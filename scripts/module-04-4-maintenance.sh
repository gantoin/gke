#!/usr/bin/env bash
# Leçon 4.4 : versions, fenêtre de maintenance, et protection des pods pendant un drain
set -u
Z=europe-west1-b
echo "== Canal et versions du cluster"
gcloud container clusters describe atelier --zone=$Z --format="table(releaseChannel.channel,currentMasterVersion,currentNodeVersion)"
echo "== Versions par défaut de chaque canal"
gcloud container get-server-config --zone=$Z --flatten="channels" --format="table(channels.channel,channels.defaultVersion)" 2>/dev/null
echo "== Fenêtre de maintenance : le week-end, la nuit"
gcloud container clusters update atelier --zone=$Z --maintenance-window-start=2026-11-14T01:00:00Z \
  --maintenance-window-end=2026-11-14T05:00:00Z --maintenance-window-recurrence="FREQ=WEEKLY;BYDAY=SA,SU" 2>&1 | tail -1 | cut -c1-200
gcloud container clusters describe atelier --zone=$Z --format="yaml(maintenancePolicy.window)"
echo "== Stratégie de mise à jour du pool par défaut"
gcloud container node-pools describe default-pool --cluster=atelier --zone=$Z --format="yaml(upgradeSettings,management)"
echo "== PodDisruptionBudget"
kubectl apply -f k8s/module-04/pdb-worker.yaml
sleep 5
kubectl get pdb
echo "== On vide le node Spot"
SPOT=$(kubectl get nodes -l cloud.google.com/gke-spot=true -o name | head -1)
timeout 45 kubectl drain $SPOT --ignore-daemonsets --delete-emptydir-data 2>&1 | grep -v -i daemonset | cut -c1-230 | head -6
kubectl get pods -l app=worker -o custom-columns='POD:.metadata.name,ETAT:.status.phase,NODE:.spec.nodeName'
kubectl uncordon $SPOT
