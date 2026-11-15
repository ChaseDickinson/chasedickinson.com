#!/bin/bash
# Deploys the prerequisites stack with your own AWS credentials.
# Usage: cloudformation/deploy.sh [--no-execute-changeset]
set -euo pipefail

cd "$(dirname "$0")"

domain="chasedickinson.com"
zone_id=$(aws route53 list-hosted-zones-by-name --dns-name "$domain" \
    --query "HostedZones[?Name=='${domain}.'].Id | [0]" --output text)
if [[ "$zone_id" == "None" || -z "$zone_id" ]]; then
    echo "No Route 53 hosted zone found for $domain" >&2
    exit 1
fi

aws cloudformation deploy \
    --region us-east-1 \
    --stack-name website-bootstrap \
    --template-file bootstrap.yml \
    --capabilities CAPABILITY_NAMED_IAM \
    --no-fail-on-empty-changeset \
    --parameter-overrides "HostedZoneId=${zone_id##*/}" \
    "$@"
