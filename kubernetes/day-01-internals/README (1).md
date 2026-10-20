# DevOps Learning Log

Hands-on notes, labs and interview prep for the DevOps / Platform / SRE roadmap.

## How this repo works
- One folder per topic, one sub-folder per study day.
- Every day has: `notes.md` (read), `interview-questions.md` (practise), `commands.md` (reference), YAMLs and scripts (run).
- Each lab ends with a **"What broke and why"** section. Those become interview stories.

## Progress

| Area | Day | Topic | Status |
|---|---|---|---|
| Kubernetes | [Day 1](kubernetes/day-01-internals/) | Internals: `kubectl apply` to traffic served | Done |
| Kubernetes | Day 2 | Rolling updates, probes, breaking pods | Planned |
| Kubernetes | Day 3 | etcd, admission, HPA, EKS specifics | Planned |
| AWS | | VPC design, ECS failure handling, IAM / IRSA / OIDC | Planned |
| Terraform | | State, locking, drift, modules | Planned |

## Rules for this repo
- Never commit secrets: no keys, tokens, kubeconfigs, `.tfvars` with real values.
- Write notes in your own words. If you can't explain it simply, you haven't learned it yet.
