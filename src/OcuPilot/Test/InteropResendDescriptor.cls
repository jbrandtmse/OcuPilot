/// <p>Pins Story 20.31's declarations and its pure rules without a running production (AD-5, AD-6, AD-13, AD-22, AD-44, AD-51, AD-53,
/// AD-59, AD-62): the two tools' parameters and privilege pairs in order, their governance keys shipped disabled, the Messages list's
/// checked-row Resend capped at the port's cap and the Header tab's two row actions with their empty-state keys, the port's
/// <code>Serves</code> and <code>Pairs</code> for the four Messages types, the verdict matrix and its order, the message set's
/// refusals and canonical order, the digest's order sensitivity, every code's sentence, the set's check at the mint, and the script
/// forms.</p>
Class OcuPilot.Test.InteropResendDescriptor Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter ERROR = "OcuPilot.Api.InteropError";

Parameter RESENDTOOL = "OcuPilot.Screen.Tool.InteropMessageResend";

Parameter EDITTOOL = "OcuPilot.Screen.Tool.InteropMessageEditResend";

Parameter LISTCLASS = "OcuPilot.Screen.Descriptor.InteropMessageList";

Parameter HEADERCLASS = "OcuPilot.Screen.Descriptor.InteropMessageHeaderTab";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>The pairs of <var>pTool</var> as <code>resource:permission</code> joined by a comma.</p>
ClassMethod PairsOf(pTool As %String) As %String
{
    Set tPairs = $ClassMethod(pTool, "PrivilegePairs", "", .tResolved)
    Set tText = ""
    For tI = 1:1:$ListLength(tPairs) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(tPairs, tI), ":")
    }
    Quit $Select(tResolved: tText, 1: "unresolved")
}

/// <p>The pairs the port requires for <var>pType</var> of the Messages endpoint, as <code>resource:permission</code> joined by a comma.</p>
ClassMethod PortPairs(pType As %String) As %String
{
    Set tPairs = $ClassMethod(..#PORT, "Pairs", "Messages", pType)
    Set tText = ""
    For tI = 1:1:$ListLength(tPairs) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(tPairs, tI), ":")
    }
    Quit tText
}

/// <p>AC7: the two tools carry the parameters the plan names -- the keys, the endpoint types, the destructive and dry-run flags, the classic
/// pages, the consequence codes and the fingerprint subjects -- and their privilege pairs are the port's, in the port's order; both keys
/// ship disabled.</p>
/// <p>Mutation (Rule 19): drop <code>DRYRUN</code> from <class>OcuPilot.Screen.Tool.InteropMessageAction</class> -- the flag row goes red.</p>
Method TestTheTwoToolsDeclareWhatThePlanNames()
{
    For tCase = $ListBuild(..#RESENDTOOL, "interop.messages.resend", "RESEND", "RESENDMESSAGES", "INTEROP.MESSAGE.RESEND", "EnsPortal.MessageResend", "Verdicts,Production,Namespace,Reviewed", "Messages", "%Ens_Portal:USE,%Ens_MessageHeader:USE,%Ens_MessageResend:USE,%DB_USER:WRITE"), $ListBuild(..#EDITTOOL, "interop.messageheader.editresend", "EDIT", "EDITRESEND", "INTEROP.MESSAGE.EDITRESEND", "EnsPortal.MessageResend,EnsPortal.MessageResendEdit", "Verdict,Original,Namespace,Fields,Reviewed", "Message", "%Ens_Portal:USE,%Ens_MessageHeader:USE,%Ens_MessageContent:USE,%Ens_MessageResend:USE,%Ens_MessageEditResend:USE,%DB_USER:WRITE") {
        Set tTool = $List(tCase, 1)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $Parameter(tTool, "READTYPE") _ "|" _ $Parameter(tTool, "WRITETYPE"), $List(tCase, 2) _ "|" _ $List(tCase, 3) _ "|" _ $List(tCase, 4), tTool _ ": its name and its read and write types")
        Do $$$AssertEquals($Parameter(tTool, "CONSEQUENCECODE") _ "|" _ $Parameter(tTool, "CLASSICPAGES") _ "|" _ $Parameter(tTool, "FINGERPRINTSUBJECT"), $List(tCase, 5) _ "|" _ $List(tCase, 6) _ "|" _ $List(tCase, 7), tTool _ ": its consequence, its classic pages and its fingerprint subject")
        Do $$$AssertEquals(+$Parameter(tTool, "DESTRUCTIVE") _ "|" _ +$Parameter(tTool, "DRYRUN") _ "|" _ $ClassMethod(tTool, "IdArgument") _ "|" _ $ClassMethod(tTool, "Endpoint"), "1|1|" _ $List(tCase, 8) _ "|Messages", tTool _ ": destructive, reviewed first, and named by its target argument")
        Do $$$AssertEquals(..PairsOf(tTool), $List(tCase, 9), tTool _ ": its privilege pairs, in the port's order")
        Do $$$AssertEquals($Parameter(tTool, "WRITERESOURCE") _ ":" _ $Parameter(tTool, "WRITEPERMISSION"), "%Ens_MessageResend:USE", tTool _ ": the Resend page's own pair")
    }
    For tPage = "EnsPortal.MessageResend", "EnsPortal.MessageResendEdit" {
        Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("/csp/sys/op/" _ tPage _ ".zen"), tPage, "the portal's own resolver spells " _ tPage _ " as the tools declare it")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Governance.Baseline).Keys(.tKeys), "the shipped governance keys are read")
    If $IsObject($Get(tKeys)) {
        Do $$$AssertEquals(tKeys.%GetTypeOf("interop.messages.resend") _ "|" _ tKeys.%Get("interop.messages.resend") _ "|" _ tKeys.%GetTypeOf("interop.messageheader.editresend") _ "|" _ tKeys.%Get("interop.messageheader.editresend"), "boolean|0|boolean|0", "both keys ship disabled")
    }
    Do $$$AssertEquals(+$Parameter("OcuPilot.Screen.Tool.Write", "DRYRUN"), 0, "a write declares no dry run unless it says so")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Screen.Tool.Write", "DryRunReview", {}).%ToJSON(), "{}", "and its review is empty")
}

/// <p>AC1, AC2: the Messages list offers Resend over checked rows and no more than the port's cap of them, the Header tab offers Resend
/// and Edit and resend with Resend as its primary action, and each says what to do when its list is empty -- both ask the agent.</p>
/// <p>Mutation (Rule 19): change <code>max</code> to 101 in <class>OcuPilot.Screen.Descriptor.InteropMessageList</class> -- the cap row
/// goes red.</p>
Method TestTheScreensDeclareTheirActionsAndTheCap()
{
    Set tSC = $ClassMethod(..#LISTCLASS, "DeclarationJson", .tList)
    Do $$$AssertStatusOK(tSC, "the Messages list declares JSON")
    If $IsObject($Get(tList)) {
        Do $$$AssertEquals(tList.rowActions.%Size() _ "|" _ tList.rowActions.%Get(0).id _ "|" _ tList.multiSelect.action _ "|" _ tList.multiSelect.max, "1|resend|resend|" _ $Parameter(..#PORT, "RESENDMAX"), "the list resends its checked rows, at most the port's cap")
        Do $$$AssertEquals(tList.table.emptyNextKey _ "|" _ tList.table.emptyAgentKey, "|interopMessagesEmptyAgent", "and an empty list says to ask the agent")
    }
    Set tSC = $ClassMethod(..#HEADERCLASS, "DeclarationJson", .tHeader)
    Do $$$AssertStatusOK(tSC, "the Header tab declares JSON")
    If $IsObject($Get(tHeader)) {
        Do $$$AssertEquals(tHeader.rowActions.%Size() _ "|" _ tHeader.rowActions.%Get(0).id _ "|" _ tHeader.rowActions.%Get(1).id _ "|" _ tHeader.primaryAction.id, "2|resend|editresend|resend", "the tab resends and edits and resends, resending first")
        Do $$$AssertEquals(tHeader.table.emptyNextKey _ "|" _ tHeader.table.emptyAgentKey, "|interopMessagesEmptyAgent", "and says to ask the agent when it is empty")
    }
    Do $$$AssertEquals(+$Parameter(..#PORT, "RESENDMAX"), 100, "the cap is 100")
}

/// <p>The port serves the four Messages types of this story beside <code>LIST</code> and nothing else of the family, and asks for the pairs
/// the plan names: the viewer's, then the Resend page's, and for the edit the Contents pane's, the Resend page's and the edit page's.</p>
/// <p>Mutation (Rule 19): drop the <code>TYPEEDITRESEND</code> branch from <method>OcuPilot.Port.InteropPort.Serves</method> -- the serve
/// row goes red.</p>
Method TestThePortServesTheFourTypesAndAsksTheirPairs()
{
    For tType = "LIST", "RESEND", "RESENDMESSAGES", "EDIT", "EDITRESEND" {
        Do $$$AssertTrue($ClassMethod(..#PORT, "Serves", "Messages", tType), "Messages serves " _ tType)
    }
    For tType = "ENTRY", "ABORTMESSAGE", "ITEM", "SEND", "" {
        Do $$$AssertTrue('$ClassMethod(..#PORT, "Serves", "Messages", tType), "Messages does not serve '" _ tType _ "'")
    }
    Set tMessages = "%Ens_Portal:USE,%Ens_MessageHeader:USE"
    Do $$$AssertEquals(..PortPairs("LIST"), tMessages, "the list asks the viewer's pairs")
    Do $$$AssertEquals(..PortPairs("RESEND") _ "|" _ ..PortPairs("RESENDMESSAGES"), tMessages _ ",%Ens_MessageResend:USE|" _ tMessages _ ",%Ens_MessageResend:USE", "the resend read and write add the Resend page's")
    Do $$$AssertEquals(..PortPairs("EDIT") _ "|" _ ..PortPairs("EDITRESEND"), tMessages _ ",%Ens_MessageContent:USE,%Ens_MessageResend:USE,%Ens_MessageEditResend:USE|" _ tMessages _ ",%Ens_MessageContent:USE,%Ens_MessageResend:USE,%Ens_MessageEditResend:USE", "the edit read and write add the Contents pane's, the Resend page's and the edit page's")
}

/// <p>AC1: the verdict a message reads is the first of <code>gone</code>, <code>nobody</code>, <code>targetoff</code> (a request) or
/// <code>noreplyqueue</code> (a response) that holds, else <code>resend</code>, and each verdict has its own sentence.</p>
/// <p>Mutation (Rule 19): test <code>pBodyGone</code> before <code>pExists</code> in <method>OcuPilot.Port.InteropPort.MessageVerdict</method>
/// -- the gone-and-bodiless row goes red.</p>
Method TestTheVerdictMatrixAndItsOrder()
{
    ; type, exists, bodyGone, enabledTarget, replyQueue -> verdict
    For tCase = $ListBuild("Request", 0, 1, 0, 0, "gone"), $ListBuild("Request", 0, 0, 1, 1, "gone"), $ListBuild("Response", 0, 0, 0, 0, "gone"), $ListBuild("Request", 1, 1, 0, 0, "nobody"), $ListBuild("Request", 1, 1, 1, 1, "nobody"), $ListBuild("Response", 1, 1, 1, 1, "nobody"), $ListBuild("Request", 1, 0, 0, 1, "targetoff"), $ListBuild("Request", 1, 0, 0, 0, "targetoff"), $ListBuild("Request", 1, 0, 1, 0, "resend"), $ListBuild("Request", 1, 0, 1, 1, "resend"), $ListBuild("Response", 1, 0, 0, 0, "noreplyqueue"), $ListBuild("Response", 1, 0, 1, 0, "noreplyqueue"), $ListBuild("Response", 1, 0, 0, 1, "resend"), $ListBuild("Response", 1, 0, 1, 1, "resend") {
        Set tVerdict = $ClassMethod(..#PORT, "MessageVerdict", $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 4), $List(tCase, 5))
        Do $$$AssertEquals(tVerdict, $List(tCase, 6), $List(tCase, 1) _ " exists=" _ $List(tCase, 2) _ " bodyGone=" _ $List(tCase, 3) _ " enabled=" _ $List(tCase, 4) _ " replyQueue=" _ $List(tCase, 5))
    }
    Set tSeen = ""
    Set tWords = $ListFromString($Parameter(..#ERROR, "VERDICTS"), ",")
    Do $$$AssertEquals($ListLength(tWords), 5, "five verdicts are declared")
    For tI = 1:1:$ListLength(tWords) {
        Set tSentence = $ClassMethod(..#ERROR, "VerdictSentence", $List(tWords, tI))
        Do $$$AssertTrue((tSentence '= "") && '$ListFind(tSeen, tSentence), $List(tWords, tI) _ " has a sentence of its own")
        Set tSeen = tSeen _ $ListBuild(tSentence)
    }
    Do $$$AssertEquals($ClassMethod(..#ERROR, "VerdictSentence", "unknown") _ "|" _ $ClassMethod(..#PORT, "VerdictSentence", "gone"), "|" _ $ClassMethod(..#ERROR, "VerdictSentence", "gone"), "an unknown verdict has none, and the port says what the error class says")
}

/// <p>AC2: a set is 1 to 100 message ids, each once and in ascending order whatever the spelling; an empty set, a member of another shape
/// (<code>0x1</code>, <code>007</code>, an empty member, a decimal) and a set over the cap are refused whole; repeats fold before the
/// cap is counted. The digest of a set's verdicts changes with their order and with the production.</p>
/// <p>Mutation (Rule 19): count the members before folding repeats in <method>OcuPilot.Port.InteropPort.MessageSet</method> -- the
/// folded-repeats row goes red.</p>
Method TestTheMessageSetAndItsDigest()
{
    For tCase = $ListBuild("13", "13"), $ListBuild("2,13", "2,13"), $ListBuild("13,2,13", "2,13"), $ListBuild(" 13 , 2 ", "2,13"), $ListBuild("100,9,10", "9,10,100"), $ListBuild("9,09", ""), $ListBuild("", ""), $ListBuild("0x1", ""), $ListBuild("007", ""), $ListBuild("12,,13", ""), $ListBuild("abc", ""), $ListBuild("1.5", ""), $ListBuild("-1", ""), $ListBuild("1,2,", "") {
        Set tOK = $ClassMethod(..#PORT, "MessageSet", $List(tCase, 1), .tIds)
        Do $$$AssertEquals($Select(tOK: $ListToString(tIds, ","), 1: "") _ "|" _ tOK, $List(tCase, 2) _ "|" _ ($List(tCase, 2) '= ""), "'" _ $List(tCase, 1) _ "' is the set '" _ $List(tCase, 2) _ "'")
    }
    Set tHundred = ""
    For tI = 1:1:100 {
        Set tHundred = tHundred _ $Select(tHundred = "": "", 1: ",") _ (900000000 + tI)
    }
    Do $$$AssertTrue($ClassMethod(..#PORT, "MessageSet", tHundred, .tIds) && ($ListLength(tIds) = 100), "100 ids are a set")
    Do $$$AssertTrue('$ClassMethod(..#PORT, "MessageSet", tHundred _ ",900000101", .tIds) && (tIds = ""), "101 are refused whole")
    Do $$$AssertTrue($ClassMethod(..#PORT, "MessageSet", tHundred _ ",900000001,900000002", .tIds) && ($ListLength(tIds) = 100), "100 ids and repeats of two of them are 100")
    Set tOne = $ClassMethod(..#PORT, "ResendDigest", "Prod", "1=resend,2=gone")
    Do $$$AssertEquals($Length(tOne) _ "|" _ (tOne = $ClassMethod(..#PORT, "ResendDigest", "Prod", "1=resend,2=gone")), "64|1", "the digest is 64 hex digits and repeatable")
    Do $$$AssertTrue((tOne '= $ClassMethod(..#PORT, "ResendDigest", "Prod", "2=gone,1=resend")) && (tOne '= $ClassMethod(..#PORT, "ResendDigest", "Other", "1=resend,2=gone")) && (tOne '= $ClassMethod(..#PORT, "ResendDigest", "Prod", "1=resend,2=resend")), "and changes with the order, the production and a verdict")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("interop-message", "13,2,13"), "2,13", "the entity-reference rule names the same set in one spelling")
}

/// <p>Every code this story added has a sentence of its own through the interoperability class and through the framework's reason lookup;
/// the seven refusals and violations are among the codes, the two consequences among the consequence codes; none of the sentences
/// repeats.</p>
/// <p>Mutation (Rule 19): drop the <code>EDITSECRET</code> branch from <method>OcuPilot.Api.InteropError.ReasonFor</method> -- the sentence
/// row goes red.</p>
Method TestEveryCodeHasASentence()
{
    Set tCodes = $ListBuild("INTEROP.RESEND.NONE", "INTEROP.RESEND.CHANGED", "INTEROP.EDIT.NOTEDITABLE", "INTEROP.EDIT.NOCHANGE", "INTEROP.EDIT.FIELD", "INTEROP.EDIT.SECRET", "INTEROP.EDIT.VALUE", "INTEROP.MESSAGE.RESEND", "INTEROP.MESSAGE.EDITRESEND")
    Set tSeen = ""
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tSentence = $ClassMethod(..#ERROR, "ReasonFor", tCode)
        Do $$$AssertTrue(tSentence '= "", tCode _ " has a sentence")
        Do $$$AssertTrue('$ListFind(tSeen, tSentence), tCode _ "'s sentence is its own")
        Set tSeen = tSeen _ $ListBuild(tSentence)
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tSentence, tCode _ ": the framework's lookup says the same")
        If tI <= 7 Do $$$AssertTrue($ListFind($ClassMethod(..#ERROR, "Codes"), tCode) > 0, tCode _ " is among the codes")
    }
    Do $$$AssertTrue(($ListFind($ClassMethod(..#ERROR, "ConsequenceCodes"), "INTEROP.MESSAGE.RESEND") > 0) && ($ListFind($ClassMethod(..#ERROR, "ConsequenceCodes"), "INTEROP.MESSAGE.EDITRESEND") > 0), "the two consequence codes are among the consequence codes")
    Do $$$AssertEquals($ClassMethod(..#ERROR, "ReasonFor", "INTEROP.RESEND.NOTHING"), "", "a code this class does not declare has none")
}

/// <p>AC2: the agent's resend is checked at the mint against the port's own rule for a set, so a set the port would refuse is refused with
/// the tool's own sentence and no read; the digest only a person's action carries is not an argument of a proposal; and the edit's
/// <code>Fields</code> are an object of text values with at least one member.</p>
/// <p>Mutation (Rule 19): drop the <code>Reviewed</code> test from <method>OcuPilot.Screen.Tool.InteropMessageResend.SetProblem</method>
/// -- the digest row goes red.</p>
Method TestTheMintChecksWhatThePortWouldRefuse()
{
    Do $$$AssertEquals($ClassMethod(..#RESENDTOOL, "SetProblem", "1,2", {}), "", "a set of two ids passes")
    For tBad = "", "0x1", "1,,2", "abc" {
        Do $$$AssertTrue($ClassMethod(..#RESENDTOOL, "SetProblem", tBad, {}) [ "message ids", "'" _ tBad _ "' is refused with the sentence")
    }
    Do $$$AssertTrue($ClassMethod(..#RESENDTOOL, "SetProblem", "1", {"Reviewed": "abc"}) [ "Reviewed", "an argument carrying the digest is refused")
    Do $$$AssertTrue($ClassMethod(..#RESENDTOOL, "SetProblem", {}, {}) [ "string of message ids", "a set that is no string is refused")
    Do $$$AssertStatusOK($ClassMethod(..#EDITTOOL, "ArgumentProblem", "1", {"Fields": {"StringValue": "x"}}, .tProblem), "the edit's arguments are judged")
    Do $$$AssertEquals(tProblem, "", "an object of text passes")
    Do $$$AssertTrue(..EditProblem({"Fields": {}}) [ "at least one field", "an empty object of fields is refused")
    Do $$$AssertTrue(..EditProblem({"Fields": "text"}) [ "an object of text values", "fields that are text are refused")
    Do $$$AssertTrue(..EditProblem({"Fields": {"A": 1}}) [ "text values only", "a value that is no text is refused")
    Do $$$AssertTrue(..EditProblem({"Fields": {"A": "x"}, "Reviewed": "abc"}) [ "Reviewed", "an argument carrying the digest is refused")
}

/// <p>The edit tool's sentence for the arguments <var>pArgs</var>, <code>""</code> when they pass.</p>
ClassMethod EditProblem(pArgs As %DynamicObject) As %String
{
    Do $ClassMethod(..#EDITTOOL, "ArgumentProblem", "1", pArgs, .tProblem)
    Quit tProblem
}

/// <p>AD-59: the script of a resend is one <code>ResendDuplicatedMessage</code> line for each id the reviewed verdicts read
/// <code>resend</code> (none when the payload holds no verdicts), each id a string literal; a read, a list and an unknown type have no
/// script.</p>
/// <p>Mutation (Rule 19): drop the verdict test in <method>OcuPilot.Port.InteropPort.MessageSnippet</method> -- the held-back row goes
/// red.</p>
Method TestTheResendScriptRendersTheReviewedIds()
{
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tContext = {"payload": {"Verdicts": "1=resend,2=targetoff,3=resend"}}
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Messages", "RESENDMESSAGES", .tQuery, "", tContext)
    Do $$$AssertEquals(tSteps.%Size() _ "|" _ tSteps.%Get(0).kind, "1|objectscript", "a resend has one ObjectScript step")
    Set tText = tSteps.%Get(0).text
    Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ "ResendDuplicatedMessage(""1"", .tNew)") && (tText [ "ResendDuplicatedMessage(""3"", .tNew)") && (tText '[ """2"""), "it sends the two reviewed as resend: " _ tText)
    Set tQuery("id") = "4,5"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Messages", "RESENDMESSAGES", .tQuery, "", {"payload": {}})
    Set tText = tSteps.%Get(0).text
    Do $$$AssertTrue((tText '[ "ResendDuplicatedMessage("), "with no verdicts it sends nothing: " _ tText)
    For tType = "LIST", "RESEND", "EDIT", "UNKNOWN" {
        Do $$$AssertEquals($ClassMethod(..#PORT, "Snippet", "Messages", tType, .tQuery, "", tContext).%Size(), 0, tType _ " has no script")
    }
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Messages", "EDITRESEND") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "Messages", "RESEND"), "objectscript|", "the edit and resend has a script form and the read does not")
}

}
