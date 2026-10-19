# shellcheck shell=bash
# ==========================================
# PAINÉIS — status, dev, help e dotfiles
# ==========================================

# _memoria → "3.1G de 15.5G em uso"  (Linux lê o /proc direto; macOS pergunta pro sistema)
_memoria() {
    local total=0 livre=0 chave valor _
    if [ -r /proc/meminfo ]; then
        while read -r chave valor _; do
            case "$chave" in
                MemTotal:)     total=$(( valor * 1024 )) ;;
                MemAvailable:) livre=$(( valor * 1024 )); break ;;
            esac
        done < /proc/meminfo
    elif [ "$_SO" = macos ]; then
        local pagina livres inativas
        total=$(sysctl -n hw.memsize 2> /dev/null)
        pagina=$(sysctl -n hw.pagesize 2> /dev/null)
        livres=$(vm_stat 2> /dev/null | awk '/Pages free/ {gsub(/\./,"",$3); print $3}')
        inativas=$(vm_stat 2> /dev/null | awk '/Pages inactive/ {gsub(/\./,"",$3); print $3}')
        livre=$(( (${livres:-0} + ${inativas:-0}) * ${pagina:-4096} ))
    fi
    (( total > 0 )) || return 1
    printf '%s de %s em uso' "$(_humano $(( total - livre )))" "$(_humano "$total")"
}

# _bateria → "carga estado" (estado: Charging/Discharging/Full) ou nada se não tiver bateria
_bateria() {
    local b carga estado
    for b in /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1; do
        if [ -r "$b/capacity" ]; then
            read -r carga < "$b/capacity"
            read -r estado < "$b/status" 2> /dev/null
            printf '%s %s' "$carga" "${estado:-Unknown}"
            return 0
        fi
    done
    if [ "$_SO" = macos ] && _tem pmset; then
        local linha re='([0-9]+)%; ([a-z ]+);'
        linha=$(pmset -g batt 2> /dev/null | sed -n 2p)
        if [[ $linha =~ $re ]]; then
            estado="${BASH_REMATCH[2]}"
            case "$estado" in charging) estado=Charging ;; charged) estado=Full ;; *) estado=Discharging ;; esac
            printf '%s %s' "${BASH_REMATCH[1]}" "$estado"
            return 0
        fi
    fi
    return 1
}

# _nome_sistema → "Pop!_OS 24.04 LTS" / "macOS 15.1" / "Ubuntu 24.04 (WSL)"
_nome_sistema() {
    local nome="" k v
    if [ "$_SO" = macos ]; then
        nome="macOS $(sw_vers -productVersion 2> /dev/null)"
    elif [ -r /etc/os-release ]; then
        while IFS='=' read -r k v; do
            [ "$k" = PRETTY_NAME ] && { nome="${v//\"/}"; break; }
        done < /etc/os-release
    fi
    [ "$_SO" = wsl ] && nome="$nome (WSL)"
    printf '%s' "${nome:-$(uname -s)}"
}

# _versao_shell → "bash 5.2" / "zsh 5.9"
_versao_shell() {
    if [ -n "${ZSH_VERSION:-}" ]; then printf 'zsh %s' "$ZSH_VERSION"
    else printf 'bash %s' "${BASH_VERSION%%(*}"; fi
}

# status - panorama completo do ambiente
status() {
    local L="  ${C_DIM}%-11s${C_OFF} %s\n"

    _cabecalho "ENVIRONMENT STATUS"

    # --- LOCAL ---
    _secao "local"
    printf "$L" "pasta"   "${C_TEXT}$(pwd)${C_OFF}"
    printf "$L" "sistema" "${C_TEXT}$(_nome_sistema) · $(_versao_shell)${C_OFF}"

    # --- GIT ---
    _secao "git"
    if git rev-parse --git-dir > /dev/null 2>&1; then
        local branch pendentes ultimo divergencia
        branch=$(git branch --show-current)
        pendentes=$(( $(git status --porcelain | wc -l) ))
        ultimo=$(git log -1 --format='%h  %s  (%cr)' 2> /dev/null)

        printf "$L" "branch" "${C_WARN}${branch}${C_OFF}"

        if [ "$pendentes" -eq 0 ]; then
            printf "$L" "mudanças" "${C_OK}árvore limpa${C_OFF}"
        else
            printf "$L" "mudanças" "${C_WARN}${pendentes} arquivo(s) pendente(s)${C_OFF}"
        fi

        # left-right conta commits só do remoto (atrás) e só locais (à frente)
        divergencia=$(git rev-list --count --left-right '@{upstream}...HEAD' 2> /dev/null)
        if [ -n "$divergencia" ]; then
            local atras frente
            read -r atras frente <<< "$divergencia"
            printf "$L" "remoto" "${C_TEXT}↓${atras} atrás  ↑${frente} à frente${C_OFF}"
        else
            printf "$L" "remoto" "${C_DIM}sem upstream configurado${C_OFF}"
        fi

        [ -n "$ultimo" ] && printf "$L" "último" "${C_TEXT}${ultimo}${C_OFF}"
    else
        printf "$L" "" "${C_DIM}não é um repositório git${C_OFF}"
    fi

    # --- PROJETO ---
    _secao "projeto"
    if [ -f package.json ]; then
        local nome_pkg versao_pkg deps
        nome_pkg=$(grep -m1 '"name"' package.json | sed 's/.*: *"\(.*\)".*/\1/')
        versao_pkg=$(grep -m1 '"version"' package.json | sed 's/.*: *"\(.*\)".*/\1/')
        printf "$L" "package" "${C_TEXT}${nome_pkg} v${versao_pkg}${C_OFF}"
        printf "$L" "gerenciador" "${C_TEXT}$(_pm)${C_OFF}"

        if [ -d node_modules ]; then
            deps=$(( $(find node_modules -maxdepth 1 -mindepth 1 -type d 2> /dev/null | wc -l) ))
            printf "$L" "node_modules" "${C_TEXT}${deps} pacote(s)${C_OFF}"
        else
            printf "$L" "node_modules" "${C_WARN}ausente — rode ni${C_OFF}"
        fi
    else
        printf "$L" "" "${C_DIM}sem package.json nesta pasta${C_OFF}"
    fi

    # --- RUNTIME ---
    _secao "runtime"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        # Lê do disco pra NÃO disparar o lazy load do nvm
        local node_versao=""
        [ -r "$NVM_DIR/alias/default" ] && read -r node_versao < "$NVM_DIR/alias/default"
        printf "$L" "node (nvm)" "${C_TEXT}${node_versao:-sem default definido}${C_OFF}"
    elif _tem node; then
        printf "$L" "node" "${C_TEXT}$(command node --version 2> /dev/null)${C_OFF}"
    else
        printf "$L" "node" "${C_DIM}não instalado${C_OFF}"
    fi
    printf "$L" "git" "${C_TEXT}$(git --version | awk '{print $3}')${C_OFF}"
    _tem python3 && printf "$L" "python" "${C_TEXT}$(python3 --version 2>&1 | awk '{print $2}')${C_OFF}"
    _tem docker && printf "$L" "docker" "${C_TEXT}$(docker --version 2> /dev/null | sed 's/Docker version \([^,]*\).*/\1/')${C_OFF}"

    # --- MÁQUINA ---
    _secao "máquina"
    printf "$L" "disco"   "${C_TEXT}$(df -Ph / | awk 'NR==2 {print $4" livres ("$5" em uso)"}')${C_OFF}"
    printf "$L" "memória" "${C_TEXT}$(_memoria)${C_OFF}"
    printf "$L" "uptime"  "${C_TEXT}$(_uptime_txt)${C_OFF}"

    local bat carga estado icone
    if bat=$(_bateria); then
        read -r carga estado <<< "$bat"
        if [ "$estado" = "Charging" ]; then icone="⚡"; else icone="🔋"; fi
        if [ "${carga:-100}" -lt 20 ] && [ "$estado" != "Charging" ]; then
            printf "$L" "bateria" "${C_WARN}${icone} ${carga}% — conecte o carregador${C_OFF}"
        else
            printf "$L" "bateria" "${C_TEXT}${icone} ${carga}%${C_OFF}"
        fi
    fi

    echo ""
}

# dev - lista SÓ os comandos personalizados deste terminal
#   dev          → tudo
#   dev git      → só uma seção (Tab completa os nomes)
# Embaixo de cada atalho, em laranja, vem o comando original que ele roda.
# (a lista das seções, _DEV_SECOES, fica em shell/50-atalhos.sh: o Tab precisa dela desde o início)

_dev_secao() {
    case "$1" in
        nav)
            _secao "navegação"
            _linha "p"             "vai direto pra pasta de projetos"
            _eq    "cd $(_curto "$DEV_HOME")"
            _linha "proj"          "lista teus projetos com busca — Enter entra no escolhido"
            _linha "mkcd nome"     "cria a pasta (e as do meio) e já entra nela"
            _eq    "mkdir -p nome && cd nome"
            _linha "cd nome"       "pula pra uma pasta que você já visitou, de qualquer lugar"
            _eq    "z nome  (zoxide)"
            _linha "zi"            "mostra as pastas já visitadas numa lista com busca"
            _linha ".. / ..."      "sobe 1 ou 2 pastas"
            _eq    "cd ..  ·  cd ../.."
            _linha "up 3"          "sobe 3 pastas de uma vez"
            _eq    "cd ../../.."
            _linha "-"             "volta pra pasta anterior (vai e volta)"
            _eq    "cd -"
            _linha "cdr"           "volta pra raiz do repositório git"
            _eq    'cd "$(git rev-parse --show-toplevel)"'
            _linha "tmpd"          "cria uma pasta temporária e entra (pra testes rápidos)"
            _eq    'cd "$(mktemp -d)"'
            _linha "open"          "abre a pasta atual no gerenciador, sem travar o terminal"
            _eq    "xdg-open .  (macOS: open · WSL: explorer.exe)"
            _linha "open arq"      "abre arquivo, pasta ou link no app padrão"
            _linha "c"             "limpa a tela"
            _eq    "clear"
            ;;
        arquivos)
            _secao "arquivos"
            _linha "ff"            "busca arquivo pelo nome, com prévia do conteúdo"
            _linha "ff texto"      "acha em quais arquivos (e linhas) esse texto aparece"
            _eq    'grep -rn "texto" .'
            _linha "extract arq"   "descompacta zip, tar.gz, rar, 7z… sem decorar a flag"
            _linha "compactar x"   "o contrário: pasta vira x.tar.gz (ou zip, tar.xz, 7z)"
            _eq    "tar -czf x.tar.gz x"
            _linha "bak arq"       "cópia de segurança ao lado, com data e hora no nome"
            _eq    "cp -a arq arq.bak-<data>"
            _linha "lixo arq"      "manda pra lixeira (recuperável) em vez de apagar de vez"
            _eq    "gio trash arq"
            _linha "espaco"        "o que mais ocupa espaço na pasta, com barrinha"
            _eq    "du -sk * | sort -rn"
            _linha "cpv a b"       "copia mostrando o progresso (bom pra arquivo grande)"
            _eq    "rsync -ah --info=progress2 a b"
            _linha "ls"            "lista com ícones, pastas primeiro"
            _eq    "eza --icons --group-directories-first"
            _linha "ll"            "lista tudo com detalhes: tamanho, data, permissão, ocultos"
            _eq    "eza -alF"
            _linha "la"            "lista incluindo os ocultos (os que começam com .)"
            _eq    "eza -A"
            _linha "lt / tree"     "mostra em árvore (lt = só 2 níveis)"
            _eq    "eza --tree --level=2"
            _linha "cat arq"       "mostra o arquivo com cores de código e nº de linha"
            _eq    "batcat --paging=never arq"
            _linha "catp arq"      "igual ao cat, mas com rolagem (q sai)"
            _eq    "batcat arq"
            ;;
        util)
            _secao "utilitários"
            _linha "clip [arq]"    "copia pra área de transferência (pwd | clip)"
            _eq    "wl-copy · xclip · pbcopy · clip.exe"
            _linha "colar"         "imprime o que está na área de transferência"
            _linha "json arq"      "formata JSON bonito (curl -s url | json)"
            _eq    "jq ."
            _linha "uuid"          "gera um UUID e já copia"
            _linha "senha [n]"     "gera uma senha forte e já copia (padrão 20 letras)"
            _linha "b64 / b64d"    "codifica / decodifica base64"
            _eq    "base64 · base64 --decode"
            _linha "epoch [ts]"    "timestamp de agora · ou converte um timestamp em data"
            _linha "calc expr"     "calculadora: calc 1500*1.07"
            _linha "loadenv"       "carrega as variáveis do .env no terminal (sem executar nada)"
            _linha "venv"          "cria/ativa o .venv do Python (de novo: desativa)"
            _eq    "python3 -m venv .venv && . .venv/bin/activate"
            _linha "mkscript x.sh" "cria script bash executável com cabeçalho seguro"
            _linha "cheat cmd"     "exemplos prontos de um comando (cheat.sh)"
            _eq    "curl cheat.sh/cmd"
            ;;
        dev)
            _secao "dev"
            _linha "serve [porta]" "sobe um site local da pasta atual (padrão 8000)"
            _eq    "python3 -m http.server 8000"
            _linha "port N"        "mostra qual programa está usando a porta N"
            _eq    "ss -lptn 'sport = :N'"
            _linha "port -k N"     "fecha esse programa e libera a porta"
            _eq    "kill <pid>"
            _linha "portas"        "todas as portas abertas e quem está em cada uma"
            _eq    "ss -tlnp"
            _linha "waitport N"    "espera a porta N abrir (banco subindo no docker…)"
            _linha "httpcheck url" "testa uma URL: código HTTP e o tempo de cada etapa"
            _eq    "curl -w '%{http_code} %{time_total}'"
            _linha "timebox [min]" "cronômetro de foco (padrão ${TIMEBOX_MIN} min), avisa na tela"
            _linha "alert"         "avisa na tela quando o comando acabar: npm run build; alert"
            _linha "status"        "painel: pasta, git, projeto, node, disco, memória, bateria"
            _linha "diario"        "abre teu diário no navegador"
            ;;
        git)
            _secao "git · dia a dia"
            _linha "gs"            "estado da pasta: o que mudou, o que é novo, o que tá no stage"
            _eq    "git status"
            _linha "gl"            "histórico em árvore, 1 commit por linha, todas as branches"
            _eq    "git log --oneline --graph --decorate --all"
            _linha "gd"            "o que você mudou e AINDA NÃO deu ga, linha por linha:"
            _linha ""              "lista os arquivos (+ entrou − saiu), Enter abre inteiro"
            _eq    "git diff"
            _linha "gd arq"        "o mesmo, só desse arquivo, direto no terminal"
            _eq    "git diff arq"
            _linha "gds"           "o que JÁ tá no stage, ou seja, o que vai no próximo commit"
            _eq    "git diff --staged"
            _linha ""              "guia completo (como ler, variações, pegadinhas): help diff"
            _linha "ga arq"        "põe o arquivo no stage — sem nome abre a lista (Tab marca)"
            _eq    "git add arq"
            _linha "gaa"           "põe TUDO no stage: novos, alterados e apagados"
            _eq    "git add --all"
            _linha "gc msg"        "salva o que tá no stage num commit (aspas opcionais)"
            _eq    'git commit -m "msg"'
            _linha "gcm"           "commit no padrão Conventional Commits, guiado por lista"
            _linha "gcm tipo:esc msg" "direto: gcm feat:login adiciona botão"
            _eq    'git commit -m "feat(login): adiciona botão"'
            _linha "gac msg"       "add de tudo + commit, numa tacada só"
            _eq    'git add --all && git commit -m "msg"'
            _linha "gamend"        "enfia as mudanças atuais no último commit, mesmo texto"
            _eq    "git add --all && git commit --amend --no-edit"
            _linha "gamend msg"    "igual, mas também troca o texto do último commit"
            _eq    'git add --all && git commit --amend -m "msg"'
            _linha "gundo"         "desfaz o último commit; as mudanças voltam pro stage"
            _eq    "git reset --soft HEAD~1"
            _linha "gwip / gunwip" "salva tudo num commit provisório · desfaz ele depois"
            _eq    'git add -A && git commit -m "wip"  ·  git reset HEAD~1'
            _linha "grst arq"      "tira o arquivo do stage (desfaz o ga); a mudança fica"
            _eq    "git restore --staged arq"
            _linha "grs arq"       "JOGA FORA as mudanças do arquivo (pede confirmação)"
            _eq    "git restore arq"
            _linha "gst [msg]"     "guarda as mudanças na gaveta (stash), até arquivo novo"
            _eq    'git stash push -u -m "msg"'
            _linha "gstp"          "tira da gaveta o último guardado e aplica de volta"
            _eq    "git stash pop"
            _linha "gsl"           "lista o que tá guardado na gaveta"
            _eq    "git stash list"
            ;;
        remoto)
            _secao "git · branches e GitHub"
            _linha "gp"            "envia teus commits pro GitHub (branch nova publica sozinha)"
            _eq    "git push   ·   1ª vez: git push -u origin branch"
            _linha "gpl"           "baixa os commits novos do GitHub e junta na tua branch"
            _eq    "git pull"
            _linha "gf"            "só confere se tem novidade no GitHub, sem mexer em nada"
            _eq    "git fetch --prune"
            _linha "gup"           "atualiza a main com o GitHub sem sair da tua branch"
            _eq    "git fetch origin main:main"
            _linha "gb"            "lista as branches (* = a que você tá)"
            _eq    "git branch"
            _linha "gbr"           "branches da mais recente pra mais antiga — Enter troca"
            _eq    "git for-each-ref --sort=-committerdate refs/heads"
            _linha "gco branch"    "troca de branch — sem nome abre a lista"
            _eq    "git checkout branch"
            _linha "gcb nome"      "cria branch nova a partir da atual e já entra nela"
            _eq    "git checkout -b nome"
            _linha "gnew nome"     "cria a branch, entra e já publica no GitHub"
            _eq    "git checkout -b nome && git push -u origin nome"
            _linha "gin branch"    "commits que VÃO ENTRAR se você der merge (sozinho = lista)"
            _eq    "git log HEAD..branch --oneline"
            _linha "gm branch"     "traz os commits de outra branch pra atual"
            _eq    "git merge branch"
            _linha "gbd nome"      "apaga a branch local (só se já foi mergeada)"
            _eq    "git branch -d nome"
            _linha "gclean"        "apaga as branches já mergeadas (menos main/master/develop)"
            _eq    "git branch --merged | xargs git branch -d"
            _linha "gcl url"       "clona o repositório e já entra na pasta"
            _eq    "git clone url && cd pasta"
            _linha "hub"           "abre o repositório atual no GitHub, no navegador"
            _eq    "git remote get-url origin  → abre o link"
            _linha "gpr [base]"    "abre a página de criar Pull Request da branch atual"
            _eq    "github.com/<repo>/compare/main...branch"
            ;;
        node)
            _secao "node · npm"
            _linha "npkg [nome]"   "cria um package.json base aqui (nunca sobrescreve)"
            _eq    "npm init -y  (só que já com type module e scripts prontos)"
            _linha "ni"            "instala tudo que tá no package.json"
            _eq    "npm install"
            _linha "ni pacote"     "instala um pacote e salva nas dependências"
            _eq    "npm install pacote"
            _linha "nid pacote"    "instala só pra desenvolvimento (eslint, prettier…)"
            _eq    "npm install --save-dev pacote"
            _linha "nr"            "lista os scripts do package.json"
            _eq    "npm run"
            _linha "nr nome"       "roda um script"
            _eq    "npm run nome"
            _linha "nrd"           "roda o script dev"
            _eq    "npm run dev"
            _linha "nrb"           "gera a versão final do projeto (build)"
            _eq    "npm run build"
            _linha "ns"            "roda o script start"
            _eq    "npm start"
            _linha "nt"            "roda os testes"
            _eq    "npm test"
            _linha "nfresh"        "apaga o node_modules e instala tudo de novo"
            _eq    "rm -rf node_modules && npm install"
            _linha "nout"          "mostra os pacotes desatualizados"
            _eq    "npm outdated"
            printf "  ${C_DIM}ni, nr… só rodam dentro de um projeto (pasta com package.json)${C_OFF}\n"
            printf "  ${C_DIM}com pnpm-lock.yaml, yarn.lock ou bun.lockb, usam o pnpm/yarn/bun${C_OFF}\n"
            ;;
        docker)
            _secao "docker"
            _linha "dps"           "containers rodando: nome, estado, portas"
            _eq    "docker ps"
            _linha "dpsa"          "todos os containers, até os parados"
            _eq    "docker ps -a"
            _linha "dimg"          "imagens baixadas e o tamanho de cada"
            _eq    "docker images"
            _linha "dlog [nome]"   "logs ao vivo — sem nome abre a lista com prévia"
            _eq    "docker logs -f --tail 100 nome"
            _linha "dsh [nome]"    "terminal dentro do container (bash ou sh)"
            _eq    "docker exec -it nome bash"
            _linha "dstop [nome]"  "para containers (sem nome: marca vários na lista)"
            _eq    "docker stop nome"
            _linha "drm [nome]"    "apaga containers (pede confirmação)"
            _eq    "docker rm nome"
            _linha "dclean [-a]"   "faxina: parados, redes e imagens órfãs (volumes ficam)"
            _eq    "docker system prune"
            _linha "dstats"        "CPU, memória e rede de cada container agora"
            _eq    "docker stats --no-stream"
            _linha "dc …"          "docker compose (acha sozinho a versão certa)"
            _linha "dcu / dcd"     "sobe os serviços em segundo plano / derruba"
            _eq    "docker compose up -d  ·  docker compose down"
            _linha "dcl / dcr"     "logs ao vivo de todos os serviços / reinicia"
            _eq    "docker compose logs -f  ·  docker compose restart"
            ;;
        rede)
            _secao "rede"
            _linha "rede"          "diagnóstico passo a passo: Wi-Fi, roteador, DNS, internet"
            _linha "meuip"         "teu IP na rede local e o IP público"
            _eq    "ip route get 1.1.1.1  ·  curl api.ipify.org"
            _linha "portas"        "portas abertas na máquina e quem está em cada uma"
            _linha "httpcheck url" "código HTTP e tempo de DNS, conexão, TLS e resposta"
            ;;
        processos)
            _secao "processos"
            _linha "psg nome"      "acha processos pelo nome (ou parte do comando)"
            _eq    "ps aux | grep nome"
            _linha "pk [nome]"     "escolhe processos numa lista e encerra (Tab marca vários)"
            _eq    "kill pid  ·  se não sair: kill -9 pid"
            _linha "topcpu [n]"    "os que mais gastam CPU agora (padrão 10)"
            _eq    "ps --sort=-%cpu"
            _linha "topmem [n]"    "os que mais gastam memória agora"
            _eq    "ps --sort=-%mem"
            _linha "mon"           "monitor ao vivo (btop, htop ou top — o que tiver)"
            ;;
        sistema)
            _secao "sistema"
            _linha "clean"         "limpeza profunda: órfãos, caches (apt, flatpak, snap, brew,"
            _linha ""              "npm, pip), logs antigos e temporários — com relatório"
            _linha "clean -n"      "só mostra quanto dá pra liberar, sem apagar nada"
            _linha "upgrade"       "atualiza tudo: apt/pacman/dnf, flatpak, snap e brew"
            _eq    "sudo apt update && sudo apt upgrade && flatpak update"
            _linha "bkp"           "copia .bashrc, .zshrc, .gitconfig e settings do VS Code"
            _eq    "cp … ~/dotfiles-backup/<data>"
            _linha "rmpkg nome"    "desinstala pacote e mostra o espaço liberado"
            _eq    "sudo apt purge nome && sudo apt autoremove"
            _linha "rmapp nome"    "desinstala app flatpak e mostra o espaço liberado"
            _eq    "flatpak uninstall --delete-data nome"
            _linha "lspkg"         "lista os pacotes que VOCÊ instalou"
            _eq    "apt-mark showmanual"
            _linha "lsapp"         "lista os apps flatpak instalados"
            _eq    "flatpak list --app --user"
            _linha "tela on / off" "liga / desliga a tela do notebook (off pede confirmação)"
            _eq    "cosmic-randr enable eDP-1  ·  disable eDP-1"
            ;;
        energia)
            _secao "energia"
            _linha "poweroff"      "desliga — confere o que tá pendente, pergunta e conta 5s"
            _eq    "systemctl poweroff"
            _linha "reboot"        "reinicia, com as mesmas checagens"
            _eq    "systemctl reboot"
            _linha "suspend"       "suspende (dorme) — acorda onde parou"
            _eq    "systemctl suspend"
            _linha "poweroff 30"   "agenda pra daqui a 30 min · poweroff cancelar desfaz"
            _eq    "shutdown -h +30  ·  shutdown -c"
            _linha "-y"            "pula a pergunta (a contagem com Ctrl+C continua)"
            printf "  ${C_DIM}também em português: desligar · reiniciar · suspender${C_OFF}\n"
            printf "  ${C_DIM}antes de desligar salva um log em %s${C_OFF}\n" "$(_curto "$DOTFILES_ESTADO/energia")"
            ;;
        terminal)
            _secao "este terminal"
            _linha "atualizar"     "baixa a versão nova deste terminal (GitHub) e já recarrega"
            _eq    "git -C ~/dotfiles pull && source ~/.bashrc"
            _linha "dotfiles"      "check-up: o que está instalado e o que falta"
            _linha "dotfiles tempo" "quanto o terminal leva pra abrir"
            _linha "dotfiles perfil" "quanto cada módulo leva pra carregar"
            _linha "banner"        "mostra o banner animado de abertura"
            _linha "help"          "comandos NATIVOS do sistema, explicados"
            ;;
        *)
            return 1
            ;;
    esac
}

dev() {
    local _LARG=14 s     # _LARG: largura da coluna de nomes (o _linha e o _eq enxergam)

    if [ $# -eq 0 ]; then
        _cabecalho "YOUR COMMANDS"
        printf "  ${C_DIM}↳ ${C_WARN}em laranja${C_DIM}: o comando original que o atalho roda por baixo${C_OFF}\n"
        for s in "${_DEV_SECOES[@]}"; do _dev_secao "$s"; done
        printf "\n${C_DIM}  dev <seção> mostra só uma: %s${C_OFF}\n" "${_DEV_SECOES[*]}"
        printf "${C_DIM}  sem argumento, os comandos mostram como usar (ga e gco abrem a lista)${C_OFF}\n"
        printf "${C_DIM}  comandos nativos do sistema: ${C_TEXT}help${C_OFF}\n\n"
        return 0
    fi

    for s in "${_DEV_SECOES[@]}"; do
        if [ "$1" = "$s" ]; then
            _dev_secao "$s"
            printf "\n"
            return 0
        fi
    done

    _err "'$1' não é uma seção do dev" "seções: ${_DEV_SECOES[*]}"
    return 1
}

# help - comandos NATIVOS mais úteis (o que é personalizado fica no 'dev')
# 'help' já existe no bash (help cd). Ele continua funcionando:
#   help            → esta lista
#   help rede       → só uma seção
#   help cd         → ajuda original do bash (no zsh: o manual do comando)
# (a lista das seções, _HELP_SECOES, fica em shell/50-atalhos.sh)

_help_secao() {
    case "$1" in
        nav)
            _secao "navegação"
            _linha "cd pasta"                "entra na pasta"
            _linha "cd"                      "volta pra home"
            _linha "cd -"                    "volta pra pasta anterior (vai e volta)"
            _linha "pwd"                     "mostra o caminho de onde você está"
            ;;
        arquivos)
            _secao "arquivos e pastas"
            _linha "touch arq"               "cria arquivo vazio"
            _linha "mkdir -p a/b/c"          "cria pastas, inclusive as do meio"
            _linha "cp arq destino"          "copia (pasta precisa de -r)"
            _linha "mv origem destino"       "move ou renomeia"
            _linha "rm arq · rm -r pasta"    "apaga — não vai pra lixeira (use: lixo)"
            _linha "ln -s alvo atalho"       "cria atalho (link simbólico)"
            _linha "chmod +x script.sh"      "deixa o arquivo executável"
            _linha 'find . -name "*.js"'     "acha arquivos pelo nome"
            _linha "du -sh *"                "tamanho de cada item da pasta"
            _linha "file arq"                "descobre o tipo real do arquivo"
            _linha "xdg-open arq"            "abre no app padrão (pdf, imagem…)"
            _linha "tar -czf x.tar.gz pasta" "compacta a pasta"
            ;;
        texto)
            _secao "ler e mexer em texto"
            _linha "less arq"                "lê arquivo grande (q sai, / busca)"
            _linha "head -n 20 arq"          "primeiras 20 linhas"
            _linha "tail -n 20 arq"          "últimas 20 linhas"
            _linha "tail -f arq.log"         "acompanha o arquivo crescendo ao vivo"
            _linha 'grep -rn "txt" .'        "acha texto nos arquivos (-i ignora maiúscula)"
            _linha "wc -l arq"               "conta linhas"
            _linha "diff a b"                "compara dois arquivos"
            _linha "nano arq"                "editor simples (Ctrl+O salva, Ctrl+X sai)"
            _linha "code ."                  "abre a pasta atual no VS Code"
            ;;
        pipes)
            _secao "combinar comandos"
            _linha "a | b"                   "a saída de a vira entrada de b"
            _linha "cmd > arq"               "salva a saída no arquivo (sobrescreve)"
            _linha "cmd >> arq"              "adiciona no fim do arquivo"
            _linha "cmd 2> /dev/null"        "joga as mensagens de erro fora"
            _linha "cmd &> arq"              "salva saída + erros juntos"
            _linha "a && b"                  "roda b só se a deu certo"
            _linha "a || b"                  "roda b só se a falhou"
            _linha "cmd &"                   "roda em segundo plano"
            _linha '$(cmd)'                  "usa a saída de um comando dentro de outro"
            ;;
        teclado)
            _secao "atalhos de teclado"
            _linha "Tab"                     "completa (com várias opções, já lista todas)"
            _linha "Ctrl+R"                  "busca no histórico (fzf)"
            _linha "texto + ↑ / ↓"           "navega só nos comandos que começam com o texto"
            _linha "Ctrl+T"                  "insere arquivo com preview (fzf)"
            _linha "Alt+C"                   "entra numa subpasta (fzf)"
            _linha "Ctrl+A · Ctrl+E"         "vai pro início · fim da linha"
            _linha "Ctrl+← · Ctrl+→"         "pula palavra"
            _linha "Ctrl+W"                  "apaga a palavra anterior"
            _linha "Ctrl+U · Ctrl+K"         "apaga até o início · até o fim"
            _linha "Alt+."                   "cola o último argumento do comando anterior"
            _linha "Ctrl+L"                  "limpa a tela (mantém o que está digitado)"
            _linha "Ctrl+C"                  "cancela o comando"
            _linha "Ctrl+Z · fg"             "pausa o processo · traz de volta"
            _linha "Ctrl+Shift+C · V"        "copia · cola no terminal"
            ;;
        historico)
            _secao "histórico"
            _linha "history"                 "lista o histórico (com data e hora)"
            _linha '!!'                      "repete o último comando"
            _linha 'sudo !!'                 "repete o último comando como admin"
            _linha '!$'                      "último argumento do comando anterior"
            _linha '!123'                    "roda o comando nº 123 do histórico"
            ;;
        processos)
            _secao "processos"
            _linha "top"                     "monitor de processos ao vivo (q sai)"
            _linha "pgrep -a nome"           "acha o processo e mostra o PID"
            _linha "kill PID"                "pede pro processo encerrar"
            _linha "kill -9 PID"             "mata na marra (último recurso)"
            _linha "pkill nome"              "encerra pelo nome"
            _linha "jobs · fg · bg"          "lista · traz pra frente · manda pro fundo"
            _linha "time cmd"                "mede quanto o comando demora"
            _linha "watch -n 2 cmd"          "repete o comando a cada 2s"
            ;;
        sistema)
            _secao "sistema"
            _linha "sudo cmd"                "roda como administrador"
            _linha "free -h"                 "uso de memória RAM"
            _linha "df -h"                   "espaço livre nos discos"
            _linha "lsblk"                   "discos, pendrives e partições"
            _linha "systemctl status x"      "estado de um serviço"
            _linha "sudo journalctl -f"      "logs do sistema ao vivo"
            _linha "reboot · poweroff"       "reinicia · desliga (aqui pedem confirmação: dev energia)"
            ;;
        pacotes)
            _secao "pacotes"
            _linha "sudo apt update"         "atualiza a lista de pacotes"
            _linha "sudo apt upgrade"        "atualiza o que está instalado"
            _linha "sudo apt install x"      "instala um pacote"
            _linha "apt search x"            "procura pacote pelo nome"
            _linha "flatpak update"          "atualiza os apps flatpak"
            _linha "flatpak search x"        "procura app flatpak"
            _linha "brew install x"          "instala no macOS (Homebrew)"
            ;;
        rede)
            _secao "rede"
            _linha "ping google.com"         "testa se tem internet (Ctrl+C para)"
            _linha "curl url"                "faz requisição HTTP (ótimo pra testar API)"
            _linha "curl -I url"             "só os cabeçalhos da resposta"
            _linha "curl -O url"             "baixa o arquivo"
            _linha "hostname -I"             "teu IP na rede local"
            _linha "ss -tlnp"                "todas as portas abertas"
            _linha "ssh user@host"           "acessa outro computador"
            ;;
        git)
            _secao "git (o que não tem atalho)"
            _linha "git init"                "transforma a pasta em repositório"
            _linha "git remote -v"           "mostra pra onde o repo aponta"
            _linha "git remote add origin"   "+ url: liga o repo local ao GitHub"
            _linha "git show hash"           "detalhes e mudanças de um commit"
            _linha "git log -p arq"          "histórico de mudanças de um arquivo"
            _linha "git blame arq"           "quem mudou cada linha e quando"
            _linha "git revert hash"         "desfaz um commit criando outro (seguro)"
            _linha "git reflog"              "salva-vidas: acha commit 'perdido'"
            _linha "git diff …"              "compara versões — guia completo: help diff"
            ;;
        node)
            _secao "node / npm"
            _linha "node arq.js"             "roda um arquivo JS"
            _linha "node"                    "console JS interativo (.exit sai)"
            _linha "npm init -y"             "cria o package.json"
            _linha "npm i"                   "instala tudo do package.json"
            _linha "npm i pacote"            "instala dependência (-D = só dev)"
            _linha "npm run nome"            "roda um script do package.json"
            _linha "npx pacote"              "roda sem instalar"
            _linha "nvm ls · nvm use 22"     "versões do node · troca de versão"
            ;;
        shell)
            _secao "shell"
            _linha 'echo $VAR'               "mostra o valor de uma variável"
            _linha "export VAR=valor"        "cria variável de ambiente (só nesta sessão)"
            _linha "env | grep x"            "procura entre as variáveis de ambiente"
            _linha "source ~/.bashrc"        "recarrega a config sem fechar o terminal"
            _linha "exit"                    "fecha o terminal"
            ;;
        ajuda)
            _secao "quando travar"
            _linha "help cmd"                "ajuda dos comandos internos (cd, export…)"
            _linha "man cmd"                 "manual completo (q sai, / busca)"
            _linha "cmd --help"              "resumo rápido das opções"
            _linha "type cmd"                "diz se é alias, função ou programa"
            _linha "alias"                   "lista todos os aliases"
            _linha "apropos palavra"         "acha comando pela descrição"
            ;;
        *)
            return 1
            ;;
    esac
}

# _guia_diff - guia completo do git diff (abre com: help diff)
# _paragrafo "texto"  — parágrafo do guia, recuado
_paragrafo() { printf "  ${C_TEXT}%s${C_OFF}\n" "$1"; }
_guia_diff() {
    local _LARG=20
    _cabecalho "GIT DIFF — o que mudou, linha por linha"

    _secao "o que ele faz"
    _paragrafo "Compara duas versões do teu código e mostra SÓ as linhas que mudaram."
    _paragrafo "Ele não mexe em nada, só mostra: pode rodar quantas vezes quiser."

    _secao "as 3 áreas do git (é isso que o diff compara)"
    _linha "pasta"   "teus arquivos do jeito que estão agora no editor"
    _linha "stage"   "o que você já separou com ga/gaa pro próximo commit"
    _linha "commit"  "a última versão salva (o git chama de HEAD)"
    printf "\n  ${C_CMD}pasta${C_OFF} ${C_DIM}──${C_WARN}ga${C_DIM}──▶${C_OFF} ${C_CMD}stage${C_OFF} ${C_DIM}──${C_WARN}gc${C_DIM}──▶${C_OFF} ${C_CMD}commit${C_OFF}\n"

    _secao "qual diff usar"
    _linha "git diff"            "pasta × stage: o que você mudou e AINDA NÃO deu ga"
    _eq    "atalho: gd (abre a lista com prévia)"
    _linha "git diff --staged"   "stage × commit: o que vai entrar no próximo commit"
    _eq    "atalho: gds"
    _linha "git diff HEAD"       "pasta × commit: tudo que mudou desde o último commit"
    _linha "git diff arq"        "qualquer um acima, só daquele arquivo"
    _eq    "atalho: gd arq · gds arq"
    _linha "git diff HEAD~1"     "tua pasta × o commit anterior (HEAD~2 = 2 atrás…)"
    _linha "git diff main"       "tua pasta × a branch main"
    _linha "git diff main...x"   "só o que a branch x mudou desde que saiu da main"
    _eq    "ótimo antes de um merge — junto com o gin"
    _linha "git diff a1b2 c3d4"  "entre dois commits quaisquer (o hash vem do gl)"

    _secao "opções que ajudam (servem em todos acima)"
    _linha "--stat"          "só o resumo: quais arquivos e quantas linhas (+ e −)"
    _linha "--name-only"     "só os nomes dos arquivos que mudaram"
    _linha "--word-diff"     "marca as PALAVRAS que mudaram, não a linha inteira"
    _linha "-w"              "ignora mudança que é só espaço ou indentação"
    _eq    "ex.: gd --stat · gds --name-only · git diff HEAD~1 -w"

    _secao "como ler a saída"
    printf "  ${C_TEXT}diff --git a/app.js b/app.js${C_OFF}   ${C_DIM}arquivo comparado (a = antes, b = depois)${C_OFF}\n"
    printf "  ${C_TEXT}@@ -5,3 +5,4 @@${C_OFF}                ${C_DIM}trecho: -5,3 = antes: linha 5, 3 linhas${C_OFF}\n"
    printf "  %31s${C_DIM}        +5,4 = agora: linha 5, 4 linhas${C_OFF}\n" ""
    printf "  ${C_TEXT} const total = soma(2, 3)${C_OFF}      ${C_DIM}sem sinal: linha igual, só pra dar contexto${C_OFF}\n"
    printf "  ${C_ERR}-console.log(total)${C_OFF}            ${C_DIM}− vermelho: linha que SAIU${C_OFF}\n"
    printf "  ${C_OK}+mostrar(total)${C_OFF}                ${C_DIM}+ verde: linha que ENTROU${C_OFF}\n"
    _paragrafo "Linha alterada aparece como as duas: a velha com − e a nova com +."
    _paragrafo "Com o delta instalado, cada linha mostra:  nº antes ⋮ nº depois │ código."

    _secao "pegadinhas"
    _paragrafo "Arquivo novo não aparece no git diff até você dar ga (aí aparece no gds)."
    _paragrafo "Deu ga em tudo e o gd ficou vazio? Normal: agora tá tudo no gds."
    _paragrafo "Diff vazio não é erro: quer dizer que não tem nada diferente ali."
    _paragrafo "Em diff comprido: espaço desce a página, b sobe, / busca, q sai."

    _secao "na interface do gd / gds"
    _paragrafo "↑ ↓ escolhe o arquivo · digitar filtra pelo nome"
    _paragrafo "Enter abre o arquivo inteiro (lado a lado se a tela for larga)"
    _paragrafo "q volta pra lista · Esc sai"
    printf "\n"
}

help() {
    local _LARG=24 s     # _LARG: largura da coluna de nomes (o _linha enxerga)

    # Sem argumento: a lista inteira
    if [ $# -eq 0 ]; then
        _cabecalho "SYSTEM COMMANDS"
        for s in "${_HELP_SECOES[@]}"; do _help_secao "$s"; done
        printf "\n${C_DIM}  help <seção> mostra só uma: %s${C_OFF}\n" "${_HELP_SECOES[*]}"
        printf "${C_DIM}  guia completo do git diff: ${C_TEXT}help diff${C_OFF}\n"
        printf "${C_DIM}  teus comandos personalizados: ${C_TEXT}dev${C_OFF}\n\n"
        return 0
    fi

    # help diff → guia completo do git diff (não entra na lista geral: é comprido)
    if [ "$1" = "diff" ]; then
        _guia_diff
        return 0
    fi

    # help <seção>
    for s in "${_HELP_SECOES[@]}"; do
        if [ "$1" = "$s" ]; then
            _help_secao "$s"
            printf "\n"
            return 0
        fi
    done

    # help cd / help export / help -d ...  → cai no help original do bash
    # (pergunta pro próprio help: o 'type' diria "alias" pro cd, que virou zoxide)
    if [ -z "${ZSH_VERSION:-}" ]; then
        if [[ "$1" == -* ]] || builtin help -s "$1" > /dev/null 2>&1; then
            builtin help "$@"
            return
        fi
    elif [[ "$(whence -wa "$1" 2> /dev/null)" == *": builtin"* || "$(whence -wa "$1" 2> /dev/null)" == *": reserved"* ]]; then
        # o zsh não tem 'help': o manual dos comandos internos dele é o zshbuiltins
        man zshbuiltins 2> /dev/null | less -p "^       $1 " 2> /dev/null || man zshbuiltins
        return
    fi

    _err "'$1' não é seção nem comando interno do shell" "tente: man $1  ou  $1 --help"
    _dica "seções: ${_HELP_SECOES[*]}"
    return 1
}

# ==========================================
# DOTFILES — check-up do próprio terminal
#   dotfiles          o que está instalado, o que falta e como instalar
#   dotfiles tempo    quanto o terminal leva pra abrir (média de 5)
#   dotfiles perfil   quanto cada módulo leva pra carregar
#   dotfiles cache    apaga o cache dos 'init' (refaz no próximo terminal)
#   dotfiles editar   abre o repositório no editor
# ==========================================
dotfiles() {
    case "${1:-doctor}" in
        doctor|check) _dotfiles_doctor ;;
        tempo)        _dotfiles_tempo ;;
        perfil)       DOTFILES_PERFIL=1 DOTFILES_ANIM=0 "$_SHELL" -i -c exit 2> /dev/null | grep 'µs' ;;
        cache)
            command rm -rf "$DOTFILES_CACHE"
            _ok "cache apagado" "o próximo terminal refaz (fica uns ms mais lento só dessa vez)"
            ;;
        editar)
            if _tem code; then code "$DOTFILES"; else "${EDITOR:-vi}" "$DOTFILES"; fi
            ;;
        *)
            _uso "dotfiles [doctor | tempo | perfil | cache | editar]"
            ;;
    esac
}

_dotfiles_doctor() {
    local _LARG=12 t falta=0
    _cabecalho "DOTFILES · CHECK-UP"

    _secao "terminal"
    _linha "sistema"   "$(_nome_sistema) · $(_versao_shell)"
    _linha "repo"      "$(_curto "$DOTFILES") · $(git -C "$DOTFILES" log -1 --format='%h %cr' 2> /dev/null)"
    local rc rc_repo
    read -r rc rc_repo <<< "$(_rc_do_shell)"
    if [ "$(_caminho_real "$rc")" = "$(_caminho_real "$rc_repo")" ]; then
        _linha "atalho"  "$(_curto "$rc") → $(_curto "$rc_repo") ✓"
    else
        _linha "atalho"  "$(_curto "$rc") NÃO aponta pro repo — o atualizar não chega nele"
        _eq "$(_curto "$DOTFILES")/install.sh"
    fi
    if [ -r "$DOTFILES_LOCAL" ]; then
        _linha "local.sh" "$(_curto "$DOTFILES_LOCAL") (teus ajustes)"
    else
        _linha "local.sh" "não tem — ajustes pessoais iriam em $(_curto "$DOTFILES_LOCAL")"
    fi

    _secao "ferramentas"
    local item nome uso
    for item in \
        "git|base de tudo (obrigatório)" \
        "fzf|as listas com busca (gd, ga, gco, proj, ff, pk…)" \
        "zoxide|o cd que lembra das pastas" \
        "eza|o ls com ícones" \
        "bat|o cat com cores" \
        "fd|busca de arquivos rápida" \
        "rg|busca de texto rápida (ff texto)" \
        "delta|o git diff colorido" \
        "jq|o json formatado" \
        "docker|os atalhos do docker"
    do
        nome="${item%%|*}"; uso="${item#*|}"
        t="$nome"
        [ "$nome" = bat ] && [ -n "$_BAT" ] && t="$_BAT"
        [ "$nome" = fd ] && [ -n "$_FD" ] && t="$_FD"
        if _tem "$t"; then
            printf "  ${C_OK}✓${C_OFF} ${C_CMD}%s${C_OFF} ${C_DIM}%s${C_OFF}\n" "$(_pad "$nome" 8)" "$uso"
        else
            printf "  ${C_ERR}✗${C_OFF} ${C_CMD}%s${C_OFF} ${C_DIM}%s${C_OFF}\n" "$(_pad "$nome" 8)" "$uso"
            printf "    %s ${C_WARN}%s${C_OFF}\n" "$(_pad "" 8)" "$(_cmd_instalar "$nome")"
            falta=$(( falta + 1 ))
        fi
    done

    printf "\n"
    if [ "$falta" -eq 0 ]; then
        _ok "tudo instalado" "o terminal está completo"
    else
        _aviso "$(_plural "$falta" "ferramenta opcional faltando" "ferramentas opcionais faltando")" \
            "tudo funciona sem elas — só fica mais simples. Instala tudo: ~/dotfiles/install.sh --ferramentas"
    fi
}

# _dotfiles_tempo - abre o shell 5 vezes (sem banner) e mostra o tempo de cada um
_dotfiles_tempo() {
    local i t0 tempos=() ms soma=0
    _titulo "⏱" "medindo quanto o $_SHELL leva pra abrir" "5 vezes"
    for i in 1 2 3 4 5; do
        _us t0
        DOTFILES_ANIM=0 _BASHRC_CARREGADO=1 "$_SHELL" -i -c exit > /dev/null 2>&1
        ms=$(( ( $(_us_agora) - t0 ) / 1000 ))
        tempos+=("$ms")
        soma=$(( soma + ms ))
    done
    _feito "⚡" "média $(( soma / 5 ))ms" "cada vez: ${tempos[*]} (ms)"
    _dica "abaixo de 50ms ninguém percebe · detalhe por módulo: dotfiles perfil"
}
_us_agora() { local x; _us x; printf '%s' "$x"; }
