# Single-controller hand connection

One controller drives both dancers:

- LS moves the black dancer.
- RS moves the white dancer.
- LT contracts or extends both independently modelled arms of the black dancer.
- RT contracts or extends both independently modelled arms of the white dancer.
- The D-pad changes the shared extended-arm stance for both dancers.
- LB controls the black dancer's grip intention.
- RB controls the white dancer's grip intention.

With released triggers, neither dancer requests any spin. Contracting a
dancer's arms creates and progressively raises that dancer's target spin speed.
Through the existing arm-to-move ratio, contraction can also increase movement
speed. L3 reverses the black dancer's selected spin direction; R3 independently
reverses the white dancer's.

## Hold to prime, release to latch

Holding LB primes whichever black hand is currently closest to either white
hand. Holding RB does the same for the white dancer. A small opposite-colour
ring marks each currently selected candidate hand.

A catch requires both LB and RB to remain held. The system chooses the single
closest eligible black-white hand pair within 54 px and below 280 px/s relative
hand speed. It latches exactly that one pair; no second or double hold can form.

A successful catch consumes both primed states. Releasing the bumpers after the
catch does not disconnect the hands. Once a bumper has returned up, its next
fresh press releases the hold. Either LB or RB can perform that release. The
release press is consumed until it comes up again, preventing an immediate
re-catch. All hands receive a short 0.35 s catch cooldown.

The first 0.22 s uses the firmest closing response while the hands settle. Any
catch gap outside the hard tether is corrected by the constraint on the next
physics step.

## Physical one-hand spring

The retained coop solver is a radial, damped constraint between the actual hand
endpoints. It asks for a bounded closing speed instead of stacking a spring
force, a full velocity weld, and repeated position rotation. The response uses
the two bodies' effective mass at the hands, including arm leverage, so an
extended arm does not make it overshoot.

Below 80 px/s, the hold closes firmly toward a 2 px fingertip overlap and removes
only a controlled fraction of relative hand motion each tick. From 80 to
400 px/s it changes smoothly toward a softer response with very little
tangential damping. That fast region can stretch and rebound while preserving
an orbit. The elastic blend opens quickly under a fast maneuver and closes more
slowly, creating damped recoil instead of abrupt switching.

The connection never averages movement, changes trigger-driven spin targets, or
replaces the trigger-driven arm pose. Movement, turns, pulls, and under-arm
motion emerge from the two dancers and the single off-centre spring.

At 27 px—one and a half 18 px hand diameters—the hands reach an unconditional
geometric limit. A prediction margin, eight position passes, and one
separating-velocity pass keep the rendered endpoints inside it. The correction
acts only along the current hand gap.

A hand may pass behind one dancer during an under-arm turn. Only mutual dorsal
separation—each connected hand displaced behind the other dancer at the same
time—collapses to the 2 px firm-contact distance. Releasing the spring removes
only that relationship and preserves both dancers' linear and angular momentum.

Minimal 12 px torso colliders remain active in free and connected motion so the
body centres cannot collapse into the same space.

## Telemetry

Captures distinguish free and single hold states. For each hand they record
button-down, candidate priming, and release-tap state. Connection data includes
the selected pair, measured and authorized separation, elastic blend, position
and velocity correction, dorsal and radial limit activation, snap time, catch
cooldown, force, and solver mode.
