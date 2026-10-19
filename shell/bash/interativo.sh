# shellcheck shell=bash
# ==========================================
# BASH — zoxide, teclas do fzf, teclado, PROMPT e Tab dos atalhos
# Carrega depois dos módulos: o prompt e o Tab usam funções de lá.
# ==========================================

# zoxide: o cd que lembra das pastas visitadas (cd nome pula direto pra ela)
# O 'zoxide init' fica em cache: sem abrir processo a cada terminal.
if _cache_init _df_arq zoxide zoxide init bash; then
    # shellcheck source=/dev/null
    . "$_df_arq"
    alias cd='z'
fi

# fzf: Ctrl+R (histórico), Ctrl+T (arquivo), Alt+C (pasta)
# Procura o script no lugar de cada sistema; o fzf 0.48+ gera o próprio.
_df_fzf=""
for _df_f in /usr/share/doc/fzf/examples/key-bindings.bash /usr/share/fzf/key-bindings.bash \
             /usr/share/fzf/shell/key-bindings.bash "${HOMEBREW_PREFIX:-/sem-brew}/opt/fzf/shell/key-bindings.bash" \
             "$HOME/.fzf/shell/key-bindings.bash"; do
    if [ -f "$_df_f" ]; then _df_fzf="$_df_f"; break; fi
done
if [ -n "$_df_fzf" ]; then
    # shellcheck source=/dev/null
    . "$_df_fzf"
    # shellcheck source=/dev/null
    [ -f "${_df_fzf%/*}/completion.bash" ] && . "${_df_fzf%/*}/completion.bash"
elif _tem fzf && _cache_init _df_arq fzf fzf --bash; then
    # shellcheck source=/dev/null
    . "$_df_arq"
fi
unset _df_f _df_fzf _df_arq

# ==========================================
# TECLADO — Tab e setas mais espertos
# 2>/dev/null: fora de um terminal de verdade o bind só reclamaria
# ==========================================

bind 'set completion-ignore-case on'    2>/dev/null  # Tab ignora maiúscula: "doc" completa "Documents"
bind 'set show-all-if-ambiguous on'     2>/dev/null  # com várias opções, 1 Tab já lista todas
bind 'set colored-stats on'             2>/dev/null  # a lista do Tab vem colorida como o ls
bind 'set mark-symlinked-directories on' 2>/dev/null # Tab num atalho de pasta já põe a / no fim
bind '"\e[A": history-search-backward'  2>/dev/null  # ↑ com texto digitado: só comandos que começam com ele
bind '"\e[B": history-search-forward'   2>/dev/null  # ↓ volta na mesma busca
bind '"\eOA": history-search-backward'  2>/dev/null  # as mesmas setas, no outro modo que alguns terminais usam
bind '"\eOB": history-search-forward'   2>/dev/null

# ==========================================
# PROMPT
# Fica DEPOIS do zoxide de propósito: ele também usa o PROMPT_COMMAND,
# e o nosso hook precisa ser o primeiro a ler o $? do último comando.
# ==========================================

# Roda antes de cada prompt: guarda o erro do último comando, a branch atual
# e quanto o comando levou (se foi lento). Não abre processo nenhum:
# a branch vem do .git/HEAD lido direto (_branch_rapido, no módulo do git).
_prompt_hook() {
    local st=$? d
    case "$st" in
        0|130|148) _PS1_ERRO="" ;;          # 130 = Ctrl+C, 148 = Ctrl+Z: foi você que parou, não é erro
        *)         _PS1_ERRO="  ✗ $st" ;;
    esac
    if _branch_rapido; then _PS1_BRANCH=" $REPLY"; else _PS1_BRANCH=""; fi

    _PS1_TEMPO=""
    if [ -n "${_DF_T0:-}" ]; then            # _DF_T0: marcado pelo PS0 quando o comando começou
        d=$(( ${EPOCHSECONDS:-0} - _DF_T0 ))
        if (( d >= ${DOTFILES_LENTO:-5} )); then
            if (( d >= 60 )); then _PS1_TEMPO="  ⏱ $(( d / 60 ))m$(( d % 60 ))s"; else _PS1_TEMPO="  ⏱ ${d}s"; fi
        fi
        unset _DF_T0
    fi
    history -a 2> /dev/null                  # salva o comando na hora: abas novas e o Ctrl+R já enxergam
    return "$st"                             # devolve o $? intacto pros próximos hooks
}

# O 'if' evita duplicar o hook quando você roda 'source ~/.bashrc'
if [[ "$PROMPT_COMMAND" != *_prompt_hook* ]]; then
    PROMPT_COMMAND="_prompt_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

# PS0 aparece logo antes do comando rodar. A conta $((…)) guarda a hora de
# início em _DF_T0 sem abrir processo e não imprime nada (substring vazia).
_DF_PS0=x
PS0='${_DF_PS0:$((_DF_T0=EPOCHSECONDS,0)):0}'

# Cores do prompt: negrito + tons vivos, pra achar ele de relance no meio da saída
P_USER=$'\033[1;38;5;39m'     # azul vivo      [brian]
P_SEP=$'\033[0;38;5;245m'     # cinza          " in " (sem negrito: só separa)
P_HORA=$'\033[1;38;5;141m'    # lilás vivo     hora
P_PASTA=$'\033[1;38;5;51m'    # ciano vivo     pasta atual
P_BRANCH=$'\033[1;38;5;214m'  # laranja vivo   branch do git
P_ERRO=$'\033[1;38;5;196m'    # vermelho vivo  ✗ código do erro
P_CIFRAO=$'\033[1;38;5;46m'   # verde forte    $

# Linha 1: [brian] in 15:45:10  ~/pasta branch  ✗ erro  ⏱ 12s
# Linha 2: só o $ verde
# Aspas simples: as variáveis são lidas a CADA prompt, não uma vez só.
# Todo código de cor fica entre \[ \] — sem isso o bash erra a largura
# da linha e o texto se embola quando o comando é comprido.
PS1='\[${P_USER}\][${PROMPT_NOME}]\[${P_SEP}\] in \[${P_HORA}\]\t  \[${P_PASTA}\]\w\[${P_BRANCH}\]${_PS1_BRANCH}\[${P_ERRO}\]${_PS1_ERRO}\[${P_SEP}\]${_PS1_TEMPO}\[${C_OFF}\]\n\[${P_CIFRAO}\]\$\[${C_OFF}\] '

# ==========================================
# TAB DOS ATALHOS
# ==========================================

# Tab completa as seções do dev e do help (e os tópicos originais do help)
complete -W "${_DEV_SECOES[*]}" dev
complete -A helptopic -W "${_HELP_SECOES[*]} diff" help

# Tab completa nomes de branch nos atalhos que recebem branch
_df_comp_branches() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    mapfile -t COMPREPLY < <(compgen -W "$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2> /dev/null)" -- "$cur")
}
complete -F _df_comp_branches gco gm gbd gin

# Tab completa nome de container nos atalhos do docker
_df_comp_containers() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    mapfile -t COMPREPLY < <(compgen -W "$(docker ps -a --format '{{.Names}}' 2> /dev/null)" -- "$cur")
}
complete -F _df_comp_containers dlog dsh dstop drm

# Comando não encontrado: o bash chama esta função sozinho (ver shell/90-erros.sh)
command_not_found_handle() { _comando_nao_encontrado "$@"; }
