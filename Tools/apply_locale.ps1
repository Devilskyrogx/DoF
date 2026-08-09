# DoF/Tools/apply_locale.ps1
#
# Заменяет строковые литералы в исходниках на обращения к локали.
# На вход — TSV-карта: <файл><TAB><русская строка><TAB><ключ локали>
#
#   powershell -ExecutionPolicy Bypass -File Tools\apply_locale.ps1 -Map Tools\maps\ui_batch1.tsv
#
# Заменяется только точное совпадение литерала целиком ("строка" -> DoF.L["ключ"]),
# внутри комментариев замена не делается. Каждая строка карты обязана совпасть
# хотя бы один раз — иначе скрипт завершается с ошибкой и ничего не пишет на диск:
# молчаливый промах означал бы непереведённый текст, который всплывёт только в игре.

param(
    [Parameter(Mandatory = $true)][string]$Map,
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

$entries = @()
foreach ($line in [System.IO.File]::ReadAllLines($Map, $utf8)) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
    $parts = $line -split "`t"
    if ($parts.Count -lt 3) { throw "Строка карты не в формате файл<TAB>текст<TAB>ключ: $line" }
    $entries += [pscustomobject]@{ File = $parts[0]; Text = $parts[1]; Key = $parts[2] }
}

# Позиции литералов, лежащих вне комментариев. Логика разбора та же, что в
# inventory_strings.ps1: "--" внутри кавычек комментарий не начинает.
function Get-LiteralSpans([string]$line, [hashtable]$state) {
    $spans = @()
    $i = 0
    $len = $line.Length

    while ($i -lt $len) {
        if ($state.InBlockComment) {
            $end = $line.IndexOf(']]', $i)
            if ($end -lt 0) { return $spans }
            $state.InBlockComment = $false
            $i = $end + 2
            continue
        }

        $ch = $line[$i]

        if ($ch -eq '-' -and $i + 1 -lt $len -and $line[$i + 1] -eq '-') {
            if ($i + 3 -lt $len -and $line.Substring($i + 2, 2) -eq '[[') {
                $state.InBlockComment = $true
                $i += 4
                continue
            }
            return $spans
        }

        if ($ch -eq '"' -or $ch -eq "'") {
            $quote = $ch
            $j = $i + 1
            while ($j -lt $len) {
                if ($line[$j] -eq '\') { $j += 2; continue }
                if ($line[$j] -eq $quote) { break }
                $j++
            }
            if ($j -lt $len) {
                $spans += [pscustomobject]@{
                    Start = $i
                    Length = $j - $i + 1
                    Value = $line.Substring($i + 1, $j - $i - 1)
                }
            }
            $i = $j + 1
            continue
        }

        $i++
    }

    return $spans
}

$hits = @{}
$touched = @{}
$pending = @{}

foreach ($group in $entries | Group-Object File) {
    $path = Join-Path $Root $group.Name
    if (-not (Test-Path $path)) { throw "Файл не найден: $path" }

    $lines = [System.IO.File]::ReadAllLines($path, $utf8)
    $byText = @{}
    foreach ($e in $group.Group) { $byText[$e.Text] = $e.Key }

    $state = @{ InBlockComment = $false }
    $changed = $false

    for ($n = 0; $n -lt $lines.Count; $n++) {
        # @() обязательно: PowerShell разворачивает массив из одного элемента
        # в скаляр, и тогда .Count вернёт $null — строки-одиночки молча терялись.
        $spans = @(Get-LiteralSpans $lines[$n] $state)
        if ($spans.Count -eq 0) { continue }

        # Справа налево, чтобы смещения предыдущих замен не сбивали позиции.
        for ($s = $spans.Count - 1; $s -ge 0; $s--) {
            $span = $spans[$s]
            if (-not $byText.ContainsKey($span.Value)) { continue }

            $key = $byText[$span.Value]
            $replacement = 'DoF.L["' + $key + '"]'
            $lines[$n] = $lines[$n].Substring(0, $span.Start) + $replacement +
                         $lines[$n].Substring($span.Start + $span.Length)
            $changed = $true

            $id = "$($group.Name)`t$($span.Value)"
            $hits[$id] = ($hits[$id] + 1)
        }
    }

    # Результат копится в памяти. Запись — только после того, как проверена
    # ВСЯ карта: иначе промах в последней строке оставлял бы предыдущие файлы
    # уже переписанными, и повторный запуск было бы не на чем основывать.
    if ($changed) { $pending[$group.Name] = @{ Path = $path; Lines = $lines } }
}

# Проверка, что каждая запись карты действительно нашлась.
$missed = @()
foreach ($e in $entries) {
    if (-not $hits.ContainsKey("$($e.File)`t$($e.Text)")) { $missed += $e }
}

if ($missed.Count -gt 0) {
    Write-Host ""
    Write-Host "НЕ НАЙДЕНО в исходниках:" -ForegroundColor Red
    $missed | ForEach-Object { Write-Host "  $($_.File): `"$($_.Text)`"" }
    throw "$($missed.Count) записей карты не совпали — на диск ничего не записано, проверьте карту."
}

if (-not $DryRun) {
    foreach ($name in $pending.Keys) {
        [System.IO.File]::WriteAllLines($pending[$name].Path, $pending[$name].Lines, $utf8)
        $touched[$name] = $true
    }
}

$total = ($hits.Values | Measure-Object -Sum).Sum
Write-Host ""
Write-Host "Записей в карте: $($entries.Count)"
Write-Host "Заменено вхождений: $total"
Write-Host "Файлов изменено: $($touched.Count)"
if ($DryRun) { Write-Host "(DryRun — на диск ничего не записано)" -ForegroundColor Yellow }
