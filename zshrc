# ~/.zshrc: executado pelo zsh em todo terminal interativo.
# ==========================================
# DOTFILES · ENTRADA DO ZSH  (Linux e macOS)
#
# O ~/.zshrc é um atalho (symlink) pra este arquivo. Ele carrega os MESMOS
# módulos de shell/ que o bash usa — um código só pros dois shells.
#
# Como: os módulos são escritos num jeito de bash que o zsh entende quando
# está em "emulação ksh" (arrays começando do 0, palavras separadas por
# espaço, como no bash). O 'emulate ksh -c' grava essa emulação em cada
# função definida ali: toda vez que a função roda, ela roda do jeito bash,
# e o resto do teu zsh continua zsh normal.
# O que é exclusivo do zsh (prompt, Tab, teclas) fica em shell/zsh/interativo.zsh.
#
# DOTFILES_PERFIL=1 zsh  → mostra quanto cada módulo levou pra carregar
# ==========================================

[[ -o interactive || -n ${DOTFILES_TESTE:-} ]] || return 0

# EPOCHREALTIME e strftime (relógio sem abrir o 'date') vêm desse módulo
zmodload zsh/datetime 2> /dev/null

_df_t=$EPOCHREALTIME
_df_f=${_df_t#*[.,]}
_DF_T_INI="${_df_t%[.,]*}${_df_f[1,6]}"

# Acha a pasta do repositório seguindo o atalho ~/.zshrc → ~/dotfiles/zshrc
# (:A resolve o atalho dentro do próprio zsh, sem abrir processo)
DOTFILES=${${(%):-%x}:A:h}
if [[ ! -f $DOTFILES/shell/00-plataforma.sh ]]; then
    if [[ -f $HOME/dotfiles/shell/00-plataforma.sh ]]; then
        DOTFILES=$HOME/dotfiles
    else
        print -r -- "  ✗ não achei a pasta shell/ dos dotfiles (procurei em $DOTFILES)"
        print -r -- "    ↳ instale com: git clone https://github.com/briandevbr/dotfiles ~/dotfiles && ~/dotfiles/install.sh"
        unset _df_t _df_f
        return 0
    fi
fi
export DOTFILES

for _df_mod in $DOTFILES/shell/[0-9]*.sh; do
    if [[ ${_df_mod:t} == 99-* ]]; then
        # partes exclusivas do zsh e os teus ajustes, logo antes do banner
        [[ -n ${DOTFILES_PERFIL:-} ]] && _df_t=$EPOCHREALTIME
        . $DOTFILES/shell/zsh/interativo.zsh
        [[ -n ${DOTFILES_PERFIL:-} ]] && printf '  %6d µs  %s\n' $(( (EPOCHREALTIME - _df_t) * 1000000 )) "shell/zsh/interativo.zsh"
        [[ -r $DOTFILES_LOCAL ]] && . $DOTFILES_LOCAL
    fi
    [[ -n ${DOTFILES_PERFIL:-} ]] && _df_t=$EPOCHREALTIME
    emulate ksh -o bash_rematch -c '. "$_df_mod"'
    [[ -n ${DOTFILES_PERFIL:-} ]] && printf '  %6d µs  %s\n' $(( (EPOCHREALTIME - _df_t) * 1000000 )) "${_df_mod#$DOTFILES/}"
done
unset _df_t _df_f _df_mod
