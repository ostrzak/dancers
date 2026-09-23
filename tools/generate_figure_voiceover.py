"""Preview all narration texts or make one Gemini TTS request. Python stdlib only."""

import argparse
import base64
import binascii
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.request
import wave


ROOT = Path(__file__).resolve().parents[1]
TEXTS = ROOT / "docs" / "FIGURE_VOICEOVERS.md"
MODEL = "gemini-2.5-flash-preview-tts"
DIRECTION = (
    "Synthesize speech. Read only the transcript below, exactly as written. "
    "You are a composed ballroom instructor speaking British English in Received "
    "Pronunciation. Use a formal, clear, unhurried delivery with restrained warmth, "
    "approximately 135 words per minute, and natural pauses between sentences. "
    "Keep the voice consistent. Do not add an introduction, commentary or music."
)


def load_figures():
    sections = re.findall(r"^## ([^\n]+)\n+(.+?)(?=\n## |\Z)",
                          TEXTS.read_text(encoding="utf-8"), re.M | re.S)
    titles = [title for title, _ in sections]
    if len(titles) != len(set(titles)):
        raise ValueError("Duplicate narration headings.")
    narrated = {title: " ".join(body.split()) for title, body in sections}
    registry = (ROOT / "figure_demonstration.gd").read_text(encoding="utf-8")
    base_registry, variant_registry = registry.split("const VARIANTS :=", 1)
    paths = re.findall(r'preload\("res://(figures/[^\"]+\.tres)"\)', base_registry)
    variants = {
        slug: re.findall(r'preload\("res://(figures/[^\"]+\.tres)"\)', values)
        for slug, values in re.findall(r'^\s*"([^\"]+)": \[(.+)\],', variant_registry, re.M)
    }
    paths = [item for path in paths
             for item in [path, *variants.get(Path(path).stem, [])]]
    result = {}
    expected_titles = []
    for path in paths:
        resource = (ROOT / path).read_text(encoding="utf-8")
        title = re.search(r'^title = "(.+)"$', resource, re.M).group(1)
        variant = re.search(r'^variant_label = "(.*)"$', resource, re.M)
        if variant and variant.group(1):
            title += " - " + variant.group(1)
        expected_titles.append(title)
        if title not in narrated or not narrated[title]:
            raise ValueError(f"Missing narration: {title}")
        result[Path(path).stem] = {"title": title, "text": narrated[title]}
    if not result or titles != expected_titles:
        raise ValueError("Narration headings must match the registered figures in menu order.")
    return result


def api_key():
    # Read newly saved Windows user variables even if Codex predates the change.
    for name in ("GEMINI_API_KEY", "GOOGLE_API_KEY"):
        value = os.environ.get(name, "").strip()
        if value:
            return value
    if sys.platform == "win32":
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as env:
            for name in ("GEMINI_API_KEY", "GOOGLE_API_KEY"):
                try:
                    value = winreg.QueryValueEx(env, name)[0].strip()
                except FileNotFoundError:
                    continue
                if value:
                    return value
    return None


def decode_audio(response):
    candidates = response.get("candidates", [])
    if not candidates:
        raise ValueError("Gemini returned no audio candidate.")
    candidate = candidates[0]
    if candidate.get("finishReason") not in (None, "STOP"):
        raise ValueError("Gemini did not complete the narration; no file was saved.")
    chunks = []
    rate = None
    for part in candidate.get("content", {}).get("parts", []):
        inline = part.get("inlineData")
        if not inline:
            continue
        mime = inline.get("mimeType", "")
        sample_rate = re.search(r"(?:^|;)\s*rate=(\d+)", mime)
        if not mime.startswith("audio/L16") or not sample_rate:
            raise ValueError(f"Unsupported Gemini audio format: {mime}")
        current_rate = int(sample_rate.group(1))
        if current_rate <= 0 or (rate is not None and rate != current_rate):
            raise ValueError("Inconsistent audio sample rates.")
        rate = current_rate
        chunks.append(base64.b64decode(inline["data"], validate=True))
    pcm = b"".join(chunks)
    if not pcm or len(pcm) % 2:
        raise ValueError("Gemini returned empty or invalid 16-bit PCM audio.")
    return pcm, rate


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--figure", default="travelling_turn")
    parser.add_argument("--voice", default="Charon")
    parser.add_argument("--generate", action="store_true",
                        help="Send exactly one request using your configured project/API key.")
    parser.add_argument("--list", action="store_true", help="List all texts without networking.")
    args = parser.parse_args()
    figures = load_figures()
    if args.list:
        for slug, figure in figures.items():
            print(f"{slug}: {figure['text']}")
        return 0
    if args.figure not in figures:
        parser.error("Unknown figure; use --list to see the available identifiers.")
    figure = figures[args.figure]
    prompt = DIRECTION + "\n\nTRANSCRIPT:\n" + figure["text"]
    print(f"Validated {len(figures)} narrations. Sample: {figure['title']}")
    print(f"Model: {MODEL}; voice: {args.voice}\n{prompt}")
    if not args.generate:
        print("Preview only. No API request made. Add --generate to request one recording.")
        return 0
    key = api_key()
    if not key:
        print("No API request made: set GEMINI_API_KEY for a free-tier AI Studio project.",
              file=sys.stderr)
        return 2
    output = ROOT / "voiceover_samples" / f"{args.figure}.wav"
    if output.exists():
        raise ValueError(f"Sample already exists; move it before regenerating: {output}")
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "responseModalities": ["AUDIO"],
            "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {
                "voiceName": args.voice
            }}},
        },
    }
    request = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
        method="POST",
    )
    print("Sending one request. Billing tier is determined by your Google project.")
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            body = json.load(response)
    except urllib.error.HTTPError as error:
        # Read only the structured API message and redact the supplied credential.
        try:
            api_error = json.load(error).get("error", {})
            detail = api_error.get("message", "")
            detail = str(detail).replace(key, "[redacted]")[:1200]
            for item in api_error.get("details", []):
                for violation in item.get("violations", []):
                    quota_id = str(violation.get("quotaId", "")).replace(key, "[redacted]")
                    if quota_id:
                        detail += "\nQuota ID: " + quota_id[:200]
        except (ValueError, AttributeError):
            detail = ""
        hints = {400: "Request rejected; check model and voice availability.",
                 401: "Authentication failed.", 403: "Key or project access was denied.",
                 404: "The preview model is unavailable.",
                 429: "Project quota/rate limit reached; no paid fallback or retry was attempted."}
        print(f"Gemini HTTP {error.code}: " + hints.get(error.code, "Request failed; no retry attempted."),
              file=sys.stderr)
        if detail:
            print(detail, file=sys.stderr)
        return 3
    pcm, rate = decode_audio(body)
    output.parent.mkdir(parents=True, exist_ok=True)
    # Gemini's PCM examples use mono, little-endian, signed 16-bit samples.
    with output.open("xb") as stream:
        with wave.open(stream, "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(rate)
            wav.writeframes(pcm)
    print(f"Saved {output} ({len(pcm) / (2 * rate):.2f}s, {rate} Hz, mono)")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, binascii.Error) as error:
        print(f"Voiceover generation failed: {error}", file=sys.stderr)
        sys.exit(1)
