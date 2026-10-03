/// <p>Pins Story 18.6's license server writes on both callers of each tool (AC A5, A6; AD-53, AD-55):
/// the form's Save (<class>OcuPilot.Test.LicenseSaveFixture</class>) and the list's Delete
/// (<class>OcuPilot.Test.LicenseActionFixture</class>), and the agent's mint and confirm
/// (<class>OcuPilot.Test.DatabaseConfirm</class>) -- the matrix's create, update, delete, refusal and
/// absent-target legs and the stored upper-case name.</p>
/// <p>The vendor's writes are real; <class>OcuPilot.Test.LicenseSeamPort</class> records every call and
/// sends it, so a refusal shows as a recorded write or none.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes
/// probe license servers (<class>OcuPilot.Test.LicenseProbe</class>) and sets the governance policy.
/// Every probe object is removed by exact name before all, after each and after all, and after each test
/// the license and its servers read as that test found them.</p>
Class OcuPilot.Test.LicenseServerWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_LICENSE_CONFIG";

Parameter PROBE = "OcuPilot.Test.LicenseProbe";

Parameter SEAM = "OcuPilot.Test.LicenseSeamPort";

Parameter SAVE = "OcuPilot.Test.LicenseSaveFixture";

Parameter ACTION = "OcuPilot.Test.LicenseActionFixture";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.LicenseServerCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.LicenseServerUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.LicenseServerDelete";

Parameter SCREEN = "osmgmt.licenseservers";

Parameter LIST = "OcuPilot.Screen.Descriptor.LicenseServerList";

Parameter DELETEKEY = "osmgmt.licenseservers.delete";

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The license's facts and license servers before each test
/// (<method>OcuPilot.Test.LicenseProbe.LicenseLines</method>), which the test must leave as found.</p>
Property PreparedLicense As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LicenseServerWrite creates and deletes probe license servers on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>Every test records through the seam, with the agent's delete key enabled over the snapshot.</p>
Method OnBeforeOneTest() As %Status
{
    Set ..PreparedLicense = $ClassMethod(..#PROBE, "LicenseLines")
    Do $ClassMethod(..#SEAM, "Clear")
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#SEAM, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object is removed by exact name")
    Do $$$AssertTrue(..PreparedLicense [ "license|KeyOrderNumber|", "the license snapshot was taken before the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LicenseLines"), ..PreparedLicense, "the license and the instance's license servers read as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>A5: a create on both callers sends one <code>License.Server</code> <code>PUT</code> carrying
/// <code>{Address, Port}</code>; the instance stores the name upper-cased, the list shows it, and the
/// read-back matches.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.OsMgmt.LicenseRules.Shape</method> does nothing -- the
/// form's port is sent as a string and the sent-type leg goes red.</p>
Method TestACreateWritesTheAddressAndPortOnBothCallers()
{
    Set tSC = $ClassMethod(..#SAVE, "Handle", "create", "", {"Name": "ocuprobe186a", "Address": "127.0.0.1", "Port": "4999"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 201, "the form's create answers 201: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "License.Server/PUT", "sending one PUT")
    Do $$$AssertEquals(..Keys($ClassMethod(..#SEAM, "BodyOf", "License.Server/PUT")), "Address,Port", "carrying the address and the port")
    Set tSent = ..Parsed($ClassMethod(..#SEAM, "BodyOf", "License.Server/PUT"))
    Do $$$AssertEquals($Select($IsObject(tSent): tSent.%GetTypeOf("Port"), 1: ""), "number", "the form's port sent as a number, as the vendor's read answers it")
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals($Select($IsObject(tParsed): tParsed.%Get("name") _ " " _ tParsed.%Get("readBack").%Get("verdict"), 1: ""), "OCUPROBE186A matches", "naming the stored server, and its read-back matches")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "ocuprobe186b", {"Name": "ocuprobe186b", "Address": "127.0.0.1", "Port": 4997}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Confirm", tProposal, .tResult), "200 ", "and its confirm writes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "License.Server/PUT", "one PUT")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)) && $IsObject(tResult.%Get("readBack")): tResult.%Get("readBack").%Get("verdict"), 1: ""), "matches", "and its read-back matches")
    Set tListed = $ClassMethod(..#PROBE, "ListText", ..#LIST, "Name")
    Do $$$AssertTrue((tListed [ ",OCUPROBE186A,") && (tListed [ ",OCUPROBE186B,"), "both are listed upper-cased: " _ tListed)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OCUPROBE186A", "Port") _ " " _ $ClassMethod(..#PROBE, "Stored", "ocuprobe186b", "Port"), "4999 4997", "and stored with their ports, resolved in any case")
}

/// <p>A5: an update on both callers sends the complete <code>{Address, Port}</code> read fresh, the
/// agent's with one diff row, and never <code>KeyDirectory</code>, which stays as stored.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.LicenseServerUpdate.MergeUpdate</method> sends only
/// the changed field -- the body's keys shrink to <code>Port</code> and this goes red.</p>
Method TestAnUpdateSendsTheCompleteSetReadFreshAndNeverTheKeyDirectory()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186U"), "a probe license server")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedKeyDirectory", "OCUPROBE186U", "/tmp/ocuprobe186kd/"), "with a key directory")
    Set tSC = $ClassMethod(..#SAVE, "Handle", "update", "OCUPROBE186U", {"Port": 4998}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the form's update answers 200: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals(..Keys($ClassMethod(..#SEAM, "BodyOf", "License.Server/PUT")), "Address,Port", "sending the complete set")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OCUPROBE186U", "Port") _ " " _ $ClassMethod(..#PROBE, "Stored", "OCUPROBE186U", "KeyDirectory"), "4998 /tmp/ocuprobe186kd/", "the port is written and the key directory kept")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186V"), "a second probe license server")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OCUPROBE186V", {"Name": "OCUPROBE186V", "Port": 4997}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's update is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($Select($IsObject(tProposal): tProposal.%Get("changed").%Size(), 1: -1), 1, "with one diff row")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Confirm", tProposal, .tResult), "200 ", "and its confirm writes")
    Do $$$AssertEquals(..Keys($ClassMethod(..#SEAM, "BodyOf", "License.Server/PUT")), "Address,Port", "the complete set")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)) && $IsObject(tResult.%Get("readBack")): tResult.%Get("readBack").%Get("verdict"), 1: ""), "matches", "and its read-back matches")
}

/// <p>A5, AD-21: a caller's <code>KeyDirectory</code> is refused on both callers before anything is
/// sent: the Save 400 <code>PORT.FIELD.UNEXPECTED</code>, the agent's arguments
/// <code>TOOL.ARGUMENTS</code>.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.LicenseServerUpdate.PERMITTEDFIELDS</parameter>
/// admits <code>KeyDirectory</code> -- both legs go red.</p>
Method TestACallersKeyDirectoryIsNeverSent()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186K"), "a probe license server")
    Set tSC = $ClassMethod(..#SAVE, "Handle", "update", "OCUPROBE186K", {"KeyDirectory": "/tmp/ocuprobe186other/"}, .tAnswer, .tStatus)
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tParsed): tParsed.%Get("code"), 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "the form's key directory is refused: " _ $Extract(tAnswer, 1, 200))
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OCUPROBE186K", {"Name": "OCUPROBE186K", "KeyDirectory": "/tmp/ocuprobe186other/"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals(tHttp, 400, "and so is the agent's: " _ tProblem)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ "|" _ $ClassMethod(..#PROBE, "Stored", "OCUPROBE186K", "KeyDirectory"), "|", "with nothing sent and nothing stored")
}

/// <p>A5: a delete on both callers sends <code>License.Server</code> <code>DELETE</code>; the server
/// leaves the list and the read-back reads it absent.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.LicenseServerDelete.WRITETYPE</parameter>
/// <code>GET</code> -- nothing is deleted and this goes red.</p>
Method TestADeleteRemovesTheServerOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186D"), "a probe license server")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186E"), "and the agent's")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": "OCUPROBE186D"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the list's delete answers 200: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "License.Server/DELETE", "sending one DELETE")
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals($Select($IsObject(tParsed): tParsed.%Get("action") _ " " _ tParsed.%Get("readBack").%Get("verdict"), 1: ""), "deleted notFound", "answering the delete, read back absent")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#DELETETOOL, "OCUPROBE186E", {"Name": "OCUPROBE186E"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Confirm", tProposal, .tResult), "200 ", "and its confirm deletes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "License.Server/DELETE", "one DELETE")
    Set tListed = $ClassMethod(..#PROBE, "ListText", ..#LIST, "Name")
    Do $$$AssertTrue((tListed '= "") && '(tListed [ ",OCUPROBE186D,") && '(tListed [ ",OCUPROBE186E,"), "neither is listed: " _ tListed)
}

/// <p>A6: a name of the wrong shape or one the instance holds in any case, an address that is empty or
/// one <class>Config.Host</class> refuses, and a port outside 1 to 65535 or not a number are each
/// refused on their field on both callers' create, and an address or port of either kind on both
/// callers' update, before any vendor write.</p>
/// <p>Mutation (Rule 19): drop the range from <method>OcuPilot.Area.OsMgmt.LicenseRules.IsPort</method>
/// -- port 65536 is written and this goes red.</p>
Method TestBadNamesAddressesAndPortsAreRefusedBeforeAnyWrite()
{
    For tCase = $ListBuild("local", "127.0.0.1", "4999", "Name:LICENSE.SERVER.NAME.TAKEN"), $ListBuild("1 a", "127.0.0.1", "4999", "Name:LICENSE.SERVER.NAME.SHAPE"), $ListBuild("a.b", "127.0.0.1", "4999", "Name:LICENSE.SERVER.NAME.SHAPE"), $ListBuild("ocuprobe186r", "", "4999", "Address:LICENSE.SERVER.ADDRESS"), $ListBuild("ocuprobe186r", "my host", "4999", "Address:LICENSE.SERVER.ADDRESS"), $ListBuild("ocuprobe186r", $Translate($Justify("", 256), " ", "a"), "4999", "Address:LICENSE.SERVER.ADDRESS"), $ListBuild("ocuprobe186r", "127.0.0.1", "0", "Port:LICENSE.SERVER.PORT"), $ListBuild("ocuprobe186r", "127.0.0.1", "65536", "Port:LICENSE.SERVER.PORT"), $ListBuild("ocuprobe186r", "127.0.0.1", "x", "Port:LICENSE.SERVER.PORT") {
        Do $ClassMethod(..#SEAM, "Clear")
        Set tBody = {}
        Do tBody.%Set("Name", $List(tCase, 1), "string")
        Do tBody.%Set("Address", $List(tCase, 2), "string")
        Do tBody.%Set("Port", $List(tCase, 3), "string")
        Set tSC = $ClassMethod(..#SAVE, "Handle", "create", "", tBody, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ..Violation(tAnswer), "422 " _ $List(tCase, 4), $ListToString(tCase, " ") _ ": the form's create is refused on its field")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", $ListToString(tCase, " ") _ ": before any vendor write")
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, $List(tCase, 1), tBody, .tProposal, .tHttp, .tProblem)
        If $List(tCase, 1) = "local" {
            ; The agent's create of a name the instance holds in any case is refused by the mint's
            ; absence read (AD-54), before any rule runs.
            Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "already present"), $ListToString(tCase, " ") _ ": and the agent's is refused as present: " _ tProblem)
            Continue
        }
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ ##class(OcuPilot.Api.Error).ReasonForViolation($Piece($List(tCase, 4), ":", 2))), $ListToString(tCase, " ") _ ": and the agent's is refused with the same sentence: " _ tProblem)
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "no probe server was created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186W"), "a probe license server to update")
    For tCase = $ListBuild("Port", 0, "Port:LICENSE.SERVER.PORT"), $ListBuild("Port", 65536, "Port:LICENSE.SERVER.PORT"), $ListBuild("Address", "", "Address:LICENSE.SERVER.ADDRESS"), $ListBuild("Address", "my host", "Address:LICENSE.SERVER.ADDRESS") {
        Do $ClassMethod(..#SEAM, "Clear")
        Set tBody = {}
        Do tBody.%Set($List(tCase, 1), $List(tCase, 2), $Select($List(tCase, 1) = "Port": "number", 1: "string"))
        Set tSC = $ClassMethod(..#SAVE, "Handle", "update", "OCUPROBE186W", tBody, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ..Violation(tAnswer), "422 " _ $List(tCase, 3), $ListToString(tCase, " ") _ ": the form's update is refused on its field")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", $ListToString(tCase, " ") _ ": before any vendor write")
        Do tBody.%Set("Name", "OCUPROBE186W", "string")
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OCUPROBE186W", tBody, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ ##class(OcuPilot.Api.Error).ReasonForViolation($Piece($List(tCase, 3), ":", 2))), $ListToString(tCase, " ") _ ": and the agent's update is refused with the same sentence: " _ tProblem)
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", $ListToString(tCase, " ") _ ": with nothing written")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OCUPROBE186W", "Address") _ ":" _ $ClassMethod(..#PROBE, "Stored", "OCUPROBE186W", "Port"), $Parameter(..#PROBE, "SERVERADDRESS") _ ":" _ $Parameter(..#PROBE, "SERVERPORT"), "and the server is as seeded")
}

/// <p>A6: an update or delete of a server the instance no longer defines sends nothing: the Save and
/// the list's delete answer 404, and the agent's confirm of a server deleted since its mint is refused
/// as a changed target.</p>
Method TestAnAbsentTargetIsRefusedAndNothingIsSent()
{
    Set tSC = $ClassMethod(..#SAVE, "Handle", "update", "OCUPROBE186GONE", {"Port": 4998}, .tAnswer, .tStatus)
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tParsed): tParsed.%Get("code"), 1: ""), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "the form's update of an absent server is 404: " _ $Extract(tAnswer, 1, 200))
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": "OCUPROBE186GONE"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 404, "and the list's delete is 404: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with nothing sent")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186X"), "a probe license server")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OCUPROBE186X", {"Name": "OCUPROBE186X", "Port": 4998}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's update is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveServer", "OCUPROBE186X"), "and the server is deleted since")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused as a changed target")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ "|" _ $ClassMethod(..#PROBE, "ServerExists", "OCUPROBE186X"), "|0", "with nothing sent and nothing re-created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186Y"), "a probe license server for the agent's delete")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#DELETETOOL, "OCUPROBE186Y", {"Name": "OCUPROBE186Y"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveServer", "OCUPROBE186Y"), "and the server is deleted since")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused as a changed target")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with nothing sent")
}

/// <p>The keys of the JSON object <var>pJson</var>, sorted and comma-joined.</p>
ClassMethod Keys(pJson As %String) As %String
{
    Set tObject = ..Parsed(pJson)
    If '$IsObject(tObject) Quit ""
    Quit ##class(OcuPilot.Test.LicenseKey).Keys(tObject)
}

/// <p>The first violation of the envelope <var>pJson</var>, <code>field:code</code>.</p>
ClassMethod Violation(pJson As %String) As %String
{
    Quit ##class(OcuPilot.Test.LicenseKey).Violation(pJson)
}

/// <p><var>pJson</var> parsed as an object, or <code>""</code>.</p>
ClassMethod Parsed(pJson As %String) As %DynamicObject
{
    Quit ##class(OcuPilot.Test.LicenseKey).Parsed(pJson)
}

}
