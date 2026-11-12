# Maîtriser Google Kubernetes Engine (GKE)

Code source du cours Udemy « Maîtriser Google Kubernetes Engine (GKE) ».

## Contenu

| Dossier | Contenu |
|---|---|
| `app/api-catalogue` | L'API catalogue du projet fil rouge : Spring Boot 3, Java 21, avec son Dockerfile |
| `k8s/module-03` | Les manifestes des leçons du module 3 (pod, Deployment, Services) |
| `k8s/api-catalogue` | Le déploiement complet de l'API catalogue (namespace, Deployment, Service) |

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
