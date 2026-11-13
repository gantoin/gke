#!/usr/bin/env bash
# Leçon 5.6 : un vrai nom de domaine et un certificat HTTPS
# Usage : DOMAINE=gke.exemple.fr bash scripts/module-05-8-domaine-https.sh zone|site|menage
# 1. "zone"   crée la zone Cloud DNS et affiche les serveurs de noms à déclarer chez votre vendeur de domaine
# 2. "site"   déploie l'Ingress, crée l'enregistrement, attend le certificat et teste en HTTPS
# 3. "menage" supprime l'Ingress, le certificat et l'enregistrement
set -u
: "${DOMAINE:?Indiquez votre domaine : DOMAINE=gke.exemple.fr}"
ZONE=$(echo "$DOMAINE" | tr '.' '-')
NOM=boutique.$DOMAINE
case "${1:-}" in
zone)
  gcloud services enable dns.googleapis.com
  gcloud dns managed-zones create $ZONE --dns-name="$DOMAINE." --description="Zone du cours GKE" 2>&1 | tail -1
  echo "== Serveurs de noms à déclarer chez votre vendeur de domaine (enregistrements NS)"
  gcloud dns managed-zones describe $ZONE --format="value(nameServers)" | tr ';' '\n'
  ;;
site)
  kubectl scale deployment api-catalogue -n boutique --replicas=3
  kubectl apply -f k8s/module-05/vitrine.yaml
  kubectl rollout status deployment api-catalogue -n boutique --timeout=300s | tail -1
  sed "s/DOMAINE/$DOMAINE/" k8s/module-05/ingress-https.yaml | kubectl apply -f -
  echo "== On attend l'adresse de l'Ingress"
  for i in $(seq 1 90); do IP=$(kubectl get ingress boutique -n boutique -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); [ -n "$IP" ] && break; sleep 10; done
  kubectl get ingress boutique -n boutique
  echo "== L'enregistrement DNS"
  gcloud dns record-sets create $NOM. --zone=$ZONE --type=A --ttl=300 --rrdatas=$IP 2>&1 | tail -4
  echo "== On attend que le nom réponde sur Internet"
  for i in $(seq 1 60); do [ "$(dig +short @8.8.8.8 $NOM)" = "$IP" ] && break; sleep 10; done
  dig +short @8.8.8.8 $NOM
  echo "== On attend le certificat (de 15 minutes à une heure)"
  S=$(date +%s)
  for i in $(seq 1 240); do [ "$(kubectl get managedcertificate boutique -n boutique -o jsonpath='{.status.certificateStatus}')" = "Active" ] && break; sleep 30; done
  echo "Certificat prêt au bout de $(( ($(date +%s) - S) / 60 )) minutes"
  kubectl get managedcertificate boutique -n boutique
  for i in $(seq 1 40); do [ "$(curl -s -m 5 -o /dev/null -w '%{http_code}' https://$NOM/api/info)" = "200" ] && break; sleep 15; done
  echo "== Test en HTTPS"
  curl -s -m 10 https://$NOM/api/info; echo
  curl -s -m 10 https://$NOM/ | grep -i "<title>"
  curl -s -m 10 -o /dev/null -v https://$NOM/ 2>&1 | grep -E "subject:|issuer:|expire date:" | sed 's/^\* *//'
  ;;
menage)
  kubectl delete ingress boutique -n boutique
  kubectl delete managedcertificate boutique -n boutique
  kubectl delete -f k8s/module-05/vitrine.yaml
  kubectl scale deployment api-catalogue -n boutique --replicas=0
  gcloud dns record-sets delete $NOM. --zone=$ZONE --type=A 2>&1 | tail -1
  echo "La zone $ZONE est conservée. Pour la supprimer : retirez d'abord les enregistrements NS chez votre vendeur de domaine,"
  echo "puis : gcloud dns managed-zones delete $ZONE"
  ;;
*) echo "Usage : DOMAINE=gke.exemple.fr bash $0 zone|site|menage" ;;
esac
