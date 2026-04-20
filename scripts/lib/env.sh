#!/usr/bin/env bash

load_env_file() {
  local env_file="$1"
  local line key value

  [[ -f "$env_file" ]] || return 0
  MIR_ENV_LOADED_FILES="${MIR_ENV_LOADED_FILES:+$MIR_ENV_LOADED_FILES:}$env_file"

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* || "$line" != *=* ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    printf -v "$key" '%s' "$value"
    export "$key"
  done < "$env_file"
}

load_workspace_env() {
  local root="$1"
  local profile requested_profile

  requested_profile="${MIR_ENV_PROFILE:-}"
  MIR_ENV_LOADED_FILES=""
  load_env_file "$root/.env"

  profile="${requested_profile:-${MIR_ENV_PROFILE:-}}"
  if [[ -z "$profile" && -f "$root/.env.daic" && -d /opt/insy/modulefiles ]]; then
    profile="daic"
  fi

  if [[ -n "$profile" ]]; then
    export MIR_ENV_PROFILE="$profile"
    load_env_file "$root/.env.$profile"
  fi

  export MIR_ENV_LOADED_FILES
}
