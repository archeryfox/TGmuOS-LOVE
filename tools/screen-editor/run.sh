#!/bin/sh
# Build and run the Telegram screen editor (egui desktop app)
cd "$(dirname "$0")" || exit 1
if [ ! -x target/release/screen-editor ]; then
    echo "Building screen-editor..."
    cargo build --release || exit 1
fi
exec ./target/release/screen-editor