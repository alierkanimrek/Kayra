#!/bin/bash
FLAG="$HOME/.config/kayra/.firstlogin"
if [ -f "$FLAG" ]; then
    "$HOME/.local/bin/make-user-dirs.sh"
    [ -x /usr/local/bin/kayra-set-language.sh ] && /usr/local/bin/kayra-set-language.sh $(locale | grep LANG= | cut -d= -f2 | cut -d_ -f1)
    rm -f "$FLAG"
fi
