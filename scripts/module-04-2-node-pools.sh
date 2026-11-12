#!/usr/bin/env bash
# Leçon 4.2 : un deuxième node pool, réservé par un taint
set -u
Z=europe-west1-b
echo "== Création du pool"
gcloud container node-pools create pool-memoire --cluster=atelier --zone=$Z --machine-type=e2-highmem-2 \
  --num-nodes=1 --disk-type=pd-standard --disk-size=50 --node-taints=reserve=memoire:NoSchedule 2>&1 | tail -3 | cut -c1-200
kubectl get nodes -L cloud.google.com/gke-nodepool
echo "== Trois pods de test"
kubectl apply -f k8s/module-04/pods-placement.yaml
sleep 25
kubectl get pods -o custom-columns='POD:.metadata.name,ETAT:.status.phase,NODE:.spec.nodeName'
echo "== Pourquoi pod-refuse attend"
kubectl get events --field-selector involvedObject.name=pod-refuse -o custom-columns='TYPE:.type,RAISON:.reason,MESSAGE:.message' | cut -c1-260 | tail -2
kubectl delete -f k8s/module-04/pods-placement.yaml
echo "== Redimensionner le pool par défaut"
gcloud container clusters resize atelier --zone=$Z --node-pool=default-pool --num-nodes=1 --quiet 2>&1 | tail -2 | cut -c1-200
kubectl get nodes -L cloud.google.com/gke-nodepool
