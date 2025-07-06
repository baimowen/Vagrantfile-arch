#! /bin/bash

if [ "$(id -u)" -eq 0 ]; then
    echo "Please do not run this script as root or with sudo."
    exit 1
fi 

[ -f ~/.cache/arch_packages.log ] && rm -f ~/.cache/arch_packages.log
exec &> >(tee -a ~/.cache/arch_packages.log)

# ==================================== switch network ====================================
sudo pacman -Syu --noconfirm && sudo pacman -S --noconfirm networkmanager
sudo systemctl disable --now systemd-networkd
# sudo systemctl disable --now systemd-resolved
sudo systemctl enable --now NetworkManager
INTERFACE=$(ip -o -4 route show default | awk '{print $5}' | head -n1)
read -p "Enter ip address: " IPADDR
# sudo nmcli connection add type ethernet \
#     con-name "$INTERFACE" \
#     ifname $INTERFACE
sudo nmcli con mod "$INTERFACE" ipv4.method manual \
    ipv4.address $IPADDR/24 \
    ipv4.gateway 192.168.99.254 \
    ipv4.dns "114.114.114.114 8.8.8.8 223.5.5.5"
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
sudo pacman -S --noconfirm --needed openssh net-tools ufw jq unp less dos2unix \
    vim neovim \
    git lazygit gitui tokei \
    lsd yazi lf fd bat \
    curl wget hyperfine \
    ncdu duf tree \
    btop ctop mission-center \
    rsync rsyncy

curl https://laktak.github.io/rsyncy.sh | bash

sudo pacman -S --noconfirm fastfetch
yay -S --noconfirm neofetch rxfetch onefetch manly howdoi 

neofetch

# yay -S --noconfirm wine visual-studio-code-bin

sudo ufw allow 22/tcp
sudo ufw enable

# ==================================== Install tmux ====================================
echo "===== Installing Tmux... ====="
sudo pacman -S --noconfirm tmux
echo "Install tmux plugin manager: tpm"
if git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm 2>/dev/null; then
    ~/.tmux/plugins/tpm/bin/install_plugins
else
    echo "Warning: TPM installation skipped (git clone failed)."
fi
echo "create tmux configuration file: ~/.tmux.conf"
cat << 'EOF' > ~/.tmux.conf
# ~/.tmux.conf
set -g default-command "exec zsh -l"
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
run '~/.tmux/plugins/tpm/tpm'

EOF
tmux new-session -d -s tmux_setup
tmux send-keys -t tmux_setup "tmux source ~/.tmux.conf" Enter
tmux send-keys -t tmux_setup "sleep 1" Enter
tmux send-keys -t tmux_setup "`tmux show-options -g prefix | cut -d\' -f2`I" Enter
tmux send-keys -t tmux_setup "sleep 10" Enter
sleep 5

# ==================================== Configuration git ====================================
# This part can be written to an .env file
echo "===== Configuring git... ====="
read -p "Enter your username for git: " GIT_USER
read -p "Enter your email for git: " GIT_EMAIL
if [ -z "$GIT_USER" ]; then
    GIT_USER="arch"
fi
if [ -z "$GIT_EMAIL" ]; then
    GIT_EMAIL="arch@arch.template"
fi

git config --global pull.rebase true
git config --global init.defaultBranch main
git config --global status.branch true
git config --global status.showStash true
git config --global color.ui auto
git config --global user.name "$GIT_USER"
git config --global user.email "$GIT_EMAIL"

# ==================================== Configuration yazi ====================================
echo "===== Configuring yazi... ====="
mkdir -p ~/.config/yazi
cat << 'EOF' > ~/.config/yazi/config.toml
# yazi.toml
[manager]
show_hidden = true
show_git = true
show_icons = true
show_size = true
EOF

# ================================ fonts: 0xProtoNerdFontMono MapleMonoNFCN ================================
sudo pacman -S --noconfirm unzip fontconfig

# echo "===== Installing 0xProtoNerdFontMono font... ====="
# wget -t 3 -P /tmp https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/0xProto.zip
# if [ -f /tmp/0xProto.zip ]; then
#     mkdir -p /tmp/fonts/0xProto
#     unzip /tmp/0xProto.zip -d /tmp/fonts/0xProto
#     sudo mkdir -p /usr/share/fonts/0xProto && sudo cp -r /tmp/fonts/0xProto/* /usr/share/fonts/0xProto
#     sudo fc-cache -fv
#     echo "0xProtoNerdFontMono font installed successfully. Cleaning up..."
#     rm -rf /tmp/0xProto.zip && rm -rf /tmp/fonts/0xProto
# else
#     echo "Failed to install 0xProtoNerdFontMono font."
# fi

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

# ==================================== neofetch ====================================
[ -d ~/.config/neofetch ] || mkdir ~/.config/neofetch
git clone https://github.com/Chick2D/neofetch-themes.git
cat neofetch-themes/small/dotfetch.conf | tee -a ~/.config/neofetch/config.conf >/dev/null

# ==================================== Install Cockpit ====================================
echo "===== Installing Cockpit... ====="
sudo pacman -S --noconfirm cockpit cockpit-podman cockpit-machines cockpit-packagekit
sudo systemctl enable --now cockpit.socket
sudo ufw allow 9090/tcp

# ==================================== Install Docker ====================================
# or podman(runc) 
# nerdctl(containerd)
# crictl(cri-o)  # Use with kubernetes
echo "===== Installing Docker... ====="
sudo pacman -S --noconfirm docker docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
echo "Docker installed successfully. Create docker configuration file..."
sudo mkdir -p /etc/docker
sudo bash <(curl -sSL https://linuxmirrors.cn/docker.sh) && rm -f docker.sh
sudo systemctl daemon-reload
sudo systemctl restart docker
echo "===== start dpanel... ====="
sudo docker run -d --name dpanel --restart=always \
  -p 88:80 -p 443:443 -p 8807:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /home/dpanel:/dpanel -e APP_NAME=dpanel dpanel/dpanel:latest
sudo docker run -d --name portainer --restart always \
  -p 9000:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock -v /app/portainer_data:/data \
  --privileged=true portainer/portainer-ce:latest
sudo docker ps -a | grep -aiE "dpanel|portainer"

# ==================================== Install kubernetes ====================================
echo "===== Installing Kubernetes... ====="
yay -S --noconfirm kind-bin minikube
sudo pacman -S --noconfirm kubectl
kind create cluster --name kind-cluster

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

# ==================================== Install Tailscale ====================================
echo "===== Installing Tailscale... ====="
curl -fsSL https://tailscale.com/install.sh | sh

# ==================================== Install zsh ====================================
echo "===== Installing zsh... ====="
sudo pacman -S --noconfirm zsh fzf
chsh -s /bin/zsh

echo "Install zsh plugin: zsh-autosuggestions, zsh-syntax-highlighting, zsh-sudo"
git clone https://github.com/catppuccin/zsh-syntax-highlighting.git ~/.zsh/zsh-catppuccin || echo "Failed to clone catppuccin-zsh-theme repository"
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting || echo "Failed to clone zsh-syntax-highlighting repository"
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions || echo "Failed to clone zsh-autosuggestions repository"
git clone https://github.com/zap-zsh/sudo.git ~/.zsh/zsh-sudo || echo "Failed to clone zsh-sudo repository"

mkdir -p ~/.config/shell
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
# alias ..='cd ..'
# alias ...='cd ../..'
# alias ~='cd ~'

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

# >>> kill >>>
alias kill="killfzf"
# <<< kill <<<

# >>> bat >>>
alias bat='bat -n --color=always --style=plain --paging=auto'
# <<< bat <<<
EOF

cat <<'EOF' > ~/.config/shell/bindkeys.sh
# vi
# bindkey -v
# export KEYTIMEOUT=1
# bindkey '^R' history-incremental-search-backward
# bind key: esc esc -> sudo
# bindkey -M viins '\e\e' sudo
# bindkey -M vicmd '\e\e' sudo
bindkey -r "^I"  # 解除tab快捷键的绑定
bindkey "^I" complete-word  # 重新将tab快捷键绑定到自动补全
EOF

cat << 'EOF' > ~/.config/shell/colors.sh
# [ -f "$HOME/.config/dircolors" ] && eval $(dircolors "$HOME/.config/dircolors")
DCOLORS_PATHS=(
    "$HOME/.config/dircolors"
    "$HOME/.dir_colors"
    "$HOME/.dircolors"
    "/etc/DIR_COLORS"
    "/usr/bin/dircolors"
)

if ! command -v dircolors >/dev/null 2>&1; then
    echo "[WARN] dircolors command not found - using default colors" >/dev/null
    return 1
fi

for config in "${DCOLORS_PATHS[@]}"; do
    if [[ -f "$config" ]]; then
        if eval "$(dircolors -b "$config" 2>/dev/null)"; then
            echo "[INFO] Applied dircolors from: $config" >/dev/null
            return 0
        else
            echo "[WARN] Failed to apply dircolors from: $config" >/dev/null
        fi
    fi
done

echo "[INFO] No valid dircolors found - using defaults" >/dev/null
eval "$(dircolors -b 2>/dev/null)"
return 1
EOF

cat <<'EOF' > ~/.config/shell/history_settings.sh
HISTFILE=~/.cache/zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_SPACE
EOF

mkdir -p ~/.config/shell/scripts
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
cat <<'EOF' > ~/.config/shell/scripts/killfzf.sh
killfzf() {
  if [[ -z $COMP_LINE ]]; then  # 仅在直接运行 kill 时触发 fzf
    local pid=$(ps -aux | fzf | awk '{print $2}')
    [[ -n $pid ]] && kill "$pid"
  else
    command kill "$@"  # 补全时使用默认 kill 行为
  fi
}
EOF

cat <<'EOF' > ~/.zshrc
case $- in  # check shell options
    *i*) ;;  # interactive shell
      *) return;;  # don't do anything
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

EOF

cat <<'EOF' > ~/.zprofile
[ -f ~/.zshrc ] && source ~/.zshrc
if [ -z "${WAYLAND_DISPLAY}" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec Hyprland
fi

if ! pgrep -u $USER pulseaudio > /dev/null; then
    pulseaudio --start
fi

# cava xterm-256color
export TERM=xterm-256color
EOF
chmod +x ~/.config/shell/*.sh
chmod +x ~/.config/shell/scripts/*.sh
fzf --zsh > ~/.config/shell/fzf.zsh > /dev/null

# ==================================== Install starship ====================================
echo "===== Installing Starship... ====="
sudo pacman -S --noconfirm starship
starship preset catppuccin-powerline -o ~/.config/starship.toml
sed -i '/\[line_break\]/,/^$/ s/disabled = true/disabled = false/' ~/.config/starship.toml
echo "Starship installed successfully. Now you can use it by running 'starship init zsh' in your terminal."

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
    echo "Skipping LazyVim installation."
fi

# ==================================== Install conda ====================================
echo "===== Installing Miniconda... ====="
mkdir -p ~/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
# ~/miniconda3/bin/conda init zsh
echo "hide conda base in prompt"
conda --version
conda config --set changeps1 false

cat <<'EOF' | tee -a ~/.zshrc >/dev/null
# >>> conda initialize >>>
# Conda 延迟加载配置（支持多路径检测，但优先使用 /home/arch/miniconda3）
export CONDA_PATHS=(
    /home/arch/miniconda3/bin/conda  # 你的明确路径
    /data/miniconda3/bin/conda       # 其他可能路径
    $HOME/miniconda3/bin/conda       # 用户级默认路径
)

# 定义 conda 函数（首次调用时加载）
conda() {
    echo "[Lazy Load] Initializing Conda..."  # 提示信息（可删）
    unfunction conda  # 移除临时函数，避免重复加载

    # 遍历可能的 Conda 路径
    for conda_path in $CONDA_PATHS; do
        if [[ -f $conda_path ]]; then
            echo "Found Conda at: $conda_path"  # 调试信息（可删）
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
EOF
# conda config --set changeps1 true
echo "Miniconda installed successfully. You can run 'conda' to manage your environments and packages."

# ==================================== Install nvm ====================================
echo "===== Installing nvm... ====="
mkdir -p ~/.nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
sed -i '/export NVM_DIR="$HOME\/.nvm"/,/\[ -s "$NVM_DIR\/bash_completion" \] && \. "$NVM_DIR\/bash_completion"/d' ~/.zshrc
cat << 'EOF' >> ~/.zshrc
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
nvm install --lts
nvm use --lts
echo "nvm installed successfully. You can run 'nvm' to manage Node.js versions."

# ==================================== Install manually packages ====================================
echo "===== Installing manually packages... ====="
yay -S --noconfirm tempy-git calcure glow termpicker
sudo pacman -S --noconfirm gum tokei 
pipx install frogmouth toolong 
npm i fanyi -g

# ==================================== Install funny packages ====================================
echo "===== Installing funny packages... ====="
sudo pacman -S --noconfirm pulseaudio mpd mpc ncmpcpp && pulseaudio --check || pulseaudio --start
mkfifo /tmp/mpd.fifo && chmod 666 /tmp/mpd.fifo
cat <<EOF > ~/.config/mpd/mpd.conf
music_directory         "~/Music"
playlist_directory      "~/.config/mpd/playlists"
db_file                 "~/.config/mpd/database"
log_file                "~/.config/mpd/log"
pid_file                "~/.config/mpd/pid"
state_file              "~/.config/mpd/state"
# bind_to_address         "localhost"
bind_to_address         "127.0.0.1"
port                    "6600"
log_level               "default"
restore_paused          "yes"
auto_update             "yes"
auto_update_depth       "4"

audio_output {
     type            "pulse"
     name            "pulse audio"
}

audio_output {
       type	"fifo"
       name	"Visualizer feed"
       path	"/tmp/mpd.fifo"
       format	"44100:16:2"
}
EOF
mkdir -p ~/Music
mkdir -p ~/.config/mpd/playlists
sudo systemctl enable --now mpd
sudo pacman -S --noconfirm cowsay lolcat cava
yay -S --noconfirm musicfox
pipx install sonwmachine
wget -t 3 https://raw.githubusercontent.com/ContentsViewer/shtris/v3.0.0/shtris && chmod +x shtris && sudo mv shtris /usr/local/bin/shtris
wget -t 3 https://github.com/mihaigalos/aim/releases/download/1.8.6/aim-1.8.6-x86_64-unknown-linux-gnu.tar.gz && mkdir ~/aim && sudo mv ~/aim/aim /usr/local/bin/aim


# ==================================== clear package cache ====================================
echo "===== Clearing package cache... ====="
sudo pacman -Scc
rm -rf ~/.cache/*
sudo rm -rf /tmp/*
sudo rm -rf /usr/lib/modules/$(uname -r)-old
echo "Package cache cleared."

# ==================================== Finalize setup ====================================
echo "Done. 🎉"
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
# source ~/.zshrc
# # nvim透明背景
# cat << 'EOF' >> ~/.config/nvim/init.lua
# vim.cmd([[
# hi Normal guibg=NONE ctermbg=NONE
# hi LineNr guibg=NONE ctermbg=NONE
# hi EndOfBuffer guibg=NONE ctermbg=NONE
# ]])
# EOF