const { test } = require('node:test');
const assert = require('node:assert/strict');
const ts = require('typescript');
const fs = require('node:fs');
// Compile these pure schema modules in memory. No Firebase or external writes.
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(
  fs.readFileSync(filename, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }
).outputText, filename);
const { WaitlistSchema, scoreAnswers, WAITLIST_QUESTION_IDS } = require('../src/app/campus/campus.model.ts');
test('waitlist payload: strict, normalises email, scores server-side', () => {
  const answers = Object.fromEntries(WAITLIST_QUESTION_IDS.map(id => [id, 2]));
  const ok = WaitlistSchema.parse({ email: ' A@B.com ', consent: true, answers });
  assert.equal(ok.email, 'a@b.com');
  assert.deepEqual(scoreAnswers(ok.answers), { R: 10, I: 10, A: 10, S: 10, E: 10, C: 10 });
  assert.equal(WaitlistSchema.safeParse({ email: 'a@b.com', consent: true }).success, true);
  assert.equal(WaitlistSchema.safeParse({ email: 'a@b.com', consent: false }).success, false);
  assert.equal(WaitlistSchema.safeParse({ email: 'a@b.com', consent: true, answers: { ...answers, R1: 3 } }).success, false);
  assert.equal(WaitlistSchema.safeParse({ email: 'a@b.com', consent: true, answers: { ...answers, X9: 1 } }).success, false);
  assert.equal(WaitlistSchema.safeParse({ email: 'nope', consent: true }).success, false);
});
