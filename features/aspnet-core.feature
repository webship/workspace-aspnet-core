Feature: The ASP.NET Core plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the ASP.NET Core builder, each
  AI folder lists the items of its kind the plugin ships, and the Plugins page lists the plugin
  with its steps.

  # Settings lists every plugin that was added; the package and what the plugin ships are on its own page.
  Scenario: Settings lists the plugin, and its own page names its package and what it ships
    Given I am on "/settings"
     Then I should see "ASP.NET Core"
     When I go to "/settings/plugin/aspnet-core"
     Then I should see "@webship.co/workspace-aspnet-core"
      And I should see "cmd-aspnet-core-project.sh"
      And I should see "aspnet-core-site-builder"

  Scenario: A sites folder offers the ASP.NET Core builder
    Given I am on "/dev"
     Then "option[value='cmd-aspnet-core-project.sh']" should be attached

  # The AI folders are searched by name: with every plugin on, a folder lists more than one page of items.
  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents?q=aspnet-core-"
     Then I should see "aspnet-core-site-builder"
      And I should see "aspnet-core-tester"

  Scenario: The AI Skills folder lists the skill the plugin ships
    Given I am on "/ai-skills?q=aspnet-core-scenarios"
     Then I should see "aspnet-core-scenarios"

  Scenario: The AI Commands folder lists the command the plugin ships
    Given I am on "/ai-commands?q=aspnet-core-test"
     Then I should see "aspnet-core-test"

  Scenario: The AI Prompts folder lists the prompts the plugin ships
    Given I am on "/ai-prompts?q=aspnet-core-"
     Then I should see "aspnet-core-build-and-test"
      And I should see "aspnet-core-scenarios-for-an-area"
