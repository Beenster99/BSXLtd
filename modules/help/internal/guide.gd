extends RefCounted
## The built-in help pages (HelpBus). Plain lines: "# heading", "- bullet", "> tip", anything
## else a paragraph; {key:<action>} becomes the key it is on now. Keep each page short: one
## screen of the wrist, in the words players use.

const TOPICS := [
	{"id": "start", "order": 10, "title": "Getting started", "text": """You run BSX Ltd, a shipyard in deep space. Clients order new ships; your crew designs them, quotes, builds and delivers them, and gets paid in stages.
# The loop
- Pick a ship order in the design room and draw up a design that meets it.
- Send the client a quote. When they sign, they pay a deposit.
- Buy the parts. Haulers bring them to the stores hall and bots rack them.
- The ship is built in the build berth outside the station. TartanCo's bots do the heavy work.
- Deliver for the surveyors' trial. The last payment goes up or down with how well she meets the order.
# Where to begin
- Walk to the design room and use the holotable with {key:interact}.
- Start with one of the two Starter jobs at the top of the order list (PICK FROM ORDERS on the console). See Your first contract.
> {key:holo} opens this wrist screen anywhere. {key:cancel} or {key:holo} puts it away."""},
	{"id": "keys", "order": 20, "title": "Keys", "text": ""},
	{"id": "yard", "order": 30, "title": "The station and the dock", "text": """The station has gravity: walk with {key:move_forward} {key:move_left} {key:move_back} {key:move_right}, run with {key:run}, jump with {key:jump}.
# Rooms
- Design room: the holotable, the design console and the wall screens.
- Contracts desk: where clients' business is done.
- Stores hall: two storeys of racks for every part, goods in at the east end, the yard side facing the dock.
- Refurb works: an annex of the stores hall where used parts are rebuilt to Standard grade.
- Crew room and quarters, and the airlock out to the dock.
# Outside, in zero g
- Through the airlock the dock has no gravity. Fly with the movement keys, up with {key:yard.up}, down with {key:yard.down}, roll with {key:yard.roll_left} {key:yard.roll_right}.
- {key:yard.brake} stops your drift. {key:yard.dampeners} switches the suit's dampeners off for free drifting.
- The build berth takes the ship you are building; holding berths keep part-built hulls.
> {key:yard.view} swaps first and third person. {key:yard.lamp} is the helmet lamp."""},
	{"id": "design", "order": 40, "title": "Designing a ship", "text": """Stand at the holotable and press {key:interact} to open the design console.
# The console
- Left: rooms and components. Pick a size and grade, then place it on the deck plan.
- Middle: the deck plan, the main place to design. Page Up and Page Down change deck, R turns, Delete removes.
- Right: the hologram and the live data channel: cost, mass, power, crew, and how the design scores against its order.
- Top: your saved designs (new, open, save with Ctrl+S). Ctrl+Z undoes, Ctrl+Y redoes.
- WILL IT WORK lists what is wrong: missing services, parts that clash, a ship too long for the berth.
# Round the room
- With the console shut, the arrow keys turn and zoom the hologram, N steps through its layers, Page Down cuts away the top deck.
- J puts what the hologram shows up on the wall you are facing.
- Every wall is a set of screens. Step a panel with its < and > (plans, elevations, parts list, market, stock, accounts...).
- WALK INSIDE takes you through the design at full size. OPERATE plays every door, ramp and leg; SET HER DOWN stands her on a pad.
- Help's Sizes and classes page compares every component at every size and grade, and shows what each reactor can power.
> Everyone in the room sees the same design and each other's edits."""},
	{"id": "contracts", "order": 50, "title": "Contracts: order to payment", "text": """Clients post ship orders: a kind of ship, a size, demands (crew, cargo, range, speed, defence...) and clauses (rooms or parts she must have).
# Picking an order
- In the design console, PICK FROM ORDERS and choose one for your design to answer. The two Starter jobs sit at the top until you deliver them.
- Each order shows its budget against the cheapest honest build: green is generous, amber tight, red unrealistic.
- Bigger orders open as your standing with a client grows.
# Quote and sign
- With the design answering the order, SEND QUOTE. The client signs off at the quoted price and pays the deposit.
- CONTRACT DETAILS shows every payment: what sets it off, when it is due and what is paid.
# Build and trial
- Later stages pay as the build reaches them.
- DELIVER FOR TRIAL sends her to the surveyors. Each demand beaten earns a bonus; each one missed holds back part of the last payment, and late delivery costs too.
- Delivering to spec raises your standing with that client.
> The Contract fit tab on the wrist scores the open design against its order, area by area, with what to change."""},
	{"id": "parts", "order": 60, "title": "Parts, stock and suppliers", "text": """# Buying
- The Parts market tab prices the open design's parts list at every vendor, with this week's deals, waits and your standing with each.
- Its optimiser offers three ways to buy: cheapest, most reliable and median cost.
# Deliveries and the stores
- Haulers dock at the east of the stores hall. Bots carry each load from goods in to a rack place.
- The Warehouse stock tab shows everything held: count, places, value, weight, what is on the way in and what the open design is still short of. Click a part to light its bays on the hall map.
- Bots take parts out to the yard side for the build berth. {key:yard.kit} calls a mover bot with the next kit.
# Second-hand parts
- Used parts go to the refurb works, where refurbishers inspect, strip, clean, rebuild and test them, then certify them at Standard grade. A cracked casing is scrapped."""},
	{"id": "bots", "order": 70, "title": "Bots and TartanCo", "text": """TartanCo supplies the yard's worker bots: builders, movers, refurbishers and the rest.
- The TartanCo fleet tab lists every bot: what it is doing, its condition and any faults.
- Bots wear as they work. Past 40% wear they slow down; at 75% TartanCo is called and their service ship comes to put them right.
- Group bots and give each group a priority and tasks from the build plan. The bots don't follow these orders yet; this is groundwork for automatic building.
- Better marks of bot with more module slots come with TartanCo's upgrades."""},
	{"id": "money", "order": 80, "title": "Money and accounts", "text": """- The company's cash is at the top right of the wrist screen.
- The Accounts tab has the full books: cash in and out, what is owed and due, and a forecast of the cash to come from staged ship payments.
- Each day closes at midnight: rent, wages, the market moves and payments fall due.
- Every player has a wallet too. Send money from the Crew tab."""},
	{"id": "time", "order": 85, "title": "Game time", "text": """The company's calendar drives everything dated: deliveries, payment stages, due days.
- Change the pace in Esc > Settings > Gameplay > Game time: paused, half, normal, double or four times.
- Skip to a later date there too. Every day in between closes as it would (rent, wages, deliveries, payments), but work the bots have under way does not jump ahead, so use a faster pace while they work.
- In a shared game the host sets the pace for everyone."""},
	{"id": "together", "order": 88, "title": "Playing together", "text": """- Play Online on the main menu: host a yard or join a friend's.
- The Crew tab lists who is here and their wallets.
- Ping a spot with the middle mouse button (or {key:graphics.ping}) to show the crew where you mean.
- In the design room everyone works on the same design and sees each other's edits."""},
	{"id": "wrist", "order": 95, "title": "This wrist screen", "text": """{key:holo} brings it up anywhere in the yard; click a tab for another screen.
- Warehouse stock: what the stores hold, where, and what the open design is short of.
- Parts market: prices from every vendor and the best ways to buy.
- Contract fit: how the open design meets its order, and what to change.
- Accounts: the company's books and cash forecast.
- Crew and TartanCo fleet: the people and the bots.
- Help: these pages. Type in the search box to find a word in any of them.
> Most of these tabs also go up on the design room's walls."""},
]
