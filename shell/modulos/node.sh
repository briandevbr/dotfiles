# shellcheck shell=bash
# ==========================================
# NODE / NPM — atalhos de desenvolvimento
# Só rodam dentro de um projeto (pasta com package.json ou qualquer
# subpasta dele). Fora de um, o npm criaria package.json e node_modules
# no lugar errado — tipo direto na sua home.
# A saída do próprio npm já é o feedback.
#
# Projeto com pnpm-lock.yaml, yarn.lock ou bun.lockb? Os mesmos atalhos
# usam o gerenciador certo (se ele estiver instalado) — misturar dá
# dois arquivos de lock brigando no mesmo projeto.
# ==========================================

# _raiz_node - sobe as pastas até achar um package.json
_raiz_node() {
    local d="$PWD"
    while :; do
        if [ -f "$d/package.json" ]; then
            printf '%s' "${d:-/}"
            return 0
        fi
        if [ -z "$d" ] || [ "$d" = "/" ]; then return 1; fi
        d="${d%/*}"
    done
}

# _em_projeto_node - guarda usada por todos os atalhos npm
_em_projeto_node() {
    _raiz_node > /dev/null && return 0
    _err "aqui não é um projeto node (não achei package.json)" "entre na pasta do projeto — ou crie um aqui com: npkg"
}

# _pm - qual gerenciador usar neste projeto: npm (padrão), pnpm, yarn ou bun
_pm() {
    local raiz
    raiz=$(_raiz_node) || { printf 'npm'; return 0; }
    if   [ -f "$raiz/pnpm-lock.yaml" ] && _tem pnpm; then printf 'pnpm'
    elif [ -f "$raiz/yarn.lock" ]      && _tem yarn; then printf 'yarn'
    elif { [ -f "$raiz/bun.lockb" ] || [ -f "$raiz/bun.lock" ]; } && _tem bun; then printf 'bun'
    else printf 'npm'
    fi
}

# ni - sem nada: instala tudo do package.json · ni pacote: instala e salva nas dependências
ni() {
    _em_projeto_node || return 1
    local pm; pm=$(_pm)
    if [ $# -eq 0 ] || [ "$pm" = npm ]; then
        "$pm" install "$@"
    else
        "$pm" add "$@"                       # pnpm/yarn/bun usam 'add' pra pacote novo
    fi
}

nr()  { _em_projeto_node && "$(_pm)" run "$@"; }     # sozinho lista os scripts · nr nome: roda um
nrd() { _em_projeto_node && "$(_pm)" run dev "$@"; } # npm run dev
nrb() { _em_projeto_node && "$(_pm)" run build "$@"; } # npm run build
ns()  { _em_projeto_node && "$(_pm)" start "$@"; }   # npm start
nt()  { _em_projeto_node && "$(_pm)" test "$@"; }    # npm test

# nid - instala um pacote só pra desenvolvimento (-D)
nid() {
    if [ $# -eq 0 ]; then
        _uso "nid <pacote>" "instala como dependência de desenvolvimento (ex: nid eslint)"
        return 1
    fi
    _em_projeto_node || return 1
    local pm; pm=$(_pm)
    if [ "$pm" = npm ]; then npm install --save-dev "$@"; else "$pm" add -D "$@"; fi
}

# nfresh - apaga o node_modules e instala tudo de novo (resolve 90% dos "na minha máquina funcionava")
nfresh() {
    _em_projeto_node || return 1
    local raiz pm
    raiz=$(_raiz_node); pm=$(_pm)
    if [ -d "$raiz/node_modules" ]; then
        _rodar "apagando node_modules ($(_humano "$(_tam_bytes "$raiz/node_modules")"))" \
            command rm -rf -- "$raiz/node_modules" || return 1
    fi
    _rodar "instalando tudo de novo com $pm" _no_pasta "$raiz" "$pm" install
}
# _no_pasta pasta comando... - roda o comando dentro da pasta (num subshell)
_no_pasta() { (builtin cd -- "$1" && shift && "$@"); }

# nout - o que está desatualizado no projeto
nout() { _em_projeto_node && "$(_pm)" outdated "$@"; }

# _nome_npm "Minha Pizzaria" → "minha-pizzaria"
# Regras do npm: minúsculas, sem espaço/acento, não começa com . ou _, até 214 letras
_nome_npm() {
    local n
    n=$(printf '%s' "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT 2> /dev/null)
    n=$(printf '%s' "$n" | tr '[:upper:]' '[:lower:]')   # tudo minúsculo
    n="${n//[[:space:]]/-}"                              # espaço vira hífen
    n=$(printf '%s' "$n" | sed 's/[^a-z0-9._~-]//g; s/^[._-]*//; s/--*/-/g; s/-$//')
    n="${n:0:214}"
    printf '%s' "${n:-meu-projeto}"
}

# _json_txt "texto" → texto com \ e " escapados pra caber numa string JSON
_json_txt() { local t="${1//\\/\\\\}"; printf '%s' "${t//\"/\\\"}"; }

# npkg - cria um package.json base na pasta atual (nunca sobrescreve)
#   npkg           → o nome do projeto vem do nome da pasta
#   npkg meu-app   → usa o nome que você passar
npkg() {
    if [ -e package.json ]; then
        _err "já existe um package.json aqui" "não sobrescrevo — edite ele ou apague antes"
        return 1
    fi
    if [ "$PWD" = "$HOME" ]; then
        _err "você está na home, não numa pasta de projeto" "entre nela antes: p · proj · mkcd nome"
        return 1
    fi

    local raiz
    if raiz=$(_raiz_node); then
        _aviso "esta pasta já fica dentro de outro projeto node" "$(_curto "$raiz")/package.json"
        _confirma "criar outro package.json aqui mesmo assim?" || { _cancelado; return 0; }
    fi

    local nome autor
    nome=$(_nome_npm "${1:-${PWD##*/}}")
    autor=$(git config user.name 2> /dev/null)

    # printf em vez de cat: o 'cat' deste arquivo é o bat
    if ! printf '%s\n' \
        '{' \
        "  \"name\": \"$(_json_txt "$nome")\"," \
        '  "version": "1.0.0",' \
        '  "description": "",' \
        '  "type": "module",' \
        '  "main": "index.js",' \
        '  "scripts": {' \
        '    "start": "node index.js",' \
        '    "dev": "node --watch index.js",' \
        '    "test": "node --test"' \
        '  },' \
        '  "keywords": [],' \
        "  \"author\": \"$(_json_txt "${autor:-David Brian}")\"," \
        '  "license": "MIT"' \
        '}' > package.json
    then
        _err "não consegui criar o package.json" "confira se você tem permissão nesta pasta"
        return 1
    fi

    _ok "package.json criado" "$nome"
    _kv "tipo" "módulos com import/export  (\"type\": \"module\")"
    _kv "scripts" "ns → node index.js · nrd → recarrega sozinho · nt → testes"
    [ -f index.js ] || _dica "falta o index.js: touch index.js  — depois é só nrd"
}
