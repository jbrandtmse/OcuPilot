/// <p>Pins Story 24.8's Compare namespaces over the real route and the real tool dispatch, as least-privileged principals (AD-8, AD-29,
/// AD-60, AD-61 rule 1): <code>GET /screens/explorer.namespacediff/read</code> and a turn that calls
/// <code>explorer.namespacediff.read</code>, each signed in as a principal that holds <code>%Development:USE</code> and the database
/// pairs of <code>HSCUSTOM</code> only, then as one that holds the pairs of <code>USER</code> as well. No test seam stands in for the
/// gate.</p>
/// <p>What it pins: a principal missing one namespace's pair is refused 403 naming that pair whichever namespace is the route's scope
/// and whichever is the target, and a control read of the namespace it holds is not refused; a principal holding both reads the same
/// four rows from either side, through the route and through the tool; and every refusal of the story's matrix (this namespace named
/// as the target, a bad target, an unknown target, a wide spec, a bad spec, a bad generated choice, and a pattern over the document cap
/// in either namespace) is answered at the route with its status, code and reason.</p>
/// <p>It needs <parameter>ARMINGVARIABLE</parameter> and <parameter>PROVIDERVARIABLE</parameter> armed, and the namespaces
/// <code>USER</code> and <code>HSCUSTOM</code>. Each test saves and removes the <code>OcuProbe248</code> documents in both; the
/// principals, their roles and the probe definition are removed in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.NamespaceDiffRoute Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter PROBE = "OcuPilot.Test.DevToolProbe";

Parameter FLOOR = "OcuPilot.Test.DeveloperFloorFixture";

Parameter TAG = "namespacediffroute-probe";

Parameter HERE = "USER";

Parameter THERE = "HSCUSTOM";

Parameter SPEC = "OcuProbe248.*.cls,OcuProbe248*.mac";

Parameter READ = "/screens/explorer.namespacediff/read";

Parameter HASHREAD = "/screens/explorer.documenthashes/read";

Property PreparedPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedDefinitionId = ""
    Set ..PreparedPrior = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.NamespaceDiffRoute creates IRIS users and roles and runs turn jobs against the turnprobe row, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PROVIDERVARIABLE _ " must both read 1, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = tId
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.NamespaceDiffRoute teardown left:" _ tLeft)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Set tSC = $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
    If $$$ISERR(tSC) Quit tSC
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemovePair", ..#HERE, ..#THERE), "no probe document is left from before")
    Quit $ClassMethod(..#PROBE, "MakePair", ..#HERE, ..#THERE)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemovePair", ..#HERE, ..#THERE), "the probe documents are removed from both namespaces")
    Quit $$$OK
}

/// <p>The database pairs' resources of <var>pNamespace</var> as a role grant, <code>resource:R</code> for each.</p>
ClassMethod Grants(pNamespace As %String) As %String
{
    Set tPairs = ##class(OcuPilot.Port.AtelierPort).NamespacePairs(pNamespace)
    Set tGrants = ""
    For tI = 1:1:$ListLength(tPairs) {
        Set tGrants = tGrants _ $Select(tGrants = "": "", 1: ",") _ $List($List(tPairs, tI), 1) _ ":R"
    }
    Quit tGrants
}

/// <p>Create the principal holding <code>%Development:USE</code> and the pairs of <code>HSCUSTOM</code>, and those of <code>USER</code>
/// too when <var>pBoth</var>; read back whether it holds <code>%DB_USER:READ</code> as asked, <code>%DB_HSCUSTOM:READ</code> and
/// <code>%Development:USE</code>, and no administrative resource. Answers its name.</p>
Method Principal(pBoth As %Boolean) As %String
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tGrant = "%Development:U," _ ..Grants(..#THERE) _ $Select(pBoth: "," _ ..Grants(..#HERE), 1: "")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources", 0), tGrant)
    Do $$$AssertStatusOK(tSC, "the principal is created holding " _ tGrant)
    Set tSC = $ClassMethod(..#FLOOR, "Composed", tUser, .tComposed)
    Do $$$AssertStatusOK(tSC, "its composed privileges read back")
    If $$$ISERR(tSC) Quit tUser
    Set tHeld = $ClassMethod(..#FLOOR, "Holds", tComposed, "%DB_USER", "READ") _ "|" _ $ClassMethod(..#FLOOR, "Holds", tComposed, "%DB_HSCUSTOM", "READ") _ "|" _ $ClassMethod(..#FLOOR, "Holds", tComposed, "%Development", "USE") _ "|" _ $ClassMethod(..#FLOOR, "HoldsAdministrative", tComposed)
    Do $$$AssertEquals(tHeld, (''pBoth) _ "|1|1|0", "it holds USER's pair as asked, HSCUSTOM's pair and %Development:USE, and no administrative resource")
    Quit tUser
}

/// <p>One <code>GET</code> of <var>pPath</var> with <var>pQuery</var> as <var>pUser</var>; <var>pBody</var> is the parsed answer, or
/// <code>""</code> when it is not JSON.</p>
Method Get(pUser As %String, pPath As %String, pQuery As %String, Output pStatus As %Integer, Output pBody As %DynamicObject) As %Status
{
    Set pBody = ""
    Set tSC = $ClassMethod(..#FIXTURE, "Call", "GET", pPath _ "?" _ pQuery, pUser, ..PreparedPassword, "", .pStatus, .tText, .tHeaders)
    Try { Set pBody = ##class(%DynamicAbstractObject).%FromJSON(tText) } Catch {}
    Do $$$AssertTrue($IsObject(pBody), "the answer parses: " _ $Extract(tText, 1, 200))
    Quit tSC
}

/// <p>The documents, then the changes, of <var>pBody</var>'s rows, each comma-separated, joined by <code>|</code>.</p>
ClassMethod Summary(pBody As %DynamicObject) As %String
{
    Set tDocuments = ""
    Set tChanges = ""
    Set tIterator = pBody.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tDocuments = tDocuments _ $Select(tDocuments = "": "", 1: ",") _ tRow.%Get("Document")
        Set tChanges = tChanges _ $Select(tChanges = "": "", 1: ",") _ tRow.%Get("Change")
    }
    Quit tDocuments _ "|" _ tChanges
}

/// <p>The summary the four <code>OcuProbe248</code> rows take with <code>USER</code> as the route's scope.</p>
ClassMethod UserSummary() As %String
{
    Set tHere = $Parameter("OcuPilot.Port.DevToolPort", "CHANGEONLYHERE")
    Set tThere = $Parameter("OcuPilot.Port.DevToolPort", "CHANGEONLYTHERE")
    Quit "OcuProbe248.Changed.cls,OcuProbe248.OnlyHere.cls,OcuProbe248.OnlyThere.cls,OcuProbe248Mac.mac|" _ $Parameter("OcuPilot.Port.DevToolPort", "CHANGEDIFFERS") _ "," _ tHere _ "," _ tThere _ "," _ tHere
}

/// <p>Assert <var>pBody</var>, answered <var>pStatus</var>, is a refusal <var>pHttp</var> with <var>pCode</var> and <var>pReason</var>,
/// and carries no rows.</p>
Method AssertRefused(pStatus As %Integer, pBody As %DynamicObject, pHttp As %Integer, pCode As %String, pReason As %String, pLabel As %String)
{
    Do $$$AssertEquals(+pStatus, pHttp, pLabel _ ": HTTP status")
    If '$IsObject(pBody) Quit
    Do $$$AssertEquals(pBody.%Get("code"), pCode, pLabel _ ": code")
    If pReason '= "" Do $$$AssertEquals(pBody.%Get("reason"), pReason, pLabel _ ": reason")
    Do $$$AssertEquals(pBody.%GetTypeOf("rows"), "unassigned", pLabel _ ": and no rows")
}

/// <p><b>AC3 at the real route.</b> A principal holding <code>HSCUSTOM</code>'s pairs and not <code>USER</code>'s is refused 403
/// naming <code>%DB_USER:READ</code> when <code>USER</code> is the route's scope (the shell's <code>NS.DENIED</code>, before the port) and
/// when it is the target (the port's <code>AUTH.NOPRIVILEGE</code>), and reads
/// <code>HSCUSTOM</code> through the hash screen; a principal holding both reads the diff from either side.</p>
/// <p>Mutation: skip evaluating <code>NamespacePairs(tTarget)</code> in <method>OcuPilot.Port.DevToolPort.Invoke</method> -&gt; the
/// target leg answers 200 and this goes red.</p>
Method TestEachNamespacePassesItsOwnGateAtTheRoute()
{
    Set tUser = ..Principal(0)
    Do ..Get(tUser, ..#READ, "ns=USER&target=HSCUSTOM&spec=" _ ..#SPEC, .tStatus, .tBody)
    Do ..AssertRefused(tStatus, tBody, 403, "NS.DENIED", "", "USER as the scope")
    Do $$$AssertTrue($IsObject(tBody) && $IsObject(tBody.%Get("detail")), "USER as the scope: the refusal carries its detail")
    If $IsObject(tBody) && $IsObject(tBody.%Get("detail")) Do $$$AssertEquals(tBody.detail.%Get("failedPair"), "%DB_USER:READ", "USER as the scope: names USER's pair")
    Do ..Get(tUser, ..#READ, "ns=HSCUSTOM&target=USER&spec=" _ ..#SPEC, .tStatus, .tBody)
    Do ..AssertRefused(tStatus, tBody, 403, "AUTH.NOPRIVILEGE", "", "USER as the target")
    Do $$$AssertTrue($IsObject(tBody) && $IsObject(tBody.%Get("detail")), "USER as the target: the refusal carries its detail")
    If $IsObject(tBody) && $IsObject(tBody.%Get("detail")) Do $$$AssertEquals(tBody.detail.%Get("failedPair"), "%DB_USER:READ", "USER as the target: names USER's pair")
    Do ..Get(tUser, ..#HASHREAD, "ns=HSCUSTOM&spec=OcuProbe248.OnlyThere.cls", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "control: the same principal reads HSCUSTOM's hashes")
    If $IsObject(tBody) && $IsObject(tBody.%Get("rows")) Do $$$AssertEquals(tBody.rows.%Size(), 1, "and finds the one probe document there")
    Do ..Get(tUser, ..#HASHREAD, "ns=USER&spec=OcuProbe248.OnlyHere.cls", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 403, "control: and is refused USER's hashes")

    Set tUser = ..Principal(1)
    Do ..Get(tUser, ..#READ, "ns=USER&target=HSCUSTOM&spec=" _ ..#SPEC, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "a holder of both reads the diff with USER as the scope")
    If $IsObject(tBody) && $IsObject(tBody.%Get("rows")) Do $$$AssertEquals(..Summary(tBody), ..UserSummary(), "the four documents and their changes")
    Do ..Get(tUser, ..#READ, "ns=HSCUSTOM&target=USER&spec=" _ ..#SPEC, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "and with HSCUSTOM as the scope")
    If $IsObject(tBody) && $IsObject(tBody.%Get("rows")) {
        Set tHere = $Parameter("OcuPilot.Port.DevToolPort", "CHANGEONLYHERE")
        Set tThere = $Parameter("OcuPilot.Port.DevToolPort", "CHANGEONLYTHERE")
        Do $$$AssertEquals(..Summary(tBody), "OcuProbe248.Changed.cls,OcuProbe248.OnlyHere.cls,OcuProbe248.OnlyThere.cls,OcuProbe248Mac.mac|" _ $Parameter("OcuPilot.Port.DevToolPort", "CHANGEDIFFERS") _ "," _ tThere _ "," _ tHere _ "," _ tThere, "where each change reads from that side")
    }
}

/// <p><b>AC2 at the real route.</b> A principal holding both namespaces' pairs is refused each row of the matrix with its status, code
/// and written reason and no rows: this namespace as the target in either case, a target that is empty, has a space or a slash, or is
/// unknown, a bare <code>*</code> and a malformed spec, a generated choice outside the two, and a pattern matching more than the cap in
/// the route's namespace, which is counted first (<code>Ens*.cls</code> from <code>USER</code>), and in <code>HSCUSTOM</code> alone
/// (<code>HS.*.cls</code>, a package <code>USER</code> does not map), the fault naming the namespace that exceeded it.</p>
/// <p>Mutation: move the same-namespace check after the body calls in <method>OcuPilot.Port.DevToolPort.Invoke</method> -&gt; the
/// same-namespace leg answers 200 and this goes red.</p>
Method TestEveryRefusalIsAnsweredAtTheRoute()
{
    Set tUser = ..Principal(1)
    Set tBase = "ns=USER&spec=" _ ..#SPEC
    Set tDevTool = "OcuPilot.Port.DevToolPort"
    Set tValidation = ##class(OcuPilot.Api.Error).#PORTVALIDATION
    For tTarget = "USER", "user" {
        Do ..Get(tUser, ..#READ, tBase _ "&target=" _ tTarget, .tStatus, .tBody)
        Do ..AssertRefused(tStatus, tBody, 400, tValidation, $Parameter(tDevTool, "REASONTARGETSAME"), "target " _ tTarget)
    }
    For tTarget = "", "HS%20CUSTOM", "HS%2FCUSTOM" {
        Do ..Get(tUser, ..#READ, tBase _ "&target=" _ tTarget, .tStatus, .tBody)
        Do ..AssertRefused(tStatus, tBody, 400, tValidation, $Parameter(tDevTool, "REASONTARGETSHAPE"), "target '" _ tTarget _ "'")
    }
    Do ..Get(tUser, ..#READ, tBase _ "&target=NOSUCHNS248", .tStatus, .tBody)
    Do ..AssertRefused(tStatus, tBody, 400, tValidation, $Parameter("OcuPilot.Port.AtelierPort", "REASONNAMESPACEUNKNOWN"), "unknown target")
    Do ..Get(tUser, ..#READ, "ns=USER&target=HSCUSTOM&spec=*", .tStatus, .tBody)
    Do ..AssertRefused(tStatus, tBody, 400, $Parameter("OcuPilot.Api.AtelierError", "SPECWIDE"), $Parameter("OcuPilot.Api.AtelierError", "REASONSPECWIDE"), "a bare *")
    Do ..Get(tUser, ..#READ, "ns=USER&target=HSCUSTOM&spec=OcuProbe248..x", .tStatus, .tBody)
    Do ..AssertRefused(tStatus, tBody, 400, tValidation, $Parameter(tDevTool, "REASONSPECSHAPE"), "a malformed spec")
    Do ..Get(tUser, ..#READ, tBase _ "&target=HSCUSTOM&generated=maybe", .tStatus, .tBody)
    Do ..AssertRefused(tStatus, tBody, 400, "READ.CRITERION", "", "a generated choice outside yes and no")
    For tCase = $ListBuild("USER", "HSCUSTOM", "Ens*.cls", "USER"), $ListBuild("USER", "HSCUSTOM", "HS.*.cls", "HSCUSTOM"), $ListBuild("HSCUSTOM", "USER", "HS.*.cls", "HSCUSTOM") {
        Do ..Get(tUser, ..#READ, "ns=" _ $List(tCase, 1) _ "&target=" _ $List(tCase, 2) _ "&spec=" _ $List(tCase, 3), .tStatus, .tBody)
        Set tLabel = "spec " _ $List(tCase, 3) _ " from " _ $List(tCase, 1)
        Do ..AssertRefused(tStatus, tBody, 400, $Parameter("OcuPilot.Api.AtelierError", "SPECTOOMANY"), $Parameter("OcuPilot.Api.AtelierError", "REASONSPECTOOMANY"), tLabel)
        Do $$$AssertTrue($IsObject(tBody) && $IsObject(tBody.%Get("detail")), tLabel _ ": the refusal carries its detail")
        If $IsObject(tBody) && $IsObject(tBody.%Get("detail")) {
            Do $$$AssertEquals(tBody.detail.%Get("namespace") _ "|" _ tBody.detail.%Get("max"), $List(tCase, 4) _ "|1000", tLabel _ ": names the namespace over the cap and the cap")
            Do $$$AssertTrue(+tBody.detail.%Get("count") > 1000, tLabel _ ": and a count above it")
        }
    }
}

/// <p><b>AC1 at the real route</b> (Cut and Identical, which the browser spec leaves out): a cap of two answers two rows and says so,
/// and the one document both namespaces hold alike answers no row, each over the principal's own gates.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Read.Execute</method> read its truncation as <code>0</code> -&gt; the capped read says it
/// is not truncated and this goes red.</p>
Method TestACapAndAnIdenticalDocumentAtTheRoute()
{
    Set tUser = ..Principal(1)
    Do ..Get(tUser, ..#READ, "ns=USER&target=HSCUSTOM&maxRows=2&spec=" _ ..#SPEC, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the capped read answers")
    If $IsObject(tBody) && $IsObject(tBody.%Get("rows")) {
        Do $$$AssertEquals(tBody.rows.%Size() _ "|" _ tBody.truncated, "2|1", "two rows and truncated")
        Do $$$AssertEquals($Piece(..Summary(tBody), "|", 1), "OcuProbe248.Changed.cls,OcuProbe248.OnlyHere.cls", "the first two in document order")
    }
    Do ..Get(tUser, ..#READ, "ns=USER&target=HSCUSTOM&spec=OcuProbe248.Same.cls", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the identical document's read answers")
    If $IsObject(tBody) && $IsObject(tBody.%Get("rows")) Do $$$AssertEquals(tBody.rows.%Size() _ "|" _ tBody.truncated, "0|0", "with no row and not truncated")
}

/// <p>Script one provider reply that makes every call of <var>pCalls</var> (<code>{id, name, input}</code> objects), then <code>done</code>;
/// run the turn as <var>pUser</var> over <var>pNamespace</var> and wait for it to complete. <var>pByUse</var> holds each tool result the
/// provider's second request carries, subscripted by call id, with its <code>is_error</code> flag at <code>(id, "error")</code>.</p>
Method RunTurn(pUser As %String, pNamespace As %String, pCalls As %DynamicArray, Output pByUse) As %String
{
    Kill pByUse
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG), "the probe row is armed for this turn")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(pCalls))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", pUser, ..PreparedPassword, .tStatus, .tText)
    Do $$$AssertNotEquals(tConvId, "", "the principal starts a conversation: " _ tStatus _ " " _ $Extract(tText, 1, 200))
    If tConvId = "" Quit ""
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn?ns=" _ pNamespace, pUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "StartBody", "compare the namespaces", tConvId), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "the turn starts: " _ $Extract(tText, 1, 200))
    If tStatus '= 202 Quit ""
    Set tId = ##class(%DynamicObject).%FromJSON(tText).turnId
    Set tState = $ClassMethod(..#FIXTURE, "AwaitEnd", tId, pUser, ..PreparedPassword, 90, .tView)
    Do $$$AssertEquals(tState, "completed", "the turn completes: " _ $Select($IsObject(tView): $Extract(tView.%ToJSON(), 1, 400), 1: "no view"))
    If tState '= "completed" Quit tState
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 2, "after two provider calls")
    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "messages"))
    Set tIterator = tMessages.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMessage) {
        If (tMessage.%Get("role") '= "user") || (tMessage.%GetTypeOf("content") '= "array") Continue
        Set tBlocks = tMessage.%Get("content").%GetIterator()
        While tBlocks.%GetNext(.tBlockIndex, .tBlock) {
            If tBlock.%Get("type") '= "tool_result" Continue
            Set pByUse(tBlock.%Get("tool_use_id")) = tBlock.%Get("content")
            Set pByUse(tBlock.%Get("tool_use_id"), "error") = +tBlock.%Get("is_error")
        }
    }
    Quit tState
}

/// <p>One call as the provider names it: id <var>pId</var>, the read tool, and the arguments <var>pTarget</var> and <var>pSpec</var>.</p>
ClassMethod Call(pId As %String, pTarget As %String, pSpec As %String) As %DynamicObject
{
    Set tCall = {"input": {}}
    Do tCall.%Set("id", pId, "string")
    Do tCall.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("explorer.namespacediff.read"), "string")
    Do tCall.input.%Set("target", pTarget, "string")
    Do tCall.input.%Set("spec", pSpec, "string")
    Quit tCall
}

/// <p>The parsed answer inside the data frame of the tool result <var>pContent</var>, or <code>""</code>.</p>
Method Body(pContent As %String, pLabel As %String) As %DynamicObject
{
    Set tText = $ClassMethod(..#FIXTURE, "Unwrapped", pContent, .tWrapped)
    Do $$$AssertTrue(tWrapped, pLabel _ ": the result reaches the model framed as data (AD-60): " _ $Extract(pContent, 1, 200))
    Set tParsed = ""
    Try { Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(tText) } Catch {}
    Do $$$AssertTrue($IsObject(tParsed), pLabel _ ": and parses")
    Quit tParsed
}

/// <p><b>AC4 and AC3 through the real tool dispatch.</b> A turn run over <code>HSCUSTOM</code> as the principal missing <code>USER</code>'s pair has
/// <code>explorer.namespacediff.read</code> refused <code>AUTH.NOPRIVILEGE</code> naming <code>%DB_USER:READ</code> and the turn
/// completes; a turn run as the principal holding both answers the rows the route answers, and the tool's refusals (this namespace as
/// the target, an unknown target) carry the screen's codes.</p>
/// <p>Mutation: point the descriptor's endpoint at <code>DocumentHashes</code> -&gt; the rows carry no change and this goes red.</p>
Method TestTheReadToolAnswersAsThePrincipalMayRead()
{
    Set tUser = ..Principal(0)
    Set tCalls = [(..Call("toolu_diff", ..#HERE, ..#SPEC))]
    Set tState = ..RunTurn(tUser, ..#THERE, tCalls, .tByUse)
    If tState = "completed" {
        Do $$$AssertEquals(+$Get(tByUse("toolu_diff", "error")), 1, "the principal missing USER's pair is refused the read")
        Set tRefused = ..Body($Get(tByUse("toolu_diff")), "refused")
        If $IsObject(tRefused) {
            Do $$$AssertEquals(tRefused.%Get("code"), "AUTH.NOPRIVILEGE", "with the gate's code")
            Do $$$AssertEquals($Select($IsObject(tRefused.%Get("detail")): tRefused.detail.%Get("failedPair"), 1: tRefused.%Get("failedPair")), "%DB_USER:READ", "naming USER's pair")
        }
    }

    Set tUser = ..Principal(1)
    Do ..Get(tUser, ..#READ, "ns=USER&target=HSCUSTOM&spec=" _ ..#SPEC, .tStatus, .tRoute)
    Do $$$AssertEquals(tStatus, 200, "the route answers the principal holding both")
    Set tCalls = [(..Call("toolu_diff", ..#THERE, ..#SPEC)), (..Call("toolu_same", ..#HERE, ..#SPEC)), (..Call("toolu_unknown", "NOSUCHNS248", ..#SPEC))]
    Set tState = ..RunTurn(tUser, ..#HERE, tCalls, .tByUse)
    If tState '= "completed" Quit
    Do $$$AssertEquals(+$Get(tByUse("toolu_diff", "error")), 0, "the diff is answered without error")
    Set tDiff = ..Body($Get(tByUse("toolu_diff")), "diff")
    If $IsObject(tDiff) && $IsObject(tDiff.%Get("rows")) && $IsObject(tRoute) && $IsObject(tRoute.%Get("rows")) {
        Do $$$AssertEquals(tDiff.rows.%ToJSON(), tRoute.rows.%ToJSON(), "the tool's rows are the route's")
        Do $$$AssertEquals(..Summary(tDiff), ..UserSummary(), "the four documents and their changes")
    }
    For tId = "toolu_same", "toolu_unknown" {
        Do $$$AssertEquals(+$Get(tByUse(tId, "error")), 1, tId _ ": refused")
        Set tFault = ..Body($Get(tByUse(tId)), tId)
        If $IsObject(tFault) Do $$$AssertEquals(tFault.%Get("code"), ##class(OcuPilot.Api.Error).#PORTVALIDATION, tId _ ": with the screen's code")
    }
}

}
