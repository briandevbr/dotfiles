# shellcheck shell=bash
# ==========================================
# NAVEGAÇÃO
# (os aliases de navegação e de segurança — .., p, rm -i… — ficam em
#  shell/50-atalhos.sh: alias precisa existir desde o início do terminal)
# ==========================================

# open - abre a pasta atual no gerenciador de arquivos e libera o terminal na hora.
# Com argumento abre o que você passar: open src · open foto.png · open https://...
# No macOS, com opção (open -a Safari) vira o 'open' original do sistema.
open() {
    if [ "$_SO" = macos ] && [[ "${1:-}" == -* ]]; then
        command open "$@"
        return
    fi
    local alvo="${1:-.}"
    if [[ "$alvo" != *://* ]] && [ ! -e "$alvo" ]; then
        _err "não encontrei: $alvo" "confira o nome (o Tab completa)"
        return 1
    fi
    _abrir "$alvo"
    if [ "$alvo" = "." ]; then
        _ok "abrindo" "$(_curto)"
    else
        _ok "abrindo" "$alvo"
    fi
}

# mkcd - cria a pasta e já entra nela
# Usa 'builtin cd' porque o alias cd='z' (zoxide) trabalha com histórico
# de pastas já visitadas - uma pasta recém-criada ainda não está lá.
mkcd() {
    if [ -z "$1" ]; then
        _uso "mkcd <nome-da-pasta>" "cria a pasta (e as do meio) e já entra nela"
        return 1
    fi
    if ! mkdir -p -- "$1" 2> /dev/null || ! builtin cd -- "$1"; then
        _err "não consegui criar '$1'" "confira se você tem permissão nesta pasta"
        return 1
    fi
    _ok "criada e acessada" "$(_curto)"
}

# up [n] - sobe n pastas de uma vez (up 3 = cd ../../..)
up() {
    local n="${1:-1}" destino="" i
    if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ]; then
        _uso "up [n]" "sobe n pastas de uma vez (padrão: 1)"
        return 1
    fi
    for (( i = 0; i < n; i++ )); do destino+="../"; done
    builtin cd -- "$destino" || return 1
    _ok "subiu $(_plural "$n" pasta pastas)" "$(_curto)"
}

# cdr - volta pra raiz do repositório git (de qualquer subpasta dele)
cdr() {
    local raiz
    if ! raiz=$(git rev-parse --show-toplevel 2> /dev/null); then
        _err "aqui não é um repositório git" "entre na pasta do projeto antes"
        return 1
    fi
    builtin cd -- "$raiz" || return 1
    _ok "raiz do repositório" "$(_curto)"
}

# tmpd [nome] - cria uma pasta temporária e entra nela (pra testes rápidos)
tmpd() {
    local d
    if ! d=$(mktemp -d "${TMPDIR:-/tmp}/${1:-rascunho}.XXXXXX" 2> /dev/null); then
        _err "não consegui criar a pasta temporária"
        return 1
    fi
    builtin cd -- "$d" || return 1
    _ok "pasta temporária" "$d"
    _dica "ela some sozinha quando o sistema reiniciar"
}

# proj - pula direto pra qualquer projeto via busca interativa
# A prévia mostra os últimos commits do projeto (ou os arquivos, se não for git)
proj() {
    if [ ! -d "$DEV_HOME" ]; then
        _err "pasta de projetos não existe: $(_curto "$DEV_HOME")" "crie com: mkdir -p \"$DEV_HOME\""
        return 1
    fi
    _precisa fzf || return 1

    # Glob em vez de 'find -printf' (só existe no GNU): funciona no macOS e não abre processo
    local d nomes=() escolhido
    for d in "$DEV_HOME"/*/; do
        [ -d "$d" ] || continue
        d="${d%/}"
        nomes+=("${d##*/}")
    done
    if [ ${#nomes[@]} -eq 0 ]; then
        _aviso "nenhum projeto em $(_curto "$DEV_HOME") ainda" "comece um com: mkcd \"$DEV_HOME/nome\""
        return 0
    fi

    escolhido=$(printf '%s\n' "${nomes[@]}" \
        | fzf --height=40% --reverse --prompt='projeto ❯ ' --border=rounded \
              --preview 'git -C "$DEV_HOME"/{} log --oneline --color=always -12 2> /dev/null || ls -A "$DEV_HOME"/{}' \
              --preview-window=right:55%)

    [ -z "$escolhido" ] && return 0          # Esc: cancelou, sem drama
    builtin cd "$DEV_HOME/$escolhido" || return 1
    _ok "$escolhido" "$(_curto)"
}

# ==========================================
# ARQUIVOS
# ==========================================

# extract - descompacta qualquer formato sem você lembrar a flag certa.
# Nunca sobrescreve: arquivo que já existe na pasta fica como estava.
extract() {
    local formatos=".zip .tar.gz .tgz .tar.bz2 .tar.xz .tar.zst .tar .gz .bz2 .xz .zst .rar .7z"
    if [ -z "$1" ]; then
        _uso "extract <arquivo>" "$formatos"
        return 1
    fi
    if [ ! -f "$1" ]; then
        _err "arquivo não encontrado: $1"
        return 1
    fi

    local arq="$1" nome="${1##*/}" t0 cmd=()
    case "$arq" in
        *.tar.gz|*.tgz)   cmd=(tar -xzf "$arq") ;;
        *.tar.bz2|*.tbz2) cmd=(tar -xjf "$arq") ;;
        *.tar.xz|*.txz)   cmd=(tar -xJf "$arq") ;;
        *.tar.zst|*.tzst) _precisa zstd || return 1; cmd=(tar -xf "$arq") ;;
        *.tar)            cmd=(tar -xf "$arq") ;;
        *.gz)             cmd=(gunzip "$arq") ;;
        *.bz2)            cmd=(bunzip2 "$arq") ;;
        *.xz)             cmd=(unxz "$arq") ;;
        *.zst)            _precisa zstd || return 1; cmd=(zstd -dq --rm "$arq") ;;
        *.zip)            _precisa unzip || return 1; cmd=(unzip -q -n "$arq") ;;
        *.rar)            _precisa unrar || return 1; cmd=(unrar x -o- "$arq") ;;
        *.7z)             _precisa 7z || return 1; cmd=(7z x -aos "$arq") ;;
        *)
            _err "formato não reconhecido: $1" "$formatos"
            return 1
            ;;
    esac

    _us t0
    if ! _rodar -q "extraindo $nome" "${cmd[@]}"; then
        _dica "arquivo corrompido ou download incompleto?"
        return 1
    fi
    _feito "📦" "extraído" "$nome → $(_curto) · $(_tempo_desde "$t0")"
}

# compactar - o contrário do extract: pasta ou arquivo vira nome.tar.gz (ou outro formato)
compactar() {
    local alvo="${1%/}" fmt="${2:-tar.gz}"
    if [ -z "$alvo" ]; then
        _uso "compactar <pasta|arquivo> [formato]" "formatos: tar.gz (padrão) · zip · tar.xz · tar.zst · 7z"
        return 1
    fi
    if [ ! -e "$alvo" ]; then
        _err "não encontrei: $alvo"
        return 1
    fi

    local nome="${alvo##*/}" dir saida cmd=()
    dir="${alvo%/*}"
    [ "$dir" = "$alvo" ] && dir="."
    saida="$PWD/$nome.$fmt"
    if [ -e "$saida" ]; then
        _err "já existe $nome.$fmt aqui" "apague ou renomeie antes — não sobrescrevo"
        return 1
    fi

    case "$fmt" in
        tar.gz|tgz) cmd=(tar -czf "$saida" -C "$dir" "$nome") ;;
        tar.xz)     cmd=(tar -cJf "$saida" -C "$dir" "$nome") ;;
        tar.zst)    _precisa zstd || return 1; cmd=(tar --zstd -cf "$saida" -C "$dir" "$nome") ;;
        zip)        _precisa zip || return 1; cmd=(_zipar "$dir" "$nome" "$saida") ;;
        7z)         _precisa 7z || return 1; cmd=(7z a "$saida" "$alvo") ;;
        *)
            _err "formato '$fmt' não suportado" "use: tar.gz · zip · tar.xz · tar.zst · 7z"
            return 1
            ;;
    esac

    _rodar -q "compactando $nome" "${cmd[@]}" || return 1
    _feito "📦" "compactado" "$nome.$fmt · $(_humano "$(_tam_bytes "$saida")") (era $(_humano "$(_tam_bytes "$alvo")"))"
}
# o zip não tem -C: entra na pasta num subshell (o teu terminal não sai do lugar)
_zipar() { (builtin cd -- "$1" && zip -qr "$3" "$2"); }

# bak - cópia de segurança ao lado do original, com data e hora no nome
#   bak config.json  →  config.json.bak-2026-10-19_143005
bak() {
    if [ $# -eq 0 ]; then
        _uso "bak <arquivo|pasta> [...]" "cria uma cópia ao lado: nome.bak-<data_hora>"
        return 1
    fi
    local alvo carimbo erro=0
    carimbo=$(_data '%Y-%m-%d_%H%M%S')
    for alvo in "$@"; do
        alvo="${alvo%/}"
        if [ ! -e "$alvo" ]; then
            _err "não encontrei: $alvo"; erro=1; continue
        fi
        if command cp -a -- "$alvo" "$alvo.bak-$carimbo"; then
            _ok "cópia criada" "$alvo.bak-$carimbo"
        else
            _err "não consegui copiar $alvo" "confira o espaço e a permissão"; erro=1
        fi
    done
    return "$erro"
}

# lixo - manda pra lixeira em vez de apagar de vez (dá pra recuperar depois)
lixo() {
    if [ $# -eq 0 ]; then
        _uso "lixo <arquivo|pasta> [...]" "vai pra lixeira do sistema — o rm apaga sem volta"
        return 1
    fi
    local alvo n=0 erro=0
    for alvo in "$@"; do
        if [ ! -e "$alvo" ] && [ ! -L "$alvo" ]; then
            _err "não encontrei: $alvo"; erro=1; continue
        fi
        if _lixeira "${alvo%/}"; then n=$(( n + 1 )); else _err "não consegui mandar pra lixeira: $alvo"; erro=1; fi
    done
    (( n > 0 )) && _feito "🗑" "$(_plural "$n" "item foi pra lixeira" "itens foram pra lixeira")" "recupere pelo gerenciador de arquivos"
    return "$erro"
}

# _lixeira caminho - usa a lixeira do sistema (gio, trash-cli, macOS) ou,
# sem nenhuma, a do padrão freedesktop (~/.local/share/Trash) direto
_lixeira() {
    local abs
    abs="$(builtin cd -P -- "$(dirname -- "$1")" && pwd)/${1##*/}"
    if _tem gio && gio trash -- "$abs" 2> /dev/null; then return 0; fi
    if _tem trash-put && trash-put -- "$abs" 2> /dev/null; then return 0; fi
    if [ "$_SO" = macos ]; then
        # confere se saiu mesmo: sem sessão gráfica, o Finder "aceita" e não faz nada
        if _tem trash && command trash "$abs" 2> /dev/null && [ ! -e "$abs" ]; then return 0; fi
        osascript -e "tell application \"Finder\" to delete POSIX file \"${abs//\"/\\\"}\"" > /dev/null 2>&1 &&
            [ ! -e "$abs" ] && return 0
    fi
    local lixeira="${XDG_DATA_HOME:-$HOME/.local/share}/Trash" nome="${abs##*/}"
    mkdir -p "$lixeira/files" "$lixeira/info" || return 1
    while [ -e "$lixeira/files/$nome" ]; do nome="${abs##*/}.$RANDOM"; done
    printf '[Trash Info]\nPath=%s\nDeletionDate=%s\n' "$abs" "$(_data '%Y-%m-%dT%H:%M:%S')" \
        > "$lixeira/info/$nome.trashinfo" || return 1
    command mv -- "$abs" "$lixeira/files/$nome"
}

# espaco [pasta] - o que mais ocupa espaço aqui, com barrinha de tamanho
espaco() {
    local alvo="${1:-.}"
    if [ ! -d "$alvo" ]; then
        _err "pasta não encontrada: $alvo"
        return 1
    fi
    alvo=$(builtin cd -P -- "$alvo" && pwd)

    local itens=() item
    for item in "$alvo"/* "$alvo"/.[!.]*; do
        [ -e "$item" ] && itens+=("$item")
    done
    if [ ${#itens[@]} -eq 0 ]; then
        _ok "pasta vazia" "$(_curto "$alvo")"
        return 0
    fi

    _rodar -q "medindo $(_curto "$alvo")" du -sk -- "${itens[@]}"
    local linhas maior=0 kb nome n=0
    linhas=$(printf '%s\n' "$_RODAR_SAIDA" | sort -rn | head -n 15)
    read -r maior _ <<< "$linhas"

    _titulo "📊" "o que mais ocupa" "$(_curto "$alvo")"
    while IFS=$'\t' read -r kb nome; do
        [ -z "$kb" ] && continue
        n=$(( n + 1 ))
        printf "  ${C_TEXT}%7s${C_OFF}  %s  ${C_CMD}%s${C_OFF}\n" \
            "$(_humano $(( kb * 1024 )))" "$(_barra "$kb" "${maior:-1}" 16)" "${nome##*/}"
    done <<< "$linhas"
    (( ${#itens[@]} > 15 )) && _dica "mostrando os 15 maiores de ${#itens[@]}"
    _kv "disco" "$(_humano "$(_livre_bytes "$alvo")") livres"
}

# cpv - copia mostrando a barra de progresso (bom pra arquivo grande)
cpv() {
    if [ $# -lt 2 ]; then
        _uso "cpv <origem>... <destino>" "copia mostrando o progresso (usa rsync ou pv se tiver)"
        return 1
    fi
    if _tem rsync && rsync --version 2> /dev/null | grep -q 'version [3-9]'; then
        rsync -ah --info=progress2 -- "$@" || return 1
    elif _tem pv && [ $# -eq 2 ] && [ -f "$1" ]; then
        local destino="$2"
        [ -d "$destino" ] && destino="$destino/${1##*/}"
        pv -- "$1" > "$destino" || return 1
    else
        command cp -Riv -- "$@" || return 1
    fi
    local destino
    for destino; do :; done                  # o último argumento é o destino
    _ok "copiado" "→ $destino"
}

# ff - busca arquivo (sem argumento) ou trecho de código (com argumento)
ff() {
    local preview_cmd="cat {}"
    [ -n "$_BAT" ] && preview_cmd="$_BAT --color=always --style=numbers {}"

    if [ -z "$1" ]; then
        # Modo 1: buscar arquivo pelo nome (com fd fica mais rápido e respeita o .gitignore)
        _precisa fzf || return 1
        local arquivo
        if [ -n "$_FD" ]; then
            arquivo=$("$_FD" --type f --hidden --exclude .git --exclude node_modules 2> /dev/null \
                | fzf --height=60% --reverse --border=rounded --prompt='arquivo ❯ ' \
                      --preview "$preview_cmd" --preview-window=right:60%)
        else
            arquivo=$(find . -type f -not -path '*/node_modules/*' -not -path '*/.git/*' 2> /dev/null \
                | fzf --height=60% --reverse --border=rounded --prompt='arquivo ❯ ' \
                      --preview "$preview_cmd" --preview-window=right:60%)
        fi
        [ -n "$arquivo" ] && printf "  ${C_TEXT}%s${C_OFF}\n" "$arquivo"
        return 0
    fi

    # Modo 2: buscar trecho de código dentro dos arquivos
    _titulo "🔍" "procurando" "$1"
    printf "\n"
    if _tem rg; then
        rg --line-number --color=always -- "$1"
    else
        grep -rn --color=always --exclude-dir=node_modules --exclude-dir=.git -- "$1" . 2> /dev/null
    fi || { _aviso "nada encontrado pra '$1'"; return 1; }
}
