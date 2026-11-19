/// <p>Pins Story 21.10's mobile phone provider writes on both callers (AC2, AC6; AD-4, AD-6, AD-15, AD-22, AD-53, AD-54, AD-55, AD-58) against the real
/// instance: a provider created, changed and deleted by the screen (the Save route, and the list's own delete action route
/// <class>OcuPilot.Test.EcpActionFixture</class>) and by the agent's mint and confirm (<class>OcuPilot.Test.LicenseProbe</class>); a refused write that
/// changes nothing; a provider that users name, refused <code>PHONEPROVIDER.INUSE</code> by both callers and by the port before any vendor call; and the
/// agent's confirm that writes once with one audit marker, a delete refused by governance until its key is enabled.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because
/// the class creates, changes and deletes mobile phone providers and a probe user and sets the governance policy. Every provider and user it makes is
/// named by <method>Marker</method> and removed on every path, and the list is read before and after each test.</p>
Class OcuPilot.Test.PhoneProviderWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PORT = "OcuPilot.Port.PhoneProviderPort";

Parameter SEAM = "OcuPilot.Test.PhoneGateSeam";

Parameter READ = "OcuPilot.Test.PhoneProviderRead";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter SAVE = "OcuPilot.Area.Security.PhoneProviderSave";

Parameter SCREEN = "security.phoneproviders";

Parameter LISTSCREEN = "OcuPilot.Screen.Descriptor.PhoneProviderList";

Parameter CREATE = "OcuPilot.Screen.Tool.PhoneProviderCreate";

Parameter UPDATE = "OcuPilot.Screen.Tool.PhoneProviderUpdate";

Parameter DELETE = "OcuPilot.Screen.Tool.PhoneProviderDelete";

Parameter FIRSTGATEWAY = "first.gateway.example.com";

Parameter SECONDGATEWAY = "second.gateway.example.com";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>Whether <method>OnBeforeAllTests</method> took the policy snapshot; every teardown restores only then.</p>
Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

/// <p>The providers as the test found them, as <code>{name: gateway}</code> JSON.</p>
Property PreparedProviders As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PhoneProviderWrite creates, changes and deletes this instance's mobile phone providers and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    ; The confirm fixture's port is the shipped phone provider port, so the confirm reads and writes the instance.
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Do ..RemoveMarked()
    Set tProviders = ..Providers()
    If tProviders.%ToJSON() = "{}" Quit $$$ERROR($$$GeneralError, "could not read the providers, so no test changes one it could not put back")
    Set ..PreparedProviders = tProviders.%ToJSON()
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#SEAM, "Reset")
    Do ..RemoveMarked()
    Do $$$AssertEquals(..Providers().%ToJSON(), ..PreparedProviders, "every provider and user the test made is removed, and the list reads as before the test")
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Do ..RemoveMarked()
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>The providers as <code>{name: gateway}</code>, read through the vendor's own <code>List</code> query in <code>%SYS</code>; <code>{}</code> when it
/// cannot be read.</p>
ClassMethod Providers() As %DynamicObject
{
    Set tAll = {}
    If $ClassMethod(..#READ, "VendorProviders", .tProviders) < 0 Quit tAll
    Set tName = ""
    For {
        Set tName = $Order(tProviders(tName))
        If tName = "" Quit
        Do tAll.%Set(tName, tProviders(tName), "string")
    }
    Quit tAll
}

/// <p>A marker name for this job: <code>ZZOcuPhone</code>, the job number and <var>pSuffix</var>.</p>
ClassMethod Marker(pSuffix As %String = "") As %String
{
    Quit "ZZOcuPhone" _ $Job _ pSuffix
}

/// <p>The probe user the in-use legs make, named for this job.</p>
ClassMethod ProbeUser() As %String
{
    Quit "ZZOcuPhoneU" _ $Job
}

/// <p>Delete every provider this job's marker names and the probe user, in <code>%SYS</code> through the vendor's own calls, the user first, so a provider
/// a user named can go. Failures are not raised: the assertions after it read the result.</p>
ClassMethod RemoveMarked()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..ProbeUser()) Do ##class(Security.Users).Delete(..ProbeUser())
        Set tRS = ##class(%ResultSet).%New("%SYS.PhoneProviders:List")
        Do tRS.Execute()
        Kill tMarked
        While tRS.Next() {
            If $Extract(tRS.GetData(1), 1, 10) = "ZZOcuPhone" Set tMarked(tRS.GetData(1)) = ""
        }
        Set tName = ""
        For {
            Set tName = $Order(tMarked(tName))
            If tName = "" Quit
            Do ##class(%SYS.PhoneProviders).Delete(tName)
        }
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
}

/// <p>The gateway of <var>pName</var> through the port, or <code>(404)</code> style text when it reads absent.</p>
ClassMethod GatewayOf(pName As %String) As %String
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", "PhoneProviders", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tRow)): tRow.%Get("SMSGateway"), 1: "(" _ $Get(tHttp) _ ")")
}

/// <p>The list as it reads now, without <var>pName</var>, as JSON, so what a write did not touch can be compared.</p>
ClassMethod Without(pName As %String) As %String
{
    Set tCopy = ..Providers()
    If tCopy.%GetTypeOf(pName) '= "unassigned" Do tCopy.%Remove(pName)
    Quit tCopy.%ToJSON()
}

/// <p>Make a user that names <var>pProvider</var> for two-factor text messages, in <code>%SYS</code>; answers the status. The user holds no role.</p>
ClassMethod MakeUser(pProvider As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).Create(..ProbeUser(), "", "OcuPhone!Probe" _ $Job _ "aA","OcuPilot phone provider test user (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.PhoneProviderWrite; deleted on every path", , , pProvider)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Set the probe user's provider to <var>pProvider</var>, in <code>%SYS</code>.</p>
ClassMethod SetUserProvider(pProvider As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProps("PhoneProvider") = pProvider
        Set tSC = ##class(Security.Users).Modify(..ProbeUser(), .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The Save route's create of the provider <var>pName</var> with the gateway <var>pGateway</var>, as the form's Save sends it; answers the read-back
/// verdict, or <code>http code</code> of the refusal, with the violations as <code>field:code</code> in <var>pViolations</var>.</p>
ClassMethod SaveCreate(pName As %String, pGateway As %String, Output pViolations As %String) As %String
{
    Set tSC = $ClassMethod(..#SAVE, "Create", pName, $ListBuild(pName), {"SMSGateway": (pGateway)}, .tHttp, .tFault, .tViolations, .tReadBack)
    Quit ..SaveVerdict(tSC, .tHttp, .tFault, .tViolations, .tReadBack, .pViolations)
}

/// <p>The Save route's edit of the provider <var>pName</var> to the gateway <var>pGateway</var>; answers as <method>SaveCreate</method>.</p>
ClassMethod SaveUpdate(pName As %String, pGateway As %String, Output pViolations As %String) As %String
{
    Set tSC = $ClassMethod(..#SAVE, "Update", pName, {"SMSGateway": (pGateway)}, .tHttp, .tFault, .tViolations, .tReadBack, .tConsequence)
    Quit ..SaveVerdict(tSC, .tHttp, .tFault, .tViolations, .tReadBack, .pViolations)
}

/// <p>What a Save answered, as <method>SaveCreate</method> describes it.</p>
ClassMethod SaveVerdict(pSC As %Status, ByRef pHttp, ByRef pFault, ByRef pViolationList, ByRef pReadBack, Output pViolations As %String) As %String
{
    Set pViolations = ""
    For tI = 1:1:+$Get(pViolationList) Set pViolations = pViolations _ $Select(pViolations = "": "", 1: ",") _ $List(pViolationList(tI), 1) _ ":" _ $List(pViolationList(tI), 2)
    If +$Get(pViolationList) > 0 Quit "violations"
    If $$$ISERR(pSC) Quit +$Get(pHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
    Quit $Select($IsObject($Get(pReadBack)): pReadBack.%Get("verdict"), 1: "(none)")
}

/// <p>The list's screen action <code>delete</code> on <var>pName</var>, through the action fixture; the parsed envelope in <var>pAnswer</var>, answering
/// the HTTP status.</p>
ClassMethod ActDelete(pName As %String, Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": "delete"}
    Do tBody.%Set("id", pName, "string")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .tJson, .tStatus)
    Set pAnswer = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus
}

/// <p>The refusal code an answer carries, or <code>""</code>.</p>
ClassMethod Code(pAnswer As %DynamicObject) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>Mint <var>pTool</var> for <var>pName</var> with the gateway <var>pGateway</var> (none for a delete) and confirm it, answering <code>http code</code>
/// and the confirm's answer in <var>pResult</var>, or <code>refused: &lt;problem&gt;</code> when the mint refused; the proposal is in <var>pProposal</var>.</p>
ClassMethod Agent(pTool As %String, pName As %String, pGateway As %String, Output pResult As %DynamicObject, Output pProposal As %DynamicObject) As %String
{
    Set tArgs = {}
    Do tArgs.%Set("Name", pName, "string")
    If pGateway '= "" Do tArgs.%Set("SMSGateway", pGateway, "string")
    Set tSC = $ClassMethod(..#AGENT, "Mint", pTool, pName, tArgs, .pProposal, .tHttp, .tProblem)
    If '$IsObject($Get(pProposal)) Quit "refused: " _ $Get(tProblem)
    Quit $ClassMethod(..#AGENT, "Confirm", pProposal, .pResult)
}

/// <p>The agent's dispatch of <var>pKey</var> with <var>pInput</var>: <code>minted</code> with the proposal's id in <var>pProposalId</var> and the turn's key
/// in <var>pTurnKey</var>, or <code>refused</code>.</p>
ClassMethod Dispatched(pKey As %String, pInput As %DynamicObject, Output pProposalId As %String, Output pTurnKey As %String) As %String
{
    Set pProposalId = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Set pTurnKey = $Get(tTurnKey)
    If $$$ISERR(tSC) Quit "no turn"
    Set tUse = {"type": "tool_use", "id": "toolu_phone"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(pKey), "string")
    Do tUse.%Set("input", pInput)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tContent = $Select($IsObject($Get(tResults)) && (tResults.%Size() = 1): tResults.%Get(0).%Get("content"), 1: "")
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(tContent)
    If $IsObject(tParsed) Set pProposalId = tParsed.%Get("proposalId")
    Quit $Select(pProposalId '= "": "minted", 1: "refused")
}

/// <p>Store the delete key enabled, so the agent's confirm of a delete is not refused by governance; the teardown restores the policy.</p>
ClassMethod EnableDelete() As %Status
{
    Kill tSettings
    Set tSettings("security.phoneproviders.delete") = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p><b>AC2.</b> A provider is created, its SMS gateway changed and it is deleted, each by both callers: the form's Save route and the list's delete
/// action, and the agent's confirmed proposals. Each round-trips over <code>%SYS.PhoneProviders</code>: the row reads what was sent, the read-back
/// matches (and reads the provider gone after a delete), every other provider reads as before, and the delete's card states its consequence.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.PhoneProviderPort</class>'s <code>VendorWrite</code> sends the fresh read's gateway instead of the new
/// one -> the change assertions go red.</p>
Method TestAProviderIsCreatedChangedAndDeletedByBothCallers()
{
    Set tScreenName = ..Marker("S")
    Set tAgentName = ..Marker("A")
    Set tBefore = ..Providers().%ToJSON()
    Do $$$AssertEquals(..SaveCreate(tScreenName, ..#FIRSTGATEWAY, .tViolations) _ "|" _ tViolations, "matches|", "the Save route creates the provider and its read-back matches")
    Do $$$AssertEquals(..GatewayOf(tScreenName), ..#FIRSTGATEWAY, "which reads what was sent")
    Do $$$AssertEquals(..Without(tScreenName), tBefore, "and every other provider reads as before")
    Set tResult = ##class(OcuPilot.Screen.Read).Execute(..#LISTSCREEN, "", .tRead, .tHttp, .tFault)
    Set tFound = ""
    Set tIterator = tRead.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Name") = tScreenName Set tFound = tRow.%Get("SMSGateway")
    }
    Do $$$AssertEquals(tFound, ..#FIRSTGATEWAY, "and the list's own read answers its row with the gateway sent")
    Do $$$AssertEquals(..SaveUpdate(tScreenName, ..#SECONDGATEWAY, .tViolations) _ "|" _ ..GatewayOf(tScreenName), "matches|" _ ..#SECONDGATEWAY, "the Save route changes the gateway and reads it back")
    Do $$$AssertEquals(..Without(tScreenName), tBefore, "and every other provider reads as before")
    Set tStatus = ..ActDelete(tScreenName, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..Providers().%GetTypeOf(tScreenName), "200|notFound|unassigned", "the list's Delete removes it and reads it gone")
    Set tOutcome = ..Agent(..#CREATE, tAgentName, ..#FIRSTGATEWAY, .tResult2, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult2) _ "|" _ ..GatewayOf(tAgentName), "200 |matches|" _ ..#FIRSTGATEWAY, "the agent's confirmed create makes it, read back matching: " _ tOutcome)
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), "", "and its card states no consequence")
    Set tOutcome = ..Agent(..#UPDATE, tAgentName, ..#SECONDGATEWAY, .tResult3, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult3) _ "|" _ ..GatewayOf(tAgentName), "200 |matches|" _ ..#SECONDGATEWAY, "the agent's confirmed change sets the gateway: " _ tOutcome)
    Do $$$AssertEquals(..Without(tAgentName), tBefore, "and every other provider reads as before")
    Do $$$AssertStatusOK(..EnableDelete(), "the delete key is stored enabled, which the confirm asks")
    Set tOutcome = ..Agent(..#DELETE, tAgentName, "", .tResult4, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult4) _ "|" _ ..Providers().%GetTypeOf(tAgentName), "200 |notFound|unassigned", "the agent's confirmed delete removes it, read back gone: " _ tOutcome)
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), "PHONEPROVIDER.DELETE", "and its card states the delete consequence")
    Do $$$AssertEquals(..Providers().%ToJSON(), tBefore, "the list reads as it did before the test")
}

/// <p><b>AC2.</b> A refused write changes nothing on either caller: the Save route refuses a held name on <code>Name</code> and a name or a gateway the rules
/// refuse on its field, an edit of an absent provider is 404; the list's delete of an absent provider is 404 <code>PHONEPROVIDER.NOTFOUND</code>; the port
/// finds a provider by its exact name, so another case is absent; and the mint refuses each with its sentence. The list reads as before.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Area.Security.PhoneProviderRules</class>'s <code>IsBounded</code> admits any length -> the name and gateway rows
/// go red, with a provider created that the instance could not store.</p>
Method TestARefusedWriteChangesNothingOnEitherCaller()
{
    Set tBefore = ..Providers().%ToJSON()
    Set tName = ..Marker("R")
    Do $$$AssertEquals(..SaveCreate(tName, ..#FIRSTGATEWAY, .tViolations), "matches", "a provider to hold")
    Do $$$AssertEquals(..SaveCreate(tName, ..#SECONDGATEWAY, .tViolations) _ "|" _ tViolations, "violations|Name:PHONEPROVIDER.TAKEN", "the Save refuses a held name on its field")
    Do $$$AssertEquals(..GatewayOf(tName), ..#FIRSTGATEWAY, "and leaves the held provider as it was")
    Do $$$AssertEquals(..SaveCreate(..Marker($Translate($Justify("", 50), " ", "Q")), ..#FIRSTGATEWAY, .tViolations) _ "|" _ tViolations, "violations|Name:PHONEPROVIDER.NAME", "the Save refuses a name over fifty characters, on its field")
    Do $$$AssertEquals(..SaveCreate(..Marker("Q"), "", .tViolations) _ "|" _ tViolations, "violations|SMSGateway:PHONEPROVIDER.GATEWAY", "and an empty gateway, on its field")
    Do $$$AssertEquals(..SaveCreate(..Marker("Q"), $Translate($Justify("", 51), " ", "g"), .tViolations) _ "|" _ tViolations, "violations|SMSGateway:PHONEPROVIDER.GATEWAY", "and a gateway over fifty characters")
    Do $$$AssertEquals(..SaveUpdate(tName, "a" _ $Char(7) _ "b", .tViolations) _ "|" _ tViolations, "violations|SMSGateway:PHONEPROVIDER.GATEWAY", "an edit to a gateway holding a control character is refused on its field")
    Do $$$AssertEquals(..SaveUpdate(..Marker("X"), ..#FIRSTGATEWAY, .tViolations), "404 PHONEPROVIDER.NOTFOUND", "an edit of an absent provider is 404")
    Set tStatus = ..ActDelete(..Marker("X"), .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), "404|PHONEPROVIDER.NOTFOUND", "a delete of an absent provider is refused at the list")
    Set tOther = $Select(tName = $ZConvert(tName, "L"): $ZConvert(tName, "U"), 1: $ZConvert(tName, "L"))
    Set tStatus = ..ActDelete(tOther, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer) _ "|" _ ..GatewayOf(tName), "404|PHONEPROVIDER.NOTFOUND|" _ ..#FIRSTGATEWAY, "a delete under the same name in another case names no provider, and the held one stays")
    Set tOutcome = ..Agent(..#CREATE, tName, ..#SECONDGATEWAY, .tResult, .tProposal)
    Do $$$AssertTrue($Extract(tOutcome, 1, 8) = "refused:", "the agent's create of a held name is refused at the mint: " _ tOutcome)
    Do $$$AssertEquals(..GatewayOf(tName), ..#FIRSTGATEWAY, "and leaves the held provider as it was")
    Set tOutcome = ..Agent(..#CREATE, ..Marker("Q"), "", .tResult, .tProposal)
    Do $$$AssertTrue($Extract(tOutcome, 1, 8) = "refused:", "a create that names no gateway is refused at the mint: " _ tOutcome)
    Set tOutcome = ..Agent(..#CREATE, ..Marker("Q"), $Translate($Justify("", 51), " ", "g"), .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome, "refused: '" _ "SMSGateway" _ "': " _ $Parameter("OcuPilot.Api.PhoneProviderError", "REASONGATEWAY"), "a gateway over fifty characters is refused at the mint on its published sentence")
    Set tOutcome = ..Agent(..#UPDATE, ..Marker("X"), ..#FIRSTGATEWAY, .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome, "refused: '" _ ..Marker("X") _ "' is not present on this instance", "a change of an absent provider is refused at the mint, which reads the target first")
    Set tOutcome = ..Agent(..#DELETE, ..Marker("X"), "", .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome, "refused: '" _ ..Marker("X") _ "' is not present on this instance", "and a delete of an absent provider")
    Kill tQuery
    Set tQuery("name") = ..Marker("Q")
    Set tSC = $ClassMethod(..#PORT, "Invoke", "PhoneProviders", "CREATE", .tQuery, {"SMSGateway": "ok.example.com", "Extra": "x"}, .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code"), "400|PORT.VALIDATION", "the port refuses a body that names more than the gateway and the name")
    Do $$$AssertEquals(..Providers().%GetTypeOf(..Marker("Q")), "unassigned", "and creates nothing")
    Do $$$AssertEquals(..Without(tName), tBefore, "every other provider reads as before")
}

/// <p><b>AC2, AD-54.</b> A provider that a user names is refused <code>PHONEPROVIDER.INUSE</code> by both callers before any vendor call: the list's delete
/// and the agent's confirmed delete answer 409 and the provider stays, and the port itself refuses it before it reaches the vendor and sends the vendor
/// the delete only once no user names it. The count follows the vendor's own predicate with the name bound, which matches without regard to case, though
/// a provider is found by its exact name: a user naming the provider in another case still holds it.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.PhoneProviderPort</class>'s <code>Remove</code> skips the count of users naming the provider -> the port's
/// refusal and the recorded call assertions go red.</p>
Method TestAProviderNamedByAUserIsRefusedByBothCallersBeforeAnyVendorCall()
{
    Set tName = ..Marker("U")
    Set tBefore = ..Providers().%ToJSON()
    Do $$$AssertEquals(..SaveCreate(tName, ..#FIRSTGATEWAY, .tViolations), "matches", "a provider to hold")
    Set tOther = $Select(tName = $ZConvert(tName, "U"): $ZConvert(tName, "L"), 1: $ZConvert(tName, "U"))
    Do $$$AssertStatusOK(..MakeUser(tOther), "a test user names it in another case")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do $ClassMethod(..#SEAM, "Reset")
    Kill tQuery
    Set tQuery("name") = tName
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "PhoneProviders", "DELETE", .tQuery, "", .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "") _ "|" _ $ClassMethod(..#SEAM, "Calls"), "409|PHONEPROVIDER.INUSE|", "the port refuses it 409 and sends the vendor nothing")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: ""), $Parameter("OcuPilot.Api.PhoneProviderError", "REASONINUSE"), "on the published sentence")
    Set tStatus = ..ActDelete(tName, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer) _ "|" _ ..GatewayOf(tName), "409|PHONEPROVIDER.INUSE|" _ ..#FIRSTGATEWAY, "the list's Delete is refused 409 and the provider stays")
    Do $$$AssertStatusOK(..EnableDelete(), "the delete key is stored enabled, which the confirm asks")
    Set tOutcome = ..Agent(..#DELETE, tName, "", .tResult, .tProposal)
    Do $$$AssertEquals($Piece(tOutcome, " ", 1) _ "|" _ ..GatewayOf(tName), "409|" _ ..#FIRSTGATEWAY, "the agent's confirmed delete is refused 409 and the provider stays: " _ tOutcome)
    Do $$$AssertEquals($Piece(tOutcome, " ", 2), "PHONEPROVIDER.INUSE", "on the same code: " _ tOutcome)
    Do $$$AssertStatusOK(..SetUserProvider(""), "the user's provider is cleared")
    Do $ClassMethod(..#SEAM, "Reset")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "PhoneProviders", "DELETE", .tQuery, "", .tOut, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#SEAM, "Calls"), "200|DELETE|" _ tName, "with no user naming it the port sends the vendor the delete, once")
    Set tStatus = ..ActDelete(tName, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..Providers().%GetTypeOf(tName), "200|notFound|unassigned", "and the list's Delete removes it")
    Do $$$AssertEquals(..Providers().%ToJSON(), tBefore, "the list reads as it did before the test")
}

/// <p><b>AC2.</b> The routes answer JSON over the wire: <code>POST /phone-provider</code> creates a provider with 201 and a matching read-back,
/// <code>GET /phone-provider/form</code> answers its two fields (and a new provider's, both empty), <code>PUT /phone-provider/:id</code> changes it with
/// 200, a held name is 422 on <code>Name</code>, and a name the rules refuse is 422 with its violation on the field.</p>
/// <p>Mutation (Rule 19): remove <code>POST /phone-provider</code> from <file>Api/Router.cls</file> -- the create leg goes red.</p>
Method TestTheRoutesAnswerJsonOverTheWire()
{
    Set tName = ..Marker("W")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tBody = {"Name": (tName), "SMSGateway": (..#FIRSTGATEWAY)}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/phone-provider", tUser, tPassword, .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "POST /phone-provider answers 201: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tAnswer.id _ "|" _ tAnswer.readBack.verdict, tName _ "|matches", "with the provider's id and a matching read-back")
    Do $$$AssertEquals(..GatewayOf(tName), ..#FIRSTGATEWAY, "and the instance holds it")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/phone-provider/form?id=" _ ##class(OcuPilot.Kernel.EntityId).Encode(tName), tUser, tPassword, .tFormStatus, .tFormRaw, .tFormHeaders)
    Set tForm = ##class(%DynamicObject).%FromJSON(tFormRaw)
    Do $$$AssertEquals(tFormStatus _ "|" _ tForm.row.Name _ "|" _ tForm.row.SMSGateway, "200|" _ tName _ "|" _ ..#FIRSTGATEWAY, "GET /phone-provider/form answers the provider's two fields: " _ $Extract($Get(tFormRaw), 1, 200))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/phone-provider/form", tUser, tPassword, .tNewStatus, .tNewRaw, .tNewHeaders)
    Set tNew = ##class(%DynamicObject).%FromJSON(tNewRaw)
    Do $$$AssertEquals(tNewStatus _ "|" _ tNew.row.Name _ "|" _ tNew.row.SMSGateway, "200||", "and a new provider's, both empty")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/phone-provider/form?id=" _ ##class(OcuPilot.Kernel.EntityId).Encode(..Marker("Z")), tUser, tPassword, .tAbsentStatus, .tAbsentRaw, .tAbsentHeaders)
    Do $$$AssertEquals(tAbsentStatus, 404, "a provider the instance does not hold is 404 on the form read")
    Set tChange = {"SMSGateway": (..#SECONDGATEWAY)}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ "/phone-provider/" _ ##class(OcuPilot.Kernel.EntityId).Encode(tName), tUser, tPassword, .tChangeStatus, .tChangeRaw, .tChangeHeaders, tChange.%ToJSON(), "application/json")
    Do $$$AssertEquals(tChangeStatus, 200, "PUT /phone-provider/:id answers 200: " _ $Extract($Get(tChangeRaw), 1, 200))
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tChangeRaw).readBack.verdict _ "|" _ ..GatewayOf(tName), "matches|" _ ..#SECONDGATEWAY, "with a matching read-back")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/phone-provider", tUser, tPassword, .tHeldStatus, .tHeldRaw, .tHeldHeaders, tBody.%ToJSON(), "application/json")
    Set tHeld = ##class(%DynamicObject).%FromJSON(tHeldRaw)
    Do $$$AssertEquals(tHeldStatus _ "|" _ tHeld.detail.violations.%Get(0).field _ "|" _ tHeld.detail.violations.%Get(0).code, "422|Name|PHONEPROVIDER.TAKEN", "a held name is 422 on its field")
    Set tBad = {"Name": (..Marker("B")), "SMSGateway": ""}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/phone-provider", tUser, tPassword, .tBadStatus, .tBadRaw, .tBadHeaders, tBad.%ToJSON(), "application/json")
    Set tViolation = ##class(%DynamicObject).%FromJSON(tBadRaw).detail.violations.%Get(0)
    Do $$$AssertEquals(tBadStatus _ "|" _ tViolation.field _ "|" _ tViolation.code, "422|SMSGateway|PHONEPROVIDER.GATEWAY", "an empty gateway is 422 with the violation on its field")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ "/phone-provider/" _ ##class(OcuPilot.Kernel.EntityId).Encode(tName), tUser, tPassword, .tNameStatus, .tNameRaw, .tNameHeaders, {"Extra": "x"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tNameStatus, 400, "an edit that names a key the form does not admit is refused as an unexpected field")
}

/// <p><b>AC2, AC6.</b> With the keys the baseline enables, the agent's call for a create is dispatched, mints a proposal, and its confirm creates the provider
/// once, with a read-back and one write-kind ledger row carrying the audit marker; the token is spent, so a second confirm is refused. The change mints
/// and confirms once. A delete is refused at dispatch while its key ships off, and with its key stored enabled it mints a destructive proposal that
/// carries the delete consequence and confirms once. A person's Save is not governed (AD-22).</p>
/// <p>Mutation (Rule 19): <code>security.phoneproviders.delete</code> set <code>true</code> in <class>OcuPilot.Kernel.Governance.Baseline</class> -> the
/// refusal assertion goes red.</p>
Method TestTheAgentsConfirmWritesOnceWithOneAuditMarker()
{
    Set tName = ..Marker("G")
    Set tInput = {"Name": (tName), "rationale": "probe", "expectedImpact": "probe"}
    Do tInput.%Set("SMSGateway", ..#FIRSTGATEWAY, "string")
    Do $$$AssertEquals(..Dispatched("security.phoneproviders.create", tInput, .tProposalId, .tTurnKey) _ "|" _ (tProposalId '= ""), "minted|1", "the baseline lets the create mint a proposal")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $Get(tCode) _ "|" _ ..GatewayOf(tName) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "1||" _ ..#FIRSTGATEWAY _ "|matches", "its confirm creates the provider, with a read-back: " _ $Get(tCode))
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row records it")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent's audit marker landed on it")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult2, .tHttp2, .tCode2, .tDetail2)
    Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ ..GatewayOf(tName), "1|" _ ..#FIRSTGATEWAY, "a second confirm of the same proposal is refused and changes nothing more")
    Set tSet = {"Name": (tName), "rationale": "probe", "expectedImpact": "probe"}
    Do tSet.%Set("SMSGateway", ..#SECONDGATEWAY, "string")
    Do $$$AssertEquals(..Dispatched("security.phoneproviders.update", tSet, .tSetId, .tSetTurn) _ "|" _ (tSetId '= ""), "minted|1", "the baseline lets the change mint a proposal")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tSetId, "", $Username, .tSetResult, .tSetHttp, .tSetCode, .tSetDetail)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ ..GatewayOf(tName) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tSetResult), "1|" _ ..#SECONDGATEWAY _ "|matches", "its confirm changes the gateway, with a read-back: " _ $Get(tSetCode))
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tSetTurn, .tSetRow) _ "|" _ $Get(tSetRow("AuditMarked")), "1|" _ $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "with one audit marker of its own")
    Set tDelete = {"Name": (tName), "rationale": "probe", "expectedImpact": "probe"}
    Do $$$AssertEquals(..Dispatched("security.phoneproviders.delete", tDelete, .tNoneId, .tNoneTurn), "refused", "a delete is refused at dispatch while its key ships off")
    Do $$$AssertStatusOK(..EnableDelete(), "the delete key is stored enabled")
    Do $$$AssertEquals(..Dispatched("security.phoneproviders.delete", tDelete, .tDeleteId, .tDeleteTurn) _ "|" _ (tDeleteId '= ""), "minted|1", "and the same call mints")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tDeleteId, .tFound, .tValues)
    Do $$$AssertEquals($Get(tValues("destructive")) _ "|" _ $Get(tValues("consequence")), "1|PHONEPROVIDER.DELETE", "as a destructive proposal that carries the delete consequence")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tDeleteId, "", $Username, .tResult3, .tHttp3, .tCode3, .tDetail3)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult3) _ "|" _ ..Providers().%GetTypeOf(tName), "1|notFound|unassigned", "its confirm deletes the provider once, read back gone: " _ $Get(tCode3))
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tDeleteTurn, .tDeleteRow), 1, "with one audit marker of its own")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline decides again")
    Set tPerson = ..SaveCreate(..Marker("H"), ..#FIRSTGATEWAY, .tViolations)
    Do $$$AssertEquals(tPerson, "matches", "while a person's Save is not governed and still creates")
}

}
