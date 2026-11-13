#!/usr/bin/env bash
# Leçons 7.3 et 7.4 : le mot de passe de la base dans Secret Manager, lu sans aucune clé
# Usage : bash scripts/module-07-3-secret-manager.sh activer|secret|deployer|autoriser|verifier|menage
# À lancer après : bash scripts/module-07-1-configmap.sh image
set -u
P=$(gcloud config get-value project 2>/dev/null)
PN=$(gcloud projects describe $P --format="value(projectNumber)")
S=boutique-db-mot-de-passe
MEMBRE="principal://iam.googleapis.com/projects/$PN/locations/global/workloadIdentityPools/$P.svc.id.goog/subject/ns/boutique/sa"
ouvrir() { pkill -f "port-forward service/api-catalogue" 2>/dev/null; kubectl port-forward service/api-catalogue 8080:80 -n ${1:-boutique} >/dev/null 2>&1 & sleep 4; }
case "${1:-}" in
activer)
  # Une vingtaine de minutes sur le cluster du cours
  gcloud services enable secretmanager.googleapis.com
  gcloud container clusters update formation --region=europe-west1 --enable-secret-manager
  ;;
secret)
  # Un mot de passe au hasard, qui ne passe ni par un fichier ni par l'historique du terminal
  openssl rand -base64 18 | tr -d '\n' | gcloud secrets create $S --replication-policy=automatic --data-file=-
  gcloud secrets list --format="table(name,createTime.date('%Y-%m-%d'))"
  gcloud secrets versions list $S --format="table(name,state)"
  ;;
deployer)
  kubectl apply -f k8s/module-07/configmap.yaml
  kubectl apply -f k8s/module-07/secrets/01-comptes.yaml
  sed "s/PROJECT_ID/$P/" k8s/module-07/secrets/02-secret-provider.yaml | kubectl apply -f -
  kubectl apply -f k8s/module-07/secrets/03-postgres.yaml
  kubectl apply -f k8s/module-05/netpol-postgres.yaml
  kubectl delete deployment api-catalogue -n boutique --ignore-not-found
  sed "s/PROJECT_ID/$P/" k8s/module-07/secrets/04-api-catalogue.yaml | kubectl apply -f -
  echo "== On attend une minute"
  sleep 75
  kubectl get pods -n boutique
  echo "== Pourquoi ?"
  kubectl get events -n boutique --field-selector reason=FailedMount --sort-by=.lastTimestamp -o custom-columns='POD:.involvedObject.name,MESSAGE:.message' | tail -2 | cut -c1-600
  ;;
autoriser)
  # On donne à chaque identité Kubernetes le droit de lire ce secret, et seulement celui-là
  for SA in api-catalogue postgres; do
    gcloud secrets add-iam-policy-binding $S --role=roles/secretmanager.secretAccessor --member="$MEMBRE/$SA" --format="value(etag)" >/dev/null && echo "Droit donné à $SA"
  done
  gcloud secrets get-iam-policy $S --format="table(bindings.role,bindings.members.flatten())"
  ;;
verifier)
  echo "== On attend que les pods démarrent"
  for i in $(seq 1 60); do
    [ "$(kubectl get statefulset postgres -n boutique -o jsonpath='{.status.readyReplicas}')" = "1" ] && [ "$(kubectl get deployment api-catalogue -n boutique -o jsonpath='{.status.readyReplicas}')" = "2" ] && break
    sleep 10
  done
  kubectl get pods -n boutique
  ouvrir
  echo "== L'API parle à la base"
  curl -s localhost:8080/api/info; echo
  curl -s localhost:8080/api/produits | cut -c1-160; echo
  echo "== Aucun Secret Kubernetes, aucune clé"
  kubectl get secrets -n boutique
  gcloud iam service-accounts keys list --iam-account=$PN-compute@developer.gserviceaccount.com --managed-by=user
  POD=$(kubectl get pods -n boutique -l app=api-catalogue -o jsonpath='{.items[0].metadata.name}')
  echo "== Le fichier dans le pod (on compte les caractères, on ne l'affiche pas)"
  kubectl exec $POD -n boutique -- sh -c 'ls /var/secrets; wc -c < /var/secrets/DB_PASSWORD'
  pkill -f "port-forward service/api-catalogue" 2>/dev/null
  ;;
menage)
  pkill -f "port-forward service/api-catalogue" 2>/dev/null
  kubectl delete -f k8s/module-07/secrets/03-postgres.yaml --ignore-not-found
  kubectl delete pvc data-postgres-0 -n boutique --ignore-not-found
  kubectl delete secretproviderclass boutique-secrets -n boutique --ignore-not-found
  kubectl delete networkpolicy postgres-seulement-api -n boutique --ignore-not-found
  kubectl delete configmap api-catalogue-config -n boutique --ignore-not-found
  kubectl delete deployment api-catalogue -n boutique --ignore-not-found
  kubectl delete -f k8s/module-07/secrets/01-comptes.yaml --ignore-not-found
  sed "s/PROJECT_ID/$P/" k8s/api-catalogue/deployment.yaml | kubectl apply -f -
  kubectl scale deployment api-catalogue -n boutique --replicas=0
  gcloud secrets delete $S --quiet
  ;;
*) echo "Usage : bash $0 activer|secret|deployer|autoriser|verifier|menage" ;;
esac
