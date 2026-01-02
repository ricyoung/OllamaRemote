# Privacy Policy for OllamaRemote

**Last updated:** January 2, 2026

## Overview

OllamaRemote is designed with privacy as a core principle. We believe your conversations with AI should remain private and under your control.

## Data Collection

**OllamaRemote does NOT collect, store, or transmit any personal data to us.** We have no servers, no analytics, and no tracking.

### What stays on your device:
- All conversation history
- Provider settings and API keys
- App preferences
- Usage statistics (shown only to you)

### What leaves your device:

Data only leaves your device when YOU initiate a conversation, and it goes directly to YOUR chosen provider:

| Provider | Where data goes | Privacy |
|----------|----------------|---------|
| **Local Ollama** | Your own computer/server | Complete privacy - never leaves your network |
| **On-Device** | Nowhere - runs on Neural Engine | Complete privacy - processed locally |
| **Ollama Cloud** | Ollama's servers | Subject to [Ollama's Privacy Policy](https://ollama.com/privacy) |
| **OpenRouter** | OpenRouter's servers | Subject to [OpenRouter's Privacy Policy](https://openrouter.ai/privacy) |

## API Keys

Your API keys are stored securely in the iOS Keychain, Apple's encrypted credential storage system. They are:
- Encrypted at rest
- Never transmitted to us
- Only sent to the respective provider when making API calls

## Third-Party Services

When using cloud providers (Ollama Cloud, OpenRouter), your conversations are processed by those services. Please review their respective privacy policies:
- [Ollama Privacy Policy](https://ollama.com/privacy)
- [OpenRouter Privacy Policy](https://openrouter.ai/privacy)

## Local Processing

When using Local Ollama or On-Device providers:
- **No data is sent to any external servers**
- All processing happens on your device or local network
- Your conversations are completely private

## Data Storage

- Conversations are stored locally using SwiftData (Apple's persistence framework)
- Data is stored in your app's private container
- Data is included in iCloud backups if you have iCloud Backup enabled
- You can delete all data at any time from Settings → Clear All Conversations

## Children's Privacy

OllamaRemote is not directed at children under 13. We do not knowingly collect any information from children.

## Changes to This Policy

We may update this privacy policy from time to time. Changes will be posted to this page with an updated revision date.

## Open Source

OllamaRemote is open source. You can review exactly what the app does:
- [GitHub Repository](https://github.com/ricyoung/OllamaRemote)

## Contact

If you have questions about this privacy policy:
- [Open an issue on GitHub](https://github.com/ricyoung/OllamaRemote/issues)

---

**In summary:** We don't collect your data. Your conversations stay between you and whatever AI provider you choose. If you use local/on-device options, your data never leaves your control.
