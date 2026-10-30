#!/usr/bin/env bash
#
# template-lib.sh - Kayra OS template helper library (source it; do not execute it).
#
# Provides template_replace(), which substitutes a placeholder inside a
# template text and prints the modified text back.
#
# Usage in a script:
#   source "$(dirname "$0")/template-lib.sh"
#   text="$(template_replace "$template_text" "{{LOGIN}}" "Log in")"
#   text="$(template_replace "$template_text" "LOGIN" "Log in")"   # braces added
#
# template_replace <template_text> <placeholder> <replacement>
#   Prints <template_text> where every occurrence of <placeholder> is
#   replaced by <replacement>.
#   * The placeholder is matched literally (no glob, no regex).
#   * All occurrences are replaced, not only the first one.
#   * A placeholder given without braces ("NAME") is treated as "{{NAME}}",
#     so both styles used by the config templates work.
#   * Backslashes in <replacement> are kept literal (useful for paths).
#   * The modified text is printed to stdout, so the function is used in
#     command substitution.
#

export LC_ALL=C.UTF-8

template_replace() {
    local template_text="$1"
    local placeholder="$2"
    local replacement="$3"

    # Without a placeholder there is nothing to replace.
    if [[ -z "$placeholder" ]]; then
        printf '%s\n' "$template_text"
        return 0
    fi

    # Accept both "NAME" and "{{NAME}}" style placeholders.
    if [[ "$placeholder" != *"{{"* ]]; then
        placeholder="{{$placeholder}}"
    fi

    # Escape backslashes in the replacement so bash keeps them literal.
    local replacement_escaped="${replacement//\\/\\\\}"

    # Quoted placeholder -> literal match, no pattern interpretation.
    printf '%s\n' "${template_text//"$placeholder"/$replacement_escaped}"
}
