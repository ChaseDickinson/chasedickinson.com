#!/usr/bin/env bash
# Print the open Dependabot branches on origin after you switch branches.
#
# Runs as a post-checkout hook through pre-commit. It only reports and always exits 0, so it
# never blocks a checkout, and it says nothing when there is nothing to report or the remote
# can't be reached. Install it once with:
#
#   pre-commit install --hook-type post-checkout
#
# It asks the remote with `git ls-remote`, which needs no GitHub CLI. If `gh` is installed
# it also prints each pull request's number and title.
#
# Usage: scripts/check-dependabot.sh

set -uo pipefail

# pre-commit sets this to 1 for a branch checkout and 0 for a file checkout.
[[ "${PRE_COMMIT_CHECKOUT_TYPE:-1}" == "1" ]] || exit 0

# Short timeouts, so being offline doesn't stall `git switch`. BatchMode stops ssh prompting.
branches="$(
  GIT_SSH_COMMAND="ssh -o ConnectTimeout=5 -o BatchMode=yes" \
    git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=5 \
    ls-remote --heads origin 'dependabot/*' 2> /dev/null | sed 's#.*refs/heads/##'
)"
[[ -n "$branches" ]] || exit 0

count="$(grep -c . <<< "$branches")"
echo "Dependabot has $count open update branch(es) on origin:"

prs=""
if command -v gh > /dev/null; then
  prs="$(gh pr list --author 'app/dependabot' --state open \
    --json number,title --jq '.[] | "  #\(.number) \(.title)"' 2> /dev/null || true)"
fi

if [[ -n "$prs" ]]; then
  echo "$prs"
else
  while IFS= read -r branch; do
    echo "  $branch"
  done <<< "$branches"
fi
exit 0
