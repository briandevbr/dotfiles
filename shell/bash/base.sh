# shellcheck shell=bash
# ==========================================
# BASH — histórico, opções e completar com Tab
# Carrega cedo: os teus aliases do ~/.bash_aliases entram antes dos
# módulos, como sempre foi (o que vem depois vale por cima).
# ==========================================

HISTCONTROL=ignoreboth:erasedups   # ignora linha com espaço no início e comando repetido
shopt -s histappend
HISTSIZE=50000                     # comandos lembrados na sessão (antes: 1000)
HISTFILESIZE=100000                # comandos guardados no arquivo (antes: 2000)
shopt -s checkwinsize

# Histórico com data e hora em cada comando
export HISTTIMEFORMAT="%d/%m/%Y %H:%M:%S  "

# Conforto extra, sem mudar o que já funcionava
shopt -s cmdhist                   # comando de várias linhas vira uma linha só no histórico
shopt -s checkjobs                 # avisa antes de fechar o terminal com algo rodando
shopt -s cdspell dirspell          # cd com letra trocada (cd Docuemnts) acerta sozinho
shopt -s globstar                  # ** entra nas subpastas: ls src/**/*.js

if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    read -r debian_chroot < /etc/debian_chroot   # read: sem abrir o 'cat'
fi

if [ -f ~/.bash_aliases ]; then
    # shellcheck source=/dev/null
    . ~/.bash_aliases
fi

# Completar com Tab (bash-completion): Debian/Ubuntu/Pop, Arch, Fedora e Homebrew
if ! shopt -oq posix; then
    for _df_c in /usr/share/bash-completion/bash_completion /etc/bash_completion \
                 /opt/homebrew/etc/profile.d/bash_completion.sh /usr/local/etc/profile.d/bash_completion.sh; do
        if [ -f "$_df_c" ]; then
            # shellcheck source=/dev/null
            . "$_df_c"
            break
        fi
    done
    unset _df_c
fi
