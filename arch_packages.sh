#! /bin/sh

exec &> >(tee -a "output.log")

# ==================================== switch network ====================================
sudo pacman -Syu --noconfirm && sudo pacman -S --noconfirm networkmanager
sudo systemctl disable --now systemd-networkd
sudo systemctl disable --now systemd-resolved
sudo systemctl enable --now NetworkManager
INTERFACE=$(ip -o -4 route show default | awk '{print $5}' | head -n1)
sudo nmcli connection add type ethernet \
    con-name "$INTERFACE" \
    ifname ens32
sudo nmcli con mod "$INTERFACE" ipv4.method manual \
    ipv4.address 192.168.99.11/24 \
    ipv4.gateway 192.168.99.254 \
    ipv4.dns 114.114.114.114
sudo nmcli con up "$INTERFACE"

# ==================================== update && upgrade ====================================
sudo pacman -Syu --noconfirm

# ====================================   Install yay   =====================================
echo "===== Installing yay... ====="
sudo pacman -S --noconfirm --needed base-devel git wget curl
git clone https://aur.archlinux.org/yay.git || { echo "Failed to clone yay repository"; exit 1; }
cd yay || { echo "Failed to enter yay directory"; exit 1; }
makepkg -si
if [ $? -ne 0 ]; then
    echo "Failed to build and install yay"
    exit 1
fi
cd ..

# ==================================== Install packages ====================================
echo "===== Installing packages... ====="
sudo pacman -S --noconfirm openssh net-tools ufw \
    vim neovim \
    git lazygit \
    yazi \
    curl wget \
    ncdu duf tree \
    btop \
    fzf \
    bat

yay -S --noconfirm neofetch \
    kind-bin minikube \

git config --global user.name arch
git config --global user.email arch@arch.template

sudo ufw allow 22/tcp
sudo ufw enable

# ================================ fonts: 0xProtoNerdFontMono ================================
echo "===== Installing 0xProtoNerdFontMono font... ====="
curl --fail --show-error -LO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/0xProto.zip
sudo pacman -S --noconfirm unzip fontconfig
mkdir /tmp/fonts && unzip 0xProto.zip -d /tmp/fonts
sudo mkdir -p /usr/share/fonts && sudo cp -r /tmp/fonts/* /usr/share/fonts/
sudo fc-cache -fv
echo "0xProtoNerdFontMono font installed successfully. Cleaning up..."
rm -rf 0xProto.zip && rm -rf /tmp/fonts 

# ================================ grub_theme: Xenlism Grub Theme ================================
is_uefi() {
    [[ -d "/sys/firmware/efi/efivars" ]]
}
install_packages() {
    local pkgs=("grub")
    if is_uefi; then
        pkgs+=("efibootmgr")
    else
        pkgs+=("os-prober")
    fi

    echo -e "Installing dependencies:${pkgs[*]}"
    sudo pacman -Sy --noconfirm --needed "${pkgs[@]}"
}
install_grub_theme() {
    echo "===== Installing Xenlism Grub Theme...====="
    curl -LO https://raw.githubusercontent.com/xenlism/Grub-themes/refs/heads/main/xenlism-grub-arch-1080p.tar.xz
    tar -xvf xenlism-grub-arch-1080p.tar.xz
    cd xenlism-grub-arch-1080p && sudo sh ./install.sh
    cd ..
    echo "Xenlism Grub Theme installed successfully. Cleaning up..."
    rm -rf xenlism-grub-arch-1080p && rm -rf xenlism-grub-arch-1080p.tar.xz
}
if [[ -f /boot/grub/grub.cfg ]] && [[ ! -f /boot/grub2/grub.cfg ]]; then
    echo -e "GRUB is installed."
    install_grub_theme
else
    echo -e "GRUB is not installed."
    echo -e "Installing GRUB..."
    is_uefi && install_packages
    install_grub_theme
fi

# ==================================== Install Cockpit ====================================
echo "===== Installing Cockpit... ====="
sudo pacman -S --noconfirm cockpit cockpit-podman cockpit-machines cockpit-packagekit
sudo systemctl enable --now cockpit.socket
sudo ufw allow 9090/tcp

# ==================================== Install Docker ====================================
echo "===== Installing Docker... ====="
sudo pacman -S --noconfirm docker docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
echo "Docker installed successfully. Create docker configuration file..."
sudo mkdir -p /etc/docker
cat << 'EOF' | sudo tee /etc/docker/daemon.json
{
    "registry-mirrors": [
        "https://docker.1panel.live",
        "https://docker.mirrors.tuna.tsinghua.edu.cn",
        "https://mirror.gcr.io",
        "https://registry.docker-cn.com",
        "https://docker.mirrors.ustc.edu.cn"
    ]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
echo "===== start dpanel... ====="
sudo docker run -d --name dpanel --restart=always \
 -p 88:80 -p 443:443 -p 8807:8080 \
 -v /var/run/docker.sock:/var/run/docker.sock \
 -v /home/dpanel:/dpanel -e APP_NAME=dpanel dpanel/dpanel:latest
sudo docker ps -a | grep -aiE dpanel

# ==================================== Install Nginx ====================================
echo "===== Installing nginx... ====="
sudo pacman -S --noconfirm nginx
sudo systemctl start nginx
sudo systemctl enable nginx
sudo ufw allow http
sudo ufw allow https

# ==================================== Install FRP ====================================
echo "===== Installing FRP... ====="
yay -S --noconfirm frpc frps

# ==================================== Install zsh ====================================
echo "===== Installing zsh... ====="
sudo pacman -S --noconfirm zsh
chsh -s /bin/zsh

echo "Install zsh plugin: zsh-autosuggestions, zsh-syntax-highlighting, zsh-sudo"
git clone https://github.com/catppuccin/zsh-syntax-highlighting.git ~/.zsh/zsh-catppuccin || echo "Failed to clone catppuccin-zsh-theme repository"
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting || echo "Failed to clone zsh-syntax-highlighting repository"
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions || echo "Failed to clone zsh-autosuggestions repository"
git clone https://github.com/zap-zsh/sudo.git ~/.zsh/zsh-sudo || echo "Failed to clone zsh-sudo repository"

cat << 'EOF' > ~/.zshrc
# history settings
HISTFILE=~/.cache/zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_SPACE

# git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# git clone https://github.com/catppuccin/zsh-syntax-highlighting.git ~/.zsh/zsh-catppuccin
source ~/.zsh/zsh-catppuccin/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh
# git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
# git clone https://github.com/zap-zsh/sudo.git ~/.zsh/zsh-sudo
source ~/.zsh/zsh-sudo/sudo.plugin.zsh

alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias ls='LC_ALL=C ls -alh --group-directories-first --sort=name --color=auto'
alias grep='grep -iE --color=auto'
alias cat='bat'
alias v='nvim'
alias c='clear'
alias his='history'
alias df='df -h'
alias du='du -h'
# alias du='ncdu .'
alias free='free -h'
alias ..='cd ..'
alias ...='cd ../..'
alias ~='cd ~'

# starship
eval "$(starship init zsh)"

# >>> tmux >>>
# tmux sessions manage
alias tls='tmux ls'
alias tns='tmux new-session -d -t'
alias tks='tmux kill-session -t'
alias ta='tmux attach -t'
alias td='tmux detach'
# tmux windows manage
alias tnw='tmux new-window -n'
alias tkw='tmux kill-window -t'
alias tn='tmux next-window'
alias tp='tmux previous-window'
# tmux panes manage
alias th='tmux split-window -h'
alias tv='tmux split-window -v'
alias tsp='tmux select-pane -t'
alias tkp='tmux kill-pane'
# <<< tmux <<<
EOF

# ==================================== Install tmux ====================================
echo "===== Installing Tmux... ====="
sudo pacman -S --noconfirm tmux
cat << 'EOF' > ~/.tmux.conf
# ~/.tmux.conf
set -g default-command "exec zsh -l"
# set-option -g default-command "reattach-to-user-namespace -l $SHELL"

# keymaps
unbind C-b
set -g prefix `
bind ` send-prefix

# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'christoomey/vim-tmux-navigator'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'jimeh/tmuxifier'

# catppuccin theme
set -g @plugin "catppuccin/tmux"
set -g @catppuccin_flavour "mocha"

# non-plugin options
set -g default-terminal "tmux-256color"
set -g base-index 1
set -g pane-base-index 1
set -g renumber-windows on
set -g mouse on

# 更改复制模式的默认行为为熟悉的vi风格
# tmux中复制模式通常使用复制模式的步骤如下:
#   1. 输入 <[>      进入复制模式
#   2. 按下 <空格键> 开始复制，移动光标选择复制区域
#   3. 按下 <回车键> 复制选中文本并退出复制模式
#   4. 按下 <]>      粘贴文本
# 开启vi风格后, 支持vi的C-d、C-u、hjkl等快捷键
setw -g mode-keys vi

# Vim 风格的快捷键实现窗格间移动
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# visual mode
set-window-option -g mode-keys vi
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

# clipboard support
set -g set-clipboard on

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '~/.tmux/plugins/tpm/tpm'
EOF
echo "Install tmux plugin manager: tpm"
if git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm 2>/dev/null; then
    ~/.tmux/plugins/tpm/bin/install_plugins
else
    echo "Warning: TPM installation skipped (git clone failed)."
fi

# ==================================== Install starship ====================================
echo "===== Installing Starship... ====="
sudo pacman -S --noconfirm starship
starship preset catppuccin-powerline -o ~/.config/starship.toml
sed -i '/\[line_break\]/,/^$/ s/disabled = true/disabled = false/' ~/.config/starship.toml
echo "Starship installed successfully. Now you can use it by running 'starship init zsh' in your terminal."

# ==================================== Install wezterm ====================================
echo "===== Installing WezTerm... ====="
sudo pacman -S --noconfirm wezterm
touch ~/.config/wezterm/wezterm.lua
cat << 'EOF' > ~/.config/wezterm/wezterm.lua
-- Path: ~/.config/wezterm/wezterm.lua
-- github.com/riverify
-- This is a configuration file for wezterm, a GPU-accelerated terminal emulator for modern workflows.

local wezterm = require("wezterm")

config = wezterm.config_builder()

config = {
    automatically_reload_config = true,
    enable_tab_bar = true,
    hide_tab_bar_if_only_one_tab = true,    -- Hide the tab bar when there is only one tab
    window_close_confirmation = "NeverPrompt",
    window_decorations = "TITLE | RESIZE", -- disable the title bar but enable the resizable border
    font = wezterm.font("JetBrains Mono"),
    font_size = 18,
    color_scheme = "Nord (Gogh)",
    default_cursor_style = 'BlinkingBlock',
    macos_window_background_blur = 25, -- Enable window background blur on macOS
    background = {
        {
            source = {
                Color = "#222030", -- dark purple
            },
            width = "100%",
            height = "100%",
            opacity = 0.70,
        },
    },
    window_padding = {
        left = 3,
        right = 3,
        top = 0,
        bottom = 0,
    },
    initial_rows = 25,
    initial_cols = 100,
}

return config
EOF
echo "WezTerm installed successfully. Now you can use it by running 'wezterm' after installing the desktop environment"

# ==================================== Install lazyvim ====================================
echo "===== Installing LazyVim... ====="
mv ~/.config/nvim{,.bak}
mv ~/.local/share/nvim{,.bak}
mv ~/.local/state/nvim{,.bak}
mv ~/.cache/nvim{,.bak}
git clone https://github.com/LazyVim/starter ~/.config/nvim
if [ -d ~/.config/nvim ]; then
    rm -rf ~/.config/nvim/.git
    echo "LazyVim installed successfully. Now you can run 'nvim' to start using it."
else
    echo "Failed to clone LazyVim repository."
    echo "skipping LazyVim installation."
fi

# ==================================== Install conda ====================================
echo "===== Installing Miniconda... ====="
mkdir -p ~/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
~/miniconda3/bin/conda init zsh
echo "hide conda base in prompt"
conda config --set changeps1 false
# conda config --set changeps1 true
echo "Miniconda installed successfully. You can run 'conda' to manage your environments and packages."

# ==================================== Install nvm ====================================
echo "===== Installing nvm... ====="
mkdir -p ~/.nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
cat << 'EOF' >> ~/.zshrc
# >>> nvm initialize >>>
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
# <<< nvm initialize <<<
EOF
echo "nvm installed successfully. You can run 'nvm' to manage Node.js versions."

# ==================================== Install cloudreve ====================================
echo "===== Installing Cloudreve... ====="
curl -LO https://github.com/cloudreve/Cloudreve/releases/download/4.0.0-beta.13/cloudreve_4.0.0-beta.13_linux_amd64.tar.gz
if [ -f "cloudreve_4.0.0-beta.13_linux_amd64.tar.gz" ]; then
    mkdir cloudreve && tar -xzf cloudreve_4.0.0-beta.13_linux_amd64.tar.gz -C cloudreve
    chmod +x cloudreve/cloudreve
    echo "Cloudreve installed successfully. You can run it with './cloudreve/cloudreve'."
    echo "clean up..."
    rm -rf cloudreve_4.0.0-beta.13_linux_amd64.tar.gz
else
    echo "Failed to download Cloudreve. Please check the URL or your internet connection."
    echo "Skipping Cloudreve installation."
fi

# ==================================== clear package cache ====================================
echo "===== Clearing package cache... ====="
sudo pacman -Scc
rm -rf ~/.cache/*
sudo rm -rf /tmp/*
sudo rm -rf /usr/lib/modules/$(uname -r)-old
echo "Package cache cleared."

# ==================================== Finalize setup ====================================
echo "Done. Please restart your terminal or run 'source ~/.zshrc' to apply changes."
cat << 'EOF'
The packages installed this time are: 
==========================================================================================================================================================
Package Manager: yay
Basic system tools: grub openssh networkmanager net-tools ufw vim neovim git lazygit yazi tree curl wget fzf bat neofetch
Development Environment: conda nvm
System monitoring: btop duf ncdu
Web server: nginx
Intranet penetration: frp 
Web panel: dpanel cockpit
Efficiency tools: Tmux
Docker: docker docker-compose
kubernetes cluster: kind-bin minikube
Cloud storage: cloudreve

About the beautification of the system:
Fonts: 0xProtoNerdFontMono
Grub Theme: Xenlism Grub Theme
Terminal: wezterm
vim: LazyVim
zsh plugins: zsh-autosuggestions, zsh-syntax-highlighting, zsh-sudo, starship
Tmux plugins: tmux-plugins/tpm, tmux-plugins/tmux-sensible, christoomey/vim-tmux-navigator, tmux-plugins/tmux-yank, jimeh/tmuxifier, catppuccin/tmux

Please run 'yay -Syu' and 'sudo pacman -Syu' to update your system and install any additional packages you may need."
You need to run "source ~/.zshrc" to apply the changes made to your zsh configuration.
==========================================================================================================================================================
EOF

# ==================================== Switch to user shell ====================================
su - $USER
source ~/.zshrc