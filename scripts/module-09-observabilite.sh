#!/usr/bin/env bash
# Module 9 : observabilité (logs, métriques, alertes, Prometheus, debugging)
# Usage : bash scripts/module-09-observabilite.sh image|deployer|collecte|logs|alertes|prometheus|pannes|menage
set -u
P=$(gcloud config get-value project 2>/dev/null)
K=k8s/module-09
IMG=europe-west1-docker.pkg.dev/$P/formation-images/api-catalogue:v5
FILTRE='resource.type="k8s_container" AND resource.labels.namespace_name="boutique" AND jsonPayload.level="ERROR"'
ouvrir() { pkill -f "port-forward service/api-catalogue" 2>/dev/null; kubectl port-forward service/api-catalogue 8080:80 -n boutique >/dev/null 2>&1 & sleep 4; }
promql() { curl -s -G -H "Authorization: Bearer $(gcloud auth print-access-token)" "https://monitoring.googleapis.com/v1/projects/$P/location/global/prometheus/api/v1/query" --data-urlencode "query=$1"; }
case "${1:-}" in
image)
  # L'image v5 : Spring Boot 3.4 (logs en JSON), métriques Prometheus, et un endpoint qui écrit une erreur
  gcloud auth configure-docker europe-west1-docker.pkg.dev -q 2>/dev/null
  docker build -q --build-arg APP_VERSION=v5 -t $IMG app/api-catalogue && docker push -q $IMG
  ;;
deployer)
  kubectl delete deployment api-catalogue -n boutique --ignore-not-found
  sed "s/PROJECT_ID/$P/" $K/api-catalogue.yaml | kubectl apply -f -
  kubectl rollout status deployment api-catalogue -n boutique --timeout=400s | tail -1
  ouvrir
  echo "== Un peu de trafic, et trois erreurs"
  for i in $(seq 1 20); do curl -s -o /dev/null localhost:8080/api/produits; done
  curl -s -X POST -H "Content-Type: application/json" -d '{"nom":"Clavier","categorie":"informatique","prix":49.90}' localhost:8080/api/produits; echo
  for i in 1 2 3; do curl -s -X POST localhost:8080/api/test/erreur; echo; done
  pkill -f "port-forward service/api-catalogue" 2>/dev/null
  ;;
collecte)
  echo "== Ce que le cluster collecte tout seul"
  gcloud container clusters describe formation --region=europe-west1 --format="yaml(loggingConfig,monitoringConfig)"
  ;;
logs)
  POD=$(kubectl get pods -n boutique -l app=api-catalogue -o jsonpath='{.items[0].metadata.name}')
  echo "== Les logs de l'API : une ligne de JSON par message"
  kubectl logs -n boutique -l app=api-catalogue --tail=200 | grep -E "Produit ajouté|Paiement refusé" | head -2
  echo "== Les erreurs de la boutique, dans Cloud Logging"
  gcloud logging read "$FILTRE" --freshness=30m --limit=5 --format="table(timestamp.date('%H:%M:%S'),resource.labels.pod_name,jsonPayload.level,jsonPayload.message)"
  echo "== Une métrique qui compte ces erreurs"
  gcloud logging metrics create boutique-erreurs --description="Erreurs dans les logs de la boutique" --log-filter="$FILTRE"
  gcloud logging metrics list --format="table(name,filter)" | cut -c1-150
  ;;
alertes)
  echo "== Un tableau de bord"
  gcloud monitoring dashboards create --config-from-file=$K/tableau-de-bord.json --format="value(displayName,name)"
  echo "== Une alerte : un conteneur qui redémarre trop souvent"
  curl -s -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" -d @$K/alerte.json "https://monitoring.googleapis.com/v3/projects/$P/alertPolicies" | grep -E '"name"|"displayName"|"code"|"message"' | head -6
  gcloud monitoring dashboards list --format="table(displayName)"
  ;;
prometheus)
  POD=$(kubectl get pods -n boutique -l app=api-catalogue -o jsonpath='{.items[0].metadata.name}')
  echo "== Les métriques exposées par l'API"
  kubectl port-forward $POD 8081:8080 -n boutique >/dev/null 2>&1 & sleep 4
  curl -s localhost:8081/actuator/prometheus | grep -E '^http_server_requests_seconds_count|^jvm_memory_used_bytes\{area="heap"' | head -6
  pkill -f "port-forward $POD" 2>/dev/null
  echo "== On demande à Prometheus managé de venir les lire"
  kubectl apply -f $K/podmonitoring.yaml
  ouvrir
  for i in $(seq 1 30); do curl -s -o /dev/null localhost:8080/api/produits 2>/dev/null; sleep 6; done
  pkill -f "port-forward service/api-catalogue" 2>/dev/null
  kubectl get podmonitoring -n boutique
  echo "== Une requête PromQL : les demandes reçues, par adresse et par code de réponse"
  promql 'sum by (uri, status) (http_server_requests_seconds_count{namespace="boutique"})'; echo
  echo "== La mémoire Java utilisée, par pod (en Mo)"
  promql 'sum by (pod) (jvm_memory_used_bytes{namespace="boutique", area="heap"}) / 1024 / 1024'; echo
  ;;
pannes)
  sed "s/PROJECT_ID/$P/" $K/pannes.yaml | kubectl apply -f -
  echo "On attend trois minutes..."; sleep 180
  kubectl get pods -n boutique -l lab=pannes
  for n in 1 2 3 4; do
    echo "== panne-$n : les événements"
    kubectl get events -n boutique --field-selector involvedObject.name=panne-$n --sort-by=.lastTimestamp -o custom-columns='TYPE:.type,RAISON:.reason,MESSAGE:.message' | tail -3 | cut -c1-230
  done
  echo "== panne-2 : les logs du conteneur précédent"
  kubectl logs panne-2 -n boutique --previous
  echo "== panne-3 : le dernier arrêt du conteneur"
  kubectl get pod panne-3 -n boutique -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}{"  code de sortie : "}{.status.containerStatuses[0].lastState.terminated.exitCode}{"\n"}'
  echo "== Un conteneur d'enquête, ajouté à un pod de l'API"
  POD=$(kubectl get pods -n boutique -l app=api-catalogue -o jsonpath='{.items[0].metadata.name}')
  kubectl debug $POD -n boutique --image=busybox:1.36 --container=enquete --target=api-catalogue -- sh -c "wget -qO- localhost:8080/actuator/health; echo; ps | head -5"
  sleep 25
  kubectl logs $POD -n boutique -c enquete
  ;;
menage)
  kubectl delete pod -n boutique -l lab=pannes --ignore-not-found --wait=false
  kubectl delete -f $K/podmonitoring.yaml --ignore-not-found
  gcloud logging metrics delete boutique-erreurs -q
  for d in $(gcloud monitoring dashboards list --filter="displayName=Boutique" --format="value(name)"); do gcloud monitoring dashboards delete $d -q; done
  T=$(gcloud auth print-access-token)
  # On ne supprime que l'alerte créée par ce module
  for a in $(curl -s -G -H "Authorization: Bearer $T" "https://monitoring.googleapis.com/v3/projects/$P/alertPolicies" --data-urlencode 'filter=display_name="Boutique : un conteneur redémarre trop souvent"' | grep -o 'projects/[^"]*/alertPolicies/[0-9]*"' | tr -d '"' | sort -u); do curl -s -X DELETE -H "Authorization: Bearer $T" "https://monitoring.googleapis.com/v3/$a"; echo " alerte supprimée : $a"; done
  kubectl delete deployment api-catalogue -n boutique --ignore-not-found
  sed "s/PROJECT_ID/$P/" k8s/api-catalogue/deployment.yaml | kubectl apply -f -
  kubectl scale deployment api-catalogue -n boutique --replicas=0
  ;;
*) echo "Usage : bash $0 image|deployer|collecte|logs|alertes|prometheus|pannes|menage" ;;
esac
