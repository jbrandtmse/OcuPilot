/// <p>Pins <class>OcuPilot.Screen.Tool.ServiceUpdate</class> as the agent reaches it (AD-3, AD-4,
/// AD-6, AD-10, AD-44): what it advertises and declares, its pairs among them; the mint's diff rows,
/// an empty address list reading "Unrestricted" on a changed and an unchanged row (DW-1016); a
/// two-field confirm whose body keeps every other field; the entry reading both callers share, the
/// classic <code>address:role</code> spelling sent canonical and an entry the service holds sent as
/// read; the rules at the mint, the three address rules against held services among them, and the
/// vendor's own address check they use; the serving service's disable refused at the mint by name
/// while an address change is minted destructive with its consequence; and the destructive marking
/// of an added unauthenticated bit and of an address carrying <code>%All</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and its protected state readable.
/// Every mint's fresh read and every confirmed write go to <class>OcuPilot.Test.ProposalFixture</class>;
/// the tool's own rules read the instance (<code>%Service_CallIn</code>,
/// <code>%Service_CacheDirect</code> and the serving service among it), and only read it. No arming
/// variable is required.</p>
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

/// <p>A service this instance holds and never enables, read by the capability rule. It checks no
/// address.</p>
Parameter CALLIN = "%Service_CallIn";

/// <p>A service this instance holds and never enables, which checks addresses and gives them no
/// roles. Read here, never written.</p>
Parameter CACHEDIRECT = "%Service_CacheDirect";

/// <p>The Edit Service dialog the tool declares it performs (AD-44).</p>
Parameter DIALOG = "%CSP.UI.Portal.Dialog.Service";

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
/// a role the instance does not hold, in either spelling, an authentication method the service
/// does not support, and an empty address before a role in the <code>address:role</code> spelling --
/// each by its published sentence, and nothing is written.</p>
/// <p>Mutation (Rule 19): drop the <code>Validate</code> call from
/// <method>OcuPilot.Screen.Tool.ServiceUpdate.ArgumentProblem</method> -- every leg goes red. Make
/// <method>OcuPilot.Area.Permissions.ServiceRules.AddressViolations</method> read roles after
/// <code>|</code> only -- the <code>address:role</code> leg goes red. Drop the empty-address check
/// <method>OcuPilot.Area.Permissions.ServiceRules.EntryShaped</method> makes through
/// <method>OcuPilot.Area.Permissions.ServiceRules.EntryParts</method> -- the <code>:%Operator</code> leg
/// goes red.</p>
Method TestTheRulesRefuseAtTheMint()
{
    Set tError = "OcuPilot.Api.Error"
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh(48, "[]", "false"))
    Set tCases = [{"Name": (..#PROBE), "ClientSystems": ["a;b"]}, {"Name": (..#PROBE), "ClientSystems": ["10.0.0.1|OcuPilotNoSuchRole99"]}, {"Name": (..#CALLIN), "AutheEnabled": 262192}, {"Name": (..#PROBE), "ClientSystems": ["10.0.0.1:OcuPilotNoSuchRole99"]}, {"Name": (..#PROBE), "ClientSystems": [":%Operator"]}]
    Set tCodes = $ListBuild($Parameter(tError, "SERVICEADDRESSSHAPE"), $Parameter(tError, "SERVICEADDRESSROLE"), $Parameter(tError, "SERVICEAUTHEUNSUPPORTED"), $Parameter(tError, "SERVICEADDRESSROLE"), $Parameter(tError, "SERVICEADDRESSSHAPE"))
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
/// consequence, which outranks a privileged role on the card; the service gives an address no roles,
/// so an address with one is refused at the mint. The method leg sends a mask inside the live
/// service's own capabilities, so it also shows the capability rule admits a supported method. The
/// mint writes nothing, and no proposal here is confirmed.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.ServingServiceDisabled</method>
/// answer 0 -- the disable legs go red. Drop the serving branch of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ServiceWeakening</method> -- the address and method
/// legs go red. Drop <code>AutheEnabled</code> from that branch's field list -- the method leg goes
/// red alone.</p>
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
    Do $$$AssertEquals($ClassMethod(..#UPDATE, "Consequence", {}, 1, $Parameter(..#SET, "EFFECTSERVINGSERVICE")), $Parameter(..#SET, "EFFECTSERVINGSERVICE"), "the serving consequence outranks a privileged role")
    Set tSC = ..Mint({"Name": (tServing), "ClientSystems": ["10.0.0.1|%All"]}, .tProposal, .tHttp, .tFault)
    Do $$$AssertTrue((tHttp = 400) && (..Problem(.tFault) [ ##class(OcuPilot.Api.ServiceError).#REASONADDRESSROLEUNSUPPORTED), "an address with a role is refused, since this service gives none: " _ ..Problem(.tFault))
    Set tKey = ..MintedKey({"Name": (tServing), "AutheEnabled": 2080})
    Do $$$AssertNotEquals(tKey, "", "a method the service supports (32 plus LDAP's 2048) is minted")
    Do ..Stored(tKey, .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "1 " _ $Parameter(..#SET, "EFFECTSERVINGSERVICE"), "and a method change is destructive with the same consequence")
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
/// the list's own pairs, and declares its classic page and no exemption, which the registry accepts,
/// while the list declares none either; every <code>SERVICE.*</code> code carries a sentence.</p>
/// <p>Mutation (Rule 19): set the form's exemption to exempt -- the exemption leg goes red.</p>
Method TestTheFormDescriptorIsBuiltUnlistedAndLinksNowhere()
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
    Do $$$AssertEquals(tDeclaration.%Get("classicPage") _ " " _ tExemption.%Get("exempt") _ " [" _ tExemption.%Get("reason") _ tExemption.%Get("label") _ tExemption.%Get("href") _ "]", ..#DIALOG _ " 0 []", "it names its classic page and declares no exemption")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "which the registry accepts")
    Do $$$AssertEquals(tDeclaration.%Get("suggestedPrompts").%Size(), 3, "it declares three suggested prompts")
    Set tSC = $ClassMethod(tList, "DeclarationJson", .tListDeclaration)
    If $$$ISOK(tSC) Do $$$AssertEquals(tListDeclaration.%Get("classicLinkExemption").%Get("exempt"), 0, "while the list declares no exemption")
    Set tCodes = ##class(OcuPilot.Api.Error).ServiceViolationCodes()
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, tI)), "", $List(tCodes, tI) _ " carries a written sentence")
    }
}

/// <p>The one entry reading the rules, the form read and the merge share: the separator is
/// <code>|</code> when the entry holds one or more than one <code>:</code>, and <code>:</code>
/// otherwise, as the classic dialog reads it; the canonical spelling is <code>address</code> or
/// <code>address|role,role</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Permissions.ServiceRules.EntryParts</method>
/// ignore <code>:</code> -- the <code>a:r</code> row goes red.</p>
Method TestAnEntryReadsTheWayTheClassicDialogReadsIt()
{
    Set tRules = "OcuPilot.Area.Permissions.ServiceRules"
    For tCase = $ListBuild("a", "a", "", "a"), $ListBuild("a|r1,r2", "a", "r1,r2", "a|r1,r2"), $ListBuild("a:r", "a", "r", "a|r"), $ListBuild("::1", "::1", "", "::1"), $ListBuild("fe80::1|r", "fe80::1", "r", "fe80::1|r"), $ListBuild("a|r1,,r2", "a", "r1,r2", "a|r1,r2") {
        Do $ClassMethod(tRules, "EntryParts", $List(tCase, 1), .tAddress, .tRoles)
        Do $$$AssertEquals(tAddress _ " [" _ $ListToString(tRoles, ",") _ "]", $List(tCase, 2) _ " [" _ $List(tCase, 3) _ "]", $List(tCase, 1) _ " reads as its address and roles")
        Do $$$AssertEquals($ClassMethod(tRules, "Canonical", $List(tCase, 1)), $List(tCase, 4), $List(tCase, 1) _ " is spelled " _ $List(tCase, 4))
    }
}

/// <p>The vendor's own address check, which <parameter>OcuPilot.Api.ServiceError.ADDRESSINVALID</parameter>
/// refuses 1, 2 and 3 of, answers as measured: 0 for an address, a range, a wildcard, a host name
/// and IPv6; 1 for an address or range it cannot read; 2 for a malformed name; 4 for a name that does
/// not resolve, which the classic page accepts.</p>
Method TestTheVendorsAddressCheckAnswersAsMeasured()
{
    For tCase = $ListBuild("10.0.0.1", 0), $ListBuild("10.0.0.1-20", 0), $ListBuild("10.0.0.*", 0), $ListBuild("localhost", 0), $ListBuild("::1", 0), $ListBuild("fe80::1", 0), $ListBuild("999.1.1.1", 1), $ListBuild("10.0.0.0/24", 1), $ListBuild("a b", 2), $ListBuild("no-such-host.invalid", 4) {
        Set tSC = ##class(OcuPilot.Area.Permissions.ServiceRules).AddressValidity($List(tCase, 1), .tAnswer)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ " is checked")
        Do $$$AssertEquals(tAnswer, $List(tCase, 2), $List(tCase, 1) _ " answers " _ $List(tCase, 2))
    }
}

/// <p>AD-4, AD-10: an entry the agent writes in the classic <code>address:role</code> spelling is
/// sent as <code>address|role</code>, so the kernel reads its role and mints a <code>%All</code>
/// grant destructive with <code>GRANT.PRIVILEGED</code>; an entry the service already holds is sent
/// back exactly as read, beside a new one sent canonical.</p>
/// <p>Mutation (Rule 19): drop the canonical rewrite from
/// <method>OcuPilot.Screen.Tool.ServiceUpdate.MergeUpdate</method> -- the payload and destructive legs go
/// red.</p>
Method TestAClassicSpellingIsSentCanonicalAndMarkedPrivileged()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh(48, "[]", "false"))
    Set tKey = ..MintedKey({"Name": (..#PROBE), "ClientSystems": ["10.0.0.9:%All"]})
    Do $$$AssertNotEquals(tKey, "", "the classic spelling is minted")
    Do ..Stored(tKey, .tDestructive, .tConsequence, .tPayload)
    Do $$$AssertEquals($Select($IsObject(tPayload): tPayload.%Get("ClientSystems").%ToJSON(), 1: ""), "[""10.0.0.9|%All""]", "and its payload carries the canonical spelling")
    Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "1 " _ $Parameter("OcuPilot.Kernel.Proposal.Mint", "CONSEQUENCEPRIVILEGED"), "which the kernel reads as a privileged grant")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh(48, "[""10.0.0.6:%Manager""]", "false"))
    Set tKey = ..MintedKey({"Name": (..#PROBE), "ClientSystems": ["10.0.0.6:%Manager", "10.0.0.8:%Operator"]})
    Do ..Stored(tKey, .tDestructive, .tConsequence, .tPayload)
    Do $$$AssertEquals($Select($IsObject(tPayload): tPayload.%Get("ClientSystems").%ToJSON(), 1: ""), "[""10.0.0.6:%Manager"",""10.0.0.8|%Operator""]", "a held entry is sent as read and a new one canonical")
}

/// <p>AD-55, AC7: at the mint, an added address the vendor's check refuses, an address on a service
/// that checks none, and a role on a service that gives none are each refused by the published
/// sentence, judged against the held services <code>%Service_CacheDirect</code> and
/// <code>%Service_CallIn</code>, which are read and never written; nothing is written.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Permissions.ServiceRules.Validate</method> skip
/// the <code>ADDRESSUNSUPPORTED</code> rule -- the <code>%Service_CallIn</code> leg goes red.</p>
Method TestTheAddressRulesRefuseAtTheMint()
{
    Set tError = "OcuPilot.Api.ServiceError"
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh(32, "[]", "false"))
    For tCase = $ListBuild(..#CACHEDIRECT, "999.1.1.1", $Parameter(tError, "ADDRESSINVALID")), $ListBuild(..#CALLIN, "10.0.0.1", $Parameter(tError, "ADDRESSUNSUPPORTED")), $ListBuild(..#CACHEDIRECT, "10.0.0.5|%Operator", $Parameter(tError, "ADDRESSROLEUNSUPPORTED")) {
        Set tArgs = {"Name": ($List(tCase, 1)), "ClientSystems": [($List(tCase, 2))]}
        Set tSC = ..Mint(tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 400, tArgs.%ToJSON() _ " is refused at the mint")
        Do $$$AssertTrue(..Problem(.tFault) [ ("'ClientSystems': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 3))), tArgs.%ToJSON() _ ": on ClientSystems by " _ $List(tCase, 3) _ "'s sentence: " _ ..Problem(.tFault))
    }
    Set tKey = ..MintedKey({"Name": (..#CACHEDIRECT), "ClientSystems": ["10.0.0.1"]})
    Do $$$AssertNotEquals(tKey, "", "while a plain address on a service that checks addresses is minted")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing is written")
}

/// <p>DW-1016, AC8: an empty address list reads with the tool's declared word, on the changed row
/// the mint answers (<code>before</code> <code>""</code> with <code>emptyKey</code> for a restriction,
/// <code>after</code> <code>""</code> for its removal) and on an unchanged row under the disclosure
/// (<code>{value: "", emptyKey}</code>); a field the tool does not declare carries no key.</p>
/// <p>Mutation (Rule 19): make the mint's <code>ApplyEmptyKeys</code> skip the key -- the changed-row
/// leg goes red. Make it rewrite only <code>before</code> -- the removal leg goes red.</p>
Method TestAnEmptyAddressListReadsUnrestricted()
{
    Set tKey = "serviceAllowedUnrestricted"
    Do $$$AssertEquals($Parameter(..#UPDATE, "EMPTYKEYS"), "ClientSystems=" _ tKey, "the tool declares its word for an empty address list")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh(48, "[]", "false"))
    Set tSC = ..Mint({"Name": (..#PROBE), "ClientSystems": ["10.0.0.1"]}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a restriction is minted: " _ ..Problem(.tFault))
    If '$IsObject($Get(tProposal)) Quit
    Set tRow = tProposal.%Get("changed").%Get(0)
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("field") _ " [" _ tRow.%Get("before") _ "] " _ tRow.%Get("after") _ " " _ tRow.%Get("emptyKey"), 1: ""), "ClientSystems [] [""10.0.0.1""] " _ tKey, "the changed row's empty before reads the tool's word")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh(48, "[""10.0.0.1""]", "false"))
    Set tSC = ..Mint({"Name": (..#PROBE), "ClientSystems": []}, .tProposal, .tHttp, .tFault)
    Set tRow = $Select($IsObject($Get(tProposal)): tProposal.%Get("changed").%Get(0), 1: "")
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("before") _ " [" _ tRow.%Get("after") _ "] " _ tRow.%Get("emptyKey"), 1: ""), "[""10.0.0.1""] [] " _ tKey, "and a removed restriction's empty after reads it too: " _ ..Problem(.tFault))
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Fresh(48, "[]", "false"))
    Set tKey2 = ..MintedKey({"Name": (..#PROBE), "Enabled": true})
    Do ..Stored(tKey2, .tDestructive, .tConsequence, .tPayload, .tDiff)
    Set tRows = ##class(OcuPilot.Kernel.Proposal.Disclosure).Rows($Parameter(..#UPDATE, "TOOLNAME"), $Select($IsObject(tPayload): tPayload.%ToJSON(), 1: ""), tDiff)
    Set (tAddresses, tMethods) = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tUnchanged) {
        If tUnchanged.%Get("field") = "ClientSystems" Set tAddresses = "[" _ tUnchanged.%Get("value") _ "] " _ tUnchanged.%Get("emptyKey")
        If tUnchanged.%Get("field") = "AutheEnabled" Set tMethods = tUnchanged.%Get("value") _ " " _ tUnchanged.%GetTypeOf("emptyKey")
    }
    Do $$$AssertEquals(tAddresses, "[] " _ tKey, "an unchanged empty list reads the same word under the disclosure")
    Do $$$AssertEquals(tMethods, "48 unassigned", "and a field the tool does not declare carries no key")
}

/// <p>AD-8, AD-44: the tool's pairs are the Services list's, with the custom resource of the classic
/// Edit Service dialog it performs unioned through <method>OcuPilot.Screen.Gate.WithClassicPages</method>.</p>
Method TestThePairsUnionTheClassicDialogsResource()
{
    Do $$$AssertEquals($Parameter(..#UPDATE, "CLASSICPAGES"), ..#DIALOG, "the tool declares the Edit Service dialog")
    Set tList = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#LIST, .tResolved)
    Do $$$AssertTrue(tResolved, "the list's pairs resolve")
    Set tPairs = $ClassMethod(..#UPDATE, "PrivilegePairs", "", .tToolResolved)
    Do $$$AssertTrue(tToolResolved && (tPairs = ##class(OcuPilot.Screen.Gate).WithClassicPages(tList, ..#DIALOG)), "its pairs are the list's with the dialog's custom resource")
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

/// <p>Proposal <var>pKey</var>'s stored destructive flag, consequence, payload and diff.</p>
ClassMethod Stored(pKey As %String, Output pDestructive As %Boolean, Output pConsequence As %String, Output pPayload As %DynamicObject, Output pDiff As %String)
{
    Set pDestructive = ""
    Set pConsequence = "<absent>"
    Set pPayload = ""
    Set pDiff = ""
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pKey, .tFound, .tValues)
    If $$$ISERR(tSC) || '$Get(tFound) Quit
    Set pDestructive = +$Get(tValues("destructive"))
    Set pConsequence = $Get(tValues("consequence"))
    Set pDiff = $Get(tValues("diff"))
    If $Get(tValues("payload")) '= "" Set pPayload = ##class(%DynamicObject).%FromJSON(tValues("payload"))
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
