/// <p>DW-349 -- a key posted by an OcuPilot administrator who does not hold
/// <code>%Ens_Credentials:WRITE</code> is refused by name, <code>AGENT.CREDENTIAL.NOPRIVILEGE</code>,
/// rather than failing inside the vendor's store as a 500, and nothing is written (AD-7, AD-8,
/// AD-42).</p>
/// <p><b>Only a real principal can show this.</b> <code>%UnitTest</code> runs as an account holding
/// <code>%All</code>, for which both <code>$System.Security.Check</code> and the vendor's own
/// resource check pass, so the refusal cannot be observed in process. The principal here holds what
/// the route needs to reach the handler -- read on the install namespace's routine database,
/// <code>%Admin_Operate:USE</code> and OcuPilot's administrative resource -- and not the credential
/// store's resource, which setup reads back before any leg runs. Each method starts from that role,
/// and the one leg that grants the credential store's resource, with write on the globals database,
/// is answered 200.</p>
/// <p><b>It creates an IRIS user and role, so <method>OnBeforeAllTests</method> refuses to run
/// unless <parameter>ARMINGVARIABLE</parameter> arms it.</b> Only
/// <file>scripts/ci-throwaway.sh</file> sets it; teardown removes the principal, the definition and
/// any credential entry, and fails if one survives.</p>
Class OcuPilot.Test.CredentialPrivilege Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal holding OcuPilot's administrative resource and not the credential store's.</p>
Parameter STOREUSER = "OcuPilotCredentialStorer";

/// <p>See <parameter>STOREUSER</parameter>.</p>
Parameter STOREROLE = "OcuPilotCredentialStorerRole";

/// <p>The prefix every definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>The credential reference the definition names.</p>
Parameter PROBECREDENTIAL = "OcuPilotProbePrivilegeCredential";

/// <p>A key shaped for the shipped <code>anthropic</code> row, so no earlier refusal answers.</p>
Parameter PROBEKEY = "sk-ant-ocupilotprivilegeprobe00000";

/// <p>A key that does not begin with the shipped <code>anthropic</code> row's prefix.</p>
Parameter WRONGSHAPEKEY = "not-an-anthropic-key-privilegeprobe";

/// <p>The account's password for this run, generated in <method>OnBeforeAllTests</method>.</p>
Property PreparedPassword As %String;

/// <p>Whether setup read back that the principal holds what it is meant to and nothing more.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

/// <p>The definition the store is posted to.</p>
Property PreparedDefinitionId As %String;

/// <p>The stripped role's resources, which <method>OnBeforeOneTest</method> restores.</p>
Property PreparedResources As %String;

/// <p>The resource guarding the install namespace's globals database.</p>
Property PreparedGlobalsResource As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Set ..PreparedDefinitionId = ""
    Set ..PreparedResources = ""
    Set ..PreparedGlobalsResource = ""
    Quit $$$OK
}

/// <p>Refuse to run unless armed, then create the principal and one definition on the credentials
/// rung for it to store against.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.CredentialPrivilege creates and deletes an IRIS user and role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    ; Read before the switch: OcuPilot's classes are not mapped into %SYS.
    Set tAdminResource = ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE
    Try {
        Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#PROBECREDENTIAL)
        Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "Privilege", 0, 0, .tRow)
        If $$$ISERR(tSC) Quit
        Do ##class(OcuPilot.Kernel.State.Agent).SnapshotSecurityFields(tRow, .tSnapshot)
        Set tRow.CredType = "creds"
        Set tRow.EnvVarName = ""
        Set tRow.CredentialName = ..#PROBECREDENTIAL
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedUpdate(tRow, .tSnapshot)
        Set ..PreparedDefinitionId = tRow.%Id()
        Set tRow = ""
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedDefinitionId, 1, 1)
        If $$$ISERR(tSC) Quit

        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotCrd" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

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
        Set tSysDb = ##class(SYS.Database).%OpenId(tDbObj.Directory)
        If '$IsObject(tSysDb) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open SYS.Database for the routine database directory")
            Quit
        }
        Set tResources = tSysDb.ResourceName _ ":R,%Admin_Operate:U," _ tAdminResource _ ":U"
        Set ..PreparedResources = tResources
        Set tGlobalsDb = ##class(Config.Databases).Open(tNsObj.Globals)
        If '$IsObject(tGlobalsDb) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open the globals database " _ tNsObj.Globals)
            Quit
        }
        Set tGlobalsSysDb = ##class(SYS.Database).%OpenId(tGlobalsDb.Directory)
        If '$IsObject(tGlobalsSysDb) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open SYS.Database for the globals database directory")
            Quit
        }
        Set ..PreparedGlobalsResource = tGlobalsSysDb.ResourceName
        If ##class(Security.Roles).Exists(..#STOREROLE, .tR, .tRS) {
            Set tSC = ##class(Security.Roles).Delete(..#STOREROLE)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Roles).Create(..#STOREROLE, "OcuPilot test: credential store privilege principal role (throwaway)", tResources, "")
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#STOREUSER, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(..#STOREUSER)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(..#STOREUSER, ..#STOREROLE, ..PreparedPassword, "OcuPilot credential store privilege test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.CredentialPrivilege; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit

        Set tHoldsAdmin = ($SYSTEM.Security.CheckUserPermission(..#STOREUSER, tAdminResource, "USE") = 1)
        Set tHoldsOperate = ($SYSTEM.Security.CheckUserPermission(..#STOREUSER, "%Admin_Operate", "USE") = 1)
        ; The literal pair the vendor's store checks, not the handler's own parameters: a misspelt
        ; parameter must not make setup agree with it.
        Set tLacksStore = ($SYSTEM.Security.CheckUserPermission(..#STOREUSER, "%Ens_Credentials", "WRITE") '= 1)
        Set ..PreparedSetupOk = tHoldsAdmin && tHoldsOperate && tLacksStore && (..PreparedDefinitionId '= "")
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the principal's pairs: holds " _ tAdminResource _ " " _ tHoldsAdmin _ ", holds %Admin_Operate " _ tHoldsOperate _ ", lacks %Ens_Credentials:WRITE " _ tLacksStore _ ", definition id '" _ ..PreparedDefinitionId _ "'")
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the principal, the definition and any credential entry, and <b>return a failing
/// status</b> if one survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tLeft = ""
    Try {
        Set tRemoveSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
        If $$$ISERR(tRemoveSC) || (tRemaining '= 0) {
            Set tLeft = "agent definitions (" _ tRemaining _ " left, " _ $System.Status.GetErrorText(tRemoveSC) _ ")"
        }
        Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#PROBECREDENTIAL)
        If ##class(OcuPilot.Test.CredentialFixture).Exists(..#PROBECREDENTIAL) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "credential entry " _ ..#PROBECREDENTIAL
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#STOREUSER, .tU, .tUS) Do ##class(Security.Users).Delete(..#STOREUSER)
        If ##class(Security.Users).Exists(..#STOREUSER, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ ..#STOREUSER
        If ##class(Security.Roles).Exists(..#STOREROLE, .tR, .tRS) Do ##class(Security.Roles).Delete(..#STOREROLE)
        If ##class(Security.Roles).Exists(..#STOREROLE, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ ..#STOREROLE
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.CredentialPrivilege teardown left throwaway objects on the instance: " _ tLeft)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Start every method from the stripped role, no credential entry, and an enabled, verified
/// definition.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#PROBECREDENTIAL)
    Set tSC = ##class(OcuPilot.Test.AgentFixture).SetFlags(..PreparedDefinitionId, 1, 1)
    If $$$ISERR(tSC) Quit tSC
    Quit ..SetRoleResources(..PreparedResources)
}

/// <p>Replace the principal's role's resources with <var>pResources</var>.</p>
Method SetRoleResources(pResources As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tProps("Resources") = pResources
        Set tSC = ##class(Security.Roles).Modify(..#STOREROLE, .tProps)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Post <var>pKey</var> to the definition as the principal; the HTTP status, and the body in
/// <var>pBody</var>.</p>
Method Store(pKey As %String, Output pBody As %String) As %Integer
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/agent/definitions/" _ ..PreparedDefinitionId _ "/credential", ..#STOREUSER, ..PreparedPassword, .tStatus, .pBody, .tHeaders, ##class(OcuPilot.Test.CredentialFixture).PayloadText(pKey), "application/json")
    Do $$$AssertStatusOK(tSC, "the store request completes")
    Do $$$AssertEquals(pBody [ pKey, 0, "and the answer carries no part of the key")
    Quit tStatus
}

/// <p>Assert <var>pBody</var>, answered <var>pStatus</var>, is the NOPRIVILEGE refusal, reading its
/// sentence off the response.</p>
Method AssertRefusedByName(pWhat As %String, pStatus As %Integer, pBody As %String)
{
    Do $$$AssertEquals(pStatus, 422, pWhat _ ": refused as a validation failure, not a 500: " _ pBody)
    If pStatus '= 422 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(pBody)
    Do $$$AssertEquals(tAnswer.code, "AGENT.VALIDATION", pWhat _ ": under the agent validation code")
    Set tViolations = $Select($IsObject(tAnswer.detail): tAnswer.detail.violations, 1: "")
    Do $$$AssertEquals($Select($IsObject(tViolations): tViolations.%Size(), 1: 0), 1, pWhat _ ": with one violation: " _ pBody)
    If '$IsObject(tViolations) Quit
    Set tViolation = tViolations.%Get(0)
    Do $$$AssertEquals(tViolation.field, "apiKey", pWhat _ ": on apiKey")
    Do $$$AssertEquals(tViolation.code, "AGENT.CREDENTIAL.NOPRIVILEGE", pWhat _ ": naming the missing privilege")
    Do $$$AssertTrue(tViolation.reason [ "%Ens_Credentials:WRITE", pWhat _ ": whose sentence names the pair to grant: " _ tViolation.reason)
}

/// <p><b>DW-349</b> -- the store is refused 422 with <code>AGENT.CREDENTIAL.NOPRIVILEGE</code> on
/// <code>apiKey</code>, whose sentence names <code>%Ens_Credentials:WRITE</code>; no credential entry
/// is written and the definition keeps its flags.</p>
/// <p>Mutation: delete the NOPRIVILEGE arm from
/// <method>OcuPilot.Api.Definitions.CredentialRefusal</method> -- this goes red, the vendor's store
/// refusing inside the handler and the route answering 500.</p>
Method TestAStoreWithoutTheCredentialStoreResourceIsRefusedByName()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principal holds OcuPilot's administrative resource and not the credential store's")
    Set tStatus = ..Store(..#PROBEKEY, .tBody)
    Do ..AssertRefusedByName("a well-formed key", tStatus, tBody)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#PROBECREDENTIAL), 0, "no credential entry was written")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentConnection).FlagsOf(..PreparedDefinitionId), "1|1", "and the definition is still enabled and verified")
}

/// <p>The privilege is judged before the key's shape, so a principal without it who posts a key of
/// the wrong shape is still told what to grant.</p>
Method TestAWrongShapeKeyWithoutTheResourceIsStillRefusedByName()
{
    Set tStatus = ..Store(..#WRONGSHAPEKEY, .tBody)
    Do ..AssertRefusedByName("a key of the wrong shape", tStatus, tBody)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#PROBECREDENTIAL), 0, "no credential entry was written")
}

/// <p><b>The refusal is the resource's</b> -- the same principal, granted
/// <code>%Ens_Credentials:W</code> and write on the install namespace's globals database, stores the
/// key and is answered 200.</p>
/// <p>Mutation: misspell <parameter>OcuPilot.Api.Definitions.CREDENTIALSRESOURCE</parameter> -- this
/// goes red at 422, the handler asking about a resource nobody holds.</p>
Method TestAStoreWithTheResourceIsAccepted()
{
    ; The routine database's grant leads the stripped set; where the globals database is the same
    ; one, that grant is widened rather than named twice.
    If $Piece(..PreparedResources, ":", 1) = ..PreparedGlobalsResource {
        Set tResources = ..PreparedGlobalsResource _ ":RW," _ $Piece(..PreparedResources, ",", 2, *) _ ",%Ens_Credentials:W"
    } Else {
        Set tResources = ..PreparedResources _ ",%Ens_Credentials:W," _ ..PreparedGlobalsResource _ ":RW"
    }
    Do $$$AssertStatusOK(..SetRoleResources(tResources), "the role is granted the credential store's resource and write on the globals database")
    Set tStatus = ..Store(..#PROBEKEY, .tBody)
    Do $$$AssertEquals(tStatus, 200, "and the store is accepted: " _ tBody)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#PROBECREDENTIAL), 1, "writing the credential entry")
    Do $$$AssertStatusOK(..SetRoleResources(..PreparedResources), "the role is stripped again")
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#PROBECREDENTIAL)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#PROBECREDENTIAL), 0, "and the entry is removed")
}

}
