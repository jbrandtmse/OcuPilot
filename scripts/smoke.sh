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
#   sh scripts/smoke.sh --container ocupilot-fresh
#   sh scripts/smoke.sh --compose-file <dir>/compose.yml --project ocupilot-fresh
#   sh scripts/smoke.sh                        # an instance with `iris` on this PATH
#
# Options:
#   --container NAME     run inside this docker container (docker exec)
#   --compose-file FILE  run inside a compose project's `iris` service
#   --project NAME       the compose project name, with --compose-file
#   --service NAME       the compose service to exec into (default: iris)
#   --namespace NS       the install namespace (default: OCUPILOT_NAMESPACE, else the instance's
#                        own answer: HSCUSTOM if it exists, else USER, as the install resolves it)
#   --user NAME          sign-in credentials; the two list reads need %Admin_Secure:USE and %DB_IRISSYS:READ
#   --password VALUE     ...its password. With no --user the sign-in check is SKIPPED, and so
#                        are the API reads that need its token -- which is honest, and
#                        which the executed count then shows.
#   --demo 0|1           whether the opt-in demo fixtures are expected (AD-25). Resolved from
#                        the container's PID 1 environment when not given, because a session
#                        spawned down the instance's own process tree sees a narrower
#                        environment than the container's declared one (the same trap
#                        scripts/container-start.sh records).
#
# Exit 0 when the run passed: at least one check executed and none failed. Exit 1 when it did not,
# including a run in which every check was skipped, because zero executed checks is a failure and
# never a pass, and an instance holding neither HSCUSTOM nor USER, where no session is opened.
# Exit 2 for a caller error: a bad argument, or a credential this script refuses.
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

# `iris session` in direct mode executes each piped LINE as its own top-level command, so a line
# break inside a credential would end the Set line and run whatever followed it as a command of
# its own. Doubling a quote cannot help with that, so it is refused rather than escaped.
#
# A bare CARRIAGE RETURN ends that line too, not only a newline -- observed on this build, where
# `Set tX = "A<CR>Write 99"` piped in as one line raised two separate <SYNTAX> errors. Credentials
# read from a CRLF-authored file or secret carry one, so both characters are refused.
#
# The `x` sentinel is what carries the character out of the substitution: `$(...)` strips trailing
# newlines, so `$(printf '\n')` is the empty string and `*""*` matches every input. Held in a
# variable, each pattern tests for its own character under `sh` and `dash` as well as `bash`.
SMOKE_NL=$(printf '\nx')
SMOKE_NL=${SMOKE_NL%x}
SMOKE_CR=$(printf '\rx')
SMOKE_CR=${SMOKE_CR%x}
case "$SMOKE_USER$SMOKE_PASSWORD" in
    *"$SMOKE_NL"*|*"$SMOKE_CR"*)
        echo "smoke: credentials may not contain a newline or a carriage return"
        exit 2
        ;;
esac

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
fi

# No override: the instance's own answer, resolved the way scripts/container-start.sh resolves the
# install namespace -- HSCUSTOM when it exists, else USER. Asked in %SYS, which every instance has,
# so a missing namespace is refused here by name rather than answered "Access Denied" by a session
# opened in it. The instance reports both flags and this script chooses, so the choice is testable
# with a stub `iris`.
if [ -z "$NAMESPACE" ]; then
    PROBE_RAW=$($RUNNER iris session iris -U %SYS 2>&1 <<'EOF' || true
Write "OCUPILOT-"_"SMOKE-NS-START:"_##class(%SYS.Namespace).Exists("HSCUSTOM")_","_##class(%SYS.Namespace).Exists("USER")_":OCUPILOT-"_"SMOKE-NS-END",!
Halt
EOF
)
    PROBE=$(printf '%s\n' "$PROBE_RAW" | tr '\r' ' ' | grep -o 'OCUPILOT-SMOKE-NS-START:[01],[01]:OCUPILOT-SMOKE-NS-END' | tail -n 1 | sed -e 's/^OCUPILOT-SMOKE-NS-START://' -e 's/:OCUPILOT-SMOKE-NS-END$//')
    case "$PROBE" in
        1,[01]) NAMESPACE="HSCUSTOM" ;;
        0,1) NAMESPACE="USER" ;;
        0,0)
            echo "smoke: this instance has neither HSCUSTOM nor USER, so OcuPilot has no install namespace here; pass --namespace to name one"
            exit 1
            ;;
        *)
            echo "smoke: the instance did not say whether HSCUSTOM or USER exists, so no install namespace could be chosen; pass --namespace to name one"
            printf '%s\n' "$PROBE_RAW" | tail -n 30 | sed -e 's/^/smoke: | /'
            exit 1
            ;;
    esac
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
        # Every failing check by name, on one quotable line (DW-1079). A report row is
        # "  " + <outcome padded to 9> + <name> [+ " -- " + reason] (OcuPilot.Install.Smoke), so
        # awk's default whitespace split puts the outcome in $1 and the name in $2. Without this
        # the line said only that "the failing check is named above", which is an unattributable
        # red in a CI log nobody can grep -- and the class-side line names only the first.
        FAILED=$(printf '%s\n' "$REPORT" | awk '$1 == "fail" { printf "%s%s", (n++ ? ", " : ""), $2 }')
        NAMED=$(printf '%s\n' "$REPORT" | awk '$1 == "fail" { n++ } END { print n + 0 }')
        # What the class itself counted, from its own counts line. The criterion is that the line
        # names EVERY failing check, and the two numbers are the only thing that says it did: a
        # row the class fails closed on (an outcome outside the four it writes) carries that
        # outcome in $1 and is invisible to the awk above, so a silent under-report would read as
        # a complete one. Held equal here rather than assumed.
        COUNTED=$(printf '%s\n' "$REPORT" | sed -n 's/.*[[:space:]]failed=\([0-9][0-9]*\).*/\1/p' | tail -n 1)
        if [ -n "$FAILED" ]; then
            echo "smoke: FAILED check(s): $FAILED"
            if [ -n "$COUNTED" ] && [ "$COUNTED" != "$NAMED" ]; then
                echo "smoke: the report counted $COUNTED failure(s) and $NAMED could be named; the rest are in the report above"
            fi
        else
            echo "smoke: the instance did not pass; the failing check is named above"
        fi
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
