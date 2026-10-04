# What I learned building OcuPilot: macOS quietly deletes IRIS databases kept in /tmp

<!-- Draft for the InterSystems Developer Community, "What I learned building OcuPilot" series.
Facts checked on 2026-10-04 on macOS 26.6 with the intersystems/iris-community:2026.2 image. -->

While building [OcuPilot](https://openexchange.intersystems.com/package/OcuPilot), an AI co-pilot for the IRIS Management Portal, I ran a
lot of short-lived IRIS containers for testing. They kept their data in folders under `/tmp` on my
Mac, because that is where scratch files go. Three days in, one of them started failing in ways that
made no sense: a temporary database that still showed as mounted had no file behind it, and writes
to it failed.

My first suspicion was IRIS, then my own code. It was neither. It was macOS doing exactly what it is
designed to do.

## What macOS does

Every night at midnight, macOS runs a small cleanup job that deletes files under `/tmp` that nobody
has touched for more than three days. It is part of macOS itself, and it is a reasonable thing for a
temporary folder. It only looks at `/tmp` (which is really `/private/tmp`), and it does not
care what the files are.

## Why IRIS databases are especially exposed

IRIS keeps the data you use in memory and only writes to a database file when something changes. I
measured this: reading a database, even all of it, left the file's timestamps exactly as they were.
So a database that is only read, or not used at all, looks untouched to the cleanup job, and three
days later its file is gone.

The temporary databases go first, because IRIS almost never writes them to disk. But any database
qualifies once it has gone three days without a change.

## What happens next

This is the part that surprised me. I reproduced it on purpose with a fresh container and a test
database:

- **At first, nothing looks wrong.** IRIS still has the file open, so it keeps reading your data and
  reports the database as mounted.
- **Writes start failing when the database needs to grow.** A small change went through; a larger one
  failed partway.
- **On the next restart, IRIS refused to start.** It had changes waiting to be written to a file that
  no longer existed, and it stopped rather than guess. The instance stayed down until someone stepped
  in, and the data in that database was gone.
- **The container still showed as running.** Docker reported the container up the whole time, even
  though IRIS inside it had not started.

If you have landed here from a search, these are the messages I saw. The path is my test database's;
yours will name your own. While IRIS was still running, `messages.log` recorded:

```text
Error opening volume to write block 652 of /durable/iris/mgr/userdb/
```

and on the next start, IRIS stopped with:

```text
Failed to open /durable/iris/mgr/userdb/IRIS.DAT: errno=2
We failed to fully restore the WIJ.
** Startup aborted **
Recovery failure. Startup aborted.
```

Getting back means restoring the database from a backup. IRIS does offer a way to start anyway, but it
warns that other databases may be damaged if you take it.

## Who is affected

It is not about containers. It is about where the files live on your Mac.

| Setup | Affected? |
|---|---|
| IRIS installed natively in a normal location (for example under your home folder or `/opt`) | No |
| A native install, or just one database, journal or other data folder, placed under `/tmp` | Yes |
| A container with its data in a folder under `/tmp` (for example `-v /tmp/iris:/durable`) | Yes |
| A container using a named Docker volume, or a folder outside `/tmp` | No |

`/tmp` is a natural place for a quick experiment, and three days is short enough to catch a container
you meant to remove on Friday and forgot until Monday.

## How to check

Look for database files under `/tmp`:

```bash
find /private/tmp -name IRIS.DAT 2>/dev/null
```

If that prints anything you care about, move it before tonight. For containers, check where each one
keeps its data:

```bash
docker inspect --format '{{.Name}} {{range .Mounts}}{{.Source}} {{end}}' $(docker ps -q)
```

Any source path starting with `/tmp` or `/private/tmp` is at risk.

## How to avoid it

- Keep IRIS data out of `/tmp`. A folder in your home directory works, and so does a named Docker
  volume.
- If you do use `/tmp` for a quick test, treat the container as disposable and recreate it before it
  is three days old.
- Do not rely on the container's "running" status. Check that IRIS itself started, for example with
  `iris qlist` inside the container.

## What I learned

- When an instance misbehaves, look at where its files live before blaming the database.
- A test container that outlives its plan is no longer a throwaway.
- "Running" is not the same as "working".

I'm moving OcuPilot's own test containers out of `/tmp`. If you run IRIS on a Mac, take a minute to
check yours today.
