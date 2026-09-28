/// <p>Pins what becomes of the vendor's async task rows (DW-1101, DW-1136, DW-1137, AD-37):
/// <method>OcuPilot.Port.AdminPort.ForgetTask</method> deletes a row the caller may write, leaves a
/// row the caller cannot delete silently -- without meeting a <code>&lt;PROTECT&gt;</code> the
/// instance would audit -- and logs any other failure; and
/// <method>OcuPilot.Port.AdminPort.SweepOwnTasks</method>, a step of the daily retention sweep,
/// deletes the terminal rows OcuPilot's port queued once a day old and nothing else.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and a caller holding
/// <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the
/// class creates and deletes a user and a role, runs the whole retention sweep, and seeds and deletes
/// rows of the vendor's async task table through <class>OcuPilot.Test.PortFixture</class>. It
/// asserts only on the rows it seeded, and removes every one.</p>
Class OcuPilot.Test.AdminPortForget Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>An id no async-task row carries, so the delete always fails and is always logged. Letters and
/// digits only: it travels as an IdKey value, not as a path.</p>
Parameter MISSINGGUID = "OcuPilotForgetProbe00000000";

/// <p>The prefix of every row this class seeds.</p>
Parameter PROBEGUID = "OcuPilotSweepProbe";

/// <p>The purpose-built principal holding the install namespace's code read and
/// <code>%DB_IRISSYS:READ</code>, and no write on the database the rows live in.</p>
Parameter PROBEUSER = "OcuPilotForgetProbeUser";

Parameter PROBEROLE = "OcuPilotForgetProbeRole";

/// <p>The throwaway principal's password, generated for the run.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AdminPortForget creates and deletes a user and a role, runs the retention sweep and writes the vendor's async task table, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotFrgt" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ..EnsurePrincipal()
}

/// <p>Remove the principal and its role; a failing status when either survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#PROBEUSER) Do ##class(Security.Users).Delete(..#PROBEUSER)
        If ##class(Security.Roles).Exists(..#PROBEROLE) Do ##class(Security.Roles).Delete(..#PROBEROLE)
        If ##class(Security.Users).Exists(..#PROBEUSER) || ##class(Security.Roles).Exists(..#PROBEROLE) Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AdminPortForget left a throwaway principal on the instance")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit ..RemoveProbes()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Set tSC = ..RemoveProbes()
    Do $$$AssertStatusOK(tSC, "every seeded row is removed")
    Quit $$$OK
}

/// <p>DW-1136, DW-1137: for a caller who may write the row, the delete is attempted whatever pair
/// the port's own <code>HoldsPair</code> answers, and a failure other than
/// <code>&lt;PROTECT&gt;</code> -- an id no row carries -- is logged.</p>
/// <p>Mutation (Rule 19): restore the guard that skipped the delete for a caller the fixture answers
/// holds no pair (<code>If '..HoldsPair("%DB_IRISLOCALDATA:WRITE") Quit</code>) -- this goes red,
/// and so does <class>OcuPilot.Test.AdminPortAsync</class>'s "the queued row is gone" when the guard
/// answers no.</p>
Method TestTheDeleteIsNotGatedOnAPairAndAnotherFailureIsLogged()
{
    ; The fixture answers that no pair is held, so a pair guard in ForgetTask would skip the delete.
    Do ##class(OcuPilot.Test.PortFixture).SetHoldsPair(0)
    Do ##class(OcuPilot.Test.PortFixture).ForgetTask(..#MISSINGGUID)
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ "an async task row could not be removed", "the delete was attempted, and its failure is reported: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))
}

/// <p>DW-1136, DW-1137: a caller who cannot write the database the rows live in -- a real
/// least-privileged principal, in a child process -- leaves the row alone: the delete meets no
/// <code>&lt;PROTECT&gt;</code>, which the instance records in its audit log (measured), nothing is
/// logged, and the row stays for the sweep.</p>
/// <p>Mutation (Rule 19): attempt the delete without asking
/// <method>OcuPilot.Port.AdminPort.MayDeleteTask</method> -- the no-protect leg goes red.</p>
Method TestAnUnprivilegedCallersDeleteLeavesTheRowAndLogsNothing()
{
    Set tGuid = ..#PROBEGUID _ "Protect"
    Set tSC = ##class(OcuPilot.Test.PortFixture).SeedTaskRow(tGuid, "GET /v2/ocupilot/database/syscrud", "Finished", ..HoursAgo(1))
    Do $$$AssertStatusOK(tSC, "a finished row is seeded")
    If $$$ISERR(tSC) Quit
    Set tRun = ..ForgetAs(..#PROBEUSER, tGuid)
    Do $$$AssertEquals(tRun.%Get("error") _ " " _ tRun.%Get("username"), " " _ ..#PROBEUSER, "the child ran the delete as the principal")
    Do $$$AssertTrue(tRun.%IsDefined("zerror") && '(tRun.%Get("zerror") [ "<PROTECT>"), "the delete met no protect, which the instance would audit: " _ tRun.%ToJSON())
    Do $$$AssertEquals(tRun.%Get("message") _ "|" _ tRun.%Get("event"), "|", "and nothing was logged: " _ tRun.%ToJSON())
    Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).TaskRowExists(tGuid), 1, "and the row is left for the sweep")
}

/// <p>AD-37, DW-1101: the sweep deletes a row OcuPilot's port labeled, in a terminal state, queued
/// more than the given hours ago -- finished, failed or canceled, and one queued 25 hours ago -- and
/// leaves a labeled row queued now or 23 hours ago, a row another caller queued and a labeled row
/// still running. An age that is not a whole number of hours above zero is refused.</p>
/// <p>Mutation (Rule 19): drop the label condition from
/// <method>OcuPilot.Port.AdminPort.SweepOwnTasks</method> -- the unlabeled leg goes red; halve the
/// cutoff's hours -- the 23-hour leg goes red.</p>
Method TestTheSweepTakesOnlyOcuPilotsTerminalRowsADayOld()
{
    Set tOld = ..HoursAgo(48)
    Set tNew = ..HoursAgo(0)
    For tCase = $ListBuild("Finished", "GET /v2/ocupilot/database/syscrud", "Finished", tOld, 0), $ListBuild("Failed", "GET /v2/ocupilot/security/audit/record", "Failed", tOld, 0), $ListBuild("Canceled", "GET /v2/ocupilot/database/syscrud", "Canceled", tOld, 0), $ListBuild("Recent", "GET /v2/ocupilot/database/syscrud", "Finished", tNew, 1), $ListBuild("Day23", "GET /v2/ocupilot/database/syscrud", "Finished", ..HoursAgo(23), 1), $ListBuild("Day25", "GET /v2/ocupilot/database/syscrud", "Finished", ..HoursAgo(25), 0), $ListBuild("Unlabeled", "POST /v2/database-dir/info", "Finished", tOld, 1), $ListBuild("Running", "GET /v2/ocupilot/database/syscrud", "Running", tOld, 1) {
        Set tSC = ##class(OcuPilot.Test.PortFixture).SeedTaskRow(..#PROBEGUID _ $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 4))
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ " is seeded")
    }
    Do $$$AssertStatusNotOK(##class(OcuPilot.Port.AdminPort).SweepOwnTasks(0), "an age of no hours is refused")
    Set tSC = ##class(OcuPilot.Port.AdminPort).SweepOwnTasks(24)
    Do $$$AssertStatusOK(tSC, "the sweep runs: " _ $System.Status.GetErrorText(tSC))
    For tCase = $ListBuild("Finished", 0), $ListBuild("Failed", 0), $ListBuild("Canceled", 0), $ListBuild("Recent", 1), $ListBuild("Day23", 1), $ListBuild("Day25", 0), $ListBuild("Unlabeled", 1), $ListBuild("Running", 1) {
        Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).TaskRowExists(..#PROBEGUID _ $List(tCase, 1)), $List(tCase, 2), "the " _ $List(tCase, 1) _ " row is " _ $Select($List(tCase, 2): "left", 1: "deleted"))
    }
}

/// <p>AD-37: the daily retention sweep runs that step, deleting a labeled terminal row two days
/// old.</p>
/// <p>Mutation (Rule 19): remove the step from <method>OcuPilot.Kernel.Retention.Sweep</method> --
/// this goes red.</p>
Method TestTheRetentionSweepDeletesOcuPilotsOldRows()
{
    Set tGuid = ..#PROBEGUID _ "Retention"
    Set tSC = ##class(OcuPilot.Test.PortFixture).SeedTaskRow(tGuid, "GET /v2/ocupilot/database/syscrud", "Finished", ..HoursAgo(48))
    Do $$$AssertStatusOK(tSC, "a two-day-old finished row is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Kernel.Retention).Sweep()
    Do $$$AssertEquals(##class(OcuPilot.Test.PortFixture).TaskRowExists(tGuid), 0, "and the retention sweep deletes it")
}

/// <p>The instance's local time <var>pHours</var> hours ago, as the vendor stamps
/// <code>TimeQueued</code>.</p>
ClassMethod HoursAgo(pHours As %Integer) As %String
{
    Set tNow = $Horolog
    Set tSeconds = ($Piece(tNow, ",", 1) * 86400) + $Piece(tNow, ",", 2) - (pHours * 3600)
    Quit $ZDateTime((tSeconds \ 86400) _ "," _ (tSeconds # 86400), 3)
}

/// <p>Delete every row this class seeds.</p>
ClassMethod RemoveProbes() As %Status
{
    Set tFirst = $$$OK
    For tSuffix = "Protect", "Finished", "Failed", "Canceled", "Recent", "Day23", "Day25", "Unlabeled", "Running", "Retention" {
        Set tSC = ##class(OcuPilot.Test.PortFixture).RemoveTaskRow(..#PROBEGUID _ tSuffix)
        If $$$ISERR(tSC) && $$$ISOK(tFirst) Set tFirst = tSC
    }
    Quit tFirst
}

/// <p>Run <method>Forget</method> as <var>pUser</var> on <var>pGuid</var> in a child process and
/// answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod ForgetAs(pUser As %String, pGuid As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.AdminPortForget).Forget($Job, pUser, pGuid)::10
        If '$Test {
            Do tOut.%Set("error", "the child process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 60)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the child process signalled nothing within 60 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>The child: log in as <var>pUser</var>, forget <var>pGuid</var> through
/// <class>OcuPilot.Test.PortFixture</class>, whose log is captured rather than written, and signal
/// <code>{error, username, zerror, message, event}</code> to process <var>pParent</var>, where
/// <code>zerror</code> is the last error the forget met, trapped or not.</p>
/// <p><b>Caller contract:</b> <code>JOB</code>ed by <method>ForgetAs</method> and by nothing else;
/// <code>$System.Security.Login</code> switches this process's own user context.</p>
ClassMethod Forget(pParent As %Integer, pUser As %String, pGuid As %String)
{
    Set tOut = {"error": ""}
    Try {
        If '$SYSTEM.Security.Login(pUser) {
            Do tOut.%Set("error", "the login as " _ pUser _ " failed")
            Quit
        }
        Do tOut.%Set("username", $Username, "string")
        Do ##class(OcuPilot.Test.LogProbe).Clear()
        Set $ZError = ""
        Do ##class(OcuPilot.Test.PortFixture).ForgetTask(pGuid)
        Do tOut.%Set("zerror", $ZError, "string")
        Do tOut.%Set("message", ##class(OcuPilot.Test.LogProbe).Captured("message"), "string")
        Do tOut.%Set("event", ##class(OcuPilot.Test.LogProbe).Captured("event"), "string")
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Create the throwaway role and the account that holds it, then read its grants back: the
/// install namespace's code read and <code>%DB_IRISSYS:READ</code>, and no write on the database the
/// async task rows live in.</p>
Method EnsurePrincipal() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCode = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        If ##class(Security.Users).Exists(..#PROBEUSER) Do ##class(Security.Users).Delete(..#PROBEUSER)
        If ##class(Security.Roles).Exists(..#PROBEROLE) Do ##class(Security.Roles).Delete(..#PROBEROLE)
        Set tSC = ##class(Security.Roles).Create(..#PROBEROLE, "OcuPilot test: the async task delete (throwaway)", tCode _ ",%DB_IRISSYS:R", "")
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Users).Create(..#PROBEUSER, ..#PROBEROLE, ..PreparedPassword, "OcuPilot async task test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.AdminPortForget; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit
        Set tRowsDb = ##class(Config.Databases).Open("IRISLOCALDATA")
        Set tRowsResource = ##class(SYS.Database).%OpenId(tRowsDb.Directory).ResourceName
        If ($SYSTEM.Security.CheckUserPermission(..#PROBEUSER, "%DB_IRISSYS", "READ") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#PROBEUSER, tRowsResource, "WRITE") = 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal's grants did not read back as declared")
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
