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

The accepted catch gap closes over 0.22 seconds using co-op's smoothstep
acquisition curve. Corrections use the actual body masses and hand leverage.

## Rigid one-hand hold

After acquisition, the actual hand endpoints share a zero-gap point joint.
Position and velocity constraints replace the older elastic spring, 27 px
tether, and mutual-dorsal exception. The joint does not prescribe relative body
orientation: turning, pulling and orbiting remain possible around the hand.

The connection does not average movement, change trigger-driven spin targets,
or replace either dancer's trigger-driven arm pose. Releasing the hold preserves
both dancers' linear and angular momentum. There is still exactly one connection;
co-op's double-hold flexion permission and red request-mismatch tint do not apply.

Existing 12 px torso colliders, 1.2 body masses, individual skeleton dimensions,
and movement/spin tuning are retained. New artwork does not change these values.

## Telemetry

Captures use `dancers-single-controller-telemetry-v2` and solver mode `joint`.
They distinguish free and single holds, record candidate priming and release-tap
state, selected pair, measured and acquisition-authorized separation, smooth
acquisition progress, position/velocity corrections, cooldown and solver iterations.
Old spring-force, compliance and dorsal-limit fields have been removed.
