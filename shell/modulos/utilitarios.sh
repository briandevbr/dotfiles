# shellcheck shell=bash
# ==========================================
# UTILITÁRIOS DE DEV — coisas pequenas que você faria no Google
# (gerar uuid, formatar json, copiar pro clipboard…) sem sair do terminal.
# ==========================================

# clip - copia pra área de transferência
#   pwd | clip  ·  clip arquivo.txt  ·  clip "texto"
clip() {
    local entrada
    if [ $# -gt 0 ] && [ -f "$1" ]; then
        entrada=$(< "$1")
    elif [ $# -gt 0 ]; then
        entrada="$*"
    elif [ ! -t 0 ]; then
        entrada=$(< /dev/stdin)
    else
        _uso "clip [arquivo|texto]" "pwd | clip   copia a saída de um comando"
        return 1
    fi
    if ! printf '%s' "$entrada" | _clip_copiar; then
        _err "não achei como copiar neste sistema" "$(_cmd_instalar wl-copy)  (Wayland) ou xclip (X11)"
        return 1
    fi
    _ok "copiado" "$(_plural "${#entrada}" caractere caracteres)"
}

# _clip_copiar - lê da entrada e manda pro clipboard do sistema que existir
_clip_copiar() {
    if [ "$_SO" = macos ]; then pbcopy
    elif [ "$_SO" = wsl ] && _tem clip.exe; then iconv -f UTF-8 -t UTF-16LE | clip.exe
    elif [ -n "${WAYLAND_DISPLAY:-}" ] && _tem wl-copy; then wl-copy
    elif _tem xclip; then xclip -selection clipboard
    elif _tem xsel; then xsel --clipboard --input
    else return 1
    fi
}

# colar - imprime o que está na área de transferência (colar | grep x)
colar() {
    if [ "$_SO" = macos ]; then pbpaste
    elif [ "$_SO" = wsl ] && _tem powershell.exe; then powershell.exe -NoProfile -Command Get-Clipboard | tr -d '\r'
    elif [ -n "${WAYLAND_DISPLAY:-}" ] && _tem wl-paste; then wl-paste
    elif _tem xclip; then xclip -selection clipboard -o
    elif _tem xsel; then xsel --clipboard --output
    else _err "não achei como colar neste sistema" "$(_cmd_instalar wl-copy)  (Wayland) ou xclip (X11)"
    fi
}

# json - formata JSON bonito e colorido: json arquivo.json · curl url | json
json() {
    if [ $# -eq 0 ] && [ -t 0 ]; then
        _uso "json <arquivo>" "curl -s url | json   formata a resposta de uma API"
        return 1
    fi
    if _tem jq; then
        jq . "$@" || { _err "JSON inválido"; return 1; }
    elif _tem python3; then
        python3 -m json.tool "$@" || { _err "JSON inválido"; return 1; }
    else
        _precisa jq
    fi
}

# uuid - gera um UUID v4 (e copia pro clipboard se der)
uuid() {
    local u
    if [ -r /proc/sys/kernel/random/uuid ]; then
        read -r u < /proc/sys/kernel/random/uuid
    elif _tem uuidgen; then
        u=$(uuidgen | tr '[:upper:]' '[:lower:]')
    else
        u=$(python3 -c 'import uuid; print(uuid.uuid4())' 2> /dev/null) || { _precisa uuidgen; return 1; }
    fi
    printf '%s\n' "$u"
    [ -t 1 ] && printf '%s' "$u" | _clip_copiar 2> /dev/null && _dica "copiado pro clipboard"
    return 0
}

# senha [tamanho] - gera uma senha forte aleatória (padrão: 20 caracteres)
senha() {
    local n="${1:-20}" s
    if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 8 ]; then
        _uso "senha [tamanho]" "gera uma senha aleatória (mínimo 8, padrão 20)"
        return 1
    fi
    # lê o /dev/urandom em blocos de 512 bytes: um 'tr < /dev/urandom | head' sem fim
    # trava pra sempre num processo que herdou o SIGPIPE ignorado (o tr do macOS não para)
    s=""
    while [ "${#s}" -lt "$n" ]; do
        s+=$(head -c 512 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9!@#%^*_+=-')
    done
    s="${s:0:$n}"
    printf '%s\n' "$s"
    [ -t 1 ] && printf '%s' "$s" | _clip_copiar 2> /dev/null && _dica "copiada pro clipboard — cola onde precisar"
    return 0
}

# b64 / b64d - codifica e decodifica base64 (texto ou o que vier do pipe)
b64()  { if [ $# -gt 0 ]; then printf '%s' "$*" | base64; else base64; fi; }
b64d() { if [ $# -gt 0 ]; then printf '%s' "$*" | base64 --decode; else base64 --decode; fi; echo; }

# epoch [timestamp] - sem argumento: o timestamp de agora. Com: vira data legível
#   epoch            → 1792377661
#   epoch 1700000000 → 14/11/2023 19:13:20
epoch() {
    if [ $# -eq 0 ]; then
        printf '%s\n' "${EPOCHSECONDS:-$(date +%s)}"
        return 0
    fi
    local ts="$1"
    if ! [[ "$ts" =~ ^[0-9]+$ ]]; then
        _uso "epoch [timestamp]" "converte segundos desde 1970 em data (milissegundos também valem)"
        return 1
    fi
    (( ${#ts} > 11 )) && ts=$(( ts / 1000 ))     # timestamp em milissegundos (JavaScript)
    printf '%s\n' "$(_data '%d/%m/%Y %H:%M:%S' "$ts")"
}

# calc "expressão" - calculadora rápida: calc 1500*1.07 · calc "2^10" · calc 10/3
calc() {
    if [ $# -eq 0 ]; then
        _uso "calc <expressão>" "ex.: calc 1500*1.07   ·   calc \"(3+4)^2\"   ·   calc 10/3"
        return 1
    fi
    local expr="$*" permitido='^[0-9.+*/%^() -]+$'
    expr="${expr//,/.}"                          # 1,5 vira 1.5
    if ! [[ "$expr" =~ $permitido ]]; then
        _err "só números e + - * / % ^ ( )" "ex.: calc 1500*1.07"
        return 1
    fi
    awk "BEGIN { r = $expr; if (r == int(r)) printf \"%d\\n\", r; else printf \"%.6g\\n\", r }"
}

# loadenv [arquivo] - carrega as variáveis de um .env no terminal atual.
# Lê linha por linha (CHAVE=valor): não executa nada que esteja no arquivo.
loadenv() {
    local arq="${1:-.env}" linha chave valor n=0
    local formato='^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$'
    if [ ! -f "$arq" ]; then
        _err "não achei $arq" "uso: loadenv [arquivo]  (padrão: .env da pasta atual)"
        return 1
    fi
    while IFS= read -r linha || [ -n "$linha" ]; do
        linha="${linha%$'\r'}"
        [[ "$linha" =~ $formato ]] || continue
        chave="${BASH_REMATCH[2]}"
        valor="${BASH_REMATCH[3]}"
        if [[ "$valor" == \"*\" ]] || [[ "$valor" == \'*\' ]]; then
            valor="${valor:1:${#valor}-2}"           # tira as aspas de fora
        fi
        export "$chave=$valor"
        n=$(( n + 1 ))
    done < "$arq"
    _ok "$(_plural "$n" variável variáveis) carregadas" "$arq"
}

# venv - ambiente virtual do Python: cria (se não existir) e ativa o .venv da pasta
venv() {
    if [ -n "${VIRTUAL_ENV:-}" ] && [ "${1:-}" != "-f" ]; then
        deactivate 2> /dev/null
        _ok "venv desativado" "$(_curto "$VIRTUAL_ENV")"
        return 0
    fi
    _precisa python3 || return 1
    if [ ! -d .venv ]; then
        _rodar "criando .venv" python3 -m venv .venv || return 1
    fi
    # shellcheck source=/dev/null
    . .venv/bin/activate || return 1
    _ok "venv ativo" "$(python3 --version 2>&1) · rode venv de novo pra desativar"
}

# mkscript nome.sh - cria um script bash já executável, com o cabeçalho seguro
mkscript() {
    if [ -z "$1" ]; then
        _uso "mkscript <nome.sh>" "cria o arquivo com #!/usr/bin/env bash, set -euo pipefail e chmod +x"
        return 1
    fi
    if [ -e "$1" ]; then
        _err "já existe $1" "não sobrescrevo"
        return 1
    fi
    printf '%s\n' '#!/usr/bin/env bash' '# '"${1##*/}"' — ' 'set -euo pipefail' '' 'main() {' '    echo "ok"' '}' '' 'main "$@"' > "$1" &&
        chmod +x "$1" || { _err "não consegui criar $1"; return 1; }
    _ok "script criado" "$1 · rode com: ./$1"
}

# cheat comando - cola rápida de um comando (cheat.sh): cheat tar · cheat git-rebase
cheat() {
    if [ -z "$1" ]; then
        _uso "cheat <comando>" "exemplos prontos de uso, direto da internet (cheat.sh)"
        return 1
    fi
    _precisa curl || return 1
    curl -fsS -m 10 "https://cheat.sh/$1?style=monokai" || _err "não consegui buscar" "tá sem internet?"
}
