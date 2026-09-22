extends SceneTree
var failures := 0
func check(value: bool,message: String) -> void:
	if not value: push_error(message); failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	check(game.objective_text().contains("选择"),"开局先给公司选择")
	for firm in ["a","b"]:
		game.career.facts.guide_company=firm
		check(ObjectiveGuide.target(game).stable_id==firm+"_hr","公司选择映射具体岗位")
		game.career.conflict[firm]=2
		check(ObjectiveGuide.target(game)==null and game.objective_text().contains("不再招聘"),"关闭路线不指向不可用人物")
		game.career.conflict[firm]=0
	game.career.recruit.a=3
	game.career.facts.guide_company="a"
	game.career.apply("decline_a")
	check(game.objective_text().contains("邀请已暂缓"),"拒绝后目标应反映暂缓，而非催促入职")
	game.payroll.minute=12*60
	game.update_daylight()
	var noon: float=game.sun.light_energy
	game.payroll.minute=4*60
	game.update_daylight()
	check(game.sun.light_energy<noon*0.2,"凌晨没有白昼太阳")
	var p := Payroll.new()
	p.tick(10,"")
	check(p.minute==9*60+5,"正常时钟每秒半分钟")
	game.queue_free()
	await process_frame
	print("GUIDANCE_TEST failures=",failures)
	quit(failures)
