#!/bin/sh
# Write, start and tear down the THROWAWAY container CI's instance job runs against
# (Story 1.17; README.md's "Verifying the start path against a throwaway container").
#
# **It never points `docker compose` at this repository's own docker-compose.yml.** That file
# names the container `ocupilot` and mounts `./iris-data`, so one missing override line reaches
# a live instance. The compose file this writes is a standalone one in a scratch directory, with
# its own project name, its own container name, its own host ports (never 52774 or 1973) and its
# own data directory, and `down` takes `-v` so nothing of it survives.
#
# The `restart`, `depends_on`, `healthcheck` and `command` keys, and the one-shot `durable-init`
# service, are copied from docker-compose.yml on purpose, so a start behaves on the throwaway as it
# would there. Copy them again when they change; `ui/tools/ci.test.mjs` holds the two equal.
#
# Usage:
#   sh scripts/ci-throwaway.sh up    [--dir DIR] [--project NAME] [--web 52776] [--super 1975]
#   sh scripts/ci-throwaway.sh logs  [--dir DIR]
#   sh scripts/ci-throwaway.sh down  [--dir DIR] [--project NAME]
set -e

ACTION="${1:-}"
shift 2>/dev/null || true

DIR="${OCUPILOT_THROWAWAY_DIR:-/tmp/ocupilot-ci}"
PROJECT="ocupilot-ci"
WEB_PORT="52776"
SUPER_PORT="1975"
IMAGE="intersystems/irishealth-community:2026.2"
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)

while [ $# -gt 0 ]; do
    case "$1" in
        --dir) DIR="$2"; shift 2 ;;
        --project) PROJECT="$2"; shift 2 ;;
        --web) WEB_PORT="$2"; shift 2 ;;
        --super) SUPER_PORT="$2"; shift 2 ;;
        --image) IMAGE="$2"; shift 2 ;;
        *) echo "ci-throwaway: unknown argument $1"; exit 2 ;;
    esac
done

# The live instance's own ports, refused outright. This script writes a compose file and starts
# a container from it; publishing the live ports would either collide with a running instance or,
# worse, be mistaken for one.
if [ "$WEB_PORT" = "52774" ] || [ "$SUPER_PORT" = "1973" ]; then
    echo "ci-throwaway: 52774 and 1973 are the live container's published ports; a throwaway never takes them"
    exit 2
fi
if [ "$PROJECT" = "ocupilot" ]; then
    echo "ci-throwaway: 'ocupilot' is the live container's own project name; a throwaway never takes it"
    exit 2
fi
# `down` removes $DIR recursively, and $DIR is caller-supplied. Every other destructive surface
# in this script and in ci-image-compile.sh is guarded by name (52774, 1973, project `ocupilot`,
# container `ocupilot`); this one was not, so a mistyped --dir deleted whatever it named.
# Scratch roots only, and never the root of one.
case "$DIR" in
    /tmp/?*|/private/tmp/?*|"${TMPDIR:-/nonexistent-tmpdir}"?*) ;;
    *) echo "ci-throwaway: '$DIR' is not under a scratch root; a throwaway's directory is removed recursively, so it must be under /tmp, /private/tmp or \$TMPDIR"; exit 2 ;;
esac

COMPOSE_FILE="$DIR/compose.yml"

# Remove the throwaway's durable directory, whoever owns what is in it.
#
# IRIS creates /durable/iris and everything under it as its own user, uid 51773. On Linux -- every
# GitHub runner -- those files are uid 51773 on the host too, and unlinking them needs write
# permission on the directories holding them, which the invoking user does not have: a plain
# `rm -rf` removes what it can and exits non-zero. Probed on this build against the pinned image:
# uid 1001 got `rm: cannot remove '/scratch/data/iris/mgr/messages.log': Permission denied`, exit
# 1, tree intact. Docker Desktop maps bind-mount ownership to the calling user, so the plain
# removal succeeds on macOS -- it is tried first, and the container is the fallback, using the
# image this script already pulled with its entrypoint overridden so nothing starts an instance.
scrub_data() {
    if [ ! -d "$DIR/data" ]; then return 0; fi
    if rm -rf "$DIR/data" 2>/dev/null; then return 0; fi
    docker run --rm --user 0:0 --entrypoint sh -v "$DIR:/scratch" "$IMAGE" -c 'rm -rf /scratch/data'
}

case "$ACTION" in
    up)
        # A previous run whose teardown was skipped leaves $DIR/data holding an INSTALLED
        # volume, and `up` over it validates a first install that already happened. The
        # header promises a fresh container; this is what makes that true.
        scrub_data
        rm -rf "$DIR"
        mkdir -p "$DIR/data" "$DIR/src" "$DIR/scripts" "$DIR/ui"
        # The durable directory is left as `mkdir` made it: owned by the invoking user, 0755. The
        # generated `durable-init` service makes it writable by IRIS's own user before `iris`
        # starts, exactly as docker-compose.yml does, so on a Linux runner this bring-up is the
        # end-to-end proof of that service (DW-234).
        # Scratch copies, so a mutation made for a check never touches this repository's files.
        cp -R "$REPO_ROOT/src/." "$DIR/src/"
        cp -R "$REPO_ROOT/scripts/." "$DIR/scripts/"
        # The committed manifest, mounted so that OcuPilot.Test.Manifest's XML parse (DW-197)
        # actually RUNS rather than taking its "no manifest on this instance" skip. That class
        # reads /opt/ocupilot/module.xml, and neither this repository's own compose file nor an
        # earlier version of this script mounted it -- so the one assertion that reads the
        # manifest as a document skipped everywhere, including here, which is the vacuous pass
        # this story exists to remove. Copied rather than bind-mounted from the repository for
        # the reason the two above are.
        cp "$REPO_ROOT/module.xml" "$DIR/module.xml"
        if [ -d "$REPO_ROOT/ui/dist" ]; then
            mkdir -p "$DIR/ui/dist"
            cp -R "$REPO_ROOT/ui/dist/." "$DIR/ui/dist/"
        fi
        # The same rule as the durable directory, one mount over: these three are read-only to the
        # container, but uid 51773 still has to be able to read them, and `cp` reproduces the
        # invoking user's umask. Under the 022 a runner and a workstation both use they are already
        # world-readable; under an 077 the container would exit unable to read container-start.sh.
        chmod -R a+rX "$DIR/src" "$DIR/scripts" "$DIR/ui" "$DIR/module.xml"
        cat > "$COMPOSE_FILE" <<EOF
# GENERATED BY scripts/ci-throwaway.sh -- THROWAWAY ONLY, never this repository's docker-compose.yml
name: $PROJECT
services:
  iris:
    image: $IMAGE
    container_name: $PROJECT
    restart: on-failure:3
    depends_on:
      durable-init:
        condition: service_completed_successfully
    ports:
      - "$SUPER_PORT:1972"
      - "$WEB_PORT:52773"
    environment:
      ISC_DATA_DIRECTORY: /durable/iris
      OCUPILOT_DEMO: "1"
      # Arms OcuPilot.Test.LogSourceRotation, which rotates the instance's own messages.log.
      # Set here and nowhere else: this container is discarded, and the test refuses to run
      # anywhere the variable is absent rather than trusting a doc comment to keep it off a
      # development instance.
      OCUPILOT_ALLOW_LOG_ROTATION: "1"
      # Arms OcuPilot.Test.LogSourceDenial, which creates and deletes IRIS users and roles.
      # Same reasoning, same single home: test classes are selected by package, so a runner
      # pointed at an instance someone cares about would otherwise create principals on it.
      OCUPILOT_ALLOW_PRINCIPALS: "1"
    volumes:
      - $DIR/data:/durable
      - $DIR/src:/opt/ocupilot/src:ro
      - $DIR/scripts:/opt/ocupilot/scripts:ro
      - $DIR/ui:/opt/ocupilot/ui:ro
      - $DIR/module.xml:/opt/ocupilot/module.xml:ro
    command: ["--after", "sh /opt/ocupilot/scripts/container-start.sh"]
    healthcheck:
      test: ["CMD", "sh", "/opt/ocupilot/scripts/container-health.sh"]
      interval: 10s
      timeout: 15s
      retries: 30
      start_period: 60s

  durable-init:
    image: $IMAGE
    user: "0:0"
    entrypoint: ["sh", "/opt/ocupilot/scripts/durable-init.sh"]
    restart: "no"
    volumes:
      - $DIR/data:/durable
      - $DIR/scripts:/opt/ocupilot/scripts:ro
EOF
        echo "ci-throwaway: wrote $COMPOSE_FILE ($IMAGE, web $WEB_PORT, superserver $SUPER_PORT)"
        docker compose -f "$COMPOSE_FILE" up -d --wait
        docker compose -f "$COMPOSE_FILE" ps
        ;;
    logs)
        # The failure-path capture, run before the teardown and only when something already
        # failed. In run 34773637146 the failing step printed one line -- `container ocupilot-ci
        # is unhealthy` -- and the cause reached the job only because the NEXT step, the teardown,
        # happens to print `logs | tail -n 80` of one service before removing everything. That is
        # the evidence surviving by luck twice over: under a step whose name says nothing about
        # it, and only because the container failed early enough to still be inside the last 80
        # lines. This prints the state of every container the throwaway created and its whole
        # log, under a step named for the job it does.
        if [ ! -f "$COMPOSE_FILE" ]; then
            echo "ci-throwaway: no compose file at $COMPOSE_FILE; nothing was brought up"
            exit 0
        fi
        # `|| true` on the cheap half only: under `set -e` a non-zero `ps -a` would abort the
        # capture before the log -- the half that is actually being captured -- ever printed.
        docker compose -f "$COMPOSE_FILE" ps -a || true
        docker compose -f "$COMPOSE_FILE" logs --no-color --timestamps
        ;;
    down)
        if [ -f "$COMPOSE_FILE" ]; then
            docker compose -f "$COMPOSE_FILE" logs --no-color iris | tail -n 80 || true
            docker compose -f "$COMPOSE_FILE" down -v
        fi
        scrub_data
        rm -rf "$DIR"
        echo "ci-throwaway: removed $DIR"
        ;;
    *)
        echo "ci-throwaway: usage: ci-throwaway.sh up|logs|down [options]"
        exit 2
        ;;
esac
