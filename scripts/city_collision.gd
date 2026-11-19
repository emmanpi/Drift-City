extends Resource

## Données de collision de la ville low-poly, générées par
## tools/bake_lowpoly_city.gd.
##
## `chunks` contient un ConcavePolygonShape3D par morceau de 60 m (géométrie
## exacte, tous les triangles des objets non-routiers). Les arbres sont
## représentés par une boîte unique partagée, placée en chaque position de
## `tree_positions`.

@export var chunks: Array = []
@export var tree_positions: PackedVector3Array = PackedVector3Array()
@export var tree_box_size: Vector3 = Vector3(1.0, 4.0, 1.0)
