#!/bin/bash

echo "📦 Installing timeout command for macOS..."

# Check if Homebrew is installed
if command -v brew >/dev/null 2>&1; then
    echo "✅ Homebrew found, installing coreutils..."
    brew install coreutils
    echo "✅ timeout command installed!"
    echo "💡 You can now use 'gtimeout' or add /usr/local/bin to your PATH for 'timeout'"
else
    echo "❌ Homebrew not found"
    echo "💡 Install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo "💡 Then run: brew install coreutils"
fi