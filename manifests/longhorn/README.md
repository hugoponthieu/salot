# Install longhorn

```bash
helm install longhorn longhorn/longhorn \
--namespace longhorn-system \
-f values.yaml \
--version 1.13.0 
```

## Redimensionner les disques Longhorn des VM Talos

Les deux workers utilisent chacun un disque raw sparse dédié à Longhorn. Le
disque est attaché en `vdb` par libvirt et apparaît en `/dev/sda` dans Talos.
Talos le monte en XFS dans `/var/mnt/longhorn` via le volume `u-longhorn`.

Cette procédure agrandit les disques sans recréer les VM ni les volumes
Longhorn. Elle ne permet pas de réduire leur taille. Sauvegarder les données
importantes et traiter un seul worker à la fois.

### Correspondance actuelle

| VM libvirt | Nœud Kubernetes | IP Talos | Libvirt | Talos |
| --- | --- | --- | --- | --- |
| `homelab_worker-node-1` | `talos-ek9-utp` | `192.168.121.85` | `vdb` | `/dev/sda` |
| `homelab_worker-node-2` | `talos-ku2-xtb` | `192.168.121.173` | `vdb` | `/dev/sda` |

Les noms et adresses peuvent changer après une reconstruction. Les vérifier
avant l'opération :

```bash
ssh hugo@100.94.238.124 \
  'virsh --connect qemu:///system domblklist homelab_worker-node-1'
ssh hugo@100.94.238.124 \
  'virsh --connect qemu:///system domblklist homelab_worker-node-2'
kubectl get nodes -o wide
```

### 1. Conserver la taille dans le Vagrantfile

Sur l'hôte `100.94.238.124`, modifier
`~/code/homelab/Vagrantfile`. La taille est centralisée ainsi :

```ruby
longhorn_disk_size = "160G"
```

La définition des disques doit utiliser cette variable :

```ruby
domain.storage :file,
               :path => node.fetch(:longhorn_disk),
               :size => longhorn_disk_size,
               :type => "raw",
               :bus => "sata",
               :cache => "none"
```

Valider le fichier :

```bash
ssh hugo@100.94.238.124 \
  'cd ~/code/homelab && vagrant validate'
```

Le Vagrantfile garantit la bonne taille lors des futures recréations. Il ne
redimensionne pas à lui seul les fichiers raw déjà attachés aux VM.

### 2. Agrandir les disques libvirt existants

Exemple pour passer les deux disques à 160 Gio :

```bash
ssh hugo@100.94.238.124 \
  'virsh --connect qemu:///system blockresize homelab_worker-node-1 vdb 160G'
ssh hugo@100.94.238.124 \
  'virsh --connect qemu:///system blockresize homelab_worker-node-2 vdb 160G'
```

Vérifier la taille exposée par libvirt :

```bash
ssh hugo@100.94.238.124 \
  'virsh --connect qemu:///system domblkinfo homelab_worker-node-1 vdb'
ssh hugo@100.94.238.124 \
  'virsh --connect qemu:///system domblkinfo homelab_worker-node-2 vdb'
```

Les images raw sont sparse : leur taille virtuelle augmente immédiatement,
mais l'espace physique est consommé progressivement.

### 3. Faire redétecter la taille par Talos

Le contrôleur SATA virtuel ne propage pas forcément la nouvelle géométrie à
chaud. Redémarrer les workers un par un.

Premier worker :

```bash
kubectl cordon talos-ek9-utp
kubectl drain talos-ek9-utp \
  --ignore-daemonsets --delete-emptydir-data --timeout=10m
talosctl --talosconfig ../talosconfig \
  --nodes 192.168.121.85 reboot --wait
```

Si `drain` est bloqué par un PodDisruptionBudget, identifier le workload avant
de décider de le contourner. Une fois le nœud revenu :

```bash
talosctl --talosconfig ../talosconfig \
  --nodes 192.168.121.85 get disks sda
talosctl --talosconfig ../talosconfig \
  --nodes 192.168.121.85 get volumestatuses u-longhorn
```

Le `UserVolumeConfig` de `u-longhorn` possède `grow: true`. Talos doit donc
agrandir automatiquement XFS jusqu'à la nouvelle taille pendant le démarrage.

Attendre que le nœud soit `Ready` et que tous les volumes soient `healthy` :

```bash
kubectl get nodes
kubectl -n longhorn-system get volumes.longhorn.io \
  -o custom-columns=VOLUME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness
kubectl uncordon talos-ek9-utp
```

Répéter seulement ensuite avec le second worker :

```bash
kubectl cordon talos-ku2-xtb
kubectl drain talos-ku2-xtb \
  --ignore-daemonsets --delete-emptydir-data --timeout=10m
talosctl --talosconfig ../talosconfig \
  --nodes 192.168.121.173 reboot --wait
talosctl --talosconfig ../talosconfig \
  --nodes 192.168.121.173 get disks sda
talosctl --talosconfig ../talosconfig \
  --nodes 192.168.121.173 get volumestatuses u-longhorn
kubectl uncordon talos-ku2-xtb
```

### 4. Validation finale

```bash
kubectl -n longhorn-system get nodes.longhorn.io
kubectl -n longhorn-system get volumes.longhorn.io \
  -o custom-columns=VOLUME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness
kubectl get pvc -A
```

En cas d'écart, contrôler dans cet ordre :

1. `virsh domblkinfo` : taille exposée par libvirt ;
2. `talosctl get disks sda` : taille détectée par Talos ;
3. `talosctl get volumestatuses u-longhorn` : taille du système de fichiers ;
4. les ressources `nodes.longhorn.io` : capacité publiée par Longhorn.
