extends Resource

## Faces horizontales de la ville (routes, trottoirs, pelouses), générées par
## tools/bake_lowpoly_city.gd. Ce resource est placé sur le calque de collision 4
## et sert uniquement aux raycasts de sol : la voiture peut ainsi monter sur les
## trottoirs sans que ces faces génèrent des murs invisibles.

@export var chunks: Array = []
