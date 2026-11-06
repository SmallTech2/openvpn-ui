# Composants du déploiement natif

La documentation utilisateur est dans [docs/](../docs/README.md) :
[installation](../docs/installation.md), [administration](../docs/administration.md),
[sécurité](../docs/security.md) et [maintenance](../docs/maintenance.md).
`radio-v2` est en préparation ; elle n'est pas publiée.

Ce dossier conserve les chemins nécessaires au déploiement :

- `deploy-vps.sh` : installateur interactif autonome.
- `package-release.sh` : création du paquet du binaire, des ressources et de la documentation.
- [scripts/](scripts/README.md) : opérations appelées par l'interface et le déploiement.
- [config/](config/README.md) : modèles de configuration et unités systemd.
- [RELEASE-radio-v1.md](RELEASE-radio-v1.md) : renvoi maintenu pour le workflow de publication historique.

Les tests sont regroupés dans `test/` à la racine du dépôt. Aucun script de déploiement
ni modèle de configuration n'a changé de chemin.
