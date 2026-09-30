extends SceneTree

# Original seven-metre community bus. Bake material batches offline; the runtime
# never creates this geometry. Dimensions share the existing passenger contract.
const OUTPUT := "res://assets/vehicles/city_bus"
var batches := {}
var materials := {}
var costs := {}

func _initialize() -> void:call_deferred("run")

func material(id: String,color: Color,roughness: float=.6,metal: float=0) -> void:
	var mat := StandardMaterial3D.new();mat.resource_name=id
	mat.albedo_color=color;mat.roughness=roughness;mat.metallic=metal
	materials[id]=mat

func surface(group: String,id: String) -> SurfaceTool:
	if not batches.has(group):batches[group]={}
	if not batches[group].has(id):
		var tool := SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_material(materials[id])
		batches[group][id]=tool
	return batches[group][id]

func vertex(tool: SurfaceTool,p: Vector3,n: Vector3,uv: Vector2) -> void:
	tool.set_normal(n);tool.set_uv(uv);tool.add_vertex(p)

func quad(group: String,id: String,a: Vector3,b: Vector3,c: Vector3,d: Vector3,outward: Vector3=Vector3.ZERO) -> void:
	var tool := surface(group,id)
	# Godot front faces use clockwise winding.
	var normal := (c-a).cross(b-a).normalized()
	if outward!=Vector3.ZERO and normal.dot(outward)<0:
		var swap := b;b=d;d=swap;normal=-normal
	for item in [[a,Vector2(0,0)],[b,Vector2(1,0)],[c,Vector2(1,1)],[a,Vector2(0,0)],[c,Vector2(1,1)],[d,Vector2(0,1)]]:
		vertex(tool,item[0],normal,item[1])

func primitive(group: String,id: String,mesh: PrimitiveMesh,at: Vector3,basis: Basis=Basis.IDENTITY) -> void:
	var arrays := mesh.get_mesh_arrays()
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var tool := surface(group,id)
	var normal_basis := basis.inverse().transposed()
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for offset in range(0,indices.size(),3):
		var a := basis*vertices[indices[offset]];var b := basis*vertices[indices[offset+1]];var c := basis*vertices[indices[offset+2]]
		# Sphere poles from the engine primitive contain zero-area triangles.
		if (b-a).cross(c-a).length()<.0000001:continue
		for corner in range(3):
			var index := indices[offset+corner]
			vertex(tool,at+basis*vertices[index],(normal_basis*normals[index]).normalized(),uv[index])

func box(group: String,id: String,size: Vector3,at: Vector3,basis: Basis=Basis.IDENTITY) -> void:
	var mesh := BoxMesh.new();mesh.size=size;primitive(group,id,mesh,at,basis)

func rounded(group: String,id: String,size: Vector3,at: Vector3,radius: float,basis: Basis=Basis.IDENTITY,waterfall: bool=false) -> void:
	var half := size*.5
	var r := minf(radius,minf(half.x,minf(half.y,half.z))*.95)
	var inner := half-Vector3.ONE*r
	var tool := surface(group,id)
	for axis in range(3):
		var u := (axis+1)%3;var v := (axis+2)%3
		var us := [-half[u],-half[u]+r*.134,-half[u]+r*.5,-inner[u],inner[u],half[u]-r*.5,half[u]-r*.134,half[u]]
		var vs := [-half[v],-half[v]+r*.134,-half[v]+r*.5,-inner[v],inner[v],half[v]-r*.5,half[v]-r*.134,half[v]]
		if waterfall:
			if u==2:us.append_array([-.20,-.16,-.12,-.08]);us.sort()
			if v==2:vs.append_array([-.20,-.16,-.12,-.08]);vs.sort()
		for sign_value in [-1,1]:
			for i in range(us.size()-1):
				for j in range(vs.size()-1):
					var points := []
					for pair in [[i,j],[i+1,j],[i+1,j+1],[i,j+1]]:
						var p := Vector3.ZERO;p[axis]=half[axis]*sign_value;p[u]=us[pair[0]];p[v]=vs[pair[1]]
						var core := p.clamp(-inner,inner)
						var normal := (p-core).normalized()
						var shaped := core+normal*r
						if waterfall:
							var t := clampf((-shaped.z-.08)/.21,0,1)
							shaped.y-=.09*t*t*(3-2*t)
							normal=Vector3(normal.x,normal.y,normal.z-normal.y*.09*6*t*(1-t)/.21).normalized()
						points.append([at+basis*shaped,basis*normal,Vector2(p[u],p[v])])
					for index in ([0,2,1,0,3,2] if sign_value>0 else [0,1,2,0,2,3]):
						var point: Array=points[index];vertex(tool,point[0],point[1],point[2])

func tube(group: String,id: String,a: Vector3,b: Vector3,radius: float,segments: int=16) -> void:
	var mesh := CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius
	mesh.height=a.distance_to(b);mesh.radial_segments=segments;mesh.rings=1
	var direction := (b-a).normalized()
	var x := direction.cross(Vector3.FORWARD if absf(direction.z)<.9 else Vector3.UP).normalized()
	primitive(group,id,mesh,(a+b)*.5,Basis(x,direction,x.cross(direction)))

func arch(group: String,id: String,x0: float,x1: float,z: float,outer: float,inner: float) -> void:
	for i in range(32):
		var a := PI*i/32;var b := PI*(i+1)/32
		var oa := Vector3(0,.43+sin(a)*outer,z+cos(a)*outer)
		var ob := Vector3(0,.43+sin(b)*outer,z+cos(b)*outer)
		var ia := Vector3(0,.43+sin(a)*inner,z+cos(a)*inner)
		var ib := Vector3(0,.43+sin(b)*inner,z+cos(b)*inner)
		var radial := Vector3(0,sin((a+b)*.5),cos((a+b)*.5))
		quad(group,id,oa+Vector3.RIGHT*x0,ob+Vector3.RIGHT*x0,ob+Vector3.RIGHT*x1,oa+Vector3.RIGHT*x1,radial)
		quad(group,id,ia+Vector3.RIGHT*x1,ib+Vector3.RIGHT*x1,ib+Vector3.RIGHT*x0,ia+Vector3.RIGHT*x0,-radial)
		for x in [x0,x1]:quad(group,id,oa+Vector3.RIGHT*x,ia+Vector3.RIGHT*x,ib+Vector3.RIGHT*x,ob+Vector3.RIGHT*x,Vector3.RIGHT*signf(x-(x0+x1)*.5))

func side_lower(side: int) -> void:
	# Follow each wheel opening instead of drawing a solid panel over the tire.
	for i in range(160):
		var z0 := lerpf(-3.28,3.28,i/160.0);var z1 := lerpf(-3.28,3.28,(i+1)/160.0)
		if side<0 and z0> -1.91 and z1< -.77:continue
		var bottom := []
		for z in [z0,z1]:
			var y := .40
			for axle in [-2.4,2.1]:
				if absf(z-axle)<.54:y=maxf(y,.43+sqrt(.54*.54-(z-axle)*(z-axle)))
			bottom.append(y)
		for x in [side*1.21,side*1.26]:
			quad("body","ivory",Vector3(x,bottom[0],z0),Vector3(x,1.25,z0),Vector3(x,1.25,z1),Vector3(x,bottom[1],z1),Vector3.RIGHT*side*(1 if is_equal_approx(absf(x),1.26) else -1))
	for extent in ([[ -3.27,-1.92],[-.76,3.27]] if side<0 else [[-3.27,3.27]]):
		box("body","teal",Vector3(.058,.14,extent[1]-extent[0]),Vector3(side*1.266,1.19,(extent[0]+extent[1])*.5))
		box("body","rubber",Vector3(.065,.055,extent[1]-extent[0]),Vector3(side*1.267,1.31,(extent[0]+extent[1])*.5))
	# Keep rubber outside the cabin cap and below the housing inner radius;
	# coincident surfaces flicker as black triangles in the rider/driver view.
	for axle in [-2.4,2.1]:arch("body","rubber",side*1.06,side*1.29,axle,.525,.485)

func seat(at: Vector3,driver: bool=false) -> void:
	var group := "cabin"
	var upholstery := "driver_fabric" if driver else "fabric"
	rounded(group,"seat_shell",Vector3(.67,.12,.61),at+Vector3(0,.005,.01),.05,Basis.IDENTITY,true)
	rounded(group,upholstery,Vector3(.60,.09,.54),at+Vector3(0,.055,-.01),.04,Basis.IDENTITY,true)
	rounded(group,"seat_shell",Vector3(.66,.80,.13),at+Vector3(0,.49,.335),.055,Basis(Vector3.RIGHT,-.07))
	rounded(group,upholstery,Vector3(.59,.66,.07),at+Vector3(0,.51,.255),.03,Basis(Vector3.RIGHT,-.07))
	tube(group,"steel",Vector3(at.x,.415,at.z+.08),at+Vector3(0,-.07,.08),.045)
	box(group,"rubber",Vector3(.28,.025,.28),Vector3(at.x,.415,at.z+.08))
	# Back-mounted grip remains outside the seated person's shoulders.
	tube(group,"rail",at+Vector3(-.21,.85,.365),at+Vector3(.21,.85,.365),.022)
	for x in [-.21,.21]:tube(group,"steel",at+Vector3(x,.68,.365),at+Vector3(x,.85,.365),.018)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	material("ivory",Color("deded3"),.34,.15);material("teal",Color("215b62"),.3,.3)
	material("rubber",Color("202729"),.84);material("steel",Color("9ba4a8"),.25,.8)
	material("seat_shell",Color("c4c6bb"),.5);material("fabric",Color("345b6a"),.95)
	material("driver_fabric",Color("303a40"),.95);material("rail",Color("e9be52"),.38,.2)
	material("glass",Color(.30,.43,.47,.19),.13,.12)
	materials.glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	materials.glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	materials.glass.disable_receive_shadows=true
	material("white_lamp",Color("e1e7d4"),.25)
	material("red_lamp",Color("a92121"),.25);material("amber_lamp",Color("d08822"),.28)
	for id in ["white_lamp","red_lamp","amber_lamp"]:
		materials[id].emission_enabled=true;materials[id].emission=materials[id].albedo_color;materials[id].emission_energy_multiplier=.8
	# Transparent glass and rounded manufactured panels use separate materials.
	rounded("body","ivory",Vector3(2.52,.20,6.98),Vector3(0,2.84,0),.095)
	rounded("body","teal",Vector3(2.35,.17,5.5),Vector3(0,2.97,.1),.075)
	rounded("body","ivory",Vector3(1.55,.12,1.2),Vector3(0,3.09,.7),.05)
	for z in [.3,.45,.6,.75,.9,1.05]:box("body","rubber",Vector3(1.2,.012,.03),Vector3(0,3.155,z))
	for side in [-1,1]:
		side_lower(side)
		for z in [-3.27,-1.93,-.76,.68,2.0,3.27]:
			rounded("body","teal",Vector3(.095,1.47,.09),Vector3(side*1.218,2.02,z),.025)
		box("body","rubber",Vector3(.08,.055,6.57),Vector3(side*1.22,2.68,0))
		for extent in [[-3.21,-2.00],[-1.86,-.82],[-.70,.62],[.74,1.94],[2.06,3.21]]:
			if side<0 and extent[0]< -1 and extent[1]> -1:continue
			box("body","glass",Vector3(.013,1.26,extent[1]-extent[0]),Vector3(side*1.22,2.0,(extent[0]+extent[1])*.5))
		for z in [-3.1,.25,1.6,3.08]:
			if side<0 and z< -1:continue
			tube("cabin","rail",Vector3(side*.99,.41,z),Vector3(side*.99,2.63,z),.023)
		tube("cabin","rail",Vector3(side*.73,2.53,-1.9),Vector3(side*.73,2.53,3.12),.024)
		for z in [.3,1.65,2.85]:
			tube("cabin","rubber",Vector3(side*.73,2.51,z),Vector3(side*.73,2.24,z),.014)
			var handle := TorusMesh.new();handle.inner_radius=.055;handle.outer_radius=.075;handle.rings=16;handle.ring_segments=8
			primitive("cabin","rail",handle,Vector3(side*.73,2.18,z),Basis(Vector3.RIGHT,PI/2))
	for z in [-3.35,3.35]:
		rounded("body","ivory",Vector3(2.49,.69,.22),Vector3(0,.87,z),.10)
		rounded("body","rubber",Vector3(2.42,.16,.17),Vector3(0,.43,z+signf(z)*.09),.045)
		box("body","teal",Vector3(2.43,.12,.235),Vector3(0,1.18,z))
		for x in [-1.18,1.18]:rounded("body","teal",Vector3(.13,1.47,.13),Vector3(x,2.02,z),.035)
		box("body","rubber",Vector3(2.34,.26,.09),Vector3(0,2.57,z))
		box("body","rubber",Vector3(2.34,.15,.09),Vector3(0,1.28,z))
		box("body","glass",Vector3(2.20,1.14,.015),Vector3(0,1.91,z+signf(z)*.06))
		for x in [-.92,.92]:
			rounded("body","rubber",Vector3(.38,.30,.12),Vector3(x,.9,z+signf(z)*.09),.055)
			for y in [.83,.98]:
				var lamp := SphereMesh.new();lamp.radius=.075;lamp.height=.15;lamp.radial_segments=16;lamp.rings=8
				primitive("body","white_lamp" if z<0 else "red_lamp",lamp,Vector3(x,y,z+signf(z)*.13),Basis.from_scale(Vector3(1,1,.38)))
		box("body","rubber",Vector3(.50,.17,.025),Vector3(0,.73,z+signf(z)*.125))
		for i in range(11):box("body","rubber",Vector3(.74,.015,.022),Vector3(0,1.05-i*.021,z+signf(z)*.125))
	# Front wipers, mirrors and rear maintenance seams establish a manufactured object.
	for x in [-.65,.45]:
		tube("body","rubber",Vector3(x,1.4,-3.432),Vector3(x+.18,2.14,-3.432),.012)
		tube("body","rubber",Vector3(x+.14,1.96,-3.444),Vector3(x+.25,2.45,-3.444),.019)
	for side in [-1,1]:
		tube("body","rubber",Vector3(side*1.18,2.5,-3.2),Vector3(side*1.48,2.5,-3.4),.025)
		rounded("body","rubber",Vector3(.15,.46,.23),Vector3(side*1.48,2.26,-3.38),.06)
		box("body","steel",Vector3(.11,.38,.014),Vector3(side*1.48,2.26,-3.256))
	# Six passenger seats retain the approved roots and cushion support height.
	for x in [-.65,.65]:
		for z in [-.4,1.0,2.4]:seat(Vector3(x,.69,z))
	seat(Vector3(-.65,.69,-2.55),true)
	# Wheel housings stay outboard of the 0.65m-wide seats, enclosing the tires.
	for side in [-1,1]:
		for axle in [-2.4,2.1]:
			arch("cabin","seat_shell",side*.99,side*1.20,axle,.57,.53)
			# The arch strip alone exposes the inner wheel face to seated riders.
			# Close the cabin-facing half-disc, outside the passenger seat width.
			var tool := surface("cabin","seat_shell")
			var center := Vector3(side*.99,.43,axle)
			var normal: Vector3=Vector3.LEFT*side
			for i in range(32):
				var a := PI*i/32;var b := PI*(i+1)/32
				var first := center+Vector3(0,sin(a)*.53,cos(a)*.53)
				var second := center+Vector3(0,sin(b)*.53,cos(b)*.53)
				for p in ([center,second,first] if side>0 else [center,first,second]):vertex(tool,p,normal,Vector2(p.z,p.y))
			box("cabin","seat_shell",Vector3(.025,.03,1.14),center+Vector3(0,-.015,0))
		rounded("cabin","ivory",Vector3(.10,.58,1.0),Vector3(side*1.13,.7,.15),.035)
	rounded("cabin","driver_fabric",Vector3(2.22,.22,.49),Vector3(0,1.13,-3.08),.08)
	rounded("cabin","rubber",Vector3(.57,.16,.27),Vector3(-.65,1.27,-3.02),.035)
	for x in [-.78,-.52]:
		var dial := CylinderMesh.new();dial.top_radius=.067;dial.bottom_radius=.067;dial.height=.018;dial.radial_segments=24
		primitive("cabin","white_lamp",dial,Vector3(x,1.30,-2.89),Basis(Vector3.RIGHT,PI/2))
	tube("cabin","rubber",Vector3(-.65,.65,-3.05),Vector3(-.65,1.27,-2.82),.055)
	# Partition behind the driver leaves a front vestibule beside the entrance.
	rounded("cabin","seat_shell",Vector3(.78,.7,.08),Vector3(-.65,.83,-2.15),.035)
	box("cabin","glass",Vector3(.75,.95,.014),Vector3(-.65,1.65,-2.15))
	tube("cabin","rail",Vector3(-.22,.42,-2.15),Vector3(-.22,2.52,-2.15),.026)
	for z in [-2.45,.1,2.65]:
		rounded("cabin","white_lamp",Vector3(.62,.025,.14),Vector3(0,2.725,z),.012)
	for side in [-1,1]:box("cabin","rail",Vector3(.045,.008,6.65),Vector3(side*.31,.408,0))
	# Left-side sliding plug doors serve the existing island platforms. Local
	# origin is the centre of each leaf; runtime opens outwards then slides apart.
	for part in ["door_front","door_rear"]:
		for z in [-.253,.253]:rounded(part,"teal",Vector3(.068,2.19,.055),Vector3(0,0,z),.018)
		for y in [-1.075,1.075]:box(part,"teal",Vector3(.068,.07,.51),Vector3(0,y,0))
		box(part,"glass",Vector3(.018,2.04,.455),Vector3(0,0,0))
		box(part,"rail",Vector3(.023,.035,.46),Vector3(-.041,-.58,0))
		tube(part,"rail",Vector3(.08,-.3,0),Vector3(.08,.35,0),.018)
	# Detailed reusable wheel, with axle on local X and tread radius 0.43m.
	for id in ["tire","hub"]:
		var cylinder := CylinderMesh.new();cylinder.top_radius=.43 if id=="tire" else .255
		cylinder.bottom_radius=cylinder.top_radius;cylinder.height=.24 if id=="tire" else .255
		cylinder.radial_segments=48;cylinder.rings=1
		primitive("wheel","rubber" if id=="tire" else "steel",cylinder,Vector3.ZERO,Basis(Vector3.FORWARD,PI/2))
	for side in [-1,1]:
		for i in range(8):
			var angle := TAU*i/8
			var cap := CylinderMesh.new();cap.top_radius=.025;cap.bottom_radius=.025;cap.height=.014;cap.radial_segments=8
			primitive("wheel","rubber",cap,Vector3(side*.136,sin(angle)*.16,cos(angle)*.16),Basis(Vector3.FORWARD,PI/2))
		var hub := SphereMesh.new();hub.radius=.10;hub.height=.2;hub.radial_segments=16;hub.rings=8
		primitive("wheel","steel",hub,Vector3(side*.14,0,0),Basis.from_scale(Vector3(.4,1,1)))
	for i in range(48):
		var angle := TAU*i/48
		box("wheel","rubber",Vector3(.19,.009,.015),Vector3(0,sin(angle)*.428,cos(angle)*.428),Basis(Vector3.RIGHT,-angle))
	var files := {}
	for group in batches:
		var imported := ImporterMesh.new();var triangles := 0
		for id in batches[group]:
			var tool: SurfaceTool=batches[group][id];tool.index()
			var arrays := tool.commit_to_arrays()
			triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
			imported.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},materials[id])
		imported.generate_lods(60,20,[])
		var mesh := imported.get_mesh()
		if ResourceSaver.save(mesh,OUTPUT.path_join(group+".res"),ResourceSaver.FLAG_COMPRESS)!=OK:quit(1);return
		files[group+".res"]=FileAccess.get_sha256(OUTPUT.path_join(group+".res"))
		costs[group]={"triangles":triangles,"surfaces":mesh.get_surface_count()}
	var record := {"origin":"Original project geometry; no third-party vehicle input","source":"tools/prepare_city_bus.gd","source_sha256":FileAccess.get_sha256("res://tools/prepare_city_bus.gd"),"derived_files":files,"geometry":costs,"floor_top_m":.4,"wheel_radius_m":.43,"passenger_roots":"unchanged CityPassengers.SEATS and player seat","collision":"unchanged 2.6 x 2.8 x 7 m"}
	FileAccess.open(OUTPUT.path_join("production.json"),FileAccess.WRITE).store_string(JSON.stringify(record,"\t")+"\n")
	print("CITY_BUS_PREPARED ",JSON.stringify(costs));quit()
