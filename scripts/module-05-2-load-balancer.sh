#!/usr/bin/env bash
# Leçon 5.2 : un Service LoadBalancer, et ce que Google crée derrière
set -u
kubectl apply -f k8s/module-05/service-lb.yaml
echo "== On attend l'adresse publique"
for i in $(seq 1 40); do IP=$(kubectl get service api-catalogue-lb -n boutique -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); [ -n "$IP" ] && break; sleep 5; done
kubectl get service api-catalogue-lb -n boutique
echo "== Côté Google Cloud"
gcloud compute forwarding-rules list --format="table(name.scope():label=NAME,region.basename(),IPAddress,loadBalancingScheme)" | cut -c1-140
sleep 20
echo "== Test"
curl -s -m 10 http://$IP/api/info; echo
echo "== On supprime tout de suite"
kubectl delete -f k8s/module-05/service-lb.yaml
