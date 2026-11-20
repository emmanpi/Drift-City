# JeuDrift — état du projet (19/11/2026)

Projet Godot 4.7.2, `/Users/elie/Documents/JeuDrift`, dépôt git (changements non commités).

## Lancer

```
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

- Rendu : **`gl_compatibility`** obligatoire. En Forward+/Vulkan, la 2D ne s'affiche
  pas sur l'Intel Iris 550 (menu invisible, écran gris) → ne pas y revenir.
- Ombres temps réel désactivées (modèles voiture en `cast_shadow=OFF`, ombre
  plaquée dédiée) ; MSAA 3D = 2.
- `timeout` n'existe pas sur macOS : `cmd & PID=$!; sleep N; kill $PID`.

## Nouvelle ville (en service depuis le 19/11)

Source : `low-poly-city/source/Untitled.glb` (63 Mo, 1 116 376 triangles,
3 matériaux, 2 textures, 1 930 objets). Ancienne ville `gm-bigcity` supprimée
le 20/11/2026 (plus utilisée ni conservée en secours).

| Fichier | Rôle |
|---|---|
| `tools/bake_lowpoly_city.gd` | bake : fusion par cellules, décimation des arbres, collision exacte, sol, waypoints, spawn |
| `low-poly-city/city.tscn` | ville prête à l'emploi : **25 cellules de 100 m**, 38 surfaces (≤ 3/cellule), 805 919 triangles |
| `low-poly-city/city_collision.res` | murs : 30 trimesh de 60 m (cargos exclus) + 319 boîtes d'arbres |
| `low-poly-city/city_ground.res` | sol : 64 morceaux / 26 440 faces horizontales (calque de collision 4) |
| `low-poly-city/city_roads.res` | 262 points de passage (131 segments de route) pour les NPC |
| `scripts/city_collision.gd`, `scripts/city_ground.gd`, `scripts/city_roads.gd` | resources `@export` correspondantes |
| `scripts/city.gd` | instance la scène, les collisions, le HUD, la voiture, les limites et le trafic |
| `generic_passenger_car_pack.glb` | pack source des voitures NPC (11,8 Mo, 10 corps + 40 roues) |
| `tools/bake_npc_cars.gd` | découpe le pack en 10 prefabs `npc_cars/*.tscn` |
| `scripts/npc_traffic.gd`, `scripts/npc_car.gd` | trafic : graphe de routes, 16 NPC, déplacement et évitement |

### Décisions du bake

- **Frustum culling** : un mesh unique de ~1 M triangles était toujours dessiné
  en entier → découpe en 25 cellules de 100 m (38 draw calls max, seulement les
  cellules visibles sont dessinées). Gain mesuré : **32 → ~50 fps** (Iris 550,
  1280×720, fenêtré).
- **Arbres** : clustering de sommets à 0,18 m → 298 327 → 167 133 triangles.
- **Collision exacte par morceaux** : tous les triangles des objets non-routiers
  sont conservés (`backface_collision = true`) ; les arbres ont une boîte
  1 × 4 × 1 m autour du tronc.
- **Normales inversées corrigées** : le GLB exporte 93,7 % de faces dont la
  normale est opposée à l'enroulement du triangle → la ville était éclairée
  « d'en bas ». Les normales sont retournées au bake (`normals[ni] = -normals[ni]`).
  Luminance moyenne des captures : 0,31 → **0,51** en vue aérienne, 0,35 → **0,59**
  au spawn. Les 3 matériaux d'origine (double-sided) sont conservés.
- **Véhicules statiques supprimés** : 310 objets retirés au bake
  (`N_Suv`, `N_Muscle Car`, `N_Simple Car`, `Sport Car`, `School Bus`,
  `Ambulance Car`, `Pick Up`, `Sedan Car`, `Police Car N`, `Hatchback Car`,
  `Especial Car`, `Military Vehicle`, `Truck`, `Classic Car`, `Bus_`) et
  remplacés par des NPC roulants. Les feux (`Traffic`), avions et cargos
  restent en place.
- **Cargos sans collision** : les 15 coques `Container Ship` sont encore
  visibles mais leurs 75 966 triangles de collision ont été retirés
  (`tools/strip_ship_collision.gd`). Le bake les ignore aussi désormais.
- **Eau traversable** : aucun mur invisible au bord de l'eau. La voiture peut
  rouler sur le port ; l'eau la ralentit, la fait couler légèrement puis la
  ramène au **dernier point sur terre** avec un petit message « WORLD LIMIT /
  You've reached the edge of the map. » (3 s). Pas d'écran de mort, et la
  bourse n'est pas touchée. `R` ramène toujours au spawn.
- **Sol cuit** : routes, trottoirs, pelouses et `City Ground` sont ajoutés au
  calque 4 (`collision_layer = 8`, `collision_mask = 0`) uniquement pour les
  raycasts ; hauteurs y ∈ [−0,29 ; 1,37], 83 % des faces à y ≈ 0.
- Map recentrée sur l'origine en X/Z ; emprise 566 × 686 m.
- Spawn : **`(-31.8, 0.02, -9.8)`**, yaw 0, dégagement ≈ 22 m (mur à 22 m devant).
  Limites invisibles : `Rect2(-283, -343, 566, 686)`, hauteur 6 m.

## Physique verticale

`scripts/car.gd` ne force plus `global_position.y = GROUND_Y` :

- `_ground_height_at()` sonde le calque 8 par raycast de `p + 1,5 m` vers
  `p − 3 m` (repli `GROUND_Y = 0,02` hors sol cuit) ;
- `_step_up()` lève la voiture de **0,62 m max** avant le déplacement pour
  monter les trottoirs ;
- `_resolve_ground()` suit la surface ou applique une gravité de **22 m/s²**
  dans les descentes ;
- les traces de dérive suivent maintenant `global_position.y`.

## Braquage

- `scripts/car.gd` : vitesse de cap **`steer_rate` 70–86°/s** (au lieu de
  50–66), **108–132°/s au frein à main** (au lieu de 78–100). Le cap est à
  pleine puissance dès **8 m/s** (au lieu de 12), et les roues visuelles
  tournent jusqu'à ±0,62 rad (au lieu de 0,52).
- `scripts/car_catalog.gd` : Aveo 75/115, Datsun 78/120, S13 82/128,
  Miata 86/132, Skyline 70/108 (les plus sportives tournent le plus).
- `steer_test.gd` : à 119 km/h, **150° de cap en 2 s** en conduite normale,
  **130° au frein à main** (la dérive fait glisser la trajectoire).

Les NPC restent à `y = 0.02` (routes planes) : les poussées verticales dues aux
collisions entre voitures sont annulées après `move_and_slide()`.

## Trafic NPC

- Prefabs dans `npc_cars/` : corps + 4 roues, échelle 0,001 (mètres), centrés au
  sol, longs de 2,8 à 5,8 m, tous alignés sur l'axe Z ; le plat `Cylinder001`
  de 21 688 unités est exclu.
- **Sens avant par modèle** : table `FRONT` dans `npc_traffic.gd` (+1 pour
  compact, hatchback, minivan, offroad, pickup, sedan, sport, suv, wagon ; −1
  pour coupe) et `front_sign` dans `npc_car.gd`. Les modèles ne roulent plus à
  l'envers.
- 16 voitures, 10 modèles, `CharacterBody3D` layer 1 / mask 0 : les contacts
  joueur/NPC et NPC/NPC sont résolus manuellement, sans faire perdre le drift
  par une collision physique parasite.
- **Moteur porté de `mrdoob/slop-newyork`** : graphe de **130 carrefours et
  216 voies orientées** reconstruit depuis les tuiles `Road_*` (grille ~11,4 m),
  courbes de Bézier aux carrefours, modèle de poursuite IDM (vitesse, gap,
  freinage), anticipation de courbure et contacts avec impulsion angulaire.
- **Dégagement** : une voiture bloquée ou trop proche d'un obstacle recule en
  tournant (`reverse_left`) puis reprend sa voie ; pas de marche arrière
  visuelle permanente, pas de téléportation, pas de chevauchement.
- **Nombre configurable** : 16 voitures par défaut, réglable de **0 à 100**
  depuis le menu pause (`set_count()` ajoute/retire des NPC en direct, sans
  recharger la ville). La valeur est sauvegardée avec la partie.
- Aucune ombre portée (GPU intégré).

### Résultats des tests

- `spawn_check.gd` : voiture à `(-31.8, −0.056, −9.8)`, **0 collision**, mur à 22 m.
- `wall_test.gd` : accélération + nitro (155 km/h) vers le mur à 22 m →
  arrêt à z = −29,75, **mur bloquant, pas de tunneling**.
- `npc_traffic_check.gd` (15 s de physique) : **16/16 bien orientés** (avant
  aligné sur la vitesse), **16/16 sur chaussée** (≤ 2,3 m de l'axe),
  **0 chevauchement profond**, 13 à 15/16 en mouvement selon les arrêts aux
  carrefours ; 35 à 130 m parcourus.
- `water_death_test.gd` : depuis la côte est, la voiture avance sans mur ; dans
  le port elle est ramenée au dernier point sur terre (x = 120), le message
  « WORLD LIMIT » s'affiche puis se cache tout seul, et `R` ramène au spawn
  avec la bourse intacte.
- `purchase_test.gd` : sans argent, l'achat est refusé (« You need $6000
  more. ») ; avec 10 000 $, la Datsun est achetée (bourse 4 000 $) puis le
  bouton affiche `START ENGINE`.
- `drift_money_test.gd` : drift sur sol plat → bourse créditée et sauvegardée
  (478 $ sur le dernier essai, avec le braquage augmenté).
- `hud_check.gd` : compteur FPS actif, textes `HANDBRAKE`, nom de voiture et
  bourse affichés, message « WORLD LIMIT » masqué au départ.
- `reflections_test.gd` : par défaut les matériaux NPC sont plats (metallic 0,
  sans textures) ; le bouton du menu pause rétablit les matériaux PBR d'origine
  (metallic 1 + textures) en direct, puis les désactive à nouveau ; le réglage
  est relu au lancement suivant (`reflets=true`).
- `save_read_menu.gd` : après un achat dans une première session, le vrai menu
  recharge `$ 4000`, `Datsun 240Z`, `Owned` et `npc=87` au lancement suivant.
- `pause_menu_test.gd` : `Esc` ouvre le menu (`paused=true`), les boutons
  `RESUME / MAIN MENU / QUIT GAME` sont présents ; `+` passe à 17 voitures,
  les bornes 0 et 100 tiennent (boutons désactivés). Clic sur le nombre +
  saisie `42` → 42 NPC en direct ; `a7b3` → 7, champ vide → valeur conservée.
  `RESUME` rend la main.
- `pause_input_test.gd` : vraie touche `Échap` injectée via `Input` →
  ouverture puis fermeture du menu (correctif : le gestionnaire n'appelait
  que `hide_menu()`, jamais `show_menu()`).
- `pause_typing_test.gd` : focus sur le champ, frappe réelle de `4` puis `2`
  via `Input` → `42` dans le champ, `Entrée` → 42 NPC en direct, `Échap`
  annule la saisie et garde le menu ouvert.
- `fps_probe.gd` : 50,3 fps à l'arrêt, 25,7 fps en roulant avec nitro sur la
  dernière mesure (fenêtré, Iris 550). Le coût par image du trafic n'a pas
  changé (graphe et alignement calculés au chargement) : la baisse est
  vraisemblablement le throttling macOS d'une fenêtre occluse (voir pièges).
- Drift/argent (`open_test.tscn`, Aveo) : 403,7 m → **1 745 $** (multiplicateur x4 à 200 m).
- Roues Miata : les 4 axes sont passés de `(±1,27 ; ±0,11 ; 0)` (inclinaison
  ~5° autour de Z) à `(±1,27 ; 0 ; 0)`. Correction dans `wheel_rig.gd` via le
  drapeau `align` (nœuds de roue GLB uniquement) : une `Basis` correctrice
  ramène l'axe dans le plan X, sans toucher aux roues extraites de surfaces OBJ.
- Captures : `shot_air.png` (luminance 0,51), `shot_spawn.png` (0,59),
  `shot_npc.png` (0,48, 302 teintes) → éclairage correct, NPC rendu, pas d'écran gris.

## Port, eau et garage

- **Port ouvert** : les limites invisibles sont celles de toute la map
  (`Rect2(-283, -343, 566, 686)`). Il n'y a plus de mur au bord de l'eau :
  la voiture entre dans le port librement.
- **Limite du monde** : au-dessus de l'eau (raycast sans sol cuit, ou sol sous
  `y = −0,12`), la voiture ralentit et coule légèrement, puis est remise au
  dernier point sur terre (position + cap mémorisés à chaque frame sur sol)
  après 0,9 s. Un petit bandeau « WORLD LIMIT / You've reached the edge of
  the map. » s'affiche 3 s. Plus de carte « YOU DIED » ; bourse et voitures
  achetées intactes.
- Les 15 cargos restent visuels et sans collision (75 966 triangles retirés) :
  on peut traverser leurs coques sur l'eau.
- **Garage** : seule la Chevrolet Aveo est offerte. Les autres doivent être
  achetées dans le menu (le bouton devient `BUY $prix`) :
  Mazda MX-5 Miata **3 500 $**, Datsun 240Z **6 000 $**,
  Nissan Silvia S13 **9 500 $**, Nissan Skyline GT-R **15 000 $**.
- La bourse, les voitures possédées, la dernière voiture choisie et le nombre
  de NPC sont sauvegardés dans `user://progress.cfg` après chaque achat, drift
  encaissé ou réglage du trafic, et rechargés à chaque lancement (vérifié sur
  deux sessions séparées). Le menu affiche « Progress saved automatically ».
  `DRIFT_SAVE_PATH` permet aux tests d'utiliser un fichier séparé.
- Interface entièrement en anglais (menu, HUD, chargement, contrôles).

## Menu pause

- `Esc` ouvre `scripts/pause_menu.gd` (CanvasLayer `PROCESS_MODE_ALWAYS`,
  `get_tree().paused = true`, souris visible) avec **RESUME**, **MAIN MENU**,
  **QUIT GAME**. `Esc` / `Entrée` reprend aussi la partie.
- Ligne **NPC CARS IN CITY** : boutons `−` / `+`, valeur **0 à 100**, défaut
  **16**. Le signal `npc_count_changed` appelle `Traffic.set_count()` en direct,
  puis `Game.set_npc_count()` écrit `player/npc_count` dans la sauvegarde.
- Le nombre est un `LineEdit` cliquable : clic puis frappe au clavier (chiffres
  seulement), `Entrée` valide, `Échap` annule la saisie. Les valeurs hors plage
  sont ramenées à 0–100 et un champ vide conserve la valeur précédente.
- Boutons désactivés aux bornes ; la ville n'est pas rechargée pour changer le
  trafic.

## Audio (20/11/2026)

- Autoload `Sound` (`scripts/sound.gd`), ajouté après `Game` dans `project.godot`.
  Il possède deux lecteurs de musique et quatre lecteurs d'effets ; il survit
  aux changements de scène.
- **En jeu** : piste fournie par l'utilisateur, actuellement
  `Warriyo - Mortals (TOKYO MACHINE & Boom Kitty Remix).mp3` (NCS) à la racine.
  `Sound._find_game_music()` détecte automatiquement n'importe quel `.mp3`,
  `.ogg` ou `.wav` à la racine ou dans `assets/audio/music/` (hors
  `menu_theme.wav`) : changer de morceau ne demande aucun code. Les `.mp3` de la
  racine sont ignorés par Git, sauf le morceau NCS ci-dessus qui est versionné.
- **Menu** : `assets/audio/music/menu_theme.wav`, boucle originale de 13,7 s
  composée par `tools/generate_menu_music.py` (basse, batterie, arpège, nappe ;
  8 mesures, raccord sans clic).
- `main_menu.gd` appelle `play_menu_music()`, `city.gd` appelle
  `play_game_music()`. Changement avec fondu de 0,8 s ; musique à −18 dB
  pendant la pause (`Sound` est `PROCESS_MODE_ALWAYS`).
- Effets synthétisés par `tools/generate_sfx.py` (Python standard, aucun sample
  tiers) : `engine_low.wav` / `engine_high.wav` (deux couches, hauteur et volume
  pilotés par la vitesse, charge et nitro), `tyre_skid.wav` (volume piloté par
  le glissement latéral et le frein à main), `crash.wav` (one-shot déclenché
  dans `_crash()`, amplifié selon la vitesse avant impact).
- `car.gd` démarre/arrête les boucles à l'entrée/sortie de scène et les met à
  jour chaque frame ; en pause, moteur et crissement sont coupés.
- Menu pause : boutons **MUSIC** et **SOUNDS**, état sauvegardé dans
  `user://progress.cfg` (`music_enabled`, `sfx_enabled`, défaut `true`).
- Voir `assets/audio/README.md` pour les chemins et les commandes de régénération.

## Ancienne map (historique, utile pour comprendre le bug réglé)

- Le sol était un empilement de **6 347 triangles horizontaux tous à y = 1,25**,
  soit 334 000 000 m² pour 9 000 000 m² de ville (**37× recouvrement**) →
  z-fighting permanent : c'était la vraie cause des textures « n'importe quoi ».
- Les UV étaient sains (une tuile / 10,5 m) et le bake atlas fidèle.
- Le passage au gris uni (`gm_bigcity_city_grey.res`) masquait le z-fighting.
- `tools/rebuild_walls.gd` ligne 50 avait un filtre trop restrictif qui jetait
  les pans de mur dont le bas était au-dessus de y = 1,7 → la collision ne
  couvrait que 8 737 triangles sur ~84 000 visuels.
- `gm-bigcity/` (332 Mo), ses outils (`bake_city.gd`, `bake_grey_city.gd`,
  `rebuild_walls.gd`, `wall_check.gd`) et `miata.blend` (200 Mo) ont été
  supprimés le 20/11/2026. Ces outils n'étaient plus utilisés ; le modèle
  `miata.glb`, lui, reste chargé par le jeu.

## Fichiers clés inchangés

| Fichier | Rôle |
|---|---|
| `project.godot` | rendu GL Compatibility, MSAA 2, autoloads `Inputs`/`Game`/`Sound`/`Loading`, scène principale `main_menu.tscn` |
| `scripts/sound.gd`, `assets/audio/README.md` | musiques (jeu/menu), effets moteur/dérive/crash, réglages audio |
| `scripts/car.gd` | physique de drift, caméra orbitale, argent, roues, traces, sol en Y, limite du monde, pilotage des effets |
| `scripts/game_state.gd` | bourse, voitures possédées, nombre de NPC, sauvegarde `user://progress.cfg` |
| `scripts/main_menu.gd` | menu, aperçu 3D, sélection et achat des 5 voitures |
| `scripts/pause_menu.gd` | menu pause : reprendre, menu principal, quitter, réglage NPC 0–100 au clavier |
| `scripts/hud.gd`, `speedometer.gd`, `speedometer_dial.gd` | HUD et compteur à aiguille |
| `scripts/loading.gd` | voile de chargement (autoload) |
| `scenes/car.tscn` | `CharacterBody3D`, layer 2 / mask 1, boîte 1,9 × 1,5 × 4,2 |
| `tools/open_test.tscn` | test de drift sur sol plat |
| `ui/theme.tres` | thème global, police Rajdhani |

## Commandes de test

```
# ville (contrôle rapide des erreurs de chargement)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://scenes/city.tscn

# audio : musiques, fondus, moteur/dérive/crash, pause
... --headless --path . --script res://tools/audio_check.gd
python3 tools/generate_sfx.py
python3 tools/generate_menu_music.py

# spawn / murs / trafic / eau / garage / fps
... --headless --path . --script res://tools/spawn_check.gd
... --headless --path . --script res://tools/wall_test.gd
... --headless --path . --script res://tools/steer_test.gd
... --headless --path . --script res://tools/npc_traffic_check.gd
... --headless --path . --script res://tools/water_death_test.gd
DRIFT_SAVE_PATH=user://test_pause.cfg \
  ... --headless --path . --script res://tools/pause_menu_test.gd
DRIFT_SAVE_PATH=user://test_pause_input.cfg \
  ... --headless --path . --script res://tools/pause_input_test.gd
DRIFT_SAVE_PATH=user://test_typing.cfg \
  ... --headless --path . --script res://tools/pause_typing_test.gd
DRIFT_SAVE_PATH=user://test_progress.cfg \
  ... --headless --path . --script res://tools/purchase_test.gd
DRIFT_SAVE_PATH=user://test_progress.cfg \
  ... --headless --path . --script res://tools/save_read_menu.gd
DRIFT_SAVE_PATH=user://test_drift.cfg \
  ... --headless --path . --script res://tools/drift_money_test.gd
... --headless --path . --script res://tools/hud_check.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/fps_probe.gd

# drift sur sol plat
DRIFT_SMOKE=1 DRIFT_SMOKE_LONG=1 DRIFT_CAR=aveo \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/open_test.tscn
DRIFT_SMOKE=1 DRIFT_SMOKE_LONG=1 DRIFT_CAR=miata \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/open_test.tscn

# régénérer la ville (≈ 10 s) et les prefabs NPC
... --headless --path . --script res://tools/bake_lowpoly_city.gd
... --headless --path . --script res://tools/bake_npc_cars.gd

# retirer les collisions des cargos d'un city_collision.res existant
... --headless --path . --script res://tools/strip_ship_collision.gd

# lumière / sol / captures
... --headless --path . --script res://tools/normals_probe.gd
... --headless --path . --script res://tools/ground_probe.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/shot_city.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/shot_npc.gd
... --headless --path . --script res://tools/shot_stats.gd
```

## Pièges déjà rencontrés

- Une sonde enregistrée à la fois en autoload **et** en scène s'exécute deux
  fois (ville en double, fps divisés, logs dupliqués).
- `await get_tree().process_frame` avant `add_child` sur `root` dans `_ready`
  (sinon « Parent node is busy setting up children »).
- `class_name` d'un nouveau script n'est pas résolu en headless sans rescan de
  `.godot/global_script_class_cache.cfg` → préférer `preload`.
- Limite Godot : 256 surfaces max par mesh.
- Les fps mesurés en fenêtre sont très instables (25 → 145) : macOS throttle une
  fenêtre occluse. Ne pas conclure d'une mesure isolée.
- Dans un script `SceneTree`, `global_transform` n'est pas disponible hors
  arbre : propager la transformée du parent manuellement.
- `ResourceSaver.save()` d'un `Array` échoue : passer par une ressource `@export`.
- Une expression `var x := a.prop if a != null else ...` ne compile pas si `a`
  est typé `Node` : déclarer `var x := ...` puis affecter dans un `if`.
- Accéder à une variable de script depuis un `Node` typé (`car.segment`) ne
  compile pas : utiliser `car.get("segment")` / `car.set("target", ...)` ou
  `manager.call("retarget", self)`.

## Espace disque

- `.godot/imported` : cache régénéré par Godot (474 Mo supprimés le 20/11,
  reimport automatique au prochain lancement).
- `low-poly-city` ≈ 128 Mo (`city.tscn` 49 Mo, collision 20 Mo, GLB source 61 Mo).
- `npc_cars` ≈ 4 Mo (10 prefabs), `generic_passenger_car_pack.glb` ≈ 12 Mo.
- `assets/cars` ≈ 394 Mo après suppression de `miata.blend` (200 Mo) ; les
  modèles utilisés (`miata.glb`, `model.dae` + textures) sont conservés.
- `.git` ≈ 588 Mo : l'historique garde les anciens gros blobs. Une réduction
  réelle du dépôt GitHub demanderait une réécriture de l'historique (non faite).
