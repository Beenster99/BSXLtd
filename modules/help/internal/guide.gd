extends RefCounted
## The built-in help (HelpBus): chapters in four groups. Plain lines: "# heading", "- bullet",
## "> tip", "1. a numbered step", "! <shot>" (a picture of the screen from shots/), "@ 2|text" (what
## the picture's ring 2 points at), "=> <channel>|Open it" (a button that puts a wrist screen up),
## "-> <page>|See ..." (a link to another chapter), anything else a paragraph; **words** are bold;
## {key:<action>} becomes the key it is on now. `screens`: the wrist screens a chapter explains (the
## Help tab opens on it from them). Write as you would explain it to a friend at the console:
## plain words, what each thing is for, and what to do next.

const START := "Start here"
const STEPS := "Step by step"
const SCREENS := "Screens"
const MORE := "More"

## Pages other modules used to add that these chapters now cover (HelpBus leaves them out).
const REPLACES: PackedStringArray = ["contracts.starter", "bots", "orders", "berths", "company", "papers", "trading"]

const TOPICS := [
	# --- Start here --------------------------------------------------------------------------
	{"id": "start", "order": 10, "group": START, "title": "Getting started", "text": """You run BSX Ltd, a shipyard in deep space. Clients order ships. You design each one, quote a price, buy her parts, build her in the dock and deliver her. The client pays in four stages along the way.
# The loop, in one line each
1. **Pick an order.** At the holotable in the design room, open the design console's CONTRACT panel and pick a client's ship order.
2. **Design her.** Lay out rooms and components until the order's demands are met.
3. **Quote.** SEND QUOTE. The client signs and pays a 20% deposit.
4. **Buy parts.** On the wrist's Parts orders screen, stage by stage, as cash allows.
5. **Build.** The ship is built in the build berth outside the station: by hand for small ships, by the bots for bigger ones.
6. **Get paid as she grows.** Keel laid and Fit-out each pay 20% once you sign their stage gate.
7. **Deliver.** DELIVER FOR TRIAL. The surveyors test her and the last 40% is paid, up or down with how well she did.
# Where to begin
- Read **Your first contract** below. It walks you through all of it, screen by screen.
- Open the wrist screen with {key:holo} anywhere. Every tab along its top is a screen with a chapter here.
> On any wrist screen, click the 12 HELP tab: Help opens on the chapter for the screen you were just on.
-> first_contract|Your first contract, step by step"""},
	{"id": "keys", "order": 20, "group": START, "title": "Keys", "text": ""},
	{"id": "wrist", "order": 30, "group": START, "title": "The wrist screen", "text": """{key:holo} brings up the wrist screen anywhere in a game. {key:holo} or {key:cancel} puts it away. Click a tab along the top for another screen.
! help
@ 1|**The tabs.** One for each screen. The lit one is the screen you are on.
@ 2|**Cash.** The company's money right now, on every screen.
@ 3|**Help.** These pages. Opened from another tab, it starts on that screen's chapter.
# What each tab is for
- **Warehouse stock**: what the stores hold, and what the open design is short of.
- **Parts market**: what the open design's parts cost at every supplier. Look here; buy on Parts orders.
- **Parts orders**: where you actually buy a ship's parts, and watch them arrive.
- **Parts trading**: buy parts cheap and sell them dear, as a sideline.
- **Contract fit**: how well the open design meets its order, and what to change.
- **Build plan**: the ship in the berth, stage by stage, and the berths.
- **Accounts**: the company's books and the cash to come.
- **Crew**: who is playing, chat, helmet cams and sending money.
- **TartanCo fleet** and **Bot board**: the worker bots.
- **The company**: the yard's rank, rival bids, crew roles, naming ships, papers.
> Most of these screens also go up on the design room's walls, full size."""},
	{"id": "help_use", "order": 40, "group": START, "title": "Using Help", "text": """- Click a chapter on the left. **Step by step** chapters are the jobs you do (taking a contract, buying parts). **Screens** chapters explain one screen each: what it is for and what every number and button means.
- Type in the search box to find a word in any chapter (try "deposit", "late" or "greyed").
- On a screen chapter, the picture is that screen with orange numbered rings. The numbered lines under it say what each ring is.
- Orange buttons like this one open the screen itself, so you can try it as you read:
=> orders.book|Open Parts orders
- Help opens where you left it, or on the chapter of the screen you were just on."""},

	# --- Step by step ------------------------------------------------------------------------
	{"id": "first_contract", "order": 100, "group": STEPS, "title": "Your first contract", "text": """From a client's order to the last payment, for the first time. The two **Starter jobs** at the top of the order list are small, generous and in no hurry: start with one.
# 1. Pick the order
1. Walk to the holotable in the design room and press {key:interact}. The design console opens.
2. Bottom right, click the **>** beside **CONTRACT** to open that panel. It starts folded away.
3. Click **PICK FROM ORDERS** and click a Starter job. Its demands (crew, cargo, cost...) are listed under its title.
! console_orders
@ 1|**CONTRACT** panel. Click its arrow to open it.
@ 2|**PICK FROM ORDERS** lists the clients' orders. Each shows its budget, how realistic the money is (Generous, Fair, Tight, Long shot, Unrealistic) and how many things it asks for.
@ 3|A **Starter job**. Pick one of these first.
# 2. Design a ship that meets it
4. Lay out rooms and components on the deck plan. The **DESIGN DATA** panel (right) scores her against the order as you go: red numbers are demands not met yet.
5. To learn the design console, or to skip designing for now, the sample skiff meets both Starter jobs: Esc > Settings > Debug > Open the sample skiff.
6. Check the wrist's **Contract fit** screen: it says what would lose you the contract and how to fix it.
-> fit|The Contract fit screen
# 3. Quote and sign
7. With the order picked, the CONTRACT panel shows your **QUOTE**: the price and your margin. The price is what her parts cost plus the yard's fee, never more than the client's budget.
8. Click **CONTRACT DETAILS** to see every payment: how much, what sets it off and its expected day.
9. Click **SEND QUOTE** (or SIGN AS ... AND SEND QUOTE). The client signs and pays the **deposit**, 20% of the price. Her build is set up in the build berth.
! console_quote
@ 1|**QUOTE**: the price, and your margin (the price less what her parts cost).
@ 2|**SEND QUOTE**. Greyed out? Hold the pointer on it to see why.
@ 3|**CONTRACT DETAILS**: the payment stages and their days.
# 4. Buy her parts, a stage at a time
10. Open the wrist ({key:holo}) on **Parts orders**. Her whole parts list is there, coloured by build stage.
11. The deposit will not buy everything. Press **ORDER NEXT STAGE: KEEL LAID** to buy just the frame (grey stripe): the build only needs each stage's parts when it gets there. Deliveries arrive within 10 real minutes.
-> buy_parts|Buying parts within your cash
# 5. Build her
12. A small ship is built **by hand**: fly out of the airlock to the build berth, go to the glowing pieces and press {key:interact}. They float into place, chalked where to weld, rivet or bolt. Use the welder, riveter and socket on the chalk marks.
13. The **Build plan** screen shows each stage, the next job and anything holding the build up.
-> build_ship|Building a ship
# 6. Sign the stage gates, get paid
14. When the frame is complete, the **Keel laid** gate is ready. Sign it (SIGN STAGE GATE on the Build plan, the design console or The company's PAPERS page) and the client pays 20%.
15. When the hull is closed and the main machinery is in, sign **Fit-out**: another 20%.
# 7. Deliver
16. Finish every stage, then in the design console with her design open, click **DELIVER FOR TRIAL**.
17. The surveyors test her against every demand. Each demand beaten by a quarter earns a bonus. Each one missed, or the build not finished, holds back part of the last payment. Late costs too.
-> deliver|Delivering and the trial
> Name her first, on The company's LAUNCH page. At delivery the bots line up and a bottle breaks on her bow."""},
	{"id": "buy_parts", "order": 110, "group": STEPS, "title": "Buying parts within your cash", "screens": [], "text": """A ship's parts cost most of her price, but the client pays only 20% up front. So buy her parts **a stage at a time**, as the payments come in. The build waits for each stage's parts only when it reaches that stage.
# Which lines belong to which stage
On Parts orders the parts list is grouped under a cyan heading for each payment stage, and the coloured stripe at the left of each line is its build stage:
- **KEEL LAID STAGE: grey, the frame.** Beams and their welds. Needed first.
- **FIT-OUT STAGE: blue plates and yellow fittings.** Hull plating, rivets, walls, deck and doors; rooms' kits, components and bolts.
- **DELIVERY STAGE: orange wiring and green pipes.**
# Step by step
1. Look at the cash at the top right of the wrist screen.
2. Open Parts orders. Check the plans in the **BILL OF MATERIALS CALCULATOR**: CHEAPEST, MOST RELIABLE and MEDIAN COST each give the total, the wait and how often those suppliers arrive on time.
3. The quick way: **ORDER NEXT STAGE: KEEL LAID, CR x** orders just the frame from the cheapest suppliers. It is greyed out when the cash won't cover it.
4. To choose suppliers yourself, don't press a plan's USE (that picks every line at once). On each line under **KEEL LAID STAGE**, click the supplier you want. Your choice shows as "Split:" under the line, and **YOUR MIX** adds it up. Then press **PLACE ORDER**. Greyed out? The amber line under it says why.
5. Every delivery arrives within 10 real minutes; each line counts down "due ... (about N min)". When the stage heading says all its lines are in, build the frame and sign **Keel laid**. That payment buys the **Fit-out** stage, and Fit-out's payment the **Delivery** stage.
=> orders.book|Open Parts orders
# Ways to stretch the money
- **Cheaper suppliers** wait longer and are late more often. A late part holds the build up, and a late ship costs 1% of the price a day.
- **½** on a quote buys half the line there, so you can split a big line between two suppliers.
- **USE n FROM STOCK** appears on a line when the yard already holds those parts (from trading). They cost nothing more.
- **Second-hand** quotes are cheaper components that go through the refurb works before they count as in.
- **Insider tips** (Parts trading) say which prices are about to rise or fall.
- **A loan**: Esc > Settings > Company lends a little at interest.
- **Sell parts** you hold on Parts trading.
> EXPRESS brings an order in under a minute, but costs 35% more. Keep it for the one part holding everything up."""},
	{"id": "build_ship", "order": 120, "group": STEPS, "title": "Building a ship", "text": """Once a contract is signed, her build is set up in the **build berth** (B1) outside the station, as a faint holo of the whole ship. Only the ship in B1 is worked on.
# Who builds her
- **Small ships are built by hand**, by you and your crew, one job at a time.
- **Bigger ships are built by the bots.** You can join in: fly to a glowing piece and press {key:interact}, or TAKE OVER a job on the Bot board's WORK page.
# By hand
1. Through the airlock the dock has no gravity: fly with the movement keys, {key:yard.up} and {key:yard.down}. {key:yard.brake} stops you.
2. Fly to the build berth. The next job's pieces glow.
3. Press {key:interact} at them. They float into place, chalked where they are to be fastened.
4. Weld, rivet or bolt each chalk mark with the right tool. How square and neat each one is counts towards the ship's **workmanship**, which the trial checks.
5. When every fastening of the job is made, the next job's pieces glow.
# When the build stops
- **"Waiting for parts"** on the Build plan: that stage's parts are not ordered or not in yet. Order them on Parts orders, or wait for them to arrive.
- **A stage gate to sign**: the build reached Keel laid or Fit-out. Sign it to be paid.
- **Bots idle?** Check their charge and the rule cards on the Bot board (a Hold card stops a stage).
# More than one ship
Holding berths (H1, H2) keep part-built ships. On the Build plan, **TUG TO H1** frees the build berth for another contract; tug her back to carry on. Holding berths open as the company grows.
=> build.plan|Open the Build plan"""},
	{"id": "deliver", "order": 130, "group": STEPS, "title": "Delivering and the trial", "text": """When she is built, deliver her for the surveyors' trial. The last payment, **Delivery** (40% of the price), is paid after it, up or down with the result.
# How to deliver
1. Check the Build plan: every stage done ("Built in full" is one of the things the trial checks).
2. Name her on The company's LAUNCH page if you like.
3. At the design console, open the design that was signed (DESIGNS), open the CONTRACT panel and click **DELIVER FOR TRIAL**. Greyed out? The design open is not the one the client signed.
# What the trial does to the last payment
- Each demand she **beats by a quarter** or more earns a bonus of 3% of the price (up to three).
- Each demand or clause she **misses** holds back 5% of the price. "Built in full" and "Workmanship" count as clauses.
- Each **day late** costs 1% of the price.
- She gets a grade from A to E. Delivering to spec raises your standing with that client, which opens bigger orders.
> Contract fit's BONUSES AND NEAR MISSES shows the bonuses in hand and the ones just out of reach, before you deliver."""},
	{"id": "money_short", "order": 140, "group": STEPS, "title": "When money runs short", "text": """Cash is the company's money now, top right of every wrist screen. Every day costs money: bay rent, crew wages and bot upkeep come out at midnight.
# Read the warning signs
- **Accounts** shows **RUNWAY**: how many days the cash lasts at today's costs. Under a month, take care.
- The **CASH FORECAST** on Accounts draws the next 30 days: payments due in, costs going out and the parts still to buy for your contracts. It says the lowest point the cash will reach.
=> business.accounts|Open Accounts
# What you can do
- **Buy a stage at a time.** Only order what the next stage needs.
- **Push for the next stage payment.** Finish the frame and sign Keel laid, or the fittings and sign Fit-out.
- **Sell held parts** on Parts trading. Watch for "90-day range: HIGH, sell".
- **Borrow.** Esc > Settings > Company: TAKE LOAN. Repaid monthly with interest.
- **Don't take a second contract** you can't buy the parts for.
> A guide to what things cost: a small ship's parts are around CR 500,000. Its deposit is a fifth of its price."""},
	{"id": "trade_parts", "order": 150, "group": STEPS, "title": "Trading parts for profit", "text": """A sideline: buy parts when the market is low and sell them when it is high.
1. Open **Parts trading** and look at **TRENDS**. "90-day range: LOW, buy" means today's price is near the bottom of the last three months.
2. Check **INSIDER TIPS**: which prices are expected to rise or fall in the next week or two.
3. Press **NEW 5** (or NEW 50 for hull stock) to buy at today's new price, or **BUY LOT** for five second-hand parts, cheaper but they need the refurb works first.
4. When they arrive, **YOU HOLD** shows them.
5. When the row says "HIGH, sell", press **SELL 1** or **SELL ALL**. Buyers always pay a bit less than the new price that day, so the profit is in the timing.
=> orders.trade|Open Parts trading
> Parts you hold can go into a build instead: Parts orders offers USE FROM STOCK, at no new cost."""},
	{"id": "stuck", "order": 160, "group": STEPS, "title": "Why isn't it working?", "text": """Some buttons go grey, or nothing seems to happen. Hold the pointer over a greyed button: its tooltip says why. The usual reasons:
# Parts orders
- **PLACE ORDER greyed**: nothing chosen yet (click a supplier on a line, or USE a plan), or not enough cash for the order. The line under the buttons says which.
- **Ordered but nothing arrives**: each supplier has a wait (the minutes on its quote), and every delivery arrives within 10 real minutes. The line's end counts down "due ... (about N min)"; "in the refurb works" means second-hand parts still being rebuilt.
- **"Waits for its parts"** at the top: the build will not start a stage until that stage's parts are in.
# Design console
- **SEND QUOTE greyed**: the order is already signed, the client doesn't know BSX well enough for an order that size, or the yard's berths are too small for her.
- **No orders to pick**: the CONTRACT panel is folded. Click its arrow, bottom right.
- **DELIVER FOR TRIAL greyed**: open the design the client signed.
# The build
- **Nothing glows in the berth**: the stage's parts are not in, a stage gate is waiting for a signature, or the ship is in a holding berth.
- **Bots standing by**: the ship in B1 is a hand build, a Hold card is on, or they are charging.
# Money
- **Cash went down overnight**: rent, wages and bot upkeep are paid at midnight. Accounts lists them.
-> money_short|When money runs short"""},

	# --- Screens ------------------------------------------------------------------------------
	{"id": "console", "order": 200, "group": SCREENS, "title": "Design console", "text": """The big screen at the holotable in the design room ({key:interact} to open it). You design ships here, and do a contract's paperwork: pick an order, quote, sign gates and deliver.
! console
@ 1|**Top bar.** NEW, DESIGNS (open a saved one), SAVE, UNDO, REDO; PLAN, SIDE and END views; DECK - and DECK + change deck; WALK INSIDE walks you through her at full size; LEAVE closes the console.
@ 2|**Tools, doors, walls, wires.** SELECT, doors of every kind, inner walls and beams, and DRAW WIRING or FUEL PIPE (ROUTE ALL lays them for you).
@ 3|**Rooms.** PICK A ROOM, then drag it out on the deck plan.
@ 4|**Components.** Filter by size and class, search, and click one into a room. R turns it.
@ 5|**The deck plan**, in the middle. Where you design.
@ 6|**Design data.** Cost, mass, power, crew; WILL IT WORK (what is wrong); the berth she needs; and the order's demands, met or not.
@ 7|**CONTRACT.** Folded at first: click its arrow. The order, the quote, SEND QUOTE, the payments, stage gates and DELIVER FOR TRIAL.
# The CONTRACT panel
! console_signed
@ 1|**SIGNED**: the price, what has been paid, and the next payment with its expected day.
@ 2|**SIGN STAGE GATE**: shows when the build reaches Keel laid or Fit-out. Sign it and that stage is paid.
@ 3|**DELIVER FOR TRIAL**: the surveyors' trial and the last payment.
@ 4|**CONTRACT DETAILS**: every payment and the signed papers.
# Handy
- Ctrl+Z undoes, Ctrl+Y redoes, Ctrl+S saves. Delete removes what is selected.
- WINDOW (top bar) shows or hides panels, changes the text size, and resets the layout if you lose a panel.
- Everyone in the room sees the same design and each other's edits.
-> first_contract|Your first contract, step by step"""},
	{"id": "fit", "order": 210, "group": SCREENS, "title": "Contract fit", "screens": ["design.fit"], "text": """How well the design open at the console meets the order it answers, area by area, and what to change. Check it before you SEND QUOTE and before you DELIVER FOR TRIAL.
! fit
@ 1|**The order**: who, what kind of ship, and its demands in short.
@ 2|**Overall status** and score: READY TO BID, BID WITH CARE, CLOSE, NEEDS WORK or NOT VIABLE. Under it, how many demands are met, the yard's fee and the pay you can expect.
@ 3|**Areas of the contract.** Each scored, with PASSES, WATCH or FAILS, and the lines behind it (OK or NO).
@ 4|**Company optimiser**: in plain words, what would lose you the contract, the cheap wins (grade swaps that save money), bonuses in hand and near misses.
# The areas
- **Performance against the brief**: each rating the client asked for (crew, cargo, speed...).
- **Cost and margin**: her cost against the client's ceiling, and room for a price rise.
- **Delivery schedule**: supplier waits and yard hours against the days allowed.
- **Buildability and safety**: anything that can't be built or needs checking.
- **Power and running**, **Crew and habitability**, and **What the client will look for**.
> A "FAILS" area costs you at the trial. Fix those first; the optimiser says how."""},
	{"id": "stock", "order": 220, "group": SCREENS, "title": "Warehouse stock", "screens": ["stores.stock"], "text": """Everything the stores hall holds: how much, where on the racks, what it is worth, and what the open design is still short of.
! stock
@ 1|**Totals**: units held, their value, weight, rack places used, units on the way in, and lines the open design is **short** of (red: you need to buy them).
@ 2|**Rack kinds** and how full each is: long stock (beams), plate, components and heavy.
@ 3|**Filters**: ALL, a rack kind, IN STOCK, SHORT (what the design still needs) or INBOUND (on its way).
@ 4|**The table.** One line a part. Click a heading to sort by it; click a line to pick that part.
@ 5|**The rack map**, both storeys. Each bay is shaded by how full it is; the part you picked lights up its bays.
@ 6|**The part picked**: how many, where, its size and value, and what the open design needs of it.
# The columns
- **RACKS**: which racks it is on. **HELD**: how many. **PLACES**: rack places they take. **ROOM**: how many more fit.
- **INBOUND**: on its way. **DESIGN**: how many the open design needs. **SHORT**: how many more you must buy (OK when covered).
- **UNIT CR**, **VALUE CR** and **TONNES**.
> Parts come in at GOODS IN, the east end of the stores hall. Bots rack them, then carry kits out to the yard side for the build."""},
	{"id": "market", "order": 230, "group": SCREENS, "title": "Parts market", "screens": ["supply.market"], "text": """Every supplier's price for each part of the **design open at the console**, this week's deals, and the best ways to buy the lot. This screen is for **looking**: you buy on Parts orders.
! market
@ 1|**Three ways to buy the whole design**: CHEAPEST, MOST RELIABLE and MEDIAN COST. Each with its total, how it compares with the market, the longest wait, how often its suppliers are on time, and how many suppliers.
@ 2|**Deals this week**: how many lines are on offer, how much they save, and the day the week ends.
@ 3|**The optimiser's notes**, one at a time: what each plan means for this design.
@ 4|**The price table.** One row a part, one column a supplier: the unit price and its wait in days. Cells outlined in orange are the picks of the plan you last clicked. WHOLE DESIGN at the top is the total from each supplier, and how many lines they stock.
@ 5|**Price history.** Click a row for that part's prices (or WHOLE DESIGN); 30 D, 90 D, 180 D for the span.
@ 6|**Vendors and standing.** Each supplier: how well they know BSX (out of 100) and what that gives you (days off the wait, % off), the next level, their on-time rate, volume discounts and deals.
# Words on this screen
- **Standing** grows each time you order from a supplier. More standing: shorter waits and lower prices.
- **On time 45%**: those suppliers arrive on the day only 45% of the time; otherwise a day to three late.
- **holds 4, then +5 d a batch**: they keep 4 in stock; more takes longer.
- **30 D** column: how much the part's price moved in the last 30 days.
=> orders.book|Buy them on Parts orders"""},
	{"id": "orders_screen", "order": 240, "group": SCREENS, "title": "Parts orders", "screens": ["orders.book"], "text": """Where you **buy** a ship's parts and watch them arrive. Each signed contract's parts list comes here; the build waits for each stage's parts.
! orders
@ 1|**The status line**: the ship, how many lines, how many are fully ordered, how many have fully **arrived**, and "WAITS FOR ITS PARTS" while the build is held up for them.
@ 2|**The ship** and her berth. ◀ ▶ switch between ships when there is more than one.
@ 3|**Bill of materials calculator.** Totals for buying everything still to order three ways (CHEAPEST, MOST RELIABLE, MEDIAN COST), each with its wait and on-time rate. **USE** picks that plan's supplier for every line.
@ 4|**YOUR MIX**: what you have chosen so far and what it would cost.
@ 5|**PLACE ORDER** buys your mix: each supplier gets its own order and the company pays now. **ORDER CHEAPEST** orders every line still to order from the cheapest suppliers. **ORDER NEXT STAGE** orders just the next payment stage's parts, cheapest, with its cost on the button: the easiest way to buy within your cash. Greyed out? The amber line under the buttons says why (nothing chosen, or not enough cash).
@ 6|**A part line.** Its stage stripe, its name, then how much the ship **needs**, how much is **ordered** and how much has **arrived** in the stores. The end says where it stands: **all in**, **due day N, HH:MM (about N min)** for an order on its way, **in the refurb works** for second-hand parts being rebuilt, or **not ordered**. Grey: not all ordered. Amber: all ordered, still coming. Green: all in.
@ 7|**A supplier's quote**: name, price each, how long delivery takes in real minutes, and how often they arrive on time. Click it to take the rest of the line from them. **½** takes half the line there.
@ 8|**A payment stage's heading** (cyan): the parts list is grouped by the payment each stage earns. **KEEL LAID** is the frame; **FIT-OUT** the hull plates, doors, rooms and machinery; **DELIVERY** the wiring and pipes. It counts how many of its lines are in.
# Lower down
- **EXPRESS: UNDER A MINUTE, +35%**: everything you order next arrives in under a minute, for 35% more. Every normal delivery arrives within 10 real minutes anyway.
- **CLEAR MIX** forgets what you chose (nothing ordered is undone).
- **USE n FROM STOCK** on a line: parts the yard already holds cover it, at no new cost.
- **ORDERS**: each order placed, its supplier, value, and when it is due (or "in the stores", or "in the refurb works" for second-hand parts being rebuilt).
-> buy_parts|Buying parts within your cash"""},
	{"id": "trading_screen", "order": 250, "group": SCREENS, "title": "Parts trading", "screens": ["orders.trade"], "text": """A market for parts on the side: each part's price rises and falls over weeks and months. Buy low, sell high, or use what you hold in a build.
! trading
@ 1|**The trading account**: what you have spent on stock, what buyers paid you, and the net so far (stock not yet sold counts as spent).
@ 2|**MARKET** and **INSIDER TIPS** pages.
@ 3|**How this works**, in three lines.
@ 4|**A part's row**: what YOU HOLD, the NEW price today, today's SECOND-HAND LOT (and its estimated refurb bill), what the best buyer pays today (SELL TODAY), and the last 90 days' chart.
@ 5|**TRENDS**: this week, this month, and where today sits in the last 90 days: LOW (buy), MIDDLING or HIGH (sell).
@ 6|**Buttons**: NEW 5 (or NEW 50), BUY LOT, SELL 1, SELL ALL. Hold the pointer on one to see its price.
# Insider tips
! trading_tips
The trade advisor's word on where prices are going in the next week or two, first for parts your builds still need ("order now" or "the order can wait"), then for the market at large.
- Selling many at once fetches a little less each.
- A second-hand lot's refurb bill is an estimate: you pay the real bill as each part is certified.
- Trading has its own line in the accounts.
-> trade_parts|Trading parts for profit"""},
	{"id": "plan_screen", "order": 260, "group": SCREENS, "title": "Build plan", "screens": ["build.plan"], "text": """The ship in the build berth, stage by stage: how far she is, what is next, what is holding her up, and the berths.
! plan
@ 1|**The ship** in the build berth, and **JOBS** done out of all her jobs.
@ 2|**Workmanship** (how well the fastenings are made, graded), **hand fastenings** made, and what the build has **paid** so far.
@ 3|**The stages**: Frame, Plates and walls, Fittings, Wiring, Pipes, each with jobs done. ▶ marks the stage under way. "Keel laid pays here" and "Fit-out pays here" mark the stage gates.
@ 4|**Next**: the job in hand and what to do.
@ 5|**SIGN STAGE GATE**: shows when the build reaches Keel laid or Fit-out. Sign it and the client pays that stage.
@ 6|**Berths**: B1 the build berth, H1 and H2 the holding berths, what is in each and who builds her. **TUG TO** moves a ship between them.
- **Waiting for parts** (amber) shows in place of the gate when that stage's parts are not ordered or not in yet, with **ORDER THE CHEAPEST PLAN** to order them in one press.
-> build_ship|Building a ship"""},
	{"id": "accounts_screen", "order": 270, "group": SCREENS, "title": "Accounts", "screens": ["business.accounts"], "text": """The company's books: where the money came from and went, what it is worth, and the cash to come. TODAY, 7 D, 30 D and ALL (top right) pick the period.
! accounts
@ 1|**CASH**: money in the company account now.
@ 2|**NET** for the period, **MONEY IN** and **MONEY OUT**.
@ 3|**NET WORTH**: cash plus stock plus parts on order, less debt.
@ 4|**RUNWAY**: how many days the cash lasts at what a day costs now.
@ 5|**REPUTATION** (sets how much you can borrow and how suppliers treat you) and **LOANS OWED**.
@ 6|**Profit and loss**: every kind of money in and out for the period, grouped, with the net result.
@ 7|**Cash chart**: closing cash each day, with the day's money in (green) and out (red).
@ 8|**Cash forecast, next 30 days**: what comes in (stage payments), what goes out (rent, wages, upkeep, parts still to buy) and the lowest point. Green line: cash stays above zero.
# Further down
! accounts_lower
- **Payments coming in**, by day, and **money going out**.
- **Balance sheet**: what the company owns and owes.
- **What a day costs now**: rent, wages, loan repayments and running costs, a day and a month.
- **Contracts on the books**: each contract's value, what is paid, its parts and its margin.
- **Loans**, **crew pay** and wallets, **stock on hand** and the **ledger**, newest first.
-> money_short|When money runs short"""},
	{"id": "crew_screen", "order": 280, "group": SCREENS, "title": "Crew", "screens": ["multiplayer.crew"], "text": """Who is playing, and the crew's own tools.
! crew
@ 1|**Crew on shift**: each player, and which one is the host.
@ 2|**Transfer money**: from your wallet or the company account to a crew member. Type an amount and SEND CR.
@ 3|**Crew channel**: chat with the crew.
@ 4|**Helmet cam**: press CAM by a name to see through their helmet.
- Hosting and joining are on the main menu's Play Online.
- Ping a spot with the middle mouse button (or {key:graphics.ping}) to show the crew where you mean."""},
	{"id": "fleet_screen", "order": 290, "group": SCREENS, "title": "TartanCo fleet", "screens": ["fleet.bots"], "text": """TartanCo supplies the yard's worker androids. This screen lists every one on site at a glance, with one bot in detail.
! fleet
@ 1|**The fleet's figures**: bots, how many are working, charging, with faults, and their average condition and charge.
@ 2|**The list**: each bot's status, current job, condition, charge, where it is and its group. Click a row for its detail.
@ 3|**BOT DETAIL** and **GROUPS AND ORDERS**: groups of bots with a priority and tasks from the build plan.
- Bots wear as they work. Past 40% wear they slow down; at 75% TartanCo's service ship comes to put them right.
- The bots are only listed while you are in the orbital yard, where they work.
-> bots_screen|The Bot board: what they do and in what order"""},
	{"id": "bots_screen", "order": 300, "group": SCREENS, "title": "Bot board", "screens": ["bots.board"], "text": """Runs TartanCo's fleet, the androids that build your ships: who they are, the rules they work to, the work in hand, and the shop. Five pages along the top.
! bots
@ 1|**The status line**: how many bots, how many at work, the build's jobs done, and their upkeep a day.
@ 2|**The pages**: CREW, RULES, WORK, SHOP, LOG.
@ 3|**CREW**: each TartanCo bot (F-3 fitters, W-3 welders, R-3 riveters, B-3 bolters), its mark, what it is doing, its charge (CHG) and wear. Click one to raise its mark (up to Mk5), fit a TartanCo module or send it for a service.
# Rules
! bots_rules
The bots read the rule cards top to bottom.
- **Section first**: which part of the ship they start from (bow, stern, midships, lowest or top deck).
- **Rush** a stage: its jobs go first. **Hold** a stage: they leave it till the card is off.
- **Leave for the crew**: they leave a stage for you to do by hand.
- **Helps**: one bot works beside another.
- **Inspect below 60%**: inspectors make any fastening worse than that again.
- **Charge below 25%**: a bot goes to charge under that.
- **ON/OFF** switches a card; **CHANGE** what it says; **UP** moves it up; **X** removes it; the + buttons add one.
# Work and shop
- **WORK**: who builds the ship in the berth (BOTS BUILD HER puts the bots on any ship, BUILD HER BY HAND gives her back to you), the build by stage, the jobs in hand and who has them (TAKE OVER to do one yourself, HAND BACK to return it), and what is stuck and why.
- **SHOP**: a new bot of each trade from TartanCo, what it does best ("weld x4" is four times a fitter's speed), its price and its upkeep a day. BUY. Each new bot gets a charge dock of its own on the berth (room for 10).
! bots_shop
> Welders weld four times as fast as a fitter; riveters rivet plates and wiring; bolters fit pipes. Bots low on charge hang on their charge docks on the build berth's frame. The TARTANCO FLEET screen shows the same bots."""},
	{"id": "company_screen", "order": 310, "group": SCREENS, "title": "The company", "screens": ["company.yard"], "text": """BSX Ltd as a whole: its rank, its clients and rivals, the crew's roles, naming ships, the trophy shelf and the signed papers.
! company
@ 1|**The headline**: the yard's rank, ships delivered and reputation.
@ 2|**The pages**: RANK, CLIENTS, CREW, LAUNCH, SHELF, PAPERS.
@ 3|**RANK**: where BSX is now and what the next rank asks.
@ 4|**What each rank opens**: more bots, holding berths, specialist bots and bigger ships. Deliver ships and earn reputation to climb from Workshop to Yard, Shipworks and Consortium.
# Clients and rivals
! company_clients
Rival yards bid for the same orders. You sign at the **lowest rival bid** unless the client knows BSX well (level 2), or it is a repeat order. Pleased clients come back with repeat orders.
# Crew roles
! company_crew
Take a role while you are on shift: **Foreman** (bots 10% faster), **Buyer** (parts orders 5% cheaper), **Welder** (hand fastenings a bit better) or **Launch master** (the crew's share of trial bonuses doubled).
# Launch, shelf and papers
- **LAUNCH**: name each ship before her trial. At delivery the bots line up and a bottle breaks on her bow.
- **SHELF**: a miniature of every ship the yard has built, signed by her crew.
- **PAPERS**: every contract's signed papers (design sign-off, stage gates, delivery note), and any gate waiting for a signature.
! company_papers"""},
	{"id": "refurb", "order": 320, "group": SCREENS, "title": "Refurb works", "text": """An annex of the stores hall where second-hand parts are rebuilt. The big screen over the charger rack shows its work.
# How a used part goes through
1. It comes in at goods in with the other deliveries, at Reclaimed grade and a condition nobody knows yet.
2. A cart takes it into the annex: small parts onto the rollers, big ones onto the heavy stand by the crane.
3. Refurb bots **INSPECT** it (a cracked casing is scrapped), **STRIP**, **CLEAN**, **REBUILD** and **TEST** it.
4. It is certified at **Standard** grade and goes into stock. Only then does it count as in for a build.
# The wall screen
- **TASKING**: each cradle and the heavy stand, the part on it, its stage and condition, and what is coming in.
- **DRONES**: what each refurb bot is doing and its charge.
- **THE WORKS**: goods in, on the rollers, certified, scrapped, what it has cost, and what is ready to take.
> The refurb bill is the part's new price times a share for its wear, so a worn part costs more to bring back."""},
	{"id": "walls", "order": 330, "group": SCREENS, "title": "The design room", "text": """The design room is the yard's office: the holotable, the design console and walls of screens.
- **The holotable** shows the open design as a hologram. With the console shut, the arrow keys turn and zoom it, N steps through its layers, Page Down cuts away the top deck.
- J puts what the hologram shows up on the wall you are facing.
- **Every wall is a set of screens.** Step a panel with its < and > arrows: plans, elevations, parts list, parts market, stock, accounts, parts orders, trading, the bot board, the company and more. They work like the wrist screens.
- **WALK INSIDE** (top bar of the console) takes you through the design at full size. **OPERATE** plays every door, ramp and leg. **SET HER DOWN** stands her on a pad.
> Everyone in the room sees the same design and each other's edits."""},

	# --- More ---------------------------------------------------------------------------------
	{"id": "yard", "order": 400, "group": MORE, "title": "The station and the dock", "text": """The station has gravity: walk with {key:move_forward} {key:move_left} {key:move_back} {key:move_right}, run with {key:run}, jump with {key:jump}.
# Rooms
- **Design room**: the holotable, the design console and the wall screens.
- **Stores hall**: two storeys of racks for every part, goods in at the east end, the yard side facing the dock.
- **Refurb works**: an annex of the stores hall where used parts are rebuilt.
- Crew room and quarters, and the airlock out to the dock.
# Outside, in zero g
- Through the airlock the dock has no gravity. Fly with the movement keys, up with {key:yard.up}, down with {key:yard.down}, roll with {key:yard.roll_left} {key:yard.roll_right}.
- {key:yard.brake} stops your drift. {key:yard.dampeners} switches the suit's dampeners off for free drifting.
- The build berth (B1) takes the ship being built; holding berths keep part-built hulls.
- {key:yard.kit} calls a mover bot with the next kit of parts.
> {key:yard.view} swaps first and third person. {key:yard.lamp} is the helmet lamp."""},
	{"id": "time", "order": 420, "group": MORE, "title": "Game time", "text": """The company's calendar drives everything dated: deliveries, payment stages, due days.
- Change the pace in Esc > Settings > Gameplay > Game time: paused, half, normal, double or four times.
- Skip to a later date there too. Every day in between closes as it would (rent, wages, deliveries, payments), but work the bots have under way does not jump ahead, so use a faster pace while they work.
- Each day closes at midnight: rent, wages and upkeep are paid, the market moves and payments fall due.
- In a shared game the host sets the pace for everyone."""},
	{"id": "together", "order": 430, "group": MORE, "title": "Playing together", "text": """- **Play Online** on the main menu: host a yard or join a friend's.
- The **Crew** tab lists who is here, their wallets, chat and helmet cams.
- Ping a spot with the middle mouse button (or {key:graphics.ping}) to show the crew where you mean.
- In the design room everyone works on the same design and sees each other's edits.
- Take a crew role on The company's CREW page: each one helps the yard while you are on shift."""},
]
