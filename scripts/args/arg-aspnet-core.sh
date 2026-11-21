#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its DDEV project and its host name.')
parser.add_argument('-t', '--template',
                    default="webapp",
                    help='The official template of the app, with individual accounts: webapp (Razor Pages with the default account pages, the default) or blazor (the Blazor Web App, whose account pages are components of its own).')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Add what an app adds once it goes to work: the Administrator role and a page only it opens, a mail sender pointed at the mail catcher, a seeding step of its own for the accounts, the status code page, and in the Razor Pages app the movies pages of the official tutorial. Without it the template is built as it is.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts (administrator with the Administrator role, user, twofactoruser with two-factor sign-in, lockeduser locked out, unconfirmeduser with its email not confirmed): the ones the test scenarios log in as.')
parser.add_argument('-d', '--dotnet-version',
                    default="",
                    help='The .NET release line of the app and of the SDK image: 11.0 (the current one) by default, or 10.0 (the long-term-support one). Example: --dotnet-version 10.0')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the app in a browser when it is ready.')
ARGEOF
