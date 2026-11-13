#!/usr/bin/env bash
# Leçon 7.2 : un Secret Kubernetes n'est pas chiffré, il est seulement encodé
set -u
kubectl apply -f k8s/module-06/postgres/01-secret.yaml
echo "== Le secret, vu par kubectl"
kubectl get secret postgres -n boutique -o yaml | grep -A3 "^data:"
echo "== On décode"
kubectl get secret postgres -n boutique -o jsonpath='{.data.mot-de-passe}' | base64 --decode; echo
echo "== Qui a le droit de le lire ?"
kubectl auth can-i get secrets -n boutique
kubectl auth can-i get secrets -n boutique --as=system:serviceaccount:boutique:default
echo "== Ménage"
kubectl delete secret postgres -n boutique
