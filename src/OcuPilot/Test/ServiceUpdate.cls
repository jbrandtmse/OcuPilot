/// <p>Pins <class>OcuPilot.Screen.Tool.ServiceUpdate</class> as the agent reaches it (AD-3, AD-4,
/// AD-6, AD-10): what it advertises and declares; the mint's diff rows; a two-field confirm whose
/// body keeps every other field; the three rules at the mint; the serving service's disable refused
/// at the mint by name while an address change is minted destructive with its consequence; and the
/// destructive marking of an added unauthenticated bit and of an address carrying
/// <code>%All</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and its protected state readable.
/// Every mint's fresh read and every confirmed write go to <class>OcuPilot.Test.ProposalFixture</class>;
/// the tool's own rules read the instance, and only read it. No arming variable is required.</p>
Class OcuPilot.Test.ServiceUpdate Extends %UnitTest.TestCase
{

Parameter UPDATE = "OcuPilot.Screen.Tool.ServiceUpdate";

Parameter LIST = "OcuPilot.Screen.Descriptor.ServiceList";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>A name the instance does not hold, so the tool's own rules read nothing for it.</p>
Parameter PROBE = "OcuPilotProbeService";

/// <p>A service this instance holds and never enables, read by the capability rule.</p>
Parameter CALLIN = "%Service_CallIn";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>AD-3: the tool admits <code>AutheEnabled</code>, <code>ClientSystems</code> and
/// <code>Enabled</code> -- the prohibited set's own list -- typed as the vendor reads them, never
/// <code>Description</code>, which the vendor drops; it is a merge write over the vendor's
/// <code>GET</code> and <code>PUT</code> with no secret.</p>
Method TestTheToolDeclaresItsFieldsAndShapes()
{
    Set tSchema = $ClassMethod(..#UPDATE, "InputSchema")
    Set tNames = ""
    Set tIterator = tSchema.%Get("properties").%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $ListFind($ListBuild("Name", "rationale", "expectedImpact", "reverse"), tKey) Continue
        Set tNames = tNames _ $ListBuild(tKey)
    }
    Do $$$AssertEquals(..Sorted(tNames), "AutheEnabled,ClientSystems,Enabled", "the schema advertises the three fields and nothing else")
    Do $$$AssertEquals(tSchema.%Get("properties").%Get("AutheEnabled").%Get("type") _ " " _ tSchema.%Get("properties").%Get("Enabled").%Get("type") _ " " _ tSchema.%Get("properties").%Get("ClientSystems").%Get("type"), "integer boolean array", "typed as the vendor's read answers them")
    Do $$$AssertEquals(..Sorted($ClassMethod(..#UPDATE, "SettableFields")), ..Sorted($ClassMethod(..#SET, "PermittedChangeFields", "service")), "the tool sets what the set permits a change")
    Do $$$AssertEquals($ListFind($ClassMethod(..#UPDATE, "SettableFields"), "Description"), 0, "and never the description")
    Do $$$AssertEquals($ClassMethod(..#UPDATE, "SecretArguments"), "", "it admits no secret")
    Do $$$AssertEquals($ClassMethod(..#UPDATE, "Endpoint") _ " " _ $ClassMethod(..#UPDATE, "ReadType") _ " " _ $ClassMethod(..#UPDATE, "WriteType") _ " " _ $ClassMethod(..#UPDATE, "SendsBody") _ " " _ $ClassMethod(..#UPDATE, "ChangeAction"), "Security.Service GET PUT 1 updated", "a merge write over the vendor's read and PUT")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).IsMutating("Security.Service", "PUT"), 1, "which the port admits")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("service", "%Service_CallIn"), "%service_callin", "a name is one entity in any case (AD-13)")
}

/// <p>AD-4, AD-6: a mint answers one row per changed field and counts the fields sent unchanged, and a
/// confirmed two-field change sends the fresh read with the two applied, so
/// <code>AutheEnabled</code> and the description reach the vendor as the instance held them.</p>
/// <p>Mutation (Rule 19): make the tool's merge send the changed fields only -- the body leg goes
/// red.</p>
Method TestATwoFieldConfirmKeepsEveryOtherField()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh(48, "[]", "false"))
    Set tSC = ..Mint({"Name": (..#PROBE), "ClientSystems": ["10.0.0.1"], "Enabled": true}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the change is minted: " _ ..Problem(.tFault))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 2, "one row per changed field")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 2, "and the other two sent unchanged")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode)
    Do $$$AssertEquals(tHttp, 200, "the confirm writes: " _ tCode)
    Set tBody = ##class(%DynamicObject).%FromJSON(##class(OcuPilot.Test.ProposalFixture).LastWriteBody())
    Do $$$AssertEquals(tBody.%Get("AutheEnabled"), 48, "the methods the instance held are sent back")
    Do $$$AssertEquals(tBody.%Get("Description"), "probe service", "and so is the description")
    Do $$$AssertEquals(tBody.%Get("ClientSystems").%ToJSON() _ " " _ tBody.%Get("Enabled"), "[""10.0.0.1""] 1", "with the two changes applied")
}

/// <p>AD-55: the tool's rules refuse at the mint what the form refuses: an entry holding a semicolon,
/// a role the instance does not hold, and an authentication method the service does not support --
/// each by its published sentence, and nothing is written.</p>
/// <p>Mutation (Rule 19): drop the <code>Validate</code> call from
/// <method>OcuPilot.Screen.Tool.ServiceUpdate.ArgumentProblem</method> -- all three legs go red.</p>
Method TestTheRulesRefuseAtTheMint()
{
    Set tError = "OcuPilot.Api.Error"
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh(48, "[]", "false"))
    Set tCases = [{"Name": (..#PROBE), "ClientSystems": ["a;b"]}, {"Name": (..#PROBE), "ClientSystems": ["10.0.0.1|OcuPilotNoSuchRole99"]}, {"Name": (..#CALLIN), "AutheEnabled": 262192}]
    Set tCodes = $ListBuild($Parameter(tError, "SERVICEADDRESSSHAPE"), $Parameter(tError, "SERVICEADDRESSROLE"), $Parameter(tError, "SERVICEAUTHEUNSUPPORTED"))
    For tI = 1:1:$ListLength(tCodes) {
        Set tCase = $ListBuild("", $List(tCodes, tI))
        Set tArgs = tCases.%Get(tI - 1)
        Set tSC = ..Mint(tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 400, tArgs.%ToJSON() _ " is refused at the mint")
        Do $$$AssertTrue(..Problem(.tFault) [ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 2)), tArgs.%ToJSON() _ ": by " _ $List(tCase, 2) _ "'s sentence: " _ ..Problem(.tFault))
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing is written")
}

/// <p>AD-10 as amended (ruling 2dca0322), AC5: on the service OcuPilot is served through, turning it
/// off is refused at the mint with the published sentence, in any spelling of its name; changing its
/// addresses or methods is minted destructive with <code>SERVICE.SERVESOCUPILOT</code> as its
/// consequence, even beside a privileged role. The mint writes nothing, and no proposal here is
/// confirmed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.ServingServiceDisabled</method>
/// answer 0 -- the disable legs go red. Drop the serving branch of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ServiceWeakening</method> -- the address legs go
/// red.</p>
Method TestTheServingServiceIsNeverTurnedOffAndItsAddressesAreMarked()
{
    Set tServing = $Parameter(..#SET, "SERVINGSERVICENAME")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh(32, "[]", "true"))
    For tName = tServing, $ZConvert(tServing, "L") {
        Set tSC = ..Mint({"Name": (tName), "Enabled": false}, .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 400, tName _ ": turning it off is refused at the mint")
        Do $$$AssertTrue(..Problem(.tFault) [ $Parameter(..#SET, "SERVINGSERVICEREASON"), tName _ ": by the published sentence: " _ ..Problem(.tFault))
    }
    Set tKey = ..MintedKey({"Name": (tServing), "ClientSystems": ["10.0.0.1"]})
    Do $$$AssertNotEquals(tKey, "", "an address change is minted")
    Do ..Stored(tKey, .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "1 " _ $Parameter(..#SET, "EFFECTSERVINGSERVICE"), "destructive, naming that OcuPilot is served through it")
    Set tKey = ..MintedKey({"Name": (tServing), "ClientSystems": ["10.0.0.1|%All"]})
    Do ..Stored(tKey, .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "1 " _ $Parameter(..#SET, "EFFECTSERVINGSERVICE"), "and the serving consequence outranks a privileged role")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "nothing is written")
}

/// <p>AD-10 as amended, AC5, on the confirm's own path: the kernel set, asked about the agent's tool
/// against the live serving service, refuses turning it off by name
/// (<code>PROHIBITED.SERVINGSERVICE</code>) and permits an address change. It reads the instance and
/// writes nothing.</p>
/// <p>Mutation (Rule 19): remove the <code>service</code> branch from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> -- the refusal leg goes red.</p>
Method TestTheKernelRefusesTheServingServiceDisableByName()
{
    Set tServing = $Parameter(..#SET, "SERVINGSERVICENAME")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("service", "instance", tServing, .tRef)
    Do $$$AssertStatusOK(tSC, "the serving service builds a reference")
    Kill tQuery
    Set tQuery("name") = tServing
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Service", "GET", .tQuery, "", .tLive, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and reads")
    If '$IsObject($Get(tLive)) Quit
    Do $$$AssertEquals(tLive.%Get("Enabled"), 1, "it is enabled, as it must be to serve this request")
    Set tOff = ##class(%DynamicObject).%FromJSON(tLive.%ToJSON())
    Do tOff.%Set("Enabled", 0, "boolean")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits($Parameter(..#UPDATE, "TOOLNAME"), tRef, tOff.%ToJSON(), "[{""field"":""Enabled""}]", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers")
    Do $$$AssertEquals(tProhibits _ " " _ tCode, "1 PROHIBITED.SERVINGSERVICE", "turning it off is refused by name")
    Set tMoved = ##class(%DynamicObject).%FromJSON(tLive.%ToJSON())
    Do tMoved.%Set("ClientSystems", ["10.0.0.1"])
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits($Parameter(..#UPDATE, "TOOLNAME"), tRef, tMoved.%ToJSON(), "[{""field"":""ClientSystems""}]", .tProhibits, .tCode)
    Do $$$AssertEquals(tProhibits _ " " _ tCode, "0 ", "while an address change is permitted")
}

/// <p>AD-10 by effect: on any other service, adding the unauthenticated bit is minted destructive
/// with <code>SERVICE.UNAUTHENTICATED</code>, and an address given <code>%All</code> is minted
/// destructive naming the privilege; an ordinary address is neither.</p>
/// <p>Mutation (Rule 19): drop the service arm of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method> -- the
/// <code>%All</code> leg goes red.</p>
Method TestAWeakeningOrPrivilegedChangeIsMintedDestructive()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh(48, "[]", "false"))
    Set tKey = ..MintedKey({"Name": (..#PROBE), "AutheEnabled": 112})
    Do ..Stored(tKey, .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "1 " _ $Parameter(..#SET, "EFFECTSERVICEUNAUTHENTICATED"), "adding bit 64 is destructive and named")
    Set tKey = ..MintedKey({"Name": (..#PROBE), "ClientSystems": ["10.0.0.9|%All"]})
    Do ..Stored(tKey, .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "1 " _ $Parameter("OcuPilot.Kernel.Proposal.Mint", "CONSEQUENCEPRIVILEGED"), "an address given %All is destructive and names the privilege")
    Set tKey = ..MintedKey({"Name": (..#PROBE), "ClientSystems": ["10.0.0.9"]})
    Do ..Stored(tKey, .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "0 ", "while an ordinary address is neither")
}

/// <p>AD-5, AD-44: the form is built, unlisted, at the list's own route with the editor suffix, over
/// the list's own pairs, and ends with a honoured classic-portal exemption naming the classic page
/// and its same-origin address, while the list declares none; every <code>SERVICE.*</code> code
/// carries a sentence.</p>
/// <p>Mutation (Rule 19): set the list's exemption to exempt -- the list leg goes red.</p>
Method TestTheFormDescriptorIsBuiltUnlistedAndExempt()
{
    Set tForm = "OcuPilot.Screen.Descriptor.ServiceForm"
    Set tList = ..#LIST
    Do $$$AssertEquals($ClassMethod(tForm, "Route"), $ClassMethod(tList, "Route") _ "/edit", "the form's route is the list's own with the editor suffix")
    Do $$$AssertEquals(''$ClassMethod(tForm, "IsBuilt") _ " " _ (+$ClassMethod(tForm, "SideBarPosition")) _ " " _ $ClassMethod(tForm, "Archetype") _ " " _ $ClassMethod(tForm, "PrimaryEntityType"), "1 0 form-page service", "a built, unlisted form page over the list's type")
    Do $$$AssertEquals($ClassMethod(tForm, "ToolIdentifier"), "permissions.serviceform", "with its own tool identifier")
    Do $$$AssertEquals($ListToString($ClassMethod(tForm, "PrivilegePairs")), $ListToString($ClassMethod(tList, "PrivilegePairs")), "requiring exactly what the list requires")
    Do $$$AssertEquals($Parameter("OcuPilot.Area.Permissions.ServiceSave", "DESCRIPTORCLASS") _ " " _ $Parameter("OcuPilot.Area.Permissions.ServiceRules", "DESCRIPTORCLASS"), tForm _ " " _ tForm, "and the routes gate on the form's declaration")
    Set tSC = $ClassMethod(tForm, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the form's declaration parses")
    If $$$ISERR(tSC) Quit
    Set tExemption = tDeclaration.%Get("classicLinkExemption")
    Do $$$AssertEquals(tDeclaration.%Get("classicPage") _ " " _ tExemption.%Get("exempt") _ " " _ tExemption.%Get("label") _ " " _ tExemption.%Get("href"), "%CSP.UI.Portal.Dialog.Service 1 Services /csp/sys/sec/%25CSP.UI.Portal.Services.zen", "it names its classic page and links out to the classic list")
    Do $$$AssertTrue(tExemption.%Get("reason") [ "Story 16.13", "its reason names the story that removes it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and the registry honours it")
    Do $$$AssertEquals(tDeclaration.%Get("suggestedPrompts").%Size(), 3, "it declares three suggested prompts")
    Set tSC = $ClassMethod(tList, "DeclarationJson", .tListDeclaration)
    If $$$ISOK(tSC) Do $$$AssertEquals(tListDeclaration.%Get("classicLinkExemption").%Get("exempt"), 0, "while the list declares no exemption")
    Set tCodes = ##class(OcuPilot.Api.Error).ServiceViolationCodes()
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, tI)), "", $List(tCodes, tI) _ " carries a written sentence")
    }
}

/// <p>A service as the vendor's read answers one.</p>
ClassMethod Fresh(pAuthe As %Integer, pClients As %String, pEnabled As %String) As %String
{
    Quit "{""AutheEnabled"":" _ pAuthe _ ",""ClientSystems"":" _ pClients _ ",""Description"":""probe service"",""Enabled"":" _ pEnabled _ "}"
}

/// <p>Mint one proposal with <var>pArgs</var> through the fixture mint.</p>
Method Mint(pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tTool = ..#UPDATE
    Quit $ClassMethod(..#MINT, "Mint", ..#LIST, $Parameter(tTool, "TOOLNAME"), $Username, "", tTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), pArgs.%Get("Name"), $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
}

/// <p>The key of the proposal <method>Mint</method> answers, or <code>""</code>.</p>
Method MintedKey(pArgs As %DynamicObject) As %String
{
    Set tSC = ..Mint(pArgs, .tProposal, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tProposal)) Quit ""
    Quit tProposal.%Get("proposalId")
}

/// <p>Confirm <var>pKey</var> through the shipped transition over the fixture port.</p>
Method Confirm(pKey As %String, Output pHttp As %Integer, Output pCode As %String) As %Status
{
    Quit $ClassMethod(..#CONFIRM, "Confirm", pKey, "", $Username, .tResult, .pHttp, .pCode, .tDetail)
}

/// <p>Proposal <var>pKey</var>'s stored destructive flag and consequence.</p>
ClassMethod Stored(pKey As %String, Output pDestructive As %Boolean, Output pConsequence As %String)
{
    Set pDestructive = ""
    Set pConsequence = "<absent>"
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pKey, .tFound, .tValues)
    If $$$ISERR(tSC) || '$Get(tFound) Quit
    Set pDestructive = +$Get(tValues("destructive"))
    Set pConsequence = $Get(tValues("consequence"))
}

/// <p>The problem a refusal's fault carries, or <code>""</code>.</p>
ClassMethod Problem(ByRef pFault) As %String
{
    If '$IsObject($Get(pFault)) Quit ""
    If pFault.%GetTypeOf("detail") '= "object" Quit pFault.%Get("reason")
    Quit pFault.%Get("detail").%Get("problem")
}

/// <p><var>pList</var> sorted and comma-separated.</p>
ClassMethod Sorted(pList As %List) As %String
{
    Kill tNames
    For tI = 1:1:$ListLength(pList) Set tNames($List(pList, tI)) = ""
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tNames(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

}
