from __future__ import annotations

import json
import re
from pathlib import Path

from bs4 import BeautifulSoup

from common import fetch_bytes, polite_sleep, save_snapshot

BASE = "https://rubinot.com.br/changelog"
OUT = Path("data/normalized/rubinot/changelog.json")


def parse_page(html: bytes) -> list[dict]:
    soup = BeautifulSoup(html, "html.parser")
    text = soup.get_text("\n", strip=True)
    lines = [x.strip() for x in text.splitlines() if x.strip()]
    releases: list[dict] = []
    scope = None
    current = None

    version_re = re.compile(r"^v\d+(?:\.\d+)+$")
    date_re = re.compile(r"\b\d{1,2}\s+de\s+[a-zç]+\.?(?:\s+de)?\s+\d{4}\b", re.I)
    count_re = re.compile(r"^(\d+)\s+alteraç")

    for line in lines:
        if line in {"Cliente", "Servidor"}:
            scope = "client" if line == "Cliente" else "server"
            continue
        if version_re.match(line):
            if current:
                releases.append(current)
            current = {"scope": scope, "version": line, "date_text": None, "change_count": None, "changes": []}
            continue
        if not current:
            continue
        m = count_re.match(line)
        if m:
            current["change_count"] = int(m.group(1))
            d = date_re.search(line)
            if d:
                current["date_text"] = d.group(0)
            continue
        if line.startswith("Ver todas as") or line.startswith("Mostrando "):
            continue
        if len(line) > 20 and not version_re.match(line):
            current["changes"].append(line)

    if current:
        releases.append(current)

    # Keep only real release blocks and remove obvious navigation text.
    return [r for r in releases if r["scope"] and r["version"]]


def main() -> None:
    html = fetch_bytes(BASE)
    snap = save_snapshot("rubinot_changelog", BASE, html, "html")
    releases = parse_page(html)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        json.dumps(
            {
                "source": BASE,
                "snapshot": snap.__dict__,
                "releases": releases,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    polite_sleep()
    print(f"RubinOT changelog: {len(releases)} release blocks -> {OUT}")


if __name__ == "__main__":
    main()
