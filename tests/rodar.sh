#!/usr/bin/env bash
# ==========================================
# tests/rodar.sh — roda a suíte de testes dos dotfiles
#   tests/rodar.sh            bash e zsh (os que existirem)
#   tests/rodar.sh bash       só no bash
#   tests/rodar.sh zsh        só no zsh
#
# Cada shell roda num HOME descartável, com os stubs de tests/stubs/ na
# frente do PATH: sudo, systemctl, apt… são de mentira e só anotam a
# chamada. Nada desliga, instala ou apaga de verdade na tua máquina.
# ==========================================
set -u

RAIZ=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
alvos=("$@")
[ ${#alvos[@]} -eq 0 ] && alvos=(bash zsh)

# locale UTF-8 que existir (o macOS não tem C.UTF-8)
LOCALE=C.UTF-8
if ! locale -a 2> /dev/null | grep -qiE '^c\.utf-?8$'; then LOCALE=en_US.UTF-8; fi

falhou=0
for sh in "${alvos[@]}"; do
    if ! command -v "$sh" > /dev/null 2>&1; then
        printf '\n○ %s não está instalado — pulando\n' "$sh"
        continue
    fi
    if [ "$sh" = bash ]; then
        versao=$(bash -c 'echo $(( BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] ))')
        if [ "$versao" -lt 404 ]; then
            printf '\n○ bash %s é antigo (precisa 4.4+) — pulando\n' "$(bash -c 'echo $BASH_VERSION')"
            continue
        fi
    fi

    tmp="${TMPDIR:-/tmp}"
    sandbox=$(mktemp -d "${tmp%/}/dotfiles-teste.XXXXXX")   # o TMPDIR do macOS termina em /
    sandbox=$(cd -P "$sandbox" && pwd)                       # e /var é atalho pra /private/var
    mkdir -p "$sandbox/home/Documents/projetos" "$sandbox/home/.config/dotfiles"
    ln -s "$RAIZ/bashrc" "$sandbox/home/.bashrc"
    ln -s "$RAIZ/zshrc" "$sandbox/home/.zshrc"
    printf 'skip_global_compinit=1\n' > "$sandbox/home/.zshenv"
    cat > "$sandbox/home/.gitconfig" << 'EOF'
[user]
    name = Teste
    email = teste@exemplo.com
[init]
    defaultBranch = main
[pull]
    rebase = false
[advice]
    detachedHead = false
EOF

    printf '\n━━ %s (%s) ━━\n' "$sh" "$("$sh" --version 2>&1 | head -n 1)"
    comum=(HOME="$sandbox/home" USER=teste LOGNAME=teste SHELL="$(command -v "$sh")"
           PATH="$RAIZ/tests/stubs:$PATH" TERM=xterm-256color LANG="$LOCALE" LC_ALL="$LOCALE" TZ=UTC
           DOTFILES_TESTE=1 DOTFILES_ANIM=0 DOTFILES_CONTAGEM=0
           # com HOMEBREW_PREFIX definido o bashrc não roda o 'brew shellenv', que poria o brew
           # de verdade na frente dos stubs (e o teste do upgrade atualizaria o macOS inteiro)
           HOMEBREW_PREFIX=/dotfiles-teste-sem-brew HOMEBREW_NO_AUTO_UPDATE=1
           STUB_LOG="$sandbox/stub.log" T_RAIZ="$RAIZ" T_SANDBOX="$sandbox" T_SHELL="$sh")
    if [ "$sh" = bash ]; then
        env -i "${comum[@]}" bash --norc --noprofile -O expand_aliases -c \
            '. ~/.bashrc > /dev/null && . "$T_RAIZ/tests/casos.sh"' < /dev/null &
    else
        env -i "${comum[@]}" zsh -f -c \
            '. ~/.zshrc > /dev/null && emulate ksh -o bash_rematch -c ". \"\$T_RAIZ/tests/casos.sh\""' < /dev/null &
    fi
    # cão de guarda: se um teste travar, a suíte morre em 5 min e diz onde parou
    pid=$!
    # (o trap leva o sleep junto quando o guarda é dispensado: sem ele, sobra um sleep órfão)
    ( trap 'kill $! 2> /dev/null; exit' TERM
      sleep 300 & wait $!
      kill "$pid" 2> /dev/null && printf '\n✗ tempo esgotado: travou depois do último teste acima\n' ) &
    guarda=$!
    wait "$pid"
    cod=$?
    kill "$guarda" 2> /dev/null
    [ "$cod" -ne 0 ] && falhou=1
    if [ "$cod" -ne 0 ] && [ -s "$sandbox/saida.log" ]; then
        printf '   (saída dos testes que falharam: %s/saida.log)\n' "$sandbox"
    else
        rm -rf "$sandbox"
    fi
done

if [ "$falhou" -eq 0 ]; then printf '\n✓ tudo passou\n'; else printf '\n✗ teve falha\n'; fi
exit "$falhou"
