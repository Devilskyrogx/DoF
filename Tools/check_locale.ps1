# DoF/Tools/check_locale.ps1
#
# Проверка целостности локализации. Три независимых проверки:
#   1. Ключи, используемые в коде (DoF.L["..."] / DoF.Locale:Format("...")),
#      но не объявленные в локали  -> в игре покажется "[ключ]".
#   2. Ключи, объявленные в ruRU, но отсутствующие в enUS (и наоборот)
#      -> один из языков молча откатится на fallback.
#   3. Глобалы DoF_L_*, на которые ссылается XML, но которых не даёт локаль
#      -> в интерфейсе покажется имя переменной.
#
#   powershell -ExecutionPolicy Bypass -File Tools\check_locale.ps1
#
# Код возврата 1, если найдена хоть одна проблема — годится для хука перед сборкой.

param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$problems = 0

function Get-DeclaredKeys([string]$lang) {
    $keys = @{}
    $dir = Join-Path $Root "Locale\$lang"
    if (-not (Test-Path $dir)) { throw "Нет каталога локали: $dir" }

    foreach ($file in Get-ChildItem $dir -Filter *.lua) {
        $text = [System.IO.File]::ReadAllText($file.FullName, $utf8)
        foreach ($m in [regex]::Matches($text, '\["([^"]+)"\]\s*=')) {
            $key = $m.Groups[1].Value
            if ($keys.ContainsKey($key)) {
                Write-Host "  ДУБЛЬ ключа в $lang : $key" -ForegroundColor Yellow
            }
            $keys[$key] = $file.Name
        }
    }
    return $keys
}

$ru = Get-DeclaredKeys 'ruRU'
$en = Get-DeclaredKeys 'enUS'

# ─── 1. Ключи, используемые в коде ─────────────────────────────
$used = @{}
$sources = Get-ChildItem -Path $Root -Recurse -File -Include *.lua |
    Where-Object { $_.FullName -notmatch '\\Libs\\' -and $_.FullName -notmatch '\\Locale\\' -and $_.FullName -notmatch '\\Tools\\' }

foreach ($file in $sources) {
    $relative = $file.FullName.Substring($Root.Length).TrimStart('\')
    $text = [System.IO.File]::ReadAllText($file.FullName, $utf8)
    foreach ($m in [regex]::Matches($text, 'DoF\.L\["([^"]+)"\]|DoF\.Locale:(?:Format|Get)\("([^"]+)"')) {
        $key = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
        if (-not $used.ContainsKey($key)) { $used[$key] = @() }
        $used[$key] += $relative
    }
}

$undeclared = $used.Keys | Where-Object { -not $en.ContainsKey($_) -and -not $ru.ContainsKey($_) } | Sort-Object
if ($undeclared) {
    $problems += $undeclared.Count
    Write-Host ""
    Write-Host "Используются в коде, но не объявлены ни в одной локали:" -ForegroundColor Red
    $undeclared | ForEach-Object { Write-Host "  $_  <- $((($used[$_]) | Select-Object -Unique) -join ', ')" }
}

# ─── 2. Расхождение языков ─────────────────────────────────────
$onlyRu = $ru.Keys | Where-Object { -not $en.ContainsKey($_) } | Sort-Object
$onlyEn = $en.Keys | Where-Object { -not $ru.ContainsKey($_) } | Sort-Object

if ($onlyRu) {
    $problems += $onlyRu.Count
    Write-Host ""
    Write-Host "Есть в ruRU, нет в enUS (английский откатится на ключ):" -ForegroundColor Red
    $onlyRu | ForEach-Object { Write-Host "  $_" }
}
if ($onlyEn) {
    $problems += $onlyEn.Count
    Write-Host ""
    Write-Host "Есть в enUS, нет в ruRU (русский покажет английский текст):" -ForegroundColor Yellow
    $onlyEn | ForEach-Object { Write-Host "  $_" }
}

# ─── 3. Глобалы для XML ────────────────────────────────────────
# Locale/Globals.lua строит DoF_L_<КЛЮЧ> из каждого ключа "xml.*".
$xmlGlobals = @{}
foreach ($key in $en.Keys + $ru.Keys) {
    if ($key.StartsWith('xml.')) {
        $xmlGlobals['DoF_L_' + $key.Substring(4).ToUpper()] = $key
    }
}

$missingGlobals = @()
foreach ($file in Get-ChildItem -Path (Join-Path $Root 'UI') -Recurse -File -Filter *.xml) {
    $text = [System.IO.File]::ReadAllText($file.FullName, $utf8)
    # Ищем DoF_L_* где угодно в файле, а не только в text="...": глобалы
    # используются ещё и из Lua-кода внутри <OnLoad>/<OnShow>, и опечатка там
    # так же молча выводит имя переменной вместо текста.
    foreach ($m in [regex]::Matches($text, '\bDoF_L_[A-Z0-9_]+')) {
        $name = $m.Value
        if (-not $xmlGlobals.ContainsKey($name)) { $missingGlobals += $name }
    }
}

$missingGlobals = $missingGlobals | Sort-Object -Unique
if ($missingGlobals) {
    $problems += $missingGlobals.Count
    Write-Host ""
    Write-Host "XML ссылается на глобалы, которых локаль не создаёт:" -ForegroundColor Red
    $missingGlobals | ForEach-Object { Write-Host "  $_" }
}

# ─── Итог ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "Ключей в ruRU: $($ru.Count)   в enUS: $($en.Count)"
Write-Host "Используется в коде: $($used.Count)"
Write-Host "Глобалов для XML: $($xmlGlobals.Count)"
Write-Host ""
if ($problems -eq 0) {
    Write-Host "Проблем не найдено." -ForegroundColor Green
    exit 0
}
Write-Host "Проблем: $problems" -ForegroundColor Red
exit 1
