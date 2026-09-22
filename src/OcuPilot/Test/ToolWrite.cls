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

/// <p>Story 5.11's write tool and its class: the first action-style one -- no settable field, a
/// vendor request type of its own, and no body (AD-51).</p>
Parameter RESUMETOOL = "tasks.schedule.resume";

Parameter RESUMETOOLCLASS = "OcuPilot.Screen.Tool.TaskResume";

/// <p>Story 5.12's two write tools and their classes: the first pair of action-style writes over
/// one screen, and the first to declare a fingerprint subject (AD-51 as amended).</p>
Parameter SUSPENDTOOL = "osmgmt.processes.suspend";

Parameter SUSPENDTOOLCLASS = "OcuPilot.Screen.Tool.ProcessSuspend";

Parameter PROCRESUMETOOL = "osmgmt.processes.resume";

Parameter PROCRESUMETOOLCLASS = "OcuPilot.Screen.Tool.ProcessResume";

Parameter WRITEBASE = "OcuPilot.Screen.Tool.Write";

Parameter ERRORDELETETOOL = "logs.applicationerrors.delete";

Parameter ERRORDELETETOOLCLASS = "OcuPilot.Screen.Tool.ErrorDelete";

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

/// <p>AC4, AC11 (Story 5.11): the task resume tool is registered as an action-style write --
/// its <code>INFO</code> read, its <code>RESUME</code> write, no body, no settable field, not
/// destructive -- over its screen's own two pairs at <code>USE</code>, and its schema is the
/// identifying property and the agent's own words alone.</p>
/// <p>It also pins <method>OcuPilot.Screen.Tool.Write.ToolClass</method>, which is what carries a
/// concrete tool's declarations into the mint: a base that answered its own name would give every
/// action tool the merge write's read type and no state row.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Screen.Tool.TaskResume.SENDSBODY</parameter> to
/// <code>1</code> -- the bodyless assertion goes red and so does the empty settable set, because
/// the endpoint's own template would then be derived from.</p>
Method TestTheTaskResumeToolIsAnActionWriteOverTheScreensOwnPairs()
{
    Set tSC = $ClassMethod(..#REGISTRY, "Resolve", ..#RESUMETOOL, .tTool)
    Do $$$AssertStatusOK(tSC, "the registry resolves the task resume tool by name")
    Do $$$AssertTrue($IsObject(tTool), "and finds it")
    If '$IsObject(tTool) Quit
    Do $$$AssertEquals(tTool.%Get("kind"), "write", "it is a write tool")
    Do $$$AssertEquals(tTool.%Get("class"), ..#RESUMETOOLCLASS, "answered by its own class")
    Do $$$AssertEquals($ClassMethod(..#REGISTRY, "FulfilmentOf", tTool), "instance", "fulfilled on the instance, never in the browser")

    Do $$$AssertEquals($ClassMethod(..#RESUMETOOLCLASS, "ToolClass"), ..#RESUMETOOLCLASS, "the tool answers its own class, which is what the mint reads its declarations from")
    Do $$$AssertEquals($ClassMethod(..#RESUMETOOLCLASS, "ReadType"), "INFO", "its fresh read is the only request type that answers Suspended truthfully")
    Do $$$AssertEquals($ClassMethod(..#RESUMETOOLCLASS, "WriteType"), "RESUME", "its write is the vendor's own resume request type")
    Do $$$AssertEquals($ClassMethod(..#RESUMETOOLCLASS, "SendsBody"), 0, "and it sends no body")
    Do $$$AssertEquals($ClassMethod(..#RESUMETOOLCLASS, "Destructive"), 0, "a resume is not destructive: proposing the opposite undoes it")
    Do $$$AssertEquals($ClassMethod(..#RESUMETOOLCLASS, "Endpoint"), "Task.CRUD", "over the task endpoint")
    Do $$$AssertEquals($ClassMethod(..#RESUMETOOLCLASS, "IdParam"), "id", "identified by the vendor's own query parameter")
    Do $$$AssertEquals($ListLength($ClassMethod(..#RESUMETOOLCLASS, "SettableFields")), 0, "and it admits no settable field at all")
    Do $$$AssertEquals($ListToString($ClassMethod(..#RESUMETOOLCLASS, "FingerprintSubject")), "Suspended", "its fingerprint covers the one INFO field its own precondition reads (AD-51, DW-1476)")
    Do $$$AssertEquals($ClassMethod(..#RESUMETOOLCLASS, "PreconditionField"), "Suspended", "which is that precondition field")

    ; The merge writes still send one: the seam defaults to today's behavior rather than
    ; changing it, which is the half no action-tool assertion can see.
    Do $$$AssertEquals($ClassMethod(..#AUDITTOOLCLASS, "SendsBody"), 1, "while a merge write still sends its body")
    Do $$$AssertEquals($ClassMethod(..#AUDITTOOLCLASS, "WriteType"), "PUT", "as a PUT")
    Do $$$AssertEquals($ClassMethod(..#AUDITTOOLCLASS, "ReadType"), "GET", "read fresh with a GET")

    Set tPairs = $ClassMethod(..#RESUMETOOLCLASS, "PrivilegePairs", "", .tResolved)
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
    Do $$$AssertEquals(+$Get(tSeen("%Admin_Task:USE")), 1, "the screen's own use pair is required once: " _ tSpelled)
    Do $$$AssertEquals(+$Get(tSeen("%Admin_Task:WRITE")), 0, "and no pair asks for a write permission on an administrative resource: " _ tSpelled)
    Set tDeclared = ##class(OcuPilot.Screen.Gate).RequiredPairs($Parameter(..#RESUMETOOLCLASS, "DESCRIPTORCLASS"), .tDeclaredResolved)
    Do $$$AssertEquals(tDeclaredResolved, 1, "the screen's own declared set resolves")
    Do $$$AssertEquals(tPairs, tDeclared, "and the write's set is that set, not a superset of it")

    Set tSchema = $ClassMethod(..#RESUMETOOLCLASS, "InputSchema")
    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertEquals(tProperties.%Get("Id").%Get("type"), "string", "the identifying property is advertised")
    Do $$$AssertEquals(tProperties.%GetTypeOf("rationale"), "object", "with the agent's own words beside it")
    Do $$$AssertEquals(tProperties.%GetTypeOf("Suspended"), "unassigned", "and no field of the endpoint's own template is advertised")
    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"Id": "7"}, .tProblem)
    Do $$$AssertStatusOK(tSC, "the id alone validates: " _ tProblem)
    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"Id": "7", "Suspended": false}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "while a field on a bodyless write is refused")
    Do $$$AssertTrue(tProblem [ "Suspended", "naming the argument: " _ tProblem)
}

/// <p>AD-51, AD-8: the process suspend tool is an action-style write -- <code>GET</code> fresh,
/// <code>SUSPEND</code> written, no body, no settable field, not destructive -- over its screen's
/// own three pairs at <code>USE</code>, with the fingerprint subject the amended AD-51 requires.</p>
/// <p>Mutation (Rule 19): set
/// <parameter>OcuPilot.Screen.Tool.ProcessSuspend.FINGERPRINTSUBJECT</parameter> to
/// <code>"Pid"</code> -- the subject assertion goes red, and so does
/// <method>TestAnInadequateFingerprintSubjectIsRefusedAtRegistration</method>'s floor. Set
/// <parameter>OcuPilot.Screen.Tool.ProcessSuspend.DESTRUCTIVE</parameter> to <code>1</code> -- the
/// destructive assertion goes red.</p>
Method TestTheProcessSuspendToolIsAnActionWriteOverTheScreensOwnPairs()
{
    Do ..AssertActionWrite(..#SUSPENDTOOL, ..#SUSPENDTOOLCLASS, "SUSPEND", 0)
}

/// <p>AD-51, AD-8: the process resume tool, the same shape in the other direction and not
/// destructive -- proposing the suspend puts it back.</p>
/// <p>Mutation (Rule 19): set
/// <parameter>OcuPilot.Screen.Tool.ProcessResume.DESTRUCTIVE</parameter> to <code>1</code> -- the
/// destructive assertion goes red.</p>
Method TestTheProcessResumeToolIsAnActionWriteOverTheScreensOwnPairs()
{
    Do ..AssertActionWrite(..#PROCRESUMETOOL, ..#PROCRESUMETOOLCLASS, "RESUME", 0)
}

/// <p>AD-48, AD-51, AD-52: the application-error delete is an action-style write whose port is not
/// the admin port, whose fingerprint subject is the enumerated id set, and whose pair set is the
/// screen's own two pairs -- the per-namespace half is resolved by the port at call time and cannot
/// be declared on a descriptor at all.</p>
/// <p>Mutation (Rule 19): change <parameter>OcuPilot.Screen.Tool.ErrorDelete.PORTCLASS</parameter>
/// to the admin port -- the port assertion goes red here, and every mint of this tool then asks the
/// admin API for an endpoint it does not serve.</p>
Method TestTheErrorDeleteToolIsAnActionWriteOverItsOwnPort()
{
    Set tClass = ..#ERRORDELETETOOLCLASS
    Set tSC = $ClassMethod(..#REGISTRY, "Resolve", ..#ERRORDELETETOOL, .tTool)
    Do $$$AssertStatusOK(tSC, "the registry resolves the delete tool by name")
    Do $$$AssertTrue($IsObject(tTool), "and finds it")
    If '$IsObject(tTool) Quit
    Do $$$AssertEquals(tTool.%Get("kind"), "write", "it is a write tool")
    Do $$$AssertEquals(tTool.%Get("class"), tClass, "answered by its own class")
    Do $$$AssertEquals($ClassMethod(..#REGISTRY, "FulfilmentOf", tTool), "instance", "fulfilled on the instance, never in the browser")

    Do $$$AssertEquals($ClassMethod(tClass, "PortClass"), "OcuPilot.Port.LogSourcePort", "its target lives behind the log port, not the admin port")
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.Write", "PORTCLASS"), "OcuPilot.Port.AdminPort", "which is not the base's default, so the declaration is doing work")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Screen.Tool.TaskResume", "PortClass"), "OcuPilot.Port.AdminPort", "and every admin-backed write still resolves to the default")
    Do $$$AssertEquals($ClassMethod(tClass, "Endpoint"), $Parameter("OcuPilot.Port.LogSourcePort", "ENDPOINTERRORS"), "over that port's own endpoint name")
    Do $$$AssertEquals($ClassMethod(tClass, "ReadType"), "ENUMERATE", "its fresh read is the port's id enumeration")
    Do $$$AssertEquals($ClassMethod(tClass, "WriteType"), "DELETE", "and its write removes exactly those ids")
    Do $$$AssertEquals($ClassMethod(tClass, "SendsBody"), 0, "it sends no body")
    Do $$$AssertEquals($ClassMethod(tClass, "Destructive"), 1, "and it is destructive: nothing proposes a deleted error back")
    Do $$$AssertEquals($ClassMethod(tClass, "IdArgument"), "namespace", "identified by the namespace the user drilled to")
    Do $$$AssertEquals($ClassMethod(tClass, "IdParam"), "namespace", "which is the port's own query parameter")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "SettableFields")), 0, "it admits no settable field at all")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")), "namespace,entries", "its fingerprint covers the target identity and the enumerated id set")
    Do $$$AssertEquals($ClassMethod(tClass, "PreconditionField"), "entries", "which is the field its own precondition reads")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", "and the registration guard holds that subject adequate")
    ; DW-1475: the screen declares no read at all, so the guard has nothing of the screen's to
    ; validate these names against and the tool's own READANSWERS is what it reads.
    Do $$$AssertTrue('$IsObject($ClassMethod($Parameter(tClass, "DESCRIPTORCLASS"), "Read")), "the screen declares no read, which is what makes READANSWERS load-bearing")
    Do $$$AssertTrue($ListFind($ClassMethod(tClass, "ReadAnswers"), "entries") > 0, "and the tool declares the names its own read answers")

    Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
    Do $$$AssertEquals(tResolved, 1, "its pairs resolve")
    Set tDeclared = ##class(OcuPilot.Screen.Gate).RequiredPairs($Parameter(tClass, "DESCRIPTORCLASS"), .tDeclaredResolved)
    Do $$$AssertEquals(tDeclaredResolved, 1, "the screen's own declared set resolves")
    Do $$$AssertEquals(tPairs, tDeclared, "and the write's set is that set, not a superset of it")
    For tI = 1:1:$ListLength(tPairs) {
        Set tResource = $List($List(tPairs, tI), 1)
        If $ListFind($ListFromString($Parameter("OcuPilot.Screen.Gate", "ADMINRESOURCES")), tResource) {
            Do $$$AssertEquals($List($List(tPairs, tI), 2), $Parameter("OcuPilot.Screen.Gate", "ADMINPERMISSION"), tResource _ " is required at the one permission a shipped role grants it at")
        }
    }
    ; The per-namespace half: read AND write on the resource guarding that namespace's globals
    ; database, resolved at call time because ^ERRORS is unmapped (AD-48).
    Set tArgPairs = $ClassMethod(tClass, "ArgumentPairs", "", {"namespace": ($Namespace)}, .tArgResolved)
    Do $$$AssertEquals(tArgResolved, 1, "the per-namespace pairs resolve")
    Set tSpelled = ""
    For tI = 1:1:$ListLength(tArgPairs) {
        Set tSpelled = tSpelled _ $Select(tI = 1: "", 1: ",") _ $List($List(tArgPairs, tI), 1) _ ":" _ $List($List(tArgPairs, tI), 2)
    }
    Do $$$AssertTrue(tSpelled [ ":WRITE", "and carry the WRITE half this story exists for: " _ tSpelled)

    Set tSchema = $ClassMethod(tClass, "InputSchema")
    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertEquals(tProperties.%Get("namespace").%Get("type"), "string", "the identifying property is advertised")
    Do $$$AssertEquals(tProperties.%GetTypeOf("entries"), "unassigned", "and no field of the tool's own read is advertised")
    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"namespace": "HSCUSTOM"}, .tProblem)
    Do $$$AssertStatusOK(tSC, "the namespace alone validates: " _ tProblem)
    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"namespace": "HSCUSTOM", "date": "09/11/2026"}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "while a field on a bodyless write is refused")
    Do $$$AssertTrue(tProblem [ "date", "naming the argument: " _ tProblem)
}

/// <p>What both process tools declare, given the tool name <var>pName</var>, its class
/// <var>pClass</var>, the vendor request type <var>pWriteType</var> it issues and whether it is
/// <var>pDestructive</var>.</p>
Method AssertActionWrite(pName As %String, pClass As %String, pWriteType As %String, pDestructive As %Boolean)
{
    Set tSC = $ClassMethod(..#REGISTRY, "Resolve", pName, .tTool)
    Do $$$AssertStatusOK(tSC, "the registry resolves " _ pName _ " by name")
    Do $$$AssertTrue($IsObject(tTool), "and finds it")
    If '$IsObject(tTool) Quit
    Do $$$AssertEquals(tTool.%Get("kind"), "write", "it is a write tool")
    Do $$$AssertEquals(tTool.%Get("class"), pClass, "answered by its own class")
    Do $$$AssertEquals($ClassMethod(..#REGISTRY, "FulfilmentOf", tTool), "instance", "fulfilled on the instance, never in the browser")

    Do $$$AssertEquals($ClassMethod(pClass, "ReadType"), "GET", "its fresh read is the endpoint's one single-object read")
    Do $$$AssertEquals($ClassMethod(pClass, "WriteType"), pWriteType, "its write is the vendor's own request type")
    Do $$$AssertEquals($ClassMethod(pClass, "SendsBody"), 0, "and it sends no body")
    Do $$$AssertEquals($ClassMethod(pClass, "Destructive"), pDestructive, "its destructive declaration is the effect it has")
    Do $$$AssertEquals($ClassMethod(pClass, "Endpoint"), "Process", "over the process endpoint")
    Do $$$AssertEquals($ClassMethod(pClass, "IdArgument"), "Pid", "identified by the list's own id property")
    Do $$$AssertEquals($ClassMethod(pClass, "IdParam"), "id", "and by the vendor's own query parameter")
    Do $$$AssertEquals($ListLength($ClassMethod(pClass, "SettableFields")), 0, "it admits no settable field at all")
    Do $$$AssertEquals($ListToString($ClassMethod(pClass, "FingerprintSubject")), "Pid,State", "its fingerprint covers the scoped target identity and its precondition field, and nothing else")
    Do $$$AssertEquals($ClassMethod(pClass, "PreconditionField"), "State", "which is the field its own precondition reads")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(pClass), "", "and the registration guard holds that subject adequate")

    Set tPairs = $ClassMethod(pClass, "PrivilegePairs", "", .tResolved)
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
    Do $$$AssertEquals($ListLength(tPairs), 3, "the resolved set is exactly three pairs: " _ tSpelled)
    Do $$$AssertEquals(+$Get(tSeen("%Admin_Operate:USE")), 1, "the endpoint's own use pair is required once: " _ tSpelled)
    Do $$$AssertEquals(+$Get(tSeen("%Admin_Operate:WRITE")), 0, "and no pair asks for a write permission on an administrative resource: " _ tSpelled)
    Set tDeclared = ##class(OcuPilot.Screen.Gate).RequiredPairs($Parameter(pClass, "DESCRIPTORCLASS"), .tDeclaredResolved)
    Do $$$AssertEquals(tDeclaredResolved, 1, "the screen's own declared set resolves")
    Do $$$AssertEquals(tPairs, tDeclared, "and the write's set is that set, not a superset of it")

    Set tSchema = $ClassMethod(pClass, "InputSchema")
    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertEquals(tProperties.%Get("Pid").%Get("type"), "string", "the identifying property is advertised")
    Do $$$AssertEquals(tProperties.%GetTypeOf("State"), "unassigned", "and no field of the endpoint's own read is advertised")
    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"Pid": "837"}, .tProblem)
    Do $$$AssertStatusOK(tSC, "the pid alone validates: " _ tProblem)
    Set tSC = $ClassMethod(..#REGISTRY, "ValidateArguments", tSchema, {"Pid": "837", "State": "RUN"}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "while a field on a bodyless write is refused")
    Do $$$AssertTrue(tProblem [ "State", "naming the argument: " _ tProblem)
}

/// <p>AD-51's structural adequacy rule, in both directions: the shipped subjects pass and each of
/// the six ways one can be wrong is refused by name, through the same builder
/// <code>fingerprintExcludes</code> is validated by.</p>
/// <p>The six are: no subject on an action-style write, a subject that parses empty, no
/// precondition field, a name neither the screen nor the tool's own read answers, a name the
/// descriptor also excludes, and a subject declared on a write that sends a body.</p>
/// <p><b>The probes never register.</b> They sit in
/// <parameter>OcuPilot.Screen.Tool.Registry.EXCLUDEDPACKAGE</parameter>, so the guard is asked
/// about them directly rather than by making the instance's own tool list refuse to build.</p>
/// <p>Mutation (Rule 19): make
/// <method>OcuPilot.Screen.Registry.FingerprintSubjectProblem</method> answer <code>""</code>
/// unconditionally -- all five refusals go red while the floor stays green.</p>
Method TestAnInadequateFingerprintSubjectIsRefusedAtRegistration()
{
    Set tRegistry = "OcuPilot.Screen.Registry"
    Do $$$AssertEquals($ClassMethod(tRegistry, "FingerprintSubjectProblem", ..#SUSPENDTOOLCLASS), "", "the shipped suspend subject is adequate, so a guard refusing everything would not read green here")
    Do $$$AssertEquals($ClassMethod(tRegistry, "FingerprintSubjectProblem", ..#TOOLCLASS), "", "and a merge write, which declares no subject, is not asked to -- AD-6's exclusions cover the body it does send")

    ; DW-1476. An action-style write that declares none at all is refused, which is what makes the
    ; declaration compulsory for the kind rather than optional.
    Set tNoSubject = $ClassMethod(tRegistry, "FingerprintSubjectProblem", "OcuPilot.Test.SubjectProbe.NoSubject")
    Do $$$AssertNotEquals(tNoSubject, "", "an action-style write declaring no subject at all is refused")
    Do $$$AssertTrue(tNoSubject [ "FINGERPRINTSUBJECT", "naming the missing declaration: " _ tNoSubject)
    ; AD-51 as amended 2026-09-22: identity is not part of the subject, so a subject of the
    ; precondition field alone is adequate -- TargetRef answers which object this is (AD-13).
    Do $$$AssertEquals($ClassMethod(tRegistry, "FingerprintSubjectProblem", ..#RESUMETOOLCLASS), "", "a subject naming no identity is adequate, which is what makes the task resume registrable at all")
    Do $$$AssertTrue('$ListFind($ClassMethod(..#RESUMETOOLCLASS, "FingerprintSubject"), $ClassMethod(..#RESUMETOOLCLASS, "IdArgument")), "and that tool's subject really does omit its identity, so the leg above is not vacuous")

    Set tMissingPrecondition = $ClassMethod(tRegistry, "FingerprintSubjectProblem", "OcuPilot.Test.SubjectProbe.MissingPrecondition")
    Do $$$AssertNotEquals(tMissingPrecondition, "", "a tool declaring a subject and no precondition field is refused")
    Do $$$AssertTrue(tMissingPrecondition [ "PRECONDITIONFIELD", "naming the empty declaration: " _ tMissingPrecondition)

    Set tUnknown = $ClassMethod(tRegistry, "FingerprintSubjectProblem", "OcuPilot.Test.SubjectProbe.UnknownName")
    Do $$$AssertNotEquals(tUnknown, "", "a subject naming a field the screen does not declare is refused")
    Do $$$AssertTrue(tUnknown [ "Variables", "naming the field: " _ tUnknown)

    Set tEmpty = $ClassMethod(tRegistry, "FingerprintSubjectProblem", "OcuPilot.Test.SubjectProbe.EmptySubject")
    Do $$$AssertNotEquals(tEmpty, "", "a declaration that names no field at all is refused")
    Do $$$AssertTrue(tEmpty [ "FINGERPRINTSUBJECT", "naming the declaration: " _ tEmpty)

    Set tBodyTaking = $ClassMethod(tRegistry, "FingerprintSubjectProblem", "OcuPilot.Test.SubjectProbe.BodyTaking")
    Do $$$AssertNotEquals(tBodyTaking, "", "and so is a subject declared on a write that sends a body, which the inversion is not for")
    Do $$$AssertTrue(tBodyTaking [ "sends a body", "naming why: " _ tBodyTaking)

    ; DW-1474. Fingerprint.Of projects the subject and then applies the exclusions, so a name both
    ; keys carry is hashed out of the very set it is the whole of and every confirm matches. No
    ; shipped descriptor declares fingerprintExcludes, which is why this direction needs a probe
    ; descriptor that does.
    Set tExcluded = $ClassMethod(tRegistry, "FingerprintSubjectProblem", "OcuPilot.Test.SubjectProbe.ExcludedName")
    Do $$$AssertNotEquals(tExcluded, "", "a subject naming a field the descriptor also excludes is refused")
    Do $$$AssertTrue(tExcluded [ "LastModified", "naming the overlapping field: " _ tExcluded)
    Do $$$AssertTrue(tExcluded [ "fingerprintExcludes", "and the key it overlaps: " _ tExcluded)

}

/// <p>AD-51: the guard runs at registration, so a tool with an inadequate subject does not become
/// a tool at all. Reached here through <method>OcuPilot.Screen.Tool.Registry.ListTools</method>,
/// over <class>OcuPilot.Test.SubjectProbe.Registry</class>, whose discovery admits the probe
/// package the shipped registry excludes.</p>
/// <p>Mutation (Rule 19): delete the write branch's <code>FingerprintSubjectProblem</code> call
/// from <method>OcuPilot.Screen.Tool.Registry.ListTools</method> -- this leg goes red while the
/// direct one above stays green.</p>
Method TestAnInadequateFingerprintSubjectStopsTheToolListBuilding()
{
    Set tRefused = "OcuPilot.Test.SubjectProbe.BodyTaking"
    Set tProblem = $ClassMethod("OcuPilot.Screen.Registry", "FingerprintSubjectProblem", tRefused)
    Do $$$AssertNotEquals(tProblem, "", "the first probe that registry's discovery reaches is inadequate, so the run below is not a pass over nothing")
    Set tSC = $ClassMethod("OcuPilot.Test.SubjectProbe.Registry", "ListTools", .tTools)
    Do $$$AssertStatusNotOK(tSC, "a registry admitting the probe package cannot build its tool list")
    Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ (tRefused _ ": " _ tProblem), "naming the class and its problem: " _ $System.Status.GetErrorText(tSC))
}

/// <p>AD-51: every registered write tool's <method>OcuPilot.Screen.Tool.Write.WriteType</method>
/// is a <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> member, and it is a
/// <parameter>OcuPilot.Port.AdminPort.BODYLESSTYPES</parameter> member exactly when the tool
/// answers <method>OcuPilot.Screen.Tool.Write.SendsBody</method> 0.</p>
/// <p><b>Why the equality is pinned rather than derived.</b> "This write sends no body" is
/// declared twice -- once by the tool, once by the port, which learns it from the vendor's own
/// <code>NeedsRequestBody()</code>. Neither can be computed from the other: the port's list is a
/// fact about the vendor and the tool's is a choice about one operation. Disagreeing is silent in
/// both directions -- a tool that sends no body over a type the port still requires one for is
/// refused 500 at the write, and one that sends a body the vendor never reads issues a payload
/// nobody reviewed. Stories 5.12 and 5.13 each add an action write, so the roster is what keeps
/// the two halves arriving together.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Port.AdminPort.BODYLESSTYPES</parameter>, drop
/// its <code>Process/SUSPEND</code> entry, or set
/// <parameter>OcuPilot.Screen.Tool.TaskResume.SENDSBODY</parameter> to 1 -- the equality goes red
/// naming the tool and its request type. Add <code>TERMINATE</code> to
/// <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> -- the absence leg goes red.</p>
Method TestEveryWriteToolsRequestTypeAgreesWithThePortsBodylessRoster()
{
    Set tMutating = $ListFromString($Parameter("OcuPilot.Port.AdminPort", "MUTATINGTYPES"))
    Set tBodyless = $ListFromString($Parameter("OcuPilot.Port.AdminPort", "BODYLESSTYPES"))
    Do $$$AssertTrue($ListLength(tBodyless) > 0, "the port names at least one bodyless request type; a run over none would pass having checked nothing")
    Set tEndpoints = ""
    For tI = 1:1:$ListLength(tBodyless) {
        Set tEntry = $List(tBodyless, tI)
        Do $$$AssertEquals($Length(tEntry, "/"), 2, "'" _ tEntry _ "' is an <endpoint>/<type> pair, not a bare suffix (DW-1464)")
        Set tType = $Piece(tEntry, "/", 2)
        Do $$$AssertTrue($ListFind(tMutating, tType) > 0, "'" _ tEntry _ "' is exempted from the object-body refusal, so its type is a mutating one the refusal would otherwise reach")
        If '$ListFind(tEndpoints, $Piece(tEntry, "/", 1)) Set tEndpoints = tEndpoints _ $ListBuild($Piece(tEntry, "/", 1))
    }
    ; DW-1464's own condition: the exemption keys on the pair because one suffix serves two
    ; endpoints on this build, so a bare-suffix roster would carry one endpoint's
    ; NeedsRequestBody() answer onto the other's.
    Do $$$AssertTrue($ListLength(tEndpoints) > 1, "more than one endpoint declares a bodyless request type, which is what makes the pair key load-bearing: " _ $ListToString(tEndpoints))
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsBodyless("Process", "RESUME"), "Process/RESUME is exempt")
    Do $$$AssertTrue('##class(OcuPilot.Port.AdminPort).IsBodyless("Task.CRUD", "SUSPEND"), "while Task.CRUD/SUSPEND, which no endpoint pairs, is not")

    Set tSC = $ClassMethod(..#REGISTRY, "ListTools", .tTools)
    Do $$$AssertStatusOK(tSC, "the tool registry lists: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tWrites = 0
    Set tActions = 0
    Set tOtherPorts = 0
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry.%Get("kind") '= "write" Continue
        ; AD-52: the roster below is a fact about the ADMIN API's own request types, read from
        ; that port's two parameters. A tool whose target lives behind another port issues that
        ; port's request types and the admin port answers 501 for them by construction, so holding
        ; it to this roster would assert the wrong instance's contract. Counted, so a change that
        ; routed every write off the admin port could not empty this loop silently.
        If $ClassMethod(tEntry.%Get("class"), "PortClass") '= "OcuPilot.Port.AdminPort" {
            Set tOtherPorts = tOtherPorts + 1
            Continue
        }
        Set tWrites = tWrites + 1
        Set tName = tEntry.%Get("name")
        Set tClass = tEntry.%Get("class")
        Set tType = $ClassMethod(tClass, "WriteType")
        Set tSends = ''$ClassMethod(tClass, "SendsBody")
        Do $$$AssertTrue($ListFind(tMutating, tType) > 0, tName _ " writes with '" _ tType _ "', which the port declares a mutating type")
        Set tExempt = ''##class(OcuPilot.Port.AdminPort).IsBodyless($ClassMethod(tClass, "Endpoint"), tType)
        Do $$$AssertEquals(tExempt, 'tSends, tName _ " sends " _ $Select(tSends: "a body", 1: "none") _ ", so '" _ tType _ "' is " _ $Select(tSends: "absent from", 1: "in") _ " the port's bodyless roster")
        If 'tSends Set tActions = tActions + 1
    }
    Do $$$AssertTrue(tWrites > 0, "the registry enumerated admin-port write tools at all")
    Do $$$AssertTrue(tActions > 0, "and at least one of them is an action-style write, so the bodyless half of the equality was exercised")
    Do $$$AssertEquals(tOtherPorts, 1, "exactly one shipped write reaches its target through another port, and it is held to that port's contract instead")

    ; AD-10, Story 5.12's AC3: the vendor exposes terminating a process twice -- TYPETERMINATE and
    ; RunDelete delegating to it -- so "never advertised" is a statement about OcuPilot. Neither
    ; suffix is a mutating type, so the port answers 501 for it without reaching the endpoint.
    For tAbsent = "TERMINATE", "DELETE" {
        Do $$$AssertEquals($ListFind(tMutating, tAbsent), 0, "'" _ tAbsent _ "' is not a request type this port admits")
        Kill tQuery
        ; A pid no process carries. The 501 lands before the id is read, so an absent one proves the
        ; same refusal -- and the mutation this method's doc names (admitting TERMINATE) then reaches
        ; the vendor against nothing, rather than against the process running this test.
        Set tQuery("id") = 999999999
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Process", tAbsent, .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, "and the port refuses a Process " _ tAbsent _ " outright")
        Do $$$AssertEquals(+$Get(tHttp), 501, "at 501, before the vendor endpoint is entered")
    }
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
