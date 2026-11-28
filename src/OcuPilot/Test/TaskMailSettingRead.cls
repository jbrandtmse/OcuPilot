/// <p>Pins Story 21.19's Task Manager email read, gate and declarations (AC2, AC6; AD-22, AD-29, AD-35, AD-36): the screen and the port read one row per
/// name of the port's roster, each valued as <code>%SYS.Task.Config.EmailGet</code> answers it, and no row names the mail password; a vendor read that
/// fails is a fault and never an empty row; every read and write is refused to a caller short of a pair before any vendor call; the screen and its
/// tool declare the classic page, the Tasks position, the pairs and the action; and the set key ships enabled.</p>
/// <p><b>Live-safe:</b> it reads, changes no setting, and stores a governance policy only to restore it. <b>What it needs from the
/// environment:</b> OcuPilot installed and serving.</p>
Class OcuPilot.Test.TaskMailSettingRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter SEAM = "OcuPilot.Test.ConfigGateSeam";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.TaskMailSettingList";

Parameter TOOL = "OcuPilot.Screen.Tool.TaskMailSettingSet";

Parameter KEY = "tasks.mail.set";

Parameter ENDPOINT = "TaskMail";

/// <p>The twelve names the roster must name and nothing else, in the order a list answers them.</p>
Parameter NAMES = "AuthUser,MessageFailure,MessageSuccess,Port,ReplyTo,SSLConfiguration,Sender,Server,SubjectFailure,SubjectSuccess,TimeZone,UseSTARTTLS";

/// <p>The name <code>EmailGet</code> answers that no row, get or set names.</p>
Parameter SECRET = "AuthPassword";

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

/// <p>The value <code>%SYS.Task.Config.EmailGet</code> answers for <var>pName</var>, read in <code>%SYS</code>; <code>(error)</code> when it fails.</p>
ClassMethod VendorValue(pName As %String) As %String
{
    Set tValue = "(error)"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(%SYS.Task.Config).EmailGet(pName, .tGot)
        If $$$ISOK(tSC) Set tValue = $Get(tGot)
    } Catch {
        Set tValue = "(error)"
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tValue
}

/// <p>The screen's read through the shipped executor, answering its result object.</p>
ClassMethod Read(Output pHttp As %Integer, Output pFault As %DynamicObject) As %DynamicObject
{
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, "", .tResult, .pHttp, .pFault)
    If $$$ISERR(tSC) Quit ""
    Quit tResult
}

/// <p>A read's rows as an array keyed by name, each the row object, in <var>pRows</var>; the count answered.</p>
ClassMethod RowsByName(pResult As %DynamicObject, Output pRows) As %Integer
{
    Kill pRows
    Set tCount = 0
    If '$IsObject(pResult) Quit 0
    Set tIterator = pResult.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set pRows(tRow.%Get("Name")) = tRow
        Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>Hold the three pairs the port's read names, in the gate's test seam.</p>
ClassMethod HoldReadPairs()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
}

/// <p><b>AC2 (AD-35).</b> The screen answers twelve rows, one per roster name, each valued as <code>EmailGet</code> answers it and never the mail
/// password, with the kinds and limits the roster gives; the port answers the same rows, each exactly its seven members.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>TASKMAILROSTER</code> gains <code>AuthPassword|text|||1</code> -> the count, the
/// names and the no-secret assertions go red.</p>
Method TestTheReadIsTheTwelveRowsEmailGetAnswersAndNeverThePassword()
{
    Set tResult = ..Read(.tHttp, .tFault)
    Do $$$AssertTrue($IsObject(tResult), "the read answers (" _ $Get(tHttp) _ ")")
    If '$IsObject(tResult) Quit
    Set tCount = ..RowsByName(tResult, .tRows)
    Do $$$AssertEquals(tCount, 12, "one row per roster name")
    Set tNames = ""
    Set tName = ""
    For {
        Set tName = $Order(tRows(tName))
        If tName = "" Quit
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName
        Do $$$AssertEquals(tRows(tName).Value, ..VendorValue(tName), tName _ ": the row reads the value EmailGet answers")
        Do $$$AssertEquals(tRows(tName).Restart _ "|" _ tRows(tName).ReadOnly, "0|0", tName _ ": states no restart and is settable")
    }
    Do $$$AssertEquals(tNames, ..#NAMES, "the rows are the roster's names")
    Do $$$AssertEquals($Data(tRows(..#SECRET)), 0, "no row is the mail password")
    Do $$$AssertEquals(tResult.%ToJSON() [ ..#SECRET, 0, "and the answer names it nowhere")
    Do $$$AssertEquals(tResult.%Get("truncated"), 0, "nothing is truncated")
    Do ..HoldReadPairs()
    Set tSC = $ClassMethod(..#SEAM, "Rows", ..#ENDPOINT, 1000, .tPortRows, .tPortHttp, .tPortFault)
    Set tOk = $$$ISOK(tSC) && (tPortRows.%Size() = tCount)
    Set tIterator = tPortRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPortRow) {
        If ##class(OcuPilot.Test.LicenseKey).Keys(tPortRow) '= "Accepts,Kind,Name,Purges,ReadOnly,Restart,Value" Set tOk = 0
    }
    Do $$$AssertEquals(tOk, 1, "the port answers the same rows, each exactly its seven members")
}

/// <p><b>AC2.</b> The kinds and what each accepts are the roster's: the port a text of at most five characters, the STARTTLS switch 0 or 1, the two
/// messages up to 32000 characters and every other setting up to 255.</p>
/// <p>Mutation (Rule 19): <code>TASKMAILROSTER</code> declares <code>MessageSuccess</code> with a 255 limit -> its row goes red.</p>
Method TestTheKindsAndLimitsAreTheRosters()
{
    Do ..RowsByName(..Read(), .tRows)
    For tCase = $ListBuild("Port", "text", "Text of up to 5 characters."), $ListBuild("UseSTARTTLS", "boolean", "0 (off) or 1 (on)."), $ListBuild("MessageSuccess", "text", "Text of up to 32000 characters."), $ListBuild("MessageFailure", "text", "Text of up to 32000 characters."), $ListBuild("Server", "text", "Text of up to 255 characters."), $ListBuild("Sender", "text", "Text of up to 255 characters."), $ListBuild("ReplyTo", "text", "Text of up to 255 characters."), $ListBuild("TimeZone", "text", "Text of up to 255 characters."), $ListBuild("AuthUser", "text", "Text of up to 255 characters."), $ListBuild("SSLConfiguration", "text", "Text of up to 255 characters."), $ListBuild("SubjectSuccess", "text", "Text of up to 255 characters."), $ListBuild("SubjectFailure", "text", "Text of up to 255 characters.") {
        Set tRow = tRows($List(tCase, 1))
        Do $$$AssertEquals(tRow.Kind _ "|" _ tRow.Accepts, $List(tCase, 2) _ "|" _ $List(tCase, 3), $List(tCase, 1) _ ": its kind and what it accepts")
    }
}

/// <p><b>AC2, AD-35.</b> A <code>GET</code> answers the one row the list answers for the name, and a name the roster does not list, in any case,
/// the mail password among them, is 404 <code>CONFIG.SETTING.NOTFOUND</code> with no vendor call.</p>
/// <p>Mutation (Rule 19): <code>TASKMAILROSTER</code> gains the mail password -> the <code>AuthPassword</code> row goes red.</p>
Method TestAGetAnswersOneRowAndTheMailPasswordIsAbsent()
{
    Kill tQuery
    Set tQuery("name") = "Port"
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a listed setting reads")
    Do ..RowsByName(..Read(), .tRows)
    Do tRow.%Remove("Purges")
    Do $$$AssertEquals(tRow.%ToJSON(), tRows("Port").%ToJSON(), "and is the row the list answers")
    For tName = "port", "NoSuchSetting", "", "AuthPassword", "authpassword", "MailAuthPassword", "MailPort" {
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tAbsent, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "404|CONFIG.SETTING.NOTFOUND", "'" _ tName _ "' is not a Task Manager email setting")
    }
}

/// <p><b>AC2, AD-58.</b> A vendor read that fails is answered 500 <code>INTERNAL</code> and no rows, never an empty value that a write's read-back would
/// take for the stored one.</p>
/// <p>Mutation (Rule 19): <code>CollectRoster</code> ignores the read's status -> the failure assertions go red.</p>
Method TestAFailedVendorReadIsAFaultAndNotAnEmptyRow()
{
    Do ..HoldReadPairs()
    Do $ClassMethod(..#SEAM, "MailReadFails")
    Kill tQuery
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "") _ "|" _ $IsObject($Get(tRows)), "500|INTERNAL|0", "a list answers a fault and no rows")
    Set tQuery("name") = "Port"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $IsObject($Get(tRow)), "500|0", "and so does a get")
}

/// <p><b>AC2.</b> Every read is refused to a caller short of a pair, naming the first one missing, and every write to a caller without
/// <code>%DB_IRISSYS:WRITE</code>, each before any vendor call.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>WRITEPAIRS</code> loses <code>%DB_IRISSYS:WRITE</code> -> the write row goes red.</p>
Method TestEveryReadAndWriteIsRefusedToACallerShortOfItsPairs()
{
    Kill tQuery
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ tDetail _ "|" _ $IsObject(tRows), "403|AUTH.NOPRIVILEGE|%Admin_Manage:USE|0", "a caller holding nothing is refused naming the first pair and answers no rows")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ tDetail, "403|%DB_IRISSYS:READ", "a caller holding only %Admin_Manage:USE is refused %DB_IRISSYS:READ")
    Set tSC = $ClassMethod(..#SEAM, "Rows", ..#ENDPOINT, 10, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 403, "and the screens' own list call is gated by the same pairs")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a caller holding the read pairs reads")
    Set tQuery("name") = "Port"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "SET", .tQuery, {"Value": "587"}, .tOut, .tHttp, .tFault)
    Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ tDetail _ "|" _ $ClassMethod(..#SEAM, "Modifies"), "403|%DB_IRISSYS:WRITE|", "a caller holding the read pairs is refused the write naming the write pair, and nothing reached the vendor")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "SET", .tQuery, {"Value": "587"}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#SEAM, "Modifies"), "200|TaskMail|Port|587", "a caller holding the write pair sets it, once")
}

/// <p><b>AC2, AD-5, AD-44, AD-51, AD-53.</b> The screen declares the classic mail page, the Tasks area, the next free position, the config read source
/// and its pairs (the area's two and the port's <code>%Admin_Manage:USE</code>, which is its own); the tool declares its screen action, its port, its
/// endpoint and the classic page it replaces, and reads its value back.</p>
/// <p>Mutation (Rule 19): <code>TaskMailSettingList</code> declares position 5 -> the declaration assertion goes red.</p>
Method TestTheScreenAndToolDeclareTheirPagesPairsAndActions()
{
    Set tClass = ..#DESCRIPTOR
    Do $$$AssertStatusOK($ClassMethod(tClass, "DeclarationJson", .tDeclaration), "the declaration parses")
    Do $$$AssertEquals($ClassMethod(tClass, "Route") _ "|" _ $ClassMethod(tClass, "AreaKey") _ "|" _ $ClassMethod(tClass, "SideBarPosition"), "tasks/email|tasks|6", "its route, area and side-bar position")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%cspapp.mgr.utilsystaskmail", "its classic page")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), "task-mail-setting|set,password", "its entity type and its two row actions, the second also its primary action (Story 21.36)")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryActionId") _ "|" _ $ListToString($ClassMethod(tClass, "SecretArguments")), "password|AuthPassword", "the primary action is Set mail password, and the one declared secret is the mail password, a write and never a row")
    Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "config|TaskMail|LIST", "it reads through the config port")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read is the declared grammar")
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tClass, .tResolved)
    Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Admin_Task", "USE")) && $ListFind(tPairs, $ListBuild("%Admin_Manage", "USE")) && $ListFind(tPairs, $ListBuild("%DB_IRISSYS", "READ")) && '$ListFind(tPairs, $ListBuild("%DB_IRISSYS", "WRITE")), "it requires the area's two pairs and the port's own, and not the write pair")
    Do $$$AssertEquals(tDeclaration.ownPrivileges.%ToJSON(), "[{""resource"":""%Admin_Manage"",""permission"":""USE""}]", "the port's pair is its own, so the other Tasks screens stay open to a holder of the area's two")
    Set tTool = ..#TOOL
    Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint"), ..#KEY _ "|set|" _ ..#PORT _ "|" _ ..#ENDPOINT, "the tool's name, screen action, port and endpoint")
    Do $$$AssertEquals($Parameter(tTool, "CLASSICPAGES"), "%cspapp.mgr.utilsystaskmail", "the classic page it replaces")
    Do $$$AssertEquals(''$ClassMethod(tTool, "SendsBody") _ ''$ClassMethod(tTool, "Destructive") _ $ListToString($ClassMethod(tTool, "ReadBackFields")), "10Value", "a merge write that is not destructive and reads its value back")
    Do $$$AssertTrue($ListFind($ClassMethod(tTool, "PrivilegePairs"), $ListBuild("%DB_IRISSYS", "WRITE")) && $ListFind($ClassMethod(tTool, "PrivilegePairs"), $ListBuild("%Admin_Manage", "USE")), "the tool requires the write pair and %Admin_Manage:USE")
}

/// <p><b>AC6.</b> The set key ships enabled by the baseline, so with none stored the agent's call mints a proposal; with the key absent from the
/// baseline it reads disabled and the same call is refused <code>GOVERNANCE.DISABLED</code> at dispatch before anything is minted.</p>
/// <p>Mutation (Rule 19): the <code>tasks.mail.set</code> line removed from <class>OcuPilot.Kernel.Governance.Baseline</class> -> the baseline and mint
/// assertions go red.</p>
Method TestTheKeyShipsEnabledAndADisabledKeyIsRefusedAtDispatch()
{
    Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved(..#KEY), "1|baseline", ..#KEY _ " ships enabled by the baseline")
    Set tInput = {"Name": "Port", "Value": "587", "rationale": "probe", "expectedImpact": "probe"}
    Set tAnswer = ..Dispatched(..#KEY, tInput, .tContent, .tProposal)
    Do $$$AssertEquals(tAnswer, "minted", "the call mints a proposal: " _ tContent)
    Kill tSettings
    Set tSettings(..#KEY) = "disabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is stored disabled")
    Do $$$AssertEquals(..Dispatched(..#KEY, tInput, .tContent) _ "|" _ tContent, "refused|{""code"":""GOVERNANCE.DISABLED""}", "and the same call is refused by the governance gate")
}

/// <p>The agent's dispatch of <var>pKey</var> with <var>pInput</var>: <code>minted</code> or <code>refused</code>; the answer's content is in
/// <var>pContent</var> and a minted proposal in <var>pProposal</var>. A minted proposal is never confirmed.</p>
ClassMethod Dispatched(pKey As %String, pInput As %DynamicObject, Output pContent As %String, Output pProposal As %DynamicObject) As %String
{
    Set pContent = ""
    Set pProposal = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit "no turn"
    Set tUse = {"type": "tool_use", "id": "toolu_taskmail"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(pKey), "string")
    Do tUse.%Set("input", pInput)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set pContent = $Select($IsObject($Get(tResults)) && (tResults.%Size() = 1): tResults.%Get(0).%Get("content"), 1: "")
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(pContent)
    If $IsObject(tParsed) && (tParsed.%Get("proposalId") '= "") Set pProposal = tParsed
    Quit $Select($IsObject(pProposal): "minted", 1: "refused")
}

}
