#!/usr/bin/env bash
# Module 11 : CI/CD et GitOps (Cloud Build, GitHub Actions, Helm, Argo CD)
# Usage : bash scripts/module-11-cicd.sh preparer|base|cloudbuild|github|helm|argocd|apps|etat|menage
# DEPOT : votre dépôt GitHub (un fork du dépôt du cours), par exemple DEPOT=moncompte/gke
set -u
P=$(gcloud config get-value project 2>/dev/null)
N=$(gcloud projects describe $P --format="value(projectNumber)")
DEPOT=${DEPOT:-gantoin/gke}
ARGO=${ARGO:-v3.6.1}                 # la version d'Argo CD installée
REG=europe-west1-docker.pkg.dev/$P/formation-images/api-catalogue
SA=pipeline-boutique@$P.iam.gserviceaccount.com
POOL=projects/$N/locations/global/workloadIdentityPools/github
GH="principalSet://iam.googleapis.com/$POOL/attribute.repository/$DEPOT"
ouvrir() { pkill -f "port-forward service/$1" 2>/dev/null; kubectl port-forward service/$1 8080:80 -n $2 >/dev/null 2>&1 & sleep 4; }
case "${1:-}" in
preparer)
  echo "== Les API"
  gcloud services enable cloudbuild.googleapis.com iamcredentials.googleapis.com sts.googleapis.com
  echo "== Un compte de service pour Cloud Build, avec trois droits"
  gcloud iam service-accounts create pipeline-boutique --display-name="Pipeline de la boutique" 2>&1 | tail -1
  sleep 10
  gcloud artifacts repositories add-iam-policy-binding formation-images --location=europe-west1 --member="serviceAccount:$SA" --role=roles/artifactregistry.writer --format="value(etag)" >/dev/null && echo "pousser des images : ok"
  gcloud projects add-iam-policy-binding $P --member="serviceAccount:$SA" --role=roles/container.developer --condition=None --format="value(etag)" >/dev/null && echo "déployer sur GKE : ok"
  gcloud projects add-iam-policy-binding $P --member="serviceAccount:$SA" --role=roles/logging.logWriter --condition=None --format="value(etag)" >/dev/null && echo "écrire ses logs : ok"
  # Cloud Build range le code à construire dans un bucket : le compte de service doit pouvoir le lire
  gcloud storage buckets describe gs://${P}_cloudbuild >/dev/null 2>&1 || gcloud storage buckets create gs://${P}_cloudbuild --location=europe-west1 -q 2>/dev/null
  gcloud storage buckets add-iam-policy-binding gs://${P}_cloudbuild --member="serviceAccount:$SA" --role=roles/storage.objectViewer >/dev/null && echo "lire le code à construire : ok"
  echo "== Pour GitHub Actions : la confiance entre Google et le dépôt $DEPOT, sans clé"
  gcloud iam workload-identity-pools create github --location=global --display-name="GitHub Actions" 2>&1 | tail -1
  gcloud iam workload-identity-pools providers create-oidc depot --location=global --workload-identity-pool=github \
    --issuer-uri=https://token.actions.githubusercontent.com \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
    --attribute-condition="assertion.repository=='$DEPOT'" 2>&1 | tail -1
  gcloud artifacts repositories add-iam-policy-binding formation-images --location=europe-west1 --member="$GH" --role=roles/artifactregistry.writer --format="value(etag)" >/dev/null && echo "GitHub, pousser des images : ok"
  gcloud projects add-iam-policy-binding $P --member="$GH" --role=roles/container.developer --condition=None --format="value(etag)" >/dev/null && echo "GitHub, déployer sur GKE : ok"
  ;;
base)
  kubectl delete deployment api-catalogue -n boutique --ignore-not-found
  sed "s/PROJECT_ID/$P/" k8s/module-09/api-catalogue.yaml | kubectl apply -f -
  kubectl rollout status deployment api-catalogue -n boutique --timeout=400s | tail -1
  ouvrir api-catalogue boutique; curl -s localhost:8080/api/info; echo; pkill -f "port-forward service/api-catalogue"
  ;;
cloudbuild)
  V=${2:-v6}
  echo "== On lance le pipeline : construire, pousser, déployer la version $V"
  gcloud builds submit . --config=cloudbuild.yaml --substitutions=_VERSION=$V --service-account=projects/$P/serviceAccounts/$SA --format="value(id,status)" 2>&1 | tail -3
  echo "== Les étapes du dernier build"
  B=$(gcloud builds list --limit=1 --format="value(id)")
  gcloud builds describe $B --format="table(steps.id,steps.status,steps.timing.startTime.date('%H:%M:%S'),steps.timing.endTime.date('%H:%M:%S'))"
  gcloud builds list --limit=3 --format="table(id,status,createTime.date('%H:%M:%S'),duration)"
  echo "== La version en ligne"
  ouvrir api-catalogue boutique; curl -s localhost:8080/api/info; echo; pkill -f "port-forward service/api-catalogue"
  ;;
github)
  echo "Dans votre dépôt GitHub : Settings > Secrets and variables > Actions > New repository secret"
  echo "GCP_PROJECT_ID   = $P"
  echo "GCP_WIF_PROVIDER = $POOL/providers/depot"
  echo "Puis : onglet Actions > Déployer l'API sur GKE > Run workflow"
  ;;
version)
  kubectl get deployment api-catalogue -n boutique -o jsonpath='{.spec.template.spec.containers[0].image}' | sed 's/.*api-catalogue:/api-catalogue:/'; echo
  ouvrir api-catalogue boutique; curl -s localhost:8080/api/info; echo; pkill -f "port-forward service/api-catalogue"
  ;;
helm)
  C=helm/boutique
  echo "== Le chart"; find $C -type f | sort
  helm lint $C | tail -2
  echo "== Ce que Helm fabrique (extrait)"
  helm template essai $C --set image.depot=$REG --set replicas=1 | grep -E "^kind:|  name:|replicas:|image:|value:"
  echo "== On installe la boutique dans un namespace de test"
  helm install test $C -n boutique-test --create-namespace --set image.depot=$REG --set replicas=1 --set message="Installée avec Helm" | head -6
  kubectl rollout status deployment test-api-catalogue -n boutique-test --timeout=400s | tail -1
  ouvrir test-api-catalogue boutique-test; curl -s localhost:8080/api/info; echo; pkill -f "port-forward service/test-api-catalogue"
  echo "== Une mise à jour : deux pods, et un autre message"
  helm upgrade test $C -n boutique-test --set image.depot=$REG --set replicas=2 --set message="Soldes" | head -4
  kubectl rollout status deployment test-api-catalogue -n boutique-test --timeout=400s | tail -1
  helm list -n boutique-test
  helm history test -n boutique-test
  echo "== Et un retour en arrière"
  helm rollback test 1 -n boutique-test
  kubectl rollout status deployment test-api-catalogue -n boutique-test --timeout=400s | tail -1
  kubectl get deployment test-api-catalogue -n boutique-test
  helm history test -n boutique-test
  ;;
argocd)
  echo "== On installe Argo CD $ARGO (manifeste officiel du dépôt argoproj/argo-cd)"
  kubectl create namespace argocd 2>/dev/null
  kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGO/manifests/install.yaml 2>&1 | grep -c -E "serverside-applied"
  for d in argocd-repo-server argocd-server argocd-redis argocd-applicationset-controller; do kubectl rollout status deployment $d -n argocd --timeout=600s | tail -1; done
  kubectl rollout status statefulset argocd-application-controller -n argocd --timeout=600s | tail -1
  kubectl get pods -n argocd
  ;;
apps)
  sed -e "s#DEPOT_GIT#$DEPOT#" -e "s/PROJECT_ID/$P/" k8s/module-11/argocd-applications.yaml | kubectl apply -f -
  for i in $(seq 1 40); do
    S=$(kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.status.sync.status}/{.status.health.status} {end}')
    echo "$(date +%H:%M:%S)  $S"
    [ "$S" = "Synced/Healthy Synced/Healthy " ] && break; sleep 15
  done
  bash $0 etat
  ;;
etat)
  kubectl get applications -n argocd -o custom-columns='APPLICATION:.metadata.name,SYNC:.status.sync.status,SANTE:.status.health.status,COMMIT:.status.sync.revision'
  for E in dev prod; do
    echo "== $E"
    kubectl get deployment api-catalogue -n boutique-$E -o custom-columns='PODS:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image' | sed 's#europe-west1.*/api-catalogue:#api-catalogue:#'
  done
  ;;
attendre)
  # attendre que les deux applications soient à jour avec Git (Argo CD regarde Git toutes les 3 minutes)
  kubectl annotate applications --all -n argocd argocd.argoproj.io/refresh=normal --overwrite >/dev/null
  for i in $(seq 1 60); do
    S=$(kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.status.sync.status}/{.status.health.status} {end}')
    R=$(kubectl get application boutique-prod -n argocd -o jsonpath='{.status.sync.revision}' | cut -c1-7)
    echo "$(date +%H:%M:%S)  $S  commit: $R"
    [ "$R" = "${2:-x}" ] && [ "$S" = "Synced/Healthy Synced/Healthy " ] && break; sleep 10
  done
  bash $0 etat
  ;;
reparer)
  echo "== Quelqu'un supprime le Deployment de production, à la main"
  kubectl delete deployment api-catalogue -n boutique-prod
  for i in 1 2 3 4 5 6; do sleep 10; echo "$(date +%H:%M:%S)  $(kubectl get deployment api-catalogue -n boutique-prod --no-headers 2>&1 | cut -c1-60)"; done
  ;;
menage)
  kubectl delete applications --all -n argocd --ignore-not-found
  kubectl delete namespace boutique-dev boutique-prod boutique-test argocd --ignore-not-found --wait=false
  kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io --ignore-not-found
  kubectl delete clusterrole,clusterrolebinding -l app.kubernetes.io/part-of=argocd --ignore-not-found
  kubectl delete deployment api-catalogue -n boutique --ignore-not-found
  sed "s/PROJECT_ID/$P/" k8s/api-catalogue/deployment.yaml | kubectl apply -f -
  kubectl scale deployment api-catalogue -n boutique --replicas=0
  echo "== On retire les droits donnés aux pipelines"
  gcloud projects remove-iam-policy-binding $P --member="$GH" --role=roles/container.developer --condition=None --format="value(etag)" >/dev/null
  gcloud artifacts repositories remove-iam-policy-binding formation-images --location=europe-west1 --member="$GH" --role=roles/artifactregistry.writer --format="value(etag)" >/dev/null
  gcloud iam workload-identity-pools delete github --location=global -q
  gcloud projects remove-iam-policy-binding $P --member="serviceAccount:$SA" --role=roles/container.developer --condition=None --format="value(etag)" >/dev/null
  gcloud projects remove-iam-policy-binding $P --member="serviceAccount:$SA" --role=roles/logging.logWriter --condition=None --format="value(etag)" >/dev/null
  gcloud artifacts repositories remove-iam-policy-binding formation-images --location=europe-west1 --member="serviceAccount:$SA" --role=roles/artifactregistry.writer --format="value(etag)" >/dev/null
  gcloud storage buckets remove-iam-policy-binding gs://${P}_cloudbuild --member="serviceAccount:$SA" --role=roles/storage.objectViewer >/dev/null
  gcloud iam service-accounts delete $SA -q
  ;;
*) echo "Usage : bash $0 preparer|base|cloudbuild|github|version|helm|argocd|apps|etat|attendre|reparer|menage" ;;
esac
