/// <p>Pins the Users write tool's confirm path (Story 5.9, AD-4, AD-6, AD-8, AD-10, AD-13): the
/// confirmed write sends the complete sixteen-property set, every property the fresh read carried
/// survives the round trip except the ones the diff names, the fingerprint refuses a target that
/// moved, a pair the caller has lost refuses naming it, and each of AD-10's four user refusals is
/// reachable on its own.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, an account holding
/// <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code> --
/// <method>OnBeforeAllTests</method> refuses anywhere it does not, because this class creates and
/// deletes user accounts and one role. Only <file>scripts/ci-throwaway.sh</file> sets it.</p>
/// <p><b>It writes nothing it did not create.</b> Every account and the role are
/// <class>OcuPilot.Test.ProposalFixture</class>'s, which refuses to adopt one it did not make, and
/// the refusal legs go through <class>OcuPilot.Test.ConfirmFixture</class>'s armed port so no
/// refused write can reach the instance at all.</p>
Class OcuPilot.Test.UserUpdate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.ProposalFixture";

Parameter SET = "OcuPilot.Test.ProhibitedFixture";

Parameter SHIPPEDSET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter CONFIRMFIXTURE = "OcuPilot.Test.ConfirmFixture";

Parameter CONFIRM = "OcuPilot.Kernel.Proposal.Confirm";

Parameter MINT = "OcuPilot.Kernel.Proposal.Mint";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.UserList";

Parameter TOOL = "permissions.users.update";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.UserUpdate";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter ENDPOINT = "Security.User";

Parameter IDPARAM = "name";

/// <p>How many top-level properties the vendor's own <code>Security.User</code> <code>GET</code>
/// answers on this build. Measured rather than assumed, and asserted against the live read below
/// so a vendor change reddens here instead of silently narrowing a payload (AD-4).</p>
Parameter PROPERTYCOUNT As %Integer = 16;

/// <p>The pair the privilege refusal is driven with, refused through
/// <class>OcuPilot.Test.ConfirmFixture</class> rather than revoked on the instance. It must be a
/// pair the tool actually requires, or <method>MissingPair</method> has nothing to fail on.</p>
Parameter DENIEDPAIR = "%Admin_Secure:USE";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.UserUpdate creates and deletes user accounts and a role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    ; Six creates, and a failure part way through must not leave the earlier ones behind: every
    ; Ensure* refuses to adopt an account it did not create, so a partial setup makes every later
    ; run of this class refuse at this method until someone cleans up by hand.
    Set tSC = $$$OK
    Try {
        Set tSC = $ClassMethod(..#FIXTURE, "EnsureAllRole", .tCreated)
        If $$$ISERR(tSC) Quit
        Set tSC = $ClassMethod(..#FIXTURE, "EnsureUser", $Parameter(..#FIXTURE, "USERTARGET"), $Parameter(..#FIXTURE, "USERINITIALROLE"), 0, .tCreated)
        If $$$ISERR(tSC) Quit
        Set tSC = $ClassMethod(..#FIXTURE, "EnsureUser", $Parameter(..#FIXTURE, "USERTARGETMIXEDCASE"), "", 1, .tCreated)
        If $$$ISERR(tSC) Quit
        Set tSC = $ClassMethod(..#FIXTURE, "EnsureUser", $Parameter(..#FIXTURE, "USERALLHOLDERSECOND"), $Parameter(..#FIXTURE, "USERALLROLE"), 1, .tCreated)
        If $$$ISERR(tSC) Quit
        Set tSC = $ClassMethod(..#FIXTURE, "EnsureUser", $Parameter(..#FIXTURE, "USERALLHOLDERDISABLED"), $Parameter(..#FIXTURE, "USERALLROLE"), 0, .tCreated)
        If $$$ISERR(tSC) Quit
        Set tSC = $ClassMethod(..#FIXTURE, "EnsureUser", $Parameter(..#FIXTURE, "USERALLHOLDER"), $Parameter(..#FIXTURE, "USERALLROLE"), 1, .tCreated)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Do ..OnAfterAllTests()
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Do $ClassMethod(..#FIXTURE, "RemoveUser", $Parameter(..#FIXTURE, "USERALLHOLDER"))
    Do $ClassMethod(..#FIXTURE, "RemoveUser", $Parameter(..#FIXTURE, "USERALLHOLDERDISABLED"))
    Do $ClassMethod(..#FIXTURE, "RemoveUser", $Parameter(..#FIXTURE, "USERALLHOLDERSECOND"))
    Do $ClassMethod(..#FIXTURE, "RemoveUser", $Parameter(..#FIXTURE, "USERTARGETMIXEDCASE"))
    Do $ClassMethod(..#FIXTURE, "RemoveUser", $Parameter(..#FIXTURE, "USERTARGET"))
    Quit $ClassMethod(..#FIXTURE, "RemoveAllRole")
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $ClassMethod(..#FIXTURE, "DenyPair", "")
    Do $ClassMethod(..#FIXTURE, "ArmProhibited", "")
    Do $ClassMethod(..#FIXTURE, "ArmLastAllHolder", "")
    Do $ClassMethod(..#FIXTURE, "ArmAllHolders", "")
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveSeeded", .tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>The target account's name, as this fixture created it.</p>
Method Target() As %String
{
    Quit $Parameter(..#FIXTURE, "USERTARGET")
}

/// <p>Read <var>pName</var> fresh through the shipped port, exactly as the mint and the confirm
/// read it. <code>""</code> in <var>pObject</var> when the instance answers no object.</p>
Method Fresh(pName As %String, Output pObject As %DynamicObject) As %Status
{
    Set pObject = ""
    Kill tQuery
    Set tQuery(..#IDPARAM) = pName
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "GET", .tQuery, "", .pObject, .tHttp, .tFault)
    Quit tSC
}

/// <p>Mint one live proposal for <var>pArgs</var> on a completed turn for the running account,
/// through the <b>shipped</b> mint and the shipped port, and answer its id.</p>
Method Mint(pArgs As %DynamicObject, Output pTurnKey As %String) As %String
{
    Set pTurnKey = ""
    Set tSC = $ClassMethod(..#FIXTURE, "SeedTurn", $Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set pTurnKey = tTurnKey
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, ..#TOOL, $Username, "", tTurnKey, pArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, ..#ENDPOINT, ..#IDPARAM, pArgs.%Get("Name"), "Name", $ClassMethod(..#TOOLCLASS, "SettableFields"))
    Do $$$AssertStatusOK(tSC, "the probe proposal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit ""
    Quit tProposal.%Get("proposalId")
}

/// <p>Seed one live proposal directly, carrying <var>pPayload</var> and a diff naming the
/// comma-separated <var>pFields</var>, against the account <var>pName</var>. The payload is not one
/// a mint produced, which is what lets a refusal be driven against a target the armed port answers
/// rather than against a real account.</p>
Method Seed(pName As %String, pPayload As %String, pFields As %String) As %String
{
    Set tSC = $ClassMethod(..#FIXTURE, "SeedTurn", $Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tRef = $ClassMethod(..#SET, "Reference", pName, "user")
    Do $$$AssertNotEquals(tRef, "", "the target reference is built")
    If tRef = "" Quit ""
    Kill tValues
    Set tValues("user") = $Username
    Set tValues("convKey") = ""
    Set tValues("turnKey") = tTurnKey
    Set tValues("toolName") = ..#TOOL
    Set tValues("targetRef") = tRef
    Set tValues("fingerprint") = "0"
    Set tValues("arguments") = "{}"
    Set tValues("payload") = pPayload
    Set tValues("diff") = $ClassMethod(..#SET, "Diff", pFields)
    Set tValues("unchangedCount") = 0
    Set tSC = $ClassMethod(..#FIXTURE, "SeedProposal", .tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit ""
    Quit tKey
}

/// <p>Drive <var>pPayload</var> and its diff against the armed target <var>pFresh</var> through the
/// shipped confirm transition with the armed set in the seam, and assert the refusal it earns: 403
/// with <var>pExpected</var>, the row still live, nothing at the port.</p>
Method Refused(pName As %String, pFresh As %String, pPayload As %String, pFields As %String, pExpected As %String)
{
    Do $ClassMethod(..#FIXTURE, "ArmProhibited", ..#SET)
    Set tKey = ..Seed(pName, pPayload, pFields)
    If tKey = "" Quit
    Do $ClassMethod(..#FIXTURE, "Arm", pFresh)
    Set tSC = $ClassMethod(..#CONFIRMFIXTURE, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tCode, pExpected, "with " _ pExpected)
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Do $$$AssertNotEquals($ClassMethod(..#SHIPPEDSET, "ReasonFor", tCode), "", "and the code carries a written reason the card renders")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "WriteCount"), 0, "and nothing reached the port")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Field", tKey, "State"), "live", "the row stays live")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Field", tKey, "Burned"), 0, "and the token is unspent")
}

/// <p>AC1, AC2, AC3, AD-4: a confirmed enable plus an ordinary role add sends the complete property
/// set the fresh read carried, and every property except the two the diff names comes back byte
/// equal. The instance's own record of the account is what the round trip is read from.</p>
/// <p><b>Also the side-effect measurement AC3 asks for.</b> Every property outside the diff is
/// asserted unchanged, so a property this endpoint moves as a side effect reddens here and names
/// itself; the descriptor declares no <code>fingerprintExcludes</code> because, measured this way,
/// there is none.</p>
/// <p>Mutation: drop one property from the payload in
/// <method>OcuPilot.Kernel.Proposal.Mint.Merge</method> (for instance skip the first key of the
/// clone) -- the survival assertions redden and name the property.</p>
Method TestAConfirmedWriteSendsTheCompletePropertySetAndTheOthersSurvive()
{
    Set tName = ..Target()
    Do $$$AssertStatusOK(..Fresh(tName, .tBefore), "the probe account reads fresh through the port")
    If '$IsObject(tBefore) Quit
    Set tKeys = ""
    Set tIterator = tBefore.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $ListBuild(tKey)
    }
    Do $$$AssertEquals($ListLength(tKeys), ..#PROPERTYCOUNT, "the GET answers the measured property count: " _ $ListToString(tKeys))

    Set tArgs = {}
    Do tArgs.%Set("Name", tName, "string")
    Do tArgs.%Set("Enabled", 1, "boolean")
    Set tRoles = []
    Do tRoles.%Push($Parameter(..#FIXTURE, "USERINITIALROLE"))
    Do tRoles.%Push($Parameter(..#FIXTURE, "USERORDINARYROLE"))
    Do tArgs.%Set("Roles", tRoles)
    Set tKey = ..Mint(tArgs, .tTurnKey)
    If tKey = "" Quit

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tKey, .tFound, .tStored), "the stored row reads back")
    Set tPayload = ##class(%DynamicAbstractObject).%FromJSON($Get(tStored("payload")))
    Set tSentKeys = 0
    Set tIterator = tPayload.%GetIterator()
    While tIterator.%GetNext(.tKey2, .tValue2) {
        Set tSentKeys = tSentKeys + 1
    }
    Do $$$AssertEquals(tSentKeys, ..#PROPERTYCOUNT, "the stored payload is the complete property set, not the two changed fields")
    Do $$$AssertEquals(+$Get(tStored("unchangedCount")), ..#PROPERTYCOUNT - 2, "and the card's unchanged count is the rest of it")

    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm succeeds: " _ tCode _ " " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tHttp, 200, "answering 200")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tResult.%Get("state"), "confirmed", "the row is confirmed")

    Do $$$AssertStatusOK(..Fresh(tName, .tAfter), "the account reads back through the port")
    If '$IsObject(tAfter) Quit
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).Display(tAfter.%Get("Enabled"), tAfter.%GetTypeOf("Enabled")), "true", "the account is enabled on the instance")
    ; Compared as a set: the instance stores an account's roles in its own order, not the order the
    ; payload listed them in, so an ordered compare would pin a vendor detail rather than the write.
    Do $$$AssertEquals(..SortedNames(tAfter.%Get("Roles")), ..SortedNames(tRoles), "and holds exactly the roles the proposal named")
    For tI = 1:1:$ListLength(tKeys) {
        Set tField = $List(tKeys, tI)
        If (tField = "Enabled") || (tField = "Roles") Continue
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).Display(tAfter.%Get(tField), tAfter.%GetTypeOf(tField)), ##class(OcuPilot.Kernel.Proposal.Mint).Display(tBefore.%Get(tField), tBefore.%GetTypeOf(tField)), tField _ " survived the round trip byte for byte")
    }
    Do $$$AssertEquals($ListLength($ClassMethod(..#SCREEN, "FingerprintExcludes")), 0, "and the screen declares no fingerprint exclusion, because no property moved by itself")

    ; AC1's second half (AD-41): the ledger row records the pairs actually exercised, each once.
    ; The expected string is built from the tool's own resolved set through the writer's own
    ; renderer, so this pins that the row carries that set rather than re-spelling it here; that
    ; the set itself is two pairs each once is
    ; OcuPilot.Test.ToolWrite.TestTheUserWriteToolAdvertisesEnabledAndRolesWithTheScreensOwnPairs.
    Set tPairs = $ClassMethod(..#TOOLCLASS, "PrivilegePairs", "", .tPairsResolved)
    Do $$$AssertEquals(tPairsResolved, 1, "the tool's pairs resolve")
    Do $$$AssertEquals($ListLength(tPairs), 2, "and are the screen's two")
    Set tExpected = ##class(OcuPilot.Kernel.Audit.Ledger).PairsToString(tPairs, .tTruncated)
    Do $$$AssertEquals(tTruncated, 0, "and spell without truncation")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Status, RequiredPairs, PairsSense, AuditMarked FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ? AND %EXACT(Kind) = ?", tTurnKey, $Parameter("OcuPilot.Kernel.State.Ledger", "KINDWRITE"))
    Do $$$AssertTrue(tRS.%Next(), "the confirmed write left a ledger row")
    Do $$$AssertEquals(tRS.%Get("Status"), "ok", "recorded ok")
    Do $$$AssertEquals(tRS.%Get("RequiredPairs"), tExpected, "carrying the pairs the write actually exercised")
    Do $$$AssertEquals(tRS.%Get("PairsSense"), $Parameter("OcuPilot.Kernel.State.Ledger", "SENSECHECKED"), "as a set the writer itself checked")
    Do $$$AssertEquals(tRS.%Get("AuditMarked"), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the marker landed (AD-15)")
    Do $$$AssertTrue('tRS.%Next(), "and exactly one such row")
    ; The ledger outlives its subject by design (AD-37), so this class removes its own rows rather
    ; than leaving one per run behind: OnAfterOneTest's RemoveSeeded reaches proposals and turns,
    ; not the ledger.
    Set tRS = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "and this class removes the ledger row it wrote")
}

/// <p>The names <var>pArray</var> carries, upper-cased and sorted, as a comma-separated string:
/// what a role list compares as, since the instance keeps its own order.</p>
Method SortedNames(pArray As %DynamicArray) As %String
{
    Set tList = ""
    If $IsObject(pArray) {
        Set tIterator = pArray.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tItem) {
            If $IsObject(tItem) Continue
            Set tOne = $ZConvert($ZStrip(tItem, "<>W"), "U")
            If tOne '= "" Set tSeen(tOne) = ""
        }
    }
    Set tName = ""
    For {
        Set tName = $Order(tSeen(tName))
        If tName = "" Quit
        Set tList = tList _ $Select(tList = "": "", 1: ",") _ tName
    }
    Quit tList
}

/// <p>AD-6: a target that moved between the mint and the confirm is refused and the row closes.
/// The move is made through <class>Security.Users</class> directly, which is what a second
/// administrator doing the same work looks like.</p>
/// <p>Mutation: return <code>pMatches = 1</code> unconditionally from
/// <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> -- this goes red.</p>
Method TestATargetThatMovedAfterTheMintIsRefused()
{
    Set tName = $Parameter(..#FIXTURE, "USERTARGETMIXEDCASE")
    Set tArgs = {}
    Do tArgs.%Set("Name", tName, "string")
    Do tArgs.%Set("Enabled", 0, "boolean")
    Set tKey = ..Mint(tArgs, .tTurnKey)
    If tKey = "" Quit

    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Kill tProps
    Set tProps("FullName") = "moved under the proposal"
    Set tMoveSC = ##class(Security.Users).Modify(tName, .tProps)
    Set $NAMESPACE = tOrigNS
    Do $$$AssertStatusOK(tMoveSC, "a third party moves the account after the mint")

    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "by the fingerprint gate")
    Do $$$AssertEquals(tHttp, 409, "at 409")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Field", tKey, "ClosedReason"), $Parameter("OcuPilot.Kernel.State.Propose", "REASONTARGETCHANGED"), "and the row closes, naming the target that moved")
    Do $$$AssertStatusOK(..Fresh(tName, .tAfter), "the account still reads back")
    If $IsObject(tAfter) Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).Display(tAfter.%Get("Enabled"), tAfter.%GetTypeOf("Enabled")), "true", "and was never disabled")
}

/// <p>AD-8: a pair the caller has lost since the mint refuses the write at the confirm, naming the
/// pair. Driven through <class>OcuPilot.Test.ConfirmFixture</class>, so no grant on the instance
/// changes and no write leaves.</p>
/// <p>Mutation: delete the <method>MissingPair</method> branch from
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> -- this goes red.</p>
Method TestAPairTheCallerHasLostRefusesNamingIt()
{
    Set tFresh = $ClassMethod(..#SET, "UserObject", ..Target(), 1, $Parameter(..#FIXTURE, "USERINITIALROLE"))
    Set tKey = ..Seed(..Target(), tFresh, "Enabled")
    If tKey = "" Quit
    Do $ClassMethod(..#FIXTURE, "Arm", tFresh)
    Do $ClassMethod(..#FIXTURE, "DenyPair", ..#DENIEDPAIR)
    Set tSC = $ClassMethod(..#CONFIRMFIXTURE, "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, "with the privilege code")
    Do $$$AssertEquals($Select($IsObject(tDetail): tDetail.%Get("failedPair"), 1: ""), ..#DENIEDPAIR, "naming the pair that failed")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "WriteCount"), 0, "and nothing reached the port")
}

/// <p>AC4, AD-10: disabling the account the caller is signed in as, and disabling
/// <code>_SYSTEM</code> in any spelling, are each refused inside the transition with a code of
/// their own.</p>
/// <p>Mutation: return <code>pProhibits = 0</code> from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.User</method> -- both legs redden.</p>
Method TestDisablingTheCurrentUserOrTheSystemAccountIsRefused()
{
    ; The two predicates would coincide for a runner signed in as the predefined account, and the
    ; first-hit-wins order would then hide one of them. Asserted rather than assumed: this suite
    ; runs as the container's own OS-mapped account.
    Do $$$AssertNotEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("user", $Username), ##class(OcuPilot.Kernel.EntityRef).NormalizedId("user", $Parameter(..#SHIPPEDSET, "SYSTEMACCOUNTNAME")), "the signed-in account is not the predefined one, so the two refusals are separable")
    Set tSelf = $ClassMethod(..#SET, "UserObject", $Username, 0)
    Do ..Refused($Username, $ClassMethod(..#SET, "UserObject", $Username, 1), tSelf, "Enabled", $Parameter(..#SHIPPEDSET, "CURRENTUSER"))

    ; Any spelling: the id rule folds case, so a reference built from "_System" is the same key and
    ; earns the same verdict as one built from "_SYSTEM".
    Set tSystem = $Parameter(..#SHIPPEDSET, "SYSTEMACCOUNTNAME")
    Set tSpelled = $ZConvert($Extract(tSystem, 1, 2), "U") _ $ZConvert($Extract(tSystem, 3, *), "L")
    Do $$$AssertNotEquals(tSpelled, tSystem, "the second spelling really differs from the first: " _ tSpelled)
    Do ..Refused(tSpelled, $ClassMethod(..#SET, "UserObject", tSystem, 1), $ClassMethod(..#SET, "UserObject", tSystem, 0), "Enabled", $Parameter(..#SHIPPEDSET, "SYSTEMACCOUNT"))
}

/// <p>AC4, AD-10: disabling the only account that holds <code>%All</code> is refused. The census is
/// answered through <method>OcuPilot.Test.ProposalFixture.ArmLastAllHolder</method>, because an
/// instance with several holders has no last one and stripping the role from a real account is the
/// one thing this suite must not do. The census's own query is exercised by
/// <method>TestTheCensusCountsAUserHoldingAllThroughACustomRole</method>.</p>
/// <p>Mutation: return <code>pLast = 0</code> unconditionally from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.LastAllHolder</method> -- this goes red, and so does
/// the arming leg below it.</p>
Method TestDisablingTheLastAllHolderIsRefused()
{
    Set tName = $Parameter(..#FIXTURE, "USERALLHOLDER")
    Set tFresh = $ClassMethod(..#SET, "UserObject", tName, 1, $Parameter(..#FIXTURE, "USERALLROLE"))
    Set tPayload = $ClassMethod(..#SET, "UserObject", tName, 0, $Parameter(..#FIXTURE, "USERALLROLE"))

    ; Disarmed first: this instance has several %All holders, so the shipped census says the target
    ; is not the last one and the write reaches the gates behind the set.
    Do $ClassMethod(..#FIXTURE, "ArmProhibited", ..#SET)
    Set tSC = $ClassMethod(..#SET, "Ask", tFresh, tPayload, $ClassMethod(..#SET, "Diff", "Enabled"), tName, "user", .tProhibits, .tCode, ..#TOOL)
    Do $$$AssertStatusOK(tSC, "the shipped census answers: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tProhibits, 0, "and this instance's other holders mean the target is not the last one, code was '" _ tCode _ "'")

    Do $ClassMethod(..#FIXTURE, "ArmLastAllHolder", 1)
    Do ..Refused(tName, tFresh, tPayload, "Enabled", $Parameter(..#SHIPPEDSET, "LASTALLHOLDER"))
}

/// <p>AC5, AD-10: a <code>Roles</code> delta that adds <code>%All</code>, any <code>%Admin_</code>
/// role, or a custom role that grants <code>%All</code> is refused; a delta that adds an ordinary
/// role is not, and neither is one that only removes a role.</p>
/// <p>Mutation: compare the payload's roles against nothing instead of against the live target in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilege</method> -- the removal leg reddens,
/// because an account that already holds a privileged role sends it back on every write.</p>
Method TestARoleDeltaThatGrantsPrivilegeIsRefused()
{
    Set tName = ..Target()
    Set tOrdinary = $Parameter(..#FIXTURE, "USERINITIALROLE")
    Set tFresh = $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary)
    Set tCode = $Parameter(..#SHIPPEDSET, "PRIVILEGEGRANT")

    Do ..Refused(tName, tFresh, $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary _ ",%All"), "Roles", tCode)
    Do ..Refused(tName, tFresh, $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary _ ",%Admin_Secure"), "Roles", tCode)
    Do ..Refused(tName, tFresh, $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary _ "," _ $Parameter(..#FIXTURE, "USERALLROLE")), "Roles", tCode)

    Do $ClassMethod(..#FIXTURE, "ArmProhibited", ..#SET)
    Set tSC = $ClassMethod(..#SET, "Ask", tFresh, $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary _ "," _ $Parameter(..#FIXTURE, "USERORDINARYROLE")), $ClassMethod(..#SET, "Diff", "Roles"), tName, "user", .tProhibits, .tOut, ..#TOOL)
    Do $$$AssertStatusOK(tSC, "the set answers the ordinary add")
    Do $$$AssertEquals(tProhibits, 0, "adding an ordinary role is not prohibited, code was '" _ tOut _ "'")

    ; A privileged role the account already holds travels in every payload (AD-4), so the delta is
    ; what decides: dropping it is a removal, not a grant.
    Set tHeld = $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary _ ",%All")
    Set tSC = $ClassMethod(..#SET, "Ask", tHeld, $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary), $ClassMethod(..#SET, "Diff", "Roles"), tName, "user", .tProhibits, .tOut, ..#TOOL)
    Do $$$AssertStatusOK(tSC, "the set answers the removal")
    Do $$$AssertEquals(tProhibits, 0, "removing a privileged role is not a grant, code was '" _ tOut _ "'")

    Set tSC = $ClassMethod(..#SET, "Ask", tHeld, tHeld, $ClassMethod(..#SET, "Diff", "Roles"), tName, "user", .tProhibits, .tOut, ..#TOOL)
    Do $$$AssertStatusOK(tSC, "the set answers an unchanged role list")
    Do $$$AssertEquals(tProhibits, 0, "and sending back the roles the account holds changes nothing, code was '" _ tOut _ "'")
}

/// <p>AD-10: the privileged-role match is case-insensitive, the way the instance itself resolves a
/// role name -- every other leg in this class adds <code>%All</code> or <code>%Admin_Secure</code>
/// in their own already-canonical spelling, so none of them would notice if the fold were lost.</p>
/// <p>Mutation: in <method>OcuPilot.Kernel.Proposal.Prohibited.IsPrivilegedRole</method>, compare
/// <var>pRole</var> against <parameter>ALLROLE</parameter> and <parameter>ADMINROLEPREFIX</parameter>
/// without folding case (drop both <code>$ZConvert(...,"U")</code> calls on the compared side) --
/// this goes red, because every other privilege-grant leg here sends the canonical spelling and
/// would stay green.</p>
Method TestARoleAddedInADifferentCaseIsStillRecognizedAsPrivileged()
{
    Set tName = ..Target()
    Set tOrdinary = $Parameter(..#FIXTURE, "USERINITIALROLE")
    Set tFresh = $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary)
    Set tCode = $Parameter(..#SHIPPEDSET, "PRIVILEGEGRANT")

    Do ..Refused(tName, tFresh, $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary _ ",%all"), "Roles", tCode)
    Do ..Refused(tName, tFresh, $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary _ ",%ADMIN_secure"), "Roles", tCode)
}

/// <p>AC4, AD-10: every change to <code>EscalationRoles</code> is refused, and a field outside the
/// reviewed two is refused as unreviewed even though no tool can author one.</p>
/// <p>Mutation: remove <code>EscalationRoles</code> from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.AlwaysProhibitedFields</method> and its branch from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.User</method> -- the first leg reddens on the code it
/// earns instead.</p>
Method TestAChangedEscalationRoleAndAnUnreviewedFieldAreRefused()
{
    Set tName = ..Target()
    Set tFresh = $ClassMethod(..#SET, "UserObject", tName, 1, $Parameter(..#FIXTURE, "USERINITIALROLE"))
    Do ..Refused(tName, tFresh, $ClassMethod(..#SET, "UserObject", tName, 1, $Parameter(..#FIXTURE, "USERINITIALROLE"), "%Developer"), "EscalationRoles", $Parameter(..#SHIPPEDSET, "PRIVILEGEGRANT"))
    Do ..Refused(tName, tFresh, $ClassMethod(..#SET, "UserObject", tName, 1, $Parameter(..#FIXTURE, "USERINITIALROLE"), "", "after"), "FullName", $Parameter(..#SHIPPEDSET, "UNCOVEREDFIELD"))
    Do $$$AssertEquals($ListToString($ClassMethod(..#SHIPPEDSET, "AlwaysProhibitedFields", "user")), "EscalationRoles", "one user field carries an always-prohibited predicate of its own")
}

/// <p>AC5's second half: the census asks the instance for each account's recursed role set, so an
/// account that holds <code>%All</code> only through a custom role is counted. The probe account
/// declares <parameter>OcuPilot.Test.ProposalFixture.USERALLROLE</parameter> and never
/// <code>%All</code> itself, so a substring match on the declared list would miss it.</p>
/// <p>Mutation: read the declared <code>Roles</code> column instead of the recursed set in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.HoldsAll</method> -- this goes red.</p>
Method TestTheCensusCountsAUserHoldingAllThroughACustomRole()
{
    Set tName = $Parameter(..#FIXTURE, "USERALLHOLDER")
    Set tDeclared = $ClassMethod(..#FIXTURE, "UserField", tName, "Roles")
    Do $$$AssertEquals(tDeclared, $Parameter(..#FIXTURE, "USERALLROLE"), "the probe account declares the custom role and nothing else")
    Do $$$AssertEquals(tDeclared [ "%All", 0, "and its declared list does not spell %All at all")

    Set tSC = $ClassMethod(..#SHIPPEDSET, "HoldsAll", tName, .tHolds)
    Do $$$AssertStatusOK(tSC, "the census asks the instance: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tHolds, 1, "and counts the account as an %All holder")

    Set tSC = $ClassMethod(..#SHIPPEDSET, "HoldsAll", ..Target(), .tHolds)
    Do $$$AssertStatusOK(tSC, "it answers for an ordinary account too")
    Do $$$AssertEquals(tHolds, 0, "which holds no %All")

    ; And the whole-population query behind it runs: this instance has more than one holder, so no
    ; account is the last one, which is the answer the arming seam replaces in the refusal leg.
    Set tSC = $ClassMethod(..#SHIPPEDSET, "LastAllHolder", tName, .tLast)
    Do $$$AssertStatusOK(tSC, "the census over the whole population answers")
    Do $$$AssertEquals(tLast, 0, "and this instance's other holders mean the probe account is not the last one")
    Set tSC = $ClassMethod(..#SHIPPEDSET, "LastAllHolder", ..Target(), .tLast)
    Do $$$AssertStatusOK(tSC, "it answers for an account that holds none")
    Do $$$AssertEquals(tLast, 0, "which cannot be the last holder of a role it does not hold")
}

/// <p>AC4, AD-10: the census's own <b>yes</b>, and the filter that decides it. The shipped body
/// runs in full over the real population -- the <code>%SYS</code> query, the enabled filter, the
/// canonical self-skip and the loop; only "does this account hold <code>%All</code>" is armed
/// (<method>OcuPilot.Test.ProposalFixture.ArmAllHolders</method>), because an instance with several
/// real holders has no last one and stripping the role from a real account is the one thing this
/// suite must not do.</p>
/// <p><b>Two-sided on purpose.</b> With the only other holder <i>disabled</i> the target is the
/// last one; with it enabled the target is not. A one-sided leg would pass against a census that
/// always answers the same thing.</p>
/// <p>Mutations: drop the enabled-column filter from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.LastAllHolder</method> (the disabled holder then
/// counts and the first leg reddens), or answer <code>pLast = 0</code> unconditionally (the first
/// leg reddens too).</p>
Method TestOnlyAnEnabledHolderCountsAsAnotherAllHolder()
{
    Set tName = $Parameter(..#FIXTURE, "USERALLHOLDER")
    Set tDisabled = $Parameter(..#FIXTURE, "USERALLHOLDERDISABLED")
    Set tSecond = $Parameter(..#FIXTURE, "USERALLHOLDERSECOND")
    ; The population really carries all three, and the enabled flags really differ -- read off the
    ; instance, so neither leg below rests on what the fixture meant to create.
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserField", tName, "Enabled"), 1, "the target holder is enabled on the instance")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserField", tSecond, "Enabled"), 1, "the second holder is enabled")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserField", tDisabled, "Enabled"), 0, "and the third is disabled")

    ; Armed so the target and the DISABLED account are the only holders: the loop finds no other
    ; account that could sign in with %All, so the target is the last usable holder.
    Do $ClassMethod(..#FIXTURE, "ArmAllHolders", tName _ "," _ tDisabled)
    Set tSC = $ClassMethod(..#SET, "LastAllHolder", tName, .tLast)
    Do $$$AssertStatusOK(tSC, "the census answers: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tLast, 1, "a disabled holder is not another holder, so the target is the last one")

    ; Armed so the other holder is ENABLED instead: the same loop now finds it and the target is
    ; not the last one. Same code, opposite answer.
    Do $ClassMethod(..#FIXTURE, "ArmAllHolders", tName _ "," _ tSecond)
    Set tSC = $ClassMethod(..#SET, "LastAllHolder", tName, .tLast)
    Do $$$AssertStatusOK(tSC, "the census answers again: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tLast, 0, "an enabled holder is another holder, so the target is not the last one")

    ; And the yes reaches the refusal through the shipped census rather than through
    ; ArmLastAllHolder, which is the seam TestDisablingTheLastAllHolderIsRefused drives.
    Do $ClassMethod(..#FIXTURE, "ArmAllHolders", tName _ "," _ tDisabled)
    Set tFresh = $ClassMethod(..#SET, "UserObject", tName, 1, $Parameter(..#FIXTURE, "USERALLROLE"))
    Do ..Refused(tName, tFresh, $ClassMethod(..#SET, "UserObject", tName, 0, $Parameter(..#FIXTURE, "USERALLROLE")), "Enabled", $Parameter(..#SHIPPEDSET, "LASTALLHOLDER"))
}

/// <p>AD-10: the two shapes <method>OcuPilot.Kernel.Proposal.Prohibited.RoleNames</method>
/// declares. The vendor <code>GET</code> answers <code>Roles</code> as an array, which every other
/// leg here sends; this one sends the comma-separated string the same property takes on its way
/// into <class>Security.Users</class>, so that branch has an executed test host. Read as nothing it
/// would empty the role delta and permit <b>every</b> grant.</p>
/// <p>Mutation: return without parsing in the string branch of <code>RoleNames</code> -- the delta
/// is empty, nothing is refused, and this goes red.</p>
Method TestARoleDeltaIsReadWhenTheRolesMemberIsAString()
{
    Set tName = ..Target()
    Set tOrdinary = $Parameter(..#FIXTURE, "USERINITIALROLE")
    Set tFresh = $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary, "", "before", 1)
    ; The shape really is a string on both sides, or the leg would be a second array test.
    Do $$$AssertEquals(##class(%DynamicAbstractObject).%FromJSON(tFresh).%GetTypeOf("Roles"), "string", "the fixture sends Roles as a string, not an array")

    Do ..Refused(tName, tFresh, $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary _ ",%All", "", "before", 1), "Roles", $Parameter(..#SHIPPEDSET, "PRIVILEGEGRANT"))
    Do ..Refused(tName, tFresh, $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary _ "," _ $Parameter(..#FIXTURE, "USERALLROLE"), "", "before", 1), "Roles", $Parameter(..#SHIPPEDSET, "PRIVILEGEGRANT"))

    ; And the permitted add is still permitted through the same branch, so the leg above is not
    ; passing because the string shape refuses everything.
    Do $ClassMethod(..#FIXTURE, "ArmProhibited", ..#SET)
    Set tSC = $ClassMethod(..#SET, "Ask", tFresh, $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary _ "," _ $Parameter(..#FIXTURE, "USERORDINARYROLE"), "", "before", 1), $ClassMethod(..#SET, "Diff", "Roles"), tName, "user", .tProhibits, .tOut, ..#TOOL)
    Do $$$AssertStatusOK(tSC, "the set answers the ordinary add in string shape")
    Do $$$AssertEquals(tProhibits, 0, "adding an ordinary role is still not prohibited, code was '" _ tOut _ "'")
}

/// <p>AD-10: an <code>Enabled</code> value the predicate cannot read as on is treated as a
/// disable, so the three refusals behind that guard still apply. An unreadable stored payload
/// renders every member <code>""</code>
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.ParsedObject</method>), which is the reachable
/// case; a spelling the guard does not know is the residual one.</p>
/// <p><code>_SYSTEM</code> is the target because its refusal needs no census and no signed-in
/// account, and this leg only ever asks the set -- nothing is minted and no <code>PUT</code> is
/// issued.</p>
/// <p>Mutation: answer <code>0</code> for either arm in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.IsOff</method> -- the matching leg reddens, because
/// the proposal stops reading as a disable and <code>Enabled</code> is a reviewed field, so the
/// unreviewed-field sweep does not catch it either.</p>
Method TestAnEnabledValueTheGuardCannotReadAsOnIsADisable()
{
    Set tSystem = $Parameter(..#SHIPPEDSET, "SYSTEMACCOUNTNAME")
    Set tFresh = $ClassMethod(..#SET, "UserObject", tSystem, 1)
    Set tExpected = $Parameter(..#SHIPPEDSET, "SYSTEMACCOUNT")

    ; An empty object: every member renders "", which is what an unreadable payload looks like.
    Do ..Refused(tSystem, tFresh, "{}", "Enabled", tExpected)

    ; A spelling the guard does not know. Asserted to render as itself first, so the leg cannot
    ; pass by accidentally rendering "" and taking the arm above.
    Set tOdd = ##class(%DynamicAbstractObject).%FromJSON(tFresh)
    Do tOdd.%Set("Enabled", "Yes", "string")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).Display(tOdd.%Get("Enabled"), tOdd.%GetTypeOf("Enabled")), "Yes", "the odd spelling renders as itself, not as an empty member")
    Do ..Refused(tSystem, tFresh, tOdd.%ToJSON(), "Enabled", tExpected)

    ; The numeric arm, the third shape the guard's own doc comment declares. Both sides, and each
    ; asserted to render as a digit first so neither can pass by taking one of the arms above.
    Set tZero = ##class(%DynamicAbstractObject).%FromJSON(tFresh)
    Do tZero.%Set("Enabled", 0, "number")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).Display(tZero.%Get("Enabled"), tZero.%GetTypeOf("Enabled")), 0, "a numeric off renders as its digit")
    Do ..Refused(tSystem, tFresh, tZero.%ToJSON(), "Enabled", tExpected)

    Set tOne = ##class(%DynamicAbstractObject).%FromJSON($ClassMethod(..#SET, "UserObject", ..Target(), 0))
    Do tOne.%Set("Enabled", 1, "number")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).Display(tOne.%Get("Enabled"), tOne.%GetTypeOf("Enabled")), 1, "and a numeric on renders as its digit")
    Do $ClassMethod(..#FIXTURE, "ArmProhibited", ..#SET)
    Set tSC = $ClassMethod(..#SET, "Ask", $ClassMethod(..#SET, "UserObject", ..Target(), 0), tOne.%ToJSON(), $ClassMethod(..#SET, "Diff", "Enabled"), ..Target(), "user", .tProhibits, .tOut, ..#TOOL)
    Do $$$AssertStatusOK(tSC, "the set answers a numeric enable")
    Do $$$AssertEquals(tProhibits, 0, "a numeric on is read as on, so the disable refusals do not apply, code was '" _ tOut _ "'")
}

/// <p>AD-10: a role whose <b>name</b> says nothing can still carry an administrative resource, and
/// granting it is a privilege grant through a path. Every other privilege-grant leg here adds
/// <code>%All</code>, an <code>%Admin_</code>-named role or a role that grants <code>%All</code> as
/// a role, so the recursed-role test alone satisfied all of them -- and IRIS ships no role whose
/// name carries the prefix at all.</p>
/// <p>The roles are read off the instance first, so neither half rests on a remembered fact:
/// <code>%Manager</code> must recurse to no privileged <i>name</i> and must carry a privileged
/// <i>resource</i>, and the ordinary role must carry none.</p>
/// <p>Mutation: drop the <method>OcuPilot.Kernel.Proposal.Prohibited.RoleGrantsPrivilege</method>
/// call from <method>OcuPilot.Kernel.Proposal.Prohibited.RoleEscalates</method> -- this goes red and
/// nothing else in the class does.</p>
Method TestARoleCarryingAnAdministrativeResourceIsRefusedThoughItsNameSaysNothing()
{
    Set tName = ..Target()
    Set tOrdinary = $Parameter(..#FIXTURE, "USERINITIALROLE")
    Set tFresh = $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary)
    Set tCode = $Parameter(..#SHIPPEDSET, "PRIVILEGEGRANT")
    Set tAdminPrefix = $Parameter(..#SHIPPEDSET, "ADMINROLEPREFIX")

    Set tManagerRoles = ""
    Do $SYSTEM.Security.GetRecursedRoleSet("%Manager", .tManagerRoles)
    Do $$$AssertEquals(tManagerRoles [ tAdminPrefix, 0, "%Manager's recursed role set names no " _ tAdminPrefix _ " role: " _ tManagerRoles)
    Do $$$AssertEquals(tManagerRoles [ "%All", 0, "and no %All either, so the name tests cannot be what refuses it: " _ tManagerRoles)
    Set tManagerResources = $ClassMethod(..#FIXTURE, "RoleResources", "%Manager")
    Do $$$AssertTrue(tManagerResources [ tAdminPrefix, "%Manager carries an " _ tAdminPrefix _ " resource: " _ tManagerResources)

    Do ..Refused(tName, tFresh, $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary _ ",%Manager"), "Roles", tCode)

    ; The other side: the ordinary role this suite adds carries no administrative resource, so the
    ; resource test must not turn every role add into a refusal.
    Set tOrdinaryAdd = $Parameter(..#FIXTURE, "USERORDINARYROLE")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "RoleResources", tOrdinaryAdd) [ tAdminPrefix, 0, tOrdinaryAdd _ " carries no administrative resource")
    Do $ClassMethod(..#FIXTURE, "ArmProhibited", ..#SET)
    Set tSC = $ClassMethod(..#SET, "Ask", tFresh, $ClassMethod(..#SET, "UserObject", tName, 1, tOrdinary _ "," _ tOrdinaryAdd), $ClassMethod(..#SET, "Diff", "Roles"), tName, "user", .tProhibits, .tOut, ..#TOOL)
    Do $$$AssertStatusOK(tSC, "the set answers the ordinary add")
    Do $$$AssertEquals(tProhibits, 0, "adding a role that carries no administrative resource is still permitted, code was '" _ tOut _ "'")
}

/// <p>AD-10, AD-21: which population rows the census may count. An unauthenticated placeholder is
/// answered <code>enabled</code> by the instance's own user list and holds <code>%All</code> on a
/// Minimal-security instance, so counting one would say "some other account still holds
/// <code>%All</code>" about an account nobody can sign in as -- and the last usable holder could
/// then be disabled. The list of placeholders has one home
/// (<parameter>OcuPilot.Screen.Gate.ANONYMOUSPRINCIPALS</parameter>) and this is a third reader of
/// it, not a second copy.</p>
/// <p>The placeholders are read off the instance's own population first, so the leg cannot pass
/// against names the instance does not carry.</p>
/// <p>Mutation: drop the
/// <method>OcuPilot.Screen.Gate.IsAuthenticatedPrincipal</method> call from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.CountsAsHolder</method> -- the placeholder
/// assertions go red.</p>
Method TestAnUnauthenticatedPlaceholderNeverCountsAsAnAllHolder()
{
    Set tAnonymous = $Parameter("OcuPilot.Screen.Gate", "ANONYMOUSPRINCIPALS")
    Do $$$AssertNotEquals(tAnonymous, "", "the one home for the placeholder names answers")
    Set tSeen = 0
    For tI = 1:1:$Length(tAnonymous, ",") {
        Set tOne = $Piece(tAnonymous, ",", tI)
        If tOne = "" Continue
        ; Enabled is passed as the instance's own affirmative spelling, so the refusal below can
        ; only come from the name and never from the enabled filter.
        Do $$$AssertEquals($ClassMethod(..#SHIPPEDSET, "CountsAsHolder", tOne, "Yes"), 0, tOne _ " never counts as another %All holder, however the list answers its enabled column")
        Set tSeen = tSeen + 1
    }
    Do $$$AssertTrue(tSeen > 0, "the placeholder list carried names, so the loop above ran over something")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "UserField", "UnknownUser", "Enabled"), 1, "and the instance really does answer UnknownUser enabled, which is what makes the filter load-bearing")

    ; The rest of the predicate, so the guard above cannot be the only thing it does.
    Do $$$AssertEquals($ClassMethod(..#SHIPPEDSET, "CountsAsHolder", ..Target(), "Yes"), 1, "an ordinary enabled account counts")
    Do $$$AssertEquals($ClassMethod(..#SHIPPEDSET, "CountsAsHolder", ..Target(), 1), 1, "and so does one whose enabled column reads 1")
    Do $$$AssertEquals($ClassMethod(..#SHIPPEDSET, "CountsAsHolder", ..Target(), "No"), 0, "a disabled account does not")
    Do $$$AssertEquals($ClassMethod(..#SHIPPEDSET, "CountsAsHolder", ..Target(), "maybe"), 0, "and neither does one whose enabled column cannot be read as enabled")
    Do $$$AssertEquals($ClassMethod(..#SHIPPEDSET, "CountsAsHolder", "", "Yes"), 0, "an empty name does not")
}

/// <p>AC6, AD-13 as amended: the user id rule folds case the way the instance resolves an account
/// name, so two spellings are one reference key and one AD-34 lock. The rule is compared with the
/// port's own answers rather than with a sentence.</p>
/// <p>Mutation: return the id verbatim for <code>user</code> in
/// <method>OcuPilot.Kernel.EntityRef.NormalizedId</method> -- this goes red on the key comparison.</p>
Method TestTheUserRuleFoldsCaseTheWayTheInstanceResolvesIt()
{
    Set tName = $Parameter(..#FIXTURE, "USERTARGETMIXEDCASE")
    Set tUpper = $ZConvert(tName, "U")
    Set tLower = $ZConvert(tName, "L")
    Do $$$AssertNotEquals(tUpper, tName, "the probe account's own spelling is neither upper nor lower case")

    Set tFirstKey = ""
    For tSpelling = tName, tUpper, tLower {
        Set tSC = ..Fresh(tSpelling, .tObject)
        Do $$$AssertStatusOK(tSC, "the instance resolves '" _ tSpelling _ "': " _ $System.Status.GetErrorText(tSC))
        Do $$$AssertTrue($IsObject(tObject), "answering the account")
        Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("user", tSpelling), tLower, "and the rule folds '" _ tSpelling _ "' to the one canonical spelling")
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.EntityRef).Key("user", "instance", tSpelling, .tKey), "a reference key builds from it")
        If tFirstKey = "" Set tFirstKey = tKey
        Do $$$AssertEquals(tKey, tFirstKey, "and every spelling builds the same key")
    }

    ; A trailing space is not a spelling the instance resolves, so the rule does not strip one.
    Set tSC = ..Fresh(tName _ " ", .tObject)
    Do $$$AssertStatusNotOK(tSC, "a trailing space resolves to no account")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("user", tName _ " "), tLower _ " ", "and the rule leaves it in place rather than inventing a resolution")
}

}
