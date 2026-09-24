# Voiceover status and next batch

Updated 2026-09-24. **Start with `mirror_spins_mirrored`.**

- Catalogue: 21 figures, 38 prepared scripts.
- Recordings: 28 WAVs attached; 10 missing.
- This batch: 10 new recordings. Stopped at `mirror_spins_mirrored`: daily free-tier quota (HTTP 429). No retry.
- All 18 pre-existing WAVs preserved byte-for-byte. No retries or paid fallback.
- Audio validation: mono, 24 kHz, 16-bit PCM, non-silent, duration 1–120 seconds.
- Godot import and focused narration checks passed; all 28 WAV references verified.
- Listening review: original Travelling turn user-approved; new recordings are
  technically validated only and still need listening review.

Model: `gemini-2.5-flash-preview-tts`. Voice: Charon, established British RP direction.
Exact scripts from [FIGURE_VOICEOVERS.md](FIGURE_VOICEOVERS.md) used unchanged.
Follow [VOICEOVER_GENERATION.md](VOICEOVER_GENERATION.md) to continue; revalidate files first.

Listening priority: compare `weave_promenade` (10.17 s) with its mirrored variant
(19.13 s). Both are valid audio; the duration difference warrants checking pace
and completeness by ear before treating delivery as approved.

## Remaining IDs, in order

```text
mirror_spins_mirrored
two_planets
two_planets_mirrored
spinning_planets
spinning_planets_mirrored
do_si_do
do_si_do_mirrored
travelling_turns
travelling_turns_mirrored
mirror_paths
```

## Preserved wording

The original `travelling_turn`, `turn_in_place` and `open_out_return` WAVs are
compatible neutral introductions that omit the newer variant-specific detail.
Keep them as requested. Their mirrored variants now have dedicated recordings.
The other preserved WAVs are `alternating_sides`, `open_and_close` and
`join_behind_back`. The former colour-based recordings were replaced with
prepared gentleman/lady scripts. Do not restore the deleted versions.
