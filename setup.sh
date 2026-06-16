#!/bin/bash

# Interrompe o script se houver erros em comandos críticos
set -e

echo "Detectando compatibilidade de distribuição..."
# 1. Tenta ler o arquivo de upstream específico do Mint/Forks se ele existir
if [ -f /etc/upstream-release/lsb-release ]; then
    UBUNTU_CODENAME=$(grep "DISTRIB_CODENAME=" /etc/upstream-release/lsb-release | cut -d= -f2)
fi

# 2. Se falhar ou não existir (Ubuntu nativo ou Zorin), busca no os-release
if [ -z "$UBUNTU_CODENAME" ]; then
    # Tenta pegar a variável UBUNTU_CODENAME que o Zorin e Pop!_OS costumam injetar
    UBUNTU_CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME}")
fi

# 3. Fallback final: se ainda estiver vazio, usa o VERSION_CODENAME padrão do Ubuntu
if [ -z "$UBUNTU_CODENAME" ]; then
    UBUNTU_CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME}")
fi

# Limpa possíveis aspas que possam vir nos arquivos de configuração
UBUNTU_CODENAME=$(echo "$UBUNTU_CODENAME" | tr -d '"')

echo "Base Ubuntu detectada para repositórios: $UBUNTU_CODENAME"

echo "Atualizando índices de pacotes..."
sudo apt update -y

echo "Instalando ferramentas básicas (incluindo dependências do tema Passion)..."
sudo apt install -y \
vim terminator python3 \
zsh curl git fzf nmap btop \
copyq flameshot bc

echo "Removendo pacotes desnecessários (erros ignorados se não existirem)..."
# Usamos || true para evitar que o script pare caso o pacote não exista na derivada
sudo apt remove -y libreoffice-base-core libreoffice-core cheese brasero shotwell transmission-common || true
sudo apt remove --autoremove gnome-games -y || true

#-----------------------------------------------------------------------------------------------------------
# vscode
read -p "Deseja instalar o VS Code? (Y/n): " install_vscode
install_vscode=${install_vscode:-Y}
if [[ "$install_vscode" =~ ^[Yy]$ ]]; then
    echo "Instalando VS Code..."
    sudo apt install -y wget gpg apt-transport-https
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    rm -f packages.microsoft.gpg

    sudo apt update -y
    sudo apt install -y code
fi

#-----------------------------------------------------------------------------------------------------------
# docker
read -p "Deseja instalar o Docker? (Y/n): " install_docker
install_docker=${install_docker:-Y}
if [[ "$install_docker" =~ ^[Yy]$ ]]; then
    echo "Instalando Docker (Base Ubuntu: $UBUNTU_CODENAME)..."
    sudo apt install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $UBUNTU_CODENAME stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update -y
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    sudo systemctl enable docker || true
    sudo systemctl start docker || true
fi

#-----------------------------------------------------------------------------------------------------------
# flatpak & obsidian
read -p "Deseja instalar o Flatpak, Obsidian e demais apps? (Y/n): " install_flatpak
install_flatpak=${install_flatpak:-Y}
if [[ "$install_flatpak" =~ ^[Yy]$ ]]; then
    echo "Configurando Flatpak..."
    # Adicionado suporte para Mint/Zorin onde o plugin do gnome-software pode variar ou já vir instalado
    sudo apt install -y flatpak gnome-software-plugin-flatpak || sudo apt install -y flatpak
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    echo "Instalando aplicações Flatpak (Obsidian, OnlyOffice, Bitwarden)..."
    flatpak install -y flathub md.obsidian.Obsidian
    flatpak install -y flathub org.onlyoffice.desktopeditors
    flatpak install -y flathub com.bitwarden.desktop
fi

#-----------------------------------------------------------------------------------------------------------
# oh-my-zsh e Tema Passion
echo "Instalando Oh My Zsh..."
# Move a pasta antiga se existir
mv "$HOME/.oh-my-zsh" "$HOME/.old-oh-my-zsh"

# Executa o instalador limpando explicitamente a variável ZSH herdada da sessão ativa
ZSH= sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

echo "Instalando e configurando o tema Passion..."
# Garante que estamos trabalhando temporariamente fora do diretório de destino
TEMP_DIR=$(mktemp -d)
git clone https://github.com/ChesterYue/ohmyzsh-theme-passion "$TEMP_DIR/ohmyzsh-theme-passion"

# Copia o arquivo do tema para o diretório correto do Oh My Zsh
cp "$TEMP_DIR/ohmyzsh-theme-passion/passion.zsh-theme" "$HOME/.oh-my-zsh/themes/passion.zsh-theme"

# Limpa o diretório temporário utilizado no clone
rm -rf "$TEMP_DIR"

# Modifica o .zshrc alterando a linha do ZSH_THEME para "passion" via regex (sed)
if [ -f "$HOME/.zshrc" ]; then
    sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="passion"/' "$HOME/.zshrc"
    echo "Tema Passion configurado com sucesso no seu ~/.zshrc."
else
    echo "Aviso: ~/.zshrc não encontrado. O tema foi copiado, mas precisa ser ativado manualmente."
fi

echo "Script finalizado com sucesso! Para aplicar as mudanças do terminal, mude seu shell padrão ou reinicie a sessão."
