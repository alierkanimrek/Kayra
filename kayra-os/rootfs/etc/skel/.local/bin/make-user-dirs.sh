# 1. Ana dizinleri oluştur
mkdir -p ~/Workspace/{code/docker-stacks,writing,music,design,content,research}
mkdir -p ~/Resources/{fonts,templates,presets,virt/{isos,disks},images,vectors,audio,video,documents,3d,daw}
mkdir -p ~/Exports/{software,documents,audio,graphics,videos}
mkdir -p ~/{Documents,Music,Pictures,Videos,Public}

# 2. Eski Downloads içeriğini Resources'a taşı ve sembolik bağ kur
if [ -d ~/Downloads ] && [ ! -L ~/Downloads ]; then
    cp -rn ~/Downloads/* ~/Resources/ 2>/dev/null || true
    rm -rf ~/Downloads
fi
ln -s ~/Resources ~/Downloads
