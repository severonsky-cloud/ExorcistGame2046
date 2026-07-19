import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const port = Number(process.env.PORT || 8080);

const mime = new Map([
  ['.html', 'text/html; charset=utf-8'],
  ['.htm', 'text/html; charset=utf-8'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.mjs', 'text/javascript; charset=utf-8'],
  ['.css', 'text/css; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.png', 'image/png'],
  ['.jpg', 'image/jpeg'],
  ['.jpeg', 'image/jpeg'],
  ['.svg', 'image/svg+xml'],
  ['.ico', 'image/x-icon'],
  ['.txt', 'text/plain; charset=utf-8']
]);

const corePatch = `const player={x:0,y:1.7,z:4,yaw:0,pitch:0,vx:0,vz:0,crouch:false,sceneSpawn:null};
const keys={}, touchMove={x:0,y:0};
function box(x,y,z,sx,sy,sz,color=C.wall,opt={}){const e={x,y,z,sx,sy,sz,color,solid:opt.solid!==false,tag:opt.tag||'',label:opt.label||'',interact:opt.interact||null,em:opt.em||0,ry:opt.ry||0,hidden:false};W.push(e);return e}
function npc(x,z,type,label,opt={}){const n={x,z,y:0,type,label,dir:opt.dir||0,patrol:opt.patrol||null,speed:opt.speed||1,phase:Math.random()*6.28,hostile:false,hidden:false};NPC.push(n);return n}
function clearWorld(){W=[];NPC=[];near=null}
function roomShell(w,d,h,color=C.wall){box(0,-.15,0,w,.3,d,C.floor,{solid:false});box(0,h,0,w,.25,d,C.dark);box(-w/2,h/2,0,.25,h,d,color);box(w/2,h/2,0,.25,h,d,color);box(0,h/2,-d/2,w,h,.25,color);box(0,h/2,d/2,w,h,.25,color)}
function buildCity(){scene='city';clearWorld();box(0,-.3,0,140,.6,140,[.11,.14,.13],{solid:false});player.x=-53;player.z=34;player.yaw=0;objective('Добраться до центра города')}
function buildMission(){scene='mission';clearWorld();roomShell(18,18,4.5,[.3,.27,.23]);player.x=0;player.z=6.8;player.yaw=0;objective('Осмотреть квартиру архитектора')}
`;

const viewModelCss = `<style id="runtime-viewmodel-fix">
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
</style>`;

const runtimePatch = `
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
`;

function patchedGameHtml() {
  const indexPath = path.join(root, 'index.html');
  let html = fs.readFileSync(indexPath, 'utf8');

  if (!html.includes('const player={x:0,y:1.7,z:4')) {
    const marker = 'function useTool(n){';
    if (!html.includes(marker)) throw new Error('Runtime patch marker was not found in index.html');
    html = html.replace(marker, corePatch + marker);
  }

  html = html
    .replace('Object.assign(state,{timeOfDay:8.25', 'Object.assign(state,{timeOfDay:20.45')
    .replace("coop.panel.classList.add('open');coopRefreshUI();toast('Нажмите K:", "coop.panel.classList.remove('open');coopRefreshUI();toast('Нажмите K:")
    .replace('</head>', `${viewModelCss}\n</head>`)
    .replace('requestAnimationFrame(loop);', `${runtimePatch}\nrequestAnimationFrame(loop);`);

  return html;
}

function send(res, status, body, type = 'text/plain; charset=utf-8') {
  const data = Buffer.isBuffer(body) ? body : Buffer.from(body);
  res.writeHead(status, {
    'Content-Type': type,
    'Content-Length': data.length,
    'Cache-Control': 'no-store',
    'Access-Control-Allow-Origin': '*',
    'Cross-Origin-Resource-Policy': 'cross-origin'
  });
  res.end(data);
}

const server = http.createServer((req, res) => {
  try {
    const requestUrl = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
    let pathname = decodeURIComponent(requestUrl.pathname);

    if (pathname === '/' || pathname === '/play.html' || pathname === '/index.html') {
      send(res, 200, patchedGameHtml(), 'text/html; charset=utf-8');
      return;
    }

    const fullPath = path.resolve(root, `.${pathname}`);
    if (!fullPath.startsWith(root + path.sep)) {
      send(res, 403, '403 Forbidden');
      return;
    }

    if (!fs.existsSync(fullPath) || !fs.statSync(fullPath).isFile()) {
      send(res, 404, '404 Not Found');
      return;
    }

    send(res, 200, fs.readFileSync(fullPath), mime.get(path.extname(fullPath).toLowerCase()) || 'application/octet-stream');
  } catch (error) {
    send(res, 500, `500 Server Error\n${error.stack || error.message}`);
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`ExorcistGame2046: http://localhost:${port}/`);
  console.log('The server patches the game before sending it; no browser fetch loader is used.');
  console.log('Keep this window open. Press Ctrl+C to stop.');
});
