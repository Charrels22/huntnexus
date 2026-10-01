from __future__ import annotations

import json
from pathlib import Path
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from common import fetch_bytes, polite_sleep, save_snapshot

BASE = "https://wiki.rubinot.com/pt-BR"
OUT = Path("data/normalized/rubinot/wiki_index.json")

ALLOWED_PREFIXES = (
    "/pt-BR/",
    "https://wiki.rubinot.com/pt-BR/",
)


def main() -> None:
    html = fetch_bytes(BASE)
    snap = save_snapshot("rubinot_wiki", BASE, html, "html")
    soup = BeautifulSoup(html, "html.parser")

    pages = {}
    for a in soup.find_all("a", href=True):
        title = a.get_text(" ", strip=True)
        href = a["href"]
        url = urljoin(BASE, href)
        if not title or not any(href.startswith(p) for p in ALLOWED_PREFIXES):
            continue
        pages[url] = {"title": title, "url": url}

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        json.dumps(
            {"source": BASE, "snapshot": snap.__dict__, "pages": sorted(pages.values(), key=lambda x: x["title"])},
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    polite_sleep()
    print(f"RubinOT Wiki index: {len(pages)} pages -> {OUT}")


if __name__ == "__main__":
    main()
