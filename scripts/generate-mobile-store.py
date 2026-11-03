#!/usr/bin/env python3
"""Build the static mobile-store catalog from the current NPC shops.

This is a one-time development tool.  The generated file is the runtime source
of truth afterwards; update it by hand when shop prices/items change.

Rules:
  * buy  = lowest price any NPC charges for the item
  * sell = highest price any NPC pays for the item
  * if sell >= buy, sell becomes 90% of buy (sell < buy)
  * an item with no buy price is not sold by the store
  * an item with no sell price is not bought by the store

Sources:
  * data/npc/*.xml parameter shop_buyable / shop_sellable
  * data/npc/scripts/**/*.lua ShopModule:addBuyableItem / addSellableItem
"""

from __future__ import annotations

import argparse
import html
import math
import re
import sys
from collections import defaultdict
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parent.parent
NPC_DIR = ROOT / "data" / "npc"
ITEMS_XML = ROOT / "data" / "items" / "items.xml"
OUTPUT = ROOT / "data" / "scripts" / "lib" / "mobile_store_catalog.lua"


def strip_lua_comments(text: str) -> str:
    """Remove line and long comments while preserving strings and line count."""
    out = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch in ("'", '"'):
            quote = ch
            out.append(ch)
            i += 1
            while i < n:
                out.append(text[i])
                if text[i] == "\\":
                    i += 1
                    if i < n:
                        out.append(text[i])
                elif text[i] == quote:
                    i += 1
                    break
                i += 1
            continue
        if text.startswith("--", i):
            # long comment --[[ ... ]] / --[=[ ... ]=]
            long_match = re.match(r"--\[(=*)\[", text[i:])
            if long_match:
                end = "--]" + long_match.group(1) + "]"
                end_pos = text.find(end, i + len(long_match.group(0)))
                if end_pos == -1:
                    break
                i = end_pos + len(end)
                continue
            newline = text.find("\n", i)
            if newline == -1:
                break
            i = newline
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def split_top_level(value: str, separator: str = ",") -> list[str]:
    parts = []
    start = 0
    depth = 0
    quote = None
    i = 0
    while i < len(value):
        ch = value[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in ("'", '"'):
            quote = ch
        elif ch in "({[":
            depth += 1
        elif ch in ")}]":
            depth -= 1
        elif ch == separator and depth == 0:
            parts.append(value[start:i])
            start = i + 1
        i += 1
    parts.append(value[start:])
    return parts


def balanced_call(text: str, open_index: int) -> int | None:
    depth = 0
    quote = None
    i = open_index
    while i < len(text):
        ch = text[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in ("'", '"'):
            quote = ch
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return None


def parse_lua_calls(path: Path, records: list[dict]):
    text = strip_lua_comments(path.read_text(errors="replace"))
    pattern = re.compile(r"\b(addBuyableItem|addSellableItem)\s*\(")
    for match in pattern.finditer(text):
        kind = "buy" if match.group(1) == "addBuyableItem" else "sell"
        end = balanced_call(text, match.end() - 1)
        if end is None:
            continue
        args = split_top_level(text[match.end():end])
        if len(args) < 3:
            continue

        item_arg = args[1].strip()
        cost_arg = args[2].strip()
        if not re.fullmatch(r"\d+", item_arg) or not re.fullmatch(r"\d+", cost_arg):
            continue

        item_id = int(item_arg)
        cost = int(cost_arg)
        subtype = None
        name = None
        if kind == "buy":
            if len(args) >= 4:
                subtype = args[3].strip()
            if len(args) >= 5:
                name = args[4].strip()
        else:
            if len(args) >= 4:
                name = args[3].strip()
            if len(args) >= 5:
                subtype = args[4].strip()

        def as_int(value):
            if value is not None and re.fullmatch(r"-?\d+", value):
                return int(value)
            return None

        def as_string(value):
            if value is None:
                return None
            m = re.fullmatch(r"'((?:\\.|[^'])*)'|\"((?:\\.|[^\"])*)\"", value, re.DOTALL)
            if not m:
                return None
            raw = m.group(1) if m.group(1) is not None else m.group(2)
            return raw.replace("\\'", "'").replace('\\"', '"').replace("\\\\", "\\")

        records.append({
            "id": item_id,
            "cost": cost,
            "kind": kind,
            "type": as_int(subtype),
            "name": as_string(name),
            "source": f"{path.relative_to(ROOT)}",
        })


def parse_npc_xml(records: list[dict]):
    for path in sorted(NPC_DIR.glob("*.xml")):
        try:
            tree = ElementTree.parse(path)
        except ElementTree.ParseError:
            continue
        for parameter in tree.iter("parameter"):
            key = parameter.get("key")
            if key not in ("shop_buyable", "shop_sellable"):
                continue
            value = parameter.get("value") or ""
            kind = "buy" if key == "shop_buyable" else "sell"
            for entry in value.split(";"):
                fields = [field.strip() for field in entry.split(",")]
                if len(fields) < 3:
                    continue
                name, item_id, cost = fields[0], fields[1], fields[2]
                if not re.fullmatch(r"\d+", item_id) or not re.fullmatch(r"\d+", cost):
                    continue

                subtype = None
                if kind == "buy":
                    if len(fields) >= 4 and re.fullmatch(r"\d+", fields[3]):
                        subtype = int(fields[3])
                    real_name = fields[4] if len(fields) >= 5 else None
                else:
                    real_name = fields[3] if len(fields) >= 4 else None
                    if len(fields) >= 5 and re.fullmatch(r"\d+", fields[4]):
                        subtype = int(fields[4])

                records.append({
                    "id": int(item_id),
                    "cost": int(cost),
                    "kind": kind,
                    "type": subtype,
                    "name": real_name or name or None,
                    "source": f"{path.relative_to(ROOT)}",
                })



OTB = ROOT / "data" / "items" / "items.otb"
OTB_SPECIAL = re.compile(rb"[\xfd-\xff]")


def parse_otb_node(data: bytes, pos: int):
    node_type = data[pos + 1]
    props_start = pos + 2
    marker_pos = props_start
    while True:
        match = OTB_SPECIAL.search(data, marker_pos)
        if match is None:
            raise ValueError("unterminated items.otb node")
        marker_pos = match.start()
        if data[marker_pos] == 0xFD:
            marker_pos += 2
            continue
        break
    raw = data[props_start:marker_pos]
    if b"\xfd" in raw:
        out = bytearray()
        i = 0
        while i < len(raw):
            byte = raw[i]
            if byte == 0xFD:
                i += 1
                if i >= len(raw):
                    raise ValueError("truncated items.otb escape")
                byte = raw[i]
            out.append(byte)
            i += 1
        raw = bytes(out)
    return node_type, raw, marker_pos


def skip_otb_subtree(data: bytes, marker: int) -> int:
    depth = 0
    pos = marker
    while True:
        match = OTB_SPECIAL.search(data, pos)
        if match is None:
            raise ValueError("unterminated items.otb subtree")
        offset = match.start()
        byte = data[offset]
        if byte == 0xFD:
            pos = offset + 2
        elif byte == 0xFE:
            depth += 1
            pos = offset + 2
        else:
            if depth == 0:
                return offset + 1
            depth -= 1
            pos = offset + 1


def load_items_otb() -> dict[int, int]:
    data = OTB.read_bytes()
    root_type, _, marker = parse_otb_node(data, 4)
    if root_type != 0:
        raise ValueError("invalid items.otb root")
    mapping = {}
    pos = marker
    while data[pos] == 0xFE:
        node_type, props, next_marker = parse_otb_node(data, pos)
        offset = 4  # flags
        server_id = None
        client_id = None
        while offset + 3 <= len(props):
            attribute = props[offset]
            length = int.from_bytes(props[offset + 1:offset + 3], "little")
            offset += 3
            value = props[offset:offset + length]
            offset += length
            if attribute == 0x10 and len(value) == 2:
                server_id = int.from_bytes(value, "little")
            elif attribute == 0x11 and len(value) == 2:
                client_id = int.from_bytes(value, "little")
        if server_id is not None and client_id:
            mapping[server_id] = client_id
        pos = skip_otb_subtree(data, next_marker)
    return mapping


def load_item_names() -> dict[int, str]:
    names = {}
    text = ITEMS_XML.read_text(errors="replace")
    for match in re.finditer(r"<item\b([^>]*)>", text, re.DOTALL):
        attrs = match.group(1)
        name_match = re.search(r'name="([^"]*)"', attrs)
        if not name_match:
            continue
        name = html.unescape(name_match.group(1))
        id_match = re.search(r'\bid="(\d+)"', attrs)
        if id_match:
            names[int(id_match.group(1))] = name
            continue
        from_match = re.search(r'\bfromid="(\d+)"', attrs)
        to_match = re.search(r'\btoid="(\d+)"', attrs)
        if from_match and to_match:
            for item_id in range(int(from_match.group(1)), int(to_match.group(1)) + 1):
                names[item_id] = name
    return names


def build_catalog(records: list[dict], item_names: dict[int, str], otb: dict[int, int]):
    buys = defaultdict(list)
    sells = defaultdict(list)
    subtypes = {}
    names = {}
    for record in records:
        item_id = record["id"]
        if record["kind"] == "buy":
            buys[item_id].append(record["cost"])
        else:
            sells[item_id].append(record["cost"])
        if record["type"] is not None and record["type"] != 0:
            subtypes.setdefault(item_id, record["type"])
        if record["name"]:
            names.setdefault(item_id, record["name"])

    catalog = []
    skipped = 0
    for item_id in sorted(set(buys) | set(sells)):
        client_id = otb.get(item_id)
        if client_id is None or client_id < 100 or client_id > 11703:
            skipped += 1
            continue

        buy = min(buys[item_id]) if buys[item_id] else 0
        sell = max(sells[item_id]) if sells[item_id] else 0
        if buy and sell and sell >= buy:
            sell = int(math.floor(buy * 0.9))
        if buy <= 0:
            buy = 0
        if sell < 0:
            sell = 0
        if buy == 0 and sell == 0:
            continue
        catalog.append({
            "id": item_id,
            "subType": subtypes.get(item_id, 0),
            "buy": buy,
            "sell": sell,
            "name": item_names.get(item_id) or names.get(item_id) or f"item {item_id}",
        })
    return catalog, skipped


def lua_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r") + '"'


def write_catalog(catalog: list[dict], output: Path):
    lines = [
        "-- Generated from the current NPC shop prices.",
        "-- This file is the static runtime source; edit it by hand for future items/prices.",
        "-- buy = lowest NPC buy price, sell = highest NPC sell price, capped at 90% of buy.",
        "MobileStoreCatalog = {",
    ]
    for entry in catalog:
        lines.append(
            "    {id = %d, subType = %d, buy = %d, sell = %d, name = %s},"
            % (entry["id"], entry["subType"], entry["buy"], entry["sell"], lua_string(entry["name"]))
        )
    lines.append("}")
    lines.append("")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default=str(OUTPUT))
    args = parser.parse_args()

    records = []
    parse_npc_xml(records)
    for path in sorted((NPC_DIR / "scripts").rglob("*.lua")):
        parse_lua_calls(path, records)

    item_names = load_item_names()
    otb = load_items_otb()
    catalog, skipped = build_catalog(records, item_names, otb)
    output = Path(args.output)
    write_catalog(catalog, output)

    print(f"NPC price records: {len(records)}")
    print(f"catalog items: {len(catalog)} (skipped {skipped} items missing from the client DAT)")
    print(f"wrote {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
