#!/usr/bin/env bash
# Remove images from the origin bucket that the deployed page no longer links to.
#
# It reads the page that is live in the bucket, not the local copy, so a stale checkout
# can't make it delete an image the site still uses. A file is kept if the live page links
# to it, if it is on the keep list, or if it is a hashed file uploaded within the grace
# period (an open tab or a cached copy of the old page can still point at an old name).
# Unhashed files are not part of the hashed scheme and are removed.
#
# Usage: scripts/prune-images.sh [--delete] [--grace-days N] [--keep NAME]...
#
# Without --delete it only prints what it would remove. NAME is a file name under
# images/, for example --keep hula_hoop.jpg. Uses the default AWS credentials or AWS_PROFILE.

set -euo pipefail

usage() {
  echo "usage: $0 [--delete] [--grace-days N] [--keep NAME]..." >&2
}

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$root/scripts/lib.sh"

delete=false
grace_days=7
keep_list=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --delete)
      delete=true
      shift
      ;;
    --grace-days)
      grace_days="${2:?--grace-days needs a number}"
      shift 2
      ;;
    --keep)
      keep_list="$keep_list${2:?--keep needs a file name}"$'\n'
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

# The confirmation prompt needs a terminal. Without one, read fails and set -e ends the
# script with no message, so say so before doing any work.
if $delete && [[ ! -t 0 ]]; then
  echo "--delete needs a terminal to ask for confirmation, so run it in a terminal tab" >&2
  exit 1
fi

bucket="$(web_bucket)"

referenced="$(aws s3 cp "s3://$bucket/index.html" - | grep -o 'images/[^"]*' | sort -u || true)"
if [[ -z "$referenced" ]]; then
  echo "the live page links to no images, so nothing is safe to remove" >&2
  exit 1
fi

cutoff="$(date -u -v-"${grace_days}"d +%Y-%m-%dT%H:%M:%S 2> /dev/null ||
  date -u -d "-${grace_days} days" +%Y-%m-%dT%H:%M:%S)"

remove=""
count=0

while IFS=$'\t' read -r key modified; do
  [[ -n "$key" && "$key" != "None" && "$key" != */ ]] || continue
  name="${key#images/}"

  if grep -qxF -- "$key" <<< "$referenced"; then
    echo "keep    $name (linked)"
  elif grep -qxF -- "$name" <<< "$keep_list"; then
    echo "keep    $name (keep list)"
  elif [[ "$name" =~ \.[0-9a-f]{12}\.[a-z]+$ && "${modified:0:19}" > "$cutoff" ]]; then
    echo "keep    $name (uploaded within $grace_days days)"
  else
    echo "remove  $name"
    remove="$remove$key"$'\n'
    count=$((count + 1))
  fi
done < <(aws s3api list-objects-v2 --bucket "$bucket" --prefix images/ \
  --query 'Contents[].[Key,LastModified]' --output text)

echo
if [[ "$count" -eq 0 ]]; then
  echo "nothing to remove"
  exit 0
fi

if ! $delete; then
  echo "$count file(s) would be removed. Run again with --delete to remove them."
  exit 0
fi

read -r -p "Remove $count file(s) from the bucket? [y/N] " answer
if [[ "$answer" != "y" ]]; then
  echo "cancelled"
  exit 1
fi

while IFS= read -r key; do
  [[ -n "$key" ]] || continue
  aws s3 rm "s3://$bucket/$key" > /dev/null
  echo "removed ${key#images/}"
done <<< "$remove"
echo "Removed files can still be served from CloudFront's cache for up to a day."
