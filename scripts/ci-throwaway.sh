#!/bin/sh
# Write, start and tear down the THROWAWAY container CI's instance job runs against
# (docs/DEVELOPMENT.md's "Verifying the start path against a throwaway container").
#
# **It never points `docker compose` at this repository's own docker-compose.yml.** That file
# names the container `ocupilot` and mounts `./iris-data`, so one missing override line reaches
# a live instance. The compose file this writes is a standalone one in a scratch directory, with
# its own project name, its own container name, its own host ports (never 52774 or 1973) and its
# own data directory, and `down` takes `-v` so nothing of it survives.
#
# The `restart`, `depends_on`, `healthcheck` and `command` keys, and the one-shot `durable-init`
# service, are copied from docker-compose.yml on purpose, so a start behaves on the throwaway as it
# would there. Copy them again when they change; `ui/tools/ci.test.mjs` holds the two equal.
#
# Beside the arming variables, its environment carries OCUPILOT_LOAD_TESTS: "1", which
# docker-compose.yml does not: it makes container-start.sh compile the roster's test-scope package
# the suite runs (AD-17). `up --product` leaves it out, so the start hook compiles what a product
# start compiles, no test class (the arming variables stay), and `product-check` then counts it.
# `product-reuse` compiles two classes into the test package and starts a product throwaway again
# over the same volume, which must delete both (DW-1885).
#
# Usage:
#   sh scripts/ci-throwaway.sh up    [--dir DIR] [--project NAME] [--web 52776] [--super 1975] [--product]
#   sh scripts/ci-throwaway.sh logs  [--dir DIR]
#   sh scripts/ci-throwaway.sh product-check [--dir DIR]
#   sh scripts/ci-throwaway.sh product-reuse [--dir DIR]
#   sh scripts/ci-throwaway.sh data-check [--dir DIR]
#   sh scripts/ci-throwaway.sh down  [--dir DIR] [--project NAME]
#
# Without --dir or OCUPILOT_THROWAWAY_DIR the directory is $HOME/.ocupilot-throwaways/<project> on
# macOS, whose /tmp cleaner prunes files left untouched for days, and /tmp/ocupilot-ci elsewhere.
set -e

ACTION="${1:-}"
shift 2>/dev/null || true

DIR="${OCUPILOT_THROWAWAY_DIR:-}"
PROJECT="ocupilot-ci"
WEB_PORT="52776"
SUPER_PORT="1975"
IMAGE="intersystems/irishealth-community:2026.2"
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
# The environment line that makes the start hook compile the test package; `--product` empties it.
LOAD_TESTS_ENV='OCUPILOT_LOAD_TESTS: "1"'

while [ $# -gt 0 ]; do
    case "$1" in
        --dir) DIR="$2"; shift 2 ;;
        --project) PROJECT="$2"; shift 2 ;;
        --web) WEB_PORT="$2"; shift 2 ;;
        --super) SUPER_PORT="$2"; shift 2 ;;
        --image) IMAGE="$2"; shift 2 ;;
        --product) LOAD_TESTS_ENV=""; shift ;;
        *) echo "ci-throwaway: unknown argument $1"; exit 2 ;;
    esac
done

# The local root a macOS default lands in, and the one the scratch-root guard below admits. Trailing
# slashes come off HOME, and a HOME that is not absolute gives no root, so a relative HOME cannot
# admit a relative --dir.
HOME_ROOT="${HOME:-}"
while [ "$HOME_ROOT" != "${HOME_ROOT%/}" ]; do
    HOME_ROOT="${HOME_ROOT%/}"
done
case "$HOME_ROOT" in
    /?*) ;;
    *) HOME_ROOT="" ;;
esac

if [ -z "$DIR" ]; then
    DIR="/tmp/ocupilot-ci"
    if [ "$(uname -s)" = "Darwin" ] && [ -n "$HOME_ROOT" ]; then
        DIR="$HOME_ROOT/.ocupilot-throwaways/$PROJECT"
    fi
fi

# The live instance's own ports, refused outright. This script writes a compose file and starts
# a container from it; publishing the live ports would either collide with a running instance or,
# worse, be mistaken for one.
if [ "$WEB_PORT" = "52774" ] || [ "$SUPER_PORT" = "1973" ]; then
    echo "ci-throwaway: 52774 and 1973 are the live container's published ports; a throwaway never takes them"
    exit 2
fi
if [ "$PROJECT" = "ocupilot" ]; then
    echo "ci-throwaway: 'ocupilot' is the live container's own project name; a throwaway never takes it"
    exit 2
fi
# Slot dev instances -- the owner-managed containers a parallel /epic-cycle runner compiles into
# (ocupilot-slot-*, see CLAUDE.md "Container") -- are as untouchable as the live container: their
# project names and published ports are refused the same way.
case "$PROJECT" in
    ocupilot-slot-*)
        echo "ci-throwaway: '$PROJECT' is a slot dev instance's project name; a throwaway never takes it"
        exit 2 ;;
esac
if [ "$WEB_PORT" = "52775" ] || [ "$SUPER_PORT" = "1974" ]; then
    echo "ci-throwaway: 52775 and 1974 are slot B's published ports; a throwaway never takes them"
    exit 2
fi
if [ "$WEB_PORT" = "52778" ] || [ "$SUPER_PORT" = "1977" ]; then
    echo "ci-throwaway: 52778 and 1977 are slot C's published ports; a throwaway never takes them"
    exit 2
fi
# `down` removes $DIR recursively, and $DIR is caller-supplied. Every other destructive surface
# in this script and in ci-image-compile.sh is guarded by name (52774, 1973, project `ocupilot`,
# container `ocupilot`); this one was not, so a mistyped --dir deleted whatever it named.
# Scratch roots only, and never the root of one. A `..` would walk out of the root the case below
# checks, so `/tmp/../x` is refused before it.
case "$DIR" in
    *..*) echo "ci-throwaway: '$DIR' contains '..', which walks out of any root this could check; a throwaway's directory is removed recursively, so it must name its scratch root directly"; exit 2 ;;
esac
case "$DIR" in
    /tmp/?*|/private/tmp/?*|"${TMPDIR:-/nonexistent-tmpdir}"?*|"${HOME_ROOT:-/nonexistent-home}/.ocupilot-throwaways"/?*) ;;
    *) echo "ci-throwaway: '$DIR' is not under a scratch root; a throwaway's directory is removed recursively, so it must be under /tmp, /private/tmp, \$TMPDIR or \$HOME/.ocupilot-throwaways"; exit 2 ;;
esac

COMPOSE_FILE="$DIR/compose.yml"

# How many times a bring-up that failed on a host-port bind is retried (DW-439), and the base of
# the wait between attempts. The wait grows with the attempt (2s, then 4s), because three cycles
# run back to back would otherwise ask for the port again well inside the seconds a transient
# occupant holds it for. Overridable so a test that stubs docker can set it to 0.
BIND_ATTEMPTS=3
BIND_RETRY_SECONDS="${OCUPILOT_BIND_RETRY_SECONDS:-2}"

# The kernel's ephemeral port range, named in the exhaustion message so the next occurrence is a
# measurement rather than the inference the ledger entry recorded. Linux only; anywhere else it
# says so rather than printing nothing.
ephemeral_range() {
    if [ -r /proc/sys/net/ipv4/ip_local_port_range ]; then
        tr '\t' '-' < /proc/sys/net/ipv4/ip_local_port_range | tr -d '\n'
    else
        printf 'not readable on this platform'
    fi
}

# Remove the throwaway's durable directory, whoever owns what is in it.
#
# IRIS creates /durable/iris and everything under it as its own user, uid 51773. On Linux -- every
# GitHub runner -- those files are uid 51773 on the host too, and unlinking them needs write
# permission on the directories holding them, which the invoking user does not have: a plain
# `rm -rf` removes what it can and exits non-zero. Probed on this build against the pinned image:
# uid 1001 got `rm: cannot remove '/scratch/data/iris/mgr/messages.log': Permission denied`, exit
# 1, tree intact. Docker Desktop maps bind-mount ownership to the calling user, so the plain
# removal succeeds on macOS -- it is tried first, and the container is the fallback, using the
# image this script already pulled with its entrypoint overridden so nothing starts an instance.
scrub_data() {
    if [ ! -d "$DIR/data" ]; then return 0; fi
    if rm -rf "$DIR/data" 2>/dev/null; then return 0; fi
    docker run --rm --user 0:0 --entrypoint sh -v "$DIR:/scratch" "$IMAGE" -c 'rm -rf /scratch/data'
}

case "$ACTION" in
    up)
        # A project Compose already knows from a DIFFERENT config file is someone else's throwaway
        # (a second runner's, or a slot's): `up` here would recreate their container under this
        # definition and the later `down -v` would remove it, with no error at any point. Our own
        # project from a skipped teardown lists THIS config file and is recreated as before.
        listed=$(docker compose ls -a --format json 2>/dev/null | tr -d '\n' | grep -o "{[^}]*\"Name\":\"$PROJECT\"[^}]*}" || true)
        if [ -n "$listed" ] && ! printf '%s' "$listed" | grep -q "\"ConfigFiles\":\"$COMPOSE_FILE\""; then
            echo "ci-throwaway: project '$PROJECT' is already registered with Compose from a different config file; a throwaway never takes over another project"
            exit 2
        fi
        # A previous run whose teardown was skipped leaves $DIR/data holding an INSTALLED
        # volume, and `up` over it validates a first install that already happened. The
        # header promises a fresh container; this is what makes that true.
        scrub_data
        rm -rf "$DIR"
        mkdir -p "$DIR/data" "$DIR/src" "$DIR/scripts" "$DIR/ui"
        # The durable directory is left as `mkdir` made it: owned by the invoking user, 0755. The
        # generated `durable-init` service makes it writable by IRIS's own user before `iris`
        # starts, exactly as docker-compose.yml does, so on a Linux runner this bring-up is the
        # end-to-end proof of that service (DW-234).
        # Scratch copies, so a mutation made for a check never touches this repository's files.
        cp -R "$REPO_ROOT/src/." "$DIR/src/"
        cp -R "$REPO_ROOT/scripts/." "$DIR/scripts/"
        # The committed manifest, mounted so that OcuPilot.Test.Manifest's XML parse (DW-197)
        # actually RUNS rather than taking its "no manifest on this instance" skip. That class
        # reads /opt/ocupilot/module.xml, and neither this repository's own compose file nor an
        # earlier version of this script mounted it -- so the one assertion that reads the
        # manifest as a document skipped everywhere, including here, which is the vacuous pass
        # this story exists to remove. Copied rather than bind-mounted from the repository for
        # the reason the two above are.
        cp "$REPO_ROOT/module.xml" "$DIR/module.xml"
        if [ -d "$REPO_ROOT/ui/dist" ]; then
            mkdir -p "$DIR/ui/dist"
            cp -R "$REPO_ROOT/ui/dist/." "$DIR/ui/dist/"
        fi
        # The same rule as the durable directory, one mount over: these three are read-only to the
        # container, but uid 51773 still has to be able to read them, and `cp` reproduces the
        # invoking user's umask. Under the 022 a runner and a workstation both use they are already
        # world-readable; under an 077 the container would exit unable to read container-start.sh.
        chmod -R a+rX "$DIR/src" "$DIR/scripts" "$DIR/ui" "$DIR/module.xml"
        cat > "$COMPOSE_FILE" <<EOF
# GENERATED BY scripts/ci-throwaway.sh -- THROWAWAY ONLY, never this repository's docker-compose.yml
name: $PROJECT
services:
  iris:
    image: $IMAGE
    container_name: $PROJECT
    restart: on-failure:3
    depends_on:
      durable-init:
        condition: service_completed_successfully
    ports:
      - "$SUPER_PORT:1972"
      - "$WEB_PORT:52773"
    environment:
      ISC_DATA_DIRECTORY: /durable/iris
      OCUPILOT_DEMO: "1"
      $LOAD_TESTS_ENV
      # ARMING ROSTERS. Each block below carries one or more \`classes:\` lines naming, in
      # OcuPilot.Test.* short form, every class that declares that variable -- and nothing else
      # does. ui/tools/ci.test.mjs derives the same set from the declarations under
      # src/OcuPilot/Test/ and holds the two equal in both directions, so a class that gains or
      # loses an arming declaration reddens here rather than leaving a roster nobody re-read.
      # The derivation is structural (the arming Parameter, or an inline \$System.Util.GetEnviron),
      # never a substring scan: a variable named in a comment and not armed by it is not a
      # member, and counting one as a member is how a grep-shaped count came out wrong by one.
      # What is held equal is DECLARING the variable, not refusing on it: a fixture supplies the
      # destructive helper, declares the variable its callers refuse on, and holds no refusal of
      # its own (TurnWireFixture). Keeping a declared variable while deleting the refusal beside
      # it is a change these rosters cannot see -- scripts/check-objectscript.py's
      # destructive-test-guard rule reads that, but only for a class making a call it names.
      #
      # Rotates the instance's own messages.log, or writes a file beside it, or seeds the six
      # secondary log stores (Story 16.8). Set here and nowhere else: this container is
      # discarded, and the test refuses to run anywhere the variable is absent rather than
      # trusting a doc comment to keep it off a development instance.
      # classes: LogOlderFilesWire, LogSecondarySeed, LogSecondaryWire, LogSourceRotation
      # classes: LogHubWire
      OCUPILOT_ALLOW_LOG_ROTATION: "1"
      # Every class that creates or deletes IRIS principals, or the OAuth 2.0 configuration
      # objects handled the same way, or the instance's file-system access allow-list. Same
      # reasoning, same single home: test classes are selected
      # by package, so a runner pointed at an instance someone cares about would otherwise create
      # principals on it. scripts/check-objectscript.py's destructive-test-guard rule holds the
      # population. AuditCopy and AuditStarted also copy the instance's audit database into USER and empty USER's
      # audit globals, and AuditCopy's least-privilege leg sends a purge the route must refuse.
      # classes: TurnGrounding
      # classes: InjectionChannels, InjectionCompromised, InjectionSeed
      # classes: TurnSanitize
      # classes: SanitizeAuditMask
      # classes: Retention, TranscriptsWire
      # classes: GovernanceWire
      # classes: AccountPasswordWire, AgentConnectionRoles, AgentWireSecurity, AuditMarker, ConfigGate, CredentialPrivilege, DenialParity
      # classes: Disabled, ErrorDelete, ErrorLogDenial, LedgerWire, LogSourceDenial, MgmntPortDenial
      # classes: OAuthTabs
      # classes: TokenProbe, TokenRevoke
      # classes: OAuthServerCreate, OAuthServerDelete, OAuthServerDiscover, OAuthServerJwks, OAuthServerToken, OAuthServerUpdate, OAuthServerWire
      # classes: OAuthClientCreate, OAuthClientKeys, OAuthClientRegister, OAuthClientSecrets, OAuthClientUpdate, OAuthClientWire, AuditVendorSecrets
      # classes: OAuthResourceServerAuthenticator, OAuthResourceServerCreate, OAuthResourceServerMappings, OAuthResourceServerSecret, OAuthResourceServerUpdate, OAuthResourceServerWire, OAuthResourceServerAuditMask
      # classes: OAuthAuthorizationServerClients, OAuthAuthorizationServerCreate, OAuthAuthorizationServerKeys, OAuthAuthorizationServerSecret, OAuthAuthorizationServerUpdate, OAuthAuthorizationServerWire
      # classes: OAuthRegisteredClientCreate, OAuthRegisteredClientJwks, OAuthRegisteredClientSecret, OAuthRegisteredClientUpdate, OAuthRegisteredClientWire
      # classes: AuditCopy, AuditStarted
      # classes: DraftExecute
      # classes: ProcessControl, ProhibitedRoute, ProposalFixture, ProposalSpelling, State, Token
      # classes: ToolSetFull
      # classes: ToolWire, TurnContext, TurnConversation, TurnLong, TurnProviderFault, TurnWire
      # classes: AgentPickTurn, SqlAgentRead
      # classes: TurnStream
      # classes: WebAppWire
      # classes: UserCreateWire, RoleWire, ResourceWire, X509Wire, WalletWire, WalletKeyWire, DeviceWire, DeviceWriteGate
      # classes: UserSave, UserSignIn, WebAppSave, WebAppWeakening
      # classes: TurnWireFixture, UnexpireScope, UserUpdate, Version, Wire, WireOAuthRead, WireSecurityRead
      # classes: RoleSave, RoleUpdate, ReadBackRoute
      # classes: ImpactRoute
      # classes: SslWire
      # classes: TaskWire
      # classes: ServiceEdit, LdapEdit, ServiceLdapProbe
      # classes: AuditEventEditor
      # classes: UiPerformanceWire
      # classes: FindingsWire, GuardrailsWire
      # classes: LogHubWire, PathPort, PathPortInstance, PathPortPrivilege
      # classes: PathPortServed
      # classes: PermissionCheck, EffectiveUser
      # classes: LedgerSearchWire
      # classes: NamespaceWriteGate
      # The enable-interop gate class also enables interoperability on a probe namespace as its principal.
      # classes: NamespaceInteropGate
      # classes: ClassicPageGate, MappingWriteGate
      # classes: DatabaseRefusals, DatabaseWriteGate
      # classes: DatabaseActionsGate, DatabaseIntegrity
      # classes: WebSessionsLive
      # The Background tasks classes also create a scratch database and pause, resume and cancel a
      # compact of it; AdminPortForget runs the whole retention sweep.
      # classes: AdminPortForget, BackgroundSeed, BackgroundTasksLive
      # The 404 class creates and deletes a probe role through the real port and reads messages.log.
      # classes: AdminPortAbsence
      # The broadcast's live class also starts terminal sessions of its own and broadcasts to them.
      # classes: ProcessBroadcastLive
      # Task export and import's live class also exports and imports probe tasks as its principals.
      # classes: TaskTransferLive
      # The language server class also creates, starts, stops and deletes probe Java servers.
      # classes: LanguageServerWire
      # classes: WireAreaAnyScreen
      # The language server editor's class also creates, edits, starts, stops and deletes probe servers.
      # classes: LanguageServerEditorWire
      # The Task Manager classes also suspend, resume, stop and start the Task Manager and act on a
      # probe purge task as their principals.
      # classes: TaskManagerLive, TaskRowWire
      # The lock removal class also starts processes that hold probe locks and removes those locks.
      # classes: LockRemoveLive
      # The LDAP test class also tests authentication as a principal without the LDAP editor's pairs.
      # classes: LdapTest
      # classes: EgressLine
      # The source code API's denial class also makes one mapped code database's resource non-public
      # for its leg and restores it.
      # classes: AtelierPortDenial
      # The developer floor classes sign in as purpose-built principals: a %Developer, one below the
      # floor, an administrator without %All, and a %Development holder that runs a turn.
      # classes: DeveloperFloor, DeveloperFloorFixture, DeveloperFloorRoutes, DeveloperFloorTurn
      # The System Explorer write gate class signs in as principals holding READ, READ and WRITE,
      # and the %Developer role on a namespace's code database, and compiles and deletes probes.
      # classes: AtelierPortWriteDenial
      # The SQL catalog's live class signs in as a principal granted SELECT on one probe table
      # alone and reads the catalog as it (Story 19.5).
      # classes: AtelierPortCatalogLive
      # classes: AtelierPortCatalogTabsLive
      # The SQL console's probe signs in as principals granted SQL SELECT on one probe table alone,
      # without %Development:USE, and without READ on USER's database (Story 19.6).
      # classes: SqlConsoleProbe
      # The data browser's view-kinds class signs in as two principals granted SELECT on a probe view
      # alone, or on three of its columns (Story 19.7).
      # classes: SqlBrowseViewKinds
      # The remote database gate class signs in as probe principals holding the Remote databases
      # screens' pairs, with and without the system database's write (Story 18.16).
      # classes: RemoteDatabaseWriteGate
      # The journal classes sign in as probe principals holding Journals' pairs, with and without
      # the system database's write, and switch the journal as them (Story 18.5).
      # classes: JournalWrite, JournalWriteGate
      # The journal settings rules class also restricts the file selector's allow-list to reach
      # OcuPilot's served directory, as PathPortServed does, and restores it (Story 18.18).
      # classes: JournalSettingsRules
      # The journal record classes sign in as probe principals holding Journal records' pairs, with
      # and without read on their probe database, and list and open records as them (Story 18.19).
      # classes: JournalRecordDetail, JournalRecords
      # The license server gate class signs in as probe principals holding License servers' pairs,
      # with and without the system database's write, and writes probe license servers as them
      # (Story 18.6).
      # classes: LicenseWriteGate
      # The ECP data server gate class signs in as probe principals holding ECP data servers' pairs,
      # with and without the system database's write and %Admin_Operate, and writes probe data servers
      # and changes their status as them (Story 18.20).
      # classes: EcpWriteGate
      # The ECP settings gate class signs in as probe principals holding ECP settings' and ECP
      # application servers' pairs, with and without %Admin_Secure and the system database's write,
      # and saves the settings and deletes probe SSL/TLS names as them (Story 18.21).
      # classes: EcpSettingsGate
      # The encryption key file gate class signs in as probe principals holding Encryption key files'
      # pairs, with and without the file-system pair and %Admin_Manage, and reads and writes probe key
      # files as them (Story 18.7).
      # classes: EncryptionWriteGate
      # The encryption key gate class signs in as probe principals holding Security's pairs, with and
      # without the file-system pair and Security's resource, and activates and deactivates keys as
      # them through a seam port that sends neither (Story 18.22).
      # classes: EncryptionKeyGate
      # The encryption startup gate class signs in as probe principals holding Security's pairs, with
      # and without the file-system pair, Security's resource and the system database's read, and saves
      # the startup settings as them through a seam port that sends nothing (Story 18.23).
      # classes: EncryptionStartupGate
      # The document database gate class signs in as probe principals each missing one pair the DocDB
      # port requires, and lists, creates and drops a probe database as them (Story 19.17).
      # classes: DocDbGate
      # The authentication options gate class signs in as probe principals holding Security's pairs, and
      # each without one, and saves the options as them through a seam port that sends nothing (Story 18.8).
      # classes: AuthOptionsGate
      # The superserver gate class signs in as probe principals holding Security's pairs, and each
      # without one, and writes probe superservers as them through a seam port that sends nothing
      # (Story 18.25).
      # classes: SuperserverGate
      # The managed file transfer connection classes create and delete probe connections named OcuMftProbe,
      # the OAuth 2.0 client configurations and descriptions they name, and probe principals, and the gate
      # class writes them as principals holding Security's pairs and each without one (Story 18.26).
      # classes: MftConnectionGate, MftConnectionRead, MftConnectionWrite
      # The SQL object privilege classes create and remove a probe user and role named OcuSqlPrivProbe and a probe
      # schema's objects in USER, set up privileges as the running account, and the gate class writes them as
      # principals holding Security's pairs and each without one (Story 18.9).
      # classes: SqlPrivilegeGate, SqlPrivilegeRead, SqlPrivilegeWrite
      # The SQL activity gate class signs in as probe principals each missing one pair the SQL
      # activity port requires, or holding READ on USER's database and %Development, and reads
      # another account's running probe statement as them (Story 19.10).
      # classes: SqlActivityGate, SqlActivityProbe
      # The interoperability control class compiles and runs a probe production in USER and starts,
      # stops, restarts, updates and recovers it; its descriptor class compiles the probe classes in USER;
      # its gate class signs in as probe principals each
      # missing one pair the interoperability port requires and reads and controls the probe as them
      # (Story 20.2).
      # classes: InteropControl, InteropDescriptor, InteropGate
      OCUPILOT_ALLOW_PRINCIPALS: "1"
      # Writes an application error to a namespace's own ^ERRORS. Same reasoning again, and one
      # degree worse: an application error cannot be un-logged, so a runner pointed elsewhere
      # would leave it there.
      # classes: DraftExecute, ErrorDelete, ErrorLogSeed, ProviderSecret, ProviderStub, ProviderStubTransport
      # classes: DemoErrorSeed
      # classes: SecretLeak, SecretStoreProbe
      # It also covers the seeded injection's append-only messages.log line and failed-login audit row.
      # classes: InjectionChannels, InjectionCompromised, InjectionSeed
      # classes: LogHubErrors
      OCUPILOT_ALLOW_ERROR_SEED: "1"
      # Deletes OcuPilot's own audit event registrations to prove an unregistered triple drops
      # its row, then reinstalls to put them back -- the configuration triple, and the BASELINE
      # RoleGranted triple every install registers. One degree worse again: while a registration
      # is gone every row OcuPilot would write under that triple is dropped with no error and no
      # log line, so a runner pointed at an instance someone cares about would silently stop
      # auditing it. AuditMarker deletes the AgentWrite triple for the same reason and creates a
      # web application to write to, so it declares OCUPILOT_ALLOW_PRINCIPALS as well.
      # classes: AuditEvent, AuditMarker, UninstallSurvival
      # classes: AuditEventEditor
      OCUPILOT_ALLOW_AUDIT_EVENTS: "1"
      # Runs OcuPilot's PRODUCTION install. A production install is not one side effect but a
      # whole set of them -- a database, a resource, a role, three web applications, the audit
      # registrations and the _SYSTEM unexpire -- which is why it has a variable of its own
      # rather than riding on a narrower one. Every class that runs it refuses on this variable,
      # whatever else arms it; scripts/check-objectscript.py's destructive-test-guard rule holds
      # that. Consequence, stated plainly: the classes below run here and on CI, never on a
      # development container someone cares about.
      # classes: AuditRecord, AuditVerbs, DefinitionDefaults, DemoOptIn, GatewayGapIpmPath, GrantReadBack
      # classes: IdentityInstall, InstallNamespaceSource, Installer, Manifest, Provenance, Static
      # classes: UninstallGuard, UninstallResidue, UninstallSurvival, WebApp
      # classes: AuditEvent, AuditMarker, ConfigGate, State, Token, UnexpireScope, Version, Wire
      # classes: RetentionTask
      OCUPILOT_ALLOW_PRODUCTION_INSTALL: "1"
      # Runs the installer's EnsureSslConfiguration step under the probe profile and so creates
      # -- and leaves -- a TLS configuration in the instance's own security database. Same
      # reasoning as the blocks above: a runner pointed at an instance someone cares about would
      # otherwise add a security object to it. The demo fixture's classes create and remove its
      # TLS configuration, X.509 credential and wallet collection, and the SSL/TLS editor's
      # classes create and delete probe configurations by exact name, for the same reason.
      # classes: ProviderSsl
      # classes: Demo, DemoFaults, FixtureNamespace, SslSave, SslSecret, SslTest
      # classes: SslWire
      OCUPILOT_ALLOW_SSL_CONFIG: "1"
      # Turns the instance's own auditing OFF and back on through the shipped confirm path, which
      # is the widest effect any class here has: while it is off nothing on this instance is
      # audited at all, not only OcuPilot's own events. Its own variable rather than riding on
      # OCUPILOT_ALLOW_AUDIT_EVENTS, which deletes a registration and leaves the channel open.
      # Each class restores auditing in an in-method frame and asserts the restore in its
      # teardown, so a run that aborts mid-sequence still leaves this instance audited.
      # ProhibitedRoute confirms one real disable as a least-privileged principal (AD-29), so it
      # declares this variable as well as OCUPILOT_ALLOW_PRINCIPALS.
      # classes: AuditingUpdate, ProhibitedRoute
      OCUPILOT_ALLOW_AUDIT_TOGGLE: "1"
      # Suspends and resumes a REAL process on this instance through the shipped confirm path.
      # A suspended process holds every lock and open transaction it had, so a runner pointed at
      # an instance someone cares about could stop work nobody there asked to stop. The class
      # JOBs its own probe process, never a daemon, the Task Manager, a Work Queue worker or
      # WRTDMN, and halts it on every exit path.
      # classes: ProcessControl
      OCUPILOT_ALLOW_PROCESS_CONTROL: "1"
      # Creates a task in this instance's Task Manager and resumes it. Same reasoning as the
      # block above, one degree narrower: the effect is a task that runs where nobody scheduled
      # one. OcuPilot.Test.TaskResume shipped in Story 5.11 without a guard (DW-1458); this is
      # that guard's home. The New Task wizard's classes create probe tasks and delete each by
      # id once its exact name reads back. Edit task's classes edit and run their own probe tasks,
      # never a vendor task.
      # classes: TaskResume
      # classes: TaskCreate, TaskRules, TaskSave, TaskWire
      # classes: TaskUpdate, TaskEdit
      # classes: InjectionChannels, InjectionCompromised, InjectionSeed
      # Task export and import's classes export probe tasks to files under the first allowed
      # directory and import them back, then delete every task named OcuP164* and that directory.
      # classes: TaskTransfer, TaskTransferLive
      # The Task Manager classes suspend, resume, stop and start this instance's Task Manager and
      # restore it running as TASKMGR on every exit; the row class suspends, resumes and deletes a
      # probe purge task it creates, never running it.
      # classes: TaskManagerLive, TaskRowWire
      OCUPILOT_ALLOW_TASK_CONTROL: "1"
      # Deletes REAL application errors from a namespace's own ^ERRORS through the shipped confirm
      # path. One degree worse than OCUPILOT_ALLOW_ERROR_SEED above, which can only add: a deleted
      # application error is gone, and the variable table it captured with it, so a runner pointed
      # at an instance someone cares about would destroy the record of a fault nobody had read yet.
      # The class seeds every error it removes and clears its own namespace on exit; it declares
      # OCUPILOT_ALLOW_ERROR_SEED as well, because it seeds through that class's own guarded helper.
      # DemoErrorSeed deletes the demo fixture's own entries from the install namespace and leaves
      # one present when it finishes.
      # classes: DraftExecute, ErrorDelete
      # classes: DemoErrorSeed
      # classes: InjectionChannels, InjectionCompromised, InjectionSeed
      OCUPILOT_ALLOW_ERROR_DELETE: "1"
      # Writes a service and LDAP configurations in this instance's own security database through
      # the shipped Save and confirm paths. The service classes write only %Service_CallIn, which is
      # disabled, and restore the snapshot they took; they refuse outright where it is enabled. The
      # LDAP classes create ocup99* configurations and delete each once its exact name reads back.
      # The service OcuPilot is served through is never written: its legs mint only, or save
      # through a port that records a PUT and never sends it.
      # Since Story 16.13 ServiceEdit also writes %Service_CacheDirect and %Service_ECP, each disabled, snapshotted and restored the same way.
      # classes: ServiceEdit, LdapEdit, LdapUpdate, ServiceLdapProbe
      # Since Story 16.14 the LDAP classes also create configurations through the editor's Save and the agent's create, set and clear their search password, delete them, and test authentication against 127.0.0.1:1.
      # classes: LdapCreate, LdapPassword, LdapTest
      # Since Story 19.17 the document database classes enable %Service_DocDB, which a stock instance
      # keeps disabled, and put it back as they found it after every test; they create and drop probe
      # databases named OcuProbe1917* in USER and remove each by name.
      # classes: DocDbProbe, DocDbPort, DocDbGate, DocDbWrite
      # Since Story 18.8 the authentication options class saves and confirms the instance's authentication
      # and web session options -- a login cookie timeout and an unchanged Kerberos flag sent for real, and the
      # SMTP password set and cleared -- and restores every value it read first. Every sign-in, start or token
      # change goes only to a seam port that records it and never sends it.
      # classes: AuthOptionsWrite
      # Since Story 18.25 the superserver class creates, changes and deletes probe superservers on 21825 to
      # 21829 only, each removed by exact port, and sets the governance policy it restores. The system
      # default superserver is never written: any other port goes only to a seam that refuses it.
      # classes: SuperserverWrite
      OCUPILOT_ALLOW_SERVICE_CONFIG: "1"
      # Arms the turnprobe provider row OcuPilot.Kernel.Provider.Catalog resolves only under it,
      # and with it the classes that spawn turn jobs or Test connection children against that row's
      # scripted adapter. Either is a separate process no in-process stub reaches, so the row is
      # armed by the environment, and only here.
      # classes: TurnGrounding
      # classes: TurnStream
      # classes: AgentConnectionBound, AgentConnectionRoles, AgentConnectionWire, LedgerWire, ToolWire, TurnChain
      # classes: TurnContext, TurnConversation, TurnLong, TurnProviderFault, TurnStore
      # classes: TurnWire, TurnWireFixture
      # classes: InjectionChannels, InjectionCompromised
      # classes: TurnSanitize
      # classes: SanitizeAuditMask
      # classes: EgressLine
      # classes: DeveloperFloorTurn
      # classes: AgentPickTurn, SqlAgentRead
      OCUPILOT_ALLOW_TEST_PROVIDER: "1"
      # Purges the instance's own audit database through the shipped screen route: every record
      # dated before today is removed, the agent's audit markers among them, and nothing puts one
      # back. Its own variable because no narrower one names that effect. The purge leg of
      # ui/browser/audit-copy-purge.browser-spec.mjs has the same effect and runs only against this
      # container, which its own assertThrowaway checks.
      # classes: AuditPurge
      OCUPILOT_ALLOW_AUDIT_PURGE: "1"
      # Clears the suite's own HTTP account's favorites, recents and remembered views through the
      # shipped preferences route and its store. Its own variable because no narrower one names
      # that effect: a runner pointed at an instance someone uses would empty that account's lists.
      # classes: PreferencesWire
      OCUPILOT_ALLOW_ACCOUNT_PREFERENCES: "1"
      # Creates, edits and deletes namespaces in this instance's own configuration, with the web
      # applications bound to them and a global mapping, through the shipped Save, row-action and
      # confirm paths. Its own variable because no narrower one names that effect: a namespace delete
      # removes every web application bound to it, so a runner pointed at an instance someone cares
      # about could take applications nobody there asked to lose. The classes touch only OCUPROBE182*
      # namespaces and /csp/ocuprobe182* applications, each by exact name, and write to the install
      # namespace and %SYS only through a port that sends nothing. It also adds, changes, removes
      # and copies OCUPROBE1814* mappings between OCUPROBE1814* namespaces, and assigns a probe
      # custom resource to the classic namespace and mapping pages, restoring each.
      # classes: NamespaceRefusals, NamespaceWrite, NamespaceWriteGate
      # classes: ClassicPageGate, MappingCodeGlobals, MappingRefusals, MappingWrite, MappingWriteGate, NamespaceCopy
      # It also enables interoperability on OCUPROBE1815* namespaces over its own OCUPROBE1815D
      # database and restores what the vendor's enable changes instance-wide, each object by its exact
      # name, writing %SYS security objects, tasks and ^%SYS nodes directly to do so.
      # classes: NamespaceInterop, NamespaceInteropGate
      OCUPILOT_ALLOW_NAMESPACE_CONFIG: "1"
      # Creates, edits and deletes database configurations and database files in this instance's own
      # configuration, with the %DB_* resources and directories a create makes, through the shipped
      # Save, row-action and confirm paths. Its own variable because no narrower one names that
      # effect: a database delete with its file removes data. The classes touch only OCUPROBE183*
      # databases, %DB_OCUPROBE183* resources and <mgr>ocuprobe183* directories, each by exact
      # name, with the probe namespaces, mapping and /csp/ocuprobe183* applications and the
      # OCUPROBE183SRV data server they create, and write to the instance's own databases only
      # through a port that sends nothing.
      # classes: DatabaseRefusals, DatabaseWrite, DatabaseWriteDetail, DatabaseWriteGate, PathPortDatabases
      # It also mounts, dismounts, truncates, compacts, defragments, grows, adds volumes to and
      # checks the integrity of OCUPROBE184* databases, removing their background tasks and
      # integrity checks by probe directory (Story 18.4).
      # classes: DatabaseActions, DatabaseActionsGate, DatabaseActionsProhibited, DatabaseGrowExpand, DatabaseIntegrity
      # It also defines OCUPROBE1816* ECP data servers, configuration only and never contacted, and
      # creates, re-points and deletes OCUPROBE1816* remote database configurations, with a local
      # probe database, a namespace and a mapping over them (Story 18.16).
      # classes: RemoteDatabaseDescriptor, RemoteDatabaseListing, RemoteDatabaseWrite, RemoteDatabaseWriteGate
      # It also creates and removes the OCUPROBE185D database, with its %DB_OCUPROBE185D resource and
      # <mgr>ocuprobe185d directory, and writes journaled records into it (Story 18.19).
      # classes: JournalRecordDetail, JournalRecords
      # It also creates and removes the OCUPROBEECPR remote database configuration on an OCUPROBEECP*
      # ECP data server, configuration only and never contacted (Story 18.20).
      # classes: EcpDataServerWrite
      OCUPILOT_ALLOW_DATABASE_CONFIG: "1"
      # Switches this instance's journal file and journal directory through the shipped screen and
      # confirm paths, and seeds an alternate journal directory to switch into. Its own variable
      # because no narrower one names that effect: a switch closes the file every process is
      # writing. Each class restores the current directory, the primary and the alternate it
      # found and asserts the restore; the journal files a switch creates stay (Story 18.5).
      # classes: JournalWrite, JournalWriteGate, PathPortInstance
      # JournalRead, JournalIntegrity, JournalWrite and JournalWriteGate before their tests, and
      # AdminPortAsync in its journal check, also switch the journal file where the list names no
      # closed file, to close one (OcuPilot.Test.JournalProbe.EnsureClosedFile).
      # classes: AdminPortAsync, JournalIntegrity, JournalRead
      # Journal settings' classes also change this instance's journal settings through the shipped
      # Save and confirm paths, and restore every setting they found (Story 18.18).
      # classes: JournalSettingsRules, JournalSettingsWrite
      OCUPILOT_ALLOW_JOURNAL: "1"
      # Creates, edits and deletes license servers in this instance's own configuration through the
      # shipped Save, row-action and confirm paths. Its own variable because no narrower one names
      # that effect: a license server entry tells the instance where to ask for license units. The
      # classes touch only OCUPROBE186* servers, each by exact name, and never change the license
      # key: the activation reaches only a seam port that sends nothing (Story 18.6).
      # classes: LicenseServerWrite, LicenseWriteGate
      OCUPILOT_ALLOW_LICENSE_CONFIG: "1"
      # Creates, edits and deletes ECP data servers in this instance's own configuration, and changes
      # their status to Disabled and back to Not Connected, through the shipped Save, row-action and
      # confirm paths. Its own variable because no narrower one names that effect: a data server entry
      # tells the instance where to connect as an ECP application server. The classes touch only
      # OCUPROBEECP* servers at a TEST-NET-1 address, each by exact name, open no ECP connection, and
      # never send Action 3: Normal reaches only a seam port that sends nothing (Story 18.20).
      # classes: EcpDataServerStatus, EcpDataServerWrite, EcpWriteGate
      # The settings classes change the ECP settings and restore them, sending every MaxServerConn
      # change and every SSL/TLS one only to a seam port that sends nothing; the SSL/TLS classes
      # authorize and delete OCUPROBEECP* SSL/TLS names and seed a marked %ECPClient (Story 18.21).
      # classes: EcpSettingsGate, EcpSettingsWrite, EcpSslConnectionWrite
      OCUPILOT_ALLOW_ECP_CONFIG: "1"
      # Creates encryption key files under the probe directory <ManagerDirectory>ocuprobe187/, adds and
      # removes their administrators and keys through the shipped Save, row-action and confirm paths,
      # and removes the directory. Its own variable because no narrower one names that effect: a key
      # file holds an encryption key the instance could activate. The classes never activate or
      # deactivate a key, change no encryption setting and touch no file outside that directory
      # (Story 18.7).
      # classes: EncryptionKeyFileRead, EncryptionKeyFileWrite, EncryptionWriteGate
      # Story 18.22's classes create key files under <ManagerDirectory>ocuprobeact/ the same way, and
      # activate and deactivate keys only through a seam port that sends neither; the one activation
      # sent to the vendor carries a wrong password, which it refuses before activating anything.
      # classes: EncryptionKeyGate, EncryptionKeyWrite
      # Story 18.23's class creates key files under <ManagerDirectory>ocuprobestart/ the same way, sends
      # every startup setting change only to a seam port that sends nothing, and sends the vendor one
      # Settings PUT of the settings unchanged.
      # classes: EncryptionStartupWrite
      OCUPILOT_ALLOW_ENCRYPTION_CONFIG: "1"
    volumes:
      - $DIR/data:/durable
      - $DIR/src:/opt/ocupilot/src:ro
      - $DIR/scripts:/opt/ocupilot/scripts:ro
      - $DIR/ui:/opt/ocupilot/ui:ro
      - $DIR/module.xml:/opt/ocupilot/module.xml:ro
    command: ["--after", "sh /opt/ocupilot/scripts/container-start.sh"]
    healthcheck:
      test: ["CMD", "sh", "/opt/ocupilot/scripts/container-health.sh"]
      interval: 10s
      timeout: 15s
      retries: 30
      start_period: 60s

  durable-init:
    image: $IMAGE
    user: "0:0"
    entrypoint: ["sh", "/opt/ocupilot/scripts/durable-init.sh"]
    restart: "no"
    volumes:
      - $DIR/data:/durable
      - $DIR/scripts:/opt/ocupilot/scripts:ro
EOF
        echo "ci-throwaway: wrote $COMPOSE_FILE ($IMAGE, web $WEB_PORT, superserver $SUPER_PORT)"
        # The bring-up, retried a BOUNDED number of times and ONLY on a host-port bind (DW-439).
        #
        # 52776 sits inside the ephemeral range a Linux runner allocates outbound source ports
        # from -- the kernel default is 32768-60999 -- so an outbound connection opened by
        # anything else on the box can hold it when compose asks for it, a failure that is over in
        # seconds and is not about this container at all. 1975 is an order of magnitude below that
        # floor and cannot be taken that way; a bind failure there is another listener, which the
        # same retry survives only if that listener goes away. Moving the ports is not the fix:
        # 52776/1975 are written into CLAUDE.md, _bmad/custom/parallel.yaml and every parallel
        # runner's spawn prompt.
        #
        # Every other failure exits at once. A retry loop that swallows "the image is not
        # available" or "the install failed" turns one clear error into three and then a
        # misleading one about a port.
        #
        # The bring-up is STREAMED, not captured: the first start takes several minutes, and a
        # `--wait` that hangs until the job is cancelled printed nothing at all under a captured
        # bring-up -- the exact situation DW-439 exists for. POSIX sh has no PIPESTATUS, so the
        # exit code goes to a file inside the pipeline and is read back beside the text.
        UP_OUTPUT_FILE="$DIR/up-output.txt"
        UP_RC_FILE="$DIR/up-rc.txt"
        ATTEMPT=1
        while : ; do
            # Cleared first: the exit code is written from inside the pipeline, so if that write
            # never happens -- the left side killed, the file unwritable -- `cat` would otherwise
            # read whatever an earlier attempt or an earlier run of this script left behind, and a
            # stale `0` reads as a bring-up that succeeded. Absent, it reads empty, which is not
            # "0" and takes the failure path.
            rm -f "$UP_RC_FILE"
            { docker compose -f "$COMPOSE_FILE" up -d --wait 2>&1; echo "$?" > "$UP_RC_FILE"; } | tee "$UP_OUTPUT_FILE"
            if [ "$(cat "$UP_RC_FILE" 2>/dev/null)" = "0" ]; then break; fi
            UP_OUTPUT=$(cat "$UP_OUTPUT_FILE")
            case "$UP_OUTPUT" in
                *"address already in use"*|*"port is already allocated"*|*"ports are not available"*|*"Bind for "*) ;;
                *)
                    echo "ci-throwaway: the bring-up failed for a reason that is not a host-port bind; not retried"
                    exit 1
                    ;;
            esac
            if [ "$ATTEMPT" -ge "$BIND_ATTEMPTS" ]; then
                echo "ci-throwaway: host port $WEB_PORT (or superserver $SUPER_PORT) was still bound after $BIND_ATTEMPTS attempt(s); this runner's ephemeral port range is $(ephemeral_range), which bears on $WEB_PORT -- $SUPER_PORT is below any default range's floor, so a bind failure there is another listener"
                exit 1
            fi
            echo "ci-throwaway: host port $WEB_PORT is bound; removing this project's containers and retrying (attempt $ATTEMPT of $BIND_ATTEMPTS)"
            docker compose -f "$COMPOSE_FILE" down -v || true
            if [ "$BIND_RETRY_SECONDS" -gt 0 ]; then sleep $((BIND_RETRY_SECONDS * ATTEMPT)); fi
            ATTEMPT=$((ATTEMPT + 1))
        done
        docker compose -f "$COMPOSE_FILE" ps
        ;;
    logs)
        # The failure-path capture, run before the teardown and only when something already
        # failed. In run 34773637146 the failing step printed one line -- `container ocupilot-ci
        # is unhealthy` -- and the cause reached the job only because the NEXT step, the teardown,
        # happens to print `logs | tail -n 80` of one service before removing everything. That is
        # the evidence surviving by luck twice over: under a step whose name says nothing about
        # it, and only because the container failed early enough to still be inside the last 80
        # lines. This prints the state of every container the throwaway created and its whole
        # log, under a step named for the job it does.
        if [ ! -f "$COMPOSE_FILE" ]; then
            echo "ci-throwaway: no compose file at $COMPOSE_FILE; nothing was brought up"
            exit 0
        fi
        # `|| true` on the cheap half only: under `set -e` a non-zero `ps -a` would abort the
        # capture before the log -- the half that is actually being captured -- ever printed.
        docker compose -f "$COMPOSE_FILE" ps -a || true
        docker compose -f "$COMPOSE_FILE" logs --no-color --timestamps
        ;;
    product-check)
        # What a product start (`up --product`) compiled, counted in the install namespace --
        # HSCUSTOM when it exists, else USER, as container-start.sh resolves it with no override.
        # It passes only when OcuPilot classes are compiled there and none is OcuPilot.Test.*
        # (AD-17). No OcuPilot class at all is a failure: zero test classes in a namespace nothing
        # was installed into proves nothing.
        if [ ! -f "$COMPOSE_FILE" ]; then
            echo "ci-throwaway: no compose file at $COMPOSE_FILE; nothing was brought up to check"
            exit 1
        fi
        RAW=$(docker compose -f "$COMPOSE_FILE" exec -T iris iris session iris -U %SYS 2>&1 <<'EOF'
Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",##class(%SYS.Namespace).Exists("USER"):"USER",1:"")
Set $NAMESPACE=$Select(tNS="":$NAMESPACE,1:tNS)
Set tAll=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) FROM %Dictionary.CompiledClass WHERE %EXACT(ID) %STARTSWITH ?","OcuPilot.")
Set tTests=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) FROM %Dictionary.CompiledClass WHERE %EXACT(ID) %STARTSWITH ?","OcuPilot.Test.")
Write "OCUPILOT-"_"PRODUCT-START:"_tNS_":"_$Select(tAll.%Next():tAll.%GetData(1),1:"")_":"_$Select(tTests.%Next():tTests.%GetData(1),1:"")_":OCUPILOT-"_"PRODUCT-END",!
Halt
EOF
) || { echo "ci-throwaway: could not open a session in the throwaway's iris service"; printf '%s\n' "$RAW" | tail -n 20; exit 1; }
        PRODUCT=$(printf '%s' "$RAW" | tr '\r\n' '  ' | grep -o 'OCUPILOT-PRODUCT-START:.*:OCUPILOT-PRODUCT-END' | sed -e 's/^OCUPILOT-PRODUCT-START://' -e 's/:OCUPILOT-PRODUCT-END$//')
        NS=$(printf '%s' "$PRODUCT" | cut -d: -f1)
        ALL=$(printf '%s' "$PRODUCT" | cut -d: -f2)
        TESTS=$(printf '%s' "$PRODUCT" | cut -d: -f3)
        case "$ALL:$TESTS" in
            :*|*:|*[!0-9:]*)
                echo "ci-throwaway: the throwaway did not answer how many classes its start compiled"
                printf '%s\n' "$RAW" | tail -n 20
                exit 1
                ;;
        esac
        echo "ci-throwaway: $NS holds $ALL compiled OcuPilot class(es), $TESTS of them OcuPilot.Test.*"
        if [ "$ALL" -lt 1 ]; then
            echo "ci-throwaway: no OcuPilot class is compiled in '$NS', so its count of test classes proves nothing"
            exit 1
        fi
        if [ "$TESTS" -ne 0 ]; then
            echo "ci-throwaway: a product start compiled $TESTS OcuPilot.Test class(es); it must compile none (AD-17)"
            exit 1
        fi
        echo "ci-throwaway: the product start compiled no OcuPilot.Test class"
        ;;
    product-reuse)
        # A product start over a volume that already holds compiled test classes (DW-1885). The
        # throwaway's own start must have logged deleting 0 classes; then two classes are compiled
        # into the install namespace's OcuPilot.Test package, one a direct member and one in a
        # subpackage, the iris service is recreated over the same volume, so its start hook runs
        # again as a product start, and that start's log must say it deleted 2 classes;
        # `product-check` then counts none. A throwaway that sets OCUPILOT_LOAD_TESTS is refused,
        # since its start compiles the package.
        if [ ! -f "$COMPOSE_FILE" ]; then
            echo "ci-throwaway: no compose file at $COMPOSE_FILE; nothing was brought up to start again"
            exit 1
        fi
        if grep -q 'OCUPILOT_LOAD_TESTS' "$COMPOSE_FILE"; then
            echo "ci-throwaway: $COMPOSE_FILE sets OCUPILOT_LOAD_TESTS, so its start compiles the test package rather than deleting it; bring the throwaway up with --product"
            exit 1
        fi
        DELETED_LINE="container-start: OCUPILOT_LOAD_TESTS is not 1, so this start deleted"
        LOG=$(docker compose -f "$COMPOSE_FILE" logs --no-color iris 2>&1) || { echo "ci-throwaway: could not read the log of the throwaway's start"; exit 1; }
        if ! printf '%s\n' "$LOG" | grep -F -q "$DELETED_LINE 0 class(es) of the roster's test-scope package"; then
            echo "ci-throwaway: the throwaway's own start did not log deleting 0 classes of the test package"
            printf '%s\n' "$LOG" | grep 'container-start:' | tail -n 20
            exit 1
        fi
        RAW=$(docker compose -f "$COMPOSE_FILE" exec -T iris iris session iris -U %SYS 2>&1 <<'EOF'
Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",##class(%SYS.Namespace).Exists("USER"):"USER",1:"")
Set $NAMESPACE=$Select(tNS="":$NAMESPACE,1:tNS)
Set tSC=$Select(tNS="":$System.Status.Error(5001,"neither HSCUSTOM nor USER exists"),1:##class(%Dictionary.ClassDefinition).%New("OcuPilot.Test.PlantedProbe").%Save())
Set tSC=$Select($System.Status.IsOK(tSC):##class(%Dictionary.ClassDefinition).%New("OcuPilot.Test.Planted.Probe").%Save(),1:tSC)
Set tSC=$Select($System.Status.IsOK(tSC):$System.OBJ.Compile("OcuPilot.Test.PlantedProbe,OcuPilot.Test.Planted.Probe","ck-d"),1:tSC)
Write "OCUPILOT-"_"PLANT-START:"_$Select($System.Status.IsOK(tSC):"OK:"_(##class(%Dictionary.CompiledClass).%ExistsId("OcuPilot.Test.PlantedProbe")+##class(%Dictionary.CompiledClass).%ExistsId("OcuPilot.Test.Planted.Probe")),1:"FAILED:"_$System.Status.GetErrorText(tSC))_":OCUPILOT-"_"PLANT-END",!
Halt
EOF
) || { echo "ci-throwaway: could not open a session in the throwaway's iris service"; printf '%s\n' "$RAW" | tail -n 20; exit 1; }
        PLANT=$(printf '%s' "$RAW" | tr '\r\n' '  ' | grep -o 'OCUPILOT-PLANT-START:.*:OCUPILOT-PLANT-END' | sed -e 's/^OCUPILOT-PLANT-START://' -e 's/:OCUPILOT-PLANT-END$//')
        if [ "$PLANT" != "OK:2" ]; then
            echo "ci-throwaway: could not compile two classes into the test package to start over (${PLANT:-no answer})"
            printf '%s\n' "$RAW" | tail -n 20
            exit 1
        fi
        echo "ci-throwaway: compiled OcuPilot.Test.PlantedProbe and OcuPilot.Test.Planted.Probe; starting the throwaway again over the same volume"
        docker compose -f "$COMPOSE_FILE" up -d --wait --force-recreate --no-deps iris || { echo "ci-throwaway: the throwaway did not come back healthy over the reused volume"; exit 1; }
        LOG=$(docker compose -f "$COMPOSE_FILE" logs --no-color iris 2>&1) || { echo "ci-throwaway: could not read the log of the start over the reused volume"; exit 1; }
        if ! printf '%s\n' "$LOG" | grep -F -q "$DELETED_LINE 2 class(es) of the roster's test-scope package"; then
            echo "ci-throwaway: the start over the reused volume did not log deleting the two classes compiled into the test package"
            printf '%s\n' "$LOG" | grep 'container-start:' | tail -n 20
            exit 1
        fi
        echo "ci-throwaway: the start over the reused volume deleted the two test classes compiled before it"
        ;;
    data-check)
        # Every mounted local database directory still holds its IRIS.DAT. A host cleaner that
        # prunes the data directory leaves the instance running against files that are gone, and
        # nothing else says so. One %SYS session reads SYS.Database:List; a row counts when its
        # status starts with "Mounted" and its directory is a local path. No databases listed is
        # a failure, since an empty list proves nothing.
        if [ ! -f "$COMPOSE_FILE" ]; then
            echo "ci-throwaway: no compose file at $COMPOSE_FILE; nothing was brought up to check"
            exit 1
        fi
        RAW=$(docker compose -f "$COMPOSE_FILE" exec -T iris iris session iris -U %SYS 2>&1 <<'EOF'
Set tRS=##class(%ResultSet).%New("SYS.Database:List")
Set tSC=tRS.Execute("*")
Set tN=0,tMissing=""
If tSC { While tRS.Next() { Set tDir=tRS.GetData(1),tStatus=tRS.GetData(4) If ($Extract(tStatus,1,7)="Mounted")&&($Extract(tDir,1)="/") { Set tN=tN+1,tFile=##class(%File).NormalizeDirectory(tDir)_"IRIS.DAT" If ##class(%File).Exists(tFile)=0 Set tMissing=tMissing_$Select(tMissing="":"",1:";")_tDir } } }
Write "OCUPILOT-"_"DATCHECK-START:"_tN_":"_tMissing_":OCUPILOT-"_"DATCHECK-END",!
Halt
EOF
) || { echo "ci-throwaway: could not open a session in the throwaway's iris service"; printf '%s\n' "$RAW" | tail -n 20; exit 1; }
        DATA=$(printf '%s' "$RAW" | tr '\r\n' '  ' | grep -o 'OCUPILOT-DATCHECK-START:.*:OCUPILOT-DATCHECK-END' | sed -e 's/^OCUPILOT-DATCHECK-START://' -e 's/:OCUPILOT-DATCHECK-END$//')
        COUNT=$(printf '%s' "$DATA" | cut -d: -f1)
        MISSING=$(printf '%s' "$DATA" | cut -d: -f2-)
        case "$COUNT" in
            ""|*[!0-9]*)
                echo "ci-throwaway: the throwaway did not answer which of its databases hold an IRIS.DAT"
                printf '%s\n' "$RAW" | tail -n 20
                exit 1
                ;;
        esac
        if [ "$COUNT" -lt 1 ]; then
            echo "ci-throwaway: the throwaway listed no mounted local database, so a check of their files proves nothing"
            exit 1
        fi
        if [ -n "$MISSING" ]; then
            echo "ci-throwaway: a mounted database has no IRIS.DAT in: $MISSING"
            exit 1
        fi
        echo "ci-throwaway: all $COUNT mounted local database(s) hold their IRIS.DAT"
        ;;
    down)
        if [ -f "$COMPOSE_FILE" ]; then
            docker compose -f "$COMPOSE_FILE" logs --no-color iris | tail -n 80 || true
            docker compose -f "$COMPOSE_FILE" down -v
        else
            # compose.yml is gone (a host cleaner pruned it) but the container may still be up.
            # Compose is asked to remove the project only when it lists this project from this
            # directory's own compose file; any other listing is someone else's throwaway.
            listed=$(docker compose ls -a --format json 2>/dev/null | tr -d '\n' | grep -o "{[^}]*\"Name\":\"$PROJECT\"[^}]*}" || true)
            if [ -n "$listed" ] && printf '%s' "$listed" | grep -q "\"ConfigFiles\":\"$COMPOSE_FILE\""; then
                # From /, so Compose loads no compose file from the working directory or above it.
                (cd / && docker compose -p "$PROJECT" down -v --remove-orphans)
            elif [ -n "$listed" ]; then
                echo "ci-throwaway: no compose file at $COMPOSE_FILE and Compose lists '$PROJECT' from a different config file; no Compose call made"
            else
                echo "ci-throwaway: no compose file at $COMPOSE_FILE and Compose does not list '$PROJECT'; no Compose call made"
            fi
        fi
        scrub_data
        rm -rf "$DIR"
        echo "ci-throwaway: removed $DIR"
        ;;
    *)
        echo "ci-throwaway: usage: ci-throwaway.sh up|logs|product-check|product-reuse|data-check|down [options]"
        exit 2
        ;;
esac
