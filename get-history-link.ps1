# Finds the wish history link that Genshin Impact caches when you open the
# wish history in game, checks it with HoYoverse and copies it to your
# clipboard. Only reads local game files; the only request goes to
# HoYoverse's own wish history API.

# Hides PowerShell's own download progress, which would cover our output.
$ProgressPreference = "SilentlyContinue"

$logPath = [System.Environment]::ExpandEnvironmentVariables("%userprofile%\AppData\LocalLow\miHoYo\Genshin Impact\output_log.txt")
$apiUrl = "https://public-operation-hk4e-sg.hoyoverse.com/gacha_info/api/getGachaLog"
$totalSteps = 4

# --- Output -----------------------------------------------------------------

function Write-Step($number, $text) {
    Write-Host ""
    Write-Host " [$number/$totalSteps] " -ForegroundColor Cyan -NoNewline
    Write-Host $text -ForegroundColor White
}

function Write-Done($text) {
    Write-Host "       $text" -ForegroundColor Green
}

function Write-Fail($text) {
    Write-Host "       $text" -ForegroundColor Red
    Write-Host ""
}

function Show-Progress($done, $total) {
    $width = 30
    $filled = [Math]::Floor($done / $total * $width)
    $bar = ("#" * $filled) + ("-" * ($width - $filled))
    Write-Host "`r       [$bar] $done/$total" -ForegroundColor DarkCyan -NoNewline
}

# --- Steps ------------------------------------------------------------------

# The game writes its install folder into its log.
function Find-GameDataDir {
    if (-not (Test-Path $logPath)) { return $null }
    $line = Get-Content -Path $logPath | Select-String -Pattern "(.:/.+GenshinImpact_Data)" | Select-Object -First 1
    if (-not $line) { return $null }
    return $line.Matches[0].Groups[1].Value
}

# The game's web cache of the newest game version, where the wish history page was loaded.
function Find-CacheFile($gameDataDir) {
    $versionDir = Get-ChildItem -Path "$gameDataDir/webCaches" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1
    if (-not $versionDir) { return $null }
    return "$($versionDir.FullName)\Cache\Cache_Data\data_2"
}

# Every authkey in the cache, once each. The game keeps the file open, so
# read a copy, and delete the copy at once: it holds the keys.
function Read-AuthKeys($cacheFile) {
    $copy = "$env:TEMP\ch_data_2"
    Copy-Item $cacheFile -Destination $copy
    $content = Get-Content -Encoding UTF8 -Raw $copy
    Remove-Item $copy
    $keys = Select-String -InputObject $content -Pattern 'authkey=(.*?)&game_biz' -AllMatches |
        ForEach-Object { $_.Matches } |
        ForEach-Object { $_.Groups[1].Value }
    return @($keys | Select-Object -Unique)
}

function New-WishLink($authKey) {
    return "${apiUrl}?authkey=$authKey&win_mode=fullscreen&authkey_ver=1&sign_type=2&auth_appid=webview_gacha&init_type=301&gacha_type=301&page=1&size=20&end_id=0&lang=en"
}

# The game UID the link opens, or $null if the link has expired or the account has no wishes.
function Get-LinkUid($link) {
    try {
        $response = Invoke-RestMethod -Uri $link -Method Get
    }
    catch {
        return $null
    }
    if ($response.message -eq "OK" -and $response.data.list.Count -gt 0) {
        return $response.data.list[0].uid
    }
    return $null
}

# One working link per game account.
function Find-Accounts($authKeys) {
    $accounts = @()
    for ($i = 0; $i -lt $authKeys.Count; $i++) {
        Show-Progress $i $authKeys.Count
        $link = New-WishLink $authKeys[$i]
        $uid = Get-LinkUid $link
        if ($uid -and -not ($accounts.Uid -contains $uid)) {
            $accounts += [PSCustomObject]@{ Uid = $uid; Link = $link }
        }
    }
    Show-Progress $authKeys.Count $authKeys.Count
    Write-Host ""
    return $accounts
}

function Select-Account($accounts) {
    if ($accounts.Count -eq 1) { return $accounts[0] }

    for ($i = 0; $i -lt $accounts.Count; $i++) {
        Write-Host "       [$($i + 1)] " -ForegroundColor Cyan -NoNewline
        Write-Host "UID $($accounts[$i].Uid)"
    }
    # Asks again on a wrong number: rerunning would check every link again.
    while ($true) {
        # Read-Host adds ": " after the prompt.
        $choice = "$(Read-Host "       Type the account number and press Enter (just Enter to skip)")".Trim()
        if ($choice -eq "") { return $null }
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $accounts.Count) {
            return $accounts[[int]$choice - 1]
        }
        Write-Host "       There is no account $choice. Type a number from 1 to $($accounts.Count)." -ForegroundColor Yellow
    }
}

# --- Run --------------------------------------------------------------------

Write-Host ""
Write-Host " ARCHON.MOE - Wish History Link" -ForegroundColor Cyan
Write-Host " Reads your local game files and copies the link to your clipboard." -ForegroundColor DarkGray

Write-Step 1 "Finding the game folder"
$gameDataDir = Find-GameDataDir
if (-not $gameDataDir) {
    Write-Fail "Cannot find the game. Open the wish history in game first, or restart PowerShell as administrator."
    return
}
Write-Done "Found"

Write-Step 2 "Reading the game cache"
$cacheFile = Find-CacheFile $gameDataDir
if (-not $cacheFile) {
    Write-Fail "Cannot find the game cache. Open the wish history in game first."
    return
}
$authKeys = Read-AuthKeys $cacheFile
if ($authKeys.Count -eq 0) {
    Write-Fail "No wish history link in the cache. Open the wish history in game first."
    return
}
Write-Done "$($authKeys.Count) link(s) found"

Write-Step 3 "Checking which links still work"
$accounts = @(Find-Accounts $authKeys)
if ($accounts.Count -eq 0) {
    Write-Fail "All links have expired. Open the wish history in game again and rerun the command."
    return
}
Write-Done "$($accounts.Count) game account(s) found"

Write-Step 4 "Copying the link"
$account = Select-Account $accounts
if (-not $account) {
    Write-Host "       Nothing copied." -ForegroundColor Yellow
    Write-Host ""
    return
}
Set-Clipboard -Value $account.Link
Write-Done "Link for UID $($account.Uid) copied to your clipboard"

Write-Host ""
Write-Host " Done! Paste the link on the import page." -ForegroundColor Green
Write-Host " Keep it to yourself: for about 24 hours it opens your wish history." -ForegroundColor Yellow
Write-Host ""
