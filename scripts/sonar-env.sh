#!/usr/bin/env bash
# Load local SonarQube settings. Source this file; do not execute it.
#
# An exported SONAR_TOKEN or SONAR_HOST_URL wins. Otherwise the value is read
# from repo-root .env. The file is parsed, never sourced, and the token is
# never printed. Host defaults to http://localhost:9000.

sonar_env_load() {
    local root="$1" env_file line key value
    env_file="${root}/.env"
    if [[ -f "${env_file}" ]]; then
        while IFS= read -r line || [[ -n "${line}" ]]; do
            line="${line%$'\r'}"
            [[ -z "${line}" || "${line}" == \#* || "${line}" != *=* ]] && continue
            key="${line%%=*}"
            value="${line#*=}"
            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"
            if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
                value="${value#\"}"
                value="${value%\"}"
            elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
                value="${value#\'}"
                value="${value%\'}"
            fi
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
