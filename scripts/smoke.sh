#!/bin/sh
# OcuPilot's smoke script (Story 1.17, AD-45): the one entry point CI and Epic 17's
# clean-clone run both call to ask an instance whether OcuPilot is installed and working.
#
# THE ASSERTIONS ARE NOT HERE. They live in OcuPilot.Install.Smoke, inside the instance,
# which is what makes "the same script with the same assertions, differing only in what
# created the instance" literally true rather than a claim about two implementations that
# happen to agree. This script locates an instance, runs that class through `iris session`,
# prints what it returns unchanged, and maps its verdict to an exit code.
#
# Usage:
#   bash scripts/smoke.sh --container ocupilot-fresh
#   bash scripts/smoke.sh --compose-file <dir>/compose.yml --project ocupilot-fresh
#   bash scripts/smoke.sh                      # an instance with `iris` on this PATH
#
# Options:
#   --container NAME     run inside this docker container (docker exec)
#   --compose-file FILE  run inside a compose project's `iris` service
#   --project NAME       the compose project name, with --compose-file
#   --service NAME       the compose service to exec into (default: iris)
#   --namespace NS       the install namespace (default: OCUPILOT_NAMESPACE, else HSCUSTOM)
#   --user NAME          credentials the sign-in check mints a token pair with
#   --password VALUE     ...its password. With no --user the sign-in check is SKIPPED, and so
#                        are the three API reads that need its token -- which is honest, and
#                        which the executed count then shows.
#   --demo 0|1           whether the opt-in demo fixtures are expected (AD-25). Resolved from
#                        the container's PID 1 environment when not given, because a session
#                        spawned down the instance's own process tree sees a narrower
#                        environment than the container's declared one (the same trap
#                        scripts/container-start.sh records).
#
# Exit 0 when the run passed: at least one check executed and none failed. Exit 1 otherwise --
# including a run in which every check was skipped, because zero executed checks is a failure
# and never a pass.
#
# `iris session` echoes a banner and a fresh prompt after every line it reads, so the report is
# extracted between markers rather than assumed to be "the last lines". Each marker is written
# split ("OCUPILOT-"_"SMOKE-...") so that a line echoed back with an error cannot supply one.
set -e

CONTAINER=""
COMPOSE_FILE=""
PROJECT=""
SERVICE="iris"
NAMESPACE=""
SMOKE_USER=""
SMOKE_PASSWORD=""
DEMO=""

while [ $# -gt 0 ]; do
    case "$1" in
        --container) CONTAINER="$2"; shift 2 ;;
        --compose-file) COMPOSE_FILE="$2"; shift 2 ;;
        --project) PROJECT="$2"; shift 2 ;;
        --service) SERVICE="$2"; shift 2 ;;
        --namespace) NAMESPACE="$2"; shift 2 ;;
        --user) SMOKE_USER="$2"; shift 2 ;;
        --password) SMOKE_PASSWORD="$2"; shift 2 ;;
        --demo) DEMO="$2"; shift 2 ;;
        -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
        *) echo "smoke: unknown argument $1"; exit 2 ;;
    esac
done

if [ -n "$CONTAINER" ] && [ -n "$COMPOSE_FILE" ]; then
    echo "smoke: --container and --compose-file name two different instances; pass one"
    exit 2
fi

case "$DEMO" in
    ""|0|1) ;;
    *) echo "smoke: --demo takes 0 or 1, got '$DEMO'"; exit 2 ;;
esac

# A caller error, refused as one. Without this, --user with no --password signs in with an empty
# password, the token endpoint refuses it, and the report blames the instance for a mistake the
# command line made.
if [ -n "$SMOKE_USER" ] && [ -z "$SMOKE_PASSWORD" ]; then
    echo "smoke: --user was given without --password; pass both, or neither to skip the sign-in check"
    exit 2
fi

# A quote in a credential would end the ObjectScript string literal the here-doc below builds.
# Doubled, which is how ObjectScript escapes one inside a literal.
escape_literal() {
    printf '%s' "$1" | sed -e 's/"/""/g'
}

# How to run a command inside the instance. Three shapes, one contract: everything after the
# prefix is the command and its arguments.
if [ -n "$CONTAINER" ]; then
    RUNNER="docker exec -i $CONTAINER"
elif [ -n "$COMPOSE_FILE" ]; then
    if [ -n "$PROJECT" ]; then
        RUNNER="docker compose -p $PROJECT -f $COMPOSE_FILE exec -T $SERVICE"
    else
        RUNNER="docker compose -f $COMPOSE_FILE exec -T $SERVICE"
    fi
else
    RUNNER=""
fi

# The demo opt-in flag, read from PID 1's own environment when the caller did not state it --
# the one place in the container that reliably carries the declared value.
if [ -z "$DEMO" ]; then
    if [ -n "$RUNNER" ]; then
        DEMO_RAW=$($RUNNER sh -c "tr '\\0' '\\n' < /proc/1/environ 2>/dev/null | grep '^OCUPILOT_DEMO=' | cut -d= -f2-" 2>/dev/null || true)
    else
        DEMO_RAW=$(tr '\0' '\n' < /proc/1/environ 2>/dev/null | grep '^OCUPILOT_DEMO=' | cut -d= -f2- || true)
    fi
    case "$DEMO_RAW" in
        1*) DEMO=1 ;;
        *) DEMO=0 ;;
    esac
fi

if [ -z "$NAMESPACE" ]; then
    if [ -n "$RUNNER" ]; then
        NS_RAW=$($RUNNER sh -c "tr '\\0' '\\n' < /proc/1/environ 2>/dev/null | grep '^OCUPILOT_NAMESPACE=' | cut -d= -f2-" 2>/dev/null || true)
    else
        NS_RAW="${OCUPILOT_NAMESPACE:-}"
    fi
    NAMESPACE=$(printf '%s' "$NS_RAW" | tr -cd 'A-Za-z0-9_%-')
    [ -n "$NAMESPACE" ] || NAMESPACE="HSCUSTOM"
fi

USER_LITERAL=$(escape_literal "$SMOKE_USER")
PASSWORD_LITERAL=$(escape_literal "$SMOKE_PASSWORD")

# Direct-mode ObjectScript: `iris session` executes each piped line as its own top-level
# command, so no brace-delimited block may span lines (verified in scripts/container-start.sh).
# Every `$` is escaped so this here-doc's own shell leaves it for IRIS, except the three
# substitutions below, which the shell fills in.
RAW=$($RUNNER iris session iris -U "$NAMESPACE" 2>&1 <<EOF || true
Set tOk = ##class(OcuPilot.Install.Smoke).Run("$USER_LITERAL", "$PASSWORD_LITERAL", "$DEMO", .tReport, .tCounts)
Write "OCUPILOT-"_"SMOKE-REPORT-START:",!
Write tReport,!
Write "OCUPILOT-"_"SMOKE-VERDICT-START:"_\$Select(tOk: "PASS", 1: "FAIL")_":OCUPILOT-"_"SMOKE-VERDICT-END",!
Halt
EOF
)

# The report, printed unchanged: everything the class produced between its own start marker and
# the verdict line. The two filters remove `iris session`'s own noise and nothing else -- it
# echoes a fresh `NAMESPACE>` prompt after every line it reads, and the report itself carries no
# blank line and no line that is only a prompt.
REPORT=$(printf '%s\n' "$RAW" | tr -d '\r' \
    | sed -n '/OCUPILOT-SMOKE-REPORT-START:/,/OCUPILOT-SMOKE-VERDICT-START:/p' \
    | sed -e '/OCUPILOT-SMOKE-REPORT-START:/d' -e '/OCUPILOT-SMOKE-VERDICT-START:/d' \
    | sed -e '/^[A-Za-z%][A-Za-z0-9_%-]*>[[:space:]]*$/d' -e '/^[[:space:]]*$/d')
VERDICT=$(printf '%s\n' "$RAW" | tr '\r' ' ' | grep -o 'OCUPILOT-SMOKE-VERDICT-START:[A-Z]*:OCUPILOT-SMOKE-VERDICT-END' | sed -e 's/^OCUPILOT-SMOKE-VERDICT-START://' -e 's/:OCUPILOT-SMOKE-VERDICT-END$//')

if [ -n "$REPORT" ]; then
    printf '%s\n' "$REPORT"
fi

case "$VERDICT" in
    PASS)
        exit 0
        ;;
    FAIL)
        echo "smoke: the instance did not pass; the failing check is named above"
        exit 1
        ;;
    *)
        # No verdict marker at all: the session never got as far as reporting one, which is a
        # failure and never a pass. The raw output is what says why.
        echo "smoke: no verdict marker was found in the session output -- the smoke run did not complete"
        printf '%s\n' "$RAW" | tail -n 30 | sed -e 's/^/smoke: | /'
        exit 1
        ;;
esac
