# Day 1: Kubernetes internals

**Question this day answers:** what actually happens between `kubectl apply` and traffic being served?

**Lab environment:** Killercoda playground, 2 nodes (`controlplane`, `node01`), containerd runtime, Cilium CNI.

## Files

| File | Use it for |
|---|---|
| [notes.md](notes.md) | Main notes: architecture, the flow, diagram, concepts, what I saw in my lab |
| [interview-questions.md](interview-questions.md) | Questions with model answers. Practise out loud |
| [commands.md](commands.md) | kubectl commands grouped by purpose |
| [skim-before-interview.md](skim-before-interview.md) | One-page revision sheet for the day before |
| [lab.sh](lab.sh) | Step-by-step lab script (run line by line, don't just execute it) |
| [web-deployment.yaml](web-deployment.yaml) | 3-replica nginx Deployment with labels, requests and readiness probe |
| [web-service.yaml](web-service.yaml) | ClusterIP Service selecting `app=web` |
| [toleration-demo.yaml](toleration-demo.yaml) | Deployment whose pods tolerate a taint |
| [svc-selector-mismatch.yaml](svc-selector-mismatch.yaml) | Service with a wrong selector, to practise the "no endpoints" failure |

## Suggested order
1. Read `notes.md` sections 1 to 3.
2. Run the lab (`lab.sh`) in a fresh cluster with `kubectl get events -w` open in a second terminal.
3. Fill in the **"In my own words"** section at the end of `notes.md`.
4. Answer `interview-questions.md` out loud before reading the model answers.
5. Re-read `skim-before-interview.md` the day before any interview.
