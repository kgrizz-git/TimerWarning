# Audio Tools for Linux: Command-Line Playback Options

## Overview

This document provides detailed information about command-line audio playback tools available on Linux systems. It covers tool availability, capabilities, limitations, and distribution-specific considerations for implementing audio alerts in shell scripts.

---

## Available Audio Tools

### 1. PulseAudio Tools (`paplay`)

#### Availability
- **Most modern Linux distributions** (Ubuntu, Debian, Fedora, Arch, openSUSE, etc.)
- **Package**: `pulseaudio-utils` or `pulseaudio`

#### Pros
- Standard on most desktop Linux systems
- Works with PulseAudio sound server (most common)
- Supports multiple audio formats (WAV, OGG, MP3, etc.)
- Can specify volume level
- Works in systemd user services (inherits user session)

#### Cons
- Requires PulseAudio daemon running
- May not work in headless environments
- May not work if user session is locked/logged out

#### Usage
```bash
# Basic playback
paplay /path/to/sound.wav

# With volume control (0-65536, where 65536 = 100%)
paplay --volume=52429 /path/to/sound.wav  # 80% volume

# Play system bell sound
paplay /usr/share/sounds/freedesktop/stereo/bell.oga
```

#### Volume Control
- Range: 0-65536 (0 = mute, 65536 = 100%)
- Formula: `pulse_volume = (percentage * 65536) / 100`

---

### 2. PipeWire Tools (`pw-play`)

#### Availability
- **Modern distributions migrating to PipeWire** (Fedora 34+, openSUSE Tumbleweed, Arch with PipeWire)
- **Package**: `pipewire-utils` or `pipewire`

#### Pros
- Modern replacement for PulseAudio
- Backward compatible with PulseAudio clients
- Better low-latency performance
- Supports same audio formats as PulseAudio

#### Cons
- Newer technology, less widespread than PulseAudio
- Requires PipeWire daemon running

#### Usage
```bash
# Basic playback
pw-play /path/to/sound.wav

# Play system bell sound
pw-play /usr/share/sounds/freedesktop/stereo/bell.oga
```

#### Volume Control
- Use `pw-volume` or PulseAudio compatibility layer
- Volume control is less straightforward than PulseAudio

---

### 3. ALSA Tools (`aplay`)

#### Availability
- **Nearly universal on Linux** (part of ALSA utils)
- **Package**: `alsa-utils` (almost always pre-installed)

#### Pros
- Lowest-level audio system, always available
- Works without sound server (direct hardware access)
- Minimal dependencies
- Works in more restricted environments

#### Cons
- Only supports WAV and raw audio formats
- No built-in volume control (must use `amixer` separately)
- May conflict with PulseAudio/PipeWire if both try to access hardware
- Less user-friendly (requires device specification sometimes)

#### Usage
```bash
# Basic playback
aplay /path/to/sound.wav

# With device specification
aplay -D plughw:0,0 /path/to/sound.wav

# Quiet mode (suppress output)
aplay -q /path/to/sound.wav
```

#### Volume Control
- Use `amixer` separately:
  ```bash
  amixer set Master 50%  # Set to 50%
  amixer set Master 80% unmute  # Set to 80% and unmute
  ```

---

### 4. libcanberra (`canberra-gtk-play`)

#### Availability
- **Most desktop Linux distributions**
- **Package**: `libcanberra` or `libcanberra-gtk3`

#### Pros
- Designed for system event sounds
- Integrates with desktop environment sound themes
- Can play system sounds by name (e.g., "bell", "message")
- Works well with GTK applications

#### Cons
- Requires GTK libraries
- May not work in non-GTK environments
- Less control over audio file selection

#### Usage
```bash
# Play custom sound file
canberra-gtk-play -f /path/to/sound.wav

# Play system sound by name
canberra-gtk-play --id=bell
canberra-gtk-play --id=message
```

#### Volume Control
- Controlled by system sound settings
- No direct volume control via command line

---

### 5. speaker-test (ALSA)

#### Availability
- **Part of `alsa-utils`** (nearly universal)
- **Package**: `alsa-utils`

#### Pros
- Always available (part of ALSA)
- Can generate simple beep tones
- No sound file required

#### Cons
- Only generates test tones, not custom sounds
- Very limited (not suitable for custom audio files)
- Primarily for hardware testing

#### Usage
```bash
# Generate 1kHz tone for 1 second
speaker-test -t sine -f 1000 -l 1 -c 1

# Generate 440Hz tone (A note) for 0.5 seconds
speaker-test -t sine -f 440 -l 1 -c 1
```

#### Use Case
- Fallback for simple beep when no sound file available
- Hardware testing
- Simple alert tones

---

### 6. beep (PC Speaker)

#### Availability
- **Available but requires kernel module** (`pcspkr`)
- **Package**: `beep`

#### Pros
- Works even without sound card
- Very simple beep

#### Cons
- Requires `pcspkr` kernel module (often disabled by default)
- Only simple beeps, no audio files
- May not work on modern systems (module often blacklisted)

#### Usage
```bash
# Simple beep
beep

# Beep with frequency and duration
beep -f 1000 -l 500  # 1000Hz for 500ms
```

#### Use Case
- Last resort fallback
- Systems without sound card
- Minimal environments

---

## Tool Detection Priority

### Recommended Auto-Detection Order

1. **`paplay`** (PulseAudio) - Most common, best user experience
2. **`pw-play`** (PipeWire) - Modern systems
3. **`aplay`** (ALSA) - Always available fallback
4. **`canberra-gtk-play`** - Desktop environments
5. **`beep`** - Last resort
6. **Terminal bell** (`\a`) - Final fallback

### Detection Function Example

```bash
# Detect available audio tool (priority order)
detect_audio_tool() {
    # Check user preference first
    local preferred_tool
    preferred_tool=$(get_audio_alert_tool)
    
    if [ "${preferred_tool}" != "auto" ] && command -v "${preferred_tool}" >/dev/null 2>&1; then
        echo "${preferred_tool}"
        return 0
    fi
    
    # Auto-detect: try in priority order
    if command -v paplay >/dev/null 2>&1; then
        echo "paplay"
        return 0
    elif command -v pw-play >/dev/null 2>&1; then
        echo "pw-play"
        return 0
    elif command -v aplay >/dev/null 2>&1; then
        echo "aplay"
        return 0
    elif command -v canberra-gtk-play >/dev/null 2>&1; then
        echo "canberra-gtk-play"
        return 0
    elif command -v beep >/dev/null 2>&1; then
        echo "beep"
        return 0
    fi
    
    # Last resort: terminal bell
    echo "bell"
    return 0
}
```

---

## Systemd Service Environment Considerations

### Current Service Configuration

The system runs as a systemd user service (`sleep-warning.service`), which:
- Inherits user's environment variables
- Runs in user's session context
- Has access to user's audio session (PulseAudio/PipeWire)
- May have limited access if user session is locked

### Audio Access in Systemd Services

#### User Services
- Can access user's PulseAudio/PipeWire session if running in active session
- Environment variables may need to be explicitly set:
  - `PULSE_RUNTIME_PATH` for PulseAudio
  - `XDG_RUNTIME_DIR` for PipeWire

#### Session Services
- Better audio access, but requires `After=graphical-session.target`
- More reliable audio access in graphical sessions

#### Fallback Strategy
- ALSA (`aplay`) may work even if PulseAudio/PipeWire unavailable
- Direct hardware access doesn't require sound server

### Recommended Approach

1. **Primary**: Try PulseAudio (`paplay`) - most common, best user experience
2. **Secondary**: Try PipeWire (`pw-play`) - modern systems
3. **Tertiary**: Fall back to ALSA (`aplay`) - always available
4. **Last Resort**: Simple beep via `speaker-test` or terminal bell (`\a`)

---

## Distribution-Specific Considerations

### Ubuntu/Debian
- **PulseAudio**: Standard, `paplay` available
- **ALSA**: Always available via `alsa-utils`
- **libcanberra**: Usually installed on desktop environments

### Fedora (Recent Versions)
- **PipeWire**: Default on Fedora 34+
- **PulseAudio**: Available via compatibility layer
- **ALSA**: Always available

### Arch Linux
- **PulseAudio or PipeWire**: User choice
- **ALSA**: Always available
- **libcanberra**: Available in AUR if needed

### openSUSE
- **PipeWire**: Default on Tumbleweed
- **PulseAudio**: Available
- **ALSA**: Always available

### SteamOS (Steam Deck)
- **PipeWire**: Default audio system
- **PulseAudio**: Available via compatibility
- **ALSA**: Always available
- **Gaming Mode**: Audio works in systemd user services

### Minimal/Server Environments
- **ALSA**: Only option (`aplay`)
- **No PulseAudio/PipeWire**: May not have sound server
- **Fallback**: Terminal bell or silent (no error)

---

## Audio Playback Function Example

### Complete Implementation

```bash
# Play audio alert
play_audio_alert() {
    local audio_enabled
    audio_enabled=$(get_audio_alert_enabled)
    
    if [ "${audio_enabled}" != "true" ]; then
        return 0  # Audio alerts disabled
    fi
    
    local audio_tool
    audio_tool=$(detect_audio_tool)
    
    local audio_type
    audio_type=$(get_audio_alert_type)
    
    local sound_file
    sound_file=$(get_audio_alert_sound)
    
    case "${audio_tool}" in
        paplay)
            local volume
            volume=$(get_audio_alert_volume)
            local pulse_volume=$((volume * 65536 / 100))
            if [ -n "${sound_file}" ] && [ -f "${sound_file}" ]; then
                paplay --volume="${pulse_volume}" "${sound_file}" 2>/dev/null &
            else
                # Generate simple beep
                paplay --volume="${pulse_volume}" /usr/share/sounds/freedesktop/stereo/bell.oga 2>/dev/null &
            fi
            ;;
        pw-play)
            if [ -n "${sound_file}" ] && [ -f "${sound_file}" ]; then
                pw-play "${sound_file}" 2>/dev/null &
            else
                pw-play /usr/share/sounds/freedesktop/stereo/bell.oga 2>/dev/null &
            fi
            ;;
        aplay)
            if [ -n "${sound_file}" ] && [ -f "${sound_file}" ]; then
                aplay -q "${sound_file}" 2>/dev/null &
            else
                # Generate beep using speaker-test
                speaker-test -t sine -f 1000 -l 1 -c 1 >/dev/null 2>&1 &
            fi
            ;;
        canberra-gtk-play)
            if [ -n "${sound_file}" ] && [ -f "${sound_file}" ]; then
                canberra-gtk-play -f "${sound_file}" 2>/dev/null &
            else
                canberra-gtk-play --id=bell 2>/dev/null &
            fi
            ;;
        beep)
            beep 2>/dev/null &
            ;;
        bell|*)
            # Terminal bell (last resort)
            echo -e "\a" >&2
            ;;
    esac
}
```

### Key Implementation Notes

1. **Non-blocking**: All audio commands run in background (`&`)
2. **Error Suppression**: Suppress stderr (`2>/dev/null`) for graceful failure
3. **Graceful Degradation**: Never fail if audio unavailable
4. **Volume Control**: Only implemented for PulseAudio (most common)
5. **Fallback Chain**: Multiple fallbacks ensure something always works

---

## Format Support

### Audio File Formats

| Tool | WAV | OGG | MP3 | FLAC | Other |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **paplay** | ✅ | ✅ | ✅ | ✅ | Most formats |
| **pw-play** | ✅ | ✅ | ✅ | ✅ | Most formats |
| **aplay** | ✅ | ❌ | ❌ | ❌ | Raw audio only |
| **canberra-gtk-play** | ✅ | ✅ | ⚠️ | ⚠️ | Depends on backend |
| **beep** | ❌ | ❌ | ❌ | ❌ | No file support |
| **speaker-test** | ❌ | ❌ | ❌ | ❌ | No file support |

### Recommendations

- **WAV**: Universal format, supported by all tools that support files
- **OGG**: Good choice for PulseAudio/PipeWire (open format)
- **MP3**: Widely supported but may require additional codecs
- **System Sounds**: Use `/usr/share/sounds/freedesktop/stereo/bell.oga` for compatibility

---

## Error Handling

### Common Issues

1. **Audio daemon not running** (PulseAudio/PipeWire)
   - **Solution**: Fall back to ALSA or terminal bell
   - **Detection**: Command fails with error, catch and fallback

2. **No audio hardware**
   - **Solution**: Fail silently, don't show errors
   - **Detection**: Command fails, suppress errors

3. **User session locked**
   - **Solution**: May still work with ALSA, fallback gracefully
   - **Detection**: Test in actual locked session

4. **Missing sound file**
   - **Solution**: Use system sound or generate beep
   - **Detection**: Check file existence before playing

### Best Practices

- Always run audio commands in background (`&`)
- Suppress stderr (`2>/dev/null`) for graceful failure
- Never fail popup display due to audio issues
- Log audio attempts for debugging (optional)
- Implement multiple fallback levels

---

## Testing Considerations

### Test Scenarios

1. **Tool Availability**: Test with different tools available/unavailable
2. **Systemd Service**: Test audio playback from systemd timer context
3. **User Session**: Test with user logged in, locked, and logged out
4. **Audio Hardware**: Test with and without audio hardware
5. **Daemon Status**: Test with PulseAudio/PipeWire running and stopped
6. **Multiple Alerts**: Test rapid successive alerts (should not overlap)

### Edge Cases

- No audio hardware available
- Audio daemon not running
- User session locked
- Headless environment
- Multiple audio systems (PulseAudio + ALSA conflict)
- Invalid sound file path
- Unsupported audio format

---

## References

- [PulseAudio Documentation](https://www.freedesktop.org/wiki/Software/PulseAudio/)
- [PipeWire Documentation](https://pipewire.org/)
- [ALSA Documentation](https://www.alsa-project.org/)
- [libcanberra Documentation](https://0pointer.net/lennart/projects/libcanberra/)
