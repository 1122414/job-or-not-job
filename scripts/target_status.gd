class_name TargetStatus
extends RefCounted

static func supported(person: Node3D) -> bool:
	return is_instance_valid(person) and (person is OfficeNPC or person is CityResident or person is AutumnStoryPoint and person.person)

static func describe(game: Node3D,person: Node3D) -> Dictionary:
	if not supported(person): return {}
	var result := {"id":person.stable_id,"name":person.title.split(" · ")[0],"hp":person.hp,"affinity":0,"trust":0,"fear":0,"state":"平静","reason":"尚无共同经历"}
	if person is OfficeNPC:
		var social: Dictionary=game.social.state(person)
		result.affinity=person.affinity;result.trust=social.trust;result.fear=social.fear
		result.state="已故（历史记录）" if person.dead else "昏迷 / 救助中" if person.care_state!="awake" else "倒地" if person.down>0 else "愤怒 / 反击" if person.hostile>0 else "警惕" if social.fear>0 else person.mood
		if not social.memories.is_empty(): result.reason=social.memories[-1]
	elif person is AutumnStoryPoint:
		result.affinity=person.affinity;result.trust=person.trust;result.fear=person.fear
		result.state="暂时昏迷" if person.down>0 else "受伤 / 拒绝争辩" if person.fear>0 else "坚持拒绝实习"
		if person.fear>0: result.reason="你刚才动手，导师仍有戒心"
	else:
		var record: Dictionary=game.free_chat.records.get(person.stable_id,{})
		result.affinity=clampi(int(record.get("affinity",0))-person.hits*18,-100,100)
		result.trust=clampi(int(record.get("trust",0))-person.hits*20,-100,100)
		result.fear=mini(100,roundi(person.fear*5))
		result.state="已故（历史记录）" if person.hp==0 else "昏迷 / 等待救助" if person.down>0 else "害怕 / 躲避" if person.fear>0 else "交谈中" if person.state=="talking" else "平静"
		if person.hits>0: result.reason="对方记得你曾伤害过他"
	var chat: Dictionary=game.free_chat.records.get(person.stable_id,{})
	if chat.has("last_change"): result.reason=chat.last_change
	if result.fear==0 and person.available() and chat.get("attitude","neutral")!="neutral": result.state={"warm":"愿意亲近","guarded":"有所保留","angry":"不满"}.get(chat.attitude,result.state)
	return result
