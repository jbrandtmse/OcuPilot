/// <p>Pins Story 20.6's host test end to end against a probe production in <code>USER</code> (AD-6, AD-15, AD-35, AD-36, AD-39, AD-51,
/// AD-53, AD-62): the item's Test tab lists the request classes the echo operation takes and their fields, the same rows through the
/// port, the screen's read and the read tool, and no read instantiates a class, saves a message or changes the stored production; a
/// person's Test action and the agent's proposal, confirmed over HTTP, each send one request through the testing service and answer
/// its session, status and response as text, with the item's Messages tab listing the session's messages and one audit row of
/// OcuPilot's own that carries no field value and no answer; a target that answers nothing answers <code>done</code> with no line; a
/// target that fails the request answers <code>error</code> with the error's text; a
/// target that does not answer within the wait answers <code>waiting</code> with its session; and a virtual document is sent as its
/// text.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it compiles and <b>runs a probe production in
/// <code>USER</code></b> with <class>OcuPilot.Test.ProductionProbe</class> and <class>OcuPilot.Test.InteropTestFixture</class> and
/// removes everything it made after the last test. It borrows the transport helpers of <class>OcuPilot.Test.InteropItemControl</class>.
/// One class per run.</p>
Class OcuPilot.Test.InteropHostTest Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropTestFixture";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter READ = "OcuPilot.Test.InteropHostRead";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.InteropItemTestTab";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropItemTestSend";

Parameter SCREEN = "/screens/interop.itemtest";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

/// <p>The probe's plain operation, which takes <code>Ens.Request</code> and answers nothing.</p>
Parameter PLAINNAME = "OcuPilotProbeOp";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropHostTest compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "Create")
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Settle")
    Set tRemove = $ClassMethod(..#FIXTURE, "Remove")
    If $$$ISOK(tSC) Set tSC = tRemove
    Set tProbe = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = tProbe
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropHostTest left probe state in USER")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ..Clear()
    Quit $ClassMethod(..#PROBE, "Settle")
}

Method OnAfterOneTest() As %Status
{
    Do ..Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is left stopped")
    Quit $$$OK
}

ClassMethod Clear()
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $ClassMethod(..#FIXTURE, "ClearMarker")
}

/// <p>The item <var>pName</var> of the probe production in the spelling the reads take, and in the composite one the routes take.</p>
ClassMethod ItemId(pName As %String) As %String
{
    Quit ..#PRODUCTION _ "||" _ pName
}

ClassMethod RouteId(pName As %String) As %String
{
    Quit ..#PRODUCTION _ $Char(1) _ pName
}

/// <p>The probe production running with the testing service registered.</p>
ClassMethod Arm() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "Start")
}

/// <p>A person's Test action on <var>pName</var>, sending request class <var>pClass</var> with the fields <var>pFields</var>, as
/// <code>status code</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod Send(pName As %String, pClass As %String, pFields As %DynamicObject, Output pAnswer) As %String
{
    Set tBody = {"action": "test", "values": {}}
    Do tBody.%Set("id", ..RouteId(pName), "string")
    Do tBody.values.%Set("requestClass", pClass, "string")
    Do tBody.values.%Set("fields", pFields.%ToJSON(), "string")
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#SCREEN _ "/action", tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>All that proposal <var>pKey</var> and the steps and reply of turn <var>pTurn</var> keep, as one text: the proposal row's
/// columns and streams, each step's text columns and the turn's reply and citations.</p>
ClassMethod StoredText(pKey As %String, pTurn As %String) As %String
{
    Set tText = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ProposalKey) = ?", pKey)
    If tRS.%Next() {
        Set tProposal = ##class(OcuPilot.Kernel.State.Propose).%OpenId(tRS.%GetData(1))
        If $IsObject(tProposal) {
            For tName = "Arguments", "Payload", "Diff" {
                Set tStream = $Property(tProposal, tName)
                Do tStream.Rewind()
                Set tText = tText _ "|" _ tStream.Read(3000000)
            }
            For tName = "Rationale", "ExpectedImpact", "Reverse", "ReadBack", "Impact", "TargetName", "TargetRef" {
                Set tText = tText _ "|" _ $Property(tProposal, tName)
            }
        }
    }
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Summary, Text, Target, Arguments, Result, Reason FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = ?", pTurn)
    While tRS.%Next() {
        For tI = 1:1:6 Set tText = tText _ "|" _ tRS.%GetData(tI)
    }
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Reply, Citations FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = ?", pTurn)
    While tRS.%Next() {
        For tI = 1:1:2 Set tText = tText _ "|" _ tRS.%GetData(tI)
    }
    Quit tText
}

/// <p>The arguments of the agent's call.</p>
ClassMethod ArgsFor(pName As %String, pClass As %String, pFields As %DynamicObject) As %DynamicObject
{
    Set tArgs = $ClassMethod(..#CONTROL, "ArgsFor", pName)
    Do tArgs.%Set("RequestClass", pClass, "string")
    Do tArgs.%Set("Fields", pFields)
    Quit tArgs
}

/// <p>The rows of the Test tab for <var>pName</var> through the port.</p>
ClassMethod Rows(pName As %String, Output pHttp As %Integer, Output pFault) As %DynamicArray
{
    Kill tQuery
    Set tQuery("item") = ..ItemId(pName)
    Quit $ClassMethod(..#READ, "Rows", "ItemTest", .tQuery, .pHttp, .pFault)
}

/// <p>Each row of <var>pClass</var> in <var>pRows</var> as <code>Field:Required:MaxLength:Values:Secret</code>, joined by <code>;</code>.</p>
ClassMethod Signature(pRows As %DynamicArray, pClass As %String) As %String
{
    Set tText = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.RequestClass '= pClass Continue
        Set tValues = ""
        Set tValueIterator = tRow.Values.%GetIterator()
        While tValueIterator.%GetNext(.tAt, .tValue) {
            Set tValues = tValues _ $Select(tValues = "": "", 1: "/") _ tValue
        }
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ tRow.Field _ ":" _ tRow.Required _ ":" _ tRow.%Get("MaxLength") _ ":" _ tValues _ ":" _ tRow.Secret
    }
    Quit tText
}

/// <p>The distinct request classes of <var>pRows</var>, in the order the rows list them, joined by <code>,</code>.</p>
ClassMethod Classes(pRows As %DynamicArray) As %String
{
    Set tText = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $ListFind($ListFromString(tText, ","), tRow.RequestClass) = 0 Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.RequestClass
    }
    Quit tText
}

/// <p>The echo item's rows are the ones its message map and <code>OnMessage</code> name -- the vendor's own request classes first, in
/// name order, then the subclasses -- with every field the request class has, an embedded object's under a dotted path, a required
/// field, a closed list of values, a length bound and a credential-named field marked secret; a virtual document is one
/// <code>content</code> field; a business service gives none; an unknown item is 404 and a read with no item 400; and the screen's
/// read and the read tool answer the rows the port does.</p>
/// <p>Mutation (Rule 19): lift the row cap from <method>OcuPilot.Port.InteropPort.GatherTestFields</method> -- the cap leg goes red;
/// drop the empty-field row of a class with no settable field from the same method -- the plain operation's leg goes red;
/// make <method>OcuPilot.Port.InteropPort.CollectFieldsHere</method> skip a serial property -- the
/// <code>Address</code> rows go red; make <method>OcuPilot.Port.InteropPort.RequestClassesHere</method> list no subclass -- the
/// order leg goes red; make <method>OcuPilot.Port.InteropPort.TestFieldRow</method> answer <code>Secret</code> false -- the
/// <code>Password</code> row goes red.</p>
Method TestTheTabRowsAgreeThroughThePortTheScreenAndTheReadTool()
{
    Set tRows = ..Rows($Parameter(..#FIXTURE, "ECHONAME"), .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the port lists the echo item's fields: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    If '$IsObject(tRows) Quit
    Set tRequest = $Parameter(..#FIXTURE, "REQUESTCLASS")
    Do $$$AssertEquals(..Signature(tRows, tRequest), "Text:1:50::0;Count:0:::0;Kind:0:50:alpha/beta/gamma:0;Password:0:50::1;Address.Street:0:50::0;Address.City:0:30::0", "the request class's fields, in its order, with their bounds, values and secrecy")
    Do $$$AssertEquals(..Signature(tRows, "Ens.StringRequest"), "StringValue:0:::0", "the vendor's string request has its one field")
    Set tDocument = $ClassMethod(..#READ, "RowWhere", tRows, "RequestClass", $Parameter(..#FIXTURE, "DOCUMENTCLASS"))
    Do $$$AssertTrue($IsObject(tDocument) && (tDocument.Kind _ "|" _ tDocument.Field _ "|" _ tDocument.Required = "document|content|1"), "a virtual document is one required content field")
    Do $$$AssertEquals(..Classes(tRows), "Ens.StringRequest,EnsLib.HL7.Message," _ tRequest _ "," _ $Parameter(..#FIXTURE, "SUBCLASS"), "the item's own classes come first, in name order, then a subclass of them")
    Do $$$AssertEquals(..Signature(tRows, $Parameter(..#FIXTURE, "SUBCLASS")), ..Signature(tRows, tRequest), "and the subclass lists the fields it inherits")
    Set tFirst = $ClassMethod(..#READ, "RowWhere", tRows, "RequestClass", tRequest)
    Do $$$AssertEquals(tFirst.Production _ "|" _ tFirst.Item _ "|" _ tFirst.Kind, ..#PRODUCTION _ "|" _ ..ItemId($Parameter(..#FIXTURE, "ECHONAME")) _ "|object", "a row names its production and item")
    Set tPlain = ..Rows(..#PLAINNAME, .tPlainHttp)
    Set tNoField = $ClassMethod(..#READ, "RowWhere", tPlain, "RequestClass", "Ens.Request")
    Do $$$AssertTrue($IsObject(tNoField) && (tPlainHttp = 200), "the plain operation lists the request class that has no settable field")
    If $IsObject(tNoField) Do $$$AssertEquals(tNoField.Field _ "|" _ tNoField.Kind _ "|" _ tNoField.Secret, "|object|0", "as one row with an empty field")
    Set tService = ..Rows($Parameter(..#PROBE, "SVCNAME"), .tServiceHttp)
    Do $$$AssertEquals(tServiceHttp _ "|" _ $Select($IsObject(tService): tService.%Size(), 1: -1), "200|0", "a business service gives no row")
    Do ..Rows("NoSuchItem", .tMissingHttp)
    Do $$$AssertEquals(tMissingHttp, 404, "an unknown item is 404")
    Kill tQuery
    Do $ClassMethod(..#READ, "Rows", "ItemTest", .tQuery, .tNoCriterionHttp, .tNoCriterionFault)
    Do $$$AssertEquals(tNoCriterionHttp _ " " _ tNoCriterionFault.code, "400 PORT.VALIDATION", "a read with no item is 400")
    Kill tCap
    Set tCap("namespace") = ..#NAMESPACE
    Set tCap("item") = ..ItemId($Parameter(..#FIXTURE, "ECHONAME"))
    Set tCap("maxRows") = 3
    Set tSC = $ClassMethod(..#PORT, "Invoke", "ItemTest", "LIST", .tCap, "", .tCapped, .tCapHttp, .tCapFault)
    Do $$$AssertEquals(tCapHttp _ "|" _ $Select($IsObject(tCapped): tCapped.%Size(), 1: -1), "200|3", "a row cap of three gives three rows of the " _ tRows.%Size())
    Kill tCriteria
    Set tCriteria("item") = ..ItemId($Parameter(..#FIXTURE, "ECHONAME"))
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 1000, .tAnswer, .tScreenHttp, .tScreenFault, .tCriteria)
    Do $$$AssertEquals(+$Get(tScreenHttp), 200, "the screen's read answers")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("interop.itemtest.read", .tTool)
    Set tToolHttp = 0
    If $IsObject($Get(tTool)) Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"item": (tCriteria("item"))}, 1000, .tResult, .tToolHttp, .tToolFault)
    Do $$$AssertEquals(+$Get(tToolHttp), 200, "the read tool answers")
    If '$IsObject($Get(tAnswer)) || '$IsObject($Get(tResult)) Quit
    Set tDigest = $ClassMethod(..#READ, "Digest", $ClassMethod(..#READ, "Projected", tRows, ..#DESCRIPTOR))
    Do $$$AssertEquals($ClassMethod(..#READ, "Digest", tAnswer.rows), tDigest, "the screen's rows are the port's, in the fields it declares")
    Do $$$AssertEquals($ClassMethod(..#READ, "Digest", tResult.rows), tDigest, "and so are the tool's")
}

/// <p>AC9: the tab's read, and the composed read of a test with and without the action, create no request object (the request
/// class counts its creations), save no request or message, and leave the stored production as it was.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ClassFieldsHere</method> create an instance of the class it lists --
/// the marker leg goes red.</p>
Method TestNoReadInstantiatesARequestClassOrChangesWhatIsStored()
{
    Set tName = $Parameter(..#FIXTURE, "ECHONAME")
    Set tItems = $ClassMethod(..#CONTROL, "Items")
    Set tCounts = $ClassMethod(..#FIXTURE, "Counts")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Marker"), 0, "no request has been created yet")
    Do ..Rows(tName, .tHttp)
    Do $$$AssertEquals(tHttp, 200, "the tab's read answers")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..ItemId(tName)
    Set tQuery("requestClass") = $Parameter(..#FIXTURE, "REQUESTCLASS")
    Set tQuery("fields") = "{""Text"":""x""}"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "ItemTest", "TESTTARGET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the composed read answers: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Set tQuery("action") = "SENDTEST"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "ItemTest", "TESTTARGET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 INTEROP.PRODUCTION.NOTRUNNING", "composed for the send it is refused before it reads a field")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Marker"), 0, "no read created a request")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts"), tCounts, "none saved a request or added a message")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), tItems, "and the stored production's items are as they were")
}

/// <p>The echo item sent <var>pClass</var> with <var>pFields</var> by the person's action: the answer's output, the session it names
/// and the audit text, after the production is armed.</p>
Method Through(pFields As %DynamicObject, Output pOutput, Output pSession As %String, Output pData As %String, Output pText As %String)
{
    Set tName = $Parameter(..#FIXTURE, "ECHONAME")
    Do $$$AssertStatusOK(..Arm(), "the probe production runs with the testing service registered")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set pText = ..Send(tName, $Parameter(..#FIXTURE, "REQUESTCLASS"), pFields, .tAnswer)
    Do $$$AssertEquals(pText, "200 ", "the person's Test answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set pOutput = $Select($IsObject(tAnswer): tAnswer.%Get("output"), 1: "")
    Set pSession = $Select($IsObject(pOutput): pOutput.sessionId, 1: "")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.scope _ "|" _ $Translate(tAnswer.target.id, $Char(1), "~"), 1: ""), "updated|production-item|USER|" _ ..#PRODUCTION _ "~" _ tName, "publishing the change event for the item")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """verb"":""test""", .pData, """sessionId"":""" _ pSession _ """"), 1, "one audit row of OcuPilot's own records the test")
}

/// <p>AC2, AC8: a person's Test sends the request the dialog built through the testing service and answers, as text, its session,
/// its status and the response's fields; the request was created and saved once, the testing service's answer node is gone, the
/// item's Messages tab lists the session's messages, and the audit row names the class and the session and carries no field value
/// and no answer.</p>
/// <p>Mutation (Rule 19): skip the response read in <method>OcuPilot.Port.InteropPort.AwaitTestHere</method> -- the lines leg goes red;
/// drop the <code>AuditRuntime</code> call from <method>OcuPilot.Port.InteropPort.PerformTest</method> -- the audit leg goes red; drop
/// the <code>Kill</code> of the answer node -- the node leg goes red.</p>
Method TestThePersonsSendShowsTheResponseAndItsSession()
{
    Set tFields = {"Text": "hello <b>x</b>", "Count": "5", "Kind": "beta", "Address.City": "Berlin"}
    Set tSavedBefore = $Piece($ClassMethod(..#FIXTURE, "Counts"), "/", 1)
    Do ..Through(tFields, .tOutput, .tSession, .tData, .tText)
    If '$IsObject(tOutput) Quit
    Do $$$AssertEquals(tOutput.status _ "|" _ tOutput.responseClass _ "|" _ tOutput.errors, "done|Ens.StringResponse|0", "the test is done and names the response's class")
    Do $$$AssertEquals(tOutput.lines.%ToJSON(), "[""StringValue: echo:hello <b>x</b>""]", "the response's field is one line of text, markup and all")
    Do $$$AssertTrue(tSession > 0, "with the session the testing service gave it: " _ tSession)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Marker"), 1, "one request was created")
    Do $$$AssertEquals($Piece($ClassMethod(..#FIXTURE, "Counts"), "/", 1) - tSavedBefore, 1, "and one saved: " _ tSavedBefore _ " then " _ $ClassMethod(..#FIXTURE, "Counts"))
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "NodesGone"), "the testing service's answer node is gone")
    Kill tQuery
    Set tQuery("item") = ..ItemId($Parameter(..#FIXTURE, "ECHONAME"))
    Set tMessages = $ClassMethod(..#READ, "Rows", "ItemMessages", .tQuery, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject(tMessages) && ($ClassMethod(..#READ, "CountWhere", tMessages, "SessionId", tSession) > 0), "the item's Messages tab lists the session's messages")
    Do $$$AssertTrue((tData [ $Parameter(..#FIXTURE, "REQUESTCLASS")) && (tData '[ "hello") && (tData '[ "Berlin") && (tData '[ "echo:") && (tData '[ """lines"""), "the audit row names the class and carries no value and no answer: " _ tData)
}

/// <p>AC2, AC8: the agent's call, minted for the HTTP account and confirmed over HTTP, shows a card with the request class and the
/// fields and the sending consequence, answers one envelope whose output is the same answer a person's Test gets, is ledgered once
/// and marked, and leaves the answer in no stored proposal, no ledger row and no audit row.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropItemTestSend.WriteOutput</method> answer <code>""</code> -- the
/// output leg goes red; add <code>lines</code> to the audit effects in <method>OcuPilot.Port.InteropPort.PerformTest</method> -- the
/// audit leg goes red; have <method>OcuPilot.Kernel.Proposal.Confirm</method> record the confirmed output as the proposal's
/// read-back -- the stored-text leg goes red.</p>
Method TestTheAgentsSendConfirmsOverHttp()
{
    Set tName = $Parameter(..#FIXTURE, "ECHONAME")
    Do $$$AssertStatusOK(..Arm(), "the probe production runs with the testing service registered")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tFields = {"Text": "agent text", "Count": "7"}
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, ..ArgsFor(tName, $Parameter(..#FIXTURE, "REQUESTCLASS"), tFields), ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tMintHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the call mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%Get(0).field _ "|" _ tProposal.changed.%Get(1).field _ "|" _ tProposal.changed.%Size(), "RequestClass|Fields|2", "its card shows the request class and the fields")
    Do $$$AssertEquals(tProposal.changed.%Get(1).after, "{""Count"":""7"",""Text"":""agent text""}", "the fields as canonical text")
    Do $$$AssertEquals(tProposal.target.type _ "|" _ $Translate(tProposal.target.id, $Char(1), "~"), "production-item|" _ ..#PRODUCTION _ "~" _ tName, "the target is the item, by its composite id")
    Set tId = tProposal.proposalId
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tId, "Destructive") + 0), "INTEROP.TEST.SENDS|0", "it states the sending consequence and is not destructive")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Marker"), 0, "the mint created no request")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the confirm answers 200: " _ $Extract($Get(tRaw), 1, 300))
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertTrue($Length(tRaw, "}{") = 1, "exactly one envelope")
    Do $$$AssertEquals(tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action, "1|updated", "marked and updated")
    Set tOutput = tAnswer.output
    Do $$$AssertEquals($Select($IsObject(tOutput): tOutput.status _ "|" _ tOutput.lines.%ToJSON() _ "|" _ tOutput.errors, 1: ""), "done|[""StringValue: echo:agent text""]|0", "the output is the response as text")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Marker"), 1, "one request was created, by the confirm")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, "interop.itemtest.send"), 1, "the confirmed write is in the ledger once")
    Set tRows = ##class(%SQL.Statement).%ExecDirect(, "SELECT Arguments, Fields, Target, Code, Status FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", tTurn)
    Set tLedger = ""
    While tRows.%Next() {
        Set tLedger = tLedger _ tRows.%GetData(1) _ "|" _ tRows.%GetData(2) _ "|" _ tRows.%GetData(3) _ "|" _ tRows.%GetData(4) _ "|" _ tRows.%GetData(5) _ ";"
    }
    Do $$$AssertTrue((tLedger '= "") && (tLedger '[ "echo:") && (tLedger '[ "StringValue"), "the ledger row carries no answer: " _ tLedger)
    Set tStored = ..StoredText(tId, tTurn)
    Do $$$AssertTrue((tStored [ "agent text") && (tStored '[ "echo:") && (tStored '[ "StringValue"), "the confirmed proposal and the turn's steps, read back, hold the request and no answer")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """verb"":""test""", .tData, """requestClass"":""" _ $Parameter(..#FIXTURE, "REQUESTCLASS") _ """"), 1, "one audit row records the test")
    Do $$$AssertTrue((tData '[ "agent text") && (tData '[ "echo:") && (tData '[ """lines"""), "which carries no value and no answer: " _ tData)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC2: a target that answers nothing -- the probe's plain operation takes <code>Ens.Request</code> and returns no response --
/// is <code>done</code> with no line, no response class and no error.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.CollectResponseHere</method> raise for a missing response -- this
/// goes red.</p>
Method TestATargetThatAnswersNothingAnswersDoneWithNoLine()
{
    Do $$$AssertStatusOK(..Arm(), "the probe production runs with the testing service registered")
    Set tText = ..Send(..#PLAINNAME, "Ens.Request", {}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the Test answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tOutput = $Select($IsObject(tAnswer): tAnswer.%Get("output"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tOutput): tOutput.status _ "|" _ tOutput.responseClass _ "|" _ tOutput.lines.%Size() _ "|" _ tOutput.errors, 1: ""), "done||0|0", "done, with no response, no line and no error")
}

/// <p>AC1, AC2: a request class the Test tab lists as a subclass of one the item names is one the send takes: the gate accepts what
/// the tab offers, the subclass's inherited fields are set, and the operation answers it as it answers the class it descends from.</p>
/// <p>Mutation (Rule 19): end <method>OcuPilot.Port.InteropPort.IsRequestClassHere</method> with a refusal of every class the host does
/// not name itself -- this goes red with 409 <code>INTEROP.TEST.REQUESTTYPE</code>.</p>
Method TestASubclassTheTabListsIsSentLikeTheClassItDescendsFrom()
{
    Do $$$AssertStatusOK(..Arm(), "the probe production runs with the testing service registered")
    Set tText = ..Send($Parameter(..#FIXTURE, "ECHONAME"), $Parameter(..#FIXTURE, "SUBCLASS"), {"Text": "sub text"}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the Test answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tOutput = $Select($IsObject(tAnswer): tAnswer.%Get("output"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tOutput): tOutput.status _ "|" _ tOutput.lines.%ToJSON(), 1: ""), "done|[""StringValue: echo:sub text""]", "the subclass is sent and answered")
}

/// <p>AC2: a target that fails the request -- the probe's echo operation returns an error for the text <code>fail</code> -- is
/// <code>error</code> with the error's text as the line and the errors flag set, and the answer node is gone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.AwaitTestHere</method> skip its <code>Error</code> branch -- this goes
/// red and nothing else in the class does.</p>
Method TestAFailingTargetAnswersErrorWithItsText()
{
    Do $$$AssertStatusOK(..Arm(), "the probe production runs with the testing service registered")
    Set tText = ..Send($Parameter(..#FIXTURE, "ECHONAME"), $Parameter(..#FIXTURE, "REQUESTCLASS"), {"Text": "fail"}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the Test answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tOutput = $Select($IsObject(tAnswer): tAnswer.%Get("output"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tOutput): tOutput.status _ "|" _ tOutput.errors, 1: ""), "error|1", "the test is an error")
    Do $$$AssertTrue($IsObject(tOutput) && (tOutput.lines.%Size() = 1) && (tOutput.lines.%Get(0) [ "echo failed"), "the error's text is the line: " _ $Select($IsObject(tOutput): tOutput.lines.%ToJSON(), 1: ""))
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "NodesGone"), "the answer node is gone")
}

/// <p>AC4: a target that does not answer within the wait answers <code>waiting</code> with its session, in about the wait and not the
/// target's time. The probe operation hangs five seconds and the wait is one, through the seam; the answer node is left for the
/// vendor.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.AwaitTestHere</method> ignore its deadline -- the elapsed leg goes
/// red and the answer is <code>done</code>.</p>
Method TestASlowTargetAnswersWaitingWithinTheCap()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetHang", 5), "the plain operation hangs five seconds on a message")
    Do $$$AssertStatusOK(..Arm(), "the probe production runs with the testing service registered")
    Do ..HoldPairs()
    Do $ClassMethod(..#SEAM, "ShortenTestWait", 1)
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..ItemId(..#PLAINNAME)
    Set tQuery("requestClass") = "Ens.Request"
    Set tQuery("fields") = "{}"
    Set tStart = $ZHorolog
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "ItemTest", "SENDTEST", .tQuery, "", .tResult, .tHttp, .tFault)
    Set tTook = $ZHorolog - tStart
    Do $$$AssertEquals(tHttp, 200, "the send answers: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.status _ "|" _ tResult.lines.%Size() _ "|" _ tResult.errors, "waiting|0|0", "it answers waiting, with no line")
    Do $$$AssertTrue(tResult.sessionId > 0, "and its session: " _ tResult.sessionId)
    Do $$$AssertTrue((tTook >= 1) && (tTook < 4.5), "within about the wait, not the target's five seconds: " _ $FNumber(tTook, "", 2) _ " s")
}

/// <p>AC2: a virtual document is sent as its text -- the dialog's one <code>content</code> field -- and the echo operation answers the
/// sending application it read from it; a text that is not a message of the class is 422 <code>INTEROP.TEST.REQUEST</code> on the
/// field with nothing saved or sent.</p>
/// <p>Mutation (Rule 19): build a document with <code>%New</code> in <method>OcuPilot.Port.InteropPort.BuildTestRequestHere</method>
/// -- the echo leg goes red.</p>
Method TestADocumentRequestIsSentAsItsText()
{
    Do $$$AssertStatusOK(..Arm(), "the probe production runs with the testing service registered")
    Set tName = $Parameter(..#FIXTURE, "ECHONAME")
    Set tClass = $Parameter(..#FIXTURE, "DOCUMENTCLASS")
    Set tText = ..Send(tName, tClass, {"content": ($Parameter(..#FIXTURE, "DOCUMENTTEXT"))}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the Test answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tOutput = $Select($IsObject(tAnswer): tAnswer.%Get("output"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tOutput): tOutput.status _ "|" _ tOutput.lines.%ToJSON(), 1: ""), "done|[""StringValue: echo:OCUSENDER""]", "the operation read the message's sending application: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tCounts = $ClassMethod(..#FIXTURE, "Counts")
    Set tText = ..Send(tName, tClass, {"content": "this is not a message"}, .tRefused)
    Do $$$AssertEquals(tText, "422 INTEROP.TEST.REQUEST", "text that is not a message is refused on the field: " _ $Select($IsObject(tRefused): tRefused.%ToJSON(), 1: ""))
    Do $$$AssertEquals($Select($IsObject(tRefused): tRefused.detail.violations.%Get(0).field, 1: ""), "content", "naming content")
}

/// <p>The probe's reply operation's answer to a string request carrying <var>pText</var>: the test output, from the person's route.</p>
Method ReplyTo(pText As %String, Output pOutput)
{
    Set tText = ..Send($Parameter(..#FIXTURE, "REPLYNAME"), "Ens.StringRequest", {"StringValue": (pText)}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the Test answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set pOutput = $Select($IsObject(tAnswer): tAnswer.%Get("output"), 1: "")
}

/// <p>AC8, AD-35: a response field named like a credential, or inside an embedded object named like one, reads blank in the lines the
/// person and the card show, while its neighbours show their values and the answer's class is named.</p>
/// <p>Mutation (Rule 19): drop the blanking of a credential-named value from <method>OcuPilot.Port.InteropPort.TestLines</method> --
/// this goes red and the answer carries the credential.</p>
Method TestAResponseFieldNamedLikeACredentialReadsBlank()
{
    Do $$$AssertStatusOK(..Arm(), "the probe production runs with the testing service registered")
    Do ..ReplyTo("hi", .tOutput)
    If '$IsObject(tOutput) Quit
    Do $$$AssertEquals(tOutput.responseClass, $Parameter(..#FIXTURE, "REPLYCLASS"), "the response's class is named")
    Do $$$AssertEquals(tOutput.lines.%ToJSON(), "[""Text: reply:hi"",""Password: "",""Credential.Value: ""]", "the credential-named fields read blank and the other shows its value")
    Do $$$AssertTrue(tOutput.%ToJSON() '[ "s3cret", "and no credential is anywhere in the answer")
}

/// <p>AC8: a response value longer than a result shows is cut at the bound and marked, so one field cannot fill the card.</p>
/// <p>Mutation (Rule 19): drop the cut of a value in <method>OcuPilot.Port.InteropPort.TestLines</method> -- this goes red.</p>
Method TestALongResponseValueIsCutAndMarked()
{
    Do $$$AssertStatusOK(..Arm(), "the probe production runs with the testing service registered")
    Do ..ReplyTo("long", .tOutput)
    If '$IsObject(tOutput) Quit
    Set tLine = tOutput.lines.%Get(0)
    Set tCut = $Parameter(..#PORT, "TESTCUT")
    Do $$$AssertEquals($Length(tLine), $Length("Text: ") + $Parameter(..#PORT, "TESTVALUEMAX") + $Length(tCut), "the value is cut at the bound: " _ $Length(tLine))
    Do $$$AssertEquals($Extract(tLine, $Length(tLine) - $Length(tCut) + 1, *), tCut, "and ends with the mark")
}

/// <p>AC2: a response that is a virtual document shows as its own text, one line for each segment, and names its class.</p>
/// <p>Mutation (Rule 19): drop the document branch of <method>OcuPilot.Port.InteropPort.CollectResponseHere</method> -- this goes red.</p>
Method TestADocumentResponseShowsAsItsText()
{
    Do $$$AssertStatusOK(..Arm(), "the probe production runs with the testing service registered")
    Set tText = ..Send($Parameter(..#FIXTURE, "REPLYNAME"), $Parameter(..#FIXTURE, "DOCUMENTCLASS"), {"content": ($Parameter(..#FIXTURE, "DOCUMENTTEXT"))}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the Test answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tOutput = $Select($IsObject(tAnswer): tAnswer.%Get("output"), 1: "")
    If '$IsObject(tOutput) Quit
    Do $$$AssertEquals(tOutput.responseClass _ "|" _ tOutput.lines.%Size() _ "|" _ tOutput.lines.%Get(0), $Parameter(..#FIXTURE, "DOCUMENTCLASS") _ "|1|" _ $Parameter(..#FIXTURE, "REPLYDOCUMENT"), "the document's text is the line: " _ tOutput.%ToJSON())
}

/// <p>Hold the pairs a send needs in process, for the legs that call the port through its seam.</p>
ClassMethod HoldPairs()
{
    Set tHeld = $ListBuild($ListBuild("%Ens_Portal", "USE"), $ListBuild("%Ens_TestingService", "USE"))
    Do ##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase(..#NAMESPACE, .tResource, .tReadOnly)
    Set tHeld = tHeld _ $ListBuild($ListBuild(tResource, "READ"), $ListBuild(tResource, "WRITE"))
    For tI = 1:1:$ListLength(tHeld) {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List($List(tHeld, tI), 1), $List($List(tHeld, tI), 2))
    }
}

}
