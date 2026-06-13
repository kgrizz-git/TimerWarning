#!/bin/bash

###############################################################################
# Sleep Warning System - Feature Toggle Input Collection Module (facade)
#
# Public getters for feature toggles and security settings in the configure
# wizard. Implementation is split across submodules; this file sources them
# so configure.sh and tests keep a single stable entry point.
#
# Functions (re-exported from submodules):
# - get_configure_block_enabled_config()
# - get_security_settings_config()
# - get_config_lock_enabled_config()
# - get_pause_enabled_config()
# - get_pause_duration_config()
# - get_pause_cooldown_hours_config()
# - get_uninstall_protection_mode_config()
# - get_dialog_tool_selection()
#
# Dependencies:
# - configure-core.sh, configure-dialogs.sh, configure-ui.sh (sourced before this file)
###############################################################################

_CONFIGURE_INPUT_FEATURES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090
source "${_CONFIGURE_INPUT_FEATURES_DIR}/configure-input-feature-helpers.sh"
# shellcheck disable=SC1090
source "${_CONFIGURE_INPUT_FEATURES_DIR}/configure-input-security.sh"
# shellcheck disable=SC1090
source "${_CONFIGURE_INPUT_FEATURES_DIR}/configure-input-pause.sh"
# shellcheck disable=SC1090
source "${_CONFIGURE_INPUT_FEATURES_DIR}/configure-input-dialog-tool.sh"
# shellcheck disable=SC1090
source "${_CONFIGURE_INPUT_FEATURES_DIR}/config-keys.sh"

unset _CONFIGURE_INPUT_FEATURES_DIR
