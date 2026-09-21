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
var visual: Node3D
var label: Label3D
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
	visual = Node3D.new()
	add_child(visual)
	var color := Color("469aab") if company == "a" else Color("d38b53")
	if role == "guard": color = Color("465263")
	Shapes.box(visual, Vector3(0.65,0.85,0.4), Vector3(0,1.1,0), color)
	Shapes.box(visual, Vector3(0.42,0.42,0.42), Vector3(0,1.73,0), Color("f5c7a0"))
	for x in [-0.2,0.2]:
		Shapes.box(visual, Vector3(0.22,0.65,0.3), Vector3(x,0.35,0), Color("29374c"))
	label = Shapes.label(self, title, Vector3(0,2.4,0), 28)

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
		if hostile > 0 and game.player.protection <= 0 and distance < 9 and game.can_see(self, game.player):
			target = game.player.global_position
			if distance < 1.6 and attack_cooldown == 0:
				game.player.hurt(18)
				attack_cooldown = 1.0
		var direction := target - global_position
		direction.y = 0
		if direction.length() > 0.8:
			direction = direction.normalized()
			velocity.x = direction.x * 2.3
			velocity.z = direction.z * 2.3
		else:
			velocity.x = 0
			velocity.z = 0
	move_and_slide()
	if position.y < -6: position = home
