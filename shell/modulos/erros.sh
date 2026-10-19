# shellcheck shell=bash
# ==========================================
# ERROS — comando não encontrado
# O shell chama _comando_nao_encontrado sozinho quando você digita algo
# que não existe (o gancho de cada shell fica em shell/bash/ e shell/zsh/).
# ==========================================

# _mesmas_letras "gti" "git"  → verdadeiro se forem as mesmas letras embaralhadas
_mesmas_letras() {
    [ "${#1}" -eq "${#2}" ] || return 1
    local resto="$2" i letra
    for (( i = 0; i < ${#1}; i++ )); do
        letra="${1:$i:1}"   # $i: no zsh, ${1:i} seria um modificador
        [[ "$resto" == *"$letra"* ]] || return 1
        resto="${resto/"$letra"/}"           # tira UMA ocorrência da letra
    done
    return 0
}

# _listar_comandos - nomes das tuas funções e aliases (cada shell guarda de um jeito)
_listar_comandos() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        # shellcheck disable=SC2296  # sintaxe do zsh: o bash nunca passa por aqui
        printf '%s\n' "${(k)functions[@]}" "${(k)aliases[@]}"
    else
        compgen -A function -a
    fi
}

# _comando_parecido "gti"  → "git" (procura nos teus comandos + nativos comuns)
_comando_parecido() {
    local nativos="git cd ls cat grep code npm node npx nvm sudo mkdir touch clear exit history man help docker"
    local c
    for c in $(_listar_comandos) $nativos; do
        [[ "$c" == _* ]] && continue
        if _mesmas_letras "$1" "$c"; then
            printf '%s' "$c"
            return 0
        fi
    done
    return 1
}

_comando_nao_encontrado() {
    local sugestao pacote="" cnf
    printf "  ${C_ERR}✗${C_OFF}  ${C_TEXT}%s${C_OFF}${C_DIM}: comando não encontrado${C_OFF}\n" "$1" >&2

    # 1) Erro de digitação? (gti → git, sl → ls, claer → clear)
    sugestao=$(_comando_parecido "$1")
    if [ -n "$sugestao" ]; then
        shift
        printf "     ${C_DIM}↳ quis dizer ${C_TEXT}%s${C_DIM}?${C_OFF}\n" "${sugestao}${*:+ $*}" >&2
        return 127
    fi

    # 2) Existe pacote com esse comando?
    #    Ubuntu/Pop/Debian: command-not-found · Arch: pkgfile
    for cnf in /usr/lib/command-not-found /usr/share/command-not-found/command-not-found; do
        if [ -x "$cnf" ]; then
            pacote=$("$cnf" -- "$1" 2>&1 | grep -m1 -oE 'sudo (apt|snap) install [^ ]+')
            break
        fi
    done
    if [ -z "$pacote" ] && _tem pkgfile; then
        pacote=$(pkgfile -b -- "$1" 2> /dev/null | head -n 1)
        [ -n "$pacote" ] && pacote="sudo pacman -S ${pacote##*/}"
    fi

    if [ -n "$pacote" ]; then
        printf "     ${C_DIM}↳ dá pra instalar: ${C_TEXT}%s${C_OFF}\n" "$pacote" >&2
    else
        printf "     ${C_DIM}↳ ${C_TEXT}dev${C_DIM} teus comandos · ${C_TEXT}help${C_DIM} os do sistema${C_OFF}\n" >&2
    fi
    return 127
}
