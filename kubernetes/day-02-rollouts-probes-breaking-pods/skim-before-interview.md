# Skim Before the Interview: Rollouts, probes, Services, troubleshooting (15 minutes)

## 1. Rolling update in four lines
- Template change creates a **new ReplicaSet**; new scales up, old scales down.
- Pace: `maxSurge` and `maxUnavailable` (default 25% each). Zero downtime = `maxUnavailable: 0`.
- New pod counts only when **readiness passes**.
- Old ReplicaSets are kept for rollback: `kubectl rollout undo`.

## 2. Bad rollout, what really happens
New pod never Ready, old pods can't be removed, rollout **stalls**, traffic stays on old pods, `ProgressDeadlineExceeded` after 600s. **No automatic rollback.** Roll back first, investigate second.
ECS comparison: `minimumHealthyPercent` / `maximumPercent` ~ `maxUnavailable` / `maxSurge`; ECS has a circuit breaker, plain Deployments don't.

## 3. Probes
| Probe | Failure means | Result |
|---|---|---|
| Startup | Not started yet | Restart; liveness/readiness off until it passes |
| Readiness | Can't serve now | Removed from endpoints, no restart |
| Liveness | Stuck or dead | Container restarted |

Never put dependencies (DB, downstream APIs) in a liveness probe.

## 4. Services
- Types: ClusterIP, NodePort (30000-32767), LoadBalancer, ExternalName, headless.
- `port` (Service) / `targetPort` (container) / `nodePort` (every node).
- Ingress = HTTP routing rules (needs an ingress controller) in front of Services.
- DNS: `<svc>.<ns>.svc.cluster.local`.
- No endpoints = selector mismatch or pods not Ready. Endpoints but failing = wrong `targetPort`.

## 5. Status to stage to first look
First command, always: **`kubectl describe pod`, read Events.**

| Status | Stuck at | Look at |
|---|---|---|
| Pending | Scheduler | `FailedScheduling`: resources, taints, affinity, PVC |
| ImagePullBackOff | Image pull | exact error: tag, pull secret, registry/ECR permissions |
| CrashLoopBackOff | Ran then exited | `logs --previous`, exit code, probes |
| Running, 0/1 Ready | Readiness | probe path/port, `describe svc` endpoints |
| Restarts climbing | Liveness | probe events, genuine hang? |
| Endpoints but no connection | Port wiring | `targetPort` vs container port |

## 6. Exit codes
0 clean, 1 app error, 126/127 command problem, **137 SIGKILL / OOMKilled**, 139 segfault, 143 SIGTERM.

## 7. CrashLoopBackOff back-off
Restart delay doubles 10s, 20s, 40s... up to 5 minutes.

## 8. The debug sentence
> `get pods` for status and restarts, `describe pod` and Events to see which stage it's stuck at, `logs --previous` and the exit code for crashes, and the Service selector, EndpointSlice and `targetPort` when traffic fails.

## 9. Spoken answer for "production release broke things"
> Stop the damage first: roll back with `rollout undo`. Then check events, logs, probes and resource limits for the new version, confirm recovery through error rate and latency, and add a guard so it can't recur: a readiness probe, canary, or alert.

## 10. Carry-over from Day 1
- A Deployment doesn't create a Service.
- The EndpointSlice controller updates pod IPs; kube-proxy/Cilium routes.
- API server: authN, RBAC, admission, validate, write to etcd.
- Preemption can't fix taints.
