#!/usr/bin/env bash
# Leçon 4.6 : le cluster régional du projet fil rouge, avec un pool Spot
# Attention : 3 machines facturées. Supprimez le cluster à la fin de la séance.
set -u
R=europe-west1
echo "== On supprime le cluster d'atelier"
gcloud container clusters delete atelier --zone=europe-west1-b --quiet 2>&1 | tail -1 | cut -c1-200
echo "== Création du cluster régional (une machine par zone)"
# Le compte d'essai limite le nombre de machines : on place les nodes sur deux zones.
# En production, retirez --node-locations pour utiliser les trois zones.
gcloud container clusters create boutique --region=$R --node-locations=europe-west1-b,europe-west1-c --num-nodes=1 --machine-type=e2-standard-2 \
  --release-channel=regular --disk-type=pd-standard --disk-size=50 2>&1 | tail -3 | cut -c1-200
echo "== Le pool Spot, dans une seule zone"
gcloud container node-pools create pool-spot --cluster=boutique --region=$R --node-locations=europe-west1-b --spot \
  --machine-type=e2-standard-2 --num-nodes=1 --disk-type=pd-standard --disk-size=50 \
  --node-taints=cloud.google.com/gke-spot=true:NoSchedule 2>&1 | tail -2 | cut -c1-200
gcloud container clusters get-credentials boutique --region=$R 2>&1 | tail -1
kubectl get nodes -L topology.kubernetes.io/zone,cloud.google.com/gke-nodepool
echo "== Les fichiers du module 3, sans rien changer"
kubectl apply -f k8s/api-catalogue
kubectl rollout status deployment api-catalogue -n boutique --timeout=240s
kubectl get pods -n boutique -o custom-columns='POD:.metadata.name,ETAT:.status.phase,NODE:.spec.nodeName'
echo "== Nos clusters"
gcloud container clusters list --format="table(name,location,autopilot.enabled:label=AUTOPILOT,currentNodeCount:label=NODES,status)"
