#!/usr/bin/env bash
# Leçon 4.3 : un node pool Spot et un worker dessus
set -u
Z=europe-west1-b
echo "== Création du pool Spot"
gcloud container node-pools create pool-spot --cluster=atelier --zone=$Z --spot --machine-type=e2-standard-2 \
  --num-nodes=1 --disk-type=pd-standard --disk-size=50 2>&1 | tail -3 | cut -c1-200
kubectl get nodes -L cloud.google.com/gke-nodepool,cloud.google.com/gke-spot
echo "== Taints posés sur les nodes"
kubectl get nodes -o custom-columns='NODE:.metadata.name,TAINTS:.spec.taints[*].key'
if ! kubectl get nodes -l cloud.google.com/gke-spot=true -o jsonpath='{.items[*].spec.taints[*].key}' | grep -q gke-spot; then
  echo "== Pas de taint automatique : on le pose nous-mêmes"
  gcloud container node-pools update pool-spot --cluster=atelier --zone=$Z \
    --node-taints=cloud.google.com/gke-spot=true:NoSchedule --quiet 2>&1 | tail -2 | cut -c1-200
  kubectl get nodes -o custom-columns='NODE:.metadata.name,TAINTS:.spec.taints[*].key'
fi
echo "== Le worker"
kubectl apply -f k8s/module-04/worker-spot.yaml
kubectl rollout status deployment worker --timeout=120s
kubectl get pods -l app=worker -o custom-columns='POD:.metadata.name,ETAT:.status.phase,NODE:.spec.nodeName'
kubectl logs deployment/worker --tail=3
