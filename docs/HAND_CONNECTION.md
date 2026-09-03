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

The first 0.22 s uses the firmest closing response while the hands settle. Any
part of the initial catch gap outside the hard tether is corrected immediately;
the connection never begins in an overstretched state.

## One or two physical holds

Each connection is a radial, damped constraint between the actual hand
endpoints. It asks for a bounded closing speed instead of stacking a spring
force, a full velocity weld, and repeated position rotation. The response uses
the two bodies' effective mass at the hands, including arm leverage, so it does
not overshoot merely because an arm is extended.

Below 80 px/s, a hold closes firmly toward a 2 px fingertip overlap and removes
only a controlled fraction of relative hand motion each tick. From 80 to 400
px/s it changes smoothly toward a softer response with very little tangential
damping. That fast one-hand region can stretch and rebound while preserving an
orbit. The hard limit remains independent of this blend.

A double hold uses the same two radial constraints in their conservative
response. It does not weld dancer orientation, align the bodies, average input,
or alter either arm's trigger target. The two contact points themselves provide
the frame leverage.

Therefore, during both single and double holds:

- Each player's LS continues applying that dancer's screen-space movement.
- Outside the deadzone, each player's RS angle is that dancer's absolute
  screen-space facing target. Partial and full travel at the same angle are
  identical. The dancer turns toward it at the configured turn-rate limit,
  without torque, acceleration buildup, overshoot, or circular-stick history.
- LT and RT continue flexing only the corresponding left or right arm.
- A minimal 12 px torso collider remains active in free, single, and double
  holds. The 25-degree forward arm frame leaves it clear in a natural two-hand
  pose, while the circles prevent the body centres from collapsing together.
- Turns, pulls, orbits, under-arm motion, and releases emerge from player input
  and the two hand constraints rather than input averaging.

When LS is neutral, its motor applies no force. When RS returns to the deadzone,
RS-driven rotation stops immediately and does not continue toward its previous
angle. The handhold is still allowed to rotate the dancer physically, so a
neutral partner is not an implicit orientation lock.

## Physical axis locks

L3 and R3 are independent press-to-toggle controls:

- Pressing L3 anchors world position with a stiff spring-damper, suppresses the
  LS motor, and leaves rotation free. Press L3 again to release it.
- Pressing R3 anchors orientation with a stiff torque spring-damper, suppresses
  the RS motor, and leaves translation free. Press R3 again to release it.
- Enabling both anchors both axes.

The locks remain slightly compliant under extreme hand forces rather than
teleporting or directly overwriting momentum.

At 27 px—one and a half 18 px hand diameters—the hands reach an unconditional
geometric limit. A small prediction margin, eight position passes, and one
separating-velocity pass keep the rendered endpoints inside it. These safety
corrections use effective mass and arm leverage but act only along the current
hand gap; they do not weld all motion at the contact.

A hand is allowed behind one dancer, which is necessary for an underarm turn.
Only mutual dorsal separation—each connected hand displaced behind the other
dancer at the same time—collapses to the 2 px firm-contact distance. This is one
anatomical rule, not two competing body-relative half-planes.

The elastic blend opens quickly under a fast maneuver and closes more slowly,
creating damped recoil instead of switching abruptly between responses.
Releasing a hold removes only that relationship and preserves both dancers'
current linear and angular momentum.

## Telemetry

Samples distinguish `free`, `single`, and `double` holds. For each hand they
record physical button-down, primed, and release-tap-armed state. They also
record both connection pairings, each pair's measured and authorized separation,
single-hold elastic blend, position and velocity correction, dorsal and radial
limit activation, catch cooldown, collision suppression, both toggle-lock states
and applied lock forces, double-hold orbital/alignment measurements, and the
separate LS, RS, LT, and RT state for each dancer.
