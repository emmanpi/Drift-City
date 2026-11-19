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
3 matériaux, 2 textures, 1 930 objets). Ancienne ville `gm-bigcity` conservée
en secours mais **plus utilisée**.

| Fichier | Rôle |
|---|---|
| `tools/bake_lowpoly_city.gd` | bake : fusion par cellules, décimation des arbres, collision exacte, sol, waypoints, spawn |
| `low-poly-city/city.tscn` | ville prête à l'emploi : **25 cellules de 100 m**, 38 surfaces (≤ 3/cellule), 805 919 triangles |
| `low-poly-city/city_collision.res` | murs : 40 trimesh de 60 m + 319 boîtes d'arbres |
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

Les NPC restent à `y = 0.02` (routes planes) : les poussées verticales dues aux
collisions entre voitures sont annulées après `move_and_slide()`.

## Trafic NPC

- Prefabs dans `npc_cars/` : corps + 4 roues, échelle 0,001 (mètres), centrés au
  sol, longs de 2,8 à 5,8 m, tous alignés sur l'axe Z ; le plat `Cylinder001`
  de 21 688 unités est exclu.
- **Sens avant par modèle** : 6 prefabs ont le nez vers +Z (hatchback, minivan,
  offroad, sedan, suv, wagon), 4 vers −Z. Déduit des feux arrière rouges de la
  texture `Optics`. La table `FRONT` dans `npc_traffic.gd` et `front_sign` dans
  `npc_car.gd` corrigent l'`atan2` / le `+PI` : plus de NPC à l'envers.
- 16 voitures, 10 modèles, vitesse 10–14 m/s (~36–50 km/h), `CharacterBody3D`
  layer/mask 1 (donc collisions avec le joueur, les murs et les autres NPC →
  une collision fait perdre le drift).
- **Graphe orienté** : les 262 points du bake sont reconstitués en 131 segments,
  reliés quand leurs extrémités sont à moins de 12 m (**676 liaisons**). Chaque
  NPC part de l'extrémité où il se trouve vers l'autre bout de son segment, puis
  choisit un segment adjacent au carrefour. Les demi-tours sont écartés
  (`incoming.dot(outgoing) > -0.2`) ainsi que le segment parcouru : plus de
  coupe en diagonale à travers les immeubles. Blocage > 0,7 s → retarget,
  ralentissement progressif à l'approche du carrefour.
- Aucune ombre portée (GPU intégré).

### Résultats des tests

- `spawn_check.gd` : voiture à `(-31.8, −0.056, −9.8)`, **0 collision**, mur à 22 m.
- `wall_test.gd` : accélération + nitro (155 km/h) vers le mur à 22 m →
  arrêt à z = −29,75, **mur bloquant, pas de tunneling**.
- `npc_traffic_check.gd` (7 s de physique) : **16/16 NPC en mouvement**,
  **16/16 bien orientés** (avant aligné sur la vitesse), **16/16 sur route**
  (≤ 3 m), y stable ; 30 à 67 m parcourus en 7 s.
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

## Question en suspens

La nouvelle map contient un port (15 cargos, géométrie sous y = 0). L'utilisateur
n'a pas encore choisi : bordure invisible autour de l'eau ou voiture libre de
rouler dessus (le sol cuit suit la géométrie, donc le comportement dépend des
faces présentes).

## Ancienne map (historique, utile pour comprendre le bug réglé)

- Le sol était un empilement de **6 347 triangles horizontaux tous à y = 1,25**,
  soit 334 000 000 m² pour 9 000 000 m² de ville (**37× recouvrement**) →
  z-fighting permanent : c'était la vraie cause des textures « n'importe quoi ».
- Les UV étaient sains (une tuile / 10,5 m) et le bake atlas fidèle.
- Le passage au gris uni (`gm_bigcity_city_grey.res`) masquait le z-fighting.
- `tools/rebuild_walls.gd` ligne 50 avait un filtre trop restrictif qui jetait
  les pans de mur dont le bas était au-dessus de y = 1,7 → la collision ne
  couvrait que 8 737 triangles sur ~84 000 visuels.
- `gm-bigcity/` (332 Mo) est conservé pour revenir en arrière.

## Fichiers clés inchangés

| Fichier | Rôle |
|---|---|
| `project.godot` | rendu GL Compatibility, MSAA 2, autoloads `Inputs`/`Game`/`Loading`, scène principale `main_menu.tscn` |
| `scripts/car.gd` | physique de drift, caméra orbitale, argent, roues, traces, sol en Y |
| `scripts/main_menu.gd` | menu, aperçu 3D, sélection des 5 voitures |
| `scripts/hud.gd`, `speedometer.gd`, `speedometer_dial.gd` | HUD et compteur à aiguille |
| `scripts/loading.gd` | voile de chargement (autoload) |
| `scenes/car.tscn` | `CharacterBody3D`, layer 2 / mask 1, boîte 1,9 × 1,5 × 4,2 |
| `tools/open_test.tscn` | test de drift sur sol plat |
| `ui/theme.tres` | thème global, police Rajdhani |

## Commandes de test

```
# ville (contrôle rapide des erreurs de chargement)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://scenes/city.tscn

# spawn / murs / trafic / fps
... --headless --path . --script res://tools/spawn_check.gd
... --headless --path . --script res://tools/wall_test.gd
... --headless --path . --script res://tools/npc_traffic_check.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/fps_probe.gd

# drift sur sol plat
DRIFT_SMOKE=1 DRIFT_SMOKE_LONG=1 DRIFT_CAR=aveo \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/open_test.tscn
DRIFT_SMOKE=1 DRIFT_SMOKE_LONG=1 DRIFT_CAR=miata \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/open_test.tscn

# régénérer la ville (≈ 10 s) et les prefabs NPC
... --headless --path . --script res://tools/bake_lowpoly_city.gd
... --headless --path . --script res://tools/bake_npc_cars.gd

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

- `.godot/imported` ≈ 450 Mo (dont l'import du GLB, ~30 Mo).
- `low-poly-city` ≈ 143 Mo (`city.tscn` 49 Mo, collision 20 Mo, GLB source 63 Mo).
- `npc_cars` ≈ 8 Mo (10 prefabs), `generic_passenger_car_pack.glb` ≈ 12 Mo.
- `gm-bigcity` ≈ 332 Mo : ancienne map, inutilisée, conservée pour rollback.
