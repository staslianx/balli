const mod = require('./lib/index.js');
const seen = new Set();
const pathsSeen = new Set();

function findCircular(obj, path = 'root', depth = 0) {
  if (depth > 15) {
    console.log('MAX DEPTH at:', path);
    return;
  }

  if (!obj || typeof obj !== 'object') return;

  const objId = JSON.stringify(Object.keys(obj).sort());
  const pathId = path + ':' + objId;

  if (pathsSeen.has(pathId)) {
    console.log('CIRCULAR DETECTED:', path);
    return;
  }

  if (seen.has(obj)) {
    console.log('CIRCULAR OBJECT REFERENCE:', path);
    return;
  }

  seen.add(obj);
  pathsSeen.add(pathId);

  for (const key in obj) {
    try {
      const newPath = path + '.' + key;
      findCircular(obj[key], newPath, depth + 1);
    } catch(e) {
      console.log('ERROR at', path + '.' + key, ':', e.message);
    }
  }
}

console.log('Starting circular reference detection...\n');
findCircular(mod);
console.log('\nDone.');
