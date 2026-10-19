# shellcheck shell=bash
# ==========================================
# PLATAFORMA — onde o terminal tá rodando + compatibilidade
# Roda uma vez no carregamento e não abre processo nenhum: só lê variáveis
# do shell e arquivos do /proc e do /etc com o 'read' (builtin).
#
#   _SHELL   bash | zsh
#   _SO      linux | macos | wsl
#   _DISTRO  pop | ubuntu | debian | arch | fedora | ...   (vazio no macOS)
#   _PKG     apt | pacman | dnf | zypper | brew            (gerenciador de pacotes)
#
# Os helpers daqui escondem as diferenças entre GNU (Linux) e BSD (macOS):
# o resto do código chama _humano, _livre_bytes, _abrir… e não precisa
# saber em que sistema está.
# ==========================================

if [ -n "${ZSH_VERSION:-}" ]; then _SHELL=zsh; else _SHELL=bash; fi

case "${OSTYPE:-}" in
    darwin*) _SO=macos ;;
    *)
        _SO=linux
        if [ -n "${WSL_DISTRO_NAME:-}" ] || [ -n "${WSL_INTEROP:-}" ]; then
            _SO=wsl
        elif [ -r /proc/sys/kernel/osrelease ]; then
            read -r _df_k < /proc/sys/kernel/osrelease
            case "$_df_k" in *[Mm]icrosoft*|*WSL*) _SO=wsl ;; esac
        fi
        ;;
esac

# Distro: o ID do /etc/os-release (pop, ubuntu, arch…), lido sem abrir processo
_DISTRO=""
if [ -r /etc/os-release ]; then
    while IFS='=' read -r _df_k _df_v; do
        if [ "$_df_k" = "ID" ]; then _DISTRO="${_df_v//\"/}"; break; fi
    done < /etc/os-release
fi
unset _df_k _df_v

# _tem programa — o programa existe no PATH? (builtin, sem abrir processo)
# Olha só o PATH de propósito: funções e aliases com o mesmo nome não contam
# (o 'command -v' acharia a função 'open' deste arquivo, por exemplo).
_tem() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        (( ${+commands[$1]} )) || whence -p "$1" > /dev/null 2>&1
    else
        hash "$1" 2> /dev/null
    fi
}

# _caminho_cmd VAR programa — guarda em VAR o caminho completo do programa
_caminho_cmd() {
    case "$2" in
        */*) [ -x "$2" ] || return 1; eval "$1=\$2"; return 0 ;;
    esac
    _tem "$2" || return 1
    if [ -n "${ZSH_VERSION:-}" ]; then
        eval "$1=\${commands[\$2]:-\$(whence -p \"\$2\")}"
    else
        eval "$1=\${BASH_CMDS[\$2]}"
    fi
}

# Gerenciador de pacotes do sistema (o primeiro que existir)
_PKG=""
for _df_g in apt pacman dnf zypper brew; do
    if _tem "$_df_g"; then _PKG="$_df_g"; break; fi
done
unset _df_g

# _cmd_instalar programa — o comando que instala o programa NESTE sistema.
# O nome do pacote muda de distro pra distro (o fd no Ubuntu é 'fd-find').
_cmd_instalar() {
    local p="$1"
    case "$_PKG:$p" in
        apt:fd)                      p=fd-find ;;
        apt:delta|pacman:delta|dnf:delta|brew:delta) p=git-delta ;;
        apt:7z)                      p=p7zip-full ;;
        pacman:7z)                   p=p7zip ;;
        dnf:7z)                      p=p7zip-plugins ;;
        brew:7z)                     p=sevenzip ;;
        *:rg)                        p=ripgrep ;;
        apt:notify-send)             p=libnotify-bin ;;
        *:notify-send)               p=libnotify ;;
        *:xdg-open)                  p=xdg-utils ;;
        *:wl-copy)                   p=wl-clipboard ;;
        apt:docker)                  p=docker.io ;;
        brew:docker)                 p="--cask docker" ;;
        pacman:python3)              p=python ;;
        brew:python3)                p=python ;;
        apt:batcat)                  p=bat ;;
    esac
    case "$_PKG" in
        apt)    printf 'sudo apt install %s' "$p" ;;
        pacman) printf 'sudo pacman -S %s' "$p" ;;
        dnf)    printf 'sudo dnf install %s' "$p" ;;
        zypper) printf 'sudo zypper install %s' "$p" ;;
        brew)   printf 'brew install %s' "$p" ;;
        *)      printf 'instale o pacote %s pelo gerenciador do teu sistema' "$p" ;;
    esac
}

# _precisa programa — guarda das funções: se o programa não existe,
# explica como instalar (do jeito certo pra este sistema) e retorna 1
_precisa() {
    _tem "$1" && return 0
    _err "$1 não está instalado" "$(_cmd_instalar "$1")"
}

# ---------- tempo ----------

# _us VAR — guarda em VAR o relógio em microssegundos (pra medir duração).
# O bash 5 dá 6 casas decimais e o zsh dá 9; no locale pt_BR o separador
# pode vir como vírgula. Normaliza tudo pra µs. Sem EPOCHREALTIME, usa segundos.
_us() {
    local _us_t="${EPOCHREALTIME:-}" _us_s _us_f
    if [ -z "$_us_t" ]; then
        eval "$1=\$(( SECONDS * 1000000 ))"
        return 0
    fi
    _us_s="${_us_t%[.,]*}"
    _us_f="${_us_t#*[.,]}000000"
    eval "$1=\${_us_s}\${_us_f:0:6}"
}

# _data "formato" [epoch] — data formatada SEM chamar o binário 'date'
# bash: printf %(...)T é builtin · zsh: strftime (módulo zsh/datetime)
_data() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        strftime "$1" "${2:-$EPOCHSECONDS}"
    else
        printf "%($1)T" "${2:--1}"
    fi
}

# _data_var VAR "formato" [epoch] — igual o _data, mas guarda em VAR (sem subshell)
_data_var() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        strftime -s "$1" "$2" "${3:-$EPOCHSECONDS}"
    else
        printf -v "$1" "%($2)T" "${3:--1}"
    fi
}

# _uptime_txt → "ligado há 3h12" (Linux lê o /proc; macOS pergunta pro sysctl)
_uptime_txt() {
    local s=""
    if [ -r /proc/uptime ]; then
        read -r s _ < /proc/uptime
        s="${s%.*}"
    elif [ "$_SO" = macos ]; then
        local boot
        boot=$(sysctl -n kern.boottime 2> /dev/null | sed -n 's/.*sec = \([0-9]*\).*/\1/p')
        [ -n "$boot" ] && s=$(( ${EPOCHSECONDS:-0} - boot ))
    fi
    [ -z "$s" ] && return 0
    if (( s >= 86400 )); then printf 'ligado há %dd%02dh' $(( s / 86400 )) $(( s % 86400 / 3600 ))
    else printf 'ligado há %dh%02d' $(( s / 3600 )) $(( s % 3600 / 60 )); fi
}

# ---------- caminhos e tamanhos ----------

# _curto [caminho] → troca o /home/você do começo por ~ (padrão: pasta atual)
_curto() {
    local p="${1:-$PWD}"
    case "$p" in
        "$HOME")   printf '~' ;;
        "$HOME"/*) printf '~%s' "${p#"$HOME"}" ;;
        *)         printf '%s' "$p" ;;
    esac
}

# _humano 1536 → "1.5K"  (no lugar do numfmt, que o macOS não tem)
_humano() {
    local b="${1:-0}" sinal="" i=0 resto=0
    local unidades=(B K M G T P)
    case "$b" in ''|*[!0-9-]*) b=0 ;; esac
    if (( b < 0 )); then sinal="-"; b=$(( -b )); fi
    while (( b >= 1024 && i < 5 )); do
        resto=$(( b % 1024 )); b=$(( b / 1024 )); i=$(( i + 1 ))
    done
    if (( i == 0 )); then
        printf '%s%dB' "$sinal" "$b"
    elif (( b < 10 )); then
        printf '%s%d.%d%s' "$sinal" "$b" $(( resto * 10 / 1024 )) "${unidades[i]}"
    else
        printf '%s%d%s' "$sinal" "$b" "${unidades[i]}"
    fi
}

# _livre_bytes [pasta] — espaço livre em bytes no disco da pasta.
# 'df -Pk' sai igual no GNU e no macOS (o --output=avail é só do GNU).
_livre_bytes() {
    local _ livre=0
    { read -r _; read -r _ _ _ livre _; } < <(LC_ALL=C df -Pk "${1:-/}" 2> /dev/null)
    case "$livre" in ''|*[!0-9]*) livre=0 ;; esac
    printf '%s' "$(( livre * 1024 ))"
}

# _tam_bytes [-s] caminho... — tamanho somado em bytes ('du -sb' é só do GNU).
# -s usa o sudo (pastas do sistema, tipo /var/cache/apt) — sem pedir senha.
_tam_bytes() {
    local sudo="" kb _ total=0
    if [ "$1" = "-s" ]; then sudo="sudo -n"; shift; fi
    [ $# -eq 0 ] && { printf 0; return 0; }
    while read -r kb _; do
        case "$kb" in ''|*[!0-9]*) continue ;; esac
        total=$(( total + kb ))
    done < <($sudo du -sk "$@" 2> /dev/null)
    printf '%s' "$(( total * 1024 ))"
}

# _caminho_real arquivo — segue atalhos até o arquivo de verdade
# (o 'readlink -f' só existe no macOS 12.3+; aqui funciona em qualquer um)
_caminho_real() {
    local alvo="$1" destino
    while [ -L "$alvo" ]; do
        destino=$(readlink -- "$alvo") || break
        case "$destino" in
            /*) alvo="$destino" ;;
            *)  alvo="${alvo%/*}/$destino" ;;
        esac
    done
    case "$alvo" in */*) ;; *) alvo="./$alvo" ;; esac
    printf '%s/%s' "$(builtin cd -P -- "${alvo%/*}" 2> /dev/null && pwd)" "${alvo##*/}"
}

# _cache_init VAR nome programa [args...] — roda "programa args" (ex: zoxide
# init bash), guarda a saída em cache e põe o caminho do cache em VAR.
# Quem chama dá o source. Os próximos terminais leem direto do cache, sem
# abrir processo (~2-6ms a menos por ferramenta no startup).
# O cache se refaz sozinho quando: o programa é atualizado (binário mais novo
# que o cache) ou os argumentos mudam.
# Se o programa não aceitar os argumentos (ex: fzf antigo sem --bash), isso
# também fica anotado no cache — não tenta de novo a cada terminal.
_cache_init() {
    local _ci_var="$1" _ci_nome="$2" _ci_bin _ci_cache _ci_cab _ci_l1="" _ci_l2=""
    shift 2
    _caminho_cmd _ci_bin "$1" || return 1
    _ci_cache="$DOTFILES_CACHE/init-$_ci_nome.$_SHELL.sh"
    _ci_cab="# dotfiles cache: $*"
    [ -s "$_ci_cache" ] && { read -r _ci_l1; read -r _ci_l2; } < "$_ci_cache"
    if [ "$_ci_l1" != "$_ci_cab" ] || [ "$_ci_bin" -nt "$_ci_cache" ]; then
        [ -d "$DOTFILES_CACHE" ] || mkdir -p "$DOTFILES_CACHE" 2> /dev/null || return 1
        if { printf '%s\n' "$_ci_cab"; "$_ci_bin" "${@:2}"; } > "$_ci_cache.$$" 2> /dev/null; then
            command mv -f "$_ci_cache.$$" "$_ci_cache"
        else
            printf '%s\n# falhou\n' "$_ci_cab" > "$_ci_cache"
            command rm -f "$_ci_cache.$$"
            return 1
        fi
    elif [ "$_ci_l2" = "# falhou" ]; then
        return 1
    fi
    eval "$_ci_var=\$_ci_cache"
}

# ---------- integração com o sistema ----------

# _abrir "alvo" — abre no app padrão SOLTO do terminal, em qualquer sistema.
# Linux: o xdg-open roda o app preso ao terminal (ele trava até a janela
# fechar e ainda despeja mensagens tipo "Connecting to org.freedesktop.Tracker3...").
# setsid -f: o app vira um processo independente (fechar o terminal não fecha ele)
# </dev/null >/dev/null 2>&1: nada entra, nada sai na tela.
_abrir() {
    local alvo="$1"
    case "$_SO" in
        macos)
            command open "$alvo" > /dev/null 2>&1
            ;;
        wsl)
            if _tem wslview; then
                (wslview "$alvo" < /dev/null > /dev/null 2>&1 &)
            else
                # explorer.exe só entende caminho do Windows (C:\...)
                if [[ "$alvo" != *://* ]]; then
                    alvo=$(wslpath -w "$alvo" 2> /dev/null) || alvo="$1"
                fi
                (explorer.exe "$alvo" < /dev/null > /dev/null 2>&1 &)
            fi
            ;;
        *)
            if _tem setsid; then
                setsid -f xdg-open "$alvo" < /dev/null > /dev/null 2>&1
            else
                (nohup xdg-open "$alvo" < /dev/null > /dev/null 2>&1 &)
            fi
            ;;
    esac
}

# _notificar "título" "texto" [urgencia] — notificação na tela do sistema.
# Sem sistema de notificação (servidor, SSH): toca o sino e escreve no terminal.
_notificar() {
    local titulo="$1" texto="$2"
    case "$_SO" in
        macos)
            osascript -e "display notification \"${texto//\"/\\\"}\" with title \"${titulo//\"/\\\"}\"" \
                > /dev/null 2>&1 && return 0
            ;;
        wsl)
            # O WSL só repassa pro Windows as variáveis listadas no WSLENV
            if _tem powershell.exe; then
                (DF_TITULO="$titulo" DF_TEXTO="$texto" WSLENV="${WSLENV:+$WSLENV:}DF_TITULO:DF_TEXTO" \
                    powershell.exe -NoProfile -WindowStyle Hidden -Command '
                    Add-Type -AssemblyName System.Windows.Forms
                    $n = New-Object System.Windows.Forms.NotifyIcon
                    $n.Icon = [System.Drawing.SystemIcons]::Information
                    $n.Visible = $true
                    $n.ShowBalloonTip(10000, $env:DF_TITULO, $env:DF_TEXTO, "Info")
                    Start-Sleep -Seconds 10; $n.Dispose()' < /dev/null > /dev/null 2>&1 &)
                return 0
            fi
            ;;
    esac
    if _tem notify-send; then
        notify-send ${3:+-u "$3"} "$titulo" "$texto" 2> /dev/null && return 0
    fi
    printf '\a\n  %s  %s\n' "$titulo" "$texto" > /dev/tty 2> /dev/null
}
