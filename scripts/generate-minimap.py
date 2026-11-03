#!/usr/bin/env python3
"""Generate a fully revealed OTClient minimap (minimap.otmm) from an OTBM map.

The client only stores tiles it has actually seen.  This tool walks the whole
world map, resolves every tile exactly the way the client does (topmost
non-common thing's DAT minimap colour, walkability/pathability flags and ground
speed), and writes the result in the client's own on-disk format, so the map is
revealed without ever walking it.

Inputs:
  * the OTBM world (`data/world/global.otbm` by default)
  * the server's items.otb (`data/items/items.otb` by default), because the
    map stores *server* item ids and the client draws the matching *client* id
    (this datapack remaps many of them, e.g. server grass 9043 -> client 4515)
  * the client DAT for the same protocol (`data/things/860/Tibia.dat` by
    default, the vanilla 8.60 DAT used by the client)

Output:
  * `minimap.otmm`, to be copied into the client's user directory with the
    client closed (the client rewrites the file when a game session ends).

Format (src/client/minimap.h / minimap.cpp in otclient):
  u32 signature "OTMM", u16 data start, u16 version (1), u32 flags,
  u16-length string "OTMM 1.0", then per block:
  u16 x, u16 y, u8 z, u16 compressed length, zlib(64*64*3 bytes).
  Each tile is 3 bytes: flags, colour, speed, index = (y%64)*64 + (x%64).
  A block is only written when it contains at least one map tile; the file
  ends with a zero position (u16 0, u16 0, u8 0).

Usage:
  python3 scripts/generate-minimap.py --stats
  python3 scripts/generate-minimap.py --out /tmp/minimap.otmm
  python3 scripts/generate-minimap.py --compare ~/.local/share/otclient/.otclient/minimap.otmm
"""

from __future__ import annotations

import argparse
import os
import re
import struct
import sys
import zlib
from dataclasses import dataclass

# --- OTBM -----------------------------------------------------------------

OTBM_ROOTV1 = 1
OTBM_MAP_DATA = 2
OTBM_TILE_AREA = 4
OTBM_TILE = 5
OTBM_ITEM = 6
OTBM_HOUSETILE = 14

OTBM_ATTR_TILE_FLAGS = 3
OTBM_ATTR_ITEM = 9

SPECIAL = re.compile(rb"[\xfd-\xff]")


class MapError(RuntimeError):
    pass


def unescape(raw: bytes) -> bytes:
    """Undo OTBM 0xFD escaping inside a node's property block."""
    if b"\xfd" not in raw:
        return raw
    out = bytearray()
    i = 0
    size = len(raw)
    while i < size:
        byte = raw[i]
        if byte == 0xFD:
            i += 1
            if i >= size:
                raise MapError("truncated escape in OTBM properties")
            byte = raw[i]
        out.append(byte)
        i += 1
    return bytes(out)


@dataclass(frozen=True)
class Node:
    """A parsed node header: type, unescaped properties and child marker."""

    type: int
    props: bytes
    marker: int  # position of the first child (0xFE) or the node end (0xFF)


def find_marker(data: bytes, pos: int) -> int:
    """Return the offset of the next unescaped 0xFE/0xFF marker."""
    while True:
        match = SPECIAL.search(data, pos)
        if match is None:
            raise MapError(f"unterminated node at offset {pos}")
        offset = match.start()
        if data[offset] == 0xFD:
            pos = offset + 2
            continue
        return offset


def parse_node(data: bytes, pos: int) -> Node:
    if data[pos] != 0xFE:
        raise MapError(f"expected node start at offset {pos}")
    node_type = data[pos + 1]
    props_start = pos + 2
    marker = find_marker(data, props_start)
    return Node(node_type, unescape(data[props_start:marker]), marker)


def skip_subtree(data: bytes, marker: int) -> int:
    """Skip the children of a node and return the offset after its end byte."""
    depth = 0
    pos = marker
    while True:
        match = SPECIAL.search(data, pos)
        if match is None:
            raise MapError(f"unterminated subtree at offset {pos}")
        offset = match.start()
        byte = data[offset]
        if byte == 0xFD:
            pos = offset + 2
        elif byte == 0xFE:
            depth += 1
            pos = offset + 2
        else:  # 0xFF
            if depth == 0:
                return offset + 1
            depth -= 1
            pos = offset + 1


def read_inline_item(props: bytes, pos: int) -> tuple[int, int]:
    """Read an old-style inline OTBM_ATTR_ITEM (u16 id only) and return (id, new pos).

    IOMap::parseTileArea calls Item::CreateItem(propStream), which only reads
    the id; inline item attributes are not part of this map format.  Item
    attributes live in child OTBM_ITEM nodes.
    """
    if pos + 2 > len(props):
        raise MapError("truncated inline item id")
    return struct.unpack_from("<H", props, pos)[0], pos + 2


@dataclass
class TileInfo:
    items: list[int]


def walk_tiles(data: bytes, on_tile):
    """Call on_tile(x, y, z, items) for every tile in the map."""
    root = parse_node(data, 4)
    if root.type not in (0, OTBM_ROOTV1):
        raise MapError(f"unexpected root node type {root.type}")
    if len(root.props) < 16:
        raise MapError("invalid OTBM root header")

    map_data = parse_node(data, root.marker)
    if map_data.type != OTBM_MAP_DATA:
        raise MapError(f"expected map data, got node type {map_data.type}")

    pos = map_data.marker
    while data[pos] == 0xFE:
        area = parse_node(data, pos)
        if area.type != OTBM_TILE_AREA:
            pos = skip_subtree(data, area.marker)
            continue
        if len(area.props) < 5:
            raise MapError("invalid tile area properties")
        base_x, base_y, base_z = struct.unpack_from("<HHB", area.props, 0)

        tile_pos = area.marker
        while data[tile_pos] == 0xFE:
            tile = parse_node(data, tile_pos)
            if tile.type not in (OTBM_TILE, OTBM_HOUSETILE):
                raise MapError(f"unexpected tile node type {tile.type}")
            if len(tile.props) < 2:
                raise MapError("invalid tile properties")

            offset = 2
            if tile.type == OTBM_HOUSETILE:
                offset += 4

            items: list[int] = []
            # Legacy inline items come before child item nodes.
            while offset < len(tile.props):
                attr = tile.props[offset]
                offset += 1
                if attr == OTBM_ATTR_TILE_FLAGS:
                    offset += 4
                elif attr == OTBM_ATTR_ITEM:
                    item_id, offset = read_inline_item(tile.props, offset)
                    items.append(item_id)
                else:
                    raise MapError(f"unknown tile attribute {attr}")

            item_pos = tile.marker
            while data[item_pos] == 0xFE:
                item = parse_node(data, item_pos)
                if item.type != OTBM_ITEM:
                    raise MapError(f"unexpected tile child node type {item.type}")
                if len(item.props) < 2:
                    raise MapError("invalid item node")
                items.append(struct.unpack_from("<H", item.props, 0)[0])
                item_pos = skip_subtree(data, item.marker)

            if data[item_pos] != 0xFF:
                raise MapError("unterminated tile node")

            on_tile(base_x + tile.props[0], base_y + tile.props[1], base_z, items)
            tile_pos = item_pos + 1

        if data[tile_pos] != 0xFF:
            raise MapError("unterminated tile area node")
        pos = tile_pos + 1

    if data[pos] != 0xFF:
        raise MapError("unterminated map data node")


# --- items.otb ------------------------------------------------------------
#
# Map tiles store the server id.  ProtocolGame serialises ItemType::clientId,
# so every id has to be translated before it can be looked up in the DAT.

OTB_IDENTIFIER = b"OTBI"
OTB_ROOT_ATTR_VERSION = 0x01
OTB_ATTR_SERVERID = 0x10
OTB_ATTR_CLIENTID = 0x11


def load_items_otb(path: str) -> dict[int, int]:
    with open(path, "rb") as handle:
        data = handle.read()

    if data[:4] not in (OTB_IDENTIFIER, b"\0\0\0\0"):
        raise MapError(f"{path} is not an items.otb file")

    root = parse_node(data, 4)
    if root.type != 0:
        raise MapError(f"unexpected items.otb root type {root.type}")

    mapping: dict[int, int] = {}
    pos = root.marker
    while data[pos] == 0xFE:
        node = parse_node(data, pos)
        if len(node.props) < 4:
            raise MapError("invalid items.otb item node")
        offset = 4  # flags
        server_id = None
        client_id = None
        while offset + 3 <= len(node.props):
            attribute = node.props[offset]
            length = struct.unpack_from("<H", node.props, offset + 1)[0]
            offset += 3
            value = node.props[offset:offset + length]
            offset += length
            if attribute == OTB_ATTR_SERVERID and len(value) == 2:
                server_id = struct.unpack_from("<H", value)[0]
            elif attribute == OTB_ATTR_CLIENTID and len(value) == 2:
                client_id = struct.unpack_from("<H", value)[0]
        if server_id is not None and client_id:
            mapping[server_id] = client_id
        pos = skip_subtree(data, node.marker)

    if data[pos] != 0xFF:
        raise MapError("unterminated items.otb root node")
    return mapping


# --- DAT ------------------------------------------------------------------


@dataclass
class DatItem:
    ground: bool = False
    ground_speed: int = 0
    ground_border: bool = False
    on_bottom: bool = False
    on_top: bool = False
    not_walkable: bool = False
    not_pathable: bool = False
    minimap_color: int = 0

    @property
    def common(self) -> bool:
        """Thing::isCommon() - ignored when picking a minimap colour."""
        return not (self.ground or self.ground_border or self.on_bottom or self.on_top)


# Attributes with a fixed payload (8.60 DAT, see ThingType::unserialize).
# Displacement and light carry two u16 values, the rest a single one.
_U16_DAT_ATTRS = {0, 8, 9, 25, 28, 29, 32, 34, 251}
_U16X2_DAT_ATTRS = {21, 24}
_MARKET_DAT_ATTR = 33


class DatReader:
    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0

    def u8(self) -> int:
        value = self.data[self.pos]
        self.pos += 1
        return value

    def u16(self) -> int:
        value = struct.unpack_from("<H", self.data, self.pos)[0]
        self.pos += 2
        return value

    def u32(self) -> int:
        value = struct.unpack_from("<I", self.data, self.pos)[0]
        self.pos += 4
        return value

    def skip(self, count: int):
        self.pos += count

    def string(self):
        self.skip(self.u16())


def load_dat(path: str) -> dict[int, DatItem]:
    with open(path, "rb") as handle:
        data = handle.read()

    reader = DatReader(data)
    reader.u32()  # signature
    counts = [reader.u16() + 1 for _ in range(4)]

    items: dict[int, DatItem] = {}
    for category in range(4):
        first_id = 100 if category == 0 else 1
        for client_id in range(first_id, counts[category]):
            item = DatItem()
            while True:
                attr = reader.u8()
                if attr == 255:
                    break
                if attr > 32:
                    raise MapError(f"unsupported DAT attribute {attr} (item {client_id})")

                if attr in _U16_DAT_ATTRS:
                    value = reader.u16()
                    if attr == 0:
                        item.ground = True
                        item.ground_speed = value
                    elif attr == 28:
                        item.minimap_color = value
                elif attr in _U16X2_DAT_ATTRS:
                    reader.skip(4)
                elif attr == _MARKET_DAT_ATTR:
                    reader.skip(6)
                    reader.string()
                    reader.skip(4)
                elif attr == 1:
                    item.ground_border = True
                elif attr == 2:
                    item.on_bottom = True
                elif attr == 3:
                    item.on_top = True
                elif attr == 12:
                    item.not_walkable = True
                elif attr == 15:
                    item.not_pathable = True

            width = reader.u8()
            height = reader.u8()
            if width > 1 or height > 1:
                reader.skip(1)  # exact size
            layers = reader.u8()
            pattern_x = reader.u8()
            pattern_y = reader.u8()
            pattern_z = reader.u8()
            animation = reader.u8()
            reader.skip(2 * width * height * layers * pattern_x * pattern_y * pattern_z * animation)

            if category == 0:
                items[client_id] = item

    if reader.pos != len(data):
        raise MapError(f"DAT parse consumed {reader.pos} of {len(data)} bytes")
    return items


# --- Minimap --------------------------------------------------------------

MMBLOCK_SIZE = 64
OTMM_SIGNATURE = 0x4D4D544F
OTMM_VERSION = 1
MMBLOCK_BYTES = MMBLOCK_SIZE * MMBLOCK_SIZE * 3
DEFAULT_TILE = bytes((0, 255, 10))
MINIMAP_TILE_WAS_SEEN = 1
MINIMAP_TILE_NOT_PATHABLE = 2
MINIMAP_TILE_NOT_WALKABLE = 4


def make_block() -> bytearray:
    return bytearray(DEFAULT_TILE * (MMBLOCK_SIZE * MMBLOCK_SIZE))


def tile_bytes(items: list[int], dat: dict[int, DatItem]) -> bytes | None:
    """Resolve a map tile the way Tile::getMinimapColorByte/isWalkable does."""
    if not items:
        return None

    ground = dat.get(items[0])
    has_ground = bool(ground and ground.ground)

    flags = MINIMAP_TILE_WAS_SEEN
    not_walkable = not has_ground
    not_pathable = False
    color = 255

    for item_id in reversed(items):
        item = dat.get(item_id)
        if item is None:
            continue
        if not item.common and color == 255 and item.minimap_color:
            color = item.minimap_color & 0xFF
        if item.not_walkable:
            not_walkable = True
        if item.not_pathable:
            not_pathable = True

    if not_walkable:
        flags |= MINIMAP_TILE_NOT_WALKABLE
    if not_pathable:
        flags |= MINIMAP_TILE_NOT_PATHABLE

    speed = ground.ground_speed if has_ground else 100
    speed = min((speed + 9) // 10, 255)
    return bytes((flags, color, speed))


def build_blocks(data: bytes, dat: dict[int, DatItem], stats: dict,
                 otb: dict[int, int] | None = None):
    blocks: dict[tuple[int, int, int], bytearray] = {}
    stats.update(tiles=0, tiles_without_ground=0, unknown_items=0, unmapped_items=0)

    known: set[int] = set()

    def on_tile(x: int, y: int, z: int, server_items: list[int]):
        key = (x // MMBLOCK_SIZE, y // MMBLOCK_SIZE, z)
        block = blocks.get(key)
        if block is None:
            block = make_block()
            blocks[key] = block
        stats["tiles"] += 1

        items = []
        for server_id in server_items:
            client_id = server_id if otb is None else otb.get(server_id)
            if client_id is None:
                stats["unmapped_items"] += 1
                if server_id not in known:
                    known.add(server_id)
                continue
            if client_id not in dat:
                stats["unknown_items"] += 1
                continue
            items.append(client_id)

        if not items:
            return
        if not dat[items[0]].ground:
            stats["tiles_without_ground"] += 1

        tile = tile_bytes(items, dat)
        if tile is None:
            return

        index = ((y % MMBLOCK_SIZE) * MMBLOCK_SIZE + (x % MMBLOCK_SIZE)) * 3
        block[index:index + 3] = tile

    walk_tiles(data, on_tile)
    stats["blocks"] = len(blocks)
    return blocks


def write_otmm(path: str, blocks: dict[tuple[int, int, int], bytearray]) -> int:
    # Block coordinates are absolute tile positions and the zero position is
    # the end-of-file marker.  OTC's loader rejects any block at x == 0 or
    # y == 0 and stops reading the rest of the file, so a block whose origin
    # is below 64 cannot be represented at all; dropping it keeps every other
    # floor loadable.  Such blocks only ever contain off-map void tiles.
    skipped = 0
    with open(path, "wb") as handle:
        handle.write(struct.pack("<IHHI", OTMM_SIGNATURE, 22, OTMM_VERSION, 0))
        description = b"OTMM 1.0"
        handle.write(struct.pack("<H", len(description)))
        handle.write(description)

        for (bx, by, z) in sorted(blocks, key=lambda key: (key[2], key[1], key[0])):
            if bx == 0 or by == 0:
                skipped += 1
                continue
            compressed = zlib.compress(bytes(blocks[(bx, by, z)]), 3)
            if len(compressed) > 0xFFFF:
                raise MapError("compressed minimap block exceeds the format limit")
            handle.write(struct.pack("<HHB", bx * MMBLOCK_SIZE,
                                     by * MMBLOCK_SIZE, z))
            handle.write(struct.pack("<H", len(compressed)))
            handle.write(compressed)

        handle.write(struct.pack("<HHB", 0, 0, 0))
    return skipped


def read_otmm(path: str) -> dict[tuple[int, int, int], bytes]:
    with open(path, "rb") as handle:
        data = handle.read()
    signature, start, version, _flags = struct.unpack_from("<IHHI", data, 0)
    if signature != OTMM_SIGNATURE:
        raise MapError("not an OTMM file")
    if version != 1:
        raise MapError(f"unsupported OTMM version {version}")

    blocks: dict[tuple[int, int, int], bytes] = {}
    pos = start
    while True:
        x, y, z = struct.unpack_from("<HHB", data, pos)
        pos += 5
        if x == 0 or y == 0 or z >= 16:
            break
        (length,) = struct.unpack_from("<H", data, pos)
        pos += 2
        block = zlib.decompress(data[pos:pos + length])
        pos += length
        if len(block) != MMBLOCK_BYTES:
            raise MapError(f"block ({x},{y},{z}) has {len(block)} bytes")
        blocks[(x // MMBLOCK_SIZE, y // MMBLOCK_SIZE, z)] = block
    return blocks


def compare(existing_path: str, blocks: dict[tuple[int, int, int], bytearray]):
    existing = read_otmm(existing_path)
    compared = 0
    seen = 0
    mismatches = {"flags": 0, "color": 0, "speed": 0}
    samples = []

    for key, block in existing.items():
        generated = blocks.get(key)
        if generated is None:
            continue
        for index in range(MMBLOCK_SIZE * MMBLOCK_SIZE):
            old = block[index * 3:index * 3 + 3]
            new = generated[index * 3:index * 3 + 3]
            if not (old[0] & MINIMAP_TILE_WAS_SEEN):
                continue
            compared += 1
            if old[1] != 255 or new[1] != 255:
                seen += 1
            if old == new:
                continue
            if old[0] != new[0]:
                mismatches["flags"] += 1
            if old[1] != new[1]:
                mismatches["color"] += 1
            if old[2] != new[2]:
                mismatches["speed"] += 1
            if len(samples) < 25:
                samples.append((
                    key[0] * MMBLOCK_SIZE + index % MMBLOCK_SIZE,
                    key[1] * MMBLOCK_SIZE + index // MMBLOCK_SIZE,
                    key[2], tuple(old), tuple(new),
                ))

    print(f"compared {compared} seen tiles in {len(existing)} stored blocks")
    print(f"tiles with a real colour: {seen}")
    print("mismatches: " + ", ".join(f"{name}={count}" for name, count in mismatches.items()))
    print("first mismatches (x, y, z, existing flags/color/speed, generated):")
    for x, y, z, old, new in samples:
        print(f"  ({x}, {y}, {z}) {old} -> {new}")


def main() -> int:
    default_dat = os.path.expanduser("~/repos/otclient/data/things/860/Tibia.dat")
    default_map = "data/world/global.otbm"

    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--map", default=default_map, help="OTBM world file")
    parser.add_argument("--items-otb", default="data/items/items.otb",
                        help="server items.otb used to translate map ids to client ids")
    parser.add_argument("--dat", default=os.environ.get("OTCLIENT_DAT", default_dat),
                        help="client DAT file (must match the map's item ids)")
    parser.add_argument("--out", default="minimap.otmm", help="output OTMM file")
    parser.add_argument("--compare", metavar="OTMM",
                        help="compare against an existing minimap instead of writing")
    parser.add_argument("--stats", action="store_true", help="print statistics only")
    args = parser.parse_args()

    if not os.path.exists(args.map):
        parser.error(f"map not found: {args.map}")
    if not os.path.exists(args.dat):
        parser.error(f"DAT not found: {args.dat}")
    if not os.path.exists(args.items_otb):
        parser.error(f"items.otb not found: {args.items_otb}")

    otb = load_items_otb(args.items_otb)
    print(f"items.otb: {len(otb)} server ids mapped ({args.items_otb})")

    dat = load_dat(args.dat)
    print(f"DAT: {len(dat)} items ({args.dat})")

    with open(args.map, "rb") as handle:
        data = handle.read()
    print(f"map: {len(data) / (1024 * 1024):.1f} MiB ({args.map})")

    stats: dict = {}
    blocks = build_blocks(data, dat, stats, otb)

    print(f"tiles: {stats['tiles']}")
    print(f"blocks: {stats['blocks']}")
    print(f"tiles without ground: {stats['tiles_without_ground']}")
    print(f"unmapped server ids: {stats['unmapped_items']} references")
    print(f"client ids missing from DAT: {stats['unknown_items']} references")

    if args.compare:
        compare(args.compare, blocks)
        return 0

    if args.stats:
        return 0

    skipped = write_otmm(args.out, blocks)
    if skipped:
        print(f"skipped {skipped} block(s) below x=64/y=64 (not representable in OTMM)")
    print(f"wrote {args.out} ({os.path.getsize(args.out) / (1024 * 1024):.1f} MiB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
