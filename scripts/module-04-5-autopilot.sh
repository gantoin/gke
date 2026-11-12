#!/usr/bin/env bash
# Leçon 4.5 : ce qu'Autopilot refuse
set -u
gcloud container clusters get-credentials formation --region=europe-west1 2>&1 | tail -1
echo "== Un pod privilégié sur Autopilot"
kubectl apply -f k8s/module-04/autopilot-interdit.yaml 2>&1 | fold -w 150 | head -12
echo "== Le même pod sur le cluster Standard"
gcloud container clusters get-credentials atelier --zone=europe-west1-b 2>&1 | tail -1
kubectl apply -f k8s/module-04/autopilot-interdit.yaml
sleep 15
kubectl get pod pod-interdit
kubectl delete pod pod-interdit --wait=false
