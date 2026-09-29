extends "res://tools/render_character_candidates.gd"

func run() -> void:
 DirAccess.make_dir_recursive_absolute(output)
 root.set_disable_input(true)
 var viewport := SubViewport.new()
 viewport.size=Vector2i(1200,900)
 viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.msaa_3d=Viewport.MSAA_2X
 viewport.set_disable_input(true)
 root.add_child(viewport)
 var game=load('res://scenes/main.tscn').instantiate()
 viewport.add_child(game)
 for i in range(10):await physics_frame
 game.set_process(false)
 game.player.set_physics_process(false)
 game.player.visual.hide()
 for npc in game.npcs:npc.set_physics_process(false)
 var camera := Camera3D.new()
 game.add_child(camera);camera.make_current();camera.fov=40
 for firm in ['a','b']:
  var host: OfficeNPC=game.npc_for_role('a_lead' if firm=='a' else 'b_hr')
  game.interviews.schedule('interview_lead' if firm=='a' else 'interview_b')
  game.interviews.sessions[firm].call_stage='room'
  game.interviews.sessions[firm].status='active'
  game.interviews.sessions[firm].step=1
  host.position=OfficeRooms.point(game,firm,'interview_host')
  host.visual.position=host.visual.seated_offset;host.visual.rotation.y=PI
  var h := host.visual
  h.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  h.current='phone_reply';h.animation.play('phone_reply');h.animation.advance(0)
  var target := host.position+Vector3(.2,1.0,.30)
  camera.position=target+Vector3(.85,.35,1.25);camera.look_at(target)
  for phase in [0.18,0.32,0.55,0.84]:
   h.animation.seek(phase*3.2,true);h.animation.advance(0)
   if not await capture(viewport,firm+'-phone-'+str(phase)):quit(1);return
  game.interviews.sessions[firm].status='completed';game.interviews.update_phone_contact(host)
 game.player.visual.show();game.player.position=Vector3(-14,0,5)
 game.player.visual.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 game.player.visual.animation.play('idle');game.player.visual.animation.advance(0)
 camera.position=game.player.position+Vector3(.9,1.4,-1.7);camera.look_at(game.player.position+Vector3(0,1.0,-.3))
 for kind in ['keyboard','cup','monitor','badge']:
  for prop in game.props:
   if prop.kind==kind:game.player.pick(prop);break
  game.player.visual.animation.advance(0)
  game.player.sync_held()
  if not await capture(viewport,'held-'+kind):quit(1);return
 viewport.queue_free();await process_frame
 print('HAND_CONTACT_RENDER images=',captures,' pointer_visible=',Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
 quit()
