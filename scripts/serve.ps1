param(
    [int]$Port = 8080
)

$ErrorActionPreference = 'Stop'
$Root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Address = [System.Net.IPAddress]::Loopback
$Listener = $null
$RequestedPort = $Port

function Get-MimeType([string]$Path) {
    switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.html' { 'text/html; charset=utf-8' }
        '.htm'  { 'text/html; charset=utf-8' }
        '.js'   { 'text/javascript; charset=utf-8' }
        '.mjs'  { 'text/javascript; charset=utf-8' }
        '.css'  { 'text/css; charset=utf-8' }
        '.json' { 'application/json; charset=utf-8' }
        '.png'  { 'image/png' }
        '.jpg'  { 'image/jpeg' }
        '.jpeg' { 'image/jpeg' }
        '.svg'  { 'image/svg+xml' }
        '.ico'  { 'image/x-icon' }
        '.txt'  { 'text/plain; charset=utf-8' }
        default { 'application/octet-stream' }
    }
}

function Send-Response($Stream, [int]$Status, [string]$Reason, [byte[]]$Body, [string]$ContentType) {
    $Header = "HTTP/1.1 $Status $Reason`r`n" +
              "Content-Type: $ContentType`r`n" +
              "Content-Length: $($Body.Length)`r`n" +
              "Cache-Control: no-store`r`n" +
              "Connection: close`r`n`r`n"
    $HeaderBytes = [System.Text.Encoding]::ASCII.GetBytes($Header)
    $Stream.Write($HeaderBytes, 0, $HeaderBytes.Length)
    if ($Body.Length -gt 0) { $Stream.Write($Body, 0, $Body.Length) }
    $Stream.Flush()
}

try {
    for ($Candidate = $RequestedPort; $Candidate -le ($RequestedPort + 10); $Candidate++) {
        try {
            $CandidateListener = [System.Net.Sockets.TcpListener]::new($Address, $Candidate)
            $CandidateListener.Start()
            $Listener = $CandidateListener
            $Port = $Candidate
            break
        } catch {
            if ($null -ne $CandidateListener) { $CandidateListener.Stop() }
        }
    }

    if ($null -eq $Listener) {
        throw "No free port found from $RequestedPort to $($RequestedPort + 10)."
    }

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host '  EXORCIST GAME 2046 — LOCAL SERVER' -ForegroundColor Cyan
    Write-Host "  http://localhost:$Port/play.html" -ForegroundColor Green
    Write-Host '  Keep this window open while playing.' -ForegroundColor Yellow
    Write-Host '  Press Ctrl+C to stop the server.' -ForegroundColor DarkGray
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ''

    try { Start-Process "http://localhost:$Port/play.html" }
    catch { Write-Host "Open http://localhost:$Port/play.html manually." -ForegroundColor Yellow }

    while ($true) {
        $Client = $Listener.AcceptTcpClient()
        try {
            $Stream = $Client.GetStream()
            $Reader = [System.IO.StreamReader]::new($Stream,[System.Text.Encoding]::ASCII,$false,4096,$true)
            $RequestLine = $Reader.ReadLine()
            while ($true) {
                $Line = $Reader.ReadLine()
                if ($null -eq $Line -or $Line.Length -eq 0) { break }
            }
            if ([string]::IsNullOrWhiteSpace($RequestLine)) { continue }
            $Parts = $RequestLine.Split(' ')
            if ($Parts.Length -lt 2) { continue }

            $UrlPath = ($Parts[1] -split '\?')[0]
            $UrlPath = [System.Uri]::UnescapeDataString($UrlPath)
            if ($UrlPath -eq '/') { $UrlPath = '/play.html' }
            $Relative = $UrlPath.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            $FullPath = [System.IO.Path]::GetFullPath((Join-Path $Root $Relative))

            if (-not $FullPath.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
                Send-Response $Stream 403 'Forbidden' ([System.Text.Encoding]::UTF8.GetBytes('403 Forbidden')) 'text/plain; charset=utf-8'
                continue
            }
            if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) {
                Send-Response $Stream 404 'Not Found' ([System.Text.Encoding]::UTF8.GetBytes('404 Not Found')) 'text/plain; charset=utf-8'
                continue
            }

            $Body = [System.IO.File]::ReadAllBytes($FullPath)
            Send-Response $Stream 200 'OK' $Body (Get-MimeType $FullPath)
        } catch {
            Write-Host "Request error: $($_.Exception.Message)" -ForegroundColor DarkYellow
        } finally {
            if ($null -ne $Client) { $Client.Close() }
        }
    }
} catch {
    Write-Host ''
    Write-Host "SERVER FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Close another server or try again.' -ForegroundColor Yellow
    exit 1
} finally {
    if ($null -ne $Listener) { $Listener.Stop() }
}
