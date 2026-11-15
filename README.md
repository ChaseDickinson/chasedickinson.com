# [ChaseDickinson.com](https://chasedickinson.com)

Source for my personal website and the AWS setup that serves it. The site is one static page in S3 behind CloudFront, managed with OpenTofu.

## Layout

- `site/` is the page and its fonts. Images live in the bucket, not here (see Images).
- `tofu/` is the OpenTofu config for the bucket, the CloudFront distribution, the certificate, and DNS.
- `cloudformation/bootstrap.yml` holds what OpenTofu needs before it can run: the state bucket, GitHub's sign-in to AWS, and the plan and apply roles. It is deployed by hand with `cloudformation/deploy.sh`, and OpenTofu never manages it.
- `scripts/` publishes, checks, and prunes images.

## How changes ship

Every change is a pull request. CI runs the `pre-commit` hooks, `scripts/check-images.sh`, and `tofu plan`, and I read the plan in the Actions log before merging. Merging to `main` runs `tofu apply`, then syncs `site/` to the bucket. The page and fonts cache for 60 seconds, so a page change shows up within about a minute with no invalidation.

## Images

Images are not in the repo. They live in the S3 bucket under content-hashed names, and `site/images/` is gitignored.

An image upload and its pull request go together:

1. Put the file in `site/images/` under a plain name, like `chase.jpg`.
2. Run `scripts/publish-images.sh`. It uploads the file as `name.<hash>.ext` and rewrites `site/index.html` to link to it.
3. Commit the `index.html` change and open a pull request.
4. Merge it.

Upload before you merge, or the page goes live with broken images. Don't upload without opening the pull request. `scripts/prune-images.sh` removes any hashed file the live page doesn't link to once it is older than 7 days, so an upload with no merged pull request gets cleaned out. If a pull request stays open longer than that, run the prune script with a larger `--grace-days`.

`scripts/prune-images.sh` prints what it would remove and deletes only with `--delete`.

## Credits

The home-screen icon is the cowboy hat face from Google's [Noto Emoji](https://github.com/googlefonts/noto-emoji), set on the page's orange.
