# shellcheck shell=bash
# ==========================================
# MÓDULOS SOB DEMANDA — o segredo do terminal abrir na hora
#
# Os comandos (git, docker, clean, painéis…) moram em shell/modulos/.
# Ler todos eles a cada terminal custaria ~10ms. Em vez disso, cada
# comando começa como uma "casca" de uma linha só:
#
#     gs() { _df_sob_demanda git gs "$@"; }
#
# Na primeira vez que você usa QUALQUER comando de um módulo, a casca
# carrega o módulo inteiro (que troca as cascas pelas funções de verdade)
# e repassa a chamada. Você não percebe nada — só que abre mais rápido.
#
# A lista de cascas (o "índice") se monta sozinha lendo os módulos e fica
# em cache. Criou uma função nova num módulo? O índice se refaz no próximo
# terminal, porque o módulo ficou mais novo que o cache.
# Regra pra quem mexe nos módulos: função no começo da linha (nome() {) e
# nada de alias lá dentro — alias mora em shell/50-atalhos.sh.
# ==========================================

_DF_CARREGADOS=""                       # módulos já carregados neste terminal

# _df_carregar_modulo nome - lê shell/modulos/<nome>.sh (uma vez por terminal)
_df_carregar_modulo() {
    case " $_DF_CARREGADOS " in *" $1 "*) return 0 ;; esac
    _DF_ARQ="$DOTFILES/shell/modulos/$1.sh"
    if [ ! -r "$_DF_ARQ" ]; then
        _err "módulo $1 não encontrado" "o repositório mudou: rode source ~/.${_SHELL}rc"
        return 1
    fi
    _DF_CARREGADOS+=" $1"
    if [ -n "${ZSH_VERSION:-}" ]; then
        emulate ksh -o bash_rematch -c '. "$_DF_ARQ"'   # mesma emulação dos outros módulos (ver zshrc)
    else
        # shellcheck source=/dev/null
        . "$_DF_ARQ"
    fi
}

# _df_sob_demanda módulo função [args...] - o corpo de toda casca
_df_sob_demanda() {
    local mod="$1" fn="$2"
    shift 2
    case " $_DF_CARREGADOS " in
        *" $mod "*)                     # o módulo carregou e mesmo assim a função não veio
            _err "$fn não existe mais no módulo $mod" "o repositório mudou: rode source ~/.${_SHELL}rc"
            return 127 ;;
    esac
    _df_carregar_modulo "$mod" || return 1
    "$fn" "$@"
}

# _df_indice - garante o índice de cascas em dia e põe o caminho em _DF_IDX.
# Refaz quando: não existe, algum módulo mudou, entrou/saiu módulo, ou o
# repositório mudou de lugar.
_df_indice() {
    local mod nome nomes f cab="" linha="" refazer=0
    _DF_IDX="$DOTFILES_CACHE/indice.$_SHELL.sh"
    for mod in "$DOTFILES"/shell/modulos/*.sh; do
        cab+=" ${mod##*/}"
        [ "$mod" -nt "$_DF_IDX" ] && refazer=1
    done
    cab="# indice dotfiles:$cab · $DOTFILES"
    [ -s "$_DF_IDX" ] && read -r linha < "$_DF_IDX"
    [ "$linha" != "$cab" ] && refazer=1
    [ "$refazer" -eq 0 ] && return 0

    [ -d "$DOTFILES_CACHE" ] || mkdir -p "$DOTFILES_CACHE" || return 1
    {
        printf '%s\n' "$cab"
        for mod in "$DOTFILES"/shell/modulos/*.sh; do
            nome="${mod##*/}"; nome="${nome%.sh}"
            nomes=$(sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)[[:space:]]*()[[:space:]]*{.*/\1/p' "$mod" | tr '\n' ' ')
            [ -z "$nomes" ] && continue
            # tira alias velho com o mesmo nome antes de criar a casca (senão o alias expande na definição)
            printf 'unalias %s 2> /dev/null\n' "$nomes"
            for f in $nomes; do
                printf '%s() { _df_sob_demanda %s %s "$@"; }\n' "$f" "$nome" "$f"
            done
        done
    } > "$_DF_IDX.$$" && command mv -f "$_DF_IDX.$$" "$_DF_IDX"
}

# _df_versao_disco - põe em REPLY o commit em que o repositório está, lendo o .git
# direto (sem abrir o git). Guardado em _DF_VERSAO = o que ESTE terminal carregou:
# se outro terminal (ou um git pull) atualizar o repo, o atualizar percebe a diferença.
_df_versao_disco() {
    local g="$DOTFILES/.git" head sha nome
    REPLY=""
    [ -r "$g/HEAD" ] || return 1
    read -r head < "$g/HEAD"
    case "$head" in
        "ref: "*)
            head="${head#ref: }"
            if [ -r "$g/$head" ]; then
                read -r REPLY < "$g/$head"
            elif [ -r "$g/packed-refs" ]; then
                while read -r sha nome; do
                    if [ "$nome" = "$head" ]; then REPLY="$sha"; break; fi
                done < "$g/packed-refs"
            fi ;;
        *) REPLY="$head" ;;                       # commit solto, sem branch
    esac
    [ -n "$REPLY" ]
}
_DF_VERSAO=""
if _df_versao_disco; then _DF_VERSAO="$REPLY"; fi

if _df_indice; then
    # shellcheck source=/dev/null
    . "$_DF_IDX"
else
    # sem cache gravável (disco cheio, home só leitura): carrega tudo na hora, do jeito antigo
    for _df_m in "$DOTFILES"/shell/modulos/*.sh; do
        _df_m="${_df_m##*/}"
        _df_carregar_modulo "${_df_m%.sh}"
    done
    unset _df_m
fi
