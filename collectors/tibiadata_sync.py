from __future__ import annotations

import json
from pathlib import Path
from urllib.parse import quote

from common import fetch_bytes, polite_sleep, save_snapshot

BASE = "https://tibiadata.bytewizards.de/api/v1"
OUT = Path("data/normalized/tibia")
KINDS = {
    "creatures": "creatures/sync",
    "items": "items/sync",
    "hunting_places": "hunting-places/sync",
}


def get_json(url: str):
    raw = fetch_bytes(url)
    save_snapshot("bytewizards_tibiadata", url, raw, "json")
    return json.loads(raw)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}

    for kind, route in KINDS.items():
        url = f"{BASE}/{route}"
        payload = get_json(url)
        path = OUT / f"{kind}_sync.json"
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        manifest[kind] = {"sync_url": url, "count": len(payload), "path": str(path)}
        polite_sleep()

    (OUT / "sync_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
