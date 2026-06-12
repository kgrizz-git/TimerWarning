# Refactor Assessment - 2026-06-12 00:14:17

## Assessment Date
- **Date**: 2026-06-12
- **Time**: 00:14:17
- **Assessor**: AI Agent
- **Baseline comparison**: [refactor-assessment-2026-05-31-140925.md](refactor-assessment-2026-05-31-140925.md)

## Top 5 Largest Shell Files (excluding backups/imports)

| Rank | File | Lines |
|------|------|-------|
| 1 | `lib/configure-display.sh` | 1,338 |
| 2 | `lib/configure-ui.sh` | 1,291 |
| 3 | `install.sh` | 1,077 |
| 4 | `lib/configure-dialogs-darwin.sh` | 939 |
| 5 | `lib/configure-input-features.sh` | 937 |

Runner-up files near threshold (>=750 lines): `lib/configure-dialogs.sh` (923), `lib/configure-config.sh` (871), `status.sh` (883), `lib/config.sh` (864).

## Large Functions (50+ lines)

### `lib/configure-display.sh` (1,338 lines)

| Function | Lines | Concern |
|----------|-------|---------|
| `show_summary()` | 399 | God function — display, overlap detection, warnings, validation all in one |
| `show_main_menu()` | 267 | Monolithic menu dispatcher |
| `show_visual_grid()` | 233 | Grid rendering + editing interleaved |
| `_configure_build_grid_cache()` | 110 | Data prep for grid — could be separate module |
| `format_popup_size_display()` | 105 | Formatting logic mixed with I/O |
| `show_window_behavior_submenu()` | 102 | Submenu — reasonable size but duplicate patterns |

**Branching density**: 158 `if/elif/case/while/for` — highest in codebase.

### `lib/configure-ui.sh` (1,291 lines)

| Function | Lines | Concern |
|----------|-------|---------|
| `show_config_locked_error()` | 422 | Massive error-display function with embedded business logic |
| `calculate_restriction_end_time()` | 140 | Time math mixed with UI concerns |
| `ask_what_to_edit()` | 85 | Menu with duplicated dialog patterns |
| `show_help_dialog()` | 65 | Long help text inline |
| `show_welcome()` | 51 | Welcome text inline |

### `lib/configure-input-features.sh` (937 lines)

| Function | Lines | Concern |
|----------|-------|---------|
| `get_dialog_tool_selection()` | 196 | Tool detection + selection UI |
| `get_security_settings_config()` | 147 | Compound settings getter |
| `get_uninstall_protection_mode_config()` | 115 | Near-identical structure to `get_pause_enabled_config` |
| `get_pause_enabled_config()` | 104 | Boilerplate getter pattern |
| `get_pause_duration_config()` | 78 | Duplicated getter boilerplate |
| `get_pause_cooldown_hours_config()` | 78 | Duplicated getter boilerplate |
| `get_config_lock_enabled_config()` | 60 | Duplicated getter boilerplate |
| `get_configure_block_enabled_config()` | 46 | Duplicated getter boilerplate |

### `lib/configure-dialogs.sh` (923 lines)

| Function | Lines | Concern |
|----------|-------|---------|
| `show_multi_column_list_dialog()` | 242 | Complex multi-toolkit dialog |
| `manage_ranges_dialog()` | 241 | Range editing — full CRUD inline |
| `show_entry_dialog()` | 99 | Multi-toolkit dispatch |
| `show_list_dialog()` | 92 | Multi-toolkit dispatch |
| `show_text_info_dialog()` | 33 | Acceptable |
| `show_info_dialog()` | 31 | Acceptable |
| `show_error_dialog()` | 31 | Acceptable |

### `lib/configure-dialogs-darwin.sh` (939 lines, 151 `if/elif/case`)

Primarily internal helpers (`_cd_darwin_*`). The 74 toolkit references and 82 branch points indicate significant single-function complexity within the macOS dialog layer.

### `install.sh` (1,077 lines)

| Function | Lines | Concern |
|----------|-------|---------|
| `main_linux()` | 118 | Orchestration — acceptable for install |
| `migrate_config_to_subdirectory()` | 111 | Migration — one-time logic |
| `install_files()` | 103 | File copy + verify |

### `status.sh` (883 lines)

| Function | Lines | Concern |
|----------|-------|---------|
| `show_configuration()` | 397 | God function — reads and formats everything |
| `check_service_status()` | 106 | Platform dispatch — acceptable |

### `lib/configure-config.sh` (871 lines)

| Function | Lines | Concern |
|----------|-------|---------|
| `load_existing_config()` | 289 | Parses entire config file inline |
| `write_config()` | 241 | Serializes entire config inline |
| `_write_config_header()` | 142 | Large header generation |

### `lib/config.sh` (864 lines)

| Function | Lines | Concern |
|----------|-------|---------|
| `parse_uninstall_lock_hours()` | 88 | Similar structure to `parse_lock_hours()` |
| `parse_lock_hours()` | 67 | Similar structure to `parse_uninstall_lock_hours()` |
| `parse_config()` | 54 | Core parser — acceptable |

## Key Observations

### 1. Getter Boilerplate Duplication (`configure-input-features.sh`)

Eight `get_*_config()` functions (lines 98–936) share an almost identical structure:
- Read existing value from config
- Decide GUI vs CLI
- Show dialog / prompt
- Validate input
- Return result

The pattern repeats 8 times with minor variations (`default`, `validation_func`, `prompt_text`). A data-driven or higher-order approach could eliminate ~60% of this code.

### 2. Config Key String Sprawl

Config keys (`LOCK_HOURS`, `MIN_DISPLAY_TIME`, `DIALOG_TOOL`, `CHECK_INTERVAL`, etc.) are referenced by raw string across 79+ total references in `lib/`. `LOCK_HOURS` alone has 81 references. These are not centralized as constants — grep-based coupling makes refactor risky.

### 3. Deep Nesting

- `lib/configure-display.sh`: 675 lines at 4+ indentation levels
- `lib/configure-dialogs.sh`: 552 lines at 4+ levels
- `lib/configure-input-features.sh`: 520 lines at 4+ levels
- `lib/configure-ui.sh`: 492 lines at 4+ levels

Deep nesting indicates functions doing too many things. These numbers suggest systematic extraction opportunities.

### 4. Multi-Toolkit Dispatch Pattern (`configure-dialogs.sh`)

`show_multi_column_list_dialog()` (242 lines) and `manage_ranges_dialog()` (241 lines) both contain large `if is_darwin / yad / zenity / kdialog` branches. The toolkit dispatch is interleaved with business logic. The Darwin path delegates to `configure-dialogs-darwin.sh`, but the Linux paths inline everything.

### 5. `show_config_locked_error()` — 422 lines

This single function in `configure-ui.sh` is larger than many entire source files. It embeds: error message composition, time calculation, multiple dialog toolkits, platform branching, and retry logic. Should be decomposed into: error message builder, time calculator (likely reuse `calculate_restriction_end_time`), and display dispatcher.

### 6. `show_summary()` — 399 lines

`configure-display.sh:939` — combines overlap detection, warning generation, formatting, and display. Overlap detection and warning generation should be pure functions callable without UI.

### 7. `show_configuration()` — 397 lines

`status.sh:422` — reads, parses, and formats the entire config. The formatting logic for each section could be extracted into smaller display helpers.

### 8. Parse Function Duplication (`config.sh`)

`parse_lock_hours()` (67 lines) and `parse_uninstall_lock_hours()` (88 lines) are structurally identical, differing only in the array name they populate. A single parameterized function would eliminate ~65 lines.

### 9. Sourcing Chain Complexity

17 source/include points across `configure-*.sh` files. `configure-ui.sh` conditionally sources `configure-core.sh` and `configure-time.sh` at runtime (lines 638, 871-872), making dependencies implicit rather than declared at file head.

### 10. No `TODO`/`FIXME` Debt Markers

The codebase has essentially zero `TODO`/`FIXME`/`HACK` markers outside intentional fallback patterns. This is clean but means there's no in-code roadmap for known issues.

## Prioritized Recommendations

| Priority | File | Recommendation | Impact | Risk |
|----------|------|----------------|--------|------|
| **P1** | `lib/configure-input-features.sh` | Extract shared getter template; replace 8 boilerplate functions with data-driven dispatch | Removes ~500 lines of duplication | Low — internal API unchanged |
| **P1** | `lib/config.sh` | Merge `parse_lock_hours` / `parse_uninstall_lock_hours` into parameterized function | ~65 lines removed, bug fix consistency | Low — called only from `parse_config` |
| **P2** | `lib/configure-ui.sh` | Decompose `show_config_locked_error` (422 lines) into error-msg builder, time calculator, display dispatcher | Readability, testability | Medium — error display is safety-adjacent |
| **P2** | `lib/configure-display.sh` | Extract overlap detection and warning generation from `show_summary` into pure functions | Testability, reuse | Medium — display is safety-adjacent |
| **P2** | `lib/configure-dialogs.sh` | Extract toolkit dispatch from `show_multi_column_list_dialog` and `manage_ranges_dialog` into shared dispatch helpers | Reduces nesting, improves Linux readability | Medium — dialog flow is user-facing |
| **P3** | `lib/configure-display.sh` | Break `show_main_menu` (267 lines) into submenu handlers | Readability | Low |
| **P3** | `status.sh` | Extract per-section formatters from `show_configuration` (397 lines) | Readability, testing | Low — read-only path |
| **P3** | `lib/configure-config.sh` | Extract section serializers from `write_config` / `load_existing_config` | Already partially done; complete the extraction | Low |
| **P3** | All config files | Centralize config key strings as variables/constants | Reduces grep-coupling, enables rename refactors | Medium — cross-cutting |
| **P4** | `lib/configure-ui.sh` | Inline help text → heredoc constants or separate data file | Reduces function length | Low |

## Files Appropriately Large (Justified)

- `lib/configure-dialogs-darwin.sh` (939 lines): Darwin-specific dialog implementations with 20+ internal helpers. Each helper is focused. Size is a consequence of AppleScript/Python bridging complexity, not design issues.
- `install.sh` (1,077 lines): Installation is inherently sequential and cross-cutting. Functions are already decomposed; further splitting would create coordination overhead.
- `lib/configure-validation.sh` (598 lines): Validation rules are inherently branching. Each function is a rule — the count of rules drives the line count.

## Summary Statistics

| Metric | Value |
|--------|-------|
| Total `.sh` files in `lib/` | 56 |
| Files >= 750 lines | 9 |
| Files >= 1,000 lines | 3 |
| Max function size | 422 lines (`show_config_locked_error`) |
| Functions > 200 lines | 7 |
| Functions > 100 lines | 15 |
| Total `if/elif/case` branches in configure-display.sh | 158 |
| Lines at 4+ indent (configure-display.sh) | 675 |
| Config key string references across `lib/` | 300+ |
| Boilerplate getter functions in configure-input-features.sh | 8 |