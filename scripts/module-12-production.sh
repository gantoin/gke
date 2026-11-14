#!/usr/bin/env bash
# Module 12 : coûts, production et bonnes pratiques
# Usage : bash scripts/module-12-production.sh couts|checklist|quotas|inventaire|menage|nettoyage-complet
set -u
P=$(gcloud config get-value project 2>/dev/null)
ok()  { printf "  %-44s %s\n" "$1" "OK"; }
ko()  { printf "  %-44s %s\n" "$1" "A FAIRE  ($2)"; }
champ() { kubectl get deployment api-catalogue -n boutique -o jsonpath="$1" 2>/dev/null; }
case "${1:-}" in
couts)
  echo "== La boutique en service : 2 pods"
  sed "s/PROJECT_ID/$P/" k8s/module-09/api-catalogue.yaml | kubectl apply -f - >/dev/null
  kubectl rollout status deployment api-catalogue -n boutique --timeout=400s | tail -1
  sleep 90
  echo "== Ce que les pods demandent (sur Autopilot : ce que vous payez)"
  kubectl get pods -n boutique -l app=api-catalogue -o custom-columns='POD:.metadata.name,CPU_DEMANDE:.spec.containers[0].resources.requests.cpu,MEMOIRE_DEMANDEE:.spec.containers[0].resources.requests.memory'
  echo "== Ce qu'ils consomment vraiment"
  kubectl top pods -n boutique -l app=api-catalogue
  echo "== Les machines du cluster"
  kubectl get nodes -o custom-columns='MACHINE:.metadata.name,TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,SPOT:.metadata.labels.cloud\.google\.com/gke-spot,ZONE:.metadata.labels.topology\.kubernetes\.io/zone'
  ;;
checklist)
  echo "== La boutique, passée en revue"
  echo "Fiabilité"
  R=$(champ '{.spec.replicas}'); [ "${R:-0}" -ge 2 ] && ok "Au moins 2 pods" || ko "Au moins 2 pods" "replicas: $R"
  [ -n "$(champ '{.spec.template.spec.containers[0].readinessProbe}')" ] && ok "Une sonde readiness" || ko "Une sonde readiness" "module 3"
  [ -n "$(champ '{.spec.template.spec.containers[0].livenessProbe}')" ] && ok "Une sonde liveness" || ko "Une sonde liveness" "module 3"
  [ -n "$(champ '{.spec.template.spec.containers[0].resources.requests.cpu}')" ] && ok "Des requests" || ko "Des requests" "module 3"
  [ -n "$(kubectl get pdb -n boutique -o name 2>/dev/null)" ] && ok "Un PodDisruptionBudget" || ko "Un PodDisruptionBudget" "module 8"
  [ -n "$(kubectl get hpa -n boutique -o name 2>/dev/null)" ] && ok "Un autoscaler (HPA)" || ko "Un autoscaler (HPA)" "module 8"
  echo "Sécurité"
  [ "$(champ '{.spec.template.spec.securityContext.runAsNonRoot}')" = "true" ] && ok "Pas de root" || ko "Pas de root" "module 10"
  [ "$(champ '{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}')" = "true" ] && ok "Système de fichiers en lecture seule" || ko "Système de fichiers en lecture seule" "module 10"
  [ -n "$(kubectl get networkpolicy -n boutique -o name 2>/dev/null)" ] && ok "Des Network Policies" || ko "Des Network Policies" "module 10"
  I=$(champ '{.spec.template.spec.containers[0].image}'); case "$I" in *:latest|*/api-catalogue) ko "Une image avec une version précise" "latest";; *) ok "Une image avec une version précise";; esac
  echo "Exploitation"
  [ -n "$(kubectl get podmonitoring -n boutique -o name 2>/dev/null)" ] && ok "Des métriques collectées" || ko "Des métriques collectées" "module 9"
  [ -n "$(gcloud alpha monitoring policies list --format='value(name)' 2>/dev/null | head -1)" ] && ok "Au moins une alerte" || ko "Au moins une alerte" "module 9"
  ;;
quotas)
  echo "== Un namespace pour une équipe, avec un budget"
  kubectl create namespace equipe-dev 2>/dev/null
  kubectl apply -f k8s/module-12/quotas.yaml
  echo "== L'équipe demande 5 pods"
  kubectl apply -f k8s/module-12/essai.yaml
  sleep 20
  kubectl get deployment essai -n equipe-dev
  echo "== Pourquoi seulement 3 ?"
  kubectl get events -n equipe-dev --field-selector reason=FailedCreate -o custom-columns='MESSAGE:.message' | tail -1 | fold -w 100
  echo "== Le budget, et ce qui est consommé"
  kubectl describe resourcequota budget-equipe -n equipe-dev | tail -5
  ;;
inventaire)
  echo "== Ce qui existe dans le projet, et qui peut coûter"
  echo "-- Clusters";            gcloud container clusters list --format="table(name,location,autopilot.enabled:label=AUTOPILOT,status)" 2>/dev/null
  echo "-- Disques";             gcloud compute disks list --format="table(name,sizeGb,zone.basename())" 2>/dev/null | grep -v "^gke-.*-pvc-" | head -8
  echo "-- Adresses IP réservées"; gcloud compute addresses list --format="table(name,region.basename(),status)" 2>/dev/null
  echo "-- Load balancers";      gcloud compute forwarding-rules list --format="table(name,region.basename(),loadBalancingScheme)" 2>/dev/null
  echo "-- Cloud SQL";           gcloud sql instances list --format="table(name,region,state)" 2>/dev/null </dev/null
  echo "-- Dépôts d'images";     gcloud artifacts repositories list --format="table(name.basename(),location,sizeBytes.size())" 2>/dev/null
  echo "-- Buckets";             gcloud storage buckets list --format="value(name)" 2>/dev/null
  echo "-- Zones DNS";           gcloud dns managed-zones list --format="value(name)" 2>/dev/null </dev/null
  ;;
menage)
  kubectl delete namespace equipe-dev --ignore-not-found --wait=false
  kubectl scale deployment api-catalogue -n boutique --replicas=0
  ;;
nettoyage-complet)
  # La fin du cours : on supprime tout ce qui coûte. Rien n'est récupérable.
  [ "${2:-}" = "oui" ] || { echo "Cette commande supprime le cluster et le dépôt d'images. Pour confirmer : bash $0 nettoyage-complet oui"; exit 1; }
  echo "== Le cluster"
  gcloud container clusters delete formation --region=europe-west1 -q
  echo "== Le dépôt d'images"
  gcloud artifacts repositories delete formation-images --location=europe-west1 -q
  echo "== Le bucket de Cloud Build"
  gcloud storage rm -r gs://${P}_cloudbuild 2>&1 | tail -1
  echo "== Ce qu'il reste"
  bash $0 inventaire
  ;;
*) echo "Usage : bash $0 couts|checklist|quotas|inventaire|menage|nettoyage-complet" ;;
esac
