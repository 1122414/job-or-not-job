class_name WalkingGrid
extends RefCounted

var grid := AStarGrid2D.new()
var built := false

func build(game: Node3D) -> void:
	grid.region=Rect2i(-35,-21,71,44)
	grid.cell_size=Vector2.ONE
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var excluded: Array[RID] = [game.player.get_rid()]
	for npc in game.npcs: excluded.append(npc.get_rid())
	for prop in game.props:
		if prop.portable(): excluded.append(prop.get_rid())
	var shape := BoxShape3D.new()
	shape.size=Vector3(0.85,1.5,0.85)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.exclude=excluded
	for x in range(-35,36):
		for z in range(-21,23):
			query.transform.origin=Vector3(x,1,z)
			grid.set_point_solid(Vector2i(x,z),not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty())
	built=true

func cell(pos: Vector3) -> Vector2i:
	var c := Vector2i(clampi(roundi(pos.x),-35,35),clampi(roundi(pos.z),-21,22))
	if not grid.is_point_solid(c): return c
	for radius in range(1,5):
		for dx in range(-radius,radius+1):
			for dz in range(-radius,radius+1):
				var other := c+Vector2i(dx,dz)
				if grid.is_in_boundsv(other) and not grid.is_point_solid(other): return other
	return c

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array()
	if not built: return points
	for p in grid.get_id_path(cell(from),cell(to)):
		points.append(Vector3(p.x,0,p.y))
	return points
