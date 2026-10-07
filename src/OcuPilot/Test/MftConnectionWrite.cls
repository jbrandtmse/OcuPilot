/// <p>Pins Story 18.26's writes on both callers of each tool (C2 to C5): the form's Save
/// (<class>OcuPilot.Test.MftSaveFixture</class>) and the list's row actions
/// (<class>OcuPilot.Test.MftActionFixture</class>), and the agent's mint and confirm
/// (<class>OcuPilot.Test.DatabaseConfirm</class>) -- a create that makes no OAuth 2.0 client configuration, a
/// change that sends the fresh read's five fields, a delete that removes the client configuration and description
/// it names, a delete over an absent client answered as done, every row of the rules refused before any
/// <code>PUT</code>, a taken name, a moved target, a held lock, a revoke refused without a token and sent with one,
/// and the write routes over the wire.</p>
/// <p>Every write is real for a connection named <code>OcuMftProbe...</code> and refused for any other:
/// <class>OcuPilot.Test.MftSeamPort</class> records every call. A connection holding a token cannot exist here, so
/// the revoke that finds one is a seam answer (<method>OcuPilot.Test.MftSeamPort.ArmAuthorized</method>); the
/// vendor's <code>REVOKE</code> itself is real and changes nothing for a connection with no token, and no call
/// reaches a file service.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, a stock instance with no
/// connection, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and
/// deletes probe connections, client configurations and descriptions and sets the governance policy. Every probe
/// object is removed by exact name before all, after each and after all, and after each test the connection list
/// reads as that test found it.</p>
Class OcuPilot.Test.MftConnectionWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.MftProbe";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter SEAM = "OcuPilot.Test.MftSeamPort";

Parameter SAVE = "OcuPilot.Test.MftSaveFixture";

Parameter ACTION = "OcuPilot.Test.MftActionFixture";

Parameter CREATETOOL = "OcuPilot.Test.SeamMftConnectionCreate";

Parameter UPDATETOOL = "OcuPilot.Test.SeamMftConnectionUpdate";

Parameter DELETETOOL = "OcuPilot.Test.SeamMftConnectionDelete";

Parameter REVOKETOOL = "OcuPilot.Test.SeamMftConnectionRevoke";

Parameter SCREEN = "security.mftconnections";

Parameter ERRORS = "OcuPilot.Api.MftConnectionError";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.MftConnectionWrite creates, changes and deletes probe connections on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts")
    Do $ClassMethod(..#SEAM, "Clear")
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("OcuPilot.Test.MftSet")
    Kill tSettings
    Set tSettings("security.mftconnections.create") = "enabled"
    Set tSettings("security.mftconnections.update") = "enabled"
    Set tSettings("security.mftconnections.delete") = "enabled"
    Set tSettings("security.mftconnections.revoketoken") = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#SEAM, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "every probe object is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "and none is left")
    Do $$$AssertNotEquals(..PreparedFacts, "unreadable", "the connection list was read before the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedFacts, "the connection list reads as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll"))
}

/// <p>C2: a create on both callers sends one <code>PUT</code> carrying the five fields; the instance stores them,
/// the id is the name as written, the read-back matches, and <b>no OAuth 2.0 client configuration or description
/// is made</b> for the client it names.</p>
/// <p>Mutation (Rule 19): drop <code>Service</code> from the create's <code>PERMITTEDFIELDS</code> -- the vendor
/// refuses the body and both legs go red.</p>
Method TestACreateSendsTheFiveFieldsOnBothCallersAndMakesNoClient()
{
    Set tBody = $ClassMethod(..#PROBE, "Body", "OcuMftProbeA")
    Do tBody.%Set("Name", "OcuMftProbeA")
    Set tSC = $ClassMethod(..#SAVE, "Handle", "", tBody, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 201, "the form's create answers 201: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "PUT:OcuMftProbeA", "sending one PUT")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(##class(OcuPilot.Test.LicenseKey).Parsed($ClassMethod(..#SEAM, "BodyOf", "Security.MFT/PUT"))), "ApplicationName,SSLConfiguration,Service,URL,Username", "carrying the five fields")
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)
    Do $$$AssertEquals($Select($IsObject(tParsed) && $IsObject(tParsed.%Get("readBack")): tParsed.%Get("id") _ " " _ tParsed.%Get("readBack").%Get("verdict"), 1: ""), "OcuMftProbeA matches", "the id as written, and the read-back matches")
    Set tStored = $ClassMethod(..#PROBE, "Stored", "OcuMftProbeA")
    Do $$$AssertEquals($Select($IsObject(tStored): tStored.%Get("Service") _ "|" _ tStored.%Get("Username") _ "|" _ tStored.%Get("ApplicationName"), 1: ""), "Box|probe@ocumftprobe.invalid|OcuMftProbeAApp", "the instance stores it")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsClient", "OcuMftProbeAApp") _ $ClassMethod(..#PROBE, "Descriptions"), "00", "and made no client configuration or description")

    Do $ClassMethod(..#SEAM, "Clear")
    Set tArgs = $ClassMethod(..#PROBE, "Body", "OcuMftProbeB", {"Service": "Dropbox"})
    Do tArgs.%Set("Name", "OcuMftProbeB")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "OcuMftProbeB", tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "PUT:OcuMftProbeB", "sending one PUT")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "matches", "its read-back matches")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OcuMftProbeB").%Get("Service") _ $ClassMethod(..#PROBE, "HoldsClient", "OcuMftProbeBApp"), "Dropbox0", "the instance holds it, and no client configuration")
}

/// <p>C2: a change on both callers sends the fresh read's five fields with the change applied, <code>Service</code>
/// as read, and nothing else moves; a change that changes nothing sends nothing; a body naming <code>Service</code>
/// is 400 before anything is read; a stored value the rules would refuse is never refused when the change leaves it
/// as it is, an SSL/TLS configuration that no longer exists among them.</p>
/// <p>Mutation (Rule 19): let the update tool admit <code>Service</code> -- the Service leg sends the
/// <code>PUT</code> and goes red.</p>
Method TestAChangeSendsTheFreshFiveFieldsOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeA", {"Username": "before@ocumftprobe.invalid", "URL": "not a url", "SSLConfiguration": "OcuNoSuchTLS"}), "a probe connection, whose stored URL and SSL/TLS configuration no rule would accept")
    Set tSC = $ClassMethod(..#SAVE, "Handle", "OcuMftProbeA", {"Username": "form@ocumftprobe.invalid"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the form's change answers 200 although the stored URL and SSL/TLS configuration are not acceptable: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "PUT:OcuMftProbeA", "sending one PUT")
    Set tSent = ##class(OcuPilot.Test.LicenseKey).Parsed($ClassMethod(..#SEAM, "BodyOf", "Security.MFT/PUT"))
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tSent), "ApplicationName,SSLConfiguration,Service,URL,Username", "carrying the five fields")
    Do $$$AssertEquals(tSent.%Get("Service") _ "|" _ tSent.%Get("URL") _ "|" _ tSent.%Get("SSLConfiguration") _ "|" _ tSent.%Get("Username"), "Box|not a url|OcuNoSuchTLS|form@ocumftprobe.invalid", "Service, URL and SSL/TLS configuration as read, the Username as changed")
    Do $$$AssertEquals(..Verdict(##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)), "matches", "the read-back matches")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", "OcuMftProbeA", {"Username": "form@ocumftprobe.invalid"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#SEAM, "Writes"), "200 ", "a change that changes nothing sends nothing")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", "OcuMftProbeA", {"Service": "Dropbox"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer).%Get("code") _ " " _ $ClassMethod(..#SEAM, "Calls"), "400 PORT.FIELD.UNEXPECTED ", "a body naming Service is refused before anything is read")

    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuMftProbeA", {"Name": "OcuMftProbeA", "Username": "agent@ocumftprobe.invalid"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "PUT:OcuMftProbeA", "sending one PUT")
    Set tSent = ##class(OcuPilot.Test.LicenseKey).Parsed($ClassMethod(..#SEAM, "BodyOf", "Security.MFT/PUT"))
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tSent) _ "|" _ tSent.%Get("Service"), "ApplicationName,SSLConfiguration,Service,URL,Username|Box", "carrying the same five fields, Service as read")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "matches", "its read-back matches")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OcuMftProbeA").%Get("Username"), "agent@ocumftprobe.invalid", "and the instance holds it")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuMftProbeA", {"Name": "OcuMftProbeA", "Service": "Dropbox"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "an agent change naming Service is refused at the mint: " _ tProblem)
}

/// <p>C3: a delete on both callers removes the connection, its OAuth 2.0 client configuration and that client's
/// description when it was the last client; with a second connection naming the client, the client is kept until
/// the last goes; a delete of a name the instance does not hold is 404 <code>PORT.NOTFOUND</code> with no
/// write.</p>
/// <p>Mutation (Rule 19): none beyond <method>TestADeleteOverAnAbsentClientIsAnsweredAsDeleted</method>; the
/// vendor's removal of the client is measured, and this leg pins it.</p>
Method TestADeleteRemovesTheConnectionItsClientAndItsDescription()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", "OcuMftProbeAApp"), "a probe client configuration and description")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeA"), "and the connection naming it")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": "OcuMftProbeA"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the list's Delete answers 200: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "DELETE:OcuMftProbeA", "sending one DELETE")
    Do $$$AssertEquals($IsObject($ClassMethod(..#PROBE, "Stored", "OcuMftProbeA")) _ $ClassMethod(..#PROBE, "HoldsClient", "OcuMftProbeAApp") _ $ClassMethod(..#PROBE, "Descriptions"), "000", "the connection, the client configuration and its description are gone")
    Do $$$AssertEquals(..Verdict(##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)), "notFound", "the read-back reads notFound")

    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": "OcuMftProbeZ"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer).%Get("code") _ " " _ $ClassMethod(..#SEAM, "Writes"), "404 PORT.NOTFOUND ", "a connection the instance does not hold is 404 with no write")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", "OcuMftProbeSharedApp"), "a client configuration two connections name")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeB", {"ApplicationName": "OcuMftProbeSharedApp"}), "the first")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeC", {"ApplicationName": "OcuMftProbeSharedApp"}), "and the second")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#DELETETOOL, "OcuMftProbeB", {"Name": "OcuMftProbeB"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "destructive") _ " " _ ##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "consequence"), "1 MFT.DELETE", "destructive, stating the client's removal")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "DELETE:OcuMftProbeB", "sending one DELETE")
    Do $$$AssertEquals($IsObject($ClassMethod(..#PROBE, "Stored", "OcuMftProbeB")) _ $IsObject($ClassMethod(..#PROBE, "Stored", "OcuMftProbeC")) _ $ClassMethod(..#PROBE, "HoldsClient", "OcuMftProbeSharedApp") _ $ClassMethod(..#PROBE, "Descriptions"), "0111", "the first is gone and the shared client and description stay")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": "OcuMftProbeC"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#PROBE, "HoldsClient", "OcuMftProbeSharedApp") _ $ClassMethod(..#PROBE, "Descriptions"), "200 00", "the last connection takes the client and its description with it")
}

/// <p>C3: a connection whose client configuration is absent is deleted by the vendor, which then answers 500; the
/// port re-reads, finds it absent and answers the delete as done on both callers, with the read-back reading
/// absent. A <code>DELETE</code> of a name no connection holds stays 404, and a 500 followed by a re-read that
/// cannot say stays the fault.</p>
/// <p>Mutation (Rule 19): remove the re-read from <method>OcuPilot.Port.MftPort.Delete</method> -- the list's
/// Delete answers the 500 and the first leg goes red.</p>
Method TestADeleteOverAnAbsentClientIsAnsweredAsDeleted()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeA"), "a probe connection naming no client configuration")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": "OcuMftProbeA"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the list's Delete answers 200 as done: " _ $Extract(tAnswer, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "DELETE:OcuMftProbeA", "after one DELETE")
    Do $$$AssertEquals($IsObject($ClassMethod(..#PROBE, "Stored", "OcuMftProbeA")), 0, "the connection is gone")
    Do $$$AssertEquals(..Verdict(##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)), "notFound", "and the read-back reads it absent")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeB"), "a second connection")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#DELETETOOL, "OcuMftProbeB", {"Name": "OcuMftProbeB"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed as done")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ $IsObject($ClassMethod(..#PROBE, "Stored", "OcuMftProbeB")), "DELETE:OcuMftProbeB 0", "after one DELETE, the connection gone")

    Do $ClassMethod(..#SEAM, "Clear")
    Kill tQuery
    Set tQuery("connection") = "OcuMftProbeZ"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Security.MFT", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $ClassMethod(..#SEAM, "Calls"), "404 Security.MFT/DELETE", "a name no connection holds is 404, and is not re-read")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeC"), "a third connection")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "ArmFail", "Security.MFT/GET")
    Kill tQuery
    Set tQuery("connection") = "OcuMftProbeC"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Security.MFT", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 500, "a 500 whose re-read cannot say is the fault as it is")
    Do $$$AssertStatusNotOK(tSC, "as an error status")
    Do $ClassMethod(..#SEAM, "Clear")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeD"), "a fourth connection")
    Do $ClassMethod(..#SEAM, "ArmFail", "Security.MFT/DELETE")
    Kill tQuery
    Set tQuery("connection") = "OcuMftProbeD"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Security.MFT", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a DELETE that fails while the connection stays is an error status")
    Do $$$AssertEquals(tHttp _ " " _ $ClassMethod(..#SEAM, "Calls"), "500 Security.MFT/DELETE,Security.MFT/GET", "the fault as it is, after one re-read that finds the connection")
    Do $$$AssertEquals($IsObject($ClassMethod(..#PROBE, "Stored", "OcuMftProbeD")), 1, "and the connection is still stored")
    Do $ClassMethod(..#SEAM, "Clear")
}

/// <p>C5: every row of the rules is refused on its field before any <code>PUT</code>, by the form's Save as a 422
/// <code>MFT.VALIDATION</code> carrying the violation and by the agent's mint as its problem, naming the field and
/// the published sentence.</p>
/// <p>Mutation (Rule 19): drop the <code>Service</code> rule from
/// <method>OcuPilot.Area.Security.MftConnectionRules.Valid</method> -- its legs send the <code>PUT</code> and go
/// red.</p>
Method TestEveryRulesRowIsRefusedBeforeAnyPutOnBothCallers()
{
    Set tErrors = ..#ERRORS
    Set tShape = ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE
    Set tLongName = $Translate($Justify("", 65), " ", "n")
    Set tLongUrl = "https://h.invalid/" _ $Translate($Justify("", 1010), " ", "u") _ "/"
    Set tCases = ""
    For tField = "Service", "URL", "SSLConfiguration", "Username", "ApplicationName" {
        Set tCases = tCases _ $ListBuild($ListBuild("no " _ tField, "{""" _ tField _ """: null}", tField, $ClassMethod("OcuPilot.Area.Security.MftConnectionRules", "CodeFor", tField), "drop"))
    }
    Set tCases = tCases _ $ListBuild($ListBuild("name empty", "{""Name"": """"}", "Name", $Parameter(tErrors, "NAME"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("name over 64", "{""Name"": """ _ tLongName _ """}", "Name", $Parameter(tErrors, "NAME"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("name with a control character", "{""Name"": ""OcuMftProbe\u0007x""}", "Name", $Parameter(tErrors, "NAME"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("service box", "{""Service"": ""box""}", "Service", $Parameter(tErrors, "SERVICE"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("service Foo", "{""Service"": ""Foo""}", "Service", $Parameter(tErrors, "SERVICE"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("url not a url", "{""URL"": ""not a url""}", "URL", $Parameter(tErrors, "URL"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("url without the slash", "{""URL"": ""https://h.invalid""}", "URL", $Parameter(tErrors, "URL"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("url ftp", "{""URL"": ""ftp://h.invalid/""}", "URL", $Parameter(tErrors, "URL"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("url over 1024", "{""URL"": """ _ tLongUrl _ """}", "URL", $Parameter(tErrors, "URL"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("ssl absent", "{""SSLConfiguration"": ""OcuNoSuchTLS""}", "SSLConfiguration", $Parameter(tErrors, "SSLCONFIG"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("ssl a server configuration", "{""SSLConfiguration"": ""OcuMftProbeServerTLS""}", "SSLConfiguration", $Parameter(tErrors, "SSLCONFIG"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("ssl empty", "{""SSLConfiguration"": """"}", "SSLConfiguration", $Parameter(tErrors, "SSLCONFIG"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("username empty", "{""Username"": """"}", "Username", $Parameter(tErrors, "USERNAME"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("username over 160", "{""Username"": """ _ $Translate($Justify("", 161), " ", "u") _ """}", "Username", $Parameter(tErrors, "USERNAME"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("application name empty", "{""ApplicationName"": """"}", "ApplicationName", $Parameter(tErrors, "APPLICATIONNAME"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("application name over 64", "{""ApplicationName"": """ _ tLongName _ """}", "ApplicationName", $Parameter(tErrors, "APPLICATIONNAME"), ""))
    Set tCases = tCases _ $ListBuild($ListBuild("url a number", "{""URL"": 5}", "URL", tShape, ""))
    Set tCases = tCases _ $ListBuild($ListBuild("username a boolean", "{""Username"": true}", "Username", tShape, ""))
    Set tCases = tCases _ $ListBuild($ListBuild("service an object", "{""Service"": {}}", "Service", tShape, ""))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tBody = $ClassMethod(..#PROBE, "Body", "OcuMftProbeR")
        Do tBody.%Set("Name", "OcuMftProbeR")
        Set tOverride = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Set tIterator = tOverride.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If $List(tCase, 5) = "drop" {
                Do tBody.%Remove(tKey)
            } Else {
                Set tType = tOverride.%GetTypeOf(tKey)
                If (tType = "object") || (tType = "array") {
                    Do tBody.%Set(tKey, tValue)
                } Else {
                    Do tBody.%Set(tKey, tValue, tType)
                }
            }
        }
        Do $ClassMethod(..#SEAM, "Clear")
        Do $ClassMethod(..#SEAM, "ArmSslType", "OcuMftProbeServerTLS", 1)
        Set tSC = $ClassMethod(..#SAVE, "Handle", "", tBody, .tAnswer, .tStatus)
        Set tWhy = ..ViolationOf(tAnswer, $List(tCase, 3))
        Do $$$AssertEquals(tStatus _ " " _ tWhy, "422 " _ $List(tCase, 4), $List(tCase, 1) _ ": the Save is refused on " _ $List(tCase, 3) _ ": " _ $Extract(tAnswer, 1, 200))
        Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer).%Get("code"), $Parameter(tErrors, "VALIDATION"), $List(tCase, 1) _ ": under the validation envelope, never INTERNAL")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", $List(tCase, 1) _ ": before any PUT")
        Set tName = $Select($IsObject(tBody) && (tBody.%GetTypeOf("Name") = "string"): tBody.%Get("Name"), 1: "OcuMftProbeR")
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, tName, tBody, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 1) _ ": the agent's mint is refused")
        Do $$$AssertTrue(tProblem [ ("'" _ $List(tCase, 3) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 4))), $List(tCase, 1) _ ": naming the field and the published sentence: " _ tProblem)
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", $List(tCase, 1) _ ": and no PUT")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "no probe connection was created")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeU"), "a probe connection to change")
    For tCase = $ListBuild("url", "{""URL"": ""nope""}", "URL", $Parameter(tErrors, "URL")), $ListBuild("username", "{""Username"": """"}", "Username", $Parameter(tErrors, "USERNAME")), $ListBuild("ssl", "{""SSLConfiguration"": ""OcuNoSuchTLS""}", "SSLConfiguration", $Parameter(tErrors, "SSLCONFIG")), $ListBuild("ssl server", "{""SSLConfiguration"": ""OcuMftProbeServerTLS""}", "SSLConfiguration", $Parameter(tErrors, "SSLCONFIG")), $ListBuild("application name", "{""ApplicationName"": """"}", "ApplicationName", $Parameter(tErrors, "APPLICATIONNAME")) {
        Do $ClassMethod(..#SEAM, "Clear")
        Do $ClassMethod(..#SEAM, "ArmSslType", "OcuMftProbeServerTLS", 1)
        Set tChange = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Set tSC = $ClassMethod(..#SAVE, "Handle", "OcuMftProbeU", tChange, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, $List(tCase, 3)) _ " " _ $ClassMethod(..#SEAM, "Writes"), "422 " _ $List(tCase, 4) _ " ", $List(tCase, 1) _ ": a change is refused on its field before any PUT: " _ $Extract(tAnswer, 1, 200))
        Do tChange.%Set("Name", "OcuMftProbeU")
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuMftProbeU", tChange, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 1) _ ": and the agent's change is refused (" _ tProblem _ ")")
        Do $$$AssertTrue(tProblem [ ("'" _ $List(tCase, 3) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 4))), $List(tCase, 1) _ ": naming the field and the published sentence: " _ tProblem)
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", $List(tCase, 1) _ ": with no PUT from either caller")
    }
}

/// <p>A look-up the rules cannot make is an error, never a pass: a create whose SSL/TLS configuration read or
/// name read fails other than with 404 is refused 500 <code>INTERNAL</code> with no write.</p>
/// <p>Mutation (Rule 19): let <method>OcuPilot.Area.Security.MftConnectionRules.ClientConfiguration</method> pass a
/// failed read -- the SSL/TLS leg answers 422 and goes red.</p>
Method TestALookUpThatCannotBeMadeRefusesTheSave()
{
    For tPair = "Security.SSLConfig/GET", "Security.MFT/GET" {
        Set tBody = $ClassMethod(..#PROBE, "Body", "OcuMftProbeL")
        Do tBody.%Set("Name", "OcuMftProbeL")
        Do $ClassMethod(..#SEAM, "Clear")
        Do $ClassMethod(..#SEAM, "ArmFail", tPair)
        Set tSC = $ClassMethod(..#SAVE, "Handle", "", tBody, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer).%Get("code") _ " " _ $ClassMethod(..#SEAM, "Writes"), "500 INTERNAL ", tPair _ " failing refuses the create with no write: " _ $Extract(tAnswer, 1, 200))
    }
    Do $ClassMethod(..#SEAM, "Clear")
}

/// <p>C2: a name taken since is refused by the absence fingerprint and by the Save's own look-up, a target moved
/// since the mint refuses the confirm as changed, and a target another write holds answers 409
/// <code>WRITE.TARGETBUSY</code> after the wait, with no write.</p>
/// <p>Mutation (Rule 19): drop the <code>HoldTool</code> from
/// <method>OcuPilot.Area.Security.MftConnectionSave.HandleUpdate</method> -- the busy leg writes and goes red.</p>
Method TestATakenNameAMovedTargetAndABusyTargetAreRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeA", {"Username": "first@ocumftprobe.invalid"}), "a probe connection")
    Set tBody = $ClassMethod(..#PROBE, "Body", "OcuMftProbeA")
    Do tBody.%Set("Name", "OcuMftProbeA")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", "", tBody, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, "Name") _ " " _ $ClassMethod(..#SEAM, "Writes"), "422 " _ $Parameter(..#ERRORS, "TAKEN") _ " ", "a create of a taken name is refused on Name with no write: " _ $Extract(tAnswer, 1, 200))
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "OcuMftProbeA", tBody, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "the agent's create of it is refused at the mint: " _ tProblem)
    Set tFree = $ClassMethod(..#PROBE, "Body", "OcuMftProbeB")
    Do tFree.%Set("Name", "OcuMftProbeB")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "OcuMftProbeB", tFree, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a create of a free name is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeB"), "and the name is taken since")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused by the absence fingerprint")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with no write")

    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuMftProbeA", {"Name": "OcuMftProbeA", "Username": "second@ocumftprobe.invalid"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a change is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeA", {"URL": "https://moved.ocumftprobe.invalid/"}), "and a field the payload carries moves")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused as a changed target")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with no write")

    Do ##class(OcuPilot.Kernel.EntityRef).Key("mft-connection", "instance", "OcuMftProbeA", .tRef)
    Set tLockKey = ##class(OcuPilot.Kernel.State.Propose).TargetHoldKey(tRef)
    Do $$$AssertNotEquals(tLockKey, "", "the connection names a lock")
    Lock +^OcuPilotProposalTarget(tLockKey):5
    Set tHeld = $Test
    Do $$$AssertTrue(tHeld, "which this process holds, as another write's hold does")
    If 'tHeld Quit
    Set tStatus = 0
    Set tBusy = ""
    Try {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/mft-connection/" _ ##class(OcuPilot.Kernel.EntityId).Encode("OcuMftProbeA"), .tStatus, .tBusy, {"Username": "busy@ocumftprobe.invalid"}.%ToJSON(), "application/json")
    } Catch {
    }
    Lock -^OcuPilotProposalTarget(tLockKey)
    Set tAnswer = tStatus _ " " _ $Select($IsObject(tBusy): tBusy.%Get("code") _ " " _ tBusy.%Get("reason"), 1: tBusy)
    Do $$$AssertEquals(tAnswer, "409 WRITE.TARGETBUSY " _ ##class(OcuPilot.Api.Error).#REASONWRITETARGETBUSY, "the held Save is refused busy, with the published reason")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OcuMftProbeA").%Get("Username"), "probe@ocumftprobe.invalid", "and nothing was written")

    Do ##class(OcuPilot.Kernel.EntityRef).Key("mft-connection", "instance", "OcuMftProbeC", .tFreeRef)
    Set tFreeKey = ##class(OcuPilot.Kernel.State.Propose).TargetHoldKey(tFreeRef)
    Lock +^OcuPilotProposalTarget(tFreeKey):5
    Set tHeld = $Test
    Do $$$AssertTrue(tHeld, "a free name's lock, held as another create's hold is")
    If 'tHeld Quit
    Set tCreate = $ClassMethod(..#PROBE, "Body", "OcuMftProbeC")
    Do tCreate.%Set("Name", "OcuMftProbeC")
    Set tStatus = 0
    Set tBusy = ""
    Try {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/mft-connection", .tStatus, .tBusy, tCreate.%ToJSON(), "application/json")
    } Catch {
    }
    Lock -^OcuPilotProposalTarget(tFreeKey)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBusy): tBusy.%Get("code"), 1: tBusy), "409 WRITE.TARGETBUSY", "a create of a held name is refused busy")
    Do $$$AssertEquals($IsObject($ClassMethod(..#PROBE, "Stored", "OcuMftProbeC")), 0, "and nothing was created")
}

/// <p>C4: a revoke of a connection that holds no token is refused <code>MFT.TOKEN.NONE</code> by the fresh read on
/// both callers, with no <code>REVOKE</code> sent; with the seam reading the connection as authorized, the agent's
/// revoke is minted destructive and confirmed, and the list's Revoke token is answered, each sending one
/// <code>REVOKE</code> through the admin port and reading back as nothing sent, although the connection then reads
/// not authorized (AD-58); a token gone between the mint and the confirm closes the proposal as a changed
/// target.</p>
/// <p>Mutation (Rule 19): stop <method>OcuPilot.Port.MftPort.State</method> refusing "Not Authorized" -- the
/// refusal legs send the <code>REVOKE</code> and go red.</p>
Method TestARevokeIsRefusedWithoutATokenAndSentWithOne()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeA"), "a probe connection holding no token")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#REVOKETOOL, "OcuMftProbeA", {"Name": "OcuMftProbeA"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "the agent's revoke is refused at the mint")
    Do $$$AssertEquals(tHttp _ " " _ tProblem, "409 " _ $Parameter(..#ERRORS, "TOKENNONE"), "as MFT.TOKEN.NONE")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "revoke-token", "id": "OcuMftProbeA"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer).%Get("code"), "409 " _ $Parameter(..#ERRORS, "TOKENNONE"), "so is the list's Revoke token: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "and no REVOKE was sent")

    Do $ClassMethod(..#SEAM, "ArmAuthorized", "OcuMftProbeA")
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#REVOKETOOL, "OcuMftProbeA", {"Name": "OcuMftProbeA"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "with a token the agent's revoke is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "destructive") _ " " _ ##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "consequence"), "1 MFT.REVOKE", "destructive, stating its consequence")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "REVOKE:OcuMftProbeA", "sending one REVOKE")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "nothingSent", "read back as nothing sent, the connection now not authorized")
    Do $ClassMethod(..#SEAM, "ArmAuthorized", "OcuMftProbeA")
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "revoke-token", "id": "OcuMftProbeA"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#SEAM, "Writes"), "200 REVOKE:OcuMftProbeA", "the list's Revoke token sends one REVOKE: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals(..Verdict(##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)), "nothingSent", "and reads back as nothing sent")

    Do $ClassMethod(..#SEAM, "ArmAuthorized", "OcuMftProbeA")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#REVOKETOOL, "OcuMftProbeA", {"Name": "OcuMftProbeA"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a revoke is minted again")
    Kill ^||OcuPilotMftSeam("authorized")
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the token gone since, its confirm is refused as a changed target")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with no REVOKE")
}

/// <p>The write routes answer over the wire as JSON: <code>POST /mft-connection</code> creates a probe connection
/// with 201 and <code>PUT /mft-connection/:id</code> changes it with 200, each answering the id and the read-back,
/// and a body key outside the settings is 400 <code>PORT.FIELD.UNEXPECTED</code>. The name holds a space and a dot,
/// which the path segment carries encoded (AD-13). The write reaches the real port, for a probe name alone.</p>
/// <p>Mutation (Rule 19): remove <code>POST /mft-connection</code> from <file>Api/Router.cls</file> -- the create
/// leg goes red.</p>
Method TestTheWriteRoutesAnswerOverTheWire()
{
    Set tName = "OcuMftProbe W.1"
    Set tBody = $ClassMethod(..#PROBE, "Body", tName)
    Do tBody.%Set("Name", tName)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/mft-connection", .tStatus, .tAnswer, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "POST /mft-connection answers 201")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("id") _ " " _ ..Verdict(tAnswer), 1: ""), tName _ " matches", "with the id and the read-back")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("Username"), "probe@ocumftprobe.invalid", "and the instance holds it")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/mft-connection/" _ ##class(OcuPilot.Kernel.EntityId).Encode(tName), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tChangeStatus, .tChangeRaw, .tHeaders, {"Username": "wire@ocumftprobe.invalid"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tChangeStatus, 200, "PUT /mft-connection/:id answers 200: " _ $Extract(tChangeRaw, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals(..Verdict(##class(OcuPilot.Test.LicenseKey).Parsed(tChangeRaw)), "matches", "with its read-back")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("Username"), "wire@ocumftprobe.invalid", "and the instance holds the change")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/mft-connection/" _ ##class(OcuPilot.Kernel.EntityId).Encode(tName), .tUnexpectedStatus, .tUnexpected, {"Service": "Dropbox"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tUnexpectedStatus _ " " _ $Select($IsObject(tUnexpected): tUnexpected.%Get("code"), 1: ""), "400 PORT.FIELD.UNEXPECTED", "a body naming Service is refused before anything is read")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/mft-connection/" _ ##class(OcuPilot.Kernel.EntityId).Encode("OcuMftProbeZ"), .tAbsentStatus, .tAbsent, {"Username": "x@ocumftprobe.invalid"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tAbsentStatus _ " " _ $Select($IsObject(tAbsent): tAbsent.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "a connection the instance does not hold is 404")
}

/// <p>The read-back verdict of <var>pAnswer</var>, or <code>(none)</code>.</p>
ClassMethod Verdict(pAnswer) As %String
{
    If '$IsObject(pAnswer) || (pAnswer.%GetTypeOf("readBack") '= "object") Quit "(none)"
    Quit pAnswer.%Get("readBack").%Get("verdict")
}

/// <p>The code of the violation on <var>pField</var> in the envelope text <var>pAnswer</var>, or
/// <code>""</code>.</p>
ClassMethod ViolationOf(pAnswer As %String, pField As %String) As %String
{
    Set tAnswer = ##class(OcuPilot.Test.LicenseKey).Parsed(pAnswer)
    If '$IsObject(tAnswer) || '$IsObject(tAnswer.%Get("detail")) || (tAnswer.%Get("detail").%GetTypeOf("violations") '= "array") Quit ""
    Set tIterator = tAnswer.%Get("detail").%Get("violations").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("field") = pField Quit
        Set tRow = ""
    }
    Quit $Select($IsObject($Get(tRow)): tRow.%Get("code"), 1: "")
}

}
