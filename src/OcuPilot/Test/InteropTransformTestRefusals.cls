/// <p>Pins Story 20.27's data transformation test at its edges against the probe transformations of
/// <class>OcuPilot.Test.InteropTransformFixture</class> in <code>USER</code> (AD-8, AD-10, AD-15, AD-39, AD-62): input that does not
/// parse, a transformation that fails, one whose fault escapes <code>Transform</code>, one that leaves no target and one that writes to
/// the device each answer 200 with their status, and nothing they wrote reaches the log; a transformation that saves its target leaves
/// its extent as it was; and each refusal -- a Record Map batch or a stream for source or target, a class that is not listed, an empty
/// or too long message, OcuPilot's own name, a namespace that runs no interoperability -- is answered by its code from the person's
/// Test and from the agent's call, before any parse or <code>Transform</code>, leaving the run count and every extent as they were.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs transformations in
/// <code>USER</code></b>. No probe production is used. It borrows the helpers of <class>OcuPilot.Test.InteropTransformTest</class>.
/// One class per run.</p>
Class OcuPilot.Test.InteropTransformTestRefusals Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropTransformFixture";

Parameter BASE = "OcuPilot.Test.InteropTransformTest";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropTransformTest";

Parameter NAMESPACE = "USER";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropTransformTestRefusals compiles and runs probe data transformations in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#FIXTURE, "Create")
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "Remove")
}

Method OnBeforeOneTest() As %Status
{
    Do ..Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

ClassMethod Clear()
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Disarm")
}

/// <p>A person's Test on the XML transformation with the value <var>pValue</var> as the message, the output of the answer as
/// <code>status|errors|console|lines</code>, and <code>status code</code> in <var>pText</var>.</p>
ClassMethod Run(pName As %String, pContent As %String, Output pText As %String) As %String
{
    Set pText = $ClassMethod(..#BASE, "Act", pName _ ".cls", pContent, .tAnswer)
    If '$IsObject(tAnswer) || '$IsObject(tAnswer.%Get("output")) Quit ""
    Set tOutput = tAnswer.output
    Quit tOutput.status _ "|" _ tOutput.errors _ "|" _ tOutput.console.%ToJSON() _ "|" _ tOutput.lines.%ToJSON()
}

/// <p>AC4: each outcome of a run is answered 200 in the one JSON envelope with its status and the errors flag: input that is not XML
/// or that names another root is <code>input</code> with the vendor's text, text no HL7 or X12 parser takes is <code>input</code>
/// with no line, a status the transformation sets and a fault it does not trap are <code>transform</code>, a transformation that
/// leaves no target is <code>output</code>, and a line the transformation writes to the device is the console, not the answer's
/// body.</p>
/// <p>Mutation (Rule 19): remove the trap around <code>Transform</code> in <method>OcuPilot.Port.InteropPort.RunTransformHere</method>
/// -- the escaped fault leg answers 500 and goes red; close the capture before <code>Transform</code> in
/// <method>OcuPilot.Port.InteropPort.PerformTransformTest</method> -- the console leg goes red.</p>
Method TestEachOutcomeIsAnswered200WithItsStatus()
{
    Set tXml = $Parameter(..#FIXTURE, "XML")
    Set tRuns = $ClassMethod(..#FIXTURE, "Runs")
    Set tShape = ..Run(tXml, "hello", .tText)
    Do $$$AssertEquals(tText _ " " _ tShape, "200  input|1|[]|[""ERROR #5001: Not XML Format""]", "text that is not XML is an input error")
    Set tShape = ..Run(tXml, "<b>x</b>", .tText)
    Do $$$AssertTrue((tText = "200 ") && ($Piece(tShape, "|", 1, 3) = "input|1|[]") && ($Piece(tShape, "|", 4, *) [ "<b>x</b>"), "XML of another root is an input error that echoes the text: " _ tShape)
    Set tShape = ..Run($Parameter(..#FIXTURE, "HL7"), "no segment here", .tText)
    Do $$$AssertEquals(tText _ " " _ tShape, "200  input|1|[]|[]", "text the HL7 parser takes for no message is an input error with no line")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Runs") - tRuns, 0, "no input error ran a transformation")
    Set tShape = ..Run(tXml, $ClassMethod(..#FIXTURE, "Message", "fail"), .tText)
    Do $$$AssertTrue((tText = "200 ") && ($Piece(tShape, "|", 1, 3) = "transform|1|[]") && ($Piece(tShape, "|", 4, *) [ "probe-fail"), "an error status is a transform failure with its text: " _ tShape)
    Set tShape = ..Run($Parameter(..#FIXTURE, "RAW"), $ClassMethod(..#FIXTURE, "Message", "x"), .tText)
    Do $$$AssertTrue((tText = "200 ") && ($Piece(tShape, "|", 1, 3) = "transform|1|[]") && ($Piece(tShape, "|", 4, *) [ "<DIVIDE>"), "a fault that escapes Transform is a transform failure, trapped: " _ tShape)
    Set tShape = ..Run(tXml, $ClassMethod(..#FIXTURE, "Message", "none"), .tText)
    Do $$$AssertEquals(tText _ " " _ tShape, "200  output|1|[]|[""No object created""]", "a transformation that leaves no target is an output failure")
    Set tShape = ..Run(tXml, $ClassMethod(..#FIXTURE, "Message", "write"), .tText)
    Do $$$AssertEquals(tText _ " " _ tShape, "200  done|0|[""" _ $Parameter(..#FIXTURE, "DEVICELINE") _ """]|[""<StringResponse>"",""  <StringValue>out:write</StringValue>"",""</StringResponse>""]", "a line written to the device is the console, and the answer stays JSON")
}

/// <p>AC2, AC4: a transformation that saves its target answers <code>done</code> and the string response extent holds the count it had
/// before the run.</p>
/// <p>Mutation (Rule 19): skip the cleanup in <method>OcuPilot.Port.InteropPort.RunTransformHere</method> -- the extent goes red.</p>
Method TestAStoredTargetIsDeletedBeforeTheAnswer()
{
    Set tCounts = $ClassMethod(..#FIXTURE, "Counts")
    Set tShape = ..Run($Parameter(..#FIXTURE, "XML"), $ClassMethod(..#FIXTURE, "Message", "save"), .tText)
    Do $$$AssertEquals(tText _ " " _ $Piece(tShape, "|", 1, 2), "200  done|0", "the run is done")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts"), tCounts, "and the response it saved is gone")
}

/// <p>The pairs the port's gate evaluates, held through the test gate for the probe namespace.</p>
ClassMethod Hold()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Code", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_DTLTest", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "WRITE")
}

/// <p>AC4: no error text, console line or message reaches the log, whatever the outcome: the port, driven in process, logs nothing for
/// input that does not parse, a failing transformation, a fault, no target or a line written to the device.</p>
/// <p>Mutation (Rule 19): hand <method>OcuPilot.Port.InteropPort.LogFault</method> the error lines in
/// <method>OcuPilot.Port.InteropPort.PerformTransformTest</method> -- this goes red.</p>
Method TestNothingTheRunWroteReachesTheLog()
{
    Do ..Hold()
    Do $ClassMethod(..#SEAM, "Arm")
    Set tCases = $ListBuild($ListBuild("XML", "hello"), $ListBuild("XML", $ClassMethod(..#FIXTURE, "Message", "fail")), $ListBuild("RAW", $ClassMethod(..#FIXTURE, "Message", "x")), $ListBuild("XML", $ClassMethod(..#FIXTURE, "Message", "none")), $ListBuild("XML", $ClassMethod(..#FIXTURE, "Message", "write")))
    For tI = 1:1:$ListLength(tCases) {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = $Parameter(..#FIXTURE, $List($List(tCases, tI), 1)) _ ".cls"
        Set tQuery("content") = $List($List(tCases, tI), 2)
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "Transforms", "TRANSFORMTEST", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp), 200, "case " _ tI _ ": the run is answered 200")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged"), 0, "and the port logged nothing")
}

/// <p>The fault of a refusal as <code>http code</code>.</p>
ClassMethod FaultText(pHttp As %Integer, pFault) As %String
{
    Quit +$Get(pHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>AC5: each refusal is answered by its code from the person's Test and from the agent's call, before any parse or
/// <code>Transform</code>: a source or target that is neither a document nor XML, each Record Map base among them, is 409
/// <code>SOURCEFORMAT</code> or <code>TARGETFORMAT</code> from both; a class that is not listed, one stored and never compiled, a base
/// class and a name without <code>.cls</code> are <code>PORT.NOTFOUND</code> from the person and <code>TOOL.ARGUMENTS</code> from the agent; an empty message is 422
/// <code>INTEROP.TRANSFORM.CONTENT</code> on <code>content</code> from the person and <code>TOOL.ARGUMENTS</code> from the agent; and
/// OcuPilot's own name is <code>PROHIBITED.OCUPILOTCODE</code> from the person's Test and from the agent's confirm. The run count and
/// every extent stay as they were.</p>
/// <p>Mutation (Rule 19): drop the Record Map check from <method>OcuPilot.Port.InteropPort.FormatKindHere</method> -- the batch leg goes
/// red; drop one base from <parameter>OcuPilot.Port.InteropPort.RECORDMAPBASES</parameter> -- its leg goes red; check <code>content</code>
/// after the parse in <method>OcuPilot.Port.InteropPort.ReadTransform</method> -- the empty message leg goes red; list a class that is
/// not compiled as found -- the uncompiled leg goes red.</p>
Method TestEveryRefusalIsAnsweredByItsCodeAndRunsNothing()
{
    Set tRuns = $ClassMethod(..#FIXTURE, "Runs")
    Set tCounts = $ClassMethod(..#FIXTURE, "Counts")
    Set tMessage = $ClassMethod(..#FIXTURE, "Message", "x")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tCases = $ListBuild(
        $ListBuild("OcuProbeDtl.Batch.cls", tMessage, "409 INTEROP.TRANSFORM.SOURCEFORMAT", "409 INTEROP.TRANSFORM.SOURCEFORMAT"),
        $ListBuild("OcuProbeDtl.FromStream.cls", tMessage, "409 INTEROP.TRANSFORM.SOURCEFORMAT", "409 INTEROP.TRANSFORM.SOURCEFORMAT"),
        $ListBuild("OcuProbeDtl.ToStream.cls", tMessage, "409 INTEROP.TRANSFORM.TARGETFORMAT", "409 INTEROP.TRANSFORM.TARGETFORMAT"),
        $ListBuild("OcuProbeDtl.StreamBoth.cls", tMessage, "409 INTEROP.TRANSFORM.SOURCEFORMAT", "409 INTEROP.TRANSFORM.SOURCEFORMAT"),
        $ListBuild("OcuProbeDtl.RmBase.cls", tMessage, "409 INTEROP.TRANSFORM.SOURCEFORMAT", "409 INTEROP.TRANSFORM.SOURCEFORMAT"),
        $ListBuild("OcuProbeDtl.RmComplexBase.cls", tMessage, "409 INTEROP.TRANSFORM.SOURCEFORMAT", "409 INTEROP.TRANSFORM.SOURCEFORMAT"),
        $ListBuild("OcuProbeDtl.RmComplexParent.cls", tMessage, "409 INTEROP.TRANSFORM.SOURCEFORMAT", "409 INTEROP.TRANSFORM.SOURCEFORMAT"),
        $ListBuild("OcuProbeDtl.Uncompiled.cls", tMessage, "404 PORT.NOTFOUND", "400 TOOL.ARGUMENTS"),
        $ListBuild("OcuProbeDtl.Missing.cls", tMessage, "404 PORT.NOTFOUND", "400 TOOL.ARGUMENTS"),
        $ListBuild("Ens.DataTransformDTL.cls", tMessage, "404 PORT.NOTFOUND", "400 TOOL.ARGUMENTS"),
        $ListBuild("Ens.DataTransform.cls", tMessage, "404 PORT.NOTFOUND", "400 TOOL.ARGUMENTS"),
        $ListBuild("OcuProbeDtl.Xml", tMessage, "404 PORT.NOTFOUND", "400 TOOL.ARGUMENTS"),
        $ListBuild("OcuProbeDtl.Xml.cls", "", "422 INTEROP.TRANSFORM.CONTENT", "400 TOOL.ARGUMENTS"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tText = $ClassMethod(..#BASE, "Act", $List(tCase, 1), $List(tCase, 2), .tAnswer)
        Do $$$AssertEquals(tText, $List(tCase, 3), $List(tCase, 1) _ ": the person's Test is refused by its code")
        Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")) && $IsObject(tAnswer.detail.%Get("violations")): tAnswer.detail.violations.%Get(0).field, 1: ""), $Select($List(tCase, 2) = "": "content", 1: ""), $List(tCase, 1) _ ": a violation names the field")
        Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, $ClassMethod(..#BASE, "ArgsFor", $List(tCase, 1), $List(tCase, 2)), tUser, .tProposal, .tHttp, .tFault, .tTurn)
        Do $$$AssertEquals(..FaultText(tHttp, tFault), $List(tCase, 4), $List(tCase, 1) _ ": the agent's call is refused by its code")
        Do $$$AssertEquals($IsObject($Get(tProposal)), 0, $List(tCase, 1) _ ": and mints nothing")
    }
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, $ClassMethod(..#BASE, "ArgsFor", "OcuProbeDtl.Xml.cls", $Justify("", $Parameter("OcuPilot.Screen.Tool.ExplorerSave", "CHANGEMAXLENGTH") + 1)), tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "400 TOOL.ARGUMENTS", "a message past the card's width is refused from the agent")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Runs") - tRuns, 0, "no refusal ran a transformation")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts"), tCounts, "and none stored anything")
}

/// <p>AC5: OcuPilot's own name -- a transformation whose class begins <code>OcuPilot</code> -- is refused <code>PROHIBITED.OCUPILOTCODE</code>
/// from the person's Test and from the agent's confirm of a proposal the mint accepted, and nothing runs.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.IsOcuPilotCode</method> answer 0 -- both legs go red.</p>
Method TestOcuPilotsOwnNameIsRefusedFromBothCallers()
{
    Set tName = $Parameter(..#FIXTURE, "OWN") _ ".cls"
    Set tRuns = $ClassMethod(..#FIXTURE, "Runs")
    Set tText = $ClassMethod(..#BASE, "Act", tName, $ClassMethod(..#FIXTURE, "Message", "x"), .tAnswer)
    Do $$$AssertEquals(tText, "403 PROHIBITED.OCUPILOTCODE", "the person's Test is refused")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, $ClassMethod(..#BASE, "ArgsFor", tName, $ClassMethod(..#FIXTURE, "Message", "x")), ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the agent's call mints, since the set is evaluated at the confirm: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tConfirm)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tConfirm): tConfirm.%Get("code"), 1: ""), "403 PROHIBITED.OCUPILOTCODE", "and its confirm is refused: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Runs") - tRuns, 0, "nothing ran")
}

/// <p>AC5: a message past the port's bound is 422 <code>INTEROP.TRANSFORM.CONTENT</code> on <code>content</code> and a namespace that
/// runs no interoperability is 409 <code>INTEROP.NAMESPACE</code>, each through the port before any vendor call.</p>
/// <p>Mutation (Rule 19): drop the upper bound from <method>OcuPilot.Port.InteropPort.ReadTransform</method> -- the first leg goes
/// red.</p>
Method TestAMessagePastTheBoundAndAPlainNamespaceAreRefusedByThePort()
{
    Set tRuns = $ClassMethod(..#FIXTURE, "Runs")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = $Parameter(..#FIXTURE, "XML") _ ".cls"
    Set tQuery("content") = $Justify("", $Parameter("OcuPilot.Port.AtelierPort", "MAXIMPORTCHARACTERS") + 1)
    Set tSC = $ClassMethod("OcuPilot.Port.InteropPort", "Invoke", "Transforms", "TRANSFORMTEST", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "422 INTEROP.TRANSFORM.CONTENT", "a message one character past the bound is refused")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.detail.violations.%Get(0).field, 1: ""), "content", "naming the field")
    Set tQuery("content") = $ClassMethod(..#FIXTURE, "Message", "x")
    Set tQuery("namespace") = "%SYS"
    Set tSC = $ClassMethod("OcuPilot.Port.InteropPort", "Invoke", "Transforms", "TRANSFORMTEST", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "409 INTEROP.NAMESPACE", "a namespace that runs no interoperability is refused")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Runs") - tRuns, 0, "neither ran a transformation")
}

/// <p>AC5: a refused format or an absent class is answered before the message is judged, so an empty message does not hide it, and
/// when both sides are refused the source is the one named.</p>
/// <p>Mutation (Rule 19): judge <code>content</code> before the formats in <method>OcuPilot.Port.InteropPort.ReadTransform</method>, or
/// judge the target's format before the source's -- this goes red.</p>
Method TestAFormatIsRefusedBeforeTheMessageIsJudged()
{
    Set tRuns = $ClassMethod(..#FIXTURE, "Runs")
    Set tCases = $ListBuild($ListBuild("OcuProbeDtl.FromStream.cls", "409 INTEROP.TRANSFORM.SOURCEFORMAT"), $ListBuild("OcuProbeDtl.ToStream.cls", "409 INTEROP.TRANSFORM.TARGETFORMAT"), $ListBuild("OcuProbeDtl.StreamBoth.cls", "409 INTEROP.TRANSFORM.SOURCEFORMAT"), $ListBuild("OcuProbeDtl.Missing.cls", "404 PORT.NOTFOUND"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tText = $ClassMethod(..#BASE, "Act", $List(tCase, 1), "", .tAnswer)
        Do $$$AssertEquals(tText, $List(tCase, 2), $List(tCase, 1) _ " with an empty message is refused by its format or its absence")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Runs") - tRuns, 0, "no refusal ran a transformation")
}

/// <p>AC4: what a run answers is held to <parameter>OcuPilot.Port.InteropPort.TESTOUTPUTMAX</parameter> characters in all, the last line
/// cut and marked: a target one hundred characters past the bound is answered 200 <code>done</code> with its lines ending in the
/// marker and holding the bound and the marker's length and no more.</p>
/// <p>Mutation (Rule 19): drop the cut marker <method>OcuPilot.Port.InteropPort.RenderTargetHere</method> appends when the stream held
/// more than it read -- the marker leg goes red.</p>
Method TestATargetPastTheBoundIsCutAndMarked()
{
    Set tMax = $Parameter("OcuPilot.Port.InteropPort", "TESTOUTPUTMAX")
    Set tCut = $Parameter("OcuPilot.Port.InteropPort", "TESTCUT")
    Set tMessage = $ClassMethod(..#FIXTURE, "Message", $Translate($Justify("", tMax + 100), " ", "a"))
    Set tText = $ClassMethod(..#BASE, "Act", $Parameter(..#FIXTURE, "XML") _ ".cls", tMessage, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the run is answered 200")
    If '$IsObject(tAnswer) || '$IsObject(tAnswer.%Get("output")) Quit
    Set tOutput = tAnswer.output
    Set tLines = tOutput.lines
    Set tTotal = 0
    For tI = 0:1:tLines.%Size() - 1 Set tTotal = tTotal + $Length(tLines.%Get(tI))
    For tI = 0:1:tOutput.console.%Size() - 1 Set tTotal = tTotal + $Length(tOutput.console.%Get(tI))
    Set tLast = tLines.%Get(tLines.%Size() - 1)
    Do $$$AssertEquals(tOutput.status, "done", "it is done")
    Do $$$AssertEquals($Extract(tLast, $Length(tLast) - $Length(tCut) + 1, $Length(tLast)), tCut, "its last line ends in the cut marker")
    Do $$$AssertEquals(tTotal, tMax + $Length(tCut), "and the lines hold the bound and the marker and no more")
}

/// <p>A read of a transformation the list does not report is 404 <code>PORT.NOTFOUND</code> with or without the test's action, and an
/// action key the endpoint does not serve is 501: the host test's send on <code>Transforms</code>, and the transformation test on
/// <code>ItemTest</code>. The port is driven in process, and no transformation runs.</p>
/// <p>Mutation (Rule 19): move the absence refusal inside the action branch of
/// <method>OcuPilot.Port.InteropPort.ReadTransform</method> -- the first leg goes red; drop the 501 refusal from
/// <method>OcuPilot.Port.InteropPort.InvokeTransformTest</method> -- the second goes red; compare the action in
/// <method>OcuPilot.Port.InteropPort.InvokeItemTest</method> with <code>IsTestWrite</code> again -- the third goes red.</p>
Method TestAnUnlistedReadIsAbsentAndAForeignActionKeyIsNotImplemented()
{
    Set tRuns = $ClassMethod(..#FIXTURE, "Runs")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "OcuProbeDtl.Missing.cls"
    Set tSC = $ClassMethod("OcuPilot.Port.InteropPort", "Invoke", "Transforms", "TRANSFORM", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "404 PORT.NOTFOUND", "a read of a class the list does not report, with no action, is absent")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = $Parameter(..#FIXTURE, "XML") _ ".cls"
    Set tQuery("action") = "SENDTEST"
    Set tSC = $ClassMethod("OcuPilot.Port.InteropPort", "Invoke", "Transforms", "TRANSFORM", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "501 PORT.NOTIMPLEMENTED", "the host test's send is not a Transforms action")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "Probe||Item"
    Set tQuery("action") = "TRANSFORMTEST"
    Set tSC = $ClassMethod("OcuPilot.Port.InteropPort", "Invoke", "ItemTest", "TESTTARGET", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..FaultText(tHttp, tFault), "501 PORT.NOTIMPLEMENTED", "the transformation test is not an ItemTest action")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Runs") - tRuns, 0, "none of them ran a transformation")
}

}
