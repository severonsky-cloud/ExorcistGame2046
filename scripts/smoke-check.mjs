import fs from 'node:fs';

const indexUrl = new URL('../index.html', import.meta.url);
const playUrl = new URL('../play.html', import.meta.url);
const index = fs.readFileSync(indexUrl, 'utf8');
const play = fs.readFileSync(playUrl, 'utf8');

const scriptMatch = index.match(/<script>[\s\S]*?\n\(\(\) => \{([\s\S]*)\}\)\(\);\s*<\/script>/);
if (!scriptMatch) throw new Error('Main game script was not found in index.html');
new Function(scriptMatch[1]);

const indexMarkers = [
  'EXORCIST GAME 2046: TWO-PLAYER COOP FOUNDATION',
  'RTCPeerConnection',
  'buildCoopStairwell',
  'fbkFund',
  'channelMoney',
  'FUNCTIONAL HANDS + PHONE RIG PASS',
  'BLOOD COUNTESS QUEST REBUILD'
];
for (const marker of indexMarkers) {
  if (!index.includes(marker)) throw new Error(`Required index marker missing: ${marker}`);
}

const recoveryMarkers = [
  "fetch('./index.html'",
  'const player={x:0,y:1.7,z:4',
  'function clearWorld()',
  'function buildCity()',
  'function buildMission()',
  'document.write(html)'
];
for (const marker of recoveryMarkers) {
  if (!play.includes(marker)) throw new Error(`Required recovery marker missing: ${marker}`);
}

console.log('Syntax, co-op markers and recovery launcher: OK');
