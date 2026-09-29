class_name CityEvening
extends RefCounted

# The same public places can be visited without an invitation from the player.
# Work, conversation, accepted plans and danger still override this base target.
const PLANS := {
	"a_friend":["bookshop","waterfront"],
	"a_group":["garden","waterfront"],
	"b_friend":["waterfront","garden"]
}
const FOYERS := {"a_friend":Vector3(-8,0,18),"a_group":Vector3(-4,0,18),"b_friend":Vector3(8,0,18)}

static func venue(npc: OfficeNPC) -> String:
	var minute: int=npc.game.payroll.minute%1440
	if not PLANS.has(npc.role_id) or minute<1140 or minute>=1260: return ""
	var place: String=PLANS[npc.role_id][0 if minute<1200 else 1]
	# An outdoor continuation remains possible after the bookshop closes.
	if place=="bookshop" and not npc.game.city_life.is_open(): return "garden"
	return place

static func destination(npc: OfficeNPC) -> Vector3:
	var place := venue(npc)
	if place=="": return FOYERS[npc.role_id]
	# Shared places use separate standing spots where two routines overlap.
	return CityOuting.place_position(npc,place)

static func at_place(npc: OfficeNPC) -> String:
	var place := venue(npc)
	if place=="" or not npc.available() or npc.hostile>0 or npc.reaction>0 or npc.hit_stun>0: return ""
	var game: Node3D=npc.game
	if not game.social.outing.is_empty() or game.social.work_following(npc) or game.office.visit_target(npc)!=null or game.onboarding.npc_target(npc)!=null or game.interviews.host_target(npc)!=null: return ""
	return place if npc.position.distance_to(destination(npc))<.7 else ""

static func facing(npc: OfficeNPC) -> Variant:
	var place := at_place(npc)
	if place=="" or npc.game.speaker==npc: return null
	return {"bookshop":Vector3(-47,1.5,28),"garden":Vector3(38,1.4,56),"waterfront":Vector3(28,1.5,135)}[place]

static func greeting(npc: OfficeNPC) -> String:
	var place := at_place(npc)
	if place=="": return ""
	return npc.title.split(" · ")[0]+"："+{"bookshop":"下班后过来看看书。没想到在这里碰见你。","garden":"我想在花园里缓一会儿。你也出来走走？","waterfront":"我绕到海边吹吹风。今天的事情可以先放一放。"}[place]
