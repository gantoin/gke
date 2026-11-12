#!/usr/bin/env bash
# Module 3, leçons 3.7 et 3.8 : ressources, classe QoS et test de la liveness probe.
# À lancer après : kubectl apply -f k8s/api-catalogue
set -u
NS=boutique

echo "== Ressources et classe QoS des pods"
kubectl get pods -n "$NS" -o custom-columns='POD:.metadata.name,QOS:.status.qosClass,CPU_REQ:.spec.containers[0].resources.requests.cpu,CPU_LIM:.spec.containers[0].resources.limits.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory,MEM_LIM:.spec.containers[0].resources.limits.memory'

POD=$(kubectl get pods -n "$NS" -l app=api-catalogue -o jsonpath='{.items[0].metadata.name}')
echo
echo "== On fait échouer la liveness probe du pod $POD"
kubectl exec -n "$NS" "$POD" -- curl -s -X POST localhost:8080/api/test/casser-liveness
echo
echo "== On attend 45 secondes..."
sleep 45
kubectl get pods -n "$NS"
echo
echo "== Événements liés à la liveness probe"
kubectl get events -n "$NS" --sort-by=.lastTimestamp | grep -i -E 'liveness|killing' | tail -3 | cut -c1-200
