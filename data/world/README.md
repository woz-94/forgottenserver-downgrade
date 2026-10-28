# The world (map) is not stored in this repository

`global.otbm`, `spawn.xml` and `house.xml` are published as an immutable GitHub
release asset so that every RME save does not add ~95 MB to git history, and so
the engine image stays small (~100 MB smaller).

The deployed version is pinned in the homelab repo:
`services/tfs860/configmap.yaml` → `WORLD_VERSION` / `WORLD_URL` / `WORLD_SHA256`.
At pod start an init container downloads that tarball into an emptyDir mounted
at `/srv/data/world`.

## Publishing a new map

```bash
cd ~/repos/tfs860
./scripts/release-world.sh --from map-workspace --notes "training room"
```

The script tars the three files, uploads them to a `world-vN` release, verifies
the asset downloads and matches its checksum, and bumps the homelab configmap.
Then commit/push the homelab repo and sync the `tfs860` app in ArgoCD.

## Running the server locally

Pull the published tarball into this directory before starting the engine:

```bash
cd ~/repos/tfs860
version=$(grep -oE 'WORLD_VERSION: "[0-9]+"' ~/repos/homelab/services/tfs860/configmap.yaml | grep -oE '[0-9]+')
curl -fsSL "https://github.com/woz-94/forgottenserver-downgrade/releases/download/world-v${version}/world.tar.gz" \
  | tar -xz -C data/world
```

Local edits belong in `../map-workspace/` (gitignored) and are published with
`scripts/release-world.sh`.
