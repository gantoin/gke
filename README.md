# Maîtriser Google Kubernetes Engine (GKE)

Code source du cours Udemy « Maîtriser Google Kubernetes Engine (GKE) ».

## Contenu

| Dossier | Contenu |
|---|---|
| `app/api-catalogue` | L'API catalogue du projet fil rouge : Spring Boot 3, Java 21, avec son Dockerfile |
| `k8s/module-03` | Les manifestes des leçons du module 3 (pod, Deployment, Services) |
| `k8s/api-catalogue` | Le déploiement complet de l'API catalogue (namespace, Deployment, Service) |
| `k8s/module-04`, `k8s/module-05`, `k8s/module-06` | Les manifestes des modules 4 (clusters), 5 (réseau) et 6 (stockage, PostgreSQL) |
| `scripts` | Des scripts de démonstration utilisés dans les leçons |

## Avant de commencer

Les manifestes contiennent le texte `PROJECT_ID` à la place de l'identifiant de votre projet Google Cloud. Remplacez-le une fois pour toutes après avoir cloné le dépôt :

```
git clone https://github.com/gantoin/gke.git
cd gke
sed -i "s/PROJECT_ID/$(gcloud config get-value project)/" k8s/*/*.yaml
```

Sur macOS, la commande `sed` s'écrit `sed -i ''` au lieu de `sed -i`.

## L'API catalogue

| Méthode | Chemin | Rôle |
|---|---|---|
| GET | `/api/produits` | La liste des produits. L'en-tête `X-Pod-Name` indique le pod qui a répondu |
| GET | `/api/info` | Le nom de l'application, sa version et le pod |
| GET | `/actuator/health` | L'état de santé (avec `/liveness` et `/readiness` pour les probes) |
| POST | `/api/test/casser-liveness` | Démonstration : fait échouer la liveness probe |

Construire et tester l'image :

```
cd app/api-catalogue
docker build -t api-catalogue:v1 .
docker run --rm -p 8080:8080 api-catalogue:v1
curl localhost:8080/api/produits
```

Construire une version v2 (seule la valeur renvoyée par `/api/info` change) :

```
docker build --build-arg APP_VERSION=v2 -t api-catalogue:v2 .
```

## Autoriser le cluster à télécharger les images

Sur un projet récent, les machines du cluster n'ont pas le droit de lire Artifact Registry. Les pods restent alors en `ImagePullBackOff`. Donnez le rôle de lecture au compte de service par défaut, sur le dépôt d'images :

```
PN=$(gcloud projects describe $(gcloud config get-value project) --format='value(projectNumber)')
gcloud artifacts repositories add-iam-policy-binding formation-images \
  --location=europe-west1 \
  --member="serviceAccount:$PN-compute@developer.gserviceaccount.com" \
  --role="roles/artifactregistry.reader"
```

Construire la version v3 (module 6), qui sait ranger ses produits dans PostgreSQL :

```
docker build --build-arg APP_VERSION=v3 -t api-catalogue:v3 .
```

Par défaut, les produits restent en mémoire. Avec `SPRING_PROFILES_ACTIVE=postgres`, l'API utilise la base indiquée par `DB_HOST`, `DB_NAME`, `DB_USER` et `DB_PASSWORD`, et `POST /api/produits` ajoute un produit.
