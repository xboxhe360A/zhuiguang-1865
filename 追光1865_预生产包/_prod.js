const fs = require('fs'), https = require('https');
const KEY = JSON.parse(fs.readFileSync('C:/Users/C/.qoder-cn/settings.json', 'utf8')).mcpServers.agnes.env.AGNES_API_KEY;
const OUT = 'C:/Users/C/Documents/Qoder/2026-10-12/27d21b2f/追光1865_预生产包/图片/';
const jobs = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const sleep = ms => new Promise(r => setTimeout(r, ms));
function post(body) {
  return new Promise((res, rej) => {
    const data = JSON.stringify(body);
    const req = https.request({ host: 'api.agnes-ai.cn', path: '/v1/images/generations', method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + KEY, 'Content-Length': Buffer.byteLength(data) } },
      r => { let b = ''; r.on('data', c => b += c); r.on('end', () => res({ code: r.statusCode, body: b })); });
    req.on('error', rej); req.write(data); req.end();
  });
}
function get(url) {
  return new Promise((res, rej) => {
    https.get(url, r => {
      if (r.statusCode >= 300 && r.headers.location) return res(get(r.headers.location));
      const ch = []; r.on('data', c => ch.push(c)); r.on('end', () => res(Buffer.concat(ch)));
    }).on('error', rej);
  });
}
(async () => {
  for (const j of jobs) {
    const body = { model: 'agnes-image-2.5-flash', prompt: j.prompt, size: '2K', aspect_ratio: j.ratio };
    if (j.ref) body.image = 'data:image/png;base64,' + fs.readFileSync(j.ref).toString('base64');
    let ok = false;
    for (let a = 1; a <= 24 && !ok; a++) {
      try {
        const r = await post(body);
        if (r.code === 200) {
          const p = JSON.parse(r.body); const url = p.data && p.data[0] && p.data[0].url;
          if (url) { fs.writeFileSync(OUT + j.name + '.png', await get(url)); console.log('OK ' + j.name + ' attempt ' + a); ok = true; }
          else { console.log('NOURL ' + j.name + ' ' + r.body.slice(0, 120)); await sleep(25000); }
        } else { console.log('retry ' + j.name + ' ' + a + ' ' + r.code + ' ' + r.body.slice(0, 80)); await sleep(25000); }
      } catch (e) { console.log('err ' + j.name + ' ' + a + ' ' + e.message); await sleep(25000); }
    }
    if (!ok) console.log('FAIL ' + j.name);
  }
  console.log('DONE ' + process.argv[2]);
})();
