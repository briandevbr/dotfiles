#!/usr/bin/env bash
# shellcheck disable=SC2088  # o "~/" nas mensagens é texto pra ler, não caminho
# ==========================================
# install.sh — instala os dotfiles no Linux, macOS ou WSL
#
#   ./install.sh                 liga o ~/.bashrc e o ~/.zshrc ao repositório
#   ./install.sh --ferramentas   também instala fzf, zoxide, eza, bat, fd, rg, delta, jq
#   ./install.sh --so-bash       só o bash      ·   --so-zsh   só o zsh
#
# Pode rodar quantas vezes quiser: o que já está certo fica como está.
# Antes de trocar qualquer arquivo seu, guarda uma cópia com a data no nome.
# ==========================================
set -u

RAIZ=$(cd -P -- "$(dirname -- "$0")" && pwd)
export DOTFILES="$RAIZ"
# os mesmos helpers de cor e mensagem do terminal (✓ ✗ ↳)
# shellcheck source=shell/00-plataforma.sh
. "$RAIZ/shell/00-plataforma.sh"
# shellcheck source=shell/10-config.sh
. "$RAIZ/shell/10-config.sh"
# shellcheck source=shell/20-ui.sh
. "$RAIZ/shell/20-ui.sh"

ferramentas=0 fazer_bash=1 fazer_zsh=1
for arg in "$@"; do
    case "$arg" in
        --ferramentas) ferramentas=1 ;;
        --so-bash)     fazer_zsh=0 ;;
        --so-zsh)      fazer_bash=0 ;;
        -h|--help)     sed -n '2,12p' "$0"; exit 0 ;;
        *)             _err "opção desconhecida: $arg" "veja: ./install.sh --help"; exit 1 ;;
    esac
done

carimbo=$(date +%Y-%m-%d_%H%M%S)

# _ligar origem destino — faz o destino (~/.bashrc) virar atalho pro arquivo do repo
_ligar() {
    local origem="$1" destino="$2"
    if [ -L "$destino" ] && [ "$(_caminho_real "$destino")" = "$(_caminho_real "$origem")" ]; then
        _ok "$(_curto "$destino") já aponta pro repositório"
        return 0
    fi
    if [ -e "$destino" ] || [ -L "$destino" ]; then
        command mv -- "$destino" "$destino.antes-dotfiles-$carimbo" || { _err "não consegui guardar $(_curto "$destino")"; return 1; }
        _dica "o antigo ficou em $(_curto "$destino.antes-dotfiles-$carimbo")"
    fi
    ln -s -- "$origem" "$destino" && _ok "$(_curto "$destino") → $(_curto "$origem")"
}

_cabecalho "DOTFILES · INSTALAÇÃO"
_kv "sistema" "$_SO${_DISTRO:+ ($_DISTRO)} · pacotes: ${_PKG:-?}"
_kv "repo" "$(_curto "$RAIZ")"

if ! _tem git; then
    _err "o git é obrigatório" "$(_cmd_instalar git)"
    exit 1
fi

_secao "atalhos"
if [ "$fazer_bash" -eq 1 ]; then
    _ligar "$RAIZ/bashrc" "$HOME/.bashrc"
    if [ "$_SO" = macos ]; then
        # o Terminal do macOS abre shell de login: o .bash_profile precisa chamar o .bashrc
        if ! grep -qs 'bashrc' "$HOME/.bash_profile"; then
            printf '\n# dotfiles: o macOS abre o bash como login shell\n[ -f ~/.bashrc ] && . ~/.bashrc\n' >> "$HOME/.bash_profile"
            _ok "~/.bash_profile agora carrega o ~/.bashrc"
        fi
        if [ "${BASH_VERSINFO[0]}" -lt 4 ] && ! [ -x /opt/homebrew/bin/bash ] && ! [ -x /usr/local/bin/bash ]; then
            _aviso "o bash do macOS é o 3.2 (antigo demais)" "use o zsh (padrão) ou: brew install bash"
        fi
    fi
fi
if [ "$fazer_zsh" -eq 1 ]; then
    if _tem zsh || [ "$_SO" = macos ]; then
        _ligar "$RAIZ/zshrc" "$HOME/.zshrc"
        # Ubuntu/Debian: o /etc/zsh/zshrc já roda o compinit; sem isso, o Tab carregaria 2x
        if [ -f /etc/zsh/zshrc ] && grep -qs 'skip_global_compinit' /etc/zsh/zshrc &&
           ! grep -qs 'skip_global_compinit' "$HOME/.zshenv"; then
            printf 'skip_global_compinit=1   # dotfiles: o zshrc já cuida do Tab\n' >> "$HOME/.zshenv"
            _ok "~/.zshenv: Tab carregando uma vez só"
        fi
    else
        _dica "zsh não instalado — pulando (instale com: $(_cmd_instalar zsh))"
    fi
fi

_secao "teus ajustes"
if [ -f "$DOTFILES_LOCAL" ]; then
    _ok "$(_curto "$DOTFILES_LOCAL") já existe (não mexi)"
else
    mkdir -p "$(dirname "$DOTFILES_LOCAL")"
    cat > "$DOTFILES_LOCAL" << 'EOF'
# ~/.config/dotfiles/local.sh — teus ajustes pessoais
# Carrega depois de tudo (bash e zsh) e fica FORA do repositório:
# o 'atualizar' nunca mexe aqui. Exemplos:
#
# PROMPT_NOME="ana"                          # o [nome] do prompt
# DEV_HOME="$HOME/code"                      # pasta dos projetos
# TIMEBOX_MIN=50                             # timebox padrão
# DOTFILES_ANIM=0                            # sem animações
# alias k='kubectl'                          # teus atalhos
EOF
    _ok "criado $(_curto "$DOTFILES_LOCAL")" "teus ajustes vão lá"
fi

if [ "$ferramentas" -eq 1 ]; then
    _secao "ferramentas opcionais"
    case "$_PKG" in
        apt)    pacotes=(fzf zoxide eza bat fd-find ripgrep git-delta jq); instalar=(sudo apt-get install -y) ;;
        pacman) pacotes=(fzf zoxide eza bat fd ripgrep git-delta jq); instalar=(sudo pacman -S --needed --noconfirm) ;;
        dnf)    pacotes=(fzf zoxide eza bat fd-find ripgrep git-delta jq); instalar=(sudo dnf install -y) ;;
        zypper) pacotes=(fzf zoxide eza bat fd ripgrep git-delta jq); instalar=(sudo zypper install -y) ;;
        brew)   pacotes=(fzf zoxide eza bat fd ripgrep git-delta jq); instalar=(brew install) ;;
        *)      pacotes=(); _aviso "não reconheci o gerenciador de pacotes" "instale à mão: fzf zoxide eza bat fd ripgrep delta jq" ;;
    esac
    [ "$_PKG" = apt ] && sudo apt-get update -qq
    # um por vez: se a distro não tiver um deles (ex.: eza no Ubuntu antigo), os outros entram mesmo assim
    for p in "${pacotes[@]}"; do
        if "${instalar[@]}" "$p" > /dev/null 2>&1; then _ok "$p"; else _aviso "$p não instalou" "tente à mão: ${instalar[*]} $p"; fi
    done
fi

printf "\n"
_feito "◈" "pronto!" "abra um terminal novo (ou: source ~/.bashrc · source ~/.zshrc)"
_dica "comandos: dev · ajuda do sistema: help · check-up: dotfiles"
