#!/bin/sh
# OcuPilot's compose health probe (Story 1.4, AD-38, AD-45). Reports healthy only once
# THIS container start's install has recorded success, and only while install is complete
# at the deployed schema version -- the same OcuPilot.Install.Installer.GateStatus()
# decision Api.Router's traffic gate uses, read through `iris session` because the image
# ships no curl (verified this story's Code Map) and there is no HTTP readiness endpoint yet
# (that is Story 1.17's, AD-45).
#
# Start-scoped (DW-72, AD-38 as amended 2026-09-11): container-start.sh writes
# /tmp/ocupilot-start-ok only after it has seen STARTPATH-OK, holding a key for that
# container start (the kernel's boot id and PID 1's start time). Until the marker carries
# this start's key the probe fails without asking IRIS anything, so a same-version restart
# can no longer read healthy from the version row an earlier start wrote while this start
# is still recompiling and re-installing. After it, the gate decides: a later failed install
# (a failed or unreadable row) turns the check unhealthy again, as it always did. The API
# gate itself keeps reading GateStatus() alone -- an IPM install has no start hook, so a
# start-scoped condition there would refuse traffic forever. The trade (the key follows the
# container, not the IRIS instance inside it, so an `iris restart` inside a running container
# does not re-run the hook and the check stays healthy) is in container-start.sh's header and
# README.md.
#
# See container-start.sh's own note: `iris session` echoes prompt text into stdout, so
# the result is extracted with a distinctive marker, never assumed to be "the last line" --
# and the marker is split on its source line, so a failing line's echoed source cannot
# supply one.
set -e

START_MARKER="/tmp/ocupilot-start-ok"

# Fix Pack F-2 (code review round 3): the raw session output used to be captured and thrown
# away, so a <CLASS DOES NOT EXIST> or an <UNDEFINED> never reached `docker inspect`'s
# health log. print_tail puts the last lines of it on stderr, which that log records.
print_tail() {
    # The first error lines as well as the last lines: once one line of a session fails,
    # every later line that uses its result fails too, so the tail alone can show only the
    # cascade (<UNDEFINED> after <UNDEFINED>) and never the error that started it.
    tFirstErrors=$(printf '%s\n' "$2" | grep -a -E '^<[A-Z]|ERROR #' | head -n 5 || true)
    if [ -n "$tFirstErrors" ]; then
        echo "container-health: first errors in the $1 session output:" >&2
        printf '%s\n' "$tFirstErrors" | sed -e 's/^/container-health: | /' >&2
    fi
    echo "container-health: last lines of the $1 session output:" >&2
    printf '%s\n' "$2" | tail -n 20 | sed -e 's/^/container-health: | /' >&2
}

# The key for this container start. Must match container-start.sh's.
start_key() {
    tBoot=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || true)
    tStarted=$(sed -e 's/^.*) //' /proc/1/stat 2>/dev/null | cut -d' ' -f20 || true)
    if [ -z "$tBoot" ] || [ -z "$tStarted" ]; then
        return 1
    fi
    printf '%s:%s' "$tBoot" "$tStarted"
}

KEY=$(start_key) || KEY=""
if [ -z "$KEY" ]; then
    echo "container-health: this container start could not be identified (/proc/sys/kernel/random/boot_id, /proc/1/stat)" >&2
    exit 1
fi
if [ ! -r "$START_MARKER" ] || [ "$(cat "$START_MARKER" 2>/dev/null)" != "$KEY" ]; then
    echo "container-health: this container start's install has not recorded success yet" >&2
    exit 1
fi

# Fix Pack F-3: namespace resolution and the GateStatus() read used to be two separate
# `iris session` logins, every 10s, for the container's life -- but the resolved
# namespace's answer cannot change between them within one probe, so this is now one
# session: start in %SYS (reachable regardless of which namespace turns out to be the
# install target), resolve the namespace, `Set $NAMESPACE` to it (an ordinary variable
# assignment, no further login needed), then read GateStatus(). Direct-mode execution:
# no `$$$` macros (see container-start.sh's note).
# Fix Pack F-1 (round 2): `set -e` takes a command substitution's own exit status, so a
# non-zero `iris session` (IRIS not yet accepting logins, an auth failure) used to end
# this script right here, at the assignment -- before the diagnostic message below could
# ever print. The exit code was already correct either way; the `|| { ...; exit 1; }`
# below only makes sure the log line explaining why is not lost with it.
STATUS_RAW=$(iris session iris -U %SYS <<'EOF'
Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"): "HSCUSTOM", 1: "USER")
Set $NAMESPACE=tNS
Write "OCUPILOT-"_"STATUS-START:"_##class(OcuPilot.Install.Installer).GateStatus()_":OCUPILOT-"_"STATUS-END",!
Halt
EOF
) || { echo "container-health: iris session failed while resolving the gate status" >&2; print_tail "gate status" "$STATUS_RAW"; exit 1; }
STATUS=$(printf '%s' "$STATUS_RAW" | grep -o 'OCUPILOT-STATUS-START:[a-z]*:OCUPILOT-STATUS-END' | sed -e 's/^OCUPILOT-STATUS-START://' -e 's/:OCUPILOT-STATUS-END$//')

if [ -z "$STATUS" ]; then
    # Fix Pack F-2 (code review round 3): there was no branch for a session that never
    # wrote its marker at all; it reported "gate status is ''" and nothing else.
    echo "container-health: no gate status marker was found in the session output" >&2
    print_tail "gate status" "$STATUS_RAW"
    exit 1
fi

if [ "$STATUS" != "installed" ]; then
    # Fix Pack F-3: every branch used to be a bare `exit 1` with no message, so
    # `docker inspect`'s health log recorded nothing beyond the exit code.
    echo "container-health: gate status is '$STATUS', not installed" >&2
    exit 1
fi
