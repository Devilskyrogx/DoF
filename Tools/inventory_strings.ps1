# DoF/Tools/inventory_strings.ps1
#
# Инвентаризация строк для локализации: собирает все строковые литералы,
# содержащие кириллицу, отделяя их от комментариев, и выгружает в CSV.
#
# Комментарии отбрасываются полноценным разбором, а не регуляркой: в коде хватает
# строк вида "Урон 10-20 -- крит", где "--" внутри кавычек не начинает комментарий.
#
#   powershell -ExecutionPolicy Bypass -File Tools\inventory_strings.ps1
#
# Результат: Tools\locale_inventory.csv (UTF-8), отсортирован по домену и файлу.

param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$Out  = (Join-Path $PSScriptRoot 'locale_inventory.csv')
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# Домен определяется по пути файла — он же станет префиксом ключа локали.
function Get-Domain([string]$relativePath) {
    switch -Regex ($relativePath) {
        'Data\\Effects\.lua'    { return 'effects' }
        'Data\\Passives\.lua'   { return 'passives' }
        'NPCLibrary'            { return 'npc' }
        '^UI\\'                 { return 'ui' }
        '^Combat\\'             { return 'combat' }
        '^Sync\\'               { return 'combat' }
        '^Core\\'               { return 'core' }
        '^Data\\'               { return 'core' }
        default                 { return 'core' }
    }
}

# Транслитерация для черновых ключей: править вручную проще, чем придумывать с нуля.
$translit = @{
    'а'='a';'б'='b';'в'='v';'г'='g';'д'='d';'е'='e';'ё'='e';'ж'='zh';'з'='z';
    'и'='i';'й'='y';'к'='k';'л'='l';'м'='m';'н'='n';'о'='o';'п'='p';'р'='r';
    'с'='s';'т'='t';'у'='u';'ф'='f';'х'='h';'ц'='c';'ч'='ch';'ш'='sh';'щ'='sch';
    'ъ'='';'ы'='y';'ь'='';'э'='e';'ю'='yu';'я'='ya'
}

function Get-SuggestedKey([string]$domain, [string]$text) {
    $lower = $text.ToLower()
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $lower.ToCharArray()) {
        if ($translit.ContainsKey([string]$ch)) {
            [void]$sb.Append($translit[[string]$ch])
        } elseif ($ch -match '[a-z0-9]') {
            [void]$sb.Append($ch)
        } else {
            [void]$sb.Append('_')
        }
    }
    $slug = $sb.ToString() -replace '_+', '_' -replace '^_|_$', ''
    if ($slug.Length -gt 40) { $slug = $slug.Substring(0, 40).TrimEnd('_') }
    if ([string]::IsNullOrWhiteSpace($slug)) { $slug = 'unnamed' }
    return "$domain.$slug"
}

# Разбор строки Lua: возвращает найденные литералы, пропуская комментарии.
# $state — хэштаблица с ключом InBlockComment, переносится между строками файла.
function Get-LuaStrings([string]$line, [hashtable]$state) {
    $found = @()
    $i = 0
    $len = $line.Length

    while ($i -lt $len) {
        if ($state.InBlockComment) {
            $end = $line.IndexOf(']]', $i)
            if ($end -lt 0) { return $found }
            $state.InBlockComment = $false
            $i = $end + 2
            continue
        }

        $ch = $line[$i]

        # Начало комментария
        if ($ch -eq '-' -and $i + 1 -lt $len -and $line[$i + 1] -eq '-') {
            if ($i + 3 -lt $len -and $line.Substring($i + 2, 2) -eq '[[') {
                $state.InBlockComment = $true
                $i += 4
                continue
            }
            return $found  # однострочный комментарий — остаток строки игнорируем
        }

        # Строковый литерал
        if ($ch -eq '"' -or $ch -eq "'") {
            $quote = $ch
            $j = $i + 1
            $sb = New-Object System.Text.StringBuilder
            while ($j -lt $len) {
                if ($line[$j] -eq '\') {
                    if ($j + 1 -lt $len) { [void]$sb.Append($line[$j]); [void]$sb.Append($line[$j + 1]) }
                    $j += 2
                    continue
                }
                if ($line[$j] -eq $quote) { break }
                [void]$sb.Append($line[$j])
                $j++
            }
            if ($j -lt $len) { $found += $sb.ToString() }
            $i = $j + 1
            continue
        }

        $i++
    }

    return $found
}

# XML содержит текст в двух местах, и оба надо смотреть:
#   1) атрибуты text= / tooltip= / label=;
#   2) Lua-код внутри <OnLoad>, <OnShow>, <OnClick> и прочих <Scripts>.
# Второе легко упустить — именно там пряталась подпись «ПАНЕЛЬ ВЕДУЩЕГО».
# XML-комментарии <!-- --> пропускаются: в них встречаются примеры кода
# с кириллицей, которые переводить не нужно.
function Get-XmlStrings([string]$line, [hashtable]$state) {
    $found = @()

    if ($state.InXmlComment) {
        $end = $line.IndexOf('-->')
        if ($end -lt 0) { return $found }
        $line = $line.Substring($end + 3)
        $state.InXmlComment = $false
    }

    # Вырезаем комментарии, начинающиеся и заканчивающиеся на этой же строке.
    $line = [regex]::Replace($line, '<!--.*?-->', '')

    $open = $line.IndexOf('<!--')
    if ($open -ge 0) {
        $state.InXmlComment = $true
        $line = $line.Substring(0, $open)
    }

    foreach ($m in [regex]::Matches($line, '(?:text|tooltip|label)="([^"]*)"')) {
        $found += $m.Groups[1].Value
    }

    # Lua-литералы в скриптовых блоках. Ищем только там, где строка содержит
    # обращение к SetText/Setup/print и подобным — атрибуты уже разобраны выше.
    if ($line -match '<On[A-Za-z]+>|SetText|Setup|print|AddLine') {
        foreach ($m in [regex]::Matches($line, '"([^"]*)"')) {
            $value = $m.Groups[1].Value
            # Пропускаем то, что уже поймано как значение XML-атрибута.
            if ($line -match ('(?:text|tooltip|label)="' + [regex]::Escape($value) + '"')) { continue }
            $found += $value
        }
    }

    return $found
}

$rows = New-Object System.Collections.Generic.List[object]

$files = Get-ChildItem -Path $Root -Recurse -File -Include *.lua, *.xml |
    Where-Object { $_.FullName -notmatch '\\Libs\\' -and $_.FullName -notmatch '\\Locale\\' -and $_.FullName -notmatch '\\Tools\\' }

foreach ($file in $files) {
    $relative = $file.FullName.Substring($Root.Length).TrimStart('\')
    $domain = Get-Domain $relative
    $isXml = $file.Extension -eq '.xml'
    $state = @{ InBlockComment = $false; InXmlComment = $false }
    $lines = [System.IO.File]::ReadAllLines($file.FullName, $utf8)

    for ($n = 0; $n -lt $lines.Count; $n++) {
        $line = $lines[$n]
        if ($line -notmatch '[Ѐ-ӿ]') { continue }

        $strings = if ($isXml) { Get-XmlStrings $line $state } else { Get-LuaStrings $line $state }

        foreach ($s in $strings) {
            if ($s -notmatch '[Ѐ-ӿ]') { continue }

            $rows.Add([pscustomobject]@{
                Domain       = $domain
                File         = $relative
                Line         = $n + 1
                Text         = $s
                SuggestedKey = Get-SuggestedKey $domain $s
                # Строки с подстановками нельзя собирать из кусков — переводятся целиком.
                HasFormat    = if ($s -match '%[sdxq\d\.\-]') { 'yes' } else { '' }
                Context      = $line.Trim()
            })
        }
    }
}

# Одна и та же строка встречается в разных местах — считаем повторы,
# чтобы сразу видеть, сколько мест придётся править на один ключ локали.
$grouped = $rows | Group-Object Domain, Text | ForEach-Object {
    $first = $_.Group[0]
    [pscustomobject]@{
        Domain       = $first.Domain
        Text         = $first.Text
        SuggestedKey = $first.SuggestedKey
        HasFormat    = $first.HasFormat
        Occurrences  = $_.Count
        Locations    = ($_.Group | ForEach-Object { "$($_.File):$($_.Line)" }) -join '; '
        Context      = $first.Context
    }
}

$grouped | Sort-Object Domain, Text | Export-Csv -Path $Out -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Всего вхождений: $($rows.Count)"
Write-Host "Уникальных строк: $($grouped.Count)"
Write-Host ""
$grouped | Group-Object Domain | Sort-Object Count -Descending |
    ForEach-Object { "  {0,-10} {1,5} уникальных" -f $_.Name, $_.Count } | Write-Host
Write-Host ""
Write-Host "CSV: $Out"
