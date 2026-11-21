Feature: The app answers, its login works and its accounts log in
  As the owner of the app
  I want the login, each default account and the two-factor sign-in to work
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-aspnet-core-cli.sh --add-users); a scenario logs in by a handle of the
  # users registry in cucumber.js, so no password is written here. It passes on an app built with --install
  # --add-users, the Razor Pages app or the Blazor Web App.

  @critical
  Scenario: A visitor who opens a page that needs a session is sent to the login page, and back after the login
    Given I am not logged in
    When I go to "/Movies"
    Then I should be on the login page
    And I should see the login form
    When I log in as "user" with the login form
    Then I should be back on the page I asked for
    And I should be logged in as "user"

  Scenario Outline: The <account> account logs in through the login form
    Given I am not logged in
    When I go to the login page
    And I log in as "<account>" with the login form
    Then I should be logged in as "<account>"

    Examples:
      | account       |
      | administrator |
      | user          |

  Scenario: A wrong password is refused
    Given I am on the login page
    When I log in with the email "user@example.com" and the password "Wrong-password-1"
    Then the login should be refused with "Invalid login attempt."
    And I should not be logged in

  Scenario: The two-factor account is asked for the code of its authenticator app
    Given I am not logged in
    And I am on the login page
    When I submit the login form as "twofactoruser"
    Then I should be asked for the authenticator code
    When I enter the authenticator code of "twofactoruser"
    Then I should be logged in as "twofactoruser"

  Scenario: A locked-out account is sent to the lockout page
    Given I am on the login page
    When I submit the login form as "lockeduser"
    Then I should see the lockout page
