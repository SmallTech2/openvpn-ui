# Version stable radio-v1

[radio-v1](https://github.com/SmallTech2/openvpn-ui/releases/tag/radio-v1) fournit
le déploiement natif sur Debian 13 AMD64 : OpenVPN Community Edition,
OpenVPN UI, Easy-RSA, systemd et nftables, sans Docker ni compilation sur le serveur.

## Fonctionnement validé

Les validations réelles rapportées couvrent :

- Installation automatisée depuis un serveur Debian 13 vierge.
- Fonctionnement d'OpenVPN, de l'interface Web, de systemd et de nftables.
- Création de clients à IP fixes, connexion simultanée et communication interclients.
- Conservation de l'accès Internet habituel des clients.
- Redémarrage du serveur et reconnexion des clients.
- Révocation d'un certificat avec refus de reconnexion.
- Renouvellement de la CRL et persistance de la révocation après renouvellement et redémarrage.

## Fichiers et traçabilité

La Release conserve le binaire validé, le paquet de déploiement et leurs empreintes SHA-256.
Le paquet identifie séparément les sources du binaire (`source-commit.txt`) et les
sources des scripts et modèles (`deployment-source-commit.txt`). Les sources et les
dépendances Go sont disponibles dans le dépôt.

Pour cette version historique, consultez le [guide d’installation historique](https://github.com/SmallTech2/openvpn-ui/blob/radio-v1/Radio/README.md)
du tag figé. Le téléchargement du script utilise le tag `radio-v1`.
Cette actualisation documentaire ne modifie ni le tag ni les fichiers de la Release.

## Installation de cette version historique

```sh
curl --fail --location --proto '=https' --proto-redir '=https' \
  https://raw.githubusercontent.com/SmallTech2/openvpn-ui/radio-v1/Radio/deploy-vps.sh \
  -o deploy-vps.sh
sudo bash deploy-vps.sh
```

Les évolutions de la prochaine version sont présentées dans [radio-v2](radio-v2.md).
La documentation générale courante se trouve dans [docs/](../README.md).
