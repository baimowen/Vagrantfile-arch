#! /bin/bash

if [ "$(id -u)" -eq 0 ]; then
    echo -e "\033[1;31mPlease do not run this script as root or with sudo.\033[0m"
    exit 1
fi 

LOGFILE="$HOME/.cache/arch_packages.log"
[ -f $LOGFILE ] && rm -f $LOGFILE
exec &> >(tee -a $LOGFILE)

sudo cp /etc/sudoers /etc/sudoers.bak
sudo sed -i '$ a\root ALL=(ALL) NOPASSWD: ALL' /etc/sudoers

# -- variables ---------------------------------------------------------------------------------
VERBOSE=false
INTERFACE=$(ip -o -4 route show default | awk '{print $5}' | head -n1)
IPADDR=""
GATEWAY=""
NOW_IP=$(ip -o -4 addr show "$INTERFACE" | awk '{print $4}' | cut -d/ -f1)
NOW_GATEWAY=$(ip route | grep default | awk '{print $3}')
GIT_USERNAME=""
GIT_EMAIL=""
DEFAULT_GIT_USERNAME="local"
DEFAULT_GIT_EMAIL="local@localhost"

if [ -z "$IPADDR" ]; then
    read -p "Enter your ipaddr of the network interface (current: $INTERFACE): " IPADDR
fi

if [ -z "$GATEWAY" ]; then
    DEFAULT_GATEWAY=$(echo "$IPADDR" | awk -F. '{print $1"."$2"."$3".254"}')
    read -p "Enter your gateway of the network interface (default: $DEFAULT_GATEWAY): " GATEWAY
    GATEWAY=${GATEWAY:-$DEFAULT_GATEWAY}
fi

if [ -z "$GIT_USERNAME" ]; then
    read -p "Enter your git username: " GIT_USERNAME
    GIT_USERNAME=${GIT_USERNAME:-$DEFAULT_GIT_USERNAME}
fi

if [ -z "$GIT_EMAIL" ]; then
    read -p "Enter your git email: " GIT_EMAIL
    GIT_EMAIL=${GIT_EMAIL:-$DEFAULT_GIT_EMAIL}
fi

# -- functions ---------------------------------------------------------------------------------
# -e/--env KEY=VALUE
# Example: -e IPADDR=192.168.1.10
while [[ "$#" -gt 0 ]]; do
    case $1 in
        # -v|--verbose) VERBOSE=true ;;
        -e|--env)
            shift
            if [[ "$1" =~ ^([^=]+)=(.*)$ ]]; then
                case "${BASH_REMATCH[1]}" in
                    IPADDR) IPADDR="${BASH_REMATCH[2]}" ;;
                    GATEWAY) GATEWAY="${BASH_REMATCH[2]}" ;;
                    GIT_USERNAME) GIT_USERNAME="${BASH_REMATCH[2]}" ;;
                    GIT_EMAIL) GIT_EMAIL="${BASH_REMATCH[2]}" ;;
                    *) echo "Unknown environment variable: ${BASH_REMATCH[1]}"; exit 1 ;;
                esac
            else
                echo "Invalid environment variable format: $1 (should be KEY=VALUE)"; exit 1
            fi
            ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# debug() {
#     if [ "$VERBOSE" = true ]; then
#         echo "[DEBUG] $1"
#     fi
# }

# -- config network ---------------------------------------------------------------------------------
if command -v nmcli &> /dev/null; then
    echo "[info]: NetworkManager is already installed."
else
    echo "[warning]: NetworkManager is not installed, installing..."
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm networkmanager
fi
echo "[info]: enable NetworkManager.service..."
sudo systemctl enable --now NetworkManager
echo -e "\033[1;32m■ Configuring network...\033[0m"
# sudo systemctl disable --now systemd-networkd
# sudo systemctl disable --now systemd-resolved
# sudo nmcli con mod "$INTERFACE" \
#     ipv4.method manual \
#     ipv4.address $IPADDR/24 \
#     ipv4.gateway $GATEWAY \
#     ipv4.dns "114.114.114.114 8.8.8.8 223.5.5.5"
# sudo systemctl restart NetworkManager

# -- update pacman ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ update pacman...\033[0m"
sudo pacman -Syu --noconfirm

# -- install yay ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ Installing yay...\033[0m"
sudo pacman -S --noconfirm --needed base-devel git wget curl
git clone https://aur.archlinux.org/yay.git $HOME/yay && cd $HOME/yay|| { echo "Failed to clone yay repository"; exit 1; }
makepkg -si
if [ $? -ne 0 ]; then
    echo "Failed to build and install yay"
    exit 1
fi
cd $HOME

# -- install packages ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ Installing packages...\033[0m"
sudo pacman -S --noconfirm --needed openssh net-tools nftables jq less man dos2unix \
    vim neovim \
    lazygit gitui tokei \
    lsd yazi lf fzf fd bat ueberzugpp papirus-icon-theme \
    hyperfine \
    ncdu duf tree \
    btop ctop \
    unzip fontconfig \
    cockpit cockpit-podman cockpit-machines cockpit-packagekit \
    docker docker-compose \
    nginx \
    zsh starship tmux \
    gum \
    unp rsync \
    mpd mpc ncmpcpp cava \
    cowsay lolcat
    # kubectl

# sudo pacman -S --noconfirm fastfetch
# yay -S --noconfirm rxfetch
yay -S --noconfirm neofetch onefetch manly \
    tempy-git calcure glow termpicker musicfox
    # kind-bin minikube
# kind create cluster --name kind-cluster

curl https://laktak.github.io/rsyncy.sh | bash

wget -t 3 https://raw.githubusercontent.com/ContentsViewer/shtris/v3.0.0/shtris && chmod +x shtris && sudo mv shtris /usr/local/bin/shtris


# -- config tmux ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ Config tmux\033[0m"
echo "[info]: create configuration file: $HOME/.tmux.conf"
cat <<'EOF' > $HOME/.tmux.conf
# $HOME/.tmux.conf
# set -g default-command "exec zsh -l"
# set-option -g default-command "reattach-to-user-namespace -l $SHELL"

# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'christoomey/vim-tmux-navigator'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'jimeh/tmuxifier'
set -g @plugin 'sainnhe/tmux-fzf'
set -g @plugin 'tmux-plugins/tmux-resurrect'  # prefix + Ctrl-s - save
set -g @plugin 'tmux-plugins/tmux-continuum'  # prefix + Ctrl-r - restore
set -g @continuum-restore 'on'

set-option -g @plugin 'b0o/tmux-autoreload'  # auto reload

# catppuccin theme
set -g @plugin "catppuccin/tmux"
set -g @catppuccin_flavour "mocha"

# colors
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"

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
# 开启vi风格后，支持vi的C-d、C-u、hjkl等快捷键
set -g mode-keys vi
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

# keymaps
unbind C-b
set -g prefix `
bind ` send-prefix

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run "$HOME/.tmux/plugins/tpm/tpm"
EOF
echo "[info]: Install tmux plugin manager: tpm"
if git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm 2>/dev/null; then
    echo "[Info]: TPM installed successfully."
else
    echo "[Warning]: TPM installation skipped (git clone failed)."
fi
chmod 755 $HOME/.tmux

SESSION0=tmux_setup
tmux new-session -d -s $SESSION0
tmux send-keys -t $SESSION0 'tmux source-file $HOME/.tmux.conf' C-m
tmux send-keys -t $SESSION0 "sleep 1" C-m
# tmux send-keys -t $SESSION0 "`tmux show-options -g prefix | cut -d\' -f2`I" C-m
tmux send-keys -t $SESSION0 "tmux run-shell '$HOME/.tmux/plugins/tpm/bin/install_plugins'" C-m
tmux send-keys -t $SESSION0 "sleep 5" C-m
echo "[info]: use tmux attach -t $SESSION_NAME to check the progress."

# -- config git ---------------------------------------------------------------------------------
# This part can be written to an .env file
echo -e "\033[1;32m■ Config git\033[0m"
git config --global init.defaultBranch main
git config --global user.name "$GIT_USERNAME"
git config --global user.email "$GIT_EMAIL"
git config --global pull.rebase true
git config --global status.branch true
git config --global status.showStash true
git config --global color.ui auto

# -- config yazi/lf ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ Config yazi & lf\033[0m"
mkdir -p $HOME/.config/yazi
cat <<EOF > $HOME/.config/yazi/config.toml
[manager]
show_hidden = true
show_git = true
show_icons = true
show_size = true
EOF
mkdir -p $HOME/.config/lf
cat <<EOF > $HOME/.config/lf/lfrc
set hidden true
set icons true
set previewer bat
EOF

# -- config font ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ Config MapleMonoNFCN\033[0m"
wget -t 3 -P /tmp https://github.com/subframe7536/maple-font/releases/download/v7.3/MapleMono-NF-CN.zip
if [ -f /tmp/MapleMono-NF-CN.zip ]; then
    mkdir -p /tmp/fonts/MapleMono-NF-CN
    unzip /tmp/MapleMono-NF-CN.zip -d /tmp/fonts/MapleMono-NF-CN
    sudo mkdir -p /usr/share/fonts/MapleMono-NF-CN && sudo cp -r /tmp/fonts/MapleMono-NF-CN/* /usr/share/fonts/MapleMono-NF-CN
    sudo fc-cache -fv
    echo "MapleMonoNFCN font installed successfully. Cleaning up..."
    rm -rf /tmp/MapleMono-NF-CN.zip && rm -rf /tmp/fonts/MapleMono-NF-CN
else
    echo "[error]: Failed to install MapleMonoNFCN font."
fi
# echo -e "\033[1;32m■ Config 0xProtoNerdFontMonoFont\033[0m"
# wget -t 3 -P /tmp https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/0xProto.zip
# if [ -f /tmp/0xProto.zip ]; then
#     mkdir -p /tmp/fonts/0xProto
#     unzip /tmp/0xProto.zip -d /tmp/fonts/0xProto
#     sudo mkdir -p /usr/share/fonts/0xProto && sudo cp -r /tmp/fonts/0xProto/* /usr/share/fonts/0xProto
#     sudo fc-cache -fv
#     echo "0xProtoNerdFontMono font installed successfully. Cleaning up..."
#     rm -rf /tmp/0xProto.zip && rm -rf /tmp/fonts/0xProto
# else
#     echo "[error]: Failed to install 0xProtoNerdFontMono font."
# fi

# -- config neofetch ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ Config neofetch\033[0m"
[ -d $HOME/.config/neofetch ] || mkdir $HOME/.config/neofetch
if git clone https://github.com/Chick2D/neofetch-themes.git $HOME/.config/neofetch/themes; then
    cat $HOME/.config/neofetch/themes/small/dotfetch.conf | tee -a $HOME/.config/neofetch/config.conf >/dev/null
    sed -i "s/prin \"\$(color 5) CPU:/    info \"\$(color 5) CPU \" cpu/" $HOME/.config/neofetch/config.conf
    sed -i "s/prin \"\$(color 6) GPU:/    info \"\$(color 6) GPU \" gpu/" $HOME/.config/neofetch/config.conf
    echo "[info]: neofetch configuration complete."
else
    echo "[error]: Clone failed, skip."
neofetch

# -- config nginx and cockpit ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ Config nginx\033[0m"
sudo systemctl enable --now nginx
# cat <<EOF | sudo tee /etc/nginx/config.conf
# EOF
# sudo ln -s 
# test the configuration
if sudo nginx -t; then
    echo "[info]: Nginx configuration is valid."
    nginx -s reload
    echo "[info]: nginx configration complete."
else
    echo "[error]: Nginx configuration is invalid. Please check the logs."
fi
echo -e "\033[1;32m■ Config cockpit\033[0m"
sudo systemctl enable --now cockpit.socket
echo "[info]: Cockpit configuration complete."

# -- config docker ---------------------------------------------------------------------------------
# or podman(runc) 
# nerdctl(containerd)
# crictl(cri-o)  # Use with kubernetes
echo -e "\033[1;32m■ Config docker\033[0m"
sudo usermod -aG docker $USER
echo "[info]: Create docker configuration file..."
sudo mkdir -p /etc/docker
# sudo bash <(curl -sSL https://linuxmirrors.cn/docker.sh) && rm -f docker.sh
cat <<EOF | sudo tee /etc/docker/daemon.json >/dev/null
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
sudo systemctl enable --now docker
echo "[info]: docker mirror list:"
sudo docker info | grep -A 5 "Registry Mirrors"
echo "[info]: create dpanel and portainer container"
sudo docker run -d --name dpanel --restart=always \
  -p 88:80 -p 443:443 -p 8807:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /home/dpanel:/dpanel -e APP_NAME=dpanel dpanel/dpanel:latest
sudo docker run -d --name portainer --restart always \
  -p 9000:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock -v /app/portainer_data:/data \
  --privileged=true portainer/portainer-ce:latest
sudo docker ps -a | grep -aiE "dpanel|portainer"

# -- config miniconda ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ install miniconda\033[0m"
echo "=== installing Miniconda ==="
mkdir -p $HOME/miniconda3
wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
bash miniconda.sh -b -p $HOME/miniconda3
# initialize conda for zsh
# $HOME/miniconda3/bin/conda init --all
# hide conda base in prompt
conda config --set changeps1 false
conda --version
echo "[info]: miniconda installation completed!"
echo "[info]: clean cache..."
[ -f miniconda3.sh ] && rm -f miniconda3.sh && echo

# -- config nvm ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ install nvm\033[0m"
mkdir -p $HOME/.nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
[ -f install.sh ] && rm -f install.sh
echo "[info]: nvm installation completed!"

# -- config starship ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ Config starship\033[0m"
starship preset catppuccin-powerline -o $HOME/.config/starship.toml
sed -i '/\[line_break\]/,/^$/ s/disabled = true/disabled = false/' $HOME/.config/starship.toml
echo "[info]: Starship installed successfully. Now you can use it by running 'starship init zsh' in your terminal."

# -- download zsh plugins ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ download zsh plugins\033[0m"
git clone https://github.com/catppuccin/zsh-syntax-highlighting.git ~/.zsh/zsh-catppuccin || echo "[error]: Failed to clone catppuccin-zsh-theme repository"
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting || echo "[error]: Failed to clone zsh-syntax-highlighting repository"
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions || echo "[error]: Failed to clone zsh-autosuggestions repository"
git clone https://github.com/zap-zsh/sudo.git ~/.zsh/zsh-sudo || echo "[error]: Failed to clone zsh-sudo repository"

# -- zshrc and zprofile ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ create zshrc and zprofile\033[0m"
cat <<'EOF' > ~/.zshrc
case $- in  # check shell options
    *i*) ;;  # interactive shell
      *) return;;  # do not do anything
esac

load_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        if source "$file" 2>/dev/null; then
            return 0
        else
            echo >&2 "[WARN] Failed to load: $file"
            return 1
        fi
    else
        echo >&2 "[INFO] File not found, skipping: $file"
        return 1
    fi
}

CONFIG_FILES="${HOME}/.config/shell"
FUNCTIONS_DIR="${CONFIG_FILES}/scripts"
ZSH_PLUGIN_HOME="${HOME}/.zsh"

# config files
for config_file in "${CONFIG_FILES}"/*.{sh,zsh}(N); do
    load_file "$config_file"
done

# custom functions
for func_file in "${FUNCTIONS_DIR}"/*.{sh,zsh}(N); do
    load_file "$func_file"
done

# zsh plugins
for plugin_dir in "${ZSH_PLUGIN_HOME}"/*(N); do
    if [[ "$plugin_dir" != */zsh-syntax-highlighting ]]; then
        for plugin_file in "$plugin_dir"/*.{zsh,plugin.zsh}(N); do
            load_file "$plugin_file"
        done
    fi
done
[ -f "${ZSH_PLUGIN_HOME}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && \
    load_file "${ZSH_PLUGIN_HOME}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" || \
    echo >&2 "[Warning] load zsh-syntax-highlighting faild, skipping"

# starship
eval "$(starship init zsh)"

# fzf
[ -f ${CONFIG_FILES}/fzf.zsh ] && source ${CONFIG_FILES}/fzf.zsh || echo >&2 "[Warning] load fzf.sh faild, skipping"
# source <(/usr/bin/fzf --zsh)

# >>> conda initialize >>>
export CONDA_PATHS=(
    /home/arch/miniconda3/bin/conda  # 默认路径
    /data/miniconda3/bin/conda       # 可能路径
    $HOME/miniconda3/bin/conda       # 用户级默认路径
)

# 定义 conda 函数（首次调用时加载）
conda() {
    echo "[Lazy Load] Initializing Conda..."  # 提示信息
    unfunction conda  # 移除临时函数，避免重复加载

    # 遍历可能的 Conda 路径
    for conda_path in $CONDA_PATHS; do
        if [[ -f $conda_path ]]; then
            echo "Found Conda at: $conda_path"  # 调试信息
            eval "$($conda_path shell.zsh hook)"  # 初始化 Conda
            conda "$@"  # 执行用户输入的 conda 命令
            return
        fi
    done

    # 如果未找到 Conda
    echo "Error: No Conda installation found in the following paths:"
    for path in $CONDA_PATHS; do
        echo "  - $path"
    done
    return 1
}
# <<< conda initialize <<<

# >>> nvm initialize >>>
function nvm() {
    echo "Lazy loading nvm upon first invocation..."
    unfunction nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \\. "$NVM_DIR/bash_completion"
    nvm "$@"
}
# <<< nvm initialize <<<
EOF

cat <<'EOF' > ~/.zprofile
# $HOME/.zprofile
[ -f $HOME/.zshrc ] && source $HOME/.zshrc

# hyprland
# if [ -z "${WAYLAND_DISPLAY}" ] && [ "$(tty)" = "/dev/tty1" ]; then
#     exec Hyprland
# fi

# pulseaudio
# if ! pgrep -u $USER pulseaudio > /dev/null; then
#     pulseaudio --start
# fi

# cava xterm-256color
export TERM=xterm-256color
EOF

bat --paging=never $HOME/.zshrc
bat --paging=never $HOME/.zprofile
echo "[info]: zshrc and zprofile configuration complete."

# -- $HOME/.config/shell ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ create zsh script\033[0m"
echo "[info]: create fzf.zsh alias.sh bindkeys.sh history_settings.sh"
mkdir -p $HOME/.config/shell
fzf --zsh > "$HOME/.config/shell/fzf.zsh" >/dev/null
cat <<'EOF' > ~/.config/shell/aliases.sh
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias ls='LC_ALL=C ls -alh --group-directories-first --sort=name --color=auto'
alias lsd='lsd -alh --tree --group-directories-first --color=auto --icon=always'
alias grep='grep -iE --color=auto'
alias cat='bat'
alias v='nvim'
alias c='clear'
alias his='history'
alias df='df -h'
alias du='du -h'
alias free='free -h'

# >>> git >>>
alias lg='lazygit'
alias gl='git log --all --graph --color=auto'
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gps='git push'
alias gpl='git pull --rebase'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gplb='git pull --rebase origin $(git rev-parse --abbrev-ref HEAD)'
alias gplm='git pull --rebase origin main'
# <<< git <<<

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

# >>> fzf >>>
alias fzf='fzf --height 40% --layout reverse --border --ansi --multi'
# <<< fzf <<<

# >>> bat >>>
alias bat='bat -n --color=always --style=plain --paging=auto'
# <<< bat <<<
EOF

cat <<EOF > $HOME/.config/shell/bindkeys.sh
# vi
# bindkey -v
# export KEYTIMEOUT=1
# bindkey '^R' history-incremental-search-backward
# bind key: esc esc -> sudo
# bindkey -M viins '\e\e' sudo
# bindkey -M vicmd '\e\e' sudo
bindkey -r "^I"
bindkey "^I" complete-word
EOF

cat <<'EOF' > $HOME/.config/shell/history_settings.sh
HISTFILE=$HOME/.cache/zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_SPACE
EOF

echo "[info]: create $HOME/.config/scripts/*.sh"
mkdir -p $HOME/.config/shell/scripts
cat <<'EOF' > ~/.config/shell/scripts/bat.sh
batl() {
    local file="$1"
    local lang=""

    # 根据文件后缀匹配语言
    case "$file" in
        *.conf|*.ini)   lang="ini" ;;
        *.json)         lang="json" ;;
        *.yaml|*.yml)  lang="yaml" ;;
        *.sh|*.zsh|*.bash) lang="sh" ;;
        *.py)           lang="python" ;;
        *.js)           lang="javascript" ;;
        *.html)         lang="html" ;;
        *.css)          lang="css" ;;
        *.md)           lang="markdown" ;;
        *.toml)         lang="toml" ;;
        *.rs)           lang="rust" ;;
        *.go)           lang="go" ;;
        *)              lang="" ;;  # 自动检测
    esac

    # 调用 bat 并传递语言参数
    if [ -n "$lang" ]; then
        command bat --language="$lang" "$@"
    else
        command bat "$@"
    fi
}
EOF

echo "[info]: add execution permissions"
chmod +x ~/.config/shell/*.{sh,zsh}
chmod +x ~/.config/shell/scripts/*.sh

# -- Install lazyvim ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ Install lazyvim\033[0m"
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
    echo "Skipping LazyVim installation."
fi
# # nvim透明背景
# cat << 'EOF' >> $HOME/.config/nvim/init.lua
# vim.cmd([[
# hi Normal guibg=NONE ctermbg=NONE
# hi LineNr guibg=NONE ctermbg=NONE
# hi EndOfBuffer guibg=NONE ctermbg=NONE
# ]])
# EOF

# -- Clean package cache ---------------------------------------------------------------------------------
echo -e "\033[1;32m■ Clean package cache\033[0m"
sudo pacman -Scc
shopt -s extglob
rm -rf ~/.cache/!($LOGFILE) 2>/dev/null
shopt -u extglob
sudo rm -rf /tmp/*
# sudo rm -rf /usr/lib/modules/$(uname -r)-old
echo "[info]: Package cache cleared."

# ==================================== Finalize setup ====================================
echo "Done. 🎉"
echo -e "\033[1;36m\n📦 Package Summary\033[0m\n
\033[1;33m▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m\n
\033[1;32m■ Base Packages\033[0m
  ├─ \033[1;34mEditor\033[0m: vim nvim
  ├─ \033[1;34mVersion Control\033[0m: git lazygit
  ├─ \033[1;34mFile Process\033[0m: fzf fd bat jq less
  ├─ \033[1;34mFile Manager\033[0m: yazi lf lsd
  └─ \033[1;34mSystem Tools\033[0m: ncdu duf tree hyperfine rsync man\n
\033[1;32m■ System Service\033[0m
  ├─ \033[1;33mWeb Server\033[0m: nginx
  └─ \033[1;33mMonitor Panel\033[0m:
      ├─ cockpit: http://0.0.0.0:9000
      ├─ dpanel: http://0.0.0.0:8807
      └─ portainer: http://0.0.0.0:9000\n
\033[1;32m■ Terminal Enhancement\033[0m
  ├─ \033[1;35mShell\033[0m: zsh starship
  └─ \033[1;35mMultiplex\033[0m: tmux\n
\033[1;32m■ Development Envs\033[0m
  └─ \033[1;36mEnvironment Managers\033[0m: docker miniconda nvm\n
\033[1;32m■ Entertainment\033[0m
  └─ \033[1;31mMedia & Games\033[0m: ncmpcpp musicfox cava shtris\n
\033[1;33m▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m
\033[3;36mTips: Please restart your terminal or run 'source ~/.zshrc' to apply changes\n      Maybe you need to run 'conda config --set changeps1 false' to hide conda base in prompt.\033[0m" | sed 's/^/  /'
[ -f $LOGFILE ] && echo -e "Log file: \033[1;33m$LOGFILE\033[0m" || echo -e "\033[1;31mCreate log file failed\033[0m, please run 'journalctl -xe' to check system logs."

# ==================================== Switch to user shell ====================================
su - $USER