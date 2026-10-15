/// <p>Pins the proposal store's target key (AD-6, AD-13, AD-34): <code>ProposalTargetIdx</code> is keyed by the digest of a proposal's
/// target and not by the target, so a target of any length the store accepts is stored whole and a longer one is refused, never cut; the
/// sibling cancel finds its siblings by that key and closes only a row whose target is exactly the claimed one; and a proposal stored
/// before the key existed keeps each column in its data slot and is given its key, and its index entry, by the install step, which a
/// second run leaves alone.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot's protected state, an account holding <code>%All</code>, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because one test runs OcuPilot's production install. Every row it seeds
/// names a user starting with <parameter>OcuPilot.Test.ProposalFixture.PROBEPREFIX</parameter>, removed in
/// <method>OnAfterOneTest</method> with every index entry it planted.</p>
Class OcuPilot.Test.ProposalTargetKey Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

Parameter PROBEUSER = "OcuPilotProbeProposalTargetKey";

Parameter OTHERUSER = "OcuPilotProbeProposalTargetKeyTwo";

Parameter STORE = "OcuPilot.Kernel.State.Propose";

Parameter INSTALLER = "OcuPilot.Install.Installer";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ProposalTargetKey runs OcuPilot's production install, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was run.")
    }
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tLoc = ..IndexLocation()
    Set tRef = ""
    For {
        Set tRef = $Order(^||OcuPilotTargetKeyStale(tRef))
        If tRef = "" Quit
        Set tId = ""
        For {
            Set tId = $Order(^||OcuPilotTargetKeyStale(tRef, tId))
            If tId = "" Quit
            If tLoc '= "" Kill @tLoc@("ProposalTargetIdx", tRef, " LIVE", tId)
        }
    }
    Kill ^||OcuPilotTargetKeyStale
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).Remove(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>The global the proposal store keeps its indices in, from the compiled storage definition.</p>
ClassMethod IndexLocation() As %String
{
    Set tStorage = ##class(%Dictionary.CompiledStorage).%OpenId(..#STORE _ "||Default")
    Quit $Select($IsObject(tStorage): tStorage.IndexLocation, 1: "")
}

/// <p>Whether <code>ProposalTargetIdx</code> holds an entry for the row <var>pId</var> under <var>pTargetKey</var> and the state
/// <var>pState</var> (the index orders a state in upper case behind a space).</p>
ClassMethod IndexHas(pTargetKey As %String, pState As %String, pId As %String) As %Boolean
{
    Set tLoc = ..IndexLocation()
    If tLoc = "" Quit 0
    Quit ''$Data(@tLoc@("ProposalTargetIdx", pTargetKey, " " _ $ZConvert(pState, "U"), pId))
}

/// <p>A target the size of the longest resend target: 100 message ids of 19 digits, built through
/// <method>OcuPilot.Kernel.EntityRef.Key</method> so the separator is the one the store holds. <var>pLast</var> replaces the last id's
/// final digit, which names another target of the same length.</p>
ClassMethod LongRef(pLast As %Integer = 1) As %String
{
    Set tIds = ""
    For tI = 1:1:100 {
        Set tId = "9" _ $Translate($Justify(tI, 18), " ", "0")
        If tI = 100 Set tId = $Extract(tId, 1, 18) _ pLast
        Set tIds = tIds _ $Select(tI > 1: ",", 1: "") _ tId
    }
    Do ##class(OcuPilot.Kernel.EntityRef).Key("interop-message", "USER", tIds, .tKey)
    Quit tKey
}

/// <p>A short target: the web application <var>pName</var>.</p>
ClassMethod ShortRef(pName As %String = "/csp/ocupilotprobetargetkey") As %String
{
    Do ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", pName, .tKey)
    Quit tKey
}

/// <p>Mint one live proposal on <var>pTargetRef</var> for <var>pUser</var>, answer the store's status, and its id in <var>pKey</var>.</p>
ClassMethod SeedRaw(pTargetRef As %String, pUser As %String, Output pKey As %String) As %Status
{
    Kill tValues
    Set tValues("user") = pUser
    Set tValues("convKey") = "probe-target-key-conv"
    Set tValues("turnKey") = "probe-target-key-turn"
    Set tValues("toolName") = "webapp.list.update"
    Set tValues("targetRef") = pTargetRef
    Set tValues("fingerprint") = "0"
    Set tValues("arguments") = "{}"
    Set tValues("payload") = "{}"
    Set tValues("diff") = "[]"
    Set tValues("unchangedCount") = 0
    Quit ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .pKey, .tToken)
}

/// <p>Seed one live proposal on <var>pTargetRef</var> for <var>pUser</var> and answer its id.</p>
Method Seed(pTargetRef As %String, pUser As %String = {..#PROBEUSER}) As %String
{
    Set tSC = ..SeedRaw(pTargetRef, pUser, .tKey)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded: " _ $Select($$$ISERR(tSC): $System.Status.GetErrorText(tSC), 1: ""))
    If $$$ISERR(tSC) Quit ""
    Quit tKey
}

/// <p>How many proposals <var>pUser</var> owns, or -1 when the count cannot be read.</p>
ClassMethod CountFor(pUser As %String) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(UserName) = ?", pUser)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit tRS.%GetData(1)
}

/// <p>Run <var>pSql</var> with the bound values and answer its <code>SQLCODE</code>.</p>
ClassMethod Exec(pSql As %String, pFirst As %String, pSecond As %String = "") As %Integer
{
    If pSecond = "" {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pFirst)
    } Else {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pFirst, pSecond)
    }
    Quit tRS.%SQLCODE
}

/// <p>Leave proposal <var>pKey</var> as a row stored before <property>TargetKey</property> existed is: no key.</p>
ClassMethod NullKey(pKey As %String) As %Integer
{
    Quit ..Exec("UPDATE OcuPilot_Kernel_State.Proposal SET TargetKey = NULL WHERE %EXACT(ProposalKey) = ?", pKey)
}

/// <p>The stored column <var>pField</var> of proposal <var>pKey</var>.</p>
ClassMethod Field(pKey As %String, pField As %String) As %String
{
    Quit ##class(OcuPilot.Test.ProposalFixture).Field(pKey, pField)
}

/// <p>The row id of proposal <var>pKey</var>, which is what an index entry names.</p>
ClassMethod IdOf(pKey As %String) As %String
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ProposalKey) = ?", pKey)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit ""
    Quit tRS.%GetData(1)
}

/// <p>Claim proposal <var>pKey</var> on <var>pTargetRef</var> at its current version; 1 when the claim won.</p>
Method Claim(pKey As %String, pTargetRef As %String) As %Boolean
{
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedRowVersion", pKey, .tVersion), "the claimed row's version reads")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedClaimAndClose", pKey, tVersion, pTargetRef, .tWon, .tTerminal), "the claim runs")
    Quit +$Get(tWon)
}

/// <p>Plant the entry the previous index definition left for row <var>pId</var>: the target itself as the first subscript, which only a
/// short target can be.</p>
Method PlantStale(pTargetRef As %String, pId As %String)
{
    Set tLoc = ..IndexLocation()
    Do $$$AssertNotEquals(tLoc, "", "the index location reads")
    If tLoc = "" Quit
    Set @tLoc@("ProposalTargetIdx", pTargetRef, " LIVE", pId) = ""
    Set ^||OcuPilotTargetKeyStale(pTargetRef, pId) = ""
}

/// <p>AC2, AC3: a row stores the digest of its target as its key, and the index holds its entry under that key: for a short target, and for
/// 100 ids of 19 digits, about 2,000 characters, which the store keeps whole. A row with no target has no key.</p>
/// <p>Mutation (Rule 19): key <code>ProposalTargetIdx</code> by <code>TargetRef</code> in <class>OcuPilot.Kernel.State.Propose</class> --
/// the entry assertions go red for the short target and the long one cannot be stored.</p>
Method TestTheKeyIsTheDigestOfTheTargetAndALongTargetIsStoredWhole()
{
    For tCase = $ListBuild("short", ..ShortRef()), $ListBuild("100 ids of 19 digits", ..LongRef()) {
        Set tName = $List(tCase, 1)
        Set tRef = $List(tCase, 2)
        Set tKey = ..Seed(tRef)
        If tKey = "" Continue
        Set tDigest = $ClassMethod(..#STORE, "TargetLockKey", tRef)
        Do $$$AssertEquals($Length(tDigest), 64, tName _ ": the digest is 64 characters")
        Do $$$AssertTrue($Select(tName = "short": $Length(tRef) < 400, 1: $Length(tRef) > 2000), tName _ ": the target is " _ $Length(tRef) _ " characters")
        Do $$$AssertEquals(..Field(tKey, "TargetRef"), tRef, tName _ ": the stored target is the whole target")
        Do $$$AssertEquals(..Field(tKey, "TargetKey"), tDigest, tName _ ": the stored key is the digest of it")
        Do $$$AssertEquals(..IndexHas(tDigest, "live", ..IdOf(tKey)), 1, tName _ ": the index holds the row under its key")
    }
    Set tUnscoped = ..Seed("")
    If tUnscoped '= "" Do $$$AssertEquals(..Field(tUnscoped, "TargetKey"), "", "a row with no target has no key")
}

/// <p>AC3, AD-34: a claim closes the live proposals on its own target, whoever owns them, for a short target and for the longest one,
/// and leaves alone a proposal on another target and a proposal that carries the claimed target's key but another target.</p>
/// <p>Mutation (Rule 19): drop the <code>%EXACT(TargetRef)</code> test from the sibling update in
/// <method>OcuPilot.Kernel.State.Propose.GuardedClaimAndClose</method> -- the row with the forged key is closed and this goes red.</p>
Method TestASiblingCancelClosesItsSiblingsByTheExactTargetAndLeavesOthersAlone()
{
    For tCase = $ListBuild("short", ..ShortRef(), ..ShortRef("/csp/ocupilotprobetargetkeyother")), $ListBuild("100 ids of 19 digits", ..LongRef(), ..LongRef(2)) {
        Set tName = $List(tCase, 1)
        Set tRef = $List(tCase, 2)
        Set tOther = $List(tCase, 3)
        Set tWinner = ..Seed(tRef)
        Set tSibling = ..Seed(tRef, ..#OTHERUSER)
        Set tElsewhere = ..Seed(tOther)
        Set tForged = ..Seed(tOther)
        If (tWinner = "") || (tSibling = "") || (tElsewhere = "") || (tForged = "") Continue
        Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.Proposal SET TargetKey = ? WHERE %EXACT(ProposalKey) = ?", $ClassMethod(..#STORE, "TargetLockKey", tRef), tForged), 0, tName _ ": a row is given the claimed target's key and another target")
        Do $$$AssertEquals(..Claim(tWinner, tRef), 1, tName _ ": the claim wins")
        Do $$$AssertEquals(..Field(tSibling, "State") _ "|" _ ..Field(tSibling, "ClosedReason"), "canceled|sibling", tName _ ": the sibling on the same target is closed as a sibling")
        Do $$$AssertEquals(..Field(tElsewhere, "State"), "live", tName _ ": a proposal on another target is untouched")
        Do $$$AssertEquals(..Field(tForged, "State"), "live", tName _ ": so is the one that carries the key and not the target")
    }
}

/// <p>AC3: a proposal stored before the key existed is not found by the sibling cancel until the install step has run; the step gives it
/// its key and its index entry, removes the entry the previous index definition left for it, and then the claim closes it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Install.Installer.EnsureProposalTargetKeys</method> a no-op -- the key stays unset and
/// the sibling stays live. Skip <method>OcuPilot.Kernel.State.Propose.GuardedBuildIndices</method> in
/// <method>OcuPilot.Kernel.State.Propose.GuardedRebuildTargetKeys</method> -- the entry the old definition left stays.</p>
Method TestARowStoredBeforeTheKeyExistedIsFoundBySiblingCancelOnceTheStepHasRun()
{
    Set tRef = ..ShortRef()
    Set tDigest = $ClassMethod(..#STORE, "TargetLockKey", tRef)
    Set tWinner = ..Seed(tRef)
    Set tOld = ..Seed(tRef, ..#OTHERUSER)
    If (tWinner = "") || (tOld = "") Quit
    Set tOldId = ..IdOf(tOld)
    Do $$$AssertEquals(..NullKey(tOld), 0, "a row is left as one stored before the key existed is")
    Do $$$AssertEquals(..Field(tOld, "TargetKey"), "", "it has no key")
    Do $$$AssertEquals(..IndexHas(tDigest, "live", tOldId), 0, "and no index entry under its key")
    Do ..PlantStale(tRef, tOldId)

    Do $$$AssertStatusOK($ClassMethod(..#INSTALLER, "EnsureProposalTargetKeys", .tReports), "the install step runs")
    Do $$$AssertTrue($Get(tReports(1, "message")) [ "Gave ", "and reports that it gave rows a key: " _ $Get(tReports(1, "message")))
    Do $$$AssertEquals(..Field(tOld, "TargetKey"), tDigest, "the row has its key")
    Do $$$AssertEquals(..IndexHas(tDigest, "live", tOldId), 1, "and its index entry")
    Do $$$AssertEquals(..IndexHas(tRef, "live", tOldId), 0, "and the entry the old index definition left for it is gone")
    Do $$$AssertEquals(..Claim(tWinner, tRef), 1, "a claim on its target wins")
    Do $$$AssertEquals(..Field(tOld, "State") _ "|" _ ..Field(tOld, "ClosedReason"), "canceled|sibling", "and closes the row as its sibling")
}

/// <p>AC3: a second run of the step changes nothing: no row is given a key, the index is not purged, and a row with no target is not
/// written. The first run gives a key to every row that lacks one.</p>
/// <p>Mutation (Rule 19): build the index on every run in <method>OcuPilot.Kernel.State.Propose.GuardedRebuildTargetKeys</method> -- the
/// entry planted between the runs is purged and this goes red.</p>
Method TestASecondRunOfTheStepChangesNothing()
{
    Set tRef = ..ShortRef()
    Set tFirst = ..Seed(tRef)
    Set tSecond = ..Seed(tRef, ..#OTHERUSER)
    Set tUnscoped = ..Seed("")
    If (tFirst = "") || (tSecond = "") || (tUnscoped = "") Quit
    Do $$$AssertEquals(..NullKey(tFirst) + ..NullKey(tSecond), 0, "two rows are left as ones stored before the key existed are")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedRebuildTargetKeys", .tChanged1), "the first run")
    Do $$$AssertTrue(tChanged1 >= 2, "gives a key to at least those two rows: " _ tChanged1)
    Set tDigest = $ClassMethod(..#STORE, "TargetLockKey", tRef)
    Do $$$AssertEquals(..Field(tFirst, "TargetKey") _ "|" _ ..Field(tSecond, "TargetKey"), tDigest _ "|" _ tDigest, "both rows have their key")
    Set tFirstId = ..IdOf(tFirst)
    Do ..PlantStale(tRef, tFirstId)
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedRebuildTargetKeys", .tChanged2), "the second run")
    Do $$$AssertEquals(tChanged2, 0, "gives a key to no row")
    Do $$$AssertEquals(..IndexHas(tRef, "live", tFirstId), 1, "and does not purge the index")
    Do $$$AssertEquals(..Field(tUnscoped, "TargetKey"), "", "a row with no target still has no key")
    Do $$$AssertStatusOK($ClassMethod(..#INSTALLER, "EnsureProposalTargetKeys", .tReports), "the install step runs a third time")
    Do $$$AssertTrue($Get(tReports(1, "message")) [ "already carries", "and reports that every proposal already has its key: " _ $Get(tReports(1, "message")))
}

/// <p>AD-6, AD-13: a target of exactly <parameter>OcuPilot.Kernel.State.Propose.TARGETREFMAX</parameter> characters is stored whole, and one
/// character more is refused with an error and stores no row, so a stored target is always the target the user reviewed.</p>
/// <p>Mutation (Rule 19): cut the target at <parameter>TARGETREFMAX</parameter> in <method>OcuPilot.Kernel.State.Propose.GuardedMint</method>
/// in place of refusing it -- the status reads OK, a row is stored, and this goes red.</p>
Method TestATargetOverTheLimitIsRefusedAtTheMintAndTheLimitItselfIsStoredWhole()
{
    Set tMax = $Parameter(..#STORE, "TARGETREFMAX")
    Set tAtLimit = "limit|USER|" _ $Translate($Justify("", tMax - 11), " ", "a")
    Set tOver = tAtLimit _ "a"
    Do $$$AssertEquals($Length(tAtLimit), tMax, "the first target is exactly the limit long")
    Set tKey = ..Seed(tAtLimit)
    If tKey '= "" Do $$$AssertEquals(..Field(tKey, "TargetRef"), tAtLimit, "and is stored whole")
    Set tSC = ..SeedRaw(tOver, ..#OTHERUSER, .tOverKey)
    Do $$$AssertStatusNotOK(tSC, "a target one character over the limit is refused")
    Do $$$AssertEquals($Get(tOverKey), "", "and no proposal id is answered")
    Do $$$AssertEquals(..CountFor(..#OTHERUSER), 0, "and no row is stored for it")
}

/// <p>AC3: the production install runs the step, so a proposal stored before the key existed has its key once an install has finished.</p>
/// <p>Mutation (Rule 19): drop the <code>EnsureProposalTargetKeys</code> call from <method>OcuPilot.Install.Installer.Install</method>
/// -- the key stays unset and this goes red.</p>
Method TestTheProductionInstallGivesAStoredProposalItsKey()
{
    Set tRef = ..ShortRef()
    Set tKey = ..Seed(tRef)
    If tKey = "" Quit
    Do $$$AssertEquals(..NullKey(tKey), 0, "a row is left as one stored before the key existed is")
    Do $$$AssertStatusOK($ClassMethod(..#INSTALLER, "Install", ""), "the production install runs")
    Do $$$AssertEquals(..Field(tKey, "TargetKey"), $ClassMethod(..#STORE, "TargetLockKey", tRef), "and the row has its key")
}

/// <p>Consistency Conventions, new properties on a stored class: the proposal row's data slots hold, in order, the 30 columns a row
/// stored before the key existed was written with, and then the key, so such a row reads each column where it wrote it. A slot after
/// the 31st, a property added later, is not checked.</p>
/// <p>Mutation (Rule 19): declare <code>TargetKey</code> directly after <code>TargetRef</code> in
/// <class>OcuPilot.Kernel.State.Propose</class> -- every slot after <code>TargetRef</code> moves and this goes red.</p>
Method TestARowStoredBeforeTheKeyKeepsEachColumnInItsSlot()
{
    Set tExpected = $ListBuild("ProposalKey", "Token", "Burned", "UserName", "ConvKey", "TurnKey", "ToolName", "TargetRef", "Fingerprint", "Arguments", "Payload", "Diff", "UnchangedCount", "Rationale", "ExpectedImpact", "Reverse", "CreatedAt", "ExpiresAt", "State", "AuditWarning", "Destructive", "Consequence", "ConfirmedAt", "ClosedReason", "DefinitionId", "DefinitionVersion", "RequiredPairs", "ReadBack", "Impact", "TargetName", "TargetKey")
    Set tActual = ""
    For tSlot = 1:1:$ListLength(tExpected) {
        Set tValue = ##class(%Dictionary.CompiledStorageDataValue).%OpenId(..#STORE _ "||Default||ProposeDefaultData||" _ tSlot)
        Set tActual = tActual _ $ListBuild($Select($IsObject(tValue): tValue.Value, 1: ""))
    }
    Do $$$AssertEquals($ListToString(tActual), $ListToString(tExpected), "the first 31 data slots of a proposal row")
}

}
