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

## Version stable et démarrage rapide

La version stable officielle est **[radio-v2.2](https://github.com/SmallTech2/openvpn-ui/releases/tag/radio-v2.2)**.
Utilisez sa référence figée pour installer le logiciel ; une branche de développement
ne remplace pas une version publiée et validée.

Prévoyez un serveur vierge Debian 13 x86_64/AMD64, une IPv4 publique fixe, un accès SSH
interactif avec droits root/sudo et la clé publique ED25519 de votre poste administrateur.
Les accès SSH et UDP 1194 doivent être autorisés par le pare-feu de l'hébergeur.

```sh
curl --fail --location --proto '=https' --proto-redir '=https' \
  https://raw.githubusercontent.com/SmallTech2/openvpn-ui/radio-v2.2/Radio/deploy-vps.sh \
  -o deploy-vps.sh
sudo bash deploy-vps.sh
```

Après la préparation Debian et le redémarrage, reconnectez-vous et relancez la même
commande `sudo bash deploy-vps.sh` depuis le répertoire du script téléchargé.
Le script demande le nom du compte Linux à créer (`technicien` proposé par défaut)
et impose la validation d’une nouvelle connexion SSH par clé avant de poursuivre.

Consultez les [guides dans docs/](docs/README.md) : [installation](docs/installation.md),
[administration](docs/administration.md), [sécurité](docs/security.md) et
[maintenance](docs/maintenance.md). Les évolutions de développement ne sont annoncées
comme stables qu'après leur validation complète et leur publication.

## Validation et limites

Les vérifications déjà réalisées sur un serveur Debian 13 de recette couvrent : installation, interface Web,
services systemd et nftables, deux clients à IP fixes, communication interclients,
Internet habituel conservé et reconnexion après redémarrage. La révocation avec refus
de reconnexion, le renouvellement de la CRL et la persistance des révocations après
renouvellement et redémarrage ont également été validés.

Le filtrage entrant et les deux accès à l'interface ont été vérifiés. Dans la configuration
contrôlée, le routage IP du noyau est désactivé et OpenVPN assure la communication
interclients avec `client-to-client` ; voir le [périmètre documenté](docs/security.md#routage-du-noyau-et-communication-interclients).

Le déploiement fourni cible IPv4 et AMD64. Les sous-réseaux privés acceptés vont de
`/16` à `/29`, limites du mode serveur OpenVPN utilisé. Les autres architectures,
IPv6 et les fonctions facultatives non décrites dans le guide ne font pas partie de
ce périmètre validé. Le script installe un serveur vierge ; il ne migre pas une PKI existante.
Les paquets Debian peuvent évoluer indépendamment de la Release. Une nouvelle installation
complète depuis Debian 13 vierge reste à réaliser pour confirmer définitivement le paquet
actuellement publié, notamment le parcours SSH et son intégration au déploiement.

## Licence et crédits

Projet sous [licence MIT](LICENSE). Les attributions d'Adam Wałach et de Mr. Philipp
(d3vilh), auteurs du projet d'origine et de ses évolutions, sont conservées.
Les dépendances tierces et leurs notices restent dans `vendor/` ; leurs versions sont
référencées dans `go.mod` et `go.sum`.
