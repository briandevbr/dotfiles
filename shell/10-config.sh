# shellcheck shell=bash
# ==========================================
# CONFIGURAÇÃO — mude aqui, não no meio do arquivo
# Quer mudar sem mexer no repositório (e sem o 'atualizar' reclamar)?
# Coloque as mesmas linhas em ~/.config/dotfiles/local.sh — ele carrega
# depois de tudo e vale por cima daqui.
# ==========================================

# Pasta raiz dos seus projetos. Usa $HOME em vez do caminho absoluto
# pra não quebrar se o nome de usuário mudar.
export DEV_HOME="$HOME/Documents/projetos"

# Duração padrão do timebox, em minutos
export TIMEBOX_MIN=30

# Onde fica o repositório dotfiles (o ~/.bashrc é um atalho pro bashrc de lá).
# O comando 'atualizar' baixa a versão nova desse repo.
# Quem descobre o caminho é o próprio bashrc/zshrc, seguindo o atalho.
export DOTFILES="${DOTFILES:-$HOME/dotfiles}"

# O nome que aparece no começo do prompt: [brian] in 15:45:10 ...
PROMPT_NOME="brian"

# As DOTFILES_* abaixo também aceitam vir do ambiente: DOTFILES_ANIM=0 bash
# Animações (banner de boas-vindas, spinners). 0 = tudo estático.
# O banner animado só roda no primeiro terminal do dia; os outros abrem na hora.
DOTFILES_ANIM="${DOTFILES_ANIM:-1}"

# Segundos de contagem regressiva antes de desligar/reiniciar (Ctrl+C cancela)
DOTFILES_CONTAGEM="${DOTFILES_CONTAGEM:-5}"

# Comando lento: se levar mais que isso (segundos), o prompt mostra quanto levou
DOTFILES_LENTO="${DOTFILES_LENTO:-5}"

# Onde ficam os logs (energia, limpeza) e o cache dos 'init' das ferramentas.
# Seguem o padrão XDG: nada de arquivo solto na tua home.
DOTFILES_ESTADO="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
DOTFILES_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
DOTFILES_LOCAL="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local.sh"
