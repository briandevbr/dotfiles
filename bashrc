# ~/.bashrc: executado pelo bash(1) para shells sem login.
case $- in
    *i*) ;;
      *) return;;
esac

HISTCONTROL=ignoreboth:erasedups   # ignora linha com espaço no início e comando repetido
shopt -s histappend
HISTSIZE=50000                     # comandos lembrados na sessão (antes: 1000)
HISTFILESIZE=100000                # comandos guardados no arquivo (antes: 2000)
shopt -s checkwinsize

# Histórico com data e hora em cada comando
export HISTTIMEFORMAT="%d/%m/%Y %H:%M:%S  "

[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# ==========================================
# CONFIGURAÇÃO — mude aqui, não no meio do arquivo
# ==========================================

# Pasta raiz dos seus projetos. Usa $HOME em vez do caminho absoluto
# pra não quebrar se o nome de usuário mudar.
export DEV_HOME="$HOME/Documents/projetos"

# Duração padrão do timebox, em minutos
export TIMEBOX_MIN=30

# Onde fica o repositório dotfiles (o ~/.bashrc é um atalho pro bashrc de lá).
# O comando 'atualizar' baixa a versão nova desse repo.
export DOTFILES="$HOME/dotfiles"

# ==========================================
# PALETA — as mesmas cores vivas do prompt, no terminal inteiro
# 39  = azul vivo     (accent: títulos, "uso")       ← [brian]
# 141 = lilás         (seções dos painéis)           ← hora
# 51  = ciano         (nome dos comandos nos painéis) ← pasta
# 214 = laranja       (alerta, branch, comando original) ← branch
# 46  = verde         (sucesso)                      ← $
# 196 = vermelho      (erro)                         ← ✗ erro
# 245 = cinza         (texto de apoio)               ← " in "
# 252 = quase branco  (texto normal)
# ==========================================

# ANSI-C quoting: $'...' converte o \033 em um caractere ESC de verdade
# na hora da atribuição. Com "\033" entre aspas duplas, a variável guardaria
# a STRING literal - o 'echo -e' traduz na hora de imprimir, mas o 'printf'
# só traduz escapes que estão no formato, nunca nos argumentos.
C_ACCENT=$'\033[38;5;39m'
C_DIM=$'\033[38;5;245m'
C_TEXT=$'\033[38;5;252m'
C_WARN=$'\033[38;5;214m'
C_OK=$'\033[38;5;46m'
C_ERR=$'\033[38;5;196m'
C_SECAO=$'\033[1;38;5;141m'   # negrito: seção é título
C_CMD=$'\033[1;38;5;51m'      # negrito: nome de comando salta no painel
C_OFF=$'\033[00m'

# ==========================================
# UI — um estilo só pra todas as respostas do terminal
# Toda função usa esses helpers: mudou aqui, muda em tudo.
# Regra: texto variável vai SEMPRE como argumento (%s), nunca dentro
# do formato do printf — um '%' na mensagem quebraria a saída.
# ==========================================

_CL=$'\r\033[K'   # volta pro início da linha e limpa (apaga o "◌ carregando...")

# _feito "símbolo" "mensagem" ["detalhe"]  — resultado de sucesso
_feito() {
    printf "${_CL}  ${C_OK}%s${C_OFF}  ${C_TEXT}%s${C_OFF}" "$1" "$2"
    if [ -n "$3" ]; then printf "   ${C_DIM}%s${C_OFF}" "$3"; fi
    printf "\n"
}

# _ok "mensagem" ["detalhe"]
_ok() { _feito "✓" "$1" "$2"; }

# _err "o que deu errado" ["como resolver"]  — vai pro stderr e retorna 1
_err() {
    {
        printf "${_CL}  ${C_ERR}✗${C_OFF}  ${C_TEXT}%s${C_OFF}\n" "$1"
        if [ -n "$2" ]; then printf "     ${C_DIM}↳ %s${C_OFF}\n" "$2"; fi
    } >&2
    return 1
}

# _aviso "atenção" ["detalhe"]
_aviso() {
    printf "${_CL}  ${C_WARN}!${C_OFF}  ${C_TEXT}%s${C_OFF}\n" "$1"
    if [ -n "$2" ]; then printf "     ${C_DIM}↳ %s${C_OFF}\n" "$2"; fi
}

# _dica "texto"  — linha de apoio, discreta
_dica() { printf "     ${C_DIM}↳ %s${C_OFF}\n" "$*"; }

# _titulo "ícone" "ação" ["alvo"]  — abre uma operação que vai demorar
_titulo() {
    printf "  ${C_ACCENT}%s${C_OFF}  ${C_TEXT}%s${C_OFF}" "$1" "$2"
    if [ -n "$3" ]; then printf "  ${C_DIM}%s${C_OFF}" "$3"; fi
    printf "\n"
}

# _kv "rótulo" "valor"  — linha de detalhe alinhada (rótulos sem acento)
_kv() { printf "     ${C_DIM}%-9s${C_OFF} ${C_TEXT}%s${C_OFF}\n" "$1" "$2"; }

# _uso "sintaxe" ["explicação" ...]  — mostra como usar e retorna 1
_uso() {
    printf "  ${C_ACCENT}uso${C_OFF}  ${C_TEXT}%s${C_OFF}\n" "$1"
    shift
    local linha
    for linha in "$@"; do printf "       ${C_DIM}%s${C_OFF}\n" "$linha"; done
    return 1
}

# _confirma "pergunta"  — retorna 0 só se a resposta for s/S
_confirma() {
    local resposta
    printf "  ${C_WARN}?${C_OFF}  ${C_TEXT}%s${C_OFF} ${C_DIM}[s/N]${C_OFF} " "$1"
    read -r resposta
    [[ "$resposta" =~ ^[sS]$ ]]
}

_cancelado() { printf "  ${C_DIM}○  cancelado — nada foi mexido${C_OFF}\n"; }

# _pendente "texto"  — linha provisória sem \n; o próximo _feito/_err escreve por cima
_pendente() {
    if [ -t 1 ]; then printf "  ${C_DIM}◌  %s${C_OFF}" "$1"; fi
}

# _tempo_desde <inicio>  → "840ms" ou "2.3s"
# EPOCHREALTIME é do bash 5: mede tempo sem chamar o binário 'date'
_tempo_desde() {
    local us=$(( ${EPOCHREALTIME//[!0-9]/} - $1 ))
    if (( us < 1000000 )); then
        printf '%dms' $(( us / 1000 ))
    else
        printf '%d.%ds' $(( us / 1000000 )) $(( us % 1000000 / 100000 ))
    fi
}

# _plural 3 "commit" "commits"  → "3 commits"
_plural() {
    if [ "$1" -eq 1 ]; then printf '%s %s' "$1" "$2"; else printf '%s %s' "$1" "$3"; fi
}

# _linha "nome" "descrição"  — linha dos painéis dev/help
# Alinha contando LETRAS (${#1}), não bytes: o printf %-12s conta bytes,
# e 'ç', '·', '←' ocupam 2-3 bytes cada, desalinhando a coluna.
_linha() {
    local pad=$(( ${_LARG:-12} - ${#1} ))
    (( pad < 1 )) && pad=1
    printf "  ${C_CMD}%s${C_OFF}%*s ${C_TEXT}%s${C_OFF}\n" "$1" "$pad" "" "$2"
}

# _eq "git status"  — linha logo abaixo do _linha: o comando de verdade
# que o atalho roda por baixo (fica alinhada com a descrição)
_eq() {
    printf "  %*s ${C_DIM}↳${C_OFF} ${C_WARN}%s${C_OFF}\n" "${_LARG:-12}" "" "$1"
}

_secao()     { printf "\n${C_SECAO}  ▸ %s${C_OFF}\n" "$1"; }
_cabecalho() {
    printf "\n${C_ACCENT}\033[1m  ◈  %s${C_OFF}\n" "$1"
    printf "${C_DIM}  ────────────────────────────────────────${C_OFF}\n"
}

# ==========================================
# NVM - CARREGAMENTO LAZY (terminal mais rápido)
# ==========================================

export NVM_DIR="$HOME/.nvm"

lazy_load_nvm() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}
nvm()  { lazy_load_nvm; nvm "$@"; }
node() { lazy_load_nvm; node "$@"; }
npm()  { lazy_load_nvm; npm "$@"; }
npx()  { lazy_load_nvm; npx "$@"; }

# ==========================================
# BANNER DE ABERTURA
# ==========================================

# printf com %()T formata a data SEM chamar o binário 'date' —
# é builtin do bash, custo zero no startup.
# _BASHRC_CARREGADO: no 'source ~/.bashrc' (ou no atualizar) o banner não repete
if [ -z "$_BASHRC_CARREGADO" ]; then
    printf "\n  ${C_ACCENT}◈  GROUND CONTROL${C_OFF}   ${C_DIM}%(%a %d %b · %H:%M)T${C_OFF}\n" -1
    printf "  ${C_DIM}   all systems nominal — ${C_TEXT}dev${C_DIM} your tools · ${C_TEXT}help${C_DIM} the system${C_OFF}\n\n"
fi

# Pastas em ciano negrito (igual à pasta do prompt), links em lilás, executáveis em verde
export LS_COLORS="di=1;38;5;51:fi=38;5;252:ln=38;5;141:ex=1;38;5;46:*.sh=38;5;214:*.py=38;5;39:*.js=38;5;214:*.json=38;5;141:*.md=38;5;39"

# ==========================================
# FERRAMENTAS MODERNAS (FZF, ZOXIDE, EZA, BAT)
# ==========================================

if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
    alias cd='z'
fi

[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && \. /usr/share/doc/fzf/examples/key-bindings.bash
[ -f /usr/share/doc/fzf/examples/completion.bash ] && \. /usr/share/doc/fzf/examples/completion.bash

# Mesmas cores do prompt em hex: 39=#00afff 51=#00ffff 141=#af87ff 214=#ffaf00 46=#00ff00
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border=rounded \
--color=fg:#d0d0d0,bg:-1,hl:#00afff \
--color=fg+:#ffffff,bg+:#303030,hl+:#00ffff \
--color=info:#af87ff,prompt:#00afff,pointer:#ffaf00,marker:#00ff00,spinner:#af87ff,header:#af87ff,border:#585858"

if command -v eza &> /dev/null; then
    alias ls='eza --icons --group-directories-first --git'
    alias ll='eza -alF --icons --group-directories-first --git'
    alias la='eza -A --icons --group-directories-first --git'
    alias lt='eza --tree --icons --level=2 --git'
    alias tree='eza --tree --icons --group-directories-first --git'
    alias dir='eza --icons --group-directories-first --git'
fi

# Define _BAT com o nome real do binário (varia entre distros)
if command -v batcat &> /dev/null; then
    _BAT="batcat"
elif command -v bat &> /dev/null; then
    _BAT="bat"
fi

if [ -n "$_BAT" ]; then
    export BAT_THEME="Dracula"
    alias cat="$_BAT --paging=never"
    alias catp="$_BAT"
    # Preview colorido no Ctrl+T do fzf
    export FZF_CTRL_T_OPTS="--preview '$_BAT --color=always --style=numbers --line-range=:100 {}'"
fi

# fd (busca de arquivos moderna): se estiver instalado, o fzf passa a usar ele.
# Fica mais rápido e pula .git e node_modules sozinho.
# No Pop!_OS o comando se chama 'fdfind'; o alias devolve o nome curto.
if command -v fdfind &> /dev/null; then
    alias fd='fdfind'
    _FD="fdfind"
elif command -v fd &> /dev/null; then
    _FD="fd"
fi
if [ -n "$_FD" ]; then
    export FZF_DEFAULT_COMMAND="$_FD --type f --hidden --exclude .git --exclude node_modules"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="$_FD --type d --hidden --exclude .git --exclude node_modules"
fi

# delta: o git diff ganha cores de código, número de linha e o nome do arquivo
# em destaque. Vale pra git diff, git show, git log -p e pros atalhos gd/gds.
# Só liga se estiver instalado (sudo apt install git-delta) — sem ele o git
# continua com o visual normal, nada quebra.
# As cores seguem o prompt: arquivo em ciano, trecho em lilás, + verde, − vermelho.
if command -v delta &> /dev/null; then
    _DELTA_ESTILO="--line-numbers --hunk-header-style='file line-number syntax' \
--file-style='bold 51' --file-decoration-style='51 ul' \
--hunk-header-decoration-style='141 box' --hunk-header-file-style='bold 141' \
--hunk-header-line-number-style=141 \
--line-numbers-left-style=245 --line-numbers-right-style=245 --line-numbers-zero-style=245 \
--line-numbers-minus-style='bold 196' --line-numbers-plus-style='bold 46'"
    export GIT_PAGER="delta $_DELTA_ESTILO"
fi

# ==========================================
# TECLADO — Tab e setas mais espertos
# 2>/dev/null: fora de um terminal de verdade o bind só reclamaria
# ==========================================

bind 'set completion-ignore-case on'    2>/dev/null  # Tab ignora maiúscula: "doc" completa "Documents"
bind 'set show-all-if-ambiguous on'     2>/dev/null  # com várias opções, 1 Tab já lista todas
bind 'set colored-stats on'             2>/dev/null  # a lista do Tab vem colorida como o ls
bind '"\e[A": history-search-backward'  2>/dev/null  # ↑ com texto digitado: só comandos que começam com ele
bind '"\e[B": history-search-forward'   2>/dev/null  # ↓ volta na mesma busca
bind '"\eOA": history-search-backward'  2>/dev/null  # as mesmas setas, no outro modo que alguns terminais usam
bind '"\eOB": history-search-forward'   2>/dev/null

# ==========================================
# PROMPT
# Fica DEPOIS do zoxide de propósito: ele também usa o PROMPT_COMMAND,
# e o nosso hook precisa ser o primeiro a ler o $? do último comando.
# ==========================================

# Roda antes de cada prompt: guarda o erro do último comando e a branch atual
_prompt_hook() {
    local st=$?
    case "$st" in
        0|130|148) _PS1_ERRO="" ;;          # 130 = Ctrl+C, 148 = Ctrl+Z: foi você que parou, não é erro
        *)         _PS1_ERRO="  ✗ $st" ;;
    esac
    _PS1_BRANCH=$(git branch --show-current 2>/dev/null)
    [ -n "$_PS1_BRANCH" ] && _PS1_BRANCH=" $_PS1_BRANCH"
    history -a                               # salva o comando na hora: abas novas e o Ctrl+R já enxergam
    return "$st"                             # devolve o $? intacto pros próximos hooks
}

# O 'if' evita duplicar o hook quando você roda 'source ~/.bashrc'
if [[ "$PROMPT_COMMAND" != *_prompt_hook* ]]; then
    PROMPT_COMMAND="_prompt_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

# Cores do prompt: negrito + tons vivos, pra achar ele de relance no meio da saída
P_USER=$'\033[1;38;5;39m'     # azul vivo      [brian]
P_SEP=$'\033[0;38;5;245m'     # cinza          " in " (sem negrito: só separa)
P_HORA=$'\033[1;38;5;141m'    # lilás vivo     hora
P_PASTA=$'\033[1;38;5;51m'    # ciano vivo     pasta atual
P_BRANCH=$'\033[1;38;5;214m'  # laranja vivo   branch do git
P_ERRO=$'\033[1;38;5;196m'    # vermelho vivo  ✗ código do erro
P_CIFRAO=$'\033[1;38;5;46m'   # verde forte    $

# Linha 1: [brian] in 15:45:10  ~/pasta branch  ✗ erro
# Linha 2: só o $ verde
# Aspas simples: as variáveis são lidas a CADA prompt, não uma vez só.
# Todo código de cor fica entre \[ \] — sem isso o bash erra a largura
# da linha e o texto se embola quando o comando é comprido.
PS1='\[${P_USER}\][brian]\[${P_SEP}\] in \[${P_HORA}\]\t  \[${P_PASTA}\]\w\[${P_BRANCH}\]${_PS1_BRANCH}\[${P_ERRO}\]${_PS1_ERRO}\[${C_OFF}\]\n\[${P_CIFRAO}\]\$\[${C_OFF}\] '

# ==========================================
# SEGURANÇA — confirmação em comandos destrutivos
# Pede confirmação antes de apagar ou sobrescrever.
# As funções deste arquivo usam 'command rm/cp' para não
# serem afetadas: alias dentro de função expande na leitura.
# ==========================================

alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# ==========================================
# NAVEGAÇÃO
# ==========================================

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias c='clear'
alias p='builtin cd "$DEV_HOME"'

# _abrir "alvo" - abre no app padrão SOLTO do terminal.
# O xdg-open roda o app preso ao terminal: ele fica travado até a janela fechar
# e ainda despeja as mensagens do app ("Connecting to org.freedesktop.Tracker3...").
# setsid -f: o app vira um processo independente (fechar o terminal não fecha ele)
# </dev/null >/dev/null 2>&1: nada entra, nada sai na tela.
_abrir() { setsid -f xdg-open "$1" </dev/null >/dev/null 2>&1; }

# open - abre a pasta atual no gerenciador de arquivos e libera o terminal na hora.
# Com argumento abre o que você passar: open src · open foto.png · open https://...
unalias open 2>/dev/null                     # versão antiga era alias: tira antes de virar função
open() {
    local alvo="${1:-.}"
    if [[ "$alvo" != *://* ]] && [ ! -e "$alvo" ]; then
        _err "não encontrei: $alvo" "confira o nome (o Tab completa)"
        return 1
    fi
    _abrir "$alvo"
    if [ "$alvo" = "." ]; then
        _ok "abrindo" "${PWD/#$HOME/\~}"
    else
        _ok "abrindo" "$alvo"
    fi
}

# mkcd - cria a pasta e já entra nela
# Usa 'builtin cd' porque o alias cd='z' (zoxide) trabalha com histórico
# de pastas já visitadas - uma pasta recém-criada ainda não está lá.
mkcd() {
    if [ -z "$1" ]; then
        _uso "mkcd <nome-da-pasta>" "cria a pasta (e as do meio) e já entra nela"
        return 1
    fi
    if ! mkdir -p -- "$1" 2>/dev/null || ! builtin cd -- "$1"; then
        _err "não consegui criar '$1'" "confira se você tem permissão nesta pasta"
        return 1
    fi
    _ok "criada e acessada" "${PWD/#$HOME/\~}"
}

# proj - pula direto pra qualquer projeto via busca interativa
proj() {
    if [ ! -d "$DEV_HOME" ]; then
        _err "pasta de projetos não existe: ${DEV_HOME/#$HOME/\~}" "crie com: mkdir -p \"$DEV_HOME\""
        return 1
    fi
    if ! command -v fzf &> /dev/null; then
        _err "fzf não está instalado" "sudo apt install fzf"
        return 1
    fi

    local escolhido
    escolhido=$(find "$DEV_HOME" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null \
        | sort \
        | fzf --height=40% --reverse --prompt='projeto ❯ ' --border=rounded)

    [ -z "$escolhido" ] && return 0          # Esc: cancelou, sem drama
    builtin cd "$DEV_HOME/$escolhido" || return 1
    _ok "$escolhido" "${PWD/#$HOME/\~}"
}

# extract - descompacta qualquer formato sem você lembrar a flag certa
extract() {
    local formatos=".zip .tar.gz .tgz .tar.bz2 .tar.xz .tar .gz .bz2 .rar .7z"
    if [ -z "$1" ]; then
        _uso "extract <arquivo>" "$formatos"
        return 1
    fi
    if [ ! -f "$1" ]; then
        _err "arquivo não encontrado: $1"
        return 1
    fi

    _titulo "📦" "extraindo" "$(basename "$1")"

    case "$1" in
        *.tar.gz|*.tgz)   tar -xzf "$1"    ;;
        *.tar.bz2|*.tbz2) tar -xjf "$1"    ;;
        *.tar.xz)         tar -xJf "$1"    ;;
        *.tar)            tar -xf  "$1"    ;;
        *.gz)             gunzip   "$1"    ;;
        *.bz2)            bunzip2  "$1"    ;;
        *.zip)            unzip -q "$1"    ;;
        *.rar)
            if ! command -v unrar &> /dev/null; then
                _err "unrar não está instalado" "sudo apt install unrar"
                return 1
            fi
            unrar x "$1"
            ;;
        *.7z)
            if ! command -v 7z &> /dev/null; then
                _err "7z não está instalado" "sudo apt install p7zip-full"
                return 1
            fi
            7z x "$1"
            ;;
        *)
            _err "formato não reconhecido: $1" "$formatos"
            return 1
            ;;
    esac

    # O 'case' devolve o status do último comando que rodou dentro dele
    if [ $? -ne 0 ]; then
        _err "falhou ao extrair $(basename "$1")" "arquivo corrompido ou download incompleto?"
        return 1
    fi
    _ok "extraído" "${PWD/#$HOME/\~}"
}

# ff - busca arquivo (sem argumento) ou trecho de código (com argumento)
ff() {
    if ! command -v fzf &> /dev/null; then
        _err "fzf não está instalado" "sudo apt install fzf"
        return 1
    fi

    local preview_cmd="cat {}"
    [ -n "$_BAT" ] && preview_cmd="$_BAT --color=always --style=numbers {}"

    if [ -z "$1" ]; then
        # Modo 1: buscar arquivo pelo nome
        local arquivo
        arquivo=$(find . -type f -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null \
            | fzf --height=60% --reverse --border=rounded --prompt='arquivo ❯ ' \
                  --preview "$preview_cmd" --preview-window=right:60%)
        [ -n "$arquivo" ] && printf "  ${C_TEXT}%s${C_OFF}\n" "$arquivo"
        return 0
    fi

    # Modo 2: buscar trecho de código dentro dos arquivos
    _titulo "🔍" "procurando" "$1"
    printf "\n"
    if command -v rg &> /dev/null; then
        rg --line-number --color=always "$1"
    else
        grep -rn --color=always --exclude-dir=node_modules --exclude-dir=.git "$1" . 2>/dev/null
    fi || { _aviso "nada encontrado pra '$1'"; return 1; }
}

# ==========================================
# SISTEMA
# ==========================================

alias lspkg='apt-mark showmanual'
alias lsapp='flatpak list --app --user'

# _espaco_liberado <bytes-livres-antes>  — fecha remoções mostrando o ganho
_espaco_liberado() {
    local depois liberado
    depois=$(df --output=avail -B1 / | tail -1)
    liberado=$(( depois - $1 ))
    if [ "$liberado" -gt 0 ]; then
        _ok "removido" "$(numfmt --to=iec "$liberado") liberados"
    else
        _ok "removido"
    fi
}

# rmapp - remove app Flatpak mostrando espaço liberado
rmapp() {
    if [ "$#" -eq 0 ]; then
        _uso "rmapp <ID_DO_APP> [ID_2 ...]" "descubra o ID com: lsapp"
        return 1
    fi

    local antes
    antes=$(df --output=avail -B1 / | tail -1)

    _titulo "🗑 " "removendo" "$*"
    if ! flatpak uninstall --delete-data "$@" -y; then
        _err "não consegui remover" "confira o ID com: lsapp"
        return 1
    fi
    flatpak uninstall --unused -y > /dev/null 2>&1
    _espaco_liberado "$antes"
}

# rmpkg - remove pacote APT mostrando espaço liberado
rmpkg() {
    if [ "$#" -eq 0 ]; then
        _uso "rmpkg <PACOTE> [PACOTE_2 ...]" "descubra o nome com: lspkg"
        return 1
    fi

    local antes
    antes=$(df --output=avail -B1 / | tail -1)

    _titulo "🗑 " "removendo" "$*"
    if ! sudo apt purge "$@" -y; then
        _err "não consegui remover" "confira o nome com: lspkg"
        return 1
    fi
    sudo apt autoremove -y > /dev/null 2>&1
    _espaco_liberado "$antes"
}

# clean - limpeza geral com feedback por etapa
clean() {
    local inicio=$SECONDS
    local espaco_antes
    espaco_antes=$(df --output=avail -B1 / | tail -1)

    echo -e "${C_ACCENT}╭────────────────────────────────────────╮${C_OFF}"
    echo -e "${C_ACCENT}│${C_OFF}   🧹  LIMPEZA GERAL DO SISTEMA          ${C_ACCENT}│${C_OFF}"
    echo -e "${C_ACCENT}╰────────────────────────────────────────╯${C_OFF}"

    echo -e "\n${C_DIM}[1/4]${C_OFF} Pacotes órfãos e cache do APT..."
    local apt_antes apt_depois apt_liberado
    apt_antes=$(du -sb /var/cache/apt/archives 2>/dev/null | cut -f1)
    sudo apt autoremove --purge -y > /dev/null 2>&1
    sudo apt clean > /dev/null 2>&1
    apt_depois=$(du -sb /var/cache/apt/archives 2>/dev/null | cut -f1)
    apt_liberado=$(( ${apt_antes:-0} - ${apt_depois:-0} ))
    echo -e "  ${C_OK}✓${C_OFF} Cache do APT: $(numfmt --to=iec "${apt_liberado}") liberados"

    echo -e "\n${C_DIM}[2/4]${C_OFF} Logs antigos do systemd..."
    local journal_saida
    journal_saida=$(sudo journalctl --vacuum-time=7d 2>&1 | tail -1)
    echo -e "  ${C_OK}✓${C_OFF} ${journal_saida:-Nenhum log antigo encontrado}"

    echo -e "\n${C_DIM}[3/4]${C_OFF} Runtimes Flatpak não usados..."
    local flatpak_saida
    flatpak_saida=$(flatpak uninstall --unused -y 2>&1)
    if echo "$flatpak_saida" | grep -qi "nothing"; then
        echo -e "  ${C_OK}✓${C_OFF} Nada pra remover"
    else
        echo -e "  ${C_OK}✓${C_OFF} Runtimes órfãos removidos"
    fi

    echo -e "\n${C_DIM}[4/4]${C_OFF} Cache de miniaturas..."
    local thumb_tamanho
    thumb_tamanho=$(du -sb ~/.cache/thumbnails 2>/dev/null | cut -f1)
    command rm -rf ~/.cache/thumbnails/* 2>/dev/null
    echo -e "  ${C_OK}✓${C_OFF} Thumbnails: $(numfmt --to=iec "${thumb_tamanho:-0}") liberados"

    local espaco_depois total_liberado tempo_total
    espaco_depois=$(df --output=avail -B1 / | tail -1)
    total_liberado=$(( espaco_depois - espaco_antes ))
    tempo_total=$(( SECONDS - inicio ))

    echo -e "\n${C_ACCENT}╭────────────────────────────────────────╮${C_OFF}"
    if [ "$total_liberado" -gt 0 ]; then
        echo -e "${C_ACCENT}│${C_OFF}  💾  Total liberado: ${C_OK}$(numfmt --to=iec "$total_liberado")${C_OFF}"
    else
        echo -e "${C_ACCENT}│${C_OFF}  ✨  Sistema já estava limpo!"
    fi
    echo -e "${C_ACCENT}│${C_OFF}  ⏱   Levou ${tempo_total}s"
    echo -e "${C_ACCENT}╰────────────────────────────────────────╯${C_OFF}"
}

# port - mostra quem está ocupando uma porta; com -k, mata o processo
port() {
    local matar=0 porta="$1"

    if [ "$1" = "-k" ]; then
        matar=1
        porta="$2"
    fi

    if [ -z "$porta" ]; then
        _uso "port <número>" "port -k <número>   encerra quem está usando"
        return 1
    fi

    local info
    info=$(ss -lptnH "sport = :$porta" 2>/dev/null)

    if [ -z "$info" ]; then
        _ok "porta $porta livre"
        return 0
    fi

    local pid processo
    pid=$(grep -oP 'pid=\K[0-9]+' <<< "$info" | head -1)
    [ -n "$pid" ] && processo=$(ps -p "$pid" -o comm= 2>/dev/null)

    printf "  ${C_WARN}●${C_OFF}  ${C_TEXT}porta %s ocupada${C_OFF}   ${C_DIM}%s · pid %s${C_OFF}\n" \
        "$porta" "${processo:-processo de outro usuário}" "${pid:-?}"

    if [ "$matar" -eq 0 ]; then
        _dica "pra liberar: port -k $porta"
        return 0
    fi

    if [ -n "$pid" ] && kill "$pid" 2>/dev/null; then
        _ok "processo encerrado" "porta $porta liberada"
    else
        _err "não consegui encerrar" "processo de outro usuário? tente: sudo ss -lptn 'sport = :$porta'"
        return 1
    fi
}

# serve - sobe servidor HTTP na pasta atual (sem instalar nada)
serve() {
    local porta="${1:-8000}"

    if ! [[ "$porta" =~ ^[0-9]+$ ]]; then
        _uso "serve [porta]" "padrão: 8000"
        return 1
    fi
    if ! command -v python3 &> /dev/null; then
        _err "python3 não encontrado" "sudo apt install python3"
        return 1
    fi
    if [ -n "$(ss -lptnH "sport = :$porta" 2>/dev/null)" ]; then
        _err "porta $porta ocupada" "veja quem é com: port $porta  ·  ou use outra: serve 8080"
        return 1
    fi

    _titulo "🌐" "servindo" "${PWD/#$HOME/\~}"
    printf "     ${C_OK}http://localhost:%s${C_OFF}\n" "$porta"
    printf "     ${C_DIM}Ctrl+C pra parar${C_OFF}\n\n"

    python3 -m http.server "$porta" --bind 127.0.0.1
}

# timebox - cronômetro de foco com notificação ao fim
timebox() {
    local minutos="${1:-$TIMEBOX_MIN}"

    if ! [[ "$minutos" =~ ^[0-9]+$ ]]; then
        _uso "timebox [minutos]" "padrão: ${TIMEBOX_MIN}"
        return 1
    fi

    local fim
    fim=$(date -d "+${minutos} minutes" '+%H:%M' 2>/dev/null)

    _titulo "⏳" "timebox de ${minutos} min" "termina ${fim}"
    _dica "não saiu até lá? anota o gap e segue. revisita depois."

    # Roda em subshell de fundo e desanexa: o terminal continua livre
    (
        sleep $(( minutos * 60 ))
        notify-send -u critical "⏱ Timebox encerrado" \
            "Passaram ${minutos} minutos. Travou? Anota o gap e avança."
    ) & disown
}

# bkp - backup dos seus arquivos de configuração
bkp() {
    local destino="$HOME/dotfiles-backup/$(date +%Y-%m-%d_%H-%M)"
    if ! mkdir -p "$destino"; then
        _err "não consegui criar a pasta de backup" "$destino"
        return 1
    fi

    _titulo "💾" "backup de configurações"

    # Cada item: caminho-original|nome-no-backup|como aparece na tela
    local item origem nome rotulo copiados=0
    for item in \
        "$HOME/.bashrc|.bashrc|.bashrc" \
        "$HOME/.config/Code/User/settings.json|vscode-settings.json|settings.json (VS Code)" \
        "$HOME/.gitconfig|.gitconfig|.gitconfig" \
        "$HOME/.gitignore_global|.gitignore_global|.gitignore_global"
    do
        IFS='|' read -r origem nome rotulo <<< "$item"
        [ -f "$origem" ] || continue
        if command cp "$origem" "$destino/$nome"; then
            copiados=$((copiados + 1))
            printf "     ${C_OK}✓${C_OFF} ${C_TEXT}%s${C_OFF}\n" "$rotulo"
        else
            printf "     ${C_ERR}✗${C_OFF} ${C_TEXT}%s${C_OFF}\n" "$rotulo"
        fi
    done

    _ok "$(_plural "$copiados" "arquivo salvo" "arquivos salvos")" "${destino/#$HOME/\~}"
}

# atualizar - baixa a versão mais nova do teu terminal (repo dotfiles no GitHub),
# recarrega na hora e mostra o que mudou. Não precisa abrir outro terminal.
# Por baixo: git -C ~/dotfiles pull && source ~/.bashrc
atualizar() {
    if [ ! -d "$DOTFILES/.git" ]; then
        _err "não achei o repositório dotfiles em ${DOTFILES/#$HOME/\~}" \
             "instale com: git clone https://github.com/briandevbr/dotfiles ~/dotfiles"
        return 1
    fi
    # O ~/.bashrc tem que ser um atalho pro bashrc do repo, senão a atualização não chega nele
    if [ "$(readlink -f "$HOME/.bashrc")" != "$(readlink -f "$DOTFILES/bashrc")" ]; then
        _err "teu ~/.bashrc não tá ligado ao repositório" \
             "ligue uma vez só: ln -sf ~/dotfiles/bashrc ~/.bashrc"
        return 1
    fi
    if [ -n "$(git -C "$DOTFILES" status --porcelain 2>/dev/null)" ]; then
        _err "você mexeu no bashrc por aqui e isso não tá no GitHub" \
             "ver o que mudou: git -C ~/dotfiles diff  ·  descartar: git -C ~/dotfiles restore ."
        return 1
    fi

    local antes depois qtd msg t0=${EPOCHREALTIME//[!0-9]/}
    antes=$(git -C "$DOTFILES" rev-parse HEAD)
    _pendente "procurando atualização…"
    if ! git -C "$DOTFILES" pull --ff-only -q > /dev/null 2>&1; then
        _err "não consegui baixar a atualização" "tá sem internet? Se repetir, rode: git -C ~/dotfiles pull"
        return 1
    fi
    depois=$(git -C "$DOTFILES" rev-parse HEAD)

    if [ "$antes" = "$depois" ]; then
        _ok "já tá na versão mais nova" "$(git -C "$DOTFILES" log -1 --format='%h · %cr')"
        return 0
    fi

    qtd=$(git -C "$DOTFILES" rev-list --count "$antes..$depois")
    # shellcheck source=/dev/null
    source "$HOME/.bashrc"                   # recarrega aqui mesmo: as mudanças valem na hora
    _feito "⟳" "terminal atualizado" "$(_plural "$qtd" mudança mudanças) · $(_tempo_desde "$t0")"
    while IFS= read -r msg; do
        printf "     ${C_DIM}•${C_OFF} ${C_TEXT}%s${C_OFF}\n" "$msg"
    done < <(git -C "$DOTFILES" log --format='%s' "$antes..$depois")
    _dica "deu ruim? volta pra anterior: git -C ~/dotfiles reset --hard ${antes:0:7} && source ~/.bashrc"
}

# ==========================================
# GIT
# ==========================================

# Tira os aliases antigos antes de criar as funções com o mesmo nome.
# Sem isso, um 'source ~/.bashrc' num terminal já aberto quebra:
# o alias antigo expandiria no meio da definição da função.
unalias gs gl gd gds gb ga gaa gc gp gpl gco gcb gst gstp gundo 2>/dev/null

# _em_repo_git - guarda usada por todas as funções git
_em_repo_git() {
    git rev-parse --git-dir > /dev/null 2>&1 && return 0
    _err "aqui não é um repositório git" "entre na pasta do projeto ou rode: git init"
}

# Comandos que só MOSTRAM coisa: a própria saída do git já é o feedback.
# Viraram função só pra ganhar o erro bonito fora de um repositório.
gs()  { _em_repo_git && git status "$@"; }
gl()  { _em_repo_git && git log --oneline --graph --decorate --all "$@"; }

# gd / gds - sem argumento abrem a INTERFACE do diff (ver _diff_lista abaixo).
# Com argumento viram o git diff normal: gd src/app.js · gd --stat · gds arq
gd() {
    _em_repo_git || return 1
    if [ $# -eq 0 ] && [ -t 1 ] && command -v fzf &> /dev/null; then
        _diff_lista
    else
        git diff "$@"
    fi
}
gds() {
    _em_repo_git || return 1
    if [ $# -eq 0 ] && [ -t 1 ] && command -v fzf &> /dev/null; then
        _diff_lista --staged
    else
        git diff --staged "$@"
    fi
}

# _diff_lista [--staged] - a interface do gd/gds:
#   esquerda: os arquivos mudados com quantas linhas entraram (+) e saíram (−)
#   direita:  a prévia do diff do arquivo selecionado
#   Enter abre o diff completo em tela cheia (lado a lado se a tela for larga)
#   q volta pra lista · Esc sai
_diff_lista() {
    local staged="$1" rotulo="mudanças fora do stage"
    [ -n "$staged" ] && rotulo="o que vai no próximo commit"

    # --numstat: "linhas+  linhas−  arquivo" de cada arquivo (binário vem com "-")
    # --no-renames: arquivo renomeado aparece como apagado + novo (lista mais simples)
    local numstat
    numstat=$(git diff $staged --no-renames --numstat 2>/dev/null)

    if [ -z "$numstat" ]; then
        if [ -n "$staged" ]; then
            _ok "nada no stage ainda"
            _dica "põe arquivo no stage com: ga  (ou gaa pra tudo)"
        else
            _ok "nenhuma mudança fora do stage"
            [ -n "$(git diff --staged --name-only 2>/dev/null)" ] && _dica "o que já tá no stage: gds"
        fi
        _diff_novos "$staged"
        return 0
    fi

    # Monta as linhas da lista: "+12 −3     <TAB>arquivo" e soma o total.
    # Os números vêm primeiro, com largura fixa, pra coluna dos nomes ficar alinhada.
    local add del arq est pad linhas="" n=0 tot_add=0 tot_del=0
    while IFS=$'\t' read -r add del arq; do
        n=$((n + 1))
        if [ "$add" = "-" ]; then
            est="binário"
            pad=$(( 10 - ${#est} )); (( pad < 1 )) && pad=1
            linhas+="${C_DIM}${est}${C_OFF}$(printf '%*s' "$pad" '')"$'\t'"${arq}"$'\n'
        else
            tot_add=$((tot_add + add)); tot_del=$((tot_del + del))
            est="+${add} −${del}"
            pad=$(( 10 - ${#est} )); (( pad < 1 )) && pad=1
            linhas+="${C_OK}+${add}${C_OFF} ${C_ERR}−${del}${C_OFF}$(printf '%*s' "$pad" '')"$'\t'"${arq}"$'\n'
        fi
    done <<< "$numstat"

    # Prévia e tela cheia: com delta fica colorido; sem ele, o diff colorido do git.
    # "less -R" sem o -F: senão um diff curto fecha na hora e você nem vê a tela cheia.
    # > /dev/tty: a saída do fzf vai pro /dev/null lá embaixo, a tela cheia não pode ir junto.
    local previa cheia lado=""
    (( ${COLUMNS:-80} >= 140 )) && lado="--side-by-side"
    if command -v delta &> /dev/null; then
        previa="git diff $staged --no-renames --color=always -- {2} | delta --paging=never --width=\$FZF_PREVIEW_COLUMNS $_DELTA_ESTILO"
        cheia="git diff $staged --no-renames --color=always -- {2} | DELTA_PAGER='less -R' delta --paging=always $lado $_DELTA_ESTILO > /dev/tty"
    else
        previa="git diff $staged --no-renames --color=always -- {2}"
        cheia="git diff $staged --no-renames --color=always -- {2} | less -R > /dev/tty"
    fi

    printf '%s' "$linhas" | fzf --ansi --delimiter=$'\t' --height=100% --no-sort \
        --tabstop=1 --border=rounded \
        --border-label=" ${rotulo} ─ Enter: diff inteiro (q volta) · Esc: sai " \
        --header="$(_plural "$n" arquivo arquivos) · +${tot_add} −${tot_del}" \
        --prompt='arquivo ❯ ' \
        --preview="$previa" \
        --preview-window='right,65%,border-left,<50(down,65%,border-top)' \
        --bind="enter:execute($cheia)" > /dev/null

    _diff_novos "$staged"
    command -v delta &> /dev/null || _dica "pra cores de código e nº de linha no diff: sudo apt install git-delta"
    return 0
}

# _diff_novos [--staged] - lembra que arquivo novo não aparece no diff até o ga
_diff_novos() {
    [ -n "$1" ] && return 0
    local novos
    novos=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)
    (( novos > 0 )) && _dica "$(_plural "$novos" "arquivo novo" "arquivos novos") fora da lista — o diff só mostra depois do ga"
    return 0
}
gb()  { _em_repo_git && git branch "$@"; }

# _git - roda o git em silêncio.
# Deu certo: não mostra nada (quem chamou monta o resumo).
# Deu errado: mostra as linhas de erro do git formatadas. As linhas 'hint:'
# ficam de fora — nos casos comuns a função que chamou dá a dica em português.
# (Quer o texto completo? Roda o mesmo comando com 'git' puro.)
# A saída inteira fica em _GIT_SAIDA pra função que chamou poder ler.
_git() {
    local cod linha
    _GIT_SAIDA=$(git "$@" 2>&1)
    cod=$?
    if [ "$cod" -ne 0 ]; then
        {
            printf "${_CL}  ${C_ERR}✗${C_OFF}  ${C_TEXT}git %s falhou${C_OFF}\n" "$1"
            while IFS= read -r linha; do
                [[ -z "$linha" || "$linha" == hint:* ]] && continue
                printf "     ${C_DIM}│${C_OFF} %s\n" "$linha"
            done <<< "$_GIT_SAIDA"
        } >&2
    fi
    return "$cod"
}

# _numeros_stat "saída do --shortstat"  → "arquivos inserções remoções"
_numeros_stat() {
    local a=0 i=0 d=0
    [[ $1 =~ ([0-9]+)\ file ]]      && a=${BASH_REMATCH[1]}
    [[ $1 =~ ([0-9]+)\ insertion ]] && i=${BASH_REMATCH[1]}
    [[ $1 =~ ([0-9]+)\ deletion ]]  && d=${BASH_REMATCH[1]}
    echo "$a $i $d"
}

# _resumo_stage  → "+1 novo  ~3 alterados  −1 apagado" do que está no stage
_resumo_stage() {
    local a=0 m=0 d=0 st resto saida=""
    while IFS=$'\t' read -r st resto; do
        case "$st" in
            A*) a=$((a + 1)) ;;
            D*) d=$((d + 1)) ;;
            ?*) m=$((m + 1)) ;;
        esac
    done < <(git diff --cached --name-status 2>/dev/null)

    (( a > 0 )) && saida+="${C_OK}+$(_plural "$a" novo novos)${C_OFF}  "
    (( m > 0 )) && saida+="${C_WARN}~$(_plural "$m" alterado alterados)${C_OFF}  "
    (( d > 0 )) && saida+="${C_ERR}−$(_plural "$d" apagado apagados)${C_OFF}  "
    saida="${saida%  }"                      # tira o espaço sobrando no fim
    printf '%s' "${saida:-${C_DIM}vazio${C_OFF}}"
}

# _resumo_commit - cartão do último commit (usado por gc, gac e gamend)
_resumo_commit() {
    local arq ins del
    # LC_ALL=C: força o git em inglês pra leitura não depender do idioma do sistema
    read -r arq ins del < <(_numeros_stat "$(LC_ALL=C git show --shortstat --format= HEAD 2>/dev/null)")
    _kv "branch" "$(git branch --show-current)"
    printf "     ${C_DIM}%-9s${C_OFF} ${C_WARN}%s${C_OFF}\n" "hash" "$(git rev-parse --short HEAD)"
    printf "     ${C_DIM}%-9s${C_OFF} ${C_TEXT}%s${C_OFF}   ${C_OK}+%s${C_OFF} ${C_ERR}−%s${C_OFF}\n" \
        "arquivos" "$arq" "$ins" "$del"
    _kv "mensagem" "$(git log -1 --format=%s)"
}

# _ja_no_remoto - verdadeiro se o último commit já foi enviado pro GitHub
_ja_no_remoto() {
    git merge-base --is-ancestor HEAD '@{upstream}' 2>/dev/null
}

# ---------- dia a dia ----------

# ga - adiciona arquivos ao stage. Sem argumento: escolhe numa lista (Tab marca vários)
ga() {
    _em_repo_git || return 1

    if [ $# -eq 0 ]; then
        if ! command -v fzf &> /dev/null; then
            _uso "ga <arquivo> [arquivo2 ...]" "ga .   adiciona tudo desta pasta"
            return 1
        fi
        local escolhidos=()
        # -z/--read0/--print0: nomes separados por byte nulo, então espaço no nome não quebra
        mapfile -d '' -t escolhidos < <(
            git ls-files -z --modified --others --deleted --exclude-standard | sort -zu |
            fzf --multi --read0 --print0 --prompt='add ❯ ' --header='Tab marca · Enter confirma' \
                --preview 'git diff --color=always -- {} 2>/dev/null | head -100; git diff --quiet -- {} 2>/dev/null && head -60 {}'
        )
        [ ${#escolhidos[@]} -eq 0 ] && return 0     # Esc: cancelou, sem drama
        set -- "${escolhidos[@]}"
    fi

    _git add -- "$@" || return 1

    local lista=() f
    mapfile -t lista < <(git diff --cached --name-only -- "$@")
    _feito "+" "adicionado ao stage" "$(_plural "${#lista[@]}" arquivo arquivos)"
    for f in "${lista[@]:0:8}"; do
        printf "     ${C_OK}+${C_OFF} ${C_TEXT}%s${C_OFF}\n" "$f"
    done
    (( ${#lista[@]} > 8 )) && printf "     ${C_DIM}… e mais %s${C_OFF}\n" "$(( ${#lista[@]} - 8 ))"
    printf "     ${C_DIM}%-9s${C_OFF} %s\n" "stage" "$(_resumo_stage)"
}

# gaa - adiciona tudo
gaa() {
    _em_repo_git || return 1
    if [ -z "$(git status --porcelain)" ]; then
        _ok "nada pra adicionar" "árvore de trabalho limpa"
        return 0
    fi
    _git add --all || return 1
    printf "  ${C_OK}+${C_OFF}  ${C_TEXT}tudo no stage${C_OFF}   %s\n" "$(_resumo_stage)"
}

# gc - commit do que está no stage. Aspas opcionais: gc arruma o menu
gc() {
    if [ $# -eq 0 ]; then
        _uso 'gc "mensagem"' "aspas são opcionais: gc arruma o menu"
        return 1
    fi
    _em_repo_git || return 1
    if git diff --cached --quiet 2>/dev/null; then
        _err "nada no stage pra commitar" "use ga <arquivo> ou gaa antes — ou gac pra fazer tudo junto"
        return 1
    fi
    _git commit -m "$*" || return 1
    _feito "◆" "commit criado"
    _resumo_commit
}

# gac - add tudo + commit numa tacada só
gac() {
    if [ $# -eq 0 ]; then
        _uso 'gac "mensagem"' "add tudo + commit · aspas opcionais"
        return 1
    fi
    _em_repo_git || return 1
    if [ -z "$(git status --porcelain)" ]; then
        _err "nada pra commitar" "árvore de trabalho limpa"
        return 1
    fi
    _git add --all || return 1
    _git commit -m "$*" || return 1
    _feito "◆" "commit criado"
    _resumo_commit
}

# gamend - joga as mudanças atuais no último commit. Com mensagem, troca o texto dele
gamend() {
    _em_repo_git || return 1
    if ! git rev-parse -q --verify HEAD > /dev/null; then
        _err "ainda não existe commit pra emendar" "faça o primeiro com: gac \"mensagem\""
        return 1
    fi
    if [ $# -eq 0 ] && [ -z "$(git status --porcelain)" ]; then
        _err "nada pra emendar" "sem mudanças novas — pra só trocar a mensagem: gamend \"nova mensagem\""
        return 1
    fi

    local ja_enviado=0
    _ja_no_remoto && ja_enviado=1

    _git add --all || return 1
    if [ $# -eq 0 ]; then
        _git commit --amend --no-edit || return 1
    else
        _git commit --amend -m "$*" || return 1
    fi

    _feito "◆" "último commit atualizado"
    _resumo_commit
    if [ "$ja_enviado" -eq 1 ]; then
        _aviso "esse commit já estava no GitHub" "o próximo envio precisa ser: git push --force-with-lease"
    fi
}

# gundo - desfaz o último commit, mantém as alterações
gundo() {
    _em_repo_git || return 1
    if ! git rev-parse -q --verify HEAD~1 > /dev/null; then
        _err "não tem commit anterior pra voltar" "esse é o primeiro commit do repositório"
        return 1
    fi

    local hash msg ja_enviado=0
    hash=$(git rev-parse --short HEAD)
    msg=$(git log -1 --format=%s)
    _ja_no_remoto && ja_enviado=1

    _git reset --soft HEAD~1 || return 1
    _feito "↶" "commit desfeito" "$hash $msg"
    _dica "as mudanças voltaram pro stage — nada foi perdido"
    if [ "$ja_enviado" -eq 1 ]; then
        _aviso "esse commit já estava no GitHub" "se commitar de novo, o envio precisa ser: git push --force-with-lease"
    fi
}

# grst - tira do stage (desfaz um ga). A mudança continua no arquivo
grst() {
    if [ $# -eq 0 ]; then
        _uso "grst <arquivo>" "tira do stage — a mudança continua no arquivo" "grst .   tira tudo"
        return 1
    fi
    _em_repo_git || return 1
    _git restore --staged -- "$@" || return 1
    _feito "−" "fora do stage" "$*"
    _dica "a mudança continua no arquivo, só não entra no próximo commit"
}

# grs - descarta as mudanças do arquivo (volta pro último commit). Pede confirmação
grs() {
    if [ $# -eq 0 ]; then
        _uso "grs <arquivo>" "joga fora as mudanças e volta o arquivo pro último commit"
        return 1
    fi
    _em_repo_git || return 1
    if ! _confirma "descartar as mudanças de $*? não tem volta"; then
        _cancelado
        return 0
    fi
    _git restore -- "$@" || return 1
    _feito "↶" "mudanças descartadas" "$*"
}

# gst - guarda as mudanças (inclusive arquivos novos) pra limpar a mesa
gst() {
    _em_repo_git || return 1
    local qtd
    qtd=$(git status --porcelain | wc -l)
    if [ "$qtd" -eq 0 ]; then
        _ok "nada pra guardar" "árvore de trabalho limpa"
        return 0
    fi
    # -u inclui arquivos novos: sem ele, arquivo recém-criado fica pra trás
    if [ $# -gt 0 ]; then
        _git stash push -u -m "$*" || return 1
    else
        _git stash push -u || return 1
    fi
    _feito "▣" "$(_plural "$qtd" "arquivo guardado" "arquivos guardados")" "stash@{0}"
    _dica "recupere com: gstp"
}

# gstp - recupera o último stash
gstp() {
    _em_repo_git || return 1
    if [ -z "$(git stash list)" ]; then
        _err "nada guardado no stash" "guarde mudanças com: gst"
        return 1
    fi
    local desc
    desc=$(git stash list -1 --format=%s)
    if ! _git stash pop "$@"; then
        if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
            _dica "conflito! o stash continua salvo — resolva e depois rode: git stash drop"
        fi
        return 1
    fi
    _feito "↺" "mudanças recuperadas" "$desc"
}

# gsl - lista o que está guardado no stash
gsl() {
    _em_repo_git || return 1
    if [ -z "$(git stash list)" ]; then
        _ok "stash vazio" "nada guardado"
        return 0
    fi
    local ref quando msg
    printf "\n"
    while IFS=$'\t' read -r ref quando msg; do
        printf "  ${C_WARN}%-11s${C_OFF} ${C_DIM}%-15s${C_OFF} ${C_TEXT}%s${C_OFF}\n" "$ref" "$quando" "$msg"
    done < <(git stash list --format='%gd%x09%cr%x09%s')
    printf "\n"
}

# ---------- branches e remoto ----------

# gp - push. Branch nova é publicada sozinha na primeira vez
gp() {
    _em_repo_git || return 1
    local t0=${EPOCHREALTIME//[!0-9]/}

    # Com argumentos (ex: gp origin main): repassa direto, sem mágica
    if [ $# -gt 0 ]; then
        _pendente "enviando..."
        _git push "$@" || return 1
        _feito "↑" "push feito" "$(_tempo_desde "$t0")"
        return 0
    fi

    local branch upstream qtd
    branch=$(git branch --show-current)
    if [ -z "$branch" ]; then
        _err "você não está em nenhuma branch (HEAD solto)" "entre numa com: gco <branch>"
        return 1
    fi

    # Só conta se a branch remota existir de verdade: num repositório
    # recém-clonado e ainda vazio, o upstream vem configurado mas não existe
    if git rev-parse -q --verify '@{upstream}' > /dev/null 2>&1; then
        upstream=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
    fi

    # Primeira vez da branch: publica e liga a local à remota (-u)
    if [ -z "$upstream" ]; then
        _pendente "publicando $branch..."
        if ! _git push -u origin "$branch"; then
            [[ $_GIT_SAIDA == *"'origin'"* ]] && _dica "conecte o repo ao GitHub: git remote add origin <url>"
            return 1
        fi
        _feito "↑" "branch publicada" "$branch → origin/$branch · $(_tempo_desde "$t0")"
        return 0
    fi

    qtd=$(git rev-list --count '@{upstream}..HEAD' 2>/dev/null)
    if [ "${qtd:-0}" -eq 0 ]; then
        _ok "nada pra enviar" "$branch já está igual a $upstream"
        return 0
    fi

    _pendente "enviando $(_plural "$qtd" commit commits)..."
    if ! _git push; then
        [[ $_GIT_SAIDA == *"rejected"* ]] && _dica "o remoto tem commits que você não tem — rode gpl e depois gp"
        return 1
    fi
    _feito "↑" "$(_plural "$qtd" "commit enviado" "commits enviados")" "$branch → $upstream · $(_tempo_desde "$t0")"
}

# gpl - pull com resumo do que chegou
gpl() {
    _em_repo_git || return 1
    local t0=${EPOCHREALTIME//[!0-9]/} antes depois
    antes=$(git rev-parse -q --verify HEAD)

    _pendente "buscando novidades..."
    # GIT_MERGE_AUTOEDIT=no: se o pull gerar merge, não abre editor no meio do caminho
    if ! GIT_MERGE_AUTOEDIT=no _git pull "$@"; then
        if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
            _dica "conflito! arrume os arquivos marcados e finalize com: gaa e gc \"merge\""
        elif [[ $_GIT_SAIDA == *"divergent"* ]]; then
            _dica "local e remoto divergiram. Configure uma vez: git config --global pull.rebase false"
        elif [[ $_GIT_SAIDA == *"no tracking information"* ]]; then
            _dica "essa branch ainda não existe no remoto — publique com: gp"
        fi
        return 1
    fi

    depois=$(git rev-parse -q --verify HEAD)
    if [ "$antes" = "$depois" ]; then
        _ok "já estava em dia" "nada novo no remoto · $(_tempo_desde "$t0")"
        return 0
    fi

    local qtd detalhe tempo arq ins del
    tempo=$(_tempo_desde "$t0")
    if [ -n "$antes" ]; then
        qtd=$(git rev-list --count "$antes..$depois")
        read -r arq ins del < <(_numeros_stat "$(LC_ALL=C git diff --shortstat "$antes" "$depois")")
        detalhe="$(_plural "$arq" arquivo arquivos) · +$ins −$del · $tempo"
    else
        qtd=$(git rev-list --count HEAD)
        detalhe="$tempo"
    fi
    _feito "↓" "$(_plural "$qtd" "commit recebido" "commits recebidos")" "$detalhe"
}

# gf - confere o remoto sem mexer em nada seu
gf() {
    _em_repo_git || return 1
    local t0=${EPOCHREALTIME//[!0-9]/} atras

    _pendente "conferindo o remoto..."
    _git fetch --prune "$@" || return 1

    atras=$(git rev-list --count 'HEAD..@{upstream}' 2>/dev/null)
    if [ -z "$atras" ]; then
        _ok "fetch feito" "esta branch ainda não está no remoto · $(_tempo_desde "$t0")"
    elif [ "$atras" -eq 0 ]; then
        _ok "tudo em dia" "nada novo no remoto · $(_tempo_desde "$t0")"
    else
        _feito "↓" "$(_plural "$atras" "commit novo" "commits novos") no remoto" "$(_tempo_desde "$t0")"
        _dica "traga com: gpl"
    fi
}

# gco - troca de branch. Sem argumento: escolhe numa lista
gco() {
    _em_repo_git || return 1

    if [ $# -eq 0 ]; then
        if ! command -v fzf &> /dev/null; then
            _uso "gco <branch>"
            return 1
        fi
        local escolhida
        escolhida=$(git branch --format='%(refname:short)' \
            | grep -vx -- "$(git branch --show-current)" \
            | fzf --prompt='branch ❯ ' --preview 'git log --oneline --color=always -15 {}')
        [ -z "$escolhida" ] && return 0
        set -- "$escolhida"
    fi

    local antes depois
    antes=$(git branch --show-current)
    if ! _git checkout "$@"; then
        [[ $_GIT_SAIDA == *"would be overwritten"* ]] && _dica "guarde as mudanças antes: gst → gco → gstp"
        return 1
    fi
    depois=$(git branch --show-current)

    if [ -n "$depois" ] && [ "$antes" != "$depois" ]; then
        _feito "⇄" "agora em $depois" "saiu de ${antes:-HEAD solto}"
    else
        _ok "checkout feito" "$*"
    fi
}

# gcb - cria branch a partir da atual e já entra nela
gcb() {
    if [ -z "$1" ]; then
        _uso "gcb <nome-da-branch>" "cria a partir da branch atual e já entra nela"
        return 1
    fi
    _em_repo_git || return 1
    local origem
    origem=$(git branch --show-current)
    _git checkout -b "$@" || return 1
    _feito "🌿" "branch $1 criada" "a partir de ${origem:-HEAD} · você já está nela"
    _dica "publique quando quiser com: gp"
}

# gnew - cria branch local e já publica no remoto
gnew() {
    if [ -z "$1" ]; then
        _uso "gnew <nome-da-branch>" "cria, entra e já publica no remoto"
        return 1
    fi
    _em_repo_git || return 1

    local origem t0=${EPOCHREALTIME//[!0-9]/}
    origem=$(git branch --show-current)

    _git checkout -b "$1" || return 1
    _feito "🌿" "branch $1 criada" "a partir de ${origem:-HEAD}"

    _pendente "publicando..."
    if ! _git push -u origin "$1"; then
        _dica "a branch local existe, só o envio falhou — publique depois com: gp"
        return 1
    fi
    _feito "↑" "publicada no remoto" "origin/$1 · $(_tempo_desde "$t0")"
}

# gin - mostra os commits que VÃO ENTRAR na branch atual se você der merge de outra.
# Bom costume: roda o gin antes do gm pra saber o que vem.
#   gin feature/x     → os commits da feature/x que a branch atual ainda não tem
#   gin origin/main   → também funciona com branch do GitHub (depois de um gf)
#   gin               → escolhe a branch numa lista, com a prévia dos commits
# Por baixo: git log HEAD..branch --oneline
#   HEAD..branch = "o que tem na branch e NÃO tem em mim (HEAD)"
gin() {
    _em_repo_git || return 1
    local alvo="$1" atual
    atual=$(git branch --show-current)
    atual="${atual:-HEAD}"                  # HEAD solto (sem branch): usa o commit atual

    if [ -z "$alvo" ]; then
        if ! command -v fzf &> /dev/null; then
            _uso "gin <branch>" "mostra os commits que entram na $atual com um merge"
            return 1
        fi
        # Branches locais e do GitHub, menos a atual e o "origin/HEAD" (é só um apelido)
        alvo=$(git for-each-ref --format='%(refname)' refs/heads refs/remotes 2>/dev/null \
            | grep -v '/HEAD$' \
            | sed 's#^refs/heads/##; s#^refs/remotes/##' \
            | grep -vx -- "$atual" \
            | fzf --height=60% --reverse --border=rounded --prompt="entra na $atual ❯ " \
                  --header='a prévia mostra os commits que entrariam' \
                  --preview "git log --oneline --color=always HEAD..{} | head -50; [ -z \"\$(git rev-list -1 HEAD..{})\" ] && echo 'nada novo: $atual já tem tudo'")
        [ -z "$alvo" ] && return 0          # Esc: cancelou
    fi

    if ! git rev-parse -q --verify "${alvo}^{commit}" > /dev/null; then
        _err "branch '$alvo' não existe" "veja as locais com: gb  ·  as do GitHub: git branch -r"
        return 1
    fi

    local qtd
    qtd=$(git rev-list --count "HEAD..$alvo")
    if [ "$qtd" -eq 0 ]; then
        _ok "nada novo pra entrar" "$atual já tem tudo de $alvo"
        return 0
    fi

    # Resumo do código que vem junto (três pontos = só o que mudou na outra branch)
    local arq ins del
    read -r arq ins del < <(_numeros_stat "$(LC_ALL=C git diff --shortstat "HEAD...$alvo" 2>/dev/null)")

    _titulo "⇉" "$(_plural "$qtd" "commit entra" "commits entram") na $atual" \
        "vindo de $alvo · $(_plural "$arq" arquivo arquivos) · +$ins −$del"
    git --no-pager log --oneline --color=always -30 "HEAD..$alvo" | sed 's/^/     /'
    (( qtd > 30 )) && _dica "… e mais $((qtd - 30)). Lista inteira: git log HEAD..$alvo --oneline"
    _dica "ver o código que vem: git diff HEAD...$alvo  ·  trazer: gm $alvo"
}

# gm - traz os commits de outra branch pra atual (merge)
gm() {
    if [ -z "$1" ]; then
        _uso "gm <branch>" "traz os commits da <branch> pra branch atual"
        return 1
    fi
    _em_repo_git || return 1

    local atual qtd
    atual=$(git branch --show-current)
    qtd=$(git rev-list --count "HEAD..$1" 2>/dev/null)
    if [ -z "$qtd" ]; then
        _err "branch '$1' não existe" "veja as branches com: gb"
        return 1
    fi
    if [ "$qtd" -eq 0 ]; then
        _ok "nada pra trazer" "$atual já tem tudo de $1"
        return 0
    fi

    if ! GIT_MERGE_AUTOEDIT=no _git merge "$1"; then
        if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
            _dica "conflito! arrume os arquivos marcados e finalize com: gaa e gc \"merge $1\""
            _dica "pra desistir do merge: git merge --abort"
        fi
        return 1
    fi
    _feito "⇉" "merge feito" "$1 → $atual · $(_plural "$qtd" commit commits)"
}

# gbd - apaga branch local (só se já foi mergeada — o git protege)
gbd() {
    if [ -z "$1" ]; then
        _uso "gbd <branch>" "apaga a branch local"
        return 1
    fi
    _em_repo_git || return 1
    if [ "$1" = "$(git branch --show-current)" ]; then
        _err "não dá pra apagar a branch onde você está" "troque antes com: gco <outra-branch>"
        return 1
    fi
    if ! _git branch -d "$1"; then
        [[ $_GIT_SAIDA == *"not fully merged"* ]] && _dica "ela tem commits que não foram mergeados. Tem certeza? git branch -D $1"
        return 1
    fi
    _feito "−" "branch $1 apagada"
}

# gclean - remove branches locais já mergeadas (com confirmação)
gclean() {
    _em_repo_git || return 1

    # ^...$ compara o nome INTEIRO: antes, 'fix-main-menu' também escapava
    local branches
    branches=$(git branch --merged | grep -vE '^\*|^[[:space:]]*(main|master|develop)$' | sed 's/^[[:space:]]*//')

    if [ -z "$branches" ]; then
        _ok "nada pra limpar" "nenhuma branch mergeada sobrando"
        return 0
    fi

    local total b
    total=$(printf '%s\n' "$branches" | wc -l)

    _titulo "🧹" "branches já mergeadas"
    while read -r b; do
        printf "     ${C_DIM}•${C_OFF} ${C_TEXT}%s${C_OFF}\n" "$b"
    done <<< "$branches"

    if _confirma "apagar $(_plural "$total" branch branches)?"; then
        printf '%s\n' "$branches" | xargs git branch -d > /dev/null 2>&1
        _ok "$(_plural "$total" "branch apagada" "branches apagadas")"
    else
        _cancelado
    fi
}

# gcl - clona e já entra na pasta
gcl() {
    if [ -z "$1" ]; then
        _uso "gcl <url> [pasta]" "clona o repositório e já entra nele"
        return 1
    fi

    local url="$1" pasta t0=${EPOCHREALTIME//[!0-9]/}
    pasta="${2:-$(basename "${url%.git}")}"

    if [ -e "$pasta" ]; then
        _err "já existe '$pasta' aqui" "escolha outro nome: gcl <url> <pasta>"
        return 1
    fi

    _pendente "clonando $pasta..."
    _git clone "$url" "$pasta" || return 1
    builtin cd "$pasta" || return 1
    _feito "↓" "clonado" "$pasta · $(_plural "$(git ls-files | wc -l)" arquivo arquivos) · $(_tempo_desde "$t0")"
}

# hub - abre o repositório atual no navegador
hub() {
    _em_repo_git || return 1

    local remoto
    remoto=$(git remote get-url origin 2>/dev/null)
    if [ -z "$remoto" ]; then
        _err "esse repositório não tem remoto 'origin'" "conecte com: git remote add origin <url>"
        return 1
    fi

    # Normaliza a URL: SSH (git@host:user/repo.git) vira HTTPS de navegador
    local url="${remoto%.git}"               # tira o .git do final
    if [[ "$url" == git@* ]]; then
        url="${url#git@}"                    # tira o 'git@'
        url="https://${url/://}"             # troca o ':' por '/'
    fi

    xdg-open "$url" > /dev/null 2>&1 & disown
    _feito "🔗" "abrindo no navegador" "$url"
}

# ==========================================
# NODE / NPM — atalhos de desenvolvimento
# Só rodam dentro de um projeto (pasta com package.json ou qualquer
# subpasta dele). Fora de um, o npm criaria package.json e node_modules
# no lugar errado — tipo direto na sua home.
# A saída do próprio npm já é o feedback.
# ==========================================

# Tira aliases antigos com esses nomes (se existirem) antes de criar as funções
unalias ni nid nr nrd ns nt nrb 2>/dev/null

# _raiz_node - sobe as pastas até achar um package.json
_raiz_node() {
    local d="$PWD"
    while :; do
        if [ -f "$d/package.json" ]; then
            printf '%s' "${d:-/}"
            return 0
        fi
        if [ -z "$d" ] || [ "$d" = "/" ]; then return 1; fi
        d="${d%/*}"
    done
}

# _em_projeto_node - guarda usada por todos os atalhos npm
_em_projeto_node() {
    _raiz_node > /dev/null && return 0
    _err "aqui não é um projeto node (não achei package.json)" "entre na pasta do projeto — ou crie um aqui com: npkg"
}

ni()  { _em_projeto_node && npm install "$@"; }       # instala tudo do package.json · ni pacote: instala um
nr()  { _em_projeto_node && npm run "$@"; }           # sozinho lista os scripts · nr nome: roda um
nrd() { _em_projeto_node && npm run dev "$@"; }       # npm run dev
nrb() { _em_projeto_node && npm run build "$@"; }     # npm run build
ns()  { _em_projeto_node && npm start "$@"; }         # npm start
nt()  { _em_projeto_node && npm test "$@"; }          # npm test

# nid - instala um pacote só pra desenvolvimento (-D)
nid() {
    if [ $# -eq 0 ]; then
        _uso "nid <pacote>" "instala como dependência de desenvolvimento (ex: nid eslint)"
        return 1
    fi
    _em_projeto_node && npm install --save-dev "$@"
}

# _nome_npm "Minha Pizzaria" → "minha-pizzaria"
# Regras do npm: minúsculas, sem espaço/acento, não começa com . ou _, até 214 letras
_nome_npm() {
    local n
    n=$(printf '%s' "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null)
    n="${n,,}"                                          # tudo minúsculo
    n="${n//[[:space:]]/-}"                             # espaço vira hífen
    n=$(printf '%s' "$n" | sed 's/[^a-z0-9._~-]//g; s/^[._-]*//; s/--*/-/g; s/-$//')
    n="${n:0:214}"
    printf '%s' "${n:-meu-projeto}"
}

# _json_txt "texto" → texto com \ e " escapados pra caber numa string JSON
_json_txt() { local t="${1//\\/\\\\}"; printf '%s' "${t//\"/\\\"}"; }

# npkg - cria um package.json base na pasta atual (nunca sobrescreve)
#   npkg           → o nome do projeto vem do nome da pasta
#   npkg meu-app   → usa o nome que você passar
npkg() {
    if [ -e package.json ]; then
        _err "já existe um package.json aqui" "não sobrescrevo — edite ele ou apague antes"
        return 1
    fi
    if [ "$PWD" = "$HOME" ]; then
        _err "você está na home, não numa pasta de projeto" "entre nela antes: p · proj · mkcd nome"
        return 1
    fi

    local raiz
    if raiz=$(_raiz_node); then
        _aviso "esta pasta já fica dentro de outro projeto node" "${raiz/#$HOME/\~}/package.json"
        _confirma "criar outro package.json aqui mesmo assim?" || { _cancelado; return 0; }
    fi

    local nome autor
    nome=$(_nome_npm "${1:-${PWD##*/}}")
    autor=$(git config user.name 2>/dev/null)

    # printf em vez de cat: o 'cat' deste arquivo é o bat
    if ! printf '%s\n' \
        '{' \
        "  \"name\": \"$(_json_txt "$nome")\"," \
        '  "version": "1.0.0",' \
        '  "description": "",' \
        '  "type": "module",' \
        '  "main": "index.js",' \
        '  "scripts": {' \
        '    "start": "node index.js",' \
        '    "dev": "node --watch index.js",' \
        '    "test": "node --test"' \
        '  },' \
        '  "keywords": [],' \
        "  \"author\": \"$(_json_txt "${autor:-David Brian}")\"," \
        '  "license": "MIT"' \
        '}' > package.json
    then
        _err "não consegui criar o package.json" "confira se você tem permissão nesta pasta"
        return 1
    fi

    _ok "package.json criado" "$nome"
    _kv "tipo" "módulos com import/export  (\"type\": \"module\")"
    _kv "scripts" "ns → node index.js · nrd → recarrega sozinho · nt → testes"
    [ -f index.js ] || _dica "falta o index.js: touch index.js  — depois é só nrd"
}

# ==========================================
# PAINÉIS
# ==========================================

# status - panorama completo do ambiente
status() {
    local L="  ${C_DIM}%-11s${C_OFF} %s\n"

    _cabecalho "ENVIRONMENT STATUS"

    # --- LOCAL ---
    _secao "local"
    printf "$L" "pasta"   "${C_TEXT}$(pwd)${C_OFF}"

    # --- GIT ---
    _secao "git"
    if git rev-parse --git-dir > /dev/null 2>&1; then
        local branch pendentes ultimo divergencia
        branch=$(git branch --show-current)
        pendentes=$(git status --porcelain | wc -l)
        ultimo=$(git log -1 --format='%h  %s  (%cr)' 2>/dev/null)

        printf "$L" "branch" "${C_WARN}${branch}${C_OFF}"

        if [ "$pendentes" -eq 0 ]; then
            printf "$L" "mudanças" "${C_OK}árvore limpa${C_OFF}"
        else
            printf "$L" "mudanças" "${C_WARN}${pendentes} arquivo(s) pendente(s)${C_OFF}"
        fi

        # left-right conta commits só do remoto (atrás) e só locais (à frente)
        divergencia=$(git rev-list --count --left-right '@{upstream}...HEAD' 2>/dev/null)
        if [ -n "$divergencia" ]; then
            local atras frente
            atras=$(echo "$divergencia" | cut -f1)
            frente=$(echo "$divergencia" | cut -f2)
            printf "$L" "remoto" "${C_TEXT}↓${atras} atrás  ↑${frente} à frente${C_OFF}"
        else
            printf "$L" "remoto" "${C_DIM}sem upstream configurado${C_OFF}"
        fi

        [ -n "$ultimo" ] && printf "$L" "último" "${C_TEXT}${ultimo}${C_OFF}"
    else
        printf "$L" "" "${C_DIM}não é um repositório git${C_OFF}"
    fi

    # --- PROJETO ---
    _secao "projeto"
    if [ -f package.json ]; then
        local nome_pkg versao_pkg deps
        nome_pkg=$(grep -m1 '"name"' package.json | sed 's/.*: *"\(.*\)".*/\1/')
        versao_pkg=$(grep -m1 '"version"' package.json | sed 's/.*: *"\(.*\)".*/\1/')
        printf "$L" "package" "${C_TEXT}${nome_pkg} v${versao_pkg}${C_OFF}"

        if [ -d node_modules ]; then
            deps=$(find node_modules -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
            printf "$L" "node_modules" "${C_TEXT}${deps} pacote(s)${C_OFF}"
        else
            printf "$L" "node_modules" "${C_WARN}ausente — rode npm install${C_OFF}"
        fi
    else
        printf "$L" "" "${C_DIM}sem package.json nesta pasta${C_OFF}"
    fi

    # --- RUNTIME ---
    _secao "runtime"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        # Lê do disco pra NÃO disparar o lazy load do nvm
        local node_versao
        node_versao=$(cat "$NVM_DIR/alias/default" 2>/dev/null)
        printf "$L" "node (nvm)" "${C_TEXT}${node_versao:-sem default definido}${C_OFF}"
    else
        printf "$L" "node" "${C_DIM}nvm não encontrado${C_OFF}"
    fi
    printf "$L" "git" "${C_TEXT}$(git --version | awk '{print $3}')${C_OFF}"

    # --- MÁQUINA ---
    _secao "máquina"
    printf "$L" "disco"   "${C_TEXT}$(df -h / | awk 'NR==2 {print $4" livres ("$5" em uso)"}')${C_OFF}"
    printf "$L" "memória" "${C_TEXT}$(free -h --si | awk 'NR==2 {print $3" de "$2" em uso"}')${C_OFF}"
    printf "$L" "uptime"  "${C_TEXT}$(uptime -p | sed 's/^up //')${C_OFF}"

    if [ -d /sys/class/power_supply/BAT0 ]; then
        local carga estado icone
        carga=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
        estado=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
        if [ "$estado" = "Charging" ]; then icone="⚡"; else icone="🔋"; fi
        if [ "${carga:-100}" -lt 20 ] && [ "$estado" != "Charging" ]; then
            printf "$L" "bateria" "${C_WARN}${icone} ${carga}% — conecte o carregador${C_OFF}"
        else
            printf "$L" "bateria" "${C_TEXT}${icone} ${carga}%${C_OFF}"
        fi
    fi

    echo ""
}

# dev - lista SÓ os comandos personalizados deste terminal
#   dev          → tudo
#   dev git      → só uma seção (Tab completa os nomes)
# Embaixo de cada atalho, em laranja, vem o comando original que ele roda.
_DEV_SECOES=(nav arquivos dev git remoto node sistema)

_dev_secao() {
    case "$1" in
        nav)
            _secao "navegação"
            _linha "p"             "vai direto pra pasta de projetos"
            _eq    "cd ${DEV_HOME/#$HOME/\~}"
            _linha "proj"          "lista teus projetos com busca — Enter entra no escolhido"
            _linha "mkcd nome"     "cria a pasta (e as do meio) e já entra nela"
            _eq    "mkdir -p nome && cd nome"
            _linha "cd nome"       "pula pra uma pasta que você já visitou, de qualquer lugar"
            _eq    "z nome  (zoxide)"
            _linha "zi"            "mostra as pastas já visitadas numa lista com busca"
            _linha ".. / ..."      "sobe 1 ou 2 pastas"
            _eq    "cd ..  ·  cd ../.."
            _linha "open"          "abre a pasta atual no gerenciador, sem travar o terminal"
            _eq    "xdg-open ."
            _linha "open arq"      "abre arquivo, pasta ou link no app padrão"
            _linha "c"             "limpa a tela"
            _eq    "clear"
            ;;
        arquivos)
            _secao "arquivos"
            _linha "ff"            "busca arquivo pelo nome, com prévia do conteúdo"
            _linha "ff texto"      "acha em quais arquivos (e linhas) esse texto aparece"
            _eq    'grep -rn "texto" .'
            _linha "extract arq"   "descompacta zip, tar.gz, rar, 7z… sem decorar a flag"
            _linha "ls"            "lista com ícones, pastas primeiro"
            _eq    "eza --icons --group-directories-first"
            _linha "ll"            "lista tudo com detalhes: tamanho, data, permissão, ocultos"
            _eq    "eza -alF"
            _linha "la"            "lista incluindo os ocultos (os que começam com .)"
            _eq    "eza -A"
            _linha "lt / tree"     "mostra em árvore (lt = só 2 níveis)"
            _eq    "eza --tree --level=2"
            _linha "cat arq"       "mostra o arquivo com cores de código e nº de linha"
            _eq    "batcat --paging=never arq"
            _linha "catp arq"      "igual ao cat, mas com rolagem (q sai)"
            _eq    "batcat arq"
            ;;
        dev)
            _secao "dev"
            _linha "serve [porta]" "sobe um site local da pasta atual (padrão 8000)"
            _eq    "python3 -m http.server 8000"
            _linha "port N"        "mostra qual programa está usando a porta N"
            _eq    "ss -lptn 'sport = :N'"
            _linha "port -k N"     "fecha esse programa e libera a porta"
            _eq    "kill <pid>"
            _linha "timebox [min]" "cronômetro de foco (padrão ${TIMEBOX_MIN} min), avisa na tela"
            _linha "status"        "painel: pasta, git, projeto, node, disco, memória, bateria"
            _linha "diario"        "abre teu diário no navegador"
            ;;
        git)
            _secao "git · dia a dia"
            _linha "gs"            "estado da pasta: o que mudou, o que é novo, o que tá no stage"
            _eq    "git status"
            _linha "gl"            "histórico em árvore, 1 commit por linha, todas as branches"
            _eq    "git log --oneline --graph --decorate --all"
            _linha "gd"            "o que você mudou e AINDA NÃO deu ga, linha por linha:"
            _linha ""              "lista os arquivos (+ entrou − saiu), Enter abre inteiro"
            _eq    "git diff"
            _linha "gd arq"        "o mesmo, só desse arquivo, direto no terminal"
            _eq    "git diff arq"
            _linha "gds"           "o que JÁ tá no stage, ou seja, o que vai no próximo commit"
            _eq    "git diff --staged"
            _linha ""              "guia completo (como ler, variações, pegadinhas): help diff"
            _linha "ga arq"        "põe o arquivo no stage — sem nome abre a lista (Tab marca)"
            _eq    "git add arq"
            _linha "gaa"           "põe TUDO no stage: novos, alterados e apagados"
            _eq    "git add --all"
            _linha "gc msg"        "salva o que tá no stage num commit (aspas opcionais)"
            _eq    'git commit -m "msg"'
            _linha "gac msg"       "add de tudo + commit, numa tacada só"
            _eq    'git add --all && git commit -m "msg"'
            _linha "gamend"        "enfia as mudanças atuais no último commit, mesmo texto"
            _eq    "git add --all && git commit --amend --no-edit"
            _linha "gamend msg"    "igual, mas também troca o texto do último commit"
            _eq    'git add --all && git commit --amend -m "msg"'
            _linha "gundo"         "desfaz o último commit; as mudanças voltam pro stage"
            _eq    "git reset --soft HEAD~1"
            _linha "grst arq"      "tira o arquivo do stage (desfaz o ga); a mudança fica"
            _eq    "git restore --staged arq"
            _linha "grs arq"       "JOGA FORA as mudanças do arquivo (pede confirmação)"
            _eq    "git restore arq"
            _linha "gst [msg]"     "guarda as mudanças na gaveta (stash), até arquivo novo"
            _eq    'git stash push -u -m "msg"'
            _linha "gstp"          "tira da gaveta o último guardado e aplica de volta"
            _eq    "git stash pop"
            _linha "gsl"           "lista o que tá guardado na gaveta"
            _eq    "git stash list"
            ;;
        remoto)
            _secao "git · branches e GitHub"
            _linha "gp"            "envia teus commits pro GitHub (branch nova publica sozinha)"
            _eq    "git push   ·   1ª vez: git push -u origin branch"
            _linha "gpl"           "baixa os commits novos do GitHub e junta na tua branch"
            _eq    "git pull"
            _linha "gf"            "só confere se tem novidade no GitHub, sem mexer em nada"
            _eq    "git fetch --prune"
            _linha "gb"            "lista as branches (* = a que você tá)"
            _eq    "git branch"
            _linha "gco branch"    "troca de branch — sem nome abre a lista"
            _eq    "git checkout branch"
            _linha "gcb nome"      "cria branch nova a partir da atual e já entra nela"
            _eq    "git checkout -b nome"
            _linha "gnew nome"     "cria a branch, entra e já publica no GitHub"
            _eq    "git checkout -b nome && git push -u origin nome"
            _linha "gin branch"    "commits que VÃO ENTRAR se você der merge (sozinho = lista)"
            _eq    "git log HEAD..branch --oneline"
            _linha "gm branch"     "traz os commits de outra branch pra atual"
            _eq    "git merge branch"
            _linha "gbd nome"      "apaga a branch local (só se já foi mergeada)"
            _eq    "git branch -d nome"
            _linha "gclean"        "apaga as branches já mergeadas (menos main/master/develop)"
            _eq    "git branch --merged | xargs git branch -d"
            _linha "gcl url"       "clona o repositório e já entra na pasta"
            _eq    "git clone url && cd pasta"
            _linha "hub"           "abre o repositório atual no GitHub, no navegador"
            _eq    "git remote get-url origin  → abre o link"
            ;;
        node)
            _secao "node · npm"
            _linha "npkg [nome]"   "cria um package.json base aqui (nunca sobrescreve)"
            _eq    "npm init -y  (só que já com type module e scripts prontos)"
            _linha "ni"            "instala tudo que tá no package.json"
            _eq    "npm install"
            _linha "ni pacote"     "instala um pacote e salva nas dependências"
            _eq    "npm install pacote"
            _linha "nid pacote"    "instala só pra desenvolvimento (eslint, prettier…)"
            _eq    "npm install --save-dev pacote"
            _linha "nr"            "lista os scripts do package.json"
            _eq    "npm run"
            _linha "nr nome"       "roda um script"
            _eq    "npm run nome"
            _linha "nrd"           "roda o script dev"
            _eq    "npm run dev"
            _linha "nrb"           "gera a versão final do projeto (build)"
            _eq    "npm run build"
            _linha "ns"            "roda o script start"
            _eq    "npm start"
            _linha "nt"            "roda os testes"
            _eq    "npm test"
            printf "  ${C_DIM}ni, nr… só rodam dentro de um projeto (pasta com package.json)${C_OFF}\n"
            ;;
        sistema)
            _secao "sistema"
            _linha "clean"         "limpeza: cache do apt, órfãos, logs, flatpak, miniaturas"
            _linha "bkp"           "copia .bashrc, .gitconfig e settings do VS Code"
            _eq    "cp … ~/dotfiles-backup/<data>"
            _linha "rmpkg nome"    "desinstala pacote apt e mostra o espaço liberado"
            _eq    "sudo apt purge nome && sudo apt autoremove"
            _linha "rmapp nome"    "desinstala app flatpak e mostra o espaço liberado"
            _eq    "flatpak uninstall --delete-data nome"
            _linha "lspkg"         "lista os pacotes apt que VOCÊ instalou"
            _eq    "apt-mark showmanual"
            _linha "lsapp"         "lista os apps flatpak instalados"
            _eq    "flatpak list --app --user"
            _linha "tela on / off" "liga / desliga a tela do notebook (off pede confirmação)"
            _eq    "cosmic-randr enable eDP-1  ·  disable eDP-1"
            _linha "atualizar"     "baixa a versão nova deste terminal (GitHub) e já recarrega"
            _eq    "git -C ~/dotfiles pull && source ~/.bashrc"
            ;;
        *)
            return 1
            ;;
    esac
}

dev() {
    local _LARG=14 s     # _LARG: largura da coluna de nomes (o _linha e o _eq enxergam)

    if [ $# -eq 0 ]; then
        _cabecalho "YOUR COMMANDS"
        printf "  ${C_DIM}↳ ${C_WARN}em laranja${C_DIM}: o comando original que o atalho roda por baixo${C_OFF}\n"
        for s in "${_DEV_SECOES[@]}"; do _dev_secao "$s"; done
        printf "\n${C_DIM}  dev <seção> mostra só uma: %s${C_OFF}\n" "${_DEV_SECOES[*]}"
        printf "${C_DIM}  sem argumento, os comandos mostram como usar (ga e gco abrem a lista)${C_OFF}\n"
        printf "${C_DIM}  comandos nativos do sistema: ${C_TEXT}help${C_OFF}\n\n"
        return 0
    fi

    for s in "${_DEV_SECOES[@]}"; do
        if [ "$1" = "$s" ]; then
            _dev_secao "$s"
            printf "\n"
            return 0
        fi
    done

    _err "'$1' não é uma seção do dev" "seções: ${_DEV_SECOES[*]}"
    return 1
}

# Tab completa as seções do dev
complete -W "${_DEV_SECOES[*]}" dev

# help - comandos NATIVOS mais úteis (o que é personalizado fica no 'dev')
# 'help' já existe no bash (help cd). Ele continua funcionando:
#   help            → esta lista
#   help rede       → só uma seção
#   help cd         → ajuda original do bash
_HELP_SECOES=(nav arquivos texto pipes teclado historico processos sistema pacotes rede git node shell ajuda)

_help_secao() {
    case "$1" in
        nav)
            _secao "navegação"
            _linha "cd pasta"                "entra na pasta"
            _linha "cd"                      "volta pra home"
            _linha "cd -"                    "volta pra pasta anterior (vai e volta)"
            _linha "pwd"                     "mostra o caminho de onde você está"
            ;;
        arquivos)
            _secao "arquivos e pastas"
            _linha "touch arq"               "cria arquivo vazio"
            _linha "mkdir -p a/b/c"          "cria pastas, inclusive as do meio"
            _linha "cp arq destino"          "copia (pasta precisa de -r)"
            _linha "mv origem destino"       "move ou renomeia"
            _linha "rm arq · rm -r pasta"    "apaga — não vai pra lixeira"
            _linha "ln -s alvo atalho"       "cria atalho (link simbólico)"
            _linha "chmod +x script.sh"      "deixa o arquivo executável"
            _linha 'find . -name "*.js"'     "acha arquivos pelo nome"
            _linha "du -sh *"                "tamanho de cada item da pasta"
            _linha "file arq"                "descobre o tipo real do arquivo"
            _linha "xdg-open arq"            "abre no app padrão (pdf, imagem…)"
            _linha "tar -czf x.tar.gz pasta" "compacta a pasta"
            ;;
        texto)
            _secao "ler e mexer em texto"
            _linha "less arq"                "lê arquivo grande (q sai, / busca)"
            _linha "head -n 20 arq"          "primeiras 20 linhas"
            _linha "tail -n 20 arq"          "últimas 20 linhas"
            _linha "tail -f arq.log"         "acompanha o arquivo crescendo ao vivo"
            _linha 'grep -rn "txt" .'        "acha texto nos arquivos (-i ignora maiúscula)"
            _linha "wc -l arq"               "conta linhas"
            _linha "diff a b"                "compara dois arquivos"
            _linha "nano arq"                "editor simples (Ctrl+O salva, Ctrl+X sai)"
            _linha "code ."                  "abre a pasta atual no VS Code"
            ;;
        pipes)
            _secao "combinar comandos"
            _linha "a | b"                   "a saída de a vira entrada de b"
            _linha "cmd > arq"               "salva a saída no arquivo (sobrescreve)"
            _linha "cmd >> arq"              "adiciona no fim do arquivo"
            _linha "cmd 2> /dev/null"        "joga as mensagens de erro fora"
            _linha "cmd &> arq"              "salva saída + erros juntos"
            _linha "a && b"                  "roda b só se a deu certo"
            _linha "a || b"                  "roda b só se a falhou"
            _linha "cmd &"                   "roda em segundo plano"
            _linha '$(cmd)'                  "usa a saída de um comando dentro de outro"
            ;;
        teclado)
            _secao "atalhos de teclado"
            _linha "Tab"                     "completa (com várias opções, já lista todas)"
            _linha "Ctrl+R"                  "busca no histórico (fzf)"
            _linha "texto + ↑ / ↓"           "navega só nos comandos que começam com o texto"
            _linha "Ctrl+T"                  "insere arquivo com preview (fzf)"
            _linha "Alt+C"                   "entra numa subpasta (fzf)"
            _linha "Ctrl+A · Ctrl+E"         "vai pro início · fim da linha"
            _linha "Ctrl+← · Ctrl+→"         "pula palavra"
            _linha "Ctrl+W"                  "apaga a palavra anterior"
            _linha "Ctrl+U · Ctrl+K"         "apaga até o início · até o fim"
            _linha "Alt+."                   "cola o último argumento do comando anterior"
            _linha "Ctrl+L"                  "limpa a tela (mantém o que está digitado)"
            _linha "Ctrl+C"                  "cancela o comando"
            _linha "Ctrl+Z · fg"             "pausa o processo · traz de volta"
            _linha "Ctrl+Shift+C · V"        "copia · cola no terminal"
            ;;
        historico)
            _secao "histórico"
            _linha "history"                 "lista o histórico (com data e hora)"
            _linha '!!'                      "repete o último comando"
            _linha 'sudo !!'                 "repete o último comando como admin"
            _linha '!$'                      "último argumento do comando anterior"
            _linha '!123'                    "roda o comando nº 123 do histórico"
            ;;
        processos)
            _secao "processos"
            _linha "top"                     "monitor de processos ao vivo (q sai)"
            _linha "pgrep -a nome"           "acha o processo e mostra o PID"
            _linha "kill PID"                "pede pro processo encerrar"
            _linha "kill -9 PID"             "mata na marra (último recurso)"
            _linha "pkill nome"              "encerra pelo nome"
            _linha "jobs · fg · bg"          "lista · traz pra frente · manda pro fundo"
            _linha "time cmd"                "mede quanto o comando demora"
            _linha "watch -n 2 cmd"          "repete o comando a cada 2s"
            ;;
        sistema)
            _secao "sistema"
            _linha "sudo cmd"                "roda como administrador"
            _linha "free -h"                 "uso de memória RAM"
            _linha "df -h"                   "espaço livre nos discos"
            _linha "lsblk"                   "discos, pendrives e partições"
            _linha "systemctl status x"      "estado de um serviço"
            _linha "sudo journalctl -f"      "logs do sistema ao vivo"
            _linha "reboot · poweroff"       "reinicia · desliga"
            ;;
        pacotes)
            _secao "pacotes"
            _linha "sudo apt update"         "atualiza a lista de pacotes"
            _linha "sudo apt upgrade"        "atualiza o que está instalado"
            _linha "sudo apt install x"      "instala um pacote"
            _linha "apt search x"            "procura pacote pelo nome"
            _linha "flatpak update"          "atualiza os apps flatpak"
            _linha "flatpak search x"        "procura app flatpak"
            ;;
        rede)
            _secao "rede"
            _linha "ping google.com"         "testa se tem internet (Ctrl+C para)"
            _linha "curl url"                "faz requisição HTTP (ótimo pra testar API)"
            _linha "curl -I url"             "só os cabeçalhos da resposta"
            _linha "curl -O url"             "baixa o arquivo"
            _linha "hostname -I"             "teu IP na rede local"
            _linha "ss -tlnp"                "todas as portas abertas"
            _linha "ssh user@host"           "acessa outro computador"
            ;;
        git)
            _secao "git (o que não tem atalho)"
            _linha "git init"                "transforma a pasta em repositório"
            _linha "git remote -v"           "mostra pra onde o repo aponta"
            _linha "git remote add origin"   "+ url: liga o repo local ao GitHub"
            _linha "git show hash"           "detalhes e mudanças de um commit"
            _linha "git log -p arq"          "histórico de mudanças de um arquivo"
            _linha "git blame arq"           "quem mudou cada linha e quando"
            _linha "git revert hash"         "desfaz um commit criando outro (seguro)"
            _linha "git reflog"              "salva-vidas: acha commit 'perdido'"
            _linha "git diff …"              "compara versões — guia completo: help diff"
            ;;
        node)
            _secao "node / npm"
            _linha "node arq.js"             "roda um arquivo JS"
            _linha "node"                    "console JS interativo (.exit sai)"
            _linha "npm init -y"             "cria o package.json"
            _linha "npm i"                   "instala tudo do package.json"
            _linha "npm i pacote"            "instala dependência (-D = só dev)"
            _linha "npm run nome"            "roda um script do package.json"
            _linha "npx pacote"              "roda sem instalar"
            _linha "nvm ls · nvm use 22"     "versões do node · troca de versão"
            ;;
        shell)
            _secao "shell"
            _linha 'echo $VAR'               "mostra o valor de uma variável"
            _linha "export VAR=valor"        "cria variável de ambiente (só nesta sessão)"
            _linha "env | grep x"            "procura entre as variáveis de ambiente"
            _linha "source ~/.bashrc"        "recarrega a config sem fechar o terminal"
            _linha "exit"                    "fecha o terminal"
            ;;
        ajuda)
            _secao "quando travar"
            _linha "help cmd"                "ajuda dos comandos internos (cd, export…)"
            _linha "man cmd"                 "manual completo (q sai, / busca)"
            _linha "cmd --help"              "resumo rápido das opções"
            _linha "type cmd"                "diz se é alias, função ou programa"
            _linha "alias"                   "lista todos os aliases"
            _linha "apropos palavra"         "acha comando pela descrição"
            ;;
        *)
            return 1
            ;;
    esac
}

# _guia_diff - guia completo do git diff (abre com: help diff)
# _paragrafo "texto"  — parágrafo do guia, recuado
_paragrafo() { printf "  ${C_TEXT}%s${C_OFF}\n" "$1"; }
_guia_diff() {
    local _LARG=20
    _cabecalho "GIT DIFF — o que mudou, linha por linha"

    _secao "o que ele faz"
    _paragrafo "Compara duas versões do teu código e mostra SÓ as linhas que mudaram."
    _paragrafo "Ele não mexe em nada, só mostra: pode rodar quantas vezes quiser."

    _secao "as 3 áreas do git (é isso que o diff compara)"
    _linha "pasta"   "teus arquivos do jeito que estão agora no editor"
    _linha "stage"   "o que você já separou com ga/gaa pro próximo commit"
    _linha "commit"  "a última versão salva (o git chama de HEAD)"
    printf "\n  ${C_CMD}pasta${C_OFF} ${C_DIM}──${C_WARN}ga${C_DIM}──▶${C_OFF} ${C_CMD}stage${C_OFF} ${C_DIM}──${C_WARN}gc${C_DIM}──▶${C_OFF} ${C_CMD}commit${C_OFF}\n"

    _secao "qual diff usar"
    _linha "git diff"            "pasta × stage: o que você mudou e AINDA NÃO deu ga"
    _eq    "atalho: gd (abre a lista com prévia)"
    _linha "git diff --staged"   "stage × commit: o que vai entrar no próximo commit"
    _eq    "atalho: gds"
    _linha "git diff HEAD"       "pasta × commit: tudo que mudou desde o último commit"
    _linha "git diff arq"        "qualquer um acima, só daquele arquivo"
    _eq    "atalho: gd arq · gds arq"
    _linha "git diff HEAD~1"     "tua pasta × o commit anterior (HEAD~2 = 2 atrás…)"
    _linha "git diff main"       "tua pasta × a branch main"
    _linha "git diff main...x"   "só o que a branch x mudou desde que saiu da main"
    _eq    "ótimo antes de um merge — junto com o gin"
    _linha "git diff a1b2 c3d4"  "entre dois commits quaisquer (o hash vem do gl)"

    _secao "opções que ajudam (servem em todos acima)"
    _linha "--stat"          "só o resumo: quais arquivos e quantas linhas (+ e −)"
    _linha "--name-only"     "só os nomes dos arquivos que mudaram"
    _linha "--word-diff"     "marca as PALAVRAS que mudaram, não a linha inteira"
    _linha "-w"              "ignora mudança que é só espaço ou indentação"
    _eq    "ex.: gd --stat · gds --name-only · git diff HEAD~1 -w"

    _secao "como ler a saída"
    printf "  ${C_TEXT}diff --git a/app.js b/app.js${C_OFF}   ${C_DIM}arquivo comparado (a = antes, b = depois)${C_OFF}\n"
    printf "  ${C_TEXT}@@ -5,3 +5,4 @@${C_OFF}                ${C_DIM}trecho: -5,3 = antes: linha 5, 3 linhas${C_OFF}\n"
    printf "  %31s${C_DIM}        +5,4 = agora: linha 5, 4 linhas${C_OFF}\n" ""
    printf "  ${C_TEXT} const total = soma(2, 3)${C_OFF}      ${C_DIM}sem sinal: linha igual, só pra dar contexto${C_OFF}\n"
    printf "  ${C_ERR}-console.log(total)${C_OFF}            ${C_DIM}− vermelho: linha que SAIU${C_OFF}\n"
    printf "  ${C_OK}+mostrar(total)${C_OFF}                ${C_DIM}+ verde: linha que ENTROU${C_OFF}\n"
    _paragrafo "Linha alterada aparece como as duas: a velha com − e a nova com +."
    _paragrafo "Com o delta instalado, cada linha mostra:  nº antes ⋮ nº depois │ código."

    _secao "pegadinhas"
    _paragrafo "Arquivo novo não aparece no git diff até você dar ga (aí aparece no gds)."
    _paragrafo "Deu ga em tudo e o gd ficou vazio? Normal: agora tá tudo no gds."
    _paragrafo "Diff vazio não é erro: quer dizer que não tem nada diferente ali."
    _paragrafo "Em diff comprido: espaço desce a página, b sobe, / busca, q sai."

    _secao "na interface do gd / gds"
    _paragrafo "↑ ↓ escolhe o arquivo · digitar filtra pelo nome"
    _paragrafo "Enter abre o arquivo inteiro (lado a lado se a tela for larga)"
    _paragrafo "q volta pra lista · Esc sai"
    printf "\n"
}

help() {
    local _LARG=24 s     # _LARG: largura da coluna de nomes (o _linha enxerga)

    # Sem argumento: a lista inteira
    if [ $# -eq 0 ]; then
        _cabecalho "SYSTEM COMMANDS"
        for s in "${_HELP_SECOES[@]}"; do _help_secao "$s"; done
        printf "\n${C_DIM}  help <seção> mostra só uma: %s${C_OFF}\n" "${_HELP_SECOES[*]}"
        printf "${C_DIM}  guia completo do git diff: ${C_TEXT}help diff${C_OFF}\n"
        printf "${C_DIM}  teus comandos personalizados: ${C_TEXT}dev${C_OFF}\n\n"
        return 0
    fi

    # help diff → guia completo do git diff (não entra na lista geral: é comprido)
    if [ "$1" = "diff" ]; then
        _guia_diff
        return 0
    fi

    # help <seção>
    for s in "${_HELP_SECOES[@]}"; do
        if [ "$1" = "$s" ]; then
            _help_secao "$s"
            printf "\n"
            return 0
        fi
    done

    # help cd / help export / help -d ...  → cai no help original do bash
    if [[ "$1" == -* ]] || [[ "$(type -t "$1")" =~ ^(builtin|keyword)$ ]]; then
        builtin help "$@"
        return
    fi

    _err "'$1' não é seção nem comando interno do bash" "tente: man $1  ou  $1 --help"
    _dica "seções: ${_HELP_SECOES[*]}"
    return 1
}

# Tab completa as seções E os tópicos originais do help
complete -A helptopic -W "${_HELP_SECOES[*]} diff" help

# ==========================================
# ERROS — comando não encontrado
# O bash chama esta função sozinho quando você digita algo que não existe.
# ==========================================

# _mesmas_letras "gti" "git"  → verdadeiro se forem as mesmas letras embaralhadas
_mesmas_letras() {
    [ "${#1}" -eq "${#2}" ] || return 1
    local resto="$2" i letra
    for (( i = 0; i < ${#1}; i++ )); do
        letra="${1:i:1}"
        [[ "$resto" == *"$letra"* ]] || return 1
        resto="${resto/"$letra"/}"           # tira UMA ocorrência da letra
    done
    return 0
}

# _comando_parecido "gti"  → "git" (procura nos teus comandos + nativos comuns)
_comando_parecido() {
    local nativos="git cd ls cat grep code npm node npx nvm sudo mkdir touch clear exit history man help"
    local c
    for c in $(compgen -A function -a) $nativos; do
        [[ "$c" == _* ]] && continue
        if _mesmas_letras "$1" "$c"; then
            printf '%s' "$c"
            return 0
        fi
    done
    return 1
}

command_not_found_handle() {
    local sugestao pacote cnf
    printf "  ${C_ERR}✗${C_OFF}  ${C_TEXT}%s${C_OFF}${C_DIM}: comando não encontrado${C_OFF}\n" "$1" >&2

    # 1) Erro de digitação? (gti → git, sl → ls, claer → clear)
    sugestao=$(_comando_parecido "$1")
    if [ -n "$sugestao" ]; then
        shift
        printf "     ${C_DIM}↳ quis dizer ${C_TEXT}%s${C_DIM}?${C_OFF}\n" "${sugestao}${*:+ $*}" >&2
        return 127
    fi

    # 2) Existe pacote com esse comando? (usa o command-not-found do Ubuntu/Pop)
    for cnf in /usr/lib/command-not-found /usr/share/command-not-found/command-not-found; do
        if [ -x "$cnf" ]; then
            pacote=$("$cnf" -- "$1" 2>&1 | grep -m1 -oE 'sudo (apt|snap) install [^ ]+')
            break
        fi
    done

    if [ -n "$pacote" ]; then
        printf "     ${C_DIM}↳ dá pra instalar: ${C_TEXT}%s${C_OFF}\n" "$pacote" >&2
    else
        printf "     ${C_DIM}↳ ${C_TEXT}dev${C_DIM} teus comandos · ${C_TEXT}help${C_DIM} os do sistema${C_OFF}\n" >&2
    fi
    return 127
}

# ==========================================
# COMPATIBILIDADE — nomes antigos
# Pode apagar este bloco quando a memória muscular pegar os novos.
# ==========================================

alias cleanSys='clean'
alias devstatus='status'
alias rmApt='rmpkg'
alias rmProgram='rmapp'
alias listApt='lspkg'
alias listProgram='lsapp'
alias openhub='hub'

# ==========================================
# PASTA PADRÃO
# Só entra na pasta de projetos se o shell abriu no $HOME.
# Assim o terminal do VS Code, que abre na pasta do projeto,
# não é sequestrado pra outro lugar.
# ==========================================

if [ -z "$_BASHRC_CARREGADO" ] && [ "$PWD" = "$HOME" ] && [ -d "$DEV_HOME" ]; then
    builtin cd "$DEV_HOME"
fi

alias diario='_abrir "https://claude.ai/artifact/58cmKCqHrffWQxMtoMQA41"'   # _abrir: não trava o terminal

# tela on|off — liga/desliga a tela do notebook (eDP-1) pelo cosmic-randr
tela() {
    command -v cosmic-randr >/dev/null 2>&1 || { _err "cosmic-randr não encontrado" "esse comando só funciona no COSMIC"; return 1; }
    local saida="eDP-1"
    case "$1" in
        on)
            if cosmic-randr enable "$saida"; then _ok "Tela do notebook ligada"
            else _err "Não consegui ligar a tela $saida" "rode: cosmic-randr list  (confira o nome da saída)"; fi
            ;;
        off)
            _aviso "Vai desligar a tela do notebook" "confirme que o HDMI está ligado, senão fica sem tela"
            local r
            read -r -p "     Continuar? [s/N] " r
            [[ "$r" =~ ^[sSyY]$ ]] || { _dica "cancelado"; return 0; }
            if cosmic-randr disable "$saida"; then _ok "Tela do notebook desligada"
            else _err "Não consegui desligar a tela $saida" "rode: cosmic-randr list"; fi
            ;;
        *)
            _err "uso: tela on | tela off"
            ;;
    esac
}

# Marca que este arquivo já carregou uma vez neste terminal (o banner e o
# "entra na pasta de projetos" não repetem no source / atualizar)
_BASHRC_CARREGADO=1
