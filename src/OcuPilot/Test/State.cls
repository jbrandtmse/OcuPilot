/// <p>Escalation, denial and integration suite for
/// <class>OcuPilot.Kernel.State.Base</class> (AC4, AC5). Owns the throwaway denial user
/// and its purpose-built role, created in <method>OnBeforeOneTest</method> and deleted
/// in <method>OnAfterOneTest</method>. Must not grant <code>%Operator</code>: that role
/// carries <code>%DB_IRISSYS:RW</code>, a self-escalation primitive -- the "denied" user
/// could then <code>Set $ROLES</code> to anything and log in as <code>_SYSTEM</code>, and
/// the denial assertions below would fail for a reason unrelated to this story. Grants
/// <code>%Admin_Operate:U</code> through the purpose-built role instead, verified with
/// <code>$SYSTEM.Security.CheckUserPermission</code> in setup -- <code>Security.Users.Create</code>
/// silently accepts a role name that does not exist.</p>
/// <p>Also pins, with the same denied account, that the install lock
/// (<method>OcuPilot.Install.Installer.InstallLockName</method>, DW-47) cannot be taken by an
/// account without privilege on <code>IRISSYS</code>
/// (<method>TestDeniedUserCannotHoldTheInstallLock</method>).</p>
/// <p><b>Impersonation is confined to one method frame</b> in each of
/// <method>AttemptGlobalAccess</method> / <method>AttemptSqlAccess</method> /
/// <method>AttemptInstallLock</method>:
/// <code>New $ROLES</code>, then <code>$SYSTEM.Security.Login</code>, the guarded access
/// inside a <code>Try</code>, the exception captured, and every assertion made after the
/// helper returns -- never inside the impersonated frame.</p>
Class OcuPilot.Test.State Extends %UnitTest.TestCase
{

Parameter DENIALUSER = "OcuPilotDenialProbe";

Parameter DENIALROLE = "OcuPilotDenialProbeRole";

/// <p>The <code>%SQLCODE</code> <method>AttemptSqlAccess</method> reports when it could
/// not carry out the attempt at all. Non-negative on purpose: "denied" is asserted as
/// <code>%SQLCODE &lt; 0</code>, so a helper fault must never land inside that range.</p>
Parameter NOTDENIED As %Integer = 9999;

/// <p>Prefix deliberately does not begin with "Test" -- see
/// <file>.claude/rules/objectscript-testing.md</file> (a <code>Test*</code> property
/// name collides with the compiler's auto-generated datatype helper methods, which the
/// framework's method-discovery loop then mis-matches as test methods).</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

/// <p>Ensures production is installed (idempotent, safe -- AC4/AC5 necessarily run
/// against production, since <class>OcuPilot.Kernel.State.Base</class> names exactly one
/// application and one guarding role), then creates the denial user and role.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Install.Installer).Install("")
        If $$$ISERR(tSC) Quit
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit

        Set tNsObj = ##class(Config.Namespaces).Open(tInstallNs)
        If '$IsObject(tNsObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open namespace configuration for " _ tInstallNs)
            Quit
        }
        Set tGlobalsDbName = tNsObj.Globals
        Set tGlobalsDbObj = ##class(Config.Databases).Open(tGlobalsDbName)
        If '$IsObject(tGlobalsDbObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open the globals database " _ tGlobalsDbName)
            Quit
        }
        Set tGlobalsDbDbObj = ##class(SYS.Database).%OpenId(tGlobalsDbObj.Directory)
        If '$IsObject(tGlobalsDbDbObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open SYS.Database for the globals database directory")
            Quit
        }
        Set tInstallNsResource = tGlobalsDbDbObj.ResourceName
        Set tWantResources = tInstallNsResource _ ":RW,%Admin_Operate:U"

        If ##class(Security.Roles).Exists(..#DENIALROLE, .tRoleObj, .tRoleSC) {
            Set tModRoleProps("Resources") = tWantResources
            Set tModRoleProps("ForceSave") = 2
            Set tSC = ##class(Security.Roles).Modify(..#DENIALROLE, .tModRoleProps)
        } Else {
            Set tSC = ##class(Security.Roles).Create(..#DENIALROLE, "OcuPilot test: AC4 denial probe role", tWantResources, "")
        }
        If $$$ISERR(tSC) Quit

        Set tPassword = "OcuPilotTestDenial#" _ $Random(1000000000) _ "!Aa9"
        If ##class(Security.Users).Exists(..#DENIALUSER, .tUserObj, .tUserSC) {
            Set tRoles = ..#DENIALROLE
            Set tSC = ##class(Security.Users).AddRoles(..#DENIALUSER, .tRoles)
        } Else {
            Set tSC = ##class(Security.Users).Create(..#DENIALUSER, ..#DENIALROLE, tPassword, "OcuPilot test denial probe (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.State; deleted in OnAfterOneTest")
        }
        If $$$ISERR(tSC) Quit

        Set ..PreparedSetupOk = ($SYSTEM.Security.CheckUserPermission(..#DENIALUSER, "%Admin_Operate", "USE") = 1)
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the denial user holds %Admin_Operate:U")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Deletes the throwaway user and role, then checks Exists() on each afterwards.</p>
Method OnAfterOneTest() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        ; Purge the Stamp rows this class's own tests write. They carry Profile="probe"
        ; but land in the PRODUCTION protected database -- Stamp's data global starts
        ; with "OcuPilot" and so matches the production mapping, never the probe's
        ; distinct ProbeOcuPilotState* pattern -- and nothing else in this class removes
        ; them. This is the same leak this story's review pass found and fixed for
        ; Test/Installer.cls (212 rows), which would otherwise reappear here every time
        ; OcuPilot.Test.State is run on its own, which is exactly how this story's spec
        ; directs the suite to be executed (per class, never per package). Called before
        ; the switch below: Stamp is an install-namespace class (see Installer's header).
        Set tPurgeSC = ##class(OcuPilot.Kernel.State.Stamp).DeleteByProfile("probe")
        Do $$$AssertStatusOK(tPurgeSC, "the probe stamp rows this class wrote are purged from the production database")

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit

        If ##class(Security.Users).Exists(..#DENIALUSER, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(..#DENIALUSER)
            If $$$ISERR(tSC) Quit
        }
        If ##class(Security.Roles).Exists(..#DENIALROLE, .tR, .tRS) {
            Set tSC = ##class(Security.Roles).Delete(..#DENIALROLE)
            If $$$ISERR(tSC) Quit
        }
        Do $$$AssertTrue('##class(Security.Users).Exists(..#DENIALUSER, .tU2, .tUS2), "the denial user is gone after teardown")
        Do $$$AssertTrue('##class(Security.Roles).Exists(..#DENIALROLE, .tR2, .tRS2), "the denial role is gone after teardown")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>One method frame: escalate away from the current identity into
/// <var>pUsername</var>'s, attempt a direct global GET and SET, capture whatever
/// <code>&lt;PROTECT&gt;</code> code each raised (raised even for a node that does not
/// exist), and return. No assertion is made inside this frame.</p>
ClassMethod AttemptGlobalAccess(pUsername As %String, Output pGetCode As %String, Output pSetCode As %String) [ Private ]
{
    Set pGetCode = ""
    Set pSetCode = ""
    New $ROLES
    Try {
        Do $SYSTEM.Security.Login(pUsername)
        Try {
            Set tVal = $Get(^OcuPilotKernelStateProbe("denialProbe"))
        } Catch getEx {
            Set pGetCode = getEx.Code
        }
        Try {
            Set ^OcuPilotKernelStateProbe("denialProbe") = "should never be written by a denied user"
        } Catch setEx {
            Set pSetCode = setEx.Code
        }
    } Catch ex {
        Set pGetCode = "LOGIN-FAILED:" _ ex.DisplayString()
        Set pSetCode = "LOGIN-FAILED"
    }
    Quit
}

/// <p>One method frame: escalate into <var>pUsername</var>'s identity, attempt a
/// SELECT and an INSERT against the stamp table, capture each <code>%SQLCODE</code>,
/// and return. <var>pWhoAmI</var> reports the identity actually in force inside the
/// frame, so a caller can assert the impersonation really happened.</p>
/// <p><b>The failure sentinel is deliberately non-negative.</b> Every caller asserts
/// <code>%SQLCODE &lt; 0</code> to mean "denied", so writing <code>-1</code> here on
/// exception -- which an earlier version did -- scored <i>any</i> fault in this helper,
/// most importantly <code>$SYSTEM.Security.Login</code> failing and the impersonation
/// never happening at all, as a successful denial. That is a test whose green depends on
/// the very thing it claims to prove (Rule 19). <method>AttemptGlobalAccess</method>
/// already gets this right by reporting <code>"LOGIN-FAILED"</code>, which its
/// <code>= 202</code> assertions reject.</p>
ClassMethod AttemptSqlAccess(pUsername As %String, Output pSelectCode As %Integer, Output pInsertCode As %Integer, Output pWhoAmI As %String) [ Private ]
{
    Set pSelectCode = ..#NOTDENIED
    Set pInsertCode = ..#NOTDENIED
    Set pWhoAmI = ""
    New $ROLES
    Try {
        Do $SYSTEM.Security.Login(pUsername)
        Set pWhoAmI = $Username
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Stamp")
        Set pSelectCode = tRS.%SQLCODE
        Set tRS2 = ##class(%SQL.Statement).%ExecDirect(, "INSERT INTO OcuPilot_Kernel_State.Stamp (Timestamp, Profile) VALUES ('denial-probe', 'probe')")
        Set pInsertCode = tRS2.%SQLCODE
    } Catch ex {
        Set pSelectCode = ..#NOTDENIED
        Set pInsertCode = ..#NOTDENIED
    }
    Quit
}

/// <p>One method frame: drop into <var>pUsername</var>'s identity, then reach OcuPilot's
/// protected state through <class>OcuPilot.Kernel.State.Base</class>'s guarded methods --
/// the same frame shape as <method>AttemptGlobalAccess</method>, but going <i>through</i>
/// the escalation instead of around it. No assertion is made inside this frame.</p>
ClassMethod AttemptGuardedAccess(pUsername As %String, Output pSetSC As %Status, Output pGetSC As %Status, Output pValue As %String, Output pWhoAmI As %String) [ Private ]
{
    Set pSetSC = $$$ERROR($$$GeneralError, "the guarded write was never attempted")
    Set pGetSC = $$$ERROR($$$GeneralError, "the guarded read was never attempted")
    Set pValue = ""
    Set pWhoAmI = ""
    New $ROLES
    Try {
        Do $SYSTEM.Security.Login(pUsername)
        Set pWhoAmI = $Username
        Set pSetSC = ##class(OcuPilot.Kernel.State.Base).GuardedProbeSet("escalationProbe", "written-through-the-escalated-path")
        Set pGetSC = ##class(OcuPilot.Kernel.State.Base).GuardedProbeGet("escalationProbe", .pValue)
    } Catch ex {
        Set pSetSC = ex.AsStatus()
        Set pGetSC = ex.AsStatus()
    }
    Quit
}

/// <p>One method frame: drop into <var>pUsername</var>'s identity and try to take the probe
/// profile's install lock (<method>OcuPilot.Install.Installer.InstallLockName</method>, DW-47),
/// the same frame shape as <method>AttemptGlobalAccess</method>. <var>pOutcome</var> is
/// <code>TAKEN</code> (and the lock is released again at once), <code>TIMEDOUT</code>, the
/// name of the error the attempt raised, or <code>LOGIN-FAILED:...</code>. The lock name is
/// read before the identity changes. No assertion is made inside this frame.</p>
ClassMethod AttemptInstallLock(pUsername As %String, Output pOutcome As %String, Output pWhoAmI As %String) [ Private ]
{
    Set pOutcome = "NOT-ATTEMPTED"
    Set pWhoAmI = ""
    Set tName = ##class(OcuPilot.Install.Installer).InstallLockName("probe")
    New $ROLES
    Try {
        Do $SYSTEM.Security.Login(pUsername)
        Set pWhoAmI = $Username
        Try {
            Lock +@tName:2
            If $Test {
                Set pOutcome = "TAKEN"
                Lock -@tName
            } Else {
                Set pOutcome = "TIMEDOUT"
            }
        } Catch lockEx {
            Set pOutcome = lockEx.Name
        }
    } Catch ex {
        Set pOutcome = "LOGIN-FAILED:" _ ex.DisplayString()
    }
    Quit
}

/// <p>AC4 (global half) -- a denied user's direct GET and SET of an
/// <code>^OcuPilot…</code> global both raise <code>&lt;PROTECT&gt;</code>, and the same
/// global reference is read successfully through the escalated path in the same test,
/// so a mistyped name cannot pass as a denial.</p>
Method TestDeniedUserCannotReachTheGlobal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the denial user holds %Admin_Operate:U")

    Set tSC0 = ##class(OcuPilot.Kernel.State.Base).GuardedProbeSet("denialProbe", "sentinel-for-denial-test")
    Do $$$AssertStatusOK(tSC0, "seed the probe global through the escalated path before the denial attempt")

    Do ..AttemptGlobalAccess(..#DENIALUSER, .tGetCode, .tSetCode)
    Do $$$AssertEquals(tGetCode, 202, "denied user's direct global GET raises <PROTECT> (code 202)")
    Do $$$AssertEquals(tSetCode, 202, "denied user's direct global SET raises <PROTECT> (code 202)")

    Set tSC = ##class(OcuPilot.Kernel.State.Base).GuardedProbeGet("denialProbe", .tVal)
    Do $$$AssertStatusOK(tSC, "the escalated path can still read the same global reference")
    Do $$$AssertEquals(tVal, "sentinel-for-denial-test", "the escalated read sees the value set before the denial attempt, not a value the denied write produced")
}

/// <p>AC4 (table half) -- a denied user's SELECT and INSERT against the stamp table
/// both fail with a negative %SQLCODE, paired with an escalated success on the same
/// table so a mistyped table name cannot pass as a denial.</p>
Method TestDeniedUserCannotReachTheTable()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the denial user holds %Admin_Operate:U")

    Do ..AttemptSqlAccess(..#DENIALUSER, .tSelectCode, .tInsertCode, .tWhoAmI)
    Do $$$AssertEquals(tWhoAmI, ..#DENIALUSER, "the impersonation actually took effect -- the two attempts below ran as the denied user, not as the suite's own identity")
    Do $$$AssertTrue(tSelectCode < 0, "denied user's SELECT against the stamp table fails with a negative SQLCODE")
    Do $$$AssertTrue(tInsertCode < 0, "denied user's INSERT against the stamp table fails with a negative SQLCODE")

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Stamp")
    Do $$$AssertTrue(tRS.%SQLCODE >= 0, "a legitimately-privileged SELECT against the same table succeeds")
}

/// <p>AC5 (Integration AC, Rule 1) -- <class>OcuPilot.Kernel.State.Stamp</class> writes
/// a row and reads it back through <class>OcuPilot.Kernel.State.Base</class>, the row
/// round-trips with its values intact, and that row is one of the objects AC4's denied
/// user cannot see.</p>
Method TestGuardedSaveRoundTrips()
{
    Set tStamp = ##class(OcuPilot.Kernel.State.Stamp).%New()
    Set tStamp.Timestamp = "2026-09-09T00:00:00Z"
    Set tStamp.Profile = "probe"
    Set tStamp.DatabaseName = "roundtrip-test"
    Set tStamp.GrantOutcome = "granted"
    Set tStamp.GrantedUsername = "roundtrip-user"
    Set tSC = ##class(OcuPilot.Kernel.State.Base).GuardedSave(tStamp)
    Do $$$AssertStatusOK(tSC, "guarded save succeeds")
    Set tId = tStamp.%Id()

    Set tSC2 = ##class(OcuPilot.Kernel.State.Stamp).GuardedOpenId(tId, .tReopened)
    Do $$$AssertStatusOK(tSC2, "guarded open succeeds")
    Do $$$AssertTrue($IsObject(tReopened), "guarded open returns an object")
    Do $$$AssertEquals(tReopened.DatabaseName, "roundtrip-test", "the round-tripped row carries its saved values intact")
    Do $$$AssertEquals(tReopened.GrantedUsername, "roundtrip-user", "the round-tripped row carries its saved values intact")

    Do ..AttemptSqlAccess(..#DENIALUSER, .tSelectCode, .tInsertCode, .tWhoAmI)
    Do $$$AssertEquals(tWhoAmI, ..#DENIALUSER, "the impersonation actually took effect before the invisibility check below")
    Do $$$AssertTrue(tSelectCode < 0, "the denied user cannot select from the round-tripped row's table either")
}

/// <p><method>OcuPilot.Kernel.State.Base.GuardedExistsId</method> reflects presence and
/// absence through the escalated frame -- a module the diff shipped with no executed
/// test host until now.</p>
Method TestGuardedExistsIdReflectsPresenceAndAbsence()
{
    Set tStamp = ##class(OcuPilot.Kernel.State.Stamp).%New()
    Set tStamp.Timestamp = "2026-09-09T00:00:00Z"
    Set tStamp.Profile = "probe"
    Set tSC = ##class(OcuPilot.Kernel.State.Base).GuardedSave(tStamp)
    Do $$$AssertStatusOK(tSC, "guarded save succeeds")
    Set tId = tStamp.%Id()

    Set tSC2 = ##class(OcuPilot.Kernel.State.Stamp).GuardedExistsId(tId, .tExists)
    Do $$$AssertStatusOK(tSC2, "guarded exists succeeds for a present id")
    Do $$$AssertTrue(tExists, "a saved row's id exists through the guarded check")

    Set tSC3 = ##class(OcuPilot.Kernel.State.Stamp).GuardedExistsId("999999999", .tExists2)
    Do $$$AssertStatusOK(tSC3, "guarded exists succeeds for an absent id")
    Do $$$AssertTrue('tExists2, "an id that was never saved does not exist through the guarded check")
}

/// <p>AD-37 (weak references) -- <method>OcuPilot.Kernel.State.Stamp.ResolveGrantedUser</method>
/// renders a granted username that names no real account as "no longer present" rather
/// than failing, resolves one that still exists to that username, and leaves an unset
/// value as the empty string. Reads only <property>GrantedUsername</property>, so none
/// of this needs the object saved.</p>
Method TestResolveGrantedUserRendersDeletedAccountAsNoLongerPresent()
{
    Set tStamp = ##class(OcuPilot.Kernel.State.Stamp).%New()
    Set tStamp.GrantedUsername = "OcuPilotNoSuchUserZZZTMPPROBE"
    Do $$$AssertEquals(tStamp.ResolveGrantedUser(), "no longer present", "a granted username that names no real account resolves as 'no longer present'")

    Set tStamp2 = ##class(OcuPilot.Kernel.State.Stamp).%New()
    Set tStamp2.GrantedUsername = $Username
    Do $$$AssertEquals(tStamp2.ResolveGrantedUser(), $Username, "a granted username naming a real, still-existing account resolves to that username")

    Set tStamp3 = ##class(OcuPilot.Kernel.State.Stamp).%New()
    Do $$$AssertEquals(tStamp3.ResolveGrantedUser(), "", "an unset GrantedUsername resolves to the empty string, never a failure")
}

/// <p>AD-9 / AC5 -- <b>the escalation itself is what grants access, and this is the one
/// assertion in the suite that can prove it.</b> The denied user of AC4, whose direct
/// read and write of <code>^OcuPilotKernelStateProbe</code> both raise
/// <code>&lt;PROTECT&gt;</code>, reaches the same global successfully <i>through</i>
/// <class>OcuPilot.Kernel.State.Base</class>'s guarded methods -- so the privileged
/// routine application, not the caller's own roles, is demonstrably what opens
/// <code>%DB_OCUPILOT</code>.</p>
/// <p><b>Why the other escalated-success assertions in this class cannot do this job.</b>
/// The suite's own connection authenticates as <code>_SYSTEM</code>, which holds
/// <code>%All</code> (verified: <code>$ROLES</code> reads
/// <code>%All,OcuPilotAdmin</code>), and <code>%All</code> satisfies
/// <code>%DB_OCUPILOT</code> without any escalation at all. Deleting
/// <code>New $ROLES</code> and <code>$SYSTEM.Security.AddRoles</code> from every guarded
/// method therefore leaves <method>TestGuardedSaveRoundTrips</method>,
/// <method>TestGuardedExistsIdReflectsPresenceAndAbsence</method> and
/// <method>TestDeniedUserCannotReachTheGlobal</method>'s escalated halves all green --
/// confirmed live by this story's QA pass for <method>TestGuardedSaveRoundTrips</method>.
/// Only a caller who is genuinely refused without the escalation can tell the difference,
/// and the denial user built in <method>OnBeforeOneTest</method> is that caller.</p>
Method TestEscalationIsWhatGrantsTheDeniedUserAccess()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the denial user holds %Admin_Operate:U")

    Do ..AttemptGlobalAccess(..#DENIALUSER, .tGetCode, .tSetCode)
    Do $$$AssertEquals(tSetCode, 202, "the control: the same user's DIRECT write of an ^OcuPilot global raises <PROTECT> (code 202)")

    Do ..AttemptGuardedAccess(..#DENIALUSER, .tSetSC, .tGetSC, .tValue, .tWhoAmI)
    Do $$$AssertEquals(tWhoAmI, ..#DENIALUSER, "the impersonation actually took effect -- the guarded calls below ran as the denied user, not as the suite's own %All identity")
    Do $$$AssertStatusOK(tSetSC, "the same denied user's GUARDED write succeeds -- the escalation, not the caller's roles, is what grants access")
    Do $$$AssertStatusOK(tGetSC, "the same denied user's GUARDED read succeeds")
    Do $$$AssertEquals(tValue, "written-through-the-escalated-path", "the guarded read sees exactly what the guarded write stored")
}

/// <p>AD-9's first ordering-rule half -- the guarding role is present in
/// <code>$ROLES</code> inside the guarded frame.</p>
Method TestRoleIsPresentInsideTheFrame()
{
    Set tInside = $ZConvert(##class(OcuPilot.Kernel.State.Base).GuardedRolesSnapshot(), "U")
    Set tGuardRole = $ZConvert(##class(OcuPilot.Kernel.State.Base).#DBRESOURCE, "U")
    Do $$$AssertTrue($ListFind($ListFromString(tInside, ","), tGuardRole) > 0, "the guarding role is present in $ROLES inside the guarded frame")
}

/// <p>AD-9's second ordering-rule half -- the guarding role is absent immediately after
/// the method returns, on the normal path and after an exception raised inside the
/// frame.</p>
Method TestRoleIsAbsentAfterTheFrameReturns()
{
    Set tGuardRole = $ZConvert(##class(OcuPilot.Kernel.State.Base).#DBRESOURCE, "U")

    Do ##class(OcuPilot.Kernel.State.Base).GuardedRolesSnapshot()
    Set tAfter = $ZConvert($ROLES, "U")
    Do $$$AssertEquals($ListFind($ListFromString(tAfter, ","), tGuardRole), 0, "the guarding role is absent immediately after the method returns (normal path)")

    Set tSC = ##class(OcuPilot.Kernel.State.Base).GuardedRolesSnapshotThenThrow()
    Do $$$AssertStatusNotOK(tSC, "the induced exception is reported as an error status, not swallowed")
    Set tAfter2 = $ZConvert($ROLES, "U")
    Do $$$AssertEquals($ListFind($ListFromString(tAfter2, ","), tGuardRole), 0, "the guarding role is absent immediately after an exception raised inside the frame")
}

/// <p>DW-47: the install lock is not something any account can take. It is an extended
/// reference into <code>%SYS</code> (<method>OcuPilot.Install.Installer.InstallLockName</method>),
/// and a lock on a global is checked against the caller's privilege on the database it
/// resolves to -- <code>IRISSYS</code>, which has no public permission. So this class's
/// purpose-built account, which holds <code>%DB_&lt;install-namespace&gt;:RW</code> and
/// <code>%Admin_Operate:U</code> but nothing on <code>IRISSYS</code>, is refused it with
/// <code>&lt;PROTECT&gt;</code> and cannot hold it to stall an install; the suite's own
/// identity takes the same lock, so the refusal is about privilege, not about a lock someone
/// else holds.</p>
/// <p>Mutation (Rule 19): make the install lock a plain local lock name (no caret) -- the
/// denied account takes it, red.</p>
Method TestDeniedUserCannotHoldTheInstallLock()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the denial user holds %Admin_Operate:U")

    Do ..AttemptInstallLock(..#DENIALUSER, .tOutcome, .tWhoAmI)
    Do $$$AssertEquals(tWhoAmI, ..#DENIALUSER, "the impersonation actually took effect")
    Do $$$AssertEquals(tOutcome, "<PROTECT>", "an account with no privilege on IRISSYS is refused the install lock")

    Set tName = ##class(OcuPilot.Install.Installer).InstallLockName("probe")
    Lock +@tName:2
    Set tTook = $Test
    If tTook Lock -@tName
    Do $$$AssertTrue(tTook, "the suite's own identity takes the same lock, so nothing else was holding it")
}

}
