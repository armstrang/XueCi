/* Interface text for the app, from content/i18n/i18n*.js.

     node mobile/tool/make_i18n.js OUT_DIR

   The JS files are run in a vm (twice: without and with the sealed blocks) and every value is written as JSON.
   Functions (text with numbers in it, e.g. n => `${n} words`) become small expression trees that lib/i18n/tpl.dart
   evaluates: template literals, ?:, + - * / %, comparisons, && || !, member access, and calls of helper arrows
   defined in the same files (inlined). Anything else stops the build, so nothing is silently lost.

   Writes OUT_DIR/i18n-<lang>.json (the text everyone has) and OUT_DIR/i18n-sealed.json (the text that only exists
   past the gate: make_assets.py puts it into the sealed part; it must never be shipped as it is). */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
let acorn;
for (const p of ['acorn', path.join(__dirname, 'node_modules', 'acorn'), '/opt/node-tools/node_modules/acorn']) {
  try {
    acorn = require(p);
    break;
  } catch (e) {}
}
if (!acorn) throw new Error('acorn missing: npm install --prefix mobile/tool acorn@8');

const ROOT = path.join(__dirname, '..', '..');
const OUT = process.argv[2] || path.join(__dirname, '..', 'build', 'gen');
const FILES = ['i18n.js', 'i18n-app.js', 'i18n-learn.js'];
const SEAL = /\/\*<seal>\*\/([\s\S]*?)\/\*<\/seal>\*\//g;
const LANGS = ['id', 'en', 'th', 'vi'];

const src = FILES.map(f => fs.readFileSync(path.join(ROOT, 'content', 'i18n', f), 'utf8'));

function load(sealed) {
  const ctx = {};
  vm.createContext(ctx);
  const text = src.map(s => (sealed ? s.replace(SEAL, '$1') : s.replace(SEAL, ''))).join('\n;\n');
  vm.runInContext(text + '\n;globalThis.I18N = I18N;', ctx);
  return ctx.I18N;
}

/* helper arrows declared in the files (const r = m => ...): inlined where they are called */
const HELPERS = new Map();
for (const s of src) {
  const ast = acorn.parse(s, { ecmaVersion: 2022 });
  (function walk(n) {
    if (!n || typeof n !== 'object') return;
    if (n.type === 'VariableDeclarator' && n.id.type === 'Identifier' && n.init && n.init.type === 'ArrowFunctionExpression')
      HELPERS.set(n.id.name, n.init);
    for (const k in n) if (k !== 'type') Array.isArray(n[k]) ? n[k].forEach(walk) : walk(n[k]);
  })(ast);
}

const OPS = new Set(['+', '-', '*', '/', '%', '===', '!==', '==', '!=', '<', '>', '<=', '>=']);
function conv(n, env, where) {
  const bad = () => {
    throw new Error(`${where}: cannot convert ${n.type} ${n.operator || ''}`);
  };
  switch (n.type) {
    case 'Literal':
      if (typeof n.value === 'string') return ['s', n.value];
      if (typeof n.value === 'number') return ['n', n.value];
      if (typeof n.value === 'boolean') return ['b', n.value];
      if (n.value === null) return ['null'];
      return bad();
    case 'TemplateLiteral': {
      const parts = [];
      n.quasis.forEach((q, i) => {
        parts.push(q.value.cooked);
        if (i < n.expressions.length) parts.push(conv(n.expressions[i], env, where));
      });
      return ['t', parts];
    }
    case 'Identifier':
      if (env.has(n.name)) return env.get(n.name);
      if (n.name === 'undefined') return ['null'];
      throw new Error(`${where}: free name ${n.name}`);
    case 'ConditionalExpression':
      return ['?', conv(n.test, env, where), conv(n.consequent, env, where), conv(n.alternate, env, where)];
    case 'BinaryExpression':
      if (!OPS.has(n.operator)) return bad();
      return ['op', n.operator, conv(n.left, env, where), conv(n.right, env, where)];
    case 'LogicalExpression':
      if (n.operator !== '&&' && n.operator !== '||') return bad();
      return [n.operator, conv(n.left, env, where), conv(n.right, env, where)];
    case 'UnaryExpression':
      if (n.operator === '!') return ['!', conv(n.argument, env, where)];
      if (n.operator === '-') return ['neg', conv(n.argument, env, where)];
      if (n.operator === '+') return ['num', conv(n.argument, env, where)];
      return bad();
    case 'MemberExpression':
      return ['.', conv(n.object, env, where), n.computed ? conv(n.property, env, where) : ['s', n.property.name]];
    case 'CallExpression': {
      if (n.callee.type === 'Identifier' && HELPERS.has(n.callee.name)) {
        const h = HELPERS.get(n.callee.name),
          e2 = new Map(env);
        h.params.forEach((p, i) => e2.set(p.name, n.arguments[i] ? conv(n.arguments[i], env, where) : ['null']));
        if (h.body.type === 'BlockStatement') return bad();
        return conv(h.body, e2, where + ' > ' + n.callee.name);
      }
      return bad();
    }
    default:
      return bad();
  }
}

function fnTree(f, where) {
  const text = f.toString();
  const ast = acorn.parse('(' + text + ')', { ecmaVersion: 2022 }).body[0].expression;
  if (ast.type !== 'ArrowFunctionExpression' && ast.type !== 'FunctionExpression') throw new Error(where + ': not a function');
  const env = new Map();
  ast.params.forEach((p, i) => {
    if (p.type !== 'Identifier') throw new Error(where + ': destructured parameter');
    env.set(p.name, ['a', i]);
  });
  if (ast.body.type === 'BlockStatement') {
    /* a body of only `return x` is fine */
    const b = ast.body.body;
    if (b.length === 1 && b[0].type === 'ReturnStatement') return { $f: ast.params.length, b: conv(b[0].argument, env, where) };
    throw new Error(where + ': function with statements');
  }
  return { $f: ast.params.length, b: conv(ast.body, env, where) };
}

function json(v, where) {
  if (typeof v === 'function') return fnTree(v, where);
  if (Array.isArray(v)) return v.map((x, i) => json(x, `${where}[${i}]`));
  if (v && typeof v === 'object') {
    const o = {};
    for (const k of Object.keys(v)) o[k] = json(v[k], `${where}.${k}`);
    return o;
  }
  return v;
}

const pub = load(false),
  full = load(true);
fs.mkdirSync(OUT, { recursive: true });
const sealed = {};
for (const l of LANGS) {
  const P = json(pub[l], l),
    F = json(full[l], l);
  fs.writeFileSync(path.join(OUT, `i18n-${l}.json`), JSON.stringify(P));
  /* the sealed part: every top-level value the sealed blocks add or change, whole */
  const d = {};
  for (const k of Object.keys(F)) if (JSON.stringify(F[k]) !== JSON.stringify(P[k])) d[k] = F[k];
  sealed[l] = d;
  console.log(`i18n ${l}: ${Object.keys(P).length} keys, sealed: ${Object.keys(d).join(' ')}`);
}
fs.writeFileSync(path.join(OUT, 'i18n-sealed.json'), JSON.stringify(sealed));
/* the keys and their kinds, for lib/i18n/keys.g.dart: from every language, sealed included */
const kinds = {};
for (const l of LANGS)
  for (const [k, v] of Object.entries(full[l])) {
    const kind = typeof v === 'function' ? 'f' + v.length : typeof v === 'string' ? 's' : Array.isArray(v) ? 'l' : v && typeof v === 'object' ? 'm' : typeof v;
    const old = kinds[k];
    if (old && old[0] === 'f' && kind[0] === 'f') kinds[k] = +old.slice(1) >= +kind.slice(1) ? old : kind;
    else if (old && old !== kind) throw new Error(`i18n: ${k} is ${old} in one language and ${kind} in ${l}`);
    else kinds[k] = kind;
  }
fs.writeFileSync(path.join(OUT, 'i18n-keys.json'), JSON.stringify(kinds));

/* lib/i18n/keys.g.dart: one typed member per key (committed; regenerated by this script) */
const RESERVED = new Set(
  'abstract as assert async await base break case catch class const continue covariant default deferred do dynamic else enum export extends extension external factory false final finally for Function get hide if implements import in interface is late library mixin new null of on operator part required rethrow return sealed set show static super switch sync this throw true try type typedef var void when while with yield s f v m'.split(' '),
);
const dn = k => (RESERVED.has(k) ? k + '_' : k);
const lines = Object.keys(kinds)
  .sort()
  .map(k => {
    const t = kinds[k],
      n = dn(k);
    if (t === 's') return `  String get ${n} => s('${k}');`;
    if (t === 'l') return `  List<dynamic> get ${n} => v('${k}') as List<dynamic>? ?? const [];`;
    if (t === 'm') return `  Map<String, dynamic> get ${n} => (v('${k}') as Map?)?.cast<String, dynamic>() ?? const {};`;
    if (t[0] === 'f') {
      const ar = +t.slice(1),
        ps = Array.from({ length: ar }, (_, i) => `Object? a${i}`).join(', ');
      return `  String ${n}(${ps}) => f('${k}', [${Array.from({ length: ar }, (_, i) => 'a' + i).join(', ')}]);`;
    }
    throw new Error('kind ' + t);
  });
const dart = `// GENERATED by mobile/tool/make_i18n.js from content/i18n/i18n*.js. Do not edit.
// ignore_for_file: non_constant_identifier_names, public_member_api_docs
part of 'l10.dart';

mixin L10Keys {
  String s(String k);
  String f(String k, List<Object?> a);
  Object? v(String k);

${lines.join('\n')}
}
`;
fs.writeFileSync(path.join(__dirname, '..', 'lib', 'i18n', 'keys.g.dart'), dart);

/* probes: every text function called with a few sets of arguments in JS, for test/i18n_test.dart to compare */
const ARGS = [
  [1, 2, 3, 4],
  [0, 0, 0, 0],
  [5, 'a', 'b', 'c'],
  [31, 2, 1, 0],
  ['x', 'y', 'z', 'w'],
  [12.5, 7, 100, 3],
  [true, false, 1, 2],
];
const probes = [];
for (const l of LANGS)
  (function walk(v, where) {
    if (typeof v === 'function') {
      for (const a of ARGS) {
        let out;
        try {
          out = v(...a);
        } catch (e) {
          continue;
        }
        if (typeof out === 'string') probes.push([l, where, a, out]);
      }
    } else if (Array.isArray(v)) v.forEach((x, i) => walk(x, [...where, i]));
    else if (v && typeof v === 'object') for (const k of Object.keys(v)) walk(v[k], [...where, k]);
  })(full[l], []);
fs.writeFileSync(path.join(OUT, 'i18n-probe.json'), JSON.stringify(probes));
console.log(`i18n probes: ${probes.length}`);
