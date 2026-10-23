class_name LedgerEntry
extends RefCounted
## One movement of money. Positive amounts come in, negative go out.

const DEPOSIT := "deposit"
const PAYMENT := "payment"
const PARTS := "parts"
const RENT := "rent"
const PENALTY := "penalty"
const REFUND := "refund"
const UPGRADE := "upgrade"
const GOODWILL := "goodwill"
const WAGES := "wages"
const BONUS := "bonus"
const LOAN := "loan"
const REPAYMENT := "repayment"
## Bales and ingots sold to the metal broker.
const SCRAP := "scrap"
## Money added by a debug button (testing).
const DEBUG := "debug"

var day := 0
var amount := 0
var category := ""
## The contract or order this is for, if any.
var ref := ""
var note := ""


func to_dict() -> Dictionary:
	return {"day": day, "amount": amount, "category": category, "ref": ref, "note": note}


static func from_dict(d: Dictionary) -> LedgerEntry:
	var e := LedgerEntry.new()
	e.day = int(d.get("day", 0))
	e.amount = int(d.get("amount", 0))
	e.category = str(d.get("category", ""))
	e.ref = str(d.get("ref", ""))
	e.note = str(d.get("note", ""))
	return e
