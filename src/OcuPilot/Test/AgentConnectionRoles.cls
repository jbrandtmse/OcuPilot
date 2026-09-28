/// <p>AD-9 over HTTP -- <method>OcuPilot.Kernel.Provider.TestCall.Child</method> runs Test
/// connection's one provider call as the caller, spawned from no escalated frame. Every other pin
/// of the child's identity (<class>OcuPilot.Test.AgentConnectionBound</class>'s
/// <method>TestTheChildSendsTheTestRequestAsItsCaller</method>) runs in process as the
/// <code>%UnitTest.TestCase</code> account, which already holds <code>%All</code> -- a real
/// security check answers yes to every resource for that account whether or not an escalation was
/// unwound before the spawn, so that test cannot tell the two apart. Only a real, least-privileged
/// principal dispatched through the REST gateway can.</p>
/// <p>The principal's one role holds exactly what <code>POST /agent/definitions</code>,
/// <code>.../credential</code> and <code>.../test</code> need to be reached and to store a key:
/// read on the install namespace's routine database, <code>%Admin_Operate:USE</code>,
/// <code>OcuPilot.Kernel.State.Base.#ADMINRESOURCE:USE</code>, <code>%Ens_Credentials:WRITE</code>
/// and write on the credential store's database. It does not hold OcuPilot's own database role
/// (<code>#DBRESOURCE</code>) or <code>%All</code>.</p>
/// <p><b>It creates an IRIS user and a role, so <method>OnBeforeAllTests</method> refuses to run
/// unless <parameter>ARMINGVARIABLE</parameter> reads 1, and it runs the created definition against
/// the armed <code>turnprobe</code> row, so it refuses unless <parameter>PROVIDERVARIABLE</parameter>
/// reads 1 too.</b> Only <file>scripts/ci-throwaway.sh</file> sets them; teardown removes the
/// principal, the definition and the credential entry, and fails if one survives.</p>
Class OcuPilot.Test.AgentConnectionRoles Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>See class comment: the armed <code>turnprobe</code> row.</p>
Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

/// <p>The <code>turnprobe</code> row's model tag this class scripts.</p>
Parameter TAG = "acr-roles";

/// <p>The prefix every definition this class creates is named with, so
/// <class>OcuPilot.Test.AgentFixture</class>'s shared teardown finds it.</p>
Parameter NAME = "OcuPilotProbeAgentConnectionRoles";

/// <p>The credential reference the definition names.</p>
Parameter CREDENTIAL = "OcuPilotProbeConnectionRolesCredential";

/// <p>The least-privileged principal AD-9 is checked against.</p>
Parameter ROLESUSER = "OcuPilotConnectionRolesUser";

/// <p>See <parameter>ROLESUSER</parameter>.</p>
Parameter ROLESROLE = "OcuPilotConnectionRolesRole";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>A fabricated key of the shape the <code>turnprobe</code> row requires. It reaches no
/// provider.</p>
Parameter PROBEKEY = "sk-ant-ocupilotrolesprobe0000000000";

/// <p>The account's password for this run, generated in <method>OnBeforeAllTests</method> and
/// never written to source.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back, through
/// <code>$SYSTEM.Security.CheckUserPermission</code>, that the account holds what the route
/// needs.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

/// <p>Refuse to run at all unless both arming variables read 1, then create the least-privileged
/// principal.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AgentConnectionRoles creates and deletes an IRIS user and role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AgentConnectionRoles tests a definition against the turnprobe provider row, on a throwaway container only. " _ ..#PROVIDERVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    ; Read before the switch below: OcuPilot's classes are not mapped into %SYS.
    Set tAdminResource = ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE
    Try {
        Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAG)
        Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#CREDENTIAL)
        Set ..PreparedPassword = "OcuPilotRls" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit

        Set tNsObj = ##class(Config.Namespaces).Open(tInstallNs)
        If '$IsObject(tNsObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open namespace configuration for " _ tInstallNs)
            Quit
        }
        Set tDbObj = ##class(Config.Databases).Open(tNsObj.Routines)
        If '$IsObject(tDbObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open the routine database " _ tNsObj.Routines)
            Quit
        }
        Set tCodeSysDb = ##class(SYS.Database).%OpenId(tDbObj.Directory)
        If '$IsObject(tCodeSysDb) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open SYS.Database for the routine database directory")
            Quit
        }
        Set tStoreDir = $Piece(##class(%SYS.Namespace).GetGlobalDest(tInstallNs, "Ens.Conf.CredentialsD"), "^", 2)
        Set tStoreSysDb = ##class(SYS.Database).%OpenId(tStoreDir)
        If '$IsObject(tStoreSysDb) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open SYS.Database for the credential store's directory " _ tStoreDir)
            Quit
        }
        ; The install namespace's routine database and the vendor credential store's database are
        ; the same database on a single-database instance (verified here: both %DB_HSCUSTOM), and
        ; Security.Roles refuses a Resources string naming one resource twice -- ERROR #895 --
        ; even at two different permission levels, so the two reads are combined into one pair
        ; when they name the same resource.
        Set tDbResources = tCodeSysDb.ResourceName _ ":R"
        If tStoreSysDb.ResourceName = tCodeSysDb.ResourceName {
            Set tDbResources = tCodeSysDb.ResourceName _ ":RW"
        } Else {
            Set tDbResources = tDbResources _ "," _ tStoreSysDb.ResourceName _ ":W"
        }
        Set tResources = tDbResources _ ",%Admin_Operate:U," _ tAdminResource _ ":U,%Ens_Credentials:W"

        If ##class(Security.Roles).Exists(..#ROLESROLE, .tR, .tRS) {
            Set tModProps("Resources") = tResources
            Set tModProps("GrantedRoles") = ""
            Set tModProps("ForceSave") = 2
            Set tSC = ##class(Security.Roles).Modify(..#ROLESROLE, .tModProps)
        } Else {
            Set tSC = ##class(Security.Roles).Create(..#ROLESROLE, "OcuPilot test: Test connection AD-9 least-privilege principal role (throwaway)", tResources, "")
        }
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#ROLESUSER, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(..#ROLESUSER)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(..#ROLESUSER, ..#ROLESROLE, ..PreparedPassword, "OcuPilot Test connection AD-9 test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.AgentConnectionRoles; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit

        Set tHoldsAdmin = ($SYSTEM.Security.CheckUserPermission(..#ROLESUSER, tAdminResource, "USE") = 1)
        Set tHoldsOperate = ($SYSTEM.Security.CheckUserPermission(..#ROLESUSER, "%Admin_Operate", "USE") = 1)
        Set tHoldsStore = ($SYSTEM.Security.CheckUserPermission(..#ROLESUSER, "%Ens_Credentials", "WRITE") = 1)
        Set ..PreparedSetupOk = tHoldsAdmin && tHoldsOperate && tHoldsStore
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the principal's pairs: holds " _ tAdminResource _ " " _ tHoldsAdmin _ ", holds %Admin_Operate " _ tHoldsOperate _ ", holds %Ens_Credentials:WRITE " _ tHoldsStore)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the principal, the definition and the credential entry, and <b>return a failing
/// status</b> if one survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tLeft = ""
    Try {
        Set tRemoveSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
        If $$$ISERR(tRemoveSC) || (tRemaining '= 0) {
            Set tLeft = tLeft _ "agent definitions (" _ tRemaining _ " left)"
        }
        Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#CREDENTIAL)
        If ##class(OcuPilot.Test.CredentialFixture).Exists(..#CREDENTIAL) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "credential entry " _ ..#CREDENTIAL
        Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAG)
        If ##class(OcuPilot.Test.TurnProvider).Remains(..#TAG) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "stub"
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#ROLESUSER, .tU, .tUS) Do ##class(Security.Users).Delete(..#ROLESUSER)
        If ##class(Security.Users).Exists(..#ROLESUSER, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ ..#ROLESUSER
        If ##class(Security.Roles).Exists(..#ROLESROLE, .tR, .tRS) Do ##class(Security.Roles).Delete(..#ROLESROLE)
        If ##class(Security.Roles).Exists(..#ROLESROLE, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ ..#ROLESROLE
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AgentConnectionRoles teardown left throwaway objects on the instance: " _ tLeft)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAG)
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#CREDENTIAL)
    Quit $$$OK
}

/// <p>AD-9, over HTTP, as a real least-privileged principal: the child that makes Test
/// connection's provider call runs as that principal, carrying that principal's own role and
/// never <code>%All</code> or OcuPilot's own database role -- proof that
/// <method>OcuPilot.Kernel.Provider.TestCall.Spawn</method>'s <code>JOB</code> is issued from no
/// escalated frame (AD-9), which the equivalent in-process assertion
/// (<class>OcuPilot.Test.AgentConnectionBound</class>'s
/// <method>TestTheChildSendsTheTestRequestAsItsCaller</method>) cannot show because that test's
/// own account already holds <code>%All</code>.</p>
/// <p>Mutation: have <method>OcuPilot.Kernel.State.Base.GuardedExistsId</method> drop its
/// <code>New $ROLES</code> frame, so the escalation <method>OcuPilot.Api.Definitions.OpenDefinition</method>
/// takes before the call is still standing at the <code>JOB</code> -- red on the recorded roles
/// carrying <code>%DB_OCUPILOT</code>.</p>
Method TestTheChildRunsAsALeastPrivilegedCallerOverHttp()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principal holds what the route needs")

    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("least-privileged"))

    Set tCreateBody = "{""name"":""" _ ..#NAME _ """,""provider"":""turnprobe"",""model"":""" _ ..#TAG _ """,""credType"":""creds"",""credentialName"":""" _ ..#CREDENTIAL _ """}"
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/agent/definitions", ..#ROLESUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders, tCreateBody, "application/json")
    Do $$$AssertStatusOK(tSC, "the create request completes")
    Do $$$AssertEquals(tStatus, 201, "the least-privileged principal may create the definition: " _ tText)
    If tStatus '= 201 Quit
    Set tId = ##class(%DynamicObject).%FromJSON(tText).id

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/agent/definitions/" _ tId _ "/credential", ..#ROLESUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders, ##class(OcuPilot.Test.CredentialFixture).PayloadText(..#PROBEKEY), "application/json")
    Do $$$AssertStatusOK(tSC, "the store request completes")
    Do $$$AssertEquals(tStatus, 200, "the principal may store the key: " _ tText)
    If tStatus '= 200 Quit

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/agent/definitions/" _ tId _ "/test", ..#ROLESUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders, "", "application/json", , 30)
    Do $$$AssertStatusOK(tSC, "the test request completes")
    Do $$$AssertEquals(tStatus, 200, "the test answers before the bound: " _ tText)
    If tStatus '= 200 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tAnswer.reply, "least-privileged", "with the scripted call's own reply")

    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 1, "with one provider call")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "user"), ..#ROLESUSER, "the child ran as the caller, not as the dispatching request's own identity")
    Set tRoles = $ZConvert(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "roles"), "U")
    Do $$$AssertTrue(tRoles [ $ZConvert(..#ROLESROLE, "U"), "the child carries the caller's own role: " _ tRoles)
    Do $$$AssertTrue(tRoles '[ "%ALL", "and never %All, however the request was dispatched: " _ tRoles)
    Do $$$AssertTrue(tRoles '[ $ZConvert(##class(OcuPilot.Kernel.State.Base).#DBRESOURCE, "U"), "nor OcuPilot's own database role, which only an installer or emergency identity holds: " _ tRoles)
}

}
