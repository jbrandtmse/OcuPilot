/// <p>Pins Story 12.6's authenticator (AD-3, AD-35, AD-39): the port's <code>AUTHENTICATORS</code> read
/// answers the classes a namespace compiles, each with its settings less the credential-named ones; a
/// custom authenticator's credential-named setting (<class>OcuPilot.Test.OAuthProbeAuthenticator</class>'s
/// <code>ApiKey</code>) is never answered by the port's read or the form read, is kept stored across a
/// Save that leaves it out, and is refused by name when a caller sends it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo fixture
/// and its test classes compiled in this namespace, an account holding <code>%All</code>, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes OAuth 2.0
/// resource servers and server descriptions.</p>
Class OcuPilot.Test.OAuthResourceServerAuthenticator Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.OAuthResourceServerUpdate";

Parameter SCREEN = "OcuPilot.Test.OAuthResourceServerSaveFixture";

Parameter RECORD = "OcuPilot.Test.OAuthResourceServerRecordPort";

Parameter PROBE = "OcuPilot.Test.OAuthResourceServerProbe";

Parameter HELPER = "OcuPilot.Test.OAuthServerProbe";

Parameter PORT = "OcuPilot.Port.OAuthResourceServerPort";

Parameter ENDPOINT = "Security.OAuth2.ResourceServer";

Parameter SIMPLE = "%OAuth2.ResourceServer.SimpleAuthenticator";

Parameter FORMPATH = "/oauth/resource-server/form";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthResourceServerAuthenticator creates and deletes OAuth 2.0 resource servers on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "AddServer", ..Issuer())
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe object is removed by exact name")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

ClassMethod Issuer() As %String
{
    Quit $ClassMethod(..#PROBE, "Issuer", "authenticator")
}

/// <p>The probe authenticator as a body member, with <var>pClaim</var>.</p>
ClassMethod Probe(pClaim As %String) As %DynamicObject
{
    Set tAuthenticator = {}
    Do tAuthenticator.%Set("Namespace", $ClassMethod(..#PROBE, "Namespace"), "string")
    Do tAuthenticator.%Set("Implementation", $Parameter(..#PROBE, "AUTHENTICATOR"), "string")
    Do tAuthenticator.%Set("Claim", pClaim, "string")
    Quit tAuthenticator
}

/// <p>Make server <var>pName</var> whose authenticator is the probe's, holding <var>pKey</var> as its
/// <code>ApiKey</code>.</p>
ClassMethod MakeServer(pName As %String, pKey As %String) As %Status
{
    Set tAuthenticator = ..Probe("sub")
    Do tAuthenticator.%Set("ApiKey", pKey, "string")
    Quit $ClassMethod(..#PROBE, "AddResource", pName, ..Issuer(), $ListBuild("aud.authenticator"), {"Authenticator": (tAuthenticator)})
}

/// <p>The <code>AUTHENTICATORS</code> read of <var>pNamespace</var>.</p>
ClassMethod Offered(pNamespace As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "AUTHENTICATORS", .tQuery, "", .tRead, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit ""
    Quit tRead
}

/// <p>The settings <var>pRead</var> offers for <var>pClass</var>, sorted, comma-separated, or
/// <code>-</code> when it offers no such class.</p>
ClassMethod SettingsFor(pRead As %DynamicObject, pClass As %String) As %String
{
    If '$IsObject(pRead) Quit "-"
    Set tOut = "-"
    Set tIterator = pRead.%Get("Authenticators").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.%Get("Implementation") '= pClass Continue
        Set tNames = ""
        Set tSettings = tEntry.%Get("Settings").%GetIterator()
        While tSettings.%GetNext(.tSettingIndex, .tSetting) { Set tNames = tNames _ $ListBuild(tSetting.%Get("name") _ ":" _ tSetting.%Get("type")) }
        Set tOut = $ClassMethod(..#HELPER, "Sorted", tNames)
    }
    Quit tOut
}

/// <p>AC6's list: <code>%SYS</code> offers the simple authenticator and its three settings; this
/// namespace offers the probe authenticator with <code>Claim</code> and without <code>ApiKey</code>; a
/// namespace that does not exist offers the simple authenticator alone.</p>
Method TestTheImplementationsAreTheNamespacesOwn()
{
    Set tSys = ..Offered("%SYS")
    Do $$$AssertEquals(..SettingsFor(tSys, ..#SIMPLE), "Prefix:string,RoleClaim:string,UserClaim:string", "%SYS offers the simple authenticator's three settings")
    Set tHere = ..Offered($ClassMethod(..#PROBE, "Namespace"))
    Do $$$AssertEquals(..SettingsFor(tHere, $Parameter(..#PROBE, "AUTHENTICATOR")), "Claim:string", "this namespace offers the probe authenticator's Claim and not its ApiKey")
    Set tNone = ..Offered("OCUPILOTNOSUCHNS")
    Do $$$AssertTrue($IsObject(tNone) && (tNone.%Get("Namespace") = "%SYS") && (tNone.%Get("Authenticators").%Size() = 1) && (..SettingsFor(tNone, ..#SIMPLE) '= "-"), "a namespace that does not exist offers the simple authenticator alone")
}

/// <p>AC6: the probe's <code>ApiKey</code> is never answered by the port's read or the form read, and a
/// Save that changes <code>Claim</code> and leaves the key out keeps it stored.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.OAuthResourceServerPort.Stripped</method> stops removing
/// the credential-named settings -- the no-read assertions go red.</p>
Method TestTheProbesKeyIsNeverReadAndKeptAcrossASave()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Key")
    Set tKey = $ClassMethod(..#PROBE, "Secret", "apikey")
    Do $$$AssertStatusOK(..MakeServer(tName, tKey), "a server with the probe authenticator is created")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("Authenticator").%Get("ApiKeyLength"), $Length(tKey), "the instance holds the key")
    Set tRead = $ClassMethod(..#PROBE, "Read", tName)
    Do $$$AssertTrue($IsObject(tRead) && (tRead.%ToJSON() '[ tKey) && (tRead.%Get("Authenticator").%GetTypeOf("ApiKey") = "unassigned"), "the port's read answers neither the key nor its setting")
    Do $$$AssertEquals($Select($IsObject(tRead): tRead.%Get("Authenticator").%Get("Claim"), 1: ""), "sub", "while it answers Claim")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#FORMPATH _ "?name=" _ $ZConvert(tName, "O", "URL"), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the form read answers")
    Do $$$AssertTrue((tRaw '[ tKey) && (tRaw '[ "ApiKey"), "and carries neither the key nor its setting")
    Set tBody = {}
    Do tBody.%Set("Authenticator", ..Probe("email"))
    Set tSC = $ClassMethod(..#SCREEN, "Update", tName, tBody, [], [], .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "a Save changing Claim completes: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastBody", "PUT") [ tKey, 0, "the body the Save composed carries no key before the port")
    Set tStored = $ClassMethod(..#PROBE, "Stored", tName).%Get("Authenticator")
    Do $$$AssertEquals(tStored.%Get("Claim") _ " " _ tStored.%Get("ApiKeyLength"), "email " _ $Length(tKey), "the instance holds the new Claim and keeps the key")
}

/// <p>A caller that sends the credential-named setting is refused by name on both callers and at the
/// port, and nothing is sent.</p>
Method TestSendingTheKeyIsRefusedByName()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Sent")
    Set tKey = $ClassMethod(..#PROBE, "Secret", "sentkey")
    Do $$$AssertStatusOK(..MakeServer(tName, tKey), "a server with the probe authenticator is created")
    Set tAuthenticator = ..Probe("sub")
    Do tAuthenticator.%Set("ApiKey", "ocupilotreplacedprobe000", "string")
    Set tBody = {}
    Do tBody.%Set("Authenticator", tAuthenticator)
    Set tSC = $ClassMethod(..#SCREEN, "Update", tName, tBody, [], [], .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals($ClassMethod(..#HELPER, "CodeFor", .tViolations, "Authenticator.ApiKey"), "OAUTH.AUTHENTICATOR.SECRET", "the Save refuses the setting by name")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and sends nothing")
    Set tArgs = ##class(%DynamicObject).%FromJSON(tBody.%ToJSON())
    Do tArgs.%Set("Name", tName, "string")
    Set tSC = $ClassMethod(..#HELPER, "Mint", ..#UPDATETOOL, tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && ($ClassMethod(..#HELPER, "Problem", $Get(tFault)) [ ("'Authenticator.ApiKey': " _ ##class(OcuPilot.Api.Error).#REASONOAUTHAUTHENTICATORSECRET)), "the agent's mint refuses it by name")
    Kill tQuery
    Set tQuery("name") = tName
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "PUT", .tQuery, tBody, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)) && (tFault.%GetTypeOf("detail") = "object"): tFault.%Get("detail").%Get("violations").%Get(0).%Get("code"), 1: ""), "422 OAUTH.AUTHENTICATOR.SECRET", "and so does the port")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("Authenticator").%Get("ApiKeyLength"), $Length(tKey), "the stored key is unchanged")
}

/// <p>The port checks the authenticator itself: a class the namespace does not compile, and a
/// namespace that does not exist, are refused on their member before the vendor is called.</p>
Method TestThePortRefusesAnAuthenticatorItCannotUse()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "Port")
    Do $$$AssertStatusOK(..MakeServer(tName, "x"), "a server is created")
    Kill tQuery
    Set tQuery("name") = tName
    For tCase = $ListBuild("OCUPILOTNOSUCHNS", ..#SIMPLE, "Authenticator.Namespace"), $ListBuild("%SYS", "OcuPilot.Test.NoSuchAuthenticator", "Authenticator.Implementation") {
        Set tBody = {}
        Do tBody.%Set("Authenticator", {"Namespace": ($List(tCase, 1)), "Implementation": ($List(tCase, 2))})
        Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "PUT", .tQuery, tBody, .tResult, .tHttp, .tFault)
        Set tRow = $Select($IsObject($Get(tFault)) && (tFault.%GetTypeOf("detail") = "object"): tFault.%Get("detail").%Get("violations").%Get(0), 1: {})
        Do $$$AssertEquals(tHttp _ " " _ tRow.%Get("field"), "422 " _ $List(tCase, 3), $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": refused on " _ $List(tCase, 3))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName).%Get("Authenticator").%Get("Implementation"), $Parameter(..#PROBE, "AUTHENTICATOR"), "and the authenticator is unchanged")
}

}
