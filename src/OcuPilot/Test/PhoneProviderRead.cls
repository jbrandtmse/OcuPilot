/// <p>Pins Story 21.10's Mobile phone providers read, gate and declarations (AC2, AC6; AD-8, AD-29, AD-36, AD-44): the screen and the port list the
/// providers exactly as <code>%SYS.PhoneProviders:List</code> answers them; a provider is found by its exact name; every read and write is refused to a
/// caller short of a pair before any vendor call; the screens and tools declare the classic pages, the pairs and the destructive set; and the delete
/// key ships disabled while the create and update keys mint.</p>
/// <p><b>Live-safe:</b> it reads, changes no provider, and stores a governance policy only to restore it. <b>What it needs from the environment:</b>
/// OcuPilot installed and serving.</p>
Class OcuPilot.Test.PhoneProviderRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.PhoneProviderPort";

Parameter SEAM = "OcuPilot.Test.PhoneGateSeam";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter LIST = "OcuPilot.Screen.Descriptor.PhoneProviderList";

Parameter FORM = "OcuPilot.Screen.Descriptor.PhoneProviderForm";

Parameter CREATE = "OcuPilot.Screen.Tool.PhoneProviderCreate";

Parameter UPDATE = "OcuPilot.Screen.Tool.PhoneProviderUpdate";

Parameter DELETE = "OcuPilot.Screen.Tool.PhoneProviderDelete";

/// <p>The governance policy as it stood before each test.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>The providers <code>%SYS.PhoneProviders:List</code> answers, in <var>pProviders</var> keyed by name with the SMS gateway as the value, and their
/// count answered; <code>-1</code> when the query cannot be run. Read in <code>%SYS</code>.</p>
ClassMethod VendorProviders(Output pProviders) As %Integer
{
    Kill pProviders
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("%SYS.PhoneProviders:List")
        Set tSC = tRS.Execute()
        If $$$ISERR(tSC) {
            Set tCount = -1
            Quit
        }
        While tRS.Next() {
            Set pProviders(tRS.GetData(1)) = tRS.GetData(2)
            Set tCount = tCount + 1
        }
    } Catch {
        Set tCount = -1
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p>The Security area's screen verdicts <var>pJson</var> as a principal's navigation map answers them, with the two Mobile phone providers screens
/// added: the list as Security's last listed screen and its editor among the unlisted ones, each carrying the verdict the Managed file transfer
/// connections screens carry in the same answer, because the three declare the same two pairs (AD-8). The editor goes in the position the map sorts
/// it to, by descriptor class name, before the SSL/TLS editor; the list goes last. A map that holds no connections entry is answered as it is.</p>
ClassMethod WithScreens(pJson As %String) As %String
{
    Set tListMark = "{""route"":""security/mft-connections"",""labelKey"":""mftConnectionListLabel"",""sideBarPosition"":13,"
    Set tFormMark = "{""route"":""security/mft-connections/edit"",""labelKey"":""aboutMftConnection"",""sideBarPosition"":0,"
    Set tSslMark = "{""route"":""security/ssl/edit"""
    If (pJson '[ tListMark) || (pJson '[ tFormMark) || (pJson '[ tSslMark) Quit pJson
    Set tListVerdict = $Piece($Piece(pJson, tListMark, 2), "}", 1)
    Set tFormVerdict = $Piece($Piece(pJson, tFormMark, 2), "}", 1)
    Set tForm = "{""route"":""security/phone-providers/edit"",""labelKey"":""aboutPhoneProvider"",""sideBarPosition"":0," _ tFormVerdict _ "},"
    Set tList = ",{""route"":""security/phone-providers"",""labelKey"":""phoneProviderListLabel"",""sideBarPosition"":15," _ tListVerdict _ "}"
    Set tWith = $Piece(pJson, tSslMark, 1) _ tForm _ tSslMark _ $Piece(pJson, tSslMark, 2, *)
    Quit $Extract(tWith, 1, *-1) _ tList _ "]"
}

/// <p>The Security area's screen verdicts <var>pJson</var> without the two Mobile phone providers screens, for a test whose subject is another
/// screen set and whose expectation lists none of them.</p>
ClassMethod WithoutScreens(pJson As %String) As %String
{
    For tRoute = "security/phone-providers/edit", "security/phone-providers" {
        Set tMark = "{""route"":""" _ tRoute _ """,""labelKey"""
        Set tAfterMark = $Find(pJson, tMark)
        If 'tAfterMark Continue
        Set tStart = tAfterMark - $Length(tMark)
        Set tEnd = $Find(pJson, "}", tAfterMark)
        If $Extract(pJson, tEnd) = "," {
            Set tEnd = tEnd + 1
        } ElseIf (tStart > 1) && ($Extract(pJson, tStart - 1) = ",") {
            Set tStart = tStart - 1
        }
        Set pJson = $Extract(pJson, 1, tStart - 1) _ $Extract(pJson, tEnd, *)
    }
    Quit pJson
}

/// <p>The screen's read through the shipped executor, answering its result object.</p>
ClassMethod Read(Output pHttp As %Integer, Output pFault As %DynamicObject) As %DynamicObject
{
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, "", .tResult, .pHttp, .pFault)
    If $$$ISERR(tSC) Quit ""
    Quit tResult
}

/// <p><b>AC2.</b> The screen answers one row per provider, each <code>{Name, SMSGateway}</code> as the vendor's list answers it, in the vendor's order, and
/// the port answers the same rows with exactly those two members.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.PhoneProviderPort</class>'s <code>Listing</code> reads the gateway from the wrong column -> the value
/// assertions go red.</p>
Method TestTheReadIsTheVendorsList()
{
    Set tCount = ..VendorProviders(.tProviders)
    Do $$$AssertTrue(tCount > 0, "the instance holds providers to read: " _ tCount)
    Set tResult = ..Read(.tHttp, .tFault)
    Do $$$AssertTrue($IsObject(tResult), "the read answers (" _ $Get(tHttp) _ ")")
    If '$IsObject(tResult) Quit
    Set tRows = tResult.%Get("rows")
    Do $$$AssertEquals(tRows.%Size(), tCount, "one row per provider")
    Set tOk = 1
    Set tNames = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.%Get("Name")
        If tRow.%Get("SMSGateway") '= $Get(tProviders(tRow.%Get("Name"))) Set tOk = 0
        If '$Data(tProviders(tRow.%Get("Name"))) Set tOk = 0
    }
    Do $$$AssertEquals(tOk, 1, "each row is a provider the vendor lists, with the gateway it lists")
    Set tVendorNames = ""
    Set tName = ""
    For {
        Set tName = $Order(tProviders(tName))
        If tName = "" Quit
        Set tVendorNames = tVendorNames _ $Select(tVendorNames = "": "", 1: ",") _ tName
    }
    Do $$$AssertEquals($ZConvert(tNames, "U"), $ZConvert(tVendorNames, "U"), "in the vendor's order")
    Do $$$AssertEquals(tResult.%Get("truncated"), 0, "nothing is truncated")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = $ClassMethod(..#SEAM, "Rows", "PhoneProviders", 1000, .tPortRows, .tPortHttp, .tPortFault)
    Set tOk = $$$ISOK(tSC) && (tPortRows.%Size() = tCount)
    Set tIterator = tPortRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPortRow) {
        If ##class(OcuPilot.Test.LicenseKey).Keys(tPortRow) '= "Name,SMSGateway" Set tOk = 0
    }
    Do $$$AssertEquals(tOk, 1, "the port answers the same rows, each exactly its two members")
}

/// <p><b>AC2.</b> A <code>GET</code> answers the one provider found by its exact name; a name in another case, an absent name and an empty name are 404
/// <code>PHONEPROVIDER.NOTFOUND</code>, as is a name that is not on the list.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.PhoneProviderPort</class>'s <code>Lookup</code> opens the provider by the folded name -> the
/// other-case row goes red.</p>
Method TestAGetFindsOneProviderByItsExactName()
{
    Set tCount = ..VendorProviders(.tProviders)
    Set tName = $Order(tProviders(""))
    Do $$$AssertTrue(tName '= "", "the instance holds a provider to get")
    Kill tQuery
    Set tQuery("name") = tName
    Set tSC = $ClassMethod(..#PORT, "Invoke", "PhoneProviders", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tRow.%Get("Name") _ "|" _ tRow.%Get("SMSGateway"), "200|" _ tName _ "|" _ tProviders(tName), "a listed provider reads, with the gateway the list shows")
    Set tOther = $Select(tName = $ZConvert(tName, "L"): $ZConvert(tName, "U"), 1: $ZConvert(tName, "L"))
    For tProbe = tOther, "NoSuchPhoneProvider", "" {
        Set tQuery("name") = tProbe
        Set tSC = $ClassMethod(..#PORT, "Invoke", "PhoneProviders", "GET", .tQuery, "", .tAbsent, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "404|PHONEPROVIDER.NOTFOUND", "'" _ tProbe _ "' names no provider")
    }
}

/// <p><b>AC2.</b> Every read is refused to a caller short of a pair, naming the first one missing, and every write is refused to a caller short of a
/// pair, each before any vendor call: no provider is created, changed or deleted.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.PhoneProviderPort</class>'s <code>Admit</code> returns success before it evaluates the pairs -> the
/// refusal rows go red.</p>
Method TestEveryReadAndWriteIsRefusedToACallerShortOfItsPairs()
{
    Set tCount = ..VendorProviders(.tProviders)
    Kill tQuery
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "PhoneProviders", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ tDetail _ "|" _ $IsObject(tRows), "403|AUTH.NOPRIVILEGE|%Admin_Secure:USE|0", "a caller holding nothing is refused naming the first pair and answers no rows")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Set tSC = $ClassMethod(..#SEAM, "Rows", "PhoneProviders", 10, .tRows, .tHttp, .tFault)
    Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ tDetail, "403|%DB_IRISSYS:READ", "a caller holding %Admin_Secure:USE alone is refused %DB_IRISSYS:READ, on the screens' own list call too")
    Kill tQuery
    Set tQuery("name") = "OcuPhoneProbe"
    For tType = "CREATE", "SET", "DELETE" {
        Set tBody = $Select(tType = "DELETE": "", 1: {"SMSGateway": "probe.example.com"})
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "PhoneProviders", tType, .tQuery, tBody, .tOut, .tHttp, .tFault)
        Set tDetail = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
        Do $$$AssertEquals(tHttp _ "|" _ tDetail, "403|%DB_IRISSYS:READ", tType _ " by a caller short of a pair is refused naming it")
    }
    Do $$$AssertEquals(..VendorProviders(.tAfter), tCount, "and nothing reached the vendor")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Kill tQuery
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "PhoneProviders", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a caller holding both pairs reads")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "NoSuchEndpoint", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code"), "501|PORT.NOTIMPLEMENTED", "another endpoint is not implemented")
}

/// <p><b>AC2, AD-5, AD-44, AD-51, AD-53.</b> The list declares the classic providers page, the Security area, the next free position, the phone read
/// source and the pairs; the form declares the classic provider page; each tool declares its port, endpoint, request types, classic page and kind, and
/// the delete is destructive with its consequence code.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.PhoneProviderDelete</class> declares <code>DESTRUCTIVE</code> 0 -> the delete assertion goes red.</p>
Method TestTheScreensAndToolsDeclareTheirPagesPairsAndActions()
{
    Set tClass = ..#LIST
    Do $$$AssertStatusOK($ClassMethod(tClass, "DeclarationJson", .tDeclaration), "the list's declaration parses")
    Do $$$AssertEquals($ClassMethod(tClass, "Route") _ "|" _ $ClassMethod(tClass, "AreaKey") _ "|" _ $ClassMethod(tClass, "SideBarPosition"), "security/phone-providers|security|15", "its route, area and side-bar position")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.PhoneProviders", "its classic page")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage($ZConvert("%CSP.UI.Portal.PhoneProviders", "O", "URL")), "%CSP.UI.Portal.PhoneProviders", "which the portal's own resolver recognises (AD-44)")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ListToString($ClassMethod(tClass, "RowActionIds")), "phone-provider|delete", "its entity type and its one row action")
    Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type, "phone|PhoneProviders|LIST", "it reads through the phone port")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read is the declared grammar")
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tClass, .tResolved)
    Do $$$AssertEquals($ListLength(tPairs) _ "|" _ ''$ListFind(tPairs, $ListBuild("%Admin_Secure", "USE")) _ ''$ListFind(tPairs, $ListBuild("%DB_IRISSYS", "READ")), "2|11", "it requires the two pairs the vendor needs")
    Set tForm = ..#FORM
    Do $$$AssertEquals($ClassMethod(tForm, "Route") _ "|" _ $ClassMethod(tForm, "SideBarPosition") _ "|" _ $ClassMethod(tForm, "ClassicPage") _ "|" _ $ClassMethod(tForm, "Archetype"), "security/phone-providers/edit|0|%CSP.UI.Portal.PhoneProvider|form-page", "the form's route, no side-bar entry, classic page and archetype")
    For tTool = ..#CREATE, ..#UPDATE, ..#DELETE {
        Do $$$AssertEquals($ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $ClassMethod(tTool, "IdParam"), ..#PORT _ "|PhoneProviders|name", tTool _ ": its port, endpoint and id parameter")
    }
    Do $$$AssertEquals($Parameter(..#CREATE, "TOOLNAME") _ "|" _ $Parameter(..#CREATE, "WRITETYPE") _ "|" _ $ClassMethod(..#CREATE, "Creates") _ "|" _ $Parameter(..#CREATE, "CLASSICPAGES"), "security.phoneproviders.create|CREATE|1|%CSP.UI.Portal.PhoneProvider", "the create's name, request type, kind and replaced page")
    Do $$$AssertEquals($Parameter(..#UPDATE, "TOOLNAME") _ "|" _ $Parameter(..#UPDATE, "WRITETYPE") _ "|" _ $ClassMethod(..#UPDATE, "SendsBody") _ "|" _ $Parameter(..#UPDATE, "CLASSICPAGES"), "security.phoneproviders.update|SET|1|%CSP.UI.Portal.PhoneProvider", "the update's name, request type, merge body and replaced page")
    Do $$$AssertEquals($ListToString($ClassMethod(..#CREATE, "SettableFields")) _ "|" _ $ListToString($ClassMethod(..#UPDATE, "SettableFields")) _ "|" _ $ListToString($ClassMethod(..#DELETE, "SettableFields")), "SMSGateway|SMSGateway|", "the create and the update admit the SMS gateway and the delete admits none")
    Do $$$AssertEquals($Parameter(..#DELETE, "TOOLNAME") _ "|" _ $Parameter(..#DELETE, "WRITETYPE") _ "|" _ ''$ClassMethod(..#DELETE, "SendsBody") _ "|" _ ''$ClassMethod(..#DELETE, "Destructive") _ "|" _ $ListToString($ClassMethod(..#DELETE, "ScreenActionIds")), "security.phoneproviders.delete|DELETE|0|1|delete", "the delete is action-style, destructive and the list's row action")
    Do $$$AssertEquals($ClassMethod(..#DELETE, "Consequence", {}), "PHONEPROVIDER.DELETE", "its card states the consequence code the client publishes")
}

/// <p><b>AC6.</b> The create and update keys ship enabled and the delete key ships disabled by the baseline, so with none stored the agent's call of the
/// delete is refused <code>GOVERNANCE.DISABLED</code> at dispatch before anything is minted; stored enabled it mints a destructive proposal carrying the
/// consequence code.</p>
/// <p>Mutation (Rule 19): <code>security.phoneproviders.delete</code> set <code>true</code> in <class>OcuPilot.Kernel.Governance.Baseline</class> -> the
/// baseline assertion and the refusal go red.</p>
Method TestTheDeleteKeyShipsDisabledAndAnEnabledKeyMintsADestructiveProposal()
{
    Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved("security.phoneproviders.create"), "1|baseline", "the create key ships enabled")
    Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved("security.phoneproviders.update"), "1|baseline", "the update key ships enabled")
    Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved("security.phoneproviders.delete"), "0|baseline", "the delete key ships disabled")
    Set tCount = ..VendorProviders(.tProviders)
    Set tName = $Order(tProviders(""))
    Set tInput = {"Name": (tName), "rationale": "probe", "expectedImpact": "probe"}
    Do $$$AssertEquals(..Dispatched("security.phoneproviders.delete", tInput, .tContent) _ "|" _ tContent, "refused|{""code"":""GOVERNANCE.DISABLED""}", "the agent's call is refused by the governance gate")
    Kill tSettings
    Set tSettings("security.phoneproviders.delete") = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is stored enabled")
    Set tAnswer = ..Dispatched("security.phoneproviders.delete", tInput, .tContent, .tProposal)
    Do $$$AssertEquals(tAnswer, "minted", "the same call mints a proposal: " _ tContent)
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals($Get(tValues("consequence")) _ "|" _ +$Get(tValues("destructive")), "PHONEPROVIDER.DELETE|1", "its card is destructive and carries the consequence code")
    Do $$$AssertEquals(..VendorProviders(.tAfter), tCount, "and the minted proposal changed no provider")
}

/// <p>The agent's dispatch of <var>pKey</var> with <var>pInput</var>: <code>minted</code> or <code>refused</code>; the answer's content is in
/// <var>pContent</var> and a minted proposal in <var>pProposal</var>. A minted proposal is never confirmed.</p>
ClassMethod Dispatched(pKey As %String, pInput As %DynamicObject, Output pContent As %String, Output pProposal As %DynamicObject) As %String
{
    Set pContent = ""
    Set pProposal = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit "no turn"
    Set tUse = {"type": "tool_use", "id": "toolu_phone"}
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
