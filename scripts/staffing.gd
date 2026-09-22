class_name Staffing
extends RefCounted
var game: Node3D
var calm := {"a":0.0,"b":0.0}

func tick(delta: float) -> void:
	for firm in ["a","b"]:
		var disturbed := false
		for npc in game.npcs:
			if npc.company==firm and not npc.dead and (npc.hostile>0 or npc.down>0 or npc.reaction>0): disturbed=true
		calm[firm]=0.0 if disturbed else float(calm[firm])+delta
		if calm[firm]<30: continue
		var missing: Array[OfficeNPC]=[]
		for npc in game.npcs:
			if npc.stable_id==npc.role_id and npc.company==firm and game.npc_for_role(npc.role_id)==null: missing.append(npc)
		for original in missing:
			var number := 1
			for npc in game.npcs:
				if npc.role_id==original.role_id: number+=1
			var id := original.role_id+"_replacement_"+str(number)
			var names := ["沈言","陈悦","李沐","何宁","程远"]
			var title: String=names[number%names.size()]+" · 接任"+original.title.split(" · ")[-1]
			game.add_npc(id,title,Vector3(-14 if firm=="a" else 14,0,2.8),firm,original.role,original.role_id)
			var replacement: OfficeNPC=game.npcs.back()
			replacement.home=original.home
			game.career.record(id+"_arrival",title+"从入口到岗，接手未完成事务；私人关系重新建立。")
			game.say(title+"已到岗 · 未完成事务可继续联系")
			game.queue_save()
			game.navigation_dirty=0.1
