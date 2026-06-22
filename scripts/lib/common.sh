#!/usr/bin/env bash
# Shared helpers for FlatPark publish tooling.
set -euo pipefail
log()  { printf '[flatpark] %s\n' "$*" >&2; }
warn() { printf '[flatpark] WARN: %s\n' "$*" >&2; }
die()  { printf '[flatpark] ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }
load_config() {
    ROOT="$1"
    local conf="${FLATPARK_CONF:-$ROOT/config/flatpark.conf}"
    if [ "${_FLATPARK_CONFIG_LOADED:-0}" = "1" ]; then
        [ "${REPO_FILE_URL-}" = "${_FLATPARK_REPO_FILE_URL_DEFAULT-}" ] && unset REPO_FILE_URL
        [ "${REPO_DIR-}" = "${_FLATPARK_REPO_DIR_DEFAULT-}" ] && unset REPO_DIR
        [ "${PAGES_DIR-}" = "${_FLATPARK_PAGES_DIR_DEFAULT-}" ] && unset PAGES_DIR
        [ "${PUBKEY_FILE-}" = "${_FLATPARK_PUBKEY_FILE_DEFAULT-}" ] && unset PUBKEY_FILE
    fi
    [ -f "$conf" ] || die "missing config: $conf"
    # shellcheck disable=SC1090
    . "$conf"
    _FLATPARK_CONFIG_LOADED=1
    _FLATPARK_REPO_FILE_URL_DEFAULT="${REPO_URL%/}/flatpark.flatpakrepo"
    _FLATPARK_REPO_DIR_DEFAULT="$OUT_DIR/repo"
    _FLATPARK_PAGES_DIR_DEFAULT="$OUT_DIR/site"
    _FLATPARK_PUBKEY_FILE_DEFAULT="$OUT_DIR/flatpark.pub.asc"
    local var
    for var in ROOT REPO_TITLE REPO_HOMEPAGE REPO_COMMENT REPO_URL REPO_FILE_URL \
        RUNTIME_REPO_URL REMOTE_NAME RUNTIME_REMOTE_NAME VERIFY_REMOTE_NAME \
        REGISTRY_DIR PACKAGING_REPO_URL PACKAGING_BRANCH \
        GNUPGHOME_DIR KEY_NAME KEY_EMAIL OUT_DIR REPO_DIR PAGES_DIR PUBKEY_FILE \
        ; do
        declare -g "$var=${!var}"
    done
    declare -g "_FLATPARK_CONFIG_LOADED=$_FLATPARK_CONFIG_LOADED"
    declare -g "_FLATPARK_REPO_FILE_URL_DEFAULT=$_FLATPARK_REPO_FILE_URL_DEFAULT"
    declare -g "_FLATPARK_REPO_DIR_DEFAULT=$_FLATPARK_REPO_DIR_DEFAULT"
    declare -g "_FLATPARK_PAGES_DIR_DEFAULT=$_FLATPARK_PAGES_DIR_DEFAULT"
    declare -g "_FLATPARK_PUBKEY_FILE_DEFAULT=$_FLATPARK_PUBKEY_FILE_DEFAULT"
}

app_record_path() {
    local app_id="$1"
    printf '%s/%s/flatpark.yml\n' "$REGISTRY_DIR" "$app_id"
}

load_app() {
    local app_id="${1:?load_app: app id required}"
    local record app_dir
    record="$(app_record_path "$app_id")"
    [ -f "$record" ] || die "missing app registry entry: $record"
    app_dir="$(dirname "$record")"

    if [ "${_FLATPARK_APP_OVERRIDE_STATE_READY:-0}" != "1" ]; then
        local override_var override_marker override_value
        local overridable_vars=(APP_SRC MANIFEST UPDATE_MODE APP_REF_URL APP_ICON APP_CATEGORY APP_TAGS APP_SOURCE_URL APP_WEBSITE)
        for override_var in "${overridable_vars[@]}"; do
            override_marker="_FLATPARK_${override_var}_HAS_OVERRIDE"
            override_value="_FLATPARK_${override_var}_OVERRIDE_VALUE"
            if declare -p "$override_var" >/dev/null 2>&1; then
                declare -g "$override_marker=1"
                declare -g "$override_value=${!override_var}"
            else
                declare -g "$override_marker=0"
                declare -g "$override_value="
            fi
        done
        declare -g "_FLATPARK_APP_OVERRIDE_STATE_READY=1"
    fi

    unset APP_ID APP_NAME APP_SUMMARY APP_BRANCH APP_SRC MANIFEST UPDATE_MODE APP_REF_URL \
        APP_ICON APP_CATEGORY APP_TAGS APP_SOURCE_URL APP_WEBSITE
    local override_var override_marker override_value has_override
    local overridable_vars=(APP_SRC MANIFEST UPDATE_MODE APP_REF_URL APP_ICON APP_CATEGORY APP_TAGS APP_SOURCE_URL APP_WEBSITE)
    for override_var in "${overridable_vars[@]}"; do
        override_marker="_FLATPARK_${override_var}_HAS_OVERRIDE"
        override_value="_FLATPARK_${override_var}_OVERRIDE_VALUE"
        has_override="${!override_marker:-0}"
        if [ "$has_override" = "1" ]; then
            declare -g "$override_var=${!override_value}"
        fi
    done

    need node
    local desc
    desc="$(node "$ROOT/scripts/read-descriptor.mjs" "$record")" \
        || die "failed to read descriptor: $record"
    local _FP_ID _FP_NAME _FP_SUMMARY _FP_BRANCH _FP_MANIFEST _FP_MODE \
          _FP_CATEGORY _FP_TAGS _FP_WEBSITE _FP_SOURCE_URL _FP_UPDATE_COMMAND
    # shellcheck disable=SC1090
    eval "$desc"

    APP_ID="$_FP_ID"
    APP_NAME="$_FP_NAME"
    APP_SUMMARY="$_FP_SUMMARY"
    [ "$APP_ID" = "$app_id" ] || die "registry id mismatch: wanted $app_id got $APP_ID"

    # Defaults compose the descriptor values; any explicit env override (captured
    # above) already won and is left untouched by these `:=` assignments.
    : "${APP_SRC:=$app_dir}"
    : "${MANIFEST:=$APP_SRC/$_FP_MANIFEST}"
    : "${APP_BRANCH:=${_FP_BRANCH:-stable}}"
    : "${UPDATE_MODE:=${_FP_MODE:-manual}}"
    : "${APP_CATEGORY:=${_FP_CATEGORY:-Apps}}"
    : "${APP_TAGS:=$_FP_TAGS}"
    : "${APP_WEBSITE:=$_FP_WEBSITE}"
    : "${APP_SOURCE_URL:=$_FP_SOURCE_URL}"
    : "${APP_REF_URL:=${REPO_URL%/}/$APP_ID.flatpakref}"
    : "${APP_ICON:=}"
    APP_UPDATE_COMMAND="$_FP_UPDATE_COMMAND"

    local var
    for var in APP_ID APP_NAME APP_SUMMARY APP_BRANCH APP_SRC MANIFEST APP_REF_URL UPDATE_MODE; do
        [ -n "${!var-}" ] || die "app registry entry $record did not set $var"
        declare -g "$var=${!var}"
    done
    for var in APP_CATEGORY APP_TAGS APP_ICON APP_SOURCE_URL APP_WEBSITE APP_UPDATE_COMMAND; do
        declare -g "$var=${!var}"
    done
    unset _FP_ID _FP_NAME _FP_SUMMARY _FP_BRANCH _FP_MANIFEST _FP_MODE \
          _FP_CATEGORY _FP_TAGS _FP_WEBSITE _FP_SOURCE_URL _FP_UPDATE_COMMAND
}
