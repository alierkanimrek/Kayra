#!/bin/bash
#
# kayra-make-user-dirs.sh - Create the Kayra OS home directory layout.
#
# Creates the standard user directories and points ~/Downloads to ~/Resources.
# An existing real ~/Downloads is merged without overwriting anything: entries
# that do not collide move into ~/Resources, and entries that collide (hidden
# files included) stay in the directory, which is then moved as a whole to
# ~/Resources/Downloads (or ~/Resources/Downloads.<n> when that name is taken).
# Nothing is deleted until every entry has been accounted for.
# It is idempotent and runs on the first login.
#
# Usage: kayra-make-user-dirs.sh
#
# Used commands: mkdir, mv, rmdir, ln, printf
#
set -uo pipefail
export LC_ALL=C.UTF-8

# 1. Create the main directories
mkdir -p ~/Workspace/{code/docker-stacks,writing,music,design,content,research}
mkdir -p ~/Resources/{fonts,templates,presets,virt/{isos,disks},images,vectors,audio,video,documents,3d,daw}
mkdir -p ~/Exports/{software,documents,audio,graphics,videos}
mkdir -p ~/{Documents,Music,Pictures/screenshots,Videos,Public}

# 2. Merge the old Downloads content into Resources and link it back.
#    A missing target is moved; a colliding one is left in place so the whole
#    directory can be preserved under ~/Resources/Downloads afterwards.
src=$HOME/Downloads
dst=$HOME/Resources

if [ -d "$src" ] && [ ! -L "$src" ]; then
    shopt -s nullglob dotglob
    failed=0

    for entry in "$src"/*; do
        name=${entry##*/}
        target=$dst/$name
        if [ -e "$target" ] || [ -L "$target" ]; then
            continue
        fi
        mv -- "$entry" "$target" || {
            printf 'kayra-make-user-dirs: cannot move %s\n' "$entry" >&2
            failed=1
        }
    done

    remaining=("$src"/*)
    if [ "${#remaining[@]}" -gt 0 ]; then
        target=$dst/Downloads
        n=1
        while [ -e "$target" ] || [ -L "$target" ]; do
            target=$dst/Downloads.$n
            n=$((n + 1))
        done
        if mv -- "$src" "$target"; then
            printf 'kayra-make-user-dirs: collisions preserved in %s\n' "$target" >&2
        else
            printf 'kayra-make-user-dirs: cannot move %s, kept in place\n' "$src" >&2
            failed=1
        fi
    elif [ "$failed" -eq 0 ]; then
        rmdir -- "$src" 2>/dev/null || failed=1
    fi
fi

# 3. Point ~/Downloads at ~/Resources. Never create a link inside a real
#    directory that could not be migrated.
if [ -L "$HOME/Downloads" ] || [ ! -e "$HOME/Downloads" ]; then
    ln -sfn "$HOME/Resources" "$HOME/Downloads"
elif [ -d "$HOME/Downloads" ]; then
    printf 'kayra-make-user-dirs: %s was not migrated, no link created\n' "$HOME/Downloads" >&2
fi
