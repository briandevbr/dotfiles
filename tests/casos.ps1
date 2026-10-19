# ==========================================
# Testes do profile do PowerShell (Windows PowerShell 5.1 e PowerShell 7+)
#   pwsh -NoProfile -File tests/casos.ps1
#   powershell -NoProfile -File tests\casos.ps1      (Windows 5.1)
# Roda num HOME descartável. Desligar, reiniciar e suspender são trocados
# por funções que só anotam: nada desliga de verdade.
# ==========================================
$ErrorActionPreference = 'Continue'
$raiz = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-ps.' + [IO.Path]::GetRandomFileName())
$null = New-Item -ItemType Directory -Force -Path $sandbox
$env:DOTFILES_ANIM = '0'
$env:DOTFILES_CONTAGEM = '0'
$env:GIT_AUTHOR_NAME = 'Teste'; $env:GIT_AUTHOR_EMAIL = 'teste@exemplo.com'
$env:GIT_COMMITTER_NAME = 'Teste'; $env:GIT_COMMITTER_EMAIL = 'teste@exemplo.com'
git config --global init.defaultBranch main 2>$null

$Global:T_OK = 0; $Global:T_FALHA = 0
function _t_passou([string]$n) { $Global:T_OK++; Write-Output "  ✓ $n" }
function _t_falhou([string]$n, [string]$d) { $Global:T_FALHA++; Write-Output "  ✗ $n"; if ($d) { Write-Output "      $d" } }
function _t_eq([string]$n, $esperado, $obtido) { if ("$esperado" -eq "$obtido") { _t_passou $n } else { _t_falhou $n "esperado [$esperado], veio [$obtido]" } }
function _t_tem([string]$n, [string]$trecho, [string]$texto) { if ($texto.Contains($trecho)) { _t_passou $n } else { _t_falhou $n "não achei [$trecho] em: $($texto.Substring(0, [Math]::Min(300, $texto.Length)))" } }
function _t_nao_tem([string]$n, [string]$trecho, [string]$texto) { if (-not $texto.Contains($trecho)) { _t_passou $n } else { _t_falhou $n "não devia ter [$trecho]" } }
function _t_secao([string]$n) { Write-Output "`n▸ $n" }
# captura o que as funções escrevem direto no console
function _t_saida([scriptblock]$bloco) {
    $original = [Console]::Out
    $sw = New-Object IO.StringWriter
    [Console]::SetOut($sw)
    try { $null = & $bloco } finally { [Console]::SetOut($original) }
    return ($sw.ToString() -replace "$([char]27)\[[0-9;?]*[a-zA-Z]", '' -replace "`r", '')
}

# ---------- carrega o profile ----------
_t_secao 'carregamento'
$antes = $Error.Count
# dot-source no escopo do script (dentro de um & { } as funções sumiriam no fim do bloco)
$console = [Console]::Out; $buffer = New-Object IO.StringWriter; [Console]::SetOut($buffer)
. (Join-Path $raiz 'windows/Microsoft.PowerShell_profile.ps1')
[Console]::SetOut($console)
$saidaCarga = $buffer.ToString()
# (o init do zoxide faz um Get-Variable -ErrorAction SilentlyContinue: anota em $Error sem ser erro)
$errosCarga = @($Error | Select-Object -First ($Error.Count - $antes) | Where-Object { "$_" -notmatch '__zoxide_hooked' })
_t_eq 'profile carrega sem erro' 0 $errosCarga.Count
$errosCarga | ForEach-Object { Write-Output "      $_" }
_t_tem 'banner aparece' 'GROUND CONTROL' $saidaCarga
_t_eq 'alias gc saiu (virou o atalho do git)' 'Function' (Get-Command gc).CommandType
_t_eq 'alias ni saiu (virou o atalho do npm)' 'Function' (Get-Command ni).CommandType

# energia nunca de verdade nos testes
$Global:T_LOG = New-Object Collections.Generic.List[string]
function Stop-Computer { $Global:T_LOG.Add('Stop-Computer') }
function Restart-Computer { $Global:T_LOG.Add('Restart-Computer') }
function _suspender_windows { $Global:T_LOG.Add('suspender') }
function systemctl { $Global:T_LOG.Add("systemctl $args") }
function shutdown { $Global:T_LOG.Add("shutdown $args") }
function shutdown.exe { $Global:T_LOG.Add("shutdown.exe $args") }

# ---------- helpers ----------
_t_secao 'helpers'
_t_eq '_humano 1536' '1.5K' (_humano 1536)
_t_eq '_humano 10M' '10M' (_humano 10485760)
_t_eq '_humano 0' '0B' (_humano 0)
_t_eq '_plural 1' '1 commit' (_plural 1 commit commits)
_t_eq '_plural 2' '2 commits' (_plural 2 commit commits)
_t_eq '_mesmas_letras gti git' $true (_mesmas_letras gti git)
_t_eq '_mesmas_letras diferente' $false (_mesmas_letras abc abd)
_t_eq 'calc' 14 (calc '2+3*4')
_t_eq 'calc decimal' 2.5 (calc 10/4)
_t_tem 'calc recusa letra' 'só números' (_t_saida { calc 'abc' })
_t_eq 'b64' 'b2k=' (b64 oi)
_t_eq 'b64d' 'oi' (b64d 'b2k=')
_t_eq 'senha tamanho' 24 ((senha 24 | Select-Object -First 1).Length)
_t_eq 'uuid formato' $true ([bool]((uuid | Select-Object -First 1) -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'))
_t_eq 'epoch converte' 4 ((epoch 0).Split('/').Count + 1)
$s = _t_saida { _ok 'tudo certo' 'detalhe' }
_t_tem '_ok' '✓  tudo certo   detalhe' $s
$s = _t_saida { _err 'deu ruim' 'faz assim' }
_t_tem '_err' '✗  deu ruim' $s
$s = _t_saida { $null = _rodar 'tarefa' { 1 + 1 } }
_t_tem '_rodar sucesso' '✓  tarefa' $s
$s = _t_saida { $null = _rodar 'tarefa ruim' { throw 'motivo-do-erro' } }
_t_tem '_rodar falha mostra o motivo' 'motivo-do-erro' $s

# ---------- arquivos ----------
_t_secao 'arquivos e navegação'
Set-Location $sandbox
$null = _t_saida { mkcd 'a/b' }
_t_eq 'mkcd entra' (Join-Path (Join-Path $sandbox 'a') 'b') (Get-Location).Path
$null = _t_saida { up 2 }
_t_eq 'up 2' $sandbox (Get-Location).Path
Set-Content -Path nota.txt -Value 'oi'
$null = _t_saida { bak nota.txt }
_t_eq 'bak cria cópia' 1 @(Get-ChildItem -Filter 'nota.txt.bak-*').Count
$null = New-Item -ItemType Directory -Force -Path pacote/sub; Set-Content pacote/sub/x.txt 'x'
$null = _t_saida { compactar pacote }
_t_eq 'compactar zip' $true (Test-Path pacote.zip)
$null = New-Item -ItemType Directory -Force -Path ext; Set-Location ext
$null = _t_saida { extract ../pacote.zip }
_t_eq 'extract zip' $true (Test-Path pacote/sub/x.txt)
Set-Location $sandbox
_t_tem 'extract formato errado' 'formato não reconhecido' (_t_saida { extract nota.txt })
_t_tem 'espaco' 'o que mais ocupa' (_t_saida { espaco $sandbox })

# ---------- git ----------
_t_secao 'git'
git init -q --bare (Join-Path $sandbox 'remoto.git')
git init -q (Join-Path $sandbox 'proj'); Set-Location (Join-Path $sandbox 'proj')
git remote add origin (Join-Path $sandbox 'remoto.git')
Set-Content a.txt 'um'
_t_tem 'ga' 'adicionado ao stage' (_t_saida { ga a.txt })
_t_tem 'gc' 'commit criado' (_t_saida { gc primeiro commit })
_t_eq 'gc junta a mensagem' 'primeiro commit' (git log -1 --format=%s)
_t_eq 'branch rápida' 'main' (_branch_rapido)
_t_tem 'prompt mostra a branch' 'main' (prompt)
_t_tem 'gp publica' 'branch publicada' (_t_saida { gp })
_t_tem 'gp sem nada' 'nada pra enviar' (_t_saida { gp })
Add-Content a.txt 'dois'; Set-Content b.txt 'novo'
_t_tem 'gac' 'commit criado' (_t_saida { gac segundo })
Add-Content a.txt 'tres'; git add a.txt
$null = _t_saida { gcm feat:login adiciona botão }
_t_eq 'gcm tipo:escopo' 'feat(login): adiciona botão' (git log -1 --format=%s)
Add-Content a.txt 'quatro'; git add a.txt
_t_tem 'gcm tipo inválido' 'Conventional Commits' (_t_saida { gcm bobagem texto })
$null = _t_saida { gundo }
_t_eq 'gundo' 'segundo' (git log -1 --format=%s)
$null = _t_saida { gamend nova mensagem }
_t_eq 'gamend' 'nova mensagem' (git log -1 --format=%s)
Add-Content a.txt 'sujo'
$null = _t_saida { gst }
_t_eq 'gst limpa' '' "$(git status --porcelain)"
$null = _t_saida { gstp }
_t_tem 'gstp devolve' 'a.txt' "$(git status --porcelain)"
git checkout -q -- a.txt
$null = _t_saida { gcb feature/x }
_t_eq 'gcb' 'feature/x' (git branch --show-current)
Set-Content f.txt 'f'; git add f.txt; git commit -qm 'feat: f'
$null = _t_saida { gco main }
_t_eq 'gco' 'main' (git branch --show-current)
_t_tem 'gin' '1 commit entra' (_t_saida { gin feature/x })
$null = _t_saida { gm feature/x }
_t_eq 'gm' $true (Test-Path f.txt)
$null = _t_saida { gbd feature/x }
_t_nao_tem 'gbd' 'feature/x' "$(git branch)"
git remote set-url origin git@github.com:fulano/projeto.git
_t_eq '_url_remoto' 'https://github.com/fulano/projeto' (_url_remoto)
Set-Location $sandbox
_t_tem 'fora de repo avisa' 'não é um repositório git' (_t_saida { gs })

# ---------- node ----------
_t_secao 'node'
$null = New-Item -ItemType Directory -Force -Path (Join-Path $sandbox 'Minha Pizzaria Ç')
Set-Location (Join-Path $sandbox 'Minha Pizzaria Ç')
$null = _t_saida { npkg }
$pkg = Get-Content package.json -Raw | ConvertFrom-Json
_t_eq 'npkg nome normalizado' 'minha-pizzaria-c' $pkg.name
_t_eq 'npkg type module' 'module' $pkg.type
_t_tem 'npkg não sobrescreve' 'já existe' (_t_saida { npkg })
_t_eq '_pm padrão' 'npm' (_pm)
Set-Location $sandbox
_t_tem 'ni fora de projeto' 'não é um projeto node' (_t_saida { ni })

# ---------- energia ----------
_t_secao 'energia (de mentira)'
function _confirma { $false }
$null = _t_saida { poweroff }
_t_eq 'poweroff cancelado não desliga' 0 $Global:T_LOG.Count
function _confirma { $true }
$null = _t_saida { poweroff }
_t_tem 'poweroff confirmado' $(if ($Global:_DF_WINDOWS) { 'Stop-Computer' } else { 'systemctl poweroff' }) ($Global:T_LOG -join ';')
$Global:T_LOG.Clear(); $null = _t_saida { reboot -y }
_t_tem 'reboot -y' $(if ($Global:_DF_WINDOWS) { 'Restart-Computer' } else { 'systemctl reboot' }) ($Global:T_LOG -join ';')
$Global:T_LOG.Clear(); $null = _t_saida { suspend -y }
_t_tem 'suspend -y' $(if ($Global:_DF_WINDOWS) { 'suspender' } else { 'systemctl suspend' }) ($Global:T_LOG -join ';')
$Global:T_LOG.Clear(); $null = _t_saida { poweroff -y 30 }
_t_tem 'poweroff agendado' $(if ($Global:_DF_WINDOWS) { 'shutdown.exe /s /t 1800' } else { 'shutdown -h +30' }) ($Global:T_LOG -join ';')
_t_tem 'suspend não agenda' 'não tem agendamento' (_t_saida { suspend 10 })
_t_tem 'opção errada = uso' 'uso' (_t_saida { poweroff --bobagem })
_t_eq 'log preventivo salvo' $true (Test-Path (Join-Path (Join-Path $Global:DOTFILES_ESTADO 'energia') 'energia.log'))

# ---------- painéis ----------
_t_secao 'painéis'
_t_tem 'dev' 'YOUR COMMANDS' (_t_saida { dev })
foreach ($x in $Global:_DEV_SECOES) { _t_tem "dev $x" '▸' (_t_saida { dev $x }) }
_t_tem 'dev seção errada' 'não é uma seção' (_t_saida { dev bobagem })
_t_tem 'help' 'SYSTEM COMMANDS' (_t_saida { help })
_t_tem 'status' 'ENVIRONMENT STATUS' (_t_saida { status })
_t_tem 'dotfiles' 'CHECK-UP' (_t_saida { dotfiles })
_t_tem 'limpar -n' 'SÓ SIMULANDO' (_t_saida { limpar -n })

Set-Location $raiz
Remove-Item -Recurse -Force -LiteralPath $sandbox -ErrorAction SilentlyContinue
Write-Output "`n  $Global:T_OK passaram · $Global:T_FALHA falharam"
if ($Global:T_FALHA -gt 0) { exit 1 } else { exit 0 }
