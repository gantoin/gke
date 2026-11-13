#!/usr/bin/env bash
# Module 8 : l'autoscaling, sous une vraie charge
# Usage : bash scripts/module-08-autoscaling.sh hpa|resilience|zones|machines|menage
# À lancer après : bash scripts/module-07-1-configmap.sh image   (l'image v4 de l'API)
set -u
P=$(gcloud config get-value project 2>/dev/null)
K=k8s/module-08
# Une ligne toutes les 15 secondes : CPU mesuré / consigne, nombre de pods, machines du cluster
observer() {
  for i in $(seq 1 $1); do
    H=$(kubectl get hpa api-catalogue -n boutique --no-headers 2>/dev/null | awk '{print $3, $4, $5, "pods voulus:", $7}')
    PR=$(kubectl get pods -n boutique -l app=api-catalogue --no-headers 2>/dev/null | grep -c "1/1")
    PE=$(kubectl get pods -n boutique -l app=api-catalogue --no-headers 2>/dev/null | grep -c Pending)
    N=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    echo "$(date +%H:%M:%S)  $H  prêts: $PR  en attente: $PE  machines: $N"
    sleep 15
  done
}
zones() {
  kubectl get pods -n boutique -l app=api-catalogue -o custom-columns='POD:.metadata.name,MACHINE:.spec.nodeName' --no-headers | while read POD NODE; do
    echo "$POD  $(kubectl get node $NODE -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')"
  done | awk '{print $2}' | sort | uniq -c
}
case "${1:-}" in
hpa)
  kubectl delete deployment api-catalogue -n boutique --ignore-not-found
  sed "s/PROJECT_ID/$P/" $K/api-catalogue.yaml | kubectl apply -f -
  kubectl apply -f $K/hpa.yaml -f $K/vpa.yaml
  kubectl rollout status deployment api-catalogue -n boutique --timeout=400s | tail -1
  sleep 45
  echo "== Au repos"
  kubectl get hpa api-catalogue -n boutique
  kubectl get nodes --no-headers | wc -l
  echo "== On envoie la charge"
  kubectl apply -f $K/charge.yaml -f $K/sonde.yaml
  observer 20
  kubectl get hpa api-catalogue -n boutique
  kubectl get pods -n boutique -l app=api-catalogue
  echo "== Les machines ajoutées par le cluster"
  kubectl get events -n boutique --field-selector reason=TriggeredScaleUp -o custom-columns='POD:.involvedObject.name,MESSAGE:.message' | tail -3 | cut -c1-200
  kubectl get nodes
  echo "== Un redémarrage des pods sous la charge (sans précaution)"
  kubectl logs sonde -n boutique --tail=1
  kubectl rollout restart deployment api-catalogue -n boutique
  kubectl rollout status deployment api-catalogue -n boutique --timeout=600s | tail -1
  sleep 10
  kubectl logs sonde -n boutique --tail=1
  echo "== Le conseil du VPA"
  kubectl describe vpa api-catalogue -n boutique | sed -n '/Recommendation:/,/Events:/p' | grep -v Events
  echo "== On arrête la charge"
  kubectl delete -f $K/charge.yaml
  observer 24
  kubectl get hpa api-catalogue -n boutique
  ;;
resilience)
  kubectl delete pod sonde -n boutique --ignore-not-found
  sed "s/PROJECT_ID/$P/" $K/api-catalogue-resilient.yaml | kubectl apply -f -
  kubectl apply -f $K/pdb.yaml -f $K/hpa.yaml
  kubectl rollout status deployment api-catalogue -n boutique --timeout=600s | tail -1
  echo "== On envoie la charge"
  kubectl apply -f $K/charge.yaml -f $K/sonde.yaml
  observer 16
  kubectl get hpa,pdb -n boutique
  echo "== Les pods, par zone"
  zones
  echo "== Un redémarrage des pods sous la charge (avec les précautions)"
  kubectl logs sonde -n boutique --tail=1
  kubectl rollout restart deployment api-catalogue -n boutique
  kubectl rollout status deployment api-catalogue -n boutique --timeout=900s | tail -1
  sleep 10
  kubectl logs sonde -n boutique --tail=1
  echo "== On arrête la charge"
  kubectl delete -f $K/charge.yaml
  observer 16
  kubectl get hpa api-catalogue -n boutique
  kubectl get nodes --no-headers | wc -l
  ;;
zones)
  # Trois pods au minimum, et on regarde dans quelles zones ils sont placés
  sed "s/PROJECT_ID/$P/" $K/api-catalogue-resilient.yaml | kubectl apply -f -
  kubectl apply -f $K/pdb.yaml -f $K/hpa.yaml
  kubectl patch hpa api-catalogue -n boutique --type merge -p '{"spec":{"minReplicas":3}}'
  for i in $(seq 1 40); do
    echo "$(date +%H:%M:%S)  prêts: $(kubectl get pods -n boutique -l app=api-catalogue --no-headers | grep -c 1/1)  en attente: $(kubectl get pods -n boutique -l app=api-catalogue --no-headers | grep -c Pending)  machines: $(kubectl get nodes --no-headers | wc -l)"
    [ "$(kubectl get deployment api-catalogue -n boutique -o jsonpath='{.status.updatedReplicas}')" = "3" ] && [ "$(kubectl get deployment api-catalogue -n boutique -o jsonpath='{.status.readyReplicas}')" = "3" ] && [ "$(kubectl get pods -n boutique -l app=api-catalogue --no-headers | wc -l)" = "3" ] && break
    sleep 15
  done
  echo "== Les pods, par zone"
  zones
  kubectl get nodes -o custom-columns='MACHINE:.metadata.name,ZONE:.metadata.labels.topology\.kubernetes\.io/zone,CPU:.status.capacity.cpu'
  kubectl get pods -n boutique -l app=api-catalogue
  kubectl describe pod -n boutique -l app=api-catalogue | grep -E "FailedScheduling|TriggeredScaleUp|NotTriggerScaleUp" | tail -4 | cut -c1-260
  ;;
machines)
  echo "== Avant"
  kubectl get nodes
  kubectl apply -f $K/gros-pods.yaml
  for i in $(seq 1 24); do
    echo "$(date +%H:%M:%S)  pods prêts: $(kubectl get pods -n boutique -l app=gros-pods --no-headers | grep -c 1/1)  en attente: $(kubectl get pods -n boutique -l app=gros-pods --no-headers | grep -c Pending)  machines: $(kubectl get nodes --no-headers | wc -l)"
    [ "$(kubectl get deployment gros-pods -n boutique -o jsonpath='{.status.readyReplicas}')" = "4" ] && break
    sleep 15
  done
  echo "== Pourquoi des machines sont arrivées"
  kubectl get events -n boutique --field-selector reason=TriggeredScaleUp -o custom-columns='POD:.involvedObject.name,MESSAGE:.message' | tail -2 | cut -c1-220
  kubectl get nodes
  echo "== On supprime les gros pods : les machines repartent plus tard"
  kubectl delete -f $K/gros-pods.yaml
  for i in $(seq 1 30); do echo "$(date +%H:%M:%S)  machines: $(kubectl get nodes --no-headers | wc -l)"; sleep 30; done
  ;;
menage)
  kubectl delete -f $K/gros-pods.yaml -f $K/charge.yaml -f $K/sonde.yaml -f $K/hpa.yaml -f $K/vpa.yaml -f $K/pdb.yaml --ignore-not-found
  kubectl delete deployment api-catalogue -n boutique --ignore-not-found
  sed "s/PROJECT_ID/$P/" k8s/api-catalogue/deployment.yaml | kubectl apply -f -
  kubectl scale deployment api-catalogue -n boutique --replicas=0
  ;;
*) echo "Usage : bash $0 hpa|resilience|zones|machines|menage" ;;
esac
