# Evaluation: Enhancement Plans - Modular Architecture Updates Needed

**Date**: 2026-01-19  
**Purpose**: Identify all enhancement plans that need updates after modular architecture refactoring

## Summary

After the modular architecture refactoring, many enhancement plans contain outdated references to:
- Specific line numbers in monolithic files (now split across modules)
- Function locations (functions moved to library modules)
- File structure (new `lib/` directory structure)
- Implementation details (different module organization)

## Architecture Changes

### sleep-warning.sh Modular Structure
- **Before**: Single file `sleep-warning.sh` (1,667 lines)
- **After**: Main script `sleep-warning.sh` (~128 lines) + 7 modules in `lib/`:
  - `lib/config.sh` - Configuration management
  - `lib/logging.sh` - Logging functions
  - `lib/display-detection.sh` - Display environment detection
  - `lib/desktop-environment.sh` - Desktop/dialog tool detection
  - `lib/window-management.sh` - Window manipulation
  - `lib/time-validation.sh` - Time range validation (contains `is_restricted_hour()`)
  - `lib/popup-display.sh` - Warning popup display (contains `show_warning()`)

### configure.sh Modular Structure
- **Before**: Single file `configure.sh` (2,588 lines)
- **After**: Main script `configure.sh` (~268 lines) + 7 modules in `lib/`:
  - `lib/configure-core.sh` - Core utilities and constants
  - `lib/configure-config.sh` - Config file operations (contains `write_config()`, `load_existing_config()`)
  - `lib/configure-time.sh` - Time formatting & validation (contains `format_ranges_human()`, `format_range_human()`)
  - `lib/configure-ui.sh` - Basic UI dialogs
  - `lib/configure-input.sh` - User input collection
  - `lib/configure-display.sh` - Complex displays
  - `lib/configure-workflow.sh` - Section orchestration

### Key Function Locations

| Function | Old Location | New Location |
|----------|-------------|--------------|
| `is_restricted_hour()` | `sleep-warning.sh` (line ~1265) | `lib/time-validation.sh` |
| `show_warning()` | `sleep-warning.sh` (line ~1295) | `lib/popup-display.sh` |
| `write_config()` | `configure.sh` (line ~217) | `lib/configure-config.sh` |
| `load_existing_config()` | `configure.sh` | `lib/configure-config.sh` |
| `format_ranges_human()` | `configure.sh` (line ~918) | `lib/configure-time.sh` |
| `format_range_human()` | `configure.sh` (line ~879) | `lib/configure-time.sh` |
| `format_hour_12h()` | `configure.sh` (line ~865) | `lib/configure-core.sh` |

## Enhancement Plans Requiring Updates

### 🔴 Critical Updates Needed (Outdated Line Numbers/Function Locations)

#### 1. **enhancement-22-prevent-24-7-restriction-configuration.md**
**Issues**:
- Line 217: References `write_config()` function in `configure.sh` → Should reference `lib/configure-config.sh`
- Line 27: References "sleep-warning.sh logic at lines 1256" → Outdated line number
- Multiple references to "in configure.sh" for functions now in modules

**Updates Needed**:
- Change "Locate `write_config()` function in `configure.sh`" → "Locate `write_config()` function in `lib/configure-config.sh`"
- Remove or update line number references
- Update references to indicate modular structure

#### 2. **enhancement-23-display-restricted-times-in-popup.md**
**Issues**:
- Line 169: References "configure.sh lines 865-942" → Functions now in `lib/configure-time.sh` and `lib/configure-core.sh`
- Line 173: References "sleep-warning.sh `show_warning()` - Line 1295" → Now in `lib/popup-display.sh`
- Line 175: References "lines 1389-1395 in sleep-warning.sh" → Outdated line numbers
- Multiple checklist items reference adding functions to `sleep-warning.sh` → Should reference appropriate modules

**Updates Needed**:
- Update all function location references to correct modules
- Remove specific line number references
- Update checklist items to reference correct modules:
  - `format_hour_12h()` → `lib/configure-core.sh` (already exists, can reuse)
  - `format_ranges_human()` → `lib/configure-time.sh` (already exists, can reuse)
  - New functions → `lib/popup-display.sh` or appropriate module

#### 3. **enhancement-19-prevent-configure-execution.md**
**Issues**:
- Line 22: References "Reuse `is_restricted_hour()` function from `sleep-warning.sh`" → Now in `lib/time-validation.sh`
- References to modifying `configure.sh` and `manage.sh` → Should note modular structure

**Updates Needed**:
- Update to reference `lib/time-validation.sh` for `is_restricted_hour()`
- Note that `configure.sh` now sources modules, so time check should be added early in main() or in a module
- Consider creating shared module or sourcing `lib/time-validation.sh` in configure.sh

#### 4. **enhancement-18-config-file-locking.md**
**Issues**:
- References to modifying `sleep-warning.sh` and `configure.sh` → Should reference modules
- Line 78: References "every `sleep-warning.sh` invocation" → Should note modular structure

**Updates Needed**:
- Update references to indicate which modules need modification
- Lock logic likely belongs in `lib/config.sh` or new module
- Config file operations in `lib/configure-config.sh`

#### 5. **enhancement-16b-12-hour-format-time-input.md**
**Issues**:
- Multiple references to updating `sleep-warning.sh` time comparison logic → Should reference `lib/time-validation.sh`
- References to `configure.sh` → Should reference `lib/configure-time.sh` or `lib/configure-input.sh`

**Updates Needed**:
- Update time comparison logic references to `lib/time-validation.sh`
- Update configure.sh references to appropriate modules

### 🟡 Moderate Updates Needed (General References)

#### 6. **enhancement-25-user-selectable-dialog-tool.md**
**Status**: ✅ **Already Updated** - References modular structure correctly
- Correctly references `lib/config.sh`, `lib/desktop-environment.sh`, `lib/configure-config.sh`, `lib/configure-ui.sh`

#### 7. **enhancement-24-unified-dialog-priority-yad-first.md**
**Status**: ✅ **Already Updated** - References modular structure correctly
- Correctly references `lib/desktop-environment.sh`, `lib/popup-display.sh`, `lib/configure-*.sh` modules

#### 8. **fix-window-title-and-geometry-parsing.md**
**Status**: ✅ **Already Updated** - References modular structure correctly
- Correctly references `lib/popup-display.sh` and `lib/window-management.sh`

#### 9. **fix-popup-position-and-status-display.md**
**Status**: ✅ **Already Updated** - References modular structure correctly
- Correctly references `lib/window-management.sh` and `lib/popup-display.sh`

### 🟢 Minor Updates Needed (Documentation Only)

#### 10. **Other Enhancement Files**
Most other enhancement files have generic references (e.g., "modify configure.sh", "update sleep-warning.sh") that are still valid but could be more specific about which modules to modify.

## Recommended Update Strategy

### Phase 1: Critical Updates (High Priority)
1. **enhancement-22-prevent-24-7-restriction-configuration.md**
   - Update `write_config()` location reference
   - Remove outdated line number references
   - Add note about modular structure

2. **enhancement-23-display-restricted-times-in-popup.md**
   - Update all function location references
   - Update checklist to reference correct modules
   - Note that some functions already exist in modules (can reuse)

3. **enhancement-19-prevent-configure-execution.md**
   - Update `is_restricted_hour()` location reference
   - Add note about sourcing `lib/time-validation.sh` in configure.sh

### Phase 2: Moderate Updates (Medium Priority)
4. **enhancement-18-config-file-locking.md**
   - Update references to indicate which modules need modification
   - Clarify module structure

5. **enhancement-16b-12-hour-format-time-input.md**
   - Update time comparison logic references
   - Update configure.sh references

### Phase 3: Documentation Improvements (Low Priority)
6. Update remaining enhancement files with more specific module references where helpful

## Specific Update Patterns

### Pattern 1: Function Location Updates
**Before**:
```
- Locate `write_config()` function in `configure.sh`
```

**After**:
```
- Locate `write_config()` function in `lib/configure-config.sh`
- Note: This function is part of the configuration file operations module
```

### Pattern 2: Line Number Removal
**Before**:
```
- **Existing formatting functions** (to adapt): `configure.sh` lines 865-942
```

**After**:
```
- **Existing formatting functions** (to adapt):
  - `format_hour_12h()` in `lib/configure-core.sh`
  - `format_range_human()` in `lib/configure-time.sh`
  - `format_ranges_human()` in `lib/configure-time.sh`
```

### Pattern 3: Module Structure Notes
**Before**:
```
- Modify `show_warning()` function in `sleep-warning.sh`
```

**After**:
```
- Modify `show_warning()` function in `lib/popup-display.sh`
- Note: The sleep-warning.sh script now uses a modular architecture. The `show_warning()` function is located in the popup-display module.
```

### Pattern 4: Shared Function References
**Before**:
```
- Reuse `is_restricted_hour()` function from `sleep-warning.sh`
```

**After**:
```
- Reuse `is_restricted_hour()` function from `lib/time-validation.sh`
- Note: Both `sleep-warning.sh` and `configure.sh` can source this module to use the same time validation logic
```

## Implementation Notes

### Sourcing Modules Across Scripts
Some enhancements (e.g., #19) require functions from `sleep-warning.sh` modules to be used in `configure.sh`. Options:

1. **Source the module directly**:
   ```bash
   # In configure.sh, add:
   source "${LIB_DIR}/time-validation.sh" || exit 1
   ```

2. **Create shared utility module**:
   - Move shared functions to a common location
   - Both scripts source the shared module

3. **Duplicate function** (not recommended):
   - Copy function to configure modules
   - Maintains separation but creates duplication

**Recommendation**: Option 1 (source the module directly) is simplest and maintains consistency.

### Module Dependency Considerations
When updating enhancement plans, consider:
- Module dependencies (which modules depend on which)
- Source order in main scripts
- Global variable usage
- Function naming conflicts

## Checklist for Each Enhancement Update

When updating an enhancement plan, verify:
- [ ] All function location references are updated to correct modules
- [ ] Outdated line numbers are removed or updated
- [ ] File structure references reflect modular architecture
- [ ] Module dependencies are noted where relevant
- [ ] Implementation approach accounts for modular structure
- [ ] Checklist items reference correct modules
- [ ] Code examples (if any) reflect modular structure

## Main Plan File (linux-warning-system-plan.md)

**Status**: ✅ **Mostly Current** - High-level references are still valid

**Minor Updates Recommended**:
- Add note about modular architecture in Architecture Overview section
- Update component descriptions to mention modular structure
- Reference modular architecture documentation

**Current References** (still valid):
- References to `sleep-warning.sh` and `configure.sh` as components (high-level, still accurate)
- No specific line numbers or function locations referenced
- Enhancement references are generic (still valid)

## Related Documentation

- [plan-modular-architecture-sleep-warning.md](../completed-plans/plan-modular-architecture-sleep-warning.md) - Sleep warning modular architecture details
- [plan-modular-architecture-configure.md](../completed-plans/plan-modular-architecture-configure.md) - Configure wizard modular architecture details
- [TECHNICAL_DETAILS.md](../TECHNICAL_DETAILS.md) - General technical documentation

## Conclusion

**Total Enhancements Evaluated**: 35 files  
**Critical Updates Needed**: 5 files  
**Moderate Updates Needed**: 2 files  
**Already Updated**: 4 files  
**Minor/No Updates Needed**: 24 files

The modular architecture refactoring was successful, but several enhancement plans need updates to reflect the new structure. Priority should be given to enhancements that are actively being implemented or are high-priority features.
