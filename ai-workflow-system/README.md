# AI Workflow System (Minimal)

## Setup

```bash
npm install
```

## Install OpenAI SDK

```bash
npm install openai
```

## Configure API key (recommended)

1. Copy the example file:

```bash
cp .env.example .env
```

2. Set your key in `.env`:

```bash
OPENAI_API_KEY=your_openai_api_key_here
```

3. Load env vars before running Node (bash/zsh):

```bash
set -a
source .env
set +a
node index.js
```
