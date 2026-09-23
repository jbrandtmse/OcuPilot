/// <p>Pins Story 8.2's user create (AD-3, AD-6, AD-10, AD-35, AD-54, AD-55): what
/// <class>OcuPilot.Screen.Tool.UserCreate</class> advertises, the one rule set both callers apply,
/// the privileged-role refusal on both callers, the password's absence from every stored surface,
/// the one body the screen and the confirm send, and the port's wrapper.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and its protected state
/// readable. Every write goes to <class>OcuPilot.Test.ProposalFixture</class>, so nothing here
/// creates an account; the name-taken read is live, so <parameter>PROBEUSER</parameter> must be a
/// name the instance does not hold. No arming variable is required.</p>
Class OcuPilot.Test.UserCreate Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.UserCreate";

Parameter LIST = "OcuPilot.Screen.Descriptor.UserList";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The shipped screen route with only its port replaced.</p>
Parameter SCREEN = "OcuPilot.Test.UserCreateFixture";

/// <p>The shipped mint and confirm with the port replaced.</p>
Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter STORE = "OcuPilot.Kernel.State.Propose";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The name every create here proposes; nothing on the instance holds it.</p>
Parameter PROBEUSER = "ocupilotprobeusercreate";

/// <p>A password that meets this build's policy (<code>3.255ANP</code>) and appears nowhere else,
/// so its absence from a stored surface is a search for exactly this text.</p>
Parameter PROBEPASSWORD = "Ocu8Probe-Secret";

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

/// <p>AD-3 and AD-10: the schema carries no <code>Password</code> and no
/// <code>EscalationRoles</code>, and the tool's settable set equals the prohibited set's reviewed
/// create list for a user.</p>
/// <p>Mutation: add <code>Comment</code> to <parameter>OcuPilot.Screen.Tool.UserCreate.PERMITTEDFIELDS</parameter>
/// -> the set equality goes red.</p>
Method TestTheSchemaCarriesNoSecretAndThePermittedSetIsTheSets()
{
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertEquals(tProperties.%GetTypeOf("Password"), "unassigned", "the schema never offers the model a password")
    Do $$$AssertEquals(tProperties.%GetTypeOf("EscalationRoles"), "unassigned", "nor escalation roles")
    Do $$$AssertEquals(tProperties.%GetTypeOf("Roles"), "object", "and it offers the roles")
    Do $$$AssertEquals(tSchema.%Get("additionalProperties"), 0, "closed to everything else")
    Do $$$AssertEquals(..Sorted($ClassMethod(..#TOOL, "SettableFields")), ..Sorted($ClassMethod(..#SET, "PermittedCreateFields", "user")), "the settable set is the prohibited set's reviewed create list")
    Do $$$AssertTrue($ListFind($ClassMethod(..#SET, "AlwaysProhibitedCreateFields", "user"), "EscalationRoles"), "and escalation roles are always prohibited on a create")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "WriteType"), "POST", "the create is the vendor's POST")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Creates"), 1, "and a create (AD-54)")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "ComposedSecrets")), "Password", "whose one composed secret is the password")
    Do $$$AssertTrue($ListFind($ClassMethod(..#LIST, "SecretArguments"), "Password"), "which the Users list declares secret")
}

/// <p>AD-55: every field rule refuses on the screen route and at the agent's mint alike, on the
/// field it names; the two password rules and the name look-up are the screen's alone, because the
/// agent never holds a password and its mint reads the target's absence itself.</p>
/// <p>Mutation: drop the namespace leg from
/// <method>OcuPilot.Area.Permissions.UserCreateRules.Validate</method> -> the namespace case goes
/// red on both callers.</p>
Method TestEveryFieldRuleRefusesOnBothCallers()
{
    Set tLong = $Translate($Justify("", 161), " ", "a")
    Set tFullNameMax = +##class(OcuPilot.Area.Permissions.UserCreateRules).Lengths().%Get("FullName")
    Do $$$AssertTrue(tFullNameMax > 0, "the instance publishes the full name's stored length")
    For tCase = 1:1:12 {
        Set tName = ..#PROBEUSER
        Set tArgs = ..Args()
        If tCase = 1 Set tName = "probe@user", tField = "Name", tCode = "USERNAMESHAPE"
        If tCase = 2 Set tName = tLong, tField = "Name", tCode = "USERNAMESHAPE"
        If tCase = 3 Set tName = "probe" _ $Char(1), tField = "Name", tCode = "USERNAMESHAPE"
        If tCase = 4 Do tArgs.%Set("ExpirationDate", "2027-02-30", "string") Set tField = "ExpirationDate", tCode = "USEREXPIRATIONDATESHAPE"
        If tCase = 5 Do tArgs.%Set("NameSpace", "OCUPILOTNOSUCHNS", "string") Set tField = "NameSpace", tCode = "USERNAMESPACEUNKNOWN"
        If tCase = 6 Do tArgs.%Remove("NameSpace") Do tArgs.%Set("Routine", "^probe", "string") Set tField = "Routine", tCode = "USERROUTINENAMESPACE"
        If tCase = 7 Do tArgs.%Set("Routine", $Translate($Justify("", 65), " ", "r"), "string") Set tField = "Routine", tCode = "USERROUTINELENGTH"
        If tCase = 8 Do tArgs.%Set("Roles", ["OcuPilotNoSuchRole"]) Set tField = "Roles", tCode = "USERROLESUNKNOWN"
        If tCase = 9 Do tArgs.%Set("FullName", $Translate($Justify("", tFullNameMax + 1), " ", "f"), "string") Set tField = "FullName", tCode = "USERFULLNAMELENGTH"
        If tCase = 10 Do tArgs.%Set("Roles", "%Developer", "string") Set tField = "Roles", tCode = "USERROLESSHAPE"
        If tCase = 11 Do tArgs.%Set("FullName", {"first": "probe"}) Set tField = "FullName", tCode = "PORTFIELDSHAPE"
        If tCase = 12 Set tName = "probe*user", tField = "Name", tCode = "USERNAMESHAPE"
        Set tExpected = $Parameter("OcuPilot.Api.Error", tCode)

        Set tScreenArgs = ##class(%DynamicAbstractObject).%FromJSON(tArgs.%ToJSON())
        Do tScreenArgs.%Set("Password", ..#PROBEPASSWORD, "string")
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Set tSC = $ClassMethod(..#SCREEN, "Perform", tName, tScreenArgs, .tCreated, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(..CodeFor(.tViolations, tField), tExpected, "case " _ tCase _ ": the screen refuses on " _ tField)
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "case " _ tCase _ ": and nothing reaches the port")

        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
        Set tSC = ..Mint(tName, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, "case " _ tCase _ ": the agent's mint refuses it too")
        Do $$$AssertEquals(tHttp, 400, "case " _ tCase _ ": at 400")
        Set tProblem = ..Problem(tFault)
        ; An object for a scalar field is refused at the mint by the payload's own composition,
        ; in its own words, before the field rules run; the refusal still names the field.
        If tCase = 11 {
            Do $$$AssertTrue(tProblem [ "'FullName'", "case 11: on the full name: " _ tProblem)
        } Else {
            Do $$$AssertTrue(tProblem [ ##class(OcuPilot.Api.Error).ReasonForViolation(tExpected), "case " _ tCase _ ": with the same sentence: " _ tProblem)
        }
    }

    ; The two password rules, the screen's alone.
    For tPassword = "", "ab" {
        Set tArgs = ..Args()
        If tPassword '= "" Do tArgs.%Set("Password", tPassword, "string")
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Set tSC = $ClassMethod(..#SCREEN, "Perform", ..#PROBEUSER, tArgs, .tCreated, .tHttp, .tFault, .tViolations)
        Set tCode = $Select(tPassword = "": ##class(OcuPilot.Api.Error).#USERPASSWORDREQUIRED, 1: ##class(OcuPilot.Api.Error).#USERPASSWORDPOLICY)
        Do $$$AssertEquals(..CodeFor(.tViolations, "Password"), tCode, "a password of '" _ $Length(tPassword) _ "' characters is refused on the password field")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing reaches the port")
    }

    ; The name look-up, the screen's alone: an account every instance holds, in another case.
    Set tArgs = ..Args()
    Do tArgs.%Set("Password", ..#PROBEPASSWORD, "string")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#SCREEN, "Perform", "_system", tArgs, .tCreated, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(..CodeFor(.tViolations, "Name"), ##class(OcuPilot.Api.Error).#USERNAMETAKEN, "a taken name is refused on the name field")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing reaches the port")
}

/// <p>AD-55: the screen's Save and the agent's confirm send one body from the same arguments --
/// the composed fields, then the password merged in after the verdict.</p>
/// <p>Mutation: replace <code>$ClassMethod(tClass, "SettableFields")</code> in
/// <method>OcuPilot.Area.Permissions.UserCreate.Perform</method> with a hand-typed list missing
/// <code>FullName</code> -> the bodies differ and this goes red.</p>
Method TestTheScreenAndTheConfirmSendOneBody()
{
    Set tArgs = ..Args()
    Set tScreenArgs = ##class(%DynamicAbstractObject).%FromJSON(tArgs.%ToJSON())
    Do tScreenArgs.%Set("Password", ..#PROBEPASSWORD, "string")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#SCREEN, "Perform", ..#PROBEUSER, tScreenArgs, .tCreated, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the screen accepts the create")
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Set tScreenBody = ##class(OcuPilot.Test.ProposalFixture).LastWriteBody()
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "POST", "at the tool's own write type")

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#PROBEUSER, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent mints the same create")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult, ..Secrets())
    Do $$$AssertStatusOK(tSC, "and its confirm, supplied the password on the card, applies it")
    Set tAgentBody = ##class(OcuPilot.Test.ProposalFixture).LastWriteBody()

    Do $$$AssertNotEquals(tScreenBody, "", "a body reached the port from the screen")
    Do $$$AssertEquals(tScreenBody, tAgentBody, "the screen's Save and the agent's confirm send the identical body")
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tScreenBody)
    Do $$$AssertEquals(tBody.%Get("FullName"), tArgs.%Get("FullName"), "carrying the full name")
    Do $$$AssertEquals(tBody.%GetTypeOf("Roles"), "array", "the roles")
    Do $$$AssertEquals(tBody.%Get("Password"), ..#PROBEPASSWORD, "and the password, which reaches the port and nothing else")
    Do $$$AssertEquals(tBody.%GetTypeOf("Name"), "unassigned", "and never the name, which is the vendor's query parameter")
}

/// <p>AD-10 on both callers: a role that grants <code>%All</code> by name, or an administrative
/// resource it carries, is refused -- on the screen as the Roles violation carrying the server's
/// sentence, at the agent's confirm inside the transition -- and neither reaches the port. An
/// ordinary role is not refused. A seeded row carrying escalation roles is refused inside the
/// transition too.</p>
/// <p>Mutation: remove the <code>user</code> step from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Created</method> -> every privileged leg goes red on
/// both callers.</p>
Method TestAPrivilegedRoleIsRefusedOnBothCallers()
{
    For tRole = "%All", "%Manager" {
        Set tArgs = ..Args()
        Do tArgs.%Set("Roles", [(tRole)])
        Set tScreenArgs = ##class(%DynamicAbstractObject).%FromJSON(tArgs.%ToJSON())
        Do tScreenArgs.%Set("Password", ..#PROBEPASSWORD, "string")
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Set tSC = $ClassMethod(..#SCREEN, "Perform", ..#PROBEUSER, tScreenArgs, .tCreated, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(+$Get(tViolations), 1, tRole _ ": the screen answers one violation")
        Do $$$AssertEquals(..CodeFor(.tViolations, "Roles"), $Parameter(..#SET, "PRIVILEGEGRANT"), tRole _ ": on the Roles field, as a privilege grant")
        Do $$$AssertEquals($ListGet($Get(tViolations(1)), 3), ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor($Parameter(..#SET, "PRIVILEGEGRANT")), tRole _ ": carrying the server's sentence")
        Do $$$AssertTrue('($ZConvert($ListGet($Get(tViolations(1)), 3), "L") [ "agent"), tRole _ ": a sentence a person reads on the screen names no caller (AD-53)")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, tRole _ ": and nothing reaches the port")

        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
        Set tSC = ..Mint(..#PROBEUSER, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tRole _ ": the agent's mint proposes it")
        If $$$ISERR(tSC) Continue
        Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
        Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult, ..Secrets())
        Do $$$AssertStatusNotOK(tSC, tRole _ ": and its confirm refuses it")
        Do $$$AssertEquals(tHttp, 403, tRole _ ": at 403")
        Do $$$AssertEquals(tCode, $Parameter(..#SET, "PRIVILEGEGRANT"), tRole _ ": on the privilege-grant predicate")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, tRole _ ": and nothing reaches the port")
    }

    ; An ordinary role grants nothing AD-10 names.
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#SET, "Prohibits", $Parameter(..#TOOL, "TOOLNAME"), ..TargetRef(), {"Roles": ["%Developer"]}.%ToJSON(), "[]", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers for an ordinary role")
    Do $$$AssertEquals(tProhibits, 0, "and does not refuse it")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).RoleGrantsAdministrativePrivilege("%Developer"), 0, "the picker leaves an ordinary role available")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Prohibited).RoleGrantsAdministrativePrivilege("%Manager"), 1, "and pre-marks one that carries an administrative resource")

    ; A seeded row the shipped mint cannot produce: escalation roles, refused inside the transition.
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tFpSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(##class(OcuPilot.Kernel.Proposal.Mint).AbsenceState(0), "", .tFingerprint)
    Do $$$AssertStatusOK(tFpSC, "the absence digest is taken")
    Set tPayload = {"FullName": "probe", "EscalationRoles": ["%Developer"]}
    Kill tValues
    Set tValues("user") = $Username
    Set tValues("turnKey") = tTurnKey
    Set tValues("toolName") = $Parameter(..#TOOL, "TOOLNAME")
    Set tValues("targetRef") = ..TargetRef()
    Set tValues("fingerprint") = tFingerprint
    Set tValues("arguments") = tPayload.%ToJSON()
    Set tValues("payload") = tPayload.%ToJSON()
    Set tValues("diff") = "[]"
    Set tValues("unchangedCount") = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a create proposal carrying escalation roles is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Confirm(tKey, .tHttp, .tCode, .tResult, ..Secrets())
    Do $$$AssertEquals(tHttp, 403, "the seeded row is refused at 403")
    Do $$$AssertEquals(tCode, $Parameter(..#SET, "PRIVILEGEGRANT"), "as a privilege grant")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "with no write")
}

/// <p>AD-6 and AD-35: a password among the mint's arguments is refused, and a minted create's
/// stored arguments, payload and diff carry no password -- only one <code>Password</code> diff row,
/// empty on both sides -- and its ledger row names every sent field except the password.</p>
/// <p>Mutation: store <code>Password</code> in
/// <method>OcuPilot.Kernel.Proposal.Mint.StoredArguments</method> (set it on the stored text) -> the
/// stored-arguments assertion goes red.</p>
Method TestThePasswordIsAbsentFromEveryStoredSurface()
{
    Set tArgs = ..Args()
    Do tArgs.%Set("Password", ..#PROBEPASSWORD, "string")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#PROBEUSER, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a password from the agent is refused")
    Do $$$AssertEquals(tHttp, 400, "at 400")
    Do $$$AssertTrue(..Problem(tFault) [ "'Password' is a secret field", "as a secret the agent never supplies")

    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#PROBEUSER, ..Args(), .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a create with no password is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "with nothing unchanged")
    Set tChanged = tProposal.%Get("changed")
    Set tLast = tChanged.%Get(tChanged.%Size() - 1)
    Do $$$AssertEquals(tLast.%Get("field"), "Password", "and one Password row, last")
    Do $$$AssertEquals(tLast.%Get("before") _ "|" _ tLast.%Get("after"), "|", "empty on both sides")

    Set tSC = $ClassMethod(..#STORE, "GuardedByKey", tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertStatusOK(tSC, "the stored row reads back")
    Do $$$AssertTrue(tFound, "the minted row is found, so the absence checks below have a subject")
    If 'tFound Quit
    Set tStoredArgs = ##class(%DynamicAbstractObject).%FromJSON($Get(tValues("arguments")))
    Set tStoredPayload = ##class(%DynamicAbstractObject).%FromJSON($Get(tValues("payload")))
    Do $$$AssertEquals(tStoredArgs.%GetTypeOf("Password"), "unassigned", "the stored arguments carry no password")
    Do $$$AssertEquals(tStoredPayload.%GetTypeOf("Password"), "unassigned", "nor the stored payload")

    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult, ..Secrets())
    Do $$$AssertStatusOK(tSC, "the confirm supplies the password and applies the create")
    If $$$ISERR(tSC) Quit
    Set tStored = $Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff"))
    Set tSC = $ClassMethod(..#STORE, "GuardedByKey", tProposal.%Get("proposalId"), .tFound, .tAfter)
    Set tStored = tStored _ $Get(tAfter("arguments")) _ $Get(tAfter("payload")) _ $Get(tAfter("diff"))
    Do $$$AssertTrue('(tStored [ ..#PROBEPASSWORD), "no stored surface carries the password, before or after the confirm")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "the turn holds one write-kind ledger row")
    Set tFields = $Get(tRow("Fields"))
    Do $$$AssertTrue(tFields [ "FullName", "which names the sent fields: " _ tFields)
    Do $$$AssertTrue('$ListFind($ListFromString(tFields), "Password"), "and never the password: " _ tFields)
    Do $$$AssertTrue('(tFields [ ..#PROBEPASSWORD), "or its value")
}

/// <p>AD-5, AD-15 and AD-14: a confirmed create is marked, answers the <code>created</code> action,
/// and the body the port receives becomes the vendor's wrapper -- the account's fields under
/// <code>User</code> and the password beside it.</p>
/// <p>Mutation: remove <code>Security.User/POST</code> from
/// <parameter>OcuPilot.Port.AdminPort.WRAPPEDTYPES</parameter> -> the wrapper assertions go red.</p>
Method TestAConfirmedCreateIsMarkedAndItsBodyIsWrapped()
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#PROBEUSER, ..Args(), .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the create is minted")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult, ..Secrets())
    Do $$$AssertStatusOK(tSC, "and confirmed")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "created", "the answer carries the created action")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent marker landed on it")

    Set tSent = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.ProposalFixture).LastWriteBody())
    Set tWire = ##class(OcuPilot.Port.AdminPort).Wrapped("Security.User", "POST", tSent)
    Do $$$AssertEquals(tWire.%GetTypeOf("User"), "object", "the port wraps the account's fields under User")
    If tWire.%GetTypeOf("User") '= "object" Quit
    Do $$$AssertEquals(tWire.%Get("User").%Get("FullName"), ..Args().%Get("FullName"), "carrying the full name")
    Do $$$AssertEquals(tWire.%Get("User").%GetTypeOf("Roles"), "array", "and the roles, as an array")
    Do $$$AssertEquals(tWire.%Get("User").%GetTypeOf("Password"), "unassigned", "with the password outside the wrapper")
    Do $$$AssertEquals(tWire.%Get("Password"), ..#PROBEPASSWORD, "beside it")
    ; A missing outer key stays missing, so the vendor's own refusal answers for it.
    Set tBare = ##class(OcuPilot.Port.AdminPort).Wrapped("Security.User", "POST", {"FullName": "x"})
    Do $$$AssertEquals(tBare.%GetTypeOf("Password"), "unassigned", "a password the body lacks stays missing")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).WrapperKey("Security.User", "PUT"), "", "and the update's PUT is not wrapped")
}

/// <p>The User form is built, unlisted, gated by the list's own pairs and secret-typed on the
/// password in its context; the list is write-capable and declares the password secret (AD-5,
/// AD-8, AD-24).</p>
/// <p>Mutation: give the form a non-zero <code>sideBarPosition</code> -> the unlisted assertion goes
/// red.</p>
Method TestTheFormDescriptorIsBuiltUnlistedAndCarriesTheListsOwnPairs()
{
    Set tForm = "OcuPilot.Screen.Descriptor.UserForm"
    Do $$$AssertEquals($ClassMethod(tForm, "Route"), $ClassMethod(..#LIST, "Route") _ "/edit", "the form's route is the list's own with the editor suffix")
    Do $$$AssertEquals(''$ClassMethod(tForm, "IsBuilt"), 1, "it is built")
    Do $$$AssertEquals(+$ClassMethod(tForm, "SideBarPosition"), 0, "and unlisted")
    Do $$$AssertEquals($ClassMethod(tForm, "Archetype"), "form-page", "it is a form page")
    Do $$$AssertEquals($ClassMethod(tForm, "PrimaryEntityType"), "user", "over the user entity type")
    Do $$$AssertEquals($ClassMethod(tForm, "ToolIdentifier"), "permissions.userform", "with its own tool identifier")
    Do $$$AssertEquals($IsObject($ClassMethod(tForm, "Read")), 0, "and no declared read")
    Do $$$AssertEquals($ListToString($ClassMethod(tForm, "PrivilegePairs")), $ListToString($ClassMethod(..#LIST, "PrivilegePairs")), "the form requires exactly what the list requires")
    Do $$$AssertEquals($Parameter("OcuPilot.Area.Permissions.UserCreate", "DESCRIPTORCLASS"), tForm, "and the create route gates on the form's declaration")
    Set tSC = $ClassMethod(tForm, "DeclarationJson", .tFormDeclaration)
    Do $$$AssertStatusOK(tSC, "the form's declaration parses")
    If $$$ISOK(tSC) Do $$$AssertEquals(tFormDeclaration.%Get("context").%Get("secretFields").%ToJSON(), "[""Password""]", "its context never carries the password being typed")
    Set tSC = $ClassMethod(..#LIST, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the list's declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tDeclaration.%Get("primaryAction").%Get("id"), "create", "the list declares Create as its primary action")
    Do $$$AssertEquals(tDeclaration.%Get("table").%Get("emptyNextKey"), "", "so its empty state names no next step")
    Do $$$AssertEquals(tDeclaration.%Get("table").%Get("emptyAgentKey"), "userListEmptyAgent", "and invites the agent instead")
}

/// <p>AD-3, AD-6: a <code>secretArguments</code> name qualifies when it is a top-level
/// <code>secret</code> row of the screen's write tools -- the create's authored
/// <code>Password</code> -- while a name no source carries, and a nested secret path, are still
/// refused, and a settable field still qualifies. The twin of
/// <file>ui/tools/screen-mirror.test.mjs</file>'s secret-row test.</p>
/// <p>Mutation: drop the <method>OcuPilot.Screen.Registry.SecretRowNames</method> clause from
/// <method>OcuPilot.Screen.Registry.ConfirmChannelProblem</method> -> the Users list's own
/// declaration is refused and this goes red.</p>
Method TestTheConfirmChannelAdmitsATopLevelSecretRowAndNothingElseNew()
{
    Set tSC = $ClassMethod(..#LIST, "DeclarationJson", .tUsers)
    Do $$$AssertStatusOK(tSC, "the Users list's declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tUsers), "", "its authored Password qualifies")
    Do tUsers.%Set("secretArguments", ["Pasword"])
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tUsers) [ "'Pasword'", "a name no source carries is still refused")
    Set tSC = ##class(OcuPilot.Screen.Descriptor.WebAppList).DeclarationJson(.tApps)
    Do $$$AssertStatusOK(tSC, "the Web applications list's declaration parses")
    If $$$ISERR(tSC) Quit
    Do tApps.%Set("secretArguments", ["Timeout"])
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tApps), "", "a settable field still qualifies")
    Do tApps.%Set("secretArguments", ["MatchRoles[].MatchRole"])
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tApps), "", "and a nested secret path does not")
}

/// <p>AD-39: every <code>USER.*</code> field code carries a written sentence, and the form's
/// bootstrap rules carry exactly those sentences.</p>
/// <p>Mutation: add a code to <method>OcuPilot.Api.Error.UserViolationCodes</method> with no row in
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> -> this goes red naming it.</p>
Method TestEveryUserFieldCodeCarriesItsOwnSentence()
{
    Set tCodes = ##class(OcuPilot.Api.Error).UserViolationCodes()
    Do $$$AssertTrue($ListLength(tCodes) > 0, "the story publishes user field codes")
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, tI)), "", $List(tCodes, tI) _ " carries a written sentence")
    }
    Set tRules = ##class(OcuPilot.Area.Permissions.UserCreateRules).Rules()
    Do $$$AssertEquals(tRules.%Size(), $ListLength(tCodes), "and the bootstrap publishes one rule per code")
    Set tIterator = tRules.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRule) {
        Do $$$AssertEquals(tRule.%Get("reason"), ##class(OcuPilot.Api.Error).ReasonForViolation(tRule.%Get("code")), "the rule on " _ tRule.%Get("field") _ " carries the server's sentence")
    }
}

/// <p>The arguments every create here proposes.</p>
ClassMethod Args() As %DynamicObject
{
    Set tArgs = {}
    Do tArgs.%Set("FullName", "OcuPilot create probe", "string")
    Do tArgs.%Set("ExpirationDate", "2099-12-31", "string")
    Do tArgs.%Set("NameSpace", $Namespace, "string")
    Do tArgs.%Set("Roles", ["%Developer"])
    Quit tArgs
}

/// <p>The confirm body: the password, the one key the channel is open to.</p>
ClassMethod Secrets() As %DynamicObject
{
    Set tSecrets = {}
    Do tSecrets.%Set("Password", ..#PROBEPASSWORD, "string")
    Quit tSecrets
}

/// <p>The canonical reference of <parameter>PROBEUSER</parameter>.</p>
ClassMethod TargetRef() As %String
{
    Do ##class(OcuPilot.Kernel.EntityRef).Key("user", "instance", ..#PROBEUSER, .tRef)
    Quit $Get(tRef)
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

/// <p>Confirm <var>pKey</var> through the shipped transition, supplying <var>pSecrets</var>.</p>
Method Confirm(pKey As %String, Output pHttp As %Integer, Output pCode As %String, Output pResult As %DynamicObject, pSecrets As %DynamicObject = "") As %Status
{
    Set pResult = ""
    Quit $ClassMethod(..#CONFIRM, "Confirm", pKey, pSecrets, $Username, .pResult, .pHttp, .pCode, .tDetail)
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
