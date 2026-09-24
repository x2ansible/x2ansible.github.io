---
layout: default
title: Documentation versioning
parent: Developing
nav_order: 3
---

# Documentation versioning

The `latest/` tree is the working documentation for the current release. Released trees such as `v0.5/` are snapshots: do not edit them to fix current behavior. Keep deployment manifests in the matching `deploy/<version>/` directory as well.

## Release checklist

Use this checklist when a newer version is released:

- [ ] Confirm the release number and the commit/tag that the docs describe.
- [ ] Update `docs/latest/` for the new release and remove stale instructions.
- [ ] Update the current manifests in `deploy/` and test the installation commands.
- [ ] Copy the completed `docs/latest/` tree to `docs/v<version>/` (for example, `cp -a docs/latest docs/v0.6`).
- [ ] Copy versioned data files under `docs/_data/` (for example, `cp docs/_data/rhdh-plugins-latest.json docs/_data/rhdh-plugins-v06.json`) and update the copied pages' `version_data` values.
- [ ] Change the API URL in $version/platform/api-reference.md to the specific one
- [ ] Copy the deploy files to `deploy/v<version>/` (do not copy `secrets.yaml`): `cp deploy/{README.md,app.yaml,checluster.yaml,operator.yaml,secrets.yaml.template} deploy/v<version>/`.
- [ ] Add `docs/_includes/deploy-v<version>` pointing to `../../deploy/v<version>` and change the frozen installation pages to use that include and `deploy/v<version>/` paths.
- [ ] Add the new version to `docs/versions.md` and the links on `docs/index.md` if needed.
- [ ] Verify that Jekyll link tags, relative links, and deployment snippets stay inside the selected version.
- [ ] Build the site with `cd docs && make build`, then run `make check-links`.
- [ ] Review the generated URLs under `_site/latest/` and `_site/v<version>/` before merging.

## Adding a release directly

From the repository root, the mechanical part of a release can be done with:

```bash
version=v0.6
cp -a docs/latest "docs/$version"
mkdir -p "deploy/$version"
cp deploy/{README.md,app.yaml,checluster.yaml,operator.yaml,secrets.yaml.template} "deploy/$version/"
cp docs/_data/rhdh-plugins-latest.json "docs/_data/rhdh-plugins-$version.json"
ln -s "../../deploy/$version" "docs/_includes/deploy-$version"
```

Then complete the checklist above. In particular, update the copied version's platform documentation so it references its own deployment snapshot. Never use a symlink from a frozen version to the live `deploy/` directory.
