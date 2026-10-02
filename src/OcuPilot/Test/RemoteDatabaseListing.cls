/// <p>Pins Story 18.16's bounded listing (AD-21's seventh case, AD-42's child-job model): on this
/// instance, whose license enables no ECP, the real listing answers
/// <code>DATABASE.SERVER.UNREACHABLE</code> at once and starts no child; through the seam
/// (<class>OcuPilot.Test.RemoteDatabaseListingPort</class>) on a licensed instance, the listing answers
/// the data server's rows from a child job, a child past its bound is cut there and its late answer is
/// discarded by the next listing, and a server listing no rows while not connected is unreachable; and
/// an agent's mint lists nothing, while its confirm and a Save each list once.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, a license that enables no ECP
/// (IRIS Community), and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the
/// class defines probe ECP data servers (configuration only, never contacted) and probe remote
/// configurations (<class>OcuPilot.Test.RemoteDatabaseProbe</class>), and sets the governance policy.
/// Every probe object is removed by exact name before all, after each and after all.</p>
Class OcuPilot.Test.RemoteDatabaseListing Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PROBE = "OcuPilot.Test.RemoteDatabaseProbe";

Parameter SEAM = "OcuPilot.Test.RemoteDatabaseListingPort";

/// <p>The rules whose reads, form read and listing route go through the seam.</p>
Parameter RULES = "OcuPilot.Test.RemoteDatabaseRulesFixture";

Parameter PORT = "OcuPilot.Port.RemoteDatabasePort";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.RemoteDatabaseCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.RemoteDatabaseUpdate";

Parameter UNREACHABLE = "DATABASE.SERVER.UNREACHABLE";

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RemoteDatabaseListing defines probe ECP data servers and remote databases on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#SEAM, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object is removed by exact name")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>The license pre-check: this instance's license enables no ECP, so a listing answers
/// <code>DATABASE.SERVER.UNREACHABLE</code> on <code>Server</code> within a second -- well inside its
/// bound plus 2 s -- with the license sentence, and starts no child. The seam, which keeps the
/// instance's own license, is asked first; only when it started no child is the shipped port asked,
/// so a port without the pre-check never opens a real ECP connection here.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.RemoteDatabasePort.Directories</method> skips its
/// <method>OcuPilot.Port.RemoteDatabasePort.NetworkEnabled</method> check -> the seam's child is
/// started and lists, and this goes red.</p>
Method TestAnUnlicensedListingAnswersAtOnceAndStartsNothing()
{
    Do $$$AssertEquals($SYSTEM.License.NetworkEnabled(), 0, "this instance's license enables no ECP, the case this leg pins")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer"), "the probe data server is defined")
    Set tSC = $ClassMethod(..#SEAM, "Directories", "OCUPROBE1816SRV", .tRows, .tTruncated, .tHttp, .tFault)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Refusal", tSC, tHttp, tFault), "422 Server:" _ ..#UNREACHABLE, "the listing on this license is refused on Server")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Listings") _ "/" _ $ClassMethod(..#SEAM, "Spawns"), "1/0", "having been asked once and started no child")
    If ($ClassMethod(..#SEAM, "Spawns") > 0) || ($SYSTEM.License.NetworkEnabled() '= 0) Quit
    Set tStart = $ZHorolog
    Set tSC = $ClassMethod(..#PORT, "Directories", "OCUPROBE1816SRV", .tRows, .tTruncated, .tHttp, .tFault)
    Set tSeconds = $ZHorolog - tStart
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Refusal", tSC, tHttp, tFault), "422 Server:" _ ..#UNREACHABLE, "the shipped listing is refused alike")
    Do $$$AssertTrue(tSeconds < 1, "at once (" _ tSeconds _ " s), inside the bound plus 2 s (" _ ($Parameter(..#PORT, "LISTSECONDS") + 2) _ " s)")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Reason", tFault) [ "license", "with the sentence naming the license")
}

/// <p>A licensed listing, through the seam: the data server's rows come back from one child job,
/// and a server answering no rows while not connected is unreachable.</p>
Method TestALicensedListingAnswersTheServersRows()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer"), "the probe data server is defined")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE1816DOWN"), "and one that lists nothing")
    Set ^||OcuPilotRemoteLicensed = 1
    Set tSC = $ClassMethod(..#SEAM, "Directories", "OCUPROBE1816SRV", .tRows, .tTruncated, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the listing answers")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", tRows), "OCUPROBE1816X:/ocuprobe1816x/,OCUPROBE1816Y:/ocuprobe1816y/,IRISSYS:" _ $ClassMethod(..#SEAM, "Manager"), "with the data server's three rows")
    Do $$$AssertEquals(tTruncated, 0, "uncut")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Spawns"), 1, "from one child job")
    Set tSC = $ClassMethod(..#SEAM, "Directories", "OCUPROBE1816DOWN", .tRows, .tTruncated, .tHttp, .tFault)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Refusal", tSC, tHttp, tFault), "422 Server:" _ ..#UNREACHABLE, "a server listing no rows while not connected is unreachable")
}

/// <p>The bound: a child that answers past a one-second bound is cut at the bound, nothing is
/// answered from it, and its late answer, arriving while nobody waits, is discarded by the next
/// listing, which answers its own server's rows.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.RemoteDatabasePort.Directories</method> runs
/// <method>OcuPilot.Port.RemoteDatabasePort.ListRows</method> in process instead of in the child -> the
/// slow listing answers after three seconds and this goes red.</p>
Method TestAChildPastTheBoundIsCutAndItsLateAnswerDiscarded()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer"), "the probe data server is defined")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE1816SLOW"), "and a slow one")
    Set ^||OcuPilotRemoteLicensed = 1
    Set ^||OcuPilotRemoteBound = 1
    Set tStart = $ZHorolog
    Set tSC = $ClassMethod(..#SEAM, "Directories", "OCUPROBE1816SLOW", .tRows, .tTruncated, .tHttp, .tFault)
    Set tSeconds = $ZHorolog - tStart
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Refusal", tSC, tHttp, tFault), "422 Server:" _ ..#UNREACHABLE, "the slow listing is refused on Server")
    Do $$$AssertTrue((tSeconds >= 0.9) && (tSeconds < 2), "at its one-second bound (" _ tSeconds _ " s)")
    Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Size(), 1: -1), 0, "answering no row")
    ; The abandoned child answers about two seconds later, while nobody waits.
    Hang $Parameter(..#SEAM, "SLOWSECONDS")
    Kill ^||OcuPilotRemoteBound
    Set tSC = $ClassMethod(..#SEAM, "Directories", "OCUPROBE1816SRV", .tRows, .tTruncated, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the next listing answers")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", tRows), "OCUPROBE1816X:/ocuprobe1816x/,OCUPROBE1816Y:/ocuprobe1816y/,IRISSYS:" _ $ClassMethod(..#SEAM, "Manager"), "its own server's rows, the late answer discarded")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Spawns"), 2, "each from its own child")
}

/// <p>No listing at a mint (AD-7): on this instance any listing is refused, so an agent's create and
/// re-point naming a directory no data server lists are each minted, the mint having asked only the
/// name and the server; a confirm on this license is refused unreachable with nothing written, and one
/// made through the seam, licensed, lists once.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.OsMgmt.RemoteDatabaseRules.Problem</method> asks
/// the tool's port's listing -> the mint is refused unreachable and this goes red.</p>
Method TestAMintListsNothingAndItsConfirmListsOnce()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer"), "the probe data server is defined")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816R"), "and a remote database to re-point")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "OCUPROBE1816A", {"Name": "OCUPROBE1816A", "Server": "OCUPROBE1816SRV", "Directory": "/nowhere1816/"}, .tCreate, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted without a listing (" _ tProblem _ ")")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OCUPROBE1816R", {"Name": "OCUPROBE1816R", "Directory": "/nowhere1816r/"}, .tUpdate, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "and the re-point (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Consequence", tCreate) _ "|" _ $ClassMethod(..#PROBE, "Consequence", tUpdate), "DATABASE.REMOTELIST|DATABASE.REMOTELIST", "each card states the listing the confirm makes")
    ; On this license (the seam keeps the instance's own): the confirm is refused unreachable, nothing written.
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Confirm", tCreate), "422 " _ ..#UNREACHABLE, "the create's confirm on this license is refused unreachable")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBE1816A"), 0, "and nothing is written")
    ; Through the seam, licensed: the re-point's confirm lists once and is refused on Directory.
    Do $ClassMethod(..#SEAM, "Clear")
    Set ^||OcuPilotRemoteLicensed = 1
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Confirm", tUpdate), "422 DATABASE.REMOTEDIRECTORY.ABSENT", "the re-point's confirm lists, and the unlisted directory is refused")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Listings"), 1, "having listed once")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OCUPROBE1816R", "Directory"), "/ocuprobe1816r/", "and the configuration is unchanged")
}

/// <p>The admin port admits the listing as a read and resolves the vendor's type for it, without
/// sending it: a member of <code>CONNECTIONREADTYPES</code>, keyed by its pair and not mutating.</p>
/// <p>Mutation (Rule 19): drop the <code>CONNECTIONREADTYPES</code> branch from
/// <method>OcuPilot.Port.AdminPort.EndpointType</method> -> the type resolves empty and this goes
/// red.</p>
Method TestThePortAdmitsTheListingAsARead()
{
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsConnectionRead("ECP.DataServer", "DBLIST"), "the listing is a connection read")
    Do $$$AssertTrue('##class(OcuPilot.Port.AdminPort).IsConnectionRead("Database.ConfigCRUD", "DBLIST"), "keyed by its pair, not by its type alone")
    Do $$$AssertTrue('##class(OcuPilot.Port.AdminPort).IsMutating("ECP.DataServer", "DBLIST"), "and not a mutating type")
    Set tType = $ClassMethod(..#SEAM, "ListingType")
    Do $$$AssertTrue((tType '= "") && (tType = +tType), "the port resolves the vendor's type for it (" _ tType _ ")")
}

/// <p>A licensed listing of a connected data server that holds no database answers no rows, rather
/// than refusing the server unreachable, so the form can say it lists no databases.</p>
/// <p>Mutation (Rule 19): drop the <method>OcuPilot.Port.RemoteDatabasePort.ServerStatus</method> term
/// from <method>OcuPilot.Port.RemoteDatabasePort.Directories</method> -> the empty listing is refused
/// unreachable and this goes red.</p>
Method TestAConnectedServerListingNothingAnswersNoRows()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE1816EMPTY"), "a probe data server that reads connected and lists nothing")
    Set ^||OcuPilotRemoteLicensed = 1
    Set tSC = $ClassMethod(..#SEAM, "Directories", "OCUPROBE1816EMPTY", .tRows, .tTruncated, .tHttp, .tFault)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Refusal", tSC, tHttp, tFault), "ok", "the listing answers")
    Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Size(), 1: -1) _ " " _ tHttp, "0 200", "with no rows")
}

/// <p>The listing route answers the data server's rows as the form reads them --
/// <code>{server, rows: [{Name, Directory}], truncated}</code> -- through the seam on a licensed
/// instance.</p>
/// <p>Mutation (Rule 19): rename <code>rows</code> in
/// <method>OcuPilot.Area.OsMgmt.RemoteDatabaseRules.HandleDirectories</method> -> this goes red.</p>
Method TestTheListingRouteAnswersTheRowsTheFormReads()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer"), "the probe data server is defined")
    Set ^||OcuPilotRemoteLicensed = 1
    Do $$$AssertStatusOK($ClassMethod(..#RULES, "Route", "directories", "OCUPROBE1816SRV", .tAnswer, .tStatus), "the route runs")
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(tAnswer) } Catch {}
    Do $$$AssertEquals(tStatus, 200, "it answers 200: " _ $Extract(tAnswer, 1, 200))
    If '$IsObject(tBody) Quit
    Do $$$AssertEquals(tBody.%Get("server") _ "|" _ tBody.%GetTypeOf("rows") _ "|" _ tBody.%GetTypeOf("truncated") _ "|" _ tBody.%Get("truncated"), "OCUPROBE1816SRV|array|boolean|0", "naming its server, its rows and whether they were cut")
    If tBody.%GetTypeOf("rows") '= "array" Quit
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", tBody.%Get("rows")), "OCUPROBE1816X:/ocuprobe1816x/,OCUPROBE1816Y:/ocuprobe1816y/,IRISSYS:" _ $ClassMethod(..#SEAM, "Manager"), "each row a database's name and directory")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Spawns"), 1, "from one child job")
}

}
