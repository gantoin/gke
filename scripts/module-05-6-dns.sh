#!/usr/bin/env bash
# Leçon 5.6 : une zone Cloud DNS d'entraînement (sans acheter de domaine)
set -u
gcloud services enable dns.googleapis.com
echo "== Création de la zone"
gcloud dns managed-zones create boutique-demo --dns-name="boutique-demo.example." --description="Zone d'entrainement du cours GKE" 2>&1 | tail -1
gcloud dns managed-zones describe boutique-demo --format="value(nameServers)" | tr ';' '\n'
echo "== Un enregistrement A vers l'adresse du load balancer"
gcloud dns record-sets create api.boutique-demo.example. --zone=boutique-demo --type=A --ttl=300 --rrdatas=203.0.113.10 2>&1 | tail -3
gcloud dns record-sets list --zone=boutique-demo --format="table(name,type,ttl,rrdatas.list():label=DATA)"
NS=$(gcloud dns managed-zones describe boutique-demo --format="value(nameServers[0])")
echo "== On interroge directement le serveur de Google"
dig +short @$NS api.boutique-demo.example
echo "== Ménage"
gcloud dns record-sets delete api.boutique-demo.example. --zone=boutique-demo --type=A 2>&1 | tail -1
gcloud dns managed-zones delete boutique-demo 2>&1 | tail -1
