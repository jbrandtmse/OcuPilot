/// <p>Pins Story 21.14's locale list, its validation, the gate and the governance defaults (AC2, AC3's and AC4's refusals; AD-21, AD-22, AD-29, AD-36, AD-39,
/// AD-53): Locale definitions read through <class>OcuPilot.Port.LocalePort</class> and the screens' own read executor, a locale named exactly and never
/// as a pattern, Validate through the screen's route and the agent's tool with neither answer holding a vendor line, every read and write refused to a caller short of a pair before any vendor call, and the install and delete keys shipping disabled.</p>
/// <p><b>Live-safe:</b> it reads, installs and deletes nothing (the port's seams record the calls it never makes), and stores a governance policy only to
/// restore it. <b>What it needs from the environment:</b> OcuPilot installed and serving, and the web application answering at the test port.</p>
Class OcuPilot.Test.LocaleRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.LocalePort";

Parameter SEAM = "OcuPilot.Test.LocaleGateSeam";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.LocaleList";

Parameter VALIDATE = "OcuPilot.Screen.Tool.LocaleValidate";

Parameter KEYS = "osmgmt.locales.install,osmgmt.locales.delete";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The governance policy as it stood before each test.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>Hold every pair the port's two sets name, in the gate's test seam.</p>
ClassMethod HoldAll()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
}

/// <p>The locale names the vendor's own list answers, comma-joined in its order, and the current locale, read in <code>%SYS</code> independently of the
/// port.</p>
ClassMethod VendorList(Output pCurrent As %String) As %String
{
    Set tNames = ""
    Set pCurrent = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set pCurrent = $Get(^%SYS("LOCALE", "CURRENT"))
        Set tRS = ##class(%ResultSet).%New("Config.NLS.Locales:List")
        Set tSC = tRS.Execute("*")
        While $$$ISOK(tSC) && tRS.Next() {
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRS.Get("Name")
        }
        Set tRS = ""
    } Catch {
        Set tRS = ""
        Set tNames = ""
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tNames
}

/// <p>The vendor's <code>IsValid</code> of <var>pName</var>, as <code>valid|errors|warnings</code>: the verdict as 0 or 1, then its error and warning line counts, read in <code>%SYS</code>
/// independently of the port.</p>
ClassMethod VendorChecks(pName As %String) As %String
{
    Set tOut = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tValid = ''##class(Config.NLS.Locales).IsValid(pName, .tE1, .tW1)
        Set tOut = tValid _ "|" _ +$Get(tE1) _ "|" _ +$Get(tW1)
    } Catch {
        Set tOut = ""
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p><b>AC2.</b> The screen's read answers one row per locale the vendor lists, in its order, with its description; exactly one row is current, the one
/// <code>^%SYS("LOCALE","CURRENT")</code> names, and a row is custom exactly when its name starts with <code>y</code>. The port's own list answers the
/// same rows.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.LocalePort</class>'s <code>LocaleRows</code> marks <code>Current</code> by a case-insensitive comparison, or
/// reads <code>Custom</code> from the second letter -> the current and custom assertions go red.</p>
Method TestTheRowsAreTheVendorsListAndTheCurrentLocale()
{
    Set tNames = ..VendorList(.tCurrent)
    Do $$$AssertTrue($Length(tNames, ",") > 1, "the vendor lists locales: " _ $Length(tNames, ","))
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read answers (" _ $Get(tHttp) _ ")")
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) Quit
    Set tGot = ""
    Set tCurrentRows = 0
    Set tCustomOk = 1
    Set tIterator = tResult.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tGot = tGot _ $Select(tGot = "": "", 1: ",") _ tRow.%Get("Name")
        If tRow.%Get("Current") Set tCurrentRows = tCurrentRows + 1
        If tRow.%Get("Current") && (tRow.%Get("Name") '= tCurrent) Set tCurrentRows = tCurrentRows + 100
        If (''tRow.%Get("Custom")) '= (''($Extract(tRow.%Get("Name"), 1) = "y")) Set tCustomOk = 0
        If tRow.%Get("Description") = "" Set tCustomOk = 0
    }
    Do $$$AssertEquals(tGot, tNames, "its rows are the vendor's list, in its order")
    Do $$$AssertEquals(tCurrentRows, 1, "exactly one row is current, and it is " _ tCurrent)
    Do $$$AssertEquals(tCustomOk, 1, "a row is custom exactly when its name starts with y, and each has a description")
    Do $$$AssertEquals(tResult.%Get("truncated"), 0, "nothing is truncated")
    Do ..HoldAll()
    Set tSC = $ClassMethod(..#SEAM, "Rows", "Locales", 1000, .tPortRows, .tPortHttp, .tPortFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tPortRows.%Size(), 1: -1), tResult.%Get("rows").%Size(), "the port's own list answers the same rows")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, 3, .tCapped, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tCapped)): tCapped.%Get("rows").%Size() _ "|" _ tCapped.%Get("truncated"), 1: "none"), "3|1", "a read capped at three answers three rows and says it is truncated")
}

/// <p><b>AC2 (AD-21).</b> A named read finds the locale by an exact comparison against the instance's own list: the name as listed answers its row, and
/// the name in another letter case, a pattern, a name with a comma and an empty name are each 404 <code>LOCALE.NOTFOUND</code>, none reaching the vendor's
/// <code>List</code> pattern.</p>
/// <p>Mutation (Rule 19): <code>State</code> compares with <code>[</code> in place of <code>=</code> -> the pattern rows go red.</p>
Method TestANamedReadComparesExactlyAndNeverAsAPattern()
{
    Set tNames = ..VendorList(.tCurrent)
    Set tFirst = $Piece(tNames, ",", 1)
    Kill tQuery
    Set tQuery("name") = tFirst
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Locales", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tRow)): tRow.%Get("Name"), 1: ""), "200|" _ tFirst, "a listed name answers its row")
    Set tQuery("name") = tCurrent
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Locales", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tRow)): tRow.%Get("Current"), 1: -1), 1, "the current locale reads current")
    For tName = $ZConvert(tCurrent, "U"), "*", "e*", $Extract(tCurrent, 1, 2) _ "*", tCurrent _ ",", "", $Extract(tCurrent, 1, 3) {
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Locales", "GET", .tQuery, "", .tAbsent, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404|LOCALE.NOTFOUND", "'" _ tName _ "' is not a locale of the list")
    }
    Do $$$AssertEquals(##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.NOTFOUND"), "There is no locale with that name.", "the refusal's sentence is the published one")
}

/// <p><b>AC2.</b> Validate through the port and the agent's tool (the screen's route is <method>TestTheValidationRouteAnswersJsonOverTheWire</method>): <code>Valid</code>
/// and the counts match the vendor's <code>IsValid</code>, the tool's result is the verdict, the name and the counts
/// (<method>TestTheToolHoldsNoVendorLine</method> feeds it lines), and a name the list does not hold is 404 <code>LOCALE.NOTFOUND</code> at the tool.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.LocaleValidate</class>'s <code>View</code> answers the count as <code>0</code> -> the counts
/// assertion goes red.</p>
Method TestValidateAgreesWithTheVendorByPortAndToolAndTheToolHoldsNoLine()
{
    Set tNames = ..VendorList(.tCurrent)
    Set tChecks = ..VendorChecks(tCurrent)
    Do $$$AssertNotEquals(tChecks, "", "the vendor's checks of the current locale are read")
    Set tValid = $Piece(tChecks, "|", 1)
    Kill tQuery
    Set tQuery("name") = tCurrent
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Locales", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do ..HoldAll()
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Validation", "GET", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $$$AssertEquals(tHttp _ "|" _ tAnswer.%Get("Valid"), "200|" _ ''tValid, "the port's Valid is IsValid's answer")
    Do $$$AssertEquals(tAnswer.%Get("ErrorCount") _ "|" _ tAnswer.%Get("WarningCount"), $Piece(tChecks, "|", 2) _ "|" _ $Piece(tChecks, "|", 3), "the counts are IsValid's")
    Set tSC = $ClassMethod(..#VALIDATE, "View", "", {"name": (tCurrent)}, 100, .tResult, .tToolHttp, .tToolFault)
    Do $$$AssertStatusOK(tSC, "the agent's tool answers (" _ $Get(tToolHttp) _ ")")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Keys(tResult), "ErrorCount,Name,Valid,WarningCount", "its result is exactly the verdict, the name and the two counts")
    Do $$$AssertEquals(tResult.%Get("Valid") _ "|" _ tResult.%Get("ErrorCount") _ "|" _ tResult.%Get("WarningCount") _ "|" _ tResult.%GetTypeOf("ErrorCount") _ "|" _ tResult.%GetTypeOf("WarningCount"), ''tValid _ "|" _ $Piece(tChecks, "|", 2) _ "|" _ $Piece(tChecks, "|", 3) _ "|number|number", "the tool's verdict and counts are IsValid's")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(##class(OcuPilot.Screen.Tool.LocaleValidate).ResultSchema(), tResult, .tProblem), "and conforms to its own result schema: " _ $Get(tProblem))
    Set tSC = $ClassMethod(..#VALIDATE, "View", "", {"name": "nosuchlocale"}, 100, .tAbsent, .tToolHttp, .tToolFault)
    Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ tToolHttp _ "|" _ $Select($IsObject($Get(tToolFault)): tToolFault.%Get("code"), 1: ""), "1|404|LOCALE.NOTFOUND", "the tool refuses a name the list does not hold")
    Set tSC = $ClassMethod(..#VALIDATE, "View", "", {"name": 7}, 100, .tAbsent, .tToolHttp, .tToolFault)
    Do $$$AssertEquals(tToolHttp _ "|" _ $Select($IsObject($Get(tToolFault)): tToolFault.%Get("code"), 1: ""), "400|TOOL.ARGUMENTS", "and an argument the schema refuses, before the port is asked")
}

/// <p><b>AC2.</b> The screen's validation route answers over the wire as the port does: 200 and <code>application/json</code> with the name, the verdict and the
/// counts, a name the list does not hold 404 <code>LOCALE.NOTFOUND</code> in the envelope, and a request that carries no credentials is refused before any read.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Area.OsMgmt.LocaleRules</class>'s <code>HandleValidate</code> answers the fresh row in place of the port's validation -> the verdict
/// legs go red.</p>
Method TestTheValidationRouteAnswersJsonOverTheWire()
{
    Set tNames = ..VendorList(.tCurrent)
    Set tChecks = ..VendorChecks(tCurrent)
    Set tRoute = "/locales/:name/validation"
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tUrl = tBase _ $Replace(tRoute, ":name", ##class(OcuPilot.Kernel.EntityId).Encode(tCurrent))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tUrl, tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the route answers 200: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Keys(tAnswer), "ErrorCount,Name,Valid,WarningCount", "its body is the validation's four members, no line")
    Do $$$AssertEquals(tAnswer.Name _ "|" _ tAnswer.Valid _ "|" _ tAnswer.ErrorCount _ "|" _ tAnswer.WarningCount, tCurrent _ "|" _ ''$Piece(tChecks, "|", 1) _ "|" _ $Piece(tChecks, "|", 2) _ "|" _ $Piece(tChecks, "|", 3), "with IsValid's verdict and counts")
    Set tUrl = tBase _ $Replace(tRoute, ":name", "nosuchlocale")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tUrl, tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 404, "a name the list does not hold is 404: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "in the JSON envelope")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tRefusal.code _ "|" _ tRefusal.reason, "LOCALE.NOTFOUND|" _ ##class(OcuPilot.Api.LocaleError).#REASONNOTFOUND, "carrying the code and the published sentence")
    Set tUrl = tBase _ $Replace(tRoute, ":name", ##class(OcuPilot.Kernel.EntityId).Encode(tCurrent))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tUrl, "", "", .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 401, "a request with no credentials is refused before any read")
}

/// <p><b>AC2 (AD-39).</b> Whatever lines the vendor's <code>IsValid</code> answers, the port's validation, which the screen's route answers whole, carries none of them:
/// only the name, the verdict and the counts of every line. The verdict is whatever the check answered.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.LocalePort</class>'s <code>Validation</code> adds the first error line to its answer -> the member and
/// no-line assertions go red; <code>Validation</code> asks <code>ReadInstallable</code> -> the no-check assertion goes red.</p>
Method TestTheValidationAnswerHoldsNoVendorLine()
{
    Set tNames = ..VendorList(.tCurrent)
    Set tError = "error line 5b0f"
    Set tWarning = "warning line e81a"
    Set tErrors = $ListBuild(tError)
    For tI = 2:1:61 Set tErrors = tErrors _ $ListBuild("error " _ tI)
    Do $ClassMethod(..#SEAM, "Feed", 0, tErrors, $ListBuild(tWarning, "warning two"))
    Do ..HoldAll()
    Kill tQuery
    Set tQuery("name") = tCurrent
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Validation", "GET", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the validation answers")
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Keys(tAnswer), "ErrorCount,Name,Valid,WarningCount", "its answer is the name, the verdict and the two counts")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Checks"), "", "and the vendor's install check, which writes some locales' definitions, was not asked")
    Do $$$AssertEquals(tAnswer.%Get("ErrorCount") _ "|" _ tAnswer.%Get("WarningCount"), "61|2", "the counts are of every line")
    Do $$$AssertTrue(tAnswer.%ToJSON() '[ tError, "no error line is in the answer: " _ tAnswer.%ToJSON())
    Do $$$AssertTrue(tAnswer.%ToJSON() '[ tWarning, "no warning line is in the answer: " _ tAnswer.%ToJSON())
    Do $$$AssertEquals(tAnswer.%Get("Valid"), 0, "the verdict is the one the check answered")
}

/// <p><b>AC2 (AD-39).</b> Whatever lines the vendor's <code>IsValid</code> answers, the agent's tool result carries none of them: only the name, the verdict and
/// the counts of every line. The lines are fed through <class>OcuPilot.Test.LocaleValidateSeam</class>, so the test does not depend on what the
/// instance's own locale answers.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.LocaleValidate</class>'s <code>View</code> passes the answer's <code>Warnings</code> lines through -> the
/// no-line assertions go red.</p>
Method TestTheToolHoldsNoVendorLine()
{
    Set tNames = ..VendorList(.tCurrent)
    Set tError = "error line 71c4"
    Set tWarning = "warning line 9d2e"
    Do $ClassMethod(..#SEAM, "Feed", 0, $ListBuild(tError), $ListBuild(tWarning, "warning two"))
    Do ..HoldAll()
    Set tSC = $ClassMethod("OcuPilot.Test.LocaleValidateSeam", "View", "", {"name": (tCurrent)}, 100, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the tool answers (" _ $Get(tHttp) _ ")")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tResult.%Get("Valid") _ "|" _ tResult.%Get("ErrorCount") _ "|" _ tResult.%Get("WarningCount"), "0|1|2", "the verdict and the counts of every line")
    Do $$$AssertTrue(tResult.%ToJSON() '[ tError, "no error line is in the result: " _ tResult.%ToJSON())
    Do $$$AssertTrue(tResult.%ToJSON() '[ tWarning, "no warning line is in the result: " _ tResult.%ToJSON())
}

/// <p><b>AC2.</b> Every read, of the locale list and of a locale's properties, is refused to a caller holding none of its pairs, naming the first, before any vendor call;
/// a caller holding the read pairs reads and is refused an install, a delete, a copy and a set, add, remove or load of a property naming <code>%DB_IRISSYS:WRITE</code>,
/// with nothing recorded.</p>
/// <p>Mutation (Rule 19): <code>WRITEPAIRS</code> without <code>%DB_IRISSYS:WRITE</code> -> the write rows go red; <code>Invoke</code> asks <code>ReadInstallable</code>
/// before the gate for an install -> the install row goes red; <code>WRITETYPES</code> without <code>COPY</code> and <code>LOAD</code> -> the copy and load rows go red.</p>
Method TestEveryReadAndWriteIsRefusedToACallerShortOfItsPairs()
{
    For tCase = $ListBuild("Locales", "LIST"), $ListBuild("Locales", "GET"), $ListBuild("Validation", "GET"), $ListBuild("Properties", "LIST"), $ListBuild("Properties", "GET") {
        Kill tQuery
        Set tQuery("name") = "enuw"
        Set tSC = $ClassMethod(..#SEAM, "Invoke", $List(tCase, 1), $List(tCase, 2), .tQuery, "", .tRows, .tHttp, .tFault)
        Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ tDetail, "403|AUTH.NOPRIVILEGE|%Admin_Manage:USE", $List(tCase, 1) _ " " _ $List(tCase, 2) _ " is refused naming the first pair")
    }
    Set tSC = $ClassMethod(..#SEAM, "Rows", "Locales", 10, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 403, "the screens' own list call is gated too")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Kill tQuery
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Locales", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a caller holding the two read pairs reads the list")
    For tType = "INSTALL", "DELETE" {
        Set tQuery("name") = "yzzw"
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "Locales", tType, .tQuery, "", .tOut, .tHttp, .tFault)
        Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
        Do $$$AssertEquals(tHttp _ "|" _ tDetail _ "|" _ $ClassMethod(..#SEAM, "Calls") _ $ClassMethod(..#SEAM, "Checks"), "403|%DB_IRISSYS:WRITE|", tType _ " is refused naming the write pair, with nothing sent and the vendor's install check not asked")
    }
    For tCase = $ListBuild("Locales", "COPY"), $ListBuild("Properties", "SET"), $ListBuild("Properties", "ADD"), $ListBuild("Properties", "REMOVE"), $ListBuild("Properties", "LOAD") {
        Kill tQuery
        Set tQuery("locale") = "yzzw"
        Set tQuery("name") = $Select($List(tCase, 1) = "Locales": "yzzw", 1: "DateFormat")
        Set tSC = $ClassMethod(..#SEAM, "Invoke", $List(tCase, 1), $List(tCase, 2), .tQuery, "", .tOut, .tHttp, .tFault)
        Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
        Do $$$AssertEquals(tHttp _ "|" _ tDetail _ "|" _ $ClassMethod(..#SEAM, "Calls") _ $ClassMethod(..#SEAM, "Checks"), "403|%DB_IRISSYS:WRITE|", $List(tCase, 1) _ " " _ $List(tCase, 2) _ " is refused naming the write pair, with nothing sent")
    }
}

/// <p><b>AC2, AC3.</b> A call that is not a read, a write the endpoint does not serve and a body are each refused: 501 <code>PORT.NOTIMPLEMENTED</code> for
/// another endpoint or type, and a body is 500 <code>INTERNAL</code>, logged; a <code>maxRows</code> that is not a whole number above zero is 400
/// <code>PORT.VALIDATION</code>.</p>
/// <p>Mutation (Rule 19): <code>Serves</code> answers 1 for <code>INSTALL</code> on <code>Validation</code> -> the 501 row goes red; <code>Serves</code> answers 1 for <code>SET</code>
/// on <code>Locales</code> or for <code>INSTALL</code> on <code>Properties</code> -> the served-type row goes red.</p>
Method TestTheServedTypesAndTheBoundsAreEnforced()
{
    Do ..HoldAll()
    Do $$$AssertEquals(##class(OcuPilot.Port.LocalePort).Serves("Locales", "COPY") _ ##class(OcuPilot.Port.LocalePort).Serves("Properties", "LIST") _ ##class(OcuPilot.Port.LocalePort).Serves("Properties", "GET") _ ##class(OcuPilot.Port.LocalePort).Serves("Properties", "SET") _ ##class(OcuPilot.Port.LocalePort).Serves("Properties", "ADD") _ ##class(OcuPilot.Port.LocalePort).Serves("Properties", "REMOVE") _ ##class(OcuPilot.Port.LocalePort).Serves("Properties", "LOAD") _ ##class(OcuPilot.Port.LocalePort).Serves("Properties", "INSTALL") _ ##class(OcuPilot.Port.LocalePort).Serves("Properties", "DELETE") _ ##class(OcuPilot.Port.LocalePort).Serves("Locales", "SET"), "1111111000", "Locales serves COPY and not SET; Properties serves LIST, GET, SET, ADD, REMOVE and LOAD and not INSTALL or DELETE")
    Do $$$AssertEquals(##class(OcuPilot.Port.LocalePort).Serves("Locales", "LIST") _ ##class(OcuPilot.Port.LocalePort).Serves("Locales", "GET") _ ##class(OcuPilot.Port.LocalePort).Serves("Locales", "INSTALL") _ ##class(OcuPilot.Port.LocalePort).Serves("Locales", "DELETE") _ ##class(OcuPilot.Port.LocalePort).Serves("Validation", "GET") _ ##class(OcuPilot.Port.LocalePort).Serves("Validation", "LIST") _ ##class(OcuPilot.Port.LocalePort).Serves("Validation", "INSTALL") _ ##class(OcuPilot.Port.LocalePort).Serves("Nothing", "GET"), "11111000", "Locales serves LIST, GET, INSTALL and DELETE, Validation GET, and nothing else")
    Kill tQuery
    Set tQuery("name") = "yzzw"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Validation", "INSTALL", .tQuery, "", .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "501|PORT.NOTIMPLEMENTED", "an install on Validation is refused 501")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Locales", "LIST", .tQuery, {"a": 1}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#SEAM, "Faults"), "500|INTERNAL|error", "a body is refused and the raw status logged")
    For tBad = "0", "x", "-1", "1.5" {
        Kill tQuery
        Set tQuery("maxRows") = tBad
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "Locales", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 400, "a maxRows of " _ tBad _ " is refused")
    }
    Kill tQuery
    Set tQuery("maxRows") = 2
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Locales", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%Size(), 1: -1) _ "|" _ tHttp, "2|200", "the port's list stops at maxRows")
}

/// <p>The locale source's refusals: each case replaces Locale definitions' <code>read.source</code> and names the sentence the registry's read check
/// answers, or <code>null</code>.</p>
XData Cases
{
{
  "cases": [
    {"name": "a locale LIST of Locales is sound", "source": {"port": "locale", "endpoint": "Locales", "type": "LIST"}, "expected": null},
    {"name": "an endpoint the port does not list", "source": {"port": "locale", "endpoint": "Validation", "type": "LIST"}, "expected": "read.source.endpoint 'Validation' is not one of the locale port's endpoints ('Locales', 'Properties') (AD-29)"},
    {"name": "a type other than LIST", "source": {"port": "locale", "endpoint": "Locales", "type": "GET"}, "expected": "read.source.type 'GET' is declared on a locale source, which lists the instance's locale definitions (AD-36)"},
    {"name": "rowGet", "source": {"port": "locale", "endpoint": "Locales", "type": "LIST", "rowGet": {"key": "Name", "param": "name", "fields": ["Description"], "derived": []}}, "expected": "read.source.rowGet is declared on a locale source, which answers its list whole (AD-36)"},
    {"name": "forEach", "source": {"port": "locale", "endpoint": "Locales", "type": "LIST", "forEach": ["Description"]}, "expected": "read.source.forEach is declared on a locale source, which answers its list whole (AD-36)"},
    {"name": "query", "source": {"port": "locale", "endpoint": "Locales", "type": "LIST", "query": {"a": "b"}}, "expected": "read.source.query is declared on a locale source, which answers its list whole (AD-36)"},
    {"name": "parts", "source": {"port": "locale", "endpoint": "Locales", "type": "LIST", "parts": [{"type": "LIST", "as": "x"}]}, "expected": "read.source.parts is declared on a locale source, which answers its list whole (AD-36)"}
  ]
}
}

/// <p>Every case of the <code>Cases</code> block gets its exact sentence, or none, from the registry, and the corpus refuses at least five shapes.</p>
/// <p>Mutation (Rule 19): <code>ReadProblem</code>'s locale arm admits any endpoint -> the endpoint case goes red.</p>
Method TestTheLocaleSourceRefusals()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Cases", , .tSC)
    Do $$$AssertTrue($IsObject(tXData), "the corpus is declared")
    If '$IsObject(tXData) Quit
    Set tCorpus = ##class(%DynamicObject).%FromJSON(tXData.Data)
    Set tRefusals = 0
    Set tIterator = tCorpus.cases.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCase) {
        Kill tDeclaration
        Do $ClassMethod(..#SCREEN, "DeclarationJson", .tDeclaration)
        Do tDeclaration.read.%Set("source", ##class(%DynamicObject).%FromJSON(tCase.source.%ToJSON()))
        Set tProblem = ##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration)
        Set tExpected = $Select(tCase.%GetTypeOf("expected") = "null": "", 1: tCase.expected)
        Do $$$AssertEquals(tProblem, tExpected, tCase.name)
        If tExpected '= "" Set tRefusals = tRefusals + 1
    }
    Do $$$AssertTrue(tRefusals >= 5, "the corpus refuses its shapes: " _ tRefusals)
}

/// <p>AC2, AC3, AC4, AD-5, AD-44, AD-51, AD-53. Locale definitions declares the classic locale page, the locale source's <code>Locales</code> endpoint,
/// OS management's thirty-seventh side-bar position, the classic page's pairs (the write pair is not the screen's own) and its three row actions; the
/// tools declare their names, screen actions, port, that the install and the delete are destructive and send no body, the consequence each card states,
/// pinned to the error class's, and the classic page they replace; and the validate tool is a read tool bound to the screen.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.LocaleInstall</class> declares <code>DESTRUCTIVE</code> 0 -> the destructive assertion goes red.</p>
Method TestTheScreenAndToolsDeclareTheirPageActionsAndConsequences()
{
    Set tClass = ..#SCREEN
    Do $$$AssertStatusOK($ClassMethod(tClass, "DeclarationJson", .tDeclaration), "the declaration parses")
    Do $$$AssertEquals($ClassMethod(tClass, "Route") _ "|" _ $ClassMethod(tClass, "AreaKey") _ "|" _ $ClassMethod(tClass, "SideBarPosition") _ "|" _ $ClassMethod(tClass, "ClassicPage"), "os-management/locales|os-management|37|%CSP.UI.Portal.NLS", "its route, area, position and classic page")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage($ZConvert("%CSP.UI.Portal.NLS", "O", "URL")), "%CSP.UI.Portal.NLS", "which the portal's own resolver recognises (AD-44)")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), "locale|validate,install,delete,copy,export,export-browser,import,import-local", "its entity type and its row actions")
    Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "locale|Locales|LIST", "it reads through the locale port")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read is the declared grammar")
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tClass, .tResolved)
    Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Admin_Manage", "USE")) && $ListFind(tPairs, $ListBuild("%DB_IRISSYS", "READ")) && '$ListFind(tPairs, $ListBuild("%DB_IRISSYS", "WRITE")), "it requires the classic page's pairs and not the write pair")
    For tCase = $ListBuild("LocaleInstall", "osmgmt.locales.install", "install", "INSTALL", 1, "LOCALE.INSTALL", "Current"), $ListBuild("LocaleDelete", "osmgmt.locales.delete", "delete", "DELETE", 1, "LOCALE.DELETE", "Description") {
        Set tTool = "OcuPilot.Screen.Tool." _ $List(tCase, 1)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $ClassMethod(tTool, "WriteType"), $List(tCase, 2) _ "|" _ $List(tCase, 3) _ "|" _ ..#PORT _ "|Locales|" _ $List(tCase, 4), $List(tCase, 1) _ ": its name, screen action, port, endpoint and request type")
        Do $$$AssertEquals(''$ClassMethod(tTool, "Destructive") _ "|" _ ''$ClassMethod(tTool, "SendsBody") _ "|" _ $ClassMethod(tTool, "Consequence", {}) _ "|" _ $Parameter(tTool, "CLASSICPAGES"), $List(tCase, 5) _ "|0|" _ $List(tCase, 6) _ "|%CSP.UI.Portal.NLS", $List(tCase, 1) _ ": destructive, bodyless, with its consequence and its classic page")
        Do $$$AssertEquals($Parameter(tTool, "PRECONDITIONFIELD"), $List(tCase, 7), $List(tCase, 1) _ ": its precondition field")
        Do $$$AssertEquals(##class(%Dictionary.CompiledMethod).%ExistsId(tTool _ "||Consequence"), 1, $List(tCase, 1) _ ": it states its consequence")
        Set tToolPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tToolResolved)
        Do $$$AssertTrue($ListFind(tToolPairs, $ListBuild("%DB_IRISSYS", "WRITE")), $List(tCase, 1) _ ": its tool adds the write pair")
    }
    Do $$$AssertEquals(##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.INSTALL"), "Installing makes this locale the instance's current locale, purges every cached query, and can change IRISTEMP's default collation.", "the install sentence is the published one")
    Do $$$AssertEquals(##class(OcuPilot.Api.LocaleError).ReasonFor("LOCALE.DELETE"), "The locale and its definition are removed from this instance.", "and so is the delete's")
    Do $$$AssertEquals($Parameter(..#VALIDATE, "TOOLNAME") _ "|" _ $Parameter(..#VALIDATE, "KIND") _ "|" _ $Parameter(..#VALIDATE, "DESCRIPTORCLASS"), "osmgmt.locales.validate|read|" _ tClass, "the validate tool is a read tool bound to the screen")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityType).IsKnown("locale"), 1, "the entity type is declared")
}

/// <p>AC3, AC4. The install and delete keys ship disabled in the baseline, and with none stored the agent's call for each is refused
/// <code>GOVERNANCE.DISABLED</code> at dispatch before anything is minted.</p>
/// <p>Mutation (Rule 19): <code>osmgmt.locales.install</code> set <code>true</code> in <class>OcuPilot.Kernel.Governance.Baseline</class> -> the baseline
/// assertion goes red for that key.</p>
Method TestTheInstallAndDeleteKeysShipDisabledAndTheAgentIsRefusedAtDispatch()
{
    For tI = 1:1:$Length(..#KEYS, ",") {
        Set tKey = $Piece(..#KEYS, ",", tI)
        Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved(tKey), "0|baseline", tKey _ " ships disabled by the baseline")
        Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
        Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
        If $$$ISERR(tSC) Continue
        Set tUse = {"type": "tool_use", "id": "toolu_locale", "input": {"Name": "yzzw", "rationale": "probe", "expectedImpact": "probe"}}
        Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(tKey), "string")
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
        Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
        Set tAnswer = ""
        If $IsObject($Get(tResults)) && (tResults.%Size() = 1) Set tAnswer = $Select(tResults.%Get(0).%Get("is_error"): 1, 1: 0) _ "|" _ tResults.%Get(0).%Get("content")
        Do $$$AssertEquals(tAnswer, "1|{""code"":""GOVERNANCE.DISABLED""}", tKey _ ": the agent's call is refused by the governance gate and nothing is minted")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    }
}

/// <p>The tables and the sub-tables the instance holds that the locale <var>pLocale</var> loads, read in <code>%SYS</code> independently of the port:
/// <code>$ListBuild(tableCount, subTableCount, type, from, to)</code>, the last three naming the locale's first table.</p>
ClassMethod VendorFootprint(pLocale As %String) As %List
{
    Set tOut = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tLocale = ##class(Config.NLS.Locales).%OpenId(pLocale)
        Do tLocale.GetTables(.tSet)
        Set tTables = 0
        Set tFirst = ""
        Set tType = ""
        For {
            Set tType = $Order(tSet(tType))
            If tType = "" Quit
            Set tFrom = ""
            For {
                Set tFrom = $Order(tSet(tType, tFrom))
                If tFrom = "" Quit
                Set tTo = ""
                For {
                    Set tTo = $Order(tSet(tType, tFrom, tTo))
                    If tTo = "" Quit
                    Set tTables = tTables + 1
                    If tFirst = "" Set tFirst = $ListBuild(tType, tFrom, tTo)
                    Kill tProps
                    If $$$ISOK(##class(Config.NLS.Tables).Get(tType, tFrom, tTo, .tProps)) && ($Get(tProps("SubTableName")) '= "") Set tNamed($Get(tProps("SubTableName"))) = ""
                }
            }
        }
        Set tSubTables = 0
        Set tName = ""
        For {
            Set tName = $Order(tNamed(tName))
            If tName = "" Quit
            If ##class(Config.NLS.SubTables).Exists(tName) Set tSubTables = tSubTables + 1
        }
        Set tOut = $ListBuild(tTables, tSubTables) _ tFirst
    } Catch {
        Set tOut = ""
    }
    Set tLocale = ""
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p>The number of nodes <var>pNodes</var> holds at <var>pDepth</var> subscripts.</p>
ClassMethod CountNodes(ByRef pNodes, pDepth As %Integer) As %Integer
{
    Set tCount = 0
    Set tA = ""
    For {
        Set tA = $Order(pNodes(tA))
        If tA = "" Quit
        If pDepth = 1 {
            Set tCount = tCount + 1
            Continue
        }
        Set tB = ""
        For {
            Set tB = $Order(pNodes(tA, tB))
            If tB = "" Quit
            Set tC = ""
            For {
                Set tC = $Order(pNodes(tA, tB, tC))
                If tC = "" Quit
                Set tCount = tCount + 1
            }
        }
    }
    Quit tCount
}

/// <p><b>AC3 (the current-locale footprint).</b> <method>OcuPilot.Port.LocalePort.CurrentFootprint</method> answers the live current locale's name, and
/// <method>OcuPilot.Port.LocalePort.LocaleFootprint</method> of it holds as many tables and sub-tables as an independent read of the locale's own
/// <code>GetTables</code> and its tables' <code>SubTableName</code>, with the locale's first real table among its subscripts as type, from, to.</p>
/// <p>Mutation (Rule 19): the subscript order transposed in <code>LocaleFootprint</code> -> the first-table row goes red.</p>
Method TestTheCurrentFootprintIsTheCurrentLocalesOwnTablesAndSubTables()
{
    Do ..VendorList(.tVendorCurrent)
    Set tSC = $ClassMethod(..#PORT, "CurrentFootprint", .tCurrent, .tTables, .tSubTables)
    Do $$$AssertStatusOK(tSC, "the footprint is read")
    Do $$$AssertTrue((tVendorCurrent '= "") && (tCurrent = tVendorCurrent), "it names the live current locale: " _ tCurrent)
    Set tVendor = ..VendorFootprint(tVendorCurrent)
    Do $$$AssertTrue($ListLength(tVendor) = 5, "the independent read finds the current locale's tables")
    If $ListLength(tVendor) '= 5 Quit
    Do $$$AssertEquals(..CountNodes(.tTables, 3) _ "|" _ ..CountNodes(.tSubTables, 1), $List(tVendor, 1) _ "|" _ $List(tVendor, 2), "its tables and sub-tables are as many as the independent read finds")
    Do $$$AssertTrue($List(tVendor, 1) > 0, "and the locale loads tables")
    Do $$$AssertTrue($Data(tTables($List(tVendor, 3), $List(tVendor, 4), $List(tVendor, 5))) = 1, "a table the vendor names is among its subscripts, as type, from and to")
}

}
