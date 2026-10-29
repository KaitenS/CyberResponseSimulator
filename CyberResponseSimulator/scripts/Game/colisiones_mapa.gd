extends Node
## Agrega colisiones automaticas a las mallas del mapa al iniciar la escena.
## En tu Game.tscn: nodo hijo de Game, y "Raiz Mapa" = Floor/Office.

@export var raiz_mapa: NodePath
## Mallas cuyo nombre contenga alguno de estos textos NO tendran colision.
@export var excluir_nombres: PackedStringArray = ["Luz", "Light", "Cable", "Decal", "Techo"]
## Nombres EXACTOS de mallas a excluir (ej: "Cube_040"). Util para quitar lo que estorba.
@export var excluir_exactos: PackedStringArray = []
## Mallas mas chicas que esto (en metros, su lado mayor) se ignoran: evita trabarse con objetos pequenos.
@export var tamano_minimo: float = 0.3
## Capa de fisica donde quedan las colisiones (debe estar en la Mask del jugador).
@export_range(1, 32) var capa: int = 1
## Imprime en la consola cada malla con colision (para saber cual es cual).
@export var depurar: bool = true

var _creadas := 0


func _ready() -> void:
	var raiz: Node = get_node_or_null(raiz_mapa) if not raiz_mapa.is_empty() else get_parent()
	if raiz == null:
		push_warning("colisiones_mapa: no se encontro raiz_mapa")
		return
	_recorrer(raiz, true)
	if depurar:
		print("colisiones_mapa: %d colisiones creadas en '%s'" % [_creadas, raiz.name])


func _recorrer(nodo: Node, es_raiz: bool = false) -> void:
	# No tocar al jugador ni cuerpos con fisica propia (la raiz si se recorre aunque sea un cuerpo).
	if not es_raiz and (nodo is CharacterBody3D or nodo is RigidBody3D or nodo is StaticBody3D or nodo is Area3D):
		return
	if nodo is MeshInstance3D:
		_colisionar(nodo)
	for hijo in nodo.get_children():
		_recorrer(hijo)


func _colisionar(malla: MeshInstance3D) -> void:
	if malla.mesh == null or not malla.visible:
		return
	if String(malla.name) in excluir_exactos:
		return
	for t in excluir_nombres:
		if String(malla.name).containsn(t):
			return
	var caja: AABB = malla.get_aabb()
	var tam: Vector3 = caja.size * malla.global_transform.basis.get_scale().abs()
	if maxf(tam.x, maxf(tam.y, tam.z)) < tamano_minimo:
		return
	for h in malla.get_children():
		if h is StaticBody3D:
			return # ya tiene colision
	malla.create_trimesh_collision()
	for h in malla.get_children():
		if h is StaticBody3D:
			h.collision_layer = 1 << (capa - 1)
			_creadas += 1
			if depurar:
				print("  colision: %s  (%.1f x %.1f x %.1f m)" % [malla.name, tam.x, tam.y, tam.z])
