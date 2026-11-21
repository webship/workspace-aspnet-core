#!/usr/bin/env bash

# Installed by the ASP.NET Core plugin (plugins.sh --install aspnet-core); __WORKSPACE__ is the workspace it was installed into.
#
# `dotnet` and the run of one ASP.NET Core app of this workspace, in its web container: say what the app is, run a
# dotnet command for it, publish it again, restart it, show its log, run it in another environment, add or cancel the
# default accounts. Nothing here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="aspnet_core";

ARGPARSE_DESCRIPTION="Run dotnet for an ASP.NET Core app of __WORKSPACE__: status, a dotnet command, a new publish, a restart, its log, its environment, the default accounts"
# The args file comes with the plugin: core/scripts/plugins/aspnet-core/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/aspnet-core/args/arg-aspnet-core-cli.sh || exit 1 ;

shift $#;

aspnet_core_cli_tool ;
