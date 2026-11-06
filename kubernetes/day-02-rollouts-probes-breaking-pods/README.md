# Day 2: Rolling updates, probes, Services and breaking pods

**Questions this day answers:**
1. What happens when a release goes wrong, and how do I roll back?
2. What do readiness, liveness and startup probes actually do?
3. A pod is in a bad state. Where is it stuck and how do I find out why?

**Lab environment:** same Killercoda 2-node playground (or kind / minikube). Sessions get wiped, so copy your notes into git at the end.

## Files

| File | Use it for |
|---|---|
| [notes.md](notes.md) | Main notes: rolling updates, probes, Services, failure catalogue, debug flow |
| [interview-questions.md](interview-questions.md) | 24 questions with model answers, plus the Day 1 retest |
| [commands.md](commands.md) | Rollout, probe and debugging commands |
| [skim-before-interview.md](skim-before-interview.md) | One-page revision sheet |
| [lab.sh](lab.sh) | Step-by-step lab (run section by section) |
| [rolling-update-deployment.yaml](rolling-update-deployment.yaml) | 4-replica Deployment with explicit rolling-update settings |
| [probes-demo.yaml](probes-demo.yaml) | Healthy Deployment with startup, readiness and liveness probes |
| [svc-types.yaml](svc-types.yaml) | ClusterIP, NodePort and headless Services |
| [broken/](broken/) | Seven deliberately broken manifests to diagnose |

## Suggested plan (about 2 hours)

**Morning, 1 hour: read**
- kubernetes.io docs: *Deployments* (rolling update, rollback sections), *Liveness, Readiness and Startup Probes*, *Service*, *Debug Pods*.
- Read `notes.md` sections 1 to 4, then close it and explain each from memory.

**Night, 1 hour: lab**
- Run `lab.sh` sections 0 to 4 (rollouts, bad rollout, rollback, probes, Services).
- Then section 5: break pods one at a time. For each, use **get, describe, logs** and write one sentence in `notes.md` section 9.

**Last 10 minutes: retest**
- Answer Day 1 Q1 and Q4 again (see the end of `interview-questions.md`). Listen for two things:
  - You name the **first command** (`kubectl describe pod`, read Events).
  - You name the **EndpointSlice controller** for updating pod IPs.

## Rules for yourself
- Predict the result **before** running each command. A wrong prediction is where the learning is.
- If you get stuck for more than 10 minutes, paste the output and ask.
