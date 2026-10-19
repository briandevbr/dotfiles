# shellcheck shell=bash
# ==========================================
# DOCKER — atalhos com lista pra escolher o container
# Sem nome, dlog/dsh/dstop/drm abrem a lista (com prévia dos logs).
# Sem docker instalado, cada comando explica como instalar.
# ==========================================

# _em_docker - guarda: docker instalado, rodando e com permissão?
_em_docker() {
    _precisa docker || return 1
    docker info > /dev/null 2>&1 && return 0
    if [ -S /var/run/docker.sock ] && [ ! -w /var/run/docker.sock ]; then
        _err "sem permissão pra falar com o docker" "sudo usermod -aG docker \$USER  (depois saia e entre na sessão)"
    elif [ "$_SO" = linux ]; then
        _err "o docker não está rodando" "ligue com: sudo systemctl start docker"
    else
        _err "o docker não está rodando" "abra o Docker Desktop e espere ele ficar verde"
    fi
}

# _escolher_container [-a] [-m] "prompt" - lista com busca e prévia dos logs
#   -a inclui os parados · -m deixa marcar vários (Tab)
_escolher_container() {
    local todos="" multi=""
    while [ $# -gt 1 ]; do
        case "$1" in -a) todos="-a" ;; -m) multi="--multi" ;; esac
        shift
    done
    if ! _tem fzf; then
        _err "diga o nome do container" "veja os nomes com: dpsa  ·  ou instale o fzf pra escolher numa lista"
        return 1
    fi
    local lista
    # shellcheck disable=SC2086  # $todos/$multi vazios têm que sumir
    lista=$(docker ps $todos --format '{{.Names}}\t{{.Image}}\t{{.Status}}' 2> /dev/null)
    if [ -z "$lista" ]; then
        _ok "nenhum container${todos:+ (nem parado)}" "suba um com: dcu (compose) ou docker run"
        return 1
    fi
    # shellcheck disable=SC2086
    printf '%s\n' "$lista" | fzf $multi --delimiter=$'\t' --prompt="$1" \
        --header='nome · imagem · estado' --preview 'docker logs --tail 40 {1} 2>&1' | cut -f1
}

# dps - containers rodando (nome, estado, portas, imagem)
dps() {
    _em_docker || return 1
    if [ -z "$(docker ps -q)" ]; then
        _ok "nenhum container rodando"
        _dica "todos, inclusive os parados: dpsa"
        return 0
    fi
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}' "$@"
}

# dpsa - todos os containers, até os parados
dpsa() { _em_docker && docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' "$@"; }

# dimg - imagens baixadas com o tamanho de cada
dimg() { _em_docker && docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}' "$@"; }

# dlog [container] - acompanha os logs ao vivo (Ctrl+C sai)
dlog() {
    _em_docker || return 1
    local c="${1:-}"
    [ $# -gt 0 ] && shift
    if [ -z "$c" ]; then
        c=$(_escolher_container -a "logs de ❯ ") || return 0
        [ -z "$c" ] && return 0
    fi
    _titulo "📜" "logs de $c" "últimas 100 linhas + ao vivo · Ctrl+C sai"
    docker logs -f --tail 100 "$@" "$c"
}

# dsh [container] - abre um terminal dentro do container (bash, ou sh se não tiver)
dsh() {
    _em_docker || return 1
    local c="${1:-}"
    if [ -z "$c" ]; then
        c=$(_escolher_container "entrar em ❯ ") || return 0
        [ -z "$c" ] && return 0
    fi
    _titulo "🐳" "dentro de $c" "exit volta"
    docker exec -it "$c" sh -c 'command -v bash > /dev/null && exec bash || exec sh'
}

# dstop [container...] - para containers (sem nome: escolhe vários na lista)
dstop() {
    _em_docker || return 1
    local alvos=() c
    if [ $# -gt 0 ]; then
        alvos=("$@")
    else
        while IFS= read -r c; do [ -n "$c" ] && alvos+=("$c"); done < <(_escolher_container -m "parar ❯ ")
    fi
    [ ${#alvos[@]} -eq 0 ] && return 0
    _rodar "parando $(_plural "${#alvos[@]}" container containers)" docker stop "${alvos[@]}"
}

# drm [container...] - apaga containers parados (pede confirmação)
drm() {
    _em_docker || return 1
    local alvos=() c
    if [ $# -gt 0 ]; then
        alvos=("$@")
    else
        while IFS= read -r c; do [ -n "$c" ] && alvos+=("$c"); done < <(_escolher_container -a -m "apagar ❯ ")
    fi
    [ ${#alvos[@]} -eq 0 ] && return 0
    _confirma "apagar ${alvos[*]}? (os dados dentro do container somem)" || { _cancelado; return 0; }
    _rodar "apagando $(_plural "${#alvos[@]}" container containers)" docker rm "${alvos[@]}"
}

# dclean [-a] - faxina do docker: containers parados, redes sem uso e imagens órfãs.
# -a também apaga imagens que nenhum container usa (vão ser baixadas de novo se precisar).
# Volumes (onde ficam os dados dos bancos) NUNCA entram aqui.
dclean() {
    _em_docker || return 1
    local tudo=""
    [ "$1" = "-a" ] && tudo="-a"
    _titulo "🐳" "faxina do docker" "${tudo:+inclui imagens sem uso · }volumes ficam intactos"
    docker system df 2> /dev/null | sed 's/^/     /'
    _confirma "limpar?" || { _cancelado; return 0; }
    # shellcheck disable=SC2086
    _rodar -q "limpando" docker system prune -f $tudo || return 1
    local liberado
    liberado=$(printf '%s\n' "$_RODAR_SAIDA" | sed -n 's/^Total reclaimed space: //p')
    _feito "✓" "docker limpo" "${liberado:-0B} liberados"
}

# dc - docker compose (acha sozinho se é 'docker compose' ou o antigo 'docker-compose')
dc() {
    if [ -z "${_DF_COMPOSE:-}" ]; then
        if _tem docker && docker compose version > /dev/null 2>&1; then
            _DF_COMPOSE="docker compose"
        elif _tem docker-compose; then
            _DF_COMPOSE="docker-compose"
        else
            _err "docker compose não encontrado" "instale o plugin: $(_cmd_instalar docker-compose-plugin)"
            return 1
        fi
    fi
    # shellcheck disable=SC2086  # "docker compose" são duas palavras de propósito
    $_DF_COMPOSE "$@"
}

# dcu - sobe os serviços do compose em segundo plano e mostra como ficaram
dcu() {
    dc up -d "$@" || { _err "o compose não subiu" "veja o motivo com: dcl"; return 1; }
    _ok "serviços no ar"
    dc ps
}
dcd()    { dc down "$@" && _ok "serviços derrubados"; }       # derruba (os volumes ficam)
dcl()    { dc logs -f --tail 100 "$@"; }                       # logs ao vivo de todos os serviços
dcr()    { dc restart "$@" && _ok "serviços reiniciados"; }    # reinicia

# dstats - quanto cada container está gastando de CPU, memória e rede (agora)
dstats() {
    _em_docker || return 1
    docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}' "$@"
}
