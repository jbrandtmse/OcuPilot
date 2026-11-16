/// <p>The backup screens' codes and sentences (AD-29, AD-39, Story 21.2): every <code>BACKUP.*</code> code
/// <class>OcuPilot.Port.BackupPort</class> and <class>OcuPilot.Area.OsMgmt.BackupRules</class> answer with, and the
/// one sentence each carries. Each sentence is published once in EXPERIENCE.md's Fixed strings and pinned equal to its
/// <file>ui/src/app/core/strings.ts</file> key. They live beside <class>OcuPilot.Api.Error</class> rather than in it
/// because that class holds the compiler's limit of 1,000 parameters (ERROR #5290);
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> and <method>OcuPilot.Api.Error.ReasonForViolation</method>
/// answer these codes through <method>ReasonFor</method>.</p>
/// <p><parameter>RUN</parameter> and <parameter>FREEZE</parameter> are not refusals: they are the consequence codes
/// the proposal card of a backup run and of a freeze renders.</p>
Class OcuPilot.Api.BackupError Extends %RegisteredObject
{

/// <p>404: the instance lists no backup task of that name.</p>
Parameter TASKNOTFOUND = "BACKUP.TASK.NOTFOUND";

Parameter REASONTASKNOTFOUND = "There is no backup task with that name.";

/// <p>409: a backup task reads Running, so another is not started.</p>
Parameter RUNNING = "BACKUP.RUNNING";

Parameter REASONRUNNING = "A backup is already running.";

/// <p>400: a freeze names no suspend limit from 1 to <parameter>OcuPilot.Port.BackupPort.FREEZELIMITMAX</parameter>.</p>
Parameter FREEZELIMIT = "BACKUP.FREEZE.LIMIT";

Parameter REASONFREEZELIMIT = "Give a suspend limit from 1 to 600 seconds.";

/// <p>409: database writes are already frozen.</p>
Parameter FROZEN = "BACKUP.FROZEN";

Parameter REASONFROZEN = "Database writes are already frozen.";

/// <p>409: the instance would ignore the freeze's suspend limit, so the freeze is refused before it is sent.</p>
Parameter FREEZEUNBOUNDED = "BACKUP.FREEZE.UNBOUNDED";

Parameter REASONFREEZEUNBOUNDED = "Writes cannot be frozen with a limit on this system.";

/// <p>409: database writes are not frozen, so there is nothing to thaw.</p>
Parameter NOTFROZEN = "BACKUP.NOTFROZEN";

Parameter REASONNOTFROZEN = "Database writes are not frozen.";

/// <p>404: the instance holds no database of that name.</p>
Parameter DATABASENOTFOUND = "BACKUP.DATABASE.NOTFOUND";

Parameter REASONDATABASENOTFOUND = "There is no database with that name.";

/// <p>409: the database is already on the backup list, or is not on it, so the write would change nothing.</p>
Parameter LISTCONFLICT = "BACKUP.LIST.CONFLICT";

Parameter REASONLISTCONFLICT = "The backup list already reflects that change.";

/// <p>The consequence code a backup run's proposal card carries.</p>
Parameter RUN = "BACKUP.RUN";

Parameter REASONRUN = "The backup runs in the background; its result appears in Backup history.";

/// <p>The consequence code a freeze's proposal card carries.</p>
Parameter FREEZE = "BACKUP.FREEZE";

Parameter REASONFREEZE = "Database writes stop until you thaw them or the limit passes.";

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#TASKNOTFOUND Quit ..#REASONTASKNOTFOUND
    If pCode = ..#RUNNING Quit ..#REASONRUNNING
    If pCode = ..#FREEZELIMIT Quit ..#REASONFREEZELIMIT
    If pCode = ..#FROZEN Quit ..#REASONFROZEN
    If pCode = ..#FREEZEUNBOUNDED Quit ..#REASONFREEZEUNBOUNDED
    If pCode = ..#NOTFROZEN Quit ..#REASONNOTFROZEN
    If pCode = ..#DATABASENOTFOUND Quit ..#REASONDATABASENOTFOUND
    If pCode = ..#LISTCONFLICT Quit ..#REASONLISTCONFLICT
    If pCode = ..#RUN Quit ..#REASONRUN
    If pCode = ..#FREEZE Quit ..#REASONFREEZE
    Quit ""
}

/// <p>The HTTP status <var>pCode</var> is answered with: 404, 409 or 400, and 0 for a code that is no
/// refusal.</p>
ClassMethod HttpStatusFor(pCode As %String) As %Integer
{
    If (pCode = ..#TASKNOTFOUND) || (pCode = ..#DATABASENOTFOUND) Quit 404
    If pCode = ..#FREEZELIMIT Quit 400
    If (pCode = ..#RUNNING) || (pCode = ..#FROZEN) || (pCode = ..#FREEZEUNBOUNDED) || (pCode = ..#NOTFROZEN) || (pCode = ..#LISTCONFLICT) Quit 409
    Quit 0
}

/// <p>The envelope slug <var>pCode</var> is answered under.</p>
ClassMethod SlugFor(pCode As %String) As %String
{
    Set tHttp = ..HttpStatusFor(pCode)
    If tHttp = 404 Quit ##class(OcuPilot.Api.Error).#NOTFOUND
    If tHttp = 400 Quit ##class(OcuPilot.Api.Error).#BADREQUEST
    Quit ##class(OcuPilot.Api.Error).#CONFLICT
}

}
