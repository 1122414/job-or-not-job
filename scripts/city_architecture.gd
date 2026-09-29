class_name CityArchitecture
extends RefCounted

const ROOT := "res://assets/city_architecture/"
const MODULES := ["centered_large_02","centered_double_02","centered_small_03"]
const GROUND_HEIGHT := 3.2

static func build(streets: CityStreetscape,lot: Dictionary) -> void:
	var at: Vector3=lot.at
	var size: Vector3=lot.size
	var floors := roundi((size.y-GROUND_HEIGHT)/3)
	var height := (size.y-GROUND_HEIGHT)/floors
	var tint: Color={"west":Color("efe8de"),"east":Color("b4cfdf"),"north":Color("d4d8c7")}[lot.id]
	var architecture := Node3D.new()
	architecture.name="Architecture_"+lot.id
	streets.add_child(architecture)
	# Upper rooms are visual depth, not new playable interiors. Keep the original
	# solid upper collision volume while letting the actual windows remain open.
	var body := StaticBody3D.new()
	architecture.add_child(body)
	body.position=at+Vector3(0,(size.y+GROUND_HEIGHT)/2,0)
	Shapes.collider(body,Vector3(size.x,size.y-GROUND_HEIGHT,size.z))
	var count := 0
	for face in range(4):
		var yaw := face*PI/2
		var rotation := Basis(Vector3.UP,yaw)
		var width := size.x if face%2==0 else size.z
		var depth := size.z if face%2==0 else size.x
		var columns := roundi(width/3)
		var spacing := width/columns
		var transforms := [[],[],[]]
		for floor_index in range(floors):
			var bottom := GROUND_HEIGHT+floor_index*height
			for column in range(columns):
				var index := 1 if lot.id=="east" else 0
				if column==0 or column==columns-1:index=2
				var local := Vector3((column-(columns-1)*.5)*spacing,bottom,depth/2)
				var origin := at+rotation*local
				transforms[index].append(Transform3D(rotation*Basis.from_scale(Vector3(spacing/3,height/3,1)),origin))
				# Recessed room surfaces and occasional curtains sit behind real
				# glazing. No opaque building block fills the window apertures.
				var occupied := (column+floor_index*2+face+(1 if lot.id=="east" else 0))%5==1
				streets.box(Vector3(spacing-.08,height-.08,.08),origin+rotation*Vector3(0,height/2,-1.15),"window_lit" if occupied else "curtain",yaw)
				for side in [-1,1]:
					streets.box(Vector3(.08,height,.9),origin+rotation*Vector3(side*spacing/2,height/2,-.75),"stone",yaw)
				if (column+face+floor_index)%3==0 and index!=2:
					for side in [-1,1]:streets.box(Vector3(.35,1.8,.035),origin+rotation*Vector3(side*.88,1.23,-.4),"curtain",yaw)
				count+=1
			streets.box(Vector3(width+.12,.1,.22),at+rotation*Vector3(0,bottom,depth/2+.015),"stone",yaw)
		for variant in range(MODULES.size()):
			if transforms[variant].is_empty():continue
			var batch := MultiMeshInstance3D.new()
			batch.name="Facade_%s_%d_%d"%[lot.id,face,variant]
			batch.multimesh=MultiMesh.new()
			batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
			batch.multimesh.use_colors=true
			batch.multimesh.mesh=load(ROOT+MODULES[variant]+".res")
			batch.multimesh.instance_count=transforms[variant].size()
			for i in range(transforms[variant].size()):
				batch.multimesh.set_instance_transform(i,transforms[variant][i])
				batch.multimesh.set_instance_color(i,tint)
			architecture.add_child(batch)
		streets.box(Vector3(width+.18,.65,.26),at+rotation*Vector3(0,size.y+.3,depth/2),lot.wall,yaw)
		streets.box(Vector3(width+.4,.14,.48),at+rotation*Vector3(0,size.y+.68,depth/2),"stone",yaw)
	for floor_index in range(floors):
		streets.box(Vector3(size.x-.08,.08,size.z-.08),at+Vector3(0,GROUND_HEIGHT+floor_index*height+.04,0),"timber")
	for x in [-size.x/2,size.x/2]:
		for z in [-size.z/2,size.z/2]:
			streets.box(Vector3(.2,size.y-GROUND_HEIGHT,.2),at+Vector3(x,(size.y+GROUND_HEIGHT)/2,z),"stone")
	architecture.set_meta("window_bays",count)
	architecture.set_meta("upper_floor_height",height)
