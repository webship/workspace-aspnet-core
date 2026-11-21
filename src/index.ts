/**
 * ASP.NET Core for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the dotnet CLI tool in the
 * sites folders, their functions and argparse under core/scripts/plugins/aspnet-core/ (with the files the builder adds
 * to an app: the script that puts them in and the files themselves, bundled), and its AI items (ai/ in this package)
 * in the folder of their kind: the agents in AI Agents, the skill in AI Skills, the command in AI Commands, the
 * prompts in AI Prompts. The dashboard needs nothing drawn for it: the builder is in the Build list because it is a
 * cmd-*-project.sh, the row menus are the core's, the AI items are listed like any other. What register() adds is
 * what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the dashboard's own
 * files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/**
 * The plugin's name. An ASP.NET Core app is a generic DDEV project: the plugin claims it with
 * .ddev/config.aspnet-core.yaml, and the core's tools call its functions under aspnet_core.
 */
export const PLATFORM = 'aspnet-core';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-aspnet-core-project.sh', 'cmd-tools-aspnet-core-cli.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['aspnet-core-site-builder', 'aspnet-core-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['aspnet-core-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['aspnet-core-test'];

/** The prompts the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['aspnet-core-build-and-test', 'aspnet-core-scenarios-for-an-area'];

/** What the assistant is told about ASP.NET Core in this workspace. */
export function assistantContext(): string {
  return [
    'ASP.NET Core (a plugin, @webship.co/workspace-aspnet-core): an app is built with',
    '`bash cmd-aspnet-core-project.sh <name> --install --add-users` from a sites folder (dev, test, sandboxes, demos):',
    'an app made with `dotnet new` from an official template with individual accounts (the Razor Pages app by default, the Blazor Web App with `--template blazor`),',
    'at the current .NET release (`--dotnet-version 11.0`; 10.0 is the long-term-support line), with the .NET SDK of the official image in the web image,',
    'published and run in production by the web container of a generic DDEV project at https://<name>.ddev.site, its mail caught at https://<name>.ddev.site:8026;',
    '`--install` adds the Administrator role and its page, a mail sender pointed at the mail catcher, the app\'s seeding step for the accounts, the status code page and (Razor Pages) the movies pages of the official tutorial;',
    '`--add-users` adds the default accounts (administrator, user, twofactoruser with two-factor sign-in, lockeduser locked out, unconfirmeduser), each @example.com.',
    'A build takes a few minutes the first time (the SDK image, NuGet downloads into the project\'s .nuget/).',
    '`bash cmd-tools-aspnet-core-cli.sh <name>` says what the app is and lists its accounts; `--dotnet "<command>"` runs dotnet in the container, `--rebuild` publishes again and restarts,',
    '`--restart` restarts it, `--logs` shows its log, `--environment Development|Production` switches the environment, `--add-users` and `--cancel-users` manage the default accounts.',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the ASP.NET Core step pack; `--run` runs the suite.',
    `For ASP.NET Core work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <site>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run dotnet on the host for a project; removing the project removes its NuGet downloads too.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
