#!/usr/bin/env python3
"""Prepare an app made with `dotnet new webapp --auth Individual` or `dotnet new blazor --auth Individual` as the
test site of the step pack: what an app adds to the template once it goes to work.

  python3 prepare-app.py <app folder> --template webapp|blazor

Both templates get:
  - the Administrator role (`.AddRoles<IdentityRole>()`) and a page only that role may open (/Admin);
  - an email sender over SMTP, pointed at the project's mail catcher (the confirmation mail, the password reset,
    the confirmation of a new email address), in place of the template's sender that sends nothing;
  - the keys that protect the cookies and the tokens of the mail kept in the project (a restart keeps the sessions);
  - a seeding step of the app's own, run by the build with the app itself (`--seed-accounts <file>`, the password
    on standard input): the accounts through the app's user manager;
  - one fixture page, /Throw, which throws, for the app's error page.
The Razor Pages app also gets the status code page of the app (`UseStatusCodePagesWithReExecute`), and the movies
pages of the official Razor Pages tutorial behind the login (the CRUD pages in the markup the official scaffolder
writes, with the tutorial's search and sample movies). The Blazor app keeps its own status code page (/not-found).

Every change is anchored on a line of the template; a template whose line moved stops the script with the line it
looked for. Running it twice changes nothing the second time.
"""
import argparse
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MARK = 'Added by the build of the test site'


def fail(message):
    sys.exit('prepare-app.py: ' + message)


def read(path):
    with open(path, encoding='utf-8-sig') as handle:
        return handle.read()


def write(path, text):
    with open(path, 'w', encoding='utf-8') as handle:
        handle.write(text)


def insert_after(text, anchor, addition, where):
    index = text.find(anchor)
    if index < 0:
        fail(f'{where}: the line "{anchor.strip()}" is not there; the template changed.')
    end = index + len(anchor)
    return text[:end] + addition + text[end:]


def insert_before(text, anchor, addition, where):
    index = text.find(anchor)
    if index < 0:
        fail(f'{where}: the line "{anchor.strip()}" is not there; the template changed.')
    return text[:index] + addition + text[index:]


# The files the build adds: the tree app/<common|webapp|blazor>/ beside this script (the step pack), or, where an
# installer places its files side by side in one folder (the Webship Workspace plugin), the same files bundled in
# aspnet-core-app-files.json beside it: {"common/Data/AccountSeeder.cs": "<text>", ...}.
BUNDLE = os.path.join(HERE, 'aspnet-core-app-files.json')


def files_of(kind):
    tree = os.path.join(HERE, 'app', kind)
    if os.path.isdir(tree):
        for root, _dirs, files in os.walk(tree):
            for name in sorted(files):
                path = os.path.join(root, name)
                yield os.path.relpath(path, tree), read(path)
        return
    if not os.path.isfile(BUNDLE):
        fail(f'neither app/{kind}/ nor aspnet-core-app-files.json is beside this script.')
    with open(BUNDLE, encoding='utf-8') as handle:
        bundle = json.load(handle)
    for key in sorted(bundle):
        if key.startswith(kind + '/'):
            yield key[len(kind) + 1:], bundle[key]


def copy_files(kind, app, namespace):
    for rel, text in files_of(kind):
        dest = os.path.join(app, rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        write(dest, text.replace('__APP__', namespace))
        print('  ' + rel)


def seeding(user_type, extra=''):
    return (
        '\n\n// ' + MARK + ': the accounts, through the app\'s own user manager (the password on standard input):\n'
        '//   dotnet <app>.dll --seed-accounts <accounts.json>   |   dotnet <app>.dll --cancel-accounts <accounts.json>\n'
        'if (args.Contains("--seed-accounts") || args.Contains("--cancel-accounts"))\n'
        '{\n'
        f'    Environment.ExitCode = await AccountSeeder.RunAsync<{user_type}>(app.Services, args);\n'
        + extra +
        '    return;\n'
        '}'
    )


SERVICES = (
    '// ' + MARK + ': the mail goes over SMTP to the project\'s mail catcher, and the keys that protect the cookies\n'
    '// and the tokens of the mail are kept in the project, so a restart of the app keeps the sessions.\n'
    'builder.Services.AddTransient<IEmailSender, SmtpEmailSender>();\n'
)
KEYS = 'builder.Services.AddDataProtection().PersistKeysToFileSystem(new DirectoryInfo(builder.Configuration["DataProtection:KeysFolder"] ?? "keys"));\n'
USINGS = 'using Microsoft.AspNetCore.DataProtection;\nusing Microsoft.AspNetCore.Identity.UI.Services;\n'


def prepare_webapp(app, namespace):
    program = os.path.join(app, 'Program.cs')
    text = read(program)
    text = USINGS + f'using {namespace}.Services;\n' + text
    text = insert_before(text, '    .AddEntityFrameworkStores<ApplicationDbContext>();', '    .AddRoles<IdentityRole>()\n', 'Program.cs')
    text = insert_after(text, 'builder.Services.AddRazorPages();\n', SERVICES + KEYS, 'Program.cs')
    extra = '    if (Environment.ExitCode == 0 && args.Contains("--seed-accounts")) await MovieSeeder.RunAsync(app.Services);\n'
    text = insert_after(text, 'var app = builder.Build();', seeding('IdentityUser', extra), 'Program.cs')
    text = insert_before(text, 'app.UseHttpsRedirection();', (
        '// ' + MARK + ': the status code page of the app, for an answer without a body of its own (a 404, a 400).\n'
        'app.UseStatusCodePagesWithReExecute("/StatusCode", "?code={0}");\n\n'), 'Program.cs')
    write(program, text)
    print('  Program.cs: the Administrator role, the mail sender, the keys, the seeding step, the status code page')

    context = os.path.join(app, 'Data', 'ApplicationDbContext.cs')
    text = read(context)
    match = re.search(r'class ApplicationDbContext[^\n]*\n\{\n', text)
    if not match:
        fail('Data/ApplicationDbContext.cs: the class ApplicationDbContext is not there; the template changed.')
    text = text[:match.end()] + f'    // {MARK}: the movies of the official Razor Pages tutorial.\n    public DbSet<{namespace}.Models.Movie> Movie {{ get; set; }} = default!;\n' + text[match.end():]
    write(context, text)
    print('  Data/ApplicationDbContext.cs: the movies')

    layout = os.path.join(app, 'Pages', 'Shared', '_Layout.cshtml')
    text = read(layout)
    privacy = re.search(r'( *)<li class="nav-item">\s*<a class="nav-link text-dark" asp-area="" asp-page="/Privacy">Privacy</a>\s*</li>\n', text)
    if not privacy:
        fail('Pages/Shared/_Layout.cshtml: the Privacy item of the navigation bar is not there; the template changed.')
    pad = privacy.group(1)
    items = (
        f'{pad}@* {MARK}: the movies, and the administration for the Administrator role. *@\n'
        f'{pad}<li class="nav-item">\n{pad}    <a class="nav-link text-dark" asp-area="" asp-page="/Movies/Index">Movies</a>\n{pad}</li>\n'
        f'{pad}@if (User.IsInRole("Administrator"))\n{pad}{{\n'
        f'{pad}    <li class="nav-item">\n{pad}        <a class="nav-link text-dark" asp-area="" asp-page="/Admin/Index">Administration</a>\n{pad}    </li>\n'
        f'{pad}}}\n'
    )
    text = text[:privacy.end()] + items + text[privacy.end():]
    write(layout, text)
    print('  Pages/Shared/_Layout.cshtml: the Movies and Administration items of the navigation bar')


def prepare_blazor(app, namespace):
    program = os.path.join(app, 'Program.cs')
    text = read(program)
    text = USINGS + f'using {namespace}.Services;\n' + text
    text = insert_before(text, '    .AddEntityFrameworkStores<ApplicationDbContext>()', '    .AddRoles<IdentityRole>()\n', 'Program.cs')
    old = 'builder.Services.AddSingleton<IEmailSender<ApplicationUser>, IdentityNoOpEmailSender>();\n'
    if old not in text:
        fail(f'Program.cs: the line "{old.strip()}" is not there; the template changed.')
    text = text.replace(old, SERVICES + 'builder.Services.AddTransient<IEmailSender<ApplicationUser>, IdentitySmtpEmailSender>();\n' + KEYS)
    text = insert_after(text, 'var app = builder.Build();', seeding('ApplicationUser'), 'Program.cs')
    write(program, text)
    print('  Program.cs: the Administrator role, the mail sender, the keys, the seeding step')

    menu = os.path.join(app, 'Components', 'Layout', 'NavMenu.razor')
    text = read(menu)
    auth = re.search(r'( *)<div class="nav-item px-3">\s*<NavLink class="nav-link" href="auth">.*?</NavLink>\s*</div>\n', text, re.S)
    if not auth:
        fail('Components/Layout/NavMenu.razor: the "Auth Required" item is not there; the template changed.')
    pad = auth.group(1)
    item = (
        f'\n{pad}@* {MARK}: the administration, for the Administrator role. *@\n'
        f'{pad}<AuthorizeView Roles="Administrator">\n'
        f'{pad}    <div class="nav-item px-3">\n'
        f'{pad}        <NavLink class="nav-link" href="Admin">\n'
        f'{pad}            <span class="bi bi-lock-nav-menu" aria-hidden="true"></span> Administration\n'
        f'{pad}        </NavLink>\n'
        f'{pad}    </div>\n'
        f'{pad}</AuthorizeView>\n'
    )
    text = text[:auth.end()] + item + text[auth.end():]
    write(menu, text)
    print('  Components/Layout/NavMenu.razor: the Administration item')


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('app', help='the folder of the app (where its .csproj is)')
    parser.add_argument('--template', choices=['webapp', 'blazor'], required=True)
    args = parser.parse_args()

    app = os.path.abspath(args.app)
    projects = [f for f in os.listdir(app) if f.endswith('.csproj')] if os.path.isdir(app) else []
    if len(projects) != 1:
        fail(f'{app} holds no single .csproj: make the app with dotnet new first.')
    namespace = projects[0][:-len('.csproj')]
    if MARK in read(os.path.join(app, 'Program.cs')):
        print(f'{app} is prepared already.')
        return

    print(f'Preparing the {args.template} app {namespace} as the test site:')
    copy_files('common', app, namespace)
    copy_files(args.template, app, namespace)
    if args.template == 'webapp':
        prepare_webapp(app, namespace)
    else:
        prepare_blazor(app, namespace)


if __name__ == '__main__':
    main()
