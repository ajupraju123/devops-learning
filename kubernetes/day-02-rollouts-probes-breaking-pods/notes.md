# Day 2 Notes: Rolling updates, probes, Services, breaking pods

Date: ____ (fill in)
Lab: Killercoda 2-node cluster

Prerequisite: Day 1 (flow from `kubectl apply` to traffic, labels, taints). Re-read `../day-01-internals/skim-before-interview.md` first.

---

## 0. Day 1 gaps to fix today

Say these correctly without notes:
- A **Deployment does not create a Service**. A Service is a separate object.
- The **EndpointSlice controller** (inside the controller manager) updates the pod IP list. kube-proxy / Cilium then programs routing from it.
- The API server **authenticates, authorises (RBAC), runs admission, validates and writes** the desired state to etcd. It doesn't just "check the current state".
- For any broken pod, the **first command is `kubectl describe pod`**, and you read the **Events** section.
- Preemption evicts lower-priority pods to free resources. It never fixes taints.

---

## 1. Rolling updates

### How it works
- A Deployment keeps one **ReplicaSet per pod-template version**. Change the template (image, env, resources) and the Deployment controller creates a **new ReplicaSet**, scales it up and scales the old one down, in steps.
- Only changes to `spec.template` trigger a rollout. Scaling replicas does not.
- Pace is controlled by two settings:
  - **`maxSurge`**: how many extra pods above `replicas` may exist during the update (default 25%, rounded up).
  - **`maxUnavailable`**: how many pods below `replicas` may be unavailable (default 25%, rounded down).
- A new pod counts as available only when its **readiness probe passes** (plus `minReadySeconds`). No readiness probe means "ready" the moment the container starts, so a broken pod can look healthy and the rollout rushes ahead.

### Example: replicas 4, maxSurge 1, maxUnavailable 0

| Step | Old RS | New RS | Total | Available |
|---|---|---|---|---|
| Start | 4 | 0 | 4 | 4 |
| Surge one new pod | 4 | 1 (not Ready yet) | 5 | 4 |
| New pod Ready, remove an old one | 3 | 1 | 4 | 4 |
| Repeat... | 2 / 1 | 2 / 3 | 4 | 4 |
| Done | 0 | 4 | 4 | 4 |

Availability never drops below 4. That's the zero-downtime setting.

```
Old RS  [4][4][3][3][2][2][1][1][0]
New RS  [0][1][1][2][2][3][3][4][4]
```

### Strategies
- **RollingUpdate** (default): described above.
- **Recreate**: kill all old pods, then start new ones. Downtime, but needed when two versions must never run at once.

### Rollback
- `kubectl rollout undo deployment/<name>` scales the previous ReplicaSet back up (and the current one down). It is itself a rolling update in reverse.
- Old ReplicaSets are kept (scaled to 0) up to `revisionHistoryLimit` (default 10) so rollback is possible.
- `kubectl rollout history deployment/<name>` lists revisions. Set the annotation `kubernetes.io/change-cause` to give each revision a readable reason.
- `--to-revision=N` rolls back to a specific revision.
- `kubectl rollout pause|resume` lets you batch several changes into one rollout.

### What happens when a rollout goes bad (very important)
Scenario: you set an image tag that doesn't exist.
1. The new ReplicaSet creates a pod. It sits in `ErrImagePull` then `ImagePullBackOff`, never becoming Ready.
2. With `maxUnavailable: 0`, the old ReplicaSet can't scale down (that would drop availability). The rollout **stalls** at 4 old pods and 1 new broken pod.
3. **Traffic keeps flowing to the old pods.** Users are mostly unaffected. The readiness gate and `maxUnavailable` protected you.
4. `kubectl rollout status` keeps waiting. After `progressDeadlineSeconds` (default 600s) the Deployment gets condition `Progressing=False, reason=ProgressDeadlineExceeded`.
5. **Kubernetes does not roll back automatically.** You (or your CD tool, for example Argo Rollouts / Flagger) must run `rollout undo` or fix forward.

### Link to ECS (my weak spot in the mock interview)
- `minimumHealthyPercent` is like `maxUnavailable`, `maximumPercent` is like `maxSurge`.
- ECS has a **deployment circuit breaker** that can roll back automatically. Kubernetes' native Deployment does not; that gap is why progressive delivery tools exist.

### Recovery thinking (say this in interviews)
"My first move on a bad release is to stop the damage: roll back (`rollout undo`), then investigate. I'd check pod events and logs for the new version, and confirm health through readiness, error rate and latency."

---

## 2. Probes

Probes are checks the **kubelet** runs against a container.

| Probe | Question it answers | If it fails |
|---|---|---|
| **Startup** | Has the app finished starting? | Container is killed and restarted (after `failureThreshold x periodSeconds`). Until it succeeds, liveness and readiness are **disabled**. |
| **Readiness** | Can this pod take traffic right now? | Pod is marked **not Ready** and **removed from Service endpoints**. **No restart.** |
| **Liveness** | Is the container stuck or dead? | Kubelet **restarts the container** (`RESTARTS` goes up). |

Mechanisms: `httpGet`, `tcpSocket`, `exec` (command exit code), `grpc`.

Settings (defaults): `initialDelaySeconds` 0, `periodSeconds` 10, `timeoutSeconds` 1, `failureThreshold` 3, `successThreshold` 1 (must be 1 for liveness and startup).

### What the symptoms look like
- **Readiness failing:** `READY 0/1`, status `Running`, no restarts, Service has no endpoint for this pod. (A common "Service has no endpoints but pods are Running" cause.)
- **Liveness failing:** `RESTARTS` keeps climbing; Events show `Liveness probe failed` then `Container ... will be restarted`. Eventually `CrashLoopBackOff`.
- **Startup probe too strict:** slow apps get killed in a loop before they ever start.

### Common mistakes
- No readiness probe, so traffic arrives before the app is ready and rollouts move too fast.
- **Liveness probe that checks dependencies** (database, downstream API). A dependency outage restarts every pod at once, making the outage worse. Liveness should check only "is this process healthy?"
- Timeouts too tight under load, causing needless restarts.
- Using the same check for readiness and liveness.

### Rule of thumb
- Readiness: "can I serve requests?" (may include dependencies, carefully).
- Liveness: "am I deadlocked?" (keep it cheap and internal).
- Startup: "am I done booting?" (for slow starters, instead of a huge `initialDelaySeconds`).

---

## 3. Services in more depth

### Types

| Type | What it gives you | Typical use |
|---|---|---|
| **ClusterIP** (default) | Stable virtual IP and DNS name, reachable only inside the cluster | Service-to-service traffic |
| **NodePort** | ClusterIP plus a port (default range 30000-32767) opened on **every node** | Quick external access, building block for load balancers |
| **LoadBalancer** | NodePort plus a cloud load balancer created via the cloud provider | Exposing a service on AWS/GCP/Azure |
| **ExternalName** | DNS CNAME to an external name | Pointing at an outside service |
| **Headless** (`clusterIP: None`) | No virtual IP; DNS returns the pod IPs directly | StatefulSets, client-side load balancing |

**Ingress** is a separate object: HTTP(S) routing rules (host/path) that an **ingress controller** (for example NGINX, or the AWS Load Balancer Controller creating an ALB) implements. The Ingress routes to Services, which route to pods.

### Ports (get these three right)
- `port`: what the **Service** listens on.
- `targetPort`: the **container** port traffic is forwarded to.
- `nodePort`: the port opened on each node (NodePort/LoadBalancer only).

### DNS
- CoreDNS resolves `<service>.<namespace>.svc.cluster.local`. Inside the same namespace, `web` alone works.

### Remember
- Service and pods are linked only by **label selector**. Endpoints list **Ready** pods only.
- Wrong `targetPort` gives you **endpoints that exist but connections that fail**, a different symptom from no endpoints.

---

## 4. Pod lifecycle and states

- **Pod phases:** `Pending`, `Running`, `Succeeded`, `Failed`, `Unknown`.
- **Container states:** `Waiting` (with a reason: `ContainerCreating`, `ImagePullBackOff`, `CrashLoopBackOff`), `Running`, `Terminated` (with reason and **exit code**).
- `kubectl get pods` STATUS column shows these reasons. `describe pod` shows `State`, `Last State`, `Exit Code`, and Events.
- `restartPolicy: Always` (default for Deployment pods) means the kubelet restarts exited containers with exponential back-off (10s, 20s, 40s... up to 5 minutes). That back-off is the `BackOff` in CrashLoopBackOff.

### Exit codes
| Code | Meaning |
|---|---|
| 0 | Clean exit |
| 1 | Application error |
| 126 / 127 | Command not executable / not found |
| 137 | SIGKILL (128+9). With reason `OOMKilled`, the container exceeded its memory limit |
| 139 | Segfault |
| 143 | SIGTERM (128+15), normal shutdown signal |

---

## 5. Failure catalogue

| Status | Stage stuck at | How I reproduced it | How to diagnose | Typical causes and fixes |
|---|---|---|---|---|
| `Pending` | Scheduler | `broken/01-pending-insufficient-cpu.yaml` | `describe pod` Events: `FailedScheduling` | Insufficient CPU/memory, untolerated taint, affinity/nodeSelector mismatch, unbound PVC. Fix requests, add nodes, add toleration, fix selector |
| `ErrImagePull` then `ImagePullBackOff` | Kubelet pulling image | `broken/02-imagepullbackoff.yaml` | `describe pod` Events: exact pull error | Wrong tag/name, missing `imagePullSecret`, registry permissions. On EKS: node role needs ECR read access, and cross-account ECR needs a repo policy |
| `CrashLoopBackOff` (app error) | Container ran then exited | `broken/03-crashloopbackoff.yaml` | `logs --previous`, exit code in `describe` | Bad config or env var, app bug, missing dependency |
| `OOMKilled` then `CrashLoopBackOff` | Container exceeded memory limit | `broken/04-oomkilled.yaml` | `describe`: `Reason: OOMKilled`, `Exit Code: 137` | Raise limit, fix leak, right-size requests |
| `Running` but `0/1` Ready | Readiness probe failing | `broken/05-readiness-failing.yaml` | `describe` Events: `Readiness probe failed`; `describe svc`: no endpoint | Wrong probe path/port, app not actually ready |
| Restarts climbing | Liveness probe failing | `broken/06-liveness-failing.yaml` | Events: `Liveness probe failed ... will be restarted` | Wrong probe, too-tight timeout, genuinely hung app |
| Endpoints exist, connection fails | Service port wiring | `broken/07-service-wrong-targetport.yaml` | `describe svc` shows endpoints; curl fails | `targetPort` doesn't match the container's listening port |
| Service has no endpoints | Selector / readiness | (Day 1) `svc-selector-mismatch.yaml` | `describe svc`, `get pods --show-labels` | Label mismatch, pods not Ready |

---

## 6. Debug flow

```
Is the pod object there?        kubectl get pods
        |
Status Pending?  ---------> describe pod -> Events (FailedScheduling): resources? taints? affinity? PVC?
        |
ContainerCreating / ImagePullBackOff? --> describe pod -> Events: image, pull secret, volume, CNI
        |
CrashLoopBackOff / restarts? -> describe pod (Last State, exit code) -> logs --previous -> probes?
        |
Running but 0/1 Ready? ------> describe pod -> readiness probe events -> check path/port
        |
Running and Ready but no traffic? -> describe svc (selector, ports, endpoints) -> labels -> targetPort
        |
Still unclear -> node level: describe node, kubectl get events -A, kubelet logs (on EKS: node/SSM access)
```

**Spoken template for interviews:**
> I start with `kubectl get pods` to see the status and restart count. Then `kubectl describe pod` and the Events section tell me which stage it is stuck at: scheduling, image pull, container start or probes. For a crash I check `logs --previous` and the exit code. If the pod is healthy but traffic fails, I check the Service: selector versus pod labels, the EndpointSlice, and the `targetPort`.

---

## 7. What I saw in my own lab (fill in)

- Rolling update: (what did `get rs -w` show?)
- Bad rollout: (what happened to the old pods and to traffic?)
- Each broken pod: (status, the key event line, the fix)

---

## 8. Mistakes I made today (fill in)

| I said / did | Correct |
|---|---|
| | |
| | |

---

## 9. In my own words (fill in after the lab)

**What happens when I run `kubectl set image` and the new image is bad:**

(write here)

**Readiness vs liveness vs startup:**

(write here)

**My debug routine for a broken pod:**

(write here)

---

## 10. Next

- Day 3: etcd (backup/restore basics), admission controllers, HPA, and EKS specifics (VPC CNI, IRSA, ALB ingress controller)
- Then the AWS and Terraform weeks
