class_name ComicImpact
extends Node3D

var age := 0.0
var lifetime := .48
var knockout := false
var heavy := false
var burst: MeshInstance3D
var caption: Label3D
var ink: StandardMaterial3D

static func show_hit(parent: Node3D,point: Vector3,ko: bool,strong: bool) -> ComicImpact:
	var effect := ComicImpact.new()
	effect.knockout=ko;effect.heavy=strong
	parent.add_child(effect);effect.global_position=point
	return effect

func _ready() -> void:
	add_to_group("comic_impacts")
	# Effects are presentation only, capped independently of the persistent world.
	var effects := get_tree().get_nodes_in_group("comic_impacts")
	if effects.size()>12: effects[0].queue_free()
	lifetime=.8 if knockout else .48
	var mesh := ImmediateMesh.new()
	ink=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ink.cull_mode=BaseMaterial3D.CULL_DISABLED
	ink.albedo_color=Color("ffbb36") if heavy or knockout else Color("fff1af")
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,ink)
	for i in range(12):
		var angle := float(i)*TAU/12
		var length := (.85 if heavy else .55)*(1.2 if i%2==0 else .8)
		for vertex in [Vector3(cos(angle-.055),sin(angle-.055),0)*.23,Vector3(cos(angle),sin(angle),0)*length,Vector3(cos(angle+.055),sin(angle+.055),0)*.23]: mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	burst=MeshInstance3D.new();burst.mesh=mesh;burst.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(burst)
	caption=Label3D.new();caption.text="KO!" if knockout else "轰！" if heavy else "砰！"
	caption.font_size=100 if knockout else 64;caption.outline_size=22
	caption.pixel_size=.007;caption.modulate=Color("ffda54") if knockout else Color.WHITE
	caption.outline_modulate=Color("302124");caption.no_depth_test=false
	caption.position=Vector3(.12,.4,.025);caption.rotation.z=-.12;add_child(caption)

func _process(delta: float) -> void:
	age+=delta
	if age>=lifetime: queue_free();return
	var camera := get_viewport().get_camera_3d()
	if camera and global_position.distance_to(camera.global_position)>.01: look_at(camera.global_position,Vector3.UP,true)
	var progress := age/lifetime
	var size := lerpf(.55,1.15,ease(minf(1,progress*5),.45))
	burst.scale=Vector3.ONE*size
	var opacity := 1.0-smoothstep(.45,1.0,progress)
	ink.albedo_color.a=opacity;caption.modulate.a=opacity
	caption.position.y=.4+progress*.25
