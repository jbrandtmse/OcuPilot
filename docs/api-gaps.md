# Where the admin API's specification and IRIS 2026.2 disagree

OcuPilot is built on version 2 of the IRIS admin API (`/api/admin`), described by the specification InterSystems
published at
[intersystems-community/sysadmin-api-specification](https://github.com/intersystems-community/sysadmin-api-specification)
(`mainspec_v2.json`). Building against a real instance turned up seven places where the specification and IRIS for
Health 2026.2 (Build 221U) disagree. In each case OcuPilot follows what the instance does. The first three are reported
upstream.

| # | Where | The specification says | IRIS 2026.2 does | What OcuPilot does |
| --- | --- | --- | --- | --- |
| 1 | `GET /v2/tasks` | Each task carries a `Suspended` boolean | Every task is reported `"Suspended": false`, including tasks that are suspended; `GET /v2/task/info` reports the real state | Reads each task's own information, so the Task schedule shows the true state. [Issue #1](https://github.com/intersystems-community/sysadmin-api-specification/issues/1) |
| 2 | OAuth 2.0 client configuration | The server field is `OAuth2ServerDefinition` | Rejects that name with 400 (`ERROR #40307`) and uses `ServerDefinition`; its answers also carry `ClientId` and `JWTInterval`, which the schema does not list | Sends and reads `ServerDefinition`. [Issue #2](https://github.com/intersystems-community/sysadmin-api-specification/issues/2) |
| 3 | OAuth 2.0 token revocation | `POST /v2/security/oauth2/revoke` | That path answers 404; revocation is served at `POST /v2/security/oauth2/server/revoke` | Calls the `/server/revoke` path. [Issue #2](https://github.com/intersystems-community/sysadmin-api-specification/issues/2) |
| 4 | `GET /v2/web-app` | The application record includes `Type` | The record has no `Type`; the list, `GET /v2/web-apps`, does carry it, as a display string such as `System,CSP` | Shows the type from the list |
| 5 | `GET /v2/web-app` | `WSGIType` is an integer | `WSGIType` is a string: `WSGI` or `ASGI` | Reads and sends the string |
| 6 | `PUT /v2/security/resource` | `PublicPermission` is any string of `R`, `W` and `U`, which includes the empty string | Refuses an empty permission with 400 and an empty error list, on a create and on a clear, so no resource can be made private through the API | Makes that one change through IRIS's own `Security.Resources` class, after the same checks, and reads it back |
| 7 | `PUT /v2/security/resource` | A 200 answer is a success; `Description` has no length limit | A 300-character description answers 200 and leaves the resource unchanged; the answer carries the old values | Reads every resource change back, and reports one the instance did not keep as not applied |

The admin API is labeled experimental in 2026.2, so some of these may change in later releases. Numbers 1 to 3 were
reproduced on a fresh `intersystems/irishealth-community:2026.2` container when they were reported, 1, 4 and 5 were
checked again on 2026-09-27, and 6 and 7 on 2026-09-28.

## What the admin API does not cover

A few things the portal needs are not served by the admin API, so OcuPilot reads them directly:

- `messages.log`, `alerts.log` and the older rotated `messages` files, from the instance's manager directory.
- The REST API explorer's list of applications and their OpenAPI documents, from the logic behind `/api/mgmnt`.
