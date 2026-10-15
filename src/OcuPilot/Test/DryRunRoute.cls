/// <p>Pins <code>POST /screens/:screen/dryrun</code> (Story 20.31, AD-6, AD-10, AD-53): the review of a person's own action before it is
/// sent. A body the action route would not take -- unreadable, not an object, with no action, an action that is no string, a key beyond
/// the route's three -- is 400 <code>TOOL.ARGUMENTS</code> before anything is read; an unknown screen, an action the screen does not
/// declare and an action whose tool does not declare a dry run are the framework's 404; and a request that resolves answers exactly
/// <code>{rows, review}</code>, whose rows are the rows the agent's proposal card shows for the same action, while writing no proposal,
/// holding no target and sending nothing.</p>
/// <p>A secret value is refused before any read by the shared preview (<method>OcuPilot.Api.ScreenAction.Resolve</method>, pinned by
/// <class>OcuPilot.Test.ImpactRoute</class>); no tool that declares a dry run declares a secret, so this route cannot be asked for one.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the
/// answering leg needs the running probe production of <class>OcuPilot.Test.InteropResendCase</class>. One class per run.</p>
Class OcuPilot.Test.DryRunRoute Extends OcuPilot.Test.InteropResendCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter ROUTE = "/api/ocupilot/screens/:screen/dryrun";

Parameter MESSAGESCREEN = "interop.messages";

Parameter HEADERSCREEN = "interop.messageheader";

Parameter RESENDTOOL = "OcuPilot.Screen.Tool.InteropMessageResend";

Parameter EDITTOOL = "OcuPilot.Screen.Tool.InteropMessageEditResend";

/// <p>The text <var>pText</var> posted to the dry-run route of <var>pScreen</var> as the HTTP account: the status, the answer's
/// <code>code</code> in <var>pCode</var> (<code>""</code> for an answer that is not one JSON document), the answer in <var>pAnswer</var>
/// and its content type in <var>pContentType</var>.</p>
ClassMethod Raw(pScreen As %String, pText As %String, Output pCode As %String, Output pAnswer, Output pContentType As %String) As %Integer
{
    Kill tExtra
    Set tPath = $Replace(..#ROUTE, ":screen", pScreen) _ "?ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, pText, "application/json", .tExtra, 90)
    Set pCode = ""
    Set pAnswer = ""
    Set pContentType = $Get(tHeaders("CONTENT-TYPE"))
    Try {
        Set pAnswer = ##class(%DynamicAbstractObject).%FromJSON(tRaw)
        If pAnswer.%IsA("%Library.DynamicObject") Set pCode = pAnswer.%Get("code")
    } Catch {
        Set pAnswer = ""
    }
    Quit +$Get(tStatus)
}

/// <p>AC1: a body the action route would not take is 400 <code>TOOL.ARGUMENTS</code>, an unknown screen, an undeclared action and an
/// action whose tool declares no dry run are 404, each before anything is read, so no proposal, ledger row or message is made.</p>
/// <p>Mutation (Rule 19): drop the <code>DRYRUN</code> test in <method>OcuPilot.Api.ScreenAction.DryRun</method> -- the tool-without-a-dry-run
/// leg reaches the preview and goes red; drop the stray-key check in <method>OcuPilot.Api.ScreenDryRun.Handle</method> -- the stray-key
/// leg goes red.</p>
Method TestARequestTheActionRouteWouldNotTakeIsRefusedBeforeAnythingIsRead()
{
    Set tA = ..Make("alpha")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tProposals = ##class(OcuPilot.Test.ProposalFixture).ProposalCount()
    Set tBadRequest = "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS
    Set tNotFound = "404 " _ ##class(OcuPilot.Api.Error).#ROUTENOTFOUND
    For tCase = $ListBuild("", tBadRequest, "an empty body"), $ListBuild("not json", tBadRequest, "a body that is not JSON"), $ListBuild("[]", tBadRequest, "an array"), $ListBuild("{}", tBadRequest, "no action"), $ListBuild("{""action"": 1}", tBadRequest, "an action that is no string"), $ListBuild("{""action"": """"}", tBadRequest, "an empty action"), $ListBuild("{""action"": ""resend"", ""id"": """ _ tA _ """, ""extra"": 1}", tBadRequest, "a key beyond the route's three") {
        Set tStatus = ..Raw(..#MESSAGESCREEN, $List(tCase, 1), .tCode, , .tContentType)
        Do $$$AssertEquals(tStatus _ " " _ tCode _ " " _ $Piece(tContentType, ";", 1), $List(tCase, 2) _ " application/json", $List(tCase, 3) _ " is refused as JSON")
    }
    Set tStatus = ..Raw("no.such.screen", "{""action"": ""resend"", ""id"": """ _ tA _ """}", .tCode)
    Do $$$AssertEquals(tStatus _ " " _ tCode, tNotFound, "an unknown screen is not found")
    Set tStatus = ..Raw(..#MESSAGESCREEN, "{""action"": ""no-such-action"", ""id"": """ _ tA _ """}", .tCode)
    Do $$$AssertEquals(tStatus _ " " _ tCode, tNotFound, "an action the screen does not declare is not found")
    Set tStatus = ..Raw("interop.items", "{""action"": ""disable"", ""id"": ""x""}", .tCode)
    Do $$$AssertEquals(tStatus _ " " _ tCode, tNotFound, "an action whose tool declares no dry run is not found")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId") _ "|" _ ##class(OcuPilot.Test.ProposalFixture).ProposalCount(), tTop _ "|" _ tProposals, "nothing was sent and no proposal was written")
}

/// <p>AC1, AC2: the answer is <code>{rows, review}</code> and nothing else; its rows are the rows the agent's proposal card shows for the same
/// resend and the same edit, its review carries the digest (and, for the edit, the kind and the form); and the review wrote no proposal,
/// held no target -- the agent's mint of the same target then succeeds -- and sent nothing.</p>
/// <p>Mutation (Rule 19): answer <code>review</code> from the tool's class default in <method>OcuPilot.Api.ScreenAction.DryRun</method> -- the
/// review legs go red.</p>
Method TestTheAnswerIsRowsAndReviewAndTheRowsAreTheAgentsCardRows()
{
    Set tA = ..Make("alpha")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    Set tProposals = ##class(OcuPilot.Test.ProposalFixture).ProposalCount()
    Set tFields = {"StringValue": "edited"}.%ToJSON()
    Set tStatus = ..Raw(..#MESSAGESCREEN, "{""action"": ""resend"", ""id"": """ _ tA _ """}", .tCode, .tResend, .tContentType)
    Do $$$AssertEquals(tStatus _ "|" _ $Piece(tContentType, ";", 1), "200|application/json", "the resend review answers 200 as JSON")
    Set tBody = {"action": "editresend"}
    Do tBody.%Set("id", tA, "string")
    Do tBody.%Set("values", {}.%Set("fields", tFields, "string"))
    Set tStatus = ..Raw(..#HEADERSCREEN, tBody.%ToJSON(), .tCode, .tEdit)
    Do $$$AssertEquals(tStatus, 200, "the edit review answers")
    If '$IsObject(tResend) || '$IsObject(tEdit) Quit
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tResend.%ToJSON()).%Size() _ "|" _ tResend.%GetTypeOf("rows") _ "|" _ tResend.%GetTypeOf("review"), "2|array|object", "the answer is rows and review and nothing else")
    Do $$$AssertEquals(tResend.review.%Size() _ "|" _ $Length(tResend.review.Digest), "1|64", "the resend's review is its digest")
    Do $$$AssertEquals(tEdit.review.Kind _ "|" _ tEdit.review.Form.%Size() _ "|" _ $Length(tEdit.review.Digest), "object|1|64", "and the edit's is the digest, the kind and the form")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TopId") _ "|" _ ##class(OcuPilot.Test.ProposalFixture).ProposalCount(), tTop _ "|" _ tProposals, "the reviews sent nothing and wrote no proposal")
    Do ..EnableKey("interop.messages.resend")
    Do ..EnableKey("interop.messageheader.editresend")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#RESENDTOOL, {"Messages": (tA)}, tUser, .tCard, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the agent's resend of the same target mints, so the review held nothing: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If $IsObject($Get(tCard)) Do $$$AssertEquals(tResend.rows.%ToJSON(), tCard.changed.%ToJSON(), "and its card shows the review's rows")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#EDITTOOL, {"Message": (tA), "Fields": {"StringValue": "edited"}}, tUser, .tCard, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "so does the agent's edit: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If $IsObject($Get(tCard)) Do $$$AssertEquals(tEdit.rows.%ToJSON(), tCard.changed.%ToJSON(), "and its card shows the review's rows")
}

}
