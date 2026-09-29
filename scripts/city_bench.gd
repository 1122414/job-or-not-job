class_name CityBench
extends StaticBody3D

var stable_id := ""
var title := "街廊长凳 · 坐下歇歇"

func seat_point(side: int) -> Vector3:
	return global_transform*Vector3(-.6 if side==0 else .6,0,0)

func approach() -> Vector3:
	return global_transform*Vector3(0,0,-1.35)
