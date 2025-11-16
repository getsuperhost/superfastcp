#!/usr/bin/env bash
set -euo pipefail

# Helper script to install the GitHub Copilot CLI safely.
NODE_MIN=22

echo "Checking Node.js version..."
NODE_VER=$(node -v 2>/dev/null || echo "")
if [ -z "$NODE_VER" ]; then
  echo "Node.js is not installed or not in PATH. Please install Node.js >= $NODE_MIN or use nvm (https://github.com/nvm-sh/nvm)."
  exit 1
fi

NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v\([0-9]*\)\..*/\1/')
if [ "$NODE_MAJOR" -lt "$NODE_MIN" ]; then
  echo "Detected Node.js $NODE_VER; GitHub Copilot CLI requires Node >= $NODE_MIN."
  echo "Suggested: install nvm and run\n  nvm install $NODE_MIN && nvm use $NODE_MIN\nthen re-run this script"
  exit 1
fi

echo "Node.js version OK ($NODE_VER)."

if [ "$EUID" -eq 0 ]; then
  echo "Running as root — attempting global npm install..."
  npm install -g @github/copilot
else
  if [ -w "$(npm root -g)" ]; then
    echo "Installing Copilot CLI globally (no sudo required)..."
    npm install -g @github/copilot
  else
    echo "Global npm directory requires elevated permissions."
    echo "Using sudo to install globally (you will be prompted for your password)."
    sudo npm install -g @github/copilot
  fi
fi

echo "Installation finished. Run 'copilot --version' to verify."

exit 0
