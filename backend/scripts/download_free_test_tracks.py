#!/usr/bin/env python3
"""
Download free/CC-friendly music from Internet Archive for local recommendation testing.

Uses collections like `netlabels` and `opensource_audio` — files are offered by
uploaders under various open licenses; verify terms on each item page before
redistribution. Output includes ATTRIBUTION.txt with archive.org links.

Usage (from repo root):
  cd backend
  python scripts/download_free_test_tracks.py --count 100 --out scripts/free_test_tracks

  Dry run (no downloads):
  python scripts/download_free_test_tracks.py --dry-run --count 5
"""
from __future__ import annotations

import argparse
import json
import os
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

ARCHIVE_SEARCH = "https://archive.org/advancedsearch.php"
ARCHIVE_META = "https://archive.org/metadata/{}"
ARCHIVE_FILE = "https://archive.org/download/{}/{}"

# IA search queries that tend to return many individual audio files (netlabels, etc.)
SEARCH_QUERIES = [
    "collection:netlabels AND mediatype:audio",
    "collection:opensource_audio AND mediatype:audio",
    "collection:audio_music AND mediatype:audio",
]

# Skip obvious junk / huge items
MAX_FILE_BYTES = 25 * 1024 * 1024  # 25 MB per track
MIN_FILE_BYTES = 20_000  # avoid tiny stubs


def _http_get_json(url: str, timeout: float = 60.0) -> Any:
    req = urllib.request.Request(url, headers={"User-Agent": "NoizeDevTest/1.0 (recommendation QA)"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8", errors="replace"))


def _search_identifiers(query: str, rows: int, page: int) -> List[Dict[str, Any]]:
    params = [
        ("q", query),
        ("rows", str(rows)),
        ("page", str(page)),
        ("output", "json"),
    ]
    for k in ("identifier", "title"):
        params.append(("fl[]", k))
    url = ARCHIVE_SEARCH + "?" + urllib.parse.urlencode(params)
    data = _http_get_json(url)
    docs = data.get("response", {}).get("docs") or []
    return docs if isinstance(docs, list) else []


def _list_candidate_mp3s(meta: Dict[str, Any]) -> List[Dict[str, Any]]:
    files = meta.get("files") or []
    out: List[Dict[str, Any]] = []
    for f in files:
        if not isinstance(f, dict):
            continue
        name = f.get("name") or ""
        if not name.lower().endswith(".mp3"):
            continue
        if "/__ia_thumb" in name or name.startswith("."):
            continue
        try:
            size = int(f.get("size") or 0)
        except (TypeError, ValueError):
            size = 0
        if size < MIN_FILE_BYTES or size > MAX_FILE_BYTES:
            continue
        out.append({"name": name, "size": size})
    out.sort(key=lambda x: x["name"].lower())
    return out


def _download_file(identifier: str, filename: str, dest: Path) -> None:
    # Preserve subpaths (e.g. "Set1/01-Track.mp3") for archive.org download URLs.
    enc = "/".join(urllib.parse.quote(seg, safe="") for seg in filename.split("/"))
    url = ARCHIVE_FILE.format(identifier, enc)
    req = urllib.request.Request(url, headers={"User-Agent": "NoizeDevTest/1.0 (recommendation QA)"})
    dest.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = resp.read()
    dest.write_bytes(data)


def _iter_archive_items(
    shuffle_seed: Optional[int],
) -> Iterable[Tuple[str, str, List[Dict[str, Any]]]]:
    """Yields (identifier, title, mp3_file_dicts)."""
    pages_per_query = 8
    rows = 80
    all_docs: List[Dict[str, Any]] = []
    for q in SEARCH_QUERIES:
        for page in range(1, pages_per_query + 1):
            try:
                docs = _search_identifiers(q, rows=rows, page=page)
            except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError) as e:
                print(f"search warning ({q} p{page}): {e}", file=sys.stderr)
                continue
            if not docs:
                break
            all_docs.extend(docs)
            time.sleep(0.35)

    seen: set[str] = set()
    uniq: List[Dict[str, Any]] = []
    for d in all_docs:
        i = d.get("identifier")
        if not i or i in seen:
            continue
        seen.add(i)
        uniq.append(d)

    if shuffle_seed is not None:
        rnd = random.Random(shuffle_seed)
        rnd.shuffle(uniq)
    else:
        random.shuffle(uniq)

    for doc in uniq:
        identifier = doc["identifier"]
        title = (doc.get("title") or identifier)[:200]
        try:
            meta = _http_get_json(ARCHIVE_META.format(identifier))
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError) as e:
            print(f"metadata skip {identifier}: {e}", file=sys.stderr)
            time.sleep(0.25)
            continue
        mp3s = _list_candidate_mp3s(meta)
        if not mp3s:
            time.sleep(0.15)
            continue
        yield identifier, title, mp3s
        time.sleep(0.2)


def main() -> int:
    ap = argparse.ArgumentParser(description="Download free IA audio for rec-engine QA.")
    ap.add_argument("--out", type=Path, default=Path("scripts/free_test_tracks"))
    ap.add_argument("--count", type=int, default=100)
    ap.add_argument(
        "--max-per-item",
        type=int,
        default=4,
        help="Max MP3s per archive.org item (avoids one concert filling the whole set).",
    )
    ap.add_argument("--sleep", type=float, default=0.45, help="Delay between file downloads (seconds).")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--seed", type=int, default=None, help="Shuffle seed for reproducible item order.")
    args = ap.parse_args()

    out_dir: Path = args.out
    if not args.dry_run:
        out_dir.mkdir(parents=True, exist_ok=True)

    manifest: List[str] = []
    n_ok = 0
    for identifier, title, mp3s in _iter_archive_items(args.seed):
        taken_here = 0
        for f in mp3s:
            if n_ok >= args.count:
                break
            if taken_here >= max(1, args.max_per_item):
                break
            safe_name = f["name"].replace("/", "_").replace("\\", "_")
            dest = out_dir / f"{n_ok + 1:03d}_{identifier[:40]}_{safe_name}"
            line = f"{n_ok + 1:03d}\t{identifier}\t{f['name']}\t{title}\thttps://archive.org/details/{urllib.parse.quote(identifier)}"
            print(line[:160] + ("..." if len(line) > 160 else ""))
            if args.dry_run:
                manifest.append(line)
                n_ok += 1
                taken_here += 1
                continue
            try:
                _download_file(identifier, f["name"], dest)
                manifest.append(line)
                n_ok += 1
                taken_here += 1
                print(f"  saved -> {dest.name} ({dest.stat().st_size // 1024} KB)")
            except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError, ValueError) as e:
                print(f"  FAIL {identifier} / {f['name']}: {e}", file=sys.stderr)
            time.sleep(max(0.0, args.sleep))
        if n_ok >= args.count:
            break

    if not args.dry_run and manifest:
        att = out_dir / "ATTRIBUTION.txt"
        att.write_text(
            "Tracks downloaded from archive.org for local development testing only.\n"
            "Respect each item's license shown on its details page before any public use.\n\n"
            + "\n".join(manifest)
            + "\n",
            encoding="utf-8",
        )
        print(f"\nWrote {len(manifest)} entries and {att.name}")

    if n_ok < args.count:
        print(
            f"\nNote: only {n_ok}/{args.count} files obtained. "
            "Try again later, different network, or increase IA search breadth in the script.",
            file=sys.stderr,
        )
        return 1 if n_ok == 0 else 0

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
