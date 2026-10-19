# shellcheck shell=bash disable=SC2088
# ==========================================
# Casos de teste — rodam DENTRO do shell testado (bash ou zsh), depois do
# ~/.bashrc / ~/.zshrc carregado. Chamado pelo tests/rodar.sh.
# ==========================================

T_OK=0
T_FALHA=0
T_LOG="$T_SANDBOX/saida.log"
: > "$T_LOG"

# ---------- mini framework ----------

_t_passou() { T_OK=$(( T_OK + 1 )); printf '  ✓ %s\n' "$1"; }
_t_falhou() {
    T_FALHA=$(( T_FALHA + 1 ))
    printf '  ✗ %s\n' "$1"
    [ -n "${2:-}" ] && printf '      %s\n' "$2"
    printf '### FALHOU: %s\n%s\n' "$1" "${2:-}" >> "$T_LOG"
}

# _t "nome" comando... — passa se o comando der certo (saída vai pro log)
_t() {
    local nome="$1"; shift
    if "$@" >> "$T_LOG" 2>&1; then _t_passou "$nome"; else _t_falhou "$nome" "comando falhou: $*"; fi
}
# _t_nao "nome" comando... — passa se o comando FALHAR
_t_nao() {
    local nome="$1"; shift
    if "$@" >> "$T_LOG" 2>&1; then _t_falhou "$nome" "devia falhar: $*"; else _t_passou "$nome"; fi
}
# _t_eq "nome" "esperado" "obtido"
_t_eq() {
    if [ "$2" = "$3" ]; then _t_passou "$1"; else _t_falhou "$1" "esperado [$2], veio [$3]"; fi
}
# _t_tem "nome" "trecho" "texto"
_t_tem() {
    case "$3" in
        *"$2"*) _t_passou "$1" ;;
        *)      _t_falhou "$1" "não achei [$2] em: $(printf '%s' "$3" | head -c 400)" ;;
    esac
}
# _t_nao_tem "nome" "trecho" "texto"
_t_nao_tem() {
    case "$3" in
        *"$2"*) _t_falhou "$1" "não devia ter [$2] em: $(printf '%s' "$3" | head -c 400)" ;;
        *)      _t_passou "$1" ;;
    esac
}
# _t_limpo - tira cores e \r da saída (pra comparar texto)
_t_limpo() { sed "s/$(printf '\033')\[[0-9;?]*[a-zA-Z]//g" | tr -d '\r'; }
_t_secao() { printf '\n▸ %s\n' "$1"; }

# ==========================================
_t_secao "plataforma e helpers"
# ==========================================
_t_eq "_SHELL detectado" "$T_SHELL" "$_SHELL"
_t "_SO conhecido" test -n "$_SO"
_t "_tem acha o git" _tem git
_t_nao "_tem não acha programa inexistente" _tem programa-que-nao-existe-xyz
_t_eq "_humano 0" "0B" "$(_humano 0)"
_t_eq "_humano 1023" "1023B" "$(_humano 1023)"
_t_eq "_humano 1536" "1.5K" "$(_humano 1536)"
_t_eq "_humano 10M" "10M" "$(_humano 10485760)"
_t_eq "_humano 1G" "1.0G" "$(_humano 1073741824)"
_t_eq "_humano negativo" "-2.0K" "$(_humano -2048)"
_t_eq "_plural 1" "1 commit" "$(_plural 1 commit commits)"
_t_eq "_plural 3" "3 commits" "$(_plural 3 commit commits)"
_t_eq "_curto home" "~/x/y" "$(_curto "$HOME/x/y")"
_t_eq "_curto fora" "/etc" "$(_curto /etc)"
_t_eq "_pad conta letras (não bytes)" "[ção  ]" "[$(_pad ção 5)]"
_t_eq "_barra metade" "█████░░░░░" "$(_barra 5 10 10 | _t_limpo)"
_us t_a
_t "_us dá número" test "$t_a" -gt 1000000000000000
_t_tem "_tempo_desde em ms" "ms" "$(_tempo_desde "$t_a")"
_t_eq "_data epoch 0 (UTC)" "01/01/1970" "$(_data '%d/%m/%Y' 0)"
_data_var t_d '%Y' 0
_t_eq "_data_var" "1970" "$t_d"
_t "_livre_bytes > 0" test "$(_livre_bytes /)" -gt 0
mkdir -p "$T_SANDBOX/tam" && printf '%01024d' 0 > "$T_SANDBOX/tam/a"
_t "_tam_bytes mede" test "$(_tam_bytes "$T_SANDBOX/tam")" -ge 1024
ln -sf "$T_SANDBOX/tam/a" "$T_SANDBOX/link"
_t_eq "_caminho_real segue atalho" "$(builtin cd -P "$T_SANDBOX/tam" && pwd)/a" "$(_caminho_real "$T_SANDBOX/link")"
_t_tem "_cmd_instalar fd" "fd" "$(_cmd_instalar fd)"

# ==========================================
_t_secao "UI e animação"
# ==========================================
saida=$(_ok "tudo certo" "detalhe" | _t_limpo)
_t_tem "_ok" "✓  tudo certo   detalhe" "$saida"
saida=$(_err "deu ruim" "faz assim" 2>&1 | _t_limpo)
_t_tem "_err mensagem" "✗  deu ruim" "$saida"
_t_tem "_err dica" "↳ faz assim" "$saida"
_t_nao "_err retorna 1" _err x
saida=$(_rodar "tarefa ok" true 2>&1 | _t_limpo)
_t_tem "_rodar sucesso" "✓  tarefa ok" "$saida"
saida=$(_rodar "tarefa ruim" sh -c 'echo motivo-do-erro; exit 3' 2>&1 | _t_limpo)
_t_tem "_rodar falha mostra a saída" "motivo-do-erro" "$saida"
_t_tem "_rodar falha mostra o código" "código 3" "$saida"
_rodar -q "silencioso" sh -c 'echo capturado' > /dev/null 2>&1
_t_eq "_rodar guarda a saída" "capturado" "$_RODAR_SAIDA"
_t_nao "_rodar devolve o código" _rodar "x" false
_t "_contagem termina" _contagem 1 "teste"
_t_eq "_confirma s" "sim" "$(_confirma "ok?" <<< s > /dev/null && echo sim)"
_t_eq "_confirma vazio = não" "nao" "$(_confirma "ok?" <<< '' > /dev/null || echo nao)"

# ==========================================
_t_secao "carregamento sob demanda"
# ==========================================
_t "índice de cascas existe" test -s "$DOTFILES_CACHE/indice.$_SHELL.sh"
_t_tem "gs começa como casca" "_df_sob_demanda" "$(typeset -f gs 2> /dev/null || declare -f gs)"
_t_nao_tem "git ainda não carregou" " git " " $_DF_CARREGADOS "
_df_carregar_modulo git
_t_tem "módulo git carregou" " git" "$_DF_CARREGADOS"
_t_tem "gs virou a função de verdade" "git status" "$(typeset -f gs 2> /dev/null || declare -f gs)"
_t "carregar 2x não quebra" _df_carregar_modulo git
for t_m in navegacao utilitarios node docker rede sistema energia paineis erros; do
    _t "módulo $t_m carrega" _df_carregar_modulo "$t_m"
done
_t_nao "módulo inexistente avisa" _df_carregar_modulo modulo-que-nao-existe

# ==========================================
_t_secao "navegação e arquivos"
# ==========================================
t_volta="$PWD"
builtin cd "$T_SANDBOX" || exit 1
mkcd "a/b/c" > /dev/null
_t_eq "mkcd cria e entra" "$T_SANDBOX/a/b/c" "$PWD"
up 2 > /dev/null
_t_eq "up 2" "$T_SANDBOX/a" "$PWD"
_t_nao "up com letra = uso" up x
_t_nao "mkcd sem nome = uso" mkcd
builtin cd "$T_SANDBOX" || exit 1
printf 'conteudo\n' > nota.txt
bak nota.txt > /dev/null
t_baks=(nota.txt.bak-*)
_t "bak cria cópia" test -f "${t_baks[0]}"
mkdir -p pacote/sub && printf 'x\n' > pacote/sub/arq.txt
compactar pacote > /dev/null 2>&1
_t "compactar tar.gz" test -f pacote.tar.gz
_t_nao "compactar não sobrescreve" compactar pacote
mkdir -p ext && builtin cd ext || exit 1
extract ../pacote.tar.gz > /dev/null 2>&1
_t "extract tar.gz" test -f pacote/sub/arq.txt
builtin cd "$T_SANDBOX" || exit 1
if _tem zip && _tem unzip; then
    compactar pacote zip > /dev/null 2>&1
    _t "compactar zip" test -f pacote.zip
    mkdir -p ext2 && builtin cd ext2 && extract ../pacote.zip > /dev/null 2>&1
    _t "extract zip" test -f pacote/sub/arq.txt
    builtin cd "$T_SANDBOX" || exit 1
fi
_t_nao "extract formato desconhecido" extract nota.txt
_t_nao "extract arquivo que não existe" extract nada.zip
printf 'tchau\n' > apagar.txt
XDG_DATA_HOME="$T_SANDBOX/xdg" lixo apagar.txt > /dev/null 2>&1
_t "lixo tira o arquivo daqui" test ! -e apagar.txt
saida=$(espaco "$T_SANDBOX" 2>&1 | _t_limpo)
_t_tem "espaco lista os maiores" "o que mais ocupa" "$saida"
git init -q repo-cdr && mkdir -p repo-cdr/x/y && builtin cd repo-cdr/x/y && cdr > /dev/null
_t_eq "cdr volta pra raiz do repo" "$(builtin cd -P "$T_SANDBOX/repo-cdr" && pwd)" "$(pwd -P)"
builtin cd "$T_SANDBOX" || exit 1
_t_nao "open de arquivo que não existe" open nao-existe.txt
_t "open de arquivo existente" open nota.txt
sleep 0.5                                                   # o app abre solto do terminal: dá um tempo
_t_tem "open chamou o sistema" "nota.txt" "$(cat "$STUB_LOG" 2> /dev/null)"

# ==========================================
_t_secao "utilitários"
# ==========================================
_t_eq "calc inteiro" "14" "$(calc '2+3*4')"
_t_eq "calc decimal" "2.5" "$(calc 10/4)"
_t_eq "calc vírgula" "3" "$(calc '1,5*2')"
_t_nao "calc recusa letras" calc 'system(1)'
_t_eq "epoch 0" "01/01/1970 00:00:00" "$(epoch 0)"
_t_eq "epoch em milissegundos" "14/11/2023 22:13:20" "$(epoch 1700000000000)"
_t_eq "b64" "b2k=" "$(b64 oi)"
_t_eq "b64d" "oi" "$(b64d b2k= | tr -d '\n')"
_t_eq "senha tem o tamanho pedido" "24" "$(senha 24 | head -n 1 | tr -d '\n' | wc -c | tr -d ' ')"
_t_nao "senha curta demais" senha 4
saida=$(uuid | head -n 1)
t_re='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
if [[ "$saida" =~ $t_re ]]; then _t_passou "uuid formato v4"; else _t_falhou "uuid formato v4" "$saida"; fi
printf '# comentário\nexport A_TESTE="com aspas"\nB_TESTE=simples\nINVALIDO LINHA\nC_TESTE='"'"'x y'"'"'\n' > "$T_SANDBOX/.env"
loadenv "$T_SANDBOX/.env" > /dev/null
_t_eq "loadenv tira aspas duplas" "com aspas" "${A_TESTE:-}"
_t_eq "loadenv simples" "simples" "${B_TESTE:-}"
_t_eq "loadenv aspas simples" "x y" "${C_TESTE:-}"
printf '{"a":[1,2]}' > "$T_SANDBOX/x.json"
if _tem jq || _tem python3; then _t "json formata" json "$T_SANDBOX/x.json"; fi
printf '{quebrado' > "$T_SANDBOX/ruim.json"
if _tem jq || _tem python3; then _t_nao "json inválido avisa" json "$T_SANDBOX/ruim.json"; fi
builtin cd "$T_SANDBOX" || exit 1
mkscript ola.sh > /dev/null
_t "mkscript executável" test -x ola.sh
_t_eq "mkscript roda" "ok" "$(./ola.sh)"
_t_nao "mkscript não sobrescreve" mkscript ola.sh

# ==========================================
_t_secao "git"
# ==========================================
builtin cd "$T_SANDBOX" || exit 1
git init -q --bare remoto.git
git init -q proj && builtin cd proj || exit 1
git remote add origin "$T_SANDBOX/remoto.git"
_t_nao "gc sem stage avisa" gc teste
printf 'um\n' > a.txt
saida=$(ga a.txt 2>&1 | _t_limpo)
_t_tem "ga adiciona" "adicionado ao stage" "$saida"
saida=$(gc primeiro commit 2>&1 | _t_limpo)
_t_tem "gc cria commit" "commit criado" "$saida"
_t_eq "gc junta a mensagem sem aspas" "primeiro commit" "$(git log -1 --format=%s)"
_t_eq "_branch_rapido lê a branch" "main" "$(_branch_rapido && printf '%s' "$REPLY")"
mkdir -p sub/dir && builtin cd sub/dir || exit 1
_t_eq "_branch_rapido de subpasta" "main" "$(_branch_rapido && printf '%s' "$REPLY")"
builtin cd ../.. || exit 1
saida=$(gp 2>&1 | _t_limpo)
_t_tem "gp publica branch nova" "branch publicada" "$saida"
saida=$(gp 2>&1 | _t_limpo)
_t_tem "gp sem nada novo" "nada pra enviar" "$saida"
printf 'dois\n' >> a.txt
printf 'novo\n' > b.txt
saida=$(gac segundo 2>&1 | _t_limpo)
_t_tem "gac" "commit criado" "$saida"
_t_eq "gac incluiu arquivo novo" "b.txt" "$(git show --name-only --format= HEAD | grep b.txt)"
printf 'tres\n' >> a.txt
_t_nao "gcm sem stage avisa" gcm feat:login adiciona botão
git add a.txt
gcm feat:login adiciona botão > /dev/null 2>&1
_t_eq "gcm feat:escopo" "feat(login): adiciona botão" "$(git log -1 --format=%s)"
printf 'quatro\n' >> a.txt && git add a.txt
gcm fix corrige conta > /dev/null 2>&1
_t_eq "gcm sem escopo" "fix: corrige conta" "$(git log -1 --format=%s)"
printf 'cinco\n' >> a.txt && git add a.txt
gcm 'refactor(api)!' muda rota > /dev/null 2>&1
_t_eq "gcm com parênteses e !" "refactor(api)!: muda rota" "$(git log -1 --format=%s)"
printf 'seis\n' >> a.txt && git add a.txt
_t_nao "gcm tipo inválido" gcm bobagem texto
_t_nao "gcm sem descrição avisa" gcm feat:login
saida=$(builtin cd / && gcm 2>&1 | _t_limpo)
t_faltam=""
for t_t in "${_GCM_TIPOS[@]}"; do [[ "$saida" == *"  $t_t "* ]] || t_faltam+=" $t_t"; done
_t_eq "gcm sem nada lista os tipos (até fora de um repo)" "" "$t_faltam"
_t_tem "gcm sem nada dá exemplo de cada um" "ex.: feat(login)" "$saida"
git reset -q a.txt && git checkout -q -- a.txt
gundo > /dev/null 2>&1
_t_eq "gundo desfaz e mantém no stage" "M  a.txt" "$(git status --porcelain | grep a.txt)"
gamend > /dev/null 2>&1
_t_eq "gamend emenda no último" "fix: corrige conta" "$(git log -1 --format=%s)"
gamend nova mensagem > /dev/null 2>&1
_t_eq "gamend troca a mensagem" "nova mensagem" "$(git log -1 --format=%s)"
printf 'sujo\n' >> a.txt
gst guardado > /dev/null 2>&1
_t_eq "gst limpa a árvore" "" "$(git status --porcelain)"
_t_tem "gsl lista" "guardado" "$(gsl 2>&1)"
gstp > /dev/null 2>&1
_t_tem "gstp devolve" "a.txt" "$(git status --porcelain)"
grs a.txt <<< s > /dev/null 2>&1
_t_eq "grs descarta (com confirmação)" "" "$(git status --porcelain)"
printf 'x\n' > c.txt && git add c.txt
grst c.txt > /dev/null 2>&1
_t_eq "grst tira do stage" "?? c.txt" "$(git status --porcelain)"
command rm -f c.txt
gwip > /dev/null 2>&1
_t_eq "gwip sem mudança não commita" "nova mensagem" "$(git log -1 --format=%s)"
printf 'wip\n' > w.txt
gwip > /dev/null 2>&1
_t_tem "gwip commita" "wip:" "$(git log -1 --format=%s)"
gunwip > /dev/null 2>&1
_t_eq "gunwip devolve pros arquivos" "?? w.txt" "$(git status --porcelain)"
command rm -f w.txt
gcb feature/x > /dev/null 2>&1
_t_eq "gcb cria e entra" "feature/x" "$(git branch --show-current)"
printf 'feature\n' > f.txt && git add f.txt && git commit -qm "feat: arquivo da feature"
gco main > /dev/null 2>&1
_t_eq "gco troca" "main" "$(git branch --show-current)"
saida=$(gin feature/x 2>&1 | _t_limpo)
_t_tem "gin mostra o que entra" "1 commit entra na main" "$saida"
gm feature/x > /dev/null 2>&1
_t "gm traz o commit" test -f f.txt
_t_tem "gin depois do merge" "nada novo" "$(gin feature/x 2>&1)"
_t_nao "gbd na branch atual" gbd main
gbd feature/x > /dev/null 2>&1
_t_nao_tem "gbd apaga" "feature/x" "$(git branch)"
git branch velha-1 && git branch velha-2
gclean <<< s > /dev/null 2>&1
_t_nao_tem "gclean apaga as mergeadas" "velha" "$(git branch)"
_t_eq "gclean não toca na main" "main" "$(git branch --format='%(refname:short)' | grep -x main)"
# mergeada aqui, mas o upstream no remoto é outra história: o 'git branch -d' recusa essa
git checkout -qb t-up && printf 'x\n' > up.txt && git add up.txt && git commit -qm up1
git push -qu origin t-up > /dev/null 2>&1
printf 'y\n' >> up.txt && git commit -qam up2
git checkout -q main && git merge -q --no-ff --no-edit t-up
saida=$(gclean <<< s 2>&1 | _t_limpo)
_t_nao_tem "gclean apaga mergeada com upstream atrasado" "t-up" "$(git branch)"
_t_tem "gclean conta o que apagou de verdade" "1 branch apagada" "$saida"
gp > /dev/null 2>&1
saida=$(gf 2>&1 | _t_limpo)
_t_tem "gf em dia" "tudo em dia" "$saida"
saida=$(gpl 2>&1 | _t_limpo)
_t_tem "gpl em dia" "já estava em dia" "$saida"
# outro clone empurra um commit: gpl tem que trazer
git clone -q "$T_SANDBOX/remoto.git" "$T_SANDBOX/outro" 2> /dev/null
( builtin cd "$T_SANDBOX/outro" && printf 'remoto\n' > r.txt && git add r.txt && git commit -qm "feat: do remoto" && git push -q 2> /dev/null )
saida=$(gf 2>&1 | _t_limpo)
_t_tem "gf vê commit novo" "1 commit novo no remoto" "$saida"
saida=$(gpl 2>&1 | _t_limpo)
_t_tem "gpl recebe" "1 commit recebido" "$saida"
git checkout -q -b topico
( builtin cd "$T_SANDBOX/outro" && printf 'mais\n' >> r.txt && git commit -qam "fix: mais um" && git push -q 2> /dev/null )
saida=$(gup 2>&1 | _t_limpo)
_t_tem "gup atualiza a main sem sair da branch" "main atualizada" "$saida"
_t_eq "gup não troca de branch" "topico" "$(git branch --show-current)"
git checkout -q main
git remote set-url origin git@github.com:fulano/projeto.git
_t_eq "_url_remoto converte ssh" "https://github.com/fulano/projeto" "$(_url_remoto)"
git remote set-url origin ssh://git@gitlab.com/fulano/projeto.git
_t_eq "_url_remoto ssh://" "https://gitlab.com/fulano/projeto" "$(_url_remoto)"
git remote set-url origin "$T_SANDBOX/remoto.git"
_t_eq "_branch_padrao" "main" "$(_branch_padrao)"
git checkout -q --detach HEAD
_t_eq "_branch_rapido em HEAD solto mostra o hash" "$(git rev-parse --short=7 HEAD)" "$(_branch_rapido && printf '%s' "$REPLY")"
git checkout -q main
git worktree add -q "$T_SANDBOX/wt" -b arvore 2> /dev/null
( builtin cd "$T_SANDBOX/wt" && _branch_rapido && printf '%s' "$REPLY" ) > "$T_SANDBOX/wt.txt"
_t_eq "_branch_rapido em worktree" "arvore" "$(cat "$T_SANDBOX/wt.txt")"
builtin cd "$T_SANDBOX" || exit 1
_t_nao "gs fora de repo avisa" gs
_t_nao_tem "fora de repo sem branch" "x" "$(_branch_rapido && printf x)"

# ==========================================
_t_secao "node"
# ==========================================
mkdir -p "$T_SANDBOX/Minha Pizzaria Ç" && builtin cd "$T_SANDBOX/Minha Pizzaria Ç" || exit 1
_t_nao "ni fora de projeto avisa" ni
npkg > /dev/null 2>&1
_t "npkg cria package.json" test -f package.json
_t_tem "npkg normaliza o nome" '"name": "minha-pizzaria-c"' "$(command cat package.json)"
if _tem python3; then
    _t "package.json é JSON válido" python3 -c 'import json,sys; json.load(open("package.json"))'
fi
_t_nao "npkg não sobrescreve" npkg
_t_eq "_pm padrão é npm" "npm" "$(_pm)"
: > yarn.lock
if _tem yarn; then _t_eq "_pm com yarn.lock" "yarn" "$(_pm)"; else _t_eq "_pm com yarn.lock sem yarn instalado" "npm" "$(_pm)"; fi
mkdir -p src/deep && builtin cd src/deep || exit 1
_t_eq "_raiz_node sobe as pastas" "$T_SANDBOX/Minha Pizzaria Ç" "$(_raiz_node)"
_t_eq "_nome_npm" "meu-app-legal" "$(_nome_npm '  Meu App   Legal ')"
_t_eq "_json_txt escapa" 'a\"b\\c' "$(_json_txt 'a"b\c')"
builtin cd "$T_SANDBOX" || exit 1

# ==========================================
_t_secao "processos, portas e rede"
# ==========================================
_t_eq "_ms" "123" "$(_ms 0.123456)"
_t_eq "_ms segundos" "2005" "$(_ms 2.005)"
_t_nao "port sem número = uso" port
_t_nao "serve com porta inválida" serve abc
_t_nao "waitport sem alvo = uso" waitport
if _tem python3 && { _tem ss || _tem lsof; }; then
    t_porta=$(( 20000 + RANDOM % 20000 ))
    saida=$(port "$t_porta" 2>&1 | _t_limpo)
    _t_tem "port livre" "porta $t_porta livre" "$saida"
    # O http.server faz bind, depois um getfqdn (DNS reverso) e só então listen: no macOS
    # do CI esse DNS leva ~30s e a porta fica presa sem aceitar conexão. Aqui o getfqdn sai.
    t_srv='import http.server as h, socketserver as s, sys
class S(h.HTTPServer):
    def server_bind(self):
        s.TCPServer.server_bind(self)
        self.server_name, self.server_port = "localhost", self.server_address[1]
S(("127.0.0.1", int(sys.argv[1])), h.SimpleHTTPRequestHandler).serve_forever()'
    (python3 -c "$t_srv" "$t_porta" < /dev/null > /dev/null 2>&1 &)
    waitport "127.0.0.1:$t_porta" 10 > /dev/null 2>&1
    _t "waitport espera o servidor subir" _porta_aberta 127.0.0.1 "$t_porta"
    saida=$(port "$t_porta" 2>&1 | _t_limpo)
    _t_tem "port ocupada" "porta $t_porta ocupada" "$saida"
    _t_tem "portas lista a porta" "$t_porta" "$(portas 2>&1)"
    if _tem curl; then
        saida=$(httpcheck "http://127.0.0.1:$t_porta/" 2>&1 | _t_limpo)
        _t_tem "httpcheck HTTP 200" "HTTP 200" "$saida"
    fi
    _t_nao "serve recusa porta ocupada" serve "$t_porta"
    port -k "$t_porta" > /dev/null 2>&1
    sleep 0.5
    _t_nao "port -k libera" _porta_aberta 127.0.0.1 "$t_porta"
    _t_nao "waitport desiste no limite" waitport "127.0.0.1:$t_porta" 1
fi
_t_tem "psg acha o próprio shell" "$T_SHELL" "$(psg "$T_SHELL" 2>&1)"
_t_tem "topmem lista" "PROCESSO" "$(topmem 3 2>&1)"
_t_tem "topcpu lista" "PROCESSO" "$(topcpu 3 2>&1)"

# ==========================================
_t_secao "docker (com o daemon parado)"
# ==========================================
saida=$(dps 2>&1 | _t_limpo)
_t_tem "dps explica que o docker não está rodando" "docker" "$saida"
_t_nao "dps retorna erro" dps
_t_eq "dc acha o compose" "docker compose" "$(_DF_COMPOSE=''; dc version > /dev/null 2>&1; printf '%s' "$_DF_COMPOSE")"

# ==========================================
_t_secao "sistema"
# ==========================================
_df_carregar_modulo sistema
_limpa_tmp() { printf 'limpa-tmp\n' >> "$STUB_LOG"; }        # nos testes não mexe no /tmp de verdade
_limpa_miniaturas() { printf 'limpa-miniaturas\n' >> "$STUB_LOG"; }
: > "$STUB_LOG"
saida=$(clean -n 2>&1 | _t_limpo)
_t_tem "clean -n simula" "SÓ SIMULANDO" "$saida"
_t_tem "clean -n mostra o total" "Dá pra liberar" "$saida"
_t_nao_tem "clean -n não apaga nada" "autoremove" "$(cat "$STUB_LOG")"
saida=$(clean 2>&1 | _t_limpo)
_t_tem "clean roda as etapas" "LIMPEZA GERAL" "$saida"
_t_tem "clean tem relatório" "Levou" "$saida"
_t_tem "clean chamou o apt" "apt-get autoremove --purge -y" "$(cat "$STUB_LOG")"
_t_tem "clean chamou o journal" "journalctl --vacuum-time=7d" "$(cat "$STUB_LOG")"
_t_tem "clean removeu versão velha do snap" "snap remove core --revision=100" "$(cat "$STUB_LOG")"
_t "clean anotou no log de manutenção" test -s "$DOTFILES_ESTADO/manutencao.log"
_t_nao "clean com opção errada = uso" clean --bobagem
: > "$STUB_LOG"
if [ "$_PKG" = apt ]; then
    rmpkg pacote-teste > /dev/null 2>&1
    _t_tem "rmpkg usa apt purge" "apt purge pacote-teste -y" "$(cat "$STUB_LOG")"
    saida=$(upgrade 2>&1 | _t_limpo)
    _t_tem "upgrade roda" "sistema atualizado" "$saida"
fi
_t_nao "timebox com letra = uso" timebox abc
_t_nao "rmpkg sem nome = uso" rmpkg
bkp > /dev/null 2>&1
t_bkps=("$HOME"/dotfiles-backup/*/.bashrc)
_t "bkp copia o .bashrc" test -f "${t_bkps[0]}"
_t_tem "alias alert existe" "_alerta" "$(alias alert)"

# ==========================================
_t_secao "energia (systemctl de mentira)"
# ==========================================
# o comando de verdade muda de sistema pra sistema (todos são stubs aqui)
case "$_SO" in
    macos) t_off="osascript"; t_reboot="osascript"; t_susp="pmset sleepnow"; t_agenda="shutdown -h +30"; t_cancela="killall shutdown" ;;
    wsl)   t_off="shutdown.exe /s"; t_reboot="shutdown.exe /r"; t_susp="rundll32"; t_agenda="shutdown.exe /s /t 1800"; t_cancela="shutdown.exe /a" ;;
    *)     t_off="systemctl poweroff"; t_reboot="systemctl reboot"; t_susp="systemctl suspend"; t_agenda="shutdown -h +30"; t_cancela="shutdown -c" ;;
esac
: > "$STUB_LOG"
saida=$(poweroff <<< n 2>&1 | _t_limpo)
_t_tem "poweroff pergunta e cancela" "cancelado" "$saida"
_t_nao_tem "poweroff cancelado não desliga" "$t_off" "$(cat "$STUB_LOG")"
_t_tem "poweroff faz a checagem" "nada pendente" "$saida"
poweroff <<< s > /dev/null 2>&1
_t_tem "poweroff confirmado desliga" "$t_off" "$(cat "$STUB_LOG")"
_t "poweroff salvou o log preventivo" test -s "$DOTFILES_ESTADO/energia/energia.log"
t_logs=("$DOTFILES_ESTADO"/energia/desligar-*.log)
_t "log de energia detalhado" test -f "${t_logs[0]}"
: > "$STUB_LOG"
reboot -y > /dev/null 2>&1
_t_tem "reboot -y não pergunta" "$t_reboot" "$(cat "$STUB_LOG")"
: > "$STUB_LOG"
suspend -y > /dev/null 2>&1
_t_tem "suspend" "$t_susp" "$(cat "$STUB_LOG")"
: > "$STUB_LOG"
poweroff -y 30 > /dev/null 2>&1
_t_tem "poweroff agendado" "$t_agenda" "$(cat "$STUB_LOG")"
: > "$STUB_LOG"
poweroff cancelar > /dev/null 2>&1
_t_tem "poweroff cancelar" "$t_cancela" "$(cat "$STUB_LOG")"
_t_nao "suspend não agenda" suspend 10
_t_nao "poweroff com opção errada = uso" poweroff --bobagem
: > "$STUB_LOG"
desligar <<< n > /dev/null 2>&1
_t_nao_tem "desligar (português) também pergunta" "$t_off" "$(cat "$STUB_LOG")"
mkdir -p "$DEV_HOME/sujo" && ( builtin cd "$DEV_HOME/sujo" && git init -q && printf 'x\n' > x )
saida=$(poweroff <<< n 2>&1 | _t_limpo)
_t_tem "poweroff avisa projeto com mudanças" "sujo" "$saida"

# ==========================================
_t_secao "painéis e erros"
# ==========================================
saida=$(dev 2>&1 | _t_limpo)
_t_tem "dev mostra tudo" "YOUR COMMANDS" "$saida"
_t_tem "dev tem a seção energia" "poweroff" "$saida"
for t_s in "${_DEV_SECOES[@]}"; do
    _t "dev $t_s" dev "$t_s"
done
_t_nao "dev seção errada" dev bobagem
_t_tem "help mostra tudo" "SYSTEM COMMANDS" "$(help 2>&1)"
_t_tem "help diff" "GIT DIFF" "$(help diff 2>&1)"
for t_s in "${_HELP_SECOES[@]}"; do
    _t "help $t_s" help "$t_s"
done
if [ "$T_SHELL" = bash ]; then _t_tem "help cd cai no help do bash" "cd:" "$(help cd 2>&1)"; fi
saida=$(status 2>&1 | _t_limpo)
_t_tem "status" "ENVIRONMENT STATUS" "$saida"
_t_tem "status mostra a máquina" "memória" "$saida"
saida=$(dotfiles 2>&1 | _t_limpo)
_t_tem "dotfiles doctor" "CHECK-UP" "$saida"
saida=$(_comando_nao_encontrado gti status 2>&1 | _t_limpo)
_t_tem "comando errado sugere o certo" "quis dizer git status" "$saida"
_comando_nao_encontrado gti > /dev/null 2>&1
_t_eq "comando não encontrado devolve 127" "127" "$?"
_t "_mesmas_letras" _mesmas_letras gti git
_t_nao "_mesmas_letras diferente" _mesmas_letras abc abd
_t_tem "banner fixo" "GROUND CONTROL" "$(_banner_fixo 2>&1)"
_t_tem "banner animado (sem animação nos testes)" "arsenal" "$(_banner_animado 2>&1)"

# ==========================================
_t_secao "prompt"
# ==========================================
if [ "$T_SHELL" = bash ]; then
    false; _prompt_hook
    _t_eq "prompt marca o erro" "  ✗ 1" "$_PS1_ERRO"
    true; _prompt_hook
    _t_eq "prompt limpa o erro" "" "$_PS1_ERRO"
    _DF_T0=$(( EPOCHSECONDS - 75 )); _prompt_hook
    _t_eq "prompt mostra comando lento" "  ⏱ 1m15s" "$_PS1_TEMPO"
    _t_tem "PS1 tem o nome" 'PROMPT_NOME' "$PS1"
else
    false; _df_precmd
    _t_eq "prompt marca o erro" "  ✗ 1" "$_PS1_ERRO"
    true; _df_precmd
    _t_eq "prompt limpa o erro" "" "$_PS1_ERRO"
    _DF_T0=$(( EPOCHSECONDS - 75 )); _df_precmd
    _t_eq "prompt mostra comando lento" "  ⏱ 1m15s" "$_PS1_TEMPO"
    _t_tem "PROMPT tem o nome" 'PROMPT_NOME' "$PROMPT"
fi

# ==========================================
_t_secao "atualizar (repositório de mentira)"
# ==========================================
builtin cd "$T_SANDBOX" || exit 1
git clone -q --no-local "$T_RAIZ" origem-dotfiles.git --bare 2> /dev/null || git clone -q --bare "$T_RAIZ" origem-dotfiles.git
git clone -q origem-dotfiles.git clone-dotfiles 2> /dev/null
( builtin cd clone-dotfiles && git status --porcelain | head -1 ) > /dev/null
if [ -d clone-dotfiles/shell ]; then
    t_dot_antigo="$DOTFILES"
    DOTFILES="$T_SANDBOX/clone-dotfiles"
    t_rc_antigo=$(_caminho_real "$HOME/.${T_SHELL}rc")
    ln -sf "$DOTFILES/${T_SHELL}rc" "$HOME/.${T_SHELL}rc"
    saida=$(atualizar 2>&1 | _t_limpo)
    _t_tem "atualizar sem novidade" "já tá na versão mais nova" "$saida"
    ( builtin cd "$T_SANDBOX" && git clone -q origem-dotfiles.git autor && builtin cd autor &&
      printf '\n# teste\n' >> shell/50-atalhos.sh && git commit -qam "feat: mudança de teste" && git push -q 2> /dev/null )
    saida=$(atualizar 2>&1 | _t_limpo)
    _t_tem "atualizar baixa e recarrega" "terminal atualizado" "$saida"
    _t_tem "atualizar lista o que mudou" "feat: mudança de teste" "$saida"
    _t_tem "atualizar: a dica usa a pasta real do repo" "git -C $DOTFILES reset" "$saida"
    printf 'mexi\n' >> "$DOTFILES/zshrc"
    _t_nao "atualizar recusa repo mexido" atualizar
    _t_tem "atualizar mexido: a dica usa a pasta real" "git -C $DOTFILES diff" "$(atualizar 2>&1 | _t_limpo)"
    ln -sf "$t_rc_antigo" "$HOME/.${T_SHELL}rc"
    DOTFILES="$t_dot_antigo"
fi

builtin cd "$t_volta" 2> /dev/null || true

# ==========================================
printf '\n  %s passaram · %s falharam\n' "$T_OK" "$T_FALHA"
[ "$T_FALHA" -eq 0 ]
