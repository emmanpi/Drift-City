extends Resource

## Points de passage sur les routes, générés par tools/bake_lowpoly_city.gd.
## Utilisés par les voitures NPC pour choisir leurs destinations.

@export var points: PackedVector3Array = PackedVector3Array()
