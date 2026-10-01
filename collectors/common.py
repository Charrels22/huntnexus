from __future__ import annotations

import hashlib
import json
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.request import Request, urlopen

USER_AGENT = "HuntNexus/0.1 (+https://github.com/Charrels22/huntnexus)"
RAW_ROOT = Path("data/raw")


@dataclass
class Snapshot:
    source: str
    url: str
    fetched_at: str
    content_hash: str
    path: str


def fetch_bytes(url: str, timeout: int = 30) -> bytes:
    req = Request(url, headers={"User-Agent": USER_AGENT, "Accept": "*/*"})
    with urlopen(req, timeout=timeout) as response:
        return response.read()


def save_snapshot(source: str, url: str, payload: bytes, suffix: str) -> Snapshot:
    fetched = datetime.now(timezone.utc)
    digest = hashlib.sha256(payload).hexdigest()
    folder = RAW_ROOT / source / fetched.strftime("%Y/%m/%d")
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / f"{fetched.strftime('%H%M%S')}_{digest[:12]}.{suffix}"
    path.write_bytes(payload)
    meta = {
        "source": source,
        "url": url,
        "fetched_at": fetched.isoformat(),
        "sha256": digest,
        "payload_path": str(path).replace("\\", "/"),
    }
    path.with_suffix(path.suffix + ".meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return Snapshot(source, url, fetched.isoformat(), digest, str(path))


def polite_sleep(seconds: float = 1.0) -> None:
    time.sleep(seconds)
