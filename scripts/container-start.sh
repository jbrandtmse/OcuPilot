#!/bin/sh
# OcuPilot's `--after` container start hook (Story 1.4, AD-17, AD-38).
#
# /iris-main runs this once IRIS itself has started -- the instance's web server is
# already listening by the time this executes, which is exactly why AD-38's load-bearing
# half is the API's own traffic gate (Api.Router.OnPreDispatch), not start ordering: this
# script cannot hold the TCP port closed while it works.
#
# ObjectScript stays out of this file's own compiled classes and lives here instead,
# because a class cannot be called before it is compiled -- this script's own job is to
# compile OcuPilot's source tree, so the call into it is necessarily typed at the shell
# level, through `iris session`.
#
# The container ships bash, sh and iris on the PATH, and no curl -- verified this story
# (see the spec's Code Map). Kept as `sh`, not bash-specific, on general principle: no
# bash-only syntax is used below.
#
# `iris session` echoes its own banner and a fresh NAMESPACE> prompt after every line it
# reads (verified live: a naive `| tail -n 1` capture returned the literal prompt text
# "%SYS>", not the Write output that preceded it) -- so every value this script reads
# back is wrapped in a distinctive start/end marker and extracted with `grep -o` /
# `sed`, never assumed to be "the last line".
set -e

SRC_DIR="/opt/ocupilot/src"

# Resolve the install namespace the same way OcuPilot.Install.Installer.ResolveNamespace
# does: HSCUSTOM when it exists on this instance, else USER. %SYS.Namespace is a
# %-package class reachable from any namespace without a switch, so this session can run
# in %SYS regardless of which namespace turns out to be the install target.
NS_RAW=$(iris session iris -U %SYS <<'EOF'
Write "OCUPILOT-NS-START:",$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"): "HSCUSTOM", 1: "USER"),":OCUPILOT-NS-END",!
Halt
EOF
)
INSTALL_NS=$(printf '%s' "$NS_RAW" | grep -o 'OCUPILOT-NS-START:[A-Za-z0-9_]*:OCUPILOT-NS-END' | sed -e 's/^OCUPILOT-NS-START://' -e 's/:OCUPILOT-NS-END$//')

if [ "$INSTALL_NS" != "HSCUSTOM" ] && [ "$INSTALL_NS" != "USER" ]; then
    echo "container-start: could not resolve the install namespace (got '$INSTALL_NS')" >&2
    exit 1
fi

echo "container-start: install namespace resolved to $INSTALL_NS"

# Demo opt-in flag (AD-25) is read from PID 1's own environment
# (/proc/1/environ), never from this shell's own $OCUPILOT_DEMO. Verified live, twice,
# that this shell's own inherited environment is NOT the container's declared one:
# /iris-main's `--after` spawns this script with a visibly narrower environment than
# `docker exec` gets in the very same container (confirmed live: $OCUPILOT_DEMO reads
# empty here, non-empty via `docker exec`), and $System.Util.GetEnviron() inside IRIS
# inherits that same narrowed environment for a client session spawned down this same
# process tree, so asking IRIS to read it does not sidestep the gap either -- only PID
# 1 itself (the container's actual entrypoint, which Docker sets the environment on
# directly) reliably carries the full, docker-compose-declared value.
# Review finding: report explicitly when /proc/1/environ itself could not be read, so
# "demo not requested" and "demo requested but undetectable" never look identical in
# the log.
if [ ! -r /proc/1/environ ]; then
    echo "container-start: could not read /proc/1/environ -- treating OCUPILOT_DEMO as absent" >&2
fi
DEMO_FLAG=$(tr '\0' '\n' < /proc/1/environ 2>/dev/null | grep '^OCUPILOT_DEMO=' | cut -d= -f2-)
if [ "$DEMO_FLAG" = "1" ]; then
    DEMO_ARG=1
else
    DEMO_ARG=0
fi

# Load and compile the read-only-mounted source tree, then invoke the one hook entry
# point, entirely inside a single `iris session` so the compile and the call share one
# resolved namespace. %SYSTEM.OBJ.LoadDir is deprecated but still the documented,
# supported way to load-and-compile a directory tree from ObjectScript itself; "ck"
# compiles and keeps generated source, matching the flags this project's MCP-tool
# verification commands already use.
#
# Direct-mode ObjectScript (piped through `iris session`) never expands `$$$` macros --
# they are a compile-time preprocessor step this shell has no routine or include context
# for (.claude/rules/objectscript-debugging.md). $System.Status.IsOK/GetErrorText are the
# documented runtime substitutes.
#
# No brace-delimited block spans more than one input line below -- verified live that
# `iris session` executes each piped line as its own independent top-level command, so a
# multi-line `If cond { ... } Else { ... }` does not scope the way it would inside a
# compiled routine: the `If` line's own condition is evaluated and then discarded, and
# every following line runs unconditionally regardless of it (reproduced directly: a
# guarded "would only print if IsOK" line printed even when the guard should have
# suppressed it). Every branch below is one single-line `$Select(...)` assignment
# instead. Every `$` is backslash-escaped so this here-doc's own shell leaves it for IRIS
# to interpret, except `$SRC_DIR` and `$DEMO_ARG`, which the shell substitutes.
RESULT_RAW=$(iris session iris -U "$INSTALL_NS" <<EOF
Set tSC = \$System.OBJ.LoadDir("$SRC_DIR", "ck", .tErrors, 1)
Set tLoadOK = \$System.Status.IsOK(tSC)
Set tLoadErr = \$Select(tLoadOK: "", 1: \$System.Status.GetErrorText(tSC))
Set tSC2 = \$Select(tLoadOK: ##class(OcuPilot.Install.Installer).StartPath($DEMO_ARG), 1: tSC)
Set tStartOK = \$Select(tLoadOK: \$System.Status.IsOK(tSC2), 1: 0)
Set tStartErr = \$Select(tStartOK: "", 1: \$System.Status.GetErrorText(tSC2))
Set tOutcome = \$Select('tLoadOK: "LOAD-FAILED:" _ tLoadErr, tStartOK: "STARTPATH-OK", 1: "STARTPATH-FAILED:" _ tStartErr)
Write "OCUPILOT-RESULT-START:",tOutcome,":OCUPILOT-RESULT-END",!
Halt
EOF
)
RESULT=$(printf '%s' "$RESULT_RAW" | grep -o 'OCUPILOT-RESULT-START:.*:OCUPILOT-RESULT-END' | sed -e 's/^OCUPILOT-RESULT-START://' -e 's/:OCUPILOT-RESULT-END$//')

echo "container-start: $RESULT"

case "$RESULT" in
    STARTPATH-OK*)
        exit 0
        ;;
    LOAD-FAILED*)
        # Review finding: a compile error happens before Install() ever runs, so
        # there is no version row yet to point at -- the generic message below would
        # be misleading here specifically.
        echo "container-start: compiling src/OcuPilot/ failed before install could run; see the load error above" >&2
        exit 1
        ;;
    *)
        echo "container-start: install did not complete; see the phase and failing step recorded on the version row" >&2
        exit 1
        ;;
esac
