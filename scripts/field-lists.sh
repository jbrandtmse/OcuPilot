#!/bin/sh
# Regenerates src/OcuPilot/Screen/Tool/FieldLists.cls from a running instance (Story 2.2, AD-3).
#
# The derivation is OcuPilot.Test.FieldDerive's, inside the instance; this script runs its
# Regenerate through `iris session`, takes the returned class source from between two markers,
# and writes it. A failed status, or a session that printed no complete source, exits 1 and
# leaves the file as it was. OcuPilot.Test.DerivedFields is the test that fails when the
# committed file and the instance disagree; this is how the file is brought back into line.
#
# Usage:
#   sh scripts/field-lists.sh --container ocupilot
#
# Options:
#   --container NAME   run inside this docker container (docker exec) -- required
#   --namespace NS     the namespace OcuPilot is installed in (default: HSCUSTOM)
#   --output FILE      where to write (default: src/OcuPilot/Screen/Tool/FieldLists.cls)
#
# Exit 0 when the file was written, 1 when the derivation failed, 2 for a caller error.
#
# Each marker is written split ("OCUPILOT-"_"FIELDS-...") so that a line `iris session` echoes
# back with an error cannot supply one.
set -e

CONTAINER=""
NAMESPACE="HSCUSTOM"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUTPUT="$ROOT/src/OcuPilot/Screen/Tool/FieldLists.cls"

while [ $# -gt 0 ]; do
    case "$1" in
        --container) CONTAINER="$2"; shift 2 ;;
        --namespace) NAMESPACE="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
        *) echo "field-lists: unknown argument $1"; exit 2 ;;
    esac
done

if [ -z "$CONTAINER" ]; then
    echo "field-lists: --container is required"
    exit 2
fi

case "$NAMESPACE" in
    *[!A-Za-z0-9%-]*|"") echo "field-lists: --namespace '$NAMESPACE' is not a namespace name"; exit 2 ;;
esac

RAW=$(docker exec -i "$CONTAINER" iris session iris -U "$NAMESPACE" 2>&1 <<'EOF' || true
Set tSC = ##class(OcuPilot.Test.FieldDerive).Regenerate(.tSource)
Write "OCUPILOT-"_"FIELDS-STATUS-START:"_$Select($System.Status.IsOK(tSC): "OK", 1: "FAILED "_$System.Status.GetErrorText(tSC))_":OCUPILOT-"_"FIELDS-STATUS-END",!
If $System.Status.IsOK(tSC) Write "OCUPILOT-"_"FIELDS-SOURCE-START",!,tSource,!,"OCUPILOT-"_"FIELDS-SOURCE-END",!
Halt
EOF
)

STATUS=$(printf '%s\n' "$RAW" | tr '\r\n' '  ' | grep -o 'OCUPILOT-FIELDS-STATUS-START:.*:OCUPILOT-FIELDS-STATUS-END' | sed -e 's/^OCUPILOT-FIELDS-STATUS-START://' -e 's/:OCUPILOT-FIELDS-STATUS-END$//' || true)

case "$STATUS" in
    OK) ;;
    FAILED*)
        echo "field-lists: the derivation failed; $OUTPUT is unchanged"
        printf '%s\n' "$STATUS" | sed -e 's/^FAILED /field-lists: | /'
        exit 1
        ;;
    *)
        echo "field-lists: no status marker was found in the session output; $OUTPUT is unchanged"
        printf '%s\n' "$RAW" | tail -n 30 | sed -e 's/^/field-lists: | /'
        exit 1
        ;;
esac

# Both markers must be present on lines of their own: a session cut short prints a start with no
# end, and writing what came before the cut would commit a truncated class.
if ! printf '%s\n' "$RAW" | tr -d '\r' | grep -qx 'OCUPILOT-FIELDS-SOURCE-END'; then
    echo "field-lists: the session printed no complete class source; $OUTPUT is unchanged"
    exit 1
fi

TMP="$OUTPUT.tmp.$$"
trap 'rm -f "$TMP"' EXIT
printf '%s\n' "$RAW" | tr -d '\r' \
    | sed -n '/^OCUPILOT-FIELDS-SOURCE-START$/,/^OCUPILOT-FIELDS-SOURCE-END$/p' \
    | sed -e '1d' -e '$d' > "$TMP"

if ! grep -q '^Class OcuPilot\.Screen\.Tool\.FieldLists ' "$TMP"; then
    echo "field-lists: the session output carried no FieldLists class declaration; $OUTPUT is unchanged"
    exit 1
fi

mv "$TMP" "$OUTPUT"
echo "field-lists: wrote $OUTPUT"
