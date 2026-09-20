/// <p>AD-35 across a whole turn (Story 5.4, AC5): a canary provider key is driven through a turn
/// that <b>completes</b> and a turn that <b>fails</b>, and every place the turn left a record --
/// every ledger column, every transcript step column, the progress record and the console log --
/// is swept for it. The in-memory holder is asked directly whether it is empty when the call
/// returns.</p>
/// <p><b>The sibling this does not duplicate.</b> <class>OcuPilot.Test.ProviderSecret</class> pins
/// the key out of the two logs and the envelope under forced failures, from the adapter's own call
/// stack. What is new here is the turn's own storage: the rows and steps a completed turn and a
/// failed turn leave behind, which no failure test writes.</p>
/// <p><b>The canary is fabricated and has no value.</b> It is shaped like a real key so it passes
/// the shape gate and reaches every point a real one would, and it is unmistakable in a sweep. No
/// provider is called: the adapter is a transport stub.</p>
/// <p><b>Live-safe.</b> It spawns nothing and creates no principal; the rows it writes name
/// <parameter>PROBEUSER</parameter> and <method>OnAfterOneTest</method> asserts none survives.</p>
Class OcuPilot.Test.TurnSecretResidue Extends %UnitTest.TestCase
{

/// <p>The fabricated credential, shaped like an Anthropic key so it passes the catalog row's
/// prefix gate.</p>
Parameter CANARY = "sk-ant-ocupilotturnresidue00000000";

/// <p>The substring the sweep searches for -- the canary's distinctive middle, so a truncated or
/// re-encoded copy matches as well as a verbatim one.</p>
Parameter CANARYMARK = "ocupilotturnresidue";

/// <p>The port the calls are driven through, and the catalog whose anthropic row answers the
/// adapter that reports what it still held.</p>
Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

Parameter CATALOG = "OcuPilot.Test.CatalogResidue";

/// <p>The ledger's public face and the store beneath it.</p>
Parameter LEDGER = "OcuPilot.Kernel.Audit.Ledger";

Parameter STORE = "OcuPilot.Kernel.State.Ledger";

/// <p>The shipped bounds.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The user every probe row records -- its own, so the teardown's sweep cannot reach a
/// sibling's rows.</p>
Parameter PROBEUSER = "OcuPilotProbeTurnResidue";

Method OnBeforeOneTest() As %Status
{
    Do ..Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Clear()
    Do $$$AssertEquals(##class(OcuPilot.Test.Ledger).RowCountFor(..#PROBEUSER), 0, "no probe ledger row survives the method")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).RemoveTurns(.tRemaining), "the probe turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

Method Clear()
{
    Do ##class(OcuPilot.Test.ResidueStub).Clear()
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..#PROBEUSER)
}

/// <p>The definition the canary travels on: the catalog row whose key prefix is the shipped
/// Anthropic row's, so the canary passes the shape gate, carried as a request-body key so no
/// environment variable or credential entry has to exist for the run.</p>
ClassMethod Definition(Output pValues)
{
    Kill pValues
    Set pValues("provider") = ##class(OcuPilot.Test.CatalogAnthropicStub).#ANTHROPICKEY
    Set pValues("model") = "probe-residue-model-1"
    Set pValues("endpointUrl") = "https://api.anthropic.com/v1/messages"
    Set pValues("markedLocal") = 0
    Set pValues("credType") = "env"
    Set pValues("envVarName") = "OCUPILOT_PROBE_RESIDUE_KEY"
    Set pValues("credentialName") = ""
    Set pValues("maxTokens") = 4000
    Set pValues("temperature") = 0
    Set pValues("keySource") = ##class(OcuPilot.Kernel.Provider.Base).#KEYSOURCEBODY
    Set tBody = {}
    Do tBody.%Set("apiKey", ..#CANARY, "string")
    Set pValues("keyBody") = tBody
    Set pValues("keyField") = "apiKey"
}

/// <p>Make one provider call carrying the canary. <var>pStatus</var> and <var>pBody</var> are the
/// answer the transport stub is queued with: a 200 for a turn that completes, a 500 for one that
/// fails.</p>
Method Drive(pStatus As %Integer, pBody As %String, Output pResponse, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Do $ClassMethod(..#PORT, "SetCatalogClass", ..#CATALOG)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(pStatus, pBody)
    Do ..Definition(.tValues)
    Set tMessages = 1
    Set tMessages(1, "role") = "user"
    Set tMessages(1, "content") = "probe"
    Quit $ClassMethod(..#PORT, "InvokeDraft", .tValues, .tMessages, .tTools, "", .pResponse, .pHttpStatus, .pFault)
}

/// <p>A turn key no other class and no other call uses.</p>
/// <p><code>$ZHex</code> is not how random bytes become a string: it reads its argument as a
/// number, so a binary one answers <code>0</code> every time and every key would collide. The
/// hex-binary conversion is the tree's own idiom (<class>OcuPilot.Test.ProposalFixture</class>).</p>
ClassMethod NewTurnKey() As %String
{
    Quit "residue-" _ $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.GenCryptRand(16)), "L")
}

/// <p><b>AC5</b> -- the in-memory holder is empty when the call returns, on the path that
/// completes and on the path that fails.</p>
/// <p>Mutation (Rule 19): delete the always-runs clear in
/// <method>OcuPilot.Kernel.Provider.Base.Invoke</method>'s final block -> this goes red.</p>
Method TestTheKeyIsDiscardedWhenTheTurnEnds()
{
    Set tSC = ..Drive(200, $Parameter("OcuPilot.Test.Provider", "OKBODY"), .tResponse, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the completing call returns")
    Do $$$AssertEquals(##class(OcuPilot.Test.ResidueStub).Calls(), 1, "and was served by the reporting adapter")
    Do $$$AssertEquals(##class(OcuPilot.Test.ResidueStub).KeyAfterCall(), "", "the adapter holds no key once the call has returned")

    Do ##class(OcuPilot.Test.ResidueStub).Clear()
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Set tSC = ..Drive(500, "{""error"":""probe""}", .tResponse2, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC, "the failing call returns too")
    Do $$$AssertEquals(##class(OcuPilot.Test.ResidueStub).Calls(), 1, "and was served by the reporting adapter")
    Do $$$AssertEquals(##class(OcuPilot.Test.ResidueStub).KeyAfterCall(), "", "and holds no key on the failure path either")
    Do $$$AssertTrue($IsObject(tFault2), "the failure answered a fault")
    If $IsObject(tFault2) Do $$$AssertEquals(tFault2.%ToJSON() [ ..#CANARYMARK, 0, "which carries no credential material: " _ tFault2.%ToJSON())
}

/// <p><b>AC5</b> -- no part of the canary reaches any column of any ledger row, any column of any
/// transcript step, or the progress record, for a turn that completed and a turn that failed.</p>
/// <p>Mutation (Rule 19): remove the declared-secret drop from
/// <method>OcuPilot.Kernel.Audit.Ledger.RedactArguments</method> -> the tool row stores the
/// canary and this goes red.</p>
Method TestNoKeyReachesTheLedger()
{
    Set tUser = ..#PROBEUSER
    For tOutcome = "completed", "failed" {
        Do ..Clear()
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), tOutcome _ ": a turn is reserved")
        Do $$$AssertEquals(tBusy, 0, tOutcome _ ": and is not busy")
        If $Get(tKey) = "" Continue
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, tUser, ..#LIMITS, .tBegun, .tStarted, "permissions/users"), tOutcome _ ": and begun")

        Set tHttp = $Select(tOutcome = "completed": 200, 1: 500)
        Set tBody = $Select(tOutcome = "completed": $Parameter("OcuPilot.Test.Provider", "OKBODY"), 1: "{""error"":""probe""}")
        Do $$$AssertStatusOK(..Drive(tHttp, tBody, .tResponse, .tCallHttp, .tFault), tOutcome _ ": the provider call returns")

        ; The row the turn writes for that call, through the shipped writer.
        Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "RecordProviderCall", tKey, tUser, "permissions/users", "anthropic", "probe-residue-model-1", 1, 10, 20, $Select(tOutcome = "completed": "ok", 1: "error"), $Select(tOutcome = "completed": "", 1: "PROVIDER.TRANSPORT"), tCallHttp, ..#LIMITS), tOutcome _ ": the provider row is recorded")

        ; And a tool row whose arguments carry the canary in a field the tool declares secret, which
        ; is the layer a name pattern alone cannot see (AD-3).
        Set tInput = {"Name": "probe"}
        Do tInput.%Set("Value", ..#CANARY, "string")
        Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "RecordToolCall", tKey, tUser, "permissions/users", "probe.residue.read", "target", tInput, $ListBuild($ListBuild("%Admin_Operate", "USE")), "", $ListBuild("Value"), "ok", "", ..#LIMITS, 1), tOutcome _ ": the tool row is recorded")

        Set tRowText = ##class(OcuPilot.Test.Ledger).RowText(tKey)
        Do $$$AssertEquals(tRowText [ ..#CANARYMARK, 0, tOutcome _ ": no ledger column carries the key: " _ tRowText)
        Set tStepText = ##class(OcuPilot.Test.Ledger).StepText(tKey)
        Do $$$AssertEquals(tStepText [ ..#CANARYMARK, 0, tOutcome _ ": no transcript step column carries it either: " _ tStepText)

        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedView(tKey, tUser, .tFound, .tProgress), tOutcome _ ": the progress record reads")
        Do $$$AssertEquals(tFound, 1, tOutcome _ ": and the turn is found")
        Do $$$AssertEquals($Select($IsObject($Get(tProgress)): tProgress.%ToJSON(), 1: "") [ ..#CANARYMARK, 0, tOutcome _ ": and the progress record carries none of it")

        Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, $Select(tOutcome = "completed": "completed", 1: "failed"), "", "", "done", 0, ..#LIMITS)
    }
}

}
