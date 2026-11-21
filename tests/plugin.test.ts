import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';

import { register, assistantContext, PLATFORM, COMMANDS, AGENTS } from '../src/index';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const read = (f: string) => fs.readFileSync(path.join(PKG, f), 'utf8');
const manifest = JSON.parse(read('package.json')).workspacePlugin;

test('the manifest names the platform, and every file it names ships', () => {
  assert.strictEqual(manifest.name, PLATFORM);
  const named = [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args, ...manifest.scripts.machine,
    ...manifest.ai.agents, ...manifest.ai.skills, ...manifest.ai.commands, ...manifest.ai.prompts, ...manifest.features];
  for (const f of named) assert.ok(fs.existsSync(path.join(PKG, f)), `${f} is in the package`);
  assert.deepStrictEqual(manifest.commands.files.map((f: string) => path.basename(f)), COMMANDS);
  assert.deepStrictEqual(manifest.ai.agents.map((f: string) => path.basename(f, '.md')), AGENTS);
  assert.deepStrictEqual(manifest.commands.types, ['sites'], 'the commands go to sites folders only');
  const files: string[] = JSON.parse(read('package.json')).files;
  for (const f of named) assert.ok(files.includes(f.split('/')[0]), `${f} is published with the package`);
  // The machine files land side by side in core/scripts/plugins/aspnet-core/: no two may share a name.
  const names = manifest.scripts.machine.map((f: string) => path.basename(f));
  assert.strictEqual(new Set(names).size, names.length, 'the machine files have names of their own');
});

test('every command finds the workspace by itself, names its folder, and sources its args from where the installer puts them', () => {
  for (const f of manifest.commands.files) {
    const src = read(f);
    assert.match(src, /^#!\/usr\/bin\/env bash/, `${f} is a bash script`);
    assert.match(src, /WORKSPACE_SCRIPTS="\$\{WORKSPACE_SCRIPTS:-\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)\/\.\.\/core\/scripts" && pwd\)\}"/, `${f} locates the tooling from its own path`);
    assert.match(src, /workspace\.__WORKSPACE__\.settings\.yml/, `${f} loads the settings of the folder it is installed into`);
    assert.match(src, /source \$\{WORKSPACE_SCRIPTS\}\/plugins\/aspnet-core\/args\/arg-[a-z-]+\.sh \|\| exit 1 ;/, `${f} reads its arguments from the plugin's args`);
    assert.match(src, /^distribution_name="aspnet_core";$/m, `${f}: the user list of the core's tools is aspnet_core`);
    const last = src.trim().split('\n').pop() as string;
    assert.match(read('scripts/functions/fun-aspnet-core.sh'), new RegExp(`^function ${last.replace(/ ;$/, '')}\\(\\)`, 'm'), `${f} ends by calling a function the plugin defines`);
  }
  assert.match(read('commands/cmd-aspnet-core-project.sh'), /^# workspace-name: ASP\.NET Core/m, 'the builder carries the name the Build list shows');
  assert.doesNotMatch(read('commands/cmd-tools-aspnet-core-cli.sh'), /^# workspace-name:/m, 'a tool is not a builder');
});

test('every shell script and the preparation script parse, and the bundle of the app files reads', () => {
  for (const f of [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args]) {
    const r = spawnSync('bash', ['-n', path.join(PKG, f)], { encoding: 'utf8' });
    assert.strictEqual(r.status, 0, `${f}: ${r.stderr}`);
  }
  const py = spawnSync('python3', ['-c', 'import ast, sys; ast.parse(open(sys.argv[1]).read())', path.join(PKG, 'scripts/app/aspnet-core-prepare-app.py')], { encoding: 'utf8' });
  assert.strictEqual(py.status, 0, py.stderr);
  const bundle = JSON.parse(read('scripts/app/aspnet-core-app-files.json'));
  for (const f of ['common/Data/AccountSeeder.cs', 'common/Services/SmtpEmailSender.cs', 'webapp/Pages/Admin/Index.cshtml', 'webapp/Pages/StatusCode.cshtml', 'webapp/Pages/Movies/Index.cshtml', 'blazor/Components/Pages/Admin.razor', 'blazor/Components/Account/IdentitySmtpEmailSender.cs']) {
    assert.ok(typeof bundle[f] === 'string' && bundle[f].length > 100, `the bundle carries ${f}`);
  }
  for (const [f, text] of Object.entries(bundle)) {
    if (/\.cs$/.test(f)) assert.match(text as string, /^namespace __APP__(\.[A-Za-z.]+)?;$/m, `${f} takes the namespace of the app`);
  }
});

test('the claim file is the plugin\'s own name, and is a real overlay of the container tool: the daemon, the port, the settings', () => {
  const src = read('scripts/functions/fun-aspnet-core.sh');
  assert.match(src, /\.ddev\/config\.aspnet-core\.yaml/, 'the file the core reads as the plugin\'s claim (#490): config.<plugin>.yaml');
  const yaml = (src.match(/config\.aspnet-core\.yaml" <<YAMLEOF\n([\s\S]*?)\nYAMLEOF/) || [])[1] || '';
  assert.match(yaml, /^web_extra_exposed_ports:\n  - name: aspnet-core\n    container_port: \$\{ASPNET_CORE_PORT\}\n    http_port: 80\n    https_port: 443$/m, 'the router sends the project\'s address to the app\'s port');
  assert.match(yaml, /^web_extra_daemons:\n  - name: aspnet-core\n    command: ".*exec dotnet \$\{app_name\}\.dll'"/m, 'the web container runs the published app as a daemon');
  assert.match(yaml, /ASPNETCORE_FORWARDEDHEADERS_ENABLED=true/, 'the app reads the forwarded headers of the router');
  assert.match(yaml, /Smtp__Port=1025/, 'the mail goes to the mail catcher');
  assert.match(yaml, /NUGET_PACKAGES=\$\{ASPNET_CORE_ROOT\}\/\.nuget\/packages/, 'NuGet keeps its downloads in the project');
  assert.match(src, /^function set_aspnet_core_users\(\) \{/m, 'the claim names a plugin with a user list: set_<plugin>_users with the dash as an underscore');
});

test('the functions carry the names the core\'s tools look for, and build the app the official way', () => {
  const src = read('scripts/functions/fun-aspnet-core.sh');
  for (const fn of ['set_aspnet_core_users', 'add_aspnet_core_users', 'cancel_aspnet_core_users', 'testing_configure_aspnet_core', 'aspnet_core_build', 'aspnet_core_cli_tool']) {
    assert.match(src, new RegExp(`^function ${fn}\\(\\) \\{`, 'm'), `${fn} is defined`);
  }
  assert.match(src, /--project-type=generic --webserver-type=generic --docroot=app/, 'a generic project whose web container runs the app itself');
  assert.match(src, /--omit-containers=db/, 'the app keeps its own data (SQLite)');
  assert.match(src, /--nodejs-version=\$\(ddev_nodejs_version\)/, 'the project carries the Node.js of the workspace rule');
  assert.match(src, /COPY --from=mcr\.microsoft\.com\/dotnet\/sdk:\$\{dotnet_version\} \/usr\/share\/dotnet \/usr\/share\/dotnet/, 'the .NET SDK from its official image');
  assert.match(src, /"new \$\{template\} --auth Individual -o app -n \$\{app_name\} --force"/, 'the app made with dotnet new from an official template with individual accounts');
  assert.match(src, /readonly ASPNET_CORE_DEFAULT_DOTNET='11\.0';/, 'the current .NET release');
  assert.match(src, /printf '%s' "\$\{!password\}" \| ddev exec/, 'the password goes to the seeding step on its standard input, never on a command line');
  assert.match(src, /DOTNET_CLI_TELEMETRY_OPTOUT=1/, 'the SDK sends no telemetry');
  assert.doesNotMatch(src, /ddev stop -y/, 'ddev stop takes no -y');
});

test('the help of --dotnet says how to give options alone: joined to the flag with =', () => {
  // Python's argument parser takes a value that starts with a dash for an option: --dotnet "--info" stops the tool.
  assert.match(read('scripts/args/arg-aspnet-core-cli.sh'), /A value that starts with a dash is joined to the flag with =\. Example: [^']*--dotnet="--info"/);
  assert.ok(read('README.md').includes('--dotnet="--info"'), 'the README shows it');
  assert.ok(read('ai/agents/aspnet-core-site-builder.md').includes('--dotnet="--info"'), 'the site-builder agent shows it');
});

test('the preparation script is the step pack\'s, and finds its files in the bundle beside it', () => {
  const py = read('scripts/app/aspnet-core-prepare-app.py');
  assert.match(py, /BUNDLE = os\.path\.join\(HERE, 'aspnet-core-app-files\.json'\)/, 'it reads the bundle beside it');
  assert.match(py, /\.AddRoles<IdentityRole>\(\)/, 'the Administrator role');
  assert.match(py, /UseStatusCodePagesWithReExecute\("\/StatusCode", "\?code=\{0\}"\)/, 'the status code page of the Razor Pages app');
  const seeder = JSON.parse(read('scripts/app/aspnet-core-app-files.json'))['common/Data/AccountSeeder.cs'];
  assert.match(seeder, /await Console\.In\.ReadToEndAsync\(\)/, 'the seeding step reads the password from standard input');
  assert.match(seeder, /users\.CreateAsync\(user, password\)/, 'the accounts are made through the user manager');
  assert.match(seeder, /SetAuthenticationTokenAsync\(user, StoreProvider, "AuthenticatorKey"/, 'two-factor sign-in with a known key');
});

test('each agent is a definition the AI Agents folder can list: named after its file, described, on the fable model', () => {
  for (const f of manifest.ai.agents) {
    const src = read(f);
    const head = src.split('\n---\n')[0];
    assert.match(head, /^---\n/, `${f} opens with frontmatter`);
    assert.match(head, new RegExp(`^name: ${path.basename(f, '.md')}$`, 'm'));
    assert.match(head, /^description: .{80,}$/m, `${f} says when to use it`);
    assert.match(head, /^model: fable$/m);
    assert.match(head, /^tools:\n(  - \S+\n?)+/m);
    assert.match(src, /cmd-tools-testing\.sh|cmd-aspnet-core-project\.sh/, `${f} names the plugin's commands`);
  }
  const tester = read('ai/agents/aspnet-core-tester.md');
  assert.match(tester, /Never create or delete an account in a suite/);
  assert.match(tester, /No platform name in a step phrase/);
  assert.match(tester, /Playwright MCP browser first/);
});

test('register() adds the assistant context and nothing else', () => {
  const calls: string[] = [];
  const api: any = { name: 'aspnet-core', addAssistantContext: (fn: () => string) => calls.push(fn()) };
  register(api);
  assert.strictEqual(calls.length, 1);
  assert.strictEqual(calls[0], assistantContext());
  for (const c of COMMANDS) assert.ok(calls[0].includes(c), `the assistant is told about ${c}`);
  for (const a of AGENTS) assert.ok(calls[0].includes(a), `the assistant is told about ${a}`);
});

test('the docs say container-based, name only what ships, and carry no personal value', () => {
  const docs = ['README.md', ...manifest.ai.agents, 'scripts/functions/fun-aspnet-core.sh'];
  for (const f of docs) {
    const src = read(f);
    assert.doesNotMatch(src, /DDEV-only/i, `${f}: the workspace is container-based, DDEV by default`);
    assert.doesNotMatch(src, /\/home\/(?!YOUR_USER)[a-z]/, `${f} carries no personal path`);
    const mails = src.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[a-z]{2,}/g) || [];
    for (const m of mails) assert.match(m, /@example\.(com|org)$/, `${f}: ${m} is not an example address`);
  }
  for (const c of COMMANDS) assert.ok(read('README.md').includes(c), `the README lists ${c}`);
});
