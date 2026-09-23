/// <p>Pins Story 8.3's role create (AD-3, AD-10, AD-39, AD-54, AD-55): what
/// <class>OcuPilot.Screen.Tool.RoleCreate</class> advertises, the one rule set both callers apply,
/// a privileged grant permitted on both callers and marked destructive on the agent's, the one body
/// the screen and the confirm send, the bootstrap's privileged marks, and the marked confirm.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and its protected state
/// readable. Every write goes to <class>OcuPilot.Test.ProposalFixture</class>, so nothing here
/// creates a role; the name-taken read and the prohibited set's absence read are live, so
/// <parameter>PROBEROLE</parameter> must be a name the instance does not hold. No arming variable
/// is required.</p>
Include %sySecurity

Class OcuPilot.Test.RoleCreate Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.RoleCreate";

Parameter LIST = "OcuPilot.Screen.Descriptor.RoleList";

Parameter FORM = "OcuPilot.Screen.Descriptor.RoleForm";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter RULES = "OcuPilot.Area.Permissions.RoleCreateRules";

/// <p>The shipped screen route with only its port replaced.</p>
Parameter SCREEN = "OcuPilot.Test.RoleCreateFixture";

/// <p>The shipped mint and confirm with the port replaced.</p>
Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The name every create here proposes; nothing on the instance holds it.</p>
Parameter PROBEROLE = "OcuPilotProbeRoleCreate";

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

/// <p>AD-3 and AD-10: the schema carries no <code>EscalationOnly</code>, offers the resource grants
/// as <code>{Name, Permissions}</code> objects, and the tool's settable set equals the prohibited
/// set's reviewed create list for a role.</p>
/// <p>Mutation: add <code>EscalationOnly</code> to
/// <parameter>OcuPilot.Screen.Tool.RoleCreate.PERMITTEDFIELDS</parameter> -> the schema and set
/// assertions go red.</p>
Method TestTheSchemaCarriesNoEscalationOnlyAndThePermittedSetIsTheSets()
{
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertEquals(tProperties.%GetTypeOf("EscalationOnly"), "unassigned", "the schema never offers escalation-only")
    Do $$$AssertEquals(tProperties.%GetTypeOf("GrantedRoles"), "object", "it offers the granted roles")
    Do $$$AssertEquals(tProperties.%GetTypeOf("Resources"), "object", "and the resource grants")
    If tProperties.%GetTypeOf("Resources") = "object" {
        Set tItems = tProperties.%Get("Resources").%Get("items")
        Do $$$AssertEquals($Select($IsObject(tItems): tItems.%Get("type"), 1: ""), "object", "each grant an object")
    }
    Do $$$AssertEquals(tSchema.%Get("additionalProperties"), 0, "closed to everything else")
    Do $$$AssertEquals(..Sorted($ClassMethod(..#TOOL, "SettableFields")), ..Sorted($ClassMethod(..#SET, "PermittedCreateFields", "role")), "the settable set is the prohibited set's reviewed create list")
    Do $$$AssertEquals($ClassMethod(..#SET, "AlwaysProhibitedCreateFields", "role"), "", "and no create field is prohibited by name")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "WriteType"), "PUT", "the create is the vendor's upsert PUT")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Creates"), 1, "guarded as a create (AD-54)")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).EmitSchema(tSchema, .tEmitted, .tProblem)
    Do $$$AssertEquals(tProblem, "", "and the schema is one a provider request can carry")
}

/// <p>AD-55: every field rule refuses on the screen route and at the agent's mint alike, on the
/// field it names; the name look-up and the required name are the screen's alone.</p>
/// <p>Mutations: drop the duplicate check from
/// <method>OcuPilot.Area.Permissions.RoleCreateRules.ResourceViolation</method> -> the duplicate
/// case goes red on both callers; drop its write-only check -> case 14 goes red on both.</p>
Method TestEveryFieldRuleRefusesOnBothCallers()
{
    For tCase = 1:1:14 {
        Set tName = ..#PROBEROLE
        Set tArgs = ..Args()
        If tCase = 1 Set tName = $Translate($Justify("", 65), " ", "r"), tField = "Name", tCode = "ROLENAMELENGTH"
        If tCase = 2 Set tName = "probe,role", tField = "Name", tCode = "ROLENAMESHAPE"
        If tCase = 3 Set tName = "probe" _ $Char(1), tField = "Name", tCode = "ROLENAMESHAPE"
        If tCase = 4 Set tName = "%OcuPilotProbe", tField = "Name", tCode = "ROLENAMESYSTEM"
        If tCase = 5 Do tArgs.%Set("Description", $Translate($Justify("", 257), " ", "d"), "string") Set tField = "Description", tCode = "ROLEDESCRIPTIONLENGTH"
        If tCase = 6 Do tArgs.%Set("Resources", "%DB_USER:RW", "string") Set tField = "Resources", tCode = "ROLERESOURCESSHAPE"
        If tCase = 7 Do tArgs.%Set("Resources", [{"Name": "%DB_USER"}]) Set tField = "Resources", tCode = "ROLERESOURCESSHAPE"
        If tCase = 8 Do tArgs.%Set("Resources", [{"Name": "OcuPilotNoSuchResource", "Permissions": "R"}]) Set tField = "Resources", tCode = "ROLERESOURCESUNKNOWN"
        If tCase = 9 Do tArgs.%Set("Resources", [{"Name": "%DB_USER", "Permissions": "U"}]) Set tField = "Resources", tCode = "ROLERESOURCESPERMISSIONS"
        If tCase = 10 Do tArgs.%Set("Resources", [{"Name": "%DB_USER", "Permissions": "R"}, {"Name": "%db_user", "Permissions": "RW"}]) Set tField = "Resources", tCode = "ROLERESOURCESDUPLICATE"
        If tCase = 11 Do tArgs.%Set("GrantedRoles", ["OcuPilotNoSuchRole"]) Set tField = "GrantedRoles", tCode = "ROLEGRANTEDROLESUNKNOWN"
        If tCase = 12 Do tArgs.%Set("GrantedRoles", "%Developer", "string") Set tField = "GrantedRoles", tCode = "ROLEGRANTEDROLESSHAPE"
        If tCase = 13 Do tArgs.%Set("Resources", [{"Name": "%DB_USER", "Permissions": "RW", "EscalationOnly": true}]) Set tField = "Resources", tCode = "ROLERESOURCESSHAPE"
        ; DW-1514: Write on a database carries Read, as the classic dialog's writeChanged ties them.
        If tCase = 14 Do tArgs.%Set("Resources", [{"Name": "%DB_USER", "Permissions": "W"}]) Set tField = "Resources", tCode = "ROLERESOURCESWRITEONLY"
        Set tExpected = $Parameter("OcuPilot.Api.Error", tCode)

        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Set tSC = $ClassMethod(..#SCREEN, "Perform", tName, tArgs, .tCreated, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(..CodeFor(.tViolations, tField), tExpected, "case " _ tCase _ ": the screen refuses on " _ tField)
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "case " _ tCase _ ": and nothing reaches the port")

        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
        Set tSC = ..Mint(tName, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, "case " _ tCase _ ": the agent's mint refuses it too")
        Do $$$AssertEquals(tHttp, 400, "case " _ tCase _ ": at 400")
        Set tProblem = ..Problem(tFault)
        Do $$$AssertTrue(tProblem [ ##class(OcuPilot.Api.Error).ReasonForViolation(tExpected), "case " _ tCase _ ": with the same sentence: " _ tProblem)
    }

    ; The screen's alone: an empty name, and a name taken in another case.
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#SCREEN, "Perform", "", ..Args(), .tCreated, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(..CodeFor(.tViolations, "Name"), ##class(OcuPilot.Api.Error).#ROLENAMEREQUIRED, "an empty name is refused on the name field")
    Set tTaken = $ZConvert(##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE, "L")
    Set tSC = $ClassMethod(..#SCREEN, "Perform", tTaken, ..Args(), .tCreated, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(..CodeFor(.tViolations, "Name"), ##class(OcuPilot.Api.Error).#ROLENAMETAKEN, "a role held in another case is refused as taken")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing reaches the port")
}

/// <p>AD-55: the screen's Save and the agent's confirm send one body from the same arguments, at the
/// tool's own <code>PUT</code>, with the name only as the query parameter.</p>
/// <p>Mutation: replace <code>$ClassMethod(tClass, "SettableFields")</code> in
/// <method>OcuPilot.Area.Permissions.RoleCreate.Perform</method> with a list missing
/// <code>Resources</code> -> the bodies differ and this goes red.</p>
Method TestTheScreenAndTheConfirmSendOneBody()
{
    Set tArgs = ..Args()
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#SCREEN, "Perform", ..#PROBEROLE, tArgs, .tCreated, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the screen accepts the create")
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Set tScreenBody = ##class(OcuPilot.Test.ProposalFixture).LastWriteBody()
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "PUT", "at the tool's own write type")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("name"), ..#PROBEROLE, "naming the role in the query parameter")

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#PROBEROLE, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent mints the same create")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "with nothing unchanged")
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 3, "and one diff row per supplied field")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and its confirm applies it")
    Set tAgentBody = ##class(OcuPilot.Test.ProposalFixture).LastWriteBody()

    Do $$$AssertNotEquals(tScreenBody, "", "a body reached the port from the screen")
    Do $$$AssertEquals(tScreenBody, tAgentBody, "the screen's Save and the agent's confirm send the identical body")
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tScreenBody)
    Do $$$AssertEquals(tBody.%Get("Resources").%ToJSON(), tArgs.%Get("Resources").%ToJSON(), "carrying the grants in the vendor's own shape")
    Do $$$AssertEquals(tBody.%Get("GrantedRoles").%ToJSON(), "[""%Developer""]", "the granted roles")
    Do $$$AssertEquals(tBody.%GetTypeOf("Name"), "unassigned", "and never the name, which the vendor refuses in the body")
    Do $$$AssertEquals(tBody.%GetTypeOf("EscalationOnly"), "unassigned", "nor escalation-only")
}

/// <p>AD-10 on both callers: a resource grant of an <code>%Admin_*</code> resource and a granted
/// role that grants <code>%All</code> or an administrative privilege are granted, not refused. The
/// screen's Save reaches the port with each; the agent's proposal is minted <b>destructive</b> with
/// the privilege-grant consequence and its confirm applies it. An ordinary grant -- write on
/// <code>%DB_IRISSECURITY</code>, and its implicit role, among them -- is neither.</p>
/// <p>Mutations: drop <code>tPrivileged</code> from the destructive value in
/// <method>OcuPilot.Kernel.Proposal.Mint.Mint</method> -> the destructive legs go red; make
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ResourcesEscalate</method> answer 0 -> the resource
/// cases go red.</p>
Method TestAPrivilegedGrantIsGrantedAtTheStrongestConfirmationOnBothCallers()
{
    Set tPrivilegedCode = $Parameter("OcuPilot.Kernel.Proposal.Mint", "CONSEQUENCEPRIVILEGED")
    For tCase = 1:1:7 {
        Set tArgs = ..Args()
        Set tPrivileged = 1
        If tCase = 1 Do tArgs.%Set("Resources", [{"Name": "%Admin_Secure", "Permissions": "U"}]) Set tField = "Resources"
        If tCase = 2 Do tArgs.%Set("Resources", [{"Name": "%DB_USER", "Permissions": "RW"}, {"Name": "%Admin_Operate", "Permissions": "U"}]) Set tField = "Resources"
        If tCase = 3 Do tArgs.%Set("GrantedRoles", ["%Manager"]) Set tField = "GrantedRoles"
        If tCase = 4 Do tArgs.%Set("GrantedRoles", ["%All"]) Set tField = "GrantedRoles"
        If tCase = 5 Do tArgs.%Set("Resources", [{"Name": "%DB_IRISSECURITY", "Permissions": "RW"}]) Set tField = "Resources", tPrivileged = 0
        If tCase = 6 Do tArgs.%Set("GrantedRoles", ["%DB_IRISSECURITY"]) Set tField = "GrantedRoles", tPrivileged = 0
        If tCase = 7 Set tField = "Resources", tPrivileged = 0
        Set tLabel = "case " _ tCase _ " (" _ tField _ ")"

        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Set tSC = $ClassMethod(..#SCREEN, "Perform", ..#PROBEROLE, tArgs, .tCreated, .tHttp, .tFault, .tViolations)
        Do $$$AssertStatusOK(tSC, tLabel _ ": the screen's Save is accepted")
        Do $$$AssertEquals(+$Get(tViolations), 0, tLabel _ ": with no violation")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, tLabel _ ": and the create reaches the port")

        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
        Set tSC = ..Mint(..#PROBEROLE, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tLabel _ ": the agent's mint proposes it")
        If $$$ISERR(tSC) Continue
        Do ..Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
        Do $$$AssertEquals(tDestructive, tPrivileged, tLabel _ ": the proposal is destructive exactly when the grant is privileged")
        Do $$$AssertEquals(tConsequence, $Select(tPrivileged: tPrivilegedCode, 1: ""), tLabel _ ": and names the privilege as its consequence")
        Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
        Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
        Do $$$AssertStatusOK(tSC, tLabel _ ": and its confirm applies it")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, tLabel _ ": at the port")
    }

    ; A seeded row the shipped mint cannot produce: an escalation-only flag, refused inside the
    ; transition as a field nobody reviewed.
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = ..SeedAndConfirm({"Description": "probe", "EscalationOnly": true}, .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ $Parameter(..#SET, "UNCOVEREDFIELD"), "a seeded escalation-only flag is refused as a field nobody reviewed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "with no write")

    ; The screen asks the set about the caller's own fields, so the flag is refused there too rather
    ; than dropped by the composition.
    Set tArgs = ..Args()
    Do tArgs.%Set("EscalationOnly", 1, "boolean")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#SCREEN, "Perform", ..#PROBEROLE, tArgs, .tCreated, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "403 " _ $Parameter(..#SET, "UNCOVEREDFIELD"), "the screen refuses an escalation-only flag as a field nobody reviewed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing reaches the port")
}

/// <p>AD-10, AD-39: the bootstrap's resource list carries each resource's admissible letters and
/// marks, from the prohibited set's classifier, the grants that grant <code>%All</code> or an
/// administrative privilege; the role list is 8.2's. The client holds no copy of either rule.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Proposal.Prohibited.ResourceGrantsAdministrativePrivilege</method>
/// answer 0 -> the <code>%Admin_Secure</code> mark goes red.</p>
Method TestTheBootstrapMarksWhatTheClassifierCallsPrivileged()
{
    Set tSC = $ClassMethod(..#RULES, "Resources", .tResources)
    Do $$$AssertStatusOK(tSC, "the resources are listed through the tool's port")
    If $$$ISERR(tSC) Quit
    Kill tByName
    Set tIterator = tResources.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tByName($ZConvert(tEntry.%Get("name"), "U")) = tEntry
    }
    Set tSecure = $Get(tByName("%ADMIN_SECURE"))
    Set tUser = $Get(tByName("%DB_USER"))
    Set tSecurity = $Get(tByName("%DB_IRISSECURITY"))
    Do $$$AssertTrue($IsObject(tSecure) && $IsObject(tUser) && $IsObject(tSecurity), "the three probe resources are listed")
    If '($IsObject(tSecure) && $IsObject(tUser) && $IsObject(tSecurity)) Quit
    Do $$$AssertEquals(tSecure.%Get("privileged"), 1, "%Admin_Secure is marked privileged")
    Do $$$AssertEquals(tSecure.%Get("permissions"), "U", "and admits Use alone")
    Do $$$AssertEquals(tUser.%Get("privileged"), 0, "%DB_USER is not")
    Do $$$AssertEquals(tUser.%Get("permissions"), "RW", "and admits read and write")
    Do $$$AssertEquals(tSecurity.%Get("privileged"), 0, "nor is %DB_IRISSECURITY, at any permission")
    Do $$$AssertEquals(tSecurity.%GetTypeOf("privilegedPermissions"), "unassigned", "and no entry marks a letter")
    Do $$$AssertEquals($ClassMethod(..#RULES, "AdmissiblePermissions", "OcuPilotAdmin"), "RWU", "a resource with no system prefix admits all three letters")

    Set tSC = ##class(OcuPilot.Area.Permissions.UserCreateRules).Roles(.tRoles)
    Do $$$AssertStatusOK(tSC, "the roles are listed")
    Kill tRoleByName
    Set tIterator = tRoles.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tRoleByName($ZConvert(tEntry.%Get("name"), "U")) = tEntry.%Get("privileged")
    }
    Do $$$AssertEquals($Get(tRoleByName("%MANAGER")), 1, "%Manager is marked privileged")
    Do $$$AssertEquals($Get(tRoleByName("%DEVELOPER")), 0, "%Developer is not")
    Do $$$AssertEquals($Get(tRoleByName("%DB_IRISSECURITY")), 0, "nor is the %DB_IRISSECURITY role")
}

/// <p>The admitted letters follow the classic grant dialog's own rule:
/// <parameter>OcuPilot.Area.Permissions.RoleCreateRules.USEONLYPREFIXES</parameter> is, in order,
/// the prefixes <code>%CSP.UI.Portal.Dialog.RoleResourceEdit</code> offers Use alone for, and
/// <parameter>OcuPilot.Area.Permissions.RoleCreateRules.DATABASEPREFIX</parameter> its database
/// prefix, each read from <file>%sySecurity.inc</file> as the running build compiles it.</p>
/// <p>Mutation: drop <code>%SQL</code> from
/// <parameter>OcuPilot.Area.Permissions.RoleCreateRules.USEONLYPREFIXES</parameter> -> this goes red.</p>
Method TestTheAdmittedLettersFollowTheVendorsPrefixes()
{
    Set tVendor = $$$ServiceResourcePrefix _ "," _ $$$DeepSeeResourcePrefix _ "," _ $$$AdminResourcePrefix _ "," _ $$$DeveloperResourcePrefix _ "," _ $$$ApplicationResourcePrefix _ "," _ $$$SystemResourcePrefix _ "," _ $$$DocDBResourcePrefix _ "," _ $$$GatewayResourcePrefix _ "," _ $$$IAMResourcePrefix _ "," _ $$$NativeResourcePrefix _ "," _ $$$SQLResourcePrefix _ "," _ $$$SecureShellResourcePrefix
    Do $$$AssertEquals($Parameter(..#RULES, "USEONLYPREFIXES"), tVendor, "the Use-only prefixes are the classic dialog's, in its order")
    Do $$$AssertEquals($Parameter(..#RULES, "DATABASEPREFIX"), $$$DBResourcePrefix, "and the database prefix is the vendor's")
}

/// <p>AD-15, AD-41, AD-14: a confirmed create is marked, its ledger row names the sent fields, and
/// the answer carries the <code>created</code> action.</p>
/// <p>Mutation: set <parameter>OcuPilot.Screen.Tool.RoleCreate.CREATES</parameter> to 0 -> the mint
/// refuses the absent target and this goes red.</p>
Method TestAConfirmedCreateIsMarkedAndAnswersCreated()
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#PROBEROLE, ..Args(), .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the create is minted")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and confirmed")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "created", "the answer carries the created action")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent marker landed on it")
    Set tFields = $ListFromString($Get(tRow("Fields")))
    For tField = "Description", "GrantedRoles", "Resources" {
        Do $$$AssertTrue($ListFind(tFields, tField), "the ledger names " _ tField _ ": " _ $Get(tRow("Fields")))
    }
}

/// <p>AD-54 over a role: a name the instance already holds refuses the agent's mint at 400
/// <code>TOOL.ARGUMENTS</code>, and a name taken between the mint and the confirm refuses the
/// confirm at 409 <code>PROPOSAL.TARGETCHANGED</code> with nothing sent to the vendor's upsert.</p>
/// <p>Mutation: set <parameter>OcuPilot.Screen.Tool.RoleCreate.CREATES</parameter> to 0 -> the
/// present name is minted and this goes red.</p>
Method TestATakenNameRefusesTheMintAndAConfirmTakenSince()
{
    Set tPresent = "{""Description"":""held by somebody else""}"
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tPresent)
    Set tSC = ..Mint(..#PROBEROLE, ..Args(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a create whose name the instance already holds is refused at the mint")
    Do $$$AssertEquals(tHttp, 400, "at 400")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "with the arguments code")

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#PROBEROLE, ..Args(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a create whose name is free is minted")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tPresent)
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "a confirm whose name was taken since the mint is refused")
    Do $$$AssertEquals(tHttp, 409, "at 409")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "as the target having changed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and the vendor's upsert is never reached")
}

/// <p>AD-39: every <code>ROLE.*</code> field code carries a written sentence, and the form's
/// bootstrap rules carry exactly those sentences.</p>
/// <p>Mutation: add a code to <method>OcuPilot.Api.Error.RoleViolationCodes</method> with no row in
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> -> this goes red naming it.</p>
Method TestEveryRoleFieldCodeCarriesItsOwnSentence()
{
    Set tCodes = ##class(OcuPilot.Api.Error).RoleViolationCodes()
    Do $$$AssertTrue($ListLength(tCodes) > 0, "the story publishes role field codes")
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, tI)), "", $List(tCodes, tI) _ " carries a written sentence")
    }
    Set tRules = $ClassMethod(..#RULES, "Rules")
    Do $$$AssertEquals(tRules.%Size(), $ListLength(tCodes), "and the bootstrap publishes one rule per code")
    Set tIterator = tRules.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRule) {
        Do $$$AssertNotEquals(tRule.%Get("field"), "", tRule.%Get("code") _ " names its field")
        Do $$$AssertEquals(tRule.%Get("reason"), ##class(OcuPilot.Api.Error).ReasonForViolation(tRule.%Get("code")), "the rule on " _ tRule.%Get("field") _ " carries the server's sentence")
    }
}

/// <p>The Role form is built, unlisted and gated by the list's own pairs; the list is write-capable
/// with Create as its primary action and invites the agent when empty (AD-5, AD-8).</p>
/// <p>Mutation: give the form a non-zero <code>sideBarPosition</code> -> the unlisted assertion goes
/// red.</p>
Method TestTheFormDescriptorIsBuiltUnlistedAndCarriesTheListsOwnPairs()
{
    Set tForm = ..#FORM
    Do $$$AssertEquals($ClassMethod(tForm, "Route"), $ClassMethod(..#LIST, "Route") _ "/edit", "the form's route is the list's own with the editor suffix")
    Do $$$AssertEquals(''$ClassMethod(tForm, "IsBuilt"), 1, "it is built")
    Do $$$AssertEquals(+$ClassMethod(tForm, "SideBarPosition"), 0, "and unlisted")
    Do $$$AssertEquals($ClassMethod(tForm, "Archetype"), "form-page", "it is a form page")
    Do $$$AssertEquals($ClassMethod(tForm, "PrimaryEntityType"), "role", "over the role entity type")
    Do $$$AssertEquals($ClassMethod(tForm, "ToolIdentifier"), "permissions.roleform", "with its own tool identifier")
    Do $$$AssertEquals($ListToString($ClassMethod(tForm, "PrivilegePairs")), $ListToString($ClassMethod(..#LIST, "PrivilegePairs")), "the form requires exactly what the list requires")
    Do $$$AssertEquals($Parameter("OcuPilot.Area.Permissions.RoleCreate", "DESCRIPTORCLASS"), tForm, "and the create route gates on the form's declaration")
    Set tSC = $ClassMethod(..#LIST, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the list's declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tDeclaration.%Get("primaryAction").%Get("id"), "create", "the list declares Create as its primary action")
    Do $$$AssertEquals(tDeclaration.%Get("table").%Get("emptyNextKey"), "", "so its empty state names no next step")
    Do $$$AssertEquals(tDeclaration.%Get("table").%Get("emptyAgentKey"), "roleListEmptyAgent", "and invites the agent instead")
}

/// <p>The arguments every create here proposes.</p>
ClassMethod Args() As %DynamicObject
{
    Set tArgs = {}
    Do tArgs.%Set("Description", "OcuPilot create probe", "string")
    Do tArgs.%Set("Resources", [{"Name": "%DB_USER", "Permissions": "RW"}])
    Do tArgs.%Set("GrantedRoles", ["%Developer"])
    Quit tArgs
}

/// <p>The stored proposal <var>pKey</var>'s destructive marking and consequence code.</p>
ClassMethod Stored(pKey As %String, Output pDestructive As %Boolean, Output pConsequence As %String)
{
    Set pDestructive = ""
    Set pConsequence = "<absent>"
    Set tSC = $ClassMethod("OcuPilot.Kernel.State.Propose", "GuardedByKey", pKey, .tFound, .tValues)
    If $$$ISERR(tSC) || '$Get(tFound) Quit
    Set pDestructive = +$Get(tValues("destructive"))
    Set pConsequence = $Get(tValues("consequence"))
}

/// <p>The canonical reference of <parameter>PROBEROLE</parameter>.</p>
ClassMethod TargetRef() As %String
{
    Do ##class(OcuPilot.Kernel.EntityRef).Key("role", "instance", ..#PROBEROLE, .tRef)
    Quit $Get(tRef)
}

/// <p>Seed one create proposal carrying <var>pPayload</var> under the absence fingerprint, and
/// confirm it through the shipped transition.</p>
Method SeedAndConfirm(pPayload As %DynamicObject, Output pHttp As %Integer, Output pCode As %String) As %Status
{
    Set pHttp = 0
    Set pCode = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(##class(OcuPilot.Kernel.Proposal.Mint).AbsenceState(0), "", .tFingerprint)
    If $$$ISERR(tSC) Quit tSC
    Kill tValues
    Set tValues("user") = $Username
    Set tValues("turnKey") = tTurnKey
    Set tValues("toolName") = $Parameter(..#TOOL, "TOOLNAME")
    Set tValues("targetRef") = ..TargetRef()
    Set tValues("fingerprint") = tFingerprint
    Set tValues("arguments") = pPayload.%ToJSON()
    Set tValues("payload") = pPayload.%ToJSON()
    Set tValues("diff") = "[]"
    Set tValues("unchangedCount") = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Quit ..Confirm(tKey, .pHttp, .pCode, .tResult)
}

/// <p>Mint one create of <var>pName</var> through the fixture mint, as
/// <method>OcuPilot.Screen.Tool.Write.View</method> would.</p>
Method Mint(pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pTurnKey As %String) As %Status
{
    Set pTurnKey = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#MINT, "Mint", ..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", pTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pName, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

/// <p>Confirm <var>pKey</var> through the shipped transition.</p>
Method Confirm(pKey As %String, Output pHttp As %Integer, Output pCode As %String, Output pResult As %DynamicObject) As %Status
{
    Set pResult = ""
    Quit $ClassMethod(..#CONFIRM, "Confirm", pKey, "", $Username, .pResult, .pHttp, .pCode, .tDetail)
}

/// <p>The problem a 400 <code>TOOL.ARGUMENTS</code> refusal carries, or <code>""</code>.</p>
ClassMethod Problem(pFault As %DynamicObject) As %String
{
    If '$IsObject(pFault) Quit ""
    If '$IsObject(pFault.%Get("detail")) Quit ""
    Quit pFault.%Get("detail").%Get("problem")
}

/// <p>The code <var>pViolations</var> carries for <var>pField</var>, or <code>""</code>.</p>
ClassMethod CodeFor(ByRef pViolations, pField As %String) As %String
{
    Set tCode = ""
    For tI = 1:1:+$Get(pViolations) {
        If $List(pViolations(tI), 1) = pField Set tCode = $List(pViolations(tI), 2) Quit
    }
    Quit tCode
}

/// <p><var>pList</var> sorted, as a comma-separated string.</p>
ClassMethod Sorted(pList As %List) As %String
{
    Kill tSeen
    For tI = 1:1:$ListLength(pList) Set tSeen($List(pList, tI)) = ""
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSeen(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

}
