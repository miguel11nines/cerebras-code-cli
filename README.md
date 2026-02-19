<p align="center">
  <img src="assets/cerebras-logo.png" alt="Cerebras" width="400">
</p>

<h1 align="center">Cerebras Code CLI</h1>

<p align="center"><strong>The blazing-fast AI coding agent for the terminal — powered by Cerebras inference.</strong></p>

<p align="center">
  <em>Fork of <a href="https://github.com/sst/opencode">OpenCode</a>, adapted for Cerebras's fast inference.</em>
</p>

---

### Installation

```bash
# YOLO
curl -fsSL https://raw.githubusercontent.com/kevint-cerebras/cerebras-code-cli/refs/heads/dev/install | bash

npm i -g cerebras-cli              # or bun/pnpm/yarn
```

### Zed (ACP)

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

> [!TIP]
> Remove versions older than 0.1.x before installing.

### Desktop App (BETA)

OpenCode is also available as a desktop application. Download directly from the [releases page](https://github.com/anomalyco/opencode/releases) or [opencode.ai/download](https://opencode.ai/download).

| Platform              | Download                              |
| --------------------- | ------------------------------------- |
| macOS (Apple Silicon) | `opencode-desktop-darwin-aarch64.dmg` |
| macOS (Intel)         | `opencode-desktop-darwin-x64.dmg`     |
| Windows               | `opencode-desktop-windows-x64.exe`    |
| Linux                 | `.deb`, `.rpm`, or AppImage           |

```bash
git clone https://github.com/kevint-cerebras/cerebras-code-cli.git
cd cerebras-code-cli
bun install
```

## Usage

```bash
bun dev
```

---

## Features

- ⚡ **Instant responses** — Cerebras inference in milliseconds
- 🖥️ **Terminal-native** — Full TUI with session management
- 🔧 **Coding agent** — File editing, bash commands, code analysis
- 📊 **Cache monitoring** — Real-time hit rate with sparklines and alerts
- 🔌 **LSP & MCP** — Language server and Model Context Protocol support

---

## Agents

Switch with `Tab`:

- **build** — Full access for development (default)
- **plan** — Read-only for analysis

---

## Team

Kevin · Isaac · Daniel · Arihant

---

<p align="center"><strong>Built with ⚡ by Cerebras</strong></p>
