#!/bin/bash
FLAG="$HOME/.config/kayra/.firstlogin"
if [ -f "$FLAG" ]; then
    "$HOME/.local/bin/make-user-dirs.sh"
    rm -f "$FLAG"
fi
