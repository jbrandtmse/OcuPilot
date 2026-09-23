/// <p>Pins Story 8.4's resource create (AD-3, AD-10, AD-39, AD-54, AD-55): what
/// <class>OcuPilot.Screen.Tool.ResourceCreate</class> advertises, the one rule set both callers apply,
/// the one body the screen and the confirm send, a privileged public permission permitted on both
/// callers and marked on the agent's, OcuPilot's own resources refused on both, the marked confirm,
/// the absence fingerprint, the published sentences and letter rules, and the list's declaration.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and its protected state
/// readable. Every write goes to <class>OcuPilot.Test.ProposalFixture</class>, so nothing here
/// creates a resource; the name-taken read and the prohibited set's target read are live, so the
/// probe names must be ones the instance does not hold. No arming variable is required.</p>
Class OcuPilot.Test.ResourceCreate Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.ResourceCreate";

Parameter LIST = "OcuPilot.Screen.Descriptor.ResourceList";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter RULES = "OcuPilot.Area.Permissions.ResourceRules";

/// <p>The shipped screen route with only its port replaced.</p>
Parameter SCREEN = "OcuPilot.Test.ResourceFixture";

/// <p>The shipped mint and confirm with the port replaced.</p>
Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The names the creates here propose; nothing on the instance holds them.</p>
Parameter PROBE = "OcuPilotProbeResourceCreate";

Parameter PRIVILEGEDPROBE = "%Admin_OcuPilotProbe";

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

/// <p>AD-3 and AD-10: the schema offers exactly the description and the public permission, both
/// required because the vendor's create requires both, and the settable set equals the prohibited
/// set's reviewed create list for a resource.</p>
/// <p>Mutation: drop the required fields from
/// <method>OcuPilot.Screen.Tool.ResourceUpdate.Described</method> -> the required assertion goes
/// red.</p>
Method TestTheSchemaAndTheSettableSetAreTheSets()
{
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertEquals(tProperties.%GetTypeOf("Description"), "object", "the schema offers the description")
    Do $$$AssertEquals(tProperties.%GetTypeOf("PublicPermission"), "object", "and the public permission")
    Do $$$AssertEquals(tProperties.%GetTypeOf("Type"), "unassigned", "and never a type")
    Do $$$AssertEquals(tSchema.%Get("required").%ToJSON(), "[""Name"",""Description"",""PublicPermission""]", "all three are required, as the vendor's create requires them")
    Do $$$AssertEquals(tSchema.%Get("additionalProperties"), 0, "closed to everything else")
    Do $$$AssertEquals(..Sorted($ClassMethod(..#TOOL, "SettableFields")), ..Sorted($ClassMethod(..#SET, "PermittedCreateFields", "resource")), "the settable set is the prohibited set's reviewed create list")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "WriteType"), "PUT", "the create is the vendor's upsert PUT")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Creates"), 1, "guarded as a create (AD-54)")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "ChangeAction"), "created", "publishing the created action")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).EmitSchema(tSchema, .tEmitted, .tProblem)
    Do $$$AssertEquals(tProblem, "", "and the schema is one a provider request can carry")
}

/// <p>AD-55: every field rule refuses on the screen route and at the agent's mint alike, on the
/// field it names; the name look-up and the required name are the screen's alone.</p>
/// <p>Mutations: drop the repeated-letter test from
/// <method>OcuPilot.Area.Permissions.ResourceRules.Validate</method> -> case 6 goes red on both
/// callers; drop its admitted-letters test -> cases 8 and 9 go red on both.</p>
Method TestEveryFieldRuleRefusesOnBothCallers()
{
    For tCase = 1:1:9 {
        Set tName = ..#PROBE
        Set tArgs = ..Args()
        If tCase = 1 Set tName = $Translate($Justify("", 65), " ", "r"), tField = "Name", tCode = "RESOURCENAMELENGTH"
        If tCase = 2 Set tName = "probe,resource", tField = "Name", tCode = "RESOURCENAMESHAPE"
        If tCase = 3 Set tName = "probe" _ $Char(1), tField = "Name", tCode = "RESOURCENAMESHAPE"
        If tCase = 4 Do tArgs.%Set("Description", $Translate($Justify("", 257), " ", "d"), "string") Set tField = "Description", tCode = "RESOURCEDESCRIPTIONLENGTH"
        If tCase = 5 Do tArgs.%Set("PublicPermission", "RX", "string") Set tField = "PublicPermission", tCode = "RESOURCEPUBLICPERMISSIONSHAPE"
        If tCase = 6 Do tArgs.%Set("PublicPermission", "RR", "string") Set tField = "PublicPermission", tCode = "RESOURCEPUBLICPERMISSIONSHAPE"
        If tCase = 7 Do tArgs.%Set("PublicPermission", 1, "number") Set tField = "PublicPermission", tCode = "RESOURCEPUBLICPERMISSIONSHAPE"
        If tCase = 8 Set tName = "%DB_OcuPilotProbe" Do tArgs.%Set("PublicPermission", "RU", "string") Set tField = "PublicPermission", tCode = "RESOURCEPUBLICPERMISSIONLETTERS"
        If tCase = 9 Set tName = "%Service_OcuPilotProbe" Do tArgs.%Set("PublicPermission", "R", "string") Set tField = "PublicPermission", tCode = "RESOURCEPUBLICPERMISSIONLETTERS"
        Set tExpected = $Parameter("OcuPilot.Api.Error", tCode)

        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Set tSC = $ClassMethod(..#SCREEN, "Create", tName, tArgs, .tHttp, .tFault, .tViolations)
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

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#SCREEN, "Create", "", ..Args(), .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(..CodeFor(.tViolations, "Name"), ##class(OcuPilot.Api.Error).#RESOURCENAMEREQUIRED, "an empty name is refused on the name field")
    Set tSC = $ClassMethod(..#SCREEN, "Create", "%db_user", ..Args(), .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(..CodeFor(.tViolations, "Name"), ##class(OcuPilot.Api.Error).#RESOURCENAMETAKEN, "a resource held in another case is refused as taken")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing reaches the port")
}

/// <p>AD-55: the screen's Save and the agent's confirm send one body from the same arguments, at the
/// tool's own <code>PUT</code>, with the name only as the query parameter.</p>
/// <p>Mutation: replace <code>$ClassMethod(tClass, "SettableFields")</code> in
/// <method>OcuPilot.Area.Permissions.ResourceSave.Create</method> with a list missing
/// <code>PublicPermission</code> -> the bodies differ and this goes red.</p>
Method TestTheScreenAndTheConfirmSendOneBody()
{
    Set tArgs = ..Args()
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#SCREEN, "Create", ..#PROBE, tArgs, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the screen accepts the create")
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Set tScreenBody = ##class(OcuPilot.Test.ProposalFixture).LastWriteBody()
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "PUT", "at the tool's own write type")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("name"), ..#PROBE, "naming the resource in the query parameter")

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#PROBE, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent mints the same create")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "with nothing unchanged")
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 2, "and one diff row per supplied field")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and its confirm applies it")
    Set tAgentBody = ##class(OcuPilot.Test.ProposalFixture).LastWriteBody()

    Do $$$AssertNotEquals(tScreenBody, "", "a body reached the port from the screen")
    Do $$$AssertEquals(tScreenBody, tAgentBody, "the screen's Save and the agent's confirm send the identical body")
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tScreenBody)
    Do $$$AssertEquals(tBody.%Get("PublicPermission"), "RU", "carrying the public permission")
    Do $$$AssertEquals(tBody.%GetTypeOf("Name"), "unassigned", "and never the name, which the vendor refuses in the body")
    Do $$$AssertEquals(tBody.%GetTypeOf("Type"), "unassigned", "nor a type")
}

/// <p>AC6, AD-10 on both callers: a public permission on an administrative resource is granted,
/// not refused. The screen's Save reaches the port with it; the agent's proposal is minted
/// <b>destructive</b> with the privilege-grant consequence and its confirm applies it. The same
/// letters on an ordinary resource, and no letter on an administrative one, are neither.</p>
/// <p>Mutation: make the <code>resource</code> branch of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method> answer 0 -> case 1
/// goes red.</p>
Method TestAPrivilegedPublicPermissionIsGrantedAtTheStrongestConfirmationOnBothCallers()
{
    Set tPrivilegedCode = $Parameter("OcuPilot.Kernel.Proposal.Mint", "CONSEQUENCEPRIVILEGED")
    For tCase = 1:1:3 {
        Set tArgs = ..Args()
        If tCase = 1 Set tName = ..#PRIVILEGEDPROBE, tPrivileged = 1 Do tArgs.%Set("PublicPermission", "U", "string")
        If tCase = 2 Set tName = ..#PRIVILEGEDPROBE, tPrivileged = 0 Do tArgs.%Set("PublicPermission", "", "string")
        If tCase = 3 Set tName = ..#PROBE, tPrivileged = 0
        Set tLabel = "case " _ tCase

        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Set tSC = $ClassMethod(..#SCREEN, "Create", tName, tArgs, .tHttp, .tFault, .tViolations)
        Do $$$AssertStatusOK(tSC, tLabel _ ": the screen's Save is accepted")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, tLabel _ ": and the create reaches the port")

        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
        Set tSC = ..Mint(tName, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tLabel _ ": the agent's mint proposes it")
        If $$$ISERR(tSC) Continue
        Do ..Stored(tProposal.%Get("proposalId"), .tDestructive, .tConsequence)
        Do $$$AssertEquals(tDestructive, tPrivileged, tLabel _ ": the proposal is destructive exactly when the grant is privileged")
        Do $$$AssertEquals(tConsequence, $Select(tPrivileged: tPrivilegedCode, 1: ""), tLabel _ ": and names the privilege as its consequence")
        Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
        Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
        Do $$$AssertStatusOK(tSC, tLabel _ ": and its confirm applies it")
    }
    Do $$$AssertEquals(##class(OcuPilot.Area.Permissions.ResourceRules).LetterRules().%ToJSON() [ "%Admin_", 1, "the letter rules the editor applies carry the administrative prefix")
}

/// <p>AD-10, P2: a create that gives one of OcuPilot's own resources a public permission is refused
/// <code>PROHIBITED.OCUPILOTRESOURCE</code> on both callers, for both names in another case, and the
/// same create with no permission is not refused on that code.</p>
/// <p>Mutation: drop the <code>resource</code> step from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Created</method> -> both callers go red.</p>
Method TestACreateOpeningOcuPilotsOwnResourceIsRefusedOnBothCallers()
{
    Set tCode = $Parameter(..#SET, "OCUPILOTRESOURCE")
    For tName = $ZConvert(##class(OcuPilot.Kernel.State.Base).#DBRESOURCE, "L"), $ZConvert(##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE, "U") {
        Set tArgs = {"Description": "probe", "PublicPermission": "R"}
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Set tSC = $ClassMethod(..#SCREEN, "Create", tName, tArgs, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "403 " _ tCode, tName _ ": the screen refuses it as OcuPilot's own")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, tName _ ": and nothing reaches the port")

        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Set tSC = ..SeedAndConfirm(tName, tArgs, .tHttp, .tCode2)
        Do $$$AssertEquals(tHttp _ " " _ tCode2, "403 " _ tCode, tName _ ": the agent's confirm refuses it inside the transition")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, tName _ ": with no write")

        Set tArgs = {"Description": "probe", "PublicPermission": ""}
        Set tSC = $ClassMethod(..#SCREEN, "Create", tName, tArgs, .tHttp, .tFault, .tViolations)
        Do $$$AssertNotEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), tCode, tName _ ": no permission is not refused as opening it")
    }
    Set tReason = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode)
    Do $$$AssertNotEquals(tReason, "", "the refusal carries a written sentence")
    Do $$$AssertTrue('($ZConvert(tReason, "L") [ "agent"), "which names no caller")
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Kernel.Proposal.Prohibited).Codes(), tCode), "and is one of the set's declared codes")
}

/// <p>AD-15, AD-41, AD-14: a confirmed create is marked, its ledger row names the sent fields, and
/// the answer carries the <code>created</code> action.</p>
/// <p>Mutation: set <parameter>OcuPilot.Screen.Tool.ResourceCreate.CREATES</parameter> to 0 -> the
/// mint refuses the absent target and this goes red.</p>
Method TestAConfirmedCreateIsMarkedAndAnswersCreated()
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#PROBE, ..Args(), .tProposal, .tHttp, .tFault, .tTurnKey)
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
    For tField = "Description", "PublicPermission" {
        Do $$$AssertTrue($ListFind(tFields, tField), "the ledger names " _ tField _ ": " _ $Get(tRow("Fields")))
    }
}

/// <p>AD-54: a name the instance already holds refuses the agent's mint at 400, and a name taken
/// between the mint and the confirm refuses the confirm at 409 with nothing sent to the upsert.</p>
/// <p>Mutation: set <parameter>OcuPilot.Screen.Tool.ResourceCreate.CREATES</parameter> to 0 -> the
/// present name is minted and this goes red.</p>
Method TestATakenNameRefusesTheMintAndAConfirmTakenSince()
{
    Set tPresent = "{""Description"":""held by somebody else"",""PublicPermission"":""""}"
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tPresent)
    Set tSC = ..Mint(..#PROBE, ..Args(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a create whose name the instance already holds is refused at the mint")
    Do $$$AssertEquals(tHttp, 400, "at 400")

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#PROBE, ..Args(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a create whose name is free is minted")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tPresent)
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "a confirm whose name was taken since the mint is refused as the target having changed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and the vendor's upsert is never reached")
}

/// <p>AD-39: every <code>RESOURCE.*</code> field code carries a sentence, the form read publishes
/// exactly those, and its letter rules give <method>OcuPilot.Area.Permissions.ResourceRules.AdmissibleLetters</method>'s
/// answer for every name a client could apply them to. The list declares Create and invites the
/// agent.</p>
/// <p>Mutations: add a code to <method>OcuPilot.Api.Error.ResourceViolationCodes</method> with no
/// sentence -> red naming it; drop the database prefix from
/// <method>OcuPilot.Area.Permissions.ResourceRules.LetterRules</method> -> the <code>%DB_</code>
/// name goes red.</p>
Method TestTheFormReadPublishesTheSentencesAndTheLetterRules()
{
    Set tCodes = ##class(OcuPilot.Api.Error).ResourceViolationCodes()
    Do $$$AssertTrue($ListLength(tCodes) > 0, "the story publishes resource field codes")
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, tI)), "", $List(tCodes, tI) _ " carries a written sentence")
    }
    Set tRules = $ClassMethod(..#RULES, "Rules")
    Do $$$AssertEquals(tRules.%Size(), $ListLength(tCodes), "the form read publishes one rule per code")

    Set tLetterRules = $ClassMethod(..#RULES, "LetterRules")
    For tName = "%DB_USER", "%db_probe", "%Admin_Secure", "%Service_Login", "%SQL", "%Development", "%Secure_Probe", "OcuPilotAdmin", "Plain", "%Other_Probe" {
        Do $$$AssertEquals(..Apply(tLetterRules, tName), $ClassMethod(..#RULES, "AdmissibleLetters", tName), tName _ ": the shipped rules give the server's letters")
    }
    Do $$$AssertEquals($ClassMethod(..#RULES, "AdmissibleLetters", "%DB_USER"), "RW", "a database admits read and write")
    Do $$$AssertEquals($ClassMethod(..#RULES, "AdmissibleLetters", "%Admin_Secure"), "U", "an administrative resource admits use")
    Do $$$AssertEquals($ClassMethod(..#RULES, "AdmissibleLetters", "Plain"), "RWU", "any other resource admits all three")

    Set tSC = $ClassMethod(..#LIST, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the list's declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tDeclaration.%Get("primaryAction").%Get("id"), "create", "the list declares Create as its primary action")
    Do $$$AssertEquals(tDeclaration.%Get("table").%Get("emptyNextKey"), "", "so its empty state names no next step")
    Do $$$AssertEquals(tDeclaration.%Get("table").%Get("emptyAgentKey"), "resourceListEmptyAgent", "and invites the agent instead")
}

/// <p>The letters <var>pRules</var> (<method>OcuPilot.Area.Permissions.ResourceRules.LetterRules</method>'s
/// shape) give <var>pName</var>, as the editor applies them.</p>
ClassMethod Apply(pRules As %DynamicObject, pName As %String) As %String
{
    Set tIterator = pRules.%Get("prefixes").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tPrefix = $ZConvert(tEntry.%Get("prefix"), "U")
        If $Extract($ZConvert(pName, "U"), 1, $Length(tPrefix)) = tPrefix Quit
        Set tEntry = ""
    }
    If $IsObject($Get(tEntry)) Quit tEntry.%Get("letters")
    Quit pRules.%Get("letters")
}

/// <p>The arguments every create here proposes.</p>
ClassMethod Args() As %DynamicObject
{
    Quit {"Description": "OcuPilot create probe", "PublicPermission": "RU"}
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

/// <p>Seed one create proposal of <var>pName</var> carrying <var>pPayload</var> under the absence
/// fingerprint, and confirm it through the shipped transition.</p>
Method SeedAndConfirm(pName As %String, pPayload As %DynamicObject, Output pHttp As %Integer, Output pCode As %String) As %Status
{
    Set pHttp = 0
    Set pCode = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(##class(OcuPilot.Kernel.Proposal.Mint).AbsenceState(0), "", .tFingerprint)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("resource", "instance", pName, .tRef)
    If $$$ISERR(tSC) Quit tSC
    Kill tValues
    Set tValues("user") = $Username
    Set tValues("turnKey") = tTurnKey
    Set tValues("toolName") = $Parameter(..#TOOL, "TOOLNAME")
    Set tValues("targetRef") = tRef
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
