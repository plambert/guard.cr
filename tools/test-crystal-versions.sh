#!/usr/bin/env bash

# use podman to get a list of crystallang/crystal docker image versions, and then
# work backwards to find the earliest which passes the spec tests

set -e -o pipefail

DEFAULT_CACHE_TIME=3600
IMAGE_NAME="docker.io/crystallang/crystal"
MINIMUM_VERSION="${MINIMUM_VERSION:-1.0.0}"
REPO_MOUNT=/repo
PARALLEL_TEST_COUNT_DARWIN=2
PARALLEL_TEST_COUNT_LINUX=4

main() {
  local version last_version
  declare -g basedir toolsdir cachedir
  declare -g parallel_test_count="${PARALLEL_TEST_COUNT_LINUX}"
  declare -g -a available_versions=()
  declare -g -A user_for_version

  check_bash_version

  basedir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
  toolsdir="${basedir}/tools"
  cachedir="${basedir}/.cache"
  toolname="$(basename -- "${BASH_SOURCE[0]}")"

  if [[ "$OSTYPE" == darwin* ]]; then
    parallel_test_count="${PARALLEL_TEST_COUNT_DARWIN}"
  fi

  parse_options "$@"

  if [[ -d "/opt/podman/bin" ]] && [[ ":$PATH:" != *":/opt/podman/bin:"* ]]; then
    export PATH="${PATH}:/opt/podman/bin"
  fi

  if ! command -v podman > /dev/null 2>&1; then
    echo 1>&2 "$0: could not find podman command, make sure it's in your PATH"
    exit 1
  fi

  mkdir -p "$cachedir"

  fetch_crystal_versions available_versions

  INFO '%d available versions of crystal' "${#available_versions[*]}"

  read_cached_user_for_version

  if [[ ! -n "$NO_PULL" ]]; then
    INFO 'pulling images in parallel'
    pull_images "${available_versions[@]}"
  fi

  if [[ -n "$TEST_PARALLEL" ]]; then
    test_in_parallel last_version "${available_versions[@]}"
  else
    test_sequentially last_version "${available_versions[@]}"
  fi

  echo "$last_version"

  INFO 'latest version to pass: %s' "$last_version"

  write_cached_user_for_version
}

parse_options() {
  local opt
  while [[ $# -gt 0 ]]; do
    opt="$1"
    shift
    case "$opt" in
      --run-spec)
        run_spec "$@"
        exit "$?"
        ;;
      --container-test)
        container_test "$@"
        exit "$?"
        ;;
      *)
        FAIL '%s: unknown option' "$opt"
        ;;
    esac
  done
}

test_sequentially() {
  local _var="$1" version
  shift

  if ! test_version "$1"; then
    FAIL 'latest version (%s) did not pass' "$1"
  fi
  printf -v "$_var" %s "$1"
  shift

  for version in "$@"; do
    if ! test_version "$version"; then
      break
    else
      printf -v "$_var" %s "$version"
    fi
  done
}

test_in_parallel() {
  local _var="$1" _version
  shift

  local -A results

  rm -rf "${cachedir}/results" > /dev/null 2>&1 || true
  mkdir "${cachedir}/results"

  parallel --line-buffer -j "$parallel_test_count" -n 1 "${BASH_SOURCE[0]}" --container-test ::: "$@"

  for _version in "$@"; do
    if [[ -f "${cachedir}/results/v${version}.rc" ]]; then
      read -r "results[${version}]" < "${cachedir}/results/v${version}.rc"
      # results["$version"]="$(< "${cachedir}/results/v${version}.rc")"
    fi
  done

  for _version in "$@"; do
    [[ "${results[${_version}]}" -ne 0 ]] && break
    printf -v "$_var" %s "$_version"
  done
}

test_version() {
  local ver="$1" rc user=ubuntu
  local image="${IMAGE_NAME}:${ver}"

  run_container "$image"
  rc=$?

  INFO 'returned code %d' "$rc"

  return "$rc"
}

run_container() {
  local image="$1"
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

}

run_spec() {
  cd "$REPO_MOUNT"
  crystal spec --fail-fast --order random -v --time
}

container_test() {
  local version="$1"
  mkdir -p "${cachedir}/results"

  INFO 'starting test of version %s' "$version"
  run_container "${IMAGE_NAME}:${version}"
  rc=$?

  echo "$rc" > "${cachedir}/results/v${version}.rc"
}

pull_images() {
  local ver images=()
  for ver; do
    images+=("${IMAGE_NAME}:${ver}")
  done
  parallel --line-buffer -j "$parallel_test_count" -n 1 podman pull -q ::: "${images[@]}"
  # podman
}

fetch_crystal_versions() {
  local _var="$1" file

  set_cache_filename file crystal_versions

  if ! is_cached crystal_versions; then
    INFO 'fetching list of crystal versions'

    crystal run "${toolsdir}/find-latest-crystal-versions.cr" -- --latest "--${MINIMUM_VERSION}" > "$file"
  fi

  mapfile -t "$_var" < <(reverse_lines "$file")
}

read_cached_user_for_version() {
  local _ver _user
  if [[ -f "${cachedir}/container-user.cache" ]]; then
    while IFS='=' read -r _ver _user; do
      printf -v "user_for_version[${_ver}]" %s "$_user"
    done < "${cachedir}/container-user.cache"
  fi
}

write_cached_user_for_version() {
  local cachefile="container-user.cache"
  local tmpfile=".${cachefile}"
  if ! dump_user_for_version > "${cachedir}/${tmpfile}"; then
    INFO 'could not write container user cache'
  else
    /bin/mv -f "${cachedir}/${tmpfile}" "${cachedir}/${cachefile}" > /dev/null 2>&1
  fi
}

dump_user_for_version() {
  local _ver
  for _ver in "${!user_for_version[@]}"; do
    printf '%s\t%s\n' "$_ver" "${user_for_version[$_ver]}"
  done
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

reverse_lines() {
  case "$OSTYPE" in
    darwin*)
      tail -r "$@"
      ;;
    *)
      tac "$@"
      ;;
  esac
}

INFO() {
  __LOG INFO "$@"
}

WARN() {
  __LOG WARN "$@"
}

FAIL() {
  __LOG ERROR "$@"
  exit 1
}

__LOG() {
  local _level="${1^^}" _fmt=%s _color
  shift
  if [[ $# -gt 1 ]]; then
    _fmt="$1"
    shift
  fi

  if [[ -t 1 ]]; then
    case "$_level" in
      ERROR)
        _color='31;1'
        ;;
      WARN)
        _color='33'
        ;;
      *)
        _color='34;1'
        ;;
    esac
    printf 1>&2 '\e[%sm[%5s]\e[0m ' "$_color" "$_level"
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

main "$@"
