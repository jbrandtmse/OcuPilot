/// <p>The role routes and the role delete against the instance itself (AD-10, AD-12, AD-39, AD-54,
/// AD-55): the form's bootstrap read, the name look-up, a create whose role reads back with the sent
/// grants, a privileged create confirmed and applied through the real port, and an agent delete
/// minted and confirmed through it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// the screen's own pairs, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code> --
/// because the create and delete legs create and delete a real role, and the census leg a real
/// account. <method>OnBeforeAllTests</method> refuses anywhere it does not, and refuses to adopt a
/// probe name the instance already holds; <method>OnAfterOneTest</method> deletes the probe roles
/// and account by exact name, never by prefix.</p>
Class OcuPilot.Test.RoleWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FORMPATH = "/roles/form";

Parameter NAMEPATH = "/roles/name";

Parameter CREATEPATH = "/roles";

Parameter TOOL = "OcuPilot.Screen.Tool.RoleDelete";

Parameter LIST = "OcuPilot.Screen.Descriptor.RoleList";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The role the create leg makes, and the one the delete leg makes and deletes. The delete
/// probe is stored in mixed case, so the confirm's folded name is not the stored spelling.</p>
Parameter PROBEROLE = "OcuPilotProbeRoleWire";

Parameter DELETEPROBE = "OcuPilotProbeRoleDelete";

/// <p>The role <method>TestAPrivilegedCreateConfirmedThroughTheRealPortIsApplied</method> creates
/// through the agent's path, granting <code>%All</code>.</p>
Parameter GRANTPROBE = "OcuPilotProbeRoleGrant";

/// <p>The census leg's principals: a role granting <code>%All</code>, a role granting that role,
/// and an account whose only path to <code>%All</code> runs through both.</p>
Parameter PATHPROBE = "OcuPilotProbeAllPath";

Parameter OUTERPROBE = "OcuPilotProbeAllOuter";

Parameter HOLDERPROBE = "OcuPilotProbeAllHolder";

/// <p>The <code>Prohibited</code> subclass whose census input can be armed.</p>
Parameter SETFIXTURE = "OcuPilot.Test.ProhibitedFixture";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RoleWire creates and deletes a role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If ..Exists(..#PROBEROLE) || ..Exists(..#DELETEPROBE) || ..Exists(..#GRANTPROBE) || ..Exists(..#PATHPROBE) || ..Exists(..#OUTERPROBE) || ..UserExists(..#HOLDERPROBE) {
        Quit $$$ERROR($$$GeneralError, "a probe role of OcuPilot.Test.RoleWire already exists on this instance, and this class deletes what it creates -- it will not adopt one it did not make.")
    }
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmAllHolders("")
    Do ..RemoveUser(..#HOLDERPROBE)
    Do ..Remove(..#PROBEROLE)
    Do ..Remove(..#DELETEPROBE)
    Do ..Remove(..#GRANTPROBE)
    Do ..Remove(..#OUTERPROBE)
    Do ..Remove(..#PATHPROBE)
    Do $$$AssertEquals(..Exists(..#PROBEROLE) + ..Exists(..#DELETEPROBE) + ..Exists(..#GRANTPROBE) + ..Exists(..#OUTERPROBE) + ..Exists(..#PATHPROBE) + ..UserExists(..#HOLDERPROBE), 0, "the probe principals are gone")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p><code>GET /roles/form</code> publishes the rules with the server's own sentences, each
/// resource with the letters it admits and whether a grant of it is privileged, and the roles with
/// the privileged ones marked -- the classifier's answers, for the form's consequence line, and no
/// refusal sentence.</p>
/// <p>Mutation: drop the Use-only branch from
/// <method>OcuPilot.Area.Permissions.RoleCreateRules.AdmissiblePermissions</method> -> the
/// <code>%Admin_Secure</code> letters go red.</p>
Method TestTheFormReadPublishesTheRulesAndMarksThePrivilegedChoices()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "the form read answers")
    Do $$$AssertEquals(tStatus, 200, "at 200")
    If '$IsObject($Get(tBody)) Quit
    Do $$$AssertEquals(tBody.%GetTypeOf("privilegeReason"), "unassigned", "it ships no refusal sentence for a privileged choice")
    Do $$$AssertEquals(tBody.%Get("requiredFields").%ToJSON(), "[""Name""]", "and the one required field")
    Do $$$AssertEquals(tBody.%Get("rules").%Size(), $ListLength(##class(OcuPilot.Api.Error).RoleViolationCodes()), "and one rule per role code")
    Kill tResources
    Set tIterator = tBody.%Get("resources").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tResources(tEntry.%Get("name")) = tEntry.%Get("permissions") _ "|" _ tEntry.%Get("privileged")
    }
    Do $$$AssertEquals($Get(tResources("%DB_USER")), "RW|0", "%DB_USER admits read and write, and is not privileged")
    Do $$$AssertEquals($Get(tResources("%Admin_Secure")), "U|1", "%Admin_Secure admits Use and is privileged")
    Do $$$AssertEquals($Get(tResources("%DB_IRISSECURITY")), "RW|0", "%DB_IRISSECURITY admits read and write, and is not privileged")
    Kill tMarked
    Set tIterator = tBody.%Get("roles").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRole) {
        Set tMarked(tRole.%Get("name")) = tRole.%Get("privileged")
    }
    Do $$$AssertEquals($Get(tMarked("%Manager"), "absent"), 1, "%Manager is marked privileged")
    Do $$$AssertEquals($Get(tMarked("%Developer"), "absent"), 0, "and an ordinary role is not")
}

/// <p><code>POST /roles</code> creates the role, whose vendor read carries the sent grants; a second
/// create under another spelling is refused as taken; and a privileged grant -- an administrative
/// resource and <code>%All</code> as a granted role -- is applied (AD-10).</p>
/// <p>Mutation: remove <code>Security.Role/PUT</code> from
/// <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> -> the port answers 501 and the
/// create leg goes red.</p>
Method TestTheCreateMakesTheRoleWithTheSentGrants()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH _ "?name=" _ ..#PROBEROLE, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the name look-up answers")
    If $IsObject($Get(tBody)) Do $$$AssertEquals(tBody.%Get("available"), 1, "and the probe name is free")

    Set tRequest = {"Name": (..#PROBEROLE), "Description": "OcuPilot wire probe", "Resources": [{"Name": "%DB_USER", "Permissions": "RW"}, {"Name": "%Service_Login", "Permissions": "U"}], "GrantedRoles": ["%Developer"]}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
    Do $$$AssertStatusOK(tSC, "the create answers")
    Do $$$AssertEquals(tStatus, 201, "at 201")
    If tStatus '= 201 Quit
    Do $$$AssertEquals(..Exists(..#PROBEROLE), 1, "the instance holds the role")
    Kill tQuery
    Set tQuery("name") = ..#PROBEROLE
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Role", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the vendor's GET answers")
    If $IsObject($Get(tRead)) {
        Do $$$AssertEquals(..Grants(tRead.%Get("Resources")), "%DB_USER:RW,%Service_Login:U", "with the grants sent")
        Do $$$AssertEquals(tRead.%Get("GrantedRoles").%ToJSON(), "[""%Developer""]", "the granted role sent")
        Do $$$AssertEquals(tRead.%Get("Description"), "OcuPilot wire probe", "and the description")
    }

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH _ "?name=" _ $ZConvert(..#PROBEROLE, "U"), .tStatus, .tBody)
    If $IsObject($Get(tBody)) Do $$$AssertEquals(tBody.%Get("available"), 0, "the name is taken now, in any case")
    Set tAgain = {"Name": ($ZConvert(..#PROBEROLE, "L")), "Description": "rewritten"}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tAgain.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 422, "a second create under another spelling is refused")
    If $IsObject($Get(tBody)) Do $$$AssertEquals(..FirstViolation(tBody), "Name " _ ##class(OcuPilot.Api.Error).#ROLENAMETAKEN, "on the name, as taken")
    Do $$$AssertEquals(..Property(..#PROBEROLE, "Description"), "OcuPilot wire probe", "and the role was not rewritten")

    Set tPrivileged = {"Name": (..#DELETEPROBE), "Resources": [{"Name": "%Admin_Secure", "Permissions": "U"}], "GrantedRoles": ["%All"]}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tPrivileged.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "a privileged grant is created at 201")
    Kill tQuery
    Set tQuery("name") = ..#DELETEPROBE
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Role", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    If $IsObject($Get(tRead)) {
        Do $$$AssertEquals(..Grants(tRead.%Get("Resources")), "%Admin_Secure:U", "with the administrative resource granted")
        Do $$$AssertEquals(tRead.%Get("GrantedRoles").%ToJSON(), "[""%All""]", "and %All granted")
    } Else {
        Do $$$AssertTrue(0, "the privileged role reads back")
    }
}

/// <p>AD-10 through the agent's path and the real port: a role create granting <code>%All</code> is
/// minted destructive with the privilege-grant consequence, and its confirm creates the role with
/// the grant.</p>
/// <p>Mutation: drop <code>tPrivileged</code> from the destructive value in
/// <method>OcuPilot.Kernel.Proposal.Mint.Mint</method> -> the destructive assertion goes red.</p>
Method TestAPrivilegedCreateConfirmedThroughTheRealPortIsApplied()
{
    Set tTool = "OcuPilot.Screen.Tool.RoleCreate"
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tArgs = {"Name": (..#GRANTPROBE), "GrantedRoles": ["%All"]}
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#LIST, $Parameter(tTool, "TOOLNAME"), $Username, "", tTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), ..#GRANTPROBE, $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
    Do $$$AssertStatusOK(tSC, "the create is minted")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals(+$Get(tValues("destructive")), 1, "destructive")
    Do $$$AssertEquals($Get(tValues("consequence")), $Parameter("OcuPilot.Kernel.Proposal.Mint", "CONSEQUENCEPRIVILEGED"), "and naming the privilege")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and confirmed: " _ $Get(tCode))
    Do $$$AssertEquals(..Exists(..#GRANTPROBE), 1, "the instance holds the role")
    Do $$$AssertTrue((","_$ZConvert(..Property(..#GRANTPROBE, "GrantedRoles"), "U")_",") [ ",%ALL,", "granting %All: " _ ..Property(..#GRANTPROBE, "GrantedRoles"))
}

/// <p><code>permissions.roles.delete</code> minted and confirmed through the shipped mint, confirm
/// and port removes the role, and the port's verifying re-read answers that it is gone.</p>
/// <p>Mutation: drop the <code>If $$$ISERR(tReadSC) &amp;&amp; (+$Get(tReadHttp) = 404) Quit $$$OK</code>
/// line from <method>OcuPilot.Port.AdminPort.VerifyGone</method> -> every verified delete fails and
/// this goes red.</p>
Method TestTheAgentDeleteThroughTheRealPortRemovesTheRole()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Roles).Create(..#DELETEPROBE, "OcuPilot delete probe", "%DB_USER:R", "")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Do $$$AssertStatusOK(tSC, "a probe role is created")
    If $$$ISERR(tSC) Quit

    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tArgs = {"Name": (..#DELETEPROBE)}
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", tTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), ..#DELETEPROBE, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
    Do $$$AssertStatusOK(tSC, "the delete is minted against the live role")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "deleted", "answering the deleted action")
    Do $$$AssertEquals(..Exists(..#DELETEPROBE), 0, "and the instance no longer holds the role")
}

/// <p>AD-10: the role-delete census over the real role graph. Only "does this account hold
/// <code>%All</code>" is armed (<method>OcuPilot.Test.ProposalFixture.ArmAllHolders</method>); the
/// population query, the holder filter and the walk through <code>GrantedRoles</code> run as
/// shipped. An account that reaches <code>%All</code> only through a role granted by another role
/// loses it when the inner role goes, so that delete leaves no holder; with <code>_SYSTEM</code>,
/// which holds <code>%All</code> directly, also counted, the same delete leaves one.</p>
/// <p>Mutations: make <method>OcuPilot.Kernel.Proposal.Prohibited.ReachesAllWithout</method> answer
/// 0 -> the kept-holder leg goes red; skip the deleted role only among the account's direct roles
/// -> the nested-holder leg goes red.</p>
Method TestTheDeleteCensusCountsOnlyHoldersThatLoseAllThroughTheRole()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Roles).Create(..#PATHPROBE, "OcuPilot census probe", "", "%All")
        If $$$ISOK(tSC) Set tSC = ##class(Security.Roles).Create(..#OUTERPROBE, "OcuPilot census probe", "", ..#PATHPROBE)
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(..#HOLDERPROBE, ..#OUTERPROBE, "ProbePass2026", "OcuPilot census probe")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Do $$$AssertStatusOK(tSC, "the census probes are created")
    If $$$ISERR(tSC) Quit

    Do ##class(OcuPilot.Test.ProposalFixture).ArmLastAllHolder("")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmAllHolders(..#HOLDERPROBE)
    Set tSC = $ClassMethod(..#SETFIXTURE, "DeletingLeavesNoAllHolder", ..#PATHPROBE, .tLeaves)
    Do $$$AssertStatusOK(tSC, "the census answers: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tLeaves, 1, "the only holder reaches %All through the deleted role, nested one level down, so the delete leaves no holder")
    Set tSC = $ClassMethod(..#SETFIXTURE, "DeletingLeavesNoAllHolder", ..#OUTERPROBE, .tLeaves)
    Do $$$AssertEquals(tLeaves, 1, "and so does deleting the role it holds directly")

    Do ##class(OcuPilot.Test.ProposalFixture).ArmAllHolders(..#HOLDERPROBE _ ",_SYSTEM")
    Set tSC = $ClassMethod(..#SETFIXTURE, "DeletingLeavesNoAllHolder", ..#PATHPROBE, .tLeaves)
    Do $$$AssertStatusOK(tSC, "the census answers again: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(tLeaves, 0, "with _SYSTEM holding %All directly, the same delete leaves a holder")
}

/// <p>AD-12: the two reads and the create each answer exactly one JSON envelope over a real HTTP
/// request, and a create naming nothing is refused on its own envelope code.</p>
/// <p>Mutation: render <method>OcuPilot.Area.Permissions.RoleCreate.RenderViolations</method> with
/// <code>USERVALIDATION</code> -> the envelope-code assertion goes red.</p>
Method TestEachRouteAnswersOneJsonEnvelopeOverTheWire()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    For tPath = tBase _ ..#FORMPATH, tBase _ ..#NAMEPATH _ "?name=" _ ..#PROBEROLE {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, tUser, tPassword, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tPath _ ": the request completes")
        Do $$$AssertEquals(tStatus, 200, tPath _ ": at 200")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tPath _ ": as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, tPath _ ": exactly one envelope")
    }
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, tUser, tPassword, .tStatus, .tBody, .tHeaders, "{}", "application/json")
    Do $$$AssertStatusOK(tSC, "the create request completes")
    Do $$$AssertEquals(tStatus, 422, "a body naming nothing is refused at 422")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Set tParsed = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tParsed.code, ##class(OcuPilot.Api.Error).#ROLEVALIDATION, "with the create's own envelope code")
}

/// <p><var>pResources</var>, the vendor's <code>[{Name, Permissions}]</code>, as
/// <code>name:letters</code> pairs sorted by name.</p>
ClassMethod Grants(pResources As %DynamicArray) As %String
{
    If '$IsObject(pResources) Quit ""
    Kill tSorted
    Set tIterator = pResources.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tGrant) {
        Set tSorted(tGrant.%Get("Name")) = tGrant.%Get("Permissions")
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey _ ":" _ tSorted(tKey)
    }
    Quit tOut
}

/// <p>The first <code>detail.violations</code> row of envelope <var>pBody</var>, as
/// <code>field code</code>, or <code>""</code>.</p>
ClassMethod FirstViolation(pBody As %DynamicObject) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("detail")) Quit ""
    Set tRows = pBody.%Get("detail").%Get("violations")
    If '$IsObject(tRows) || (tRows.%Size() = 0) Quit ""
    Quit tRows.%Get(0).%Get("field") _ " " _ tRows.%Get(0).%Get("code")
}

/// <p>Whether the instance holds a role named <var>pName</var>, in any case.</p>
ClassMethod Exists(pName As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Security.Roles).Exists(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tExists = 0
    }
    Quit tExists
}

/// <p>Role <var>pName</var>'s property <var>pProperty</var> as <method>Security.Roles.Get</method>
/// answers it, or <code>""</code>.</p>
ClassMethod Property(pName As %String, pProperty As %String) As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        If $$$ISOK(##class(Security.Roles).Get(pName, .tProps)) Set tValue = $Get(tProps(pProperty))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValue = ""
    }
    Quit tValue
}

/// <p>Delete the role named exactly <var>pName</var>, if there is one.</p>
ClassMethod Remove(pName As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Roles).Exists(pName) Do ##class(Security.Roles).Delete(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>Whether an account named <var>pName</var> exists.</p>
ClassMethod UserExists(pName As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Security.Users).Exists(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tExists = 0
    }
    Quit tExists
}

/// <p>Delete the account named exactly <var>pName</var>, if there is one.</p>
ClassMethod RemoveUser(pName As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(pName) Do ##class(Security.Users).Delete(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

}
