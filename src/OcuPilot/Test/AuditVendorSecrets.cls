/// <p>Pins AD-35's masking of the secrets IRIS writes into its own audit rows (DW-1640, Story 12.5):
/// a real vendor row carrying a probe registration access token, written by a client's secrets write,
/// and one carrying a probe initial access token, written by a server description's token write, each
/// read masked through the Logs audit screen's read over the wire and through
/// <code>logs.audit.read</code>, while the audit database itself still holds the value; and the mask
/// reads the per-event declaration alone.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo
/// fixture and auditing on, an account holding <code>%All</code>, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes OAuth
/// 2.0 client configurations and server descriptions. The rows it writes stay in the audit database,
/// which it neither copies nor purges.</p>
Class OcuPilot.Test.AuditVendorSecrets Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PORT = "OcuPilot.Port.AuditPort";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.AuditList";

Parameter READPATH = "/screens/logs.audit/read";

Parameter TOOLNAME = "logs.audit.read";

Parameter PROBE = "OcuPilot.Test.OAuthClientProbe";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditVendorSecrets creates and deletes OAuth 2.0 client configurations on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe object is removed by exact name")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>The declaration names the six vendor events measured on a throwaway, each with the key its rows
/// carry, and the vendor event they are all rows of.</p>
Method TestTheDeclarationNamesTheMeasuredEvents()
{
    Set tDeclared = $Parameter(..#PORT, "VENDORSECRETS")
    For tEvent = "Create OAuth2 Server Definition", "Modify OAuth2 Server Definition" {
        Do $$$AssertTrue(tDeclared [ (tEvent _ "=InitialAccessToken:registration_access_token"), tEvent _ ": declares the initial access token and the registration access token")
    }
    For tEvent = "Create OAuth2 Client", "Modify OAuth2 Client", "Create OAuth2 Client Metadata", "Modify OAuth2 Client Metadata" {
        Do $$$AssertTrue((";" _ tDeclared _ ";") [ (";" _ tEvent _ "=registration_access_token;"), tEvent _ ": declares the registration access token")
    }
    Do $$$AssertEquals($Length(tDeclared, ";"), 6, "and nothing else")
    Do $$$AssertEquals($Parameter(..#PORT, "VENDORSECRETSOURCE"), "%System/%Security/OAuth2", "all rows of the vendor's OAuth 2.0 security event")
}

/// <p>AC4, AD-35: a client's secrets write puts a probe registration access token into the vendor's
/// "Modify OAuth2 Client" and "Modify OAuth2 Client Metadata" rows; the audit screen's read and
/// <code>logs.audit.read</code> each answer both rows with the token masked.</p>
/// <p>Mutation (Rule 19): remove the <code>Modify OAuth2 Client</code> and <code>Modify OAuth2 Client
/// Metadata</code> declarations from <parameter>OcuPilot.Port.AuditPort.VENDORSECRETS</parameter> --
/// both reads carry the token and this goes red.</p>
Method TestAClientRowCarryingAProbeTokenReadsMasked()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "audit")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddServer", tIssuer, .tServerId), "a description is created")
    Set tName = $ClassMethod(..#PROBE, "Name", "Audit")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddClient", tName, tServerId), "and a client")
    Set tToken = $ClassMethod(..#PROBE, "Secret", "audittoken")
    Set tSince = $ZDateTime($Horolog, 3)
    Set tUtcSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Kill tQuery
    Set tQuery("applicationName") = tName
    ; A client secret beside the token modifies the client itself, so the vendor writes its client row
    ; as well as its metadata row, and both carry the token.
    Set tSC = ##class(OcuPilot.Port.OAuthClientPort).Invoke("Security.OAuth2.Client.ClientConfiguration", "CHANGESECRET", .tQuery, {"RegistrationAccessToken": (tToken), "ClientSecret": ($ClassMethod(..#PROBE, "Secret", "auditsecret"))}, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the secrets write stores the token")
    Do $$$AssertTrue(..VendorCarries(tUtcSince, tToken) >= 2, "and the vendor's own client and metadata rows carry it in plain text")
    Do ..AssertMasked(tSince, tName, tToken, "Modify OAuth2 Client ", "registration_access_token")
}

/// <p>AD-35: a server description's token write puts a probe initial access token into the vendor's
/// "Modify OAuth2 Server Definition" row; both reads answer it masked.</p>
/// <p>Mutation (Rule 19): remove the <code>Modify OAuth2 Server Definition</code> declaration -- both
/// reads carry the token and this goes red.</p>
Method TestAServerRowCarryingAProbeTokenReadsMasked()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "audittoken")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddServer", tIssuer, .tServerId), "a description is created")
    Set tToken = $ClassMethod(..#PROBE, "Secret", "auditinitial")
    Set tSince = $ZDateTime($Horolog, 3)
    Set tUtcSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Kill tQuery
    Set tQuery("issuer") = tIssuer
    Set tSC = ##class(OcuPilot.Port.OAuthServerPort).Invoke("Security.OAuth2.Client.ServerDefinition", "TOKEN", .tQuery, {"InitialAccessToken": (tToken)}, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the token write stores the token")
    Do $$$AssertTrue(..VendorCarries(tUtcSince, tToken) >= 1, "and the vendor's own row carries it in plain text")
    Do ..AssertMasked(tSince, tIssuer, tToken, "Modify OAuth2 Server Definition ", "InitialAccessToken")
}

/// <p>The mask reads the declaration and nothing else: a declared key is masked in each of the three
/// places the vendor writes one, on a Modify row and on a Create row; the same text under an event the
/// declaration does not name, under another vendor event, or under a key it does not declare is
/// unchanged.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AuditPort.MaskedEventData</method> stops masking a
/// <code>&lt;key&gt;:</code> property line -- the Create server definition assertion goes red.</p>
Method TestTheMaskReadsTheDeclarationAlone()
{
    Set tCrlf = $Char(13, 10)
    Set tData = "Modify OAuth2 Client: X" _ tCrlf _ "metadata.registration_access_token modified:" _ tCrlf _ "  New value: ocupilotmaskprobe000a" _ tCrlf _ "  Old value: ocupilotmaskprobe000b" _ tCrlf _ "metadata.client_id modified:" _ tCrlf _ "  New value: kept" _ tCrlf _ "Metadata:                               {""client_id"":""kept"",""registration_access_token"":""ocupilotmaskprobe000c""}"
    Set tRows = []
    Do tRows.%Push(..Row("%System", "%Security", "OAuth2", "Modify OAuth2 Client X", tData))
    Do tRows.%Push(..Row("%System", "%Security", "OAuth2", "Modify OAuth2 Server Client X", tData))
    Do tRows.%Push(..Row("%System", "%Security", "UserChange", "Modify OAuth2 Client X", tData))
    Do $ClassMethod(..#PORT, "MaskVendorSecrets", tRows)
    Set tMasked = tRows.%Get(0).%Get("EventData")
    Do $$$AssertEquals(tMasked [ "ocupilotmaskprobe000", 0, "a declared event's three places are masked")
    Do $$$AssertTrue((tMasked [ "  New value: *****") && (tMasked [ "  Old value: *****") && (tMasked [ """registration_access_token"":""*****"""), "each with the vendor's own mask")
    Do $$$AssertTrue((tMasked [ "  New value: kept") && (tMasked [ """client_id"":""kept"""), "and an undeclared key beside them is unchanged")
    Do $$$AssertEquals(tRows.%Get(1).%Get("EventData"), tData, "an event the declaration does not name is unchanged")
    Do $$$AssertEquals(tRows.%Get(2).%Get("EventData"), tData, "and so is another vendor event")

    ; A Create row lists every property on its own line, as the vendor writes one (read on a throwaway).
    Set tCreate = "Create OAuth2 Server Definition: X" _ tCrlf _ tCrlf _ "InitialAccessToken:                     ocupilotmaskprobe000d" _ tCrlf _ "IssuerEndpoint:                         https://ocupilotprobe125.invalid/x" _ tCrlf _ "Metadata:                               {""registration_access_token"":""ocupilotmaskprobe000e""}"
    Set tClient = "Create OAuth2 Client: Y" _ tCrlf _ tCrlf _ "Metadata:                               {""client_name"":""kept"",""registration_access_token"":""ocupilotmaskprobe000f""}"
    Set tRows = []
    Do tRows.%Push(..Row("%System", "%Security", "OAuth2", "Create OAuth2 Server Definition X", tCreate))
    Do tRows.%Push(..Row("%System", "%Security", "OAuth2", "Create OAuth2 Client Y", tClient))
    Do $ClassMethod(..#PORT, "MaskVendorSecrets", tRows)
    Set tMasked = tRows.%Get(0).%Get("EventData")
    Do $$$AssertTrue((tMasked '[ "ocupilotmaskprobe000") && (tMasked [ "InitialAccessToken:                     *****") && (tMasked [ "IssuerEndpoint:                         https://ocupilotprobe125.invalid/x"), "a Create server definition row's property line and metadata are masked, and nothing else: " _ tMasked)
    Set tMasked = tRows.%Get(1).%Get("EventData")
    Do $$$AssertTrue((tMasked '[ "ocupilotmaskprobe000") && (tMasked [ """client_name"":""kept"""), "and so is a Create client row's metadata: " _ tMasked)
}

/// <p>Assert that the audit screen's read over the wire and <code>logs.audit.read</code> each answer
/// a row since <var>pSince</var> naming <var>pName</var> under <var>pPrefix</var> whose
/// <var>pKey</var> reads the mask, and that no answered row carries <var>pToken</var>.</p>
Method AssertMasked(pSince As %String, pName As %String, pToken As %String, pPrefix As %String, pKey As %String)
{
    ; The vendor writes its rows before the call returns; the audit read queues its own task.
    Set tPath = ..#READPATH _ "?events=OAuth2&maxRows=200&beginDateTime=" _ $ZConvert(pSince, "O", "URL")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the audit screen's read answers: " _ $Extract(tRaw, 1, 200))
    Set tScreen = ""
    Try { Set tScreen = ##class(%DynamicObject).%FromJSON(tRaw).%Get("rows") } Catch { Set tScreen = "" }
    Do $$$AssertTrue(..Named($Get(tScreen), pName, pPrefix), "the screen's read answers the row naming " _ pName)
    Do $$$AssertEquals(tRaw [ pToken, 0, "and carries no token")
    Do $$$AssertTrue(..MaskedRows($Get(tScreen), pName, pPrefix, pKey) > 0, "where the token was, " _ pKey _ " reads the mask")

    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#TOOLNAME, .tTool)
    Do $$$AssertStatusOK(tSC, "the read tool resolves")
    Set tArgs = {"events": "OAuth2", "maxRows": 200}
    Do tArgs.%Set("beginDateTime", pSince, "string")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, tArgs, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "logs.audit.read answers")
    Set tText = $Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "")
    Do $$$AssertTrue(..Named($Select($IsObject($Get(tResult)): tResult.%Get("rows"), 1: ""), pName, pPrefix), "logs.audit.read answers the row naming " _ pName)
    Do $$$AssertEquals(tText [ pToken, 0, "and carries no token")
    Do $$$AssertTrue(..MaskedRows($Select($IsObject($Get(tResult)): tResult.%Get("rows"), 1: ""), pName, pPrefix, pKey) > 0, "where the token was, " _ pKey _ " reads the mask")
}

/// <p>How many rows of <var>pRows</var> whose <code>Description</code> begins <var>pPrefix</var> and
/// names <var>pName</var> carry the mask as <var>pKey</var>'s value in their <code>EventData</code>, in
/// any of the three places the vendor writes one: a <code>New value</code> line under a
/// <code>&lt;key&gt; modified:</code> or <code>metadata.&lt;key&gt; modified:</code> line, a
/// <code>&lt;key&gt;:</code> property line, or the member in a <code>Metadata:</code> line's JSON.</p>
ClassMethod MaskedRows(pRows, pName As %String, pPrefix As %String, pKey As %String) As %Integer
{
    If '$IsObject(pRows) Quit 0
    Set tMask = $Parameter(..#PORT, "MASK")
    Set tCount = 0
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tDescription = tRow.%Get("Description")
        If ($Extract(tDescription, 1, $Length(pPrefix)) '= pPrefix) || '(tDescription [ pName) Continue
        Set tData = tRow.%Get("EventData")
        Set tMasked = (tData [ ("""" _ pKey _ """:""" _ tMask _ """"))
        Set tBlock = 0
        For tI = 1:1:$Length(tData, $Char(10)) {
            Set tLine = $ZStrip($Piece(tData, $Char(10), tI), "<>WC")
            If tBlock && ($Extract(tLine, 1, 10) = "New value:") && ($ZStrip($Extract(tLine, 11, *), "<>W") = tMask) Set tMasked = 1
            If ($Extract(tLine, 1, $Length(pKey) + 1) = (pKey _ ":")) && ($ZStrip($Extract(tLine, $Length(pKey) + 2, *), "<>W") = tMask) Set tMasked = 1
            Set tBlock = (tLine = (pKey _ " modified:")) || (tLine = ("metadata." _ pKey _ " modified:"))
        }
        If tMasked Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>Whether <var>pRows</var> holds a row whose <code>Description</code> begins <var>pPrefix</var> and
/// names <var>pName</var>.</p>
ClassMethod Named(pRows, pName As %String, pPrefix As %String) As %Boolean
{
    If '$IsObject(pRows) Quit 0
    Set tFound = 0
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tDescription = tRow.%Get("Description")
        If ($Extract(tDescription, 1, $Length(pPrefix)) = pPrefix) && (tDescription [ pName) Set tFound = 1
    }
    Quit tFound
}

/// <p>How many of the vendor's own OAuth 2.0 rows since <var>pSince</var> (UTC) carry <var>pToken</var>
/// in their event data, read from the audit database directly.</p>
ClassMethod VendorCarries(pSince As %String, pToken As %String) As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT EventData FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = '%System' AND %NOINDEX EventType = '%Security' AND %NOINDEX Event = 'OAuth2'", pSince)
        While tRS.%Next() {
            If tRS.%Get("EventData") [ pToken Set tCount = tCount + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>One audit row as the read answers it.</p>
ClassMethod Row(pSource As %String, pType As %String, pEvent As %String, pDescription As %String, pData As %String) As %DynamicObject
{
    Set tRow = {}
    Do tRow.%Set("EventSource", pSource, "string")
    Do tRow.%Set("EventType", pType, "string")
    Do tRow.%Set("Event", pEvent, "string")
    Do tRow.%Set("Description", pDescription, "string")
    Do tRow.%Set("EventData", pData, "string")
    Quit tRow
}

}
