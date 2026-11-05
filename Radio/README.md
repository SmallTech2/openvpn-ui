# Modèles de configuration Radio Bonheur — Debian 13 native

Sources : VPS de référence du 4 novembre 2026. Aucune PKI, clé privée, base de données ni mot de passe.

- `server.conf.tpl` : remplacer `@VPN_NETWORK@` par `10.1.0.0`, `10.2.0.0` ou `10.3.0.0` lors de l’installation.
- `client.conf.tpl` : remplacer `@PUBLIC_IP@` par l’IPv4 du VPS.
- `openvpn-server-config.tpl` : management limité à `127.0.0.1:2080` pour toute future régénération depuis l’interface.
- `nftables.conf.tpl` : **modèle seulement**, ne pas appliquer tel quel avant validation du SSH, du rollback et du pare-feu hébergeur. Le port 22 reste autorisé localement ; restriction via le pare-feu hébergeur.
- `app.conf` : configuration de référence. Le mot de passe administrateur se met dans `/etc/openvpn-ui.env` et n’est jamais inclus dans Git.

Ces modèles ne sont pas encore validés par un nouveau déploiement.
