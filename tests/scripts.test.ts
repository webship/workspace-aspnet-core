import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-aspnet-core.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['tsx/cjs'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

/**
 * A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled. An app
 * of this plugin has the builder's .ddev/config.aspnet-core.yaml; `kind` says which template, `accounts` whether it
 * was built with --install (its seeding step).
 */
function project(kind: 'webapp' | 'blazor' | 'drupal', accounts = true) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'aspnet-core-plugin-'));
  const dir = path.join(root, 'dev', 'app1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: app1\ntype: ${kind === 'drupal' ? 'drupal11' : 'generic'}\n`);
  if (kind !== 'drupal') {
    fs.writeFileSync(path.join(dir, '.ddev', 'config.aspnet-core.yaml'), 'web_extra_daemons: []\n');
    fs.mkdirSync(path.join(dir, 'app', 'Components'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'app', 'App1.csproj'), '<Project Sdk="Microsoft.NET.Sdk.Web"></Project>\n');
    fs.writeFileSync(path.join(dir, 'app', 'Program.cs'), accounts ? 'Environment.ExitCode = await AccountSeeder.RunAsync<IdentityUser>(app.Services, args);\n' : 'app.Run();\n');
    if (kind === 'blazor') fs.writeFileSync(path.join(dir, 'app', 'Components', 'App.razor'), '<!DOCTYPE html>\n');
  }
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'app1', devDependencies: { 'webship-js': '^2.0.16' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  const plugin = path.join(scripts, 'plugins', 'aspnet-core');
  fs.mkdirSync(plugin, { recursive: true });
  for (const f of ['testing/site.feature', 'scripts/app/aspnet-core-prepare-app.py', 'scripts/app/aspnet-core-app-files.json']) {
    fs.copyFileSync(path.join(PKG, f), path.join(plugin, path.basename(f)));
  }
  return { root, dir, scripts };
}

/**
 * Run bash with the plugin's functions sourced and `ddev` replaced by a recorder of its command lines; what a command
 * gets on its standard input is recorded apart (DDEV_STDIN), the home page answers 200.
 */
function bash(script: string, env: Record<string, string> = {}) {
  const fake = [
    'ddev() {',
    '  echo "ddev $*" >> "${DDEV_LOG:-/dev/null}" ;',
    '  case "$*" in',
    '    *--seed-accounts*) cat >> "${DDEV_STDIN:-/dev/null}" ; echo "administrator@example.com (Administrator)" ;;',
    '    *http_code*) echo 200 ;;',
    '    *) if [ ! -t 0 ] ; then cat > /dev/null ; fi ;;',
    '  esac',
    '  return 0 ;',
    '}',
  ].join('\n');
  return spawnSync('bash', ['-c', `${fake}\nsource ${FUNCTIONS}\n${script}`], { encoding: 'utf8', env: { ...process.env, ...env } });
}

test('the default accounts: an administrator with the Administrator role, a user, a two-factor one, a locked-out one and an unconfirmed one, at example addresses', () => {
  const r = bash('set_aspnet_core_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; g="user_${u}_role" ; s="user_${u}_state" ; echo "${!n}|${!m}|${!p}|${!g}|${!s}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['administrator', 'user', 'twofactoruser', 'lockeduser', 'unconfirmeduser']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['Administrator', '_none_', '_none_', '_none_', '_none_']);
  assert.deepStrictEqual(rows.map((x) => x[4]), ['', '', 'two-factor', 'locked-out', 'unconfirmed']);
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    assert.ok(password.length >= 10 && /\d/.test(password) && /[A-Z]/.test(password) && /[^A-Za-z0-9]/.test(password), 'a password the default password rules accept');
  }
});

test('the accounts are made by the app\'s own seeding step, the password on its standard input and never on a command line', () => {
  const p = project('webapp');
  const log = path.join(p.root, 'ddev.log');
  const stdin = path.join(p.root, 'stdin.log');
  const r = bash('set_aspnet_core_users ; add_aspnet_core_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'app1', DDEV_LOG: log, DDEV_STDIN: stdin });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const file = JSON.parse(fs.readFileSync(path.join(p.dir, 'config', 'accounts.json'), 'utf8'));
  assert.deepStrictEqual(file.roles, ['Administrator']);
  assert.deepStrictEqual(file.accounts.map((a: any) => a.email), ['administrator@example.com', 'user@example.com', 'twofactoruser@example.com', 'lockeduser@example.com', 'unconfirmeduser@example.com']);
  assert.deepStrictEqual(file.accounts[0].roles, ['Administrator']);
  assert.match(file.accounts[2].authenticatorKey, /^[A-Z2-7]{32}$/, 'two-factor sign-in with a known base32 key');
  assert.strictEqual(file.accounts[3].lockedOut, true);
  assert.strictEqual(file.accounts[4].emailConfirmed, false);
  assert.doesNotMatch(JSON.stringify(file), /dD\.123123ddd/, 'the file holds no password');
  const recorded = fs.readFileSync(log, 'utf8');
  assert.match(recorded, /ddev exec -d \/var\/www\/html\/publish Logging__LogLevel__Default=Warning dotnet App1\.dll --seed-accounts \/var\/www\/html\/config\/accounts\.json/, 'the published app runs its seeding step');
  assert.doesNotMatch(recorded, /dD\.123123ddd/, 'no password on a command line');
  assert.strictEqual(fs.readFileSync(stdin, 'utf8'), 'dD.123123ddd', 'the password on the standard input of the seeding step');
});

test('cancelling the default accounts runs the seeding step with --cancel-accounts', () => {
  const p = project('blazor');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('set_aspnet_core_users ; cancel_aspnet_core_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'app1', DDEV_LOG: log });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  assert.match(fs.readFileSync(log, 'utf8'), /dotnet App1\.dll --cancel-accounts \/var\/www\/html\/config\/accounts\.json/);
});

test('an app built without --install has no seeding step: the tools say so and change nothing', () => {
  const p = project('webapp', false);
  const r = bash('set_aspnet_core_users ; add_aspnet_core_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'app1' });
  assert.notStrictEqual(r.status, 0);
  assert.match(r.stdout, /built without --install/);
  assert.ok(!fs.existsSync(path.join(p.dir, 'config', 'accounts.json')));
});

test('the claim file and the web image: the daemon, the port, the settings, the SDK of the official image', () => {
  const p = project('webapp');
  const r = bash(`aspnet_core_write_ddev_config "${p.dir}" 10.0 MyApp`);
  assert.strictEqual(r.status, 0, r.stderr);
  const claim = fs.readFileSync(path.join(p.dir, '.ddev', 'config.aspnet-core.yaml'), 'utf8');
  assert.match(claim, /container_port: 5000\n    http_port: 80\n    https_port: 443/);
  assert.match(claim, /cd \/var\/www\/html\/publish && exec dotnet MyApp\.dll/);
  assert.match(claim, /^  - ASPNETCORE_ENVIRONMENT=Production$/m, 'a live app by default');
  assert.match(claim, /ConnectionStrings__DefaultConnection=DataSource=\/var\/www\/html\/data\/app\.db;Cache=Shared/);
  const docker = fs.readFileSync(path.join(p.dir, '.ddev', 'web-build', 'Dockerfile.aspnet-core'), 'utf8');
  assert.match(docker, /^COPY --from=mcr\.microsoft\.com\/dotnet\/sdk:10\.0 \/usr\/share\/dotnet \/usr\/share\/dotnet$/m);
  assert.match(docker, /ln -sf \/usr\/share\/dotnet\/dotnet \/usr\/local\/bin\/dotnet/);
});

test('the namespace of an app is its project name in Pascal case', () => {
  const r = bash('for n in aspsite my-app 2go shop-2026-a ; do aspnet_core_namespace "$n" ; echo ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  assert.deepStrictEqual(r.stdout.trim().split('\n'), ['Aspsite', 'MyApp', 'App2go', 'Shop2026A']);
});

test('the testing hook adds the pack, the pages of the app, the browser messages and the users registry, once', () => {
  for (const kind of ['webapp', 'blazor'] as const) {
    const p = project(kind);
    const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'app1' };
    const first = bash(`testing_configure_aspnet_core "${p.dir}"`, env);
    assert.strictEqual(first.status, 0, first.stderr + first.stdout);
    const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
    assert.strictEqual(pkg.devDependencies['@webship-js/aspnet-core-steps'], '^2.0.0');
    const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
    assert.match(cucumber, /'node_modules\/webship-js\/tests\/step-definitions\/\*\*\/\*\.js',.*\n\s+'node_modules\/@webship-js\/aspnet-core-steps\/tests\/step-definitions\/\*\*\/\*\.js',/, 'the pack after webship-js');
    assert.match(cucumber, /tags: process\.env\.CUCUMBER_TAGS \|\| 'not @wip and not @must-fail',/);
    assert.match(cucumber, new RegExp(`accountPath: '${kind === 'webapp' ? '/Identity/Account' : '/Account'}',`), `where the account pages of the ${kind} app are`);
    assert.match(cucumber, new RegExp(`protectedPath: '${kind === 'webapp' ? '/Movies' : '/auth'}',`), `a page only a signed-in account opens, of the ${kind} app`);
    assert.match(cucumber, /mailUrl: process\.env\.MAIL_URL \|\| 'https:\/\/app1\.ddev\.site:8026',/);
    assert.match(cucumber, /javascript: \{ mode: process\.env\.WEBSHIP_JS_ERROR_MODE \|\| 'warn'/);
    assert.match(cucumber, /administrator: \{ email: process\.env\.ASPNET_CORE_ADMINISTRATOR_EMAIL \|\| 'administrator@example\.com', password: process\.env\.ASPNET_CORE_ADMINISTRATOR_PASSWORD \|\| 'dD\.123123ddd' \},/);
    assert.match(cucumber, /twofactoruser: \{ email: [^}]*, otpSecret: process\.env\.ASPNET_CORE_TWOFACTORUSER_OTP_SECRET \|\| '[A-Z2-7]{32}' \},/);
    assert.match(cucumber, /process\.env\.LAUNCH_URL \|\| 'https:\/\/app1\.ddev\.site'/, 'the address of the app');
    const feature = fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8');
    assert.match(feature, new RegExp(`When I go to "${kind === 'webapp' ? '/Movies' : '/auth'}"`), 'a first feature with the page of the app');
    assert.match(first.stdout, /the default accounts are in the app \(administrator user twofactoruser lockeduser unconfirmeduser\)/);
    // A second run adds nothing and resets nothing.
    const again = bash(`testing_configure_aspnet_core "${p.dir}"`, env);
    assert.strictEqual(again.status, 0, again.stderr);
    assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber, 'the second run changes nothing in cucumber.js');
  }
});

test('the testing hook leaves a project of another platform alone', () => {
  const p = project('drupal');
  const r = bash(`testing_configure_aspnet_core "${p.dir}"`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'app1' });
  assert.strictEqual(r.status, 0, r.stderr);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
  assert.strictEqual(r.stdout, '');
});
