# AGENTS.md

Repository-specific invariants for the 8.60 TFS server data. Read this before
changing items, NPCs, travel, consumables, the in-game store, or deployments.

## Deployment Gate (Mandatory)

- All runtime changes deploy through ArgoCD. Do not `kubectl apply`, `kubectl
  edit`, `kubectl exec`, or otherwise mutate running pods directly; a direct
  change drifts from git and is overwritten on the next sync.
- Runtime settings live in the homelab repo:
  `~/repos/homelab/services/tfs860/configmap.yaml`.
- Images are built by the fork's GitHub Actions workflow
  (`woz-94/forgottenserver-downgrade`, `Container Images`). Push code, let CI
  build, then let ArgoCD roll it out.
- Local full builds are not reliable on this host because the system Boost
  (1.92) lacks `io_service` / `io_context::work`. Use CI for build validation.
- `gh` in this checkout defaults to the upstream repo. Run
  `gh repo set-default woz-94/forgottenserver-downgrade` before using `gh`
  commands, or pass `--repo` explicitly.

## Item ID Semantics

- Server IDs come from `data/items/items.otb`, not from modern TibiaWiki or
  TibiaWeb IDs.
- `data/items/items.xml` is a mixed 8.60/modern table and is not authoritative.
  Use `~/repos/RME/data/860/items.xml` for matched 8.60 names.
- The client sprite ID is the OTB attribute `0x11`; never feed a modern client
  ID into map/loot/NPC code.
- Do not regenerate or bulk-replace `items.otb`. If a single server ID must be
  corrected (for example a ground tile), patch only that ID and record the
  original file hash in the change description.
- Loot-only item inventory: `loot_items.md` (repo root). Regenerate from
  `data/monster/**/*.xml` `<item id>` / `<item name>` resolved through
  `items.xml`, and report unresolved IDs explicitly.

## Travel and Sailing

- All travel is free and premium-free. Level and PZ checks stay.
- Sailing destinations are shared through
  `data/npc/lib/npcsystem/sea_travel.lua`. Add destinations with
  `SeaTravel.add(...)`; do not reintroduce per-captain destination subsets or
  costs.
- `StdModule.travel` must ignore travel cost and premium. `|TRAVELCOST|`
  renders `free`. Keep coach and tower teleports free as well.
- When changing travel, verify every sailing NPC still exposes the full
  destination network, including quest/special boats and custom islands.

## NPC System

- `PlayerStorageKeys` lives in `data/lib/core/storages.lua`. Do not remove it;
  legacy NPC scripts reference it.
- `getPlayerStorageValue` returns `-1` for unset storage (compat layer in
  `data/lib/compat/compat.lua`). Do not reintroduce `nil` returns.
- NPC XML `script=` values are case- and path-sensitive. Match the file on disk
  exactly.
- Lua string escapes must be valid (`\m` and similar are not). Prefer quoting
  the whole string when in doubt.

## Consumables

- `removeChargesFromPotions = false` and `removeChargesFromRunes = false` in
  `config.lua.dist` and the deployed ConfigMap. Potions/runes must not be
  consumed on use.
- The empty flask is added only when a potion is actually consumed.
- Keep the runtime ConfigMap values in sync with `config.lua.dist`; a fix only
  in git is not deployed until ArgoCD syncs.

## Mobile Store (`!store`)

- Opens a buy/sell window anywhere out of combat, for all players.
- Implemented in `data/scripts/lib/mobile_store.lua`,
  `data/scripts/lib/mobile_store_catalog.lua`, and
  `data/scripts/talkactions/player/store.lua`.
- Prices aggregate NPC shops: lowest buy price, highest sell price. If
  `maxSell >= minBuy`, sell is 10% below buy.
- The catalog is static and edited manually; do not hide NPCs from the world to
  make prices work.
- Keep the classic trade UI.

## Map and World Artifacts

- Map fixes require rebuilding/publishing the world artifact and updating the
  deployed ConfigMap; do not patch a running pod.
- `data/scripts/actions/others/teleport.lua` must not blindly teleport `z+1`
  into sealed geometry. Validate the destination tile exists and is reachable
  before moving the player.

## Verification

Before committing:

- Run targeted Lua syntax checks on every changed Lua file.
- `rg` for leftover debug output (for example `[cavebot-debug]`, temporary
  `/tmp/` logging).
- Confirm no direct cluster mutations were made; list the files that ArgoCD
  must sync.
- For item changes, state which server IDs changed and verify they exist in
  `items.otb`.
- For NPC changes, verify the referenced script path and case exist.
