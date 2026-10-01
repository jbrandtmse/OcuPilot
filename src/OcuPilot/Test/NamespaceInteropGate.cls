/// <p>Pins Story 18.15's <code>%All</code> requirement with real principals (AD-8 as amended
/// 2026-10-01): no resource is named <code>%All</code>; a principal holding every resource a role may be
/// granted but not the <code>%All</code> role, and one whose own role only grants <code>%All</code>, are
/// refused 403 <code>AUTH.NOPRIVILEGE</code> naming <code>%All:USE</code> at the agent's dispatch and on
/// the screen's route, and one that lost the role since its proposal was minted is refused the same way
/// at the confirm, the route and the confirm asking their port nothing; a principal holding the
/// <code>%All</code> role is admitted on both callers. The class's snapshot after all tests equals the
/// one before (<class>OcuPilot.Test.InteropProbe</class>).</p>
/// <p>The granted-role leg pins a measured limit: <code>$SYSTEM.Security.CheckUserPermission</code>
/// answers 0 for <code>%All:USE</code> when <code>%All</code> reaches the user only through another
/// role's grant, though that user holds every resource (measured on <code>ocupilot-b-ci</code>,
/// 2026-10-01).</p>
/// <p>The legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.MappingWriteGateProbe</class>), which reports what the step's port was asked:
/// <class>OcuPilot.Test.MappingAcceptPort</class>, which sends no write, for every refusal leg, so a
/// removed pair shows as a recorded call and never as an enable made by a principal without
/// <code>%All</code>; <class>OcuPilot.Test.NamespaceInteropRecordPort</class>, which sends it and waits
/// for it to end, for the admitted leg. A dispatch runs the shipped tool, whose port is the shipped one,
/// so a dispatch leg's answer is read and its port calls are not.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>NAMESPACEVARIABLE</parameter> reading
/// <code>1</code>, because the class creates and deletes four users, their four roles and a scratch
/// role, sets the governance policy, and creates, enables and deletes an <code>OCUPROBE1815*</code>
/// namespace, restoring what the enable changes instance-wide
/// (<class>OcuPilot.Test.InteropProbe</class>).</p>
Class OcuPilot.Test.NamespaceInteropGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the namespace writes, set there alone too.</p>
Parameter NAMESPACEVARIABLE = "OCUPILOT_ALLOW_NAMESPACE_CONFIG";

Parameter PROBE = "OcuPilot.Test.InteropProbe";

Parameter GATE = "OcuPilot.Test.MappingWriteGate";

Parameter NSGATE = "OcuPilot.Test.NamespaceWriteGate";

/// <p>The port every refusal leg's step names, which records and sends no write.</p>
Parameter ACCEPT = "OcuPilot.Test.MappingAcceptPort";

Parameter KEY = "osmgmt.namespaces.enableinterop";

Parameter SCREEN = "osmgmt.namespaces";

Parameter ACTIONID = "enable-interop";

/// <p>The principal holding every resource a role may be granted but not the <code>%All</code> role.
/// The principals' names hold no <parameter>OcuPilot.Test.InteropProbe.PREFIX</parameter>, so the
/// probe never counts them as its own.</p>
Parameter NOALLUSER = "OcuGate1815NoAll";

/// <p>The principal whose own role only grants <code>%All</code>.</p>
Parameter GRANTEDUSER = "OcuGate1815Granted";

/// <p>The principal holding the <code>%All</code> role.</p>
Parameter ALLUSER = "OcuGate1815All";

/// <p>The principal holding every resource and the <code>%All</code> role until a test takes the role
/// away.</p>
Parameter LOSINGUSER = "OcuGate1815Losing";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>Every resource a role may be granted, at the most it may be granted, spelled for a role's
/// resources.</p>
Property PreparedResources As %String(MAXLEN = "");

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The probe snapshot taken before all tests, before the principals exist.</p>
Property PreparedSnapshot As %Library.DynamicArray;

/// <p>The port the admitted leg's route names.</p>
Parameter ADMITTEDPORT = "OcuPilot.Test.NamespaceInteropRecordPort";

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedResources = ""
    Set ..PreparedSnapshot = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#NAMESPACEVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.NamespaceInteropGate creates and deletes users, roles and namespaces and enables interoperability on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#NAMESPACEVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set ..PreparedPassword = "OcuGate1815" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedSnapshot = $ClassMethod(..#PROBE, "Snapshot")
    Quit ..EnsurePrincipals()
}

/// <p>The agent's key enabled, so only the pairs stand in the way, and the probe namespace
/// created.</p>
Method OnBeforeOneTest() As %Status
{
    Kill tSettings
    Set tSettings(..#KEY) = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Add", "G"))
}

Method OnAfterOneTest() As %Status
{
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object is removed by exact name, and what an enable changed instance-wide is restored")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>Remove the probe objects, the policy's changes, the principals and their roles; a failing
/// status when any survives or the snapshot differs from the one taken before all tests.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Merge tRows = ..PreparedPolicy
    Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows))
    Set tSC = $$$ADDSC(tSC, ..RemovePrincipals())
    If $IsObject(..PreparedSnapshot) {
        Set tDiff = $ClassMethod(..#PROBE, "Diff", ..PreparedSnapshot, $ClassMethod(..#PROBE, "Snapshot"))
        If tDiff.added.%Size() || tDiff.removed.%Size() {
            Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the instance differs from its snapshot after OcuPilot.Test.NamespaceInteropGate: added " _ $Extract(tDiff.added.%ToJSON(), 1, 400) _ " removed " _ $Extract(tDiff.removed.%ToJSON(), 1, 400)))
        }
    }
    Quit tSC
}

/// <p>No resource is named <code>%All</code>, so the pair <code>%All:USE</code> is held only by a holder
/// of the <code>%All</code> role: the principal holding every resource does not hold it, nor does the
/// one whose own role only grants <code>%All</code>, and the one holding the role does.</p>
Method TestNoResourceIsNamedAll()
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tExists = ##class(Security.Resources).Exists("%All")
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(tExists, 0, "no resource is named %All")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#NOALLUSER, "%All", "USE") _ "|" _ $SYSTEM.Security.CheckUserPermission(..#GRANTEDUSER, "%All", "USE") _ "|" _ $SYSTEM.Security.CheckUserPermission(..#ALLUSER, "%All", "USE"), "0|0|1", "every resource is not %All:USE, nor is %All granted through a role, and the %All role is")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#GRANTEDUSER, "%Admin_Manage", "USE"), 1, "though the role granting %All holds every resource")
}

/// <p>A principal holding every resource but not <code>%All</code> is refused 403
/// <code>AUTH.NOPRIVILEGE</code> naming <code>%All:USE</code> at the agent's dispatch and on the
/// screen's route, the route's port asked nothing and no proposal minted; so is a principal whose own
/// role only grants <code>%All</code>.</p>
/// <p>Mutation (Rule 19): drop <code>%All:USE</code> from
/// <method>OcuPilot.Screen.Tool.NamespaceEnableInterop.PrivilegePairs</method> -> the principal is
/// admitted, the route reaches the port, and this goes red.</p>
Method TestACallerWithoutAllIsRefusedBeforeAnyPortCall()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "G")
    For tUser = ..#NOALLUSER, ..#GRANTEDUSER {
        Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "running", .tTurnKey)
        Do $$$AssertStatusOK(tSC, tUser _ ": a running turn is seeded for the principal")
        Set tPlan = []
        Do tPlan.%Push({"kind": "dispatch", "turnKey": (tTurnKey), "tool": (..#KEY), "input": {"Name": (tName)}, "port": (..#ACCEPT)})
        Do tPlan.%Push({"kind": "action", "screen": (..#SCREEN), "body": {"action": (..#ACTIONID), "id": (tName)}, "port": (..#ACCEPT)})
        Set tRun = $ClassMethod(..#GATE, "RunAs", tUser, tPlan)
        Do $$$AssertEquals($ClassMethod(..#NSGATE, "Ran", tRun), tUser _ " 1", tUser _ ": the child process ran as the principal")
        Do $$$AssertEquals($Piece($ClassMethod(..#NSGATE, "LegText", tRun, 1), " calls=", 1), "403 AUTH.NOPRIVILEGE %All:USE", tUser _ ": the agent's dispatch is refused naming %All:USE")
        Do $$$AssertEquals($ClassMethod(..#NSGATE, "LegText", tRun, 2), "403 AUTH.NOPRIVILEGE %All:USE calls=0 types=", tUser _ ": the screen's route is refused naming %All:USE, its port asked nothing")
        Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurnKey, tUser, .tRows)
        Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Size(), 1: -1), 0, tUser _ ": no proposal is minted")
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), tUser _ ": this class removes the ledger rows its calls wrote")
    }
}

/// <p>A principal that minted while it held the <code>%All</code> role and lost it since is refused the
/// same way at the confirm, the port asked nothing (AD-6, AD-8).</p>
Method TestALostGrantIsRefusedAtTheConfirm()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "G")
    Do $$$AssertStatusOK(..HoldAll(..#LOSINGUSER, 1), "the principal holds the %All role")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#LOSINGUSER, "running", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a running turn is seeded for the principal")
    Set tRun = $ClassMethod(..#GATE, "RunAs", ..#LOSINGUSER, [{"kind": "dispatch", "turnKey": (tTurnKey), "tool": (..#KEY), "input": {"Name": (tName)}}])
    Do $$$AssertEquals($Piece($ClassMethod(..#NSGATE, "LegText", tRun, 1), " calls=", 1), "200  ", "the principal's call is admitted and answers a proposal")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurnKey, ..#LOSINGUSER, .tRows)
    Set tProposalId = $Select($IsObject($Get(tRows)) && (tRows.%Size() = 1): tRows.%Get(0).%Get("proposalId"), 1: "")
    Do $$$AssertNotEquals(tProposalId, "", "one proposal is minted")
    Do $$$AssertStatusOK(..HoldAll(..#LOSINGUSER, 0), "the principal loses the %All role, keeping every other resource")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#LOSINGUSER, "%All", "USE"), 0, "so it no longer holds %All:USE")
    Set tRun = $ClassMethod(..#GATE, "RunAs", ..#LOSINGUSER, [{"kind": "confirm", "proposalId": (tProposalId), "port": (..#ACCEPT)}])
    Do $$$AssertEquals($ClassMethod(..#NSGATE, "LegText", tRun, 1), "403 AUTH.NOPRIVILEGE %All:USE calls=0 types=", "the confirm is refused naming %All:USE, the port asked nothing")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "this class removes the ledger rows its calls wrote")
}

/// <p>A principal holding the <code>%All</code> role is admitted at the agent's dispatch, which answers a
/// proposal, and on the screen's route, whose recording port receives exactly one <code>INTEROP</code>
/// call and answers it done, not still running; the namespace is then enabled, its HealthShare half
/// included. The vendor marks a namespace enabled early in the run, so only the done answer says the
/// task has ended.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Test.NamespaceInteropRecordPort.BOUNDSECONDS</parameter>
/// 0 -> the route answers still running and this goes red.</p>
Method TestAnAllHolderIsAdmittedOnBothCallers()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "G")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#ALLUSER, "running", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a running turn is seeded for the principal")
    Set tPlan = []
    Do tPlan.%Push({"kind": "dispatch", "turnKey": (tTurnKey), "tool": (..#KEY), "input": {"Name": (tName)}})
    Do tPlan.%Push({"kind": "action", "screen": (..#SCREEN), "body": {"action": (..#ACTIONID), "id": (tName)}, "port": (..#ADMITTEDPORT)})
    Set tRun = $ClassMethod(..#GATE, "RunAs", ..#ALLUSER, tPlan)
    Do $$$AssertEquals($ClassMethod(..#NSGATE, "Ran", tRun), ..#ALLUSER _ " 1", "the child process ran as the principal")
    Do $$$AssertEquals($Piece($ClassMethod(..#NSGATE, "LegText", tRun, 1), " calls=", 1), "200  ", "the agent's dispatch is admitted and answers a proposal")
    Set tLeg = $ClassMethod(..#NSGATE, "Leg", tRun, 2)
    Set tTypes = $Select($IsObject(tLeg): tLeg.%Get("types"), 1: "")
    Set tInterop = 0
    For tI = 1:1:$Length(tTypes, ",") {
        If $Piece(tTypes, ",", tI) = "INTEROP" Set tInterop = tInterop + 1
    }
    Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http"), 1: "") _ " " _ tInterop, "200 1", "the screen's route is admitted, and the recording port receives exactly one INTEROP call (" _ $ClassMethod(..#NSGATE, "LegText", tRun, 2) _ ")")
    Do $$$AssertEquals($Select($IsObject(tLeg): +tLeg.%Get("continues"), 1: ""), 0, "the route answers the enable done, so its task has ended")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "IsEnabled", tName), 1, "and the namespace is enabled")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HasHealthShareHalf", tName), 1, "its HealthShare half included")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "this class removes the ledger rows its calls wrote")
}

/// <p>Give (<var>pOn</var> 1) or take away (0) the <code>%All</code> role from <var>pUser</var>, who
/// keeps its own role.</p>
ClassMethod HoldAll(pUser As %String, pOn As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        Set tProperties("Roles") = pUser _ "Role" _ $Select(pOn: ",%All", 1: "")
        Set tSC = ##class(Security.Users).Modify(pUser, .tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the four throwaway roles and the accounts that hold them, then read the grants back: every
/// resource a role may be granted and not <code>%All</code>; a role granting <code>%All</code>; the
/// <code>%All</code> role beside an empty role; and every resource and the <code>%All</code> role, the
/// latter until a test takes it away.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ..EveryResource(.tResources)
        If $$$ISERR(tSC) Quit
        Set ..PreparedResources = tResources
        For tCase = $ListBuild(..#NOALLUSER, tResources, "", "", 0), $ListBuild(..#GRANTEDUSER, "", "%All", "", 0), $ListBuild(..#ALLUSER, "", "", ",%All", 1), $ListBuild(..#LOSINGUSER, tResources, "", ",%All", 1) {
            Set tUser = $List(tCase, 1)
            Set tRole = tUser _ "Role"
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the enable-interop gate (throwaway)", $List(tCase, 2), $List(tCase, 3))
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole _ $List(tCase, 4), ..PreparedPassword, "OcuPilot enable-interop test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.NamespaceInteropGate; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
            If ($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Manage", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "WRITE") '= 1) || ($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Operate", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(tUser, "%All", "USE") '= $List(tCase, 5)) {
                Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal " _ tUser _ "'s grants did not read back as declared")
                Quit
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Every resource on the instance a role may be granted, each at the most it may be granted,
/// spelled for a role's resources, in <var>pResources</var>: <code>RWU</code>, narrowed to
/// <code>U</code>, then <code>RW</code>, then <code>R</code>, for a resource a scratch role's create
/// refuses at the wider permission (#897), and left out where it refuses the resource itself (#1499).
/// Runs in <code>%SYS</code>; the scratch role is deleted.</p>
Method EveryResource(Output pResources As %String) As %Status
{
    Set pResources = ""
    Set tSC = $$$OK
    Set tScratch = ..#NOALLUSER _ "Scratch"
    Kill tPermissions
    Set tRS = ##class(%ResultSet).%New("Security.Resources:List")
    Set tSC = tRS.Execute("*")
    If $$$ISERR(tSC) Quit tSC
    While tRS.Next() {
        Set tPermissions(tRS.Get("Name")) = "RWU"
    }
    Set tNext("RWU") = "U"
    Set tNext("U") = "RW"
    Set tNext("RW") = "R"
    For tAttempt = 1:1:1000 {
        Set pResources = ""
        Set tName = ""
        For {
            Set tName = $Order(tPermissions(tName), 1, tPermission)
            If tName = "" Quit
            Set pResources = pResources _ $Select(pResources = "": "", 1: ",") _ tName _ ":" _ tPermission
        }
        If ##class(Security.Roles).Exists(tScratch) Do ##class(Security.Roles).Delete(tScratch)
        Set tSC = ##class(Security.Roles).Create(tScratch, "OcuPilot test: a scratch role (throwaway)", pResources, "")
        If $$$ISOK(tSC) Quit
        Set tText = $System.Status.GetErrorText(tSC)
        Set tUngrantable = $Piece($Piece(tText, "grant resource ", 2), " to a role", 1)
        If (tText [ "#1499") && (tUngrantable '= "") && $Data(tPermissions(tUngrantable)) {
            Kill tPermissions(tUngrantable)
            Continue
        }
        Set tRefused = $Piece($Piece(tText, "for resource name ", 2), ".", 1)
        If (tText '[ "#897") || (tRefused = "") || '$Data(tPermissions(tRefused), tPermission) || ($Get(tNext(tPermission)) = "") Quit
        Set tPermissions(tRefused) = tNext(tPermission)
    }
    If ##class(Security.Roles).Exists(tScratch) Do ##class(Security.Roles).Delete(tScratch)
    Quit tSC
}

/// <p>Delete the principals, their roles and the scratch role; an error when any survives.</p>
Method RemovePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#NOALLUSER, ..#GRANTEDUSER, ..#ALLUSER, ..#LOSINGUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.NamespaceInteropGate left the principal or role of " _ tUser))
        }
        If ##class(Security.Roles).Exists(..#NOALLUSER _ "Scratch") Do ##class(Security.Roles).Delete(..#NOALLUSER _ "Scratch")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

}
