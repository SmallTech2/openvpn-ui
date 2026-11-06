# Sécurité — préparation de radio-v2

> **radio-v2 est la prochaine version stable, encore en préparation.** Le tag et
> la Release `radio-v2` ne sont pas encore publiés. La validation complète sur Debian 13 vierge doit
> précéder la publication. `radio-v1` reste la version stable actuellement disponible.

## Compte administrateur et SSH


Le script prévu pour `radio-v2`, actuellement sur `main`, demande le nom du compte Linux ; appuyez sur Entrée pour conserver
`technicien`. Le nom doit contenir de 1 à 32 caractères : lettres minuscules, chiffres,
`_` ou `-`, avec une lettre ou `_` en premier. Un nom correspondant déjà à un utilisateur
ou à un groupe est refusé pour éviter de modifier un compte existant.

Dans les exemples SSH ci-dessous, remplacez `UTILISATEUR_LINUX` par le nom choisi.
Avec le script stable `radio-v1`, ce nom reste `technicien`.
Le compte dispose d'un répertoire personnel, de Bash, de sudo avec mot de passe
et de la clé fournie. La configuration SSH est validée avant rechargement.

## Validation obligatoire par clé

Le script ne force plus `PasswordAuthentication yes` pendant la préparation :
il conserve le réglage existant tant que l'accès par clé n'est pas prouvé.
Il installe et vérifie la commande `/usr/local/bin/radio-secure-ssh`, puis attend :

1. Gardez la session d'installation ouverte. Depuis un **autre terminal de votre poste**,
   utilisez la commande SSH affichée par le script pour vous connecter avec le compte créé.
   Elle impose une nouvelle authentification par clé, sans réutiliser une session multiplexée
   ni accepter de mot de passe SSH. Ajoutez `-i CHEMIN_CLE_PRIVEE` si nécessaire.
2. Dans cette nouvelle session, exécutez `echo "$SSH_CONNECTION"` et gardez-la ouverte.
3. Copiez les quatre valeurs affichées dans la demande de l'installateur.

L'installateur vérifie dans le journal du démarrage courant une authentification
`publickey` pour **ce compte, cette connexion et l'empreinte de la clé installée**.
Une simple confirmation ou une connexion par mot de passe ne suffit pas.
Sans preuve, aucun mot de passe n'est désactivé et l'installation ne continue pas.

Après cette preuve, le helper impose les valeurs suivantes et les contrôle avec
`sshd -t`, puis `sshd -T`, globalement et dans le contexte complet de la connexion
(compte, IP source, IP locale et port local), y compris les règles `Match` applicables :

```text
pubkeyauthentication yes
authenticationmethods publickey
passwordauthentication no
kbdinteractiveauthentication no
```

Seul un rechargement de `ssh` est demandé ; les sessions ouvertes sont conservées.
Une erreur de syntaxe, de configuration effective ou de rechargement provoque la restauration
du fichier précédent et une nouvelle tentative de validation. L'installateur ne déclare
pas l'installation terminée sans réussite de cette étape.
Vérifiez une nouvelle connexion après durcissement avant de fermer les sessions conservées.

La commande reste disponible pour un contrôle ou un nouveau durcissement ultérieur,
depuis la session par clé du compte administrateur :

```sh
sudo /usr/local/bin/radio-secure-ssh "$SSH_CONNECTION"
```

Elle est exécutée automatiquement par l'installateur pendant l'étape obligatoire ;
ce n'est plus une opération facultative à penser à lancer après installation.

## Différence historique avec radio-v1

Le script figé de `radio-v1` pouvait laisser l'authentification par mot de passe active
si son durcissement final n'aboutissait pas. La correction ci-dessus est propre à `main` ;
elle ne modifie pas la Release ni les serveurs déjà installés.

## Protection réseau et retour arrière

L'UI dépend de `nftables.service`. Le pare-feu autorise SSH sur les ports effectifs,
UDP 1194, loopback, ICMP et TCP 8080 uniquement depuis `tun0`.

A l'installation, un retour arrière systemd est armé pour trois minutes, avec retour
immédiat sur erreur. Il restaure les règles précédentes et arrête VPN/UI. Il n'est annulé
qu'après les contrôles locaux des services, de l'adresse CIDR de `tun0`, de l'UDP et du HTTP.
Vérifiez une nouvelle connexion SSH depuis votre poste avant de fermer la session
utilisée pour l'installation ou une intervention réseau.


L'accès à l'interface Web et le tunnel SSH sont décrits dans le
[guide d'administration](administration.md#accès-à-openvpn-ui).
