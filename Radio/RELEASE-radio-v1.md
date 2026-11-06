Version stable du deploiement natif sur Debian 13 AMD64 : OpenVPN CE,
OpenVPN UI, Easy-RSA, systemd et nftables. Aucun Docker ni compilation sur le VPS.

La recette reelle Infomaniak a ete validee le 6 novembre 2026 : installation vierge,
deux clients a IP fixes, connexions simultanees, communication interclients,
Internet habituel conserve, tunnel SSH vers l'UI et fonctionnement apres reboot.

Le deploiement valide est `db5b79d24ceb57eeee864e3ec15783ffba51fc91`.
Le tag `radio-v1` ajoute uniquement le gel de version, la documentation et les metadonnees
de publication ; le comportement applicatif valide est conserve.

Le binaire de `radio-build-test3` est reutilise sans recompilation :

- Sources du binaire : `684151fb3a0ad27e392f79e617cb649583c4e8ff` (`source-commit.txt`).
- SHA-256 du binaire : `5e5255d176839be76df6d08fd373dd62fc915fd86bb2ffb90ad9bfe34d8b53b8`.
- Sources des scripts et modeles figes : commit du tag `radio-v1` (`deployment-source-commit.txt`).
- Le ZIP est reconstitue avec ce binaire inchange et les fichiers Radio finalises ;
  son empreinte figure dans `radio-openvpn-ui-linux-amd64.zip.sha256`.

Installation et exploitation : [Radio/README.md](https://github.com/SmallTech2/openvpn-ui/blob/radio-v1/Radio/README.md).
Le telechargement du script doit utiliser `radio-v1`, jamais `main`.

Restent a valider sur le VPS reel : revocation avec refus de reconnexion,
renouvellement effectif de la CRL et persistance des revocations apres regeneration/reboot.
Ces operations n'ont pas ete executees pendant cette finalisation.
