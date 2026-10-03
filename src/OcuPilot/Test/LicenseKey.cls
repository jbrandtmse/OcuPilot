/// <p>Pins Story 18.6's License key (AC A1-A3): the screen's read and
/// <code>osmgmt.licensekey.read</code> answer the same thirteen fields and never the authorization key;
/// the key check refuses an empty, oversized or malformed text on <code>Key</code> with OcuPilot's own
/// sentence and leaves the license as found; the seam's valid verdict reaches the screen as the restart
/// and the reductions; the activation sends <code>VALIDATE</code> and then the <code>PUT</code> only when
/// valid; the key text reaches no log line, ledger row, proposal or answer; and no agent tool, dispatch
/// or screen context carries the activation.</p>
/// <p>Every activation and every valid verdict runs through <class>OcuPilot.Test.LicenseSeamPort</class>,
/// which never sends a <code>License.Key</code> <code>PUT</code> to the vendor; the malformed check is
/// the vendor's own and changes nothing (measured at the story's Task 0). After each test the license's
/// facts read as they did before the class (<method>OcuPilot.Test.LicenseProbe.LicenseFacts</method>).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving. It writes no
/// instance configuration.</p>
Class OcuPilot.Test.LicenseKey Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.LicenseProbe";

Parameter SEAM = "OcuPilot.Test.LicenseSeamPort";

Parameter ACTION = "OcuPilot.Test.LicenseActionFixture";

Parameter SCREEN = "osmgmt.licensekey";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.LicenseKey";

Parameter TOOL = "osmgmt.licensekey.activate";

Parameter FIELDS = "LicenseCapacity,CustomerName,OrderNumber,Product,LicenseType,Server,Platform,LicenseUnits,CoresLicensed,CoresEnforced,ExpirationDate,ExtendedFeaturesList,AuthorizedApplications";

/// <p>The license's facts before the class ran.</p>
Property PreparedFacts As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedFacts = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "LicenseFacts").%ToJSON()
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Clear")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LicenseFacts").%ToJSON(), ..PreparedFacts, "the license's facts and key files read as they did before the class")
    Quit $$$OK
}

/// <p>A1: the declared read and the read tool answer the same thirteen fields, and neither carries
/// <code>AuthorizationKey</code> as a key or its value.</p>
/// <p>Mutation (Rule 19): drop <code>AuthorizationKey</code> from the descriptor's
/// <code>context.secretFields</code> -- both answers carry it and this goes red.</p>
Method TestTheReadAndTheToolAnswerTheFieldsWithoutTheAuthorizationKey()
{
    Set tAuthorization = $SYSTEM.License.KeyAuthorizationKey()
    Do $$$AssertTrue(tAuthorization '= "", "the instance's key carries an authorization key")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 10, .tRead, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the screen's read answers")
    Set tRow = ""
    If $IsObject($Get(tRead)) && (tRead.%Get("rows").%Size() = 1) Set tRow = tRead.%Get("rows").%Get(0)
    Do $$$AssertEquals(..Keys(tRow), ..Sorted(..#FIELDS), "one row of the thirteen fields")
    Do $$$AssertTrue($IsObject(tRow) && 'tRow.%IsDefined("AuthorizationKey"), "the screen's row has no authorization key")
    Do $$$AssertTrue($IsObject(tRead) && '(tRead.%ToJSON() [ tAuthorization), "and carries no authorization key's value")
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#DESCRIPTOR, {}, 1000, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read tool answers")
    Set tJson = $Select($IsObject($Get(tView)): tView.%ToJSON(), 1: "")
    Do $$$AssertTrue((tJson '= "") && (tJson '[ "AuthorizationKey") && (tJson '[ tAuthorization), "the tool's answer names no authorization key and carries none")
    Set tToolRow = ""
    If $IsObject($Get(tView)) && (tView.%GetTypeOf("rows") = "array") && (tView.%Get("rows").%Size() = 1) Set tToolRow = tView.%Get("rows").%Get(0)
    Do $$$AssertEquals(..Keys(tToolRow), ..Sorted(..#FIELDS), "and the same thirteen fields")
    Do $$$AssertTrue($IsObject(tRow) && $IsObject(tToolRow) && (tRow.%Get("OrderNumber") = tToolRow.%Get("OrderNumber")) && (tRow.%Get("ExpirationDate") = tToolRow.%Get("ExpirationDate")), "with the screen's values")
    Set tAuthorization = ""
}

/// <p>A2: a malformed text is refused 422 <code>LICENSE.KEY.INVALID</code> on <code>Key</code> with
/// OcuPilot's sentence, after one vendor check and no write, and no text of the vendor's reaches the
/// answer; the license, its key files and the temporary directory read as before.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.LicensePort.Validate</method> answer the vendor's
/// <code>InvalidReason</code> as the fault's reason -- the no-vendor-text leg goes red.</p>
Method TestAMalformedKeyIsRefusedOnTheFieldAndChangesNothing()
{
    Set tTemp = $ClassMethod(..#PROBE, "TempKeyCount")
    Set tSC = $ClassMethod(..#SEAM, "Validate", $Parameter(..#PROBE, "MALFORMEDKEY"), .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the malformed text is refused")
    Do $$$AssertEquals(..Refusal(tHttp, tFault), "422 Key:LICENSE.KEY.INVALID", "422 on Key")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "License.Key/VALIDATE", "after one vendor check and nothing else")
    Set tJson = $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "")
    Do $$$AssertTrue((tJson [ ##class(OcuPilot.Api.LicenseError).#REASONKEYINVALID) && (tJson '[ "8603") && (tJson '[ "license key file"), "with OcuPilot's sentence and no vendor text: " _ tJson)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "TempKeyCount"), tTemp, "and no temporary key file is left")
}

/// <p>A2: an empty text, one of whitespace, and one longer than the port's bound are refused before
/// any vendor call.</p>
/// <p>Mutation (Rule 19): drop the empty check from <method>OcuPilot.Port.LicensePort.Validate</method>
/// -- the empty leg reaches the vendor and this goes red.</p>
Method TestAnEmptyOrOversizedKeyIsRefusedBeforeAnyCall()
{
    For tCase = $ListBuild("", "LICENSE.KEY.EMPTY"), $ListBuild("   ", "LICENSE.KEY.EMPTY"), $ListBuild($Translate($Justify("", $Parameter("OcuPilot.Port.LicensePort", "KEYMAXLENGTH") + 1), " ", "k"), "LICENSE.KEY.INVALID") {
        Do $ClassMethod(..#SEAM, "Clear")
        Set tSC = $ClassMethod(..#SEAM, "Validate", $List(tCase, 1), .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals(..Refusal(tHttp, tFault), "422 Key:" _ $List(tCase, 2), "a text of " _ $Length($List(tCase, 1)) _ " characters is refused " _ $List(tCase, 2))
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "before any vendor call")
    }
}

/// <p>A2: a valid verdict answers <code>{valid, requiresRestart, reductions, features}</code>: the
/// restart, the cores reduced from 20 to 8 and the dropped feature, and none of the vendor's
/// text.</p>
/// <p>Mutation (Rule 19): drop the reductions loop from <method>OcuPilot.Port.LicensePort.Answer</method>
/// -- the reductions leg goes red.</p>
Method TestTheSeamsValidVerdictCarriesTheRestartAndTheReductions()
{
    Do $ClassMethod(..#SEAM, "Arm", 1)
    Set tSC = $ClassMethod(..#SEAM, "Validate", "OCUPROBE186 seam key", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the seam's verdict is valid")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Set tJson = $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: "")
    Do $$$AssertEquals(tJson, "{""valid"":true,""requiresRestart"":true,""reductions"":[{""kind"":""Cores"",""from"":""20"",""to"":""8""}],""features"":[""" _ $Parameter(..#SEAM, "FEATURE") _ """]}", "the restart, the reduction and the feature, and no vendor text")
}

/// <p>A3: the screen's activation sends <code>VALIDATE</code> and no <code>PUT</code> for a malformed
/// text, refused 422 on <code>Key</code>; and, valid through the seam, <code>VALIDATE</code> then the
/// <code>PUT</code>, once each and in that order, answering the <code>license-key</code> change and a
/// read-back that compared no value.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.LicensePort.Activate</method> send the
/// <code>PUT</code> without validating -- the malformed leg's writes read <code>License.Key/PUT</code> and
/// this goes red.</p>
Method TestTheActivationValidatesThenWritesOnlyWhenValid()
{
    Set tSC = ..Activate($Parameter(..#PROBE, "MALFORMEDKEY"), .tAnswer, .tStatus)
    Do $$$AssertStatusOK(tSC, "the action ran")
    Do $$$AssertEquals(tStatus _ " " _ ..Violation(tAnswer), "422 Key:LICENSE.KEY.INVALID", "a malformed text is refused on Key: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "License.Key/VALIDATE", "after VALIDATE alone, and no PUT")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Arm", 1)
    Set tSC = ..Activate("OCUPROBE186 seam key", .tAnswer, .tStatus)
    Do $$$AssertStatusOK(tSC, "the action ran")
    Do $$$AssertEquals(tStatus, 200, "a valid text is activated: " _ $Extract(tAnswer, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "License.Key/VALIDATE,License.Key/PUT", "VALIDATE, then the PUT, once each")
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals($Select($IsObject(tParsed): tParsed.%Get("action") _ " " _ tParsed.%Get("target").%Get("type") _ " " _ tParsed.%Get("readBack").%Get("verdict"), 1: ""), "updated license-key " _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#WRITTEN, "answering the license-key change and a read-back that compared no value")
}

/// <p>A3: a key text carrying a marker, checked and activated through the seam and checked by the
/// vendor, reaches no <code>messages.log</code> or <code>alerts.log</code> line, proposal or answer.
/// A screen action writes no ledger row; the ledger leg is
/// <method>TestTheActivationIsAbsentFromEveryRosterTheAgentSees</method>'s, where a model's call does.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.LicensePort.Validate</method> log the text it
/// checks -- the log leg goes red.</p>
Method TestTheKeyTextReachesNoLogLedgerProposalOrAnswer()
{
    Set tMarker = "OCUPROBE186MARKER" _ $Translate($ZTimeStamp, ",.", "")
    Set tFrom = $ClassMethod(..#PROBE, "LineCount", "messages.log")
    Set tAlertsFrom = $ClassMethod(..#PROBE, "LineCount", "alerts.log")
    Set tProposals = ..Count("SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ToolName) = ?", ..#TOOL)
    Set tAnswers = ""
    Set tSC = $ClassMethod(..#SEAM, "Validate", tMarker, .tAnswer, .tHttp, .tFault)
    Set tAnswers = tAnswers _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "")
    Do $ClassMethod(..#SEAM, "Arm", 1)
    Set tSC = $ClassMethod(..#SEAM, "Validate", tMarker, .tAnswer, .tHttp, .tFault)
    Set tAnswers = tAnswers _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: "")
    Set tSC = ..Activate(tMarker, .tActed, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the marker key is activated through the seam")
    Set tAnswers = tAnswers _ tActed
    Do $$$AssertTrue(tAnswers '[ tMarker, "no answer carries the key text")
    Set tLines = $ClassMethod(..#PROBE, "LinesAfter", "messages.log", tFrom)
    Do $$$AssertTrue(tLines.%ToJSON() '[ tMarker, "no messages.log line carries it")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "LinesAfter", "alerts.log", tAlertsFrom).%ToJSON() '[ tMarker, "nor any alerts.log line")
    Do $$$AssertEquals(..Count("SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ToolName) = ?", ..#TOOL), tProposals, "and no proposal was minted")
}

/// <p>A3, AD-53: the activation is in neither the provider's tool list, the dispatch lookup, a
/// proposal-path resolve nor License key's screen-context <code>tools</code>; the registry still lists
/// it, so the screen's action resolves it; and a model's call is refused as an unknown tool.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.LicenseKeyActivate.ADVERTISED</parameter> 1
/// -- this goes red.</p>
Method TestTheActivationIsAbsentFromEveryRosterTheAgentSees()
{
    Set tRegistry = "OcuPilot.Screen.Tool.Registry"
    Set tWire = $ClassMethod(tRegistry, "WireName", ..#TOOL)
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ProviderTools", .tProvider), "the provider tool list builds")
    Set tProviderNames = ""
    For tI = 1:1:+$Get(tProvider) Set tProviderNames = tProviderNames _ $ListBuild(tProvider(tI, "name"))
    Do $$$AssertTrue('$ListFind(tProviderNames, tWire) && $ListFind(tProviderNames, $ClassMethod(tRegistry, "WireName", "osmgmt.licensekey.read")), "the provider tool list carries the read and not the activation")
    Kill tByWire, tByName, tForRoute
    Do $ClassMethod(tRegistry, "ResolveWire", tWire, .tByWire)
    Do $$$AssertTrue('$IsObject($Get(tByWire)), "the dispatch lookup does not find it")
    Do $ClassMethod(tRegistry, "Resolve", ..#TOOL, .tByName)
    Do $$$AssertTrue('$IsObject($Get(tByName)), "nor does a proposal-path resolve")
    Do $ClassMethod(tRegistry, "Resolve", ..#TOOL, .tForRoute, 1)
    Do $$$AssertTrue($IsObject($Get(tForRoute)), "while the registry lists it for the screen's route")
    Kill tTools
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(..#DESCRIPTOR, .tTools), "License key's context tools build")
    Set tJson = $Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: "")
    Do $$$AssertTrue((tJson '[ tWire) && (tJson '[ ..#TOOL), "and they carry no activation: " _ tJson)
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.LicenseKeyActivate).Advertised(), 0, "declared unadvertised")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a completed probe turn is seeded")
    Set tMarker = "OCUPROBE186MARKER" _ $Translate($ZTimeStamp, ",.", "")
    Set tUse = {"type": "tool_use", "id": "toolu_activate", "input": {"Name": "SYSTEM", "rationale": "probe", "expectedImpact": "probe"}}
    Do tUse.%Get("input").%Set("Key", tMarker, "string")
    Do tUse.%Set("name", tWire, "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurn)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurn, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    ; A3: the model's call is ledgered, and no row of it carries the key text the call held.
    Set tRows = ..Count("SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", tTurn)
    Set tCarried = ..Count("SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ? AND (Arguments [ ? OR Target [ ? OR Fields [ ? OR Route [ ?)", tTurn, tMarker, tMarker, tMarker, tMarker)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertTrue(tRows > 0, "the model's call is ledgered (" _ tRows _ " rows)")
    Do $$$AssertEquals(tCarried, 0, "and no ledger row carries the key text it held")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Do $$$AssertStatusOK(tSC, "the dispatch answers")
    Set tCode = ""
    If $IsObject($Get(tResults)) && (tResults.%Size() = 1) Set tCode = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content")).%Get("code")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Api.Error).#TOOLUNKNOWN, "a model's call is refused as an unknown tool")
}

/// <p>A2: <code>POST /license/key/validate</code> over the wire answers a malformed text 422 on
/// <code>Key</code>, not to be stored, and a body other than <code>{Key}</code> 400.</p>
Method TestTheValidateRouteAnswersOverTheWire()
{
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/license/key/validate"
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders, {"Key": ($Parameter(..#PROBE, "MALFORMEDKEY"))}.%ToJSON(), "application/json")
    Do $$$AssertStatusOK(tSC, "the request was sent")
    Do $$$AssertEquals(tStatus _ " " _ ..Violation(tBody), "422 Key:LICENSE.KEY.INVALID", "a malformed text is refused on Key: " _ $Extract(tBody, 1, 200))
    Do $$$AssertEquals($Get(tHeaders("CACHE-CONTROL")), "no-store", "and the answer is not stored")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders, {"Key": "x", "Other": "y"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 400, "a body other than {Key} is 400: " _ $Extract(tBody, 1, 200))
}

/// <p>A2, A3: <code>POST /license/key/validate</code>'s valid answer, through the seam: 200 with
/// exactly <code>{valid, requiresRestart, reductions, features}</code>, not to be stored, after one
/// check, and carrying none of the key text it was sent.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.OsMgmt.LicenseRules.HandleValidate</method> echo
/// the key text into its answer -- the marker leg goes red.</p>
Method TestTheValidateRouteAnswersAValidKeyWithoutItsText()
{
    Set tMarker = "OCUPROBE186MARKER" _ $Translate($ZTimeStamp, ",.", "")
    Do $ClassMethod(..#SEAM, "Arm", 1)
    Set tBody = {}
    Do tBody.%Set("Key", tMarker, "string")
    Set tSC = ##class(OcuPilot.Test.LicenseRulesFixture).Check(tBody, .tAnswer, .tStatus, .tCacheControl)
    Do $$$AssertStatusOK(tSC, "the route ran")
    Do $$$AssertEquals(tStatus, 200, "a valid key is answered 200")
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals($Select($IsObject(tParsed): tParsed.%ToJSON(), 1: ""), "{""valid"":true,""requiresRestart"":true,""reductions"":[{""kind"":""Cores"",""from"":""20"",""to"":""8""}],""features"":[""" _ $Parameter(..#SEAM, "FEATURE") _ """]}", "with the verdict, the restart, the reduction and the feature")
    Do $$$AssertEquals(tCacheControl, "no-store", "not to be stored")
    Do $$$AssertTrue((tAnswer '= "") && (tAnswer '[ tMarker), "and none of the key text it was sent")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "License.Key/VALIDATE", "after one check")
}

/// <p>Send the License key screen's activation with key text <var>pKey</var> through
/// <class>OcuPilot.Test.LicenseActionFixture</class>.</p>
Method Activate(pKey As %String, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set tBody = {"action": "activate", "id": "SYSTEM"}
    Set tValues = {}
    Do tValues.%Set("Key", pKey, "string")
    Do tBody.%Set("values", tValues)
    Quit $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .pAnswer, .pStatus)
}

/// <p><code>http field:code</code> of a refusal's first violation.</p>
ClassMethod Refusal(pHttp As %Integer, pFault As %DynamicObject) As %String
{
    Set tText = +$Get(pHttp)
    If $IsObject($Get(pFault)) && $IsObject(pFault.%Get("detail")) && (pFault.detail.%GetTypeOf("violations") = "array") && (pFault.detail.violations.%Size() > 0) {
        Set tRow = pFault.detail.violations.%Get(0)
        Quit tText _ " " _ tRow.%Get("field") _ ":" _ tRow.%Get("code")
    }
    Quit tText _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>The first violation of the envelope <var>pJson</var>, <code>field:code</code>, or
/// <code>""</code>.</p>
ClassMethod Violation(pJson As %String) As %String
{
    Set tAnswer = ..Parsed(pJson)
    If '$IsObject(tAnswer) || '$IsObject(tAnswer.%Get("detail")) || (tAnswer.detail.%GetTypeOf("violations") '= "array") Quit ""
    Set tFirst = tAnswer.detail.violations.%Get(0)
    If '$IsObject(tFirst) Quit ""
    Quit tFirst.%Get("field") _ ":" _ tFirst.%Get("code")
}

/// <p><var>pJson</var> parsed as an object, or <code>""</code>.</p>
ClassMethod Parsed(pJson As %String) As %DynamicObject
{
    Set tObject = ""
    Try {
        Set tObject = ##class(%DynamicObject).%FromJSON(pJson)
    } Catch {
        Set tObject = ""
    }
    Quit tObject
}

/// <p>The keys of <var>pObject</var>, sorted and comma-joined.</p>
ClassMethod Keys(pObject) As %String
{
    If '$IsObject(pObject) Quit ""
    Kill tKeys
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) { Set tKeys(tKey) = "" }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tKeys(tKey))
        Quit:tKey=""
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

/// <p><var>pList</var>, comma-separated, sorted.</p>
ClassMethod Sorted(pList As %String) As %String
{
    Kill tNames
    For tI = 1:1:$Length(pList, ",") Set tNames($Piece(pList, ",", tI)) = ""
    Set tOut = ""
    Set tName = ""
    For {
        Set tName = $Order(tNames(tName))
        Quit:tName=""
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tName
    }
    Quit tOut
}

/// <p>The count statement <var>pSql</var> answers for its arguments, or -1.</p>
ClassMethod Count(pSql As %String, pArgs...) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pArgs...)
    If (tRS.%SQLCODE '= 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%Get("N")
}

}
