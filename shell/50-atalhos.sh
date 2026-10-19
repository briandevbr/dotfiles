# shellcheck shell=bash
# ==========================================
# ATALHOS — aliases e listas que precisam existir desde o início
# As funções moram em shell/modulos/ e carregam sob demanda; alias não
# dá pra carregar depois, então todos ficam aqui.
# ==========================================

# ---------- SEGURANÇA — confirmação em comandos destrutivos ----------
# Pede confirmação antes de apagar ou sobrescrever.
# As funções dos módulos usam 'command rm/cp' para não serem afetadas:
# alias dentro de função expande na leitura.
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# ---------- NAVEGAÇÃO ----------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'                        # volta pra pasta anterior
alias c='clear'
alias p='builtin cd "$DEV_HOME"'

# ---------- AVISOS E ATALHOS PESSOAIS ----------
alias limpar='clean'                     # o mesmo nome do PowerShell (lá 'clean' é palavra reservada)
alias alert='_alerta $?'                 # avisa na tela quando acabar: npm run build; alert
alias diario='_abrir "https://claude.ai/artifact/58cmKCqHrffWQxMtoMQA41"'   # _abrir: não trava o terminal

# ---------- SEÇÕES DOS PAINÉIS ----------
# O Tab do dev e do help completa com estas listas logo no início
_DEV_SECOES=(nav arquivos util dev git remoto node docker rede processos sistema energia terminal)
_HELP_SECOES=(nav arquivos texto pipes teclado historico processos sistema pacotes rede git node shell ajuda)

# ==========================================
# COMPATIBILIDADE — nomes antigos
# Pode apagar este bloco quando a memória muscular pegar os novos.
# ==========================================

alias cleanSys='clean'
alias devstatus='status'
alias rmApt='rmpkg'
alias rmProgram='rmapp'
alias listApt='lspkg'
alias listProgram='lsapp'
alias openhub='hub'
