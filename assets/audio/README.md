# Audio du jeu

## Musique

| Moment | Piste | Emplacement |
|---|---|---|
| En jeu | `game_theme.wav` — morceau original rapide/industriel (174 BPM, 44 s) | `assets/audio/music/game_theme.wav` |
| Menu principal | `menu_theme.wav` — boucle originale (140 BPM, 13,7 s) | `assets/audio/music/menu_theme.wav` |

Les deux pistes sont **générées dans ce dépôt** par `tools/generate_game_music.py`
et `tools/generate_menu_music.py` : aucun sample ni mélodie provenant d'un
soundtrack existant n'est utilisé. La musique de jeu est énergique et
industrielle (basse saturée, double kick, arpèges dissonants) dans l'esprit des
jeux rythmés rapides, sans reproduction d'un morceau précis.

`Sound._find_game_music()` utilise d'abord `game_theme.wav`, puis, s'il manque,
n'importe quel `.mp3`, `.ogg` ou `.wav` déposé à la racine ou dans
`assets/audio/music/`. Les MP3 à la racine restent ignorés par Git.

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
python3 tools/generate_game_music.py
```

Les boucles sont construites à partir de partiels dont la fréquence est un
multiple entier de `1 / durée` : le raccord de fin de boucle est sans clic.
