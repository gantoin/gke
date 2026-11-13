#!/usr/bin/env bash
# Leçon 7.5 : une base commune, et un dossier par environnement, avec Kustomize
# Usage : bash scripts/module-07-5-kustomize.sh demo|menage
set -u
P=$(gcloud config get-value project 2>/dev/null)
K=k8s/module-07/kustomize
sed -i "s/PROJECT_ID/$P/" $K/base/deployment.yaml
case "${1:-}" in
demo)
  echo "== Les fichiers"
  find $K -type f | sort
  echo "== Ce que Kustomize fabrique pour dev (extrait)"
  kubectl kustomize $K/overlays/dev | grep -E "^kind:|namespace:|replicas:|BOUTIQUE_MESSAGE|  name: api-catalogue-config" | uniq
  echo "== On déploie les deux environnements"
  kubectl apply -k $K/overlays/dev
  kubectl apply -k $K/overlays/prod
  kubectl rollout status deployment api-catalogue -n boutique-dev --timeout=400s | tail -1
  kubectl rollout status deployment api-catalogue -n boutique-prod --timeout=400s | tail -1
  kubectl get deployments -A -l app=api-catalogue
  kubectl get configmaps -n boutique-dev -o name | grep api; kubectl get configmaps -n boutique-prod -o name | grep api
  for E in dev prod; do
    pkill -f "port-forward service/api-catalogue" 2>/dev/null; kubectl port-forward service/api-catalogue 8080:80 -n boutique-$E >/dev/null 2>&1 & sleep 4
    echo "== $E"; curl -s localhost:8080/api/info; echo
  done
  echo "== On change le message de dev : le ConfigMap change de nom, les pods sont remplacés tout seuls"
  sed -i "s/BOUTIQUE_MESSAGE=Boutique de test/BOUTIQUE_MESSAGE=Boutique de test, version 2/" $K/overlays/dev/kustomization.yaml
  kubectl apply -k $K/overlays/dev
  kubectl rollout status deployment api-catalogue -n boutique-dev --timeout=400s | tail -1
  kubectl get configmaps -n boutique-dev -o name | grep api
  pkill -f "port-forward service/api-catalogue" 2>/dev/null; kubectl port-forward service/api-catalogue 8080:80 -n boutique-dev >/dev/null 2>&1 & sleep 4
  curl -s localhost:8080/api/info; echo
  pkill -f "port-forward service/api-catalogue" 2>/dev/null
  git checkout -- $K/overlays/dev/kustomization.yaml 2>/dev/null
  ;;
menage)
  kubectl delete namespace boutique-dev boutique-prod
  ;;
*) echo "Usage : bash $0 demo|menage" ;;
esac
