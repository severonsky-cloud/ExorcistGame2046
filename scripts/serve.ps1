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
              "Access-Control-Allow-Origin: *`r`n" +
              "Cross-Origin-Resource-Policy: cross-origin`r`n" +
              "Connection: close`r`n`r`n"
    $HeaderBytes = [System.Text.Encoding]::ASCII.GetBytes($Header)
    $Stream.Write($HeaderBytes, 0, $HeaderBytes.Length)
    if ($Body.Length -gt 0) { $Stream.Write($Body, 0, $Body.Length) }
    $Stream.Flush()
}

function Get-PatchedGameHtml {
    $IndexPath = Join-Path $Root 'index.html'
    $Html = [System.IO.File]::ReadAllText($IndexPath, [System.Text.Encoding]::UTF8)

    $CorePatch = @'
const player={x:0,y:1.7,z:4,yaw:0,pitch:0,vx:0,vz:0,crouch:false,sceneSpawn:null};
const keys={}, touchMove={x:0,y:0};
function box(x,y,z,sx,sy,sz,color=C.wall,opt={}){const e={x,y,z,sx,sy,sz,color,solid:opt.solid!==false,tag:opt.tag||'',label:opt.label||'',interact:opt.interact||null,em:opt.em||0,ry:opt.ry||0,hidden:false};W.push(e);return e}
function npc(x,z,type,label,opt={}){const n={x,z,y:0,type,label,dir:opt.dir||0,patrol:opt.patrol||null,speed:opt.speed||1,phase:Math.random()*6.28,hostile:false,hidden:false};NPC.push(n);return n}
function clearWorld(){W=[];NPC=[];near=null}
function roomShell(w,d,h,color=C.wall){box(0,-.15,0,w,.3,d,C.floor,{solid:false});box(0,h,0,w,.25,d,C.dark);box(-w/2,h/2,0,.25,h,d,color);box(w/2,h/2,0,.25,h,d,color);box(0,h/2,-d/2,w,h,.25,color);box(0,h/2,d/2,w,h,.25,color)}
function buildCity(){scene='city';clearWorld();box(0,-.3,0,140,.6,140,[.11,.14,.13],{solid:false});player.x=-53;player.z=34;player.yaw=0;objective('Добраться до центра города')}
function buildMission(){scene='mission';clearWorld();roomShell(18,18,4.5,[.3,.27,.23]);player.x=0;player.z=6.8;player.yaw=0;objective('Осмотреть квартиру архитектора')}
'@

    if (-not $Html.Contains('const player={x:0,y:1.7,z:4')) {
        $Marker = 'function useTool(n){'
        if (-not $Html.Contains($Marker)) { throw 'Runtime patch marker was not found in index.html.' }
        $Html = $Html.Replace($Marker, $CorePatch + "`n" + $Marker)
    }

    $ViewModelCss = @'
<style id="runtime-viewmodel-fix">
#handsRig .fpHand{width:128px!important;height:176px!important;bottom:-92px!important;opacity:.72!important}
#handsRig .fpHand .palm{transform:scale(.76);transform-origin:50% 100%}
#hpLeft{left:calc(50% - 232px)!important}
#hpRight{right:calc(50% - 232px)!important}
#handsRig.runtime-rest .fpHand,#handsRig.runtime-rest #phoneModel,#handsRig.runtime-rest .ctxProp{opacity:0!important}
#handsRig.phoneOpen #phoneModel{width:142px!important;height:244px!important;bottom:12px!important;transform:translateX(-50%) translateY(58px) rotate(0deg)!important}
#handsRig.phoneOpen #hpLeft{transform:translate(-8px,82px) rotate(8deg)!important}
#handsRig.phoneOpen #hpRight{transform:translate(8px,76px) rotate(-8deg)!important}
#handsRig.selfie #phoneModel{width:138px!important;height:238px!important;transform:translateX(6%) translateY(62px) rotate(-14deg)!important}
#handsRig.selfie #hpLeft{transform:translate(-26px,82px) rotate(20deg)!important}
#handsRig.selfie #hpRight{transform:translate(42px,58px) rotate(-28deg)!important}
@media(max-width:760px){#hpLeft{left:-34px!important}#hpRight{right:-34px!important}#handsRig.phoneOpen #phoneModel{width:126px!important;height:216px!important}}
</style>
'@

    $RuntimePatch = @'
// ===== SERVER RUNTIME PATCH 0.1.2 =====
state.timeOfDay=20.45;
if(coop?.panel)coop.panel.classList.remove('open');
handPhone.toolPoseUntil=0;
const runtimeUseToolBase=useTool;
useTool=function(n){handPhone.toolPoseUntil=performance.now()+1100;runtimeUseToolBase(n);hpUpdateRig()};
const runtimeHandsBase=hpUpdateRig;
hpUpdateRig=function(){
  runtimeHandsBase();
  if(!gameStarted||!handPhone.rig)return;
  const phoneOpen=!$('#phone').classList.contains('hidden');
  const active=phoneOpen||handPhone.streaming||handPhone.selfieFlash>0||performance.now()<(handPhone.toolPoseUntil||0);
  handPhone.rig.classList.toggle('runtime-rest',!active);
};
setTimeout(()=>{if(coop?.panel)coop.panel.classList.remove('open');hpUpdateRig()},700);
// ===== END SERVER RUNTIME PATCH =====
'@

    $Html = $Html.Replace('Object.assign(state,{timeOfDay:8.25', 'Object.assign(state,{timeOfDay:20.45')
    $Html = $Html.Replace("coop.panel.classList.add('open');coopRefreshUI();toast('Нажмите K:", "coop.panel.classList.remove('open');coopRefreshUI();toast('Нажмите K:")
    $Html = $Html.Replace('</head>', $ViewModelCss + "`n</head>")
    $Html = $Html.Replace('requestAnimationFrame(loop);', $RuntimePatch + "`nrequestAnimationFrame(loop);")
    return $Html
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
    Write-Host '  EXORCIST GAME 2046 — PATCHED LOCAL SERVER' -ForegroundColor Cyan
    Write-Host "  http://localhost:$Port/" -ForegroundColor Green
    Write-Host '  Browser fetch loader removed: the server sends a ready game.' -ForegroundColor Yellow
    Write-Host '  Keep this window open. Press Ctrl+C to stop.' -ForegroundColor DarkGray
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ''

    try { Start-Process "http://localhost:$Port/" }
    catch { Write-Host "Open http://localhost:$Port/ manually." -ForegroundColor Yellow }

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

            if ($UrlPath -eq '/' -or $UrlPath -eq '/play.html' -or $UrlPath -eq '/index.html') {
                $ReadyHtml = Get-PatchedGameHtml
                $Body = [System.Text.Encoding]::UTF8.GetBytes($ReadyHtml)
                Send-Response $Stream 200 'OK' $Body 'text/html; charset=utf-8'
                continue
            }

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
    Write-Host 'Close another server or use npm start.' -ForegroundColor Yellow
    exit 1
} finally {
    if ($null -ne $Listener) { $Listener.Stop() }
}
