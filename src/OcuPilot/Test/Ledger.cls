/// <p>The agent ledger in process (AD-3, AD-9, AD-21, AD-37, AD-41): the two redaction layers and
/// their order, the mandatory declaration, the pair string's round trip, the per-turn row cap and its
/// overflow count, the argument cut, the bounded windowed read's binding, and a swept turn leaving
/// its rows behind.</p>
/// <p><b>Live-safe with one exception.</b> It spawns nothing, creates no principal and touches no
/// registration. Every row it writes carries a user name starting with
/// <parameter>PROBEUSER</parameter>'s prefix and a turn key starting with
/// <parameter>KEYPREFIX</parameter>, and <method>OnAfterOneTest</method> asserts none survives. The
/// exception is <method>TestASweepRemovesTheTurnAndLeavesItsLedgerRows</method>, which runs
/// <method>OcuPilot.Kernel.State.Turn.GuardedSweep</method> -- instance-wide over every terminal
/// turn past retention, not only this class's.</p>
Class OcuPilot.Test.Ledger Extends %UnitTest.TestCase
{

/// <p>The store under test.</p>
Parameter STORE = "OcuPilot.Kernel.State.Ledger";

/// <p>The ledger's public face.</p>
Parameter LEDGER = "OcuPilot.Kernel.Audit.Ledger";

/// <p>The shipped bounds, and the narrowed ones a cap test runs under.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter NARROW = "OcuPilot.Test.LedgerLimits";

/// <p>The shipped bounds with only the reply budget narrowed.</p>
Parameter BUDGET = "OcuPilot.Test.LedgerBudgetLimits";

/// <p>The user every probe row records. It shares
/// <parameter>OcuPilot.Test.TurnFixture.PROBEPREFIX</parameter>, so a turn this class reserves is
/// removed by that fixture's own teardown.</p>
Parameter PROBEUSER = "OcuPilotProbeTurnLedgerA";

/// <p>The prefix every probe turn key carries.</p>
Parameter KEYPREFIX = "ocupilotprobeledger";

/// <p>The declared secret's own value, which must reach no column and no view.</p>
Parameter SECRETVALUE = "s3cr3tledgervalue";

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
    Do ##class(OcuPilot.Test.LedgerGate).Clear()
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..#PROBEUSER)
    Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..#PROBEUSER _ "B")
}

/// <p>How many rows name this class's probe users, by direct SQL rather than through the store the
/// tests are checking.</p>
ClassMethod RowCount() As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE UserName %STARTSWITH ?", ..#PROBEUSER)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>Every column of every row of turn <var>pTurnKey</var>, concatenated -- the serialization an
/// absence assertion is made against, read by direct SQL so it covers what is stored rather than
/// what a projection chose to show.</p>
ClassMethod RowText(pTurnKey As %String) As %String
{
    Set tText = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT * FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", pTurnKey)
    If tRS.%SQLCODE < 0 Quit "SQLCODE=" _ tRS.%SQLCODE
    Set tMeta = tRS.%GetMetadata()
    While tRS.%Next() {
        For tI = 1:1:tMeta.columns.Count() {
            Set tText = tText _ "|" _ tRS.%GetData(tI)
        }
    }
    Quit tText
}

/// <p>Every column of every progress step of turn <var>pTurnKey</var>, concatenated -- the same
/// serialization <method>RowText</method> makes of the ledger, over the store beside it. A tool
/// step's own argument string runs the same two redaction layers a ledger row's does
/// (<method>OcuPilot.Kernel.Agent.Dispatch.StepArguments</method>), so a declared secret must be
/// absent from both or the redaction is only half wired.</p>
ClassMethod StepText(pTurnKey As %String) As %String
{
    Set tText = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT * FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ?", pTurnKey)
    If tRS.%SQLCODE < 0 Quit "SQLCODE=" _ tRS.%SQLCODE
    Set tMeta = tRS.%GetMetadata()
    While tRS.%Next() {
        For tI = 1:1:tMeta.columns.Count() {
            Set tText = tText _ "|" _ tRS.%GetData(tI)
        }
    }
    Quit tText
}

/// <p>A fresh probe turn key.</p>
ClassMethod NewTurnKey() As %String
{
    Quit ..#KEYPREFIX _ $Translate($System.Util.CreateGUID(), "-", "")
}

/// <p>Record one tool call through the ledger's own public face. <var>pClassified</var> defaults to
/// 1 -- the ordinary case of a resolved tool whose declaration was read -- so a caller passing 0
/// asks for the withheld-arguments row instead.</p>
ClassMethod Record(pTurnKey As %String, pName As %String, pInput As %DynamicObject, pSecretNames As %List = "", pDeclaredPairs As %List = "", pArgumentPairs As %List = "", pLimits As %String = {..#LIMITS}, pUser As %String = {..#PROBEUSER}, pClassified As %Boolean = 1) As %Status
{
    Quit $ClassMethod(..#LEDGER, "RecordToolCall", pTurnKey, pUser, "permissions/users", pName, "target-" _ pName, pInput, pDeclaredPairs, pArgumentPairs, pSecretNames, "ok", "", pLimits, pClassified)
}

/// <p>Every <code>LEDGER*</code> code the error vocabulary declares is in
/// <method>OcuPilot.Api.Error.LedgerCodes</method> and has a written sentence. Its own copy of the
/// turn family's test, because that one filters on <code>TURN</code>.</p>
/// <p>Mutation (Rule 19): remove the <code>LEDGER.UNAVAILABLE</code> branch from
/// <method>OcuPilot.Api.Error.ReasonForLedger</method> -- this goes red.</p>
Method TestEveryLedgerCodeHasASentence()
{
    Set tDeclared = ##class(OcuPilot.Api.Error).LedgerCodes()
    Set tFound = 0
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledParameter WHERE parent = ?", "OcuPilot.Api.Error")
    While tRS.%Next() {
        Set tName = tRS.%GetData(1)
        If $Extract(tName, 1, 6) '= "LEDGER" Continue
        Set tFound = tFound + 1
        Set tCode = $Parameter("OcuPilot.Api.Error", tName)
        Do $$$AssertTrue($ListFind(tDeclared, tCode) > 0, tName _ " is in LedgerCodes()")
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForLedger(tCode), "", tName _ " has a written sentence")
    }
    Do $$$AssertTrue(tFound > 0, "the vocabulary declares ledger codes")
    Do $$$AssertEquals($ListLength(tDeclared), tFound, "and LedgerCodes() holds no code the class does not declare")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForLedger("TURN.BUSY"), "", "and no code from another family")
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
    Set tKey = ..NewTurnKey()
    Set tInput = {"Name": "probe"}
    Do tInput.%Set("Value", ..#SECRETVALUE, "string")
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", tInput, $ListBuild("Value")), "the call is recorded")

    Set tText = ..RowText(tKey)
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
    Set tKey = ..NewTurnKey()
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

    Set tText = ..RowText(tKey)
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

    Set tSC = $ClassMethod("OcuPilot.Test.LedgerClientDispatchProbe", "ResolveClientCall", $Username, tBlock, ..#LIMITS, .tPending, .tToolName, .tRoute, .tEntityId, .tTarget, .tArguments, .tArgTrunc, .tIsError, .tContent, .tReason, .tFailedPair, ..NewTurnKey(), .tCInput, .tDeclaredPairs, .tCallPairs, .tSecretNames, .tSecretDeclared)
    Do $$$AssertStatusOK(tSC, "the client call resolves")
    Do $$$AssertEquals(tPending, 1, "and validates through to a directive: " _ tContent)
    Do $$$AssertEquals($ListToString(tSecretNames), "Value", "carrying the tool's own secret declaration, read by the resolver itself")
    Do $$$AssertEquals(tSecretDeclared, 1, "and reporting that a classification was read at all")
    Do $$$AssertEquals(tArguments [ ..#SECRETVALUE, 0, "and answering a step argument string the declaration has already been applied to: " _ tArguments)
    Do $$$AssertTrue(tArguments [ "[redacted]", "which reads as redacted instead")

    ; Record the row from exactly what the resolver answered -- the same values
    ; OcuPilot.Kernel.Agent.Loop.RecordClientRow would carry -- so the row's own absence proves the
    ; wiring, not a hand-supplied declared-secret list.
    Set tKey = ..NewTurnKey()
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "RecordToolCall", tKey, ..#PROBEUSER, "probe/route", tToolName, tTarget, tCInput, tDeclaredPairs, tCallPairs, tSecretNames, "ok", "", ..#LIMITS, tSecretDeclared), "the row is recorded from the resolver's own outputs")

    Set tText = ..RowText(tKey)
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

    Set tKey = ..NewTurnKey()
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", tInput, "", "", "", ..#LIMITS, ..#PROBEUSER, 0), "a call nothing classified is recorded")
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tView, .tFault), "the view reads")
    Do $$$AssertEquals($IsObject(tFault), 0, "with no fault")
    Do $$$AssertEquals(tView.rowsSent, 1, "one row: " _ tView.%ToJSON())
    If tView.rowsSent = 1 {
        Set tRow = tView.rows.%Get(0)
        Do $$$AssertEquals(tRow.arguments, ##class(OcuPilot.Kernel.Audit.Log).#REDACTED, "whose arguments are the redaction mark alone: " _ tRow.arguments)
        Do $$$AssertEquals(tRow.argumentsTruncated, 0, "and are not reported as cut")
    }
    Do $$$AssertEquals(..RowText(tKey) [ ..#SECRETVALUE, 0, "with the value the caller sent in no column: " _ ..RowText(tKey))

    ; The same input from a call whose tool did declare: recorded field by field, the declared name
    ; redacted and the ordinary one in clear. Without this leg the mark above could be what every
    ; row stores.
    Set tKeyB = ..NewTurnKey()
    Do $$$AssertStatusOK(..Record(tKeyB, "probe.ledger.read", tInput, $ListBuild("Value")), "the same input from a classified call is recorded")
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, "", 0, tKeyB, 10, .tViewB, .tFaultB), "and reads")
    Do $$$AssertEquals(tViewB.rowsSent, 1, "as one row")
    If tViewB.rowsSent = 1 {
        Set tRowB = tViewB.rows.%Get(0)
        Do $$$AssertNotEquals(tRowB.arguments, ##class(OcuPilot.Kernel.Audit.Log).#REDACTED, "whose arguments are not withheld whole")
        Do $$$AssertTrue(tRowB.arguments [ "probe", "carrying the ordinary argument in clear: " _ tRowB.arguments)
        Do $$$AssertTrue(tRowB.arguments [ ##class(OcuPilot.Kernel.Audit.Log).#REDACTED, "and the declared one redacted in place")
    }
    Do $$$AssertEquals(..RowText(tKeyB) [ ..#SECRETVALUE, 0, "with the declared value in no column either")
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
    Set tKey = ..NewTurnKey()
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
    Do $$$AssertEquals(..RowText(tKey) [ ..#SECRETVALUE, 0, "with the model's own value in no column: " _ ..RowText(tKey))

    Do $ClassMethod(..#STORE, "GuardedDeleteForTurn", tKey)
}

/// <p>AC2 on the instance-fulfilled path -- a row's <code>requiredPairs</code> is written from the
/// pairs the dispatcher itself read, both halves of them.
/// <class>OcuPilot.Test.LedgerTool.Probe</class> declares <code>%Admin_Operate:USE</code> and adds
/// <code>%DB_IRISSYS:READ</code> only when the call names <code>Name</code>, so the two legs below
/// tell a row carrying the union from a row carrying the declared half alone. No shipped tool this
/// exit is reached with requires a pair, so an empty requirement would otherwise be truthful.</p>
/// <p>Mutation (Rule 19): replace <code>$Get(tPairs), $Get(tArgumentPairs)</code> with
/// <code>"", ""</code> at <method>OcuPilot.Kernel.Agent.Dispatch.AnswerOne</method>'s common exit --
/// both rows record no requirement and this goes red.</p>
Method TestARowsRequiredPairsComeFromTheDispatchersOwnReads()
{
    Set tBoth = ..NewTurnKey()
    Do $$$AssertEquals(..DispatchedPairs(tBoth, {"Name": "probe"}), "%Admin_Operate:USE,%DB_IRISSYS:READ", "a call naming Name records the declared pair unioned with the one its argument adds")

    Set tDeclaredOnly = ..NewTurnKey()
    Do $$$AssertEquals(..DispatchedPairs(tDeclaredOnly, {}), "%Admin_Operate:USE", "and a call naming none records the declared half alone")
}

/// <p>The <code>requiredPairs</code> of the one row a call with arguments <var>pInput</var> writes
/// through the shipped <method>OcuPilot.Kernel.Agent.Dispatch.AnswerOne</method> reading
/// <class>OcuPilot.Test.LedgerTool.Registry</class>. Answers a sentence naming what went wrong
/// instead, so a failure reads as itself rather than as a pair mismatch. Removes the turn's rows
/// before returning: they name <code>$Username</code> rather than
/// <parameter>PROBEUSER</parameter>.</p>
ClassMethod DispatchedPairs(pTurnKey As %String, pInput As %DynamicObject) As %String
{
    Set tOut = ""
    Try {
        Set tUse = {"id": "toolu_pairs"}
        Do tUse.%Set("name", "probe_ledger_read", "string")
        Do tUse.%Set("input", pInput)
        Set tUses = []
        Do tUses.%Push(tUse)
        Set tSC = $ClassMethod("OcuPilot.Test.LedgerDispatchProbe", "Answer", pTurnKey, $Username, "1", tUses, ..#LIMITS, .tResults, .tNames, , , .tDetails, "probe/route")
        If $$$ISERR(tSC) {
            Set tOut = "the dispatcher failed: " _ $System.Status.GetErrorText(tSC)
            Quit
        }
        Set tViewSC = $ClassMethod(..#LEDGER, "ViewForUser", $Username, "", 0, pTurnKey, 10, .tView, .tFault)
        If $$$ISERR(tViewSC) || $IsObject(tFault) || '$IsObject(tView) {
            Set tOut = "the view did not read"
            Quit
        }
        If tView.rowsSent '= 1 {
            Set tOut = "the call wrote " _ tView.rowsSent _ " rows: " _ tView.%ToJSON()
            Quit
        }
        Set tOut = tView.rows.%Get(0).requiredPairs
    } Catch ex {
        Set tOut = "the read raised: " _ ex.DisplayString()
    }
    Do $ClassMethod(..#STORE, "GuardedDeleteForTurn", pTurnKey)
    Quit tOut
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

/// <p>AC2 -- a row's <code>requiredPairs</code> is the declared set unioned with the
/// argument-derived one, canonically spelled, sorted and de-duplicated, and it round-trips back to
/// the pair list the gate evaluates.</p>
/// <p>Mutation (Rule 19): drop <var>pArgumentPairs</var> from
/// <method>OcuPilot.Kernel.Audit.Ledger.RecordToolCall</method>'s union -- the argument-derived pair
/// is absent and this goes red.</p>
Method TestARowsPairsAreTheUnionSortedAndDeduplicated()
{
    Set tDeclared = $ListBuild($ListBuild("%Admin_Operate", "USE"), $ListBuild("%Admin_Secure", "USE"))
    Set tArgument = $ListBuild($ListBuild("%DB_IRISSYS", "READ"), $ListBuild("%Admin_Operate", "USE"))
    Set tText = $ClassMethod(..#LEDGER, "PairsToString", tDeclared _ tArgument)
    Do $$$AssertEquals(tText, "%Admin_Operate:USE,%Admin_Secure:USE,%DB_IRISSYS:READ", "the union is sorted and de-duplicated")

    Set tBack = $ClassMethod(..#LEDGER, "StringToPairs", tText)
    Do $$$AssertEquals($ListLength(tBack), 3, "and round-trips to three pairs")
    Do $$$AssertEquals($List($List(tBack, 3), 1) _ ":" _ $List($List(tBack, 3), 2), "%DB_IRISSYS:READ", "each carrying its resource and permission")
    Do $$$AssertEquals($ClassMethod(..#LEDGER, "PairsToString", tBack), tText, "and back again unchanged")
    Do $$$AssertEquals($ClassMethod(..#LEDGER, "StringToPairs", ""), "", "an empty string is no pair at all")

    Set tKey = ..NewTurnKey()
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", {}, "", tDeclared, tArgument), "a call carrying both halves is recorded")
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tView, .tFault), "the view reads")
    Do $$$AssertEquals(tView.rows.%Size(), 1, "one row")
    If tView.rows.%Size() = 1 Do $$$AssertEquals(tView.rows.%Get(0).requiredPairs, tText, "carrying the union it was written with")
}

/// <p>AC4 -- past the per-turn row cap a call is counted, not stored: exactly
/// <code>LEDGERMAXROWS</code> rows are stored, one <code>overflow</code> row carries the count of
/// the rest, and the view reports it as <code>rowsDropped</code> without ever listing it as a call.
/// An argument string longer than <code>LEDGERROWMAXLENGTH</code> is cut to the bound, ends U+2026
/// and sets <code>argumentsTruncated</code>.</p>
/// <p>Mutation (Rule 19): drop the <var>pStored</var> cap check from
/// <method>OcuPilot.Kernel.State.Ledger.GuardedAppend</method> so it always saves -- four rows are
/// stored, no overflow row exists, and this goes red.</p>
Method TestTheRowCapStoresNoMoreAndCountsTheRest()
{
    Set tKey = ..NewTurnKey()
    Set tCap = +$Parameter(..#NARROW, "LEDGERMAXROWS")
    Do $$$AssertEquals(tCap, 2, "the narrowed cap is two rows")
    Set tLong = {}
    Do tLong.%Set("Name", "abcdefghijklmnopqrstuvwxyz0123456789", "string")
    For tI = 1:1:(tCap + 2) {
        Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", tLong, "", "", "", ..#NARROW), "call " _ tI _ " is recorded")
    }

    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedCountForTurn", tKey, .tRows), "the turn's rows are counted")
    Do $$$AssertEquals(tRows, tCap + 1, "exactly the cap plus the one overflow row is stored")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tView, .tFault), "the view reads")
    Do $$$AssertEquals(tView.rowsSent, tCap, "the view lists the stored calls and not the overflow row")
    Do $$$AssertEquals(tView.rowsDropped, 2, "and reports the two that were counted instead")

    ; Newest first (the matrix's "the caller's own rows, newest first, bounded"): which rows
    ; survive the cap is decided by this order, so an inverted read would hand a busy user their
    ; oldest activity and call it truncated.
    Do $$$AssertTrue(tView.rows.%Get(0).seq > tView.rows.%Get(1).seq, "the view answers newest first: seq " _ tView.rows.%Get(0).seq _ " then " _ tView.rows.%Get(1).seq)

    Set tRow = tView.rows.%Get(0)
    Set tMax = +$Parameter(..#NARROW, "LEDGERROWMAXLENGTH")
    Do $$$AssertEquals($Length(tRow.arguments), tMax, "the argument string is cut to the bound: " _ tRow.arguments)
    Do $$$AssertEquals($Extract(tRow.arguments, tMax), $Char(8230), "ending in the truncation mark")
    Do $$$AssertEquals(tRow.argumentsTruncated, 1, "and says it was cut")
}

/// <p>AC9 (DW-448) -- the windowed read runs through
/// <method>OcuPilot.Kernel.State.Base.GuardedIdsBounded</method> with every value bound: the window
/// cutoff, the row cap and each predicate. A user name carrying SQL matches literally and returns no
/// row, and the fragment the read is built from holds no value at all.</p>
/// <p>Mutation (Rule 19): in
/// <method>OcuPilot.Kernel.State.Ledger.GuardedIdsForWindow</method>, concatenate the user into the
/// fragment instead of binding it -- the injected name returns every row and this goes red.</p>
Method TestTheBoundedHelperBindsTheWindowAndThePredicates()
{
    Set tKey = ..NewTurnKey()
    For tI = 1:1:2 {
        Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", {}), "row " _ tI _ " is recorded")
    }

    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedIdsForWindow", ..#PROBEUSER, 0, "", 10, .tMine, .tProblem), "the user's own windowed read runs")
    Do $$$AssertEquals(+$Get(tMine), 2, "and finds both rows")

    Set tInjected = ..#PROBEUSER _ "' OR 1=1 --"
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedIdsForWindow", tInjected, 0, "", 10, .tInjectedIds, .tProblem), "a user name carrying SQL is read the same way")
    Do $$$AssertEquals(+$Get(tInjectedIds), 0, "and matches literally, returning no row")

    ; The row cap is bound too: asking for one of two rows answers one.
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedIdsForWindow", ..#PROBEUSER, 0, "", 1, .tOne, .tProblem), "a capped read runs")
    Do $$$AssertEquals(+$Get(tOne), 1, "and is cut to the cap")

    ; And the fragment itself carries no value -- the cutoff is pushed onto the parameter array.
    Set tParams = []
    Set tFragment = $ClassMethod(..#STORE, "BoundedWhere", 0, "LoggedAt", .tParams, .tProblem, "Seq > 0", "%EXACT(UserName) = ?")
    Do $$$AssertEquals(tFragment, "LoggedAt > ? AND (Seq > 0) AND (%EXACT(UserName) = ?)", "the fragment is placeholders only")
    Do $$$AssertEquals(tFragment [ "'", 0, "with no quoted value in it")
    Do $$$AssertEquals(tParams.%Size(), 1, "and the cutoff alone bound, at index 1")

    ; A refused window runs nothing rather than reading unbounded.
    Do $$$AssertStatusNotOK($ClassMethod(..#STORE, "GuardedIdsForWindow", ..#PROBEUSER, 99999, "", 10, .tNone, .tRefused), "a window outside the bound refuses the read")
    Do $$$AssertTrue(tRefused [ "720", "naming the bound: " _ tRefused)
}

/// <p>AC7 -- a terminal turn swept past retention takes its steps with it and leaves its ledger rows
/// behind. A ledger row is an audit record and outlives its turn (AD-37).</p>
/// <p>Mutation (Rule 19): add a <class>OcuPilot.Kernel.State.Ledger</class> arm to
/// <method>OcuPilot.Kernel.State.Turn.GuardedDelete</method>'s cascade -- the rows vanish with the
/// turn and this goes red.</p>
Method TestASweepRemovesTheTurnAndLeavesItsLedgerRows()
{
    Set tUser = ..#PROBEUSER
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), "a turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and is not busy")
    If $Get(tKey) = "" Quit

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Step).GuardedAppend(tKey, "model", "provider", "ok", "", "", "", ..#LIMITS, .tSeq, .tStored), "the turn has a step")
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", {}), "and a ledger row")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, "completed", "", "", "done", 0, ..#LIMITS), "the turn ends")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TurnFixture).Age(tKey, "EndedAt", +$Parameter(..#LIMITS, "RETENTIONSECONDS") + 60), "and is aged past retention")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedSweep(..#LIMITS), "the sweep runs")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "State"), "", "the turn is gone")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).StepCount(tKey), 0, "its steps are gone")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedCountForTurn", tKey, .tRows), "and its ledger rows are counted")
    Do $$$AssertEquals(tRows, 1, "which still read")
}

/// <p>AC6's store half -- a self read is ungated and a cross-user read is gated per row, so the
/// evaluation happens over the row's own recorded requirement rather than over the reader's
/// standing. The wire half, with a real least-privileged administrator, is
/// <class>OcuPilot.Test.LedgerWire</class>'s.</p>
/// <p>Both legs run through <class>OcuPilot.Test.LedgerGateProbe</class>, which holds nothing but
/// the administrative pair. The real gate cannot drive either: <code>%UnitTest</code> runs as a
/// <code>%All</code> account, for which <method>OcuPilot.Screen.Gate.HoldsPrivilege</method>
/// answers yes to every resource name, including one the instance does not define -- so a self read
/// through it reads the same whether it is gated or not.</p>
/// <p>Mutation (Rule 19): drop the <code>tCrossUser</code> condition from
/// <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method>'s per-row gate -- the self read starts
/// gating its owner's own rows against a resource the probe gate does not hold, and the first
/// assertion goes red.</p>
Method TestASelfReadIsUngatedAndACrossUserReadIsGatedPerRow()
{
    Set tKey = ..NewTurnKey()
    Set tPairs = $ListBuild($ListBuild("OcuPilotProbeNoSuchResource", "USE"))
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", {}, "", tPairs, ""), "a row recording an unheld resource is written")

    ; Through the probe gate, which holds nothing but the administrative pair: %UnitTest runs as a
    ; %All account, for which the real check answers yes to every resource name, so a self read
    ; driven through it could not tell an ungated read from a gated one.
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerGateProbe", "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tSelf, .tSelfFault), "the owner's own read runs")
    Do $$$AssertEquals($IsObject(tSelfFault), 0, "with no fault")
    Do $$$AssertEquals(tSelf.rowsSent _ "|" _ tSelf.rowsWithheld, "1|0", "and answers the row ungated (AD-46)")

    ; The same rows read as somebody else, through a gate that holds nothing: every row is withheld
    ; and counted, and none is answered with fields removed.
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerGateProbe", "ViewForUser", "OcuPilotProbeLedgerReader", ..#PROBEUSER, 0, tKey, 10, .tCross, .tCrossFault), "a cross-user read runs")
    Do $$$AssertEquals($IsObject(tCrossFault), 0, "with no fault, the administrative pair being held")
    Do $$$AssertEquals(tCross.rowsSent _ "|" _ tCross.rowsWithheld, "0|1", "and the row the reader cannot hold is absent and counted")
    Do $$$AssertEquals(tCross.rows.%ToJSON(), "[]", "with nothing of it on the wire at all")

    Do ##class(OcuPilot.Test.LedgerGate).Grant("OcuPilotProbeNoSuchResource", "USE")
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerGateProbe", "ViewForUser", "OcuPilotProbeLedgerReader", ..#PROBEUSER, 0, tKey, 10, .tGranted, .tGrantedFault), "the same read runs once the reader holds the resource")
    Do $$$AssertEquals(tGranted.rowsSent _ "|" _ tGranted.rowsWithheld, "1|0", "and the row appears")

    ; A requirement that will not parse is withheld rather than read as no requirement at all.
    Do ##class(OcuPilot.Test.LedgerGate).Clear()
    Do $$$AssertEquals($ClassMethod(..#LEDGER, "StringToPairs", "notapair"), "", "a malformed requirement yields no pair")
}

/// <p>Whether <var>pUser</var> is an account this instance holds, read in <code>%SYS</code> and the
/// namespace restored on both paths (AD-16).</p>
ClassMethod UserExists(pUser As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Security.Users).Exists(pUser)
    } Catch ex {
        Set tExists = 0
    }
    Set $NAMESPACE = tOrigNS
    Quit tExists
}

/// <p>Matrix row "Tool refused before dispatch" -- a call the reply budget cannot answer is refused
/// without dispatch and still writes one <code>tool</code> row, carrying the refusal code and no
/// pairs at all: nothing read them, and a row claiming a requirement no check evaluated would be a
/// claim about a check that did not happen.</p>
/// <p>It also pins <property>OcuPilot.Kernel.State.Turn.ContextRoute</property>, whose only writer
/// is the <method>GuardedBegin</method> call this method makes and whose only reader today is this
/// assertion: the turn row says which screen it ran from after its progress has been swept.</p>
/// <p>The tool it refuses is the fixture that declares <code>Value</code> secret, reached through
/// <class>OcuPilot.Test.LedgerDispatchProbe</class>: no shipped tool declares one, so a refusal
/// row's layer-1 redaction would otherwise have nothing to redact.</p>
/// <p>Mutation (Rule 19): delete the <method>RecordRefusedRow</method> call at
/// <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method>'s reply-budget branch -- no row is
/// written and this goes red. For the route: delete the
/// <property>ContextRoute</property> assignment in
/// <method>OcuPilot.Kernel.State.Turn.GuardedBegin</method> -- the added assertion goes red. For the declaration: pass <code>""</code> in place of <var>pTool</var> at
/// that same call -- the declared value reaches the row and the absence assertions go red.</p>
Method TestARefusalBeforeDispatchRecordsARowWithNoPairs()
{
    Set tUser = ..#PROBEUSER
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), "a turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and is not busy")
    If $Get(tKey) = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, tUser, ..#LIMITS, .tBegun, .tStarted, "permissions/users"), "and begun")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "ContextRoute"), "permissions/users", "the turn row records the screen it was begun from")

    Set tUses = []
    Set tBlock = {"id": "toolu_budget"}
    Do tBlock.%Set("name", "probe_ledger_read", "string")
    Set tBudgetInput = {"Name": "probe"}
    Do tBudgetInput.%Set("Value", ..#SECRETVALUE, "string")
    Do tBlock.%Set("input", tBudgetInput)
    Do tUses.%Push(tBlock)
    Set tLog = []
    Set tMessages = 0
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerLoopProbe", "AnswerTools", tKey, tUser, "1", "", tUses, ..#BUDGET, .tMessages, tLog, .tLastSeq, 0, "", 0, 0, .tState, .tCode, 0, "permissions/users"), "the call is answered")
    Do $$$AssertEquals(tState, "", "the turn is not stopped by the refusal")
    Do $$$AssertEquals(tLog.%Size(), 1, "and the refusal is logged once")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", tUser, "", 0, tKey, 10, .tView, .tFault), "the view reads")
    Do $$$AssertEquals($IsObject(tFault), 0, "with no fault")
    Do $$$AssertEquals(tView.rowsSent, 1, "one row was written: " _ tView.%ToJSON())
    If tView.rowsSent = 1 {
        Set tRow = tView.rows.%Get(0)
        Do $$$AssertEquals(tRow.kind, "tool", "a tool row")
        Do $$$AssertEquals(tRow.name, "probe.ledger.read", "naming the tool it would have run")
        Do $$$AssertEquals(tRow.status, "error", "refused")
        Do $$$AssertEquals(tRow.code, ##class(OcuPilot.Api.Error).#TOOLRESULTTOOLARGE, "with the refusal's own code")
        Do $$$AssertEquals(tRow.requiredPairs, "", "and no pairs, because nothing read them")
        Do $$$AssertEquals(tRow.route, "permissions/users", "recorded against the screen the turn ran from")
        ; A pair check that did not happen says nothing about which arguments are secret: the
        ; refusal resolved the tool, so its declaration is read and layer 1 runs (AD-3).
        Do $$$AssertEquals(tRow.arguments [ ..#SECRETVALUE, 0, "and the tool's declared secret nowhere in the row's arguments: " _ tRow.arguments)
        Do $$$AssertTrue(tRow.arguments [ "[redacted]", "which read as redacted instead")
    }
    Do $$$AssertEquals(..RowText(tKey) [ ..#SECRETVALUE, 0, "nor in any column of the stored row")
    Do $$$AssertEquals(..StepText(tKey) [ ..#SECRETVALUE, 0, "nor in any column of the tool step written beside it: " _ ..StepText(tKey))
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, "completed", "", "", "done", 0, ..#LIMITS)
}

/// <p>The unpinned sibling of <method>TestARefusalBeforeDispatchRecordsARowWithNoPairs</method>: a
/// stop caught at the per-call boundary itself -- distinct from the reply-budget refusal, and reached
/// through <class>OcuPilot.Test.LedgerLoopStopProbe</class>, whose <method>Boundary</method> always
/// answers stop -- still writes one <code>tool</code> row, carrying <code>TURN.STOPPED</code> and no
/// pairs, with the tool's declared secret redacted the same way.</p>
/// <p>Mutation (Rule 19): delete the <method>RecordRefusedRow</method> call at
/// <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method>'s boundary-stop branch -- no row is
/// written and this goes red.</p>
Method TestABoundaryStopBeforeDispatchRecordsARowWithNoPairs()
{
    Set tUser = ..#PROBEUSER
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve(tUser, "1", "TURN.ABANDONED.JOBLOST", ..#LIMITS, .tKey, .tBusy, .tSweep), "a turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and is not busy")
    If $Get(tKey) = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, tUser, ..#LIMITS, .tBegun, .tStarted, "permissions/users"), "and begun")

    Set tUses = []
    Set tBlock = {"id": "toolu_stop"}
    Do tBlock.%Set("name", "probe_ledger_read", "string")
    Set tStopInput = {"Name": "probe"}
    Do tStopInput.%Set("Value", ..#SECRETVALUE, "string")
    Do tBlock.%Set("input", tStopInput)
    Do tUses.%Push(tBlock)
    Set tLog = []
    Set tMessages = 0
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerLoopStopProbe", "AnswerTools", tKey, tUser, "1", "", tUses, ..#LIMITS, .tMessages, tLog, .tLastSeq, 0, "", 0, 0, .tState, .tCode, 0, "permissions/users"), "the call is answered")
    Do $$$AssertEquals(tState, ##class(OcuPilot.Kernel.State.Turn).#STATESTOPPED, "the boundary stops the turn")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Api.Error).#TURNSTOPPED, "with its own code")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", tUser, "", 0, tKey, 10, .tView, .tFault), "the view reads")
    Do $$$AssertEquals($IsObject(tFault), 0, "with no fault")
    Do $$$AssertEquals(tView.rowsSent, 1, "one row was written: " _ tView.%ToJSON())
    If tView.rowsSent = 1 {
        Set tRow = tView.rows.%Get(0)
        Do $$$AssertEquals(tRow.kind, "tool", "a tool row")
        Do $$$AssertEquals(tRow.name, "probe.ledger.read", "naming the tool it would have run")
        Do $$$AssertEquals(tRow.status, "stopped", "the boundary's own status")
        Do $$$AssertEquals(tRow.code, ##class(OcuPilot.Api.Error).#TURNSTOPPED, "with the stop's own code")
        Do $$$AssertEquals(tRow.requiredPairs, "", "and no pairs, because nothing read them")
        Do $$$AssertEquals(tRow.route, "permissions/users", "recorded against the screen the turn ran from")
        Do $$$AssertEquals(tRow.arguments [ ..#SECRETVALUE, 0, "and the tool's declared secret nowhere in the row's arguments: " _ tRow.arguments)
        Do $$$AssertTrue(tRow.arguments [ "[redacted]", "which reads as redacted instead")
    }
    Do $$$AssertEquals(..RowText(tKey) [ ..#SECRETVALUE, 0, "nor in any column of the stored row")
    Do $$$AssertEquals(..StepText(tKey) [ ..#SECRETVALUE, 0, "nor in any column of the stopped step written beside it: " _ ..StepText(tKey))
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, tUser, "completed", "", "", "done", 0, ..#LIMITS)
}

/// <p>Matrix row "Subject user deleted" -- a row outlives the account it names. The probe user is
/// not an account this instance holds at all, so the read is the deleted-user case by construction:
/// the row still reads and its <code>user</code> is rendered as recorded, never resolved.</p>
/// <p>It also pins the caller's own name being matched case-insensitively for the self/cross-user
/// split (AC6's "a caller always sees their own rows") while the column stays <code>%EXACT</code>
/// (AD-37).</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.State.Ledger.GuardedRow</method> answer
/// <code>""</code> for <code>user</code> -- the name is no longer rendered as recorded and this goes
/// red. For the casing: remove the <code>$ZConvert</code> self-match from
/// <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method> -- the differently-cased read becomes a
/// cross-user read and answers no row.</p>
Method TestARowOutlivesTheAccountItNames()
{
    Do $$$AssertEquals(..UserExists(..#PROBEUSER), 0, ..#PROBEUSER _ " is not an account this instance holds")
    Set tKey = ..NewTurnKey()
    Do $$$AssertStatusOK(..Record(tKey, "probe.ledger.read", {}), "a row naming it is written")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, "", 0, tKey, 10, .tView, .tFault), "the read runs")
    Do $$$AssertEquals($IsObject(tFault), 0, "and never fails over an unresolvable name")
    Do $$$AssertEquals(tView.rowsSent, 1, "answering the row")
    If tView.rowsSent = 1 Do $$$AssertEquals(tView.rows.%Get(0).user, ..#PROBEUSER, "with the name exactly as the row recorded it")

    ; An account name is case-insensitive on this instance, so a caller naming their own account in
    ; another case is still reading their own rows -- not refused for asking about somebody else.
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..#PROBEUSER, $ZConvert(..#PROBEUSER, "L"), 0, tKey, 10, .tCased, .tCasedFault), "the same caller asking in another case is read")
    Do $$$AssertEquals($IsObject(tCasedFault), 0, "with no privilege refusal")
    Do $$$AssertEquals($Select($IsObject(tCased): tCased.rowsSent, 1: -1), 1, "and still answers their own row")
}

/// <p>Matrix row "Store unreadable" -- a guarded read that answers an error status becomes one
/// <code>LEDGER.UNAVAILABLE</code> fault on the <code>unavailable</code> slug, which is the 503 the
/// route renders, and the raw status text reaches the log alone (AD-39).</p>
/// <p>Mutation (Rule 19): return the store's raw status text as the fault's <code>reason</code> in
/// <method>OcuPilot.Kernel.Audit.Ledger.Unavailable</method> -- the probe's marker reaches the
/// envelope and this goes red.</p>
Method TestAnUnreadableStoreIsOneUnavailableEnvelope()
{
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.LedgerFaultProbe", "ViewForUser", ..#PROBEUSER, "", 0, "", 10, .tView, .tFault), "the read answers rather than raising")
    Do $$$AssertEquals($IsObject(tView), 0, "with no view at all")
    Do $$$AssertTrue($IsObject(tFault), "and one fault")
    If '$IsObject(tFault) Quit
    Do $$$AssertEquals(tFault.error, ##class(OcuPilot.Api.Error).#UNAVAILABLE, "on the slug the route renders 503 from")
    Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Api.Error).#LEDGERUNAVAILABLE, "carrying the machine code")
    Do $$$AssertEquals(tFault.reason, ##class(OcuPilot.Api.Error).#REASONLEDGERUNAVAILABLE, "and its written sentence")
    Do $$$AssertEquals(tFault.%ToJSON() [ "ledgerprobestorefault", 0, "with none of the store's own text on the wire: " _ tFault.%ToJSON())
}

}
