# Distribution and Packaging Options

## Current Distribution Method

The project currently uses a traditional installation approach:
- Source code repository (Git)
- Installation script (`install.sh`) that copies files to system locations
- Manual installation via systemd user services
- Configuration via command-line scripts

## Alternative Distribution Options

### Option 1: Single Executable Installer Script

**Description**: Bundle all files into a single self-extracting installer script that users can download and run.

**Advantages**:
- Single file to download
- Easy distribution (GitHub releases, direct download)
- No package manager required
- Works across all distributions
- Can include all dependencies bundled

**Implementation Approach**:
- Create a shell script that contains all project files as base64-encoded data
- Script extracts files to temporary directory
- Runs installation process
- Cleans up temporary files
- Can be made executable with `chmod +x`

**Example Structure**:
```bash
#!/bin/bash
# Self-extracting installer
# Contains: sleep-warning.sh, configure.sh, manage.sh, systemd files, etc.

# Extract embedded files
# Run install.sh
# Clean up
```

**Checklist**:
- [ ] Create self-extracting installer script template
- [ ] Add file embedding mechanism (base64 or here-document)
- [ ] Add extraction logic
- [ ] Integrate with existing install.sh
- [ ] Test on multiple distributions
- [ ] Create build script to generate installer
- [ ] Document usage and distribution

### Option 2: Desktop GUI Application Wrapper

**Description**: Create a desktop application (using GTK, Qt, or Electron) that provides a GUI for configuration and management.

**Advantages**:
- User-friendly graphical interface
- No command-line knowledge required
- Can be packaged as AppImage, Flatpak, or Snap
- Provides visual feedback and status
- Can include system tray integration

**Implementation Approach**:
- Use Python with GTK (PyGObject) or similar
- Create GUI windows for:
  - Configuration wizard (replaces configure.sh)
  - Management interface (replaces manage.sh)
  - Status display
  - Settings panel
- Backend still uses systemd services
- Can be packaged as AppImage or Flatpak

**Technologies**:
- **Python + GTK**: Lightweight, native Linux look
- **Electron**: Cross-platform, modern UI, larger size
- **Qt/QML**: Native, good performance, cross-platform

**Checklist**:
- [ ] Choose GUI framework (GTK/Qt/Electron)
- [ ] Design GUI mockups/wireframes
- [ ] Implement configuration GUI
- [ ] Implement management GUI
- [ ] Implement status display
- [ ] Integrate with systemd services
- [ ] Add system tray icon (optional)
- [ ] Create desktop entry file
- [ ] Package as AppImage/Flatpak/Snap
- [ ] Test on multiple desktop environments

### Option 3: Flatpak Package

**Description**: Package the application as a Flatpak for easy distribution across Linux distributions.

**Advantages**:
- Works on any Linux distribution with Flatpak support
- Sandboxed execution
- Automatic dependency management
- Easy installation: `flatpak install sleep-warning`
- Centralized distribution (Flathub)

**Requirements**:
- Flatpak manifest file (`.flatpak.json` or `.yaml`)
- Application metadata
- Desktop entry file
- Icon files
- Build system setup

**Implementation Approach**:
- Create Flatpak manifest defining:
  - Runtime dependencies (systemd, bash, zenity)
  - Application files
  - Permissions (user service access)
- Build Flatpak package
- Submit to Flathub or host repository

**Checklist**:
- [ ] Create Flatpak manifest file
- [ ] Define runtime and SDK requirements
- [ ] Configure application permissions
- [ ] Create desktop entry and metadata
- [ ] Create application icons
- [ ] Build Flatpak package locally
- [ ] Test Flatpak installation and functionality
- [ ] Set up build automation (CI/CD)
- [ ] Submit to Flathub or create repository
- [ ] Document Flatpak installation process

### Option 4: Snap Package

**Description**: Package the application as a Snap for Ubuntu and other Snap-supported distributions.

**Advantages**:
- Works on Ubuntu, Debian, Fedora, Arch (with snapd)
- Automatic updates
- Sandboxed execution
- Centralized distribution (Snap Store)

**Requirements**:
- Snapcraft YAML file (`snapcraft.yaml`)
- Application metadata
- Desktop entry file
- Icon files
- Build system setup

**Implementation Approach**:
- Create `snapcraft.yaml` defining:
  - Base and build packages
  - Application files and scripts
  - Plugs and slots for systemd access
  - Desktop integration
- Build Snap package
- Submit to Snap Store

**Checklist**:
- [ ] Create snapcraft.yaml file
- [ ] Define base and build requirements
- [ ] Configure plugs for systemd user services
- [ ] Create desktop entry and metadata
- [ ] Create application icons
- [ ] Build Snap package locally
- [ ] Test Snap installation and functionality
- [ ] Set up build automation (CI/CD)
- [ ] Submit to Snap Store
- [ ] Document Snap installation process

### Option 5: Hybrid Approach (Recommended)

**Description**: Provide multiple distribution methods to suit different user preferences and technical levels.

**Distribution Methods**:
1. **Traditional**: Source code + install.sh (current method)
2. **Single Installer**: Self-extracting executable script
3. **GUI App**: Desktop application (AppImage or Flatpak)
4. **Package Manager**: Flatpak or Snap for easy installation

**Implementation Strategy**:
- Keep current installation method for advanced users
- Add single installer script for convenience
- Develop GUI application wrapper
- Package GUI app as Flatpak/Snap
- Provide clear documentation for each method

**Checklist**:
- [ ] Maintain current installation method
- [ ] Implement single installer script (Option 1)
- [ ] Develop GUI application (Option 2)
- [ ] Package GUI as Flatpak (Option 3)
- [ ] Package GUI as Snap (Option 4)
- [ ] Create unified documentation covering all methods
- [ ] Set up automated builds for all packages
- [ ] Create release process for all distribution formats

## Recommendations

**For End-User Ease**: 
- **Priority 1**: Single executable installer script (Option 1) - Easiest to implement, works everywhere
- **Priority 2**: GUI application wrapper (Option 2) - Best user experience, can be packaged

**For Distribution**:
- **Priority 1**: Flatpak (Option 3) - Best cross-distribution support, modern packaging
- **Priority 2**: Snap (Option 4) - Good for Ubuntu users, automatic updates

**For Maximum Compatibility**:
- Provide all methods: Traditional install, single installer, GUI app, and packaged versions
- Let users choose based on their technical level and distribution preferences
