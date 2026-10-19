# shellcheck shell=bash
# ==========================================
# INÍCIO — banner de abertura e pasta inicial
# Último módulo: roda depois de tudo carregado (inclusive o teu local.sh).
# _BASHRC_CARREGADO: no 'source ~/.bashrc' (ou no atualizar) nada daqui repete.
# ==========================================

unalias banner 2> /dev/null

# _banner_fixo - o banner de todo terminal: aparece na hora, sem animação.
# A data sai do printf/strftime (builtin) e o tempo do relógio do shell:
# nenhum processo aberto só pra desenhar.
_banner_fixo() {
    local data agora ms=""
    _data_var data '%a %d %b · %H:%M'
    if [ -n "${_DF_T_INI:-}" ]; then
        _us agora
        ms=$(( (agora - _DF_T_INI) / 1000 ))
    fi
    printf "\n  ${C_ACCENT}◈  GROUND CONTROL${C_OFF}   ${C_DIM}%s${C_OFF}" "$data"
    [ -n "$ms" ] && printf "   ${C_DIM}⚡%sms${C_OFF}" "$ms"
    printf "\n  ${C_DIM}   all systems nominal — ${C_TEXT}dev${C_DIM} your tools · ${C_TEXT}help${C_DIM} the system${C_OFF}\n\n"
}

# _banner_linha "rótulo" "texto" - gira um instante e escreve a linha da checagem
_banner_linha() {
    local i
    if _anim; then
        for i in 0 3 6; do
            printf '%s     %s%s%s' "$_CL" "$C_ACCENT" "${_SPIN[i]}" "$C_OFF"
            sleep 0.03
        done
    fi
    printf "%s     ${C_SECAO}▸${C_OFF} ${C_DIM}%s${C_OFF} ${C_TEXT}%s${C_OFF}\n" "$_CL" "$(_pad "$1" 9)" "$2"
}

# _banner_animado - a "sequência de lançamento": título digitado e as checagens do sistema
_banner_animado() {
    local data maq bat ars="" nome t n=0 d
    _data_var data '%a %d %b · %H:%M'

    printf "\n  %s" "$C_ACCENT"
    _digitar "◈  GROUND CONTROL" 0.012
    printf "%s   %s%s%s\n" "$C_OFF" "$C_DIM" "$data" "$C_OFF"

    _banner_linha "sistema" "$(_nome_sistema) · $(_versao_shell)"

    maq="disco $(_humano "$(_livre_bytes /)") livres"
    t=$(_uptime_txt)
    [ -n "$t" ] && maq="$t · $maq"
    bat=$(_bateria) && maq+=" · bateria ${bat%% *}%"
    _banner_linha "máquina" "$maq"

    for nome in git fzf zoxide eza bat delta docker; do
        t="$nome"
        [ "$nome" = bat ] && t="${_BAT:-bat}"
        if _tem "$t"; then ars+="$nome ${C_OK}✓${C_TEXT}  "; else ars+="${C_DIM}$nome ✗${C_TEXT}  "; fi
    done
    _banner_linha "arsenal" "$ars"

    if [ -d "$DEV_HOME" ]; then
        for d in "$DEV_HOME"/*/; do [ -d "$d" ] && n=$(( n + 1 )); done
        _banner_linha "projetos" "$(_curto "$DEV_HOME") · $(_plural "$n" pasta pastas)"
    fi
    printf "  ${C_DIM}   all systems nominal — ${C_TEXT}dev${C_DIM} your tools · ${C_TEXT}help${C_DIM} the system${C_OFF}\n\n"
}

# banner - mostra a sequência de abertura animada quando quiser
banner() { _banner_animado; }

if [ -z "${_BASHRC_CARREGADO:-}" ]; then
    # O banner animado só aparece no primeiro terminal do dia: os outros abrem na hora
    _df_hoje=""
    _df_ultimo=""
    _data_var _df_hoje '%Y-%m-%d'
    [ -r "$DOTFILES_ESTADO/banner-dia" ] && read -r _df_ultimo < "$DOTFILES_ESTADO/banner-dia"
    if [ "$_df_ultimo" != "$_df_hoje" ] && _anim; then
        _banner_animado
        { [ -d "$DOTFILES_ESTADO" ] || mkdir -p "$DOTFILES_ESTADO"; } 2> /dev/null &&
            printf '%s\n' "$_df_hoje" > "$DOTFILES_ESTADO/banner-dia"
    else
        _banner_fixo
    fi
    unset _df_hoje _df_ultimo

    # ==========================================
    # PASTA PADRÃO
    # Só entra na pasta de projetos se o shell abriu no $HOME.
    # Assim o terminal do VS Code, que abre na pasta do projeto,
    # não é sequestrado pra outro lugar.
    # ==========================================
    if [ "$PWD" = "$HOME" ] && [ -d "$DEV_HOME" ]; then
        builtin cd "$DEV_HOME" || true
    fi
fi

# Marca que os dotfiles já carregaram uma vez neste terminal (o banner e o
# "entra na pasta de projetos" não repetem no source / atualizar)
_BASHRC_CARREGADO=1
