/// <p>Pins Story 20.6's host test refusals end to end against a probe production in <code>USER</code> (AD-12, AD-35, AD-39, AD-62):
/// each refusal and violation is answered by its own code with the published sentence from both callers, the person's Test action
/// and the agent's mint, before anything is built, saved or sent, so the saved request count, the message header count and the
/// request class's creation marker are as they were; testing that is not enabled is refused the same way; a confirm is refused as a
/// changed target after the item is disabled between mint and confirm; a credential's value reaches no ledger row; and a vendor
/// refusal that writes to the device is answered by its mapped code while the text it wrote is logged and never answered; and a
/// namespace that runs no interoperability is refused 409 on the read, the composed read and the send; and a request naming more
/// fields than the bound is refused as malformed.</p>
/// <p>It borrows the helpers of <class>OcuPilot.Test.InteropHostTest</class>. <b>What it needs from the environment:</b> the same as
/// that class, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it compiles and <b>runs a probe production
/// in <code>USER</code></b> and removes everything it made after the last test. One class per run.</p>
Class OcuPilot.Test.InteropHostTestRefusals Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter HOST = "OcuPilot.Test.InteropHostTest";

Parameter FIXTURE = "OcuPilot.Test.InteropTestFixture";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropItemTestSend";

Parameter ERROR = "OcuPilot.Api.InteropError";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropHostTestRefusals compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring up a throwaway container with scripts/ci-throwaway.sh.")
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
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropHostTestRefusals left probe state in USER")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ..Reset()
    Quit $ClassMethod(..#PROBE, "Settle")
}

Method OnAfterOneTest() As %Status
{
    Do ..Reset()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is left stopped")
    Quit $$$OK
}

/// <p>Nothing armed, the echo item enabled and testing enabled in the stored production, whatever the last test did.</p>
ClassMethod Reset()
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $ClassMethod(..#FIXTURE, "ClearMarker")
    If $ClassMethod(..#CONTROL, "StoredEnabled", $Parameter(..#FIXTURE, "ECHONAME")) = 0 Do $ClassMethod(..#CONTROL, "Act", "enable", $Parameter(..#FIXTURE, "ECHONAME"))
    Do $ClassMethod(..#FIXTURE, "EnableTesting", 1)
}

/// <p>The agent's mint of the test for <var>pName</var> as the HTTP account, as <code>status code</code>; the proposal in
/// <var>pProposal</var>, the fault in <var>pFault</var> and the turn in <var>pTurn</var>.</p>
ClassMethod Mint(pName As %String, pClass As %String, pFields As %DynamicObject, Output pProposal, Output pFault, Output pTurn) As %String
{
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, $ClassMethod(..#HOST, "ArgsFor", pName, pClass, pFields), ##class(OcuPilot.Test.Http).GetTestUsername(), .pProposal, .tHttp, .pFault, .pTurn)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>The first violation of <var>pAnswer</var> as <code>field code</code>, <code>""</code> when it names none.</p>
ClassMethod First(pAnswer) As %String
{
    If '$IsObject(pAnswer) || '$IsObject(pAnswer.%Get("detail")) || '$IsObject(pAnswer.detail.%Get("violations")) Quit ""
    Quit pAnswer.detail.violations.%Get(0).field _ " " _ pAnswer.detail.violations.%Get(0).code
}

/// <p>The saved requests, the message headers and the request class's creation marker, as one text.</p>
ClassMethod Footprint() As %String
{
    Quit $ClassMethod(..#FIXTURE, "Counts") _ "/" _ $ClassMethod(..#FIXTURE, "Marker")
}

/// <p>AC3: each host refusal, in the order the read checks them, is answered 409 by its own code and sentence from the person's Test
/// and refused the same at the agent's mint with nothing minted; no request is created, saved or sent, and OcuPilot records no test.
/// A production that is not running is the first; a business service, a disabled item, a class the item does not take (a
/// superclass and one that does not exist), a credential-named field with a value and a value for a field under a credential-named
/// object follow.</p>
/// <p>Mutation (Rule 19): drop the <code>TARGETDISABLED</code> check from <method>OcuPilot.Port.InteropPort.ReadTestTarget</method> --
/// the disabled leg goes red; drop the <code>SECRET</code> check -- the credential legs go red; test only the field's last segment in
/// that check -- the embedded credential leg goes red.</p>
Method TestEachRefusalIsAnsweredByItsCodeFromBothCallers()
{
    Set tEcho = $Parameter(..#FIXTURE, "ECHONAME")
    Set tClass = $Parameter(..#FIXTURE, "REQUESTCLASS")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    ; a $List serializes an object, so each case carries its fields as JSON text
    For tI = 1:1:8 {
        If tI = 2 Do $$$AssertStatusOK($ClassMethod(..#HOST, "Arm"), "the probe production runs with the testing service registered")
        If tI = 1 Set tCase = $ListBuild(tEcho, tClass, "{""Text"":""x""}", "NOTRUNNING", "the production is not running")
        If tI = 2 Set tCase = $ListBuild($Parameter(..#PROBE, "SVCNAME"), tClass, "{""Text"":""x""}", "TESTTARGETTYPE", "a business service takes no test")
        If tI = 3 Set tCase = $ListBuild($Parameter(..#FIXTURE, "OFFNAME"), tClass, "{""Text"":""x""}", "TESTTARGETDISABLED", "a disabled item would only queue the request")
        If tI = 4 Set tCase = $ListBuild(tEcho, "Ens.Request", "{}", "TESTREQUESTTYPE", "a superclass of the classes the item takes")
        If tI = 5 Set tCase = $ListBuild(tEcho, "OcuPilotProbe.No.Such.Class", "{}", "TESTREQUESTTYPE", "a class that does not exist")
        If tI = 6 Set tCase = $ListBuild(tEcho, tClass, "{""Text"":""x"",""Password"":""hunter2-secret""}", "TESTSECRET", "a credential-named field with a value")
        If tI = 7 Set tCase = $ListBuild(tEcho, tClass, "{""Text"":""x"",""Address.Street"":""s"",""Password"":""hunter2-secret""}", "TESTSECRET", "a credential among other fields")
        If tI = 8 Set tCase = $ListBuild(tEcho, tClass, "{""Text"":""x"",""Credential.Value"":""hunter2-secret""}", "TESTSECRET", "a field under a credential-named object")
        Set tFields = ##class(%DynamicObject).%FromJSON($List(tCase, 3))
        Set tCode = $Parameter(..#ERROR, $List(tCase, 4))
        If tI = 1 Set tCode = $Parameter(..#ERROR, "NOTRUNNING")
        Set tWhat = $List(tCase, 5)
        Set tBefore = ..Footprint()
        Set tText = $ClassMethod(..#HOST, "Send", $List(tCase, 1), $List(tCase, 2), tFields, .tAnswer)
        Do $$$AssertEquals(tText, "409 " _ tCode, tWhat _ ": the person's Test is refused by its code: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
        If $List(tCase, 4) '= "NOTRUNNING" Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), $Parameter(..#ERROR, "REASON" _ $List(tCase, 4)), tWhat _ ": with the published sentence")
        Set tMint = ..Mint($List(tCase, 1), $List(tCase, 2), tFields, .tProposal, .tFault, .tTurn)
        Do $$$AssertEquals(tMint, "409 " _ tCode, tWhat _ ": the agent's mint is refused the same")
        Do $$$AssertTrue('$IsObject($Get(tProposal)) && ($ClassMethod(..#CONTROL, "LedgerCount", tTurn, "interop.itemtest.send") = 0), tWhat _ ": nothing is minted or ledgered")
        If $List(tCase, 4) = "TESTSECRET" Do $$$AssertTrue(($Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "") '[ "hunter2") && ($Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: "") '[ "hunter2"), tWhat _ ": the value is in neither refusal")
        Do $$$AssertEquals(..Footprint(), tBefore, tWhat _ ": no request was saved, no header added, no request created")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ConfigChange", """verb"":""test"""), 0, "and OcuPilot recorded no test")
}

/// <p>AC3: a production started with testing not enabled has no testing service, so a Test is refused 409
/// <code>INTEROP.TEST.DISABLED</code> from both callers before any request is built, and the vendor, which would write its error to
/// the device, is not called.</p>
/// <p>Mutation (Rule 19): drop the testing-registered check from <method>OcuPilot.Port.InteropPort.ReadTestTarget</method> -- the
/// request is saved before the vendor refuses, the saved count grows and this goes red.</p>
Method TestATestWithTestingNotEnabledIsRefusedBeforeAnythingIsBuilt()
{
    Set tEcho = $Parameter(..#FIXTURE, "ECHONAME")
    Set tClass = $Parameter(..#FIXTURE, "REQUESTCLASS")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "EnableTesting", 0), "testing is turned off in the stored production")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = $Parameter(..#PROBE, "PRODUCTION")
    Set tSC = $ClassMethod($Parameter(..#CONTROL, "PORT"), "Invoke", "Productions", "START", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the production starts")
    Do $$$AssertTrue($ClassMethod("OcuPilot.Test.InteropJobEnd", "StartUpdated", .tWhy), "and is up to date: " _ $Get(tWhy))
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = $ClassMethod(..#HOST, "ItemId", tEcho)
    Set tSC = $ClassMethod($Parameter(..#CONTROL, "PORT"), "Invoke", "ItemTest", "TESTTARGET", .tQuery, "", .tRow, .tReadHttp, .tReadFault)
    Do $$$AssertEquals($Select($IsObject($Get(tRow)): +tRow.Testing, 1: "unread " _ $Get(tReadHttp)), 0, "the item's read says testing is not available")
    Set tBefore = ..Footprint()
    Set tText = $ClassMethod(..#HOST, "Send", tEcho, tClass, {"Text": "x"}, .tAnswer)
    Do $$$AssertEquals(tText, "409 " _ $Parameter(..#ERROR, "TESTDISABLED"), "the person's Test is refused: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), $Parameter(..#ERROR, "REASONTESTDISABLED"), "with the published sentence")
    Set tMint = ..Mint(tEcho, tClass, {"Text": "x"}, .tProposal, .tFault)
    Do $$$AssertEquals(tMint, "409 " _ $Parameter(..#ERROR, "TESTDISABLED"), "so is the agent's mint")
    Do $$$AssertEquals(..Footprint(), tBefore, "nothing was saved, added or created")
}

/// <p>AC3: a request the item's class cannot take is 422 on the field, from both callers, before anything is saved: an unknown
/// field and a second member of a document are <code>INTEROP.TEST.FIELD</code>, a value its class refuses, a value outside a
/// field's listed values (a boolean's <code>true</code>, a display list's stored value), a required field left out, a value over the
/// field's length and a document with no text are <code>INTEROP.TEST.VALUE</code>, and text that is not a
/// message of the document class is <code>INTEROP.TEST.REQUEST</code> on <code>content</code>. The agent's mint is refused the same
/// way, with the same code on the same field, except the last, which only the send can tell.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ConvertPlanHere</method> accept a value whose class refuses it --
/// the value legs go red; drop the listed-values check from <method>OcuPilot.Port.InteropPort.ReadTestTarget</method> -- the
/// <code>Flag</code> and <code>Level</code> legs go red.</p>
Method TestAnInvalidRequestIsRefusedOnItsFieldFromBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#HOST, "Arm"), "the probe production runs with the testing service registered")
    Set tEcho = $Parameter(..#FIXTURE, "ECHONAME")
    Set tClass = $Parameter(..#FIXTURE, "REQUESTCLASS")
    Set tDocument = $Parameter(..#FIXTURE, "DOCUMENTCLASS")
    Set tField = ##class(OcuPilot.Api.InteropError).#TESTFIELD
    Set tValue = ##class(OcuPilot.Api.InteropError).#TESTVALUE
    Set tRequest = ##class(OcuPilot.Api.InteropError).#TESTREQUEST
    ; each case is its class, its fields as JSON text, and the first violation expected: field and code
    For tCase = $ListBuild(tClass, "{""Text"":""x"",""Nope"":""y""}", "Nope " _ tField), $ListBuild(tClass, "{""Text"":""x"",""Count"":""abc""}", "Count " _ tValue), $ListBuild(tClass, "{""Text"":""x"",""Kind"":""delta""}", "Kind " _ tValue), $ListBuild(tClass, "{""Text"":""x"",""Flag"":""true""}", "Flag " _ tValue), $ListBuild(tClass, "{""Text"":""x"",""Level"":""H""}", "Level " _ tValue),
        $ListBuild(tClass, "{""Count"":""5""}", "Text " _ tValue), $ListBuild(tClass, "{""Text"":""" _ $Translate($Justify("", 51), " ", "x") _ """}", "Text " _ tValue), $ListBuild(tClass, "{""Text"":""x"",""Address.Nope"":""y""}", "Address.Nope " _ tField),
        $ListBuild(tDocument, "{""content"":""x"",""other"":""y""}", "other " _ tField), $ListBuild(tDocument, "{""content"":""""}", "content " _ tValue), $ListBuild(tDocument, "{""content"":""this is not a message""}", "content " _ tRequest) {
        Set tFields = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Set tWhat = $List(tCase, 1) _ " " _ $List(tCase, 2)
        Set tBefore = ..Footprint()
        Set tText = $ClassMethod(..#HOST, "Send", tEcho, $List(tCase, 1), tFields, .tAnswer)
        Do $$$AssertEquals(tText _ "|" _ ..First(tAnswer), "422 " _ $Piece($List(tCase, 3), " ", 2) _ "|" _ $List(tCase, 3), "the person's Test of " _ tWhat _ " is 422 on its first violation")
        Do $$$AssertEquals(..Footprint(), tBefore, "nothing was saved, added or created")
        Set tMint = ..Mint(tEcho, $List(tCase, 1), tFields, .tProposal, .tFault, .tTurn)
        If $Piece($List(tCase, 3), " ", 2) = tRequest {
            ; whether text is a message of its class is known only by building it, which the send does and the read does not
            Do $$$AssertTrue($IsObject($Get(tProposal)), "the agent's mint of " _ tWhat _ " reads the text as a field value and mints: " _ tMint)
            If '$IsObject($Get(tProposal)) Continue
            Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tConfirm)
            Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tConfirm): tConfirm.%Get("code"), 1: ""), "422 " _ tRequest, "and its confirm is refused with the request code: " _ $Extract($Get(tRaw), 1, 300))
            Do $$$AssertEquals(..Footprint(), tBefore, "nothing was saved, added or created")
            ; the refused confirm is ledgered as an error, which this test does not assert on
            Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
        } Else {
            Do $$$AssertEquals(tMint _ "|" _ ..First($Get(tFault)), "422 " _ $Piece($List(tCase, 3), " ", 2) _ "|" _ $List(tCase, 3), "the agent's mint of " _ tWhat _ " is refused with the same code on the same field")
            Do $$$AssertTrue('$IsObject($Get(tProposal)), "and mints nothing")
        }
    }
    Set tText = $ClassMethod(..#HOST, "Send", tEcho, tClass, {"Text": "x"}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "and a sound request is sent: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
}

/// <p>AC3 (AD-6): an item disabled between the mint and the confirm is a changed target, so the confirm is refused 409
/// <code>PROPOSAL.TARGETCHANGED</code>, nothing is sent and the proposal sends no request later.</p>
/// <p>Mutation (Rule 19): drop <code>Enabled</code> from <parameter>OcuPilot.Screen.Tool.InteropItemTestSend.FINGERPRINTSUBJECT</parameter>
/// and the refusal of a disabled target -- the confirm sends and this goes red.</p>
Method TestAConfirmIsRefusedAsAChangedTargetAfterTheItemIsDisabled()
{
    Do $$$AssertStatusOK($ClassMethod(..#HOST, "Arm"), "the probe production runs with the testing service registered")
    Set tEcho = $Parameter(..#FIXTURE, "ECHONAME")
    Set tMint = ..Mint(tEcho, $Parameter(..#FIXTURE, "REQUESTCLASS"), {"Text": "x"}, .tProposal, .tFault, .tTurn)
    Do $$$AssertEquals(tMint, "200 ", "the call mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit
    Set tBefore = ..Footprint()
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "disable", tEcho), "200 ", "the item is disabled after the mint")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as a changed target: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..Footprint(), tBefore, "nothing was created, saved or sent")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "LedgerCount", tTurn, "interop.itemtest.send"), 0, "and no write is ledgered")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "enable", tEcho), "200 ", "the item is enabled again")
}

/// <p>AC3: a vendor that refuses a send after writing to the device -- the testing service not registered, as a stopped production's
/// send does -- is answered by the mapped code <code>INTEROP.TEST.DISABLED</code> with the published sentence; the text it wrote is
/// logged and appears in no answer. The port is called through <class>OcuPilot.Test.InteropItemSeam</class>, which makes the vendor
/// call fail in process.</p>
/// <p>Mutation (Rule 19): drop the log of the captured text in <method>OcuPilot.Port.InteropPort.PerformTest</method> -- the logged
/// leg goes red; answer the captured text in the refusal -- the answer leg goes red.</p>
Method TestAVendorRefusalThatWritesToTheDeviceIsMappedAndLoggedNotAnswered()
{
    Do $$$AssertStatusOK($ClassMethod(..#HOST, "Arm"), "the probe production runs with the testing service registered")
    Do $ClassMethod(..#HOST, "HoldPairs")
    Do $ClassMethod(..#SEAM, "Arm")
    Do $ClassMethod(..#SEAM, "FailSendWithDeviceText", "VENDOR-DEVICE-TEXT-7")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = $ClassMethod(..#HOST, "ItemId", $Parameter(..#FIXTURE, "ECHONAME"))
    Set tQuery("requestClass") = $Parameter(..#FIXTURE, "REQUESTCLASS")
    Set tQuery("fields") = "{""Text"":""x""}"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "ItemTest", "SENDTEST", .tQuery, "", .tResult, .tHttp, .tFault)
    Set tFaultText = $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "")
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409 " _ $Parameter(..#ERROR, "TESTDISABLED"), "the refusal is the mapped code: " _ tFaultText)
    Do $$$AssertTrue(tFaultText '[ "VENDOR-DEVICE-TEXT-7", "and the text the vendor wrote is not in the answer")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Logged"), 1, "one line was logged")
    Do $$$AssertTrue($Get(^||OcuPilotInteropItemLog(1)) [ "VENDOR-DEVICE-TEXT-7", "and it carries what the vendor wrote: " _ $Get(^||OcuPilotInteropItemLog(1)))
    Do $ClassMethod(..#SEAM, "Disarm")
}

/// <p>AC3: a namespace that runs no interoperability is refused 409 <code>INTEROP.NAMESPACE</code> on the tab's list, the composed read
/// and the send, before any request is built, so the saved request count, the message header count and the creation marker are as
/// they were.</p>
/// <p>Mutation (Rule 19): drop the <code>INTEROP.NAMESPACE</code> refusal from <method>OcuPilot.Port.InteropPort.Admit</method> -- this
/// goes red.</p>
Method TestANamespaceThatRunsNoInteroperabilityIsRefusedOnEveryType()
{
    Set tBefore = ..Footprint()
    Set tItem = $ClassMethod(..#HOST, "ItemId", $Parameter(..#FIXTURE, "ECHONAME"))
    For tType = "LIST", "TESTTARGET", "SENDTEST" {
        Kill tQuery
        Set tQuery("namespace") = "%SYS"
        Set tQuery("item") = tItem
        Set tQuery("id") = tItem
        Set tQuery("requestClass") = $Parameter(..#FIXTURE, "REQUESTCLASS")
        Set tQuery("fields") = "{""Text"":""x""}"
        Set tSC = $ClassMethod(..#PORT, "Invoke", "ItemTest", tType, .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409 " _ $Parameter(..#ERROR, "NAMESPACE"), tType _ " in a namespace that runs no interoperability is refused")
    }
    Do $$$AssertEquals(..Footprint(), tBefore, "and nothing was built, saved or sent")
}

/// <p>AC3: a request naming more fields than the bound is refused as malformed, 400 <code>PORT.VALIDATION</code>, on the composed read
/// the send begins with, before any class is looked up, so nothing is built, saved or sent.</p>
/// <p>Mutation (Rule 19): drop the member count from <method>OcuPilot.Port.InteropPort.ParseTestFields</method> -- this goes red.</p>
Method TestARequestNamingTooManyFieldsIsRefusedAsMalformed()
{
    Set tBefore = ..Footprint()
    Set tFields = {}
    For tI = 1:1:$Parameter(..#PORT, "TESTINPUTMAX") + 1 {
        Do tFields.%Set("f" _ tI, "x", "string")
    }
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = $ClassMethod(..#HOST, "ItemId", $Parameter(..#FIXTURE, "ECHONAME"))
    Set tQuery("requestClass") = $Parameter(..#FIXTURE, "REQUESTCLASS")
    Set tQuery("fields") = tFields.%ToJSON()
    For tType = "TESTTARGET", "SENDTEST" {
        Set tSC = $ClassMethod(..#PORT, "Invoke", "ItemTest", tType, .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "400 PORT.VALIDATION", tType _ " with one field too many is refused as malformed")
    }
    Do $$$AssertEquals(..Footprint(), tBefore, "and nothing was built, saved or sent")
}

}
