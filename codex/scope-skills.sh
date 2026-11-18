#!/bin/sh
# Disable the kit's skill paths in Codex's user config through its local config API.
set -eu

paths=$(jq -cn --args '$ARGS.positional' "$@")
rpc_dir=$(mktemp -d "${TMPDIR:-/tmp}/herdr-kit-codex.XXXXXX")
cleanup() {
  if [ -n "${server:-}" ]; then
    kill "$server" 2>/dev/null || :
    wait "$server" 2>/dev/null || :
  fi
  rm -f "$rpc_dir/in" "$rpc_dir/out"
  rmdir "$rpc_dir"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
mkfifo "$rpc_dir/in" "$rpc_dir/out"

codex app-server --listen stdio:// <"$rpc_dir/in" >"$rpc_dir/out" &
server=$!
exec 3>"$rpc_dir/in" 4<"$rpc_dir/out"

request() {
  printf '%s\n' "$2" >&3
  while IFS= read -r reply <&4; do
    if ! printf '%s\n' "$reply" | jq -e --argjson id "$1" '.id == $id' >/dev/null; then
      continue
    fi
    if printf '%s\n' "$reply" | jq -e '.error != null' >/dev/null; then
      printf '%s\n' "$reply" | jq -r '.error.message' >&2
      return 1
    fi
    printf '%s\n' "$reply" | jq -ce '.result'
    return
  done
  echo 'Codex closed its local config connection.' >&2
  return 1
}

request 1 '{"id":1,"method":"initialize","params":{"clientInfo":{"name":"herdr-kit","version":"1"}}}' >/dev/null
printf '%s\n' '{"method":"initialized"}' >&3
config=$(request 2 '{"id":2,"method":"config/read","params":{"includeLayers":true}}')
user_layer=$(printf '%s\n' "$config" | jq -ce '
  .layers | map(select(.name.type == "user" and .name.profile == null)) | first
')

edit=$(printf '%s\n' "$user_layer" | jq -c --argjson paths "$paths" '
  (.config.skills.config // []) as $previous
  | ($previous | map(select(.path as $path | ($paths | index($path)) == null))) as $unrelated
  | ($unrelated + ($paths | map({path: ., enabled: false}))) as $rules
  | if $rules == $previous then empty
    else {id: 3, method: "config/value/write", params: {
      keyPath: "skills.config", value: $rules, mergeStrategy: "replace",
      filePath: .name.file, expectedVersion: .version
    }} end
')
if [ -n "$edit" ]; then
  request 3 "$edit" >/dev/null
fi

exec 3>&- 4<&-
wait "$server"
server=
