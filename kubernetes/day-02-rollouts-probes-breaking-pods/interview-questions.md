# Day 2 Interview Questions: Rollouts, probes, Services, troubleshooting

How to use: cover the answers, say yours **out loud**, then compare. Use a frame: "First..., then..., finally...". If you catch a mistake, correct it in one clause and carry on.

---

## A. Rolling updates and rollbacks

**1. How does a rolling update work in a Deployment?**
Changing the pod template makes the Deployment controller create a new ReplicaSet. It scales the new one up and the old one down in steps, paced by `maxSurge` and `maxUnavailable`, and a new pod only counts as available once its readiness probe passes. Old ReplicaSets are kept (scaled to 0) for rollback.

**2. What do `maxSurge` and `maxUnavailable` do? What are the defaults?**
`maxSurge` is how many extra pods above the desired count may exist during the update; `maxUnavailable` is how many may be unavailable. Defaults are 25% each (surge rounds up, unavailable rounds down). With `maxSurge: 1, maxUnavailable: 0` you get zero-downtime updates, at the cost of needing capacity for one extra pod.

**3. How do you roll back a bad release?**
`kubectl rollout undo deployment/<name>` (or `--to-revision=N`). It scales the previous ReplicaSet up and the current one down. `kubectl rollout history` shows revisions.

**4. You push an image tag that doesn't exist. What happens to users?**
The new pod goes `ErrImagePull` / `ImagePullBackOff` and never becomes Ready. With `maxUnavailable: 0`, the old pods can't be removed, so the rollout stalls and traffic stays on the old pods. After `progressDeadlineSeconds` (600s default) the Deployment reports `ProgressDeadlineExceeded`. Kubernetes does **not** roll back on its own, so I'd run `rollout undo` and then investigate.

**5. Does Kubernetes roll back automatically?**
No, not for a plain Deployment. Argo Rollouts, Flagger or the CD pipeline can add automated rollback on failed analysis. (ECS has a native deployment circuit breaker; that's the comparison.)

**6. What triggers a rollout? Does scaling?**
Only changes under `spec.template`. Changing `replicas` doesn't create a new ReplicaSet.

**7. RollingUpdate vs Recreate?**
Recreate kills everything then starts the new version (downtime). Use it when two versions must never run together, for example a breaking schema or a singleton.

---

## B. Probes

**8. Explain readiness, liveness and startup probes.**
Readiness decides whether the pod receives traffic; failing it removes the pod from Service endpoints without restarting it. Liveness detects a stuck container; failing it makes the kubelet restart the container. Startup protects slow-starting apps: liveness and readiness are disabled until it succeeds.

**9. A pod shows `Running` but `0/1` Ready. What does that mean?**
The container is up but the readiness probe is failing, so it's excluded from the Service's endpoints. `describe pod` Events show `Readiness probe failed`; check the probe path, port and what the app actually serves.

**10. What's wrong with a liveness probe that calls the database?**
A database outage would fail liveness on every pod and the kubelet would restart them all, turning a dependency problem into a full outage. Liveness should check only that the process itself is healthy.

**11. What happens if there's no readiness probe?**
The pod is considered Ready as soon as the container starts, so it can receive traffic before the app is ready, and rollouts move faster than they safely should.

**12. Why use a startup probe instead of a large `initialDelaySeconds`?**
It adapts: the app is checked repeatedly until it's up (up to `failureThreshold x periodSeconds`), then the normal liveness and readiness probes take over. A big fixed delay either wastes time or still isn't enough.

---

## C. Services and networking

**13. What are the Service types?**
ClusterIP (internal virtual IP), NodePort (a port on every node), LoadBalancer (cloud load balancer in front), ExternalName (DNS CNAME), and headless (`clusterIP: None`, DNS returns pod IPs). Ingress is separate: HTTP routing rules implemented by an ingress controller, forwarding to Services.

**14. Difference between `port`, `targetPort` and `nodePort`?**
`port` is what the Service listens on, `targetPort` is the container port traffic goes to, `nodePort` is the port opened on every node (default range 30000-32767).

**15. How does one pod reach another by name?**
CoreDNS resolves `<service>.<namespace>.svc.cluster.local`; inside the same namespace the short name works. The ClusterIP is load-balanced across Ready endpoints by kube-proxy or Cilium.

**16. A Service has `Endpoints: <none>`. What do you check?**
`describe svc`, then compare the selector with `get pods --show-labels`; confirm the pods are Ready; confirm the `targetPort`. Selector typo or readiness failure are the common causes.

**17. A Service has endpoints, but requests fail. What now?**
Check `targetPort` against the port the container actually listens on, then test from a temporary pod (`kubectl run ... curl`) to separate Service problems from network policy or app problems. Check the app logs and any NetworkPolicy.

**18. How is a headless Service different, and when do you use it?**
No ClusterIP, DNS returns the individual pod IPs. Used with StatefulSets and for client-side load balancing or peer discovery.

---

## D. Troubleshooting

**19. Pending, ImagePullBackOff, CrashLoopBackOff: first command and likely causes for each?**
First command for all: `kubectl describe pod` and read Events.
- Pending: scheduler problem (insufficient CPU/memory, untolerated taint, affinity, unbound PVC).
- ImagePullBackOff: wrong tag or name, missing pull secret, registry permissions (on EKS, ECR read access on the node role).
- CrashLoopBackOff: the container ran and exited; `logs --previous` and the exit code (1 app error, 137 OOMKilled), plus liveness probe failures.

**20. What is OOMKilled and how do you spot it?**
The container exceeded its memory limit and the kernel killed it. `describe pod` shows `Last State: Terminated, Reason: OOMKilled, Exit Code: 137`. Fix by raising the limit, fixing a leak or right-sizing.

**21. Why is it called CrashLoopBackOff?**
The container keeps crashing and the kubelet restarts it with an exponentially increasing delay (10s, 20s, 40s, up to 5 minutes). "BackOff" is that delay.

**22. Why doesn't `kubectl exec` help much with CrashLoopBackOff?**
The container keeps dying, so you often can't get a shell. Use `logs --previous` and `describe` for the exit code and events instead.

**23. Pod is stuck in Terminating. What could be going on?**
A finalizer that isn't being removed, a node that's unreachable, or an app ignoring SIGTERM until the grace period ends. Check `describe pod`, finalizers in the YAML and the node status. Force-delete only as a last resort.

**24. Walk me through how you'd troubleshoot a release that caused 5xx errors in production.**
Stop the damage first: roll back (`rollout undo`) or shift traffic back. Then check the new pods' events and logs, readiness and liveness behaviour, resource limits, and config differences. Confirm recovery through error rate and latency, then write up the cause and add a guard (readiness probe, canary, alert).

---

## Retest from Day 1 (answer these again at the end of the day)

**R1. `kubectl apply` of a Deployment to traffic served.** Listen for: API server (authN, RBAC, admission, validation) writes to etcd; Deployment controller creates ReplicaSet; ReplicaSet controller creates Pods; scheduler binds nodes; kubelet asks containerd via CRI; readiness passes; **EndpointSlice controller** adds the IP; kube-proxy/Cilium routes traffic. Also: **a Service must exist** for any of the endpoint steps.

**R2. Pending, ImagePullBackOff, CrashLoopBackOff.** Listen for: the **first command** named explicitly (`kubectl describe pod`, Events), the stage each is stuck at, and `logs --previous` with the exit code.

---

## My weakest five (re-practise before each mock)

4, 9, 16, 19, 24
