#! /bin/bash

if [ "$(id -u)" -eq 0 ]; then
    echo "Please do not run this script as root or with sudo."
    exit 1
fi 

[ -f $HOME/.cache/arch_packages.log ] && rm -f $HOME/.cache/arch_packages.log
exec &> >(tee -a $HOME/.cache/arch_packages.log)

if command -v nmcli &> /dev/null; then
    echo "NetworkManager is already installed."
else
    echo -e "\033[1;31mError: NetworkManager is not installed. Please install it first.\033[0m"
    exit 1
fi

sudo cp /etc/sudoers /etc/sudoers.bak
sudo sed -i '$ a\root ALL=(ALL) NOPASSWD: ALL' /etc/sudoers

# ==================================== ENVS ====================================
VERBOSE=false
INTERFACE=$(ip -o -4 route show default | awk '{print $5}' | head -n1)
IPADDR=""
GATEWAY=""
GIT_USERNAME=""
GIT_EMAIL=""
DEFAULT_GIT_USERNAME="local"
DEFAULT_GIT_EMAIL="local@localhost"
SESSION_NAME="pkg_setup"
MAIN_WINDOW="main"

# -e/--env KEY=VALUE
# Example: -e IPADDR=192.168.1.10
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true ;;
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

debug() {
    if [ "$VERBOSE" = true ]; then
        echo "[DEBUG] $1"
    fi
}

debug sudo -v

# ==================================== config network ====================================
echo "===== Configuring network... ====="
# sudo systemctl enable --now NetworkManager
# sudo nmcli con mod "$INTERFACE" \
#     ipv4.method manual \
#     ipv4.address $IPADDR/24 \
#     ipv4.gateway $GATEWAY \
#     ipv4.dns "114.114.114.114 8.8.8.8 223.5.5.5"
# sudo systemctl restart NetworkManager
NOW_IP=$(ip -o -4 addr show "$INTERFACE" | awk '{print $4}' | cut -d/ -f1)
NOW_GATEWAY=$(ip route | grep default | awk '{print $3}')
echo -e "ip: \033[1;32m$NOW_IP/24\033[0m\ngateway: \033[1;32m$NOW_GATEWAY\033[0m"

# ==================================== update packages manager ====================================
echo "===== Updating packages manager... ====="
sudo pacman -Syu --noconfirm

# ==================================== install yay ====================================
echo "===== Installing yay... ====="
sudo pacman -S --noconfirm --needed curl wget git base-devel
git clone https://aur.archlinux.org/yay.git $HOME/yay || { echo "Failed to clone yay repository"; exit 1; }
cd yay || { echo "Failed to enter yay directory"; exit 1; }
makepkg -si
if [ $? -ne 0 ]; then
    echo "Failed to build and install yay"
    exit 1
fi
cd $HOME

# ==================================== install packages ====================================
echo "===== Installing packages... ====="
sudo pacman -S --noconfirm --needed openssh net-tools nftables jq less man dos2unix \
    vim neovim \
    lazygit gitui tokei \
    lsd yazi lf fzf fd bat ueberzugpp papirus-icon-theme \
    hyperfine \
    ncdu duf tree \
    btop ctop \
    unzip fontconfig \
    cockpit cockpit-podman cockpit-machines cockpit-packagekit \
    docker docker-compose kubectl \
    nginx \
    zsh starship tmux \
    gum \
    unp rsync \
    mpd mpc ncmpcpp cava \
    cowsay lolcat

# sudo pacman -S --noconfirm fastfetch
# yay -S --noconfirm rxfetch
yay -S --noconfirm neofetch onefetch manly \
    tempy-git calcure glow termpicker musicfox \
    # kind-bin minikube

curl https://laktak.github.io/rsyncy.sh | bash

# ==================================== add iptables rules ====================================
sudo nft add rule inet filter input iifname lo accept
sudo nft add rule inet filter input tcp dport 22 accept  # ssh
sudo nft add rule inet filter input tcp dport { 80, 443 } accept  # http/https
sudo nft add rule inet filter input tcp dport { 9090 } accept  # cockpit
sudo nft add rule inet filter input tcp dport { 8807, 9000 } accept  # dpanel portainer
sudo nft add rule inet filter input ct state established,related accept
sudo nft add rule inet filter input ip protocol icmp accept
sudo nft add rule inet filter input ip6 nexthdr ipv6-icmp accept
sudo nft list ruleset > /etc/nftables.conf
sudo systemctl restart nftables

# ==================================== configuration preparation ====================================
# Asynchronously configure through tmux sessions
sudo pacman -S --noconfirm --needed git tmux base-devel

run_in_pane() {
    local window_name="$1"
    local pane_index="$2"
    local command="$3"
    
    if ! tmux list-windows -t $SESSION_NAME | grep -q "$window_name"; then
        tmux new-window -d -t $SESSION_NAME -n "$window_name"
        sleep 0.5
    fi
    
    # create pane
    if [[ $pane_index -gt 0 ]]; then
        if [[ $pane_index -eq 1 ]]; then
            tmux split-window -h -t "${SESSION_NAME}:${window_name}"
        else
            tmux split-window -v -t "${SESSION_NAME}:${window_name}.1"
        fi
        sleep 0.5
    fi
    
    tmux send-keys -t "${SESSION_NAME}:${window_name}.${pane_index}" "$command" Enter
}

echo "[Info]: create tmux configuration file: $HOME/.tmux.conf"
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

# auto reload
set-option -g @plugin 'b0o/tmux-autoreload'

# save and restore sessions
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'
# prefix + Ctrl-s - save
# prefix + Ctrl-r - restore

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
tmux new-session -d -s $SESSION_NAME -n "$MAIN_WINDOW"

# config tmux
echo "Install tmux plugin manager: tpm"
if git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm 2>/dev/null; then
    echo "[Info]: TPM installed successfully."
else
    echo "[Warning]: TPM installation skipped (git clone failed)."
fi
chmod 755 $HOME/.tmux
tmux new-session -d -s tmux_setup
tmux send-keys -t tmux_setup 'tmux source-file $HOME/.tmux.conf' C-m
tmux send-keys -t tmux_setup "sleep 1" C-m
# tmux send-keys -t tmux_setup "`tmux show-options -g prefix | cut -d\' -f2`I" C-m
tmux send-keys -t tmux_setup "tmux run-shell '$HOME/.tmux/plugins/tpm/bin/install_plugins'" C-m
tmux send-keys -t tmux_setup "sleep 5" C-m
echo "Waiting for tmux setup to complete..."
sleep 5

echo "All tasks are being carried out in the background..."
echo "use tmux attach -t $SESSION_NAME to check the progress."

# ==================================== configuration ====================================
# tmux kill-session -t $SESSION_NAME 2>/dev/null
tmux new-session -d -s "$SESSION_NAME" -n "$MAIN_WINDOW"
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux new-session -d -s "$SESSION_NAME"
fi
# git、yazi、lf、neofetch
# pane0: git
run_in_pane "base" 0 '
echo "===== Configuring git... ====="
git config --global pull.rebase true
git config --global init.defaultBranch main
git config --global status.branch true
git config --global status.showStash true
git config --global color.ui auto
git config --global user.name "$GIT_USERNAME"
git config --global user.email "$GIT_EMAIL"
bat --color=always --paging=never $HOME/.gitconfig
'
# pane1: yazi
run_in_pane "base" 1 '
echo "===== Configuring yazi... ====="
mkdir -p $HOME/.config/yazi
cat <<EOF > ~/.config/yazi/config.toml
[manager]
show_hidden = true
show_git = true
show_icons = true
show_size = true
EOF
bat -n --color=always --paging=never $HOME/.config/yazi/config.toml
'
# pane2: lf
run_in_pane "base" 2 '
echo "===== Configuring lf... ====="
mkdir -p $HOME/.config/lf
cat <<EOF > ~/.config/lf/lfrc
set hidden true
set icons true
set previewer bat
EOF
bat -n --color=always --paging=never $HOME/.config/lf/lfrc
'
# pane3: neofetch
run_in_pane "base" 3 '
echo "===== Configuring neofetch... ====="
[ -d $HOME/.config/neofetch ] || mkdir $HOME/.config/neofetch
git clone https://github.com/Chick2D/neofetch-themes.git $HOME/.config/neofetch/themes
cat neofetch-themes/small/dotfetch.conf | tee -a $HOME/.config/neofetch/config.conf >/dev/null
sed -i "s/prin \"\$(color 5) CPU:/    info \"\$(color 5) CPU \" cpu/" $HOME/.config/neofetch/config.conf
sed -i "s/prin \"\$(color 6) GPU:/    info \"\$(color 6) GPU \" gpu/" $HOME/.config/neofetch/config.conf
neofetch
'
# pane4: lazyvim
run_in_pane "base" 4 '
echo "===== Configuring lazyvim... ====="
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
nvim
'

# develop environment
# pane0: Miniconda
run_in_pane "develop" 0 '
echo "=== installing Miniconda ==="
mkdir -p $HOME/miniconda3
wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
bash /tmp/miniconda.sh -b -p $HOME/miniconda3
# initialize conda for zsh
# $HOME/miniconda3/bin/conda init --all
# hide conda base in prompt
conda config --set changeps1 false
conda --version
echo "Miniconda installation completed!"
'
# pane1：Nvm
run_in_pane "develop" 1 '
echo "=== installing Nvm ==="
mkdir -p $HOME/.nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
echo "Nvm installation completed!"
'
# pane2：Docker
run_in_pane "develop" 2 '
echo "=== configuring Docker ==="
sudo usermod -aG docker $USER
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json >/dev/null
{
    "registry-mirrors": [
        "https://docker.1panel.live"
        "https://docker.mirrors.tuna.tsinghua.edu.cn"
        "https://mirror.gcr.io"
        "https://registry.docker-cn.com"
        "https://docker.mirrors.ustc.edu.cn"
    ],
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable --now docker
echo "Docker configuration completed!"
'
# pane3: cockpit and nginx
run_in_pane "develop" 3 '
echo "=== configuring Cockpit ==="
sudo systemctl enable --now cockpit
echo "Cockpit configuration completed!"
echo "=== configuring Nginx ==="
sudo systemctl enable --now nginx
# cat <<EOF | sudo tee /etc/nginx/config.conf >/dev/null
# EOF
# sudo ln -s 
# test the configuration
if sudo nginx -t; then
    echo "Nginx configuration is valid."
    nginx -s reload
else
    echo "Nginx configuration is invalid. Please check the logs."
fi
echo "Nginx configuration completed!"
'
# pane4: dpanel
run_in_pane "develop" 4 '
sudo docker run -d --name dpanel --restart=always \
  -p 88:80 -p 443:443 -p 8807:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /home/dpanel:/dpanel -e APP_NAME=dpanel dpanel/dpanel:latest
sudo docker ps -a | grep dpanel 
'
# pane5: portainer
run_in_pane "develop" 5 '
sudo docker run -d --name portainer --restart always \
  -p 9000:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock -v /app/portainer_data:/data \
  --privileged=true portainer/portainer-ce:latest
sudo docker ps -a | grep portainer
'

# zsh and starship
# pane0: switch default shell and install zsh plugins
run_in_pane "terminal" 0 '
echo "=== clone zsh_plugin ==="
mkdir -p $HOME/.config/shell
git clone https://github.com/catppuccin/zsh-syntax-highlighting.git $HOME/.zsh/zsh-catppuccin || echo "Failed to clone catppuccin-zsh-theme repository"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $HOME/.zsh/zsh-syntax-highlighting || echo "Failed to clone zsh-syntax-highlighting repository"
git clone https://github.com/zsh-users/zsh-autosuggestions.git $HOME/.zsh/zsh-autosuggestions || echo "Failed to clone zsh-autosuggestions repository"
git clone https://github.com/zap-zsh/sudo.git $HOME/.zsh/zsh-sudo || echo "Failed to clone zsh-sudo repository"
'
# pane1: config starship style
run_in_pane "terminal" 1 '
echo "=== Configuring Starship ==="
starship preset catppuccin-powerline -o $HOME/.config/starship.toml
sed -i "/\[line_break\]/,/^$/ s/disabled = true/disabled = false/" $HOME/.config/starship.toml
echo "Starship installed successfully. Now you can use it by running starship init zsh in your terminal."
'
# pane2: font
run_in_pane "terminal" 2 '
echo "===== Installing MapleMonoNFCN font... ====="
wget -t 3 -P /tmp https://github.com/subframe7536/maple-font/releases/download/v7.3/MapleMono-NF-CN.zip
if [ -f /tmp/MapleMono-NF-CN.zip ]; then
    mkdir -p /tmp/fonts/MapleMono-NF-CN
    unzip /tmp/MapleMono-NF-CN.zip -d /tmp/fonts/MapleMono-NF-CN
    sudo mkdir -p /usr/share/fonts/MapleMono-NF-CN && sudo cp -r /tmp/fonts/MapleMono-NF-CN/* /usr/share/fonts/MapleMono-NF-CN
    sudo fc-cache -fv
    echo "MapleMonoNFCN font installed successfully. Cleaning up..."
    rm -rf /tmp/MapleMono-NF-CN.zip && rm -rf /tmp/fonts/MapleMono-NF-CN
else
    echo "Failed to install MapleMonoNFCN font."
fi
'

# zsh configurations
# pane0: zshrc and zprofile
run_in_pane "zsh" 0 '
cat <<EOF > ~/.zshrc
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

cat <<EOF > ~/.zprofile
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

fzf --zsh > "${CONFIG_FILES}/fzf.zsh" >/dev/null
EOF
bat -n --color=always --paging=never $HOME/.zshrc
bat -n --color=always --paging=never $HOME/.zprofile
'
# pane1: aliases/bindkeys/history_settings/
run_in_pane "zsh" 1 "
cat <<'EOF' > ~/.config/shell/aliases.sh
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias ls='LC_ALL=C ls -alh --group-directories-first --sort=name --color=auto'
alias lsd='lsd -alh --tree --group-directories-first --color=auto --icon=always'
alias grep='grep -iE --color=auto'
alias cat='batl'
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
alias gplb='git pull --rebase origin \$(git rev-parse --abbrev-ref HEAD)'
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

# bindkeys
cat <<'EOF' > ~/.config/shell/bindkeys.sh
# vi
# bindkey -v
# export KEYTIMEOUT=1
# bindkey '^R' history-incremental-search-backward
# bind key: esc esc -> sudo
# bindkey -M viins '\e\e' sudo
# bindkey -M vicmd '\e\e' sudo
bindkey -r '^I'
bindkey '^I' complete-word
EOF

# history settings
cat <<'EOF' > ~/.config/shell/history_settings.sh
HISTFILE=\$HOME/.cache/zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_SPACE
EOF

for config_file in ~/.config/shell/*.{sh}; do
    chmod +x \"\$config_file\"
    bat -n --color=always --paging=never \"\$config_file\"
done
"
# pane2: zsh_scripts
run_in_pane "zsh" 2 '
mkdir -p $HOME/.config/shell/scripts
cat <<EOF > $HOME/.config/shell/scripts/batl.sh
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
        *)              lang="" ;;
    esac

    if [ -n "$lang" ]; then
        command bat --language="$lang" "$@"
    else
        command bat "$@"
    fi
}
EOF
chmod +x $HOME/.config/shell/scripts/batl.sh
bat -n $HOME/.config/shell/scripts/batl.sh
'

# ==================================== clear package cache ====================================
# echo "===== Clearing package cache... ====="
# sudo pacman -Scc
# shopt -s extglob
# sudo rm -rf ~/.cache/!(log.log)
# shopt -u extglob
# sudo rm -rf /tmp/*
# # sudo rm -rf /usr/lib/modules/$(uname -r)-old
# echo "Package cache cleared."

# ==================================== Finalize setup ====================================
# echo "Done. 🎉"
echo "\033[1;32mPackages list: \033[0m"
echo -e "\033[1;36m\n📦 Packages\033[0m\n
\033[1;33m▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m\n
\033[1;32m■ Basic Packages\033[0m
  ├─ \033[1;34mSystem Manage\033[0m: openssh networkmanager net-tools ufw ncdu duf yay toolong manly howdoi hyperfine
  ├─ \033[1;34mFile Manage\033[0m: yazi lf tree unp rsync rsyncy fd
  ├─ \033[1;34mNetwork Tools\033[0m: curl wget aim frp tailscale
  └─ \033[1;34mOthers\033[0m: fastfetch rxfetch onefetch fanyi \n
\033[1;32m■ Terminal Enhancement\033[0m
  ├─ \033[1;35mShell\033[0m: zsh starship
  ├─ \033[1;35mMultiplex\033[0m: tmux
  ├─ \033[1;35mFile Process\033[0m: fzf bat less jq
  └─ \033[1;35mPlugins\033[0m:
      ├─ zsh: autosuggestions/syntax-highlighting/sudo/fzf
      └─ tmux: tpm/sensible/vim-navigator/yank\n
\033[1;32m■ System Service\033[0m
  ├─ \033[1;33mWeb Server\033[0m: nginx
  ├─ \033[1;33mMonitor Panel\033[0m:
  |   ├─ cockpit: http://0.0.0.0:9000
  |   └─ dpanel: http://0.0.0.0:8807
  └─ \033[1;33mPerformance Monitor\033[0m: btop ctop mission-center\n
\033[1;32m■ Development\033[0m
  ├─ \033[1;36mEditor\033[0m: neo vim lazyvim glow frogmouth
  ├─ \033[1;36mVersion Control\033[0m: git lazygit gitui tokei
  ├─ \033[1;36mContainer Management\033[0m: docker portainer(http://0.0.0.0:9000)
  ├─ \033[1;36mCluster\033[0m: kubectl kind minikube
  └─ \033[1;36mEnvs\033[0m: conda nvm\n
\033[1;32m■ Funny Tools\033[0m
  ├─ \033[1;31mtext:\033[0m: cowsay lolcat termpicker
  ├─ \033[1;31mgames:\033[0m: shtris snowmachine 
  └─ \033[1;31maudio:\033[0m: musicfox cava\n
\033[1;32m■ Landscaping Extension\033[0m
  ├─ \033[1;35mfonts\033[0m: 0xProtoNerdMono MapleMonoNFCN
  └─ \033[1;35mcolor_theme\033[0m: Catppuccin\n
\033[1;33m▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔\033[0m
\033[3;36mTips: Please restart your terminal or run 'source ~/.zshrc' to apply changes\n      Maybe you need to run 'conda config --set changeps1 false' to hide conda base in prompt.\033[0m" | sed 's/^/  /'
[ -f ~/.cache/arch_packages.log ] && echo -e "Log file: \033[1;33m~/.cache/arch_packages.log\033[0m" || echo -e "\033[1;31mCreate log file failed\033[0m, please run 'journalctl -xe' to check system logs."

# ==================================== Switch to user shell ====================================
su - $USER