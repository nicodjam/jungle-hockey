# Jungle Hockey

Air hockey local multijoueur pour tablette Android (cible : Samsung Galaxy Tab S11), écrit en Flutter, sans dépendance externe.

La tablette est posée à plat, en paysage. Les équipes se font face aux deux petits côtés : chacune défend le but de son côté et frappe le palet avec ses maillets, au doigt.

## Règles

- **1 contre 1** ou **2 contre 2** : chaque joueur contrôle un maillet.
- Il faut poser le doigt sur un maillet pour le saisir ; il suit alors le doigt (vitesse bornée) sans sortir de son camp.
- Premier à 5, 7 ou 10 points (au choix dans le menu).
- Après un but, le palet est remis en jeu dans le camp de l'équipe qui a encaissé.
- Bouton central : pause / reprise / recommencer.

### Équilibrage

Mode optionnel (interrupteur « Équilibrage » du menu) pour faire jouer ensemble des joueurs de niveaux différents. À chaque point d'avance, les tirs de l'équipe qui mène perdent 8 % de leur vitesse et ceux de l'équipe menée en gagnent 8 %, jusqu'à −40 % / +40 % (5 points d'écart). La vitesse maximale du palet suit le même facteur. À égalité, rien ne change.

L'effet s'affiche près du score de chaque équipe (« TIRS −24 % », « TIRS +24 % ») et se multiplie avec les pouvoirs : une équipe qui mène de 3 points avec le turbo tire à 0,76 × 1,5 ≈ 1,14 fois la vitesse normale. Réglages : `balanceStep`, `balanceMin`, `balanceMax` dans `lib/game/config.dart`.

### Pouvoirs

Des objets apparaissent au hasard sur le terrain (2 au maximum, toutes les 4 à 8 s ; ils disparaissent au bout de 14 s s'ils ne sont pas pris). Quand le palet touche un objet, l'équipe qui l'a **frappé en dernier** (même après des rebonds sur les bandes) obtient le pouvoir pendant **5 secondes**, et l'objet disparaît. Un palet que personne n'a encore frappé depuis la remise en jeu passe dessus sans effet.

| Pouvoir | Effet |
|---|---|
| ⚡ **Turbo** | Les tirs de l'équipe partent 1,5 fois plus vite (vitesse max relevée d'autant). |
| ⏳ **Frein adverse** | Les tirs de l'adversaire sont ralentis de moitié. |
| 🎯 **Tête chercheuse** | Après une frappe de l'équipe, le palet s'oriente vers le milieu du but adverse. |
| 🟢 **Maillet géant** | Les maillets de l'équipe grossissent (×1,6) : plus faciles pour défendre et frapper. |
| 🌫️ **Brouillard** | Le centre du terrain se couvre d'une brume presque opaque : le palet y devient à peine visible. |
| 🥅 **Cage adverse géante** | La cage de l'adversaire s'élargit (×1,6) : le terrier s'étend sur la palissade. |
| 🚪 **Cage rétrécie** | La cage de l'équipe se referme (×0,55) : du bambou bouche une partie de l'ouverture. |

Les pouvoirs **se cumulent** : une équipe peut avoir par exemple brouillard et turbo en même temps, chacun avec son propre chrono ; reprendre un pouvoir déjà actif remet ses 5 secondes à plein. Chaque pouvoir actif s'affiche sur une ligne près du bord de l'équipe, avec une jauge du temps restant ; ses maillets s'entourent d'un anneau par pouvoir, et le palet prend cette couleur tant que le pouvoir agit sur le tir en cours. Les pouvoirs se désactivent dans le menu. Tous les réglages sont dans `lib/game/config.dart`.

## Démarrer

```bash
flutter pub get
flutter test
flutter run            # tablette branchée en débogage USB ou Wi-Fi
```

Identifiant Android : `com.nicodjam.junglehockey`. Le manifeste verrouille le paysage (`screenOrientation`) et déclare l'appli comme jeu (`appCategory="game"`) : depuis Android 16, sur tablette, le système ignore le verrouillage d'orientation des autres applis.

Nécessite Flutter ≥ 3.27 (Dart ≥ 3.6).

## Scripts (`tool/`)

Repris de Pitchoune Timer.

| Script | Rôle |
|---|---|
| `source tool/env.sh` | Trouve Flutter, le SDK Android et Java, les met dans le `PATH`, et dit comment installer ce qui manque (`tool/env.sh --print` donne les lignes pour `~/.bashrc`). |
| `tool/connect.sh <ip:port>` | Connecte la tablette en débogage sans fil et la mémorise (`--pair <ip:port>` la première fois). |
| `tool/build.sh` | Construit l'APK release et vérifie sa signature (`--debug` accepte la clé de debug). |
| `tool/install.sh` | Installe le dernier build sur la tablette, en mise à jour. |
| `tool/logs.sh` | Logs du jeu sans le bruit (`-f` en direct, `--clear`, `--all`). |
| `python3 tool/generate_decor.py` | Redessine le décor de jungle (`assets/decor/jungle.webp`). Voir ci-dessous. |
| `python3 tool/generate_sounds.py` | Resynthétise les effets sonores (`assets/sounds/`). Voir ci-dessous. |
| `python3 tool/generate_icons.py` | Redessine l'icône de l'appli (maillet en noix de coco et bambou qui frappe un palet en tranche d'ananas, fond de jungle) : `assets/icon/` et toutes les icônes Android, adaptatives comprises. |

Usage courant : `tool/build.sh --debug && tool/install.sh`.

### Décor

Le décor de la table est une seule image plein écran : la surface de jeu (une clairière moussue avec des taches de soleil et l'ombre des feuillages) entourée d'une palissade de bambou, de végétation, de fleurs d'hibiscus et de frangipanier, de lianes, de noix de coco et de papillons. Les buts sont des terriers entre deux poteaux de bambou. Le jeu dessine par-dessus les lignes, la couleur des équipes dans les buts, les maillets et le palet.

L'image est générée par `tool/generate_decor.py` (SVG rendu par Chromium, comme les icônes de Pitchoune Timer) :

```bash
pip install pillow playwright && playwright install chromium
python3 tool/generate_decor.py                                  # réécrit assets/decor/jungle.webp
python3 tool/generate_decor.py --preview build/decor-preview.png  # + aperçu avec maillets et palet
```

Les dimensions viennent du code du jeu (`config.dart`, `table_layout.dart`) : après un changement de la table ou des buts, relancer le script. Le cadre est dessiné pour une moitié puis recopié tourné de 180°, pour que les deux camps voient le même décor. Le tirage est fixe (`SEED`) : changer cette valeur donne une autre variante. Sans l'image, le jeu retombe sur le plateau uni.

### Sons

Ambiance jungle, entièrement synthétisée par `tool/generate_sounds.py` (numpy, aucun échantillon ni droit à gérer) :

| Son | Quand | Recette |
|---|---|---|
| `hit_1..3.wav` | contact maillet/palet | « tock » creux de noix de coco, trois hauteurs jouées à tour de rôle ; volume selon la force du coup |
| `power.wav` | un pouvoir commence | arpège de marimba montant et scintillement |
| `goal.wav` | but | tambours (da-da-DOUM) et appel de marimba |
| `victory.wav` | fin de partie | roulement de tambours et mélodie de marimba |

```bash
pip install numpy && python3 tool/generate_sounds.py
```

Les sons sont lus par `audioplayers` en mode basse latence (SoundPool), chargés au démarrage, et se mêlent à la musique éventuelle sans la couper. Interrupteur « Sons » dans le menu.

### Clé de release

Sans clé, `tool/build.sh --debug` suffit pour jouer. Pour des builds qui se mettent à jour entre eux (et qu'on peut diffuser) :

1. Créer la clé, hors du dépôt :
   ```bash
   keytool -genkey -v -keystore ~/keys/jungle-hockey.jks -keyalg RSA -keysize 2048 -validity 10000 -alias jungle
   ```
2. Créer `android/key.properties` (ignoré par git), avec un chemin **absolu** :
   ```properties
   storeFile=/home/<moi>/keys/jungle-hockey.jks
   storePassword=...
   keyAlias=jungle
   keyPassword=...
   ```
3. Dans `android/app/build.gradle.kts` (généré par `flutter create`), charger ce fichier et signer la release avec :
   ```kotlin
   import java.io.FileInputStream
   import java.util.Properties

   val keystorePropertiesFile = rootProject.file("key.properties")
   val keystoreProperties = Properties().apply {
       if (keystorePropertiesFile.exists()) load(FileInputStream(keystorePropertiesFile))
   }

   android {
       // ...
       signingConfigs {
           create("release") {
               keyAlias = keystoreProperties["keyAlias"] as String?
               keyPassword = keystoreProperties["keyPassword"] as String?
               storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
               storePassword = keystoreProperties["storePassword"] as String?
           }
       }
       buildTypes {
           release {
               signingConfig = if (keystorePropertiesFile.exists()) {
                   signingConfigs.getByName("release")
               } else {
                   signingConfigs.getByName("debug")
               }
           }
       }
   }
   ```

## Architecture

```
lib/
  main.dart                  App, orientation paysage, plein écran immersif
  game/
    config.dart              Dimensions (table 1720×1000 unités, 16:10 bandes comprises) et réglages physiques
    entities.dart            Side, Puck, Mallet
    power_ups.dart           Types de pouvoirs, objets du terrain, pouvoir actif
    air_hockey_game.dart     Moteur : physique, buts, score, phases, saisie multitouch
  ui/
    table_layout.dart        Conversion écran ↔ table (mise à l'échelle centrée), épaisseur des bandes
    decor.dart               Chargement de l'image du décor (au démarrage)
    sound_effects.dart       Effets sonores (basse latence, chargés au démarrage)
    table_painter.dart       Rendu CustomPainter du plateau, des maillets, du palet, des scores
    power_painting.dart      Rendu des objets, pictogrammes et effets des pouvoirs
    game_screen.dart         Boucle (Ticker), multitouch (Listener), haptique, menus pause/fin
    menu_screen.dart         Choix du mode et du score cible (décor assombri en fond)
assets/decor/
  jungle.webp                Décor de la table, généré par tool/generate_decor.py
assets/sounds/               Effets sonores, générés par tool/generate_sounds.py
assets/icon/                 Icône de l'appli (sources SVG et PNG), générée par tool/generate_icons.py
test/
  air_hockey_game_test.dart  Tests du moteur (rebonds, buts, saisie, ligne médiane, pause)
  power_ups_test.dart        Tests des pouvoirs (ramassage, durée, effets)
  balance_test.dart          Tests du mode équilibrage
```

Principes :

- **Le moteur ne dépend d'aucun widget.** `AirHockeyGame` est un `ChangeNotifier` piloté par `update(dt)` et `pointerDown/Move/Up` en coordonnées table : il se teste sans écran, et le rendu ne fait que le lire.
- **Physique en unités table**, indépendante de la résolution ; `TableLayout` fait la mise à l'échelle.
- **Sous-pas** (6 par image) et vitesse de maillet bornée : pas d'effet tunnel même avec un geste rapide.
- Les maillets ont une masse infinie ; le palet subit un amortissement exponentiel et une vitesse plafonnée.
- Textes (scores, « BUT ! », « VICTOIRE ») orientés vers chaque camp.

## Pistes

- Mode solo contre une IA simple.
- Réglages de difficulté (taille des buts, vitesse du palet).
- Effets visuels sur les buts (particules, flash de la gorge).
