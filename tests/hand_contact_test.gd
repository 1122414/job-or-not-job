extends SceneTree

var failures := 0
var report := {}
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1

# Evaluate the imported skin, independently of the contact frame's wrist transform.
func skin_samples(h: HumanVisual,side: String) -> Array:
	var body: MeshInstance3D=h.find_children("body","MeshInstance3D",true,false)[0]
	var arrays := body.mesh.surface_get_arrays(0)
	var rest := h.skeleton.get_bone_global_rest(h.skeleton.find_bone("wrist."+side))
	var center: Vector3=(rest*h.contacts.palms[side]).origin
	var result := []
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		var vertex: Vector3=arrays[Mesh.ARRAY_VERTEX][i]
		if vertex.distance_to(center)>0.025: continue
		var influences := []
		for slot in range(4):
			var weight: float=arrays[Mesh.ARRAY_WEIGHTS][i*4+slot]
			if weight<=0: continue
			var bind: int=arrays[Mesh.ARRAY_BONES][i*4+slot]
			influences.append([h.skeleton.find_bone(body.skin.get_bind_name(bind)),body.skin.get_bind_pose(bind)*vertex,weight])
		result.append(influences)
	return result

func surface_distance(h: HumanVisual,samples: Array,point: Vector3) -> float:
	var distance := INF
	for vertex in samples:
		var position := Vector3.ZERO
		for influence in vertex: position+=(h.skeleton.get_bone_global_pose(influence[0])*influence[1])*influence[2]
		distance=minf(distance,h.skeleton.to_global(position).distance_to(point))
	return distance

func penetration(h: HumanVisual,prop: OfficeProp) -> float:
	var body: MeshInstance3D=h.find_children("body","MeshInstance3D",true,false)[0]
	var arrays := body.mesh.surface_get_arrays(0)
	var transforms := []
	for bind in body.skin.get_bind_count():
		var bone := h.skeleton.find_bone(body.skin.get_bind_name(bind))
		transforms.append(prop.global_transform.affine_inverse()*h.skeleton.global_transform*h.skeleton.get_bone_global_pose(bone)*body.skin.get_bind_pose(bind))
	var worst := 0.0
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		var point := Vector3.ZERO
		for slot in range(4):
			point+=(transforms[arrays[Mesh.ARRAY_BONES][i*4+slot]]*arrays[Mesh.ARRAY_VERTEX][i])*arrays[Mesh.ARRAY_WEIGHTS][i*4+slot]
		var depth: float
		if prop.kind=="cup": depth=minf(0.05-Vector2(point.x,point.z).length(),0.075-absf(point.y))
		else:
			var size: Vector3=OfficeProp.TYPES[prop.kind][1]*0.5
			if prop.kind=="monitor": point-=Vector3(0,-0.40,0.02);size=Vector3(0.55,0.035,0.3)*0.5
			var depths := size-point.abs()
			depth=minf(depths.x,minf(depths.y,depths.z))
		worst=maxf(worst,depth)
	return worst

func run() -> void:
	for person in ["casual","office","office_female","protagonist","lin_lan","a_cheng"]:
		var h := HumanVisual.new()
		if person in ["casual","office","office_female"]: h.outfit=person
		else: h.cast_id=person
		root.add_child(h)
		h.set_process(false)
		h.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var samples := {"L":skin_samples(h,"L"),"R":skin_samples(h,"R")}
		var worst := 0.0
		var reach_error := 0.0
		for frame in range(97):
			h.animation.play("walk");h.animation.seek(frame/97.0,true);h.animation.advance(0)
			for side in ["L","R"]:
				var target := h.global_transform*Transform3D(Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP),Vector3(-0.20 if side=="L" else 0.20,h.standing_height*0.64,-0.32))
				h.contacts.reach(side,target)
				h.contacts.fingers(side,0)
				worst=maxf(worst,surface_distance(h,samples[side],h.contacts.palm(side).origin))
				reach_error=maxf(reach_error,h.contacts.palm(side).origin.distance_to(target.origin))
		check(worst<0.01,person+" evaluated skin stays within 1 cm of the palm contact")
		check(reach_error<0.02,person+" reachable carry targets stay within 2 cm")
		report[person]={"skin_error_m":worst,"reach_error_m":reach_error}
		# Far-away requests must remain finite and must not stretch the bones.
		var bone := h.skeleton.find_bone("lowerarm01.L")
		var before := h.skeleton.get_bone_pose_position(bone)
		h.contacts.reach("L",Transform3D(Basis.IDENTITY,Vector3(100,100,100)))
		check(h.contacts.palm("L").is_finite() and h.skeleton.get_bone_pose_position(bone)==before,"Unreachable target cannot stretch or corrupt bones")
		h.queue_free();await process_frame
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);root.set_disable_input(true)
	for i in range(10): await physics_frame
	game.set_process(false);game.player.set_physics_process(false)
	for npc in game.npcs: npc.set_physics_process(false)
	for action in ["interview_lead","interview_boss","interview_b"]:
		var firm := "b" if action=="interview_b" else "a"
		var host: OfficeNPC=game.npc_for_role(InterviewFlow.HOSTS[action])
		game.interviews.schedule(action)
		var session: Dictionary=game.interviews.sessions[firm]
		session.call_stage="room";session.status="active";session.step=2 if action=="interview_boss" else 1
		host.position=OfficeRooms.point(game,firm,"interview_host")
		var h := host.visual
		h.position=h.seated_offset;h.rotation.y=PI
		h.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var phone := OfficeRooms.object(game,firm,"InterviewPhone"+firm.to_upper())
		var home := phone.transform
		var id := phone.get_instance_id()
		for clip in (["phone_reply","box_message"] if firm=="b" else ["phone_reply"]):
			h.animation.stop();h.current=clip;h.animation.play(clip);h.animation.advance(0)
			var samples := skin_samples(h,"L")
			var worst := 0.0
			var jump := 0.0
			var previous := phone.global_position
			for frame in range(257):
				var phase := frame/256.0
				h.animation.seek(phase*h.animation.get_animation(clip).length,true);h.animation.advance(0)
				jump=maxf(jump,phone.global_position.distance_to(previous));previous=phone.global_position
				var gesture := clampf((phase-0.25)/0.70,0,1) if clip=="box_message" else phase
				if gesture>=0.18 and gesture<=0.84:
					worst=maxf(worst,surface_distance(h,samples,phone.to_global(Vector3(0.0375,0,0))))
				check(phone.visible and phone.get_instance_id()==id and h.find_children("*","MeshInstance3D",true,false).size()==h.get_node("Model").find_children("*","MeshInstance3D",true,false).size(),"Exactly one original phone mesh throughout the gesture")
			check(worst<0.01,action+"/"+clip+" phone side contacts evaluated palm skin within 1 cm")
			check(jump<0.025,action+"/"+clip+" no visibility/position jump during pickup or replacement")
			check(phone.transform.is_equal_approx(home),"Phone returns to its authored transform before the clip finishes")
			report[action+"/"+clip]={"skin_error_m":worst,"max_sample_displacement_m":jump}
		h.animation.stop();h.current="phone_reply";h.animation.play("phone_reply");h.animation.seek(1.6,true);h.animation.advance(0)
		game.interviews.interrupt()
		check(phone.transform.is_equal_approx(home),"Interrupted interview immediately restores its unique phone")
		session.status="active"
		h.animation.play("phone_reply");h.animation.seek(1.6,true);h.animation.advance(0)
		game.interviews.sessions.erase(firm)
		game.interviews.update_props()
		check(phone.transform.is_equal_approx(home),"Removing recruitment/session cannot leave a phone suspended")
		session.status="completed"
	var player: OfficePlayer=game.player
	player.visual.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for kind in ["keyboard","cup","monitor","badge"]:
		var prop: OfficeProp
		for item in game.props:
			if item.kind==kind: prop=item;break
		player.pick(prop)
		var samples := skin_samples(player.visual,"R")
		var worst := 0.0
		var deepest := 0.0
		for frame in range(97):
			player.visual.animation.play("walk");player.visual.animation.seek(frame/97.0,true);player.visual.animation.advance(0)
			worst=maxf(worst,surface_distance(player.visual,samples,prop.to_global(prop.support_point())))
			if frame%24==0: deepest=maxf(deepest,penetration(player.visual,prop))
			if kind in ["keyboard","monitor"]:
				var left := prop.support_point();left.x=-left.x
				check(player.visual.contacts.palm("L").origin.distance_to(prop.to_global(left))<0.01,"Wide object has a second support")
		check(worst<0.01,kind+" underside contacts evaluated palm skin within 1 cm")
		check(deepest<0.002,kind+" palm/fingers do not pierce the support volume by more than 2 mm")
		var before := prop.global_transform
		player.release(kind=="keyboard")
		check(prop.global_transform.is_equal_approx(before),"Release preserves actual hand position and orientation: "+kind)
		check(not prop.freeze and prop.collision_mask==3,"Released item returns to physical collision")
		report["held/"+kind]={"skin_error_m":worst,"max_support_penetration_m":deepest}
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Background fixture never captures mouse")
	game.queue_free();await process_frame
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			FileAccess.open(argument.trim_prefix("--output="),FileAccess.WRITE).store_string(JSON.stringify({"measurements":report,"failures":failures},"\t"))
	print("HAND_CONTACT_TEST measurements=",JSON.stringify(report)," failures=",failures)
	quit(failures)
