Feature: Logging in and out
  As a person with an account of the app
  I want the login page to let me in and refuse a wrong password
  So that my account is mine alone

  Scenario: A visitor is sent to the login page, and back to the page after the login
    Given I am not logged in
    When I go to "/Movies"
    Then I should be on the login page
    When I log in as "user" with the login form
    Then I should be back on the page I asked for
    And I should be logged in as "user"

  Scenario: A wrong password is refused, and so is an account whose email is not confirmed
    Given I am on the login page
    When I log in with the email "user@example.com" and the password "Wrong-password-1"
    Then the login should be refused with "Invalid login attempt."
    When I submit the login form as "unconfirmeduser"
    Then the login should be refused with "Invalid login attempt."
    And I should not be logged in

  Scenario: A locked-out account is sent to the lockout page
    Given I am on the login page
    When I submit the login form as "lockeduser"
    Then I should see the lockout page

  Scenario: The logout button of the navigation ends the session
    Given I am not logged in
    And I am on the login page
    When I log in as "user" with the login form
    And I log out
    Then I should not be logged in
