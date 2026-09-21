class_name OfficeNPC
extends CharacterBody3D

var stable_id := ""
var title := ""
var company := "a"
var role := ""
var home := Vector3.ZERO
var mood := "平静"
var affinity := 0
var down := 0.0
var last_hit := -1
var game: Node3D
var visual: HumanVisual
var label: Label3D
var route := PackedVector3Array()
var route_clock := 0.0
var reaction := 0.0
var hostile := 0.0
var attack_cooldown := 0.0

func setup(id: String, display: String, pos: Vector3, firm: String, job: String, owner_game: Node3D) -> void:
	stable_id = id
	title = display
	position = pos
	home = pos
	company = firm
	role = job
	game = owner_game

func _ready() -> void:
	Shapes.collider(self, Vector3(0.65,1.8,0.65), Vector3(0,0.9,0))
	visual = HumanVisual.new()
	visual.outfit="office" if role in ["boss","hr","group","guard"] else "casual"
	if stable_id in ["a_hr","a_group"]: visual.outfit="office_female"
	add_child(visual)
	label = Shapes.label(self, title, Vector3(0,2.05,0), 28)
	label.pixel_size=0.0035

func hit(direction: Vector3, strength: float, action: int) -> void:
	if action == last_hit: return
	last_hit = action
	down = 2.7
	velocity = direction * strength * 3.0 + Vector3.UP * 2.0
	mood = "生气：别碰我！"
	affinity = maxi(-100, affinity - 18)
	hostile = 12.0
	game.on_aggression(self, action)

func _physics_process(delta: float) -> void:
	reaction = maxf(0,reaction-delta)
	attack_cooldown = maxf(0, attack_cooldown - delta)
	hostile = maxf(0, hostile - delta)
	var distance := global_position.distance_to(game.player.global_position)
	label.visible = distance < 5.0
	var bar := ""
	for i in range(10): bar += "■" if i < (affinity + 100) / 20 else "□"
	label.text = "%s\n%s\n%s\n%s" % [title, "倒地 · 稍后恢复" if down > 0 else mood, bar, game.relationship(self)]
	if not is_on_floor(): velocity.y -= 20 * delta
	if down > 0:
		down -= delta
		visual.rotation.z = lerpf(visual.rotation.z, 1.4, delta * 12)
		velocity.x = move_toward(velocity.x,0,delta * 4)
		velocity.z = move_toward(velocity.z,0,delta * 4)
	else:
		visual.rotation.z = lerpf(visual.rotation.z, 0, delta * 10)
		var target := home
		if game.payroll.after_work() and stable_id in ["a_friend","a_group","b_friend"]:
			target={"a_friend":Vector3(-8,0,12),"a_group":Vector3(-4,0,12),"b_friend":Vector3(8,0,12)}[stable_id]
		if stable_id=="b_friend" and (not game.payroll.after_work() or game.career.b_event=="negotiating"):
			match game.career.b_event:
				"refused", "helping": target=Vector3(21,0,-4)
				"negotiating": target=game.player.position+Vector3(1.5,0,0)
				"helped", "negotiated", "conflict": target=Vector3(14,0,4)
		if hostile > 0 and game.player.protection <= 0 and distance < 9 and game.can_see(self, game.player):
			target = game.player.global_position
			if distance < 1.6 and attack_cooldown == 0:
				game.player.hurt(18)
				attack_cooldown = 1.0
		if reaction>0: target = global_position + (global_position-game.player.global_position).normalized()*2
		route_clock-=delta
		if route_clock<=0:
			route=game.walking.route(global_position,target)
			route_clock=0.8
		while not route.is_empty() and Vector2(route[0].x-position.x,route[0].z-position.z).length()<0.5: route.remove_at(0)
		var next := target if route.is_empty() else route[0]
		var direction := next - global_position
		direction.y = 0
		if direction.length() > 0.35:
			direction = direction.normalized()
			velocity.x = direction.x * 2.3
			velocity.z = direction.z * 2.3
		else:
			velocity.x = 0
			velocity.z = 0
	if down<=0 and Vector2(velocity.x,velocity.z).length()>0.3:
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-velocity.x,-velocity.z),delta*8)
	elif down<=0:
		var facing: Vector3 = game.player.global_position-global_position if distance<5 else Vector3(0,0,1)
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-facing.x,-facing.z),delta*4)
	visual.pose(Vector2(velocity.x,velocity.z).length(),attack_cooldown>0.7,down>0)
	move_and_slide()
	if position.y < -6: position = home
