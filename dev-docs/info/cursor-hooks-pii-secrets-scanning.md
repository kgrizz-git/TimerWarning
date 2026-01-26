# Cursor Hooks for PII and Secrets Scanning

## Overview

This document provides detailed information about using Cursor hooks to scan for Personally Identifiable Information (PII) and secrets before content leaves your machine. Cursor hooks allow you to intercept, analyze, and block or modify agent actions at various stages of the AI agent loop, providing a critical security layer for preventing sensitive data from being sent to AI services.

---

## What are Cursor Hooks?

Cursor hooks are custom scripts that execute at specific events in the AI agent loop. They communicate over stdio using JSON in both directions, allowing you to:

- **Observe** agent actions and content
- **Control** whether actions proceed (allow/deny)
- **Modify** data before it's processed
- **Extend** functionality with custom logic

Hooks can be written in any language (bash, Python, TypeScript, etc.) and are configured via JSON files at project, user, or system levels.

---

## Key Hooks for PII/Secrets Scanning

### 1. `beforeSubmitPrompt`

**When it fires**: Right after the user hits send but before the backend request is sent to the AI.

**Use case**: Scan user prompts for secrets/PII before they're sent to the AI service.

**Input fields**:
- `prompt`: The user's prompt text
- `attachments`: Array of file/rule attachments

**Output fields**:
- `continue`: `true` to allow, `false` to block
- `user_message`: Message shown to user when blocked

**Security behavior**: If the hook fails (crashes, times out, invalid JSON), the prompt submission proceeds (fail-open).

---

### 2. `beforeReadFile`

**When it fires**: Just before the Agent reads a file.

**Use case**: Scan file contents for secrets/PII before the agent accesses them.

**Input fields**:
- `file_path`: Absolute path to the file
- `content`: Full contents of the file
- `attachments`: Context attachments associated with the prompt

**Output fields**:
- `permission`: `"allow"` to proceed, `"deny"` to block
- `user_message`: Message shown when denied

**Security behavior**: **Fail-closed** - If the hook fails, the file read is blocked. This provides security guarantees for sensitive file access.

---

### 3. `beforeTabFileRead`

**When it fires**: Before Tab (inline completions) reads a file.

**Use case**: Apply different scanning policies to autonomous Tab operations vs user-directed Agent operations.

**Key differences from `beforeReadFile`**:
- Only triggered by Tab, not Agent
- Does not include `attachments` field
- Useful for applying different policies to autonomous operations

**Input fields**:
- `file_path`: Absolute path to the file
- `content`: Full contents of the file

**Output fields**:
- `permission`: `"allow"` or `"deny"`

---

## Configuration

### Hook File Locations

Hooks can be configured at multiple levels (priority order, highest to lowest):

1. **Enterprise** (system-wide):
   - macOS: `/Library/Application Support/Cursor/hooks.json`
   - Linux/WSL: `/etc/cursor/hooks.json`
   - Windows: `C:\ProgramData\Cursor\hooks.json`

2. **Team** (cloud-distributed, Enterprise only):
   - Managed via Cursor web dashboard

3. **Project** (project-specific):
   - `<project-root>/.cursor/hooks.json`
   - Runs from project root directory
   - Use paths like `.cursor/hooks/script.sh`

4. **User** (user-specific):
   - `~/.cursor/hooks.json`
   - Runs from `~/.cursor/` directory
   - Use paths like `./hooks/script.sh` or `hooks/script.sh`

### Basic Configuration Structure

```json
{
  "version": 1,
  "hooks": {
    "beforeSubmitPrompt": [
      {
        "command": ".cursor/hooks/scan-secrets.sh",
        "timeout": 10
      }
    ],
    "beforeReadFile": [
      {
        "command": ".cursor/hooks/scan-secrets.sh",
        "timeout": 10
      }
    ],
    "beforeTabFileRead": [
      {
        "command": ".cursor/hooks/scan-secrets.sh",
        "timeout": 10
      }
    ]
  }
}
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `version` | number | `1` | Config schema version |
| `command` | string | required | Script path or command |
| `timeout` | number | platform default | Execution timeout in seconds |
| `type` | `"command"` \| `"prompt"` | `"command"` | Hook execution type |
| `matcher` | object | - | Filter criteria for when hook runs |

---

## Implementation Examples

### Example 1: Bash Script with Pattern Matching

Create `.cursor/hooks/scan-secrets.sh`:

```bash
#!/bin/bash

# Read JSON input from stdin
INPUT=$(cat)

# Extract the content to scan based on hook type
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')

if [ "$HOOK_EVENT" = "beforeSubmitPrompt" ]; then
    CONTENT=$(echo "$INPUT" | jq -r '.prompt // empty')
elif [ "$HOOK_EVENT" = "beforeReadFile" ] || [ "$HOOK_EVENT" = "beforeTabFileRead" ]; then
    CONTENT=$(echo "$INPUT" | jq -r '.content // empty')
    FILE_PATH=$(echo "$INPUT" | jq -r '.file_path // empty')
else
    # Unknown hook type, allow it
    echo '{"continue": true}'
    exit 0
fi

# Patterns to detect secrets/PII
PATTERNS=(
    "password\s*[:=]\s*['\"]?[^'\"]+['\"]?"
    "api[_-]?key\s*[:=]\s*['\"]?[^'\"]+['\"]?"
    "secret\s*[:=]\s*['\"]?[^'\"]+['\"]?"
    "token\s*[:=]\s*['\"]?[^'\"]+['\"]?"
    "aws[_-]?access[_-]?key"
    "aws[_-]?secret[_-]?key"
    "private[_-]?key"
    "ssh[_-]?key"
    "BEGIN\s+(RSA|DSA|EC|OPENSSH)\s+PRIVATE\s+KEY"
    "[0-9]{4}[-\s]?[0-9]{4}[-\s]?[0-9]{4}[-\s]?[0-9]{4}"  # Credit card
    "[0-9]{3}-[0-9]{2}-[0-9]{4}"  # SSN
    "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"  # Email
)

FOUND_SECRETS=()

for pattern in "${PATTERNS[@]}"; do
    if echo "$CONTENT" | grep -qiE "$pattern"; then
        FOUND_SECRETS+=("$pattern")
    fi
done

# If secrets found, block the action
if [ ${#FOUND_SECRETS[@]} -gt 0 ]; then
    if [ "$HOOK_EVENT" = "beforeSubmitPrompt" ]; then
        echo "{\"continue\": false, \"user_message\": \"Blocked: Potential secrets or PII detected in prompt. Please remove sensitive information before submitting.\"}"
    else
        echo "{\"permission\": \"deny\", \"user_message\": \"Blocked: Potential secrets or PII detected in file: $FILE_PATH\"}"
    fi
    exit 0
fi

# No secrets found, allow the action
if [ "$HOOK_EVENT" = "beforeSubmitPrompt" ]; then
    echo '{"continue": true}'
else
    echo '{"permission": "allow"}'
fi
```

Make it executable:
```bash
chmod +x .cursor/hooks/scan-secrets.sh
```

**Pros**:
- Simple, no dependencies beyond `jq` and standard Unix tools
- Fast execution
- Easy to customize patterns

**Cons**:
- Limited pattern matching capabilities
- May have false positives
- Requires `jq` for JSON parsing

---

### Example 2: Python Script with Advanced Scanning

Create `.cursor/hooks/scan-secrets.py`:

```python
#!/usr/bin/env python3
import json
import sys
import re
from typing import Dict, List, Any

def scan_for_secrets(content: str) -> List[str]:
    """Scan content for potential secrets and PII."""
    found = []
    
    # Secret patterns
    patterns = {
        "API Key": r'(?i)(api[_-]?key|apikey)\s*[:=]\s*["\']?([a-zA-Z0-9_\-]{20,})["\']?',
        "AWS Access Key": r'(?i)AKIA[0-9A-Z]{16}',
        "AWS Secret Key": r'(?i)aws[_-]?secret[_-]?access[_-]?key\s*[:=]\s*["\']?([^"\']+)["\']?',
        "Private Key": r'-----BEGIN\s+(RSA|DSA|EC|OPENSSH)\s+PRIVATE\s+KEY-----',
        "Password": r'(?i)password\s*[:=]\s*["\']?([^"\']+)["\']?',
        "Token": r'(?i)token\s*[:=]\s*["\']?([a-zA-Z0-9_\-]{20,})["\']?',
        "Credit Card": r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b',
        "SSN": r'\b\d{3}-\d{2}-\d{4}\b',
        "Email": r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b',
    }
    
    for name, pattern in patterns.items():
        if re.search(pattern, content):
            found.append(name)
    
    return found

def main():
    # Read JSON input from stdin
    input_data = json.load(sys.stdin)
    
    hook_event = input_data.get('hook_event_name', '')
    
    # Extract content based on hook type
    if hook_event == 'beforeSubmitPrompt':
        content = input_data.get('prompt', '')
    elif hook_event in ['beforeReadFile', 'beforeTabFileRead']:
        content = input_data.get('content', '')
        file_path = input_data.get('file_path', '')
    else:
        # Unknown hook, allow it
        print(json.dumps({"continue": True} if hook_event == 'beforeSubmitPrompt' else {"permission": "allow"}))
        return
    
    # Scan for secrets
    found_secrets = scan_for_secrets(content)
    
    if found_secrets:
        if hook_event == 'beforeSubmitPrompt':
            response = {
                "continue": False,
                "user_message": f"Blocked: Detected potential secrets/PII: {', '.join(found_secrets)}. Please remove sensitive information."
            }
        else:
            response = {
                "permission": "deny",
                "user_message": f"Blocked: Detected potential secrets/PII in {file_path}: {', '.join(found_secrets)}"
            }
        print(json.dumps(response))
    else:
        # No secrets found, allow
        if hook_event == 'beforeSubmitPrompt':
            print(json.dumps({"continue": True}))
        else:
            print(json.dumps({"permission": "allow"}))

if __name__ == '__main__':
    main()
```

Update `hooks.json`:
```json
{
  "version": 1,
  "hooks": {
    "beforeSubmitPrompt": [
      {"command": "python3 .cursor/hooks/scan-secrets.py"}
    ],
    "beforeReadFile": [
      {"command": "python3 .cursor/hooks/scan-secrets.py"}
    ]
  }
}
```

**Pros**:
- More sophisticated pattern matching
- Better error handling
- Easier to extend with additional logic
- Can integrate with Python libraries

**Cons**:
- Requires Python 3
- Slightly slower than bash
- May need additional dependencies

---

### Example 3: Integration with Third-Party Tools

You can integrate professional secret scanning tools like `detect-secrets`, `truffleHog`, `gitleaks`, or `semgrep`.

#### Using `detect-secrets`

```bash
#!/bin/bash
INPUT=$(cat)
CONTENT=$(echo "$INPUT" | jq -r '.prompt // .content // empty')

# Use detect-secrets to scan
if echo "$CONTENT" | detect-secrets scan --force-use-all-plugins - 2>/dev/null | jq -e '.results | length > 0' >/dev/null; then
    echo '{"continue": false, "user_message": "Blocked: Secrets detected by detect-secrets"}'
else
    echo '{"continue": true}'
fi
```

**Installation**:
```bash
pip install detect-secrets
```

**Pros**:
- Professional-grade detection
- Multiple plugin support
- Lower false positive rate
- Actively maintained

**Cons**:
- Requires Python and pip
- Additional dependency
- May be slower than simple scripts

---

## Common Patterns to Detect

### Secrets

- **API Keys**: `api[_-]?key\s*[:=]\s*['\"]?[^'\"]+['\"]?`
- **AWS Access Keys**: `AKIA[0-9A-Z]{16}`
- **AWS Secret Keys**: `aws[_-]?secret[_-]?access[_-]?key`
- **Private Keys**: `-----BEGIN\s+(RSA|DSA|EC|OPENSSH)\s+PRIVATE\s+KEY-----`
- **Passwords**: `password\s*[:=]\s*['\"]?[^'\"]+['\"]?`
- **Tokens**: `token\s*[:=]\s*['\"]?[a-zA-Z0-9_\-]{20,}['\"]?`
- **OAuth Tokens**: `ya29\.[a-zA-Z0-9_-]+` (Google OAuth)
- **GitHub Tokens**: `ghp_[a-zA-Z0-9]{36}` or `gho_[a-zA-Z0-9]{36}`
- **Slack Tokens**: `xox[baprs]-[0-9a-zA-Z-]{10,48}`
- **JWT Tokens**: `eyJ[A-Za-z0-9-_=]+\.eyJ[A-Za-z0-9-_=]+\.?[A-Za-z0-9-_.+/=]*`

### PII

- **Email Addresses**: `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}`
- **Credit Cards**: `\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b`
- **SSN**: `\b\d{3}-\d{2}-\d{4}\b`
- **Phone Numbers**: `\b\d{3}[-.]?\d{3}[-.]?\d{4}\b`
- **IP Addresses**: `\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b`

---

## Testing Your Hooks

### Manual Testing

Test your hook script manually:

```bash
# Test beforeSubmitPrompt hook
echo '{"hook_event_name":"beforeSubmitPrompt","prompt":"My API key is secret123"}' | .cursor/hooks/scan-secrets.sh

# Test beforeReadFile hook
echo '{"hook_event_name":"beforeReadFile","file_path":"/path/to/file","content":"password=secret123"}' | .cursor/hooks/scan-secrets.sh
```

### Expected Outputs

**When secrets are detected**:
```json
{"continue": false, "user_message": "Blocked: Potential secrets or PII detected..."}
```
or
```json
{"permission": "deny", "user_message": "Blocked: Potential secrets or PII detected..."}
```

**When no secrets are found**:
```json
{"continue": true}
```
or
```json
{"permission": "allow"}
```

---

## Important Considerations

### Performance

- **Keep scanning fast**: Hooks run synchronously and can delay agent operations
- **Use timeouts**: Set appropriate timeouts in `hooks.json` (default is platform-specific)
- **Optimize patterns**: Complex regex patterns can be slow on large files

### False Positives

- **Tune patterns carefully**: Overly broad patterns may block legitimate content
- **Whitelist exceptions**: Consider adding logic to allow known-safe patterns
- **User feedback**: Provide clear messages explaining why content was blocked

### Security Behavior

- **Fail-closed hooks**: `beforeReadFile` and `beforeMCPExecution` block if the hook fails
- **Fail-open hooks**: `beforeSubmitPrompt` allows submission if the hook fails
- **Exit codes**: Command hooks returning exit code `2` block the action (equivalent to `"permission": "deny"`)

### Redaction vs. Blocking

Instead of blocking, you could redact sensitive content and allow the action:

```python
def redact_secrets(content: str) -> str:
    """Redact secrets instead of blocking."""
    # Replace patterns with [REDACTED]
    content = re.sub(r'password\s*[:=]\s*["\']?[^"\']+["\']?', 'password=[REDACTED]', content, flags=re.IGNORECASE)
    return content
```

However, **blocking is generally safer** as it prevents any risk of data leakage.

---

## Environment Variables

Hook scripts receive these environment variables:

| Variable | Description | Always Present |
|----------|-------------|----------------|
| `CURSOR_PROJECT_DIR` | Workspace root directory | Yes |
| `CURSOR_VERSION` | Cursor version string | Yes |
| `CURSOR_USER_EMAIL` | Authenticated user email | If logged in |
| `CURSOR_CODE_REMOTE` | Remote-aware project path | For remote workspaces |
| `CLAUDE_PROJECT_DIR` | Alias for project dir (Claude compatibility) | Yes |

Session-scoped environment variables from `sessionStart` hooks are passed to all subsequent hook executions within that session.

---

## Troubleshooting

### Hooks Not Running

1. **Check hook configuration**: Verify `hooks.json` syntax is valid JSON
2. **Verify script paths**: 
   - Project hooks: Use `.cursor/hooks/script.sh` (relative to project root)
   - User hooks: Use `./hooks/script.sh` (relative to `~/.cursor/`)
3. **Check permissions**: Ensure hook scripts are executable (`chmod +x`)
4. **Restart Cursor**: Hooks are loaded at startup

### Debugging

- **Hooks tab in Settings**: Cursor provides a Hooks tab in Settings to debug configured and executed hooks
- **Hooks output channel**: Check the Hooks output channel in Cursor to see errors
- **Test manually**: Run your hook script manually with sample JSON input

### Common Issues

- **jq not found**: Install `jq` for JSON parsing in bash scripts
- **Python not found**: Ensure Python 3 is installed and in PATH
- **Timeout errors**: Increase timeout in `hooks.json` if scanning large files
- **Invalid JSON output**: Ensure your script outputs valid JSON

---

## Third-Party Integrations

Cursor supports partner integrations for security scanning:

- **1Password**: Validate environment files before execution
- **Semgrep**: Automatically scan AI-generated code for vulnerabilities
- **Corridor**: Real-time feedback on code security
- **Snyk**: Review agent actions with Evo Agent Guard

See [Cursor's partner integrations documentation](https://cursor.com/docs/agent/third-party-hooks) for more details.

---

## Best Practices

1. **Start with simple patterns**: Begin with basic secret patterns and refine based on false positives
2. **Test thoroughly**: Test hooks with various content types and edge cases
3. **Monitor performance**: Ensure hooks don't significantly slow down agent operations
4. **Document patterns**: Keep a record of what patterns you're scanning for and why
5. **Update regularly**: Keep patterns updated as new secret types emerge
6. **Consider context**: Some patterns may be safe in certain contexts (e.g., example code)
7. **User education**: Help users understand why content is blocked and how to work safely

---

## References

- [Cursor Hooks Documentation](https://cursor.com/docs/agent/hooks)
- [Cursor Hooks Reference](https://cursor.com/docs/agent/hooks#reference)
- [1Password Cursor Hooks](https://github.com/1Password/cursor-hooks)
- [detect-secrets](https://github.com/Yelp/detect-secrets)
- [TruffleHog](https://github.com/trufflesecurity/trufflehog)
- [GitLeaks](https://github.com/gitleaks/gitleaks)

---

**Last Updated**: 2026-01-26
