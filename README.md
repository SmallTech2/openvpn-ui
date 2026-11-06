# OpenVPN UI — déploiement natif sur Debian 13

Déployez un serveur OpenVPN et son interface Web d'administration sur un serveur
**Debian 13 AMD64**, avec un script interactif. L'installation utilise OpenVPN Community
Edition, Easy-RSA, systemd et nftables, sans Docker ni compilation sur le serveur.

Cette adaptation de [d3vilh/openvpn-ui](https://github.com/d3vilh/openvpn-ui), initiée
par Radio Bonheur, s'adresse à toute personne ou organisation souhaitant administrer
un réseau VPN à adresses fixes. Le nom du dossier `Radio/` est conservé pour la
compatibilité des chemins de déploiement.

## Fonctionnalités

- Préparation de Debian, configuration SSH et installation automatisée des services.
- Réseau IPv4 privé configurable et adresse fixe par client.
- Création, téléchargement, renouvellement et révocation des certificats dans l'interface Web.
- Profils `.ovpn` complets avec `tls-crypt` et communication interclients.
- Conservation de l'accès Internet habituel des clients, sans redirection de leur passerelle.
- Interface accessible depuis le VPN ou un tunnel SSH, protégée par nftables.
- Renouvellement automatique de la liste de révocation des certificats (CRL).

## Démarrage rapide et prochaine version stable

**`radio-v2` est la prochaine version stable, non encore publiée.** Sa publication
attend la validation intégrale sur Debian 13 vierge. Les téléchargements du futur tag
ne sont pas disponibles. La version stable actuelle reste
[radio-v1](https://github.com/SmallTech2/openvpn-ui/releases/tag/radio-v1).

Prévoyez un serveur vierge Debian 13 x86_64/AMD64, une IPv4 publique fixe, un accès SSH
interactif avec droits root/sudo et la clé publique ED25519 de votre poste administrateur.
Les accès SSH et UDP 1194 doivent être autorisés par le pare-feu de l'hébergeur.

Pour la **recette de la branche `main` avant publication**, sur un serveur vierge dédié :

```sh
curl --fail --location --proto '=https' --proto-redir '=https' \
  https://raw.githubusercontent.com/SmallTech2/openvpn-ui/main/Radio/deploy-vps.sh \
  -o deploy-vps.sh
sudo env RADIO_RELEASE_TAG=radio-v1 bash deploy-vps.sh
```

Le script demande une relance après la préparation Debian et le redémarrage.
Ce parcours utilise le paquet déjà publié `radio-v1` avec le script de `main` ;
il n'installe pas une Release `radio-v2` inexistante.

Consultez les [guides dans docs/](docs/README.md) : [installation](docs/installation.md),
[administration](docs/administration.md), [sécurité](docs/security.md) et
[maintenance](docs/maintenance.md). Les commandes utilisant le futur tag `radio-v2`
sont préparées dans le guide d'installation et réservées à l'après-publication.

## Validation et limites

La version historique `radio-v1` a été validée sur Debian 13 vierge : installation, interface Web,
services systemd et nftables, deux clients à IP fixes, communication interclients,
Internet habituel conservé et reconnexion après redémarrage. La révocation avec refus
de reconnexion, le renouvellement de la CRL et la persistance des révocations après
renouvellement et redémarrage ont également été validés.

Le déploiement fourni cible IPv4 et AMD64. Les sous-réseaux privés acceptés vont de
`/16` à `/29`, limites du mode serveur OpenVPN utilisé. Les autres architectures,
IPv6 et les fonctions facultatives non décrites dans le guide ne font pas partie de
ce périmètre validé. Le script installe un serveur vierge ; il ne migre pas une PKI existante.
Les paquets Debian peuvent évoluer indépendamment de la Release. La validation complète
de `radio-v2` reste à réaliser ; les résultats de `radio-v1` ne la remplacent pas.

## Licence et crédits

Projet sous [licence MIT](LICENSE). Les attributions d'Adam Wałach et de Mr. Philipp
(d3vilh), auteurs du projet d'origine et de ses évolutions, sont conservées.
Les dépendances tierces et leurs notices restent dans `vendor/` ; leurs versions sont
référencées dans `go.mod` et `go.sum`.
