#!/bin/sh
# Wait until an instance's readiness endpoint reports that OcuPilot is installed (Story 1.17,
# AD-45), or fail.
#
# CI's instance job runs this before any suite. `docker compose up -d --wait` already blocks on
# the container's own health check, which is start-scoped and reads the same gate ladder -- but
# the health check answers from inside the container, and this asks the same question over HTTP,
# from outside, as a caller with no credentials. That is the question a monitor asks, and the one
# this story exists to make answerable; if the two ever disagree, the disagreement is what the
# job should stop on.
#
# Usage:
#   sh scripts/wait-readiness.sh --url http://localhost:52776/api/ocupilot/readiness/ [--timeout 300]
#
# Exit 0 once the endpoint reports state "installed". Exit 1 on a timeout, and exit 1 IMMEDIATELY
# on state "failed", "upgraderequired" or "unreadable": none of them becomes "installed" by waiting,
# and a job that waited out its whole budget would report a timeout instead of the cause. Exit 2 on
# bad arguments.
set -e

URL=""
TIMEOUT=300
INTERVAL=5

while [ $# -gt 0 ]; do
    case "$1" in
        --url) URL="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        *) echo "wait-readiness: unknown argument $1"; exit 2 ;;
    esac
done

[ -n "$URL" ] || { echo "wait-readiness: --url is required"; exit 2; }
# ELAPSED advances by INTERVAL, so a zero or non-numeric interval never reaches TIMEOUT and the
# loop spins until the runner's own timeout kills the job -- a budget that silently does not
# apply is worse than no budget.
case "$INTERVAL" in
    ''|*[!0-9]*|0) echo "wait-readiness: --interval must be a positive whole number of seconds"; exit 2 ;;
esac
case "$TIMEOUT" in
    ''|*[!0-9]*|0) echo "wait-readiness: --timeout must be a positive whole number of seconds"; exit 2 ;;
esac

echo "wait-readiness: polling $URL for up to ${TIMEOUT}s"
ELAPSED=0
LAST=""

while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
    BODY=$(curl -fsS --max-time 10 "$URL" 2>/dev/null || true)
    case "$BODY" in
        *'"state":"installed"'*)
            echo "wait-readiness: installed after ${ELAPSED}s -- $BODY"
            exit 0
            ;;
        *'"state":"failed"'*)
            echo "wait-readiness: the instance reports a FAILED install after ${ELAPSED}s -- $BODY"
            echo "wait-readiness: readiness names no failing step by design (AD-45); the container log does"
            exit 1
            ;;
        *'"state":"upgraderequired"'*)
            # A settled state, like "failed": the stored schema version is below the deployed
            # one and no amount of waiting changes that. Without this arm the job spent its
            # whole budget and then reported a timeout, which names the clock rather than the
            # instance.
            echo "wait-readiness: the instance is installed at an OLDER schema version than this code deploys, after ${ELAPSED}s -- $BODY"
            echo "wait-readiness: an upgrade has to run before any suite means anything here"
            exit 1
            ;;
        *'"state":"unreadable"'*)
            # DW-96: the gate cannot read OcuPilot's own install state (a revoked SQL grant, say).
            # Waiting never clears it; install has to run again.
            echo "wait-readiness: the instance reports its install state UNREADABLE after ${ELAPSED}s -- $BODY"
            echo "wait-readiness: waiting will not help; run install again"
            exit 1
            ;;
    esac
    if [ "$BODY" != "$LAST" ]; then
        echo "wait-readiness: ${ELAPSED}s -- ${BODY:-<no answer yet>}"
        LAST="$BODY"
    fi
    sleep "$INTERVAL"
    ELAPSED=$((ELAPSED + INTERVAL))
done

echo "wait-readiness: gave up after ${TIMEOUT}s; the last answer was: ${LAST:-<no answer at all>}"
exit 1
