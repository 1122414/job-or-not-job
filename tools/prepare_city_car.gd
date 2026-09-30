extends "res://tools/prepare_city_bus.gd"

const CAR_OUTPUT := "res://assets/vehicles/city_car"
const AXLES := [-1.38,1.27]

func width_at(z: float) -> float:
	return .9-.13*pow(absf(z)/2.12,5)

func shoulder(z: float) -> float:
	return .99-.14*pow(absf(z)/2.12,4)

func lower_edge(z: float) -> float:
	var low := .115+.18*pow(absf(z)/2.12,8)
	for axle in AXLES:
		if absf(z-axle)<.405:low=maxf(low,.34+sqrt(.405*.405-(z-axle)*(z-axle)))
	return low

func side_point(side: int,z: float,t: float) -> Vector3:
	var bottom := lower_edge(z)
	var width := width_at(z)-.055*pow(2*t-1,4)
	return Vector3(side*width,lerpf(bottom,shoulder(z),t),z)

func side_panel(side: int) -> void:
	for i in range(144):
		var z0 := lerpf(-2.05,2.05,i/144.0);var z1 := lerpf(-2.05,2.05,(i+1)/144.0)
		for j in range(6):
			var points := []
			for pair in [[z0,j/6.0],[z1,j/6.0],[z1,(j+1)/6.0],[z0,(j+1)/6.0]]:
				var z: float=pair[0];var t: float=pair[1]
				var p := side_point(side,z,t)
				var along := side_point(side,z+.0001,t)-side_point(side,z-.0001,t)
				var up := side_point(side,z,t+.0001)-side_point(side,z,t-.0001)
				var normal := up.cross(along).normalized()*side
				points.append([p,normal,Vector2(z,t)])
			for index in ([0,1,2,0,2,3] if side>0 else [0,2,1,0,3,2]):
				var p: Array=points[index];vertex(surface("body","paint"),p[0],p[1],p[2])
		# Wheel opening has real depth; it never covers the tire sidewall.
		quad("body","liner",side_point(side,z0,0),side_point(side,z1,0),Vector3(side*.69,lower_edge(z1),z1),Vector3(side*.69,lower_edge(z0),z0),Vector3.DOWN)
	for axle in AXLES:
		for i in range(40):
			var a := PI*i/40;var b := PI*(i+1)/40
			var points := []
			for item in [[a,.408],[b,.408],[b,.433],[a,.433]]:
				var z: float=axle+cos(item[0])*item[1]
				points.append(Vector3(side*(width_at(z)-.039),.34+sin(item[0])*item[1],z))
			quad("body","paint",points[0],points[1],points[2],points[3],Vector3.RIGHT*side)
		# Closed inner cap and roof prevent seeing through to the opposite wheel.
		for i in range(40):
			var a := PI*i/40;var b := PI*(i+1)/40
			var center := Vector3(side*.70,.34,axle)
			var first := center+Vector3(0,sin(a)*.445,cos(a)*.445)
			var second := center+Vector3(0,sin(b)*.445,cos(b)*.445)
			for p in ([center,second,first] if side>0 else [center,first,second]):vertex(surface("cabin","liner"),p,Vector3.LEFT*side,Vector2(p.z,p.y))
			# Separate outer face: an inward cap alone is culled from the wheel side.
			for p in ([center,first,second] if side>0 else [center,second,first]):vertex(surface("cabin","liner"),p+Vector3.RIGHT*side*.005,Vector3.RIGHT*side,Vector2(p.z,p.y))
			quad("cabin","liner",first,second,second+Vector3.RIGHT*side*.17,first+Vector3.RIGHT*side*.17,Vector3(0,-sin((a+b)*.5),-cos((a+b)*.5)))
		for face in [-1,1]:
			var x := side*(.705 if face>0 else .70)
			quad("cabin","liner",Vector3(x,.13,axle-.445),Vector3(x,.34,axle-.445),Vector3(x,.34,axle+.445),Vector3(x,.13,axle+.445),Vector3.RIGHT*side*face)

func pillar(a: Vector3,b: Vector3,width: float) -> void:
	var up := (b-a).normalized()
	var right := (Vector3.RIGHT-up*Vector3.RIGHT.dot(up)).normalized()
	rounded("body","paint",Vector3(.046,a.distance_to(b),width),(a+b)*.5,.009,Basis(right,up,right.cross(up)))

func end_cap(z: float) -> void:
	for i in range(18):
		var u0 := lerpf(-1,1,i/18.0);var u1 := lerpf(-1,1,(i+1)/18.0)
		var width := width_at(z)-.055
		quad("body","paint",Vector3(u0*width,lower_edge(z),z),Vector3(u0*width,shoulder(z)+.045*(1-u0*u0),z),Vector3(u1*width,shoulder(z)+.045*(1-u1*u1),z),Vector3(u1*width,lower_edge(z),z),Vector3.BACK*signf(z))

func deck(z0: float,z1: float) -> void:
	for i in range(24):
		for j in range(18):
			var points := []
			for pair in [[i,j],[i+1,j],[i+1,j+1],[i,j+1]]:
				var z := lerpf(z0,z1,pair[0]/24.0);var u := lerpf(-1,1,pair[1]/18.0)
				points.append(Vector3(u*(width_at(z)-.055),shoulder(z)+.045*(1-u*u),z))
			quad("body","paint",points[0],points[1],points[2],points[3],Vector3.UP)

func glazing(a: Vector3,b: Vector3,c: Vector3,d: Vector3,normal: Vector3) -> void:
	quad("glass","glass",a,b,c,d,normal)
	for edge in [[a,b],[b,c],[c,d],[d,a]]:tube("body","seal",edge[0],edge[1],.014,10)

func car_seat(at: Vector3) -> void:
	# Hip support follows the existing root (0.13 + seated hip 0.53),
	# with the same clothing clearance used for the community bus seats.
	rounded("cabin","fabric",Vector3(.59,.12,.57),at,.05,Basis.IDENTITY,true)
	rounded("cabin","fabric",Vector3(.59,.62,.12),at+Vector3(0,.38,.29),.05,Basis(Vector3.RIGHT,-.09))
	for x in [-.26,.26]:rounded("cabin","bolster",Vector3(.10,.17,.47),at+Vector3(x,.025,.025),.045)
	for x in [-.10,.10]:tube("cabin","metal",at+Vector3(x,.65,.32),at+Vector3(x,.77,.33),.011)
	rounded("cabin","fabric",Vector3(.32,.20,.12),at+Vector3(0,.78,.33),.055)
	for x in [-.20,.20]:box("cabin","liner",Vector3(.04,.12,.47),at+Vector3(x,-.14,0))

func wheel_mesh() -> void:
	var profile := [[-.115,.235],[-.113,.28],[-.09,.325],[-.06,.34],[.06,.34],[.09,.325],[.113,.28],[.115,.235]]
	for i in range(profile.size()-1):
		for j in range(64):
			var points := []
			for pair in [[i,j],[i+1,j],[i+1,j+1],[i,j+1]]:
				var p: Array=profile[pair[0]];var angle: float=pair[1]*TAU/64
				points.append(Vector3(p[0],sin(angle)*p[1],cos(angle)*p[1]))
			quad("wheel","tire",points[0],points[1],points[2],points[3],Vector3(0,sin((j+.5)*TAU/64),cos((j+.5)*TAU/64)))
	var disc := CylinderMesh.new();disc.top_radius=.21;disc.bottom_radius=.21;disc.height=.18;disc.radial_segments=48
	primitive("wheel","brake_disc",disc,Vector3.ZERO,Basis(Vector3.FORWARD,PI/2))
	for side in [-1,1]:
		var rim := TorusMesh.new();rim.inner_radius=.201;rim.outer_radius=.239;rim.rings=48;rim.ring_segments=10
		primitive("wheel","metal",rim,Vector3(side*.117,0,0),Basis(Vector3.FORWARD,PI/2))
		for i in range(5):
			var angle := TAU*i/5
			box("wheel","metal",Vector3(.035,.053,.173),Vector3(side*.12,sin(angle)*.13,cos(angle)*.13),Basis(Vector3.RIGHT,-angle))
			var bolt := CylinderMesh.new();bolt.top_radius=.011;bolt.bottom_radius=.011;bolt.height=.02;bolt.radial_segments=8
			primitive("wheel","steel",bolt,Vector3(side*.151,sin(angle)*.043,cos(angle)*.043),Basis(Vector3.FORWARD,PI/2))
		var hub := CylinderMesh.new();hub.top_radius=.069;hub.bottom_radius=.069;hub.height=.03;hub.radial_segments=24
		primitive("wheel","metal",hub,Vector3(side*.13,0,0),Basis(Vector3.FORWARD,PI/2))
	for i in range(64):
		var angle := TAU*i/64
		for x in [-.052,0,.052]:
			box("wheel","tread",Vector3(.033,.003,.018),Vector3(x,sin(angle)*.339,cos(angle)*.339),Basis(Vector3.RIGHT,PI/2-angle))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(CAR_OUTPUT)
	material("paint",Color.WHITE,.25,.48);materials.paint.clearcoat_enabled=true;materials.paint.clearcoat=.8;materials.paint.clearcoat_roughness=.22
	material("seal",Color("141b1e"),.75);material("liner",Color("252b2e"),.87)
	material("tire",Color("202528"),.93);material("tread",Color("12191b"),.95)
	material("metal",Color("b4bec4"),.24,.86);material("steel",Color("657177"),.37,.8)
	material("brake_disc",Color("44494b"),.63,.7)
	material("fabric",Color("4f5558"),.96);material("bolster",Color("323b40"),.75)
	material("glass",Color(.37,.50,.55,.17),.1,.1)
	materials.glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;materials.glass.cull_mode=BaseMaterial3D.CULL_DISABLED;materials.glass.disable_receive_shadows=true
	material("headlamp",Color("dce5e8"),.19,.15);material("taillamp",Color("942b26"),.24)
	material("dial",Color("20313b"),.5);material("plate",Color("c9d0c8"),.65)
	for side in [-1,1]:side_panel(side)
	deck(-2.05,-.86);deck(1.07,2.05)
	end_cap(-2.05);end_cap(2.05)
	for z in [-2.03,2.03]:
		rounded("body","paint",Vector3(1.65,.43,.18),Vector3(0,.56,z),.075)
		rounded("body","seal",Vector3(1.4,.07,.10),Vector3(0,.32,z+signf(z)*.07),.032)
		rounded("body","seal",Vector3(.91,.18,.023),Vector3(0,.52,z+signf(z)*.094),.010)
		for i in range(5):box("body","steel",Vector3(.83,.009,.012),Vector3(0,.47+i*.027,z+signf(z)*.107))
		rounded("body","plate",Vector3(.34,.10,.015),Vector3(0,.73,z+signf(z)*.095),.006)
		for x in [-.61,.61]:
			rounded("body","seal",Vector3(.39,.17,.055),Vector3(x,.78,z+signf(z)*.07),.05)
			rounded("headlights" if z<0 else "taillights","headlamp" if z<0 else "taillamp",Vector3(.35,.13,.028),Vector3(x,.78,z+signf(z)*.102),.035)
			for n in [-1,0,1]:box("body","steel",Vector3(.008,.10,.008),Vector3(x+n*.085,.78,z+signf(z)*.12))
	# Roof, pillars and glazing share the same sloped contour.
	rounded("body","paint",Vector3(1.39,.10,1.20),Vector3(0,1.585,.15),.049)
	for side in [-1,1]:
		var a := Vector3(side*.79,1.00,-.85);var b := Vector3(side*.665,1.55,-.43)
		var c := Vector3(side*.665,1.55,.72);var d := Vector3(side*.79,1.00,1.08)
		pillar(a,b,.072);pillar(c,d,.105)
		pillar(b,c,.065);tube("body","paint",a,d,.018,12)
		var bottom := Vector3(side*.79,1.00,.22);var top := Vector3(side*.665,1.55,.22)
		rounded("body","seal",Vector3(.044,.57,.052),(bottom+top)*.5,.009,Basis(Vector3.BACK,side*.22))
		glazing(a,b,top,bottom,Vector3.RIGHT*side);glazing(bottom,top,c,d,Vector3.RIGHT*side)
		# Door outlines remain visible below the real glass opening.
		for z in [-.86,.22,1.08]:
			var bottom_y := maxf(.39,lower_edge(z)+.025)
			for i in range(10):
				var y0 := lerpf(bottom_y,.96,i/10.0);var y1 := lerpf(bottom_y,.96,(i+1)/10.0)
				var t0 := (y0-lower_edge(z))/(shoulder(z)-lower_edge(z));var t1 := (y1-lower_edge(z))/(shoulder(z)-lower_edge(z))
				tube("body","seal",side_point(side,z,t0)+Vector3.RIGHT*side*.003,side_point(side,z,t1)+Vector3.RIGHT*side*.003,.004,6)
		for z in [.07,.91]:
			rounded("body","seal",Vector3(.014,.045,.18),Vector3(side*.873,.875,z),.006)
			rounded("body","metal",Vector3(.025,.021,.137),Vector3(side*.89,.882,z),.009)
		rounded("body","paint",Vector3(.21,.11,.24),Vector3(side*.963,1.065,-.71),.052)
		box("body","metal",Vector3(.145,.067,.01),Vector3(side*.97,1.07,-.58))
		tube("body","seal",Vector3(side*.78,1.04,-.75),Vector3(side*.95,1.055,-.71),.023)
		# Door cards, armrest and sill belong to the interior, not solid glass.
		rounded("cabin","bolster",Vector3(.065,.81,1.68),Vector3(side*.817,.555,.12),.025)
		rounded("cabin","fabric",Vector3(.07,.20,1.23),Vector3(side*.729,.76,.11),.026)
		rounded("cabin","bolster",Vector3(.13,.07,.45),Vector3(side*.70,.77,.17),.024)
	glazing(Vector3(-.79,1,-.85),Vector3(-.665,1.55,-.43),Vector3(.665,1.55,-.43),Vector3(.79,1,-.85),Vector3.FORWARD)
	glazing(Vector3(.79,1,1.08),Vector3(.665,1.55,.72),Vector3(-.665,1.55,.72),Vector3(-.79,1,1.08),Vector3.BACK)
	for x in [-.47,.24]:
		tube("body","seal",Vector3(x,1.012,-.856),Vector3(x+.24,1.022,-.848),.007,8)
	box("cabin","liner",Vector3(1.68,.035,2.03),Vector3(0,.0945,.06))
	for x in [-.43,.43]:car_seat(Vector3(x,.485,.10))
	rounded("cabin","fabric",Vector3(1.34,.12,.43),Vector3(0,.465,.78),.05)
	rounded("cabin","fabric",Vector3(1.34,.49,.12),Vector3(0,.76,.96),.055,Basis(Vector3.RIGHT,-.10))
	for x in [-.44,.44]:rounded("cabin","fabric",Vector3(.27,.18,.13),Vector3(x,1.11,.86),.05)
	rounded("cabin","bolster",Vector3(1.46,.20,.41),Vector3(0,.925,-.62),.085)
	rounded("cabin","liner",Vector3(.23,.27,.69),Vector3(0,.405,-.17),.055)
	tube("cabin","seal",Vector3(0,.54,-.2),Vector3(0,.64,-.23),.019)
	rounded("cabin","bolster",Vector3(.061,.055,.073),Vector3(0,.65,-.23),.025)
	for x in [-.57,-.29]:
		var dial := CylinderMesh.new();dial.top_radius=.067;dial.bottom_radius=.067;dial.height=.014;dial.radial_segments=32
		primitive("cabin","metal",dial,Vector3(x,1.045,-.428),Basis(Vector3.RIGHT,PI/2))
		dial.top_radius=.058;dial.bottom_radius=.058;dial.height=.017
		primitive("cabin","dial",dial,Vector3(x,1.045,-.423),Basis(Vector3.RIGHT,PI/2))
		tube("cabin","plate",Vector3(x,1.045,-.411),Vector3(x-.025,1.075,-.411),.003,6)
	rounded("cabin","seal",Vector3(.23,.13,.025),Vector3(.05,.94,-.405),.010)
	for x in [-.69,.31,.57]:
		for y in [.942,.969,.996]:box("cabin","seal",Vector3(.13,.009,.014),Vector3(x,y,-.411))
	tube("cabin","seal",Vector3(-.43,.50,-.56),Vector3(-.43,1.0,-.25),.048)
	wheel_mesh()
	var files := {}
	for group in batches:
		var imported := ImporterMesh.new();var triangles := 0
		for id in batches[group]:
			var tool: SurfaceTool=batches[group][id];tool.index();var arrays := tool.commit_to_arrays()
			triangles+=arrays[Mesh.ARRAY_INDEX].size()/3;imported.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},materials[id])
		imported.generate_lods(60,20,[]);var mesh := imported.get_mesh()
		if ResourceSaver.save(mesh,CAR_OUTPUT.path_join(group+".res"),ResourceSaver.FLAG_COMPRESS)!=OK:quit(1);return
		files[group+".res"]=FileAccess.get_sha256(CAR_OUTPUT.path_join(group+".res"));costs[group]={"triangles":triangles,"surfaces":mesh.get_surface_count()}
	var sources := {}
	for path in ["tools/prepare_city_car.gd","tools/prepare_city_bus.gd"]:sources[path]=FileAccess.get_sha256("res://"+path)
	var record := {"origin":"Original project compact sedan; no third-party vehicle input","sources":sources,"derived_files":files,"geometry":costs,"wheel_radius_m":.34,"floor_top_m":.112,"driver_root":"unchanged CityCar.SEAT","collision":"unchanged 1.86 x 1.3 x 4.25 m"}
	FileAccess.open(CAR_OUTPUT.path_join("production.json"),FileAccess.WRITE).store_string(JSON.stringify(record,"\t")+"\n")
	print("CITY_CAR_PREPARED ",JSON.stringify(costs));quit()
