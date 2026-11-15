/// <p>Pins Story 21.3's refusals (AC1, AC3; AD-29, AD-39, AD-55): every refusal row of the matrix, asked three ways -- of the rules over
/// the row the port answers, of the port's own set through <class>OcuPilot.Test.ConfigGateSeam</class>, whose vendor call is recorded and
/// never made, and of the agent's mint -- so a value the rules refuse reaches no vendor call from either caller, and the codes and sentences
/// of <class>OcuPilot.Api.ConfigError</class> are the published ones.</p>
/// <p><b>Live-safe:</b> no setting is changed; the only write is a proposal row the mint stores and the test removes. <b>What it needs from the
/// environment:</b> OcuPilot installed and serving.</p>
Class OcuPilot.Test.ConfigSettingRules Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter SEAM = "OcuPilot.Test.ConfigGateSeam";

Parameter ERROR = "OcuPilot.Api.ConfigError";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

/// <p>The matrix rows as <code>endpoint|setting|value|expected</code>, where expected is the refusal code or <code>ok</code>.</p>
Parameter ROWS = "Startup|ShutdownTimeout|119|CONFIG.SETTING.VALUE;Startup|ShutdownTimeout|100001|CONFIG.SETTING.VALUE;Startup|ShutdownTimeout|1.5|CONFIG.SETTING.VALUE;Startup|ShutdownTimeout|x|CONFIG.SETTING.VALUE;Startup|ShutdownTimeout||CONFIG.SETTING.VALUE;Startup|ShutdownTimeout|0301|CONFIG.SETTING.VALUE;Startup|ShutdownTimeout|301|ok;Startup|ShutdownTimeout|120|ok;Startup|ShutdownTimeout|100000|ok;Startup|DefaultPort|1972|CONFIG.SETTING.READONLY;Startup|DefaultPortBindAddress|x|CONFIG.SETTING.READONLY;Startup|WebServer|0|CONFIG.SETTING.READONLY;Startup|WebServerPort|52773|CONFIG.SETTING.READONLY;Startup|TempDirectory|x|CONFIG.SETTING.READONLY;Startup|WebServerURLPrefix|x|CONFIG.SETTING.READONLY;Startup|NoSuchSetting|1|CONFIG.SETTING.NOTFOUND;Startup|ZaMode|1|CONFIG.SETTING.NOTFOUND;Startup|SystemMode|TEST|ok;Startup|SystemMode||ok;Startup|SystemMode|012345678901234567890123456789012|CONFIG.SETTING.VALUE;Startup|WebServerProtocol|ftp|CONFIG.SETTING.VALUE;Startup|WebServerProtocol|https|ok;Startup|ErrorPurge|1|ok;Startup|ErrorPurge|0|CONFIG.SETTING.VALUE;Startup|DBSizesAllowed|16384|CONFIG.SETTING.VALUE;Startup|DBSizesAllowed|8192,1024|CONFIG.SETTING.VALUE;Startup|DBSizesAllowed|8192,8192|CONFIG.SETTING.VALUE;Startup|DBSizesAllowed|8192|ok;Memory|bbsiz|100|CONFIG.SETTING.VALUE;Memory|bbsiz|-1|ok;Memory|bbsiz|256|ok;Memory|routines|5|CONFIG.SETTING.VALUE;Memory|routines|65537|CONFIG.SETTING.VALUE;Memory|routines|0|ok;Memory|routines|36|ok;Memory|history|1001|CONFIG.SETTING.VALUE;Memory|history|-1|CONFIG.SETTING.VALUE;Memory|history|501|ok;Memory|errlog|9|CONFIG.SETTING.VALUE;Memory|errlog|501|ok;Memory|gmheap|-5|CONFIG.SETTING.VALUE;Memory|gmheap|1073741761|CONFIG.SETTING.VALUE;Memory|gmheap|0|ok;Memory|ConsoleFile|x|CONFIG.SETTING.READONLY;Memory|LibPath|x|CONFIG.SETTING.READONLY;Memory|PythonRuntimeLibrary|x|CONFIG.SETTING.READONLY;Memory|globals2kb|1|CONFIG.SETTING.NOTFOUND;Compatibility|LineRecall|2|CONFIG.SETTING.VALUE;Compatibility|LineRecall|true|CONFIG.SETTING.VALUE;Compatibility|LineRecall|0|ok;Compatibility|LineRecall|1|ok;Compatibility|Undefined|3|CONFIG.SETTING.VALUE;Compatibility|Undefined|2|ok;Compatibility|ListFormat|5|CONFIG.SETTING.VALUE;Compatibility|ListFormat|0|ok;Compatibility|NullSubscripts|1|ok;Compatibility|ZaMode|1|CONFIG.SETTING.NOTFOUND";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>Hold every pair the port's sets name, in the gate's test seam.</p>
ClassMethod HoldAll()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
}

/// <p>The vendor class endpoint <var>pEndpoint</var> sets.</p>
ClassMethod VendorClass(pEndpoint As %String) As %String
{
    Quit $ClassMethod(..#PORT, "VendorClass", pEndpoint)
}

/// <p><b>AC1, AC3.</b> Every row of the matrix at the port: a value the rules refuse, a setting shown and never changed and a name the class
/// does not list are each answered on the code and status <class>OcuPilot.Api.ConfigError</class> names with nothing sent to the vendor, and
/// a value the rules pass is sent once, as the one key, to the vendor class that endpoint names.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>READONLY</code> loses <code>DefaultPort</code> -> the
/// <code>DefaultPort</code> row goes red, with a vendor call recorded.</p>
Method TestEveryMatrixRowIsAnsweredOnItsCodeAndSendsNothingToTheVendorWhenRefused()
{
    Do ..HoldAll()
    Set tSizeOk = $ClassMethod(..#PORT, "BlockSizeAvailable", 16384)
    For tI = 1:1:$Length(..#ROWS, ";") {
        Set tRow = $Piece(..#ROWS, ";", tI)
        Set tEndpoint = $Piece(tRow, "|", 1)
        Set tName = $Piece(tRow, "|", 2)
        Set tValue = $Piece(tRow, "|", 3)
        Set tExpected = $Piece(tRow, "|", 4)
        Do $ClassMethod(..#SEAM, "Reset")
        Kill tQuery
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "SET", .tQuery, {"Value": (tValue)}, .tOut, .tHttp, .tFault)
        Set tCode = $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
        Set tWanted = $Select(tExpected = "ok": "200|", 1: $ClassMethod(..#ERROR, "HttpStatusFor", tExpected) _ "|" _ tExpected)
        Set tSent = $ClassMethod(..#SEAM, "Modifies")
        Do $$$AssertEquals(tHttp _ "|" _ tCode, tWanted, tEndpoint _ " " _ tName _ " '" _ tValue _ "': " _ $Select(tExpected = "ok": "accepted", 1: tExpected))
        Do $$$AssertEquals(tSent, $Select(tExpected = "ok": ..VendorClass(tEndpoint) _ "|" _ tName _ "|" _ tValue, 1: ""), tEndpoint _ " " _ tName _ " '" _ tValue _ "': " _ $Select(tExpected = "ok": "sent once, as the one key", 1: "nothing reached the vendor"))
    }
    Do $ClassMethod(..#SEAM, "Reset")
    Kill tQuery
    Set tQuery("name") = "DBSizesAllowed"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Startup", "SET", .tQuery, {"Value": "8192,16384"}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, $Select(tSizeOk: 200, 1: 400), "8192 with 16384 is accepted exactly when the instance offers 16384")
}

/// <p><b>AC1, AD-4.</b> A set sends the complete property set: every key the vendor class's <code>Get</code> answers, the excluded and the
/// read-only keys among them as they were read, with the one key changed, and no comment.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>VendorModify</code> sends the one key alone -> the key-list
/// assertion goes red.</p>
Method TestASetSendsEveryKeyTheClassAnswersWithTheOneKeyChanged()
{
    Do ..HoldAll()
    For tCase = $ListBuild("Startup", "ShutdownTimeout", "301"), $ListBuild("Memory", "history", "501"), $ListBuild("Compatibility", "LineRecall", "0") {
        Do $ClassMethod(..#SEAM, "Reset")
        Kill tQuery
        Set tQuery("name") = $List(tCase, 2)
        Set tSC = $ClassMethod(..#SEAM, "Invoke", $List(tCase, 1), "SET", .tQuery, {"Value": ($List(tCase, 3))}, .tOut, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, $List(tCase, 1) _ ": the set is sent")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "SentKeys"), $ClassMethod("OcuPilot.Test.ConfigSettingRead", "VendorKeys", ..VendorClass($List(tCase, 1))), $List(tCase, 1) _ ": every key the class answers is sent")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Modifies"), ..VendorClass($List(tCase, 1)) _ "|" _ $List(tCase, 2) _ "|" _ $List(tCase, 3), $List(tCase, 1) _ ": with the one key changed")
    }
}

/// <p><b>AC1.</b> The rules answer the same codes over the row the port reads, for the three that matter beside the matrix: an
/// object body without a text <code>Value</code> is refused 400 <code>PORT.VALIDATION</code>; a vendor <code>Modify</code> the rules did not
/// foresee is answered 400 <code>CONFIG.SETTING.VALUE</code> with nothing stored; and a caller body on a read is refused.</p>
/// <p>Mutation (Rule 19): <code>SetValue</code> maps a vendor refusal to success -> the vendor refusal assertion goes red.</p>
Method TestTheBodyShapeAndAVendorRefusalAreAnsweredOnTheirOwnCodes()
{
    Do ..HoldAll()
    Kill tQuery
    Set tQuery("name") = "ShutdownTimeout"
    For tBody = {}, {"Name": "ShutdownTimeout"}, {"Value": 301}, "x" {
        Do $ClassMethod(..#SEAM, "Reset")
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "Startup", "SET", .tQuery, tBody, .tOut, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "") _ "|" _ $ClassMethod(..#SEAM, "Modifies"), "400|PORT.VALIDATION|", "a set body that is not an object with a text Value is refused and sends nothing")
    }
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "VendorRefuses")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Startup", "SET", .tQuery, {"Value": "301"}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "") _ "|" _ $IsObject($Get(tOut)), "400|CONFIG.SETTING.VALUE|0", "a value the rules pass and the vendor refuses is answered as a value this setting does not accept, and answers no write")
    Do $ClassMethod(..#SEAM, "Reset")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Startup", "GET", .tQuery, {"Value": "301"}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#SEAM, "Modifies"), "500|", "a read that is given a body is refused as an internal fault and sends nothing")
}

/// <p><b>AC1, AC3.</b> The agent's mint asks the same rules: a value a setting does not accept and a setting shown and never changed are
/// refused with the published sentence and mint nothing; a name the instance does not list is refused; a value the setting accepts
/// mints a proposal whose one diff row is the value, and nothing is confirmed.</p>
/// <p>Mutation (Rule 19): <code>ConfigSettingSet.ArgumentProblem</code> answers no problem -> the two refusal assertions go red.</p>
Method TestTheMintRefusesWhatThePortRefuses()
{
    Set tSC = $ClassMethod(..#AGENT, "Mint", "OcuPilot.Screen.Tool.StartupSettingSet", "ShutdownTimeout", {"Name": "ShutdownTimeout", "Value": "119"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject(tProposal) _ "|" _ tProblem, "0|" _ $ClassMethod(..#ERROR, "ReasonFor", "CONFIG.SETTING.VALUE"), "a value out of range mints nothing and is answered with its sentence")
    Set tSC = $ClassMethod(..#AGENT, "Mint", "OcuPilot.Screen.Tool.StartupSettingSet", "DefaultPort", {"Name": "DefaultPort", "Value": "1973"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject(tProposal) _ "|" _ tProblem, "0|" _ $ClassMethod(..#ERROR, "ReasonFor", "CONFIG.SETTING.READONLY"), "a setting shown and never changed mints nothing and is answered with its sentence")
    Set tSC = $ClassMethod(..#AGENT, "Mint", "OcuPilot.Screen.Tool.MemorySettingSet", "NoSuchSetting", {"Name": "NoSuchSetting", "Value": "1"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject(tProposal) _ "|" _ tProblem, "0|'NoSuchSetting' is not present on this instance", "a name the instance does not list mints nothing and is answered in the sentence the sibling mints give")
    Set tSC = $ClassMethod(..#AGENT, "Mint", "OcuPilot.Screen.Tool.CompatibilitySettingSet", "LineRecall", {"Name": "LineRecall", "Value": "2"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject(tProposal) _ "|" _ tProblem, "0|" _ $ClassMethod(..#ERROR, "ReasonFor", "CONFIG.SETTING.VALUE"), "a boolean setting refuses 2 at the mint")
    Set tHistory = ##class(OcuPilot.Test.ConfigSettingRead).Unlike("Memory", "history", "501") _ ""
    Set tArgs = {"Name": "history"}
    Do tArgs.%Set("Value", tHistory, "string")
    Set tSC = $ClassMethod(..#AGENT, "Mint", "OcuPilot.Screen.Tool.MemorySettingSet", "history", tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject(tProposal), 1, "a value the setting accepts mints a proposal: " _ tProblem)
    If '$IsObject(tProposal) Quit
    Set tChanged = tProposal.%Get("changed")
    Do $$$AssertEquals(tChanged.%Size() _ "|" _ tChanged.%Get(0).%Get("field") _ "|" _ tChanged.%Get(0).%Get("after"), "1|Value|" _ tHistory, "whose one diff row is the value")
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), "", "and which states no consequence for a setting that needs no restart")
    Set tArgs = {"Name": "errlog"}
    Do tArgs.%Set("Value", ##class(OcuPilot.Test.ConfigSettingRead).Unlike("Memory", "errlog", "501") _ "", "string")
    Set tSC = $ClassMethod(..#AGENT, "Mint", "OcuPilot.Screen.Tool.MemorySettingSet", "errlog", tArgs, .tRestart, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject(tRestart), 1, "a restart-bound value mints too: " _ tProblem)
    If $IsObject(tRestart) Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tRestart), "CONFIG.SETTING.RESTART", "and its card states the restart consequence")
}

/// <p>AD-29, AD-39. The codes, statuses, slugs and sentences are the published ones, the dispatch by prefix reaches them, and an
/// <code>Accepts</code> sentence takes its numbers.</p>
Method TestTheCodesAndSentencesArePublished()
{
    For tCase = $ListBuild("CONFIG.SETTING.NOTFOUND", "There is no setting with that name.", 404, "not_found"), $ListBuild("CONFIG.SETTING.READONLY", "This setting is shown here and never changed here.", 409, "conflict"), $ListBuild("CONFIG.SETTING.VALUE", "This setting does not accept that value.", 400, "bad_request") {
        Set tCode = $List(tCase, 1)
        Do $$$AssertEquals($ClassMethod(..#ERROR, "ReasonFor", tCode) _ "|" _ $ClassMethod(..#ERROR, "HttpStatusFor", tCode) _ "|" _ $ClassMethod(..#ERROR, "SlugFor", tCode), $List(tCase, 2) _ "|" _ $List(tCase, 3) _ "|" _ $List(tCase, 4), tCode _ ": its sentence, status and slug")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), $List(tCase, 2), tCode _ ": the violation dispatch reaches it")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), $List(tCase, 2), tCode _ ": and so does the tool-code dispatch")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).IsValidCode(tCode), 1, tCode _ " is a well-formed machine code")
    }
    Do $$$AssertEquals($ClassMethod(..#ERROR, "ReasonFor", "CONFIG.SETTING.RESTART") _ "|" _ $ClassMethod(..#ERROR, "HttpStatusFor", "CONFIG.SETTING.RESTART"), "Takes effect at the next restart.|0", "the restart code is a consequence with a sentence and no status")
    Do $$$AssertEquals($ClassMethod(..#ERROR, "ReasonFor", "CONFIG.NO.SUCH"), "", "and a code the class does not declare carries none")
    Do $$$AssertEquals($ClassMethod(..#ERROR, "Accepting", $Parameter(..#ERROR, "ACCEPTSRANGE"), 120, 100000), "A whole number from 120 to 100000.", "a range sentence takes its two numbers")
    Do $$$AssertEquals($ClassMethod(..#ERROR, "Accepting", $Parameter(..#ERROR, "ACCEPTSCHOICE"), "0, 1, 2"), "One of 0, 1, 2.", "a choice sentence takes its list")
    Set tRules = "OcuPilot.Area.OsMgmt.ConfigSettingRules"
    Do $$$AssertEquals($ClassMethod(tRules, "ValueHolds", $ListBuild("text", "", "", "", 32, ""), "A" _ $Char(10) _ "B") _ $ClassMethod(tRules, "ValueHolds", $ListBuild("text", "", "", "", 32, ""), "AB"), "01", "a text value holding a control character is refused, and the same text without it is not")
    Do $$$AssertEquals($ClassMethod(tRules, "ValueHolds", $ListBuild("integer", 0, "", "", "", ""), "1234567890123456") _ $ClassMethod(tRules, "ValueHolds", $ListBuild("integer", 0, "", "", "", ""), "123456789012345"), "01", "a whole number longer than fifteen digits is refused, and one of fifteen is not")
}

/// <p>AD-59. A set renders as a script of the vendor's own <code>Get</code>, the one key and <code>Modify</code>, in <code>%SYS</code>, with
/// the name and the value as string literals so nothing the caller sent runs as code; a read renders none.</p>
Method TestTheSetRendersAsAScriptAndAReadRendersNone()
{
    Kill tQuery
    Set tQuery("name") = "ShutdownTimeout"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Startup", "SET", .tQuery, {"Value": "301"})
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Startup", "SET") _ "|" _ tSteps.%Size() _ "|" _ tSteps.%Get(0).%Get("kind"), "objectscript|1|objectscript", "a set is one script step")
    Set tText = tSteps.%Get(0).%Get("text")
    Do $$$AssertEquals(tText, " Set $NAMESPACE = ""%SYS""" _ $Char(10) _ " Set tSC = ##class(Config.Startup).Get(.tProps)" _ $Char(10) _ " Set tProps(""ShutdownTimeout"") = ""301""" _ $Char(10) _ " Set tSC = ##class(Config.Startup).Modify(.tProps)", "naming the class, the key and the value")
    Set tHostileName = "x"") Halt ;"
    Set tQuery("name") = tHostileName
    Set tHostileValue = "a""b"
    Set tHostile = $ClassMethod(..#PORT, "Snippet", "Memory", "SET", .tQuery, {"Value": (tHostileValue)})
    Set tText = tHostile.%Get(0).%Get("text")
    Set tAdmin = "OcuPilot.Port.AdminPort"
    Do $$$AssertTrue(tText [ ("Set tProps(" _ $ClassMethod(tAdmin, "Literal", tHostileName) _ ") = " _ $ClassMethod(tAdmin, "Literal", tHostileValue)), "a hostile name and value are string literals: " _ tText)
    Do $$$AssertEquals($Length(tText, $Char(10)), 4, "and add no line of their own")
    Set tRead = $ClassMethod(..#PORT, "Snippet", "Startup", "LIST", .tQuery)
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Startup", "LIST") _ "|" _ tRead.%Size(), "|0", "a read has no script form")
}

}
