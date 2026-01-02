# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.4.x   | :white_check_mark: |
| < 1.4   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in OllamaRemote, please report it responsibly:

1. **Do NOT** open a public GitHub issue for security vulnerabilities
2. **Email** the maintainer directly or use GitHub's private vulnerability reporting
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Any suggested fixes (optional)

## Security Considerations

### API Keys
- All API keys are stored in the iOS Keychain (encrypted)
- Keys are never logged or transmitted to third parties
- Keys are only sent to their respective providers (Ollama Cloud, OpenRouter)

### Data Storage
- Conversations are stored locally using SwiftData
- No data is sent to external servers by the app itself
- Cloud providers (Ollama Cloud, OpenRouter) process your prompts per their privacy policies

### Network Security
- All cloud API calls use HTTPS
- Local Ollama uses HTTP (intentional - for LAN access only)
- No analytics or tracking

### On-Device Processing
- On-Device models run entirely on your device's Neural Engine
- No network requests are made when using On-Device provider

## Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 1 week
- **Fix Timeline**: Depends on severity
  - Critical: ASAP (within days)
  - High: Within 2 weeks
  - Medium/Low: Next release cycle
