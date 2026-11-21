#!/usr/bin/env bash

# workspace-name: ASP.NET Core (the Razor Pages app or the Blazor Web App, with individual accounts)

# Installed by the ASP.NET Core plugin (plugins.sh --install aspnet-core); __WORKSPACE__ is the workspace it was installed into.
#
# Build an ASP.NET Core app in a container: an app made with `dotnet new` from an official template with individual
# accounts (the Razor Pages app with the default account pages, or the Blazor Web App with --template blazor), at the
# current .NET release, published and run in production by the web container at https://<name>.ddev.site. With
# --install the app gets what an app adds once it goes to work (the Administrator role and a page only it opens, a mail
# sender pointed at the mail catcher, a seeding step of its own for the accounts, the status code page and, in the
# Razor Pages app, the movies pages of the official tutorial); with --add-users also the default accounts.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="aspnet_core";
distribution_title="ASP.NET Core";
distribution_webroot="app";

ARGPARSE_DESCRIPTION="Build an ${distribution_title} project in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/aspnet-core/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/aspnet-core/args/arg-aspnet-core.sh || exit 1 ;

shift $#;

aspnet_core_build ;
