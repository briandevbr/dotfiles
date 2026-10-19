# shellcheck shell=bash
# ==========================================
# PROCESSOS, PORTAS E REDE
# Funciona igual no Linux (ss, ip) e no macOS (lsof, route): cada função
# usa a ferramenta que o sistema tiver.
# ==========================================

# ---------- portas ----------

# _quem_usa_porta porta → "pid<TAB>processo" se ocupada (pid vazio = processo de outro usuário)
# Retorna 1 se a porta está livre.
_quem_usa_porta() {
    local porta="$1" info pid="" proc="" re='pid=([0-9]+)'
    if _tem ss; then
        info=$(ss -lptnH "sport = :$porta" 2> /dev/null)
        [ -z "$info" ] && return 1
        [[ $info =~ $re ]] && pid="${BASH_REMATCH[1]}"
    elif _tem lsof; then
        pid=$(lsof -nP -iTCP:"$porta" -sTCP:LISTEN -t 2> /dev/null | head -n 1)
        [ -z "$pid" ] && return 1
    else
        return 1
    fi
    [ -n "$pid" ] && proc=$(ps -p "$pid" -o comm= 2> /dev/null)
    printf '%s\t%s' "$pid" "${proc##*/}"
}

# port - mostra quem está ocupando uma porta; com -k, mata o processo
port() {
    local matar=0 porta="$1"

    if [ "$1" = "-k" ]; then
        matar=1
        porta="$2"
    fi

    if [ -z "$porta" ]; then
        _uso "port <número>" "port -k <número>   encerra quem está usando"
        return 1
    fi

    local info pid processo
    if ! info=$(_quem_usa_porta "$porta"); then
        _ok "porta $porta livre"
        return 0
    fi
    IFS=$'\t' read -r pid processo <<< "$info"

    printf "  ${C_WARN}●${C_OFF}  ${C_TEXT}porta %s ocupada${C_OFF}   ${C_DIM}%s · pid %s${C_OFF}\n" \
        "$porta" "${processo:-processo de outro usuário}" "${pid:-?}"

    if [ "$matar" -eq 0 ]; then
        _dica "pra liberar: port -k $porta"
        return 0
    fi

    if [ -n "$pid" ] && kill "$pid" 2> /dev/null; then
        _ok "processo encerrado" "porta $porta liberada"
    else
        _err "não consegui encerrar" "processo de outro usuário? tente: sudo kill \$(sudo lsof -t -i:$porta)"
        return 1
    fi
}

# portas - todas as portas TCP abertas na máquina (quem está escutando em cada uma)
portas() {
    local linhas="" porta end proc pid
    if _tem ss; then
        local _a _b _c local_ _peer procs re='"([^"]+)",pid=([0-9]+)'
        while read -r _a _b _c local_ _peer procs; do
            porta="${local_##*:}"; end="${local_%:*}"
            proc=""; pid=""
            [[ $procs =~ $re ]] && { proc="${BASH_REMATCH[1]}"; pid="${BASH_REMATCH[2]}"; }
            linhas+="$porta"$'\t'"$end"$'\t'"${proc:--}"$'\t'"${pid:--}"$'\n'
        done < <(ss -tlnpH 2> /dev/null)
    elif _tem lsof; then
        local cmd _u _fd _t _d _s _n nome
        while read -r cmd pid _u _fd _t _d _s _n nome _; do
            porta="${nome##*:}"; end="${nome%:*}"
            linhas+="$porta"$'\t'"$end"$'\t'"$cmd"$'\t'"$pid"$'\n'
        done < <(lsof -nP -iTCP -sTCP:LISTEN 2> /dev/null | sed 1d)
    else
        _precisa ss
        return 1
    fi
    if [ -z "$linhas" ]; then
        _ok "nenhuma porta TCP aberta"
        return 0
    fi
    printf "\n  ${C_DIM}%-7s %-18s %-18s %s${C_OFF}\n" "PORTA" "ENDEREÇO" "PROCESSO" "PID"
    while IFS=$'\t' read -r porta end proc pid; do
        [ -z "$porta" ] && continue
        printf "  ${C_CMD}%-7s${C_OFF} ${C_DIM}%-18s${C_OFF} ${C_TEXT}%-18s${C_OFF} ${C_DIM}%s${C_OFF}\n" "$porta" "$end" "$proc" "$pid"
    done < <(printf '%s' "$linhas" | sort -t$'\t' -k1,1n -u)
    _dica "processo '-' é de outro usuário (root): sudo ss -tlnp mostra todos"
    printf "\n"
}

# serve - sobe servidor HTTP na pasta atual (sem instalar nada)
serve() {
    local porta="${1:-8000}"

    if ! [[ "$porta" =~ ^[0-9]+$ ]]; then
        _uso "serve [porta]" "padrão: 8000"
        return 1
    fi
    _precisa python3 || return 1
    if _quem_usa_porta "$porta" > /dev/null; then
        _err "porta $porta ocupada" "veja quem é com: port $porta  ·  ou use outra: serve 8080"
        return 1
    fi

    _titulo "🌐" "servindo" "$(_curto)"
    printf "     ${C_OK}http://localhost:%s${C_OFF}\n" "$porta"
    printf "     ${C_DIM}Ctrl+C pra parar${C_OFF}\n\n"

    python3 -m http.server "$porta" --bind 127.0.0.1
}

# _porta_aberta host porta - alguém aceita conexão ali? (nc, ou o /dev/tcp do bash)
# Sempre com tempo-limite: o nc de cada sistema trata o -w de um jeito, e uma
# conexão que não responde nunca pode travar quem chamou.
_porta_aberta() {
    if _tem nc; then
        _com_limite 3 nc -z -w 1 "$1" "$2" < /dev/null > /dev/null 2>&1
    else
        _com_limite 3 bash -c 'exec 3<> "/dev/tcp/$0/$1"' "$1" "$2" < /dev/null 2> /dev/null
    fi
}

# _esperar_porta host porta limite - tenta a cada meio segundo até abrir (ou estourar o limite)
_esperar_porta() {
    local fim=$(( SECONDS + $3 ))
    until _porta_aberta "$1" "$2"; do
        (( SECONDS >= fim )) && return 1
        sleep 0.5
    done
}

# waitport [host:]porta [segundos] - espera um serviço subir (banco no docker, API…)
#   waitport 5432 && npm run migrate
waitport() {
    local alvo="$1" limite="${2:-60}" host porta
    if [ -z "$alvo" ]; then
        _uso "waitport [host:]porta [segundos]" "espera a porta aceitar conexão (padrão: localhost, 60s)" \
            "ex.: waitport 5432 && npm run migrate"
        return 1
    fi
    case "$alvo" in
        *:*) host="${alvo%:*}"; porta="${alvo##*:}" ;;
        *)   host="localhost"; porta="$alvo" ;;
    esac
    if ! [[ "$porta" =~ ^[0-9]+$ ]]; then
        _err "porta inválida: $porta"
        return 1
    fi
    _rodar "esperando $host:$porta" _esperar_porta "$host" "$porta" "$limite" && return 0
    _dica "passou de ${limite}s e ninguém respondeu — o serviço subiu mesmo? (dps, dcl)"
    return 1
}

# ---------- rede ----------

# _ip_local → "interface ip" da saída pra internet
_ip_local() {
    local dev="" ip="" linha re_dev='dev ([^ ]+)' re_src='src ([0-9.]+)'
    if _tem ip; then
        linha=$(ip -4 route get 1.1.1.1 2> /dev/null)
        [[ $linha =~ $re_dev ]] && dev="${BASH_REMATCH[1]}"
        [[ $linha =~ $re_src ]] && ip="${BASH_REMATCH[1]}"
    elif [ "$_SO" = macos ]; then
        dev=$(route -n get default 2> /dev/null | sed -n 's/.*interface: //p')
        [ -n "$dev" ] && ip=$(ipconfig getifaddr "$dev" 2> /dev/null)
    fi
    [ -n "$ip" ] && printf '%s %s' "${dev:-?}" "$ip"
}

# _gateway → IP do roteador
_gateway() {
    if _tem ip; then
        ip -4 route show default 2> /dev/null | sed -n 's/.*via \([0-9.]*\).*/\1/p' | head -n 1
    elif [ "$_SO" = macos ]; then
        route -n get default 2> /dev/null | sed -n 's/.*gateway: //p'
    fi
}

# _ping_ms host [n] → "media_ms perda%" (ping do Linux usa -W em segundos, o do macOS em ms)
_ping_ms() {
    local saida espera=1 re_avg='= [0-9.]+/([0-9.]+)/' re_perda='([0-9.]+)% packet loss'
    [ "$_SO" = macos ] && espera=1000
    saida=$(LC_ALL=C ping -c "${2:-1}" -W "$espera" "$1" 2> /dev/null) || true
    local media="" perda=100
    [[ $saida =~ $re_avg ]] && media="${BASH_REMATCH[1]%.*}"
    [[ $saida =~ $re_perda ]] && perda="${BASH_REMATCH[1]%.*}"
    [ -n "$media" ] && printf '%s %s' "$media" "$perda"
}

# _resolve nome → IP (DNS)
_resolve() {
    if _tem getent; then
        getent ahostsv4 "$1" 2> /dev/null | awk 'NR==1 {print $1}'
    elif [ "$_SO" = macos ]; then
        dscacheutil -q host -a name "$1" 2> /dev/null | awk '/ip_address/ {print $2; exit}'
    elif _tem host; then
        host -t A "$1" 2> /dev/null | awk '/has address/ {print $4; exit}'
    fi
}

# meuip - teu IP na rede local e o IP público (o que a internet vê)
meuip() {
    local loc pub
    loc=$(_ip_local)
    _kv "local" "${loc#* }${loc:+  (${loc%% *})}"
    if _tem curl && _rodar -q "consultando o IP público" curl -fsS -m 5 https://api.ipify.org; then
        pub="$_RODAR_SAIDA"
        _kv "público" "$pub"
    else
        _kv "público" "sem resposta (tá sem internet?)"
    fi
}

# rede - diagnóstico da conexão, passo a passo, e diz onde está o problema
rede() {
    local loc gw r ms dns_ip t0 http ok_gw=0 ok_dns=0 ok_http=0 ok_ping=0
    _titulo "🌐" "diagnóstico de rede"

    # 1) interface e IP local
    loc=$(_ip_local)
    if [ -n "$loc" ]; then
        _feito "✓" "interface" "${loc%% *} · ${loc#* }"
    else
        _err "interface" "sem IP: o Wi-Fi/cabo está conectado?"
    fi

    # 2) roteador (alguns bloqueiam ping: aí é só aviso)
    gw=$(_gateway)
    if [ -n "$gw" ]; then
        _pendente "roteador $gw…"
        r=$(_ping_ms "$gw")
        if [ -n "$r" ]; then
            ok_gw=1; _feito "✓" "roteador" "$gw · ${r%% *}ms"
        else
            _aviso "roteador" "$gw não respondeu ao ping (alguns roteadores bloqueiam)"
        fi
    else
        _aviso "roteador" "não achei a rota padrão"
    fi

    # 3) DNS (o "catálogo" que traduz github.com em IP)
    _us t0
    _pendente "DNS…"
    dns_ip=$(_resolve github.com)
    if [ -n "$dns_ip" ]; then
        ok_dns=1; _feito "✓" "DNS" "github.com → $dns_ip · $(_tempo_desde "$t0")"
    else
        _err "DNS" "não consegui traduzir github.com em IP"
    fi

    # 4) internet de verdade: uma requisição HTTPS
    if _tem curl; then
        _us t0
        _pendente "internet (HTTPS)…"
        http=$(curl -sS -o /dev/null -m 6 -w '%{http_code}' https://www.google.com/generate_204 2> /dev/null)
        if [[ "$http" =~ ^[23] ]]; then
            ok_http=1; _feito "✓" "internet" "HTTPS ok · $(_tempo_desde "$t0")"
        else
            _err "internet" "HTTPS não passou (código ${http:-sem resposta})"
        fi
    fi

    # 5) latência até um servidor rápido (Cloudflare)
    _pendente "latência…"
    r=$(_ping_ms 1.1.1.1 4)
    if [ -n "$r" ]; then
        ok_ping=1; ms="${r%% *}"
        if (( ms > 150 )); then
            _aviso "latência" "1.1.1.1 · média ${ms}ms · ${r#* }% perda — lenta pra chamada de vídeo e jogo"
        else
            _feito "✓" "latência" "1.1.1.1 · média ${ms}ms · ${r#* }% perda"
        fi
    else
        _aviso "latência" "ping bloqueado ou sem resposta"
    fi

    # Veredito: junta as pistas num diagnóstico só
    printf "\n"
    if (( ok_http )); then
        _ok "conexão funcionando"
    elif (( ok_ping && ! ok_dns )); then
        _err "o DNS está com problema (a internet chega, os nomes não)" "teste outro DNS: 1.1.1.1 ou 8.8.8.8 nas configurações de rede"
    elif (( ok_dns && ! ok_http )); then
        _err "o DNS responde mas o HTTPS não passa" "proxy, firewall ou portal de login do Wi-Fi? abra um site no navegador"
    elif (( ! ok_gw )) && [ -z "$loc" ]; then
        _err "sem conexão com a rede local" "confira o Wi-Fi ou o cabo"
    else
        _err "sem internet" "reinicie o roteador; se continuar, é com o provedor"
    fi
}

# _ms "0.123456" → 123  (o curl dá segundos com 6 casas)
_ms() {
    local s="${1%[.,]*}" f="${1#*[.,]}000"
    printf '%d' $(( 10#${s:-0} * 1000 + 10#${f:0:3} ))
}

# httpcheck url - testa uma URL/API: código, tempo de cada etapa e tamanho
httpcheck() {
    if [ -z "$1" ]; then
        _uso "httpcheck <url>" "código HTTP + quanto levou cada etapa (DNS, conexão, TLS, resposta)"
        return 1
    fi
    _precisa curl || return 1
    local url="$1" saida codigo dns con tls ttfb total tam ip cor
    [[ "$url" != *://* ]] && url="https://$url"
    _rodar -q "testando $url" curl -sS -o /dev/null -m 20 \
        -w '%{http_code}|%{time_namelookup}|%{time_connect}|%{time_appconnect}|%{time_starttransfer}|%{time_total}|%{size_download}|%{remote_ip}' \
        "$url" || return 1
    saida="$_RODAR_SAIDA"
    IFS='|' read -r codigo dns con tls ttfb total tam ip <<< "$saida"
    case "$codigo" in
        2*) cor="$C_OK" ;;
        3*) cor="$C_ACCENT" ;;
        4*) cor="$C_WARN" ;;
        *)  cor="$C_ERR" ;;
    esac
    printf "  ${cor}●${C_OFF}  ${C_TEXT}HTTP %s${C_OFF}   ${C_DIM}%s · %s${C_OFF}\n" "$codigo" "$url" "${ip:-?}"
    _kv "DNS" "$(_ms "$dns")ms"
    _kv "conexão" "$(_ms "$con")ms"
    [ "$(_ms "$tls")" -gt 0 ] && _kv "TLS" "$(_ms "$tls")ms"
    _kv "resposta" "$(_ms "$ttfb")ms  (até o 1º byte)"
    _kv "total" "$(_ms "$total")ms · $(_humano "${tam%.*}")"
}

# ---------- processos ----------

# psg termo - procura processos pelo nome (ou qualquer parte do comando)
psg() {
    if [ -z "$1" ]; then
        _uso "psg <termo>" "acha processos: psg node · psg 3000"
        return 1
    fi
    local linhas cab n
    linhas=$(ps -Ao pid,user,%cpu,%mem,etime,args 2> /dev/null | sed 1d | grep -i -- "$1" | grep -v -e 'grep -i' -e ' psg ')
    if [ -z "$linhas" ]; then
        _ok "nenhum processo com '$1'"
        return 1
    fi
    n=$(( $(printf '%s\n' "$linhas" | wc -l) ))
    cab=$(ps -Ao pid,user,%cpu,%mem,etime,args 2> /dev/null | head -n 1)
    printf "  ${C_DIM}%s${C_OFF}\n" "$cab"
    printf '%s\n' "$linhas" | grep -i --color=always -- "$1" | sed 's/^/  /'
    _dica "$(_plural "$n" processo processos) · pra encerrar: pk $1"
}

# pk [termo] - escolhe processos numa lista e encerra (Tab marca vários).
# Pede com educação primeiro (TERM); quem não sair em 2s pode ser forçado (KILL).
pk() {
    _precisa fzf || return 1
    local sel pids=() pid vivos=()
    sel=$(ps -Ao pid,user,%cpu,%mem,etime,args 2> /dev/null | sed 1d \
        | fzf --multi --query="${1:-}" --prompt='encerrar ❯ ' \
              --header='Tab marca vários · Enter encerra · Esc cancela' \
              --preview 'ps -o pid,ppid,user,%cpu,%mem,rss,etime,args -p {1} 2> /dev/null')
    [ -z "$sel" ] && return 0
    while read -r pid _; do [ -n "$pid" ] && pids+=("$pid"); done <<< "$sel"

    _confirma "encerrar $(_plural "${#pids[@]}" processo processos) (${pids[*]})?" || { _cancelado; return 0; }
    kill "${pids[@]}" 2> /dev/null
    sleep 2
    for pid in "${pids[@]}"; do kill -0 "$pid" 2> /dev/null && vivos+=("$pid"); done
    if [ ${#vivos[@]} -eq 0 ]; then
        _ok "$(_plural "${#pids[@]}" "processo encerrado" "processos encerrados")"
        return 0
    fi
    _aviso "${vivos[*]} ainda rodando" "não quiseram sair com educação"
    if _confirma "forçar (kill -9)? o programa não salva nada"; then
        kill -9 "${vivos[@]}" 2> /dev/null && _ok "forçado" || _err "não consegui" "é de outro usuário? sudo kill -9 ${vivos[*]}"
    else
        _cancelado
    fi
}

# _top_ps cpu|mem n - os n processos que mais gastam (o --sort é só do GNU; o macOS usa -r/-m)
_top_ps() {
    local campo="$1" n="$2" linhas
    if [ "$_SO" = macos ]; then
        local flag="-r"; [ "$campo" = mem ] && flag="-m"
        linhas=$(ps -Ao pid,%cpu,%mem,rss,comm "$flag" 2> /dev/null | sed 1d | head -n "$n")
    else
        linhas=$(ps -eo pid,%cpu,%mem,rss,comm --sort=-%"$campo" 2> /dev/null | sed 1d | head -n "$n")
    fi
    local pid cpu mem rss nome valor maior=""
    printf "\n  ${C_DIM}%-8s %6s %6s %8s  %-16s %s${C_OFF}\n" "PID" "%CPU" "%MEM" "MEMÓRIA" "" "PROCESSO"
    while read -r pid cpu mem rss nome; do
        [ -z "$pid" ] && continue
        if [ "$campo" = cpu ]; then valor="${cpu%.*}"; else valor="${mem%.*}"; fi
        [ -z "$maior" ] && maior="${valor:-1}"
        (( maior < 1 )) && maior=1
        printf "  ${C_DIM}%-8s${C_OFF} ${C_TEXT}%6s %6s %8s${C_OFF}  %s ${C_CMD}%s${C_OFF}\n" \
            "$pid" "$cpu" "$mem" "$(_humano $(( rss * 1024 )))" "$(_barra "${valor:-0}" "$maior" 16)" "${nome##*/}"
    done <<< "$linhas"
    printf "\n"
}

# topcpu [n] / topmem [n] - os que mais gastam CPU / memória agora (padrão: 10)
topcpu() { _top_ps cpu "${1:-10}"; }
topmem() { _top_ps mem "${1:-10}"; }

# mon - monitor do sistema ao vivo (o melhor que tiver: btop, htop ou top)
mon() {
    if _tem btop; then btop
    elif _tem htop; then htop
    else
        _dica "pra um monitor mais bonito: $(_cmd_instalar btop)"
        top
    fi
}
