#!/usr/bin/env bash
# Leçon 6.3 : PostgreSQL sur GKE, branché à l'API catalogue
# Usage : bash scripts/module-06-3-postgres.sh image|base|api|test|menage
set -u
P=$(gcloud config get-value project 2>/dev/null)
IMG=europe-west1-docker.pkg.dev/$P/formation-images/api-catalogue:v3
# Une porte temporaire vers l'API, depuis ce terminal
ouvrir() { pkill -f "port-forward service/api-catalogue" 2>/dev/null; kubectl port-forward service/api-catalogue 8080:80 -n boutique >/dev/null 2>&1 & sleep 4; }
case "${1:-}" in
image)
  # L'image v3 de l'API sait ranger ses produits dans PostgreSQL
  gcloud auth configure-docker europe-west1-docker.pkg.dev -q 2>/dev/null
  docker build -q --build-arg APP_VERSION=v3 -t $IMG app/api-catalogue && docker push -q $IMG
  ;;
base)
  kubectl delete -f k8s/module-05/postgres.yaml --ignore-not-found 2>/dev/null
  kubectl apply -f k8s/module-06/postgres
  kubectl apply -f k8s/module-05/netpol-postgres.yaml
  echo "== On attend la base"
  for i in $(seq 1 60); do
    kubectl get pod postgres-0 -n boutique --no-headers 2>/dev/null | awk '{print $1, $2, $3}'
    [ "$(kubectl get statefulset postgres -n boutique -o jsonpath='{.status.readyReplicas}')" = "1" ] && break
    sleep 10
  done
  kubectl get pods,pvc -n boutique
  ;;
api)
  sed "s/PROJECT_ID/$P/" k8s/module-06/api-catalogue-postgres.yaml | kubectl apply -f -
  kubectl rollout status deployment api-catalogue -n boutique --timeout=400s | tail -1
  echo "== Les journaux de l'API"
  kubectl logs deployment/api-catalogue -n boutique | grep -E "HikariPool|profile" | cut -c1-160
  ouvrir
  echo "== L'API"
  curl -s localhost:8080/api/info; echo
  curl -s localhost:8080/api/produits; echo
  ;;
test)
  ouvrir
  echo "== On ajoute un produit témoin"
  curl -s -X POST localhost:8080/api/produits -H "Content-Type: application/json" \
    -d '{"nom":"Produit crash-test","categorie":"Test","prix":1.00}'; echo
  echo "== On supprime le pod de la base"
  kubectl delete pod postgres-0 -n boutique
  sleep 2
  echo "== Pendant la coupure"
  curl -s -m 8 -o /dev/null -w "code HTTP : %{http_code}\n" localhost:8080/api/produits
  S=$(date +%s)
  sleep 5
  kubectl wait pod postgres-0 -n boutique --for=condition=Ready --timeout=300s
  for i in $(seq 1 30); do [ "$(curl -s -m 5 -o /dev/null -w '%{http_code}' localhost:8080/api/produits)" = "200" ] && break; sleep 3; done
  echo "La base répond de nouveau au bout de $(( $(date +%s) - S )) secondes"
  kubectl get pods,pvc -n boutique -l app=postgres
  echo "== Le produit témoin est toujours là"
  curl -s localhost:8080/api/produits; echo
  ;;
menage)
  pkill -f "port-forward service/api-catalogue" 2>/dev/null
  kubectl scale deployment api-catalogue -n boutique --replicas=0
  kubectl delete -f k8s/module-06/postgres
  kubectl delete pvc data-postgres-0 -n boutique
  ;;
*) echo "Usage : bash $0 image|base|api|test|menage" ;;
esac
