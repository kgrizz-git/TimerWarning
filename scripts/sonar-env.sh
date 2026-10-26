#!/usr/bin/env bash
# Load local SonarQube settings. Source this file; do not execute it.
#
# An exported SONAR_TOKEN or SONAR_HOST_URL wins. Otherwise the value is read
# from repo-root .env. The file is parsed, never sourced, and the token is
# never printed. A leading "export " and a trailing " # comment" are accepted.
# Host defaults to http://localhost:9000. .env should be mode 0600.

sonar_env_unquote() {
    local value="$1"
    if [[ "${value}" == \"* ]]; then
        value="${value#\"}"
        value="${value%%\"*}"
    elif [[ "${value}" == \'* ]]; then
        value="${value#\'}"
        value="${value%%\'*}"
    else
        value="${value%%[[:space:]]#*}"
        value="${value%"${value##*[![:space:]]}"}"
    fi
    printf '%s' "${value}"
}

sonar_env_mode() {
    # GNU stat uses -c. BSD stat uses -f. Try GNU first: on Linux, stat -f
    # is a filesystem query and can succeed with output that is not a mode.
    local env_file="$1" perm
    if perm="$(stat -c '%a' "${env_file}" 2>/dev/null)"; then
        printf '%s' "${perm}"
        return 0
    fi
    if perm="$(stat -f '%OLp' "${env_file}" 2>/dev/null)"; then
        printf '%s' "${perm}"
        return 0
    fi
    return 1
}

sonar_env_warn_mode() {
    local env_file="$1" perm extra
    perm="$(sonar_env_mode "${env_file}" || true)"
    perm="${perm//[^0-7]/}"
    [[ "${perm}" =~ ^[0-7]+$ ]] || return 0
    extra=$((8#${perm} & 077))
    if (( extra != 0 )); then
        echo "warning: ${env_file} is readable by group or other (mode ${perm}). Run: chmod 600 ${env_file}" >&2
    fi
}

sonar_env_load() {
    local root="$1" env_file line key value
    env_file="${root}/.env"
    if [[ -f "${env_file}" ]]; then
        sonar_env_warn_mode "${env_file}"
        while IFS= read -r line || [[ -n "${line}" ]]; do
            line="${line%$'\r'}"
            [[ -z "${line}" || "${line}" == \#* || "${line}" != *=* ]] && continue
            key="${line%%=*}"
            value="${line#*=}"
            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"
            if [[ "${key}" == export\ * ]]; then
                key="${key#export }"
                key="${key#"${key%%[![:space:]]*}"}"
                key="${key%"${key##*[![:space:]]}"}"
            fi
            value="${value#"${value%%[![:space:]]*}"}"
            value="$(sonar_env_unquote "${value}")"
            case "${key}" in
                SONAR_TOKEN)
                    if [[ -n "${SONAR_TOKEN:-}" ]]; then
                        SONAR_TOKEN_SOURCE="${SONAR_TOKEN_SOURCE:-export}"
                    elif [[ -n "${value}" ]]; then
                        SONAR_TOKEN="${value}"
                        SONAR_TOKEN_SOURCE="dotenv"
                        export SONAR_TOKEN
                    fi
                    ;;
                SONAR_HOST_URL)
                    if [[ -z "${SONAR_HOST_URL:-}" && -n "${value}" ]]; then
                        SONAR_HOST_URL="${value}"
                        export SONAR_HOST_URL
                    fi
                    ;;
                *)
                    ;;
            esac
        done < "${env_file}"
    fi
    if [[ -z "${SONAR_HOST_URL:-}" ]]; then
        SONAR_HOST_URL="http://localhost:9000"
        export SONAR_HOST_URL
    fi
    if [[ -n "${SONAR_TOKEN:-}" && -z "${SONAR_TOKEN_SOURCE:-}" ]]; then
        SONAR_TOKEN_SOURCE="export"
    fi
}
