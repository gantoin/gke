#!/usr/bin/env bash
# Leçon 6.5 : une photo du disque de PostgreSQL, un accident, une restauration
# À lancer après scripts/module-06-3-postgres.sh (image, base, api)
set -u
ouvrir() { pkill -f "port-forward service/api-catalogue" 2>/dev/null; kubectl port-forward service/api-catalogue 8080:80 -n boutique >/dev/null 2>&1 & sleep 4; }
SQL="kubectl exec postgres-0 -n boutique -- psql -U boutique -d boutique -c"
ouvrir
echo "== Avant"
curl -s localhost:8080/api/produits | cut -c1-200; echo
echo "== La photo du disque"
$SQL "CHECKPOINT" >/dev/null
kubectl apply -f k8s/module-06/snapshot.yaml
for i in $(seq 1 60); do [ "$(kubectl get volumesnapshot postgres-avant-accident -n boutique -o jsonpath='{.status.readyToUse}')" = "true" ] && break; sleep 5; done
kubectl get volumesnapshot -n boutique
echo "== L'accident"
$SQL "DROP TABLE produits"
curl -s -m 8 -o /dev/null -w "code HTTP : %{http_code}\n" localhost:8080/api/produits
echo "== La restauration"
kubectl scale statefulset postgres -n boutique --replicas=0
kubectl wait pod postgres-0 -n boutique --for=delete --timeout=120s
kubectl delete pvc data-postgres-0 -n boutique
kubectl apply -f k8s/module-06/pvc-depuis-snapshot.yaml
kubectl scale statefulset postgres -n boutique --replicas=1
sleep 5
kubectl wait pod postgres-0 -n boutique --for=condition=Ready --timeout=400s
kubectl get pvc -n boutique
for i in $(seq 1 30); do [ "$(curl -s -m 5 -o /dev/null -w '%{http_code}' localhost:8080/api/produits)" = "200" ] && break; sleep 3; done
echo "== Après"
curl -s localhost:8080/api/produits | cut -c1-200; echo
pkill -f "port-forward service/api-catalogue" 2>/dev/null
