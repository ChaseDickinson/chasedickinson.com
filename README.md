# [ChaseDickinson.com](https://chasedickinson.com)

Source code for my personal website.

Work in progress - playing around with GitHub Actions & Terraform Cloud

## Images

Images are not in the repo. They live in the S3 bucket under content-hashed names, and `site/images/` is gitignored.

An image upload and its pull request go together:

1. Put the file in `site/images/` under a plain name, like `chase.jpg`.
2. Run `scripts/publish-images.sh`. It uploads the file as `name.<hash>.ext` and rewrites `site/index.html` to link to it.
3. Commit the `index.html` change and open a pull request.
4. Merge it.

Upload before you merge, or the page goes live with broken images. Don't upload without opening the pull request. `scripts/prune-images.sh` removes any hashed file the live page doesn't link to once it is older than 7 days, so an upload with no merged pull request gets cleaned out. If a pull request stays open longer than that, run the prune script with a larger `--grace-days`.

`scripts/prune-images.sh` prints what it would remove and deletes only with `--delete`.
