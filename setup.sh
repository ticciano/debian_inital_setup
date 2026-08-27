#!/bin/bash

# Cores ANSI
RESET="\033[0m"
WHITE="\033[1;37m"
GREEN="\033[1;32m"
RED="\033[1;31m"

# Interrompe o script se houver erros em comandos críticos
set -e

# Função para exibir progresso com pontos simulados (Sintaxe Clássica e Segura)
executar_com_progresso() {
    local mensagem="$1"
    shift
    # Executa o comando em segundo plano e esconde a saída
    "$@" >/dev/null 2>&1 &
    local pid=$!

    # Mostra a mensagem inicial em branco
    echo -ne "${WHITE}${mensagem}...${RESET}"

    # Enquanto o processo estiver rodando, adiciona pontos na tela
    while kill -0 $pid 2>/dev/null; do
        echo -ne "${WHITE}.${RESET}"
        sleep 1
    done

    # Aguarda o processo terminar de fato para capturar o status de saída
    wait $pid
    local status=$?

    if [ $status -eq 0 ]; then
        echo -e " [${GREEN}OK${RESET}]"
    else
        echo -e " [${RED}FALHA${RESET}]"
        exit 1
    fi
}

# --- Início da Execução ---

# Detecção silenciosa de compatibilidade
if [ -f /etc/upstream-release/lsb-release ]; then
    UBUNTU_CODENAME=$(grep "DISTRIB_CODENAME=" /etc/upstream-release/lsb-release | cut -d= -f2)
fi
if [ -z "$UBUNTU_CODENAME" ]; then
    UBUNTU_CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME}")
fi
if [ -z "$UBUNTU_CODENAME" ]; then
    UBUNTU_CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME}")
fi
UBUNTU_CODENAME=$(echo "$UBUNTU_CODENAME" | tr -d '"')

# Solicita a senha do sudo logo no início para não quebrar a animação visual depois
sudo -v

executar_com_progresso "Atualizando índices de pacotes" \
    sudo apt update -y

executar_com_progresso "Instalando ferramentas básicas e dependências" \
    sudo apt install -y vim terminator python3 zsh curl git fzf nmap btop copyq flameshot bc

executar_com_progresso "Removendo pacotes desnecessários" \
    bash -c "sudo apt remove -y libreoffice-base-core libreoffice-core cheese brasero shotwell transmission-common gnome-games || true"

executar_com_progresso "Limpando dependências órfãs" \
    sudo apt autoremove -y

#-----------------------------------------------------------------------------------------------------------
# vscode
read -p "$(echo -e ${WHITE}"Deseja instalar o VS Code? (Y/n): "${RESET})" install_vscode
install_vscode=${install_vscode:-Y}
if [[ "$install_vscode" =~ ^[Yy]$ ]]; then
    executar_com_progresso "Configurando repositório do VS Code" bash -c "
        sudo apt install -y wget gpg apt-transport-https && \
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && \
        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg && \
        echo 'deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main' | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null && \
        rm -f packages.microsoft.gpg && \
        sudo apt update -y
    "
    executar_com_progresso "Instalando VS Code" \
        sudo apt install -y code
fi

#-----------------------------------------------------------------------------------------------------------
# insync
read -p "$(echo -e ${WHITE}"Deseja instalar o Insync? (Y/n): "${RESET})" install_insync
install_insync=${install_insync:-Y}
if [[ "$install_insync" =~ ^[Yy]$ ]]; then
    executar_com_progresso "Configurando chaves e repositório Insync ($UBUNTU_CODENAME)" bash -c "
        curl -L https://apt.insync.io/insynchq.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/insynchq.gpg > /dev/null && \
        echo \"deb [signed-by=/etc/apt/trusted.gpg.d/insynchq.gpg] http://apt.insync.io/ubuntu $UBUNTU_CODENAME non-free contrib\" | sudo tee /etc/apt/sources.list.d/insync.list > /dev/null && \
        sudo apt update -y
    "
    executar_com_progresso "Instalando Insync" \
        sudo apt install -y insync
fi

#-----------------------------------------------------------------------------------------------------------
# docker
read -p "$(echo -e ${WHITE}"Deseja instalar o Docker? (Y/n): "${RESET})" install_docker
install_docker=${install_docker:-Y}
if [[ "$install_docker" =~ ^[Yy]$ ]]; then
    executar_com_progresso "Configurando chaves e repositório Docker ($UBUNTU_CODENAME)" bash -c "
        sudo apt install -y ca-certificates curl && \
        sudo install -m 0755 -d /etc/apt/keyrings && \
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
        sudo chmod a+r /etc/apt/keyrings/docker.asc && \
        echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $UBUNTU_CODENAME stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
        sudo apt update -y
    "
    executar_com_progresso "Instalando Docker Engine" \
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
    executar_com_progresso "Inicializando serviços do Docker" bash -c "
        sudo systemctl enable docker || true && \
        sudo systemctl start docker || true
    "
fi

#-----------------------------------------------------------------------------------------------------------
# flatpak & obsidian
read -p "$(echo -e ${WHITE}"Deseja instalar o Flatpak e pacotes Flathub? (Y/n): "${RESET})" install_flatpak
install_flatpak=${install_flatpak:-Y}
if [[ "$install_flatpak" =~ ^[Yy]$ ]]; then
    executar_com_progresso "Configurando ambiente Flatpak" bash -c "
        (sudo apt install -y flatpak gnome-software-plugin-flatpak || sudo apt install -y flatpak) && \
        sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    "
    executar_com_progresso "Instalando Obsidian (Flatpak)" \
        flatpak install --user -y flathub md.obsidian.Obsidian
        
    executar_com_progresso "Instalando OnlyOffice (Flatpak)" \
        flatpak install --user -y flathub org.onlyoffice.desktopeditors
        
    executar_com_progresso "Instalando Bitwarden (Flatpak)" \
        flatpak install --user -y flathub com.bitwarden.desktop
    
    executar_com_progresso "Instalando Vivaldi (Flatpak)" \
        flatpak install --user -y flathub com.vivaldi.Vivaldi
fi

#-----------------------------------------------------------------------------------------------------------
# oh-my-zsh e Tema Passion
executar_com_progresso "Baixando e instalando Oh My Zsh" bash -c "
    rm -rf \$HOME/.oh-my-zsh && \
    ZSH= sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended
"

executar_com_progresso "Baixando o tema Passion" bash -c "
    TEMP_DIR=\$(mktemp -d) && \
    git clone https://github.com/ChesterYue/ohmyzsh-theme-passion \"\$TEMP_DIR/ohmyzsh-theme-passion\" && \
    cp \"\$TEMP_DIR/ohmyzsh-theme-passion/passion.zsh-theme\" \"\$HOME/.oh-my-zsh/themes/passion.zsh-theme\" && \
    rm -rf \"\$TEMP_DIR\"
"

executar_com_progresso "Aplicando tema Passion no ~/.zshrc" bash -c "
    if [ -f \"\$HOME/.zshrc\" ]; then \
        sed -i 's/^ZSH_THEME=\".*\"/ZSH_THEME=\"passion\"/' \"\$HOME/.zshrc\"; \
    fi

    sudo chsh -s $(which zsh)
"

echo -e "\n${GREEN}Script finalizado com sucesso!${RESET} Abra um novo terminal para usar o Zsh com o tema Passion."
