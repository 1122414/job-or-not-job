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
	draw_circle(point(game.transit.bus.position),5,Color("e09267"))
	draw_circle(point(game.player.position),5,Color("63d6ef"))
	draw_string(ThemeDB.fallback_font,Vector2(12,24),"N ↑    蓝：你    橙：101",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
