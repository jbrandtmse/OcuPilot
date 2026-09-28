/// <p>Pins AD-35's mask composed with AD-60: a real vendor audit row already masked
/// to <class>OcuPilot.Port.AuditPort</class>'s own <code>*****</code> reaches the model
/// through a real turn's <code>logs.audit.read</code> call with that one mask intact -- neither
/// unmasked nor mangled a second time by <class>OcuPilot.Kernel.Agent.Sanitize</class>, whose own
/// unit legs (<class>OcuPilot.Test.Sanitize</class>) pin the same fact on a literal
/// <code>*****</code>, never on a value the vendor's own masking wrote.</p>
/// <p><b>It creates an IRIS user and a role, a probe OAuth 2.0 server description and turn jobs, so
/// <method>OnBeforeAllTests</method> refuses to run unless both</b>
/// <parameter>ARMINGVARIABLE</parameter> <b>and</b> <parameter>PROVIDERVARIABLE</parameter>
/// <b>read 1.</b> Only <file>scripts/ci-throwaway.sh</file> sets them. The principal's second role
/// carries the audit screen's own privilege pairs, so its turn can call the real
/// <code>logs.audit.read</code> tool.</p>
Class OcuPilot.Test.SanitizeAuditMask Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "sanitizeauditmask-probe";

/// <p>The pairs <code>logs/audit</code> declares beyond the shared fixture's own set, so this
/// class's principal can call the real <code>logs.audit.read</code> tool.</p>
Parameter AUDITRESOURCES = "%Admin_Secure:U,%DB_IRISSYS:R";

Property PreparedPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedDefinitionId = ""
    Set ..PreparedPrior = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SanitizeAuditMask creates an IRIS user and a role, an OAuth 2.0 server description and turn jobs, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SanitizeAuditMask runs turn jobs against the turnprobe provider row, on a throwaway container only. " _ ..#PROVIDERVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"), ..#AUDITRESOURCES)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = tId
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = ##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SanitizeAuditMask teardown left:" _ tLeft)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Do ##class(OcuPilot.Test.OAuthClientProbe).RemoveAll(.tRemaining)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.OAuthClientProbe).RemoveAll(.tRemaining), "the probe server description is removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>Start a turn as the probe principal; the turn id when it answered 202.</p>
Method Start(pMessage As %String, Output pStatus As %Integer, Output pText As %String) As %String
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedPassword, .tConvStatus, .tConvText)
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "StartBody", pMessage, tConvId), .pStatus, .pText, .tHeaders)
    If pStatus '= 202 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(pText).turnId
}

/// <p>A vendor row masked by <method>OcuPilot.Port.AuditPort.MaskVendorSecrets</method> (AD-35),
/// already proven masked over the wire and through the tool by
/// <class>OcuPilot.Test.AuditVendorSecrets</class>: a probe OAuth 2.0 server description's initial
/// access token write puts the token into the vendor's own "Modify OAuth2 Server Definition" row,
/// which the read masks before this test ever calls the model. Answers the issuer, the raw token
/// (never expected over the wire) and the UTC timestamp the turn's own read is narrowed to.</p>
Method SeedMaskedRow(Output pIssuer As %String, Output pToken As %String, Output pSince As %String) As %Status
{
    Set pIssuer = ##class(OcuPilot.Test.OAuthClientProbe).Issuer("sanitizemask")
    Set tSC = ##class(OcuPilot.Test.OAuthClientProbe).AddServer(pIssuer, .tServerId)
    If $$$ISERR(tSC) Quit tSC
    Set pToken = ##class(OcuPilot.Test.OAuthClientProbe).Secret("sanitizemasktoken")
    Set pSince = $ZDateTime($ZTimeStamp, 3, 1, 3)
    Kill tQuery
    Set tQuery("issuer") = pIssuer
    Quit ##class(OcuPilot.Port.OAuthServerPort).Invoke("Security.OAuth2.Client.ServerDefinition", "TOKEN", .tQuery, {"InitialAccessToken": (pToken)}, .tResult, .tHttp, .tFault)
}

/// <p>Integration: a real masked vendor secret reaches the model exactly as masked. The turn's
/// model calls <code>logs_audit_read</code>, narrowed to this row's own event and window; the
/// recorded <code>tool_result</code> arrives framed (Story 14.3's one seam), the row is found, its
/// <code>EventData</code> carries the vendor's own <code>*****</code> mask and never the raw
/// token, and the sanitizer's own redaction mark
/// (<code>OcuPilot.Kernel.Audit.Log.#REDACTED</code>) appears nowhere in it -- the mask
/// is not mangled a second time.</p>
/// <p>Mutation: add a sixth shape matching runs of <code>*</code> to
/// <method>OcuPilot.Kernel.Agent.Sanitize.Matchers</method> and <method>Redact</method> -- this goes
/// red on the mask assertion and the once-not-twice assertion.</p>
Method TestARealMaskedVendorSecretReachesTheModelOnceMasked()
{
    Set tSC = ..SeedMaskedRow(.tIssuer, .tToken, .tSince)
    Do $$$AssertStatusOK(tSC, "the token write stores the token")
    If $$$ISERR(tSC) Quit

    Set tCalls = [{"name": "logs_audit_read", "input": {"events": "OAuth2", "beginDateTime": (tSince), "maxRows": 200}}]
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tCalls))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    Set tTurnId = ..Start("read the audit log", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted: " _ tText)
    If tTurnId = "" Quit
    Set tState = $ClassMethod(..#FIXTURE, "AwaitEnd", tTurnId, $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, 30, .tView)
    Do $$$AssertEquals(tState, "completed", "the turn completes: " _ $Select($IsObject($Get(tView)): tView.%ToJSON(), 1: ""))
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 2, 10), "call 2 lands")

    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "messages"))
    Set tResultBlock = tMessages.%Get(tMessages.%Size() - 1).content.%Get(0)
    Do $$$AssertEquals(tResultBlock."is_error", 0, "the read tool answers, not an error: " _ tResultBlock.content)

    Set tBody = ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tResultBlock.content, .tWrapped)
    Do $$$AssertTrue(tWrapped, "the tool_result arrives framed as data: " _ $Extract(tResultBlock.content, 1, 80))
    If 'tWrapped Quit
    Set tContent = ##class(%DynamicAbstractObject).%FromJSON(tBody)

    Set tRedactedMark = ##class(OcuPilot.Kernel.Audit.Log).#REDACTED
    Set tFoundRow = 0
    Set tIterator = tContent.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tData = tRow.%Get("EventData")
        If (tData = "") || (tData '[ tIssuer) Continue
        Set tFoundRow = 1
        Do $$$AssertEquals(tData [ tToken, 0, "the raw token never reaches the model: " _ $Extract(tData, 1, 200))
        Do $$$AssertTrue(tData [ "*****", "the vendor's own mask is present: " _ $Extract(tData, 1, 200))
        Do $$$AssertEquals($Length(tData, tRedactedMark), 1, "and the sanitizer's own mark is nowhere in it -- masked once, not twice")
    }
    Do $$$AssertTrue(tFoundRow, "this test's own masked row is in the result: " _ tContent.%ToJSON())
}

}
