# Audio du jeu

## Musique

| Moment | Piste | Emplacement |
|---|---|---|
| En jeu | **The Cyber Grind — Meganeko** (votre fichier) | `meganeko - The Cyber Grind (Ultrakill Soundtrack).mp3` à la racine du projet |
| Menu principal | `menu_theme.wav` (composé pour le projet, original) | `assets/audio/music/menu_theme.wav` |

Le morceau de Meganeko est protégé par le droit d'auteur : il n'est pas
généré ni redistribué par ce dépôt (fichier exclu via `.gitignore`). Le jeu le
charge depuis votre propre copie.
Si vous le déplacez, `scripts/sound.gd` (`GAME_MUSIC_CANDIDATES`) accepte aussi
`assets/audio/music/the_cyber_grind.{mp3,ogg,wav}`.

La musique est gérée par l'autoload `Sound` : `main_menu.gd` appelle
`play_menu_music()`, `city.gd` appelle `play_game_music()`. Le changement de
piste se fait avec un fondu d'environ 0,8 s et la musique est baissée pendant
la pause. Les boutons **MUSIC** / **SOUNDS** du menu pause permettent de couper
chaque catégorie (préférences sauvegardées dans `user://progress.cfg`).

## Effets sonores

Fichiers originaux synthétisés (aucun sample tiers) :

| Fichier | Rôle | Déclenchement |
|---|---|---|
| `sfx/engine_low.wav` | moteur, bas régime | boucle, volume et hauteur pilotés par la vitesse |
| `sfx/engine_high.wav` | moteur, haut régime | boucle, fondu avec la couche basse |
| `sfx/tyre_skid.wav` | crissement de pneus | boucle, volume piloté par le glissement latéral / frein à main |
| `sfx/crash.wav` | impact | one-shot sur collision, amplifié selon la vitesse |

Pour régénérer toutes les pistes originales :

```
python3 tools/generate_sfx.py
python3 tools/generate_menu_music.py
```

Les boucles sont construites à partir de partiels dont la fréquence est un
multiple entier de `1 / durée` : le raccord de fin de boucle est sans clic.
