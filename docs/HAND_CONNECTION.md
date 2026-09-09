# Co-op hand connection

Each controller owns one dancer. Controller one drives the black dancer and
controller two drives the white dancer. LB always refers to that dancer's left
hand and RB to the right hand.

## Hold to prime, release to latch

Holding LB or RB makes the corresponding hand willing to connect. Releasing the
bumper before a catch removes that hand's priming. If no willing partner hand is
nearby, the hand stays primed only for as long as the bumper remains physically
held. A waiting hand has a small opposite-colour ring.

A catch requires both endpoints to be willing. It accepts the nearest willing,
free partner hand within 54 px and below 280 px/s relative hand speed. Any left
or right hand can pair with any willing partner hand. A successful catch
consumes both primed states and latches the physical connection. The original
bumper releases do not disconnect it.

After an endpoint's catch bumper has returned up, its next fresh press releases
that specific handhold. The release press is consumed until it comes up again,
so it cannot prime an immediate re-catch. In a double hold, each handhold keeps
its own latch and either connected endpoint can tap its side-relevant bumper to
release only that pair. Released endpoints receive a short 0.35 s re-catch
cooldown.

The first 0.22 s increases the pull that brings the hands together. This is
magnetic capture assistance, not a rigid joint: dancer rotation and momentum
remain physical throughout the snap.

## One or two physical holds

Every connection is an off-centre spring-damper between the actual hand
positions. One handhold behaves like a loose hinge. A second handhold adds a
second independent physical constraint; it does not switch to a special couple
controller.

Therefore, during both single and double holds:

- Each player's LS continues applying that dancer's screen-space movement.
- Each player's RS continues setting that dancer's own facing target.
- LT and RT continue flexing only the corresponding left or right arm.
- D-pad Left/Right adjusts neutral shoulder adduction/abduction; Up/Down adjusts
  forward/backward sweep. Each axis requires matching directions from both
  players at all times, including while apart. Diagonals combine axes; one player alone
  cannot change the neutral pose. Both dancers receive the same angular change
  up to either partner's limit, preserving any pre-existing pose difference.
- A 20 px torso collider remains active in free, single, and double
  holds. The 25-degree forward arm frame leaves it clear in a natural two-hand
  pose, while the circles prevent the body centres from collapsing together.
- Turns, pulls, orbits, under-arm motion, and releases emerge from player input
  and the two hand constraints rather than input averaging.

When LS and RS are neutral, their motors apply no force or torque. The dancer
remembers the last RS direction for the next gesture but does not actively hold
that heading, so a connected partner can physically guide both translation and
rotation.

## Stable spring integration

Spring forces use a backward-Euler step with the effective inverse mass at both
hands, including each arm's rotational lever and the current body inertia. This
prevents damping from overshooting and reversing endpoint velocity each tick.
When two holds share the bodies, a conservative two-pair response budget prevents
the independently applied forces from overcorrecting together. Forces are still
equal and opposite at the physical hand positions, with the existing force cap;
there is no added rotation snap, velocity reset, or artificial settling timer.

The current branch retained explicit springs; the earlier `e0bed60` rigid-joint
fix is not in its ancestry. The September 9 capture reproduced alternating spin
even with pre-weight masses restored, so the new visual hands were not the cause.
The regression fixture in `tests/fixtures/handhold-stability-2026-09-09.json`
preserves that capture's initial state and exact input-change frames. Run
`tests/handhold_replay_test.gd`; `--extreme-weights` also exercises 100/50 kg.
The replay asserts low sustained spin-step RMS after input stops, in addition
to bounded hand separation. Configuration records `implicit_endpoint_mass`.

## Physical axis locks

L3 and R3 are held controls, not toggles:

- Holding L3 anchors world position with a stiff spring-damper, suppresses the
  LS motor, and leaves rotation free.
- Holding R3 anchors orientation with a stiff torque spring-damper, suppresses
  the RS motor, and leaves translation free.
- Holding both anchors both axes.

The locks remain slightly compliant under extreme hand forces rather than
teleporting or directly overwriting momentum.

The hold continuously changes character with relative hand speed. At or below
80 px/s it uses a stiff, well-damped response that feels close to a weld. From
80 to 500 px/s it eases into a softer elastic response. At 500 px/s and above,
normal damping is only 2 and tangential damping only 0.5, so a fast separation
stores useful spring tension without killing an orbit or turn. Damping is split
into normal and tangential components specifically to preserve dance momentum.

At 36 px the hands reach a geometric safety limit. Excess distance and only the
separating component of velocity are projected out, weighted by inverse mass
and respecting L3 position locks; converging, tangential, and angular motion are
left intact. Projection begins 0.75 px early to absorb one physics tick of
solver motion without visibly exceeding the limit. If both dancers are position-locked, the bounded safety spring is
used instead because neither body may be moved. Total constraint force per
handhold remains capped at 4200. Releasing a hold removes only that relationship
and preserves both dancers' current linear and angular momentum.

## Telemetry

Samples distinguish `free`, `single`, and `double` holds. For each hand they
record physical button-down, primed, and release-tap-armed state. They also
record both connection pairings and forces, each pair's weld-to-elastic blend,
catch cooldown, snap time remaining, maximum-separation activation, collision
suppression, both lock states and applied lock forces, and the separate LS, RS,
LT, and RT state for each dancer.
