#!/bin/bash
#
# kayra-make-user-dirs.sh - Create the Kayra OS home directory layout.
#
# Creates the standard user directories and points ~/Downloads to ~/Resources.
# It is idempotent and runs on the first login.
#
# Usage: kayra-make-user-dirs.sh
#
# Used commands: mkdir, cp, rm, ln
#
set -uo pipefail
export LC_ALL=C.UTF-8

# 1. Create the main directories
mkdir -p ~/Workspace/{code/docker-stacks,writing,music,design,content,research}
mkdir -p ~/Resources/{fonts,templates,presets,virt/{isos,disks},images,vectors,audio,video,documents,3d,daw}
mkdir -p ~/Exports/{software,documents,audio,graphics,videos}
mkdir -p ~/{Documents,Music,Pictures/screenshots,Videos,Public}

# 2. Move the old Downloads content into Resources and link it back
if [ -d ~/Downloads ] && [ ! -L ~/Downloads ]; then
    cp -rn ~/Downloads/* ~/Resources/ 2>/dev/null || true
    rm -rf ~/Downloads
fi
ln -sfn ~/Resources ~/Downloads
