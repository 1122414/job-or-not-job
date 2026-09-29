class_name CitySharePerformance
extends Node3D

var life: CityLife
var books := {}

func _ready() -> void:
	for index in CityLife.AUDIENCE:
		var person: CityResident=life.game.population.residents[index]
		var book := CityStoryAlbum.new()
		person.add_child(book)
		book.scale=Vector3.ONE*.36
		book.hide()
		books[person.stable_id]=book

func attending() -> Array[CityResident]:
	var result: Array[CityResident]=[]
	for index in CityLife.AUDIENCE:
		var person: CityResident=life.game.population.residents[index]
		if life.present(person): result.append(person)
	return result

func running() -> bool:
	return life.active() and life.player_at_event() and attending().size()>=2

func narrator() -> CityResident:
	var people := attending()
	if people.size()<2: return null
	var preferred: CityResident=life.game.population.residents[CityLife.AUDIENCE[mini(2,int(life.elapsed/6))]]
	return preferred if preferred in people else people[0]

func action(person: CityResident) -> String:
	if not running() or not life.present(person): return ""
	if life.method=="paper": return "story_read"
	return "story_present" if narrator()==person else "story_listen"

func facing(person: CityResident) -> Vector3:
	if not running(): return life.focus_position()
	var speaker := narrator()
	if speaker!=person:
		return speaker.global_position.lerp(life.focus_position(),pointing_weight()*.75) if life.method!="paper" else speaker.global_position
	var people := attending()
	var target: Vector3=life.game.player.global_position
	for other in people:
		if other!=person: target+=other.global_position
	target/=people.size()
	return target.lerp(life.focus_position(),pointing_weight()*.85) if life.method!="paper" else target

func pointing_weight() -> float:
	var seconds := fposmod(life.elapsed,6)
	return smoothstep(.3,.9,seconds)*(1.0-smoothstep(2.5,3.1,seconds))

func hand_target(book: CityStoryAlbum,side: String) -> Transform3D:
	var support_basis := Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP)
	var support := Transform3D(support_basis,Vector3(-.13/.36 if side=="L" else .13/.36,-.032,.23))
	if side=="R":
		var seconds := fposmod(life.elapsed,6)
		var edge := Transform3D(support_basis,Vector3(.36,-.009,.23))
		if book.page<2 and seconds>=4.8:
			# Approach around the rear edge. Raising straight from underneath
			# would pass the wrist through the stationary page stack.
			var above := Transform3D(support_basis,Vector3(.68,.2,.82))
			var behind := Transform3D(support_basis,Vector3(.68,-.032,.82))
			if seconds<5.0: support=support.interpolate_with(behind,smoothstep(4.8,5.0,seconds))
			elif seconds<5.15: support=behind.interpolate_with(above,smoothstep(5.0,5.15,seconds))
			else: support=above.interpolate_with(book.turning_page.transform*edge,smoothstep(5.15,5.45,seconds))
		elif book.page>0 and seconds<1.2:
			var finished := Transform3D(Basis(Vector3.BACK,PI),Vector3(0,.015,0))*edge
			var above := Transform3D(support_basis,Vector3(.68,.2,.82))
			var behind := Transform3D(support_basis,Vector3(.68,-.032,.82))
			if seconds<.6:
				var release := smoothstep(0,.6,seconds)
				support=finished.interpolate_with(above,release)
				support.origin.y+=sin(release*PI)*.4
				support.origin.z+=sin(release*PI)*.4
			elif seconds<.9: support=above.interpolate_with(behind,smoothstep(.6,.9,seconds))
			else: support=behind.interpolate_with(support,smoothstep(.9,1.2,seconds))
	return Transform3D(book.global_basis.orthonormalized()*support.basis,book.to_global(support.origin))

# Called after AnimationPlayer has evaluated its bone tracks. Interruptions are
# resolved by the resident state before any hand/head correction is applied.
func apply(person: CityResident) -> void:
	var book: CityStoryAlbum=books.get(person.stable_id)
	if not book: return
	var clip := action(person)
	book.visible=clip=="story_read" and person.visual.current==clip
	if clip=="" or person.visual.current!=clip: return
	var human := person.visual
	var skeleton := human.skeleton
	var target := facing(person)+Vector3.UP*1.5
	if clip=="story_read":
		var sway := sin(life.elapsed*1.7+person.index)*.007
		book.global_transform=human.global_transform*Transform3D(Basis(Vector3.RIGHT,.35).scaled(Vector3.ONE*.36),Vector3(0,human.standing_height*.65+sway,-.36))
		book.show_story(mini(2,int(life.elapsed/6)),clampf((fposmod(life.elapsed,6)-5.2)/.8,0,1))
		for side in ["L","R"]:
			# The left palm supports the rear edge; the right follows the real
			# page hinge then returns above the book without stretching bones.
			human.contacts.reach(side,hand_target(book,side))
			human.contacts.fingers(side,-.10)
		if fposmod(life.elapsed,6)<4.0: target=book.global_position
	elif clip=="story_present":
		var weight := pointing_weight()
		var shoulder := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("upperarm01.R")).origin)
		var display := life.focus_position()
		if life.method=="garden": display+=Vector3((mini(2,int(life.elapsed/6))-1)*.95,1.45,.09)
		var direction := (display-shoulder).normalized()
		var across := Vector3.UP.cross(direction).normalized()
		var basis := Basis(across,direction,across.cross(direction))
		human.contacts.reach("R",Transform3D(basis,shoulder+direction*.43),weight)
		human.contacts.fingers("R",.65,weight)
		for joint in range(1,4):
			var finger := skeleton.find_bone("finger2-%d.R"%joint)
			skeleton.set_bone_pose_rotation(finger,skeleton.get_bone_pose_rotation(finger).slerp(Quaternion.IDENTITY,weight))
		if weight>.5: target=display
	var toward := human.to_local(target)-Vector3(0,1.55,0)
	var head := skeleton.find_bone("head")
	var rotation := Vector3(clampf(atan2(-toward.y,Vector2(toward.x,toward.z).length()),-.3,.35),clampf(atan2(-toward.x,-toward.z),-.55,.55),0)
	skeleton.set_bone_pose_rotation(head,Quaternion.from_euler(rotation))

func sync() -> void:
	for id in books:
		var person: CityResident=books[id].get_parent()
		if action(person)!="story_read": books[id].hide()
