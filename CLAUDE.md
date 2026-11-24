# chasedickinson.com

Personal website, served from S3 behind CloudFront. The AWS resources are in `tofu/`. Run them with `tofu`, never `terraform`.

## Not obvious from the files

- `cloudformation/bootstrap.yml` is what OpenTofu needs before it can run: the state bucket, GitHub OIDC sign-in, and the plan and apply roles. Deploy it by hand with `cloudformation/deploy.sh`. OpenTofu never manages it.
- Photos and logos never go in this repo, which is public and MIT licensed. Images live in the S3 bucket and are uploaded by hand, and the site deploy sync excludes `images/`. Upload them with `scripts/publish-images.sh` and open the pull request that links them in the same session. An upload with no pull request looks unlinked, and `scripts/prune-images.sh` removes it after 7 days when someone runs it. Nothing runs it on a schedule. See the README.

## Pull requests

- Never commit to `main`. The `no-commit-to-branch` hook blocks it. Make a short-lived branch for each change and open a pull request.
- Don't merge pull requests. The repo owner reviews and merges them.
- Don't push, open a pull request, or comment on one unless asked.

## Before committing

- Run `pre-commit run --all-files` and fix what it reports. Never skip hooks with `--no-verify`.
- If a hook fails and you can't tell why, say so. Don't loosen the hook to get past it.

## AWS changes

- Reading is fine: `tofu plan`, `aws ... describe-*`, `aws ... list-*`.
- Never delete or destroy a resource. Remove it from `tofu/` and let CI apply the change. The repo owner deletes the bootstrap stack by hand.
- A `moved` or `import` block is temporary. Add it in the pull request that needs it. Once CI has applied that change and `tofu plan` reports no changes, remove the block in a follow-up pull request. This repo has one state, so nothing else needs the block.
- Prefer `aws` and `tofu` features over third-party tools. Follow the global rule on installing software.

## Secrets

This repo is public. Never commit credentials, tokens, state files, or the AWS account ID. Build names and ARNs from `data.aws_caller_identity` or `AWS::AccountId`, never a literal. Keep the account ID out of commit messages, pull request descriptions, and comments too. The role ARNs contain it, so they live in GitHub secrets, not variables.
