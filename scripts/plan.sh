#!/usr/bin/env bash
# Run the same read-only plan CI runs on a pull request.
#
# It initializes OpenTofu against the state bucket, then plans without taking the state lock.
# Pass extra `tofu plan` flags after the script name.
#
# Usage: scripts/plan.sh [tofu plan flags]
#
# Uses the default AWS credentials or AWS_PROFILE. The plan role in CI is read-only; yours
# probably isn't, so this only plans and never applies.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$root/scripts/lib.sh"

cd "$root/tofu"
tofu init -input=false -backend-config="bucket=$(state_bucket)"
tofu validate
tofu plan -input=false -lock=false "$@"
