# ==========================================
# DOTFILES · PROFILE DO POWERSHELL
# Windows PowerShell 5.1 e PowerShell 7+ (Windows, e também pwsh no Linux/macOS)
#
# O mesmo terminal do bash/zsh — mesmo prompt, mesmas cores, mesmos atalhos
# (gs, gac, gp, proj, clean, poweroff, dev, help…) — com o jeito do Windows
# por baixo (winget, Lixeira, Stop-Computer, Get-NetTCPConnection…).
#
# Instalação: windows\install.ps1 (faz o $PROFILE carregar este arquivo).
# Copiar e colar também vale: cole o arquivo inteiro no teu $PROFILE.
# Salvo em UTF-8 COM BOM de propósito: sem o BOM, o PowerShell 5.1 lê os
# acentos e os símbolos (✓ ✗ ◈) errado.
#
# Teus ajustes pessoais: $HOME\.config\dotfiles\local.ps1 (carrega no fim).
# ==========================================

$Global:_DF_T0 = [Diagnostics.Stopwatch]::StartNew()

# ==========================================
# CONFIGURAÇÃO — mude aqui (ou no local.ps1)
# ==========================================
$Global:DEV_HOME = Join-Path (Join-Path $HOME 'Documents') 'projetos'   # pasta dos projetos
$Global:TIMEBOX_MIN = 30                                                # timebox padrão (min)
$Global:DOTFILES = Join-Path $HOME 'dotfiles'                           # o repositório…
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot '..\.git'))) {   # …ou a pasta onde este arquivo mora,
    $Global:DOTFILES = Split-Path -Parent $PSScriptRoot                 # se ele foi clonado em outro lugar
}
$Global:PROMPT_NOME = 'brian'                                           # o [brian] do prompt
$Global:DOTFILES_ANIM = if ($env:DOTFILES_ANIM) { $env:DOTFILES_ANIM } else { '1' }          # 0 = sem animação
$Global:DOTFILES_CONTAGEM = if ($env:DOTFILES_CONTAGEM) { [int]$env:DOTFILES_CONTAGEM } else { 5 }  # contagem antes de desligar
$Global:DOTFILES_LENTO = 5                                              # segundos pra mostrar "⏱" no prompt
$Global:_DF_WINDOWS = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
if ($Global:_DF_WINDOWS) {
    $Global:DOTFILES_ESTADO = Join-Path $env:LOCALAPPDATA 'dotfiles'
} else {
    $Global:DOTFILES_ESTADO = Join-Path (Join-Path (Join-Path $HOME '.local') 'state') 'dotfiles'
}
$Global:DOTFILES_LOCAL = Join-Path (Join-Path (Join-Path $HOME '.config') 'dotfiles') 'local.ps1'

# Acentos e símbolos certos no console
try {
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    $Global:OutputEncoding = [Text.Encoding]::UTF8
} catch { $null = $_ }

# ==========================================
# PALETA — as mesmas cores do prompt do bash
# 39 azul (títulos) · 141 lilás (seções) · 51 ciano (comandos) · 214 laranja (alerta)
# 46 verde (sucesso) · 196 vermelho (erro) · 245 cinza (apoio) · 252 texto
# ==========================================
$Global:_E = [char]27
$Global:C_ACCENT = "$([char]27)[38;5;39m"
$Global:C_DIM    = "$([char]27)[38;5;245m"
$Global:C_TEXT   = "$([char]27)[38;5;252m"
$Global:C_WARN   = "$([char]27)[38;5;214m"
$Global:C_OK     = "$([char]27)[38;5;46m"
$Global:C_ERR    = "$([char]27)[38;5;196m"
$Global:C_SECAO  = "$([char]27)[1;38;5;141m"
$Global:C_CMD    = "$([char]27)[1;38;5;51m"
$Global:C_OFF    = "$([char]27)[0m"
$Global:_CL      = "`r$([char]27)[K"

# ==========================================
# UI — um estilo só pra todas as respostas
# Escreve direto no console (não no pipeline): a mensagem não suja o
# resultado quando você encadeia comandos com |
# ==========================================
function _w([string]$texto) { [Console]::Out.Write($texto) }

function _feito([string]$simbolo, [string]$msg, [string]$detalhe) {
    $linha = "$_CL  $C_OK$simbolo$C_OFF  $C_TEXT$msg$C_OFF"
    if ($detalhe) { $linha += "   $C_DIM$detalhe$C_OFF" }
    _w "$linha`n"
}
function _ok([string]$msg, [string]$detalhe) { _feito '✓' $msg $detalhe }
function _err([string]$msg, [string]$dica) {
    _w "$_CL  $C_ERR✗$C_OFF  $C_TEXT$msg$C_OFF`n"
    if ($dica) { _w "     $C_DIM↳ $dica$C_OFF`n" }
    $Global:LASTEXITCODE = 1
}
function _aviso([string]$msg, [string]$dica) {
    _w "$_CL  $C_WARN!$C_OFF  $C_TEXT$msg$C_OFF`n"
    if ($dica) { _w "     $C_DIM↳ $dica$C_OFF`n" }
}
function _dica([string]$texto) { _w "     $C_DIM↳ $texto$C_OFF`n" }
function _titulo([string]$icone, [string]$acao, [string]$alvo) {
    $linha = "  $C_ACCENT$icone$C_OFF  $C_TEXT$acao$C_OFF"
    if ($alvo) { $linha += "  $C_DIM$alvo$C_OFF" }
    _w "$linha`n"
}
function _kv([string]$rotulo, [string]$valor) { _w ("     $C_DIM{0,-9}$C_OFF $C_TEXT{1}$C_OFF`n" -f $rotulo, $valor) }
function _uso([string]$sintaxe) {
    _w "  ${C_ACCENT}uso$C_OFF  $C_TEXT$sintaxe$C_OFF`n"
    foreach ($l in $args) { _w "       $C_DIM$l$C_OFF`n" }
}
function _confirma([string]$pergunta) {
    _w "  $C_WARN?$C_OFF  $C_TEXT$pergunta$C_OFF $C_DIM[s/N]$C_OFF "
    $r = [Console]::In.ReadLine()
    return ($r -match '^[sS]$')
}
function _cancelado { _w "  $C_DIM○  cancelado — nada foi mexido$C_OFF`n" }
function _pendente([string]$texto) { _w "  $C_DIM◌  $texto$C_OFF" }
function _plural([int]$n, [string]$um, [string]$varios) { if ($n -eq 1) { "$n $um" } else { "$n $varios" } }
function _secao([string]$t) { _w "`n$C_SECAO  ▸ $t$C_OFF`n" }
function _cabecalho([string]$t) {
    _w "`n$C_ACCENT$([char]27)[1m  ◈  $t$C_OFF`n"
    _w "$C_DIM  ────────────────────────────────────────$C_OFF`n"
}
$Global:_LARG = 14
function _linha([string]$nome, [string]$desc) {
    $pad = [Math]::Max(1, $Global:_LARG - $nome.Length)
    _w "  $C_CMD$nome$C_OFF$(' ' * $pad) $C_TEXT$desc$C_OFF`n"
}
function _eq([string]$cmd) { _w "  $(' ' * $Global:_LARG) $C_DIM↳$C_OFF $C_WARN$cmd$C_OFF`n" }
function _curto([string]$p) { if (-not $p) { $p = (Get-Location).Path }; if ($p.StartsWith($HOME)) { '~' + $p.Substring($HOME.Length) } else { $p } }
function _tempo([Diagnostics.Stopwatch]$sw) {
    $ms = [int]$sw.Elapsed.TotalMilliseconds
    if ($ms -lt 1000) { "${ms}ms" } else { '{0:N1}s' -f ($ms / 1000) }
}
function _humano([double]$b) {
    $u = 'B', 'K', 'M', 'G', 'T'; $i = 0
    $sinal = ''; if ($b -lt 0) { $sinal = '-'; $b = -$b }
    while ($b -ge 1024 -and $i -lt 4) { $b /= 1024; $i++ }
    if ($i -eq 0) { "$sinal{0}B" -f [int]$b } elseif ($b -lt 10) { "$sinal{0:0.0}{1}" -f $b, $u[$i] } else { "$sinal{0:0}{1}" -f $b, $u[$i] }
}
function _tem([string]$cmd) { [bool](Get-Command $cmd -CommandType Application -ErrorAction Ignore) }
function _precisa([string]$cmd, [string]$pacote) {
    if (_tem $cmd) { return $true }
    if (-not $pacote) { $pacote = $cmd }
    _err "$cmd não está instalado" "winget install $pacote   (ou: scoop install $pacote)"
    return $false
}
function _anim { ($Global:DOTFILES_ANIM -eq '1') -and -not [Console]::IsOutputRedirected }
$Global:_SPIN = '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'

# _barra atual total [largura] → ██████░░░░
function _barra([double]$atual, [double]$total, [int]$larg = 20) {
    if ($total -lt 1) { $total = 1 }
    $cheio = [Math]::Min($larg, [int][Math]::Floor($atual * $larg / $total))
    "$C_ACCENT$('█' * $cheio)$C_DIM$('░' * ($larg - $cheio))$C_OFF"
}
function _etapa([int]$i, [int]$n, [string]$texto) { _w "`n  $C_DIM[$i/$n]$C_OFF $(_barra $i $n 12)  $C_TEXT$texto$C_OFF`n" }

# _rodar "mensagem" { bloco } [args] — roda o bloco num runspace separado com
# spinner na tela. A saída fica em $Global:_RODAR_SAIDA. Retorna $true/$false.
function _rodar([string]$msg, [scriptblock]$bloco, [object[]]$argumentos = @(), [switch]$Quieto) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $ps = [PowerShell]::Create()
    $null = $ps.AddScript($bloco.ToString())
    foreach ($a in $argumentos) { $null = $ps.AddArgument($a) }
    $ok = $true
    try {
        $h = $ps.BeginInvoke()
        $i = 0
        if (_anim) { _w "$([char]27)[?25l" }
        while (-not $h.IsCompleted) {
            if (_anim) {
                $seg = [int]$sw.Elapsed.TotalSeconds
                $extra = if ($seg -ge 2) { "  $C_DIM${seg}s$C_OFF" } else { '' }
                _w "$_CL  $C_ACCENT$($Global:_SPIN[$i % 10])$C_OFF  $C_TEXT$msg$C_OFF$extra"
            }
            Start-Sleep -Milliseconds 100
            $i++
        }
        $Global:_RODAR_SAIDA = ($ps.EndInvoke($h) | Out-String).Trim()
        if ($ps.HadErrors) { $ok = $false; $Global:_RODAR_SAIDA += "`n" + (($ps.Streams.Error | Out-String).Trim()) }
    } catch {
        $ok = $false
        $Global:_RODAR_SAIDA = $_.Exception.Message
    } finally {
        if (_anim) { _w "$([char]27)[?25h" }
        $ps.Dispose()
    }
    if ($ok) {
        if ($Quieto) { _w $_CL } else { _feito '✓' $msg (_tempo $sw) }
    } else {
        _w "$_CL  $C_ERR✗$C_OFF  $C_TEXT$msg — falhou$C_OFF`n"
        ($Global:_RODAR_SAIDA -split "`n" | Select-Object -Last 6) | ForEach-Object { _w "     $C_DIM│$C_OFF $_`n" }
    }
    return $ok
}

# _contagem segundos "texto" — contagem regressiva; Ctrl+C cancela
function _contagem([int]$seg, [string]$msg) {
    $antes = [Console]::TreatControlCAsInput
    try {
        [Console]::TreatControlCAsInput = $true
        for ($t = $seg * 10; $t -gt 0; $t--) {
            if ([Console]::KeyAvailable) {
                $k = [Console]::ReadKey($true)
                if ($k.Key -eq 'C' -and ($k.Modifiers -band [ConsoleModifiers]::Control)) { _w $_CL; return $false }
            }
            _w "$_CL  $C_WARN$($Global:_SPIN[$t % 10])$C_OFF  $C_TEXT$msg em $C_WARN$([Math]::Ceiling($t / 10))s$C_OFF   ${C_DIM}Ctrl+C cancela$C_OFF"
            Start-Sleep -Milliseconds 100
        }
    } catch {
        Start-Sleep -Seconds $seg                 # console sem teclado (redirecionado): só espera
    } finally {
        try { [Console]::TreatControlCAsInput = $antes } catch { $null = $_ }
    }
    _w $_CL
    return $true
}

# ==========================================
# ALIASES DO POWERSHELL QUE BATEM COM OS ATALHOS
# gc (Get-Content), gl, gp, gcb, gm, gcm, ni, gin… saem pra dar lugar aos
# atalhos de git/npm. Os comandos originais continuam: Get-Content, New-Item…
# ==========================================
# No Windows PowerShell 5.1 vários deles são AllScope (uma cópia em cada escopo):
# remove até não sobrar nenhum visível, senão o alias ganha da função.
foreach ($a in 'gc', 'gl', 'gp', 'gcb', 'gm', 'gcm', 'ni', 'gin', 'gs', 'gd', 'gb', 'gst') {
    for ($i = 0; $i -lt 5 -and (Test-Path "Alias:$a"); $i++) { Remove-Item "Alias:$a" -Force -ErrorAction Ignore }
}

# ==========================================
# FERRAMENTAS — zoxide, fzf, PSReadLine (só se existirem)
# ==========================================
if (_tem zoxide) {
    # --cmd cd: o próprio zoxide vira o cd (cd nome pula pra pasta já visitada; cdi abre a lista)
    Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
}
$env:FZF_DEFAULT_OPTS = '--height 40% --layout=reverse --border=rounded --color=fg:#d0d0d0,bg:-1,hl:#00afff --color=fg+:#ffffff,bg+:#303030,hl+:#00ffff --color=info:#af87ff,prompt:#00afff,pointer:#ffaf00,marker:#00ff00,spinner:#af87ff,header:#af87ff,border:#585858'
# -ErrorAction Ignore (e não SilentlyContinue) no profile todo: sondar uma ferramenta
# que não existe não deixa erro guardado no teu $Error.
# PSReadLine só num console de verdade (com a saída redirecionada ele recusa as opções).
if (-not [Console]::IsOutputRedirected -and (Get-Module -ListAvailable PSReadLine)) {
    Import-Module PSReadLine -ErrorAction Ignore
    try {
        Set-PSReadLineOption -HistoryNoDuplicates -HistorySearchCursorMovesToEnd
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward      # ↑ com texto: só comandos que começam com ele
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete                   # Tab lista as opções
        Set-PSReadLineOption -Colors @{ Command = "$([char]27)[38;5;51m"; String = "$([char]27)[38;5;214m"; Parameter = "$([char]27)[38;5;141m"; Operator = "$([char]27)[38;5;245m" }
        Set-PSReadLineOption -PredictionSource History -ErrorAction Stop           # sugestão cinza do histórico (PSReadLine 2.1+)
    } catch { $null = $_ }
}

# ==========================================
# PROMPT — igual ao do bash:  [brian] in 15:45:10  ~/pasta branch  ✗ 1  ⏱ 12s
# A branch vem do .git/HEAD lido direto (sem chamar o git a cada Enter)
# ==========================================
function _branch_rapido {
    $d = (Get-Location).ProviderPath
    if (-not $d -or (Get-Location).Provider.Name -ne 'FileSystem') { return $null }
    while ($d) {
        $git = Join-Path $d '.git'
        if (Test-Path -LiteralPath (Join-Path $git 'HEAD') -PathType Leaf) { $head = Join-Path $git 'HEAD'; break }
        if (Test-Path -LiteralPath $git -PathType Leaf) {
            $gd = ((Get-Content -LiteralPath $git -TotalCount 1) -replace '^gitdir:\s*', '')
            if (-not [IO.Path]::IsPathRooted($gd)) { $gd = Join-Path $d $gd }
            $head = Join-Path $gd 'HEAD'; break
        }
        $pai = Split-Path $d -Parent
        if ($pai -eq $d) { return $null }
        $d = $pai
    }
    if (-not $d) { return $null }
    $linha = Get-Content -LiteralPath $head -TotalCount 1 -ErrorAction Ignore
    if ($linha -match '^ref: refs/heads/(.+)$') { return $Matches[1] }
    if ($linha) { return $linha.Substring(0, [Math]::Min(7, $linha.Length)) }
    return $null
}

function prompt {
    $okUltimo = $?
    $codigo = $Global:LASTEXITCODE
    $erro = ''
    if (-not $okUltimo) { $erro = if ($codigo -and $codigo -ne 0) { "  ✗ $codigo" } else { '  ✗' } }
    $branch = _branch_rapido
    $branch = if ($branch) { " $branch" } else { '' }
    $tempo = ''
    $ultimo = Get-History -Count 1 -ErrorAction Ignore
    if ($ultimo -and $ultimo.Id -ne $Global:_DF_ULTIMO_ID) {
        $Global:_DF_ULTIMO_ID = $ultimo.Id
        $d = [int]($ultimo.EndExecutionTime - $ultimo.StartExecutionTime).TotalSeconds
        if ($d -ge $Global:DOTFILES_LENTO) { $tempo = if ($d -ge 60) { "  ⏱ $([int][Math]::Floor($d / 60))m$($d % 60)s" } else { "  ⏱ ${d}s" } }
    }
    $e = [char]27
    "$e[1;38;5;39m[$Global:PROMPT_NOME]$e[0;38;5;245m in $e[1;38;5;141m$(Get-Date -Format HH:mm:ss)  $e[1;38;5;51m$(_curto)$e[1;38;5;214m$branch$e[1;38;5;196m$erro$e[0;38;5;245m$tempo$e[0m`n$e[1;38;5;46m>$e[0m "
}

# ==========================================
# NAVEGAÇÃO E ARQUIVOS
# ==========================================
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }
function c { Clear-Host }
function p { Set-Location $Global:DEV_HOME }

function mkcd([string]$nome) {
    if (-not $nome) { _uso 'mkcd <nome-da-pasta>' 'cria a pasta (e as do meio) e já entra nela'; return }
    try { $null = New-Item -ItemType Directory -Force -Path $nome -ErrorAction Stop; Set-Location $nome; _ok 'criada e acessada' (_curto) }
    catch { _err "não consegui criar '$nome'" 'confira se você tem permissão nesta pasta' }
}
function up([int]$n = 1) {
    if ($n -lt 1) { _uso 'up [n]' 'sobe n pastas de uma vez'; return }
    Set-Location ((@('..') * $n) -join [IO.Path]::DirectorySeparatorChar)
    _ok "subiu $(_plural $n pasta pastas)" (_curto)
}
function cdr {
    $raiz = git rev-parse --show-toplevel 2>$null
    if (-not $raiz) { _err 'aqui não é um repositório git' 'entre na pasta do projeto antes'; return }
    Set-Location $raiz; _ok 'raiz do repositório' (_curto)
}
function tmpd {
    $d = Join-Path ([IO.Path]::GetTempPath()) ("rascunho." + [IO.Path]::GetRandomFileName())
    $null = New-Item -ItemType Directory -Path $d; Set-Location $d
    _ok 'pasta temporária' $d
}
function open([string]$alvo = '.') {
    if ($alvo -notmatch '://' -and -not (Test-Path -LiteralPath $alvo)) { _err "não encontrei: $alvo" 'confira o nome (o Tab completa)'; return }
    if ($Global:_DF_WINDOWS) { Invoke-Item $alvo }
    elseif (_tem xdg-open) { Start-Process xdg-open $alvo }
    else { Start-Process open $alvo }
    _ok 'abrindo' $(if ($alvo -eq '.') { _curto } else { $alvo })
}
function proj {
    if (-not (Test-Path $Global:DEV_HOME)) { _err "pasta de projetos não existe: $(_curto $Global:DEV_HOME)" "crie com: mkdir `"$Global:DEV_HOME`""; return }
    $nomes = Get-ChildItem -Directory -LiteralPath $Global:DEV_HOME | Sort-Object Name | ForEach-Object Name
    if (-not $nomes) { _aviso "nenhum projeto em $(_curto $Global:DEV_HOME) ainda"; return }
    if (_tem fzf) {
        $escolhido = $nomes | fzf --prompt='projeto ❯ '
    } else {
        $i = 0; foreach ($n in $nomes) { $i++; _w ("  $C_CMD{0,3}$C_OFF  $C_TEXT{1}$C_OFF`n" -f $i, $n) }
        $r = Read-Host '  número do projeto'
        $escolhido = if ($r -match '^\d+$' -and [int]$r -ge 1 -and [int]$r -le @($nomes).Count) { @($nomes)[[int]$r - 1] } else { $null }
    }
    if (-not $escolhido) { return }
    Set-Location (Join-Path $Global:DEV_HOME $escolhido); _ok $escolhido (_curto)
}
function extract([string]$arq) {
    if (-not $arq) { _uso 'extract <arquivo>' '.zip .tar .tar.gz .tgz .tar.xz .tar.bz2 .7z .rar'; return }
    if (-not (Test-Path -LiteralPath $arq)) { _err "arquivo não encontrado: $arq"; return }
    $cheio = (Resolve-Path -LiteralPath $arq).Path; $nome = Split-Path $arq -Leaf; $aqui = (Get-Location).Path
    switch -Regex ($nome) {
        '\.zip$' { $ok = _rodar "extraindo $nome" { param($a, $d) Expand-Archive -LiteralPath $a -DestinationPath $d } @($cheio, $aqui) -Quieto; break }
        '\.(tar|tar\.gz|tgz|tar\.xz|tar\.bz2|tar\.zst)$' { $ok = _rodar "extraindo $nome" { param($a, $d) Set-Location $d; tar -xf $a 2>&1; if ($LASTEXITCODE) { throw 'tar falhou' } } @($cheio, $aqui) -Quieto; break }
        '\.(7z|rar)$' {
            if (-not (_precisa 7z 7zip.7zip)) { return }
            $ok = _rodar "extraindo $nome" { param($a, $d) Set-Location $d; 7z x -aos $a 2>&1; if ($LASTEXITCODE) { throw '7z falhou' } } @($cheio, $aqui) -Quieto; break
        }
        default { _err "formato não reconhecido: $nome" '.zip .tar .tar.gz .tgz .tar.xz .tar.bz2 .7z .rar'; return }
    }
    if ($ok) { _feito '📦' 'extraído' "$nome → $(_curto)" } else { _dica 'arquivo corrompido ou download incompleto?' }
}
function compactar([string]$alvo, [string]$fmt = 'zip') {
    if (-not $alvo) { _uso 'compactar <pasta|arquivo> [formato]' 'formatos: zip (padrão) · tar.gz'; return }
    if (-not (Test-Path -LiteralPath $alvo)) { _err "não encontrei: $alvo"; return }
    $nome = Split-Path ($alvo.TrimEnd('\', '/')) -Leaf; $saida = Join-Path (Get-Location).Path "$nome.$fmt"
    if (Test-Path -LiteralPath $saida) { _err "já existe $nome.$fmt aqui" 'apague ou renomeie antes — não sobrescrevo'; return }
    $cheio = (Resolve-Path -LiteralPath $alvo).Path
    switch ($fmt) {
        'zip' { $ok = _rodar "compactando $nome" { param($a, $s) Compress-Archive -LiteralPath $a -DestinationPath $s } @($cheio, $saida) -Quieto }
        'tar.gz' { $ok = _rodar "compactando $nome" { param($a, $s) tar -czf $s -C (Split-Path $a -Parent) (Split-Path $a -Leaf) 2>&1; if ($LASTEXITCODE) { throw 'tar falhou' } } @($cheio, $saida) -Quieto }
        default { _err "formato '$fmt' não suportado" 'use: zip · tar.gz'; return }
    }
    if ($ok) { _feito '📦' 'compactado' "$nome.$fmt · $(_humano (Get-Item -LiteralPath $saida).Length)" }
}
function bak {
    if (-not $args) { _uso 'bak <arquivo|pasta> [...]' 'cria uma cópia ao lado: nome.bak-<data_hora>'; return }
    $carimbo = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    foreach ($a in $args) {
        $a = "$a".TrimEnd('\', '/')
        if (-not (Test-Path -LiteralPath $a)) { _err "não encontrei: $a"; continue }
        Copy-Item -LiteralPath $a -Destination "$a.bak-$carimbo" -Recurse
        _ok 'cópia criada' "$a.bak-$carimbo"
    }
}
function lixo {
    if (-not $args) { _uso 'lixo <arquivo|pasta> [...]' 'vai pra Lixeira (dá pra recuperar) — o Remove-Item apaga de vez'; return }
    $n = 0
    foreach ($a in $args) {
        if (-not (Test-Path -LiteralPath $a)) { _err "não encontrei: $a"; continue }
        $cheio = (Resolve-Path -LiteralPath $a).Path
        try {
            if ($Global:_DF_WINDOWS) {
                Add-Type -AssemblyName Microsoft.VisualBasic
                if (Test-Path -LiteralPath $cheio -PathType Container) {
                    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($cheio, 'OnlyErrorDialogs', 'SendToRecycleBin')
                } else {
                    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($cheio, 'OnlyErrorDialogs', 'SendToRecycleBin')
                }
            } else {
                $lixeira = Join-Path $HOME '.local/share/Trash/files'
                $null = New-Item -ItemType Directory -Force -Path $lixeira
                Move-Item -LiteralPath $cheio -Destination (Join-Path $lixeira ((Split-Path $cheio -Leaf) + '.' + (Get-Random)))
            }
            $n++
        } catch { _err "não consegui mandar pra lixeira: $a" $_.Exception.Message }
    }
    if ($n -gt 0) { _feito '🗑' "$(_plural $n 'item foi pra lixeira' 'itens foram pra lixeira')" 'recupere pela Lixeira' }
}
function espaco([string]$alvo = '.') {
    if (-not (Test-Path -LiteralPath $alvo -PathType Container)) { _err "pasta não encontrada: $alvo"; return }
    $alvo = (Resolve-Path -LiteralPath $alvo).Path
    _pendente "medindo $(_curto $alvo)…"
    $itens = Get-ChildItem -LiteralPath $alvo -Force -ErrorAction Ignore | ForEach-Object {
        $tam = if ($_.PSIsContainer) { (Get-ChildItem -LiteralPath $_.FullName -Recurse -Force -File -ErrorAction Ignore | Measure-Object Length -Sum).Sum } else { $_.Length }
        [pscustomobject]@{ Nome = $_.Name; Tam = [double]$tam }
    } | Sort-Object Tam -Descending | Select-Object -First 15
    _w $_CL
    if (-not $itens) { _ok 'pasta vazia' (_curto $alvo); return }
    _titulo '📊' 'o que mais ocupa' (_curto $alvo)
    $maior = [Math]::Max(1, $itens[0].Tam)
    foreach ($i in $itens) { _w ("  $C_TEXT{0,7}$C_OFF  {1}  $C_CMD{2}$C_OFF`n" -f (_humano $i.Tam), (_barra $i.Tam $maior 16), $i.Nome) }
}
function ff([string]$texto) {
    if (-not $texto) {
        if (-not (_precisa fzf fzf)) { return }
        $arq = Get-ChildItem -Recurse -File -ErrorAction Ignore | Where-Object { $_.FullName -notmatch '[\\/](node_modules|\.git)[\\/]' } |
            ForEach-Object { Resolve-Path -Relative $_.FullName } | fzf --prompt='arquivo ❯ '
        if ($arq) { _w "  $C_TEXT$arq$C_OFF`n" }
        return
    }
    _titulo '🔍' 'procurando' $texto
    if (_tem rg) { rg --line-number --color=always -- $texto; return }
    $achou = Get-ChildItem -Recurse -File -ErrorAction Ignore | Where-Object { $_.FullName -notmatch '[\\/](node_modules|\.git)[\\/]' } |
        Select-String -Pattern $texto -SimpleMatch
    if ($achou) { $achou | ForEach-Object { _w "  $C_CMD$(Resolve-Path -Relative $_.Path)${C_OFF}:$C_DIM$($_.LineNumber)${C_OFF}: $($_.Line.Trim())`n" } }
    else { _aviso "nada encontrado pra '$texto'" }
}

# ==========================================
# UTILITÁRIOS
# ==========================================
function clip { $t = if ($args) { if (Test-Path -LiteralPath "$($args[0])") { Get-Content -Raw -LiteralPath $args[0] } else { "$args" } } else { $input | Out-String }; Set-Clipboard -Value $t.TrimEnd(); _ok 'copiado' "$(_plural $t.TrimEnd().Length caractere caracteres)" }
function colar { Get-Clipboard }
function json([string]$arq) {
    $txt = if ($arq) { Get-Content -Raw -LiteralPath $arq } else { $input | Out-String }
    try { $txt | ConvertFrom-Json | ConvertTo-Json -Depth 30 } catch { _err 'JSON inválido' $_.Exception.Message }
}
function uuid { $u = [guid]::NewGuid().ToString(); $u; try { Set-Clipboard $u; _dica 'copiado pro clipboard' } catch { $null = $_ } }
function senha([int]$n = 20) {
    if ($n -lt 8) { _uso 'senha [tamanho]' 'gera uma senha aleatória (mínimo 8, padrão 20)'; return }
    $chars = [char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%^*_+=-'
    $bytes = New-Object byte[] $n
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $s = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
    $s; try { Set-Clipboard $s; _dica 'copiada pro clipboard' } catch { $null = $_ }
}
function b64([string]$t) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($t)) }
function b64d([string]$t) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($t)) }
function epoch([string]$ts) {
    if (-not $ts) { return [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
    if ($ts -notmatch '^\d+$') { _uso 'epoch [timestamp]' 'converte segundos desde 1970 em data (milissegundos também valem)'; return }
    $n = [long]$ts; if ($ts.Length -gt 11) { $n = [long]($n / 1000) }
    [DateTimeOffset]::FromUnixTimeSeconds($n).ToLocalTime().ToString('dd/MM/yyyy HH:mm:ss')
}
function calc {
    $expr = ("$args" -replace ',', '.')
    if (-not $expr) { _uso 'calc <expressão>' 'ex.: calc 1500*1.07   ·   calc "(3+4)*2"'; return }
    if ($expr -notmatch '^[0-9.+*/%() -]+$') { _err 'só números e + - * / % ( )' 'ex.: calc 1500*1.07'; return }
    $r = (New-Object Data.DataTable).Compute($expr, $null)
    [double]$r
}
function loadenv([string]$arq = '.env') {
    if (-not (Test-Path -LiteralPath $arq)) { _err "não achei $arq" 'uso: loadenv [arquivo]  (padrão: .env da pasta atual)'; return }
    $n = 0
    foreach ($l in Get-Content -LiteralPath $arq) {
        if ($l -match '^\s*(export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $v = $Matches[3]; if ($v -match '^"(.*)"$' -or $v -match "^'(.*)'$") { $v = $Matches[1] }
            Set-Item -Path "env:$($Matches[2])" -Value $v; $n++
        }
    }
    _ok "$(_plural $n variável variáveis) carregadas" $arq
}
function venv {
    if ($env:VIRTUAL_ENV) { deactivate; _ok 'venv desativado'; return }
    $py = if (_tem python) { 'python' } elseif (_tem python3) { 'python3' } else { $null }
    if (-not $py) { _err 'python não está instalado' 'winget install Python.Python.3.12'; return }
    if (-not (Test-Path .venv)) { if (-not (_rodar 'criando .venv' { param($p, $d) Set-Location $d; & $p -m venv .venv } @($py, (Get-Location).Path))) { return } }
    $act = if (Test-Path .venv\Scripts\Activate.ps1) { '.venv\Scripts\Activate.ps1' } else { '.venv/bin/Activate.ps1' }
    . $act; _ok 'venv ativo' 'rode venv de novo pra desativar'
}
function cheat([string]$cmd) {
    if (-not $cmd) { _uso 'cheat <comando>' 'exemplos prontos de uso (cheat.sh)'; return }
    try { (Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 "https://cheat.sh/$($cmd)?T").Content } catch { _err 'não consegui buscar' 'tá sem internet?' }
}

# ==========================================
# GIT — os mesmos atalhos do bash
# ==========================================
function _em_repo_git {
    git rev-parse --git-dir *> $null
    if ($LASTEXITCODE -eq 0) { return $true }
    _err 'aqui não é um repositório git' 'entre na pasta do projeto ou rode: git init'
    return $false
}
# _git — roda o git em silêncio; deu errado: mostra as linhas do erro (sem os hint:)
function _git {
    $Global:_GIT_SAIDA = (& git @args 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        _w "$_CL  $C_ERR✗$C_OFF  ${C_TEXT}git $($args[0]) falhou$C_OFF`n"
        $Global:_GIT_SAIDA -split "`n" | Where-Object { $_.Trim() -and $_ -notmatch '^hint:' } | ForEach-Object { _w "     $C_DIM│$C_OFF $($_.TrimEnd())`n" }
        return $false
    }
    return $true
}
function _resumo_commit {
    $stat = (git -c core.quotepath=off show --shortstat --format= HEAD 2>$null | Out-String)
    $a = if ($stat -match '(\d+) file') { $Matches[1] } else { 0 }
    $i = if ($stat -match '(\d+) insertion') { $Matches[1] } else { 0 }
    $d = if ($stat -match '(\d+) deletion') { $Matches[1] } else { 0 }
    _kv 'branch' (git branch --show-current)
    _w ("     $C_DIM{0,-9}$C_OFF $C_WARN{1}$C_OFF`n" -f 'hash', (git rev-parse --short HEAD))
    _w ("     $C_DIM{0,-9}$C_OFF $C_TEXT{1}$C_OFF   $C_OK+{2}$C_OFF $C_ERR−{3}$C_OFF`n" -f 'arquivos', $a, $i, $d)
    _kv 'mensagem' (git log -1 --format=%s)
}
function _ja_no_remoto { git merge-base --is-ancestor HEAD '@{upstream}' 2>$null; return ($LASTEXITCODE -eq 0) }
function _branch_padrao {
    $ref = git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>$null
    if ($ref) { return ($ref -replace '^origin/', '') }
    foreach ($b in 'main', 'master', 'develop', 'trunk') { git show-ref --verify --quiet "refs/heads/$b"; if ($LASTEXITCODE -eq 0) { return $b } }
    return $null
}
function _url_remoto {
    $r = git remote get-url origin 2>$null
    if (-not $r) { _err "esse repositório não tem remoto 'origin'" 'conecte com: git remote add origin <url>'; return $null }
    $u = $r -replace '\.git$', ''
    if ($u -match '^git@([^:]+):(.+)$') { $u = "https://$($Matches[1])/$($Matches[2])" }
    elseif ($u -match '^ssh://([^@]+@)?(.+)$') { $u = "https://$($Matches[2])" }
    elseif ($u -match '^https://[^@]+@(.+)$') { $u = "https://$($Matches[1])" }
    return $u
}

function gs { if (_em_repo_git) { git status @args } }
function gl { if (_em_repo_git) { git log --oneline --graph --decorate --all @args } }
function gd { if (_em_repo_git) { git diff @args } }
function gds { if (_em_repo_git) { git diff --staged @args } }
function gb { if (_em_repo_git) { git branch @args } }
function ga {
    if (-not (_em_repo_git)) { return }
    $lista = $args
    if (-not $lista) {
        if (-not (_tem fzf)) { _uso 'ga <arquivo> [arquivo2 ...]' 'ga .   adiciona tudo desta pasta'; return }
        $lista = @(git ls-files --modified --others --deleted --exclude-standard | Sort-Object -Unique | fzf --multi --prompt='add ❯ ' --header='Tab marca · Enter confirma')
        if (-not $lista) { return }
    }
    if (-not (_git add -- @lista)) { return }
    $no_stage = @(git diff --cached --name-only -- @lista)
    _feito '+' 'adicionado ao stage' (_plural $no_stage.Count arquivo arquivos)
    $no_stage | Select-Object -First 8 | ForEach-Object { _w "     $C_OK+$C_OFF $C_TEXT$_$C_OFF`n" }
}
function gaa {
    if (-not (_em_repo_git)) { return }
    if (-not (git status --porcelain)) { _ok 'nada pra adicionar' 'árvore de trabalho limpa'; return }
    if (_git add --all) { _feito '+' 'tudo no stage' }
}
function gc {
    if (-not $args) { _uso 'gc "mensagem"' 'aspas são opcionais: gc arruma o menu'; return }
    if (-not (_em_repo_git)) { return }
    git diff --cached --quiet; if ($LASTEXITCODE -eq 0) { _err 'nada no stage pra commitar' 'use ga <arquivo> ou gaa antes — ou gac pra fazer tudo junto'; return }
    if (_git commit -m "$args") { _feito '◆' 'commit criado'; _resumo_commit }
}
function gac {
    if (-not $args) { _uso 'gac "mensagem"' 'add tudo + commit · aspas opcionais'; return }
    if (-not (_em_repo_git)) { return }
    if (-not (git status --porcelain)) { _err 'nada pra commitar' 'árvore de trabalho limpa'; return }
    if ((_git add --all) -and (_git commit -m "$args")) { _feito '◆' 'commit criado'; _resumo_commit }
}
$Global:_GCM_TIPOS = 'feat', 'fix', 'docs', 'style', 'refactor', 'perf', 'test', 'build', 'ci', 'chore', 'revert'
# _gcm_tipo nome 'quando usar' 'exemplo' ['observação'] - uma entrada do painel do gcm
function _gcm_tipo([string]$nome, [string]$desc, [string]$ex, [string]$obs) {
    _linha $nome $desc
    _w "  $(' ' * $Global:_LARG) ${C_DIM}↳ ex.: ${C_TEXT}$ex${C_OFF}`n"
    if ($obs) { _w "  $(' ' * $Global:_LARG) ${C_DIM}↳ $obs${C_OFF}`n" }
}
# _gcm_painel - o 'gcm' sem nada: cada tipo, quando usar e um exemplo (igual ao dev e ao help)
function _gcm_painel {
    $Global:_LARG = 10
    _cabecalho 'CONVENTIONAL COMMITS'
    _w "  ${C_DIM}↳ formato: ${C_TEXT}tipo(escopo): descrição${C_DIM} · o escopo (opcional) é a parte do projeto${C_OFF}`n"
    _secao 'tipos'
    _gcm_tipo 'feat' 'novidade pra quem usa: tela, botão, rota de API, comando, opção' 'feat(login): adiciona entrar com Google'
    _gcm_tipo 'fix' 'corrige o que tava errado: bug, crash, conta, brecha de segurança' 'fix(carrinho): corrige o total com cupom de desconto'
    _gcm_tipo 'docs' 'só documentação: README, comentários, guias, exemplos, CHANGELOG' 'docs(readme): explica a instalação no Windows'
    _gcm_tipo 'style' 'só a forma do código: espaços, indentação, aspas, ponto e vírgula' 'style: formata o projeto com o prettier' 'mudou o visual da tela (CSS)? aí é feat ou fix'
    _gcm_tipo 'refactor' 'reorganiza sem mudar o que faz: renomeia, divide, move, simplifica' 'refactor(api): separa as rotas em arquivos'
    _gcm_tipo 'perf' 'mais rápido ou mais leve: cache, menos consultas, menos memória' 'perf(busca): guarda os resultados em cache'
    _gcm_tipo 'test' 'só testes: cria, corrige ou melhora, sem mexer no código testado' 'test(login): cobre o caso de senha errada'
    _gcm_tipo 'build' 'como o projeto é montado: dependências, versões, Docker, bundler' 'build: atualiza o react para a versão 19'
    _gcm_tipo 'ci' 'a automação de cada push: GitHub Actions, pipelines, deploy' 'ci: roda os testes também no macOS'
    _gcm_tipo 'chore' 'manutenção que não entra nas outras: .gitignore, configs, scripts' 'chore: ignora a pasta dist no git' 'na dúvida entre chore e outro tipo, use o outro'
    _gcm_tipo 'revert' 'desfaz um commit anterior: diga na descrição qual foi' 'revert: desfaz "feat(login): adiciona botão"'
    _secao 'como usar'
    $Global:_LARG = 30
    _linha 'gcm fix corrige o frete' '→ fix: corrige o frete'
    _linha 'gcm feat:login adiciona botão' '→ feat(login): adiciona botão'
    _linha 'gcm feat:api! muda as rotas' '→ feat(api)!: muda as rotas'
    _w "`n"
    _dica 'o ! avisa que quebra compatibilidade: quem usa vai precisar mudar algo'
    _dica 'antes, ponha os arquivos no stage com ga ou gaa · aspas são opcionais'
    _dica 'mudou coisas de tipos diferentes? faça um commit pra cada'
    _w "`n"
}
function gcm {
    if (-not $args) { _gcm_painel; return }
    if (-not (_em_repo_git)) { return }
    git diff --cached --quiet; if ($LASTEXITCODE -eq 0) { _err 'nada no stage pra commitar' 'use ga <arquivo> ou gaa antes'; return }
    $cab = "$($args[0])".TrimEnd(':'); $desc = ($args | Select-Object -Skip 1) -join ' '
    if ($cab -notmatch '^([a-z]+)(\(([^)]+)\)|:([^!]+))?(!)?$') { _err "tipo inválido: $cab" 'use tipo ou tipo:escopo — ex.: gcm feat:login adiciona botão'; return }
    $tipo = $Matches[1]; $escopo = if ($Matches[3]) { $Matches[3] } else { $Matches[4] }; $quebra = $Matches[5]
    if ($Global:_GCM_TIPOS -notcontains $tipo) { _err "'$tipo' não é um tipo do Conventional Commits" "tipos: $($Global:_GCM_TIPOS -join ' ')"; return }
    if (-not $desc) { _err 'falta a descrição do commit' "ex.: gcm $cab adiciona botão de login"; return }
    $msg = $tipo + $(if ($escopo) { "($escopo)" } else { '' }) + $quebra + ": $desc"
    if (_git commit -m $msg) { _feito '◆' 'commit criado'; _resumo_commit }
}
function gamend {
    if (-not (_em_repo_git)) { return }
    if (-not $args -and -not (git status --porcelain)) { _err 'nada pra emendar' 'sem mudanças novas — pra só trocar a mensagem: gamend "nova mensagem"'; return }
    $enviado = _ja_no_remoto
    if (-not (_git add --all)) { return }
    $ok = if ($args) { _git commit --amend -m "$args" } else { _git commit --amend --no-edit }
    if ($ok) { _feito '◆' 'último commit atualizado'; _resumo_commit; if ($enviado) { _aviso 'esse commit já estava no GitHub' 'o próximo envio precisa ser: git push --force-with-lease' } }
}
function gundo {
    if (-not (_em_repo_git)) { return }
    git rev-parse -q --verify HEAD~1 *> $null; if ($LASTEXITCODE -ne 0) { _err 'não tem commit anterior pra voltar' 'esse é o primeiro commit do repositório'; return }
    $h = git rev-parse --short HEAD; $m = git log -1 --format=%s; $enviado = _ja_no_remoto
    if (_git reset --soft HEAD~1) { _feito '↶' 'commit desfeito' "$h $m"; _dica 'as mudanças voltaram pro stage — nada foi perdido'; if ($enviado) { _aviso 'esse commit já estava no GitHub' }
    }
}
function gwip {
    if (-not (_em_repo_git)) { return }
    if (-not (git status --porcelain)) { _ok 'nada pra salvar' 'árvore de trabalho limpa'; return }
    if ((_git add --all) -and (_git commit --no-verify -m 'wip: trabalho em andamento [skip ci]')) { _feito '◆' 'trabalho salvo num commit wip'; _dica 'pra continuar de onde parou: gunwip' }
}
function gunwip {
    if (-not (_em_repo_git)) { return }
    if ((git log -1 --format=%s) -notmatch '^wip:') { _err 'o último commit não é um wip' 'nada foi mexido — veja com: gl'; return }
    if (_git reset HEAD~1) { _feito '↶' 'wip desfeito' 'as mudanças estão de volta nos arquivos' }
}
function grst { if (-not $args) { _uso 'grst <arquivo>' 'tira do stage — a mudança continua no arquivo'; return }; if ((_em_repo_git) -and (_git restore --staged -- @args)) { _feito '−' 'fora do stage' "$args" } }
function grs {
    if (-not $args) { _uso 'grs <arquivo>' 'joga fora as mudanças e volta o arquivo pro último commit'; return }
    if (-not (_em_repo_git)) { return }
    if (-not (_confirma "descartar as mudanças de $args? não tem volta")) { _cancelado; return }
    if (_git restore -- @args) { _feito '↶' 'mudanças descartadas' "$args" }
}
function gst {
    if (-not (_em_repo_git)) { return }
    $qtd = @(git status --porcelain).Count
    if ($qtd -eq 0) { _ok 'nada pra guardar' 'árvore de trabalho limpa'; return }
    $ok = if ($args) { _git stash push -u -m "$args" } else { _git stash push -u }
    if ($ok) { _feito '▣' (_plural $qtd 'arquivo guardado' 'arquivos guardados') 'stash@{0}'; _dica 'recupere com: gstp' }
}
function gstp {
    if (-not (_em_repo_git)) { return }
    if (-not (git stash list)) { _err 'nada guardado no stash' 'guarde mudanças com: gst'; return }
    $desc = git stash list -1 --format=%s
    if (_git stash pop @args) { _feito '↺' 'mudanças recuperadas' $desc }
}
function gsl { if (_em_repo_git) { git stash list --format='%gd  %cr  %s' } }
function gp {
    if (-not (_em_repo_git)) { return }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    if ($args) { _pendente 'enviando...'; if (_git push @args) { _feito '↑' 'push feito' (_tempo $sw) }; return }
    $branch = git branch --show-current
    if (-not $branch) { _err 'você não está em nenhuma branch (HEAD solto)' 'entre numa com: gco <branch>'; return }
    git rev-parse -q --verify '@{upstream}' *> $null
    if ($LASTEXITCODE -ne 0) {
        _pendente "publicando $branch..."
        if (_git push -u origin $branch) { _feito '↑' 'branch publicada' "$branch → origin/$branch · $(_tempo $sw)" }
        return
    }
    $qtd = [int](git rev-list --count '@{upstream}..HEAD')
    if ($qtd -eq 0) { _ok 'nada pra enviar' "$branch já está igual ao remoto"; return }
    _pendente "enviando $(_plural $qtd commit commits)..."
    if (_git push) { _feito '↑' (_plural $qtd 'commit enviado' 'commits enviados') "$branch · $(_tempo $sw)" }
    elseif ($Global:_GIT_SAIDA -match 'rejected') { _dica 'o remoto tem commits que você não tem — rode gpl e depois gp' }
}
function gpl {
    if (-not (_em_repo_git)) { return }
    $sw = [Diagnostics.Stopwatch]::StartNew(); $antes = git rev-parse -q --verify HEAD
    _pendente 'buscando novidades...'
    $env:GIT_MERGE_AUTOEDIT = 'no'
    $ok = _git pull @args
    Remove-Item env:GIT_MERGE_AUTOEDIT -ErrorAction Ignore
    if (-not $ok) { if (git diff --name-only --diff-filter=U) { _dica 'conflito! arrume os arquivos marcados e finalize com: gaa e gc "merge"' }; return }
    $depois = git rev-parse -q --verify HEAD
    if ($antes -eq $depois) { _ok 'já estava em dia' "nada novo no remoto · $(_tempo $sw)"; return }
    $qtd = if ($antes) { [int](git rev-list --count "$antes..$depois") } else { [int](git rev-list --count HEAD) }
    _feito '↓' (_plural $qtd 'commit recebido' 'commits recebidos') (_tempo $sw)
}
function gf {
    if (-not (_em_repo_git)) { return }
    $sw = [Diagnostics.Stopwatch]::StartNew(); _pendente 'conferindo o remoto...'
    if (-not (_git fetch --prune @args)) { return }
    $atras = git rev-list --count 'HEAD..@{upstream}' 2>$null
    if (-not $atras) { _ok 'fetch feito' "esta branch ainda não está no remoto · $(_tempo $sw)" }
    elseif ([int]$atras -eq 0) { _ok 'tudo em dia' "nada novo no remoto · $(_tempo $sw)" }
    else { _feito '↓' "$(_plural ([int]$atras) 'commit novo' 'commits novos') no remoto" (_tempo $sw); _dica 'traga com: gpl' }
}
function gup([string]$base) {
    if (-not (_em_repo_git)) { return }
    if (-not $base) { $base = _branch_padrao }
    if (-not $base) { _err 'não descobri a branch principal' 'diga qual: gup main'; return }
    $atual = git branch --show-current
    if ($atual -eq $base) { gpl; return }
    $antes = git rev-parse -q --verify "refs/heads/$base"
    if (-not (_git fetch origin "${base}:${base}")) { return }
    $depois = git rev-parse -q --verify "refs/heads/$base"
    if ($antes -eq $depois) { _ok "$base já estava em dia" "você continua na $atual"; return }
    _feito '↓' "$base atualizada" "você continua na $atual"; _dica "trazer pra cá: gin $base · gm $base"
}
function gco {
    if (-not (_em_repo_git)) { return }
    $alvo = $args
    if (-not $alvo) {
        if (-not (_tem fzf)) { _uso 'gco <branch>'; return }
        $atual = git branch --show-current
        $alvo = @(git branch --format='%(refname:short)' | Where-Object { $_ -ne $atual } | fzf --prompt='branch ❯ ')
        if (-not $alvo) { return }
    }
    $antes = git branch --show-current
    if (-not (_git checkout @alvo)) { if ($Global:_GIT_SAIDA -match 'would be overwritten') { _dica 'guarde as mudanças antes: gst → gco → gstp' }; return }
    $depois = git branch --show-current
    if ($depois -and $antes -ne $depois) { _feito '⇄' "agora em $depois" "saiu de $antes" } else { _ok 'checkout feito' "$alvo" }
}
function gbr {
    if (-not (_em_repo_git)) { return }
    $atual = git branch --show-current
    git for-each-ref --sort=-committerdate refs/heads --format='%(refname:short)|%(committerdate:relative)|%(subject)' | ForEach-Object {
        $n, $q, $s = $_ -split '\|', 3
        $m = if ($n -eq $atual) { '*' } else { ' ' }
        _w ("  $C_OK{0}$C_OFF $C_WARN{1,-24}$C_OFF $C_DIM{2,-16}$C_OFF $C_TEXT{3}$C_OFF`n" -f $m, $n, $q, $s)
    }
}
function gcb([string]$nome) {
    if (-not $nome) { _uso 'gcb <nome-da-branch>' 'cria a partir da branch atual e já entra nela'; return }
    if (-not (_em_repo_git)) { return }
    $origem = git branch --show-current
    if (_git checkout -b $nome) { _feito '🌿' "branch $nome criada" "a partir de $origem · você já está nela"; _dica 'publique quando quiser com: gp' }
}
function gnew([string]$nome) {
    if (-not $nome) { _uso 'gnew <nome-da-branch>' 'cria, entra e já publica no remoto'; return }
    if (-not (_em_repo_git)) { return }
    if (-not (_git checkout -b $nome)) { return }
    _feito '🌿' "branch $nome criada"
    _pendente 'publicando...'
    if (_git push -u origin $nome) { _feito '↑' 'publicada no remoto' "origin/$nome" } else { _dica 'a branch local existe, só o envio falhou — publique depois com: gp' }
}
function gin([string]$alvo) {
    if (-not (_em_repo_git)) { return }
    if (-not $alvo) { _uso 'gin <branch>' 'mostra os commits que entram na branch atual com um merge'; return }
    git rev-parse -q --verify "$alvo^{commit}" *> $null; if ($LASTEXITCODE -ne 0) { _err "branch '$alvo' não existe" 'veja as locais com: gb'; return }
    $atual = git branch --show-current
    $qtd = [int](git rev-list --count "HEAD..$alvo")
    if ($qtd -eq 0) { _ok 'nada novo pra entrar' "$atual já tem tudo de $alvo"; return }
    _titulo '⇉' "$(_plural $qtd 'commit entra' 'commits entram') na $atual" "vindo de $alvo"
    git --no-pager log --oneline --color=always -30 "HEAD..$alvo" | ForEach-Object { _w "     $_`n" }
    _dica "ver o código que vem: git diff HEAD...$alvo  ·  trazer: gm $alvo"
}
function gm([string]$alvo) {
    if (-not $alvo) { _uso 'gm <branch>' 'traz os commits da <branch> pra branch atual'; return }
    if (-not (_em_repo_git)) { return }
    $atual = git branch --show-current
    $qtd = git rev-list --count "HEAD..$alvo" 2>$null
    if (-not $qtd) { _err "branch '$alvo' não existe" 'veja as branches com: gb'; return }
    if ([int]$qtd -eq 0) { _ok 'nada pra trazer' "$atual já tem tudo de $alvo"; return }
    $env:GIT_MERGE_AUTOEDIT = 'no'; $ok = _git merge $alvo; Remove-Item env:GIT_MERGE_AUTOEDIT -ErrorAction Ignore
    if ($ok) { _feito '⇉' 'merge feito' "$alvo → $atual · $(_plural ([int]$qtd) commit commits)" }
    elseif (git diff --name-only --diff-filter=U) { _dica "conflito! arrume os arquivos marcados e finalize com: gaa e gc `"merge $alvo`""; _dica 'pra desistir do merge: git merge --abort' }
}
function gbd([string]$nome) {
    if (-not $nome) { _uso 'gbd <branch>' 'apaga a branch local'; return }
    if (-not (_em_repo_git)) { return }
    if ($nome -eq (git branch --show-current)) { _err 'não dá pra apagar a branch onde você está' 'troque antes com: gco <outra-branch>'; return }
    if (_git branch -d $nome) { _feito '−' "branch $nome apagada" } elseif ($Global:_GIT_SAIDA -match 'not fully merged') { _dica "ela tem commits que não foram mergeados. Tem certeza? git branch -D $nome" }
}
function gclean {
    if (-not (_em_repo_git)) { return }
    $bs = @(git branch --merged | Where-Object { $_ -notmatch '^\*|^\+' } | ForEach-Object { $_.Trim() } | Where-Object { $_ -notin 'main', 'master', 'develop' })
    if (-not $bs) { _ok 'nada pra limpar' 'nenhuma branch mergeada sobrando'; return }
    _titulo '🧹' 'branches já mergeadas'; $bs | ForEach-Object { _w "     $C_DIM•$C_OFF $C_TEXT$_$C_OFF`n" }
    if (-not (_confirma "apagar $(_plural $bs.Count branch branches)?")) { _cancelado; return }
    # -D e não -d: a lista veio do --merged, então nada se perde. O -d recusava a branch
    # com upstream que não contém ela (mesmo mergeada aqui), e o erro sumia
    $n = 0; foreach ($b in $bs) { if (_git branch -D $b) { $n++ } }
    if ($n) { _ok (_plural $n 'branch apagada' 'branches apagadas') }
}
function gcl([string]$url, [string]$pasta) {
    if (-not $url) { _uso 'gcl <url> [pasta]' 'clona o repositório e já entra nele'; return }
    if (-not $pasta) { $pasta = [IO.Path]::GetFileNameWithoutExtension(($url -replace '\.git$', '').TrimEnd('/')) }
    if (Test-Path $pasta) { _err "já existe '$pasta' aqui" 'escolha outro nome: gcl <url> <pasta>'; return }
    _pendente "clonando $pasta..."
    if (_git clone $url $pasta) { Set-Location $pasta; _feito '↓' 'clonado' $pasta }
}
function hub { if (-not (_em_repo_git)) { return }; $u = _url_remoto; if ($u) { Start-Process $u; _feito '🔗' 'abrindo no navegador' $u } }
function gpr([string]$base) {
    if (-not (_em_repo_git)) { return }
    $u = _url_remoto; if (-not $u) { return }
    $branch = git branch --show-current
    if (-not $base) { $base = _branch_padrao }; if (-not $base) { $base = 'main' }
    if ($branch -eq $base) { _err "você está na $($base): o PR sai de outra branch" 'crie uma com: gcb nome-da-mudanca'; return }
    git rev-parse -q --verify '@{upstream}' *> $null; if ($LASTEXITCODE -ne 0) { _aviso 'a branch ainda não está no remoto' 'publicando antes com o gp…'; gp }
    $link = if ($u -match 'gitlab') { "$u/-/merge_requests/new?merge_request%5Bsource_branch%5D=$branch" } else { "$u/compare/$base...$($branch)?expand=1" }
    Start-Process $link; _feito '🔗' 'abrindo o pull request no navegador' "$branch → $base"
}

# ==========================================
# NODE / NPM (pnpm, yarn e bun pelo arquivo de lock)
# ==========================================
function _raiz_node { $d = (Get-Location).Path; while ($d) { if (Test-Path (Join-Path $d 'package.json')) { return $d }; $pai = Split-Path $d -Parent; if ($pai -eq $d) { break }; $d = $pai }; return $null }
function _em_projeto_node { if (_raiz_node) { return $true }; _err 'aqui não é um projeto node (não achei package.json)' 'entre na pasta do projeto — ou crie um aqui com: npkg'; return $false }
function _pm {
    $r = _raiz_node; if (-not $r) { return 'npm' }
    if ((Test-Path (Join-Path $r 'pnpm-lock.yaml')) -and (_tem pnpm)) { return 'pnpm' }
    if ((Test-Path (Join-Path $r 'yarn.lock')) -and (_tem yarn)) { return 'yarn' }
    if (((Test-Path (Join-Path $r 'bun.lockb')) -or (Test-Path (Join-Path $r 'bun.lock'))) -and (_tem bun)) { return 'bun' }
    return 'npm'
}
function ni { if (-not (_em_projeto_node)) { return }; $pm = _pm; if (-not $args -or $pm -eq 'npm') { & $pm install @args } else { & $pm add @args } }
function nid { if (-not $args) { _uso 'nid <pacote>' 'instala como dependência de desenvolvimento'; return }; if (-not (_em_projeto_node)) { return }; $pm = _pm; if ($pm -eq 'npm') { npm install --save-dev @args } else { & $pm add -D @args } }
function nr { if (_em_projeto_node) { & (_pm) run @args } }
function nrd { if (_em_projeto_node) { & (_pm) run dev @args } }
function nrb { if (_em_projeto_node) { & (_pm) run build @args } }
function ns { if (_em_projeto_node) { & (_pm) start @args } }
function nt { if (_em_projeto_node) { & (_pm) test @args } }
function nout { if (_em_projeto_node) { & (_pm) outdated @args } }
function nfresh {
    if (-not (_em_projeto_node)) { return }
    $r = _raiz_node; $pm = _pm
    if (Test-Path (Join-Path $r 'node_modules')) { $null = _rodar 'apagando node_modules' { param($d) Remove-Item -Recurse -Force -LiteralPath (Join-Path $d 'node_modules') } @($r) }
    Push-Location $r; try { & $pm install } finally { Pop-Location }
}
function npkg([string]$nome) {
    if (Test-Path package.json) { _err 'já existe um package.json aqui' 'não sobrescrevo — edite ele ou apague antes'; return }
    if ((Get-Location).Path -eq $HOME) { _err 'você está na home, não numa pasta de projeto' 'entre nela antes: p · proj · mkcd nome'; return }
    if (-not $nome) { $nome = Split-Path (Get-Location).Path -Leaf }
    $n = $nome.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''
    $n = ($n.ToLower() -replace '\s+', '-' -replace '[^a-z0-9._~-]', '' -replace '^[._-]+', '' -replace '-+', '-').TrimEnd('-')
    if (-not $n) { $n = 'meu-projeto' }
    $autor = git config user.name 2>$null; if (-not $autor) { $autor = 'David Brian' }
    $pkg = [ordered]@{ name = $n; version = '1.0.0'; description = ''; type = 'module'; main = 'index.js'
        scripts = [ordered]@{ start = 'node index.js'; dev = 'node --watch index.js'; test = 'node --test' }
        keywords = @(); author = $autor; license = 'MIT' }
    [IO.File]::WriteAllText((Join-Path (Get-Location).Path 'package.json'), ($pkg | ConvertTo-Json -Depth 5) + "`n")
    _ok 'package.json criado' $n
    _kv 'scripts' 'ns → node index.js · nrd → recarrega sozinho · nt → testes'
}

# ==========================================
# DOCKER
# ==========================================
function _em_docker {
    if (-not (_precisa docker Docker.DockerDesktop)) { return $false }
    docker info *> $null
    if ($LASTEXITCODE -eq 0) { return $true }
    _err 'o docker não está rodando' 'abra o Docker Desktop e espere ele ficar verde'
    return $false
}
function _escolher_container([string]$prompt, [switch]$Todos) {
    if (-not (_tem fzf)) { _err 'diga o nome do container' 'veja os nomes com: dpsa'; return $null }
    $f = if ($Todos) { '-a' } else { $null }
    docker ps $f --format '{{.Names}}' | fzf --prompt=$prompt
}
function dps { if (_em_docker) { docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}' @args } }
function dpsa { if (_em_docker) { docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' @args } }
function dimg { if (_em_docker) { docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}' @args } }
function dlog([string]$c) { if (-not (_em_docker)) { return }; if (-not $c) { $c = _escolher_container 'logs de ❯ ' -Todos }; if ($c) { _titulo '📜' "logs de $c" 'Ctrl+C sai'; docker logs -f --tail 100 $c } }
function dsh([string]$c) { if (-not (_em_docker)) { return }; if (-not $c) { $c = _escolher_container 'entrar em ❯ ' }; if ($c) { docker exec -it $c sh -c 'command -v bash > /dev/null && exec bash || exec sh' } }
function dstop { if (-not (_em_docker)) { return }; $a = if ($args) { $args } else { @(_escolher_container 'parar ❯ ') }; if ($a) { docker stop @a } }
function drm { if (-not (_em_docker)) { return }; $a = if ($args) { $args } else { @(_escolher_container 'apagar ❯ ' -Todos) }; if ($a -and (_confirma "apagar $a?")) { docker rm @a } }
function dclean { if (-not (_em_docker)) { return }; docker system df; if (_confirma 'limpar containers parados, redes e imagens órfãs? (volumes ficam)') { docker system prune -f @args } else { _cancelado } }
function dc { if (_tem docker) { docker compose @args } elseif (_tem docker-compose) { docker-compose @args } else { _err 'docker compose não encontrado' } }
function dcu { dc up -d @args; if ($LASTEXITCODE -eq 0) { _ok 'serviços no ar'; dc ps } }
function dcd { dc down @args }
function dcl { dc logs -f --tail 100 @args }
function dcr { dc restart @args }
function dstats { if (_em_docker) { docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}' } }

# ==========================================
# PROCESSOS, PORTAS E REDE
# ==========================================
function _quem_usa_porta([int]$porta) {
    if (Get-Command Get-NetTCPConnection -ErrorAction Ignore) {
        $c = Get-NetTCPConnection -LocalPort $porta -State Listen -ErrorAction Ignore | Select-Object -First 1
        if ($c) { return [pscustomobject]@{ Pid = $c.OwningProcess; Nome = (Get-Process -Id $c.OwningProcess -ErrorAction Ignore).ProcessName } }
        return $null
    }
    if (_tem ss) {
        $l = ss -lptnH "sport = :$porta" 2>$null | Select-Object -First 1
        if (-not $l) { return $null }
        if ($l -match 'pid=(\d+)') { return [pscustomobject]@{ Pid = [int]$Matches[1]; Nome = (Get-Process -Id ([int]$Matches[1]) -ErrorAction Ignore).ProcessName } }
        return [pscustomobject]@{ Pid = $null; Nome = $null }
    }
    if (_tem lsof) { $id = lsof -nP "-iTCP:$porta" -sTCP:LISTEN -t 2>$null | Select-Object -First 1; if ($id) { return [pscustomobject]@{ Pid = [int]$id; Nome = (Get-Process -Id ([int]$id) -ErrorAction Ignore).ProcessName } } }
    return $null
}
function port {
    $matar = $false; $p = $args
    if ($args.Count -gt 0 -and $args[0] -eq '-k') { $matar = $true; $p = $args | Select-Object -Skip 1 }
    if (-not $p -or "$($p[0])" -notmatch '^\d+$') { _uso 'port <número>' 'port -k <número>   encerra quem está usando'; return }
    $porta = [int]$p[0]
    $u = _quem_usa_porta $porta
    if (-not $u) { _ok "porta $porta livre"; return }
    $nome = if ($u.Nome) { $u.Nome } else { 'processo de outro usuário' }
    $id = if ($u.Pid) { $u.Pid } else { '?' }
    _w "  $C_WARN●$C_OFF  ${C_TEXT}porta $porta ocupada$C_OFF   $C_DIM$nome · pid $id$C_OFF`n"
    if (-not $matar) { _dica "pra liberar: port -k $porta"; return }
    try { Stop-Process -Id $u.Pid -ErrorAction Stop; _ok 'processo encerrado' "porta $porta liberada" } catch { _err 'não consegui encerrar' 'é de outro usuário? abra o terminal como administrador' }
}
function portas {
    if (Get-Command Get-NetTCPConnection -ErrorAction Ignore) {
        Get-NetTCPConnection -State Listen | Sort-Object LocalPort -Unique | ForEach-Object {
            _w ("  $C_CMD{0,-7}$C_OFF $C_DIM{1,-18}$C_OFF $C_TEXT{2,-18}$C_OFF $C_DIM{3}$C_OFF`n" -f $_.LocalPort, $_.LocalAddress, (Get-Process -Id $_.OwningProcess -ErrorAction Ignore).ProcessName, $_.OwningProcess)
        }
    } elseif (_tem ss) { ss -tlnp } elseif (_tem lsof) { lsof -nP -iTCP -sTCP:LISTEN } else { netstat -an | Select-String LISTEN }
}
function serve([string]$porta = '8000') {
    if ($porta -notmatch '^\d+$') { _uso 'serve [porta]' 'padrão: 8000'; return }
    $py = if (_tem python) { 'python' } elseif (_tem python3) { 'python3' } else { $null }
    if (-not $py) { _err 'python não está instalado' 'winget install Python.Python.3.12'; return }
    if (_quem_usa_porta ([int]$porta)) { _err "porta $porta ocupada" "veja quem é com: port $porta  ·  ou use outra: serve 8080"; return }
    _titulo '🌐' 'servindo' (_curto); _w "     ${C_OK}http://localhost:$porta$C_OFF`n     ${C_DIM}Ctrl+C pra parar$C_OFF`n`n"
    & $py -m http.server $porta --bind 127.0.0.1
}
function _porta_aberta([string]$h, [int]$p) {
    $t = New-Object Net.Sockets.TcpClient
    try { $a = $t.BeginConnect($h, $p, $null, $null); $ok = $a.AsyncWaitHandle.WaitOne(800) -and $t.Connected; return $ok } catch { return $false } finally { $t.Close() }
}
function waitport([string]$alvo, [int]$limite = 60) {
    if (-not $alvo) { _uso 'waitport [host:]porta [segundos]' 'espera a porta aceitar conexão (padrão: localhost, 60s)'; return }
    $h, $p = if ($alvo -match '^(.+):(\d+)$') { $Matches[1], [int]$Matches[2] } else { 'localhost', [int]$alvo }
    $ok = _rodar "esperando ${h}:$p" { param($h, $p, $lim) $fim = (Get-Date).AddSeconds($lim)
        while ((Get-Date) -lt $fim) { $t = New-Object Net.Sockets.TcpClient; try { $a = $t.BeginConnect($h, $p, $null, $null); if ($a.AsyncWaitHandle.WaitOne(800) -and $t.Connected) { return } } catch { $null = $_ } finally { $t.Close() }; Start-Sleep -Milliseconds 500 }
        throw "ninguém respondeu em ${lim}s" } @($h, $p, $limite)
    if (-not $ok) { _dica 'o serviço subiu mesmo? (dps, dcl)' }
}
function meuip {
    $loc = if (Get-Command Get-NetIPAddress -ErrorAction Ignore) {
        (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^(127|169\.254)\.' } | Select-Object -First 1).IPAddress
    } else { ([Net.Dns]::GetHostAddresses([Net.Dns]::GetHostName()) | Where-Object { $_.AddressFamily -eq 'InterNetwork' -and $_.ToString() -notmatch '^127\.' } | Select-Object -First 1) }
    _kv 'local' "$loc"
    if (_rodar 'consultando o IP público' { (Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 https://api.ipify.org).Content } -Quieto) { _kv 'público' $Global:_RODAR_SAIDA } else { _kv 'público' 'sem resposta (tá sem internet?)' }
}
function rede {
    _titulo '🌐' 'diagnóstico de rede'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try { $ip = [Net.Dns]::GetHostAddresses('github.com') | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1; $okDns = [bool]$ip } catch { $okDns = $false }
    if ($okDns) { _feito '✓' 'DNS' "github.com → $ip · $(_tempo $sw)" } else { _err 'DNS' 'não consegui traduzir github.com em IP' }
    $sw.Restart()
    try { $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 6 https://www.google.com/generate_204; $okHttp = $r.StatusCode -lt 400 } catch { $okHttp = $false }
    if ($okHttp) { _feito '✓' 'internet' "HTTPS ok · $(_tempo $sw)" } else { _err 'internet' 'HTTPS não passou' }
    $okPing = $false
    try { $p = Test-Connection 1.1.1.1 -Count 2 -ErrorAction Stop; $okPing = $true; $ms = ($p | ForEach-Object { if ($_.PSObject.Properties['Latency']) { $_.Latency } else { $_.ResponseTime } } | Measure-Object -Average).Average; _feito '✓' 'latência' ("1.1.1.1 · média {0:N0}ms" -f $ms) } catch { _aviso 'latência' 'ping bloqueado ou sem resposta' }
    _w "`n"
    if ($okHttp) { _ok 'conexão funcionando' }
    elseif ($okPing -and -not $okDns) { _err 'o DNS está com problema (a internet chega, os nomes não)' 'teste outro DNS: 1.1.1.1 ou 8.8.8.8' }
    elseif ($okDns) { _err 'o DNS responde mas o HTTPS não passa' 'proxy, firewall ou portal de login do Wi-Fi?' }
    else { _err 'sem internet' 'reinicie o roteador; se continuar, é com o provedor' }
}
function httpcheck([string]$url) {
    if (-not $url) { _uso 'httpcheck <url>' 'código HTTP e quanto levou'; return }
    if ($url -notmatch '://') { $url = "https://$url" }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try { $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 20 -Uri $url -MaximumRedirection 0 -ErrorAction Stop; $cod = [int]$r.StatusCode; $tam = $r.RawContentLength }
    catch { if ($_.Exception.Response) { $cod = [int]$_.Exception.Response.StatusCode; $tam = 0 } else { _err "não consegui acessar $url" $_.Exception.Message; return } }
    $cor = if ($cod -lt 300) { $C_OK } elseif ($cod -lt 400) { $C_ACCENT } elseif ($cod -lt 500) { $C_WARN } else { $C_ERR }
    _w "  $cor●$C_OFF  ${C_TEXT}HTTP $cod$C_OFF   $C_DIM$url$C_OFF`n"
    _kv 'total' "$(_tempo $sw) · $(_humano $tam)"
}
function psg([string]$termo) {
    if (-not $termo) { _uso 'psg <termo>' 'acha processos: psg node'; return }
    $l = Get-Process | Where-Object { $_.ProcessName -like "*$termo*" }
    if (-not $l) { _ok "nenhum processo com '$termo'"; return }
    $l | Sort-Object CPU -Descending | Format-Table Id, ProcessName, @{ n = 'CPU(s)'; e = { [int]$_.CPU } }, @{ n = 'Memória'; e = { _humano $_.WorkingSet64 } } -AutoSize
}
function pk([string]$termo) {
    $l = @(Get-Process | Where-Object { -not $termo -or $_.ProcessName -like "*$termo*" })
    if (_tem fzf) { $sel = $l | ForEach-Object { '{0,-8} {1}' -f $_.Id, $_.ProcessName } | fzf --multi --prompt='encerrar ❯ ' --header='Tab marca vários · Enter encerra' }
    else { _uso 'pk <nome>' 'sem o fzf, diga o nome: pk node'; return }
    if (-not $sel) { return }
    $ids = @($sel | ForEach-Object { [int](($_ -split '\s+')[0]) })
    if (-not (_confirma "encerrar $(_plural $ids.Count processo processos) ($ids)?")) { _cancelado; return }
    Stop-Process -Id $ids -ErrorAction Ignore; Start-Sleep -Seconds 2
    $vivos = @($ids | Where-Object { Get-Process -Id $_ -ErrorAction Ignore })
    if (-not $vivos) { _ok (_plural $ids.Count 'processo encerrado' 'processos encerrados'); return }
    if (_confirma "$vivos não saíram. forçar?") { Stop-Process -Id $vivos -Force; _ok 'forçado' } else { _cancelado }
}
function _top([string]$campo, [int]$n) {
    $l = if ($campo -eq 'cpu') { Get-Process | Sort-Object CPU -Descending } else { Get-Process | Sort-Object WorkingSet64 -Descending }
    $l = $l | Select-Object -First $n
    $maior = if ($campo -eq 'cpu') { [Math]::Max(1, $l[0].CPU) } else { [Math]::Max(1, $l[0].WorkingSet64) }
    _w ("`n  $C_DIM{0,-8} {1,8} {2,9}  {3,-16} {4}$C_OFF`n" -f 'PID', 'CPU(s)', 'MEMÓRIA', '', 'PROCESSO')
    foreach ($p in $l) { $v = if ($campo -eq 'cpu') { $p.CPU } else { $p.WorkingSet64 }; _w ("  $C_DIM{0,-8}$C_OFF $C_TEXT{1,8} {2,9}$C_OFF  {3} $C_CMD{4}$C_OFF`n" -f $p.Id, [int]$p.CPU, (_humano $p.WorkingSet64), (_barra $v $maior 16), $p.ProcessName) }
}
function topcpu([int]$n = 10) { _top cpu $n }
function topmem([int]$n = 10) { _top mem $n }
function mon { if (_tem btop) { btop } elseif (_tem htop) { htop } elseif ($Global:_DF_WINDOWS) { taskmgr } else { top } }

# ==========================================
# SISTEMA — limpeza, atualização, backup, timebox e o próprio terminal
# ==========================================
function lspkg { if (_tem winget) { winget list } elseif (_tem scoop) { scoop list } else { _err 'não achei winget nem scoop' } }
function rmpkg { if (-not $args) { _uso 'rmpkg <pacote>' 'descubra o nome com: lspkg'; return }; if (_tem winget) { winget uninstall @args } elseif (_tem scoop) { scoop uninstall @args } }

# Cada etapa: nome, teste (devolve $true se a etapa existe aqui), pastas medidas e o bloco que limpa
function _clean_etapas {
    $tmp = [IO.Path]::GetTempPath()
    $e = @(
        @{ Nome = 'temporários teus (+7 dias)'; Pastas = @($tmp); Bloco = { param($t) Get-ChildItem -LiteralPath $t -Force -ErrorAction Ignore | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Recurse -Force -ErrorAction Ignore }; Args = @($tmp) }
    )
    if ($Global:_DF_WINDOWS) {
        $win = Join-Path $env:WINDIR 'Temp'
        $e += @{ Nome = 'temporários do Windows'; Pastas = @($win); Bloco = { param($t) Get-ChildItem -LiteralPath $t -Force -ErrorAction Ignore | Remove-Item -Recurse -Force -ErrorAction Ignore }; Args = @($win) }
        $thumbs = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'
        $e += @{ Nome = 'miniaturas antigas'; Pastas = @(); Bloco = { param($t) Get-ChildItem -LiteralPath $t -Filter 'thumbcache_*.db' -ErrorAction Ignore | Remove-Item -Force -ErrorAction Ignore }; Args = @($thumbs) }
    }
    $npm = if ($Global:_DF_WINDOWS) { Join-Path $env:LOCALAPPDATA 'npm-cache\_cacache' } else { Join-Path $HOME '.npm/_cacache' }
    if (Test-Path $npm) { $e += @{ Nome = 'npm: cache de pacotes'; Pastas = @($npm); Bloco = { param($d) Remove-Item -Recurse -Force -LiteralPath $d -ErrorAction Ignore }; Args = @($npm) } }
    if (_tem pip) { $e += @{ Nome = 'pip: cache'; Pastas = @(); Bloco = { pip cache purge 2>&1 }; Args = @() } }
    if (_tem scoop) { $e += @{ Nome = 'scoop: downloads antigos'; Pastas = @(); Bloco = { scoop cleanup * 2>&1; scoop cache rm * 2>&1 }; Args = @() } }
    return $e
}
function _clean_medir([string[]]$pastas) {
    $t = 0
    foreach ($p in $pastas) { if ($p -and (Test-Path -LiteralPath $p)) { $t += [double](Get-ChildItem -LiteralPath $p -Recurse -Force -File -ErrorAction Ignore | Measure-Object Length -Sum).Sum } }
    return $t
}
function _livre_bytes { $d = (Get-PSDrive -Name ((Get-Location).Drive.Name) -ErrorAction Ignore); if ($d) { [double]$d.Free } else { 0 } }
# limpar [-n] — no PowerShell 7.3+ "clean" virou palavra reservada (o bloco clean {}),
# então o nome aqui é limpar. O clean continua valendo no Windows PowerShell 5.1.
function limpar {
    $simular = $args -contains '-n'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $etapas = _clean_etapas
    $titulo = if ($simular) { '🔎  LIMPEZA GERAL · SÓ SIMULANDO     ' } else { '🧹  LIMPEZA GERAL DO SISTEMA         ' }
    _w "$C_ACCENT╭────────────────────────────────────────╮$C_OFF`n$C_ACCENT│$C_OFF   $titulo$C_ACCENT│$C_OFF`n$C_ACCENT╰────────────────────────────────────────╯$C_OFF`n"
    $antesDisco = _livre_bytes; $total = 0; $i = 0; $rel = @()
    foreach ($e in $etapas) {
        $i++; _etapa $i $etapas.Count $e.Nome
        $antes = _clean_medir $e.Pastas
        if ($simular) { _feito '≈' "$(_humano $antes) em cache"; $total += $antes; $rel += , @($e.Nome, $antes); continue }
        if (_rodar $e.Nome $e.Bloco $e.Args -Quieto) {
            $lib = [Math]::Max(0, $antes - (_clean_medir $e.Pastas)); $total += $lib; $rel += , @($e.Nome, $lib)
            if ($lib -gt 0) { _feito '✓' "$(_humano $lib) liberados" } else { _feito '✓' 'já estava limpo' }
        } else { $rel += , @($e.Nome, -1) }
    }
    $noDisco = (_livre_bytes) - $antesDisco; if ($noDisco -gt $total) { $total = $noDisco }
    _w "`n$C_ACCENT╭────────────────────────────────────────╮$C_OFF`n"
    foreach ($r in $rel) {
        if ($r[1] -lt 0) { _w ("$C_ACCENT│$C_OFF  $C_ERR✗$C_OFF $C_TEXT{0,-28}$C_OFF ${C_ERR}falhou$C_OFF`n" -f $r[0]) }
        elseif ($r[1] -gt 0) { _w ("$C_ACCENT│$C_OFF  $C_OK✓$C_OFF $C_TEXT{0,-28}$C_OFF $C_OK{1,8}$C_OFF`n" -f $r[0], (_humano $r[1])) }
        else { _w ("$C_ACCENT│$C_OFF  $C_DIM· {0,-28} {1,8}$C_OFF`n" -f $r[0], '0') }
    }
    _w "$C_ACCENT├────────────────────────────────────────┤$C_OFF`n"
    if ($simular) { _w "$C_ACCENT│$C_OFF  🔎  Dá pra liberar: $C_OK$(_humano $total)$C_OFF`n" }
    elseif ($total -gt 0) { _w "$C_ACCENT│$C_OFF  💾  Total liberado: $C_OK$(_humano $total)$C_OFF`n" }
    else { _w "$C_ACCENT│$C_OFF  ✨  Sistema já estava limpo!`n" }
    _w "$C_ACCENT│$C_OFF  ⏱   Levou $([int]$sw.Elapsed.TotalSeconds)s`n$C_ACCENT╰────────────────────────────────────────╯$C_OFF`n"
}
if ($PSVersionTable.PSVersion.Major -lt 7) { function clean { limpar @args } }
function upgrade {
    $etapas = @()
    if (_tem winget) { $etapas += , @('winget', { winget upgrade --all --accept-source-agreements --accept-package-agreements }) }
    if (_tem scoop) { $etapas += , @('scoop', { scoop update; scoop update * }) }
    if (_tem choco) { $etapas += , @('choco', { choco upgrade all -y }) }
    if (-not $etapas) { _err 'não achei winget, scoop nem choco pra atualizar'; return }
    _cabecalho 'ATUALIZANDO O SISTEMA'
    $i = 0; foreach ($e in $etapas) { $i++; _etapa $i $etapas.Count $e[0]; & $e[1]; if ($LASTEXITCODE -eq 0) { _ok "$($e[0]) em dia" } else { _err "$($e[0]) não terminou" } }
}
function bkp {
    $destino = Join-Path (Join-Path $HOME 'dotfiles-backup') (Get-Date -Format 'yyyy-MM-dd_HH-mm')
    $null = New-Item -ItemType Directory -Force -Path $destino
    _titulo '💾' 'backup de configurações'
    $itens = @(@($PROFILE, 'Microsoft.PowerShell_profile.ps1'), @((Join-Path $HOME '.gitconfig'), '.gitconfig'), @($Global:DOTFILES_LOCAL, 'local.ps1'))
    if ($env:APPDATA) { $itens += , @((Join-Path $env:APPDATA 'Code\User\settings.json'), 'vscode-settings.json') }
    if ($env:LOCALAPPDATA) { $itens += , @((Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'), 'windows-terminal.json') }
    $n = 0; foreach ($it in $itens) { if ($it[0] -and (Test-Path -LiteralPath $it[0])) { Copy-Item -LiteralPath $it[0] -Destination (Join-Path $destino $it[1]); $n++; _w "     $C_OK✓$C_OFF $C_TEXT$($it[1])$C_OFF`n" } }
    _ok (_plural $n 'arquivo salvo' 'arquivos salvos') (_curto $destino)
}
function timebox([string]$min) {
    if (-not $min) { $min = "$Global:TIMEBOX_MIN" }
    if ($min -notmatch '^\d+$') { _uso 'timebox [minutos]' "padrão: $Global:TIMEBOX_MIN"; return }
    _titulo '⏳' "timebox de $min min" "termina $((Get-Date).AddMinutes([int]$min).ToString('HH:mm'))"
    _dica 'não saiu até lá? anota o gap e segue. revisita depois.'
    # numa tarefa de fundo (Start-Job): o terminal continua livre
    $minutos = [int]$min
    $null = Start-Job -ScriptBlock {
        $minutos = $using:minutos
        Start-Sleep -Seconds ($minutos * 60)
        Add-Type -AssemblyName System.Windows.Forms
        $n = New-Object System.Windows.Forms.NotifyIcon
        $n.Icon = [System.Drawing.SystemIcons]::Information
        $n.Visible = $true
        $n.ShowBalloonTip(10000, '⏱ Timebox encerrado', "Passaram $minutos minutos. Travou? Anota o gap e avança.", 'Info')
        Start-Sleep -Seconds 10
        $n.Dispose()
    }
}
# _df_versao_disco - o commit em que o repositório está, lido do .git direto (sem abrir o git).
# Guardado em _DF_VERSAO = o que ESTE PowerShell carregou: se outra janela (ou um git pull)
# atualizar o repo, o atualizar percebe a diferença.
function _df_versao_disco {
    $g = Join-Path $Global:DOTFILES '.git'; $h = Join-Path $g 'HEAD'
    if (-not (Test-Path $h -PathType Leaf)) { return '' }
    $head = Get-Content $h -TotalCount 1
    if ($head -notlike 'ref: *') { return $head }
    $ref = $head.Substring(5); $arq = Join-Path $g $ref
    if (Test-Path $arq -PathType Leaf) { return (Get-Content $arq -TotalCount 1) }
    $pk = Join-Path $g 'packed-refs'
    if (Test-Path $pk) { foreach ($l in Get-Content $pk) { $p = $l -split ' '; if ($p.Count -ge 2 -and $p[1] -eq $ref) { return $p[0] } } }
    return ''
}
$Global:_DF_VERSAO = _df_versao_disco
function atualizar {
    if (-not (Test-Path (Join-Path $Global:DOTFILES '.git'))) { _err "não achei o repositório dotfiles em $(_curto $Global:DOTFILES)" 'instale com: git clone https://github.com/briandevbr/dotfiles $HOME\dotfiles'; return }
    # só trava com mudança em arquivo do repo: arquivo novo solto (.vscode/, .idea/…) não se perde no pull
    $mexidos = @(git -C $Global:DOTFILES status --porcelain --untracked-files=no)
    if ($mexidos) {
        _err 'você mexeu nos dotfiles por aqui e isso não tá no GitHub'
        $mexidos | Select-Object -First 5 | ForEach-Object { _w "     ${C_DIM}│${C_OFF} $($_.Substring(3))`n" }
        if ($mexidos.Count -gt 5) { _w "     ${C_DIM}│ … e mais $($mexidos.Count - 5)${C_OFF}`n" }
        _dica "ver o que mudou: git -C $(_curto $Global:DOTFILES) diff · descartar: git -C $(_curto $Global:DOTFILES) restore ."; _dica "ajuste pessoal vai em $(_curto $Global:DOTFILES_LOCAL)"; return
    }
    $sw = [Diagnostics.Stopwatch]::StartNew(); $antes = git -C $Global:DOTFILES rev-parse HEAD
    if (-not (_rodar 'procurando atualização' { param($d) git -C $d pull --ff-only -q 2>&1; if ($LASTEXITCODE) { throw 'git pull falhou' } } @($Global:DOTFILES) -Quieto)) { _dica 'tá sem internet?'; return }
    $depois = git -C $Global:DOTFILES rev-parse HEAD
    # compara com o que ESTE PowerShell carregou: outra janela (ou um git pull) pode já ter trazido a versão nova
    $carregada = if ($Global:_DF_VERSAO) { $Global:_DF_VERSAO } else { $antes }
    git -C $Global:DOTFILES merge-base --is-ancestor $carregada $depois 2>$null; if ($LASTEXITCODE) { $carregada = $antes }
    if ($carregada -eq $depois) { _ok 'já tá na versão mais nova' (git -C $Global:DOTFILES log -1 --format='%h · %cr'); return }
    $antes = $carregada
    $qtd = [int](git -C $Global:DOTFILES rev-list --count "$antes..$depois")
    . (Join-Path $Global:DOTFILES 'windows\Microsoft.PowerShell_profile.ps1')
    _feito '⟳' 'terminal atualizado' "$(_plural $qtd mudança mudanças) · $(_tempo $sw)"
    git -C $Global:DOTFILES log --format='%s' "$antes..$depois" | ForEach-Object { _w "     $C_DIM•$C_OFF $C_TEXT$_$C_OFF`n" }
}

# ==========================================
# ENERGIA — poweroff / reboot / suspend com checagem, log e contagem
# (os originais continuam: Stop-Computer, Restart-Computer, shutdown.exe)
# ==========================================
function poweroff { _energia desligar @args }
function reboot { _energia reiniciar @args }
function suspend { _energia suspender @args }
function desligar { _energia desligar @args }
function reiniciar { _energia reiniciar @args }
function suspender { _energia suspender @args }
function _suspender_windows { Add-Type -AssemblyName System.Windows.Forms; $null = [System.Windows.Forms.Application]::SetSuspendState('Suspend', $false, $false) }
function _energia([string]$acao) {
    $resto = @($args); $sim = $resto -contains '-y'; $cancelar = $resto -contains 'cancelar'
    $min = $resto | Where-Object { "$_" -match '^\d{1,3}$' } | Select-Object -First 1
    $cmd = @{ desligar = 'poweroff'; reiniciar = 'reboot'; suspender = 'suspend' }[$acao]
    $estranho = $resto | Where-Object { $_ -ne '-y' -and $_ -ne 'cancelar' -and "$_" -notmatch '^\d{1,3}$' }
    if ($estranho) { _uso "$cmd [-y] [minutos | cancelar]" '-y pula a pergunta · minutos agenda · cancelar desfaz o agendamento'; return }
    if ($acao -eq 'suspender' -and ($min -or $cancelar)) { _err 'suspender não tem agendamento' 'use só: suspend'; return }
    if ($cancelar) {
        if ($Global:_DF_WINDOWS) { shutdown.exe /a 2>$null } else { shutdown -c 2>$null }
        _ok 'agendamento cancelado' 'o computador continua ligado'; return
    }
    $verbo = @{ desligar = 'desligar o computador'; reiniciar = 'reiniciar o computador'; suspender = 'suspender (dormir)' }[$acao]
    $icone = @{ desligar = '⏻'; reiniciar = '⟳'; suspender = '☾' }[$acao]
    $quando = if ($min) { "daqui a $min min · " } else { '' }
    $uptime = ''
    try {
        $up = if ($Global:_DF_WINDOWS) { (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime } else { [TimeSpan]::FromMilliseconds([Environment]::TickCount64) }
        $uptime = 'ligado há {0}h{1:00}' -f [int][Math]::Floor($up.TotalHours), $up.Minutes
    } catch { $null = $_ }
    _titulo $icone $verbo "$quando$uptime"

    # o que pode se perder
    $pendente = $false
    $jobs = @(Get-Job -State Running -ErrorAction Ignore)
    if ($jobs) { _aviso "$(_plural $jobs.Count 'tarefa rodando' 'tarefas rodando') neste terminal" 'veja com: Get-Job'; $pendente = $true }
    if (Get-Process TiWorker, wusa -ErrorAction Ignore) { _aviso 'o Windows parece estar instalando atualização' 'se puder, espere terminar antes de desligar'; $pendente = $true }
    if ($acao -ne 'suspender' -and (Test-Path $Global:DEV_HOME)) {
        $sujos = @(Get-ChildItem -Directory -LiteralPath $Global:DEV_HOME | Where-Object { (Test-Path (Join-Path $_.FullName '.git')) -and (git -C $_.FullName status --porcelain 2>$null) } | ForEach-Object Name)
        if ($sujos) { _aviso "$(_plural $sujos.Count 'projeto com mudanças' 'projetos com mudanças') fora do git" (($sujos | Select-Object -First 6) -join ' '); $pendente = $true }
    }
    if (-not $pendente) { _ok 'nada pendente' 'nenhuma tarefa rodando, projetos salvos no git' }
    if (-not $sim -and -not (_confirma "pode $($verbo.Split(' ')[0])?")) { _cancelado; return }

    # log preventivo: avisos e erros recentes do sistema
    $dir = Join-Path $Global:DOTFILES_ESTADO 'energia'
    $null = New-Item -ItemType Directory -Force -Path $dir
    $arq = Join-Path $dir "$acao-$(Get-Date -Format 'yyyy-MM-dd_HHmmss').log"
    $linhas = @("# $acao · $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') · $uptime")
    if (Get-Command Get-WinEvent -ErrorAction Ignore) {
        $linhas += Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2, 3 } -MaxEvents 200 -ErrorAction Ignore | ForEach-Object { "$($_.TimeCreated)  [$($_.LevelDisplayName)] $($_.ProviderName): $($_.Message -replace '\s+', ' ')" }
    }
    $linhas | Set-Content -LiteralPath $arq -Encoding UTF8
    Add-Content -LiteralPath (Join-Path $dir 'energia.log') -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $acao  $(if ($min) { "+$min min" } else { 'agora' })"
    Get-ChildItem -LiteralPath $dir -Filter "$acao-*.log" | Sort-Object LastWriteTime -Descending | Select-Object -Skip 20 | Remove-Item -Force

    if ($min) {
        if ($Global:_DF_WINDOWS) { $f = if ($acao -eq 'reiniciar') { '/r' } else { '/s' }; shutdown.exe $f /t ([int]$min * 60) }
        else { $f = if ($acao -eq 'reiniciar') { '-r' } else { '-h' }; shutdown $f "+$min" }
        _feito '⏲' 'agendado' "$verbo às $((Get-Date).AddMinutes([int]$min).ToString('HH:mm'))"; _dica "mudou de ideia? $cmd cancelar"; return
    }
    $espera = $Global:DOTFILES_CONTAGEM; if ($acao -eq 'suspender' -and $espera -gt 3) { $espera = 3 }
    if ($espera -gt 0 -and -not (_contagem $espera "vai $($verbo.Split(' ')[0])")) { _cancelado; return }
    _feito $icone "$($verbo.Split(' ')[0])…" "o log ficou em $(_curto $dir)"
    if ($Global:_DF_WINDOWS) {
        switch ($acao) {
            'desligar' { Stop-Computer -Force:$false }
            'reiniciar' { Restart-Computer -Force:$false }
            'suspender' { _suspender_windows }
        }
    } else {
        $v = @{ desligar = 'poweroff'; reiniciar = 'reboot'; suspender = 'suspend' }[$acao]
        systemctl $v
    }
}

# ==========================================
# PAINÉIS — status, dev, help, dotfiles
# ==========================================
function status {
    _cabecalho 'ENVIRONMENT STATUS'
    $L = "  $C_DIM{0,-11}$C_OFF {1}`n"
    _secao 'local'
    _w ($L -f 'pasta', "$C_TEXT$((Get-Location).Path)$C_OFF")
    $so = if ($Global:_DF_WINDOWS) { (Get-CimInstance Win32_OperatingSystem -ErrorAction Ignore).Caption } else { [Runtime.InteropServices.RuntimeInformation]::OSDescription }
    _w ($L -f 'sistema', "$C_TEXT$so · PowerShell $($PSVersionTable.PSVersion)$C_OFF")
    _secao 'git'
    git rev-parse --git-dir *> $null
    if ($LASTEXITCODE -eq 0) {
        $pend = @(git status --porcelain).Count
        _w ($L -f 'branch', "$C_WARN$(git branch --show-current)$C_OFF")
        _w ($L -f 'mudanças', $(if ($pend -eq 0) { "${C_OK}árvore limpa$C_OFF" } else { "$C_WARN$pend arquivo(s) pendente(s)$C_OFF" }))
        _w ($L -f 'último', "$C_TEXT$(git log -1 --format='%h  %s  (%cr)' 2>$null)$C_OFF")
    } else { _w ($L -f '', "${C_DIM}não é um repositório git$C_OFF") }
    _secao 'runtime'
    foreach ($t in 'node', 'git', 'python', 'docker') { if (_tem $t) { _w ($L -f $t, "$C_TEXT$((& $t --version 2>&1 | Select-Object -First 1) -replace '^(git version|Python|Docker version) ', '')$C_OFF") } }
    _secao 'máquina'
    $d = Get-PSDrive -Name ((Get-Location).Drive.Name) -ErrorAction Ignore
    if ($d) { _w ($L -f 'disco', "$C_TEXT$(_humano $d.Free) livres$C_OFF") }
    if ($Global:_DF_WINDOWS) {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Ignore
        if ($os) { _w ($L -f 'memória', "$C_TEXT$(_humano (($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1KB)) de $(_humano ($os.TotalVisibleMemorySize * 1KB)) em uso$C_OFF") }
        $b = Get-CimInstance Win32_Battery -ErrorAction Ignore | Select-Object -First 1
        if ($b) { _w ($L -f 'bateria', "$C_TEXT$(if ($b.BatteryStatus -eq 2) { '⚡' } else { '🔋' }) $($b.EstimatedChargeRemaining)%$C_OFF") }
    }
    _w "`n"
}
$Global:_DEV_SECOES = 'nav', 'arquivos', 'util', 'dev', 'git', 'node', 'docker', 'rede', 'processos', 'sistema', 'energia'
function _dev_secao([string]$s) {
    switch ($s) {
        'nav' { _secao 'navegação'; _linha 'p' 'vai direto pra pasta de projetos'; _linha 'proj' 'lista teus projetos — escolhe e entra'; _linha 'mkcd nome' 'cria a pasta e já entra'; _linha 'up 3' 'sobe 3 pastas'; _linha 'cdr' 'raiz do repositório git'; _linha 'tmpd' 'pasta temporária pra testes'; _linha 'open [x]' 'abre no Explorer / app padrão'; _eq 'Invoke-Item'; _linha '.. / ...' 'sobe 1 ou 2 pastas'; _linha 'c' 'limpa a tela'; _eq 'Clear-Host' }
        'arquivos' { _secao 'arquivos'; _linha 'ff [texto]' 'busca arquivo (fzf) ou texto dentro deles'; _linha 'extract arq' 'descompacta zip, tar.gz, 7z…'; _linha 'compactar x' 'pasta vira x.zip (ou tar.gz)'; _eq 'Compress-Archive'; _linha 'bak arq' 'cópia ao lado com data e hora'; _linha 'lixo arq' 'manda pra Lixeira (recuperável)'; _linha 'espaco' 'o que mais ocupa espaço na pasta' }
        'util' { _secao 'utilitários'; _linha 'clip / colar' 'copia / cola da área de transferência'; _eq 'Set-Clipboard · Get-Clipboard'; _linha 'json arq' 'formata JSON'; _linha 'uuid' 'gera um UUID e copia'; _linha 'senha [n]' 'senha forte e copia'; _linha 'b64 / b64d' 'base64'; _linha 'epoch [ts]' 'timestamp ↔ data'; _linha 'calc expr' 'calculadora'; _linha 'loadenv' 'carrega o .env'; _linha 'venv' 'ativa/cria o .venv do Python'; _linha 'cheat cmd' 'exemplos de um comando' }
        'dev' { _secao 'dev'; _linha 'serve [porta]' 'site local da pasta (padrão 8000)'; _linha 'port N' 'quem usa a porta N (-k encerra)'; _eq 'Get-NetTCPConnection -LocalPort N'; _linha 'portas' 'todas as portas abertas'; _linha 'waitport N' 'espera a porta abrir'; _linha 'httpcheck url' 'código HTTP e tempo'; _linha 'timebox [min]' "cronômetro de foco (padrão $Global:TIMEBOX_MIN min)"; _linha 'status' 'painel do ambiente' }
        'git' { _secao 'git'; _linha 'gs · gl · gd · gds' 'status · histórico · diff · diff do stage'; _linha 'ga · gaa' 'põe no stage (um · tudo)'; _linha 'gc msg · gac msg' 'commit · add tudo + commit'; _linha 'gcm' 'os tipos do Conventional Commits: quando usar cada um'; _linha 'gcm tipo:esc msg' 'commit no padrão Conventional Commits'; _linha 'gamend · gundo' 'emenda o último · desfaz o último'; _linha 'gwip · gunwip' 'commit provisório · desfaz'; _linha 'grst · grs' 'tira do stage · descarta mudança'; _linha 'gst · gstp · gsl' 'stash: guarda · recupera · lista'; _linha 'gp · gpl · gf · gup' 'push · pull · fetch · atualiza a main'; _linha 'gco · gcb · gnew · gbr' 'troca · cria · cria e publica · recentes'; _linha 'gin · gm · gbd · gclean' 'o que entra · merge · apaga · limpa mergeadas'; _linha 'gcl · hub · gpr' 'clona · abre no GitHub · abre o PR' }
        'node' { _secao 'node'; _linha 'npkg' 'package.json base'; _linha 'ni [pacote]' 'instala'; _linha 'nid pacote' 'instala só pra dev'; _linha 'nr · nrd · nrb · ns · nt' 'run · dev · build · start · test'; _linha 'nfresh · nout' 'reinstala do zero · desatualizados' }
        'docker' { _secao 'docker'; _linha 'dps · dpsa · dimg' 'rodando · todos · imagens'; _linha 'dlog · dsh' 'logs ao vivo · terminal dentro'; _linha 'dstop · drm · dclean' 'para · apaga · faxina'; _linha 'dc · dcu · dcd · dcl' 'compose · up · down · logs'; _linha 'dstats' 'CPU e memória de cada container' }
        'rede' { _secao 'rede'; _linha 'rede' 'diagnóstico: DNS, internet, latência'; _linha 'meuip' 'IP local e público'; _linha 'portas · httpcheck' 'portas abertas · teste de URL' }
        'processos' { _secao 'processos'; _linha 'psg nome' 'acha processos'; _linha 'pk [nome]' 'escolhe e encerra'; _eq 'Stop-Process'; _linha 'topcpu · topmem' 'os que mais gastam'; _linha 'mon' 'monitor (btop, htop ou Gerenciador)' }
        'sistema' { _secao 'sistema'; _linha 'limpar [-n]' 'limpeza: temporários, caches (npm, pip, scoop)'; _eq 'no PowerShell 5.1 também: clean'; _linha 'upgrade' 'atualiza tudo: winget, scoop, choco'; _eq 'winget upgrade --all'; _linha 'bkp' 'backup do profile, .gitconfig, VS Code e Terminal'; _linha 'lspkg · rmpkg' 'lista · remove programas'; _linha 'atualizar' 'baixa a versão nova destes dotfiles' }
        'energia' { _secao 'energia'; _linha 'poweroff' 'desliga — checa pendências, pergunta e conta 5s'; _eq 'Stop-Computer'; _linha 'reboot' 'reinicia'; _eq 'Restart-Computer'; _linha 'suspend' 'suspende'; _linha 'poweroff 30' 'agenda · poweroff cancelar desfaz'; _eq 'shutdown.exe /s /t 1800 · /a'; _linha '-y' 'pula a pergunta' }
        default { return $false }
    }
    return $true
}
function dev([string]$s) {
    $Global:_LARG = 18
    if (-not $s) {
        _cabecalho 'YOUR COMMANDS'
        foreach ($x in $Global:_DEV_SECOES) { $null = _dev_secao $x }
        _w "`n$C_DIM  dev <seção> mostra só uma: $($Global:_DEV_SECOES -join ' ')$C_OFF`n$C_DIM  comandos nativos: ${C_TEXT}help$C_OFF`n`n"
        return
    }
    if (-not (_dev_secao $s)) { _err "'$s' não é uma seção do dev" "seções: $($Global:_DEV_SECOES -join ' ')" } else { _w "`n" }
}
$Global:_HELP_SECOES = 'nav', 'arquivos', 'texto', 'processos', 'sistema', 'rede', 'atalhos'
function _help_secao([string]$s) {
    switch ($s) {
        'nav' { _secao 'navegação'; _linha 'Set-Location (cd) x' 'entra na pasta'; _linha 'cd -' 'volta pra anterior (PS 6+)'; _linha 'Get-Location (pwd)' 'onde você está'; _linha 'Push/Pop-Location' 'guarda e volta pra uma pasta' }
        'arquivos' { _secao 'arquivos'; _linha 'Get-ChildItem (ls)' 'lista (-Force mostra ocultos, -Recurse entra nas pastas)'; _linha 'New-Item x -Type File' 'cria arquivo'; _linha 'Copy-Item / Move-Item' 'copia / move (cp / mv)'; _linha 'Remove-Item x -Recurse' 'apaga de vez (use: lixo)'; _linha 'Get-Content x -Tail 20' 'últimas linhas (-Wait acompanha)'; _linha 'Invoke-Item x' 'abre no app padrão' }
        'texto' { _secao 'texto'; _linha 'Select-String x -Path *' 'acha texto (o grep do PowerShell)'; _linha '… | Measure-Object -Line' 'conta linhas'; _linha 'Compare-Object a b' 'compara'; _linha 'code .' 'abre no VS Code' }
        'processos' { _secao 'processos'; _linha 'Get-Process x' 'acha processo'; _linha 'Stop-Process -Id N' 'encerra (-Force na marra)'; _linha 'Get-Job · Receive-Job' 'tarefas em segundo plano'; _linha 'Measure-Command { … }' 'mede quanto demora' }
        'sistema' { _secao 'sistema'; _linha 'Get-ComputerInfo' 'tudo sobre a máquina'; _linha 'Get-Service x' 'estado de um serviço'; _linha 'winget install x' 'instala programa'; _linha 'winget upgrade --all' 'atualiza tudo'; _linha 'Stop/Restart-Computer' 'desliga / reinicia (aqui: poweroff, reboot)' }
        'rede' { _secao 'rede'; _linha 'Test-Connection x' 'ping'; _linha 'Test-NetConnection x -Port N' 'testa uma porta'; _linha 'Invoke-WebRequest url' 'requisição HTTP (curl.exe também existe)'; _linha 'Resolve-DnsName x' 'consulta DNS'; _linha 'Get-NetTCPConnection' 'conexões e portas' }
        'atalhos' { _secao 'teclado'; _linha 'Tab' 'completa (lista as opções)'; _linha 'texto + ↑ / ↓' 'histórico que começa com o texto'; _linha 'Ctrl+R' 'busca no histórico'; _linha 'Ctrl+Space' 'mostra todas as opções'; _linha 'F2' 'alterna a sugestão em lista (PS 7.2+)' }
        default { return $false }
    }
    return $true
}
function help {
    $Global:_LARG = 26
    if (-not $args) {
        _cabecalho 'SYSTEM COMMANDS'
        foreach ($x in $Global:_HELP_SECOES) { $null = _help_secao $x }
        _w "`n$C_DIM  help <seção> · help <comando> (Get-Help) · teus atalhos: ${C_TEXT}dev$C_OFF`n`n"
        return
    }
    if (_help_secao "$($args[0])") { _w "`n"; return }
    Get-Help @args
}
function dotfiles {
    _cabecalho 'DOTFILES · CHECK-UP'
    _secao 'terminal'
    _kv 'shell' "PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
    _kv 'repo' (_curto $Global:DOTFILES)
    _kv 'profile' (_curto $PROFILE)
    _kv 'carregou' "em $($Global:_DF_CARGA)"
    _secao 'ferramentas'
    $falta = 0
    foreach ($t in @(@('git', 'Git.Git'), @('fzf', 'junegunn.fzf'), @('zoxide', 'ajeetdsouza.zoxide'), @('rg', 'BurntSushi.ripgrep.MSVC'), @('delta', 'dandavison.delta'), @('jq', 'jqlang.jq'), @('docker', 'Docker.DockerDesktop'))) {
        if (_tem $t[0]) { _w "  $C_OK✓$C_OFF $C_CMD$($t[0])$C_OFF`n" } else { _w "  $C_ERR✗$C_OFF $C_CMD$($t[0])$C_OFF   ${C_WARN}winget install $($t[1])$C_OFF`n"; $falta++ }
    }
    _w "`n"; if ($falta -eq 0) { _ok 'tudo instalado' } else { _aviso "$(_plural $falta 'ferramenta opcional faltando' 'ferramentas opcionais faltando')" 'tudo funciona sem elas — só fica mais simples' }
}

# ==========================================
# ERROS — comando não encontrado sugere o certo (gti → git)
# ==========================================
function _mesmas_letras([string]$a, [string]$b) {
    if ($a.Length -ne $b.Length) { return $false }
    $r = [Collections.Generic.List[char]]$b.ToCharArray()
    foreach ($ch in $a.ToCharArray()) { if (-not $r.Remove($ch)) { return $false } }
    return $true
}
# Só age no que VOCÊ digitou (CommandOrigin Runspace): script e módulo continuam
# recebendo o erro normal do PowerShell.
$ExecutionContext.InvokeCommand.CommandNotFoundAction = {
    param($nome, $evento)
    if ($evento.CommandOrigin -ne 'Runspace' -or $nome -match '^get-' -or $nome -match '[\\/]') { return }
    $sug = Get-Command -CommandType Function, Alias, Application -ErrorAction Ignore |
        Where-Object { $_.Name -notmatch '^_' -and (_mesmas_letras $nome ($_.Name -replace '\.exe$', '')) } |
        Select-Object -First 1 | ForEach-Object { $_.Name -replace '\.exe$', '' }
    $evento.StopSearch = $true
    $evento.CommandScriptBlock = {
        _w "  $C_ERR✗$C_OFF  $C_TEXT$nome$C_OFF${C_DIM}: comando não encontrado$C_OFF`n"
        if ($sug) { _w "     $C_DIM↳ quis dizer $C_TEXT$sug$C_DIM?$C_OFF`n" }
        else { _w "     $C_DIM↳ ${C_TEXT}dev$C_DIM teus comandos · ${C_TEXT}help$C_DIM os do sistema$C_OFF`n" }
        $Global:LASTEXITCODE = 127
    }.GetNewClosure()
}

# ==========================================
# BANNER E INÍCIO
# ==========================================
function banner {
    $t = '◈  GROUND CONTROL'
    _w "`n  $C_ACCENT"; foreach ($ch in $t.ToCharArray()) { _w $ch; if (_anim) { Start-Sleep -Milliseconds 12 } }
    _w "$C_OFF   $C_DIM$((Get-Date).ToString('ddd dd MMM · HH:mm'))$C_OFF`n"
    $ars = (@('git', 'fzf', 'zoxide', 'rg', 'docker') | ForEach-Object { if (_tem $_) { "$_ $C_OK✓$C_TEXT" } else { "$C_DIM$_ ✗$C_TEXT" } }) -join '  '
    foreach ($l in @(@('shell', "PowerShell $($PSVersionTable.PSVersion)"), @('arsenal', $ars), @('projetos', (_curto $Global:DEV_HOME)))) {
        if (_anim) { foreach ($f in 0, 3, 6) { _w "$_CL     $C_ACCENT$($Global:_SPIN[$f])$C_OFF"; Start-Sleep -Milliseconds 30 } }
        _w ("$_CL     $C_SECAO▸$C_OFF $C_DIM{0,-9}$C_OFF $C_TEXT{1}$C_OFF`n" -f $l[0], $l[1])
    }
    _w "  $C_DIM   all systems nominal — ${C_TEXT}dev$C_DIM your tools · ${C_TEXT}help$C_DIM the system$C_OFF`n`n"
}

# teus ajustes por cima de tudo
if (Test-Path -LiteralPath $Global:DOTFILES_LOCAL) { . $Global:DOTFILES_LOCAL }

if (-not $Global:_DF_CARREGADO) {
    $Global:_DF_CARGA = _tempo $Global:_DF_T0
    $hoje = Get-Date -Format 'yyyy-MM-dd'
    $marca = Join-Path $Global:DOTFILES_ESTADO 'banner-dia'
    $ultimo = if (Test-Path -LiteralPath $marca) { Get-Content -LiteralPath $marca -TotalCount 1 } else { '' }
    if ($ultimo -ne $hoje -and (_anim)) {
        banner
        $null = New-Item -ItemType Directory -Force -Path $Global:DOTFILES_ESTADO
        Set-Content -LiteralPath $marca -Value $hoje
    } else {
        _w "`n  $C_ACCENT◈  GROUND CONTROL$C_OFF   $C_DIM$((Get-Date).ToString('ddd dd MMM · HH:mm'))   ⚡$($Global:_DF_CARGA)$C_OFF`n"
        _w "  $C_DIM   all systems nominal — ${C_TEXT}dev$C_DIM your tools · ${C_TEXT}help$C_DIM the system$C_OFF`n`n"
    }
    # Só entra na pasta de projetos se abriu na home (o terminal do VS Code abre no projeto)
    if ((Get-Location).Path -eq $HOME -and (Test-Path -LiteralPath $Global:DEV_HOME)) { Set-Location $Global:DEV_HOME }
}
$Global:_DF_CARREGADO = $true
