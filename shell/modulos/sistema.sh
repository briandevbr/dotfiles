# shellcheck shell=bash
# ==========================================
# SISTEMA — pacotes, limpeza, atualização, backup e o próprio terminal
# ==========================================

# lspkg - lista os pacotes que VOCÊ instalou (não os que vieram com o sistema)
lspkg() {
    case "$_PKG" in
        apt)    apt-mark showmanual ;;
        pacman) pacman -Qe ;;
        dnf)    dnf repoquery --userinstalled 2> /dev/null ;;
        zypper) zypper search --installed-only ;;
        brew)   brew leaves ;;
        *)      _err "não reconheci o gerenciador de pacotes deste sistema" ;;
    esac
}

# lsapp - apps Flatpak instalados (no macOS: os apps do Homebrew Cask)
lsapp() {
    if _tem flatpak; then
        flatpak list --app --user
    elif [ "$_SO" = macos ] && _tem brew; then
        brew list --cask
    else
        _precisa flatpak
    fi
}

# _espaco_liberado <bytes-livres-antes>  — fecha remoções mostrando o ganho
_espaco_liberado() {
    local depois liberado
    depois=$(_livre_bytes /)
    liberado=$(( depois - $1 ))
    if [ "$liberado" -gt 0 ]; then
        _ok "removido" "$(_humano "$liberado") liberados"
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
    antes=$(_livre_bytes /)

    _titulo "🗑 " "removendo" "$*"
    if [ "$_SO" = macos ] && ! _tem flatpak; then
        brew uninstall --cask --zap "$@" || { _err "não consegui remover" "confira o nome com: lsapp"; return 1; }
    else
        _precisa flatpak || return 1
        if ! flatpak uninstall --delete-data "$@" -y; then
            _err "não consegui remover" "confira o ID com: lsapp"
            return 1
        fi
        flatpak uninstall --unused -y > /dev/null 2>&1
    fi
    _espaco_liberado "$antes"
}

# rmpkg - remove pacote (apt, pacman, dnf, brew) mostrando espaço liberado
rmpkg() {
    if [ "$#" -eq 0 ]; then
        _uso "rmpkg <PACOTE> [PACOTE_2 ...]" "descubra o nome com: lspkg"
        return 1
    fi

    local antes ok=0
    antes=$(_livre_bytes /)

    _titulo "🗑 " "removendo" "$*"
    case "$_PKG" in
        apt)    sudo apt purge "$@" -y && { sudo apt autoremove -y > /dev/null 2>&1; ok=1; } ;;
        pacman) sudo pacman -Rns "$@" && ok=1 ;;
        dnf)    sudo dnf remove -y "$@" && ok=1 ;;
        zypper) sudo zypper remove -y "$@" && ok=1 ;;
        brew)   brew uninstall "$@" && { brew autoremove > /dev/null 2>&1; ok=1; } ;;
        *)      _err "não reconheci o gerenciador de pacotes deste sistema"; return 1 ;;
    esac
    if [ "$ok" -ne 1 ]; then
        _err "não consegui remover" "confira o nome com: lspkg"
        return 1
    fi
    _espaco_liberado "$antes"
}

# ==========================================
# CLEAN — limpeza profunda com relatório
# Cada etapa só roda se a ferramenta existir neste sistema. No fim, o
# relatório mostra quanto cada uma liberou e o total no disco.
#   clean         limpa tudo que encontrar
#   clean -n      só mostra quanto dá pra liberar, sem apagar nada
# Nunca mexe em: arquivos teus, lixeira, volumes do docker, node_modules de projeto.
# ==========================================

# Cada etapa: "nome|teste|pastas medidas|função que limpa"
#   teste: programa que precisa existir (ou d:pasta que precisa existir)
#   pastas: separadas por ':' — o prefixo -s: mede com sudo (pastas do sistema)
_CLEAN_ETAPAS=(
    "apt: órfãos e cache|apt-get|-s:/var/cache/apt/archives|_limpa_apt"
    "pacman: órfãos e cache|pacman|-s:/var/cache/pacman/pkg|_limpa_pacman"
    "dnf: órfãos e cache|dnf|-s:/var/cache/dnf|_limpa_dnf"
    "flatpak: runtimes sem uso|flatpak|$HOME/.local/share/flatpak/repo:/var/tmp/flatpak-cache-*|_limpa_flatpak"
    "snap: versões antigas|snap|-s:/var/lib/snapd/snaps|_limpa_snap"
    "brew: downloads antigos|brew|$HOME/Library/Caches/Homebrew:$HOME/.cache/Homebrew|_limpa_brew"
    "npm: cache de pacotes|d:$HOME/.npm/_cacache|$HOME/.npm/_cacache|_limpa_npm"
    "pip: cache|pip3|$HOME/.cache/pip:$HOME/Library/Caches/pip|_limpa_pip"
    "logs do sistema (+7 dias)|journalctl|-s:/var/log/journal|_limpa_journal"
    "temporários teus (+7 dias)|find|/tmp:/var/tmp|_limpa_tmp"
    "miniaturas de imagem|find|$HOME/.cache/thumbnails|_limpa_miniaturas"
)

_limpa_apt()        { sudo -n apt-get autoremove --purge -y && sudo -n apt-get clean; }
_limpa_pacman()     {
    local orfaos
    orfaos=$(pacman -Qdtq 2> /dev/null)
    # shellcheck disable=SC2086
    [ -n "$orfaos" ] && { sudo -n pacman -Rns --noconfirm $orfaos || return 1; }
    if _tem paccache; then sudo -n paccache -rk1; else sudo -n pacman -Sc --noconfirm; fi
}
_limpa_dnf()        { sudo -n dnf autoremove -y && sudo -n dnf clean all; }
_limpa_flatpak()    { flatpak uninstall --unused -y; }
_limpa_snap()       {
    # snap guarda as versões antigas de cada app ("disabled"): remove só essas
    local nome rev
    while read -r nome rev; do
        sudo -n snap remove "$nome" --revision="$rev" || return 1
    done < <(LC_ALL=C snap list --all 2> /dev/null | awk '/disabled/ {print $1, $3}')
}
_limpa_brew()       { brew cleanup -s --prune=all && brew autoremove; }
# o npm do nvm só entra no PATH depois do primeiro uso: sem ele, apaga o cache direto (é o que o npm faria)
_limpa_npm()        { if _tem npm; then npm cache clean --force; else command rm -rf "$HOME/.npm/_cacache"; fi; }
_limpa_pip()        { pip3 cache purge; }
_limpa_journal()    { sudo -n journalctl --vacuum-time=7d; }
_limpa_tmp()        {
    # só arquivos TEUS, parados há mais de 7 dias (nada de outros usuários nem do sistema)
    find /tmp /var/tmp -xdev -type f -user "$(id -u)" -mtime +7 -delete 2> /dev/null
    return 0
}
_limpa_miniaturas() { command rm -rf "$HOME/.cache/thumbnails/"* 2> /dev/null; return 0; }

# _clean_medir "pastas" → bytes (prefixo -s: mede com sudo)
_clean_medir() {
    local pastas="$1" sudo="" lista=() p
    if [[ "$pastas" == -s:* ]]; then sudo="-s"; pastas="${pastas#-s:}"; fi
    local IFS=':'
    for p in $pastas; do
        # shellcheck disable=SC2206  # o glob das pastas (flatpak-cache-*) tem que expandir
        [ -e "$p" ] && lista+=($p)
    done
    unset IFS
    [ ${#lista[@]} -eq 0 ] && { printf 0; return 0; }
    if [ -n "$sudo" ]; then _tam_bytes -s "${lista[@]}"; else _tam_bytes "${lista[@]}"; fi
}

clean() {
    local simular=0
    case "${1:-}" in
        -n|--simular|--dry-run) simular=1 ;;
        "") ;;
        *) _uso "clean [-n]" "limpa caches, órfãos, temporários e logs antigos" "-n só mostra quanto dá pra liberar"; return 1 ;;
    esac

    local inicio=$SECONDS etapas=() e nome teste pastas func
    for e in "${_CLEAN_ETAPAS[@]}"; do
        IFS='|' read -r nome teste pastas func <<< "$e"
        if [[ "$teste" == d:* ]]; then
            [ -d "${teste#d:}" ] && etapas+=("$e")
        else
            _tem "$teste" && etapas+=("$e")
        fi
    done

    printf "${C_ACCENT}╭────────────────────────────────────────╮${C_OFF}\n"
    if [ "$simular" -eq 1 ]; then
        printf "${C_ACCENT}│${C_OFF}   🔎  LIMPEZA GERAL · SÓ SIMULANDO      ${C_ACCENT}│${C_OFF}\n"
    else
        printf "${C_ACCENT}│${C_OFF}   🧹  LIMPEZA GERAL DO SISTEMA          ${C_ACCENT}│${C_OFF}\n"
    fi
    printf "${C_ACCENT}╰────────────────────────────────────────╯${C_OFF}\n"

    # sudo uma vez só, antes das etapas (o spinner não pode parar pra pedir senha)
    local precisa_sudo=0
    for e in "${etapas[@]}"; do [[ "$e" == *"|-s:"* ]] && precisa_sudo=1; done
    if [ "$simular" -eq 0 ] && [ "$precisa_sudo" -eq 1 ] && _tem sudo; then
        if ! sudo -v; then
            _err "sem a senha do sudo não dá pra limpar as partes do sistema" "rode de novo: clean"
            return 1
        fi
    fi

    local espaco_antes total=0 i=0 n=${#etapas[@]} antes depois liberado relatorio=()
    espaco_antes=$(_livre_bytes /)
    for e in "${etapas[@]}"; do
        IFS='|' read -r nome teste pastas func <<< "$e"
        i=$(( i + 1 ))
        _etapa "$i" "$n" "$nome"
        antes=$(_clean_medir "$pastas")
        if [ "$simular" -eq 1 ]; then
            _feito "≈" "$(_humano "$antes") em cache" "$(printf '%s' "${pastas#-s:}" | tr ':' ' ')"
            total=$(( total + antes ))
            relatorio+=("$nome|$antes")
            continue
        fi
        if _rodar -q "$nome" "$func"; then
            depois=$(_clean_medir "$pastas")
            liberado=$(( antes - depois ))
            (( liberado < 0 )) && liberado=0
            total=$(( total + liberado ))
            relatorio+=("$nome|$liberado")
            if (( liberado > 0 )); then
                _feito "✓" "$(_humano "$liberado") liberados"
            else
                _feito "✓" "já estava limpo"
            fi
        else
            relatorio+=("$nome|falhou")
        fi
    done

    # Relatório final
    local espaco_depois no_disco linha r_nome r_valor
    espaco_depois=$(_livre_bytes /)
    no_disco=$(( espaco_depois - espaco_antes ))
    (( total < no_disco )) && total=$no_disco

    printf "\n${C_ACCENT}╭────────────────────────────────────────╮${C_OFF}\n"
    for linha in "${relatorio[@]}"; do
        r_nome="${linha%|*}"; r_valor="${linha##*|}"
        if [ "$r_valor" = "falhou" ]; then
            printf "${C_ACCENT}│${C_OFF}  ${C_ERR}✗${C_OFF} ${C_TEXT}%s${C_OFF} ${C_ERR}%s${C_OFF}\n" "$(_pad "$r_nome" 28)" "falhou"
        elif [ "$r_valor" -gt 0 ]; then
            printf "${C_ACCENT}│${C_OFF}  ${C_OK}✓${C_OFF} ${C_TEXT}%s${C_OFF} ${C_OK}%8s${C_OFF}\n" "$(_pad "$r_nome" 28)" "$(_humano "$r_valor")"
        else
            printf "${C_ACCENT}│${C_OFF}  ${C_DIM}·${C_OFF} ${C_DIM}%s %8s${C_OFF}\n" "$(_pad "$r_nome" 28)" "0"
        fi
    done
    printf "${C_ACCENT}├────────────────────────────────────────┤${C_OFF}\n"
    if [ "$simular" -eq 1 ]; then
        printf "${C_ACCENT}│${C_OFF}  🔎  Dá pra liberar: ${C_OK}%s${C_OFF}\n" "$(_humano "$total")"
        printf "${C_ACCENT}│${C_OFF}  ${C_DIM}nada foi apagado · pra limpar: clean${C_OFF}\n"
    elif [ "$total" -gt 0 ]; then
        printf "${C_ACCENT}│${C_OFF}  💾  Total liberado: ${C_OK}%s${C_OFF}\n" "$(_humano "$total")"
    else
        printf "${C_ACCENT}│${C_OFF}  ✨  Sistema já estava limpo!\n"
    fi
    printf "${C_ACCENT}│${C_OFF}  ⏱   Levou %ss · disco: %s livres\n" "$(( SECONDS - inicio ))" "$(_humano "$espaco_depois")"
    printf "${C_ACCENT}╰────────────────────────────────────────╯${C_OFF}\n"

    # guarda o resultado no log (pra comparar limpezas)
    if [ "$simular" -eq 0 ]; then
        mkdir -p "$DOTFILES_ESTADO" 2> /dev/null &&
            printf '%s  clean  %s liberados\n' "$(_data '%Y-%m-%d %H:%M:%S')" "$(_humano "$total")" >> "$DOTFILES_ESTADO/manutencao.log"
    fi
    return 0
}

# upgrade - atualiza tudo: pacotes do sistema, flatpak, snap, brew e os globais do npm
# Cada etapa mostra a saída original (os gerenciadores perguntam S/n quando precisa).
upgrade() {
    local etapas=() i=0 n inicio=$SECONDS falhas=0
    case "$_PKG" in
        apt)    etapas+=("apt|sudo apt update && sudo apt upgrade") ;;
        pacman) etapas+=("pacman|sudo pacman -Syu") ;;
        dnf)    etapas+=("dnf|sudo dnf upgrade") ;;
        zypper) etapas+=("zypper|sudo zypper update") ;;
    esac
    _tem flatpak && etapas+=("flatpak|flatpak update -y")
    _tem snap && etapas+=("snap|sudo snap refresh")
    _tem brew && etapas+=("brew|brew update && brew upgrade")
    n=${#etapas[@]}
    if [ "$n" -eq 0 ]; then
        _err "não achei nenhum gerenciador de pacotes pra atualizar"
        return 1
    fi

    _cabecalho "ATUALIZANDO O SISTEMA"
    local e nome cmd
    for e in "${etapas[@]}"; do
        nome="${e%%|*}"; cmd="${e#*|}"
        i=$(( i + 1 ))
        _etapa "$i" "$n" "$nome"
        _dica "$cmd"
        if eval "$cmd"; then
            _ok "$nome em dia"
        else
            _err "$nome não terminou"
            falhas=$(( falhas + 1 ))
        fi
    done
    printf "\n"
    if [ "$falhas" -eq 0 ]; then
        _feito "⟳" "sistema atualizado" "$(_plural "$n" etapa etapas) · $(( SECONDS - inicio ))s"
    else
        _aviso "$(_plural "$falhas" "etapa falhou" "etapas falharam")" "rode de novo: upgrade"
    fi
    [ -f /var/run/reboot-required ] && _aviso "o sistema pede reinício pra terminar a atualização" "quando puder: reboot"
    mkdir -p "$DOTFILES_ESTADO" 2> /dev/null &&
        printf '%s  upgrade  %s falhas\n' "$(_data '%Y-%m-%d %H:%M:%S')" "$falhas" >> "$DOTFILES_ESTADO/manutencao.log"
    [ "$falhas" -eq 0 ]
}

# timebox - cronômetro de foco com notificação ao fim
timebox() {
    local minutos="${1:-$TIMEBOX_MIN}"

    if ! [[ "$minutos" =~ ^[0-9]+$ ]]; then
        _uso "timebox [minutos]" "padrão: ${TIMEBOX_MIN}"
        return 1
    fi

    local fim
    fim=$(_data '%H:%M' $(( ${EPOCHSECONDS:-0} + minutos * 60 )))

    _titulo "⏳" "timebox de ${minutos} min" "termina ${fim}"
    _dica "não saiu até lá? anota o gap e segue. revisita depois."

    # Roda num subshell de fundo solto do terminal: ele continua livre e
    # não aparece "[1] 12345" nem "Done" na tela
    ( (
        sleep $(( minutos * 60 ))
        _notificar "⏱ Timebox encerrado" "Passaram ${minutos} minutos. Travou? Anota o gap e avança." critical
    ) > /dev/null 2>&1 & )
}

# _alerta - o que o alias 'alert' chama (ver shell/50-atalhos.sh):  npm run build; alert
_alerta() {
    local st="${1:-0}" cmd
    if [ -n "${ZSH_VERSION:-}" ]; then
        cmd="${_DF_ULTIMO_CMD:-comando}"
    else
        cmd=$(HISTTIMEFORMAT='' history 1)
    fi
    cmd=$(printf '%s' "$cmd" | sed -e 's/^[[:space:]]*[0-9]*[[:space:]]*//' -e 's/[;&|][[:space:]]*alert$//')
    if [ "$st" -eq 0 ]; then
        _notificar "✓ terminou" "$cmd"
    else
        _notificar "✗ falhou (código $st)" "$cmd" critical
    fi
}

# bkp - backup dos seus arquivos de configuração
bkp() {
    local destino
    destino="$HOME/dotfiles-backup/$(_data '%Y-%m-%d_%H-%M')"
    if ! mkdir -p "$destino"; then
        _err "não consegui criar a pasta de backup" "$destino"
        return 1
    fi

    _titulo "💾" "backup de configurações"

    # Cada item: caminho-original|nome-no-backup|como aparece na tela
    local item origem nome rotulo copiados=0
    for item in \
        "$HOME/.bashrc|.bashrc|.bashrc" \
        "$HOME/.zshrc|.zshrc|.zshrc" \
        "$DOTFILES_LOCAL|local.sh|local.sh (teus ajustes)" \
        "$HOME/.config/Code/User/settings.json|vscode-settings.json|settings.json (VS Code)" \
        "$HOME/Library/Application Support/Code/User/settings.json|vscode-settings.json|settings.json (VS Code)" \
        "$HOME/.gitconfig|.gitconfig|.gitconfig" \
        "$HOME/.gitignore_global|.gitignore_global|.gitignore_global" \
        "$HOME/.ssh/config|ssh-config|.ssh/config"
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

    _ok "$(_plural "$copiados" "arquivo salvo" "arquivos salvos")" "$(_curto "$destino")"
}

# _rc_do_shell - o arquivo de início do shell atual (~/.bashrc ou ~/.zshrc) e o do repo
_rc_do_shell() {
    if [ "$_SHELL" = zsh ]; then printf '%s %s' "$HOME/.zshrc" "$DOTFILES/zshrc"
    else printf '%s %s' "$HOME/.bashrc" "$DOTFILES/bashrc"; fi
}

# atualizar - baixa a versão mais nova do teu terminal (repo dotfiles no GitHub),
# recarrega na hora e mostra o que mudou. Não precisa abrir outro terminal.
# Por baixo: git -C ~/dotfiles pull && source ~/.bashrc
atualizar() {
    if [ ! -d "$DOTFILES/.git" ]; then
        _err "não achei o repositório dotfiles em $(_curto "$DOTFILES")" \
             "instale com: git clone https://github.com/briandevbr/dotfiles ~/dotfiles"
        return 1
    fi
    local rc rc_repo
    read -r rc rc_repo <<< "$(_rc_do_shell)"
    # O ~/.bashrc (ou ~/.zshrc) tem que ser um atalho pro do repo, senão a atualização não chega nele
    if [ "$(_caminho_real "$rc")" != "$(_caminho_real "$rc_repo")" ]; then
        _err "teu $(_curto "$rc") não tá ligado ao repositório" \
             "ligue uma vez só: ln -sf $(_curto "$rc_repo") $(_curto "$rc")  (ou rode ~/dotfiles/install.sh)"
        return 1
    fi
    if [ -n "$(git -C "$DOTFILES" status --porcelain 2> /dev/null)" ]; then
        _err "você mexeu nos dotfiles por aqui e isso não tá no GitHub" \
             "ver o que mudou: git -C ~/dotfiles diff  ·  descartar: git -C ~/dotfiles restore ."
        _dica "ajuste pessoal vai em $(_curto "$DOTFILES_LOCAL") — lá o atualizar nunca mexe"
        return 1
    fi

    local antes depois qtd msg t0
    _us t0
    antes=$(git -C "$DOTFILES" rev-parse HEAD)
    if ! _rodar -q "procurando atualização" git -C "$DOTFILES" pull --ff-only -q; then
        _dica "tá sem internet? Se repetir, rode: git -C ~/dotfiles pull"
        return 1
    fi
    depois=$(git -C "$DOTFILES" rev-parse HEAD)

    if [ "$antes" = "$depois" ]; then
        _ok "já tá na versão mais nova" "$(git -C "$DOTFILES" log -1 --format='%h · %cr')"
        return 0
    fi

    qtd=$(git -C "$DOTFILES" rev-list --count "$antes..$depois")
    # shellcheck source=/dev/null
    source "$rc"                             # recarrega aqui mesmo: as mudanças valem na hora
    _feito "⟳" "terminal atualizado" "$(_plural "$qtd" mudança mudanças) · $(_tempo_desde "$t0")"
    while IFS= read -r msg; do
        printf "     ${C_DIM}•${C_OFF} ${C_TEXT}%s${C_OFF}\n" "$msg"
    done < <(git -C "$DOTFILES" log --format='%s' "$antes..$depois")
    _dica "deu ruim? volta pra anterior: git -C ~/dotfiles reset --hard ${antes:0:7} && source $(_curto "$rc")"
}

# tela on|off — liga/desliga a tela do notebook (eDP-1) pelo cosmic-randr
tela() {
    _tem cosmic-randr || { _err "cosmic-randr não encontrado" "esse comando só funciona no COSMIC"; return 1; }
    local saida="eDP-1"
    case "$1" in
        on)
            if cosmic-randr enable "$saida"; then _ok "Tela do notebook ligada"
            else _err "Não consegui ligar a tela $saida" "rode: cosmic-randr list  (confira o nome da saída)"; fi
            ;;
        off)
            _aviso "Vai desligar a tela do notebook" "confirme que o HDMI está ligado, senão fica sem tela"
            if ! _confirma "Continuar?"; then _cancelado; return 0; fi
            if cosmic-randr disable "$saida"; then _ok "Tela do notebook desligada"
            else _err "Não consegui desligar a tela $saida" "rode: cosmic-randr list"; fi
            ;;
        *)
            _err "uso: tela on | tela off"
            ;;
    esac
}
