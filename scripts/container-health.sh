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

NS_RAW=$(iris session iris -U %SYS <<'EOF'
Write "OCUPILOT-NS-START:",$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"): "HSCUSTOM", 1: "USER"),":OCUPILOT-NS-END",!
Halt
EOF
)
INSTALL_NS=$(printf '%s' "$NS_RAW" | grep -o 'OCUPILOT-NS-START:[A-Za-z0-9_]*:OCUPILOT-NS-END' | sed -e 's/^OCUPILOT-NS-START://' -e 's/:OCUPILOT-NS-END$//')

if [ "$INSTALL_NS" != "HSCUSTOM" ] && [ "$INSTALL_NS" != "USER" ]; then
    exit 1
fi

# Direct-mode execution: no `$$$` macros (see container-start.sh's note).
STATUS_RAW=$(iris session iris -U "$INSTALL_NS" <<'EOF'
Write "OCUPILOT-STATUS-START:",##class(OcuPilot.Install.Installer).GateStatus(),":OCUPILOT-STATUS-END",!
Halt
EOF
)
STATUS=$(printf '%s' "$STATUS_RAW" | grep -o 'OCUPILOT-STATUS-START:[a-z]*:OCUPILOT-STATUS-END' | sed -e 's/^OCUPILOT-STATUS-START://' -e 's/:OCUPILOT-STATUS-END$//')

[ "$STATUS" = "installed" ]
