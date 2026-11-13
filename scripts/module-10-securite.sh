#!/usr/bin/env bash
# Module 10 : sécurité (RBAC, pods durcis, images, réseau, Cloud Armor, audit)
# Usage : bash scripts/module-10-securite.sh durcir|rbac|images|reseau|armor|audit|verifier|menage
# À lancer après : bash scripts/module-09-observabilite.sh image   (l'image v5 de l'API)
set -u
P=$(gcloud config get-value project 2>/dev/null)
K=k8s/module-10
LEA="--as=lea@example.com"
peut() { printf "%-46s %s\n" "$*" "$(kubectl auth can-i "$@" $LEA 2>&1 | head -1)"; }
case "${1:-}" in
durcir)
  kubectl delete deployment api-catalogue -n boutique --ignore-not-found
  sed "s/PROJECT_ID/$P/" $K/api-catalogue-securise.yaml | kubectl apply -f -
  kubectl rollout status deployment api-catalogue -n boutique --timeout=400s | tail -1
  POD=$(kubectl get pods -n boutique -l app=api-catalogue -o jsonpath='{.items[0].metadata.name}')
  echo "== Qui suis-je, dans le conteneur ?"
  kubectl exec $POD -n boutique -- id
  echo "== Écrire dans l'image : interdit"
  kubectl exec $POD -n boutique -- touch /app/pirate.txt
  echo "== Écrire dans /tmp : permis"
  kubectl exec $POD -n boutique -- sh -c "touch /tmp/ok.txt && ls /tmp/ok.txt"
  echo "== Un namespace qui refuse les pods mal réglés"
  kubectl create namespace boutique-dev 2>/dev/null
  kubectl label namespace boutique-dev pod-security.kubernetes.io/enforce=restricted --overwrite
  kubectl run test-root --image=busybox:1.36 -n boutique-dev -- sleep 3600
  ;;
rbac)
  kubectl apply -f $K/rbac-developpeur.yaml
  echo "== Ce que Léa peut faire"
  peut get pods -n boutique-dev
  peut create deployments -n boutique-dev
  peut get pods -n boutique
  peut delete pods -n boutique
  peut get secrets -n boutique
  peut get nodes
  echo "== Léa essaie de supprimer un pod de la production"
  POD=$(kubectl get pods -n boutique -l app=api-catalogue -o jsonpath='{.items[0].metadata.name}')
  kubectl delete pod $POD -n boutique $LEA
  echo "== Léa regarde les pods de la production"
  kubectl get pods -n boutique $LEA
  ;;
images)
  echo "== Les images de l'API, avec leur empreinte"
  gcloud artifacts docker images list europe-west1-docker.pkg.dev/$P/formation-images/api-catalogue --include-tags --format="table(tags,version,createTime.date('%Y-%m-%d'))" 2>/dev/null
  echo "== L'image utilisée par les pods"
  kubectl get pods -n boutique -l app=api-catalogue -o jsonpath='{.items[0].status.containerStatuses[0].imageID}{"\n"}'
  ;;
reseau)
  kubectl apply -f $K/network-policies.yaml
  sleep 20
  echo "== Depuis un pod du namespace boutique"
  kubectl run visiteur --rm -i --restart=Never --image=busybox:1.36 -n boutique --quiet -- wget -q -T 5 -O - http://api-catalogue/api/info; echo
  echo "== Depuis un pod d'un autre namespace"
  kubectl run intrus --rm -i --restart=Never --image=busybox:1.36 -n default --quiet -- wget -q -T 5 -O - http://api-catalogue.boutique/api/info; echo "(code de sortie : $?)"
  ;;
armor)
  echo "== Une politique Cloud Armor : 30 demandes par minute et par adresse, pas plus"
  # Sur un compte d'essai, le quota de politiques Cloud Armor est à zéro : la création est refusée.
  if gcloud compute security-policies create boutique --description="Protection de la boutique"; then
    ARMOR=oui
    gcloud compute security-policies rules create 1000 --security-policy=boutique --src-ip-ranges="*" \
      --action=throttle --rate-limit-threshold-count=30 --rate-limit-threshold-interval-sec=60 \
      --conform-action=allow --exceed-action=deny-429 --enforce-on-key=IP
    kubectl apply -f $K/backendconfig.yaml
    kubectl annotate service api-catalogue -n boutique cloud.google.com/backend-config='{"default":"boutique"}' --overwrite
  else
    ARMOR=non
    echo "Pas de Cloud Armor sur ce compte : on continue avec l'Ingress seul."
  fi
  kubectl apply -f $K/ingress.yaml
  echo "On attend le load balancer (jusqu'à 15 minutes)..."
  for i in $(seq 1 90); do
    IP=$(kubectl get ingress boutique -n boutique -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    [ -n "$IP" ] && [ "$(curl -s -o /dev/null -m 5 -w '%{http_code}' http://$IP/api/info)" = "200" ] && break
    sleep 10
  done
  echo "$(date +%H:%M:%S)  réponse du load balancer, malgré les Network Policies : $(curl -s -o /dev/null -m 5 -w '%{http_code}' http://$IP/api/info)"
  if [ $ARMOR = oui ]; then
    for i in $(seq 1 18); do
      [ -n "$(gcloud compute backend-services list --format='value(securityPolicy)' 2>/dev/null | grep boutique)" ] && break; sleep 10
    done
    gcloud compute backend-services list --format="table(name,securityPolicy.basename())"
    sleep 75
    echo "== 60 demandes d'affilée"
    for i in $(seq 1 60); do curl -s -o /dev/null -m 5 -w '%{http_code}\n' http://$IP/api/info; done | sort | uniq -c
  fi
  ;;
audit)
  echo "== Qui a supprimé quoi, dans le cluster ?"
  gcloud logging read "logName=\"projects/$P/logs/cloudaudit.googleapis.com%2Factivity\" AND resource.type=\"k8s_cluster\" AND protoPayload.methodName:\"delete\" AND protoPayload.resourceName:\"namespaces/boutique\"" --freshness=3h --limit=6 \
    --format="table(timestamp.date('%H:%M:%S'),protoPayload.authenticationInfo.principalEmail,protoPayload.methodName,protoPayload.resourceName.slice(0:70),protoPayload.status.code)"
  echo "== Les demandes refusées"
  gcloud logging read "logName=\"projects/$P/logs/cloudaudit.googleapis.com%2Factivity\" AND resource.type=\"k8s_cluster\" AND protoPayload.status.code=7" --freshness=3h --limit=3 \
    --format="table(timestamp.date('%H:%M:%S'),protoPayload.authenticationInfo.principalEmail,protoPayload.methodName,protoPayload.status.message.slice(0:90))"
  echo "== Le tableau de bord de sécurité du cluster"
  gcloud container clusters describe formation --region=europe-west1 --format="yaml(securityPostureConfig)"
  ;;
verifier)
  echo "== 1. Les droits"
  kubectl get rolebinding -n boutique -o custom-columns='NOM:.metadata.name,ROLE:.roleRef.name,POUR:.subjects[0].name'
  echo "== 2. Les pods"
  kubectl get deployment api-catalogue -n boutique -o jsonpath='{"runAsNonRoot: "}{.spec.template.spec.securityContext.runAsNonRoot}{"\nreadOnlyRootFilesystem: "}{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}{"\ncapabilities.drop: "}{.spec.template.spec.containers[0].securityContext.capabilities.drop}{"\n"}'
  echo "== 3. Le réseau"
  kubectl get networkpolicy -n boutique
  echo "== 4. Le périmètre"
  gcloud compute security-policies list --format="table(name,description)"
  ;;
menage)
  kubectl delete ingress boutique -n boutique --ignore-not-found
  kubectl annotate service api-catalogue -n boutique cloud.google.com/backend-config- 2>/dev/null
  kubectl delete backendconfig boutique -n boutique --ignore-not-found
  kubectl delete -f $K/network-policies.yaml --ignore-not-found
  kubectl delete rolebinding lea-lecture -n boutique --ignore-not-found
  kubectl delete namespace boutique-dev --ignore-not-found --wait=false
  kubectl delete deployment api-catalogue -n boutique --ignore-not-found
  sed "s/PROJECT_ID/$P/" k8s/api-catalogue/deployment.yaml | kubectl apply -f -
  kubectl scale deployment api-catalogue -n boutique --replicas=0
  echo "On attend la suppression du load balancer, puis on supprime la politique Cloud Armor..."
  for i in $(seq 1 30); do gcloud compute security-policies delete boutique -q 2>/dev/null && echo "politique supprimée" && break; sleep 20; done
  gcloud compute forwarding-rules list --format="value(name)"; gcloud compute security-policies list --format="value(name)"
  ;;
*) echo "Usage : bash $0 durcir|rbac|images|reseau|armor|audit|verifier|menage" ;;
esac
