# shellcheck shell=bash
# ==========================================
# GIT
# ==========================================

# _em_repo_git - guarda usada por todas as funções git
_em_repo_git() {
    git rev-parse --git-dir > /dev/null 2>&1 && return 0
    _err "aqui não é um repositório git" "entre na pasta do projeto ou rode: git init"
}

# Comandos que só MOSTRAM coisa: a própria saída do git já é o feedback.
# Viraram função só pra ganhar o erro bonito fora de um repositório.
gs()  { _em_repo_git && git status "$@"; }
gl()  { _em_repo_git && git log --oneline --graph --decorate --all "$@"; }

# gd / gds - sem argumento abrem a INTERFACE do diff (ver _diff_lista abaixo).
# Com argumento viram o git diff normal: gd src/app.js · gd --stat · gds arq
gd() {
    _em_repo_git || return 1
    if [ $# -eq 0 ] && [ -t 1 ] && _tem fzf; then
        _diff_lista
    else
        git diff "$@"
    fi
}
gds() {
    _em_repo_git || return 1
    if [ $# -eq 0 ] && [ -t 1 ] && _tem fzf; then
        _diff_lista --staged
    else
        git diff --staged "$@"
    fi
}

# _diff_lista [--staged] - a interface do gd/gds:
#   esquerda: os arquivos mudados com quantas linhas entraram (+) e saíram (−)
#   direita:  a prévia do diff do arquivo selecionado
#   Enter abre o diff completo em tela cheia (lado a lado se a tela for larga)
#   q volta pra lista · Esc sai
_diff_lista() {
    local staged="$1" rotulo="mudanças fora do stage"
    [ -n "$staged" ] && rotulo="o que vai no próximo commit"

    # --numstat: "linhas+  linhas−  arquivo" de cada arquivo (binário vem com "-")
    # --no-renames: arquivo renomeado aparece como apagado + novo (lista mais simples)
    local numstat
    # shellcheck disable=SC2086  # $staged vazio tem que sumir, não virar ""
    numstat=$(git diff $staged --no-renames --numstat 2> /dev/null)

    if [ -z "$numstat" ]; then
        if [ -n "$staged" ]; then
            _ok "nada no stage ainda"
            _dica "põe arquivo no stage com: ga  (ou gaa pra tudo)"
        else
            _ok "nenhuma mudança fora do stage"
            [ -n "$(git diff --staged --name-only 2> /dev/null)" ] && _dica "o que já tá no stage: gds"
        fi
        _diff_novos "$staged"
        return 0
    fi

    # Monta as linhas da lista: "+12 −3     <TAB>arquivo" e soma o total.
    # Os números vêm primeiro, com largura fixa, pra coluna dos nomes ficar alinhada.
    local add del arq est pad linhas="" n=0 tot_add=0 tot_del=0
    while IFS=$'\t' read -r add del arq; do
        n=$((n + 1))
        if [ "$add" = "-" ]; then
            est="binário"
            pad=$(( 10 - ${#est} )); (( pad < 1 )) && pad=1
            linhas+="${C_DIM}${est}${C_OFF}$(printf '%*s' "$pad" '')"$'\t'"${arq}"$'\n'
        else
            tot_add=$((tot_add + add)); tot_del=$((tot_del + del))
            est="+${add} −${del}"
            pad=$(( 10 - ${#est} )); (( pad < 1 )) && pad=1
            linhas+="${C_OK}+${add}${C_OFF} ${C_ERR}−${del}${C_OFF}$(printf '%*s' "$pad" '')"$'\t'"${arq}"$'\n'
        fi
    done <<< "$numstat"

    # Prévia e tela cheia: com delta fica colorido; sem ele, o diff colorido do git.
    # "less -R" sem o -F: senão um diff curto fecha na hora e você nem vê a tela cheia.
    # > /dev/tty: a saída do fzf vai pro /dev/null lá embaixo, a tela cheia não pode ir junto.
    local previa cheia lado=""
    (( ${COLUMNS:-80} >= 140 )) && lado="--side-by-side"
    if _tem delta; then
        previa="git diff $staged --no-renames --color=always -- {2} | delta --paging=never --width=\$FZF_PREVIEW_COLUMNS $_DELTA_ESTILO"
        cheia="git diff $staged --no-renames --color=always -- {2} | DELTA_PAGER='less -R' delta --paging=always $lado $_DELTA_ESTILO > /dev/tty"
    else
        previa="git diff $staged --no-renames --color=always -- {2}"
        cheia="git diff $staged --no-renames --color=always -- {2} | less -R > /dev/tty"
    fi

    printf '%s' "$linhas" | fzf --ansi --delimiter=$'\t' --height=100% --no-sort \
        --tabstop=1 --border=rounded \
        --border-label=" ${rotulo} ─ Enter: diff inteiro (q volta) · Esc: sai " \
        --header="$(_plural "$n" arquivo arquivos) · +${tot_add} −${tot_del}" \
        --prompt='arquivo ❯ ' \
        --preview="$previa" \
        --preview-window='right,65%,border-left,<50(down,65%,border-top)' \
        --bind="enter:execute($cheia)" > /dev/null

    _diff_novos "$staged"
    _tem delta || _dica "pra cores de código e nº de linha no diff: $(_cmd_instalar delta)"
    return 0
}

# _diff_novos [--staged] - lembra que arquivo novo não aparece no diff até o ga
_diff_novos() {
    [ -n "$1" ] && return 0
    local novos
    novos=$(( $(git ls-files --others --exclude-standard 2> /dev/null | wc -l) ))
    (( novos > 0 )) && _dica "$(_plural "$novos" "arquivo novo" "arquivos novos") fora da lista — o diff só mostra depois do ga"
    return 0
}
gb()  { _em_repo_git && git branch "$@"; }

# _git - roda o git em silêncio.
# Deu certo: não mostra nada (quem chamou monta o resumo).
# Deu errado: mostra as linhas de erro do git formatadas. As linhas 'hint:'
# ficam de fora — nos casos comuns a função que chamou dá a dica em português.
# (Quer o texto completo? Roda o mesmo comando com 'git' puro.)
# A saída inteira fica em _GIT_SAIDA pra função que chamou poder ler.
_git() {
    local cod linha
    _GIT_SAIDA=$(git "$@" 2>&1)
    cod=$?
    if [ "$cod" -ne 0 ]; then
        {
            printf "${_CL}  ${C_ERR}✗${C_OFF}  ${C_TEXT}git %s falhou${C_OFF}\n" "$1"
            while IFS= read -r linha; do
                [[ -z "$linha" || "$linha" == hint:* ]] && continue
                printf "     ${C_DIM}│${C_OFF} %s\n" "$linha"
            done <<< "$_GIT_SAIDA"
        } >&2
    fi
    return "$cod"
}

# _numeros_stat "saída do --shortstat"  → "arquivos inserções remoções"
_numeros_stat() {
    local a=0 i=0 d=0
    local re_a='([0-9]+) file' re_i='([0-9]+) insertion' re_d='([0-9]+) deletion'
    [[ $1 =~ $re_a ]] && a=${BASH_REMATCH[1]}
    [[ $1 =~ $re_i ]] && i=${BASH_REMATCH[1]}
    [[ $1 =~ $re_d ]] && d=${BASH_REMATCH[1]}
    echo "$a $i $d"
}

# _resumo_stage  → "+1 novo  ~3 alterados  −1 apagado" do que está no stage
_resumo_stage() {
    local a=0 m=0 d=0 st resto saida=""
    while IFS=$'\t' read -r st resto; do
        case "$st" in
            A*) a=$((a + 1)) ;;
            D*) d=$((d + 1)) ;;
            ?*) m=$((m + 1)) ;;
        esac
    done < <(git diff --cached --name-status 2> /dev/null)

    (( a > 0 )) && saida+="${C_OK}+$(_plural "$a" novo novos)${C_OFF}  "
    (( m > 0 )) && saida+="${C_WARN}~$(_plural "$m" alterado alterados)${C_OFF}  "
    (( d > 0 )) && saida+="${C_ERR}−$(_plural "$d" apagado apagados)${C_OFF}  "
    saida="${saida%  }"                      # tira o espaço sobrando no fim
    printf '%s' "${saida:-${C_DIM}vazio${C_OFF}}"
}

# _resumo_commit - cartão do último commit (usado por gc, gac, gcm e gamend)
_resumo_commit() {
    local arq ins del
    # LC_ALL=C: força o git em inglês pra leitura não depender do idioma do sistema
    read -r arq ins del < <(_numeros_stat "$(LC_ALL=C git show --shortstat --format= HEAD 2> /dev/null)")
    _kv "branch" "$(git branch --show-current)"
    printf "     ${C_DIM}%-9s${C_OFF} ${C_WARN}%s${C_OFF}\n" "hash" "$(git rev-parse --short HEAD)"
    printf "     ${C_DIM}%-9s${C_OFF} ${C_TEXT}%s${C_OFF}   ${C_OK}+%s${C_OFF} ${C_ERR}−%s${C_OFF}\n" \
        "arquivos" "$arq" "$ins" "$del"
    _kv "mensagem" "$(git log -1 --format=%s)"
}

# _ja_no_remoto - verdadeiro se o último commit já foi enviado pro GitHub
_ja_no_remoto() {
    git merge-base --is-ancestor HEAD '@{upstream}' 2> /dev/null
}

# _branch_padrao - a branch principal do repositório (main, master…)
_branch_padrao() {
    local ref
    if ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2> /dev/null); then
        printf '%s' "${ref#origin/}"
        return 0
    fi
    for ref in main master develop trunk; do
        if git show-ref --verify --quiet "refs/heads/$ref"; then
            printf '%s' "$ref"
            return 0
        fi
    done
    return 1
}

# _url_remoto - link de navegador do remoto 'origin' (SSH vira HTTPS)
_url_remoto() {
    local remoto url
    remoto=$(git remote get-url origin 2> /dev/null)
    if [ -z "$remoto" ]; then
        _err "esse repositório não tem remoto 'origin'" "conecte com: git remote add origin <url>"
        return 1
    fi
    url="${remoto%.git}"                     # tira o .git do final
    case "$url" in
        git@*)                               # git@github.com:user/repo
            url="${url#git@}"
            url="https://${url/://}" ;;
        ssh://*)                             # ssh://git@github.com/user/repo
            url="${url#ssh://}"
            url="https://${url#*@}" ;;
        https://*@*)                         # https://token@github.com/user/repo
            url="https://${url#https://*@}" ;;
    esac
    printf '%s' "$url"
}

# ---------- dia a dia ----------

# ga - adiciona arquivos ao stage. Sem argumento: escolhe numa lista (Tab marca vários)
ga() {
    _em_repo_git || return 1

    if [ $# -eq 0 ]; then
        if ! _tem fzf; then
            _uso "ga <arquivo> [arquivo2 ...]" "ga .   adiciona tudo desta pasta"
            return 1
        fi
        local escolhidos=() f
        # -z/--read0/--print0: nomes separados por byte nulo, então espaço no nome não quebra
        while IFS= read -r -d '' f; do escolhidos+=("$f"); done < <(
            git ls-files -z --modified --others --deleted --exclude-standard | sort -zu |
            fzf --multi --read0 --print0 --prompt='add ❯ ' --header='Tab marca · Enter confirma' \
                --preview 'git diff --color=always -- {} 2>/dev/null | head -100; git diff --quiet -- {} 2>/dev/null && head -60 {}'
        )
        [ ${#escolhidos[@]} -eq 0 ] && return 0     # Esc: cancelou, sem drama
        set -- "${escolhidos[@]}"
    fi

    _git add -- "$@" || return 1

    local lista=() f
    while IFS= read -r f; do lista+=("$f"); done < <(git diff --cached --name-only -- "$@")
    _feito "+" "adicionado ao stage" "$(_plural "${#lista[@]}" arquivo arquivos)"
    for f in "${lista[@]:0:8}"; do
        printf "     ${C_OK}+${C_OFF} ${C_TEXT}%s${C_OFF}\n" "$f"
    done
    (( ${#lista[@]} > 8 )) && printf "     ${C_DIM}… e mais %s${C_OFF}\n" "$(( ${#lista[@]} - 8 ))"
    printf "     ${C_DIM}%-9s${C_OFF} %s\n" "stage" "$(_resumo_stage)"
}

# gaa - adiciona tudo
gaa() {
    _em_repo_git || return 1
    if [ -z "$(git status --porcelain)" ]; then
        _ok "nada pra adicionar" "árvore de trabalho limpa"
        return 0
    fi
    _git add --all || return 1
    printf "  ${C_OK}+${C_OFF}  ${C_TEXT}tudo no stage${C_OFF}   %s\n" "$(_resumo_stage)"
}

# gc - commit do que está no stage. Aspas opcionais: gc arruma o menu
gc() {
    if [ $# -eq 0 ]; then
        _uso 'gc "mensagem"' "aspas são opcionais: gc arruma o menu"
        return 1
    fi
    _em_repo_git || return 1
    if git diff --cached --quiet 2> /dev/null; then
        _err "nada no stage pra commitar" "use ga <arquivo> ou gaa antes — ou gac pra fazer tudo junto"
        return 1
    fi
    _git commit -m "$*" || return 1
    _feito "◆" "commit criado"
    _resumo_commit
}

# gac - add tudo + commit numa tacada só
gac() {
    if [ $# -eq 0 ]; then
        _uso 'gac "mensagem"' "add tudo + commit · aspas opcionais"
        return 1
    fi
    _em_repo_git || return 1
    if [ -z "$(git status --porcelain)" ]; then
        _err "nada pra commitar" "árvore de trabalho limpa"
        return 1
    fi
    _git add --all || return 1
    _git commit -m "$*" || return 1
    _feito "◆" "commit criado"
    _resumo_commit
}

# gcm - commit no padrão Conventional Commits: tipo(escopo): descrição
#   gcm                              → painel dos tipos: quando usar cada um, com exemplo
#   gcm feat:login adiciona botão    → feat(login): adiciona botão  (aspas opcionais)
#   gcm fix corrige o cálculo        → fix: corrige o cálculo       (sem escopo)
#   gcm feat:api! muda a rota        → feat(api)!: muda a rota      (! = quebra compatibilidade)
# O escopo vai depois de ':' porque parêntese solto é erro de sintaxe no bash
# ("feat(login)" entre aspas também vale).
_GCM_TIPOS=(feat fix docs style refactor perf test build ci chore revert)
gcm() {
    if [ $# -eq 0 ]; then
        _gcm_painel
        return 0
    fi
    _em_repo_git || return 1
    if git diff --cached --quiet 2> /dev/null; then
        _err "nada no stage pra commitar" "use ga <arquivo> ou gaa antes"
        return 1
    fi

    local tipo="" escopo="" quebra="" desc="" cab
    cab="${1%:}"; shift
    desc="$*"

    # separa tipo, escopo e ! do cabeçalho: "feat:login!" ou "feat(login)!" → feat · login · !
    local formato='^([a-z]+)(\(([^)]+)\)|:([^!]+))?(!)?$'
    if ! [[ "$cab" =~ $formato ]]; then
        _err "tipo inválido: $cab" "use tipo ou tipo:escopo — ex.: gcm feat:login adiciona botão"
        return 1
    fi
    tipo="${BASH_REMATCH[1]}"; escopo="${BASH_REMATCH[3]:-${BASH_REMATCH[4]}}"; quebra="${BASH_REMATCH[5]}"

    local t valido=0
    for t in "${_GCM_TIPOS[@]}"; do [ "$t" = "$tipo" ] && valido=1; done
    if [ "$valido" -eq 0 ]; then
        _err "'$tipo' não é um tipo do Conventional Commits" "tipos: ${_GCM_TIPOS[*]}"
        return 1
    fi

    if [ -z "$desc" ]; then
        _err "falta a descrição do commit" "ex.: gcm $tipo${escopo:+:$escopo}$quebra adiciona botão de login"
        return 1
    fi

    _git commit -m "$tipo${escopo:+($escopo)}$quebra: $desc" || return 1
    _feito "◆" "commit criado"
    _resumo_commit
}

# _gcm_painel - o 'gcm' sem nada: cada tipo, quando usar e um exemplo (igual ao dev e ao help)
_gcm_painel() {
    local _LARG=10     # largura da coluna de nomes (o _linha e o _gcm_tipo enxergam)
    _cabecalho "CONVENTIONAL COMMITS"
    printf "  ${C_DIM}↳ formato: ${C_TEXT}tipo(escopo): descrição${C_DIM} · o escopo (opcional) é a parte do projeto${C_OFF}\n"

    _secao "tipos"
    _gcm_tipo feat     "novidade pra quem usa: tela, botão, rota de API, comando, opção" \
                       "feat(login): adiciona entrar com Google"
    _gcm_tipo fix      "corrige o que tava errado: bug, crash, conta, brecha de segurança" \
                       "fix(carrinho): corrige o total com cupom de desconto"
    _gcm_tipo docs     "só documentação: README, comentários, guias, exemplos, CHANGELOG" \
                       "docs(readme): explica a instalação no Windows"
    _gcm_tipo style    "só a forma do código: espaços, indentação, aspas, ponto e vírgula" \
                       "style: formata o projeto com o prettier" \
                       "mudou o visual da tela (CSS)? aí é feat ou fix"
    _gcm_tipo refactor "reorganiza sem mudar o que faz: renomeia, divide, move, simplifica" \
                       "refactor(api): separa as rotas em arquivos"
    _gcm_tipo perf     "mais rápido ou mais leve: cache, menos consultas, menos memória" \
                       "perf(busca): guarda os resultados em cache"
    _gcm_tipo test     "só testes: cria, corrige ou melhora, sem mexer no código testado" \
                       "test(login): cobre o caso de senha errada"
    _gcm_tipo build    "como o projeto é montado: dependências, versões, Docker, bundler" \
                       "build: atualiza o react para a versão 19"
    _gcm_tipo ci       "a automação de cada push: GitHub Actions, pipelines, deploy" \
                       "ci: roda os testes também no macOS"
    _gcm_tipo chore    "manutenção que não entra nas outras: .gitignore, configs, scripts" \
                       "chore: ignora a pasta dist no git" \
                       "na dúvida entre chore e outro tipo, use o outro"
    _gcm_tipo revert   "desfaz um commit anterior: diga na descrição qual foi" \
                       'revert: desfaz "feat(login): adiciona botão"'

    _secao "como usar"
    _LARG=30
    _linha "gcm fix corrige o frete"       "→ fix: corrige o frete"
    _linha "gcm feat:login adiciona botão" "→ feat(login): adiciona botão"
    _linha "gcm feat:api! muda as rotas"   "→ feat(api)!: muda as rotas"
    printf "\n"
    _dica "o ! avisa que quebra compatibilidade: quem usa vai precisar mudar algo"
    _dica "antes, ponha os arquivos no stage com ga ou gaa · aspas são opcionais"
    _dica "mudou coisas de tipos diferentes? faça um commit pra cada"
    printf "\n"
}

# _gcm_tipo nome "quando usar" "exemplo" ["observação"] - uma entrada do painel do gcm
_gcm_tipo() {
    _linha "$1" "$2"
    printf "  %*s ${C_DIM}↳ ex.: ${C_TEXT}%s${C_OFF}\n" "$_LARG" "" "$3"
    if [ -n "${4:-}" ]; then printf "  %*s ${C_DIM}↳ %s${C_OFF}\n" "$_LARG" "" "$4"; fi
}

# gamend - joga as mudanças atuais no último commit. Com mensagem, troca o texto dele
gamend() {
    _em_repo_git || return 1
    if ! git rev-parse -q --verify HEAD > /dev/null; then
        _err "ainda não existe commit pra emendar" "faça o primeiro com: gac \"mensagem\""
        return 1
    fi
    if [ $# -eq 0 ] && [ -z "$(git status --porcelain)" ]; then
        _err "nada pra emendar" "sem mudanças novas — pra só trocar a mensagem: gamend \"nova mensagem\""
        return 1
    fi

    local ja_enviado=0
    _ja_no_remoto && ja_enviado=1

    _git add --all || return 1
    if [ $# -eq 0 ]; then
        _git commit --amend --no-edit || return 1
    else
        _git commit --amend -m "$*" || return 1
    fi

    _feito "◆" "último commit atualizado"
    _resumo_commit
    if [ "$ja_enviado" -eq 1 ]; then
        _aviso "esse commit já estava no GitHub" "o próximo envio precisa ser: git push --force-with-lease"
    fi
}

# gundo - desfaz o último commit, mantém as alterações
gundo() {
    _em_repo_git || return 1
    if ! git rev-parse -q --verify HEAD~1 > /dev/null; then
        _err "não tem commit anterior pra voltar" "esse é o primeiro commit do repositório"
        return 1
    fi

    local hash msg ja_enviado=0
    hash=$(git rev-parse --short HEAD)
    msg=$(git log -1 --format=%s)
    _ja_no_remoto && ja_enviado=1

    _git reset --soft HEAD~1 || return 1
    _feito "↶" "commit desfeito" "$hash $msg"
    _dica "as mudanças voltaram pro stage — nada foi perdido"
    if [ "$ja_enviado" -eq 1 ]; then
        _aviso "esse commit já estava no GitHub" "se commitar de novo, o envio precisa ser: git push --force-with-lease"
    fi
}

# gwip - salva tudo num commit provisório "wip" (pra trocar de branch rápido)
gwip() {
    _em_repo_git || return 1
    if [ -z "$(git status --porcelain)" ]; then
        _ok "nada pra salvar" "árvore de trabalho limpa"
        return 0
    fi
    _git add --all || return 1
    _git commit --no-verify -m "wip: trabalho em andamento [skip ci]" || return 1
    _feito "◆" "trabalho salvo num commit wip" "$(git rev-parse --short HEAD)"
    _dica "pra continuar de onde parou: gunwip"
}

# gunwip - desfaz o commit wip: as mudanças voltam pros arquivos, como antes
gunwip() {
    _em_repo_git || return 1
    if [[ "$(git log -1 --format=%s 2> /dev/null)" != wip:* ]]; then
        _err "o último commit não é um wip" "nada foi mexido — veja com: gl"
        return 1
    fi
    _git reset HEAD~1 || return 1
    _feito "↶" "wip desfeito" "as mudanças estão de volta nos arquivos"
}

# grst - tira do stage (desfaz um ga). A mudança continua no arquivo
grst() {
    if [ $# -eq 0 ]; then
        _uso "grst <arquivo>" "tira do stage — a mudança continua no arquivo" "grst .   tira tudo"
        return 1
    fi
    _em_repo_git || return 1
    _git restore --staged -- "$@" || return 1
    _feito "−" "fora do stage" "$*"
    _dica "a mudança continua no arquivo, só não entra no próximo commit"
}

# grs - descarta as mudanças do arquivo (volta pro último commit). Pede confirmação
grs() {
    if [ $# -eq 0 ]; then
        _uso "grs <arquivo>" "joga fora as mudanças e volta o arquivo pro último commit"
        return 1
    fi
    _em_repo_git || return 1
    if ! _confirma "descartar as mudanças de $*? não tem volta"; then
        _cancelado
        return 0
    fi
    _git restore -- "$@" || return 1
    _feito "↶" "mudanças descartadas" "$*"
}

# gst - guarda as mudanças (inclusive arquivos novos) pra limpar a mesa
gst() {
    _em_repo_git || return 1
    local qtd
    qtd=$(( $(git status --porcelain | wc -l) ))
    if [ "$qtd" -eq 0 ]; then
        _ok "nada pra guardar" "árvore de trabalho limpa"
        return 0
    fi
    # -u inclui arquivos novos: sem ele, arquivo recém-criado fica pra trás
    if [ $# -gt 0 ]; then
        _git stash push -u -m "$*" || return 1
    else
        _git stash push -u || return 1
    fi
    _feito "▣" "$(_plural "$qtd" "arquivo guardado" "arquivos guardados")" "stash@{0}"
    _dica "recupere com: gstp"
}

# gstp - recupera o último stash
gstp() {
    _em_repo_git || return 1
    if [ -z "$(git stash list)" ]; then
        _err "nada guardado no stash" "guarde mudanças com: gst"
        return 1
    fi
    local desc
    desc=$(git stash list -1 --format=%s)
    if ! _git stash pop "$@"; then
        if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
            _dica "conflito! o stash continua salvo — resolva e depois rode: git stash drop"
        fi
        return 1
    fi
    _feito "↺" "mudanças recuperadas" "$desc"
}

# gsl - lista o que está guardado no stash
gsl() {
    _em_repo_git || return 1
    if [ -z "$(git stash list)" ]; then
        _ok "stash vazio" "nada guardado"
        return 0
    fi
    local ref quando msg
    printf "\n"
    while IFS=$'\t' read -r ref quando msg; do
        printf "  ${C_WARN}%-11s${C_OFF} ${C_DIM}%-15s${C_OFF} ${C_TEXT}%s${C_OFF}\n" "$ref" "$quando" "$msg"
    done < <(git stash list --format='%gd%x09%cr%x09%s')
    printf "\n"
}

# ---------- branches e remoto ----------

# gp - push. Branch nova é publicada sozinha na primeira vez
gp() {
    _em_repo_git || return 1
    local t0
    _us t0

    # Com argumentos (ex: gp origin main): repassa direto, sem mágica
    if [ $# -gt 0 ]; then
        _pendente "enviando..."
        _git push "$@" || return 1
        _feito "↑" "push feito" "$(_tempo_desde "$t0")"
        return 0
    fi

    local branch upstream="" qtd
    branch=$(git branch --show-current)
    if [ -z "$branch" ]; then
        _err "você não está em nenhuma branch (HEAD solto)" "entre numa com: gco <branch>"
        return 1
    fi

    # Só conta se a branch remota existir de verdade: num repositório
    # recém-clonado e ainda vazio, o upstream vem configurado mas não existe
    if git rev-parse -q --verify '@{upstream}' > /dev/null 2>&1; then
        upstream=$(git rev-parse --abbrev-ref '@{upstream}' 2> /dev/null)
    fi

    # Primeira vez da branch: publica e liga a local à remota (-u)
    if [ -z "$upstream" ]; then
        _pendente "publicando $branch..."
        if ! _git push -u origin "$branch"; then
            [[ $_GIT_SAIDA == *"'origin'"* ]] && _dica "conecte o repo ao GitHub: git remote add origin <url>"
            return 1
        fi
        _feito "↑" "branch publicada" "$branch → origin/$branch · $(_tempo_desde "$t0")"
        return 0
    fi

    qtd=$(git rev-list --count '@{upstream}..HEAD' 2> /dev/null)
    if [ "${qtd:-0}" -eq 0 ]; then
        _ok "nada pra enviar" "$branch já está igual a $upstream"
        return 0
    fi

    _pendente "enviando $(_plural "$qtd" commit commits)..."
    if ! _git push; then
        [[ $_GIT_SAIDA == *"rejected"* ]] && _dica "o remoto tem commits que você não tem — rode gpl e depois gp"
        return 1
    fi
    _feito "↑" "$(_plural "$qtd" "commit enviado" "commits enviados")" "$branch → $upstream · $(_tempo_desde "$t0")"
}

# gpl - pull com resumo do que chegou
gpl() {
    _em_repo_git || return 1
    local t0 antes depois
    _us t0
    antes=$(git rev-parse -q --verify HEAD)

    _pendente "buscando novidades..."
    # GIT_MERGE_AUTOEDIT=no: se o pull gerar merge, não abre editor no meio do caminho
    if ! GIT_MERGE_AUTOEDIT=no _git pull "$@"; then
        if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
            _dica "conflito! arrume os arquivos marcados e finalize com: gaa e gc \"merge\""
        elif [[ $_GIT_SAIDA == *"divergent"* ]]; then
            _dica "local e remoto divergiram. Configure uma vez: git config --global pull.rebase false"
        elif [[ $_GIT_SAIDA == *"no tracking information"* ]]; then
            _dica "essa branch ainda não existe no remoto — publique com: gp"
        fi
        return 1
    fi

    depois=$(git rev-parse -q --verify HEAD)
    if [ "$antes" = "$depois" ]; then
        _ok "já estava em dia" "nada novo no remoto · $(_tempo_desde "$t0")"
        return 0
    fi

    local qtd detalhe tempo arq ins del
    tempo=$(_tempo_desde "$t0")
    if [ -n "$antes" ]; then
        qtd=$(git rev-list --count "$antes..$depois")
        read -r arq ins del < <(_numeros_stat "$(LC_ALL=C git diff --shortstat "$antes" "$depois")")
        detalhe="$(_plural "$arq" arquivo arquivos) · +$ins −$del · $tempo"
    else
        qtd=$(git rev-list --count HEAD)
        detalhe="$tempo"
    fi
    _feito "↓" "$(_plural "$qtd" "commit recebido" "commits recebidos")" "$detalhe"
}

# gf - confere o remoto sem mexer em nada seu
gf() {
    _em_repo_git || return 1
    local t0 atras
    _us t0

    _pendente "conferindo o remoto..."
    _git fetch --prune "$@" || return 1

    atras=$(git rev-list --count 'HEAD..@{upstream}' 2> /dev/null)
    if [ -z "$atras" ]; then
        _ok "fetch feito" "esta branch ainda não está no remoto · $(_tempo_desde "$t0")"
    elif [ "$atras" -eq 0 ]; then
        _ok "tudo em dia" "nada novo no remoto · $(_tempo_desde "$t0")"
    else
        _feito "↓" "$(_plural "$atras" "commit novo" "commits novos") no remoto" "$(_tempo_desde "$t0")"
        _dica "traga com: gpl"
    fi
}

# gup [branch] - atualiza a branch principal (main) SEM sair da branch atual
# Bom antes de um gm main: você traz a main fresquinha do GitHub primeiro.
gup() {
    _em_repo_git || return 1
    local base atual antes depois qtd t0
    _us t0
    if ! base="${1:-$(_branch_padrao)}" || [ -z "$base" ]; then
        _err "não descobri a branch principal" "diga qual: gup main"
        return 1
    fi
    atual=$(git branch --show-current)
    if [ "$atual" = "$base" ]; then
        gpl
        return
    fi
    antes=$(git rev-parse -q --verify "refs/heads/$base")
    _pendente "atualizando $base..."
    # origin/main:main só avança a main local se for fast-forward: nunca perde commit seu
    if ! _git fetch origin "$base:$base"; then
        [[ $_GIT_SAIDA == *"non-fast-forward"* ]] && _dica "a $base local tem commits que o GitHub não tem — entre nela e rode gpl"
        return 1
    fi
    depois=$(git rev-parse -q --verify "refs/heads/$base")
    if [ "$antes" = "$depois" ]; then
        _ok "$base já estava em dia" "você continua na ${atual:-HEAD solto} · $(_tempo_desde "$t0")"
        return 0
    fi
    qtd=$(git rev-list --count "${antes:-$depois}..$depois" 2> /dev/null)
    _feito "↓" "$base atualizada" "$(_plural "${qtd:-0}" "commit novo" "commits novos") · você continua na ${atual:-HEAD solto}"
    _dica "trazer pra cá: gin $base (ver o que vem) · gm $base (trazer)"
}

# gco - troca de branch. Sem argumento: escolhe numa lista
gco() {
    _em_repo_git || return 1

    if [ $# -eq 0 ]; then
        if ! _tem fzf; then
            _uso "gco <branch>"
            return 1
        fi
        local escolhida
        escolhida=$(git branch --format='%(refname:short)' \
            | grep -vx -- "$(git branch --show-current)" \
            | fzf --prompt='branch ❯ ' --preview 'git log --oneline --color=always -15 {}')
        [ -z "$escolhida" ] && return 0
        set -- "$escolhida"
    fi

    local antes depois
    antes=$(git branch --show-current)
    if ! _git checkout "$@"; then
        [[ $_GIT_SAIDA == *"would be overwritten"* ]] && _dica "guarde as mudanças antes: gst → gco → gstp"
        return 1
    fi
    depois=$(git branch --show-current)

    if [ -n "$depois" ] && [ "$antes" != "$depois" ]; then
        _feito "⇄" "agora em $depois" "saiu de ${antes:-HEAD solto}"
    else
        _ok "checkout feito" "$*"
    fi
}

# gbr - branches da mais recente pra mais antiga, com o último commit de cada.
# No terminal abre a lista: Enter troca pra branch escolhida.
gbr() {
    _em_repo_git || return 1
    local formato='%(refname:short)%09%(committerdate:relative)%09%(subject)' atual
    atual=$(git branch --show-current)
    if [ -t 1 ] && _tem fzf; then
        local escolhida
        escolhida=$(git for-each-ref --sort=-committerdate refs/heads --format="$formato" \
            | fzf --delimiter=$'\t' --tabstop=24 --prompt='branch ❯ ' --header="você está na ${atual:-HEAD solto} · Enter troca" \
                  --preview 'git log --oneline --color=always -15 {1}')
        [ -z "$escolhida" ] && return 0
        gco "${escolhida%%$'\t'*}"
        return
    fi
    local nome quando assunto marca
    while IFS=$'\t' read -r nome quando assunto; do
        marca=" "; [ "$nome" = "$atual" ] && marca="*"
        printf "  ${C_OK}%s${C_OFF} ${C_WARN}%-24s${C_OFF} ${C_DIM}%-16s${C_OFF} ${C_TEXT}%s${C_OFF}\n" \
            "$marca" "$nome" "$quando" "$assunto"
    done < <(git for-each-ref --sort=-committerdate refs/heads --format="$formato")
}

# gcb - cria branch a partir da atual e já entra nela
gcb() {
    if [ -z "$1" ]; then
        _uso "gcb <nome-da-branch>" "cria a partir da branch atual e já entra nela"
        return 1
    fi
    _em_repo_git || return 1
    local origem
    origem=$(git branch --show-current)
    _git checkout -b "$@" || return 1
    _feito "🌿" "branch $1 criada" "a partir de ${origem:-HEAD} · você já está nela"
    _dica "publique quando quiser com: gp"
}

# gnew - cria branch local e já publica no remoto
gnew() {
    if [ -z "$1" ]; then
        _uso "gnew <nome-da-branch>" "cria, entra e já publica no remoto"
        return 1
    fi
    _em_repo_git || return 1

    local origem t0
    _us t0
    origem=$(git branch --show-current)

    _git checkout -b "$1" || return 1
    _feito "🌿" "branch $1 criada" "a partir de ${origem:-HEAD}"

    _pendente "publicando..."
    if ! _git push -u origin "$1"; then
        _dica "a branch local existe, só o envio falhou — publique depois com: gp"
        return 1
    fi
    _feito "↑" "publicada no remoto" "origin/$1 · $(_tempo_desde "$t0")"
}

# gin - mostra os commits que VÃO ENTRAR na branch atual se você der merge de outra.
# Bom costume: roda o gin antes do gm pra saber o que vem.
#   gin feature/x     → os commits da feature/x que a branch atual ainda não tem
#   gin origin/main   → também funciona com branch do GitHub (depois de um gf)
#   gin               → escolhe a branch numa lista, com a prévia dos commits
# Por baixo: git log HEAD..branch --oneline
#   HEAD..branch = "o que tem na branch e NÃO tem em mim (HEAD)"
gin() {
    _em_repo_git || return 1
    local alvo="$1" atual
    atual=$(git branch --show-current)
    atual="${atual:-HEAD}"                  # HEAD solto (sem branch): usa o commit atual

    if [ -z "$alvo" ]; then
        if ! _tem fzf; then
            _uso "gin <branch>" "mostra os commits que entram na $atual com um merge"
            return 1
        fi
        # Branches locais e do GitHub, menos a atual e o "origin/HEAD" (é só um apelido)
        alvo=$(git for-each-ref --format='%(refname)' refs/heads refs/remotes 2> /dev/null \
            | grep -v '/HEAD$' \
            | sed 's#^refs/heads/##; s#^refs/remotes/##' \
            | grep -vx -- "$atual" \
            | fzf --height=60% --reverse --border=rounded --prompt="entra na $atual ❯ " \
                  --header='a prévia mostra os commits que entrariam' \
                  --preview "git log --oneline --color=always HEAD..{} | head -50; [ -z \"\$(git rev-list -1 HEAD..{})\" ] && echo 'nada novo: $atual já tem tudo'")
        [ -z "$alvo" ] && return 0          # Esc: cancelou
    fi

    if ! git rev-parse -q --verify "${alvo}^{commit}" > /dev/null; then
        _err "branch '$alvo' não existe" "veja as locais com: gb  ·  as do GitHub: git branch -r"
        return 1
    fi

    local qtd
    qtd=$(git rev-list --count "HEAD..$alvo")
    if [ "$qtd" -eq 0 ]; then
        _ok "nada novo pra entrar" "$atual já tem tudo de $alvo"
        return 0
    fi

    # Resumo do código que vem junto (três pontos = só o que mudou na outra branch)
    local arq ins del
    read -r arq ins del < <(_numeros_stat "$(LC_ALL=C git diff --shortstat "HEAD...$alvo" 2> /dev/null)")

    _titulo "⇉" "$(_plural "$qtd" "commit entra" "commits entram") na $atual" \
        "vindo de $alvo · $(_plural "$arq" arquivo arquivos) · +$ins −$del"
    git --no-pager log --oneline --color=always -30 "HEAD..$alvo" | sed 's/^/     /'
    (( qtd > 30 )) && _dica "… e mais $((qtd - 30)). Lista inteira: git log HEAD..$alvo --oneline"
    _dica "ver o código que vem: git diff HEAD...$alvo  ·  trazer: gm $alvo"
}

# gm - traz os commits de outra branch pra atual (merge)
gm() {
    if [ -z "$1" ]; then
        _uso "gm <branch>" "traz os commits da <branch> pra branch atual"
        return 1
    fi
    _em_repo_git || return 1

    local atual qtd
    atual=$(git branch --show-current)
    qtd=$(git rev-list --count "HEAD..$1" 2> /dev/null)
    if [ -z "$qtd" ]; then
        _err "branch '$1' não existe" "veja as branches com: gb"
        return 1
    fi
    if [ "$qtd" -eq 0 ]; then
        _ok "nada pra trazer" "$atual já tem tudo de $1"
        return 0
    fi

    if ! GIT_MERGE_AUTOEDIT=no _git merge "$1"; then
        if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
            _dica "conflito! arrume os arquivos marcados e finalize com: gaa e gc \"merge $1\""
            _dica "pra desistir do merge: git merge --abort"
        fi
        return 1
    fi
    _feito "⇉" "merge feito" "$1 → $atual · $(_plural "$qtd" commit commits)"
}

# gbd - apaga branch local (só se já foi mergeada — o git protege)
gbd() {
    if [ -z "$1" ]; then
        _uso "gbd <branch>" "apaga a branch local"
        return 1
    fi
    _em_repo_git || return 1
    if [ "$1" = "$(git branch --show-current)" ]; then
        _err "não dá pra apagar a branch onde você está" "troque antes com: gco <outra-branch>"
        return 1
    fi
    if ! _git branch -d "$1"; then
        [[ $_GIT_SAIDA == *"not fully merged"* ]] && _dica "ela tem commits que não foram mergeados. Tem certeza? git branch -D $1"
        return 1
    fi
    _feito "−" "branch $1 apagada"
}

# gclean - remove branches locais já mergeadas (com confirmação)
gclean() {
    _em_repo_git || return 1

    # ^...$ compara o nome INTEIRO: antes, 'fix-main-menu' também escapava
    local branches
    branches=$(git branch --merged | grep -vE '^\*|^\+|^[[:space:]]*(main|master|develop)$' | sed 's/^[[:space:]]*//')

    if [ -z "$branches" ]; then
        _ok "nada pra limpar" "nenhuma branch mergeada sobrando"
        return 0
    fi

    local total b
    total=$(( $(printf '%s\n' "$branches" | wc -l) ))

    _titulo "🧹" "branches já mergeadas"
    while read -r b; do
        printf "     ${C_DIM}•${C_OFF} ${C_TEXT}%s${C_OFF}\n" "$b"
    done <<< "$branches"

    if _confirma "apagar $(_plural "$total" branch branches)?"; then
        printf '%s\n' "$branches" | xargs git branch -d > /dev/null 2>&1
        _ok "$(_plural "$total" "branch apagada" "branches apagadas")"
    else
        _cancelado
    fi
}

# gcl - clona e já entra na pasta
gcl() {
    if [ -z "$1" ]; then
        _uso "gcl <url> [pasta]" "clona o repositório e já entra nele"
        return 1
    fi

    local url="$1" pasta t0
    _us t0
    pasta="${2:-$(basename "${url%.git}")}"

    if [ -e "$pasta" ]; then
        _err "já existe '$pasta' aqui" "escolha outro nome: gcl <url> <pasta>"
        return 1
    fi

    _pendente "clonando $pasta..."
    _git clone "$url" "$pasta" || return 1
    builtin cd "$pasta" || return 1
    _feito "↓" "clonado" "$pasta · $(_plural "$(( $(git ls-files | wc -l) ))" arquivo arquivos) · $(_tempo_desde "$t0")"
}

# hub - abre o repositório atual no navegador
hub() {
    _em_repo_git || return 1
    local url
    url=$(_url_remoto) || return 1
    _abrir "$url"
    _feito "🔗" "abrindo no navegador" "$url"
}

# gpr [base] - abre a página de criar Pull Request da branch atual
# (GitHub e GitLab). Branch ainda não publicada é publicada antes (gp).
gpr() {
    _em_repo_git || return 1
    local url branch base link
    url=$(_url_remoto) || return 1
    branch=$(git branch --show-current)
    if [ -z "$branch" ]; then
        _err "você não está em nenhuma branch (HEAD solto)" "entre numa com: gco <branch>"
        return 1
    fi
    base="${1:-$(_branch_padrao)}"
    base="${base:-main}"
    if [ "$branch" = "$base" ]; then
        _err "você está na $base: o PR sai de outra branch" "crie uma com: gcb nome-da-mudanca"
        return 1
    fi
    if ! git rev-parse -q --verify '@{upstream}' > /dev/null 2>&1; then
        _aviso "a branch ainda não está no remoto" "publicando antes com o gp…"
        gp || return 1
    fi
    case "$url" in
        *gitlab*) link="$url/-/merge_requests/new?merge_request%5Bsource_branch%5D=$branch&merge_request%5Btarget_branch%5D=$base" ;;
        *)        link="$url/compare/$base...$branch?expand=1" ;;
    esac
    _abrir "$link"
    _feito "🔗" "abrindo o pull request no navegador" "$branch → $base"
}
