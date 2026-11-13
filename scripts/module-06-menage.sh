#!/usr/bin/env bash
# Module 6 : tout supprimer à la fin de la séance, et remettre l'API du module 3 à zéro pod
set -u
bash scripts/module-06-6-backup-for-gke.sh menage
bash scripts/module-06-3-postgres.sh menage
kubectl delete networkpolicy postgres-seulement-api -n boutique --ignore-not-found
kubectl delete volumesnapshot --all -n boutique
kubectl delete volumesnapshotclass photo-disque --ignore-not-found
P=$(gcloud config get-value project 2>/dev/null)
# On repart du Deployment du module 3 (sans les variables de la base)
kubectl delete deployment api-catalogue -n boutique --ignore-not-found
sed "s/PROJECT_ID/$P/" k8s/api-catalogue/deployment.yaml | kubectl apply -f -
kubectl scale deployment api-catalogue -n boutique --replicas=0
sleep 60
echo "== Ce qui reste dans le namespace"
kubectl get all,pvc,secret,networkpolicy -n boutique
echo "== Les disques et les photos qui restent chez Google (rien, si tout va bien)"
gcloud compute disks list --filter="name~^pvc-" --format="value(name,sizeGb)"
gcloud compute snapshots list --format="value(name)"
gcloud beta container backup-restore backup-plans list --location=europe-west1
echo FIN
