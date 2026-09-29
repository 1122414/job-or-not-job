class_name WalkingGrid
extends RefCounted

var grid := AStarGrid2D.new()
var built := false
var world: Node3D
var excluded: Array[RID] = []

func build(game: Node3D) -> void:
	world=game
	grid.region=Rect2i(-70,-42,141,87)
	grid.cell_size=Vector2(0.5,0.5)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	excluded = [game.player.get_rid(),game.transit.bus.get_rid()]
	for car in game.driving.cars: excluded.append(car.get_rid())
	for npc in game.npcs: excluded.append(npc.get_rid())
	for prop in game.props:
		if prop.portable(): excluded.append(prop.get_rid())
	var shape := BoxShape3D.new()
	shape.size=Vector3(0.6,1.5,0.6)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.collision_mask=3
	query.exclude=excluded
	for x in range(-70,71):
		for z in range(-42,45):
			query.transform.origin=Vector3(x*0.5,1,z*0.5)
			grid.set_point_solid(Vector2i(x,z),not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty())
	built=true

func cell(pos: Vector3) -> Vector2i:
	var c := Vector2i(clampi(roundi(pos.x*2),-70,70),clampi(roundi(pos.z*2),-42,44))
	if not grid.is_point_solid(c): return c
	for radius in range(1,5):
		for dx in range(-radius,radius+1):
			for dz in range(-radius,radius+1):
				var other := c+Vector2i(dx,dz)
				if grid.is_in_boundsv(other) and not grid.is_point_solid(other): return other
	return c

func route(from: Vector3, to: Vector3, seat: CollisionObject3D = null, actor: Node3D = null) -> PackedVector3Array:
	var points := PackedVector3Array()
	if not built: return points
	var occupied := {}
	if actor:
		for person in world.npcs+[world.player]:
			if person==actor or person.position.distance_to(to)<0.9: continue
			var center := Vector2i(roundi(person.position.x*2),roundi(person.position.z*2))
			for dx in range(-1,2):
				for dz in range(-1,2):
					var point := center+Vector2i(dx,dz)
					if Vector2(point.x*0.5-person.position.x,point.y*0.5-person.position.z).length()>0.60: continue
					if grid.is_in_boundsv(point) and not occupied.has(point):
						occupied[point]=grid.is_point_solid(point)
						grid.set_point_solid(point,true)
	for p in grid.get_id_path(cell(from),cell(to)):
		points.append(Vector3(p.x*0.5,0,p.y*0.5))
	for point in occupied: grid.set_point_solid(point,occupied[point])
	if not points.is_empty() and clear_segment(points[-1],to,seat,actor): points.append(Vector3(to.x,0,to.z))
	return points

func clear_segment(from: Vector3,to: Vector3,seat: CollisionObject3D = null,actor: Node3D = null) -> bool:
	if not built or not is_instance_valid(world): return false
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius=0.28
	shape.height=1.7
	query.shape=shape
	query.collision_mask=3
	query.exclude=excluded
	if actor:
		var dynamic_exceptions: Array[RID]=[actor.get_rid()]
		for prop in world.props:
			if prop.portable(): dynamic_exceptions.append(prop.get_rid())
		query.exclude=dynamic_exceptions
	if seat:
		var exceptions := query.exclude
		exceptions.append(seat.get_rid())
		query.exclude=exceptions
	query.transform.origin=Vector3(from.x,0.9,from.z)
	query.motion=Vector3(to.x-from.x,0,to.z-from.z)
	var result := world.get_world_3d().direct_space_state.cast_motion(query)
	return result.size()==2 and result[0]>0.99
