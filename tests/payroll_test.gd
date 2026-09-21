extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures+=1
func _initialize() -> void:
	var p := Payroll.new()
	p.advance(100,"a")
	check(p.pending.a==2000 and p.balance==0,"在职闲逛计薪但未提前支付")
	p.advance(Payroll.PERIOD-p.minute,"")
	check(p.balance==2000 and p.pending.a==0,"离职前应付到期保留")
	p.advance(Payroll.PERIOD*3,"")
	check(p.balance==2000 and p.payments.size()==1,"离职后不续计也不重复发")
	p.advance(Payroll.PERIOD*2,"b")
	check(p.balance==2000+Payroll.PERIOD*2*20 and p.payments.size()==3,"跨多期不漏发")
	var ids := {}
	for payment in p.payments: ids[payment.id]=true
	check(ids.size()==p.payments.size(),"账单ID唯一")
	var q := Payroll.new()
	q.advance(20,"a")
	q.advance(30,"b")
	q.advance(Payroll.PERIOD-q.minute,"")
	check(q.balance==1000 and q.payments.size()==2,"换公司应付独立保留")
	print("PAYROLL_TEST failures=",failures)
	quit(failures)
