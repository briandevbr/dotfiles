# ~/.bashrc: executado pelo bash(1) para shells sem login.
# ==========================================
# DOTFILES · ENTRADA DO BASH  (Linux, WSL e bash 4.4+ no macOS)
#
# O ~/.bashrc é um atalho (symlink) pra este arquivo. Ele só prepara o
# terreno e carrega os módulos de shell/ — o código de verdade mora lá,
# um assunto por arquivo, na ordem do número:
#
#   shell/00-plataforma.sh    onde está rodando (Linux, macOS, WSL) + compatibilidade
#   shell/10-config.sh        CONFIGURAÇÃO — mude aqui
#   shell/bash/base.sh        histórico, opções e Tab do bash
#   shell/20-ui.sh            paleta, respostas padronizadas, spinner, barra de progresso
#   shell/30-ferramentas.sh   fzf, eza, bat, fd, delta, nvm (só o que estiver instalado)
#   shell/40-modulos.sh       carregamento sob demanda dos comandos (ver abaixo)
#   shell/50-atalhos.sh       aliases: .., p, rm -i, nomes antigos…
#   shell/bash/interativo.sh  prompt, teclado, zoxide, teclas do fzf e Tab dos atalhos
#   ~/.config/dotfiles/local.sh  TEUS ajustes (fora do repo: o atualizar não mexe)
#   shell/99-inicio.sh        banner de abertura e pasta inicial
#
# Os comandos em si moram em shell/modulos/ e só são lidos na primeira vez
# que você usa um deles — é isso que deixa o terminal abrir na hora:
#   navegacao · utilitarios · git · node · docker · rede · sistema · energia · paineis · erros
#
# DOTFILES_PERFIL=1 bash  → mostra quanto cada módulo levou pra carregar
# ==========================================

case $- in
    *i*) ;;
      *) [ -n "${DOTFILES_TESTE:-}" ] || return ;;   # DOTFILES_TESTE: a suíte de testes carrega sem terminal
esac

# bash 3.2 (o que vem no macOS) não tem o que os módulos usam
if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
    printf '  ! bash %s é antigo demais pra estes dotfiles (precisa do 4.4 ou mais novo)\n' "$BASH_VERSION"
    printf '    ↳ no macOS use o zsh (já é o padrão) ou instale um bash novo: brew install bash\n'
    return
fi

# Hora do início, pro banner mostrar quanto o terminal levou pra abrir
_df_t="${EPOCHREALTIME:-0.000000}"
_DF_T_INI="${_df_t%[.,]*}${_df_t#*[.,]}"

# Acha a pasta do repositório seguindo o atalho ~/.bashrc → ~/dotfiles/bashrc.
# O -ef compara o arquivo de verdade sem abrir processo; o readlink só roda
# se o repo estiver num lugar diferente do padrão.
if [ "${BASH_SOURCE[0]}" -ef "$HOME/dotfiles/bashrc" ]; then
    DOTFILES="$HOME/dotfiles"
else
    _df_src="${BASH_SOURCE[0]}"
    while [ -L "$_df_src" ]; do
        _df_dest=$(readlink -- "$_df_src") || break
        case "$_df_dest" in /*) _df_src="$_df_dest" ;; *) _df_src="${_df_src%/*}/$_df_dest" ;; esac
    done
    case "$_df_src" in */*) ;; *) _df_src="./$_df_src" ;; esac
    DOTFILES=$(cd -P -- "${_df_src%/*}" && pwd)
fi
if [ ! -f "$DOTFILES/shell/00-plataforma.sh" ]; then
    printf '  ✗ não achei a pasta shell/ dos dotfiles (procurei em %s)\n' "$DOTFILES"
    printf '    ↳ instale com: git clone https://github.com/briandevbr/dotfiles ~/dotfiles && ~/dotfiles/install.sh\n'
    unset _df_t _df_src _df_dest
    return
fi
export DOTFILES

# Monta a ordem: os módulos em ordem de número, com as partes do bash encaixadas
_df_lista=()
for _df_mod in "$DOTFILES"/shell/[0-9]*.sh; do
    case "${_df_mod##*/}" in 99-*) _df_lista+=("$DOTFILES/shell/bash/interativo.sh" LOCAL) ;; esac
    _df_lista+=("$_df_mod")
    case "${_df_mod##*/}" in 10-*) _df_lista+=("$DOTFILES/shell/bash/base.sh") ;; esac
done

# Carrega no nível de cima do arquivo (não dentro de função): assim tudo
# que os módulos definem fica valendo pro terminal inteiro
for _df_mod in "${_df_lista[@]}"; do
    if [ "$_df_mod" = LOCAL ]; then
        _df_mod="$DOTFILES_LOCAL"
        [ -r "$_df_mod" ] || continue
    fi
    [ -n "${DOTFILES_PERFIL:-}" ] && _df_t="${EPOCHREALTIME/[.,]/}"
    # shellcheck source=/dev/null
    . "$_df_mod"
    [ -n "${DOTFILES_PERFIL:-}" ] && printf '  %6d µs  %s\n' $(( ${EPOCHREALTIME/[.,]/} - _df_t )) "${_df_mod/#$HOME/\~}"
done
unset _df_t _df_src _df_dest _df_mod _df_lista
