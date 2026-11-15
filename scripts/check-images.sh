#!/usr/bin/env bash
# Check that every image site/index.html links to is served by the live site.
#
# Images are uploaded by hand with scripts/publish-images.sh before the pull request that
# links them is merged. CI runs this on every pull request, so a merge can't put a page
# with broken images online. It asks the public site, not the bucket, so it needs no AWS
# access and tests what visitors get.
#
# A link to an image without a hash in its name fails at once. Any other failure is
# retried for up to --wait seconds, because CloudFront caches a "missing" answer for about
# ten seconds and a file uploaded just before this runs can look missing for that long.
#
# Usage: scripts/check-images.sh [--wait SECONDS]

set -euo pipefail

site="https://chasedickinson.com"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
page="$root/site/index.html"
wait_seconds=60

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait)
      wait_seconds="${2:?--wait needs a number of seconds}"
      shift 2
      ;;
    *)
      echo "usage: $0 [--wait SECONDS]" >&2
      exit 2
      ;;
  esac
done

refs="$(grep -oE 'images/[A-Za-z0-9._-]+' "$page" | sort -u || true)"
if [[ -z "$refs" ]]; then
  echo "site/index.html links to no images, which looks like a mistake" >&2
  exit 1
fi

unhashed=""
while IFS= read -r ref; do
  if [[ ! "$ref" =~ \.[0-9a-f]{12}\.[a-z]+$ ]]; then
    unhashed="$unhashed  $ref"$'\n'
  fi
done <<< "$refs"
if [[ -n "$unhashed" ]]; then
  echo "these links have no hash in the name:" >&2
  printf '%s' "$unhashed" >&2
  echo "run scripts/publish-images.sh to upload the images and rewrite the links" >&2
  exit 1
fi

pending="$refs"
deadline=$((SECONDS + wait_seconds))

while true; do
  still=""
  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$site/$ref" || true)"
    if [[ "$code" == "200" ]]; then
      echo "ok       $ref"
    else
      still="$still$ref"$'\n'
    fi
  done <<< "$pending"
  pending="$still"

  [[ -n "$pending" ]] || break

  if ((SECONDS >= deadline)); then
    echo >&2
    echo "not served by $site after ${wait_seconds}s:" >&2
    printf '%s' "$pending" | sed 's/^/  /' >&2
    echo "run scripts/publish-images.sh to upload them, then run this again" >&2
    exit 1
  fi
  echo "waiting  $(printf '%s' "$pending" | grep -c .) not served yet, trying again in 5s"
  sleep 5
done

echo "all images are served"
