#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The ASP.NET Core project in this workspace.')
parser.add_argument('-n', '--dotnet',
                    default="_none_",
                    help='A dotnet command and its options, run in the app folder of the web container. A value that starts with a dash is joined to the flag with =. Example: --dotnet "list package", --dotnet "build" or --dotnet="--info"')
parser.add_argument('-r', '--rebuild',
                    action='store_true',
                    default=False,
                    help='Publish the app again (after a change to its code) and restart it.')
parser.add_argument('--restart',
                    action='store_true',
                    default=False,
                    help='Restart the app, and wait for it.')
parser.add_argument('--logs',
                    action='store_true',
                    default=False,
                    help='Show the end of the log of the app\'s web container.')
parser.add_argument('-e', '--environment',
                    default="_none_",
                    help='Run the app in another environment: Production (a live app: its error page, no debug information) or Development (the developer exception page). The project restarts. Example: --environment Development')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Make the default accounts through the app\'s user manager. An account that is there already gets its password, its role and its state back.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts through the app\'s user manager (its other accounts stay).')
ARGEOF
