/// <p>Pins <code>permissions.roles.update</code> (Story 9.3, AD-3, AD-6, AD-10, AD-51, AD-53,
/// AD-55): its schema and settable set, its screen actions and values, a change adding
/// <code>%All</code> to a role's granted roles minted destructive with the privilege named, a change
/// restating what the role holds refused 400 <code>TOOL.ARGUMENTS</code>, and a broken field rule
/// refused at the mint.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, an account holding
/// <code>%Admin_Secure</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because it creates and deletes one role, <parameter>PROBEROLE</parameter>, by exact name.
/// <method>OnBeforeAllTests</method> refuses anywhere it does not.</p>
Class OcuPilot.Test.RoleUpdate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "OcuPilot.Screen.Tool.RoleUpdate";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter PROBEROLE = "OcuPilotProbeRoleUpdate";

Parameter PROBEMARKER = "OcuPilot role update probe";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RoleUpdate creates and deletes a role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ..EnsureProbe()
}

Method OnAfterAllTests() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit ..RemoveProbe()
}

/// <p>AD-3, AD-10: the tool is a merge write over the Roles list's own pairs; it admits exactly the
/// four fields the prohibited set has reviewed for a role; its schema types the escalation flag a
/// boolean and carries the two authored lists; and it declares the Roles list's four value actions,
/// each with the values it admits.</p>
/// <p>Mutation (Rule 19): drop <code>GrantedRoles</code> from
/// <method>OcuPilot.Screen.Tool.RoleUpdate.SettableFields</method> -- the settable and schema legs
/// go red.</p>
Method TestTheToolAdmitsTheReviewedFourAndDeclaresItsActions()
{
    Set tClass = ..#TOOL
    Do $$$AssertEquals($ClassMethod(tClass, "Endpoint") _ "/" _ $ClassMethod(tClass, "ReadType") _ "/" _ $ClassMethod(tClass, "WriteType") _ "/" _ $ClassMethod(tClass, "SendsBody"), "Security.Role/GET/PUT/1", "a merge write over the role endpoint")
    Do $$$AssertEquals(..Sorted($ClassMethod(tClass, "SettableFields")), ..Sorted($ClassMethod(..#SET, "PermittedChangeFields", "role")), "its settable set is the prohibited set's reviewed role list")
    Set tSchema = $ClassMethod(tClass, "InputSchema")
    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertEquals(tProperties.%Get("EscalationOnly").%Get("type"), "boolean", "the escalation flag is typed a boolean")
    Do $$$AssertEquals(tProperties.%Get("GrantedRoles").%Get("type") _ "/" _ tProperties.%Get("GrantedRoles").%Get("items").%Get("type"), "array/string", "the granted roles are a list of names")
    Do $$$AssertEquals(tProperties.%Get("Resources").%Get("type") _ "/" _ tProperties.%Get("Resources").%Get("items").%Get("type"), "array/object", "the grants a list of objects")
    Do $$$AssertEquals(tSchema.%Get("additionalProperties"), 0, "and the schema is closed")
    For tField = "Description", "EscalationOnly", "GrantedRoles", "Resources" {
        Do $$$AssertNotEquals(tProperties.%Get(tField).%Get("description"), "", tField _ " is described")
    }
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")), "add-granted-role,remove-granted-role,set-resource-grant,remove-resource-grant", "the four value actions")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionValueNames", "set-resource-grant")), "Resource,Permissions", "a grant set takes the resource and its letters")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionValueNames", "add-granted-role")), "Role", "a granted role its name")
    Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
    Do $$$AssertEquals(tResolved, 1, "its pairs resolve")
    Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Admin_Secure", "USE")) > 0, "and include %Admin_Secure:USE")
}

/// <p>AD-10 (the matrix's Agent privileged row): a change adding <code>%All</code> to the role's
/// granted roles is minted destructive with the privilege-grant consequence, and its diff names
/// <code>%All</code>.</p>
/// <p>Mutation (Rule 19): drop the role branch from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method> -- the destructive
/// assertion goes red.</p>
Method TestAPrivilegedGrantIsMintedDestructiveNamingThePrivilege()
{
    Set tSC = ..Mint({"Name": (..#PROBEROLE), "GrantedRoles": ["%Developer", "%All"]}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the change is minted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals(+$Get(tValues("destructive")), 1, "destructive")
    Do $$$AssertEquals($Get(tValues("consequence")), $Parameter("OcuPilot.Kernel.Proposal.Mint", "CONSEQUENCEPRIVILEGED"), "naming the privilege as its consequence")
    Set tRow = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tOne) {
        If tOne.%Get("field") = "GrantedRoles" Set tRow = tOne
    }
    Do $$$AssertTrue($IsObject(tRow) && (tRow.%Get("after") [ "%All"), "and the diff names %All: " _ $Select($IsObject(tRow): tRow.%ToJSON(), 1: ""))
}

/// <p>The editor's rule on both callers, and Epic 9's no-op rule: a change restating the role's own
/// description and granted roles is 400 <code>TOOL.ARGUMENTS</code> at the mint, never an empty
/// proposal; and a non-boolean escalation flag is refused naming <code>'EscalationOnly'</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.RoleUpdate.ArgumentProblem</method>
/// answer no problem -- the flag leg goes red.</p>
Method TestANoOpAndABrokenRuleAreRefusedAtTheMint()
{
    Set tSC = ..Mint({"Name": (..#PROBEROLE), "Description": (..#PROBEMARKER), "GrantedRoles": ["%Developer"]}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a change restating what the role holds is not proposed")
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "and is refused 400 TOOL.ARGUMENTS")
    Set tSC = ..Mint({"Name": (..#PROBEROLE), "Resources": [{"Name": "%DB_USER", "Permissions": "U"}]}, .tProposal, .tHttp, .tFault)
    Set tProblem = $Select($IsObject($Get(tFault)) && (tFault.%GetTypeOf("detail") = "object"): tFault.detail.%Get("problem"), 1: "")
    Do $$$AssertTrue(tProblem [ "'Resources'", "a grant its resource does not admit is refused naming 'Resources': " _ tProblem)
    Set tAnswer = ""
    Set tSC = $ClassMethod(..#TOOL, "ArgumentProblem", ..#PROBEROLE, {"EscalationOnly": "yes"}, .tAnswer)
    Do $$$AssertTrue(tAnswer [ "'EscalationOnly'", "a non-boolean flag is refused naming 'EscalationOnly': " _ tAnswer)
}

/// <p>Mint <var>pArgs</var> through the tool, as the model's call would, on a seeded completed turn.</p>
Method Mint(pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = $ClassMethod(..#TOOL, "View", "", pArgs, 0, .pProposal, .pHttp, .pFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit tSC
}

/// <p><var>pList</var> sorted, comma-separated, for an order-free comparison.</p>
ClassMethod Sorted(pList As %List) As %String
{
    Kill tSorted
    For tI = 1:1:$ListLength(pList) {
        Set tSorted($List(pList, tI)) = ""
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

/// <p>Create <parameter>PROBEROLE</parameter> afresh, granting <code>%Developer</code>: removed first
/// when it is this class's own, refused when a role of that name is anybody else's.</p>
Method EnsureProbe() As %Status
{
    Set tSC = ..RemoveProbe()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Roles).Create(..#PROBEROLE, ..#PROBEMARKER, "%Development:U", "%Developer")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete <parameter>PROBEROLE</parameter> when its description says it is this class's own.</p>
Method RemoveProbe() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Roles).Exists(..#PROBEROLE) {
            Kill tProps
            Set tSC = ##class(Security.Roles).Get(..#PROBEROLE, .tProps)
            If $$$ISOK(tSC) {
                If $Extract($Get(tProps("Description")), 1, $Length(..#PROBEMARKER)) = ..#PROBEMARKER {
                    Set tSC = ##class(Security.Roles).Delete(..#PROBEROLE)
                } Else {
                    Set tSC = $$$ERROR($$$GeneralError, "the role " _ ..#PROBEROLE _ " is not this class's own, so it was left alone")
                }
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
