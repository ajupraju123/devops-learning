# Skim Before the Interview: Kubernetes internals (15 minutes)

## 1. Who does what (say it in one breath)
- **API server:** front door; authN, RBAC, admission, validation; only thing that talks to etcd.
- **etcd:** all cluster state. Lost with no backup = lost objects.
- **Controller manager:** runs the Deployment, ReplicaSet, Node and EndpointSlice controllers.
- **Scheduler:** picks the node (filter, then score) and writes it back to the API server.
- **Kubelet:** watches for pods on its node; asks containerd (CRI) to run them; mounts secrets; runs probes; reports status.
- **kube-proxy / Cilium:** Service routing on each node. **CNI:** pod IPs.
- EKS: AWS runs the control plane and etcd.

## 2. The flow (10 words each)
1. API server: auth, RBAC, admission, validate
2. Stored in etcd
3. Deployment controller creates ReplicaSet
4. ReplicaSet controller creates Pods
5. Scheduler binds pod to node
6. Kubelet + containerd pull image, start container
7. Readiness probe passes, pod Ready
8. EndpointSlice gets the pod IP
9. kube-proxy / Cilium route traffic

Everything is **watch + reconcile**. Components never call each other directly.

## 3. Five facts people forget
- Pod **IPs change**; the Service ClusterIP doesn't.
- A Deployment does **not** create a Service.
- Each version = its own **ReplicaSet**; rollback scales the old one back up.
- A Service finds pods by **label selector**; no endpoints usually means a label mismatch or pods not Ready.
- Pending pods are a **scheduler** problem: `describe pod` shows `FailedScheduling`.

## 4. Taints in one line
Taint on node repels; toleration on pod permits; affinity/nodeSelector attracts. `NoExecute` evicts running pods. Preemption never fixes a taint.

## 5. Pod status to stuck stage

| Status | Meaning | Look at |
|---|---|---|
| Pending | No node yet | `describe` Events (resources, taints, affinity) |
| ImagePullBackOff | Can't pull image | tag, pull secret, registry permissions |
| CrashLoopBackOff | Ran, then exited | `logs --previous`, exit code, probes |
| Running, no traffic | After Ready | selector, EndpointSlice, readiness, port |

Routine: **get, describe, logs**.

## 6. Exit codes
`137` = OOMKilled (or SIGKILL), `1` = app error, `0` = clean exit (still restarts if it's a Deployment pod).

## 7. Commands to recall without thinking
```
kubectl get pods -o wide --show-labels
kubectl describe pod <pod>
kubectl logs <pod> --previous
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl get endpointslices
kubectl rollout undo deployment/<name>
kubectl taint nodes <node> key=value:NoSchedule
```

## 8. Mistakes to avoid saying
- "Master node" (say control plane)
- "Kubelet pulls the image" (it asks containerd via the CRI)
- "Controller manager assigns nodes" (the scheduler does)
- "Pod IPs stay the same" (they don't)

## 9. Stories to attach to answers
- Lab: a pod landed on the control-plane node because the taint was removed in the playground; I confirmed with `describe node`.
- Lab: deleted a pod, the replacement had a new IP, the Service IP stayed the same.
- Work: relate each failure state above to an incident on your EKS environments, with the command that found the cause.

## 10. Read aloud once
> Everything in Kubernetes is a control loop. Desired state lives in etcd behind the API server; controllers, the scheduler and kubelets watch the API server and reconcile actual state toward it.
