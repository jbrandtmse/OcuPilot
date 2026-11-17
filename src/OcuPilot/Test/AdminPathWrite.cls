/// <p>The two administrator paths that write OcuPilot's state without <code>%All</code> in mind keep
/// working under AD-9's store gate: the retention task, run by the Task Manager as the account it
/// names, purges the ledger; an administrator who holds <code>OcuPilotAdmin:USE</code> and not
/// <code>%All</code> runs the install's target-key step and the ledger purge; and a first install by
/// an account that is granted <code>OcuPilotAdmin</code> by that install, which does not change the
/// running process, passes the target-key step on a store with no row to key.</p>
/// <p>The principals' calls run in a child process logged in as each
/// (<class>OcuPilot.Test.AdminPathProbe</class>); rows are seeded and read back here, as the suite's
/// own <code>%All</code> identity.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot's production install, with its retention
/// task, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates
/// and deletes two users and two roles, grants one of them <code>OcuPilotAdmin</code>, and forces a run
/// of the retention task, which sweeps the whole instance. The forced run is taken only when
/// <method>OcuPilot.Test.Retention.ForeignExpired</method> finds no row another suite left past its
/// retention. Every row it seeds names <parameter>PROBEUSER</parameter> or starts with
/// <parameter>OcuPilot.Test.ProposalFixture.PROBEPREFIX</parameter>, removed after each test.</p>
Class OcuPilot.Test.AdminPathWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AdminPathProbe";

/// <p>Holds <code>OcuPilotAdmin:USE</code> and the install namespace's databases read and write, and
/// nothing else.</p>
Parameter ADMINUSER = "OcuPilotAdminPathAdmin";

Parameter ADMINROLE = "OcuPilotAdminPathAdminRole";

/// <p>Holds what an installer needs to grant a role (<code>%Admin_Secure:USE</code> and the system
/// database's write) and the install namespace's databases read and write, and no
/// <code>OcuPilotAdmin</code>: an installer before its first install's grant.</p>
Parameter INSTALLERUSER = "OcuPilotAdminPathInstaller";

Parameter INSTALLERROLE = "OcuPilotAdminPathInstallerRole";

/// <p>Holds <code>%Development:USE</code> and the install namespace's databases read and write, and
/// no <code>OcuPilotAdmin</code> and no write on the system database.</p>
Parameter DEVUSER = "OcuPilotAdminPathDev";

Parameter DEVROLE = "OcuPilotAdminPathDevRole";

/// <p>The owner of every ledger row the class seeds; no account has this name.</p>
Parameter PROBEUSER = "OcuPilotProbeAdminPath";

Parameter PROPOSALUSER = "OcuPilotProbeProposalAdminPath";

/// <p>When a seeded ledger row was logged: before any cutoff a sweep or <parameter>PURGEBEFORE</parameter>
/// computes.</p>
Parameter AGEDAT = "1990-01-01T00:00:00Z";

/// <p>The purge cutoff the principals pass: it removes only rows older than 1990-01-02.</p>
Parameter PURGEBEFORE = "1990-01-02T00:00:00Z";

/// <p>How long a forced task run is waited for: the Task Manager takes a run request at its next
/// once-a-minute pass.</p>
Parameter RUNWAITSECONDS As %Integer = 180;

Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AdminPathWrite creates and deletes users and roles and forces a retention sweep on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotPath" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ..EnsurePrincipals(..PreparedPassword)
}

Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.AdminStateWrite).RemovePrincipals(..Cases(), "OcuPilot.Test.AdminPathWrite")
}

/// <p>Recreate the principals: an earlier test's grant to the installer stays with the account, and a
/// test of the grant starts from an account that does not hold the role.</p>
Method OnBeforeOneTest() As %Status
{
    Quit ..EnsurePrincipals(..PreparedPassword)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(UserName) = ?", ..#PROBEUSER)
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(UserName) = ?", ..#PROBEUSER), 0, "no seeded ledger row survives")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).Remove(.tRemaining), "the seeded proposals are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>The principals, as <code>$ListBuild(user, role, grants)</code>.</p>
ClassMethod Cases() As %List
{
    Quit $ListBuild($ListBuild(..#ADMINUSER, ..#ADMINROLE, "OcuPilotAdmin:U"), $ListBuild(..#INSTALLERUSER, ..#INSTALLERROLE, "%Admin_Secure:U,%DB_IRISSYS:RW"), $ListBuild(..#DEVUSER, ..#DEVROLE, "%Development:U"))
}

/// <p>Create each role of <var>pCases</var> (default <method>Cases</method>) through
/// <method>OcuPilot.Test.AdminStateWrite.EnsurePrincipals</method> with the install namespace's databases read and
/// write plus its grants, and its account, and read back that none holds <code>%All</code> and that only the account
/// named <parameter>ADMINUSER</parameter> holds <code>OcuPilotAdmin</code>.</p>
ClassMethod EnsurePrincipals(pPassword As %String, pCases As %List = "") As %Status
{
    If pCases = "" Set pCases = ..Cases()
    Set tCases = ""
    For tI = 1:1:$ListLength(pCases) {
        Set tCase = $List(pCases, tI)
        Set tAdjuster = (($List(tCase, 3) [ "%Development:") || ($List(tCase, 3) [ "%Admin_Secure:"))
        Set tCases = tCases _ $ListBuild($ListBuild($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), $List(tCase, 1) = ..#ADMINUSER, tAdjuster))
    }
    Quit ##class(OcuPilot.Test.AdminStateWrite).EnsurePrincipals(pPassword, tCases, "RW")
}

/// <p>The first column of <var>pSql</var>'s first row, bound to <var>pValue</var>, as a number;
/// <code>-1</code> when it cannot be read.</p>
ClassMethod Count(pSql As %String, pValue As %String) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pValue)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>Seed one ledger row of <parameter>PROBEUSER</parameter> logged at <parameter>AGEDAT</parameter>.</p>
Method SeedAgedRow(pKey As %String)
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "INSERT INTO OcuPilot_Kernel_State.Ledger (LedgerKey, UserName, LoggedAt, TurnKey, Seq, Kind, Status) VALUES (?, ?, ?, ?, 1, 'tool', 'ok')", pKey, ..#PROBEUSER, ..#AGEDAT, pKey)
    Do $$$AssertEquals(tRS.%SQLCODE, 0, "an aged ledger row is seeded")
}

/// <p>How many ledger rows carry <var>pKey</var>.</p>
ClassMethod LedgerRows(pKey As %String) As %Integer
{
    Quit ..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(LedgerKey) = ?", pKey)
}

/// <p>Seed one live proposal with a target and leave it with no target key, as a proposal stored
/// before the key existed is; answer its key, or <code>""</code>.</p>
Method SeedKeyless() As %String
{
    Kill tValues
    Set tValues("user") = ..#PROPOSALUSER
    Set tValues("convKey") = "probe-admin-path-conv"
    Set tValues("turnKey") = "probe-admin-path-turn"
    Set tValues("toolName") = "webapp.list.update"
    Set tValues("targetRef") = "webapp|USER|/csp/ocupilotadminpath"
    Set tValues("fingerprint") = "0"
    Set tValues("arguments") = "{}"
    Set tValues("payload") = "{}"
    Set tValues("diff") = "[]"
    Set tValues("unchangedCount") = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Proposal SET TargetKey = NULL WHERE %EXACT(ProposalKey) = ?", tKey)
    Do $$$AssertEquals(tRS.%ROWCOUNT, 1, "and left with no target key")
    Quit tKey
}

/// <p>Proposal <var>pKey</var>'s stored target key.</p>
ClassMethod TargetKey(pKey As %String) As %String
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TargetKey FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ProposalKey) = ?", pKey)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit ""
    Quit tRS.%GetData(1)
}

/// <p>Step <var>pIndex</var> of <var>pRun</var> as <code>kind ok=n code=c</code>, its error text
/// appended when it failed.</p>
ClassMethod LegText(pRun As %DynamicObject, pIndex As %Integer) As %String
{
    Set tText = ##class(OcuPilot.Test.AdminStateWrite).LegText(pRun, pIndex)
    Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(pRun, pIndex)
    If $IsObject(tLeg) && 'tLeg.%Get("ok") Set tText = tText _ " " _ tLeg.%Get("text")
    If $IsObject(pRun) && pRun.%IsDefined("error") Set tText = tText _ " " _ pRun.%Get("error")
    Quit tText
}

/// <p>The retention task, forced to run through the Task Manager, runs as the account it names and
/// purges a ledger row older than every retention; that account, logged in in a child process, runs
/// the install's target-key step.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.State.Ledger.GuardedPurgeBefore</method> refuses
/// every caller -> the run records a failure, the aged row stays, and this goes red.</p>
Method TestTheRetentionTaskPurgesTheLedgerAsItsOwnUser()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.RetentionTask).TaskIds(.tIds), "the retention tasks read")
    Do $$$AssertEquals(+$Get(tIds), 1, "one retention task is scheduled")
    If +$Get(tIds) '= 1 Quit
    Set tId = tIds(1)
    Set tForeign = ##class(OcuPilot.Test.Retention).ForeignExpired()
    Do $$$AssertEquals(tForeign, "", "no row another suite created is past its retention, so a run removes nothing of theirs")
    If tForeign '= "" Quit
    Do ..SeedAgedRow("probe-admin-path-task")
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT RunAsUser FROM %SYS.Task WHERE ID = ?", tId)
    Set tRunAs = $Select(tRS.%Next(): tRS.%GetData(1), 1: "")
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(ID) FROM %SYS_Task.History")
    Set tMark = $Select(tRS.%Next(): +tRS.%GetData(1), 1: 0)
    Set tRunSC = ##class(%SYS.Task).RunNow(tId)
    Set $NAMESPACE = tOrigNS
    Do $$$AssertTrue(tRunAs '= "", "the task names the account it runs as: " _ tRunAs)
    Do $$$AssertStatusOK(tRunSC, "a run is requested")
    Set tRun = ""
    Set tDeadline = $ZHorolog + ..#RUNWAITSECONDS
    While ($ZHorolog < tDeadline) && (tRun = "") {
        Hang 5
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Status, Username, Error FROM %SYS_Task.History WHERE Task = ? AND ID > ? ORDER BY ID DESC", tId, tMark)
        If tRS.%Next() Set tRun = tRS.%GetData(1) _ "|" _ tRS.%GetData(2) _ "|" _ tRS.%GetData(3)
        Set $NAMESPACE = tOrigNS
    }
    Do $$$AssertEquals($Piece(tRun, "|", 1, 2), "1|" _ tRunAs, "the run succeeds as " _ tRunAs _ ": " _ tRun)
    Do $$$AssertEquals(..LedgerRows("probe-admin-path-task"), 0, "and purged the aged ledger row")

    Set tKey = ..SeedKeyless()
    If tKey = "" Quit
    Set tChild = ##class(OcuPilot.Test.AdminStateWrite).RunAs(tRunAs, [{"kind": "Install.EnsureProposalTargetKeys"}], ..#PROBE)
    Do $$$AssertEquals(tChild.%Get("username"), tRunAs, "the child runs as the task's account")
    Do $$$AssertEquals(..LegText(tChild, 1), "Install.EnsureProposalTargetKeys ok=1 code=", "which runs the install's target-key step")
    Do $$$AssertTrue(..TargetKey(tKey) '= "", "and the keyless proposal has its key")
}

/// <p>An administrator who holds <code>OcuPilotAdmin:USE</code> and not <code>%All</code> runs the
/// install's target-key step over a keyless proposal and the ledger purge: the install of an account
/// that already holds the role, and the retention task of an install that ran as one.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.State.Ledger.GuardedPurgeBefore</method> also
/// requires <code>%All</code> -> the purge leg is refused and this goes red alone.</p>
Method TestAnAdministratorWithoutAllKeysProposalsAndPurgesTheLedger()
{
    Set tKey = ..SeedKeyless()
    If tKey = "" Quit
    Do ..SeedAgedRow("probe-admin-path-admin")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#ADMINUSER, [{"kind": "Install.EnsureProposalTargetKeys"}, {"kind": "Ledger.GuardedPurgeBefore", "iso": (..#PURGEBEFORE)}], ..#PROBE)
    Do $$$AssertEquals(tRun.%Get("username") _ "|" _ tRun.%Get("holdsAdmin") _ "|" _ (tRun.%Get("roles") [ "%All"), ..#ADMINUSER _ "|1|0", "the child runs as the administrator, without %All")
    Do $$$AssertEquals(..LegText(tRun, 1), "Install.EnsureProposalTargetKeys ok=1 code=", "the target-key step passes")
    Do $$$AssertTrue(..TargetKey(tKey) '= "", "and the keyless proposal has its key")
    Do $$$AssertEquals(..LegText(tRun, 2), "Ledger.GuardedPurgeBefore ok=1 code=", "the purge passes")
    Do $$$AssertEquals(..LedgerRows("probe-admin-path-admin"), 0, "and removed the aged row")
}

/// <p>A first install by an account that does not hold <code>%All</code>: the install grants it
/// <code>OcuPilotAdmin</code>, which leaves its running process without the role, and then runs the
/// target-key step, which passes because no stored proposal lacks its key, as on a new install.</p>
/// <p>Mutation (Rule 19): the frame removed from <method>OcuPilot.Install.Installer.AsAdministrator</method>
/// and <method>OcuPilot.Kernel.State.Propose.GuardedRebuildTargetKeys</method> made to check the
/// administrator before it reads -> the step is refused <code>822</code> and this goes red, with the
/// upgrade test and the developer's empty-store leg.</p>
Method TestAFirstInstallWithoutAllPassesTheTargetKeyStep()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedRebuildTargetKeys(.tChanged), "every stored proposal is given its key first")
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Proposal WHERE TargetKey IS NULL AND TargetRef IS NOT NULL AND TargetRef <> ?", ""), 0, "so none lacks one, as on a new install")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#INSTALLERUSER, [{"kind": "Install.EnsureGrant"}, {"kind": "Install.EnsureProposalTargetKeys"}], ..#PROBE)
    Do $$$AssertEquals(tRun.%Get("username") _ "|" _ tRun.%Get("holdsAdmin") _ "|" _ (tRun.%Get("roles") [ "%All"), ..#INSTALLERUSER _ "|0|0", "the child runs as the installer, without OcuPilotAdmin or %All")
    Do $$$AssertEquals(..LegText(tRun, 1), "Install.EnsureGrant ok=1 code=", "the grant is made")
    Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1)
    Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("holdsAdmin"), 1: ""), 0, "and leaves the running process without the role")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#INSTALLERUSER, "OcuPilotAdmin", "USE"), 1, "while the account now holds it")
    Do $$$AssertEquals(..LegText(tRun, 2), "Install.EnsureProposalTargetKeys ok=1 code=", "the target-key step passes")
}

/// <p>An upgrade from a release whose proposals carry no target key, by an account that does not hold
/// <code>%All</code> and is granted <code>OcuPilotAdmin</code> in the same install: the grant does not reach
/// the running process, and the target-key step gives the keyless proposal its key all the same, because the
/// step adds the role to its own process around the one call. The role is gone when the step returns.</p>
/// <p>Mutation (Rule 19): the <code>New $ROLES</code> frame and its <code>Set $ROLES</code> removed from
/// <method>OcuPilot.Install.Installer.AsAdministrator</method> -> the step is refused
/// <code>822</code>, the proposal keeps no key, and this goes red alone.</p>
Method TestAnUpgradeByAnAccountGrantedTheRoleInTheSameInstallKeysTheProposals()
{
    Set tKey = ..SeedKeyless()
    If tKey = "" Quit
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#INSTALLERUSER, [{"kind": "Install.EnsureGrant"}, {"kind": "Install.EnsureProposalTargetKeys"}], ..#PROBE)
    Do $$$AssertEquals(tRun.%Get("username") _ "|" _ tRun.%Get("holdsAdmin") _ "|" _ (tRun.%Get("roles") [ "%All"), ..#INSTALLERUSER _ "|0|0", "the child runs as the installer, without OcuPilotAdmin or %All")
    Do $$$AssertEquals(..LegText(tRun, 1), "Install.EnsureGrant ok=1 code=", "the grant is made")
    Do $$$AssertEquals(..LegText(tRun, 2), "Install.EnsureProposalTargetKeys ok=1 code=", "the target-key step passes")
    Do $$$AssertTrue(..TargetKey(tKey) '= "", "the keyless proposal has its key")
    Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 2)
    Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("holdsAdmin"), 1: ""), 0, "and the process is without the role again when the step returns")
}

/// <p>A developer -- <code>%Development:USE</code> and the install namespace's databases, no write on the
/// system database -- calls the public target-key step over a keyless proposal. IRIS refuses its own
/// addition of the administrative role to its process with <code>&lt;PROTECT&gt;</code>, so the step runs as
/// the developer, the store answers <code>822</code>, and the proposal keeps no key. On a store with no
/// keyless proposal the same call is accepted.</p>
/// <p>Mutation (Rule 19): <code>Propose.GuardedRebuildTargetKeys</code> drops its administrator check ->
/// the step is accepted, the proposal is keyed, and this goes red alone. The same method made to check
/// the administrator before it reads -> the empty-store leg goes red, with the install test above.</p>
Method TestADeveloperCallingTheTargetKeyStepIsRefused()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedRebuildTargetKeys(.tChanged), "every stored proposal is given its key first")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [{"kind": "Install.EnsureProposalTargetKeys"}], ..#PROBE)
    Do $$$AssertEquals(..LegText(tRun, 1), "Install.EnsureProposalTargetKeys ok=1 code=", "a developer's call over a store with nothing to key is accepted")
    Set tKey = ..SeedKeyless()
    If tKey = "" Quit
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [{"kind": "Roles.AddAdministrator"}, {"kind": "Install.EnsureProposalTargetKeys"}], ..#PROBE)
    Do $$$AssertEquals(tRun.%Get("username") _ "|" _ tRun.%Get("holdsAdmin") _ "|" _ (tRun.%Get("roles") [ "%All"), ..#DEVUSER _ "|0|0", "the child runs as the developer, without OcuPilotAdmin or %All")
    Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1)
    Do $$$AssertTrue($IsObject(tLeg) && 'tLeg.%Get("ok") && (tLeg.%Get("text") [ "PROTECT"), "IRIS refuses the developer's own addition of the role with <PROTECT>: " _ ..LegText(tRun, 1))
    Do $$$AssertEquals(..LegText(tRun, 2) _ "|" _ ..TargetKey(tKey), "Install.EnsureProposalTargetKeys ok=0 code=822 " _ ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 2).%Get("text") _ "|", "the step is refused 822 and the proposal keeps no key")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#INSTALLERUSER, [{"kind": "Roles.AddAdministrator"}], ..#PROBE)
    Do $$$AssertEquals(..LegText(tRun, 1), "Roles.AddAdministrator ok=1 code=", "while an account that can write the system database is admitted the same addition")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1).%Get("holdsAdmin"), 1, "and holds the administrative role after it")
}

}
