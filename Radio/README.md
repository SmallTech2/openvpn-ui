# Radio Bonheur - deploiement natif Debian 13

Trois VPS AMD64 independants : `10.1.0.0/16`, `10.2.0.0/16`, `10.3.0.0/16`.
OpenVPN CE, OpenVPN UI precompile, Easy-RSA, systemd et nftables. Aucun Docker ni Go sur le VPS.
Tous les clients ont une IPv4 fixe ; `client-to-client` est actif, sans `redirect-gateway`.

## Premiere recette

La Release requise est `radio-build-test2`, compilee APRES ces corrections. `radio-build-test1` est incompatible.
Ne reinitialiser aucun VPS d'exploitation avant sauvegarde et validation de la Release de recette.
Sur le VPS Debian 13 vierge, avec un terminal interactif :

```sh
curl --fail --location --proto '=https' --proto-redir '=https' \
  https://raw.githubusercontent.com/SmallTech2/openvpn-ui/radio-build-test2/Radio/deploy-vps.sh \
  -o deploy-vps.sh
sudo bash deploy-vps.sh install
```

L'IPv4 et le reseau peuvent aussi etre passes en arguments :
`sudo bash deploy-vps.sh install IP_PUBLIQUE 10.1`.
Le script demande les deux mots de passe, la cle PUBLIQUE ED25519 du poste administrateur,
l'organisation et l'email PKI. Ne pas fournir une cle privee ni la cle reservee a l'acces GitHub.
Il initialise la base GUI, les configurations et une PKI neuve, puis demarre les services.
Aucune etape GUI ni seconde commande n'est necessaire pour obtenir un VPN operationnel.
Les erreurs importantes provoquent un statut non nul, sans message de succes.

## Acces et protection SSH

Le compte `technicien` dispose de sudo avec mot de passe et de la cle fournie.
La configuration SSH est validee avant rechargement. Les mots de passe SSH ne sont desactives
que si le journal du boot prouve l'utilisation de cette cle sur la connexion courante.
Sinon ils restent actifs : cette validation client ne peut pas etre deduite de la seule presence d'une cle publique.
Apres une connexion technicien par cle, la commande facultative suivante termine ce durcissement :

```sh
sudo radio-secure-ssh "$SSH_CONNECTION"
```

Elle controle la preuve de connexion, les regles SSH effectives et restaure l'ancienne configuration en cas d'erreur.
La session initiale doit rester ouverte pendant le premier test de reconnexion.

nftables autorise les ports SSH effectifs (y compris celui de la connexion en cours), UDP 1194,
le loopback, ICMP et l'UI TCP 8080 uniquement depuis `tun0`.
Il est active et persistant AVANT le demarrage de l'UI. Un retour arriere differe de trois minutes,
et immediat sur erreur du script, restaure les anciennes regles/configuration et arrete VPN/UI.
Le retour arriere est annule uniquement apres les controles locaux des services, du HTTP et de SSH.
Le pare-feu de l'hebergeur doit egalement autoriser SSH et UDP 1194 ; ne pas y ouvrir TCP 8080.

GUI : `http://10.N.0.1:8080` depuis le VPN, ou tunnel depuis le PC :
`ssh -L 8080:127.0.0.1:8080 technicien@IP_PUBLIQUE`, puis `http://127.0.0.1:8080`.
Le management OpenVPN reste strictement sur `127.0.0.1:2080`.

## Configurations et exploitation

`RadioVpnNetwork` et `RadioPublicIP` sont generes dans `/opt/openvpn-ui-runtime/conf/app.conf`.
Ils initialisent les valeurs SQLite et restent appliques aux sauvegardes des formulaires GUI.
Les anciens sous-reseaux, routes et valeurs loopback des profils clients ne sont pas reutilises pour Radio.
Les IP fixes sont controlees dans le reseau du serveur ; les adresses reservees et deja utilisees sont refusees.
`nopool` et `ccd-exclusive` empechent les attributions dynamiques. Les fichiers CCD restent lisibles par OpenVPN.
Les profils contiennent une seule copie complete des blocs PEM et `tls-crypt` ; les fichiers contenant
les cles clientes sont prives. Les mots de passe clients ne sont plus interpoles dans un shell ni journalises.

`/etc/openvpn/pki` pointe sur `/usr/share/easy-rsa/pki`. Une CA existante interdit `init_all`.
La suppression des fichiers d'un client ne supprime jamais les entrees revoquees de l'index de la CA.
Le renouvellement hebdomadaire via `radio-renew-crl.timer` ne peut donc pas oublier ces revocations.
La CRL initiale est controlee et un renouvellement est execute pendant le deploiement.
Les changements de configuration serveur redemarrent OpenVPN via systemd ; les modifications des
modeles clients et variables Easy-RSA n'arretent pas le VPN.

## Compilation, ressources et Release de recette

`.github/workflows/radio-build.yml` compile et teste les branches `main`/`radio/**`, les PR et les tags de recette.
Le ZIP contient le binaire, `static/`, `views/`, `swagger/`, les sources `Radio/`, la licence,
le commit source et les empreintes internes. Une empreinte du ZIP est publiee separement.
Le deploiement verifie le ZIP avant extraction, puis son contenu ; il telecharge les scripts de la revision compilee.
`RADIO_SOURCE_REF` accepte une branche, un tag ou un commit, mais sa revision resolue doit correspondre
au binaire de la Release. `RADIO_RELEASE_TAG` choisit une autre Release de recette compatible.

Apres succes des controles, un tag `radio-build-testN` declenche la publication d'une **preversion**.
Le workflow manuel accepte aussi un nom de preversion ; laisser ce champ vide pour compiler seulement.
Les noms de version definitive, dont `radio-v1`, sont refuses par ce workflow de publication.
Aucun workflow ne se connecte a un VPS ni ne deploie un serveur.

## Limites de validation

Les tests Go couvrent les trois reseaux et les IP fixes. Les tests du binaire verifient SQLite,
les configurations generees et l'echec explicite d'une initialisation invalide.
Les tests Easy-RSA 3.2.2 generent de vrais certificats, profils et CRL, y compris renouvellement,
revocation, suppression des fichiers et nouvelle CRL. Aucun daemon OpenVPN n'est lance par ces tests.
Ces controles ne remplacent pas une recette sur Debian 13 : demarrage systemd, acces distant SSH,
filtrage reseau reel, connexion de deux clients fixes, trafic client-to-client et redemarrage du VPS
restent a verifier avant toute version definitive.
