class_name RentalSearch
extends Node3D

const MONTH := 30*Payroll.DAY
const OFFERS := [
	{"id":"old_lane","name":"榕树街 · 低价招租","at":Vector3(-58,0,45),"advertised":1800,"rent":4500,"deposit":3,"prepay":1,"walk":18,"detail":"中介：1800是床位的价格，照片里这一间4500。窗户朝走廊也算有窗。押三付一，服务费另算。\n你问能不能看合同，对方先问能不能今天转定金；最后说照片这套刚被订走了。","available":false},
	{"id":"river","name":"海风步道 · 人才公寓","at":Vector3(24,0,116),"advertised":2800,"rent":4800,"deposit":3,"prepay":1,"walk":35,"detail":"管家：2800是优惠后价格，要先提供正式劳动合同和社保。实习接收通知不算。\n你还没找到工作，无法先拿合同；不享优惠要4800，押三付一。当前普通房源排队，最快下个月。","available":false},
	{"id":"east","name":"东里101 · 现房直租","at":Vector3(58,0,42),"advertised":4200,"rent":4200,"deposit":3,"prepay":1,"walk":22,"detail":"房东：房子可以进去看，合同也能先看。4200一个月，押三付一，入住先付16800。\n你问应届生能否少押一点。他翻了一下手机：押一也行，月租4600。灵活的不是房租，是付款方式。","available":true}
]
var game: Node3D
var points: Array[RentalPoint]=[]
var notice := ""

static func blank(enabled: bool=false) -> Dictionary:
	return {"enabled":enabled,"started":false,"viewed":[],"guide":"","lease":"","rent":0,"deposit":0,"next_due":0,"arrears":0,"paid":0}

func state() -> Dictionary:
	if not game.story.data.has("rental"): game.story.data.rental=blank()
	return game.story.data.rental

func _ready() -> void:
	for offer in OFFERS:
		var point := RentalPoint.new();point.stable_id="rental_"+offer.id;point.title=offer.name;point.position=offer.at
		add_child(point);points.append(point)
		Shapes.box(point,Vector3(.85,1.2,.08),Vector3(0,1.2,0),Color("45605b"))
		var label := Shapes.label(point,"招租 / E\n"+str(offer.advertised)+"元起",Vector3(0,1.3,.06),26)
		label.pixel_size=.003
		point.hide()

func sync() -> void:
	for point in points: point.visible=state().started and not game.story.campus()

func begin() -> void:
	var data := state()
	if not data.enabled or data.started: return
	data.started=true;game.payroll.balance+=1800000
	game.career.record("rental_savings","带着18000元搬家储蓄进入秋招。看房首付款会占用这些钱，押金不等于可用余额。")
	sync();game.queue_save()

func required() -> bool:
	return state().enabled and state().started and state().lease==""

func target() -> RentalPoint:
	for point in points:
		if point.stable_id==state().guide: return point
	return null

func clear_guide() -> void:
	state().guide=""

func open(point: RentalPoint) -> void:
	if not point in points or not state().started: return
	clear_guide()
	var index := points.find(point)
	var offer: Dictionary=OFFERS[index]
	if not offer.id in state().viewed:
		state().viewed.append(offer.id)
		game.advance_time(45)
	game.speaker=point
	game.conversation={"text":offer.name+"\n"+offer.detail,"choices":[["记下真实条件，打开对比","rental_compare"],["先离开，再想想","rental_leave"]]}
	game.queue_save()

func handle(action: String) -> bool:
	if action=="rental_compare": game.panels.show_page("rental");return true
	if action=="rental_leave": game.close_interaction();return true
	return false

func guide(id: String) -> void:
	game.story.response.clear_guide();game.city_life.walk.guiding=false
	if game.social.outing.has("guiding"): game.social.outing.guiding=false
	state().guide="rental_"+id
	game.home.guiding=false;game.transit.waypoint="";game.driving.guide_car="";game.city_life.guide=""
	game.panels.show_page("");game.queue_save()

func sign_lease(low_deposit: bool) -> bool:
	var data := state()
	if not required() or data.viewed.size()<3: notice="先到三处现场核实，再比较合同。";return false
	var rent := 460000 if low_deposit else 420000
	var deposit := rent*(1 if low_deposit else 3)
	if game.payroll.balance<rent+deposit: notice="余额不足以支付这份合同的押金和首月租金，请比较另一种付款方案。";return false
	game.payroll.balance-=rent+deposit
	data.lease="east_flexible" if low_deposit else "east_standard"
	data.rent=rent;data.deposit=deposit;data.paid=rent;data.next_due=game.payroll.minute+MONTH;data.guide=""
	game.career.record("rental_signed","租下东里101：月租%d元，押金%d元。押金冻结，首月租金已付；之后每30天付租。"%[rent/100,deposit/100])
	notice="钥匙到手。家已标在地图上，现在可以自由选择公司参加面试。"
	game.home.guiding=true;game.queue_save();return true

func tick() -> void:
	var data := state()
	if data.lease=="": return
	if game.payroll.minute>=data.next_due:
		var months := 1+int((game.payroll.minute-data.next_due)/MONTH)
		data.arrears+=months*data.rent;data.next_due+=months*MONTH
		game.say("房租到期：%d元。可在 J 的租房记录查看余额与欠租。"%(months*data.rent/100))
		game.queue_save()
	var pay := mini(game.payroll.balance,data.arrears)
	if pay>0:
		game.payroll.balance-=pay;data.arrears-=pay;data.paid+=pay;game.queue_save()

func page(view: GamePageView) -> void:
	var data := state()
	view.paragraph("秋招第一件事：先有个能睡觉的地方。每次到场核实花45分钟；广告价格不等于签约价。",view.ACCENT)
	view.paragraph("余额 %.2f 元 · 押金 %.2f 元 · 累计已付租金 %.2f 元 · 欠租 %.2f 元"%[game.payroll.balance/100.0,data.deposit/100.0,data.paid/100.0,data.arrears/100.0])
	view.paragraph("连续受雇30天的实习收入估算为8640元；4200—4600元房租占49%—53%。未受雇时没有这笔收入。",view.MUTED)
	for offer in OFFERS:
		var seen: bool=offer.id in data.viewed
		view.paragraph(offer.name+" · 广告%d元起 · 步行通勤约%d分钟"%[offer.advertised,offer.walk],view.ACCENT)
		if seen:
			view.paragraph("现场月租%d元 · 押%d付%d · 首付款%d元\n"%[offer.rent,offer.deposit,offer.prepay,offer.rent*(offer.deposit+offer.prepay)]+offer.detail)
		else: view.paragraph("尚未现场核实。",view.MUTED)
		view.action("rental-"+offer.id,"前往现场"+(" · 再核对一次" if seen else " · 核实条件"),func(): guide(offer.id))
	if required():
		view.action("lease-standard","签东里101 · 押三付一 · 首付16800 / 月租4200",func(): sign_lease(false);view.refresh(),data.viewed.size()<3)
		view.action("lease-flexible","签东里101 · 押一付一 · 首付9200 / 月租4600",func(): sign_lease(true);view.refresh(),data.viewed.size()<3)
	elif data.lease!="": view.paragraph("已签约 · 下次付租："+game.recruitment.stamp(data.next_due)+"。工资到账时会先补欠租；未付部分记为欠租，暂不收回住处。",view.ACCENT)
	view.paragraph(notice,view.ACCENT)

static func valid(data: Variant) -> bool:
	if not data is Dictionary or not data.get("enabled") is bool or not data.get("started") is bool or not data.get("viewed") is Array: return false
	var ids := []
	for offer in OFFERS: ids.append(offer.id)
	var seen := []
	for id in data.viewed:
		if not id in ids or id in seen: return false
		seen.append(id)
	if not data.get("guide") in ["","rental_old_lane","rental_river","rental_east"] or not data.get("lease") in ["","east_standard","east_flexible"]: return false
	for key in ["rent","deposit","next_due","arrears","paid"]:
		if not CityPopulation.number(data.get(key),0,1e12,true): return false
	if not data.enabled and data.started or not data.started and (not data.viewed.is_empty() or data.guide!=""): return false
	if data.lease=="": return data.rent==0 and data.deposit==0 and data.next_due==0 and data.arrears==0 and data.paid==0
	var rent := 420000 if data.lease=="east_standard" else 460000
	return data.enabled and data.started and data.viewed.size()==3 and data.rent==rent and data.deposit==rent*(3 if data.lease=="east_standard" else 1) and data.next_due>0 and data.paid>=rent
