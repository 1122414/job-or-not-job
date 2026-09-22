class_name Payroll
extends RefCounted

const DAY := 1440
const PERIOD := 7 * DAY
const CENTS_PER_MINUTE := 20
const GAME_MINUTES_PER_SECOND := 0.5
var minute := 9 * 60
var fraction := 0.0
var next_payday := PERIOD
var balance := 0
var pending := {"a":0,"b":0}
var payments: Array = []

func tick(delta: float, employer: String) -> void:
	fraction+=delta*GAME_MINUTES_PER_SECOND
	var count := int(fraction)
	fraction-=count
	advance(count,employer)

func advance(count: int, employer: String) -> void:
	var end := minute+maxi(0,count)
	while minute<end:
		var stop := mini(end,next_payday)
		if employer in ["a","b"]: pending[employer]+=(stop-minute)*CENTS_PER_MINUTE
		minute=stop
		if minute==next_payday:
			for firm in ["a","b"]:
				if pending[firm]>0:
					payments.append({"id":str(next_payday)+firm,"company":firm,"cents":pending[firm],"minute":minute})
					balance+=pending[firm]
					pending[firm]=0
			next_payday+=PERIOD

func after_work() -> bool:
	return minute % DAY >= 18*60 or minute % DAY < 9*60

func time_text() -> String:
	return "第%d天 %02d:%02d" % [minute/DAY+1,minute%DAY/60,minute%60]
