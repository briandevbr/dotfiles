# shellcheck shell=bash
# ==========================================
# ENERGIA — desligar, reiniciar e suspender com segurança
#   poweroff [-y] [minutos | cancelar]     (ou: desligar)
#   reboot   [-y] [minutos | cancelar]     (ou: reiniciar)
#   suspend  [-y]                          (ou: suspender)
#
# Antes de qualquer coisa:
#   1. confere o que pode se perder: programas rodando neste terminal,
#      projetos com mudanças não commitadas, instalação de pacote no meio
#   2. pergunta (o -y pula a pergunta)
#   3. salva um log preventivo: avisos e erros do sistema desde o último
#      boot + o histórico do terminal (se algo der errado, o rastro fica)
#   4. contagem regressiva — Ctrl+C ainda cancela
# Linux usa systemctl; macOS usa o próprio sistema (os apps pedem pra salvar);
# no WSL quem desliga é o Windows.
# O comando original continua lá: sudo poweroff / command reboot.
# ==========================================

poweroff()  { _energia desligar "$@"; }
reboot()    { _energia reiniciar "$@"; }
suspend()   { _energia suspender "$@"; }
desligar()  { _energia desligar "$@"; }
reiniciar() { _energia reiniciar "$@"; }
suspender() { _energia suspender "$@"; }

_energia() {
    local acao="$1" sim=0 minutos="" cancelar=0 cmd
    shift
    case "$acao" in desligar) cmd=poweroff ;; reiniciar) cmd=reboot ;; *) cmd=suspend ;; esac
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--sim)           sim=1 ;;
            cancelar|-c)        cancelar=1 ;;
            [0-9]|[0-9][0-9]|[0-9][0-9][0-9]) minutos="$1" ;;
            *)
                _uso "$cmd [-y] [minutos | cancelar]" \
                    "-y pula a pergunta · minutos agenda (ex.: 30) · cancelar desfaz o agendamento"
                return 1
                ;;
        esac
        shift
    done
    if [ "$acao" = suspender ] && { [ -n "$minutos" ] || [ "$cancelar" -eq 1 ]; }; then
        _err "suspender não tem agendamento" "use só: suspend"
        return 1
    fi

    if [ "$cancelar" -eq 1 ]; then
        _energia_cancelar
        return
    fi

    local icone="⏻" verbo
    case "$acao" in
        desligar)  verbo="desligar o computador" ;;
        reiniciar) verbo="reiniciar o computador"; icone="⟳" ;;
        suspender) verbo="suspender (dormir)"; icone="☾" ;;
    esac
    [ "$_SO" = wsl ] && verbo="${verbo/o computador/o WINDOWS inteiro}"

    _titulo "$icone" "$verbo" "${minutos:+daqui a $minutos min · }$(_uptime_txt)"
    _energia_checagem "$acao" || true

    if [ "$sim" -eq 0 ]; then
        if ! _confirma "pode ${verbo%% *}?"; then
            _cancelado
            return 0
        fi
    fi

    _energia_log "$acao" "${minutos:-agora}"

    if [ -n "$minutos" ]; then
        _energia_executar "$acao" "$minutos" || return 1
        _feito "⏲" "agendado" "$verbo às $(_data '%H:%M' $(( ${EPOCHSECONDS:-0} + minutos * 60 )))"
        _dica "mudou de ideia? $cmd cancelar"
        return 0
    fi

    local espera="${DOTFILES_CONTAGEM:-5}"
    [ "$acao" = suspender ] && (( espera > 3 )) && espera=3
    if (( espera > 0 )) && ! _contagem "$espera" "vai ${verbo%% *}"; then
        _cancelado
        return 0
    fi
    _feito "$icone" "${verbo%% *}…" "o log ficou em $(_curto "$DOTFILES_ESTADO/energia")"
    _energia_executar "$acao" || return 1
}

# _energia_checagem acao - o que pode se perder se desligar agora
_energia_checagem() {
    local achou=0 n p mudancas=()

    # programas rodando em segundo plano NESTE terminal
    n=$(( $(jobs -p 2> /dev/null | wc -l) ))
    if (( n > 0 )); then
        _aviso "$(_plural "$n" "programa rodando" "programas rodando") neste terminal" "veja com: jobs"
        achou=1
    fi

    # instalação de pacote no meio do caminho: desligar agora pode quebrar o sistema
    local gerenciador
    for gerenciador in apt apt-get dpkg pacman dnf zypper; do
        if pgrep -x "$gerenciador" > /dev/null 2>&1; then
            _err "o $gerenciador está instalando algo AGORA" "espere terminar: desligar no meio pode quebrar o sistema"
            achou=1
        fi
    done

    # projetos com mudanças que ainda não foram pro git
    if [ -d "$DEV_HOME" ] && [ "$1" != suspender ]; then
        _pendente "conferindo os projetos…"
        for p in "$DEV_HOME"/*/; do
            [ -d "$p/.git" ] || continue
            [ -n "$(git -C "$p" status --porcelain 2> /dev/null | head -n 1)" ] && mudancas+=("$(basename "$p")")
        done
        printf '%s' "$_CL"
        if [ ${#mudancas[@]} -gt 0 ]; then
            _aviso "$(_plural "${#mudancas[@]}" "projeto com mudanças" "projetos com mudanças") fora do git" "${mudancas[*]:0:6}"
            achou=1
        fi
    fi

    # outras pessoas conectadas (servidor, SSH)
    if [ "$_SO" = linux ] && _tem who; then
        n=$(( $(who 2> /dev/null | wc -l) ))
        (( n > 1 )) && { _aviso "$n sessões abertas nesta máquina" "outras pessoas podem estar usando (who)"; achou=1; }
    fi

    (( achou == 0 )) && _ok "nada pendente" "nenhum programa rodando, projetos salvos no git"
    return "$achou"
}

# _energia_log acao quando - log preventivo antes de desligar (guarda os 20 últimos)
_energia_log() {
    local dir="$DOTFILES_ESTADO/energia" arq carimbo
    mkdir -p "$dir" 2> /dev/null || return 0
    carimbo=$(_data '%Y-%m-%d_%H%M%S')
    arq="$dir/$1-$carimbo.log"

    # o histórico do terminal vai pro disco antes (senão os últimos comandos se perdem)
    if [ -n "${ZSH_VERSION:-}" ]; then fc -AI 2> /dev/null; else history -a 2> /dev/null; fi

    {
        printf '# %s · %s (%s)\n' "$1" "$(_data '%d/%m/%Y %H:%M:%S')" "$2"
        printf '# %s · %s · %s\n\n' "$(uname -srm 2> /dev/null)" "$(_uptime_txt)" "$_SHELL"
        if _tem journalctl; then
            printf '## avisos e erros desde o último boot (journalctl -b -p warning)\n'
            journalctl -b -p warning -n 300 --no-pager 2> /dev/null
        elif [ "$_SO" = macos ]; then
            # o log unificado do macOS é enorme: varrer 1h levaria minutos e travaria o desligar
            printf '## erros dos últimos 5 minutos (log show, no máximo 5s procurando)\n'
            _com_limite 5 log show --last 5m --predicate 'messageType == error' --style compact 2> /dev/null | tail -n 300
        fi
    } > "$arq" 2>&1

    printf '%s  %-9s %s  %s\n' "$(_data '%Y-%m-%d %H:%M:%S')" "$1" "$2" "$(_uptime_txt)" >> "$dir/energia.log"

    # guarda só os 20 logs mais recentes de cada tipo
    local antigos=() f
    while IFS= read -r f; do antigos+=("$f"); done < <(command ls -1t "$dir/$1-"*.log 2> /dev/null | tail -n +21)
    [ ${#antigos[@]} -gt 0 ] && command rm -f -- "${antigos[@]}"
    sync 2> /dev/null
    return 0
}

# _energia_executar acao [minutos] - o comando de verdade, de cada sistema
_energia_executar() {
    local acao="$1" min="${2:-}"
    case "$_SO" in
        wsl)
            case "$acao" in
                desligar)  shutdown.exe /s /t $(( ${min:-0} * 60 )) ;;
                reiniciar) shutdown.exe /r /t $(( ${min:-0} * 60 )) ;;
                suspender) rundll32.exe powrprof.dll,SetSuspendState 0,1,0 ;;
            esac
            ;;
        macos)
            if [ -n "$min" ]; then
                local flag="-h"; [ "$acao" = reiniciar ] && flag="-r"
                sudo shutdown "$flag" "+$min"
                return
            fi
            case "$acao" in
                desligar)  osascript -e 'tell application "System Events" to shut down' ;;
                reiniciar) osascript -e 'tell application "System Events" to restart' ;;
                suspender) pmset sleepnow ;;
            esac
            ;;
        *)
            if [ -n "$min" ]; then
                local flag="-h"; [ "$acao" = reiniciar ] && flag="-r"
                command shutdown "$flag" "+$min" 2> /dev/null || sudo shutdown "$flag" "+$min"
                return
            fi
            local verbo
            case "$acao" in
                desligar)  verbo=poweroff ;;
                reiniciar) verbo=reboot ;;
                suspender) verbo=suspend ;;
            esac
            if _tem systemctl; then
                command systemctl "$verbo" 2> /dev/null || sudo systemctl "$verbo"
            elif [ "$acao" = suspender ]; then
                _err "sem systemd não sei suspender este sistema" "tente: sudo pm-suspend"
                return 1
            else
                sudo "$verbo"
            fi
            ;;
    esac || {
        _err "o sistema recusou" "tente com sudo: sudo $acao"
        return 1
    }
}

# _energia_cancelar - desfaz um desligamento/reinício agendado
_energia_cancelar() {
    local ok=1
    case "$_SO" in
        wsl)   shutdown.exe /a > /dev/null 2>&1 && ok=0 ;;
        macos) sudo killall shutdown > /dev/null 2>&1 && ok=0 ;;
        *)     { command shutdown -c 2> /dev/null || sudo shutdown -c; } && ok=0 ;;
    esac
    if [ "$ok" -eq 0 ]; then
        _ok "agendamento cancelado" "o computador continua ligado"
        mkdir -p "$DOTFILES_ESTADO/energia" 2> /dev/null &&
            printf '%s  %-9s\n' "$(_data '%Y-%m-%d %H:%M:%S')" "cancelado" >> "$DOTFILES_ESTADO/energia/energia.log"
    else
        _err "não tinha nada agendado (ou o sistema recusou)"
        return 1
    fi
}
