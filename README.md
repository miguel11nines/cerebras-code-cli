<p align="center">
  <img src="assets/cerebras-logo.png" alt="Cerebras" width="400">
</p>

<h1 align="center">Cerebras Code CLI</h1>

<p align="center"><strong>The blazing-fast AI coding agent for the terminal — powered by Cerebras inference.</strong></p>

<p align="center">
  <em>Fork of <a href="https://github.com/sst/opencode">OpenCode</a>, adapted for Cerebras's fast inference.</em>
</p>

---

## Features

- ⚡ **Instant responses** — Cerebras inference in milliseconds
- 🖥️ **Terminal-native** — Full TUI with session management
- 🔧 **Coding agent** — File editing, bash commands, code analysis
- 📊 **Cache monitoring** — Real-time hit rate with sparklines and alerts
- 🔌 **LSP & MCP** — Language server and Model Context Protocol support

---

## Setting Up Your Account

Before you install the CLI, you will need:

1. A **Cerebras account**
2. An **API key**

### Creating Your Account

If you do not already have one, sign up for an account at [cloud.cerebras.ai](https://cloud.cerebras.ai).

### Getting Your API Key

1. Log into [cloud.cerebras.ai](https://cloud.cerebras.ai)
2. Go to **"API keys"**
3. Copy your **"Default"** key or create a new one

---

## Installation

### Prerequisites

- **Node.js** — install with `brew install node` if you don't already have it
- **Bun** — install with `curl -fsSL https://bun.com/install | bash`

### Install the CLI

```bash
npm install -g cerebras-cli
```

> [!TIP]
> Remove versions older than 0.1.x before installing.

### Connecting to Cerebras

Once inside the CLI:

1. Type `/connect`
2. Select **Cerebras** as your provider
3. Paste your Cerebras API key
4. Select your desired model

---

## Usage

Navigate to your project and start the CLI:

```bash
cd your-project
cerebras-cli
```

### Referencing Files

To modify specific files, reference them using `@`:

> **Example:** `Update @src/components/Button.tsx to support a disabled state`

This works similarly to attaching files in GitHub Copilot.

---

## Agents

The Cerebras Code CLI includes three agents. Switch modes by pressing `Tab`.

### Plan

Creates a structured implementation plan **without modifying code**.

Use Plan mode when you're exploring approaches or deciding how to implement something. Think of this as a consultant that will leave you with a plan to execute.

> **Example:** `Add user authentication using JWT to this project`

### Build

Executes a specific implementation and **modifies code directly**.

Use Build mode when you know exactly what change you want to make. Perfect for simple, specific tasks where you just want it to follow instructions or execute a plan.

> **Example:** `Add a disabled state to @src/components/Button.tsx`

### Ralph

Combines planning and execution. **Automatically creates and executes plans.**

Use Ralph mode for larger tasks — starting a project or building a complex feature. You can see the plans and task lists it creates so you understand why it builds what it builds.

> **Example:** `Add dark mode support across the application`

> [!TIP]
> Use `git status` to see which files have changed so you can further inspect them in your IDE.

---

## Zed (ACP)

If you're using this fork as `cerebras`, you can run the built-in ACP server and connect it to Zed:

```json
{
  "agent_servers": {
    "Cerebras CLI": {
      "type": "custom",
      "command": "cerebras",
      "args": ["acp"]
    }
  }
}
```

---

## Development

```bash
git clone https://github.com/kevint-cerebras/cerebras-code-cli.git
cd cerebras-code-cli
bun install
bun dev
```

---

## Team

Kevin · Isaac · Daniel · Pearl

---

<p align="center"><strong>Built with ⚡ by Cerebras</strong></p>
