# Co-op hand connection

Each controller owns one dancer. Controller one drives the black dancer and
controller two drives the white dancer. LB always refers to that dancer's left
hand and RB to the right hand.

## Held readiness and catch assist

Holding LB or RB makes the corresponding hand willing to connect. Releasing the
bumper removes that hand's readiness. If no willing partner hand is nearby, the
hand stays ready only for as long as the bumper remains physically held. A
waiting hand has a small opposite-colour ring.

A catch requires both endpoints to be willing. It accepts the nearest willing,
free partner hand within 54 px and below 280 px/s relative hand speed. Any left
or right hand can pair with any willing partner hand. Releasing either
endpoint's side-relevant bumper releases that connection immediately. The
partner remains ready if their own bumper is still held, and both endpoints
receive a short 0.35 s re-catch cooldown.

The first 0.22 s uses a stronger spring-damper to pull the hands together. This
is magnetic capture assistance, not a body teleport: dancer position, rotation,
and momentum remain physical throughout the snap.

## One or two physical holds

Every connection is an off-centre spring-damper between the actual hand
positions. One handhold behaves like a loose hinge. A second handhold adds a
second independent physical constraint; it does not switch to a special couple
controller.

Therefore, during both single and double holds:

- Each player's LS continues applying that dancer's screen-space movement.
- Each player's RS continues setting that dancer's own facing target.
- LT and RT continue flexing only the corresponding left or right arm.
- A minimal 12 px torso collider remains active in free and single holds.
- A double hold disables only dancer-to-dancer collision, allowing a close
  two-hand dance frame; arena-wall collision remains active.
- Turns, pulls, orbits, under-arm motion, and releases emerge from player input
  and the two hand constraints rather than input averaging.

When LS and RS are neutral, their motors apply no force or torque. The dancer
remembers the last RS direction for the next gesture but does not actively hold
that heading, so a connected partner can physically guide both translation and
rotation.

## Physical axis locks

L3 and R3 are held controls, not toggles:

- Holding L3 anchors world position with a stiff spring-damper, suppresses the
  LS motor, and leaves rotation free.
- Holding R3 anchors orientation with a stiff torque spring-damper, suppresses
  the RS motor, and leaves translation free.
- Holding both anchors both axes.

The locks remain slightly compliant under extreme hand forces rather than
teleporting or directly overwriting momentum.

The normal hold uses stiffness 42 and damping 8. Beyond 36 px, an additional
bounded tether force resists separation; no position correction or injected
separation impulse is used. Total constraint force per handhold is capped at
4200. Releasing a hold removes only that relationship and preserves both
dancers' current linear and angular momentum.

## Telemetry

Samples distinguish `free`, `single`, and `double` holds. They record all four
held-bumper readiness states, both connection pairings and forces, catch
cooldown, snap time remaining, maximum-separation activation, collision
suppression, both lock states and applied lock forces, and the separate LS, RS,
LT, and RT state for each dancer.
