/// <p>Pins AD-10's dismount arm (Story 18.4): a dismount of OcuPilot's own database, of the install
/// namespace's routines database and of <code>IRISSYS</code> is refused
/// <code>PROHIBITED.OCUPILOTDATABASE</code> on both callers, matched by directory, with no write sent and
/// the reason stated when the Dismount dialog opens; a protected directory spelled another way is
/// refused too; a failed own-set read refuses; a probe database
/// standing as an own database is refused; and a mount, truncate, compact or defragment of a protected
/// database stays permitted.</p>
/// <p>Every write goes to <class>OcuPilot.Test.DatabaseAcceptPort</class>, which reads the instance and
/// sends no write, so a removed predicate shows as a recorded write and never as a dismounted
/// database.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because the class creates and deletes a probe database
/// (<class>OcuPilot.Test.DatabaseActionProbe</class>) and sets the governance policy. It refuses anywhere
/// it does not; every probe object is removed before all, after each and after all.</p>
Class OcuPilot.Test.DatabaseActionsProhibited Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PROBE = "OcuPilot.Test.DatabaseActionProbe";

Parameter ACCEPT = "OcuPilot.Test.DatabaseAcceptPort";

Parameter OWNCODE = "PROHIBITED.OCUPILOTDATABASE";

Parameter DISMOUNTTOOL = "OcuPilot.Screen.Tool.DatabaseDismount";

Parameter DISMOUNTKEY = "osmgmt.databasedetails.dismount";

Parameter NAME = "OCUPROBE184P";

Property PreparedPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DatabaseActionsProhibited creates and deletes a probe database on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort, ^||OcuPilotDatabaseProhibited, ^||OcuPilotDatabaseOwnProbe, ^||OcuPilotDatabaseOwnFail
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Do $ClassMethod(..#ACCEPT, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object is removed")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>The protected directories (AC5): for OcuPilot's own database, the install namespace's routines
/// database and <code>IRISSYS</code>, the screen's dismount and the agent's confirmed dismount are each
/// refused <code>PROHIBITED.OCUPILOTDATABASE</code> with no write sent, and the dismount's impact -- what
/// the Dismount dialog states when it opens -- is that refusal and its sentence.</p>
/// <p>Mutation (Rule 19): remove the dismount arm of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Database</method> -> each refused leg is a dismount the
/// accept port records, and this goes red.</p>
Method TestTheProtectedDatabasesAreNotDismounted()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.DatabaseActions).Enable(..#DISMOUNTKEY), "the agent's dismount key is enabled, so only the prohibited set stands in the way")
    Set ^||OcuPilotDatabaseWritePort = ..#ACCEPT
    Set tRoutines = ##class(OcuPilot.Test.DatabaseWrite).InstallRoutines()
    Do $$$AssertTrue(tRoutines '= "", "the install namespace's routines database is read (" _ tRoutines _ ")")
    For tName = "OCUPILOT", tRoutines, "IRISSYS" {
        Set tDirectory = ##class(OcuPilot.Test.DatabaseWriteProbe).Stored(tName, "Directory")
        Do $$$AssertTrue(tDirectory '= "", tName _ ": its directory is read (" _ tDirectory _ ")")
        Do $ClassMethod(..#ACCEPT, "Clear")
        Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).Act("dismount", tDirectory), "403 " _ ..#OWNCODE, tName _ ": the screen's dismount is refused")
        Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).Agent(..#DISMOUNTTOOL, tDirectory, {}), "403 " _ ..#OWNCODE, tName _ ": and the agent's")
        Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", tName _ ": no write reached the port")
        Set tImpact = ..Impact(tDirectory)
        Do $$$AssertEquals($Select($IsObject(tImpact) && $IsObject(tImpact.refused): tImpact.kind _ "|" _ tImpact.refused.code _ "|" _ tImpact.refused.reason, 1: ""), "database-dismount|" _ ..#OWNCODE _ "|" _ ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(..#OWNCODE), tName _ ": the Dismount dialog states the refusal when it opens")
    }
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(..#OWNCODE) [ "cannot be deleted or dismounted", "the refusal's sentence names the dismount")
}

/// <p>A protected directory spelled another way (AC5): OcuPilot's own database and the install
/// namespace's routines database, each named with a <code>.</code> segment, a doubled separator and a
/// <code>..</code> segment -- spellings the vendor opens as that same database -- are refused on both
/// callers with no write sent.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.DatabasePort.StateOf</method> answers a spelling that
/// normalization changes -> the dismount arm compares that spelling, the accept port records a
/// dismount and this goes red.</p>
Method TestAProtectedDirectorySpelledAnotherWayIsNotDismounted()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.DatabaseActions).Enable(..#DISMOUNTKEY), "the agent's dismount key is enabled, so only the refusals stand in the way")
    Set ^||OcuPilotDatabaseWritePort = ..#ACCEPT
    Set tRoutines = ##class(OcuPilot.Test.DatabaseWrite).InstallRoutines()
    For tName = "OCUPILOT", tRoutines {
        Set tDirectory = ##class(OcuPilot.Test.DatabaseWriteProbe).Stored(tName, "Directory")
        Set tBare = $ZStrip(tDirectory, ">", "/")
        Set tLast = $Piece(tBare, "/", $Length(tBare, "/"))
        Set tParent = $Piece(tBare, "/", 1, $Length(tBare, "/") - 1)
        For tSpelling = tBare _ "/./", tParent _ "//" _ tLast _ "/", tBare _ "/../" _ tLast _ "/" {
            Do $ClassMethod(..#ACCEPT, "Clear")
            Do $$$AssertNotEquals(##class(OcuPilot.Test.DatabaseActions).Act("dismount", tSpelling), "200 ", tName _ " as " _ tSpelling _ ": the screen's dismount is refused")
            Do $$$AssertNotEquals(##class(OcuPilot.Test.DatabaseActions).Agent(..#DISMOUNTTOOL, tSpelling, {}), "200 ", tName _ " as " _ tSpelling _ ": and the agent's")
            Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", tName _ " as " _ tSpelling _ ": no write reached the port")
        }
    }
}

/// <p>Every other operation of a protected database stays permitted (AC5): the prohibited set answers
/// nothing for a mount, truncate, compact or defragment of <code>IRISSYS</code>'s directory, and the
/// screen's truncate of it reaches the port; a probe database's dismount has no impact to state.</p>
/// <p>Mutation (Rule 19): the dismount arm refuses every write type -> the truncate is refused and this
/// goes red.</p>
Method TestTheOtherOperationsOfAProtectedDatabaseArePermitted()
{
    Set tDirectory = ##class(OcuPilot.Test.DatabaseWriteProbe).Stored("IRISSYS", "Directory")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("database", "instance", tDirectory, .tRef)
    For tTool = "mount", "truncate", "compact", "defragment" {
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits("osmgmt.databasedetails." _ tTool, tRef, "{}", "[]", .tProhibits, .tCode)
        Do $$$AssertStatusOK(tSC, tTool _ ": the set answers")
        Do $$$AssertEquals(tProhibits _ "|" _ tCode, "0|", tTool _ ": and prohibits nothing for IRISSYS")
    }
    Set ^||OcuPilotDatabaseWritePort = ..#ACCEPT
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).Act("truncate", tDirectory, {"TargetSize": "0"}), "200 ", "the screen's truncate of IRISSYS passes every gate")
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "Database.Actions/TRUNCATE", "and reaches the port, which sends nothing")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", ..#NAME), "a probe database is created")
    Do $$$AssertEquals(..Impact($ClassMethod(..#PROBE, "DirectoryOf", ..#NAME)), "", "and its dismount has no impact to state")
}

/// <p>An own database by fixture, and a failed own-set read (AC5): with a probe database standing as an
/// own database (<class>OcuPilot.Test.DatabaseProhibitedFixture</class>) its dismount is refused on both
/// callers; with the own names unread, and with the own directories unread, it is refused too; and no
/// write reaches the port.</p>
/// <p>Mutation (Rule 19): the arm carries on with an empty own set when a read fails -> the dismount is
/// an accepted write and this goes red.</p>
Method TestAnOwnProbeAndAFailedOwnSetReadAreRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", ..#NAME), "a probe database is created")
    Set tDirectory = $ClassMethod(..#PROBE, "DirectoryOf", ..#NAME)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.DatabaseActions).Enable(..#DISMOUNTKEY), "the agent's dismount key is enabled")
    Set ^||OcuPilotDatabaseProhibited = "OcuPilot.Test.DatabaseProhibitedFixture"
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("OcuPilot.Test.DatabaseProhibitedFixture")
    Set ^||OcuPilotDatabaseWritePort = ..#ACCEPT
    For tCase = "own", "names", "directories" {
        Kill ^||OcuPilotDatabaseOwnProbe, ^||OcuPilotDatabaseOwnFail
        If tCase = "own" Set ^||OcuPilotDatabaseOwnProbe = ..#NAME
        If tCase '= "own" Set ^||OcuPilotDatabaseOwnFail = tCase
        Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).Act("dismount", tDirectory), "403 " _ ..#OWNCODE, tCase _ ": the screen's dismount is refused")
        Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).Agent(..#DISMOUNTTOOL, tDirectory, {}), "403 " _ ..#OWNCODE, tCase _ ": and the agent's")
    }
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", "no write reached the port")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).StateOf(tDirectory, "Mounted"), "true", "and the database is still mounted")
}

/// <p>The dismount's impact for the database in <var>pDirectory</var>, as the screen's dialog asks it
/// when it opens (<class>OcuPilot.Api.ScreenImpact</class>), or <code>""</code>.</p>
ClassMethod Impact(pDirectory As %String) As %DynamicObject
{
    Set tSC = ##class(OcuPilot.Api.ScreenAction).Preview("OcuPilot.Screen.Descriptor.DatabaseDetails", "dismount", pDirectory, "", .tPreview)
    If '$IsObject($Get(tPreview)) Quit ""
    Quit ##class(OcuPilot.Kernel.Proposal.Impact).Of(tPreview.%Get("tool"), tPreview.%Get("targetRef"), tPreview.%Get("fresh").%ToJSON(), tPreview.%Get("payload").%ToJSON(), tPreview.%Get("diff").%ToJSON())
}

}
