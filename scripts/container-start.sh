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
#
# The marker text never appears literally on a source line, and each marker line is one
# Write of one expression (Fix Pack F-2, rework iteration 8, seen on a throwaway container).
# When a line fails, the session prints that line's source back with the error, and it had
# already written whatever arguments came before the failing one: a StartPath that threw
# left tOutcome undefined, the RESULT line wrote its start marker, failed, and echoed its own
# source, whose literal end marker the extraction below then matched. The hook reported the
# echoed source as the result and sent the operator to the version row. Splitting each
# marker ("OCUPILOT-"_"RESULT-START:") keeps the echo from matching, and one expression
# means a failure writes nothing at all.
#
# Every start, including a restart at the same schema version, re-runs install (AD-17), so
# AD-38 (as amended 2026-09-11, DW-72) asks two things of this hook:
#
# - Before it recompiles, it marks an `installed` version row `installing`
#   (Installer.MarkInstalling), so Api.Router's gate stops serving the previous start's row
#   for the whole recompile and re-install. That call reaches the class the PREVIOUS start
#   compiled: on a first start on a volume there is no such class, and on the first start
#   after the mark shipped the class predates it. The hook logs either case and carries on;
#   a mark that fails or is refused never fails the start.
#
# - The health check reports healthy only once THIS start's install has recorded success,
#   never on a row an earlier start wrote. After STARTPATH-OK, and only then, this hook
#   writes START_MARKER below, holding a key for this container start: the kernel's boot id
#   and PID 1's start time (field 22 of /proc/1/stat). A container restart starts a new
#   PID 1, so the key changes and an earlier start's marker no longer matches;
#   container-health.sh computes the same key and requires the marker to carry it. The
#   marker lives in the container's own /tmp, never in the durable volume or the mounted
#   source. The trade, recorded in docs/DEVELOPMENT.md's "The container start path"
#   too: the key follows the container, not the IRIS instance inside it. Observed on a
#   throwaway container: `iris restart` inside the running container left PID 1 and the
#   marker in place, this hook did not run again, and the check stayed healthy, answering
#   from this container start's install and the version row (the gate still reads the
#   row, so a later failed install still turns it unhealthy).
#
# NO MESSAGE OF THIS HOOK'S OWN REACHES STDERR, and neither does any `iris session`:
# every message below is written to stdout, and every `iris session` is captured with `2>&1`,
# so a session that writes to stderr puts that text into the captured output (where
# print_tail can show it) instead of into /iris-main's. Those are the two things
# `ui/tools/compose.test.mjs` enforces. The other children -- the `grep`, `head`, `sed`,
# `tail` and `cut` inside print_tail and start_key -- read from pipes and variables rather
# than from files, so none has an input it can fail on, but their stderr is inherited rather
# than captured and no test covers them. Verified by controlled probe on the pinned image
# (Story 1.5):
# /iris-main treats ANY stderr output from its `--after` command as a failure and shuts the
# instance down -- `--after "sh -c 'echo X >&2; exit 0'"` logs `[ERROR] X` and then
# "Shutting down InterSystems IRIS instance IRIS", with the command's own exit status 0. So a
# line meant to say "carrying on" would stop the container instead, which is the opposite of
# what DW-72 promises for a failed mark and of what AC11 promises for an absent client bundle.
# The exit code alone is enough to fail a start: the same probe with `exit 1` and no stderr
# shut the instance down and logged the status. Every message below therefore goes to stdout,
# and a genuine failure is signalled by `exit 1` and nothing else.
set -e

SRC_DIR="/opt/ocupilot/src"
START_MARKER="/tmp/ocupilot-start-ok"
# The built Angular bundle, on the read-only ./ui mount docker-compose.yml declares. Story
# 1.5's install step copies it into the shell application's own directory; an absent one is a
# warn and never a failed start, so a clone whose client has never been built still comes up.
BUNDLE_DIR="/opt/ocupilot/ui/dist/ocupilot-ui/browser"

# Fix Pack F-2 (code review round 3): the raw `iris session` output used to be captured and
# then thrown away, so on the paths that tell the operator to read "the output above" -- no
# result marker, or a session that failed outright -- a <CLASS DOES NOT EXIST> or an
# <UNDEFINED> was lost. print_tail puts the last lines of it in the log instead.
print_tail() {
    # The first error lines as well as the last lines: once one line of a session fails,
    # every later line that uses its result fails too, so the tail alone can show only the
    # cascade (<UNDEFINED> after <UNDEFINED>) and never the error that started it.
    tFirstErrors=$(printf '%s\n' "$2" | grep -a -E '^<[A-Z]|ERROR #' | head -n 5 || true)
    if [ -n "$tFirstErrors" ]; then
        echo "container-start: first errors in the $1 session output:"
        printf '%s\n' "$tFirstErrors" | sed -e 's/^/container-start: | /'
    fi
    echo "container-start: last lines of the $1 session output:"
    printf '%s\n' "$2" | tail -n 20 | sed -e 's/^/container-start: | /'
}

# The key for this container start -- see the header. Must match container-health.sh's.
start_key() {
    tBoot=$(cat "${OCUPILOT_BOOT_ID_FILE:-/proc/sys/kernel/random/boot_id}" 2>/dev/null || true)
    tStarted=$(sed -e 's/^.*) //' "${OCUPILOT_PID1_STAT_FILE:-/proc/1/stat}" 2>/dev/null | cut -d' ' -f20 || true)
    if [ -z "$tBoot" ] || [ -z "$tStarted" ]; then
        return 1
    fi
    printf '%s:%s' "$tBoot" "$tStarted"
}

# No earlier start's marker survives into this one. It would not match this start's key
# anyway; removing it is belt and braces.
rm -f "$START_MARKER" 2>/dev/null || true

# The optional install-namespace override (DW-12). Read from PID 1's own environment for the
# same reason OCUPILOT_DEMO is below -- /iris-main's `--after` spawns this script with a
# visibly narrower environment than the container's declared one. Optional, like
# OCUPILOT_DEMO: no environment variable is required to run. Sanitized rather than trusted:
# not because the value is interpolated -- both here-docs below are quoted and the value
# reaches IRIS only through $System.Util.GetEnviron -- but so that a value that is not a
# namespace name is refused here, by a script that can still print why, rather than becoming
# a <NAMESPACE> inside a session whose output the operator has to reconstruct.
NS_OVERRIDE=$(tr '\0' '\n' < /proc/1/environ 2>/dev/null | grep '^OCUPILOT_NAMESPACE=' | cut -d= -f2-)
NS_OVERRIDE_SAFE=$(printf '%s' "$NS_OVERRIDE" | tr -cd 'A-Za-z0-9_%-')
if [ "$NS_OVERRIDE" != "$NS_OVERRIDE_SAFE" ]; then
    echo "container-start: OCUPILOT_NAMESPACE is set to something that is not a namespace name; refusing rather than guessing at an install target"
    exit 1
fi
if [ -n "$NS_OVERRIDE" ]; then
    echo "container-start: OCUPILOT_NAMESPACE names $NS_OVERRIDE, which overrides the HSCUSTOM-then-USER default"
fi
# Re-exported so the `iris session` children below inherit it and can read it with
# $System.Util.GetEnviron. The header's warning is about reading the CONTAINER's declared
# environment from inside IRIS, which is narrowed; a variable this shell exports itself is
# inherited normally. Passing it this way keeps both here-docs quoted, so no ObjectScript
# below is interpolated by the shell.
export OCUPILOT_NAMESPACE="$NS_OVERRIDE"

# Resolve the install namespace the same way OcuPilot.Install.Installer.ResolveNamespace
# does -- HSCUSTOM when it exists on this instance, then USER -- unless OCUPILOT_NAMESPACE
# names one, in which case that one is used and no default is considered. %SYS.Namespace is a
# %-package class reachable from any namespace without a switch, so this session can run
# in %SYS regardless of which namespace turns out to be the install target. The same
# session then makes the pre-recompile mark (DW-72) in that namespace, through the
# installer the previous start compiled -- when there is one, and when it has the method.
#
# DW-12: the namespace is checked to exist, and a namespace that does not is a failed start
# naming it -- never a silent fall back to a default the operator did not ask for. NONE is the
# instance that carries neither candidate and no override, which OcuPilot cannot install into
# at all; the session reports which of the two it is, and the branch below says so.
#
# Fix Pack F-1 (round 2): `set -e` takes a command substitution's own exit status, so a
# non-zero `iris session` here (or at RESULT_RAW below) used to end this script at the
# assignment -- before either diagnostic message could print. The exit code was already
# correct either way; `|| { ...; exit 1; }` only keeps the log line that explains why.
#
# The here-doc stays quoted: the override reaches IRIS through the exported environment
# variable above, not through shell interpolation, so nothing below is rewritten by the shell.
#
# DW-195 (closed, Story 1.17): the system-namespace refusal happens HERE, in the resolution
# session, and not in OcuPilot.Install.Installer.GuardInstallNamespace alone. That guard is
# reached only once StartPath runs -- in the load-and-start session below, by which point the
# sessions below have already compiled src/OcuPilot/ (less the roster's test-scope package on a
# product start) into whatever namespace was resolved first, unconditionally. An override
# naming an existing system namespace (%SYS.Namespace.Exists("%SYS") answers true on every
# instance) therefore reached the compile before anything could refuse it.
#
# The refusal list is a LITERAL here, and it has to be. This session runs in %SYS and decides
# the namespace before switching into it -- the decision is what selects the namespace, so it
# cannot be made from inside one -- and OcuPilot's code is mapped nowhere but the install
# namespace, so asking OcuPilot.Install.Installer for its own SYSTEMNAMESPACES parameter from
# here answers nothing on every start, not only the first. What holds the literal equal to the
# parameter is ui/tools/compose.test.mjs, which compares the two as text. The "%"-prefix rule
# below is independent of the list and refuses %SYS whatever the list says.
PRE_RAW=$(iris session iris -U %SYS 2>&1 <<'EOF'
Set tOverride=$System.Util.GetEnviron("OCUPILOT_NAMESPACE")
Set tHasHSCUSTOM=##class(%SYS.Namespace).Exists("HSCUSTOM")
Set tHasUSER=##class(%SYS.Namespace).Exists("USER")
Set tDefault=$Select(tHasHSCUSTOM:"HSCUSTOM",tHasUSER:"USER",1:"")
Set tNS=$Case(tOverride,"":tDefault,:tOverride)
Set tExists=$Select(tNS="":0,1:##class(%SYS.Namespace).Exists(tNS))
Set tRefusedList="ENSLIB,DOCBOOK,HSLIB,HSSYS,HSSYSLOCALTEMP,IRISAUDIT,IRISLIB,IRISLOCALDATA,IRISSYS,IRISTEMP"
Set tUpper=$ZConvert(tNS,"U")
Set tIsSystem=$Select(tUpper="":1,$Extract(tUpper)="%":1,1:(","_tRefusedList_",")[(","_tUpper_","))
Set tNsOutcome=$Select(tIsSystem&&($Length(tNS)>0): "SYSTEM:"_tNS, tExists: "OK:"_tNS, 1: $Case(tOverride,"":"NONE",:"MISSING:"_tOverride))
Write "OCUPILOT-"_"NS-START:"_tNsOutcome_":OCUPILOT-"_"NS-END",!
Set tUsable=$Select(tIsSystem:0,1:tExists)
Set $NAMESPACE=$Select(tUsable: tNS, 1: $NAMESPACE)
Set tHaveClass=$Select(tUsable:##class(%Dictionary.CompiledClass).%ExistsId("OcuPilot.Install.Installer"),1:0)
Set tHaveMark=$Select(tHaveClass:##class(%Dictionary.CompiledMethod).%ExistsId("OcuPilot.Install.Installer||MarkInstalling"),1:0)
Set tMarkSC=$Select(tHaveMark:##class(OcuPilot.Install.Installer).MarkInstalling("", .tMarkOutcome), 1: 1)
Write "OCUPILOT-"_"MARK-START:"_$Select('tHaveClass: "NOCLASS", 'tHaveMark: "NOMETHOD", $System.Status.IsOK(tMarkSC): "OK:"_tMarkOutcome, 1: "FAILED:"_$System.Status.GetErrorText(tMarkSC))_":OCUPILOT-"_"MARK-END",!
Halt
EOF
) || { echo "container-start: iris session failed while resolving the install namespace"; print_tail "namespace" "$PRE_RAW"; exit 1; }
NS_RESULT=$(printf '%s' "$PRE_RAW" | tr '\r\n' '  ' | grep -o 'OCUPILOT-NS-START:.*:OCUPILOT-NS-END' | sed -e 's/^OCUPILOT-NS-START://' -e 's/:OCUPILOT-NS-END$//')

INSTALL_NS=""
case "$NS_RESULT" in
    OK:*)
        INSTALL_NS="${NS_RESULT#OK:}"
        ;;
    MISSING:*)
        echo "container-start: OCUPILOT_NAMESPACE names the namespace ${NS_RESULT#MISSING:}, which does not exist on this instance; refusing rather than falling back to HSCUSTOM or USER"
        exit 1
        ;;
    SYSTEM:*)
        # DW-195: refused HERE, before $System.OBJ.LoadDir compiles anything. The same refusal
        # exists in OcuPilot.Install.Installer.GuardInstallNamespace, but that one is reached
        # only once StartPath runs -- by which point the sessions below have already compiled
        # OcuPilot's code into the namespace named here.
        echo "container-start: OCUPILOT_NAMESPACE names ${NS_RESULT#SYSTEM:}, which is a namespace OcuPilot refuses to install into; refusing before anything is compiled into it. Name an ordinary namespace, or leave the variable unset to use the HSCUSTOM-then-USER default"
        exit 1
        ;;
    NONE)
        echo "container-start: this instance carries neither HSCUSTOM nor USER, so there is no namespace to install OcuPilot into; create one of them. OCUPILOT_NAMESPACE does not substitute for that -- it chooses which namespace to install into, and Installer.StartPath refuses an instance carrying neither candidate whatever the override names"
        exit 1
        ;;
    *)
        echo "container-start: could not resolve the install namespace (got '$NS_RESULT')"
        print_tail "namespace" "$PRE_RAW"
        exit 1
        ;;
esac

echo "container-start: install namespace resolved to $INSTALL_NS"

# The mark's outcome. None of these fails the start (DW-72's constraint).
MARK=$(printf '%s' "$PRE_RAW" | tr '\r\n' '  ' | grep -o 'OCUPILOT-MARK-START:.*:OCUPILOT-MARK-END' | sed -e 's/^OCUPILOT-MARK-START://' -e 's/:OCUPILOT-MARK-END$//')
case "$MARK" in
    OK:marked)
        echo "container-start: marked the version row installing before the recompile; it stays so until this start's install records its outcome"
        ;;
    OK:*)
        echo "container-start: left the version row as it is before the recompile (${MARK#OK:}); only an installed row is marked"
        ;;
    NOCLASS)
        echo "container-start: no installer is compiled yet (a first start on this volume), so there is no version row to mark before the recompile"
        ;;
    NOMETHOD)
        echo "container-start: the installer an earlier start compiled predates the pre-recompile mark, so nothing was marked this time; the health check still waits for this start's install"
        ;;
    FAILED:*)
        echo "container-start: could not mark the version row before the recompile (${MARK#FAILED:}); carrying on, and the health check still waits for this start's install"
        ;;
    *)
        echo "container-start: the mark before the recompile reported nothing; carrying on, and the health check still waits for this start's install"
        print_tail "namespace and mark" "$PRE_RAW"
        ;;
esac

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
    echo "container-start: could not read /proc/1/environ -- treating OCUPILOT_DEMO as absent"
fi
DEMO_FLAG=$(tr '\0' '\n' < /proc/1/environ 2>/dev/null | grep '^OCUPILOT_DEMO=' | cut -d= -f2-)
if [ "$DEMO_FLAG" = "1" ]; then
    DEMO_ARG=1
else
    DEMO_ARG=0
fi

# The container start path ALWAYS names the bundle directory, present or not, so install is
# the one place that decides what an absent bundle means -- a warn naming the directory, and
# a start that carries on (AC11). The empty argument is reserved for a caller that names no
# source at all (the MCP tools, IPM's <Invoke>), which is a different case: leave whatever
# bundle is already installed alone, and say so rather than warn about a directory nobody
# asked for. This branch only chooses the log line.
BUNDLE_ARG="$BUNDLE_DIR"
if [ -f "$BUNDLE_DIR/index.html" ]; then
    echo "container-start: installing the built client bundle from $BUNDLE_DIR"
else
    echo "container-start: no built client bundle at $BUNDLE_DIR -- install will report it and the shell will answer STATIC.NOBUNDLE until one is built and the container restarted"
fi

# Whether this start compiles the roster's test-scope package (AD-17): only when PID 1's
# environment carries OCUPILOT_LOAD_TESTS=1, read the way OCUPILOT_DEMO is above.
# scripts/ci-throwaway.sh sets it for the suite; this repository's docker-compose.yml does not,
# so a product start compiles no test class. Any other value, or none, is a product start.
#
# A product start compiles a copy of the source tree that leaves out each folder the roster
# declares `scope: test` (OcuPilot.Install.Roster, AD-17's one source). The folders are asked
# of the roster this start is about to compile: Roster.cls is loaded and compiled on its own,
# its Get() is read, and each test-scope `.PKG` resource's package names its folder under the
# sources root. A roster that cannot be read, or a folder it names that the tree does not
# carry, fails the start rather than compiling test classes into it. Every command here
# captures its own stderr, for the reason the header gives. No `##class` on a piped line follows
# a space: bash 3.2 reads ` #` inside `$( )` as a comment and the file then fails to parse.
#
# A product start also deletes those packages, subpackages included, from the install namespace
# before it compiles, so test classes an earlier start compiled into a reused volume do not
# survive it (DW-1885). It logs how many classes it deleted, 0 included. A package the namespace
# maps in from another database is never deleted, since $System.OBJ.DeletePackage deletes through
# a mapping; only each package's own mapping is read, not a subpackage's. That, a delete that
# fails, or a class of the package still there afterwards fails the start before anything is
# compiled, so no start reaches STARTPATH-OK with part of the package left.
LOAD_TESTS_FLAG=$(tr '\0' '\n' < /proc/1/environ 2>/dev/null | grep '^OCUPILOT_LOAD_TESTS=' | cut -d= -f2-)
LOAD_DIR="$SRC_DIR"
PRODUCT_SRC="/tmp/ocupilot-product-src"
rm -rf "$PRODUCT_SRC" >/dev/null 2>&1 || true
if [ "$LOAD_TESTS_FLAG" = "1" ]; then
    echo "container-start: OCUPILOT_LOAD_TESTS is 1, so this start compiles the whole source tree, the roster's test-scope package included"
else
    SCOPE_RAW=$(iris session iris -U "$INSTALL_NS" 2>&1 <<EOF
Set tSC = \$System.OBJ.Load("$SRC_DIR/OcuPilot/Install/Roster.cls", "ck-d")
Set tSC = \$Select(\$System.Status.IsOK(tSC):##class(OcuPilot.Install.Roster).Get(.tRoster), 1: tSC)
Set tIt = \$Select('\$System.Status.IsOK(tSC): "", '\$IsObject(tRoster.resources): "", 1: tRoster.resources.%GetIterator())
Set tDirs = "" If \$IsObject(tIt) { While tIt.%GetNext(.tKey, .tRes) { If \$IsObject(tRes) && (tRes.scope = "test") { Set tDirs = tDirs _ \$Select(tDirs = "": "", 1: ",") _ \$Translate(\$Piece(tRes.name, ".PKG", 1), ".", "/") } } }
Write "OCUPILOT-"_"SCOPE-START:"_\$Select('\$System.Status.IsOK(tSC): "FAILED:" _ \$System.Status.GetErrorText(tSC), '\$IsObject(tIt): "FAILED:the roster declares no resources array", 1: "OK:" _ tDirs)_":OCUPILOT-"_"SCOPE-END",!
Halt
EOF
) || { echo "container-start: iris session failed while reading the roster's test-scope package"; print_tail "roster" "$SCOPE_RAW"; exit 1; }
    SCOPE=$(printf '%s' "$SCOPE_RAW" | tr '\r\n' '  ' | grep -o 'OCUPILOT-SCOPE-START:.*:OCUPILOT-SCOPE-END' | sed -e 's/^OCUPILOT-SCOPE-START://' -e 's/:OCUPILOT-SCOPE-END$//')
    case "$SCOPE" in
        OK:*)
            TEST_DIRS="${SCOPE#OK:}"
            ;;
        FAILED:*)
            echo "container-start: could not read the roster's test-scope package (${SCOPE#FAILED:}); failing the start rather than compiling test classes into a product start"
            exit 1
            ;;
        *)
            echo "container-start: the roster session wrote no verdict on the test-scope package; failing the start rather than compiling test classes into a product start"
            print_tail "roster" "$SCOPE_RAW"
            exit 1
            ;;
    esac
    if [ -z "$TEST_DIRS" ]; then
        echo "container-start: the roster declares no test-scope package, so this start compiles the whole source tree"
    else
        # Splitting on commas drops a trailing empty name, which the per-folder check below would
        # then never see; an empty name here fails the start before anything is copied or deleted.
        case ",$TEST_DIRS," in
            *,,*)
                echo "container-start: the roster's test-scope packages map to '$TEST_DIRS', which names an empty folder; failing the start"
                exit 1
                ;;
        esac
        COPY_OUT=$( { cp -R "$SRC_DIR" "$PRODUCT_SRC" && chmod -R u+w "$PRODUCT_SRC"; } 2>&1 ) || { echo "container-start: could not copy $SRC_DIR to $PRODUCT_SRC ($COPY_OUT); failing the start rather than compiling test classes into a product start"; exit 1; }
        # The list is split on commas with globbing off, so a name is never expanded against
        # whatever directory this script runs in.
        set -f
        OLD_IFS="$IFS"
        IFS=','
        for TEST_DIR in $TEST_DIRS; do
            case "$TEST_DIR" in
                ""|/*|*[!A-Za-z0-9/]*)
                    echo "container-start: the roster's test-scope package maps to '$TEST_DIR', which is not a folder name; failing the start"
                    exit 1
                    ;;
            esac
            if [ ! -d "$PRODUCT_SRC/$TEST_DIR" ]; then
                echo "container-start: the roster's test-scope package maps to $TEST_DIR, which is not a folder of $SRC_DIR; failing the start rather than guessing what to leave out"
                exit 1
            fi
            RM_OUT=$(rm -rf "$PRODUCT_SRC/$TEST_DIR" 2>&1) || { echo "container-start: could not leave $TEST_DIR out of $PRODUCT_SRC ($RM_OUT); failing the start"; exit 1; }
            echo "container-start: OCUPILOT_LOAD_TESTS is not 1, so this start leaves the roster's test-scope folder $TEST_DIR out of the compile"
        done
        IFS="$OLD_IFS"
        set +f
        # Every folder has passed the name check above, so the list is safe to interpolate.
        TEST_PKGS=$(printf '%s' "$TEST_DIRS" | tr '/' '.')
        PURGE_RAW=$(iris session iris -U "$INSTALL_NS" 2>&1 <<EOF
Set tPkgs = \$Translate("$TEST_DIRS", "/", ".")
Set tHome=##class(%SYS.Namespace).GetRoutineDest()
Set tMapped = "" For tI = 1:1:\$Length(tPkgs, ",") { Set tDest=##class(%SYS.Namespace).GetPackageDest(, \$Piece(tPkgs, ",", tI)) Set tMapped = tMapped _ \$Select(tDest = tHome: "", 1: ", " _ \$Piece(tPkgs, ",", tI) _ " from " _ tDest) }
Set tCountSQL = "SELECT COUNT(*) FROM %Dictionary.ClassDefinition WHERE %EXACT(ID) %STARTSWITH ?"
Set tBefore = 0, tCounted = 1 For tI = 1:1:\$Length(tPkgs, ",") { Set tRS=##class(%SQL.Statement).%ExecDirect(, tCountSQL, \$Piece(tPkgs, ",", tI) _ ".") Set tCounted = tCounted && tRS.%Next() Set tBefore = tBefore + \$Select(tCounted: tRS.%GetData(1), 1: 0) }
Set tSC = \$Select((tMapped = "") && tCounted: \$System.OBJ.DeletePackage(tPkgs, "-d"), 1: 1)
Set tLeftSQL = "SELECT (SELECT COUNT(*) FROM %Dictionary.ClassDefinition WHERE %EXACT(ID) %STARTSWITH ?) + (SELECT COUNT(*) FROM %Dictionary.CompiledClass WHERE %EXACT(ID) %STARTSWITH ?)"
Set tLeft = 0 For tI = 1:1:\$Length(tPkgs, ",") { Set tRS=##class(%SQL.Statement).%ExecDirect(, tLeftSQL, \$Piece(tPkgs, ",", tI) _ ".", \$Piece(tPkgs, ",", tI) _ ".") Set tCounted = tCounted && tRS.%Next() Set tLeft = tLeft + \$Select(tCounted: tRS.%GetData(1), 1: 0) }
Write "OCUPILOT-"_"PURGE-START:"_\$Select(tMapped = "": \$Select(tCounted = 0: "FAILED:the classes of the package could not be counted", \$System.Status.IsOK(tSC) = 0: "FAILED:" _ \$System.Status.GetErrorText(tSC), tLeft > 0: "LEFT:" _ tLeft, 1: "OK:" _ tBefore), 1: "MAPPED:" _ \$Extract(tMapped, 3, *))_":OCUPILOT-"_"PURGE-END",!
Halt
EOF
) || { echo "container-start: iris session failed while deleting the roster's test-scope package $TEST_PKGS"; print_tail "test-scope delete" "$PURGE_RAW"; exit 1; }
        PURGE=$(printf '%s' "$PURGE_RAW" | tr '\r\n' '  ' | grep -o 'OCUPILOT-PURGE-START:.*:OCUPILOT-PURGE-END' | sed -e 's/^OCUPILOT-PURGE-START://' -e 's/:OCUPILOT-PURGE-END$//')
        case "$PURGE" in
            OK:*)
                echo "container-start: OCUPILOT_LOAD_TESTS is not 1, so this start deleted ${PURGE#OK:} class(es) of the roster's test-scope package $TEST_PKGS from $INSTALL_NS"
                ;;
            MAPPED:*)
                echo "container-start: the roster's test-scope package is mapped into $INSTALL_NS from another database (${PURGE#MAPPED:}), and deleting it there would delete it for every namespace that maps it; failing the start rather than deleting it or leaving test classes on a product start"
                exit 1
                ;;
            LEFT:*)
                echo "container-start: ${PURGE#LEFT:} class(es) of the roster's test-scope package $TEST_PKGS are still in $INSTALL_NS after the delete; failing the start rather than leaving test classes on a product start"
                exit 1
                ;;
            FAILED:*)
                echo "container-start: could not delete the roster's test-scope package $TEST_PKGS from $INSTALL_NS (${PURGE#FAILED:}); failing the start rather than leaving test classes on a product start"
                exit 1
                ;;
            *)
                echo "container-start: the delete session wrote no verdict on the roster's test-scope package; failing the start rather than leaving test classes on a product start"
                print_tail "test-scope delete" "$PURGE_RAW"
                exit 1
                ;;
        esac
        LOAD_DIR="$PRODUCT_SRC"
    fi
fi

# Load and compile the source tree chosen above, then invoke the one hook entry
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
# to interpret, except `$LOAD_DIR`, `$DEMO_ARG` and `$BUNDLE_ARG`, which the shell substitutes.
RESULT_RAW=$(iris session iris -U "$INSTALL_NS" 2>&1 <<EOF
Set tSC = \$System.OBJ.LoadDir("$LOAD_DIR", "ck", .tErrors, 1)
Set tLoadOK = \$System.Status.IsOK(tSC)
Set tLoadErr = \$Select(tLoadOK: "", 1: \$System.Status.GetErrorText(tSC))
Set tSC2 = \$Select(tLoadOK:##class(OcuPilot.Install.Installer).StartPath($DEMO_ARG, "$BUNDLE_ARG"), 1: tSC)
Set tStartOK = \$Select(tLoadOK: \$System.Status.IsOK(tSC2), 1: 0)
Set tStartErr = \$Select(tStartOK: "", 1: \$System.Status.GetErrorText(tSC2))
Set tOutcome = \$Select(tLoadOK: \$Select(tStartOK: "STARTPATH-OK", 1: "STARTPATH-FAILED:" _ tStartErr), 1: "LOAD-FAILED:" _ tLoadErr)
Write "OCUPILOT-"_"RESULT-START:"_tOutcome_":OCUPILOT-"_"RESULT-END",!
Halt
EOF
) || { echo "container-start: iris session failed while loading and starting OcuPilot"; print_tail "load and start" "$RESULT_RAW"; exit 1; }
# The product copy has been read; a later start makes its own.
rm -rf "$PRODUCT_SRC" >/dev/null 2>&1 || true
# Fix Pack F-2: grep -o matches only within one line, and $System.Status.GetErrorText
# on a multi-document compile failure can span lines -- collapsing CR/LF to spaces
# BEFORE the marker search means a multi-line error no longer defeats it (a multi-line
# error previously left RESULT empty, falling through to the generic
# "install did not complete" message below even on a LOAD-FAILED outcome, which is
# exactly the misleading case that branch's own message was added to avoid).
RESULT_FLAT=$(printf '%s' "$RESULT_RAW" | tr '\r\n' '  ')
RESULT=$(printf '%s' "$RESULT_FLAT" | grep -o 'OCUPILOT-RESULT-START:.*:OCUPILOT-RESULT-END' | sed -e 's/^OCUPILOT-RESULT-START://' -e 's/:OCUPILOT-RESULT-END$//')

echo "container-start: $RESULT"

case "$RESULT" in
    STARTPATH-OK*)
        # DW-72, the health half: record that THIS container start's install succeeded, in
        # the one place container-health.sh looks. Written to a temporary name and renamed,
        # so the health check never reads half a marker. A start that cannot record it
        # would never be reported healthy, so it fails loudly instead.
        KEY=$(start_key) || KEY=""
        if [ -z "$KEY" ]; then
            echo "container-start: install completed, but this container start could not be identified (/proc/sys/kernel/random/boot_id, /proc/1/stat), so the health check could never pass; failing the start"
            exit 1
        fi
        if ! { printf '%s\n' "$KEY" > "$START_MARKER.$$" && mv -f "$START_MARKER.$$" "$START_MARKER"; }; then
            rm -f "$START_MARKER.$$" 2>/dev/null || true
            echo "container-start: install completed, but $START_MARKER could not be written, so the health check could never pass; failing the start"
            exit 1
        fi
        echo "container-start: recorded this container start's successful install for the health check"
        exit 0
        ;;
    LOAD-FAILED*)
        # Review finding: a compile error happens before Install() ever runs, so
        # there is no version row yet to point at -- the generic message below would
        # be misleading here specifically.
        echo "container-start: compiling src/OcuPilot/ failed before install could run; see the load error above"
        exit 1
        ;;
    "")
        # Fix Pack F-2 (round 2): the marker is never written at all -- a
        # <CLASS DOES NOT EXIST> on StartPath, an <UNDEFINED> before the Write -- RESULT
        # is empty here, and used to fall to the generic *) message below, which sends
        # the operator to "the phase and failing step recorded on the version row" for
        # a run that never touched it. Named explicitly instead.
        echo "container-start: no result marker was found in the session output -- install may have crashed before it could report anything"
        print_tail "load and start" "$RESULT_RAW"
        exit 1
        ;;
    *)
        echo "container-start: install did not complete; the failing step is named above and on the version row, where one could be written"
        exit 1
        ;;
esac
