#!/bin/sh
# Build OcuPilot's distributable IPM archive on one throwaway instance, then prove that archive
# installs on a second, freshly created one (Story 13.3; AD-18, AD-27, AD-45).
#
# **Nothing here uploads anything anywhere, and nothing here can.** The archive is produced by
# IPM's local `package` verb -- the module lifecycle run to completion, minus the upload -- and
# both containers run with `--network none`, so each has a loopback interface and nothing else.
# No credential, token or repository row is read, written or asked for: this script asserts that
# `%IPM_Repo.Definition` is EMPTY on both instances, after the IPM import and again after every
# verb, which is what turns "resolved nothing from a package registry" from a promise into a
# measurement over the phases rather than a snapshot taken before them. The archive crosses from one container to
# the other by `docker cp`, which is not network.
#
# The three IPM verbs it issues are `load`, `package` and `list`, and `ui/tools/ipm-archive.test.mjs`
# holds that set equal to its declared allow-list in both directions.
#
# Measured on the pinned image (IPM 0.10.5), not recalled:
#   - `package <module> -path X` writes `X.tgz`, a sibling of the directory `X` it also creates.
#   - It prints no line naming that file. So the artifact is READ BACK from the container's own
#     output directory, where exactly one `.tgz` is required; its name is never predicted.
#   - The archive re-roots class members under `src/cls/`, carries `ui/dist/ocupilot-ui/browser/`
#     at its repository-relative path, and omits every `Scope="test"` resource.
#   - IPM re-serializes the manifest on export: attribute order becomes its own, and both the
#     default `<Packaging>` element and `<SystemRequirements>` are dropped. So the manifest check
#     below is STRUCTURAL, over the declarations the roster owns, never a byte comparison, and
#     `<SystemRequirements>` is outside the compared set because no export carries it.
#
# The container idiom -- argument refusals, a cleanup trap, the bounded readiness loop, split
# markers and `grep -o`/`sed` extraction -- is scripts/ci-image-compile.sh's, deliberately. The
# trap covers `INT` and `TERM` as well as `EXIT`, because an uncaught interrupt would otherwise
# leave two IRIS containers running under names a later run removes without asking.
#
# Usage:
#   sh scripts/ci-ipm-archive.sh --image intersystems/irishealth-community:2026.2
#      [--dir /tmp/ocupilot-ipm] [--build-name NAME] [--install-name NAME]
set -e

IMAGE=""
DIR="${OCUPILOT_IPM_DIR:-/tmp/ocupilot-ipm}"
BUILD_NAME="ocupilot-ipm-build"
INSTALL_NAME="ocupilot-ipm-install"
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUNDLE="ui/dist/ocupilot-ui/browser"
# Where `package` writes inside the build container, and the directory it writes into. The
# directory is made empty first so that "exactly one .tgz is here" identifies the artifact.
OUT_DIR="/tmp/ocupilot-package"
OUT_PATH="$OUT_DIR/ocupilot"

while [ $# -gt 0 ]; do
    case "$1" in
        --image) IMAGE="$2"; shift 2 ;;
        --dir) DIR="$2"; shift 2 ;;
        --build-name) BUILD_NAME="$2"; shift 2 ;;
        --install-name) INSTALL_NAME="$2"; shift 2 ;;
        *) echo "ci-ipm-archive: unknown argument $1"; exit 2 ;;
    esac
done

[ -n "$IMAGE" ] || { echo "ci-ipm-archive: --image is required"; exit 2; }
case "$IMAGE" in
    *:latest|*:latest-*) echo "ci-ipm-archive: refusing the floating tag in '$IMAGE'; AD-27 requires an explicit one"; exit 2 ;;
esac
# A reference with no tag at all is the floating `:latest` under another spelling, and the
# patterns above need a colon to see it. Tested on the segment after the last "/", because the
# colon in a registry host:port is not a tag.
case "${IMAGE##*/}" in
    *:*) ;;
    *) echo "ci-ipm-archive: '$IMAGE' names no tag, which Docker resolves to :latest; AD-27 requires an explicit one"; exit 2 ;;
esac

# The six containers this script must never touch: the live instance, the three owner-managed slot
# dev instances, and the three per-slot throwaways a parallel runner is using right now. Both of
# this script's own containers are checked, because `cleanup` removes BOTH by name and a trap that
# fires after a bad argument would otherwise remove somebody else's instance.
refuse_taken_name() {
    case "$2" in
        "") echo "ci-ipm-archive: $1 cannot be empty"; exit 2 ;;
        ocupilot) echo "ci-ipm-archive: $1 '$2' is the live container's own name; this script removes what it names, so it never takes it"; exit 2 ;;
        ocupilot-slot-*) echo "ci-ipm-archive: $1 '$2' is a slot dev instance's name; this script removes what it names, so it never takes it"; exit 2 ;;
        ocupilot-ci|ocupilot-b-ci|ocupilot-c-ci) echo "ci-ipm-archive: $1 '$2' is a slot's throwaway, which belongs to whoever brought it up; this script never takes it"; exit 2 ;;
    esac
}
refuse_taken_name "--build-name" "$BUILD_NAME"
refuse_taken_name "--install-name" "$INSTALL_NAME"
if [ "$BUILD_NAME" = "$INSTALL_NAME" ]; then
    echo "ci-ipm-archive: --build-name and --install-name are both '$BUILD_NAME'; the install target must be a SECOND, fresh instance"
    exit 2
fi

# $DIR is removed recursively below and is caller-supplied, the same hazard ci-throwaway.sh names.
# Scratch roots only, and never the root of one.
case "$DIR" in
    *..*) echo "ci-ipm-archive: '$DIR' contains '..', which walks out of any root this could check; this directory is removed recursively, so it must name its scratch root directly"; exit 2 ;;
esac
# The $TMPDIR arm is written with its own separator rather than appended raw: a TMPDIR of `/tmp`
# would otherwise make `/tmpanything` a sibling that passes as if it were inside.
SCRATCH_TMPDIR="${TMPDIR:-/nonexistent-tmpdir}"
SCRATCH_TMPDIR="${SCRATCH_TMPDIR%/}"
case "$DIR" in
    /tmp/?*|/private/tmp/?*|"$SCRATCH_TMPDIR"/?*) ;;
    *) echo "ci-ipm-archive: '$DIR' is not under a scratch root; this directory is removed recursively, so it must be under /tmp, /private/tmp or \$TMPDIR"; exit 2 ;;
esac

# Only now, with both names known to be this script's own.
cleanup() {
    docker rm -f "$BUILD_NAME" >/dev/null 2>&1 || true
    docker rm -f "$INSTALL_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

fail() {
    echo "ci-ipm-archive: FAILED in the $1 phase: $2"
    exit 1
}

# One marker's payload out of a session's whole output. The session echoes its own input, so every
# marker literal is written split (`"OCUPILOT-"_"X-START:"`) and cannot match here.
marker() {
    printf '%s' "$1" | tr '\r\n' '  ' | grep -o "OCUPILOT-$2-START:.*:OCUPILOT-$2-END" \
        | sed -e "s/^OCUPILOT-$2-START://" -e "s/:OCUPILOT-$2-END\$//"
}

# The instance is serving before it is ready for work; wait for it to answer at all.
wait_for_session() {
    ELAPSED=0
    until docker exec -i "$1" iris session iris -U %SYS <<'EOF' >/dev/null 2>&1
Write "up",!
Halt
EOF
    do
        ELAPSED=$((ELAPSED + 5))
        if [ "$ELAPSED" -ge 300 ]; then
            echo "ci-ipm-archive: $1 never answered a session in ${ELAPSED}s"
            docker logs "$1" 2>&1 | tail -n 40
            exit 1
        fi
        sleep 5
    done
    echo "ci-ipm-archive: $1 is answering after ${ELAPSED}s"
}

# IPM, imported from the offline copy the image already carries, and the repository table read
# back. AD-18: a stock instance carries no %IPM class at all, so this is the import that makes the
# two verbs below exist -- and it creates no repository row, which the marker proves rather than
# assumes.
import_ipm() {
    RAW=$(docker exec -i "$1" iris session iris -U HSCUSTOM 2>&1 <<'EOF'
Set tSC = $System.OBJ.Load("/usr/irissys/dist/install/misc/zpm.xml","ck")
Write "OCUPILOT-"_"IPM-START:"_$Select($System.Status.IsOK(tSC):"OK",1:"FAILED")_":OCUPILOT-"_"IPM-END",!
Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) FROM %IPM_Repo.Definition")
Write "OCUPILOT-"_"REPOSITORIES-START:"_$Select(tRS.%Next():tRS.%GetData(1),1:"unread")_":OCUPILOT-"_"REPOSITORIES-END",!
Halt
EOF
)
    IPM_OUTCOME=$(marker "$RAW" "IPM")
    REPOSITORIES=$(marker "$RAW" "REPOSITORIES")
    if [ "$IPM_OUTCOME" != "OK" ]; then
        printf '%s\n' "$RAW" | tail -n 30
        fail "$2" "IPM did not import on $1"
    fi
    if [ "$REPOSITORIES" != "0" ]; then
        fail "$2" "$1 carries $REPOSITORIES package-repository row(s) after an offline IPM import; this script requires zero, so that nothing it runs can resolve anything from one"
    fi
    echo "ci-ipm-archive: IPM imported on $1, with $REPOSITORIES package-repository row(s)"
}

# The same count, read again after a verb has run. Taken only once, at import, the zero would
# describe the instance BEFORE the phases it is offered as evidence about; every verb below is
# followed by this, so no row can appear and go unread.
assert_no_repositories() {
    RAW=$(docker exec -i "$1" iris session iris -U HSCUSTOM 2>&1 <<'EOF'
Set tRS = ##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) FROM %IPM_Repo.Definition")
Write "OCUPILOT-"_"REPOSITORIES-START:"_$Select(tRS.%Next():tRS.%GetData(1),1:"unread")_":OCUPILOT-"_"REPOSITORIES-END",!
Halt
EOF
)
    REPOSITORIES=$(marker "$RAW" "REPOSITORIES")
    if [ "$REPOSITORIES" != "0" ]; then
        fail "$2" "$1 carries $REPOSITORIES package-repository row(s) after $3; this script requires zero throughout, so that nothing it ran resolved anything from one"
    fi
    echo "ci-ipm-archive: $1 still carries $REPOSITORIES package-repository row(s) after $3"
}

# --- Before anything is staged, and before any container starts -------------------------------

# The manifest against the roster, in both directions, on the tree that is about to be staged. A
# hand-edited module.xml and an un-regenerated roster fail identically, and both fail here rather
# than inside an archive nobody opens.
echo "ci-ipm-archive: checking module.xml against src/OcuPilot/Install/Roster.cls"
MANIFEST_STATUS=0
( cd "$REPO_ROOT/ui" && node tools/ipm-manifest.mjs --check ) || MANIFEST_STATUS=$?
if [ "$MANIFEST_STATUS" -ne 0 ]; then
    echo "ci-ipm-archive: module.xml has drifted from the roster (exit $MANIFEST_STATUS); nothing was staged"
    exit 1
fi

if [ ! -d "$REPO_ROOT/$BUNDLE" ]; then
    echo "ci-ipm-archive: $BUNDLE is not there, and the manifest copies it into the package; run: cd ui && npm run build"
    exit 2
fi

# --- Staging ----------------------------------------------------------------------------------

echo "ci-ipm-archive: staging src/, module.xml and $BUNDLE into $DIR/module"
rm -rf "$DIR"
mkdir -p "$DIR/module/src" "$DIR/module/$BUNDLE" "$DIR/artifact" "$DIR/extract"
cp -R "$REPO_ROOT/src/." "$DIR/module/src/"
cp "$REPO_ROOT/module.xml" "$DIR/module/module.xml"
cp -R "$REPO_ROOT/$BUNDLE/." "$DIR/module/$BUNDLE/"
# The mount is read-only to the container, but IRIS's own uid still has to read it, and `cp`
# reproduces the invoking user's umask (ci-throwaway.sh makes the same adjustment, for the same
# reason: under an 077 the container cannot read what it was given).
chmod -R a+rX "$DIR/module"

# --- Phase 1: the archive ---------------------------------------------------------------------

echo "ci-ipm-archive: starting $BUILD_NAME from $IMAGE (no network, no port mapping, no durable volume)"
docker rm -f "$BUILD_NAME" >/dev/null 2>&1 || true
docker run -d --network none --name "$BUILD_NAME" -v "$DIR/module:/opt/ocupilot:ro" "$IMAGE" >/dev/null
wait_for_session "$BUILD_NAME"
import_ipm "$BUILD_NAME" "archive"

echo "ci-ipm-archive: loading the staged module on $BUILD_NAME"
LOAD_RAW=$(docker exec -i "$BUILD_NAME" iris session iris -U HSCUSTOM 2>&1 <<'EOF'
Set tSC = ##class(%IPM.Main).Shell("load -dev /opt/ocupilot",1,0)
Write "OCUPILOT-"_"MODULE-START:"_$Select($System.Status.IsOK(tSC):"OK",1:"FAILED")_":OCUPILOT-"_"MODULE-END",!
Halt
EOF
)
if [ "$(marker "$LOAD_RAW" "MODULE")" != "OK" ]; then
    printf '%s\n' "$LOAD_RAW" | tail -n 40
    fail "archive" "the staged module did not load on $BUILD_NAME"
fi

docker exec "$BUILD_NAME" sh -c "rm -rf '$OUT_DIR' && mkdir -p '$OUT_DIR'"
echo "ci-ipm-archive: running IPM's local package verb on $BUILD_NAME"
PACK_RAW=$(docker exec -i "$BUILD_NAME" iris session iris -U HSCUSTOM 2>&1 <<EOF
Set tSC = ##class(%IPM.Main).Shell("package ocupilot -path $OUT_PATH",1,0)
Write "OCUPILOT-"_"ARCHIVE-START:"_\$Select(\$System.Status.IsOK(tSC):"OK",1:"FAILED")_":OCUPILOT-"_"ARCHIVE-END",!
Halt
EOF
)
if [ "$(marker "$PACK_RAW" "ARCHIVE")" != "OK" ]; then
    printf '%s\n' "$PACK_RAW" | tail -n 40
    fail "archive" "the package verb did not complete on $BUILD_NAME"
fi

assert_no_repositories "$BUILD_NAME" "archive" "the load and package verbs"

# The artifact is READ back, never predicted: IPM 0.10.5 prints no line naming the file it wrote,
# so the output directory -- emptied above -- is listed and exactly one .tgz is required. Two would
# mean the name is ambiguous, and none would mean a phase reported success having produced nothing.
PRODUCED=$(docker exec "$BUILD_NAME" sh -c "ls -1 '$OUT_DIR' | grep '\\.tgz\$' || true")
COUNT=$(printf '%s\n' "$PRODUCED" | grep -c '[^[:space:]]' || true)
if [ "${COUNT:-0}" -ne 1 ]; then
    echo "ci-ipm-archive: $OUT_DIR holds ${COUNT:-0} archive(s): $(printf '%s' "$PRODUCED" | tr '\n' ' ')"
    fail "archive" "the package verb must leave exactly one .tgz; a phase that produced nothing is a failure, never a pass"
fi
ARTIFACT_NAME=$(printf '%s\n' "$PRODUCED" | head -n 1)
docker cp "$BUILD_NAME:$OUT_DIR/$ARTIFACT_NAME" "$DIR/artifact/$ARTIFACT_NAME"
chmod -R a+rX "$DIR/artifact"
ARCHIVE="$DIR/artifact/$ARTIFACT_NAME"
ARCHIVE_BYTES=$(wc -c < "$ARCHIVE" | tr -d ' ')
echo "ci-ipm-archive: $ARTIFACT_NAME is $ARCHIVE_BYTES bytes, copied to $ARCHIVE"

# --- What is in it, read host-side from the file itself ----------------------------------------

MEMBERS=$(tar tzf "$ARCHIVE")
count_members() { printf '%s\n' "$MEMBERS" | grep -c "$1" || true; }

if [ "$(count_members '^module\.xml$')" -lt 1 ]; then
    fail "archive" "$ARTIFACT_NAME carries no module.xml, so nothing can install it"
fi
CLASS_COUNT=$(count_members '^src/cls/OcuPilot/.*\.cls$')
STAGED_CLASSES=$(find "$DIR/module/src/OcuPilot" -name '*.cls' -not -path '*/Test/*' | grep -c '[^[:space:]]' || true)
if [ "${STAGED_CLASSES:-0}" -lt 1 ]; then
    fail "archive" "the staged tree holds no shippable class, so a comparison against it would pass having compared nothing"
fi
if [ "${CLASS_COUNT:-0}" -ne "${STAGED_CLASSES:-0}" ]; then
    fail "archive" "$ARTIFACT_NAME carries $CLASS_COUNT src/cls/OcuPilot/*.cls member(s) against $STAGED_CLASSES shippable class(es) staged; the archive must carry all of them, not some"
fi
# Every staged bundle file by name, rather than a count: the archive also carries directory
# entries, so a count on that side would not be comparing like with like.
MISSING_BUNDLE=""
BUNDLE_STAGED=0
for tFile in $(cd "$DIR/module/$BUNDLE" && find . -type f | sed 's#^\./##'); do
    BUNDLE_STAGED=$((BUNDLE_STAGED + 1))
    if [ "$(printf '%s\n' "$MEMBERS" | grep -c "^$BUNDLE/$tFile\$" || true)" -lt 1 ]; then
        MISSING_BUNDLE="$MISSING_BUNDLE $tFile"
    fi
done
if [ "$BUNDLE_STAGED" -lt 1 ]; then
    fail "archive" "the staged bundle holds no file, so a comparison against it would pass having compared nothing"
fi
if [ -n "$MISSING_BUNDLE" ]; then
    fail "archive" "$ARTIFACT_NAME is missing $(printf '%s' "$MISSING_BUNDLE" | wc -w | tr -d ' ') staged bundle file(s):$MISSING_BUNDLE"
fi
TEST_MEMBERS=$(printf '%s\n' "$MEMBERS" | grep 'OcuPilot/Test/' || true)
if [ -n "$TEST_MEMBERS" ]; then
    echo "ci-ipm-archive: $(printf '%s' "$TEST_MEMBERS" | head -n 5 | tr '\n' ' ')"
    fail "archive" "$ARTIFACT_NAME carries a member under OcuPilot/Test/, which Scope=\"test\" excludes from a shipped package"
fi
BUNDLE_COUNT=$BUNDLE_STAGED
echo "ci-ipm-archive: $ARTIFACT_NAME carries module.xml, all $CLASS_COUNT staged OcuPilot class(es), all $BUNDLE_COUNT staged bundle file(s) and no OcuPilot/Test/ member"

# The manifest that actually reached the archive, against the one the roster generated. IPM
# re-serializes on export, so this compares DECLARATIONS rather than bytes: the module name,
# version and sources root, and every attribute of every <Resource>, <FileCopy>, <Invoke>,
# <WebApplication> and <Dependency>, plus the <Arg> count. The roster side of the equality was
# held by the drift check above, before anything was staged.
tar xzf "$ARCHIVE" -C "$DIR/extract" module.xml
text_element() {
    printf '%s=%s\n' "$3" "$(sed -n "s#.*<$2>\\([^<]*\\)</$2>.*#\\1#p" "$1" | head -n 1)"
}
# One line per <Kind ...> element, carrying every attribute it declares, sorted. Newlines are
# flattened first so an element written across several lines is read whole.
element_lines() {
    tr '\n' ' ' < "$1" | grep -o "<$2 [^>]*>" | while IFS= read -r el; do
        printf '%s=' "$3"
        printf '%s' "$el" | grep -o '[A-Za-z]*="[^"]*"' | sort | tr '\n' '|'
        printf '\n'
    done | sort
}
declarations() {
    text_element "$1" Name name
    text_element "$1" Version version
    text_element "$1" SourcesRoot sourcesroot
    element_lines "$1" Resource resource
    element_lines "$1" FileCopy filecopy
    element_lines "$1" Invoke invoke
    element_lines "$1" WebApplication webapp
    element_lines "$1" Dependency dependency
    # <Arg> children are counted rather than read as elements, because the no-attribute form
    # `<Arg>x</Arg>` is not an element_lines match. AD-17: the roster's <Invoke> carries none, and
    # one appearing on either side is the difference between an install that unexpires _SYSTEM and
    # one that does not.
    printf 'argcount=%s\n' "$(grep -c '<Arg' "$1" || true)"
}
declarations "$REPO_ROOT/module.xml" > "$DIR/extract/declared-by-the-roster.txt"
declarations "$DIR/extract/module.xml" > "$DIR/extract/declared-in-the-archive.txt"
DECLARED=$(grep -c '[^[:space:]]' < "$DIR/extract/declared-by-the-roster.txt" || true)
if [ "${DECLARED:-0}" -lt 11 ]; then
    fail "archive" "the manifest comparison read only ${DECLARED:-0} declaration(s) from the roster's manifest, fewer than the 11 it declares; a comparison that read less than the file holds is a pass that means nothing"
fi
if ! diff -u "$DIR/extract/declared-by-the-roster.txt" "$DIR/extract/declared-in-the-archive.txt"; then
    fail "archive" "the manifest inside $ARTIFACT_NAME declares something other than what the roster does"
fi
echo "ci-ipm-archive: the archive's manifest declares the same $DECLARED item(s) as the roster's"

# --- Phase 2: the local installation on a second, fresh instance --------------------------------

echo "ci-ipm-archive: starting $INSTALL_NAME from $IMAGE (no network, no port mapping, no durable volume)"
docker rm -f "$INSTALL_NAME" >/dev/null 2>&1 || true
docker run -d --network none --name "$INSTALL_NAME" -v "$DIR/artifact:/opt/ocupilot-archive:ro" "$IMAGE" >/dev/null
wait_for_session "$INSTALL_NAME"
import_ipm "$INSTALL_NAME" "local-install"

echo "ci-ipm-archive: loading /opt/ocupilot-archive/$ARTIFACT_NAME on $INSTALL_NAME"
INSTALL_RAW=$(docker exec -i "$INSTALL_NAME" iris session iris -U HSCUSTOM 2>&1 <<EOF
Set tSC = ##class(%IPM.Main).Shell("load /opt/ocupilot-archive/$ARTIFACT_NAME",1,0)
Write "OCUPILOT-"_"INSTALLED-START:"_\$Select(\$System.Status.IsOK(tSC):"OK",1:"FAILED")_":OCUPILOT-"_"INSTALLED-END",!
Halt
EOF
)
if [ "$(marker "$INSTALL_RAW" "INSTALLED")" != "OK" ]; then
    printf '%s\n' "$INSTALL_RAW" | tail -n 40
    fail "local-install" "the archive did not load on $INSTALL_NAME"
fi

assert_no_repositories "$INSTALL_NAME" "local-install" "the archive install"

# What the instance itself now says it carries, in its own words. The module name is required in
# that answer: an archive that loaded and left nothing behind would otherwise read as a success.
LIST_RAW=$(docker exec -i "$INSTALL_NAME" iris session iris -U HSCUSTOM 2>&1 <<'EOF'
Set tSC = ##class(%IPM.Main).Shell("list",1,0)
Write "OCUPILOT-"_"LISTED-START:"_$Select($System.Status.IsOK(tSC):"OK",1:"FAILED")_":OCUPILOT-"_"LISTED-END",!
Halt
EOF
)
# IPM colors its own output, so the module line begins with an SGR escape rather than with the
# name. The escape character is built with printf rather than written into this file (Rule 14).
ESC=$(printf '\033')
LISTED=$(printf '%s\n' "$LIST_RAW" | tr -d '\r' | sed -e "s/${ESC}\[[0-9;]*m//g" | grep -i '^ocupilot[[:space:]]' || true)
if [ "$(marker "$LIST_RAW" "LISTED")" != "OK" ] || [ -z "$LISTED" ]; then
    printf '%s\n' "$LIST_RAW" | tail -n 30
    fail "local-install" "$INSTALL_NAME does not name the ocupilot module among the modules it carries"
fi
echo "ci-ipm-archive: $INSTALL_NAME reports: $LISTED"

# A fresh Community instance expires _SYSTEM on first login, and the manifest's <Invoke> carries no
# <Arg>, so Install()'s pUnexpire keeps its 0 default and an IPM installation deliberately leaves
# the account as it found it (AD-17). Clearing it is therefore an OPERATOR act, done here after the
# module is in and before the smoke run, or every HTTP check below would read 401. By name, never
# the all-users form.
UNEXPIRE_RAW=$(docker exec -i "$INSTALL_NAME" iris session iris -U %SYS 2>&1 <<'EOF'
Set tSC = ##class(Security.Users).UnExpireUserPasswords("_SYSTEM")
Write "OCUPILOT-"_"UNEXPIRED-START:"_$Select($System.Status.IsOK(tSC):"OK",1:"FAILED")_":OCUPILOT-"_"UNEXPIRED-END",!
Halt
EOF
)
if [ "$(marker "$UNEXPIRE_RAW" "UNEXPIRED")" != "OK" ]; then
    printf '%s\n' "$UNEXPIRE_RAW" | tail -n 20
    fail "local-install" "_SYSTEM could not be unexpired on $INSTALL_NAME, so every HTTP check would read 401"
fi
echo "ci-ipm-archive: _SYSTEM unexpired on $INSTALL_NAME by name -- the operator act an IPM installation leaves to the operator (AD-17)"

# The one smoke path (AD-45), asked of the instance the archive built. Its status is read from the
# command itself; a pipeline would report the last stage's status instead, so the output goes to a
# file and is printed afterwards.
SMOKE_STATUS=0
sh "$REPO_ROOT/scripts/smoke.sh" --container "$INSTALL_NAME" --user _SYSTEM --password SYS > "$DIR/smoke.log" 2>&1 || SMOKE_STATUS=$?
cat "$DIR/smoke.log"
EXECUTED=$(sed -n 's/.*executed=\([0-9][0-9]*\).*/\1/p' "$DIR/smoke.log" | tail -n 1)
if [ "$SMOKE_STATUS" -ne 0 ]; then
    fail "local-install" "smoke reported a verdict other than PASS on $INSTALL_NAME (exit $SMOKE_STATUS)"
fi
if [ "${EXECUTED:-0}" -lt 1 ]; then
    fail "local-install" "smoke executed ${EXECUTED:-0} check(s) on $INSTALL_NAME; zero executed checks is a failure, never a pass"
fi

echo "ci-ipm-archive: $ARTIFACT_NAME ($ARCHIVE_BYTES bytes, $CLASS_COUNT class(es), $BUNDLE_COUNT bundle member(s)) installed on a second fresh instance and smoke PASSED with $EXECUTED check(s) executed; no package registry was reachable from either container."
