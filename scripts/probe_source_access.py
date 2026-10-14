from __future__ import annotations

import json
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "data" / "source_catalog.json"
OUTPUT = ROOT / "docs" / "evidence" / "2026-10-13-source-access-probe.json"
USER_AGENT = "HuntNexus-Audit/1.0 (+https://github.com/Charrels22/huntnexus)"


def probe(name: str, url: str) -> dict:
    request = Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/json;q=0.9,*/*;q=0.1",
            "Range": "bytes=0-4095",
        },
    )
    started = time.monotonic()
    result = {
        "name": name,
        "url": url,
        "http_status": None,
        "reachable_by_bounded_http_probe": False,
        "final_url": None,
        "content_type": None,
        "elapsed_ms": None,
        "error_type": None,
        "error": None,
    }
    try:
        with urlopen(request, timeout=20) as response:
            response.read(4096)
            result.update(
                http_status=response.status,
                reachable_by_bounded_http_probe=200 <= response.status < 400,
                final_url=response.geturl(),
                content_type=response.headers.get_content_type(),
            )
    except HTTPError as error:
        result.update(
            http_status=error.code,
            final_url=error.geturl(),
            content_type=error.headers.get_content_type() if error.headers else None,
            error_type=type(error).__name__,
            error=str(error.reason),
        )
    except (URLError, TimeoutError, OSError) as error:
        result.update(error_type=type(error).__name__, error=str(error.reason if isinstance(error, URLError) else error))
    finally:
        result["elapsed_ms"] = round((time.monotonic() - started) * 1000)
    return result


def main() -> None:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    results = []
    for index, source in enumerate(catalog["sources"]):
        if index:
            time.sleep(1)
        result = probe(source["name"], source["url"])
        results.append(result)
        print(f'{source["name"]}: {result["http_status"] or result["error_type"]}')

    payload = {
        "observed_at": datetime.now(timezone.utc).isoformat(),
        "method": "One sequential bounded GET per catalog entry; response body discarded after 4096 bytes.",
        "interpretation": "A failed automated HTTP probe does not prove that a source is unavailable to a normal browser. Reachability does not grant collection permission.",
        "source_count": len(results),
        "results": results,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
