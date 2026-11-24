#!/usr/bin/env bash
# Upload site/images/ to the origin bucket under content-hashed names and point
# site/index.html at them. Run it before merging the pull request that ships the change.
#
# A hashed name never changes content, so each image can be cached for a year and the
# site never needs an invalidation. Only index.html changes which names it points at, and
# CI deploys it with a 60 second cache time.
#
# Usage: scripts/publish-images.sh [--dry-run]
#
# Put the source files in site/images/ under plain names (chase.jpg, github-black.svg).
# That folder is gitignored. Uses the default AWS credentials or AWS_PROFILE.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
images="$root/site/images"
page="$root/site/index.html"
dry_run=false
# shellcheck source=lib.sh
source "$root/scripts/lib.sh"

case "${1:-}" in
  "") ;;
  -n | --dry-run) dry_run=true ;;
  *)
    echo "usage: $0 [--dry-run]" >&2
    exit 2
    ;;
esac

content_type() {
  case "$1" in
    svg) echo "image/svg+xml" ;;
    png) echo "image/png" ;;
    jpg | jpeg) echo "image/jpeg" ;;
    webp) echo "image/webp" ;;
    *)
      echo "no content type for .$1" >&2
      return 1
      ;;
  esac
}

bucket=""
if ! $dry_run; then
  bucket="$(web_bucket)"
fi

new_page="$(mktemp)"
trap 'rm -f "$new_page"' EXIT
cp "$page" "$new_page"

for file in "$images"/*; do
  [[ -f "$file" ]] || continue
  name="$(basename "$file")"
  stem="${name%.*}"
  ext="${name##*.}"

  if [[ "$stem" =~ \.[0-9a-f]{12}$ ]]; then
    echo "skip $name: the name already looks hashed, rename the source file" >&2
    continue
  fi

  type="$(content_type "$ext")"
  hash="$(shasum -a 256 "$file" | cut -c1-12)"
  hashed="$stem.$hash.$ext"

  if $dry_run; then
    echo "would upload images/$hashed"
  elif aws s3api head-object --bucket "$bucket" --key "images/$hashed" > /dev/null 2>&1; then
    echo "already there: images/$hashed"
  else
    aws s3 cp "$file" "s3://$bucket/images/$hashed" \
      --content-type "$type" \
      --cache-control "public, max-age=31536000, immutable" > /dev/null
    echo "uploaded: images/$hashed"
  fi

  # Matches the plain name or an older hashed name, so the script can run again.
  sed -E "s#images/$stem(\.[0-9a-f]{12})?\.$ext#images/$hashed#g" "$new_page" > "$new_page.next"
  mv "$new_page.next" "$new_page"
done

if $dry_run; then
  echo
  echo "changes to site/index.html:"
  diff -u "$page" "$new_page" || true
else
  cp "$new_page" "$page"
  echo
  echo "Updated site/index.html. Commit it, then merge the pull request."
  echo "Old hashed images stay in the bucket. Run scripts/prune-images.sh to see which ones nothing links to."
fi
