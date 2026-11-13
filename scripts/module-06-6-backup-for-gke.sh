#!/usr/bin/env bash
# Leçon 6.5 : Backup for GKE : sauvegarder tout le namespace, le supprimer, le restaurer
# Usage : bash scripts/module-06-6-backup-for-gke.sh activer|plan|sauvegarde|sinistre|restauration|menage
# À lancer après scripts/module-06-3-postgres.sh (image, base, api)
set -u
P=$(gcloud config get-value project 2>/dev/null)
L=europe-west1
C=projects/$P/locations/$L/clusters/formation
BR="gcloud beta container backup-restore"
case "${1:-}" in
activer)
  # Une vingtaine de minutes sur le cluster du cours
  gcloud services enable gkebackup.googleapis.com
  gcloud container clusters update formation --region=$L --update-addons=BackupRestore=ENABLED
  ;;
plan)
  # Tout le namespace boutique, avec ses disques et ses secrets, chaque nuit à 3 h, gardé 30 jours
  $BR backup-plans create boutique --project=$P --location=$L --cluster=$C \
    --selected-namespaces=boutique --include-secrets --include-volume-data \
    --cron-schedule="0 3 * * *" --backup-retain-days=30
  $BR backup-plans list --project=$P --location=$L
  ;;
sauvegarde)
  S=$(date +%s)
  $BR backups create manuelle-1 --project=$P --location=$L --backup-plan=boutique --wait-for-completion
  echo "Sauvegarde terminée en $(( $(date +%s) - S )) secondes"
  $BR backups list --project=$P --location=$L --backup-plan=boutique \
    --format="table(name.basename(),state,resourceCount,volumeCount,sizeBytes)"
  ;;
sinistre)
  kubectl get pods,pvc -n boutique
  kubectl delete namespace boutique
  kubectl get namespace boutique
  ;;
restauration)
  $BR restore-plans create boutique --project=$P --location=$L --cluster=$C \
    --backup-plan=projects/$P/locations/$L/backupPlans/boutique \
    --selected-namespaces=boutique --namespaced-resource-restore-mode=fail-on-conflict \
    --volume-data-restore-policy=restore-volume-data-from-backup \
    --cluster-resource-conflict-policy=use-existing-version
  S=$(date +%s)
  $BR restores create restauration-1 --project=$P --location=$L --restore-plan=boutique \
    --backup=projects/$P/locations/$L/backupPlans/boutique/backups/manuelle-1 --wait-for-completion
  echo "Restauration terminée en $(( $(date +%s) - S )) secondes"
  echo "== On attend la base"
  for i in $(seq 1 60); do [ "$(kubectl get statefulset postgres -n boutique -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "1" ] && break; sleep 10; done
  kubectl get pods,pvc -n boutique
  echo "== Les données"
  kubectl exec postgres-0 -n boutique -- psql -U boutique -d boutique -c "SELECT id, nom, prix FROM produits ORDER BY id"
  ;;
menage)
  $BR restores delete restauration-1 --project=$P --location=$L --restore-plan=boutique --quiet
  $BR restore-plans delete boutique --project=$P --location=$L --quiet
  $BR backups delete manuelle-1 --project=$P --location=$L --backup-plan=boutique --quiet
  $BR backup-plans delete boutique --project=$P --location=$L --quiet
  ;;
*) echo "Usage : bash $0 activer|plan|sauvegarde|sinistre|restauration|menage" ;;
esac
