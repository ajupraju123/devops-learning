#!/usr/bin/env bash
# Day 2 lab: rolling updates, probes, Services, breaking pods
#
# Run this section by section (copy and paste), NOT as one blob.
# Keep two extra terminals open:
#   Terminal 2: kubectl get rs -w
#   Terminal 3: kubectl get pods -w
# Before each step, write down your PREDICTION. Compare afterwards.
#
# Environment: Killercoda 2-node playground (or kind / minikube).
# Run from the day-02 folder so the relative file paths work.

# ---------------------------------------------------------------
# 0. Baseline: Deployment + Services
# ---------------------------------------------------------------
kubectl apply -f rolling-update-deployment.yaml
kubectl apply -f svc-types.yaml
kubectl get deployment,rs,pods -o wide
kubectl get svc,endpointslices
# Check: how many endpoints? Do they match the 4 pod IPs?

# Zero-downtime watcher: a pod that curls the Service twice a second
kubectl run load --image=curlimages/curl --restart=Never -- \
  sh -c 'while true; do curl -s -o /dev/null -w "%{http_code} " --max-time 1 http://rollout-demo; sleep 0.5; done'
# Terminal 4:  kubectl logs -f load      (a stream of 200s = no dropped requests)

# ---------------------------------------------------------------
# 1. A good rolling update
# ---------------------------------------------------------------
# Predict: how many ReplicaSets after this? How many pods at peak? (maxSurge 1, maxUnavailable 0)
kubectl set image deployment/rollout-demo nginx=nginx:1.27
kubectl annotate deployment/rollout-demo kubernetes.io/change-cause="upgrade nginx to 1.27" --overwrite
kubectl rollout status deployment/rollout-demo
kubectl get rs
kubectl rollout history deployment/rollout-demo
# Check: did the load watcher ever print anything other than 200?

# ---------------------------------------------------------------
# 2. A bad rollout (the important one)
# ---------------------------------------------------------------
# Predict: what happens to the old pods? To user traffic? Does Kubernetes roll back by itself?
kubectl set image deployment/rollout-demo nginx=nginx:doesnotexist
kubectl rollout status deployment/rollout-demo --timeout=60s    # will time out
kubectl get rs
kubectl get pods
kubectl describe pod "$(kubectl get pods --no-headers | grep -E 'ErrImagePull|ImagePullBackOff' | head -1 | awk '{print $1}')"
kubectl describe deployment rollout-demo                         # after ~120s: Progressing=False, ProgressDeadlineExceeded
# Check: load watcher still all 200s? (the readiness gate kept traffic on the old pods)

# Recover: roll back
kubectl rollout undo deployment/rollout-demo
kubectl rollout status deployment/rollout-demo
kubectl rollout history deployment/rollout-demo

# ---------------------------------------------------------------
# 3. Probes
# ---------------------------------------------------------------
kubectl apply -f probes-demo.yaml
kubectl describe pod "$(kubectl get pods -l app=probes-demo -o jsonpath='{.items[0].metadata.name}')" | grep -iE "liveness|readiness|startup"
# Now the broken ones (see broken/05 and broken/06):
kubectl apply -f broken/05-readiness-failing.yaml
kubectl get pod ready-demo                  # Running but 0/1?
kubectl describe pod ready-demo             # Events
kubectl describe svc ready-demo             # endpoints?
kubectl apply -f broken/06-liveness-failing.yaml
kubectl get pod liveness-demo -w            # watch RESTARTS climb
kubectl describe pod liveness-demo
# Write down the difference between 05 and 06 in your own words (notes.md section 9).

# ---------------------------------------------------------------
# 4. Services
# ---------------------------------------------------------------
kubectl get svc -o wide
kubectl run curl-test --rm -it --image=curlimages/curl --restart=Never -- curl -s -o /dev/null -w "%{http_code}\n" http://rollout-demo
kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- nslookup rollout-demo            # one ClusterIP
kubectl run dns-test2 --rm -it --image=busybox:1.36 --restart=Never -- nslookup rollout-demo-headless  # several pod IPs
kubectl get svc rollout-demo-np             # NodePort 30080
# Wrong targetPort:
kubectl apply -f broken/07-service-wrong-targetport.yaml
kubectl describe svc tp-demo                # endpoints exist...
kubectl run curl-test2 --rm -it --image=curlimages/curl --restart=Never -- curl -sv --max-time 3 http://tp-demo   # ...but it fails
kubectl delete -f broken/07-service-wrong-targetport.yaml

# ---------------------------------------------------------------
# 5. Break pods one at a time: get, describe, logs
# ---------------------------------------------------------------
# For each: predict the status, run the three commands, write one sentence in notes.md.
kubectl apply -f broken/01-pending-insufficient-cpu.yaml
kubectl get pod pending-demo
kubectl describe pod pending-demo           # FailedScheduling
kubectl delete -f broken/01-pending-insufficient-cpu.yaml

kubectl apply -f broken/02-imagepullbackoff.yaml
kubectl get pod imagepull-demo
kubectl describe pod imagepull-demo         # Scheduled OK, then pull error
kubectl delete -f broken/02-imagepullbackoff.yaml

kubectl apply -f broken/03-crashloopbackoff.yaml
kubectl get pod crash-demo -w               # Ctrl+C after a few restarts
kubectl describe pod crash-demo             # Exit Code 1
kubectl logs crash-demo --previous
kubectl delete -f broken/03-crashloopbackoff.yaml

kubectl apply -f broken/04-oomkilled.yaml
kubectl get pod oom-demo -w                 # Ctrl+C after a restart
kubectl describe pod oom-demo               # OOMKilled, Exit Code 137
kubectl delete -f broken/04-oomkilled.yaml

# ---------------------------------------------------------------
# 6. Clean up
# ---------------------------------------------------------------
kubectl delete pod load --ignore-not-found
kubectl delete -f broken/ --ignore-not-found
kubectl delete -f probes-demo.yaml -f svc-types.yaml -f rolling-update-deployment.yaml --ignore-not-found

# ---------------------------------------------------------------
# 7. Retest (last 10 minutes, out loud, no notes)
# ---------------------------------------------------------------
# R1: kubectl apply -> traffic served. Name the EndpointSlice controller and say a Service must exist.
# R2: Pending / ImagePullBackOff / CrashLoopBackOff. Name the FIRST command, the stage, and the likely causes.
