#!/usr/bin/env bash
# Leçon 5.7 : un cluster dont les machines n'ont pas d'adresse publique
# Créez d'abord le cluster (une dizaine de minutes) :
#   gcloud container clusters create-auto prive --region=europe-west1 --enable-private-nodes
set -u
R=europe-west1
gcloud container clusters get-credentials prive --region=$R 2>&1 | tail -1
echo "== Réglages du cluster"
gcloud container clusters describe prive --region=$R --format="yaml(privateClusterConfig.enablePrivateNodes,privateClusterConfig.privateEndpoint,privateClusterConfig.publicEndpoint)" | sed 's/\(Endpoint: [0-9]*\.[0-9]*\)\.[0-9]*\.[0-9]*/\1.x.x/'
echo "== On déploie l'API"
kubectl apply -f k8s/api-catalogue
kubectl rollout status deployment api-catalogue -n boutique --timeout=400s | tail -1
echo "== Les machines"
kubectl get nodes -o custom-columns='NODE:.metadata.name,ADRESSE_INTERNE:.status.addresses[?(@.type=="InternalIP")].address,ADRESSE_EXTERNE:.status.addresses[?(@.type=="ExternalIP")].address'
echo "== Ménage"
gcloud container clusters delete prive --region=$R --quiet 2>&1 | tail -1 | cut -c1-200
gcloud container clusters get-credentials formation --region=$R 2>&1 | tail -1
