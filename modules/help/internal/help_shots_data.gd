extends RefCounted
## The help chapters' pictures: one per wrist screen (tools/help_shots.gd makes them). Each:
## id (the file, DIR/<id>.webp), channel (the wrist screen), do (steps before the shot) and
## ring ([number, "words on the screen"]: what the chapter's numbered callouts point at; see
## tools/help_ring.gd) and crop ([x, y, w, h] of the 1600 x 1000 window, for a corner of a big screen).

const DIR := "res://modules/help/shots"

const SHOTS := [
	{"id": "console", "ring": [[1, ["=NEW", "=LEAVE"]], [2, ["TOOLS, DOORS, WALLS, WIRES", "=SHUTTER"]],
			[3, ["ROOMS  (pick", "PICK A ROOM"]], [4, ["COMPONENTS  (click", "Pilot console"]],
			[5, ["=MEASURE", "=LOOK HERE", "=SAMPLE SKIFF"]], [6, ["=DESIGN DATA#1", "=Build"]], [7, "=CONTRACT"]]},
	{"id": "console_orders", "crop": [960, 40, 640, 560], "ring": [[1, "=CONTRACT"], [2, "ORDERS ("], [3, "Starter job: a crew"]]},
	{"id": "console_quote", "crop": [960, 40, 640, 560], "ring": [[1, "QUOTE  CR"], [2, "SEND QUOTE"], [3, "=CONTRACT DETAILS"]]},
	{"id": "console_terms"},
	{"id": "console_signed", "crop": [960, 40, 640, 560], "ring": [[1, "SIGNED  CR"], [2, "SIGN STAGE GATE"], [3, "DELIVER FOR TRIAL"], [4, "=CONTRACT DETAILS"]]},
	{"id": "stock", "channel": "stores.stock", "ring": [[1, ["UNITS HELD", "SHORT FOR DESIGN", "units promised a place"]], [2, ["LONG STOCK", "Floor cradles"]], [3, ["=ALL", "=INBOUND"]], [4, ["=PART", "=TONNES"]], [5, ["STORES HALL", "%RackMap"]], [6, "%Detail"]]},
	{"id": "market", "channel": "supply.market", "ring": [[1, ["=CHEAPEST^1", "=MEDIAN COST^1"]], [2, "=DEALS THIS WEEK^1"], [3, "OPTIMISER 1/"], [4, ["=PART", "=TARROW", "=Airlock"]], [5, ["=PRICE HISTORY", "=180 D", "WHOLE DESIGN at each"]], [6, ["=VENDORS AND STANDING", "Meridian General Supply"]]]},
	{"id": "orders", "channel": "orders.book", "ring": [[1, "PARTS ORDERS ·"], [2, "berth"], [3, ["BILL OF MATERIALS", "=MEDIAN COST^1"]], [4, "=YOUR MIX^1"], [5, ["=PLACE ORDER", "=ORDER CHEAPEST"]], [6, "· ordered ^1"], [7, "  CR "]]},
	{"id": "trading", "channel": "orders.trade", "ring": [[1, "PARTS TRADING  ·"], [2, ["=MARKET", "=INSIDER TIPS"]], [3, ["=HOW THIS WORKS", "3. When"]], [4, ["=PART", "=LAST 90 DAYS"]], [5, "this week:^1"], [6, ["=NEW 50", "=SELL ALL"]]]},
	{"id": "trading_tips", "channel": "orders.trade", "do": [["set", "page", "TIPS"]]},
	{"id": "fit", "channel": "design.fit", "ring": [[1, "CONTRACT FIT ASSESSMENT^1"], [2, "OVERALL STATUS^1"], [3, ["AREAS OF THE CONTRACT", "BUILDABILITY AND SAFETY^1"]], [4, "COMPANY OPTIMISER^1"]]},
	{"id": "plan", "channel": "build.plan", "ring": [[1, ["BUILD PLAN  ·", "JOBS "]], [2, ["=WORKMANSHIP^1", "=PAID BY THE BUILD^1"]], [3, ["▶", "=Pipes"]], [4, "Next:"], [5, "SIGN STAGE GATE"], [6, ["=BERTHS", "TUG TO#1"]]]},
	{"id": "accounts", "channel": "business.accounts", "ring": [[1, "=CASH^1"], [2, ["=NET WEEK^1", "=MONEY OUT^1"]], [3, "=NET WORTH^1"], [4, "=RUNWAY^1"], [5, ["=REPUTATION^1", "=LOANS OWED^1"]], [6, "=PROFIT AND LOSS^1"], [7, "=CASH#1^1"], [8, "CASH FORECAST^1"]]},
	{"id": "accounts_lower", "channel": "business.accounts", "do": [["scroll", 900]]},
	{"id": "crew", "channel": "multiplayer.crew", "ring": [[1, "CREW ON SHIFT^1"], [2, "=TRANSFER MONEY^1"], [3, "=CREW CHANNEL^1"], [4, "=HELMET CAM^1"]]},
	{"id": "fleet", "channel": "fleet.bots", "ring": [[1, ["=BOTS^1", "=CHARGE^1"]], [2, ["=BOT", "=GROUP"]], [3, ["=BOT DETAIL", "=GROUPS AND ORDERS"]]]},
	{"id": "fleet_orders", "channel": "fleet.bots", "do": [["press", "GROUPS AND ORDERS"]]},
	{"id": "bots", "channel": "bots.board", "ring": [[1, "BOTS ·"], [2, ["=CREW", "=LOG"]], [3, "Standing by^1"]]},
	{"id": "bots_rules", "channel": "bots.board", "do": [["set", "page", "RULES"]]},
	{"id": "bots_work", "channel": "bots.board", "do": [["set", "page", "WORK"]]},
	{"id": "bots_shop", "channel": "bots.board", "do": [["set", "page", "SHOP"]]},
	{"id": "company", "channel": "company.yard", "ring": [[1, "REPUTATION"], [2, ["=RANK", "=PAPERS"]], [3, ["=WORKSHOP", "Next:"]], [4, ["WHAT EACH RANK OPENS", "=Consortium^1"]]]},
	{"id": "company_clients", "channel": "company.yard", "do": [["set", "page", "CLIENTS"]]},
	{"id": "company_crew", "channel": "company.yard", "do": [["set", "page", "CREW"]]},
	{"id": "company_launch", "channel": "company.yard", "do": [["set", "page", "LAUNCH"]]},
	{"id": "company_papers", "channel": "company.yard", "do": [["set", "page", "PAPERS"]]},
	{"id": "help", "channel": "help.guide", "ring": [[1, ["01  WAREHOUSE STOCK", "11  THE COMPANY"]], [2, "CR "], [3, "12  HELP"]]},
]
