/// <p>Pins Story 21.38's source-control follow-up (AD-39's ninth exception, AD-53, AD-61 rules 1, 3, 6 and 7): OcuPilot's
/// create and delete of a class return the question or alert the namespace's source-control class asks as
/// <code>questions</code>, and nothing when it asks none; an action the port cannot show carries no text; an answer runs
/// <code>AfterUserAction</code> in the calling process, as the caller, through the one fixed statement with every value bound;
/// a bad step, answer or set, and a caller without WRITE on the routines database, are refused before any route; a class's
/// error text is logged and never sent; and the question's text reaches the agent's mint answer, the stored proposal, its
/// ledger rows, the audit and the message log never, while the confirm's own answer carries it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, a <code>USER</code> namespace that runs interoperability, and
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>PRINCIPALVARIABLE</parameter> reading <code>1</code>, because each test puts <code>USER</code> under
/// <class>OcuPilot.Test.SourceControlProbe</class>'s source-control class and takes it away again. It makes its probe documents
/// before it enables the class, removes them after it disables it, asserts that <code>USER</code> then names no source-control
/// class and that no probe document is left, and snapshots the stored governance policy before each test and puts it back
/// after it.</p>
Class OcuPilot.Test.SourceControlFollowUp Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_NAMESPACE_CONFIG";

/// <p>The variable that arms the account the answer's WRITE leg signs in as
/// (<class>OcuPilot.Test.DeveloperFloorFixture</class>).</p>
Parameter PRINCIPALVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter NAMESPACE = "USER";

Parameter SC = "OcuPilot.Test.SourceControlProbe";

Parameter PROBE = "OcuPilot.Test.ExplorerCreateProbe";

Parameter SAVE = "OcuPilot.Test.AtelierPortSave";

Parameter FIXTURE = "OcuPilot.Test.AtelierPortFixture";

Parameter FLOW = "OcuPilot.Test.ExplorerCreateFlow";

/// <p>The probe classes, in the probe package: each leg makes its own, so a leg never meets another's.</p>
Parameter ASKED = "OcuProbe2020.Asked";

Parameter QUIET = "OcuProbe2020.Quiet";

Parameter ALERT = "OcuProbe2020.Alert";

Parameter OTHER = "OcuProbe2020.Other";

Parameter GONE = "OcuProbe2020.Gone";

Parameter AGENT = "OcuProbe2020.Agent";

Parameter PERSON = "OcuProbe2020.Person";

Parameter CREATETOOL = "explorer.classes.create";

Parameter DELETETOOL = "explorer.classes.delete";

/// <p>The classes list's delete key, which the baseline disables.</p>
Parameter DELETEKEY = "explorer.classes.delete";

/// <p>The text an error the hooks class raises carries, for the create's question and for the answer.</p>
Parameter ERRORTEXT = "OcuProbe2138 hook error text";

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SourceControlFollowUp puts " _ ..#NAMESPACE _ " under a source-control class and takes it away again, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#PRINCIPALVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SourceControlFollowUp creates one IRIS account for its WRITE leg, and runs on a throwaway container only. " _ ..#PRINCIPALVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Set tSC = $ClassMethod(..#SC, "Disable", ..#NAMESPACE)
    If $$$ISERR(tSC) Quit tSC
    Do ..ClearFixtures()
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Remove", ..#NAMESPACE)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#SC, "Disable", ..#NAMESPACE), "the probe's source-control class is taken out of " _ ..#NAMESPACE)
    Do $$$AssertEquals(##class(%Studio.SourceControl.Interface).SourceControlClassGet(..#NAMESPACE), "", ..#NAMESPACE _ " names no source-control class")
    Set tGlobal = $ClassMethod(..#SC, "Global", ..#NAMESPACE)
    Do $$$AssertTrue('$Data(@tGlobal), "the probe's log global is gone")
    Do ..ClearFixtures()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#NAMESPACE), "every probe class is removed")
    Set tLeft = ""
    For tName = ..#ASKED, ..#QUIET, ..#ALERT, ..#OTHER, ..#GONE, ..#AGENT, ..#PERSON {
        If $ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, tName _ ".cls") Set tLeft = tLeft _ " " _ tName
    }
    Do $$$AssertEquals(tLeft, "", "and each reads back absent")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Test.DeveloperFloorFixture", "RemovePrincipals"), "", "no probe account or role is left")
    Quit $$$OK
}

Method ClearFixtures()
{
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>Put <code>USER</code> under the probe's source-control class, its log empty, with the action its
/// <code>UserAction</code> answers set to <var>pAction</var>.</p>
Method Arm(pAction As %Integer)
{
    Do $$$AssertStatusOK($ClassMethod(..#SC, "Enable", ..#NAMESPACE), "the probe's source-control class is enabled in " _ ..#NAMESPACE)
    Do $ClassMethod(..#SC, "Action", ..#NAMESPACE, pAction)
    Do $ClassMethod(..#SC, "Clear", ..#NAMESPACE)
}

/// <p>The port's create of the probe class <var>pName</var>, not compiled.</p>
ClassMethod Create(pName As %String, Output pResult, Output pHttp As %Integer, Output pFault) As %Status
{
    Quit $ClassMethod(..#SAVE, "Act", "Classes", "CREATE", $ListBuild("names=" _ pName _ ".cls", "content=" _ $ClassMethod(..#PROBE, "NewClassText", pName), "Compile=0"), .pResult, .pHttp, .pFault)
}

/// <p>The questions the port answers for <var>pDocument</var> at each step of the comma list <var>pSteps</var>, all of
/// <var>pAction</var>: with the class's text <var>pTarget</var> for a question or an alert, flagged unsupported with none
/// for any other action.</p>
ClassMethod Expected(pDocument As %String, pSteps As %String, pAction As %Integer, pTarget As %String = "") As %DynamicArray
{
    Set tList = []
    For tI = 1:1:$Length(pSteps, ",") {
        Set tQuestion = {}
        Do tQuestion.%Set("document", pDocument, "string")
        Do tQuestion.%Set("step", +$Piece(pSteps, ",", tI), "number")
        Do tQuestion.%Set("action", pAction, "number")
        If (pAction = 1) || (pAction = 6) {
            Do tQuestion.%Set("target", pTarget, "string")
        } Else {
            Do tQuestion.%Set("unsupported", 1, "boolean")
        }
        Do tList.%Push(tQuestion)
    }
    Quit tList
}

/// <p>The delete's result for <var>pDocument</var> with no question: the one document, deleted.</p>
ClassMethod Deleted(pDocument As %String) As %DynamicObject
{
    Quit {"documents": [{"name": (pDocument), "deleted": true, "reason": ""}]}
}

/// <p>The <code>extra</code> of each hook call of <var>pEntries</var> (the probe's log) named <var>pHook</var>, comma-joined
/// in order.</p>
ClassMethod Extras(pEntries As %DynamicArray, pHook As %String) As %String
{
    Set tExtras = ""
    Set tIterator = pEntries.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.hook = pHook Set tExtras = tExtras _ $Select(tExtras = "": "", 1: ",") _ tEntry.extra
    }
    Quit tExtras
}

/// <p>An answer or a fault as one text, as <class>OcuPilot.Test.AtelierPortSave</class> says it.</p>
ClassMethod Said(pHttp, pResult, pFault) As %String
{
    Quit $ClassMethod(..#SAVE, "Said", .pHttp, .pResult, .pFault)
}

/// <p>AC5: a create the source-control class asks a question after answers one question per step the class was asked at
/// (1 and 7), carrying the class's text; a delete answers one at step 2 beside its per-document result; and with action 0
/// neither answers a <code>questions</code> member, the create's result and the delete's staying as they were.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.DeleteSet</method> drops the <code>questions</code> it reads
/// -- the delete legs go red.</p>
Method TestACreateAndADeleteReturnTheQuestionTheClassAsks()
{
    Set tQuestion = $Parameter(..#SC, "QUESTION")
    Set tName = ..#ASKED _ ".cls"
    Do ..Arm(1)
    Do ..Create(..#ASKED, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "200 " _ {"questions": (..Expected(tName, "1,7", 1, tQuestion))}.%ToJSON(), "the create answers the class's question at both its steps")
    Do $$$AssertEquals(..Extras($ClassMethod(..#SC, "Entries", ..#NAMESPACE), "UserAction"), "1|1,1|7", "which the class was asked, in order")
    Do $ClassMethod(..#SC, "Clear", ..#NAMESPACE)
    Do $ClassMethod(..#SAVE, "Act", "Classes", "DELETE", $ListBuild("names=" _ tName), .tResult, .tHttp, .tFault)
    Set tExpected = ..Deleted(tName)
    Do tExpected.%Set("questions", ..Expected(tName, "2", 1, tQuestion))
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "200 " _ tExpected.%ToJSON(), "the delete answers its per-document result and the class's question at step 2")
    Do $$$AssertEquals(..Extras($ClassMethod(..#SC, "Entries", ..#NAMESPACE), "UserAction"), "1|2", "which the class was asked")

    Do $ClassMethod(..#SC, "Action", ..#NAMESPACE, 0)
    Set tQuiet = ..#QUIET _ ".cls"
    Do ..Create(..#QUIET, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "200 {}", "with action 0 the create answers no question")
    Do $ClassMethod(..#SAVE, "Act", "Classes", "DELETE", $ListBuild("names=" _ tQuiet), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "200 " _ ..Deleted(tQuiet).%ToJSON(), "and the delete answers its result alone")
}

/// <p>AC6: an alert (action 6) is answered with the class's text and an action the port cannot show (3 here) with no text at
/// all, on both a create and a delete.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.Questions</method> keeps the text of every action -- the unsupported
/// leg goes red; it treats action 6 as unsupported -- the alert leg goes red.</p>
Method TestAnAlertKeepsItsTextAndAnyOtherActionCarriesNone()
{
    Set tQuestion = $Parameter(..#SC, "QUESTION")
    For tCase = $ListBuild(..#ALERT, 6), $ListBuild(..#OTHER, 3) {
        Set tName = $List(tCase, 1) _ ".cls"
        Set tAction = $List(tCase, 2)
        Do ..Arm(tAction)
        Do ..Create($List(tCase, 1), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "200 " _ {"questions": (..Expected(tName, "1,7", tAction, tQuestion))}.%ToJSON(), "action " _ tAction _ ": the create's questions")
        Do $ClassMethod(..#SAVE, "Act", "Classes", "DELETE", $ListBuild("names=" _ tName), .tResult, .tHttp, .tFault)
        Set tExpected = ..Deleted(tName)
        Do tExpected.%Set("questions", ..Expected(tName, "2", tAction, tQuestion))
        Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "200 " _ tExpected.%ToJSON(), "action " _ tAction _ ": the delete's question")
        Do $$$AssertStatusOK($ClassMethod(..#SC, "Disable", ..#NAMESPACE), "the probe is taken out before the next action")
    }
}

/// <p>AC5: an answer runs <code>AfterUserAction</code> in the calling process, as the caller, at the step and with the
/// answer sent, for a document that is gone, and answers <code>{}</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.AnswerSet</method> binds the step where the answer goes -- the
/// logged triples go red.</p>
Method TestAnAnswerRunsAfterUserActionAsTheCaller()
{
    Do ..Arm(1)
    For tCase = $ListBuild(7, 1), $ListBuild(2, 2), $ListBuild(1, 0) {
        Set tStep = $List(tCase, 1)
        Set tAnswer = $List(tCase, 2)
        Do $ClassMethod(..#SC, "Clear", ..#NAMESPACE)
        Do $ClassMethod(..#SAVE, "Act", "Classes", "ANSWER", $ListBuild("names=" _ ..#GONE _ ".cls", "step=" _ tStep, "answer=" _ tAnswer), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "200 {}", "step " _ tStep _ ", answer " _ tAnswer _ ": answered")
        Set tEntries = $ClassMethod(..#SC, "Entries", ..#NAMESPACE)
        Do $$$AssertEquals(..Extras(tEntries, "AfterUserAction"), "1|" _ tStep _ "|" _ tAnswer, "the class's AfterUserAction ran once with that step and answer: " _ tEntries.%ToJSON())
        Set tWrong = ""
        Set tIterator = tEntries.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If tEntry.hook '= "AfterUserAction" Continue
            If ($ZConvert(tEntry.name, "U") '= $ZConvert(..#GONE _ ".cls", "U")) || (tEntry.job '= $Job) || (tEntry.user '= $Username) Set tWrong = tWrong _ " " _ tEntry.%ToJSON()
        }
        Do $$$AssertEquals(tWrong, "", "for that document, in this process, as " _ $Username)
    }
}

/// <p>AC9: an error the class raises is logged at information severity and never sent. After a create it leaves the create's
/// result free of the text; for an answer it is 422 <code>EXPLORER.SOURCECONTROL.ANSWER</code> with the published sentence and
/// the text in no part of the fault.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.AnswerSet</method> puts the class's text in the refusal's reason
/// -- the answer leg goes red.</p>
Method TestAClassesErrorTextIsLoggedAndNeverSent()
{
    Set tText = ..#ERRORTEXT
    Do ..Arm(1)
    Do $ClassMethod(..#SC, "Error", ..#NAMESPACE, 0, tText)
    Do ..Create(..#ASKED, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a create answers though the class's UserAction failed: " _ ..Said(.tHttp, .tResult, .tFault))
    Do $$$AssertTrue($IsObject($Get(tResult)) && (tResult.%ToJSON() '[ tText), "and its result holds none of the class's error text")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ tText, "which went to the log: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("severity"), 0, "at information severity")
    Do $ClassMethod(..#SC, "Error", ..#NAMESPACE, 0, "")
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do $ClassMethod(..#SC, "Error", ..#NAMESPACE, 1, tText)
    Do $ClassMethod(..#SAVE, "Act", "Classes", "ANSWER", $ListBuild("names=" _ ..#ASKED _ ".cls", "step=7", "answer=1"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault) _ " " _ $Select($IsObject($Get(tFault)): tFault.reason, 1: ""), "422 EXPLORER.SOURCECONTROL.ANSWER " _ ##class(OcuPilot.Api.AtelierError).#REASONSOURCECONTROLANSWER, "the answer is refused with the published sentence")
    Do $$$AssertTrue($IsObject($Get(tFault)) && (tFault.%ToJSON() '[ tText), "and the fault holds none of the class's text: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ tText, "which went to the log: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("severity"), 0, "at information severity")
}

/// <p>AC7: an answer is refused before any route when its set is not one document, its step is not 1, 2 or 7, or its answer
/// is not 0, 1 or 2; one sent to a caller holding the read pairs but not WRITE on the routines database is refused naming
/// that pair; and with WRITE the one statement goes to the <code>Query</code> route with every value bound and nothing a
/// caller typed in it (canned routes, the fixture's gate).</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Port.AtelierPort.TYPEANSWER</parameter> from the write types in
/// <method>OcuPilot.Port.AtelierPort.Invoke</method> -- the WRITE leg goes red; accept any step in
/// <method>OcuPilot.Port.AtelierPort.AnswerSet</method> -- the step leg goes red.</p>
Method TestABadAnswerOrACallerWithoutWriteIsRefusedBeforeAnyRoute()
{
    Do $ClassMethod(..#FIXTURE, "UseFakeRoutes")
    Do $ClassMethod(..#FIXTURE, "SetVersion", 8)
    Do $ClassMethod(..#FIXTURE, "SetResources", "%DB_PROBEHOME", "%DB_PROBEGLOBALS", "")
    Do $ClassMethod(..#FIXTURE, "SetGateClass", "OcuPilot.Test.ScreenGate")
    For tPair = $ListBuild("%Development", "USE"), $ListBuild("%DB_PROBEHOME", "READ"), $ListBuild("%DB_PROBEGLOBALS", "READ") {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tPair, 1), $List(tPair, 2))
    }
    Set tNamespace = "namespace=" _ $Namespace
    Set tOne = "names=" _ ..#GONE _ ".cls"
    Do $ClassMethod(..#SAVE, "Act", "Classes", "ANSWER", $ListBuild(tNamespace, tOne, "step=7", "answer=1"), .tResult, .tHttp, .tFault)
    Set tPair = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.detail.failedPair, 1: "")
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault) _ " " _ tPair, "403 AUTH.NOPRIVILEGE %DB_PROBEHOME:WRITE", "an answer is refused naming the routines database's WRITE pair")
    Do $ClassMethod(..#SAVE, "Act", "Classes", "ANSWERDOCS", $ListBuild(tNamespace, tOne), .tResult, .tHttp, .tFault)
    Set tPair = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.detail.failedPair, 1: "")
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault) _ " " _ tPair, "403 AUTH.NOPRIVILEGE %DB_PROBEHOME:WRITE", "so is the answer's own read")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CallCount"), 0, "before any route")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_PROBEHOME", "WRITE")
    For tCase = $ListBuild(tOne, "step=3", "answer=1"), $ListBuild(tOne, "step=", "answer=1"), $ListBuild(tOne, "step=7", "answer=3"), $ListBuild(tOne, "step=7", "answer="), $ListBuild(tOne _ "," _ ..#ALERT _ ".cls", "step=7", "answer=1"), $ListBuild("names=not a document", "step=7", "answer=1") {
        Do $ClassMethod(..#SAVE, "Act", "Classes", "ANSWER", $ListBuild(tNamespace) _ tCase, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals($Piece(..Said(.tHttp, .tResult, .tFault), " ", 1, 2), "400 PORT.VALIDATION", $ListToString(tCase) _ ": refused 400")
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CallCount"), 0, "none of them reaches a route")
    Do $ClassMethod(..#FIXTURE, "Arm", "Query", "200 OK", "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[{""message"":"""",""reload"":0,""doc"":"""",""errorText"":""""}]}}")
    Do $ClassMethod(..#SAVE, "Act", "Classes", "ANSWER", $ListBuild(tNamespace, tOne, "step=7", "answer=1"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(.tHttp, .tResult, .tFault), "200 {}", "with WRITE the answer is sent")
    Set tCall = $ClassMethod(..#FIXTURE, "CallAt", 1)
    Do $$$AssertEquals(tCall.method _ " " _ tCall.body, "Query " _ {"query": (##class(OcuPilot.Port.AtelierPort).#USERACTIONANSWERQUERY), "parameters": [1, 7, (..#GONE _ ".cls"), 1, ""]}.%ToJSON(), "as the one fixed statement with the step, document and answer bound")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "CallCount"), 1, "in one route call")
}

/// <p>AC9 (AD-39's ninth exception): over the agent's confirmed create and delete the class's question rides on the confirm's
/// own answer and nowhere else: the mint's answer to the model, the stored proposal and its turn's ledger rows, the audit
/// and the message log hold none of its text. (The text stays out of the client's screen context in the client's own
/// specs.)</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.Questions</method> logs the class's text through
/// <method>OcuPilot.Port.AtelierPort.LogNote</method> -- the message log leg goes red;
/// <class>OcuPilot.Screen.Tool.ExplorerSave</class>'s <code>WriteOutput</code> answers nothing -- the create's confirm leg
/// goes red.</p>
Method TestTheQuestionReachesTheConfirmAnswerAndNothingElse()
{
    Set tQuestion = $Parameter(..#SC, "QUESTION")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#NAMESPACE, ..#GONE), "a probe class is saved to delete")
    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the delete key is enabled through its stored setting")
    Do ..Arm(1)
    Set tMark = ##class(OcuPilot.Test.SslSinks).AuditMark()
    Set tFrom = ##class(OcuPilot.Test.SourceControlSave).LogSize(.tLog)
    Set tSC = $ClassMethod(..#FLOW, "Dispatch", ..#NAMESPACE, ..#CREATETOOL, $ClassMethod(..#FLOW, "Input", ..#AGENT _ ".cls", $ClassMethod(..#PROBE, "NewClassText", ..#AGENT)), .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) || tIsError Do $$$AssertTrue(0, "the create is minted: " _ $Extract($Get(tContent), 1, 300)) Quit
    Do $$$AssertTrue(tContent '[ tQuestion, "the create's mint answers the model none of the question")
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#NAMESPACE, tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the create is confirmed: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertTrue($IsObject(tResult.output) && (tResult.output.%GetTypeOf("questions") = "array"), "the confirm's answer carries the questions: " _ tResult.%ToJSON())
    If '$IsObject(tResult.output) || (tResult.output.%GetTypeOf("questions") '= "array") Quit
    Do $$$AssertEquals(tResult.output.questions.%ToJSON(), ..Expected(..#AGENT _ ".cls", "1,7", 1, tQuestion).%ToJSON(), "at both steps, with the class's text")
    Set tStored = ##class(OcuPilot.Test.ExplorerWrite).StoredText(tProposal.proposalId, .tLedgerRows)
    Do $$$AssertTrue(tLedgerRows > 0, "the turn's ledger rows are read: " _ tLedgerRows)
    Do $$$AssertTrue((tStored [ (..#AGENT _ ".cls")) && (tStored '[ tQuestion), "the stored proposal and its ledger rows hold none of the text: " _ $Extract(tStored, 1, 300))

    Set tSC = $ClassMethod(..#FLOW, "Dispatch", ..#NAMESPACE, ..#DELETETOOL, {"Names": (..#GONE _ ".cls")}, .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) || tIsError Do $$$AssertTrue(0, "the delete is minted: " _ $Extract($Get(tContent), 1, 300)) Quit
    Do $$$AssertTrue(tContent '[ tQuestion, "the delete's mint answers the model none of the question")
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#NAMESPACE, tProposal, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the delete is confirmed: " _ $Get(tCode))
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertTrue($IsObject(tResult.output) && (tResult.output.%GetTypeOf("questions") = "array"), "the confirm's answer carries the questions: " _ tResult.%ToJSON())
    If '$IsObject(tResult.output) || (tResult.output.%GetTypeOf("questions") '= "array") Quit
    Do $$$AssertEquals(tResult.output.questions.%ToJSON(), ..Expected(..#GONE _ ".cls", "2", 1, tQuestion).%ToJSON(), "at step 2, with the class's text")
    Set tStored = ##class(OcuPilot.Test.ExplorerWrite).StoredText(tProposal.proposalId, .tLedgerRows)
    Do $$$AssertTrue((tStored [ (..#GONE _ ".cls")) && (tStored '[ tQuestion), "the stored proposal and its ledger rows hold none of the text: " _ $Extract(tStored, 1, 300))

    Set tAudit = ##class(OcuPilot.Test.SslSinks).AuditSince(tMark)
    Do $$$AssertTrue(tAudit '= "", "the two confirms left audit rows to read")
    Do $$$AssertTrue(tAudit '[ tQuestion, "no audit row since the first mint holds the text")
    Do $$$AssertEquals(##class(OcuPilot.Test.SourceControlSave).LogLine(tLog, tFrom, tQuestion), "", "and no line of the message log does")
}

/// <p>AC5: the Classes list's own delete, over HTTP as the account, answers the class's question as <code>output.questions</code>
/// beside its per-document result, and the class's hook ran under that account in the web process.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.ExplorerWrite</class>'s <code>WriteOutput</code> answers only the
/// per-document results -- this goes red.</p>
Method TestThePersonsDeleteAnswersTheQuestionOnTheScreen()
{
    Set tQuestion = $Parameter(..#SC, "QUESTION")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#NAMESPACE, ..#PERSON), "a probe class is saved to delete")
    Do ..Arm(1)
    Do ##class(OcuPilot.Test.ExplorerWrite).Act("classes", ..#NAMESPACE, "delete", ..#PERSON _ ".cls", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the delete answers 200: " _ ##class(OcuPilot.Test.ExplorerWrite).Json(tBody))
    If '$IsObject(tBody) || '$IsObject(tBody.%Get("output")) || (tBody.output.%GetTypeOf("questions") '= "array") Do $$$AssertTrue(0, "the output carries the questions: " _ ##class(OcuPilot.Test.ExplorerWrite).Json(tBody)) Quit
    Do $$$AssertEquals(tBody.output.questions.%ToJSON(), ..Expected(..#PERSON _ ".cls", "2", 1, tQuestion).%ToJSON(), "its output carries the class's question at step 2")
    Do $$$AssertEquals(tBody.output.documents.%Get(0).deleted, 1, "beside the per-document result")
    Set tEntries = $ClassMethod(..#SC, "Entries", ..#NAMESPACE)
    Set tWrong = ""
    Set tIterator = tEntries.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If (tEntry.hook = "UserAction") && ((tEntry.user '= ##class(OcuPilot.Test.Http).GetTestUsername()) || (tEntry.job = $Job)) Set tWrong = tWrong _ " " _ tEntry.%ToJSON()
    }
    Do $$$AssertEquals(tWrong, "", "and the class's UserAction ran as " _ ##class(OcuPilot.Test.Http).GetTestUsername() _ " in the web process, not this one")
}

/// <p>The two lists' answer tools are a person's alone (AD-53): unadvertised, bodyless and not destructive, served by the
/// <code>answer</code> row action over the one declared step and answer, on the source-code port's <code>ANSWER</code> write
/// and its <code>ANSWERDOCS</code> read, with their keys in the baseline and disabled.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.ExplorerSourceControlAnswer.ADVERTISED</parameter> 1 -- the
/// advertised leg goes red; <code>explorer.classes.answer</code> removed from <class>OcuPilot.Kernel.Governance.Baseline</class>
/// -- its key leg goes red.</p>
Method TestTheAnswerToolsArePersonOnlyAndShipDisabled()
{
    Set tPort = "OcuPilot.Port.AtelierPort"
    For tCase = $ListBuild("OcuPilot.Screen.Tool.ExplorerClassAnswer", "explorer.classes.answer", "Classes", "ExplorerClassList"), $ListBuild("OcuPilot.Screen.Tool.ExplorerRoutineAnswer", "explorer.routines.answer", "Routines", "ExplorerRoutineList") {
        Set tTool = $List(tCase, 1)
        Set tName = $List(tCase, 2)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $Piece($Parameter(tTool, "DESCRIPTORCLASS"), ".", *), tName _ "|" _ tPort _ "|" _ $List(tCase, 3) _ "|" _ $List(tCase, 4), tName _ ": name, port, endpoint and screen")
        Do $$$AssertEquals($ClassMethod(tTool, "Advertised") _ $ClassMethod(tTool, "Destructive") _ $ClassMethod(tTool, "SendsBody") _ "|" _ $ClassMethod(tTool, "WriteType") _ "|" _ $ClassMethod(tTool, "ReadType"), "000|ANSWER|ANSWERDOCS", tName _ ": unadvertised, not destructive, bodyless, and its write and read types")
        Do $$$AssertEquals($ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionValueNames", "answer")) _ "|" _ $ListToString($ClassMethod(tTool, "SettableFields")), "answer|step,answer|step,answer", tName _ ": the row action, its values and its arguments")
        Do $$$AssertEquals(+$Parameter(tTool, "READSVALUES"), 1, tName _ ": the step and the answer are checked before the fresh read, so a bad value reaches no route")
        Do ##class(OcuPilot.Kernel.Governance.Baseline).Seed(tName, .tListed)
        Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Resolve(tName, "write", .tEnabled, .tSource)
        Do $$$AssertEquals(tListed _ " " _ ''$Get(tEnabled), "1 0", tName _ ": its key is in the baseline and ships disabled")
    }
}

/// <p>AC5 and AC7: a person's answer over HTTP runs the class's <code>AfterUserAction</code> as that person and answers no
/// output, although the tool's key ships disabled (a person's action asks none); a step or answer outside those the dialog
/// sends is refused 400 with no hook run; and an answer on a list whose namespace's routines database the account cannot
/// write is refused before the hook.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.ExplorerSourceControlAnswer</class>'s <code>ScreenActionDelta</code>
/// accepts any step -- the bad-step leg goes red; its <code>WriteOutput</code> answers the write's result -- the no-output leg
/// goes red.</p>
Method TestAnAnswerThroughTheScreenRouteRunsTheClassAndRefusesABadValue()
{
    Set tName = ..#GONE _ ".cls"
    Do ..Arm(1)
    For tCase = $ListBuild("3", "1"), $ListBuild("7", "3"), $ListBuild("", "1"), $ListBuild("7", "") {
        Do $ClassMethod(..#SC, "Clear", ..#NAMESPACE)
        Do ..Answer(tName, $List(tCase, 1), $List(tCase, 2), .tStatus, .tBody)
        Do $$$AssertEquals(tStatus, 400, "step '" _ $List(tCase, 1) _ "' with answer '" _ $List(tCase, 2) _ "' is refused: " _ ..Json(tBody))
        Do $$$AssertTrue(..Json(tBody) [ "TOOL.ARGUMENTS", "by the tool's own values check, before the port: " _ ..Json(tBody))
        Do $$$AssertEquals(..Extras($ClassMethod(..#SC, "Entries", ..#NAMESPACE), "AfterUserAction"), "", "and no hook runs")
    }
    Do $ClassMethod(..#SC, "Clear", ..#NAMESPACE)
    Do ..Answer(tName, "2", "0", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "a deleted document's No is answered 200 although the tool's key ships disabled: " _ ..Json(tBody))
    Do $$$AssertTrue($IsObject(tBody) && (tBody.%GetTypeOf("output") = "unassigned"), "with no output: " _ ..Json(tBody))
    Set tEntries = $ClassMethod(..#SC, "Entries", ..#NAMESPACE)
    Do $$$AssertEquals(..Extras(tEntries, "AfterUserAction"), "1|2|0", "and the class's AfterUserAction ran once at that step with that answer: " _ tEntries.%ToJSON())
    Set tWrong = ""
    Set tIterator = tEntries.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If (tEntry.hook = "AfterUserAction") && ((tEntry.user '= ##class(OcuPilot.Test.Http).GetTestUsername()) || (tEntry.job = $Job)) Set tWrong = tWrong _ " " _ tEntry.%ToJSON()
    }
    Do $$$AssertEquals(tWrong, "", "as " _ ##class(OcuPilot.Test.Http).GetTestUsername() _ " in the web process, not this one")
}

/// <p>AC7: an account that holds <code>%Development:USE</code> and READ on the install namespace's routines database, and no
/// WRITE there, is refused the answer on that namespace, naming that database's WRITE pair; the same account, which holds
/// WRITE on <code>USER</code>'s, is accepted there and its hook runs under its own name.</p>
/// <p>Mutation (Rule 19): the answer tools' <code>ArgumentPairs</code> answers no pair and
/// <parameter>OcuPilot.Port.AtelierPort.TYPEANSWER</parameter> leaves <code>Invoke</code>'s write types together -- the refusal leg
/// goes red. Either alone leaves it green, since the screen's gate and the port each refuse the same pair.</p>
Method TestAnAnswerNeedsWriteOnTheNamespacesRoutinesDatabase()
{
    Set tFixture = "OcuPilot.Test.DeveloperFloorFixture"
    Set tName = ..#GONE _ ".cls"
    Set tPassword = $ClassMethod(tFixture, "NewPassword")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "EnsurePrincipal", tPassword, "", .tUser), "the account is created")
    If tUser = "" Quit
    Set tSC = $ClassMethod(tFixture, "Composed", tUser, .tComposed)
    Set tCode = $ClassMethod(tFixture, "CodeResource")
    Do $$$AssertTrue($$$ISOK(tSC) && $ClassMethod(tFixture, "Holds", tComposed, "%Development", "USE") && $ClassMethod(tFixture, "Holds", tComposed, tCode, "READ") && '$ClassMethod(tFixture, "Holds", tComposed, tCode, "WRITE"), "it holds %Development:USE and READ, and not WRITE, on " _ tCode)
    Do $$$AssertTrue($ClassMethod(tFixture, "Holds", tComposed, "%DB_USER", "WRITE"), "and it holds WRITE on %DB_USER")
    Do ..AnswerAs(tUser, tPassword, ##class(OcuPilot.Install.Installer).ResolveNamespace(), tName, "7", "1", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 403, "an answer in the install namespace is refused: " _ $Extract(tText, 1, 300))
    Do $$$AssertTrue((tText [ "AUTH.NOPRIVILEGE") && (tText [ (tCode _ ":WRITE")), "naming the routines database's WRITE pair: " _ $Extract(tText, 1, 300))
    Do ..Arm(1)
    Do ..AnswerAs(tUser, tPassword, ..#NAMESPACE, tName, "7", "1", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 200, "and in " _ ..#NAMESPACE _ " it is accepted: " _ $Extract(tText, 1, 300))
    Set tEntries = $ClassMethod(..#SC, "Entries", ..#NAMESPACE)
    Do $$$AssertEquals(..Extras(tEntries, "AfterUserAction"), "1|7|1", "and the hook ran once: " _ tEntries.%ToJSON())
    Set tWrong = ""
    Set tIterator = tEntries.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If (tEntry.hook = "AfterUserAction") && (tEntry.user '= tUser) Set tWrong = tWrong _ " " _ tEntry.%ToJSON()
    }
    Do $$$AssertEquals(tWrong, "", "under " _ tUser)
}

/// <p>The Classes list's <code>answer</code> action over HTTP as the suite's own account, <var>pStep</var> and
/// <var>pAnswer</var> as the dialog sends them: the status and the parsed envelope.</p>
ClassMethod Answer(pDocument As %String, pStep As %String, pAnswer As %String, Output pStatus As %Integer, Output pBody)
{
    Do ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/explorer.classes/action?ns=" _ ..#NAMESPACE, .pStatus, .pBody, ..AnswerBody(pDocument, pStep, pAnswer))
}

/// <p>The same answer as <var>pUser</var> in <var>pNamespace</var>: the status and the response text.</p>
ClassMethod AnswerAs(pUser As %String, pPassword As %String, pNamespace As %String, pDocument As %String, pStep As %String, pAnswer As %String, Output pStatus As %Integer, Output pText As %String)
{
    Do $ClassMethod("OcuPilot.Test.DeveloperFloorFixture", "Call", "POST", "/screens/explorer.classes/action?ns=" _ pNamespace, pUser, pPassword, .pStatus, .pText, .tHeaders, ..AnswerBody(pDocument, pStep, pAnswer))
}

/// <p>The request body of an answer.</p>
ClassMethod AnswerBody(pDocument As %String, pStep As %String, pAnswer As %String) As %String
{
    Set tValues = {}
    Do tValues.%Set("step", pStep, "string")
    Do tValues.%Set("answer", pAnswer, "string")
    Set tRequest = {}
    Do tRequest.%Set("action", "answer", "string")
    Do tRequest.%Set("id", pDocument, "string")
    Do tRequest.%Set("values", tValues)
    Quit tRequest.%ToJSON()
}

/// <p>A parsed envelope as text, for an assertion message.</p>
ClassMethod Json(pBody) As %String
{
    Quit $Select($IsObject(pBody): $Extract(pBody.%ToJSON(), 1, 400), 1: "")
}

}
