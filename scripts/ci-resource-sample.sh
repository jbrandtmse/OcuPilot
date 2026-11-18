#!/bin/sh
# Run a command while printing the machine's memory, load and largest node processes at a fixed
# interval, so a step that hangs or is killed leaves its resource history in the log; and report
# what the kernel logged about out-of-memory kills.
#
# Usage:
#   sh scripts/ci-resource-sample.sh [--interval <seconds>] -- <command> [args...]
#   sh scripts/ci-resource-sample.sh --report
#
# The first form runs the command, takes one sample at once and then one every --interval seconds
# (default 15), and exits with the command's own status. The sampler is stopped when the command
# ends. A signal sent to the script alone is acted on once the command returns; a signal sent to
# the script's process group ends the command and the sampler together. Each sample is a UTC stamp
# and one line each for memory and swap (`free -m`), load (/proc/loadavg) and online CPUs (`getconf`),
# then the three largest Node processes by resident set (`ps`): those whose program is node, ng,
# npm or npx, since `ng` renames its own process. A source the platform lacks reads `unavailable`.
#
# The second form prints the kernel's out-of-memory lines (`sudo -n dmesg`, else `dmesg`), or
# `no OOM lines` when the log holds none, or `kernel log unavailable` when it cannot be read. It
# exits 0 in all three cases: it reports, it does not gate.
#
# Exit 2 on bad arguments.

INTERVAL=15
REPORT=0

while [ $# -gt 0 ]; do
    case "$1" in
        --interval)
            [ $# -ge 2 ] || { echo "ci-resource-sample: --interval needs a value"; exit 2; }
            INTERVAL="$2"; shift 2 ;;
        --report) REPORT=1; shift ;;
        --) shift; break ;;
        *) echo "ci-resource-sample: unknown argument $1"; exit 2 ;;
    esac
done

report() {
    if log=$(sudo -n dmesg 2>/dev/null); then
        :
    elif log=$(dmesg 2>/dev/null); then
        :
    else
        echo "ci-resource-sample: kernel log unavailable"
        return 0
    fi
    lines=$(printf '%s\n' "$log" | grep -i -E 'out of memory|oom-kill|oom_reaper|killed process')
    if [ -n "$lines" ]; then
        printf '%s\n' "$lines"
    else
        echo "ci-resource-sample: no OOM lines"
    fi
}

sample() {
    stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    mem=unavailable
    swap=unavailable
    if out=$(free -m 2>/dev/null); then
        mem=$(free_line Mem)
        swap=$(free_line Swap)
    fi
    load=unavailable
    if [ -r /proc/loadavg ]; then
        load=$(cat /proc/loadavg)
    fi
    cpus=$(getconf _NPROCESSORS_ONLN 2>/dev/null)
    [ -n "$cpus" ] || cpus=unavailable
    procs=unavailable
    if out=$(ps -eo rss=,pid=,args= 2>/dev/null); then
        procs=$(printf '%s\n' "$out" | awk '$3 ~ /(^|\/)(node|ng|npm|npx)$/ { print }' | sort -rn | head -n 3 | cut -c 1-160)
        if [ -z "$procs" ]; then
            procs="no node process"
        fi
    fi
    printf 'ci-resource-sample: %s\n  mem: %s\n  swap: %s\n  load: %s\n  cpus: %s\n  node (rss KiB, pid, command):\n%s\n' \
        "$stamp" "$mem" "$swap" "$load" "$cpus" "$(printf '%s\n' "$procs" | sed 's/^/    /')"
}

# The line of `free -m`'s output in $out that starts with $1, or `unavailable`.
free_line() {
    printf '%s\n' "$out" | awk -v want="$1" 'index($0, want) == 1 { print; found = 1 } END { if (!found) print "unavailable" }'
}

sample_loop() {
    trap - EXIT
    nap=""
    trap '[ -n "$nap" ] && kill "$nap" 2>/dev/null; exit 0' TERM INT HUP
    while :; do
        sample
        sleep "$INTERVAL" &
        nap=$!
        wait "$nap"
    done
}

if [ "$REPORT" -eq 1 ]; then
    report
    exit 0
fi

[ $# -gt 0 ] || { echo "ci-resource-sample: a command after -- is required"; exit 2; }
case "$INTERVAL" in
    ''|*[!0-9]*) INTERVAL=0 ;;
esac
[ "$INTERVAL" -gt 0 ] || { echo "ci-resource-sample: --interval must be a positive whole number of seconds"; exit 2; }

SAMPLER=""
stop_sampler() {
    if [ -n "$SAMPLER" ]; then
        kill "$SAMPLER" 2>/dev/null
        wait "$SAMPLER" 2>/dev/null
        SAMPLER=""
    fi
}
trap stop_sampler EXIT
trap 'exit 143' TERM INT HUP

sample_loop &
SAMPLER=$!

"$@"
STATUS=$?
stop_sampler
exit "$STATUS"
