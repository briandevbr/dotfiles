# ==========================================
# windows\install.ps1 — instala o profile no PowerShell (5.1 e 7+)
#
#   powershell -ExecutionPolicy Bypass -File .\windows\install.ps1
#   powershell -ExecutionPolicy Bypass -File .\windows\install.ps1 -Ferramentas
#
# O $PROFILE de cada PowerShell vira uma linha só que carrega o profile do
# repositório — assim o 'atualizar' (git pull) chega nele sem copiar nada.
# O profile antigo, se existir, fica guardado com a data no nome.
# ==========================================
param([switch]$Ferramentas)

$repo = Split-Path -Parent $PSScriptRoot
$alvo = Join-Path $repo 'windows\Microsoft.PowerShell_profile.ps1'
$carimbo = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$e = [char]27
function ok([string]$m, [string]$d) { Write-Output "  $e[38;5;46m✓$e[0m  $m   $e[38;5;245m$d$e[0m" }
function aviso([string]$m, [string]$d) { Write-Output "  $e[38;5;214m!$e[0m  $m   $e[38;5;245m$d$e[0m" }

Write-Output "`n$e[38;5;39m$e[1m  ◈  DOTFILES · INSTALAÇÃO (PowerShell)$e[0m"

# Os dois PowerShells têm $PROFILE em pastas diferentes (e a pasta Documentos pode estar no OneDrive)
$docs = [Environment]::GetFolderPath('MyDocuments')
$perfis = @(
    (Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),   # Windows PowerShell 5.1
    (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1')           # PowerShell 7+
)
$linha = ". `"$alvo`"   # dotfiles: o terminal mora no repositório"

foreach ($p in $perfis) {
    $null = New-Item -ItemType Directory -Force -Path (Split-Path $p)
    if (Test-Path $p) {
        if ((Get-Content $p -Raw) -match [regex]::Escape($alvo)) { ok "$p" 'já carrega os dotfiles'; continue }
        Copy-Item $p "$p.antes-dotfiles-$carimbo"
        aviso 'profile antigo guardado' "$p.antes-dotfiles-$carimbo"
    }
    # UTF-8 com BOM: o PowerShell 5.1 lê certo
    [IO.File]::WriteAllText($p, "$linha`r`n", (New-Object Text.UTF8Encoding $true))
    ok $p 'agora carrega os dotfiles'
}

# Sem isso o Windows não deixa o profile rodar (o padrão é Restricted)
$politica = Get-ExecutionPolicy -Scope CurrentUser
if ($politica -in 'Undefined', 'Restricted') {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    ok 'política de execução' 'RemoteSigned pro teu usuário (scripts locais rodam; os baixados precisam de assinatura)'
}

# Teus ajustes ficam fora do repositório
$local = Join-Path $HOME '.config\dotfiles\local.ps1'
if (-not (Test-Path $local)) {
    $null = New-Item -ItemType Directory -Force -Path (Split-Path $local)
    $modelo = @(
        '# local.ps1 — teus ajustes pessoais (o atualizar nunca mexe aqui)',
        "# `$Global:PROMPT_NOME = 'ana'",
        "# `$Global:DEV_HOME = 'D:\code'",
        "# `$Global:DOTFILES_ANIM = '0'"
    )
    [IO.File]::WriteAllLines($local, $modelo, (New-Object Text.UTF8Encoding $true))
    ok "criado $local" 'teus ajustes vão lá'
}

if ($Ferramentas) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        aviso 'winget não encontrado' 'instale o "App Installer" pela Microsoft Store'
    } else {
        foreach ($id in 'Git.Git', 'junegunn.fzf', 'ajeetdsouza.zoxide', 'BurntSushi.ripgrep.MSVC', 'dandavison.delta', 'jqlang.jq') {
            winget install --id $id -e --accept-source-agreements --accept-package-agreements --silent *> $null
            if ($LASTEXITCODE -eq 0) { ok $id } else { aviso "$id não instalou (ou já estava)" "winget install $id" }
        }
    }
}

Write-Output "`n  $e[38;5;46m◈$e[0m  pronto! abra um PowerShell novo (de preferência no Windows Terminal)"
Write-Output "     $e[38;5;245m↳ comandos: dev · ajuda do sistema: help · check-up: dotfiles$e[0m`n"
