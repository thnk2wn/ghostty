#!/bin/bash
# Migrate API keys from environment variables to macOS Keychain for Geofftty
#
# Run this script from a terminal where your API keys are set as environment
# variables (e.g., in your .zprofile or .zshrc). The keys will be saved to
# Keychain so they work when launching the app from Finder or Spotlight.

SERVICE="com.geofftty.ai"
MIGRATED=0

if [ -n "$OPENAI_API_KEY" ]; then
    security add-generic-password -s "$SERVICE" -a "openai" -w "$OPENAI_API_KEY" -U 2>/dev/null
    echo "✓ Saved OpenAI key to Keychain"
    MIGRATED=$((MIGRATED + 1))
fi

if [ -n "$ANTHROPIC_API_KEY" ]; then
    security add-generic-password -s "$SERVICE" -a "anthropic" -w "$ANTHROPIC_API_KEY" -U 2>/dev/null
    echo "✓ Saved Anthropic key to Keychain"
    MIGRATED=$((MIGRATED + 1))
fi

if [ $MIGRATED -eq 0 ]; then
    echo "No API keys found in environment."
    echo "Set OPENAI_API_KEY or ANTHROPIC_API_KEY and run again."
    exit 1
fi

echo ""
echo "Done! Restart Geofftty to use the saved keys."
