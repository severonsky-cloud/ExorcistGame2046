import fs from "node:fs";

const path = new URL("../index.html", import.meta.url);
const html = fs.readFileSync(path, "utf8");
const match = html.match(/<script>[\s\S]*?\n\(\(\) => \{([\s\S]*)\}\)\(\);\s*<\/script>/);

if (!match) {
  throw new Error("Main game script was not found in index.html");
}

new Function(match[1]);

const requiredMarkers = [
  "EXORCIST GAME 2046: TWO-PLAYER COOP FOUNDATION",
  "RTCPeerConnection",
  "buildCoopStairwell",
  "fbkFund",
  "channelMoney",
  "coopRitualToolBase",
  "FUNCTIONAL HANDS + PHONE RIG PASS",
  "BLOOD COUNTESS QUEST REBUILD"
];

for (const marker of requiredMarkers) {
  if (!html.includes(marker)) {
    throw new Error(`Required marker missing: ${marker}`);
  }
}

console.log("Syntax and required markers: OK");
