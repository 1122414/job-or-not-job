class_name OfficeNPC
extends CharacterBody3D

var care_state := "awake"
var care_elapsed := 0.0
var return_minute := 0
var rescue_position := Vector3.ZERO
var stable_id := ""
var role_id := ""
var stuck_time := 0.0
var last_position := Vector3.ZERO
var title := ""
var company := "a"
var role := ""
var home := Vector3.ZERO
var mood := "平静"
var affinity := 0
var down := 0.0
var hit_stun := 0.0
var block_time := 0.0
var hit_push := Vector3.ZERO
var fall_side := 1.0
var hp := 100
var dead := false
var last_hit := -1
var game: Node3D
var visual: HumanVisual
var label: Label3D
var route := PackedVector3Array()
var route_clock := 0.0
var street_request := ""
var reaction := 0.0
var hostile := 0.0
var attack_cooldown := 0.0
var seated := false
var visit_wait := 0.0
var body_shape: CollisionShape3D
var body_pose := ""
var seat_body: OfficeProp

func setup(id: String, display: String, pos: Vector3, firm: String, job: String, owner_game: Node3D) -> void:
	stable_id = id
	title = display
	position = pos
	home = pos
	company = firm
	role = job
	game = owner_game

func _ready() -> void:
	collision_mask=3
	body_shape=CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.27
	capsule.height=1.8
	body_shape.shape=capsule
	body_shape.position.y=0.9
	add_child(body_shape)
	visual = HumanVisual.new()
	visual.personality=role
	visual.variation=absi(stable_id.hash())
	visual.outfit="office" if role in ["boss","hr","group","guard"] else "casual"
	if role_id in ["a_hr","a_group"]: visual.outfit="office_female"
	visual.cast_id={"a_hr":"lin_lan","b_hr":"a_cheng"}.get(stable_id,"")
	add_child(visual)
	visual.animation.mixer_applied.connect(func(): game.interviews.update_phone_contact(self))
	visual.animation.mixer_applied.connect(func(): game.handover.contact(self))
	visual.animation.mixer_applied.connect(func():
		if game.meals: game.meals.scene.apply(self))
	if not visual.cast_id.is_empty():
		capsule.height=visual.standing_height
		body_shape.position.y=capsule.height*0.5
	label = Shapes.label(self, title, Vector3(0,2.05,0), 28)
	label.pixel_size=0.0028
	label.outline_size=3

func temperament() -> String:
	if role=="guard": return "protective"
	if role_id in ["a_hr","a_friend","b_hr"]: return "cautious"
	if role_id in ["a_boss","b_boss"]: return "volatile"
	return "restrained"

func available() -> bool:
	return not dead and care_state=="awake" and down<=0

func sync_care() -> void:
	visible=care_state!="away"
	collision_layer=0 if care_state in ["away","carried"] else 1
	collision_mask=0 if care_state in ["away","carried"] else 3

func hit(direction: Vector3, strength: float, action: int, dangerous: bool = true) -> void:
	if dead or care_state in ["away","carried"] or action==last_hit: return
	if not dangerous and (care_state!="awake" or down>0): return
	last_hit=action
	var damage := roundi(strength*24*(0.5 if block_time>0 and not dangerous else 1.0))
	hp=maxi(1,hp-damage)
	dead=hp==0
	var knocked_out := not dead and hp<=1
	if knocked_out:
		care_state="unconscious"
		care_elapsed=0
		rescue_position=Vector3(-14 if company=="a" else 14,0,3)
		game.say(title.split(" · ")[0]+"昏迷 · 已呼叫救助")
	if knocked_out or dangerous and (strength>=1.0 or hp<=30):
		down=2.7
		var right := Vector3.RIGHT.rotated(Vector3.UP,visual.rotation.y)
		fall_side=-1.0 if direction.dot(right)>0 else 1.0
		velocity=direction*minf(strength,1.0)*0.5
	else:
		hit_stun=0.32
		hit_push=direction*0.65
		reaction=0.6
		route_clock=0
	affinity=maxi(-100,affinity-18)
	match temperament():
		"cautious":
			mood="别靠近，我要叫保安了"
			reaction=8
			hostile=0
		"restrained":
			reaction=0
			mood="停手！我不想和你打架"
			hostile=5 if affinity<=-36 else 0
			block_time=1.1 if hostile==0 else 0
		"volatile":
			mood="别动手！"
			hostile=6
		_:
			mood="停止攻击，退后"
			hostile=6
	if knocked_out or dead: hostile=0; reaction=0
	game.on_aggression(self,action)
	if dead:
		care_state="awake"
		game.on_npc_death(self)


func _physics_process(delta: float) -> void:
	street_request=""
	if care_state in ["away","carried"]: return
	if not seat_body:
		for prop in game.props:
			if prop.stable_id.ends_with("_seat") and Vector2(prop.position.x-home.x,prop.position.z-home.z).length()<0.5:
				seat_body=prop
				add_collision_exception_with(prop)
				break
	block_time=maxf(0,block_time-delta)
	hit_stun=maxf(0,hit_stun-delta)
	visit_wait=maxf(0,visit_wait-delta)
	reaction = maxf(0,reaction-delta)
	attack_cooldown = maxf(0, attack_cooldown - delta)
	hostile = maxf(0, hostile - delta)
	var distance := global_position.distance_to(game.player.global_position)
	label.visible = false
	label.text = title.split(" · ")[0]+(" · 已死亡" if dead else "")
	if not is_on_floor(): velocity.y -= 20 * delta
	if down > 0 or dead:
		down = maxf(1.0 if care_state=="unconscious" else 0.0,down-delta)
		visual.rotation.z = lerpf(visual.rotation.z, fall_side*PI/2, delta * 12)
		velocity.x = move_toward(velocity.x,0,delta * 4)
		velocity.z = move_toward(velocity.z,0,delta * 4)
	else:
		visual.rotation.z = lerpf(visual.rotation.z, 0, delta * 10)
		var target := home
		if game.payroll.after_work() and role_id in ["a_friend","a_group","b_friend"]:
			target=CityEvening.destination(self)
		if role_id=="b_friend" and (not game.payroll.after_work() or game.career.b_event=="negotiating"):
			match game.career.b_event:
				"refused", "helping": target=Vector3(21,0,-4)
				"negotiating": target=game.player.position+Vector3(1.5,0,0)
				"helped", "negotiated", "conflict": target=Vector3(14,0,4)
		if role_id=="b_friend" and not game.payroll.after_work() and game.handover.data.get("phase") in ["pending","delivered"]: target=home
		var visiting: Variant=game.office.visit_target(self)
		if visiting!=null: target=visiting
		elif (visit_wait>0 or game.speaker==self) and not (role_id=="b_friend" and game.career.b_event=="negotiating"): target=position
		var social_target: Variant=game.social.npc_target(self)
		if social_target!=null: target=social_target
		if game.meals:
			var meal_target: Variant=game.meals.npc_target(self)
			if meal_target!=null: target=meal_target
		var introduction: Variant=game.onboarding.npc_target(self)
		if introduction!=null: target=introduction
		var meeting: Variant=game.interviews.host_target(self)
		if meeting!=null: target=meeting
		if game.handover.owns(self) and game.speaker!=self: target=game.handover.point()
		if hostile > 0 and game.player.protection <= 0 and distance < 9 and game.can_see(self, game.player):
			target = game.player.global_position
			if distance < 1.6 and attack_cooldown == 0:
				game.player.hurt(18)
				attack_cooldown = 1.0
		if reaction>0:
			var guard: OfficeNPC=game.npc_for_role(company+"_guard")
			target=guard.home+Vector3(0,0,1) if temperament()=="cautious" and guard else global_position+(global_position-game.player.global_position).normalized()*2
		route_clock-=delta
		if route_clock<=0:
			route=game.walking.route(global_position,target,seat_body,self)
			route_clock=0.8
		while not route.is_empty() and Vector2(route[0].x-position.x,route[0].z-position.z).length()<0.28: route.remove_at(0)
		if Vector2(target.x-position.x,target.z-position.z).length()<0.3: route.clear()
		var next := global_position if route.is_empty() else route[0]
		if global_position.distance_to(target)<1.5 and game.walking.clear_segment(global_position,target,seat_body,self): next=target
		street_request=CityFootRoutes.request(global_position,next)
		if street_request!="" and not game.population.may_cross(street_request): next=global_position
		var direction := next - global_position
		direction.y = 0
		if direction.length() > (.035 if game.handover.owns(self) and game.speaker!=self else .15):
			direction = direction.normalized()
			# The grid excludes moving people; steer around nearby bodies locally.
			for other in game.npcs+game.population.residents+[game.player]:
				if other==self: continue
				var away: Vector3=global_position-other.global_position
				away.y=0
				var separation := away.length()
				if separation<1.4 and separation>0.01 and direction.dot(-away.normalized())>0.1:
					var side := Vector3(-direction.z,0,direction.x)
					if away.dot(side)<0: side=-side
					direction=(direction+side*clampf((1.4-separation)*2.8,0,1.8)).normalized()
			velocity.x = direction.x * 2.3
			velocity.z = direction.z * 2.3
		else:
			velocity.x = 0
			velocity.z = 0
	if hit_stun>0 and down<=0 and not dead:
		velocity.x=hit_push.x*hit_stun/0.32
		velocity.z=hit_push.z*hit_stun/0.32
	var interview_seated: bool=game.interviews.host_seated(self)
	var interview_calling: bool=game.interviews.host_calling(self)
	seated=interview_seated or not dead and role not in ["guard","hr"] and down<=0 and hostile<=0 and reaction<=0 and block_time<=0 and hit_stun<=0 and visit_wait<=0 and game.speaker!=self and game.office.visit_target(self)==null and game.social.npc_target(self)==null and game.onboarding.npc_target(self)==null and Vector2(position.x-home.x,position.z-home.z).length()<0.4 and not game.payroll.after_work()
	visual.position.y=move_toward(visual.position.y,0.27 if down>0 or dead else visual.seated_offset.y if seated else 0.0,delta*2.5)
	label.position.y=1.65 if seated else 2.05
	if block_time>0 and down<=0 and not dead:
		var opponent: Vector3=game.player.position-position
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-opponent.x,-opponent.z),delta*10)
	elif seated:
		visual.rotation.y=lerp_angle(visual.rotation.y,PI if interview_seated else 0,delta*5)
	elif down<=0 and not dead and Vector2(velocity.x,velocity.z).length()>0.3:
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-velocity.x,-velocity.z),delta*8)
	elif down<=0 and not dead:
		var facing: Vector3 = game.player.global_position-global_position if distance<5 else Vector3(0,0,1)
		var public_focus: Variant=CityEvening.facing(self)
		if public_focus!=null: facing=public_focus-global_position
		if game.meals:
			var meal_facing: Variant=game.meals.facing(self)
			if meal_facing!=null: facing=meal_facing-global_position
		if game.handover.owns(self) and game.speaker!=self: facing=game.handover.station().position-global_position
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-facing.x,-facing.z),delta*4)
	update_body_pose()
	visual.blocking=block_time>0 and available()
	visual.scene_action=game.interviews.performance(self)
	if game.handover.working(self): visual.scene_action="terminal_work"
	visual.set_attention(game.player.visual.face_position(),available() and hit_stun<=0 and (game.speaker==self or interview_calling or interview_seated))
	visual.pose(Vector2(velocity.x,velocity.z).length(),attack_cooldown>0.7,down>0 or dead,seated,interview_seated or interview_calling,hit_stun>0,(game.speaker==self and not game.conversation.is_empty()) or interview_calling or (interview_seated and game.interviews.active_firm()==company))
	var requested_motion := Vector2(velocity.x,velocity.z).length()
	move_and_slide()
	if requested_motion>0.4 and position.distance_to(last_position)<delta*0.15:
		stuck_time+=delta
		if stuck_time>1.2:
			route.clear()
			route_clock=0
			game.navigation_dirty=0.05
			mood="通道被挡住，等待重新绕行"
			stuck_time=0
	else: stuck_time=0
	last_position=position
	if position.y < -6: position = home

func update_body_pose() -> void:
	var next := "down" if down>0 or dead else "seated" if seated else "standing"
	var pose_key := next+str(fall_side) if next=="down" else next
	if pose_key==body_pose: return
	body_pose=pose_key
	var capsule: CapsuleShape3D=body_shape.shape
	capsule.height=1.4 if next=="seated" else 1.8
	if not visual.cast_id.is_empty(): capsule.height=visual.standing_height+(visual.seated_offset.y if next=="seated" else 0.0)
	body_shape.rotation=Vector3(0,visual.rotation.y,fall_side*PI/2) if next=="down" else Vector3.ZERO
	body_shape.position=Vector3(-0.75*fall_side,0.28,0).rotated(Vector3.UP,visual.rotation.y) if next=="down" else Vector3(0,0.7 if next=="seated" else 0.9,0)
	if not visual.cast_id.is_empty():
		body_shape.position=Vector3(-capsule.height*0.5*fall_side,0.28,0).rotated(Vector3.UP,visual.rotation.y) if next=="down" else Vector3(0,capsule.height*0.5,0)
	# A rigid body may be sleeping on the old support surface when posture changes.
	for prop in game.props:
		if not prop.freeze and prop.position.distance_to(position)<2.5: prop.sleeping=false
