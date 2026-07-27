const fs = require('fs');
const path = require('path');

function walk(dir) {
  let results = [];
  const list = fs.readdirSync(dir);
  list.forEach(file => {
    file = path.join(dir, file);
    const stat = fs.statSync(file);
    if (stat && stat.isDirectory()) {
      results = results.concat(walk(file));
    } else if (file.endsWith('.dart')) {
      results.push(file);
    }
  });
  return results;
}

const files = walk('lib');
let changed = false;

files.forEach(file => {
  let content = fs.readFileSync(file, 'utf8');
  let original = content;
  
  const lines = content.split('\n');
  
  // Sometimes 'const' is on a previous line than AppLocalizations!
  // To handle multiline correctly, let's use a regex on the full content.
  // We want to replace 'const Type( ... AppLocalizations' with 'Type( ... AppLocalizations'
  // But regex across multiline in JS can be tricky. Let's do a simple approach:
  // If the file contains AppLocalizations, we replace 'const InputDecoration', 'const Text', 'const PopupMenuItem', 'const Row', 'const Icon'
  // with their non-const equivalents IF they enclose an AppLocalization.
  // Actually, just removing ALL 'const ' before those types in files containing AppLocalizations is safer and faster.
  
  if (content.includes('AppLocalizations')) {
     content = content
        .replace(/const\s+InputDecoration\b/g, 'InputDecoration')
        .replace(/const\s+Text\b/g, 'Text')
        .replace(/const\s+PopupMenuItem\b/g, 'PopupMenuItem')
        .replace(/const\s+Row\b/g, 'Row')
        .replace(/const\s+Icon\b/g, 'Icon');
  }
  
  if (content !== original) {
    fs.writeFileSync(file, content);
    console.log(`Fixed ${file}`);
    changed = true;
  }
});

if (!changed) {
  console.log('No files needed fixing.');
}
