#!/bin/sh
# Run ONE OcuPilot %UnitTest class inside a container, or list the classes there are to run.
# `ui/tools/ci-runner.mjs` is the serializer that calls this once per class and decides the
# job's verdict; this script is the primitive that reaches the instance.
#
# It lives here rather than inside the Node runner for the reason every other `iris session`
# in this repository does (`container-start.sh`, `container-health.sh`, `smoke.sh`): the
# ObjectScript a shell pipes into a session is shell-level code, and this is where that code
# lives. It also keeps `^UnitTestRoot` -- the vendor's own unit-test root global, which
# `scripts/check-objectscript.py` carries on its inherited rename-checklist token list because
# the sibling projects set it -- out of the `ui/` tree that checker scans, rather than being
# smuggled past the guard by assembling the name at runtime.
#
# Usage:
#   sh scripts/ci-unit-test.sh --container NAME [--namespace NS] --class OcuPilot.Test.Wire
#   sh scripts/ci-unit-test.sh --container NAME [--namespace NS] --list [--package OcuPilot.Test]
#
# It prints the session output verbatim, markers included, and never decides a run's verdict
# itself: deciding what a run means is the runner's job, and a script that exited non-zero on a
# failing test would hide the marker the runner needs to tell "failed" from "never reported". It
# does exit non-zero when the CONTAINER cannot be reached, because `set -e` aborts on the
# `docker exec` itself -- and that is the right answer there: no marker exists to read.
#
# Every marker is written split ("OCUPILOT-"_"RUN-START:"), the discipline container-start.sh
# records: when a line fails, `iris session` echoes that line's source back with the error, and
# a whole marker in the echo was once taken for the result.
set -e

CONTAINER=""
NAMESPACE="HSCUSTOM"
CLASSNAME=""
PACKAGE="OcuPilot.Test"
MODE="run"

while [ $# -gt 0 ]; do
    case "$1" in
        --container) CONTAINER="$2"; shift 2 ;;
        --namespace) NAMESPACE="$2"; shift 2 ;;
        --class) CLASSNAME="$2"; shift 2 ;;
        --package) PACKAGE="$2"; shift 2 ;;
        --list) MODE="list"; shift ;;
        *) echo "ci-unit-test: unknown argument $1"; exit 2 ;;
    esac
done

[ -n "$CONTAINER" ] || { echo "ci-unit-test: --container is required"; exit 2; }
if [ "$MODE" = "run" ] && [ -z "$CLASSNAME" ]; then
    echo "ci-unit-test: --class is required unless --list is given"
    exit 2
fi

# A class name is a dotted identifier and nothing else. Checked rather than trusted: the value
# is interpolated into the ObjectScript below, and a name carrying a quote would end the string
# literal it sits in.
case "$MODE:$CLASSNAME" in
    run:*[!A-Za-z0-9.%]*) echo "ci-unit-test: '$CLASSNAME' is not a class name"; exit 2 ;;
esac
case "$PACKAGE" in
    *[!A-Za-z0-9.%]*) echo "ci-unit-test: '$PACKAGE' is not a package name"; exit 2 ;;
esac

# The listing is "every class the framework would run", not "every %UnitTest.TestCase subclass".
# The EXISTS clause is the difference and it is load-bearing: `OcuPilot.Test.Http` is the suite's
# over-the-wire CLIENT, a helper that extends TestCase for its assertion macros and declares no
# test method at all. Discovered, it runs nothing, and the runner's own "a class that asserted
# nothing is a failure" rule -- which is the rule that matters -- then fails the job over a helper.
# Excluding a class with no Test* method keeps both properties: a helper is never discovered, and
# a real test class that ran nothing is still a failure.
if [ "$MODE" = "list" ]; then
    # PrimarySuper, not Super: Super holds a class's OWN declared superclasses, so a test class
    # reaching %UnitTest.TestCase through a project base class would not be discovered and the
    # job would go green having run fewer classes than the tree carries. PrimarySuper holds the
    # whole chain, "~"-delimited (verified on this build), which is why the match is anchored on
    # the delimiters rather than on the bare name.
    docker exec -i "$CONTAINER" iris session iris -U "$NAMESPACE" 2>&1 <<EOF
Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledClass c WHERE c.Name %STARTSWITH ? AND c.PrimarySuper [ '~%UnitTest.TestCase~' AND c.Abstract = 0 AND EXISTS (SELECT 1 FROM %Dictionary.CompiledMethod m WHERE m.parent = c.Name AND m.Name %STARTSWITH 'Test') ORDER BY c.Name", "$PACKAGE.")
Set tNames = ""
For  Quit:'tRS.%Next()  Set tNames = tNames_\$Select(tNames="":"",1:",")_tRS.%GetData(1)
Write "OCUPILOT-"_"LIST-START:"_tNames_":OCUPILOT-"_"LIST-END",!
Halt
EOF
    exit 0
fi

# Direct-mode ObjectScript: `iris session` executes each piped line as its own top-level
# command, so no brace-delimited block may span lines (verified in container-start.sh). The
# result walk is therefore one line of nested argumentless `For`s.
#
# Three things about the invocation are load-bearing, and each was established by running it:
#
# - The test root must name a directory that exists. Unset, %UnitTest.Manager.Root() answers a
#   path under the install directory that this image does not carry.
# - `/norecursive` is required. Without it the manager walks the root's subdirectories, finds
#   nothing, records an instance with no suite at all, and prints "All PASSED" having run
#   nothing -- a vacuous green that no count could contradict, because there were no counts.
# - The suite half of the test spec is left empty (`:<class>`), which the manager records as
#   the suite "(root)". Naming the class as the SUITE instead makes it resolve a directory of
#   that name and refuse with "Directory name ... is invalid".
#
# The counts come from ^UnitTest.Result rather than from RunTest's own status, which reports
# whether the RUN happened and not whether the assertions passed. Each method node holds a
# \$LIST whose first element is the pass flag.
docker exec -i "$CONTAINER" iris session iris -U "$NAMESPACE" 2>&1 <<EOF
Set ^UnitTestRoot = \$System.Util.ManagerDirectory()
Set tBefore = \$Order(^UnitTest.Result(""), -1)
Write "OCUPILOT-"_"PROBEAPPS-BEFORE-START:"_##class(OcuPilot.Test.ProbeApps).Existing()_":OCUPILOT-"_"PROBEAPPS-BEFORE-END",!
Set tSC = ##class(%UnitTest.Manager).RunTest(":$CLASSNAME", "/noload/nodelete/norecursive")
Set tRun = \$Order(^UnitTest.Result(""), -1)
Set tTotal = 0
Set tFailed = 0
; "Landed" means THIS run landed, not "some run is in the global". Compared against the index
; taken before RunTest: a run that recorded nothing leaves the previous class's index highest,
; and reading that as this class's result reported the previous class's counts as this one's --
; a pass attributed to a class that never ran. The RunTest status is carried too, so a refused
; run is distinguishable from one that executed and asserted nothing.
Set tLanded = \$Select(tRun="":0,tRun=tBefore:0,1:1)
Set tRunOK = ''\$System.Status.IsOK(tSC)
Set tSuite = ""
For  Set tSuite = \$Order(^UnitTest.Result(tRun, tSuite)) Quit:tSuite=""  Set tCase = "" For  Set tCase = \$Order(^UnitTest.Result(tRun, tSuite, tCase)) Quit:tCase=""  Set tMethod = "" For  Set tMethod = \$Order(^UnitTest.Result(tRun, tSuite, tCase, tMethod)) Quit:tMethod=""  Set tTotal = tTotal + 1 Set tFailed = tFailed + '\$ListGet(^UnitTest.Result(tRun, tSuite, tCase, tMethod), 1)
Write "OCUPILOT-"_"RUN-START:"_tRun_":"_tTotal_":"_tFailed_":"_tLanded_":"_tRunOK_":OCUPILOT-"_"RUN-END",!
; DW-243: why the run failed, from THIS run's own index only (tRun, and only when it landed). A
; method node is \$LB(status, duration, action, error) and each assertion under it is
; \$LB(status, action, description, location); a class node carries an action only when the
; class's own setup or teardown raised. One JSON array, one marker line.
Set tFails = []
If tLanded Set tSuite = "" For  Set tSuite = \$Order(^UnitTest.Result(tRun, tSuite)) Quit:tSuite=""  Set tCase = "" For  Set tCase = \$Order(^UnitTest.Result(tRun, tSuite, tCase)) Quit:tCase=""  Set tCaseNode = ^UnitTest.Result(tRun, tSuite, tCase) Do:('\$ListGet(tCaseNode, 1))&&(\$ListGet(tCaseNode, 3)'="") tFails.%Push({"class": (tCase), "method": "", "action": (\$ListGet(tCaseNode, 3)), "error": (\$ListGet(tCaseNode, 4)), "asserts": []}) Set tMethod = "" For  Set tMethod = \$Order(^UnitTest.Result(tRun, tSuite, tCase, tMethod)) Quit:tMethod=""  Set tNode = ^UnitTest.Result(tRun, tSuite, tCase, tMethod) If '\$ListGet(tNode, 1) Set tFail = {"class": (tCase), "method": (tMethod), "action": (\$ListGet(tNode, 3)), "error": (\$ListGet(tNode, 4)), "asserts": []} Do tFails.%Push(tFail) Set tA = "" For  Set tA = \$Order(^UnitTest.Result(tRun, tSuite, tCase, tMethod, tA)) Quit:tA=""  Set tAssert = ^UnitTest.Result(tRun, tSuite, tCase, tMethod, tA) If '\$ListGet(tAssert, 1) Do tFail.asserts.%Push({"action": (\$ListGet(tAssert, 2)), "description": (\$ListGet(tAssert, 3)), "location": (\$ListGet(tAssert, 4))})
Write "OCUPILOT-"_"FAILS-START:"_tFails.%ToJSON()_":OCUPILOT-"_"FAILS-END",!
; DW-242: the probe profile's web applications still on the instance once the class has torn
; down, beside the answer taken before RunTest so the runner blames the class that added one.
; Any leftover fails the run; a failed check prints no marker, or "error: ...", and fails it too.
Write "OCUPILOT-"_"PROBEAPPS-START:"_##class(OcuPilot.Test.ProbeApps).Existing()_":OCUPILOT-"_"PROBEAPPS-END",!
Halt
EOF
exit 0
