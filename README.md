# Podplane Dependencies

This repository publishes the static dependency manifests served from
`https://cli.podplane.dev/deps/manifests/`.

The manifest-producing repositories remain the source of truth for release
artifacts. This repository only mirrors the latest released manifest assets into
a static object-storage bucket.

## Published paths

The build writes these public paths:

```text
/deps/manifests/components.json
/deps/manifests/templates.json
/deps/manifests/seeds.json
/deps/manifests/vmconfig_knd_debian-13_amd64.json
/deps/manifests/vmconfig_knd_debian-13_arm64.json
/deps/manifests/vmconfig_knc_debian-13_amd64.json
/deps/manifests/vmconfig_knc_debian-13_arm64.json
```

## How publishing works

1. `scripts/build.sh` reads `config/manifests.json`.
2. For each configured entry, it fetches the latest GitHub Release for the
   source repository.
3. It downloads the matching JSON release asset.
4. It validates that the asset is JSON.
5. It writes the file under `dist/deps/manifests/`.
6. The GitHub Action uses `rclone sync` to publish `dist/` to the configured
   object-storage destination.

If the build step fails, the workflow fails before the `rclone sync` step runs,
so incomplete or invalid generated output is not published.

## Local build

```bash
make build
```

Set `GH_TOKEN` if you want a higher GitHub API rate limit:

```bash
GH_TOKEN=ghp_... make build
```

The build script intentionally uses only Bash plus the standard GitHub Actions
CLI tools: `gh`, `jq`, and `curl`.

## Repository setup

The `sync` workflow publishes `dist/` with `rclone`. The storage backend is
intentionally configured through generic rclone settings rather than
provider-specific workflow logic:

```text
RCLONE_CONFIG       # secret containing a complete rclone config file
RCLONE_DESTINATION  # variable or secret, for example: `deps:<bucket-name>`
```

The public DNS name `cli.podplane.dev` points at the object-storage bucket
configured by `RCLONE_DESTINATION`. If the backing store changes later, only the
rclone config/destination should need to change; the generated `dist/` tree and
public URL layout stay the same.

## Publishing repo triggers

The workflow runs periodically, on pushes to `main`, and by manual
`workflow_dispatch`. Manifest-producing repositories can trigger it after their
release workflow has created the GitHub Release and uploaded the manifest asset.

Those repositories use a GitHub App token with access to `podplane/deps` and
permission to dispatch workflows:

```yaml
- name: Create deps app token
  id: deps-app
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.PODPLANE_DEPS_APP_ID }}
    private-key: ${{ secrets.PODPLANE_DEPS_APP_PRIVATE_KEY }}
    owner: podplane
    repositories: deps

- name: Trigger deps sync
  env:
    GH_TOKEN: ${{ steps.deps-app.outputs.token }}
  run: |
    gh workflow run sync.yml \
      --repo podplane/deps \
      --ref main \
      -f source_repo="${GITHUB_REPOSITORY}" \
      -f source_ref="${GITHUB_REF_NAME}"
```

The `source_repo` and `source_ref` fields are only for audit/debug logs. The sync
workflow always reconciles every configured manifest, so publishing repositories
do not get direct write access to the published bucket.

## Learn More

Learn more about Podplane at the official project website: [podplane.dev](https://podplane.dev)

## License

Podplane is licensed under the Apache License, Version 2.0.
Copyright The Podplane Authors.

See the [LICENSE](./LICENSE) file for details.
