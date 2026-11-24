# [ChaseDickinson.com](https://chasedickinson.com)

Source for my personal website and the AWS setup that serves it. The site is one static page in S3 behind CloudFront, managed with OpenTofu.

## Layout

- `site/` is the page and its fonts. Images live in the bucket, not here (see Images).
- `tofu/` is the OpenTofu config for the bucket, the CloudFront distribution, the certificate, and DNS.
- `cloudformation/bootstrap.yml` holds what OpenTofu needs before it can run: the state bucket, GitHub's sign-in to AWS, and the plan and apply roles. It is deployed by hand with `cloudformation/deploy.sh`, and OpenTofu never manages it.
- `scripts/` previews the site, runs a local `tofu plan`, and publishes, checks, and prunes images. `lib.sh` holds the bucket-name helpers the others share.

## Preview locally

Run `mise install` once to get the tool versions that `mise.toml` pins. CI installs from the same file, so local runs and CI use the same versions.

`mise tasks` lists the commands below as tasks, such as `mise run preview`.

Run `scripts/preview.sh` and open http://localhost:8000. It syncs the images from the bucket into `site/images/`, then serves `site/`. Pass a port to use another one. Without AWS credentials it still serves, just without images.

## How changes ship

Every change is a pull request. CI runs the `pre-commit` hooks, `scripts/check-images.sh`, and `tofu plan`, and I read the plan on the run's summary page before merging. Merging to `main` runs `tofu apply`, then syncs `site/` to the bucket. The page and fonts cache for 60 seconds, so a page change shows up within about a minute with no invalidation.

## Images

Images are not in the repo. They live in the S3 bucket under content-hashed names, and `site/images/` is gitignored.

An image upload and its pull request go together:

1. Put the file in `site/images/` under a plain name, like `chase.jpg`.
2. Run `scripts/publish-images.sh`. It uploads the file as `name.<hash>.ext` and rewrites `site/index.html` to link to it.
3. Commit the `index.html` change and open a pull request.
4. Merge it.

Upload before you merge, or the page goes live with broken images. Don't upload without opening the pull request. `scripts/prune-images.sh` treats any hashed file the live page doesn't link to as removable once it is older than 7 days. Nothing runs it on a schedule, so an upload with no merged pull request stays in the bucket until you run the script. If a pull request stays open longer than that, run the prune script with a larger `--grace-days`.

`scripts/prune-images.sh` prints what it would remove and deletes only with `--delete`.

## Credits

The home-screen icon is the cowboy hat face from Google's [Noto Emoji](https://github.com/googlefonts/noto-emoji), set on the page's orange.
