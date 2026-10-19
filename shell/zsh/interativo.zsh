# ==========================================
# ZSH — histórico, opções, Tab, teclado, zoxide, fzf e PROMPT
# Único arquivo com sintaxe exclusiva do zsh. Roda no zsh "de verdade"
# (sem emulação), depois dos módulos de shell/.
# O resultado é o mesmo terminal do bash: mesmo prompt, mesmas teclas.
# ==========================================

# ---------- histórico (o mesmo comportamento do bash) ----------
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=50000                    # comandos lembrados na sessão
SAVEHIST=100000                   # comandos guardados no arquivo
setopt EXTENDED_HISTORY           # data e hora em cada comando (history -i mostra)
setopt INC_APPEND_HISTORY         # salva na hora: abas novas e o Ctrl+R já enxergam
setopt HIST_IGNORE_SPACE          # linha com espaço no início não vai pro histórico
setopt HIST_IGNORE_ALL_DUPS       # comando repetido: fica só o mais recente
setopt HIST_REDUCE_BLANKS

# ---------- opções: zsh com cara de bash ----------
setopt INTERACTIVE_COMMENTS       # aceita # comentário na linha de comando
setopt PROMPT_SUBST               # o prompt lê as variáveis a cada Enter
setopt NO_NOMATCH                 # curl url?x=1 não quebra com "no matches found"
setopt NO_BEEP
setopt CHECK_JOBS                 # avisa antes de fechar o terminal com algo rodando

# ---------- Tab ----------
# O índice do Tab (compinit) é conferido 1x por dia; nos outros terminais
# usa o pronto com -C. E fica compilado (zcompile): o zsh lê o .zwc 4x mais
# rápido que o texto — o Tab sai de ~25ms pra ~4ms no startup.
autoload -Uz compinit
() {
    setopt localoptions extendedglob
    if [[ -n $1(#qN.mh-24) ]]; then
        compinit -C -d "$1"
    else
        [[ -d ${1:h} ]] || mkdir -p "${1:h}"
        compinit -d "$1"
        touch "$1"                                  # recomeça a contagem das 24h
    fi
    if [[ ! -s $1.zwc || $1 -nt $1.zwc ]]; then
        zcompile "$1" &!                            # compila em segundo plano, solto do terminal
    fi
} "$DOTFILES_CACHE/zcompdump-$ZSH_VERSION"
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # Tab ignora maiúscula: "doc" completa "Documents"
zstyle ':completion:*' menu select                          # setas escolhem entre as opções
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"     # a lista do Tab vem colorida como o ls
unsetopt LIST_AMBIGUOUS                                     # com várias opções, 1 Tab já lista todas

# Tab dos atalhos: seções do dev/help, branches e containers
compdef "_arguments '1:seção:(${_DEV_SECOES[*]})'" dev
compdef "_arguments '1:seção:(${_HELP_SECOES[*]} diff)'" help
_df_zcomp_branches() {
    local -a b
    b=(${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2> /dev/null)"})
    compadd -a b
}
compdef _df_zcomp_branches gco gm gbd gin
_df_zcomp_containers() {
    local -a c
    c=(${(f)"$(docker ps -a --format '{{.Names}}' 2> /dev/null)"})
    compadd -a c
}
compdef _df_zcomp_containers dlog dsh dstop drm

# ---------- teclado ----------
# Modo emacs explícito: com EDITOR=vim o zsh escolheria o modo vi sozinho
bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search     # ↑ com texto digitado: só comandos que começam com ele
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search   # ↓ volta na mesma busca
bindkey '^[OB' down-line-or-beginning-search
bindkey '^[[1;5C' forward-word                 # Ctrl+→ pula palavra
bindkey '^[[1;5D' backward-word                # Ctrl+← volta palavra
bindkey '^[[H' beginning-of-line '^[[F' end-of-line '^[[3~' delete-char
bindkey '^U' backward-kill-line                # Ctrl+U apaga até o início (igual bash)

# ---------- zoxide e fzf ----------
if _cache_init _df_arq zoxide zoxide init zsh; then
    . "$_df_arq"
    alias cd='z'
fi

_df_fzf=""
for _df_f in /usr/share/doc/fzf/examples/key-bindings.zsh /usr/share/fzf/key-bindings.zsh \
             /usr/share/fzf/shell/key-bindings.zsh "${HOMEBREW_PREFIX:-/sem-brew}/opt/fzf/shell/key-bindings.zsh" \
             "$HOME/.fzf/shell/key-bindings.zsh"; do
    if [[ -f $_df_f ]]; then _df_fzf="$_df_f"; break; fi
done
if [[ -n $_df_fzf ]]; then
    . "$_df_fzf"
    [[ -f ${_df_fzf:h}/completion.zsh ]] && . "${_df_fzf:h}/completion.zsh"
elif _tem fzf && _cache_init _df_arq fzf fzf --zsh; then
    . "$_df_arq"
fi
unset _df_f _df_fzf _df_arq

# ---------- PROMPT ----------
# Mesmo prompt do bash:
#   [brian] in 15:45:10  ~/pasta branch  ✗ erro  ⏱ 12s
#   $
_df_precmd() {
    local st=$? d
    case $st in
        0|130|148) _PS1_ERRO="" ;;                  # Ctrl+C / Ctrl+Z não contam como erro
        *)         _PS1_ERRO="  ✗ $st" ;;
    esac
    if _branch_rapido; then _PS1_BRANCH=" ${REPLY//\%/%%}"; else _PS1_BRANCH=""; fi
    _PS1_TEMPO=""
    if [[ -n ${_DF_T0:-} ]]; then
        d=$(( EPOCHSECONDS - _DF_T0 ))
        if (( d >= ${DOTFILES_LENTO:-5} )); then
            if (( d >= 60 )); then _PS1_TEMPO="  ⏱ $(( d / 60 ))m$(( d % 60 ))s"; else _PS1_TEMPO="  ⏱ ${d}s"; fi
        fi
        unset _DF_T0
    fi
    return $st
}
# preexec: marca quando o comando começou e guarda o texto dele (o 'alert' usa)
_df_preexec() { _DF_T0=$EPOCHSECONDS; _DF_ULTIMO_CMD="$1"; }

# O nosso precmd vai primeiro: precisa ler o $? antes de qualquer outro hook
precmd_functions=(_df_precmd ${precmd_functions:#_df_precmd})
preexec_functions=(_df_preexec ${preexec_functions:#_df_preexec})

PROMPT='%B%F{39}[${PROMPT_NOME}]%b%F{245} in %B%F{141}%D{%H:%M:%S}  %F{51}%~%F{214}${_PS1_BRANCH}%F{196}${_PS1_ERRO}%b%F{245}${_PS1_TEMPO}%f
%B%F{46}%(!.#.$)%f%b '

# Comando não encontrado (no zsh o nome tem um 'r' no fim)
command_not_found_handler() { _comando_nao_encontrado "$@"; }
