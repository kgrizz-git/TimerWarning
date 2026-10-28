# shellcheck shell=bash
# Sourced through BASH_ENV by scripts/check-shell-coverage.sh.
# Traces each bash 4.1+ process to its own log. xtrace goes to that log, not stderr.
if [[ -z "${SHELL_COVERAGE_DIR:-}" ]]; then
    return 0
fi
if [[ "${SHELL_COVERAGE_OFF:-}" == "1" ]]; then
    return 0
fi
if [[ "${_SHELL_COV_ON:-}" == "$$" ]]; then
    return 0
fi
# exec {fd} needs bash 4.1. Older bash runs the script with no trace.
if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 || ( "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -lt 1 ) ]]; then
    return 0
fi
_SHELL_COV_ON=$$
# Absolute paths: tests mask PATH to a stub directory before starting bash.
if ! /bin/mkdir -p "${SHELL_COVERAGE_DIR}"; then
    echo "shell-coverage-env: cannot create ${SHELL_COVERAGE_DIR}" >&2
    exit 70
fi
# Write the trace to a pipe. A direct log file shares the shell's ulimit -f,
# and tests that lower that limit (the icon help probe) then die on the trace.
_cov_log="${SHELL_COVERAGE_DIR}/$$.log"
coproc _SHELL_COV_READER {
    echo "${BASHPID}" >> "${SHELL_COVERAGE_DIR}/readers.pids"
    exec /bin/cat >> "${_cov_log}"
}
if [[ -z "${_SHELL_COV_READER[1]:-}" ]]; then
    echo "shell-coverage-env: could not start the trace reader" >&2
    exit 70
fi
_cov_write_fd="${_SHELL_COV_READER[1]}"
exec {_SHELL_COV_FD}>&"${_cov_write_fd}"
exec {_cov_write_fd}>&-
# Close the trace fd in child processes so the reader sees EOF when this shell exits.
# No per-process CLOEXEC helper, deliberately. fcntl(F_SETFD) in a child can
# only change that child's copy of a descriptor, never the parent shell's, so
# a python helper could not stop direct children from inheriting the trace fd
# on any platform — and where children cannot inherit it at all the call just
# fails. Just as important: resolving and running a python here once
# re-sourced this file through a pyenv shim and forked without bound
# (observed: ~1,850 processes). Trace fds stay inheritable; coproc readers
# exit when their shells and short-lived children exit, and
# check-shell-coverage.sh bounds the reader wait. Nothing below spawns a
# bash script, so re-sourcing cannot recur.
# Do not export this. A child bash opens its own descriptor.
BASH_XTRACEFD="${_SHELL_COV_FD}"
# [0] plus a default: set -u treats an unindexed BASH_SOURCE as unbound in PS4.
export PS4='+${BASH_SOURCE[0]-unknown}:${LINENO}:'
set -x
