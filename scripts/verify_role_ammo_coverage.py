#!/usr/bin/env python3
"""Verify that every role-ammo item used by LastHomeRoles is present in COMMUNITY_STOCK_ITEMS.

This enforces LH-26 spec §7: munitions(roleDefs) − munitions(stock) must be empty.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROLES_PATH = ROOT / "media/lua/shared/LastHomeRoles.lua"

AMMO_PATTERNS = (
    "Clip",
    "Bullets",
    "Bullet",
    "ShotgunShells",
    "Speed",
    "Belt",
)
EXPLICIT_AMMO_IDS = {
    "Base.Bolt_Bear",
    "Base.Bolt_Bear_Pack",
}


def load_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        sys.exit(2)


def extract_table_block(lua: str, table_name: str) -> str:
    pattern = re.compile(rf"{re.escape(table_name)}\s*=\s*\{{(.*?)\n\}}", re.S)
    match = pattern.search(lua)
    if match is None:
        print(f"ERROR: table not found: {table_name}", file=sys.stderr)
        sys.exit(2)
    return match.group(1)


def extract_item_ids(lua_block: str) -> list[str]:
    return re.findall(r'\{"([^"]+)"\s*,\s*\d+\}', lua_block)


def is_ammo(item_id: str) -> bool:
    if item_id in EXPLICIT_AMMO_IDS:
        return True
    short = item_id.split(".")[-1]
    return any(token in short for token in AMMO_PATTERNS) or short == "556Belt"


def main() -> int:
    lua = load_text(ROLES_PATH)
    stock_block = extract_table_block(lua, "Roles.COMMUNITY_STOCK_ITEMS")
    stock_ids = set(extract_item_ids(stock_block))

    role_defs_block = extract_table_block(lua, "Roles.ROLE_DEFS")
    role_item_ids = extract_item_ids(role_defs_block)
    ammo_ids = sorted({item_id for item_id in role_item_ids if is_ammo(item_id)})
    missing = [item_id for item_id in ammo_ids if item_id not in stock_ids]

    print(f"Roles file: {ROLES_PATH}")
    print(f"Ammo IDs referenced by ROLE_DEFS: {len(ammo_ids)}")
    print(f"Ammo IDs covered by COMMUNITY_STOCK_ITEMS: {len(ammo_ids) - len(missing)}/{len(ammo_ids)}")

    if missing:
        print("\nMissing ammo IDs:")
        for item_id in missing:
            print(f"- {item_id}")
        return 1

    print("\nOK: ammo coverage is complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
