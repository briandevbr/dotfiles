# shellcheck shell=bash
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
    if [ -n "${3:-}" ]; then printf "   ${C_DIM}%s${C_OFF}" "$3"; fi
    printf "\n"
}

# _ok "mensagem" ["detalhe"]
_ok() { _feito "✓" "$1" "${2:-}"; }

# _err "o que deu errado" ["como resolver"]  — vai pro stderr e retorna 1
_err() {
    {
        printf "${_CL}  ${C_ERR}✗${C_OFF}  ${C_TEXT}%s${C_OFF}\n" "$1"
        if [ -n "${2:-}" ]; then printf "     ${C_DIM}↳ %s${C_OFF}\n" "$2"; fi
    } >&2
    return 1
}

# _aviso "atenção" ["detalhe"]
_aviso() {
    printf "${_CL}  ${C_WARN}!${C_OFF}  ${C_TEXT}%s${C_OFF}\n" "$1"
    if [ -n "${2:-}" ]; then printf "     ${C_DIM}↳ %s${C_OFF}\n" "$2"; fi
}

# _dica "texto"  — linha de apoio, discreta
_dica() { printf "     ${C_DIM}↳ %s${C_OFF}\n" "$*"; }

# _titulo "ícone" "ação" ["alvo"]  — abre uma operação que vai demorar
_titulo() {
    printf "  ${C_ACCENT}%s${C_OFF}  ${C_TEXT}%s${C_OFF}" "$1" "$2"
    if [ -n "${3:-}" ]; then printf "  ${C_DIM}%s${C_OFF}" "$3"; fi
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
# O <inicio> vem do _us (microssegundos): mede tempo sem chamar o binário 'date'
_tempo_desde() {
    local agora us
    _us agora
    us=$(( agora - $1 ))
    if (( us < 1000000 )); then
        printf '%dms' $(( us / 1000 ))
    elif (( us < 60000000 )); then
        printf '%d.%ds' $(( us / 1000000 )) $(( us % 1000000 / 100000 ))
    else
        printf '%dm%02ds' $(( us / 60000000 )) $(( us / 1000000 % 60 ))
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

# _pad "texto" largura → texto completado com espaços até a largura (contando letras, não bytes)
_pad() {
    local n=$(( $2 - ${#1} ))
    (( n < 0 )) && n=0
    printf '%s%*s' "$1" "$n" ''
}

_secao()     { printf "\n${C_SECAO}  ▸ %s${C_OFF}\n" "$1"; }
_cabecalho() {
    printf "\n${C_ACCENT}\033[1m  ◈  %s${C_OFF}\n" "$1"
    printf "${C_DIM}  ────────────────────────────────────────${C_OFF}\n"
}

# ==========================================
# PROMPT — a branch do git sem abrir o git
# ==========================================

# _branch_rapido - põe em REPLY a branch atual lendo o .git/HEAD direto.
# O prompt chama isso a CADA Enter: abrir o 'git branch' toda vez custava
# 2-5ms por prompt. Aqui é só 'read' (builtin), sem processo nenhum.
# HEAD solto (no meio de um rebase, checkout de commit): mostra o hash curto.
_branch_rapido() {
    local d="$PWD" head="" gitdir
    REPLY=""
    while :; do
        if [ -f "$d/.git/HEAD" ]; then
            gitdir="$d/.git"
            break
        elif [ -f "$d/.git" ]; then           # worktree e submódulo: ".git" é um arquivo "gitdir: caminho"
            read -r gitdir < "$d/.git"
            gitdir="${gitdir#gitdir: }"
            [[ "$gitdir" != /* ]] && gitdir="$d/$gitdir"
            break
        fi
        [ -z "$d" ] && return 1
        d="${d%/*}"
    done
    read -r head < "$gitdir/HEAD" 2> /dev/null || return 1
    case "$head" in
        "ref: refs/heads/"*) REPLY="${head#ref: refs/heads/}" ;;
        "ref: "*)            REPLY="${head#ref: }" ;;
        *)                   REPLY="${head:0:7}" ;;
    esac
    [ -n "$REPLY" ]
}

# ==========================================
# ANIMAÇÃO — spinner, barra de progresso, contagem e máquina de escrever
# Só anima num terminal de verdade e com DOTFILES_ANIM=1. Num pipe, num
# script ou com DOTFILES_ANIM=0 tudo vira texto fixo — o resultado é o mesmo.
# ==========================================

_SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

# _anim — as animações estão ligadas aqui?
_anim() { [ "${DOTFILES_ANIM:-1}" = 1 ] && [ -t 1 ]; }

# _repete "█" 5  → "█████"
_repete() {
    local s="" i
    for (( i = 0; i < $2; i++ )); do s+="$1"; done
    printf '%s' "$s"
}

# _barra atual total [largura]  → ██████░░░░ (cheio em azul, vazio em cinza)
_barra() {
    local total=$2 larg=${3:-20} cheio
    (( total < 1 )) && total=1
    cheio=$(( $1 * larg / total ))
    (( cheio > larg )) && cheio=$larg
    printf '%s%s%s%s%s' "$C_ACCENT" "$(_repete █ "$cheio")" \
        "$C_DIM" "$(_repete ░ $(( larg - cheio )))" "$C_OFF"
}

# _etapa atual total "texto"  — cabeçalho de etapa: [2/6] ███░░░ texto
_etapa() {
    printf "\n  ${C_DIM}[%s/%s]${C_OFF} %s  ${C_TEXT}%s${C_OFF}\n" "$1" "$2" "$(_barra "$1" "$2" 12)" "$3"
}

# _rodar [-q] "mensagem" comando [args...]  — roda o comando com spinner
#   enquanto roda:  ⠹  mensagem  4s
#   deu certo:      ✓  mensagem   1.2s      (-q: não escreve, quem chamou escreve)
#   deu errado:     ✗  mensagem — falhou  + as últimas linhas da saída
# A saída do comando fica em _RODAR_SAIDA (igual o _GIT_SAIDA do git).
# Ctrl+C cancela o comando de verdade (não deixa nada rodando escondido).
# Comando que pergunta alguma coisa NÃO passa por aqui: a entrada vem do
# /dev/null. Pro sudo: rode 'sudo -v' antes e use 'sudo -n' no comando.
_rodar() {
    local quieto=0
    if [ "$1" = "-q" ]; then quieto=1; shift; fi
    local msg="$1"; shift
    local log t0 cod=0 pid i=0 inicio=$SECONDS seg trap_antes=""
    _us t0
    [ -d "$DOTFILES_CACHE" ] || mkdir -p "$DOTFILES_CACHE"
    log="$DOTFILES_CACHE/rodar.$$.log"

    if ! _anim; then
        _pendente "$msg…"
        "$@" < /dev/null > "$log" 2>&1 || cod=$?
    else
        # Sem controle de jobs o shell não escreve "[1] 12345" nem "Done" na tela
        if [ -n "${ZSH_VERSION:-}" ]; then
            setopt localoptions localtraps nomonitor nonotify
        else
            local -; set +m
            trap_antes=$(trap -p INT)
        fi
        # o { } 2>/dev/null engole o "[1] 12345" que o bash interativo escreve ao soltar o job
        { "$@" < /dev/null > "$log" 2>&1 & } 2> /dev/null
        pid=$!
        trap 'kill "$pid" 2> /dev/null' INT
        printf '\033[?25l'                         # esconde o cursor enquanto gira
        while kill -0 "$pid" 2> /dev/null; do
            seg=$(( SECONDS - inicio ))
            printf '%s  %s%s%s  %s%s%s' "$_CL" "$C_ACCENT" "${_SPIN[i % 10]}" "$C_OFF" "$C_TEXT" "$msg" "$C_OFF"
            (( seg >= 2 )) && printf '  %s%ss%s' "$C_DIM" "$seg" "$C_OFF"
            i=$(( i + 1 ))
            sleep 0.1
        done
        wait "$pid" 2> /dev/null
        cod=$?
        printf '\033[?25h'
        if [ -z "${ZSH_VERSION:-}" ]; then
            if [ -n "$trap_antes" ]; then eval "$trap_antes"; else trap - INT; fi
        fi
    fi

    _RODAR_SAIDA=$(< "$log")
    command rm -f "$log"

    if [ "$cod" -eq 0 ]; then
        if [ "$quieto" -eq 1 ]; then printf '%s' "$_CL"; else _feito "✓" "$msg" "$(_tempo_desde "$t0")"; fi
        return 0
    fi
    if [ "$cod" -eq 130 ] || [ "$cod" -eq 143 ]; then
        _aviso "cancelado" "$msg — parou no meio (Ctrl+C)"
        return "$cod"
    fi
    {
        printf "${_CL}  ${C_ERR}✗${C_OFF}  ${C_TEXT}%s — falhou${C_OFF}   ${C_DIM}código %s${C_OFF}\n" "$msg" "$cod"
        local linha n=0
        while IFS= read -r linha; do
            [ -z "$linha" ] && continue
            printf "     ${C_DIM}│${C_OFF} %s\n" "$linha"
            n=$(( n + 1 ))
        done < <(printf '%s\n' "$_RODAR_SAIDA" | tail -n 6)
    } >&2
    return "$cod"
}

# _contagem segundos "texto"  — contagem regressiva antes de algo sem volta.
# Ctrl+C cancela: retorna 1 e quem chamou desiste.
_contagem() {
    local n=$(( $1 * 10 )) msg="$2" cancelou=0 i=0 trap_antes=""
    if [ -n "${ZSH_VERSION:-}" ]; then
        setopt localoptions localtraps
    else
        trap_antes=$(trap -p INT)
    fi
    trap 'cancelou=1' INT
    while (( n > 0 && cancelou == 0 )); do
        if [ -t 1 ]; then
            printf '%s  %s%s%s  %s%s em %s%ss%s   %sCtrl+C cancela%s' "$_CL" "$C_WARN" "${_SPIN[i % 10]}" "$C_OFF" \
                "$C_TEXT" "$msg" "$C_WARN" $(( (n + 9) / 10 )) "$C_OFF" "$C_DIM" "$C_OFF"
        fi
        sleep 0.1
        n=$(( n - 1 )); i=$(( i + 1 ))
    done
    if [ -z "${ZSH_VERSION:-}" ]; then
        if [ -n "$trap_antes" ]; then eval "$trap_antes"; else trap - INT; fi
    fi
    [ -t 1 ] && printf '%s' "$_CL"
    (( cancelou == 0 ))
}

# _digitar "texto" [atraso]  — escreve letra por letra (máquina de escrever)
_digitar() {
    local txt="$1" atraso="${2:-0.01}" i
    if ! _anim; then printf '%s' "$txt"; return 0; fi
    for (( i = 0; i < ${#txt}; i++ )); do
        printf '%s' "${txt:$i:1}"
        sleep "$atraso"
    done
}
