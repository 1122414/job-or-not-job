class_name CityFootRoutes
extends RefCounted

# Connect the detailed office grid to the public walking graph. The latter stays
# sparse: extending the city must not multiply the office's half-metre grid.
const PORTAL := Vector3(0,0,18)

static func in_office(point: Vector3) -> bool:
	return absf(point.x)<=35 and point.z>=-21 and point.z<=18

static func route(walking: WalkingGrid,from: Vector3,to: Vector3,seat: CollisionObject3D,actor: Node3D) -> PackedVector3Array:
	var start := PORTAL if in_office(from) else Vector3(from.x,0,from.z)
	var end := PORTAL if in_office(to) else Vector3(to.x,0,to.z)
	var result := PackedVector3Array()
	if in_office(from):
		result=walking.route(from,PORTAL,seat,actor)
		if result.is_empty(): return result
	var outside := public_route(walking,start,end)
	if outside.is_empty(): return PackedVector3Array()
	result.append_array(outside)
	if in_office(to):
		var inside := walking.route(PORTAL,to,seat,actor)
		if inside.is_empty(): return PackedVector3Array()
		result.append_array(inside)
	return result

static func anchor(walking: WalkingGrid,point: Vector3) -> Dictionary:
	var best := INF
	var selected := {}
	var population: CityPopulation=walking.world.population
	for link in CityPopulation.LINKS:
		var a: Vector3=CityPopulation.POINTS[link[0]]
		var b: Vector3=CityPopulation.POINTS[link[1]]
		var projection := Geometry3D.get_closest_point_to_segment(point,a,b)
		var distance := point.distance_to(projection)
		if distance>=best or not walking.clear_segment(point,projection): continue
		best=distance
		selected={"point":projection,"ends":link,"graph":population.graph}
	return selected

static func public_route(walking: WalkingGrid,from: Vector3,to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	var start := anchor(walking,from)
	var end := anchor(walking,to)
	if start.is_empty() or end.is_empty(): return result
	var population: CityPopulation=walking.world.population
	var best := INF
	# Collinear main paths and their subdivided links overlap. A rounding change
	# in the nearest link must not send somebody back to the previous junction.
	if (start.ends==end.ends or on_link(start.point,end.ends) or on_link(end.point,start.ends)) and walking.clear_segment(start.point,end.point):
		result=PackedVector3Array([start.point,end.point,to])
		best=from.distance_to(start.point)+start.point.distance_to(end.point)+end.point.distance_to(to)
	for a in start.ends:
		for b in end.ends:
			var ids := population.graph.get_id_path(population.point_ids.find(a),population.point_ids.find(b))
			if ids.is_empty(): continue
			var candidate := PackedVector3Array([start.point])
			for id in ids: candidate.append(CityPopulation.POINTS[population.point_ids[id]])
			candidate.append(end.point); candidate.append(to)
			var cost := from.distance_to(candidate[0])
			for i in range(1,candidate.size()): cost+=candidate[i-1].distance_to(candidate[i])
			if cost<best:
				best=cost; result=candidate
	# A nearby projection is an entry aid, not a mandatory stop. Returning to it
	# at every replan can trap an actor orbiting somebody standing on the path.
	if result.size()>1 and from.distance_to(result[0])<1.4 and walking.clear_segment(from,result[1]):
		result.remove_at(0)
	return result

static func on_link(point: Vector3,ends: Array) -> bool:
	return Geometry3D.get_closest_point_to_segment(point,CityPopulation.POINTS[ends[0]],CityPopulation.POINTS[ends[1]]).distance_to(point)<.01

static func crossing_at(point: Vector3) -> String:
	for id in CityPopulation.CROSSINGS:
		var ends: Array=CityPopulation.CROSSINGS[id]
		var a: Vector3=CityPopulation.POINTS[ends[0]]
		var b: Vector3=CityPopulation.POINTS[ends[1]]
		var axis := (b-a).normalized()
		var along := (point-a).dot(axis)
		var sideways := Vector3(point.x,0,point.z)-(a+axis*along)
		if along>.1 and along<a.distance_to(b)-.1 and sideways.length()<2: return id
	return ""

static func request(from: Vector3,to: Vector3) -> String:
	if crossing_at(from)!="": return ""
	for id in CityPopulation.CROSSINGS:
		var ends: Array=CityPopulation.CROSSINGS[id]
		for i in range(2):
			var edge: Vector3=CityPopulation.POINTS[ends[i]]
			var across: Vector3=CityPopulation.POINTS[ends[1-i]]
			if Vector2(from.x-edge.x,from.z-edge.z).length()<1 and (to-edge).dot((across-edge).normalized())>1: return id
	return ""
