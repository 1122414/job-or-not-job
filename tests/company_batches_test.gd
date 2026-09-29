extends SceneTree

const Batches = preload("res://tools/company_static_batches.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1

func fixture_box(parent: Node3D,at: Vector3,material: Material) -> MeshInstance3D:
	var node := Shapes.box(parent,Vector3(.3,.2,.1),at,Color.WHITE)
	node.material_override=material
	return node

func run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	for title in Batches.GROUPS:
		var group := Node3D.new()
		group.name=title
		fixture.add_child(group)
	var group := fixture.get_node("Architecture") as Node3D
	var material := Shapes.material(Color.WHITE)
	var first := fixture_box(group,Vector3(1,1,1),material)
	var second := fixture_box(group,Vector3(2,1,1),material)
	second.rotation.y=.4
	var far := fixture_box(group,Vector3(10,1,1),material)
	var glass := material.duplicate() as StandardMaterial3D
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var transparent := fixture_box(group,Vector3(1,1,2),glass)
	var local_texture := OfficeDress.fabric(Color.WHITE)
	var local_mapped := fixture_box(group,Vector3(1,1,3),local_texture)
	var hidden := fixture_box(group,Vector3(1,2,1),material)
	hidden.visible=false
	var moving := Node3D.new()
	moving.name="InterviewPhoneA"
	fixture.add_child(moving)
	var phone := fixture_box(moving,Vector3(1,1,1),material)
	var phone2 := fixture_box(moving,Vector3(2,1,1),material)
	var solid := Shapes.solid(group,Vector3(.3,.2,.1),Vector3(1,1,1),Color.WHITE)
	solid.get_child(0).material_override=material
	var collision: CollisionShape3D=solid.get_child(1)
	var collision_transform := collision.global_transform
	var vertices: Array[Vector3]=[]
	for node in [first,second,solid.get_child(0)]:
		for vertex in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: vertices.append(node.global_transform*vertex)
	var result := Batches.bake(fixture)
	check(result.source_meshes==3 and result.batches==1,"Nearby opaque geometry shares one batch; distant geometry stays independently culled")
	check(result.source_triangles==36 and result.batch_triangles==36,"Static batching retains every source triangle")
	check(is_instance_valid(collision) and collision.global_transform==collision_transform,"Batching preserves physical support shapes and transforms")
	for node in [far,transparent,local_mapped,hidden,phone,phone2]: check(is_instance_valid(node),"Distant, transparent, object-mapped, hidden and interactive geometry stays intact")
	check(not hidden.visible and moving.get_child_count()==2,"Hidden and movable subtree states are preserved")
	var batch: MeshInstance3D=group.get_node("StaticBatch0")
	check(batch.material_override==material,"No copied or simplified material replaces the authored material")
	var actual: PackedVector3Array=batch.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		var closest := INF
		for candidate in actual: closest=minf(closest,vertex.distance_to(batch.global_transform*candidate))
		check(closest<0.00001,"Rotated source vertex retains its exact location")
	var repeat := Batches.bake(fixture)
	check(repeat==result,"Rebaking preserves existing batches and their provenance without duplicating geometry")
	fixture.free()
	for firm in ["a","b"]:
		var company: Node3D=load("res://scenes/companies/company_"+firm+".tscn").instantiate()
		root.add_child(company)
		var report: Dictionary=company.get_meta("static_batch_report",{})
		check(not report.is_empty() and report.get("source_triangles",-1)==report.get("batch_triangles",-2),"Shipping company records a lossless bake")
		var count := 0
		var triangles := 0
		for node in company.find_children("*","MeshInstance3D",true,false):
			if not node.has_meta("source_paths"): continue
			count+=1
			var actual_triangles: int=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3
			triangles+=actual_triangles
			check(actual_triangles==node.get_meta("source_triangles"),"Serialized batch contains its declared triangles")
		check(count==report.get("batches",-1) and triangles==report.get("source_triangles",-1),"Shipping geometry matches bake counts")
		var resting_phone: Node3D=company.get_node("InterviewPhone"+firm.to_upper())
		check(absf(resting_phone.position.z+14.54)<0.00001 and resting_phone.get_child(0).rotation.is_zero_approx(),"Rebuilt source preserves S4 accepted phone rest pose")
		company.free()
	await process_frame
	print("COMPANY_BATCHES_TEST failures=",failures)
	quit(failures)
