Feature: Two-factor sign-in and a forgotten password
  As a person who protects an account
  I want the app to ask for my code, and to mail me a reset link that works
  So that a stolen password is not enough, and a lost one is not the end

  Scenario: The app asks for the code after the password, and refuses a wrong one
    Given I am not logged in
    And I am on the login page
    When I submit the login form as "twofactoruser"
    Then I should be asked for the authenticator code
    When I enter the authenticator code "000000"
    Then the authenticator code should be refused with "Invalid authenticator code."
    When I enter the authenticator code of "twofactoruser"
    Then I should be logged in as "twofactoruser"

  Scenario: A forgotten password is reset through the link in the mail
    Given I am not logged in
    When I ask for a password reset link for "user"
    Then an email with the subject "Reset your password" should be sent to "user"
    When I open the "clicking here" link of the email to "user"
    And I reset the password of "user" on the reset page
    Then I should see "Your password has been reset."

  Scenario: An unknown address gets the same answer, and no mail
    Given I am not logged in
    When I ask for a password reset link for "nobody@example.com"
    Then I should see "Please check your email to reset your password."
    And no email should be sent to "nobody@example.com"
