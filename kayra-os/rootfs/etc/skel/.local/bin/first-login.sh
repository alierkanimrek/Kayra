#!/bin/bash
FLAG="$HOME/.config/kayra/.firstlogin"
if [ -f "$FLAG" ]; then
    "$HOME/.local/bin/make-user-dirs.sh"
    [ -x "$HOME/.local/bin/set-language.sh" ] && $HOME/.local/bin/set-language.sh $(locale | grep LANG= | cut -d= -f2 | cut -d_ -f1)
    rm -f "$FLAG"
fi
