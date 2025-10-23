// Test if genkit instance creates circular references
const { genkit } = require('genkit');
const { vertexAI } = require('@genkit-ai/vertexai');

console.log('Creating genkit instance...');

const ai = genkit({
  plugins: [vertexAI({
    projectId: 'balli-project',
    location: 'us-central1'
  })],
  promptDir: './prompts'
});

console.log('Genkit instance created');
console.log('ai keys:', Object.keys(ai));

// Check for circular references in ai
const seen = new WeakSet();

function hasCircular(obj, path = 'ai', depth = 0) {
  if (depth > 5) return false;
  if (!obj || typeof obj !== 'object') return false;

  if (seen.has(obj)) {
    console.log('CIRCULAR at:', path);
    return true;
  }

  seen.add(obj);

  for (const key in obj) {
    try {
      if (hasCircular(obj[key], `${path}.${key}`, depth + 1)) {
        return true;
      }
    } catch (e) {
      // Skip errors
    }
  }

  return false;
}

const foundCircular = hasCircular(ai);
console.log('Has circular:', foundCircular);
