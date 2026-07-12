#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"

: "${SITE_DIR:=$ROOT/site}"
: "${DATA_DIR:=$SITE_DIR/public}"
: "${CATALOG_FILE:=$DATA_DIR/catalog.json}"
: "${APPS_DATA_DIR:=$DATA_DIR/apps}"
: "${ICONS_DIR:=$DATA_DIR/icons}"

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\n'/\\n}"
    printf '%s' "$s"
}

asset_name() {
    printf '%s' "$1" | tr -cs 'A-Za-z0-9._-' '-'
}

icon_url_for_app() {
    local icon="$APP_ICON"
    if [ -z "$icon" ] && [ -f "$APP_SRC/$APP_ID.svg" ]; then
        icon="$APP_SRC/$APP_ID.svg"
    fi
    if [ -z "$icon" ] && [ -f "$APP_SRC/$APP_ID.png" ]; then
        icon="$APP_SRC/$APP_ID.png"
    fi
    if [ -n "$icon" ] && [ -f "$icon" ]; then
        local ext="${icon##*.}" name
        name="$(asset_name "$APP_ID").$ext"
        cp "$icon" "$ICONS_DIR/$name"
        printf '/icons/%s' "$name"
    fi
}

tags_json() {
    local raw t out=""
    IFS=',' read -ra raw <<< "$APP_TAGS"
    for t in "${raw[@]}"; do
        t="${t#"${t%%[![:space:]]*}"}"
        t="${t%"${t##*[![:space:]]}"}"
        [ -n "$t" ] || continue
        out="$out${out:+, }\"$(json_escape "$t")\""
    done
    printf '[%s]' "$out"
}

requested_apps=("$@")
apps=()
while IFS= read -r app_id; do
    apps+=("$app_id")
done < <("$ROOT/scripts/scan-registry.sh" --ids "${requested_apps[@]}")
[ "${#apps[@]}" -gt 0 ] || die "registry scan returned no apps"

mkdir -p "$(dirname "$CATALOG_FILE")" "$APPS_DATA_DIR" "$ICONS_DIR"
# A fresh per-app set each run so removed apps do not linger.
rm -f "$APPS_DATA_DIR"/*.json 2>/dev/null || true

remote_cmd="flatpak --user remote-add --if-not-exists $REMOTE_NAME $REPO_FILE_URL"

# --- light catalog.json (drives the index grid + client-side search) ---
{
    printf '{\n'
    printf '  "repo": {\n'
    printf '    "title": "%s",\n' "$(json_escape "$REPO_TITLE")"
    printf '    "comment": "%s",\n' "$(json_escape "$REPO_COMMENT")"
    printf '    "homepage": "%s",\n' "$(json_escape "$REPO_HOMEPAGE")"
    printf '    "remoteName": "%s",\n' "$(json_escape "$REMOTE_NAME")"
    printf '    "remoteUrl": "%s",\n' "$(json_escape "$REPO_URL")"
    printf '    "repoFileUrl": "%s",\n' "$(json_escape "$REPO_FILE_URL")"
    printf '    "runtimeRemoteName": "%s",\n' "$(json_escape "$RUNTIME_REMOTE_NAME")"
    printf '    "runtimeRepoUrl": "%s",\n' "$(json_escape "$RUNTIME_REPO_URL")"
    printf '    "remoteCmd": "%s"\n' "$(json_escape "$remote_cmd")"
    printf '  },\n'
    printf '  "apps": [\n'
    first=1
    for app_id in "${apps[@]}"; do
        load_app "$app_id"
        icon="$(icon_url_for_app)"
        [ "$first" = "1" ] || printf ',\n'
        first=0
        printf '    {\n'
        printf '      "id": "%s",\n' "$(json_escape "$APP_ID")"
        printf '      "name": "%s",\n' "$(json_escape "$APP_NAME")"
        printf '      "summary": "%s",\n' "$(json_escape "$APP_SUMMARY")"
        printf '      "category": "%s",\n' "$(json_escape "$APP_CATEGORY")"
        printf '      "tags": %s,\n' "$(tags_json)"
        printf '      "updateMode": "%s",\n' "$(json_escape "$UPDATE_MODE")"
        # Public upstream link; the release-hook Worker uses it to verify that
        # an "app X released tag Y" ping names the repo we actually track.
        printf '      "sourceUrl": "%s",\n' "$(json_escape "$APP_SOURCE_URL")"
        if [ -n "$icon" ]; then
            printf '      "icon": "%s"\n' "$(json_escape "$icon")"
        else
            printf '      "icon": null\n'
        fi
        printf '    }'
    done
    printf '\n  ]\n'
    printf '}\n'
} > "$CATALOG_FILE"

# --- base per-app apps/<id>.json (enrichment fills the rest) ---
for app_id in "${apps[@]}"; do
    load_app "$app_id"
    icon="$(icon_url_for_app)"
    # No --user: flatpak routes to whichever single remote the user configured
    # (system or user). Forcing --user would break a system-only setup. The
    # /setup page still teaches the explicit per-user vs system commands.
    install_cmd="flatpak install $REMOTE_NAME $APP_ID"
    packaging_url="${PACKAGING_REPO_URL%/}/tree/$PACKAGING_BRANCH/registry/$APP_ID"
    {
        printf '{\n'
        printf '  "id": "%s",\n' "$(json_escape "$APP_ID")"
        printf '  "name": "%s",\n' "$(json_escape "$APP_NAME")"
        printf '  "summary": "%s",\n' "$(json_escape "$APP_SUMMARY")"
        printf '  "branch": "%s",\n' "$(json_escape "$APP_BRANCH")"
        printf '  "category": "%s",\n' "$(json_escape "$APP_CATEGORY")"
        printf '  "tags": %s,\n' "$(tags_json)"
        printf '  "updateMode": "%s",\n' "$(json_escape "$UPDATE_MODE")"
        if [ -n "$icon" ]; then
            printf '  "icon": "%s",\n' "$(json_escape "$icon")"
        else
            printf '  "icon": null,\n'
        fi
        printf '  "refUrl": "%s",\n' "$(json_escape "$APP_REF_URL")"
        printf '  "installCmd": "%s",\n' "$(json_escape "$install_cmd")"
        printf '  "remoteCmd": "%s",\n' "$(json_escape "$remote_cmd")"
        printf '  "website": "%s",\n' "$(json_escape "$APP_WEBSITE")"
        printf '  "sourceUrl": "%s",\n' "$(json_escape "$APP_SOURCE_URL")"
        printf '  "packagingUrl": "%s",\n' "$(json_escape "$packaging_url")"
        printf '  "_srcDir": "%s",\n' "$(json_escape "$APP_SRC")"
        printf '  "_manifest": "%s"\n' "$(json_escape "$MANIFEST")"
        printf '}\n'
    } > "$APPS_DATA_DIR/$APP_ID.json"
done

log "wrote $CATALOG_FILE + ${#apps[@]} app file(s) -> $APPS_DATA_DIR"
