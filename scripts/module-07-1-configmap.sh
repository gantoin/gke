#!/usr/bin/env bash
# Leçon 7.1 : la configuration de l'API dans un ConfigMap, et le piège du ConfigMap modifié
# Usage : bash scripts/module-07-1-configmap.sh image|demo
set -u
P=$(gcloud config get-value project 2>/dev/null)
IMG=europe-west1-docker.pkg.dev/$P/formation-images/api-catalogue:v4
ouvrir() { pkill -f "port-forward service/api-catalogue" 2>/dev/null; kubectl port-forward service/api-catalogue 8080:80 -n ${1:-boutique} >/dev/null 2>&1 & sleep 4; }
case "${1:-}" in
image)
  # L'image v4 affiche deux réglages dans /api/info : un message et une devise
  gcloud auth configure-docker europe-west1-docker.pkg.dev -q 2>/dev/null
  docker build -q --build-arg APP_VERSION=v4 -t $IMG app/api-catalogue && docker push -q $IMG
  ;;
demo)
  kubectl apply -f k8s/module-07/configmap.yaml
  kubectl delete deployment api-catalogue -n boutique --ignore-not-found
  sed "s/PROJECT_ID/$P/" k8s/module-07/api-catalogue-config.yaml | kubectl apply -f -
  kubectl rollout status deployment api-catalogue -n boutique --timeout=400s | tail -1
  POD=$(kubectl get pods -n boutique -l app=api-catalogue -o jsonpath='{.items[0].metadata.name}')
  echo "== Façon 1 : une variable d'environnement"
  kubectl exec $POD -n boutique -- printenv BOUTIQUE_MESSAGE
  echo "== Façon 2 : un fichier"
  kubectl exec $POD -n boutique -- cat /config/application.properties
  ouvrir
  echo "== L'API"
  curl -s localhost:8080/api/info; echo
  echo "== Le piège : on change le message dans le ConfigMap"
  kubectl patch configmap api-catalogue-config -n boutique --type merge -p '{"data":{"BOUTIQUE_MESSAGE":"Soldes : -20 % sur tout"}}'
  sleep 20
  curl -s localhost:8080/api/info; echo
  echo "== On redémarre les pods"
  kubectl rollout restart deployment api-catalogue -n boutique
  kubectl rollout status deployment api-catalogue -n boutique --timeout=400s | tail -1
  ouvrir
  curl -s localhost:8080/api/info; echo
  pkill -f "port-forward service/api-catalogue" 2>/dev/null
  ;;
*) echo "Usage : bash $0 image|demo" ;;
esac
