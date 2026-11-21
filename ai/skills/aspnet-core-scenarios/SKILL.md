---
name: aspnet-core-scenarios
description: Write webship-js scenarios for an ASP.NET Core app of the Webship Workspace from phrases that exist — the ASP.NET Core step pack's steps by area (the login and its refusals, the lockout, two-factor sign-in with a code worked out from the authenticator key, the password reset and the confirmation mail through the mail catcher, registration refusals, the Manage pages, who may open what, the anti-forgery token, the error pages, the validation messages of forms), the handles of the users registry, the traps found on real apps, and three features that pass on the Razor Pages app built with the default accounts. Use when writing or fixing a scenario for an ASP.NET Core app, choosing a step for one of its account pages, or turning a manual check of the login, a mail or a form into a feature.
---

# aspnet-core-scenarios

Scenarios for an app built with the ASP.NET Core plugin (`bash cmd-aspnet-core-project.sh <app> --install
--add-users`, the Razor Pages app; `--template blazor` for the Blazor Web App) in a container-based workspace (DDEV
by default), tested with webship-js and `@webship-js/aspnet-core-steps` once `bash cmd-tools-testing.sh <app>` set the
project up. Every phrase below exists in the pack or in webship-js; a scenario names no platform.

## Accounts

- `Given I am a logged in user with the "user" user`: `administrator` (the Administrator role: opens `/Admin`),
  `user` (no role), `twofactoruser` (two-factor sign-in: the step types the code of its authenticator app),
  `lockeduser` (locked out) and `unconfirmeduser` (its email not confirmed). `Given I am not logged in` for a visitor.
- The accounts are made by the app's seeding step (`cmd-tools-aspnet-core-cli.sh <app> --add-users`); a suite never
  creates or deletes one, and never writes a password: it logs in by the handle.

## Phrases by area

| Area | Steps |
| --- | --- |
| Session | `I am on the login page`, `I go to the login page`, `I log in as "user" with the login form` (`… and "Remember me?" checked`), `I submit the login form as "lockeduser"` (stops where the app answers), `I log in with the email "…" and the password "…"`, `the login should be refused with "Invalid login attempt."`, `I should be on the login page`, `I should see the login form`, `I log out`, `I go to the logout page`, `I should be asked to confirm the logout`, `I confirm the logout`, `I should be logged in`, `I should not be logged in`, `I should be logged in as "user"`, `I should be back on the page I asked for`, `I close the browser and open it again`, `my session expires` |
| Cookies | `the session cookie should be HttpOnly` (`Secure`), `the session cookie should be SameSite Lax`, `the session cookie should last 14 days`, `the session cookie should end with the browser`, `the anti-forgery cookie should be HttpOnly` |
| Two-factor | `I should be asked for the authenticator code`, `I enter the authenticator code of "twofactoruser"` (`… with "Remember this machine" checked`), `I enter the authenticator code "000000"`, `the authenticator code should be refused with "Invalid authenticator code."`, `I set up two-factor authentication with an authenticator app`, `I verify the authenticator app with the code "123456"`, `I turn two-factor authentication off`, `two-factor authentication should be on` (`off`), `I should see 10 recovery codes`, `this browser should be remembered for two-factor sign-in` (`should not`) |
| Mail | `I ask for a password reset link for "user"`, `I reset the password of "user" on the reset page`, `I ask for a new confirmation email for "unconfirmeduser"`, `an email with the subject "Reset your password" should be sent to "user"`, `no email should be sent to "nobody@example.com"`, `the email with the subject "…" to "…" should contain "…"`, `I open the "clicking here" link of the email to "user"` |
| Account pages | `I try to register with:` with a table of fields, `I should see the lockout page`, `I should see the access denied page`, `I go to the "Password" page of my account`, `I should be on the "Password" page of my account`, `I should see the status message "Your profile has been updated"`, `I change my password to "…"`, `I change my password back`, `I change my email to "…"`, `I change my email back`, `I download my personal data`, `my personal data should show "Email" as "user@example.com"` |
| Access | `I should be allowed to open "/Movies"`, `I should not be allowed to open "/Admin"` (a visitor is sent to the login page, an account without the role to the access denied page) |
| Anti-forgery | `every form that posts on this page should carry an anti-forgery token`, `the form of the "Log in" button should carry an anti-forgery token`, `I press "Save" with a forged token`, `a page of another site sends a form to "/Movies/Edit/2" with:` (a table of fields), `the form of the other site should be refused` |
| Error pages | `I should see the 404 error page` (400, 500), `the page should not show debug information`, `the error page should show its request ID`, `I should see the developer exception page` (a development run) |
| Forms | `the "Email" field should have the error "The Email field is required."`, `the "Password" field should have no error`, `the form should show the errors:` with a table of fields and messages, `the form should show the error "…"`, `the form should show no errors`, `I press "Create" with the checks of the page turned off`, `the details should show "Genre" as "Comedy"` |

Text, links, buttons and fields are webship-js's own: `I should see "…"`, `I press "…"`, `I fill in "…" with "…"`,
`I go to "…"`, `I follow "…"`, `I click "Edit" in the "Ghostbusters" row`, `the downloaded file name should be "…"`.

## A scenario, start to end

A forgotten password is reset through the mail it gets, to the password the account has (so the account stays as
the suite knows it):

```gherkin
Feature: A forgotten password
  Scenario: A forgotten password is reset through the link in the mail
    Given I am not logged in
    When I ask for a password reset link for "user"
    Then an email with the subject "Reset your password" should be sent to "user"
    When I open the "clicking here" link of the email to "user"
    And I reset the password of "user" on the reset page
    Then I should see "Your password has been reset."
```

## Traps found on real apps

- The pages are rendered on the server: an action is a form post and a new page, and a refused form comes back with
  the status 200 and its messages next to the fields.
- The page checks a form in the browser before it sends it (an empty field is refused without a request); "I press
  "…" with the checks of the page turned off" sends it as it is, so the app's own checks answer.
- After a refused submit, the first click on the button can be lost (the error line under a field goes and the button
  moves): the pack's steps focus a button before they click it; webship-js's `I press "…"` after a refusal may need
  it too.
- The default account pages say "Invalid login attempt." for a wrong password, an unknown account and an
  unconfirmed one alike; a forgotten-password request is answered the same way for every address, and mails a
  confirmed account only.
- A set-up of an authenticator app shows the recovery codes only when the account has none left; "Reset recovery
  codes" and "Generate Recovery Codes" show ten new ones every time. After a set-up the two-factor page offers "Set
  up authenticator app" instead of "Add authenticator app": the key stays.
- The browser logs every error page it gets (a 404, a 400, a 500): tag those scenarios `@js-off`.
- The Blazor Web App on the current release protects its forms without a token (it checks where the request comes
  from): its forms carry none, so test it with "a page of another site sends a form", not with the token steps.
- In the Blazor Web App, a phone number once saved on the profile cannot be taken away (the empty field is refused):
  a scenario there saves none.

## Examples

- [`examples/session.feature`](examples/session.feature): the login, a refusal, the lockout, the page asked for, the logout.
- [`examples/two-factor-and-mail.feature`](examples/two-factor-and-mail.feature): two-factor sign-in, a forgotten password through the mail.
- [`examples/access-errors-and-forms.feature`](examples/access-errors-and-forms.feature): the role page, the error pages, a refused form.

Copy them into `tests/features/` of a project of the Razor Pages app and run them:

```bash
bash cmd-tools-testing.sh <app> --run --path tests/features/session.feature
```

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For ASP.NET Core.** Start with `ch10-authentication-authorization.md` (logins, two-factor codes, lockouts, roles
  and refusals), `ch07-waiting-dynamic-content.md` (waiting on the app's own signals), `ch06-form-testing-recipes.md`
  (forms and their validation) and `ch44-javascript-and-friendly-errors.md` (the browser messages of a page).
