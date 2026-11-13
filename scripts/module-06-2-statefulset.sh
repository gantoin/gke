#!/usr/bin/env bash
# Leçon 6.2 : un StatefulSet de démonstration : des noms fixes, un disque par pod, un ordre
set -u
kubectl apply -f k8s/module-06/statefulset-demo.yaml
echo "== Les pods arrivent un par un, dans l'ordre"
for i in $(seq 1 60); do
  kubectl get pods -n boutique -l app=demo --no-headers 2>/dev/null | awk '{print $1, $2, $3}' | tr '\n' ';'; echo
  [ "$(kubectl get statefulset demo -n boutique -o jsonpath='{.status.readyReplicas}')" = "3" ] && break
  sleep 10
done
kubectl get pods -n boutique -l app=demo
echo "== Un disque par pod"
kubectl get pvc -n boutique -l app=demo
echo "== Un nom DNS par pod"
kubectl exec demo-0 -n boutique -- nslookup demo-1.demo.boutique.svc.cluster.local | tail -3
echo "== On supprime demo-1"
kubectl exec demo-1 -n boutique -- cat /data/journal.txt
kubectl delete pod demo-1 -n boutique
kubectl wait pod demo-1 -n boutique --for=condition=Ready --timeout=300s
kubectl get pods -n boutique -l app=demo
echo "== Son remplaçant a le même nom, et il retrouve son disque"
kubectl exec demo-1 -n boutique -- cat /data/journal.txt
echo "== Ménage : les disques ne partent pas avec le StatefulSet"
kubectl delete -f k8s/module-06/statefulset-demo.yaml
sleep 15
kubectl get pvc -n boutique -l app=demo
kubectl delete pvc -n boutique -l app=demo
