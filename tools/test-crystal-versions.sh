#!/usr/bin/env bash

# use podman to get a list of crystallang/crystal docker image versions, and then
# work backwards to find the earliest which passes the spec tests

set -e

DEFAULT_CACHE_TIME=3600
IMAGE_NAME="docker.io/crystallang/crystal"
MINIMUM_VERSION="${MINIMUM_VERSION:-1.0.0}"
REPO_MOUNT=/repo

main() {
  local version last_version
  declare -g basedir toolsdir cachedir
  declare -g -a available_versions=()

  if ! command -v podman > /dev/null 2>&1; then
    echo 1>&2 "$0: could not find podman command, make sure it's in your PATH"
    exit 1
  fi

  check_bash_version

  set -o pipefail

  basedir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
  toolsdir="${basedir}/tools"
  cachedir="${basedir}/.cache"
  toolname="$(basename -- "${BASH_SOURCE[0]}")"

  mkdir -p "$cachedir"

  fetch_crystal_versions available_versions

  INFO '%d available versions of crystal' "${#available_versions[*]}"

  INFO 'pulling images in parallel'

  pull_images "${available_versions[@]}"

  last_version="${available_versions[0]}"
  if ! test_version "$last_version"; then
    FAIL 'latest version (%s) did not pass' "$last_version"
  fi

  for version in "${available_versions[@]:1}"; do
    if ! test_version "$version"; then
      break
    else
      last_version="$version"
    fi
  done

  echo "$last_version"

  INFO 'latest version to pass: %s' "$last_version"

  # printf '  %s\n' "${available_versions[@]}"
}

test_version() {
  local ver="$1" rc user=ubuntu
  local image="${IMAGE_NAME}:${ver}"
  local -a podman_run_options=(--arch amd64 --entrypoint /bin/bash)

  INFO 'testing %s' "$ver"

  if podman run "${podman_run_options[@]}" id "$user" > /dev/null 2>&1; then
    podman_run_options+=(--user "$user")
  fi

  podman run -i \
    "${podman_run_options[@]}" \
    --volume "$(pwd):${REPO_MOUNT}" \
    "$image" \
    "/repo/tools/${toolname}" --run-spec

  # <<< "cd /repo && crystal spec --fail-fast --order random -v"
  rc=$?

  INFO 'returned code %d' "$rc"

  return "$rc"
}

run_spec() {
  cd "$REPO_MOUNT"
  crystal spec --fail-fast --order random -v --time
}

pull_images() {
  local ver images=()
  for ver; do
    images+=("${IMAGE_NAME}:${ver}")
  done
  parallel -n 1 podman pull -q ::: "${images[@]}"
  # podman
}

fetch_crystal_versions() {
  local _var="$1" file

  set_cache_filename file crystal_versions

  if ! is_cached crystal_versions; then
    INFO 'fetching list of crystal versions'

    crystal run "${toolsdir}/find-latest-crystal-versions.cr" -- --latest "--${MINIMUM_VERSION}" > "$file"
  fi

  mapfile -t "$_var" < <(tail -r "$file")
}

set_cache_filename() {
  local _var="$1" _key="$2"
  printf -v "$_var" '%s/%s.cache' "$cachedir" "$_key"
}

is_cached() {
  local key="$1" cachetime="${2:-${DEFAULT_CACHE_TIME}}"
  [[ -f "${cachedir}/${key}.cache" ]] &&
    [[ "$(date -r "${cachedir}/${key}.cache" +%s)" -ge "$(($(date +%s) - cachetime))" ]]
}

get_tempfile() {
  local _var _file
  declare -g -a tmpfiles
  for _var; do
    _file="$(mktemp)"
    tmpfiles+=("$_file")
    printf -v "$_var" %s "$_file"
  done
  trap remove_tempfiles EXIT
}

remove_tempfiles() {
  if [[ "${#tmpfiles[*]}" -gt 0 ]]; then
    rm -f "${tmpfiles[@]}" > /dev/null 2>&1 || true
    tmpfiles=()
  fi
}

INFO() {
  __LOG INFO "$@"
}

FAIL() {
  __LOG ERROR "$@"
  exit 1
}

__LOG() {
  local _level="${1^^}" _fmt=%s
  shift
  if [[ $# -gt 1 ]]; then
    _fmt="$1"
    shift
  fi

  if [[ -t 1 ]]; then
    printf 1>&2 '\e[34;1m[%5s]\e[0m ' "$_level"
  else
    printf 1>&2 '[%5s] ' "$_level"
  fi

  # shellcheck disable=SC2059
  printf 1>&2 "${_fmt}\n" "$@"
}

verify_commands() {
  local _cmd _missing=()
  for _cmd; do
    if ! command -v "$_cmd" > /dev/null 2>&1; then
      _missing+=("$_cmd")
    fi
  done

  if [[ "${#_missing[*]}" -gt 0 ]]; then
    set -- "${_missing[@]}"
    _cmd="$1"
    shift
    while [[ $# -gt 0 ]]; do
      _cmd="${_cmd}, $1"
      shift
    done
    FAIL 'missing commands (%s), make sure they are in your PATH' "$_cmd"
  fi
}

check_bash_version() {
  if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    FAIL 'bash 4.x or higher is required, running in bash %s' "${BASH_VERSION}"
  fi
}

if [[ "$1" == --run-spec ]]; then
  shift
  run_spec
else
  main "$@"
fi
