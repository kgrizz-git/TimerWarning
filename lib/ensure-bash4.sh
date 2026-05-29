#!/bin/bash

###############################################################################
# ensure-bash4.sh — Use bash 4+ on macOS (system /bin/bash is 3.2)
#
# macOS requires bash 4+ for associative arrays, namerefs (local -n), etc.
# Homebrew bash: /opt/homebrew/bin/bash (Apple Silicon) or /usr/local/bin/bash.
#
# Functions:
#   resolve_bash4_path          — print path to bash 4+ (empty if none)
#   ensure_bash4_reexec         — re-exec caller script with bash 4+ if needed
#   bash4_required_message      — install hint for stderr
###############################################################################

if [ -z "${ENSURE_BASH4_LOADED:-}" ]; then
    ENSURE_BASH4_LOADED=1

    bash4_required_message() {
        cat <<'EOF' >&2
Error: bash 4 or newer is required on macOS (system /bin/bash is 3.2).

Install Homebrew bash, then re-run this command:
  brew install bash

After install, either:
  - Open a new terminal and run the script again, or
  - Run: /opt/homebrew/bin/bash ./install.sh   (Apple Silicon)
  - Run: /usr/local/bin/bash ./install.sh      (Intel)
EOF
    }

    # Print absolute path to a bash 4+ binary for LaunchAgent / tooling.
    resolve_bash4_path() {
        if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ] 2>/dev/null; then
            if [ -n "${BASH:-}" ] && [ -x "${BASH}" ]; then
                echo "${BASH}"
            else
                command -v bash 2>/dev/null || echo "/bin/bash"
            fi
            return 0
        fi
        local candidate ver
        for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
            if [ -x "${candidate}" ]; then
                ver="$("${candidate}" -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null || echo 0)"
                if [ "${ver}" -ge 4 ] 2>/dev/null; then
                    echo "${candidate}"
                    return 0
                fi
            fi
        done
        return 1
    }

    # Re-exec the given script with bash 4+ when on Darwin with old bash.
    # Usage (from entry script): ensure_bash4_reexec "${BASH_SOURCE[0]}" "$@"
    #
    # Note: ./script.sh uses the shebang (/bin/bash 3.2) even when `command -v bash`
    # points at Homebrew bash in PATH. Always exec when the *running* shell is < 4.
    ensure_bash4_reexec() {
        local script_path="$1"
        shift

        if [ "$(uname -s 2>/dev/null)" != "Darwin" ]; then
            return 0
        fi
        if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ] 2>/dev/null; then
            return 0
        fi

        local bash4="" candidate ver
        for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
            if [ -x "${candidate}" ]; then
                ver="$("${candidate}" -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null || echo 0)"
                if [ "${ver}" -ge 4 ] 2>/dev/null; then
                    bash4="${candidate}"
                    break
                fi
            fi
        done

        if [ -n "${bash4}" ]; then
            exec "${bash4}" "${script_path}" "$@"
        fi

        bash4_required_message
        exit 1
    }
fi
