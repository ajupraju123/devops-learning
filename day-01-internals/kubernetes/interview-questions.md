# Day 1 Interview Questions: Kubernetes internals

How to use this: cover the answers, say your answer **out loud**, then compare. Name the component and the action in each sentence ("the scheduler assigns the node", not "it gets assigned").

Marked **[missed in practice]** = questions I got wrong or incomplete on the first attempt. Revise these twice.

---

## A. Architecture

**1. Explain the Kubernetes architecture.**
A cluster has a control plane and worker nodes. The control plane has the API server (front door, only component talking to etcd), etcd (state store), the scheduler (chooses nodes) and the controller manager (runs controllers). Each worker has a kubelet (node agent), a container runtime such as containerd (via CRI) and kube-proxy or a CNI that handles Service routing. On EKS, AWS manages the control plane.

**2. Why does only the API server talk to etcd?** **[partly missed]**
It gives one place for authentication, authorisation, admission, validation and consistency, and it protects etcd from direct access. Every other component reads and writes through the API server, usually by watching it.

**3. What happens if etcd is lost with no backup?** **[partly missed]**
All cluster objects are gone (Deployments, Services, Secrets, ConfigMaps, RBAC). Containers already running on nodes may continue for a while, but you can no longer manage, schedule or heal anything. Hence regular etcd snapshots. On EKS, AWS operates and backs up etcd.

**4. What are static pods?**
Pods started directly by the kubelet from manifest files on a node (`/etc/kubernetes/manifests`), without going through the API server's normal scheduling. kubeadm uses them to run the control plane components.

**5. What is the `kube-system` namespace?**
The namespace for Kubernetes' own components: control plane pods, CoreDNS, the CNI and (on most clusters) kube-proxy. On EKS you also see `aws-node` (VPC CNI). Don't experiment there on a real cluster.

---

## B. The flow

**6. What happens when you run `kubectl apply -f deployment.yaml`?** **[missed on first attempt]**
Use the 60-second answer in `notes.md` section 11. Skeleton: API server (authN, RBAC, admission, validation) → etcd → Deployment controller creates ReplicaSet → ReplicaSet controller creates Pods → scheduler binds to a node → kubelet asks containerd (CRI) to pull and run → probes pass → EndpointSlice updated → traffic routed.

**7. What does "watch" mean here, and why is it important?** **[missed]**
Controllers, scheduler and kubelets open long-lived watch connections to the API server and get notified when objects they care about change. Nobody calls anybody directly. This event-driven design is what lets each component work independently and recover on its own.

**8. What is reconciliation / a control loop?**
A controller repeatedly compares desired state (in etcd) with actual state and acts to close the gap. Delete a pod from a 3-replica set and the ReplicaSet controller sees 2 of 3 and creates another.

**9. Why is there a ReplicaSet between a Deployment and its Pods?** **[partly missed]**
The ReplicaSet keeps N identical pods running. Each version of the pod template gets its own ReplicaSet, so a rolling update scales the new one up and the old one down, and a rollback scales the old one back up.

**10. Does the kubelet pull images itself?** **[missed]**
No. The kubelet calls the container runtime (containerd) through the CRI. The runtime pulls the image and runs the container. The kubelet also mounts volumes and secrets, runs probes and reports status.

---

## C. Scheduling

**11. How does the scheduler choose a node?**
It **filters** out nodes that can't run the pod (not enough resources, untolerated taints, affinity or nodeSelector mismatch) and **scores** the remaining nodes (spreading, resource balance and so on), then binds the pod to the best one by writing the node name to the API server.

**12. What are taints and tolerations?** **[missed]**
A taint on a node repels pods unless they have a matching toleration. Effects: `NoSchedule`, `PreferNoSchedule`, `NoExecute` (also evicts running pods). Used to dedicate nodes (GPU, spot, platform) and to keep workloads off control-plane nodes. A toleration only allows scheduling, it doesn't attract, so pair it with nodeSelector or affinity when a workload must land on specific nodes.

**13. A pod is Pending. What do you check?** **[missed]**
`kubectl describe pod` and read the Events. A `FailedScheduling` event from `default-scheduler` gives the reason: insufficient CPU/memory, untolerated taints, node selector or affinity mismatch, unbound PVC.

**14. What is preemption?**
A high-priority pod can cause the scheduler to evict lower-priority pods to free resources (via `PriorityClass`). It never helps with taints or affinity rules, which is why the event says "Preemption is not helpful for scheduling."

---

## D. Services, labels and endpoints

**15. What is the purpose of labels?** **[partly missed]**
Pod names and IPs are temporary, so Kubernetes groups objects by label. ReplicaSets, Services and Deployments use label selectors to find their pods, which keeps them loosely coupled.

**16. A Service has no endpoints. What do you check?** **[missed]**
1. `kubectl describe svc <name>` shows `Endpoints: <none>`.
2. Compare the Service's selector with `kubectl get pods --show-labels`.
3. Check the pods are **Ready** (failing readiness probes leave them out).
4. Check the `targetPort` matches the container port.

**17. Pod IPs change when pods are replaced. How do clients cope?** **[missed]**
Clients use the Service. Its ClusterIP and DNS name are stable, and the EndpointSlice is updated automatically as pods come and go.

**18. Does creating a Deployment create a Service?**
No. A Service must be created separately.

---

## E. Troubleshooting

**19. A pod is in CrashLoopBackOff. First three commands?** **[missed]**
1. `kubectl get pods` for status and restart count.
2. `kubectl describe pod <name>` for Last State, exit code (137 = OOMKilled, 1 = app error) and probe failures.
3. `kubectl logs <name> --previous` for what the crashed container printed.
Typical causes: app error, missing env var or config, failing liveness probe, OOM.

**20. A pod is in ImagePullBackOff. What do you check?**
`describe pod` Events for the exact error: wrong image name or tag, missing `imagePullSecret`, or registry/ECR permissions.

**21. Pending vs ImagePullBackOff vs CrashLoopBackOff: what is the difference?**
Pending: not yet assigned to a node (scheduler problem). ImagePullBackOff: assigned, but the image can't be pulled. CrashLoopBackOff: image pulled, container started, then exited repeatedly. The status tells you which stage the pod is stuck at and so which component to investigate.

---

## F. EKS-flavoured follow-ups (revisit in later weeks)

- What do you see in `kube-system` on EKS? `kube-proxy`, `aws-node` (VPC CNI), `coredns`.
- Who runs etcd and the control plane on EKS? AWS.
- How do pods get AWS permissions? IRSA (covered in the IAM week).

---

## My weakest five (re-practise before every mock)

6, 7, 12, 16, 19
