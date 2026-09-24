# Generate remaining voiceovers

Work in `C:\Users\znami\Documents\Projekty\Dancers\coop`.
Current starting ID and exact pending order: [VOICEOVER_RECORDINGS.md](VOICEOVER_RECORDINGS.md).
Prepared text: [FIGURE_VOICEOVERS.md](FIGURE_VOICEOVERS.md).

## Resume procedure

1. Read the status and scripts. Validate the current catalogue offline:
   `python tools/generate_figure_voiceover.py --list`.
   Skip every ID whose `voiceover_samples/ID.wav` already exists; never overwrite it.
2. Verify that `gemini-2.5-flash-preview-tts` is still available. Keep **Charon**,
   formal British Received Pronunciation, restrained warmth and unhurried delivery.
   Use the exact prepared text, including variant wording and gentleman/lady roles.
3. Use the existing free-tier API key securely, without printing or saving it.
   The script reads `GEMINI_API_KEY` or `GOOGLE_API_KEY` from the process environment
   or Windows user environment. Last run used the key supplied in this task only
   for the process; no persistent local key was configured. If unavailable in a
   future task, request local configuration rather than storing a key in the repo.
4. Try the first missing ID once. Continue sequentially only if successful:

   ```powershell
   python tools/generate_figure_voiceover.py --figure mirror_spins_mirrored --generate
   ```

   Substitute each subsequent missing ID. Each invocation sends one request.
   Space requests to respect the free-tier limits. **Stop at the first API error
   or quota exhaustion. Do not retry, change model or enable paid billing.**
5. Validate each new WAV: mono, 24 kHz, 16-bit PCM, non-silent audio and plausible
   duration (previous batch checked 1–120 seconds). Technical validation is not
   listening review; mark new recordings as awaiting listening review.
6. Attach each successful `voiceover_samples/ID.wav` to `figures/ID.tres` through
   its `narration` AudioStream reference. Replace shared neutral audio only for
   the variant receiving a dedicated recording. Preserve other resource fields.
7. Run Godot import and `tests/figure_voiceover_test.gd`, not full gameplay suites.
   On this Windows setup, use `--headless --audio-driver WASAPI` for the narration
   test; the dummy audio driver can produce shutdown cleanup warnings.
8. Replace the status document with the current counts, validation result, stop
   reason and exact remaining order. Keep it current, without accumulating old
   batch narratives. Preserve unrelated work and leave changes uncommitted.

The generator uses Python's standard library and refuses to overwrite existing
files. Billing is determined by the Google project, not a request flag. Use the
existing Free project only. Game playback uses local audio and never calls the API.
Narrations are introductions, not cues synchronised to demonstration loops.

## References

- [Configured model](https://ai.google.dev/gemini-api/docs/models/gemini-2.5-flash-preview-tts)
- [Speech generation](https://ai.google.dev/gemini-api/docs/speech-generation)
- [Project quotas](https://ai.google.dev/gemini-api/docs/rate-limits)
