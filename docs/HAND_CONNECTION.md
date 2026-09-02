# Hand connection

Connected hands use a soft spring plus a firm maximum-separation tether.

Each drawn hand has a 9 px radius, so one hand width is 18 px. The connection
may stretch, but the two hand centres must remain no more than two hand widths
(36 px) apart under maximum opposing input or rapid arm retraction.

## Ordinary response

The spring uses a stiffness of 32 and damping of 6. This retains visible leeway
and elastic motion while settling substantially faster than the original
18 / 2.2 tuning.

## Separation limit

`maximum_hand_separation` is 36 px. The connection predicts separation from
the current relative hand velocity and cancels only velocity that would cross
the limit. If moving arm anchors or an earlier physics step already placed the
hands beyond the limit, an inverse-mass-weighted positional correction brings
them back to 36 px. Tangential and converging motion are preserved.

`maximum_numerical_safety_force` still limits the ordinary spring force. It is
not the separation limit.

## Telemetry

Connection samples report `separation_limit_active`,
`separation_position_correction`, and `separation_velocity_impulse`. These
distinguish ordinary spring behavior from frames where the firm tether had to
intervene. Captures also record `maximum_hand_separation` in their configuration.
