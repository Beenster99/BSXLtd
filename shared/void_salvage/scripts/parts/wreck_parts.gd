class_name WreckParts
extends RefCounted
## Fitted parts for derelict designs (0.19 additions to the parts library), drawn from the
## reference ships in docs/SHIP_REFERENCES.md. Like PartShapes: each returns a PartShape
## (vertex-coloured mesh, convex collision, volume), centred on the origin, metres. Round
## things run along Y (turn them to point where you need).
##
##   ducted_fan    a banded duct with a bright flared lip (bolt ring), a dark bore, blades
##                 round a hub and spinner, stator vanes aft (intake +Y; lift fans, intakes)
##   tank          a cylinder tank with domed ends, end bosses, weld seams, two buckled
##                 straps and a maker's plate (hydrogen, oxygen)
##   drill_head    a mining drill: a body drum with a hazard band and a bolted flange, a dark
##                 stepped cone with small carbide teeth on each step
##   thruster_grid a chamfered block on a mount flange, a dark waist band, a status bezel
##                 with two lamps (-Z), a dark face plate with bolts and a hollow bell per
##                 cell with a bright lip round a glowing floor (+Y)
##   solar_panel   a framed panel with a hinge edge (-Z), cells with busbars on top (+Y)
##   landing_leg   a strut leg: a bolted hip block with an amber lamp, sleeved struts with
##                 chrome rods, a pinned knee, a side ram, a ball ankle and an eight-sided pad
##                 with a hazard rim (stands on -Y)
##   engine_bell   a big main engine: bolted plate, ribbed housing with fuel feeds and a heat-
##                 shield band, a bolted gimbal collar, a hollow ringed bell with a rolled
##                 lip and a glowing injector floor (exhaust to +Y)
##   fin           a swept fin (root along Z at y = 0, rising in +Y): a capped leading
##                 wedge, a tapered trailing lip, bolted root doublers with a rubber root seal,
##                 panel lines and a red nav lamp under a lens at the tip
##   container     a cargo container: corrugated walls and roof, corner castings, a door
##                 end at +Z with two leaves, lock bars, hinges and an enamel data plate
##   antenna       a mast with collars and a ribbed dish, a feed horn over it on struts and a
##                 red aviation light at the tip (comms, sensors)
##   turret        a gun turret: a bolted ring with a dark race, an angular housing with
##                 cheek armour, a sight block with a lit lens, two barrels with sleeves and
##                 slotted brakes out of a bolted mantlet (-Z) through ribbed rubber boots
##   ion_thruster  a chamfered square housing with corner bolts, side fins and a status
##                 panel, a hollow stepped nozzle with an ion grid over a glowing floor (+Y):
##                 the small blue thrusters of SE2-style ships, in any size
##   headlamp_bar  a housing on a bolted foot with recessed lamps (reflector, lit lens)
##                 under a visor (lit face +Y): bow headlights
##   pipe          a straight pipe along Y with a forged weld-neck flange at each end and a
##                 galvanised clamp band on a rubber liner
##   pipe_elbow    a 90 degree pipe bend: in along -Y, out toward +Z, bolted flanges
##   pipe_tee      a short flanged pipe run along Y with a flanged, bolted branch stub out of
##                 its -Z side over a welded saddle (sits in a pipe run between two spans)
##   loom_bend     a wiring loom turning a rounded corner (90 degrees unless `turn` says;
##                 +Y in, toward +Z out): clip
##                 straps with buckles at its ends and a cable tie mid-turn
##   junction_box  a wall or deck box: a bevelled lid with corner screws, a hazard tab and a
##                 status lamp (front -Z), three cable glands on top (+Y), the middle one
##                 taking the loom drop
##   grating       a deck grating: a frame round bearing and cross bars over a dark plate (+Y)
##   generator     a power plant on skids on rubber pads: fin packs, an intake grille, a
##                 bolted end flange with a coupling hub and a lit five-segment status strip
##   switch_cabinet a breaker cabinet: hinged door, louvre, handle, a guarded lever on its
##                 front (-Z) and two indicator lamps
##   battery_rack  a braced rack of battery cells: red and copper terminals, straps, a
##                 charge lamp per cell
## Interior fittings (stand on -Y, front facing -Z):
##   console       a desk on a kick plinth: keyboard shelf, bezelled screens on the sloped
##                 face (lit) and status lights
##   seat          a padded seat with bolsters, headrest and armrests on a bolted pedestal
##   bunk          a two-high bunk: posts on rubber feet, railed decks, mattresses with
##                 pillows and blankets, guard rails up top, ladder rungs at the foot (+Z)
##   table         a table on a pedestal: chamfered top with a dark bumper band, steel
##                 mounting plate, eight-sided pedestal, bolted foot plate
##   locker        a tall locker: two louvred doors with hinges, handles, a lock and name
##                 plates, on a recessed plinth
##   bench         a lounge sofa: kick plinth, slim arms, sectioned chamfered seat and back
##                 cushions, a trim rail along the back (cushion colour yours)
##   bar_counter   a bar: kick plinth, panelled front, bevelled overhanging top with a trim
##                 band and a lit strip under it, footrail on brackets, back shelf (+Z)
##   stool         a bar stool: base disc, steel column with a foot ring, padded seat
##   toilet        a toilet: oval bowl, seat seam, closed lid, cistern with a flush plate,
##                 bolted floor plate
##   basin         a vanity basin: hollow bowl, plughole, steel tap, two doors below
##   portal_jamb   a door post: chamfered, a dark kick block, a steel head cap, hazard bands
##                 and bolts on both faces, a lit strip on its inner face (+X); portal_lintel
##                 the bar over the top with its lower corners cut, raised panels, bolts and a
##                 lit strip facing down: a lit doorway round a bulkhead's opening
##                 (WreckInterior.portal places all three)
##   armchair      a blocky lounge armchair: cut-edged arms and back, chamfered cushions, a
##                 head pillow and arm pads (the liner's passenger lounge)
##   hatch_door    a closed airlock door leaf: chamfered, bolted bands, green lit edges in dark
##                 channels, a window, a D-handle, a keypad with a lock lamp, a hazard foot
##                 (stands in a side door)
##   docking_port  a yellow docking collar with a hazard band, guide pins and latches round
##                 an iris hatch, a bolted plate with two status lamps (+Y out), for bellies
## Arinox parts (0.25):
##   thruster_pod  a twin-nozzle main engine: a banded stadium housing on a bolted flange,
##                 panels, lamps and fuel feeds on its sides, a pale cowl with two hollow
##                 nozzles glowing deep inside in its +Y face (the Arinox's stern pods)
##   light_strip   a thin channel along X with end caps and lit cells under a frosted diffuser
##                 on its top (+Y): cyan trim lines on hulls
##   reactor       a drum on a chamfered bolted plinth: bolted flanges, a hazard check band,
##                 ribs, clamp bands, a mullioned waist window with lit slots, a lit gauge
##                 strip and flanged pipe stubs on a stepped cap (stands on -Y)
##   machine_unit  an industrial cabinet (refinery, assembler, gas generator): a collared
##                 hopper and feed pipes on top, a control panel with a lit screen and LEDs,
##                 a hinged service door, louvred sides (front -Z)
##   railing       a handrail along X: round posts on bolted flanges, round top and mid
##                 rails, a clamped dark kick plate with hazard bars
##   shelf_rack    open shelves on slotted uprights with braces and orange beams, coloured
##                 crates on them (front -Z)
##   ladder        two rails and rungs with grip strips, rubber feet and stand-off brackets
##                 (+Z), standing on -Y, rungs facing -Z
## Second decks (0.27):
##   stair         a flight of steps: two stringers, grooved treads with yellow nosings and
##                 lit strips, risers, climbing toward -Z
##                 (base on -Y, top edge at -Z; WreckInterior.stair stands one between decks)
## Escape pod parts (0.31, the block at the end of this file):
##   crash_seat    a tall jump seat: bolted pedestal, padded seat pan and backrest, a
##                 winged headrest, shoulder straps and a buckle (stands on -Y, faces -Z)
##   grab_bar      a C-shaped handrail along Y: knuckled bends, a rubber grip with ferrules,
##                 collars on bolted plates (mounts at +Z, faces -Z)
##   landing_clamp an SE2-style landing gear: bolted base, hinge and two hydraulic rams, a
##                 yellow magnetic pad with a slanted hazard border (pad face +Y)
##   survival_locker a white emergency locker: three hinged doors, a red cross, a lit
##                 status lamp, a hazard band (front -Z)
## Lander parts (0.32, the block at the end of this file):
##   cargo_crate   an SE2-style small cargo container: corner castings, ribs, a yellow-
##                 framed hatch with a lever (-Z) and a green lock lamp
##   cargo_ramp    a closed cargo ramp leaf: side rails, a striped hazard border, a toe strip,
##                 treads and a pinned hinge on its outer face (+Z)
##   shower        a round shower cubicle: tray, cap with vents, a curved door between
##                 jambs on rubber seals, a vision strip, handle, lit occupied lamp and control
##                 panel (-Z)
## Cargo shuttle parts (0.33, the block at the end of this file):
##   bed_alcove    a bed set into a wall niche: shell open at the front (-Z) with trim,
##                 drawers in the base, bedding and headboard, a canopy shelf in tall niches,
##                 two green ring lights at the head end
##   survival_kit  an SE2-style survival kit: dark cabinet, screen on an arm, yellow-framed
##                 hatch, vents, status lamps, gas canisters at its foot (front -Z)
##   container_hatch the yellow-framed service hatch of a built-in cargo container: corner
##                 castings, a label plate, a recessed leaf with bars, hinges, a lever and a
##                 green lock lamp (face -Z, back +Z against a wall)
## Courier parts (0.34, the block at the end of this file):
##   grinder_head  twin segmented saw discs on an axle along Y under a guard, a gearbox and a
##                 ribbed motor with a fan grille and a lit lamp on its +Y end, two hoses
##                 back toward +Z (the courier's swappable bow grinders)
##   lattice_rail  an open frame along X: channel chords, posts, gussets and diagonal braces
##                 on standoff brackets with wall plates (face -Z, brackets to +Z)
##   canister_pack round gas canisters with valves, handwheels and straps on a railed dark
##                 back plate behind a retaining bar (face -Z)
## Cargo runner parts (0.35, the block at the end of this file):
##   heat_sink     radiator fins on a bevelled bolted back plate, steel fin lips, copper
##                 coolant headers with flanges and end risers (back +Z, fins to -Z)
##   nozzle_cluster small hollow round nozzles with glowing floors in a row on a bolted
##                 block with a fuel manifold (exhaust +Y)
##   conveyor_tube a square SE2 conveyor tube along Y: corner rails, end collars, bolted
##                 clamp bands, access panels and flow arrows (+Y)
##   conveyor_junction a conveyor junction cube: corner blocks, a bolted port on every face,
##                 small lit status lamps on its sides
##   gyroscope     an open frame cube with bolted corner castings, a banded drum on bearings
##                 and lit rings (stands on -Y)
## Executive shuttle parts (0.36, the block at the end of this file):
##   button_panel  an SE2 control panel bank: chamfered white housing, dark face with lit
##                 ring buttons and small screens with lit readouts (face -Z, back +Z)
##   double_bed    a double bed: dark plinth, frame with side drawers, a headboard with padded
##                 panels at +Z, made-up mattress, duvet with a turn-down, a blue throw and
##                 bolster, pillows (stands on -Y)
## Yacht parts (0.37, the block at the end of this file):
##   media_wall    a lounge wall unit: framed wood-panel tiles, a dark bezelled screen with a
##                 faint glow, a soundbar, speaker columns, shelves with books, a low cabinet
##                 with doors (face -Z, back +Z against a wall)
##   galley_counter a kitchen counter along X: drawers over doors, a grey top with a steel-
##                 rimmed sink, tap and a cooktop (lit rings), a range hood, a shelf with
##                 canisters, a coffee machine and a screen (lit) (front -Z, stands on -Y)
##   med_bed       a medical bed along Z on a column over a bolted plate, guard rails, a scanner
##                 arch over its middle (a glowing strip under it) and a lit screen on a jointed
##                 post at the head (stands on -Y)
## Armoured transport parts (0.38, the block at the end of this file):
##   hover_drum    a landing thruster under a belly: a bolted mount plate on top (+Y), two
##                 banded drums with a bolted flange, copper feed pipes, a flared nozzle with
##                 a bright lip, a ceramic throat and a glowing ring (exhaust -Y)
##   seat_row      a row of padded passenger seats along X on a beam over bolted pedestals:
##                 steel shells, chamfered cushions, padded armrests (stands on -Y, faces -Z)
##   lit_post      a square hall pillar with chamfered corners, bolted foot and capital
##                 collars, a railed dark channel down its -Z face with a three-segment lit
##                 strip (stands on -Y)
## Scoop miner parts (0.39, the block at the end of this file):
##   bore_drill    an SE2 large mining drill: a chamfered bolted housing with hazard bands,
##                 gearbox covers, hoses and an amber lamp, a bolted collar with coolant
##                 nozzles, a dark crown with two flights and rings of picks (bit toward +Y)
##   ore_hatch     a roof hatch: a dark slatted plate with a pull handle in a raised,
##                 bevelled, bolted yellow frame, hinge knuckles (+Z), latch dogs and a lit
##                 lamp (-Z) (face +Y)
##   cup_thruster  a round thruster on a bolted square plate: banded drum, stepped pale
##                 lip, a hollow throat to a glowing floor (exhaust +Y)
##   ore_bin       an open-topped ore skip on skids: corner posts, ribs, a belt, a slide gate
##                 (-Z), a yellow rim with hazard bars, a heap of ore (stands on -Y)
## Mantis fighter parts (0.40, the block at the end of this file):
##   gatling_gun   a rotary cannon: a chamfered breech housing with a feed chute and lit
##                 ready lamps, a banded drum, six barrels in hex clamps (muzzle toward +Y)
##   octagon_thruster a main engine in a deep banded octagonal housing on a bolted flange:
##                 pale rim, dark recess, two hollow nozzles with glowing floors (exhaust +Y)
##   stud_lights   a row of domed lit lenses in gasketed bezels on a dark rail along X, bolted
##                 end caps (lenses on +Y)
## Pod scout parts (0.41, the block at the end of this file):
##   stick_seat    a fighter pilot's seat: padded, harnessed, armrests with a booted flight
##                 stick and a status lamp on each (stands on -Y, faces -Z)
##   grille_drum   a round unit with a slatted grille (carrier bars, bright lip) in its +Y
##                 face, clamp bands, a bolted foot ring, on a bolted plate with cheeks and
##                 pivot bosses (-Y): intakes and small atmospheric thrusters
##   roof_hatch    a small square roof hatch: bolted coaming, dark gasket, bevelled lid with a
##                 hand wheel and a yellow latch, knuckle hinge at +Z (face +Y)
## Dagger frigate parts (0.42, the block at the end of this file):
##   twin_turret   a heavy turret: a bolted base ring, a faceted housing with cheek armour
##                 and a sloped glacis, an ammo bustle with a hazard tab, a visored sight with
##                 lit lenses, a hatch, two barrels with sleeves and slotted brakes (-Z)
##   dome_turret   a small turret: a bolted ring, a faceted dome with a dark band, a sensor
##                 head with lit lenses on its crown, one barrel with a slotted brake (-Z)
##   spinal_gun    a heavy segmented gun barrel along Y: bolted base flange, chamfered
##                 octagonal sleeves with vents and bolts, dark rings with amber charge lamps,
##                 a clamped conduit down each side, a slotted muzzle brake at +Y
##   mess_table    a thick table top with a steel trim band on a dark ribbed plinth with a
##                 kick recess, on a bolted pale floor plate (stands on -Y)
##   gravity_generator an SE2 gravity generator: a chamfered plinth with lit status slots,
##                 braced corner posts and a vented top frame round a glowing core between
##                 banded rings on arms, copper-coiled pedestals above and below (stands on -Y)
## Ranger parts (0.43, the block at the end of this file):
##   hydrogen_engine an SE2 hydrogen thruster: mount plate, ribbed drum with fuel feeds and
##                 a heat-shield band, a bolted dark rim round a pale liner narrowing to an
##                 injector ring and a glowing floor (exhaust +Y)
##   workbench     a workshop bench: drawer cabinet, steel top with a vise, undershelf with a
##                 toolbox, a framed tool board with tools and a lit shelf (front -Z, on -Y)
## Talon parts (0.44, the block at the end of this file):
##   talon_intake  the scoop in a raked pod tip: a bolted rim with a bright inner lip round a
##                 dark trough, two round thruster discs with stator vanes in its floor (face +Y)
##   oval_engine   a main engine in a banded stadium-shaped housing on a bolted flange: pale
##                 rim, dark recess, two hollow nozzles with hubs and glowing rings (exhaust +Y)
##   spoiler_wing  a flat stern wing along X with red edge trim, up-turned red end fins with
##                 bright caps and lensed nav lamps, a flap hinge line with actuator fairings,
##                 panel lines and a lit strip along its trailing edge (base on -Y)
## Claymore parts (0.45, the block at the end of this file):
##   bomb_rack     eight-sided bombs (fuse tip, yellow nose band, cross fins) lying along Z in
##                 columns and rows on a cradle: end frames, rails, cross bars and saddle
##                 pads, a base plate (stands on -Y): bomb bay payload and wall stowage
##   ribbed_spine  a dorsal keel along Z: a chamfered bar tapering to a point at +Z with dark
##                 ribs, a ridge cap, foot doublers, a bolted front plate and a red beacon lens
##                 (base on -Y)
##   cannon_maw    a heavy frontal cannon: a bolted mount plate, an octagonal housing with
##                 vents and a heat band, a bolted rim round a recessed face with a ring of
##                 collared barrels glowing red inside and lit slits between them (+Y)
##   cell_cage     a barred cage locker: posts, frames, bars, a barred door on hinges with a
##                 kick plate, lock box and handle; rifles in a rack and ammo cans inside
##                 (stands on -Y, front -Z)
## Geo Golem parts (0.46, the block at the end of this file):
##   cutter_drum   a heavy drill: bolted mount plate, orange octagonal housing with a hazard
##                 band, gearbox covers, hoses and lamps, a ribbed sleeve, a steel drum with
##                 spiral flights of picks, a toothed front face with a coolant ring and a
##                 pointed hub (bit toward +Y)
##   lift_car      a lift car: dark floor with tread bars and a hazard edge, corner posts,
##                 roof with a lamp, kick plates, a braced back panel with a handrail, a call
##                 panel with a glazed screen and buttons, a light strip (stands on -Y, open
##                 front -Z)
##   detector_head a rotating ore detector: bolted rotor base, slewing ring, collared post,
##                 six-sided head with a lit eye in a dark bezel (-Z), back vents, a capped mast
##   med_station   a wall medical station: a screen with a glowing heart trace in a pale
##                 frame, a green sign with a white cross, gas panels with gauges, two
##                 cabinets under a worktop (front -Z, back +Z on a wall)
## Superhawk parts (0.47, the block at the end of this file):
##   rail_turret   the roof gun: bolted mount plate, traverse ring, an angular housing with
##                 cheeks, vents, a hazard tab, a sight lens and a hatch, tapered posts with
##                 saddle clamps under a twin-rail barrel along Z with lit coil collars, a
##                 baffled brake at -Z, an orange band and a breech with ready lamps and a cable
##   planter       a hydroponics trough on legs over a nutrient tank and pump: soil, leafy and
##                 fruiting plants, a grow-light housing with pink lit strips (on -Y, along X)
##   hazard_band   a thin panel with slanted stripes on its -Z face inside a raised steel
##                 border with bolts, stripes cut square at the ends (back +Z)
## Pioneer parts (0.48, the block at the end of this file):
##   turbine_engine a big ducted engine: a seamed, banded drum on a bracketed mount collar, a
##                 rolled pale lip with a bolt ring, twisted blades in a fan case set back in
##                 it and a glowing ring round the spinner (exhaust +Y)
##   roof_hood     a raised white vent hood on a foot flange: panel seams, bolted side
##                 plates, a V-shaped chevron on top and a framed mesh intake at -Z (base -Y)
##   lever_stand   tall control levers in a row along X: a gated quadrant housing, rubber
##                 gaiters, grip bands, red knobs, scale plates and amber lamps (on -Y)
## K1 miner parts (0.49, the block at the end of this file):
##   pod_boom      a long chamfered top beam along Z: dark seams, bolted side access panels,
##                 foot strips, yellow-green trim lines along its top edges, bolted end collars
##                 (base on -Y)
##   armour_cowl   a yellow armour block whose top slopes down toward -Z, bevelled edges,
##                 panel grooves and bolts along its sides, a slatted vent on top, a hazard tab
##                 on the slope (base on -Y, back +Z)
##   octo_tank     an SE2 large hydrogen tank: an octagonal body along Y with steel corner
##                 rails, two-facet end caps with weld beads and bolted stepped valve bosses,
##                 three dark straps with tensioners, a weld seam and a riveted label plate (+Z)
## Iridium miner parts (0.50, the block at the end of this file):
##   spike_drill   a round drill head: chamfered housing with a hazard band, hoses and an amber
##                 lamp, a bolted collar with coolant nozzles, a ball studded with rings of
##                 chunky teeth on holders (bit toward +Y)
##   connector_ring an SE2 connector: square dark base, a thick collar in its own colour with
##                 a gold rim and latch housings, a dark recessed face with four clamp jaws,
##                 a contact boss and a status light (+Y)
## Forge welder parts (0.58, the block at the end of this file):
##   ship_welder   an SE2 large welder: a mount plate and square drive housing (-Y) with
##                 louvres, panels and lit LEDs, a tapering body with dark bands, a yellow
##                 ring and hoses, a head frame with four pinned, ram-driven claws round a
##                 finned emitter, two glowing arcs crossing in an X between the claw tips (+Y)
##   name_board    a ship's name sign: a chamfered dark board with bolted frame strips, raised
##                 pale block letters along X, framed slatted vents at both ends and white
##                 edge lights in channels (face +Y, letters' tops toward -Z)
## Drill miner parts (0.59, the block at the end of this file):
##   louvre_panel  a big slatted service panel (the grey grille down the N-M1's flank): a
##                 bevelled pale frame ringed with bolts round a dark recess, two columns of
##                 angled slats on carrier rails, a centre mullion, a yellow warning tab
##                 (face +Y, X along the hull)
## Hex-drive cruiser parts (0.60, the block at the end of this file):
##   searchlight   a big round headlight on a gimbal yoke: a drum on a bolted dark flange,
##                 dark bands, a bright rim round a reflector bowl and a glowing lens with
##                 dark slats across the mouth (light out of +Y)
##   long_cannon   a roof gun: a bolted turret ring under an angular housing, trunnions, a
##                 dark breech drum, recoil buffers and a long barrel toward -Z with two
##                 sleeves, a slotted muzzle brake and a lit lamp
##   (name_board also draws digits and a dash now: registration numbers)
## Mule hauler parts (v2 rebuild, the block at the end of this file):
##   banded_tank   a big lying hydrogen tank: round body with welded rounded shoulders, dark
##                 flat end flanges with rim bolts, a bolted clamp collar, a thin band, crown
##                 straps with clamps round a bolted valve boss (-Z), a seam and a maker's plate
##   nose_probe    a sensor rod: a bolted dark mount, a shouldered housing with strakes and a
##                 bright collar, a thin rod with collars, a sensor sleeve and a red lit tip (+Y)
##   rock_wheel    a toothed rock wheel (axle along X, bit -Z) on a dark fork: bolted side
##                 discs, motor bosses with hoses, cheek lamps, a hazard-topped cross bar
##                 with a spray bar, a bolted mount plate (+Z)
##   ore_detector  a big ore detector: an octagonal plinth with a skirt and bolts, a ribbed
##                 steel drum with a bright rim and top spokes, a bolted hub with a lit ring
##   drill_arm     a chamfered boxy arm along Z: bolted dark bands, hazard ends, chevron side
##                 panels, a skid plate, two hydraulic rams with hoses on top, lit front (-Z)
## Bay freighter parts (v2 rebuild, the block at the end of this file):
##   piston_gear   an SE2 landing gear on a piston: bolted mount plate, banded dark cylinder
##                 with a hose, sealed chrome rod, pinned clevis and a raked sled foot with
##                 hazard stripes and a red lit band (stands on -Y)
##   lift_platform a personnel lift platform: white slab with a bumper band, tread bars and a
##                 hazard end, a bolted dark piston socket at +X, toe boards, tubular railings
##                 along both long sides, a capped control post with a lit screen (-Y)
## Corsair frigate parts (v2 rebuild, the block at the end of this file):
##   bunk_rack     a three-high crew bunk rack: corner posts on feet, slatted trays with berth
##                 plates, mattresses, pillows and blankets, a ladder up one end (on -Y, along Z)
##   refill_station a white suit refill unit for a wall: hinged lower door, sloped upper
##                 front with a bezelled recess, a glowing ring round a nozzle, a lit screen
##                 and LEDs (front -Z)
##   reactor_core  a reactor housing: framed cabinet on bolted posts, a bolted round window
##                 with guard bars and the core glowing behind it, a hazard band, lamps, side
##                 louvres and access panels, a cowl with a lit gauge strip (front -Z)
##   (name_board also draws C, M and S now: "CMS-01A")
## Ship carrier parts (v2 rebuild, the block at the end of this file):
##   landing_pad   a roof landing pad on four short legs with bolted feet: a pale slab with a
##                 yellow border checkered dark, an aiming circle, tie-down rings, a caged
##                 beacon in the middle and lights at the corners (stands on -Y, X across
##                 the ship)
##   (name_board also draws P now: "PORPOISE")
## Endeavor parts (v2, the block at the end of this file):
##   fin_blade     a triangular armour fin: a blade rising to its aft end, pale caps along the
##                 slope and the aft edge, bolted dark inset panels on both faces, bolted foot
##                 doublers with a rubber root seal and a red lensed nav lamp at the top (stands
##                 on -Y, along Z)
##   spoke_beam    a gravity-ring spoke: a flanged box girder along X with lipped octagonal
##                 lightening holes, stiffeners and end plates, a grating tread on top and a
##                 cable tray on hangers down its +Z side
##   sleep_pod     a crew sleep pod: a pale capsule on a kick plinth, bumper band and rim lip,
##                 bedding, a glass canopy hinged at the foot, a lit status strip and a screen
##                 facing the sleeper (stands on -Y, along Z)
## Novaris parts (v2, the block at the end of this file):
##   shingle_panel a patch of the Novaris' scaled armour: rows of overlapping tiles across
##                 X on a dark backing plate, each tile's aft (+Z) lip standing proud and
##                 bevelled, a rivet in its front, the rows' seams staggered, an optional
##                 trim-coloured outer column (face +Y)
##   corner_sofa   an L-shaped lounge sofa: a run along X and a return along Z at its +X end,
##                 plinth, trim-railed backs, end arms, chamfered cushions, a corner pillow
##                 (stands on -Y, seats facing -Z and -X)
##   (name_board also draws V now: "NOVARIS")
## Race carrier parts (v2, the block at the end of this file):
##   garage_door   a big hull door leaf (the Nexus' numbered garage doors, slid up over the
##                 roof when open): a pale slab with raised panel seams, a bolted dark rim,
##                 roller brackets, a purple band and a hazard band, big raised digits, a pull
##                 handle and lamps along the top edge (face +Y, X along the hull, the digits'
##                 tops toward -Z)
##   racer_hull    a parked race ship's body: a low chined wedge from a pointed nose to a
##                 broad tail, panel lines and red livery stripes, a framed glass bubble
##                 canopy, flank scoops with grilles, a barred glowing exhaust slot in its
##                 tail and running lights (stands on -Y, nose -Z)
##   (name_board also draws D and K now: "DARKSPOT")
## Railgun ship parts (v2, the block at the end of this file):
##   rail_barrel   a length of railgun barrel along Y: a dark core, two chamfered rails with
##                 copper strips along the bore slot, a seamed cover, clamp bolts, octagonal
##                 coil collars with bolts and lit blue windows, a bolted end flange each end
##   rail_muzzle   the railgun's muzzle: a tapering octagonal housing on a bolted flange, a
##                 dark waist band, armour panels, vent slats and red side lamps, a dark rim
##                 round a recessed face, a hex collar with a red glow round the bore, guide
##                 vanes (+Y)
##   capacitor_bank a dark frame on a hazard-striped plinth holding two rows of capacitor cans
##                 with glowing blue bands, terminals and bus bars, retaining straps, a copper
##                 terminal bar, a high-voltage plate, louvres and a lit status panel
## Cruiser parts (v2, the block at the end of this file):
##   naval_turret  a heavy twin gun: bolted octagonal barbette, a long angular gun house with
##                 cheek armour, a bolted mantlet, rear vents and red lamps, a sight lens, hatch
##                 and rangefinder on the roof, two square barrels from blast boots in angular
##                 shrouds with clamp bands and slotted muzzles (-Z)
##   missile_launcher an armoured launcher box: a bevelled bolted frame round hollow tube
##                 collars with red-glowing warhead cones (-Z), hinged roof hatches, bolted
##                 side panels over hazard stripes, a rear louvre and red ready lamps (-Y)
##   radiator_grille a pale bolted frame with a bevelled edge round raked fins on steel ribs,
##                 a red glow between them (+Y)
##   armour_slab   layered armour: raised tiles with bevelled, nicked edges and dark seams,
##                 rows staggered, corners cut on the diagonal, corner bolts, a stencil tab,
##                 on a dark backing plate (+Y)
## Destroyer parts (v2, the block at the end of this file):
##   missile_silo  an armoured belly box with chamfered lower edges and vents in them, bolted
##                 side and end panels, an octagonal launch hatch in its underside (hazard
##                 ring, bolted red rim, pale faceted lid, centre boss) and red-lit lamp slots
##                 either side (mounts on +Y, hatch -Y)
##   rover         a six-wheeled ground rover: treaded wheels on A-arms and coil-overs under
##                 arched fenders, a cab with a raked dark windscreen at -Z, mirrors and lit
##                 headlamps, a ribbed cargo bed with a spare wheel, a lit roof lamp bar (-Y)
## Frigate parts (v2, the Sentinel; the block at the end of this file):
##   copper_vent   a long heat vent in a hull flank: a bolted pale frame with cut corners and
##                 a heat-tinted bevel round a dark recess holding a row of round copper slats
##                 on steel rails, glowing orange between them (face +Y, X along the hull)
##   case_stack    hard cases stacked in a wall frame: chamfered black shells with corner
##                 guards, lid seams, latches, a handle, ribs and hazard tabs, a retaining bar
##                 under each (stands on -Y, front -Z)
##   (name_board also draws L now: "SENTINAL")

const DETAIL := PartShapes.DETAIL
const DARK := Color(0.16, 0.16, 0.17)
const GLOWING := Color(1.0, 0.55, 0.2)
# Finish zones: a colour's alpha carries a SurfaceFinish code (SurfaceZones.<FINISH>_A), so
# the salvage surface draws that area as that finish: chrome, anodised alloy, ribbed rubber,
# leather, glazed ceramic, solar silicon... instead of the part's own paint. A colour with no
# code (DARK, Color.WHITE) is paint in the part's material. Never scale a zoned colour
# (c * 0.9 scales the code too): add a constant. Finish usage per part:
# scripts/debug/finish_report.gd; the batch pass: .claude/skills/surface-parts.
# --- Metals --------------------------------------------------------------------------------
const TRIM := Color(0.82, 0.84, 0.86, SurfaceZones.POLISHED_A)        # bright polished lips, bezels, end caps
const REFLECTOR := Color(0.88, 0.89, 0.9, SurfaceZones.CHROME_A)      # chrome lamp reflector bowls
const CHROME := Color(0.88, 0.88, 0.9, SurfaceZones.CHROME_A)         # chrome rods, pins, handles
const STAINLESS := Color(0.72, 0.73, 0.74, SurfaceZones.STAINLESS_A)  # stainless counters, sinks, hoods
const ANODISED := Color(0.52, 0.54, 0.57, SurfaceZones.ANODISED_A)    # anodised alloy frames, rails, fins
const GALVANISED := Color(0.64, 0.66, 0.68, SurfaceZones.GALVANISED_A) # galvanised shelves, straps, brackets
const CAST := Color(0.3, 0.3, 0.31, SurfaceZones.CAST_IRON_A)         # cast iron housings, hubs, vises
const BRASS := Color(0.76, 0.6, 0.3, SurfaceZones.BRASS_A)            # brass valves and fittings
const GUNMETAL := Color(0.26, 0.27, 0.3, SurfaceZones.GUNMETAL_A)     # gun bores, dark machined metal
const RIM := Color(0.3, 0.31, 0.33, SurfaceZones.BLUED_A)             # dark heat-blued engine rims
const HEAT_SHIELD := Color(0.5, 0.44, 0.38, SurfaceZones.HEAT_A)      # heat-tinted shield bands
const COPPER := Color(0.85, 0.6, 0.25, SurfaceZones.COPPER_A)         # bare copper terminals and straps
const GOLD := Color(0.85, 0.62, 0.16, SurfaceZones.GOLD_A)
const BENCH_STEEL := Color(0.62, 0.63, 0.64, SurfaceZones.BARE_A)
const GUN_STEEL := Color(0.5, 0.51, 0.53, SurfaceZones.BARE_A)        # the bare barrels
const BANK_FRAME := Color(0.3, 0.31, 0.33, SurfaceZones.GUNMETAL_A)   # gunmetal cabinet frame
const BENCH_VISE := Color(0.24, 0.3, 0.42, SurfaceZones.CAST_IRON_A)
const BOSS := Color(0.42, 0.43, 0.45, SurfaceZones.CAST_IRON_A)       # the motor bosses
const HUB := Color(0.3, 0.31, 0.33, SurfaceZones.CAST_IRON_A)         # hub caps
const COLLAR := Color(0.4, 0.41, 0.43, SurfaceZones.BRUSHED_STEEL_A)  # the collar
const FRAME_GREY := Color(0.36, 0.37, 0.39, SurfaceZones.GALVANISED_A) # the head frame's bars
const COVER := Color(0.62, 0.63, 0.65, SurfaceZones.ANODISED_A)       # the pale bore cover strip
const SLEEVE_GREY := Color(0.62, 0.63, 0.65, SurfaceZones.ANODISED_A) # every other sleeve
const TOOTH_DARK := Color(0.3, 0.31, 0.33, SurfaceZones.CAST_IRON_A)  # the dark teeth
const GUN_BORE := Color(0.05, 0.05, 0.06, SurfaceZones.GUNMETAL_A)    # the bore's deep black
const RAIL_BORE := Color(0.05, 0.05, 0.06, SurfaceZones.GUNMETAL_A)   # the bore's deep black
const PLATE_DARK := Color(0.24, 0.25, 0.27, SurfaceZones.CAST_IRON_A) # the mount plate
const FLANGE_BOLT := Color(0.32, 0.33, 0.35, SurfaceZones.GUNMETAL_A) # blackened high-tensile flange bolts
const WELD_PAD := Color(0.5, 0.48, 0.5, SurfaceZones.BLUED_A)      # heat-tinted welded saddles and pads
const RAIL_DARK := Color(0.32, 0.33, 0.36, SurfaceZones.ANODISED_A) # dark anodised extrusions: conveyor rails, edge frames
const AERO_EDGE := Color(0.64, 0.67, 0.72, SurfaceZones.TITANIUM_A) # titanium leading edges, intake lips, ridge caps
const FURN_COLLAR := Color(0.6, 0.61, 0.63, SurfaceZones.BRUSHED_STEEL_A) # brushed steel collars, ribs and cap bands on furniture
const PNL_ARMOUR_BACK := Color(0.26, 0.27, 0.29, SurfaceZones.DENSE_CAST_A) # dense cast armour backing under shingle tiles
const PNL_MESH := Color(0.46, 0.47, 0.49, SurfaceZones.GALVANISED_A) # galvanised expanded-mesh grid bars
const WALK_CROSS_BAR := Color(0.58, 0.6, 0.62, SurfaceZones.GALVANISED_A) # darker galvanised cross bars, rungs and braces
const WPN_RIB_PALE := Color(0.68, 0.69, 0.71, SurfaceZones.ANODISED_A) # an ore detector's pale anodised drum ribs
const WPN_RIB_DARK := Color(0.42, 0.43, 0.45, SurfaceZones.ANODISED_A) # ... and the dark ones between them
const WPN_TIP := Color(0.62, 0.64, 0.7, SurfaceZones.TITANIUM_A)       # titanium sensor tips on probes
const WPN_BARREL := Color(0.36, 0.37, 0.4, SurfaceZones.GUNMETAL_A)    # machined gun barrels, a shade lighter than GUNMETAL
const WPN_BLUED := Color(0.4, 0.41, 0.45, SurfaceZones.BLUED_A)        # heat-blued clamps and plates at a gun's muzzle
const ENG_STATOR := Color(0.4, 0.41, 0.44, SurfaceZones.ANODISED_A) # dark anodised stator vanes
const ENG_ION_GRID := Color(0.58, 0.6, 0.66, SurfaceZones.TITANIUM_A) # titanium ion grids over a thruster's glow
const ENG_NOZZLE := Color(0.62, 0.57, 0.5, SurfaceZones.HEAT_A)      # heat-tinted nozzle rims and lips by the glow
const ENG_FRAME := Color(0.4, 0.41, 0.44, SurfaceZones.GUNMETAL_A)    # gunmetal machine frames (the gyroscope's cage)
const LIT_CLIP := Color(0.55, 0.56, 0.58, SurfaceZones.GALVANISED_A) # galvanised loom clip straps (the spans' strap tone)
const LIT_RAIL := Color(0.38, 0.39, 0.42, SurfaceZones.GUNMETAL_A)  # gunmetal stud-light rails, lifted to read on dark hulls
# --- Paints and enamels ---------------------------------------------------------------------
const PLATE := Color(0.8, 0.78, 0.7, SurfaceZones.ENAMEL_A)           # pale enamel name and maker's plates
const CHEVRON := Color(0.82, 0.83, 0.84, SurfaceZones.ENAMEL_A)       # the pale chevrons on the side panels
const POST := Color(0.78, 0.76, 0.7, SurfaceZones.ENAMEL_A)
const PANEL_GREY := Color(0.3, 0.31, 0.33, SurfaceZones.ENAMEL_A)     # gas panels' graphite enamel
const MED_GREEN := Color(0.12, 0.55, 0.32, SurfaceZones.ENAMEL_A)     # the medical sign's paint
const BAR_TOP := Color(0.86, 0.84, 0.78, SurfaceZones.CERAMIC_GLAZED_A)
const BENCH_BOARD := Color(0.72, 0.73, 0.74, SurfaceZones.ENAMEL_A)
const HAZARD_YELLOW := Color(0.92, 0.72, 0.12, SurfaceZones.HAZARD_PAINT_A)
const PAD_YELLOW := Color(0.92, 0.72, 0.12, SurfaceZones.HAZARD_PAINT_A)
const PORT_YELLOW := Color(0.95, 0.75, 0.15, SurfaceZones.HAZARD_PAINT_A)
const DOCK_YELLOW := Color(0.95, 0.72, 0.1, SurfaceZones.HAZARD_PAINT_A)
const HATCH_YELLOW := Color(0.95, 0.72, 0.12, SurfaceZones.HAZARD_PAINT_A) # painted hatch frame
const CLAW_YELLOW := Color(0.92, 0.72, 0.12, SurfaceZones.HAZARD_PAINT_A) # the claws' shoes and the neck ring
const BOMB_BAND := Color(0.9, 0.72, 0.12, SurfaceZones.HAZARD_PAINT_A)
const LIVERY := Color(0.72, 0.1, 0.08, SurfaceZones.GLOSS_PAINT_A)    # the racer's red livery stripes
const BENCH_RED := Color(0.66, 0.17, 0.12, SurfaceZones.GLOSS_PAINT_A)
const HATCH_RED := Color(0.85, 0.16, 0.14, SurfaceZones.GLOSS_PAINT_A)
const CROSS_RED := Color(0.78, 0.1, 0.08, SurfaceZones.GLOSS_PAINT_A) # the emergency cross's paint
const STOP_RED := Color(0.75, 0.12, 0.1, SurfaceZones.GLOSS_PAINT_A)  # the motor's emergency stop tag
const HATCH_LEAF := Color(0.34, 0.35, 0.37, SurfaceZones.SATIN_PAINT_A)
const AMMO_GREEN := Color(0.34, 0.37, 0.28, SurfaceZones.SATIN_PAINT_A)
const BOMB_OLIVE := Color(0.36, 0.38, 0.34, SurfaceZones.SATIN_PAINT_A)
const MEDIA_SPINE := Color(0.36, 0.44, 0.52, SurfaceZones.METALLIC_PAINT_A)
const AERO_LIME := Color(0.78, 0.85, 0.2, SurfaceZones.ENAMEL_A)    # the K1 pod beams' yellow-green enamel trim lines
const FURN_PLINTH := Color(0.22, 0.23, 0.24, SurfaceZones.SATIN_PAINT_A) # graphite satin sheet-steel table plinths
const PNL_LIVERY_PURPLE := Color(0.36, 0.2, 0.62, SurfaceZones.GLOSS_PAINT_A) # the race carrier's purple livery band and digit
const PNL_LIVERY_WHITE := Color(0.92, 0.93, 0.94, SurfaceZones.GLOSS_PAINT_A) # gloss white livery digits
const PNL_SEAM_STRIP := Color(0.7, 0.71, 0.74, SurfaceZones.SATIN_PAINT_A) # satin-painted cover strips over panel seams
const WALK_FRAME := Color(0.2, 0.2, 0.22, SurfaceZones.SATIN_PAINT_A) # dark satin frames and stand-off brackets
const ENG_PANEL := Color(0.7, 0.71, 0.72, SurfaceZones.ENAMEL_A)    # pale grey enamel service panels on engines
# --- Plastics and rubber --------------------------------------------------------------------
const PLASTIC_DARK := Color(0.14, 0.14, 0.15, SurfaceZones.PLASTIC_TEXTURED_A) # housings, bezels, keyboards
const PLASTIC_PALE := Color(0.7, 0.7, 0.68, SurfaceZones.PLASTIC_A)   # keys, switch faces, pale casings
const RUBBER := Color(0.12, 0.12, 0.13, SurfaceZones.RUBBER_A)        # feet, seals, grips
const TREAD := Color(0.13, 0.13, 0.14, SurfaceZones.RUBBER_TREAD_A)   # ribbed soles, kick plates, mats
const CELL := Color(0.25, 0.27, 0.3, SurfaceZones.PLASTIC_TEXTURED_A) # battery cell casings
const TERMINAL_RED := Color(0.72, 0.16, 0.12, SurfaceZones.PLASTIC_GLOSS_A) # positive terminal caps
const LEVER_KNOB := Color(0.8, 0.1, 0.08, SurfaceZones.PLASTIC_GLOSS_A)
const CASE_RIB := Color(0.2, 0.2, 0.21, SurfaceZones.PLASTIC_TEXTURED_A)
const CASE_SHELL := Color(0.13, 0.13, 0.14, SurfaceZones.PLASTIC_TEXTURED_A)
const PLANTER_TANK := Color(0.3, 0.42, 0.5, SurfaceZones.PLASTIC_A)
const WINDOW := Color(0.05, 0.07, 0.05, SurfaceZones.PLASTIC_GLOSS_A) # painted-on dark window panes
const CARBON := Color(0.18, 0.18, 0.2, SurfaceZones.CARBON_A)         # carbon fibre fairings, racer panels
const WASH_SEAT := Color(0.24, 0.25, 0.27, SurfaceZones.PLASTIC_GLOSS_A) # moulded toilet seats and lids
const PNL_CABLE := Color(0.12, 0.13, 0.15, SurfaceZones.PLASTIC_A)    # black PVC cable jackets
const PNL_CABLE_BLUE := Color(0.2, 0.22, 0.28, SurfaceZones.PLASTIC_A) # blue-grey PVC cable jackets
# --- Ceramics, glass, silicon ---------------------------------------------------------------
const LINER := Color(0.86, 0.79, 0.64, SurfaceZones.CERAMIC_A)        # ceramic nozzle liners
const BEZEL := Color(0.86, 0.85, 0.82, SurfaceZones.POLISHED_A)
const SOLAR_CELL := Color(0.1, 0.16, 0.42, SurfaceZones.SILICON_A)    # blue silicon cells
const SOLAR_FRAME := Color(0.5, 0.52, 0.55, SurfaceZones.ANODISED_A)  # anodised aluminium frame
const ORE_BED := Color(0.38, 0.32, 0.27, SurfaceZones.CERAMIC_A)
const ORE_GREY := Color(0.42, 0.4, 0.38, SurfaceZones.CERAMIC_A)
const ORE_RUST := Color(0.5, 0.33, 0.22, SurfaceZones.CERAMIC_A)
const ORE_SLATE := Color(0.36, 0.36, 0.38, SurfaceZones.CERAMIC_A)
const WASH_PORCELAIN := Color(0.88, 0.88, 0.86, SurfaceZones.CERAMIC_GLAZED_A) # glazed porcelain pans, cisterns, basin bowls
const WPN_RADOME := Color(0.84, 0.83, 0.79, SurfaceZones.CERAMIC_A)    # ceramic radomes, feed horns and sensor windows
const ENG_LINER := Color(0.56, 0.51, 0.43, SurfaceZones.CERAMIC_A)   # sooted ceramic liners in thruster bores and throats
# --- Fabrics, leather, wood -----------------------------------------------------------------
const SEAT_LEATHER := Color(0.2, 0.18, 0.18, SurfaceZones.LEATHER_A)  # seat cushions
const SEAT_ARM := Color(0.14, 0.14, 0.15, SurfaceZones.RUBBER_A)      # armrest pads
const STRAP := Color(0.85, 0.55, 0.15, SurfaceZones.NYLON_A)          # webbing straps and buckles' belts
const ALCOVE_BLANKET := Color(0.28, 0.36, 0.42, SurfaceZones.CANVAS_A)
const ALCOVE_LINEN := Color(0.82, 0.82, 0.8, SurfaceZones.FABRIC_A)
const ALCOVE_MATTRESS := Color(0.3, 0.3, 0.32, SurfaceZones.UPHOLSTERY_A)
const BUNK_BLANKET := Color(0.42, 0.4, 0.33, SurfaceZones.CANVAS_A)
const BUNK_LINEN := Color(0.8, 0.8, 0.77, SurfaceZones.FABRIC_A)
const BUNK_MATTRESS := Color(0.32, 0.4, 0.5, SurfaceZones.UPHOLSTERY_A)
const DBED_DUVET := Color(0.36, 0.38, 0.42, SurfaceZones.FABRIC_A)
const DBED_LINEN := Color(0.8, 0.8, 0.77, SurfaceZones.FABRIC_A)
const DBED_THROW := Color(0.15, 0.38, 0.8, SurfaceZones.CANVAS_A)
const DBED_UPHOLSTERY := Color(0.34, 0.35, 0.37, SurfaceZones.UPHOLSTERY_A)
const POD_BLANKET := Color(0.32, 0.4, 0.5, SurfaceZones.CANVAS_A)
const POD_LINEN := Color(0.75, 0.78, 0.8, SurfaceZones.FABRIC_A)
const POD_MATTRESS := Color(0.2, 0.24, 0.3, SurfaceZones.UPHOLSTERY_A)
const RACK_BLANKET := Color(0.42, 0.4, 0.33, SurfaceZones.CANVAS_A)
const RACK_LINEN := Color(0.8, 0.8, 0.77, SurfaceZones.FABRIC_A)
const RACK_MATTRESS := Color(0.62, 0.62, 0.6, SurfaceZones.UPHOLSTERY_A)
const SOFA_CUSHION := Color(0.72, 0.76, 0.8, SurfaceZones.UPHOLSTERY_A)
const SOFA_THROW := Color(0.62, 0.32, 0.24, SurfaceZones.CANVAS_A)
const MED_LINEN := Color(0.8, 0.8, 0.77, SurfaceZones.FABRIC_A)
const MED_PAD := Color(0.72, 0.8, 0.84, SurfaceZones.LEATHER_A)
const MEDIA_CABINET := Color(0.22, 0.2, 0.19, SurfaceZones.WOOD_A)
const MEDIA_WOOD := Color(0.78, 0.47, 0.27, SurfaceZones.WOOD_A)
const MEDIA_WOOD_DARK := Color(0.6, 0.34, 0.2, SurfaceZones.WOOD_A)
const MEDIA_WOOD_MID := Color(0.7, 0.42, 0.24, SurfaceZones.WOOD_A)
const LIT_TIE := Color(0.07, 0.07, 0.075, SurfaceZones.NYLON_A)       # black nylon cable ties
# --- Plain paint in the part's material (no code) -------------------------------------------
const BAR_GLOW := Color(1.0, 0.72, 0.4)
const PLANTER_FRUIT := Color(0.78, 0.22, 0.12)
const PLANTER_LEAF := Color(0.32, 0.64, 0.24)
const PLANTER_LEAF_DARK := Color(0.2, 0.5, 0.2)
const PLANTER_SOIL := Color(0.22, 0.16, 0.11)


## A ducted fan `radius` x `length` along Y, intake at +Y: a duct in the material colour
## with chamfered outer edges, two galvanised bands and a flared polished lip (a ring of
## blackened bolts on it on fans over 0.35 m), a dark bore, `blades` anodised blades round a
## cast iron hub under a chrome spinner, and dark anodised stator vanes holding the cast
## motor nacelle at the exhaust end (-Y).
static func ducted_fan(radius: float, length: float, blades: int = 7) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var wall := radius * 0.12
	var h := length * 0.5
	var ri := radius - wall                     # bore, m
	var bt := clampf(radius * 0.02, 0.005, 0.02)  # stiffening bands stand this proud, m
	var ro := radius - bt                       # duct wall between the bands, m
	var c := minf(wall * 0.3, h * 0.25)         # outer edge chamfer, m
	var lip := ri + wall * 0.25                 # where the lip's flare meets its top, m
	var flare := minf(wall * 0.6, h * 0.3)      # flare depth into the bore, m
	# The duct: one closed profile, material outside, a bright lip, a dark bore.
	_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(ri, -h), Vector2(ro - c, -h),
			Vector2(ro, -h + c), Vector2(ro, h - c), Vector2(ro - c, h), Vector2(lip, h),
			Vector2(ri, h - flare), Vector2(ri, -h)]),
			[TRIM, Color.WHITE, Color.WHITE, TRIM, TRIM, TRIM, DARK] as Array[Color], 24)
	# Two steel stiffening bands round the outside: one by the exhaust, one at the rotor.
	var bw := clampf(length * 0.08, 0.02, 0.08)
	for yc: float in [-h + c + bw * 0.5 + length * 0.04, 0.0]:
		_piping_spin(k, Vector3(0.0, yc, 0.0), Vector3.UP, PackedVector2Array([Vector2(ro - 0.004, -bw * 0.5),
				Vector2(radius, -bw * 0.5), Vector2(radius, bw * 0.5), Vector2(ro - 0.004, bw * 0.5)]),
				[GALVANISED] as Array[Color], 24)
	# A ring of bolts on the lip's top (too small to read on little fans).
	if radius >= 0.35:
		k.color = FLANGE_BOLT
		var bs := clampf(wall * 0.3, 0.014, 0.04)
		var ring_r := (lip + ro - c) * 0.5
		_piping_bolts(k, Vector3.ZERO, Vector3.UP, h, clampi(int(TAU * ring_r / 0.16), 8, 24), ring_r, bs, bs * 0.4)
	# The motor nacelle down the axis, a dark hub on it and a bright spinner on the hub.
	var hub := radius * 0.28
	var ys := minf(hub * 0.9, h * 0.8)          # spinner tip, m
	k.color = CAST
	_thrusters_ring(k, 0.0, hub * 0.8, -h * 0.85, -h * 0.2, 12)
	k.color = HUB
	_thrusters_ring(k, 0.0, hub, -h * 0.2, h * 0.12, 14)
	k.color = CHROME
	k.lathe(PackedVector2Array([Vector2(0.0, h * 0.12), Vector2(hub * 0.96, h * 0.12),
			Vector2(hub * 0.8, lerpf(h * 0.12, ys, 0.45)), Vector2(hub * 0.45, lerpf(h * 0.12, ys, 0.85)),
			Vector2(0.0, ys)]), 14)
	# Rotor blades round the hub.
	k.color = ANODISED
	for i in blades:
		var a := TAU * float(i) / float(blades)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-sin(a), 0.0, cos(a))
		var r0 := hub * 0.95
		var r1 := ri - wall * 0.08
		var p0 := dir * r0 + side * (r1 - r0) * 0.08 + Vector3(0, h * 0.1, 0)
		var p1 := dir * r1 + side * (r1 - r0) * 0.12 + Vector3(0, h * 0.15, 0)
		var p2 := dir * r1 - side * (r1 - r0) * 0.12 + Vector3(0, -h * 0.07, 0)
		var p3 := dir * r0 - side * (r1 - r0) * 0.08 + Vector3(0, -h * 0.02, 0)
		k.quad(p0, p1, p2, p3, Vector3.UP)
		k.quad(p0, p1, p2, p3, Vector3.DOWN)
	# Stator vanes from the nacelle out to the bore, a slight twist against the rotor.
	k.color = ENG_STATOR
	var vt := clampf(radius * 0.025, 0.005, 0.03)
	var vanes := clampi(blades - 2, 3, 8)
	for i in vanes:
		var a := TAU * (float(i) + 0.5) / float(vanes)
		_hullkit_vane(k, a, hub * 0.75, ri + 0.002, -h * 0.8, -h * 0.32, vt, (h * 0.48) * 0.35)
	return _cylinder(k, radius, length)


## A flat vane at angle `a` round Y: a plate `t` thick from radius `r0` to `r1`, `y0` to
## `y1`, its top edge swept `twist` round the circle (stator vanes, ribs).
static func _hullkit_vane(k: MeshKit, a: float, r0: float, r1: float, y0: float, y1: float, t: float,
		twist: float = 0.0) -> void:
	var dir := Vector3(cos(a), 0.0, sin(a))
	var side := Vector3(-sin(a), 0.0, cos(a))
	var ring := func(r: float) -> PackedVector3Array:
		return PackedVector3Array([dir * r + side * (-t * 0.5) + Vector3(0, y0, 0),
				dir * r + side * (t * 0.5) + Vector3(0, y0, 0),
				dir * r + side * (t * 0.5 + twist) + Vector3(0, y1, 0),
				dir * r + side * (-t * 0.5 + twist) + Vector3(0, y1, 0)])
	k.loft(ring.call(r0), ring.call(r1))


static func tank(radius: float, length: float) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var sides := 24
	var body := length - radius * 0.9
	var hb := body * 0.5
	var h := length * 0.5
	# One lathe walks the whole outline: an end boss (valve seat) on each pole, a shallow
	# dome, a weld bead where the dome meets the barrel, the barrel, and back.
	var rb := radius * 0.2
	var bh := radius * 0.08
	var dome_h := radius * 0.45 - bh
	var wb := clampf(radius * 0.025, 0.008, 0.02)
	var a_b := asin(0.2)
	var lower := PackedVector2Array([Vector2(0.0, -h), Vector2(rb * 0.75, -h), Vector2(rb, -h + bh * 0.4)])
	var lower_cols: Array[Color] = [DETAIL, DETAIL, DETAIL]
	for i in 5:
		var a := a_b + (PI * 0.5 - a_b) * float(i) / 4.0
		lower.append(Vector2(sin(a) * radius, -hb - cos(a) * dome_h))
		if i < 4:
			lower_cols.append(Color.WHITE)
	lower.append_array(PackedVector2Array([Vector2(radius * 1.02, -hb), Vector2(radius * 1.02, -hb + wb * 2.0),
			Vector2(radius, -hb + wb * 2.0)]))
	lower_cols.append_array([DETAIL, DETAIL, DETAIL])
	# lower_cols[i] colours the edge from lower[i] to lower[i + 1].
	var prof := PackedVector2Array(lower)
	var cols: Array[Color] = []
	for i in lower.size() - 1:
		cols.append(lower_cols[i])
	cols.append(Color.WHITE)   # the barrel
	for i in range(lower.size() - 1, -1, -1):
		prof.append(Vector2(lower[i].x, -lower[i].y))
	for i in range(lower.size() - 2, -1, -1):
		cols.append(lower_cols[i])
	_piping_spin(k, Vector3.ZERO, Vector3.UP, prof, cols, sides)
	# Two dark straps, each with a tensioner block and its bolt on +X.
	for y: float in [-body * 0.3, body * 0.3]:
		_piping_spin(k, Vector3(0.0, y, 0.0), Vector3.UP, PackedVector2Array([Vector2(radius * 0.99, -0.06),
				Vector2(radius * 1.04, -0.06), Vector2(radius * 1.04, 0.06), Vector2(radius * 0.99, 0.06)]),
				[GALVANISED] as Array[Color], sides, PI / float(sides))
		k.color = DETAIL
		k.box(Vector3(radius * 0.08, 0.17, radius * 0.22), Vector3(radius * 1.015, y, 0.0))
		k.box(Vector3(radius * 0.03, 0.26, radius * 0.06), Vector3(radius * 1.04, y, 0.0))
	# A long weld seam down the barrel, between the straps' buckles and the top.
	var sa := PI * 0.25
	var sd := Vector3(cos(sa), 0.0, sin(sa))
	var sw := clampf(radius * 0.04, 0.012, 0.03)
	k.box(Vector3(sw, body - wb * 4.0, sw), sd * (radius * cos(PI / float(sides)) + sw * 0.25))
	# The maker's plate on -X between the straps (clear of the filler cap FluidSystem puts
	# on top, whichever way the tank lies), with dark lettering.
	var pw := minf(radius * 0.6, 0.45)
	var ph := minf(body * 0.2, 0.35)
	var x_back := sqrt(radius * radius - pw * pw * 0.25) * cos(PI / float(sides)) - 0.004
	var x_face := radius + 0.006
	k.color = PLATE
	k.box(Vector3(x_face - x_back, ph, pw), Vector3(-(x_face + x_back) * 0.5, 0.0, 0.0))
	k.color = DARK
	for j in 2:
		var ly := ph * (0.18 - 0.36 * float(j))
		k.box(Vector3(0.004, ph * 0.14, pw * (0.7 - 0.25 * float(j))), Vector3(-x_face - 0.002, ly, pw * 0.12 * float(j)))
	return _cylinder(k, radius * 1.04, length)


## A mining drill `radius` x `length` along Y, bit toward +Y: a body drum with a hazard band
## near its foot and a bolted flange where it meets a dark cone of stepped rings, each
## step's lip set with six small carbide teeth. Collision is the drum and the cone.
static func drill_head(radius: float, length: float) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var body := length * 0.45
	var y0 := -length * 0.5
	var yb := y0 + body
	k.lathe(PackedVector2Array([Vector2(0.0, y0), Vector2(radius * 0.9, y0), Vector2(radius, y0 + body * 0.15),
			Vector2(radius, yb), Vector2(0.0, yb)]), 18)
	var band_y := y0 + body * 0.32
	_gear_hazard_ring(k, radius * 0.99, radius * 1.012, band_y - body * 0.07, band_y + body * 0.07, 18, 1,
			PartShapes.ACCENT, DARK)
	k.color = DETAIL
	k.lathe(PackedVector2Array([Vector2(radius * 0.95, yb - body * 0.08), Vector2(radius * 1.015, yb - body * 0.07),
			Vector2(radius * 1.015, yb), Vector2(radius * 0.95, yb)]), 18)
	for i in 12:
		var a := TAU * (float(i) + 0.5) / 12.0
		_gear_bolt(k, Vector3(cos(a), 0.0, sin(a)) * radius + Vector3(0.0, yb - body * 0.035, 0.0),
				Vector3(cos(a), 0.0, sin(a)), radius * 0.03, 0.006)
	# The cone, in toothed rings.
	var rings := 4
	for r in rings:
		var t0 := float(r) / float(rings)
		var t1 := float(r + 1) / float(rings)
		var ya := yb + (length - body) * t0
		var y1 := yb + (length - body) * t1
		var ra := radius * (1.0 - t0) * 0.95
		var rb := radius * (1.0 - t1) * 0.95
		k.color = DARK
		k.lathe(PackedVector2Array([Vector2(0.0, ya), Vector2(ra, ya), Vector2(rb + (ra - rb) * 0.4, y1),
				Vector2(0.0, y1)]), 12)
		if r == rings - 1:
			continue
		var lip := lerpf(ra, rb + (ra - rb) * 0.4, 0.15)
		for i in 6:
			var a := TAU * (float(i) + 0.5 * float(r)) / 6.0
			var out := Vector3(cos(a), 0.0, sin(a))
			var base := out * lip * 0.92 + Vector3(0.0, lerpf(ya, y1, 0.15), 0.0)
			k.color = TRIM
			k.strut(base, base + (out * 0.5 + Vector3.UP).normalized() * radius * 0.16, radius * 0.07)
	return _cone_collision(k, radius, length)


## A thruster block `cols` x `rows` cells of `cell` m, `depth` deep along Y, nozzles in its
## +Y face: a chamfered block on a mount flange, a dark band round its waist and a dark
## status bezel with two lamps on its -Z side, a dark face plate with bolts between the
## nozzles, and per cell a hollow heat-blued bell with a bright lip round a glowing floor
## (PartShape.glow, `glow`).
static func thruster_grid(cols: int, rows: int, cell: float, depth: float,
		glow := Color(0.35, 0.65, 1.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var w := float(cols) * cell
	var d := float(rows) * cell
	var hx := w * 0.5
	var hz := d * 0.5
	var hd := depth * 0.5
	var c := cell * 0.12                          # corner chamfer, m
	var bev := clampf(cell * 0.05, 0.01, 0.03)    # body inset from the flange, m
	var fl := clampf(depth * 0.12, 0.02, 0.06)    # mount flange, m
	# The mount flange and the chamfered body standing on it.
	k.loft(_sensors_rect_ring(hx, hz, -hd, c * 1.1), _sensors_rect_ring(hx, hz, -hd + fl, c * 1.1))
	k.loft(_sensors_rect_ring(hx - bev, hz - bev, -hd + fl, c), _sensors_rect_ring(hx - bev, hz - bev, hd, c))
	# A dark band round the waist, a hair proud.
	var band := clampf(depth * 0.06, 0.012, 0.04)
	var by := lerpf(-hd + fl, hd, 0.32)
	k.color = DARK
	k.loft(_sensors_rect_ring(hx - bev + 0.004, hz - bev + 0.004, by - band * 0.5, c),
			_sensors_rect_ring(hx - bev + 0.004, hz - bev + 0.004, by + band * 0.5, c))
	# A status bezel on the -Z side, two lamps in it.
	var led := clampf(cell * 0.06, 0.012, 0.04)
	var ly := lerpf(by, hd, 0.5)
	var lz := -(hz - bev) - 0.004
	k.box(Vector3(led * 4.4, led * 1.9, 0.008), Vector3(0.0, ly, lz))
	for sx: float in [-1.0, 1.0]:
		g.box(Vector3(led, led, 0.004), Vector3(sx * led * 1.1, ly, lz - 0.005))
	# The dark face plate the nozzles stand on.
	var yb := hd + 0.006
	k.box(Vector3(w - 2.0 * bev - c, 0.006, d - 2.0 * bev - c), Vector3(0.0, hd + 0.003, 0.0))
	# Bolts where four cells meet.
	k.color = DETAIL
	var bolt_r := clampf(cell * 0.035, 0.008, 0.03)
	var bolt_h := clampf(cell * 0.03, 0.005, 0.02)
	for i in range(1, cols):
		for j in range(1, rows):
			_thrusters_bolt(k, Vector3(-hx + cell * float(i), yb, -hz + cell * float(j)), bolt_r, bolt_h)
	# A bell per cell: hollow, flaring out to a bright lip, the floor glowing deep in it.
	var yt := hd + cell * 0.25
	var lip := cell * 0.05
	for i in cols:
		for j in rows:
			var at := Vector3(-hx + cell * (float(i) + 0.5), 0.0, -hz + cell * (float(j) + 0.5))
			var first := k.verts.size()
			k.color = RIM
			k.lathe(PackedVector2Array([Vector2(cell * 0.26, yb), Vector2(cell * 0.31, yb), Vector2(cell * 0.4, yt - 0.003),
					Vector2(cell * 0.35, yt - 0.003)]), 8)
			k.color = TRIM
			k.lathe(PackedVector2Array([Vector2(cell * 0.405, yt - lip), Vector2(cell * 0.405, yt),
					Vector2(cell * 0.34, yt)]), 8)
			for v in range(first, k.verts.size()):
				k.verts[v] += at
			var gf := g.verts.size()
			_thrusters_ring(g, 0.0, cell * 0.26, yb, yb + cell * 0.1, 8)
			for v in range(gf, g.verts.size()):
				g.verts[v] += at
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = w * d * depth
	var col := BoxShape3D.new()
	col.size = Vector3(w, depth + cell * 0.5, d)
	shape.collision = col
	# Collision centred on the block; nozzles stick out a little on +Y.
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## Eight points of a `hx` by `hz` rectangle with its corners cut by `c`, at height y (XZ).
static func _sensors_rect_ring(hx: float, hz: float, y: float, c: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(hx - c, y, -hz), Vector3(hx, y, -hz + c), Vector3(hx, y, hz - c),
			Vector3(hx - c, y, hz), Vector3(-hx + c, y, hz), Vector3(-hx, y, hz - c),
			Vector3(-hx, y, -hz + c), Vector3(-hx + c, y, -hz)])


## A solar panel `width` x `length`, `thickness` deep, cells up (+Y): a framed tray with
## a hinge barrel of knuckles along its -Z edge, corner brackets and a junction box on the
## +Z rail, the backsheet set a little below the frame's top, dark blue cells on it about
## 0.5 m square (fewer, bigger cells on very big panels) with two bright busbars down each
## column of cells.
static func solar_panel(width: float, length: float, thickness: float = 0.05) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hw := width * 0.5
	var hl := length * 0.5
	var ht := thickness * 0.5
	var f := clampf(minf(width, length) * 0.02, 0.03, 0.06)   # frame rail width, m
	var hinge := clampf(thickness * 0.9, 0.035, 0.08)          # hinge rail width along Z, m
	var y_cell := ht - minf(0.008, thickness * 0.15)           # backsheet top, below the frame's, m
	# The backsheet tray, then the frame round it: X rails, a +Z rail, and the hinge edge.
	k.color = SOLAR_FRAME
	k.box(Vector3(width - 2.0 * f, y_cell + ht, length - f - hinge), Vector3(0.0, (y_cell - ht) * 0.5, (hinge - f) * 0.5))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(f, thickness, length), Vector3(sx * (hw - f * 0.5), 0.0, 0.0))
	k.box(Vector3(width - 2.0 * f, thickness, f), Vector3(0.0, 0.0, hl - f * 0.5))
	k.box(Vector3(width - 2.0 * f, thickness * 0.6, hinge), Vector3(0.0, -thickness * 0.2, -hl + hinge * 0.5))
	# Hinge knuckles on the -Z edge, alternately in the frame colour and steel, and a pin.
	var kr := thickness * 0.38
	var ky := thickness * 0.1
	var kz := -hl + hinge * 0.5
	var knuckles := clampi(int(width / 0.4), 3, 9) | 1
	var span := width - 2.0 * f
	for i in knuckles:
		var x0 := -span * 0.5 + span * float(i) / float(knuckles) + 0.004
		var x1 := -span * 0.5 + span * float(i + 1) / float(knuckles) - 0.004
		k.color = CHROME if i % 2 == 0 else SOLAR_FRAME
		_tube(k, Vector3(x0, ky, kz), Vector3(x1, ky, kz), kr, 8)
	# Steel corner brackets at the +Z corners, proud of the frame's top, and a junction box.
	k.color = DETAIL
	var cb := f * 1.6
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(cb, 0.006, cb), Vector3(sx * (hw - cb * 0.5), ht + 0.003, hl - cb * 0.5))
		k.box(Vector3(cb, 0.006, cb * 0.7), Vector3(sx * (hw - cb * 0.5), ht + 0.003, -hl + hinge + cb * 0.35))
	k.color = PLASTIC_DARK
	var jb := minf(width * 0.15, 0.2)
	k.box(Vector3(jb, 0.014, f * 0.8), Vector3(-hw * 0.5, ht + 0.007, hl - f * 0.5))
	# Cells about 0.5 m square, the grid bounded on big panels.
	var inner_w := width - 2.0 * f
	var inner_l := length - f - hinge
	var cells_x := maxi(1, int(inner_w / 0.5))
	var cells_z := maxi(1, int(inner_l / 0.5))
	while cells_x * cells_z > 120:
		cells_x = maxi(1, cells_x - 1)
		cells_z = maxi(1, cells_z - 1)
	var cw := inner_w / float(cells_x)
	var cl := inner_l / float(cells_z)
	var gap := clampf(minf(cw, cl) * 0.05, 0.01, 0.03)
	var x_left := -hw + f
	var z_front := -hl + hinge
	k.color = SOLAR_CELL
	for i in cells_x:
		for j in cells_z:
			var c := Vector3(x_left + cw * (float(i) + 0.5), y_cell + 0.003, z_front + cl * (float(j) + 0.5))
			var hx := cw * 0.5 - gap * 0.5
			var hz := cl * 0.5 - gap * 0.5
			k.quad(c + Vector3(-hx, 0, -hz), c + Vector3(hx, 0, -hz), c + Vector3(hx, 0, hz), c + Vector3(-hx, 0, hz), Vector3.UP)
	# Two busbars down every column of cells, the length of the panel.
	k.color = TRIM
	var bw := clampf(cw * 0.025, 0.006, 0.014)
	for i in cells_x:
		for s: float in [-1.0, 1.0]:
			var x := x_left + cw * (float(i) + 0.5) + s * cw * 0.22
			k.quad(Vector3(x - bw * 0.5, y_cell + 0.006, z_front + gap), Vector3(x + bw * 0.5, y_cell + 0.006, z_front + gap),
					Vector3(x + bw * 0.5, y_cell + 0.006, hl - f - gap), Vector3(x - bw * 0.5, y_cell + 0.006, hl - f - gap), Vector3.UP)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * length * thickness
	var col := BoxShape3D.new()
	col.size = Vector3(width, thickness + 0.01, length)
	shape.collision = col
	# The cover glass over the cells, a hair above the busbars, inside the frame.
	var gk := MeshKit.new()
	gk.color = Color.WHITE
	var gy := y_cell + 0.009
	gk.quad(Vector3(x_left, gy, z_front), Vector3(x_left + inner_w, gy, z_front),
			Vector3(x_left + inner_w, gy, z_front + inner_l), Vector3(x_left, gy, z_front + inner_l), Vector3.UP)
	shape.glass = gk.finish()
	shape.glass_kind = Glazing.Kind.SOLAR
	return shape


## A landing leg `height` tall (sole to mount face, +Y): a chamfered hip block with bolt
## heads on its sides and an amber status lamp on its -Z face (PartShape.glow), a clevis
## with a chrome pin, an upper strut (a sleeve in the material colour, a dark seal, a
## chrome rod) raking forward to a pinned knee hub, a lower strut the same way down to a
## ball ankle, a slim hydraulic ram from the hip to the knee on the +X side, and an
## eight-sided foot pad `pad` across: a rubber sole, a hazard band round its rim and bolts
## round the ankle. Stands on -Y.
static func landing_leg(height: float, pad: float = 0.6) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hh := height * 0.5
	var blk := 0.2                                  # hip block height, m
	var y_blk := hh - blk                           # its underside
	var pin_y := y_blk - 0.07                       # the hip pin, m
	var hip := Vector3(0.0, pin_y, 0.0)
	var knee := Vector3(0.0, 0.0, -height * 0.18)
	var pad_y := -hh + 0.1                          # top of the pad
	var ankle := Vector3(0.0, pad_y + 0.055, 0.0)
	var r := pad * 0.5
	# The hip block, bolt heads on its X faces, a dark lamp bezel on its -Z face.
	k.color = Color.WHITE
	k.loft(_chamfer_ring(0.2, y_blk, 0.04), _chamfer_ring(0.2, hh, 0.04))
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_gear_bolt(k, Vector3(sx * 0.2, y_blk + blk * 0.5, sz * 0.09), Vector3(sx, 0.0, 0.0), 0.022, 0.014)
	k.color = DARK
	k.box(Vector3(0.1, 0.05, 0.01), Vector3(0.0, y_blk + blk * 0.5, -0.2 - 0.004))
	# The clevis under the block and its pin.
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.035, 0.11, 0.12), Vector3(sx * 0.085, y_blk - 0.05, 0.0))
	k.color = CHROME
	_tube(k, Vector3(-0.115, pin_y, 0.0), Vector3(0.115, pin_y, 0.0), 0.026, 8)
	# The upper strut: sleeve, seal, rod down to the knee.
	var up_dir := (knee - hip).normalized()
	var up_mid := hip.lerp(knee, 0.58)
	k.color = Color.WHITE
	_tube(k, hip + up_dir * 0.03, up_mid, 0.076, 10)
	k.color = RUBBER
	_tube(k, up_mid - up_dir * 0.01, up_mid + up_dir * 0.025, 0.085, 10)
	k.color = CHROME
	_tube(k, up_mid, knee, 0.046, 8)
	# The knee hub with its pin caps.
	k.color = Color.WHITE
	_tube(k, knee - Vector3(0.1, 0.0, 0.0), knee + Vector3(0.1, 0.0, 0.0), 0.08, 10)
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		_gear_bolt(k, knee + Vector3(sx * 0.1, 0.0, 0.0), Vector3(sx, 0.0, 0.0), 0.04, 0.014)
	# The lower strut: sleeve, seal, rod down to the ankle.
	var lo_dir := (ankle - knee).normalized()
	var lo_mid := knee.lerp(ankle, 0.5)
	k.color = Color.WHITE
	_tube(k, knee + lo_dir * 0.05, lo_mid, 0.068, 10)
	k.color = RUBBER
	_tube(k, lo_mid - lo_dir * 0.01, lo_mid + lo_dir * 0.025, 0.077, 10)
	k.color = CHROME
	_tube(k, lo_mid, ankle, 0.042, 8)
	# The hydraulic ram on the +X side: a dark barrel and a chrome rod from a lug under the
	# hip block to the knee hub's end.
	var ram_a := Vector3(0.13, y_blk - 0.03, 0.1)
	var ram_b := knee + Vector3(0.13, 0.03, 0.0)
	k.color = DETAIL
	k.box(Vector3(0.05, 0.06, 0.06), Vector3(0.13, y_blk - 0.03 + 0.002, 0.1))
	k.color = GUNMETAL
	_tube(k, ram_a, ram_a.lerp(ram_b, 0.55), 0.028, 8)
	k.color = CHROME
	_tube(k, ram_a.lerp(ram_b, 0.5), ram_b, 0.015, 6)
	# The ankle ball on a boss.
	k.color = DETAIL
	var ay := ankle.y
	k.lathe(PackedVector2Array([Vector2(0.0, ay - 0.055), Vector2(0.04, ay - 0.04), Vector2(0.055, ay),
			Vector2(0.04, ay + 0.04), Vector2(0.0, ay + 0.055)]), 8)
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(0.0, pad_y - 0.004), Vector2(0.08, pad_y - 0.004), Vector2(0.07, pad_y + 0.02),
			Vector2(0.0, pad_y + 0.02)]), 8)
	# The pad: a rubber sole, an eight-sided body with a chamfered top, a hazard band round
	# its rim, bolts round the ankle.
	k.color = TREAD
	k.lathe(PackedVector2Array([Vector2(0.0, -hh), Vector2(r * 0.96, -hh), Vector2(r * 0.96, -hh + 0.03),
			Vector2(0.0, -hh + 0.03)]), 8)
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(0.0, -hh + 0.03), Vector2(r, -hh + 0.03), Vector2(r, -hh + 0.075),
			Vector2(r * 0.82, pad_y), Vector2(0.0, pad_y)]), 8)
	_gear_hazard_ring(k, r * 0.97, r + 0.003, -hh + 0.036, -hh + 0.07, 8, 2, PartShapes.ACCENT, DARK)
	k.color = DETAIL
	var bolt_r := minf(r * 0.62, 0.16)
	for i in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		_gear_bolt(k, Vector3(cos(a) * bolt_r, pad_y, sin(a) * bolt_r), Vector3.UP, 0.02, 0.014)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = 0.4 * 0.4 * blk + PI * 0.076 * 0.076 * hip.distance_to(knee) + PI * 0.068 * 0.068 * knee.distance_to(ankle) \
			+ 2.0 * sqrt(2.0) * r * r * 0.1
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * 0.2, hh, sz * 0.2))
			pts.append(Vector3(sx * 0.2, y_blk, sz * 0.2))
			pts.append(knee + Vector3(sx * 0.11, sz * 0.08, -0.08))
	for i in 8:
		var a := TAU * float(i) / 8.0
		pts.append(Vector3(cos(a) * r, -hh, sin(a) * r))
		pts.append(Vector3(cos(a) * r, -hh + 0.075, sin(a) * r))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	var g := MeshKit.new()
	g.box(Vector3(0.06, 0.024, 0.004), Vector3(0.0, y_blk + blk * 0.5, -0.2 - 0.011))
	shape.glow = g.finish()
	shape.glow_color = GLOWING
	return shape


## A big main engine `radius` (the bell's mouth) by `length` along Y, exhaust +Y: a dark
## chamfered mount plate with four bolts at -Y, a housing drum in the material colour with
## eight ribs, two fuel feeds and a heat-shield band under its shoulder, a dark gimbal
## collar with a bolt ring, then a hollow steel bell with two dark stiffener rings and a
## rolled pale lip, a ceramic liner down to an injector floor with a boss and a ring, and a
## glowing floor between them (PartShape.glow).
static func engine_bell(radius: float, length: float, glow := Color(1.0, 0.72, 0.4)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var r := radius
	var h := length * 0.5
	var seg := 24
	# A chamfered dark mount plate with a hex bolt in each corner.
	var plate_t := clampf(length * 0.04, 0.03, 0.08)
	var ph := r * 0.72
	k.color = DARK
	k.loft(_chamfer_ring(ph, -h, r * 0.2), _chamfer_ring(ph, -h + plate_t, r * 0.2))
	var d0 := -h + plate_t
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_thrusters_bolt(k, Vector3(sx * ph * 0.78, d0, sz * ph * 0.78), maxf(0.01, r * 0.05), clampf(r * 0.03, 0.006, 0.025))
	# The housing: a drum in the material colour widening to a chamfered shoulder.
	var yh := -h + length * 0.45                # housing top, m
	var sh := r * 0.12                           # shoulder, m
	var drum := func(y: float) -> float: return lerpf(r * 0.7, r * 0.8, (y - d0) / (yh - sh - d0))
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(0.0, d0), Vector2(r * 0.7, d0), Vector2(r * 0.8, yh - sh), Vector2(r * 0.62, yh),
			Vector2(0.0, yh)]), seg)
	# A heat-shield band under the shoulder, eight steel ribs below it.
	var hs := clampf(length * 0.05, 0.03, 0.12)
	var y_hs := yh - sh - hs
	k.color = HEAT_SHIELD
	_thrusters_ring(k, drum.call(y_hs) - 0.01, r * 0.83, y_hs, yh - sh, seg)
	var rib := clampf(r * 0.06, 0.015, 0.06)
	k.color = DETAIL
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-dir.z, 0.0, dir.x) * rib * 0.5
		var ends: Array[PackedVector3Array] = []
		for y: float in [d0, y_hs - 0.004]:
			var at: Vector3 = dir * drum.call(y) + Vector3(0.0, y, 0.0)
			ends.append(PackedVector3Array([at - dir * 0.01 - side, at - dir * 0.01 + side, at + dir * rib * 0.6 + side,
					at + dir * rib * 0.6 - side]))
		k.loft(ends[0], ends[1])
	# Two fuel feeds between the ribs: a pipe up from the plate, elbowing in through a flange.
	var pr := maxf(0.012, r * 0.045)
	var y_feed := lerpf(d0, y_hs, 0.4)
	for a: float in [PI * 0.25, PI * 1.25]:
		var dir := Vector3(cos(a), 0.0, sin(a))
		var base := dir * r * 0.86 + Vector3(0.0, d0, 0.0)
		var bend := dir * r * 0.86 + Vector3(0.0, y_feed, 0.0)
		k.color = DETAIL
		_tube(k, base, bend + Vector3(0.0, pr, 0.0), pr, 8)
		_tube(k, bend, dir * (drum.call(y_feed) - 0.02) + Vector3(0.0, y_feed, 0.0), pr, 8)
		k.color = DARK
		var fl: Vector3 = dir * (drum.call(y_feed) + pr * 0.6) + Vector3(0.0, y_feed, 0.0)
		_tube(k, fl - dir * pr * 0.6, fl + dir * pr * 0.4, pr * 1.6, 8)
		_tube(k, base - Vector3(0.0, 0.002, 0.0), base + Vector3(0.0, pr * 1.2, 0.0), pr * 1.5, 8)
	# The gimbal collar on the shoulder, bolted round its top.
	var gh := clampf(length * 0.05, 0.03, 0.12)
	k.color = RIM
	_thrusters_ring(k, r * 0.4, r * 0.6, yh - 0.004, yh + gh, seg)
	k.color = DETAIL
	_piping_bolts(k, Vector3.ZERO, Vector3.UP, yh + gh, 8, r * 0.535, r * 0.055, r * 0.03)
	# The bell: one hollow lathe, steel outside, a rolled pale lip, a ceramic liner inside
	# narrowing to the injector floor.
	var y_t := yh + gh                          # the bell's foot, m
	var wall := r * 0.05
	var lip := clampf(length * 0.04, 0.03, 0.1)
	var y_fl := y_t + clampf(length * 0.03, 0.02, 0.06)   # injector floor, m
	var steps := 6
	var rb := func(t: float) -> float: return lerpf(r * 0.42, r * 0.95, pow(t, 1.6))
	var prof := PackedVector2Array([Vector2(0.0, y_t), Vector2(rb.call(0.0) + wall, y_t)])
	var cols: Array[Color] = [DARK]
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		prof.append(Vector2(rb.call(t) + wall, lerpf(y_t, h - lip, t)))
		cols.append(DETAIL)
	prof.append_array(PackedVector2Array([Vector2(r * 1.04, h - lip), Vector2(r * 1.04, h), Vector2(rb.call(1.0), h)]))
	cols.append_array([TRIM, TRIM, TRIM])
	for i in range(steps - 1, -1, -1):
		var t := float(i) / float(steps)
		prof.append(Vector2(rb.call(t), lerpf(y_fl, h, t)))
		cols.append(LINER)
	prof.append(Vector2(0.0, y_fl))
	cols.append(DARK)
	_piping_spin(k, Vector3.ZERO, Vector3.UP, prof, cols, seg)
	# Two dark stiffener rings round the bell.
	var bw := clampf(length * 0.012, 0.01, 0.04)
	for t: float in [0.4, 0.75]:
		var y := lerpf(y_t, h - lip, t)
		var ro: float = rb.call(t) + wall
		_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(ro - 0.004, y - bw), Vector2(ro + r * 0.03, y - bw),
				Vector2(ro + r * 0.03, y + bw), Vector2(ro - 0.004, y + bw)]), [RIM] as Array[Color], seg)
	# The injector floor: a steel ring and a boss in the middle.
	var rf: float = rb.call(0.0)
	var ih := clampf(length * 0.012, 0.006, 0.03)
	_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(rf * 0.8, y_fl), Vector2(rf * 0.8, y_fl + ih),
			Vector2(rf * 0.62, y_fl + ih), Vector2(rf * 0.62, y_fl)]), [DETAIL] as Array[Color], seg)
	_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(rf * 0.25, y_fl), Vector2(rf * 0.18, y_fl + rf * 0.35),
			Vector2(0.0, y_fl + rf * 0.45)]), [DETAIL] as Array[Color], 12)
	var shape := _cylinder(k, radius * 1.05, length)
	# The glow: the floor between the boss and the ring.
	var g := MeshKit.new()
	_thrusters_ring(g, rf * 0.2, rf * 0.6, y_fl + 0.002, y_fl + 0.002 + clampf(length * 0.006, 0.003, 0.012), 20)
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A swept fin: a slab `thickness` thick (X) whose root runs `root_length` along Z at
## y = 0, rising `height` in +Y to a tip `tip_length` long set back `sweep` from the root's
## leading (-Z) end, in the hull's paint. Its leading edge is a titanium wedge, its trailing
## edge tapers to a thin anodised lip, a gunmetal doubler strip runs along the root on both
## faces with steel bolts in it, a rubber seal fillets the root on both faces where it meets
## the hull, dark panel lines cross both faces, and a small red navigation light
## (PartShape.glow) sits in a moulded plastic housing at the tip's trailing corner under a
## faceted red lens (PartShape.glass). Collision is the hull of the slab's outline.
static func fin(root_length: float, height: float, tip_length: float, sweep: float,
		thickness: float = 0.1) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var t := thickness * 0.5
	var zl0 := -root_length * 0.5                # root leading edge, m
	var zt0 := root_length * 0.5                 # root trailing edge, m
	var zl1 := -root_length * 0.5 + sweep        # tip leading edge, m
	var zt1 := zl1 + tip_length                  # tip trailing edge, m
	var el0 := clampf(root_length * 0.08, 0.04, 0.35)  # leading wedge depth at the root, m
	var el1 := clampf(tip_length * 0.1, 0.03, 0.3)     # and at the tip, m
	var et0 := el0 * 0.7                          # trailing taper, m
	var et1 := el1 * 0.7
	var lip := t * 0.25                           # the trailing edge's thin lip, half, m
	var sec := func(y: float, pts: Array) -> PackedVector3Array:
		var out := PackedVector3Array()
		for p: Vector2 in pts:
			out.append(Vector3(p.y, y, p.x))
		return out
	# The core slab, then the leading wedge (bright cap) and the trailing taper.
	k.color = Color.WHITE
	k.loft(sec.call(0.0, [Vector2(zl0 + el0, t), Vector2(zt0 - et0, t), Vector2(zt0 - et0, -t), Vector2(zl0 + el0, -t)]),
			sec.call(height, [Vector2(zl1 + el1, t), Vector2(zt1 - et1, t), Vector2(zt1 - et1, -t), Vector2(zl1 + el1, -t)]))
	k.color = ANODISED
	k.loft(sec.call(0.0, [Vector2(zt0 - et0, t), Vector2(zt0, lip), Vector2(zt0, -lip), Vector2(zt0 - et0, -t)]),
			sec.call(height, [Vector2(zt1 - et1, t), Vector2(zt1, lip), Vector2(zt1, -lip), Vector2(zt1 - et1, -t)]))
	k.color = AERO_EDGE
	k.loft(sec.call(0.0, [Vector2(zl0, 0.0), Vector2(zl0 + el0, t), Vector2(zl0 + el0, -t)]),
			sec.call(height, [Vector2(zl1, 0.0), Vector2(zl1 + el1, t), Vector2(zl1 + el1, -t)]))
	# The root doubler: a wedge strip along each face, bolted.
	var dh := clampf(height * 0.07, 0.04, 0.3)    # doubler height, m
	var dz0 := zl0 + el0 + dh * (zl1 - zl0) / height + 0.02
	var dz1 := zt0 - et0 + dh * (zt1 - zt0) / height - 0.02
	var bolts := clampi(int((dz1 - dz0) / maxf(dh * 3.0, 0.3)), 2, 12)
	var br := clampf(dh * 0.12, 0.008, 0.03)
	for sx: float in [-1.0, 1.0]:
		k.color = GUNMETAL
		var w0 := PackedVector3Array([Vector3(sx * (t - 0.002), 0.0, dz0), Vector3(sx * (t + 0.018), 0.0, dz0),
				Vector3(sx * (t - 0.002), dh, dz0)])
		var w1 := PackedVector3Array([Vector3(sx * (t - 0.002), 0.0, dz1), Vector3(sx * (t + 0.018), 0.0, dz1),
				Vector3(sx * (t - 0.002), dh, dz1)])
		k.loft(w0, w1)
		k.color = DETAIL
		# Bolt heads on the slab's face just above the doubler.
		for i in bolts:
			var z := lerpf(dz0 + 0.04, dz1 - 0.04, (float(i) + 0.5) / float(bolts))
			_gear_bolt(k, Vector3(sx * t, dh + br * 1.6, z), Vector3(sx, 0.0, 0.0), br, 0.008)
		# Panel lines: one along the span at mid-height, one down the chord.
		k.color = DARK
		var ym := height * 0.5
		var za := lerpf(zl0 + el0, zl1 + el1, 0.5) + 0.02
		var zb := lerpf(zt0 - et0, zt1 - et1, 0.5) - 0.02
		var lw := clampf(height * 0.012, 0.008, 0.03) * 0.5
		var x := sx * (t + 0.002)
		k.quad(Vector3(x, ym - lw, za), Vector3(x, ym - lw, zb), Vector3(x, ym + lw, zb), Vector3(x, ym + lw, za), Vector3(sx, 0, 0))
		var zc0 := lerpf(zl0, zt0, 0.55)
		var zc1 := lerpf(zl1, zt1, 0.55)
		var lo := dh + br * 4.0
		var hi := height * 0.92
		var zlo := lerpf(zc0, zc1, lo / height)
		var zhi := lerpf(zc0, zc1, hi / height)
		k.quad(Vector3(x, lo, zlo - lw), Vector3(x, lo, zlo + lw), Vector3(x, hi, zhi + lw), Vector3(x, hi, zhi - lw), Vector3(sx, 0, 0))
	# The root seal: a rubber fillet along each face where the slab meets the hull plate,
	# running out past the doubler's toe.
	k.color = RUBBER
	for sx: float in [-1.0, 1.0]:
		var s0 := PackedVector3Array([Vector3(sx * (t - 0.001), -0.002, zl0 + el0), Vector3(sx * (t + 0.03), -0.002, zl0 + el0),
				Vector3(sx * (t - 0.001), 0.012, zl0 + el0)])
		var s1 := PackedVector3Array([Vector3(sx * (t - 0.001), -0.002, zt0 - et0), Vector3(sx * (t + 0.03), -0.002, zt0 - et0),
				Vector3(sx * (t - 0.001), 0.012, zt0 - et0)])
		k.loft(s0, s1)
	# The navigation light at the tip's trailing corner: a plastic housing, the red lamp on
	# top under a faceted red lens.
	var ll := clampf(tip_length * 0.18, 0.05, 0.3)
	var lh := clampf(height * 0.04, 0.03, 0.12)
	var lz := zt1 - et1 - ll * 0.5 - 0.01
	k.color = PLASTIC_DARK
	k.box(Vector3(thickness + 0.016, lh + 0.008, ll), Vector3(0.0, height - lh * 0.5 + 0.004, lz))
	var g := MeshKit.new()
	g.box(Vector3(thickness * 0.7, 0.004, ll * 0.7), Vector3(0.0, height + 0.010, lz))
	var gk := MeshKit.new()
	_navlamps_lens(gk, Vector3(0.0, height + 0.008, lz), Vector3.UP, Vector3.RIGHT, thickness * 0.48, ll * 0.48, 0.016)
	var shape := PartShapes.PartShape.new()
	shape.glass = gk.finish()
	shape.glass_kind = Glazing.Kind.RED
	shape.mesh = k.finish()
	shape.volume = (root_length + tip_length) * 0.5 * height * thickness * 0.85
	var pts := PackedVector3Array()
	for p: Vector3 in [Vector3(0.0, 0.0, zl0), Vector3(0.0, 0.0, zt0), Vector3(0.0, height, zt1), Vector3(0.0, height, zl1)]:
		pts.append(p + Vector3(t, 0, 0))
		pts.append(p + Vector3(-t, 0, 0))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.18, 0.12)
	return shape


## A nav lamp's lens into `g` (a glass mesh): a faceted dome on a chamfered rectangle
## `hu` by `hv` (half sizes along `u` and `n` x `u`, m) whose base sits at `centre`,
## rising `h` along `n` through a mid tier to a flat crown. Open at the base (it sits on
## the housing over the lamp). Used by fin, fin_blade, ribbed_spine and spoiler_wing.
static func _navlamps_lens(g: MeshKit, centre: Vector3, n: Vector3, u: Vector3, hu: float, hv: float, h: float) -> void:
	var v := n.cross(u).normalized()
	var ring := func(o: Vector3, a: float, b: float) -> PackedVector3Array:
		var c := minf(a, b) * 0.35
		var out := PackedVector3Array()
		for p: Vector2 in [Vector2(a - c, b), Vector2(-a + c, b), Vector2(-a, b - c), Vector2(-a, -b + c),
				Vector2(-a + c, -b), Vector2(a - c, -b), Vector2(a, -b + c), Vector2(a, b - c)]:
			out.append(o + u * p.x + v * p.y)
		return out
	var base: PackedVector3Array = ring.call(centre, hu, hv)
	var mid: PackedVector3Array = ring.call(centre + n * h * 0.6, hu * 0.82, hv * 0.82)
	var top: PackedVector3Array = ring.call(centre + n * h, hu * 0.5, hv * 0.5)
	g.color = Color.WHITE
	g.loft(base, mid, false)
	g.loft(mid, top, false)
	g.poly(top, n)


## A shipping container `size`: corrugated walls in the material colour, a dark satin
## frame, cast corner castings with dark twist-lock holes, two door leaves at +Z meeting on
## a rubber gasket, galvanised lock bars, handles and hinges on cast keepers, and (when
## `stripe` has alpha) two bands of the `stripe` colour round it.
static func container(size: Vector3, stripe := Color(0, 0, 0, 0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := size * 0.5
	var post := minf(0.12, minf(size.x, size.y) * 0.12)    # long edge posts, m
	var ex := size.x * 0.02                                 # walls sit in from the frame, m
	var ey := size.y * 0.02
	var ez := minf(0.04, size.z * 0.02)
	var rec := minf(0.1, size.z * 0.05)                     # the door end's recess, m
	var end := maxf(minf(0.12, size.z * 0.08), rec + 0.01)  # end frame depth, m
	# The box: walls in from the frame, its +Z end set deeper for the doors.
	k.box(Vector3(size.x - 2.0 * ex, size.y - 2.0 * ey, size.z - ez - rec), Vector3(0.0, 0.0, (ez - rec) * 0.5))
	# Corrugation: trapezoid ridges up both long walls and across the roof.
	var span := size.z - 2.0 * end
	var ridges := maxi(2, int(span / 0.3))
	var pitch := span / float(ridges)
	var b0 := pitch * 0.3
	var b1 := pitch * 0.18
	var ry := h.y - 0.004 - post
	var rx := h.x - 0.004 - post
	for i in ridges:
		var zc := -h.z + end + pitch * (float(i) + 0.5)
		for sx: float in [-1.0, 1.0]:
			var x0 := sx * (h.x - ex)
			var x1 := sx * (h.x - ex * 0.5)
			var r := ex * 0.5
			k.quad(Vector3(x0, -ry, zc - b0), Vector3(x1, -ry, zc - b1), Vector3(x1, ry, zc - b1), Vector3(x0, ry, zc - b0),
					Vector3(sx * (b0 - b1), 0.0, -r))
			k.quad(Vector3(x1, -ry, zc - b1), Vector3(x1, -ry, zc + b1), Vector3(x1, ry, zc + b1), Vector3(x1, ry, zc - b1),
					Vector3(sx, 0.0, 0.0))
			k.quad(Vector3(x1, -ry, zc + b1), Vector3(x0, -ry, zc + b0), Vector3(x0, ry, zc + b0), Vector3(x1, ry, zc + b1),
					Vector3(sx * (b0 - b1), 0.0, r))
		var y0 := h.y - ey
		var y1 := h.y - ey * 0.5
		k.quad(Vector3(-rx, y0, zc - b0), Vector3(-rx, y1, zc - b1), Vector3(rx, y1, zc - b1), Vector3(rx, y0, zc - b0),
				Vector3(0.0, b0 - b1, -ey * 0.5))
		k.quad(Vector3(-rx, y1, zc - b1), Vector3(-rx, y1, zc + b1), Vector3(rx, y1, zc + b1), Vector3(rx, y1, zc - b1),
				Vector3.UP)
		k.quad(Vector3(-rx, y1, zc + b1), Vector3(-rx, y0, zc + b0), Vector3(rx, y0, zc + b0), Vector3(rx, y1, zc + b1),
				Vector3(0.0, b0 - b1, ey * 0.5))
	# The door end (+Z): two leaves in the recess, a dark seam between them.
	var fx := h.x - 0.008 - post * 0.85
	var fy := h.y - 0.008 - post * 0.85
	var gap := 0.012
	var lw := fx - gap * 0.5
	var lt := rec * 0.15
	var zl := h.z - rec + lt                                # the leaves' front face
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(lw, fy * 2.0, lt), Vector3(sx * (gap + lw) * 0.5, 0.0, h.z - rec + lt * 0.5))
	if stripe.a > 0.0:
		# Two bands of a second colour down both long sides and across both ends.
		k.color = stripe
		var bt := ex * 0.5 + 0.004
		for y: float in [size.y * 0.22, -size.y * 0.1]:
			for sx: float in [-1.0, 1.0]:
				k.box(Vector3(bt, size.y * 0.1, span), Vector3(sx * (h.x - ex + bt * 0.5), y, 0.0))
			k.box(Vector3(fx * 2.0, size.y * 0.1, 0.006), Vector3(0.0, y, -h.z + ez - 0.003))
			k.box(Vector3(fx * 2.0, size.y * 0.1, 0.003), Vector3(0.0, y, zl + 0.0015))
	k.color = RUBBER
	k.box(Vector3(gap * 0.8, fy * 2.0, lt + 0.002), Vector3(0.0, 0.0, h.z - rec + (lt + 0.002) * 0.5))
	# The frame: a post down each long edge, a ring of rails and uprights round each end.
	k.color = WALK_FRAME
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			k.box(Vector3(post, post, size.z - 0.01), Vector3(sx * (h.x - 0.004 - post * 0.5), sy * (h.y - 0.004 - post * 0.5), 0.0))
	var pe := post * 0.85
	for sz: float in [-1.0, 1.0]:
		for s: float in [-1.0, 1.0]:
			k.box(Vector3(size.x - 0.012, pe, end - 0.006), Vector3(0.0, s * (h.y - 0.008 - pe * 0.5), sz * (h.z - end * 0.5 - 0.003)))
			k.box(Vector3(pe, size.y - 0.012, end - 0.008), Vector3(s * (h.x - 0.008 - pe * 0.5), 0.0, sz * (h.z - end * 0.5 - 0.004)))
	# Lock bars on the leaves: two a leaf with a keeper at each end and a handle; hinges
	# down the outer edges.
	var lb := minf(minf(0.05, size.x * 0.02), (0.85 * rec - 0.006) / 1.1)
	var bz := zl + 0.002 + lb * 0.5
	for sx: float in [-1.0, 1.0]:
		for t: float in [0.3, 0.7]:
			var x := sx * (gap * 0.5 + lw * t)
			k.color = GALVANISED
			k.box(Vector3(lb, fy * 1.88, lb), Vector3(x, 0.0, bz))
			k.box(Vector3(lw * 0.16, lb * 0.7, lb * 0.6), Vector3(x - sx * lw * 0.08, -fy * 0.2, bz + lb * 0.3))
			k.color = CAST
			for sy: float in [-1.0, 1.0]:
				k.box(Vector3(lb * 2.0, lb * 1.2, lb * 1.2), Vector3(x, sy * fy * 0.88, zl + 0.002 + lb * 0.5))
		k.color = GALVANISED
		for sy: float in [-1.0, 1.0]:
			k.box(Vector3(lb, lb * 2.5, lb * 1.1), Vector3(sx * (fx - lb * 0.5), sy * fy * 0.6, zl + lb * 0.55))
	# The data plate: pale enamel on the right leaf between its two lock bars, high up,
	# proud of the stripe band, with a bolt head in each corner and stencilled lines on it.
	var pw := minf(0.32, (lw * 0.4 - lb) * 0.78)
	var ph := pw * 0.62
	var pc := Vector3((gap + lw) * 0.5, clampf(fy * 0.35, 0.0, fy * 0.88 - lb - ph * 0.5), zl + 0.0045)
	k.color = PLATE
	k.box(Vector3(pw, ph, 0.007), pc)
	var pf := pc.z + 0.0035                                 # the plate's front face
	var pb := clampf(pw * 0.06, 0.006, 0.014)               # bolt head, m
	k.color = FLANGE_BOLT
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			k.box(Vector3(pb, pb, 0.004), Vector3(pc.x + sx * (pw * 0.5 - pb * 1.2), pc.y + sy * (ph * 0.5 - pb * 1.2), pf + 0.002))
	k.color = DARK
	var lh := ph * 0.07
	var widths: Array[float] = [0.7, 0.55, 0.62, 0.4]     # the stencilled lines, of the plate's width
	for i in 4:
		var w := pw * widths[i]
		var y := pc.y + ph * 0.28 - ph * 0.17 * float(i)
		var x := pc.x - pw * 0.35 + w * 0.5
		k.quad(Vector3(x - w * 0.5, y - lh * 0.5, pf + 0.001), Vector3(x + w * 0.5, y - lh * 0.5, pf + 0.001),
				Vector3(x + w * 0.5, y + lh * 0.5, pf + 0.001), Vector3(x - w * 0.5, y + lh * 0.5, pf + 0.001), Vector3.BACK)
	# Corner castings, a dark twist-lock hole in each end and top face.
	var cs := post + 0.012
	var cl := minf(cs * 1.1, end - 0.004)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var c := Vector3(sx * (h.x - cs * 0.5), sy * (h.y - cs * 0.5), sz * (h.z - cl * 0.5))
				k.color = CAST
				k.box(Vector3(cs, cs, cl), c)
				k.color = DARK
				var e := Vector3(c.x, c.y, sz * (h.z + 0.002))
				k.quad(e + Vector3(-cs * 0.25, -cs * 0.15, 0), e + Vector3(cs * 0.25, -cs * 0.15, 0),
						e + Vector3(cs * 0.25, cs * 0.15, 0), e + Vector3(-cs * 0.25, cs * 0.15, 0), Vector3(0, 0, sz))
				if sy < 0.0:
					continue
				var u := Vector3(c.x, h.y + 0.002, c.z)
				k.quad(u + Vector3(-cs * 0.25, 0, -cl * 0.15), u + Vector3(cs * 0.25, 0, -cl * 0.15),
						u + Vector3(cs * 0.25, 0, cl * 0.15), u + Vector3(-cs * 0.25, 0, cl * 0.15), Vector3.UP)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size.x * size.y * size.z
	var col := BoxShape3D.new()
	col.size = size
	shape.collision = col
	return shape


## A comms mast `height` tall (base on -Y) with a dish `dish` in radius facing +Y at its
## top: a chamfered bolted foot, a round anodised mast with galvanised collars and a plastic
## junction box, the dish (anodised rim, galvanised ribs under it) on a galvanised hub, a
## ceramic feed horn held over it on three galvanised struts, and a red aviation light on a
## rubber gasket on the feed (the glow) at the very top.
static func antenna(height: float, dish: float, glow := Color(1.0, 0.12, 0.08)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var y0 := -height * 0.5
	var top := height * 0.5 + 0.02             # the light's tip (the old dish lip's height), m
	var dd := dish * 0.3                        # dish depth, m
	var t := clampf(dish * 0.04, 0.008, 0.02)   # dish shell, m
	var lr := clampf(dish * 0.09, 0.025, 0.045) # aviation light radius, m
	var rh := dish * 0.12                       # feed horn mouth radius, m
	var fh := dish * 0.14                       # feed horn height, m
	var yr := top - (lr * 1.05 + 0.012 + fh + dish * 0.18)   # dish rim, m
	var yb := yr - dd                           # dish centre, m
	var yf := yr + dish * 0.18                  # feed horn mouth, m
	# Foot: a chamfered flange with four bolts, a block on it.
	k.color = Color.WHITE
	k.loft(_chamfer_ring(0.15, y0, 0.03), _chamfer_ring(0.15, y0 + 0.04, 0.03))
	k.loft(_chamfer_ring(0.1, y0 + 0.04, 0.025), _chamfer_ring(0.1, y0 + 0.12, 0.025))
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_thrusters_bolt(k, Vector3(sx * 0.122, y0 + 0.04, sz * 0.122), 0.014, 0.01)
	# The mast, collars along it and a junction box low on its +Z side.
	k.color = ANODISED
	var mr := 0.032
	_tube(k, Vector3(0.0, y0 + 0.12, 0.0), Vector3(0.0, yb - 0.02, 0.0), mr, 8)
	k.color = GALVANISED
	var mast := yb - 0.02 - (y0 + 0.12)
	var collars := clampi(int(mast / 0.45), 1, 5)
	for i in collars + 1:
		var y := y0 + 0.12 + 0.025 + (mast - 0.07) * float(i) / float(collars)
		_tube(k, Vector3(0.0, y - 0.02, 0.0), Vector3(0.0, y + 0.02, 0.0), mr * 1.45, 8)
	if mast > 0.5:
		k.color = PLASTIC_DARK
		k.box(Vector3(0.08, 0.12, 0.05), Vector3(0.0, y0 + 0.12 + mast * 0.3, mr + 0.024))
	# The dish's hub, the dish (a bowl: material face and back, bright rim) and its ribs.
	k.color = GALVANISED
	_thrusters_ring(k, 0.0, minf(0.06, dish * 0.22), yb - 0.05, yb + t * 0.5, 10)
	var prof := PackedVector2Array([Vector2(0.0, yb)])
	var cols: Array[Color] = []
	for r: float in [0.4, 0.75, 1.0]:
		prof.append(Vector2(dish * r, yb + dd * r * r))
		cols.append(Color.WHITE)
	prof.append(Vector2(dish * 0.985, yr + t))
	cols.append(ANODISED)
	for r: float in [0.75, 0.4]:
		prof.append(Vector2(dish * r, yb + dd * r * r + t))
		cols.append(ANODISED if r > 0.7 else Color.WHITE)
	prof.append(Vector2(0.0, yb + t))
	cols.append(Color.WHITE)
	cols.append(Color.WHITE)
	_piping_spin(k, Vector3.ZERO, Vector3.UP, prof, cols, 18)
	var rt := clampf(dish * 0.03, 0.008, 0.02)
	k.color = GALVANISED
	for i in 6:
		var a := TAU * (float(i) + 0.5) / 6.0
		var d := Vector3(cos(a), 0.0, sin(a))
		var pts: Array[Vector3] = []
		for r: float in [0.12, 0.4, 0.75, 0.96]:
			pts.append(d * dish * r + Vector3(0.0, yb + dd * r * r - rt * 0.6, 0.0))
		for j in 3:
			k.strut(pts[j], pts[j + 1], rt)
	# The feed: three struts from the rim up to a horn whose mouth faces the dish.
	var st := clampf(dish * 0.025, 0.006, 0.015)
	for i in 3:
		var a := TAU * float(i) / 3.0 + PI * 0.5
		k.strut(Vector3(cos(a), 0.0, sin(a)) * dish * 0.9 + Vector3(0.0, yr + t * 0.3, 0.0),
				Vector3(cos(a), 0.0, sin(a)) * rh * 0.5 + Vector3(0.0, yf + fh * 0.5, 0.0), st)
	_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(0.0, yf), Vector2(rh, yf),
			Vector2(rh * 0.45, yf + fh), Vector2(0.0, yf + fh)]), [DARK, WPN_RADOME, WPN_RADOME] as Array[Color], 10)
	# The aviation light's base on the feed: a rubber gasket.
	k.color = RUBBER
	_thrusters_ring(k, 0.0, lr * 0.9, yf + fh, yf + fh + 0.012, 8)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = k.volume()
	var col := ConvexPolygonShape3D.new()
	var hull := PackedVector3Array()
	for p in _chamfer_ring(0.15, y0, 0.03):
		hull.append(p)
	for i in 12:
		var a := TAU * float(i) / 12.0
		hull.append(Vector3(cos(a) * dish, yr + t, sin(a) * dish))
		hull.append(Vector3(cos(a) * dish, yr - t, sin(a) * dish))
	hull.append(Vector3(0.0, top, 0.0))
	col.points = hull
	shape.collision = col
	# The red aviation light: a domed lens.
	var g := MeshKit.new()
	var yl := yf + fh + 0.012
	g.lathe(PackedVector2Array([Vector2(0.0, yl), Vector2(lr, yl), Vector2(lr, yl + lr * 0.4),
			Vector2(lr * 0.6, yl + lr * 0.9), Vector2(0.0, top)]), 10)
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A gun turret, `radius` the ring's: a cast iron foot flange with a circle of blackened
## bolts and a ring with a rubber-sealed traverse race, an angular housing with a sloped
## glacis toward -Z and raised cheek armour (a seam down each), a gunmetal sight block with a
## lit lens (PartShape.glow), a cast roof hatch and rear vent slots, and two gunmetal barrels
## out of a bolted cast mantlet, each in a ribbed rubber boot at the root, with a collar, a
## recoil sleeve, a clamp and a slotted muzzle brake. Stands on -Y, barrels toward -Z,
## reaching `barrel` past the housing's front.
static func turret(radius: float, barrel: float, glow := Color(1.0, 0.18, 0.1)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var r := radius
	var base := r * 0.4
	var yb := -base * 0.5                     # the foot, m
	var yt := base * 0.5                      # the ring's top: the housing sits here, m
	var shelf := yb + base * 0.22             # the flange's top, m
	# The ring: a bolted foot flange, the ring body, a dark traverse race under the housing.
	k.color = CAST
	k.lathe(PackedVector2Array([Vector2(0.0, yb), Vector2(r, yb), Vector2(r, shelf - r * 0.02),
			Vector2(r * 0.98, shelf), Vector2(0.0, shelf)]), 24)
	k.color = FLANGE_BOLT
	_piping_bolts(k, Vector3(0.0, shelf, 0.0), Vector3.UP, 0.0, 16, r * 0.95, r * 0.04, r * 0.025)
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(0.0, shelf), Vector2(r * 0.9, shelf), Vector2(r * 0.9, yt - base * 0.22),
			Vector2(r * 0.86, yt - base * 0.16), Vector2(0.0, yt - base * 0.16)]), 24)
	k.color = RUBBER
	k.lathe(PackedVector2Array([Vector2(0.0, yt - base * 0.16), Vector2(r * 0.8, yt - base * 0.16),
			Vector2(r * 0.8, yt), Vector2(0.0, yt)]), 24)
	# The housing: an angular block, its front sloping down to the mantlet, under a roof
	# low enough that the sight block stays inside the old outline.
	var hx := r * 0.6
	var hz := r * 0.65
	var hh := r * 0.42
	var side := PackedVector2Array([Vector2(-hz, yt), Vector2(hz, yt), Vector2(hz, yt + hh * 0.75),
			Vector2(hz * 0.8, yt + hh), Vector2(-hz * 0.25, yt + hh), Vector2(-hz, yt + hh * 0.5)])
	k.color = Color.WHITE
	_prism_x(k, side, -hx, hx)
	# Cheek armour on both sides, standing proud, a dark seam down each.
	var cheek := _weapons_inset(side, Vector2(0.0, yt + hh * 0.5), 0.82)
	for sx: float in [-1.0, 1.0]:
		k.color = Color.WHITE
		_prism_x(k, cheek, sx * (hx - 0.01), sx * (hx + 0.012))
		k.color = DARK
		k.box(Vector3(0.006, hh * 0.66, r * 0.03), Vector3(sx * (hx + 0.014), yt + hh * 0.5, hz * 0.15))
	# Three vent slots in the back.
	for i in 3:
		k.box(Vector3(hx * 0.9, r * 0.03, 0.006), Vector3(0.0, yt + hh * (0.25 + 0.17 * float(i)), hz + 0.003))
	# The sight block on the roof (lens toward -Z) and a round hatch beside it.
	var sy := yt + hh + r * 0.04
	k.color = GUNMETAL
	k.box(Vector3(r * 0.2, r * 0.08, r * 0.26), Vector3(hx * 0.5, sy, hz * 0.05))
	_weapons_lens(k, g, Vector3(hx * 0.5, sy, hz * 0.05 - r * 0.13), r * 0.05)
	k.color = CAST
	_electrical_lathe_at(k, PackedVector2Array([Vector2(0.0, yt + hh), Vector2(r * 0.13, yt + hh),
			Vector2(r * 0.12, yt + hh + r * 0.025), Vector2(0.0, yt + hh + r * 0.025)]), 12,
			Vector3(-hx * 0.45, 0.0, hz * 0.4))
	# The mantlet: a bolted block across the front, the barrels out of it.
	var by := yt + hh * 0.36
	var bx := r * 0.28
	var front := -hz - r * 0.06
	k.color = CAST
	k.box(Vector3(r * 0.86, hh * 0.4, r * 0.07), Vector3(0.0, by, -hz - r * 0.025))
	k.color = FLANGE_BOLT
	for sx: float in [-1.0, 1.0]:
		_piping_bolts(k, Vector3(sx * r * 0.36, by, front), Vector3.FORWARD, 0.0, 2, hh * 0.13, r * 0.03, r * 0.015,
				PI * 0.5)
	var tip := -r * 0.65 - barrel
	var br := r * 0.07
	for sx: float in [-1.0, 1.0]:
		_weapons_barrel(k, Vector3(sx * bx, by, front), tip, br, br * 1.75, br * 1.45, br * 1.6,
				clampf(barrel * 0.13, 0.08, 0.3), WPN_BARREL)
	# A ribbed rubber boot round each barrel's root: four folds off the mantlet's face,
	# closing down onto the gunmetal collar so its front edge still shows.
	var boot := minf((front - tip) * 0.05, br * 2.0) * 0.8   # the collar's length, less a lip, m
	var folds := PackedVector2Array()
	for i in 9:
		folds.append(Vector2(br * (1.98 if i % 2 == 0 else 1.8), boot * float(i) / 8.0))
	folds.append(Vector2(br * 1.76, boot + 0.004))
	for sx: float in [-1.0, 1.0]:
		_piping_spin(k, Vector3(sx * bx, by, front + 0.002), Vector3.FORWARD, folds, [TREAD] as Array[Color], 10)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * r * r * base * 0.8 + hx * 2.0 * hz * 2.0 * hh * 0.82 + 2.0 * PI * br * br * barrel * 1.4
	var pts := PackedVector3Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector3(cos(a) * r, yb, sin(a) * r))
		pts.append(Vector3(cos(a) * r * 0.9, yt, sin(a) * r * 0.9))
	for p in side:
		pts.append(Vector3(-hx - 0.012, p.y, p.x))
		pts.append(Vector3(hx + 0.012, p.y, p.x))
	for sx: float in [-1.0, 1.0]:
		pts.append(Vector3(hx * 0.5 + sx * r * 0.1, sy + r * 0.04, hz * 0.05))
		for sy2: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * bx + br * 1.6, by + sy2 * br * 1.6, tip))
			pts.append(Vector3(sx * bx - br * 1.6, by + sy2 * br * 1.6, tip))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## `outline` (z, y points) shrunk toward `centre` by `f`: the outline of a raised armour
## plate on the face of a prism built from it.
static func _weapons_inset(outline: PackedVector2Array, centre: Vector2, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in outline:
		out.append(centre + (p - centre) * f)
	return out


## A sight block's lens on a -Z face at `at`: a dark bezel on `k`, a lit square lens `s`
## across on `g`.
static func _weapons_lens(k: MeshKit, g: MeshKit, at: Vector3, s: float) -> void:
	k.color = DARK
	k.box(Vector3(s * 1.7, s * 1.7, 0.006), at + Vector3(0.0, 0.0, -0.003))
	g.box(Vector3(s, s, 0.004), at + Vector3(0.0, 0.0, -0.008))


## A gun barrel along -Z from `from` (its root on a mantlet's face) to z = `tip`: a gunmetal
## collar `collar` round, a recoil sleeve `sleeve` round with chamfered ends over the first
## third, the barrel `br` round in `metal`, a blackened clamp band at 0.6, and a slotted
## heat-blued muzzle brake `brake` round and `brake_len` long at the tip.
static func _weapons_barrel(k: MeshKit, from: Vector3, tip: float, br: float, collar: float, sleeve: float,
		brake: float, brake_len: float, metal: Color) -> void:
	var length := from.z - tip
	var cl := minf(length * 0.05, br * 2.0)
	k.color = GUNMETAL
	_tube(k, from + Vector3(0.0, 0.0, 0.005), from + Vector3(0.0, 0.0, -cl), collar, 10)
	var s0 := cl
	var s1 := length * 0.32
	var ch := (sleeve - br) * 0.8
	_piping_spin(k, from, Vector3.FORWARD, PackedVector2Array([Vector2(br, s0), Vector2(sleeve, s0 + ch),
			Vector2(sleeve, s1 - ch), Vector2(br, s1)]), [metal] as Array[Color], 10)
	k.color = metal
	_tube(k, from + Vector3(0.0, 0.0, -s0), Vector3(from.x, from.y, tip + brake_len * 0.2), br, 10)
	k.color = FLANGE_BOLT
	var zc := from.z - length * 0.6
	_tube(k, Vector3(from.x, from.y, zc + br * 0.6), Vector3(from.x, from.y, zc - br * 0.6), br * 1.25, 10)
	_weapons_brake(k, Vector3(from.x, from.y, tip), brake, brake_len, br * 0.6)


## A slotted muzzle brake on a barrel along Z ending at `tip` (pointing -Z): `baffles`
## heat-blued steel rings `r` round, `length` long in all, the barrel showing in the slots
## between them, and a machined bore disc `bore` round standing just proud of the tip.
static func _weapons_brake(k: MeshKit, tip: Vector3, r: float, length: float, bore: float, baffles: int = 3,
		sides: int = 10) -> void:
	var step := length / float(baffles * 2 - 1)
	k.color = WPN_BLUED
	for i in baffles:
		var za := tip.z + step * float(i * 2)
		_tube(k, Vector3(tip.x, tip.y, za + step), Vector3(tip.x, tip.y, za), r, sides)
	k.color = GUN_BORE
	_tube(k, Vector3(tip.x, tip.y, tip.z + 0.004), Vector3(tip.x, tip.y, tip.z - 0.003), bore, sides)


## A hazard tab on a face at `c` facing `facing` along Z (+1 or -1): a yellow plate `w` by
## `h` with `stripes` dark slanted stripes over it.
static func _weapons_hazard(k: MeshKit, c: Vector3, w: float, h: float, facing: float, stripes: int = 3) -> void:
	k.color = PartShapes.ACCENT
	k.box(Vector3(w, h, 0.004), c + Vector3(0.0, 0.0, facing * 0.002))
	k.color = DARK
	var sw := w / float(stripes * 2)
	var z := c.z + facing * 0.006
	for i in stripes:
		var xa := c.x - w * 0.5 + sw * float(i * 2)
		k.quad(Vector3(xa, c.y - h * 0.5, z), Vector3(xa + sw, c.y - h * 0.5, z),
				Vector3(xa + sw * 2.0, c.y + h * 0.5, z), Vector3(xa + sw, c.y + h * 0.5, z), Vector3(0.0, 0.0, facing))


## A desk console `width` across: a recessed dark kick plinth, a keyboard shelf with a
## pale nosing lip, and a sloped face carrying one dark-bezelled screen per metre of width
## (the lit screen and a row of status LEDs are the glow), seams down the side panels and
## vent slats on the flat top. Stands on -Y, the operator at -Z.
static func console(width: float, height: float = 1.0, depth: float = 0.7,
		glow := Color(0.25, 0.7, 0.85)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var d := depth * 0.5
	var w := width * 0.5
	var kick_h := minf(0.08, height * 0.08)   # plinth height, m
	var kick := minf(0.05, depth * 0.1)       # plinth set back, m
	var shelf := depth * 0.2                  # keyboard shelf depth, m
	var y_desk := h - height * 0.35
	var zt := d * 0.15                        # where the slope meets the flat top
	var y_body := -h + kick_h
	# The recessed kick plinth, ribbed rubber.
	k.color = TREAD
	k.box(Vector3(width - 0.03, kick_h, depth - kick - 0.01), Vector3(0.0, -h + kick_h * 0.5, (kick - 0.01) * 0.5))
	# Body: the lower box up to the shelf, the sloped screen block behind it.
	k.color = Color.WHITE
	k.box(Vector3(width, y_desk - y_body, depth), Vector3(0.0, (y_desk + y_body) * 0.5, 0.0))
	var upper := PackedVector2Array([Vector2(-d + shelf, y_desk), Vector2(d, y_desk), Vector2(d, h), Vector2(zt, h)])
	_prism_x(k, upper, -w, w)
	# The nosing along the shelf's front edge, anodised.
	k.color = ANODISED
	k.box(Vector3(width - 0.02, 0.035, 0.03), Vector3(0.0, y_desk - 0.0115, -d + 0.007))
	# Side panel seams.
	k.color = DARK
	var seam_z := d * 0.35
	for sx: float in [-1.0, 1.0]:
		var x := sx * (w + 0.002)
		k.box(Vector3(0.004, y_desk + height * 0.25 - y_body, 0.012),
				Vector3(x, (y_desk + height * 0.25 + y_body) * 0.5 + 0.02, seam_z))
		k.box(Vector3(0.004, 0.012, seam_z - 0.006 - (-d + 0.04)), Vector3(x, y_desk - 0.05, (seam_z - 0.006 - d + 0.04) * 0.5))
	# Vent slats across the flat top.
	for i in 3:
		var z := zt + (d - zt) * (0.3 + 0.2 * float(i))
		k.box(Vector3(width * 0.4, 0.004, 0.02), Vector3(0.0, h + 0.002, z))
	# The sloped face: one screen section per metre.
	var s0 := Vector3(0.0, y_desk, -d + shelf)
	var s1 := Vector3(0.0, h, zt)
	var slope := s1 - s0
	var slen := slope.length()
	var v := slope / slen
	var nrm := Vector3(0.0, slope.z, -slope.y).normalized()
	var mid := (s0 + s1) * 0.5
	var n := maxi(1, int(round(width / 1.0)))
	var sec := (width - 0.08) / float(n)
	var g := MeshKit.new()
	for i in n:
		var x := -w + 0.04 + sec * (float(i) + 0.5)
		var c := mid + Vector3(x, 0.0, 0.0)
		k.color = PLASTIC_DARK
		_seating_pad(k, c, Vector3.RIGHT, v, nrm, sec * 0.43, slen * 0.4, 0.012, 0.004)
		# Keyboard on the shelf, two pale key rows on it.
		var kb_d := maxf(0.025, shelf - 0.05)
		var kb := Vector3(x, y_desk + 0.009, -d + 0.025 + kb_d * 0.5)
		k.box(Vector3(sec * 0.6, 0.018, kb_d), kb)
		k.color = PLASTIC_PALE
		for r: float in [-0.22, 0.22]:
			k.box(Vector3(sec * 0.5, 0.004, kb_d * 0.22), kb + Vector3(0.0, 0.011, kb_d * r))
		# The screen and three status LEDs under it, lit.
		_seating_pad(g, c + nrm * 0.0115 + v * slen * 0.06, Vector3.RIGHT, v, nrm, sec * 0.36, slen * 0.29, 0.004)
		for j in 3:
			var at := c + nrm * 0.0115 - v * slen * 0.32 + Vector3(sec * 0.3 - 0.04 * float(j), 0.0, 0.0)
			_seating_pad(g, at, Vector3.RIGHT, v, nrm, 0.012, 0.01, 0.004)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	var area := depth * (y_desk - y_body) + (h - y_desk) * ((2.0 * d - shelf) + (d - zt)) * 0.5
	shape.volume = width * area + (width - 0.03) * kick_h * (depth - kick)
	var pts := PackedVector3Array()
	for p: Vector2 in [Vector2(-d + kick, -h), Vector2(d, -h), Vector2(d, h), Vector2(zt, h),
			Vector2(-d + shelf, y_desk), Vector2(-d, y_desk), Vector2(-d, y_body)]:
		pts.append(Vector3(-w, p.y, p.x))
		pts.append(Vector3(w, p.y, p.x))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A seat `width` across and `height` tall: a bolted base plate, a pedestal on a swivel
## collar, a frame in the material colour carrying dark chamfered cushions (seat, back with
## side bolsters, a separate headrest on a narrower top), and armrests with dark pads.
## Stands on -Y, faces -Z (the backrest is at +Z).
static func seat(width: float = 0.6, height: float = 1.2) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var w := width * 0.5
	var d := width * 0.45                     # half the depth, m
	var y_pan := -h + height * 0.4 - 0.06     # top of the pan frame, m
	var head_h := minf(0.22, height * 0.18)   # headrest height, m
	var back_t := 0.05                        # back frame thickness, m
	var zb := d - back_t                      # front face of the back frame
	_seating_base(k, Vector3(0.0, -h, 0.0), width * 0.3, y_pan - 0.06 - (-h), width * 0.26)
	# Pan frame and the back frame, its top narrowed round the headrest.
	k.color = Color.WHITE
	k.box(Vector3(width - 0.02, 0.06, zb + d - 0.01), Vector3(0.0, y_pan - 0.03, (zb - d + 0.01) * 0.5))
	var y_top := h - head_h
	k.box(Vector3(width, y_top - (y_pan - 0.06), back_t), Vector3(0.0, (y_top + y_pan - 0.06) * 0.5, d - back_t * 0.5))
	k.box(Vector3(width * 0.55, head_h, back_t), Vector3(0.0, h - head_h * 0.5, d - back_t * 0.5))
	# A dark plastic panel let into the back, then the leather cushions.
	k.color = PLASTIC_DARK
	k.box(Vector3(width * 0.6, (y_top - y_pan) * 0.6, 0.004), Vector3(0.0, (y_top + y_pan) * 0.5, d + 0.002))
	k.color = SEAT_LEATHER
	_seating_pad(k, Vector3(0.0, y_pan, (zb - d + 0.02) * 0.5), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			w - 0.04, (zb + d - 0.02) * 0.5, 0.07, 0.025)
	var b_lo := y_pan + 0.08
	var b_hi := y_top - 0.03
	var bc := Vector3(0.0, (b_lo + b_hi) * 0.5, zb)
	_seating_pad(k, bc, Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, w - 0.075, (b_hi - b_lo) * 0.5, 0.06, 0.02)
	for sx: float in [-1.0, 1.0]:
		_seating_pad(k, bc + Vector3(sx * (w - 0.035), 0.0, 0.0), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
				0.03, (b_hi - b_lo) * 0.42, 0.1, 0.015)
	_seating_pad(k, Vector3(0.0, h - head_h * 0.5, zb), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
			width * 0.275 - 0.03, head_h * 0.5 - 0.03, 0.06, 0.02)
	# Armrests on two posts each, pads on top.
	var arm_y := y_pan + minf(0.22, height * 0.18)
	var z0 := -d + 0.04
	var z1 := zb - 0.13
	for sx: float in [-1.0, 1.0]:
		var ax := sx * (w - 0.025)
		k.color = Color.WHITE
		k.box(Vector3(0.05, 0.04, z1 - z0), Vector3(ax, arm_y, (z0 + z1) * 0.5))
		for z: float in [z0 + 0.03, z1 - 0.03]:
			k.box(Vector3(0.035, arm_y - 0.02 - y_pan, 0.035), Vector3(ax, (arm_y - 0.02 + y_pan) * 0.5, z))
		k.color = SEAT_ARM
		k.box(Vector3(0.044, 0.02, (z1 - z0) * 0.85), Vector3(ax, arm_y + 0.03, (z0 + z1) * 0.5))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = k.volume()
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, width * 0.9)
	shape.collision = col
	return shape


## A chamfered pad (cushion, bezel, screen) laid on a face: its base rectangle centred on
## `c`, `hu` either way along `u` and `hv` along `v`, rising `t` along `n`, the top edge
## inset `ch` all round.
static func _seating_pad(k: MeshKit, c: Vector3, u: Vector3, v: Vector3, n: Vector3, hu: float, hv: float,
		t: float, ch: float = 0.0) -> void:
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		a.append(c + u * s.x * hu + v * s.y * hv)
		b.append(c + n * t + u * s.x * (hu - ch) + v * s.y * (hv - ch))
	k.loft(a, b)


## A seat's foot: a chamfered base plate `half` either way on the floor at `at` with a
## bolt in each corner, a square pedestal `post` across rising to `rise` above the floor
## and a swivel collar on top. Plate and pedestal take the material colour.
static func _seating_base(k: MeshKit, at: Vector3, half: float, rise: float, post: float) -> void:
	var plate := 0.035
	k.color = Color.WHITE
	_seating_pad(k, at, Vector3.RIGHT, Vector3.BACK, Vector3.UP, half, half, plate, 0.015)
	k.box(Vector3(post, rise - plate - 0.04, post), at + Vector3(0.0, plate + (rise - plate - 0.04) * 0.5, 0.0))
	k.color = DETAIL
	k.box(Vector3(post * 1.6, 0.04, post * 1.6), at + Vector3(0.0, rise - 0.02, 0.0))
	var b := half - 0.04
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.03, 0.012, 0.03), at + Vector3(sx * b, plate + 0.006, sz * b))


## A two-high bunk `length` along Z, `width` (X) by `height`: four posts in the material
## colour on dark rubber feet, a rail frame round each deck over a dark base board, a
## chamfered mattress with a pillow at the -Z end and a folded blanket at the foot, a guard
## rail along both sides of the upper bunk's head half, and ladder rungs between the +Z end
## posts. Stands on -Y.
static func bunk(length: float = 2.0, width: float = 0.9, height: float = 1.9) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var hw := width * 0.5
	var hl := length * 0.5
	var post := 0.07
	var px := hw - post * 0.5
	var pz := hl - post * 0.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.color = Color.WHITE
			k.box(Vector3(post, height - 0.03, post), Vector3(sx * px, 0.015, sz * pz))
			k.color = DARK
			k.box(Vector3(post + 0.01, 0.03, post + 0.01), Vector3(sx * px, -h + 0.015, sz * pz))
	var y_up := -h + 1.25
	for y: float in [-h + 0.35, y_up]:
		# The deck frame (rails between the posts) round a dark base board.
		k.color = Color.WHITE
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(0.04, 0.08, length - 2.0 * post), Vector3(sx * (hw - 0.025), y - 0.04, 0.0))
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(width - 2.0 * post, 0.08, 0.04), Vector3(0.0, y - 0.04, sz * (hl - 0.025)))
		k.color = DARK
		k.box(Vector3(width - 0.09, 0.02, length - 0.09), Vector3(0.0, y - 0.01, 0.0))
		# Bedding.
		k.color = BUNK_MATTRESS
		_seating_pad(k, Vector3(0.0, y, 0.0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, hw - 0.05, hl - 0.075, 0.13, 0.03)
		k.color = BUNK_LINEN
		_seating_pad(k, Vector3(0.0, y + 0.13, -hl + 0.27), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
				hw - 0.16, 0.16, 0.08, 0.035)
		k.color = BUNK_BLANKET
		_seating_pad(k, Vector3(0.0, y + 0.13, hl - 0.38), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
				hw - 0.075, 0.28, 0.035, 0.01)
	# Guard rails along the upper bunk's head half, ladder rungs at the foot end.
	k.color = DETAIL
	var yr := minf(y_up + 0.3, h - 0.025)
	var zr := -hl + length * 0.55
	for sx: float in [-1.0, 1.0]:
		var x := sx * (hw - 0.025)
		_tube(k, Vector3(x, yr, -pz), Vector3(x, yr, zr), 0.018, 6)
		_tube(k, Vector3(x, y_up, zr), Vector3(x, yr, zr), 0.018, 6)
	var rungs := 3
	for i in rungs:
		var y := -h + 0.62 + (y_up - 0.1 - (-h + 0.62)) * float(i) / float(rungs - 1)
		_tube(k, Vector3(-px + post * 0.5, y, pz), Vector3(px - post * 0.5, y, pz), 0.016, 6)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * length * 0.12 * 2.0 + post * post * height * 4.0
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, length)
	shape.collision = col
	return shape


## A table `width` along X, `depth` along Z, `height` tall: a top in the material colour
## with chamfered corners and a rubber bumper band round its edge, a galvanised mounting
## plate under it, an eight-sided stainless pedestal with brushed steel collars, on a
## chamfered cast foot plate with a blackened bolt in each corner. Stands on -Y.
static func table(width: float = 1.8, depth: float = 0.9, height: float = 0.75) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var top_t := 0.045                                        # top slab, m
	var post := clampf(minf(width, depth) * 0.18, 0.09, 0.16) # pedestal across, m
	var foot := Vector2(minf(width * 0.5, 0.7), minf(depth * 0.6, 0.6))  # foot plate, m
	var plate := 0.03                                         # foot plate thickness, m
	var c := minf(0.05, minf(width, depth) * 0.08)            # corner chamfer, m
	# The top and the bumper band standing 4 mm proud round its edge.
	k.color = Color.WHITE
	_galley_slab(k, width - 0.008, depth - 0.008, c, h - top_t, h)
	k.color = RUBBER
	_galley_slab(k, width, depth, c + 0.002, h - top_t + 0.01, h - 0.012)
	# The mounting plate and the pedestal's upper collar.
	k.color = GALVANISED
	var mount := minf(post * 2.6, minf(width, depth) * 0.6)
	k.box(Vector3(mount, 0.02, mount), Vector3(0.0, h - top_t - 0.01, 0.0))
	var y_post0 := -h + plate
	var y_post1 := h - top_t - 0.02
	k.color = FURN_COLLAR
	k.box(Vector3(post * 1.35, 0.04, post * 1.35), Vector3(0.0, y_post1 - 0.02, 0.0))
	k.box(Vector3(post * 1.35, 0.04, post * 1.35), Vector3(0.0, y_post0 + 0.02, 0.0))
	# The pedestal: eight-sided, between the collars.
	k.color = STAINLESS
	k.loft(_chamfer_ring(post * 0.5, y_post0 + 0.04, post * 0.15), _chamfer_ring(post * 0.5, y_post1 - 0.04, post * 0.15))
	# The foot plate, chamfered and tapered, with a bolt in each corner.
	k.color = CAST
	_galley_slab(k, foot.x, foot.y, 0.04, -h, -h + plate, 0.012)
	k.color = FLANGE_BOLT
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.028, 0.012, 0.028), Vector3(sx * (foot.x * 0.5 - 0.045), -h + plate + 0.004, sz * (foot.y * 0.5 - 0.045)))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * depth * 0.06 + 0.03
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth)
	shape.collision = col
	return shape


## A flat slab `w` along X and `d` along Z with its corners cut by `c`, from y0 up to y1,
## its top edge pulled in by `inset` all round (a tapered plate), centred on x = 0, z = `z`.
static func _galley_slab(k: MeshKit, w: float, d: float, c: float, y0: float, y1: float, inset: float = 0.0,
		z: float = 0.0) -> void:
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for p in PartShapes._chamfer_rect(w, d, c):
		a.append(Vector3(p.x, y0, p.y + z))
	for p in PartShapes._chamfer_rect(w - inset * 2.0, d - inset * 2.0, maxf(c - inset * 0.6, 0.002)):
		b.append(Vector3(p.x, y1, p.y + z))
	k.loft(a, b)


## Twelve points round an oval `rx` across X and `rz` along Z, centred on (0, y, z).
static func _galley_oval(rx: float, rz: float, y: float, z: float) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		ring.append(Vector3(cos(a) * rx, y, z + sin(a) * rz))
	return ring


## A curved slab round the Y axis: from radius r0 out to r1, between angles a0 and a1
## (radians from -Z toward +X), from y0 up to y1, in `segs` facets (shower doors, bands).
static func _galley_arc(k: MeshKit, r0: float, r1: float, a0: float, a1: float, y0: float, y1: float,
		segs: int) -> void:
	var lo := Vector3(0.0, y0, 0.0)
	var hi := Vector3(0.0, y1, 0.0)
	for i in segs:
		var t0 := lerpf(a0, a1, float(i) / float(segs))
		var t1 := lerpf(a0, a1, float(i + 1) / float(segs))
		var d0 := Vector3(sin(t0), 0.0, -cos(t0))
		var d1 := Vector3(sin(t1), 0.0, -cos(t1))
		var dm := (d0 + d1).normalized()
		k.quad(d0 * r1 + lo, d1 * r1 + lo, d1 * r1 + hi, d0 * r1 + hi, dm)
		k.quad(d0 * r0 + lo, d1 * r0 + lo, d1 * r0 + hi, d0 * r0 + hi, -dm)
		k.quad(d0 * r0 + hi, d1 * r0 + hi, d1 * r1 + hi, d0 * r1 + hi, Vector3.UP)
		k.quad(d0 * r0 + lo, d1 * r0 + lo, d1 * r1 + lo, d0 * r1 + lo, Vector3.DOWN)
	for e: Array in [[a0, -1.0], [a1, 1.0]]:
		var t: float = e[0]
		var d := Vector3(sin(t), 0.0, -cos(t))
		k.quad(d * r0 + lo, d * r1 + lo, d * r1 + hi, d * r0 + hi, Vector3(cos(t), 0.0, sin(t)) * float(e[1]))


static func locker(width: float = 0.8, height: float = 1.9, depth: float = 0.5) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var d := depth * 0.5
	var plinth := 0.08
	var cap := 0.04
	# The carcass on a recessed dark plinth, a cap rim round its top.
	var body_h := height - plinth - cap
	k.box(Vector3(width, body_h, depth), Vector3(0.0, -h + plinth + body_h * 0.5, 0.0))
	k.box(Vector3(width + 0.01, cap, depth + 0.01), Vector3(0.0, h - cap * 0.5, 0.0))
	k.color = DARK
	k.box(Vector3(width - 0.04, plinth, depth - 0.06), Vector3(0.0, -h + plinth * 0.5, 0.03))
	# A dark recess across the front, two door leaves over it: the gap between them is the
	# seam, the margin round them the frame.
	var door_bottom := -h + plinth + 0.03
	var door_top := h - cap - 0.03
	var dh := door_top - door_bottom
	var dy := (door_top + door_bottom) * 0.5
	k.box(Vector3(width - 0.03, dh + 0.012, 0.004), Vector3(0.0, dy, -d - 0.002))
	var gap := 0.012
	var dw := (width - 0.05 - gap) * 0.5
	var face := -d - 0.018
	for sx: float in [-1.0, 1.0]:
		var cx := sx * (gap * 0.5 + dw * 0.5)
		k.color = Color.WHITE
		k.box(Vector3(dw, dh, 0.014), Vector3(cx, dy, -d - 0.011))
		# Louvre vents near the top and the bottom of each leaf.
		k.color = DARK
		for i in 3:
			for y: float in [door_top - 0.07 - 0.035 * float(i), door_bottom + 0.07 + 0.035 * float(i)]:
				k.box(Vector3(dw * 0.6, 0.014, 0.006), Vector3(cx, y, face - 0.003))
		# Two hinge knuckles on the outer edge, a handle and lock by the seam.
		for y: float in [door_top - 0.28, door_bottom + 0.28]:
			k.box(Vector3(0.02, 0.09, 0.02), Vector3(sx * (width * 0.5 - 0.02), y, face + 0.003))
		k.box(Vector3(0.036, 0.036, 0.006), Vector3(sx * (gap * 0.5 + 0.04), dy - 0.08, face - 0.003))
		k.color = DETAIL
		k.box(Vector3(0.024, 0.16, 0.02), Vector3(sx * (gap * 0.5 + 0.04), dy + 0.06, face - 0.01))
		k.color = PLATE
		k.box(Vector3(dw * 0.45, 0.05, 0.004), Vector3(cx, door_top - 0.24, face - 0.002))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * depth * 0.15
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth)
	shape.collision = col
	return shape


# --- SE2-style exterior parts (0.23 additions) ------------------------------------------

## A square thruster housing `width` across, `length` deep along Y, its nozzle in the +Y
## face. A chamfered housing on a mount flange with a bolt in each corner, cooling fins on
## the X sides (anodised), pale enamel panels screwed on the Z sides (status lamps in a
## plastic bezel on -Z), blackened corner bolts, and a hollow nozzle: a heat-tinted rim, a
## sooted ceramic liner stepped down the bore, a crossed titanium ion grid over a glowing
## floor and a lit ring on the step (PartShape.glow).
static func ion_thruster(width: float, length: float, glow := Color(0.35, 0.65, 1.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var w := width
	var h := length * 0.5
	var y0 := -h + length * 0.78               # the housing's face, m
	var c := w * 0.07                          # corner chamfer, m
	var hb := w * 0.47                         # housing half width above the flange, m
	var bev := w * 0.025                       # bevel round the face, m
	var fl := clampf(length * 0.08, 0.02, 0.1) # mount flange, m
	var r_in := w * 0.32                       # nozzle bore, m
	var r2 := r_in * 0.74                      # bore below the step, m
	var yg := -h + length * 0.36               # nozzle floor, m
	var y_low := yg - clampf(length * 0.03, 0.006, 0.03)
	var ym := lerpf(yg, y0, 0.55)              # the step in the bore, m
	# Housing: a chamfered mount flange, a chamfered body with a bevelled face round the
	# nozzle bore (hollow down to the floor).
	k.loft(_chamfer_ring(w * 0.5, -h, c * 1.1), _chamfer_ring(w * 0.5, -h + fl, c * 1.1))
	k.loft(_chamfer_ring(hb, -h + fl, c), _chamfer_ring(hb, y_low, c))
	k.loft(_chamfer_ring(hb, y_low, c), _chamfer_ring(hb, y0 - bev, c), false)
	k.loft(_chamfer_ring(hb, y0 - bev, c), _chamfer_ring(hb - bev, y0, c), false)
	_thrusters_holed_face(k, hb - bev, c, y0, r_in, y_low, ENG_LINER)
	# The rim collar, its lip overhanging the bore a little.
	k.color = ENG_NOZZLE
	var r_base := w * 0.42
	k.lathe(PackedVector2Array([Vector2(r_in * 0.97, y0), Vector2(r_base, y0), Vector2(r_base, lerpf(y0, h, 0.3)),
			Vector2(w * 0.39, h), Vector2(r_in * 0.97, h)]), 24)
	# The bore: a floor, a stepped liner and an ion grid of crossed bars over the glow.
	k.color = DARK
	_thrusters_ring(k, 0.0, r_in, y_low, yg, 16)
	k.color = ENG_LINER
	_thrusters_ring(k, r2, r_in, yg, ym, 20)
	k.color = ENG_ION_GRID
	var bt := maxf(0.008, r2 * 0.07)
	var yb := lerpf(yg, ym, 0.45)
	for i in 3:
		var off := r2 * 0.5 * float(i - 1)
		var span := 2.0 * sqrt(r2 * r2 - off * off) * 0.98
		k.box(Vector3(bt, bt, span), Vector3(off, yb, 0.0))
		k.box(Vector3(span, bt, bt), Vector3(0.0, yb + bt * 0.5, off))
	# Hex bolts in the face's corners.
	var bolt_r := maxf(0.008, w * 0.028)
	var bolt_h := clampf(w * 0.02, 0.005, 0.02)
	k.color = FLANGE_BOLT
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_thrusters_bolt(k, Vector3(sx * w * 0.335, y0, sz * w * 0.335), bolt_r, bolt_h)
	# Cooling fins down the X sides, a panel on each Z side (seamed, screwed down); the -Z
	# one carries a dark bezel with two status lamps.
	var side_lo := -h + fl + (y0 - bev + h - fl) * 0.12
	var side_hi := y0 - bev - (y0 - bev + h - fl) * 0.12
	var fin_t := clampf(length * 0.035, 0.008, 0.05)
	var fin_out := w * 0.028
	k.color = ANODISED
	for sx: float in [-1.0, 1.0]:
		for i in 4:
			var y := lerpf(side_lo, side_hi, (float(i) + 0.5) / 4.0)
			k.box(Vector3(fin_out + 0.004, fin_t, w * 0.66), Vector3(sx * (hb + fin_out * 0.5 - 0.002), y, 0.0))
	var pt := clampf(w * 0.012, 0.004, 0.02)
	var ph := side_hi - side_lo
	var pm := (side_lo + side_hi) * 0.5
	for sz: float in [-1.0, 1.0]:
		k.color = ENG_PANEL
		k.box(Vector3(w * 0.62, ph, pt + 0.002), Vector3(0.0, pm, sz * (hb + pt * 0.5 - 0.001)))
		k.color = STAINLESS
		for cx: float in [-1.0, 1.0]:
			for cy: float in [-1.0, 1.0]:
				k.box(Vector3(bolt_r * 1.2, bolt_r * 1.2, 0.006),
						Vector3(cx * w * 0.27, pm + cy * (ph * 0.5 - bolt_r * 1.4), sz * (hb + pt + 0.002)))
	var led := clampf(w * 0.035, 0.012, 0.05)
	var led_y := pm + ph * 0.18
	var bz := hb + pt + 0.002
	k.color = PLASTIC_DARK
	k.box(Vector3(led * 4.6, led * 2.0, 0.006), Vector3(0.0, led_y, -bz))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = (w * w * (y0 + h) * 0.96 - PI * r_in * r_in * (y0 - y_low)) + PI * (r_base * r_base - r_in * r_in) * (h - y0)
	var col := BoxShape3D.new()
	col.size = Vector3(width, length, width)
	shape.collision = col
	# The glow: the floor of the bore behind the grid, a ring on the step and two lamps.
	var g := MeshKit.new()
	_thrusters_ring(g, 0.0, r2 * 0.92, yg + 0.002, yg + 0.002 + clampf(length * 0.02, 0.004, 0.02), 16)
	_thrusters_ring(g, lerpf(r2, r_in, 0.2), lerpf(r2, r_in, 0.6), ym, ym + 0.004, 20)
	for sx: float in [-1.0, 1.0]:
		g.box(Vector3(led, led, 0.004), Vector3(sx * led * 1.2, led_y, -bz - 0.004))
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A ring (or, from radius 0, a disc) `r0`..`r1` round Y from y0 to y1: one convex lathe.
static func _thrusters_ring(k: MeshKit, r0: float, r1: float, y0: float, y1: float, segments: int) -> void:
	k.lathe(PackedVector2Array([Vector2(r0, y0), Vector2(r1, y0), Vector2(r1, y1), Vector2(r0, y1)]), segments)


## A six-sided bolt head `radius` across standing `height` up (+Y) from `at`.
static func _thrusters_bolt(k: MeshKit, at: Vector3, radius: float, height: float) -> void:
	var ring_a := PackedVector3Array()
	var ring_b := PackedVector3Array()
	for i in 6:
		var a := TAU * (float(i) + 0.5) / 6.0
		ring_a.append(at + Vector3(cos(a) * radius, -0.002, sin(a) * radius))
		ring_b.append(at + Vector3(cos(a) * radius, height, sin(a) * radius))
	k.loft(ring_a, ring_b)


## The top of a chamfered square housing (`half`, corner `c`) at `y`, facing +Y, with a
## round hole `hole_r` through it whose wall (in `wall` colour) runs down to `y_bottom`.
static func _thrusters_holed_face(k: MeshKit, half: float, c: float, y: float, hole_r: float, y_bottom: float,
		wall: Color) -> void:
	var corners := _chamfer_ring(half, y, c)
	var outer := PackedVector3Array()
	for i in corners.size():
		var a := corners[i]
		var b := corners[(i + 1) % corners.size()]
		for s in 3:
			outer.append(a.lerp(b, float(s) / 3.0))
	var inner := PackedVector3Array()
	for p in outer:
		var d := Vector2(p.x, p.z).normalized() * hole_r
		inner.append(Vector3(d.x, y, d.y))
	var body := k.color
	var n := outer.size()
	for i in n:
		var j := (i + 1) % n
		k.color = body
		k.quad(outer[i], outer[j], inner[j], inner[i], Vector3.UP)
		k.color = wall
		var lo_i := Vector3(inner[i].x, y_bottom, inner[i].z)
		var lo_j := Vector3(inner[j].x, y_bottom, inner[j].z)
		var mid := (inner[i] + inner[j]) * 0.5
		k.quad(inner[i], inner[j], lo_j, lo_i, Vector3(-mid.x, 0.0, -mid.z))
	k.color = body


## A bar `length` along X with `lamps` recessed lamps on its +Y face: a chamfered housing on
## a dark bolted foot, a visor leaning over the lamps from +Z, each lamp a dark bezel round a
## reflector sloping down to a lit lens.
static func headlamp_bar(length: float, lamps: int = 4, glow := Color(1.0, 0.97, 0.9)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hl := length * 0.5
	var y_base := -0.11
	var y_foot := -0.09
	var y_face := 0.11
	# The lamp housing: a chamfered bar on a dark mounting foot (bolted down at the ends).
	var bz := 0.13
	var c := 0.03
	_prism_x(k, PackedVector2Array([Vector2(-bz, y_foot), Vector2(bz, y_foot), Vector2(bz, y_face - c),
			Vector2(bz - c, y_face), Vector2(-bz + c, y_face), Vector2(-bz, y_face - c)]), -hl + 0.006, hl - 0.006)
	k.color = DARK
	k.box(Vector3(length, y_foot - y_base, 0.31), Vector3(0.0, (y_foot + y_base) * 0.5, 0.0))
	# The visor: a dark lip leaning out over the lamps from the face's +Z edge.
	_prism_x(k, PackedVector2Array([Vector2(0.078, y_face), Vector2(0.1, y_face), Vector2(0.086, 0.158),
			Vector2(0.064, 0.158)]), -hl + 0.012, hl - 0.012)
	k.color = DETAIL
	var bolt_x: Array[float] = [-hl + 0.03, hl - 0.03]
	if lamps >= 3:
		bolt_x.append(0.0)
	for x: float in bolt_x:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.018, 0.012, 0.012), Vector3(x, y_foot + 0.006, sz * 0.1425))
	# Each lamp: a dark rectangular bezel round a pale reflector that slopes down into the
	# lens (the glow), set a little below the visor so it reads recessed.
	var pitch := length / float(lamps)
	var hx := pitch * 0.42
	var hz := 0.075
	var zc := -0.016
	var g := MeshKit.new()
	for i in lamps:
		var at := Vector3(-hl + pitch * (float(i) + 0.5), y_face, zc)
		k.color = DARK
		_lights_rect_band(k, at, hx, hz, PackedVector2Array([Vector2(-0.01, 0.0), Vector2(0.0, 0.0),
				Vector2(0.0, 0.026), Vector2(-0.005, 0.034), Vector2(-0.01, 0.034)]), true)
		k.color = REFLECTOR
		_lights_rect_band(k, at, hx, hz, PackedVector2Array([Vector2(-0.02, 0.0), Vector2(-0.0102, 0.0),
				Vector2(-0.0102, 0.03), Vector2(-0.02, 0.004)]), true)
		_lights_rect_band(g, at, hx, hz, PackedVector2Array([Vector2(-0.018, 0.006), Vector2(-0.024, 0.015)]), false)
		var ex := hx - 0.024
		var ez := hz - 0.024
		g.poly(PackedVector3Array([at + Vector3(-ex, 0.015, -ez), at + Vector3(ex, 0.015, -ez),
				at + Vector3(ex, 0.015, ez), at + Vector3(-ex, 0.015, ez)]), Vector3.UP)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = k.volume()
	var col := BoxShape3D.new()
	col.size = Vector3(length, 0.26, 0.31)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A rectangular band for the lights family: the profile's (s, y) points (s outward from
## the rectangle hx by hz round `at`, y up from it) spun round the four sides as quads.
static func _lights_rect_band(k: MeshKit, at: Vector3, hx: float, hz: float, profile: PackedVector2Array,
		closed: bool) -> void:
	var n := profile.size()
	var pc := Vector2.ZERO
	for p in profile:
		pc += p
	pc /= float(n)
	var edges := n if closed else n - 1
	for i in edges:
		var p := profile[i]
		var q := profile[(i + 1) % n]
		var e := q - p
		var out2 := Vector2(e.y, -e.x)
		if out2.dot((p + q) * 0.5 - pc) < 0.0:
			out2 = -out2
		if not closed:
			out2 = Vector2(absf(out2.x), absf(out2.y))
		var a := Vector2(hx + p.x, hz + p.x)
		var b := Vector2(hx + q.x, hz + q.x)
		for side in 4:
			var d := [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD][side] as Vector3
			var t := Vector3(-d.z, 0.0, d.x)
			var pa := d * (a.x if absf(d.x) > 0.5 else a.y)
			var ta := t * (a.y if absf(d.x) > 0.5 else a.x)
			var pb := d * (b.x if absf(d.x) > 0.5 else b.y)
			var tb := t * (b.y if absf(d.x) > 0.5 else b.x)
			var ya := Vector3(0.0, p.y, 0.0)
			var yb := Vector3(0.0, q.y, 0.0)
			k.quad(at + pa - ta + ya, at + pa + ta + ya, at + pb + tb + yb, at + pb - tb + yb, d * out2.x + Vector3.UP * out2.y)


## A straight pipe along Y, `radius` to the outside of the wall (in the part's paint), with a
## bare forged weld-neck flange at each end and a galvanised clamp band (its rubber liner
## showing at the edges) with a blackened bolt through its lug in the middle. Collision is
## the flange cylinder.
static func pipe(radius: float, length: float, flanged: bool = true) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := length * 0.5
	var fr := radius * 1.35
	# One lathe: a weld-neck flange at each end (face, rim, shoulder, a hub tapering into
	# the pipe), the pipe between them.
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(radius, 0.0), Vector2(radius, length), Vector2(0.0, length)])
	var cols: Array[Color] = [Color.WHITE]
	if flanged:
		var ft := minf(0.06, length * 0.1)
		var hub := minf(ft * 0.8, length * 0.08)
		var rh := radius * 1.12
		prof = PackedVector2Array([Vector2(0.0, 0.0), Vector2(fr, 0.0), Vector2(fr, ft), Vector2(rh, ft),
				Vector2(radius, ft + hub), Vector2(radius, length - ft - hub), Vector2(rh, length - ft),
				Vector2(fr, length - ft), Vector2(fr, length), Vector2(0.0, length)])
		cols = [DETAIL, DETAIL, DETAIL, DETAIL, Color.WHITE, DETAIL, DETAIL, DETAIL, DETAIL]
	_piping_spin(k, Vector3(0.0, -h, 0.0), Vector3.UP, prof, cols, 12)
	# A long span gets a support clamp in the middle: an eight-sided dark band with a
	# tightening lug and its bolt on +X.
	if length > 1.0:
		var w := 0.04
		_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(radius * 0.95, -w),
				Vector2(radius * 1.18, -w), Vector2(radius * 1.18, w), Vector2(radius * 0.95, w)]),
				[RUBBER, GALVANISED, RUBBER] as Array[Color], 8, PI / 8.0)
		if flanged:
			k.color = GALVANISED
			k.box(Vector3(fr - 0.002 - radius, w * 1.5, radius * 0.36), Vector3((fr - 0.002 + radius) * 0.5, 0.0, 0.0))
			var bs := maxf(radius * 0.14, 0.008)
			k.color = FLANGE_BOLT
			k.box(Vector3(bs, bs, radius * 0.62), Vector3(radius * 1.2, 0.0, 0.0))
	return _cylinder(k, fr if flanged else radius * 1.18, length)


## Spins `profile` (x = radius, y = distance along `axis` from `centre`) round `axis` in
## `segments` steps. The profile is open: walk it from the axis outward and along, solid
## on the inside, and each edge takes its colour from `colors` (the last repeats). The
## piping family's lathe: it can step in and out (flanges, hubs, beads), which
## MeshKit.lathe's convex outward test can't, and skips faces nobody sees.
static func _piping_spin(k: MeshKit, centre: Vector3, axis: Vector3, profile: PackedVector2Array,
		colors: Array[Color], segments: int, phase: float = 0.0) -> void:
	var u := Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.UP
	u = (u - axis * u.dot(axis)).normalized()
	var v := axis.cross(u)
	for s in segments:
		var a0 := phase + TAU * float(s) / float(segments)
		var a1 := phase + TAU * float(s + 1) / float(segments)
		var am := (a0 + a1) * 0.5
		var r0 := u * cos(a0) + v * sin(a0)
		var r1 := u * cos(a1) + v * sin(a1)
		var rm := u * cos(am) + v * sin(am)
		for i in profile.size() - 1:
			var p := profile[i]
			var q := profile[i + 1]
			k.color = colors[mini(i, colors.size() - 1)]
			var out := rm * (q.y - p.y) - axis * (q.x - p.x)
			k.quad(centre + axis * p.y + r0 * p.x, centre + axis * q.y + r0 * q.x,
					centre + axis * q.y + r1 * q.x, centre + axis * p.y + r1 * p.x, out)


## `count` square bolt heads `size` across and `height` tall standing on a flange face at
## distance `t` along `axis` from `centre`, on a circle `ring_r` round it, heads toward +axis.
static func _piping_bolts(k: MeshKit, centre: Vector3, axis: Vector3, t: float, count: int, ring_r: float,
		size: float, height: float, phase: float = PI * 0.25) -> void:
	var u := Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.UP
	u = (u - axis * u.dot(axis)).normalized()
	var v := axis.cross(u)
	for i in count:
		var a := phase + TAU * float(i) / float(count)
		var rad := u * cos(a) + v * sin(a)
		var tan_dir := v * cos(a) - u * sin(a)
		var c := centre + axis * t + rad * ring_r
		var s := size * 0.5
		var base := PackedVector3Array([c + rad * s + tan_dir * s, c + rad * s - tan_dir * s,
				c - rad * s - tan_dir * s, c - rad * s + tan_dir * s])
		var top := PackedVector3Array()
		for p in base:
			top.append(p + axis * height)
		k.loft(base, top, false)
		k.poly(top, axis)


## A 90 degree bend: enters along +Y at the origin (its -Y end), leaves toward +Z. The
## bend's centre line is a quarter circle of `bend` radius; both ends flanged, four bolt
## heads on the back of each flange.
static func pipe_elbow(radius: float, bend: float = 0.0) -> PartShapes.PartShape:
	if bend <= 0.0:
		bend = radius * 2.5
	var k := MeshKit.new()
	var steps := 6
	var rings: Array[PackedVector3Array] = []
	for i in steps + 1:
		var a := PI * 0.5 * float(i) / float(steps)
		var c := Vector3(0.0, sin(a) * bend, bend - cos(a) * bend)
		var t := Vector3(0.0, cos(a), sin(a))
		var u := Vector3.RIGHT
		var v := t.cross(u)
		var ring := PackedVector3Array()
		for j in 12:
			var b := TAU * float(j) / 12.0
			ring.append(c + (u * cos(b) + v * sin(b)) * radius)
		rings.append(ring)
	# The bend in the part's paint, open at both ends: the flanges close it.
	k.color = Color.WHITE
	for i in steps:
		k.loft(rings[i], rings[i + 1], false)
	# A weld-neck flange on each end (like `pipe`'s), each with four bolt heads on its back.
	var fr := radius * 1.35
	var ft := 0.06
	var rh := radius * 1.12
	var hub := minf(ft * 0.8, bend * 0.25)
	var flange := PackedVector2Array([Vector2(0.0, 0.0), Vector2(fr, 0.0), Vector2(fr, ft), Vector2(rh, ft),
			Vector2(radius * 0.98, ft + hub)])
	var end := Vector3(0.0, bend, bend)
	var bs := maxf(radius * 0.2, 0.01)
	for f: Array in [[Vector3.ZERO, Vector3.UP], [end, Vector3.FORWARD]]:
		_piping_spin(k, f[0], f[1], flange, [DETAIL] as Array[Color], 12)
		k.color = FLANGE_BOLT
		_piping_bolts(k, f[0], f[1], ft, 4, (rh + fr) * 0.5, bs, bs * 0.6)
	var flange_a := PackedVector3Array()
	for j in 12:
		var b := TAU * float(j) / 12.0
		flange_a.append(end + Vector3(cos(b) * fr, sin(b) * fr, 0.0))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * radius * radius * bend * PI * 0.5 * 0.4
	var col := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for ring in rings:
		pts.append_array(ring)
	pts.append_array(flange_a)
	col.points = pts
	shape.collision = col
	return shape


## A deck grating `width` (X) by `length` (Z), all galvanised steel: a frame of flat bars
## round the edge with a blackened bolt at each corner, thin bearing bars along Z about
## every 0.1 m and darker lower cross bars every 0.3 m, over a dark plate (the gaps). Bar counts follow the
## size; each bearing bar is three faces only (its ends hide in the frame).
static func grating(width: float, length: float, thickness: float = 0.05) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hx := width * 0.5
	var hz := length * 0.5
	var t := thickness
	var fw := minf(0.05, minf(width, length) * 0.1)   # frame bar width, m
	var top := t * 0.5 + 0.003                        # frame top, m
	var bar_top := t * 0.5                            # bearing bar top (the walking face), m
	var floor_y := -t * 0.5 + t * 0.3                 # top of the dark plate, m
	k.color = DARK
	k.box(Vector3(width - fw * 2.0, t * 0.3, length - fw * 2.0), Vector3(0.0, -t * 0.5 + t * 0.15, 0.0))
	k.color = GALVANISED
	var fh := top + t * 0.5
	var fy := (top - t * 0.5) * 0.5
	k.box(Vector3(width, fh, fw), Vector3(0.0, fy, -hz + fw * 0.5))
	k.box(Vector3(width, fh, fw), Vector3(0.0, fy, hz - fw * 0.5))
	k.box(Vector3(fw, fh, length - fw * 2.0), Vector3(-hx + fw * 0.5, fy, 0.0))
	k.box(Vector3(fw, fh, length - fw * 2.0), Vector3(hx - fw * 0.5, fy, 0.0))
	# Bearing bars along Z: a top and two sides each.
	var inner_x := width - fw * 2.0
	var bars := maxi(2, int(round(inner_x / 0.1)))
	var bw := 0.012
	var z0 := -hz + fw
	var z1 := hz - fw
	for i in range(1, bars):
		var x := -hx + fw + inner_x * float(i) / float(bars)
		var a := x - bw * 0.5
		var b := x + bw * 0.5
		k.quad(Vector3(a, bar_top, z0), Vector3(b, bar_top, z0), Vector3(b, bar_top, z1), Vector3(a, bar_top, z1), Vector3.UP)
		k.quad(Vector3(a, floor_y, z0), Vector3(a, bar_top, z0), Vector3(a, bar_top, z1), Vector3(a, floor_y, z1), Vector3.LEFT)
		k.quad(Vector3(b, floor_y, z0), Vector3(b, bar_top, z0), Vector3(b, bar_top, z1), Vector3(b, floor_y, z1), Vector3.RIGHT)
	# Cross bars along X, set a little below the bearing bars' tops.
	k.color = WALK_CROSS_BAR
	var inner_z := length - fw * 2.0
	var cross := maxi(1, int(round(inner_z / 0.3)))
	var ct := bar_top - 0.006
	var cw := 0.016
	for i in range(1, cross):
		var z := -hz + fw + inner_z * float(i) / float(cross)
		var a := z - cw * 0.5
		var b := z + cw * 0.5
		k.quad(Vector3(-hx + fw, ct, a), Vector3(hx - fw, ct, a), Vector3(hx - fw, ct, b), Vector3(-hx + fw, ct, b), Vector3.UP)
		k.quad(Vector3(-hx + fw, floor_y, a), Vector3(hx - fw, floor_y, a), Vector3(hx - fw, ct, a), Vector3(-hx + fw, ct, a), Vector3.FORWARD)
		k.quad(Vector3(-hx + fw, floor_y, b), Vector3(hx - fw, floor_y, b), Vector3(hx - fw, ct, b), Vector3(-hx + fw, ct, b), Vector3.BACK)
	# A bolt in each corner of the frame.
	k.color = FLANGE_BOLT
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(fw * 0.4, 0.008, fw * 0.4), Vector3(sx * (hx - fw * 0.5), top + 0.002, sz * (hz - fw * 0.5)))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * length * thickness * 0.5
	var col := BoxShape3D.new()
	col.size = Vector3(width, thickness, length)
	shape.collision = col
	return shape


## A power plant: a block `size` (x, y, z) on two galvanised skids standing on rubber
## anti-vibration pads (on steel shoes) at their ends, with anodised cooling
## fin packs down both sides, a bolted access panel on top, a cast flange with stainless
## bolts round a gunmetal coupling hub on its back (+Z) and, on its front (-Z), a galvanised
## intake grille and a status strip of lit segments in a plastic bezel (glow).
static func generator(size: Vector3, glow := Color(0.3, 1.0, 0.45)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := size.y * 0.5
	var front := -size.z * 0.46
	var back := size.z * 0.46
	var bx := size.x * 0.42
	# Skids along Z under the body, standing on rubber anti-vibration pads at their ends:
	# the pads take the bottom slice of the skid's height, inside its footprint.
	var sk := clampf(size.y * 0.06, 0.05, 0.09)
	var pad := clampf(sk * 0.4, 0.02, 0.03)                 # pad height, m
	var sw := size.x * 0.14                                 # skid width, m
	var sl := size.z * 0.93                                 # skid length, m
	var pl := clampf(size.z * 0.08, 0.08, 0.16)             # pad length, m
	for sx: float in [-1.0, 1.0]:
		k.color = GALVANISED
		k.box(Vector3(sw, sk - pad, sl), Vector3(sx * size.x * 0.28, -h + pad + (sk - pad) * 0.5, 0.0))
		for sz: float in [-1.0, 1.0]:
			var pz := sz * (sl * 0.5 - pl * 0.5 - 0.01)
			k.color = RUBBER
			k.box(Vector3(sw - 0.012, pad - 0.004, pl), Vector3(sx * size.x * 0.28, -h + 0.004 + (pad - 0.004) * 0.5, pz))
			# A steel shoe under the rubber, a touch wider than it, on the floor.
			k.color = GALVANISED
			k.box(Vector3(sw - 0.004, 0.004, pl + 0.012), Vector3(sx * size.x * 0.28, -h + 0.002, pz))
	# The body: chamfered along its top edges, stopping short of the top for the panel.
	k.color = Color.WHITE
	var top := h - 0.045
	var c := minf(size.x, size.y) * 0.07
	k.extrude(PackedVector2Array([Vector2(-bx, -h + sk), Vector2(bx, -h + sk), Vector2(bx, top - c),
			Vector2(bx - c, top), Vector2(-bx + c, top), Vector2(-bx, top - c)]), size.z * 0.92)
	# The access panel on top, with a bolt at each corner.
	var px := bx - c - 0.04
	var pz := size.z * 0.3
	k.box(Vector3(px * 2.0, 0.03, pz * 2.0), Vector3(0.0, top + 0.015, 0.0))
	k.color = FLANGE_BOLT
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.035, 0.015, 0.035), Vector3(sx * (px - 0.04), h - 0.0075, sz * (pz - 0.04)))
	# Fin packs: thin fins held between a top and a bottom rail.
	var fins := maxi(3, int(size.z / 0.22))
	k.color = ANODISED
	for i in fins:
		var z := -size.z * 0.46 + size.z * 0.92 * (float(i) + 0.5) / float(fins)
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(size.x * 0.1, size.y * 0.85, 0.04), Vector3(sx * size.x * 0.45, 0.0, z))
	k.color = RAIL_DARK
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			k.box(Vector3(size.x * 0.1 - 0.006, 0.04, size.z * 0.9),
					Vector3(sx * (size.x * 0.45 - 0.003), sy * (size.y * 0.425 + 0.02), 0.0))
	# The front: a dark bezel for the status strip, an intake grille, corner bolts.
	k.color = PLASTIC_DARK
	var strip_y := size.y * 0.25
	k.box(Vector3(size.x * 0.5, 0.1, 0.012), Vector3(0.0, strip_y, front - 0.006))
	k.color = DARK
	var grille_y := -h + sk + size.y * 0.22
	k.box(Vector3(size.x * 0.56, size.y * 0.3, 0.01), Vector3(0.0, grille_y, front - 0.005))
	k.color = GALVANISED
	for i in 4:
		var y := grille_y - size.y * 0.15 + size.y * 0.3 * (float(i) + 0.5) / 4.0
		k.box(Vector3(size.x * 0.52, 0.03, 0.02), Vector3(0.0, y, front - 0.015))
	k.color = FLANGE_BOLT
	for sx: float in [-1.0, 1.0]:
		for y: float in [top - c - 0.08, -h + sk + 0.07]:
			k.box(Vector3(0.035, 0.035, 0.015), Vector3(sx * (bx - 0.07), y, front - 0.0075))
	# The back: a dark flange, a ring of bolts and a chamfered coupling hub (round Z).
	var fr := minf(size.x, size.y) * 0.42
	var tf := size.z * 0.02
	var deep := size.z * 0.04 - 0.002
	var from := k.verts.size()
	k.color = CAST
	k.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(fr, 0.0), Vector2(fr, tf), Vector2(0.0, tf)]), 20)
	k.color = GUNMETAL
	k.lathe(PackedVector2Array([Vector2(0.0, tf), Vector2(fr * 0.35, tf), Vector2(fr * 0.35, deep - 0.02),
			Vector2(fr * 0.28, deep), Vector2(0.0, deep)]), 12)
	var br := minf(0.03, fr * 0.07)
	k.color = STAINLESS
	for i in 10:
		var a := TAU * (float(i) + 0.5) / 10.0
		_electrical_lathe_at(k, PackedVector2Array([Vector2(0.0, tf), Vector2(br, tf), Vector2(br, tf + 0.015),
				Vector2(0.0, tf + 0.015)]), 6, Vector3(cos(a) * fr * 0.8, 0.0, sin(a) * fr * 0.8))
	_electrical_xform(k, from, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, back)))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size.x * size.y * size.z * 0.7
	var col := BoxShape3D.new()
	col.size = size
	shape.collision = col
	# The status strip: five discrete lit segments.
	var g := MeshKit.new()
	var seg := size.x * 0.42 / 5.0
	for i in 5:
		g.box(Vector3(seg * 0.72, 0.05, 0.006), Vector3(-size.x * 0.21 + seg * (float(i) + 0.5), strip_y, front - 0.015))
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## Adds a lathe (round Y) whose axis stands at `at`.
static func _electrical_lathe_at(k: MeshKit, profile: PackedVector2Array, segments: int, at: Vector3) -> void:
	var from := k.verts.size()
	k.lathe(profile, segments)
	for i in range(from, k.verts.size()):
		k.verts[i] += at


## Moves everything added to `k` since vertex `from` by `t` (normals turned with it).
static func _electrical_xform(k: MeshKit, from: int, t: Transform3D) -> void:
	for i in range(from, k.verts.size()):
		k.verts[i] = t * k.verts[i]
		k.normals[i] = (t.basis * k.normals[i]).normalized()


## A breaker cabinet: a box on a dark plinth under a lipped cap, its front (-Z) a door on a
## dark seam with two hinges, a handle, a louvre, a hazard label between two indicator
## lamps (glow) and a big red lever (up = closed) between two guard cheeks.
static func switch_cabinet(size: Vector3 = Vector3(0.7, 1.4, 0.35), glow := Color(0.3, 1.0, 0.45)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := size.y * 0.5
	var front := -size.z * 0.5
	var plinth := 0.06
	var cap := 0.03
	k.color = DARK
	k.box(Vector3(size.x - 0.04, plinth, size.z - 0.04), Vector3(0.0, -h + plinth * 0.5, 0.02))
	k.color = Color.WHITE
	var body_h := size.y - plinth - cap
	k.box(Vector3(size.x, body_h, size.z), Vector3(0.0, -h + plinth + body_h * 0.5, 0.0))
	k.box(Vector3(size.x + 0.02, cap, size.z + 0.009), Vector3(0.0, h - cap * 0.5, -0.0075))
	# The door on a dark seam.
	var door := Vector2(size.x * 0.9, size.y * 0.84)
	var dy := -h + plinth + body_h * 0.5
	k.color = DARK
	k.box(Vector3(door.x + 0.016, door.y + 0.016, 0.004), Vector3(0.0, dy, front - 0.002))
	k.color = Color.WHITE
	k.box(Vector3(door.x, door.y, 0.012), Vector3(0.0, dy, front - 0.01))
	var df := front - 0.016
	k.color = DETAIL
	for sy: float in [-1.0, 1.0]:
		_electrical_lathe_at(k, PackedVector2Array([Vector2(0.0, -0.05), Vector2(0.018, -0.05), Vector2(0.018, 0.05),
				Vector2(0.0, 0.05)]), 8, Vector3(-door.x * 0.5, dy + sy * door.y * 0.34, df + 0.006))
		k.box(Vector3(0.022, 0.022, 0.008), Vector3(door.x * 0.5 - 0.035, dy + sy * (door.y * 0.5 - 0.035), df - 0.004))
		k.box(Vector3(0.022, 0.022, 0.008), Vector3(-door.x * 0.5 + 0.06, dy + sy * (door.y * 0.5 - 0.035), df - 0.004))
	# The handle on standoffs.
	var hx := door.x * 0.5 - 0.06
	k.strut(Vector3(hx, -size.y * 0.04, df - 0.035), Vector3(hx, size.y * 0.1, df - 0.035), 0.025)
	for y: float in [-size.y * 0.025, size.y * 0.085]:
		k.box(Vector3(0.02, 0.02, 0.025), Vector3(hx, y, df - 0.012))
	# The louvre low on the door.
	var ly := -size.y * 0.3
	k.color = DARK
	k.box(Vector3(size.x * 0.6, size.y * 0.14, 0.004), Vector3(0.0, ly, df - 0.002))
	k.color = DETAIL
	for i in 5:
		var y := ly - size.y * 0.07 + size.y * 0.14 * (float(i) + 0.5) / 5.0
		k.strut(Vector3(-size.x * 0.28, y + 0.008, df - 0.004), Vector3(size.x * 0.28, y + 0.008, df - 0.004), 0.016)
	# The lever's dark backplate with an ON mark, the guard cheeks, the lever and its knob.
	k.color = DARK
	k.box(Vector3(0.18, size.y * 0.43, 0.006), Vector3(0.0, size.y * 0.07, df - 0.003))
	k.color = PartShapes.ACCENT
	k.box(Vector3(0.1, 0.02, 0.004), Vector3(0.0, size.y * 0.27, df - 0.008))
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.02, 0.16, 0.08), Vector3(sx * 0.075, -size.y * 0.1, df - 0.046))
	k.box(Vector3(0.1, 0.1, 0.06), Vector3(0.0, -size.y * 0.1, front - 0.03))
	k.color = Color(0.9, 0.3, 0.2)
	var tip := Vector3(0.0, size.y * 0.25, front - 0.09)
	k.strut(Vector3(0.0, -size.y * 0.1, front - 0.05), tip, 0.05)
	k.color = DARK
	k.box(Vector3(0.07, 0.07, 0.07), tip + Vector3(0.0, 0.01, -0.005))
	# A hazard label between the lamps, each lamp in a dark bezel.
	var lamp_y := size.y * 0.32
	k.color = PartShapes.ACCENT
	k.box(Vector3(0.12, 0.07, 0.004), Vector3(0.0, lamp_y, df - 0.002))
	k.color = DARK
	k.strut(Vector3(0.012, lamp_y + 0.025, df - 0.005), Vector3(-0.012, lamp_y - 0.025, df - 0.005), 0.012)
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.08, 0.08, 0.008), Vector3(sx * size.x * 0.25, lamp_y, df - 0.004))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size.x * size.y * size.z * 0.3
	var col := BoxShape3D.new()
	col.size = size + Vector3(0.0, 0.0, 0.2)
	shape.collision = col
	var g := MeshKit.new()
	for sx: float in [-1.0, 1.0]:
		g.box(Vector3(0.05, 0.05, 0.006), Vector3(sx * size.x * 0.25, lamp_y, df - 0.011))
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A rack of battery cells: `rows` shelves of `cells` cells each in a frame of four posts
## with top rails and a cross brace behind. Each cell has a dark lid, a red (+) and a copper
## (-) terminal, a copper strap to the next cell and a charge lamp on its front (glow).
static func battery_rack(width: float = 1.2, height: float = 1.4, depth: float = 0.5,
		rows: int = 3, cells: int = 3, glow := Color(0.3, 1.0, 0.45)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var post := 0.05
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(post, height, post), Vector3(sx * (width - post) * 0.5, 0.0, sz * (depth - post) * 0.5))
		# A top rail front and back.
		k.box(Vector3(width - post * 2.0, 0.04, 0.03), Vector3(0.0, height * 0.5 - 0.02, sx * (depth - post) * 0.5))
	# The cross brace behind the cells.
	var bz := (depth - post) * 0.5 + 0.01
	for sx: float in [-1.0, 1.0]:
		k.strut(Vector3(-sx * (width * 0.5 - post - 0.01), -height * 0.5 + 0.06, bz),
				Vector3(sx * (width * 0.5 - post - 0.01), height * 0.5 - 0.06, bz), 0.02)
	var shelf := height / float(rows)
	var cw := (width - post * 2.0) / float(cells)
	var tz := -depth * 0.12
	var g := MeshKit.new()
	for r in rows:
		var y0 := -height * 0.5 + shelf * float(r)
		k.color = GALVANISED
		k.box(Vector3(width - post * 2.0 - 0.01, 0.03, depth - post * 2.0 - 0.01), Vector3(0.0, y0 + 0.015, 0.0))
		var lid_y := y0 + 0.03 + shelf * 0.62
		for c in cells:
			var x := -width * 0.5 + post + cw * (float(c) + 0.5)
			k.color = CELL
			k.box(Vector3(cw * 0.86, shelf * 0.62 - 0.02, depth * 0.8), Vector3(x, y0 + 0.025 + shelf * 0.31, 0.0))
			k.color = DARK
			k.box(Vector3(cw * 0.82, 0.025, depth * 0.76), Vector3(x, lid_y - 0.0125, 0.0))
			k.color = TERMINAL_RED
			k.box(Vector3(0.03, 0.05, 0.03), Vector3(x + cw * 0.25, lid_y + 0.025, tz))
			k.color = COPPER
			k.box(Vector3(0.03, 0.05, 0.03), Vector3(x - cw * 0.25, lid_y + 0.025, tz))
			if c < cells - 1:
				k.box(Vector3(cw * 0.5 + 0.03, 0.012, 0.024), Vector3(x + cw * 0.5, lid_y + 0.034, tz))
			# A pale enamel label band across the cell's front, its charge lamp at one end.
			k.color = PLATE
			k.box(Vector3(cw * 0.7, 0.05, 0.004), Vector3(x, lid_y - 0.07, -depth * 0.4 - 0.002))
			g.box(Vector3(0.045, 0.025, 0.006), Vector3(x + cw * 0.22, lid_y - 0.07, -depth * 0.4 - 0.007))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * depth * 0.4
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


# --- Lounge and cabin fittings ------------------------------------------------------------

## A lounge sofa `length` along X, facing -Z: a ribbed rubber kick plinth set back under a
## body and a back frame in the material colour with a slim arm at each end, a chrome trim
## rail along the back's top and a polished strip along the body's foot, a row of chamfered
## upholstered seat and back cushions in `cushion` (one per ~0.65 m, seams between them; an
## untagged colour becomes upholstery, a zoned one keeps its finish) and leather pads in the
## same tone on the arms. Stands on -Y, back at +Z.
static func bench(length: float = 2.0, depth: float = 0.8, height: float = 0.95,
		cushion := Color(0.65, 0.12, 0.14)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var l := length * 0.5
	var base_h := 0.36                        # top of the body above the floor, m
	var kick := 0.07                          # plinth height, m
	var zf := -depth * 0.46                   # front face of the body
	var zb := depth * 0.5                     # back face
	var bt := 0.06                            # back frame thickness, m
	var arm := 0.07                           # arm thickness, m
	var y0 := -h + base_h                     # where the seat cushions sit
	var seat_t := 0.13                        # seat cushion thickness, m
	var arm_top := minf(y0 + seat_t + 0.14, h - 0.08)
	var zs := (zf + zb - bt) * 0.5            # middle of the seat
	var hs := (zb - bt - zf) * 0.5            # half the seat's depth
	# The kick plinth, set back under the body.
	k.color = TREAD
	k.box(Vector3(length - 0.08, kick, zb - zf - 0.06), Vector3(0.0, -h + kick * 0.5, (zf + zb + 0.02) * 0.5))
	# Body, back frame and arms in the material colour, a trim rail on the back.
	k.color = Color.WHITE
	k.box(Vector3(length - 2.0 * arm, base_h - kick, zb - bt - zf), Vector3(0.0, -h + kick + (base_h - kick) * 0.5, zs))
	k.box(Vector3(length, height - kick - 0.02, bt), Vector3(0.0, -h + kick + (height - kick - 0.02) * 0.5, zb - bt * 0.5))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(arm, arm_top + h - kick, zb - bt - zf), Vector3(sx * (l - arm * 0.5), (arm_top - h + kick) * 0.5, zs))
	k.color = CHROME
	k.box(Vector3(length, 0.02, bt + 0.01), Vector3(0.0, h - 0.01, zb - bt * 0.5 - 0.005))
	k.color = TRIM
	k.box(Vector3(length - 2.0 * arm, 0.02, 0.004), Vector3(0.0, -h + kick + 0.012, zf - 0.002))
	# Cushions: seat and back, one pair per section, and a pad on each arm.
	k.color = _furn_zoned(cushion, "upholstery")
	var n := maxi(1, int(round((length - 2.0 * arm) / 0.65)))
	var cw := (length - 2.0 * arm - 0.01) / float(n)
	var yb0 := y0 + seat_t + 0.005
	var yb1 := h - 0.05
	for i in n:
		var x := -l + arm + 0.005 + cw * (float(i) + 0.5)
		_seating_pad(k, Vector3(x, y0, zs), Vector3.RIGHT, Vector3.BACK, Vector3.UP, cw * 0.5 - 0.006, hs - 0.005, seat_t, 0.03)
		_seating_pad(k, Vector3(x, (yb0 + yb1) * 0.5, zb - bt), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
				cw * 0.5 - 0.006, (yb1 - yb0) * 0.5, 0.1, 0.03)
	k.color = _furn_zoned(cushion, "leather")
	for sx: float in [-1.0, 1.0]:
		_seating_pad(k, Vector3(sx * (l - arm * 0.5), arm_top, zs), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
				arm * 0.5 - 0.005, hs - 0.01, 0.03, 0.012)
	var back_h := height - base_h - 0.14
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * depth * base_h * 0.4 + length * back_h * 0.16 * 0.3
	var col := BoxShape3D.new()
	col.size = Vector3(length, height, depth)
	shape.collision = col
	return shape


## A bar counter `length` along X: a dark kick plinth set back under a body in the material
## colour with raised chamfered panels on its customer face (-Z), a pale top with bevelled
## edges and a bright trim band overhanging toward -Z, a warm lit strip under the overhang
## (the glow), a steel footrail on brackets, and on the server's side (+Z) a dark shelf
## recess with a lip over two cupboard doors. Stands on -Y.
static func bar_counter(length: float = 3.0, height: float = 1.1, depth: float = 0.7) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var h := height * 0.5
	var d := depth * 0.5
	var l := length * 0.5
	var kick := 0.1                           # plinth height, m
	var top_t := 0.06                         # counter top thickness, m
	var zt := -d - 0.3                        # front edge of the top
	var yb0 := -h + kick
	var yb1 := h - top_t
	# Kick plinth, set back 4 cm on the customer side.
	k.color = DARK
	k.box(Vector3(length - 0.04, kick, depth - 0.06), Vector3(0.0, -h + kick * 0.5, 0.01))
	# The body, its front panels (one per ~0.8 m) and the server's cupboards.
	k.color = Color.WHITE
	k.box(Vector3(length, yb1 - yb0, depth), Vector3(0.0, (yb0 + yb1) * 0.5, 0.0))
	var n := maxi(1, int(round(length / 0.8)))
	var pw := (length - 0.08) / float(n)
	var ym := (yb0 + yb1) * 0.5
	for i in n:
		var x := -l + 0.04 + pw * (float(i) + 0.5)
		_seating_pad(k, Vector3(x, ym, -d), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
				pw * 0.5 - 0.03, (yb1 - yb0) * 0.5 - 0.08, 0.015, 0.012)
	var y_shelf := yb1 - (yb1 - yb0) * 0.35   # bottom of the shelf recess at the back
	for sx: float in [-1.0, 1.0]:
		var cx := sx * (l - 0.08) * 0.5
		_seating_pad(k, Vector3(cx, (yb0 + y_shelf) * 0.5, d), Vector3.RIGHT, Vector3.UP, Vector3.BACK,
				(l - 0.08) * 0.5 - 0.03, (y_shelf - yb0) * 0.5 - 0.05, 0.012, 0.008)
	k.color = DARK
	k.box(Vector3(length - 0.16, yb1 - y_shelf - 0.06, 0.006), Vector3(0.0, (y_shelf + yb1) * 0.5, d + 0.003))
	k.color = DETAIL
	k.box(Vector3(length - 0.16, 0.02, 0.012), Vector3(0.0, y_shelf + 0.03, d + 0.006))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.16, 0.02, 0.006), Vector3(sx * 0.11, y_shelf - 0.09, d + 0.015))
	# The top: bevelled front edges, a trim band along the front.
	k.color = BAR_TOP
	_prism_x(k, PackedVector2Array([Vector2(zt, yb1 + 0.015), Vector2(zt + 0.015, yb1), Vector2(d, yb1),
			Vector2(d, h), Vector2(zt + 0.02, h), Vector2(zt, h - 0.02)]), -l - 0.05, l + 0.05)
	k.color = TRIM
	k.box(Vector3(length + 0.09, 0.012, 0.006), Vector3(0.0, yb1 + 0.03, zt - 0.003))
	# The light channel under the overhang, its strip lit.
	k.color = DARK
	k.box(Vector3(length - 0.25, 0.014, 0.04), Vector3(0.0, yb1 - 0.007, -d - 0.06))
	g.box(Vector3(length - 0.3, 0.004, 0.018), Vector3(0.0, yb1 - 0.016, -d - 0.06))
	# Footrail on brackets: at the panel seams, or near the ends of a short counter.
	var yr := -h + 0.22
	var zr := -d - 0.17
	k.color = TRIM
	_tube(k, Vector3(-l + 0.06, yr, zr), Vector3(l - 0.06, yr, zr), 0.025, 8)
	k.color = DETAIL
	var brackets: Array[float] = [-l + 0.12, l - 0.12]
	for i in range(1, n):
		brackets.append(-l + 0.04 + pw * float(i))
	for x: float in brackets:
		k.strut(Vector3(x, yr, -d - 0.015), Vector3(x, yr, zr), 0.03)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * height * depth * 0.25
	var col := BoxShape3D.new()
	col.size = Vector3(length + 0.1, height, depth + 0.4)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = BAR_GLOW
	return shape


## A bar stool `height` tall: a cast base disc with a chamfered edge, a chrome column with
## a rubber-gripped foot ring on three chrome spokes, a dark plastic seat pan and a round
## leather cushion with a rounded edge in `cushion` (an untagged colour becomes leather, a
## zoned one keeps its finish).
static func stool(height: float = 0.75, cushion := Color(0.65, 0.12, 0.14)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var y_pan := h - 0.1                      # underside of the cushion, m
	var yf := -h + height * 0.4               # foot ring height, m
	k.color = CAST
	k.lathe(PackedVector2Array([Vector2(0.0, -h), Vector2(0.2, -h), Vector2(0.2, -h + 0.015),
			Vector2(0.165, -h + 0.035), Vector2(0.0, -h + 0.035)]), 12)
	k.color = CHROME
	k.lathe(PackedVector2Array([Vector2(0.0, -h + 0.035), Vector2(0.032, -h + 0.035), Vector2(0.032, y_pan - 0.03),
			Vector2(0.0, y_pan - 0.03)]), 8)
	k.color = RUBBER
	k.lathe(PackedVector2Array([Vector2(0.14, yf - 0.012), Vector2(0.165, yf - 0.012), Vector2(0.165, yf + 0.012),
			Vector2(0.14, yf + 0.012)]), 12)
	k.color = CHROME
	for i in 3:
		var a := TAU * (float(i) + 0.5) / 3.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		k.strut(dir * 0.03 + Vector3(0.0, yf, 0.0), dir * 0.145 + Vector3(0.0, yf, 0.0), 0.018)
	k.color = PLASTIC_DARK
	k.lathe(PackedVector2Array([Vector2(0.0, y_pan - 0.03), Vector2(0.06, y_pan - 0.03), Vector2(0.15, y_pan - 0.006),
			Vector2(0.15, y_pan), Vector2(0.0, y_pan)]), 12)
	k.color = _furn_zoned(cushion, "leather")
	k.lathe(PackedVector2Array([Vector2(0.0, y_pan), Vector2(0.18, y_pan), Vector2(0.19, y_pan + 0.03),
			Vector2(0.19, h - 0.03), Vector2(0.17, h), Vector2(0.0, h)]), 12)
	return _cylinder(k, 0.2, height)


## A caller's cushion colour as finish `id` (bench, stool, armchair): an untagged colour
## keeps its tone and takes the finish; one that already carries a zone keeps its own.
static func _furn_zoned(c: Color, id: String) -> Color:
	if SurfaceZones.zone_of(c) != 0:
		return c
	return SurfaceZones.tag(c, id)


## A toilet: a cast floor plate bolted down at its corners, a glazed porcelain pedestal
## tapering up to an oval bowl, a dark seam under the moulded plastic seat, a closed plastic
## lid with a raised panel and two chrome hinge knuckles, and a porcelain cistern at +Z (the
## back, against a wall) with a chamfered top edge, a lid seam and a stainless flush plate
## with two chrome buttons on its front.
static func toilet() -> PartShapes.PartShape:
	var k := MeshKit.new()
	# The floor plate and its bolts.
	k.color = CAST
	_galley_slab(k, 0.36, 0.42, 0.05, -0.39, -0.372, 0.006, 0.05)
	k.color = GALVANISED
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.024, 0.012, 0.024), Vector3(sx * 0.135, -0.37, 0.05 + sz * 0.165))
	# The porcelain pedestal, tapering out to the bowl.
	k.color = WASH_PORCELAIN
	var ped_a := PackedVector3Array()
	var ped_b := PackedVector3Array()
	for p in PartShapes._chamfer_rect(0.28, 0.34, 0.05):
		ped_a.append(Vector3(p.x, -0.372, p.y + 0.05))
	for p in PartShapes._chamfer_rect(0.33, 0.36, 0.08):
		ped_b.append(Vector3(p.x, -0.03, p.y + 0.02))
	k.loft(ped_a, ped_b)
	# The oval bowl, the dark seam, the seat and the closed lid with its raised panel.
	k.loft(_galley_oval(0.185, 0.195, -0.03, -0.01), _galley_oval(0.205, 0.21, 0.062, -0.01))
	k.color = DARK
	k.loft(_galley_oval(0.193, 0.2, 0.062, -0.01), _galley_oval(0.193, 0.2, 0.07, -0.01))
	k.color = WASH_SEAT
	k.loft(_galley_oval(0.205, 0.21, 0.07, -0.01), _galley_oval(0.195, 0.2, 0.09, -0.01))
	k.loft(_galley_oval(0.16, 0.16, 0.09, -0.03), _galley_oval(0.15, 0.15, 0.098, -0.03))
	k.color = CHROME
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.05, 0.03, 0.03), Vector3(sx * 0.08, 0.095, 0.165))
	# The cistern: chamfered along its top front edge, a lid seam round it.
	k.color = WASH_PORCELAIN
	_prism_x(k, PackedVector2Array([Vector2(0.17, -0.05), Vector2(0.35, -0.05), Vector2(0.35, 0.39),
			Vector2(0.21, 0.39), Vector2(0.17, 0.35)]), -0.21, 0.21)
	k.color = DARK
	k.box(Vector3(0.424, 0.01, 0.184), Vector3(0.0, 0.31, 0.26))
	# The flush plate: a stainless frame with two chrome buttons split by a seam.
	k.color = STAINLESS
	k.box(Vector3(0.17, 0.1, 0.008), Vector3(0.0, 0.2, 0.166))
	k.color = CHROME
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.07, 0.076, 0.006), Vector3(sx * 0.039, 0.2, 0.161))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = 0.06
	var col := BoxShape3D.new()
	col.size = Vector3(0.44, 0.78, 0.7)
	shape.collision = col
	return shape


## A wash basin: a vanity cabinet in the material colour on a dark toe recess, two doors
## with a dark seam and chrome handles, a stainless worktop with an upstand along its back
## (+Z, the wall), a hollow round glazed porcelain bowl standing on it with a chrome waste,
## and a chrome tap on a stainless boss at the back with a lever, its spout reaching over
## the bowl.
static func basin() -> PartShapes.PartShape:
	var k := MeshKit.new()
	# Toe recess, cabinet, door seams and handles.
	k.color = DARK
	k.box(Vector3(0.56, 0.06, 0.4), Vector3(0.0, -0.42, 0.025))
	k.color = Color.WHITE
	k.box(Vector3(0.6, 0.64, 0.45), Vector3(0.0, -0.07, 0.0))
	k.color = DARK
	k.box(Vector3(0.01, 0.58, 0.006), Vector3(0.0, -0.08, -0.226))
	k.box(Vector3(0.58, 0.01, 0.006), Vector3(0.0, 0.215, -0.226))
	k.color = CHROME
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.02, 0.13, 0.02), Vector3(sx * 0.05, 0.1, -0.234))
	# The stainless worktop and its upstand.
	k.color = STAINLESS
	k.box(Vector3(0.64, 0.08, 0.5), Vector3(0.0, 0.29, 0.0))
	k.box(Vector3(0.64, 0.07, 0.025), Vector3(0.0, 0.365, 0.2375))
	# The porcelain bowl: a sloped wall round a floor, a chrome waste in the middle.
	k.color = WASH_PORCELAIN
	k.lathe(PackedVector2Array([Vector2(0.12, 0.33), Vector2(0.165, 0.33), Vector2(0.19, 0.405), Vector2(0.168, 0.405)]), 14)
	k.lathe(PackedVector2Array([Vector2(0.0, 0.33), Vector2(0.135, 0.33), Vector2(0.135, 0.348), Vector2(0.0, 0.348)]), 14)
	k.color = CHROME
	k.lathe(PackedVector2Array([Vector2(0.0, 0.348), Vector2(0.026, 0.348), Vector2(0.026, 0.352), Vector2(0.0, 0.352)]), 8)
	# The tap: a base boss, a riser, a spout over the bowl with a nozzle, a lever.
	var zt := 0.212
	k.color = STAINLESS
	k.box(Vector3(0.05, 0.012, 0.03), Vector3(0.0, 0.336, zt))
	k.color = CHROME
	_tube(k, Vector3(0.0, 0.33, zt), Vector3(0.0, 0.49, zt), 0.014, 8)
	_tube(k, Vector3(0.0, 0.478, zt), Vector3(0.0, 0.478, 0.08), 0.011, 8)
	k.box(Vector3(0.026, 0.03, 0.026), Vector3(0.0, 0.462, 0.085))
	k.box(Vector3(0.07, 0.014, 0.018), Vector3(0.045, 0.44, zt))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = 0.08
	var col := BoxShape3D.new()
	col.size = Vector3(0.64, 0.9, 0.5)
	shape.collision = col
	return shape


## A door post `height` tall (`width` across X, `depth` along Z): a painted post with
## chamfered corners on a rubber kick block, a cast steel head cap, a dark anodised channel up
## its +X face holding a lit strip (glow), and on both Z faces a hazard band over the kick
## block, a panel seam and four blackened bolts. Put one each side of a doorway, the second turned round.
static func portal_jamb(height: float = 2.1, width: float = 0.16, depth: float = 0.3,
		glow := Color(1.0, 0.85, 0.2)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hw := width * 0.5
	var hh := height * 0.5
	var hd := depth * 0.5
	var c := minf(0.025, minf(hw, hd) * 0.3)
	var base_h := minf(0.14, height * 0.08)
	var cap_h := minf(0.08, height * 0.05)
	# The post between the kick block and the head cap, its upright edges chamfered.
	k.color = Color.WHITE
	k.loft(_doors_ring(hw, hd, c, -hh + base_h - 0.01), _doors_ring(hw, hd, c, hh - cap_h + 0.01))
	k.color = RUBBER
	k.box(Vector3(width + 0.016, base_h, depth + 0.016), Vector3(0.0, -hh + base_h * 0.5, 0.0))
	k.color = CAST
	k.box(Vector3(width + 0.01, cap_h, depth + 0.01), Vector3(0.0, hh - cap_h * 0.5, 0.0))
	# The dark channel up the inner (+X) face that holds the lit strip.
	k.color = RAIL_DARK
	k.box(Vector3(0.012, height * 0.7, 0.05), Vector3(hw + 0.004, 0.05, 0.0))
	# Both Z faces: a hazard band over the kick block, a seam and four bolts.
	var haz := minf(0.16, height * 0.08)
	var y_haz := -hh + base_h + 0.02 + haz * 0.5
	for s: float in [-1.0, 1.0]:
		var n := Vector3(0.0, 0.0, s)
		_gear_hazard(k, Vector3(0.0, y_haz, s * hd), Vector3.RIGHT, Vector3.UP, n, Vector2(width - 2.0 * c - 0.01, haz),
				haz * 0.45)
		k.color = DARK
		k.box(Vector3(width - 2.0 * c - 0.01, 0.014, 0.006), Vector3(0.0, height * 0.12, s * (hd + 0.002)))
		k.color = FLANGE_BOLT
		for y: float in [y_haz + haz * 0.5 + 0.05, hh - cap_h - 0.05]:
			for sx: float in [-1.0, 1.0]:
				_gear_bolt(k, Vector3(sx * (hw - c - 0.018), y, s * hd), n, 0.011, 0.006)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * depth * 0.6
	var col := BoxShape3D.new()
	col.size = Vector3(width + 0.03, height, depth)
	shape.collision = col
	var g := MeshKit.new()
	g.box(Vector3(0.012, height * 0.62, 0.03), Vector3(hw + 0.013, 0.05, 0.0))
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## Eight points of a rectangle `hx` by `hz` (half sizes, XZ) with its corners cut by `c`,
## at height y.
static func _doors_ring(hx: float, hz: float, c: float, y: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(hx - c, y, -hz), Vector3(hx, y, -hz + c), Vector3(hx, y, hz - c),
			Vector3(hx - c, y, hz), Vector3(-hx + c, y, hz), Vector3(-hx, y, hz - c),
			Vector3(-hx, y, -hz + c), Vector3(-hx + c, y, -hz)])


## The lintel's outline (XY): a bar `w` by `h` (half sizes) with its lower corners cut by `c`.
static func _doors_lintel_outline(w: float, h: float, c: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-w, h), Vector2(w, h), Vector2(w, -h + c), Vector2(w - c, -h),
			Vector2(-w + c, -h), Vector2(-w, -h + c)])


## The bar over a doorway, `width` across X, `height` tall, its two lower corners cut by
## `cut` (the angled top corners of an SE2 door frame). Both Z faces carry a dark seam
## round a raised panel with a blackened bolt at each end; under it a dark anodised channel
## holds a lit strip (glow) facing down into the doorway, the colour of the jambs' strips.
static func portal_lintel(width: float = 1.5, height: float = 0.35, depth: float = 0.3,
		cut: float = 0.2, glow := Color(1.0, 0.85, 0.2)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var w := width * 0.5
	var h := height * 0.5
	var c := minf(cut, minf(w, height) * 0.9)
	var outline := _doors_lintel_outline(w, h, c)
	k.extrude(outline, depth)
	var volume := k.volume()
	# A dark seam and a raised panel inside it, through the bar so both faces get them.
	var i1 := minf(0.035, h * 0.25)
	var i2 := i1 + minf(0.015, h * 0.1)
	k.color = DARK
	k.extrude(_doors_lintel_outline(w - i1, h - i1, clampf(c - i1 * 0.414, 0.0, (h - i1) * 1.8)), depth + 0.006)
	k.color = Color.WHITE
	k.extrude(_doors_lintel_outline(w - i2, h - i2, clampf(c - i2 * 0.414, 0.0, (h - i2) * 1.8)), depth + 0.01)
	k.color = FLANGE_BOLT
	for s: float in [-1.0, 1.0]:
		for sx: float in [-1.0, 1.0]:
			_gear_bolt(k, Vector3(sx * (w - i2 - 0.04), h * 0.35, s * (depth * 0.5 + 0.005)), Vector3(0.0, 0.0, s),
					0.013, 0.007)
	var shape := PartShapes.PartShape.new()
	# The lit strip's channel under the bar, between the cut corners.
	var run := 2.0 * (w - c) - 0.1
	if run > 0.05:
		k.color = RAIL_DARK
		k.box(Vector3(run, 0.008, depth * 0.35), Vector3(0.0, -h - 0.003, 0.0))
		var g := MeshKit.new()
		g.box(Vector3(run - 0.06, 0.004, depth * 0.14), Vector3(0.0, -h - 0.008, 0.0))
		shape.glow = g.finish()
		shape.glow_color = glow
	shape.mesh = k.finish()
	shape.volume = volume
	var pts := PackedVector3Array()
	for p in outline:
		pts.append(Vector3(p.x, p.y, -depth * 0.5))
		pts.append(Vector3(p.x, p.y, depth * 0.5))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	return shape

# --- Services: tees, bends, boxes -------------------------------------------------------

## A pipe tee: a short run along Y with a branch stub out of its -Z side (turn it to point
## the stub down). Flanged like `pipe`, so it sits in a pipe run between two spans.
static func pipe_tee(radius: float, length: float = 0.5, stub: float = 0.0) -> PartShapes.PartShape:
	if stub <= 0.0:
		stub = radius * 2.2
	var k := MeshKit.new()
	var h := length * 0.5
	var fr := radius * 1.35
	var ft := 0.06
	var rh := radius * 1.12
	var hub := minf(ft * 0.8, length * 0.08)
	# The run: one lathe, a weld-neck flange at each end like `pipe`'s.
	_piping_spin(k, Vector3(0.0, -h, 0.0), Vector3.UP, PackedVector2Array([Vector2(0.0, 0.0), Vector2(fr, 0.0),
			Vector2(fr, ft), Vector2(rh, ft), Vector2(radius, ft + hub), Vector2(radius, length - ft - hub),
			Vector2(rh, length - ft), Vector2(fr, length - ft), Vector2(fr, length), Vector2(0.0, length)]),
			[DETAIL, DETAIL, DETAIL, DETAIL, Color.WHITE, DETAIL, DETAIL, DETAIL, DETAIL] as Array[Color], 12)
	# The stub: a tube out toward -Z from inside the run, its own flange and four bolts.
	var ring_a := PackedVector3Array()
	var ring_b := PackedVector3Array()
	var fl_a := PackedVector3Array()
	for j in 12:
		var a := TAU * float(j) / 12.0
		ring_a.append(Vector3(cos(a) * radius, sin(a) * radius, 0.0))
		ring_b.append(Vector3(cos(a) * radius, sin(a) * radius, -stub + ft))
		fl_a.append(Vector3(cos(a) * fr, sin(a) * fr, -stub))
	k.color = Color.WHITE
	k.loft(ring_a, ring_b, false)
	var stub_end := Vector3(0.0, 0.0, -stub)
	_piping_spin(k, stub_end, Vector3.BACK, PackedVector2Array([Vector2(0.0, 0.0), Vector2(fr, 0.0),
			Vector2(fr, ft), Vector2(rh, ft), Vector2(radius * 0.98, ft + minf(hub, stub * 0.25))]),
			[DETAIL] as Array[Color], 12)
	k.color = FLANGE_BOLT
	var bs := maxf(radius * 0.2, 0.01)
	_piping_bolts(k, stub_end, Vector3.BACK, ft, 4, (rh + fr) * 0.5, bs, bs * 0.6)
	# A reinforcing saddle where the stub meets the run: an eight-sided welded band, heat-tinted.
	_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(radius * 0.95, -radius * 0.9),
			Vector2(radius * 1.18, -radius * 0.9), Vector2(radius * 1.18, radius * 0.9),
			Vector2(radius * 0.95, radius * 0.9)]), [WELD_PAD] as Array[Color], 8, PI / 8.0)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * radius * radius * (length + stub) * 0.3
	var col := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for j in 12:
		var a := TAU * float(j) / 12.0
		pts.append(Vector3(cos(a) * fr, -h, sin(a) * fr))
		pts.append(Vector3(cos(a) * fr, h, sin(a) * fr))
	pts.append_array(fl_a)
	col.points = pts
	shape.collision = col
	return shape


## A wiring loom turning a rounded 90 degree corner: in along +Y from the origin, out
## toward +Z (same frame as pipe_elbow). Wires coloured from `spec`, their ends where the
## straight spans' are; a galvanised clip strap with a buckle at each end (like the spans'
## clips) and a black nylon cable tie at the middle of the turn.
## `turn`: how far the bundle turns, radians (a quarter turn by default): it enters along
## +Y at the origin and leaves along (0, cos turn, sin turn).
static func loom_bend(spec: WiringLoom.Spec, bend: float = 0.25, turn: float = PI * 0.5) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var steps := 6
	var centres: Array[Vector3] = []
	var tangents: Array[Vector3] = []
	for i in steps + 1:
		var a := turn * float(i) / float(steps)
		centres.append(Vector3(0.0, sin(a) * bend, bend - cos(a) * bend))
		tangents.append(Vector3(0.0, cos(a), sin(a)))
	var wires: Array = [[-1, spec.core_color, spec.core_radius]]
	for i in spec.wire_colors.size():
		wires.append([i, spec.wire_colors[i], spec.wire_radius])
	var rr := spec.ring_radius()
	var n := maxi(spec.wire_colors.size(), 1)
	for w: Array in wires:
		var idx: int = w[0]
		k.color = w[1]
		var radius: float = w[2]
		var rings: Array[PackedVector3Array] = []
		for i in steps + 1:
			var t := tangents[i]
			var u := Vector3.RIGHT
			var v := t.cross(u)
			var c := centres[i]
			if idx >= 0:
				var angle := TAU * float(idx) / float(n) + spec.twist * bend * turn * float(i) / float(steps)
				c += (u * cos(angle) + v * sin(angle)) * rr
			var ring := PackedVector3Array()
			for j in 6:
				var b := TAU * float(j) / 6.0
				ring.append(c + (u * cos(b) + v * sin(b)) * radius)
			rings.append(ring)
		for i in steps:
			k.loft(rings[i], rings[i + 1], false)
		k.poly(rings[0], Vector3.DOWN)
		k.poly(rings[steps], Vector3.BACK)
	# Bands round the bundle: a galvanised clip strap near each end, a nylon tie mid-turn.
	var br := spec.bundle_radius()
	var band := func(a: float, s: float, radius: float, width: float) -> void:
		var c := Vector3(0.0, sin(a) * bend, bend - cos(a) * bend)
		var t := Vector3(0.0, cos(a), sin(a))
		var v := t.cross(Vector3.RIGHT)
		var ra := PackedVector3Array()
		var rb := PackedVector3Array()
		for j in 10:
			var b := TAU * (float(j) + 0.5) / 10.0
			var off := (Vector3.RIGHT * cos(b) + v * sin(b)) * radius
			ra.append(c + t * (s - width * 0.5) + off)
			rb.append(c + t * (s + width * 0.5) + off)
		k.loft(ra, rb)
	k.color = LIT_CLIP
	band.call(0.0, 0.02, br + 0.007, 0.022)
	band.call(turn, -0.02, br + 0.007, 0.022)
	k.color = LIT_TIE
	band.call(turn * 0.5, 0.0, br + 0.004, 0.012)
	# The clip straps' buckles, on the outside of the turn.
	k.color = LIT_CLIP
	var bk := br + 0.007
	k.box(Vector3(0.026, 0.022, 0.01), Vector3(0.0, 0.02, -bk - 0.004))
	var end_c := Vector3(0.0, sin(turn) * bend, bend - cos(turn) * bend)
	var end_t := Vector3(0.0, cos(turn), sin(turn))
	var outward := Vector3(0.0, sin(turn), -cos(turn))
	k.box(Vector3(0.026, 0.01, 0.022), end_c - end_t * 0.02 + outward * (bk + 0.004))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * br * br * bend * turn
	var col := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for i in centres.size():
		var u := Vector3.RIGHT
		var v := tangents[i].cross(u)
		for j in 8:
			var b := TAU * float(j) / 8.0
			pts.append(centres[i] + (u * cos(b) + v * sin(b)) * br)
	col.points = pts
	shape.collision = col
	return shape


## A junction box: a wall or deck box with a bevelled lid on a dark seam (a screw in each
## corner, a hazard tab, a status lamp (glow) in a bezel) on its front (-Z), and three cable
## glands on top (+Y): the middle one takes the loom drop, the outer two device leads.
static func junction_box(size: Vector3 = Vector3(0.4, 0.3, 0.2), glow := Color(0.3, 1.0, 0.45)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	k.box(size)
	var f := -size.z * 0.5
	# The lid: a bevelled plate on a dark gasket.
	k.color = DARK
	k.box(Vector3(size.x * 0.9, size.y * 0.88, 0.004), Vector3(0.0, 0.0, f - 0.002))
	k.color = Color.WHITE
	var lw := size.x * 0.44
	var lh := size.y * 0.43
	var lb := 0.006
	var ring_a := PackedVector3Array()
	var ring_b := PackedVector3Array()
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		ring_a.append(Vector3(c.x * lw, c.y * lh, f - 0.004))
		ring_b.append(Vector3(c.x * (lw - lb), c.y * (lh - lb), f - 0.016))
	k.loft(ring_a, ring_b)
	var lf := f - 0.016
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			k.box(Vector3(0.018, 0.018, 0.006), Vector3(sx * (lw - 0.03), sy * (lh - 0.03), lf - 0.003))
	# The hazard tab: an amber triangle with a dark bar.
	var t := minf(0.07, size.x * 0.25)
	var hx := -size.x * 0.18
	var hy := size.y * 0.06
	var tri_a := PackedVector3Array()
	var tri_b := PackedVector3Array()
	for p: Vector2 in [Vector2(-0.5, -0.4), Vector2(0.5, -0.4), Vector2(0.0, 0.47)]:
		tri_a.append(Vector3(hx + p.x * t, hy + p.y * t, lf + 0.001))
		tri_b.append(Vector3(hx + p.x * t, hy + p.y * t, lf - 0.003))
	k.color = PartShapes.ACCENT
	k.loft(tri_a, tri_b)
	k.color = DARK
	k.box(Vector3(t * 0.12, t * 0.36, 0.003), Vector3(hx, hy + t * 0.02, lf - 0.004))
	# The lamp's bezel.
	var led := Vector2(size.x * 0.2, size.y * 0.06)
	var bz := minf(0.05, size.x * 0.22)
	k.box(Vector3(bz, bz, 0.006), Vector3(led.x, led.y, lf - 0.003))
	# Glands on top: a dark hex nut, a body and a chamfered cap, 4 cm tall.
	var top := size.y * 0.5
	var r := clampf(size.x * 0.07, 0.015, 0.028)
	for gx: float in [-size.x * 0.3, 0.0, size.x * 0.3]:
		var at := Vector3(gx, 0.0, 0.0)
		k.color = DARK
		_electrical_lathe_at(k, PackedVector2Array([Vector2(0.0, top), Vector2(r * 1.3, top), Vector2(r * 1.3, top + 0.014),
				Vector2(0.0, top + 0.014)]), 6, at)
		k.color = DETAIL
		_electrical_lathe_at(k, PackedVector2Array([Vector2(0.0, top + 0.014), Vector2(r, top + 0.014), Vector2(r, top + 0.032),
				Vector2(r * 0.75, top + 0.04), Vector2(0.0, top + 0.04)]), 8, at)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size.x * size.y * size.z * 0.4
	var col := BoxShape3D.new()
	col.size = size
	shape.collision = col
	var g := MeshKit.new()
	g.box(Vector3(bz * 0.55, bz * 0.55, 0.006), Vector3(led.x, led.y, lf - 0.009))
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


# --- Liner parts (0.24 additions) ---------------------------------------------------------

## A blocky lounge armchair `width` across (X), facing -Z: a recessed ribbed rubber kick
## plinth, a shell in the material colour (a body under the seat, arms with their front top
## edge cut away and a seam down their outer faces, a back with its rear top edge cut),
## chamfered leather cushions in `cushion` (an untagged colour becomes leather, a zoned one
## keeps its finish): the seat, a back cushion, a head pillow over it and a pad on each arm.
static func armchair(width: float = 0.85, depth: float = 0.85, height: float = 0.95,
		cushion := Color(0.82, 0.82, 0.8)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var w := width * 0.5
	var d := depth * 0.5
	var plinth := 0.12
	var arm := 0.14
	var y_body := -h + plinth                 # top of the plinth
	var seat_top := y_body + 0.34
	var arm_top := y_body + 0.6
	var zbk := d - 0.2                        # front face of the back
	var iw := w - arm                         # half the width between the arms
	k.color = TREAD
	k.box(Vector3(width * 0.9, plinth, depth * 0.9), Vector3(0.0, -h + plinth * 0.5, 0.0))
	# The shell: body under the cushion, arms and back in the paint colour.
	k.color = Color.WHITE
	k.box(Vector3(width - 2.0 * arm, 0.2, depth - 0.2), Vector3(0.0, y_body + 0.1, -0.1))
	var c := 0.06                             # the cut on the arms' and back's edges, m
	for sx: float in [-1.0, 1.0]:
		_prism_x(k, PackedVector2Array([Vector2(-d, y_body), Vector2(d, y_body), Vector2(d, arm_top),
				Vector2(-d + c, arm_top), Vector2(-d, arm_top - c)]), sx * iw, sx * w)
	_prism_x(k, PackedVector2Array([Vector2(zbk, y_body), Vector2(d, y_body), Vector2(d, h - c),
			Vector2(d - c, h), Vector2(zbk, h)]), -iw + 0.005, iw - 0.005)
	k.color = DARK
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.004, 0.012, depth - 0.12), Vector3(sx * (w + 0.002), arm_top - 0.1, 0.03))
	# Cushions, a few millimetres inside the arms.
	k.color = _furn_zoned(cushion, "leather")
	_seating_pad(k, Vector3(0.0, seat_top - 0.14, (-d - 0.003 + zbk - 0.005) * 0.5), Vector3.RIGHT, Vector3.BACK,
			Vector3.UP, iw - 0.01, (zbk - 0.005 + d + 0.003) * 0.5, 0.14, 0.035)
	var y_lumbar := seat_top + height * 0.4
	_seating_pad(k, Vector3(0.0, (seat_top + 0.005 + y_lumbar) * 0.5, zbk), Vector3.RIGHT, Vector3.UP,
			Vector3.FORWARD, iw - 0.02, (y_lumbar - seat_top - 0.005) * 0.5, 0.1, 0.03)
	var y_head := minf(h - 0.06, y_lumbar + height * 0.17)
	_seating_pad(k, Vector3(0.0, (y_lumbar + 0.01 + y_head) * 0.5, zbk), Vector3.RIGHT, Vector3.UP,
			Vector3.FORWARD, iw - 0.06, (y_head - y_lumbar - 0.01) * 0.5, 0.07, 0.03)
	for sx: float in [-1.0, 1.0]:
		_seating_pad(k, Vector3(sx * (w - arm * 0.5), arm_top, (-d + c + 0.01 + d - 0.02) * 0.5), Vector3.RIGHT,
				Vector3.BACK, Vector3.UP, arm * 0.5 - 0.015, (d - 0.02 + d - c - 0.01) * 0.5, 0.025, 0.01)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * depth * height * 0.25
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth)
	shape.collision = col
	return shape


## A closed airlock door leaf `width` (X) by `height` (Y), `thickness` deep (Z), its
## corners chamfered. On both faces: raised bands top and bottom with a row of bolts,
## two panel seams, a narrow dark window in a steel bezel near the top, a D-handle on
## standoffs beside a keypad with a lock lamp, a hazard band along the foot, and a lit
## strip (glow) in a dark channel down each edge, like the green door lights of SE2
## airlocks. Also serves as a hatch lid or flap laid flat.
static func hatch_door(width: float = 1.3, height: float = 2.4, thickness: float = 0.1,
		glow := Color(0.35, 1.0, 0.45)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var t := thickness * 0.5
	var hw := width * 0.5
	var hh := height * 0.5
	var c := minf(0.08, minf(hw, hh) * 0.2)
	k.extrude(PackedVector2Array([Vector2(-hw + c, -hh), Vector2(hw - c, -hh), Vector2(hw, -hh + c), Vector2(hw, hh - c),
			Vector2(hw - c, hh), Vector2(-hw + c, hh), Vector2(-hw, hh - c), Vector2(-hw, -hh + c)]), thickness)
	var g := MeshKit.new()
	var fb := minf(0.1, height * 0.06)         # the top and bottom bands, m
	var ch := 0.07                             # the edge channels' width, m
	var band_x := hw - ch - 0.05               # the bands stop short of the channels
	var bolts := clampi(int(width / 0.45), 2, 6)
	var gl := minf(0.35, height * 0.25)        # the handle's grip, m
	var hx := width * 0.32
	var hy := -height * 0.12
	var haz := minf(0.09, height * 0.05)
	for face: float in [-1.0, 1.0]:
		var n := Vector3(0.0, 0.0, face)
		# The bands with their bolts.
		for sy: float in [-1.0, 1.0]:
			var y := sy * (hh - fb * 0.5 - 0.012)
			k.color = Color.WHITE
			k.box(Vector3(band_x * 2.0, fb, 0.01), Vector3(0.0, y, face * t))
			k.color = DETAIL
			for i in bolts:
				var x := -band_x + 0.06 + (band_x * 2.0 - 0.12) * float(i) / float(bolts - 1)
				_gear_bolt(k, Vector3(x, y, face * (t + 0.005)), n, 0.014, 0.008)
		# The dark channels down the edges that hold the lit strips.
		k.color = DARK
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(ch, height * 0.84, 0.008), Vector3(sx * (hw - 0.07), 0.0, face * (t + 0.002)))
			g.box(Vector3(0.035, height * 0.8, 0.012), Vector3(sx * (hw - 0.07), 0.0, face * (t + 0.006)))
		# Panel seams across the leaf.
		k.color = DETAIL
		for y: float in [-height * 0.3, height * 0.05]:
			k.box(Vector3(width - 0.24, 0.025, 0.008), Vector3(0.0, y, face * (t + 0.003)))
		# The window: a dark pane in a steel bezel.
		var win := Vector2(width * 0.35, height * 0.18)
		var wy := height * 0.28
		k.color = DARK
		k.box(Vector3(win.x, win.y, 0.008), Vector3(0.0, wy, face * (t + 0.004)))
		k.color = DETAIL
		var bz := face * (t + 0.006)
		for sy: float in [-1.0, 1.0]:
			k.box(Vector3(win.x + 0.06, 0.03, 0.012), Vector3(0.0, wy + sy * (win.y * 0.5 + 0.015), bz))
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(0.03, win.y, 0.012), Vector3(sx * (win.x * 0.5 + 0.015), wy, bz))
		# The D-handle on two standoffs, a keypad over it with a lock lamp.
		k.color = DETAIL
		for sy: float in [-1.0, 1.0]:
			k.box(Vector3(0.04, 0.04, 0.03), Vector3(hx, hy + sy * (gl * 0.5 - 0.03), face * (t + 0.015)))
		k.color = DARK
		k.box(Vector3(0.035, gl, 0.022), Vector3(hx, hy, face * (t + 0.039)))
		var ky := hy + gl * 0.5 + 0.11
		k.box(Vector3(0.09, 0.13, 0.016), Vector3(hx, ky, face * (t + 0.006)))
		g.box(Vector3(0.03, 0.02, 0.006), Vector3(hx, ky + 0.035, face * (t + 0.016)))
		# A hazard band along the foot, above the bottom band.
		_gear_hazard(k, Vector3(0.0, -hh + fb + 0.04 + haz * 0.5, face * t), Vector3.RIGHT, Vector3.UP, n,
				Vector2(width - 0.3, haz), haz)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * thickness * 0.5
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, thickness + 0.06)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A docking port on a hull face (+Y out): a square base plate with cut corners and a bolt
## circle, a yellow collar ring with a dark-and-yellow hazard band round its wall, a dark
## seal on its face, four chrome guide pins and four latch blocks round its inner edge, and
## a dark recess holding an iris hatch (seams, a chrome hub). Two green status lamps on
## the plate's corners (PartShape.glow).
static func docking_port(radius: float = 0.8, depth: float = 0.3) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var h := depth * 0.5
	var side := radius * 2.0 + 0.2
	var base := depth * 0.35
	var y_b := -h + base                         # top of the base plate
	var pin := clampf(depth * 0.18, 0.025, 0.05) # guide pins stand this far over the collar, m
	var y_c := h - pin                           # the collar's face
	var r_in := radius * 0.72
	var y_hatch := y_c - maxf(0.035, depth * 0.17)
	var cut := side * 0.09
	# The base plate and a bolt circle round the collar.
	k.color = Color.WHITE
	k.loft(_chamfer_ring(side * 0.5, -h, cut), _chamfer_ring(side * 0.5, y_b, cut))
	k.color = DETAIL
	var bolts := 12 if radius > 0.45 else 8
	var br := clampf(radius * 0.03, 0.012, 0.022)
	for i in bolts:
		var a := TAU * (float(i) + 0.5) / float(bolts)
		_gear_bolt(k, Vector3(cos(a) * (radius + 0.05), y_b, sin(a) * (radius + 0.05)), Vector3.UP, br, 0.012)
	# The collar, its hazard band, the seal on its face.
	k.color = DOCK_YELLOW
	k.lathe(PackedVector2Array([Vector2(r_in, y_b - 0.002), Vector2(radius, y_b - 0.002), Vector2(radius, y_c),
			Vector2(r_in, y_c)]), 24)
	var band := (y_c - y_b) * 0.4
	_gear_hazard_ring(k, radius - 0.01, radius + 0.006, y_b + (y_c - y_b) * 0.22, y_b + (y_c - y_b) * 0.22 + band, 24, 1,
			DARK, DOCK_YELLOW)
	var wall := radius - r_in
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(r_in + wall * 0.08, y_c - 0.002), Vector2(r_in + wall * 0.5, y_c - 0.002),
			Vector2(r_in + wall * 0.5, y_c + 0.008), Vector2(r_in + wall * 0.08, y_c + 0.008)]), 24)
	# Guide pins on the collar's face, latch blocks round its inner edge between them.
	var pr := clampf(radius * 0.035, 0.012, 0.028)
	var rp := r_in + wall * 0.74
	k.color = TRIM
	for i in 4:
		var a := TAU * float(i) / 4.0
		var c := Vector3(cos(a) * rp, 0.0, sin(a) * rp)
		var ring_a := PackedVector3Array()
		var ring_b := PackedVector3Array()
		var ring_c := PackedVector3Array()
		for j in 6:
			var t := TAU * float(j) / 6.0
			var o := Vector3(cos(t), 0.0, sin(t)) * pr
			ring_a.append(c + o + Vector3(0.0, y_c - 0.002, 0.0))
			ring_b.append(c + o + Vector3(0.0, h - pr * 0.8, 0.0))
			ring_c.append(c + o * 0.45 + Vector3(0.0, h, 0.0))
		k.loft(ring_a, ring_b, false)
		k.loft(ring_b, ring_c)
		k.poly(ring_a, Vector3.DOWN)
	k.color = DETAIL
	var lw := clampf(radius * 0.07, 0.03, 0.06)
	for i in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		var rc := r_in - lw * 0.5 + 0.004
		_gear_yblock(k, Vector3(cos(a) * rc, (y_hatch + y_c) * 0.5 + 0.004, sin(a) * rc), -a,
				Vector3(lw, y_c - y_hatch, lw * 1.6))
	# The recess and the iris hatch in it: a dark-steel leaf, six seams, a chrome hub.
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(0.0, y_b - 0.002), Vector2(r_in - 0.004, y_b - 0.002), Vector2(r_in - 0.004, y_hatch),
			Vector2(0.0, y_hatch)]), 24)
	k.color = RIM
	var leaf := minf(0.012, (y_c - y_hatch) * 0.3)
	k.lathe(PackedVector2Array([Vector2(0.0, y_hatch), Vector2(r_in * 0.9, y_hatch), Vector2(r_in * 0.9, y_hatch + leaf),
			Vector2(0.0, y_hatch + leaf)]), 24)
	k.color = DARK
	for i in 6:
		var a := TAU * float(i) / 6.0
		var rc := r_in * 0.53
		_gear_yblock(k, Vector3(cos(a) * rc, y_hatch + leaf + 0.002, sin(a) * rc), -a, Vector3(r_in * 0.72, 0.006, 0.014))
	k.color = TRIM
	k.lathe(PackedVector2Array([Vector2(0.0, y_hatch + leaf - 0.002), Vector2(r_in * 0.17, y_hatch + leaf - 0.002),
			Vector2(r_in * 0.13, y_hatch + leaf + 0.018), Vector2(0.0, y_hatch + leaf + 0.018)]), 8)
	# Two status lamps on the plate's corners: dark housings, lit lenses.
	var lr := clampf(radius * 0.04, 0.016, 0.03)
	var lc := side * 0.5 - cut * 0.5 - lr * 2.2
	for s: float in [-1.0, 1.0]:
		var at := Vector3(s * lc, y_b, -s * lc)
		k.color = DARK
		var ring_a := PackedVector3Array()
		var ring_b := PackedVector3Array()
		var dome := PackedVector3Array()
		for j in 6:
			var t := TAU * float(j) / 6.0
			ring_a.append(at + Vector3(cos(t) * lr * 1.5, -0.002, sin(t) * lr * 1.5))
			ring_b.append(at + Vector3(cos(t) * lr * 1.4, 0.02, sin(t) * lr * 1.4))
			dome.append(at + Vector3(cos(t) * lr, 0.034, sin(t) * lr))
		k.loft(ring_a, ring_b)
		var lens := PackedVector3Array()
		for j in 6:
			var t := TAU * float(j) / 6.0
			lens.append(at + Vector3(cos(t) * lr, 0.018, sin(t) * lr))
		g.loft(lens, dome)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = side * side * base + PI * radius * radius * (depth - base) * 0.3
	var col := BoxShape3D.new()
	col.size = Vector3(side, depth, side)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = Color(0.3, 1.0, 0.45)
	return shape



# --- Arinox parts (0.25 additions) --------------------------------------------------------

## A twin-nozzle main engine pod: a rounded (stadium) housing `width` across X and
## `height` across Z, `depth` deep along Y: a dark bolted mount flange at -Y, a body in the
## material colour with a steel band, bolted access panels on its flat sides (a lamp pair
## on -Z, two fuel feeds up +Z) and a heat-shield band, a pale cowl tapering to the +Y face,
## where two hollow round nozzles stand: dark flanges (bolted on big pods), steel collars,
## pale lips, ceramic liners down to an injector floor with a hub and a glowing ring
## (PartShape.glow). Turn it with `Basis(Vector3.RIGHT, PI / 2)` to blow aft (+Z) from a
## stern face.
static func thruster_pod(width: float, height: float, depth: float, glow := Color(0.35, 0.65, 1.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var h := depth * 0.5
	var e := clampf(height * 0.035, 0.03, 0.08)          # mount flange ledge, m
	var fl := clampf(depth * 0.05, 0.03, 0.1)            # mount flange, m
	var y0 := -h + fl
	var y_sh := -h + depth * 0.8                         # where the cowl starts, m
	var y_face := h - clampf(depth * 0.04, 0.02, 0.1)    # the nozzle face, m
	var y_top := h + 0.04                                # the nozzle lips, m
	var outer := PartShapes._stadium(width, height, 6)
	var body := PartShapes._stadium(width - e * 2.0, height - e * 2.0, 6)
	var cowl := PackedVector2Array()
	for p in body:
		cowl.append(Vector2(p.x * 0.93, p.y * 0.9))
	# The mount flange, bolted round its ledge; the body; the cowl up to the holed face.
	k.color = DARK
	k.loft(_engines_ring(outer, -h), _engines_ring(outer, y0))
	k.color = DETAIL
	_engines_ledge_bolts(k, PartShapes._stadium(width - e, height - e, 6), y0, clampf(e * 0.3, 0.008, 0.024), height * 0.3)
	k.color = Color.WHITE
	k.loft(_engines_ring(body, y0), _engines_ring(body, y_sh), false)
	k.color = TRIM
	k.loft(_engines_ring(body, y_sh), _engines_ring(cowl, y_face), false)
	var cx := (width - e * 2.0) * 0.465 * 0.5
	var zc := (height - e * 2.0) * 0.45
	var nr := minf(minf(height * 0.4, zc - 0.02), cx - 0.04)
	_engines_holed_face(k, cowl, y_face, [Vector2(-cx, 0.0), Vector2(cx, 0.0)] as Array[Vector2], nr * 0.8)
	# A steel band low on the body, a heat-shield band under the cowl.
	var band := PartShapes._stadium(width - e, height - e, 6)
	var bw := clampf(depth * 0.03, 0.02, 0.08)
	var yb := lerpf(y0, y_sh, 0.35)
	var under := PartShapes._stadium(width - e * 2.0 - 0.01, height - e * 2.0 - 0.01, 6)
	_engines_band(k, band, under, yb - bw * 0.5, yb + bw * 0.5, DETAIL)
	_engines_band(k, band, under, y_sh - bw * 1.5, y_sh, HEAT_SHIELD)
	# Access panels on the flat sides (+-Z), screwed down; a dark bezel with two lamps on -Z.
	var zs := (height - e * 2.0) * 0.5                   # the flat sides, m
	var straight := width - height                       # their run along X, m
	var pw := straight * 0.55
	var pan_h := (y_sh - y0) * 0.42
	var pm := lerpf(y0, y_sh, 0.64)
	var pt := 0.012
	var pz := zs + pt - 0.004                            # the panels' outer face, m
	var bs := clampf(height * 0.02, 0.014, 0.04)
	for sz: float in [-1.0, 1.0]:
		k.color = TRIM
		k.box(Vector3(pw, pan_h, pt), Vector3(0.0, pm, sz * (pz - pt * 0.5)))
		k.color = DETAIL
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				k.box(Vector3(bs, bs, 0.008), Vector3(sx * (pw * 0.5 - bs * 1.3), pm + sy * (pan_h * 0.5 - bs * 1.3), sz * (pz + 0.004)))
	var led := clampf(height * 0.03, 0.02, 0.06)
	var led_y := pm + pan_h * 0.22
	k.color = DARK
	k.box(Vector3(led * 4.6, led * 2.0, 0.006), Vector3(0.0, led_y, -(pz + 0.003)))
	for sx: float in [-1.0, 1.0]:
		g.box(Vector3(led, led, 0.004), Vector3(sx * led * 1.2, led_y, -(pz + 0.008)))
	# Two fuel feeds up the +Z side from the flange into the body, flanged where they enter.
	var pr := clampf(e * 0.4, 0.012, 0.03)
	var y_feed := lerpf(y0, y_sh, 0.25)
	for sx: float in [-1.0, 1.0]:
		var x := sx * (pw * 0.5 + pr * 3.0)
		var zp := zs + pr + 0.004
		k.color = DETAIL
		_tube(k, Vector3(x, y0 - 0.002, zp), Vector3(x, y_feed, zp), pr, 8)
		k.color = DARK
		_tube(k, Vector3(x, y0 - 0.002, zp), Vector3(x, y0 + pr * 1.2, zp), pr * 1.5, 8)
		k.box(Vector3(pr * 3.2, pr * 3.2, pr * 2.4), Vector3(x, y_feed, zs + pr * 1.2 - 0.004))
	# The nozzles, their throats sunk into the body.
	var y_floor := y_face - depth * 0.3
	for sx: float in [-1.0, 1.0]:
		_engines_nozzle(k, g, Vector3(sx * cx, 0.0, 0.0), nr, y_floor - 0.01, lerpf(y_face, y_top, 0.35), y_top, y_floor, 20,
				[RIM, DETAIL, TRIM] as Array[Color], Vector3(0.94, 0.82, 0.86), nr >= 0.2, true)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * depth * 0.6
	var col := BoxShape3D.new()
	col.size = Vector3(width, depth + 0.1, height)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## The engines family's round nozzle, exhaust +Y, standing at `c` (y = 0) with its lip
## `r` round: a flange in zones[0] (`shape.x` of r) from `y_base` up to a shelf at
## `y_shelf` (bolted when `bolts`), a collar in zones[1] widening from `shape.y` to
## `shape.z` of r, a lip in zones[2] up to `y_top`, a ceramic liner narrowing down to a dark
## floor at `y_floor` with a steel injector ring (and a hub cone when `hub`); the floor
## inside the ring glows (into `g`). `y_base` must lie under `y_floor`.
static func _engines_nozzle(k: MeshKit, g: MeshKit, c: Vector3, r: float, y_base: float, y_shelf: float,
		y_top: float, y_floor: float, seg: int, zones: Array[Color], shape: Vector3, bolts: bool,
		hub: bool = false) -> void:
	var r_fl := r * shape.x
	var r_c0 := r * shape.y
	var r_in := r * 0.74
	var r_th := r * 0.52
	var lip := clampf((y_top - y_shelf) * 0.3, 0.008, r * 0.25)
	_piping_spin(k, c, Vector3.UP, PackedVector2Array([Vector2(0.0, y_base), Vector2(r_fl, y_base),
			Vector2(r_fl, y_shelf), Vector2(r_c0, y_shelf), Vector2(r * shape.z, y_top - lip), Vector2(r, y_top - lip),
			Vector2(r, y_top), Vector2(r_in, y_top), Vector2(r_in * 0.96, lerpf(y_top, y_floor, 0.35)),
			Vector2(r_th, y_floor), Vector2(0.0, y_floor)]),
			[zones[0], zones[0], zones[0], zones[1], zones[2], zones[2], zones[2], LINER, LINER, DARK] as Array[Color], seg)
	var ring_h := clampf((y_top - y_floor) * 0.05, 0.004, 0.03)
	_piping_spin(k, c, Vector3.UP, PackedVector2Array([Vector2(r_th * 0.8, y_floor), Vector2(r_th * 0.8, y_floor + ring_h),
			Vector2(r_th * 0.62, y_floor + ring_h), Vector2(r_th * 0.62, y_floor)]), [DETAIL] as Array[Color], seg)
	if hub:
		var tall := (y_top - y_floor) * 0.4
		_piping_spin(k, c, Vector3.UP, PackedVector2Array([Vector2(r_th * 0.3, y_floor), Vector2(r_th * 0.22, y_floor + tall * 0.7),
				Vector2(0.0, y_floor + tall)]), [DETAIL] as Array[Color], maxi(seg / 2, 8))
	if bolts:
		var ring_r := (r_fl + r_c0) * 0.5
		var bs := (r_fl - r_c0) * 0.55
		k.color = DETAIL
		_piping_bolts(k, c, Vector3.UP, y_shelf, clampi(int(TAU * ring_r / (bs * 4.0)), 8, 16), ring_r, bs, bs * 0.45)
	var gy := y_floor + clampf((y_top - y_floor) * 0.02, 0.003, 0.012)
	_piping_spin(g, c, Vector3.UP, PackedVector2Array([Vector2(r_th * 0.6, y_floor), Vector2(r_th * 0.6, gy), Vector2(0.0, gy)]),
			[Color.WHITE] as Array[Color], maxi(seg - 4, 8))


## An outline (x, z) as a ring of points at height `y`.
static func _engines_ring(outline: PackedVector2Array, y: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in outline:
		out.append(Vector3(p.x, y, p.y))
	return out


## Hex bolts about `spacing` apart round an outline (x, z), standing on y (+Y).
static func _engines_ledge_bolts(k: MeshKit, outline: PackedVector2Array, y: float, radius: float, spacing: float) -> void:
	var n := outline.size()
	var lengths := PackedFloat32Array()
	var total := 0.0
	for i in n:
		lengths.append(outline[i].distance_to(outline[(i + 1) % n]))
		total += lengths[i]
	var count := clampi(roundi(total / spacing), 8, 16)
	var edge := 0
	var start := 0.0
	for j in count:
		var s := (float(j) + 0.5) * total / float(count)
		while edge < n - 1 and s > start + lengths[edge]:
			start += lengths[edge]
			edge += 1
		var p := outline[edge].lerp(outline[(edge + 1) % n], clampf((s - start) / maxf(lengths[edge], 1e-6), 0.0, 1.0))
		_thrusters_bolt(k, Vector3(p.x, y, p.y), radius, radius * 0.7)


## A flat face at `y` facing +Y over the convex `outline` (x, z), with a round hole
## `hole_r` round each of `holes` (x, z, in order along X): split halfway between holes,
## each part fanned in from its edge to its hole's rim.
static func _engines_holed_face(k: MeshKit, outline: PackedVector2Array, y: float, holes: Array[Vector2],
		hole_r: float) -> void:
	for i in holes.size():
		var c := holes[i]
		var part := outline
		if i > 0:
			part = _engines_clip_x(part, (holes[i - 1].x + c.x) * 0.5, true)
		if i < holes.size() - 1:
			part = _engines_clip_x(part, (holes[i + 1].x + c.x) * 0.5, false)
		var pts := PackedVector2Array()
		for j in part.size():
			var a := part[j]
			var b := part[(j + 1) % part.size()]
			var n := maxi(1, ceili(a.distance_to(b) / (hole_r * 0.35)))
			for s in n:
				pts.append(a.lerp(b, float(s) / float(n)))
		for j in pts.size():
			var a := pts[j]
			var b := pts[(j + 1) % pts.size()]
			var ha := c + (a - c).normalized() * hole_r
			var hb := c + (b - c).normalized() * hole_r
			k.quad(Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(hb.x, y, hb.y), Vector3(ha.x, y, ha.y), Vector3.UP)


## A convex outline (x, z) cut at x: the part above it (`keep_above`) or below.
static func _engines_clip_x(outline: PackedVector2Array, x: float, keep_above: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := outline.size()
	for i in n:
		var a := outline[i]
		var b := outline[(i + 1) % n]
		var in_a := a.x >= x - 1e-6 if keep_above else a.x <= x + 1e-6
		var in_b := b.x >= x - 1e-6 if keep_above else b.x <= x + 1e-6
		if in_a:
			out.append(a)
		if in_a != in_b:
			out.append(a.lerp(b, (x - a.x) / (b.x - a.x)))
	return out


## Builds the housing `octagon_thruster` and `oval_engine` share: `ring` gives its outline
## (x, z) shrunk by an inset (m). A dark mount flange at -Y bolted round its ledge, a drum
## set in by `e` in the material colour with a steel band and a heat-shield band, a pale
## rim round the +Y face framing a dark recess `rim_in` in, and two nozzles `nr` round at
## x = +-`cx` standing in it, their throats sunk into the drum (glow into `g`).
static func _engines_twin_housing(k: MeshKit, g: MeshKit, ring: Callable, depth: float, e: float, rim_in: float,
		nr: float, cx: float, hub: bool) -> void:
	var h := depth * 0.5
	var fl := clampf(depth * 0.08, 0.025, 0.08)          # mount flange, m
	var rim_t := clampf(depth * 0.12, 0.04, 0.14)        # rim, m
	var y_drum := h - rim_t
	var y_rec := h - clampf(depth * 0.3, 0.12, 0.5)      # recess floor, m
	var outer: PackedVector2Array = ring.call(0.0)
	var inner: PackedVector2Array = ring.call(rim_in)
	var proud: PackedVector2Array = ring.call(e * 0.5)
	k.color = DARK
	k.loft(_engines_ring(outer, -h), _engines_ring(outer, -h + fl))
	k.color = DETAIL
	_engines_ledge_bolts(k, proud, -h + fl, clampf(e * 0.3, 0.008, 0.024), maxf(depth * 0.4, 0.25))
	k.color = Color.WHITE
	var drum: PackedVector2Array = ring.call(e)
	k.loft(_engines_ring(drum, -h + fl), _engines_ring(drum, y_drum), false)
	var bw := clampf(depth * 0.04, 0.015, 0.06)
	var yb := lerpf(-h + fl, y_drum, 0.3)
	var under: PackedVector2Array = ring.call(e + 0.005)
	_engines_band(k, proud, under, yb - bw * 0.5, yb + bw * 0.5, DETAIL)
	_engines_band(k, proud, under, y_drum - bw * 2.2, y_drum, HEAT_SHIELD)
	# The rim, its inner edge bevelled down; the recess's dark wall and floor under it.
	var rim := MeshKit.new()
	rim.color = TRIM
	PartShapes._frame_between(rim, outer, inner, rim_t, rim_t * 0.3)
	_engines_append(k, rim, Vector3(0.0, h - rim_t * 0.5, 0.0))
	var wall := MeshKit.new()
	wall.color = DARK
	PartShapes._frame_between(wall, ring.call(rim_in - 0.02), inner, y_drum - y_rec, 0.0)
	_engines_append(k, wall, Vector3(0.0, (y_drum + y_rec) * 0.5, 0.0))
	k.color = DARK
	_engines_holed_face(k, inner, y_rec, [Vector2(-cx, 0.0), Vector2(cx, 0.0)] as Array[Vector2], nr * 0.8)
	var y_top := h - clampf(depth * 0.015, 0.006, 0.02)
	var y_floor := y_rec - minf(depth * 0.3, (y_rec + h - fl) * 0.85)
	for sx: float in [-1.0, 1.0]:
		_engines_nozzle(k, g, Vector3(sx * cx, 0.0, 0.0), nr, y_floor - 0.01, lerpf(y_rec, y_top, 0.3), y_top, y_floor, 20,
				[RIM, DETAIL, TRIM] as Array[Color], Vector3(0.94, 0.82, 0.86), nr >= 0.2, hub)


## A band round a housing from y0 to y1 in `color`: its outside on the outline `outer`
## and its top and bottom faces in to `inner` (x, z, the same count of points, under the
## housing's skin), nothing inside it.
static func _engines_band(k: MeshKit, outer: PackedVector2Array, inner: PackedVector2Array, y0: float, y1: float,
		color: Color) -> void:
	k.color = color
	var n := outer.size()
	for i in n:
		var j := (i + 1) % n
		var oi := Vector3(outer[i].x, 0.0, outer[i].y)
		var oj := Vector3(outer[j].x, 0.0, outer[j].y)
		var ii := Vector3(inner[i].x, 0.0, inner[i].y)
		var ij := Vector3(inner[j].x, 0.0, inner[j].y)
		var up0 := Vector3(0.0, y0, 0.0)
		var up1 := Vector3(0.0, y1, 0.0)
		k.quad(oi + up0, oj + up0, oj + up1, oi + up1, (oi + oj) * 0.5)
		k.quad(oi + up1, oj + up1, ij + up1, ii + up1, Vector3.UP)
		k.quad(oi + up0, oj + up0, ij + up0, ii + up0, Vector3.DOWN)


## Copies `src` into `k`, moved by `offset`.
static func _engines_append(k: MeshKit, src: MeshKit, offset: Vector3) -> void:
	for i in src.verts.size():
		k.verts.append(src.verts[i] + offset)
		k.normals.append(src.normals[i])
		k.colors.append(src.colors[i])


## A thin trim bar `length` along X, `width` across Z: a dark anodised channel with
## chamfered anodised lips and plastic end caps, lit cells sunk in it on top (+Y) under a
## frosted diffuser (PartShape.glass): the cyan edge lights of SE2 hulls. Lay it on a plate with the strip up.
static func light_strip(length: float, width: float = 0.14, thickness: float = 0.06,
		glow := Color(0.3, 0.95, 1.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := thickness * 0.5
	var hw := width * 0.5
	# The housing: a dark anodised extrusion whose floor sits a lip's depth under the top,
	# between two anodised lips with chamfered outer edges; plastic end caps close it off.
	# Cheap: drawn a lot.
	var lip := clampf(thickness * 0.3, 0.008, 0.015)
	var y_floor := h - lip
	var cap := clampf(length * 0.04, 0.02, 0.05)
	var x_end := length * 0.5 - 0.004
	k.color = RAIL_DARK
	k.box(Vector3(x_end * 2.0, y_floor + h, width), Vector3(0.0, (y_floor - h) * 0.5, 0.0))
	k.color = ANODISED
	var rw := clampf(width * 0.12, 0.01, 0.02)
	var ch := minf(lip * 0.6, rw * 0.5)
	for sz: float in [-1.0, 1.0]:
		var zo := sz * (hw - 0.003)
		var zi := sz * (hw - 0.003 - rw)
		_prism_x(k, PackedVector2Array([Vector2(zi, y_floor), Vector2(zo, y_floor), Vector2(zo, h - ch),
				Vector2(zo - sz * ch, h), Vector2(zi, h)]), -x_end + cap, x_end - cap)
	# End caps: chamfered plastic blocks a few millimetres proud of the housing all round.
	k.color = PLASTIC_DARK
	var cc := minf(0.012, thickness * 0.3)
	var cz := hw + 0.003
	var cy := h + 0.004
	var cap_zy := PackedVector2Array([Vector2(-cz, -h + 0.003), Vector2(cz, -h + 0.003), Vector2(cz, cy - cc),
			Vector2(cz - cc, cy), Vector2(-cz + cc, cy), Vector2(-cz, cy - cc)])
	for sx: float in [-1.0, 1.0]:
		_prism_x(k, cap_zy, sx * length * 0.5, sx * (length * 0.5 - cap))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * width * thickness * 0.9
	var col := BoxShape3D.new()
	col.size = Vector3(length, thickness + 0.02, width)
	shape.collision = col
	# The diffuser: lit cells sunk in the channel between the lips; the gaps between them
	# show the dark floor as dividers. One flat face per cell keeps a long strip cheap.
	var g := MeshKit.new()
	var run := (x_end - cap) * 2.0
	var cells := 1 if length < 0.9 else clampi(int(round(run / 0.5)), 2, 24)
	var gap := clampf(width * 0.4, 0.03, 0.07)
	var cell := (run - gap * float(cells + 1)) / float(cells)
	var gz := hw - 0.003 - rw - 0.004
	var gy := h - minf(0.004, lip * 0.4)
	for i in cells:
		var x0 := -run * 0.5 + gap + (cell + gap) * float(i)
		g.quad(Vector3(x0, gy, -gz), Vector3(x0 + cell, gy, -gz), Vector3(x0 + cell, gy, gz), Vector3(x0, gy, gz),
				Vector3.UP)
	shape.glow = g.finish()
	shape.glow_color = glow
	# A frosted diffuser over the whole run of cells, a hair proud of them and still under
	# the lips' tops, sitting between the lips.
	var dk := MeshKit.new()
	var dy := minf(gy + 0.002, h - 0.001)
	var dz := hw - 0.003 - rw - 0.001
	dk.quad(Vector3(-run * 0.5, dy, -dz), Vector3(run * 0.5, dy, -dz), Vector3(run * 0.5, dy, dz),
			Vector3(-run * 0.5, dy, dz), Vector3.UP)
	shape.glass = dk.finish()
	shape.glass_kind = Glazing.Kind.FROSTED
	return shape


## A reactor: a drum `radius` round and `height` tall on a dark chamfered plinth (-Y) with
## a bolt at each corner, a bolted base flange, a band of yellow and dark hazard checks,
## ribs, two clamp bands with tensioners on +X, a dark viewing band at its waist behind
## mullions with glowing window slots, a lit gauge strip on its -Z side, a bolted top
## flange under a stepped cap with a boss and four flanged pipe stubs. Collision is a
## cylinder round the plinth.
static func reactor(radius: float, height: float, glow := Color(1.0, 0.25, 0.2)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var r := radius
	var h := height * 0.5
	var u := clampf(radius, 0.3, 1.0)            # detail scale
	var vs := clampf(height / 3.0, 0.55, 1.1)    # vertical scale for the cap stack
	var seg := 20
	var plinth := 0.2
	var pb := -h + plinth
	# The plinth: a chamfered square slab with a bevelled top edge and a bolt at each corner.
	k.color = DARK
	var ph := r * 1.2
	var pc := r * 0.3
	var bev := minf(0.04, r * 0.1)
	k.loft(_chamfer_ring(ph, -h, pc), _chamfer_ring(ph, pb - bev, pc))
	k.loft(_chamfer_ring(ph, pb - bev, pc), _chamfer_ring(ph - bev, pb, pc))
	k.color = DETAIL
	var pbolt := 0.06 * u
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(pbolt, pbolt * 0.5, pbolt), Vector3(sx * r * 0.86, pb + pbolt * 0.25, sz * r * 0.86))
	# Heights up the drum.
	var fl := 0.05 * u                            # base flange
	var hz0 := pb + fl + 0.06 * vs                # hazard band
	var hz1 := hz0 + clampf(height * 0.07, 0.1, 0.22)
	var wh := clampf(height * 0.045, 0.06, 0.12)  # waist window half height
	var lip := 0.035 * u
	var cb := 0.045 * u                           # clamp band half height
	var tf0 := h - 0.42 * vs                      # top flange
	var tfh := 0.06 * vs
	var ycap := h - 0.24 * vs
	var y_lc := lerpf(hz1, -wh - lip, 0.45)
	var y_uc := tf0 - 0.12 * vs
	var rb := r * 1.015
	# The drum's outline from the base flange to the cap, in two spins round the hazard band.
	var lower := PackedVector2Array([Vector2(r * 0.98, pb), Vector2(r * 1.1, pb), Vector2(r * 1.1, pb + fl),
			Vector2(r, pb + fl), Vector2(r, hz0), Vector2(rb, hz0)])
	_piping_spin(k, Vector3.ZERO, Vector3.UP, lower,
			[DETAIL, DETAIL, DETAIL, Color.WHITE, HAZARD_YELLOW] as Array[Color], seg)
	var upper := PackedVector2Array([Vector2(rb, hz1), Vector2(r, hz1),
			Vector2(r, y_lc - cb), Vector2(r * 1.06, y_lc - cb), Vector2(r * 1.06, y_lc + cb), Vector2(r, y_lc + cb),
			Vector2(r, -wh - lip), Vector2(r * 1.06, -wh - lip), Vector2(r * 1.06, -wh), Vector2(r * 1.02, -wh),
			Vector2(r * 1.02, wh), Vector2(r * 1.06, wh), Vector2(r * 1.06, wh + lip), Vector2(r, wh + lip),
			Vector2(r, y_uc - cb), Vector2(r * 1.06, y_uc - cb), Vector2(r * 1.06, y_uc + cb), Vector2(r, y_uc + cb),
			Vector2(r, tf0), Vector2(r * 1.08, tf0), Vector2(r * 1.08, tf0 + tfh), Vector2(r * 0.96, tf0 + tfh),
			Vector2(r * 0.96, tf0 + tfh + 0.04 * vs), Vector2(r * 0.66, ycap), Vector2(0.0, ycap)])
	var cols: Array[Color] = [HAZARD_YELLOW, Color.WHITE, DETAIL, DETAIL, DETAIL, Color.WHITE,
			DETAIL, DETAIL, DETAIL, DARK, DETAIL, DETAIL, DETAIL, Color.WHITE, DETAIL, DETAIL, DETAIL, Color.WHITE,
			DETAIL, DETAIL, DETAIL, Color.WHITE, Color.WHITE, Color.WHITE]
	_piping_spin(k, Vector3.ZERO, Vector3.UP, upper, cols, seg)
	# The hazard band's face: two rows of yellow and dark checks, one per segment.
	var at := func(a: float, y: float, rr: float) -> Vector3: return Vector3(cos(a) * rr, y, -sin(a) * rr)
	var hm := (hz0 + hz1) * 0.5
	for row in 2:
		var y0: float = hz0 if row == 0 else hm
		var y1: float = hm if row == 0 else hz1
		for s in seg:
			k.color = HAZARD_YELLOW if (s + row) % 2 == 0 else DARK
			var a0 := TAU * float(s) / float(seg)
			var a1 := TAU * float(s + 1) / float(seg)
			var am := (a0 + a1) * 0.5
			k.quad(at.call(a0, y0, rb), at.call(a1, y0, rb), at.call(a1, y1, rb), at.call(a0, y1, rb),
					Vector3(cos(am), 0.0, -sin(am)))
	# Bolt rings on the base and top flanges.
	k.color = DETAIL
	_piping_bolts(k, Vector3.ZERO, Vector3.UP, pb + fl, 10, r * 1.045, 0.045 * u, 0.025 * u)
	_piping_bolts(k, Vector3.ZERO, Vector3.UP, tf0 + tfh, 12, r * 1.025, 0.04 * u, 0.022 * u)
	# Ribs up the lower drum (between the clamp's tensioner on +X and the gauge on -Z), and
	# the mullions across the waist window.
	for i in 10:
		var a := TAU * float(2 * i + 1) / float(seg)
		k.strut(at.call(a, hz1, r), at.call(a, -wh - lip, r), 0.045 * u)
		var m := TAU * float(2 * i) / float(seg)
		k.strut(at.call(m, -wh, r * 1.03), at.call(m, wh, r * 1.03), 0.05 * u)
	# Tensioner blocks with their bolts on the clamp bands (+X).
	for y: float in [y_lc, y_uc]:
		k.box(Vector3(0.06 * u, cb * 2.6, 0.12 * u), Vector3(r * 1.06 + 0.03 * u, y, 0.0))
		k.box(Vector3(0.025 * u, cb * 3.6, 0.04 * u), Vector3(r * 1.06 + 0.07 * u, y, 0.0))
	# The cap's boss and four pipe stubs, each with a weld-neck flange at its top.
	k.lathe(PackedVector2Array([Vector2(0.0, ycap), Vector2(r * 0.26, ycap), Vector2(r * 0.26, ycap + 0.05 * vs),
			Vector2(r * 0.2, ycap + 0.08 * vs), Vector2(0.0, ycap + 0.08 * vs)]), 12)
	var pr := clampf(r * 0.08, 0.035, 0.08)
	for i in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		var c := Vector3(cos(a) * r * 0.47, 0.0, sin(a) * r * 0.47)
		_piping_spin(k, c, Vector3.UP, PackedVector2Array([Vector2(pr, ycap), Vector2(pr, h - 0.09 * vs),
				Vector2(pr * 1.35, h - 0.07 * vs), Vector2(pr * 1.8, h - 0.07 * vs), Vector2(pr * 1.8, h),
				Vector2(0.0, h)]), [DETAIL] as Array[Color], 10)
	# The gauge on -Z: a dark bezel between the waist and the upper clamp band.
	var g0 := wh + lip + 0.05 * vs
	var g1 := y_uc - cb - 0.04 * vs
	var gl := minf(g1 - g0, 0.8)
	var gy := (g0 + g1) * 0.5
	var gw := 0.16 * u
	var gz := -r * 0.985
	var gd := 0.04 * u + r * 0.015
	k.color = DARK
	k.box(Vector3(gw, gl, gd), Vector3(0.0, gy, gz - gd * 0.5))
	k.color = DETAIL
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(gw * 0.4, 0.03 * u, 0.012), Vector3(0.0, gy + sy * (gl * 0.5 - 0.03 * u), gz - gd - 0.006))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * radius * radius * height * 0.6
	var col := CylinderShape3D.new()
	col.radius = radius * 1.2
	col.height = height
	shape.collision = col
	# Lit: a window slot behind each pair of mullions round the waist, and five gauge cells.
	var g := MeshKit.new()
	var rg := r * 1.024
	for s in seg:
		var a0 := TAU * float(s) / float(seg)
		var a1 := TAU * float(s + 1) / float(seg)
		var am := (a0 + a1) * 0.5
		g.quad(at.call(a0, -wh * 0.8, rg), at.call(a1, -wh * 0.8, rg), at.call(a1, wh * 0.8, rg), at.call(a0, wh * 0.8, rg),
				Vector3(cos(am), 0.0, -sin(am)))
	var cells := 5
	var span := gl - 0.12 * u
	for i in cells:
		var y := gy - span * 0.5 + span * (float(i) + 0.5) / float(cells)
		g.box(Vector3(gw * 0.6, span / float(cells) * 0.62, 0.006), Vector3(0.0, y, gz - gd - 0.003))
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## An industrial machine (refinery, assembler, gas generator, pumps, control cabinets): a
## cabinet `size` (x, y, z) on a recessed dark plinth under a lipped cap, a tapered hopper
## rising to a collared dark mouth, two flanged feed pipes on the cap behind it. Its front
## (-Z) has framing posts with bolts, a dark bezelled control panel (a lit screen with dark
## readout bars, a row of buttons, three status LEDs), a hazard label and a hinged service
## door with a handle and a louvre; each side a louvred grille under a bolted service
## plate, and a conduit runs up the back corner at +X. `glow` lights the screen and LEDs.
static func machine_unit(size: Vector3, glow := Color(0.3, 1.0, 0.45)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := size.y * 0.5
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var front := -hz
	var plinth := minf(0.08, size.y * 0.06)    # kick plinth height, m
	var y0 := -h + plinth                       # bottom of the body, m
	var y_top := -h + size.y * 0.82             # top of the body (under the cap), m
	var bh := y_top - y0
	var cap := minf(0.05, size.y * 0.025)       # lip round the body's top, m
	# Plinth (set in at the front and sides), body, the lip on top.
	k.color = DARK
	k.box(Vector3(size.x - 0.06, plinth, size.z - 0.04), Vector3(0.0, -h + plinth * 0.5, 0.02))
	k.color = Color.WHITE
	k.box(Vector3(size.x, bh, size.z), Vector3(0.0, y0 + bh * 0.5, 0.0))
	k.color = DETAIL
	var y_cap := y_top + 0.004
	k.box(Vector3(size.x + 0.02, cap, size.z + 0.01), Vector3(0.0, y_cap - cap * 0.5, -0.005))
	# The hopper, set forward on the cap so the feed pipes stand behind it, up to a collar
	# round a dark mouth.
	var zo := -size.z * 0.08
	var collar := minf(0.06, (h - y_cap) * 0.25)
	var yc := h - collar
	var ring_a := PackedVector3Array()
	var ring_b := PackedVector3Array()
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		ring_a.append(Vector3(c.x * size.x * 0.44, y_cap, zo + c.y * size.z * 0.36))
		ring_b.append(Vector3(c.x * size.x * 0.3, yc, zo + c.y * size.z * 0.22))
	k.color = Color.WHITE
	k.loft(ring_a, ring_b)
	var cx := size.x * 0.32
	var cz := size.z * 0.24
	var ct := minf(0.04, size.z * 0.05)
	k.color = DETAIL
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(cx * 2.0, collar, ct), Vector3(0.0, yc + collar * 0.5, zo + sz * (cz - ct * 0.5)))
		k.box(Vector3(ct, collar, cz * 2.0 - ct * 2.0), Vector3(sz * (cx - ct * 0.5), yc + collar * 0.5, zo))
	k.color = DARK
	k.box(Vector3(cx * 2.0 - ct * 2.0, collar * 0.6, cz * 2.0 - ct * 2.0), Vector3(0.0, yc + collar * 0.3, zo))
	# Two feed pipes on the cap behind the hopper, a flange at the foot and the top.
	var pr := clampf(size.x * 0.05, 0.03, 0.07)
	var stub := minf((h - y_cap) * 0.7, 0.3)
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(sx * (hx - pr - 0.06), y_cap, hz - pr - 0.04)
		k.color = DETAIL
		_tube(k, p, p + Vector3(0.0, stub, 0.0), pr, 8)
		k.color = TRIM
		_tube(k, p, p + Vector3(0.0, 0.025, 0.0), pr * 1.35, 8)
		_tube(k, p + Vector3(0.0, stub - 0.03, 0.0), p + Vector3(0.0, stub, 0.0), pr * 1.35, 8)
		k.color = DARK
		_tube(k, p + Vector3(0.0, stub, 0.0), p + Vector3(0.0, stub + 0.004, 0.0), pr * 0.8, 8)
	# Framing posts up the front corners with bolts.
	var pw := clampf(size.x * 0.05, 0.03, 0.06)
	var post_h := bh - cap
	for sx: float in [-1.0, 1.0]:
		var x := sx * (hx - pw * 0.5)
		k.color = DETAIL
		k.box(Vector3(pw, post_h, 0.012), Vector3(x, y0 + post_h * 0.5, front - 0.006))
		k.color = TRIM
		for t: float in [0.08, 0.5, 0.92]:
			k.box(Vector3(0.02, 0.02, 0.008), Vector3(x, y0 + post_h * t, front - 0.016))
	# The control panel: a dark chamfered bezel, a screen (lit) crossed by dark readout
	# bars, a row of buttons under it and three LEDs beside it.
	var g := MeshKit.new()
	var pwid := size.x - pw * 2.0 - 0.1
	var ph := bh * 0.3
	var pc := Vector3(0.0, y0 + bh * 0.73, front)
	k.color = DARK
	_cabinets_pad(k, pc, Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, pwid * 0.5, ph * 0.5, 0.025, 0.012)
	var pf := front - 0.025
	var scr := Vector3(-pwid * 0.14, pc.y + ph * 0.1, pf - 0.003)
	var sw := pwid * 0.52
	var sh := ph * 0.52
	g.box(Vector3(sw, sh, 0.004), scr)
	k.color = DARK
	for i in 3:
		var bw := sw * (0.7 - 0.2 * float(i))
		k.box(Vector3(bw, sh * 0.07, 0.003), scr + Vector3(-sw * 0.5 + 0.03 + bw * 0.5, sh * (0.25 - 0.25 * float(i)), -0.0035))
	k.color = DETAIL
	var bs := minf(0.045, ph * 0.12)
	for i in 4:
		k.box(Vector3(bs, bs, 0.016), Vector3(-pwid * 0.38 + (sw * 0.95) * float(i) / 3.0, pc.y - ph * 0.33, pf - 0.008))
	for i in 3:
		g.box(Vector3(0.03, 0.03, 0.006), Vector3(pwid * 0.3, pc.y + ph * (0.25 - 0.22 * float(i)), pf - 0.003))
	# A hazard label under the panel.
	var ly := y0 + bh * 0.535
	var lw := minf(0.3, size.x * 0.25)
	k.color = PartShapes.ACCENT
	k.box(Vector3(lw, 0.05, 0.004), Vector3(0.0, ly, front - 0.002))
	k.color = DARK
	for i in 3:
		var x := -lw * 0.3 + lw * 0.3 * float(i)
		k.strut(Vector3(x - 0.015, ly - 0.02, front - 0.005), Vector3(x + 0.015, ly + 0.02, front - 0.005), 0.012)
	# The service door on a dark seam: two hinges, a handle on standoffs, a louvre.
	var dw := pwid
	var dh := bh * 0.5 - 0.06
	var dy := y0 + 0.04 + dh * 0.5
	k.color = DARK
	k.box(Vector3(dw + 0.016, dh + 0.016, 0.004), Vector3(0.0, dy, front - 0.002))
	k.color = Color.WHITE
	_cabinets_pad(k, Vector3(0.0, dy, front - 0.004), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, dw * 0.5, dh * 0.5, 0.01, 0.005)
	var df := front - 0.014
	k.color = DETAIL
	for sy: float in [-1.0, 1.0]:
		_tube(k, Vector3(-dw * 0.5, dy + sy * dh * 0.32 - dh * 0.08, df + 0.004),
				Vector3(-dw * 0.5, dy + sy * dh * 0.32 + dh * 0.08, df + 0.004), 0.013, 6)
	var hxd := dw * 0.5 - 0.06
	k.strut(Vector3(hxd, dy - dh * 0.15, df - 0.025), Vector3(hxd, dy + dh * 0.15, df - 0.025), 0.024)
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(0.02, 0.02, 0.016), Vector3(hxd, dy + sy * dh * 0.12, df - 0.008))
	_cabinets_louvre(k, Vector3(0.0, dy - dh * 0.22, df), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, dw * 0.3, dh * 0.16, 5)
	# Each side: a louvred grille low down, a bolted service plate above it.
	for sx: float in [-1.0, 1.0]:
		var n := Vector3(sx, 0.0, 0.0)
		var side := Vector3(sx * hx, 0.0, -size.z * 0.04)
		_cabinets_louvre(k, side + Vector3(0.0, y0 + bh * 0.3, 0.0), Vector3.BACK, Vector3.UP, n, size.z * 0.3, bh * 0.16, 6)
		k.color = Color.WHITE
		var sp := side + Vector3(0.0, y0 + bh * 0.7, 0.0)
		var hu := size.z * 0.3
		var hv := bh * 0.14
		_cabinets_pad(k, sp, Vector3.BACK, Vector3.UP, n, hu, hv, 0.008, 0.004)
		k.color = TRIM
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			k.box(Vector3(0.01, 0.022, 0.022), sp + n * 0.011 + Vector3(0.0, c.y * (hv - 0.03), c.x * (hu - 0.03)))
	# The conduit up the back corner at +X, held by two clips.
	var cp := Vector3(hx - 0.004, 0.0, hz - 0.05)
	k.color = DARK
	_tube(k, cp + Vector3(0.0, y0 + 0.06, 0.0), cp + Vector3(0.0, y_cap - cap - 0.01, 0.0), 0.018, 6)
	k.color = TRIM
	for t: float in [0.25, 0.75]:
		k.box(Vector3(0.012, 0.03, 0.05), cp + Vector3(0.012, y0 + bh * t, 0.0))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size.x * size.y * size.z * 0.5
	var col := BoxShape3D.new()
	col.size = size + Vector3(0.0, 0.0, 0.04)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A raised panel on a face: a loft from the rectangle centred on `c` (`hu` x `hv` half
## sizes along `u` and `v`) out `t` along `n` to the same rectangle inset by `ch` (its
## chamfer). Doors, bezels, button caps.
static func _cabinets_pad(k: MeshKit, c: Vector3, u: Vector3, v: Vector3, n: Vector3, hu: float, hv: float,
		t: float, ch: float = 0.0) -> void:
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		a.append(c + u * s.x * hu + v * s.y * hv)
		b.append(c + n * t + u * s.x * (hu - ch) + v * s.y * (hv - ch))
	k.loft(a, b)


## A louvre on a face: a dark plate `hu` x `hv` (half sizes along `u` and `v`) on the face
## at `c` (outward `n`) with `slats` bars across it along `u` (DETAIL), standing no more
## than `th_max` + 4 mm proud.
static func _cabinets_louvre(k: MeshKit, c: Vector3, u: Vector3, v: Vector3, n: Vector3, hu: float, hv: float,
		slats: int, th_max: float = 0.016) -> void:
	k.color = DARK
	_cabinets_pad(k, c, u, v, n, hu, hv, 0.004)
	k.color = DETAIL
	var pitch := hv * 2.0 / float(slats)
	var th := minf(th_max, pitch * 0.55)
	for i in slats:
		var p := c + v * (-hv + pitch * (float(i) + 0.5)) + n * (0.004 + th * 0.5)
		k.strut(p - u * hu * 0.94, p + u * hu * 0.94, th)


## A handrail `length` along X: a round post at each end and every 1.2 m on a square base
## flange, a round top rail and mid rail, and a dark kick plate along the bottom, clear of
## the floor, clamped to each post and striped with slanted hazard bars on both faces.
## Stands on -Y.
static func railing(length: float, height: float = 1.05) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var posts := maxi(2, int(ceil(length / 1.2)) + 1)
	var top_r := 0.03     # top rail radius, m
	var post_r := 0.024   # post radius, m
	var x_end := length * 0.5 - 0.03
	var kick_y0 := -h + 0.015
	var kick_y1 := -h + 0.12
	k.color = Color.WHITE
	for i in posts:
		var x := -x_end + 2.0 * x_end * float(i) / float(posts - 1)
		_tube(k, Vector3(x, -h + 0.012, 0.0), Vector3(x, h - top_r, 0.0), post_r, 8)
		# The base flange, bolted to the deck.
		k.box(Vector3(0.08, 0.012, 0.08), Vector3(x, -h + 0.006, 0.0))
	_tube(k, Vector3(-length * 0.5, h - top_r, 0.0), Vector3(length * 0.5, h - top_r, 0.0), top_r, 8)
	_tube(k, Vector3(-x_end, h * 0.1, 0.0), Vector3(x_end, h * 0.1, 0.0), 0.02, 8)
	# Flange bolts and the kick plate's clamp on each post.
	k.color = DETAIL
	for i in posts:
		var x := -x_end + 2.0 * x_end * float(i) / float(posts - 1)
		for sx: float in [-1.0, 1.0]:
			var b := Vector3(x + sx * 0.031, -h + 0.014, 0.0)
			k.quad(b + Vector3(-0.007, 0, -0.007), b + Vector3(0.007, 0, -0.007), b + Vector3(0.007, 0, 0.007),
					b + Vector3(-0.007, 0, 0.007), Vector3.UP)
		k.box(Vector3(0.056, 0.05, 0.05), Vector3(x, (kick_y0 + kick_y1) * 0.5, 0.0))
	k.color = DARK
	var kick := Vector3(length - 0.1, kick_y1 - kick_y0, 0.03)
	k.box(kick, Vector3(0.0, (kick_y0 + kick_y1) * 0.5, 0.0))
	# Slanted hazard bars on both faces of the kick plate, between the post clamps.
	k.color = PartShapes.ACCENT
	var pitch := 0.2
	var bar := 0.06
	var slant := 0.06
	var sy0 := kick_y0 + 0.012
	var sy1 := kick_y1 - 0.012
	var span := kick.x
	var n := int(floor((span - bar - slant) / pitch))
	var x0 := -(float(n) * pitch + bar + slant) * 0.5
	for i in n + 1:
		var xa := x0 + pitch * float(i)
		var near_post := false
		for j in posts:
			var px := -x_end + 2.0 * x_end * float(j) / float(posts - 1)
			if xa + bar + slant > px - 0.04 and xa < px + 0.04:
				near_post = true
		if near_post:
			continue
		for sz: float in [-1.0, 1.0]:
			var z := sz * (kick.z * 0.5 + 0.002)
			k.quad(Vector3(xa, sy0, z), Vector3(xa + bar, sy0, z), Vector3(xa + bar + slant, sy1, z),
					Vector3(xa + slant, sy1, z), Vector3(0.0, 0.0, sz))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * height * 0.07 * 0.3
	var col := BoxShape3D.new()
	col.size = Vector3(length, height, 0.08)
	shape.collision = col
	return shape


## Open storage shelves `width` across with `shelves` levels on slotted uprights with foot
## plates, zigzag side braces and orange front beams as shelf lips, crates of a few colours
## on each. Front faces -Z; stands on -Y.
static func shelf_rack(width: float = 1.6, height: float = 2.0, depth: float = 0.6,
		shelves: int = 3) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var post := 0.05
	var foot := 0.015
	var px := (width - post) * 0.5
	var pz := (depth - post) * 0.5
	k.color = Color.WHITE
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(post, height - foot, post), Vector3(sx * px, foot * 0.5, sz * pz))
	# Foot plates, and a row of slots up the face of each front upright.
	k.color = DARK
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.07, foot, 0.07), Vector3(sx * px, -h + foot * 0.5, sz * pz))
		var holes := maxi(2, int((height - 0.25) / 0.2))
		for i in holes:
			var y := -h + 0.15 + (height - 0.25) * float(i) / float(holes - 1)
			var c := Vector3(sx * px, y, -depth * 0.5 - 0.002)
			k.quad(c + Vector3(-0.009, -0.015, 0), c + Vector3(0.009, -0.015, 0), c + Vector3(0.009, 0.015, 0),
					c + Vector3(-0.009, 0.015, 0), Vector3.FORWARD)
	var crates: Array[Color] = [Color(0.9, 0.7, 0.2), Color(0.3, 0.75, 0.8), Color(0.55, 0.3, 0.7), Color(0.85, 0.3, 0.25)]
	var y0 := -h + 0.06
	var pitch := (height - 0.11) / float(shelves)
	var beam := Vector3(width - post * 2.0 - 0.01, 0.07, 0.025)
	var n := 0
	for s in shelves:
		var y := y0 + pitch * float(s)
		# The deck, an orange beam along its front standing proud of it as a lip.
		k.color = DETAIL
		k.box(Vector3(width - post * 2.0 - 0.01, 0.04, depth - 0.02), Vector3(0.0, y + 0.02, 0.0))
		k.color = PartShapes.ACCENT
		k.box(beam, Vector3(0.0, y + 0.03, -depth * 0.5 + 0.003 + beam.z * 0.5))
		# Side braces: a diagonal from the front of this level to the back of the next.
		k.color = DETAIL
		var y_next := minf(y + pitch, h - 0.05)
		for sx: float in [-1.0, 1.0]:
			var x := sx * px
			var dz := -1.0 if s % 2 == 0 else 1.0
			k.strut(Vector3(x, y + 0.04, dz * (pz - post * 0.5)), Vector3(x, y_next, -dz * (pz - post * 0.5)), 0.022)
		var slots := maxi(2, int(width / 0.5))
		var cw := (width - post * 2.0 - 0.1) / float(slots)
		for i in slots:
			if (n * 7 + i * 3) % 5 == 0:
				n += 1
				continue
			var cx := -width * 0.5 + post + 0.05 + cw * (float(i) + 0.5)
			var ch := minf(pitch * 0.62, cw * 0.9)
			k.color = crates[n % crates.size()]
			k.box(Vector3(cw * 0.84, ch, depth * 0.72), Vector3(cx, y + 0.04 + ch * 0.5, -0.02))
			# A grip slot in the crate's front.
			k.color = DARK
			var g := Vector3(cx, y + 0.04 + ch * 0.75, -0.02 - depth * 0.36 - 0.002)
			k.quad(g + Vector3(-cw * 0.15, -0.02, 0), g + Vector3(cw * 0.15, -0.02, 0), g + Vector3(cw * 0.15, 0.02, 0),
					g + Vector3(-cw * 0.15, 0.02, 0), Vector3.FORWARD)
			n += 1
	# A top beam front and back ties the uprights together.
	k.color = PartShapes.ACCENT
	for sz: float in [-1.0, 1.0]:
		k.box(beam, Vector3(0.0, h - 0.05, sz * (depth * 0.5 - 0.003 - beam.z * 0.5)))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * depth * 0.3
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth)
	shape.collision = col
	return shape


## A ladder `height` tall: two rails `width` apart with a rung every 0.3 m, standing on -Y,
## rungs toward -Z (put its back against a wall or a hatch edge). Rails and rungs are
## galvanised; each rung has a ribbed rubber grip strip on its tread and shows its riveted
## ends on the rails' outer faces; the rails stand on rubber feet and are held off the wall
## by dark satin stand-off brackets (+Z).
static func ladder(height: float, width: float = 0.5) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var rx := (width - 0.06) * 0.5
	k.color = GALVANISED
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.06, height - 0.03, 0.06), Vector3(sx * rx, 0.015, 0.0))
	# Rubber feet.
	k.color = RUBBER
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.07, 0.03, 0.07), Vector3(sx * rx, -h + 0.015, 0.0))
	# Stand-off brackets behind the rails: top, bottom and about every 1.2 m.
	k.color = WALK_FRAME
	var levels := maxi(2, int(ceil((height - 0.4) / 1.2)) + 1)
	for j in levels:
		var y := -h + 0.2 + (height - 0.4) * float(j) / float(levels - 1)
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(0.1, 0.05, 0.015), Vector3(sx * rx, y, 0.0375))
	var rungs := maxi(2, int(height / 0.3))
	var tread := width - 0.14
	for i in rungs:
		var y := -h + 0.15 + (height - 0.3) * float(i) / float(rungs - 1)
		k.color = WALK_CROSS_BAR
		k.box(Vector3(width - 0.06, 0.035, 0.035), Vector3(0.0, y, -0.012))
		# The grip strip on the rung's tread.
		k.color = TREAD
		k.box(Vector3(tread, 0.006, 0.027), Vector3(0.0, y + 0.0195, -0.012))
		# Rivet heads where the rung goes through each rail.
		k.color = DETAIL
		for sx: float in [-1.0, 1.0]:
			var c := Vector3(sx * (width * 0.5 + 0.002), y, -0.012)
			k.quad(c + Vector3(0, -0.012, -0.012), c + Vector3(0, 0.012, -0.012), c + Vector3(0, 0.012, 0.012),
					c + Vector3(0, -0.012, 0.012), Vector3(sx, 0.0, 0.0))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * 0.06 * 0.25
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, 0.08)
	shape.collision = col
	return shape



## A flight of stairs `width` across (X) climbing `rise` over `run` toward -Z: the bottom
## step is at the +Z end, the top lands at the -Z end. A sloped stringer each side, a tread
## for every step (about `step` tall) and a riser under each nose. Centred on its origin,
## so its base is at -rise/2 (stand it on the lower floor and its top tread is `rise` up)
## and its top edge is at z = -run/2. Collision is the band through the tread noses, so a
## player walks up it as a ramp. Each tread has dark grip grooves, a yellow nosing along
## its front (+Z) edge with a short lit strip in it (glow, `glow` colour), and is bolted
## to the stringers; the stringers stand on dark foot plates.
static func stair(width: float, rise: float, run: float, step: float = 0.2,
		glow := Color(1.0, 0.78, 0.4)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var n := maxi(2, int(round(rise / step)))
	var r := rise / float(n)      # one riser, m
	var td := run / float(n)      # one tread, m
	var hx := width * 0.5
	var hy := rise * 0.5
	var hz := run * 0.5
	var side := 0.08
	# The stringer outline (z, y): the band under the line through the tread noses, one
	# riser deep, from the foot of the flight to the top landing edge.
	var band := PackedVector2Array([Vector2(hz, -hy), Vector2(hz, -hy + r), Vector2(-hz + td, hy), Vector2(-hz, hy)])
	k.color = Color.WHITE
	_prism_x(k, band, -hx, -hx + side)
	_prism_x(k, band, hx - side, hx)
	var inner := width - 2.0 * side - 0.02
	# Dark foot plates under the stringers at the bottom of the flight.
	k.color = DARK
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(side + 0.02, 0.012, 0.16), Vector3(sx * (hx - side * 0.5), -hy + 0.006, hz - 0.08 - 0.004))
	var nose_d := minf(0.04, td * 0.3)   # nosing depth, m
	var lit := inner * 0.6
	var d := MeshKit.new()   # surface decals (open faces): grooves and bolt heads
	for i in n:
		var nose_y := -hy + r * float(i + 1)
		var nose_z := hz - td * float(i)
		k.color = DETAIL
		k.box(Vector3(inner, 0.05, td - 0.01), Vector3(0.0, nose_y - 0.025, nose_z - td * 0.5))
		k.color = DARK
		var riser_h := r - 0.05
		k.box(Vector3(inner, riser_h, 0.03), Vector3(0.0, nose_y - 0.05 - riser_h * 0.5, nose_z - 0.03))
		# Grip grooves across the tread behind the nosing.
		d.color = DARK
		var gz0 := nose_z - nose_d - 0.01
		var gz1 := nose_z - td + 0.02
		for j in 3:
			var gz := lerpf(gz0, gz1, (float(j) + 0.5) / 3.0)
			var gy := nose_y + 0.002
			d.quad(Vector3(-inner * 0.45, gy, gz - 0.008), Vector3(inner * 0.45, gy, gz - 0.008),
					Vector3(inner * 0.45, gy, gz + 0.008), Vector3(-inner * 0.45, gy, gz + 0.008), Vector3.UP)
		# The nosing, standing a little proud of the tread, its lit strip in the front face.
		k.color = PartShapes.ACCENT
		var nz := nose_z - 0.002 - nose_d * 0.5
		k.box(Vector3(inner - 0.006, 0.055, nose_d), Vector3(0.0, nose_y - 0.0235, nz))
		var fz := nz + nose_d * 0.5 + 0.002
		g.quad(Vector3(-lit * 0.5, nose_y - 0.03, fz), Vector3(lit * 0.5, nose_y - 0.03, fz),
				Vector3(lit * 0.5, nose_y - 0.018, fz), Vector3(-lit * 0.5, nose_y - 0.018, fz), Vector3.BACK)
		# Bolts through each stringer into the tread's end.
		d.color = DETAIL
		for sx: float in [-1.0, 1.0]:
			var c := Vector3(sx * (hx + 0.002), nose_y - 0.025, nose_z - td * 0.5)
			for dz: float in [-td * 0.25, td * 0.25]:
				d.quad(c + Vector3(0, -0.012, dz - 0.012), c + Vector3(0, 0.012, dz - 0.012), c + Vector3(0, 0.012, dz + 0.012),
						c + Vector3(0, -0.012, dz + 0.012), Vector3(sx, 0.0, 0.0))
	var vol := k.volume()
	k.verts.append_array(d.verts)
	k.normals.append_array(d.normals)
	k.colors.append_array(d.colors)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = vol
	shape.glow = g.finish()
	shape.glow_color = glow
	var pts := PackedVector3Array()
	for p in band:
		pts.append(Vector3(-hx, p.y, p.x))
		pts.append(Vector3(hx, p.y, p.x))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	return shape


# --- Helpers ---------------------------------------------------------------------------

static func _cylinder(k: MeshKit, radius: float, length: float) -> PartShapes.PartShape:
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * radius * radius * length * 0.5
	var col := CylinderShape3D.new()
	col.radius = radius
	col.height = length
	shape.collision = col
	return shape



## A convex outline given as (z, y) points, extruded along X from x0 to x1: two caps and
## a quad per edge, every face outward.
static func _prism_x(k: MeshKit, outline_zy: PackedVector2Array, x0: float, x1: float) -> void:
	var n := outline_zy.size()
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	var centre := Vector3.ZERO
	for p in outline_zy:
		a.append(Vector3(x0, p.y, p.x))
		b.append(Vector3(x1, p.y, p.x))
		centre += Vector3((x0 + x1) * 0.5, p.y, p.x) / float(n)
	k.poly(a, Vector3.LEFT)
	k.poly(b, Vector3.RIGHT)
	for i in n:
		var j := (i + 1) % n
		var mid := (a[i] + a[j] + b[i] + b[j]) * 0.25
		var out := mid - centre
		out.x = 0.0
		k.quad(a[i], a[j], b[j], b[i], out)


static func _cone_collision(k: MeshKit, radius: float, length: float) -> PartShapes.PartShape:
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * radius * radius * length * 0.5
	var pts := PackedVector3Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector3(cos(a) * radius, -length * 0.5, sin(a) * radius))
		pts.append(Vector3(cos(a) * radius, -length * 0.5 + length * 0.45, sin(a) * radius))
	pts.append(Vector3(0, length * 0.5, 0))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	return shape


## Every fitted part in a couple of sizes: [name, PartShape] (for the parts gallery).
static func catalogue() -> Array:
	return [
		["mesh panel 1.2x2.4", mesh_panel(1.2, 2.4)],
		["ducted fan 0.8", ducted_fan(0.8, 0.7)],
		["ducted fan 1.4", ducted_fan(1.4, 1.0, 9)],
		["tank 0.6x3", tank(0.6, 3.0)],
		["tank 1.0x5", tank(1.0, 5.0)],
		["drill head", drill_head(0.9, 2.2)],
		["thruster grid 4x4", thruster_grid(4, 4, 0.35, 0.5)],
		["thruster grid 3x2", thruster_grid(3, 2, 0.4, 0.5)],
		["solar panel 2x4", solar_panel(2.0, 4.0)],
		["landing leg 1.6", landing_leg(1.6)],
		["engine bell 1.0", engine_bell(1.0, 2.2)],
		["engine bell 2.0", engine_bell(2.0, 3.6)],
		["fin 3x1.5", fin(3.0, 1.5, 1.2, 1.4)],
		["container 2.5", container(Vector3(2.4, 2.4, 2.4))],
		["container long", container(Vector3(2.4, 2.4, 6.0))],
		["antenna", antenna(2.0, 0.5)],
		["turret", turret(0.7, 2.0)],
		["console", console(1.2)],
		["console wide amber", console(2.4, 1.0, 0.7, Color(1.0, 0.62, 0.25))],
		["seat", seat()],
		["bunk", bunk()],
		["table", table()],
		["locker", locker()],
		["ion thruster 0.7", ion_thruster(0.7, 0.5)],
		["ion thruster 2.6", ion_thruster(2.6, 1.4)],
		["headlamp bar", headlamp_bar(2.0, 4)],
		["pipe 0.12x3", pipe(0.12, 3.0)],
		["pipe elbow", pipe_elbow(0.12)],
		["grating 2x3", grating(2.0, 3.0)],
		["generator", generator(Vector3(1.2, 1.3, 2.2))],
		["switch cabinet", switch_cabinet()],
		["battery rack", battery_rack()],
		["bench", bench()],
		["bar counter", bar_counter()],
		["stool", stool()],
		["toilet", toilet()],
		["basin", basin()],
		["portal jamb", portal_jamb()],
		["portal lintel", portal_lintel()],
		["container striped", container(Vector3(2.4, 2.4, 4.0), Color(0.55, 0.8, 0.2))],
		["pipe tee", pipe_tee(0.12)],
		["loom bend", loom_bend(WiringLoom.main_power())],
		["junction box", junction_box()],
		["armchair", armchair()],
		["hatch door", hatch_door()],
		["docking port", docking_port()],
		["thruster pod", thruster_pod(3.0, 1.8, 2.0)],
		["light strip", light_strip(2.0)],
		["reactor", reactor(0.9, 3.0)],
		["machine unit", machine_unit(Vector3(1.4, 2.4, 1.2))],
		["railing 2", railing(2.0)],
		["shelf rack", shelf_rack()],
		["ladder 3", ladder(3.0)],
		["stair 2.8", stair(1.0, 2.8, 3.8)],
		["crash seat", crash_seat()],
		["grab bar", grab_bar()],
		["grab frame", grab_bar(1.7, 0.3)],
		["landing clamp", landing_clamp()],
		["survival locker", survival_locker()],
		["cargo crate", cargo_crate()],
		["cargo ramp", cargo_ramp()],
		["shower", shower()],
		["bed alcove", bed_alcove()],
		["survival kit", survival_kit()],
		["container hatch", container_hatch()],
		["grinder head", grinder_head()],
		["lattice rail 4", lattice_rail(4.0, 0.9)],
		["canister pack", canister_pack()],
		["heat sink", heat_sink()],
		["nozzle cluster", nozzle_cluster()],
		["conveyor tube 2", conveyor_tube(2.0)],
		["conveyor junction", conveyor_junction()],
		["gyroscope", gyroscope()],
		["button panel", button_panel()],
		["double bed", double_bed()],
		["media wall", media_wall()],
		["galley counter", galley_counter()],
		["med bed", med_bed()],
		["hover drum", hover_drum()],
		["seat row 3", seat_row(3)],
		["lit post", lit_post(2.6)],
		["bore drill", bore_drill()],
		["ore hatch", ore_hatch()],
		["cup thruster", cup_thruster()],
		["ore bin", ore_bin()],
		["gatling gun", gatling_gun()],
		["octagon thruster", octagon_thruster()],
		["stud lights 5", stud_lights(5)],
		["stick seat", stick_seat()],
		["grille drum", grille_drum()],
		["roof hatch", roof_hatch()],
		["twin turret", twin_turret()],
		["dome turret", dome_turret()],
		["spinal gun", spinal_gun()],
		["mess table", mess_table()],
		["gravity generator", gravity_generator()],
		["hydrogen engine", hydrogen_engine()],
		["workbench", workbench()],
		["talon intake", talon_intake()],
		["oval engine", oval_engine()],
		["spoiler wing", spoiler_wing()],
		["bomb rack 2x2", bomb_rack()],
		["bomb rack 1x3", bomb_rack(1, 3, 0.16, 1.3)],
		["ribbed spine", ribbed_spine()],
		["cannon maw", cannon_maw()],
		["cell cage", cell_cage()],
		["cutter drum", cutter_drum()],
		["lift car", lift_car()],
		["detector head", detector_head()],
		["med station", med_station()],
		["rail turret", rail_turret()],
		["planter", planter()],
		["hazard band", hazard_band()],
		["turbine engine", turbine_engine()],
		["roof hood", roof_hood()],
		["lever stand", lever_stand()],
		["pod boom", pod_boom(6.0)],
		["armour cowl", armour_cowl()],
		["octo tank", octo_tank()],
		["spike drill", spike_drill()],
		["connector ring", connector_ring()],
		["ship welder", ship_welder()],
		["name board", name_board()],
		["louvre panel", louvre_panel()],
		["searchlight", searchlight()],
		["long cannon", long_cannon()],
		["name board digits", name_board("RX-39487", 4.0, 0.9)],
		["banded tank", banded_tank()],
		["nose probe", nose_probe()],
		["rock wheel", rock_wheel()],
		["drill arm", drill_arm()],
		["ore detector", ore_detector()],
		["piston gear", piston_gear()],
		["lift platform", lift_platform()],
		["bunk rack", bunk_rack()],
		["refill station", refill_station()],
		["reactor core", reactor_core()],
		["name board CMS-01A", name_board("CMS-01A", 4.0, 1.0)],
		["landing pad", landing_pad()],
		["name board PORPOISE", name_board("PORPOISE", 4.0, 1.0)],
		["fin blade", fin_blade()],
		["spoke beam", spoke_beam()],
		["sleep pod", sleep_pod()],
		["shingle panel", shingle_panel()],
		["shingle panel trim", shingle_panel(2.4, 3.0, 4, 3, Color(0.15, 0.4, 0.9))],
		["corner sofa", corner_sofa()],
		["name board NOVARIS", name_board("NOVARIS", 4.0, 1.0)],
		["garage door", garage_door()],
		["racer hull", racer_hull()],
		["name board DARKSPOT", name_board("DARKSPOT", 4.0, 1.0)],
		["rail barrel", rail_barrel()],
		["rail muzzle", rail_muzzle()],
		["capacitor bank", capacitor_bank()],
		["naval turret", naval_turret()],
		["missile launcher", missile_launcher()],
		["radiator grille", radiator_grille()],
		["armour slab", armour_slab()],
		["name board DEVASTATOR", name_board("DEVASTATOR", 5.0, 1.0)],
		["missile silo", missile_silo()],
		["rover", rover()],
		["name board EVEREST", name_board("EVEREST", 4.0, 1.0)],
		["copper vent", copper_vent()],
		["case stack", case_stack()],
		["name board SENTINAL", name_board("SENTINAL", 4.4, 1.0)],
	]


# --- Escape pod parts (0.31) ------------------------------------------------------------

## A crash seat (the escape pod's red jump seats) `width` across, `height` tall: a bolted
## base plate under a dark wedge pedestal, a seat pan, a tall backrest with chamfered dark
## pads and side bolsters, a pointed headrest with a pad between two head wings, and a
## harness (shoulder straps and a crotch strap meeting at a buckle). Stands on -Y, faces
## -Z (the backrest is at +Z). The body takes the material colour; pedestal and pads are
## dark, straps pale.
static func crash_seat(width: float = 0.65, height: float = 1.9, depth: float = 0.6) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var w := width * 0.5
	var d := depth * 0.5
	var seat_y := -h + 0.45
	var back_t := 0.12
	var plate := 0.03                         # base plate thickness, m
	# Base plate with a bolt in each corner, the wedge pedestal on it.
	var pz := (d - back_t + 0.02 + (-d + 0.18)) * 0.5
	var phz := (d - back_t + 0.02 - (-d + 0.18)) * 0.5
	k.color = Color.WHITE
	_seating_pad(k, Vector3(0.0, -h, pz), Vector3.RIGHT, Vector3.BACK, Vector3.UP, w * 0.8, phz, plate, 0.012)
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.03, 0.012, 0.03), Vector3(sx * (w * 0.8 - 0.035), -h + plate + 0.006, pz + sz * (phz - 0.035)))
	k.color = DARK
	_prism_x(k, PackedVector2Array([Vector2(d - back_t, -h + plate), Vector2(d - back_t, seat_y - 0.06),
			Vector2(-d + 0.06, seat_y - 0.06), Vector2(-d + 0.22, -h + plate)]), -w * 0.7, w * 0.7)
	k.color = Color.WHITE
	k.box(Vector3(width, 0.1, depth - back_t), Vector3(0.0, seat_y - 0.01, -back_t * 0.5))
	var back_lo := seat_y - 0.06
	var back_hi := h - 0.22
	k.box(Vector3(width, back_hi - back_lo, back_t), Vector3(0.0, (back_lo + back_hi) * 0.5, d - back_t * 0.5))
	# The pointed headrest over the backrest.
	var za := d - back_t
	var outline := [Vector2(-w, back_hi), Vector2(w, back_hi), Vector2(w, h - 0.1), Vector2(0.0, h), Vector2(-w, h - 0.1)]
	var ra := PackedVector3Array()
	var rb := PackedVector3Array()
	for p: Vector2 in outline:
		ra.append(Vector3(p.x, p.y, za))
		rb.append(Vector3(p.x, p.y, d))
	k.loft(ra, rb)
	# Head wings either side of the headrest pad.
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.06, 0.16, 0.08), Vector3(sx * (w - 0.03), back_hi + 0.12, za - 0.04))
	# Dark chamfered pads on the backrest, seat and headrest, bolsters either side.
	k.color = DARK
	var pad_h := (back_hi - back_lo) * 0.7
	var bc := Vector3(0.0, back_lo + 0.12 + pad_h * 0.5, za)
	_seating_pad(k, bc, Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, width * 0.3, pad_h * 0.5, 0.045, 0.015)
	_seating_pad(k, Vector3(0.0, seat_y + 0.04, -back_t * 0.5 - 0.02), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			width * 0.32, (depth - back_t) * 0.38, 0.045, 0.015)
	_seating_pad(k, Vector3(0.0, back_hi + 0.12, za), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
			w - 0.08, 0.075, 0.04, 0.015)
	for sx: float in [-1.0, 1.0]:
		_seating_pad(k, Vector3(sx * (w - 0.04), back_lo + 0.5 + pad_h * 0.3, za), Vector3.RIGHT, Vector3.UP,
				Vector3.FORWARD, 0.035, pad_h * 0.3, 0.09, 0.012)
	k.box(Vector3(width * 0.56, pad_h * 0.6, 0.004), Vector3(0.0, bc.y, d + 0.002))
	# The harness: shoulder straps and a crotch strap meeting at the buckle.
	k.color = DETAIL
	var buckle := Vector3(0.0, seat_y + 0.12, -d * 0.35)
	for sx: float in [-1.0, 1.0]:
		k.strut(Vector3(sx * w * 0.32, back_hi - 0.08, za - 0.03), buckle + Vector3(sx * 0.04, 0.0, 0.0), 0.035)
	k.strut(buckle, Vector3(0.0, seat_y + 0.075, -d + 0.04), 0.035)
	k.color = PartShapes.ACCENT
	k.box(Vector3(0.1, 0.08, 0.035), buckle)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * (height * back_t + depth * 0.1) + 0.04
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth)
	shape.collision = col
	return shape


## A C-shaped grab handle `height` tall along Y: a round stainless bar
## `reach` - 0.05 m off the wall, its ends bent through 45 degree knuckles into two
## standoffs, a rubber grip sleeve with polished ferrules round its middle, and at each
## standoff a polished collar on a chamfered cast mounting plate with two bolts. The wall side
## is +Z, the bar toward -Z.
static func grab_bar(height: float = 0.9, reach: float = 0.16) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var r := 0.024
	var bz := -reach * 0.5 + r
	var zw := reach * 0.5                       # the wall face, m
	var plate_t := 0.018                        # mounting plate thickness, m
	var bend := minf(0.035, (zw - plate_t - 0.02 - bz) * 0.5)   # knuckle offset, m
	var ys := h - 0.05                          # standoff height either side of the middle, m
	k.color = STAINLESS
	_tube(k, Vector3(0.0, -ys + bend, bz), Vector3(0.0, ys - bend, bz), r)
	for sy: float in [-1.0, 1.0]:
		var y := sy * ys
		var knee := Vector3(0.0, y, bz + bend)
		k.color = STAINLESS
		_tube(k, Vector3(0.0, y - sy * bend, bz), knee, r)
		_tube(k, knee, Vector3(0.0, y, zw - plate_t - 0.012), r)
		# The collar, the plate and its two bolts.
		k.color = TRIM
		_tube(k, Vector3(0.0, y, zw - plate_t - 0.014), Vector3(0.0, y, zw - plate_t + 0.002), r + 0.008, 8)
		k.color = CAST
		_seating_pad(k, Vector3(0.0, y, zw), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, 0.045, 0.06, plate_t, 0.006)
		k.color = DETAIL
		for by: float in [-0.042, 0.042]:
			k.box(Vector3(0.016, 0.016, 0.008), Vector3(0.0, y + by, zw - plate_t - 0.002))
	# The grip: a dark sleeve over the middle with a steel ferrule at each end.
	var grip := clampf(ys - bend - 0.12, 0.08, 0.3)   # half the grip's length, m
	k.color = RUBBER
	_tube(k, Vector3(0.0, -grip, bz), Vector3(0.0, grip, bz), r + 0.004)
	k.color = TRIM
	for sy: float in [-1.0, 1.0]:
		_tube(k, Vector3(0.0, sy * grip - 0.008, bz), Vector3(0.0, sy * grip + 0.008, bz), r + 0.007, 8)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * r * r * (height + reach * 2.0)
	var col := BoxShape3D.new()
	col.size = Vector3(0.1, height, reach)
	shape.collision = col
	return shape


## An SE2-style landing gear `size` square, `depth` deep along Y (mount face -Y, pad face
## +Y): a chamfered base on a bolted flange, two hinge lugs carrying a steel pin through a
## hinge block, two hydraulic rams (dark barrels, bright rods) either side of it, and a
## bevelled yellow magnetic pad with a slanted dark hazard border and corner bolts on its
## face. Two status lamps in a dark bezel on the base's -Z face are the glow.
static func landing_clamp(size: float = 0.9, depth: float = 0.45, glow := Color(0.3, 1.0, 0.45)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var s := size
	var h := depth * 0.5
	var fl := depth * 0.09                     # mount flange, m
	var yb := -h + depth * 0.32                # base top, m
	var yp := -h + depth * 0.66                # pad underside, m
	var gap := yp - yb
	var hb := s * 0.43                         # base half width, m
	# Base: a chamfered flange, a chamfered body on it, eight bolts round the flange.
	k.color = DETAIL
	k.loft(_chamfer_ring(s * 0.5, -h, s * 0.07), _chamfer_ring(s * 0.5, -h + fl, s * 0.07))
	k.color = Color.WHITE
	k.loft(_chamfer_ring(hb, -h + fl, s * 0.06), _chamfer_ring(hb, yb, s * 0.06))
	k.color = DETAIL
	var br := clampf(s * 0.018, 0.009, 0.02)
	for sa: float in [-1.0, 1.0]:
		for sb: float in [-1.0, 1.0]:
			_thrusters_bolt(k, Vector3(sa * s * 0.465, -h + fl, sb * s * 0.22), br, br * 0.7)
			_thrusters_bolt(k, Vector3(sb * s * 0.22, -h + fl, sa * s * 0.465), br, br * 0.7)
	# Hinge: two lugs, a block under the pad, a pin through all three.
	var lug_t := s * 0.07
	var y_pin := yb + gap * 0.55
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(lug_t, gap * 0.8, s * 0.3), Vector3(sx * s * 0.3, yb + gap * 0.4, 0.0))
	k.color = DARK
	k.box(Vector3(s * 0.46, gap * 0.62, s * 0.2), Vector3(0.0, yp - gap * 0.31, 0.0))
	k.color = TRIM
	_tube(k, Vector3(-s * 0.35, y_pin, 0.0), Vector3(s * 0.35, y_pin, 0.0), s * 0.035, 8)
	# Two hydraulic rams fore and aft of the hinge: barrel, gland collar, rod, end eyes.
	var rr := s * 0.045
	for sz: float in [-1.0, 1.0]:
		var a := Vector3(0.0, yb, sz * s * 0.33)
		var b := Vector3(0.0, yp, sz * s * 0.27)
		var m := a.lerp(b, 0.55)
		k.color = DETAIL
		k.box(Vector3(rr * 2.4, gap * 0.12, rr * 2.4), a + Vector3(0.0, gap * 0.06, 0.0))
		k.box(Vector3(rr * 2.0, gap * 0.1, rr * 2.0), b - Vector3(0.0, gap * 0.05, 0.0))
		k.color = DARK
		_tube(k, a, m, rr, 8)
		k.color = DETAIL
		_tube(k, m - (b - a) * 0.04, m + (b - a) * 0.06, rr * 1.2, 8)
		k.color = TRIM
		_tube(k, m, b, rr * 0.55, 8)
	# The pad: a bevelled yellow block.
	var hp := s * 0.46
	var bev := clampf(depth * 0.03, 0.006, 0.015)
	var cp := s * 0.05
	k.color = PartShapes.ACCENT
	k.loft(_chamfer_ring(hp, yp, cp), _chamfer_ring(hp, h - bev, cp), false)
	k.poly(_chamfer_ring(hp, yp, cp), Vector3.DOWN)
	k.loft(_chamfer_ring(hp, h - bev, cp), _chamfer_ring(hp - bev, h, cp), false)
	k.poly(_chamfer_ring(hp - bev, h, cp), Vector3.UP)
	# The hazard border: slanted dark bars round the face, and a bolt in each corner.
	k.color = DARK
	var bw := s * 0.075                        # border width, m
	var edge := hp - bev - s * 0.012           # border's outer edge, m
	var mid := edge - bw * 0.5
	var run := 2.0 * (edge - bw)               # each side's bars run between the corners, m
	var bars := clampi(int(run / (s * 0.11)), 3, 9)
	var pitch := run / float(bars)
	for side in 4:
		var u := Vector3.RIGHT if side < 2 else Vector3.BACK
		var n := (Vector3.BACK if side < 2 else Vector3.RIGHT) * (1.0 if side % 2 == 0 else -1.0)
		for i in bars:
			var c := u * (-run * 0.5 + pitch * (float(i) + 0.5)) + n * mid
			var lean := u * pitch * 0.22
			var hw := u * pitch * 0.25
			var nn := n * bw * 0.5
			var flat := [c - hw - nn - lean, c + hw - nn - lean, c + hw + nn + lean, c - hw + nn + lean]
			var bot := PackedVector3Array()
			var tp := PackedVector3Array()
			for p: Vector3 in flat:
				bot.append(p + Vector3(0.0, h - 0.002, 0.0))
				tp.append(p + Vector3(0.0, h + 0.008, 0.0))
			k.loft(bot, tp)
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(bw, 0.008, bw), Vector3(sx * mid, h + 0.002, sz * mid))
			_thrusters_bolt(k, Vector3(sx * mid, h + 0.006, sz * mid), bw * 0.28, 0.006)
	# Lamp bezel on the base's front.
	var led := clampf(s * 0.05, 0.025, 0.05)
	var ly := (-h + fl + yb) * 0.5
	k.color = DARK
	k.box(Vector3(led * 3.4, led * 1.6, 0.008), Vector3(s * 0.2, ly, -hb - 0.004))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size * size * depth * 0.6
	var col := BoxShape3D.new()
	col.size = Vector3(size, depth + 0.03, size)
	shape.collision = col
	var g := MeshKit.new()
	for sx: float in [-1.0, 1.0]:
		g.box(Vector3(led, led, 0.006), Vector3(s * 0.2 + sx * led * 0.8, ly, -hb - 0.01))
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A white emergency locker `width` x `height` x `depth` on a recessed dark plinth under a
## lipped cap: a hinged upper door with a red cross, a lock and a status lamp (`glow`, lit),
## two lower doors on dark seams with hinges on their outer edges, handles by the middle,
## name plates and louvres, a yellow and dark hazard band along the foot and vent slots
## down the sides. Front -Z.
static func survival_locker(width: float = 0.8, height: float = 1.9, depth: float = 0.45,
		glow := Color(0.3, 1.0, 0.45)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var hw := width * 0.5
	var fz := -depth * 0.5
	var plinth := 0.08
	var cap := 0.03
	# Plinth, body, the lip on top.
	k.color = DARK
	k.box(Vector3(width - 0.04, plinth, depth - 0.04), Vector3(0.0, -h + plinth * 0.5, 0.02))
	k.color = Color.WHITE
	var yb := -h + plinth
	var yt := h - cap
	k.box(Vector3(width, yt - yb, depth), Vector3(0.0, (yb + yt) * 0.5, 0.0))
	k.color = DETAIL
	k.box(Vector3(width + 0.02, cap, depth + 0.01), Vector3(0.0, h - cap * 0.5, -0.005))
	# The hazard band along the foot: yellow with dark diagonal stripes.
	var band_y := yb + 0.06
	k.color = PartShapes.ACCENT
	k.box(Vector3(width - 0.02, 0.1, 0.008), Vector3(0.0, band_y, fz - 0.004))
	k.color = DARK
	for i in 5:
		var x := -width * 0.36 + width * 0.18 * float(i)
		k.strut(Vector3(x - 0.035, band_y - 0.04, fz - 0.009), Vector3(x + 0.035, band_y + 0.04, fz - 0.009), 0.024)
	# The doors on one dark seam: an upper door over two lower ones.
	var d_lo := yb + 0.13
	var d_hi := yt - 0.02
	var split := d_lo + (d_hi - d_lo) * 0.42
	var dw := width - 0.06
	k.color = DARK
	k.box(Vector3(dw + 0.016, d_hi - d_lo + 0.016, 0.004), Vector3(0.0, (d_lo + d_hi) * 0.5, fz - 0.002))
	k.color = Color.WHITE
	var uh := d_hi - split - 0.006
	var uy := split + 0.006 + uh * 0.5
	_cabinets_pad(k, Vector3(0.0, uy, fz - 0.004), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, dw * 0.5, uh * 0.5, 0.012, 0.006)
	var lw := dw * 0.5 - 0.006
	var lh := split - 0.006 - d_lo
	var ly := d_lo + lh * 0.5
	for sx: float in [-1.0, 1.0]:
		_cabinets_pad(k, Vector3(sx * (lw * 0.5 + 0.006), ly, fz - 0.004), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
				lw * 0.5, lh * 0.5, 0.012, 0.006)
	var df := fz - 0.016
	# Hinges: the upper door's on its left edge, the lower doors' on their outer edges.
	k.color = DETAIL
	for sy: float in [-1.0, 1.0]:
		var y := uy + sy * uh * 0.34
		_tube(k, Vector3(-dw * 0.5, y - 0.05, df + 0.005), Vector3(-dw * 0.5, y + 0.05, df + 0.005), 0.012, 6)
		for sx: float in [-1.0, 1.0]:
			var yl := ly + sy * lh * 0.32
			_tube(k, Vector3(sx * dw * 0.5, yl - 0.05, df + 0.005), Vector3(sx * dw * 0.5, yl + 0.05, df + 0.005), 0.012, 6)
	# Handles by the middle on standoffs, name plates and louvres on the lower doors.
	for sx: float in [-1.0, 1.0]:
		var x := sx * 0.06
		k.color = DETAIL
		k.strut(Vector3(x, ly + lh * 0.12, df - 0.022), Vector3(x, ly + lh * 0.38, df - 0.022), 0.022)
		for t: float in [0.16, 0.34]:
			k.box(Vector3(0.018, 0.018, 0.016), Vector3(x, ly + lh * t, df - 0.008))
		var cx := sx * (lw * 0.5 + 0.006)
		k.color = PLATE
		k.box(Vector3(lw * 0.5, 0.045, 0.004), Vector3(cx + sx * lw * 0.08, ly - lh * 0.02, df - 0.002))
		_cabinets_louvre(k, Vector3(cx, ly - lh * 0.3, df), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, lw * 0.32, lh * 0.1, 4)
	# The upper door: the red cross, a lock box with its keyhole, the lamp in a dark bezel.
	k.color = CROSS_RED
	var c := Vector3(0.0, uy + uh * 0.06, df - 0.004)
	var arm := minf(width * 0.36, uh * 0.55)
	k.box(Vector3(arm, arm * 0.3, 0.008), c)
	k.box(Vector3(arm * 0.3, arm, 0.008), c + Vector3(0.0, 0.0, -0.0005))
	k.color = DETAIL
	var lock := Vector3(dw * 0.5 - 0.07, uy - uh * 0.32, df - 0.01)
	k.box(Vector3(0.05, 0.08, 0.02), lock)
	k.color = DARK
	k.box(Vector3(0.012, 0.03, 0.004), lock + Vector3(0.0, 0.0, -0.011))
	var lamp := Vector3(dw * 0.5 - 0.07, uy + uh * 0.4, df - 0.004)
	k.box(Vector3(0.06, 0.04, 0.008), lamp)
	# Vent slots down both sides.
	for sx: float in [-1.0, 1.0]:
		for i in 4:
			k.box(Vector3(0.004, 0.02, depth * 0.5), Vector3(sx * (hw + 0.002), yt - 0.12 - 0.05 * float(i), 0.0))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * depth * 0.15
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth + 0.04)
	shape.collision = col
	var g := MeshKit.new()
	g.box(Vector3(0.036, 0.018, 0.004), lamp + Vector3(0.0, 0.0, -0.005))
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A round bar from `a` to `b`, `radius` thick, ten-sided, capped (grab bars, rails).
static func _tube(k: MeshKit, a: Vector3, b: Vector3, radius: float, sides: int = 10) -> void:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var ra := PackedVector3Array()
	var rb := PackedVector3Array()
	for i in sides:
		var t := TAU * float(i) / float(sides)
		var off := (x * cos(t) + z * sin(t)) * radius
		ra.append(a + off)
		rb.append(b + off)
	k.loft(ra, rb)


# --- Lander parts (0.32) ----------------------------------------------------------------

## An SE2-style small cargo container (the lander's hold) `size` across: a box in the
## material colour with corner castings, edge rails and pressed ribs, a yellow-framed dark
## hatch panel with hinges, a lever and a grille on its front (-Z), a lock lamp with a
## green status LED (glow), a ribbed top and two carry handles. Stands on -Y.
static func cargo_crate(size: Vector3 = Vector3(1.3, 1.3, 1.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := size * 0.5
	k.box(Vector3(size.x * 0.96, size.y - 0.02, size.z * 0.96))
	# Ribs pressed into the sides and the back.
	for sz: float in [-1.0, 1.0]:
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(0.02, size.y * 0.7, 0.06), Vector3(sx * (h.x * 0.96 + 0.01), -size.y * 0.05, sz * size.z * 0.3))
		k.box(Vector3(0.06, size.y * 0.7, 0.02), Vector3(sz * size.x * 0.2, -size.y * 0.05, h.z * 0.96 + 0.01))
	k.color = DARK
	var strap := 0.07
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(strap, size.y * 0.98, strap), Vector3(sx * (h.x - strap * 0.5), 0.0, sz * (h.z - strap * 0.5)))
	k.box(Vector3(size.x * 0.9, 0.046, size.z * 0.9), Vector3(0.0, -h.y + 0.027, 0.0))
	# A frame of rails round the top and bottom edges, a casting on every corner.
	var r := strap * 0.8
	for sy: float in [-1.0, 1.0]:
		var y := sy * (h.y - r * 0.5 - 0.002)
		for s: float in [-1.0, 1.0]:
			k.box(Vector3(size.x - 0.1, r, r), Vector3(0.0, y, s * (h.z - r * 0.5 - 0.003)))
			k.box(Vector3(r, r, size.z - 0.1), Vector3(s * (h.x - r * 0.5 - 0.003), y, 0.0))
	var c := minf(0.1, minf(size.x, minf(size.y, size.z)) * 0.18)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var top := 0.005 if sy > 0.0 else 0.0
				k.box(Vector3(c + 0.005, c + top, c + 0.005),
						Vector3(sx * (h.x - c * 0.5 + 0.0025), sy * (h.y - c * 0.5) + top * 0.5, sz * (h.z - c * 0.5 + 0.0025)))
	# The hatch on the front: a yellow frame round a dark panel with a grille, hinged on
	# its left with a lever on its right.
	var fz := -h.z * 0.96
	var pw := size.x * 0.55
	var ph := size.y * 0.5
	k.color = PartShapes.ACCENT
	k.box(Vector3(pw + 0.1, ph + 0.1, 0.02), Vector3(0.0, 0.0, fz - 0.01))
	k.color = DARK
	k.box(Vector3(pw, ph, 0.02), Vector3(0.0, 0.0, fz - 0.025))
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(0.05, minf(0.1, ph * 0.25), 0.04), Vector3(-pw * 0.5 - 0.05, sy * ph * 0.3, fz - 0.03))
	# The lock lamp's housing beside the hatch.
	var lamp := Vector3(pw * 0.5 + 0.1, ph * 0.3, fz - 0.005)
	k.box(Vector3(0.07, 0.05, 0.01), lamp)
	k.color = DETAIL
	for i in 4:
		var y := -ph * 0.3 + ph * 0.2 * float(i)
		k.box(Vector3(pw * 0.6, 0.03, 0.015), Vector3(-pw * 0.05, y, fz - 0.04))
	k.box(Vector3(0.04, ph * 0.45, 0.03), Vector3(pw * 0.5 - 0.06, 0.0, fz - 0.05))
	# Ribs over the lid, a handle each side.
	for i in 3:
		var x := -h.x * 0.5 + h.x * 0.5 * float(i)
		k.box(Vector3(0.05, 0.018, size.z * 0.7), Vector3(x, h.y - 0.01 + 0.009, 0.0))
	k.color = DARK
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.03, 0.06, size.z * 0.4), Vector3(sx * (h.x * 0.96 + 0.015), h.y * 0.6, 0.0))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size.x * size.y * size.z * 0.12
	var col := BoxShape3D.new()
	col.size = size + Vector3(0.0, 0.03, 0.06)
	shape.collision = col
	var g := MeshKit.new()
	g.box(Vector3(0.04, 0.025, 0.006), lamp - Vector3(0.0, 0.0, 0.008))
	shape.glow = g.finish()
	shape.glow_color = Color(0.3, 1.0, 0.45)
	return shape


## A closed cargo ramp leaf `width` x `height`, `thickness` deep along Z, its outer face
## +Z (the walking face when let down): a plate with a steel side rail down each long edge,
## a hazard border of slanted yellow and dark stripes inside the rails and across the top,
## a dark rubber toe strip along the top edge, chamfered tread bars across the face, and
## along the bottom edge three round hinge knuckles on a chrome pin with bolted straps.
static func cargo_ramp(width: float = 3.2, height: float = 2.7, thickness: float = 0.12) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hx := width * 0.5
	var hy := height * 0.5
	var hz := thickness * 0.5
	var face := thickness * 0.2                     # the plate's outer face, z
	var rail := clampf(width * 0.03, 0.07, 0.14)    # side rail width, m
	var haz := clampf(width * 0.045, 0.12, 0.22)    # hazard border width, m
	var toe := 0.05                                 # rubber toe strip, m
	var knuckle := minf(hz, 0.07)                   # hinge knuckle radius, m
	var y_lo := -hy + 0.02                          # bottom of the hazard border
	var y_strap := -hy + knuckle * 2.0 + 0.16       # top of the hinge straps
	k.color = Color.WHITE
	k.box(Vector3(width, height, thickness * 0.7), Vector3(0.0, 0.0, -thickness * 0.15))
	# Side rails along both long edges, the toe strip along the top.
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(rail, height - 0.02, hz - face + 0.002), Vector3(sx * (hx - rail * 0.5 - 0.005), 0.0, (face + hz) * 0.5 - 0.001))
	k.color = DARK
	k.box(Vector3(width - rail * 2.0 - 0.02, toe, hz - face - 0.008), Vector3(0.0, hy - toe * 0.5 - 0.01, (face + hz - 0.008) * 0.5))
	# The hazard border: down each side inside the rails, across under the toe.
	var stripe := clampf(haz * 0.45, 0.06, 0.1)
	var x_in := hx - rail - 0.01                   # inner edge of the rails
	var y_top := hy - toe - 0.01                   # underside of the toe strip
	for sx: float in [-1.0, 1.0]:
		_gear_hazard(k, Vector3(sx * (x_in - haz * 0.5), (y_lo + y_top - haz) * 0.5, face), Vector3.UP, Vector3.RIGHT,
				Vector3.BACK, Vector2(y_top - haz - y_lo, haz), stripe)
	_gear_hazard(k, Vector3(0.0, y_top - haz * 0.5, face), Vector3.RIGHT, Vector3.UP, Vector3.BACK,
			Vector2(x_in * 2.0, haz), stripe)
	# Tread bars across the face between the borders: chamfered, standing a little short of
	# the rails.
	k.color = DETAIL
	var x_t := x_in - haz - 0.03
	var y0 := y_strap + 0.08
	var y1 := y_top - haz - 0.12
	var treads := maxi(4, int((y1 - y0) / 0.28) + 1)
	var top := hz - 0.01
	for i in treads:
		var y := lerpf(y0, y1, float(i) / float(treads - 1))
		_prism_x(k, PackedVector2Array([Vector2(face - 0.002, y - 0.035), Vector2(top, y - 0.018), Vector2(top, y + 0.018),
				Vector2(face - 0.002, y + 0.035)]), -x_t, x_t)
	# The hinge along the bottom edge: a chrome pin, three dark knuckles on it with bolted
	# straps up the face.
	var ky := -hy + knuckle
	var kw := clampf(width * 0.1, 0.2, 0.4)
	k.color = TRIM
	_tube(k, Vector3(-hx * 0.6 - kw * 0.5 - 0.04, ky, 0.0), Vector3(hx * 0.6 + kw * 0.5 + 0.04, ky, 0.0), knuckle * 0.4, 8)
	for i in 3:
		var x := -hx * 0.6 + hx * 0.6 * float(i)
		k.color = DARK
		_tube(k, Vector3(x - kw * 0.5, ky, 0.0), Vector3(x + kw * 0.5, ky, 0.0), knuckle, 10)
		k.color = RIM
		var sh := y_strap + hy - knuckle
		k.box(Vector3(kw * 0.8, sh, 0.012), Vector3(x, -hy + knuckle + sh * 0.5, face + 0.006))
		k.color = DETAIL
		for bx: float in [-1.0, 1.0]:
			_gear_bolt(k, Vector3(x + bx * kw * 0.25, -hy + knuckle * 2.0 + 0.1, face + 0.012), Vector3.BACK, 0.018, 0.01)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * thickness * 0.6
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, thickness)
	shape.collision = col
	return shape


## A round shower cubicle (the lander's washroom) `radius` across, `height` tall: a drum
## in the material colour (green in the reference) standing in a stainless tray on a dark
## kick plinth, under a dark moulded plastic cap with anodised vent slats. On the front
## (-Z): a curved door standing proud between anodised jambs under a header, rubber seals
## down its edges, along its top and in a sweep under it, a frosted
## glass vision strip (PartShape.glass), a chrome grab handle, an occupied lamp over the
## door and a small plastic control panel beside it with a dark readout and two status
## lights (lit in `glow`). Stands on -Y.
static func shower(radius: float = 0.42, height: float = 2.1, glow := Color(0.35, 0.85, 1.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var h := height * 0.5
	var base := 0.14                     # plinth and tray, m
	var cap := 0.12                      # cap, m
	var y_lo := -h + base                # floor of the cubicle
	var y_hi := h - cap                  # underside of the cap
	var door := 0.62                     # half the door's angle, rad
	var y_door := y_hi - 0.07            # top of the door leaf
	# The kick plinth, the tray round its top, the drum.
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(0.0, -h), Vector2(radius * 0.93, -h), Vector2(radius * 0.93, -h + 0.09),
			Vector2(0.0, -h + 0.09)]), 16)
	k.color = STAINLESS
	k.lathe(PackedVector2Array([Vector2(0.0, -h + 0.09), Vector2(radius + 0.008, -h + 0.09),
			Vector2(radius + 0.008, y_lo), Vector2(0.0, y_lo)]), 16)
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(0.0, y_lo), Vector2(radius, y_lo), Vector2(radius, y_hi), Vector2(0.0, y_hi)]), 16)
	# The cap: a lip, a chamfer up to the top, three vent slats on it.
	k.color = PLASTIC_DARK
	k.lathe(PackedVector2Array([Vector2(0.0, y_hi), Vector2(radius + 0.006, y_hi), Vector2(radius + 0.006, y_hi + 0.03),
			Vector2(radius * 0.86, h), Vector2(0.0, h)]), 16)
	k.color = ANODISED
	for i in 3:
		k.box(Vector3(radius * 0.8, 0.008, 0.03), Vector3(0.0, h + 0.004, radius * (-0.22 + 0.22 * float(i))))
	# The door leaf, its jambs and header, the vision strip and the handle.
	k.color = Color.WHITE
	_galley_arc(k, radius * 0.97, radius + 0.008, -door, door, y_lo + 0.03, y_door, 6)
	k.color = ANODISED
	for s: float in [-1.0, 1.0]:
		var d := Vector3(sin(s * (door + 0.04)), 0.0, -cos(door + 0.04))
		k.strut(d * (radius - 0.004) + Vector3(0.0, y_lo, 0.0), d * (radius - 0.004) + Vector3(0.0, y_door, 0.0), 0.03)
	_galley_arc(k, radius * 0.97, radius + 0.014, -door - 0.08, door + 0.08, y_door, y_door + 0.05, 6)
	# The leaf's rubber seals: a strip down each edge against the jambs, a sweep under it
	# closing the gap to the tray, and a band along its top under the header, each a few
	# millimetres proud of the leaf.
	k.color = RUBBER
	for s: float in [-1.0, 1.0]:
		var a0 := door - 0.04 if s > 0.0 else -door - 0.006
		_galley_arc(k, radius + 0.006, radius + 0.0135, a0, a0 + 0.046, y_lo + 0.006, y_door - 0.002, 1)
	_galley_arc(k, radius * 0.975, radius + 0.0125, -door - 0.024, door + 0.024, y_lo + 0.004, y_lo + 0.028, 4)
	_galley_arc(k, radius + 0.006, radius + 0.0115, -door, door, y_door - 0.02, y_door - 0.003, 4)
	k.color = DARK
	_galley_arc(k, radius, radius + 0.012, -door * 0.45, door * 0.45, y_lo + height * 0.45, y_door - 0.25, 4)
	# Frosted glass over the vision strip, a hair proud of it.
	var gk := MeshKit.new()
	_galley_arc(gk, radius + 0.0125, radius + 0.0135, -door * 0.43, door * 0.43, y_lo + height * 0.45 + 0.01,
			y_door - 0.26, 4)
	k.color = CHROME
	var hd := Vector3(sin(door * 0.72), 0.0, -cos(door * 0.72))
	var y_grip := y_lo + height * 0.36
	_tube(k, hd * (radius + 0.04) + Vector3(0.0, y_grip - 0.2, 0.0), hd * (radius + 0.04) + Vector3(0.0, y_grip + 0.2, 0.0), 0.012, 8)
	for dy: float in [-0.16, 0.16]:
		k.strut(hd * radius + Vector3(0.0, y_grip + dy, 0.0), hd * (radius + 0.045) + Vector3(0.0, y_grip + dy, 0.0), 0.02)
	# The occupied lamp on the header (lit).
	var y_lamp := y_door + 0.025
	_seating_pad(g, Vector3(0.0, y_lamp, -radius - 0.014), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, 0.05, 0.012, 0.006, 0.003)
	# The control panel left of the door: a plastic plate, a dark readout, two lit lights.
	var pa := -door - 0.42
	var pd := Vector3(sin(pa), 0.0, -cos(pa))
	var pu := Vector3(cos(pa), 0.0, sin(pa))
	var pc := pd * (radius - 0.006) + Vector3(0.0, y_lo + height * 0.5, 0.0)
	k.color = PLASTIC_PALE
	_seating_pad(k, pc, pu, Vector3.UP, pd, 0.05, 0.1, 0.022, 0.006)
	k.color = DARK
	_seating_pad(k, pc + pd * 0.022 + Vector3(0.0, 0.035, 0.0), pu, Vector3.UP, pd, 0.035, 0.03, 0.004)
	for j in 2:
		_seating_pad(g, pc + pd * 0.022 + Vector3(0.0, -0.035, 0.0) + pu * (0.02 - 0.04 * float(j)), pu, Vector3.UP, pd,
				0.009, 0.009, 0.006)
	var shape := _cylinder(k, radius, height)
	shape.volume = PI * radius * radius * 0.04 * height
	shape.glow = g.finish()
	shape.glow_color = glow
	shape.glass = gk.finish()
	shape.glass_kind = Glazing.Kind.FROSTED
	return shape


# --- Cargo shuttle parts (0.33) ---------------------------------------------------------

## A bed set into a wall niche (the cargo shuttle's bunk) `length` along X, `depth` deep
## (Z), `height` tall: a shell in the material colour (back, top, bottom and two ends) open
## on its front (-Z) with trim strips up its front edges, a dark kick under a base with two
## drawers, a chamfered dark mattress, a padded headboard on the head (-X) end, a pillow, a
## folded blanket at the foot, a rail on two stubs along the bed's front edge, a shelf canopy
## over the bed when the niche is tall enough (1.6 m and up) and two green ring lights in
## dark bezels on the back wall at the head end (set lower in a low niche). Stands on -Y.
static func bed_alcove(length: float = 2.1, depth: float = 1.0, height: float = 2.0) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := Vector3(length, height, depth) * 0.5
	var t := 0.06
	var kick := 0.08                          # kick recess height, m
	var bed_top := -h.y + 0.62
	var room := h.y - t - bed_top             # clear height over the bed, m
	var y_base := bed_top - 0.12              # top of the base (the mattress sits on it)
	var z_front := -h.z + 0.04                # front face of the base
	var zm := -t * 0.5 + 0.04                 # middle of the mattress
	var hm := (depth - t - 0.14) * 0.5        # half the mattress's depth
	# The shell: back wall, top, the base under the bed, an end wall each side.
	k.box(Vector3(length, height, t), Vector3(0.0, 0.0, h.z - t * 0.5))
	k.box(Vector3(length, t, depth - t), Vector3(0.0, h.y - t * 0.5, -t * 0.5))
	k.box(Vector3(length - 2.0 * t, y_base + h.y - kick, h.z - t - z_front), Vector3(0.0, (-h.y + kick + y_base) * 0.5, (z_front + h.z - t) * 0.5))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(t, height - t, depth - t), Vector3(sx * (h.x - t * 0.5), -t * 0.5, -t * 0.5))
	# Two drawers in the base's front.
	var hd := (y_base - (-h.y + kick)) * 0.5 - 0.04
	var yd := (y_base - h.y + kick) * 0.5
	for sx: float in [-1.0, 1.0]:
		_seating_pad(k, Vector3(sx * (h.x - t) * 0.5, yd, z_front), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
				(h.x - t) * 0.5 - 0.03, hd, 0.012, 0.006)
	# A canopy shelf over the bed (tall niches only), the rail along the bed's front edge.
	if room > 1.0:
		k.box(Vector3(length - 2.0 * t, 0.05, depth * 0.45), Vector3(0.0, bed_top + 0.95, h.z - t - depth * 0.225))
	k.color = DETAIL
	var rx := (length - 2.0 * t - 0.2) * 0.5
	k.box(Vector3(rx * 2.0, 0.05, 0.05), Vector3(0.0, bed_top + 0.1, -h.z + 0.06))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.03, 0.2, 0.03), Vector3(sx * (rx - 0.05), y_base + 0.1, -h.z + 0.06))
		k.box(Vector3(0.22, 0.025, 0.01), Vector3(sx * (h.x - t) * 0.5, y_base - 0.06, z_front - 0.017))
	# Trim strips up the front edges of the ends and along the top.
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(t - 0.012, height - t - 0.02, 0.008), Vector3(sx * (h.x - t * 0.5), -t * 0.5 - 0.01, -h.z - 0.004))
	k.box(Vector3(length - 0.012, t - 0.012, 0.008), Vector3(0.0, h.y - t * 0.5, -h.z - 0.004))
	k.color = DARK
	k.box(Vector3(length - 2.0 * t, kick, h.z - t - z_front - 0.03), Vector3(0.0, -h.y + kick * 0.5, (z_front + 0.03 + h.z - t) * 0.5))
	# Bedding: mattress, headboard pad on the head end, pillow, blanket at the foot.
	k.color = ALCOVE_MATTRESS
	_seating_pad(k, Vector3(0.0, y_base, zm), Vector3.RIGHT, Vector3.BACK, Vector3.UP, h.x - t - 0.01, hm, 0.12, 0.03)
	_seating_pad(k, Vector3(-h.x + t, bed_top + room * 0.32, zm + 0.02), Vector3.BACK, Vector3.UP, Vector3.RIGHT,
			hm - 0.04, room * 0.2, 0.04, 0.015)
	k.color = ALCOVE_LINEN
	_seating_pad(k, Vector3(-h.x + t + 0.27, bed_top, zm + 0.04), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			0.18, minf(depth * 0.25, hm - 0.06), 0.08, 0.035)
	k.color = ALCOVE_BLANKET
	_seating_pad(k, Vector3(h.x - t - 0.42, bed_top, zm), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			0.34, hm - 0.03, 0.035, 0.01)
	# Two ring lights at the head end of the back wall, in dark bezels.
	var ly := bed_top + minf(0.6, room * 0.5)
	k.color = DARK
	for i in 2:
		var c := Vector3(-h.x + t + 0.2 + 0.26 * float(i), ly, h.z - t)
		_seating_pad(k, c, Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, 0.1, 0.1, 0.025, 0.012)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * height * depth * 0.12
	var col := BoxShape3D.new()
	col.size = Vector3(length, height, depth)
	shape.collision = col
	var g := MeshKit.new()
	for i in 2:
		var c := Vector3(-h.x + t + 0.2 + 0.26 * float(i), ly, h.z - t - 0.03)
		for j in 8:
			var a0 := TAU * float(j) / 8.0
			var a1 := TAU * float(j + 1) / 8.0
			g.strut(c + Vector3(cos(a0), sin(a0), 0.0) * 0.065, c + Vector3(cos(a1), sin(a1), 0.0) * 0.065, 0.02)
	shape.glow = g.finish()
	shape.glow_color = Color(0.6, 1.0, 0.2)
	return shape


## An SE2-style survival kit (the cargo shuttle's medical station) `size` across: a dark
## grey cabinet whose top steps in on a sloped shoulder, a blue screen on an arm out of its
## upper front, side vents, a yellow-framed hatch with a handle and latches low in the
## front, two capped gas canisters at its foot, status LEDs and a green cross lamp. Stands
## on -Y, front -Z.
static func survival_kit(size: Vector3 = Vector3(1.1, 2.0, 0.9)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := size * 0.5
	var fz := -h.z
	# Plinth, body set back above it, a shoulder stepping in to a narrower block on top.
	k.color = DARK
	k.box(Vector3(size.x, 0.2, size.z), Vector3(0.0, -h.y + 0.1, 0.0))
	k.color = Color.WHITE
	var body_top := -h.y + 0.2 + size.y * 0.62
	var body_front := fz + size.z * 0.2
	k.box(Vector3(size.x, size.y * 0.62, size.z * 0.8), Vector3(0.0, -h.y + 0.2 + size.y * 0.31, h.z * 0.2))
	var top_front := h.z * 0.4 - size.z * 0.3
	var shoulder := body_top + 0.1
	var ring_a := PackedVector3Array()
	var ring_b := PackedVector3Array()
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		ring_a.append(Vector3(c.x * h.x * 0.97, body_top, body_front + 0.03 if c.y < 0.0 else h.z - 0.01))
		ring_b.append(Vector3(c.x * size.x * 0.4, shoulder, top_front if c.y < 0.0 else h.z - 0.01))
	k.loft(ring_a, ring_b)
	k.box(Vector3(size.x * 0.8, h.y - shoulder, h.z - 0.01 - top_front),
			Vector3(0.0, (h.y + shoulder) * 0.5, (h.z - 0.01 + top_front) * 0.5))
	# Dark edge trims up the body's front corners, vent slats in both sides.
	k.color = DARK
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.04, size.y * 0.62 - 0.02, 0.012), Vector3(sx * (h.x - 0.02), body_top - size.y * 0.31, body_front - 0.006))
		for i in 4:
			k.box(Vector3(0.012, 0.03, size.z * 0.45), Vector3(sx * (h.x + 0.006), body_top - 0.15 - 0.06 * float(i), h.z * 0.2))
	# Gas canisters lying across the front of the plinth, valve caps on their ends.
	for i in 2:
		var y := -h.y + 0.3 + 0.17 * float(i)
		k.color = DETAIL
		_tube(k, Vector3(-h.x + 0.08, y, fz + 0.14), Vector3(h.x - 0.08, y, fz + 0.14), 0.075, 10)
		k.color = DARK
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(0.05, 0.06, 0.06), Vector3(sx * (h.x - 0.055), y, fz + 0.14))
	# The hatch: a yellow frame round a dark panel, low on the body's front, with a pull
	# handle and two latches.
	var hatch := Vector3(size.x * 0.18, -h.y + size.y * 0.4, body_front)
	k.color = PartShapes.ACCENT
	k.box(Vector3(size.x * 0.42, size.y * 0.17, 0.02), hatch - Vector3(0.0, 0.0, 0.01))
	k.color = DARK
	k.box(Vector3(size.x * 0.32, size.y * 0.12, 0.02), hatch - Vector3(0.0, 0.0, 0.02))
	k.color = DETAIL
	k.box(Vector3(size.x * 0.16, 0.03, 0.03), hatch - Vector3(0.0, size.y * 0.03, 0.045))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.04, 0.05, 0.02), hatch + Vector3(sx * size.x * 0.18, size.y * 0.04, -0.03))
	# The screen arm with a knuckle at the screen, its dark bezel, a work shelf with a lip.
	k.color = DARK
	var screen := Vector3(-size.x * 0.18, h.y - size.y * 0.4, body_front - 0.25)
	k.box(Vector3(0.08, 0.08, 0.22), Vector3(-size.x * 0.22, h.y - size.y * 0.42, body_front - 0.11))
	k.box(Vector3(size.x * 0.5, size.y * 0.2, 0.06), screen)
	k.color = DETAIL
	k.box(Vector3(0.12, 0.11, 0.05), Vector3(-size.x * 0.22, h.y - size.y * 0.42, body_front - 0.2))
	k.color = Color.WHITE
	k.box(Vector3(size.x * 0.7, 0.04, 0.2), Vector3(0.0, -h.y + size.y * 0.55, body_front - 0.1))
	k.color = DARK
	k.box(Vector3(size.x * 0.7, 0.05, 0.015), Vector3(0.0, -h.y + size.y * 0.55 + 0.01, body_front - 0.2075))
	# On the top block: a dark plate behind the cross lamp, a strip behind three status lamps.
	var lamp_y := (h.y + shoulder) * 0.5
	var lamp_z := top_front - 0.005
	k.box(Vector3(0.17, 0.17, 0.01), Vector3(size.x * 0.22, lamp_y, lamp_z))
	k.box(Vector3(0.2, 0.06, 0.01), Vector3(-size.x * 0.2, lamp_y, lamp_z))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size.x * size.y * size.z * 0.35
	var col := BoxShape3D.new()
	col.size = size + Vector3(0.0, 0.0, 0.02)
	shape.collision = col
	var g := MeshKit.new()
	g.box(Vector3(size.x * 0.44, size.y * 0.15, 0.01), screen - Vector3(0.0, 0.0, 0.035))
	g.box(Vector3(0.12, 0.04, 0.008), Vector3(size.x * 0.22, lamp_y, lamp_z - 0.009))
	g.box(Vector3(0.04, 0.12, 0.006), Vector3(size.x * 0.22, lamp_y, lamp_z - 0.008))
	for i in 3:
		g.box(Vector3(0.03, 0.025, 0.006), Vector3(-size.x * 0.2 - 0.06 + 0.06 * float(i), lamp_y, lamp_z - 0.008))
	shape.glow = g.finish()
	shape.glow_color = Color(0.35, 0.75, 1.0)
	return shape


## The service hatch of a built-in cargo container (the cargo shuttle's back wall)
## `width` x `height`, `depth` deep, in the cargo crate's language: a dark backing panel
## with a corner casting at each corner (a dark twist-lock slot in each), a pale label
## plate over the hatch on tall ones, a thick yellow frame with cut corners and a bolt on
## each cut, a recessed steel leaf with three dark bars across (the middle one
## yellow-edged), two hinge knuckles on its left, a lever on two pivots on its right and a
## lock lamp over the lever with a green LED (`glow`). Its back is +Z (bolt that to the
## wall), its face -Z; the lever's grip is the front-most thing, 8 cm out.
static func container_hatch(width: float = 1.3, height: float = 1.6, depth: float = 0.12,
		glow := Color(0.3, 1.0, 0.45)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hx := width * 0.5
	var hy := height * 0.5
	var hz := depth * 0.5
	var s := minf(width, height)
	var m := clampf(s * 0.07, 0.025, 0.09)              # margin round the frame, m
	var fb := clampf(s * 0.05, 0.025, 0.06)             # frame bar, square, m
	var label := height >= 1.0 and width >= 0.6
	var lh := clampf(height * 0.07, 0.06, 0.11)         # label plate height, m
	var top := hy - m - ((lh + m * 0.5) if label else 0.0)
	var fx := hx - m - fb * 0.5                          # frame centre line, half width
	var fy0 := -hy + m + fb * 0.5
	var fy1 := top - fb * 0.5
	var yc := (fy0 + fy1) * 0.5
	var fh := (fy1 - fy0) * 0.5
	var c := minf(fx, fh) * 0.24                         # cut corners, m
	var front := -0.08                                   # the grip's face, m
	# The backing panel and its corner castings.
	k.color = DARK
	k.box(Vector3(width, height, hz), Vector3(0.0, 0.0, hz * 0.5))
	var cs := clampf(s * 0.08, 0.03, 0.09)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var cc := Vector3(sx * (hx - cs * 0.5), sy * (hy - cs * 0.5), -0.0125)
			k.color = DETAIL
			k.box(Vector3(cs, cs, 0.025), cc)
			k.color = DARK
			var e := Vector3(cc.x, cc.y, -0.027)
			k.quad(e + Vector3(-cs * 0.25, -cs * 0.14, 0), e + Vector3(cs * 0.25, -cs * 0.14, 0),
					e + Vector3(cs * 0.25, cs * 0.14, 0), e + Vector3(-cs * 0.25, cs * 0.14, 0), Vector3.FORWARD)
	# The label plate over the hatch, two dark lines of lettering on it.
	if label:
		var ly := hy - m - lh * 0.5
		k.color = PLATE
		k.box(Vector3(width * 0.5, lh, 0.012), Vector3(0.0, ly, -0.006))
		k.color = DARK
		k.box(Vector3(width * 0.34, lh * 0.18, 0.004), Vector3(-width * 0.04, ly + lh * 0.17, -0.014))
		k.box(Vector3(width * 0.22, lh * 0.18, 0.004), Vector3(-width * 0.1, ly - lh * 0.2, -0.014))
	# The leaf: a recessed steel octagon inside the frame, three dark bars across it.
	var lt := minf(0.018, fb * 0.5)
	var lx := fx - fb * 0.3
	var ly0 := fh - fb * 0.3
	k.color = HATCH_LEAF
	k.loft(_stowage_oct_xy(Vector3(0.0, yc, 0.0), lx, ly0, c), _stowage_oct_xy(Vector3(0.0, yc, -lt), lx, ly0, c))
	var iw := fx - fb * 0.5                              # inside the frame, half width
	var bh := clampf(fh * 0.16, 0.025, 0.12)
	var bt := clampf(s * 0.02, 0.01, 0.025)
	k.color = DARK
	for i in 3:
		k.box(Vector3(iw * 1.3, bh, bt), Vector3(-iw * 0.12, yc + fh * 0.52 * float(i - 1), -lt - bt * 0.5))
	k.color = PartShapes.ACCENT
	k.box(Vector3(iw * 1.1, bh * 0.25, 0.006), Vector3(-iw * 0.12, yc + bh * 0.32, -lt - bt - 0.003))
	# The frame: an octagon of thick yellow bars, a bolt on each cut corner.
	k.color = PartShapes.ACCENT
	var ring := _stowage_oct_xy(Vector3(0.0, yc, -fb * 0.5), fx, fh, c)
	for i in ring.size():
		k.strut(ring[i], ring[(i + 1) % ring.size()], fb)
	k.color = DETAIL
	var bs := fb * 0.4
	for i in 4:
		var mid := (ring[i * 2 + 1] + ring[(i * 2 + 2) % 8]) * 0.5
		k.box(Vector3(bs, bs, 0.008), Vector3(mid.x, mid.y, -fb - 0.004))
	# Hinge knuckles over the frame's left side.
	var kw := fb * 0.8
	var kd := -front * 0.8 - lt                          # knuckle depth, m
	k.color = DARK
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(kw, fh * 0.22, kd), Vector3(-fx + fb * 0.1, yc + sy * fh * 0.55, -lt - kd * 0.5))
	# The lever: two pivots, a grip standing off them, the lock lamp over the top pivot.
	var gx := iw * 0.72
	var gt := clampf(s * 0.03, 0.015, 0.035)
	var pd := -front * 0.7 - lt                          # pivot depth, m
	k.color = DETAIL
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(gt * 1.4, gt * 1.4, pd), Vector3(gx, yc + sy * fh * 0.3, -lt - pd * 0.5))
	var gz0 := -lt - pd
	k.box(Vector3(gt, fh * 0.75, gz0 - front), Vector3(gx, yc, (gz0 + front) * 0.5))
	var lamp := Vector3(gx, yc + fh * 0.62, -lt - 0.006)
	k.color = DARK
	k.box(Vector3(gt * 2.4, gt * 1.6, 0.012), lamp)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * depth * 0.3
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth + 0.05)
	shape.collision = col
	var g := MeshKit.new()
	g.box(Vector3(gt * 1.2, gt * 0.7, 0.004), lamp - Vector3(0.0, 0.0, 0.008))
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## Eight points round a rectangle `hx` by `hy` with its corners cut by `c`, in the XY plane
## through `at` (the stowage parts' hatch frames, leaves and case bodies).
static func _stowage_oct_xy(at: Vector3, hx: float, hy: float, c: float) -> PackedVector3Array:
	return PackedVector3Array([at + Vector3(-hx + c, hy, 0.0), at + Vector3(hx - c, hy, 0.0), at + Vector3(hx, hy - c, 0.0),
			at + Vector3(hx, -hy + c, 0.0), at + Vector3(hx - c, -hy, 0.0), at + Vector3(-hx + c, -hy, 0.0),
			at + Vector3(-hx, -hy + c, 0.0), at + Vector3(-hx, hy - c, 0.0)])


## `n` points round a circle of `radius` about `centre`: in the XZ plane (round things along
## Y), or in the XY plane when `along_z` (bombs lying along Z). `phase` turns the first
## point on by that fraction of a step.
static func _stowage_ring(centre: Vector3, radius: float, n: int, along_z: bool = false, phase: float = 0.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in n:
		var a := TAU * (float(i) + phase) / float(n)
		if along_z:
			out.append(centre + Vector3(cos(a), sin(a), 0.0) * radius)
		else:
			out.append(centre + Vector3(cos(a), 0.0, sin(a)) * radius)
	return out


## Turns and moves everything added to `k` since vertex `from` by `t` (normals with it).
static func _stowage_xform(k: MeshKit, from: int, t: Transform3D) -> void:
	for i in range(from, k.verts.size()):
		k.verts[i] = t * k.verts[i]
		k.normals[i] = (t.basis * k.normals[i]).normalized()



# --- Courier parts (0.34) ---------------------------------------------------------------

## The courier's swappable grinder (Q1S Courier's bow): two segmented saw discs side by
## side on one axle along Y, `radius` across: steel cores with radial expansion slots,
## bolted clamp washers and hooked tooth segments round the rim, a hex nut on the axle's -Y
## end. A guard with yellow edges hoods the discs' aft (+Z) side. A gearbox drum carries the motor on
## the axle's +Y end (in the material colour, pale green in the reference): a chamfered
## housing on a bolted foot flange, cooling ribs down its sides, a fan grille, a red stop
## tag and a lit run lamp on its front (-Z), a terminal box with a cable gland and a maker's
## plate on top; two dark hoses leave its back through couplings and run back toward +Z
## for `hose` metres (into the nose it hangs from), clamped at the bend and ferruled at the
## end. Turn +Y outboard and +Z aft.
static func grinder_head(radius: float = 0.75, hose: float = 1.0) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var t := 0.1                     # disc core thickness, m
	var hub := radius * 0.16         # axle and clamp scale, m
	var rc := radius * 0.86          # the core's rim, where the tooth segments sit, m
	var discs: Array[float] = [-0.25, -0.03]
	# The axle: a dark shaft, a hex nut on its outboard (-Y) end.
	k.color = DARK
	_thrusters_ring(k, 0.0, hub * 0.7, -0.33, 0.12, 12)
	k.color = DETAIL
	_thrusters_ring(k, 0.0, hub * 0.95, -0.36, -0.33, 6)
	var teeth := clampi(int(TAU * radius / 0.2), 16, 32)
	var tt := t * 0.5 + 0.012        # tooth half thickness (wider than the core: the kerf), m
	for di in discs.size():
		var y: float = discs[di]
		# The steel core.
		k.color = DETAIL
		_thrusters_ring(k, hub * 0.7, rc, y - t * 0.5, y + t * 0.5, 32)
		# Radial expansion slots on both faces, a little proud (dark).
		k.color = DARK
		for i in 10:
			var a := TAU * (float(i) + 0.25 * float(di)) / 10.0
			var dir := Vector3(cos(a), 0.0, sin(a))
			for side: float in [-1.0, 1.0]:
				_gear_yblock(k, dir * rc * 0.74 + Vector3(0.0, y + side * (t * 0.5 + 0.003), 0.0), -a,
						Vector3(rc * 0.2, 0.008, 0.022))
		# Clamp washers either side of the core, bolted.
		k.color = TRIM
		for side: float in [-1.0, 1.0]:
			var y0 := y + side * t * 0.5
			var y1 := y + side * (t * 0.5 + 0.022)
			_thrusters_ring(k, hub * 0.7, hub * 1.7, minf(y0, y1), maxf(y0, y1), 16)
			k.color = DETAIL
			_piping_bolts(k, Vector3(0.0, y, 0.0), Vector3.UP * side, t * 0.5 + 0.022, 6, hub * 1.25,
					clampf(hub * 0.22, 0.02, 0.035), 0.012)
			k.color = TRIM
		# The tooth segments: hooked blocks round the rim, a gullet between each, the two
		# discs' teeth staggered half a pitch.
		k.color = TRIM
		var pitch := TAU / float(teeth)
		for i in teeth:
			var a0 := pitch * (float(i) + 0.5 * float(di))
			var a1 := a0 + pitch * 0.72
			var pts := [Vector2(rc - 0.012, a0), Vector2(radius, a0 + pitch * 0.06), Vector2(radius - 0.025, a1),
					Vector2(rc - 0.012, a1)]
			var lo := PackedVector3Array()
			var hi := PackedVector3Array()
			for p: Vector2 in pts:
				lo.append(Vector3(cos(p.y) * p.x, y - tt, sin(p.y) * p.x))
				hi.append(Vector3(cos(p.y) * p.x, y + tt, sin(p.y) * p.x))
			k.loft(lo, hi)
	# The guard: a hood over the discs' aft side, a top plate from the gearbox out to a skirt
	# round the rim, yellow edges on its top and on a lip curled under the lower disc.
	k.color = Color.WHITE
	var ga0 := PI * 0.14
	var ga1 := PI * 0.86
	var top_y := discs[1] + tt + 0.008
	_heroes_sector(k, hub * 1.3, radius + 0.018, top_y, top_y + 0.025, ga0, ga1, 12)
	_heroes_sector(k, radius + 0.004, radius + 0.018, discs[0] - tt - 0.03, top_y, ga0, ga1, 12)
	k.color = PartShapes.ACCENT
	_heroes_sector(k, radius - 0.05, radius + 0.022, discs[0] - tt - 0.03, discs[0] - tt - 0.01, ga0, ga1, 12)
	_heroes_sector(k, radius - 0.05, radius + 0.022, top_y + 0.025, top_y + 0.031, ga0, ga1, 12)
	# Gearbox drum between the guard and the motor, bolted to the motor's foot flange.
	var motor := Vector3(0.6, 0.36, 0.75)
	var mc := Vector3(0.0, 0.12 + 0.02 + motor.y * 0.5, 0.12)
	var m_lo := mc.y - motor.y * 0.5
	k.color = Color.WHITE
	_thrusters_ring(k, 0.0, hub * 1.35, top_y + 0.02, m_lo - 0.025, 16)
	k.color = DETAIL
	_thrusters_ring(k, hub * 1.3, hub * 1.5, top_y + 0.025, top_y + 0.05, 16)
	var flange := Vector3(motor.x + 0.08, 0.025, motor.z + 0.08)
	k.box(flange, Vector3(0.0, m_lo - flange.y * 0.5, mc.z))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_gear_bolt(k, Vector3(sx * (motor.x * 0.5 + 0.022), m_lo, mc.z + sz * (motor.z * 0.5 + 0.022)), Vector3.UP, 0.014, 0.014)
	# The motor: a chamfered housing along X, cooling ribs down both X sides.
	k.color = Color.WHITE
	var mz0 := mc.z - motor.z * 0.5
	var mz1 := mc.z + motor.z * 0.5
	var my1 := mc.y + motor.y * 0.5
	var mch := 0.06
	_prism_x(k, PackedVector2Array([Vector2(mz0, m_lo + mch), Vector2(mz0 + mch, m_lo), Vector2(mz1 - mch, m_lo),
			Vector2(mz1, m_lo + mch), Vector2(mz1, my1 - mch), Vector2(mz1 - mch, my1), Vector2(mz0 + mch, my1),
			Vector2(mz0, my1 - mch)]), -motor.x * 0.5, motor.x * 0.5)
	for sx: float in [-1.0, 1.0]:
		for i in 5:
			var ry := lerpf(m_lo + 0.06, my1 - 0.06, float(i) / 4.0)
			k.box(Vector3(0.02, 0.024, motor.z - 0.16), Vector3(sx * (motor.x * 0.5 + 0.008), ry, mc.z + 0.02))
	# The fan grille on the front face: a bright bezel, a dark disc, slats across it.
	var fan := Vector3(-0.07, mc.y, mz0)
	var fr := minf(motor.y * 0.36, 0.13)
	k.color = TRIM
	_piping_spin(k, fan, Vector3.FORWARD, PackedVector2Array([Vector2(fr * 0.85, 0.0), Vector2(fr * 1.12, 0.0),
			Vector2(fr * 1.12, 0.018), Vector2(fr * 0.85, 0.018)]), [TRIM] as Array[Color], 16)
	k.color = DARK
	_tube(k, fan + Vector3(0.0, 0.0, 0.002), fan + Vector3(0.0, 0.0, -0.01), fr * 0.9, 16)
	k.color = DETAIL
	for i in 4:
		var sy := lerpf(-fr * 0.6, fr * 0.6, float(i) / 3.0)
		k.box(Vector3(2.0 * sqrt(fr * fr * 0.81 - sy * sy), 0.014, 0.012), fan + Vector3(0.0, sy, -0.016))
	# The red stop tag and the run lamp's dark bezel beside the fan.
	k.color = STOP_RED
	k.box(Vector3(0.1, 0.08, 0.012), Vector3(0.19, m_lo + 0.08, mz0 - 0.006))
	k.color = DARK
	var lamp := Vector3(0.19, my1 - 0.09, mz0)
	k.box(Vector3(0.07, 0.07, 0.008), lamp + Vector3(0.0, 0.0, -0.004))
	g.box(Vector3(0.04, 0.04, 0.006), lamp + Vector3(0.0, 0.0, -0.011))
	# The terminal box on top: a lid with four screws, a cable gland, a maker's plate.
	var tb := Vector3(motor.x * 0.7, 0.06, motor.z * 0.6)
	var tc := mc + Vector3(0.0, motor.y * 0.5 + 0.03, -0.05)
	k.color = Color.WHITE
	k.box(tb, tc)
	k.color = DETAIL
	k.box(Vector3(tb.x - 0.03, 0.006, tb.z - 0.03), tc + Vector3(0.0, tb.y * 0.5 + 0.003, 0.0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.018, 0.006, 0.018), tc + Vector3(sx * (tb.x * 0.5 - 0.035), tb.y * 0.5 + 0.009, sz * (tb.z * 0.5 - 0.035)))
	_tube(k, tc + Vector3(tb.x * 0.5 - 0.01, -0.005, 0.06), tc + Vector3(tb.x * 0.5 + 0.03, -0.005, 0.06), 0.022, 8)
	k.color = PLATE
	k.box(Vector3(motor.x * 0.6, 0.006, 0.12), tc + Vector3(0.0, tb.y * 0.5 + 0.009, -0.08))
	k.color = DARK
	for j in 2:
		k.box(Vector3(motor.x * (0.42 - 0.14 * float(j)), 0.004, 0.018),
				tc + Vector3(-motor.x * 0.07 * float(j), tb.y * 0.5 + 0.0135, -0.1 + 0.04 * float(j)))
	# Two hoses out of the motor's back through couplings, down to the guard's height and
	# back into the nose: a clamp at the bend, a ferrule at the end.
	var back := mz1
	var hy := top_y + 0.025 + 0.085   # the hoses' run, clear over the guard, m
	for x: float in [-0.13, 0.13]:
		var p0 := Vector3(x, mc.y - 0.02, back - 0.02)
		var p1 := Vector3(x, hy, back + hose * 0.5)
		var p2 := Vector3(x, hy, back + hose)
		k.color = TRIM
		_tube(k, Vector3(x, p0.y, back - 0.01), Vector3(x, p0.y, back + 0.05), 0.085, 10)
		k.color = DARK
		_tube(k, p0, p1, 0.065, 10)
		_tube(k, p1 - (p1 - p0).normalized() * 0.03, p2, 0.065, 10)
		k.color = DETAIL
		_tube(k, p1 + Vector3(0.0, 0.0, 0.0), p1 + Vector3(0.0, 0.0, 0.05), 0.074, 10)
		k.color = TRIM
		_tube(k, p2 - Vector3(0.0, 0.0, 0.08), p2, 0.075, 10)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * radius * radius * t * 2.0 * 0.6 + motor.x * motor.y * motor.z * 0.4
	var pts := PackedVector3Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		for y: float in [-0.36, top_y + 0.025]:
			pts.append(Vector3(cos(a) * (radius + 0.01), y, sin(a) * (radius + 0.01)))
	for x: float in [-motor.x * 0.5, motor.x * 0.5]:
		for y: float in [0.12, mc.y + motor.y * 0.5 + 0.08]:
			for z: float in [mc.z - motor.z * 0.5, back + hose]:
				pts.append(Vector3(x, y, z))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = GLOWING
	return shape


## A solid annular sector round Y: radii `r0`..`r1`, heights `y0`..`y1`, from angle `a0` to
## `a1` (round from +X toward +Z) in `n` steps (the grinder's guard).
static func _heroes_sector(k: MeshKit, r0: float, r1: float, y0: float, y1: float, a0: float, a1: float, n: int) -> void:
	for i in n:
		var aa := lerpf(a0, a1, float(i) / float(n))
		var ab := lerpf(a0, a1, float(i + 1) / float(n))
		var lo := PackedVector3Array()
		var hi := PackedVector3Array()
		for p: Vector2 in [Vector2(r0, aa), Vector2(r1, aa), Vector2(r1, ab), Vector2(r0, ab)]:
			lo.append(Vector3(cos(p.y) * p.x, y0, sin(p.y) * p.x))
			hi.append(Vector3(cos(p.y) * p.x, y1, sin(p.y) * p.x))
		k.loft(lo, hi)


## An open lattice rail along X (the yellow frame down the courier's pontoon sides):
## `length` long, `height` tall, top and bottom chords (channels open to the front) and
## posts in the material colour, a bolted gusset plate over each post's ends, a galvanised
## diagonal brace per bay, standing off a wall on galvanised brackets `standoff` deep that
## end in bolted wall plates; blackened bolts. Its face is -Z, its brackets reach back to +Z.
static func lattice_rail(length: float, height: float, bays: int = 4, depth: float = 0.16,
		standoff: float = 0.22) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hy := height * 0.5
	var hl := length * 0.5
	var zf := -(depth + standoff) * 0.5 + depth * 0.5   # the frame's middle (z)
	var front := zf - depth * 0.5
	var back := (depth + standoff) * 0.5
	var chord := 0.14
	# Chords: channels, a flange top and bottom and a web at the back, open toward -Z.
	var ft := 0.03
	var wt := depth * 0.3
	for sy: float in [-1.0, 1.0]:
		var yc := sy * (hy - chord * 0.5)
		k.box(Vector3(length, ft, depth), Vector3(0.0, yc + chord * 0.5 - ft * 0.5, zf))
		k.box(Vector3(length, ft, depth), Vector3(0.0, yc - chord * 0.5 + ft * 0.5, zf))
		k.box(Vector3(length - 0.004, chord - ft * 2.0, wt), Vector3(0.0, yc, zf + depth * 0.5 - wt * 0.5 - 0.002))
	var cell := length / float(bays)
	var gw := minf(0.24, cell * 0.4)               # gusset width, m
	var gh := minf(chord + 0.1, height * 0.4)      # gusset height, m
	var stud := PackedVector3Array()               # gusset bolt centres, on the plate's face
	for i in bays + 1:
		var x := -hl + cell * float(i)
		x = clampf(x, -hl + 0.06, hl - 0.06)
		k.color = Color.WHITE
		k.box(Vector3(0.12, height - 2.0 * chord, depth * 0.85), Vector3(x, 0.0, zf))
		# The gusset plates over the post's ends.
		var gx := clampf(x, -hl + gw * 0.5, hl - gw * 0.5)
		for sy: float in [-1.0, 1.0]:
			var gy := sy * (hy - gh * 0.5)
			k.box(Vector3(gw, gh, 0.012), Vector3(gx, gy, front - 0.006))
			for sx: float in [-1.0, 1.0]:
				stud.append(Vector3(gx + sx * gw * 0.28, gy - sy * gh * 0.12, front - 0.014))
		# Stand-off brackets top and bottom, each ending in a wall plate.
		k.color = GALVANISED
		for sy: float in [-1.0, 1.0]:
			var y := sy * (hy - chord * 0.5)
			var z0 := zf + depth * 0.5
			var z1 := back - 0.015
			k.box(Vector3(0.1, 0.09, z1 - z0), Vector3(x, y, (z0 + z1) * 0.5))
			var px := clampf(x, -hl + 0.08, hl - 0.08)
			k.box(Vector3(0.16, 0.14, 0.015), Vector3(px, y, back - 0.0075))
			for sb: float in [-1.0, 1.0]:
				stud.append(Vector3(px, y + sb * 0.058, back - 0.017))
	# Bolt heads: small squares standing just proud of the plates they hold.
	k.color = FLANGE_BOLT
	for c in stud:
		var e := 0.011
		k.quad(c + Vector3(-e, -e, 0), c + Vector3(e, -e, 0), c + Vector3(e, e, 0), c + Vector3(-e, e, 0), Vector3.FORWARD)
	k.color = WALK_CROSS_BAR
	for i in bays:
		var x0 := -hl + cell * float(i) + 0.1
		var x1 := x0 + cell - 0.2
		var flip := i % 2 == 0
		var a := Vector3(x0, -hy + chord, zf) if flip else Vector3(x0, hy - chord, zf)
		var b := Vector3(x1, hy - chord, zf) if flip else Vector3(x1, -hy + chord, zf)
		k.strut(a, b, 0.07)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * height * depth * 0.3
	var col := BoxShape3D.new()
	col.size = Vector3(length, height, depth + standoff)
	shape.collision = col
	return shape


## A pack of `count` white gas canisters side by side along X (the courier's oxygen pack
## on its flank), `cell` apart: each a round cylinder in the material colour standing on a
## dark foot ring, its chamfered base and domed shoulder narrowing to a steel neck with a
## valve block, an outlet stub toward -Z and a dark handwheel on top, a dark strap round
## it held back to the plate, and a pale label on its front. All on a dark back plate
## with steel rails top and bottom and a steel retaining bar across the front on dark end
## brackets. Back +Z (against the hull), face -Z.
static func canister_pack(count: int = 3, cell: float = 0.45, height: float = 0.9, depth: float = 0.45) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var width := cell * float(count)
	var hh := height * 0.5
	var hd := depth * 0.5
	var plate := 0.05
	var n := 10
	# The back plate and its rails.
	k.color = DARK
	k.box(Vector3(width, height, plate), Vector3(0.0, 0.0, hd - plate * 0.5))
	k.color = DETAIL
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(width - 0.02, 0.05, 0.02), Vector3(0.0, sy * (hh - 0.06), hd - plate - 0.01))
	# The retaining bar across the front, its end brackets back to the plate.
	var bar := 0.03
	var bz := -hd - 0.015 + bar * 0.5
	var by := -hh + height * 0.42
	k.box(Vector3(width - 0.01, bar, bar), Vector3(0.0, by, bz))
	k.color = DARK
	for sx: float in [-1.0, 1.0]:
		var z0 := bz + bar * 0.5
		var z1 := hd - plate
		k.box(Vector3(0.03, 0.06, z1 - z0), Vector3(sx * (width * 0.5 - 0.02), by, (z0 + z1) * 0.5))
	# The canisters, standing between the plate and the bar.
	var z_back := hd - plate - 0.01
	var z_front := bz + bar * 0.5 + 0.005
	var r := minf(cell * 0.5 - 0.03, (z_back - z_front) * 0.5)
	var zc := (z_back + z_front) * 0.5
	var y_foot := -hh + 0.04
	var y_shoulder := hh - 0.2
	var y_neck := hh - 0.11
	var y_strap := -hh + height * 0.66
	for i in count:
		var c := Vector3(-width * 0.5 + cell * (float(i) + 0.5), 0.0, zc)
		k.color = DARK
		k.loft(_stowage_ring(c + Vector3(0, -hh, 0), r * 0.9, n), _stowage_ring(c + Vector3(0, y_foot, 0), r * 0.9, n))
		k.color = Color.WHITE
		var rings: Array[PackedVector3Array] = [
				_stowage_ring(c + Vector3(0, y_foot, 0), r * 0.92, n),
				_stowage_ring(c + Vector3(0, y_foot + 0.03, 0), r, n),
				_stowage_ring(c + Vector3(0, y_shoulder, 0), r, n),
				_stowage_ring(c + Vector3(0, y_neck - 0.02, 0), r * 0.6, n),
				_stowage_ring(c + Vector3(0, y_neck, 0), r * 0.28, n)]
		for j in rings.size() - 1:
			k.loft(rings[j], rings[j + 1], false)
		k.poly(rings[rings.size() - 1], Vector3.UP)
		# The strap round it, a tab back to the plate.
		k.color = DARK
		k.loft(_stowage_ring(c + Vector3(0, y_strap - 0.025, 0), r + 0.008, n),
				_stowage_ring(c + Vector3(0, y_strap + 0.025, 0), r + 0.008, n))
		k.box(Vector3(0.05, 0.05, z_back - zc - r * 0.6), Vector3(c.x, y_strap, (z_back + zc + r * 0.6) * 0.5))
		# The neck, the valve with its outlet, the handwheel.
		k.color = DETAIL
		var vs := r * 0.42
		k.box(Vector3(r * 0.3, 0.035, r * 0.3), Vector3(c.x, y_neck + 0.0175, zc))
		k.box(Vector3(vs, 0.045, vs), Vector3(c.x, y_neck + 0.035 + 0.0225, zc))
		k.box(Vector3(0.04, 0.035, r * 0.35), Vector3(c.x, y_neck + 0.06, zc - vs * 0.5 - r * 0.175))
		k.box(Vector3(0.015, 0.018, 0.015), Vector3(c.x, hh - 0.021, zc))
		k.color = DARK
		k.box(Vector3(r * 0.75, 0.012, 0.03), Vector3(c.x, hh - 0.006, zc))
		k.box(Vector3(0.03, 0.012, r * 0.75), Vector3(c.x, hh - 0.006, zc))
		# The label on its front facet.
		k.color = PLATE
		var fz := zc - r * cos(PI / float(n))
		k.box(Vector3(r * 0.5, 0.12, 0.006), Vector3(c.x, -hh + height * 0.25, fz - 0.002))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * depth * 0.3
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth + 0.04)
	shape.collision = col
	return shape


# --- Cargo runner parts (0.35) ----------------------------------------------------------

## A bank of black radiator fins (the cargo runner's flanks, SE2 heat vents): `fins` thin
## vertical fins `height` tall standing `depth` off a back plate, spaced along X, each with
## its outer top corner cut off and a steel lip down its outer edge; a copper coolant header
## through the fins' feet and another through their roots under the top, flanged at both
## ends and joined by a riser at each end; a dark back plate with a bevelled face and a bolt
## in each corner. Back +Z (against the hull), fins toward -Z. Fins take the material
## colour (dark in the reference).
static func heat_sink(fins: int = 6, height: float = 1.0, depth: float = 0.32, pitch: float = 0.14) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var width := pitch * float(fins) + 0.06
	var hw := width * 0.5
	var hy := height * 0.5
	var plate := 0.04
	var zp := depth * 0.5 - plate          # the plate's front face (z)
	# The back plate: a slab whose front face is bevelled in all round.
	k.color = DARK
	var bev := 0.01
	k.loft(PackedVector3Array([Vector3(-hw, -hy, depth * 0.5), Vector3(hw, -hy, depth * 0.5), Vector3(hw, hy, depth * 0.5),
			Vector3(-hw, hy, depth * 0.5)]), PackedVector3Array([Vector3(-hw + bev, -hy + bev, zp), Vector3(hw - bev, -hy + bev, zp),
			Vector3(hw - bev, hy - bev, zp), Vector3(-hw + bev, hy - bev, zp)]))
	# The fins, their roots sunk a hair into the plate.
	k.color = Color.WHITE
	var fin_d := depth - plate + 0.002
	var zf := -depth * 0.5 + fin_d * 0.5   # the fins' middle (z)
	var cut := fin_d * 0.55                # how far down the outer edge the top cut runs
	var fin_x: Array[float] = []
	for i in fins:
		var x := -hw + 0.03 + pitch * (float(i) + 0.5)
		fin_x.append(x)
		# A fin: a slab with its outer top corner cut off (outline in z, y).
		var outline := PackedVector2Array([Vector2(-fin_d * 0.5, -hy), Vector2(fin_d * 0.5, -hy),
				Vector2(fin_d * 0.5, hy), Vector2(-fin_d * 0.5 + fin_d * 0.45, hy),
				Vector2(-fin_d * 0.5, hy - cut)])
		var shifted := PackedVector2Array()
		for p in outline:
			shifted.append(Vector2(p.x + zf, p.y))
		_prism_x(k, shifted, x - 0.02, x + 0.02)
	# A steel lip down each fin's outer edge, standing a hair proud of it.
	k.color = DETAIL
	for x in fin_x:
		k.box(Vector3(0.05, height - cut - 0.004, 0.022), Vector3(x, -cut * 0.5 + 0.002, -depth * 0.5 + 0.007))
	# The coolant headers: copper pipes along X through the fins' feet (outer) and their roots
	# under the top (inner), a flange collar at each end and a riser joining them at each end.
	var rr := clampf(pitch * 0.22, 0.025, 0.04)
	var yh := maxf(0.05, height * 0.1)
	var lo := Vector3(0.0, -hy + yh, -depth * 0.5 + fin_d * 0.35)
	var hi := Vector3(0.0, hy - yh, zp - rr - 0.02)
	k.color = COPPER
	for p: Vector3 in [lo, hi]:
		_tube(k, Vector3(-hw + 0.012, p.y, p.z), Vector3(hw - 0.012, p.y, p.z), rr)
	for sx: float in [-1.0, 1.0]:
		var xe := sx * (hw - 0.017)
		_tube(k, Vector3(xe, lo.y, lo.z), Vector3(xe, hi.y, hi.z), rr * 0.7, 8)
	k.color = DETAIL
	for p: Vector3 in [lo, hi]:
		for sx: float in [-1.0, 1.0]:
			_tube(k, Vector3(sx * (hw - 0.034), p.y, p.z), Vector3(sx * (hw - 0.006), p.y, p.z), rr * 1.35)
	# A bolt in each corner of the plate.
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			k.box(Vector3(0.022, 0.022, 0.012), Vector3(sx * (hw - 0.024), sy * (hy - 0.024), zp - 0.004))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * depth * 0.25
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth)
	shape.collision = col
	return shape


## A cluster of `count` small round thruster nozzles side by side along X on a mount
## block (the cargo runner's pod-side thrusters): a chamfered block in the material colour
## with steel end plates and bolts along its -Z edge, a fuel manifold along its +Z edge with
## a clamped feed into each nozzle; each nozzle a dark flange, a flared steel barrel and a
## pale rim round a ceramic throat down to a glowing floor (PartShape.glow), exhausting
## toward +Y. Mount face -Y.
static func nozzle_cluster(count: int = 3, radius: float = 0.15, length: float = 0.4,
		glow := Color(0.4, 0.7, 1.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var r := radius
	var pitch := r * 2.3
	var width := pitch * float(count)
	var block := 0.16
	var y0 := -length * 0.5
	var y_b := y0 + block                        # the block's top, m
	var hz := r * 1.3
	var c := minf(block * 0.35, r * 0.3)         # top edge chamfer, m
	var i := 0.006                               # the block sits in this far from its end plates, m
	var end := clampf(r * 0.2, 0.02, 0.05)       # end plates, m
	k.color = Color.WHITE
	_prism_x(k, PackedVector2Array([Vector2(-hz + i, y0), Vector2(hz - i, y0), Vector2(hz - i, y_b - c),
			Vector2(hz - c, y_b - i), Vector2(-hz + c, y_b - i), Vector2(-hz + i, y_b - c)]), -width * 0.5 + end, width * 0.5 - end)
	k.color = DETAIL
	var plate := PackedVector2Array([Vector2(-hz, y0), Vector2(hz, y0), Vector2(hz, y_b - c), Vector2(hz - c, y_b),
			Vector2(-hz + c, y_b), Vector2(-hz, y_b - c)])
	_prism_x(k, plate, -width * 0.5, -width * 0.5 + end)
	_prism_x(k, plate, width * 0.5 - end, width * 0.5)
	# Bolts along the -Z edge of the top, between the nozzles and at the ends.
	var bolt := clampf(r * 0.08, 0.008, 0.02)
	for j in count + 1:
		var x := clampf(-width * 0.5 + pitch * float(j), -width * 0.5 + end + bolt * 1.5, width * 0.5 - end - bolt * 1.5)
		_thrusters_bolt(k, Vector3(x, y_b - i, -r * 0.92), bolt, bolt * 0.6)
	# The fuel manifold along the +Z edge, a clamped feed from it into each nozzle.
	var pr := clampf(r * 0.12, 0.012, 0.03)
	var pz := hz - pr - 0.012
	var py := y_b - i + pr
	_tube(k, Vector3(-width * 0.5 + end, py, pz), Vector3(width * 0.5 - end, py, pz), pr, 8)
	var y_top := length * 0.5
	var y_floor := y_b + (y_top - y_b) * 0.12
	for j in count:
		var x := -width * 0.5 + pitch * (float(j) + 0.5)
		k.color = DETAIL
		_tube(k, Vector3(x, py, pz), Vector3(x, py, r * 0.6), pr * 0.8, 8)
		k.color = DARK
		_tube(k, Vector3(x - pr * 1.4, py, pz), Vector3(x + pr * 1.4, py, pz), pr * 1.35, 8)
		_engines_nozzle(k, g, Vector3(x, 0.0, 0.0), r, y_b - 0.012, y_b + (y_top - y_b) * 0.14, y_top, y_floor, 14,
				[RIM, DETAIL, TRIM] as Array[Color], Vector3(0.82, 0.72, 0.9), false)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * radius * 2.6 * block + PI * radius * radius * length * 0.3 * float(count)
	var col := BoxShape3D.new()
	col.size = Vector3(width, length, radius * 2.6)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A straight SE2 conveyor tube along Y, `length` long and `size` square: a body in the
## material colour (yellow in the reference: "all conveyors are coloured yellow"), dark
## anodised rails down its corners, a cast collar flange at each end with a galvanised clamp
## band inboard of it, access panels down every face (galvanised screws on +-X) and a dark
## stencilled flow arrow toward +Y on each +-X panel. Short tubes keep the collars and arrows.
static func conveyor_tube(length: float, size: float = 0.34) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var flange := 0.06
	var hs := size * 0.5
	var inner := length - 2.0 * flange
	k.box(Vector3(size, inner, size))
	k.color = RAIL_DARK
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.05, inner, 0.05), Vector3(sx * hs, 0.0, sz * hs))
	k.color = CAST
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(size + 0.06, flange, size + 0.06), Vector3(0.0, sy * (length * 0.5 - flange * 0.5), 0.0))
	# Clamp bands inboard of the collars, a bolt head in the middle of each face.
	var band := 0.045 if inner > 0.2 else 0.0
	if band > 0.0:
		for sy: float in [-1.0, 1.0]:
			var y := sy * (length * 0.5 - flange - band * 0.5)
			k.color = GALVANISED
			k.box(Vector3(size + 0.03, band, size + 0.03), Vector3(0.0, y, 0.0))
			k.color = FLANGE_BOLT
			for s: float in [-1.0, 1.0]:
				k.box(Vector3(0.012, 0.024, 0.024), Vector3(s * (hs + 0.021), y, 0.0))
				k.box(Vector3(0.024, 0.024, 0.012), Vector3(0.0, y, s * (hs + 0.021)))
	# Access panels down the faces between the clamp bands, each +-X one bolted at its
	# corners and marked with a flow arrow.
	var avail := inner - 2.0 * band - 0.16
	var pw := size - 0.11
	var arrows: Array[float] = []
	var plen := 0.0
	if avail > 0.3:
		var n := clampi(int(avail / 1.4) + 1, 1, 4)
		var pitch := avail / float(n)
		plen = minf(pitch - 0.12, 1.0)
		for i in n:
			var y := -avail * 0.5 + pitch * (float(i) + 0.5)
			arrows.append(y)
			k.color = Color.WHITE
			for s: float in [-1.0, 1.0]:
				k.box(Vector3(0.008, plen, pw), Vector3(s * (hs + 0.004), y, 0.0))
				k.box(Vector3(pw, plen, 0.008), Vector3(0.0, y, s * (hs + 0.004)))
			k.color = GALVANISED
			for s: float in [-1.0, 1.0]:
				for by: float in [-1.0, 1.0]:
					for bz: float in [-1.0, 1.0]:
						k.box(Vector3(0.01, 0.022, 0.022), Vector3(s * (hs + 0.013), y + by * (plen * 0.5 - 0.035),
								bz * (pw * 0.5 - 0.035)))
	elif inner > 0.2:
		arrows.append(0.0)
		plen = minf(inner - 2.0 * band - 0.04, 0.4)
	# The arrows: a shaft and a head pointing +Y, flat on the panel (or the body).
	k.color = DARK
	var face := hs + (0.0105 if avail > 0.3 else 0.003)
	var al := minf(plen * 0.6, 0.36)
	var hw := minf(pw * 0.45, 0.11)
	var head := minf(al * 0.4, 0.09)
	for y: float in arrows:
		for s: float in [-1.0, 1.0]:
			var x := s * face
			var y0 := y - al * 0.5
			var yh := y + al * 0.5 - head
			var sw := hw * 0.32
			k.poly(PackedVector3Array([Vector3(x, y0, -sw), Vector3(x, y0, sw), Vector3(x, yh, sw), Vector3(x, yh, -sw)]),
					Vector3(s, 0.0, 0.0))
			k.tri(Vector3(x, yh, -hw), Vector3(x, yh, hw), Vector3(x, y + al * 0.5, 0.0), Vector3(s, 0.0, 0.0))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size * size * length * 0.4
	var col := BoxShape3D.new()
	col.size = Vector3(size + 0.06, length, size + 0.06)
	shape.collision = col
	return shape


## An SE2 conveyor junction: a cube `size` across in the material colour with dark anodised
## edge frames between cast corner blocks, and a port on each of its six faces (tubes butt
## onto them): a cast plate with a galvanised screw at each corner, a yellow ring and a dark
## mouth. A small lit status lamp (glow) in a plastic housing sits in the top front corner of
## each side face (+-X, +-Z).
static func conveyor_junction(size: float = 0.6, glow := Color(0.3, 1.0, 0.45)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hs := size * 0.5
	k.box(Vector3(size - 0.04, size - 0.04, size - 0.04))
	# Dark anodised edge frames run between the cast corner blocks.
	k.color = RAIL_DARK
	var el := size - 0.12
	for a: Vector3 in [Vector3(1, 1, 0), Vector3(1, -1, 0), Vector3(-1, 1, 0), Vector3(-1, -1, 0)]:
		k.box(Vector3(0.05, 0.05, el), Vector3(a.x * (hs - 0.025), a.y * (hs - 0.025), 0.0))
		k.box(Vector3(el, 0.05, 0.05), Vector3(0.0, a.x * (hs - 0.025), a.y * (hs - 0.025)))
		k.box(Vector3(0.05, el, 0.05), Vector3(a.x * (hs - 0.025), 0.0, a.y * (hs - 0.025)))
	k.color = CAST
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				k.box(Vector3(0.07, 0.07, 0.07), Vector3(sx, sy, sz) * (hs - 0.03))
	# The ports: plate (with corner bolts), yellow ring, dark mouth, stepping out to the face.
	var bolt := size * 0.05
	for axis: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var i := axis.abs().max_axis_index()
		var steps: Array = [[CAST, size * 0.62, hs - 0.025, hs - 0.005], [PORT_YELLOW, size * 0.5, hs - 0.01, hs],
				[DARK, size * 0.32, hs - 0.005, hs + 0.006]]
		for st: Array in steps:
			k.color = st[0]
			var w: float = st[1]
			var d0: float = st[2]
			var d1: float = st[3]
			var s := Vector3(w, w, w)
			s[i] = d1 - d0
			k.box(s, axis * (d0 + d1) * 0.5)
		k.color = GALVANISED
		var j := (i + 1) % 3
		var l := (i + 2) % 3
		for sj: float in [-1.0, 1.0]:
			for sl: float in [-1.0, 1.0]:
				var c := axis * hs
				c[j] = sj * size * 0.28
				c[l] = sl * size * 0.28
				var bs := Vector3(bolt, bolt, bolt)
				bs[i] = 0.01
				k.box(bs, c)
	# Status lamp housings near the top front corner of each side face.
	var m := size * 0.405 - 0.025
	var hb := minf(0.04, (size * 0.19 - 0.05) * 0.8)
	var lamps: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	k.color = PLASTIC_DARK
	for n: Vector3 in lamps:
		var side := Vector3.FORWARD if n.x != 0.0 else Vector3.RIGHT
		var c := n * (hs - 0.009) + Vector3(0.0, m, 0.0) + side * m
		var s := Vector3(hb, hb, hb)
		s[n.abs().max_axis_index()] = 0.022
		k.box(s, c)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size * size * size * 0.5
	var col := BoxShape3D.new()
	col.size = Vector3(size + 0.01, size + 0.01, size + 0.01)
	shape.collision = col
	var g := MeshKit.new()
	for n: Vector3 in lamps:
		var side := Vector3.FORWARD if n.x != 0.0 else Vector3.RIGHT
		var c := n * (hs + 0.004) + Vector3(0.0, m, 0.0) + side * m
		var s := Vector3(hb * 0.55, hb * 0.55, hb * 0.55)
		s[n.abs().max_axis_index()] = 0.006
		g.box(s, c)
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## An SE2 gyroscope `size` across (stands on -Y): a gunmetal open frame cube, a solid base
## plate and an open top of rails with a cross beam, cast iron corner castings with stainless
## bolts on its eight corners, cast bearing housings top and bottom on a chrome axle, and a
## drum in the material colour on it with polished end caps, a brushed steel centre band and
## two lit rings round it (the glow, with a status lamp in a plastic bezel on the base's -Z
## edge).
static func gyroscope(size: float = 1.0, glow := Color(0.3, 0.75, 1.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hs := size * 0.5
	var bar := size * 0.08
	var r := size * 0.32                       # drum radius, m
	var dh := r * 0.75                         # drum half height, m
	# Frame: base plate, four posts, top rails and a cross beam along X.
	k.color = ENG_FRAME
	k.box(Vector3(size, bar, size), Vector3(0.0, -hs + bar * 0.5, 0.0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(bar, size - 2.0 * bar, bar), Vector3(sx * (hs - bar * 0.5), 0.0, sz * (hs - bar * 0.5)))
		k.box(Vector3(size, bar, bar), Vector3(0.0, hs - bar * 0.5, sx * (hs - bar * 0.5)))
		k.box(Vector3(bar, bar, size - 2.0 * bar), Vector3(sx * (hs - bar * 0.5), hs - bar * 0.5, 0.0))
	k.box(Vector3(size - 2.0 * bar, bar * 0.8, bar * 1.2), Vector3(0.0, hs - bar * 0.4 - 0.004, 0.0))
	# Corner castings, a little proud of the frame, each with a bolt on its two outer faces.
	var cc := bar * 1.35
	var co := hs - cc * 0.5 + 0.004
	var bs := bar * 0.35
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var at := Vector3(sx * co, sy * (hs - cc * 0.5) + maxf(sy, 0.0) * 0.004, sz * co)
				k.color = BOSS
				k.box(Vector3(cc, cc, cc), at)
				k.color = STAINLESS
				k.box(Vector3(0.006, bs, bs), Vector3(sx * (co + cc * 0.5 + 0.003), at.y, at.z - sz * cc * 0.12))
				k.box(Vector3(bs, bs, 0.006), Vector3(at.x - sx * cc * 0.12, at.y, sz * (co + cc * 0.5 + 0.003)))
	# Bearing housings on the base and under the beam, a bright axle between them.
	var yb0 := -hs + bar
	var yt0 := hs - bar * 0.8 - 0.004
	k.color = BOSS
	_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(0.0, yb0), Vector2(r * 0.42, yb0),
			Vector2(r * 0.42, yb0 + bar * 0.4), Vector2(r * 0.26, yb0 + bar * 0.8), Vector2(0.0, yb0 + bar * 0.8)]),
			[BOSS], 14)
	_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(0.0, yt0 - bar * 0.8),
			Vector2(r * 0.26, yt0 - bar * 0.8), Vector2(r * 0.42, yt0 - bar * 0.4), Vector2(r * 0.42, yt0),
			Vector2(0.0, yt0)]), [BOSS], 14)
	k.color = CHROME
	_tube(k, Vector3(0.0, yb0 + bar * 0.8, 0.0), Vector3(0.0, yt0 - bar * 0.8, 0.0), r * 0.1, 8)
	# The drum: material body with chamfered shoulders, bright end caps, a steel centre band.
	_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(0.0, -dh), Vector2(r * 0.78, -dh),
			Vector2(r, -dh + r * 0.22), Vector2(r, dh - r * 0.22), Vector2(r * 0.78, dh), Vector2(0.0, dh)]),
			[Color.WHITE], 20)
	k.color = TRIM
	_thrusters_ring(k, 0.0, r * 0.5, dh - 0.002, dh + 0.008, 16)
	_thrusters_ring(k, 0.0, r * 0.5, -dh - 0.008, -dh + 0.002, 16)
	k.color = COLLAR
	_thrusters_ring(k, r * 0.9, r + 0.012, -r * 0.09, r * 0.09, 20)
	# Status lamp bezel on the base's front edge.
	var led := clampf(bar * 0.4, 0.012, 0.03)
	k.color = PLASTIC_DARK
	k.box(Vector3(led * 3.0, bar * 0.7, 0.006), Vector3(0.0, -hs + bar * 0.5, -hs - 0.003))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size * size * size * 0.3
	var col := BoxShape3D.new()
	col.size = Vector3(size, size, size)
	shape.collision = col
	# The glow: two thin rings standing proud of the drum, and the lamp.
	var g := MeshKit.new()
	for y: float in [-r * 0.32, r * 0.32]:
		_thrusters_ring(g, r * 0.98, r + 0.016, y - 0.018, y + 0.018, 20)
	g.box(Vector3(led, led, 0.004), Vector3(0.0, -hs + bar * 0.5, -hs - 0.008))
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


# --- Executive shuttle parts (0.36) ------------------------------------------------------

## An SE2 control panel bank (the executive shuttle's cockpit ceiling and engineering
## walls): a white housing `width` x `height`, `depth` deep with chamfered front edges and
## a screw in each corner, a dark chamfered face carrying `cols` x `rows` chamfered button
## caps, each in a lit ring with a pale label tab over it, and a column of small screens in
## bezels at its right end with lit readout bars. `glow` lights the rings and readouts.
## Face -Z, back +Z (bolt that to a wall or hang it from a frame).
static func button_panel(width: float = 1.4, height: float = 0.5, cols: int = 4, rows: int = 2,
		depth: float = 0.18, glow := Color(0.75, 1.0, 0.2)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hx := width * 0.5
	var hy := height * 0.5
	var hz := depth * 0.5
	var ch := minf(0.015, depth * 0.1)   # housing chamfer, m
	k.color = Color.WHITE
	k.box(Vector3(width, height, depth - ch), Vector3(0.0, 0.0, ch * 0.5))
	_cabinets_pad(k, Vector3(0.0, 0.0, -hz + ch), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, hx, hy, ch, ch)
	# The dark face, set 2 cm proud of the housing's front with a white rim round it.
	var screen_w := minf(0.16, width * 0.14)
	var face_w := width - 0.08
	var face_h := height - 0.08
	var ff := -hz - 0.02                  # the face's front, z
	k.color = DARK
	_cabinets_pad(k, Vector3(0.0, 0.0, -hz), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, face_w * 0.5, face_h * 0.5, 0.02, 0.008)
	k.color = TRIM
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		k.box(Vector3(0.016, 0.016, 0.006), Vector3(c.x * (hx - 0.022), c.y * (hy - 0.022), -hz - 0.002))
	# Button caps with a label tab over each, and the screens' bezels at the right end.
	var grid_w := face_w - screen_w - 0.06
	var pitch_x := grid_w / float(cols)
	var pitch_y := face_h / float(rows)
	var r := minf(pitch_x, pitch_y) * 0.3
	var g := MeshKit.new()
	for i in cols:
		for j in rows:
			var c := Vector3(-face_w * 0.5 + pitch_x * (float(i) + 0.5), -face_h * 0.5 + pitch_y * (float(j) + 0.5), ff)
			k.color = DETAIL
			_cabinets_pad(k, c, Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, r * 0.55, r * 0.55, 0.02, r * 0.15)
			k.color = PLATE
			var lt := c + Vector3(0.0, r * 1.25, -0.0015)
			k.quad(lt + Vector3(-r * 0.6, -0.008, 0.0), lt + Vector3(r * 0.6, -0.008, 0.0), lt + Vector3(r * 0.6, 0.008, 0.0),
					lt + Vector3(-r * 0.6, 0.008, 0.0), Vector3.FORWARD)
			# The lit ring round the cap, a flat band just proud of the face.
			var rc := c + Vector3(0.0, 0.0, -0.002)
			for s in 8:
				var a0 := TAU * (float(s) + 0.5) / 8.0
				var a1 := TAU * (float(s) + 1.5) / 8.0
				var d0 := Vector3(cos(a0), sin(a0), 0.0)
				var d1 := Vector3(cos(a1), sin(a1), 0.0)
				g.quad(rc + d0 * r * 0.78, rc + d0 * r * 1.05, rc + d1 * r * 1.05, rc + d1 * r * 0.78, Vector3.FORWARD)
	var sx := face_w * 0.5 - screen_w * 0.5 - 0.02
	for j in rows:
		var cy := -face_h * 0.5 + pitch_y * (float(j) + 0.5)
		var sh := pitch_y * 0.55
		k.color = DETAIL
		k.box(Vector3(screen_w + 0.02, sh + 0.02, 0.006), Vector3(sx, cy, ff - 0.003))
		k.color = DARK
		k.box(Vector3(screen_w, sh, 0.004), Vector3(sx, cy, ff - 0.008))
		for b in 3:
			var bw := screen_w * (0.75 - 0.2 * float((b + j) % 3))
			var bc := Vector3(sx - screen_w * 0.5 + 0.015 + bw * 0.5, cy + sh * (0.25 - 0.25 * float(b)), ff - 0.0105)
			g.quad(bc + Vector3(-bw * 0.5, -sh * 0.07, 0.0), bc + Vector3(bw * 0.5, -sh * 0.07, 0.0),
					bc + Vector3(bw * 0.5, sh * 0.07, 0.0), bc + Vector3(-bw * 0.5, sh * 0.07, 0.0), Vector3.FORWARD)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * depth * 0.4
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## An executive double bed (the shuttle's suite) `length` long (along Z) and `width`
## across: a dark plinth set in under a frame in the material colour with two drawers in
## each side, a headboard at +Z with a chamfered top and three upholstered panels, a
## chamfered mattress made up in pale linen, a grey duvet over its foot two thirds with the
## sheet turned down over it and draped over the foot end, a blue throw folded across the
## foot, a blue bolster against the headboard and two pillows. Stands on -Y, head at +Z.
static func double_bed(length: float = 2.1, width: float = 1.6, height: float = 0.95) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := Vector3(width, height, length) * 0.5
	var frame_top := -h.y + 0.38
	var head := 0.12
	var zf := h.z - head                      # the headboard's front face
	var zc := -head * 0.5                     # middle of the frame (along Z)
	var hl := (length - head) * 0.5           # half the frame's length
	var y_frame := -h.y + 0.14                # underside of the frame
	# Plinth (set in), the frame round the mattress.
	k.color = DARK
	k.box(Vector3(width - 0.16, 0.14, length - head - 0.16), Vector3(0.0, -h.y + 0.07, zc))
	k.color = Color.WHITE
	k.box(Vector3(width, frame_top - y_frame, length - head), Vector3(0.0, (y_frame + frame_top) * 0.5, zc))
	# Two drawers in each long side, a dark pull on each.
	var yd := (y_frame + frame_top) * 0.5
	var hd := (frame_top - y_frame) * 0.5 - 0.035
	for sx: float in [-1.0, 1.0]:
		var n := Vector3.RIGHT * sx
		for sz: float in [-1.0, 1.0]:
			var c := Vector3(sx * h.x, yd, zc + sz * hl * 0.48)
			k.color = Color.WHITE
			_seating_pad(k, c, Vector3.BACK, Vector3.UP, n, hl * 0.42, hd, 0.008, 0.004)
			k.color = DARK
			k.box(Vector3(0.008, 0.02, 0.16), c + n * 0.012 + Vector3(0.0, hd * 0.45, 0.0))
	# The headboard: a slab with its front top edge chamfered, three padded panels on it.
	k.color = Color.WHITE
	_prism_x(k, PackedVector2Array([Vector2(zf, -h.y), Vector2(h.z, -h.y), Vector2(h.z, h.y),
			Vector2(zf + 0.05, h.y), Vector2(zf, h.y - 0.05)]), -h.x, h.x)
	k.color = DBED_UPHOLSTERY
	var pw := (width - 0.16) / 3.0
	var p_lo := frame_top + 0.1
	var p_hi := h.y - 0.09
	for i in 3:
		var x := -h.x + 0.08 + pw * (float(i) + 0.5)
		_seating_pad(k, Vector3(x, (p_lo + p_hi) * 0.5, zf), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
				pw * 0.5 - 0.012, (p_hi - p_lo) * 0.5, 0.05, 0.02)
	# Bedding: the mattress, the duvet over the foot with the sheet turned down over its
	# head edge and a drape down the foot end, a throw folded across the foot.
	var y_m := frame_top + 0.18               # top of the mattress
	k.color = DBED_LINEN
	_seating_pad(k, Vector3(0.0, frame_top, zc), Vector3.RIGHT, Vector3.BACK, Vector3.UP, h.x - 0.04, hl - 0.03, 0.18, 0.04)
	var zd0 := zc - hl + 0.02
	var zd1 := zc - hl + 2.0 * hl * 0.6
	k.color = DBED_DUVET
	_seating_pad(k, Vector3(0.0, y_m, (zd0 + zd1) * 0.5), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			h.x - 0.05, (zd1 - zd0) * 0.5, 0.045, 0.015)
	k.box(Vector3(width - 0.1, 0.16, 0.018), Vector3(0.0, y_m - 0.07, -h.z + 0.012))
	k.color = DBED_LINEN
	_seating_pad(k, Vector3(0.0, y_m, zd1), Vector3.RIGHT, Vector3.BACK, Vector3.UP, h.x - 0.05, 0.08, 0.06, 0.022)
	k.color = DBED_THROW
	_seating_pad(k, Vector3(0.0, y_m + 0.045, zd0 + 0.22), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			h.x - 0.03, 0.17, 0.03, 0.008)
	# A bolster against the headboard, two pillows in front of it.
	_tube(k, Vector3(-h.x + 0.14, y_m + 0.075, zf - 0.13), Vector3(h.x - 0.14, y_m + 0.075, zf - 0.13), 0.075, 8)
	k.color = DBED_LINEN
	for sx: float in [-1.0, 1.0]:
		_seating_pad(k, Vector3(sx * width * 0.23, y_m, zf - 0.37), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
				width * 0.2, 0.15, 0.1, 0.04)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * length * (frame_top + h.y) * 0.5
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, length)
	shape.collision = col
	return shape


# --- Yacht parts (0.37) -----------------------------------------------------------------

## A lounge wall unit (the Cascadia's TV wall) `width` x `height`, `depth` deep: a back
## board of chamfered warm wood-panel tiles in two shades inside a steel frame, a big dark
## screen in a chamfered bezel in the middle of its upper half with a faint blue picture
## (glow), a soundbar under it, a speaker column either side with two drivers each, wooden
## floating shelves with books and a vase outboard of them (when there is room), and a low
## dark cabinet along its foot: a set-back plinth, chamfered doors with steel handles under
## a wooden top. Face -Z, back +Z (stand it against a wall).
static func media_wall(width: float = 4.0, height: float = 2.4, depth: float = 0.4) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hx := width * 0.5
	var hy := height * 0.5
	var hz := depth * 0.5
	var board := 0.08
	var zf := hz - board                        # the board's front face
	k.color = MEDIA_WOOD_DARK
	k.box(Vector3(width, height, board), Vector3(0.0, 0.0, hz - board * 0.5))
	# The steel frame round the board's edge.
	var fw := 0.04                              # frame width, m
	k.color = DETAIL
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(width - 0.006, fw, 0.018), Vector3(0.0, sy * (hy - 0.003 - fw * 0.5), zf - 0.009))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(fw, height - 0.006 - 2.0 * fw, 0.018), Vector3(sx * (hx - 0.003 - fw * 0.5), 0.0, zf - 0.009))
	# The screen's place, and what stands round it.
	var sw := width * 0.5
	var sh := height * 0.36
	var sy := hy * 0.25
	var sd := 0.08
	var cab_h := height * 0.2
	var spk_w := width * 0.045                  # speaker column width, m
	var spk_x := sw * 0.5 + 0.06 + spk_w * 0.5
	# Tiles: a grid of chamfered panels inside the frame, alternating shades, none behind
	# the screen, the speakers or the cabinet.
	var ix := hx - 0.003 - fw
	var iy := hy - 0.003 - fw
	var cols := maxi(4, roundi(width / 0.5))
	var rows := maxi(3, roundi(height / 0.6))
	var tw := 2.0 * ix / float(cols)
	var th := 2.0 * iy / float(rows)
	var hide := Rect2(-spk_x - spk_w * 0.5, sy - sh * 0.55, 2.0 * spk_x + spk_w, sh * 1.1)
	for i in cols:
		for j in rows:
			var c := Vector2(-ix + tw * (float(i) + 0.5), -iy + th * (float(j) + 0.5))
			var r := Rect2(c - Vector2(tw, th) * 0.5, Vector2(tw, th))
			if hide.encloses(r) or (absf(c.x) < width * 0.4 and c.y + th * 0.5 < -hy + cab_h + 0.01):
				continue
			k.color = MEDIA_WOOD if (i + j) % 2 == 0 else MEDIA_WOOD_MID
			_seating_pad(k, Vector3(c.x, c.y, zf), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
					tw * 0.5 - 0.015, th * 0.5 - 0.015, 0.012, 0.006)
	# The screen: a chamfered dark bezel standing off the board, the picture on its face.
	k.color = DARK
	_seating_pad(k, Vector3(0.0, sy, zf - 0.004), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
			sw * 0.5, sh * 0.5, sd, 0.015)
	# The soundbar under it: a dark bar with a steel grille strip and end caps.
	var bar_y := sy - sh * 0.5 - 0.1
	var bar_w := sw * 0.7
	k.color = PartShapes.GASKET
	_seating_pad(k, Vector3(0.0, bar_y, zf - 0.004), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
			bar_w * 0.5, 0.035, 0.06, 0.012)
	k.color = DETAIL
	k.box(Vector3(bar_w - 0.08, 0.026, 0.004), Vector3(0.0, bar_y, zf - 0.066))
	k.color = TRIM
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.016, 0.07, 0.06), Vector3(sx * (bar_w * 0.5 + 0.008), bar_y, zf - 0.034))
	# The speaker columns: a dark box with a steel-ringed driver high and low.
	var spk_h := sh * 1.05
	var drv := minf(spk_w * 0.36, 0.07)         # driver radius, m
	for sx: float in [-1.0, 1.0]:
		var x := sx * spk_x
		k.color = PartShapes.GASKET
		_seating_pad(k, Vector3(x, sy, zf - 0.004), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
				spk_w * 0.5, spk_h * 0.5, 0.07, 0.01)
		for dy: float in [-0.25, 0.25]:
			var first := k.verts.size()
			k.color = DETAIL
			k.lathe(PackedVector2Array([Vector2(drv * 0.55, 0.0), Vector2(drv, 0.0), Vector2(drv, 0.008),
					Vector2(drv * 0.75, 0.012)]), 10)
			k.color = DARK
			k.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(drv * 0.6, 0.0), Vector2(drv * 0.25, 0.006),
					Vector2(0.0, 0.012)]), 10)
			_furnish_xform(k, first, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
					Vector3(x, sy + dy * spk_h, zf - 0.072)))
	# Floating shelves outboard of the speakers, with books and a vase.
	var sh0 := spk_x + spk_w * 0.5 + 0.08
	var sh1 := ix - 0.04
	if sh1 - sh0 > 0.2:
		var shelf_d := minf(0.2, depth - board - 0.04)
		var shelf_w := sh1 - sh0
		var spines: Array[Color] = [MEDIA_SPINE, PLATE, MEDIA_WOOD_DARK, TERMINAL_RED]
		for sx: float in [-1.0, 1.0]:
			var x := sx * (sh0 + sh1) * 0.5
			for t: float in [-0.3, 0.3]:
				var y := sy + t * sh
				k.color = MEDIA_WOOD
				k.box(Vector3(shelf_w, 0.03, shelf_d), Vector3(x, y, zf - shelf_d * 0.5 - 0.001))
				# Books along one end, a vase toward the other (mirrored side to side).
				var books := mini(5, int(shelf_w * 0.4 / 0.05))
				for b in books:
					var bh := 0.13 + 0.035 * float((b * 7 + int(t * 10.0) + 9) % 3)
					k.color = spines[b % spines.size()]
					var bx := x - sx * (shelf_w * 0.5 - 0.04 - 0.052 * float(b))
					k.box(Vector3(0.045, bh, shelf_d * 0.7), Vector3(bx, y + 0.015 + bh * 0.5, zf - shelf_d * 0.5))
				var vx := x + sx * (shelf_w * 0.5 - 0.08)
				var first := k.verts.size()
				k.color = PLATE
				k.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.035, 0.0), Vector2(0.05, 0.06),
						Vector2(0.025, 0.14), Vector2(0.032, 0.17), Vector2(0.0, 0.17)]), 8)
				_furnish_xform(k, first, Transform3D(Basis(), Vector3(vx, y + 0.015, zf - shelf_d * 0.5)))
	# The cabinet along the foot: a set-back plinth, a dark carcass, doors and a wooden top.
	var cab_w := width * 0.8
	var cab_d := depth - board - 0.02
	var z_cf := -hz + 0.01                      # the carcass front
	var kick := 0.06
	k.color = DARK
	k.box(Vector3(cab_w - 0.06, kick, cab_d - 0.04), Vector3(0.0, -hy + kick * 0.5, -hz + 0.03 + (cab_d - 0.04) * 0.5))
	k.box(Vector3(cab_w - 0.02, cab_h - kick - 0.03, cab_d - 0.01), Vector3(0.0, -hy + kick + (cab_h - kick - 0.03) * 0.5, z_cf + (cab_d - 0.01) * 0.5))
	k.color = MEDIA_WOOD
	k.box(Vector3(cab_w, 0.03, cab_d), Vector3(0.0, -hy + cab_h - 0.015, -hz + cab_d * 0.5))
	var doors := maxi(2, roundi(cab_w / 0.8))
	var dw := (cab_w - 0.02) / float(doors)
	var dy := -hy + kick + (cab_h - kick - 0.03) * 0.5
	var dh := cab_h - kick - 0.03 - 0.02
	for i in doors:
		var x := -(cab_w - 0.02) * 0.5 + dw * (float(i) + 0.5)
		k.color = MEDIA_CABINET
		_seating_pad(k, Vector3(x, dy, z_cf), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, dw * 0.5 - 0.008, dh * 0.5, 0.008, 0.004)
		k.color = TRIM
		k.box(Vector3(dw * 0.4, 0.014, 0.012), Vector3(x, dy + dh * 0.5 - 0.04, z_cf - 0.008 - 0.006))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * board + width * 0.8 * cab_h * depth * 0.5
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth + 0.01)
	shape.collision = col
	var g := MeshKit.new()
	g.box(Vector3(sw - 0.12, sh - 0.12, 0.004), Vector3(0.0, sy, zf - 0.004 - sd - 0.002))
	shape.glow = g.finish()
	shape.glow_color = Color(0.16, 0.3, 0.52)
	return shape


## Moves the vertices `k` gained since `from` by `t` (a lathed piece built round the origin).
static func _furnish_xform(k: MeshKit, from: int, t: Transform3D) -> void:
	for i in range(from, k.verts.size()):
		k.verts[i] = t * k.verts[i]
		k.normals[i] = (t.basis * k.normals[i]).normalized()


## A galley counter (the Cascadia's kitchen) `length` along X: a carcass in the material
## colour on a dark toe recess, a drawer over a door in each bay (fronts standing proud of
## dark seams, steel bar handles), a grey worktop `height` up with a steel-rimmed dark sink
## and a tap at the -X end and a dark cooktop with four rings and its knobs at the +X end,
## and a back unit rising behind the worktop: a steel range hood over the cooktop with a
## dark filter, a shelf on brackets with canisters, a coffee machine with a small display
## and a bezelled screen between them. The cooktop rings, the screen's readout and the
## machine's display are the glow (`glow`). Front -Z, stands on -Y.
static func galley_counter(length: float = 3.0, height: float = 0.95, depth: float = 0.65,
		glow := Color(1.0, 0.4, 0.15)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var back_h := 1.0                 # back unit above the worktop, m
	var total := height + back_h
	var y0 := -total * 0.5
	var hx := length * 0.5
	var hz := depth * 0.5
	var top_t := 0.05                 # worktop, m
	var toe := 0.1                    # toe recess, m
	var bt := 0.06                    # back panel, m
	var top_y := y0 + height
	var body_h := height - toe - top_t
	var front := -hz + 0.03           # the carcass's front face
	var wall := hz - bt               # the back panel's front face
	# Cupboards on a dark toe recess.
	k.color = DARK
	k.box(Vector3(length - 0.04, toe, depth - 0.1), Vector3(0.0, y0 + toe * 0.5, 0.04))
	k.color = Color.WHITE
	k.box(Vector3(length, body_h, depth - 0.03), Vector3(0.0, y0 + toe + body_h * 0.5, 0.015))
	# A dark layer behind the fronts shows in the seams between them.
	k.color = DARK
	k.box(Vector3(length - 0.016, body_h - 0.006, 0.004), Vector3(0.0, y0 + toe + body_h * 0.5, front - 0.002))
	# A drawer over a door in each bay, 12 mm proud, with bar handles.
	var doors := maxi(2, roundi(length / 0.6))
	var bay := length / float(doors)
	var drawer_h := minf(0.16, body_h * 0.22)
	var y_split := top_y - top_t - drawer_h
	var y_floor := y0 + toe
	for i in doors:
		var x := -hx + bay * (float(i) + 0.5)
		k.color = Color.WHITE
		k.box(Vector3(bay - 0.012, drawer_h - 0.012, 0.012), Vector3(x, y_split + drawer_h * 0.5, front - 0.006))
		k.box(Vector3(bay - 0.012, y_split - y_floor - 0.012, 0.012), Vector3(x, (y_split + y_floor) * 0.5, front - 0.006))
		k.color = TRIM
		k.box(Vector3(minf(0.16, bay * 0.4), 0.018, 0.02), Vector3(x, y_split + drawer_h * 0.5, front - 0.022))
		var side := 1.0 if i % 2 == 0 else -1.0
		k.box(Vector3(0.018, 0.14, 0.02), Vector3(x + side * (bay * 0.5 - 0.06), y_split - 0.12, front - 0.022))
	# The worktop.
	k.color = DETAIL
	k.box(Vector3(length, top_t, depth), Vector3(0.0, top_y - top_t * 0.5, 0.0))
	# The sink at -X: a dark basin in a steel rim, a drain, and the tap behind it.
	var xs := -hx + 0.36
	var sz := -0.03
	var sw := 0.46
	var sd := 0.38
	k.color = DARK
	k.box(Vector3(sw - 0.03, 0.006, sd - 0.03), Vector3(xs, top_y + 0.003, sz))
	k.color = TRIM
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(sw, 0.01, 0.02), Vector3(xs, top_y + 0.005, sz + s * (sd - 0.02) * 0.5))
		k.box(Vector3(0.02, 0.01, sd - 0.04), Vector3(xs + s * (sw - 0.02) * 0.5, top_y + 0.005, sz))
	k.color = DETAIL
	k.box(Vector3(0.05, 0.004, 0.05), Vector3(xs, top_y + 0.007, sz))
	var zt := wall - 0.06
	k.box(Vector3(0.06, 0.012, 0.05), Vector3(xs, top_y + 0.006, zt))
	k.color = TRIM
	_tube(k, Vector3(xs, top_y, zt), Vector3(xs, top_y + 0.3, zt), 0.016, 8)
	_tube(k, Vector3(xs, top_y + 0.285, zt), Vector3(xs, top_y + 0.285, zt - 0.2), 0.012, 8)
	k.box(Vector3(0.028, 0.035, 0.028), Vector3(xs, top_y + 0.265, zt - 0.195))
	k.box(Vector3(0.018, 0.014, 0.08), Vector3(xs + 0.035, top_y + 0.25, zt + 0.01))
	# The cooktop at +X: a dark plate, four knobs in front of it, four lit rings on it.
	var xc := hx - 0.36
	k.color = DARK
	k.box(Vector3(0.5, 0.012, 0.42), Vector3(xc, top_y + 0.006, sz))
	var zk := (-hz + sz - 0.21) * 0.5
	for i in 4:
		k.box(Vector3(0.032, 0.022, 0.032), Vector3(xc - 0.15 + 0.1 * float(i), top_y + 0.011, zk))
	for i in 4:
		var c := Vector3(xc + (0.12 if i % 2 == 0 else -0.12), top_y + 0.0135, sz + (0.1 if i < 2 else -0.1))
		for s in 12:
			var a0 := TAU * float(s) / 12.0
			var a1 := TAU * float(s + 1) / 12.0
			var d0 := Vector3(cos(a0), 0.0, sin(a0))
			var d1 := Vector3(cos(a1), 0.0, sin(a1))
			g.quad(c + d0 * 0.052, c + d1 * 0.052, c + d1 * 0.075, c + d0 * 0.075, Vector3.UP)
	# The back unit: a panel up the back.
	k.color = Color.WHITE
	k.box(Vector3(length, back_h, bt), Vector3(0.0, top_y + back_h * 0.5, hz - bt * 0.5))
	# A steel range hood over the cooktop: a lip, a taper up to the top, a dark filter.
	var y_hood := top_y + 0.64
	k.color = TRIM
	k.box(Vector3(0.6, 0.06, 0.42), Vector3(xc, y_hood + 0.03, wall - 0.21))
	var ha := PackedVector3Array()
	var hb := PackedVector3Array()
	for p: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		ha.append(Vector3(xc + p.x * 0.3, y_hood + 0.06, wall - 0.21 + p.y * 0.21))
		hb.append(Vector3(xc + p.x * 0.24, top_y + back_h - 0.01, wall - 0.1 + p.y * 0.1))
	k.loft(ha, hb)
	k.color = DARK
	k.box(Vector3(0.52, 0.004, 0.34), Vector3(xc, y_hood - 0.002, wall - 0.21))
	# A shelf on two brackets from the -X end to the hood, canisters on it.
	var y_shelf := top_y + 0.72
	var sx0 := -hx + 0.05
	var sx1 := xc - 0.36
	var sl := sx1 - sx0
	k.color = DETAIL
	k.box(Vector3(sl, 0.03, 0.24), Vector3((sx0 + sx1) * 0.5, y_shelf, wall - 0.12))
	for f: float in [0.15, 0.85]:
		var bx := sx0 + sl * f
		k.strut(Vector3(bx, y_shelf - 0.02, wall - 0.14), Vector3(bx, y_shelf - 0.1, wall - 0.006), 0.025)
	var cans := clampi(int(sl / 0.22), 1, 4)
	for i in cans:
		var cx := sx0 + 0.1 + (sl - 0.2) * (float(i) + 0.5) / float(cans)
		var ch := 0.16 + 0.04 * float(i % 2)
		k.color = PLATE if i % 2 == 0 else DETAIL
		_tube(k, Vector3(cx, y_shelf + 0.015, wall - 0.12), Vector3(cx, y_shelf + 0.015 + ch, wall - 0.12), 0.05, 8)
		k.color = DARK
		_tube(k, Vector3(cx, y_shelf + 0.015 + ch, wall - 0.12), Vector3(cx, y_shelf + 0.03 + ch, wall - 0.12), 0.042, 8)
	# Between sink and cooktop: a coffee machine (where there is room) and a screen.
	var gx0 := xs + sw * 0.5 + 0.03
	var gx1 := xc - 0.28
	var gap := gx1 - gx0
	var gc := (gx0 + gx1) * 0.5
	var wide := gap >= 1.0
	var x_screen := gc + (0.25 if wide else 0.0)
	if gap >= 0.4:
		var xm := gc - (0.25 if wide else 0.0)
		var zm := wall - 0.28
		k.color = TRIM
		k.box(Vector3(0.32, 0.34, 0.28), Vector3(xm, top_y + 0.17, wall - 0.14))
		k.color = DARK
		k.box(Vector3(0.16, 0.14, 0.006), Vector3(xm, top_y + 0.13, zm - 0.003))
		_seating_pad(k, Vector3(xm, top_y + 0.27, zm), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, 0.07, 0.03, 0.004)
		k.color = DETAIL
		k.box(Vector3(0.2, 0.02, 0.07), Vector3(xm, top_y + 0.01, zm - 0.03))
		_seating_pad(g, Vector3(xm - 0.015, top_y + 0.27, zm - 0.004), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, 0.04, 0.014, 0.004)
		_seating_pad(g, Vector3(xm + 0.05, top_y + 0.27, zm - 0.004), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, 0.008, 0.008, 0.004)
	# The screen: a steel bezel, a dark face, three lines of readout.
	var y_screen := top_y + 0.48
	k.color = DETAIL
	k.box(Vector3(0.42, 0.24, 0.02), Vector3(x_screen, y_screen, wall - 0.01))
	k.color = DARK
	k.box(Vector3(0.36, 0.18, 0.004), Vector3(x_screen, y_screen, wall - 0.022))
	for j in 3:
		var lw := [0.26, 0.2, 0.14][j] as float
		g.box(Vector3(lw, 0.016, 0.003), Vector3(x_screen - 0.15 + lw * 0.5, y_screen + 0.05 - 0.045 * float(j), wall - 0.0255))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * depth * height * 0.4 + length * back_h * bt
	var col := BoxShape3D.new()
	col.size = Vector3(length, total, depth)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A medical bed (the Cascadia's medical bay) `length` along Z and `width` across: a bolted
## steel floor plate, a tapered column shroud and a dark lift collar under a chamfered frame
## in the material colour with a dark bumper down its sides, a chamfered pale mattress and
## a pillow at the head (+Z), guard rails along the head half; a scanner arch `height` tall
## over its middle on two chamfered posts outside the frame (feet, collars, cable covers, a
## chamfered top bar with a dark emitter channel and a glowing scanner strip under it), and
## a screen in a dark bezel on a jointed post at the head's +X side, lit, facing the bed.
## The posts stand 0.15 m out each side. Stands on -Y.
static func med_bed(length: float = 2.2, width: float = 0.9, height: float = 2.0) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var hy := height * 0.5
	var hz := length * 0.5
	var hw := width * 0.5
	var top := -hy + 0.62
	var y_frame := top - 0.17                 # underside of the frame
	var y_deck := top - 0.05                  # top of the frame (the mattress lies on it)
	# A bolted floor plate, the tapered column shroud, a dark lift collar.
	k.color = DETAIL
	_seating_pad(k, Vector3(0.0, -hy, 0.0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, width * 0.4, length * 0.33, 0.04, 0.015)
	k.color = DARK
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.03, 0.012, 0.03), Vector3(sx * (width * 0.4 - 0.05), -hy + 0.046, sz * (length * 0.33 - 0.05)))
	var lo := PackedVector3Array()
	var hi := PackedVector3Array()
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		lo.append(Vector3(s.x * width * 0.32, -hy + 0.04, s.y * length * 0.27))
		hi.append(Vector3(s.x * width * 0.24, y_frame - 0.04, s.y * length * 0.2))
	k.color = Color.WHITE
	k.loft(lo, hi)
	k.color = DARK
	k.box(Vector3(width * 0.4, 0.04, length * 0.34), Vector3(0.0, y_frame - 0.02, 0.0))
	# The frame with a dark bumper down each side, the mattress and a pillow.
	k.color = Color.WHITE
	_seating_pad(k, Vector3(0.0, y_frame, 0.0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, hw, hz, 0.12, 0.025)
	k.color = DARK
	k.box(Vector3(width + 0.012, 0.03, length - 0.3), Vector3(0.0, y_frame + 0.045, 0.0))
	k.color = MED_PAD
	_seating_pad(k, Vector3(0.0, y_deck, 0.0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, hw - 0.04, hz - 0.05, 0.1, 0.03)
	k.color = MED_LINEN
	_seating_pad(k, Vector3(0.0, top + 0.05, hz - 0.28), Vector3.RIGHT, Vector3.BACK, Vector3.UP, hw - 0.14, 0.15, 0.07, 0.03)
	# Guard rails along the head half, each on two stubs.
	k.color = DETAIL
	var yr := top + 0.2
	for sx: float in [-1.0, 1.0]:
		var x := sx * (hw - 0.02)
		for z: float in [0.18, hz - 0.2]:
			_tube(k, Vector3(x, y_deck, z), Vector3(x, yr, z), 0.012, 6)
		_tube(k, Vector3(x, yr, 0.12), Vector3(x, yr, hz - 0.14), 0.015, 6)
	# The scanner arch: chamfered posts on feet outside the frame, collars, cable covers,
	# a chamfered top bar with a dark emitter channel under it.
	var px := hw + 0.09
	var post := 0.1
	var za := -0.1                            # the arch's plane (z)
	var y_bar := hy - 0.12                    # underside of the top bar
	for sx: float in [-1.0, 1.0]:
		var at := Vector3(sx * px, 0.0, za)
		k.color = DETAIL
		_seating_pad(k, at + Vector3(0.0, -hy, 0.0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, 0.065, 0.18, 0.04, 0.015)
		k.box(Vector3(post + 0.02, 0.04, 0.32), at + Vector3(0.0, -hy + 0.3, 0.0))
		var r0 := PackedVector3Array()
		var r1 := PackedVector3Array()
		for p in PartShapes._chamfer_rect(post, 0.3, 0.025):
			r0.append(at + Vector3(p.x, -hy + 0.04, p.y))
			r1.append(at + Vector3(p.x, y_bar, p.y))
		k.color = Color.WHITE
		k.loft(r0, r1)
		k.color = DARK
		k.box(Vector3(0.006, y_bar - 0.06 - (-hy + 0.36), 0.06), at + Vector3(sx * (post * 0.5 + 0.003), (y_bar - 0.06 - hy + 0.36) * 0.5, 0.0))
	k.color = Color.WHITE
	_prism_x(k, PackedVector2Array([Vector2(za - 0.17, y_bar), Vector2(za + 0.17, y_bar), Vector2(za + 0.17, hy - 0.03),
			Vector2(za + 0.14, hy), Vector2(za - 0.14, hy), Vector2(za - 0.17, hy - 0.03)]), -px - post * 0.5, px + post * 0.5)
	k.color = DARK
	k.box(Vector3(2.0 * px - post - 0.04, 0.02, 0.16), Vector3(0.0, y_bar - 0.01, za))
	g.box(Vector3(2.0 * px - post - 0.1, 0.012, 0.05), Vector3(0.0, y_bar - 0.026, za))
	# The screen at the head: a clamp on the frame, a post with a knuckle, a yoke, a dark
	# bezel facing the bed (-X) and the lit screen in it.
	var xp := hw + 0.085
	var zs := hz - 0.32
	var ys := top + 0.84
	k.color = DETAIL
	k.box(Vector3(0.06, 0.1, 0.08), Vector3(hw + 0.06, y_frame + 0.06, hz - 0.15))
	k.box(Vector3(0.06, 0.06, 0.06), Vector3(xp, top + 0.5, hz - 0.15))
	k.box(Vector3(0.05, 0.08, 0.1), Vector3(hw + 0.07, ys, hz - 0.17))
	k.color = DARK
	_tube(k, Vector3(xp, y_frame + 0.11, hz - 0.15), Vector3(xp, top + 0.47, hz - 0.15), 0.02, 6)
	_tube(k, Vector3(xp, top + 0.53, hz - 0.15), Vector3(xp, ys + 0.04, hz - 0.15), 0.02, 6)
	_seating_pad(k, Vector3(hw + 0.065, ys, zs), Vector3.BACK, Vector3.UP, Vector3.LEFT, 0.21, 0.15, 0.05, 0.012)
	_seating_pad(g, Vector3(hw + 0.016, ys, zs), Vector3.BACK, Vector3.UP, Vector3.LEFT, 0.17, 0.11, 0.004)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * length * 0.6 * 0.3
	var col := BoxShape3D.new()
	col.size = Vector3(2.0 * px + post, height, length)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = Color(0.3, 0.95, 0.9)
	return shape


# --- Armoured transport parts (0.38) ------------------------------------------------------

## A landing thruster that hangs under a belly (the Kyper transport's four round drums
## that are both its feet and its lift engines): a square mount plate with cut corners on
## top (+Y) and bolt heads under it, an upper drum with a dark band, a bolted flange, a
## wider lower drum with a chamfered top and two dark bands, two copper feed pipes from the
## plate down into the upper drum's side (flanged where they enter),
## and a flared heat-blued nozzle underneath with a bright lip, a pale ceramic throat cone
## and a glowing ring (exhaust -Y). `radius` is the lower drum's,
## `height` the whole drum's. The drums take the material colour.
static func hover_drum(radius: float = 0.6, height: float = 1.3, glow := Color(0.85, 0.9, 1.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var plate_t := 0.08
	var plate := radius * 1.3
	var pc := plate * 0.12
	k.color = DARK
	k.loft(_chamfer_ring(plate * 0.5, h - plate_t, pc), _chamfer_ring(plate * 0.5, h, pc))
	k.color = DETAIL
	var bo := plate * 0.5 - pc * 0.5 - 0.04
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_gear_bolt(k, Vector3(sx * bo, h - plate_t, sz * bo), Vector3.DOWN, 0.025, 0.018)
	# Upper drum: narrower, a dark band round its middle (proud by 0.01).
	var up_top := h - plate_t
	var up_bot := h - height * 0.45
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(0.0, up_top + 0.002), Vector2(radius * 0.72, up_top + 0.002), Vector2(radius * 0.72, up_bot),
			Vector2(0.0, up_bot)]), 20)
	k.color = RIM
	var band_y := (up_top + up_bot) * 0.5
	k.lathe(PackedVector2Array([Vector2(radius * 0.715, band_y - 0.05), Vector2(radius * 0.73, band_y - 0.05),
			Vector2(radius * 0.73, band_y + 0.05), Vector2(radius * 0.715, band_y + 0.05)]), 20)
	# A bolted flange where the upper drum meets the lower one.
	var lo_top := up_bot - 0.02
	k.color = DETAIL
	k.lathe(PackedVector2Array([Vector2(radius * 0.66, lo_top - 0.002), Vector2(radius * 0.8, lo_top - 0.002),
			Vector2(radius * 0.8, up_bot + 0.02), Vector2(radius * 0.66, up_bot + 0.02)]), 16)
	for i in 6:
		var a := TAU * (float(i) + 0.5) / 6.0
		_gear_bolt(k, Vector3(cos(a) * radius * 0.765, up_bot + 0.02, sin(a) * radius * 0.765), Vector3.UP, 0.018, 0.014)
	# Lower drum with a chamfered top edge and two dark bands.
	var lo_bot := -h + height * 0.2
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(0.0, lo_top), Vector2(radius * 0.86, lo_top), Vector2(radius, lo_top - 0.1),
			Vector2(radius, lo_bot), Vector2(0.0, lo_bot)]), 24)
	k.color = RIM
	for gy: float in [lo_top - 0.2, lo_bot + 0.12]:
		k.lathe(PackedVector2Array([Vector2(radius - 0.005, gy - 0.03), Vector2(radius + 0.008, gy - 0.03),
				Vector2(radius + 0.008, gy + 0.03), Vector2(radius - 0.005, gy + 0.03)]), 24)
	# The nozzle: a flared skirt with a heat band and a bright lip, a ceramic throat cone.
	k.color = RIM
	k.lathe(PackedVector2Array([Vector2(radius * 0.7, lo_bot + 0.002), Vector2(radius * 0.92, -h + 0.03), Vector2(radius * 0.92, -h + 0.02),
			Vector2(radius * 0.8, -h + 0.02), Vector2(radius * 0.6, lo_bot - 0.02)]), 20)
	k.color = TRIM
	k.lathe(PackedVector2Array([Vector2(radius * 0.79, -h), Vector2(radius * 0.93, -h), Vector2(radius * 0.93, -h + 0.025),
			Vector2(radius * 0.79, -h + 0.025)]), 20)
	k.color = LINER
	k.lathe(PackedVector2Array([Vector2(0.0, lo_bot - 0.01), Vector2(radius * 0.6, lo_bot - 0.01),
			Vector2(radius * 0.25, -h + 0.08), Vector2(0.0, -h + 0.08)]), 16)
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(0.0, -h + 0.075), Vector2(radius * 0.1, -h + 0.075),
			Vector2(radius * 0.1, -h + 0.082), Vector2(0.0, -h + 0.082)]), 8)
	# Two copper feed pipes from the mount plate into the upper drum's side, a flange where
	# each enters the drum.
	var pr := clampf(radius * 0.06, 0.025, 0.04)
	for sx: float in [-1.0, 1.0]:
		var a := Vector3(sx * radius * 0.55, up_top - 0.01, radius * 0.4)
		var m := Vector3(sx * radius * 0.86, up_top - 0.12, radius * 0.25)
		var b := Vector3(sx * radius * 0.86, band_y - 0.12, radius * 0.25)
		var c := Vector3(sx * radius * 0.7, band_y - 0.2, radius * 0.22)
		k.color = COPPER
		_tube(k, a, m, pr, 8)
		_tube(k, m, b, pr, 8)
		_tube(k, b, c, pr, 8)
		k.color = TRIM
		var into := (c - b).normalized()
		_tube(k, c - into * 0.02, c + into * 0.012, pr + 0.018, 8)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * radius * radius * height * 0.35
	var col := CylinderShape3D.new()
	col.radius = radius
	col.height = height
	shape.collision = col
	var g := MeshKit.new()
	g.lathe(PackedVector2Array([Vector2(radius * 0.32, -h + 0.06), Vector2(radius * 0.5, -h + 0.06),
			Vector2(radius * 0.5, -h + 0.075), Vector2(radius * 0.32, -h + 0.075)]), 20)
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A row of `count` padded passenger seats side by side along X, `pitch` apart, on one dark
## floor beam carried by two pedestals on bolted foot plates (the seat's own base): each
## seat a steel shell (pan frame, a back with a narrower head frame, a dark tray panel let
## into its rear and a pale seat-number plate) holding chamfered seat, back and headrest
## cushions in the material colour, and steel armrests with dark pads between and beside
## the seats. Stands on -Y, faces -Z.
static func seat_row(count: int = 3, pitch: float = 0.62, height: float = 1.25, depth: float = 0.7) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var d := depth * 0.5
	var width := pitch * float(count)
	var pan_y := -h + 0.46                      # top of the pan frame, m
	var back_t := 0.06                          # back shell thickness, m
	var arm := 0.06                             # armrest width, m
	var head_h := 0.2                           # headrest height, m
	var zb := d - back_t                        # front of the back shell
	var beam_y := -h + 0.3                      # middle of the floor beam, m
	# The pedestals (plate, post, collar) and the beam across them.
	for sx: float in [-1.0, 1.0]:
		_seating_base(k, Vector3(sx * (width * 0.5 - 0.2), -h, 0.02), 0.12, beam_y - 0.06 + h, 0.09)
	k.color = DARK
	k.box(Vector3(width - 0.1, 0.12, 0.16), Vector3(0.0, beam_y, 0.02))
	for i in count:
		var x := -width * 0.5 + pitch * (float(i) + 0.5)
		var w := pitch - arm - 0.02
		var hw := w * 0.5
		# The shell: pan frame, back, head frame.
		k.color = DETAIL
		k.box(Vector3(w, 0.06, zb + d - 0.02), Vector3(x, pan_y - 0.03, (zb - d + 0.02) * 0.5))
		var y_top := h - head_h
		k.box(Vector3(w, y_top - (pan_y - 0.06), back_t), Vector3(x, (y_top + pan_y - 0.06) * 0.5, d - back_t * 0.5))
		k.box(Vector3(w * 0.62, head_h, back_t), Vector3(x, h - head_h * 0.5, d - back_t * 0.5))
		# The rear: a dark tray panel and a number plate over it.
		k.color = DARK
		k.box(Vector3(w * 0.7, (y_top - pan_y) * 0.5, 0.006), Vector3(x, pan_y + (y_top - pan_y) * 0.42, d + 0.003))
		k.color = PLATE
		k.box(Vector3(0.08, 0.035, 0.006), Vector3(x, y_top - 0.06, d + 0.003))
		# Cushions: pan, back, headrest.
		k.color = Color.WHITE
		_seating_pad(k, Vector3(x, pan_y, (zb - d + 0.02) * 0.5), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
				hw - 0.01, (zb + d - 0.02) * 0.5, 0.08, 0.025)
		var b_lo := pan_y + 0.09
		var b_hi := y_top - 0.03
		_seating_pad(k, Vector3(x, (b_lo + b_hi) * 0.5, zb), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
				hw - 0.02, (b_hi - b_lo) * 0.5, 0.07, 0.025)
		_seating_pad(k, Vector3(x, h - head_h * 0.5, zb), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
				w * 0.31 - 0.025, head_h * 0.5 - 0.03, 0.06, 0.02)
	# Armrests on every seat boundary, ends included: a bar on a post, a dark pad on top.
	var z0 := -d + 0.06
	var z1 := zb - 0.08
	for i in count + 1:
		var x := -width * 0.5 + pitch * float(i)
		x = clampf(x, -width * 0.5 + arm * 0.5, width * 0.5 - arm * 0.5)
		k.color = DETAIL
		k.box(Vector3(arm, 0.04, z1 - z0), Vector3(x, pan_y + 0.2, (z0 + z1) * 0.5))
		k.box(Vector3(arm * 0.6, 0.24, 0.05), Vector3(x, pan_y + 0.06, z0 + 0.04))
		k.color = DARK
		_seating_pad(k, Vector3(x, pan_y + 0.22, (z0 + z1) * 0.5), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
				arm * 0.5 - 0.004, (z1 - z0) * 0.5 - 0.01, 0.025, 0.01)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * (depth * 0.11 + height * 0.07) + 0.02 * float(count)
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth)
	shape.collision = col
	return shape


## A square hall pillar `height` tall and `size` across: a cast foot block with a bolt in
## each corner and an anodised collar chamfering in to the shaft, the same mirrored as the
## capital, the shaft between with chamfered corners in the material colour and a dark
## shadow-gap reveal low down, and down its -Z face a dark plastic lamp housing between
## anodised rails holding a thin lit strip in three segments (the column lights in the Kyper
## transport's passenger hall). Stands on -Y.
static func lit_post(height: float = 2.6, size: float = 0.3, glow := Color(0.45, 1.0, 0.35)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var cap := 0.14
	var foot := 0.07
	var half := size * 0.5
	var wide := half + 0.04
	var c := size * 0.12
	# Cast foot and head blocks, then anodised collars chamfering in to the shaft, steel bolts.
	k.color = CAST
	k.box(Vector3(wide * 2.0, foot, wide * 2.0), Vector3(0.0, -h + foot * 0.5, 0.0))
	k.box(Vector3(wide * 2.0, foot, wide * 2.0), Vector3(0.0, h - foot * 0.5, 0.0))
	k.color = ANODISED
	k.loft(_chamfer_ring(half + 0.025, -h + foot, c), _chamfer_ring(half + 0.01, -h + cap, c))
	k.loft(_chamfer_ring(half + 0.01, h - cap, c), _chamfer_ring(half + 0.025, h - foot, c))
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.025, 0.014, 0.025), Vector3(sx * (wide - 0.022), -h + foot + 0.007, sz * (wide - 0.022)))
	# The shaft, corners chamfered, and a dark reveal round it 0.3 m up.
	k.color = Color.WHITE
	k.loft(_chamfer_ring(half, -h + cap, c), _chamfer_ring(half, h - cap, c), false)
	k.color = DARK
	var ry := -h + cap + 0.3
	k.loft(_chamfer_ring(half + 0.004, ry - 0.012, c), _chamfer_ring(half + 0.004, ry + 0.012, c))
	# The light channel on -Z: a dark plastic housing between two anodised rails, anodised
	# caps at its ends.
	var panel_h := height - 2.0 * cap - 0.4
	var pw := size * 0.6
	var face := -half
	k.color = PLASTIC_DARK
	k.box(Vector3(pw, panel_h, 0.02), Vector3(0.0, 0.0, face - 0.008))
	k.color = ANODISED
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.014, panel_h, 0.026), Vector3(sx * (pw * 0.5 + 0.007), 0.0, face - 0.011))
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(pw + 0.028, 0.02, 0.026), Vector3(0.0, sy * (panel_h * 0.5 + 0.01), face - 0.011))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size * size * height * 0.5
	var col := BoxShape3D.new()
	col.size = Vector3(size + 0.08, height, size + 0.08)
	shape.collision = col
	# The lit strip in three segments with dark gaps between.
	var g := MeshKit.new()
	var seg := panel_h * 0.7 / 3.0
	for i in 3:
		var y := panel_h * 0.35 - seg * (float(i) + 0.5)
		g.box(Vector3(0.04, seg - 0.04, 0.012), Vector3(0.0, y, face - 0.024))
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


# --- Scoop miner parts (0.39) -------------------------------------------------------------

## An SE2 large-grid mining drill (the Scoop's bow, the K1's pods): a chamfered square drive
## housing at -Y on a bolted foot flange, hazard bands round its faces, bolted gearbox
## covers on its X sides, a maker's plate on -Z, two hydraulic hoses up its +X corners into
## the collar and an amber work lamp on its top ledge (PartShape.glow); a round collar
## with a bolted flange and a dark ring of coolant nozzles, and a dark crown tapering to
## +Y wound with two flights and studded with rings of picks (a steel holder, a shank and
## a bright carbide point each) leaning out and forward, a pointed bit at the tip.
## `radius` is the crown's base (the housing is a little wider), `length` the whole part.
## Collision is the hull of the housing, the teeth's tips and the bit.
static func bore_drill(radius: float = 1.0, length: float = 2.4) -> PartShapes.PartShape:
	const TOOTH_LIGHT := Color(0.32, 0.33, 0.35)   # the light picks' shanks and the bit
	var k := MeshKit.new()
	var g := MeshKit.new()
	var y0 := -length * 0.5
	var house := length * 0.3
	var hw := radius * 0.95                       # the foot flange's half width, m
	var hb := hw - 0.035                          # the housing's half width above it, m
	var c := hw * 0.16                            # corner chamfer, m
	var fl := clampf(house * 0.12, 0.05, 0.1)     # foot flange, m
	var c0 := y0 + house
	var bev := 0.03
	# The housing: a foot flange, a chamfered body with a bevel round its top.
	k.loft(_chamfer_ring(hw, y0, c * 1.1), _chamfer_ring(hw, y0 + fl, c * 1.1))
	k.loft(_chamfer_ring(hb, y0 + fl, c), _chamfer_ring(hb, c0 - bev, c))
	k.loft(_chamfer_ring(hb, c0 - bev, c), _chamfer_ring(hb - bev, c0, c), false)
	k.poly(_chamfer_ring(hb - bev, c0, c), Vector3.UP)
	var bolt_r := clampf(radius * 0.022, 0.014, 0.03)
	var bolt_h := bolt_r * 1.1
	var faces: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
	k.color = DETAIL
	for n: Vector3 in faces:
		var u := Vector3(-n.z, 0.0, n.x)
		for i in 4:
			var s := lerpf(-1.0, 1.0, (float(i) + 0.5) / 4.0) * (hb - c)
			_gear_bolt(k, n * (hw - 0.018) + u * s + Vector3(0.0, y0 + fl, 0.0), Vector3.UP, bolt_r, bolt_h)
	# Hazard bands low on every face, a bolted gearbox cover over them on the X sides and
	# a maker's plate on -Z.
	var body_h := c0 - bev - (y0 + fl)
	var band_y := y0 + fl + body_h * 0.22
	var band_h := body_h * 0.2
	var face_w := (hb - c) * 2.0 * 0.92
	for n: Vector3 in faces:
		var u := Vector3(-n.z, 0.0, n.x)
		_gear_hazard(k, n * hb + Vector3(0.0, band_y, 0.0), u, Vector3.UP, n, Vector2(face_w, band_h), band_h * 0.6)
	var cov_y := y0 + fl + body_h * 0.64
	var cov := Vector2(face_w * 0.62, body_h * 0.42)
	for sx: float in [-1.0, 1.0]:
		k.color = DARK
		k.box(Vector3(0.02, cov.y + 0.03, cov.x + 0.03), Vector3(sx * (hb + 0.01), cov_y, 0.0))
		k.color = Color.WHITE
		k.box(Vector3(0.03, cov.y, cov.x), Vector3(sx * (hb + 0.015), cov_y, 0.0))
		k.color = DETAIL
		for cy: float in [-1.0, 1.0]:
			for cz: float in [-1.0, 0.0, 1.0]:
				_gear_bolt(k, Vector3(sx * (hb + 0.03), cov_y + cy * (cov.y * 0.5 - bolt_r * 1.8),
						cz * (cov.x * 0.5 - bolt_r * 1.8)), Vector3(sx, 0.0, 0.0), bolt_r * 0.8, bolt_h * 0.8)
	k.color = PLATE
	k.box(Vector3(face_w * 0.4, body_h * 0.22, 0.012), Vector3(0.0, cov_y, -hb - 0.006))
	k.color = DARK
	for j in 2:
		k.box(Vector3(face_w * (0.3 - 0.1 * float(j)), body_h * 0.035, 0.004),
				Vector3(-face_w * 0.05 * float(j), cov_y + body_h * (0.05 - 0.09 * float(j)), -hb - 0.014))
	# The collar: a bolted flange, a drum, a dark ring of coolant nozzles at its top.
	var collar := length * 0.08
	var rf := radius * 0.9
	var rc := radius * 0.84
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(0.0, c0), Vector2(rf, c0), Vector2(rf, c0 + collar * 0.35), Vector2(0.0, c0 + collar * 0.35)]), 20)
	k.lathe(PackedVector2Array([Vector2(0.0, c0), Vector2(rc, c0), Vector2(rc, c0 + collar), Vector2(0.0, c0 + collar)]), 20)
	k.color = DETAIL
	_piping_bolts(k, Vector3(0.0, c0, 0.0), Vector3.UP, collar * 0.35, 12, (rf + rc) * 0.5, bolt_r * 1.6, bolt_h)
	var b0 := c0 + collar
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(rc * 0.96, b0 - collar * 0.45), Vector2(radius * 0.9, b0 - collar * 0.4),
			Vector2(radius * 0.9, b0 - collar * 0.1), Vector2(rc * 0.96, b0 - collar * 0.05)]), 20)
	k.color = DETAIL
	for i in 10:
		var a := TAU * (float(i) + 0.5) / 10.0
		var out := Vector3(cos(a), 0.0, sin(a))
		k.strut(out * radius * 0.88 + Vector3(0.0, b0 - collar * 0.25, 0.0),
				out * radius * 0.93 + Vector3(0.0, b0 + collar * 0.25, 0.0), maxf(0.02, radius * 0.035))
	# Hydraulic hoses up the +X corners, over the ledge into the collar's side.
	var hr := clampf(radius * 0.03, 0.02, 0.045)
	for sz: float in [-1.0, 1.0]:
		var d := Vector3(1.0, 0.0, sz).normalized()
		var corner := Vector3(hb - c * 0.5, 0.0, sz * (hb - c * 0.5)) + d * (hr + 0.006)
		_drills_hose(k, PackedVector3Array([corner + Vector3(0.0, y0 + fl + hr * 2.0, 0.0),
				corner + Vector3(0.0, c0 - bev - hr, 0.0), d * (rc + hr * 3.0) + Vector3(0.0, c0 + hr * 1.6, 0.0),
				d * (rc - hr * 0.5) + Vector3(0.0, c0 + collar * 0.6, 0.0)]), hr)
	# A work lamp on the top ledge's -X +Z corner, facing the work (+Y).
	var ls := clampf(radius * 0.1, 0.06, 0.13)
	_drills_lamp(k, g, Vector3(-(hb - ls * 1.1), c0, hb - ls * 1.1), Vector3.UP, Vector3(1.0, 0.0, 1.0).normalized(), ls)
	# The crown: a dark cone wound with two flights, picks in rings.
	var tip := length * 0.5
	var top := tip - 0.12
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(0.0, b0), Vector2(radius * 0.88, b0), Vector2(radius * 0.18, top),
			Vector2(0.0, top)]), 16)
	k.color = RIM
	var steps := 14
	for f in 2:
		for i in steps:
			var pts: Array[Vector3] = []
			for e in 2:
				var t := lerpf(0.04, 0.9, float(i + e) / float(steps))
				var a := PI * float(f) + t * TAU * 1.1
				var cr := lerpf(radius * 0.88, radius * 0.18, t)
				pts.append(Vector3(cos(a) * cr, lerpf(b0, top, t), sin(a) * cr))
			var mid := (pts[0] + pts[1]) * 0.5
			var radial := Vector3(mid.x, 0.0, mid.z).normalized()
			_drills_bar(k, pts[0] + radial * radius * 0.012, pts[1] + radial * radius * 0.012, radial,
					radius * 0.045, radius * 0.07)
	var tips := PackedVector3Array()
	var rings := 3
	for r in rings:
		var t := (float(r) + 0.35) / float(rings)
		var y := lerpf(b0, top, t)
		var ring_r := lerpf(radius * 0.88, radius * 0.18, t)
		var n: int = [9, 7, 5][r]
		for i in n:
			var a := TAU * (float(i) + 0.5 * float(r)) / float(n)
			var out := Vector3(cos(a), 0.0, sin(a))
			var base := out * ring_r * 0.92 + Vector3(0.0, y, 0.0)
			var reach := radius * (0.22 - 0.04 * float(r))
			var end := base + out * reach + Vector3(0.0, reach * 0.9, 0.0) + Vector3(-out.z, 0.0, out.x) * reach * 0.35
			_drills_pick(k, base, end, radius * 0.14, TOOTH_LIGHT if i % 2 == 0 else DARK)
			tips.append(end)
	k.color = TOOTH_LIGHT
	k.lathe(PackedVector2Array([Vector2(0.0, top - 0.04), Vector2(radius * 0.14, top - 0.04), Vector2(radius * 0.05, tip - 0.05),
			Vector2(0.0, tip - 0.05)]), 8)
	k.color = TRIM
	k.lathe(PackedVector2Array([Vector2(0.0, tip - 0.05), Vector2(radius * 0.05, tip - 0.05), Vector2(0.0, tip)]), 8)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = hw * hw * 4.0 * house * 0.6 + PI * radius * radius * (tip - b0) * 0.25
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * hw, y0, sz * hw))
			pts.append(Vector3(sx * hw, c0, sz * hw))
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector3(cos(a) * radius * 0.92, b0, sin(a) * radius * 0.92))
	for p in tips:
		pts.append(p)
	pts.append(Vector3(0.0, tip, 0.0))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = GLOWING
	return shape


## A bar from `a` to `b` with a `w` by `h` rectangular section, `h` along `up` (squared to
## the bar), capped: tooth holders, drum flights, lamp housings.
static func _drills_bar(k: MeshKit, a: Vector3, b: Vector3, up: Vector3, w: float, h: float) -> void:
	var y := (b - a).normalized()
	var v := (up - y * up.dot(y)).normalized()
	var u := y.cross(v).normalized()
	var ra := PackedVector3Array([a + u * w * 0.5 + v * h * 0.5, a - u * w * 0.5 + v * h * 0.5,
			a - u * w * 0.5 - v * h * 0.5, a + u * w * 0.5 - v * h * 0.5])
	var rb := PackedVector3Array()
	for p in ra:
		rb.append(p + (b - a))
	k.loft(ra, rb)


## Four corners of a square `half` across round `c`, on axes `x` and `z`.
static func _drills_square(c: Vector3, x: Vector3, z: Vector3, half: float) -> PackedVector3Array:
	return PackedVector3Array([c + (x + z) * half, c + (x - z) * half, c + (-x - z) * half, c + (-x + z) * half])


## A cutting pick from `base` (on the body) to `end`, `w` across: a square steel holder
## (DETAIL) sunk in at the base, a tapering shank in `shank` and a four-sided bright
## carbide point (TRIM) for the last third.
static func _drills_pick(k: MeshKit, base: Vector3, end: Vector3, w: float, shank: Color) -> void:
	var along := end - base
	var l := along.length()
	var y := along / l
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var h1 := base + y * l * 0.2
	var m := base + along * 0.64
	k.color = DETAIL
	k.loft(_drills_square(base - y * w * 0.5, x, z, w * 0.66), _drills_square(h1, x, z, w * 0.66))
	k.color = shank
	k.loft(_drills_square(h1, x, z, w * 0.48), _drills_square(m, x, z, w * 0.4))
	k.color = TRIM
	var sq := _drills_square(m, x, z, w * 0.4)
	for i in 4:
		var p := sq[i]
		var q := sq[(i + 1) % 4]
		k.tri(p, q, end, (p + q) * 0.5 - m + y * w * 0.2)


## A small work lamp standing on a face at `at` and facing `n`, `s` across: a dark housing,
## a bright bezel and a lens (into `g`, the part's glow) 4 mm proud of it. `up` is the
## lamp's long way.
static func _drills_lamp(k: MeshKit, g: MeshKit, at: Vector3, n: Vector3, up: Vector3, s: float) -> void:
	k.color = DARK
	_drills_bar(k, at - n * 0.01, at + n * s * 0.55, up, s * 0.8, s * 1.3)
	k.color = TRIM
	_drills_bar(k, at + n * s * 0.55, at + n * s * 0.65, up, s * 0.9, s * 1.4)
	_drills_bar(g, at + n * s * 0.6, at + n * (s * 0.65 + 0.004), up, s * 0.62, s * 1.1)


## A hydraulic hose through `pts`: dark rubber runs, a steel fitting at each end and bend.
static func _drills_hose(k: MeshKit, pts: PackedVector3Array, r: float) -> void:
	k.color = DARK
	for i in pts.size() - 1:
		_tube(k, pts[i], pts[i + 1], r, 8)
	k.color = DETAIL
	var last := pts.size() - 1
	for i in pts.size():
		var d: Vector3
		if i == 0:
			d = pts[1] - pts[0]
		elif i == last:
			d = pts[i] - pts[i - 1]
		else:
			d = (pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()
		d = d.normalized()
		_tube(k, pts[i] - d * r * 1.3, pts[i] + d * r * 1.3, r * 1.35, 8)


## A recessed ore hatch for a roof (the Scoop's two lids over its ore hold, the K1's beam
## hatch): a dark plate `width` (X) by `length` (Z) in a raised yellow frame with a bevelled
## outer edge and bolts along its top, dark slats across it between two longitudinal ribs,
## a recessed pull handle, hinge knuckles on the +Z end, latch dogs on the -Z end and a short
## cyan status light in a steel bezel by them. Face +Y, base on -Y; `thickness` the whole part.
static func ore_hatch(width: float = 2.0, length: float = 3.0, thickness: float = 0.12) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := thickness * 0.5
	var hw := width * 0.5
	var hl := length * 0.5
	var plate := thickness * 0.5
	k.color = DARK
	k.box(Vector3(width - 0.02, plate, length - 0.02), Vector3(0.0, -h + plate * 0.5, 0.0))
	var border := minf(0.18, width * 0.1)
	var ch := border * 0.3                         # bevel on the frame's outer top edge, m
	# The frame: side bars along Z, end bars between them, each bevelled on its outer edge.
	k.color = HATCH_YELLOW
	for sx: float in [-1.0, 1.0]:
		var xo := sx * hw
		var xi := sx * (hw - border)
		k.extrude(PackedVector2Array([Vector2(xi, -h), Vector2(xo, -h), Vector2(xo, h - ch), Vector2(xo - sx * ch, h),
				Vector2(xi, h)]), length)
	for sz: float in [-1.0, 1.0]:
		var zo := sz * hl
		var zi := sz * (hl - border)
		_prism_x(k, PackedVector2Array([Vector2(zi, -h), Vector2(zo, -h), Vector2(zo, h - ch), Vector2(zo - sz * ch, h),
				Vector2(zi, h)]), -hw + border + 0.005, hw - border - 0.005)
	# Slats and ribs in the recess, below the frame's top.
	var inner_w := width - 2.0 * border - 0.04
	var inner_l := length - 2.0 * border - 0.04
	k.color = Color(0.24, 0.25, 0.27)
	var slats := maxi(3, int(inner_l / 0.3))
	for i in slats:
		var z := -inner_l * 0.5 + inner_l * (float(i) + 0.5) / float(slats)
		k.box(Vector3(inner_w, thickness * 0.3, inner_l / float(slats) * 0.55), Vector3(0.0, -h + plate + thickness * 0.15, z))
	k.color = DETAIL
	var rib_y := -h + plate + thickness * 0.19 + 0.003
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.08, thickness * 0.38, inner_l), Vector3(sx * inner_w * 0.22, rib_y, 0.0))
	# Bolts along the frame's flat top.
	var bolt_r := clampf(border * 0.1, 0.008, 0.016)
	var mid_band := border - ch
	for sx: float in [-1.0, 1.0]:
		var bx := sx * (hw - border + mid_band * 0.5)
		var n := maxi(2, int(length / 0.45))
		for i in n:
			_thrusters_bolt(k, Vector3(bx, h, lerpf(-hl + border * 0.5, hl - border * 0.5, float(i) / float(n - 1))),
					bolt_r, 0.008)
	for sz: float in [-1.0, 1.0]:
		var bz := sz * (hl - border + mid_band * 0.5)
		var n := maxi(1, int((width - 2.0 * border) / 0.45))
		for i in n:
			var x := lerpf(-hw + border, hw - border, (float(i) + 0.5) / float(n))
			if sz > 0.0 and absf(absf(x) - hw * 0.45) < width * 0.1:
				continue   # the hinges sit there
			_thrusters_bolt(k, Vector3(x, h, bz), bolt_r, 0.008)
	# Hinge knuckles on the +Z end bar, latch dogs on the -Z one.
	var hr := minf(0.015, border * 0.18)
	var hz := hl - border * 0.5
	for sx: float in [-1.0, 1.0]:
		var x0 := sx * hw * 0.45 - width * 0.08
		var x1 := sx * hw * 0.45 + width * 0.08
		for s in 3:
			k.color = DETAIL if s % 2 == 0 else DARK
			_tube(k, Vector3(lerpf(x0, x1, float(s) / 3.0) + 0.002, h, hz), Vector3(lerpf(x0, x1, float(s + 1) / 3.0) - 0.002, h, hz),
					hr, 8)
		k.color = DARK
		k.box(Vector3(border * 0.6, 0.012, border * 0.5), Vector3(sx * hw * 0.4, h + 0.006, -hz))
	# A pull handle in the recess near the latch end.
	var slat_top := -h + plate + thickness * 0.3
	var hy := maxf(slat_top + 0.02, h - 0.012)
	var hzp := -inner_l * 0.5 + minf(0.22, inner_l * 0.25)
	var hx := minf(0.14, inner_w * 0.15)
	k.color = TRIM
	_tube(k, Vector3(-hx, hy, hzp), Vector3(hx, hy, hzp), 0.01, 6)
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.02, hy - slat_top, 0.02), Vector3(sx * hx, (hy + slat_top) * 0.5, hzp))
	# A steel bezel for the status light.
	var lz := -inner_l * 0.5 + 0.06
	k.color = DETAIL
	k.box(Vector3(inner_w * 0.34, 0.012, 0.09), Vector3(0.0, slat_top + 0.006, lz))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * length * thickness * 0.5
	var col := BoxShape3D.new()
	col.size = Vector3(width, thickness, length)
	shape.collision = col
	var g := MeshKit.new()
	g.box(Vector3(inner_w * 0.3, 0.02, 0.06), Vector3(0.0, slat_top + 0.012, lz))
	shape.glow = g.finish()
	shape.glow_color = Color(0.3, 0.9, 1.0)
	return shape


## A round SE2-style thruster (the Scoop's lift thrusters on its roof and the two round
## engines on its stern): a chamfered cast mount plate with four galvanised bolts at -Y, a
## hollow tapered drum in the material colour with a gunmetal band and two galvanised ribs,
## a stepped heat-tinted lip at +Y and a sooted ceramic funnel throat with a heat-blued ring
## part-way down to a glowing floor. Exhaust +Y.
## `radius` is the lip's.
static func cup_thruster(radius: float = 0.45, length: float = 0.7, glow := Color(0.4, 0.7, 1.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var r := radius
	var h := length * 0.5
	var seg := 20
	# A chamfered dark mount plate with a hex bolt in each corner.
	var plate_t := clampf(length * 0.08, 0.025, 0.08)
	k.color = PLATE_DARK
	k.loft(_chamfer_ring(r * 0.9, -h, r * 0.25), _chamfer_ring(r * 0.9, -h + plate_t, r * 0.25))
	var d0 := -h + plate_t
	k.color = GALVANISED
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_thrusters_bolt(k, Vector3(sx * r * 0.66, d0, sz * r * 0.66), maxf(0.008, r * 0.07),
					clampf(r * 0.05, 0.006, 0.03))
	# The drum: a hollow tapered barrel in the material colour round the throat.
	var lip := clampf(length * 0.12, 0.03, 0.12)
	var top := h - lip
	var rt := r * 0.72
	var drum := func(y: float) -> float: return lerpf(r * 0.78, r * 0.86, (y - d0) / (top - d0))
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(rt, d0), Vector2(r * 0.78, d0), Vector2(r * 0.86, top), Vector2(rt, top)]), seg)
	# Bands: a dark one low down, two grey ribs high up.
	var bw := clampf(length * 0.05, 0.012, 0.06)
	var yb: float = lerpf(d0, top, 0.28)
	k.color = GUNMETAL
	_thrusters_ring(k, drum.call(yb) - 0.01, drum.call(yb) + r * 0.035, yb - bw, yb + bw, 16)
	k.color = GALVANISED
	for t: float in [0.62, 0.78]:
		var y: float = lerpf(d0, top, t)
		_thrusters_ring(k, drum.call(y) - 0.01, drum.call(y) + r * 0.04, y - bw * 0.4, y + bw * 0.4, 16)
	# The lip, stepped: a narrower ring under the full-width rim.
	k.color = ENG_NOZZLE
	var step_y := h - lip * 0.5
	_thrusters_ring(k, r * 0.7, r * 0.89, top, step_y, seg)
	_thrusters_ring(k, r * 0.7, r, step_y, h, seg)
	# The throat: a dark funnel down to a floor, a grey ring part-way down.
	var y_floor := h - length * 0.45
	var rf := r * 0.36
	k.color = DARK
	_thrusters_ring(k, 0.0, rt, y_floor - clampf(length * 0.03, 0.006, 0.03), y_floor, 16)
	k.color = ENG_LINER
	k.lathe(PackedVector2Array([Vector2(rf, y_floor), Vector2(rf + rt - r * 0.68, y_floor), Vector2(rt, h - 0.004),
			Vector2(r * 0.68, h - 0.004)]), seg)
	var funnel := func(y: float) -> float: return lerpf(rf, r * 0.68, (y - y_floor) / (h - 0.004 - y_floor))
	var yr := lerpf(y_floor, h, 0.4)
	var rr: float = funnel.call(yr)
	k.color = RIM
	_thrusters_ring(k, rr - r * 0.05, rr + r * 0.03, yr - bw * 0.35, yr + bw * 0.35, 16)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = k.volume()
	var col := CylinderShape3D.new()
	col.radius = radius
	col.height = length
	shape.collision = col
	# The glow: the throat's floor.
	var g := MeshKit.new()
	_thrusters_ring(g, 0.0, rf * 0.92, y_floor + 0.002, y_floor + 0.002 + clampf(length * 0.02, 0.004, 0.02), 16)
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## An open-topped ore bin `size` across (the miners' holds): a skip in the material colour
## on two dark skids, steel angle posts up its corners, dark stiffener ribs down its sides
## and ends and a steel belt rib round its middle, a yellow rim round the top with dark
## hazard bars on its outer faces, a dark slide gate in the -Z end between steel guides
## with a pull bar over it, and a heap of grey, slate and rust ore lumps (turned every
## which way) on an ore bed inside, highest in the middle. Unlit. Stands on -Y.
static func ore_bin(size: Vector3 = Vector3(1.4, 1.4, 2.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := size * 0.5
	var wall := 0.06
	var skid := 0.08                                # skid height, m
	var rim := 0.06                                 # rim height, m
	var y0 := -h.y + skid                           # underside of the skip
	var yw := (y0 + h.y - rim) * 0.5                # middle of the walls
	var wh := h.y - rim - y0                        # wall height, m
	# The skip: floor, side walls, end walls.
	k.box(Vector3(size.x - 0.04, wall, size.z - 0.04), Vector3(0.0, y0 + wall * 0.5, 0.0))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(wall, wh, size.z - 0.04), Vector3(sx * (h.x - 0.02 - wall * 0.5), yw, 0.0))
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(size.x - 0.04 - 2.0 * wall, wh, wall), Vector3(0.0, yw, sz * (h.z - 0.02 - wall * 0.5)))
	# Skids under it, steel angle posts up the corners, a belt rib round the middle.
	k.color = DARK
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.12, skid, size.z - 0.1), Vector3(sx * (h.x - 0.22), -h.y + skid * 0.5, 0.0))
	k.color = DETAIL
	var p := 0.1
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(p, wh, p), Vector3(sx * (h.x - p * 0.5), yw, sz * (h.z - p * 0.5)))
	var belt := y0 + wh * 0.45
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.024, 0.06, size.z - 2.0 * p), Vector3(sx * (h.x - 0.008), belt, 0.0))
	k.box(Vector3(size.x - 2.0 * p, 0.06, 0.024), Vector3(0.0, belt, h.z - 0.008))
	# Ribs down the sides and the +Z end.
	k.color = DARK
	var ribs := maxi(2, int(size.z / 0.6))
	for sx: float in [-1.0, 1.0]:
		for i in ribs:
			var z := -h.z + p + (size.z - 2.0 * p) * (float(i) + 0.5) / float(ribs)
			k.box(Vector3(0.02, wh - 0.04, 0.07), Vector3(sx * (h.x - 0.01), yw, z))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.07, wh - 0.04, 0.02), Vector3(sx * size.x * 0.2, yw, h.z - 0.01))
	# The slide gate in the -Z end, its guides and pull bar.
	var gw := size.x * 0.42
	var gh := wh * 0.36
	var gy := y0 + wall + gh * 0.5 + 0.04
	var ez := -h.z + 0.02                            # the end wall's outer face
	k.box(Vector3(gw, gh, 0.012), Vector3(0.0, gy, ez - 0.006))
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.04, gh + 0.16, 0.02), Vector3(sx * (gw * 0.5 + 0.02), gy + 0.06, ez - 0.01))
	k.box(Vector3(gw * 0.5, 0.03, 0.012), Vector3(0.0, gy + gh * 0.5 - 0.05, ez - 0.016))
	# The rim, dark hazard bars on its outer faces.
	k.color = PartShapes.ACCENT
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.1, rim, size.z), Vector3(sx * (h.x - 0.05), h.y - rim * 0.5, 0.0))
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(size.x - 0.2, rim, 0.1), Vector3(0.0, h.y - rim * 0.5, sz * (h.z - 0.05)))
	k.color = DARK
	var bars_z := maxi(2, int(size.z / 0.5))
	for sx: float in [-1.0, 1.0]:
		for i in bars_z:
			var z := -h.z + size.z * (float(i) + 0.5) / float(bars_z)
			k.box(Vector3(0.006, rim - 0.01, 0.07), Vector3(sx * (h.x + 0.003), h.y - rim * 0.5, z))
	for sz: float in [-1.0, 1.0]:
		for t: float in [-0.25, 0.25]:
			k.box(Vector3(0.07, rim - 0.01, 0.006), Vector3(size.x * t, h.y - rim * 0.5, sz * (h.z + 0.003)))
	# The ore: a bed, then a heap of lumps, each turned its own way.
	var ix := size.x - 0.2 - 2.0 * wall
	var iz := size.z - 0.2 - 2.0 * wall
	var deep := h.y - rim - (y0 + wall)              # inside depth, m
	var bed := deep * 0.45
	var y_bed := y0 + wall + bed
	k.color = ORE_BED
	k.box(Vector3(ix + 0.1, bed, iz + 0.1), Vector3(0.0, y0 + wall + bed * 0.5, 0.0))
	var lumps: Array[Color] = [ORE_GREY, ORE_RUST, ORE_SLATE]
	var cell := minf(ix / 3.0, iz / 4.0)
	var n := 0
	for i in 3:
		for j in 4:
			var mound := 1.0 - 0.35 * (absf(float(i) - 1.0) + absf(float(j) - 1.5) * 0.6)
			var w := cell * (0.88 + 0.1 * float((i + j) % 2))
			var c := Vector3(-ix * 0.5 + ix * (float(i) + 0.5) / 3.0, y_bed + deep * 0.32 * mound - w * 0.3,
					-iz * 0.5 + iz * (float(j) + 0.5) / 4.0)
			n = _stowage_lump(k, c, Vector3(w, w * 0.75, w * 0.9), n, lumps)
	# A crest of smaller lumps over the middle.
	for j in 4:
		var w := cell * 0.55
		var c := Vector3(cell * 0.35 * (1.0 if j % 2 == 0 else -1.0), y_bed + deep * 0.36 + w * 0.05,
				-iz * 0.3 + iz * 0.2 * float(j))
		n = _stowage_lump(k, c, Vector3(w, w * 0.7, w * 0.85), n, lumps)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size.x * size.z * size.y * 0.4
	var col := BoxShape3D.new()
	col.size = size
	shape.collision = col
	return shape


## One ore lump for `ore_bin`: a box `size` at `c`, turned by angles picked from its number
## `n` (so every machine draws the same heap), coloured from `colours` in turn. Returns
## the next number.
static func _stowage_lump(k: MeshKit, c: Vector3, size: Vector3, n: int, colours: Array[Color]) -> int:
	k.color = colours[n % colours.size()]
	var from := k.verts.size()
	k.box(size)
	var f := float(n)
	var b := Basis(Vector3.UP, f * 1.37).rotated(Vector3.RIGHT, sin(f * 2.1) * 0.45).rotated(Vector3.BACK, cos(f * 1.7) * 0.4)
	_stowage_xform(k, from, Transform3D(b, c))
	return n + 1


# --- Mantis fighter parts (0.40) ----------------------------------------------------------

## A rotary cannon (the Mantis's guns in its prong tips, the warships' close-in guns): a
## chamfered square breech housing at -Y on a cast iron mount flange, a dark band round it,
## a gunmetal ammo feed chute up its +X side with brass belt links across it, two lit ready
## lamps on its -X side (PartShape.glow) and blackened bolts in its top corners; a cast drum
## with a dark band, six gunmetal barrels in a ring with dark bores, held by two heat-blued
## hexagonal clamp plates (the thicker at the muzzle) round a gunmetal spindle. `radius` is the barrel ring's (the housing is a little
## wider), `length` the whole part, barrels toward +Y. Collision is the hull of the housing
## and the muzzle ring.
static func gatling_gun(radius: float = 0.2, length: float = 1.2, glow := Color(1.0, 0.6, 0.15)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var y0 := -length * 0.5
	var y1 := length * 0.5
	var hw := radius * 1.25
	var house := length * 0.3
	var d0 := y0 + house
	var c := hw * 0.22                    # the housing's corner chamfer, m
	var fl := house * 0.14                # the mount flange, m
	var hb := hw * 0.94                   # the housing body's half width, m
	var bev := house * 0.08               # the bevel round its top, m
	# The breech housing on its flange, a dark band round it.
	k.color = CAST
	k.loft(_chamfer_ring(hw, y0, c), _chamfer_ring(hw, y0 + fl, c))
	k.color = Color.WHITE
	k.loft(_chamfer_ring(hb, y0 + fl, c * 0.94), _chamfer_ring(hb, d0 - bev, c * 0.94))
	k.loft(_chamfer_ring(hb, d0 - bev, c * 0.94), _chamfer_ring(hb - bev, d0, c * 0.9))
	k.color = DARK
	k.loft(_chamfer_ring(hb + 0.008, y0 + house * 0.42, c * 0.94), _chamfer_ring(hb + 0.008, y0 + house * 0.56, c * 0.94))
	# The ammo feed chute up the +X side, its belt links across it.
	var ch0 := y0 + fl + house * 0.06
	var ch1 := d0 - bev - house * 0.04
	k.color = GUNMETAL
	k.box(Vector3(0.017, ch1 - ch0, hb * 0.8), Vector3(hb + 0.0035, (ch0 + ch1) * 0.5, 0.0))
	k.color = BRASS
	for i in 5:
		var y := lerpf(ch0, ch1, (float(i) + 0.5) / 5.0)
		k.box(Vector3(0.006, (ch1 - ch0) * 0.08, hb * 0.66), Vector3(hb + 0.013, y, 0.0))
	# Two ready lamps in a dark bezel on the -X side.
	var ly := lerpf(y0 + house * 0.56, d0 - bev, 0.5)
	var ls := clampf(radius * 0.12, 0.012, 0.04)
	k.color = DARK
	k.box(Vector3(0.006, ls * 1.8, ls * 4.2), Vector3(-hb - 0.003, ly, 0.0))
	for sz: float in [-1.0, 1.0]:
		g.box(Vector3(0.004, ls, ls), Vector3(-hb - 0.008, ly, sz * ls * 1.1))
	# Bolts in the top's corners, clear of the drum.
	k.color = FLANGE_BOLT
	var bs := maxf(0.012, radius * 0.09)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_piping_bolts(k, Vector3(sx * (hb - bev) * 0.8, d0, sz * (hb - bev) * 0.8), Vector3.UP, 0.0, 1, 0.0, bs,
					bs * 0.5)
	# The drum, a dark band round it.
	var drum := length * 0.16
	k.color = CAST
	k.lathe(PackedVector2Array([Vector2(0.0, d0), Vector2(radius * 1.05, d0), Vector2(radius * 1.05, d0 + drum),
			Vector2(radius * 0.7, d0 + drum + 0.03), Vector2(0.0, d0 + drum + 0.03)]), 18)
	k.color = DARK
	_thrusters_ring(k, radius * 0.9, radius * 1.05 + 0.006, d0 + drum * 0.35, d0 + drum * 0.6, 18)
	# The barrels, a ring of six, dark bores in their tips, round a spindle.
	var br := radius * 0.17
	var ring := radius * 0.68
	var metal := WPN_BARREL
	for i in 6:
		var a := TAU * float(i) / 6.0
		var off := Vector3(cos(a) * ring, 0.0, sin(a) * ring)
		k.color = metal
		_tube(k, off + Vector3(0.0, d0 + drum, 0.0), off + Vector3(0.0, y1 - 0.01, 0.0), br, 8)
		k.color = GUN_BORE
		_tube(k, off + Vector3(0.0, y1 - 0.012, 0.0), off + Vector3(0.0, y1 - 0.005, 0.0), br * 0.55, 8)
	k.color = metal
	k.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(radius * 0.35, 0.0), Vector2(radius * 0.35, y1 - 0.02),
			Vector2(0.0, y1 - 0.02)]), 10)
	# Hexagonal clamp plates: a thin one mid-way, a thick one near the muzzle.
	k.color = WPN_BLUED
	var hexr := radius * 1.05
	for clamp: Vector2 in [Vector2(lerpf(d0 + drum, y1, 0.45), 0.03), Vector2(y1 - 0.06, 0.045)]:
		k.lathe(PackedVector2Array([Vector2(ring - br * 0.3, clamp.x - clamp.y), Vector2(hexr, clamp.x - clamp.y),
				Vector2(hexr, clamp.x + clamp.y), Vector2(ring - br * 0.3, clamp.x + clamp.y)]), 6)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = hw * hw * 4.0 * house * 0.5 + PI * radius * radius * (y1 - d0) * 0.3
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * hw, y0, sz * hw))
			pts.append(Vector3(sx * hw, d0, sz * hw))
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector3(cos(a) * radius * 1.05, d0 + drum, sin(a) * radius * 1.05))
		pts.append(Vector3(cos(a) * radius, y1, sin(a) * radius))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A main engine in an octagonal housing (the Mantis's three stern engines, the Endeavor's
## pod nozzles): a dark mount flange `width` across bolted round its ledge, a deep octagonal
## drum in the material colour with a steel band and a heat-shield band, a thick pale rim
## round its +Y face framing a dark recess, and two hollow round nozzles side by side along X
## in it: dark flanges (bolted on big engines), steel collars, pale lips and ceramic liners
## down to injector floors glowing inside a steel ring (PartShape.glow). Exhaust +Y;
## `depth` the whole part.
static func octagon_thruster(width: float = 1.6, depth: float = 0.8, glow := Color(0.35, 0.65, 1.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var h := depth * 0.5
	var ring := func(inset: float) -> PackedVector2Array:
		return PartShapes._chamfer_rect(width - inset * 2.0, width - inset * 2.0, width * 0.29 - inset * 0.414)
	_engines_twin_housing(k, g, ring, depth, width * 0.03, width * 0.1, width * 0.17, width * 0.2, false)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * width * depth * 0.45
	var outer: PackedVector2Array = ring.call(0.0)
	var pts := PackedVector3Array()
	for p in outer:
		pts.append(Vector3(p.x, -h, p.y))
		pts.append(Vector3(p.x, h, p.y))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A row of round lit studs on a dark rail (the blue lights the Mantis wears in rows and
## chevrons on its roof, flanks and belly): a chamfered gunmetal rail `count` studs long
## along X with bolted anodised end caps, each stud an eight-sided chrome bezel round a domed
## glowing lens on the +Y face, sealed by a rubber gasket ring under a clear lens face
## (PartShape.glass). `pitch` is stud to stud; base on -Y.
static func stud_lights(count: int = 4, pitch: float = 0.3, radius: float = 0.09,
		glow := Color(0.3, 0.55, 1.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var length := pitch * float(count)
	var y0 := -0.03
	var yr := 0.01
	var w := radius * 2.6
	var hw := w * 0.5
	# The rail: gunmetal, chamfered along its top edges, closed by anodised end caps with a
	# steel bolt each.
	var cap := clampf((pitch * 0.5 - radius) * 0.6, 0.01, 0.04)
	var xe := length * 0.5 - 0.004
	var c := minf(0.012, hw * 0.3)
	k.color = LIT_RAIL
	_prism_x(k, PackedVector2Array([Vector2(-hw, y0), Vector2(hw, y0), Vector2(hw, yr - c), Vector2(hw - c, yr),
			Vector2(-hw + c, yr), Vector2(-hw, yr - c)]), -xe, xe)
	for sx: float in [-1.0, 1.0]:
		var xc := sx * (length * 0.5 - cap * 0.5)
		k.color = ANODISED
		k.box(Vector3(cap, yr - y0 + 0.003, w + 0.006), Vector3(xc, (yr + y0 + 0.006) * 0.5, 0.0))
		k.color = DETAIL
		var b := minf(cap * 0.6, 0.016)
		k.box(Vector3(b, 0.008, b), Vector3(xc, yr + 0.007, 0.0))
	# Each stud: a chrome bezel sloping up to a lip round a domed lens (the glow).
	var g := MeshKit.new()
	var gk := MeshKit.new()
	var ri := radius * 0.68
	for i in count:
		var x := -length * 0.5 + pitch * (float(i) + 0.5)
		var bez := MeshKit.new()
		bez.lathe(PackedVector2Array([Vector2(ri, yr), Vector2(radius, yr), Vector2(ri, 0.03)]), 8)
		for j in bez.verts.size():
			k.verts.append(bez.verts[j] + Vector3(x, 0.0, 0.0))
			k.normals.append(bez.normals[j])
			k.colors.append(CHROME)
		var lens := MeshKit.new()
		lens.lathe(PackedVector2Array([Vector2(0.0, yr), Vector2(ri, yr), Vector2(ri * 0.75, 0.026),
				Vector2(0.0, 0.034)]), 8)
		for j in lens.verts.size():
			g.verts.append(lens.verts[j] + Vector3(x, 0.0, 0.0))
			g.normals.append(lens.normals[j])
			g.colors.append(Color.WHITE)
		# A rubber gasket ring seated in the bezel's lip, over the lit dome's rim.
		var gasket := MeshKit.new()
		gasket.lathe(PackedVector2Array([Vector2(ri * 0.84, 0.0295), Vector2(ri + 0.002, 0.0295),
				Vector2(ri * 0.92, 0.0335)]), 8)
		for j in gasket.verts.size():
			k.verts.append(gasket.verts[j] + Vector3(x, 0.0, 0.0))
			k.normals.append(gasket.normals[j])
			k.colors.append(RUBBER)
		# A clear lens face domed over the glow, standing on the gasket.
		var face := MeshKit.new()
		face.lathe(PackedVector2Array([Vector2(ri * 0.86, 0.033), Vector2(ri * 0.62, 0.0375), Vector2(0.0, 0.039)]), 8)
		for j in face.verts.size():
			gk.verts.append(face.verts[j] + Vector3(x, 0.0, 0.0))
			gk.normals.append(face.normals[j])
			gk.colors.append(Color.WHITE)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * w * (yr - y0) * 0.95
	var col := BoxShape3D.new()
	col.size = Vector3(length, 0.06, w)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	shape.glass = gk.finish()
	shape.glass_kind = Glazing.Kind.CLEAR
	return shape


# --- Pod scout parts (0.41) --------------------------------------------------------------

## A fighter pilot's seat with a flight stick on each armrest (the Scout N-S1's open cockpit
## seat, seen through the canopy): a bolted base plate and pedestal, a frame in the
## material colour with dark chamfered cushions (seat, back with side bolsters, headrest
## on a narrower top), a harness with a buckle, and armrests standing forward with a stick
## housing on each front: a booted stick, a grip with a button and a trigger, and a small
## status lamp beside it (the glow). `width` across, `height` tall. Stands on -Y, faces -Z
## (the backrest is at +Z).
static func stick_seat(width: float = 0.7, height: float = 1.3, glow := Color(0.3, 1.0, 0.45)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var w := width * 0.5
	var depth := width * 0.95
	var d := depth * 0.5
	var pan_y := -h + height * 0.36           # top of the seat cushion, m
	var y_pan := pan_y - 0.04                 # top of the pan frame, m
	var back_t := 0.08                        # back frame thickness, m
	var zb := d - back_t
	var head_h := minf(0.26, height * 0.2)    # headrest height, m
	var y_top := h - head_h
	_seating_base(k, Vector3(0.0, -h, 0.05), width * 0.32, y_pan - 0.08 - (-h), width * 0.3)
	# Pan frame, back frame and the narrower head frame.
	k.color = Color.WHITE
	k.box(Vector3(width - 0.02, 0.08, zb + d - 0.01), Vector3(0.0, y_pan - 0.04, (zb - d + 0.01) * 0.5))
	k.box(Vector3(width, y_top - (y_pan - 0.08), back_t), Vector3(0.0, (y_top + y_pan - 0.08) * 0.5, d - back_t * 0.5))
	k.box(Vector3(width * 0.6, head_h, back_t), Vector3(0.0, h - head_h * 0.5, d - back_t * 0.5))
	k.color = DARK
	k.box(Vector3(width * 0.6, (y_top - y_pan) * 0.6, 0.004), Vector3(0.0, (y_top + y_pan) * 0.5, d + 0.002))
	# Cushions.
	_seating_pad(k, Vector3(0.0, y_pan, (zb - d + 0.02) * 0.5), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			w - 0.04, (zb + d - 0.02) * 0.5, 0.07, 0.025)
	var b_lo := y_pan + 0.09
	var b_hi := y_top - 0.03
	var bc := Vector3(0.0, (b_lo + b_hi) * 0.5, zb)
	_seating_pad(k, bc, Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, w - 0.075, (b_hi - b_lo) * 0.5, 0.06, 0.02)
	for sx: float in [-1.0, 1.0]:
		_seating_pad(k, bc + Vector3(sx * (w - 0.035), 0.0, 0.0), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
				0.03, (b_hi - b_lo) * 0.45, 0.11, 0.015)
	_seating_pad(k, Vector3(0.0, h - head_h * 0.5, zb), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
			width * 0.3 - 0.035, head_h * 0.5 - 0.035, 0.06, 0.02)
	# The harness: shoulder straps down the back cushion, a lap belt and its buckle.
	k.color = DETAIL
	var lap_z := zb - 0.14
	for sx: float in [-1.0, 1.0]:
		k.strut(Vector3(sx * w * 0.24, b_hi - 0.02, zb - 0.068), Vector3(sx * w * 0.14, b_lo + 0.02, zb - 0.068), 0.03)
	k.strut(Vector3(-w + 0.07, pan_y + 0.034, lap_z), Vector3(w - 0.07, pan_y + 0.034, lap_z), 0.026)
	k.color = PartShapes.ACCENT
	k.box(Vector3(0.08, 0.03, 0.05), Vector3(0.0, pan_y + 0.04, lap_z))
	# Armrests: a bar on two posts, a pad, and the stick housing on the front.
	var arm_y := pan_y + 0.26                 # top of the armrest bar, m
	var z0 := -d + 0.02
	var z1 := zb - 0.12
	var g := MeshKit.new()
	for sx: float in [-1.0, 1.0]:
		var ax := sx * (w - 0.05)
		k.color = Color.WHITE
		k.box(Vector3(0.09, 0.06, z1 - z0), Vector3(ax, arm_y - 0.03, (z0 + z1) * 0.5))
		for z: float in [z0 + 0.06, z1 - 0.03]:
			k.box(Vector3(0.05, arm_y - 0.06 - y_pan, 0.05), Vector3(ax, (arm_y - 0.06 + y_pan) * 0.5, z))
		k.color = DARK
		k.box(Vector3(0.08, 0.025, z1 - z0 - 0.15), Vector3(ax, arm_y + 0.0125, (z0 + 0.14 + z1 - 0.01) * 0.5))
		k.box(Vector3(0.09, 0.05, 0.12), Vector3(ax, arm_y + 0.025, z0 + 0.06))
		var sz := z0 + 0.055
		_seating_pad(k, Vector3(ax, arm_y + 0.05, sz), Vector3.RIGHT, Vector3.BACK, Vector3.UP, 0.03, 0.03, 0.025, 0.012)
		k.box(Vector3(0.05, 0.11, 0.06), Vector3(ax, arm_y + 0.22, sz))
		k.color = DETAIL
		_tube(k, Vector3(ax, arm_y + 0.07, sz), Vector3(ax, arm_y + 0.166, sz), 0.014, 6)
		k.color = PartShapes.ACCENT
		k.box(Vector3(0.026, 0.014, 0.026), Vector3(ax, arm_y + 0.282, sz))
		k.box(Vector3(0.02, 0.03, 0.012), Vector3(ax, arm_y + 0.225, sz - 0.036))
		g.box(Vector3(0.05, 0.006, 0.014), Vector3(ax, arm_y + 0.053, z0 + 0.105))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = k.volume()
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A round grilled unit on a bracket (the drums beside the Scout N-S1's cockpit cage: an
## air intake or a small atmospheric thruster): a drum `radius` across and `length` long
## along Y in the material colour, a dark recess in its +Y face behind a grille of
## horizontal anodised slats held by two gunmetal carrier bars across their middles and a
## polished lip, two galvanised clamp bands round it, a cast foot ring with blackened
## bolts, and a galvanised mounting plate (a bolt in each corner) with two cheeks at -Y
## carrying rubber pivot bushes. Mount it by its plate (-Y).
static func grille_drum(radius: float = 0.4, length: float = 0.7) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := length * 0.5
	var plate := 0.06
	var y0 := -h + plate
	var seg := 20
	k.color = GALVANISED
	k.box(Vector3(radius * 2.1, plate, radius * 2.1), Vector3(0.0, -h + plate * 0.5, 0.0))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.06, length * 0.35, radius * 1.2), Vector3(sx * (radius + 0.03), y0 + length * 0.175, 0.0))
	# A bolt in each corner of the plate.
	var pb := radius * 1.05 - 0.04
	k.color = FLANGE_BOLT
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.03, 0.012, 0.03), Vector3(sx * pb, y0 + 0.006, sz * pb))
	# The foot ring round the drum, and bolts on the plate round it clear of the cheeks.
	var fl := minf(0.03, length * 0.08)
	var fr := minf(radius + 0.03, radius * 1.04)
	k.color = CAST
	k.lathe(PackedVector2Array([Vector2(radius * 0.98, y0), Vector2(fr, y0), Vector2(fr, y0 + fl),
			Vector2(radius * 0.98, y0 + fl)]), 16)
	k.color = FLANGE_BOLT
	for a: float in [PI / 3.0, PI * 2.0 / 3.0, PI * 4.0 / 3.0, PI * 5.0 / 3.0]:
		k.box(Vector3(0.022, 0.012, 0.022), Vector3(cos(a) * (fr + 0.012), y0 + 0.006, sin(a) * (fr + 0.012)))
	# Pivot bosses on the cheeks' outer faces.
	k.color = RUBBER
	var boss := minf(minf(0.05, radius * 0.18), length * 0.12)
	var yc := y0 + length * 0.2
	for sx: float in [-1.0, 1.0]:
		_tube(k, Vector3(sx * (radius + 0.058), yc, 0.0), Vector3(sx * (radius + 0.072), yc, 0.0), boss)
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(0.0, y0), Vector2(radius, y0), Vector2(radius, h - 0.04),
			Vector2(radius * 0.86, h - 0.02), Vector2(radius * 0.86, h - 0.08), Vector2(0.0, h - 0.08)]), seg)
	k.color = TRIM
	k.lathe(PackedVector2Array([Vector2(radius * 0.84, h - 0.06), Vector2(radius * 0.97, h - 0.06),
			Vector2(radius * 0.97, h - 0.005), Vector2(radius * 0.84, h - 0.005)]), seg)
	k.color = GALVANISED
	var bh := minf(0.025, length * 0.05)
	for t: float in [0.3, 0.62]:
		var y := lerpf(y0, h, t)
		k.lathe(PackedVector2Array([Vector2(radius * 0.98, y - bh), Vector2(radius + 0.018, y - bh),
				Vector2(radius + 0.018, y + bh), Vector2(radius * 0.98, y + bh)]), 16)
	# The grille: horizontal slats across the recess, a dark floor behind them.
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(0.0, h - 0.09), Vector2(radius * 0.85, h - 0.09),
			Vector2(radius * 0.85, h - 0.08), Vector2(0.0, h - 0.08)]), seg)
	k.color = ANODISED
	var r := radius * 0.82
	var slats := 7
	for i in slats:
		var z := -r + (2.0 * r) * (float(i) + 0.5) / float(slats)
		var half := sqrt(maxf(r * r - z * z, 0.0))
		k.box(Vector3(half * 2.0, 0.05, 0.04), Vector3(0.0, h - 0.055, z))
	# Two carrier bars across the slats (along Z), standing on them.
	k.color = GUNMETAL
	for sx: float in [-1.0, 1.0]:
		var cz := sqrt(r * r - r * r * 0.25) - 0.01
		k.box(Vector3(0.024, 0.016, cz * 2.0), Vector3(sx * r * 0.5, h - 0.03, 0.0))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * radius * radius * length * 0.35 + radius * radius * 4.4 * plate
	var pts := PackedVector3Array()
	var hw := radius * 1.05
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * hw, -h, sz * hw))
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector3(cos(a) * (radius + 0.015), y0, sin(a) * (radius + 0.015)))
		pts.append(Vector3(cos(a) * radius, h, sin(a) * radius))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	return shape


## A small roof hatch (the two on the Scout N-S1's spine): a raised square coaming `size`
## across in the material colour with bolts round its top, a dark gasket ring inside it, a
## grey lid with a bevelled top and a hand wheel on three spokes, a yellow latch over a
## dark keeper at -Z, and a hinge of three knuckles on a dark pin along its +Z edge with
## leaves down onto the lid. Face +Y; `height` the whole part.
static func roof_hatch(size: float = 0.9, height: float = 0.14) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var s := size * 0.5
	var rim := size * 0.12
	var coaming := height * 0.7
	var cy := -h + coaming * 0.5
	var c_top := -h + coaming
	k.box(Vector3(size, coaming, rim), Vector3(0.0, cy, s - rim * 0.5))
	k.box(Vector3(size, coaming, rim), Vector3(0.0, cy, -s + rim * 0.5))
	k.box(Vector3(rim, coaming, size - rim * 2.0), Vector3(s - rim * 0.5, cy, 0.0))
	k.box(Vector3(rim, coaming, size - rim * 2.0), Vector3(-s + rim * 0.5, cy, 0.0))
	# The gasket: a dark block filling the opening, showing as a ring round the lid.
	k.color = DARK
	var open := size - rim * 2.0 - 0.004
	k.box(Vector3(open, coaming * 0.5, open), Vector3(0.0, -h + coaming * 0.45, 0.0))
	# The lid: a slab with a bevelled top.
	k.color = DETAIL
	var lh := open * 0.5 - maxf(0.012, rim * 0.25)
	var ly0 := -h + coaming * 0.55
	var ly1 := -h + coaming * 0.8
	var lid_y := -h + coaming * 0.9
	var lc := lh * 0.15
	k.loft(_chamfer_ring(lh, ly0, lc), _chamfer_ring(lh, ly1, lc))
	k.loft(_chamfer_ring(lh, ly1, lc), _chamfer_ring(lh * 0.86, lid_y, lc * 0.86))
	# Bolts round the coaming's top: the corners and the middle of each side.
	var bolt := clampf(size * 0.035, 0.012, 0.03)
	for p: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(-1, 0), Vector2(1, 0)]:
		k.box(Vector3(bolt, 0.008, bolt), Vector3(p.x * (s - rim * 0.5), c_top + 0.002, p.y * (s - rim * 0.5)))
	# The hand wheel: a ring of four bars on three spokes round a hub.
	var bar := clampf(size * 0.028, 0.012, 0.025)
	var wr := (s - rim) * 0.55
	var wy := lid_y + bar * 0.8
	k.box(Vector3(bar * 2.4, wy - lid_y + bar * 0.5, bar * 2.4), Vector3(0.0, (lid_y + wy + bar * 0.5) * 0.5 - 0.002, 0.0))
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var b := TAU * float(i + 1) / 4.0 + PI * 0.25
		k.strut(Vector3(cos(a) * wr, wy, sin(a) * wr), Vector3(cos(b) * wr, wy, sin(b) * wr), bar)
	for i in 3:
		var a := TAU * float(i) / 3.0
		k.strut(Vector3(0.0, wy, 0.0), Vector3(cos(a) * wr * 0.75, wy, sin(a) * wr * 0.75), bar * 0.8)
	# The latch over a dark keeper on the coaming at -Z.
	k.color = DARK
	k.box(Vector3(size * 0.2, 0.01, rim * 0.6), Vector3(0.0, c_top + 0.003, -s + rim * 0.5))
	k.color = PartShapes.ACCENT
	var lt := clampf(height * 0.2, 0.015, 0.03)
	var ld := rim * 0.9 + lc
	k.box(Vector3(size * 0.13, lt, ld), Vector3(0.0, lid_y + lt * 0.5 - 0.004, -lh + lc + rim * 0.2 - ld * 0.5))
	# The hinge: three knuckles on a dark pin along the +Z coaming, leaves down onto the lid.
	var kr := (height - coaming) * 0.5
	var hz := s - rim * 0.5
	var hy := h - kr
	k.color = DARK
	_tube(k, Vector3(-size * 0.33, hy, hz), Vector3(size * 0.33, hy, hz), kr * 0.45, 6)
	k.color = DETAIL
	var kl := size * 0.14
	var strap := clampf(size * 0.03, 0.01, 0.025)
	for i in 3:
		var x := (float(i) - 1.0) * size * 0.22
		_tube(k, Vector3(x - kl * 0.5, hy, hz), Vector3(x + kl * 0.5, hy, hz), kr, 8)
		if i == 1:
			k.box(Vector3(kl * 0.9, 0.006, rim * 0.45), Vector3(x, c_top + 0.002, hz + rim * 0.2))
		else:
			k.strut(Vector3(x, hy, hz - kr * 0.5), Vector3(x, lid_y + strap * 0.3, hz - rim * 1.6), strap)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size * size * coaming * 0.4
	var col := BoxShape3D.new()
	col.size = Vector3(size, height, size)
	shape.collision = col
	return shape


# --- Dagger frigate parts (0.42) ----------------------------------------------------------

## A heavy twin-barrelled gun turret (the warships' main guns: the Dagger frigate's
## shoulders, the Devastator, Everest and Sentinel): a round armoured base ring `radius`
## across, a foot flange with a bolt circle and a dark band, a low faceted housing with a
## sloped glacis toward -Z, raised cheek armour with seams, an ammo bustle at the back with
## a hazard tab, a sight block with a dark visor and two lit lenses (PartShape.glow), a
## commander's hatch and roof vents, and two barrels out of a bolted mantlet, each with a
## collar, a recoil sleeve, a clamp and a slotted muzzle brake. Stands on -Y, barrels toward
## -Z; `barrel` is how far they reach past the housing.
static func twin_turret(radius: float = 1.0, barrel: float = 2.2, glow := Color(1.0, 0.18, 0.1)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var r := radius
	var base := r * 0.3
	var y0 := -(base + r * 0.55) * 0.5
	var shelf := y0 + base * 0.3
	# The base ring: a foot flange with a bolt circle, the ring body, a dark band.
	k.lathe(PackedVector2Array([Vector2(0.0, y0), Vector2(r, y0), Vector2(r, shelf - base * 0.06),
			Vector2(r * 0.985, shelf), Vector2(0.0, shelf)]), 28)
	var bolt := maxf(0.024, r * 0.045)
	_piping_bolts(k, Vector3(0.0, shelf, 0.0), Vector3.UP, 0.0, clampi(int(TAU * r / 0.24), 12, 28), r * 0.96,
			bolt, bolt * 0.55)
	k.lathe(PackedVector2Array([Vector2(0.0, shelf), Vector2(r * 0.93, shelf), Vector2(r * 0.93, y0 + base * 0.82),
			Vector2(r * 0.88, y0 + base), Vector2(0.0, y0 + base)]), 28)
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(r * 0.88, y0 + base * 0.48), Vector2(r * 0.93 + 0.01, y0 + base * 0.48),
			Vector2(r * 0.93 + 0.01, y0 + base * 0.66), Vector2(r * 0.88, y0 + base * 0.66)]), 28)
	# The housing: a faceted block, its front sloping down toward the barrels.
	k.color = Color.WHITE
	var hy0 := y0 + base
	var hh := r * 0.55
	var hw := r * 0.78
	var hz := r * 0.82
	var side := PackedVector2Array([Vector2(-hz, hy0), Vector2(hz, hy0), Vector2(hz, hy0 + hh * 0.8),
			Vector2(hz * 0.7, hy0 + hh), Vector2(-hz * 0.35, hy0 + hh), Vector2(-hz, hy0 + hh * 0.45)])
	_prism_x(k, side, -hw, hw)
	# Cheek armour standing proud on both sides, two dark seams down each.
	var cheek := _weapons_inset(side, Vector2(0.0, hy0 + hh * 0.5), 0.84)
	for sx: float in [-1.0, 1.0]:
		k.color = Color.WHITE
		_prism_x(k, cheek, sx * (hw - 0.01), sx * (hw + 0.016))
		k.color = DARK
		for zs: float in [-0.12, 0.42]:
			k.box(Vector3(0.006, hh * 0.62, maxf(0.012, r * 0.02)), Vector3(sx * (hw + 0.018), hy0 + hh * 0.48, hz * zs))
	# The ammo bustle on the back, a hazard tab across it.
	var bz0 := hz - 0.01
	var bz1 := r * 0.96
	var bys := Vector2(hy0 + hh * 0.1, hy0 + hh * 0.7)
	k.color = Color.WHITE
	k.box(Vector3(hw * 1.3, bys.y - bys.x, bz1 - bz0), Vector3(0.0, (bys.x + bys.y) * 0.5, (bz0 + bz1) * 0.5))
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.012, bys.y - bys.x - 0.04, bz1 - bz0 - 0.02), Vector3(sx * (hw * 0.65 + 0.004), (bys.x + bys.y) * 0.5,
				(bz0 + bz1) * 0.5 - 0.01))
	_weapons_hazard(k, Vector3(0.0, (bys.x + bys.y) * 0.5, bz1), hw * 1.0, (bys.y - bys.x) * 0.36, 1.0, 4)
	# The sight block on the roof: a steel body under a dark armoured visor, two lenses.
	var sx0 := -hw * 0.45
	var sz := hz * 0.3
	var top := hy0 + hh * 1.3
	k.color = DETAIL
	k.box(Vector3(hw * 0.5, hh * 0.25, hz * 0.5), Vector3(sx0, hy0 + hh + hh * 0.125, sz))
	k.color = DARK
	k.box(Vector3(hw * 0.54, hh * 0.05, hz * 0.58), Vector3(sx0, top - hh * 0.025, sz - hz * 0.02))
	for lx: float in [-1.0, 1.0]:
		_weapons_lens(k, g, Vector3(sx0 + lx * hw * 0.12, hy0 + hh * 1.12, sz - hz * 0.25), r * 0.06)
	# A commander's hatch with a grab handle, three vent slots behind it.
	var hx := hw * 0.42
	k.color = DETAIL
	_electrical_lathe_at(k, PackedVector2Array([Vector2(0.0, hy0 + hh), Vector2(r * 0.17, hy0 + hh),
			Vector2(r * 0.15, hy0 + hh + r * 0.04), Vector2(0.0, hy0 + hh + r * 0.04)]), 14, Vector3(hx, 0.0, hz * 0.12))
	k.color = DARK
	k.box(Vector3(r * 0.16, r * 0.025, r * 0.03), Vector3(hx, hy0 + hh + r * 0.05, hz * 0.12))
	for i in 3:
		k.box(Vector3(hw * 0.6, 0.006, r * 0.035), Vector3(hx * 0.4, hy0 + hh + 0.003, hz * (0.42 + 0.1 * float(i))))
	# The mantlet: a bolted block across the front; two barrels out of it.
	var by := hy0 + hh * 0.42
	var br := r * 0.07
	var front := -hz + 0.02
	var mf := front - 0.1
	k.color = DETAIL
	k.box(Vector3(hw * 0.9 + br * 5.0, br * 5.0, 0.1), Vector3(0.0, by, front - 0.05))
	_piping_bolts(k, Vector3(0.0, by, mf), Vector3.FORWARD, 0.0, 2, hw * 0.45 + br * 2.0, bolt, bolt * 0.5, 0.0)
	_piping_bolts(k, Vector3(0.0, by, mf), Vector3.FORWARD, 0.0, 2, br * 1.9, bolt, bolt * 0.5, PI * 0.5)
	var tip := front - barrel
	for sx: float in [-1.0, 1.0]:
		_weapons_barrel(k, Vector3(sx * hw * 0.45, by, mf), tip, br, br * 1.9, br * 1.6, br * 1.5,
				clampf(barrel * 0.12, 0.15, 0.32), Color(0.24, 0.25, 0.27))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * r * r * base * 0.6 + hw * 2.0 * hz * 2.0 * hh * 0.5 + barrel * br * br * 6.0
	var pts := PackedVector3Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector3(cos(a) * r, y0, sin(a) * r))
		pts.append(Vector3(cos(a) * r, y0 + base, sin(a) * r))
	for p in side:
		pts.append(Vector3(-hw - 0.016, p.y, p.x))
		pts.append(Vector3(hw + 0.016, p.y, p.x))
	for sx: float in [-1.0, 1.0]:
		pts.append(Vector3(sx * hw * 0.65, bys.y, bz1))
		pts.append(Vector3(sx * hw * 0.65, bys.x, bz1))
	pts.append(Vector3(sx0 - hw * 0.27, top, sz + hz * 0.25))
	pts.append(Vector3(sx0 + hw * 0.27, top, sz - hz * 0.3))
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * hw * 0.45 + br * 1.5, by + sy * br * 1.5, tip))
			pts.append(Vector3(sx * hw * 0.45 - br * 1.5, by + sy * br * 1.5, tip))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A small dome turret (point defence: the Dagger frigate's stern corners, the warships'
## roofs and keels): a cast iron foot flange `radius` across with a circle of blackened
## bolts, a short cast ring and a rubber-sealed traverse race, a faceted dome with a dark
## band, a gunmetal sensor head on its flat crown with two lit lenses (PartShape.glow) and
## one gunmetal barrel out of a round cast mantlet with a ringed sleeve and a slotted muzzle
## brake. Stands on -Y, barrel toward -Z.
static func dome_turret(radius: float = 0.6, barrel: float = 1.3, glow := Color(1.0, 0.6, 0.15)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var r := radius
	var base := r * 0.25
	var dome_h := r * 0.8
	var y0 := -(base + dome_h) * 0.5
	var shelf := y0 + base * 0.45
	var top := y0 + base + dome_h
	# The foot flange with its bolts, the ring, a dark race.
	k.color = CAST
	k.lathe(PackedVector2Array([Vector2(0.0, y0), Vector2(r * 1.05, y0), Vector2(r * 1.05, shelf),
			Vector2(0.0, shelf)]), 24)
	k.color = FLANGE_BOLT
	_piping_bolts(k, Vector3(0.0, shelf, 0.0), Vector3.UP, 0.0, 16, r * 1.01, r * 0.045, r * 0.025)
	k.color = CAST
	k.lathe(PackedVector2Array([Vector2(0.0, shelf), Vector2(r * 0.97, shelf), Vector2(r * 0.97, y0 + base),
			Vector2(0.0, y0 + base)]), 24)
	var yd := y0 + base + r * 0.03
	k.color = RUBBER
	k.lathe(PackedVector2Array([Vector2(0.0, y0 + base), Vector2(r * 0.92, y0 + base), Vector2(r * 0.92, yd),
			Vector2(0.0, yd)]), 24)
	# The dome: faceted, its crown cut flat for the sensor head.
	var rd := r * 0.98
	var dh := top - yd
	k.color = Color.WHITE
	var prof := PackedVector2Array([Vector2(0.0, yd)])
	var crown := asin(0.9)
	for i in 5:
		var a := crown * float(i) / 4.0
		prof.append(Vector2(cos(a) * rd, yd + sin(a) * dh))
	prof.append(Vector2(0.0, yd + dh * 0.9))
	k.lathe(prof, 8)
	# A dark band round the dome, standing clear of its facets.
	var rad := func(t: float) -> float: return rd * sqrt(1.0 - t * t) + 0.012
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(rd * 0.7, yd + dh * 0.2), Vector2(rad.call(0.2), yd + dh * 0.2),
			Vector2(rad.call(0.34), yd + dh * 0.34), Vector2(rd * 0.7, yd + dh * 0.34)]), 8)
	# The sensor head on the crown, two lenses in its front.
	var hz := r * 0.02
	k.color = GUNMETAL
	k.box(Vector3(r * 0.36, dh * 0.1 + 0.006, r * 0.3), Vector3(0.0, yd + dh * 0.95 - 0.003, hz))
	k.color = DETAIL
	k.box(Vector3(r * 0.3, dh * 0.04, r * 0.06), Vector3(0.0, yd + dh * 0.93, hz + r * 0.15 + r * 0.03))
	for lx: float in [-1.0, 1.0]:
		_weapons_lens(k, g, Vector3(lx * r * 0.08, yd + dh * 0.95, hz - r * 0.15), r * 0.05)
	# The gun: a round mantlet out of the dome's front, a ringed sleeve, barrel and brake.
	var by := yd + dh * 0.4
	var br := r * 0.09
	k.color = CAST
	_tube(k, Vector3(0.0, by, -r * 0.8), Vector3(0.0, by, -r * 0.95), br * 1.9, 12)
	_weapons_barrel(k, Vector3(0.0, by, -r * 0.95), -r * 0.9 - barrel, br, br * 1.65, br * 1.45, br * 1.4,
			clampf(barrel * 0.12, 0.08, 0.2), WPN_BARREL)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * r * r * (base + dome_h * 0.6) * 0.5 + barrel * br * br * 3.0
	var pts := PackedVector3Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector3(cos(a) * r * 1.05, y0, sin(a) * r * 1.05))
		pts.append(Vector3(cos(a) * r * 1.05, shelf, sin(a) * r * 1.05))
		pts.append(Vector3(cos(a) * rd, yd + dh * 0.1, sin(a) * rd))
		pts.append(Vector3(cos(a) * rd * 0.8, yd + dh * 0.6, sin(a) * rd * 0.8))
		pts.append(Vector3(cos(a) * rd * 0.43, yd + dh * 0.9, sin(a) * rd * 0.43))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * r * 0.18, top, hz + sz * r * 0.15))
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * br * 1.4, by + sy * br * 1.4, -r * 0.9 - barrel))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A heavy spinal gun barrel (the one out of the Dagger frigate's stern): a chamfered square
## base flange with bolts, then `segments` chunky octagonal sleeves along Y with chamfered
## ends, alternately in the material colour and grey, dark vent slats on their corners and
## bolts on their flats, dark rings between them with an amber charge lamp each side (±Z,
## PartShape.glow in `glow`), a power conduit down each side (±X) clamped to every sleeve,
## and a slotted muzzle brake at +Y: a collar, a baffle ring and a face ring round a dark
## bore. `radius` is the sleeves' (across the flats, about), `length` the whole part.
static func spinal_gun(radius: float = 0.45, length: float = 4.0, segments: int = 5,
		glow := Color(1.0, 0.55, 0.2)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var r := radius
	var h := length * 0.5
	var flange := 0.12
	var bs := r * 0.1                              # bolt heads, m
	# The base flange, two bolts on each side outside the sleeves.
	_railgun_stack(k, PartShapes._chamfer_rect(r * 2.4, r * 2.4, r * 0.3), [[-h, 1.0], [-h + flange, 1.0]], [DETAIL])
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_piping_bolts(k, Vector3(sx * r * 1.1, -h + flange, sz * r * 0.5), Vector3.UP, 0.0, 1, 0.0, bs, bs * 0.5)
			_piping_bolts(k, Vector3(sz * r * 0.5, -h + flange, sx * r * 1.1), Vector3.UP, 0.0, 1, 0.0, bs, bs * 0.5)
	var oct := PartShapes._chamfer_rect(r * 2.0, r * 2.0, r * 0.58)
	var y := -h + flange
	var pitch := (length - flange - 0.25) / float(segments)
	var sleeve := pitch * 0.72
	var e := minf(0.06, sleeve * 0.12)
	var cx := r + 0.045                            # the conduits' centre line, m
	for i in segments:
		# The sleeve, its ends chamfered.
		_railgun_stack(k, oct, [[y, 0.9], [y + e, 1.0], [y + sleeve - e, 1.0], [y + sleeve, 0.9]],
				[Color.WHITE if i % 2 == 0 else SLEEVE_GREY])
		for f in 8:
			var j := (f + 1) % 8
			var q := PackedVector3Array([Vector3(oct[f].x, y + e, oct[f].y), Vector3(oct[j].x, y + e, oct[j].y),
					Vector3(oct[j].x, y + sleeve - e, oct[j].y), Vector3(oct[f].x, y + sleeve - e, oct[f].y)])
			var mid := (oct[f] + oct[j]) * 0.5
			var out := Vector3(mid.x, 0.0, mid.y).normalized()
			if f % 2 == 1:
				# Vent slats on the corners.
				k.color = DARK
				for s in 3:
					var v := 0.22 + 0.2 * float(s)
					_railgun_slab(k, _railgun_sub(q, 0.2, 0.8, v, v + 0.1), out, 1.0, 0.008)
			elif absf(mid.y) > absf(mid.x):
				# A bolt near each end of the ±Z flats.
				k.color = DETAIL
				for v: float in [0.1, 0.9]:
					_piping_bolts(k, _railgun_sub(q, 0.5, 0.5, v, v)[0], out, 0.0, 1, 0.0, bs, bs * 0.4)
		# The conduit clamps on the ±X flats.
		k.color = DETAIL
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(0.07, 0.08, 0.1), Vector3(sx * (r + 0.035), y + sleeve * 0.5, 0.0))
		# The dark ring to the next sleeve, an amber charge lamp in a bezel on each ±Z flat.
		var gap := pitch - sleeve
		_railgun_stack(k, oct, [[y + sleeve, 0.8], [y + pitch, 0.8]], [DARK])
		for sz: float in [-1.0, 1.0]:
			k.color = RIM
			k.box(Vector3(0.18, gap * 0.55, 0.004), Vector3(0.0, y + sleeve + gap * 0.5, sz * (r * 0.8 + 0.002)))
			g.box(Vector3(0.12, gap * 0.3, 0.004), Vector3(0.0, y + sleeve + gap * 0.5, sz * (r * 0.8 + 0.005)))
		y += pitch
	# The power conduits from the flange to a gland box on the last sleeve.
	k.color = DARK
	for sx: float in [-1.0, 1.0]:
		_tube(k, Vector3(sx * cx, -h + flange, 0.0), Vector3(sx * cx, y - pitch + sleeve * 0.5, 0.0), 0.03, 8)
		k.color = DETAIL
		k.box(Vector3(0.06, 0.16, 0.14), Vector3(sx * (r + 0.03), y - pitch + sleeve * 0.5 + 0.12, 0.0))
		k.color = DARK
	# The muzzle brake: a collar, the dark barrel showing through the slot, a baffle ring and
	# the face ring round the bore.
	var ri := r * 0.45
	var ro := r * 0.78
	k.color = RIM
	k.lathe(PackedVector2Array([Vector2(ri, y), Vector2(ro, y), Vector2(ro, y + 0.07), Vector2(ri, y + 0.07)]), 16)
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(0.0, y + 0.07), Vector2(r * 0.5, y + 0.07), Vector2(r * 0.5, h - 0.06),
			Vector2(0.0, h - 0.06)]), 12)
	k.color = RIM
	k.lathe(PackedVector2Array([Vector2(ri, y + 0.11), Vector2(ro, y + 0.11), Vector2(ro, y + 0.15), Vector2(ri, y + 0.15)]), 16)
	k.lathe(PackedVector2Array([Vector2(ri, h - 0.06), Vector2(r * 0.75, h - 0.06), Vector2(r * 0.75, h), Vector2(ri, h)]), 16)
	k.color = GUN_BORE
	k.lathe(PackedVector2Array([Vector2(0.0, h - 0.06), Vector2(ri + 0.005, h - 0.06), Vector2(ri + 0.005, h - 0.05),
			Vector2(0.0, h - 0.05)]), 16)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = radius * radius * 3.3 * length * 0.4
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * radius * 1.2, -h, sz * radius * 1.2))
			pts.append(Vector3(sx * radius * 1.2, -h + flange, sz * radius * 1.2))
	for p in oct:
		pts.append(Vector3(p.x, -h + flange, p.y))
		pts.append(Vector3(p.x, y, p.y))
	for i in 8:
		var a := TAU * float(i) / 8.0
		pts.append(Vector3(cos(a) * radius * 0.75, h, sin(a) * radius * 0.75))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A mess table (the Dagger frigate's mess hall): a thick top in the material colour
## `length` along X and `width` deep with chamfered corners, a stainless trim band standing
## proud round its edge and a chrome condiment rail along its +Z side, two galvanised bearers
## under the overhang, on a graphite satin block plinth (brushed steel ribs at its panel
## joins, a brushed steel cap band under the top, a dark kick recess at its foot) standing
## on a cast floor plate with a blackened bolt in each corner. Stands on -Y.
static func mess_table(length: float = 1.8, width: float = 0.9, height: float = 0.8) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var top := 0.16                              # top, m
	var plate := 0.04                            # floor plate, m
	var kick := 0.08                             # kick recess, m
	var pl := Vector2(length * 0.55, width * 0.55)   # plinth, m
	var y_ped := -h + plate + kick               # foot of the plinth body
	var y_top := h - top                         # underside of the top
	# The floor plate and its bolts, the kick recess, the plinth.
	k.color = CAST
	_galley_slab(k, length * 0.62, width * 0.62, 0.05, -h, -h + plate, 0.01)
	k.color = FLANGE_BOLT
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.03, 0.012, 0.03), Vector3(sx * (length * 0.31 - 0.05), -h + plate + 0.004, sz * (width * 0.31 - 0.05)))
	k.color = DARK
	k.box(Vector3(pl.x - 0.08, kick, pl.y - 0.08), Vector3(0.0, -h + plate + kick * 0.5, 0.0))
	k.color = FURN_PLINTH
	k.box(Vector3(pl.x, y_top - 0.04 - y_ped, pl.y), Vector3(0.0, (y_top - 0.04 + y_ped) * 0.5, 0.0))
	# Steel ribs at the panel joins on the long faces, a cap band under the top.
	k.color = FURN_COLLAR
	var ribs := maxi(1, roundi(pl.x / 0.45) - 1)
	for i in ribs:
		var x := -pl.x * 0.5 + pl.x * float(i + 1) / float(ribs + 1)
		k.box(Vector3(0.03, y_top - 0.06 - y_ped, pl.y + 0.008), Vector3(x, (y_top - 0.06 + y_ped) * 0.5, 0.0))
	k.box(Vector3(pl.x + 0.012, 0.04, pl.y + 0.012), Vector3(0.0, y_top - 0.02, 0.0))
	# Two bearers under the top, out toward its ends.
	k.color = GALVANISED
	k.box(Vector3(length - 0.3, 0.03, 0.06), Vector3(0.0, y_top - 0.015, -pl.y * 0.3))
	k.box(Vector3(length - 0.3, 0.03, 0.06), Vector3(0.0, y_top - 0.015, pl.y * 0.3))
	# The top, its trim band and the condiment rail.
	k.color = Color.WHITE
	_galley_slab(k, length - 0.008, width - 0.008, 0.06, y_top, h)
	k.color = STAINLESS
	_galley_slab(k, length, width, 0.062, h - top * 0.62, h - top * 0.38)
	k.color = CHROME
	k.box(Vector3(length - 0.12, 0.012, 0.03), Vector3(0.0, h + 0.006, width * 0.5 - 0.1))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * width * top + length * width * 0.3 * (height - top)
	var col := BoxShape3D.new()
	col.size = Vector3(length, height, width)
	shape.collision = col
	return shape


## An SE2-style gravity generator (the Dagger frigate's, over the dome in its belly): a
## square plinth `size` across on a dark kick band, with a chamfered top, bolts along its
## edges and three lit status slots on its front (-Z); four corner posts braced to it and to a
## chamfered top frame with dark vent slots, all in the material colour; dark emitter
## pedestals wound with copper field coils rise from the plinth and hang from the frame,
## and a glowing core floats between them inside two banded rings held out to the posts on
## arms. Stands on -Y; `height` the whole part.
static func gravity_generator(size: float = 1.4, height: float = 1.8, glow := Color(0.35, 0.75, 1.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var h := height * 0.5
	var s := size * 0.5
	var plinth := 0.22
	var frame := 0.14
	var post := 0.14
	var ch := 0.03
	var sq := func(half: float, y: float) -> PackedVector3Array:
		return PackedVector3Array([Vector3(-half, y, -half), Vector3(half, y, -half), Vector3(half, y, half), Vector3(-half, y, half)])
	# The plinth: a dark kick band, then a slab with a chamfered top edge.
	var kick := 0.06
	k.color = DARK
	k.box(Vector3(size - 0.06, kick, size - 0.06), Vector3(0.0, -h + kick * 0.5, 0.0))
	k.color = Color.WHITE
	var yp := -h + plinth
	k.loft(sq.call(s, -h + kick), sq.call(s, yp - ch), false)
	k.loft(sq.call(s, yp - ch), sq.call(s - ch, yp), false)
	k.poly(sq.call(s, -h + kick), Vector3.DOWN)
	k.poly(sq.call(s - ch, yp), Vector3.UP)
	# The top frame: a slab chamfered on its top edge, dark vent slots on top.
	var yf := h - frame
	k.loft(sq.call(s, yf), sq.call(s, h - ch), false)
	k.loft(sq.call(s, h - ch), sq.call(s - ch, h), false)
	k.poly(sq.call(s, yf), Vector3.DOWN)
	k.poly(sq.call(s - ch, h), Vector3.UP)
	# Corner posts, each braced to the plinth and to the frame by two gussets.
	var gl := minf(0.24, size * 0.16)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(post, height - plinth - frame, post), Vector3(sx * (s - post * 0.5), (plinth - frame) * 0.5, sz * (s - post * 0.5)))
			var px := sx * (s - post)
			var pz := sz * (s - post)
			var cx := sx * (s - post * 0.5)
			var cz := sz * (s - post * 0.5)
			for y_end: Vector2 in [Vector2(yp, 1.0), Vector2(yf, -1.0)]:
				k.strut(Vector3(px + 0.01 * sx, y_end.x + y_end.y * gl, cz), Vector3(px - sx * gl, y_end.x + y_end.y * 0.012, cz), 0.04)
				k.strut(Vector3(cx, y_end.x + y_end.y * gl, pz + 0.01 * sz), Vector3(cx, y_end.x + y_end.y * 0.012, pz - sz * gl), 0.04)
	k.color = DARK
	k.box(Vector3(size * 0.7, 0.02, size * 0.7), Vector3(0.0, yf - 0.01, 0.0))
	for i in 4:
		k.box(Vector3(size * 0.5, 0.004, 0.03), Vector3(0.0, h + 0.002, -size * 0.18 + size * 0.12 * float(i)))
	# Bolts along the plinth's top, two a side between the posts.
	k.color = DETAIL
	for i in 4:
		var n := Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, PI * 0.5 * float(i))
		var t := n.cross(Vector3.UP)
		for f: float in [-0.25, 0.25]:
			k.box(Vector3(0.04, 0.02, 0.04), n * (s - ch - 0.05) + t * (f * size) + Vector3.UP * (yp + 0.01))
	# Status slots in a dark bezel on the plinth's front.
	var ys := -h + (kick + plinth - ch) * 0.5
	k.color = DARK
	k.box(Vector3(minf(0.36, size * 0.3), 0.06, 0.006), Vector3(0.0, ys, -s - 0.003))
	for i in 3:
		g.box(Vector3(0.07, 0.022, 0.006), Vector3(-0.1 + 0.1 * float(i), ys, -s - 0.008))
	# Emitter pedestals: a dark base drum, a core wound with three copper coils, a cap
	# narrowing toward the core; one rises from the plinth, one hangs from the frame.
	var r := s * 0.55
	var ped: Array[Vector2] = [Vector2(0.72 * r, 0.0), Vector2(0.72 * r, 0.05), Vector2(0.5 * r, 0.05)]
	var ped_cols: Array[Color] = [DARK, DARK]
	for c in 3:
		var d := 0.07 + 0.06 * float(c)
		ped.append_array([Vector2(0.5 * r, d), Vector2(0.62 * r, d), Vector2(0.62 * r, d + 0.04), Vector2(0.5 * r, d + 0.04)])
		ped_cols.append_array([DARK, COPPER, COPPER, COPPER])
	ped.append_array([Vector2(0.5 * r, 0.26), Vector2(0.35 * r, 0.3), Vector2(0.0, 0.3)])
	ped_cols.append_array([DARK, DARK, DARK])
	var lower := PackedVector2Array()
	for p in ped:
		lower.append(Vector2(p.x, yp + p.y))
	_piping_spin(k, Vector3.ZERO, Vector3.UP, lower, ped_cols, 14)
	var upper := PackedVector2Array()
	var upper_cols: Array[Color] = []
	for i in range(ped.size() - 1, -1, -1):
		upper.append(Vector2(ped[i].x, yf - ped[i].y))
		if i > 0:
			upper_cols.append(ped_cols[i - 1])
	_piping_spin(k, Vector3.ZERO, Vector3.UP, upper, upper_cols, 14)
	# Two banded rings round the core, each held out to the posts on four arms.
	var cy := (yp + 0.3 + yf - 0.3) * 0.5
	var arm_in := r * 1.08 * cos(PI * 0.25)
	for dy: float in [-1.0, 1.0]:
		var ry := cy + dy * r * 0.75
		k.color = DETAIL
		k.lathe(PackedVector2Array([Vector2(r * 0.95, ry - 0.04), Vector2(r * 1.1, ry - 0.04), Vector2(r * 1.1, ry + 0.04),
				Vector2(r * 0.95, ry + 0.04)]), 20)
		k.color = DARK
		k.lathe(PackedVector2Array([Vector2(r * 1.09, ry - 0.016), Vector2(r * 1.1 + 0.012, ry - 0.016),
				Vector2(r * 1.1 + 0.012, ry + 0.016), Vector2(r * 1.09, ry + 0.016)]), 20)
		k.color = Color.WHITE
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				k.strut(Vector3(sx * arm_in, ry, sz * arm_in), Vector3(sx * (s - post + 0.01), ry, sz * (s - post + 0.01)), 0.035)
	var core := PackedVector2Array([Vector2(0.0, cy - r * 0.95)])
	for i in 7:
		var a := -PI * 0.5 + PI * float(i + 1) / 8.0
		core.append(Vector2(cos(a) * r * 0.92, cy + sin(a) * r * 0.95))
	core.append(Vector2(0.0, cy + r * 0.95))
	g.lathe(core, 18)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size * size * (plinth + frame) + post * post * height * 4.0 + r * r * 2.0
	var col := BoxShape3D.new()
	col.size = Vector3(size, height, size)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


# --- Ranger parts (0.43) -------------------------------------------------------------------

## An SE2 hydrogen thruster (the Ranger's big stern engine and the two beside it): a square
## dark mount plate at -Y, a ribbed drum in the material colour with two fuel feeds rising
## from the plate into it and a heat-shield band, a stepped dark rim at +Y with a bolt ring
## round a pale beige liner that narrows to an injector ring and a glowing floor. Exhaust +Y.
## `radius` is the rim's.
static func hydrogen_engine(radius: float = 1.6, length: float = 2.2, glow := Color(1.0, 0.72, 0.4)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var r := radius
	var h := length * 0.5
	var seg := 24
	# A chamfered dark mount plate with a hex bolt in each corner.
	var plate_t := clampf(length * 0.045, 0.04, 0.12)
	var ph := r * 0.85
	k.color = DARK
	k.loft(_chamfer_ring(ph, -h, r * 0.22), _chamfer_ring(ph, -h + plate_t, r * 0.22))
	var d0 := -h + plate_t
	var bolt := maxf(0.012, r * 0.05)
	var bolt_h := clampf(r * 0.03, 0.008, 0.03)
	k.color = DETAIL
	for s: float in [-1.0, 1.0]:
		_thrusters_bolt(k, Vector3(-s * ph * 0.78, d0, s * ph * 0.78), bolt, bolt_h)
	# The drum: a hollow tapered barrel in the material colour, stiffened by eight ribs, one
	# grey band and a burnished heat-shield band under the rim.
	var rim0 := h - length * 0.32
	var rt := r * 0.76                       # bore, m
	var drum := func(y: float) -> float: return lerpf(r * 0.8, r * 0.9, (y - d0) / (rim0 - d0))
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(rt, d0), Vector2(r * 0.8, d0), Vector2(r * 0.9, rim0), Vector2(rt, rim0)]), seg)
	var hs := clampf(length * 0.07, 0.04, 0.2)
	k.color = HEAT_SHIELD
	k.lathe(PackedVector2Array([Vector2(rt, rim0 - hs), Vector2(drum.call(rim0 - hs) + r * 0.03, rim0 - hs),
			Vector2(r * 0.93, rim0), Vector2(rt, rim0)]), seg)
	k.color = DETAIL
	var bw := clampf(length * 0.025, 0.02, 0.06)
	var yb: float = lerpf(d0, rim0, 0.45)
	_thrusters_ring(k, drum.call(yb) - 0.02, drum.call(yb) + r * 0.03, yb - bw, yb + bw, seg)
	var rib := clampf(r * 0.05, 0.02, 0.1)
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-dir.z, 0.0, dir.x) * rib * 0.5
		var ring_a := PackedVector3Array()
		var ring_b := PackedVector3Array()
		for y: float in [d0, rim0 - hs - 0.004]:
			var at: Vector3 = dir * drum.call(y) + Vector3(0.0, y, 0.0)
			var ring := PackedVector3Array([at - dir * 0.01 - side, at - dir * 0.01 + side, at + dir * rib * 0.7 + side,
					at + dir * rib * 0.7 - side])
			if ring_a.is_empty():
				ring_a = ring
			else:
				ring_b = ring
		k.loft(ring_a, ring_b)
	# Two fuel feeds: a pipe up from the plate, elbowing into the drum through a flange.
	var pr := maxf(0.015, r * 0.045)
	var y_feed := lerpf(d0, rim0, 0.22)
	for a: float in [PI * 0.25, PI * 1.25]:
		var dir := Vector3(cos(a), 0.0, sin(a))
		var out := r * 0.86
		var base := dir * out + Vector3(0.0, d0, 0.0)
		var bend := dir * out + Vector3(0.0, y_feed, 0.0)
		k.color = DETAIL
		_tube(k, base, bend + Vector3(0.0, pr, 0.0), pr, 8)
		_tube(k, bend, dir * (drum.call(y_feed) - 0.02) + Vector3(0.0, y_feed, 0.0), pr, 8)
		k.color = DARK
		var fl: Vector3 = dir * (drum.call(y_feed) + pr * 0.6) + Vector3(0.0, y_feed, 0.0)
		_tube(k, fl - dir * pr * 0.6, fl + dir * pr * 0.4, pr * 1.6, 8)
		_tube(k, base - Vector3(0.0, 0.002, 0.0), base + Vector3(0.0, pr * 1.2, 0.0), pr * 1.5, 8)
	# The rim, stepped: a thick dark ring with a lower outer shelf carrying a ring of bolts.
	var shelf := clampf(length * 0.05, 0.03, 0.12)
	k.color = RIM
	_thrusters_ring(k, rt, r * 0.88, rim0, h, seg)
	_thrusters_ring(k, r * 0.88 - 0.004, r, rim0, h - shelf, seg)
	k.color = DETAIL
	var rim_bolts := 12
	for i in rim_bolts:
		var a := TAU * (float(i) + 0.5) / float(rim_bolts)
		_thrusters_bolt(k, Vector3(cos(a), 0.0, sin(a)) * r * 0.94 + Vector3(0.0, h - shelf, 0.0), bolt,
				minf(bolt_h, shelf * 0.6))
	# The bore: a beige liner narrowing to a dark floor with an injector ring round it.
	var deep := h - length * 0.6
	var rf := r * 0.3
	k.color = DARK
	_thrusters_ring(k, 0.0, rt, deep - clampf(length * 0.03, 0.01, 0.05), deep, seg)
	k.color = LINER
	k.lathe(PackedVector2Array([Vector2(rf, deep), Vector2(rf + rt - r * 0.72, deep), Vector2(rt, h - 0.01),
			Vector2(r * 0.72, h - 0.01)]), seg)
	k.color = DETAIL
	var inj := clampf(length * 0.03, 0.02, 0.08)
	var r_inj := lerpf(rf, r * 0.72, inj / (h - 0.01 - deep))
	_thrusters_ring(k, rf * 0.8, r_inj + r * 0.02, deep, deep + inj, seg)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = k.volume()
	var col := CylinderShape3D.new()
	col.radius = radius
	col.height = length
	shape.collision = col
	var g := MeshKit.new()
	_thrusters_ring(g, 0.0, rf * 0.75, deep + 0.003, deep + 0.003 + clampf(length * 0.015, 0.006, 0.03), 20)
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A workshop bench (the Ranger's aft workshop) `width` along X: a chamfered steel top with
## a dark rubber nosing and a rubber mat, on a cabinet in the material colour at the -X end
## (dark kick, three drawers with pulls and label plates) and two legs on steel feet at the
## other, an undershelf between them with a red toolbox on it; a bench vise near the +X end
## (base, body, jaws with steel plates, slide bar, screw and tommy bar); a tool board along
## the back edge with a steel edge frame, hammers, spanners and screwdrivers on pegs, and a
## shelf on two gussets at its top with bins on it and a lit strip in a dark housing under
## its front edge. Front -Z, stands on -Y; `height` is the top's, the board rises `board`
## above it.
static func workbench(width: float = 2.0, depth: float = 0.8, height: float = 0.95, board: float = 1.0) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var total := height + board
	var y0 := -total * 0.5
	var top_t := 0.06
	var y_top := y0 + height                  # the worktop's surface
	var w := width * 0.5
	var dd := depth * 0.5
	var stack := width * 0.3
	var cx := -w + stack * 0.5 + 0.02         # the cabinet's middle (x)
	var kick := 0.07
	# The cabinet: a dark kick, the carcass in the material colour, three drawers.
	k.color = DARK
	k.box(Vector3(stack - 0.04, kick, depth - 0.12), Vector3(cx, y0 + kick * 0.5, 0.02))
	k.color = Color.WHITE
	var ch := height - top_t - kick
	k.box(Vector3(stack, ch, depth - 0.06), Vector3(cx, y0 + kick + ch * 0.5, 0.0))
	var dh := ch / 3.0
	for i in 3:
		var dy := y0 + kick + dh * (float(i) + 0.5)
		k.color = DETAIL
		_seating_pad(k, Vector3(cx, dy, -dd + 0.03), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, stack * 0.5 - 0.025, dh * 0.5 - 0.015, 0.012, 0.006)
		k.color = DARK
		k.box(Vector3(0.14, 0.022, 0.02), Vector3(cx, dy + dh * 0.18, -dd + 0.008))
		k.color = PLATE
		k.box(Vector3(0.07, 0.03, 0.004), Vector3(cx, dy - dh * 0.15, -dd + 0.016))
	# Two legs on steel feet at the +X end, an undershelf with a toolbox on it.
	for sz: float in [-1.0, 1.0]:
		k.color = DARK
		k.box(Vector3(0.06, height - top_t - 0.025, 0.06), Vector3(w - 0.06, y0 + 0.025 + (height - top_t - 0.025) * 0.5, sz * (dd - 0.06)))
		k.color = DETAIL
		k.box(Vector3(0.08, 0.025, 0.08), Vector3(w - 0.06, y0 + 0.0125, sz * (dd - 0.06)))
	var s0 := -w + stack + 0.02
	var s1 := w - 0.09
	var y_sh := y0 + 0.16
	k.box(Vector3(s1 - s0, 0.025, depth - 0.14), Vector3((s0 + s1) * 0.5, y_sh, 0.0))
	var bx := minf(0.4, width * 0.2)
	var bc := Vector3(w * 0.35, y_sh + 0.0125 + 0.08, 0.0)
	k.color = BENCH_RED
	k.box(Vector3(bx, 0.16, 0.22), bc)
	k.color = DARK
	k.box(Vector3(bx + 0.006, 0.012, 0.226), bc + Vector3(0.0, 0.04, 0.0))
	k.color = DETAIL
	k.box(Vector3(bx * 0.5, 0.025, 0.025), bc + Vector3(0.0, 0.0925, 0.0))
	# The worktop: chamfered steel with a rubber nosing and a mat at the cabinet end.
	k.color = BENCH_STEEL
	_seating_pad(k, Vector3(0.0, y_top - top_t, 0.0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, w, dd, top_t, 0.012)
	k.color = DARK
	k.box(Vector3(width - 0.03, 0.025, 0.012), Vector3(0.0, y_top - top_t + 0.016, -dd + 0.001))
	_seating_pad(k, Vector3(-w * 0.45, y_top, -0.05), Vector3.RIGHT, Vector3.BACK, Vector3.UP, w * 0.3, dd * 0.6, 0.006, 0.003)
	# The vise: base, body with the fixed jaw, moving jaw, jaw plates, slide bar, screw and
	# tommy bar.
	var vx := w - 0.3
	var vz := -dd + 0.16                      # the fixed jaw's face
	k.color = BENCH_VISE
	k.box(Vector3(0.18, 0.03, 0.22), Vector3(vx, y_top + 0.015, -dd + 0.16))
	k.box(Vector3(0.14, 0.09, 0.1), Vector3(vx, y_top + 0.075, vz + 0.05))
	k.box(Vector3(0.14, 0.098, 0.05), Vector3(vx, y_top + 0.061, -dd + 0.035))
	k.color = DETAIL
	k.box(Vector3(0.16, 0.035, 0.012), Vector3(vx, y_top + 0.1, vz - 0.006))
	k.box(Vector3(0.16, 0.035, 0.012), Vector3(vx, y_top + 0.09, -dd + 0.066))
	k.box(Vector3(0.04, 0.03, vz - (-dd + 0.06)), Vector3(vx, y_top + 0.045, (vz - dd + 0.06) * 0.5))
	_tube(k, Vector3(vx, y_top + 0.06, -dd + 0.012), Vector3(vx, y_top + 0.06, -dd - 0.004), 0.012, 6)
	_tube(k, Vector3(vx - 0.1, y_top + 0.06, -dd + 0.0), Vector3(vx + 0.1, y_top + 0.06, -dd + 0.0), 0.007, 6)
	# The tool board with a steel edge frame.
	var bt := 0.05
	var by := y_top + board * 0.5
	var zb := dd - bt                         # the board's front face
	k.color = BENCH_BOARD
	k.box(Vector3(width, board, bt), Vector3(0.0, by, dd - bt * 0.5))
	k.color = DETAIL
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(width, 0.03, 0.008), Vector3(0.0, by + sy * (board * 0.5 - 0.015), zb - 0.004))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.03, board - 0.06, 0.008), Vector3(sx * (w - 0.015), by, zb - 0.004))
	# Tools on pegs: hammers, spanners and screwdrivers in turn.
	var tools := maxi(3, int(width / 0.35))
	var yh := by + board * 0.12
	for i in tools:
		var x := -w + width * (float(i) + 0.5) / float(tools)
		var z := zb - 0.02
		k.color = DETAIL
		k.box(Vector3(0.02, 0.02, 0.03), Vector3(x, yh + 0.035, zb - 0.015))
		match i % 3:
			0:
				k.box(Vector3(0.14, 0.05, 0.035), Vector3(x, yh, z))
				k.color = DARK
				k.box(Vector3(0.035, 0.26, 0.025), Vector3(x, yh - 0.155, z))
			1:
				k.box(Vector3(0.03, 0.3, 0.012), Vector3(x, yh - 0.17, z))
				k.box(Vector3(0.075, 0.05, 0.012), Vector3(x, yh - 0.01, z))
				k.box(Vector3(0.06, 0.05, 0.012), Vector3(x, yh - 0.33, z))
			_:
				k.box(Vector3(0.012, 0.18, 0.012), Vector3(x, yh - 0.16, z))
				k.color = BENCH_RED
				k.box(Vector3(0.035, 0.1, 0.035), Vector3(x, yh - 0.03, z))
	# The shelf on two gussets, bins on it, the lit strip in a housing under its front.
	var ys := y0 + total - 0.12
	var shd := 0.22
	k.color = DETAIL
	k.box(Vector3(width - 0.04, 0.03, shd), Vector3(0.0, ys, zb - shd * 0.5))
	for sx: float in [-1.0, 1.0]:
		var gx := sx * (w - 0.12)
		_prism_x(k, PackedVector2Array([Vector2(zb, ys - 0.015), Vector2(zb, ys - 0.135), Vector2(zb - 0.17, ys - 0.015)]),
				gx - 0.01, gx + 0.01)
	var bins := [[-0.6, Color.WHITE], [-0.2, BENCH_VISE], [0.5, BENCH_RED]]
	for b: Array in bins:
		k.color = b[1]
		k.box(Vector3(0.16, 0.08, 0.14), Vector3(w * float(b[0]), ys + 0.055, zb - 0.1))
	k.color = DARK
	k.box(Vector3(width - 0.2, 0.025, 0.05), Vector3(0.0, ys - 0.0275, zb - shd + 0.03))
	g.box(Vector3(width - 0.26, 0.008, 0.03), Vector3(0.0, ys - 0.044, zb - shd + 0.03))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = stack * height * depth * 0.5 + width * depth * top_t + width * board * bt
	var col := BoxShape3D.new()
	col.size = Vector3(width, total, depth)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.9, 0.7)
	return shape


# --- Talon parts (0.44) --------------------------------------------------------------------

## The recessed scoop in a Talon pod's raked red tip (the "talons"): a raised rim in the
## material colour (a titanium lip round its inner edge, steel bolts) round a dark trough
## `width` across and `length` long (along Z) with gunmetal ribs, two round thruster discs
## set in the trough floor one behind the other, each a titanium lip round a heat-blued
## floor with a cast hub, gunmetal stator vanes and a glowing ring. Face +Y, base on -Y; `depth` the whole part.
static func talon_intake(width: float = 1.6, length: float = 2.8, depth: float = 0.22,
		glow := Color(1.0, 0.45, 0.3)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := depth * 0.5
	var w := width * 0.5
	var l := length * 0.5
	var rim := minf(width, length) * 0.1
	# The rim: four bars standing the full depth.
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(rim, depth, length), Vector3(sx * (w - rim * 0.5), 0.0, 0.0))
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(width - 2.0 * rim, depth, rim), Vector3(0.0, 0.0, sz * (l - rim * 0.5)))
	# A titanium lip round the rim's inner top edge, bolts down the rim's sides.
	var lip := rim * 0.28
	k.color = AERO_EDGE
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(lip, 0.006, length - 2.0 * rim + 2.0 * lip), Vector3(sx * (w - rim + lip * 0.5), h + 0.003, 0.0))
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(width - 2.0 * rim, 0.006, lip), Vector3(0.0, h + 0.003, sz * (l - rim + lip * 0.5)))
	k.color = DETAIL
	var bolts := maxi(3, int(length / 0.35))
	for sx: float in [-1.0, 1.0]:
		for i in bolts:
			var z := lerpf(-l + rim * 0.5, l - rim * 0.5, float(i) / float(bolts - 1))
			_thrusters_bolt(k, Vector3(sx * (w - rim * 0.4), h, z), rim * 0.12, 0.008)
	# The trough floor, dark, sunk to a third of the depth, with gunmetal ribs across it.
	k.color = DARK
	var floor_t := depth * 0.3
	k.box(Vector3(width - 2.0 * rim, floor_t, length - 2.0 * rim), Vector3(0.0, -h + floor_t * 0.5, 0.0))
	var ribs := maxi(2, int(length / 0.5))
	k.color = GUNMETAL
	for i in ribs:
		var z := -l + rim + (length - 2.0 * rim) * (float(i) + 0.5) / float(ribs)
		k.box(Vector3(0.05, 0.03, 0.04), Vector3(-w + rim + 0.04, -h + floor_t + 0.015, z))
		k.box(Vector3(0.05, 0.03, 0.04), Vector3(w - rim - 0.04, -h + floor_t + 0.015, z))
	# Two discs in the floor along Z.
	var r := minf(w - rim - 0.06, (l - rim) * 0.42)
	var g := MeshKit.new()
	var y0 := -h + floor_t
	for sz: float in [-1.0, 1.0]:
		var c := Vector3(0.0, 0.0, sz * (l - rim) * 0.5)
		var disc := MeshKit.new()
		disc.color = AERO_EDGE
		disc.lathe(PackedVector2Array([Vector2(r * 0.78, y0), Vector2(r, y0), Vector2(r * 0.95, y0 + depth * 0.4),
				Vector2(r * 0.78, y0 + depth * 0.4)]), 22)
		disc.color = RIM
		disc.lathe(PackedVector2Array([Vector2(0.0, y0), Vector2(r * 0.79, y0), Vector2(r * 0.79, y0 + depth * 0.15),
				Vector2(0.0, y0 + depth * 0.15)]), 18)
		disc.color = HUB
		disc.lathe(PackedVector2Array([Vector2(0.0, y0 + depth * 0.15), Vector2(r * 0.25, y0 + depth * 0.15),
				Vector2(r * 0.2, y0 + depth * 0.32), Vector2(0.0, y0 + depth * 0.34)]), 14)
		# Four stator vanes from the hub out to the lip, over the glowing ring.
		var vy := y0 + depth * 0.22
		disc.color = GUNMETAL
		for a: float in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
			var dir := Vector3(cos(a), 0.0, sin(a))
			disc.strut(dir * r * 0.2 + Vector3(0.0, vy, 0.0), dir * r * 0.8 + Vector3(0.0, vy, 0.0), maxf(0.012, r * 0.05))
		for i in disc.verts.size():
			k.verts.append(disc.verts[i] + c)
			k.normals.append(disc.normals[i])
			k.colors.append(disc.colors[i])
		var ring := MeshKit.new()
		ring.lathe(PackedVector2Array([Vector2(r * 0.45, y0 + depth * 0.15), Vector2(r * 0.68, y0 + depth * 0.15),
				Vector2(r * 0.68, y0 + depth * 0.17), Vector2(r * 0.45, y0 + depth * 0.17)]), 18)
		for i in ring.verts.size():
			g.verts.append(ring.verts[i] + c)
			g.normals.append(ring.normals[i])
			g.colors.append(Color.WHITE)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = (width * length - (width - 2.0 * rim) * (length - 2.0 * rim)) * depth + width * length * floor_t * 0.8
	var col := BoxShape3D.new()
	col.size = Vector3(width, depth, length)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## The Talon's main engine (and the Corsair's, Sentinel's and Claymore's): a stadium-shaped
## (rounded oblong) housing `width` across and `height` tall: a dark mount flange bolted
## round its ledge, a drum in the material colour with a steel band and a heat-shield band,
## a thick pale rim round its +Y face framing a dark recess, and two big round nozzles side
## by side along X in it: dark flanges (bolted on big engines), steel collars, pale lips,
## ceramic liners down to injector floors with a grey hub and a glowing ring
## (PartShape.glow). Exhaust +Y; `depth` the whole part.
static func oval_engine(width: float = 2.6, height: float = 1.5, depth: float = 1.0,
		glow := Color(0.45, 0.75, 1.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var h := depth * 0.5
	var ring := func(inset: float) -> PackedVector2Array:
		return PartShapes._stadium(width - inset * 2.0, height - inset * 2.0, 8)
	var nr := minf((height - 0.3) * 0.5 - 0.03, (width - 0.3) * 0.25 - 0.03)
	_engines_twin_housing(k, g, ring, depth, minf(width, height) * 0.03, 0.15, nr, (width - 0.3) * 0.25, true)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * depth * 0.4
	var outer: PackedVector2Array = ring.call(0.0)
	var pts := PackedVector3Array()
	for p in outer:
		pts.append(Vector3(p.x, -h, p.y))
		pts.append(Vector3(p.x, h, p.y))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## The Talon's stern spoiler: a flat wing `span` along X and `chord` along Z in the material
## colour, its leading edge (-Z) bevelled, a red trim strip along both edges, and an
## up-turned red end fin at each tip rising `fin_h` and swept back; a glowing light strip runs
## along the top of the trailing edge. A dark flap hinge line and panel lines cross the top
## with two anodised actuator fairings over the hinge; bolts line the fins' roots, carbon
## fibre caps run along the fins' top edges and a small lit nav lamp sits high on each fin's outer face
## (PartShape.glow) under a faceted clear lens (PartShape.glass). Base on -Y (the wing's underside), centred on the wing slab. Collision
## is the hull of the slab and the fins.
static func spoiler_wing(span: float = 6.0, chord: float = 1.8, thickness: float = 0.14, fin_h: float = 0.6,
		trim := Color(0.72, 0.1, 0.08)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var w := span * 0.5
	var c := chord * 0.5
	var t := thickness * 0.5
	var bevel := minf(chord * 0.2, 0.3)
	# The slab: a box with its front lower edge cut back (side outline in z, y, extruded along X).
	var side := PackedVector2Array([Vector2(-c, t), Vector2(c, t), Vector2(c, -t), Vector2(-c + bevel, -t)])
	var sa := PackedVector3Array()
	var sb := PackedVector3Array()
	for p in side:
		sa.append(Vector3(-w, p.y, p.x))
		sb.append(Vector3(w, p.y, p.x))
	k.loft(sa, sb)
	# Red trim strips along the leading and trailing edges, a hair proud of the top.
	k.color = trim
	var strip := 0.1
	k.box(Vector3(span - 0.02, 0.012, strip), Vector3(0.0, t + 0.006, -c + strip * 0.5 + 0.01))
	k.box(Vector3(span - 0.02, thickness * 0.6, 0.012), Vector3(0.0, 0.0, c + 0.006))
	# The end fins: tapered slabs rising from each tip, swept back, red.
	var fin_t := thickness * 0.8
	for sx: float in [-1.0, 1.0]:
		var x := sx * (w + fin_t * 0.5 + 0.005)
		var outline := PackedVector2Array([Vector2(-c, -t), Vector2(c, -t), Vector2(c + chord * 0.25, t + fin_h),
				Vector2(-c + chord * 0.55, t + fin_h)])
		var fa := PackedVector3Array()
		var fb := PackedVector3Array()
		for p in outline:
			fa.append(Vector3(x - fin_t * 0.5, p.y, p.x))
			fb.append(Vector3(x + fin_t * 0.5, p.y, p.x))
		k.loft(fa, fb)
	# Dark vents across the middle of the top.
	k.color = DARK
	for i in 3:
		var z := lerpf(-c * 0.4, c * 0.4, float(i) / 2.0)
		k.box(Vector3(span * 0.25, 0.012, 0.06), Vector3(0.0, t + 0.006, z))
	# The flap: a dark hinge line across the top at 70% chord, two anodised actuator fairings
	# over it, and dark panel lines dividing the span in three.
	var zh := lerpf(-c, c, 0.7)
	var lw := clampf(chord * 0.008, 0.006, 0.014)
	k.box(Vector3(span - 0.1, 0.008, lw), Vector3(0.0, t + 0.004, zh))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(lw, 0.008, chord - bevel - 0.2), Vector3(sx * span / 6.0, t + 0.004, (bevel - 0.04) * 0.5))
	k.color = ANODISED
	var fw := clampf(chord * 0.05, 0.03, 0.1)
	var fh := minf(thickness * 0.45, 0.06)
	for sx: float in [-1.0, 1.0]:
		var fx := sx * span * 0.32
		k.loft(PackedVector3Array([Vector3(fx - fw * 0.5, t, zh - chord * 0.16), Vector3(fx + fw * 0.5, t, zh - chord * 0.16),
				Vector3(fx + fw * 0.5, t, zh + chord * 0.12), Vector3(fx - fw * 0.5, t, zh + chord * 0.12)]),
				PackedVector3Array([Vector3(fx - fw * 0.35, t + fh, zh - chord * 0.08), Vector3(fx + fw * 0.35, t + fh, zh - chord * 0.08),
				Vector3(fx + fw * 0.35, t + fh, zh + chord * 0.06), Vector3(fx - fw * 0.35, t + fh, zh + chord * 0.06)]))
	# Bolts along each end fin's root on the wing's top, a carbon cap on each fin's top edge.
	var br := clampf(chord * 0.012, 0.008, 0.022)
	for sx: float in [-1.0, 1.0]:
		k.color = DETAIL
		for i in 3:
			var z := lerpf(-c + bevel, c - 0.1, (float(i) + 0.5) / 3.0)
			_thrusters_bolt(k, Vector3(sx * (w - br * 2.5), t, z), br, 0.008)
		k.color = CARBON
		var fx := sx * (w + fin_t * 0.5 + 0.005)
		var z0 := -c + chord * 0.55
		var z1 := c + chord * 0.25
		k.box(Vector3(fin_t * 0.6, 0.008, (z1 - z0) * 0.6), Vector3(fx, t + fin_h + 0.004, z0 + (z1 - z0) * 0.32))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = span * chord * thickness * 0.9 + 2.0 * chord * fin_h * fin_t * 0.7
	var pts := PackedVector3Array()
	for p in side:
		for sx: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * (w + fin_t + 0.005), p.y, p.x))
	for sx: float in [-1.0, 1.0]:
		pts.append(Vector3(sx * (w + fin_t + 0.005), t + fin_h, c + chord * 0.25))
		pts.append(Vector3(sx * (w + fin_t + 0.005), t + fin_h, -c + chord * 0.55))
		pts.append(Vector3(sx * (w + fin_t + 0.005), -t, c + chord * 0.25))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	var g := MeshKit.new()
	g.box(Vector3(span - 0.4, 0.014, 0.05), Vector3(0.0, t + 0.007, c - 0.06))
	# Navigation lamps on the end fins' outer faces, high at the trailing edge.
	var lh := clampf(fin_h * 0.12, 0.03, 0.08)
	var ll := clampf(chord * 0.08, 0.05, 0.16)
	var ly := t + fin_h - lh * 1.2
	var lz := c + chord * 0.25 * (ly + t) / (fin_h + 2.0 * t) - ll * 0.8
	# Each under a faceted clear lens a few millimetres proud (the lamps are white, as the
	# light strip: one glow colour per part).
	var gk := MeshKit.new()
	for sx: float in [-1.0, 1.0]:
		g.box(Vector3(0.004, lh, ll), Vector3(sx * (w + fin_t + 0.007), ly, lz))
		_navlamps_lens(gk, Vector3(sx * (w + fin_t + 0.005), ly, lz), Vector3(sx, 0.0, 0.0), Vector3.BACK,
				ll * 0.62, lh * 0.62, 0.014)
	shape.glass = gk.finish()
	shape.glass_kind = Glazing.Kind.CLEAR
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.97, 0.92)
	return shape


# --- Claymore parts (0.45) ------------------------------------------------------------------

## The Claymore's payload: `cols` by `rows` bombs of `radius`, each `length` long lying
## along Z (nose toward -Z), on a cradle: a dark base plate, an end frame at each end (a
## post either side of every column, a cross bar under every row), and under every row a
## pair of cross bars on side rails with a dark saddle pad under each bomb. Each bomb is
## eight-sided and flat-shaded: a steel fuse tip, an ogive nose, a yellow band behind it,
## the body, a tapering tail with a dark cap and a cross of dark fins. Stands on -Y.
## Collision is the box round it all.
static func bomb_rack(cols: int = 2, rows: int = 2, radius: float = 0.26, length: float = 2.2) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var pitch := radius * 2.0 + 0.1
	var base_t := 0.06
	var width := float(cols) * pitch + 0.1
	var height := float(rows) * pitch + base_t + 0.04
	var depth := length + 0.16
	var hx := width * 0.5
	var hy := height * 0.5
	var hz := depth * 0.5
	var h := length * 0.5
	k.color = DARK
	k.box(Vector3(width, base_t, depth), Vector3(0.0, -hy + base_t * 0.5, 0.0))
	# The end frames: a post either side of each column, a cross bar under each row.
	k.color = DETAIL
	for sz: float in [-1.0, 1.0]:
		var z := sz * (hz - 0.04)
		for c in cols + 1:
			var x := -hx + 0.05 + float(c) * pitch
			k.box(Vector3(0.05, height - base_t, 0.06), Vector3(x, base_t * 0.5, z))
		for r in rows:
			var y := -hy + base_t + float(r) * pitch + 0.05
			k.box(Vector3(width - 0.04, 0.05, 0.08), Vector3(0.0, y, z))
		k.box(Vector3(width - 0.04, 0.05, 0.08), Vector3(0.0, hy - 0.025, z))
	# Under each row: side rails from frame to frame, two cross bars the bombs sit on.
	var zs := length * 0.22                       # cross bars either side of the middle, m
	for r in rows:
		var y := -hy + base_t + float(r) * pitch + 0.025
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(0.04, 0.05, depth - 0.16), Vector3(sx * (hx - 0.05), y, 0.0))
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(width - 0.12, 0.05, 0.06), Vector3(0.0, y, sz * zs))
	# The bombs, eight-sided with flats top, bottom and sides.
	var n := 8
	var ph := 0.5
	for c in cols:
		for r in rows:
			var cy := -hy + base_t + 0.05 + pitch * float(r) + radius
			var cx := -hx + 0.05 + pitch * (float(c) + 0.5)
			var at := func(z: float, f: float) -> PackedVector3Array:
				return _stowage_ring(Vector3(cx, cy, z), radius * f, n, true, ph)
			# Saddle pads on the cross bars.
			k.color = DARK
			for sz: float in [-1.0, 1.0]:
				k.box(Vector3(radius * 1.1, radius * 0.12, 0.08), Vector3(cx, cy - radius * 0.94, sz * zs))
			# Fuse tip, nose.
			var tip: PackedVector3Array = at.call(-h, 0.14)
			var fuse: PackedVector3Array = at.call(-h + length * 0.05, 0.42)
			var ogive: PackedVector3Array = at.call(-h + length * 0.16, 0.84)
			var full: PackedVector3Array = at.call(-h + length * 0.28, 1.0)
			var aft: PackedVector3Array = at.call(h - length * 0.15, 1.0)
			var tail: PackedVector3Array = at.call(h - length * 0.02, 0.52)
			k.color = DETAIL
			k.poly(tip, Vector3.FORWARD)
			k.loft(tip, fuse, false)
			k.color = BOMB_OLIVE
			k.loft(fuse, ogive, false)
			k.loft(ogive, full, false)
			k.loft(full, aft, false)
			k.loft(aft, tail, false)
			k.color = DARK
			k.poly(tail, Vector3.BACK)
			# The band behind the nose.
			k.color = BOMB_BAND
			var b0: PackedVector3Array = at.call(-h + length * 0.3, 1.035)
			var b1: PackedVector3Array = at.call(-h + length * 0.36, 1.035)
			k.loft(b0, b1)
			# Fins: a cross over the tail.
			k.color = DARK
			var fl := length * 0.18
			var fz := h - fl * 0.5 - length * 0.01
			k.box(Vector3(radius * 1.94, 0.02, fl), Vector3(cx, cy, fz))
			k.box(Vector3(0.02, radius * 1.94, fl), Vector3(cx, cy, fz))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * depth * base_t + float(cols * rows) * PI * radius * radius * length * 0.8
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth)
	shape.collision = col
	return shape


## The Claymore's dorsal spine: a keel `length` along Z, `width` across its foot and `height`
## tall, in the hull's paint, its top narrowed by chamfers, its last quarter tapering down
## to a low point at +Z; gunmetal ribs, `ribs` of them, wrap its top and upper sides, a hair
## proud. A gunmetal doubler strip and a dark seam run along each side of the foot, a
## titanium cap strip down the ridge, a bolted cast plate on the blunt front (-Z) and a
## red-lit anti-collision beacon (PartShape.glow) on a plastic base on the ridge between the
## first two ribs, under a faceted red dome lens (PartShape.glass). Base on -Y. Collision is the hull of
## the keel.
static func ribbed_spine(length: float = 10.0, width: float = 0.7, height: float = 0.6, ribs: int = 14) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hw := width * 0.5
	var hh := height * 0.5
	var hz := length * 0.5
	var section := PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh * 0.1), Vector2(hw * 0.45, hh),
			Vector2(-hw * 0.45, hh), Vector2(-hw, hh * 0.1)])
	var taper := length * 0.25
	var tail := PackedVector2Array()
	for p in section:
		tail.append(Vector2(p.x * 0.35, -hh + (p.y + hh) * 0.3))
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	var c := PackedVector3Array()
	for i in section.size():
		a.append(Vector3(section[i].x, section[i].y, -hz))
		b.append(Vector3(section[i].x, section[i].y, hz - taper))
		c.append(Vector3(tail[i].x, tail[i].y, hz))
	k.loft(a, b)
	k.loft(b, c)
	# Ribs over the full-height part, each a band round the top and the upper sides.
	k.color = GUNMETAL
	var run := length - taper - 0.3
	for i in ribs:
		var z := -hz + 0.15 + run * (float(i) + 0.5) / float(ribs)
		var rib := PackedVector2Array()
		for p in section:
			var q := p
			if q.y > -hh + 0.01:
				q = Vector2(p.x * 1.0 + signf(p.x) * 0.025, p.y + (0.025 if p.y > hh * 0.5 else 0.0))
			else:
				q = Vector2(p.x + signf(p.x) * 0.025, -hh + height * 0.35)
			rib.append(q)
		var ra := PackedVector3Array()
		var rb := PackedVector3Array()
		for p in rib:
			ra.append(Vector3(p.x, p.y, z - 0.07))
			rb.append(Vector3(p.x, p.y, z + 0.07))
		k.loft(ra, rb)
	# A gunmetal doubler strip along each side of the foot, a dark seam above it.
	var zf := hz - taper
	for sx: float in [-1.0, 1.0]:
		k.color = GUNMETAL
		k.loft(PackedVector3Array([Vector3(sx * (hw - 0.002), -hh, -hz + 0.02), Vector3(sx * (hw + 0.02), -hh, -hz + 0.02),
				Vector3(sx * (hw - 0.002), -hh + height * 0.14, -hz + 0.02)]),
				PackedVector3Array([Vector3(sx * (hw - 0.002), -hh, zf), Vector3(sx * (hw + 0.02), -hh, zf),
				Vector3(sx * (hw - 0.002), -hh + height * 0.14, zf)]))
		k.color = DARK
		var x := sx * (hw + 0.002)
		var y := -hh + height * 0.24
		k.quad(Vector3(x, y - 0.008, -hz + 0.04), Vector3(x, y - 0.008, zf), Vector3(x, y + 0.008, zf), Vector3(x, y + 0.008, -hz + 0.04),
				Vector3(sx, 0.0, 0.0))
	# A titanium cap strip down the ridge between the ribs, and a bolted cast end plate on
	# the blunt front (-Z).
	k.color = AERO_EDGE
	k.box(Vector3(hw * 0.5, 0.008, zf + hz - 0.08), Vector3(0.0, hh + 0.004, (-hz + zf) * 0.5))
	var front := PackedVector3Array()
	for p in section:
		front.append(Vector3(p.x * 0.8, -hh + (p.y + hh) * 0.8 + 0.02, -hz - 0.004))
	k.color = CAST
	k.poly(front, Vector3.FORWARD)
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for fy: float in [0.3, 0.7]:
			_gear_bolt(k, Vector3(sx * hw * 0.55, -hh + height * fy * 0.8 + 0.02, -hz - 0.004), Vector3.FORWARD, 0.02, 0.008)
	# An anti-collision beacon on the ridge near the front: a plastic base and a red lens.
	var bz := -hz + 0.15 + run / float(maxi(ribs, 1))      # between the first two ribs, m
	k.color = PLASTIC_DARK
	k.box(Vector3(hw * 0.4, 0.018, 0.12), Vector3(0.0, hh + 0.017, bz))
	var g := MeshKit.new()
	g.box(Vector3(hw * 0.25, 0.006, 0.07), Vector3(0.0, hh + 0.029, bz))
	var gk := MeshKit.new()
	_navlamps_lens(gk, Vector3(0.0, hh + 0.026, bz), Vector3.UP, Vector3.RIGHT, hw * 0.18, 0.052, 0.022)
	var shape := PartShapes.PartShape.new()
	shape.glass = gk.finish()
	shape.glass_kind = Glazing.Kind.RED
	shape.mesh = k.finish()
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.18, 0.12)
	shape.volume = width * height * 0.8 * (length - taper * 0.6)
	var pts := PackedVector3Array()
	for p in section:
		pts.append(Vector3(p.x + signf(p.x) * 0.025, p.y + (0.025 if p.y > hh * 0.5 else 0.0), -hz))
		pts.append(Vector3(p.x + signf(p.x) * 0.025, p.y + (0.025 if p.y > hh * 0.5 else 0.0), hz - taper))
	for p in tail:
		pts.append(Vector3(p.x, p.y, hz))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	return shape


## The Claymore's chin cannon (the "devastating frontal firepower"): a dark chamfered mount
## plate on -Y bolted at its corners, an octagonal housing drum of `radius` in the material
## colour with two dark clamp bands and a louvred cooling vent on four of its facets, a
## heat-tinted band under a thick bevelled pale rim bolted round its +Y face, and in the
## recess a ring of `bores` hollow dark barrels with steel muzzle collars round a central
## one. Each bore glows red deep inside, and short lit slits between the barrels show the
## heat behind the face (PartShape.glow). `length` is the whole part along Y.
static func cannon_maw(radius: float = 0.8, length: float = 1.4, bores: int = 8, glow := Color(1.0, 0.18, 0.12)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var h := length * 0.5
	var plate_t := 0.08
	# The mount plate, its corners cut, a bolt in each corner clear of the drum.
	var ph := radius * 0.85
	k.color = DARK
	k.loft(_chamfer_ring(ph, -h, ph * 0.2), _chamfer_ring(ph, -h + plate_t, ph * 0.2))
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_gear_bolt(k, Vector3(sx * ph * 0.74, -h + plate_t, sz * ph * 0.74), Vector3.UP, radius * 0.05, radius * 0.04)
	# The housing: an octagonal drum flaring out of a stepped foot.
	var d0 := -h + plate_t
	var rim := 0.1
	var yr := h - rim                       # the rim's foot, m
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(0.0, d0), Vector2(radius * 0.92, d0), Vector2(radius, d0 + 0.15),
			Vector2(radius, yr), Vector2(0.0, yr)]), 8)
	# Two dark clamp bands, a heat-tinted band under the rim.
	k.color = DARK
	var bands: Array[float] = []
	for t: float in [0.3, 0.6]:
		var y := lerpf(d0, yr, t)
		bands.append(y)
		k.lathe(PackedVector2Array([Vector2(radius * 0.98, y - 0.04), Vector2(radius * 1.02, y - 0.04),
				Vector2(radius * 1.02, y + 0.04), Vector2(radius * 0.98, y + 0.04)]), 8)
	k.color = HEAT_SHIELD
	var hs := minf(0.08, (yr - bands[1]) * 0.3)
	k.lathe(PackedVector2Array([Vector2(radius * 0.98, yr - hs), Vector2(radius * 1.01, yr - hs),
			Vector2(radius * 1.01, yr), Vector2(radius * 0.98, yr)]), 8)
	# Louvred cooling vents on four facets, between the bands.
	var ap := radius * cos(PI / 8.0)         # the drum's flat facets stand this far out, m
	var vy := (bands[0] + bands[1]) * 0.5
	var vh := (bands[1] - bands[0] - 0.08) * 0.38
	for i in 4:
		var a := TAU * (float(i * 2) + 0.5) / 8.0
		var n := Vector3(cos(a), 0.0, sin(a))
		var u := Vector3(-sin(a), 0.0, cos(a))
		_cabinets_louvre(k, n * ap + Vector3(0.0, vy, 0.0), u, Vector3.UP, n, radius * 0.24, vh,
				clampi(int(vh * 2.0 / 0.04), 3, 6), radius * 0.02)
	# The rim: a thick bevelled octagon in bright metal, bolted round its top.
	k.color = TRIM
	k.lathe(PackedVector2Array([Vector2(radius * 0.8, yr), Vector2(radius, yr), Vector2(radius, h - rim * 0.35),
			Vector2(radius * 0.94, h), Vector2(radius * 0.82, h), Vector2(radius * 0.8, h - rim * 0.2)]), 8)
	k.color = DETAIL
	for i in 8:
		var a := TAU * float(i) / 8.0
		_gear_bolt(k, Vector3(cos(a), 0.0, sin(a)) * radius * 0.87 + Vector3(0.0, h, 0.0), Vector3.UP,
				radius * 0.035, minf(0.012, radius * 0.025))
	# The recessed face and the barrels standing out of it.
	k.color = Color(0.12, 0.12, 0.13)
	var face := yr - 0.02
	k.lathe(PackedVector2Array([Vector2(0.0, yr - 0.04), Vector2(radius * 0.81, yr - 0.04), Vector2(radius * 0.81, face),
			Vector2(0.0, face)]), 8)
	var br := radius * 0.13
	var ring := radius * 0.55
	var ytip := h - 0.03
	var cl := minf(0.06, (ytip - face) * 0.25)   # muzzle collar length, m
	var mouths: Array[Vector3] = [Vector3.ZERO]
	for i in bores:
		var a := TAU * float(i) / float(bores)
		mouths.append(Vector3(cos(a) * ring, 0.0, sin(a) * ring))
	for m in mouths:
		var xf := Transform3D(Basis(), m)
		k.color = RIM
		_launchers_lathe(k, PackedVector2Array([Vector2(br * 0.65, face), Vector2(br, face), Vector2(br, ytip - cl),
				Vector2(br * 0.65, ytip - cl)]), 12, xf)
		k.color = DETAIL
		_launchers_lathe(k, PackedVector2Array([Vector2(br * 0.65, ytip - cl), Vector2(br * 1.14, ytip - cl),
				Vector2(br * 1.14, ytip - cl * 0.25), Vector2(br * 1.06, ytip), Vector2(br * 0.65, ytip)]), 12, xf)
		_launchers_lathe(g, PackedVector2Array([Vector2(0.0, face + 0.012), Vector2(br * 0.64, face + 0.012),
				Vector2(br * 0.64, face + 0.03), Vector2(0.0, face + 0.03)]), 12, xf)
	# Lit heat slits in the face between the outer barrels.
	for i in bores:
		var a := TAU * (float(i) + 0.5) / float(bores)
		var dir := Vector3(cos(a), 0.0, sin(a))
		g.strut(dir * radius * 0.3 + Vector3(0.0, face, 0.0), dir * radius * 0.7 + Vector3(0.0, face, 0.0), radius * 0.035)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * radius * radius * length * 0.5
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * radius * 0.85, -h, sz * radius * 0.85))
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector3(cos(a) * radius * 1.02, d0, sin(a) * radius * 1.02))
		pts.append(Vector3(cos(a) * radius * 1.02, h, sin(a) * radius * 1.02))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A barred cage locker (the Claymore's armoury and the warships' weapon cages) `width` by
## `height` by `depth`: a dark back plate (+Z) and floor, corner posts, frames top and
## bottom, a roof with a pale stencil plate on its front rail, vertical bars down the sides
## and the front, the front's middle a door in its own frame on two dark hinge knuckles
## with a steel kick plate, a dark lock box with a steel key plate and a pull handle. Inside,
## rifles stand in a butt tray against a rack rail on the back plate, under a shelf with two
## ammo cans. Unlit. Stands on -Y, front -Z. Collision is the box round it.
static func cell_cage(width: float = 1.2, height: float = 2.1, depth: float = 0.9) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hx := width * 0.5
	var hy := height * 0.5
	var hz := depth * 0.5
	var post := 0.07
	var floor_y := -hy + 0.08                       # top of the floor plate
	k.color = DARK
	k.box(Vector3(width, height, 0.04), Vector3(0.0, 0.0, hz - 0.02))
	k.box(Vector3(width, 0.08, depth - 0.04), Vector3(0.0, -hy + 0.04, -0.02))
	# The kit inside: a butt tray, a rack rail, rifles, a shelf with two ammo cans.
	var back := hz - 0.04                           # the back plate's face
	var inner := hx - post - 0.08
	var guns := clampi(int(inner * 2.0 / 0.17), 2, 6)
	k.color = DETAIL
	k.box(Vector3(inner * 2.0, 0.05, 0.16), Vector3(0.0, floor_y + 0.025, back - 0.1))
	var rail_y := floor_y + 0.78
	k.box(Vector3(inner * 2.0, 0.05, 0.05), Vector3(0.0, rail_y, back - 0.025))
	for i in guns:
		var x := lerpf(-inner + 0.06, inner - 0.06, float(i) / float(guns - 1))
		var z := back - 0.1
		k.color = DARK
		k.box(Vector3(0.04, 0.32, 0.1), Vector3(x, floor_y + 0.05 + 0.16, z))            # stock
		k.box(Vector3(0.05, 0.36, 0.08), Vector3(x, floor_y + 0.05 + 0.32 + 0.18, z))    # receiver
		k.box(Vector3(0.035, 0.12, 0.05), Vector3(x, floor_y + 0.45, z - 0.065))         # magazine
		k.color = DETAIL
		k.box(Vector3(0.02, 0.36, 0.02), Vector3(x, floor_y + 0.05 + 0.68 + 0.18, z))    # barrel
	var shelf_y := floor_y + 1.13
	if shelf_y + 0.25 < hy - 0.12:
		k.color = DETAIL
		k.box(Vector3(inner * 2.0, 0.03, depth * 0.45), Vector3(0.0, shelf_y, back - depth * 0.225))
		for sx: float in [-1.0, 1.0]:
			var cc := Vector3(sx * inner * 0.45, shelf_y + 0.015 + 0.09, back - 0.17)
			k.color = AMMO_GREEN
			k.box(Vector3(0.3, 0.18, 0.16), cc)
			k.color = DARK
			k.box(Vector3(0.31, 0.03, 0.17), cc + Vector3(0.0, 0.07, 0.0))
			k.box(Vector3(0.1, 0.02, 0.03), cc + Vector3(0.0, 0.1, 0.0))
	# The cage: corner posts, frames top and bottom, the roof.
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(post, height, post), Vector3(sx * (hx - post * 0.5), 0.0, -hz + post * 0.5))
		k.box(Vector3(post, height, post), Vector3(sx * (hx - post * 0.5), 0.0, hz - 0.04 - post * 0.5))
	for y: float in [-hy + 0.12, hy - 0.04]:
		k.box(Vector3(width - 2.0 * post, 0.07, post), Vector3(0.0, y, -hz + post * 0.5))
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(post, 0.07, depth - 0.04 - 2.0 * post), Vector3(sx * (hx - post * 0.5), y, -0.02))
	k.box(Vector3(width - 0.02, 0.07, depth - 0.04), Vector3(0.0, hy - 0.035, -0.02))
	k.color = PLATE
	k.box(Vector3(minf(0.36, width * 0.3), 0.045, 0.006), Vector3(-hx * 0.45, hy - 0.04, -hz - 0.003))
	# Bars: down each side and across the front, either side of the door.
	k.color = DETAIL
	var bar := 0.025
	var bar_h := height - 0.2
	var by := -hy + 0.12 + 0.035 + bar_h * 0.5 - 0.06
	for sx: float in [-1.0, 1.0]:
		var n := maxi(2, int((depth - 0.2) / 0.12))
		for i in n:
			var z := lerpf(-hz + post + 0.06, hz - 0.04 - post - 0.06, float(i) / float(n - 1))
			k.box(Vector3(bar, bar_h, bar), Vector3(sx * (hx - post * 0.5), by, z))
	var door_w := minf(0.7, width - 0.3)
	var dx0 := -door_w * 0.5
	for x0: float in [-hx + post, door_w * 0.5 + 0.04]:
		var x1 := x0 + (hx - post - door_w * 0.5 - 0.04)
		var n := maxi(1, int((x1 - x0) / 0.12))
		for i in n:
			var x := lerpf(x0, x1, (float(i) + 0.5) / float(n))
			k.box(Vector3(bar, bar_h, bar), Vector3(x, by, -hz + post * 0.5))
	# The door: its own frame and bars, a kick plate, hinges on the left.
	var dz := -hz - 0.015
	k.color = Color(0.5, 0.52, 0.55)
	k.box(Vector3(0.05, bar_h, 0.04), Vector3(dx0, by, dz))
	k.box(Vector3(0.05, bar_h, 0.04), Vector3(-dx0, by, dz))
	k.box(Vector3(door_w, 0.05, 0.04), Vector3(0.0, by - bar_h * 0.5 + 0.025, dz))
	k.box(Vector3(door_w, 0.05, 0.04), Vector3(0.0, by + bar_h * 0.5 - 0.025, dz))
	k.box(Vector3(door_w, 0.04, 0.03), Vector3(0.0, by, dz))
	for i in 4:
		var x := lerpf(dx0 + 0.1, -dx0 - 0.1, float(i) / 3.0)
		k.box(Vector3(bar, bar_h - 0.1, bar), Vector3(x, by, dz))
	k.color = DETAIL
	k.box(Vector3(door_w - 0.06, 0.2, 0.012), Vector3(0.0, by - bar_h * 0.5 + 0.15, dz - 0.026))
	k.color = DARK
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(0.05, 0.14, 0.05), Vector3(dx0 - 0.045, by + sy * bar_h * 0.34, dz))
	# The lock box, its key plate, a pull handle beside it.
	var lock := Vector3(-dx0 - 0.1, by + 0.05, dz - 0.03)
	k.box(Vector3(0.12, 0.2, 0.06), lock)
	k.color = DETAIL
	k.box(Vector3(0.06, 0.08, 0.012), lock + Vector3(0.0, 0.03, -0.036))
	k.color = DARK
	k.box(Vector3(0.012, 0.03, 0.004), lock + Vector3(0.0, 0.03, -0.043))
	k.color = DETAIL
	var hxp := -dx0 - 0.22
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(0.025, 0.025, 0.03), Vector3(hxp, by + 0.05 + sy * 0.08, dz - 0.035))
	k.box(Vector3(0.03, 0.22, 0.022), Vector3(hxp, by + 0.05, dz - 0.061))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * 0.04 + width * depth * 0.08 + 0.05
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth + 0.06)
	shape.collision = col
	return shape


# --- Geo Golem parts (0.46) -------------------------------------------------------------

## A heavy cutter drum (the Geo Golem's two drills): a dark square mount plate at -Y with
## bolted corners, an orange octagonal drive housing with chamfered ends, a hazard band and
## a dark band, two bolted gearbox covers (one with a status lamp) on its +Z side faces,
## two hydraulic hoses up its +Z faces into a ribbed dark sleeve and an amber work lamp
## each side on its top ledge (PartShape.glow); then a steel drum `radius` across (fit it
## with a pale material) with bolted wear rings at its ends, wound with three spiral
## flights carrying picks (steel holders, shanks, bright carbide points), its front face
## dark with a ring of long picks leaning out, a dark coolant ring with nozzles and a
## pointed hub. Bit toward +Y; `length` is the whole part. Collision is the hull of the
## housing, the drum's teeth and the hub.
static func cutter_drum(radius: float = 1.45, length: float = 4.2) -> PartShapes.PartShape:
	const HOUSING := Color(0.9, 0.48, 0.12)        # the orange drive housing
	const DRUM_STEEL := Color(0.56, 0.57, 0.59)    # the drum
	const PICK_LIGHT := Color(0.66, 0.67, 0.69)    # light pick shanks
	const PICK_DARK := Color(0.4, 0.41, 0.43)      # dark pick shanks
	var k := MeshKit.new()
	var g := MeshKit.new()
	var y0 := -length * 0.5
	var plate_t := 0.1
	var hw := radius * 0.78
	var bolt_r := clampf(radius * 0.024, 0.02, 0.045)
	k.color = DARK
	k.box(Vector3(hw * 2.0, plate_t, hw * 2.0), Vector3(0.0, y0 + plate_t * 0.5, 0.0))
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			for off: Vector2 in [Vector2(0.08, 0.2), Vector2(0.2, 0.08)]:
				_gear_bolt(k, Vector3(sx * (hw - off.x * radius), y0 + plate_t, sz * (hw - off.y * radius)), Vector3.UP,
						bolt_r, bolt_r)
	# The drive housing: an octagon with chamfered ends, a hazard band and a dark band.
	var h0 := y0 + plate_t
	var h1 := y0 + length * 0.42
	var hr := radius * 0.82
	var ch := minf(0.06, (h1 - h0) * 0.05)
	k.color = HOUSING
	k.lathe(PackedVector2Array([Vector2(0.0, h0), Vector2(hr * 0.95, h0), Vector2(hr, h0 + ch), Vector2(hr, h1 - ch),
			Vector2(hr * 0.95, h1), Vector2(0.0, h1)]), 8)
	var yh := lerpf(h0, h1, 0.3)
	_gear_hazard_ring(k, hr * 0.98, hr * 1.03, yh - 0.09, yh + 0.09, 8, 2, PartShapes.ACCENT, DARK)
	k.color = DARK
	var yd := lerpf(h0, h1, 0.72)
	k.lathe(PackedVector2Array([Vector2(hr * 0.98, yd - 0.07), Vector2(hr * 1.03, yd - 0.07),
			Vector2(hr * 1.03, yd + 0.07), Vector2(hr * 0.98, yd + 0.07)]), 8)
	# Gearbox covers on the two faces either side of +Z (the top when fitted), between the
	# bands: a dark gasket, the cover, six bolts; a status lamp on the first.
	var apo := hr * cos(PI / 8.0)
	var face_w := 2.0 * hr * sin(PI / 8.0)
	var cov_y := lerpf(yh + 0.09, yd - 0.07, 0.5)
	var cov_h := (yd - 0.07 - yh - 0.09) * 0.7
	for a: float in [PI * 0.125, PI * 0.875]:
		var n := Vector3(cos(a), 0.0, sin(a))
		var u := Vector3(-n.z, 0.0, n.x)
		k.color = DARK
		_gear_yblock(k, n * (apo + 0.01) + Vector3(0.0, cov_y, 0.0), -a, Vector3(0.02, cov_h + 0.04, face_w * 0.66 + 0.04))
		k.color = HOUSING
		_gear_yblock(k, n * (apo + 0.02) + Vector3(0.0, cov_y, 0.0), -a, Vector3(0.04, cov_h, face_w * 0.66))
		k.color = DETAIL
		for cy: float in [-1.0, 1.0]:
			for cu: float in [-1.0, 0.0, 1.0]:
				_gear_bolt(k, n * (apo + 0.04) + u * cu * (face_w * 0.33 - 0.06) + Vector3(0.0, cov_y + cy * (cov_h * 0.5 - 0.06), 0.0),
						n, bolt_r, bolt_r)
		if a < PI * 0.5:
			k.color = DARK
			_gear_yblock(k, n * (apo + 0.05) + u * face_w * 0.12 + Vector3(0.0, cov_y, 0.0), -a, Vector3(0.03, 0.1, 0.1))
			_gear_yblock(g, n * (apo + 0.06) + u * face_w * 0.12 + Vector3(0.0, cov_y, 0.0), -a, Vector3(0.03, 0.055, 0.055))
	# The sleeve: dark, ribbed.
	var s1 := h1 + length * 0.08
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(0.0, h1), Vector2(radius * 0.7, h1), Vector2(radius * 0.7, s1), Vector2(0.0, s1)]), 16)
	k.color = DETAIL
	for i in 3:
		var y := lerpf(h1, s1, (float(i) + 0.5) / 3.0)
		k.lathe(PackedVector2Array([Vector2(radius * 0.69, y - 0.025), Vector2(radius * 0.74, y - 0.025),
				Vector2(radius * 0.74, y + 0.025), Vector2(radius * 0.69, y + 0.025)]), 12)
	# Hydraulic hoses up the faces either side of +Z's corner, over the ledge into the sleeve.
	var hose_r := clampf(radius * 0.028, 0.025, 0.05)
	for a: float in [PI * 0.375, PI * 0.625]:
		var d := Vector3(cos(a), 0.0, sin(a))
		var rr := apo * 1.03 + hose_r + 0.012
		var y_mid := lerpf(h1, s1, 1.0 / 3.0)
		_drills_hose(k, PackedVector3Array([d * rr + Vector3(0.0, h0 + 0.25, 0.0),
				d * rr + Vector3(0.0, h1 - 0.08, 0.0), d * (radius * 0.74 + hose_r * 2.5) + Vector3(0.0, y_mid, 0.0),
				d * radius * 0.68 + Vector3(0.0, y_mid, 0.0)]), hose_r)
		k.color = DARK
		for t: float in [0.0, 0.5, 0.9]:
			var y := lerpf(h0 + 0.25, h1 - 0.08, t)
			k.strut(d * (apo - 0.01) + Vector3(0.0, y, 0.0), d * (rr + hose_r * 1.2) + Vector3(0.0, y, 0.0), hose_r * 1.4)
	# Work lamps on the top ledge at the ±X corners, facing the work (+Y).
	var ls := clampf(radius * 0.065, 0.07, 0.12)
	for sx: float in [-1.0, 1.0]:
		_drills_lamp(k, g, Vector3(sx * lerpf(radius * 0.74, hr, 0.5), h1, 0.0), Vector3.UP, Vector3.BACK, ls)
	# The drum: steel, bolted wear rings at its ends, three spiral flights with picks.
	var d0 := s1
	var d1 := length * 0.5 - length * 0.12
	var dr := radius * 0.86
	k.color = DRUM_STEEL
	k.lathe(PackedVector2Array([Vector2(0.0, d0), Vector2(dr, d0), Vector2(dr, d1), Vector2(0.0, d1)]), 20)
	k.color = DETAIL
	for e: float in [d0, d1 - 0.09]:
		k.lathe(PackedVector2Array([Vector2(dr * 0.99, e), Vector2(dr + 0.025, e + 0.01), Vector2(dr + 0.025, e + 0.08),
				Vector2(dr * 0.99, e + 0.09)]), 16)
	k.color = DARK
	for e: float in [d0 + 0.045, d1 - 0.045]:
		for i in 6:
			var a := TAU * (float(i) + 0.5) / 6.0
			_gear_bolt(k, Vector3(cos(a) * (dr + 0.025), e, sin(a) * (dr + 0.025)), Vector3(cos(a), 0.0, sin(a)),
					bolt_r * 0.8, bolt_r * 0.6)
	var tips := PackedVector3Array()
	var flights := 3
	var per_flight := 10
	var fy0 := d0 + 0.14
	var fy1 := d1 - 0.14
	var turn := TAU * 0.75
	var vane_h := radius * 0.09
	for f in flights:
		k.color = DRUM_STEEL
		for i in per_flight:
			var p0 := _drills_helix(f, flights, float(i) / float(per_flight), turn, fy0, fy1, dr + vane_h * 0.3)
			var p1 := _drills_helix(f, flights, float(i + 1) / float(per_flight), turn, fy0, fy1, dr + vane_h * 0.3)
			var mid := (p0 + p1) * 0.5
			_drills_bar(k, p0, p1, Vector3(mid.x, 0.0, mid.z).normalized(), radius * 0.05, vane_h)
		for i in per_flight:
			var p := _drills_helix(f, flights, (float(i) + 0.5) / float(per_flight), turn, fy0, fy1, 1.0)
			var out := Vector3(p.x, 0.0, p.z)
			var side := Vector3(-out.z, 0.0, out.x)
			var base := out * (dr + vane_h * 0.75) + Vector3(0.0, p.y, 0.0)
			var end := out * radius * 1.04 + Vector3(0.0, p.y + radius * 0.04, 0.0) + side * radius * 0.08
			_drills_pick(k, base, end, radius * 0.13, PICK_LIGHT if i % 2 == 0 else PICK_DARK)
			tips.append(end)
	# The front face: dark, long picks round its rim leaning out and forward, a coolant
	# ring with nozzles, a pointed hub with a bright pilot.
	var tip := length * 0.5
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(0.0, d1), Vector2(dr, d1), Vector2(dr * 0.9, d1 + 0.08), Vector2(0.0, d1 + 0.08)]), 20)
	for i in 10:
		var a := TAU * float(i) / 10.0
		var out := Vector3(cos(a), 0.0, sin(a))
		var base := out * dr * 0.7 + Vector3(0.0, d1 + 0.06, 0.0)
		var end := out * dr * 0.88 + Vector3(0.0, tip - 0.06, 0.0)
		_drills_pick(k, base, end, radius * 0.17, PICK_LIGHT if i % 2 == 0 else PICK_DARK)
		tips.append(end)
	k.color = DARK
	var cr0 := radius * 0.4
	var cr1 := radius * 0.5
	k.lathe(PackedVector2Array([Vector2(cr0, d1 + 0.07), Vector2(cr1, d1 + 0.07), Vector2(cr1 * 0.97, d1 + 0.15),
			Vector2(cr0 * 1.03, d1 + 0.15)]), 16)
	k.color = DETAIL
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		var out := Vector3(cos(a), 0.0, sin(a))
		k.strut(out * (cr0 + cr1) * 0.5 + Vector3(0.0, d1 + 0.12, 0.0), out * cr1 * 1.05 + Vector3(0.0, d1 + 0.24, 0.0),
				radius * 0.03)
	k.color = RIM
	k.lathe(PackedVector2Array([Vector2(0.0, d1 + 0.06), Vector2(radius * 0.36, d1 + 0.06), Vector2(radius * 0.14, tip - 0.1),
			Vector2(0.0, tip - 0.1)]), 10)
	k.color = TRIM
	k.lathe(PackedVector2Array([Vector2(0.0, tip - 0.1), Vector2(radius * 0.14, tip - 0.1), Vector2(radius * 0.03, tip),
			Vector2(0.0, tip)]), 10)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = hr * hr * 3.0 * (h1 - h0) + PI * dr * dr * (d1 - d0) * 0.6
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * hw, y0, sz * hw))
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector3(cos(a) * hr, h0, sin(a) * hr))
		pts.append(Vector3(cos(a) * dr, d0, sin(a) * dr))
	for p in tips:
		pts.append(p)
	pts.append(Vector3(0.0, tip, 0.0))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = GLOWING
	return shape


## A point on flight `f` of `flights` spiral flights round Y: `t` (0..1) along it, the
## flight turning `turn` radians from y0 to y1, at radius `r`.
static func _drills_helix(f: int, flights: int, t: float, turn: float, y0: float, y1: float, r: float) -> Vector3:
	var a := TAU * float(f) / float(flights) + t * turn
	return Vector3(cos(a) * r, lerpf(y0, y1, t), sin(a) * r)


## A lift car (the elevators of the Geo Golem, the bay freighter and the Everest): a dark
## floor `width` by `depth` laid with raised bare-steel tread bars and a hazard band at
## the open front (-Z), four galvanised corner posts, a roof plate in the material colour
## over a dark anodised frame with a plastic lamp housing under its middle and a light
## strip under its front edge, galvanised guard rails and rubber kick plates down both
## sides, a panel across the back with a kick plate, a chrome handrail on standoffs and
## galvanised cross braces over it, and a call panel on the right front post (a stainless
## faceplate, a plastic body) with a screen behind clear cover glass in a stainless bezel and
## two buttons (glow). Stands on -Y. Collision is the box round it.
static func lift_car(width: float = 2.0, depth: float = 1.8, height: float = 2.5) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var hx := width * 0.5
	var hy := height * 0.5
	var hz := depth * 0.5
	var floor_t := 0.12
	var post := 0.1
	var roof_t := 0.12
	var fy := -hy + floor_t                      # the floor's top
	# The floor: a dark slab, tread bars in steel (alternating ways), a hazard band at the front.
	k.color = DARK
	k.box(Vector3(width, floor_t, depth), Vector3(0.0, -hy + floor_t * 0.5, 0.0))
	_gear_hazard(k, Vector3(0.0, fy, -hz + 0.09), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			Vector2(width - 2.0 * post - 0.04, 0.14), 0.1)
	k.color = DETAIL
	var tx0 := -hx + post + 0.06
	var tx1 := hx - post - 0.06
	var tz0 := -hz + 0.22
	var tz1 := hz - 0.1
	var nx := maxi(2, int((tx1 - tx0) / 0.16))
	var nz := maxi(2, int((tz1 - tz0) / 0.16))
	for i in nx:
		for j in nz:
			var p := Vector3(tx0 + (tx1 - tx0) * (float(i) + 0.5) / float(nx), fy + 0.003,
					tz0 + (tz1 - tz0) * (float(j) + 0.5) / float(nz))
			var a := Vector3(0.045, 0.0, 0.012) if (i + j) % 2 == 0 else Vector3(0.012, 0.0, 0.045)
			k.poly(PackedVector3Array([p + Vector3(-a.x, 0, -a.z), p + Vector3(a.x, 0, -a.z), p + Vector3(a.x, 0, a.z),
					p + Vector3(-a.x, 0, a.z)]), Vector3.UP)
	# The corner posts, galvanised.
	k.color = GALVANISED
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(post, height - floor_t, post), Vector3(sx * (hx - post * 0.5), floor_t * 0.5, sz * (hz - post * 0.5)))
	# The roof: a plate over a dark frame, a lamp housing under its middle.
	k.color = Color.WHITE
	k.box(Vector3(width, roof_t, depth), Vector3(0.0, hy - roof_t * 0.5, 0.0))
	k.color = RAIL_DARK
	k.box(Vector3(width + 0.02, 0.05, depth + 0.02), Vector3(0.0, hy - roof_t - 0.025, 0.0))
	var lamp_y := hy - roof_t - 0.05
	k.color = PLASTIC_DARK
	k.box(Vector3(0.5, 0.04, 0.3), Vector3(0.0, lamp_y - 0.02, 0.0))
	g.box(Vector3(0.42, 0.006, 0.22), Vector3(0.0, lamp_y - 0.043, 0.0))
	# Guard rails (galvanised) and rubber kick plates down the sides.
	for sx: float in [-1.0, 1.0]:
		k.color = GALVANISED
		for y: float in [-hy + 0.55, -hy + 1.05]:
			k.box(Vector3(0.05, 0.05, depth - 2.0 * post), Vector3(sx * (hx - post * 0.5), y, 0.0))
		k.color = TREAD
		k.box(Vector3(0.03, 0.2, depth - 2.0 * post), Vector3(sx * (hx - post * 0.5), fy + 0.1, 0.0))
	# The back: a panel, a dark rail along its top, a kick plate and a handrail on its inside.
	var back_top := fy + height * 0.45
	k.color = Color.WHITE
	k.box(Vector3(width - 2.0 * post, height * 0.45, 0.05), Vector3(0.0, fy + height * 0.225, hz - 0.035))
	k.color = RAIL_DARK
	k.box(Vector3(width - 2.0 * post, 0.06, 0.06), Vector3(0.0, back_top, hz - 0.04))
	k.color = TREAD
	k.box(Vector3(width - 2.0 * post, 0.2, 0.012), Vector3(0.0, fy + 0.1, hz - 0.066))
	k.color = CHROME
	var rail_y := minf(fy + 0.95, back_top - 0.12)
	var rx := hx - post - 0.12
	_tube(k, Vector3(-rx, rail_y, hz - 0.12), Vector3(rx, rail_y, hz - 0.12), 0.02, 8)
	for sx: float in [-1.0, 1.0]:
		_tube(k, Vector3(sx * (rx - 0.08), rail_y, hz - 0.12), Vector3(sx * (rx - 0.08), rail_y, hz - 0.059), 0.012, 6)
	# Cross braces over the back panel, up to the roof frame.
	k.color = GALVANISED
	var by0 := back_top + 0.03
	var by1 := hy - roof_t - 0.05
	if by1 - by0 > 0.3:
		for sx: float in [-1.0, 1.0]:
			k.strut(Vector3(-sx * (hx - post), by0, hz - 0.05), Vector3(sx * (hx - post), by1, hz - 0.05), 0.04)
	# The call panel on the right front post: a bezel, a screen and two buttons (glow).
	var px := hx - post - 0.06
	var pz := -hz + post * 0.5
	k.color = STAINLESS
	k.box(Vector3(0.135, 0.315, 0.03), Vector3(px, 0.0, pz + 0.008))
	k.color = PLASTIC_DARK
	k.box(Vector3(0.12, 0.3, 0.04), Vector3(px, 0.0, pz))
	g.box(Vector3(0.08, 0.05, 0.006), Vector3(px, 0.08, pz - 0.023))
	for y: float in [-0.02, -0.075]:
		g.box(Vector3(0.025, 0.025, 0.006), Vector3(px, y, pz - 0.023))
	# A stainless bezel round the screen, standing proud of it, for the cover glass to sit in.
	k.color = STAINLESS
	var bz := pz - 0.025                                    # the bezel's centre, m
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(0.106, 0.013, 0.01), Vector3(px, 0.08 + sy * 0.0315, bz))
		k.box(Vector3(0.013, 0.05, 0.01), Vector3(px + sy * 0.0465, 0.08, bz))
	# The light strip under the roof's front edge.
	g.box(Vector3(width - 0.3, 0.025, 0.05), Vector3(0.0, hy - roof_t - 0.065, -hz + 0.1))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * depth * (floor_t + roof_t) + 4.0 * post * post * height
	var col := BoxShape3D.new()
	col.size = Vector3(width + 0.02, height, depth + 0.02)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.82, 0.55)
	# The call panel's cover glass over the screen, a hair proud of it, inside the bezel.
	var gk := MeshKit.new()
	gk.color = Color.WHITE
	var gz := pz - 0.0275
	gk.quad(Vector3(px - 0.042, 0.052, gz), Vector3(px + 0.042, 0.052, gz), Vector3(px + 0.042, 0.108, gz),
			Vector3(px - 0.042, 0.108, gz), Vector3.FORWARD)
	shape.glass = gk.finish()
	shape.glass_kind = Glazing.Kind.CLEAR
	return shape


## The rotating ore detector on the Geo Golem's roof (and the sensor heads of the Mule and
## the warships): a cast iron rotor base with a bolt ring, a bright slewing ring and a
## galvanised post with a rubber collar seal, a flattened six-sided head in the material
## colour with a dark band, a glowing yellow eye in a plastic bezel on its front (-Z), vent
## slats on its back and a bolted anodised cap with a small anodised mast and a plastic knob
## on top. `radius` is the head's; base on -Y.
static func detector_head(radius: float = 0.45, height: float = 0.9) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var y0 := -height * 0.5
	var base_t := height * 0.14
	var yb := y0 + base_t
	k.color = CAST
	k.lathe(PackedVector2Array([Vector2(0.0, y0), Vector2(radius * 0.9, y0), Vector2(radius * 0.8, yb),
			Vector2(0.0, yb)]), 16)
	# Bolts round the base's top, a bright slewing ring round the post's foot.
	k.color = DETAIL
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		_thrusters_bolt(k, Vector3(cos(a), 0.0, sin(a)) * radius * 0.6 + Vector3(0.0, yb, 0.0),
				maxf(0.01, radius * 0.045), 0.012)
	var ring_t := height * 0.045
	k.color = TRIM
	k.lathe(PackedVector2Array([Vector2(radius * 0.2, yb), Vector2(radius * 0.4, yb), Vector2(radius * 0.4, yb + ring_t * 0.6),
			Vector2(radius * 0.34, yb + ring_t), Vector2(radius * 0.2, yb + ring_t)]), 16)
	var p1 := yb + height * 0.28
	k.color = GALVANISED
	k.lathe(PackedVector2Array([Vector2(0.0, yb), Vector2(radius * 0.22, yb), Vector2(radius * 0.22, p1),
			Vector2(0.0, p1)]), 10)
	k.color = RUBBER
	var cy := lerpf(yb + ring_t, p1, 0.55)
	k.lathe(PackedVector2Array([Vector2(radius * 0.21, cy - height * 0.03), Vector2(radius * 0.26, cy - height * 0.025),
			Vector2(radius * 0.26, cy + height * 0.025), Vector2(radius * 0.21, cy + height * 0.03)]), 10)
	var head1 := p1 + height * 0.36
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(0.0, p1), Vector2(radius * 0.7, p1), Vector2(radius, p1 + height * 0.1),
			Vector2(radius, head1 - height * 0.1), Vector2(radius * 0.7, head1), Vector2(0.0, head1)]), 6)
	k.color = DARK
	var mid := (p1 + head1) * 0.5
	k.lathe(PackedVector2Array([Vector2(radius * 0.97, mid - 0.03), Vector2(radius * 1.02, mid - 0.03),
			Vector2(radius * 1.02, mid + 0.03), Vector2(radius * 0.97, mid + 0.03)]), 6)
	# The eye's bezel and visor on the -Z face (lathe vertex 0 sits at +X, so faces centre on
	# 30 + 60 n degrees; -Z is the face at 270), vent slats on the +Z face.
	var face_d := radius * cos(PI / 6.0)
	var eye_y := mid + height * 0.03
	k.color = PLASTIC_DARK
	k.box(Vector3(radius * 0.6, height * 0.15, 0.02), Vector3(0.0, eye_y, -face_d - 0.008))
	k.color = DARK
	for i in 3:
		k.box(Vector3(radius * 0.5, height * 0.025, 0.016),
				Vector3(0.0, lerpf(p1 + height * 0.12, head1 - height * 0.12, float(i) / 2.0), face_d + 0.007))
	# A bolted cap on top, the mast standing on it with a knob at its tip.
	var cap_t := height * 0.03
	k.color = ANODISED
	k.lathe(PackedVector2Array([Vector2(0.0, head1 - 0.002), Vector2(radius * 0.48, head1 - 0.002), Vector2(radius * 0.44, head1 + cap_t),
			Vector2(0.0, head1 + cap_t)]), 6)
	var top := y0 + height
	var mast := Vector3(radius * 0.3, 0.0, radius * 0.2)
	_tube(k, mast + Vector3(0.0, head1 + cap_t, 0.0), mast + Vector3(0.0, top - 0.04, 0.0), 0.016, 6)
	k.color = PLASTIC_DARK
	k.box(Vector3(0.04, 0.04, 0.04), mast + Vector3(0.0, top - 0.02, 0.0))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * radius * radius * height * 0.4
	var pts := PackedVector3Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector3(cos(a) * radius * 0.9, y0, sin(a) * radius * 0.9))
		pts.append(Vector3(cos(a) * radius, head1, sin(a) * radius))
	pts.append(Vector3(radius * 0.3, y0 + height, radius * 0.2))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	# The eye: a lens in the bezel, pointing -Z.
	var g := MeshKit.new()
	g.box(Vector3(radius * 0.45, height * 0.1, 0.006), Vector3(0.0, eye_y, -face_d - 0.019))
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.82, 0.3)
	return shape


## A medical station on a wall (the Geo Golem's crew corridor and the sick bays): a dark
## back `width` across framed by bolted white posts under a hood, two white cabinets on a
## dark kick with hinged doors and handles under a steel worktop, the left with a small lit
## screen. Above, a big dark screen in a pale bolted frame with a heart trace and readout
## bars glowing on it, a gas panel (O2, H2) either side with a gauge, a lit LED and two
## outlets, and a green sign with a white cross in a pale frame. Front -Z, back +Z against
## the wall, stands on -Y.
static func med_station(width: float = 1.6, height: float = 2.2, depth: float = 0.55) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hx := width * 0.5
	var hy := height * 0.5
	var hz := depth * 0.5
	var back := depth * 0.35
	var wall := hz - back                          # the back's front face, z
	var post := 0.06
	var hood := 0.06
	# The dark back, white posts up both sides and a hood over the top.
	k.color = DARK
	k.box(Vector3(width - 0.1, height - hood + 0.005, back - 0.002), Vector3(0.0, (0.005 - hood) * 0.5, hz - back * 0.5 - 0.001))
	k.color = Color.WHITE
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(post, height - hood, back + 0.04), Vector3(sx * (hx - post * 0.5), -hood * 0.5, hz - (back + 0.04) * 0.5))
	k.box(Vector3(width, hood, back + 0.06), Vector3(0.0, hy - hood * 0.5, hz - (back + 0.06) * 0.5))
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for t: float in [0.2, 0.5, 0.8]:
			k.box(Vector3(0.022, 0.022, 0.008), Vector3(sx * (hx - post * 0.5), -hy + height * t, wall - 0.044))
	# Two cabinets on a dark kick under a steel worktop.
	var kick := 0.06
	var cab_h := height * 0.38
	var cab_w := (width - post * 2.0) * 0.5 - 0.01
	var cd := depth - back
	k.color = DARK
	k.box(Vector3(width - post * 2.0 - 0.02, kick, cd - 0.04), Vector3(0.0, -hy + kick * 0.5, -hz + 0.04 + (cd - 0.04) * 0.5))
	var top_y := -hy + cab_h
	for sx: float in [-1.0, 1.0]:
		var cx := sx * (cab_w * 0.5 + 0.005)
		var ch := cab_h - kick - 0.03
		var cy := -hy + kick + ch * 0.5
		k.color = Color.WHITE
		k.box(Vector3(cab_w, ch, cd), Vector3(cx, cy, -hz + cd * 0.5))
		# The door on a dark seam, hinged on the outer edge, a handle by the middle.
		var dw := cab_w - 0.06
		var dh := ch - 0.06
		k.color = DARK
		k.box(Vector3(dw + 0.014, dh + 0.014, 0.004), Vector3(cx, cy, -hz - 0.002))
		k.color = Color.WHITE
		_cabinets_pad(k, Vector3(cx, cy, -hz - 0.004), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, dw * 0.5, dh * 0.5, 0.008, 0.004)
		k.color = DETAIL
		for sy: float in [-1.0, 1.0]:
			var y := cy + sy * dh * 0.32
			_tube(k, Vector3(cx + sx * dw * 0.5, y - 0.04, -hz - 0.01), Vector3(cx + sx * dw * 0.5, y + 0.04, -hz - 0.01), 0.011, 6)
		var hxx := cx - sx * (dw * 0.5 - 0.05)
		k.strut(Vector3(hxx, cy + dh * 0.05, -hz - 0.026), Vector3(hxx, cy + dh * 0.3, -hz - 0.026), 0.02)
		for t: float in [0.1, 0.25]:
			k.box(Vector3(0.018, 0.018, 0.012), Vector3(hxx, cy + dh * t, -hz - 0.018))
	k.color = DETAIL
	k.box(Vector3(width - post * 2.0 - 0.004, 0.03, cd + 0.015), Vector3(0.0, top_y - 0.015, -hz + (cd - 0.015) * 0.5))
	# The left cabinet's small screen sits in a dark bezel on its door.
	var lsc := Vector3(-(cab_w * 0.5 + 0.005), top_y - 0.03 - 0.11, -hz - 0.012)
	k.color = DARK
	k.box(Vector3(cab_w * 0.46, 0.13, 0.006), lsc + Vector3(0.0, 0.0, -0.003))
	# The big screen in its pale frame with bolts in the corners.
	var sy := top_y + height * 0.28
	var sw := width * 0.62
	var sh := height * 0.3
	k.color = TRIM
	k.box(Vector3(sw + 0.1, sh + 0.1, 0.1), Vector3(0.0, sy, wall - 0.05))
	k.color = DARK
	k.box(Vector3(sw, sh, 0.02), Vector3(0.0, sy, wall - 0.11))
	k.color = DETAIL
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		k.box(Vector3(0.02, 0.02, 0.008), Vector3(c.x * (sw * 0.5 + 0.025), sy + c.y * (sh * 0.5 + 0.025), wall - 0.104))
	# Gas panels either side of the screen: a gauge, an LED (lit) and two outlets.
	var gx := (sw * 0.5 + 0.05 + hx - post) * 0.5
	var gw := (hx - post) - (sw * 0.5 + 0.05) - 0.012
	var gh := sh * 0.9
	var gz := wall - 0.08
	for sx: float in [-1.0, 1.0]:
		k.color = PANEL_GREY
		k.box(Vector3(gw, gh, 0.08), Vector3(sx * gx, sy, wall - 0.04))
		k.color = PLATE
		var gauge := Vector3(sx * gx, sy + gh * 0.28, gz - 0.004)
		k.box(Vector3(gw * 0.62, gw * 0.62, 0.008), gauge)
		k.color = DARK
		k.strut(gauge + Vector3(-gw * 0.15, -gw * 0.12, -0.006), gauge + Vector3(gw * 0.12, gw * 0.15, -0.006), 0.008)
		k.box(Vector3(0.045, 0.045, 0.006), Vector3(sx * gx, sy + gh * 0.02, gz - 0.003))
		k.color = DETAIL
		for i in 2:
			var oy := sy - gh * (0.18 + 0.2 * float(i))
			_tube(k, Vector3(sx * gx, oy, gz), Vector3(sx * gx, oy, gz - 0.04), 0.022, 8)
			k.color = TRIM
			_tube(k, Vector3(sx * gx, oy, gz), Vector3(sx * gx, oy, gz - 0.012), 0.03, 8)
			k.color = DETAIL
	# The sign: green, a white cross, a pale frame.
	var sign_lo := sy + sh * 0.5 + 0.07
	var sign_h := minf(0.26, hy - hood - sign_lo - 0.04)
	var sign_y := sign_lo + sign_h * 0.5
	var sign_w := width * 0.32
	k.color = TRIM
	k.box(Vector3(sign_w + 0.03, sign_h + 0.03, 0.05), Vector3(0.0, sign_y, wall - 0.025))
	k.color = MED_GREEN
	k.box(Vector3(sign_w, sign_h, 0.012), Vector3(0.0, sign_y, wall - 0.055))
	k.color = PLATE
	var arm := sign_h * 0.55
	k.box(Vector3(arm, arm * 0.3, 0.008), Vector3(0.0, sign_y, wall - 0.064))
	k.box(Vector3(arm * 0.3, arm, 0.008), Vector3(0.0, sign_y, wall - 0.0645))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * back + 2.0 * cab_w * cab_h * (depth - back) * 0.6
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth + 0.04)
	shape.collision = col
	# Lit: a heart trace and readout bars on the big screen, the cabinet screen's readout,
	# an LED on each gas panel.
	var g := MeshKit.new()
	var tz := wall - 0.122
	var trace: Array[Vector2] = [Vector2(-0.45, 0.1), Vector2(-0.18, 0.1), Vector2(-0.12, 0.02), Vector2(-0.06, 0.1),
			Vector2(0.0, 0.1), Vector2(0.04, -0.12), Vector2(0.09, 0.42), Vector2(0.14, -0.05), Vector2(0.19, 0.1),
			Vector2(0.45, 0.1)]
	for i in trace.size() - 1:
		var a := Vector3(trace[i].x * sw, sy + trace[i].y * sh, tz)
		var b := Vector3(trace[i + 1].x * sw, sy + trace[i + 1].y * sh, tz)
		g.strut(a, b, 0.014)
	for i in 3:
		var bw := sw * (0.34 - 0.08 * float(i))
		g.box(Vector3(bw, sh * 0.06, 0.004), Vector3(-sw * 0.45 + bw * 0.5, sy - sh * (0.18 + 0.1 * float(i)), tz))
	g.box(Vector3(sw * 0.12, sh * 0.16, 0.004), Vector3(sw * 0.36, sy + sh * 0.34, tz))
	for i in 2:
		g.box(Vector3(cab_w * (0.36 - 0.12 * float(i)), 0.025, 0.004), lsc + Vector3(-cab_w * 0.04 * float(i), 0.025 - 0.05 * float(i), -0.007))
	for sx: float in [-1.0, 1.0]:
		g.box(Vector3(0.028, 0.028, 0.004), Vector3(sx * gx, sy + gh * 0.02, gz - 0.007))
	shape.glow = g.finish()
	shape.glow_color = Color(0.4, 0.85, 1.0)
	return shape


# --- Superhawk parts (0.47) -------------------------------------------------------------

## A loop of `outline` (x, y points) at z, centred on (cx, cy): one end of a section lofted
## along Z (the rail turret's collars and breech).
static func _railgun_ring_z(outline: PackedVector2Array, cx: float, cy: float, z: float, s: float = 1.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in outline:
		out.append(Vector3(cx + p.x * s, cy + p.y * s, z))
	return out


## The Superhawk's roof gun (the bar on two posts over its apex): a chamfered dark mount
## plate on -Y with bolts down its edges and a traverse ring under an angular housing in the
## material colour at its back (a sloped glacis, cheek armour with seams, vent slots and a
## hazard tab in its back, a sight block with a lit lens and a round hatch on its roof); two
## tapered posts rising from it to saddle clamps round a long railgun barrel along Z: a dark
## core between two rails with copper strips along the slot, octagonal coil collars with a
## lit window each side, a three-baffle muzzle brake at -Z, an orange band in front of a
## chamfered breech block with ready lamps on its sides and a bolted cap, a power cable from
## the housing up into the breech. `length` is the whole part along Z, `height` along Y;
## `glow` lights the lamps and the lens.
static func rail_turret(length: float = 6.0, height: float = 1.3, width: float = 1.1,
		glow := Color(1.0, 0.55, 0.2)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var hz := length * 0.5
	var hy := height * 0.5
	var hx := width * 0.5
	var base_t := 0.12
	var base_z0 := hz - length * 0.42     # the mount and housing sit under the rear part
	var bd := hz - base_z0
	var bzc := (base_z0 + hz) * 0.5
	# The mount plate, bolts down both long edges.
	_railgun_stack(k, PartShapes._chamfer_rect(width, bd, width * 0.12), [[-hy, 1.0], [-hy + base_t, 1.0]], [DARK],
			Vector3(0.0, 0.0, bzc))
	k.color = DETAIL
	var nb := maxi(3, int(bd / 0.45))
	for sx: float in [-1.0, 1.0]:
		for i in nb:
			var z := lerpf(base_z0 + 0.15, hz - 0.15, float(i) / float(nb - 1))
			_piping_bolts(k, Vector3(sx * (hx - 0.06), -hy + base_t, z), Vector3.UP, 0.0, 1, 0.0, 0.04, 0.02)
	# The traverse ring and the housing on it.
	var yb := -hy + base_t + 0.05
	var house_h := height * 0.32
	var yt := -hy + base_t + house_h
	var hh := yt - yb
	var hd := bd * 0.8
	var zf := bzc - hd * 0.5
	var zb := bzc + hd * 0.5
	_piping_spin(k, Vector3(0.0, 0.0, bzc), Vector3.UP, PackedVector2Array([Vector2(hx * 0.75, -hy + base_t),
			Vector2(hx * 0.75, yb + 0.002), Vector2(0.0, yb + 0.002)]), [RIM] as Array[Color], 16)
	var hxh := hx * 0.8
	var side := PackedVector2Array([Vector2(zf, yb), Vector2(zb, yb), Vector2(zb, yt - hh * 0.25), Vector2(zb - hh * 0.25, yt),
			Vector2(zf + hh * 0.7, yt), Vector2(zf, yb + hh * 0.35)])
	k.color = Color.WHITE
	_prism_x(k, side, -hxh, hxh)
	var cheek := _weapons_inset(side, Vector2(bzc, (yb + yt) * 0.5), 0.82)
	for sx: float in [-1.0, 1.0]:
		k.color = Color.WHITE
		_prism_x(k, cheek, sx * (hxh - 0.01), sx * (hxh + 0.012))
		k.color = DARK
		k.box(Vector3(0.006, hh * 0.6, 0.02), Vector3(sx * (hxh + 0.014), (yb + yt) * 0.5, bzc))
	# Vent slots and a hazard tab in the back.
	k.color = DARK
	for i in 2:
		k.box(Vector3(hxh * 1.3, 0.025, 0.006), Vector3(0.0, yb + hh * (0.45 + 0.15 * float(i)), zb + 0.003))
	_weapons_hazard(k, Vector3(0.0, yb + hh * 0.2, zb + 0.002), hxh * 0.9, hh * 0.16, 1.0)
	# The sight block (lens toward -Z) and a round hatch on the roof.
	var sz := zf + hh * 0.7 + 0.15
	k.color = DETAIL
	k.box(Vector3(0.14, 0.08, 0.2), Vector3(hxh * 0.55, yt + 0.04, sz))
	_weapons_lens(k, g, Vector3(hxh * 0.55, yt + 0.04, sz - 0.1), 0.03)
	k.color = DETAIL
	_piping_spin(k, Vector3(-hx * 0.55, 0.0, zb - 0.35), Vector3.UP, PackedVector2Array([Vector2(0.1, yt - 0.002),
			Vector2(0.1, yt + 0.025), Vector2(0.0, yt + 0.025)]), [DETAIL] as Array[Color], 12)
	# The barrel: a dark core between two rails, copper strips along the slot.
	var bar := 0.24
	var bar_y := hy - bar * 0.5
	var z0 := -hz + 0.02
	var z1 := hz - 0.7
	var bl := z1 - z0
	var bzm := (z0 + z1) * 0.5
	k.color = DARK
	k.box(Vector3(bar * 0.36, bar * 0.7, bl), Vector3(0.0, bar_y, bzm))
	for sx: float in [-1.0, 1.0]:
		k.color = RIM
		k.box(Vector3(bar * 0.22, bar * 0.8, bl), Vector3(sx * bar * 0.29, bar_y, bzm))
		k.color = COPPER
		k.box(Vector3(0.012, 0.006, bl - 0.45), Vector3(sx * (bar * 0.18 + 0.008), bar_y + bar * 0.4 + 0.003, bzm + 0.2))
	# The posts: tapered pylons from the housing's roof to saddle clamps round the barrel.
	for pz: float in [base_z0 + 0.35, hz - 0.45]:
		_railgun_stack(k, PartShapes._chamfer_rect(0.26, 0.32, 0.05), [[yt - 0.01, 1.0], [bar_y - bar * 0.45, 0.78]], [DETAIL],
				Vector3(0.0, 0.0, pz))
		k.color = DARK
		k.box(Vector3(bar * 1.15, bar * 1.1, 0.22), Vector3(0.0, bar_y, pz))
	# The coil collars, a lit window on each side.
	var coct := PartShapes._chamfer_rect(bar, bar, bar * 0.28)
	for i in 4:
		var z := -hz + 0.9 + float(i) * (length - 2.0) / 4.0
		if absf(z - (base_z0 + 0.35)) < 0.25 or absf(z - (hz - 0.45)) < 0.25:
			continue    # a saddle clamp stands there
		k.color = DARK
		k.loft(_railgun_ring_z(coct, 0.0, bar_y, z - 0.105, 0.92), _railgun_ring_z(coct, 0.0, bar_y, z + 0.105, 0.92))
		k.color = DETAIL
		k.loft(_railgun_ring_z(coct, 0.0, bar_y, z - 0.08), _railgun_ring_z(coct, 0.0, bar_y, z + 0.08))
		for sx: float in [-1.0, 1.0]:
			k.color = DARK
			k.box(Vector3(0.004, bar * 0.4, 0.1), Vector3(sx * (bar * 0.5 + 0.002), bar_y, z))
			g.box(Vector3(0.004, bar * 0.25, 0.07), Vector3(sx * (bar * 0.5 + 0.005), bar_y, z))
	# The muzzle brake: three baffles with the barrel showing between them, a dark bore.
	k.color = DETAIL
	for i in 3:
		k.box(Vector3(bar * 1.3, bar * 1.15, 0.08), Vector3(0.0, bar_y, -hz + 0.04 + 0.16 * float(i)))
	k.color = DARK
	k.box(Vector3(bar * 0.5, bar * 0.4, 0.006), Vector3(0.0, bar_y, -hz - 0.002))
	# The orange band, the chamfered breech block, its bolted cap and ready lamps.
	k.color = PartShapes.ACCENT
	k.loft(_railgun_ring_z(PartShapes._chamfer_rect(bar * 1.44, bar * 1.34, 0.04), 0.0, bar_y - 0.01, hz - 0.83),
			_railgun_ring_z(PartShapes._chamfer_rect(bar * 1.44, bar * 1.34, 0.04), 0.0, bar_y - 0.01, hz - 0.73))
	var breech := PartShapes._chamfer_rect(bar * 1.4, bar * 1.3, 0.05)
	k.color = Color.WHITE
	k.loft(_railgun_ring_z(breech, 0.0, bar_y - 0.01, hz - 0.7), _railgun_ring_z(breech, 0.0, bar_y - 0.01, hz))
	k.color = DETAIL
	k.box(Vector3(bar * 1.0, bar * 0.9, 0.006), Vector3(0.0, bar_y - 0.01, hz + 0.002))
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			k.box(Vector3(0.03, 0.03, 0.01), Vector3(sx * bar * 0.38, bar_y - 0.01 + sy * bar * 0.33, hz + 0.007))
		k.color = DARK
		k.box(Vector3(0.004, 0.06, 0.16), Vector3(sx * (bar * 0.7 + 0.002), bar_y + 0.03, hz - 0.35))
		g.box(Vector3(0.004, 0.035, 0.12), Vector3(sx * (bar * 0.7 + 0.005), bar_y + 0.03, hz - 0.35))
		k.color = DETAIL
	# The power cable: up from the housing's roof beside the rear post and into the breech.
	var cx := bar * 0.7 + 0.04
	var cz := zb - hh * 0.25 - 0.08
	k.color = DARK
	_tube(k, Vector3(cx, yt - 0.01, cz), Vector3(cx, bar_y - 0.06, cz), 0.025, 8)
	_tube(k, Vector3(cx + 0.025, bar_y - 0.06, cz), Vector3(bar * 0.7 - 0.01, bar_y - 0.06, cz), 0.025, 8)
	k.color = DETAIL
	k.box(Vector3(0.09, 0.03, 0.09), Vector3(cx, yt + 0.012, cz))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * (hz - base_z0) * (base_t + house_h * 0.6) + bar * bar * length
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		pts.append(Vector3(sx * hx, -hy, base_z0))
		pts.append(Vector3(sx * hx, -hy, hz))
		pts.append(Vector3(sx * bar * 0.7, hy, -hz))
		pts.append(Vector3(sx * bar * 0.7, hy, hz))
		pts.append(Vector3(sx * bar * 0.7, hy - bar * 1.15, -hz))
		pts.append(Vector3(sx * hx * 0.8, -hy + base_t + house_h, base_z0))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A hydroponics planter (the Superhawk's grow room): a tapered trough `length` along X in
## the material colour with a chamfered steel lip, a label plate on its front (-Z) and a
## drain valve at its +X end, on four dark legs with steel feet; a shelf between the legs
## carrying a nutrient tank (a feed pipe up into the trough) and a pump. Dark soil with
## two rows of plants: low dark-leaved rosettes and taller leafy plants with red fruit,
## heights varying. A grow-light housing on two posts (clamped to the lip, arms forward)
## over it, three pink-white lit strips along its underside, its cable down a post.
## Stands on -Y; `height` is to the top of the light housing, `width` across Z.
static func planter(length: float = 2.0, width: float = 0.8, height: float = 1.7) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var hx := length * 0.5
	var hz := width * 0.5
	var y0 := -height * 0.5
	var trough_top := y0 + 0.85
	var trough_h := 0.4
	var y_tb := trough_top - trough_h         # the trough's underside
	var lip := 0.035
	# Legs on steel feet, a shelf between them with the nutrient tank, its feed pipe and a
	# pump.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var lx := sx * (hx - 0.08)
			var lz := sz * (hz - 0.08)
			k.color = DARK
			k.box(Vector3(0.06, y_tb - y0 - 0.02, 0.06), Vector3(lx, y0 + 0.02 + (y_tb - y0 - 0.02) * 0.5, lz))
			k.color = DETAIL
			k.box(Vector3(0.09, 0.02, 0.09), Vector3(lx, y0 + 0.01, lz))
	var y_sh := y0 + 0.14
	k.box(Vector3(length - 0.22, 0.025, width - 0.22), Vector3(0.0, y_sh, 0.0))
	var tx := -hx * 0.4
	var t_h := minf(0.18, y_tb - y_sh - 0.12)
	var y_tt := y_sh + 0.0125 + t_h           # top of the tank
	k.color = PLANTER_TANK
	k.box(Vector3(length * 0.3, t_h, width * 0.45), Vector3(tx, y_tt - t_h * 0.5, 0.0))
	k.color = DETAIL
	k.box(Vector3(0.08, 0.03, 0.08), Vector3(tx - length * 0.07, y_tt + 0.015, 0.0))
	_tube(k, Vector3(tx + length * 0.08, y_tt, 0.0), Vector3(tx + length * 0.08, y_tb, 0.0), 0.016, 6)
	k.color = DARK
	k.box(Vector3(0.14, 0.1, 0.12), Vector3(hx * 0.3, y_sh + 0.0125 + 0.05, 0.0))
	# The trough, tapering in toward its foot, a chamfered steel lip round its top.
	var lo := PackedVector3Array()
	var hi := PackedVector3Array()
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		lo.append(Vector3(s.x * (hx - 0.04), y_tb, s.y * (hz - 0.03)))
		hi.append(Vector3(s.x * hx, trough_top - lip, s.y * hz))
	k.color = Color.WHITE
	k.loft(lo, hi)
	k.color = DETAIL
	_seating_pad(k, Vector3(0.0, trough_top - lip, 0.0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, hx + 0.005, hz + 0.005, lip, 0.012)
	# A label plate on the sloped front, a drain valve at the +X end.
	var th := trough_h - lip
	var v := Vector3(0.0, th, -0.03).normalized()
	var n := Vector3(0.0, -0.03, -th).normalized()
	k.color = PLATE
	_seating_pad(k, Vector3(-hx * 0.5, y_tb + th * 0.5, -(hz - 0.015)), Vector3.RIGHT, v, n, minf(0.14, hx * 0.25), 0.05, 0.006)
	k.color = DETAIL
	_tube(k, Vector3(hx - 0.04, y_tb + 0.06, 0.0), Vector3(hx + 0.012, y_tb + 0.06, 0.0), 0.02, 6)
	k.color = PLANTER_SOIL
	k.box(Vector3(length - 0.08, 0.02, width - 0.08), Vector3(0.0, trough_top + 0.005, 0.0))
	# Plants in two rows, heights varying along the trough: rosettes and fruiting plants
	# in turn.
	var count := maxi(2, int(length / 0.32))
	var r := minf(0.15, hz * 0.36)
	for row: float in [-1.0, 1.0]:
		for i in count:
			var x := -hx + 0.16 + (length - 0.32) * (float(i) + 0.5) / float(count)
			var tall := 0.18 + 0.14 * absf(sin(float(i) * 1.7 + row))
			var at := Vector3(x, trough_top + 0.015, row * hz * 0.45)
			if (i + int(row > 0.0)) % 2 == 0:
				_quarters_plant(k, at, r * 1.1, tall * 0.5, PLANTER_LEAF_DARK, Color(0, 0, 0, 0))
			else:
				_quarters_plant(k, at, r * 0.95, tall * 0.8, PLANTER_LEAF, PLANTER_FRUIT)
	# The light housing on two posts (clamps on the lip, arms forward to it), three lit
	# strips under it, its cable down the +X post.
	var bar_y := -y0 - 0.06
	var zl := hz * 0.2                        # the housing's middle (z)
	var zp := hz - 0.06                       # the posts (z)
	var hb := width * 0.25                    # half the housing's depth
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		var px := sx * (hx - 0.1)
		k.box(Vector3(0.05, bar_y - trough_top, 0.05), Vector3(px, (trough_top + bar_y) * 0.5, zp))
		k.box(Vector3(0.08, 0.05, 0.08), Vector3(px, trough_top + 0.025, zp))
		k.box(Vector3(0.05, 0.04, zp - (zl + hb) + 0.035), Vector3(px, bar_y + 0.02, (zp + 0.025 + zl + hb - 0.01) * 0.5))
	k.color = DARK
	_seating_pad(k, Vector3(0.0, bar_y + 0.06, zl), Vector3.RIGHT, Vector3.BACK, Vector3.DOWN, (length - 0.1) * 0.5, hb, 0.06, 0.015)
	_tube(k, Vector3(hx - 0.1, bar_y + 0.03, zp + 0.035), Vector3(hx - 0.1, trough_top + 0.06, zp + 0.035), 0.01, 6)
	for dz: float in [-1.0, 0.0, 1.0]:
		g.box(Vector3(length - 0.3, 0.008, 0.035), Vector3(0.0, bar_y - 0.004, zl + dz * width * 0.14))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * width * trough_h * 0.7
	var col := BoxShape3D.new()
	col.size = Vector3(length, height, width)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.55, 0.85)
	return shape


## One planter plant standing at `at` (its foot), `r` round, `tall` high, in `leaf`: a
## six-sided bush mounding from its foot to its girth at 40% of its height, and a crown
## turned 30 degrees narrowing from there to a flat top; with `fruit` set (alpha > 0) two
## fruit hang on opposite sides of its girth.
static func _quarters_plant(k: MeshKit, at: Vector3, r: float, tall: float, leaf: Color, fruit: Color) -> void:
	k.color = leaf
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	var c := PackedVector3Array()
	var d := PackedVector3Array()
	for j in 6:
		var t0 := TAU * float(j) / 6.0
		var t1 := t0 + TAU / 12.0
		a.append(at + Vector3(cos(t0) * r * 0.7, 0.0, sin(t0) * r * 0.7))
		b.append(at + Vector3(cos(t0) * r, tall * 0.4, sin(t0) * r))
		c.append(at + Vector3(cos(t1) * r * 0.95, tall * 0.35, sin(t1) * r * 0.95))
		d.append(at + Vector3(cos(t1) * r * 0.5, tall, sin(t1) * r * 0.5))
	k.loft(a, b)
	k.loft(c, d)
	if fruit.a > 0.0:
		k.color = fruit
		for j in 2:
			var t := TAU * (float(j) + 0.3) / 2.0
			k.box(Vector3(0.045, 0.045, 0.045), at + Vector3(cos(t) * r * 0.95, tall * (0.32 + 0.08 * float(j)), sin(t) * r * 0.95))


## A hazard panel (the red and white bands round the Superhawk's hangar and over its bridge):
## a thin backing plate `length` along X and `height` tall in the material colour (white),
## a raised galvanised border round its front (-Z) with blackened bolts along its top and
## bottom bars, and slanted `stripe` stripes standing a hair proud inside it, cut off
## square at both ends so the pattern runs border to border. Back +Z on the wall.
static func hazard_band(length: float = 3.0, height: float = 0.5, thickness: float = 0.06,
		stripe := Color(0.78, 0.12, 0.1)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hx := length * 0.5
	var hy := height * 0.5
	var hz := thickness * 0.5
	var f := clampf(height * 0.08, 0.02, 0.04)   # the border bars' width
	k.color = Color.WHITE
	k.box(Vector3(length, height, thickness - 0.006), Vector3(0.0, 0.0, 0.003))
	# The border: four bars standing proud of the front, a hair inside the plate's edges.
	k.color = GALVANISED
	var bz := Vector2(-hz - 0.004, -hz + 0.012)   # its front and back (z)
	var bc := (bz.x + bz.y) * 0.5
	var bd := bz.y - bz.x
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(length - 0.004, f - 0.002, bd), Vector3(0.0, sy * (hy - 0.001 - (f - 0.002) * 0.5), bc))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(f - 0.002, height - f * 2.0 + 0.002, bd), Vector3(sx * (hx - 0.001 - (f - 0.002) * 0.5), 0.0, bc))
	# The stripes: slanted bands inside the border, clipped square at its ends.
	k.color = stripe
	var ya := -hy + f
	var yb := hy - f
	var pitch := height * 1.2
	var lean := (yb - ya) * 0.55
	var xa := -hx + f
	var xb := hx - f
	var first := -int(ceil(lean / pitch)) - 1
	var n := int(ceil(length / pitch)) + 1
	for i in range(first, n):
		var x0 := xa + float(i) * pitch
		var quad := PackedVector2Array([Vector2(x0, ya), Vector2(x0 + pitch * 0.5, ya), Vector2(x0 + pitch * 0.5 + lean, yb),
				Vector2(x0 + lean, yb)])
		var cut := _hullfit_clip_x(quad, xa, xb)
		if cut.size() < 3:
			continue
		var x_lo := INF
		var x_hi := -INF
		for p in cut:
			x_lo = minf(x_lo, p.x)
			x_hi = maxf(x_hi, p.x)
		if x_hi - x_lo < 0.01:
			continue
		var a := PackedVector3Array()
		var b := PackedVector3Array()
		for p in cut:
			a.append(Vector3(p.x, p.y, -hz))
			b.append(Vector3(p.x, p.y, -hz + 0.01))
		k.loft(a, b)
	# Bolts along the border's top and bottom bars, one in each corner.
	k.color = FLANGE_BOLT
	var bs := f * 0.45
	var nb := maxi(int(length / 0.5) + 1, 2)
	for i in nb:
		var x := lerpf(-hx + f * 0.5, hx - f * 0.5, float(i) / float(nb - 1))
		for sy: float in [-1.0, 1.0]:
			k.box(Vector3(bs, bs, 0.008), Vector3(x, sy * (hy - f * 0.5), bz.x - 0.004))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * height * thickness
	var col := BoxShape3D.new()
	col.size = Vector3(length, height, thickness)
	shape.collision = col
	return shape


## A convex outline clipped to the band xa <= x <= xb (Sutherland-Hodgman, two edges).
static func _hullfit_clip_x(outline: PackedVector2Array, xa: float, xb: float) -> PackedVector2Array:
	var out := outline
	for side in 2:
		var src := out
		out = PackedVector2Array()
		var edge := xa if side == 0 else xb
		var n := src.size()
		for i in n:
			var p := src[i]
			var q := src[(i + 1) % n]
			var p_in := p.x >= edge if side == 0 else p.x <= edge
			var q_in := q.x >= edge if side == 0 else q.x <= edge
			if p_in:
				out.append(p)
			if p_in != q_in:
				out.append(p.lerp(q, (edge - p.x) / (q.x - p.x)))
	return out


# --- Pioneer parts (0.48) ---------------------------------------------------------------

## A big ducted engine (the Pioneer's four round fan engines, one at each corner): a drum
## `radius` round and `length` long along Y in the `body` colour with dark panel seams,
## standing on a dark mount collar with six clamp brackets (two bolts each) round its foot
## (-Y), a banded waist with steel clamp blocks, a rolled pale lip with a bolt ring round the
## open +Y end, and set back inside a fan: twisted steel blades in a steel fan case over a
## dark face, a pale spinner, and a glowing ring round the spinner's foot (PartShape.glow).
## Every piece carries its own vertex colour, so fit it with a near-white material. Exhaust
## +Y; turn it with `Basis(Vector3.RIGHT, PI / 2)` to blow aft from a stern face.
static func turbine_engine(radius: float = 1.1, length: float = 1.6, body := Color(0.2, 0.42, 0.85),
		glow := Color(1.0, 0.45, 0.15)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var r := radius
	var h := length * 0.5
	var collar := length * 0.18
	var y0 := -h + collar
	var lip := clampf(length * 0.08, 0.08, 0.16)
	var y_lip := h - 0.012                      # the lip's top (its bolts stand to h), m
	var seg := 32
	# Mount collar and clamp brackets, two bolts on each bracket's face.
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(0.0, -h), Vector2(r * 0.86, -h), Vector2(r * 0.86, y0),
			Vector2(0.0, y0)]), 24)
	var bh := collar + length * 0.12
	for i in 6:
		var a := TAU * (float(i) + 0.5) / 6.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var b := Basis(Vector3.UP, -a)
		var k2 := MeshKit.new()
		k2.color = RIM
		k2.box(Vector3(0.12, bh, 0.16), Vector3.ZERO)
		k2.color = DETAIL
		for sy: float in [-0.25, 0.25]:
			k2.box(Vector3(0.012, 0.035, 0.035), Vector3(0.066, bh * sy, 0.0))
		for j in k2.verts.size():
			k.verts.append(b * k2.verts[j] + dir * (r * 0.9) + Vector3(0.0, -h + bh * 0.5, 0.0))
			k.normals.append(b * k2.normals[j])
			k.colors.append(k2.colors[j])
	# The drum, tapering a little toward the foot, with eight dark panel seams.
	k.color = body
	k.lathe(PackedVector2Array([Vector2(r * 0.78, y0), Vector2(r * 0.92, y0), Vector2(r * 0.97, h - lip),
			Vector2(r * 0.78, h - lip)]), seg)
	var drum := func(y: float) -> float: return lerpf(r * 0.92, r * 0.97, (y - y0) / (h - lip - y0))
	k.color = DARK
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-dir.z, 0.0, dir.x) * 0.012
		var ends: Array[PackedVector3Array] = []
		for y: float in [y0 + 0.02, h - lip - 0.02]:
			var at: Vector3 = dir * drum.call(y) + Vector3(0.0, y, 0.0)
			ends.append(PackedVector3Array([at - dir * 0.005 - side, at - dir * 0.005 + side, at + dir * 0.004 + side,
					at + dir * 0.004 - side]))
		k.loft(ends[0], ends[1])
	# The banded waist: two dark straps, each with a steel clamp block either side (+-X).
	for t: float in [0.3, 0.42]:
		var y := lerpf(y0, h - lip, t)
		var rr := lerpf(r * 0.92, r * 0.97, t) + 0.015
		k.color = DARK
		k.lathe(PackedVector2Array([Vector2(rr - 0.05, y - 0.03), Vector2(rr, y - 0.03), Vector2(rr, y + 0.03),
				Vector2(rr - 0.05, y + 0.03)]), seg)
		k.color = DETAIL
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(0.04, 0.1, 0.14), Vector3(sx * (rr + 0.016), y, 0.0))
	# The lip: a rolled pale ring with a bolt ring on its top.
	var c := lip * 0.3
	_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(r * 0.79, h - lip), Vector2(r - c, h - lip),
			Vector2(r, h - lip + c), Vector2(r, y_lip - c), Vector2(r - c, y_lip), Vector2(r * 0.84, y_lip),
			Vector2(r * 0.79, h - lip)]), [TRIM] as Array[Color], seg)
	k.color = DETAIL
	_piping_bolts(k, Vector3.ZERO, Vector3.UP, y_lip, 12, (r * 0.84 + r - c) * 0.5, 0.04, 0.012)
	# Inside: a dark liner, the fan face set back, a steel fan case, twisted blades, a spinner.
	var face := h - length * 0.45
	k.color = DARK
	_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(r * 0.79, h - lip), Vector2(r * 0.78, h - lip),
			Vector2(r * 0.78, face), Vector2(0.0, face)]), [DARK] as Array[Color], seg)
	var by := clampf(length * 0.07, 0.06, 0.14)
	k.color = DETAIL
	_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(r * 0.785, face + by + 0.02),
			Vector2(r * 0.73, face + by + 0.02), Vector2(r * 0.73, face)]), [DETAIL] as Array[Color], 24)
	var bt := clampf(r * 0.03, 0.02, 0.05)
	for i in 16:
		_hullkit_vane(k, TAU * float(i) / 16.0, r * 0.17, r * 0.735, face + 0.004, face + by, bt, r * 0.08)
	k.color = TRIM
	k.lathe(PackedVector2Array([Vector2(0.0, face), Vector2(r * 0.19, face), Vector2(r * 0.12, face + length * 0.12),
			Vector2(0.0, face + length * 0.16)]), 16)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * radius * radius * length * 0.3
	var col := CylinderShape3D.new()
	col.radius = radius
	col.height = length
	shape.collision = col
	# The glow: a ring round the spinner's foot, seen between the blade roots.
	var g := MeshKit.new()
	_thrusters_ring(g, r * 0.19, r * 0.36, face + 0.002, face + 0.008, 24)
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A raised vent hood (the white boxes at the corners of the Pioneer's roof): a chamfered
## block `width` across X, `length` along Z and `height` tall in the material colour on a
## galvanised foot flange, two dark panel seams across its top and down its sides, a bolted
## access plate on each side, a V-shaped chevron of two anodised bars standing proud of its
## top (pointing -Z) and a framed intake across its -Z end: a dark slot behind a mesh of
## galvanised bars. Base on -Y.
static func roof_hood(width: float = 1.6, length: float = 1.2, height: float = 0.4) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := Vector3(width, height, length) * 0.5
	var c := minf(0.08, h.y * 0.4)
	# The foot flange, standing out a little all round; the hood sits on it.
	var ft := minf(0.04, height * 0.12)
	var fo := 0.016
	k.color = GALVANISED
	k.box(Vector3(width + fo * 2.0, ft, length + fo * 2.0), Vector3(0.0, -h.y + ft * 0.5, 0.0))
	var yb := -h.y + ft - 0.002
	var outline := PackedVector2Array([Vector2(-h.z, yb), Vector2(h.z, yb), Vector2(h.z, h.y - c),
			Vector2(h.z - c, h.y), Vector2(-h.z + c * 2.0, h.y), Vector2(-h.z, h.y - c * 2.0)])
	k.color = Color.WHITE
	_prism_x(k, outline, -h.x, h.x)
	# Two panel seams: dark strips across the flat top and down both sides, a hair proud.
	var z0 := -h.z + c * 2.0
	var z1 := h.z - c
	var sw := 0.012
	var seams: Array[float] = [lerpf(z0, z1, 0.3), lerpf(z0, z1, 0.7)]
	k.color = DARK
	for z in seams:
		k.box(Vector3(width - 0.004, 0.004, sw), Vector3(0.0, h.y + 0.002, z))
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(0.004, h.y - yb - 0.004, sw), Vector3(sx * (h.x + 0.002), (h.y + yb) * 0.5, z))
	# A bolted access plate on each side, in the middle panel.
	var pz := (seams[1] - seams[0]) * 0.36
	var py := (h.y - yb) * 0.28
	var pc := Vector3(0.0, (h.y + yb) * 0.5 - (h.y - yb) * 0.04, (seams[0] + seams[1]) * 0.5)
	var bs := clampf(height * 0.06, 0.014, 0.026)
	for sx: float in [-1.0, 1.0]:
		k.color = Color.WHITE
		k.box(Vector3(0.006, py * 2.0, pz * 2.0), pc + Vector3(sx * (h.x + 0.003), 0.0, 0.0))
		k.color = DETAIL
		for dy: float in [-1.0, 1.0]:
			for dz: float in [-1.0, 1.0]:
				k.box(Vector3(0.006, bs, bs), pc + Vector3(sx * (h.x + 0.009), dy * (py - bs), dz * (pz - bs)))
	# The chevron: two solid bars from the back corners meeting at the front middle, standing
	# proud of the top (the second a hair lower so their tops don't fight where they cross).
	k.color = ANODISED
	var bar := minf(0.07, width * 0.06)
	var tip := Vector3(0.0, h.y, -h.z + c * 2.0 + 0.12)
	for sx: float in [-1.0, 1.0]:
		var back := Vector3(sx * (h.x - 0.12), h.y, h.z - c - 0.08)
		var dir := (tip - back).normalized()
		var across := Vector3.UP.cross(dir).normalized() * bar * 0.5
		var y0 := Vector3(0.0, -0.002, 0.0)
		var y1 := Vector3(0.0, 0.018 if sx > 0.0 else 0.016, 0.0)
		k.loft(PackedVector3Array([back - across + y0, back + across + y0, back + across + y1, back - across + y1]),
				PackedVector3Array([tip - across + y0, tip + across + y0, tip + across + y1, tip - across + y1]))
	# The intake across the front end: a dark slot behind a mesh of upright bars and one bar
	# across, in a galvanised frame standing proud of the end face.
	var slot := Vector2(width * 0.7, height * 0.3)
	var sc := Vector3(0.0, -h.y + height * 0.4, -h.z)
	var f := clampf(slot.y * 0.18, 0.015, 0.03)
	k.color = DARK
	k.box(Vector3(slot.x, slot.y, 0.012), sc + Vector3(0.0, 0.0, -0.004))
	k.color = GALVANISED
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(slot.x + f * 2.0, f, 0.021), sc + Vector3(0.0, sy * (slot.y + f) * 0.5, -0.0095))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(f, slot.y, 0.021), sc + Vector3(sx * (slot.x + f) * 0.5, 0.0, -0.0095))
	var bars := maxi(int(slot.x / 0.06), 4)
	for i in bars - 1:
		var x := -slot.x * 0.5 + slot.x * float(i + 1) / float(bars)
		k.box(Vector3(0.012, slot.y, 0.008), sc + Vector3(x, 0.0, -0.012))
	k.box(Vector3(slot.x, 0.012, 0.008), sc + Vector3(0.0, 0.0, -0.015))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * length * 0.9
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, length)
	shape.collision = col
	return shape


## Control levers (the red-knobbed levers beside the Pioneer's cockpit): `count` steel rods
## in a row along X, `pitch` apart, standing out of a quadrant housing (a dark kick plinth
## under a chamfered body in the material colour, a dark top plate with a slotted gate per
## lever, corner bolts), each rod rising from a dark rubber gaiter with a grip band near
## the top and a red knob; on the housing's front a pale scale plate with ticks and a small
## amber position lamp per lever (glow). `height` is to the top of the knobs. Stands on -Y.
static func lever_stand(count: int = 2, height: float = 1.2, pitch: float = 0.3,
		glow := Color(1.0, 0.62, 0.2)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var y0 := -height * 0.5
	var width := pitch * float(count)
	var hw := width * 0.5
	var hd := 0.15                              # half the housing's depth, m
	var kick := 0.04                            # plinth height, m
	var base_h := 0.22                          # top of the housing above the floor, m
	var yt := y0 + base_h                       # top of the gate plate
	var yb := yt - 0.044                        # top of the body's straight sides
	# Housing: a set-back plinth, a body with a chamfered top, a dark gate plate with bolts.
	k.color = DARK
	k.box(Vector3(width - 0.04, kick, 2.0 * hd - 0.04), Vector3(0.0, y0 + kick * 0.5, 0.0))
	k.color = Color.WHITE
	k.box(Vector3(width, yb - y0 - kick, 2.0 * hd), Vector3(0.0, (yb + y0 + kick) * 0.5, 0.0))
	_seating_pad(k, Vector3(0.0, yb, 0.0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, hw, hd, 0.02, 0.02)
	k.color = DARK
	_seating_pad(k, Vector3(0.0, yt - 0.024, 0.0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, hw - 0.025, hd - 0.025,
			0.024, 0.008)
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.018, 0.008, 0.018), Vector3(sx * (hw - 0.05), yt + 0.004, sz * (hd - 0.05)))
	var knob := 0.06
	var top := height * 0.5 - knob * 2.0
	var y_face := (y0 + kick + yb) * 0.5        # middle of the housing's front
	for i in count:
		var x := -hw + pitch * (float(i) + 0.5)
		# The gate: a slot along Z in the top plate, steel lips either side.
		k.color = PartShapes.GASKET
		k.box(Vector3(0.05, 0.004, 2.0 * hd - 0.1), Vector3(x, yt + 0.002, 0.0))
		k.color = TRIM
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(0.012, 0.01, 2.0 * hd - 0.1), Vector3(x + sx * 0.032, yt + 0.005, 0.0))
		# The gaiter: a ribbed rubber boot round the rod's foot.
		var first := k.verts.size()
		k.color = DARK
		k.lathe(PackedVector2Array([Vector2(0.0, yt), Vector2(0.042, yt), Vector2(0.034, yt + 0.03),
				Vector2(0.038, yt + 0.045), Vector2(0.026, yt + 0.08), Vector2(0.0, yt + 0.08)]), 10)
		# The rod, its grip band and the knob, lathed round the origin then moved over the slot.
		k.color = TRIM
		k.lathe(PackedVector2Array([Vector2(0.0, yt + 0.07), Vector2(0.018, yt + 0.07), Vector2(0.018, top + 0.005),
				Vector2(0.0, top + 0.005)]), 8)
		k.color = DARK
		k.lathe(PackedVector2Array([Vector2(0.0, top - 0.2), Vector2(0.024, top - 0.2), Vector2(0.028, top - 0.16),
				Vector2(0.028, top - 0.09), Vector2(0.024, top - 0.05), Vector2(0.0, top - 0.05)]), 10)
		k.color = LEVER_KNOB
		k.lathe(PackedVector2Array([Vector2(0.0, top), Vector2(knob * 0.7, top + 0.01), Vector2(knob, top + knob),
				Vector2(knob * 0.7, top + knob * 2.0 - 0.01), Vector2(0.0, top + knob * 2.0)]), 12)
		for j in range(first, k.verts.size()):
			k.verts[j].x += x
		# The front: a scale plate with ticks and a lamp over it.
		k.color = PLATE
		k.box(Vector3(0.1, 0.07, 0.006), Vector3(x, y_face - 0.015, -hd - 0.003))
		k.color = DARK
		for t in 3:
			k.box(Vector3(0.05 - 0.012 * float(t), 0.006, 0.004), Vector3(x, y_face - 0.04 + 0.025 * float(t), -hd - 0.007))
		k.box(Vector3(0.034, 0.034, 0.008), Vector3(x, y_face + 0.045, -hd - 0.004))
		g.box(Vector3(0.022, 0.022, 0.006), Vector3(x, y_face + 0.045, -hd - 0.009))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * base_h * 0.3 + 0.0016 * height * float(count)
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, 0.3)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


# --- K1 miner parts (0.49) --------------------------------------------------------------

## The long top beam of a K1 pod: a chamfered square bar `width` across X, `height` tall and
## `length` along Z in the material colour, dark seams across it every metre or so, a bolted
## access panel with a slot handle on each side of every bay between them, a rubber seal
## strip along both lower edges, a thin yellow-green enamel trim line along both top edges
## and a round galvanised end collar with a bolt ring at each end (the bigger one at +Z). Base on -Y; every piece
## is a hair proud of the bar it sits on.
static func pod_boom(length: float = 12.0, width: float = 1.4, height: float = 0.8) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hx := width * 0.5
	var hy := height * 0.5
	var collar := 0.22
	var z0 := -length * 0.5 + collar * 0.6
	var z1 := length * 0.5 - collar
	var c := minf(0.12, hy * 0.35)
	var outline := func(grow: float) -> PackedVector2Array:
		return PackedVector2Array([Vector2(-hx - grow, -hy), Vector2(hx + grow, -hy), Vector2(hx + grow, hy - c),
				Vector2(hx - c, hy + grow), Vector2(-hx + c, hy + grow), Vector2(-hx - grow, hy - c)])
	var ring := func(o: PackedVector2Array, z: float) -> PackedVector3Array:
		var out := PackedVector3Array()
		for p in o:
			out.append(Vector3(p.x, p.y, z))
		return out
	k.color = Color.WHITE
	var body: PackedVector2Array = outline.call(0.0)
	k.loft(ring.call(body, z0), ring.call(body, z1))
	# Seams across the bar.
	k.color = DARK
	var seams := maxi(1, int(round((z1 - z0) / 1.1)) - 1)
	var seam: PackedVector2Array = outline.call(0.008)
	for i in seams:
		var z := lerpf(z0, z1, float(i + 1) / float(seams + 1))
		k.loft(ring.call(seam, z - 0.025), ring.call(seam, z + 0.025))
	# Trim lines along the top edges.
	k.color = AERO_LIME
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.04, 0.012, z1 - z0 - 0.3), Vector3(sx * (hx - c - 0.05), hy + 0.006, (z0 + z1) * 0.5))
	# A rubber seal strip along each lower edge, and a bolted access panel on each side of
	# every bay between the seams (a hair proud, a dark slot handle in it).
	k.color = RUBBER
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.02, 0.047, z1 - z0 - 0.04), Vector3(sx * (hx + 0.008), -hy + 0.0265, (z0 + z1) * 0.5))
	var bays := seams + 1
	var bay := (z1 - z0) / float(bays)
	var ph := height * 0.42
	var py := -hy + 0.05 + (hy - c - (-hy + 0.05)) * 0.5
	for i in bays:
		var zc := z0 + bay * (float(i) + 0.5)
		var pl := minf(bay * 0.6, 1.2)
		for sx: float in [-1.0, 1.0]:
			k.color = Color.WHITE
			k.box(Vector3(0.008, ph, pl), Vector3(sx * (hx + 0.004), py, zc))
			k.color = DARK
			k.box(Vector3(0.006, ph * 0.12, pl * 0.18), Vector3(sx * (hx + 0.009), py, zc))
			k.color = DETAIL
			for cy: float in [-1.0, 1.0]:
				for cz: float in [-1.0, 1.0]:
					k.box(Vector3(0.012, 0.025, 0.025), Vector3(sx * (hx + 0.012), py + cy * (ph * 0.5 - 0.035), zc + cz * (pl * 0.5 - 0.035)))
	# End collars: lathed round Y, then turned to run out along Z.
	for end: int in 2:
		var turn := Basis(Vector3.RIGHT, PI * 0.5 if end == 1 else -PI * 0.5)
		var first := k.verts.size()
		var r := minf(hx, hy) * (0.9 if end == 1 else 0.7)
		var cl := collar if end == 1 else collar * 0.6
		k.color = GALVANISED
		k.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(r, 0.0), Vector2(r, cl * 0.7), Vector2(r * 0.8, cl),
				Vector2(0.0, cl)]), 20)
		k.color = DARK
		k.lathe(PackedVector2Array([Vector2(r - 0.02, cl * 0.25), Vector2(r + 0.012, cl * 0.25), Vector2(r + 0.012, cl * 0.45),
				Vector2(r - 0.02, cl * 0.45)]), 20)
		k.color = DETAIL
		for b in 8:
			var a := TAU * (float(b) + 0.5) / 8.0
			_thrusters_bolt(k, Vector3(cos(a) * r * 0.6, cl, sin(a) * r * 0.6), maxf(0.012, r * 0.05), 0.012)
		for j in range(first, k.verts.size()):
			k.verts[j] = turn * k.verts[j] + Vector3(0.0, 0.0, z1 if end == 1 else z0)
			k.normals[j] = turn * k.normals[j]
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * length * 0.9
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, length)
	shape.collision = col
	return shape


## A yellow armour cowl (the blocks on the K1's stern corners): a block `size` in the
## material colour whose top slopes down toward -Z over its front `slope` metres, its side
## edges bevelled over the top, slope and front (base and back stay square), two dark panel
## grooves and four bolt heads on each side, a steel-framed slatted vent on top near the
## back, a hazard tab low on the slope and a pale panel on its back face (+Z). Base on -Y.
static func armour_cowl(size: Vector3 = Vector3(1.6, 1.8, 3.0), slope: float = 0.8) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := size * 0.5
	var s := minf(slope, minf(size.y * 0.8, size.z * 0.6))
	var outline := PackedVector2Array([Vector2(-h.z, -h.y), Vector2(h.z, -h.y), Vector2(h.z, h.y), Vector2(-h.z + s, h.y),
			Vector2(-h.z, h.y - s)])
	# The block, its side edges bevelled over the top, slope and front (the base and the
	# back face stay square: they sit against the hull).
	var c := clampf(minf(size.x, size.y) * 0.06, 0.02, 0.08)   # bevel, m
	var bev := _armour_inset(outline, [0.0, 0.0, c, c, c])
	var ring := func(x: float, o: PackedVector2Array) -> PackedVector3Array:
		var out := PackedVector3Array()
		for p in o:
			out.append(Vector3(x, p.y, p.x))
		return out
	k.color = Color.WHITE
	k.loft(ring.call(-h.x, bev), ring.call(-h.x + c, outline), false)
	k.loft(ring.call(-h.x + c, outline), ring.call(h.x - c, outline), false)
	k.loft(ring.call(h.x - c, outline), ring.call(h.x, bev), false)
	k.poly(ring.call(-h.x, bev), Vector3.LEFT)
	k.poly(ring.call(h.x, bev), Vector3.RIGHT)
	# Two panel grooves along each side, bolt heads at the side's corners.
	var br := clampf(size.y * 0.025, 0.015, 0.03)
	for sx: float in [-1.0, 1.0]:
		k.color = DARK
		for t: float in [0.3, 0.62]:
			var y := lerpf(-h.y, h.y - s, t)
			k.box(Vector3(0.012, 0.04, size.z - 0.3), Vector3(sx * (h.x + 0.006), y, 0.1))
		k.color = DETAIL
		var yb := -h.y + br * 3.0
		var yt := lerpf(-h.y, h.y - s, 0.62) + 0.02 + br * 3.0
		for p: Vector2 in [Vector2(-h.z + c + br * 3.0, yb), Vector2(h.z - br * 3.0, yb), Vector2(h.z - br * 3.0, yt),
				Vector2(-h.z + c + br * 3.0, yt)]:
			_gear_bolt(k, Vector3(sx * h.x, p.y, p.x), Vector3(sx, 0.0, 0.0), br, 0.01)
	# The vent on top near the back: a steel frame round a dark slot with slats across it.
	var vw := size.x * 0.6
	var vd := minf(0.5, size.z * 0.2)
	var vz := h.z - 0.45
	k.color = DETAIL
	k.box(Vector3(vw + 0.08, 0.008, vd + 0.08), Vector3(0.0, h.y + 0.004, vz))
	k.color = DARK
	k.box(Vector3(vw, 0.012, vd), Vector3(0.0, h.y + 0.006, vz))
	k.color = DETAIL
	var slats := clampi(int(vd / 0.08), 3, 6)
	for i in slats:
		k.box(Vector3(vw - 0.02, 0.01, 0.025), Vector3(0.0, h.y + 0.014, vz - vd * 0.5 + vd * (float(i) + 0.5) / float(slats)))
	# A hazard tab low on the slope (or the front face when the slope is short).
	var sd := Vector3(0.0, -s, -s).normalized()                 # down the slope
	var sn := Vector3(0.0, 1.0, -1.0).normalized()
	var mid := Vector3(0.0, h.y - s * 0.5, -h.z + s * 0.5)
	var sl := s * sqrt(2.0)
	_gear_hazard(k, mid + sd * sl * 0.18, Vector3.RIGHT, sd, sn, Vector2(minf(size.x * 0.55, 1.0), minf(sl * 0.22, 0.25)),
			minf(sl * 0.06, 0.06))
	# The pale panel on the back face.
	k.color = PLATE
	k.box(Vector3(size.x * 0.6, size.y * 0.45, 0.012), Vector3(0.0, -h.y * 0.1, h.z + 0.006))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size.x * (size.y * size.z - s * s * 0.5)
	var pts := PackedVector3Array()
	for p in outline:
		pts.append(Vector3(-h.x, p.y, p.x))
		pts.append(Vector3(h.x, p.y, p.x))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	return shape


## A convex outline with each edge moved in by its own amount (`offsets[i]` for the edge
## from point i to point i + 1; 0 keeps an edge where it is), corners kept in order: the
## face of a bevelled armour block.
static func _armour_inset(outline: PackedVector2Array, offsets: Array) -> PackedVector2Array:
	var n := outline.size()
	var centre := Vector2.ZERO
	for p in outline:
		centre += p / float(n)
	var normals: Array[Vector2] = []
	for i in n:
		var e := outline[(i + 1) % n] - outline[i]
		var m := Vector2(-e.y, e.x).normalized()
		if m.dot(centre - outline[i]) < 0.0:
			m = -m
		normals.append(m)   # inward
	var out := PackedVector2Array()
	for i in n:
		var j := (i - 1 + n) % n
		# Solve m_j . x = m_j . p + d_j and m_i . x = m_i . p + d_i.
		var p := outline[i]
		var a := normals[j]
		var b := normals[i]
		var ca := a.dot(p) + float(offsets[j])
		var cb := b.dot(p) + float(offsets[i])
		var det := a.x * b.y - a.y * b.x
		out.append(Vector2((ca * b.y - cb * a.y) / det, (a.x * cb - b.x * ca) / det))
	return out


## An SE2 large hydrogen tank (the K1's three tanks in a row): an octagonal body `radius`
## across the flats and `length` along Y in the material colour, an end cap at each end
## narrowing in two facets to a stepped valve boss with a bolt ring (the top one's crown
## kept flat for the filler cap FluidSystem fits), weld beads where the caps meet the body
## and a long seam down one flat, three dark straps with a tensioner block and bolt each on
## the (-X, -Z) flat, and a pale maker's plate with rivets and dark lettering on its +Z
## side. Lies along Y; turn it with `Basis(Vector3.RIGHT, PI / 2)` to lie along the ship.
static func octo_tank(radius: float = 0.9, length: float = 2.6) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := length * 0.5
	var cap := minf(radius * 0.35, length * 0.2)
	var oct := func(r: float, y: float) -> PackedVector3Array:
		var out := PackedVector3Array()
		for i in 8:
			var a := TAU * (float(i) + 0.5) / 8.0
			out.append(Vector3(cos(a) * r, y, sin(a) * r))
		return out
	# Corners sit at r / cos(22.5 deg) so the flats are `radius` from the axis.
	var rc := radius / cos(PI / 8.0)
	var y_lo := -h + cap
	var y_hi := h - cap
	var knee := cap * 0.5
	k.color = Color.WHITE
	k.loft(oct.call(rc, y_lo), oct.call(rc, y_hi), false)
	# Each end cap narrows in two facets: steep, then flatter to the end face.
	k.loft(oct.call(rc * 0.88, -h + knee * 0.6), oct.call(rc, y_lo), false)
	k.loft(oct.call(rc * 0.62, -h), oct.call(rc * 0.88, -h + knee * 0.6), false)
	k.loft(oct.call(rc, y_hi), oct.call(rc * 0.88, h - knee * 0.6), false)
	k.loft(oct.call(rc * 0.88, h - knee * 0.6), oct.call(rc * 0.62, h), false)
	k.poly(oct.call(rc * 0.62, -h), Vector3.DOWN)
	k.poly(oct.call(rc * 0.62, h), Vector3.UP)
	# Weld beads round the joins of body and caps, a hair proud.
	var wb := clampf(radius * 0.012, 0.006, 0.012)
	k.color = DETAIL
	for y: float in [y_lo, y_hi]:
		k.loft(oct.call(rc + wb * 1.1, y - wb), oct.call(rc + wb * 1.1, y + wb))
	# Steel edge rails down the body's eight corners, between the beads.
	for i in 8:
		var d := Vector3(cos(TAU * (float(i) + 0.5) / 8.0), 0.0, sin(TAU * (float(i) + 0.5) / 8.0))
		_vessels_box(k, d * (rc - 0.004), Vector3(0.04, y_hi - y_lo - wb * 6.0, 0.014), Basis(d.cross(Vector3.UP), Vector3.UP, d))
	# A long weld seam down the (+X, -Z) flat, between the beads.
	var sw := clampf(radius * 0.025, 0.012, 0.025)
	var seam_n := Vector3(1.0, 0.0, -1.0).normalized()
	_vessels_box(k, seam_n * (radius + sw * 0.25), Vector3(sw, y_hi - y_lo - wb * 4.0, sw),
			Basis(seam_n.cross(Vector3.UP), Vector3.UP, seam_n))
	# Three dark straps, each with a tensioner block and its bolt on the (-X, -Z) flat (clear
	# of the label on +Z and of the top once the tank lies down).
	var st := 0.012
	var buckle_n := Vector3(-1.0, 0.0, -1.0).normalized()
	var buckle_t := buckle_n.cross(Vector3.UP)
	var bw := clampf(radius * 0.2, 0.1, 0.18)
	for t: float in [0.18, 0.5, 0.82]:
		var y := lerpf(y_lo, y_hi, t)
		k.color = DARK
		k.loft(oct.call(rc + st, y - 0.05), oct.call(rc + st, y + 0.05))
		k.color = DETAIL
		var basis := Basis(buckle_t, Vector3.UP, buckle_n)
		_vessels_box(k, buckle_n * (radius + st + 0.016) + Vector3.UP * y, Vector3(bw, 0.15, 0.032), basis)
		_vessels_box(k, buckle_n * (radius + st + 0.036) + Vector3.UP * y, Vector3(bw * 1.5, 0.026, 0.02), basis)
		k.color = DARK
		_vessels_box(k, buckle_n * (radius + st + 0.034) + Vector3.UP * y, Vector3(bw * 0.5, 0.11, 0.008), basis)
	# Stepped valve bosses on both ends: a bolted outer tier, a raised seat in the middle.
	var rb := radius * 0.26
	var tier := 0.008
	var seat := 0.02
	k.color = DETAIL
	_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(rb, h), Vector2(rb, h + tier),
			Vector2(rb * 0.6, h + tier), Vector2(rb * 0.6, h + seat), Vector2(0.0, h + seat)]),
			[DETAIL, DETAIL, DETAIL, DARK] as Array[Color], 12)
	_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(0.0, -h - seat), Vector2(rb * 0.6, -h - seat),
			Vector2(rb * 0.6, -h - tier), Vector2(rb, -h - tier), Vector2(rb, -h)]),
			[DARK, DETAIL, DETAIL, DETAIL] as Array[Color], 12)
	k.color = DETAIL
	var bs := maxf(rb * 0.14, 0.014)
	_piping_bolts(k, Vector3(0.0, h + tier, 0.0), Vector3.UP, 0.0, 6, rb * 0.8, bs, 0.007)
	_piping_bolts(k, Vector3(0.0, -h - tier, 0.0), Vector3.DOWN, 0.0, 6, rb * 0.8, bs, 0.007)
	# The maker's plate on +Z with a rivet in each corner and dark lettering.
	var pw := radius * 0.7
	var ph := length * 0.22
	var py := length * 0.12
	var pz := radius + 0.006
	k.color = PLATE
	k.box(Vector3(pw, ph, 0.012), Vector3(0.0, py, pz))
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			k.box(Vector3(0.018, 0.018, 0.008), Vector3(sx * (pw * 0.5 - 0.03), py + sy * (ph * 0.5 - 0.03), pz + 0.009))
	k.color = DARK
	for j in 3:
		var lw := pw * (0.7 - 0.18 * float(j))
		k.box(Vector3(lw, ph * 0.07, 0.004), Vector3(-(pw * 0.7 - lw) * 0.5, py + ph * (0.22 - 0.2 * float(j)), pz + 0.007))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = 8.0 * radius * radius * tan(PI / 8.0) * (length - cap)
	var pts := PackedVector3Array()
	pts.append_array(oct.call(rc, -h + cap))
	pts.append_array(oct.call(rc, h - cap))
	pts.append_array(oct.call(rc * 0.62, -h))
	pts.append_array(oct.call(rc * 0.62, h))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	return shape


## A box `size` (along the basis's x, y and z) centred at `centre` and turned by `basis`
## (straps' buckles, bolts and seams on a tank's diagonal flats).
static func _vessels_box(k: MeshKit, centre: Vector3, size: Vector3, basis: Basis) -> void:
	var hx := basis.x * size.x * 0.5
	var hy := basis.y * size.y * 0.5
	var hz := basis.z * size.z * 0.5
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		a.append(centre - hy + hx * c.x + hz * c.y)
		b.append(centre + hy + hx * c.x + hz * c.y)
	k.loft(a, b)


# --- Iridium miner parts (0.50) -----------------------------------------------------------

## A round mining drill (the Iridium's two bow drills, the N-M1's pair): a chamfered square
## drive housing at -Y on a bolted foot flange with a hazard band round its faces (a dark
## band on short housings), corner bolts on top, two hydraulic hoses up its +X corners into
## the collar and an amber work lamp on its top (PartShape.glow); a short round collar with
## a bolted flange and a dark ring of coolant nozzles, and a ball `radius` across studded
## with rings of chunky four-sided teeth (grey and dark by turns, bright carbide points) on
## square steel holders, a blunt tooth on the tip. `length` is the whole part; the housing
## takes what the collar and the ball leave (at least 0.15 m). Collision is the hull of the
## housing, the ball and the teeth's tips.
static func spike_drill(radius: float = 0.75, length: float = 2.0) -> PartShapes.PartShape:
	const HOUSING := Color(0.32, 0.33, 0.35)       # the drive housing's dark steel
	const TOOTH_LIGHT := Color(0.5, 0.51, 0.53)    # the light teeth
	var k := MeshKit.new()
	var g := MeshKit.new()
	var tooth := radius * 0.2
	var collar := radius * 0.12
	var y0 := -length * 0.5
	var house := maxf(0.15, length - collar - radius * 1.85 - tooth)
	var hw := radius * 0.85
	var hb := hw - 0.025
	var c := hw * 0.15
	var fl := clampf(house * 0.15, 0.025, 0.06)
	var c0 := y0 + house
	# The housing: a foot flange and a chamfered body, bolts round the flange.
	k.color = HOUSING
	k.loft(_chamfer_ring(hw, y0, c * 1.1), _chamfer_ring(hw, y0 + fl, c * 1.1))
	k.loft(_chamfer_ring(hb, y0 + fl, c), _chamfer_ring(hb, c0, c))
	var bolt_r := clampf(radius * 0.025, 0.012, 0.025)
	var faces: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
	k.color = DETAIL
	for n: Vector3 in faces:
		var u := Vector3(-n.z, 0.0, n.x)
		for s: float in [-1.0, 0.0, 1.0]:
			_gear_bolt(k, n * (hw - 0.013) + u * s * (hb - c) * 0.6 + Vector3(0.0, y0 + fl, 0.0), Vector3.UP, bolt_r, bolt_r)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_thrusters_bolt(k, Vector3(sx * (hb - 0.09), c0, sz * (hb - 0.09)), 0.035, 0.05)
	# A hazard band round the faces (a dark band when the housing is too short for one).
	var body_h := c0 - (y0 + fl)
	var band_h := body_h * 0.5
	var band_y := y0 + fl + body_h * 0.48
	var face_w := (hb - c) * 2.0 * 0.92
	if band_h >= 0.07:
		for n: Vector3 in faces:
			_gear_hazard(k, n * hb + Vector3(0.0, band_y, 0.0), Vector3(-n.z, 0.0, n.x), Vector3.UP, n,
					Vector2(face_w, band_h), band_h * 0.6)
	else:
		k.color = DARK
		k.loft(_chamfer_ring(hb + 0.01, band_y - band_h * 0.5, c), _chamfer_ring(hb + 0.01, band_y + band_h * 0.5, c))
	# The collar: a bolted flange, a drum, a dark ring of coolant nozzles round its top.
	var rf := radius * 0.68
	var rc := radius * 0.6
	k.color = COLLAR
	k.lathe(PackedVector2Array([Vector2(0.0, c0), Vector2(rf, c0), Vector2(rf, c0 + collar * 0.4), Vector2(0.0, c0 + collar * 0.4)]), 16)
	k.lathe(PackedVector2Array([Vector2(0.0, c0), Vector2(rc, c0), Vector2(rc, c0 + collar), Vector2(0.0, c0 + collar)]), 16)
	k.color = DETAIL
	_piping_bolts(k, Vector3(0.0, c0, 0.0), Vector3.UP, collar * 0.4, 8, (rf + rc) * 0.5, bolt_r * 1.6, bolt_r)
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(rc * 0.96, c0 + collar * 0.55), Vector2(rc * 1.08, c0 + collar * 0.6),
			Vector2(rc * 1.08, c0 + collar * 0.95), Vector2(rc * 0.96, c0 + collar)]), 16)
	k.color = DETAIL
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		var out := Vector3(cos(a), 0.0, sin(a))
		k.strut(out * rc * 1.04 + Vector3(0.0, c0 + collar * 0.75, 0.0), out * rc * 0.98 + Vector3(0.0, c0 + collar * 1.5, 0.0),
				maxf(0.018, radius * 0.035))
	# Hydraulic hoses up the +X corners and over the top into the collar.
	var hr := clampf(radius * 0.035, 0.018, 0.035)
	for sz: float in [-1.0, 1.0]:
		var d := Vector3(1.0, 0.0, sz).normalized()
		var corner := Vector3(hb - c * 0.5, 0.0, sz * (hb - c * 0.5)) + d * (hr + 0.005)
		_drills_hose(k, PackedVector3Array([corner + Vector3(0.0, y0 + fl + hr * 2.0, 0.0),
				corner + Vector3(0.0, c0 + hr, 0.0), d * (rf + hr * 1.5) + Vector3(0.0, c0 + hr * 1.2, 0.0),
				d * (rc - hr * 0.5) + Vector3(0.0, c0 + collar * 0.3 + hr, 0.0)]), hr)
	# A work lamp on the top's -X +Z corner, facing the work (+Y).
	var ls := clampf(radius * 0.11, 0.06, 0.11)
	_drills_lamp(k, g, Vector3(-(hb - ls * 1.1), c0, hb - ls * 1.1), Vector3.UP, Vector3(1.0, 0.0, 1.0).normalized(), ls)
	# The ball: its centre sits so its back sinks a little into the collar.
	var yc := c0 + collar + radius * 0.85
	var prof := PackedVector2Array([Vector2(0.0, yc - radius)])
	for i in range(1, 8):
		var a := PI * float(i) / 8.0
		prof.append(Vector2(sin(a) * radius, yc - cos(a) * radius))
	prof.append(Vector2(0.0, yc + radius))
	k.color = DARK
	k.lathe(prof, 16)
	# Teeth: rings of pyramids on square holders from the equator round to the front, one
	# on the tip.
	var tips := PackedVector3Array()
	var rows := [[0.5, 10], [0.32, 9], [0.16, 6]]
	var dirs: Array[Vector3] = []
	for r in rows.size():
		var lat: float = float(rows[r][0]) * PI   # angle from the axis
		var n: int = rows[r][1]
		for i in n:
			var a := TAU * (float(i) + 0.5 * float(r)) / float(n)
			dirs.append(Vector3(cos(a) * sin(lat), cos(lat), sin(a) * sin(lat)))
	dirs.append(Vector3.UP)
	var half := radius * 0.17
	for j in dirs.size():
		var dir: Vector3 = dirs[j]
		var u := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
		var v := dir.cross(u)
		var centre := Vector3(0.0, yc, 0.0)
		k.color = DETAIL
		k.loft(_drills_square(centre + dir * radius * 0.86, u, v, half * 0.85),
				_drills_square(centre + dir * radius * 1.0, u, v, half * 0.85))
		var base := centre + dir * radius * 0.99
		var tip := centre + dir * (radius + tooth)
		var mid := base.lerp(tip, 0.55)
		var lo := _drills_square(base, u, v, half * 0.7)
		var hi := _drills_square(mid, u, v, half * 0.32)
		k.color = TOOTH_LIGHT if j % 2 == 0 else TOOTH_DARK
		k.loft(lo, hi, false)
		k.color = TRIM
		for i in 4:
			var p := hi[i]
			var q := hi[(i + 1) % 4]
			k.tri(p, q, tip, (p + q) * 0.5 - mid + dir * half * 0.3)
		tips.append(tip)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = hw * hw * 4.0 * house * 0.6 + 4.0 / 3.0 * PI * pow(radius, 3.0) * 0.4
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * hw, y0, sz * hw))
			pts.append(Vector3(sx * hw, c0, sz * hw))
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector3(cos(a) * radius, yc, sin(a) * radius))
		pts.append(Vector3(cos(a) * radius * 0.7, yc - radius * 0.7, sin(a) * radius * 0.7))
	pts.append_array(tips)
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = GLOWING
	return shape


## An SE2 connector (the gold-rimmed ring in the middle of the Iridium's stern): a square
## dark base plate with cut corners and corner bolts, a thick round collar `radius` across
## in `collar` (fit it with a near-white material) with four latch housings round its foot,
## a gold rim round its outer face and a gold band round its waist, and inside it a dark
## recessed face with four clamp jaws reaching in from the wall, a round contact boss in
## the middle and a small green status light (glow). Face +Y, base on -Y; `depth` the
## whole part.
static func connector_ring(radius: float = 0.75, depth: float = 0.45, collar := Color(0.12, 0.62, 0.36)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := depth * 0.5
	var base := depth * 0.22
	var side := radius * 2.0 + 0.16
	var y_b := -h + base
	var cut := side * 0.07
	k.color = DARK
	k.loft(_chamfer_ring(side * 0.5, -h, cut), _chamfer_ring(side * 0.5, y_b, cut))
	k.color = DETAIL
	var bc := side * 0.5 - cut * 0.5 - 0.035
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_gear_bolt(k, Vector3(sx * bc, y_b, sz * bc), Vector3.UP, clampf(radius * 0.03, 0.012, 0.022), 0.012)
	var inner := radius * 0.7
	var rim := 0.05
	k.color = collar
	k.lathe(PackedVector2Array([Vector2(inner, y_b - 0.002), Vector2(radius, y_b - 0.002), Vector2(radius, h - rim),
			Vector2(inner, h - rim)]), 28)
	k.color = GOLD
	k.lathe(PackedVector2Array([Vector2(inner, h - rim), Vector2(radius, h - rim), Vector2(radius * 0.97, h),
			Vector2(inner + 0.02, h)]), 28)
	# A thin gold band round the collar's waist.
	var waist := y_b + depth * 0.25
	k.lathe(PackedVector2Array([Vector2(radius, waist), Vector2(radius + 0.012, waist),
			Vector2(radius + 0.012, waist + 0.04), Vector2(radius, waist + 0.04)]), 28)
	# Four latch housings round the collar's foot, on the diagonals, each with a bolt.
	var lw := clampf(radius * 0.22, 0.07, 0.16)
	var lt := clampf(radius * 0.04, 0.016, 0.03)
	var lh := maxf(waist - y_b - 0.01, 0.03)
	for i in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		k.color = DETAIL
		_gear_yblock(k, dir * (radius + lt * 0.5 - 0.004) + Vector3(0.0, y_b + lh * 0.5, 0.0), -a, Vector3(lt, lh, lw))
		k.color = DARK
		_gear_bolt(k, dir * (radius + lt - 0.004) + Vector3(0.0, y_b + lh * 0.55, 0.0), dir, lt * 0.55, 0.008)
	# The recessed face, four clamp jaws from the wall, the contact boss.
	var face := h - depth * 0.45
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(0.0, y_b - 0.002), Vector2(inner - 0.005, y_b - 0.002), Vector2(inner - 0.005, face),
			Vector2(0.0, face)]), 28)
	var jaw := inner * 0.28                      # how far a jaw reaches in, m
	var jaw_h := (h - rim - face) * 0.55
	for i in 4:
		var a := TAU * float(i) / 4.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		k.color = DETAIL
		_gear_yblock(k, dir * (inner - jaw * 0.5 + 0.003) + Vector3(0.0, face + jaw_h * 0.5 - 0.002, 0.0), -a,
				Vector3(jaw, jaw_h, inner * 0.36))
		k.color = TRIM
		_gear_yblock(k, dir * (inner - jaw - 0.004) + Vector3(0.0, face + jaw_h * 0.45, 0.0), -a,
				Vector3(0.012, jaw_h * 0.7, inner * 0.3))
	k.color = RIM
	k.lathe(PackedVector2Array([Vector2(0.0, face - 0.002), Vector2(inner * 0.3, face - 0.002), Vector2(inner * 0.27, face + jaw_h * 0.6),
			Vector2(0.0, face + jaw_h * 0.6)]), 12)
	k.color = TRIM
	k.lathe(PackedVector2Array([Vector2(inner * 0.12, face + jaw_h * 0.6 - 0.002), Vector2(inner * 0.22, face + jaw_h * 0.6 - 0.002),
			Vector2(inner * 0.22, face + jaw_h * 0.6 + 0.01), Vector2(inner * 0.12, face + jaw_h * 0.6 + 0.01)]), 12)
	# The status light's dark bezel on the face, between two jaws.
	var lamp := Vector3(inner * 0.45, face, inner * 0.45)
	k.color = DARK
	_gear_yblock(k, lamp + Vector3(0.0, 0.006, 0.0), -PI * 0.25, Vector3(minf(0.05, inner * 0.2), 0.012, minf(0.12, inner * 0.4)))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = side * side * base + PI * (radius * radius - inner * inner) * (depth - base)
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * side * 0.5, -h, sz * side * 0.5))
			pts.append(Vector3(sx * side * 0.5, -h + base, sz * side * 0.5))
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector3(cos(a) * (radius + 0.012), h, sin(a) * (radius + 0.012)))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	var g := MeshKit.new()
	_gear_yblock(g, lamp + Vector3(0.0, 0.014, 0.0), -PI * 0.25, Vector3(minf(0.03, inner * 0.12), 0.006, minf(0.09, inner * 0.3)))
	shape.glow = g.finish()
	shape.glow_color = Color(0.3, 1.0, 0.45)
	return shape


# --- Forge welder parts (0.58) ------------------------------------------------------------

## An SE2 large welder (the Forge's three bow welders, which reach out on pistons to weld
## inside a hull): a dark mount plate and a square drive housing `width` across at the -Y
## end, with louvred vents on its X sides, screwed access panels on its Z sides (a status
## strip of lit LEDs on -Z) and a dark band; a body tapering toward the tip with two dark
## bands, a yellow ring, a maker's plate and hydraulic hoses up its X sides in clamps to the
## head frame; at the +Y end a square head frame with bolted clevis blocks at its corners,
## four pinned claws that lean out and close back in, each pushed by a hydraulic ram (dark
## cylinder, bright rod) and tipped with a yellow shoe and a copper contact, round a finned
## dark emitter drum with a bright emitter ring. Two glowing arcs cross in an X from claw
## tip to claw tip, the emitter's face glows inside its ring (PartShape.glow). `length` the
## whole part along Y. Housing and body take the material colour.
static func ship_welder(width: float = 1.8, length: float = 4.0, glow := Color(0.45, 0.82, 1.0)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var h := length * 0.5
	var w := width * 0.5
	var plate := 0.1
	var y1 := -h + plate
	var y2 := y1 + length * 0.32          # top of the drive housing
	var y3 := h - length * 0.3            # bottom of the head frame
	var neck := w * 0.62
	var c := w * 0.18
	var hw := w - 0.03                    # the housing's half width, m
	# The mount plate, its edges chamfered.
	k.color = DARK
	k.loft(_chamfer_ring(w, -h, c * 0.6), _chamfer_ring(w, y1, c * 0.6))
	k.color = Color.WHITE
	k.loft(_chamfer_ring(hw, y1, c), _chamfer_ring(hw, y2, c))
	# The body tapers from the housing to the neck.
	var body_lo := w * 0.86
	k.loft(_chamfer_ring(body_lo, y2, c * 0.8), _chamfer_ring(neck, y3, c * 0.5))
	var at := func(y: float) -> float: return lerpf(body_lo, neck, (y - y2) / (y3 - y2))
	k.color = DARK
	for yb: float in [y2 + 0.12, y2 + (y3 - y2) * 0.5]:
		var r0 := float(at.call(yb)) + 0.015
		var r1 := float(at.call(yb + 0.1)) + 0.015
		k.loft(_chamfer_ring(r0, yb, c * 0.7), _chamfer_ring(r1, yb + 0.1, c * 0.7))
	# A dark band round the housing's waist, a yellow ring round the neck.
	k.loft(_chamfer_ring(w - 0.015, y1 + 0.25, c), _chamfer_ring(w - 0.015, y1 + 0.37, c))
	k.color = CLAW_YELLOW
	var yy := y3 - 0.16
	k.loft(_chamfer_ring(float(at.call(yy)) + 0.02, yy, c * 0.5), _chamfer_ring(float(at.call(yy + 0.1)) + 0.02, yy + 0.1, c * 0.5))
	# The housing's faces above the band: louvres on the X sides, access panels on the Z
	# sides with a screw in each corner, the -Z one under a dark status strip.
	var la := y1 + 0.37 + 0.12
	var lb := y2 - 0.14
	var face := hw - c                     # half the flat of each face, m
	var pw := face * 1.5
	for sx: float in [-1.0, 1.0]:
		k.color = DARK
		k.box(Vector3(0.006, lb - la, pw), Vector3(sx * (hw + 0.003), (la + lb) * 0.5, 0.0))
		k.color = Color.WHITE
		var slats := maxi(int((lb - la) / 0.11), 4)
		for i in slats:
			var sy := lerpf(la + 0.05, lb - 0.05, float(i) / float(slats - 1))
			k.box(Vector3(0.022, 0.034, pw - 0.04), Vector3(sx * (hw + 0.011), sy, 0.0))
	var pa := la
	var pb := lb - 0.16
	for sz: float in [-1.0, 1.0]:
		k.color = Color.WHITE
		k.box(Vector3(pw, pb - pa, 0.008), Vector3(0.0, (pa + pb) * 0.5, sz * (hw + 0.004)))
		k.color = DARK
		k.box(Vector3(pw * 0.9, 0.012, 0.004), Vector3(0.0, pa + (pb - pa) * 0.62, sz * (hw + 0.009)))
		k.color = DETAIL
		for cx: float in [-1.0, 1.0]:
			for cy: float in [-1.0, 1.0]:
				_gear_bolt(k, Vector3(cx * (pw * 0.5 - 0.05), (pa + pb) * 0.5 + cy * ((pb - pa) * 0.5 - 0.05), sz * (hw + 0.008)),
						Vector3(0.0, 0.0, sz), 0.016, 0.01)
	var led_y := lb - 0.06
	k.color = DARK
	k.box(Vector3(pw * 0.55, 0.07, 0.008), Vector3(0.0, led_y, -(hw + 0.004)))
	for i in 3:
		g.box(Vector3(0.04, 0.03, 0.005), Vector3(-pw * 0.16 + pw * 0.16 * float(i), led_y, -(hw + 0.0105)))
	# A maker's plate on the body's -Z face, dark lettering on it.
	var ym := lerpf(y2 + 0.22, y2 + (y3 - y2) * 0.5, 0.5)
	var zm := float(at.call(ym))
	k.color = PLATE
	k.box(Vector3(neck * 0.8, 0.2, 0.008), Vector3(0.0, ym, -zm - 0.004))
	k.color = DARK
	for j in 2:
		k.box(Vector3(neck * (0.6 - 0.2 * float(j)), 0.03, 0.004), Vector3(-neck * 0.1 * float(j), ym + 0.04 - 0.08 * float(j), -zm - 0.01))
	# Hydraulic hoses up both X sides from fittings on the housing's shoulder to the head
	# frame, held off the body by clamps.
	var hr := clampf(width * 0.027, 0.025, 0.05)
	var off := 0.012 + hr
	for sx: float in [-1.0, 1.0]:
		for hz: float in [-0.2, 0.2]:
			var hz_s := hz * width / 1.5
			var a := Vector3(sx * (float(at.call(y2)) + off), y2, hz_s)
			var b := Vector3(sx * (neck + off), y3, hz_s)
			k.color = TRIM
			_tube(k, a - Vector3(0.0, 0.02, 0.0), a + Vector3(0.0, 0.06, 0.0), hr * 1.4, 8)
			_tube(k, b - Vector3(0.0, 0.06, 0.0), b + Vector3(0.0, 0.01, 0.0), hr * 1.35, 8)
			k.color = DARK
			_tube(k, a, b, hr, 8)
			k.color = DETAIL
			for f: float in [0.3, 0.75]:
				var p := a.lerp(b, f)
				k.box(Vector3(off + hr - 0.01, 0.05, hr * 2.6), Vector3(sx * (float(at.call(p.y)) + (off + hr) * 0.5), p.y, hz_s))
	# The head frame: four bars round a square, a bolted clevis block on each corner.
	var fw := neck + 0.08
	var ft := 0.14
	var fy := y3 + ft * 0.5
	k.color = FRAME_GREY
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(ft, ft, fw * 2.0), Vector3(sx * (fw - ft * 0.5), fy, 0.0))
		k.box(Vector3(fw * 2.0 - ft * 2.0, ft, ft), Vector3(0.0, fy, sx * (fw - ft * 0.5)))
	# The claws: out from each corner, then in to the tip, pinned at the base and the knee,
	# a ram on the outside of each from a lug on the frame's corner to the knee.
	var tip_r := neck * 0.42
	var mid_y := y3 + ft + (h - y3 - ft) * 0.45
	var tips: Array[Vector3] = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var d := Vector3(sx, 0.0, sz).normalized()
			var pin := Vector3(-sz, 0.0, sx).normalized()
			var base := Vector3(sx * (fw - ft * 0.5), y3 + ft, sz * (fw - ft * 0.5))
			var knee := Vector3(sx * (fw + 0.06), mid_y, sz * (fw + 0.06))
			var tip := Vector3(sx * tip_r, h - 0.04, sz * tip_r)
			# Clevis block, bolted down, its pin across the claw's plane.
			k.color = FRAME_GREY
			k.box(Vector3(0.2, 0.07, 0.2), base + Vector3(0.0, 0.035, 0.0))
			k.color = DETAIL
			for e: float in [-1.0, 1.0]:
				_gear_bolt(k, base + Vector3(0.0, 0.07, 0.0) + pin * e * 0.07, Vector3.UP, 0.016, 0.012)
			k.color = Color(0.82, 0.83, 0.85)
			k.strut(base + Vector3(0.0, 0.05, 0.0), knee, 0.16)
			k.strut(knee, tip, 0.13)
			k.color = TRIM
			_tube(k, base + Vector3(0.0, 0.07, 0.0) - pin * 0.11, base + Vector3(0.0, 0.07, 0.0) + pin * 0.11, 0.035, 8)
			_tube(k, knee - pin * 0.1, knee + pin * 0.1, 0.045, 8)
			# The ram: a lug on the frame's outer corner, a dark cylinder, a bright rod.
			var lug := Vector3(sx * (fw + 0.02), fy, sz * (fw + 0.02))
			k.color = FRAME_GREY
			k.box(Vector3(0.08, ft * 0.8, 0.08), lug)
			var r_end := knee + d * 0.07 + Vector3(0.0, -0.04, 0.0)
			var r_mid := lug.lerp(r_end, 0.55)
			k.color = DARK
			_tube(k, lug + Vector3(0.0, 0.02, 0.0), r_mid, 0.045, 8)
			k.color = TRIM
			_tube(k, r_mid - (r_mid - lug).normalized() * 0.02, r_end, 0.024, 8)
			tips.append(tip)
	# The shoes on the claw tips, a copper contact on each facing the emitter.
	for tp in tips:
		k.color = CLAW_YELLOW
		k.box(Vector3(0.1, 0.08, 0.1), tp)
		k.color = COPPER
		var inward := Vector3(-tp.x, 0.0, -tp.z).normalized()
		k.box(Vector3(0.045, 0.045, 0.045), tp + inward * 0.065)
	# The emitter drum between the claws: cooling fins round it, a bright ring round its face.
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(0.0, y3 + ft), Vector2(neck * 0.45, y3 + ft), Vector2(neck * 0.38, mid_y),
			Vector2(0.0, mid_y)]), 16)
	k.color = DETAIL
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		_hullkit_vane(k, a, neck * 0.36, neck * 0.5, y3 + ft + 0.06, mid_y - 0.1, 0.02)
	k.color = TRIM
	_thrusters_ring(k, neck * 0.31, neck * 0.43, mid_y - 0.05, mid_y + 0.03, 16)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * width * (y2 + h) * 0.8 + (body_lo + neck) * (body_lo + neck) * (y3 - y2) * 0.8 + fw * fw * 4.0 * (h - y3) * 0.25
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * w, -h, sz * w))
			pts.append(Vector3(sx * w, y2, sz * w))
			pts.append(Vector3(sx * (fw + 0.14), mid_y, sz * (fw + 0.14)))
			pts.append(Vector3(sx * (tip_r + 0.08), h, sz * (tip_r + 0.08)))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	# The glowing X between the claw tips, just inside them, and the emitter's lit face.
	var gy := h - 0.12
	var gr := tip_r - 0.06
	g.strut(Vector3(-gr, gy, -gr), Vector3(gr, gy, gr), 0.035)
	g.strut(Vector3(gr, gy - 0.04, -gr), Vector3(-gr, gy - 0.04, gr), 0.035)
	g.lathe(PackedVector2Array([Vector2(0.0, mid_y), Vector2(neck * 0.3, mid_y), Vector2(neck * 0.3, mid_y + 0.02),
			Vector2(0.0, mid_y + 0.02)]), 16)
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## Eight points of a square `half` across with its corners cut by `c`, at height y (XZ).
static func _chamfer_ring(half: float, y: float, c: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(half - c, y, -half), Vector3(half, y, -half + c), Vector3(half, y, half - c),
			Vector3(half - c, y, half), Vector3(-half + c, y, half), Vector3(-half, y, half - c),
			Vector3(-half, y, -half + c), Vector3(-half + c, y, -half)])


## Block letters for `name_board`: each glyph is a list of convex outlines (u, v) on a 4 by
## 6 grid, u to the right, v up. Characters not listed draw as a plain block.
const _GLYPHS := {
	"F": [[0, 0, 1, 6], [1, 5, 4, 6], [1, 2.5, 3, 3.5]],
	"O": [[0, 0, 1, 6], [3, 0, 4, 6], [1, 0, 3, 1], [1, 5, 3, 6]],
	"R": [[0, 0, 1, 6], [1, 5, 3, 6], [3, 3.5, 4, 5.5], [1, 2.5, 3, 3.5], [[1.9, 2.5], [3, 2.5], [4, 0], [2.9, 0]]],
	"G": [[0, 1, 1, 5], [1, 5, 4, 6], [0.6, 0, 4, 1], [3, 1, 4, 3], [2, 2, 3, 3]],
	"E": [[0, 0, 1, 6], [1, 5, 4, 6], [1, 0, 4, 1], [1, 2.5, 3, 3.5]],
	"T": [[0, 5, 4, 6], [1.5, 0, 2.5, 5]],
	"I": [[1.5, 0, 2.5, 6]],
	"A": [[0, 0, 1, 5], [3, 0, 4, 5], [0.5, 5, 3.5, 6], [1, 2.5, 3, 3.5]],
	"N": [[0, 0, 1, 6], [3, 0, 4, 6], [[1, 6], [1.9, 6], [3, 2], [3, 0.4]]],
	# Corsair frigate rebuild: CMS.
	"C": [[0, 1, 1, 5], [0.6, 5, 4, 6], [0.6, 0, 4, 1]],
	"M": [[0, 0, 1, 6], [3, 0, 4, 6], [[1, 6], [1.7, 6], [2, 3.6], [2, 2.2]], [[2, 2.2], [2, 3.6], [2.3, 6], [3, 6]]],
	"S": [[0.6, 5, 4, 6], [0, 3.5, 1, 5], [0, 2.5, 3.4, 3.5], [3, 1, 4, 2.5], [0, 0, 3.4, 1]],
	# Ship carrier rebuild: PORPOISE.
	"P": [[0, 0, 1, 6], [1, 5, 3, 6], [3, 3, 4, 5.5], [1, 2.5, 3, 3.5]],
	# Novaris: V (two strokes meeting at the foot).
	"V": [[[0, 6], [1, 6], [2, 1.6], [2, 0]], [[3, 6], [4, 6], [2, 0], [2, 1.6]]],
	# Race carrier: D and K ("DARKSPOT").
	"D": [[0, 0, 1, 6], [1, 5, 3, 6], [1, 0, 3, 1], [3, 1, 4, 5], [[3, 5], [4, 5], [3, 6]], [[3, 0], [4, 1], [3, 1]]],
	"K": [[0, 0, 1, 6], [[1, 2.5], [4, 6], [3, 6], [1, 3.7]], [[1.9, 3.55], [3, 0], [4, 0], [2.6, 4.37]]],
	# Frigate (Sentinel): L ("SENTINAL").
	"L": [[0, 0, 1, 6], [1, 0, 4, 1]],
}


## A ship's name sign (the Forge's lit FORGE boards down the pods): a dark board `length`
## by `height` and `depth` thick, its face edges chamfered, a steel frame strip along each
## long edge with a row of bolts, the letters of `text` standing proud of its face in pale
## block capitals, a slatted vent in a steel frame at each end and a thin white light in a
## dark channel down each end (PartShape.glow). Face +Y; the text reads along +X with the letters' tops toward -Z, so
## on a ship's side turn it with a basis whose X runs the reading way, Y out of the hull
## and Z down.
static func name_board(text: String = "FORGE", length: float = 7.0, height: float = 1.6, depth: float = 0.18) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hl := length * 0.5
	var hh := height * 0.5
	var d := depth * 0.5
	# The board, its face edges chamfered.
	var bev := 0.015
	k.color = DARK
	_seating_pad(k, Vector3(0.0, -d, 0.0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, hl, hh, depth, bev)
	# A steel frame strip along each long edge, bolted.
	var fw := clampf(height * 0.035, 0.025, 0.05)   # frame strip width, m
	var bolts := clampi(int(length / 1.5) + 2, 3, 6)
	for sz: float in [-1.0, 1.0]:
		var fz := sz * (hh - bev - fw * 0.5)
		k.color = DETAIL
		k.box(Vector3(length - 2.0 * bev - 0.01, 0.016, fw), Vector3(0.0, d + 0.008, fz))
		k.color = TRIM
		for b in bolts:
			var bx := (-0.5 + (float(b) + 0.5) / float(bolts)) * (length - 0.4)
			k.box(Vector3(minf(fw - 0.006, 0.03), 0.008, minf(fw - 0.006, 0.03)), Vector3(bx, d + 0.02, fz))
	# The vents: a recessed grey panel in a steel frame with pale slats across it at each end.
	var vent_w := height * 0.62
	var vent_h := height * 0.62
	var proud := 0.05
	var vf := 0.025                                  # vent frame width, m
	for sx: float in [-1.0, 1.0]:
		var vx := sx * (hl - 0.12 - vent_w * 0.5)
		k.color = RIM
		k.box(Vector3(vent_w, 0.02, vent_h), Vector3(vx, d + 0.01, 0.0))
		k.color = DETAIL
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(vent_w, 0.025, vf), Vector3(vx, d + 0.0325, sz * (vent_h - vf) * 0.5))
		for sv: float in [-1.0, 1.0]:
			k.box(Vector3(vf, 0.025, vent_h - 2.0 * vf), Vector3(vx + sv * (vent_w - vf) * 0.5, d + 0.0325, 0.0))
		k.color = TRIM
		for i in 5:
			var vz := -vent_h * 0.5 + vent_h * (float(i) + 0.5) / 5.0
			k.box(Vector3(vent_w - 0.06, proud, 0.05), Vector3(vx, d + 0.02 + proud * 0.5, vz))
	# The edge lights' dark channels, standing a little proud of the face.
	var lamp_h := hh - bev - fw - 0.005               # half the channel's length, m
	k.color = PartShapes.GASKET
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.07, 0.014, 2.0 * lamp_h), Vector3(sx * (hl - 0.06), d + 0.007, 0.0))
	# The letters, spaced evenly between the vents.
	var room := length - 2.0 * (0.24 + vent_w)
	var cap := height * 0.62
	var unit := cap / 6.0
	var n := text.length()
	var pitch := minf(room / maxf(float(n), 1.0), unit * 6.2)
	var glyph_w := unit * 4.0
	var letter_t := 0.08
	k.color = Color(0.9, 0.91, 0.92)
	for i in n:
		var ch := text[i]
		var x0 := -pitch * float(n) * 0.5 + pitch * (float(i) + 0.5) - glyph_w * 0.5
		var parts: Array = _GLYPHS.get(ch, _DIGITS.get(ch, [[0, 0, 4, 6]]))
		for piece: Array in parts:
			var outline := PackedVector2Array()
			if piece[0] is Array:
				for q: Array in piece:
					outline.append(Vector2(float(q[0]), float(q[1])))
			else:
				outline = PackedVector2Array([Vector2(piece[0], piece[1]), Vector2(piece[2], piece[1]),
						Vector2(piece[2], piece[3]), Vector2(piece[0], piece[3])])
			var lo := PackedVector3Array()
			var hi := PackedVector3Array()
			for q in outline:
				var p := Vector3(x0 + q.x * unit, 0.0, cap * 0.5 - q.y * unit)
				lo.append(p + Vector3(0.0, d, 0.0))
				hi.append(p + Vector3(0.0, d + letter_t, 0.0))
			k.loft(lo, hi)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * depth * height
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * hl, -d, sz * hh))
			pts.append(Vector3(sx * hl, d + letter_t, sz * hh))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	var g := MeshKit.new()
	for sx: float in [-1.0, 1.0]:
		g.box(Vector3(0.04, 0.008, 2.0 * lamp_h - 0.024), Vector3(sx * (hl - 0.06), d + 0.018, 0.0))
	shape.glow = g.finish()
	shape.glow_color = Color(0.92, 0.95, 1.0)
	return shape


# --- Drill miner parts (0.59) -------------------------------------------------------------

## A big slatted service panel (the grey grille down the Miner N-M1's starboard flank, over
## its cargo and engine bays): a frame in the material colour `length` along X and `height`
## along Z, `depth` thick, bevelled on both top edges (mitred corners), round a dark recess;
## two columns of slats across the recess, each slat tilted so its top edge stands proud,
## held at their ends by steel carrier rails, split by a centre mullion; a ring of bolts
## round the frame and a small yellow warning tab on it. Face +Y (lay it on a hull side with
## X along the hull and Y out of it).
static func louvre_panel(length: float = 3.0, height: float = 1.6, depth: float = 0.1) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hl := length * 0.5
	var hh := height * 0.5
	var d := depth * 0.5
	var rim := minf(length, height) * 0.08
	var back := depth * 0.3
	# The frame: one mitred ring round the opening, its outer and inner top edges bevelled.
	var c_out := rim * 0.3
	var c_in := minf(rim * 0.2, depth * 0.3)
	_lights_rect_band(k, Vector3.ZERO, hl - rim, hh - rim, PackedVector2Array([Vector2(0.0, -d), Vector2(rim, -d),
			Vector2(rim, d - c_out), Vector2(rim - c_out, d), Vector2(c_in, d), Vector2(0.0, d - c_in)]), true)
	# The centre mullion, standing on the recess floor, its top a hair under the frame's.
	k.box(Vector3(rim * 0.6, depth - back - 0.006, height - rim * 2.0), Vector3(0.0, (back - 0.006) * 0.5, 0.0))
	# The dark recess behind the slats.
	k.color = DARK
	k.box(Vector3(length - rim * 2.0, back, height - rim * 2.0), Vector3(0.0, -d + back * 0.5, 0.0))
	# Slats: in each column, thin bars across, each tilted about X so it reads as a louvre.
	k.color = DETAIL
	var inner_h := height - rim * 2.0
	var n := maxi(int(inner_h / 0.12), 3)
	var pitch := inner_h / float(n)
	var col_w := (length - rim * 2.0 - rim * 0.6) * 0.5 - 0.02
	for sx: float in [-1.0, 1.0]:
		var cx := sx * (rim * 0.3 + 0.01 + col_w * 0.5)
		for i in n:
			var z := -inner_h * 0.5 + pitch * (float(i) + 0.5)
			var a := Vector3(cx - col_w * 0.5, -d + back + 0.005, z + pitch * 0.3)
			var b := Vector3(cx + col_w * 0.5, -d + back + 0.005, z + pitch * 0.3)
			var lo := PackedVector3Array([a, b, b + Vector3(0.0, 0.0, -pitch * 0.15), a + Vector3(0.0, 0.0, -pitch * 0.15)])
			var hi := PackedVector3Array()
			for q in lo:
				hi.append(Vector3(q.x, d - 0.01, q.z - pitch * 0.45))
			k.loft(lo, hi)
		# The carrier rails over the slats' ends, down each side of the column.
		var rw := clampf(rim * 0.35, 0.015, 0.04)
		for ex: float in [-1.0, 1.0]:
			k.box(Vector3(rw, 0.024, inner_h), Vector3(cx + ex * (col_w * 0.5 - rw * 0.5), d - 0.018, 0.0))
	# A ring of bolts on the frame's flat, corners included, and the warning tab.
	k.color = DETAIL
	var bs := clampf(rim * 0.3, 0.018, 0.04)
	var ex_b := hl - rim * 0.5
	var ez_b := hh - rim * 0.5
	var nx := maxi(int(length / 0.45) + 1, 2)
	var nz := maxi(int(height / 0.45) + 1, 2)
	for i in nx:
		var x := lerpf(-ex_b, ex_b, float(i) / float(nx - 1))
		for sz: float in [-1.0, 1.0]:
			if sz < 0.0 and x > -ex_b and x - bs < -hl + rim * 3.2:
				continue                   # keep clear of the warning tab
			k.box(Vector3(bs, 0.012, bs), Vector3(x, d + 0.006, sz * ez_b))
	for i in range(1, nz - 1):
		var z := lerpf(-ez_b, ez_b, float(i) / float(nz - 1))
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(bs, 0.012, bs), Vector3(sx * ex_b, d + 0.006, z))
	k.color = PartShapes.ACCENT
	k.box(Vector3(rim * 2.0, 0.015, rim * 0.5), Vector3(-hl + rim * 2.2, d + 0.0075, -hh + rim * 0.5))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * height * depth * 0.45
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * hl, -d, sz * hh))
			pts.append(Vector3(sx * hl, d + 0.02, sz * hh))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	return shape


# --- Hex-drive cruiser parts (0.60) ------------------------------------------------------

## A big round searchlight (the RX-39487's two headlights low on its nose): a drum `radius`
## round and `length` long along Y in the material colour on a dark mounting flange at -Y
## with a ring of bolts, held at its sides by a steel gimbal yoke (two tapered arms up from
## the flange to dark pivot hubs), two dark bands round the drum, a bright rim with a
## chamfered lip round the mouth, a polished reflector bowl sloping down inside to a domed
## glowing lens (PartShape.glow) and dark slats across the mouth. Light out of +Y.
static func searchlight(radius: float = 0.5, length: float = 0.9) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := length * 0.5
	var seg := 20
	var flange_t := minf(0.06, length * 0.1)
	var rim_t := minf(0.05, length * 0.08)
	var ya := -h + flange_t                # the drum's foot
	var yb := h - rim_t                    # the drum's top, under the rim
	var span := yb - ya
	var yl := yb - minf(span * 0.08, radius * 0.1)   # the lens, at the bottom of the bowl
	var mouth := radius * 0.8
	var lens_r := radius * 0.55
	# The mounting flange and a ring of bolts on it, clear of the yoke's feet.
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(0.0, -h), Vector2(radius * 1.1, -h), Vector2(radius * 1.1, ya),
			Vector2(0.0, ya)]), seg)
	k.color = DETAIL
	var bs := clampf(radius * 0.07, 0.014, 0.035)
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		k.box(Vector3(bs, bs * 0.5, bs), Vector3(cos(a) * radius * 1.035, ya + bs * 0.25, sin(a) * radius * 1.035))
	# The drum up to the lens, then a collar round the bowl up to the rim.
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(0.0, ya + 0.002), Vector2(radius * 0.97, ya + 0.002),
			Vector2(radius * 0.97, yl), Vector2(0.0, yl)]), seg)
	k.lathe(PackedVector2Array([Vector2(mouth, yl), Vector2(radius * 0.97, yl),
			Vector2(radius * 0.97, yb), Vector2(mouth, yb)]), seg)
	# Two dark bands round the drum, a hair proud of it.
	k.color = DARK
	var bh := minf(0.025, span * 0.05)
	for f: float in [0.2, 0.45]:
		var y := ya + span * f
		k.lathe(PackedVector2Array([Vector2(radius * 0.96, y - bh), Vector2(radius * 0.99, y - bh),
				Vector2(radius * 0.99, y + bh), Vector2(radius * 0.96, y + bh)]), seg)
	# The reflector bowl: a polished cone from the lens up to the mouth.
	k.color = REFLECTOR
	k.lathe(PackedVector2Array([Vector2(lens_r, yl), Vector2(mouth + 0.004, yb), Vector2(mouth + 0.004, yl)]), seg)
	# The bright rim round the mouth, its outer lip chamfered.
	k.color = TRIM
	var ch := minf(0.02, rim_t * 0.3)
	k.lathe(PackedVector2Array([Vector2(mouth, yb), Vector2(radius, yb), Vector2(radius, h - ch), Vector2(radius - ch, h),
			Vector2(mouth, h)]), seg)
	# Slats across the mouth, along X, their ends in the rim.
	k.color = DARK
	var n := 4 if radius >= 0.3 else 3
	var sw := minf(0.035, radius * 0.08)
	for i in n:
		var z := lerpf(-mouth * 0.66, mouth * 0.66, float(i) / float(n - 1))
		var half := sqrt(maxf(mouth * mouth - z * z, 0.0)) - 0.003
		k.box(Vector3(half * 2.0, minf(0.03, rim_t * 0.4), sw), Vector3(0.0, yb + rim_t * 0.5, z))
	# The gimbal yoke: a tapered steel arm each side (+-X) from the flange to a dark pivot hub.
	var yp := ya + span * 0.6
	var w := radius * 0.24
	for sx: float in [-1.0, 1.0]:
		k.color = DETAIL
		var x0 := sx * (radius + 0.002)
		var x1 := sx * radius * 1.1
		_prism_x(k, PackedVector2Array([Vector2(-w, ya), Vector2(w, ya), Vector2(w * 0.6, yp + w * 0.5),
				Vector2(-w * 0.6, yp + w * 0.5)]), minf(x0, x1), maxf(x0, x1))
		k.color = DARK
		_tube(k, Vector3(sx * (radius * 1.1 - 0.002), yp, 0.0), Vector3(sx * (radius * 1.1 + 0.014), yp, 0.0), radius * 0.15)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * radius * radius * length * 0.5
	var col := CylinderShape3D.new()
	col.radius = radius * 1.1
	col.height = length
	shape.collision = col
	# The lens: a shallow dome at the bottom of the bowl.
	var g := MeshKit.new()
	var dome := minf(0.03, lens_r * 0.25)
	g.lathe(PackedVector2Array([Vector2(0.0, yl + 0.003), Vector2(lens_r + 0.002, yl + 0.003),
			Vector2(lens_r * 0.7, yl + 0.003 + dome * 0.7), Vector2(0.0, yl + 0.003 + dome)]), seg)
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.97, 0.9)
	return shape


## A long-barrelled roof cannon (the RX-39487's gun over its stern, the Everest's bow gun,
## the Corsair's and the Nexus' roof guns): a bolted turret ring under an angular housing at
## the back (sloped front, cheek armour, a hazard tab on its back), trunnion cheeks with
## hub caps holding a dark octagonal breech drum with steel bands, two recoil buffers over
## the barrel, and a long round barrel toward -Z with two chamfered sleeves and a slotted
## muzzle brake; a small lit lamp on top of the brake (PartShape.glow). `length` is the
## whole part along Z, `radius` the housing's scale (the ring is 0.8 of it).
static func long_cannon(length: float = 5.0, radius: float = 0.55, glow := Color(0.35, 1.0, 0.4)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var r := radius
	var hz := length * 0.5
	var zb := hz - r                      # the turret's centre (z)
	var y0 := -0.4
	var ring_t := 0.18
	var rr := r * 0.8                     # the ring, under the housing, m
	var shelf := y0 + 0.07
	# The turret ring: a steel foot flange with a bolt circle, a dark ring body.
	k.color = DETAIL
	_electrical_lathe_at(k, PackedVector2Array([Vector2(0.0, y0), Vector2(rr, y0), Vector2(rr, shelf),
			Vector2(0.0, shelf)]), 20, Vector3(0.0, 0.0, zb))
	var bolt := clampf(r * 0.05, 0.016, 0.03)
	_piping_bolts(k, Vector3(0.0, shelf, zb), Vector3.UP, 0.0, 12, rr * 0.955, bolt, bolt * 0.5)
	k.color = DARK
	_electrical_lathe_at(k, PackedVector2Array([Vector2(0.0, shelf), Vector2(rr * 0.9, shelf),
			Vector2(rr * 0.9, y0 + ring_t - 0.03), Vector2(rr * 0.84, y0 + ring_t), Vector2(0.0, y0 + ring_t)]), 20,
			Vector3(0.0, 0.0, zb))
	# The housing on the ring: an angular block with a sloped front, cheek armour.
	var hy0 := y0 + ring_t + 0.004
	var hh := 0.42
	var hx := r * 0.65
	var side := PackedVector2Array([Vector2(zb - r * 0.8, hy0), Vector2(zb + r * 0.8, hy0),
			Vector2(zb + r * 0.8, hy0 + hh * 0.8), Vector2(zb + r * 0.62, hy0 + hh), Vector2(zb - r * 0.45, hy0 + hh),
			Vector2(zb - r * 0.8, hy0 + hh * 0.55)])
	k.color = Color.WHITE
	_prism_x(k, side, -hx, hx)
	var cheek := _weapons_inset(side, Vector2(zb, hy0 + hh * 0.5), 0.82)
	for sx: float in [-1.0, 1.0]:
		_prism_x(k, cheek, sx * (hx - 0.01), sx * (hx + 0.012))
	_weapons_hazard(k, Vector3(0.0, hy0 + hh * 0.4, zb + r * 0.8), hx * 1.2, hh * 0.24, 1.0, 3)
	# Trunnion cheeks on the roof, the breech drum between them on hub caps.
	var axis_y := hy0 + hh + 0.12
	var rb := r * 0.17
	var bd := rb * 2.0                     # breech drum radius, m
	var cz := zb - r * 0.1
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		var cx := sx * (bd + 0.03)
		k.box(Vector3(0.04, axis_y + 0.05 - (hy0 + hh - 0.01), r * 0.7), Vector3(cx, (axis_y + 0.05 + hy0 + hh - 0.01) * 0.5, cz))
		_tube(k, Vector3(cx + sx * 0.019, axis_y, cz), Vector3(cx + sx * 0.035, axis_y, cz), minf(0.045, r * 0.12), 10)
	k.color = DARK
	_tube(k, Vector3(0.0, axis_y, zb + r * 0.75), Vector3(0.0, axis_y, zb - r * 0.9), bd, 8)
	k.color = DETAIL
	for f: float in [0.18, 0.82]:
		var z := lerpf(zb + r * 0.75, zb - r * 0.9, f)
		_tube(k, Vector3(0.0, axis_y, z + 0.03), Vector3(0.0, axis_y, z - 0.03), bd * 1.06, 8)
	_tube(k, Vector3(0.0, axis_y, zb + r * 0.75 + 0.005), Vector3(0.0, axis_y, zb + r * 0.78), bd * 0.75, 8)
	# Two recoil buffers along the top of the barrel.
	var buf := rb * 0.4
	var bz1 := zb - r * 0.9 - minf(0.8, length * 0.15)
	for sx: float in [-1.0, 1.0]:
		_tube(k, Vector3(sx * rb * 1.15, axis_y + rb * 1.2, zb - r * 0.8), Vector3(sx * rb * 1.15, axis_y + rb * 1.2, bz1), buf, 6)
	# The barrel: two chamfered sleeves on it, a slotted brake at the muzzle.
	var muzzle := -hz + 0.35
	var metal := Color(0.7, 0.72, 0.74)
	k.color = metal
	_tube(k, Vector3(0.0, axis_y, zb - r * 0.9 + 0.002), Vector3(0.0, axis_y, -hz + 0.05), rb, 12)
	k.color = DETAIL
	for f: float in [0.3, 0.62]:
		var z := lerpf(zb - r * 0.9, muzzle, f)
		_piping_spin(k, Vector3(0.0, axis_y, z + 0.12), Vector3.FORWARD, PackedVector2Array([Vector2(rb, 0.0),
				Vector2(rb * 1.35, 0.04), Vector2(rb * 1.35, 0.2), Vector2(rb, 0.24)]), [DETAIL] as Array[Color], 12)
	_weapons_brake(k, Vector3(0.0, axis_y, -hz), rb * 1.6, 0.35, rb * 0.6, 3, 12)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * rr * rr * ring_t * 0.9 + hx * 2.0 * r * 1.6 * hh * 0.85 + PI * bd * bd * r * 1.65 \
			+ PI * rb * rb * (length - r * 1.8)
	var pts := PackedVector3Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector3(cos(a) * rr, y0, zb + sin(a) * rr))
		pts.append(Vector3(cos(a) * rr * 0.9, hy0, zb + sin(a) * rr * 0.9))
	for p in side:
		pts.append(Vector3(-hx - 0.012, p.y, p.x))
		pts.append(Vector3(hx + 0.012, p.y, p.x))
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * bd, axis_y + sy * bd, zb + r * 0.75))
			pts.append(Vector3(sx * bd, axis_y + sy * bd, zb - r * 0.9))
			pts.append(Vector3(sx * rb * 1.6, axis_y + sy * rb * 1.6, -hz))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	# The lamp on top of the brake's middle baffle.
	g.box(Vector3(0.07, 0.03, 0.06), Vector3(0.0, axis_y + rb * 1.6 + 0.012, -hz + 0.175))
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## Digits and a dash for `name_board` (registration numbers like the RX-39487's), on the
## same 4 by 6 grid as `_GLYPHS`; pieces never overlap, so their faces don't fight.
const _DIGITS := {
	"0": [[0, 0, 1, 6], [3, 0, 4, 6], [1, 0, 3, 1], [1, 5, 3, 6]],
	"1": [[1.5, 0, 2.5, 6], [0.5, 4.5, 1.5, 5.5]],
	"2": [[0, 5, 4, 6], [3, 3.5, 4, 5], [0, 2.5, 4, 3.5], [0, 1, 1, 2.5], [0, 0, 4, 1]],
	"3": [[0, 5, 3, 6], [3, 0, 4, 6], [0, 0, 3, 1], [1, 2.5, 3, 3.5]],
	"4": [[0, 2.5, 1, 6], [1, 2.5, 3, 3.5], [3, 0, 4, 6]],
	"5": [[0, 5, 4, 6], [0, 3.5, 1, 5], [0, 2.5, 4, 3.5], [3, 1, 4, 2.5], [0, 0, 4, 1]],
	"6": [[0, 0, 1, 6], [1, 5, 4, 6], [1, 2.5, 4, 3.5], [3, 1, 4, 2.5], [1, 0, 4, 1]],
	"7": [[0, 5, 4, 6], [[2.9, 5], [4, 5], [2, 0], [0.9, 0]]],
	"8": [[0, 0, 1, 6], [3, 0, 4, 6], [1, 0, 3, 1], [1, 5, 3, 6], [1, 2.5, 3, 3.5]],
	"9": [[0, 2.5, 1, 6], [1, 5, 3, 6], [3, 0, 4, 6], [1, 2.5, 3, 3.5], [0, 0, 3, 1]],
	"-": [[0.5, 2.5, 3.5, 3.5]],
}


# --- Mule hauler parts (v2 rebuild) -------------------------------------------------------

## A big hydrogen tank lying behind a hauler's body (the Mule's two khaki tanks): a round
## body `radius` across and `length` long along Y in the material colour, weld beads where
## it meets rounded shoulders, a dark flat end flange at each end (the faces a mount plate
## and an engine bolt to, kept flat) with bolt heads round its rim, a broad dark clamp collar
## near the -Y end with a tensioner on +Z and bolts on its diagonals, a thin dark band near
## +Y, a weld seam down the lower flank, a maker's plate on -X, and two dark straps along
## the -Z side with end clamps and a bolted valve boss between them (the top once it is
## turned with `Basis(Vector3.RIGHT, PI / 2)` to lie along +Z). Fit it with the hull's paint.
static func banded_tank(radius: float = 1.2, length: float = 5.0) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := length * 0.5
	var flange_t := 0.08
	var flange_r := radius * 0.62
	var shoulder := radius * 0.42
	var y0 := -h + flange_t
	var y1 := h - flange_t
	var prof := PackedVector2Array()
	prof.append(Vector2(0.0, y0))
	prof.append(Vector2(flange_r * 0.98, y0))
	for i in range(1, 4):
		var a := PI * 0.5 * float(i) / 3.0
		prof.append(Vector2(lerpf(flange_r * 0.98, radius, sin(a)), y0 + shoulder * (1.0 - cos(a))))
	for i in range(0, 3):
		var a := PI * 0.5 * float(3 - i) / 3.0
		prof.append(Vector2(lerpf(flange_r * 0.98, radius, sin(a)), y1 - shoulder * (1.0 - cos(a))))
	prof.append(Vector2(flange_r * 0.98, y1))
	prof.append(Vector2(0.0, y1))
	k.color = Color.WHITE
	k.lathe(prof, 24)
	k.color = DARK
	for y: float in [-h, y1]:
		k.lathe(PackedVector2Array([Vector2(0.0, y), Vector2(flange_r, y), Vector2(flange_r, y + flange_t),
				Vector2(0.0, y + flange_t)]), 24)
	# Bolt heads round each flange's rim (radial, so the mount faces stay flat).
	var fb := clampf(radius * 0.035, 0.02, 0.04)
	k.color = DETAIL
	for y: float in [-h + flange_t * 0.5, h - flange_t * 0.5]:
		for i in 10:
			var a := TAU * (float(i) + 0.5) / 10.0
			var n := Vector3(cos(a), 0.0, sin(a))
			_vessels_box(k, n * (flange_r + 0.006) + Vector3.UP * y, Vector3(fb, fb, 0.014),
					Basis(n.cross(Vector3.UP), Vector3.UP, n))
	# Weld beads where the shoulders meet the barrel, a hair proud.
	var body0 := y0 + shoulder
	var body1 := y1 - shoulder
	var wb := clampf(radius * 0.012, 0.006, 0.014)
	var wr := radius + minf(radius * 0.02, 0.008)
	k.color = DETAIL
	for y: float in [body0, body1]:
		k.lathe(PackedVector2Array([Vector2(radius * 0.99, y - wb), Vector2(wr, y - wb), Vector2(wr, y + wb),
				Vector2(radius * 0.99, y + wb)]), 24)
	# The broad collar near the front and a thin band near the back, a hair proud.
	var cr := radius * 1.03
	k.color = DARK
	var collar := Vector2(lerpf(body0, body1, 0.06), lerpf(body0, body1, 0.24))
	for band: Vector2 in [collar, Vector2(lerpf(body0, body1, 0.86), lerpf(body0, body1, 0.9))]:
		k.lathe(PackedVector2Array([Vector2(radius * 0.99, band.x), Vector2(cr, band.x),
				Vector2(cr, band.y), Vector2(radius * 0.99, band.y)]), 24)
	# The collar's tensioner on +Z (two lugs and a bolt) and bolt heads on its diagonals
	# (clear of brackets on +-X and of the top on -Z).
	var cm := (collar.x + collar.y) * 0.5
	var lug := clampf(radius * 0.06, 0.03, 0.07)
	var lug_out := minf(0.015, radius * 0.04)
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(lug * 0.5, (collar.y - collar.x) * 0.7, lug_out + 0.02),
				Vector3(sx * lug * 0.55, cm, cr + lug_out * 0.5 - 0.01))
	k.box(Vector3(lug * 2.0, lug * 0.4, lug * 0.4), Vector3(0.0, cm, cr + lug_out - lug * 0.2))
	for a: float in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var n := Vector3(cos(a), 0.0, sin(a))
		for dy: float in [-0.3, 0.3]:
			_vessels_box(k, n * (cr + 0.005) + Vector3.UP * (cm + dy * (collar.y - collar.x)),
					Vector3(fb, fb, 0.014), Basis(n.cross(Vector3.UP), Vector3.UP, n))
	# A weld seam down the barrel on the lower flank (+Z, toward +X), under the bands.
	var seam_n := Vector3(0.5, 0.0, 0.866)
	var sw := clampf(radius * 0.02, 0.008, 0.02)
	_vessels_box(k, seam_n * (radius - sw * 0.2), Vector3(sw, body1 - body0 - wb * 4.0, sw),
			Basis(seam_n.cross(Vector3.UP), Vector3.UP, seam_n))
	# The maker's plate on -X, between the collar and the band, with dark lettering.
	var pw := minf(radius * 0.5, 0.45)
	var ph := minf((body1 - body0) * 0.12, 0.32)
	var py := lerpf(body0, body1, 0.45)
	var x_back := sqrt(radius * radius - pw * pw * 0.25) * cos(PI / 24.0) - 0.004
	var x_face := radius + 0.006
	k.color = PLATE
	k.box(Vector3(x_face - x_back, ph, pw), Vector3(-(x_face + x_back) * 0.5, py, 0.0))
	k.color = DARK
	for j in 2:
		k.box(Vector3(0.004, ph * 0.14, pw * (0.7 - 0.25 * float(j))),
				Vector3(-x_face - 0.002, py + ph * (0.18 - 0.36 * float(j)), pw * 0.12 * float(j)))
	# Two straps along the crown on the -Z side (up once the tank is turned with
	# Basis(Vector3.RIGHT, PI / 2) to lie along +Z, collar forward), clamps at their ends,
	# a bolted valve boss between them.
	k.color = DARK
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.1, body1 - body0 - 0.2, 0.04), Vector3(sx * radius * 0.3, (body0 + body1) * 0.5, -radius * 0.97))
		k.color = DETAIL
		for sy: float in [-1.0, 1.0]:
			k.box(Vector3(0.13, 0.07, 0.03), Vector3(sx * radius * 0.3, (body0 + body1) * 0.5 + sy * ((body1 - body0) * 0.5 - 0.13),
					-radius * 0.97 - 0.02))
		k.color = DARK
	var vy := lerpf(body0, body1, 0.55)
	var vc := Vector3(0.0, vy, -radius + 0.04)
	_piping_spin(k, vc, Vector3.FORWARD, PackedVector2Array([Vector2(0.13, 0.0), Vector2(0.13, 0.07),
			Vector2(0.085, 0.07), Vector2(0.085, 0.12), Vector2(0.0, 0.12)]),
			[DETAIL, DETAIL, DARK, DARK] as Array[Color], 12)
	k.color = DETAIL
	_piping_bolts(k, vc, Vector3.FORWARD, 0.07, 6, 0.108, 0.022, 0.012)
	var pts := PackedVector3Array()
	for i in 16:
		var t := TAU * float(i) / 16.0
		var c := Vector2(cos(t), sin(t))
		for p: Vector2 in [Vector2(flange_r, -h), Vector2(cr, body0), Vector2(cr, body1), Vector2(flange_r, h)]:
			pts.append(Vector3(c.x * p.x, p.y, c.y * p.x))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * radius * radius * length * 0.9
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	return shape


## A sensor probe on a ship's nose (the Mule's long rod out of its cab, the warships' and
## the Endeavor's probes): a chamfered cast iron mount at -Y with four bolts, a round housing
## in the material colour with a dark band, four small anodised strakes and a shoulder up to
## a bright collar, a thin carbon fibre rod out to +Y with two anodised collars, a flared
## titanium sensor sleeve and a small red lit tip (PartShape.glow). `length` is the whole part along Y.
static func nose_probe(length: float = 1.6, radius: float = 0.14) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := length * 0.5
	var base_t := 0.05
	var house := minf(0.35, length * 0.25)
	var yb := -h + base_t
	# A chamfered dark mount with a bolt in each corner.
	k.color = CAST
	k.loft(_chamfer_ring(radius * 1.5, -h, radius * 0.4), _chamfer_ring(radius * 1.5, yb, radius * 0.4))
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_thrusters_bolt(k, Vector3(sx * radius * 1.12, yb, sz * radius * 1.12), maxf(0.008, radius * 0.13), 0.01)
	# The housing: a drum with a shoulder narrowing to the rod, four small strakes down it.
	var ys := yb + house * 0.6
	var yt := yb + house
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(0.0, yb + 0.002), Vector2(radius, yb + 0.002), Vector2(radius, ys),
			Vector2(radius * 0.5, yt), Vector2(0.0, yt)]), 14)
	k.color = DARK
	var by := yb + house * 0.3
	k.lathe(PackedVector2Array([Vector2(radius * 0.96, by - 0.022), Vector2(radius * 1.03, by - 0.022),
			Vector2(radius * 1.03, by + 0.022), Vector2(radius * 0.96, by + 0.022)]), 14)
	k.color = ANODISED
	var fin_lo := by + 0.03
	for i in 4:
		var a := PI * 0.25 + PI * 0.5 * float(i)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var fa := dir * radius * 0.95 + Vector3(0.0, fin_lo, 0.0)
		var fb := dir * radius * 0.95 + Vector3(0.0, ys - 0.005, 0.0)
		var fo := dir * radius * 0.35
		k.poly(PackedVector3Array([fa, fb, fb + fo * 0.4 + Vector3(0.0, -0.01, 0.0), fa + fo]), dir.cross(Vector3.UP))
		k.poly(PackedVector3Array([fa, fb, fb + fo * 0.4 + Vector3(0.0, -0.01, 0.0), fa + fo]), -dir.cross(Vector3.UP))
	var rod := radius * 0.18
	var r0 := yt
	var tip := h - 0.06
	# A bright collar where the rod leaves the housing.
	k.color = TRIM
	k.lathe(PackedVector2Array([Vector2(rod * 0.9, yt - 0.01), Vector2(rod * 2.6, yt - 0.01), Vector2(rod * 2.2, yt + 0.03),
			Vector2(rod * 0.9, yt + 0.03)]), 10)
	k.color = CARBON
	k.lathe(PackedVector2Array([Vector2(0.0, r0), Vector2(rod, r0), Vector2(rod, tip), Vector2(0.0, tip)]), 10)
	k.color = ANODISED
	for f: float in [0.35, 0.7]:
		var y := lerpf(r0, tip, f)
		k.lathe(PackedVector2Array([Vector2(rod * 0.95, y - 0.03), Vector2(rod * 1.8, y - 0.03),
				Vector2(rod * 1.8, y + 0.03), Vector2(rod * 0.95, y + 0.03)]), 10)
	# The sensor head: a flared titanium sleeve under the lit tip.
	k.color = WPN_TIP
	k.lathe(PackedVector2Array([Vector2(rod * 0.95, tip - 0.1), Vector2(rod * 1.15, tip - 0.1), Vector2(rod * 1.6, tip - 0.03),
			Vector2(rod * 1.6, tip), Vector2(rod * 0.95, tip)]), 10)
	var pts := PackedVector3Array()
	for i in 8:
		var t := TAU * float(i) / 8.0
		pts.append(Vector3(cos(t) * radius * 1.5, -h, sin(t) * radius * 1.5))
		pts.append(Vector3(cos(t) * rod * 1.8, h, sin(t) * rod * 1.8))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * radius * radius * house + PI * rod * rod * length
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	var g := MeshKit.new()
	g.lathe(PackedVector2Array([Vector2(0.0, tip - 0.002), Vector2(rod * 1.4, tip - 0.002), Vector2(rod * 1.4, h - 0.025),
			Vector2(rod * 0.8, h), Vector2(0.0, h)]), 10)
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.25, 0.2)
	return shape


# --- Titan miner parts (v2 rebuild) ------------------------------------------------------

## A rock-cutting wheel on its fork (the Titan's three bow drills): a broad steel drum
## `width` across ringed with three staggered rows of picks (steel holders, shanks, bright
## carbide points) out to `radius`, dark side discs with a bolt circle and hub caps; behind
## it a dark fork: two cheeks with cut front corners out to the axle, a bolted hydraulic
## motor boss on each with two hoses back along the cheek, an amber work lamp on each
## cheek's top facing the bit (PartShape.glow), a cross bar with a hazard-striped top and a
## dark coolant spray bar along its front edge, and a square mount plate bolted above and
## below it. The axle runs along X, the bit faces -Z and the mount plate is the +Z face, so
## fit it unturned on the front of an arm. Collision is the hull of the wheel and the fork.
static func rock_wheel(radius: float = 0.95, width: float = 1.1) -> PartShapes.PartShape:
	const DRUM_STEEL := Color(0.52, 0.53, 0.55)    # the wheel's drum
	const PICK_LIGHT := Color(0.68, 0.69, 0.71)    # light pick shanks
	const PICK_DARK := Color(0.38, 0.39, 0.41)     # dark pick shanks
	var hw := width * 0.5
	var core := radius * 0.72
	var cheek_in := hw + 0.04
	var cheek_t := 0.1
	var reach := radius + 0.22         # axle to the cross bar's back
	var plate_t := 0.12
	var z_front := -radius
	var z_back := reach + plate_t
	var oz := -(z_front + z_back) * 0.5   # centres the part along Z
	var bolt_r := clampf(radius * 0.025, 0.015, 0.03)
	# The wheel, built round Y and turned so its axle runs along X.
	var w := MeshKit.new()
	w.color = DRUM_STEEL
	w.lathe(PackedVector2Array([Vector2(0.0, -hw + 0.06), Vector2(core, -hw + 0.06), Vector2(core, hw - 0.06),
			Vector2(0.0, hw - 0.06)]), 20)
	for s: float in [-1.0, 1.0]:
		var a := s * (hw - 0.06)
		var b2 := s * hw
		w.color = DARK
		w.lathe(PackedVector2Array([Vector2(0.0, minf(a, b2)), Vector2(radius * 0.8, minf(a, b2)),
				Vector2(radius * 0.8, maxf(a, b2)), Vector2(0.0, maxf(a, b2))]), 20)
		w.color = DETAIL
		for i in 10:
			var t := TAU * (float(i) + 0.5) / 10.0
			_gear_bolt(w, Vector3(cos(t) * radius * 0.6, b2, sin(t) * radius * 0.6), Vector3(0.0, s, 0.0), bolt_r, bolt_r)
	w.color = HUB
	for s: float in [-1.0, 1.0]:
		var a := s * hw
		var b2 := s * (hw + 0.035)
		w.lathe(PackedVector2Array([Vector2(0.0, minf(a, b2)), Vector2(radius * 0.28, minf(a, b2)),
				Vector2(radius * 0.22, maxf(a, b2)) if s > 0.0 else Vector2(radius * 0.28, maxf(a, b2)),
				Vector2(0.0, maxf(a, b2))]), 12)
	var rows := 3
	var per_row := 14
	for r in rows:
		var y := lerpf(-hw + 0.2, hw - 0.2, (float(r) + 0.5) / float(rows))
		for i in per_row:
			var a := TAU * (float(i) + 0.5 * float(r % 2)) / float(per_row)
			var out := Vector3(cos(a), 0.0, sin(a))
			var side := Vector3(-out.z, 0.0, out.x)
			_drills_pick(w, out * core * 0.98 + Vector3(0.0, y, 0.0), out * radius * 0.92 + side * radius * 0.12 + Vector3(0.0, y, 0.0),
					radius * 0.2, PICK_LIGHT if i % 2 == 0 else PICK_DARK)
	var k := MeshKit.new()
	var g := MeshKit.new()
	var turn := Basis(Vector3.BACK, -PI * 0.5)    # Y -> X
	for i in w.verts.size():
		k.verts.append(turn * w.verts[i] + Vector3(0.0, 0.0, oz))
		k.normals.append(turn * w.normals[i])
		k.colors.append(w.colors[i])
	# The fork: a cheek each side out to the axle (front corners cut), a motor boss, hoses
	# and a lamp on each; a cross bar, a spray bar, the mount plate.
	var ch := radius * 0.9
	var cz0 := -0.12
	var cz1 := reach
	var cut := ch * 0.28
	var cheek := PackedVector2Array([Vector2(cz0, -ch * 0.5 + cut), Vector2(cz0 + cut, -ch * 0.5), Vector2(cz1, -ch * 0.5),
			Vector2(cz1, ch * 0.5), Vector2(cz0 + cut, ch * 0.5), Vector2(cz0, ch * 0.5 - cut)])
	for i in cheek.size():
		cheek[i].x += oz
	var hose_r := clampf(radius * 0.025, 0.018, 0.03)
	var ls := clampf(radius * 0.09, 0.06, 0.1)
	for s: float in [-1.0, 1.0]:
		var x0 := s * cheek_in
		var x1 := s * (cheek_in + cheek_t)
		k.color = DARK
		_prism_x(k, cheek, minf(x0, x1), maxf(x0, x1))
		var xo := s * (cheek_in + cheek_t)
		k.color = BOSS
		_piping_spin(k, Vector3(xo - s * 0.002, 0.0, oz), Vector3(s, 0.0, 0.0), PackedVector2Array([Vector2(0.0, 0.0),
				Vector2(radius * 0.2, 0.0), Vector2(radius * 0.2, 0.035), Vector2(radius * 0.13, 0.05), Vector2(0.0, 0.05)]),
				[BOSS] as Array[Color], 8)
		k.color = DETAIL
		for i in 6:
			var t := TAU * (float(i) + 0.5) / 6.0
			_gear_bolt(k, Vector3(xo + s * 0.033, sin(t) * radius * 0.165, cos(t) * radius * 0.165 + oz), Vector3(s, 0.0, 0.0),
					bolt_r * 0.8, bolt_r * 0.6)
		var hx := xo + s * (hose_r + 0.004)
		for hy: float in [-1.0, 1.0]:
			var yb := hy * radius * 0.1
			_drills_hose(k, PackedVector3Array([Vector3(hx, yb, radius * 0.24 + oz), Vector3(hx, yb + hy * radius * 0.14, radius * 0.45 + oz),
					Vector3(hx, yb + hy * radius * 0.14, cz1 - 0.06 + oz)]), hose_r)
		_drills_lamp(k, g, Vector3(s * (cheek_in + cheek_t * 0.5), ch * 0.5 + ls * 0.42, cz1 - ls * 1.2 + oz), Vector3.FORWARD,
				Vector3.RIGHT, ls)
	var bar_z0 := radius + 0.05
	var bar_h := ch * 0.7
	k.color = DARK
	k.box(Vector3(cheek_in * 2.0, bar_h, reach - bar_z0), Vector3(0.0, 0.0, (bar_z0 + reach) * 0.5 + oz))
	_gear_hazard(k, Vector3(0.0, bar_h * 0.5, (bar_z0 + reach) * 0.5 + oz), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			Vector2(cheek_in * 2.0 - 0.06, (reach - bar_z0) * 0.8), (reach - bar_z0) * 0.4)
	var sy := bar_h * 0.5 + 0.035
	var sz := bar_z0 + 0.035 + oz
	k.color = DARK
	_tube(k, Vector3(-cheek_in + 0.01, sy, sz), Vector3(cheek_in - 0.01, sy, sz), 0.03, 8)
	k.color = DETAIL
	for i in 5:
		var x := lerpf(-cheek_in * 0.75, cheek_in * 0.75, float(i) / 4.0)
		k.strut(Vector3(x, sy - 0.01, sz - 0.02), Vector3(x, sy - 0.03, sz - 0.08), 0.03)
	var plate_w := (cheek_in + cheek_t) * 2.0
	k.color = PLATE_DARK
	k.box(Vector3(plate_w, radius * 1.3, plate_t), Vector3(0.0, 0.0, reach + plate_t * 0.5 + oz))
	k.color = DETAIL
	for py: float in [-1.0, 1.0]:
		for i in 4:
			var x := lerpf(-plate_w * 0.38, plate_w * 0.38, float(i) / 3.0)
			_gear_bolt(k, Vector3(x, py * radius * 0.52, reach + oz), Vector3.FORWARD, bolt_r * 1.3, bolt_r)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * core * core * width + PI * radius * radius * width * 0.15 + plate_w * radius * 1.3 * plate_t \
			+ 2.0 * cheek_t * ch * reach + cheek_in * 2.0 * ch * 0.7 * (reach - bar_z0)
	var pts := PackedVector3Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		for s: float in [-1.0, 1.0]:
			pts.append(Vector3(s * hw, sin(a) * radius, cos(a) * radius + oz))
	var xo2 := cheek_in + cheek_t + 0.05
	for sx: float in [-1.0, 1.0]:
		for sy2: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * plate_w * 0.5, sy2 * radius * 0.65, z_back + oz))
			pts.append(Vector3(sx * xo2, sy2 * ch * 0.5, -0.12 + oz))
			pts.append(Vector3(sx * xo2, sy2 * ch * 0.5, reach + oz))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = GLOWING
	return shape


## A drill arm (the boxy orange arms the Titan's drills reach out on): a chamfered bar
## `width` across, `length` along Z, in the material colour; a dark band near each end with
## bolts down its sides, hazard stripes on the sides ahead of the front band, a dark panel
## down each side with three pale chevrons, a bolted skid plate under the front, a dark
## mount pad and two hydraulic rams along the top (dark barrels with steel collars, bright
## rods, clevis blocks, a hose from each barrel's ends into the arm), a dark front plate
## with a work lamp at each top corner (PartShape.glow). `height` is the whole part, the
## pad's top on +Y; front at -Z. Collision is its box.
static func drill_arm(length: float = 4.2, width: float = 1.3, height: float = 0.9) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hx := width * 0.5
	var hl := length * 0.5
	var top := height * 0.5
	var body_top := top - 0.12
	var bottom := -top
	var by := (body_top + bottom) * 0.5
	var bh := (body_top - bottom) * 0.5
	var c := minf(0.12, bh * 0.3)
	var outline := PackedVector2Array([Vector2(hx - c, by + bh), Vector2(hx, by + bh - c), Vector2(hx, by - bh + c),
			Vector2(hx - c, by - bh), Vector2(-hx + c, by - bh), Vector2(-hx, by - bh + c), Vector2(-hx, by + bh - c),
			Vector2(-hx + c, by + bh)])
	k.color = Color.WHITE
	k.extrude(outline, length)
	# Dark bands round the body near each end, a hair proud, bolted down the sides.
	var bands: Array[float] = [-hl + 0.35, hl - 0.4]
	for z: float in bands:
		k.color = DARK
		k.box(Vector3(width + 0.012, bh * 2.0 - c * 2.0, 0.16), Vector3(0.0, by, z))
		k.box(Vector3(width - c * 2.0, bh * 2.0 + 0.012, 0.16), Vector3(0.0, by, z))
		k.color = DETAIL
		for s: float in [-1.0, 1.0]:
			for i in 3:
				var y := lerpf(by - bh + c, by + bh - c, (float(i) + 0.5) / 3.0)
				_gear_bolt(k, Vector3(s * (hx + 0.006), y, z), Vector3(s, 0.0, 0.0), 0.022, 0.012)
	# Hazard stripes on each side between the front end and the front band.
	var hz0 := -hl + 0.03
	var hz1 := bands[0] - 0.09
	for s: float in [-1.0, 1.0]:
		_gear_hazard(k, Vector3(s * hx, by, (hz0 + hz1) * 0.5), Vector3.BACK, Vector3.UP, Vector3(s, 0.0, 0.0),
				Vector2(hz1 - hz0, (bh - c) * 1.6), 0.07)
	# Side panels with chevrons.
	var panel_l := length * 0.5
	var pz := 0.05
	for s: float in [-1.0, 1.0]:
		k.color = DARK
		k.box(Vector3(0.012, bh * 1.0, panel_l), Vector3(s * (hx + 0.006), by, pz))
		k.color = CHEVRON
		for i in 3:
			var z0 := pz - panel_l * 0.36 + float(i) * panel_l * 0.28
			var x := s * (hx + 0.02)
			k.strut(Vector3(x, by + bh * 0.3, z0), Vector3(x, by - bh * 0.25, z0 + 0.14), 0.035)
			k.strut(Vector3(x, by - bh * 0.25, z0 + 0.14), Vector3(x, by + bh * 0.3, z0 + 0.28), 0.035)
	# A bolted skid plate under the front, between the band and the end.
	var skid_l := minf(length * 0.3, 1.2)
	var skid_w := width - 2.0 * c - 0.1
	var skid_z := -hl + 0.06 + skid_l * 0.5
	k.color = DETAIL
	k.box(Vector3(skid_w, 0.012, skid_l), Vector3(0.0, bottom - 0.006, skid_z))
	k.color = DARK
	for sx: float in [-1.0, 1.0]:
		for i in 3:
			var z := lerpf(skid_z - skid_l * 0.42, skid_z + skid_l * 0.42, float(i) / 2.0)
			_gear_bolt(k, Vector3(sx * (skid_w * 0.5 - 0.05), bottom - 0.012, z), Vector3.DOWN, 0.02, 0.006)
	# The mount pad and the two hydraulic rams along the top.
	k.color = DARK
	var pad_w := minf(width * 0.56, width - 0.36)
	k.box(Vector3(pad_w, top - body_top, length * 0.42), Vector3(0.0, (top + body_top) * 0.5, hl - length * 0.21 - 0.15))
	var rod_x := pad_w * 0.5 + 0.1
	var ry := body_top + 0.05
	var z_front := -hl + 0.2
	var z_back := hl - 0.3
	var z_split := lerpf(z_back, z_front, 0.55)
	for s: float in [-1.0, 1.0]:
		var x := s * rod_x
		k.color = TRIM
		_tube(k, Vector3(x, ry, z_front), Vector3(x, ry, z_split + 0.1), 0.03, 8)
		k.color = DARK
		_tube(k, Vector3(x, ry, z_split), Vector3(x, ry, z_back), 0.058, 10)
		k.color = DETAIL
		for z: float in [z_split, z_back - 0.12]:
			_tube(k, Vector3(x, ry, z - 0.04), Vector3(x, ry, z + 0.04), 0.066, 10)
		k.color = DARK
		for z: float in [z_front, z_back + 0.06]:
			k.box(Vector3(0.14, 0.1, 0.12), Vector3(x, ry, z))
		var hx2 := x + s * 0.07
		_drills_hose(k, PackedVector3Array([Vector3(x + s * 0.05, ry, z_split + 0.1), Vector3(hx2, ry - 0.01, z_split + 0.2),
				Vector3(hx2, body_top + 0.02, z_split + 0.4)]), 0.02)
		_drills_hose(k, PackedVector3Array([Vector3(x + s * 0.05, ry, z_back - 0.2), Vector3(hx2, ry - 0.01, z_back - 0.3),
				Vector3(hx2, body_top + 0.02, z_back - 0.5)]), 0.02)
	# The front plate.
	k.color = DARK
	k.box(Vector3(width - 2.0 * c, bh * 2.0 - 2.0 * c, 0.008), Vector3(0.0, by, -hl - 0.004))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * bh * 2.0 * length
	var col := BoxShape3D.new()
	col.size = Vector3(width + 0.04, height, length + 0.01)
	shape.collision = col
	var g := MeshKit.new()
	for s: float in [-1.0, 1.0]:
		g.box(Vector3(0.16, 0.09, 0.012), Vector3(s * (hx - c - 0.12), by + bh - c - 0.08, -hl - 0.012))
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.96, 0.88)
	return shape


## A big ore detector (the round toothed drum on the Titan's roof, the Novaris' smaller one):
## an octagonal plinth in the material colour with a rubber skirt and bolts on its faces, a
## galvanised drum `radius` across with a ring of upright anodised ribs (pale and dark in
## turn) round its side under a bright top rim and galvanised spokes across its top, and a
## cast iron raised hub with a bolt ring round a ceramic sensor window and a yellow lit ring
## (PartShape.glow). Stands on -Y; `height` the whole part.
static func ore_detector(radius: float = 1.3, height: float = 0.9) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := height * 0.5
	var plinth_t := height * 0.28
	var plinth_r := radius * 1.04
	k.color = Color.WHITE
	k.lathe(PackedVector2Array([Vector2(0.0, -h), Vector2(plinth_r, -h), Vector2(plinth_r * 0.97, -h + plinth_t),
			Vector2(0.0, -h + plinth_t)]), 8)
	# A dark skirt band round the plinth's foot and two bolts on each of its faces (the
	# eight-sided lathe puts a corner at 0 degrees, so faces centre on 22.5 + 45 n).
	k.color = RUBBER
	var skirt := minf(0.05, plinth_t * 0.22)
	k.lathe(PackedVector2Array([Vector2(plinth_r * 0.95, -h), Vector2(plinth_r + 0.006, -h),
			Vector2(plinth_r + 0.006, -h + skirt), Vector2(plinth_r * 0.95, -h + skirt)]), 8)
	k.color = DETAIL
	var face_r := plinth_r * 0.985 * cos(PI / 8.0)
	var pbolt := clampf(radius * 0.025, 0.012, 0.03)
	for i in 8:
		var a := PI / 8.0 + TAU * float(i) / 8.0
		var out := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-out.z, 0.0, out.x)
		for s: float in [-1.0, 1.0]:
			_gear_bolt(k, out * face_r + side * s * plinth_r * 0.2 + Vector3(0.0, -h + skirt + (plinth_t - skirt) * 0.5, 0.0),
					out, pbolt, 0.012)
	var d0 := -h + plinth_t
	var d1 := h - height * 0.16
	var dr := radius * 0.86
	k.color = GALVANISED
	k.lathe(PackedVector2Array([Vector2(0.0, d0), Vector2(dr, d0), Vector2(dr, d1), Vector2(0.0, d1)]), 32)
	var ribs := 20
	for i in ribs:
		var a := TAU * float(i) / float(ribs)
		var out := Vector3(cos(a), 0.0, sin(a))
		k.color = WPN_RIB_PALE if i % 2 == 0 else WPN_RIB_DARK
		var rr := dr + (radius - dr) * 0.5
		k.strut(out * rr + Vector3(0.0, d0 + 0.03, 0.0), out * rr + Vector3(0.0, d1 - 0.01, 0.0), radius - dr)
		k.color = GALVANISED
		k.strut(out * radius * 0.34 + Vector3(0.0, d1 + 0.025, 0.0), out * dr * 0.94 + Vector3(0.0, d1 + 0.025, 0.0), 0.05)
	# A bright rim round the drum's top edge, over the ribs' heads.
	k.color = TRIM
	k.lathe(PackedVector2Array([Vector2(dr * 0.95, d1 - 0.004), Vector2(radius, d1 - 0.004), Vector2(radius, d1 + 0.02),
			Vector2(radius * 0.97, d1 + 0.035), Vector2(dr * 0.95, d1 + 0.035)]), 20)
	k.color = CAST
	k.lathe(PackedVector2Array([Vector2(0.0, d1), Vector2(radius * 0.32, d1), Vector2(radius * 0.26, h),
			Vector2(0.0, h)]), 16)
	# A bolt ring on the hub's crown round a steel sensor boss.
	k.color = DETAIL
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		_thrusters_bolt(k, Vector3(cos(a) * radius * 0.2, h, sin(a) * radius * 0.2), clampf(radius * 0.018, 0.01, 0.025), 0.01)
	k.color = WPN_RADOME
	k.lathe(PackedVector2Array([Vector2(0.0, h - 0.002), Vector2(radius * 0.11, h - 0.002), Vector2(radius * 0.09, h + 0.016),
			Vector2(0.0, h + 0.016)]), 12)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * plinth_r * plinth_r * plinth_t + PI * dr * dr * (d1 - d0)
	var pts := PackedVector3Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		var c := Vector2(cos(a), sin(a))
		pts.append(Vector3(c.x * plinth_r * 1.01, -h, c.y * plinth_r * 1.01))
		pts.append(Vector3(c.x * plinth_r * 1.01, d0, c.y * plinth_r * 1.01))
		pts.append(Vector3(c.x * radius * 1.01, d1 + 0.05, c.y * radius * 1.01))
		pts.append(Vector3(c.x * radius * 0.32, h, c.y * radius * 0.32))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	var g := MeshKit.new()
	g.lathe(PackedVector2Array([Vector2(radius * 0.33, d1 + 0.01), Vector2(radius * 0.4, d1 + 0.01),
			Vector2(radius * 0.4, d1 + 0.04), Vector2(radius * 0.33, d1 + 0.04)]), 16)
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.8, 0.25)
	return shape


# --- Bay freighter parts (v2 rebuild) ----------------------------------------------------

## An SE2 landing gear on a piston (the Manta freighter's legs): a chamfered mount plate in
## the material colour at the top (+Y) with bolt heads under its corners, a trunnion block,
## a dark square cylinder with two clamp bands, a valve block and a hydraulic hose, a gland
## and dark wiper seal round a chrome rod, the rod's eye pinned between two clevis cheeks on
## a hinge block, and a sled foot `foot` long along Z (raked ends) with a rubber sole,
## hazard stripes on its top at both ends and a red lit band round its sides
## (PartShape.glow). Stands on -Y, `height` from the foot's sole to the plate's top.
static func piston_gear(height: float = 2.4, foot: float = 1.6) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hh := height * 0.5
	var fw := foot * 0.62          # foot width (x), m
	var ft := 0.32                 # foot thickness, m
	var plate_t := 0.08            # mount plate, m
	var plate_w := 0.62
	var cyl := 0.36                # cylinder across, m
	var rod := 0.2                 # rod across, m
	var hinge_h := 0.22
	var foot_top := -hh + ft
	var hinge_top := foot_top + hinge_h
	var cyl_bottom := lerpf(hinge_top, hh - plate_t, 0.45)
	var y_plate := hh - plate_t
	var cyl_top := y_plate - 0.1   # the trunnion block sits above the cylinder
	var hl := foot * 0.5
	var rake := ft * 0.7
	# The mount plate (chamfered), bolt heads under its corners, the trunnion block.
	k.color = Color.WHITE
	k.loft(_chamfer_ring(plate_w * 0.5, y_plate, 0.06), _chamfer_ring(plate_w * 0.5, hh, 0.06))
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_gear_bolt(k, Vector3(sx * plate_w * 0.37, y_plate, sz * plate_w * 0.37), Vector3.DOWN, 0.03, 0.025)
	k.color = RIM
	k.loft(_chamfer_ring(cyl * 0.5 + 0.05, cyl_top, 0.04), _chamfer_ring(cyl * 0.5 + 0.05, y_plate + 0.002, 0.04))
	# The cylinder, two clamp bands, a valve block on -Z and a hose down its +Z side.
	k.color = DARK
	k.loft(_chamfer_ring(cyl * 0.5, cyl_bottom, 0.04), _chamfer_ring(cyl * 0.5, cyl_top + 0.002, 0.04))
	k.color = RIM
	var cl := cyl_top - cyl_bottom
	for y: float in [cyl_bottom + cl * 0.2, cyl_top - cl * 0.16]:
		k.loft(_chamfer_ring(cyl * 0.5 + 0.02, y - 0.03, 0.05), _chamfer_ring(cyl * 0.5 + 0.02, y + 0.03, 0.05))
	k.color = DETAIL
	var valve_y := cyl_top - cl * 0.45
	k.box(Vector3(0.16, minf(0.14, cl * 0.25), 0.06), Vector3(0.0, valve_y, -cyl * 0.5 - 0.028))
	_gear_bolt(k, Vector3(0.0, valve_y, -cyl * 0.5 - 0.058), Vector3.FORWARD, 0.025, 0.02)
	var hose_hi := Vector3(0.0, cyl_top - cl * 0.08, cyl * 0.5)
	var hose_lo := Vector3(0.0, cyl_bottom + cl * 0.42, cyl * 0.5)
	var off := Vector3(0.0, 0.0, 0.07)
	k.color = DARK
	_tube(k, hose_hi + off * 0.5, hose_hi + off, 0.025, 8)
	_tube(k, hose_hi + off - Vector3(0.0, 0.02, 0.0), hose_lo + off + Vector3(0.0, 0.02, 0.0), 0.025, 8)
	_tube(k, hose_lo + off, hose_lo + off * 0.5, 0.025, 8)
	k.color = TRIM
	for p: Vector3 in [hose_hi, hose_lo]:
		_tube(k, p - Vector3(0.0, 0.0, 0.004), p + off * 0.5, 0.035, 6)
	# The gland and wiper seal at the cylinder's mouth, the chrome rod.
	var rr := rod * 0.5
	k.color = RIM
	k.lathe(PackedVector2Array([Vector2(rr - 0.004, cyl_bottom - 0.06), Vector2(rr + 0.06, cyl_bottom - 0.06),
			Vector2(rr + 0.06, cyl_bottom + 0.01), Vector2(rr - 0.004, cyl_bottom + 0.01)]), 12)
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(rr - 0.002, cyl_bottom - 0.08), Vector2(rr + 0.018, cyl_bottom - 0.08),
			Vector2(rr + 0.018, cyl_bottom - 0.058), Vector2(rr - 0.002, cyl_bottom - 0.058)]), 12)
	var pin_y := foot_top + hinge_h * 0.62
	k.color = TRIM
	_tube(k, Vector3(0.0, pin_y + 0.06, 0.0), Vector3(0.0, cyl_bottom - 0.03, 0.0), rr, 12)
	# The hinge: a block on the foot, two clevis cheeks, the rod's eye, a pin with caps.
	var cheek_x := rr + 0.045
	k.color = RIM
	k.box(Vector3(fw * 0.55, hinge_h * 0.32, foot * 0.4), Vector3(0.0, foot_top + hinge_h * 0.16, 0.0))
	k.color = Color.WHITE
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.05, hinge_h * 0.72, foot * 0.22), Vector3(sx * cheek_x, foot_top + hinge_h * 0.32 + hinge_h * 0.36 - 0.002, 0.0))
	k.color = DETAIL
	k.box(Vector3(cheek_x * 2.0 - 0.07, 0.16, rod + 0.02), Vector3(0.0, pin_y + 0.02, 0.0))
	k.color = TRIM
	_tube(k, Vector3(-cheek_x - 0.05, pin_y, 0.0), Vector3(cheek_x + 0.05, pin_y, 0.0), 0.04, 10)
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		_gear_bolt(k, Vector3(sx * (cheek_x + 0.05), pin_y, 0.0), Vector3(sx, 0.0, 0.0), 0.055, 0.025)
	# The sled foot: raked at both ends, a rubber sole, hazard stripes on its top at the ends.
	k.color = RIM
	_prism_x(k, PackedVector2Array([Vector2(-hl, -hh + 0.05), Vector2(hl, -hh + 0.05), Vector2(hl, foot_top - rake),
			Vector2(hl - rake, foot_top), Vector2(-hl + rake, foot_top), Vector2(-hl, foot_top - rake)]), -fw * 0.5, fw * 0.5)
	k.color = DARK
	k.box(Vector3(fw - 0.04, 0.05, foot - 0.04), Vector3(0.0, -hh + 0.025, 0.0))
	var z0 := foot * 0.21
	var z1 := hl - rake - 0.02
	if z1 - z0 > 0.04:
		for sz: float in [-1.0, 1.0]:
			_gear_hazard(k, Vector3(0.0, foot_top, sz * (z0 + z1) * 0.5), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
					Vector2(fw - 0.12, z1 - z0), 0.07)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = fw * foot * ft + cyl * cyl * (hh - cyl_bottom) + rod * rod * (cyl_bottom - hinge_top)
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * fw * 0.5, -hh, sz * hl))
			pts.append(Vector3(sx * fw * 0.5, foot_top - rake, sz * hl))
			pts.append(Vector3(sx * plate_w * 0.5, hh, sz * plate_w * 0.5))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	# The red band round the foot's sides, a hair proud.
	var g := MeshKit.new()
	var band_y := -hh + 0.05 + (foot_top - rake - (-hh + 0.05)) * 0.5
	for sx: float in [-1.0, 1.0]:
		g.box(Vector3(0.012, 0.07, foot - rake * 2.0), Vector3(sx * (fw * 0.5 + 0.006), band_y, 0.0))
	for sz: float in [-1.0, 1.0]:
		g.box(Vector3(fw - 0.1, 0.07, 0.012), Vector3(0.0, band_y, sz * (hl + 0.006)))
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.12, 0.08)
	return shape


## A six-sided bolt head `radius` across standing `height` out of a face at `at` along
## `axis` (unit), sunk 2 mm into the face.
static func _gear_bolt(k: MeshKit, at: Vector3, axis: Vector3, radius: float, height: float) -> void:
	var x := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(axis)
	var ring_a := PackedVector3Array()
	var ring_b := PackedVector3Array()
	for i in 6:
		var t := TAU * (float(i) + 0.5) / 6.0
		var o := (x * cos(t) + z * sin(t)) * radius
		ring_a.append(at + o - axis * 0.002)
		ring_b.append(at + o + axis * height)
	k.loft(ring_a, ring_b)


## A box `size` (x, y, z before turning) centred on `centre`, turned `yaw` round Y.
static func _gear_yblock(k: MeshKit, centre: Vector3, yaw: float, size: Vector3) -> void:
	var b := Basis(Vector3.UP, yaw)
	var ax := b.x * size.x * 0.5
	var az := b.z * size.z * 0.5
	var lo := PackedVector3Array()
	var hi := PackedVector3Array()
	for c: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]:
		var p := centre + ax * c.x + az * c.y
		lo.append(p - Vector3(0.0, size.y * 0.5, 0.0))
		hi.append(p + Vector3(0.0, size.y * 0.5, 0.0))
	k.loft(lo, hi)


## A hazard ring round Y: a band from radius `r0` to `r1`, `y0` to `y1`, on a `sides`-sided
## polygon (corners at the angles a lathe puts them), each side cut into `split` cells
## that alternate between colours `a` and `b`.
static func _gear_hazard_ring(k: MeshKit, r0: float, r1: float, y0: float, y1: float, sides: int, split: int,
		a: Color, b: Color) -> void:
	for s in sides * split:
		k.color = a if s % 2 == 0 else b
		var side := s / split
		var c0 := Vector2(cos(TAU * float(side) / float(sides)), sin(TAU * float(side) / float(sides)))
		var c1 := Vector2(cos(TAU * float(side + 1) / float(sides)), sin(TAU * float(side + 1) / float(sides)))
		var p0 := c0.lerp(c1, float(s % split) / float(split))
		var p1 := c0.lerp(c1, float(s % split + 1) / float(split))
		var lo := PackedVector3Array()
		var hi := PackedVector3Array()
		for p: Vector2 in [p0 * r0, p0 * r1, p1 * r1, p1 * r0]:
			lo.append(Vector3(p.x, y0, p.y))
			hi.append(Vector3(p.x, y1, p.y))
		k.loft(lo, hi)


## Hazard stripes on a flat face: a yellow plate 3 mm proud of the face filling the
## rectangle `size` (along `u`, then `v`; unit axes) round `centre`, facing `n`, and dark
## stripes `stripe` wide at 45 degrees across it, 3 mm prouder. `u` is the long way.
static func _gear_hazard(k: MeshKit, centre: Vector3, u: Vector3, v: Vector3, n: Vector3, size: Vector2,
		stripe: float) -> void:
	var hu := size.x * 0.5
	var hv := size.y * 0.5
	var rect := PackedVector2Array([Vector2(-hu, -hv), Vector2(hu, -hv), Vector2(hu, hv), Vector2(-hu, hv)])
	k.color = PartShapes.ACCENT
	var plate := PackedVector3Array()
	for p in rect:
		plate.append(centre + u * p.x + v * p.y + n * 0.003)
	k.poly(plate, n)
	k.color = DARK
	var u0 := -hu - size.y
	while u0 < hu:
		var para := PackedVector2Array([Vector2(u0, -hv), Vector2(u0 + stripe, -hv), Vector2(u0 + stripe + size.y, hv),
				Vector2(u0 + size.y, hv)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(para, rect):
			var pts := PackedVector3Array()
			for p in piece:
				pts.append(centre + u * p.x + v * p.y + n * 0.006)
			k.poly(pts, n)
		u0 += stripe * 2.0


## A personnel lift platform (the Manta freighter's two "lifts" under the belly): a white
## slab `width` along X by `depth` along Z in a dark rubber bumper band, raised steel tread
## bars on top and a hazard band across the -X end where you step on, a dark socket block
## at the +X end (where the piston comes down) with a hazard face and corner bolts,
## tubular railings with toe boards along both long sides, open at the -X end, and a dark
## control post with a capped top, a screen in a bezel and two buttons (glow) beside the
## socket. Stands on -Y; the railings reach `rail` above the slab.
static func lift_platform(width: float = 2.6, depth: float = 1.2, rail: float = 1.0) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var slab := 0.22
	var hw := width * 0.5
	var hd := depth * 0.5
	var y0 := -(slab + rail) * 0.5
	var top := y0 + slab
	var sock := 0.55
	# The slab in its bumper band.
	k.color = Color.WHITE
	k.box(Vector3(width, slab, depth), Vector3(0.0, y0 + slab * 0.5, 0.0))
	k.color = DARK
	k.box(Vector3(width + 0.016, 0.07, depth + 0.016), Vector3(0.0, y0 + slab * 0.45, 0.0))
	# The step-on hazard band and the tread bars (alternating ways) between it and the socket.
	var haz := 0.3
	_gear_hazard(k, Vector3(-hw + 0.04 + haz * 0.5, top, 0.0), Vector3.BACK, Vector3.RIGHT, Vector3.UP,
			Vector2(depth - 0.12, haz), 0.08)
	k.color = DETAIL
	var tx0 := -hw + 0.08 + haz
	var tx1 := hw - sock - 0.1
	var nx := maxi(2, int((tx1 - tx0) / 0.16))
	var nz := maxi(2, int((depth - 0.24) / 0.16))
	for i in nx:
		for j in nz:
			var p := Vector3(tx0 + (tx1 - tx0) * (float(i) + 0.5) / float(nx), top + 0.003,
					-hd + 0.12 + (depth - 0.24) * (float(j) + 0.5) / float(nz))
			var a := Vector3(0.045, 0.0, 0.012) if (i + j) % 2 == 0 else Vector3(0.012, 0.0, 0.045)
			k.poly(PackedVector3Array([p + Vector3(-a.x, 0, -a.z), p + Vector3(a.x, 0, -a.z), p + Vector3(a.x, 0, a.z),
					p + Vector3(-a.x, 0, a.z)]), Vector3.UP)
	# The socket block: a hazard face toward the deck, bolts at its top corners.
	k.color = DARK
	var sx0 := hw - sock - 0.04
	k.box(Vector3(sock, 0.28, depth - 0.1), Vector3(hw - sock * 0.5 - 0.04, top + 0.14, 0.0))
	_gear_hazard(k, Vector3(sx0, top + 0.14, 0.0), Vector3.BACK, Vector3.UP, Vector3.LEFT, Vector2(depth - 0.2, 0.16), 0.08)
	k.color = DETAIL
	for bx: float in [sx0 + 0.06, hw - 0.1]:
		for bz: float in [-1.0, 1.0]:
			_gear_bolt(k, Vector3(bx, top + 0.28, bz * (hd - 0.11)), Vector3.UP, 0.018, 0.01)
	# Railings along both long sides: posts, a top and a mid rail and a toe board, open at -X.
	k.color = TRIM
	var r := 0.025
	var x_a := -hw + 0.55
	var x_b := hw - sock - 0.12
	for sz: float in [-1.0, 1.0]:
		var z := sz * (hd - 0.06)
		for x: float in [x_a, (x_a + x_b) * 0.5, x_b]:
			_tube(k, Vector3(x, top, z), Vector3(x, top + rail - 0.02, z), r, 8)
		_tube(k, Vector3(x_a, top + rail - 0.03, z), Vector3(x_b, top + rail - 0.03, z), r, 8)
		_tube(k, Vector3(x_a, top + rail * 0.5, z), Vector3(x_b, top + rail * 0.5, z), r * 0.8, 8)
	k.color = DETAIL
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(x_b - x_a, 0.1, 0.012), Vector3((x_a + x_b) * 0.5, top + 0.06, sz * (hd - 0.06)))
	# The control post beside the socket: a cap, a screen on its -X face in a bezel, two buttons.
	k.color = DARK
	var post := Vector3(0.22, rail * 0.95, 0.16)
	var px := hw - sock - 0.3
	k.box(post, Vector3(px, top + post.y * 0.5, 0.0))
	k.color = DETAIL
	k.box(Vector3(post.x + 0.02, 0.03, post.z + 0.02), Vector3(px, top + post.y + 0.012, 0.0))
	var face_x := px - post.x * 0.5
	k.box(Vector3(0.006, 0.2, 0.14), Vector3(face_x - 0.001, top + post.y * 0.75, 0.0))
	g.box(Vector3(0.012, 0.16, 0.11), Vector3(face_x - 0.006, top + post.y * 0.75, 0.0))
	for bz: float in [-0.035, 0.035]:
		g.box(Vector3(0.012, 0.03, 0.03), Vector3(face_x - 0.004, top + post.y * 0.5, bz))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * depth * slab + sock * 0.28 * depth
	# Collision is the slab and the socket block (the railings are thin tubes), so the piston
	# can stand on the socket.
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * hw, y0, sz * hd))
			pts.append(Vector3(sx * hw, top + 0.28, sz * hd))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = Color(0.4, 0.9, 1.0)
	return shape


# --- Corsair frigate parts (v2 rebuild) ---------------------------------------------------

## A crew bunk rack (the CMS-01A Corsair's grey three-high racks down its quarters): four
## square corner posts in the material colour `height` tall on dark rubber feet with steel
## caps, `tiers` trays up them, each a frame round a dark slatted bed with a pale enamel
## berth plate on its +Z end rail, a thin chamfered pale mattress, a pillow at the +Z end
## and a folded blanket at the -Z end; a ladder of two rails and round rungs up the -X
## side at the -Z end. Stands on -Y, `length` along Z, `width` along X.
static func bunk_rack(length: float = 2.0, width: float = 0.9, height: float = 2.1, tiers: int = 3) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hl := length * 0.5
	var hw := width * 0.5
	var hh := height * 0.5
	var post := 0.08
	var foot := 0.03
	var cap := 0.02
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var at := Vector3(sx * (hw - post * 0.5), 0.0, sz * (hl - post * 0.5))
			k.color = DARK
			k.box(Vector3(post + 0.008, foot, post + 0.008), at + Vector3(0.0, -hh + foot * 0.5, 0.0))
			k.color = Color.WHITE
			k.box(Vector3(post, height - foot - cap, post), at + Vector3(0.0, (foot - cap) * 0.5, 0.0))
			k.color = DETAIL
			_seating_pad(k, at + Vector3(0.0, hh - cap, 0.0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, post * 0.5, post * 0.5, cap, 0.01)
	var pitch := (height - 0.3) / float(tiers)
	for t in tiers:
		var y := -hh + 0.22 + pitch * float(t)
		# The tray frame: side rails along Z and end rails along X, inside the posts.
		k.color = Color.WHITE
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(0.06, 0.1, length - 2.0 * post), Vector3(sx * (hw - 0.03), y, 0.0))
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(width - 2.0 * post, 0.1, 0.06), Vector3(0.0, y, sz * (hl - 0.03)))
		k.color = PLATE
		k.box(Vector3(0.14, 0.05, 0.006), Vector3(0.0, y, hl + 0.003))
		# Dark slats across the tray, the bedding on them.
		k.color = DARK
		var slats := int(maxf(4.0, floorf((length - 0.3) / 0.22)))
		for i in slats:
			var z := -hl + 0.15 + (length - 0.3) * (float(i) + 0.5) / float(slats)
			k.box(Vector3(width - 0.14, 0.03, 0.1), Vector3(0.0, y - 0.02, z))
		var y_m := y + 0.085                  # top of the mattress
		k.color = RACK_MATTRESS
		_seating_pad(k, Vector3(0.0, y - 0.005, 0.0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, hw - 0.09, hl - 0.13, 0.09, 0.025)
		k.color = RACK_LINEN
		_seating_pad(k, Vector3(0.0, y_m, hl - 0.3), Vector3.RIGHT, Vector3.BACK, Vector3.UP, hw - 0.2, 0.14, 0.07, 0.03)
		k.color = RACK_BLANKET
		_seating_pad(k, Vector3(0.0, y_m, -hl + 0.45), Vector3.RIGHT, Vector3.BACK, Vector3.UP, hw - 0.1, 0.22, 0.03, 0.01)
	# A ladder up the -X side at the -Z end: two rails, two round rungs per tier.
	k.color = DETAIL
	var lx := -hw - 0.012
	var z0 := -hl + 0.13
	var z1 := -hl + 0.43
	var top_y := -hh + 0.22 + pitch * float(tiers - 1) + 0.35
	for z: float in [z0, z1]:
		k.box(Vector3(0.024, top_y - (-hh + 0.1), 0.03), Vector3(lx, (top_y - hh + 0.1) * 0.5, z))
	var rungs := tiers * 2
	for i in rungs:
		var ry := -hh + 0.35 + (top_y - 0.08 - (-hh + 0.35)) * float(i) / float(rungs - 1)
		_tube(k, Vector3(lx, ry, z0 + 0.015), Vector3(lx, ry, z1 - 0.015), 0.012, 6)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = post * post * height * 4.0 + width * length * 0.06 * float(tiers)
	var col := BoxShape3D.new()
	col.size = Vector3(width + 0.06, height, length)
	shape.collision = col
	return shape


## A suit refill station (the white wall units down the Corsair's mess, a ring light in each):
## a white cabinet `width` across, `height` tall, `depth` deep with its back at +Z, on a dark
## plinth, a trim band where the lower cabinet meets a sloped upper front leaning back toward
## the wall. In the slope a dark recess in a bright bezel holds a glowing ring round a
## collared nozzle, a small lit screen in a dark bezel above it and a label between two lit
## LEDs below; the lower cabinet has a hinged door with a flush pull, a name plate and a louvre,
## louvred grilles on its sides and vent slots on top. Front -Z, stands on -Y.
static func refill_station(width: float = 0.8, height: float = 1.9, depth: float = 0.5) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hw := width * 0.5
	var hh := height * 0.5
	var hz := depth * 0.5
	var fz := -hz
	# The plinth and the lower cabinet, full depth.
	k.color = DARK
	k.box(Vector3(width - 0.04, 0.1, depth - 0.04), Vector3(0.0, -hh + 0.05, 0.0))
	k.color = Color.WHITE
	var low := height * 0.42
	k.box(Vector3(width, low - 0.1, depth), Vector3(0.0, -hh + 0.1 + (low - 0.1) * 0.5, 0.0))
	# The upper body: its front leans back from the cabinet's front edge to a thinner top.
	var top_d := depth * 0.55
	var y0 := -hh + low
	_prism_x(k, PackedVector2Array([Vector2(-hz, y0), Vector2(hz, y0), Vector2(hz, hh), Vector2(hz - top_d, hh)]), -hw, hw)
	# A trim band round the seam between them.
	k.color = DETAIL
	k.box(Vector3(width + 0.012, 0.03, depth + 0.006), Vector3(0.0, y0, -0.003))
	# The lower cabinet's door on a dark seam: hinges, a handle, a name plate, a louvre.
	var dw := width - 0.1
	var d_lo := -hh + 0.14
	var d_hi := y0 - 0.045
	var dh := d_hi - d_lo
	var dy := (d_lo + d_hi) * 0.5
	k.color = DARK
	k.box(Vector3(dw + 0.016, dh + 0.016, 0.004), Vector3(0.0, dy, fz - 0.002))
	k.color = Color.WHITE
	_cabinets_pad(k, Vector3(0.0, dy, fz - 0.004), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, dw * 0.5, dh * 0.5, 0.006, 0.003)
	var df := fz - 0.01
	k.color = DETAIL
	for sy: float in [-1.0, 1.0]:
		var hy := dy + sy * dh * 0.32
		_tube(k, Vector3(-dw * 0.5, hy - 0.045, df + 0.002), Vector3(-dw * 0.5, hy + 0.045, df + 0.002), 0.01, 6)
	# A flush pull: a dark pocket with a bar across it.
	var hx := dw * 0.5 - 0.05
	k.color = DARK
	k.box(Vector3(0.045, 0.18, 0.004), Vector3(hx, dy, df - 0.002))
	k.color = DETAIL
	k.strut(Vector3(hx, dy - 0.07, df - 0.005), Vector3(hx, dy + 0.07, df - 0.005), 0.01)
	k.color = PLATE
	k.box(Vector3(dw * 0.4, 0.05, 0.004), Vector3(0.0, dy + dh * 0.3, df - 0.002))
	k.color = DARK
	k.box(Vector3(dw * 0.28, 0.012, 0.002), Vector3(-dw * 0.04, dy + dh * 0.3 + 0.006, df - 0.005))
	_cabinets_louvre(k, Vector3(0.0, dy - dh * 0.28, df), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, dw * 0.32, dh * 0.12, 4, 0.006)
	# Louvred grilles on the cabinet's sides, vent slots across the top.
	for sx: float in [-1.0, 1.0]:
		_cabinets_louvre(k, Vector3(sx * hw, -hh + 0.1 + (low - 0.1) * 0.5, 0.0), Vector3.BACK, Vector3.UP,
				Vector3(sx, 0.0, 0.0), depth * 0.3, (low - 0.1) * 0.15, 4, 0.01)
	k.color = DARK
	for i in 3:
		k.box(Vector3(width * 0.55, 0.004, 0.025), Vector3(0.0, hh + 0.002, hz - top_d * (0.25 + 0.25 * float(i))))
	# The recess in the sloped face: a dark panel standing a hair proud of it, framed by a
	# bright bezel.
	var t := 0.45   # where along the slope the recess sits (0 bottom, 1 top)
	var rise := hh - y0
	var run := depth - top_d
	var along := Vector3(0.0, rise, run).normalized()          # up the face
	var n := Vector3(0.0, run, -rise).normalized()             # out of it: forward and up
	var c := Vector3(0.0, y0 + rise * t, -hz + run * t)
	var across := Vector3.RIGHT
	var rw := width * 0.62
	var rh := (hh - y0) * 0.5
	k.color = DARK
	var p0 := c + n * 0.012
	k.poly(PackedVector3Array([p0 - across * rw * 0.5 - along * rh * 0.5, p0 + across * rw * 0.5 - along * rh * 0.5,
			p0 + across * rw * 0.5 + along * rh * 0.5, p0 - across * rw * 0.5 + along * rh * 0.5]), n)
	k.color = TRIM
	var bu := rw * 0.5 + 0.012
	var bv := rh * 0.5 + 0.012
	var bc := c + n * 0.014
	for s: float in [-1.0, 1.0]:
		k.strut(bc - across * (bu + 0.012) + along * s * bv, bc + across * (bu + 0.012) + along * s * bv, 0.024)
		k.strut(bc + across * s * bu - along * bv, bc + across * s * bu + along * bv, 0.024)
	# The nozzle at the ring's centre: a bright collar, the barrel standing out of the
	# recess, a dark bore at its tip.
	var ring_r := minf(rw, rh) * 0.34
	var collar_a := PackedVector3Array()
	var collar_b := PackedVector3Array()
	var nz := PackedVector3Array()
	var nz_out := PackedVector3Array()
	var bore := PackedVector3Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		var dir := across * cos(a) + along * sin(a)
		collar_a.append(c + n * 0.012 + dir * ring_r * 0.62)
		collar_b.append(c + n * 0.03 + dir * ring_r * 0.55)
		nz.append(c + n * 0.02 + dir * ring_r * 0.45)
		nz_out.append(c + n * 0.08 + dir * ring_r * 0.45)
		bore.append(c + n * 0.0805 + dir * ring_r * 0.25)
	k.color = TRIM
	k.loft(collar_a, collar_b)
	k.color = DETAIL
	k.loft(nz, nz_out)
	k.color = DARK
	k.poly(bore, n)
	# A dark bezel for the screen above the recess, a label below it.
	var sc := c + along * (rh * 0.5 + 0.08)
	var lc := c - along * (rh * 0.5 + 0.07)
	k.color = DARK
	_cabinets_pad(k, sc + n * 0.002, across, along, n, 0.145, 0.05, 0.01, 0.004)
	k.color = PLATE
	_cabinets_pad(k, lc + n * 0.002, across, along, n, 0.1, 0.022, 0.006)
	k.color = DARK
	for s: float in [-1.0, 1.0]:
		_cabinets_pad(k, lc + across * s * 0.15 + n * 0.002, across, along, n, 0.022, 0.022, 0.006, 0.003)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * depth * 0.6
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth)
	shape.collision = col
	# The glowing ring round the nozzle, the screen in its bezel and two LEDs by the label.
	var g := MeshKit.new()
	var inner := PackedVector3Array()
	var outer := PackedVector3Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		var dir := across * cos(a) + along * sin(a)
		var q := c + n * 0.016
		inner.append(q + dir * ring_r * 0.75)
		outer.append(q + dir * ring_r)
	for i in 16:
		var j := (i + 1) % 16
		g.quad(inner[i], outer[i], outer[j], inner[j], n)
	var sq := sc + n * 0.0125
	g.poly(PackedVector3Array([sq - across * 0.12 - along * 0.035, sq + across * 0.12 - along * 0.035,
			sq + across * 0.12 + along * 0.035, sq - across * 0.12 + along * 0.035]), n)
	for s: float in [-1.0, 1.0]:
		var lq := lc + across * s * 0.15 + n * 0.0085
		g.poly(PackedVector3Array([lq - across * 0.014 - along * 0.014, lq + across * 0.014 - along * 0.014,
				lq + across * 0.014 + along * 0.014, lq - across * 0.014 + along * 0.014]), n)
	shape.glow = g.finish()
	shape.glow_color = Color(0.85, 1.0, 0.3)
	return shape


## A reactor in its housing (the Corsair's reactor room: a big green core glowing through a
## round window in a framed cabinet): a cabinet `size` (x, y, z) in the material colour on a
## dark plinth, corner posts standing proud on bolted feet with caps and bolts down their
## fronts, a rail across the top of the front, a thick round bezel ringed with bolts in the
## front (-Z) round a dark window crossed by two bars with the glowing core behind it, a hazard
## band under the window, two pale lamp housings on the front below, a louvred vent and a
## bolted access panel with a handle on each side (+-X) and a dark cowl on top with a lit gauge
## strip in its front, a hatch and four flanged pipe stubs. Stands on -Y.
static func reactor_core(size: Vector3 = Vector3(2.0, 2.4, 1.4), glow := Color(0.6, 1.0, 0.25)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var plinth := 0.16
	k.color = DARK
	k.box(Vector3(size.x - 0.06, plinth, size.z - 0.06), Vector3(0.0, -hy + plinth * 0.5, 0.0))
	# The cabinet, set back a little from the posts.
	k.color = Color.WHITE
	var body_top := hy - 0.22
	var body_y := (-hy + plinth + body_top) * 0.5
	var sx_face := hx - 0.08
	k.box(Vector3(size.x - 0.16, body_top - (-hy + plinth), size.z - 0.12), Vector3(0.0, body_y, 0.0))
	# Corner posts, a shade darker, on bolted feet under caps; bolts down the front posts.
	k.color = POST
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.12, size.y - plinth, 0.12), Vector3(sx * (hx - 0.06), plinth * 0.5, sz * (hz - 0.06)))
	# A rail across the top of the front, between the posts.
	k.box(Vector3(size.x - 0.24, 0.08, 0.06), Vector3(0.0, hy - 0.2, -hz + 0.035))
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var pc := Vector3(sx * (hx - 0.06), 0.0, sz * (hz - 0.06))
			k.box(Vector3(0.15, 0.05, 0.15), pc + Vector3(0.0, -hy + plinth + 0.025, 0.0))
			k.box(Vector3(0.14, 0.035, 0.14), pc + Vector3(0.0, hy + 0.0175, 0.0))
	var nb := maxi(3, int((size.y - plinth - 0.3) / 0.45))
	for sx: float in [-1.0, 1.0]:
		for i in nb:
			var y := -hy + plinth + 0.2 + (size.y - plinth - 0.45) * float(i) / float(nb - 1)
			k.box(Vector3(0.05, 0.05, 0.016), Vector3(sx * (hx - 0.06), y, -hz - 0.008))
	# The dark cowl on top, with a hatch and four flanged pipe stubs.
	k.color = DARK
	var cowl_front := -(hz - 0.15)
	k.box(Vector3(size.x - 0.3, 0.2, size.z - 0.3), Vector3(0.0, hy - 0.1, 0.0))
	k.color = DETAIL
	k.box(Vector3(size.x * 0.3, 0.02, size.z * 0.3), Vector3(0.0, hy + 0.01, 0.0))
	k.box(Vector3(size.x * 0.12, 0.03, 0.04), Vector3(0.0, hy + 0.035, -size.z * 0.1))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_piping_spin(k, Vector3(sx * (hx - 0.35), 0.0, sz * (hz - 0.35)), Vector3.UP, PackedVector2Array([
					Vector2(0.05, hy), Vector2(0.05, hy + 0.025), Vector2(0.065, hy + 0.035), Vector2(0.085, hy + 0.035),
					Vector2(0.085, hy + 0.06), Vector2(0.0, hy + 0.06)]), [DETAIL] as Array[Color], 10)
	# The gauge strip's dark bezel in the cowl's front, above the rail.
	k.color = DARK
	k.box(Vector3(size.x * 0.4, 0.09, 0.02), Vector3(0.0, hy - 0.08, cowl_front - 0.01))
	# The round window: a thick bezel (a ring of boxes) round a dark disc, on the front.
	var front := -(hz - 0.06)
	var wy := body_y + size.y * 0.1
	var wr := minf(size.x, size.y) * 0.3
	var sides := 20
	k.color = BEZEL
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var pa := PackedVector3Array()
		var pb := PackedVector3Array()
		for a: float in [a0, a1]:
			pa.append(Vector3(cos(a) * wr, wy + sin(a) * wr, front - 0.01))
		for a: float in [a1, a0]:
			pa.append(Vector3(cos(a) * wr * 1.25, wy + sin(a) * wr * 1.25, front - 0.01))
		for p in pa:
			pb.append(p + Vector3(0.0, 0.0, -0.08))
		k.loft(pa, pb)
	k.color = DETAIL
	_piping_bolts(k, Vector3(0.0, wy, front - 0.09), Vector3.FORWARD, 0.0, 12, wr * 1.125, 0.045, 0.015, PI / 12.0)
	k.color = WINDOW
	var disc := PackedVector3Array()
	for i in sides:
		var a := TAU * float(i) / float(sides)
		disc.append(Vector3(cos(a) * wr, wy + sin(a) * wr, front - 0.004))
	k.poly(disc, Vector3.FORWARD)
	# Two guard bars across the window, in front of the core.
	k.color = DARK
	k.box(Vector3(wr * 2.04, 0.045, 0.025), Vector3(0.0, wy, front - 0.035))
	k.box(Vector3(0.045, wr * 2.04, 0.025), Vector3(0.0, wy, front - 0.035))
	# A hazard band under the window: yellow with dark slashes.
	var by := wy - wr * 1.25 - 0.16
	k.color = HAZARD_YELLOW
	k.box(Vector3(size.x * 0.7, 0.1, 0.02), Vector3(0.0, by, front - 0.01))
	k.color = DARK
	for i in 6:
		var x := -size.x * 0.3 + size.x * 0.6 * (float(i) + 0.5) / 6.0
		k.poly(PackedVector3Array([Vector3(x - 0.06, by - 0.05, front - 0.022), Vector3(x - 0.01, by - 0.05, front - 0.022),
				Vector3(x + 0.06, by + 0.05, front - 0.022), Vector3(x + 0.01, by + 0.05, front - 0.022)]), Vector3.FORWARD)
	# Two pale lamp housings on the front below the band.
	k.color = BEZEL
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.34, 0.14, 0.08), Vector3(sx * size.x * 0.22, by - 0.32, front - 0.04))
	# Each side (+-X): a louvred vent over a bolted access panel with a handle.
	var vd := size.z - 0.36
	var vh := minf(size.y * 0.3, 0.9)
	var vy := wy + wr * 0.2
	var ay := (-hy + plinth + vy - vh * 0.5) * 0.5
	var ah := minf(vy - vh * 0.5 - (-hy + plinth) - 0.2, 0.9)
	var slats := maxi(4, int(vh / 0.1))
	for sx: float in [-1.0, 1.0]:
		k.color = DARK
		k.box(Vector3(0.012, vh, vd), Vector3(sx * (sx_face + 0.006), vy, 0.0))
		k.color = DETAIL
		for i in slats:
			var y := vy - vh * 0.5 + vh * (float(i) + 0.5) / float(slats)
			k.box(Vector3(0.024, vh / float(slats) * 0.45, vd - 0.04), Vector3(sx * (sx_face + 0.012), y, 0.0))
		if ah > 0.25:
			k.color = POST
			k.box(Vector3(0.012, ah, vd), Vector3(sx * (sx_face + 0.006), ay, 0.0))
			k.color = DETAIL
			for py: float in [-1.0, 1.0]:
				for pz: float in [-1.0, 1.0]:
					k.box(Vector3(0.016, 0.04, 0.04), Vector3(sx * (sx_face + 0.02), ay + py * (ah * 0.5 - 0.06), pz * (vd * 0.5 - 0.06)))
			k.color = DARK
			k.box(Vector3(0.03, 0.05, minf(vd * 0.4, 0.3)), Vector3(sx * (sx_face + 0.027), ay, 0.0))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = size.x * size.y * size.z * 0.55
	var col := BoxShape3D.new()
	col.size = Vector3(size.x, size.y, size.z + 0.2)
	shape.collision = col
	# The glowing core behind the window, the lamp lenses and the cowl's gauge cells.
	var g := MeshKit.new()
	var core := PackedVector3Array()
	for i in sides:
		var a := TAU * float(i) / float(sides)
		core.append(Vector3(cos(a) * wr * 0.62, wy + sin(a) * wr * 0.62, front - 0.008))
	g.poly(core, Vector3.FORWARD)
	for sx: float in [-1.0, 1.0]:
		g.box(Vector3(0.26, 0.06, 0.01), Vector3(sx * size.x * 0.22, by - 0.32, front - 0.085))
	var cells := 6
	var cw := size.x * 0.36 / float(cells)
	for i in cells:
		g.box(Vector3(cw * 0.7, 0.05, 0.006), Vector3(-size.x * 0.18 + cw * (float(i) + 0.5), hy - 0.08, cowl_front - 0.023))
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


# --- Ship carrier parts (v2 rebuild) ------------------------------------------------------

## A roof landing pad (the two dark pads on the Porpoise's back, a green beacon in each): a
## slab `width` across (X) and `length` long (Z) in the material colour with a dark lip
## round its lower edge, on four short dark legs with bolted foot plates and two steel
## beams under it, `height` tall overall; a yellow border round its top with dark checks
## along it, tie-down rings in dark pockets inside the border, a stencilled yellow aiming
## circle with four ticks round a dark beacon housing in the middle (a bolt ring, a guard
## cage over a glowing dome, PartShape.glow), and a lamp in a round housing at each corner.
## Stands on -Y.
static func landing_pad(width: float = 6.0, length: float = 4.0, height: float = 0.5,
		glow := Color(0.35, 1.0, 0.4)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var hw := width * 0.5
	var hl := length * 0.5
	var hh := height * 0.5
	var slab := 0.18
	var leg_h := height - slab
	var top := hh
	var under := top - slab
	# The legs, inset from the corners, on bolted foot plates; two beams under the slab.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector3(sx * (hw - 0.45), -hh, sz * (hl - 0.45))
			k.color = DARK
			k.box(Vector3(0.3, leg_h - 0.01, 0.3), c + Vector3(0.0, 0.01 + (leg_h - 0.01) * 0.5, 0.0))
			k.color = Color.WHITE
			k.box(Vector3(0.44, 0.03, 0.44), c + Vector3(0.0, 0.015, 0.0))
			k.color = DETAIL
			for bx: float in [-1.0, 1.0]:
				for bz: float in [-1.0, 1.0]:
					_gear_bolt(k, c + Vector3(bx * 0.18, 0.03, bz * 0.18), Vector3.UP, 0.018, 0.012)
	k.color = DETAIL
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(width - 0.9, 0.12, 0.12), Vector3(0.0, under - 0.06, sz * (hl - 0.45)))
	# The slab, a dark lip round its lower edge.
	k.color = Color.WHITE
	k.box(Vector3(width, slab, length), Vector3(0.0, top - slab * 0.5, 0.0))
	k.color = DARK
	k.box(Vector3(width + 0.016, 0.05, length + 0.016), Vector3(0.0, under + 0.03, 0.0))
	# The yellow border: strips along both long edges full width, the ends between them.
	var band := 0.3
	var t := 0.015
	k.color = PAD_YELLOW
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(width - 0.1, t, band), Vector3(0.0, top + t * 0.5, sz * (hl - 0.05 - band * 0.5)))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(band, t, length - 0.1 - 2.0 * band - 0.02), Vector3(sx * (hw - 0.05 - band * 0.5), top + t * 0.5, 0.0))
	# Dark checks along the long strips, standing a hair proud of them.
	k.color = DARK
	var checks := int(maxf(4.0, floorf((width - 0.4) / 0.6)))
	for sz: float in [-1.0, 1.0]:
		for i in checks:
			var x := -hw + 0.2 + (width - 0.4) * (float(i) + 0.5) / float(checks)
			var off := band * 0.25 if i % 2 == 0 else -band * 0.25
			k.box(Vector3(0.15, 0.01, band * 0.5), Vector3(x, top + t + 0.005, sz * (hl - 0.05 - band * 0.5) + off))
	# Tie-down rings inside the border: a dark pocket and a steel ring lying in it.
	var ties: Array[Vector3] = []
	var tz := hl - 0.05 - band - 0.2
	var tx := hw - 0.05 - band - 0.2
	for sz: float in [-1.0, 1.0]:
		for fx: float in [-0.55, -0.2, 0.2, 0.55]:
			ties.append(Vector3(fx * hw, top, sz * tz))
	for sx: float in [-1.0, 1.0]:
		ties.append(Vector3(sx * tx, top, 0.0))
	for p: Vector3 in ties:
		var pocket := PackedVector3Array()
		for i in 8:
			var a := TAU * float(i) / 8.0
			pocket.append(p + Vector3(cos(a) * 0.1, 0.002, sin(a) * 0.1))
		k.color = DARK
		k.poly(pocket, Vector3.UP)
		k.color = DETAIL
		var ring := PackedVector2Array([Vector2(0.05, 0.004), Vector2(0.075, 0.004), Vector2(0.075, 0.018),
				Vector2(0.05, 0.018)])
		var ring_at := PackedVector2Array()
		for q in ring:
			ring_at.append(q + Vector2(0.0, p.y))
		var before := k.verts.size()
		k.lathe(ring_at, 8)
		for i in range(before, k.verts.size()):
			k.verts[i] += Vector3(p.x, 0.0, p.z)
	# The stencilled aiming circle and four ticks round the beacon, paint on the deck.
	k.color = PAD_YELLOW
	var r0 := minf(hw, hl) * 0.42
	var r1 := r0 + 0.16
	for i in 24:
		var a0 := TAU * float(i) / 24.0
		var a1 := TAU * float(i + 1) / 24.0
		var y := top + 0.002
		k.quad(Vector3(cos(a0) * r0, y, sin(a0) * r0), Vector3(cos(a0) * r1, y, sin(a0) * r1),
				Vector3(cos(a1) * r1, y, sin(a1) * r1), Vector3(cos(a1) * r0, y, sin(a1) * r0), Vector3.UP)
	for d: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var side := Vector3(d.z, 0.0, d.x) * 0.075
		var a := d * (r1 + 0.1) + Vector3(0.0, top + 0.002, 0.0)
		var b := d * (r1 + 0.45) + Vector3(0.0, top + 0.002, 0.0)
		k.quad(a - side, a + side, b + side, b - side, Vector3.UP)
	# The beacon housing in the middle: a short dark drum on a bolt ring, a guard cage over it.
	k.color = DARK
	k.lathe(PackedVector2Array([Vector2(0.0, top), Vector2(0.32, top), Vector2(0.28, top + 0.12), Vector2(0.0, top + 0.12)]), 16)
	k.color = DETAIL
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		_gear_bolt(k, Vector3(cos(a) * 0.37, top, sin(a) * 0.37), Vector3.UP, 0.02, 0.014)
	for i in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		var d := Vector3(cos(a), 0.0, sin(a))
		var p0 := d * 0.24 + Vector3(0.0, top + 0.11, 0.0)
		var p1 := d * 0.2 + Vector3(0.0, top + 0.24, 0.0)
		var p2 := Vector3(0.0, top + 0.275, 0.0)
		k.strut(p0, p1, 0.022)
		k.strut(p1, p2, 0.022)
	k.box(Vector3(0.07, 0.014, 0.07), Vector3(0.0, top + 0.278, 0.0))
	# Corner lamp housings: a dark base and a steel rim round each lens.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector3(sx * (hw - 0.55), 0.0, sz * (hl - 0.55))
			var before := k.verts.size()
			k.color = DARK
			k.lathe(PackedVector2Array([Vector2(0.0, top), Vector2(0.1, top), Vector2(0.09, top + 0.035),
					Vector2(0.0, top + 0.035)]), 8)
			k.color = DETAIL
			k.lathe(PackedVector2Array([Vector2(0.058, top + 0.03), Vector2(0.078, top + 0.03), Vector2(0.074, top + 0.055),
					Vector2(0.058, top + 0.055)]), 8)
			for i in range(before, k.verts.size()):
				k.verts[i] += c
			var gb := g.verts.size()
			g.lathe(PackedVector2Array([Vector2(0.0, top + 0.035), Vector2(0.056, top + 0.035), Vector2(0.04, top + 0.07),
					Vector2(0.0, top + 0.08)]), 8)
			for i in range(gb, g.verts.size()):
				g.verts[i] += c
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * length * slab * 0.5 + 0.09 * leg_h * 4.0
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, length)
	shape.collision = col
	# The beacon dome glows (the corner lenses went in above).
	g.lathe(PackedVector2Array([Vector2(0.0, top + 0.12), Vector2(0.18, top + 0.12), Vector2(0.12, top + 0.24), Vector2(0.0, top + 0.27)]), 12)
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


# --- Endeavor parts (v2) -----------------------------------------------------------------
## A triangular armour fin (the dark blades down the Endeavor's habitat flanks): a blade
## `thickness` thick (X) whose foot runs `length` along Z on -Y, rising to `height` at its
## aft (+Z) end, in the hull's paint, its sloped edge capped with a titanium strip and a
## carbon-fibre inset panel on both faces standing a few millimetres proud on a gunmetal
## border bolted at its corners; an anodised cap down the aft edge, a bolted gunmetal
## doubler strip along the foot on both faces, a rubber root seal filleting the foot on both
## faces, a panel line, and a red-lit navigation lamp (PartShape.glow) in a moulded plastic
## housing at the top aft corner under a faceted red lens (PartShape.glass).
## Stands on -Y.
static func fin_blade(length: float = 2.4, height: float = 1.6, thickness: float = 0.22) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hl := length * 0.5
	var hh := height * 0.5
	var ht := thickness * 0.5
	# The blade: a triangle (foot along Z, the tall end aft), extruded across X.
	var tri := [Vector3(0.0, -hh, -hl), Vector3(0.0, -hh, hl), Vector3(0.0, hh, hl)]
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for p: Vector3 in tri:
		a.append(p + Vector3(-ht, 0.0, 0.0))
		b.append(p + Vector3(ht, 0.0, 0.0))
	k.color = Color.WHITE
	k.loft(a, b)
	# A pale cap along the sloped edge, standing proud of it.
	var slope_n := Vector3(0.0, length, -height).normalized()
	k.color = AERO_EDGE
	var c0 := Vector3(0.0, -hh, -hl) + slope_n * 0.012
	var c1 := Vector3(0.0, hh, hl) + slope_n * 0.012
	var cap_a := PackedVector3Array([c0 + Vector3(-ht * 0.7, 0, 0), c1 + Vector3(-ht * 0.7, 0, 0)])
	var cap_b := PackedVector3Array([c0 + Vector3(ht * 0.7, 0, 0), c1 + Vector3(ht * 0.7, 0, 0)])
	k.quad(cap_a[0], cap_b[0], cap_b[1], cap_a[1], slope_n)
	# An anodised cap down the aft edge.
	k.color = ANODISED
	k.box(Vector3(thickness * 0.7, height - 0.1, 0.012), Vector3(0.0, -0.05, hl + 0.006))
	# Carbon-fibre inset panels on both faces, a smaller triangle inside the blade, on a
	# gunmetal border, bolted at its corners.
	var p0 := Vector2(-hl + length * 0.42, -hh + 0.16)
	var p1 := Vector2(hl - 0.14, -hh + 0.16)
	var p2 := Vector2(hl - 0.14, hh - height * 0.3)
	var ctr := (p0 + p1 + p2) / 3.0
	for sx: float in [-1.0, 1.0]:
		var n := Vector3(sx, 0.0, 0.0)
		var outer := [ctr + (p0 - ctr) * 1.12, ctr + (p1 - ctr) * 1.12, ctr + (p2 - ctr) * 1.12]
		k.color = GUNMETAL
		var x := sx * (ht + 0.002)
		k.tri(Vector3(x, outer[0].y, outer[0].x), Vector3(x, outer[1].y, outer[1].x), Vector3(x, outer[2].y, outer[2].x), n)
		k.color = CARBON
		x = sx * (ht + 0.004)
		k.tri(Vector3(x, p0.y, p0.x), Vector3(x, p1.y, p1.x), Vector3(x, p2.y, p2.x), n)
		k.color = DETAIL
		for p: Vector2 in outer:
			var q := p.lerp(ctr, 0.12)
			_gear_bolt(k, Vector3(sx * (ht + 0.002), q.y, q.x), n, 0.022, 0.01)
		# The root doubler: a wedge strip along the foot (from where the blade is tall
		# enough), bolted.
		k.color = GUNMETAL
		var dh := 0.08
		var dz0 := -hl + length * dh / height + 0.06
		k.loft(PackedVector3Array([Vector3(sx * (ht - 0.002), -hh, dz0), Vector3(sx * (ht + 0.018), -hh, dz0),
				Vector3(sx * (ht - 0.002), -hh + dh, dz0)]),
				PackedVector3Array([Vector3(sx * (ht - 0.002), -hh, hl - 0.02), Vector3(sx * (ht + 0.018), -hh, hl - 0.02),
				Vector3(sx * (ht - 0.002), -hh + dh, hl - 0.02)]))
		# A panel line across the face from the slope down to the root, ahead of the panel.
		k.color = DARK
		var zl := -hl + length * 0.3
		var ytop := -hh + height * 0.3 * 0.9
		x = sx * (ht + 0.002)
		k.quad(Vector3(x, -hh + dh + 0.03, zl - 0.008), Vector3(x, -hh + dh + 0.03, zl + 0.008), Vector3(x, ytop, zl + 0.008),
				Vector3(x, ytop, zl - 0.008), n)
	# The root seal: a rubber fillet along each face where the blade meets the hull plate,
	# from just behind the sharp leading end to the aft edge.
	k.color = RUBBER
	for sx: float in [-1.0, 1.0]:
		var s0 := PackedVector3Array([Vector3(sx * (ht - 0.001), -hh - 0.002, -hl + 0.05), Vector3(sx * (ht + 0.03), -hh - 0.002, -hl + 0.05),
				Vector3(sx * (ht - 0.001), -hh + 0.012, -hl + 0.05)])
		var s1 := PackedVector3Array([Vector3(sx * (ht - 0.001), -hh - 0.002, hl - 0.004), Vector3(sx * (ht + 0.03), -hh - 0.002, hl - 0.004),
				Vector3(sx * (ht - 0.001), -hh + 0.012, hl - 0.004)])
		k.loft(s0, s1)
	# The navigation light at the top aft corner: a plastic housing, the red lamp facing aft
	# under a faceted red lens.
	k.color = PLASTIC_DARK
	k.box(Vector3(thickness + 0.016, 0.1, 0.13), Vector3(0.0, hh - 0.07, hl - 0.057))
	var g := MeshKit.new()
	g.box(Vector3(thickness * 0.6, 0.06, 0.004), Vector3(0.0, hh - 0.07, hl + 0.010))
	var gk := MeshKit.new()
	_navlamps_lens(gk, Vector3(0.0, hh - 0.07, hl + 0.008), Vector3.BACK, Vector3.RIGHT, thickness * 0.4, 0.042, 0.016)
	var shape := PartShapes.PartShape.new()
	shape.glass = gk.finish()
	shape.glass_kind = Glazing.Kind.RED
	shape.mesh = k.finish()
	shape.volume = length * height * 0.5 * thickness
	var col := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array(a)
	pts.append_array(b)
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.18, 0.12)
	return shape


## A ring spoke (the arms that hold the Endeavor's gravity rings to their hubs): a box
## girder `length` long along X, `height` tall and `width` wide: side webs between top and
## bottom flanges standing a little proud, octagonal dark lightening holes with steel lips
## down both webs between galvanised upright stiffeners, bolted galvanised end plates, a
## galvanised tread along its top with rubber anti-slip slats, and a galvanised cable tray
## on hangers along its +Z side with three PVC-jacketed cables in rubber cleats.
## Collision is the girder's box (its top is the tread, players walk it).
static func spoke_beam(length: float = 3.0, width: float = 1.2, height: float = 0.9) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hl := length * 0.5
	var hw := width * 0.5
	var hh := height * 0.5
	var tray := 0.16
	var body_w := width - tray - 0.02
	var bz := -hw + body_w * 0.5
	var ft := clampf(height * 0.05, 0.03, 0.06)   # flange thickness, m
	var lip := 0.008                              # flanges' overhang past the webs, m
	# The webs, then the top and bottom flanges standing a little proud of them.
	k.color = Color.WHITE
	k.box(Vector3(length, height - 2.0 * ft, body_w), Vector3(0.0, 0.0, bz))
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(length, ft, body_w + 2.0 * lip), Vector3(0.0, sy * (hh - ft * 0.5), bz))
	# Lightening holes down both webs: a dark octagon with a steel lip round it, upright
	# stiffeners between them and at the ends.
	var holes := maxi(int(length / (height * 1.2)), 1)
	var hx := minf(height * 0.32, length / float(holes) * 0.32)
	var hy := height * 0.24
	var hc := minf(hx, hy) * 0.35
	var web := body_w * 0.5
	for i in holes:
		var x := -hl + length * (float(i) + 0.5) / float(holes)
		for sz: float in [-1.0, 1.0]:
			_sensors_hole(k, Vector3(x, 0.0, bz + sz * web), sz, hx, hy, hc, minf(0.04, hy * 0.2))
	k.color = GALVANISED
	for i in holes + 1:
		var x := clampf(-hl + length * float(i) / float(holes), -hl + 0.04, hl - 0.04)
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.05, height - 2.0 * ft, 0.012), Vector3(x, 0.0, bz + sz * (web + 0.006)))
	# Bolted end plates.
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.012, height - 2.0 * ft - 0.02, body_w + 0.012), Vector3(sx * (hl - 0.004), 0.0, bz))
	# The grating tread on top: rubber anti-slip slats across a galvanised frame.
	k.box(Vector3(length - 0.1, 0.03, body_w - 0.12), Vector3(0.0, hh + 0.015, bz))
	k.color = TREAD
	var slats := maxi(int(length / 0.18), 2)
	for i in slats:
		var x := -hl + 0.1 + (length - 0.2) * (float(i) + 0.5) / float(slats)
		k.box(Vector3(0.05, 0.012, body_w - 0.2), Vector3(x, hh + 0.036, bz))
	# The cable tray along the +Z side: a channel on hangers off the web, three cables in it
	# with straps round them at each hanger.
	var tz := hw - tray * 0.5
	var ty := -hh * 0.3
	k.color = GALVANISED
	k.box(Vector3(length - 0.06, 0.03, tray), Vector3(0.0, ty, tz))
	k.box(Vector3(length - 0.06, 0.12, 0.02), Vector3(0.0, ty + 0.06, hw - 0.01))
	k.box(Vector3(length - 0.06, 0.06, 0.012), Vector3(0.0, ty + 0.045, hw - tray + 0.006))
	var hangers := maxi(2, int(length / 0.7) + 1)
	var web_z := bz + web
	for i in hangers:
		var x := lerpf(-hl + 0.12, hl - 0.12, float(i) / float(hangers - 1))
		k.color = GALVANISED
		k.box(Vector3(0.04, 0.12, hw - tray + 0.01 - web_z), Vector3(x, ty + 0.03, (web_z + hw - tray + 0.01) * 0.5))
		k.box(Vector3(0.04, 0.02, tray + 0.03), Vector3(x, ty - 0.025, tz - 0.015))
		k.color = RUBBER
		k.box(Vector3(0.025, 0.09, tray - 0.03), Vector3(x, ty + 0.06, tz))
	var cable_r := 0.022
	var cz: Array[float] = [tz - 0.04, tz, tz + 0.04]
	var cable_cols: Array[Color] = [PNL_CABLE, RUBBER, PNL_CABLE_BLUE]
	for i in 3:
		k.color = cable_cols[i]
		_tube(k, Vector3(-hl + 0.05, ty + 0.015 + cable_r, cz[i]), Vector3(hl - 0.05, ty + 0.015 + cable_r, cz[i]), cable_r, 6)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * height * body_w * 0.3
	var col := BoxShape3D.new()
	col.size = Vector3(length, height + 0.06, width)
	shape.collision = col
	return shape


## A lightening hole on a web facing `sz` (+1 +Z, -1 -Z) at `at` (on the web's face): a
## dark octagon `hx` by `hy` (half sizes, corners cut by `c`) and a steel lip `rim` wide
## round it, a few millimetres proud.
static func _sensors_hole(k: MeshKit, at: Vector3, sz: float, hx: float, hy: float, c: float, rim: float) -> void:
	var oct := func(ax: float, ay: float, ac: float, z: float) -> PackedVector3Array:
		return PackedVector3Array([at + Vector3(ax - ac, -ay, z), at + Vector3(ax, -ay + ac, z), at + Vector3(ax, ay - ac, z),
				at + Vector3(ax - ac, ay, z), at + Vector3(-ax + ac, ay, z), at + Vector3(-ax, ay - ac, z),
				at + Vector3(-ax, -ay + ac, z), at + Vector3(-ax + ac, -ay, z)])
	var out := Vector3(0.0, 0.0, sz)
	k.color = DARK
	k.poly(oct.call(hx, hy, c, sz * 0.003), out)
	k.color = DETAIL
	var inner: PackedVector3Array = oct.call(hx, hy, c, sz * 0.006)
	var outer: PackedVector3Array = oct.call(hx + rim, hy + rim, c + rim * 0.4, sz * 0.006)
	var back_in: PackedVector3Array = oct.call(hx, hy, c, 0.0)
	for i in 8:
		var j := (i + 1) % 8
		k.quad(outer[i], outer[j], inner[j], inner[i], out)
		# The lip's inner edge, down to the web, facing into the hole.
		var mid := (inner[i] + inner[j]) * 0.5 - at
		k.quad(inner[i], inner[j], back_in[j], back_in[i], Vector3(-mid.x, -mid.y, 0.0))


## A sleep pod (the crew berths in the Endeavor's habitat): a pale chamfered capsule
## `length` long along Z on a dark kick plinth set in under it, a dark bumper band round
## it, a steel lip round its rim with two canopy hinges at the foot (+Z) and vent slats in
## the foot end; inside a chamfered dark mattress, a pillow at the head end (-Z) and a
## folded blanket at the foot; a glass canopy over the top half (PartShape.glass), a dark
## bezel down the +X side holding a lit status strip of five cells, and a screen facing
## the sleeper in a dark bezel on a stalk at the head end (lit). Stands on -Y.
static func sleep_pod(length: float = 2.2, width: float = 0.95, height: float = 1.05) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var hl := length * 0.5
	var hw := width * 0.5
	var hh := height * 0.5
	var plinth := 0.18
	var base := -hh + plinth                  # underside of the tub
	var rim := -hh + height * 0.55
	var tub := PartShapes._chamfer_rect(width, length, 0.18)
	# The kick plinth, set in under the tub.
	var k0 := PackedVector3Array()
	var k1 := PackedVector3Array()
	for p in tub:
		k0.append(Vector3(p.x * 0.8, -hh, p.y * 0.88))
		k1.append(Vector3(p.x * 0.86, base, p.y * 0.92))
	k.color = DARK
	k.loft(k0, k1)
	# The shell: a chamfered tub from the plinth to the canopy line.
	var lo := PackedVector3Array()
	var hi := PackedVector3Array()
	for p in tub:
		lo.append(Vector3(p.x * 0.92, base, p.y * 0.96))
		hi.append(Vector3(p.x, rim, p.y))
	k.color = Color.WHITE
	k.loft(lo, hi)
	# A dark bumper band round the tub (it follows the tub's taper, a few mm proud).
	# (At a fraction f of the way up, the tub's side is scaled 0.92 + 0.08 f across and
	# 0.96 + 0.04 f along.)
	var b0 := PackedVector3Array()
	var b1 := PackedVector3Array()
	for p in tub:
		var out := Vector3(signf(p.x), 0.0, signf(p.y)) * 0.006
		b0.append(Vector3(p.x * (0.92 + 0.08 * 0.28), base + (rim - base) * 0.28, p.y * (0.96 + 0.04 * 0.28)) + out)
		b1.append(Vector3(p.x * (0.92 + 0.08 * 0.36), base + (rim - base) * 0.36, p.y * (0.96 + 0.04 * 0.36)) + out)
	k.color = DARK
	k.loft(b0, b1)
	# Vent slats in the foot end.
	for f: float in [0.45, 0.55, 0.65]:
		k.box(Vector3(width * 0.4, 0.018, 0.012), Vector3(0.0, base + (rim - base) * f, hl * (0.96 + 0.04 * f) + 0.004))
	# The status bezel down the +X side, five lit cells in it.
	var fs := 0.62
	var ys := base + (rim - base) * fs
	var xs := hw * (0.92 + 0.08 * fs)
	_seating_pad(k, Vector3(xs - 0.002, ys, 0.0), Vector3.BACK, Vector3.UP, Vector3.RIGHT, length * 0.3, 0.035, 0.012, 0.004)
	for i in 5:
		g.box(Vector3(0.006, 0.02, length * 0.09), Vector3(xs + 0.012, ys, length * 0.11 * (float(i) - 2.0)))
	# A steel lip round the rim (a bar along each edge), two hinges at the foot.
	k.color = DETAIL
	for i in tub.size():
		var a := Vector3(tub[i].x, rim + 0.008, tub[i].y)
		var b := Vector3(tub[(i + 1) % tub.size()].x, rim + 0.008, tub[(i + 1) % tub.size()].y)
		var d := (b - a).normalized() * 0.008
		k.strut(a - d, b + d, 0.024)
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.1, 0.05, 0.05), Vector3(sx * hw * 0.45, rim + 0.035, hl * 0.97))
	# Bedding inside: the mattress, a pillow at the head, a folded blanket at the foot.
	var y_m := rim + 0.05                     # top of the mattress
	k.color = POD_MATTRESS
	_seating_pad(k, Vector3(0.0, rim, 0.02), Vector3.RIGHT, Vector3.BACK, Vector3.UP, hw - 0.13, hl - 0.2, 0.05, 0.02)
	k.color = POD_LINEN
	_seating_pad(k, Vector3(0.0, y_m, -hl + 0.36), Vector3.RIGHT, Vector3.BACK, Vector3.UP, hw - 0.22, 0.13, 0.07, 0.03)
	k.color = POD_BLANKET
	_seating_pad(k, Vector3(0.0, y_m, hl - 0.5), Vector3.RIGHT, Vector3.BACK, Vector3.UP, hw - 0.11, 0.28, 0.035, 0.01)
	# The head-end screen: a stalk off the lip, a dark bezel facing the sleeper (+Z).
	var sc := Vector3(0.0, rim + 0.17, -hl + 0.06)
	k.color = DETAIL
	k.box(Vector3(0.08, 0.025, 0.04), Vector3(0.0, rim + 0.03, -hl + 0.06))
	k.color = DARK
	_seating_pad(k, sc, Vector3.RIGHT, Vector3.UP, Vector3.BACK, 0.21, 0.13, 0.04, 0.012)
	_seating_pad(g, sc + Vector3(0.0, 0.0, 0.0395), Vector3.RIGHT, Vector3.UP, Vector3.BACK, 0.17, 0.09, 0.004)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * length * height * 0.35
	var col := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array(lo)
	var top := hh
	for p in tub:
		pts.append(Vector3(p.x, rim, p.y))
		pts.append(Vector3(p.x * 0.7, top, p.y * 0.95))
	col.points = pts
	shape.collision = col
	# The canopy: a low glass lid lofted from the rim up to a flat top.
	var gk := MeshKit.new()
	var r0 := PackedVector3Array()
	var r1 := PackedVector3Array()
	for p in tub:
		r0.append(Vector3(p.x * 0.98, rim + 0.002, p.y * 0.98))
		r1.append(Vector3(p.x * 0.7, top - 0.01, p.y * 0.93))
	gk.loft(r0, r1)
	shape.glass = gk.finish()
	shape.glow = g.finish()
	shape.glow_color = Color(0.4, 0.85, 1.0)
	return shape


# --- Novaris parts (v2) ------------------------------------------------------------------
## A patch of scaled armour (the overlapping grey and white tiles that cover the Novaris'
## roof and stepped flanks): a dense cast backing plate `width` (X) by `length` (Z), `rows` rows
## of tiles across it, each row `cols` tiles wide. Every tile is a wedge whose front (-Z)
## edge sits low and whose aft edge stands `rise` proud, so the rows step like shingles;
## alternate rows are offset half a tile so the seams stagger. Tiles take the material
## colour; with `trim` set (alpha > 0) the outermost +X tile of every row is that colour
## (the blue edging). Each tile's proud aft lip is bevelled and a blackened rivet sits in
## its low front. Face +Y; collision is the panel's box.
static func shingle_panel(width: float = 2.4, length: float = 3.0, rows: int = 4, cols: int = 3,
		trim := Color(0, 0, 0, 0), rise: float = 0.09) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hw := width * 0.5
	var hl := length * 0.5
	var base := 0.03
	var low := 0.025
	var total := base + low + rise
	var y0 := -total * 0.5
	k.color = PNL_ARMOUR_BACK
	k.box(Vector3(width, base, length), Vector3(0.0, y0 + base * 0.5, 0.0))
	var seam := 0.025
	var pitch := length / float(rows)
	var tile_w := width / float(cols)
	for r in rows:
		var z0 := -hl + pitch * float(r) + seam * 0.5
		var z1 := -hl + pitch * float(r + 1) - seam * 0.5
		var yb := y0 + base + 0.002
		# The tile's side outline: low front, its proud aft edge bevelled (a worn lip).
		var ch := minf(rise * 0.4, (z1 - z0) * 0.08)
		var top := yb + low + rise
		var outline := PackedVector2Array([Vector2(z0, yb), Vector2(z1, yb), Vector2(z1, top - ch),
				Vector2(z1 - ch * 1.5, top - rise * ch * 1.5 / (z1 - z0)), Vector2(z0, yb + low)])
		# Seams across X: an offset row starts and ends with half tiles.
		var cuts: Array[float] = [-hw]
		var off := tile_w * 0.5 if r % 2 == 1 else 0.0
		var x := -hw + (tile_w - off if off > 0.0 else tile_w)
		while x < hw - 0.05:
			cuts.append(x)
			x += tile_w
		cuts.append(hw)
		for c in cuts.size() - 1:
			var xa := cuts[c] + (seam * 0.5 if c > 0 else 0.0)
			var xb := cuts[c + 1] - (seam * 0.5 if c < cuts.size() - 2 else 0.0)
			if xb - xa < 0.05:
				continue
			k.color = trim if (trim.a > 0.0 and c == cuts.size() - 2) else Color.WHITE
			_prism_x(k, outline, xa, xb)
			# A rivet in the tile's low front, just behind the row ahead's lip.
			k.color = FLANGE_BOLT
			var rz := z0 + minf(0.07, (z1 - z0) * 0.15)
			_thrusters_bolt(k, Vector3((xa + xb) * 0.5, yb + low + rise * (rz - z0) / (z1 - z0) - 0.003, rz), 0.02, 0.012)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * length * (base + low + rise * 0.5)
	var col := BoxShape3D.new()
	col.size = Vector3(width, total, length)
	shape.collision = col
	return shape


## An L-shaped lounge sofa (the long padded seat round the Novaris' upper lounge): a run
## `length` along X and a return `side` along Z at its +X end, `depth` deep, in the bench's
## language: a dark kick plinth set back under a body in the material colour, a back frame
## along the run's +Z side and the return's +X side with a steel trim rail on top, a slim
## arm at each open end (the run's -X end, the return's -Z tip), chamfered seat and back
## cushions in pale blue-grey (one per ~0.65 m, seams between them), pads on the arms and a
## rust throw pillow leaning in the corner. Stands on -Y; sitters face -Z (run) and -X
## (return). Collision is the hull round both legs.
static func corner_sofa(length: float = 3.0, side: float = 2.0, depth: float = 0.85, height: float = 0.95) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hh := height * 0.5
	var kick := 0.07                            # plinth height, m
	var base_h := 0.32                          # top of the body above the floor, m
	var y0 := -hh + base_h                      # where the seat cushions sit
	var seat_t := 0.13                          # seat cushion thickness, m
	var bt := 0.12                              # back frame thickness, m
	var arm := 0.08                             # arm thickness, m
	var arm_top := minf(y0 + seat_t + 0.14, hh - 0.08)
	# Footprint: the run along X (z from -depth/2 to +depth/2) and the return along -Z from
	# the run's +X end.
	var x0 := -length * 0.5
	var x1 := length * 0.5
	var z_back := depth * 0.5
	var z_front := -depth * 0.5
	var z_tip := z_back - side
	var xi := x1 - bt                           # inner face of the return's back
	var zi := z_back - bt                       # inner face of the run's back
	var xr := x1 - depth                        # the return's front edge
	var yk := -hh + kick
	# The kick plinths, set back under the bodies.
	k.color = DARK
	k.box(Vector3(length - 0.08, kick, depth - 0.08), Vector3(0.0, -hh + kick * 0.5, 0.0))
	k.box(Vector3(depth - 0.08, kick, side - depth), Vector3(x1 - depth * 0.5, -hh + kick * 0.5, (z_front + 0.04 + z_tip + 0.04) * 0.5))
	# Bodies, backs and arms in the material colour.
	k.color = Color.WHITE
	k.box(Vector3(xi - (x0 + arm), base_h - kick, zi - z_front), Vector3((xi + x0 + arm) * 0.5, (yk + y0) * 0.5, (zi + z_front) * 0.5))
	k.box(Vector3(xi - xr, base_h - kick, z_front - (z_tip + arm)), Vector3((xi + xr) * 0.5, (yk + y0) * 0.5, (z_front + z_tip + arm) * 0.5))
	var y_rail := hh - 0.02
	k.box(Vector3(length, y_rail - yk, bt), Vector3(0.0, (y_rail + yk) * 0.5, z_back - bt * 0.5))
	k.box(Vector3(bt, y_rail - yk, zi - z_tip), Vector3(x1 - bt * 0.5, (y_rail + yk) * 0.5, (zi + z_tip) * 0.5))
	k.box(Vector3(arm, arm_top - yk, zi - z_front), Vector3(x0 + arm * 0.5, (arm_top + yk) * 0.5, (zi + z_front) * 0.5))
	k.box(Vector3(xi - xr, arm_top - yk, arm), Vector3((xi + xr) * 0.5, (arm_top + yk) * 0.5, z_tip + arm * 0.5))
	# The steel trim: a rail along the backs' tops and a strip along the bodies' feet.
	k.color = DETAIL
	k.box(Vector3(length, 0.02, bt + 0.01), Vector3(0.0, hh - 0.01, z_back - bt * 0.5 - 0.005))
	k.box(Vector3(bt + 0.01, 0.02, zi - z_tip - 0.01), Vector3(x1 - bt * 0.5 - 0.005, hh - 0.01, (zi + z_tip) * 0.5 - 0.005))
	k.box(Vector3(xi - (x0 + arm), 0.02, 0.004), Vector3((xi + x0 + arm) * 0.5, yk + 0.012, z_front - 0.002))
	k.box(Vector3(0.004, 0.02, z_front - (z_tip + arm)), Vector3(xr - 0.002, yk + 0.012, (z_front + z_tip + arm) * 0.5))
	# Cushions: seats and backs along the run (the corner seat is the run's last), then
	# along the return; the return's backs reach up to the run's back cushions.
	k.color = SOFA_CUSHION
	var yb0 := y0 + seat_t + 0.005
	var yb1 := hh - 0.06
	var back_c := 0.1                           # back cushion thickness, m
	var run := xi - (x0 + arm)
	var n := maxi(1, roundi(run / 0.65))
	var cw := run / float(n)
	for i in n:
		var x := x0 + arm + cw * (float(i) + 0.5)
		_seating_pad(k, Vector3(x, y0, (z_front + zi) * 0.5), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
				cw * 0.5 - 0.006, (zi - z_front) * 0.5 - 0.005, seat_t, 0.03)
		_seating_pad(k, Vector3(x, (yb0 + yb1) * 0.5, zi), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
				cw * 0.5 - 0.006, (yb1 - yb0) * 0.5, back_c, 0.03)
	var ret := z_front - (z_tip + arm)
	if ret > 0.3:
		var m := maxi(1, roundi(ret / 0.65))
		var rw := ret / float(m)
		for i in m:
			var z := z_tip + arm + rw * (float(i) + 0.5)
			_seating_pad(k, Vector3((xr + xi) * 0.5, y0, z), Vector3.BACK, Vector3.RIGHT, Vector3.UP,
					rw * 0.5 - 0.006, (xi - xr) * 0.5 - 0.005, seat_t, 0.03)
	var rb := (zi - back_c) - (z_tip + arm)
	var mb := maxi(1, roundi(rb / 0.65))
	var bw := rb / float(mb)
	for i in mb:
		var z := z_tip + arm + bw * (float(i) + 0.5)
		_seating_pad(k, Vector3(xi, (yb0 + yb1) * 0.5, z), Vector3.BACK, Vector3.UP, Vector3.LEFT,
				bw * 0.5 - 0.006, (yb1 - yb0) * 0.5, back_c, 0.03)
	# Pads on the arms.
	_seating_pad(k, Vector3(x0 + arm * 0.5, arm_top, (zi + z_front) * 0.5), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			arm * 0.5 - 0.005, (zi - z_front) * 0.5 - 0.01, 0.03, 0.012)
	_seating_pad(k, Vector3((xi + xr) * 0.5, arm_top, z_tip + arm * 0.5), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			(xi - xr) * 0.5 - 0.01, arm * 0.5 - 0.005, 0.03, 0.012)
	# A throw pillow leaning back into the corner.
	k.color = SOFA_THROW
	var out := Vector3(-1.0, 0.0, -1.0).normalized()
	var across := Vector3(1.0, 0.0, -1.0).normalized()
	var up := (Vector3.UP - out * 0.4).normalized()
	var pc := Vector3(xi - back_c - 0.13, yb0 + 0.17, zi - back_c - 0.13)
	_seating_pad(k, pc, across, up, up.cross(across), 0.17, 0.15, 0.1, 0.04)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = (length * depth + (side - depth) * depth) * height * 0.5
	var col := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for y: float in [-hh, hh]:
		pts.append(Vector3(x0, y, z_front))
		pts.append(Vector3(x0, y, z_back))
		pts.append(Vector3(x1, y, z_back))
		pts.append(Vector3(x1, y, z_tip))
		pts.append(Vector3(x1 - depth, y, z_tip))
	col.points = pts
	shape.collision = col
	return shape


# --- Race carrier parts (v2) --------------------------------------------------------------

const _PURPLE := Color(0.36, 0.2, 0.62)


## A garage door leaf (the Nexus' two numbered doors, which slide up over the roof to open
## the garages in its flank): a slab `width` along X, `height` along Z and `thickness`
## along Y in the material colour, a rubber seal round its +Y face, raised satin cover
## strips over the panel seams, a gloss purple band across it a little below the middle,
## the `number` in big raised digits above the band (the first digit purple, the rest
## white, like the reference's "01"), bolts round the rim, galvanised roller brackets with
## rubber rollers on the side edges, a hazard band along the foot (+Z) between two
## galvanised latch blocks with a chrome pull handle over it, galvanised stiffening ribs
## across the inside (-Y) and two lamps in plastic housings along the top (-Z) edge
## (PartShape.glow).
## Face +Y; on a hull side turn it
## like a `name_board`: X along the hull, Y out of it, Z down. Collision is its box.
static func garage_door(width: float = 4.4, height: float = 3.9, number: String = "01",
		thickness: float = 0.14) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hw := width * 0.5
	var hh := height * 0.5
	var t := thickness * 0.5
	k.color = Color.WHITE
	k.box(Vector3(width, thickness, height))
	# The rubber seal round the rim, a hair proud of the face.
	k.color = RUBBER
	var rim := 0.1
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(width, 0.012, rim), Vector3(0.0, t + 0.006, s * (hh - rim * 0.5)))
		k.box(Vector3(rim, 0.012, height - 2.0 * rim), Vector3(s * (hw - rim * 0.5), t + 0.006, 0.0))
	# Panel seams: two uprights and a rail, slightly darker strips, proud.
	# (The uprights stop above the hazard band at the foot.)
	var haz := minf(0.16, height * 0.05)
	var haz_z := hh - rim - 0.04 - haz * 0.5
	var seam_z0 := -hh + rim + 0.02
	var seam_z1 := haz_z - haz * 0.5 - 0.04
	k.color = PNL_SEAM_STRIP
	for fx: float in [-0.3, 0.3]:
		k.box(Vector3(0.05, 0.016, seam_z1 - seam_z0), Vector3(fx * width, t + 0.008, (seam_z0 + seam_z1) * 0.5))
	var rail_z := -hh + height * 0.22
	k.box(Vector3(width * 0.6 - 0.06, 0.016, 0.05), Vector3(0.0, t + 0.008, rail_z))
	# The purple band across the door.
	var band_z := hh - height * 0.3
	var band_h := height * 0.09
	k.color = PNL_LIVERY_PURPLE
	k.box(Vector3(width - 2.0 * rim - 0.02, 0.02, band_h), Vector3(0.0, t + 0.01, band_z))
	# The digits, standing proud over the band's top edge.
	var cap := height * 0.3
	var unit := cap / 6.0
	var n := number.length()
	var pitch := unit * 5.4
	var letter_t := 0.07
	var base_z := band_z - band_h * 0.5 - unit * 0.6   # the digits' feet
	for i in n:
		k.color = PNL_LIVERY_PURPLE if i == 0 else PNL_LIVERY_WHITE
		var x0 := -pitch * float(n) * 0.5 + pitch * (float(i) + 0.5) - unit * 2.0
		var parts: Array = _DIGITS.get(number[i], [[0, 0, 4, 6]])
		for piece: Array in parts:
			var outline := PackedVector2Array()
			if piece[0] is Array:
				for q: Array in piece:
					outline.append(Vector2(float(q[0]), float(q[1])))
			else:
				outline = PackedVector2Array([Vector2(piece[0], piece[1]), Vector2(piece[2], piece[1]),
						Vector2(piece[2], piece[3]), Vector2(piece[0], piece[3])])
			var lo := PackedVector3Array()
			var hi := PackedVector3Array()
			for q in outline:
				var p := Vector3(x0 + q.x * unit, 0.0, base_z - q.y * unit)
				lo.append(p + Vector3(0.0, t, 0.0))
				hi.append(p + Vector3(0.0, t + letter_t, 0.0))
			k.loft(lo, hi)
	# Bolts round the rim.
	k.color = DETAIL
	var per_x := maxi(2, int(width / 0.45))
	var per_z := maxi(2, int(height / 0.45))
	for i in per_x + 1:
		var x := -hw + rim * 0.5 + (width - rim) * float(i) / float(per_x)
		for s: float in [-1.0, 1.0]:
			_gear_bolt(k, Vector3(x, t + 0.012, s * (hh - rim * 0.5)), Vector3.UP, 0.018, 0.01)
	for i in range(1, per_z):
		var z := -hh + rim * 0.5 + (height - rim) * float(i) / float(per_z)
		for s: float in [-1.0, 1.0]:
			_gear_bolt(k, Vector3(s * (hw - rim * 0.5), t + 0.012, z), Vector3.UP, 0.018, 0.01)
	# Roller brackets on the side edges (the door runs up its rails on them).
	for i in 4:
		var z := -hh + height * (0.12 + 0.76 * float(i) / 3.0)
		for s: float in [-1.0, 1.0]:
			k.color = GALVANISED
			k.box(Vector3(0.07, 0.04, 0.16), Vector3(s * (hw - rim * 0.5), t + 0.032, z))
			k.color = RUBBER
			k.box(Vector3(0.05, 0.05, 0.07), Vector3(s * (hw - rim * 0.5), t + 0.045, z))
	# The hazard band along the foot (+Z), a latch block at each end of it, a pull handle over it.
	_gear_hazard(k, Vector3(0.0, t, haz_z), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			Vector2(width - 2.0 * rim - 0.5, haz), haz * 0.9)
	k.color = GALVANISED
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(0.12, 0.04, 0.12), Vector3(s * (hw - rim - 0.12), t + 0.02, haz_z))
	k.color = CHROME
	var pull_z := seam_z1 - 0.1
	k.box(Vector3(0.5, 0.05, 0.06), Vector3(0.0, t + 0.025, pull_z))
	k.color = GALVANISED
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(0.05, 0.03, 0.08), Vector3(s * 0.2, t + 0.015, pull_z))
	# Stiffening ribs across the inside face (-Y).
	k.color = GALVANISED
	for f: float in [-0.25, 0.0, 0.25]:
		k.box(Vector3(width - 0.2, 0.02, 0.08), Vector3(0.0, -t - 0.01, f * height))
	# Lamp housings along the top edge.
	k.color = PLASTIC_DARK
	var lamp_z := -hh + rim + 0.12
	for i in 2:
		k.box(Vector3(0.28, 0.025, 0.13), Vector3((-0.25 if i == 0 else 0.25) * width, t + 0.0125, lamp_z))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * thickness
	var col := BoxShape3D.new()
	col.size = Vector3(width, thickness + 2.0 * letter_t, height)
	shape.collision = col
	# Lamps along the top edge.
	var g := MeshKit.new()
	for i in 2:
		var x := (-0.25 if i == 0 else 0.25) * width
		g.box(Vector3(0.22, 0.03, 0.08), Vector3(x, t + 0.015, lamp_z))
	shape.glow = g.finish()
	shape.glow_color = Color(0.95, 0.96, 1.0)
	return shape


## A race ship's body (the blue racer parked in the Nexus' garage 01, the Devastator's
## hangar fighters): a low wedge `length` along Z, `width` across and `height` tall, lofted
## through seven ten-sided sections (a chine down each flank, a narrow top deck) from a
## pointed, low nose (-Z) to a broad tail, in the material colour; dark panel lines round
## it, twin red livery stripes down the deck and one along each forward flank; a glass
## bubble canopy over the middle (PartShape.glass) with a dark windscreen frame and hoop;
## a scoop on each flank with a bright lip round a dark mouth and grille bars; a slatted
## vent on the deck behind the canopy; a dark tail plate with a framed, barred exhaust slot;
## small running lights on the nose and both tail flanks. The exhaust slot and the lights
## glow (PartShape.glow). Stands on -Y. Collision is the hull of the body and canopy.
static func racer_hull(length: float = 4.2, width: float = 2.0, height: float = 1.0) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var hl := length * 0.5
	var hh := height * 0.5
	var y0 := -hh
	# Sections: [fraction along from the nose, half width, bottom, top] (widths of `width`,
	# heights of `height` up from the base).
	var secs: Array = [
		[0.0, 0.10, 0.22, 0.36],
		[0.12, 0.24, 0.16, 0.44],
		[0.28, 0.36, 0.06, 0.56],
		[0.45, 0.46, 0.026, 0.59],
		[0.58, 0.50, 0.0, 0.62],
		[0.80, 0.48, 0.021, 0.60],
		[1.0, 0.44, 0.04, 0.58],
	]
	# One section's ring at fraction f, every point pushed out by `grow`.
	var ring_at := func(f: float, grow: float) -> PackedVector3Array:
		var i := 0
		while i < secs.size() - 2 and f > float(secs[i + 1][0]):
			i += 1
		var a: Array = secs[i]
		var b: Array = secs[i + 1]
		var t := clampf((f - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
		var w := lerpf(float(a[1]), float(b[1]), t) * width
		var lo := y0 + lerpf(float(a[2]), float(b[2]), t) * height
		var hi := y0 + lerpf(float(a[3]), float(b[3]), t) * height
		var d := hi - lo
		var z := -hl + f * length
		var half := [Vector2(0.7 * w, lo), Vector2(w, lo + 0.3 * d), Vector2(0.97 * w, lo + 0.5 * d),
				Vector2(0.78 * w, hi - 0.12 * d), Vector2(0.45 * w, hi)]
		var pts: Array[Vector2] = []
		for p: Vector2 in half:
			pts.append(p)
		for j in range(half.size() - 1, -1, -1):
			pts.append(Vector2(-half[j].x, half[j].y))
		var mid := Vector2(0.0, (lo + hi) * 0.5)
		var out := PackedVector3Array()
		for p in pts:
			var q := p + (p - mid).normalized() * grow
			out.append(Vector3(q.x, q.y, z))
		return out
	var rings: Array[PackedVector3Array] = []
	for sc: Array in secs:
		rings.append(ring_at.call(float(sc[0]), 0.0))
	k.color = Color.WHITE
	for i in rings.size() - 1:
		k.loft(rings[i], rings[i + 1], false)
	k.poly(rings[0], Vector3.FORWARD)
	k.poly(rings[rings.size() - 1], Vector3.BACK)
	# Dark panel lines round the body ahead of the canopy and behind the scoops.
	k.color = DARK
	var dl := 0.008 / length
	for f: float in [0.2, 0.84]:
		k.loft(ring_at.call(f - dl, 0.003), ring_at.call(f + dl, 0.003), false)
	# Livery: twin stripes down the top deck (they run on under the canopy glass), one
	# along each flank above the chine from the nose back to the scoop.
	k.color = LIVERY
	for i in rings.size() - 1:
		var ra: PackedVector3Array = rings[i]
		var rb: PackedVector3Array = rings[i + 1]
		for sx: float in [-1.0, 1.0]:
			var pa := Vector2(ra[4].x, ra[4].y)   # the deck's edge (0.45 w)
			var pb := Vector2(rb[4].x, rb[4].y)
			var quad := PackedVector3Array()
			for e: Vector2 in [Vector2(0.38, 0.0), Vector2(0.7, 0.0), Vector2(0.7, 1.0), Vector2(0.38, 1.0)]:
				var p := pa if e.y == 0.0 else pb
				var z := ra[0].z if e.y == 0.0 else rb[0].z
				quad.append(Vector3(sx * p.x * e.x, p.y + 0.004, z))
			k.poly(quad, Vector3.UP)
	var scoop_f := 0.45
	for i in 3:
		var ra: PackedVector3Array = rings[i]
		var rb: PackedVector3Array = rings[i + 1]
		for side in 2:
			var j0 := 1 if side == 0 else 8      # chine point
			var j1 := 2 if side == 0 else 7      # the point above it
			var o := Vector3(0.004 if side == 0 else -0.004, 0.0, 0.0)
			var quad := PackedVector3Array([ra[j0].lerp(ra[j1], 0.3) + o, ra[j0].lerp(ra[j1], 0.8) + o,
					rb[j0].lerp(rb[j1], 0.8) + o, rb[j0].lerp(rb[j1], 0.3) + o])
			k.poly(quad, o)
	# A scoop on each flank: a wedge fairing from a mouth at scoop_f back into the side, a
	# bright lip round a dark mouth, grille bars across it.
	var fb := 0.74
	var za := -hl + scoop_f * length
	var zb := -hl + fb * length
	var wa := float(secs[3][1]) * width
	var wbk := lerpf(float(secs[4][1]), float(secs[5][1]), (fb - 0.58) / 0.22) * width
	var ya := y0 + height * 0.2
	var yb := y0 + height * 0.42
	var xo := width * 0.5 + 0.03
	var xi := wa * 0.82
	for sx: float in [-1.0, 1.0]:
		k.color = Color.WHITE
		var fa_r := PackedVector3Array([Vector3(sx * xi, ya, za), Vector3(sx * xo, ya, za), Vector3(sx * xo, yb, za),
				Vector3(sx * xi, yb, za)])
		var fb_r := PackedVector3Array([Vector3(sx * wbk * 0.8, ya + height * 0.03, zb), Vector3(sx * wbk * 0.95, ya + height * 0.03, zb),
				Vector3(sx * wbk * 0.93, yb - height * 0.03, zb), Vector3(sx * wbk * 0.8, yb - height * 0.03, zb)])
		k.loft(fa_r, fb_r)
		var mx := sx * (xi + xo) * 0.5
		var mw := xo - xi
		var my := (ya + yb) * 0.5
		var mh := yb - ya
		k.color = DARK
		k.box(Vector3(mw - 0.03, mh - 0.03, 0.008), Vector3(mx, my, za - 0.004))
		k.color = TRIM
		for sy: float in [-1.0, 1.0]:
			k.box(Vector3(mw, 0.016, 0.012), Vector3(mx, my + sy * (mh * 0.5 - 0.008), za - 0.006))
		for e: float in [-1.0, 1.0]:
			k.box(Vector3(0.016, mh, 0.012), Vector3(mx + e * (mw * 0.5 - 0.008), my, za - 0.006))
		k.color = DETAIL
		for i in 3:
			var gx := mx + (float(i) - 1.0) * mw * 0.24
			k.box(Vector3(0.012, mh - 0.04, 0.008), Vector3(gx, my, za - 0.012))
		for i in 2:
			k.box(Vector3(mw - 0.04, 0.01, 0.006), Vector3(mx, my + (float(i) - 0.5) * mh * 0.36, za - 0.011))
	# A slatted vent on the deck behind the canopy.
	var vf0 := 0.7
	var vf1 := 0.78
	var vtop := y0 + height * lerpf(0.6083, 0.6011, 0.5)
	var vw := width * 0.48 * 0.45 * 0.7
	k.color = DARK
	k.box(Vector3(vw * 2.0, 0.01, (vf1 - vf0) * length), Vector3(0.0, vtop + 0.001, -hl + (vf0 + vf1) * 0.5 * length))
	k.color = DETAIL
	for i in 4:
		var vz := -hl + lerpf(vf0, vf1, (float(i) + 0.5) / 4.0) * length
		k.box(Vector3(vw * 2.0 - 0.03, 0.012, 0.025), Vector3(0.0, vtop + 0.008, vz))
	# The dark tail plate, a bright frame round the exhaust slot and bars across it.
	var tail_lo := y0 + float(secs[6][2]) * height
	var tail_hi := y0 + float(secs[6][3]) * height
	var ty := (tail_lo + tail_hi) * 0.5
	var sh := (tail_hi - tail_lo) * 0.22
	var sw := width * 0.3
	k.color = DARK
	k.box(Vector3(width * 0.62, (tail_hi - tail_lo) * 0.5, 0.03), Vector3(0.0, ty, hl + 0.015))
	k.color = TRIM
	for sy: float in [-1.0, 1.0]:
		k.box(Vector3(sw + 0.04, 0.02, 0.006), Vector3(0.0, ty + sy * (sh * 0.5 + 0.01), hl + 0.033))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.02, sh + 0.04, 0.006), Vector3(sx * (sw * 0.5 + 0.01), ty, hl + 0.033))
	k.color = DETAIL
	for i in 3:
		k.box(Vector3(0.014, sh, 0.008), Vector3((float(i) - 1.0) * sw * 0.26, ty, hl + 0.046))
	# Running lights: one in the nose, one on each flank at the tail, in dark bezels.
	var r0: PackedVector3Array = rings[0]
	var ny := (r0[0].y + r0[4].y) * 0.5
	k.color = DARK
	k.box(Vector3(0.09, 0.05, 0.004), Vector3(0.0, ny, -hl - 0.002))
	g.box(Vector3(0.06, 0.03, 0.004), Vector3(0.0, ny, -hl - 0.005))
	var rt: PackedVector3Array = rings[6]
	for side in 2:
		var p := rt[2] if side == 0 else rt[7]
		var sx := 1.0 if side == 0 else -1.0
		var lp := Vector3(p.x - sx * 0.006, p.y, hl - 0.07)
		k.color = DARK
		k.box(Vector3(0.012, 0.05, 0.1), lp + Vector3(sx * 0.004, 0.0, 0.0))
		g.box(Vector3(0.008, 0.03, 0.07), lp + Vector3(sx * 0.009, 0.0, 0.0))
	# The canopy: a glass bubble lofted through arches along Z from a low front to a short
	# tail, its foot sunk into the deck; a dark frame round the windscreen and a hoop.
	var base_y := y0 + height * 0.56
	var cz0 := -hl + length * 0.3
	var cz1 := -hl + length * 0.68
	var cw := width * 0.24
	var hc := hh - base_y
	var arch := func(s: float, f: float, gh: float, grow: float) -> PackedVector3Array:
		var z := lerpf(cz0, cz1, s)
		var fw := f * cw + grow
		var gt := gh * hc + grow
		var ps := [Vector2(fw, 0.0), Vector2(fw, 0.45 * gt), Vector2(0.75 * fw, 0.85 * gt), Vector2(0.35 * fw, gt)]
		var out := PackedVector3Array()
		for p: Vector2 in ps:
			out.append(Vector3(p.x, base_y + p.y, z))
		for j in range(ps.size() - 1, -1, -1):
			out.append(Vector3(-ps[j].x, base_y + ps[j].y, z))
		return out
	var cs := [[0.0, 0.35, 0.05], [0.25, 0.85, 0.65], [0.5, 1.0, 1.0], [0.78, 0.9, 0.85], [1.0, 0.5, 0.25]]
	var arches: Array[PackedVector3Array] = []
	for c: Array in cs:
		arches.append(arch.call(float(c[0]), float(c[1]), float(c[2]), 0.0))
	var gk := MeshKit.new()
	for i in arches.size() - 1:
		gk.loft(arches[i], arches[i + 1], false)
	gk.poly(arches[0], Vector3.FORWARD)
	gk.poly(arches[arches.size() - 1], Vector3.BACK)
	k.color = DARK
	for ci: int in [1, 2]:
		var c: Array = cs[ci]
		var fr: PackedVector3Array = arch.call(float(c[0]), float(c[1]), float(c[2]), 0.004)
		for j in range(fr.size() - 1):
			k.strut(fr[j], fr[j + 1], 0.024)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.glass = gk.finish()
	shape.volume = length * width * height * 0.38
	var pts := PackedVector3Array()
	for r in rings:
		pts.append_array(r)
	pts.append_array(arches[2])
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	g.box(Vector3(sw, sh, 0.012), Vector3(0.0, ty, hl + 0.036))
	shape.glow = g.finish()
	shape.glow_color = Color(0.45, 0.7, 1.0)
	return shape


# --- Railgun ship parts (v2, the Galaxy) ---------------------------------------------------

## Rings of `outline` (x, z points round Y) at each of `stations` ([y, scale] pairs, in
## order along Y either way), lofted one to the next (segment i in `colors[i]`, the last
## repeating) and capped at both ends: collars, sleeves and chamfered blocks. `at` moves it.
static func _railgun_stack(k: MeshKit, outline: PackedVector2Array, stations: Array, colors: Array[Color],
		at: Vector3 = Vector3.ZERO) -> void:
	var rings: Array[PackedVector3Array] = []
	for st: Array in stations:
		var y: float = st[0]
		var s: float = st[1]
		var ring := PackedVector3Array()
		for p in outline:
			ring.append(at + Vector3(p.x * s, y, p.y * s))
		rings.append(ring)
	var dir := signf(float(stations[stations.size() - 1][0]) - float(stations[0][0]))
	for i in rings.size() - 1:
		k.color = colors[mini(i, colors.size() - 1)]
		if i == 0:
			k.poly(rings[0], Vector3.DOWN * dir)
		k.loft(rings[i], rings[i + 1], false)
	k.poly(rings[rings.size() - 1], Vector3.UP * dir)


## A raised plate on a flat face: the quad `q` (corners in order round) shrunk about its
## middle by `f`, rising `proud` off the face along the face normal that agrees with `out`,
## its foot sunk 2 mm in. Armour panels, vent slats and lamps on sloped faces.
static func _railgun_slab(k: MeshKit, q: PackedVector3Array, out: Vector3, f: float, proud: float) -> void:
	var c := (q[0] + q[1] + q[2] + q[3]) * 0.25
	var n := (q[1] - q[0]).cross(q[3] - q[0]).normalized()
	if n.dot(out) < 0.0:
		n = -n
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for p in q:
		var s := c + (p - c) * f
		a.append(s - n * 0.002)
		b.append(s + n * proud)
	k.loft(a, b)


## The part of quad `q` between fractions `u0`..`u1` (along q0 -> q1) and `v0`..`v1`
## (along q0 -> q3), as a quad in the same order.
static func _railgun_sub(q: PackedVector3Array, u0: float, u1: float, v0: float, v1: float) -> PackedVector3Array:
	var at := func(u: float, v: float) -> Vector3:
		return q[0].lerp(q[1], u).lerp(q[3].lerp(q[2], u), v)
	return PackedVector3Array([at.call(u0, v0), at.call(u1, v0), at.call(u1, v1), at.call(u0, v1)])


## The outward normal of quad `q`'s face, the one that agrees with `out`.
static func _railgun_normal(q: PackedVector3Array, out: Vector3) -> Vector3:
	var n := (q[1] - q[0]).cross(q[3] - q[0]).normalized()
	return n if n.dot(out) >= 0.0 else -n


## A length of railgun barrel (the Galaxy's spinal railgun, laid down its roof in bay-long
## sections): a dark square core `width` across and `height` tall running `length` along Y,
## two heavy chamfered rails in the material colour down its sides (±X) with bare copper
## conductor strips along the bore slot between them, a pale bore cover with seams over the
## slot (-Z), rows of clamp bolts down the rails, `coils` octagonal coil collars with
## chamfered ends, dark lips, bolts on their corners and a glowing blue window on each flat
## (PartShape.glow), and a chamfered bolted flange at each end where the sections butt
## together. Collision is the box round the collars.
static func rail_barrel(length: float = 4.0, width: float = 0.7, height: float = 0.6, coils: int = 3) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var h := length * 0.5
	var flange := 0.08
	var cw := width * 1.3      # collars stand proud of the rails
	var ch := height * 1.3
	var run := length - 2.0 * flange
	var hr := run * 0.5
	var bs := clampf(width * 0.05, 0.022, 0.04)   # bolt heads, m
	# The flanges at both ends (the same size as ever: sections butt on them), chamfered,
	# with a ring of bolt heads on their inner faces.
	var fo := PartShapes._chamfer_rect(width * 1.15, height * 1.15, minf(width, height) * 0.12)
	var fbolts: Array[Vector2] = [Vector2(width * 0.535, height * 0.28), Vector2(width * 0.535, -height * 0.28),
			Vector2(-width * 0.535, height * 0.28), Vector2(-width * 0.535, -height * 0.28),
			Vector2(width * 0.34, height * 0.537), Vector2(-width * 0.34, height * 0.537), Vector2(0.0, height * 0.537),
			Vector2(width * 0.34, -height * 0.537), Vector2(-width * 0.34, -height * 0.537), Vector2(0.0, -height * 0.537)]
	for sy: float in [-1.0, 1.0]:
		_railgun_stack(k, fo, [[sy * h, 1.0], [sy * (h - flange), 1.0]], [DETAIL])
		k.color = DETAIL
		for b in fbolts:
			_piping_bolts(k, Vector3(b.x, sy * (h - flange), b.y), Vector3.UP * -sy, 0.0, 1, 0.0, bs, bs * 0.45)
	# The core and the two rails either side of the bore slot, their outer corners chamfered.
	k.color = DARK
	k.box(Vector3(width * 0.36, run, height * 0.9), Vector3.ZERO)
	var rc := width * 0.06
	for sx: float in [-1.0, 1.0]:
		var xi := sx * width * 0.19
		var xo := sx * width * 0.49
		var xc := sx * (width * 0.49 - rc)
		var rail := PackedVector2Array([Vector2(xi, -height * 0.5), Vector2(xc, -height * 0.5), Vector2(xo, -height * 0.5 + rc),
				Vector2(xo, height * 0.5 - rc), Vector2(xc, height * 0.5), Vector2(xi, height * 0.5)])
		_railgun_stack(k, rail, [[-hr, 1.0], [hr, 1.0]], [Color.WHITE])
		# Bare copper conductor strips along the slot's edges, on the rails' tops.
		k.color = COPPER
		k.box(Vector3(0.025, run, 0.008), Vector3(sx * (width * 0.19 + 0.0155), 0.0, -height * 0.5 - 0.004))
	# The pale bore cover sunk between the rails, dark seams across it between the collars.
	k.color = COVER
	k.box(Vector3(width * 0.3, run, 0.04), Vector3(0.0, 0.0, -height * 0.45 - 0.02))
	k.color = DARK
	for j in range(1, coils):
		k.box(Vector3(width * 0.3 + 0.004, 0.02, 0.004), Vector3(0.0, -hr + run * float(j) / float(coils), -height * 0.45 - 0.042))
	# Clamp bolts down the rails' outer faces, between the collars and by the flanges.
	var bolt_y: Array[float] = [-hr + 0.12, hr - 0.12]
	for j in range(1, coils):
		bolt_y.append(-hr + run * float(j) / float(coils))
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for y in bolt_y:
			for sz: float in [-1.0, 1.0]:
				_piping_bolts(k, Vector3(sx * width * 0.49, y, sz * height * 0.25), Vector3.RIGHT * sx, 0.0, 1, 0.0, bs, bs * 0.4)
	# The coil collars: octagonal, chamfered both ends, dark lips each side, two bolts on each
	# corner and a lit window in a dark bezel on each flat.
	var co := minf(cw, ch) * 0.28
	var oct := PartShapes._chamfer_rect(cw, ch, co)
	var collar := minf(0.36, run / float(maxi(coils, 1)) * 0.4)
	var lip := 0.03
	var e := minf(0.03, collar * 0.15)
	var wy := collar * 0.3
	for i in coils:
		var y := -hr + run * (float(i) + 0.5) / float(coils)
		var y0 := y - collar * 0.5
		var y1 := y + collar * 0.5
		_railgun_stack(k, oct, [[y0 - lip, 0.92], [y0, 0.92], [y0 + e, 1.0], [y1 - e, 1.0], [y1, 0.92], [y1 + lip, 0.92]],
				[DARK, DETAIL, DETAIL, DETAIL, DARK])
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var n := Vector3(sx, 0.0, sz).normalized()
				for sy: float in [-1.0, 1.0]:
					_piping_bolts(k, Vector3(sx * (cw * 0.5 - co * 0.5), y + sy * collar * 0.28, sz * (ch * 0.5 - co * 0.5)), n,
							0.0, 1, 0.0, bs, bs * 0.4)
		var lx := (ch - 2.0 * co) * 0.6
		var lz := (cw - 2.0 * co) * 0.6
		for s: float in [-1.0, 1.0]:
			k.color = DARK
			k.box(Vector3(0.004, wy + 0.03, lx + 0.03), Vector3(s * (cw * 0.5 + 0.002), y, 0.0))
			k.box(Vector3(lz + 0.03, wy + 0.03, 0.004), Vector3(0.0, y, s * (ch * 0.5 + 0.002)))
			g.box(Vector3(0.004, wy, lx), Vector3(s * (cw * 0.5 + 0.005), y, 0.0))
			g.box(Vector3(lz, wy, 0.004), Vector3(0.0, y, s * (ch * 0.5 + 0.005)))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * length * 0.7
	var col := BoxShape3D.new()
	col.size = Vector3(cw * 1.02, length, ch * 1.02)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = Color(0.35, 0.7, 1.0)
	return shape


## The railgun's muzzle (the Galaxy's bow, head on: a red-lit bore in the middle of the
## nose): an octagonal housing `width` across tapering over `length` along Y from a bolted
## mount flange (-Y) to a thick dark rim round its +Y face, with a dark band round its
## waist, raised armour panels on its flats, vent slats on its corners and a red warning
## lamp on each side (±X); in the recessed face a raised hexagonal collar round a deep bore
## showing the copper rail ends, a red glow ring on the collar (PartShape.glow) and dark
## guide vanes across the face above and below it. Muzzle toward +Y.
static func rail_muzzle(width: float = 1.4, length: float = 1.2, glow := Color(1.0, 0.15, 0.1)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var h := length * 0.5
	var flange := 0.1
	var hw := width * 0.5
	# The mount flange, its corners cut less than the housing's: a bolt in each corner.
	_railgun_stack(k, PartShapes._chamfer_rect(width * 1.05, width * 1.05, width * 0.12), [[-h, 1.0], [-h + flange, 1.0]], [DETAIL])
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_piping_bolts(k, Vector3(sx * width * 0.41, -h + flange, sz * width * 0.41), Vector3.UP, 0.0, 1, 0.0,
					width * 0.05, width * 0.02)
	# The housing: a taper with a dark band round its waist standing a little proud.
	var back := PartShapes._chamfer_rect(width, width, width * 0.3)
	var y0 := -h + flange
	var y1 := h - 0.12
	var taper := func(y: float) -> float: return lerpf(1.0, 0.82, (y - y0) / (y1 - y0))
	var yb0 := lerpf(y0, y1, 0.22)
	var yb1 := yb0 + length * 0.06
	_railgun_stack(k, back, [[y0, 1.0], [yb0, taper.call(yb0)], [yb0 + 0.01, taper.call(yb0 + 0.01) * 1.012],
			[yb1 - 0.01, taper.call(yb1 - 0.01) * 1.012], [yb1, taper.call(yb1)], [y1, 0.82]],
			[Color.WHITE, DARK, DARK, DARK, Color.WHITE])
	# The dark rim round the face.
	_railgun_stack(k, back, [[y1, 0.82], [h, 0.82 * 0.94]], [DARK])
	# The housing's faces: armour panels on the flats, vent slats on the corners, a red lamp
	# in a dark bezel near the front of each side.
	var vb := (yb1 + 0.03 - y0) / (y1 - y0)
	for i in 8:
		var j := (i + 1) % 8
		var q := PackedVector3Array([Vector3(back[i].x, y0, back[i].y), Vector3(back[j].x, y0, back[j].y),
				Vector3(back[j].x * 0.82, y1, back[j].y * 0.82), Vector3(back[i].x * 0.82, y1, back[i].y * 0.82)])
		var mid := (back[i] + back[j]) * 0.5
		var out := Vector3(mid.x, 0.0, mid.y)
		if i % 2 == 0:
			k.color = Color.WHITE
			_railgun_slab(k, _railgun_sub(q, 0.12, 0.88, vb, 0.8), out, 1.0, 0.015)
			if absf(mid.x) > absf(mid.y):
				var lamp := _railgun_sub(q, 0.36, 0.64, 0.85, 0.93)
				k.color = DARK
				_railgun_slab(k, lamp, out, 1.0, 0.008)
				_railgun_slab(g, lamp, out, 0.75, 0.013)
		else:
			k.color = DARK
			for s in 3:
				var v := vb + 0.08 + 0.17 * float(s)
				_railgun_slab(k, _railgun_sub(q, 0.2, 0.8, v, v + 0.07), out, 1.0, 0.006)
	# The bore: a raised hexagonal collar, the dark bore inside it with the copper rail ends.
	var bore := hw * 0.36
	_piping_spin(k, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(bore * 1.38, h - 0.005), Vector2(bore * 1.38, h + 0.02),
			Vector2(bore, h + 0.02), Vector2(bore, h - 0.005)]), [RIM] as Array[Color], 6)
	var hex := PackedVector2Array()
	for i in 6:
		var ang := TAU * float(i) / 6.0
		hex.append(Vector2(cos(ang) * bore * 1.01, -sin(ang) * bore * 1.01))
	_railgun_stack(k, hex, [[h - 0.01, 1.0], [h + 0.004, 1.0]], [RAIL_BORE])
	k.color = COPPER
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(bore * 0.22, 0.012, bore * 0.8), Vector3(sx * bore * 0.58, h + 0.01, 0.0))
	# Guide vanes across the face, stepping in, above and below the bore.
	k.color = RIM
	for sz: float in [-1.0, 1.0]:
		for i in 3:
			var z := sz * (bore + 0.06 + 0.07 * float(i))
			k.box(Vector3(hw * 0.9 - 0.04 * float(i) * 2.0, 0.04, 0.035), Vector3(0.0, h + 0.02, z))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * width * length * 0.6
	var pts := PackedVector3Array()
	for p in back:
		pts.append(Vector3(p.x * 1.05, -h, p.y * 1.05))
		pts.append(Vector3(p.x, y0, p.y))
	for p in PartShapes._scaled(back, 0.82):
		pts.append(Vector3(p.x, h + 0.04, p.y))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	# The red glow ring on the collar round the bore.
	var rr := bore * 1.19
	for i in 6:
		var a0 := TAU * float(i) / 6.0
		var a1 := TAU * float(i + 1) / 6.0
		g.strut(Vector3(cos(a0) * rr, h + 0.028, -sin(a0) * rr), Vector3(cos(a1) * rr, h + 0.028, -sin(a1) * rr), 0.02)
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A bank of railgun capacitors (the blue-lit blocks seen through the Galaxy's engineering
## window): a dark frame `width` along X, `height` tall and `depth` deep on a recessed plinth
## with a hazard-striped kick plate, front posts and a lipped shelf, holding two rows of
## round capacitor cans in the material colour across its front (-Z): each can on a dark
## base ring, a glowing blue band round it (PartShape.glow), a shoulder and a red and a copper
## terminal on top, the copper ones joined by a bus bar; a bolted retaining strap across each
## row, a copper terminal bar and a high-voltage plate along the top front, louvres on the
## ends and a status panel with a lit readout and three LEDs on the +X end. Stands on -Y,
## front -Z.
static func capacitor_bank(width: float = 1.6, height: float = 1.9, depth: float = 0.7) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var hw := width * 0.5
	var hh := height * 0.5
	var hd := depth * 0.5
	var plinth := 0.12
	# The plinth, set back for a toe recess, with a hazard-striped kick plate in it.
	k.color = DARK
	k.box(Vector3(width, plinth, depth - 0.05), Vector3(0.0, -hh + plinth * 0.5, 0.025))
	var stripes := maxi(4, int(width / 0.16))
	var sp := (width - 0.2) / float(stripes)
	k.color = PartShapes.ACCENT
	for i in stripes:
		if i % 2 == 0:
			k.box(Vector3(sp, plinth * 0.5, 0.006), Vector3(-hw + 0.1 + sp * (float(i) + 0.5), -hh + plinth * 0.5, -hd + 0.05 - 0.003))
	# The frame: a back panel, two end panels and a top.
	k.color = BANK_FRAME
	k.box(Vector3(width, height - plinth, 0.08), Vector3(0.0, plinth * 0.5, hd - 0.04))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.08, height - plinth, depth - 0.08), Vector3(sx * (hw - 0.04), plinth * 0.5, -0.04))
		# A front post standing proud of the end panel's front edge, inward.
		k.box(Vector3(0.05, height - plinth - 0.1, 0.04), Vector3(sx * (hw - 0.105), plinth * 0.5 - 0.05, -hd + 0.02))
	k.box(Vector3(width - 0.16, 0.1, depth - 0.08), Vector3(0.0, hh - 0.05, -0.04))
	# Louvres on both ends (low on +X, under the status panel).
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		var top := hh - 0.25 if sx < 0.0 else hh - 0.65
		var n := int((top - (-hh + plinth + 0.2)) / 0.09)
		for i in n:
			k.box(Vector3(0.008, 0.035, depth * 0.5), Vector3(sx * (hw + 0.004), top - 0.09 * float(i), -0.04))
	# A shelf between the two rows, with a steel lip.
	var inner_h := height - plinth - 0.1
	var mid_y := -hh + plinth + inner_h * 0.5
	k.color = BANK_FRAME
	k.box(Vector3(width - 0.16, 0.05, depth - 0.12), Vector3(0.0, mid_y, -0.02))
	k.color = DETAIL
	k.box(Vector3(width - 0.16 - 0.1, 0.03, 0.02), Vector3(0.0, mid_y, -hd + 0.03))
	# The cans: upright cylinders, two rows, banded.
	var cols := maxi(2, int((width - 0.16) / 0.36))
	var pitch := (width - 0.16) / float(cols)
	var r := minf(pitch * 0.4, (depth - 0.12) * 0.42)
	var can_h := inner_h * 0.5 - 0.1
	var z := -0.04
	var post := 0.012
	for row in 2:
		var yb := -hh + plinth + (0.0 if row == 0 else inner_h * 0.5 + 0.025) + 0.02
		var y_top := yb + can_h
		for c in cols:
			var x := -hw + 0.08 + pitch * (float(c) + 0.5)
			k.color = Color.WHITE
			_tube(k, Vector3(x, yb + 0.03, z), Vector3(x, y_top - 0.015, z), r, 12)
			k.color = DARK
			_tube(k, Vector3(x, yb, z), Vector3(x, yb + 0.03, z), r * 1.04, 12)
			k.color = CELL
			_tube(k, Vector3(x, y_top - 0.015, z), Vector3(x, y_top + 0.012, z), r * 0.97, 12)
			k.color = TERMINAL_RED
			k.box(Vector3(r * 0.32, post, r * 0.32), Vector3(x, y_top + 0.012 + post * 0.5, z - r * 0.45))
			k.color = COPPER
			k.box(Vector3(r * 0.32, post, r * 0.32), Vector3(x, y_top + 0.012 + post * 0.5, z + r * 0.45))
			_tube(g, Vector3(x, yb + can_h * 0.55, z), Vector3(x, yb + can_h * 0.62, z), r + 0.01, 12)
		# The copper bus bar over the back terminals, and the retaining strap across the front.
		k.color = COPPER
		k.box(Vector3(pitch * float(cols - 1) + r * 0.4, 0.006, r * 0.2),
				Vector3(-hw + 0.08 + pitch * float(cols) * 0.5, y_top + 0.012 + post + 0.003, z + r * 0.45))
		k.color = DARK
		var strap_y := yb + can_h * 0.25
		k.box(Vector3(width - 0.16 - 0.1, 0.05, 0.02), Vector3(0.0, strap_y, z - r - 0.012))
		k.color = DETAIL
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(0.03, 0.03, 0.012), Vector3(sx * (hw - 0.16), strap_y, z - r - 0.028))
	# The terminal bar across the top front, on two dark stand-offs, and a high-voltage plate.
	k.color = COPPER
	k.box(Vector3(width - 0.3, 0.06, 0.06), Vector3(0.0, hh - 0.14, -hd + 0.06))
	k.color = DARK
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.05, 0.05, 0.03), Vector3(sx * (hw - 0.2), hh - 0.14, -hd + 0.105))
	var plate_w := minf(0.36, width * 0.25)
	k.color = PartShapes.ACCENT
	k.box(Vector3(plate_w, 0.07, 0.006), Vector3(0.0, hh - 0.05, -hd - 0.003))
	k.color = DARK
	k.strut(Vector3(0.025, hh - 0.025, -hd - 0.007), Vector3(-0.01, hh - 0.052, -hd - 0.007), 0.01)
	k.strut(Vector3(-0.01, hh - 0.052, -hd - 0.007), Vector3(0.012, hh - 0.05, -hd - 0.007), 0.01)
	k.strut(Vector3(0.012, hh - 0.05, -hd - 0.007), Vector3(-0.022, hh - 0.077, -hd - 0.007), 0.01)
	# The status panel on the +X end: a bezel, a lit readout and three LEDs under it.
	k.color = DARK
	k.box(Vector3(0.02, 0.3, 0.24), Vector3(hw + 0.01, hh - 0.4, -0.1))
	g.box(Vector3(0.012, 0.12, 0.16), Vector3(hw + 0.026, hh - 0.37, -0.1))
	for i in 3:
		g.box(Vector3(0.012, 0.022, 0.022), Vector3(hw + 0.026, hh - 0.495, -0.16 + 0.06 * float(i)))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * depth * 0.5
	var col := BoxShape3D.new()
	col.size = Vector3(width + 0.06, height, depth)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = Color(0.3, 0.6, 1.0)
	return shape


# --- Cruiser parts (v2, the Devastator) -------------------------------------------------

## A heavy naval gun turret (the Devastator's large-calibre roof guns): an octagonal
## barbette `width` across with a dark band and bolts above and below it, a long low gun
## house that narrows toward its roof and slopes down at the front, with raised cheek armour
## on its sides, a bolted mantlet on the glacis, vent slats and two red lamps in its back
## (PartShape.glow in `glow`), a commander's sight block with a lit lens, a periscope, a
## round hatch, vents and a rangefinder bar across the roof; two long square barrels, each
## out of a dark blast boot through an angular shroud with a clamp band, two clamp bands on
## the barrel and a muzzle block with side slots and a dark muzzle slot. Stands on -Y,
## barrels toward -Z; `barrel` is how far they reach past the gun house's front.
static func naval_turret(width: float = 3.0, barrel: float = 5.0, glow := Color(1.0, 0.18, 0.1)) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var hw := width * 0.5
	var base_h := width * 0.12
	var house_h := width * 0.3
	var total := base_h + house_h
	var y0 := -total * 0.5
	var bs := width * 0.025                      # bolt heads, m
	# The barbette: an octagonal ring, a dark band round its middle, bolts above and below.
	k.color = DETAIL
	var oct_lo := PackedVector3Array()
	var oct_hi := PackedVector3Array()
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		oct_lo.append(Vector3(cos(a) * hw * 0.88, y0, sin(a) * hw * 0.88))
		oct_hi.append(Vector3(cos(a) * hw * 0.88, y0 + base_h, sin(a) * hw * 0.88))
	k.loft(oct_lo, oct_hi)
	k.color = DARK
	var band_lo := PackedVector3Array()
	var band_hi := PackedVector3Array()
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		band_lo.append(Vector3(cos(a) * (hw * 0.88 + 0.012), y0 + base_h * 0.4, sin(a) * (hw * 0.88 + 0.012)))
		band_hi.append(Vector3(cos(a) * (hw * 0.88 + 0.012), y0 + base_h * 0.62, sin(a) * (hw * 0.88 + 0.012)))
	k.loft(band_lo, band_hi)
	k.color = DETAIL
	for i in 8:
		var j := (i + 1) % 8
		var face := PackedVector3Array([oct_lo[i], oct_lo[j], oct_hi[j], oct_hi[i]])
		var n := _railgun_normal(face, (oct_lo[i] + oct_lo[j]) * 0.5)
		for v: float in [0.2, 0.82]:
			_piping_bolts(k, _railgun_sub(face, 0.5, 0.5, v, v)[0], n, 0.0, 1, 0.0, bs, bs * 0.4)
	# The gun house: a long angular block, narrower on top, its front sloping down.
	k.color = Color.WHITE
	var hy := y0 + base_h
	var top := hy + house_h
	var hl := width * 0.62
	var lo := PackedVector3Array([Vector3(-hw, hy, -hl * 0.8), Vector3(hw, hy, -hl * 0.8), Vector3(hw, hy, hl), Vector3(-hw, hy, hl)])
	var hi := PackedVector3Array([Vector3(-hw * 0.72, top, -hl * 0.3), Vector3(hw * 0.72, top, -hl * 0.3),
			Vector3(hw * 0.72, top, hl * 0.86), Vector3(-hw * 0.72, top, hl * 0.86)])
	k.loft(lo, hi)
	# Cheek armour: two raised panels on each sloping side.
	for sx: float in [-1.0, 1.0]:
		var a := 1 if sx > 0.0 else 0
		var b := 2 if sx > 0.0 else 3
		var face := PackedVector3Array([lo[a], lo[b], hi[b], hi[a]])
		var out := Vector3(sx, 0.0, 0.0)
		k.color = Color.WHITE
		_railgun_slab(k, _railgun_sub(face, 0.05, 0.47, 0.12, 0.86), out, 1.0, width * 0.01)
		_railgun_slab(k, _railgun_sub(face, 0.53, 0.95, 0.12, 0.86), out, 1.0, width * 0.01)
	# The back: vent slats and a red lamp in a dark bezel at each upper corner.
	var back := PackedVector3Array([lo[3], lo[2], hi[2], hi[3]])
	k.color = DARK
	for s in 4:
		var v := 0.18 + 0.14 * float(s)
		_railgun_slab(k, _railgun_sub(back, 0.2, 0.8, v, v + 0.07), Vector3.BACK, 1.0, 0.01)
	for u: Vector2 in [Vector2(0.06, 0.13), Vector2(0.87, 0.94)]:
		var lamp := _railgun_sub(back, u.x, u.y, 0.74, 0.86)
		k.color = DARK
		_railgun_slab(k, lamp, Vector3.BACK, 1.0, 0.008)
		_railgun_slab(g, lamp, Vector3.BACK, 0.7, 0.014)
	# The mantlet: a bolted plate standing off the glacis, the barrels out of it.
	var glacis := PackedVector3Array([lo[0], lo[1], hi[1], hi[0]])
	var gn := _railgun_normal(glacis, Vector3.FORWARD)
	var mant := _railgun_sub(glacis, 0.1, 0.9, 0.12, 0.78)
	var mt := width * 0.02
	k.color = DETAIL
	_railgun_slab(k, mant, gn, 1.0, mt)
	for c: Vector2 in [Vector2(0.05, 0.1), Vector2(0.95, 0.1), Vector2(0.05, 0.9), Vector2(0.95, 0.9), Vector2(0.5, 0.1),
			Vector2(0.5, 0.9)]:
		_piping_bolts(k, _railgun_sub(mant, c.x, c.x, c.y, c.y)[0] + gn * mt, gn, 0.0, 1, 0.0, bs, bs * 0.4)
	# The roof: the commander's sight block with a lit lens, two vents, the periscope, a
	# round hatch and a rangefinder bar across the back on two posts.
	k.color = DARK
	var sc := Vector3(-hw * 0.3, top + house_h * 0.16, hl * 0.35)
	k.box(Vector3(width * 0.36, house_h * 0.32, width * 0.3), sc)
	_weapons_lens(k, g, Vector3(sc.x + width * 0.08, sc.y, sc.z - width * 0.15), width * 0.025)
	k.color = RIM
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(width * 0.16, 0.03, width * 0.32), Vector3(sx * hw * 0.42 + hw * 0.1, top + 0.015, hl * 0.2))
	k.color = DETAIL
	k.box(Vector3(width * 0.08, house_h * 0.5, 0.06), Vector3(hw * 0.45, top + house_h * 0.25, hl * 0.6))
	_piping_spin(k, Vector3(hw * 0.35, 0.0, -hl * 0.15), Vector3.UP, PackedVector2Array([Vector2(width * 0.05, top - 0.002),
			Vector2(width * 0.05, top + 0.03), Vector2(0.0, top + 0.03)]), [DETAIL] as Array[Color], 12)
	k.box(Vector3(width * 0.03, 0.025, width * 0.06), Vector3(hw * 0.35, top + 0.042, -hl * 0.15))
	var rz := hl * 0.75
	var rh := width * 0.04
	var ry := top + width * 0.065
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(rh * 0.8, ry - top, rh * 0.8), Vector3(sx * hw * 0.35, top + (ry - top) * 0.5 - 0.005, rz))
	k.box(Vector3(hw * 1.7, rh, rh), Vector3(0.0, ry + rh * 0.5, rz))
	k.color = DARK
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(rh * 1.4, rh * 1.4, rh * 1.4), Vector3(sx * hw * 0.85, ry + rh * 0.5, rz))
	# Two barrels: a blast boot, an angular shroud out of the mantlet, a square barrel, a muzzle.
	var by := hy + house_h * 0.42
	var front := -hl * 0.8 + house_h * 0.5
	var bsz := width * 0.13
	var shroud := barrel * 0.42
	for sx: float in [-1.0, 1.0]:
		var bx := sx * hw * 0.42
		k.color = DARK
		k.box(Vector3(bsz * 2.3, bsz * 2.4, 0.2), Vector3(bx, by + bsz * 0.05, front - 0.06))
		k.color = Color.WHITE
		var s0 := PackedVector3Array([Vector3(bx - bsz, by - bsz, front), Vector3(bx + bsz, by - bsz, front),
				Vector3(bx + bsz, by + bsz * 1.1, front), Vector3(bx - bsz, by + bsz * 1.1, front)])
		var s1 := PackedVector3Array([Vector3(bx - bsz * 0.75, by - bsz * 0.75, front - shroud), Vector3(bx + bsz * 0.75, by - bsz * 0.75, front - shroud),
				Vector3(bx + bsz * 0.75, by + bsz * 0.8, front - shroud), Vector3(bx - bsz * 0.75, by + bsz * 0.8, front - shroud)])
		k.loft(s0, s1)
		k.color = DARK
		k.box(Vector3(bsz * 1.55, 0.03, shroud * 0.5), Vector3(bx, by + bsz * 0.95 + 0.012, front - shroud * 0.45))
		# A clamp band round the shroud near its end.
		var cz := front - shroud * 0.85
		var cs := lerpf(1.0, 0.75, 0.85) + 0.06
		k.color = DETAIL
		k.box(Vector3(bsz * 2.0 * cs, bsz * cs * 2.05, 0.12), Vector3(bx, by + bsz * 0.03, cz))
		var bl := barrel - shroud
		k.color = GUN_STEEL
		k.box(Vector3(bsz * 0.9, bsz * 0.9, bl - 0.25), Vector3(bx, by, front - shroud - (bl - 0.25) * 0.5))
		k.color = DETAIL
		for f: float in [0.35, 0.7]:
			k.box(Vector3(bsz * 1.05, bsz * 1.05, 0.1), Vector3(bx, by, front - shroud - (bl - 0.25) * f))
		k.color = Color.WHITE
		var mz := front - barrel + 0.15
		k.box(Vector3(bsz * 1.25, bsz * 1.25, 0.3), Vector3(bx, by, mz))
		k.color = DARK
		k.box(Vector3(bsz * 0.7, bsz * 0.25, 0.02), Vector3(bx, by, front - barrel - 0.01))
		for side: float in [-1.0, 1.0]:
			for dz: float in [-0.07, 0.07]:
				k.box(Vector3(0.006, bsz * 0.3, 0.07), Vector3(bx + side * (bsz * 0.625 + 0.002), by, mz + dz))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * width * 0.62 * house_h * 0.7 + PI * hw * hw * base_h * 0.5 + barrel * bsz * bsz * 2.0
	var pts := PackedVector3Array()
	pts.append_array(oct_lo)
	pts.append_array(oct_hi)
	pts.append_array(lo)
	pts.append_array(hi)
	pts.append(Vector3(-hw * 0.3 - width * 0.18, hy + house_h * 1.32, hl * 0.35 + width * 0.15))
	pts.append(Vector3(-hw * 0.3 + width * 0.18, hy + house_h * 1.32, hl * 0.35 - width * 0.15))
	for sx: float in [-1.0, 1.0]:
		pts.append(Vector3(sx * hw * 0.92, ry + rh * 1.2, rz))
		for sy: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * (hw * 0.42 + bsz * 0.65), by + sy * bsz * 0.65, front - barrel - 0.02))
			pts.append(Vector3(sx * (hw * 0.42 + bsz), by + sy * bsz * 1.1, front))
	var col := ConvexPolygonShape3D.new()
	col.points = pts
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = glow
	return shape


## A heavy missile launcher block (the Devastator's lower bow sponsons): an armoured box
## `width` across (X), `height` tall and `length` long (Z) with chamfered top edges. Its
## front (-Z) is a raised bevelled frame with corner bolts round a dark cell plate holding
## `cols` by `rows` hollow gunmetal tube collars, each with a missile's warhead cone glowing
## red inside it (PartShape.glow). On the roof two clamshell hatch lids on rubber gaskets
## with a seam and gunmetal hinge knuckles; down each side armour panels with blackened
## bolts over a hazard-striped strip; on the back (+Z) a backblast louvre, a bolted service
## panel with three red ready lamps in plastic bezels and a brass cable gland round a rubber
## cable. Symmetric in X, so it welds to either flank. Stands
## on -Y.
static func missile_launcher(width: float = 1.4, height: float = 1.6, length: float = 4.0,
		cols: int = 2, rows: int = 3) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var hw := width * 0.5
	var hh := height * 0.5
	var hl := length * 0.5
	var ch := minf(width, height) * 0.16
	# The box, its top edges chamfered.
	var ring_a := PackedVector3Array()
	var ring_b := PackedVector3Array()
	var sec := PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh - ch), Vector2(hw - ch, hh),
			Vector2(-hw + ch, hh), Vector2(-hw, hh - ch)])
	for p in sec:
		ring_a.append(Vector3(p.x, p.y, -hl))
		ring_b.append(Vector3(p.x, p.y, hl))
	k.color = Color.WHITE
	k.loft(ring_a, ring_b)
	# The front: a dark cell plate inside a raised bevelled frame (side bars full height,
	# top and bottom bars between them), a bolt in each corner.
	var face := -hl
	var fy := -ch * 0.5                       # the frame's centre height, m
	var fhw := hw - 0.05                      # frame outer half width, m
	var fhh := (height - ch - 0.1) * 0.5      # frame outer half height, m
	var bar := minf(0.1, fhw * 0.16)          # frame bar width, m
	var ft := 0.05                            # frame stands this proud, m
	k.color = DARK
	_cabinets_pad(k, Vector3(0.0, fy, face), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, fhw - bar * 0.5, fhh - bar * 0.5, 0.008)
	k.color = Color.WHITE
	for sx: float in [-1.0, 1.0]:
		_cabinets_pad(k, Vector3(sx * (fhw - bar * 0.5), fy, face), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
				bar * 0.5, fhh, ft, 0.018)
	for sy: float in [-1.0, 1.0]:
		_cabinets_pad(k, Vector3(0.0, fy + sy * (fhh - bar * 0.5), face), Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
				fhw - bar - 0.002, bar * 0.5, ft - 0.004, 0.018)
	k.color = FLANGE_BOLT
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_gear_bolt(k, Vector3(sx * (fhw - bar * 0.5), fy + sy * (fhh - bar * 0.5), face - ft), Vector3.FORWARD, 0.022, 0.012)
	# The tube collars in a grid: hollow steel rings, a dark bore set back, a warhead cone.
	var gw := (fhw - bar) * 2.0
	var gh := (fhh - bar) * 2.0
	var cw := gw / float(cols)
	var rh := gh / float(rows)
	var r := minf(cw, rh) * 0.36
	var cf := face - 0.008                    # the cell plate's face, m
	var tip := face - 0.075                   # collars' mouths, m
	var to_z := Basis(Vector3.RIGHT, -PI * 0.5)   # lathe Y -> -Z
	for c in cols:
		for row in rows:
			var at := Vector3(-gw * 0.5 + cw * (float(c) + 0.5), fy - gh * 0.5 + rh * (float(row) + 0.5), 0.0)
			k.color = GUNMETAL
			_launchers_lathe(k, PackedVector2Array([Vector2(r, -cf - 0.004), Vector2(r * 1.2, -cf - 0.004),
					Vector2(r * 1.2, -tip - 0.012), Vector2(r * 1.12, -tip), Vector2(r, -tip)]), 12,
					Transform3D(to_z, at))
			k.color = DARK
			_launchers_lathe(k, PackedVector2Array([Vector2(0.0, -cf - 0.002), Vector2(r * 1.01, -cf - 0.002),
					Vector2(r * 1.01, -cf + 0.02), Vector2(0.0, -cf + 0.02)]), 12, Transform3D(to_z, at))
			# The warhead: a dark body band, a lit cone to a point short of the mouth.
			_launchers_lathe(k, PackedVector2Array([Vector2(0.0, -cf + 0.018), Vector2(r * 0.62, -cf + 0.018),
					Vector2(r * 0.62, -cf + 0.03), Vector2(0.0, -cf + 0.03)]), 10, Transform3D(to_z, at))
			_launchers_lathe(g, PackedVector2Array([Vector2(0.0, -cf + 0.03), Vector2(r * 0.58, -cf + 0.03),
					Vector2(r * 0.2, -tip - 0.008), Vector2(0.0, -tip - 0.008)]), 10, Transform3D(to_z, at))
	# Roof: two clamshell hatch lids on dark gaskets, a seam down each, hinges at +Z.
	var lw := width - ch * 2.0 - 0.1
	var ll := length * 0.3
	for z: float in [-hl * 0.45, hl * 0.25]:
		k.color = RUBBER
		k.box(Vector3(lw + 0.03, 0.008, ll + 0.03), Vector3(0.0, hh + 0.003, z))
		k.color = Color.WHITE
		_cabinets_pad(k, Vector3(0.0, hh + 0.006, z), Vector3.RIGHT, Vector3.BACK, Vector3.UP, lw * 0.5, ll * 0.5, 0.024, 0.014)
		k.color = DARK
		k.box(Vector3(0.016, 0.006, ll - 0.06), Vector3(0.0, hh + 0.031, z))
		k.color = GUNMETAL
		for sx: float in [-1.0, 1.0]:
			_tube(k, Vector3(sx * lw * 0.15, hh + 0.022, z + ll * 0.5 + 0.012),
					Vector3(sx * lw * 0.38, hh + 0.022, z + ll * 0.5 + 0.012), 0.016, 8)
	# Each side: a hazard-striped strip low down, bolted armour panels above it.
	var pn := maxi(2, int(round(length / 1.6)))
	var pp := (length - 0.16) / float(pn)
	var py0 := -hh + height * 0.2
	var py1 := hh - ch - 0.06
	for sx: float in [-1.0, 1.0]:
		var n := Vector3(sx, 0.0, 0.0)
		_gear_hazard(k, Vector3(sx * hw, -hh + height * 0.11, 0.0), Vector3.BACK, Vector3.UP, n,
				Vector2(length * 0.8, height * 0.08), height * 0.05)
		for i in pn:
			var pz := -hl + 0.08 + pp * (float(i) + 0.5)
			var pc := Vector3(sx * hw, (py0 + py1) * 0.5, pz)
			var hu := pp * 0.5 - 0.035
			var hv := (py1 - py0) * 0.5
			k.color = Color.WHITE
			_cabinets_pad(k, pc, Vector3.BACK, Vector3.UP, n, hu, hv, 0.012, 0.008)
			k.color = FLANGE_BOLT
			for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				_gear_bolt(k, pc + n * 0.012 + Vector3(0.0, c.y * (hv - 0.05), c.x * (hu - 0.05)), n, 0.016, 0.008)
	# The back: a backblast louvre up top, a service panel with ready lamps, a cable gland.
	var back := hl
	_cabinets_louvre(k, Vector3(0.0, hh - ch - height * 0.17, back), Vector3.RIGHT, Vector3.UP, Vector3.BACK,
			hw - 0.14, height * 0.13, 5)
	var sp := Vector3(-hw * 0.3, -hh + height * 0.3, back)
	var su := hw * 0.45
	var sv := height * 0.13
	k.color = Color.WHITE
	_cabinets_pad(k, sp, Vector3.RIGHT, Vector3.UP, Vector3.BACK, su, sv, 0.01, 0.006)
	k.color = DETAIL
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		_gear_bolt(k, sp + Vector3(c.x * (su - 0.035), c.y * (sv - 0.035), 0.01), Vector3.BACK, 0.013, 0.006)
	for i in 3:
		var lp := sp + Vector3(-su * 0.5 + su * 0.5 * float(i), sv * 0.25, 0.01)
		k.color = PLASTIC_DARK
		k.box(Vector3(0.05, 0.05, 0.006), lp + Vector3(0.0, 0.0, 0.003))
		g.box(Vector3(0.03, 0.03, 0.004), lp + Vector3(0.0, 0.0, 0.008))
	k.color = DARK
	k.box(Vector3(su * 1.3, 0.012, 0.004), sp + Vector3(0.0, -sv * 0.35, 0.012))
	var gl := Vector3(hw * 0.5, -hh + height * 0.25, back)
	k.color = BRASS
	_tube(k, gl, gl + Vector3(0.0, 0.0, 0.018), 0.05, 8)
	k.color = RUBBER
	_tube(k, gl + Vector3(0.0, 0.0, 0.017), gl + Vector3(0.0, 0.0, 0.02), 0.03, 8)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * length * 0.5
	var col := BoxShape3D.new()
	col.size = Vector3(width + 0.03, height + 0.03, length + 0.18)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.18, 0.1)
	return shape


## A lathe (closed `profile` of (radius, height) spun round Y in `segments` steps) moved by
## `xf` into `k`, in `k`'s current colour: round collars and bores on any axis.
static func _launchers_lathe(k: MeshKit, profile: PackedVector2Array, segments: int, xf: Transform3D) -> void:
	var t := MeshKit.new()
	t.color = k.color
	t.lathe(profile, segments)
	for i in t.verts.size():
		k.verts.append(xf * t.verts[i])
		k.normals.append((xf.basis * t.normals[i]).normalized())
		k.colors.append(t.colors[i])


## A red-lit radiator panel (the glowing grilles low on the Devastator's stern flanks): a
## pale frame `length` along X and `height` along Z, `depth` thick, its inner edge bevelled
## down into a dark recess, bolts round it, a dark data plate at one end and a hazard tab
## at the other; in the recess a bank of heat-tinted fins along X stacked across Z, each
## raked over toward +Z, crossed by steel support ribs, a red-orange glow showing between
## them (PartShape.glow). Face +Y (lay it on a hull side with X along the hull and Y out of
## it).
static func radiator_grille(length: float = 4.0, height: float = 1.6, depth: float = 0.16) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var hl := length * 0.5
	var hh := height * 0.5
	var d := depth * 0.5
	var rim := minf(length, height) * 0.09
	# The frame: a flat outer band, then a bevel falling into the recess.
	var rect := func(x: float, z: float) -> PackedVector2Array:
		return PackedVector2Array([Vector2(-x, -z), Vector2(x, -z), Vector2(x, z), Vector2(-x, z)])
	var mid := rim * 0.55
	k.color = Color.WHITE
	PartShapes._frame_between(k, rect.call(hl, hh), rect.call(hl - mid, hh - mid), depth, 0.0)
	PartShapes._frame_between(k, rect.call(hl - mid, hh - mid), rect.call(hl - rim, hh - rim), depth, minf(0.03, depth * 0.2))
	k.color = DARK
	var back := depth * 0.3
	k.box(Vector3(length - rim * 2.0, back, height - rim * 2.0), Vector3(0.0, -d + back * 0.5, 0.0))
	# The fins, raked toward +Z, the glow in the gaps between them at the recess floor.
	var inner_l := length - rim * 2.0
	var inner_h := height - rim * 2.0
	var n := maxi(int(inner_h / 0.11), 4)
	var pitch := inner_h / float(n)
	var y0 := -d + back - 0.002
	var y1 := d - 0.025
	var tw := pitch * 0.14
	var lean := pitch * 0.28
	k.color = HEAT_SHIELD
	for i in n:
		var z := -inner_h * 0.5 + pitch * (float(i) + 0.5) - lean * 0.5
		_prism_x(k, PackedVector2Array([Vector2(z - tw, y0), Vector2(z + tw, y0), Vector2(z + tw + lean, y1),
				Vector2(z - tw + lean, y1)]), -inner_l * 0.5 + 0.01, inner_l * 0.5 - 0.01)
		if i < n - 1:
			g.box(Vector3(inner_l - 0.04, 0.01, pitch * 0.4), Vector3(0.0, -d + back + 0.006, z + pitch * 0.5 + lean * 0.15))
	# Steel support ribs across the fins, sunk a little below their tops.
	k.color = DETAIL
	var ribs := maxi(1, int(length / 1.4))
	for i in ribs:
		var x := -inner_l * 0.5 + inner_l * (float(i) + 1.0) / float(ribs + 1)
		k.box(Vector3(0.04, y1 - y0 - 0.02, inner_h - 0.01), Vector3(x, (y0 + y1) * 0.5 - 0.004, 0.0))
	# Bolts round the frame's flat band.
	var bz := hh - mid * 0.5
	var nb := maxi(2, int(length / 0.8) + 1)
	var tab := hl - rim * 2.6                # the plate's and the tab's distance from the middle, m
	for i in nb:
		var x := -hl + mid * 0.5 + (length - mid) * float(i) / float(nb - 1)
		for sz: float in [-1.0, 1.0]:
			if sz < 0.0 and absf(absf(x) - tab) < rim * 1.2 + 0.03:
				continue
			_gear_bolt(k, Vector3(x, d, sz * bz), Vector3.UP, 0.018, 0.008)
	for sx: float in [-1.0, 1.0]:
		_gear_bolt(k, Vector3(sx * (hl - mid * 0.5), d, 0.0), Vector3.UP, 0.018, 0.008)
	# A dark data plate at the +X end, a hazard tab at the -X end.
	k.color = Color(0.1, 0.11, 0.12)
	k.box(Vector3(rim * 2.4, 0.012, mid * 0.7), Vector3(hl - rim * 2.6, d + 0.006, -bz))
	_gear_hazard(k, Vector3(-hl + rim * 2.6, d, -bz), Vector3.RIGHT, Vector3.BACK, Vector3.UP,
			Vector2(rim * 2.4, mid * 0.7), mid * 0.25)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * height * depth * 0.4
	var col := BoxShape3D.new()
	col.size = Vector3(length, depth + 0.012, height)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.32, 0.12)
	return shape


## A slab of layered hull armour (the Devastator's pale armour plating): a dark backing
## plate `width` (X) by `length` (Z) and a little over a third of `thickness`, covered in
## raised tiles with chamfered top edges and dark seams between them, the rows staggered
## and every other tile's corner cut on the diagonal (the reference's angled panel lines),
## every corner nicked by a small chamfer (worn edges), bolt heads in two opposite corners
## of each tile, a bigger bolt at each row's ends and a pale stencil tab with dark lettering
## on one tile of the middle row. Face +Y.
static func armour_slab(width: float = 3.0, length: float = 4.0, thickness: float = 0.18, rows: int = 3) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hw := width * 0.5
	var hl := length * 0.5
	var y0 := -thickness * 0.5
	var base := thickness * 0.4
	k.color = DARK
	k.box(Vector3(width, base, length), Vector3(0.0, y0 + base * 0.5, 0.0))
	k.color = Color.WHITE
	var seam := 0.035
	var ty0 := y0 + base - 0.002
	var ty1 := thickness * 0.5
	var bevel := minf(0.05, (ty1 - ty0) * 0.6)
	var pitch := length / float(rows)
	for r in rows:
		var za := -hl + pitch * float(r) + seam * 0.5
		var zb := za + pitch - seam
		# Two tiles across, the split staggered row to row.
		var split := hw * (0.25 if r % 2 == 0 else -0.3)
		var spans := [Vector2(-hw + seam * 0.5, split - seam * 0.5), Vector2(split + seam * 0.5, hw - seam * 0.5)]
		for i in 2:
			var sp: Vector2 = spans[i]
			var cut := (r + i) % 2 == 0
			var c := minf(sp.y - sp.x, zb - za) * 0.3
			var o := PackedVector2Array([Vector2(sp.x, za), Vector2(sp.y, za), Vector2(sp.y, zb)])
			if cut:
				o = PackedVector2Array([Vector2(sp.x, za), Vector2(sp.y, za), Vector2(sp.y, zb - c), Vector2(sp.y - c, zb), Vector2(sp.x, zb)])
			else:
				o.append(Vector2(sp.x, zb))
			var ctr := Vector2.ZERO
			for p in o:
				ctr += p / float(o.size())
			# Every corner nicked by a small chamfer (worn, chipped edges).
			var nicked := PackedVector2Array()
			for j in o.size():
				nicked.append(o[j].move_toward(o[(j + o.size() - 1) % o.size()], 0.035))
				nicked.append(o[j].move_toward(o[(j + 1) % o.size()], 0.035))
			o = nicked
			var lo := PackedVector3Array()
			var hi := PackedVector3Array()
			for p in o:
				lo.append(Vector3(p.x, ty0, p.y))
				var q := p.move_toward(ctr, bevel)
				hi.append(Vector3(q.x, ty1, q.y))
			k.loft(lo, hi)
			# Bolt heads in two opposite corners of the tile's top.
			k.color = DETAIL
			for ci: int in [0, int(o.size() * 0.5)]:
				var q := Vector2(hi[ci].x, hi[ci].z)
				var b := q.move_toward(Vector2(ctr.x, ctr.y), 0.09)
				_thrusters_bolt(k, Vector3(b.x, ty1, b.y), 0.024, 0.012)
			# A stencil tab on one tile: a pale plate with dark lettering bars.
			if r == int(rows * 0.5) and i == 1:
				var tc := Vector2(ctr.x, ctr.y)
				var tw := minf((sp.y - sp.x) * 0.4, 0.5)
				var td := minf((zb - za) * 0.18, 0.2)
				k.color = PLATE
				k.box(Vector3(tw, 0.004, td), Vector3(tc.x, ty1 + 0.002, tc.y))
				k.color = DARK
				for j in 2:
					k.box(Vector3(tw * (0.75 - 0.3 * float(j)), 0.004, td * 0.18),
							Vector3(tc.x - tw * 0.15 * float(j), ty1 + 0.004, tc.y - td * 0.2 + td * 0.42 * float(j)))
			k.color = Color.WHITE
		k.color = DETAIL
		for sx: float in [-1.0, 1.0]:
			_thrusters_bolt(k, Vector3(sx * (hw - 0.12), ty1, (za + zb) * 0.5), 0.034, 0.02)
		k.color = Color.WHITE
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * length * thickness * 0.7
	var col := BoxShape3D.new()
	col.size = Vector3(width, thickness + 0.06, length)
	shape.collision = col
	return shape


# --- Destroyer parts (v2, the Everest) -------------------------------------------------

## The big missile silo under a warship's belly (the Everest's large-calibre missile box,
## shots 10 and 11): an armoured box `width` across (X), `height` tall and `length` long
## (Z), its lower edges chamfered with louvred vents in the chamfers, a dark mount plate on
## top, bolted armour panels over a dark belt seam down both sides and a bolted access
## panel with a hazard tab on each end (three red ready lamps on the +Z one). In its
## underside an octagonal launch hatch: a hazard ring round a bolted red rim, a pale
## faceted lid with a dark seam and a centre boss, and a red-lit lamp slot either side
## (PartShape.glow). Mounts on +Y, hatch facing -Y.
static func missile_silo(width: float = 2.4, height: float = 1.8, length: float = 3.6) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var hw := width * 0.5
	var hh := height * 0.5
	var hl := length * 0.5
	var ch := minf(width, height) * 0.18
	var plate := 0.06
	var top := hh - plate
	# The box, its lower edges chamfered.
	var sec := PackedVector2Array([Vector2(-hw, top), Vector2(-hw, -hh + ch), Vector2(-hw + ch, -hh),
			Vector2(hw - ch, -hh), Vector2(hw, -hh + ch), Vector2(hw, top)])
	var ra := PackedVector3Array()
	var rb := PackedVector3Array()
	for p in sec:
		ra.append(Vector3(p.x, p.y, -hl))
		rb.append(Vector3(p.x, p.y, hl))
	k.color = Color.WHITE
	k.loft(ra, rb)
	# The mount plate on top, a little smaller than the box.
	k.color = DARK
	k.box(Vector3(width - 0.1, plate, length - 0.1), Vector3(0.0, hh - plate * 0.5, 0.0))
	# Each side: a dark belt seam, two bolted armour panels above it, a vent in the chamfer.
	var belt := -hh + ch + (top - (-hh + ch)) * 0.22
	var py0 := belt + 0.05
	var py1 := top - 0.08
	for sx: float in [-1.0, 1.0]:
		var n := Vector3(sx, 0.0, 0.0)
		k.color = DARK
		k.box(Vector3(0.008, 0.035, length - 0.04), Vector3(sx * (hw + 0.003), belt, 0.0))
		for sz: float in [-1.0, 1.0]:
			var pc := Vector3(sx * hw, (py0 + py1) * 0.5, sz * hl * 0.5)
			var hu := hl * 0.5 - 0.06
			var hv := (py1 - py0) * 0.5
			k.color = Color.WHITE
			_cabinets_pad(k, pc, Vector3.BACK, Vector3.UP, n, hu, hv, 0.014, 0.01)
			k.color = DETAIL
			for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				_gear_bolt(k, pc + n * 0.014 + Vector3(0.0, c.y * (hv - 0.06), c.x * (hu - 0.06)), n, 0.02, 0.01)
		var cn := Vector3(sx, -1.0, 0.0).normalized()
		var cv := Vector3(-sx, -1.0, 0.0).normalized()
		_cabinets_louvre(k, Vector3(sx * (hw - ch * 0.5), -hh + ch * 0.5, 0.0), Vector3.BACK, cv, cn,
				length * 0.3, ch * 0.42, 4)
	# Each end: a bolted access panel with a hazard tab; ready lamps on the +Z one.
	for sz: float in [-1.0, 1.0]:
		var n := Vector3(0.0, 0.0, sz)
		var pc := Vector3(0.0, (py0 + py1) * 0.5, sz * hl)
		var hu := hw * 0.5
		var hv := (py1 - py0) * 0.42
		k.color = Color.WHITE
		_cabinets_pad(k, pc, Vector3.RIGHT, Vector3.UP, n, hu, hv, 0.008, 0.006)
		k.color = DETAIL
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			_gear_bolt(k, pc + n * 0.008 + Vector3(c.x * (hu - 0.05), c.y * (hv - 0.05), 0.0), n, 0.018, 0.008)
		k.color = DARK
		k.box(Vector3(0.06, hv * 0.6, 0.012), pc + n * 0.014 + Vector3(hu * 0.7, 0.0, 0.0))
		_weapons_hazard(k, pc + n * 0.008 + Vector3(-hu * 0.45, -hv * 0.55, 0.0), hu * 0.6, 0.08, sz, 3)
		if sz > 0.0:
			for i in 3:
				var lp := pc + n * 0.008 + Vector3(-hu * 0.6 + hu * 0.3 * float(i), hv * 0.45, 0.0)
				k.color = DARK
				k.box(Vector3(0.07, 0.07, 0.008), lp + n * 0.004)
				g.box(Vector3(0.042, 0.042, 0.004), lp + n * 0.01)
	# The octagonal hatch in the underside: a hazard ring, a bolted red rim, a pale lid.
	var r_out := minf(width - ch * 2.0, length) * 0.4
	var r_in := r_out * 0.8
	var fy := -hh
	_gear_hazard_ring(k, r_out - 0.01, r_out * 1.08, fy - 0.006, fy + 0.001, 8, 3, PartShapes.ACCENT, DARK)
	var rim_lo := PackedVector3Array()
	var rim_hi := PackedVector3Array()
	var lid_lo := PackedVector3Array()
	var lid_hi := PackedVector3Array()
	for i in 8:
		var a := TAU * float(i) / 8.0
		rim_lo.append(Vector3(cos(a) * r_out, fy - 0.03, sin(a) * r_out))
		rim_hi.append(Vector3(cos(a) * r_out, fy + 0.001, sin(a) * r_out))
		lid_lo.append(Vector3(cos(a) * r_in, fy - 0.05, sin(a) * r_in))
		lid_hi.append(Vector3(cos(a) * r_in * 0.55, fy - 0.11, sin(a) * r_in * 0.55))
	k.color = HATCH_RED
	k.loft(rim_hi, rim_lo)
	k.color = DETAIL
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		var br := (r_in + r_out) * 0.5
		_gear_bolt(k, Vector3(cos(a) * br, fy - 0.03, sin(a) * br), Vector3.DOWN, 0.03, 0.014)
	k.color = Color(0.72, 0.73, 0.75)
	var lid_top := PackedVector3Array()
	for p in lid_lo:
		lid_top.append(Vector3(p.x, fy - 0.025, p.z))
	k.loft(lid_top, lid_lo)
	k.loft(lid_lo, lid_hi)
	k.color = DARK
	k.box(Vector3(r_in * 1.0, 0.012, 0.035), Vector3(0.0, fy - 0.111, 0.0))
	k.color = DETAIL
	_launchers_lathe(k, PackedVector2Array([Vector2(0.0, fy - 0.108), Vector2(r_in * 0.14, fy - 0.108),
			Vector2(r_in * 0.12, fy - 0.125), Vector2(0.0, fy - 0.125)]), 6, Transform3D())
	# Lamp slots either side of the hatch: a dark housing, a red-lit lens.
	for sx: float in [-1.0, 1.0]:
		var lx := sx * (r_out * 1.08 + (hw - ch - r_out * 1.08) * 0.5)
		k.color = DARK
		k.box(Vector3(0.1, 0.03, 0.36), Vector3(lx, fy - 0.015, 0.0))
		g.box(Vector3(0.06, 0.012, 0.28), Vector3(lx, fy - 0.034, 0.0))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * length * 0.5
	var col := BoxShape3D.new()
	col.size = Vector3(width + 0.02, height + 0.24, length + 0.02)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.18, 0.12)
	return shape


## A six-wheeled ground rover (the one the Everest's hangar carries down to a planet): six
## chunky wheels (rounded tyres with staggered tread lugs, dished steel rims with lug nuts
## and a bright cap) under arched fenders, each hung on a knuckle from a lower A-arm and a
## coil-over shock off a narrow dark-plated belly; a sill with a yellow stripe down each
## side, bumpers with tow hooks, a side step; a cab at the front (-Z) with a raked dark
## windscreen split by a pillar, wipers, side windows, door seams and handles, mirrors, a
## grille and two pairs of headlamps (lit) in its nose, a roof hatch and a roof lamp bar
## on posts (lit); a cargo bed behind it with ribbed, capped side walls, a hinged tailgate
## with latches, rub strips, a toolbox and a spare wheel. `length` (Z) by `width` (X, over
## the wheels) by `height` (Y). Stands on -Y.
static func rover(length: float = 3.6, width: float = 2.0, height: float = 1.7) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var hl := length * 0.5
	var hw := width * 0.5
	var y0 := -height * 0.5
	var r := height * 0.24
	var tyre := minf(0.32, width * 0.16)
	var body_hw := hw - tyre - 0.03
	var axle_y := y0 + r
	var ch_lo := y0 + r * 0.55
	var ch_hi := y0 + r * 1.75
	var sill_lo := lerpf(ch_lo, ch_hi, 0.4)
	var belly_hw := body_hw - 0.2
	var wheel_z: Array[float] = [-hl * 0.66, 0.0, hl * 0.66]
	var tw := tyre * 0.5
	# Wheels: a rounded tyre round X, tread lugs staggered across it, a dished rim, lug
	# nuts and a bright cap on the outer face.
	for z: float in wheel_z:
		for sx: float in [-1.0, 1.0]:
			var wc := Vector3(sx * (hw - tw), axle_y, z)
			var ax := Vector3(sx, 0.0, 0.0)
			_piping_spin(k, wc, ax, PackedVector2Array([Vector2(r * 0.56, -tw), Vector2(r * 0.86, -tw),
					Vector2(r, -tw * 0.7), Vector2(r, tw * 0.7), Vector2(r * 0.86, tw), Vector2(r * 0.56, tw)]),
					[DARK] as Array[Color], 14)
			var lugs := 10
			for i in lugs:
				var a := TAU * float(i) / float(lugs)
				var from := k.verts.size()
				k.box(Vector3(tyre * 0.55, 0.026, TAU * r / float(lugs) * 0.45), Vector3(0.0, r - 0.001, 0.0))
				_stowage_xform(k, from, Transform3D(Basis(Vector3.RIGHT, a), wc + Vector3(tyre * 0.2 * (1.0 if i % 2 == 0 else -1.0), 0.0, 0.0)))
			k.color = DETAIL
			_tube(k, wc - ax * (tw - 0.01), wc + ax * (tw - 0.035), r * 0.57, 12)
			k.color = DARK
			_tube(k, wc + ax * (tw - 0.036), wc + ax * (tw - 0.03), r * 0.42, 8)
			k.color = TRIM
			_tube(k, wc + ax * (tw - 0.036), wc + ax * (tw + 0.012), r * 0.2, 8)
			k.color = DETAIL
			for i in 4:
				var a := TAU * (float(i) + 0.5) / 4.0
				_gear_bolt(k, wc + ax * (tw - 0.035) + Vector3(0.0, cos(a), sin(a)) * r * 0.32, ax, 0.016, 0.022)
	# The belly between the wheels (a dark skid plate under it), the sill above it.
	k.color = Color.WHITE
	k.box(Vector3(belly_hw * 2.0, sill_lo - ch_lo, length - 0.3), Vector3(0.0, (ch_lo + sill_lo) * 0.5, 0.0))
	k.box(Vector3(body_hw * 2.0, ch_hi - sill_lo, length - 0.1), Vector3(0.0, (sill_lo + ch_hi) * 0.5, 0.0))
	k.color = DARK
	k.box(Vector3(belly_hw * 1.6, 0.02, length - 0.5), Vector3(0.0, ch_lo - 0.01, 0.0))
	# Suspension: a knuckle inside each wheel on a lower A-arm and a coil-over shock.
	for z: float in wheel_z:
		for sx: float in [-1.0, 1.0]:
			var kn := Vector3(sx * (hw - tyre - 0.05), axle_y, z)
			k.color = DETAIL
			k.box(Vector3(0.08, 0.18, 0.14), kn)
			k.color = DARK
			for dz: float in [-0.16, 0.16]:
				k.strut(Vector3(sx * (belly_hw - 0.01), ch_lo + 0.06, z + dz), kn + Vector3(0.0, -0.06, 0.0), 0.05)
			var s_top := Vector3(sx * (belly_hw + 0.06), sill_lo - 0.005, z + 0.1)
			var s_bot := kn + Vector3(0.0, 0.08, 0.02)
			_tube(k, s_top, s_top.lerp(s_bot, 0.5), 0.032, 8)
			k.color = PartShapes.ACCENT
			_tube(k, s_top.lerp(s_bot, 0.2), s_top.lerp(s_bot, 0.7), 0.046, 8)
			k.color = TRIM
			_tube(k, s_top.lerp(s_bot, 0.45), s_bot, 0.018, 8)
	# Arched fenders over the wheels.
	k.color = Color.WHITE
	for z: float in wheel_z:
		for sx: float in [-1.0, 1.0]:
			var xa := sx * (hw - tyre - 0.02)
			var xb := sx * (hw + 0.005)
			_heroes_arch(k, Vector3(0.0, axle_y, z), r + 0.05, r + 0.08, minf(xa, xb), maxf(xa, xb), -1.15, 1.15, 8)
	# Bumpers with tow hooks, a side step under each door.
	for sz: float in [-1.0, 1.0]:
		k.color = DARK
		k.box(Vector3(body_hw * 2.0 + 0.1, 0.16, 0.07), Vector3(0.0, sill_lo - 0.02, sz * (hl - 0.055)))
		k.color = PartShapes.ACCENT
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(0.06, 0.06, 0.04), Vector3(sx * body_hw * 0.55, sill_lo - 0.13, sz * (hl - 0.035)))
	k.color = DARK
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.12, 0.03, 0.24), Vector3(sx * (body_hw + 0.06), sill_lo - 0.06, -hl * 0.33))
	# The cab: a block over the front half, its front raked back to the windscreen.
	var cab_z0 := -hl + 0.05
	var cab_z1 := hl * 0.05
	var top := height * 0.5
	var cab := PackedVector2Array([Vector2(cab_z0, ch_hi), Vector2(cab_z1, ch_hi), Vector2(cab_z1, top),
			Vector2(cab_z0 + length * 0.2, top), Vector2(cab_z0, ch_hi + (top - ch_hi) * 0.35)])
	k.color = Color.WHITE
	_prism_x(k, cab, -body_hw + 0.04, body_hw - 0.04)
	# The windscreen on the raked face, a pillar down its middle, wipers at its foot.
	k.color = Color(0.12, 0.16, 0.2)
	var wa := Vector2(cab_z0, ch_hi + (top - ch_hi) * 0.35)
	var wb := Vector2(cab_z0 + length * 0.2, top)
	var wm := wa.lerp(wb, 0.55)
	var slope := (wb - wa).normalized()   # (dz, dy), both positive
	var n := Vector3(0.0, slope.x, -slope.y)   # out of the raked face: up and forward
	var up_face := Vector3(0.0, slope.y, slope.x)
	var wlen := (wb - wa).length() * 0.7
	var ws := PackedVector3Array()
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		ws.append(Vector3(c.x * (body_hw - 0.14), wm.y, wm.x) + up_face * (c.y * wlen * 0.5) + n * 0.012)
	k.poly(ws, n)
	var wfoot := Vector3(0.0, wm.y, wm.x) - up_face * (wlen * 0.5)
	k.color = Color.WHITE
	k.strut(wfoot + n * 0.02, wfoot + up_face * wlen + n * 0.02, 0.06)
	k.color = DARK
	for sx: float in [-1.0, 1.0]:
		var wp := wfoot + Vector3(sx * body_hw * 0.45, 0.0, 0.0) + n * 0.03 + up_face * 0.04
		k.strut(wp - Vector3(sx * 0.22, 0.0, 0.0) + up_face * 0.1, wp + Vector3(sx * 0.12, 0.0, 0.0), 0.018)
	# Side windows, door seams and handles, mirrors on arms at the front corners.
	k.color = Color(0.12, 0.16, 0.2)
	var win_z := (cab_z0 + cab_z1) * 0.5 + length * 0.06
	var win_hz := (cab_z1 - cab_z0) * 0.42
	for sx: float in [-1.0, 1.0]:
		var xs := sx * (body_hw - 0.04)
		k.color = Color(0.12, 0.16, 0.2)
		k.box(Vector3(0.012, (top - ch_hi) * 0.38, win_hz), Vector3(xs + sx * 0.006, ch_hi + (top - ch_hi) * 0.62, win_z))
		k.color = DARK
		for dz: float in [-0.5, 0.5]:
			k.box(Vector3(0.008, (top - ch_hi) * 0.9, 0.012), Vector3(xs + sx * 0.004, ch_hi + (top - ch_hi) * 0.47, win_z + dz * (win_hz + 0.12)))
		k.box(Vector3(0.008, 0.012, win_hz + 0.24), Vector3(xs + sx * 0.004, ch_hi + (top - ch_hi) * 0.06, win_z))
		k.color = DETAIL
		k.box(Vector3(0.03, 0.03, 0.12), Vector3(xs + sx * 0.015, ch_hi + (top - ch_hi) * 0.36, win_z + win_hz * 0.3))
		var arm := Vector3(xs, ch_hi + (top - ch_hi) * 0.4, cab_z0 + length * 0.1)
		k.strut(arm, arm + Vector3(sx * 0.1, 0.04, 0.0), 0.025)
		k.color = DARK
		k.box(Vector3(0.05, 0.14, 0.1), arm + Vector3(sx * 0.13, 0.05, 0.0))
	# The nose: a grille on the sill and two pairs of headlamps in dark housings over it.
	var nose := cab_z0
	k.color = DARK
	k.box(Vector3(body_hw * 0.8, (ch_hi - sill_lo) * 0.7, 0.012), Vector3(0.0, (sill_lo + ch_hi) * 0.5, -hl + 0.044))
	k.color = DETAIL
	for i in 3:
		var gy := lerpf(sill_lo, ch_hi, 0.3 + 0.2 * float(i))
		k.box(Vector3(body_hw * 0.78, 0.016, 0.01), Vector3(0.0, gy, -hl + 0.036))
	var lamp_y := ch_hi + (top - ch_hi) * 0.17
	for sx: float in [-1.0, 1.0]:
		k.color = DARK
		k.box(Vector3(0.32, 0.13, 0.02), Vector3(sx * (body_hw - 0.26), lamp_y, nose - 0.01))
		for j in 2:
			var lx := sx * (body_hw - 0.33 + 0.14 * float(j))
			k.color = REFLECTOR
			k.box(Vector3(0.11, 0.09, 0.006), Vector3(lx, lamp_y, nose - 0.023))
			g.box(Vector3(0.08, 0.065, 0.006), Vector3(lx, lamp_y, nose - 0.028))
	# The roof: a hatch with a handle, a lamp bar on two posts with lit lamps facing -Z.
	k.color = DETAIL
	var hatch_z := lerpf(cab_z0 + length * 0.2, cab_z1, 0.62)
	k.box(Vector3(0.5, 0.014, 0.5), Vector3(0.0, top + 0.007, hatch_z))
	k.color = DARK
	k.box(Vector3(0.16, 0.02, 0.03), Vector3(0.0, top + 0.024, hatch_z + 0.12))
	var bar_z := cab_z0 + length * 0.24
	k.color = DETAIL
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.05, 0.03, 0.08), Vector3(sx * body_hw * 0.62, top + 0.015, bar_z))
	k.color = DARK
	k.box(Vector3(body_hw * 1.4, 0.04, 0.1), Vector3(0.0, top + 0.05, bar_z))
	for i in 4:
		var lx := -body_hw * 0.6 + body_hw * 1.2 * float(i) / 3.0
		k.color = REFLECTOR
		k.box(Vector3(0.15, 0.036, 0.008), Vector3(lx, top + 0.05, bar_z - 0.054))
		g.box(Vector3(0.12, 0.026, 0.006), Vector3(lx, top + 0.05, bar_z - 0.06))
	# The cargo bed: ribbed side walls with cap rails, a hinged tailgate with latches,
	# rub strips on its floor, a toolbox and a spare wheel lying in it.
	k.color = Color.WHITE
	var bed_h := (top - ch_hi) * 0.35
	var bed_z := (cab_z1 + hl) * 0.5 - 0.02
	var bed_l := hl - cab_z1 - 0.1
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.06, bed_h, bed_l), Vector3(sx * (body_hw - 0.07), ch_hi + bed_h * 0.5, bed_z))
		for i in 4:
			var rz := lerpf(cab_z1 + 0.15, hl - 0.2, float(i) / 3.0)
			k.box(Vector3(0.02, bed_h - 0.02, 0.05), Vector3(sx * (body_hw - 0.03), ch_hi + bed_h * 0.5 - 0.01, rz))
		k.color = DETAIL
		k.box(Vector3(0.08, 0.02, bed_l + 0.01), Vector3(sx * (body_hw - 0.07), ch_hi + bed_h + 0.01, bed_z))
		k.color = Color.WHITE
	k.box(Vector3(body_hw * 2.0 - 0.2, bed_h, 0.06), Vector3(0.0, ch_hi + bed_h * 0.5, hl - 0.1))
	k.color = DETAIL
	_tube(k, Vector3(-body_hw + 0.14, ch_hi + 0.03, hl - 0.064), Vector3(body_hw - 0.14, ch_hi + 0.03, hl - 0.064), 0.022, 8)
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.08, 0.05, 0.02), Vector3(sx * (body_hw - 0.22), ch_hi + bed_h - 0.06, hl - 0.06))
	for i in 4:
		var rx := lerpf(-body_hw + 0.25, body_hw - 0.25, float(i) / 3.0)
		k.box(Vector3(0.04, 0.008, bed_l - 0.2), Vector3(rx, ch_hi + 0.004, bed_z))
	var tbox := Vector3(body_hw * 1.2, 0.24, 0.3)
	k.box(tbox, Vector3(0.0, ch_hi + 0.008 + tbox.y * 0.5, cab_z1 + 0.24))
	k.color = DARK
	k.box(Vector3(tbox.x + 0.006, 0.012, tbox.z + 0.006), Vector3(0.0, ch_hi + 0.008 + tbox.y * 0.72, cab_z1 + 0.24))
	var spare := Vector3(0.0, ch_hi + 0.008, hl * 0.5)
	_piping_spin(k, spare, Vector3.UP, PackedVector2Array([Vector2(r * 0.5, 0.0), Vector2(r * 0.8, 0.0),
			Vector2(r * 0.8, tyre * 0.8), Vector2(r * 0.5, tyre * 0.8)]), [DARK] as Array[Color], 14)
	k.color = DETAIL
	_thrusters_ring(k, 0.0, r * 0.52, spare.y + 0.02, spare.y + tyre * 0.7, 12)
	k.color = TRIM
	_thrusters_ring(k, 0.0, r * 0.2, spare.y + tyre * 0.7, spare.y + tyre * 0.7 + 0.02, 8)
	# Yellow stripes down the sill's sides.
	k.color = PartShapes.ACCENT
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.012, 0.07, length - 0.4), Vector3(sx * (body_hw + 0.006), ch_hi - 0.1, 0.0))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * width * height * 0.45
	var col := BoxShape3D.new()
	col.size = Vector3(width + 0.06, height + 0.08, length + 0.02)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.95, 0.8)
	return shape


## An arch round X centred on `c`: a band from radius `r0` to `r1`, from x0 to x1, swept
## from angle `a0` to `a1` (0 straight up, positive toward +Z) in `n` steps (fenders).
static func _heroes_arch(k: MeshKit, c: Vector3, r0: float, r1: float, x0: float, x1: float, a0: float, a1: float,
		n: int) -> void:
	for i in n:
		var aa := lerpf(a0, a1, float(i) / float(n))
		var ab := lerpf(a0, a1, float(i + 1) / float(n))
		var ra := PackedVector3Array()
		var rb := PackedVector3Array()
		for p: Vector2 in [Vector2(r0, aa), Vector2(r1, aa), Vector2(r1, ab), Vector2(r0, ab)]:
			var o := Vector3(0.0, cos(p.y) * p.x, sin(p.y) * p.x)
			ra.append(c + o + Vector3(x0, 0.0, 0.0))
			rb.append(c + o + Vector3(x1, 0.0, 0.0))
		k.loft(ra, rb)


# --- Frigate parts (v2, the Sentinel) ---------------------------------------------------

## The long heat vent down a frigate's bow flank (the Sentinel's copper-slatted vents,
## shots 1, 3 and 4, glowing orange at night): a frame `length` (X) by `height` (Z) with
## its corners cut, in the material colour, bolted round its flat band, its inner edge a
## heat-tinted bevel falling into a dark recess; in the recess two steel rails across the
## length carry a row of `slats` round copper bars across the height in steel saddle
## clamps, an orange glow behind the gaps between them (PartShape.glow); a small dark
## data plate on the frame. Face +Y, back on -Y against the hull.
static func copper_vent(length: float = 4.0, height: float = 1.2, depth: float = 0.24, slats: int = 8) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var g := MeshKit.new()
	var hl := length * 0.5
	var hh := height * 0.5
	var d := depth * 0.5
	var rim := minf(length, height) * 0.12
	var cut := rim * 1.6
	var oct := func(x: float, z: float, c: float) -> PackedVector2Array:
		return PackedVector2Array([Vector2(-x + c, -z), Vector2(x - c, -z), Vector2(x, -z + c), Vector2(x, z - c),
				Vector2(x - c, z), Vector2(-x + c, z), Vector2(-x, z - c), Vector2(-x, -z + c)])
	# The frame: a flat band with cut corners, then a heat-tinted bevel into the recess.
	var ihl := hl - rim
	var ihh := hh - rim
	var icut := cut * 0.6
	var mid := rim * 0.55
	var outer: PackedVector2Array = oct.call(hl, hh, cut)
	var middle: PackedVector2Array = oct.call(hl - mid, hh - mid, lerpf(cut, icut, 0.55))
	var inner: PackedVector2Array = oct.call(ihl, ihh, icut)
	k.color = Color.WHITE
	PartShapes._frame_between(k, outer, middle, depth, 0.0)
	k.color = HEAT_SHIELD
	PartShapes._frame_between(k, middle, inner, depth, minf(0.04, depth * 0.2))
	# The dark recess floor, set back from the frame's face.
	k.color = DARK
	var back := depth * 0.3
	var fa := PackedVector3Array()
	var fb := PackedVector3Array()
	for q in inner:
		fa.append(Vector3(q.x, -d, q.y))
		fb.append(Vector3(q.x, -d + back, q.y))
	k.loft(fa, fb)
	# The copper slats: round bars across the recess on two steel rails, a gap between
	# each, the glow behind.
	var n := maxi(slats, 2)
	var room := ihl * 2.0 - 0.1
	var pitch := room / float(n)
	var r := minf(pitch * 0.38, (depth - back) * 0.45)
	var sy := -d + back + r + 0.004
	var sl := ihh - 0.03
	var rail := minf(0.05, r * 0.7)
	k.color = DETAIL
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(room + 0.04, rail, rail), Vector3(0.0, -d + back + rail * 0.5 - 0.002, sz * sl * 0.55))
	for i in n:
		var x := -room * 0.5 + pitch * (float(i) + 0.5)
		k.color = COPPER
		_tube(k, Vector3(x, sy, -sl), Vector3(x, sy, sl), r, 10)
		k.color = DETAIL
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(r * 2.3, r * 0.7, 0.05), Vector3(x, sy + r * 0.45, sz * sl * 0.55))
			k.box(Vector3(0.012, r * 1.4, 0.03), Vector3(x + r * 1.15 + 0.004, sy - r * 0.3, sz * sl * 0.55))
		if i < n - 1:
			g.box(Vector3(pitch - r * 2.0 - 0.01, 0.01, sl * 1.8), Vector3(x + pitch * 0.5, -d + back + 0.006, 0.0))
	# Bolts round the flat band, and a data plate on it at the -X end.
	k.color = DETAIL
	var bz := hh - mid * 0.5
	var bx := hl - cut - mid
	var nb := maxi(2, int(bx * 2.0 / 0.9) + 1)
	var plate_x := -hl + cut + 0.25 + cut * 0.45
	for i in nb:
		var x := -bx + bx * 2.0 * float(i) / float(nb - 1)
		for sz: float in [-1.0, 1.0]:
			if sz > 0.0 and absf(x - plate_x) < cut * 0.45 + 0.04:
				continue
			_gear_bolt(k, Vector3(x, d, sz * bz), Vector3.UP, 0.02, 0.008)
	for sx: float in [-1.0, 1.0]:
		_gear_bolt(k, Vector3(sx * (hl - mid * 0.5), d, 0.0), Vector3.UP, 0.02, 0.008)
	k.color = DARK
	k.box(Vector3(cut * 0.9, 0.01, mid * 0.6), Vector3(plate_x, d + 0.005, bz))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = length * height * depth * 0.35
	var col := BoxShape3D.new()
	col.size = Vector3(length, depth + 0.02, height)
	shape.collision = col
	shape.glow = g.finish()
	shape.glow_color = Color(1.0, 0.45, 0.15)
	return shape


## Hard cases stacked in a wall frame (the Sentinel's bunk room, shot 12: three black kit
## cases one over another in a recessed frame): a back plate `width` by `height` with lips
## round it (material colour) and a steel retaining bar under each case, `cases` black
## cases filling it, each a chamfered shell with bright corner guards, a dark lid seam round
## it, two bright latches either side of a dark carry handle on the seam, two raised ribs
## below and pale hazard tabs at the lower corners. Stands on -Y, front -Z, back +Z on a
## wall.
static func case_stack(width: float = 0.95, height: float = 2.0, depth: float = 0.5, cases: int = 3) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hw := width * 0.5
	var hh := height * 0.5
	var hd := depth * 0.5
	var plate := 0.04
	var lip := 0.05
	# The back plate and the lips round the frame (material colour).
	k.box(Vector3(width, height, plate), Vector3(0.0, 0.0, hd - plate * 0.5))
	k.box(Vector3(width, lip, depth - plate), Vector3(0.0, -hh + lip * 0.5, -plate * 0.5))
	k.box(Vector3(width, lip, depth - plate), Vector3(0.0, hh - lip * 0.5, -plate * 0.5))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(lip, height - lip * 2.0, depth - plate), Vector3(sx * (hw - lip * 0.5), 0.0, -plate * 0.5))
	# The cases, a small gap between them.
	var n := maxi(cases, 1)
	var room := height - lip * 2.0 - 0.02
	var pitch := room / float(n)
	var cw := width - lip * 2.0 - 0.04
	var cd := depth - plate - 0.06
	var cz := hd - plate - 0.01 - cd * 0.5
	var face := cz - cd * 0.5
	for i in n:
		var cy := -hh + lip + 0.01 + pitch * (float(i) + 0.5)
		var ch := pitch - 0.04
		var cc := minf(0.04, ch * 0.12)                 # the shell's chamfer, m
		var sy := cy + ch * 0.28                        # the lid seam
		# A steel bar across the frame at the case's foot, between the lips.
		k.color = DETAIL
		k.box(Vector3(width - lip * 2.0, 0.03, 0.03), Vector3(0.0, cy - ch * 0.5 + 0.015, face - 0.02))
		# The shell, the lid seam round it.
		k.color = CASE_SHELL
		k.loft(_stowage_oct_xy(Vector3(0.0, cy, face), cw * 0.5, ch * 0.5, cc),
				_stowage_oct_xy(Vector3(0.0, cy, face + cd), cw * 0.5, ch * 0.5, cc))
		k.color = DARK
		k.box(Vector3(cw + 0.006, 0.014, cd + 0.002), Vector3(0.0, sy, cz - 0.002))
		# Corner guards over the front corners.
		k.color = TRIM
		var gs := cc * 1.8
		for gx: float in [-1.0, 1.0]:
			for gy: float in [-1.0, 1.0]:
				k.box(Vector3(gs, gs, 0.05), Vector3(gx * (cw * 0.5 - gs * 0.5 + 0.004), cy + gy * (ch * 0.5 - gs * 0.5 + 0.004),
						face + 0.021))
		# Latches either side of a carry handle on the seam.
		k.color = TRIM
		for lx: float in [-1.0, 1.0]:
			k.box(Vector3(0.07, 0.07, 0.024), Vector3(lx * cw * 0.3, sy, face - 0.012))
		k.color = DARK
		for hx: float in [-1.0, 1.0]:
			k.box(Vector3(0.025, 0.035, 0.035), Vector3(hx * cw * 0.1, sy - 0.03, face - 0.0175))
		k.box(Vector3(cw * 0.26, 0.03, 0.02), Vector3(0.0, sy - 0.03, face - 0.04))
		# Raised ribs across the front, hazard tabs at the lower corners.
		k.color = CASE_RIB
		for t: float in [0.0, 0.2]:
			k.box(Vector3(cw - 0.18, 0.04, 0.016), Vector3(0.0, cy - ch * (0.05 + t), face - 0.008))
		k.color = PLATE
		for tx: float in [-1.0, 1.0]:
			k.box(Vector3(0.11, 0.04, 0.008), Vector3(tx * (cw * 0.5 - gs - 0.07), cy - ch * 0.36, face - 0.004))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = width * height * depth * 0.5
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, depth + 0.04)
	shape.collision = col
	return shape


# --- v4 fittings (docs/V4_PIPELINE.md) ------------------------------------------------

## A see-through mesh grid panel: a bolted galvanised frame round a galvanised grid of thin bars
## (`cell` apart), standing in the XY plane, `thickness` deep along Z. Lift cages, the
## corridor ceilings and service-trench covers that show the pipes and looms behind them.
## Collision is the whole panel (tools cut it; nothing passes through the holes).
static func mesh_panel(width: float, height: float, thickness: float = 0.03, cell: float = 0.08,
		frame: float = 0.05) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var hw := width * 0.5
	var hh := height * 0.5
	var fw := minf(frame, minf(width, height) * 0.2)
	# The frame, galvanised.
	k.color = GALVANISED
	k.box(Vector3(width, fw, thickness), Vector3(0.0, hh - fw * 0.5, 0.0))
	k.box(Vector3(width, fw, thickness), Vector3(0.0, -hh + fw * 0.5, 0.0))
	k.box(Vector3(fw, height - fw * 2.0, thickness), Vector3(-hw + fw * 0.5, 0.0, 0.0))
	k.box(Vector3(fw, height - fw * 2.0, thickness), Vector3(hw - fw * 0.5, 0.0, 0.0))
	# Bolts in the frame's corners, both faces.
	k.color = FLANGE_BOLT
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				k.box(Vector3(fw * 0.4, fw * 0.4, 0.006), Vector3(sx * (hw - fw * 0.5), sy * (hh - fw * 0.5), sz * (thickness * 0.5 + 0.003)))
	# The grid: upright bars and cross bars, each a thin strip the depth of the panel's
	# middle, woven a little (uprights proud one way, cross bars the other).
	k.color = PNL_MESH
	var inner_w := width - fw * 2.0
	var inner_h := height - fw * 2.0
	var bar := 0.006
	var deep := thickness * 0.5
	var cols := maxi(1, int(round(inner_w / cell)))
	var rows := maxi(1, int(round(inner_h / cell)))
	for i in range(1, cols):
		var x := -hw + fw + inner_w * float(i) / float(cols)
		k.box(Vector3(bar, inner_h, deep), Vector3(x, 0.0, -deep * 0.25))
	for j in range(1, rows):
		var y := -hh + fw + inner_h * float(j) / float(rows)
		k.box(Vector3(inner_w, bar, deep), Vector3(0.0, y, deep * 0.25))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = (width * height - inner_w * inner_h) * thickness + (cols + rows) * bar * deep * maxf(inner_w, inner_h)
	var col := BoxShape3D.new()
	col.size = Vector3(width, height, thickness)
	shape.collision = col
	return shape
