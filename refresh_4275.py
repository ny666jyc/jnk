# -*- coding: utf-8 -*-
"""Resolve 4275 short links into temporary direct URLs and write a cloud manifest."""
import json
import re
import time
from datetime import datetime, timezone

import requests

BASE = "https://github-com-gh.helloworlds.eu.org/ny666ycj/jnk/raw/m/"
PAGE = "https://4275.com/{code}"
API = "https://4275.com/?m=download&a=down&code={code}&token={token}&cdn=1"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"


def resolve(session, code, retries=3):
    last = None
    for _ in range(retries):
        try:
            page = session.get(PAGE.format(code=code), timeout=30).text
            mcode = re.search(r'data-code="([^"]+)"', page)
            mtoken = re.search(r'data-token="([^"]+)"', page)
            if not mcode or not mtoken:
                raise RuntimeError("4275 page token missing for " + code)
            url = API.format(code=mcode.group(1), token=mtoken.group(1))
            r = session.get(url, allow_redirects=False, timeout=30)
            loc = r.headers.get("Location")
            if not loc:
                raise RuntimeError("4275 no Location for " + code)
            return loc
        except Exception as exc:  # noqa: BLE001
            last = exc
            time.sleep(2)
    raise last


def main():
    with open("manifest.json", encoding="utf-8") as fh:
        manifest = json.load(fh)
    with open("codes.json", encoding="utf-8") as fh:
        codes = json.load(fh)

    session = requests.Session()
    session.headers.update({"User-Agent": UA, "Referer": "https://4275.com/"})

    for tool_id, code in codes.items():
        tool = manifest["tools"].get(tool_id)
        if not tool:
            raise RuntimeError("manifest missing tool " + tool_id)
        loc = resolve(session, code)
        head = session.head(loc, timeout=30, allow_redirects=True)
        length = head.headers.get("Content-Length")
        if length is not None and int(length) != int(tool["size"]):
            raise RuntimeError(
                "size mismatch for %s: %s != %s" % (tool_id, length, tool["size"])
            )
        tool["url"] = loc
        print("OK %s %s %s" % (tool_id, code, tool["size"]), flush=True)
        time.sleep(1.0)

    now = datetime.now(timezone.utc)
    manifest["version"] = now.strftime("%Y%m%d%H%M") + "live"
    manifest["updated"] = now.strftime("%Y-%m-%d %H:%M:%S") + " UTC"
    manifest["updatedAt"] = manifest["updated"]
    manifest["base"] = BASE
    manifest["_base_url"] = BASE

    with open("manifest.live.json", "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=2)
    print("wrote manifest.live.json version=" + manifest["version"], flush=True)


if __name__ == "__main__":
    main()
