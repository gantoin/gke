#!/usr/bin/env bash
# Leçon 5.4 : le même routage avec Gateway API
set -u
kubectl delete -f k8s/module-05/ingress.yaml
echo "== Les classes de Gateway disponibles"
kubectl get gatewayclass
kubectl apply -f k8s/module-05/gateway.yaml
echo "== On attend que le load balancer soit prêt (plusieurs minutes)"
S=$(date +%s)
for i in $(seq 1 90); do
  IP=$(kubectl get gateway boutique -n boutique -o jsonpath='{.status.addresses[0].value}')
  if [ -n "$IP" ] && [ "$(curl -s -m 5 -o /dev/null -w '%{http_code}' http://$IP/api/info)" = "200" ] && [ "$(curl -s -m 5 -o /dev/null -w '%{http_code}' http://$IP/)" = "200" ]; then break; fi
  sleep 10
done
echo "Prêt au bout de $(( $(date +%s) - S )) secondes"
kubectl get gateway,httproute -n boutique
echo "== /api va vers l'API"
curl -s -m 10 http://$IP/api/info; echo
echo "== / va vers la vitrine"
curl -s -m 10 http://$IP/ | grep -i "<title>"
echo "== On supprime"
kubectl delete -f k8s/module-05/gateway.yaml
