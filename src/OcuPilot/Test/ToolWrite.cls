/// <p>Pins the first write tool (Story 5.1, AD-3, AD-10, AD-22, AD-40): the registry advertises it
/// as a <code>write</code> tool fulfilled on the instance, its schema is derived and admits no
/// privilege subtree, the model can reach the minting path and not the claim gate, and the
/// dispatcher's write branch is exercised through the <b>real</b> restraint verdict.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, an account holding
/// <code>%All</code>, and one web application the instance already serves --
/// <parameter>LIVETARGET</parameter>, OcuPilot's own shell application, which is read and never
/// written. It creates no principal and changes nothing on the instance; the only rows it writes
/// are its own proposal and ledger rows, removed in <method>OnAfterOneTest</method>.</p>
/// <p><b>The restraint seam is deliberately left unset</b> (DW-449). Every earlier exercise of the
/// write branch forced a verdict, so the branch was pinned and the verdict was not: here the real
/// <method>OcuPilot.Kernel.Restraint.Verdict</method> decides, against a per-user hold this class
/// writes and removes.</p>
Class OcuPilot.Test.ToolWrite Extends %UnitTest.TestCase
{

Parameter TOOL = "webapp.list.update";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.WebAppUpdate";

/// <p>Story 5.9's write tool, pinned here beside Story 5.5's because both questions are "what does
/// the registry advertise, with which pairs".</p>
Parameter USERTOOL = "permissions.users.update";

Parameter USERTOOLCLASS = "OcuPilot.Screen.Tool.UserUpdate";

/// <p>Story 5.10's write tool and its class: the first destructive one, and the first whose screen
/// is not built.</p>
Parameter AUDITTOOL = "security.auditing.update";

Parameter AUDITTOOLCLASS = "OcuPilot.Screen.Tool.AuditingUpdate";

Parameter WRITEBASE = "OcuPilot.Screen.Tool.Write";

Parameter REGISTRY = "OcuPilot.Screen.Tool.Registry";

Parameter PROBE = "OcuPilot.Test.ToolDispatchProbe";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The web application every live-read test names: OcuPilot's own shell, which the instance
/// serves and which this class only ever reads.</p>
Parameter LIVETARGET = "/ocupilot";

Parameter PROBETURN = "OcuPilotProbeToolWriteTurn";

Parameter PROBECONV = "OcuPilotProbeToolWriteConv";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds)
    Do $$$AssertStatusOK(tSC, "every switch row and hold this class wrote is removed")
    Do $$$AssertEquals(tHolds, 0, "and none survives")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForTurn(..#PROBETURN), "the probe turn's proposals are removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(..#PROBETURN), "and its ledger rows")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedCountForTurn(..#PROBETURN, .tLeft), "the remainder is counted")
    Do $$$AssertEquals(tLeft, 0, "and no proposal of this class survives")
    Quit $$$OK
}

/// <p>AD-22: adding a compiled concrete tool class is the whole registration.</p>
Method TestTheRegistryAdvertisesItAsAWriteToolFulfilledOnTheInstance()
{
    Set tSC = $ClassMethod(..#REGISTRY, "Resolve", ..#TOOL, .tTool)
    Do $$$AssertStatusOK(tSC, "the registry resolves the tool by name")
    Do $$$AssertTrue($IsObject(tTool), "and finds it")
    Do $$$AssertEquals(tTool.%Get("kind"), "write", "it is a write tool")
    Do $$$AssertEquals(tTool.%Get("class"), ..#TOOLCLASS, "answered by its own class")
    Do $$$AssertEquals(tTool.%Get("descriptor"), "", "with no descriptor of the registry's choosing")
    Do $$$AssertEquals($ClassMethod(..#REGISTRY, "FulfilmentOf", tTool), "instance", "and it is fulfilled on the instance, never in the browser")

    Set tSC = $ClassMethod(..#REGISTRY, "ProviderTools", .tTools)
    Do $$$AssertStatusOK(tSC, "the provider tool array builds")
    Set tFound = 0
    For tI = 1:1:+$Get(tTools) {
        If tTools(tI, "name") = "webapp_list_update" Set tFound = tI
    }
    Do $$$AssertNotEquals(tFound, 0, "and it is advertised under its wire name")
    Do $$$AssertNotEquals(tTools(tFound, "description"), "", "with a description")
}

/// <p>AD-3: the schema is the classified field list, and nothing else.</p>
Method TestTheSchemaIsDerivedFromTheClassifiedFieldList()
{
    Set tSchema = $ClassMethod(..#TOOLCLASS, "InputSchema")
    Do $$$AssertEquals(tSchema.%Get("additionalProperties"), 0, "the schema is closed")
    Do $$$AssertEquals(tSchema.%Get("required").%Get(0), "Name", "and requires the target's name")
    Do $$$AssertEquals(tSchema.%Get("required").%Size(), 1, "and nothing else")

    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertNotEquals(tProperties.%GetTypeOf("Enabled"), "unassigned", "an ordinary boolean field is admitted")
    Do $$$AssertEquals(tProperties.%Get("Enabled").%Get("type"), "boolean", "with its own JSON type")
    Do $$$AssertEquals(tProperties.%Get("Resource").%Get("type"), "string", "and a string field with its")
    ; The shipped tool admits four reviewed fields (AD-10), none of them an array, so the array
    ; shape is read on the probe subclass that lifts the positive restriction and nothing else.
    Set tWide = $ClassMethod("OcuPilot.Test.WriteExclusion", "InputSchema").%Get("properties")
    Do $$$AssertEquals(tWide.%Get("CorsAllowlist").%Get("type"), "array", "an array field is an array")
    Do $$$AssertEquals(tWide.%Get("CorsAllowlist").%Get("items").%Get("type"), "string", "of its element type")
    Do $$$AssertEquals(tProperties.%GetTypeOf("CorsAllowlist"), "unassigned", "and the shipped tool advertises no field the prohibited set has not reviewed")

    Set tFields = $ClassMethod(..#TOOLCLASS, "SettableFields")
    Do $$$AssertTrue($ListFind(tFields, "Enabled") > 0, "the settable fields are derived from the same entry")
    Do $$$AssertEquals($ListFind(tFields, "Name"), 0, "the identifying argument is not one of them")
    Do $$$AssertEquals($ListFind(tFields, "MatchRoles"), 0, "and neither is the role subtree")
}

/// <p>AD-10: privilege is not granted through any path, so the role subtree is not in the schema
/// and a call carrying it is refused as an unknown argument.</p>
/// <p>Mutation: classify the subtree <code>ordinary</code> in
/// <class>OcuPilot.Screen.Tool.Classification</class> and give it a top-level field-list row --
/// this goes red. Removing <code>MatchRoles</code> from <method>ExcludedFields</method> alone does
/// not admit it: its two field-list paths are dotted, so the nested-path filter drops them first.
/// The exclusion filter's own effect is pinned by
/// <method>TestAnExcludedFieldLeavesTheSchemaAndTheSettableList</method>.</p>
Method TestARoleGrantIsRefusedAsAnUnknownArgument()
{
    Set tSchema = $ClassMethod(..#TOOLCLASS, "InputSchema")
    Do $$$AssertEquals(tSchema.%Get("properties").%GetTypeOf("MatchRoles"), "unassigned", "the schema admits no role subtree")
    Do $$$AssertTrue($ListFind($ClassMethod(..#TOOLCLASS, "ExcludedFields"), "MatchRoles") > 0, "the tool excludes it by name")

    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"Name": "/csp/probe", "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}]}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "a call carrying one is refused")
    Do $$$AssertTrue(tProblem [ "MatchRoles", "naming the argument")

    Set tSC = $ClassMethod(..#TOOLCLASS, "View", "", {"Name": "/csp/probe", "MatchRoles": []}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "and the view refuses it too")
    Do $$$AssertEquals(tHttp, 400, "as a 400")
    Do $$$AssertEquals(tFault.%Get("code"), ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "with the arguments code")
}

/// <p>QA (Story 5.5): <method>OcuPilot.Test.Prohibited.TestNoWriteToolAdmitsAnAlwaysProhibitedField</method>
/// proves <code>DispatchClass</code> mints nothing against a real target; this is the same rigor for
/// <code>MatchRoles</code>, which that test only checks at the schema level. Against
/// <parameter>LIVETARGET</parameter> -- a real, never-written application -- a role grant is refused
/// before any proposal exists, not only before the shipped tool's own schema.</p>
/// <p>Mutation: classify the <code>MatchRoles</code> subtree <code>ordinary</code> in
/// <class>OcuPilot.Screen.Tool.Classification</class> and give it a top-level field-list row (the
/// same mutation <method>TestARoleGrantIsRefusedAsAnUnknownArgument</method> names) -- this goes red
/// on the refusal and on the mint count.</p>
Method TestARoleGrantIsRefusedAndMintsNothingAgainstARealTarget()
{
    Set tBefore = ##class(OcuPilot.Test.ProposalFixture).ProposalCount($Username)
    Do $$$AssertTrue(tBefore > -1, "the running account's proposal rows are counted")
    Set tSC = $ClassMethod(..#TOOLCLASS, "View", "", {"Name": (..#LIVETARGET), "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}]}, 200, .tResult, .tHttp, .tFault)
    ; Read before anything is asserted, so a call that was not refused is still counted rather
    ; than raising on the absent fault and leaving this unanswered.
    Set tAfter = ##class(OcuPilot.Test.ProposalFixture).ProposalCount($Username)
    Do $$$AssertStatusNotOK(tSC, "a call asking for a role grant against a real, live target is refused")
    Do $$$AssertEquals(tAfter, tBefore, "and no proposal was minted for this account")
    Do $$$AssertEquals(tHttp, 400, "at 400")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "with the arguments code")
}

/// <p>QA (Story 5.5): the same mints-nothing rigor for a field AD-10's set has simply never reviewed
/// (<code>EventClass</code> -- classified <code>ordinary</code> in
/// <class>OcuPilot.Screen.Tool.Classification</class>, but outside
/// <parameter>OcuPilot.Screen.Tool.WebAppUpdate.PERMITTEDFIELDS</parameter>): the positive list is
/// what refuses it, not a named exclusion the way <code>MatchRoles</code> and
/// <code>DispatchClass</code> are, and the model asking for it against a real target is still
/// refused before any proposal exists.</p>
/// <p>Mutation: add <code>EventClass</code> to
/// <parameter>OcuPilot.Screen.Tool.WebAppUpdate.PERMITTEDFIELDS</parameter> -- this goes red on the
/// refusal and on the mint count.</p>
Method TestAnUnreviewedFieldIsRefusedAndMintsNothingAgainstARealTarget()
{
    Set tBefore = ##class(OcuPilot.Test.ProposalFixture).ProposalCount($Username)
    Do $$$AssertTrue(tBefore > -1, "the running account's proposal rows are counted")
    Set tSC = $ClassMethod(..#TOOLCLASS, "View", "", {"Name": (..#LIVETARGET), "EventClass": "Probe.Event"}, 200, .tResult, .tHttp, .tFault)
    Set tAfter = ##class(OcuPilot.Test.ProposalFixture).ProposalCount($Username)
    Do $$$AssertStatusNotOK(tSC, "a call asking for an unreviewed field against a real, live target is refused")
    Do $$$AssertEquals(tAfter, tBefore, "and no proposal was minted for this account")
    Do $$$AssertEquals(tHttp, 400, "at 400")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "with the arguments code")
}

/// <p>The exclusion filter is load-bearing: a name in <method>ExcludedFields</method> is gone from
/// the advertised schema and from the settable list, while an unlisted sibling stays. Driven
/// through <class>OcuPilot.Test.WriteExclusion</class>, which excludes a name the shipped tool
/// leaves settable, so the two answers are compared on one tool.</p>
/// <p>Mutation: delete <code>If $ListFind(tExcluded, tName) Continue</code> from
/// <method>OcuPilot.Screen.Tool.Write.FieldRows</method> -- this goes red.</p>
Method TestAnExcludedFieldLeavesTheSchemaAndTheSettableList()
{
    Set tProbe = "OcuPilot.Test.WriteExclusion"
    Do $$$AssertTrue($ListFind($ClassMethod(..#TOOLCLASS, "SettableFields"), "Description") > 0, "Description is settable on the shipped tool")
    Do $$$AssertEquals($ClassMethod(..#TOOLCLASS, "InputSchema").%Get("properties").%GetTypeOf("Description"), "object", "and advertised in its schema")

    Do $$$AssertEquals($ListFind($ClassMethod(tProbe, "ExcludedFields"), "Description"), 1, "the probe tool excludes that one name")
    Do $$$AssertEquals($ListFind($ClassMethod(tProbe, "SettableFields"), "Description"), 0, "so it is not settable there")
    Do $$$AssertEquals($ClassMethod(tProbe, "InputSchema").%Get("properties").%GetTypeOf("Description"), "unassigned", "and not advertised there")
    Do $$$AssertTrue($ListFind($ClassMethod(tProbe, "SettableFields"), "Enabled") > 0, "while an unlisted sibling is still settable")
}

/// <p>AD-40: the model can mint and cannot apply. No path from a write tool's view reaches the
/// claim gate.</p>
Method TestNoPathFromAWriteToolsViewReachesTheClaimGate()
{
    For tClass = "OcuPilot.Screen.Tool.Write", "OcuPilot.Screen.Tool.WebAppUpdate", "OcuPilot.Kernel.Proposal.Mint", "OcuPilot.Kernel.Proposal.Fingerprint", "OcuPilot.Kernel.State.Propose" {
        Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, tClass, .tSource)
        Do $$$AssertStatusOK(tSC, tClass _ ": its source is readable")
        Do $$$AssertEquals($Find(tSource, "##class(OcuPilot.Kernel.Proposal.Write)"), 0, tClass _ ": names no call into the claim gate")
        Do $$$AssertEquals($Find(tSource, """OcuPilot.Kernel.Proposal.Write"""), 0, tClass _ ": and reaches it by no dynamic name either")
    }
}

/// <p>AD-8, DW-1208: the write's resolved set is exactly the pair set the screen's own read
/// declares -- <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>, each once -- and
/// no pair on it carries a permission no shipped role grants. The write's own pair is one the
/// screen already declares, so the set it resolves to must not carry it twice.</p>
/// <p>The "no shipped role grants it" half is asked of the vocabulary rather than of a principal:
/// <parameter>OcuPilot.Screen.Gate.ADMINRESOURCES</parameter> is required at
/// <parameter>OcuPilot.Screen.Gate.ADMINPERMISSION</parameter> throughout, so an administrative
/// resource on this set at any other permission is a requirement nothing on the instance can
/// satisfy.</p>
Method TestTheResolvedPairsAreTheScreensOwnSetEachOnce()
{
    Set tPairs = $ClassMethod(..#TOOLCLASS, "PrivilegePairs", "", .tResolved)
    Do $$$AssertEquals(tResolved, 1, "the pairs resolve")
    Set tSpelled = ""
    Kill tSeen
    For tI = 1:1:$ListLength(tPairs) {
        Set tResource = $List($List(tPairs, tI), 1)
        Set tPermission = $List($List(tPairs, tI), 2)
        Set tSpelled = tSpelled _ $Select(tI = 1: "", 1: ",") _ tResource _ ":" _ tPermission
        Set tSeen(tResource _ ":" _ tPermission) = +$Get(tSeen(tResource _ ":" _ tPermission)) + 1
        If $ListFind($ListFromString($Parameter("OcuPilot.Screen.Gate", "ADMINRESOURCES")), tResource) {
            Do $$$AssertEquals(tPermission, $Parameter("OcuPilot.Screen.Gate", "ADMINPERMISSION"), tResource _ " is required at the one permission a shipped role grants it at")
        }
    }
    Do $$$AssertEquals($ListLength(tPairs), 2, "the resolved set is exactly two pairs: " _ tSpelled)
    Do $$$AssertEquals(+$Get(tSeen("%Admin_Secure:USE")), 1, "the screen's own use pair is required once: " _ tSpelled)
    Do $$$AssertEquals(+$Get(tSeen("%DB_IRISSYS:READ")), 1, "and its database read once: " _ tSpelled)
    Do $$$AssertEquals(+$Get(tSeen("%Admin_Secure:WRITE")), 0, "and no pair asks for a write permission on an administrative resource: " _ tSpelled)
    Set tDeclared = ##class(OcuPilot.Screen.Gate).RequiredPairs($Parameter(..#TOOLCLASS, "DESCRIPTORCLASS"), .tDeclaredResolved)
    Do $$$AssertEquals(tDeclaredResolved, 1, "the screen's own declared set resolves")
    Do $$$AssertEquals(tPairs, tDeclared, "and the write's set is that set, not a superset of it")
}

/// <p>AD-3: a write tool declares which of its arguments are secret, and takes the answer from its
/// descriptor rather than from a constant.</p>
Method TestTheSecretArgumentsComeFromTheDescriptor()
{
    Set tNames = $ClassMethod(..#TOOLCLASS, "SecretArguments", "", .tDeclared)
    Do $$$AssertEquals(tDeclared, 1, "the tool declares the classification")
    Do $$$AssertEquals($ListLength(tNames), 0, "and this screen declares no secret argument")
    Do $$$AssertEquals($ListLength($ClassMethod("OcuPilot.Screen.Descriptor.WebAppList", "SecretArguments")), 0, "which is the descriptor's own answer")

    Set tProbe = $ClassMethod("OcuPilot.Screen.Tool.Read", "SecretArguments", "OcuPilot.Test.ProposalScreen", .tReadDeclared)
    Do $$$AssertEquals(tReadDeclared, 1, "a read tool declares it too")
    Do $$$AssertTrue($ListFind(tProbe, "Password") > 0, "and reads it off the descriptor rather than answering a constant")

    ; DW-1121: an abstract intermediate answers the question for every subclass below it, so the
    ; next concrete tool would inherit a classification it never made. The two intermediates
    ; therefore declare none of their own, and each concrete shell read declares its own.
    Do $$$AssertEquals(..MethodOrigin("OcuPilot.Kernel.Shell.ReadTool", "SecretArguments"), "OcuPilot.Screen.Tool.Base", "the shell read base declares no secret-argument classification of its own")
    For tClass = "OcuPilot.Kernel.Shell.InstanceRead", "OcuPilot.Kernel.Shell.NamespacesRead", "OcuPilot.Kernel.Shell.PrivilegesRead" {
        Do $$$AssertEquals(..MethodOrigin(tClass, "SecretArguments"), tClass, tClass _ ": declares its own")
    }
}

/// <p>DW-449, first leg: under a restraint the <b>real</b> verdict decides, the write branch drops
/// the call before any mint, and the verdict's own code is the tool result.</p>
/// <p>Mutation: leave <method>OcuPilot.Test.ToolDispatchProbe.ForceRestraint</method> set, or swap
/// <method>OcuPilot.Kernel.Agent.Dispatch.Restraint</method>'s two arguments -- either way this
/// goes red, because the hold below is no longer what decides.</p>
Method TestAHeldUserIsDroppedByTheRealRestraintVerdict()
{
    Do $ClassMethod(..#PROBE, "SetRegistryClass", ..#REGISTRY)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Hold($Username, "held while this test runs", .tId), "the calling account is held")

    Set tSC = ..Dispatch({"Name": (..#LIVETARGET), "Description": "probe"}, .tIsError, .tContent)
    Do $$$AssertStatusOK(tSC, "the dispatcher answers")
    Do $$$AssertEquals(tIsError, 1, "the call is an error result")
    Do $$$AssertEquals(tContent.%Get("code"), ##class(OcuPilot.Api.Error).#AGENTKILLSWITCHUSER, "carrying the verdict's own code")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Count", "restraint"), 1, "the restraint was asked exactly once")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedCountForTurn(..#PROBETURN, .tCount), "the turn's proposals are counted")
    Do $$$AssertEquals(tCount, 0, "and nothing was minted")
}

/// <p>DW-449, second leg: with nothing restraining it, the same call mints a row and the turn's
/// progress payload carries it.</p>
Method TestWithNothingRestrainingItTheCallMintsAProposal()
{
    Do $ClassMethod(..#PROBE, "SetRegistryClass", ..#REGISTRY)
    Set tSC = ..Dispatch({"Name": (..#LIVETARGET), "Description": "OcuPilot shell, renamed by a probe that never confirms"}, .tIsError, .tContent)
    Do $$$AssertStatusOK(tSC, "the dispatcher answers")
    Do $$$AssertEquals(tIsError, 0, "the call succeeded")
    Do $$$AssertNotEquals(tContent.%Get("proposalId"), "", "and the model was answered a proposal id")
    Do $$$AssertEquals(tContent.%Get("target").%Get("type"), "web-application", "against the scoped target")
    Do $$$AssertEquals(tContent.%Get("target").%Get("id"), ..#LIVETARGET, "the call named")
    Do $$$AssertTrue(tContent.%Get("unchangedCount") > 0, "reporting the properties the write still sends unchanged")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedCountForTurn(..#PROBETURN, .tCount), "the turn's proposals are counted")
    Do $$$AssertEquals(tCount, 1, "one row was minted")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(..#PROBETURN, $Username, .tRows)
    Do $$$AssertStatusOK(tSC, "and the turn's progress projection reads it")
    Do $$$AssertEquals(tRows.%Size(), 1, "carrying that one proposal")
    Do $$$AssertEquals(tRows.%Get(0).%Get("proposalId"), tContent.%Get("proposalId"), "the same one the model was told about")

    ; AD-10's other half. The tool admits no role subtree, and the fresh read's own still travels
    ; in the body the write will send (AD-4) -- a payload that dropped it would revoke this
    ; application's role at confirm, which is the grant rule running backwards.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tContent.%Get("proposalId"), .tFound, .tValues), "the stored row reads back")
    Do $$$AssertEquals(tFound, 1, "and is there")
    Set tPayload = ##class(%DynamicAbstractObject).%FromJSON($Get(tValues("payload")))
    Kill tQuery
    Set tQuery("name") = ..#LIVETARGET
    Do $$$AssertStatusOK(##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tFresh, .tFreshHttp, .tFreshFault), "the same application reads fresh through the port")
    Do $$$AssertNotEquals(tPayload.%GetTypeOf("MatchRoles"), "unassigned", "the payload still carries a MatchRoles the schema never admitted")
    If tPayload.%GetTypeOf("MatchRoles") = "unassigned" Quit
    Do $$$AssertEquals(tPayload.%Get("MatchRoles").%ToJSON(), tFresh.%Get("MatchRoles").%ToJSON(), "unchanged from the fresh read")
}

/// <p>Story 5.9, AD-3, AD-8, AD-10: the Users write tool. Its resolved set is the Users screen's
/// own two pairs, each once; it advertises <code>Enabled</code> and the one authored
/// <code>Roles</code> argument and nothing else; and every other key -- <code>EscalationRoles</code>
/// among them -- is refused under <code>additionalProperties: false</code>.</p>
/// <p>Mutations: set <parameter>OcuPilot.Screen.Tool.UserUpdate.WRITEPERMISSION</parameter> back to
/// <code>"WRITE"</code> (the pair assertions redden), drop the <code>Roles</code> property from
/// <method>OcuPilot.Screen.Tool.UserUpdate.InputSchema</method> (the advertised-fields assertions
/// redden), or remove <code>EscalationRoles</code> from
/// <method>OcuPilot.Screen.Tool.UserUpdate.ExcludedFields</method> (the exclusion assertion
/// reddens; the schema still refuses the key, because the classification calls it
/// <code>opaque</code>).</p>
Method TestTheUserWriteToolAdvertisesEnabledAndRolesWithTheScreensOwnPairs()
{
    Set tSC = $ClassMethod(..#REGISTRY, "Resolve", ..#USERTOOL, .tTool)
    Do $$$AssertStatusOK(tSC, "the registry resolves the users write tool by name")
    Do $$$AssertTrue($IsObject(tTool), "and finds it")
    If '$IsObject(tTool) Quit
    Do $$$AssertEquals(tTool.%Get("kind"), "write", "it is a write tool")
    Do $$$AssertEquals(tTool.%Get("class"), ..#USERTOOLCLASS, "answered by its own class")
    Do $$$AssertEquals($ClassMethod(..#REGISTRY, "FulfilmentOf", tTool), "instance", "fulfilled on the instance, never in the browser")

    Set tPairs = $ClassMethod(..#USERTOOLCLASS, "PrivilegePairs", "", .tResolved)
    Do $$$AssertEquals(tResolved, 1, "its pairs resolve")
    Set tSpelled = ""
    Kill tSeen
    For tI = 1:1:$ListLength(tPairs) {
        Set tResource = $List($List(tPairs, tI), 1)
        Set tPermission = $List($List(tPairs, tI), 2)
        Set tSpelled = tSpelled _ $Select(tI = 1: "", 1: ",") _ tResource _ ":" _ tPermission
        Set tSeen(tResource _ ":" _ tPermission) = +$Get(tSeen(tResource _ ":" _ tPermission)) + 1
        If $ListFind($ListFromString($Parameter("OcuPilot.Screen.Gate", "ADMINRESOURCES")), tResource) {
            Do $$$AssertEquals(tPermission, $Parameter("OcuPilot.Screen.Gate", "ADMINPERMISSION"), tResource _ " is required at the one permission a shipped role grants it at")
        }
    }
    Do $$$AssertEquals($ListLength(tPairs), 2, "the resolved set is exactly two pairs: " _ tSpelled)
    Do $$$AssertEquals(+$Get(tSeen("%Admin_Secure:USE")), 1, "the screen's own use pair is required once: " _ tSpelled)
    Do $$$AssertEquals(+$Get(tSeen("%DB_IRISSYS:READ")), 1, "and its database read once: " _ tSpelled)
    Do $$$AssertEquals(+$Get(tSeen("%Admin_Secure:WRITE")), 0, "and no pair asks for a write permission on an administrative resource: " _ tSpelled)
    Set tDeclared = ##class(OcuPilot.Screen.Gate).RequiredPairs($Parameter(..#USERTOOLCLASS, "DESCRIPTORCLASS"), .tDeclaredResolved)
    Do $$$AssertEquals(tDeclaredResolved, 1, "the screen's own declared set resolves")
    Do $$$AssertEquals(tPairs, tDeclared, "and the write's set is that set, not a superset of it")

    Set tFields = $ClassMethod(..#USERTOOLCLASS, "SettableFields")
    Do $$$AssertEquals($ListToString(tFields), "Enabled,Roles", "the settable fields are the one derived literal and the one authored array")
    Set tPermittedByTheSet = ##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedChangeFields("user")
    Do $$$AssertEquals($ListLength(tPermittedByTheSet), $ListLength(tFields), "and the kernel has reviewed exactly as many fields as the tool advertises")
    For tI = 1:1:$ListLength(tFields) {
        Do $$$AssertTrue($ListFind(tPermittedByTheSet, $List(tFields, tI)) > 0, $List(tFields, tI) _ " is a field AD-10's set has reviewed for a user")
    }

    Set tProperties = $ClassMethod(..#USERTOOLCLASS, "InputSchema").%Get("properties")
    Do $$$AssertEquals(tProperties.%Get("Enabled").%Get("type"), "boolean", "Enabled is advertised with its derived JSON type")
    Do $$$AssertEquals(tProperties.%Get("Roles").%Get("type"), "array", "Roles is advertised as an array")
    Do $$$AssertEquals(tProperties.%Get("Roles").%Get("items").%Get("type"), "string", "of role names")
    Do $$$AssertNotEquals(tProperties.%Get("Roles").%Get("description"), "", "carrying the reviewed description AD-3 requires")
    Do $$$AssertEquals(tProperties.%GetTypeOf("EscalationRoles"), "unassigned", "EscalationRoles is not advertised")
    Do $$$AssertEquals(tProperties.%GetTypeOf("FullName"), "unassigned", "and neither is an ordinary literal the set has not reviewed")
    Do $$$AssertTrue($ListFind($ClassMethod(..#USERTOOLCLASS, "ExcludedFields"), "EscalationRoles") > 0, "the tool excludes the escalation subtree by name as well")

    Set tSchema = $ClassMethod(..#USERTOOLCLASS, "InputSchema")
    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"Name": "OcuPilotProbeSchema", "EscalationRoles": ["%All"]}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "a call carrying EscalationRoles is refused")
    Do $$$AssertTrue(tProblem [ "EscalationRoles", "naming the argument: " _ tProblem)
    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"Name": "OcuPilotProbeSchema", "FullName": "renamed"}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "and so is an unreviewed ordinary literal")
    Do $$$AssertTrue(tProblem [ "FullName", "naming that argument too: " _ tProblem)
    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"Name": "OcuPilotProbeSchema", "Roles": ["%Developer"], "Enabled": true}, .tProblem)
    Do $$$AssertStatusOK(tSC, "while the two advertised fields together validate: " _ tProblem)
}

/// <p>AC1, AC4 (Story 5.10): the auditing write tool advertises its one derived field, requires its
/// screen's own pairs at <code>USE</code>, and declares its write destructive -- from the tool
/// rather than from a kernel list naming tools.</p>
/// <p>It is also the first registered write tool whose descriptor is <code>built: false</code>, so
/// the registry is asserted to list it: a tool is registered by being compiled, and a screen that
/// is not built yet is no reason for its operation to be absent.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Screen.Tool.AuditingUpdate.WRITEPERMISSION</parameter>
/// back to <code>"WRITE"</code> -- the administrative-permission assertion goes red; answer 0 from
/// <method>OcuPilot.Screen.Tool.Write.Destructive</method> -- the destructive assertion goes red.</p>
Method TestTheAuditingWriteToolAdvertisesEnabledAloneAndDeclaresItsWriteDestructive()
{
    Set tSC = $ClassMethod(..#REGISTRY, "Resolve", ..#AUDITTOOL, .tTool)
    Do $$$AssertStatusOK(tSC, "the registry resolves the auditing write tool by name")
    Do $$$AssertTrue($IsObject(tTool), "and finds it, though its screen is not built")
    If '$IsObject(tTool) Quit
    Do $$$AssertEquals(tTool.%Get("kind"), "write", "it is a write tool")
    Do $$$AssertEquals(tTool.%Get("class"), ..#AUDITTOOLCLASS, "answered by its own class")
    Do $$$AssertEquals($ClassMethod(..#REGISTRY, "FulfilmentOf", tTool), "instance", "fulfilled on the instance, never in the browser")
    Do $$$AssertEquals($ClassMethod($Parameter(..#AUDITTOOLCLASS, "DESCRIPTORCLASS"), "IsBuilt"), 0, "its descriptor is declared built: false")

    Set tPairs = $ClassMethod(..#AUDITTOOLCLASS, "PrivilegePairs", "", .tResolved)
    Do $$$AssertEquals(tResolved, 1, "its pairs resolve")
    Set tSpelled = ""
    Kill tSeen
    For tI = 1:1:$ListLength(tPairs) {
        Set tResource = $List($List(tPairs, tI), 1)
        Set tPermission = $List($List(tPairs, tI), 2)
        Set tSpelled = tSpelled _ $Select(tI = 1: "", 1: ",") _ tResource _ ":" _ tPermission
        Set tSeen(tResource _ ":" _ tPermission) = +$Get(tSeen(tResource _ ":" _ tPermission)) + 1
        If $ListFind($ListFromString($Parameter("OcuPilot.Screen.Gate", "ADMINRESOURCES")), tResource) {
            Do $$$AssertEquals(tPermission, $Parameter("OcuPilot.Screen.Gate", "ADMINPERMISSION"), tResource _ " is required at the one permission a shipped role grants it at")
        }
    }
    Do $$$AssertEquals($ListLength(tPairs), 2, "the resolved set is exactly two pairs: " _ tSpelled)
    Do $$$AssertEquals(+$Get(tSeen("%Admin_Secure:USE")), 1, "the screen's own use pair is required once: " _ tSpelled)
    Do $$$AssertEquals(+$Get(tSeen("%Admin_Secure:WRITE")), 0, "and no pair asks for a write permission on an administrative resource: " _ tSpelled)
    Set tDeclared = ##class(OcuPilot.Screen.Gate).RequiredPairs($Parameter(..#AUDITTOOLCLASS, "DESCRIPTORCLASS"), .tDeclaredResolved)
    Do $$$AssertEquals(tDeclaredResolved, 1, "the screen's own declared set resolves")
    Do $$$AssertEquals(tPairs, tDeclared, "and the write's set is that set, not a superset of it")

    Do $$$AssertEquals($ClassMethod(..#AUDITTOOLCLASS, "Destructive"), 1, "the tool declares its write destructive")
    Do $$$AssertEquals($ClassMethod(..#USERTOOLCLASS, "Destructive"), 0, "while a tool that is not says so")

    Set tFields = $ClassMethod(..#AUDITTOOLCLASS, "SettableFields")
    Do $$$AssertEquals($ListToString(tFields), "Enabled", "the one settable field is the one derived literal")
    Set tPermittedByTheSet = ##class(OcuPilot.Kernel.Proposal.Prohibited).PermittedChangeFields("auditing-configuration")
    Do $$$AssertEquals($ListToString(tPermittedByTheSet), $ListToString(tFields), "and the kernel has reviewed exactly the field the tool advertises")

    Set tSchema = $ClassMethod(..#AUDITTOOLCLASS, "InputSchema")
    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertEquals(tProperties.%Get("Enabled").%Get("type"), "boolean", "Enabled is advertised with its derived JSON type")
    Do $$$AssertEquals(tProperties.%GetTypeOf("AuditEncrypt"), "unassigned", "and no other property of the endpoint's shape is advertised")
    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"Name": "SYSTEM", "Enabled": false}, .tProblem)
    Do $$$AssertStatusOK(tSC, "the id and the flag together validate: " _ tProblem)
    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"Name": "SYSTEM", "AuditEncrypt": false}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "while an unadvertised property is refused")
    Do $$$AssertTrue(tProblem [ "AuditEncrypt", "naming the argument: " _ tProblem)
}

/// <p>The class <var>pClass</var> inherits method <var>pName</var> from, or <code>""</code>.</p>
Method MethodOrigin(pClass As %String, pName As %String) As %String
{
    Set tMethod = ##class(%Dictionary.CompiledMethod).IDKEYOpen(pClass, pName, 0)
    If '$IsObject(tMethod) Quit ""
    Quit tMethod.Origin
}

/// <p>Dispatch one <code>webapp.list.update</code> call with <var>pArgs</var> through
/// <class>OcuPilot.Test.ToolDispatchProbe</class>, inside the probe turn.
/// <var>pContent</var> is the parsed <code>tool_result</code> content.</p>
Method Dispatch(pArgs As %DynamicObject, Output pIsError As %Boolean, Output pContent As %DynamicObject) As %Status
{
    Set pIsError = 1
    Set pContent = {}
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(..#PROBETURN, ..#PROBECONV)
    Set tBlock = {}
    Do tBlock.%Set("type", "tool_use", "string")
    Do tBlock.%Set("id", "probe-use", "string")
    Do tBlock.%Set("name", $ClassMethod(..#REGISTRY, "WireName", ..#TOOL), "string")
    Do tBlock.%Set("input", pArgs)
    Set tUses = []
    Do tUses.%Push(tBlock)
    Set tSC = $ClassMethod(..#PROBE, "Answer", ..#PROBETURN, $Username, "", tUses, ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails, "")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    If $$$ISERR(tSC) Quit tSC
    Set tResult = tResults.%Get(0)
    Set pIsError = ''tResult.%Get("is_error")
    Set pContent = ##class(%DynamicAbstractObject).%FromJSON(tResult.%Get("content"))
    Quit $$$OK
}

}
