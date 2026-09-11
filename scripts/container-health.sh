#!/bin/sh
# OcuPilot's compose health probe (Story 1.4, AD-38, AD-45). Reports healthy only once
# install has completed at the deployed schema version -- the same
# OcuPilot.Install.Installer.GateStatus() decision Api.Router's traffic gate uses, read
# through `iris session` because the image ships no curl (verified this story's Code Map)
# and there is no HTTP readiness endpoint yet (that is Story 1.17's, AD-45).
#
# See container-start.sh's own note: `iris session` echoes prompt text into stdout, so
# the result is extracted with a distinctive marker, never assumed to be "the last line".
set -e

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
Write "OCUPILOT-STATUS-START:",##class(OcuPilot.Install.Installer).GateStatus(),":OCUPILOT-STATUS-END",!
Halt
EOF
) || { echo "container-health: iris session failed while resolving the gate status" >&2; exit 1; }
STATUS=$(printf '%s' "$STATUS_RAW" | grep -o 'OCUPILOT-STATUS-START:[a-z]*:OCUPILOT-STATUS-END' | sed -e 's/^OCUPILOT-STATUS-START://' -e 's/:OCUPILOT-STATUS-END$//')

if [ "$STATUS" != "installed" ]; then
    # Fix Pack F-3: every branch used to be a bare `exit 1` with no message, so
    # `docker inspect`'s health log recorded nothing beyond the exit code.
    echo "container-health: gate status is '$STATUS', not installed" >&2
    exit 1
fi
