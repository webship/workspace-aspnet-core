#!/usr/bin/env bash

# ASP.NET Core for the Webship Workspace: build an app from an official template with individual accounts (the Razor
# Pages app with the default account pages, or the Blazor Web App), make its default accounts through its own user
# manager, run `dotnet` for it, and wire its step pack into the testing setup.
#
# Placed by `plugins.sh --install aspnet-core` in core/scripts/plugins/aspnet-core/functions/, where bootstrap sources it
# after the core's own functions. Everything runs in containers (DDEV by default), never on the host: the .NET SDK is
# copied from its official image into the project's web image; the app is made with `dotnet new`,
# published and run in production by the web container, with the router of the container tool sending the project's
# address to its port. NuGet keeps its downloads in the project (.nuget/). No public domain, no hosted service, no
# account anywhere.
#
# DDEV has no project type for ASP.NET Core, so an app of this plugin is a generic project that the plugin claims with
# a file of its own (.ddev/config.aspnet-core.yaml, written by the builder: the daemon of the app, its port, its
# settings), and four names are the ones the core's tools look for (the claim file's name with its dash as an
# underscore):
#   set_aspnet_core_users          the default accounts                         (cmd-tools-add-users.sh <project> aspnet_core)
#   add_aspnet_core_users          make them through the app's user manager     (the same tool, and --add-users of the builder)
#   cancel_aspnet_core_users       delete them again                            (cmd-tools-cancel-users.sh <project> aspnet_core)
#   testing_configure_aspnet_core  the step pack in the testing stack           (cmd-tools-testing.sh <project>)

# The step pack an ASP.NET Core app is tested with, and the release line it is required at.
readonly ASPNET_CORE_STEPS_PACKAGE='@webship-js/aspnet-core-steps';
readonly ASPNET_CORE_STEPS_VERSION='^2.0.0';

# The .NET release the builder makes an app at when none is asked for (the current one; 10.0 is the
# long-term-support line), where the project lives in the web container, and the port the app listens on.
readonly ASPNET_CORE_DEFAULT_DOTNET='11.0';
readonly ASPNET_CORE_ROOT='/var/www/html';
readonly ASPNET_CORE_PORT='5000';
# The authenticator key of twofactoruser (base32): a test secret of a local app, the one the step pack's users
# registry knows, so a test works its codes out the way an authenticator app does.
readonly ASPNET_CORE_TWO_FACTOR_KEY='JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';

# The default accounts, the ones a scenario logs in as: each signs in with its email address. Accounts are
# configuration, made once through the app's own user manager (its seeding step); a test suite never creates or
# deletes one. An account's state is part of the list: the Administrator role, two-factor sign-in with a known key,
# a lockout, an email address not confirmed yet.
function set_aspnet_core_users() {
  users=(administrator user twofactoruser lockeduser unconfirmeduser);
  local user ;
  for user in "${users[@]}" ; do
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
    printf -v "user_${user}_role" '%s' '_none_' ;
    printf -v "user_${user}_state" '%s' '' ;
  done
  user_administrator_role='Administrator' ;
  user_twofactoruser_state='two-factor' ;
  user_lockeduser_state='locked-out' ;
  user_unconfirmeduser_state='unconfirmed' ;
}

# Is this folder an ASP.NET Core app of this plugin? The builder leaves .ddev/config.aspnet-core.yaml in it.
function aspnet_core_is_project() {
  [ -f "$1/.ddev/config.aspnet-core.yaml" ] ;
}

# Go to the project a tool was asked about, or say why not.
function aspnet_core_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! aspnet_core_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not an ASP.NET Core app of this plugin (it has no .ddev/config.aspnet-core.yaml)." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# The template of a project's app: blazor when it has the components of a Blazor Web App, webapp otherwise.
function aspnet_core_template() {
  if [ -f "${1:-.}/app/Components/App.razor" ] ; then echo 'blazor' ; else echo 'webapp' ; fi
}

# The .NET project name of a project's app (its .csproj).
function aspnet_core_app_name() {
  local csproj ;
  csproj="$(ls "${1:-.}"/app/*.csproj 2>/dev/null | head -n 1)" ;
  basename "${csproj:-App.csproj}" .csproj ;
}

# Has the app of a project the additions of --install (the seeding step of the accounts, the mail sender)?
function aspnet_core_has_accounts() {
  grep -q 'AccountSeeder' "${1:-.}/app/Program.cs" 2>/dev/null ;
}

# The namespace of an app made for a project: its name in Pascal case, letters and digits only (my-app: MyApp).
function aspnet_core_namespace() {
  local name="$1" part out='' ;
  IFS='-' read -ra parts <<< "${name}" ;
  for part in "${parts[@]}" ; do
    [ -n "${part}" ] && out="${out}$(printf '%s' "${part:0:1}" | tr '[:lower:]' '[:upper:]')${part:1}" ;
  done
  [[ "${out}" =~ ^[A-Za-z] ]] || out="App${out}" ;
  printf '%s' "${out}" ;
}

# What the container tool is told about the app: the router sends ports 80 and 443 of the project's address to the
# app's port, the web container runs the published app as a daemon once it is ready (.app-ready), in the environment
# asked for, behind the router's HTTPS (its forwarded headers read), with its database and the keys of its cookies in
# data/ and its mail sent to the project's mail catcher; NuGet keeps its downloads in the project. This file is also
# the plugin's claim on the project. The .NET SDK goes into the web image.
function aspnet_core_write_ddev_config() {
  local project_path="$1" dotnet_version="$2" app_name="$3" environment="${4:-Production}" ;
  mkdir -p "${project_path}/.ddev/web-build" || return 1 ;
  cat > "${project_path}/.ddev/config.aspnet-core.yaml" <<YAMLEOF
# ASP.NET Core in this project, and the claim of the workspace's ASP.NET Core plugin on it. Written by the ASP.NET
# Core builder of the workspace; build again rather than editing by hand (cmd-tools-aspnet-core-cli.sh --environment
# changes the environment). The web container serves no files of its own: the router sends ports 80 and 443 of the
# project's address to the app, which the web container runs as a daemon once it is published and its accounts are
# in (.app-ready), behind the router's HTTPS. The app keeps its database and the keys of its cookies in data/, sends
# its mail to the mail catcher of the project, and NuGet keeps its downloads in the project (.nuget/).
web_extra_exposed_ports:
  - name: aspnet-core
    container_port: ${ASPNET_CORE_PORT}
    http_port: 80
    https_port: 443
web_extra_daemons:
  - name: aspnet-core
    command: "bash -c 'while [ ! -f ${ASPNET_CORE_ROOT}/.app-ready ]; do sleep 2; done; cd ${ASPNET_CORE_ROOT}/publish && exec dotnet ${app_name}.dll'"
    directory: ${ASPNET_CORE_ROOT}
web_environment:
  - ASPNETCORE_ENVIRONMENT=${environment}
  - ASPNETCORE_HTTP_PORTS=${ASPNET_CORE_PORT}
  - ASPNETCORE_FORWARDEDHEADERS_ENABLED=true
  - ConnectionStrings__DefaultConnection=DataSource=${ASPNET_CORE_ROOT}/data/app.db;Cache=Shared
  - DataProtection__KeysFolder=${ASPNET_CORE_ROOT}/data/keys
  - Smtp__Host=127.0.0.1
  - Smtp__Port=1025
  - NUGET_PACKAGES=${ASPNET_CORE_ROOT}/.nuget/packages
  - DOTNET_CLI_TELEMETRY_OPTOUT=1
  - DOTNET_NOLOGO=1
  - DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
YAMLEOF
  cat > "${project_path}/.ddev/web-build/Dockerfile.aspnet-core" <<DOCKEREOF
# The .NET SDK of the app (${dotnet_version}), copied from its official image. Written by the ASP.NET Core builder of
# the workspace.
COPY --from=mcr.microsoft.com/dotnet/sdk:${dotnet_version} /usr/share/dotnet /usr/share/dotnet
ENV DOTNET_ROOT=/usr/share/dotnet DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
RUN ln -sf /usr/share/dotnet/dotnet /usr/local/bin/dotnet && dotnet --list-sdks
DOCKEREOF
}

# The accounts file of the app (config/accounts.json) from the list set_aspnet_core_users loads, which its seeding
# step reads.
function aspnet_core_write_accounts() {
  local user name mail role state entries='' entry ;
  for user in "${users[@]}" ; do
    name="user_${user}_name"; mail="user_${user}_mail"; role="user_${user}_role"; state="user_${user}_state";
    entry="    { \"email\": \"${!mail}\"" ;
    [ "${!role}" != '_none_' ] && [ -n "${!role}" ] && entry="${entry}, \"roles\": [\"${!role}\"]" ;
    case "${!state}" in
      two-factor)  entry="${entry}, \"authenticatorKey\": \"${ASPNET_CORE_TWO_FACTOR_KEY}\"" ;;
      locked-out)  entry="${entry}, \"lockedOut\": true" ;;
      unconfirmed) entry="${entry}, \"emailConfirmed\": false" ;;
    esac
    entries="${entries:+${entries},
}${entry} }" ;
  done
  mkdir -p config || return 1 ;
  cat > config/accounts.json <<JSONEOF
{
  "roles": ["Administrator"],
  "accounts": [
${entries}
  ]
}
JSONEOF
}

# Run a `dotnet` command in the web container, in a folder of the project (the app's by default).
function aspnet_core_dotnet() {
  local dir="${ASPNET_CORE_ROOT}/app" ;
  if [ "$1" == '--in' ] ; then dir="$2" ; shift 2 ; fi
  ddev exec -d "${dir}" "dotnet $*" < /dev/null ;
}

# Publish the app (Release) where the daemon runs it.
function aspnet_core_publish() {
  aspnet_core_dotnet "publish -c Release -o ${ASPNET_CORE_ROOT}/publish -nologo" ;
}

# The app's own seeding step, run with the published app: the accounts of config/accounts.json through its user
# manager, the password on standard input (never on a command line). `cancel` deletes them instead.
function aspnet_core_seed() {
  local mode="${1:-seed}" app_name password ;
  app_name="$(aspnet_core_app_name .)" ;
  if [ "${mode}" == 'cancel' ] ; then
    ddev exec -d "${ASPNET_CORE_ROOT}/publish" "Logging__LogLevel__Default=Warning dotnet ${app_name}.dll --cancel-accounts ${ASPNET_CORE_ROOT}/config/accounts.json" < /dev/null ;
    return $? ;
  fi
  password="user_${users[0]}_password" ;
  printf '%s' "${!password}" | ddev exec -d "${ASPNET_CORE_ROOT}/publish" "Logging__LogLevel__Default=Warning dotnet ${app_name}.dll --seed-accounts ${ASPNET_CORE_ROOT}/config/accounts.json" ;
}

# Restart the app's daemon in the web container.
function aspnet_core_restart() {
  ddev exec "supervisorctl restart webextradaemons:aspnet-core" < /dev/null > /dev/null ;
}

# Wait until the app answers its home page (from inside the web container).
function aspnet_core_wait() {
  local attempt code ;
  for attempt in $(seq 1 120) ; do
    code="$(ddev exec "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:${ASPNET_CORE_PORT}/" < /dev/null 2>/dev/null | tr -d '\r')" ;
    if [ "${code}" == '200' ] ; then
      return 0 ;
    fi
    sleep 2 ;
  done
  echo "The app did not come up; the end of the web container's log:" ;
  ddev logs --tail 60 < /dev/null 2>/dev/null ;
  return 1 ;
}

# The ASP.NET Core release and the SDK the app runs on, as the container says them.
function aspnet_core_versions() {
  local runtime sdk ;
  # sed reads the whole output: a head that stops early would cut the pipe of the container tool.
  runtime="$(ddev exec "dotnet --list-runtimes" < /dev/null 2>/dev/null | tr -d '\r' | sed -n 's/^Microsoft.AspNetCore.App \([^ ]*\).*/\1/p' | tail -n 1)" ;
  sdk="$(ddev exec "dotnet --version" < /dev/null 2>/dev/null | tr -d '\r')" ;
  echo "ASP.NET Core ${runtime:-(unknown)} (SDK ${sdk:-unknown})" ;
}

# Build an ASP.NET Core app from nothing: the project, the .NET SDK in its web image, the app made with `dotnet new`
# (the Razor Pages app, or the Blazor Web App with --template blazor) with individual accounts, with --install the
# additions of the test site and its database, with --add-users the default accounts; then the app published and
# started.
function aspnet_core_build() {
  trim_project_name ;
  local base_url="https://${PROJECT_NAME}.ddev.site" ;
  local dotnet_version="${DOTNET_VERSION:-${ASPNET_CORE_DEFAULT_DOTNET}}" ;
  local template="${TEMPLATE:-webapp}" ;
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" ;
  local app_name kind="the Razor Pages app with the default account pages" ;
  [ "${template}" == 'blazor' ] && kind="the Blazor Web App with its account pages" ;

  case "${template}" in webapp|blazor) ;; *) echo "--template takes webapp or blazor, not ${template}. Nothing was changed." ; exit 1 ;; esac
  if ! [[ "${dotnet_version}" =~ ^[0-9]+\.[0-9]+$ ]] ; then
    echo "--dotnet-version takes a release line of .NET (11.0, or 10.0 for the long-term-support one), not ${dotnet_version}. Nothing was changed." ;
    exit 1 ;
  fi
  if [ "${ADD_USERS}" == 'yes' ] && [ "${INSTALL}" != 'yes' ] ; then
    echo "--add-users needs --install: the default accounts are made by the seeding step --install adds to the app." ;
    exit 1 ;
  fi
  if [ ${#PROJECT_NAME} -gt 40 ] || ! [[ "${PROJECT_NAME}" =~ ^[a-z0-9][a-z0-9-]*$ ]] ; then
    echo "The project name ${PROJECT_NAME} must be small letters, digits and dashes (its address and its container take it). Nothing was changed." ;
    exit 1 ;
  fi
  local prepare="${WORKSPACE_SCRIPTS}/plugins/aspnet-core/aspnet-core-prepare-app.py" ;
  if [ ! -f "${prepare}" ] ; then
    echo "aspnet-core-prepare-app.py is not in ${WORKSPACE_SCRIPTS}/plugins/aspnet-core: install the plugin (plugins.sh --install aspnet-core)." ;
    exit 1 ;
  fi
  app_name="$(aspnet_core_namespace "${PROJECT_NAME}")" ;

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  # A project of the same name goes first, with its containers.
  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}/app" "${PROJECT_NAME}/data" ;
  cd "${project_path}" || exit 1 ;

  # A generic project: the web container runs the app as a daemon and the router sends the project's address to its
  # port; no database of the container tool's own (the app keeps its data in SQLite), the Node.js of the workspace
  # rule for a test suite run in the web container.
  ddev config --project-type=generic --webserver-type=generic --docroot=app --project-name=${PROJECT_NAME} \
    --omit-containers=db --nodejs-version=$(ddev_nodejs_version) < /dev/null || exit 1 ;
  aspnet_core_write_ddev_config "${project_path}" "${dotnet_version}" "${app_name}" || exit 1 ;

  echo "Starting the project: the .NET SDK's image (mcr.microsoft.com/dotnet/sdk:${dotnet_version}) is about 900 MB the first time." ;
  ddev_up start -y < /dev/null || exit 1 ;

  echo "Making ${kind} with dotnet new ${template} --auth Individual (the first run downloads its packages into .nuget/)." ;
  aspnet_core_dotnet --in "${ASPNET_CORE_ROOT}" "new ${template} --auth Individual -o app -n ${app_name} --force" || { echo "dotnet new made no app." ; exit 1 ; } ;

  if [ "${INSTALL}" == 'yes' ] ; then
    python3 "${prepare}" app --template "${template}" || exit 1 ;
    if [ "${template}" == 'webapp' ] ; then
      # The migration of the movies, with the EF Core tools of the app's own release (dotnet-ef, in the project).
      local ef_version ;
      ef_version="$(sed -n 's/.*Include="Microsoft.EntityFrameworkCore.Design" Version="\([^"]*\)".*/\1/p' app/${app_name}.csproj)" ;
      aspnet_core_dotnet --in "${ASPNET_CORE_ROOT}" "tool install dotnet-ef --version ${ef_version} --tool-path ${ASPNET_CORE_ROOT}/.dotnet-tools" || exit 1 ;
      ddev exec -d "${ASPNET_CORE_ROOT}/app" "${ASPNET_CORE_ROOT}/.dotnet-tools/dotnet-ef migrations add AddMovies" < /dev/null || exit 1 ;
    fi
  else
    # The template as it is: the database it ships (app.db, its tables made), in the place the daemon reads it.
    cp "app/app.db" data/app.db 2>/dev/null || cp "app/Data/app.db" data/app.db 2>/dev/null ;
  fi

  echo "Publishing the app (Release)." ;
  aspnet_core_publish || { echo "The app could not be published." ; exit 1 ; } ;

  if [ "${INSTALL}" == 'yes' ] ; then
    if [ "${ADD_USERS}" == 'yes' ] ; then
      set_aspnet_core_users ;
    else
      users=() ;
    fi
    aspnet_core_write_accounts || exit 1 ;
    echo "Making the accounts through the app's user manager (its seeding step applies the migrations first)." ;
    aspnet_core_seed || { echo "The seeding step of the app failed." ; exit 1 ; } ;
  fi
  touch .app-ready ;
  echo "Waiting for the app." ;
  aspnet_core_wait || exit 1 ;

  echo "${doc_name} ${PROJECT_NAME} has been built: ${kind}, $(aspnet_core_versions), at ${base_url}." ;
  local account_path='/Identity/Account' ;
  [ "${template}" == 'blazor' ] && account_path='/Account' ;
  echo "The login: ${base_url}${account_path}/Login · the mail catcher: ${base_url}:8026" ;
  if [ "${INSTALL}" == 'yes' ] && [ "${ADD_USERS}" == 'yes' ] ; then
    echo "The default accounts: administrator (Administrator), user, twofactoruser (two-factor sign-in), lockeduser (locked out), unconfirmeduser (email not confirmed), each @example.com with the workspace's shared password." ;
  elif [ "${INSTALL}" == 'yes' ] ; then
    echo "No account yet: add the default ones with cmd-tools-aspnet-core-cli.sh ${PROJECT_NAME} --add-users." ;
  else
    echo "The template as it is (built without --install): no account, no mail sender; register on the app's own page." ;
  fi
  users=() ;

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch "${base_url}" ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Make the default accounts through the app's user manager (an account that is there already gets its password,
# its roles and its state back). The list is loaded by the caller (set_aspnet_core_users): the core's add_users, the
# builder, the tool.
function add_aspnet_core_users() {
  aspnet_core_enter_project || return 1 ;
  if ! aspnet_core_has_accounts ; then
    echo "${PROJECT_NAME} has no seeding step of its accounts (it was built without --install): build it again with --install." ;
    cd ${WORKSPACE_ROOT}/${doc_name}; return 1 ;
  fi
  local user user_name user_mail user_password user_role user_state ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role"; user_state="user_${user}_state";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role}";
    [ -n "${!user_state}" ] && echo "     User state: ${!user_state}";
    echo " ================================================================= ";
  done
  local status=0 ;
  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y < /dev/null || status=1 ;
  fi
  aspnet_core_write_accounts && aspnet_core_seed || status=1 ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# Delete the default accounts through the app's user manager (its other accounts stay).
function cancel_aspnet_core_users() {
  aspnet_core_enter_project || return 1 ;
  if ! aspnet_core_has_accounts ; then
    echo "${PROJECT_NAME} has no seeding step of its accounts (it was built without --install)." ;
    cd ${WORKSPACE_ROOT}/${doc_name}; return 1 ;
  fi
  local user user_name ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo " ================================================================= ";
  done
  local status=0 ;
  aspnet_core_write_accounts && aspnet_core_seed cancel || status=1 ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# What cmd-tools-aspnet-core-cli.sh does: the first of --dotnet, --rebuild, --restart, --logs, --environment,
# --add-users, --cancel-users that was asked for; with none of them, what the app is.
function aspnet_core_cli_tool() {
  trim_project_name ;
  aspnet_core_enter_project || exit 1 ;

  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y < /dev/null || exit 1 ;
  fi

  if [ ! "${DOTNET}" == '_none_' ] ; then
    aspnet_core_dotnet "${DOTNET}" ;
    exit $? ;
  fi

  if [ "${REBUILD}" == 'yes' ] ; then
    aspnet_core_publish || exit 1 ;
    aspnet_core_restart && aspnet_core_wait || exit 1 ;
    echo "${PROJECT_NAME} is published again and running: $(aspnet_core_versions)." ;
  elif [ "${RESTART}" == 'yes' ] ; then
    aspnet_core_restart && aspnet_core_wait || exit 1 ;
    echo "${PROJECT_NAME} is running again: $(aspnet_core_versions)." ;
  elif [ "${LOGS}" == 'yes' ] ; then
    ddev logs --tail 200 < /dev/null ;
  elif [ ! "${ENVIRONMENT}" == '_none_' ] ; then
    case "${ENVIRONMENT}" in Production|Development) ;; *) echo "--environment takes Production or Development, not ${ENVIRONMENT}." ; exit 1 ;; esac
    sed -i "s/^  - ASPNETCORE_ENVIRONMENT=.*/  - ASPNETCORE_ENVIRONMENT=${ENVIRONMENT}/" .ddev/config.aspnet-core.yaml ;
    ddev restart < /dev/null || exit 1 ;
    aspnet_core_wait || exit 1 ;
    echo "${PROJECT_NAME} runs in ${ENVIRONMENT}." ;
  elif [ "${ADD_USERS}" == 'yes' ] ; then
    set_aspnet_core_users ;
    add_aspnet_core_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    set_aspnet_core_users ;
    cancel_aspnet_core_users ;
  else
    local template account_path='/Identity/Account' environment ;
    template="$(aspnet_core_template .)" ;
    [ "${template}" == 'blazor' ] && account_path='/Account' ;
    environment="$(sed -n 's/^  - ASPNETCORE_ENVIRONMENT=//p' .ddev/config.aspnet-core.yaml)" ;
    echo "${doc_name}/${PROJECT_NAME}: the ${template} app $(aspnet_core_app_name .), $(aspnet_core_versions), in ${environment:-Production}" ;
    echo "  the app:          https://${PROJECT_NAME}.ddev.site" ;
    echo "  the login:        https://${PROJECT_NAME}.ddev.site${account_path}/Login" ;
    echo "  the mail catcher: https://${PROJECT_NAME}.ddev.site:8026" ;
    if aspnet_core_has_accounts ; then
      echo "Accounts:" ;
      ddev exec -d "${ASPNET_CORE_ROOT}/data" "sqlite3 app.db \"select u.Email, coalesce(group_concat(r.Name), ''), u.EmailConfirmed, u.TwoFactorEnabled, case when u.LockoutEnd is null then 0 else 1 end from AspNetUsers u left join AspNetUserRoles ur on ur.UserId = u.Id left join AspNetRoles r on r.Id = ur.RoleId group by u.Id order by u.Email;\"" < /dev/null 2>/dev/null \
        | tr -d '\r' | awk -F'|' '{ printf "  %s%s%s%s%s\n", $1, ($2 != "" ? " (" $2 ")" : ""), ($3 == "0" ? ", email not confirmed" : ""), ($4 == "1" ? ", two-factor sign-in" : ""), ($5 == "1" ? ", locked out" : "") }' ;
    else
      echo "  the template as it is (built without --install): no default accounts" ;
    fi
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of an ASP.NET Core app. The core's testing_configure calls this in the project
# folder once webship-js is scaffolded and before the dependencies are installed; for a project that is not one of
# this plugin's it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's own, gives cucumber.js
# the tags that keep the pack's assertions that must fail out of a normal run, the pages of the app the steps need
# (where its account pages are, a page only a signed-in account may open, the mail catcher), the browser messages the
# pack's scenarios turn off, and the users registry of the default accounts (a handle a scenario reads, mapped to an
# account, with the authenticator key of the two-factor one), and writes a first feature when the project has none of
# its own. Every part is skipped when it is already there, so a second run adds what the first missed and never resets
# a suite.
function testing_configure_aspnet_core() {
  local project_path="$1";
  aspnet_core_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  ASP.NET Core: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the ASP.NET Core step pack (${ASPNET_CORE_STEPS_PACKAGE} ${ASPNET_CORE_STEPS_VERSION}).";
  set_aspnet_core_users ;
  local registry="" user user_mail user_password user_state ;
  for user in "${users[@]}" ; do
    user_mail="user_${user}_mail"; user_password="user_${user}_password"; user_state="user_${user}_state";
    registry="${registry}${user}|${!user_mail}|${!user_password}|$([ "${!user_state}" == 'two-factor' ] && echo "${ASPNET_CORE_TWO_FACTOR_KEY}")"$'\n' ;
  done

  local site_name account_path='/Identity/Account' protected='/Movies' ;
  site_name="$(sed -n 's/^name:[[:space:]]*"\{0,1\}\([A-Za-z0-9._-]*\)"\{0,1\}[[:space:]]*$/\1/p' "${project_path}/.ddev/config.yaml" | head -n 1)" ;
  if [ "$(aspnet_core_template "${project_path}")" == 'blazor' ] ; then
    account_path='/Account' ;
    protected='/auth' ;
  elif ! aspnet_core_has_accounts "${project_path}" ; then
    protected='/Identity/Account/Manage' ;
  fi

  python3 - "${project_path}" "${ASPNET_CORE_STEPS_PACKAGE}" "${ASPNET_CORE_STEPS_VERSION}" 'ASPNET_CORE' "${registry}" "https://${site_name:-${PROJECT_NAME}}.ddev.site" "${account_path}" "${protected}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry, address, account_path, protected = sys.argv[1:9]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=4) + '\n')
    print('  package.json: %s %s' % (pack, version))

cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

if not re.search(r"^[ \t]*tags:", src, re.M):
    default = re.search(r"^([ \t]*)default:[ \t]*\{[ \t]*$", src, re.M)
    if default:
        pad = default.group(1) + '  '
        block = [
            pad + "// The pack's assertions that must fail are no part of a normal run.",
            pad + "tags: process.env.CUCUMBER_TAGS || 'not @wip and not @must-fail',",
        ]
        src = src[:default.end()] + '\n' + '\n'.join(block) + src[default.end():]
        print('  cucumber.js: the tags that keep the assertions that must fail out of a normal run')

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not world:
    sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
pad = world.group(1) + '  '
additions = []
if not re.search(r"^[ \t]*accountPath:", src, re.M):
    additions += [
        pad + "// The pages of the app the steps need: where its account pages are (Login, Logout, Register, Manage, ...), a page",
        pad + "// only a signed-in account may open (the steps ask it whether the browser is signed in), the mail catcher.",
        pad + "accountPath: '%s'," % account_path,
        pad + "protectedPath: '%s'," % protected,
        pad + "mailUrl: process.env.MAIL_URL || '%s:8026'," % address,
    ]
    print('  cucumber.js: the pages of the app the steps need')
if not re.search(r"^[ \t]*javascript:", src, re.M):
    additions += [
        pad + "// The browser logs every error page it gets (a 404, a 400, a 500): the scenarios of the step pack that meet one carry @js-off.",
        pad + "javascript: { mode: process.env.WEBSHIP_JS_ERROR_MODE || 'warn', levels: ['error'], beforeScenario: false, afterScenario: true },",
    ]
if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    rows = [r.split('|') for r in registry.splitlines() if r.strip()]
    additions += [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of the app (the default accounts:",
        pad + "// cmd-tools-aspnet-core-cli.sh --add-users). Override one with %s_<HANDLE>_EMAIL and %s_<HANDLE>_PASSWORD." % (prefix, prefix),
        pad + "users: {",
    ]
    for handle, mail, password, key in rows:
        env = '%s_%s' % (prefix, handle.upper())
        entry = "  %s: { email: process.env.%s_EMAIL || '%s', password: process.env.%s_PASSWORD || '%s'" % (handle, env, mail, env, password)
        if key:
            entry += ", otpSecret: process.env.%s_OTP_SECRET || '%s'" % (env, key)
        additions.append(pad + entry + " },")
    additions.append(pad + "},")
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))
if additions:
    src = src[:world.end()] + '\n' + '\n'.join(additions) + src[world.end():]

# The address the suite opens when LAUNCH_URL is not set: the placeholder of the scaffold becomes the app's.
placeholder = "process.env.LAUNCH_URL || 'http://localhost:8080'"
if placeholder in src:
    src = src.replace(placeholder, "process.env.LAUNCH_URL || '%s'" % address)
    print('  cucumber.js: the address of the app (%s)' % address)

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the app yet (the movies are the Razor Pages app's).
  local feature="${WORKSPACE_SCRIPTS}/plugins/aspnet-core/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && sed "s|\"/Movies\"|\"${protected}\"|" "${feature}" > "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the login, the accounts and the two-factor sign-in" ;
  fi

  # The scenarios log in as the default accounts: make sure an app with its seeding step has them, once it answers
  # again (installing the webship-js add-on restarts the project, and the app with it).
  if aspnet_core_has_accounts "${project_path}" ; then
    if ( cd "${project_path}" && aspnet_core_wait > /dev/null 2>&1 && aspnet_core_write_accounts > /dev/null 2>&1 && aspnet_core_seed > /dev/null 2>&1 ) ; then
      echo "  the default accounts are in the app (${users[*]})" ;
    else
      echo "  The default accounts could not be made: is the app running (ddev start in ${project_path})?" ;
    fi
  else
    echo "  ${PROJECT_NAME:-the app} is the template as it is (built without --install): it has no default accounts, so the login scenarios of tests/features/site.feature do not apply." ;
  fi
}
