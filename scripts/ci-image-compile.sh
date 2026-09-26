#!/bin/sh
# Compile src/OcuPilot/ on one stock InterSystems Community image and confirm the instance's own
# administration API reports v2 (Story 1.17, NFR-13, AD-27).
#
# **It compiles and probes; it does not install.** It answers, before anything else on that
# edition runs, that nothing in the tree is HealthShare-only and that the one vendor
# API OcuPilot depends on is present at the version it depends on. A compile failure here names a
# class OcuPilot could not build on that edition. The install on that edition is the images job's
# own later steps: a throwaway from scripts/ci-throwaway.sh, readiness, the admin API drift check
# over HTTP and smoke (Story 8.9).
#
# **The version is READ, not inferred from a class name.** The probe calls the port's own
# OcuPilot.Port.AdminPort.HighestDispatchVersion(AdminPort.AdminApiClass()), which parses %Api.Admin's UrlMap
# and takes the highest `Dispatch.v<N>` it forwards to -- the same read AdminPort makes at
# startup (AD-27). An earlier version tested `%Dictionary.CompiledClass.%ExistsId` for the v2
# dispatch class, which is a class name existing and not a version being reported; the header,
# the workflow and README all said "answers v2" over it.
#
# It stops short of issuing a request: the probe container publishes no port and the image ships
# no HTTP client. AD-27's "a named probe endpoint answers" is AdminPort's startup duty on a real
# instance, which the images job's own throwaway and the instance job exercise; this script's
# claim is the version and the compile.
#
# The container is a throwaway with its own project name, its own container name, no published
# ports at all and no start hook: it never installs, so it needs no health check and nothing it
# does can reach a live instance.
#
# Usage:
#   sh scripts/ci-image-compile.sh --image intersystems/iris-community:2026.2 [--name ocupilot-img]
set -e

IMAGE=""
NAME="ocupilot-image-probe"
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)

while [ $# -gt 0 ]; do
    case "$1" in
        --image) IMAGE="$2"; shift 2 ;;
        --name) NAME="$2"; shift 2 ;;
        *) echo "ci-image-compile: unknown argument $1"; exit 2 ;;
    esac
done

[ -n "$IMAGE" ] || { echo "ci-image-compile: --image is required"; exit 2; }
case "$IMAGE" in
    *latest-cd*|*:latest) echo "ci-image-compile: refusing a floating tag; AD-27 requires an explicit one"; exit 2 ;;
esac
# A reference with no tag at all is the floating `:latest` under another spelling, and the
# patterns above need a colon to see it. Tested on the segment after the last "/", because the
# colon in a registry host:port is not a tag.
case "${IMAGE##*/}" in
    *:*) ;;
    *) echo "ci-image-compile: '$IMAGE' names no tag, which Docker resolves to :latest; AD-27 requires an explicit one"; exit 2 ;;
esac
if [ "$NAME" = "ocupilot" ]; then
    echo "ci-image-compile: 'ocupilot' is the live container's own name; this probe never takes it"
    exit 2
fi

cleanup() {
    docker rm -f "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "ci-image-compile: starting $NAME from $IMAGE (no published port, no start hook)"
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" -v "$REPO_ROOT/src:/opt/ocupilot/src:ro" "$IMAGE" >/dev/null

# The instance is serving before it is ready for a compile; wait for it to answer at all.
ELAPSED=0
until docker exec "$NAME" iris session iris -U %SYS <<'EOF' >/dev/null 2>&1
Write "up",!
Halt
EOF
do
    ELAPSED=$((ELAPSED + 5))
    if [ "$ELAPSED" -ge 300 ]; then
        echo "ci-image-compile: $NAME never answered a session in ${ELAPSED}s"
        docker logs "$NAME" 2>&1 | tail -n 40
        exit 1
    fi
    sleep 5
done
echo "ci-image-compile: $NAME is answering after ${ELAPSED}s"

# The namespace this edition carries. The plain Community edition has no HSCUSTOM, which is
# itself part of what this job is checking: OcuPilot's own resolver falls back to USER, and a
# compile has to land somewhere that exists.
NS_RAW=$(docker exec -i "$NAME" iris session iris -U %SYS 2>&1 <<'EOF'
Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",##class(%SYS.Namespace).Exists("USER"):"USER",1:"")
Write "OCUPILOT-"_"NS-START:"_tNS_":OCUPILOT-"_"NS-END",!
Halt
EOF
)
NS=$(printf '%s' "$NS_RAW" | tr '\r\n' '  ' | grep -o 'OCUPILOT-NS-START:.*:OCUPILOT-NS-END' | sed -e 's/^OCUPILOT-NS-START://' -e 's/:OCUPILOT-NS-END$//')
if [ -z "$NS" ]; then
    echo "ci-image-compile: $IMAGE carries neither HSCUSTOM nor USER, so there is nowhere to compile into"
    printf '%s\n' "$NS_RAW" | tail -n 20
    exit 1
fi
echo "ci-image-compile: compiling into $NS"

RAW=$(docker exec -i "$NAME" iris session iris -U "$NS" 2>&1 <<'EOF'
Set tSC = $System.OBJ.LoadDir("/opt/ocupilot/src", "ck", .tErrors, 1)
Set tOK = $System.Status.IsOK(tSC)
Set tErr = $Select(tOK: "", 1: $System.Status.GetErrorText(tSC))
Set tCount = 0
Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH 'OcuPilot.'")
Set tCount = $Select(tRS.%Next(): tRS.%GetData(1), 1: 0)
Write "OCUPILOT-"_"COMPILE-START:"_$Select(tOK:"OK",1:"FAILED")_":"_tCount_":"_tErr_":OCUPILOT-"_"COMPILE-END",!
Set tApp = ##class(%Dictionary.CompiledClass).%ExistsId(##class(OcuPilot.Port.AdminPort).AdminApiClass())
Set tVer = 0
If tApp Set tVer = ##class(OcuPilot.Port.AdminPort).HighestDispatchVersion(##class(OcuPilot.Port.AdminPort).AdminApiClass())
Write "OCUPILOT-"_"ADMIN-START:"_+tApp_":"_+(tVer=2)_":"_+tVer_":OCUPILOT-"_"ADMIN-END",!
Halt
EOF
)
FLAT=$(printf '%s' "$RAW" | tr '\r\n' '  ')
COMPILE=$(printf '%s' "$FLAT" | grep -o 'OCUPILOT-COMPILE-START:.*:OCUPILOT-COMPILE-END' | sed -e 's/^OCUPILOT-COMPILE-START://' -e 's/:OCUPILOT-COMPILE-END$//')
ADMIN=$(printf '%s' "$FLAT" | grep -o 'OCUPILOT-ADMIN-START:.*:OCUPILOT-ADMIN-END' | sed -e 's/^OCUPILOT-ADMIN-START://' -e 's/:OCUPILOT-ADMIN-END$//')

if [ -z "$COMPILE" ]; then
    echo "ci-image-compile: the compile session reported nothing"
    printf '%s\n' "$RAW" | tail -n 40
    exit 1
fi

OUTCOME=$(printf '%s' "$COMPILE" | cut -d: -f1)
COUNT=$(printf '%s' "$COMPILE" | cut -d: -f2)
echo "ci-image-compile: compile $OUTCOME, $COUNT OcuPilot class(es) compiled on $IMAGE"

if [ "$OUTCOME" != "OK" ]; then
    echo "ci-image-compile: $(printf '%s' "$COMPILE" | cut -d: -f3-)"
    printf '%s\n' "$RAW" | grep -a -E '^<[A-Z]|ERROR #' | head -n 20 || true
    exit 1
fi
# A compile over nothing is a pass that means nothing -- the same rule every other gate here
# states about itself.
if [ "${COUNT:-0}" -lt 1 ]; then
    echo "ci-image-compile: 0 classes compiled; a clean compile over no class is a failure, never a pass"
    exit 1
fi

ADMIN_PRESENT=$(printf '%s' "$ADMIN" | cut -d: -f1)
ADMIN_V2=$(printf '%s' "$ADMIN" | cut -d: -f2)
ADMIN_VERSION=$(printf '%s' "$ADMIN" | cut -d: -f3)
echo "ci-image-compile: admin API present=$ADMIN_PRESENT reported version=$ADMIN_VERSION v2=$ADMIN_V2"
if [ "$ADMIN_PRESENT" != "1" ] || [ "$ADMIN_V2" != "1" ]; then
    echo "ci-image-compile: $IMAGE does not carry the v2 administration API OcuPilot reaches every screen through (AD-27)"
    exit 1
fi

echo "ci-image-compile: $IMAGE is green."
