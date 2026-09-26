/// <p>Pins AD-35's mask of the resource server authenticator settings IRIS writes into its own audit
/// rows (Story 12.6): real vendor "Create Resource Server" and "Modify Resource Server" rows carrying a
/// probe authenticator's <code>ApiKey</code> read masked through the Logs audit screen's read over the
/// wire and through <code>logs.audit.read</code>, with the ordinary <code>Claim</code> unchanged, while
/// the audit database itself still holds the value; and the mask reads its declaration alone.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving with the demo fixture,
/// its test classes compiled in this namespace and auditing on, an account holding <code>%All</code>,
/// and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes
/// OAuth 2.0 resource servers and server descriptions. The rows it writes stay in the audit database,
/// which it neither copies nor purges.</p>
Class OcuPilot.Test.OAuthResourceServerAuditMask Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PORT = "OcuPilot.Port.AuditPort";

Parameter READPATH = "/screens/logs.audit/read";

Parameter TOOLNAME = "logs.audit.read";

Parameter PROBE = "OcuPilot.Test.OAuthResourceServerProbe";

/// <p>The vendor event the resource server rows are written under.</p>
Parameter EVENT = "OAuth2ResourceServerChange";

/// <p>The credential setting of <class>OcuPilot.Test.OAuthProbeAuthenticator</class>, and its ordinary
/// one.</p>
Parameter KEYSETTING = "ApiKey";

Parameter CLAIMSETTING = "Claim";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.OAuthResourceServerAuditMask creates and deletes OAuth 2.0 resource servers on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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

/// <p>The declaration names the two vendor events measured on a throwaway, each with the property
/// that carries the authenticator, and the vendor event they are rows of.</p>
Method TestTheDeclarationNamesTheMeasuredEvents()
{
    Do $$$AssertEquals($Parameter(..#PORT, "VENDORSETTINGSECRETS"), "Create Resource Server=Authenticator;Modify Resource Server=Authenticator", "the Create and Modify Resource Server rows declare the authenticator, and nothing else")
    Do $$$AssertEquals($Parameter(..#PORT, "VENDORSETTINGSOURCE"), "%System/%Security/" _ ..#EVENT, "both rows of the vendor's resource server event")
}

/// <p>AD-35: a server made with the probe authenticator puts its <code>ApiKey</code> into the vendor's
/// Create row, and a port <code>PUT</code> changing only <code>Claim</code> puts it into the Modify row
/// three times (the new value, the old value and the property line), because the port fills the
/// omitted key from the stored one. The audit screen's read and <code>logs.audit.read</code> each answer
/// both rows with every occurrence masked and <code>Claim</code> as written.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Port.AuditPort.VENDORSETTINGSECRETS</parameter> --
/// both reads carry the key and this goes red.</p>
Method TestARowCarryingAProbeKeyReadsMasked()
{
    Set tIssuer = $ClassMethod(..#PROBE, "Issuer", "auditmask")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddServer", tIssuer), "a description is created")
    Set tName = $ClassMethod(..#PROBE, "Name", "AuditMask")
    Set tKey = $ClassMethod(..#PROBE, "Secret", "auditmaskkey")
    Set tSince = $ZDateTime($Horolog, 3)
    Set tUtcSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tAuthenticator = ..Authenticator("sub")
    Do tAuthenticator.%Set(..#KEYSETTING, tKey, "string")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddResource", tName, tIssuer, $ListBuild("aud.auditmask"), {"Authenticator": (tAuthenticator)}), "a server with the probe authenticator is created")
    Kill tQuery
    Set tQuery("name") = tName
    Set tBody = {}
    Do tBody.%Set("Authenticator", ..Authenticator("email"))
    Set tSC = ##class(OcuPilot.Port.OAuthResourceServerPort).Invoke("Security.OAuth2.ResourceServer", "PUT", .tQuery, tBody, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a PUT changing Claim alone is stored")
    Do $$$AssertTrue(..VendorCarries(tUtcSince, tKey) >= 2, "and the vendor's own Create and Modify rows carry the key in plain text")
    Do ..AssertMasked(tSince, tName, tKey)
}

/// <p>The mask reads the declaration and nothing else: a declared event's credential setting is masked
/// on its property line and in its <code>modified</code> block, and its other members are unchanged;
/// the same text under an event the declaration does not name, or under another vendor event, is
/// unchanged; an empty key stays empty; and a property line whose JSON does not parse is masked
/// whole.</p>
Method TestTheMaskReadsTheDeclarationAlone()
{
    Set tCrlf = $Char(13, 10)
    Set tJson = "{""Implementation"":""OcuPilot.Test.OAuthProbeAuthenticator"",""Namespace"":""HSCUSTOM"",""ApiKey"":""ocupilotmaskprobe000"",""Claim"":""sub""}"
    Set tData = "Modify Resource Server: X" _ tCrlf _ tCrlf _ "Authenticator modified:" _ tCrlf _ "  New value: " _ tJson _ tCrlf _ "  Old value: " _ tJson _ tCrlf _ tCrlf _ "Audiences:                    ocupilotmaskprobe000" _ tCrlf _ "Authenticator:                " _ tJson
    Set tRows = []
    Do tRows.%Push(..Row(..#EVENT, "Modify Resource Server X", tData))
    Do tRows.%Push(..Row(..#EVENT, "Delete Resource Server X", tData))
    Do tRows.%Push(..Row("OAuth2", "Modify Resource Server X", tData))
    Do $ClassMethod(..#PORT, "MaskVendorSecrets", tRows)
    Set tMasked = tRows.%Get(0).%Get("EventData")
    Set tMaskedKey = """" _ ..#KEYSETTING _ """:""" _ $Parameter(..#PORT, "MASK") _ """"
    Do $$$AssertEquals($Length(tMasked, tMaskedKey) - 1, 3, "a declared event's key reads the mask in its new value, its old value and its property line: " _ tMasked)
    Do $$$AssertTrue((tMasked [ """Claim"":""sub""") && (tMasked [ """Namespace"":""HSCUSTOM""") && (tMasked [ "Audiences:                    ocupilotmaskprobe000"), "and every other member and property line is unchanged")
    Do $$$AssertEquals(tRows.%Get(1).%Get("EventData"), tData, "an event the declaration does not name is unchanged")
    Do $$$AssertEquals(tRows.%Get(2).%Get("EventData"), tData, "and so is another vendor event")

    Set tRows = []
    Do tRows.%Push(..Row(..#EVENT, "Create Resource Server Y", "Create Resource Server: Y" _ tCrlf _ "Authenticator:                {""Implementation"":""OcuPilot.Test.OAuthProbeAuthenticator"",""ApiKey"":"""",""Claim"":""sub""}"))
    Do tRows.%Push(..Row(..#EVENT, "Create Resource Server Z", "Create Resource Server: Z" _ tCrlf _ "Authenticator:                {""ApiKey"":""ocupilotmaskprobe000"""))
    Do $ClassMethod(..#PORT, "MaskVendorSecrets", tRows)
    Do $$$AssertTrue(tRows.%Get(0).%Get("EventData") [ """ApiKey"":""""", "an empty key stays empty")
    Do $$$AssertEquals(tRows.%Get(1).%Get("EventData"), "Create Resource Server: Z" _ tCrlf _ "Authenticator:                " _ $Parameter(..#PORT, "MASK"), "and a line whose JSON does not parse is masked whole")
}

/// <p>Assert that the audit screen's read over the wire and <code>logs.audit.read</code> each answer
/// the Create and Modify rows naming <var>pName</var> since <var>pSince</var> with <var>pKey</var>'s
/// setting masked everywhere the vendor wrote it, and that no answered row carries <var>pKey</var>.</p>
Method AssertMasked(pSince As %String, pName As %String, pKey As %String)
{
    Set tPath = ..#READPATH _ "?events=" _ ..#EVENT _ "&maxRows=200&beginDateTime=" _ $ZConvert(pSince, "O", "URL")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the audit screen's read answers: " _ $Extract(tRaw, 1, 200))
    Set tScreen = ""
    Try { Set tScreen = ##class(%DynamicObject).%FromJSON(tRaw).%Get("rows") } Catch { Set tScreen = "" }
    Do $$$AssertEquals(tRaw [ pKey, 0, "the screen's read carries no key")
    Do $$$AssertEquals(..MaskedCounts($Get(tScreen), pName), "1 3", "and answers the Create row's key and the Modify row's three masked, Claim as written")

    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#TOOLNAME, .tTool)
    Do $$$AssertStatusOK(tSC, "the read tool resolves")
    Set tArgs = {"events": (..#EVENT), "maxRows": 200}
    Do tArgs.%Set("beginDateTime", pSince, "string")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, tArgs, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "logs.audit.read answers")
    Set tText = $Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "")
    Do $$$AssertEquals(tText [ pKey, 0, "logs.audit.read carries no key")
    Do $$$AssertEquals(..MaskedCounts($Select($IsObject($Get(tResult)): tResult.%Get("rows"), 1: ""), pName), "1 3", "and answers the Create row's key and the Modify row's three masked, Claim as written")
}

/// <p>For the rows of <var>pRows</var> naming <var>pName</var>, how many times the probe key reads the
/// mask in the Create row and in the Modify row, as <code>&lt;create&gt; &lt;modify&gt;</code>; a row
/// whose <code>Claim</code> is not as written counts 0.</p>
ClassMethod MaskedCounts(pRows, pName As %String) As %String
{
    Set (tCreate, tModify) = 0
    If '$IsObject(pRows) Quit "0 0"
    Set tMasked = """" _ ..#KEYSETTING _ """:""" _ $Parameter(..#PORT, "MASK") _ """"
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tDescription = tRow.%Get("Description")
        Set tData = tRow.%Get("EventData")
        Set tCount = $Length(tData, tMasked) - 1
        If tDescription = ("Create Resource Server " _ pName) Set tCreate = $Select(tData [ """Claim"":""sub""": tCount, 1: 0)
        If tDescription = ("Modify Resource Server " _ pName) Set tModify = $Select(tData [ """Claim"":""email""": tCount, 1: 0)
    }
    Quit tCreate _ " " _ tModify
}

/// <p>How many of the vendor's own resource server rows since <var>pSince</var> (UTC) carry
/// <var>pKey</var> in their event data, read from the audit database directly.</p>
ClassMethod VendorCarries(pSince As %String, pKey As %String) As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT EventData FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = '%System' AND %NOINDEX EventType = '%Security' AND %NOINDEX Event = ?", pSince, ..#EVENT)
        While tRS.%Next() {
            If tRS.%Get("EventData") [ pKey Set tCount = tCount + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>The probe authenticator in the probe namespace with claim <var>pClaim</var> and no key.</p>
ClassMethod Authenticator(pClaim As %String) As %DynamicObject
{
    Set tAuthenticator = {}
    Do tAuthenticator.%Set("Implementation", $Parameter(..#PROBE, "AUTHENTICATOR"), "string")
    Do tAuthenticator.%Set("Namespace", $ClassMethod(..#PROBE, "Namespace"), "string")
    Do tAuthenticator.%Set(..#CLAIMSETTING, pClaim, "string")
    Quit tAuthenticator
}

/// <p>One vendor security row of event <var>pEvent</var> as the read answers it.</p>
ClassMethod Row(pEvent As %String, pDescription As %String, pData As %String) As %DynamicObject
{
    Quit ##class(OcuPilot.Test.AuditVendorSecrets).Row("%System", "%Security", pEvent, pDescription, pData)
}

}
