#!/usr/bin/env bash
# Leçon 6.1 : une demande de stockage, un disque, et des données qui survivent au pod
set -u
echo "== Le catalogue du cluster"
kubectl get storageclass
echo "== La demande"
kubectl apply -f k8s/module-06/pvc-demo.yaml
sleep 5
kubectl get pvc demo-donnees -n boutique
echo "== Un pod qui utilise la demande"
kubectl apply -f k8s/module-06/pod-demo.yaml
kubectl wait pod demo-stockage -n boutique --for=condition=Ready --timeout=400s
kubectl get pvc demo-donnees -n boutique
echo "== Côté Google Cloud"
gcloud compute disks list --filter="name~^pvc-" --format="table(name,sizeGb,type.basename(),zone.basename())"
echo "== On écrit un fichier, puis on supprime le pod"
kubectl exec demo-stockage -n boutique -- sh -c 'echo "écrit par le premier pod" > /data/note.txt; cat /data/note.txt'
kubectl delete pod demo-stockage -n boutique
echo "== Un nouveau pod, sur la même demande"
kubectl apply -f k8s/module-06/pod-demo.yaml
kubectl wait pod demo-stockage -n boutique --for=condition=Ready --timeout=400s
kubectl exec demo-stockage -n boutique -- cat /data/note.txt
echo "== Que devient le disque si on supprime la demande ?"
kubectl get pv -o custom-columns='NAME:.metadata.name,TAILLE:.spec.capacity.storage,POLITIQUE:.spec.persistentVolumeReclaimPolicy,DEMANDE:.spec.claimRef.name'
echo "== Ménage"
kubectl delete pod demo-stockage -n boutique
kubectl delete pvc demo-donnees -n boutique
sleep 30
gcloud compute disks list --filter="name~^pvc-" --format="table(name,sizeGb,type.basename())"
