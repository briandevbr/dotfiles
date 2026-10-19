# shellcheck shell=bash
# ==========================================
# FERRAMENTAS MODERNAS (FZF, ZOXIDE, EZA, BAT, FD, DELTA)
# Cada uma só liga se estiver instalada — sem ela, o comando normal continua.
# O zoxide e as teclas do fzf carregam em shell/bash/ e shell/zsh/ (o código
# de init deles é diferente em cada shell).
# ==========================================

# ---------- Homebrew (macOS e Linuxbrew) ----------
# Põe o brew no PATH antes de procurar as outras ferramentas (fzf, eza…
# instaladas por ele). A saída do 'brew shellenv' fica em cache: chamar o
# brew a cada terminal custaria ~30ms.
if [ -z "${HOMEBREW_PREFIX:-}" ]; then
    for _df_b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        if [ -x "$_df_b" ]; then
            # shellcheck source=/dev/null
            _cache_init _df_arq brew "$_df_b" shellenv && . "$_df_arq"
            [ -z "$_PKG" ] && _PKG=brew
            break
        fi
    done
    unset _df_b _df_arq
fi

# ---------- less: abre .gz, .zip, .pdf… direto ----------
# Antes: eval "$(lesspipe)" abria um processo por terminal (~5ms) só pra
# imprimir estas duas linhas, que são sempre iguais.
if [ -x /usr/bin/lesspipe ]; then
    export LESSOPEN="| /usr/bin/lesspipe %s" LESSCLOSE="/usr/bin/lesspipe %s %s"
elif _tem lesspipe.sh; then
    export LESSOPEN="|lesspipe.sh %s"
fi

# grep colorido (egrep/fgrep viraram 'grep -E/-F': os nomes antigos avisam
# que estão obsoletos nas versões novas do GNU grep)
alias grep='grep --color=auto'
alias fgrep='grep -F --color=auto'
alias egrep='grep -E --color=auto'

# ---------- NVM — carregamento lazy (terminal mais rápido) ----------
# O nvm.sh leva ~200ms pra carregar. Aqui ele só carrega na primeira vez
# que você usa node, npm, npx ou nvm.
export NVM_DIR="$HOME/.nvm"

lazy_load_nvm() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] || return 0
    if [ -n "${ZSH_VERSION:-}" ]; then
        # o nvm é escrito pro zsh "de verdade": carrega fora da emulação
        emulate zsh -c '\. "$NVM_DIR/nvm.sh"'
    else
        # shellcheck source=/dev/null
        \. "$NVM_DIR/nvm.sh"
    fi
}
# Só cria os atalhos lazy se o nvm existir: sem nvm, o node do sistema
# (apt, brew) é chamado direto.
if [ -s "$NVM_DIR/nvm.sh" ]; then
    nvm()  { lazy_load_nvm; nvm "$@"; }
    node() { lazy_load_nvm; node "$@"; }
    npm()  { lazy_load_nvm; npm "$@"; }
    npx()  { lazy_load_nvm; npx "$@"; }
fi

# ---------- cores do ls / eza ----------
# Pastas em ciano negrito (igual à pasta do prompt), links em lilás, executáveis em verde
export LS_COLORS="di=1;38;5;51:fi=38;5;252:ln=38;5;141:ex=1;38;5;46:*.sh=38;5;214:*.py=38;5;39:*.js=38;5;214:*.json=38;5;141:*.md=38;5;39"
# macOS: o 'ls' do BSD lê LSCOLORS (outro formato). Pasta ciano, link lilás, executável verde.
export CLICOLOR=1 LSCOLORS="GxFxCxDxBxegedabagaced"

# ---------- fzf — listas com busca ----------
# Mesmas cores do prompt em hex: 39=#00afff 51=#00ffff 141=#af87ff 214=#ffaf00 46=#00ff00
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border=rounded \
--color=fg:#d0d0d0,bg:-1,hl:#00afff \
--color=fg+:#ffffff,bg+:#303030,hl+:#00ffff \
--color=info:#af87ff,prompt:#00afff,pointer:#ffaf00,marker:#00ff00,spinner:#af87ff,header:#af87ff,border:#585858"

# ---------- eza — o ls com ícones e git ----------
# Sem eza: o ls do sistema, colorido (GNU no Linux, BSD no macOS)
if _tem eza; then
    alias ls='eza --icons --group-directories-first --git'
    alias ll='eza -alF --icons --group-directories-first --git'
    alias la='eza -A --icons --group-directories-first --git'
    alias lt='eza --tree --icons --level=2 --git'
    alias tree='eza --tree --icons --group-directories-first --git'
    alias dir='eza --icons --group-directories-first --git'
elif [ "$_SO" = macos ]; then
    alias ls='ls -G'
    alias ll='ls -alFG'
    alias la='ls -AG'
else
    alias ls='ls --color=auto --group-directories-first'
    alias ll='ls -alF --color=auto --group-directories-first'
    alias la='ls -A --color=auto --group-directories-first'
fi

# ---------- bat — o cat com cores de código ----------
# Define _BAT com o nome real do binário (varia entre distros)
_BAT=""
if _tem batcat; then
    _BAT="batcat"
elif _tem bat; then
    _BAT="bat"
fi

if [ -n "$_BAT" ]; then
    export BAT_THEME="Dracula"
    alias cat="$_BAT --paging=never"
    alias catp="$_BAT"
    # Preview colorido no Ctrl+T do fzf
    export FZF_CTRL_T_OPTS="--preview '$_BAT --color=always --style=numbers --line-range=:100 {}'"
fi

# ---------- fd — busca de arquivos moderna ----------
# Se estiver instalado, o fzf (e o ff) passa a usar ele: fica mais rápido
# e pula .git e node_modules sozinho.
# No Pop!_OS o comando se chama 'fdfind'; o alias devolve o nome curto.
_FD=""
if _tem fdfind; then
    alias fd='fdfind'
    _FD="fdfind"
elif _tem fd; then
    _FD="fd"
fi
if [ -n "$_FD" ]; then
    export FZF_DEFAULT_COMMAND="$_FD --type f --hidden --exclude .git --exclude node_modules"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="$_FD --type d --hidden --exclude .git --exclude node_modules"
fi

# ---------- delta — o git diff com cores de código ----------
# O git diff ganha cores de código, número de linha e o nome do arquivo
# em destaque. Vale pra git diff, git show, git log -p e pros atalhos gd/gds.
# Só liga se estiver instalado — sem ele o git continua com o visual normal.
# As cores seguem o prompt: arquivo em ciano, trecho em lilás, + verde, − vermelho.
_DELTA_ESTILO=""
if _tem delta; then
    _DELTA_ESTILO="--line-numbers --hunk-header-style='file line-number syntax' \
--file-style='bold 51' --file-decoration-style='51 ul' \
--hunk-header-decoration-style='141 box' --hunk-header-file-style='bold 141' \
--hunk-header-line-number-style=141 \
--line-numbers-left-style=245 --line-numbers-right-style=245 --line-numbers-zero-style=245 \
--line-numbers-minus-style='bold 196' --line-numbers-plus-style='bold 46'"
    export GIT_PAGER="delta $_DELTA_ESTILO"
fi

# ---------- editor padrão ----------
# Quem abre editor sozinho (git commit sem -m, crontab -e…) usa o primeiro que existir
if [ -z "${EDITOR:-}" ]; then
    for _df_e in nvim vim nano vi; do
        if _tem "$_df_e"; then export EDITOR="$_df_e"; break; fi
    done
    unset _df_e
fi
