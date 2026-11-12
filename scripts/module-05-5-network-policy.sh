#!/usr/bin/env bash
# Leçon 5.5 : seule l'API a le droit de parler à PostgreSQL
set -u
kubectl apply -f k8s/module-05/postgres.yaml
kubectl rollout status deployment postgres -n boutique --timeout=300s | tail -1
sleep 10
T="kubectl run -n boutique --rm -i --restart=Never --image=busybox:1.36 --quiet"
echo "== Avant : un pod quelconque peut joindre la base"
$T curieux -- nc -zv -w 5 postgres 5432 2>&1 | grep -v "deleted"
echo "== On applique la règle"
kubectl apply -f k8s/module-05/netpol-postgres.yaml
kubectl get networkpolicy -n boutique
sleep 15
echo "== Après : un pod quelconque"
$T curieux -- nc -zv -w 5 postgres 5432 2>&1 | grep -v "deleted"
echo "== Après : un pod qui porte l'étiquette de l'API"
$T faux-api --labels=app=api-catalogue -- nc -zv -w 5 postgres 5432 2>&1 | grep -v "deleted"
