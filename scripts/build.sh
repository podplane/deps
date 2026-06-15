#!/usr/bin/env bash
# Podplane <https://podplane.dev>
# Copyright The Podplane Authors
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="${root}/config/manifests.json"
dist_dir="${root}/dist"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

need curl
need gh
need jq

jq -e '
  (.manifests | type == "array" and length > 0) and
  all(.manifests[];
    (.name | type == "string" and test("^[A-Za-z0-9_.-]+$")) and
    (.repo | type == "string" and test("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")) and
    (.asset_pattern | type == "string" and length > 0) and
    (.target | type == "string" and test("^deps/manifests/[A-Za-z0-9_.-]+\\.json$"))
  )
' "${config}" >/dev/null

rm -rf "${dist_dir}"
mkdir -p "${dist_dir}"

jq -c '.manifests[]' "${config}" | while IFS= read -r manifest; do
  name="$(jq -r '.name' <<< "${manifest}")"
  repo="$(jq -r '.repo' <<< "${manifest}")"
  pattern="$(jq -r '.asset_pattern' <<< "${manifest}")"
  target="$(jq -r '.target' <<< "${manifest}")"

  case "${target}" in
    deps/manifests/*.json) ;;
    *)
      echo "invalid target path for ${name}: ${target}" >&2
      exit 1
      ;;
  esac

  echo "fetching ${name} from ${repo}"
  release="$(gh api "repos/${repo}/releases/latest")"
  match_count="$(jq --arg pattern "${pattern}" '[.assets[] | select(.name | test($pattern))] | length' <<< "${release}")"
  if [ "${match_count}" -ne 1 ]; then
    tag="$(jq -r '.tag_name // .name // "<unknown>"' <<< "${release}")"
    assets="$(jq -r '[.assets[].name] | join(", ")' <<< "${release}")"
    echo "expected exactly one asset for ${name} in ${tag}, found ${match_count} matching ${pattern}; assets: ${assets}" >&2
    exit 1
  fi

  asset_name="$(jq -r --arg pattern "${pattern}" '.assets[] | select(.name | test($pattern)) | .name' <<< "${release}")"
  download_url="$(jq -r --arg pattern "${pattern}" '.assets[] | select(.name | test($pattern)) | .browser_download_url' <<< "${release}")"
  output="${dist_dir}/${target}"
  tmp="${output}.tmp"

  mkdir -p "$(dirname "${output}")"
  curl -fsSL "${download_url}" -o "${tmp}"
  expected_key="${name%%_*}"
  jq -e --arg expected_key "${expected_key}" 'type == "object" and has($expected_key)' "${tmp}" >/dev/null
  mv "${tmp}" "${output}"
  echo "wrote ${output#"${root}/"} from ${asset_name}"
done
