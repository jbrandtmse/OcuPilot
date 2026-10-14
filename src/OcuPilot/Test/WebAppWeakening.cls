/// <p>Pins AD-10 as amended 2026-09-24 over real web applications (Story 9.2): making an application
/// reachable without signing in, clearing its resource and changing which code answers at its
/// address are permitted on an application that is not OcuPilot's own -- the agent's proposal is
/// minted destructive and names the effect, the confirm over the wire applies it, and the editor's
/// Save applies it -- and refused on one of OcuPilot's own, each with its own code, on both callers.
/// It also pins the card's one-code precedence for a proposal with several effects and for a
/// privileged role on an unauthenticated application.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it
/// creates and deletes two web applications by exact name and records one of them as OcuPilot's own
/// in install's record for the span of the class; <method>OnBeforeAllTests</method> refuses anywhere
/// it does not. Every proposal hangs off a turn <method>OcuPilot.Test.ProposalFixture.SeedTurn</method>
/// created, removed in <method>OnAfterOneTest</method>.</p>
Class OcuPilot.Test.WebAppWeakening Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter APIBASE = "/api/ocupilot";

Parameter TOOL = "OcuPilot.Screen.Tool.WebAppUpdate";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The application that is not OcuPilot's own.</p>
Parameter PROBEAPP = "/csp/ocupilotprobeweakening";

/// <p>The application recorded as OcuPilot's own for the span of this class.</p>
Parameter OWNAPP = "/csp/ocupilotprobeweakeningown";

/// <p>DW-1493: a create the agent names re-cased and slash-suffixed, and the name the instance holds
/// once it is confirmed.</p>
Parameter CASETYPED = "/csp/OcuPilotProbeWeakeningCase/";

Parameter CASESTORED = "/csp/OcuPilotProbeWeakeningCase";

/// <p>The description both are created with, which is how each is recognised as this class's own
/// before it is deleted.</p>
Parameter PROBEMARKER = "OcuPilot weakening probe";

/// <p>DW-2425: three resources this class creates and removes, whose public permission holds USE, only read, and none.</p>
Parameter PUBLICUSE = "OCUPILOTPROBEWEAKPUBLICU";

Parameter PUBLICREAD = "OCUPILOTPROBEWEAKPUBLICR";

Parameter PUBLICNONE = "OCUPILOTPROBEWEAKNONE";

/// <p>The class a repointed application's dispatch class names: a <class>%CSP.REST</class> class
/// this install compiles, so the vendor accepts it.</p>
Parameter DISPATCHCLASS = "OcuPilot.Api.Router";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.WebAppWeakening creates and deletes web applications on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Set tSC = ..EnsureProbes()
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#OWNAPP)
    Quit ##class(OcuPilot.Kernel.State.WebApp).GuardedRecord("probe", ..#OWNAPP, "created")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#OWNAPP), "install's record of the own probe is removed")
    Do $$$AssertStatusOK(..RemoveResources(), "the public-permission probe resources are removed")
    Do $$$AssertEquals(..ResourcesHeld(), 0, "and none is left")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Do ##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#OWNAPP)
    Do ..RemoveResources()
    Set tSC = ##class(OcuPilot.Test.WebAppSave).RemoveApp(..#PROBEAPP, ..#PROBEMARKER)
    Set tOwnSC = ##class(OcuPilot.Test.WebAppSave).RemoveApp(..#OWNAPP, ..#PROBEMARKER)
    Set tCaseSC = ##class(OcuPilot.Test.WebAppSave).RemoveApp(..#CASESTORED, ..#PROBEMARKER)
    If $$$ISERR(tSC) Quit tSC
    If $$$ISERR(tOwnSC) Quit tOwnSC
    Quit tCaseSC
}

/// <p>The three weakening changes, each as <code>$ListBuild(field, JSON value, effect parameter,
/// own-application code parameter)</code>.</p>
ClassMethod Changes() As %List
{
    Quit $ListBuild($ListBuild("AutheEnabled", "96", "EFFECTUNAUTHENTICATED", "UNAUTHENTICATED"), $ListBuild("Resource", """""", "EFFECTNORESOURCE", "AUTHORIZATION"), $ListBuild("DispatchClass", """" _ ..#DISPATCHCLASS _ """", "EFFECTREPOINTED", "DISPATCH"))
}

/// <p>On an application that is not OcuPilot's own, each weakening change the agent proposes is
/// minted destructive and carries its effect as the consequence, and its confirm over the wire is
/// applied: 200, and the change reads back.</p>
/// <p>Mutation (Rule 19): drop <code>|| (tEffect '= "")</code> from the mint's
/// <code>destructive</code> in <method>OcuPilot.Kernel.Proposal.Mint.Mint</method> -- the
/// destructive assertions go red.</p>
Method TestEachWeakeningIsMintedDestructiveAndAppliesOnceConfirmed()
{
    Set tChanges = ..Changes()
    For tI = 1:1:$ListLength(tChanges) {
        Set tChange = $List(tChanges, tI)
        Set tField = $List(tChange, 1)
        Do $$$AssertStatusOK(..EnsureProbes(), tField _ ": the probe starts afresh")
        Set tKey = ..Mint(..#PROBEAPP, ..Args(tField, $List(tChange, 2)), .tProposal, .tHttp, .tFault)
        Do $$$AssertNotEquals(tKey, "", tField _ ": the proposal is minted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If tKey = "" Continue
        Do ..Stored(tKey, .tDestructive, .tConsequence)
        Do $$$AssertEquals(tDestructive, 1, tField _ ": marked destructive")
        Do $$$AssertEquals(tConsequence, $Parameter(..#SET, $List(tChange, 3)), tField _ ": naming its effect")
        Set tSC = ..Confirm(tKey, .tStatus, .tBody)
        Do $$$AssertStatusOK(tSC, tField _ ": the confirm request completes")
        Do $$$AssertEquals(tStatus, 200, tField _ ": and is applied: " _ tBody)
        Do $$$AssertEquals(..Field(..#PROBEAPP, tField), ..Rendered(tField, $List(tChange, 2)), tField _ ": and the change reads back")
    }
}

/// <p>The same three changes as the editor's Save over the wire, on an application that is not
/// OcuPilot's own: each is 200 and reads back.</p>
/// <p>Mutation (Rule 19): restore the three arms for every application in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WebApplication</method> -- every leg answers 403 and
/// goes red.</p>
Method TestEachWeakeningAppliesAsASave()
{
    Set tChanges = ..Changes()
    For tI = 1:1:$ListLength(tChanges) {
        Set tChange = $List(tChanges, tI)
        Set tField = $List(tChange, 1)
        Do $$$AssertStatusOK(..EnsureProbes(), tField _ ": the probe starts afresh")
        Set tSC = ..Save(..#PROBEAPP, "{""" _ tField _ """:" _ $List(tChange, 2) _ "}", .tStatus, .tBody)
        Do $$$AssertStatusOK(tSC, tField _ ": the Save request completes")
        Do $$$AssertEquals(tStatus, 200, tField _ ": and is applied")
        Do $$$AssertEquals(..Field(..#PROBEAPP, tField), ..Rendered(tField, $List(tChange, 2)), tField _ ": and the change reads back")
    }
}

/// <p>On an application recorded as OcuPilot's own, each weakening change is refused with its own
/// code on both callers -- the confirm over the wire and the editor's Save -- and the application is
/// left as it was.</p>
/// <p>Mutation (Rule 19): delete the three own-application arms from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WebApplication</method> -- each answers
/// <code>SERVINGPATH</code> and the code assertions go red.</p>
Method TestEachWeakeningIsRefusedWithItsOwnCodeOnOcuPilotsOwn()
{
    Set tChanges = ..Changes()
    For tI = 1:1:$ListLength(tChanges) {
        Set tChange = $List(tChanges, tI)
        Set tField = $List(tChange, 1)
        Set tCode = $Parameter(..#SET, $List(tChange, 4))
        Set tBefore = ..Field(..#OWNAPP, tField)
        Set tKey = ..Mint(..#OWNAPP, ..Args(tField, $List(tChange, 2)), .tProposal, .tHttp, .tFault)
        Do $$$AssertNotEquals(tKey, "", tField _ ": the proposal is minted")
        If tKey '= "" {
            Set tSC = ..Confirm(tKey, .tStatus, .tBody)
            Do $$$AssertEquals(tStatus, 403, tField _ ": the confirm is refused: " _ tBody)
            Do $$$AssertEquals(..Code(tBody), tCode, tField _ ": with " _ tCode)
        }
        Set tSC = ..Save(..#OWNAPP, "{""" _ tField _ """:" _ $List(tChange, 2) _ "}", .tStatus, .tBody)
        Do $$$AssertEquals(tStatus, 403, tField _ ": the Save is refused: " _ tBody)
        Do $$$AssertEquals(..Code(tBody), tCode, tField _ ": with " _ tCode)
        Do $$$AssertEquals(..Field(..#OWNAPP, tField), tBefore, tField _ ": and the application is as it was")
    }
}

/// <p>The matrix's several-effects row: one proposal adding the unauthenticated bit, clearing the
/// resource and changing the dispatch class is destructive with the one consequence
/// <code>WEBAPP.UNAUTHENTICATED</code> and a diff row for each field.</p>
/// <p>Mutation (Rule 19): in <method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method>,
/// test the cleared resource before the added unauthenticated bit -- the consequence reads
/// <code>WEBAPP.NORESOURCE</code> and this goes red.</p>
Method TestSeveralEffectsNameTheFirstInPrecedence()
{
    Set tArgs = {"Name": (..#PROBEAPP), "AutheEnabled": 96, "Resource": "", "DispatchClass": (..#DISPATCHCLASS)}
    Set tKey = ..Mint(..#PROBEAPP, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertNotEquals(tKey, "", "the proposal is minted")
    If tKey = "" Quit
    Do ..Stored(tKey, .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive, 1, "marked destructive")
    Do $$$AssertEquals(tConsequence, $Parameter(..#SET, "EFFECTUNAUTHENTICATED"), "naming the first effect in precedence")
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 3, "with a diff row for each of the three fields")
}

/// <p>The matrix's privileged-role row: application roles granting <code>%All</code> on an
/// unauthenticated application are minted destructive with the one combined consequence
/// <code>WEBAPP.UNAUTHENTICATEDPRIVILEGED</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.WebAppUpdate.Consequence</method> answer
/// <code>""</code> -- the consequence reads <code>GRANT.PRIVILEGED</code> and this goes red.</p>
Method TestAPrivilegedRoleOnAnUnauthenticatedApplicationIsOneLine()
{
    Do $$$AssertStatusOK(..Save(..#PROBEAPP, "{""AutheEnabled"":64}", .tStatus, .tBody), "the probe is made unauthenticated")
    Do $$$AssertEquals(tStatus, 200, "and the Save is applied")
    Set tArgs = {"Name": (..#PROBEAPP), "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}]}
    Set tKey = ..Mint(..#PROBEAPP, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertNotEquals(tKey, "", "the proposal is minted")
    If tKey = "" Quit
    Do ..Stored(tKey, .tDestructive, .tConsequence)
    Do $$$AssertEquals(tDestructive, 1, "marked destructive")
    Do $$$AssertEquals(tConsequence, ##class(OcuPilot.Screen.Tool.WebAppCreate).#CONSEQUENCEUNAUTHENTICATEDPRIVILEGED, "with the one combined consequence")
}

/// <p>DW-2320 (AD-10): an application holding <code>%All</code> for a matching role, sent the same target for another
/// matching role (an empty one grants it to every caller), is minted destructive with <code>GRANT.PRIVILEGED</code>; the
/// same pair re-sent beside an unprivileged one is minted ordinary.</p>
/// <p>Mutation (Rule 19): key <method>OcuPilot.Kernel.Proposal.Prohibited.ApplicationRoleNames</method> by the target alone
/// -- the moved leg goes red.</p>
Method TestAHeldPrivilegedTargetMovedToAnotherMatchingRoleIsAGrant()
{
    Set tBody = {"NameSpace": ($Namespace), "Description": (..#PROBEMARKER), "AutheEnabled": 32, "Resource": "%Development", "Enabled": true, "DispatchClass": "", "MatchRoles": [{"MatchRole": "%Developer", "TargetRoles": ["%All"]}]}
    Do $$$AssertStatusOK(##class(OcuPilot.Test.WebAppSave).EnsureApp(..#PROBEAPP, ..#PROBEMARKER, tBody), "the probe holds %All for a matching role")
    Set tKey = ..Mint(..#PROBEAPP, {"MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}]}, .tProposal, .tHttp, .tFault)
    Do $$$AssertNotEquals(tKey, "", "the move to every caller is minted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If tKey '= "" {
        Do ..Stored(tKey, .tDestructive, .tConsequence)
        Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "1 " _ ##class(OcuPilot.Kernel.Proposal.Mint).#CONSEQUENCEPRIVILEGED, "destructive, naming the privilege")
    }
    Set tKey = ..Mint(..#PROBEAPP, {"MatchRoles": [{"MatchRole": "%Developer", "TargetRoles": ["%All"]}, {"MatchRole": "%Manager", "TargetRoles": ["%DB_HSCUSTOM"]}]}, .tProposal, .tHttp, .tFault)
    Do $$$AssertNotEquals(tKey, "", "the held pair re-sent beside an unprivileged one is minted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If tKey '= "" {
        Do ..Stored(tKey, .tDestructive, .tConsequence)
        Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "0 ", "ordinary")
    }
}

/// <p>DW-2425 (AD-10): enabling a disabled application, and pointing its resource at one whose public permission holds
/// USE, are grants while a granted role is privileged -- minted destructive with <code>GRANT.PRIVILEGED</code> -- and
/// ordinary for an application that grants nothing privileged, for a resource whose public permission only reads and for
/// one with none; a resource the instance cannot read counts as public. Clearing a privileged application's resource
/// keeps its own effect.</p>
/// <p>Mutation (Rule 19): drop the <code>RepointsToPublicResource</code> clause from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WidensPrivilegedReach</method> -- the public-resource legs go red; drop the
/// web application's call of <method>OcuPilot.Kernel.Proposal.Prohibited.WidensPrivilegedReach</method> from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method> -- every grant leg goes red.</p>
Method TestEnablingAndAPublicResourceAreGrantsWhileAPrivilegedRoleIsGranted()
{
    Do ..RemoveResources()
    Do $$$AssertStatusOK(..AddResource(..#PUBLICUSE, "U"), "a resource whose public permission holds USE")
    Do $$$AssertStatusOK(..AddResource(..#PUBLICREAD, "R"), "one that only reads")
    Do $$$AssertStatusOK(..AddResource(..#PUBLICNONE, ""), "and one with none")
    Set tGranted = "{""NameSpace"": """ _ $Namespace _ """, ""Description"": """ _ ..#PROBEMARKER _ """, ""AutheEnabled"": 32, ""Resource"": ""%Development"", ""Enabled"": false, ""DispatchClass"": """", ""MatchRoles"": [{""MatchRole"": """", ""TargetRoles"": [""%All""]}]}"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.WebAppSave).EnsureApp(..#PROBEAPP, ..#PROBEMARKER, ##class(%DynamicAbstractObject).%FromJSON(tGranted)), "a disabled application granting %All")
    For tCase = $ListBuild("Enabled", "true", "enabling it", 1), $ListBuild("Resource", """" _ ..#PUBLICUSE _ """", "pointing its resource at one the public holds USE of", 1), $ListBuild("Resource", """" _ ..#PUBLICREAD _ """", "pointing it at one the public only reads", 0), $ListBuild("Resource", """" _ ..#PUBLICNONE _ """", "pointing it at one the public holds nothing of", 0), $ListBuild("Resource", """OcuPilotProbeNoSuchResource""", "pointing it at a resource the instance cannot read", 1) {
        Set tKey = ..Mint(..#PROBEAPP, ..Args($List(tCase, 1), $List(tCase, 2)), .tProposal, .tHttp, .tFault)
        Do $$$AssertNotEquals(tKey, "", $List(tCase, 3) _ " is minted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If tKey = "" Continue
        Do ..Stored(tKey, .tDestructive, .tConsequence)
        Do $$$AssertEquals(tDestructive _ " " _ tConsequence, $Select($List(tCase, 4): "1 " _ ##class(OcuPilot.Kernel.Proposal.Mint).#CONSEQUENCEPRIVILEGED, 1: "0 "), $List(tCase, 3) _ " while it grants %All")
    }
    Set tKey = ..Mint(..#PROBEAPP, {"Resource": ""}, .tProposal, .tHttp, .tFault)
    Do $$$AssertNotEquals(tKey, "", "clearing its resource is minted")
    If tKey '= "" {
        Do ..Stored(tKey, .tDestructive, .tConsequence)
        Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "1 " _ $Parameter(..#SET, "EFFECTNORESOURCE"), "with its own effect")
    }
    Set tPlain = $Replace(tGranted, "%All", "%DB_HSCUSTOM")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.WebAppSave).EnsureApp(..#PROBEAPP, ..#PROBEMARKER, ##class(%DynamicAbstractObject).%FromJSON(tPlain)), "the same application granting nothing privileged")
    For tCase = $ListBuild("Enabled", "true"), $ListBuild("Resource", """" _ ..#PUBLICUSE _ """") {
        Set tKey = ..Mint(..#PROBEAPP, ..Args($List(tCase, 1), $List(tCase, 2)), .tProposal, .tHttp, .tFault)
        Do $$$AssertNotEquals(tKey, "", $List(tCase, 1) _ " is minted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        If tKey = "" Continue
        Do ..Stored(tKey, .tDestructive, .tConsequence)
        Do $$$AssertEquals(tDestructive _ " " _ tConsequence, "0 ", $List(tCase, 1) _ " is ordinary")
    }
}

/// <p>Create the probe resource <var>pName</var> with public permission <var>pPermission</var> in <code>%SYS</code>,
/// replacing one of that name.</p>
ClassMethod AddResource(pName As %String, pPermission As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Resources).Exists(pName) Set tSC = ##class(Security.Resources).Delete(pName)
        If $$$ISOK(tSC) Set tSC = ##class(Security.Resources).Create(pName, ..#PROBEMARKER, pPermission)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>How many of the three probe resources the instance holds.</p>
ClassMethod ResourcesHeld() As %Integer
{
    Set tHeld = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tName = ..#PUBLICUSE, ..#PUBLICREAD, ..#PUBLICNONE {
            If ##class(Security.Resources).Exists(tName) Set tHeld = tHeld + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tHeld = -1
    }
    Quit tHeld
}

/// <p>Delete the three probe resources.</p>
ClassMethod RemoveResources() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tName = ..#PUBLICUSE, ..#PUBLICREAD, ..#PUBLICNONE {
            If ##class(Security.Resources).Exists(tName) Set tSC = $$$ADDSC(tSC, ##class(Security.Resources).Delete(tName))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>DW-1493 (AD-54): an agent create confirmed over the wire leaves the instance holding the
/// application under the spelling the caller typed, while the proposal's reference stays
/// canonical.</p>
/// <p>Mutation (Rule 19): drop the typed-name branch from
/// <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> -- the instance holds the
/// canonical lower-case spelling and this goes red.</p>
Method TestAConfirmedCreateIsStoredAsTyped()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.WebAppSave).RemoveApp(..#CASESTORED, ..#PROBEMARKER), "no earlier probe survives")
    Set tTool = "OcuPilot.Screen.Tool.WebAppCreate"
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tArgs = {"Name": (..#CASETYPED), "NameSpace": ($Namespace), "Description": (..#PROBEMARKER), "AutheEnabled": 32}
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(tTool, "DESCRIPTORCLASS"), $Parameter(tTool, "TOOLNAME"), tUser, "", tTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), ..#CASETYPED, $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
    Do $$$AssertStatusOK(tSC, "the create is minted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("target").%Get("id"), $ZConvert(..#CASESTORED, "L"), "under the canonical reference")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "the confirm request completes")
    Do $$$AssertEquals(tStatus, 200, "and is applied: " _ tBody)
    Do $$$AssertEquals(..StoredName(..#CASESTORED), ..#CASESTORED, "and the instance holds the name as it was typed")
}

/// <p>The name <class>Security.Applications</class> holds for the application <var>pName</var>
/// resolves to, in the spelling it was stored under, or <code>""</code>.</p>
ClassMethod StoredName(pName As %String) As %String
{
    Set tName = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        If $$$ISOK(##class(Security.Applications).Get(pName, .tProps)) Set tName = $Get(tProps("Name"))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tName
}

/// <p>The arguments setting <var>pField</var> to the JSON value <var>pJson</var>.</p>
Method Args(pField As %String, pJson As %String) As %DynamicObject
{
    Quit ##class(%DynamicAbstractObject).%FromJSON("{""" _ pField _ """:" _ pJson _ "}")
}

/// <p><var>pJson</var> as the diff renders the value.</p>
ClassMethod Rendered(pField As %String, pJson As %String) As %String
{
    Set tObject = ##class(%DynamicAbstractObject).%FromJSON("{""v"":" _ pJson _ "}")
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Display(tObject.%Get("v"), tObject.%GetTypeOf("v"))
}

/// <p>Mint one <code>webapp.list.update</code> proposal against <var>pName</var> from
/// <var>pArgs</var> through the shipped mint and the shipped port, owned by the suite's HTTP account
/// inside a seeded turn, so the confirm over the wire is that account's own. Answers the proposal id,
/// or <code>""</code>.</p>
Method Mint(pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %String
{
    Set pProposal = ""
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Do pArgs.%Set("Name", pName, "string")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(..#TOOL, "DESCRIPTORCLASS"), $Parameter(..#TOOL, "TOOLNAME"), tUser, "", tTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttp, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pName, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
    If $$$ISERR(tSC) || '$IsObject($Get(pProposal)) Quit ""
    Quit pProposal.%Get("proposalId")
}

/// <p>The stored proposal <var>pKey</var>'s destructive marking and consequence code.</p>
ClassMethod Stored(pKey As %String, Output pDestructive As %Boolean, Output pConsequence As %String)
{
    Set pDestructive = ""
    Set pConsequence = "<absent>"
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pKey, .tFound, .tValues)
    If $$$ISERR(tSC) || '$Get(tFound) Quit
    Set pDestructive = +$Get(tValues("destructive"))
    Set pConsequence = $Get(tValues("consequence"))
}

/// <p>POST the confirm route for <var>pKey</var> as the suite's HTTP account.</p>
Method Confirm(pKey As %String, Output pStatus As %Integer, Output pBody As %String) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/proposal/" _ pKey _ "/confirm", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBody, .tHeaders, "", "application/json")
}

/// <p>PUT the editor's Save route for <var>pName</var> with the JSON body <var>pJson</var>.</p>
Method Save(pName As %String, pJson As %String, Output pStatus As %Integer, Output pBody As %String) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", ..#APIBASE _ ##class(OcuPilot.Test.WebAppSave).Path(pName), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBody, .tHeaders, pJson, "application/json")
}

/// <p>The <code>code</code> of the envelope <var>pBody</var>, or <code>""</code>.</p>
ClassMethod Code(pBody As %String) As %String
{
    Set tCode = ""
    Try {
        Set tCode = ##class(%DynamicAbstractObject).%FromJSON(pBody).%Get("code")
    } Catch {
        Set tCode = ""
    }
    Quit tCode
}

/// <p><var>pName</var>'s <var>pField</var> as the vendor's own read answers it, rendered as the diff
/// renders it.</p>
ClassMethod Field(pName As %String, pField As %String) As %String
{
    If $$$ISERR(##class(OcuPilot.Test.WebAppSave).Fresh(pName, .tFresh)) || '$IsObject($Get(tFresh)) Quit "<unread>"
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Display(tFresh.%Get(pField), tFresh.%GetTypeOf(pField))
}

/// <p>Create both probes afresh: password authentication, a resource, and no dispatch class.</p>
Method EnsureProbes() As %Status
{
    Set tBody = {"NameSpace": ($Namespace), "Description": (..#PROBEMARKER), "AutheEnabled": 32, "Resource": "%Development", "Enabled": true, "DispatchClass": ""}
    Set tSC = ##class(OcuPilot.Test.WebAppSave).EnsureApp(..#PROBEAPP, ..#PROBEMARKER, tBody)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Test.WebAppSave).EnsureApp(..#OWNAPP, ..#PROBEMARKER, tBody)
}

}
