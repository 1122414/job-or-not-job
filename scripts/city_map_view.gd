class_name CityMapView
extends Control

var game: Node3D

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func point(world: Vector3) -> Vector2:
	var scale_factor := minf((size.x-60)/216,(size.y-30)/156)
	return size/2+Vector2(world.x,world.z-54)*scale_factor

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("23343c"))
	var line := PackedVector2Array()
	for p in game.transit.curve.get_baked_points(): line.append(point(p))
	draw_polyline(line,Color("739b95"),6,true)
	for i in range(CityLayout.STOPS.size()):
		var stop: Dictionary=CityLayout.STOPS[i]
		var p := point(stop.point)
		draw_circle(p,6,Color("e6c785"))
		draw_string(ThemeDB.fallback_font,p+Vector2(10,-8),stop.title.split(" · ")[0],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
	for car in game.driving.cars:
		draw_rect(Rect2(point(car.position)-Vector2(3,3),Vector2(6,6)),Color("c4ccca") if car.traffic else Color("73c990"))
	draw_circle(point(game.transit.bus.position),5,Color("e09267"))
	draw_circle(point(game.player.position),5,Color("63d6ef"))
	draw_rect(Rect2(point(CityResponse.DEPOT)-Vector2(4,4),Vector2(8,8)),Color("83c9bc"))
	draw_string(ThemeDB.fallback_font,point(CityResponse.DEPOT)+Vector2(8,-8),"接收站",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("83c9bc"))
	draw_circle(point(game.response.crew.position),3,Color("83c9bc"))
	draw_rect(Rect2(point(CityPopulation.POINTS.bookshop_entry)-Vector2(4,4),Vector2(8,8)),Color("eee1bf"))
	draw_string(ThemeDB.fallback_font,point(CityPopulation.POINTS.bookshop_entry)+Vector2(-8,-12),"书屋",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("eee1bf"))
	draw_home(self,point(game.home.entrance.position),"我的家")
	draw_string(ThemeDB.fallback_font,Vector2(12,24),"N ↑    蓝：你    橙：101    绿：可用车    金色房屋：家",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)

static func draw_home(canvas: CanvasItem,at: Vector2,label: String) -> void:
	var color := Color("ffe0a0")
	canvas.draw_rect(Rect2(at-Vector2(7,2),Vector2(14,11)),Color("25343c"))
	canvas.draw_rect(Rect2(at-Vector2(6,1),Vector2(12,9)),color,false,2)
	canvas.draw_polyline(PackedVector2Array([at+Vector2(-8,0),at+Vector2(0,-7),at+Vector2(8,0)]),color,2,true)
	canvas.draw_line(at+Vector2(0,3),at+Vector2(0,8),color,3)
	canvas.draw_string_outline(ThemeDB.fallback_font,at+Vector2(10,5),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color("172128"))
	canvas.draw_string(ThemeDB.fallback_font,at+Vector2(10,5),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
