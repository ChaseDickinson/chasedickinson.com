#!/usr/bin/env bash
# Preview the site at http://localhost:8000.
#
# Images live in the bucket, not the repo, so this syncs them into site/images/ first.
# That folder is gitignored. If the sync fails (no credentials, offline), it warns and
# serves anyway, which is fine for text and layout changes.
#
# Usage: scripts/preview.sh [port]
#
# Uses the default AWS credentials or AWS_PROFILE.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
port="${1:-8000}"

if [[ ! "$port" =~ ^[0-9]+$ ]]; then
  echo "usage: $0 [port]" >&2
  exit 2
fi

# The bucket name holds the account ID, so build it here and never print it.
if bucket="$(aws sts get-caller-identity --query Account --output text 2> /dev/null)-web-origin" &&
  aws s3 sync "s3://$bucket/images" "$root/site/images" --only-show-errors; then
  :
else
  echo "warning: could not sync images from the bucket, serving without them" >&2
fi

echo "Serving http://localhost:$port"
exec python3 -m http.server "$port" --bind 127.0.0.1 --directory "$root/site"
