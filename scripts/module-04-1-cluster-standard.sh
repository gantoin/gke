#!/usr/bin/env bash
# Leçon 4.1 : créer le cluster Standard "atelier" et regarder ses machines
set -u
Z=europe-west1-b
echo "== Quotas de la région (essai gratuit)"
gcloud compute regions describe europe-west1 --format=json | python3 -c "
import json,sys
for q in json.load(sys.stdin)['quotas']:
    if q['metric'] in ('CPUS','DISKS_TOTAL_GB','SSD_TOTAL_GB','IN_USE_ADDRESSES','INSTANCES'): print(q['metric'], int(q['usage']), '/', int(q['limit']))"
gcloud compute project-info describe --format=json | python3 -c "
import json,sys
for q in json.load(sys.stdin)['quotas']:
    if q['metric'] in ('CPUS_ALL_REGIONS',): print(q['metric'], int(q['usage']), '/', int(q['limit']))"
echo "== Création du cluster"
gcloud container clusters create atelier --zone=$Z --num-nodes=2 --machine-type=e2-standard-2 \
  --release-channel=regular --disk-type=pd-standard --disk-size=50 2>&1 | tail -4 | cut -c1-200
gcloud container clusters get-credentials atelier --zone=$Z 2>&1 | tail -1
echo "== Contextes"
kubectl config get-contexts -o name
echo "== Nodes"
kubectl get nodes
echo "== Machines virtuelles"
gcloud compute instances list --format="table(name,zone.basename(),machineType.basename(),status)"
echo "== Capacity et Allocatable"
N=$(kubectl get nodes -o name | head -1)
kubectl get $N -o custom-columns='CPU:.status.capacity.cpu,CPU_UTILISABLE:.status.allocatable.cpu,MEMOIRE:.status.capacity.memory,MEMOIRE_UTILISABLE:.status.allocatable.memory'
