extends RefCounted

# These states represent deaths already stored by v27 and earlier, not new attacks.
# Preserve compatibility coverage while the current gameplay uses temporary injuries.
static func npc(game: Node3D,person: OfficeNPC) -> void:
	person.hp=0;person.dead=true;person.down=2.7;person.care_state="awake"
	person.hostile=0;person.reaction=0;person.sync_care()
	game.on_npc_death(person)

static func resident(game: Node3D,person: CityResident) -> void:
	person.hp=0;person.down=0;person.state="dead"
	game.response.alarm(person)
