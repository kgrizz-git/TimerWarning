#!/bin/bash

###############################################################################
# Sleep Warning System - Library Loader Helpers
#
# Provides helper functions to locate and source library files regardless of
# whether scripts are executed from the project directory, the installed
# ~/.local hierarchy, or legacy install paths. All top-level scripts should
# source this helper first to ensure consistent behavior.
###############################################################################

if [ -z "${LIBRARY_LOADER_LOADED:-}" ]; then
    LIBRARY_LOADER_LOADED=1

    # Initialize the list of library search paths. Arguments should be ordered
    # by priority (e.g., project lib first, then installed lib, then legacy dir).
    init_library_paths() {
        LIB_SEARCH_PATHS=()
        local candidate
        for candidate in "$@"; do
            if [ -n "${candidate}" ]; then
                LIB_SEARCH_PATHS+=("${candidate}")
            fi
        done
    }

    # Return the first existing library directory from the search path list.
    detect_library_dir() {
        local dir
        for dir in "${LIB_SEARCH_PATHS[@]}"; do
            if [ -n "${dir}" ] && [ -d "${dir}" ]; then
                echo "${dir}"
                return 0
            fi
        done
        return 1
    }

    # Locate a specific library file across the configured search paths. An
    # optional custom list of directories can be supplied after the filename.
    find_lib_file() {
        local target_file="$1"
        shift || true

        local search_paths=()
        if [ "$#" -gt 0 ]; then
            search_paths=("$@")
        else
            search_paths=("${LIB_SEARCH_PATHS[@]}")
        fi

        local search_dir
        for search_dir in "${search_paths[@]}"; do
            if [ -n "${search_dir}" ] && [ -f "${search_dir}/${target_file}" ]; then
                echo "${search_dir}/${target_file}"
                return 0
            fi
        done

        return 1
    }

    # Source a required library file. Accepts optional directory overrides.
    source_required_lib() {
        local target_file="$1"
        shift || true

        local lib_path
        if lib_path=$(find_lib_file "${target_file}" "$@"); then
            # shellcheck disable=SC1090
            source "${lib_path}"
            return 0
        fi

        echo "Error: required library '${target_file}' not found in search paths." >&2
        return 1
    }

    # Source an optional library file. Returns 0 if sourced, 1 if not found.
    source_optional_lib() {
        local target_file="$1"
        shift || true

        local lib_path
        if lib_path=$(find_lib_file "${target_file}" "$@"); then
            # shellcheck disable=SC1090
            source "${lib_path}"
            return 0
        fi

        return 1
    }
fi
