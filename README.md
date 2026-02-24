# MoneyClaw

Sovereign AI agent runtime with survival economics, tool execution, model routing, and self-operation capabilities.

中文文档: `README.zh-CN.md`

## Table of Contents

- Overview
- Requirements
- Installation
- Quick Start
- CLI Commands
- Configuration
- Model Management (Dynamic Discovery + Cache)
- Typical Workflows
- Development
- Troubleshooting
- Security Notes
- License

## Overview

MoneyClaw is a long-running autonomous agent runtime. It can:

- maintain persistent state in SQLite
- execute tools and heartbeat tasks
- route inference by survival tier and policy
- manage model providers (Conway, OpenAI-compatible, Anthropic-compatible, Ollama)
- discover models dynamically from provider APIs and cache them locally

## Requirements

- Node.js `>= 20`
- npm or pnpm
- Linux/macOS recommended

## Installation

```bash
git clone https://github.com/cat9999aaa/moneyclaw.git
cd moneyclaw
npm install
npm run build
```

## Quick Start

Run first-time setup and start runtime:

```bash
node dist/index.js --run
```

Useful first-run flow:

1. wallet and identity are prepared
2. setup wizard asks for API keys and optional provider base URLs
3. config is saved to `~/.automaton/automaton.json`
4. runtime starts with heartbeat + agent loop

## CLI Commands

Main binary command in this repo is `automaton` (after install/build in your environment).

You can also call the built entry directly:

```bash
node dist/index.js --help
```

Available commands:

- `automaton --run` start runtime
- `automaton --setup` re-run setup wizard
- `automaton --configure` edit config interactively
- `automaton --pick-model` pick active model interactively
- `automaton --init` initialize wallet/config directory
- `automaton --provision` provision Conway API key via SIWE
- `automaton --status` show current runtime status
- `automaton --version` show version

## Configuration

Default config file:

- `~/.automaton/automaton.json`

Key fields:

- `conwayApiUrl`
- `conwayApiKey`
- `openaiApiKey`
- `openaiBaseUrl`
- `anthropicApiKey`
- `anthropicBaseUrl`
- `ollamaBaseUrl`
- `inferenceModel`
- `modelStrategy`

Environment variable overrides:

- `CONWAY_API_URL`
- `CONWAY_API_KEY`
- `OPENAI_BASE_URL`
- `ANTHROPIC_BASE_URL`
- `OLLAMA_BASE_URL`

## Model Management (Dynamic Discovery + Cache)

MoneyClaw supports dynamic model discovery from provider APIs.

### Data Sources

- OpenAI-compatible: `GET {baseUrl}/v1/models`
- Anthropic-compatible: `GET {baseUrl}/v1/models`
- Ollama: `GET {baseUrl}/api/tags`

### Cache

Discovered models are upserted into SQLite `model_registry` and reused by model picker/routing.

### How to refresh model list

Option A (interactive picker):

```bash
node dist/index.js --pick-model
```

Option B (configure menu):

```bash
node dist/index.js --configure
```

Both flows trigger provider discovery and then show current available models.

### Important Notes

- If provider key is missing, discovery for that provider may be skipped (depends on provider/auth requirement).
- If discovery fails, MoneyClaw logs warnings and continues (soft-fail behavior).
- If you changed code, always run `npm run build` before using `node dist/index.js ...`.

## Typical Workflows

### 1) Set custom API base URL and use provider models

```bash
node dist/index.js --configure
node dist/index.js --pick-model
```

In configure:

- set `OpenAI API key` + `OpenAI base URL`
- set `Anthropic API key` + `Anthropic base URL`
- optionally set `Ollama base URL`

Then pick a discovered model from the refreshed list.

### 2) Check runtime status

```bash
node dist/index.js --status
```

Shows name, wallet, state, turn count, active model, and more.

### 3) Re-run setup safely

```bash
node dist/index.js --setup
```

Use this when moving environments or rotating credentials.

## Development

Install and build:

```bash
npm install
npm run build
```

Run tests:

```bash
npm test
```

Run in dev mode:

```bash
npm run dev
```

## Troubleshooting

### Model list does not match your custom provider

Checklist:

1. run `npm run build` first
2. confirm API key + base URL in `--configure`
3. run `node dist/index.js --pick-model`
4. check logs for discovery warnings

### `--pick-model` only shows preset models

Common causes:

- stale `dist` (not rebuilt)
- missing provider API key
- provider endpoint/auth rejected request

### Push fails with GitHub 403

- verify token scope includes repository write permissions
- verify remote URL points to your writable repository

## Security Notes

- Never commit secrets in config files.
- Prefer environment variables for production credentials.
- Review tool permissions and financial policy before running unattended.

## License

MIT
