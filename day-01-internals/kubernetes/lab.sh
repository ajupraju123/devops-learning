#!/usr/bin/env bash
# Day 1 lab: kubectl apply -> traffic served
#
# Run this section by section (copy and paste), NOT as one blob.
# Open a second terminal first and run:   kubectl get events -w
# After each step, say out loud which component did what.
#
# Environment: Killercoda 2-node playground (or kind / minikube).

# ---------------------------------------------------------------
# 0. Check the cluster
# ---------------------------------------------------------------
kubectl get nodes -o wide
kubectl get pods -n kube-system
kubectl describe node controlplane | grep -i taints     # is the control-plane taint present?
kubectl describe node node01 | grep -i taints

# ---------------------------------------------------------------
# 1. Create the Deployment (watch the events terminal)
# ---------------------------------------------------------------
kubectl apply -f web-deployment.yaml
# Match events to the flow:
#   ScalingReplicaSet -> Deployment controller
#   SuccessfulCreate  -> ReplicaSet controller
#   Scheduled         -> scheduler
#   Pulling/Pulled/Created/Started -> kubelet + containerd

# ---------------------------------------------------------------
# 2. Inspect each layer
# ---------------------------------------------------------------
kubectl get deployment,rs,pods -o wide
kubectl describe pod "$(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')"
# Read: Node, Controlled By, Tolerations, Events

# ---------------------------------------------------------------
# 3. Expose it and look at the endpoints
# ---------------------------------------------------------------
kubectl apply -f web-service.yaml
kubectl get svc,endpointslices
kubectl describe svc web
# Note: the 'kubernetes' Service/EndpointSlice is built in and points at the API server.

# ---------------------------------------------------------------
# 4. Self-healing and changing IPs
# ---------------------------------------------------------------
# Terminal 2: kubectl get endpointslices -w
kubectl get pods -o wide                                 # note the IPs
POD=$(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$POD"
kubectl get pods -o wide                                 # new pod, new IP; Service IP unchanged

# ---------------------------------------------------------------
# 5. Labels: break the link on purpose
# ---------------------------------------------------------------
kubectl get pods --show-labels
POD=$(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')
kubectl label pod "$POD" app-                            # remove the label
kubectl get pods --show-labels                           # ReplicaSet creates a replacement; orphan stays
kubectl get endpointslices                               # orphan pod no longer listed
kubectl delete pod "$POD"                                # clean up the orphan

# ---------------------------------------------------------------
# 6. Service with no endpoints (selector mismatch)
# ---------------------------------------------------------------
kubectl apply -f svc-selector-mismatch.yaml
kubectl describe svc api-broken                          # Endpoints: <none>
kubectl get svc api-broken -o wide                       # SELECTOR column
kubectl get pods --show-labels                           # compare labels with selector
kubectl run apipod --image=nginx --labels=app=api        # pod with the label the Service wants
kubectl get endpointslices                               # endpoint appears

# ---------------------------------------------------------------
# 7. Taints and tolerations
# ---------------------------------------------------------------
# Taint BOTH nodes so nothing new can be scheduled (control-plane taint may be missing here).
kubectl taint nodes node01 test=true:NoSchedule
kubectl taint nodes controlplane test=true:NoSchedule
kubectl scale deployment web --replicas=6
kubectl get pods -o wide                                 # existing pods stay; new ones Pending
kubectl describe pod "$(kubectl get pods --field-selector=status.phase=Pending -o jsonpath='{.items[0].metadata.name}')"
# Read the FailedScheduling event: "untolerated taint(s)", "Preemption is not helpful"

kubectl apply -f toleration-demo.yaml                    # these pods tolerate test=true:NoSchedule
kubectl get pods -o wide

# Remove taints (trailing dash) and watch Pending pods get scheduled
kubectl taint nodes node01 test=true:NoSchedule-
kubectl taint nodes controlplane test=true:NoSchedule-
kubectl get pods -o wide -w

# ---------------------------------------------------------------
# 8. Clean up
# ---------------------------------------------------------------
kubectl delete -f toleration-demo.yaml --ignore-not-found
kubectl delete -f svc-selector-mismatch.yaml --ignore-not-found
kubectl delete -f web-service.yaml --ignore-not-found
kubectl delete -f web-deployment.yaml --ignore-not-found
kubectl delete pod apipod --ignore-not-found

# ---------------------------------------------------------------
# 9. Write-up (do this in notes.md, section 12)
# ---------------------------------------------------------------
# - The flow in your own words
# - What surprised you
# - What broke and why (one sentence each)
