#!/bin/sh
# Make the durable root writable by IRIS's own user before IRIS starts (DW-234).
#
# docker-compose.yml runs this as a one-shot `durable-init` service, as root, in the pinned image,
# with the same durable mount as `iris`; `iris` starts only once it has exited 0. The image runs
# IRIS as uid 51773 (`irisowner`), which must create `/durable/iris` on a first start. A bind
# mount keeps the host's ownership on Linux, so a root-owned or host-user-owned 0755 directory is
# one IRIS cannot write; Docker Desktop maps ownership to the caller, so there it already can.
#
# What it does, in order:
#   1. If uid 51773 can already create a directory in the root, exit 0 and change nothing.
#   2. Otherwise `chown` the root itself -- never recursively, so nothing under it changes owner.
#   3. Check again as uid 51773; exit 1 naming the directory if it still cannot write.
#
# Usage (inside the container, as root):
#   sh /opt/ocupilot/scripts/durable-init.sh [--root /durable]
set -e

ROOT="/durable"
IRIS_UID="51773"
IRIS_GID="51773"

while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="$2"; shift 2 ;;
        *) echo "durable-init: unknown argument $1"; exit 2 ;;
    esac
done

if [ ! -d "$ROOT" ]; then
    echo "durable-init: $ROOT is not a directory; the durable mount is missing"
    exit 1
fi

# Whether uid 51773 can create (and remove) a directory directly under the root.
iris_can_write() {
    setpriv --reuid="$IRIS_UID" --regid="$IRIS_GID" --clear-groups \
        sh -c 'probe=$(mktemp -d "$1/.ocupilot-durable-init.XXXXXX") && rmdir "$probe"' sh "$ROOT" \
        >/dev/null 2>&1
}

if iris_can_write; then
    echo "durable-init: $ROOT is already writable by uid $IRIS_UID; nothing changed"
    exit 0
fi

echo "durable-init: uid $IRIS_UID cannot write $ROOT (owner $(stat -c '%u:%g %a' "$ROOT")); taking ownership of the directory itself"
if ! chown "$IRIS_UID:$IRIS_GID" "$ROOT"; then
    echo "durable-init: chown of $ROOT failed"
fi

if iris_can_write; then
    echo "durable-init: $ROOT is now writable by uid $IRIS_UID"
    exit 0
fi

echo "durable-init: uid $IRIS_UID still cannot write $ROOT after chown (owner $(stat -c '%u:%g %a' "$ROOT")); IRIS cannot create its data directory there"
exit 1
