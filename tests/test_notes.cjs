const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const notes = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'Notes.js'), 'utf8'), notes);

const rendered = notes.render('## Added\n\n- **A feature** with `code`\n\nRemoved from new installs only.');
assert.match(rendered, /<h3>Added<\/h3>/);
assert.match(rendered, /<li><b>A feature<\/b> with <code>code<\/code><\/li>/);
assert.match(rendered, /Removed from new installs only\./);
const hostile = notes.render('<script>bad()</script>\n\n<img src="https://example.com/pixel">\n\n![image](https://example.com/image)\n\n[click](javascript:bad)');
assert.ok(!hostile.includes('<script>'));
assert.ok(!hostile.includes('<img'));
assert.ok(!hostile.includes('href='));
assert.ok(!hostile.includes('https://example.com'));
assert.match(notes.render('```sh\necho "<test>"\n```'), /<pre>echo &quot;&lt;test&gt;&quot;<\/pre>/);
console.log('Notes rendering and escaping tests passed');
