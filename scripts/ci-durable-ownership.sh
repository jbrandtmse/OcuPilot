#!/bin/sh
# Reproduce the Linux durable-directory ownership failure and prove durable-init.sh fixes it
# (DW-234). CI's instance job runs this first.
#
# It uses uniquely named Docker volumes, never a bind mount: a named volume carries real Linux
# ownership even under Docker Desktop, whose bind mounts map ownership to the caller and so hide
# the failure. Every volume it creates is removed on every exit.
#
#   1. A volume whose root is 0:0 mode 0755. Negative control: uid 51773 cannot `mkdir
#      /durable/iris`. If it can, the reproduction is inert and this exits 1.
#   2. durable-init.sh runs as root over it; then uid 51773 must be able to create the directory.
#   3. Non-recursion, on a second volume: a root-owned child survives durable-init.sh taking the
#      root, and a second run over a root uid 51773 already owns changes nothing.
#   4. The failure path: over a read-only mount of that volume durable-init.sh exits 1 and names
#      the directory.
#
# Usage:
#   sh scripts/ci-durable-ownership.sh [--image intersystems/irishealth-community:2026.2]
set -e

IMAGE="intersystems/irishealth-community:2026.2"
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)

while [ $# -gt 0 ]; do
    case "$1" in
        --image) IMAGE="$2"; shift 2 ;;
        *) echo "ci-durable-ownership: unknown argument $1"; exit 2 ;;
    esac
done

SUFFIX="$$-$(date +%s)"
VOL_A="ocupilot-durable-ownership-a-$SUFFIX"
VOL_B="ocupilot-durable-ownership-b-$SUFFIX"

cleanup() {
    docker volume rm -f "$VOL_A" "$VOL_B" >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

# Run a shell command against a volume mounted at /durable, as the given uid:gid.
on_volume() {
    tVolume="$1"
    tUser="$2"
    shift 2
    docker run --rm --user "$tUser" --entrypoint sh -v "$tVolume:/durable" "$IMAGE" -c "$@"
}

# Run durable-init.sh, as root, against a volume; a second argument is a mount option (ro).
durable_init() {
    docker run --rm --user 0:0 --entrypoint sh \
        -v "$1:/durable${2:+:$2}" -v "$REPO_ROOT/scripts:/opt/ocupilot/scripts:ro" \
        "$IMAGE" /opt/ocupilot/scripts/durable-init.sh
}

docker volume create "$VOL_A" >/dev/null
docker volume create "$VOL_B" >/dev/null

echo "ci-durable-ownership: $VOL_A with its root set to 0:0 0755"
on_volume "$VOL_A" 0:0 'chown 0:0 /durable && chmod 0755 /durable'

if NEGATIVE=$(on_volume "$VOL_A" 51773:51773 'mkdir /durable/iris' 2>&1); then
    echo "ci-durable-ownership: reproduction inert -- uid 51773 created /durable/iris in a 0:0 0755 root, so nothing below proves anything"
    exit 1
fi
case "$NEGATIVE" in
    *"Permission denied"*) ;;
    *) echo "ci-durable-ownership: the negative control failed for another reason, so it proves nothing: $NEGATIVE"; exit 1 ;;
esac
echo "ci-durable-ownership: negative control holds -- uid 51773 cannot create /durable/iris"

durable_init "$VOL_A"
if ! on_volume "$VOL_A" 51773:51773 'mkdir /durable/iris'; then
    echo "ci-durable-ownership: after durable-init.sh, uid 51773 still cannot create /durable/iris"
    exit 1
fi
echo "ci-durable-ownership: after durable-init.sh, uid 51773 created /durable/iris"

echo "ci-durable-ownership: $VOL_B with a 0:0 0755 root and a 0:0 child"
on_volume "$VOL_B" 0:0 'chown 0:0 /durable && chmod 0755 /durable && mkdir /durable/child && chown 0:0 /durable/child'
durable_init "$VOL_B"
CHILD=$(on_volume "$VOL_B" 0:0 'stat -c "%u:%g" /durable/child')
ROOT_OWNER=$(on_volume "$VOL_B" 0:0 'stat -c "%u:%g" /durable')
if [ "$CHILD" != "0:0" ]; then
    echo "ci-durable-ownership: durable-init.sh changed the owner of a child to $CHILD; it must take the root only"
    exit 1
fi
if [ "$ROOT_OWNER" != "51773:51773" ]; then
    echo "ci-durable-ownership: durable-init.sh left the root owned by $ROOT_OWNER"
    exit 1
fi

BEFORE=$(on_volume "$VOL_B" 0:0 'stat -c "%u:%g %a" /durable /durable/child')
SECOND=$(durable_init "$VOL_B")
AFTER=$(on_volume "$VOL_B" 0:0 'stat -c "%u:%g %a" /durable /durable/child')
case "$SECOND" in
    *"nothing changed"*) ;;
    *) echo "ci-durable-ownership: a second run over a writable root did not report a no-op: $SECOND"; exit 1 ;;
esac
if [ "$BEFORE" != "$AFTER" ]; then
    echo "ci-durable-ownership: a second run over a writable root changed ownership or mode: $BEFORE -> $AFTER"
    exit 1
fi
echo "ci-durable-ownership: non-recursive, and a no-op over a writable root"

on_volume "$VOL_B" 0:0 'chown 0:0 /durable'
if FAILED=$(durable_init "$VOL_B" ro 2>&1); then
    echo "ci-durable-ownership: durable-init.sh exited 0 over a read-only root IRIS cannot write: $FAILED"
    exit 1
fi
case "$FAILED" in
    *"still cannot write /durable"*) ;;
    *) echo "ci-durable-ownership: durable-init.sh failed over a read-only root without naming the directory: $FAILED"; exit 1 ;;
esac
echo "ci-durable-ownership: over a read-only root durable-init.sh exits non-zero and names the directory"

echo "ci-durable-ownership: passed"
