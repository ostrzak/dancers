"""Author the single-player ghost catalogue and exact future narration scripts.

Offline only. Run from any directory; no audio generation or network requests.
Resources and voiceover markdown are generated together to keep variant IDs exact.
"""
from pathlib import Path
import json
import math
import re

ROOT = Path(__file__).resolve().parents[1]
PI = math.pi
TAU = math.tau
CATALOGUE = []
PREVIEW = "Use the other bumper to catch the second pair; each bumper releases its own pair."


def key(time, **values):
    return dict(time=float(time), centre=(640, 320), turn=0.0,
                partner_turn=PI, flexion=0.0, partner_flexion=0.0, **values)


def pose(time, **values):
    result = key(time)
    result.update(values)
    return result


def add(identifier, title, label, description, narration, keys, *, mode="free",
        mirror=None, mirrored_description=None, mirrored_narration=None,
        requirement=""):
    item = dict(id=identifier, title=title, label=label, description=description,
                narration=narration, keys=keys, mode=mode, requirement=requirement,
                duration=float(keys[-1]["time"]), variants=[])
    CATALOGUE.append(item)
    if mirror:
        item["variants"].append(dict(item, id=identifier + "_mirrored", label=mirror,
            description=mirrored_description or description,
            narration=mirrored_narration or narration, mirror_of=identifier,
            variants=[]))
    return item


add("two_planets", "Two planets", "Clockwise",
    "No hold. Use both sticks to orbit clockwise around a shared midpoint. Keep triggers released and body facing steady.",
    "The partners remain opposite each other and travel clockwise around a shared midpoint. Keep the triggers released. Guide the gentleman with the left stick and the lady with the right stick. Their floor paths circle while their bodies keep the same facing.",
    [pose(t, turn=-PI/2, partner_turn=PI/2, position_a=(-115, 0), position_b=(115, 0), path_turn=p)
     for t, p in [(0, 0), (1, 0), (13, TAU), (14, TAU)]],
    mirror="Counterclockwise",
    mirrored_description="No hold. Use both sticks to orbit counterclockwise around a shared midpoint. Keep triggers released and body facing steady.",
    mirrored_narration="The partners remain opposite each other and travel counterclockwise around a shared midpoint. Keep the triggers released. Guide the gentleman with the left stick and the lady with the right stick. Their floor paths circle while their bodies keep the same facing.")

spins = None
for label, a_spin, b_spin, suffix in [
    ("Both spin clockwise", 1, 1, ""),
    ("Both spin counterclockwise", -1, -1, "_reverse_spins"),
    ("Gentleman CW / lady CCW", 1, -1, "_opposite"),
    ("Gentleman CCW / lady CW", -1, 1, "_opposite_reverse"),
]:
    a_word = "clockwise" if a_spin > 0 else "counterclockwise"
    b_word = "clockwise" if b_spin > 0 else "counterclockwise"
    keys = [pose(t, turn=-PI/2 + a_spin*p, partner_turn=PI/2 + b_spin*p,
                 position_a=(-115, 0), position_b=(115, 0), path_turn=p,
                 flexion=f, partner_flexion=f)
            for t, p, f in [(0, 0, 0), (1, 0, .3), (13, TAU, .3), (14, TAU, 0)]]
    item = add("spinning_planets" + suffix, "Spinning planets", "Orbit CW / " + label,
        f"No hold. Orbit clockwise with both sticks. Use triggers to spin: gentleman {a_word}, lady {b_word}. L3/R3 reverse spin direction.",
        f"Both partners travel clockwise around their shared midpoint. Add gentle trigger pressure: the gentleman spins {a_word}, and the lady spins {b_word}. The left and right stick clicks reverse their respective spin directions. Keep the orbital path broad as the bodies turn.",
        keys, mirror="Orbit CCW / " + ("Both spin " + ("counterclockwise" if a_spin > 0 else "clockwise") if a_spin == b_spin else "Gentleman " + ("CCW" if a_spin > 0 else "CW") + " / lady " + ("CCW" if b_spin > 0 else "CW")),
        mirrored_description=f"No hold. Orbit counterclockwise. Use triggers to spin: gentleman {'counterclockwise' if a_spin > 0 else 'clockwise'}, lady {'counterclockwise' if b_spin > 0 else 'clockwise'}. L3/R3 reverse spins.",
        mirrored_narration=f"Both partners travel counterclockwise around their shared midpoint. Add gentle trigger pressure: the gentleman spins {'counterclockwise' if a_spin > 0 else 'clockwise'}, and the lady spins {'counterclockwise' if b_spin > 0 else 'clockwise'}. The left and right stick clicks reverse their respective spin directions. Keep the orbital path broad as the bodies turn.")
    if spins is None:
        spins = item
    else:
        CATALOGUE.pop()
        spins["variants"].append(dict(item, variants=[]))
        spins["variants"].extend(item["variants"])

add("do_si_do", "Do-si-do", "Right shoulders",
    "No hold. Pass right shoulders, go behind each other, then return. Keep triggers released to preserve facing.",
    "Start facing your partner with no hand contact. Pass right shoulders on separate lanes, travel behind one another, and return to your original places. Use the two sticks for the floor path and leave the triggers released. Keep your original facing throughout.",
    [pose(t, position_a=a, position_b=(-a[0], -a[1]))
     for t, a in [(0, (0,-115)), (1,(0,-115)), (4,(-90,0)), (7,(0,115)), (10,(90,0)), (13,(0,-115)), (14,(0,-115))]],
    mirror="Left shoulders",
    mirrored_description="No hold. Pass left shoulders, go behind each other, then return. Keep triggers released to preserve facing.",
    mirrored_narration="Start facing your partner with no hand contact. Pass left shoulders on separate lanes, travel behind one another, and return to your original places. Use the two sticks for the floor path and leave the triggers released. Keep your original facing throughout.")

add("mirror_slalom", "Mirror slalom", "Travel right",
    "No hold. Steer right together, widening and narrowing the gap in mirrored curves. Leave triggers released.",
    "The partners travel toward the right side of the floor. Guide them along mirrored curves, widening their separation and then bringing them closer. Keep the triggers released and preserve room between the bodies. Let the two sticks trace the changing lanes together.",
    [pose(t, centre=(x,320), position_a=(0,-gap), position_b=(0,gap), turn=-PI/2, partner_turn=-PI/2,
          arc_a=(0,-25 if gap < 100 else 25), arc_b=(0,25 if gap < 100 else -25))
     for t,x,gap in [(0,420,85),(1,420,85),(4,530,145),(7,640,85),(10,750,145),(13,860,85),(14,860,85)]],
    mirror="Travel left", mirrored_description="No hold. Steer left together, widening and narrowing the gap in mirrored curves. Leave triggers released.",
    mirrored_narration="The partners travel toward the left side of the floor. Guide them along mirrored curves, widening their separation and then bringing them closer. Keep the triggers released and preserve room between the bodies. Let the two sticks trace the changing lanes together.")

add("passing_spirals", "Passing spirals", "Gentleman above",
    "No hold. Approach on offset lanes, add a short opposite-spin trigger pulse, then travel apart. Gentleman passes above the lady.",
    "Approach on separate lanes, with the gentleman above the lady on the floor. As the partners pass, add a gentle trigger pulse: the gentleman turns clockwise and the lady counterclockwise. Continue apart, then release the triggers. Leave enough space for both sets of arms.",
    [pose(t, position_a=a, position_b=(-a[0],-a[1]), turn=-PI/2+r, partner_turn=PI/2-r, flexion=f, partner_flexion=f)
     for t,a,r,f in [(0,(-210,-85),0,0),(1,(-210,-85),0,0),(5,(0,-95),PI,.3),(9,(210,-85),TAU,0),(10,(210,-85),TAU,0)]],
    mirror="Gentleman above / reverse travel",
    mirrored_description="No hold. Reverse the approach: gentleman passes above, turning counterclockwise; lady turns clockwise. Pulse triggers, then separate.",
    mirrored_narration="Approach from the reversed sides, with the gentleman above the lady on the floor. As the partners pass, add a gentle trigger pulse: the gentleman turns counterclockwise and the lady clockwise. Continue apart, then release the triggers. Leave enough space for both sets of arms.")

add("pendulum", "Pendulum", "Clockwise first",
    "One joined pair. With triggers released, steer a broad swing clockwise, reverse, and return. The sticks control each reversal.",
    "Catch one pair of hands by holding one bumper as the hands approach. Let that bumper up after the catch. With the triggers released, guide a broad swing clockwise, then reverse the path and return. Use the sticks to make the reversal; the hold does not bounce automatically.",
    [pose(t, turn=r, partner_turn=PI+r) for t,r in [(0,0),(1,0),(4,.7),(10,-.7),(13,0),(14,0)]],
    mode="single", mirror="Counterclockwise first",
    mirrored_description="One joined pair. With triggers released, steer a broad swing counterclockwise, reverse, and return. The sticks control each reversal.",
    mirrored_narration="Catch one pair of hands by holding one bumper as the hands approach. Let that bumper up after the catch. With the triggers released, guide a broad swing counterclockwise, then reverse the path and return. Use the sticks to make the reversal; the hold does not bounce automatically.")

add("moving_sun", "Moving sun", "Clockwise",
    "One joined pair. Lady takes the wide clockwise path first; gradually exchange roles so the gentleman travels farther. Steer both bodies.",
    "Keep one pair of hands joined. The gentleman first takes the smaller path while the lady travels clockwise around him. Gradually exchange roles so the gentleman takes the wider path. Guide both bodies with the sticks. Neither dancer is fixed to the floor.",
    [pose(t, turn=r, partner_turn=PI+r, anchor_weight=w, centre=(x,320))
     for t,r,w,x in [(0,0,0,570),(1,0,0,570),(7,PI,0,620),(11,PI*1.5,1,650),(17,TAU,1,700),(18,TAU,1,700)]],
    mode="single", mirror="Counterclockwise",
    mirrored_description="One joined pair. Lady takes the wide counterclockwise path first; gradually exchange roles so the gentleman travels farther.",
    mirrored_narration="Keep one pair of hands joined. The gentleman first takes the smaller path while the lady travels counterclockwise around him. Gradually exchange roles so the gentleman takes the wider path. Guide both bodies with the sticks. Neither dancer is fixed to the floor.")

add("open_out_return", "Open out and return", "Gentleman CW / lady CCW",
    "One joined pair. Open into a small opposing turn, then steer back together. Try gentle trigger pulses; contraction also requests spin.",
    "From one joined pair of hands, open into a small opposing turn. The gentleman turns clockwise and the lady counterclockwise. Use gentle trigger pressure, remembering that it contracts both arms and requests spin. Reverse the selected spin directions if needed, and guide the partners back together with the sticks.",
    [pose(t, turn=r, partner_turn=PI-r, hand_side=1, flexion=f, partner_flexion=f)
     for t,r,f in [(0,0,0),(1,0,0),(5,.65,.12),(6,.65,.12),(10,0,0),(11,0,0)]],
    mode="single", mirror="Gentleman CCW / lady CW",
    mirrored_description="One joined pair. Gentleman opens counterclockwise, lady clockwise; steer back together. Gentle trigger pressure also requests spin.",
    mirrored_narration="From one joined pair of hands, open into a small opposing turn. The gentleman turns counterclockwise and the lady clockwise. Use gentle trigger pressure, remembering that it contracts both arms and requests spin. Reverse the selected spin directions if needed, and guide the partners back together with the sticks.")

add("travelling_wheel", "Travelling wheel", "Clockwise / travel right",
    "One joined pair. Steer a clockwise orbit while moving its centre right across the floor. Start with triggers released.",
    "Keep one pair of hands joined and travel toward the right side of the floor. At the same time, guide a clockwise orbit around the space between the partners. Combine the travel and circular motion with both sticks. Begin with the triggers released and keep the path broad.",
    [pose(t, centre=(x,320), turn=r, partner_turn=PI+r) for t,x,r in [(0,430,0),(1,430,0),(13,850,TAU),(14,850,TAU)]],
    mode="single", mirror="Counterclockwise / travel left",
    mirrored_description="One joined pair. Steer a counterclockwise orbit while moving its centre left across the floor. Start with triggers released.",
    mirrored_narration="Keep one pair of hands joined and travel toward the left side of the floor. At the same time, guide a counterclockwise orbit around the space between the partners. Combine the travel and circular motion with both sticks. Begin with the triggers released and keep the path broad.")

add("release_spin_catch", "Release, spin, catch", "Lady clockwise",
    "Catch once, let that bumper up, then tap it to release. Separate, turn the lady with RT, approach slowly and hold one free bumper to recatch.",
    "Begin with one joined pair of hands. Let the catching bumper up, then tap it again to release. Steer apart and use the right trigger to turn the lady clockwise. Release the trigger, approach slowly, and hold one free bumper for a fresh catch. The catch depends on the hands meeting, not on finishing the turn.",
    [pose(t, partner_turn=PI+r, release_weight=w, release_position=(880,320), partner_flexion=f, anchor_weight=0)
     for t,r,w,f in [(0,0,0,0),(1,0,0,0),(5,0,1,0),(11,TAU,1,.3),(12,TAU,1,0),(16,TAU,0,0),(17,TAU,0,0)]],
    mode="single", mirror="Lady counterclockwise",
    mirrored_description="Catch, release with a fresh tap of its bumper, then turn the lady counterclockwise with RT. Approach slowly and hold one free bumper to recatch.",
    mirrored_narration="Begin with one joined pair of hands. Let the catching bumper up, then tap it again to release. Steer apart and use the right trigger to turn the lady counterclockwise. Release the trigger, approach slowly, and hold one free bumper for a fresh catch. The catch depends on the hands meeting, not on finishing the turn.")

# Switch hands only during a fully released interval. A stays independently
# anchored there and B follows a fixed floor position, so changing side is smooth.
add("alternating_catches", "Alternating-side catches", "Left hand first",
    "Join, release, pass around your partner, then approach for a catch on the other side. One free bumper primes the nearest eligible pair.",
    "Start with the gentleman's left hand joined to the lady's right. Release with a fresh press of the catching bumper. Guide the lady around the gentleman on a clear outside path, then approach for a catch using the other pair. Hold one free bumper near the new meeting point. The nearest eligible hands determine the catch.",
    [pose(t, anchor_weight=0, hand_side=side, release_weight=w, release_position=pos)
     for t,side,w,pos in [(0,-1,0,(440,320)),(1,-1,0,(440,320)),(4,-1,1,(440,320)),
                          (8,-1,1,(640,130)),(9,1,1,(640,130)),(13,1,1,(840,320)),
                          (16,1,0,(840,320)),(17,1,0,(840,320))]],
    mode="single", mirror="Right hand first",
    mirrored_description="Start on the gentleman's right, release, pass around, then catch on his left. One free bumper primes the nearest eligible pair.",
    mirrored_narration="Start with the gentleman's right hand joined to the lady's left. Release with a fresh press of the catching bumper. Guide the lady around the gentleman on a clear outside path, then approach for a catch using the other pair. Hold one free bumper near the new meeting point. The nearest eligible hands determine the catch.")

add("back_promenade", "Back-to-back promenade", "Travel right",
    "One rear hand pair. Use D-pad down for rearward arms, catch, then steer right together with triggers released.",
    "Sweep both dancers' extended arms backward with the D-pad. Approach back to back and catch one rear pair of hands using one bumper. Once joined, let the bumpers up and travel gently toward the right. Keep the triggers released and preserve the rear connection with both sticks.",
    [pose(t, centre=(x,y), forward_sweep=-25) for t,x,y in [(0,450,320),(1,450,320),(6,640,270),(11,830,320),(12,830,320)]],
    mode="single", mirror="Travel left",
    mirrored_description="One rear hand pair. Use D-pad down for rearward arms, catch, then steer left together with triggers released.",
    mirrored_narration="Sweep both dancers' extended arms backward with the D-pad. Approach back to back and catch one rear pair of hands using one bumper. Once joined, let the bumpers up and travel gently toward the left. Keep the triggers released and preserve the rear connection with both sticks.")

add("back_wheel", "Back-to-back wheel", "Clockwise",
    "One rear hand pair. With arms swept backward, steer a broad clockwise wheel. Keep the triggers released for the first attempt.",
    "Begin with one rear pair of hands joined and both dancers' arms swept backward. Guide a broad clockwise wheel using both sticks. Keep the triggers released on the first attempt. Maintain space between the bodies as the rear connection travels around the midpoint.",
    [pose(t, turn=r, partner_turn=PI+r, forward_sweep=-25) for t,r in [(0,0),(1,0),(13,TAU),(14,TAU)]],
    mode="single", mirror="Counterclockwise",
    mirrored_description="One rear hand pair. With arms swept backward, steer a broad counterclockwise wheel. Start with triggers released.",
    mirrored_narration="Begin with one rear pair of hands joined and both dancers' arms swept backward. Guide a broad counterclockwise wheel using both sticks. Keep the triggers released on the first attempt. Maintain space between the bodies as the rear connection travels around the midpoint.")

add("back_face_catch", "Behind, release, face, catch", "Gentleman CW / lady CCW",
    "Release the rear hold, separate, turn toward each other, restore the forward arm stance and approach for a front catch.",
    "Begin with a rear hand connection. Let the catching bumper up, then tap it again to release. Move apart and turn toward each other: the gentleman clockwise and the lady counterclockwise. Sweep the extended arms forward again with the D-pad. Approach slowly and hold one free bumper for a new front catch.",
    [pose(t, turn=r, partner_turn=PI-r, forward_sweep=sweep, release_weight=w, release_position=pos, anchor_weight=0, flexion=f, partner_flexion=f)
     for t,r,sweep,w,pos,f in [(0,0,-25,0,(860,380),0),(1,0,-25,0,(860,380),0),
                              (5,0,-25,1,(860,380),0),(10,PI,25,1,(860,380),.2),
                              (11,PI,25,1,(860,380),0),(15,PI,25,1,(860,180),0),
                              (19,PI,25,1,(640,180),0),(23,PI,25,0,(640,180),0),(24,PI,25,0,(640,180),0)]],
    mode="single", mirror="Gentleman CCW / lady CW",
    mirrored_description="Release the rear hold and separate. Gentleman turns CCW, lady CW; restore forward arms, then approach for a front catch.",
    mirrored_narration="Begin with a rear hand connection. Let the catching bumper up, then tap it again to release. Move apart and turn toward each other: the gentleman counterclockwise and the lady clockwise. Sweep the extended arms forward again with the D-pad. Approach slowly and hold one free bumper for a new front catch.")

add("open_close", "Open and close", "",
    "Two-hand hold. Draw both arms inward, pause, then extend together. Explore the arm contraction while maintaining the hold.",
    "Catch the first pair with one bumper and the second pair with the other. The partners face each other with both pairs joined. Draw both arms inward, pause, then extend together. This reference shows the inward and outward arm phrase; trigger pressure also requests spin. Each bumper remains assigned to the pair it caught.",
    [pose(t, flexion=f) for t,f in [(0,0),(1,0),(5,.5),(6,.5),(10,0),(11,0)]],
    mode="double", requirement=PREVIEW)

add("turning_open_close", "Turning open and close", "Clockwise",
    "Two-hand hold. Close while the pair turns clockwise, then open. Try opposite selected spins and steer the shared turn.",
    "Catch the first pair with one bumper and the second pair with the other. The partners draw their arms inward while turning clockwise as a pair, then open again. Try opposite selected spin directions and steer the pair; the hold determines the physical response. This demonstration shows the intended phrase.",
    [pose(t, turn=r, flexion=f) for t,r,f in [(0,0,0),(1,0,0),(7,PI,.5),(13,TAU,0),(14,TAU,0)]],
    mode="double", requirement=PREVIEW, mirror="Counterclockwise",
    mirrored_description="Two-hand hold. Close while the pair turns counterclockwise, then open. Try opposite selected spins and steer the shared turn.",
    mirrored_narration="Catch the first pair with one bumper and the second pair with the other. The partners draw their arms inward while turning counterclockwise as a pair, then open again. Try opposite selected spin directions and steer the pair; the hold determines the physical response. This demonstration shows the intended phrase.")

add("concertina", "Concertina travel", "Travel right",
    "Two-hand hold. Travel right while closing and opening twice. Both arms of each dancer move together.",
    "Catch the first pair with one bumper and the second pair with the other. Travel toward the right side of the floor while closing and opening the hold twice. Both arms of each dancer move together. Keep the travel smooth so the repeated inward and outward movement remains easy to see.",
    [pose(t, centre=(x,320), flexion=f) for t,x,f in [(0,440,0),(1,440,0),(5,540,.5),(9,640,0),(13,740,.5),(17,840,0),(18,840,0)]],
    mode="double", requirement=PREVIEW, mirror="Travel left",
    mirrored_description="Two-hand hold. Travel left while closing and opening twice. Both arms of each dancer move together.",
    mirrored_narration="Catch the first pair with one bumper and the second pair with the other. Travel toward the left side of the floor while closing and opening the hold twice. Both arms of each dancer move together. Keep the travel smooth so the repeated inward and outward movement remains easy to see.")

add("side_sway", "Side-to-side sway", "Right first",
    "Two-hand hold. Travel right, then left, and return to centre. Add a small inward arm pulse at each reversal.",
    "Catch the first pair with one bumper and the second pair with the other. Travel together to the right, then to the left, and return to the centre. Add a small inward arm pulse near each reversal. Let the lateral travel and the arm movement form one gentle phrase.",
    [pose(t, centre=(x,320), flexion=f) for t,x,f in [(0,640,0),(1,640,0),(5,800,.3),(9,640,0),(13,480,.3),(17,640,0),(18,640,0)]],
    mode="double", requirement=PREVIEW, mirror="Left first",
    mirrored_description="Two-hand hold. Travel left, then right, and return to centre. Add a small inward arm pulse at each reversal.",
    mirrored_narration="Catch the first pair with one bumper and the second pair with the other. Travel together to the left, then to the right, and return to the centre. Add a small inward arm pulse near each reversal. Let the lateral travel and the arm movement form one gentle phrase.")

add("two_to_one", "Two hands to one, open out", "Keep gentleman left",
    "Two-hand hold. Release one pair, open around the remaining hand, return and restore the second pair. Release only the bumper-owned pair you want to open.",
    "Use one bumper to catch the first pair, then the other bumper to catch the remaining hands. Begin with both pairs joined. Release the gentleman's right and the lady's left hand, keeping the other pair connected. Open around the remaining connection, return, and restore the second pair. Press the bumper assigned to the released pair again when its hands meet.",
    [pose(t, turn=-r, partner_turn=PI+r, double_weight=w, flexion=.2, partner_flexion=.2)
     for t,r,w in [(0,0,1),(1,0,1),(3,0,0),(7,.6,0),(11,0,0),(13,0,1),(14,0,1)]],
    mode="single", requirement=PREVIEW, mirror="Keep gentleman right",
    mirrored_description="Two-hand hold. Keep gentleman right / lady left joined, open out, return and restore the other pair. Release only the bumper-owned pair you want to open.",
    mirrored_narration="Use one bumper to catch the first pair, then the other bumper to catch the remaining hands. Begin with both pairs joined. Release the gentleman's left and the lady's right hand, keeping the other pair connected. Open around the remaining connection, return, and restore the second pair. Press the bumper assigned to the released pair again when its hands meet.")


def value(v):
    if isinstance(v, tuple):
        return f"Vector2({v[0]:.8f}, {v[1]:.8f})"
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, bool):
        return str(v).lower()
    return f"{v:.8f}"


def write_resource(item):
    mirror = item.get("mirror_of")
    path = ROOT/'single_figures'/f'{item["id"]}.tres'
    # Rebuilding text/timelines must retain recordings attached later.
    audio_path = None
    if path.exists():
        previous = path.read_text(encoding='utf-8')
        attachment = re.search(r'^narration = ExtResource\("([^"\n]+)"\)', previous, re.M)
        if attachment:
            source = re.search(r'\[ext_resource type="AudioStream" path="([^"\n]+)" id="'
                               + re.escape(attachment.group(1)) + r'"\]', previous)
            if not source:
                raise ValueError(f'Cannot preserve narration attachment in {path}')
            audio_path = source.group(1)
    lines = [f'[gd_resource type="Resource" script_class="SingleDanceFigure" load_steps={(3 if mirror else 2) + bool(audio_path)} format=3]',
             '', '[ext_resource type="Script" path="res://single_dance_figure.gd" id="1"]']
    if mirror:
        lines.append(f'[ext_resource type="Resource" path="res://single_figures/{mirror}.tres" id="2"]')
    if audio_path:
        lines.append(f'[ext_resource type="AudioStream" path="{audio_path}" id="3_narration"]')
    lines += ['', '[resource]', 'script = ExtResource("1")']
    if audio_path:
        lines.append('narration = ExtResource("3_narration")')
    for field, v in [('title',item['title']), ('variant_label',item['label']),
                     ('description',item['description']), ('narration_text',item['narration']),
                     ('requirement',item['requirement']), ('duration',item['duration']),
                     ('no_hands',item['mode']=='free'), ('single_hand',item['mode']=='single')]:
        lines.append(f'{field} = {value(v)}')
    if mirror:
        lines.append('mirror_of = ExtResource("2")')
    else:
        lines.append('keys = Array[Dictionary]([' + ',\n'.join(
            '{' + ', '.join(f'{json.dumps(k)}: {value(v)}' for k,v in frame.items()) + '}'
            for frame in item['keys']) + '])')
    path.write_text('\n'.join(lines)+'\n', encoding='utf-8')


def main():
    (ROOT/'single_figures').mkdir(exist_ok=True)
    all_items = [item for base in CATALOGUE for item in [base, *base['variants']]]
    for item in all_items:
        write_resource(item)
    voice = ['# Single-player figure voiceovers', '',
             f'Exact prepared scripts for {len(CATALOGUE)} menu entries and {len(all_items)} variants. No recordings generated.', '',
             'Delivery: calm British English ballroom instructor; clear, unhurried introductions, not timed cues. '
             'Gentleman means dancer A (LS/LT); lady means dancer B (RS/RT). Directions use the overhead view. '
             'These are game references, not formal ballroom instruction. Speak only the paragraph beneath each heading.', '',
             'Each resource stores the identical text in `narration_text`. The stable ID in the heading is the future audio filename. '
             'Generate and review one sample first; later attach each approved AudioStream to its own resource `narration` property. '
             'Missing recordings remain silent. Do not reuse co-op scripts or recordings with different control instructions.', '',
             'This file and the resources are authored by `tools/build_single_figures.py`. Update that source when changing scripts; '
             'the builder preserves existing external AudioStream narration attachments when rebuilding.', '']
    for item in all_items:
        caption = item['title'] + (' - '+item['label'] if item['label'] else '')
        voice += [f'## {caption} (`{item["id"]}`)', '', item['narration'], '']
    (ROOT/'docs'/'SINGLE_PLAYER_VOICEOVERS.md').write_text('\n'.join(voice), encoding='utf-8')
    print(f'Authored {len(CATALOGUE)} figures / {len(all_items)} demonstrations and narration scripts.')


if __name__ == '__main__':
    main()
