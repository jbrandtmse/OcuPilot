#!/bin/sh
# Write, start and tear down the THROWAWAY container CI's instance job runs against
# (Story 1.17; README.md's "Verifying the start path against a throwaway container").
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
# Usage:
#   sh scripts/ci-throwaway.sh up    [--dir DIR] [--project NAME] [--web 52776] [--super 1975]
#   sh scripts/ci-throwaway.sh logs  [--dir DIR]
#   sh scripts/ci-throwaway.sh down  [--dir DIR] [--project NAME]
set -e

ACTION="${1:-}"
shift 2>/dev/null || true

DIR="${OCUPILOT_THROWAWAY_DIR:-/tmp/ocupilot-ci}"
PROJECT="ocupilot-ci"
WEB_PORT="52776"
SUPER_PORT="1975"
IMAGE="intersystems/irishealth-community:2026.2"
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)

while [ $# -gt 0 ]; do
    case "$1" in
        --dir) DIR="$2"; shift 2 ;;
        --project) PROJECT="$2"; shift 2 ;;
        --web) WEB_PORT="$2"; shift 2 ;;
        --super) SUPER_PORT="$2"; shift 2 ;;
        --image) IMAGE="$2"; shift 2 ;;
        *) echo "ci-throwaway: unknown argument $1"; exit 2 ;;
    esac
done

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
# Scratch roots only, and never the root of one.
case "$DIR" in
    /tmp/?*|/private/tmp/?*|"${TMPDIR:-/nonexistent-tmpdir}"?*) ;;
    *) echo "ci-throwaway: '$DIR' is not under a scratch root; a throwaway's directory is removed recursively, so it must be under /tmp, /private/tmp or \$TMPDIR"; exit 2 ;;
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
      # destructive-test-guard rule is what reads that, and DW-419 is where its limits are
      # recorded.
      #
      # Rotates the instance's own messages.log. Set here and nowhere else: this container is
      # discarded, and the test refuses to run anywhere the variable is absent rather than
      # trusting a doc comment to keep it off a development instance.
      # classes: LogSourceRotation
      OCUPILOT_ALLOW_LOG_ROTATION: "1"
      # Every class that creates or deletes IRIS principals, or the OAuth 2.0 configuration
      # objects handled the same way. Same reasoning, same single home: test classes are selected
      # by package, so a runner pointed at an instance someone cares about would otherwise create
      # principals on it. scripts/check-objectscript.py's destructive-test-guard rule holds the
      # population.
      # classes: AccountPasswordWire, AgentWireSecurity, AuditMarker, ConfigGate, CredentialPrivilege, DenialParity
      # classes: Disabled, ErrorDelete, ErrorLogDenial, LedgerWire, LogSourceDenial, MgmntPortDenial
      # classes: OAuthTabs
      # classes: ProcessControl, ProhibitedRoute, ProposalFixture, ProposalSpelling, State, Token
      # classes: ToolSetFull
      # classes: ToolWire, TurnContext, TurnConversation, TurnLong, TurnProviderFault, TurnWire
      # classes: WebAppWire
      # classes: UserCreateWire, RoleWire, ResourceWire
      # classes: TurnWireFixture, UnexpireScope, UserUpdate, Version, Wire, WireOAuthRead, WireSecurityRead
      OCUPILOT_ALLOW_PRINCIPALS: "1"
      # Writes an application error to a namespace's own ^ERRORS. Same reasoning again, and one
      # degree worse: an application error cannot be un-logged, so a runner pointed elsewhere
      # would leave it there.
      # classes: ErrorDelete, ErrorLogSeed, ProviderSecret, ProviderStub, ProviderStubTransport
      # classes: SecretLeak, SecretStoreProbe
      OCUPILOT_ALLOW_ERROR_SEED: "1"
      # Deletes OcuPilot's own audit event registrations to prove an unregistered triple drops
      # its row, then reinstalls to put them back -- the configuration triple, and the BASELINE
      # RoleGranted triple every install registers. One degree worse again: while a registration
      # is gone every row OcuPilot would write under that triple is dropped with no error and no
      # log line, so a runner pointed at an instance someone cares about would silently stop
      # auditing it. AuditMarker deletes the AgentWrite triple for the same reason and creates a
      # web application to write to, so it declares OCUPILOT_ALLOW_PRINCIPALS as well.
      # classes: AuditEvent, AuditMarker, UninstallSurvival
      OCUPILOT_ALLOW_AUDIT_EVENTS: "1"
      # Runs OcuPilot's PRODUCTION install. A production install is not one side effect but a
      # whole set of them -- a database, a resource, a role, three web applications, the audit
      # registrations and the _SYSTEM unexpire -- which is why it has a variable of its own
      # rather than riding on a narrower one. It is not the whole population that installs:
      # seven further classes run the same install and are armed by OCUPILOT_ALLOW_PRINCIPALS or
      # OCUPILOT_ALLOW_AUDIT_EVENTS instead, under a variable named for a narrower effect than
      # the one they have. Consequence, stated plainly: the classes below run here and on CI,
      # never on a development container someone cares about.
      # classes: AuditRecord, AuditVerbs, DemoOptIn, GatewayGapIpmPath, GrantReadBack
      # classes: IdentityInstall, InstallNamespaceSource, Installer, Manifest, Provenance, Static
      # classes: UninstallGuard, UninstallResidue, UninstallSurvival, WebApp
      OCUPILOT_ALLOW_PRODUCTION_INSTALL: "1"
      # Runs the installer's EnsureSslConfiguration step under the probe profile and so creates
      # -- and leaves -- a TLS configuration in the instance's own security database. Same
      # reasoning as the blocks above: a runner pointed at an instance someone cares about would
      # otherwise add a security object to it.
      # classes: ProviderSsl
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
      # that guard's home.
      # classes: TaskResume
      OCUPILOT_ALLOW_TASK_CONTROL: "1"
      # Deletes REAL application errors from a namespace's own ^ERRORS through the shipped confirm
      # path. One degree worse than OCUPILOT_ALLOW_ERROR_SEED above, which can only add: a deleted
      # application error is gone, and the variable table it captured with it, so a runner pointed
      # at an instance someone cares about would destroy the record of a fault nobody had read yet.
      # The class seeds every error it removes and clears its own namespace on exit; it declares
      # OCUPILOT_ALLOW_ERROR_SEED as well, because it seeds through that class's own guarded helper.
      # classes: ErrorDelete
      OCUPILOT_ALLOW_ERROR_DELETE: "1"
      # Arms the turnprobe provider row OcuPilot.Kernel.Provider.Catalog resolves only under it,
      # and with it the classes that spawn turn jobs against that row's scripted adapter. A turn
      # job is a separate process no in-process stub reaches, so the row is armed by the
      # environment, and only here.
      # classes: LedgerWire, ToolWire, TurnChain, TurnContext, TurnConversation
      # classes: TurnLong, TurnProviderFault, TurnStore, TurnWire, TurnWireFixture
      OCUPILOT_ALLOW_TEST_PROVIDER: "1"
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
    down)
        if [ -f "$COMPOSE_FILE" ]; then
            docker compose -f "$COMPOSE_FILE" logs --no-color iris | tail -n 80 || true
            docker compose -f "$COMPOSE_FILE" down -v
        fi
        scrub_data
        rm -rf "$DIR"
        echo "ci-throwaway: removed $DIR"
        ;;
    *)
        echo "ci-throwaway: usage: ci-throwaway.sh up|logs|down [options]"
        exit 2
        ;;
esac
