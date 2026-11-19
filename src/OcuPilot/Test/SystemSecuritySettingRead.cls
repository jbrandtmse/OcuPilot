/// <p>Pins Story 21.10's System-wide security read, gate and declarations (AC1, AC6; AD-22, AD-29, AD-35, AD-36): the screen and the port read one row
/// per name of the port's roster, each valued as <code>Security.System.Get</code> answers it, and no other property of that class, which also holds key
/// material and a mail password; every read and write is refused to a caller short of a pair before any vendor call; the screen and its tool declare
/// the classic page, the pairs and the destructive set; and the set key ships disabled.</p>
/// <p><b>Live-safe:</b> it reads, changes no setting, and stores a governance policy only to restore it. <b>What it needs from the
/// environment:</b> OcuPilot installed and serving.</p>
Class OcuPilot.Test.SystemSecuritySettingRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter SEAM = "OcuPilot.Test.ConfigGateSeam";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.SystemSecuritySettingList";

Parameter TOOL = "OcuPilot.Screen.Tool.SystemSecuritySettingSet";

Parameter KEY = "security.systemsecurity.set";

/// <p>The nineteen names the classic Parameters page shows, which the roster must name and nothing else.</p>
Parameter NAMES = "AuditEnabled,AuditFlags,ConfigurationSecurityEnabled,DefaultSecurityDomain,DefaultSignatureHash,EscalateAuthTimeout,EscalateLoginTimeout,InactiveLimit,InvalidLoginAction,InvalidLoginLimit,PasswordExpirationDays,PasswordPattern,PasswordValidationRoutine,PercentGlobalWrite,RequiredRole,SQLSecurity,SSLTelnetServer,SecurityDomains,WebAppPctAccess";

/// <p>The names shown and never changed.</p>
Parameter READONLY = "AuditEnabled,ConfigurationSecurityEnabled,DefaultSecurityDomain,PasswordExpirationDays,PasswordValidationRoutine,RequiredRole,SSLTelnetServer,SecurityDomains";

/// <p>Properties of <code>Security.System</code> that no row may carry.</p>
Parameter SECRETS = "PrivateJWKS,PublicJWKS,SMTPPassword,SMTPUsername,SMTPServer,DBEncStartPassphrase,DBEncStartUsername,TwoFactorPWIssuer,Description,AutheEnabled";

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

/// <p>The names <code>Security.System.Get</code> answers and their values, in <var>pProps</var>, read in <code>%SYS</code>.</p>
ClassMethod VendorProperties(Output pProps) As %Status
{
    Kill pProps
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.System).Get("SYSTEM", .pProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
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

/// <p>Whether this instance lists the Windows-only name.</p>
ClassMethod IsWindows() As %Boolean
{
    Quit $System.Version.GetOS() = "Windows"
}

/// <p><b>AC1 (AD-35).</b> The screen answers one row per roster name, valued as <code>Get</code> answers it, 18 on a platform other than Windows and 19 on
/// Windows, and no other property of the class: not the key material, the mail password or any property the classic page does not show. The port
/// answers the same rows, each exactly its seven members.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>CollectSecurity</code> emits every key of the <code>Get</code> array in place of
/// the roster's names -> the names and no-secret assertions go red.</p>
Method TestTheReadIsTheRosterAndNoOtherProperty()
{
    Set tResult = ..Read(.tHttp, .tFault)
    Do $$$AssertTrue($IsObject(tResult), "the read answers (" _ $Get(tHttp) _ ")")
    If '$IsObject(tResult) Quit
    Do $$$AssertStatusOK(..VendorProperties(.tProps), "Get answers")
    Set tCount = ..RowsByName(tResult, .tRows)
    Do $$$AssertEquals(tCount, $Select(..IsWindows(): 19, 1: 18), "one row per roster name, less the Windows-only one elsewhere")
    Set tExpected = ""
    For tI = 1:1:$Length(..#NAMES, ",") {
        Set tName = $Piece(..#NAMES, ",", tI)
        If (tName = "SSLTelnetServer") && '..IsWindows() Continue
        Set tExpected = tExpected _ $Select(tExpected = "": "", 1: ",") _ tName
    }
    Set tNames = ""
    Set tName = ""
    For {
        Set tName = $Order(tRows(tName))
        If tName = "" Quit
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName
    }
    Do $$$AssertEquals(tNames, tExpected, "the rows are the roster's names")
    Set tOk = 1
    Set tName = ""
    For {
        Set tName = $Order(tRows(tName))
        If tName = "" Quit
        If tRows(tName).Value '= $Get(tProps(tName)) Set tOk = 0
    }
    Do $$$AssertEquals(tOk, 1, "each row reads the value Get answers")
    Set tLeaked = ""
    For tI = 1:1:$Length(..#SECRETS, ",") {
        If $Data(tRows($Piece(..#SECRETS, ",", tI))) Set tLeaked = tLeaked _ " " _ $Piece(..#SECRETS, ",", tI)
    }
    Set tName = ""
    For {
        Set tName = $Order(tProps(tName))
        If tName = "" Quit
        If '$ListFind($ListFromString(..#NAMES), tName) && $Data(tRows(tName)) Set tLeaked = tLeaked _ " " _ tName
    }
    Do $$$AssertEquals(tLeaked, "", "no property outside the roster is a row, and no secret is read")
    Do $$$AssertEquals(tResult.%Get("truncated"), 0, "nothing is truncated")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = $ClassMethod(..#SEAM, "Rows", "Security", 1000, .tPortRows, .tPortHttp, .tPortFault)
    Set tOk = $$$ISOK(tSC) && (tPortRows.%Size() = tCount)
    Set tIterator = tPortRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPortRow) {
        If ##class(OcuPilot.Test.LicenseKey).Keys(tPortRow) '= "Accepts,Kind,Name,Purges,ReadOnly,Restart,Value" Set tOk = 0
    }
    Do $$$AssertEquals(tOk, 1, "the port answers the same rows, each exactly its seven members")
}

/// <p><b>AC1.</b> The kinds, limits and read-only flags are the roster's: the seven names shown and never changed, the page's maxima on the three
/// integer limits and 0 or 1 on the flags, the signature hash's four choices and the text lengths.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>SECURITYROSTER</code> marks <code>RequiredRole</code> settable -> the
/// read-only assertion goes red, and so does <class>OcuPilot.Test.SystemSecuritySettingWrite</class>'s refusal of it.</p>
Method TestTheKindsLimitsAndReadOnlyFlagsAreTheRosters()
{
    Do ..RowsByName(..Read(), .tRows)
    Set tReadOnly = ""
    Set tName = ""
    For {
        Set tName = $Order(tRows(tName))
        If tName = "" Quit
        If tRows(tName).ReadOnly Set tReadOnly = tReadOnly _ $Select(tReadOnly = "": "", 1: ",") _ tName
        Do $$$AssertEquals(tRows(tName).ReadOnly = 1, ''$ListFind($ListFromString(..#READONLY), tName), tName _ ": read-only exactly when the roster says so")
        Do $$$AssertEquals(tRows(tName).Restart, 0, tName _ ": states no restart")
    }
    Do $$$AssertEquals(tReadOnly, $Select(..IsWindows(): ..#READONLY, 1: "AuditEnabled,ConfigurationSecurityEnabled,DefaultSecurityDomain,PasswordExpirationDays,PasswordValidationRoutine,RequiredRole,SecurityDomains"), "the shown-and-never-changed names")
    For tCase = $ListBuild("InactiveLimit", "integer", "A whole number from 0 to 365."), $ListBuild("InvalidLoginLimit", "integer", "A whole number from 0 to 64."),$ListBuild("EscalateLoginTimeout", "integer", "A whole number of at least 0."), $ListBuild("EscalateAuthTimeout", "integer", "A whole number of at least 0."), $ListBuild("AuditFlags", "boolean", "0 (off) or 1 (on)."), $ListBuild("InvalidLoginAction", "boolean", "0 (off) or 1 (on)."), $ListBuild("PercentGlobalWrite", "boolean", "0 (off) or 1 (on)."), $ListBuild("SQLSecurity", "boolean", "0 (off) or 1 (on)."), $ListBuild("WebAppPctAccess", "boolean", "0 (off) or 1 (on)."), $ListBuild("DefaultSignatureHash", "choice", "One of SHA1, SHA256, SHA384, SHA512."), $ListBuild("PasswordPattern", "text", "Text of up to 64 characters.") {
        Set tRow = tRows($List(tCase, 1))
        Do $$$AssertEquals(tRow.Kind _ "|" _ tRow.Accepts, $List(tCase, 2) _ "|" _ $List(tCase, 3), $List(tCase, 1) _ ": its kind and what it accepts")
    }
}

/// <p><b>AC1.</b> A <code>GET</code> answers the one row the list answers for the name, and a name the roster does not list, in any case, or a vendor
/// property outside it, is 404 <code>CONFIG.SETTING.NOTFOUND</code>.</p>
Method TestAGetAnswersOneRowAndAnUnlistedNameIsAbsent()
{
    Kill tQuery
    Set tQuery("name") = "InactiveLimit"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Security", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a listed parameter reads")
    Do ..RowsByName(..Read(), .tRows)
    Do tRow.%Remove("Purges")
    Do $$$AssertEquals(tRow.%ToJSON(), tRows("InactiveLimit").%ToJSON(), "and is the row the list answers")
    For tName = "inactivelimit", "NoSuchSetting", "", "PrivateJWKS", "SMTPPassword", "PublicJWKS", "Description" {
        Set tQuery("name") = tName
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Security", "GET", .tQuery, "", .tAbsent, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "404|CONFIG.SETTING.NOTFOUND", "'" _ tName _ "' is not a system-wide security parameter")
    }
}

/// <p><b>AC1.</b> Every read is refused to a caller short of a pair, naming the first one missing, and the Security endpoint asks for
/// <code>%Admin_Secure:USE</code> beside the others; every write is refused to a caller without <code>%DB_IRISSYS:WRITE</code> and then one without
/// <code>%Admin_Secure:USE</code>, each before any vendor call.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>Admit</code> drops <code>SECURITYPAIRS</code> for the <code>Security</code>
/// endpoint -> the <code>%Admin_Secure:USE</code> rows go red.</p>
Method TestEveryReadAndWriteIsRefusedToACallerShortOfItsPairs()
{
    Kill tQuery
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Security", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ tDetail _ "|" _ $IsObject(tRows), "403|AUTH.NOPRIVILEGE|%Admin_Manage:USE|0", "a caller holding nothing is refused naming the first pair and answers no rows")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Security", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ tDetail _ "|" _ $IsObject(tRows), "403|%Admin_Secure:USE|0", "a caller holding the other read pairs is refused %Admin_Secure:USE")
    Set tSC = $ClassMethod(..#SEAM, "Rows", "Security", 10, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 403, "and the screens' own list call is gated by the same pairs")
    Kill tQuery
    Set tQuery("name") = "InactiveLimit"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Security", "SET", .tQuery, {"Value": "89"}, .tOut, .tHttp, .tFault)
    Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ tDetail, "403|%DB_IRISSYS:WRITE", "a caller holding the read pairs is refused the write naming the write pair")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Security", "SET", .tQuery, {"Value": "89"}, .tOut, .tHttp, .tFault)
    Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ tDetail, "403|%Admin_Secure:USE", "a caller holding the write pair but not %Admin_Secure:USE is refused the write")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Modifies") _ $ClassMethod(..#SEAM, "Entries"), "", "and nothing reached the vendor")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Security", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a caller holding every pair reads")
}

/// <p><b>AC1.</b> A write sends the settable roster names and no other property: the one named key at its new value and every other settable name as
/// read, and none of the seven shown names, the key material or the mail password. The seam records the call and sends nothing.</p>
/// <p>Mutation (Rule 19): <code>ModifySecurity</code> sends the whole <code>Get</code> array -> the sent-keys assertion goes red.</p>
Method TestAWriteSendsTheSettableNamesAndNothingElse()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
    Kill tQuery
    Set tQuery("name") = "InactiveLimit"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Security", "SET", .tQuery, {"Value": "89"}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tOut): tOut.%Get("Value"), 1: ""), "200|89", "a set of a settable parameter is accepted")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Entries"), "MODIFY|Security.System|SYSTEM|", "through one vendor Modify of the one record")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "SentEntryKeys"), "AuditFlags,DefaultSignatureHash,EscalateAuthTimeout,EscalateLoginTimeout,InactiveLimit,InvalidLoginAction,InvalidLoginLimit,PasswordPattern,PercentGlobalWrite,SQLSecurity,WebAppPctAccess", "which carries the eleven settable names and no other property")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
    For tCase = $ListBuild("RequiredRole", "CSPSystem", 409), $ListBuild("PasswordValidationRoutine", "x", 409), $ListBuild("AuditEnabled", "0", 409), $ListBuild("InactiveLimit", "366", 400), $ListBuild("InvalidLoginLimit", "65", 400), $ListBuild("PasswordExpirationDays", "1", 409), $ListBuild("AuditFlags", "2", 400), $ListBuild("DefaultSignatureHash", "MD5", 400), $ListBuild("PasswordPattern", $Justify("", 65), 400), $ListBuild("InactiveLimit", "-1", 400), $ListBuild("InactiveLimit", "x", 400), $ListBuild("PrivateJWKS", "x", 404) {
        Kill tQuery
        Set tQuery("name") = $List(tCase, 1)
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "Security", "SET", .tQuery, {"Value": ($List(tCase, 2))}, .tOut, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, $List(tCase, 3), $List(tCase, 1) _ " '" _ $Extract($List(tCase, 2), 1, 12) _ "' is refused at the port")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Entries"), "", "and nothing reached the vendor")
}

/// <p><b>AC1, AC6, AD-5, AD-44, AD-51, AD-53.</b> The screen declares the classic Parameters page, the Security area, the next free position, the
/// config read source and its pairs; the tool declares its screen action, its port, its endpoint and the classic page it replaces, and is
/// destructive and reads its value back.</p>
/// <p>Mutation (Rule 19): <code>SystemSecuritySettingSet</code> declares <code>DESTRUCTIVE</code> 0 -> the declaration assertion goes red.</p>
Method TestTheScreenAndToolDeclareTheirPagesPairsAndActions()
{
    Set tClass = ..#DESCRIPTOR
    Do $$$AssertStatusOK($ClassMethod(tClass, "DeclarationJson", .tDeclaration), "the declaration parses")
    Do $$$AssertEquals($ClassMethod(tClass, "Route") _ "|" _ $ClassMethod(tClass, "AreaKey") _ "|" _ $ClassMethod(tClass, "SideBarPosition"), "security/system-security|security|14", "its route, area and side-bar position")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.Parameters", "its classic page")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage($ZConvert("%CSP.UI.Portal.Parameters", "O", "URL")), "%CSP.UI.Portal.Parameters", "which the portal's own resolver recognises (AD-44)")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), "system-security-setting|set", "its entity type and its one action")
    Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "config|Security|LIST", "it reads through the config port")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read is the declared grammar")
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tClass, .tResolved)
    Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Admin_Manage", "USE")) && $ListFind(tPairs, $ListBuild("%Admin_Secure", "USE")) && $ListFind(tPairs, $ListBuild("%DB_IRISSYS", "READ")) && '$ListFind(tPairs, $ListBuild("%DB_IRISSYS", "WRITE")), "it requires the three read pairs and not the write pair")
    Set tTool = ..#TOOL
    Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint"), ..#KEY _ "|set|" _ ..#PORT _ "|Security", "the tool's name, screen action, port and endpoint")
    Do $$$AssertEquals($Parameter(tTool, "CLASSICPAGES"), "%CSP.UI.Portal.Parameters", "the classic page it replaces")
    Do $$$AssertEquals(''$ClassMethod(tTool, "SendsBody") _ ''$ClassMethod(tTool, "Destructive") _ $ListToString($ClassMethod(tTool, "ReadBackFields")), "11Value", "a merge write that is destructive and reads its value back")
    Do $$$AssertEquals($ClassMethod(tTool, "Consequence", {"Name": "InactiveLimit"}), "SECURITY.SYSTEM.SET", "its card states the consequence code the client publishes")
    Do $$$AssertTrue($ListFind($ClassMethod(tTool, "PrivilegePairs"), $ListBuild("%DB_IRISSYS", "WRITE")) && $ListFind($ClassMethod(tTool, "PrivilegePairs"), $ListBuild("%Admin_Secure", "USE")), "the tool requires the write pair and %Admin_Secure:USE")
}

/// <p><b>AC6.</b> The set key ships disabled by the baseline, so with none stored the agent's call is refused <code>GOVERNANCE.DISABLED</code> at
/// dispatch before anything is minted; stored enabled it mints a proposal that carries the destructive treatment and the consequence code.</p>
/// <p>Mutation (Rule 19): <code>security.systemsecurity.set</code> set <code>true</code> in <class>OcuPilot.Kernel.Governance.Baseline</class> -> the
/// baseline assertion and the refusal go red.</p>
Method TestTheKeyShipsDisabledAndAnEnabledKeyMintsADestructiveProposal()
{
    Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved(..#KEY), "0|baseline", ..#KEY _ " ships disabled by the baseline")
    Set tInput = {"Name": "InactiveLimit", "Value": "89", "rationale": "probe", "expectedImpact": "probe"}
    Do $$$AssertEquals(..Dispatched(..#KEY, tInput, .tContent) _ "|" _ tContent, "refused|{""code"":""GOVERNANCE.DISABLED""}", "the agent's call is refused by the governance gate")
    Kill tSettings
    Set tSettings(..#KEY) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is stored enabled")
    Set tAnswer = ..Dispatched(..#KEY, tInput, .tContent, .tProposal)
    Do $$$AssertEquals(tAnswer, "minted", "the same call mints a proposal: " _ tContent)
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals($Get(tValues("consequence")) _ "|" _ +$Get(tValues("destructive")), "SECURITY.SYSTEM.SET|1", "its card is destructive and carries the consequence code")
}

/// <p>The agent's dispatch of <var>pKey</var> with <var>pInput</var>: <code>minted</code> or <code>refused</code>; the answer's content is in
/// <var>pContent</var> and a minted proposal in <var>pProposal</var>. A minted proposal is never confirmed.</p>
ClassMethod Dispatched(pKey As %String, pInput As %DynamicObject, Output pContent As %String, Output pProposal As %DynamicObject) As %String
{
    Set pContent = ""
    Set pProposal = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit "no turn"
    Set tUse = {"type": "tool_use", "id": "toolu_security"}
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
