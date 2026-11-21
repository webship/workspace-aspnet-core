Feature: Who may open what, the error pages and a refused form
  As the owner of the app
  I want each page to let in only the accounts it is for, and a failure to show nothing of the code
  So that the app keeps its records and its secrets

  Scenario: An account without the role is shown the access denied page
    Given I am a logged in user with the "user" user
    When I go to "/Admin"
    Then I should see the access denied page
    And I should be allowed to open "/Movies"

  @js-off
  Scenario: An exception shows the app's error page, with no debug information
    Given I am not logged in
    When I go to "/Throw"
    Then I should see the 500 error page
    And the error page should show its request ID
    And the page should not show debug information

  Scenario: The page refuses an empty form before it is sent
    Given I am a logged in user with the "user" user
    When I go to "/Movies/Create"
    And I press "Create"
    Then the "Title" field should have the error "The Title field is required."
    And the form should show the error "The Rating field is required."
