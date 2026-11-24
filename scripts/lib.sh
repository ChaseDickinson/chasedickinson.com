# shellcheck shell=bash
# Shared by the other scripts and the deploy job. Source it, don't run it.
#
# Bucket names hold the account ID, which stays out of the repo and the logs. Build the
# names here and never print them.

account_id() {
  aws sts get-caller-identity --query Account --output text
}

web_bucket() {
  local account
  account="$(account_id)" || return 1
  echo "${account}-web-origin"
}

state_bucket() {
  local account
  account="$(account_id)" || return 1
  echo "${account}-terraform-state"
}
