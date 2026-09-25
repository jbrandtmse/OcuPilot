/// <p>Pins AD-42's rule that <b>a write is never retried mid-flight</b>: whether the port raises,
/// answers no HTTP status, or answers 503, the confirm path and a screen action each reach the port
/// exactly once for one write, and a confirmed proposal whose write failed stays burned, so a second
/// confirm is refused rather than re-sent. The one retry AD-42 permits is a model call's, and it
/// never reaches this path.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot's protected state and an account holding
/// <code>%All</code>. Every port call is <class>OcuPilot.Test.ProposalFixture</class>'s, so <b>no
/// write reaches the instance</b>; the rows a test mints name the running account and are removed in
/// <method>OnAfterOneTest</method>.</p>
Class OcuPilot.Test.WriteNeverRetried Extends %UnitTest.TestCase
{

Parameter SCREEN = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter TOOL = "webapp.list.update";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The target the fixture answers for. Nothing on the instance carries this path, and nothing
/// here would reach it if it did: the port is the fixture.</p>
Parameter TARGET = "/csp/ocupilotprobeneverretried";

/// <p>The fresh read every confirm leg starts from.</p>
Parameter FRESH = "{""Name"":""/csp/ocupilotprobeneverretried"",""Description"":""before"",""Enabled"":true}";

/// <p>The screen whose list Delete drives the screen-action leg.</p>
Parameter X509LIST = "OcuPilot.Screen.Descriptor.X509CredentialList";

/// <p>The alias the screen-action leg deletes; the fixture answers for it, so nothing is
/// deleted.</p>
Parameter X509PROBE = "OcuPilotProbeNeverRetried";

/// <p>The certificate read the screen-action leg's fresh read answers.</p>
Parameter X509INFO = "{""HasPrivateKey"":true,""SerialNumber"":""11"",""IssuerDN"":""CN=Issuer"",""SubjectDN"":""CN=Probe"",""ValidityNotBefore"":""2026-01-01 00:00:00"",""ValidityNotAfter"":""2126-01-01 00:00:00""}";

/// <p>The three failures a write can meet, as <code>kind:status</code>: a raise, an error with no
/// HTTP status, and a 503.</p>
Parameter FAILURES = "raise:0,nohttp:0,fault:503";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>Mint one live proposal on a completed turn for the running account, and answer its id.</p>
Method Seed() As %String
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tArgs = {}
    Do tArgs.%Set("Name", ..#TARGET, "string")
    Do tArgs.%Set("Description", "after", "string")
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, ..#TOOL, $Username, "", tTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", ..#TARGET, "Name", ##class(OcuPilot.Screen.Tool.WebAppUpdate).SettableFields())
    Do $$$AssertStatusOK(tSC, "the probe proposal mints")
    If $$$ISERR(tSC) Quit ""
    Quit tProposal.%Get("proposalId")
}

/// <p>Arm the fixture's next write to fail as <var>pKind</var> -- <code>raise</code>,
/// <code>nohttp</code> or <code>fault</code> -- with <var>pStatus</var>.</p>
ClassMethod ArmFailure(pKind As %String, pStatus As %Integer)
{
    If pKind = "raise" {
        Do ##class(OcuPilot.Test.ProposalFixture).ArmWriteException()
        Quit
    }
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWriteFault(pStatus)
}

/// <p>The confirm path: each failure reaches the port once, the proposal stays confirmed and
/// burned, and a second confirm is refused as already decided without reaching the port
/// again.</p>
/// <p>Mutation: in <method>OcuPilot.Kernel.Proposal.Operation.ApplyAt</method>, invoke the port a
/// second time when the first call errors or raises -- every leg goes red at a write count of 2.</p>
Method TestAFailedConfirmedWriteIsSentOnce()
{
    For tI = 1:1:$Length(..#FAILURES, ",") {
        Set tLeg = $Piece(..#FAILURES, ",", tI)
        Set tKind = $Piece(tLeg, ":", 1)
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Set tKey = ..Seed()
        If tKey = "" Quit
        Do ..ArmFailure(tKind, $Piece(tLeg, ":", 2))
        Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        Do $$$AssertStatusNotOK(tSC, tLeg _ ": the confirm reports the failed write")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, tLeg _ ": the port received the write exactly once")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 1, tLeg _ ": the token is spent")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "confirmed", tLeg _ ": and the row stays confirmed")

        Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, "", $Username, .tAgainResult, .tAgainHttp, .tAgainCode, .tAgainDetail)
        Do $$$AssertStatusNotOK(tSC, tLeg _ ": a second confirm is refused")
        Do $$$AssertEquals(tAgainCode, ##class(OcuPilot.Kernel.Proposal.Write).#BURNED, tLeg _ ": as already decided")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, tLeg _ ": and the write is not sent again")
    }
}

/// <p>The screen path (AD-53): a list's Delete whose write fails reaches the port once for each
/// failure, through the same operation the confirm uses.</p>
/// <p>Mutation: the same re-invoke in <method>OcuPilot.Kernel.Proposal.Operation.ApplyAt</method>
/// -- every leg goes red at a write count of 2.</p>
Method TestAFailedScreenActionIsSentOnce()
{
    Set tScreen = $ClassMethod(..#X509LIST, "ToolIdentifier")
    For tI = 1:1:$Length(..#FAILURES, ",") {
        Set tLeg = $Piece(..#FAILURES, ",", tI)
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#X509INFO)
        Do ..ArmFailure($Piece(tLeg, ":", 1), $Piece(tLeg, ":", 2))
        Do ##class(OcuPilot.Test.SslActionFixture).Act(tScreen, {"action": "delete", "id": (..#X509PROBE)}, .tAnswer, .tStatus)
        Do $$$AssertNotEquals(tStatus, 200, tLeg _ ": and does not answer success: " _ $Get(tAnswer))
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "DELETE", tLeg _ ": the write reached the port")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, tLeg _ ": exactly once")
    }
}

}
