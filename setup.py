import os
import sys
import subprocess
import threading
import customtkinter as ctk

# Configuração inicial do tema da janela
ctk.set_appearance_mode("System")
ctk.set_default_color_theme("blue")

class SetupApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("Ubuntu & Derivates Initial Setup")
        self.geometry("550x650")
        self.resizable(False, False)

        # Variáveis de detecção
        self.ubuntu_codename = self.detect_ubuntu_codename()

        # Variáveis de controle dos Checkboxes
        self.var_basics = ctk.BooleanVar(value=True)
        self.var_vscode = ctk.BooleanVar(value=True)
        self.var_insync = ctk.BooleanVar(value=True)
        self.var_docker = ctk.BooleanVar(value=True)
        self.var_flatpak = ctk.BooleanVar(value=True)
        self.var_zsh = ctk.BooleanVar(value=True)

        self.create_widgets()

    def detect_ubuntu_codename(self):
        """Mapeia dinamicamente a base Ubuntu igual ao seu script em Bash"""
        codename = ""
        if os.path.exists("/etc/upstream-release/lsb-release"):
            with open("/etc/upstream-release/lsb-release", "r") as f:
                for line in f:
                    if "DISTRIB_CODENAME=" in line:
                        codename = line.strip().split("=")[1]
        if not codename and os.path.exists("/etc/os-release"):
            with open("/etc/os-release", "r") as f:
                env = {}
                for line in f:
                    if "=" in line:
                        k, v = line.strip().split("=", 1)
                        env[k] = v.strip('"')
                codename = env.get("UBUNTU_CODENAME", env.get("VERSION_CODENAME", ""))
        return codename.strip()

    def create_widgets(self):
        # Título Principal
        self.title_label = ctk.CTkLabel(self, text="Instalador do Sistema", font=ctk.CTkFont(size=20, weight="bold"))
        self.title_label.pack(pady=20)

        # Informação do sistema detectado
        self.info_label = ctk.CTkLabel(self, text=f"Base Ubuntu Detectada: {self.ubuntu_codename.upper()}", font=ctk.CTkFont(size=12))
        self.info_label.pack(pady=5)

        # Container dos Checkboxes
        self.checkbox_frame = ctk.CTkFrame(self)
        self.checkbox_frame.pack(pady=20, padx=40, fill="both", expand=True)

        ctk.CTkCheckBox(self.checkbox_frame, text="Ferramentas Básicas (Vim, Terminator, btop...)", variable=self.var_basics).pack(pady=10, anchor="w", padx=20)
        ctk.CTkCheckBox(self.checkbox_frame, text="Visual Studio Code", variable=self.var_vscode).pack(pady=10, anchor="w", padx=20)
        ctk.CTkCheckBox(self.checkbox_frame, text="Insync (Google Drive/OneDrive Client)", variable=self.var_insync).pack(pady=10, anchor="w", padx=20)
        ctk.CTkCheckBox(self.checkbox_frame, text="Docker Engine & Docker Compose", variable=self.var_docker).pack(pady=10, anchor="w", padx=20)
        ctk.CTkCheckBox(self.checkbox_frame, text="Flatpak + Apps (Obsidian, OnlyOffice, Bitwarden)", variable=self.var_flatpak).pack(pady=10, anchor="w", padx=20)
        ctk.CTkCheckBox(self.checkbox_frame, text="Oh My Zsh + Tema Passion", variable=self.var_zsh).pack(pady=10, anchor="w", padx=20)

        # Label de Status da Instalação
        self.status_label = ctk.CTkLabel(self, text="Aguardando início...", font=ctk.CTkFont(size=13, weight="bold"), text_color="gray")
        self.status_label.pack(pady=10)

        # Barra de Progresso Indeterminada
        self.progress_bar = ctk.CTkProgressBar(self, width=400)
        self.progress_bar.pack(pady=10)
        self.progress_bar.set(0)

        # Botão de Execução
        self.start_button = ctk.CTkButton(self, text="Iniciar Instalação", command=self.start_installation_thread)
        self.start_button.pack(pady=20)

    def run_cmd(self, command):
        """Executa comandos ocultando a saída e validando erros"""
        try:
            subprocess.run(command, shell=True, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except subprocess.CalledProcessError:
            return False

    def start_installation_thread(self):
        # Desativa o botão e inicia a animação da barra de progresso
        self.start_button.configure(state="disabled")
        self.progress_bar.start()
        # Dispara o processo em uma Thread separada para não congelar a interface gráfica
        threading.Thread(target=self.install_process, daemon=True).start()

    def update_status(self, text, color="white"):
        self.status_label.configure(text=text, text_color=color)

    def install_process(self):
        # Força a autenticação do sudo gráfica ou via terminal antes de começar
        self.update_status("Solicitando credenciais sudo de administrador...", "orange")
        if not self.run_cmd("sudo -v"):
            self.update_status("Falha: Acesso administrativo (Sudo) recusado.", "red")
            self.reset_ui()
            return

        # 1. Ferramentas Básicas e Limpeza
        if self.var_basics.get():
            self.update_status("Atualizando repositórios e instalando apps básicos...")
            self.run_cmd("sudo apt update -y && sudo apt install -y vim terminator python3 zsh curl git fzf nmap btop copyq flameshot bc")
            
            self.update_status("Removendo softwares desnecessários...")
            self.run_cmd("sudo apt remove -y libreoffice-base-core libreoffice-core cheese brasero shotwell transmission-common gnome-games || true")
            self.run_cmd("sudo apt autoremove -y")

        # 2. VS Code
        if self.var_vscode.get():
            self.update_status("Instalando Visual Studio Code...")
            vscode_cmd = (
                "sudo apt install -y wget gpg apt-transport-https && "
                "wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && "
                "sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg && "
                "echo 'deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main' | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null && "
                "rm -f packages.microsoft.gpg && "
                "sudo apt update -y && sudo apt install -y code"
            )
            self.run_cmd(vscode_cmd)

        # 3. Insync
        if self.var_insync.get():
            self.update_status("Instalando cliente Insync...")
            insync_cmd = (
                f"curl -L https://apt.insync.io/insynchq.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/insynchq.gpg > /dev/null && "
                f"echo 'deb [signed-by=/etc/apt/trusted.gpg.d/insynchq.gpg] http://apt.insync.io/ubuntu {self.ubuntu_codename} non-free contrib' | sudo tee /etc/apt/sources.list.d/insync.list > /dev/null && "
                f"sudo apt update -y && sudo apt install -y insync"
            )
            self.run_cmd(insync_cmd)

        # 4. Docker
        if self.var_docker.get():
            self.update_status("Configurando e instalando Docker Engine...")
            docker_cmd = (
                "sudo apt install -y ca-certificates curl && "
                "sudo install -m 0755 -d /etc/apt/keyrings && "
                "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && "
                "sudo chmod a+r /etc/apt/keyrings/docker.asc && "
                f"echo 'deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu {self.ubuntu_codename} stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && "
                "sudo apt update -y && "
                "sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && "
                "sudo systemctl enable docker || true && sudo systemctl start docker || true"
            )
            self.run_cmd(docker_cmd)

        # 5. Flatpak
        if self.var_flatpak.get():
            self.update_status("Configurando Flatpak e instalando Apps (Obsidian)...")
            flatpak_cmd = (
                "(sudo apt install -y flatpak gnome-software-plugin-flatpak || sudo apt install -y flatpak) && "
                "sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && "
                "flatpak install -y flathub md.obsidian.Obsidian && "
                "flatpak install -y flathub org.onlyoffice.desktopeditors && "
                "flatpak install -y flathub com.bitwarden.desktop"
            )
            self.run_cmd(flatpak_cmd)

        # 6. Oh My Zsh e Passion
        if self.var_zsh.get():
            self.update_status("Configurando Oh My Zsh e Tema Passion...")
            zsh_cmd = (
                "rm -rf $HOME/.oh-my-zsh && "
                "ZSH= sh -c \"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended && "
                "TEMP_DIR=$(mktemp -d) && "
                "git clone https://github.com/ChesterYue/ohmyzsh-theme-passion \"$TEMP_DIR/ohmyzsh-theme-passion\" && "
                "cp \"$TEMP_DIR/ohmyzsh-theme-passion/passion.zsh-theme\" \"$HOME/.oh-my-zsh/themes/passion.zsh-theme\" && "
                "rm -rf \"$TEMP_DIR\" && "
                "if [ -f \"$HOME/.zshrc\" ]; then sed -i 's/^ZSH_THEME=\".*\"/ZSH_THEME=\"passion\"/' \"$HOME/.zshrc\"; fi"
            )
            self.run_cmd(zsh_cmd)

        self.update_status("Instalação Concluída com Sucesso!", "green")
        self.reset_ui()

    def reset_ui(self):
        self.progress_bar.stop()
        self.progress_bar.set(1)
        self.start_button.configure(state="normal")

if __name__ == "__main__":
    # Garante que o app só rode no Linux
    if not sys.platform.startswith("linux"):
        print("Este aplicativo só funciona em distribuições Linux.")
        sys.exit(1)
    
    app = SetupApp()
    app.mainloop()
