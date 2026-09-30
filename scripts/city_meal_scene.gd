class_name CityMealScene
extends Node3D

var meals: CityMeals
var foods := {}
var spoons := {}
var ladle: Node3D
var sign: Label3D

func _ready() -> void:
	name="StreetMealScene"
	for table in [[5.1,3.4],[10.85,3.4],[16.0,1.8]]:
		Shapes.solid(self,Vector3(table[1],.09,.8),Vector3(table[0],.99,21.2),Color("957957"))
		for side in [-1,1]:
			Shapes.solid(self,Vector3(.09,.95,.5),Vector3(table[0]+side*(table[1]/2-.2),.475,21.2),Color("405856"))
		var napkins := Shapes.box(self,Vector3(.16,.08,.12),Vector3(table[0],1.07,21.25),Color("e9e4d8"))
		napkins.material_override.roughness=.95
	var pot := bowl(self,.27,.27,Color("6d777b"))
	pot.position=Vector3(10,1.01,14.5)
	for x in [-.32,.32]: Shapes.box(pot,Vector3(.13,.035,.055),Vector3(x,.18,0),Color("3d4446"))
	Shapes.box(self,Vector3(1.1,.025,.4),Vector3(11.1,1.02,14.4),Color("b3baba"))
	Shapes.solid(self,Vector3(.045,1.65,.045),Vector3(12.15,.825,14.65),Color("526660"))
	Shapes.solid(self,Vector3(1.3,.64,.05),Vector3(12.15,1.65,14.65),Color("dfd8bd"))
	sign=Shapes.label(self,"唐可的路边摊\n葱油拌面 ¥8 · 蔬菜汤面 ¥12\n11:30—14:00 / 17:00—20:30",Vector3(12.15,1.65,14.681),26)
	sign.pixel_size=.0018;sign.outline_size=0;sign.visibility_range_end=15
	sign.billboard=BaseMaterial3D.BILLBOARD_DISABLED;sign.double_sided=false;sign.modulate=Color("304d47")
	ladle=spoon(self);ladle.hide()

func bowl(parent: Node3D,radius: float,height: float,color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var surface := SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A continuous outer wall, rounded rim and inner wall keep an open bowl
	# readable from the player's normal camera rather than a solid cylinder.
	var profile := [Vector2(.42,0),Vector2(.65,.10),Vector2(.9,.65),Vector2(1,1),Vector2(.94,1.02),Vector2(.83,.67),Vector2(.56,.2),Vector2(0,.17)]
	for ring in range(profile.size()-1):
		for segment in range(32):
			var vertices := []
			for pair in [[ring,segment],[ring,segment+1],[ring+1,segment],[ring+1,segment+1]]:
				var angle: float=pair[1]*TAU/32.0
				var point: Vector2=profile[pair[0]]
				vertices.append(Vector3(cos(angle)*point.x*radius,point.y*height,sin(angle)*point.x*radius))
			for index in [0,2,1,1,2,3]: surface.add_vertex(vertices[index])
	surface.generate_normals();mesh.mesh=surface.commit();mesh.material_override=Shapes.material(color)
	mesh.material_override.roughness=.35;parent.add_child(mesh)
	return mesh

func sphere(parent: Node3D,pos: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new();var mesh := SphereMesh.new()
	mesh.radius=.5;mesh.height=1;mesh.radial_segments=12;mesh.rings=6
	item.mesh=mesh;item.material_override=Shapes.material(color)
	parent.add_child(item);item.position=pos;item.scale=size
	return item

func food() -> Node3D:
	var result := Node3D.new();add_child(result)
	bowl(result,.15,.095,Color("ece3cf"))
	sphere(result,Vector3(0,.068,0),Vector3(.24,.035,.24),Color("b99453"))
	for i in range(9):
		var noodle := Shapes.box(result,Vector3(.13,.008,.012),Vector3(sin(i*1.7)*.045,.084+(i%3)*.002,cos(i*.9)*.07),Color("d7b874"))
		noodle.rotation.y=i*.6
	for i in range(5):
		var leaf := sphere(result,Vector3(sin(i*2.4)*.08,.098,cos(i*2.4)*.07),Vector3(.06,.012,.025),Color("477443"))
		leaf.rotation.y=i
	return result

func spoon(parent: Node3D) -> Node3D:
	var result := Node3D.new();parent.add_child(result)
	Shapes.box(result,Vector3(.012,.009,.16),Vector3(0,0,.055),Color("b6c3c4"))
	sphere(result,Vector3(0,-.003,-.052),Vector3(.043,.013,.064),Color("c7d0d0"))
	return result

func sync() -> void:
	for id in foods.keys():
		if not meals.orders.has(id):
			foods[id].queue_free();spoons[id].queue_free();foods.erase(id);spoons.erase(id)
	for id in meals.orders:
		if not foods.has(id): foods[id]=food();spoons[id]=spoon(self)
		var actor := meals.person(id)
		if actor: apply(actor)
	var vendor := meals.person(CityMeals.VENDOR)
	apply(vendor)
	meals.points[0].title="路边摊 · 餐已备好" if meals.orders.get("player",{}).get("stage")=="ready" else "路边摊 · 菜单与取餐"

func apply(actor: Node3D) -> void:
	if not is_instance_valid(actor): return
	var id: String="player" if actor==meals.game.player else actor.stable_id
	var human: HumanVisual=actor.visual
	if id==CityMeals.VENDOR:
		var cooking := meals.staffed() and meals.queue.any(func(key):return meals.orders[key].stage=="queued")
		ladle.visible=cooking
		if cooking:
			var seconds := 0.0
			for key in meals.queue:
				if meals.orders[key].stage=="queued": seconds=meals.orders[key].cooked;break
			ladle.global_transform=Transform3D(Basis(Vector3.RIGHT,-.35).scaled(Vector3(1.4,1.4,5)),Vector3(10+sin(seconds*2)*.04,1.28,14.57+cos(seconds*2)*.04))
			var target := Transform3D(human.global_basis*Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP),ladle.to_global(Vector3(0,0,.11)))
			human.contacts.reach("R",target);human.contacts.fingers("R",-.25)
	if not foods.has(id) or not meals.orders.has(id): return
	var order: Dictionary=meals.orders[id]
	var dish: Node3D=foods[id];var utensil: Node3D=spoons[id]
	if order.stage in ["queued","ready"]:
		dish.visible=order.stage=="ready" or order.cooked>0
		dish.global_position=Vector3(8.5+.55*order.slot,1.02,14.42);dish.global_basis=Basis.IDENTITY
		utensil.hide();return
	var holding := meals.safe(actor)
	if actor==meals.game.player: holding=holding and actor.held==null and actor.swing<=0 and not actor.seated and not meals.game.in_vehicle()
	else: holding=holding and meals.game.speaker!=actor
	dish.visible=holding;utensil.visible=holding
	if not holding: return
	dish.global_transform=human.global_transform*Transform3D(Basis.IDENTITY,Vector3(-.055,human.standing_height*.65,-.36))
	var eating: bool=order.stage=="eating" and meals.can_eat(actor,order)
	var phase: float=fposmod(order.eaten,4.0)
	var lift := smoothstep(.8,1.7,phase)*(1.0-smoothstep(2.5,3.4,phase)) if eating else 0.0
	var rest := Vector3(.12,human.standing_height*.65+.095,-.32)
	var mouth := human.to_local(human.face_position())+Vector3(.035,-.075,-.14)
	# At the mouth, the spoon's bowl points back toward the face while its
	# handle and the wrist remain in front. Keeping the resting orientation
	# instead sends the hand behind the head despite mathematically valid IK.
	var spoon_basis := Basis(Quaternion.IDENTITY.slerp(Quaternion(Vector3.UP,PI),lift))*Basis(Vector3.RIGHT,.15*lift)
	utensil.global_transform=human.global_transform*Transform3D(spoon_basis,rest.lerp(mouth,lift))
	var frame := human.global_basis*Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP)
	human.contacts.reach("L",Transform3D(frame,dish.to_global(Vector3(-.055,-.002,.005))))
	human.contacts.reach("R",Transform3D(utensil.global_basis*Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP),utensil.to_global(Vector3(0,0,.08))))
	for side in ["L","R"]: human.contacts.fingers(side,-.2)
