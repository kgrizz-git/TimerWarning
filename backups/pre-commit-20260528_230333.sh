#!/bin/sh
#
# Pre-commit: prune old tracked files in backups/ (see scripts/prune-backups.sh).
# Enable once per clone: ./scripts/install-git-hooks.sh
#

set -e

ROOT="$(git rev-parse --show-toplevel)"
exec "${ROOT}/scripts/prune-backups.sh"
