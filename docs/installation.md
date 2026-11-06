# Installation

Les exemples de réseaux sont fictifs. Adaptez-les à votre installation.

## Prérequis

- VPS vierge Debian 13, architecture x86_64/AMD64, systemd et droits root/sudo.
- Session SSH interactive, commande `ip` (paquet `iproute2`) et `curl` pour le téléchargement.
- IPv4 publique fixe, accès HTTPS sortant aux miroirs Debian et à GitHub.
- Clé SSH **publique ED25519** du poste administrateur. Ne pas fournir la clé privée.
- Autoriser le port SSH utilisé et UDP 1194 dans le pare-feu de l'hébergeur.
  Ne pas ouvrir TCP 8080 sur Internet.
- Choisir un sous-réseau privé qui ne chevauche pas les réseaux des clients et du VPS.

## Télécharger la référence publiée

Utilisez la commande du [README principal](../README.md#version-stable-et-démarrage-rapide).
Elle fixe la référence du script et le paquet associé ; ne remplacez pas cette référence
par une branche de développement. Aucun téléchargement de version future n'est nécessaire.

Conservez le fichier téléchargé pendant toute l'installation, y compris pour la relance
après redémarrage. Ne le téléchargez pas à nouveau entre ces deux étapes.

## Préparation Debian et paramètres interactifs

Au premier lancement, une confirmation précède `apt-get update`, `apt-get full-upgrade`
(en conservant les fichiers de configuration locaux) et `apt-get autoremove --purge`.
Le VPS redémarre ensuite. Après reconnexion SSH, relancer dans le même répertoire :

```sh
sudo bash deploy-vps.sh
```

L'état `/var/lib/radio-vpn/debian-upgrade-boot-id` est enregistré uniquement après
réussite des commandes APT. Le script vérifie le changement de démarrage et ne refait
pas la mise à niveau. Il ne reprend pas automatiquement et ne stocke aucun mot de passe
pour traverser le redémarrage.

Le script propose l'IPv4 publique détectée, modifiable, puis demande :

- Réseau VPN privé CIDR, par exemple `10.77.0.0/16` ou `192.168.42.0/24`.
- Si l’installateur le propose, nom du compte administrateur Linux ; sinon le compte
  fixé par le script est indiqué dans le README de la référence publiée.
- Clé publique SSH, organisation et email de la PKI ; remplacez les valeurs proposées par celles de votre organisation.
- Après confirmation et configuration interactive de la disposition du clavier :
  mots de passe du compte Linux créé et de l'administrateur OpenVPN UI.

Les deux mots de passe suivent la même règle : huit caractères minimum, aucune limite
maximale ajoutée par le script, espaces, accents et symboles acceptés sur une ligne,
saisie masquée et confirmation. Ils ne sont pas affichés dans le récapitulatif.
Une seconde confirmation précède l'installation VPN.
Lorsque l'installateur propose une validation dans une seconde session SSH, suivez-la
avant de poursuivre. Dans tous les cas, vérifiez l'accès par clé et le durcissement
[selon le guide de sécurité](security.md#vérifier-laccès-par-clé).

Les réseaux RFC1918 sont acceptés de `/16` à `/29`, limites de la directive serveur OpenVPN
avec `tun`. Une adresse d'hôte à la place de l'adresse réseau et les chevauchements
avec les routes présentes sur le VPS sont refusés. Les conflits avec les futurs réseaux
clients restent à vérifier par l'administrateur. Le serveur utilise toujours **réseau + 1** :
`10.77.0.0/16` donne `10.77.0.1/16`, `192.168.42.0/24` donne `192.168.42.1/24`.

Le script refuse de remplacer une installation ou une CA existante. Il télécharge le
paquet de la Release sélectionnée, vérifie son SHA-256 puis les empreintes internes et
utilise les sources de déploiement du commit inscrit dans ce paquet.
Conservez la référence figée fournie dans le README principal, sans la remplacer par une
branche de développement ou par un lien mouvant de type « latest ».

Après installation : [administration](administration.md), [sécurité SSH](security.md)
et [maintenance](maintenance.md).
