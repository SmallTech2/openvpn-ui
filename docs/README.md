# Documentation OpenVPN UI

**radio-v2 est la prochaine version stable, encore non publiée.**
La version stable disponible reste [radio-v1](releases/radio-v1.md).

## Guides utilisateur

- [Installation](installation.md) : prérequis, commandes préparées pour `radio-v2`, recette de `main`, redémarrage et paramètres.
- [Administration](administration.md) : interface Web, tunnel SSH, clients à IP fixes et révocation.
- [Sécurité](security.md) : compte Linux, preuve d'accès par clé, durcissement SSH et protection réseau.
- [Maintenance](maintenance.md) : CRL, services, diagnostic et reconstruction.
- [radio-v2, état de préparation](releases/radio-v2.md) et [radio-v1, référence historique](releases/radio-v1.md).
- [Captures de l'interface d'origine](screenshots.md) : illustrations, sans valeur de validation de la prochaine version.

## Références techniques

- [Déploiement](../Radio/README.md).
- [Scripts](../Radio/scripts/README.md).
- [Modèles de configuration](../Radio/config/README.md).

Les scripts et configurations restent dans `Radio/`. Le dossier `test/` contient
uniquement les tests ; les notices et les guides des dépendances restent dans `vendor/`.
Le fichier `docker-compose.yml` conservé dans ce dossier est un exemple amont et ne fait
pas partie du déploiement natif documenté ici.
