const fs = require('fs');
const path = require('path');
const { minify } = require('terser');
const glob = require('glob');

const root = path.resolve(__dirname, '..');
const outRoot = path.join(root, 'dist');

function ensureDir(p) {
  if (!fs.existsSync(p)) fs.mkdirSync(p, { recursive: true });
}

function minifyFile(src, dest) {
  const code = fs.readFileSync(src, 'utf8');
  return minify(code, { 
    ecma: 5, 
    compress: { 
      reduce_funcs: false,
      drop_console: false,
      drop_debugger: true,
      pure_funcs: []
    }, 
    mangle: true,
    format: {
      comments: false
    }
  }).then(result => {
    if (result.error) {
      throw result.error;
    }
    ensureDir(path.dirname(dest));
    fs.writeFileSync(dest, result.code, 'utf8');
    console.log('minified:', src, '->', dest);
  }).catch(err => {
    console.error('minify error:', src, err);
    throw err;
  });
}

async function run() {
  console.log('Minify start...');
  // patterns for JS files in project (app, pages, components)
  const patterns = [
    path.join(root, 'app.js'),
    path.join(root, 'pages', '**', '*.js'),
    path.join(root, 'components', '**', '*.js')
  ];

  const files = patterns.flatMap(p => glob.sync(p, { nodir: true }));
  for (const f of files) {
    const rel = path.relative(root, f);
    const out = path.join(outRoot, rel);
    await minifyFile(f, out);
  }

  // Also copy non-js assets (wxml, wxss, json, images)
  const assets = glob.sync(path.join(root, '**', '*.*'), { nodir: true, ignore: ['**/node_modules/**', '**/dist/**', '**/scripts/**', '**/package.json', '**/package-lock.json'] });
  for (const a of assets) {
    const ext = path.extname(a).toLowerCase();
    if (ext === '.js') continue;
    const rel = path.relative(root, a);
    const out = path.join(outRoot, rel);
    ensureDir(path.dirname(out));
    fs.copyFileSync(a, out);
  }

  console.log('Minify complete. Dist available at', outRoot);
}

run();
