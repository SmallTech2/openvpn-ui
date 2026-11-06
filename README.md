# OpenVPN UI — Radio Bonheur

Deploiement natif valide sur VPS **Debian 13 AMD64** : OpenVPN Community Edition,
OpenVPN UI, Easy-RSA, systemd et nftables. Aucun Docker en production et aucune
compilation sur le VPS.

La version stable est **[radio-v1](https://github.com/SmallTech2/openvpn-ui/releases/tag/radio-v1)**.
Utiliser le script du tag `radio-v1`, jamais celui de `main`, pour une installation reproductible.

- [Installation, exploitation et reconstruction](Radio/README.md).
- [Scripts appeles par OpenVPN UI](Radio/scripts/README.md).
- [Perimetre valide et tracabilite de la version](Radio/RELEASE-radio-v1.md).

La recette reelle a valide l'installation vierge, deux clients a IP fixes,
la communication interclients, le maintien de leur Internet habituel et le
fonctionnement apres redemarrage du VPS. Le cycle de revocation et le renouvellement
reel de la CRL restent a tester en exploitation ; ils ne sont pas annonces comme valides.

Ce fork derive de [d3vilh/openvpn-ui](https://github.com/d3vilh/openvpn-ui).
Les sources et dependances Go sont conservees dans le depot, avec `go.mod`, `go.sum`
et `vendor/`. Voir [LICENSE](LICENSE) pour la licence et les notices des dependances.
