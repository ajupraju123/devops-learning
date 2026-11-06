# Day 2 Commands

## Rollouts
```bash
kubectl apply -f rolling-update-deployment.yaml
kubectl set image deployment/rollout-demo nginx=nginx:1.27      # triggers a rollout (container name = nginx)
kubectl rollout status deployment/rollout-demo                  # waits; Ctrl+C to stop watching
kubectl rollout history deployment/rollout-demo
kubectl rollout history deployment/rollout-demo --revision=2    # what changed in revision 2
kubectl rollout undo deployment/rollout-demo                    # back one revision
kubectl rollout undo deployment/rollout-demo --to-revision=1
kubectl rollout pause deployment/rollout-demo                   # batch changes
kubectl rollout resume deployment/rollout-demo
kubectl rollout restart deployment/rollout-demo                 # new rollout, same spec (new pods)
kubectl annotate deployment/rollout-demo kubernetes.io/change-cause="upgrade nginx to 1.27" --overwrite
```

## Watching a rollout
```bash
kubectl get rs -w                          # old RS shrinks, new RS grows
kubectl get pods -w
kubectl get deployment rollout-demo -o wide
kubectl describe deployment rollout-demo   # Conditions: Progressing / Available, events
```

## Zero-downtime check (traffic during a rollout)
```bash
kubectl run load --image=curlimages/curl --restart=Never -- \
  sh -c 'while true; do curl -s -o /dev/null -w "%{http_code} " --max-time 1 http://rollout-demo; sleep 0.5; done'
kubectl logs -f load                       # a stream of 200s means no dropped requests
kubectl delete pod load
```

## Testing a Service from inside the cluster
```bash
kubectl run curl-test --rm -it --image=curlimages/curl --restart=Never -- curl -s -o /dev/null -w "%{http_code}\n" http://rollout-demo
kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- nslookup rollout-demo
kubectl port-forward svc/rollout-demo 8080:80        # then curl localhost:8080 from the same machine
```

## Services
```bash
kubectl get svc -o wide
kubectl describe svc <name>                # selector, ports, endpoints
kubectl get endpointslices
kubectl get endpointslices -l kubernetes.io/service-name=<svc> -o yaml
```

## Probes
```bash
kubectl describe pod <pod> | grep -iE "liveness|readiness|startup"
kubectl describe pod <pod>                 # Events: "Readiness probe failed", "Liveness probe failed"
kubectl get pods -w                        # watch READY and RESTARTS
```

## Diagnosing a broken pod: get, describe, logs
```bash
kubectl get pods
kubectl describe pod <pod>                 # Events at the bottom, State / Last State, Exit Code
kubectl logs <pod>
kubectl logs <pod> --previous              # the crashed container
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}{"\n"}'
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}{"\n"}'
```

## Resource usage (needs metrics-server; may not exist in the playground)
```bash
kubectl top nodes
kubectl top pods
```

## Node-level when pods look fine but something is off
```bash
kubectl describe node <node>               # Conditions, Allocated resources, taints, recent events
kubectl get events -A --sort-by=.metadata.creationTimestamp | tail -30
```

## Clean up
```bash
kubectl delete -f broken/ --ignore-not-found
kubectl delete -f svc-types.yaml -f probes-demo.yaml -f rolling-update-deployment.yaml --ignore-not-found
```
