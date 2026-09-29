class_name CityUrbanFabric
extends RefCounted

# These are three authored infill lots inside the existing district. The public
# graph remains the circulation spine; the ground-floor galleries are walkable.
const LOTS := [
	{"id":"west","at":Vector3(-18,0,35),"size":Vector3(16,12,18),"wall":"old_wall","title":"榕树里 · 公共连廊"},
	{"id":"east","at":Vector3(18,0,35),"size":Vector3(16,15,18),"wall":"home_wall","title":"东里 · 街坊休憩廊"},
	{"id":"north","at":Vector3(-16,0,78),"size":Vector3(16,12,20),"wall":"old_wall","title":"海风里 · 公共连廊"}
]

static func build(streets: CityStreetscape) -> void:
	for lot in LOTS: arcade(streets,lot)
	background(streets)

static func arcade(s: CityStreetscape,lot: Dictionary) -> void:
	var at: Vector3=lot.at
	var size: Vector3=lot.size
	var floor_height := 3.2
	# No step: visual paving sits above the district's unchanged y=0 collider.
	s.box(Vector3(size.x+2,.018,size.z+2),at+Vector3(0,.005,0),"paving")
	s.solid(Vector3(8,2.95,4),at+Vector3(0,1.475,-3),"brick")
	s.solid(Vector3(size.x,.3,size.z),at+Vector3(0,3.05,0),"stone")
	s.solid(Vector3(size.x,size.y-floor_height,size.z),at+Vector3(0,(size.y+floor_height)/2,0),lot.wall)
	for x in [-size.x/2+1.2,size.x/2-1.2]:
		for z in [-size.z/2+1.2,size.z/2-1.2]:
			s.solid(Vector3(.42,2.9,.42),at+Vector3(x,1.45,z),"brick")
	for face in range(4):
		var yaw := face*PI/2
		var rot := Basis(Vector3.UP,yaw)
		var width := size.x if face%2==0 else size.z
		var depth := size.z if face%2==0 else size.x
		var front := at+rot*Vector3(0,0,depth/2+.08)
		for floor_index in range(ceili((size.y-floor_height)/3)):
			var y := 4.7+floor_index*3
			s.box(Vector3(width+.3,.13,.3),front+Vector3(0,y-1.35,0),"trim",yaw)
			for column in range(4):
				var pos := front+rot*Vector3((column-1.5)*(width-3)/4,y,0)
				s.box(Vector3(2.3,1.85,.13),pos,"reveal",yaw)
				var lit := (column+floor_index+face)%5==1
				s.box(Vector3(2.1,1.62,.15),pos+rot*Vector3(0,0,.045),"window_lit" if lit else "glass",yaw)
				for dx in [-1.07,0,1.07]: s.box(Vector3(.065,1.72,.2),pos+rot*Vector3(dx,0,.1),"trim",yaw)
				s.box(Vector3(2.5,.12,.55),pos+rot*Vector3(0,-.96,.14),"stone",yaw)
				if column%2==0:
					s.box(Vector3(.9,.55,.5),pos+rot*Vector3(1.55,-.75,.2),"metal",yaw)
					for bar in range(4): s.box(Vector3(.7,.035,.03),pos+rot*Vector3(1.55,-.92+bar*.12,.47),"trim",yaw)
		# Roof parapets have an open centre and a recessed equipment penthouse.
		s.box(Vector3(width+.25,.65,.3),front+Vector3(0,size.y+.3,0),lot.wall,yaw)
		s.box(Vector3(width+.5,.14,.52),front+Vector3(0,size.y+.68,0),"trim",yaw)
	s.box(Vector3(size.x,.12,size.z),at+Vector3(0,size.y+.02,0),"roof")
	s.box(Vector3(5,2.3,4.5),at+Vector3(1,size.y+1.15,-2),lot.wall)
	s.box(Vector3(5.4,.2,4.9),at+Vector3(1,size.y+2.35,-2),"roof")
	s.plaque(lot.title,at+Vector3(0,2.67,size.z/2+.1),5.3)
	# Seating stays against the core, away from the through passage at z=+7.
	s.bench(at+Vector3(-2,0,0),PI,"commons_"+lot.id+"_0")
	s.bench(at+Vector3(2,0,0),PI,"commons_"+lot.id+"_1")
	for dx in [-2.4,-1.2,0,1.2,2.4]:
		s.box(Vector3(1,.85,.12),at+Vector3(dx,1.35,-5.08),"metal")
		for row in range(3): s.box(Vector3(.85,.015,.02),at+Vector3(dx,1.1+row*.25,-5.16),"trim")

static func background(s: CityStreetscape) -> void:
	# Scenery only: outside the playable bounds, without destinations, collision,
	# population or save identities. It must never count as metropolitan content.
	var lots: Array[Dictionary]=[]
	for i in range(9):
		lots.append({"at":Vector3(-180+i*46,0,-63-abs(i-4)*6),"size":Vector3(24,25+(i*17)%39,23)})
	for side in [-1,1]:
		for i in range(5):
			lots.append({"at":Vector3(side*(137+(i%2)*20),0,-12+i*25),"size":Vector3(20,22+(i*13+side+1)%32,19)})
		for i in range(5):
			lots.append({"at":Vector3(side*(220+i*19),0,-66+i*35),"size":Vector3(28,30+(i*19)%55,26)})
	s.box(Vector3(900,.12,520),Vector3(0,-.2,-135),"soil")
	for i in range(lots.size()):
		var at: Vector3=lots[i].at
		var size: Vector3=lots[i].size
		var wall := "stone" if i%3==0 else "home_wall" if i%3==1 else "old_wall"
		s.box(size,at+Vector3(0,size.y/2,0),wall)
		s.box(Vector3(size.x*.48,3,size.z*.65),at+Vector3(0,size.y+1.5,0),"roof")
		for face in range(4):
			var yaw := face*PI/2
			var rot := Basis(Vector3.UP,yaw)
			var width := size.x if face%2==0 else size.z
			var depth := size.z if face%2==0 else size.x
			for floor_index in range(int(size.y/3.2)):
				var center := at+rot*Vector3(0,1.7+floor_index*3.2,depth/2+.04)
				s.box(Vector3(width-1.5,1.6,.1),center,"glass",yaw)
				for column in range(4):
					var pos := center+rot*Vector3((column-1.5)*(width-3)/4,0,.055)
					s.box(Vector3(.35,1.8,.12),pos,wall,yaw)
					if (i+column+floor_index+face)%9==0:
						s.box(Vector3(1.2,1.5,.12),pos+rot*Vector3(.9,0,.02),"window_lit",yaw)
	s.set_meta("background_lots",lots.size())
	s.set_meta("arcade_lots",LOTS.size())
