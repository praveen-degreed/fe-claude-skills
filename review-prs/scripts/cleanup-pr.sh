#!/usr/bin/env bash
# Remove a fetch dir created by fetch-pr.sh. Refuses anything that is not one.
# Usage: cleanup-pr.sh <fetch dir>
set -u

die() { echo "cleanup-pr: $*" >&2; exit 1; }

dir=${1:-}
[ -n "$dir" ] || die "usage: cleanup-pr.sh <fetch dir>"
[ -d "$dir" ] && [ ! -L "$dir" ] || die "not a plain directory: $dir"

# Name must be what fetch-pr.sh's mktemp produces: review-pr-<number>.<random>
case "$(basename "$dir")" in
  review-pr-[0-9]*.*) ;;
  *) die "refusing, not a review-pr fetch dir: $dir" ;;
esac

# And it must sit directly in the system temp dir fetch-pr.sh writes to.
parent=$(cd "$(dirname "$dir")" && pwd -P) || die "cannot resolve parent of $dir"
tmp=$(cd "${TMPDIR:-/tmp}" && pwd -P) || die "cannot resolve TMPDIR"
slash_tmp=$(cd /tmp && pwd -P)
[ "$parent" = "$tmp" ] || [ "$parent" = "$slash_tmp" ] || die "refusing, $dir is not directly in the temp dir"

rm -rf -- "${dir:?}"
echo "cleanup-pr: removed $dir"
