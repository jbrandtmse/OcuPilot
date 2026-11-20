/// <p>Pins Story 21.19's refusals of the Task Manager email settings (AC2; AD-29, AD-35, AD-39, AD-55): every refusal of the matrix, asked of the port's
/// own set through <class>OcuPilot.Test.ConfigGateSeam</class>, whose vendor call is recorded and never made, and of the agent's mint, so a
/// value the rules refuse reaches no vendor call from either caller. A port is empty or a whole number from 1 to 65535; a subject and a message
/// hold only the fields the Task Manager substitutes, as <code>%SYS.Task.Config.SubstitutionsValid</code> judges them; the mail password is
/// no setting any of them names.</p>
/// <p><b>Live-safe:</b> no setting is changed; the only write is a proposal row the mint stores and the test removes. <b>What it needs from the
/// environment:</b> OcuPilot installed and serving.</p>
Class OcuPilot.Test.TaskMailSettingRules Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter SEAM = "OcuPilot.Test.ConfigGateSeam";

Parameter ERROR = "OcuPilot.Api.ConfigError";

Parameter RULES = "OcuPilot.Area.OsMgmt.ConfigSettingRules";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter TOOL = "OcuPilot.Screen.Tool.TaskMailSettingSet";

Parameter ENDPOINT = "TaskMail";

Parameter VALUE = "CONFIG.SETTING.VALUE";

Parameter SUBSTITUTION = "CONFIG.SETTING.SUBSTITUTION";

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

/// <p>Hold every pair the port's write names, in the gate's test seam.</p>
ClassMethod HoldAll()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
}

/// <p>The matrix as a list of <code>$ListBuild(setting, value, expected)</code>, where expected is the refusal code, <code>ok</code> or
/// <code>absent</code> for a name the port does not list.</p>
ClassMethod Cases() As %List
{
    Set tLong = $Justify("", 256)
    Set tLong = $Translate(tLong, " ", "a")
    Set tHuge = $Translate($Justify("", 32001), " ", "a")
    Set tFields = "Task #(NAME)# #(ID)# #(SUCCESS)# on #(SERVER)#:#(INSTANCE)#"
    Quit $ListBuild($ListBuild("Port", "587", "ok"), $ListBuild("Port", "", "ok"), $ListBuild("Port", "1", "ok"), $ListBuild("Port", "65535", "ok"), $ListBuild("Port", "0", ..#VALUE), $ListBuild("Port", "65536", ..#VALUE), $ListBuild("Port", "99999", ..#VALUE), $ListBuild("Port", "-1", ..#VALUE), $ListBuild("Port", "587.5", ..#VALUE), $ListBuild("Port", "0587", ..#VALUE), $ListBuild("Port", " 587", ..#VALUE), $ListBuild("Port", "smtp", ..#VALUE), $ListBuild("Port", "123456", ..#VALUE), $ListBuild("Port", "5" _ $Char(10), ..#VALUE),
        $ListBuild("UseSTARTTLS", "1", "ok"), $ListBuild("UseSTARTTLS", "0", "ok"), $ListBuild("UseSTARTTLS", "2", ..#VALUE), $ListBuild("UseSTARTTLS", "", ..#VALUE), $ListBuild("UseSTARTTLS", "true", ..#VALUE),
        $ListBuild("Server", "smtp.example.com", "ok"), $ListBuild("Server", "", "ok"), $ListBuild("Server", tLong, ..#VALUE), $ListBuild("Server", "smtp" _ $Char(10) _ "host", ..#VALUE),
        $ListBuild("SubjectSuccess", tFields, "ok"), $ListBuild("SubjectSuccess", "", "ok"), $ListBuild("SubjectSuccess", "No fields at all", "ok"), $ListBuild("SubjectFailure", "x #(BOGUS)# y", ..#SUBSTITUTION), $ListBuild("SubjectSuccess", "#(name)#", ..#SUBSTITUTION), $ListBuild("SubjectSuccess", "#(NAME)# #(NOPE)#", ..#SUBSTITUTION), $ListBuild("SubjectSuccess", "a" _ $Char(13, 10) _ "Bcc: x@example.com", ..#VALUE), $ListBuild("SubjectSuccess", tLong, ..#VALUE),
        $ListBuild("MessageSuccess", tFields, "ok"), $ListBuild("MessageSuccess", "Line one" _ $Char(13, 10) _ "Line two" _ $Char(9) _ "#(ERROR)#", "ok"), $ListBuild("MessageFailure", $Translate($Justify("", 32000), " ", "b"), "ok"), $ListBuild("MessageFailure", "x #(BOGUS)# y", ..#SUBSTITUTION), $ListBuild("MessageFailure", "x #(NAME)# #(TASK)#", ..#SUBSTITUTION), $ListBuild("MessageFailure", tHuge, ..#VALUE), $ListBuild("MessageSuccess", "bell" _ $Char(7), ..#VALUE),
        $ListBuild("AuthPassword", "x", "absent"), $ListBuild("authpassword", "x", "absent"), $ListBuild("MailPort", "587", "absent"), $ListBuild("NoSuchSetting", "1", "absent"))
}

/// <p><b>AC2.</b> Every row of the matrix at the port: a value the rules refuse is answered on the code and status
/// <class>OcuPilot.Api.ConfigError</class> names with nothing sent to the vendor, a name the port does not list, the mail password included, is 404
/// <code>CONFIG.SETTING.NOTFOUND</code>, and a value the rules pass is sent once, as the one setting and its value.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class>'s <code>TaskMailCode</code> drops the port-range rule (the
/// <code>MAXPORT</code> comparison) -> the <code>65536</code> and <code>99999</code> rows go red, with a vendor call recorded.</p>
Method TestEveryMatrixRowIsAnsweredOnItsCodeAndSendsNothingToTheVendorWhenRefused()
{
    Do ..HoldAll()
    Set tCases = ..Cases()
    Set tPosition = 0
    While $ListNext(tCases, tPosition, tCase) {
        Set tName = $List(tCase, 1)
        Set tValue = $List(tCase, 2)
        Set tExpected = $List(tCase, 3)
        Do $ClassMethod(..#SEAM, "Reset")
        Kill tQuery
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "SET", .tQuery, {"Value": (tValue)}, .tOut, .tHttp, .tFault)
        Set tCode = $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
        Set tWanted = $Case(tExpected, "ok": "200|", "absent": "404|CONFIG.SETTING.NOTFOUND", : $ClassMethod(..#ERROR, "HttpStatusFor", tExpected) _ "|" _ tExpected)
        Set tLabel = tName _ " (" _ $Length(tValue) _ " characters): " _ tExpected
        Do $$$AssertEquals(tHttp _ "|" _ tCode, tWanted, tLabel)
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Modifies"), $Select(tExpected = "ok": ..#ENDPOINT _ "|" _ tName _ "|" _ tValue, 1: ""), tLabel _ ": " _ $Select(tExpected = "ok": "sent once, as the one setting", 1: "nothing reached the vendor"))
    }
}

/// <p><b>AC2.</b> A refused substitution is answered 400 <code>CONFIG.SETTING.SUBSTITUTION</code> with the ruled sentence, whose
/// <code>&lt;fields&gt;</code> is the Task Manager's own fourteen fields in its own order, at the port's wire and in the reasons the codes
/// dispatch reaches.</p>
/// <p>Mutation (Rule 19): <code>SubstitutionReason</code> returns the template without its fields -> the sentence assertions go red.</p>
Method TestTheSubstitutionRefusalNamesTheTaskManagersFields()
{
    Do ..HoldAll()
    Set tFields = ##class(%SYS.Task.Config).SubstitutionFields()
    Do $$$AssertEquals($Length(tFields, ","), 14, "the Task Manager lists fourteen fields")
    Set tSentence = "Use only these fields between #( and )#: " _ $Replace(tFields, ",", ", ") _ "."
    Do $$$AssertEquals($ClassMethod(..#ERROR, "ReasonFor", ..#SUBSTITUTION), tSentence, "the code's sentence names them, comma and space apart")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(..#SUBSTITUTION) _ "|" _ ##class(OcuPilot.Api.Error).ReasonForToolCode(..#SUBSTITUTION), tSentence _ "|" _ tSentence, "and the violation and tool-code dispatches reach it")
    Do $$$AssertEquals($ClassMethod(..#ERROR, "HttpStatusFor", ..#SUBSTITUTION) _ "|" _ $ClassMethod(..#ERROR, "SlugFor", ..#SUBSTITUTION) _ "|" _ ##class(OcuPilot.Api.Error).IsValidCode(..#SUBSTITUTION), "400|bad_request|1", "it is a well-formed 400")
    Kill tQuery
    Set tQuery("name") = "SubjectFailure"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "SET", .tQuery, {"Value": "#(BOGUS)#"}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: ""), "400|" _ tSentence, "the port's answer carries the sentence on the wire")
}

/// <p><b>AC2.</b> The rules ask the Task Manager's own validator and agree with it: for each text the rules' substitution check answers what
/// <code>%SYS.Task.Config.SubstitutionsValid</code> answers.</p>
/// <p>Mutation (Rule 19): <code>SubstitutionsHold</code> answers 1 -> the bogus-field rows go red.</p>
Method TestTheRulesAgreeWithTheVendorsValidator()
{
    For tText = "", "plain", "#(NAME)#", "#(NAME)# and #(ID)#", "#(BOGUS)#", "#(name)#", "#()#", "#(NAME)", "#(NAME", "(NAME)#", "a #(ID)##(BOGUS)# b", "#(ID)#,#(NAME)#" {
        Set tBad = ""
        Set tVendor = ''##class(%SYS.Task.Config).SubstitutionsValid(tText, .tBad)
        Do $$$AssertEquals($ClassMethod(..#RULES, "SubstitutionsHold", tText), tVendor, "'" _ tText _ "' is judged as the Task Manager judges it")
    }
}

/// <p><b>AC2, AD-35.</b> The agent's mint asks the same rules: a port out of range, a field the Task Manager does not fill in and the mail
/// password are each refused with the published sentence and mint nothing; a value the setting accepts mints a proposal whose one diff row is the
/// value, and nothing is confirmed.</p>
/// <p>Mutation (Rule 19): <code>ConfigSettingSet.ArgumentProblem</code> answers no problem -> the refusal assertions go red.</p>
Method TestTheMintRefusesWhatThePortRefuses()
{
    Set tTool = ..#TOOL
    Set tSC = $ClassMethod(..#AGENT, "Mint", tTool, "Port", {"Name": "Port", "Value": "65536"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject(tProposal) _ "|" _ tProblem, "0|" _ $ClassMethod(..#ERROR, "ReasonFor", ..#VALUE), "a port out of range mints nothing and is answered with its sentence")
    Set tSC = $ClassMethod(..#AGENT, "Mint", tTool, "SubjectSuccess", {"Name": "SubjectSuccess", "Value": "#(BOGUS)#"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject(tProposal) _ "|" _ tProblem, "0|" _ $ClassMethod(..#ERROR, "ReasonFor", ..#SUBSTITUTION), "a field the Task Manager does not fill in mints nothing and is answered with the fields")
    Set tSC = $ClassMethod(..#AGENT, "Mint", tTool, "AuthPassword", {"Name": "AuthPassword", "Value": "x"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject(tProposal) _ "|" _ tProblem, "0|'AuthPassword' is not present on this instance", "the mail password is no setting of this tool, and nothing is minted")
    Set tSC = $ClassMethod(..#AGENT, "Mint", tTool, "Port", {"Name": "Port", "Value": "587"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject(tProposal), 1, "a port the setting accepts mints a proposal: " _ tProblem)
    If '$IsObject(tProposal) Quit
    Set tChanged = tProposal.%Get("changed")
    Do $$$AssertEquals(tChanged.%Size() _ "|" _ tChanged.%Get(0).%Get("field") _ "|" _ tChanged.%Get(0).%Get("after"), "1|Value|587", "whose one diff row is the value")
    Do $$$AssertEquals(tProposal.%ToJSON() [ "AuthPassword", 0, "and which names no mail password")
}

/// <p><b>AC2, AD-59.</b> A set renders as one script step of the vendor's own <code>EmailSet</code>, with the name and the value as string
/// literals so nothing the caller sent runs as code; a read renders none.</p>
Method TestTheSetRendersAsAScriptAndAReadRendersNone()
{
    Kill tQuery
    Set tQuery("name") = "Port"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "SET", .tQuery, {"Value": "587"})
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", ..#ENDPOINT, "SET") _ "|" _ tSteps.%Size() _ "|" _ tSteps.%Get(0).%Get("kind"), "objectscript|1|objectscript", "a set is one script step")
    Do $$$AssertEquals(tSteps.%Get(0).%Get("text"), " Set $NAMESPACE = ""%SYS""" _ $Char(10) _ " Set tSC = ##class(%SYS.Task.Config).EmailSet(""Port"", ""587"")", "naming the vendor's setter, the setting and the value")
    Set tQuery("name") = "SubjectSuccess"
    Set tHostile = "a""b #(NAME)#"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "SET", .tQuery, {"Value": (tHostile)})
    Set tText = tSteps.%Get(0).%Get("text")
    Do $$$AssertTrue(tText [ ("EmailSet(" _ $ClassMethod("OcuPilot.Port.AdminPort", "Literal", "SubjectSuccess") _ ", " _ $ClassMethod("OcuPilot.Port.AdminPort", "Literal", tHostile) _ ")"), "a value holding a quote is a string literal: " _ tText)
    Set tQuery("name") = "AuthPassword"
    Set tNone = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "SET", .tQuery, {"Value": "x"})
    Do $$$AssertEquals(tNone.%Size(), 0, "the mail password renders no script")
    Set tRead = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "LIST", .tQuery)
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", ..#ENDPOINT, "LIST") _ "|" _ tRead.%Size(), "|0", "a read has no script form")
}

}
