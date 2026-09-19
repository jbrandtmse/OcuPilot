/// <p>The agent ledger's two redaction layers and their order (AD-3): a declared secret absent from
/// every column of the row and from every serialization of the view, the name pattern adding over
/// the declaration rather than replacing it, the same wiring at both dispatch call sites, a call no
/// declaration was read for withholding its arguments whole, and a tool that declares nothing
/// refused at registration.</p>
/// <p><b>Split out of <class>OcuPilot.Test.Ledger</class>, whose helpers it calls by full class
/// name</b> -- the shape <class>OcuPilot.Test.LedgerStep</class> established.</p>
/// <p><b>Live-safe.</b> It spawns nothing, creates no principal and touches no registration. Every
/// row it writes names <parameter>PROBEUSER</parameter> or <code>$USERNAME</code>, and
/// <method>OnAfterOneTest</method> asserts none of its own survives.</p>
Class OcuPilot.Test.LedgerRedaction Extends %UnitTest.TestCase
{

/// <p>The store under test.</p>
Parameter STORE = "OcuPilot.Kernel.State.Ledger";

/// <p>The ledger's public face.</p>
Parameter LEDGER = "OcuPilot.Kernel.Audit.Ledger";

/// <p>The shipped bounds.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The user every probe row records -- its own, so the teardown's row sweep cannot reach a
/// sibling's rows. It keeps <parameter>OcuPilot.Test.TurnFixture.PROBEPREFIX</parameter> because
/// every probe user in this suite does; this class reserves no turn, so the prefix buys it
/// nothing of its own and the property its teardown has to preserve is the row sweep.</p>
Parameter PROBEUSER = "OcuPilotProbeTurnLedgerRedact";

/// <p>The declared secret's own value, which must reach no column and no view.</p>
Parameter SECRETVALUE = "s3cr3tredactvalue";

Method OnBeforeOneTest() As %Status
{
    Do ..Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Clear()
    Do $$$AssertEquals(..RowCount(), 0, "no probe ledger row survives the method")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).RemoveTurns(.tRemaining), "the probe turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>Remove every probe row this class could have written.</p>
Method Clear()
{
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..#PROBEUSER)
}

/// <p>How many rows name this class's own probe user.</p>
ClassMethod RowCount() As %Integer
{
    Quit ##class(OcuPilot.Test.Ledger).RowCountFor(..#PROBEUSER)
}

/// <p>Record one tool call as <b>this</b> class's probe user, through the sibling's own recorder, so
/// a moved method keeps the call it had and the rows it writes are swept by this class's teardown.</p>
ClassMethod Record(pTurnKey As %String, pName As %String, pInput As %DynamicObject, pSecretNames As %List = "", pDeclaredPairs As %List = "", pArgumentPairs As %List = "", pLimits As %String = {..#LIMITS}, pClassified As %Boolean = 1) As %Status
{
    Quit ##class(OcuPilot.Test.Ledger).Record(pTurnKey, pName, pInput, pSecretNames, pDeclaredPairs, pArgumentPairs, pLimits, ..#PROBEUSER, pClassified)
}

/// <p>AC3 -- a declared secret argument appears nowhere in the stored row, in any column, nor in the
/// view the read route answers. The declaration is what sees it: <code>Value</code> matches no name
/// pattern, which is exactly why AD-3 makes the schema layer the defense and the pattern a
/// backstop.</p>
/// <p>Mutation (Rule 19): remove layer 1 from
/// <method>OcuPilot.Kernel.Audit.Ledger.RedactArguments</method>, leaving only
/// <method>OcuPilot.Kernel.Audit.Log.Redact</method> -- the value appears and this goes red.</p>
Method TestADeclaredSecretIsAbsentFromTheWholeRow()
{
    Set tKey = ##class(OcuPilot.Test.Ledger).NewTurnKey()
    Set tInput = {"Name": "probe"}
    Do tInput.%Set("Value", ..#SECRETVALUE, "string")
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", tInput, $ListBuild("Value")), "the call is recorded")

    Set tText = ##class(OcuPilot.Test.Ledger).RowText(tKey)
    Do $$$AssertTrue(tText '= "", "the row was stored: " _ tText)
    Do $$$AssertEquals(tText [ ..#SECRETVALUE, 0, "no column of the stored row carries the declared secret: " _ tText)
    Do $$$AssertTrue(tText [ "[redacted]", "and the declared argument reads as redacted instead")
    Do $$$AssertTrue(tText [ "probe", "while the ordinary argument survives")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tView, .tFault), "the view reads")
    Do $$$AssertEquals($IsObject(tFault), 0, "with no fault")
    Do $$$AssertEquals(tView.%ToJSON() [ ..#SECRETVALUE, 0, "and no serialization of the view carries it either: " _ tView.%ToJSON())
}

/// <p>AC3 -- the pattern layer adds and the declaration survives it: an undeclared
/// <code>apiKey</code> is redacted by the backstop, the declared <code>Value</code> is still
/// redacted after the backstop has run, an ordinary bound is left in clear, and neither secret's
/// text reaches the answer.</p>
/// <p>Mutation (Rule 19): in
/// <method>OcuPilot.Kernel.Audit.Ledger.RedactArguments</method>, pass <var>pInput</var> rather than
/// the layer-1 copy to <method>OcuPilot.Kernel.Agent.Dispatch.RedactedArguments</method> -- the
/// declared value reaches the answer, the soundness check refuses, and the two assertions on the
/// declared name go red while the <code>apiKey</code> one stays green.</p>
Method TestThePatternAddsAndTheDeclarationSurvivesIt()
{
    Set tInput = {"maxTokens": 4000}
    Do tInput.%Set("Value", ..#SECRETVALUE, "string")
    Do tInput.%Set("apiKey", "sk-probe-undeclared", "string")

    Set tOut = $ClassMethod(..#LEDGER, "RedactArguments", tInput, $ListBuild("Value"), 4096, .tTruncated, .tRedacted)
    Do $$$AssertTrue($ListFind(tRedacted, "Value") > 0, "the declared name is redacted after both layers: " _ tOut)
    Do $$$AssertTrue($ListFind(tRedacted, "apiKey") > 0, "and the pattern added the undeclared credential-named one")
    Do $$$AssertEquals($ListFind(tRedacted, "maxTokens"), 0, "while an ordinary bound is not redacted")
    Do $$$AssertEquals(tOut [ ..#SECRETVALUE, 0, "the declared value reaches the answer nowhere: " _ tOut)
    Do $$$AssertEquals(tOut [ "sk-probe-undeclared", 0, "and neither does the pattern-matched one")
    Do $$$AssertTrue(tOut [ "4000", "while the ordinary bound is carried in clear")
    Do $$$AssertEquals(tTruncated, 0, "and nothing was cut")

    ; The caller's own object is untouched: redaction is a logging concern, never a data loss.
    Do $$$AssertEquals(tInput.%Get("Value"), ..#SECRETVALUE, "the caller still holds its own input unchanged")
}

/// <p>AC3 -- the wiring gap the review named: <method>TestADeclaredSecretIsAbsentFromTheWholeRow</method>
/// records its row through <method>OcuPilot.Kernel.Audit.Ledger.RecordToolCall</method> directly with
/// its own declared-secret list, which pins the redaction but not the read that gets that list off
/// the resolved tool at the real dispatch site. This drives the same declared secret through
/// <method>OcuPilot.Kernel.Agent.Dispatch.Answer</method> itself -- the instance-fulfilled path -- and
/// asserts it reaches no column of the stored row and no serialization of the view.</p>
/// <p>Mutation (Rule 19): replace the <code>$ClassMethod(tRegistry, "SecretArguments", tTool,
/// .tSecretDeclared)</code> call in <method>OcuPilot.Kernel.Agent.Dispatch.AnswerOne</method> with
/// <code>""</code> -- layer 1 has nothing to redact and this goes red. For the step's own argument
/// string: delete the <method>StepArguments</method> line beside that call -- the step assertions
/// go red while the row's stay green.</p>
Method TestADeclaredSecretDispatchedThroughAnswerOneIsAbsentFromTheRow()
{
    Set tKey = ##class(OcuPilot.Test.Ledger).NewTurnKey()
    Set tUse = {"id": "toolu_secret"}
    Do tUse.%Set("name", "probe_ledger_read", "string")
    Set tInput = {"Name": "probe"}
    Do tInput.%Set("Value", ..#SECRETVALUE, "string")
    Do tUse.%Set("input", tInput)
    Set tUses = []
    Do tUses.%Push(tUse)

    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerDispatchProbe", "Answer", tKey, $Username, "1", tUses, ..#LIMITS, .tResults, .tNames, , , .tDetails, "probe/route"), "the dispatcher answers the call")
    Do $$$AssertEquals(tResults.%Size(), 1, "with one result")
    If tResults.%Size() = 1 Do $$$AssertEquals(tResults.%Get(0).%Get("is_error"), 0, "and the call itself succeeds: " _ tResults.%Get(0).%Get("content"))

    Set tText = ##class(OcuPilot.Test.Ledger).RowText(tKey)
    Do $$$AssertTrue(tText '= "", "the row was stored: " _ tText)
    Do $$$AssertEquals(tText [ ..#SECRETVALUE, 0, "no column of the row dispatched through Answer carries the declared secret: " _ tText)
    Do $$$AssertTrue(tText [ "[redacted]", "and it reads as redacted instead")

    ; The same call's tool-step argument string, which AnswerOne answers alongside the row and its
    ; caller stores in OcuPilot_Kernel_State.Step: the declaration reaches it too, or the ledger is
    ; redacted and the step beside it is not.
    Set tStepArgs = $Select(tDetails.%Size() = 1: tDetails.%Get(0).arguments, 1: "")
    Do $$$AssertTrue(tStepArgs '= "", "the call answers a step argument string: " _ tStepArgs)
    Do $$$AssertEquals(tStepArgs [ ..#SECRETVALUE, 0, "which does not carry the declared secret either: " _ tStepArgs)
    Do $$$AssertTrue(tStepArgs [ "[redacted]", "and reads as redacted instead")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", $Username, "", 0, tKey, 10, .tView, .tFault), "the view reads")
    Do $$$AssertEquals($IsObject(tFault), 0, "with no fault")
    Do $$$AssertEquals(tView.%ToJSON() [ ..#SECRETVALUE, 0, "and no serialization of the view carries it either: " _ tView.%ToJSON())

    Do $ClassMethod(..#STORE, "GuardedDeleteForTurn", tKey)
}

/// <p>AC3 -- the client-fulfilled half of the same wiring gap:
/// <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method> is the call site
/// <class>OcuPilot.Kernel.Agent.Loop</class> reads a declared secret's classification off of before a
/// client-fulfilled call settles (<method>OcuPilot.Kernel.Agent.Loop.RecordClientRow</method>). This
/// calls it directly with a tool declaring <code>Value</code> secret and records the row from exactly
/// the pairs and declaration it answered -- not a hand-supplied list -- so the secret's absence is
/// proof of the resolver's own wiring, not of the ledger's redaction alone.</p>
/// <p>Mutation (Rule 19): replace the <code>$ClassMethod(tRegistry, "SecretArguments", tTool,
/// .pSecretDeclared)</code> call in <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method>
/// with <code>""</code> -- the resolver's own declaration reads empty, it reports that nothing
/// classified the call, and the two declaration assertions below go red. For the step's own argument
/// string: delete the <method>StepArguments</method> line beside that call -- the argument-string
/// assertions go red while the row's stay green.</p>
Method TestADeclaredSecretResolvedForAClientFulfilledCallIsAbsentFromTheRow()
{
    Set tBlock = {"id": "toolu_client"}
    Do tBlock.%Set("name", "probe_ledger_clientread", "string")
    Set tInput = {"Name": "probe"}
    Do tInput.%Set("Value", ..#SECRETVALUE, "string")
    Do tBlock.%Set("input", tInput)

    Set tSC = $ClassMethod("OcuPilot.Test.LedgerClientDispatchProbe", "ResolveClientCall", $Username, tBlock, ..#LIMITS, .tPending, .tToolName, .tRoute, .tEntityId, .tTarget, .tArguments, .tArgTrunc, .tIsError, .tContent, .tReason, .tFailedPair, ##class(OcuPilot.Test.Ledger).NewTurnKey(), .tCInput, .tDeclaredPairs, .tCallPairs, .tSecretNames, .tSecretDeclared)
    Do $$$AssertStatusOK(tSC, "the client call resolves")
    Do $$$AssertEquals(tPending, 1, "and validates through to a directive: " _ tContent)
    Do $$$AssertEquals($ListToString(tSecretNames), "Value", "carrying the tool's own secret declaration, read by the resolver itself")
    Do $$$AssertEquals(tSecretDeclared, 1, "and reporting that a classification was read at all")
    Do $$$AssertEquals(tArguments [ ..#SECRETVALUE, 0, "and answering a step argument string the declaration has already been applied to: " _ tArguments)
    Do $$$AssertTrue(tArguments [ "[redacted]", "which reads as redacted instead")

    ; Record the row from exactly what the resolver answered -- the same values
    ; OcuPilot.Kernel.Agent.Loop.RecordClientRow would carry -- so the row's own absence proves the
    ; wiring, not a hand-supplied declared-secret list.
    Set tKey = ##class(OcuPilot.Test.Ledger).NewTurnKey()
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "RecordToolCall", tKey, ..#PROBEUSER, "probe/route", tToolName, tTarget, tCInput, tDeclaredPairs, tCallPairs, tSecretNames, "ok", "", ..#LIMITS, tSecretDeclared), "the row is recorded from the resolver's own outputs")

    Set tText = ##class(OcuPilot.Test.Ledger).RowText(tKey)
    Do $$$AssertTrue(tText '= "", "the row was stored: " _ tText)
    Do $$$AssertEquals(tText [ ..#SECRETVALUE, 0, "no column of the row carries the declared secret: " _ tText)
    Do $$$AssertTrue(tText [ "[redacted]", "and it reads as redacted instead")
}

/// <p>A call no declaration was read for withholds its arguments whole: <code>arguments</code>
/// stores <method>OcuPilot.Kernel.Audit.Log</method>'s redaction mark alone,
/// <code>argumentsTruncated</code> reads 0, and no value the caller sent reaches any column. The
/// classified leg beside it records the same input field by field, so the two states are told apart
/// by what is stored.</p>
/// <p>Mutation (Rule 19): drop the <var>pClassified</var> branch from
/// <method>OcuPilot.Kernel.Audit.Ledger.RecordToolCall</method> so it always redacts by
/// declaration -- the withheld row stores the model's own argument object, whose undeclared
/// <code>Value</code> no name pattern sees, and this goes red.</p>
Method TestAnUnclassifiedCallWithholdsItsArgumentsWhole()
{
    Set tInput = {"Name": "probe"}
    Do tInput.%Set("Value", ..#SECRETVALUE, "string")

    Set tKey = ##class(OcuPilot.Test.Ledger).NewTurnKey()
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", tInput, "", "", "", ..#LIMITS, 0), "a call nothing classified is recorded")
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tView, .tFault), "the view reads")
    Do $$$AssertEquals($IsObject(tFault), 0, "with no fault")
    Do $$$AssertEquals(tView.rowsSent, 1, "one row: " _ tView.%ToJSON())
    If tView.rowsSent = 1 {
        Set tRow = tView.rows.%Get(0)
        Do $$$AssertEquals(tRow.arguments, ##class(OcuPilot.Kernel.Audit.Log).#REDACTED, "whose arguments are the redaction mark alone: " _ tRow.arguments)
        Do $$$AssertEquals(tRow.argumentsTruncated, 0, "and are not reported as cut")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.Ledger).RowText(tKey) [ ..#SECRETVALUE, 0, "with the value the caller sent in no column: " _ ##class(OcuPilot.Test.Ledger).RowText(tKey))

    ; The same input from a call whose tool did declare: recorded field by field, the declared name
    ; redacted and the ordinary one in clear. Without this leg the mark above could be what every
    ; row stores.
    Set tKeyB = ##class(OcuPilot.Test.Ledger).NewTurnKey()
    Do $$$AssertStatusOK(..Record(tKeyB, "probe.ledger.read", tInput, $ListBuild("Value")), "the same input from a classified call is recorded")
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, "", 0, tKeyB, 10, .tViewB, .tFaultB), "and reads")
    Do $$$AssertEquals(tViewB.rowsSent, 1, "as one row")
    If tViewB.rowsSent = 1 {
        Set tRowB = tViewB.rows.%Get(0)
        Do $$$AssertNotEquals(tRowB.arguments, ##class(OcuPilot.Kernel.Audit.Log).#REDACTED, "whose arguments are not withheld whole")
        Do $$$AssertTrue(tRowB.arguments [ "probe", "carrying the ordinary argument in clear: " _ tRowB.arguments)
        Do $$$AssertTrue(tRowB.arguments [ ##class(OcuPilot.Kernel.Audit.Log).#REDACTED, "and the declared one redacted in place")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.Ledger).RowText(tKeyB) [ ..#SECRETVALUE, 0, "with the declared value in no column either")
}

/// <p>The wiring of the withheld row on the path that produces it: a wire name that resolves no
/// tool. <method>OcuPilot.Kernel.Agent.Dispatch.AnswerOne</method> has no declaration to read on
/// that branch, so the row it writes at its common exit must withhold the model-authored argument
/// blob rather than store it behind the name pattern alone -- the row is permanent and its empty
/// requirement releases it to any administrator.</p>
/// <p>Mutation (Rule 19): pass <code>1</code> in place of <code>$Get(tSecretDeclared)</code> at
/// <method>OcuPilot.Kernel.Agent.Dispatch.AnswerOne</method>'s common exit -- the undeclared
/// <code>Value</code> is stored in clear and this goes red.</p>
Method TestACallWhoseWireNameResolvedNoToolWithholdsItsArguments()
{
    Set tKey = ##class(OcuPilot.Test.Ledger).NewTurnKey()
    Set tUse = {"id": "toolu_unknown"}
    Do tUse.%Set("name", "probe_ledger_missing", "string")
    Set tInput = {"Name": "probe"}
    Do tInput.%Set("Value", ..#SECRETVALUE, "string")
    Do tUse.%Set("input", tInput)
    Set tUses = []
    Do tUses.%Push(tUse)

    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerDispatchProbe", "Answer", tKey, $Username, "1", tUses, ..#LIMITS, .tResults, .tNames, , , .tDetails, "probe/route"), "the dispatcher answers the call")
    Do $$$AssertEquals(tResults.%Size(), 1, "with one result")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", $Username, "", 0, tKey, 10, .tView, .tFault), "the view reads")
    Do $$$AssertEquals($IsObject(tFault), 0, "with no fault")
    Do $$$AssertEquals(tView.rowsSent, 1, "one row was written: " _ tView.%ToJSON())
    If tView.rowsSent = 1 {
        Set tRow = tView.rows.%Get(0)
        Do $$$AssertEquals(tRow.code, ##class(OcuPilot.Api.Error).#TOOLUNKNOWN, "for a wire name no tool answered")
        Do $$$AssertEquals(tRow.arguments, ##class(OcuPilot.Kernel.Audit.Log).#REDACTED, "whose arguments are withheld whole: " _ tRow.arguments)
        Do $$$AssertEquals(tRow.argumentsTruncated, 0, "and are not reported as cut")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.Ledger).RowText(tKey) [ ..#SECRETVALUE, 0, "with the model's own value in no column: " _ ##class(OcuPilot.Test.Ledger).RowText(tKey))

    Do $ClassMethod(..#STORE, "GuardedDeleteForTurn", tKey)
}

/// <p>AC3 -- a tool that declares nothing about its arguments is refused when the tools are
/// advertised, naming it; the same registry with only the declaring tool advertises. Silence is not
/// read as "no secrets" (AD-3).</p>
/// <p>Mutation (Rule 19): make
/// <method>OcuPilot.Screen.Tool.Registry.ProviderTools</method> skip its
/// <method>SecretArguments</method> check -- the fixture advertises and this goes red.</p>
Method TestAToolDeclaringNothingIsRefusedAtRegistration()
{
    Set tSC = $ClassMethod("OcuPilot.Test.LedgerTool.All", "ProviderTools", .tAll)
    Do $$$AssertStatusNotOK(tSC, "a tool declaring no secret-argument classification refuses the advertisement")
    Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ "probe.silent.read", "naming the tool: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(+$Get(tAll), 0, "and nothing is advertised")

    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerTool.Registry", "ProviderTools", .tDeclared), "the declaring tool alone advertises")
    Do $$$AssertEquals(+$Get(tDeclared), 1, "as one tool")

    ; The declaration is read through the registry wrapper the advertisement uses, so the two
    ; cannot come to disagree about what a tool answered.
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerTool.Registry", "Resolve", "probe.ledger.read", .tTool), "the declaring tool resolves")
    Set tNames = ##class(OcuPilot.Screen.Tool.Registry).SecretArguments(tTool, .tDeclaredFlag)
    Do $$$AssertEquals(tDeclaredFlag _ "|" _ $ListToString(tNames), "1|Value", "and its declaration reads back through the registry")
}

/// <p>An argument the caller sent as the literal redaction mark is still redacted, and is <b>not</b>
/// reported as evidence of redaction: the argument string is stored rather than discarded whole, the
/// value-survival scan does not trip, and nothing is logged as a redaction failure. Reported, the
/// answer would claim a secret was masked where the caller sent none; discarded, a caller could
/// cost a row every one of its arguments by sending eight characters. The second is the half a
/// stored row shows -- no shipped caller reads the reported names today, so the first is a
/// contract this method is the one reader of.</p>
/// <p>The second leg is the control: the same key carrying a real secret <i>is</i> reported, so the
/// absence above is provenance rather than a reporter that answers nothing.</p>
/// <p>Mutation (Rule 19): drop the mark from the value-survival scan's skip, or restore the bare
/// equality test in <method>OcuPilot.Kernel.Audit.Ledger.RedactedKeys</method> -- this goes red.</p>
Method TestACallerSentMarkerIsRedactedAndNotReportedAsRedacted()
{
    Set tMark = ##class(OcuPilot.Kernel.Audit.Log).#REDACTED
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Set tInput = {"Name": "probe"}
    Do tInput.%Set("Value", tMark, "string")

    Set tOut = $ClassMethod("OcuPilot.Test.LedgerLogProbe", "RedactArguments", tInput, $ListBuild("Value"), 4096, .tTruncated, .tRedacted)
    Do $$$AssertNotEquals(tOut, "", "the argument string is stored rather than discarded whole")
    Do $$$AssertTrue(tOut [ tMark, "with the declared key reading as the mark: " _ tOut)
    Do $$$AssertTrue(tOut [ "probe", "and the ordinary argument in clear")
    Do $$$AssertEquals($ListFind(tRedacted, "Value"), 0, "the key is not reported as redacted, because nothing was masked: " _ $ListToString(tRedacted))
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and nothing is logged as a redaction failure: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))

    Set tReal = {"Name": "probe"}
    Do tReal.%Set("Value", ..#SECRETVALUE, "string")
    Set tRealOut = $ClassMethod("OcuPilot.Test.LedgerLogProbe", "RedactArguments", tReal, $ListBuild("Value"), 4096, .tRealTruncated, .tRealRedacted)
    Do $$$AssertTrue($ListFind(tRealRedacted, "Value") > 0, "a declared name whose value the layers changed is reported: " _ $ListToString(tRealRedacted))
    Do $$$AssertEquals(tRealOut [ ..#SECRETVALUE, 0, "and its value reaches the answer nowhere: " _ tRealOut)
    Do ##class(OcuPilot.Test.LogProbe).Clear()
}

}
