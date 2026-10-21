extends RefCounted
## The company's people and debts: who owns it, daily wages by skill level, bonuses,
## payslips and loans. Part of the books (Books.company); money moves through Books.post
## and the players' wallets. Checks (who may do what, limits) happen before these calls.

var books: RefCounted
## The owner's player name; "" until someone is named, when the host owns it.
var owner := ""
## Player name -> Array of payslips, newest last:
## {day, level, wage, bonuses: [{amount, note, by}], total}.
var payslips: Dictionary = {}
## Open loans, oldest first: {id, principal, months, apr, monthly, paid_months, balance,
## taken_day}.
var loans: Array[Dictionary] = []
var _next_loan := 1


func _init(p_books: RefCounted) -> void:
	books = p_books


func reset() -> void:
	owner = ""
	payslips = {}
	loans = []
	_next_loan = 1


# --- Wages, bonuses and payslips ---

## A day's wage for a crew member at this skill level.
func wage_for(level: int) -> int:
	var r: BusinessRules = books.rules
	return mini(r.wage_base + r.wage_per_level * maxi(0, level), r.wage_max)


## Today's payslip for a player, made when first needed (a bonus before payday).
func slip(player: String, day: int) -> Dictionary:
	var list: Array = payslips.get(player, [])
	if list.is_empty() or int(list.back().day) != day:
		list.append({"day": day, "level": 0, "wage": 0, "bonuses": [], "total": 0})
		var keep: int = books.rules.payslips_kept
		if list.size() > keep:
			list = list.slice(list.size() - keep)
		payslips[player] = list
	return list.back()


## Pays the day's wages: crew is player name -> skill level, for everyone on shift.
func pay_wages(crew: Dictionary, day: int) -> void:
	for player: String in crew:
		var level := int(crew[player])
		var wage := wage_for(level)
		var s := slip(player, day)
		s.level = level
		s.wage = wage
		s.total = wage + _bonus_sum(s)
		books.post(-wage, LedgerEntry.WAGES, player, "level %d" % level)
		_credit(player, wage)
		books._bus.payslip_issued.emit(player, s.duplicate(true))


func award_bonus(to: String, amount: int, note: String, by: String, day: int) -> void:
	var s := slip(to, day)
	s.bonuses.append({"amount": amount, "note": note, "by": by})
	s.total = int(s.wage) + _bonus_sum(s)
	books.post(-amount, LedgerEntry.BONUS, to, note)
	_credit(to, amount)
	books._bus.bonus_awarded.emit(to, amount, note, by)


func _bonus_sum(s: Dictionary) -> int:
	var n := 0
	for b: Dictionary in s.bonuses:
		n += int(b.amount)
	return n


func _credit(player: String, amount: int) -> void:
	books.wallets[player] = books.wallet(player) + amount
	books._bus.wallet_changed.emit(player, books.wallets[player], amount)


# --- Loans ---

## The fixed monthly repayment for a loan, interest included.
func monthly_for(amount: int, months: int, apr: float) -> int:
	var r := apr / 100.0 / 12.0
	if r <= 0.0:
		return ceili(float(amount) / months)
	return ceili(amount * r / (1.0 - pow(1.0 + r, -months)))


## What is still owed across every loan.
func owed() -> int:
	var n := 0
	for l in loans:
		n += int(l.balance)
	return n


## The most the company may borrow now.
func loan_room(reputation: float) -> int:
	var r: BusinessRules = books.rules
	return maxi(0, r.loan_limit_base + int(r.loan_limit_per_rep * reputation) - owed())


func take_loan(amount: int, months: int, day: int) -> Dictionary:
	var apr: float = books.rules.loan_apr_percent
	var monthly := monthly_for(amount, months, apr)
	var loan := {"id": "LN-%04d" % _next_loan, "principal": amount, "months": months, "apr": apr,
			"monthly": monthly, "paid_months": 0, "balance": monthly * months, "taken_day": day}
	_next_loan += 1
	loans.append(loan)
	books.post(amount, LedgerEntry.LOAN, loan.id, "%d months at %s%%" % [months, str(apr)])
	books._bus.loan_taken.emit(loan.duplicate())
	return loan


## Takes the monthly repayments falling due at the end of `day`.
func collect_repayments(day: int) -> void:
	var per: int = books.rules.days_per_month
	for loan in loans.duplicate():
		var age := day + 1 - int(loan.taken_day)
		if age <= 0 or age % per != 0:
			continue
		var due := mini(int(loan.monthly), int(loan.balance))
		_repay(loan, due, "month %d of %d" % [int(loan.paid_months) + 1, int(loan.months)])
		loan.paid_months = int(loan.paid_months) + 1


## Pays a loan off in one go: what's left, less the interest not yet earned.
func settle_amount(loan: Dictionary) -> int:
	var left := int(loan.months) - int(loan.paid_months)
	var r := float(loan.apr) / 100.0 / 12.0
	if r <= 0.0:
		return int(loan.balance)
	# The principal still outstanding after paid_months instalments.
	var p := float(loan.principal) * pow(1.0 + r, int(loan.paid_months)) \
			- float(loan.monthly) * (pow(1.0 + r, int(loan.paid_months)) - 1.0) / r
	return clampi(ceili(p), 0, int(loan.balance)) if left > 0 else 0


func settle(loan_id: String) -> int:
	for loan in loans:
		if loan.id == loan_id:
			var amount := settle_amount(loan)
			_repay(loan, amount, "paid off")
			loan.balance = 0
			loans.erase(loan)
			return amount
	return 0


func find_loan(loan_id: String) -> Dictionary:
	for loan in loans:
		if loan.id == loan_id:
			return loan
	return {}


func _repay(loan: Dictionary, amount: int, note: String) -> void:
	if amount <= 0:
		return
	books.post(-amount, LedgerEntry.REPAYMENT, loan.id, note)
	loan.balance = int(loan.balance) - amount
	if int(loan.balance) <= 0:
		loans.erase(loan)
	books._bus.loan_repaid.emit(str(loan.id), amount, maxi(0, int(loan.balance)))


# --- Saves ---

func save_data() -> Dictionary:
	return {"owner": owner, "payslips": payslips.duplicate(true), "loans": loans.duplicate(true), "next_loan": _next_loan}


func load_data(d: Dictionary) -> void:
	reset()
	owner = str(d.get("owner", ""))
	# JSON brings numbers back as floats; keep money whole.
	var ints := ["day", "level", "wage", "total", "amount", "principal", "months", "monthly", "paid_months", "balance", "taken_day"]
	var whole := func(x: Dictionary) -> Dictionary:
		for k in ints:
			if x.has(k):
				x[k] = int(x[k])
		return x
	var slips: Dictionary = d.get("payslips", {})
	for player in slips:
		var list: Array = []
		for s: Dictionary in slips[player]:
			var c: Dictionary = whole.call(s.duplicate(true))
			c.bonuses = (c.get("bonuses", []) as Array).map(func(b): return whole.call(b))
			list.append(c)
		payslips[str(player)] = list
	for l: Dictionary in d.get("loans", []):
		var c: Dictionary = whole.call(l.duplicate())
		c.apr = float(c.get("apr", 0.0))
		loans.append(c)
	_next_loan = int(d.get("next_loan", loans.size() + 1))
