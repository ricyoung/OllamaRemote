# OllamaRemote Help Guide

This guide will help you get started with OllamaRemote and troubleshoot common issues.

## Table of Contents

- [Quick Start](#quick-start)
- [Provider Setup](#provider-setup)
  - [OpenRouter (Easiest)](#openrouter-easiest)
  - [Local Ollama](#local-ollama)
  - [Ollama Cloud](#ollama-cloud)
- [Using the App](#using-the-app)
- [Troubleshooting](#troubleshooting)
- [Tips & Tricks](#tips--tricks)
- [FAQ](#faq)

---

## Quick Start

1. Open OllamaRemote
2. Tap the **Settings** gear icon (top-left)
3. Choose a provider and configure it
4. **Important:** Tap **Save** after entering your settings
5. Return to Conversations and start chatting!

---

## Provider Setup

### OpenRouter (Easiest)

OpenRouter is the easiest way to get started - it provides access to 200+ AI models, including many **free** options.

#### Step 1: Get an API Key
1. Visit [openrouter.ai](https://openrouter.ai)
2. Sign up for a free account
3. Go to [openrouter.ai/keys](https://openrouter.ai/keys)
4. Click "Create Key" to generate your API key
5. Copy the key (starts with `sk-or-`)

#### Step 2: Configure in OllamaRemote
1. Open OllamaRemote
2. Tap **Settings** (gear icon)
3. Tap **OpenRouter**
4. Paste your API key
5. Enable **"Prefer Free Models"** to avoid charges
6. Tap **Test Connection** to verify
7. **Tap Save** (this step is required!)

#### Step 3: Start Chatting
1. Return to Conversations
2. Tap the provider dropdown (top of screen)
3. Select **OpenRouter**
4. Choose a model from the model picker
5. Start chatting!

#### Recommended Free Models
- **Xiaomi MiMo-V2-Flash** - Fast and capable
- **Google Gemini Flash** - Good for general tasks
- **Meta Llama** variants - Various sizes available
- **Mistral** variants - Great for coding

---

### Local Ollama

Run AI models locally on your Mac, PC, or Linux machine.

#### Step 1: Install Ollama
1. Visit [ollama.ai](https://ollama.ai)
2. Download and install Ollama for your platform
3. Open Terminal and run: `ollama serve`
4. Pull a model: `ollama pull llama3.2`

#### Step 2: Find Your Computer's IP Address
- **Mac:** System Settings > Network > Your connection > Details > IP Address
- **Windows:** Settings > Network > Properties > IPv4 address
- **Linux:** Run `ip addr` or `hostname -I`

#### Step 3: Configure in OllamaRemote
1. Open OllamaRemote
2. Tap **Settings** > **Local Ollama**
3. Enter your computer's IP address (e.g., `192.168.1.100`)
4. Port is usually `11434` (default)
5. Tap **Test Connection**
6. **Tap Save**

#### Important Notes
- Your iPhone/iPad must be on the **same Wi-Fi network** as your computer
- Ollama must be running (`ollama serve`)
- Some firewalls may block connections - check your firewall settings

---

### Ollama Cloud

Connect to Ollama's cloud service for remote access.

1. Get your Ollama Cloud API key from your Ollama account
2. Open **Settings** > **Ollama Cloud**
3. Enter your API key
4. Tap **Test Connection**
5. **Tap Save**

---

## Using the App

### Starting a New Conversation
- Tap the **+** button in the top-right
- Or type in the "Ask anything..." field on the Conversations screen

### Switching Providers
1. Open any conversation
2. Tap the provider dropdown (shows current provider name)
3. Select a different provider

### Switching Models
1. Open any conversation
2. Tap the model picker (next to provider dropdown)
3. Select a different model

### Managing Conversations
- **Rename:** Long-press a conversation > Rename
- **Delete:** Swipe left on a conversation
- **Search:** Use the search bar at the bottom of Conversations
- **Share:** Tap the share icon in a conversation to export as markdown

### Keyboard Shortcuts (iPad)
- `⌘ + Return` - Send message
- `⌘ + N` - New conversation
- `⌘ + ,` - Open settings

---

## Troubleshooting

### "Provider Not Showing in Dropdown"

**Cause:** The provider hasn't been saved/configured.

**Solution:**
1. Go to **Settings**
2. Open the provider settings
3. Enter your API key or connection details
4. Tap **Test Connection** to verify
5. **Tap Save** (this is required!)

### "HTTP Error: 404" with OpenRouter

**Cause:** The selected model is no longer available on OpenRouter.

**Solution:**
1. Tap the model picker
2. Select a different model (try Xiaomi MiMo-V2-Flash or Google Gemini)
3. Send your message again

### "Connection Failed" with Local Ollama

**Possible Causes:**
1. Ollama is not running
2. Wrong IP address
3. Firewall blocking connection
4. Not on same network

**Solutions:**
1. Run `ollama serve` in Terminal
2. Verify your IP address in System Settings
3. Check firewall settings
4. Ensure iPhone and computer are on same Wi-Fi

### "Invalid API Key"

**Solution:**
1. Verify your API key is correct
2. Check if the key has been revoked
3. Generate a new key if needed
4. Re-enter the key and tap **Save**

### Messages Not Sending

**Check:**
1. Provider is selected (not just configured)
2. Model is selected
3. Internet connection is working
4. API key is valid

---

## Tips & Tricks

### Using Free Models on OpenRouter
1. Enable **"Prefer Free Models"** in OpenRouter settings
2. This automatically appends `:free` to model requests
3. Free models have usage limits but work for most tasks

### Getting Better Responses
- Be specific in your questions
- Provide context when needed
- Use follow-up questions to refine answers

### Saving Money on OpenRouter
- Enable "Prefer Free Models"
- Use smaller/faster models for simple tasks
- Set spending limits on your OpenRouter account

### Offline Usage with Local Ollama
- Pull models ahead of time: `ollama pull llama3.2`
- Once downloaded, models work without internet
- Great for privacy-sensitive conversations

---

## FAQ

**Q: Is my data stored anywhere?**
A: Conversations are stored locally on your device. API keys are stored securely in iOS Keychain. No data is sent to OllamaRemote servers.

**Q: Which provider should I use?**
A:
- **OpenRouter** - Best for most users (easy setup, many models, free options)
- **Local Ollama** - Best for privacy (runs on your computer)
- **Ollama Cloud** - Best for remote access to your models

**Q: Why do some models cost money on OpenRouter?**
A: OpenRouter aggregates many AI providers. Some models are free, others have per-token costs. Enable "Prefer Free Models" to avoid charges.

**Q: Can I use multiple providers?**
A: Yes! Configure all your providers in Settings. Switch between them using the provider dropdown in any conversation.

**Q: Does the app work offline?**
A: Only with Local Ollama and downloaded models. OpenRouter and Ollama Cloud require internet.

---

## Need More Help?

- **Report Issues:** [GitHub Issues](https://github.com/ricyoung/OllamaRemote/issues)
- **Feature Requests:** [GitHub Issues](https://github.com/ricyoung/OllamaRemote/issues)
- **Source Code:** [GitHub Repository](https://github.com/ricyoung/OllamaRemote)

---

*OllamaRemote is developed by [Richard Young](https://deepneuro.ai/richard)*
