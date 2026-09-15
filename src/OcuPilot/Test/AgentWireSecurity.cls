/// <p>AC6 -- who may see the definitions and who may edit them, proved against the <b>real</b>
/// <code>$System.Security.Check</code> with a purpose-built principal.</p>
/// <p><b>Why a real principal is the only thing that proves this.</b>
/// <method>OcuPilot.Screen.Gate.HoldsPrivilege</method> is overridable so unit tests can drive the
/// gate's set semantics, and <code>%UnitTest</code> itself runs as an account holding
/// <code>%All</code>, for which the real check answers yes to every resource name -- including one
/// the instance does not define. So no in-process test can observe this refusal. The principal
/// here holds <code>%Admin_Operate:USE</code>, which clears
/// <method>OcuPilot.Api.Router.OnPreDispatch</method>'s administrative floor, and does
/// <b>not</b> hold OcuPilot's own administrative resource.</p>
/// <p><b>It creates an IRIS user and role, so <method>OnBeforeAllTests</method> refuses to run
/// unless <parameter>ARMINGVARIABLE</parameter> arms it</b> (DW-289). Only
/// <file>scripts/ci-throwaway.sh</file> sets it.</p>
Class OcuPilot.Test.AgentWireSecurity Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Anything else -- absent, empty, or a value that reads like a refusal such as
/// <code>0</code> -- refuses.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal holding <code>%Admin_Operate:USE</code> and <b>not</b> OcuPilot's
/// administrative resource.</p>
Parameter OPERATEUSER = "OcuPilotAgentOperate";

/// <p>See <parameter>OPERATEUSER</parameter>.</p>
Parameter OPERATEROLE = "OcuPilotAgentOperateRole";

/// <p>The prefix every definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>The account's password for this run, generated in <method>OnBeforeAllTests</method> and
/// never written to source.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back, through
/// <code>$SYSTEM.Security.CheckUserPermission</code>, that the account holds exactly what it is
/// meant to and not OcuPilot's administrative resource.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

/// <p>The definition the refusals below are aimed at, created as the suite's own account.</p>
Property PreparedDefinitionId As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Set ..PreparedDefinitionId = ""
    Quit $$$OK
}

/// <p>Refuse to run at all unless <parameter>ARMINGVARIABLE</parameter> arms this class, then
/// create the principal and one definition for it to be refused on.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AgentWireSecurity creates and deletes an IRIS user and role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    ; Read before the switch below: OcuPilot's classes are not mapped into %SYS, so a
    ; ##class(...).#PARAMETER reference evaluated there raises <CLASS DOES NOT EXIST>.
    Set tAdminResource = ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE
    Try {
        Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..#PROBEPREFIX _ "Sec", 0, 0, .tRow)
        If $$$ISERR(tSC) Quit
        Set ..PreparedDefinitionId = tRow.%Id()
        Set tRow = ""

        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotAgt" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

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
        Set tResources = tSysDb.ResourceName _ ":R,%Admin_Operate:U"

        If ##class(Security.Roles).Exists(..#OPERATEROLE, .tR, .tRS) {
            Set tModProps("Resources") = tResources
            Set tModProps("GrantedRoles") = ""
            Set tModProps("ForceSave") = 2
            Set tSC = ##class(Security.Roles).Modify(..#OPERATEROLE, .tModProps)
        } Else {
            Set tSC = ##class(Security.Roles).Create(..#OPERATEROLE, "OcuPilot test: agent definitions denial principal role (throwaway)", tResources, "")
        }
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#OPERATEUSER, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(..#OPERATEUSER)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(..#OPERATEUSER, ..#OPERATEROLE, ..PreparedPassword, "OcuPilot agent definitions test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.AgentWireSecurity; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit

        Set tHoldsOperate = ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, "%Admin_Operate", "USE") = 1)
        Set tLacksOcuPilot = ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, tAdminResource, "USE") '= 1)
        Set ..PreparedSetupOk = tHoldsOperate && tLacksOcuPilot && (..PreparedDefinitionId '= "")
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the principal's pairs: holds %Admin_Operate " _ tHoldsOperate _ ", lacks " _ tAdminResource _ " " _ tLacksOcuPilot _ ", definition id '" _ ..PreparedDefinitionId _ "'")
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the principal and the definition, and <b>return a failing status</b> if either
/// survives. Reported through the status rather than assertions, which
/// <class>%UnitTest.Manager</class> does not record from this method.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tLeft = ""
    Try {
        Set tRemoveSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
        If $$$ISERR(tRemoveSC) || (tRemaining '= 0) {
            Set tLeft = tLeft _ "agent definitions (" _ tRemaining _ " left, " _ $System.Status.GetErrorText(tRemoveSC) _ ")"
        }
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#OPERATEUSER, .tU, .tUS) Do ##class(Security.Users).Delete(..#OPERATEUSER)
        If ##class(Security.Users).Exists(..#OPERATEUSER, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ ..#OPERATEUSER
        If ##class(Security.Roles).Exists(..#OPERATEROLE, .tR, .tRS) Do ##class(Security.Roles).Delete(..#OPERATEROLE)
        If ##class(Security.Roles).Exists(..#OPERATEROLE, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ ..#OPERATEROLE
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AgentWireSecurity teardown left throwaway objects on the instance: " _ tLeft)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>One request to the definitions surface <b>as the least-privileged principal</b>.</p>
Method Call(pMethod As %String, pSuffix As %String, pBody As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ "/agent/definitions" _ pSuffix, ..#OPERATEUSER, ..PreparedPassword, .pStatus, .pBodyText, .pHeaders, pBody, "application/json")
}

/// <p>AC6 -- the list is served to a caller holding no OcuPilot administrative privilege, and it
/// carries exactly the six selection keys: name, provider, model, enabled, default and the id.
/// Nothing about the credential reaches it.</p>
Method TestTheListIsServedToANonAdministratorWithTheSelectionProjectionOnly()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principal holds %Admin_Operate and not OcuPilot's administrative resource")

    Set tSC = ..Call("GET", "", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the list request completes")
    Do $$$AssertEquals(tStatus, 200, "and is served: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    If tStatus '= 200 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue(tAnswer.definitions.%Size() > 0, "with the instance's definitions listed: " _ tAnswer.definitions.%Size())
    Set tBad = ""
    Set tIterator = tAnswer.definitions.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tKeys = ""
        Set tKeyIterator = tEntry.%GetIterator()
        While tKeyIterator.%GetNext(.tKey, .tValue) {
            Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
        }
        If tKeys '= "id,name,provider,model,enabled,default" Set tBad = "row " _ tIndex _ " carries " _ tKeys
        If tBad '= "" Quit
    }
    Do $$$AssertEquals(tBad, "", "every row carries exactly the six selection keys, no credential reference and no endpoint among them")
}

/// <p>AC6 -- every other route is refused 403 by name, and <b>nothing is written</b>. The row
/// count is asserted around the refused writes, not only the status: a 403 that had already
/// written would still be a 403.</p>
/// <p>Mutation, run on a throwaway inside a recorded and reverted window: delete the
/// <method>OcuPilot.Api.Definitions.IsAdministrator</method> check from the write path -- every leg
/// below goes red on the status. Five observe 200; the credential leg observes 422, because the
/// prepared definition reads its secret from an environment variable and the next refusal after the
/// gate is <code>AGENT.CREDENTIAL.ENVUNWRITABLE</code>. The count itself stayed at 1 while a
/// definition was created, edited and deleted, which is why the per-write checks after the loop are
/// here.</p>
/// <p>The credential store is one of the six, and the gate answers it <b>before the body is
/// read</b>, so a key posted by a principal that may not store one is never looked at.</p>
Method TestEveryOtherRouteIsRefusedByNameAndWritesNothing()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principal holds %Admin_Operate and not OcuPilot's administrative resource")
    Set tExpectedPair = ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE _ ":USE"
    Set tBefore = ##class(OcuPilot.Test.AgentFixture).ProbeCount()
    Do $$$AssertTrue(tBefore > 0, "a definition exists for the refusals to be aimed at: " _ tBefore)

    Set tSound = "{""name"":""" _ ..#PROBEPREFIX _ "Refused"",""provider"":""anthropic"",""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY""}"
    For tCase = "GET|/" _ ..PreparedDefinitionId _ "|", "POST||" _ tSound, "PUT|/" _ ..PreparedDefinitionId _ "|{""model"":""claude-sonnet-5""}", "DELETE|/" _ ..PreparedDefinitionId _ "|", "POST|/" _ ..PreparedDefinitionId _ "/default|", "POST|/" _ ..PreparedDefinitionId _ "/credential|{""apiKey"":""sk-ant-refusedbeforeitisread""}" {
        Set tMethod = $Piece(tCase, "|", 1)
        Set tSuffix = $Piece(tCase, "|", 2)
        Set tRequestBody = $Piece(tCase, "|", 3, 999)
        Set tSC = ..Call(tMethod, tSuffix, tRequestBody, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tMethod _ " " _ tSuffix _ ": the request completes")
        Do $$$AssertEquals(tStatus, 403, tMethod _ " " _ tSuffix _ ": is refused (" _ tBody _ ")")
        Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, tMethod _ " " _ tSuffix _ ": as JSON")
        If tStatus '= 403 Continue
        Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", tMethod _ " " _ tSuffix _ ": on the screen-privilege code")
        Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), tExpectedPair, tMethod _ " " _ tSuffix _ ": naming " _ tExpectedPair)
    }

    ; The count alone is not evidence: a refused create and a refused delete cancel out in it.
    ; So each write is checked for its own effect as well -- observed on the throwaway with the
    ; gate removed, where the count stayed at 1 while a definition had been created, edited and
    ; deleted by a principal that may do none of those things.
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentFixture).ProbeCount(), tBefore, "the refused writes left the definition count unchanged")
    Do $$$AssertTrue('..NameExists(..#PROBEPREFIX _ "Refused"), "the refused create wrote no definition")
    Do $$$AssertTrue(..NameExists(..#PROBEPREFIX _ "Sec"), "the refused delete left the definition it named")
    Set tOpenSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(..PreparedDefinitionId, .tRow)
    Do $$$AssertStatusOK(tOpenSC, "that definition still opens")
    If $$$ISERR(tOpenSC) Quit
    Do $$$AssertEquals(tRow.Model, "claude-opus-5", "and the refused update did not change its model")
}

/// <p>Whether a definition named <var>pName</var> exists, read by SQL as the suite's own account
/// so the check does not go through the code it is checking up on.</p>
ClassMethod NameExists(pName As %String) As %Boolean
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Agent WHERE %EXACT(Name) = ?", pName)
    If tRS.%SQLCODE < 0 Quit 0
    If 'tRS.%Next() Quit 0
    Quit tRS.%GetData(1) > 0
}

}
