#!/usr/bin/env bash
# Leçon 5.1 : les plages d'adresses du cluster et les adresses des pods
set -u
R=europe-west1
gcloud container clusters get-credentials formation --region=$R 2>&1 | tail -1
kubectl scale deployment api-catalogue -n boutique --replicas=3
kubectl rollout status deployment api-catalogue -n boutique --timeout=300s | tail -1
echo "== Les plages d'adresses du cluster"
gcloud container clusters describe formation --region=$R --format="table(subnetwork,clusterIpv4Cidr:label=PODS,servicesIpv4Cidr:label=SERVICES,networkConfig.datapathProvider:label=DATAPLANE)"
gcloud compute networks subnets describe default --region=$R --format="table(name,ipCidrRange:label=NODES)"
echo "== Les adresses des pods"
kubectl get pods -n boutique -o custom-columns='POD:.metadata.name,ADRESSE:.status.podIP,NODE:.spec.nodeName'
echo "== L'adresse du service"
kubectl get service api-catalogue -n boutique
