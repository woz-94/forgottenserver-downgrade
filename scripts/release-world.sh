#!/usr/bin/env bash
# Publish the map as an immutable GitHub release asset, then pin that release in
# the tfs860 configmap so ArgoCD rolls the Deployment.
#
# The engine image no longer ships data/world: an init container downloads
# world.tar.gz from the release into an emptyDir mounted at /srv/data/world.
# That keeps ~100 MB of map out of the image and out of git, while the deployed
# map version stays declarative (WORLD_VERSION/WORLD_URL/WORLD_SHA256 in
# services/tfs860/configmap.yaml).
#
# Usage:
#   ./scripts/release-world.sh                     # tar map-workspace/, publish next world-vN, bump configmap
#   ./scripts/release-world.sh --from data/world   # explicit source directory
#   ./scripts/release-world.sh --build-only        # build + checksum only, no upload, no bump
#   ./scripts/release-world.sh --no-bump           # publish, print configmap keys, don't edit
#   ./scripts/release-world.sh --version 7         # force world-v7
#   ./scripts/release-world.sh --notes "training room" --dry-run
#
# Then:
#   git -C ~/repos/homelab add services/tfs860 && git commit && git push
#   sync app 'tfs860' in ArgoCD
set -euo pipefail

repo="${WORLD_RELEASE_REPO:-woz-94/forgottenserver-downgrade}"
homelab="${WORLD_HOMELAB_DIR:-$HOME/repos/homelab}"
configmap="${homelab}/services/tfs860/configmap.yaml"

source_dir=""
version=""
notes=""
build_only=0
bump=1
dry_run=0

die() {
	echo "error: $*" >&2
	exit 1
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--from)
		source_dir="${2:?--from needs a directory}"
		shift 2
		;;
	--version)
		version="${2:?--version needs a number}"
		shift 2
		;;
	--notes)
		notes="${2:?--notes needs a string}"
		shift 2
		;;
	--build-only)
		build_only=1
		shift
		;;
	--no-bump)
		bump=0
		shift
		;;
	--dry-run)
		dry_run=1
		shift
		;;
	-h | --help)
		sed -n '2,22p' "$0"
		exit 0
		;;
	*) die "unknown argument: $1 (try --help)" ;;
	esac
done

[[ -f "$configmap" ]] || die "configmap not found: $configmap (set WORLD_HOMELAB_DIR)"

# The engine loads data/world/<mapName>.otbm, so the tarball must match it.
map_name="$(grep -oE '^[[:space:]]*mapName = "[^"]+"' "$configmap" | head -1 | sed 's/.*"\(.*\)"/\1/')"
[[ -n "$map_name" ]] || die "could not read mapName from $configmap"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "$source_dir" ]]; then
	for candidate in "$repo_root/map-workspace" "$repo_root/data/world"; do
		if [[ -s "$candidate/${map_name}.otbm" && -s "$candidate/spawn.xml" && -s "$candidate/house.xml" ]]; then
			source_dir="$candidate"
			break
		fi
	done
fi
[[ -n "$source_dir" ]] || die "no source directory with ${map_name}.otbm + spawn.xml + house.xml (use --from)"
source_dir="$(cd "$source_dir" && pwd)"

otbm="${source_dir}/${map_name}.otbm"
[[ -s "$otbm" ]] || die "missing or empty: ${otbm}"
[[ -s "$source_dir/spawn.xml" ]] || die "missing or empty: ${source_dir}/spawn.xml"
[[ -s "$source_dir/house.xml" ]] || die "missing or empty: ${source_dir}/house.xml"

# The OTBM header names the spawn/house files; a mismatch means the engine loads
# the map but silently drops every spawn.
refs="$(grep -a -o -E '[A-Za-z0-9_.-]+\.xml' "$otbm" | sort -u | tr '\n' ' ')"
for expected in spawn.xml house.xml; do
	grep -qw -- "$expected" <<<"$refs" || die "OTBM does not reference ${expected} (it references: ${refs:-nothing})"
done

spawns="$(grep -c '<spawn ' "$source_dir/spawn.xml" || true)"
houses="$(grep -c '<house ' "$source_dir/house.xml" || true)"

echo "source:  ${source_dir}"
echo "map:     ${map_name}.otbm ($(du -h "$otbm" | cut -f1))"
echo "spawns:  ${spawns} areas"
echo "houses:  ${houses}"
for f in "${map_name}.otbm" spawn.xml house.xml; do
	printf 'file:    %s  %s\n' "$(date -r "$source_dir/$f" -u +%Y-%m-%dT%H:%M:%SZ)" "$f"
done
echo

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Entries at the archive root: the init container extracts straight into the
# world volume.
tar -czf "$tmp/world.tar.gz" -C "$source_dir" "${map_name}.otbm" spawn.xml house.xml
(
	cd "$tmp"
	sha256sum world.tar.gz >world.tar.gz.sha256
)
sha="$(cut -d' ' -f1 "$tmp/world.tar.gz.sha256")"
size="$(stat -c %s "$tmp/world.tar.gz")"

if [[ -z "$version" ]]; then
	last="$(gh release list --repo "$repo" --limit 200 --json tagName --jq '.[].tagName' 2>/dev/null |
		sed -n 's/^world-v\([0-9][0-9]*\)$/\1/p' | sort -n | tail -1)"
	version=$((${last:-0} + 1))
fi
tag="world-v${version}"
url="https://github.com/${repo}/releases/download/${tag}/world.tar.gz"
notes="${notes:-World ${tag} from $(basename "$source_dir")}"

echo "artifact: world.tar.gz (${size} bytes, sha256 ${sha})"
echo "release:  ${repo} ${tag}"
echo "url:      ${url}"
echo

print_configmap_keys() {
	cat <<EOF
configmap values (${configmap}):
  WORLD_VERSION: "${version}"
  WORLD_URL: "${url}"
  WORLD_SHA256: "${sha}"
EOF
}

if [[ $build_only -eq 1 ]]; then
	echo "build-only: nothing uploaded"
	print_configmap_keys
	exit 0
fi

if [[ $dry_run -eq 1 ]]; then
	echo "dry-run: would create release ${tag} and upload world.tar.gz + world.tar.gz.sha256"
	print_configmap_keys
	exit 0
fi

if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
	die "release ${tag} already exists; pick another --version"
fi

gh release create "$tag" --repo "$repo" --title "World ${tag}" --notes "$notes"
gh release upload "$tag" --repo "$repo" "$tmp/world.tar.gz" "$tmp/world.tar.gz.sha256"

# Verify what the cluster will actually download, unauthenticated: the repo is
# public, so this proves the init container needs no token.
curl -fsSL --retry 3 --retry-delay 2 -o "$tmp/verify.tar.gz" "$url"
echo "${sha}  ${tmp}/verify.tar.gz" | sha256sum -c -

if [[ $bump -eq 1 ]]; then
	python3 - "$configmap" "$version" "$url" "$sha" <<'PY'
import re
import sys

path, version, url, sha = sys.argv[1:5]
text = open(path).read()
block = (
    f'  WORLD_VERSION: "{version}"\n'
    f'  WORLD_URL: "{url}"\n'
    f'  WORLD_SHA256: "{sha}"\n'
)

if re.search(r'^  WORLD_VERSION:.*$', text, re.M):
    text = re.sub(r'^  WORLD_VERSION:.*$', f'  WORLD_VERSION: "{version}"', text, count=1, flags=re.M)
    text = re.sub(r'^  WORLD_URL:.*$', f'  WORLD_URL: "{url}"', text, count=1, flags=re.M)
    text = re.sub(r'^  WORLD_SHA256:.*$', f'  WORLD_SHA256: "{sha}"', text, count=1, flags=re.M)
else:
    anchor = re.search(r'^  TFS860_MOTD:.*$', text, re.M)
    if not anchor:
        sys.exit(f'TFS860_MOTD anchor not found in {path}')
    text = text[: anchor.end()] + '\n' + block.rstrip('\n') + text[anchor.end() :]

open(path, 'w').write(text)
PY
	echo "pinned ${tag} in ${configmap}"
else
	print_configmap_keys
fi

echo
echo "next:"
echo "  git -C ${homelab} diff services/tfs860/configmap.yaml"
echo "  git -C ${homelab} add services/tfs860 && git commit && git push"
echo "  sync app 'tfs860' in ArgoCD (pod restarts, init downloads ${size} bytes)"
