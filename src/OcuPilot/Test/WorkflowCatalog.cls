/// <p>The guided-workflow catalog and its pure rules (Story 20.12, AD-66): the nine ids, every tool a step names
/// resolving as the kind it is listed under, each workflow offered by a built screen's prompt, the three
/// <code>WORKFLOW.*</code> sentences, <method>OcuPilot.Kernel.Agent.Workflow.WriteRefusal</method>'s three answers,
/// <method>OcuPilot.Kernel.Agent.Workflow.Previous</method>'s projection and cap, and
/// <method>OcuPilot.Kernel.Agent.Workflow.Exchange</method>'s members. It also holds that the tool registry lists no tool spelled <code>workflow</code>.</p>
/// <p>Spawns nothing and writes nothing, so it needs no arming variable. It reads the compiled tool and screen
/// registries.</p>
Class OcuPilot.Test.WorkflowCatalog Extends %UnitTest.TestCase
{

Parameter WORKFLOW = "OcuPilot.Kernel.Agent.Workflow";

Parameter ERRORS = "OcuPilot.Api.WorkflowError";

Parameter REGISTRY = "OcuPilot.Screen.Tool.Registry";

/// <p>The catalog's nine ids, in order.</p>
Parameter IDS = "recoverproduction,resendmessages,tracemessage,systemhealth,securityposture,slowquery,compileclass,reviewclass,newproject";

/// <p>The names of the eleven iris-execute-mcp-v2 prompts the catalog adapts; no id is one of them.</p>
Parameter HARVESTED = "recover-stuck-production,resend-failed-messages,trace-message-flow,check-system-health,run-external-backup,diagnose-slow-query,deploy-and-test-class,objectscript-review,promote-environment-change,audit-security-posture,provision-project-environment";

/// <p>Every step of workflow <var>pId</var>, as a <class>%DynamicArray</class>.</p>
Method StepsOf(pId As %String) As %DynamicArray
{
    Set tEntry = $ClassMethod(..#WORKFLOW, "Lookup", pId, .tFound)
    Do $$$AssertTrue(tFound, pId _ " is in the catalog")
    Quit $Select(tFound: tEntry.%Get("steps"), 1: [])
}

/// <p>Member <var>pName</var> of <var>pStep</var> as JSON text, or <code>""</code> when the step has none.</p>
ClassMethod Member(pStep As %DynamicObject, pName As %String) As %String
{
    Quit $Select(pStep.%GetTypeOf(pName) = "array": pStep.%Get(pName).%ToJSON(), 1: "")
}

/// <p>The catalog holds the nine ids, in order, each a lower-case word, none a harvested prompt's name; every
/// workflow carries a purpose, steps that each say something, and a finish; every text is ASCII and names no
/// tool under the sibling projects' prefix.</p>
/// <p>Mutation: rename one id in the catalog -> this goes red.</p>
Method TestTheNineIdsEqualTheRoster()
{
    Set tIds = $ClassMethod(..#WORKFLOW, "Ids")
    Do $$$AssertEquals($ListToString(tIds, ","), ..#IDS, "the catalog holds the nine ids, in order")
    For tI = 1:1:$ListLength(tIds) {
        Set tId = $List(tIds, tI)
        Do $$$AssertTrue($Match(tId, "^[a-z][a-z0-9]*$"), tId _ " is a lower-case word")
        Do $$$AssertEquals($ListFind($ListFromString(..#HARVESTED, ","), tId), 0, tId _ " is no harvested prompt's name")
        Set tEntry = $ClassMethod(..#WORKFLOW, "Lookup", tId, .tFound)
        If 'tFound Continue
        Do $$$AssertTrue((tEntry.%GetTypeOf("purpose") = "string") && (tEntry.%Get("purpose") '= "") && (tEntry.%GetTypeOf("finish") = "string") && (tEntry.%Get("finish") '= ""), tId _ " has a purpose and a finish")
        Set tSteps = tEntry.%Get("steps")
        Do $$$AssertTrue(tSteps.%Size() > 0, tId _ " has steps")
        Set tIterator = tSteps.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            Do $$$AssertTrue((tStep.%GetTypeOf("say") = "string") && (tStep.%Get("say") '= ""), tId _ " step " _ (tIndex + 1) _ " says something")
        }
        Set tJson = tEntry.%ToJSON()
        Set tOutside = 0
        For tAt = 1:1:$Length(tJson) If ($Ascii(tJson, tAt) < 32) || ($Ascii(tJson, tAt) > 126) Set tOutside = tOutside + 1
        Do $$$AssertEquals(tOutside, 0, tId _ " is printable ASCII throughout")
        Do $$$AssertEquals(tJson [ ("iris" _ "_"), 0, tId _ " names no tool under the sibling prefix")
    }
    Set tEntry = $ClassMethod(..#WORKFLOW, "Lookup", "nosuch", .tFound)
    Do $$$AssertEquals(tFound _ "|" _ tEntry, "0|", "an unknown id finds nothing")
    Set tEntry = $ClassMethod(..#WORKFLOW, "Lookup", "", .tFound)
    Do $$$AssertEquals(tFound, 0, "and so does an empty one")
    Set tEntry = $ClassMethod(..#WORKFLOW, "Lookup", "COMPILECLASS", .tFound)
    Do $$$AssertEquals(tFound, 0, "an id is matched exactly, case included")
}

/// <p>Every name a step lists under <code>reads</code> resolves, through its wire name, as a <code>read</code> tool,
/// and every name under <code>writes</code> as a <code>write</code> tool; <method>Writes</method> is the union of
/// the steps' writes, and a read-only workflow has none.</p>
/// <p>Mutation: a step names <code>interop.productions.recoverx</code> -> this goes red.</p>
Method TestEveryNamedToolResolvesAsItsKind()
{
    Set tReads = 0
    Set tWrites = 0
    Set tIds = $ClassMethod(..#WORKFLOW, "Ids")
    For tI = 1:1:$ListLength(tIds) {
        Set tId = $List(tIds, tI)
        Set tUnion = ""
        Set tSteps = ..StepsOf(tId)
        Set tIterator = tSteps.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            For tMember = "reads", "writes" {
                If tStep.%GetTypeOf(tMember) '= "array" Continue
                Set tNames = tStep.%Get(tMember).%GetIterator()
                While tNames.%GetNext(.tNameIndex, .tName) {
                    Set tSC = $ClassMethod(..#REGISTRY, "ResolveWire", $ClassMethod(..#REGISTRY, "WireName", tName), .tTool)
                    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject(tTool), tId _ " step " _ (tIndex + 1) _ ": " _ tName _ " resolves")
                    If '$IsObject(tTool) Continue
                    Do $$$AssertEquals(tTool.%Get("kind") _ "|" _ tTool.%Get("name"), $Select(tMember = "reads": "read", 1: "write") _ "|" _ tName, tId _ ": " _ tName _ " is a " _ $Select(tMember = "reads": "read", 1: "write") _ " tool")
                    If tMember = "reads" Set tReadSeen(tName) = 1
                    If tMember = "writes" {
                        Set tWriteSeen(tName) = 1
                        If '$ListFind(tUnion, tName) Set tUnion = tUnion _ $ListBuild(tName)
                    }
                }
            }
        }
        Do $$$AssertEquals($ListToString($ClassMethod(..#WORKFLOW, "Writes", tId), ","), $ListToString(tUnion, ","), tId _ ": Writes is the union of the steps' writes, in step order")
    }
    Set tName = ""
    For {
        Set tName = $Order(tReadSeen(tName))
        If tName = "" Quit
        Set tReads = tReads + 1
    }
    For {
        Set tName = $Order(tWriteSeen(tName))
        If tName = "" Quit
        Set tWrites = tWrites + 1
    }
    Do $$$AssertTrue((tReads > 0) && (tWrites > 0), "the catalog names read tools (" _ tReads _ ") and write tools (" _ tWrites _ ")")
    For tId = "tracemessage", "securityposture", "slowquery", "reviewclass" {
        Do $$$AssertEquals($ListLength($ClassMethod(..#WORKFLOW, "Writes", tId)), 0, tId _ " names no write tool")
    }
    Do $$$AssertEquals($ListLength($ClassMethod(..#WORKFLOW, "Writes", "nosuch")), 0, "an unknown id names none")
}

/// <p>Every workflow is offered by the suggested prompt of at least one built screen, and every prompt's
/// <code>workflow</code> names a catalog id.</p>
/// <p>Mutation: drop a descriptor's workflow prompt -> this goes red naming the workflow.</p>
Method TestEveryWorkflowIsOfferedByABuiltScreen()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tList)
    Do $$$AssertStatusOK(tSC, "the registry enumerates the descriptors")
    For tI = 1:1:$ListLength(tList) {
        Set tClass = $List(tList, tI)
        If $$$ISERR($ClassMethod(tClass, "DeclarationJson", .tDeclaration)) || '$IsObject($Get(tDeclaration)) Continue
        If tDeclaration.%Get("built") '= 1 Continue
        If tDeclaration.%GetTypeOf("suggestedPrompts") '= "array" Continue
        Set tPrompts = tDeclaration.%Get("suggestedPrompts").%GetIterator()
        While tPrompts.%GetNext(.tIndex, .tPrompt) {
            If tPrompt.%GetTypeOf("workflow") = "unassigned" Continue
            Set tOffered(tPrompt.%Get("workflow")) = $Get(tOffered(tPrompt.%Get("workflow"))) + 1
            Do $$$AssertTrue($ListFind($ClassMethod(..#WORKFLOW, "Ids"), tPrompt.%Get("workflow")) > 0, tClass _ " prompt " _ (tIndex + 1) _ " names a catalog workflow")
        }
    }
    Set tIds = $ClassMethod(..#WORKFLOW, "Ids")
    For tI = 1:1:$ListLength(tIds) {
        Do $$$AssertTrue($Get(tOffered($List(tIds, tI))) > 0, $List(tIds, tI) _ " is offered by a built screen's prompt")
    }
}

/// <p>Each <code>WORKFLOW.*</code> code resolves to its sentence directly and through
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method>, and a code of another family resolves to none here.</p>
/// <p>Mutation: reword <parameter>REASONNOTASTEP</parameter> -> this goes red.</p>
Method TestEachCodeResolvesToItsSentence()
{
    Set tExpected = $ListBuild("WORKFLOW.UNKNOWN|That guided workflow is not one OcuPilot offers.", "WORKFLOW.NOTASTEP|This guided workflow makes no change with that tool; describe the change instead of proposing it.", "WORKFLOW.ONECHANGE|This turn has already proposed its change; end the turn so the user can confirm it before the next.")
    Set tCodes = $ClassMethod(..#ERRORS, "Codes")
    Do $$$AssertEquals($ListLength(tCodes), 3, "three codes")
    For tI = 1:1:$ListLength(tExpected) {
        Set tCode = $Piece($List(tExpected, tI), "|", 1)
        Set tSentence = $Piece($List(tExpected, tI), "|", 2, *)
        Do $$$AssertTrue($ListFind(tCodes, tCode) > 0, tCode _ " is declared")
        Do $$$AssertEquals($ClassMethod(..#ERRORS, "ReasonFor", tCode), tSentence, tCode _ " carries its sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tSentence, tCode _ " reaches a tool result through ReasonForToolCode")
    }
    Do $$$AssertEquals($ClassMethod(..#ERRORS, "ReasonFor", "TOOL.UNKNOWN"), "", "another family's code has no sentence here")
    Do $$$AssertEquals($Parameter(..#WORKFLOW, "NOTASTEP") _ "|" _ $Parameter(..#WORKFLOW, "ONECHANGE"), $Parameter(..#ERRORS, "NOTASTEP") _ "|" _ $Parameter(..#ERRORS, "ONECHANGE"), "the kernel's two refusal codes are the Api vocabulary's")
}

/// <p><method>OcuPilot.Kernel.Agent.Workflow.WriteRefusal</method> answers <code>""</code> for a step's write on a
/// turn holding no proposal, <code>WORKFLOW.NOTASTEP</code> for a tool no step names whatever the turn holds, and
/// <code>WORKFLOW.ONECHANGE</code> for a step's write once the turn holds one.</p>
/// <p>Mutation: <method>WriteRefusal</method> tests <code>pMinted > 1</code> -> the second leg goes red.</p>
Method TestWriteRefusalAnswersItsThreeCodes()
{
    Set tStep = "explorer.classes.save"
    Do $$$AssertEquals($ClassMethod(..#WORKFLOW, "WriteRefusal", "compileclass", tStep, 0), "", "a step's write on an empty turn passes")
    Do $$$AssertEquals($ClassMethod(..#WORKFLOW, "WriteRefusal", "compileclass", tStep, 1), "WORKFLOW.ONECHANGE", "and is the second change once the turn holds one")
    Do $$$AssertEquals($ClassMethod(..#WORKFLOW, "WriteRefusal", "compileclass", tStep, 3), "WORKFLOW.ONECHANGE", "however many it holds")
    Do $$$AssertEquals($ClassMethod(..#WORKFLOW, "WriteRefusal", "compileclass", "permissions.users.delete", 0), "WORKFLOW.NOTASTEP", "a tool no step names is no step")
    Do $$$AssertEquals($ClassMethod(..#WORKFLOW, "WriteRefusal", "compileclass", "permissions.users.delete", 1), "WORKFLOW.NOTASTEP", "whether or not the turn holds a proposal")
    Do $$$AssertEquals($ClassMethod(..#WORKFLOW, "WriteRefusal", "securityposture", tStep, 0), "WORKFLOW.NOTASTEP", "a read-only workflow names no write")
    Do $$$AssertEquals($ClassMethod(..#WORKFLOW, "WriteRefusal", "nosuch", tStep, 0), "WORKFLOW.NOTASTEP", "nor does an unknown one")
    Do $$$AssertEquals($ClassMethod(..#WORKFLOW, "WriteRefusal", "compileclass", "explorer.classes.compile", 0), "", "the workflow's second write tool is a step too")
}

/// <p><method>OcuPilot.Kernel.Agent.Workflow.Previous</method> projects each wire row to
/// <code>{tool, state, closedReason, readBack}</code> -- the read-back's verdict, or JSON <code>null</code> --
/// keeps nothing else of the row, and reports at most <parameter>PREVIOUSMAX</parameter>.</p>
/// <p>Mutation: <method>Previous</method> copies the row's <code>target</code> -> the projection leg goes red; it
/// reports every row -> the cap leg goes red.</p>
Method TestPreviousProjectsAtMostTenRows()
{
    Set tRows = []
    Set tOne = {"proposalId": "p1", "tool": "explorer.classes.save", "state": "confirmed", "closedReason": "", "rationale": "SECRETISH", "unchanged": [], "target": {"type": "class", "scope": "USER", "id": "A.B"}}
    Do tOne.%Set("readBack", {"verdict": "matches", "fields": ["Text"], "written": []})
    Do tRows.%Push(tOne)
    Set tTwo = {"proposalId": "p2", "tool": "explorer.classes.compile", "state": "canceled", "closedReason": "you", "readBack": null}
    Do tRows.%Push(tTwo)
    Do tRows.%Push("not an object")
    Set tPrevious = $ClassMethod(..#WORKFLOW, "Previous", tRows)
    Do $$$AssertEquals(tPrevious.%Size(), 2, "a row that is no object is skipped")
    Do $$$AssertEquals(tPrevious.%Get(0).%ToJSON(), "{""tool"":""explorer.classes.save"",""state"":""confirmed"",""closedReason"":"""",""readBack"":""matches""}", "a confirmed row reads its tool, state and verdict only")
    Do $$$AssertEquals(tPrevious.%Get(1).%ToJSON(), "{""tool"":""explorer.classes.compile"",""state"":""canceled"",""closedReason"":""you"",""readBack"":null}", "and a canceled one its reason, with a null read-back")
    Do $$$AssertEquals(tPrevious.%ToJSON() [ "SECRETISH", 0, "no rationale, target or argument reaches the result")

    Set tMany = []
    For tI = 1:1:14 Do tMany.%Push({"tool": "explorer.classes.save", "state": "live", "closedReason": ""})
    Set tCapped = $ClassMethod(..#WORKFLOW, "Previous", tMany)
    Do $$$AssertEquals(tCapped.%Size(), $Parameter(..#WORKFLOW, "PREVIOUSMAX"), "fourteen rows report the cap")
    Do $$$AssertEquals($Parameter(..#WORKFLOW, "PREVIOUSMAX"), 10, "which is ten")
    Set tNone = $ClassMethod(..#WORKFLOW, "Previous", [])
    Do $$$AssertEquals(tNone.%Size(), 0, "no rows report none")
    Set tNone = $ClassMethod(..#WORKFLOW, "Previous", "")
    Do $$$AssertEquals(tNone.%Size(), 0, "nor does no array")
}

/// <p><method>OcuPilot.Kernel.Agent.Workflow.Exchange</method> answers <code>{workflow, purpose, steps, finish,
/// previous}</code>: the catalog's constants with each step numbered from 1 and its reads and writes, and the
/// array it was given as <code>previous</code>; <code>""</code> for an id the catalog does not hold.</p>
/// <p>Mutation: <method>Exchange</method> drops a step's <code>writes</code> -> the member leg goes red; it answers
/// the finish as the purpose -> the purpose leg goes red.</p>
Method TestExchangeCarriesTheCatalogAndPrevious()
{
    Set tPrevious = $ClassMethod(..#WORKFLOW, "Previous", [{"tool": "explorer.classes.save", "state": "confirmed", "closedReason": "", "readBack": {"verdict": "matches"}}])
    Set tResult = ##class(%DynamicAbstractObject).%FromJSON($ClassMethod(..#WORKFLOW, "Exchange", "compileclass", tPrevious))
    Do $$$AssertEquals(tResult.%Get("workflow"), "compileclass", "it names the workflow")
    Set tEntry = $ClassMethod(..#WORKFLOW, "Lookup", "compileclass")
    Do $$$AssertEquals(tResult.%Get("purpose"), tEntry.%Get("purpose"), "and its purpose")
    Do $$$AssertEquals(tResult.%Get("finish"), tEntry.%Get("finish"), "and its finish")
    Do $$$AssertEquals(tResult.steps.%Size(), tEntry.steps.%Size(), "every step is there")
    For tI = 0:1:tEntry.steps.%Size() - 1 {
        Set tStep = tResult.steps.%Get(tI)
        Set tSource = tEntry.steps.%Get(tI)
        Do $$$AssertEquals(tStep.%Get("step") _ "|" _ tStep.%Get("say"), (tI + 1) _ "|" _ tSource.%Get("say"), "step " _ (tI + 1) _ " is numbered and says the catalog's text")
        Do $$$AssertEquals(..Member(tStep, "reads") _ "|" _ ..Member(tStep, "writes"), ..Member(tSource, "reads") _ "|" _ ..Member(tSource, "writes"), "step " _ (tI + 1) _ " names the catalog's reads and writes")
    }
    Do $$$AssertEquals(tResult.steps.%Get(1).%Get("writes").%ToJSON(), "[""explorer.classes.save""]", "the second step names the save")
    Do $$$AssertEquals(tResult.%Get("previous").%ToJSON(), tPrevious.%ToJSON(), "previous is the array it was given")
    Do $$$AssertEquals(##class(%DynamicAbstractObject).%FromJSON($ClassMethod(..#WORKFLOW, "Exchange", "compileclass")).previous.%Size(), 0, "and empty when it was given none")
    Do $$$AssertEquals($ClassMethod(..#WORKFLOW, "Exchange", "nosuch", []), "", "an unknown id has no result")
}

/// <p>The synthetic <code>workflow</code> call is OcuPilot's own, so a model call by that name is unknown (AD-11 rule 1)
/// only while the production tool registry holds no tool whose wire name is <code>workflow</code>: it resolves none,
/// and none of its listed tools spells that name.</p>
/// <p>Mutation: a registered tool's wire name is <code>workflow</code> -> this goes red.</p>
Method TestNoRegisteredToolIsNamedWorkflow()
{
    Set tSC = $ClassMethod(..#REGISTRY, "ResolveWire", "workflow", .tTool)
    Do $$$AssertStatusOK(tSC, "the registry resolves a wire name")
    Do $$$AssertEquals($IsObject(tTool), 0, "and resolves none for workflow")
    Set tSC = $ClassMethod(..#REGISTRY, "ListTools", .tTools)
    Do $$$AssertStatusOK(tSC, "the registry lists its tools")
    Set tNamed = 0
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If $ClassMethod(..#REGISTRY, "WireName", tEntry.name) = "workflow" Set tNamed = tNamed + 1
    }
    Do $$$AssertEquals(tNamed, 0, "and no listed tool is spelled workflow")
}

}
