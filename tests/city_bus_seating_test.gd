extends SceneTree

# Compare actual posed skin/clothes with the baked seat triangles. A seated
# flag, hip target or floor-bone assertion alone cannot establish this contact.
var failures := 0
var results := {}
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value:push_error(message);failures+=1

func inspect(human: HumanVisual,seat: Vector3) -> Dictionary:
	var mesh: ArrayMesh=load(CityBusVisual.ROOT+"cabin.res")
	var cushions := [];var backs := []
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s);var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		for t in range(0,indices.size(),3):
			var a := points[indices[t]];var b := points[indices[t+1]];var c := points[indices[t+2]]
			var center := (a+b+c)/3
			if absf(center.x-seat.x)>.35 or absf(center.z-seat.z)>.5:continue
			var normal := (c-a).cross(b-a).normalized()
			if absf(normal.y)>.01 and center.y>.5 and center.y<1.05:cushions.append([a,b,c])
			if absf(normal.z)>.9 and center.y>1.05 and center.y<1.45:backs.append([a,b,c])
	var penetration := 0.0;var support_gap := 1000.0;var vertices := 0
	var worst := Vector3.ZERO
	var worst_mesh := ""
	for body in human.find_children("*","MeshInstance3D",true,false):
		if body.skin==null:continue
		var transforms := []
		for bind in range(body.skin.get_bind_count()):
			var bone: int=human.skeleton.find_bone(body.skin.get_bind_name(bind))
			transforms.append(human.skeleton.global_transform*human.skeleton.get_bone_global_pose(bone)*body.skin.get_bind_pose(bind))
		for s in range(body.mesh.get_surface_count()):
			var arrays: Array=body.mesh.surface_get_arrays(s)
			for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
				var p := Vector3.ZERO
				for slot in range(4):p+=(transforms[arrays[Mesh.ARRAY_BONES][i*4+slot]]*arrays[Mesh.ARRAY_VERTEX][i])*arrays[Mesh.ARRAY_WEIGHTS][i*4+slot]
				vertices+=1
				if absf(p.x-seat.x)>.27:continue
				if p.z>seat.z-.24 and p.z<seat.z+.13 and p.y>.6 and p.y<1.07:
					var low := INF;var high := -INF
					for triangle in cushions:
						var hit: Variant=Geometry3D.segment_intersects_triangle(Vector3(p.x,1.05,p.z),Vector3(p.x,.5,p.z),triangle[0],triangle[1],triangle[2])
						if hit==null:continue
						low=minf(low,hit.y);high=maxf(high,hit.y)
					if low<high and p.y>=low:
						support_gap=minf(support_gap,absf(high-p.y))
						var depth := minf(high-p.y,p.y-low)
						if depth>penetration:penetration=depth;worst=p;worst_mesh=body.name
				if p.y>1.06 and p.y<1.45 and p.z>seat.z-.1 and p.z<seat.z+.45:
					var low := INF;var high := -INF
					for triangle in backs:
						var hit: Variant=Geometry3D.segment_intersects_triangle(Vector3(p.x,p.y,seat.z-.1),Vector3(p.x,p.y,seat.z+.5),triangle[0],triangle[1],triangle[2])
						if hit!=null:low=minf(low,hit.z);high=maxf(high,hit.z)
					if low<high:
						var depth := minf(p.z-low,high-p.z)
						if depth>penetration:penetration=depth;worst=p;worst_mesh=body.name
	return {"vertices":vertices,"seat_triangles":cushions.size()+backs.size(),"penetration_m":penetration,"support_gap_m":support_gap,"worst_point":SaveGame.vector(worst),"worst_mesh":worst_mesh}

func run() -> void:
	for outfit in ["casual","office","office_female"]:
		var human := HumanVisual.new();human.outfit=outfit;root.add_child(human)
		var seat := CityPassengers.SEATS[0]
		human.position=seat+human.seated_offset
		results[outfit]=[]
		for phase in [0.0,.4,2.0,3.8]:
			human.animation.stop();human.animation.play("sit",0)
			human.animation.seek(phase,true);human.animation.advance(0);human.animation.pause()
			var result := inspect(human,seat);result.phase=phase;results[outfit].append(result)
			check(result.vertices>1000 and result.seat_triangles>0,"实测皮肤衣装与实际座椅网格")
			check(result.penetration_m<.015,"座椅不穿透人物超过1.5cm "+outfit+" "+JSON.stringify(result))
			check(result.support_gap_m<.03,"坐姿有实际座面支撑 "+outfit)
		human.queue_free();await process_frame
	print("CITY_BUS_SEATING_TEST failures=",failures," ",JSON.stringify(results));quit(1 if failures else 0)
