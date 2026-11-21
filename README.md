# @webship.co/workspace-aspnet-core

ASP.NET Core for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a builder that makes a
real ASP.NET Core app in containers (an app made with `dotnet new` from an official template with individual
accounts — the Razor Pages app with the default account pages, or the Blazor Web App — at the current .NET release,
published and run in production with the .NET SDK of its official image), with what an app adds once it goes to work
(the Administrator role and a page only it opens, a mail sender pointed at the project's mail catcher, a seeding step
of its own for the accounts), a tool that runs `dotnet` for the app, the default accounts, the
[ASP.NET Core step pack](https://github.com/webship/aspnet-core-steps) wired into the workspace's testing setup, and
its AI items — two agents, a skill, a command and two prompts — each listed in the workspace folder of its kind.

The workspace is container-based (DDEV by default): an ASP.NET Core app is a row like any other, so the row menus
the core draws (start, stop, launch, clone, remove, tests) work on it unchanged. The plugin claims its apps with a
file of its own (`.ddev/config.aspnet-core.yaml`), so the Tests menu of the row offers the plugin's test users
(Workspace core 1.0.27 and later; see [The default accounts](#the-default-accounts)).

It is made from the reference platform plugin, `@webship.co/workspace-wordpress`, and runs its app the way the
Spring Boot plugin runs its own: a generic project whose web container runs the app as a daemon, with the router of
the container tool sending the project's address to the app's port.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require @webship.co/workspace-aspnet-core --with-needs   # npm install into the dashboard
bash core/scripts/plugins.sh --activate aspnet-core --with-needs                        # plugins.aspnet-core in settings.yml
bash core/scripts/plugins.sh --install aspnet-core                                      # commands, functions, args, AI items
bash core/scripts/plugins.sh --configure aspnet-core                                    # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is idempotent.
`--uninstall` removes what it placed; an AI item you edited stays. `--remove aspnet-core` then takes the package out
of the dashboard.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-aspnet-core-project.sh`, `cmd-tools-aspnet-core-cli.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The agents `aspnet-core-site-builder`, `aspnet-core-tester` | `ai-agents/` |
| The skill `aspnet-core-scenarios` | `ai-skills/` |
| The command `/aspnet-core-test` | `ai-commands/` |
| The prompts `aspnet-core-build-and-test`, `aspnet-core-scenarios-for-an-area` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompts are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate aspnet-core --with-needs   # dev and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install aspnet-core
```

Everything the builder runs for an app runs in containers, through the container tool the workspace already
needs, and Python 3, which prepares the app's files on the machine: the .NET SDK and the app are the containers'.
The plugin asks for no command of its own on the machine.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-aspnet-core-project.sh` | The builder, in the Build list as **ASP.NET Core (the Razor Pages app or the Blazor Web App, with individual accounts)**, installed into every sites folder |
| `commands/cmd-tools-aspnet-core-cli.sh` | `dotnet` and the run of an app: what the app is, a dotnet command, a new publish, a restart, its log, its environment, the default accounts |
| `scripts/functions/fun-aspnet-core.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_aspnet_core_users`, `add_aspnet_core_users`, `cancel_aspnet_core_users`, `testing_configure_aspnet_core`) |
| `scripts/args/arg-aspnet-core.sh`, `arg-aspnet-core-cli.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `scripts/app/aspnet-core-prepare-app.py` | Prepares the app `dotnet new` made (the step pack's own script): the Administrator role, the mail sender, the keys of its cookies kept in the project, its seeding step, the status code page, and in the Razor Pages app the movies pages of the official tutorial |
| `scripts/app/aspnet-core-app-files.json` | The files it adds, bundled (the step pack keeps them as a folder, `site/app/`): one file here, as the installer places machine files side by side |
| `testing/site.feature` | The first feature an app gets when testing is set up |
| `ai/agents/aspnet-core-site-builder.md` | The agent that builds and maintains apps with these commands |
| `ai/agents/aspnet-core-tester.md` | The agent that writes and runs scenarios with the ASP.NET Core step pack |
| `ai/skills/aspnet-core-scenarios/` | The skill: the step pack's phrases by area, the traps found on real apps, three example features |
| `ai/commands/aspnet-core-test.md` | The slash command `/aspnet-core-test <app>`: set up, match every step, run, report |
| `ai/prompts/aspnet-core-build-and-test.md`, `aspnet-core-scenarios-for-an-area.md` | Two prompts: whole launch commands for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about ASP.NET Core here |
| `features/aspnet-core.feature` | Scenarios for the dashboard's own browser suite |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## What is different from a PHP platform

An ASP.NET Core app is a .NET app with its own server and its own database, and DDEV has no project type for it. The
plugin keeps the shape of the reference and changes only this:

| | WordPress (the reference) | ASP.NET Core |
| --- | --- | --- |
| Project | `--project-type=wordpress`, nginx and PHP | `--project-type=generic --webserver-type=generic --docroot=app --omit-containers=db`: the web container runs the published app as a daemon and the router sends ports 80 and 443 of the project's address to its port (5000); no database of the container tool's own |
| Recognised by | The DDEV project type | The file `.ddev/config.aspnet-core.yaml`: the daemon of the app, its port, its environment, its settings, and the plugin's claim on the project |
| The runtime | PHP of the web image | The .NET SDK at `--dotnet-version` (11.0 by default, 10.0 for the long-term-support line), copied from its official image into the web image (`.ddev/web-build/Dockerfile.aspnet-core`) |
| Getting the code | `wp core download` | `dotnet new webapp --auth Individual` (Razor Pages) or `dotnet new blazor --auth Individual` (`--template blazor`) in the web container; NuGet keeps its downloads in the project (`.nuget/`) |
| Install | `wp core install` | `--install`: what the app adds to go to work (see [Build an app](#build-an-app)), the migration of its movies made with the EF Core tools of its release, its database migrated by its own seeding step |
| Database | The container tool's | SQLite, as the templates have it, in `data/` of the project, with the keys that protect the app's cookies |
| Running it | PHP-FPM | `dotnet publish -c Release`, then the published app in Production, behind the router's HTTPS (`ASPNETCORE_FORWARDEDHEADERS_ENABLED`) |
| Mail | The container tool's mail catcher | The same: the app's mail sender sends over SMTP to it (`https://<name>.ddev.site:8026`) |
| Accounts | WP-CLI | The app's own seeding step, through its user manager, the password on its standard input |
| Removing it | `ddev delete` | The same, and the project's folder takes the NuGet downloads with it |
| Tests menu of the row | Reads the project type | The plugin's claim: core 1.0.27 and later offer the plugin's test users (`aspnet_core`) |

No public domain, no hosted service and no account anywhere: the app answers at `https://<name>.ddev.site` through
the container tool's router.

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build an app

```bash
cd ~/workspace/dev
bash cmd-aspnet-core-project.sh myapp --install --add-users                        # the Razor Pages app
bash cmd-aspnet-core-project.sh myblazor --template blazor --install --add-users   # the Blazor Web App
bash cmd-aspnet-core-project.sh mylts --dotnet-version 10.0 --install --add-users  # on the long-term-support line
```

| Flag | What it does |
| --- | --- |
| `--template <webapp\|blazor>` | The official template, with individual accounts: the Razor Pages app with the default account pages (`webapp`, the default) or the Blazor Web App, whose account pages are components of its own (`blazor`) |
| `--install` | What an app adds once it goes to work: the Administrator role and a page only it opens (`/Admin`), a mail sender pointed at the project's mail catcher, the keys of its cookies kept in the project, a seeding step of its own for the accounts, a page that throws (`/Throw`, for the error page), and in the Razor Pages app the status code page and the movies pages of the official Razor Pages tutorial behind the login. Without it the template is built as it is: its own database, no mail sender, no account |
| `--add-users` | With `--install`: add the default accounts |
| `--dotnet-version <x.y>` | The .NET release line of the app and of the SDK image: `11.0` (the current one) by default, `10.0` (long-term support) |
| `--launch` | Open the app when it is ready |

The app answers at `https://myapp.ddev.site`, its login at `/Identity/Account/Login` (`/Account/Login` in the Blazor
Web App) and its mail catcher at `https://myapp.ddev.site:8026`. A project of the same name is deleted first. The .NET
namespace of the app is the project name in Pascal case (`myapp`: `Myapp`, `my-app`: `MyApp`).

A build takes about five minutes the first time (the SDK's image is about 900 MB, and NuGet downloads the app's
packages into the project, about 250 MB) and two or three after that; the app then uses about 200 MB of memory.
Check the free memory and disk first (`free -g`, `df -h /`), and build one app at a time on a machine others use.

### Work on an app

```bash
bash cmd-tools-aspnet-core-cli.sh myapp                            # template, versions, addresses, environment, accounts
bash cmd-tools-aspnet-core-cli.sh myapp --dotnet "list package"    # a dotnet command in the app folder of the web container
bash cmd-tools-aspnet-core-cli.sh myapp --dotnet="--info"          # options alone: joined to the flag with =
bash cmd-tools-aspnet-core-cli.sh myapp --rebuild                  # publish again after a change to the code, and restart
bash cmd-tools-aspnet-core-cli.sh myapp --restart                  # restart the app and wait for it
bash cmd-tools-aspnet-core-cli.sh myapp --logs                     # the end of the web container's log
bash cmd-tools-aspnet-core-cli.sh myapp --environment Development  # run it in development; --environment Production again for a live app
bash cmd-tools-aspnet-core-cli.sh myapp --add-users                # the default accounts
bash cmd-tools-aspnet-core-cli.sh myapp --cancel-users             # delete them again
```

`dotnet` runs in the web container with the project's NuGet downloads. A value of `--dotnet` that starts with a
dash (options alone, as `--info`) is joined to the flag with `=`, or the tool takes it for an option of its own. The
app's code is in `app/` of the project: change it, then `--rebuild`.

### The default accounts

| Account | Address | State | Handle in the tests |
| --- | --- | --- | --- |
| `administrator` | `administrator@example.com` | the Administrator role | `administrator` |
| `user` | `user@example.com` | no role | `user` |
| `twofactoruser` | `twofactoruser@example.com` | two-factor sign-in with an authenticator app, its key known to the tests | `twofactoruser` |
| `lockeduser` | `lockeduser@example.com` | locked out | `lockeduser` |
| `unconfirmeduser` | `unconfirmeduser@example.com` | its email address not confirmed yet | `unconfirmeduser` |

Each account has the password of the workspace's other default lists and signs in with its email address. They are
made by the app's own seeding step (`dotnet <app>.dll --seed-accounts config/accounts.json`, the password on its
standard input: never on a command line or in a file), which applies the migrations first and puts an account that
is there already back in its state (its password, its role, its two-factor key, no phone number, no recovery codes,
no failed logins). An account of your own stays when the default accounts are added or cancelled again. They are
for local apps and for tests.

The row's Tests menu offers **Add the test users** and **Cancel the test users** for an app this plugin claims
(Workspace core 1.0.27 and later): they run the same list as

```bash
bash cmd-tools-add-users.sh myapp aspnet_core       # the core's tool, with the plugin's list
bash cmd-tools-cancel-users.sh myapp aspnet_core
```

An app built without `--install` has no seeding step, and so no place for the default accounts: the tools say so and
change nothing. On a core older than 1.0.27 the Tests menu hands every project that is not of a known type the
Webship distribution's list (which starts by adding Drush with Composer): leave those two items alone there and use
the CLI tool.

### Test an app

```bash
bash cmd-tools-testing.sh myapp                  # webship-js, the step pack, the users registry, a first feature
bash cmd-tools-testing.sh myapp --run            # run the suite in the container
bash cmd-tools-testing.sh myapp --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For an ASP.NET Core app it also adds `@webship-js/aspnet-core-steps`
to `package.json`, lists its step definitions in `cucumber.js` after webship-js's own, writes where the app's account
pages are (`/Identity/Account`, or `/Account` for the Blazor Web App), a page only a signed-in account may open
(`/Movies`, or `/auth`), the mail catcher, the users registry (the handles above, by their email addresses, with the
authenticator key of `twofactoruser`, overridable with `ASPNET_CORE_<HANDLE>_EMAIL` and `ASPNET_CORE_<HANDLE>_PASSWORD`),
the browser messages the step pack's scenarios turn off, the tags that keep the pack's assertions that must fail out
of a normal run, and the app's address in place of the starter's `http://localhost:8080`. It places
`tests/features/site.feature` when the project has none, and makes sure the default accounts are in an app with its
seeding step once it answers again (installing the webship-js add-on restarts the project, and the app with it). Run
it again and it adds what is missing and keeps what you changed.

Until `@webship-js/aspnet-core-steps` is on npm, give the testing setup its tarball (`npm pack` of the pack) with
`bash cmd-tools-testing.sh myapp --add-steps <path to the tarball>`, then run the setup again.

A scenario of your own reads like this one, from the step pack's phrases (the skill `aspnet-core-scenarios` lists
them by area):

```gherkin
Feature: Two-factor sign-in
  Scenario: The app asks for the code after the password, and refuses a wrong one
    Given I am not logged in
    And I am on the login page
    When I submit the login form as "twofactoruser"
    Then I should be asked for the authenticator code
    When I enter the authenticator code "000000"
    Then the authenticator code should be refused with "Invalid authenticator code."
    When I enter the authenticator code of "twofactoruser"
    Then I should be logged in as "twofactoruser"
```

`tests/features/site.feature` passes on an app built with `--install --add-users`, the Razor Pages app or the Blazor
Web App, and the features of the step pack pass on the Razor Pages app built the same way (its `tests/blazor/` ones
on the Blazor Web App).

## The AI items

`ai/` in the package holds one folder per kind, the manifest's `ai` block names each item, and `--install` places
it in the workspace folder of that kind.

| Kind | Item | Use it to |
| --- | --- | --- |
| Agent | `aspnet-core-site-builder` | Build, maintain or remove an app with the commands above, in containers only |
| Agent | `aspnet-core-tester` | Set the testing stack up, look at the pages in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |
| Skill | `aspnet-core-scenarios` | Write a scenario from phrases that exist: the pack's steps by area, the handles of the users registry, the traps found on real apps, and three features that pass on the Razor Pages app with the default accounts |
| Command | `/aspnet-core-test <app> [feature or @tag]` | Run the suite of an app from inside a session: set up when missing, match every step, run, report what failed and why |
| Prompt | `aspnet-core-build-and-test` | Start a session that builds an app, says what it is, sets the testing stack up and runs the first feature |
| Prompt | `aspnet-core-scenarios-for-an-area` | Start a session that writes and runs the scenarios of one area of an app |

After `--install` each is in its folder on the dashboard. **Install** there puts an agent, a skill or a command
into Claude Code (`~/.claude/agents`, `~/.claude/skills`, `~/.claude/commands`), or from the command line:

```bash
cd ~/workspace/ai-agents   && bash cmd-tools-ai-items.sh aspnet-core-tester --install
cd ~/workspace/ai-skills   && bash cmd-tools-ai-items.sh aspnet-core-scenarios --install
cd ~/workspace/ai-commands && bash cmd-tools-ai-items.sh aspnet-core-test --install
```

A prompt is not installed: it is the whole `claude …` launch command of a new session, and the dashboard's
**New screen** form lists it as a template. By hand, fill the placeholders in and run the command of the file from
the folder it names.

The items are written for any AI CLI, with Claude Code as the default shape: the frontmatter and the file layout
are Claude Code's, the body of each item is plain Markdown that names no tool or feature of one CLI, a command says
in words what its arguments are, and the text between the triple quotes of a prompt can be given to another AI CLI
as it is.

Every step phrase the items show is checked against the definitions of the step pack and of webship-js
(`tests/fixtures/step-definitions.txt`), and every command and flag against the plugin's own.

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the AI items, the functions against a scaffolded project
```

CI runs the same on Node.js 20 and 24, parses every shell script, and runs the plugin's
`features/aspnet-core.feature` against a dashboard with this plugin installed
(`webship/workspace/.github/workflows/plugin-browser-suite.yml`).
