# Documentation OpenVPN UI

La version stable officielle et la commande de téléchargement figée sont indiquées
uniquement dans le [README principal](../README.md#version-stable-et-démarrage-rapide).
Les guides ci-dessous restent indépendants de son numéro.

## Guides utilisateur

- [Installation](installation.md) : prérequis, téléchargement publié, redémarrage et paramètres.
- [Administration](administration.md) : interface Web, tunnel SSH, clients à IP fixes et révocation.
- [Sécurité](security.md) : compte Linux, accès par clé, vérification du durcissement SSH et protection réseau.
- [Maintenance](maintenance.md) : CRL, services, diagnostic et reconstruction.
- [Captures de l'interface d'origine](screenshots.md) : illustrations de l'interface.

## Références techniques

- [Déploiement](../Radio/README.md).
- [Scripts](../Radio/scripts/README.md).
- [Modèles de configuration](../Radio/config/README.md).

Les scripts et configurations restent dans `Radio/`. Le dossier `test/` contient
uniquement les tests ; les notices des dépendances restent dans `vendor/`.
Le fichier `docker-compose.yml` conservé dans ce dossier est un exemple amont et ne fait
pas partie du déploiement natif documenté ici.
