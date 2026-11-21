---
description: Test an ASP.NET Core app of the Webship Workspace with webship-js and the ASP.NET Core step pack — set the testing stack up when it is missing, match every step, run the suite (or one feature, or one tag) in the app's container, and report what failed and why.
argument-hint: '<app> [tests/features/<name>.feature | @tag]'
---

# /aspnet-core-test

Test the ASP.NET Core app named in: `$ARGUMENTS`

`$ARGUMENTS` stands for what was typed after the command. An AI CLI that does not fill it in
reads the same from the request: the name of the app, then, if anything, one feature path or one
tag.

The first word is the app (its folder name in a sites folder of the workspace). What follows, if
anything, narrows the run: a path that starts with `tests/features/` is one feature (or one folder
of features), a word that starts with `@` is a tag expression. With nothing after the app, the whole
suite runs. With no app at all, stop and ask for one: list the candidates with
`ls -d ~/workspace/*/*/.ddev/config.aspnet-core.yaml`.

The workspace is container-based (DDEV by default) and everything below runs in the project's
containers through the workspace's own command. Never run `npx cucumber-js`, `npx playwright`, `node`
or `dotnet` on the host for an app.

## 1. Find the app

```bash
ls -d ~/workspace/*/<app>/.ddev/config.aspnet-core.yaml
```

Work from that sites folder (`cd ~/workspace/<folder>`). An app built without `--install` is the template as it
is, with no default accounts to test with: say so, and name `bash cmd-aspnet-core-project.sh <app> --install
--add-users` (add `--template blazor` for the Blazor Web App; it rebuilds the app from nothing).

## 2. Set the testing stack up, when it is missing

```bash
bash cmd-tools-testing.sh <app>
```

It adds webship-js, the ASP.NET Core step pack, where the app's account pages are, the mail catcher, the users
registry (`administrator`, `user`, `twofactoruser`, `lockeduser`, `unconfirmeduser`) and
`tests/features/site.feature`. A project that has `cucumber.js` already keeps it; the setup adds only what is
missing.

## 3. Match every step

```bash
bash cmd-tools-testing.sh <app> --dry-run
```

Every step must match exactly one definition. An undefined step is a phrase that does not exist: find
the real one in the pack's README or in the `aspnet-core-scenarios` skill, never invent a step.

## 4. Run

```bash
bash cmd-tools-testing.sh <app> --run                                     # the whole suite
bash cmd-tools-testing.sh <app> --run --path tests/features/site.feature  # one feature
bash cmd-tools-testing.sh <app> --run --tags @critical                    # one tag
```

## 5. Report

The scenarios and steps that passed and failed, then for each failure: the step, its message and
hint, the screenshot the run kept, and what it means (a defect of the app, a scenario to fix, or a page
the app answered with an error the browser logged, which `@js-off` keeps out of the run). A suite never
creates an account, never writes a password into a feature file, and never writes a platform name into a
step phrase. For writing or fixing scenarios, use the `aspnet-core-scenarios` skill or hand over to the
`aspnet-core-tester` agent; for changing the app, to `aspnet-core-site-builder`.

Before you write or change a scenario, or read a failed run, read the book *Automated Functional
Testing Recipes* (its `README.md`, then the matching chapter):
`.claude/automated-functional-testing-recipes/` in the project,
`~/.claude/automated-functional-testing-recipes/`, or
https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
