#!/bin/bash

###############################################################################
# Sleep Warning System - Safety invariant identifiers
#
# Stable IDs for configure-time hard blocks and runtime safety logs.
# User-facing contract: docs/SAFETY.md (end-user); catalog: dev-docs/development/invariants.md
#
# Functions:
#   safety_invariant_id_for_category  - map daily-caps category → invariant id
#   safety_invariant_doc_link         - relative SAFETY.md path + anchor for an id
#   safety_invariant_tag              - "[ID] one-line summary"
#   safety_invariant_footer           - blank line + tag + doc link (dialogs/logs)
#
# Usage:
#   source lib/safety-invariants.sh
###############################################################################

if [ -z "${SAFETY_INVARIANTS_LOADED:-}" ]; then
    SAFETY_INVARIANTS_LOADED=1

    readonly SAFETY_DOC_REL="docs/SAFETY.md"
    readonly SAFETY_ANCHOR_PER_DAY="#the-per-day-16-hour-cap-the-central-invariant"
    readonly SAFETY_ANCHOR_POPUP="#popup-lifetime-the-second-invariant"
    readonly SAFETY_ANCHOR_PARTIAL_LOCK="#partial-configure-during-lock-hours-tighten-only"

    readonly INV_CAP_RESTRICTION_DAY="CAP-RESTRICTION-DAY"
    readonly INV_CAP_CONFIGURE_BLOCK_DAY="CAP-CONFIGURE-BLOCK-DAY"
    readonly INV_CAP_UNINSTALL_BLOCK_DAY="CAP-UNINSTALL-BLOCK-DAY"
    readonly INV_CAP_WEEKLY_247="CAP-WEEKLY-247"
    readonly INV_PARTIAL_LOCK_TIGHTEN="PARTIAL-LOCK-TIGHTEN"
    readonly INV_POPUP_TIMING_MIN_DISPLAY="POPUP-TIMING-MIN-DISPLAY"
    readonly INV_POPUP_WATCHDOG="POPUP-WATCHDOG"

    safety_invariant_id_for_category() {
        local category="$1"
        case "${category}" in
            restriction)     echo "${INV_CAP_RESTRICTION_DAY}" ;;
            configure_block) echo "${INV_CAP_CONFIGURE_BLOCK_DAY}" ;;
            uninstall_block) echo "${INV_CAP_UNINSTALL_BLOCK_DAY}" ;;
            *)               echo "CAP-PER-DAY-CATEGORY" ;;
        esac
    }

    safety_invariant_doc_link() {
        local invariant_id="$1"
        local anchor="${SAFETY_ANCHOR_PER_DAY}"
        case "${invariant_id}" in
            "${INV_POPUP_TIMING_MIN_DISPLAY}"|"${INV_POPUP_WATCHDOG}")
                anchor="${SAFETY_ANCHOR_POPUP}"
                ;;
            "${INV_PARTIAL_LOCK_TIGHTEN}")
                anchor="${SAFETY_ANCHOR_PARTIAL_LOCK}"
                ;;
        esac
        echo "${SAFETY_DOC_REL}${anchor}"
    }

    safety_invariant_summary() {
        local invariant_id="$1"
        case "${invariant_id}" in
            "${INV_CAP_RESTRICTION_DAY}")
                echo "Restriction hours exceed 16 h on at least one calendar day."
                ;;
            "${INV_CAP_CONFIGURE_BLOCK_DAY}")
                echo "Configure-block hours exceed 16 h on at least one calendar day."
                ;;
            "${INV_CAP_UNINSTALL_BLOCK_DAY}")
                echo "Uninstall-block hours exceed 16 h on at least one calendar day."
                ;;
            "${INV_CAP_WEEKLY_247}")
                echo "Merged hours would lock you out 24/7; save blocked."
                ;;
            "${INV_PARTIAL_LOCK_TIGHTEN}")
                echo "Change loosens restrictions during lock hours; save blocked."
                ;;
            "${INV_POPUP_TIMING_MIN_DISPLAY}")
                echo "Minimum display time exceeds popup frequency; popups would stack."
                ;;
            "${INV_POPUP_WATCHDOG}")
                echo "Popup exceeded absolute lifetime cap; terminated by watchdog."
                ;;
            *)
                echo "Safety invariant violated; see SAFETY.md."
                ;;
        esac
    }

    safety_invariant_tag() {
        local invariant_id="$1"
        printf '[%s] %s' "${invariant_id}" "$(safety_invariant_summary "${invariant_id}")"
    }

    safety_invariant_footer() {
        local invariant_id="$1"
        printf '\n%s\n%s\n' \
            "$(safety_invariant_tag "${invariant_id}")" \
            "$(safety_invariant_doc_link "${invariant_id}")"
    }

fi
