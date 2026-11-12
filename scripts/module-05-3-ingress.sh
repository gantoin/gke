#!/usr/bin/env bash
# Leçon 5.3 : un Ingress devant deux services
set -u
kubectl apply -f k8s/module-05/vitrine.yaml
kubectl rollout status deployment vitrine -n boutique --timeout=300s | tail -1
kubectl apply -f k8s/module-05/ingress.yaml
echo "== On attend que le load balancer soit prêt (plusieurs minutes)"
S=$(date +%s)
for i in $(seq 1 90); do
  IP=$(kubectl get ingress boutique -n boutique -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [ -n "$IP" ] && [ "$(curl -s -m 5 -o /dev/null -w '%{http_code}' http://$IP/api/info)" = "200" ]; then break; fi
  sleep 10
done
echo "Prêt au bout de $(( $(date +%s) - S )) secondes"
kubectl get ingress boutique -n boutique
echo "== /api va vers l'API"
curl -s -m 10 http://$IP/api/info; echo
echo "== / va vers la vitrine"
curl -s -m 10 http://$IP/ | grep -i "<title>"
echo "== Côté Google Cloud"
gcloud compute forwarding-rules list --format="table(name.scope():label=NAME,IPAddress,loadBalancingScheme)" | cut -c1-140
