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

For the first 0.22 seconds, the accepted gap closes along a smoothstep curve.
The curve starts and finishes at zero speed, so the dancers glide into contact
without a teleport, overshoot, or rebound. The displacement is divided through
the bodies' inverse mass and hand leverage, making the lighter partner move
more. This acquisition is a geometric transition, not a spring.

## Rigid hand joints

After acquisition, every connection is an exact point joint between the actual
hand endpoints. One-hand and two-hand holds use the same zero-gap positional and
velocity constraint. There is no spring, elasticity, directional exception, or
permitted stretch.

A point joint owns no relative body orientation. One dancer can therefore turn
and orbit under the other's anchored hand while their connected hands remain at
the same point. In a double hold, both point joints together form a rigid
two-point frame without directly welding either dancer's body rotation.

In a double hold, triggers remain independent requests. For each connected pair, the achieved
contraction advances only to the lesser of the two partners' requests. One
partner can therefore ask for more flexion, but the arm and frame budge only as
far as the other partner permits. The requesting dancer's entire arm and hand shift
toward bright red when its request exceeds the partner's by more than 10%,
with a smooth colour fade above that quiet zone. Before solving the
contacts, the arm geometry
is projected so the two local hand spans match; this removes the impossible
geometry that formerly made the two constraints fight and oscillate.

Trigger and D-pad changes share a continuous geometry limit. Starting from the
last achieved pose, the system checks small steps along the proposed change,
matches the hand spans, and stops at the first pose that would violate torso
clearance. It keeps a 0.05 px clearance margin around the actual torso circles.
It cannot skip an impossible interval to switch a front hold into a rear hold
or vice versa. Geometry checks change arm parameters only, never body transforms.
The existing hand joints continue to respond to forces and body motion.

Blocked requests do not accumulate. Releasing a trigger or reversing D-pad input
moves away from the limit immediately when that direction is reachable. Stance
telemetry reports the achieved D-pad angles. Matching trigger requests remain
their normal colour; the geometry limit alone does not turn the arms red.
The fit-weight setting does not change the limit.

A back-to-back hold retains its small reachable contraction range. There is no
blanket trigger disable, no automatic front/rear conversion, and no extra arm
contraction to rescue an impossible D-pad stance. Release one hand to reposition
when a two-hand transition is blocked. One-hand and free-arm stance controls
retain their full anatomical range. If a newly acquired second contact cannot
form a compatible frame, only that new contact is released.

Both visual styles use hybrid's identical mechanical skeleton. Effort is the
positive difference between requested and achieved flexion, not a measurement
of joint force. The tint instead uses the partners' request mismatch so small
differences and matching full tuck stay neutral. Palm supination follows the achieved pose, even when a trigger
requests more flexion than the hold permits.

Therefore, during both single and double holds:

- Each player's LS continues applying that dancer's screen-space movement.
- Each player's RS angle is that dancer's screen-space heading target. Small
  travel gives gentle, eased correction and full travel gives the strongest
  response. Full outer-ring circles remain continuous; overload selects the
  shortest heading correction rather than accumulating unfinished revolutions.
- In free and one-hand motion, LT and RT flex only the corresponding arm. In a
  two-hand frame they remain individual requests, while achieved connected-arm
  flexion is limited by the partner at that contact.
- A fixed 20 px torso collider remains active in free, single, and double
  holds. The 25-degree forward arm frame leaves it clear in a natural two-hand
  pose, while the circles prevent the body centres from collapsing together.
- Turns, pulls, orbits, under-arm motion, and releases emerge from player input
  and the two hand constraints rather than input averaging.

While connected, LS retains the original force-driven movement: neutral LS
applies no walking force, so the partner can guide the dancer through the grip.
While free, LS requests a walking velocity through bounded ground forces;
neutral LS brakes self-driven travel promptly. When RS returns to the deadzone,
RS-driven rotation stops immediately and does not continue toward its previous
angle. The handhold is still allowed to rotate the dancer physically, so a
neutral partner is not an implicit orientation lock.

RS-driven motion of a held hand contributes to the joint's velocity constraint,
even though RS does not add free spin to its owner's body. Circling a partner
therefore builds actual travelling velocity before release. Letting go removes
the joint without adding a throw impulse or cutting the existing velocity.
With LS centred, the released dancer retains a short partner-derived coast. LS along the
travel direction sustains or increases it; opposite LS brakes and can eventually
reverse it; sideways LS redirects it through force. Position locks still resist
travel when explicitly enabled.

The original RS heading response is retained. Both dancers can receive the
joint's turning reaction, including while using RS; only an explicit rotation
lock removes that freedom. Position and velocity solving use the same rotational
freedom. RS alone still adds no physical spin, but a held partner can push back
and cause physical rotation. Release preserves that existing spin too.

Carry is attributed from actual joint velocity impulses, never from positional
alignment. It is reconciled with the body's real travelling velocity, so a wall
collision or a reaction opposing a blocked step cannot store a later kick.
Solo walking does not replenish carry. The recorded carry decays at 3.5/s;
double holds use 8/s, leaving less protected coast when the last hand releases.
This bookkeeping does not change held movement forces. The decay rate blends
over time when grips change. Neither a catch nor a release resets velocity or
carry. Ground support blends between held and free behavior over 0.125 seconds.
Held damping retains the original 2.2 plus the project's default damping; free
movement uses motor resistance with zero linear damping in replacement mode.
Physical spin damping, rigid hand constraints, trigger-driven arm poses, and
double-hold geometry retain their original behavior.

## Physical axis locks

L3 and R3 are independent press-to-toggle controls:

- Pressing L3 anchors world position with a stiff spring-damper, suppresses the
  LS motor, and leaves rotation free. Press L3 again to release it.
- Pressing R3 anchors orientation with a stiff torque spring-damper, suppresses
  the RS motor, and leaves translation free. Press R3 again to release it.
- Enabling both anchors both axes.

The locks remain slightly compliant under extreme hand forces rather than
teleporting or directly overwriting momentum. Releasing a hand removes only its
joint and preserves both dancers' current linear and angular momentum.

## Telemetry

Samples distinguish `free`, `single`, and `double` holds and identify the
`joint` solver. For each hand they
record physical button-down, primed, and release-tap-armed state. They also
record both connection pairings, measured and acquisition-authorized separation,
smooth acquisition progress, position and velocity correction, catch cooldown,
collision state, both toggle-lock states and applied lock forces, double-hold
orbital/alignment measurements, and the separate LS, RS, LT, and RT state for
each dancer. Double-hold samples also record each contact's mutual flexion
permission and each arm's unfulfilled effort.

The additive `double_hold_pose_limited` flag records when a trigger or stance
request reaches the connected frame's geometry limit.

The combined configuration uses `dancers-coop-telemetry-v11`, solver `joint`,
and facing mode `radial_heading_response`. See [RECONCILIATION.md](RECONCILIATION.md)
for the source versions and precedence decisions.
