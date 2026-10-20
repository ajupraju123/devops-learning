# Day 1 Commands

## Cluster overview
```bash
kubectl get nodes -o wide
kubectl get pods -n kube-system
kubectl get pods -A                       # all namespaces
kubectl get ds -A                         # daemonsets (is kube-proxy there?)
kubectl cluster-info
```

## Watching what happens
```bash
kubectl get events -w                     # live events (run in a second terminal)
kubectl get pods -w
kubectl get rs -w
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Create and scale
```bash
kubectl create deployment web --image=nginx --replicas=3
kubectl apply -f web-deployment.yaml
kubectl scale deployment web --replicas=6
kubectl set image deployment/web nginx=nginx:1.25
kubectl create deployment web --image=nginx --dry-run=client -o yaml     # print YAML, create nothing
```

Remember: `create` fails if the object exists; `update` is not a command; `set` only edits the pod template (`image`, `resources`, `env`), so use `scale` for replicas.

## Inspect each layer
```bash
kubectl get deployment,rs,pods -o wide
kubectl describe deployment web
kubectl describe pod <pod>                # read the Events section at the bottom
kubectl get pod <pod> -o yaml
kubectl explain deployment.spec           # field documentation
```

## Services and endpoints
```bash
kubectl expose deployment web --port=80
kubectl get svc,endpointslices
kubectl describe svc web                  # check Endpoints
kubectl get endpointslices -w             # watch IPs change when pods are replaced
kubectl create service clusterip api --tcp=80:80
```

## Labels
```bash
kubectl get pods --show-labels
kubectl get pods -L app,pod-template-hash        # labels as columns
kubectl get pods -l app=web                      # filter
kubectl get svc web -o wide                      # shows the SELECTOR
kubectl label pod <pod> app=api --overwrite      # add / change
kubectl label pod <pod> app-                     # remove (note the trailing -)
kubectl get nodes --show-labels
```

## Taints and tolerations
```bash
kubectl describe node node01 | grep -i taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
kubectl taint nodes node01 test=true:NoSchedule        # add
kubectl taint nodes node01 test=true:NoSchedule-       # remove (trailing -)
```

## Rollouts
```bash
kubectl rollout status deployment/web
kubectl rollout history deployment/web
kubectl rollout undo deployment/web
```

## Delete and self-healing test
```bash
kubectl delete pod <pod>                  # ReplicaSet creates a replacement
kubectl delete deployment web
kubectl delete svc web
```

## Troubleshooting routine: get, describe, logs
```bash
kubectl get pods                          # status + RESTARTS
kubectl describe pod <pod>                # Events: why
kubectl logs <pod>
kubectl logs <pod> --previous             # logs of the crashed container
kubectl logs <pod> -c <container>         # multi-container pods
kubectl exec -it <pod> -- sh              # only if the container stays up
```

## Handy
```bash
kubectl api-resources
kubectl <command> --help                  # examples are at the bottom
kubectl config get-contexts               # which cluster am I pointing at?
```
Always check the current context before running anything destructive.
