#!/bin/bash

###############################################################################
# Sleep Warning System - Popup Size Configuration Helpers
#
# This module contains the popup-size-specific configuration getters and
# dimension calculation logic extracted from `lib/config.sh`.
#
# IMPORTANT:
# - `lib/config.sh` remains the stable public API surface; it sources this file.
# - This file intentionally assumes `CONFIG_FILE` and related defaults (e.g.
#   `DEFAULT_POPUP_SIZE`) are defined by the caller (normally `lib/config.sh`).
#
# Functions:
# - get_popup_size()
# - get_popup_dimensions(size)
# - get_popup_size_mode()
# - get_popup_size_custom()
# - get_popup_size_custom_absolute()
#
# Dependencies:
# - None directly; optionally uses `get_display_resolution` and logging functions
#   (`log_message`, `log_to_file`) when available.
###############################################################################

# Get popup size from configuration file
# This is for Enhancement #3 (Enhanced Window Size Options)
get_popup_size() {
    # Check if config file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "${DEFAULT_POPUP_SIZE}"
        return 0
    fi
    
    # Read POPUP_SIZE from config file
    local size
    size=$(grep -E "^[[:space:]]*POPUP_SIZE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    
    if [ -z "${size}" ]; then
        echo "${DEFAULT_POPUP_SIZE}"
        return 0
    fi
    
    # Validate size - support new predefined sizes (xsmall, xlarge, max) and custom format
    case "${size}" in
        xsmall|small|medium|large|xlarge|max|custom)
            echo "${size}"
            return 0
            ;;
        *)
            # Check if it's custom pixel format (WIDTHxHEIGHT) or percentage format (WIDTH%xHEIGHT%)
            if echo "${size}" | grep -qE '^[0-9]+x[0-9]+$'; then
                # Pixel format (WIDTHxHEIGHT)
                echo "${size}"
                return 0
            elif echo "${size}" | grep -qE '^[0-9]+%x[0-9]+%$'; then
                # Percentage format (WIDTH%xHEIGHT%) - validate range 15-95%
                local width_percent height_percent
                width_percent=$(echo "${size}" | cut -d'x' -f1 | tr -d '%')
                height_percent=$(echo "${size}" | cut -d'x' -f2 | tr -d '%')
                if [ "${width_percent}" -ge 15 ] && [ "${width_percent}" -le 95 ] && \
                   [ "${height_percent}" -ge 15 ] && [ "${height_percent}" -le 95 ]; then
                    echo "${size}"
                    return 0
                else
                    # Invalid percentage range, use default
                    echo "${DEFAULT_POPUP_SIZE}"
                    return 0
                fi
            else
                # Invalid, use default
                echo "${DEFAULT_POPUP_SIZE}"
                return 0
            fi
            ;;
    esac
}

clamp_popup_dimensions_to_safe_display_max() {
    local width="$1"
    local height="$2"
    local screen_width="$3"
    local screen_height="$4"

    local max_width=$((screen_width * 95 / 100))
    local max_height=$((screen_height * 95 / 100))

    if [ "${width}" -gt "${max_width}" ]; then
        width="${max_width}"
    fi
    if [ "${height}" -gt "${max_height}" ]; then
        height="${max_height}"
    fi

    echo "${width} ${height}"
}

# Convert popup size to width and height
# This is for Enhancement #3 (Enhanced Window Size Options)
# Supports:
# - Predefined sizes: xsmall, small, medium, large, xlarge, max, custom
# - Custom pixel format: WIDTHxHEIGHT
# - Custom percentage format: WIDTH%xHEIGHT%
# - Display-based mode: calculates percentages from detected resolution
get_popup_dimensions() {
    local size="$1"
    local width height
    local size_mode
    local custom_size
    local custom_absolute
    local enforce_safe_max=false
    
    # Get size mode (fixed or display-based)
    size_mode=$(get_popup_size_mode)
    
    # Get custom size configuration if size is "custom"
    if [ "${size}" = "custom" ]; then
        custom_size=$(get_popup_size_custom)
        custom_absolute=$(get_popup_size_custom_absolute)
        
        # If custom_size is empty, use custom_absolute as fallback
        if [ -z "${custom_size}" ]; then
            custom_size="${custom_absolute}"
        fi
    fi
    
    # Handle predefined sizes
    case "${size}" in
        xsmall)
            if [ "${size_mode}" = "display-based" ]; then
                # Calculate 15% × 15% from display resolution
                local resolution
                resolution=$(get_display_resolution 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "${resolution}" ]; then
                    local screen_width screen_height
                    screen_width=$(echo "${resolution}" | cut -d' ' -f1)
                    screen_height=$(echo "${resolution}" | cut -d' ' -f2)
                    width=$((screen_width * 15 / 100))
                    height=$((screen_height * 15 / 100))
                else
                    # Fallback to absolute pixels
                    width=384
                    height=216
                fi
            else
                # Fixed pixel mode
                width=384
                height=216
            fi
            ;;
        small)
            if [ "${size_mode}" = "display-based" ]; then
                # Calculate 20% × 20% from display resolution
                local resolution
                resolution=$(get_display_resolution 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "${resolution}" ]; then
                    local screen_width screen_height
                    screen_width=$(echo "${resolution}" | cut -d' ' -f1)
                    screen_height=$(echo "${resolution}" | cut -d' ' -f2)
                    width=$((screen_width * 20 / 100))
                    height=$((screen_height * 20 / 100))
                else
                    # Fallback to absolute pixels
                    width=512
                    height=288
                fi
            else
                # Fixed pixel mode (backward compatibility)
                width=400
                height=250
            fi
            ;;
        medium)
            if [ "${size_mode}" = "display-based" ]; then
                # Calculate 30% × 30% from display resolution
                local resolution
                resolution=$(get_display_resolution 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "${resolution}" ]; then
                    local screen_width screen_height
                    screen_width=$(echo "${resolution}" | cut -d' ' -f1)
                    screen_height=$(echo "${resolution}" | cut -d' ' -f2)
                    width=$((screen_width * 30 / 100))
                    height=$((screen_height * 30 / 100))
                else
                    # Fallback to absolute pixels
                    width=768
                    height=432
                fi
            else
                # Fixed pixel mode (backward compatibility)
                width=800
                height=500
            fi
            ;;
        large)
            if [ "${size_mode}" = "display-based" ]; then
                # Calculate 50% × 50% from display resolution
                local resolution
                resolution=$(get_display_resolution 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "${resolution}" ]; then
                    local screen_width screen_height
                    screen_width=$(echo "${resolution}" | cut -d' ' -f1)
                    screen_height=$(echo "${resolution}" | cut -d' ' -f2)
                    width=$((screen_width * 50 / 100))
                    height=$((screen_height * 50 / 100))
                else
                    # Fallback to absolute pixels
                    width=1230
                    height=720
                fi
            else
                # Fixed pixel mode (backward compatibility)
                width=1230
                height=720
            fi
            ;;
        xlarge)
            if [ "${size_mode}" = "display-based" ]; then
                # Calculate 75% × 75% from display resolution
                local resolution
                resolution=$(get_display_resolution 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "${resolution}" ]; then
                    local screen_width screen_height
                    screen_width=$(echo "${resolution}" | cut -d' ' -f1)
                    screen_height=$(echo "${resolution}" | cut -d' ' -f2)
                    width=$((screen_width * 75 / 100))
                    height=$((screen_height * 75 / 100))
                else
                    # Fallback to absolute pixels
                    width=1845
                    height=1080
                fi
            else
                # Fixed pixel mode - must be larger than large (1230×720)
                width=1845
                height=1080
            fi
            ;;
        max)
            if [ "${size_mode}" = "display-based" ]; then
                # Calculate 90% × 90% from display resolution
                local resolution
                resolution=$(get_display_resolution 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "${resolution}" ]; then
                    local screen_width screen_height
                    screen_width=$(echo "${resolution}" | cut -d' ' -f1)
                    screen_height=$(echo "${resolution}" | cut -d' ' -f2)
                    width=$((screen_width * 90 / 100))
                    height=$((screen_height * 90 / 100))
                else
                    # Fallback to absolute pixels
                    width=2214
                    height=1296
                fi
            else
                # Fixed pixel mode
                width=2214
                height=1296
            fi
            ;;
        custom)
            # Handle custom size
            if [ -n "${custom_size}" ]; then
                # Check if custom_size is percentage format
                if echo "${custom_size}" | grep -qE '^[0-9]+%x[0-9]+%$'; then
                    # Percentage format - calculate from display resolution
                    local width_percent height_percent
                    width_percent=$(echo "${custom_size}" | cut -d'x' -f1 | tr -d '%')
                    height_percent=$(echo "${custom_size}" | cut -d'x' -f2 | tr -d '%')
                    
                    # Validate percentage range (15-95%) - 95% maximum to ensure buttons remain visible
                    if [ "${width_percent}" -ge 15 ] && [ "${width_percent}" -le 95 ] && \
                       [ "${height_percent}" -ge 15 ] && [ "${height_percent}" -le 95 ]; then
                        local resolution
                        resolution=$(get_display_resolution 2>/dev/null)
                        if [ $? -eq 0 ] && [ -n "${resolution}" ]; then
                            local screen_width screen_height
                            screen_width=$(echo "${resolution}" | cut -d' ' -f1)
                            screen_height=$(echo "${resolution}" | cut -d' ' -f2)
                            width=$((screen_width * width_percent / 100))
                            height=$((screen_height * height_percent / 100))
                        else
                            # Fallback to absolute pixels from custom_absolute
                            if [ -n "${custom_absolute}" ] && echo "${custom_absolute}" | grep -qE '^[0-9]+x[0-9]+$'; then
                                width=$(echo "${custom_absolute}" | cut -d'x' -f1)
                                height=$(echo "${custom_absolute}" | cut -d'x' -f2)
                                enforce_safe_max=true
                            else
                                # Default fallback
                                width=1280
                                height=720
                            fi
                        fi
                    else
                        # Invalid percentage range, use fallback
                        if type log_message >/dev/null 2>&1; then
                            log_message "warning" "Invalid popup size percentage range: ${custom_size} (must be 15-95%). Using fallback."
                        fi
                        if type log_to_file >/dev/null 2>&1; then
                            log_to_file "WARNING" "Invalid popup size percentage range: ${custom_size} (must be 15-95%). Using fallback."
                        fi
                        if [ -n "${custom_absolute}" ] && echo "${custom_absolute}" | grep -qE '^[0-9]+x[0-9]+$'; then
                            width=$(echo "${custom_absolute}" | cut -d'x' -f1)
                            height=$(echo "${custom_absolute}" | cut -d'x' -f2)
                            enforce_safe_max=true
                        else
                            width=1280
                            height=720
                        fi
                    fi
                elif echo "${custom_size}" | grep -qE '^[0-9]+x[0-9]+$'; then
                    # Pixel format
                    width=$(echo "${custom_size}" | cut -d'x' -f1)
                    height=$(echo "${custom_size}" | cut -d'x' -f2)
                    enforce_safe_max=true
                else
                    # Invalid format, use fallback
                    if [ -n "${custom_absolute}" ] && echo "${custom_absolute}" | grep -qE '^[0-9]+x[0-9]+$'; then
                        width=$(echo "${custom_absolute}" | cut -d'x' -f1)
                        height=$(echo "${custom_absolute}" | cut -d'x' -f2)
                        enforce_safe_max=true
                    else
                        width=1280
                        height=720
                    fi
                fi
            else
                # No custom size configured, use default
                if [ "${size_mode}" = "display-based" ]; then
                    # Default 50% × 50%
                    local resolution
                    resolution=$(get_display_resolution 2>/dev/null)
                    if [ $? -eq 0 ] && [ -n "${resolution}" ]; then
                        local screen_width screen_height
                        screen_width=$(echo "${resolution}" | cut -d' ' -f1)
                        screen_height=$(echo "${resolution}" | cut -d' ' -f2)
                        width=$((screen_width * 50 / 100))
                        height=$((screen_height * 50 / 100))
                    else
                        width=1280
                        height=720
                    fi
                else
                    width=1280
                    height=720
                fi
            fi
            ;;
        *)
            # Custom format (WIDTHxHEIGHT or WIDTH%xHEIGHT%)
            if echo "${size}" | grep -qE '^[0-9]+x[0-9]+$'; then
                # Pixel format (WIDTHxHEIGHT)
                width=$(echo "${size}" | cut -d'x' -f1)
                height=$(echo "${size}" | cut -d'x' -f2)
                # Validate dimensions: minimum 384x216 (matches xsmall), maximum 95% of screen (to ensure buttons remain visible)
                local min_width=384
                local min_height=216
                if [ "${width}" -lt "${min_width}" ] || [ "${height}" -lt "${min_height}" ]; then
                    # Invalid dimensions, use xsmall default
                    width=${min_width}
                    height=${min_height}
                fi
                enforce_safe_max=true
            elif echo "${size}" | grep -qE '^[0-9]+%x[0-9]+%$'; then
                # Percentage format (WIDTH%xHEIGHT%)
                local width_percent height_percent
                width_percent=$(echo "${size}" | cut -d'x' -f1 | tr -d '%')
                height_percent=$(echo "${size}" | cut -d'x' -f2 | tr -d '%')
                
                # Validate percentage range (15-95%) - 95% maximum to ensure buttons remain visible
                if [ "${width_percent}" -ge 15 ] && [ "${width_percent}" -le 95 ] && \
                   [ "${height_percent}" -ge 15 ] && [ "${height_percent}" -le 95 ]; then
                    local resolution
                    resolution=$(get_display_resolution 2>/dev/null)
                    if [ $? -eq 0 ] && [ -n "${resolution}" ]; then
                        local screen_width screen_height
                        screen_width=$(echo "${resolution}" | cut -d' ' -f1)
                        screen_height=$(echo "${resolution}" | cut -d' ' -f2)
                        width=$((screen_width * width_percent / 100))
                        height=$((screen_height * height_percent / 100))
                    else
                        # Fallback to absolute pixels based on 2560×1440
                        width=$((2560 * width_percent / 100))
                        height=$((1440 * height_percent / 100))
                    fi
                else
                    # Invalid percentage range, use medium default
                    if type log_message >/dev/null 2>&1; then
                        log_message "warning" "Invalid popup size percentage range: ${size} (must be 15-95%). Using default medium size (768x432)."
                    fi
                    if type log_to_file >/dev/null 2>&1; then
                        log_to_file "WARNING" "Invalid popup size percentage range: ${size} (must be 15-95%). Using default medium size (768x432)."
                    fi
                    width=768
                    height=432
                fi
            else
                # Invalid format, use medium default
                width=768
                height=432
            fi
            ;;
    esac
    
    if [ "${enforce_safe_max}" = "true" ]; then
        local resolution
        resolution=$(get_display_resolution 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "${resolution}" ]; then
            local screen_width screen_height
            screen_width=$(echo "${resolution}" | cut -d' ' -f1)
            screen_height=$(echo "${resolution}" | cut -d' ' -f2)

            local clamped_dimensions
            clamped_dimensions=$(clamp_popup_dimensions_to_safe_display_max "${width}" "${height}" "${screen_width}" "${screen_height}")
            width="${clamped_dimensions%% *}"
            height="${clamped_dimensions#* }"
        fi
    fi

    echo "${width} ${height}"
}

# Get popup size mode from configuration file
# Returns: "fixed" (absolute pixel sizes) or "display-based" (percentage-based)
# Default: "fixed" (for backward compatibility)
# This is for Enhancement #3 (Enhanced Window Size Options)
get_popup_size_mode() {
    # Check if config file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "fixed"
        return 0
    fi
    
    # Read POPUP_SIZE_MODE from config file
    local mode
    mode=$(grep -E "^[[:space:]]*POPUP_SIZE_MODE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    
    if [ "${mode}" = "display-based" ]; then
        echo "display-based"
        return 0
    else
        # Default to fixed for backward compatibility
        echo "fixed"
        return 0
    fi
}

# Get popup custom size from configuration file
# Returns: Custom size string (percentage format like "50%x50%" or pixel format like "1280x720")
# Default: "50%x50%" (for display-based mode) or "1280x720" (for fixed mode)
# This is for Enhancement #3 (Enhanced Window Size Options)
get_popup_size_custom() {
    # Check if config file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "50%x50%"
        return 0
    fi
    
    # Read POPUP_SIZE_CUSTOM from config file
    local custom_size
    custom_size=$(grep -E "^[[:space:]]*POPUP_SIZE_CUSTOM=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    
    if [ -n "${custom_size}" ]; then
        echo "${custom_size}"
        return 0
    else
        # Default
        echo "50%x50%"
        return 0
    fi
}

# Get popup custom size absolute fallback from configuration file
# Returns: Absolute pixel size string (format: "WIDTHxHEIGHT")
# Default: "1280x720" (50% of 2560×1440)
# This is for Enhancement #3 (Enhanced Window Size Options)
get_popup_size_custom_absolute() {
    # Check if config file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "1280x720"
        return 0
    fi
    
    # Read POPUP_SIZE_CUSTOM_ABSOLUTE from config file
    local custom_absolute
    custom_absolute=$(grep -E "^[[:space:]]*POPUP_SIZE_CUSTOM_ABSOLUTE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    
    if [ -n "${custom_absolute}" ] && echo "${custom_absolute}" | grep -qE '^[0-9]+x[0-9]+$'; then
        echo "${custom_absolute}"
        return 0
    else
        # Default
        echo "1280x720"
        return 0
    fi
}
