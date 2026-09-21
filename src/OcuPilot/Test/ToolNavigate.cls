/// <p>In-process suite for <class>OcuPilot.Screen.Tool.Navigate</class> (Story 4.7, AD-5, AD-11
/// rule 3): the allow-list, the schema, the two argument refusals, the privilege pairs, the
/// fulfilment declaration and its build-time enforcement. No turn, no job, no HTTP -- the wire and
/// ordering behaviors are <class>OcuPilot.Test.TurnNavigate</class>'s.</p>
/// <p>Live-safe: reads the real descriptor registry and writes nothing.</p>
Class OcuPilot.Test.ToolNavigate Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.Navigate";

/// <p>AC1: the <code>route</code> property's <code>enum</code> is exactly the set of built
/// screens' routes from <class>OcuPilot.Screen.Registry</class> -- neither more nor fewer, and no
/// URL is representable because every member is a declared route.</p>
Method TestAC1RouteEnumEqualsBuiltRoutes()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tDescriptors)
    Do $$$AssertStatusOK(tSC, "the descriptor roster reads")
    ; A %List, not a subscripted array: Home's own route is "", which a local array cannot take
    ; as a subscript.
    Set tExpected = ""
    For tI = 1:1:$ListLength(tDescriptors) {
        Set tDescriptor = $List(tDescriptors, tI)
        If ''$ClassMethod(tDescriptor, "IsBuilt") Set tExpected = tExpected _ $ListBuild($ClassMethod(tDescriptor, "Route"))
    }
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Set tEnum = tSchema.properties.route.enum
    Do $$$AssertTrue($IsObject(tEnum), "route declares an enum")
    Set tActual = ""
    Set tCount = 0
    Set tIterator = tEnum.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRoute) {
        Set tActual = tActual _ $ListBuild(tRoute)
        Set tCount = tCount + 1
    }
    For tI = 1:1:$ListLength(tExpected) {
        Set tRoute = $List(tExpected, tI)
        Do $$$AssertTrue($ListFind(tActual, tRoute) > 0, "the enum carries built route '" _ tRoute _ "'")
    }
    Do $$$AssertEquals(tCount, $ListLength(tExpected), "the enum names exactly the built routes, no more and no fewer")
    Do $$$AssertEquals(tSchema.properties.route.type, "string", "route is a string")
    Do $$$AssertEquals(tSchema.required.%Get(0), "route", "route is required")
    Do $$$AssertEquals(tSchema.additionalProperties, 0, "the schema is closed")
}

/// <p>AC1 continued: the tool's declared kind and name are what the story fixes.</p>
Method TestAC1NameAndKind()
{
    Do $$$AssertEquals($Parameter(..#TOOL, "TOOLNAME"), "shell.screen.open", "the tool's canonical name")
    Do $$$AssertEquals($Parameter(..#TOOL, "KIND"), "read", "declared read (AC9)")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Registry).WireName($Parameter(..#TOOL, "TOOLNAME")), "shell_screen_open", "the wire name a provider request advertises")
}

/// <p>AC2: an off-list route is refused by <method>OcuPilot.Screen.Tool.Registry.ValidateArguments</method>
/// before the tool body ever runs -- a caller-supplied URL is never a value the schema admits.</p>
Method TestAC2OffListRouteRefusedBySchema()
{
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Set tArgs = {"route": "/csp/sys/UtilHome.csp"}
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, tArgs, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "an off-list route is refused")
    Do $$$AssertTrue(tProblem [ "enum", "naming the enum rule: " _ tProblem)
}

/// <p>AC2: <code>entityId</code> against a screen whose <code>id.kind</code> is <code>none</code>
/// is refused <code>NAV.ENTITYNOTALLOWED</code> by <method>Directive</method>, before any
/// announcement exists -- the tool never invents a second composite grammar (AD-5).</p>
Method TestAC2EntityNotAllowedOnNoneId()
{
    Set tArgs = {"route": "agent/switches", "entityId": "x"}
    Set tSC = $ClassMethod(..#TOOL, "Directive", "", tArgs, .tRoute, .tEntityId, .tFault)
    Do $$$AssertStatusNotOK(tSC, "refused")
    Do $$$AssertTrue($IsObject(tFault), "with a fault")
    Do $$$AssertEquals(tFault.code, "NAV.ENTITYNOTALLOWED", "naming the code")
    Do $$$AssertEquals(tRoute, "", "no route is validated")
}

/// <p>AC2: the same refusal on a <code>composite</code> id (<code>logs/audit</code>).</p>
Method TestAC2EntityNotAllowedOnCompositeId()
{
    Set tArgs = {"route": "logs/audit", "entityId": "x"}
    Set tSC = $ClassMethod(..#TOOL, "Directive", "", tArgs, .tRoute, .tEntityId, .tFault)
    Do $$$AssertStatusNotOK(tSC, "refused")
    Do $$$AssertEquals(tFault.code, "NAV.ENTITYNOTALLOWED", "naming the code")
}

/// <p>A <code>single</code>-id screen (<code>permissions/users</code>) accepts an
/// <code>entityId</code>, and a <code>none</code>-id screen with no <code>entityId</code> at all
/// validates too -- the two "no error expected" rows of the I/O matrix.</p>
Method TestSingleIdAcceptsEntityAndNoneAcceptsAbsent()
{
    Set tArgs = {"route": "permissions/users", "entityId": "_SYSTEM"}
    Set tSC = $ClassMethod(..#TOOL, "Directive", "", tArgs, .tRoute, .tEntityId, .tFault)
    Do $$$AssertStatusOK(tSC, "a single-id screen accepts entityId")
    Do $$$AssertEquals(tRoute, "permissions/users", "the route is answered")
    Do $$$AssertEquals(tEntityId, "_SYSTEM", "and the entity id")
    Do $$$AssertEquals(tFault, "", "no fault")

    Set tArgs2 = {"route": "tasks/schedule"}
    Set tSC2 = $ClassMethod(..#TOOL, "Directive", "", tArgs2, .tRoute2, .tEntityId2, .tFault2)
    Do $$$AssertStatusOK(tSC2, "a screen opened with no row selected validates")
    Do $$$AssertEquals(tEntityId2, "", "no entity id")
}

/// <p>AC3 (Story 5.8), AD-21: a criterion the target descriptor declares as a <b>flag</b> is
/// accepted and travels on the directive. <code>logs/audit</code> declares exactly one --
/// <code>marker</code>, whose query parameter and value are both the descriptor's own -- and that
/// is the criterion this story's audit hand-off carries.</p>
Method TestADeclaredFlagCriterionIsAcceptedAndTravels()
{
    Do $$$AssertEquals($ListToString($ClassMethod("OcuPilot.Screen.Descriptor.AuditList", "FlagCriteria"), ","), "marker", "the audit screen declares one flag criterion")
    Set tArgs = {"route": "logs/audit", "criterion": "marker"}
    Set tSC = $ClassMethod(..#TOOL, "Directive", "", tArgs, .tRoute, .tEntityId, .tFault, .tCriterion)
    Do $$$AssertStatusOK(tSC, "the directive validates")
    Do $$$AssertEquals(tFault, "", "with no fault")
    Do $$$AssertEquals(tRoute, "logs/audit", "the route is answered")
    Do $$$AssertEquals(tCriterion, "marker", "and the criterion travels on the directive")

    Set tArgs2 = {"route": "logs/audit"}
    Set tSC2 = $ClassMethod(..#TOOL, "Directive", "", tArgs2, .tRoute2, .tEntityId2, .tFault2, .tCriterion2)
    Do $$$AssertStatusOK(tSC2, "naming no criterion validates too")
    Do $$$AssertEquals(tCriterion2, "", "and carries none")
}

/// <p>AC3 (Story 5.8), AD-21: three shapes are one refusal, <code>NAV.CRITERIONUNKNOWN</code>,
/// answered before any announcement exists -- a name the target declares nothing under, a
/// criterion <b>field</b> whose value a person types, and a name carrying a caller-supplied
/// value. The last is the one that matters most: a navigation may <b>name</b> a filter and may
/// never carry one, because no caller value reaches a read.</p>
/// <p>Mutation (Rule 19): drop the <code>$ListFind(... "FlagCriteria" ...)</code> guard from
/// <method>OcuPilot.Screen.Tool.Navigate.Directive</method> -- all three go red, and a caller's
/// own <code>eventSources</code> value would reach the audit read.</p>
Method TestAnUndeclaredOrValuedCriterionIsRefused()
{
    For tCriterion = "nosuchthing", "eventSources", "marker=OcuPilot" {
        Set tArgs = {"route": "logs/audit"}
        Do tArgs.%Set("criterion", tCriterion, "string")
        Set tSC = $ClassMethod(..#TOOL, "Directive", "", tArgs, .tRoute, .tEntityId, .tFault, .tAnswered)
        Do $$$AssertStatusNotOK(tSC, "'" _ tCriterion _ "' is refused")
        Do $$$AssertTrue($IsObject(tFault), "'" _ tCriterion _ "' is refused with a fault")
        If $IsObject(tFault) Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Api.Error).#NAVCRITERIONUNKNOWN, "'" _ tCriterion _ "' names the code")
        Do $$$AssertEquals(tRoute, "", "'" _ tCriterion _ "': no route is validated, so no announcement can exist")
        Do $$$AssertEquals($Get(tAnswered), "", "'" _ tCriterion _ "': and no criterion is answered")
    }
    ; A screen that declares no flag criterion at all refuses every name, including the one another
    ; screen declares -- the allow-list is the TARGET descriptor's, never the registry's union.
    Set tArgs = {"route": "web-applications/list", "criterion": "marker"}
    Set tSC = $ClassMethod(..#TOOL, "Directive", "", tArgs, .tRoute, .tEntityId, .tFault, .tAnswered)
    Do $$$AssertStatusNotOK(tSC, "a screen that declares no flag refuses one another screen declares")
    If $IsObject(tFault) Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Api.Error).#NAVCRITERIONUNKNOWN, "naming the code")
}

/// <p>AD-21: the schema admits <code>criterion</code> as a bounded string and closes the object,
/// so no other argument is representable at all.</p>
Method TestTheSchemaAdmitsCriterionAndNothingElse()
{
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema", "")
    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertEquals(tSchema.%Get("additionalProperties"), 0, "the object is closed")
    Do $$$AssertTrue($IsObject(tProperties.%Get("criterion")), "criterion is declared")
    Do $$$AssertEquals(tProperties.%Get("criterion").%Get("type"), "string", "as a string")
    Do $$$AssertTrue(+tProperties.%Get("criterion").%Get("maxLength") > 0, "with a bound")
    Set tCount = 0
    Set tIterator = tProperties.%GetIterator()
    While tIterator.%GetNext(.tName, .tValue) {
        Do $$$AssertTrue($ListFind($ListBuild("route", "entityId", "criterion"), tName) > 0, "the schema declares only route, entityId and criterion, not '" _ tName _ "'")
        Set tCount = tCount + 1
    }
    Do $$$AssertEquals(tCount, 3, "and all three of them")
}

/// <p>Defensive re-check: a route <code>Directive</code> cannot resolve to a built descriptor is
/// refused <code>NAV.ROUTEUNKNOWN</code> -- the disagreement case the enum construction at
/// advertise time (AC1) makes rare rather than impossible.</p>
Method TestDirectiveRefusesUnknownRoute()
{
    Set tArgs = {"route": "no/such/screen"}
    Set tSC = $ClassMethod(..#TOOL, "Directive", "", tArgs, .tRoute, .tEntityId, .tFault)
    Do $$$AssertStatusNotOK(tSC, "refused")
    Do $$$AssertEquals(tFault.code, "NAV.ROUTEUNKNOWN", "naming the code")
}

/// <p>No static privilege requirement of the tool's own: the target screen's own pairs are what
/// gate it, resolved per call in <method>ArgumentPairs</method> (AD-8).</p>
Method TestPrivilegePairsAreEmpty()
{
    Set tPairs = $ClassMethod(..#TOOL, "PrivilegePairs", "", .tResolved)
    Do $$$AssertEquals(tResolved, 1, "resolved")
    Do $$$AssertEquals($ListLength(tPairs), 0, "no static pairs")
}

/// <p>AD-8: <code>ArgumentPairs</code> answers the target descriptor's own
/// <method>OcuPilot.Screen.Gate.RequiredPairs</method> -- the same set that screen's own read tool
/// requires -- so Dispatch's step-7 check can refuse a caller the screen itself would refuse.</p>
Method TestArgumentPairsMatchTargetScreen()
{
    Set tArgs = {"route": "web-applications/list"}
    Set tPairs = $ClassMethod(..#TOOL, "ArgumentPairs", "", tArgs, .tResolved)
    Do $$$AssertEquals(tResolved, 1, "resolved")
    Set tExpected = ##class(OcuPilot.Screen.Gate).RequiredPairs("OcuPilot.Screen.Descriptor.WebAppList", .tExpectedResolved)
    Do $$$AssertEquals(tExpectedResolved, 1, "the screen's own pairs resolve")
    Do $$$AssertEquals(tPairs, tExpected, "the navigation tool requires exactly the target screen's pairs")
    Do $$$AssertTrue($ListLength(tPairs) > 0, "and that set is non-empty for this screen")
}

/// <p>AC9: the tool is client-fulfilled, so its declared <code>FULFILMENT</code> reads
/// <code>client</code> and <method>OcuPilot.Screen.Tool.Registry.FulfilmentOf</method> answers it
/// for the resolved tool entry.</p>
Method TestAC9FulfilmentIsClient()
{
    Do $$$AssertEquals($Parameter(..#TOOL, "FULFILMENT"), "client", "declared client")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("shell.screen.open", .tTool)
    Do $$$AssertStatusOK(tSC, "the tool resolves in the production registry")
    Do $$$AssertTrue($IsObject(tTool), "and is found")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Registry).FulfilmentOf(tTool), "client", "carried on the tool entry")
}

/// <p>AC9: <code>View</code> is never called in production for a client-fulfilled tool, and
/// answers <code>NAV.NOTINSTANCE</code> loudly if it ever is -- a mis-wiring fails where it
/// happened rather than serving a screen read nobody asked for.</p>
Method TestAC9ViewAnswersNotInstance()
{
    Set tSC = $ClassMethod(..#TOOL, "View", "", {"route": "tasks/schedule"}, 200, .tResult, .tHttpStatus, .tFault)
    Do $$$AssertStatusNotOK(tSC, "View refuses")
    Do $$$AssertEquals(tResult, "", "no result")
    Do $$$AssertTrue($IsObject(tFault), "with a fault")
    Do $$$AssertEquals(tFault.code, "NAV.NOTINSTANCE", "naming the mis-wiring")
}

/// <p>AC9's second half: a <code>write</code>-kind tool declaring <code>FULFILMENT = "client"</code>
/// is refused at build time (<class>OcuPilot.Test.BadFulfilment.Tool</class>), because a
/// client-fulfilled tool can never pass the write restraint path.</p>
Method TestAC9RegistryRefusesWriteClientAtBuildTime()
{
    Set tSC = ##class(OcuPilot.Test.BadFulfilment.Registry).ListTools(.tTools)
    Do $$$AssertStatusNotOK(tSC, "the registry refuses to list a write-kind client tool")
    Do $$$AssertEquals(tTools, "", "and lists nothing")
    Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ "FULFILMENT", "naming the fulfilment rule: " _ $System.Status.GetErrorText(tSC))
}

/// <p><method>OcuPilot.Screen.Tool.Registry.FulfilmentProblem</method> pinned directly: every
/// declared value, and the one combination it refuses.</p>
Method TestFulfilmentProblemVocabulary()
{
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Registry).FulfilmentProblem("X", "read", "instance"), "", "instance is sound")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.Registry).FulfilmentProblem("X", "read", "client"), "", "client on a read tool is sound")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Tool.Registry).FulfilmentProblem("X", "write", "client"), "", "client on a write tool is refused")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Tool.Registry).FulfilmentProblem("X", "read", "browser"), "", "an unlisted value is refused")
    Do $$$AssertNotEquals(##class(OcuPilot.Screen.Tool.Registry).FulfilmentProblem("X", "read", ""), "", "an empty value is refused")
}

/// <p>The tool resolves in the production registry's provider-advertised listing under its wire
/// name, with a non-empty description and a sound schema (AC1) -- <code>Dispatch.Advertise</code>'s
/// own path.</p>
Method TestAdvertisedInProduction()
{
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Advertise(.tTools)
    Do $$$AssertStatusOK(tSC, "the tool set advertises")
    Set tFound = 0
    For tI = 1:1:tTools {
        If tTools(tI, "name") = "shell_screen_open" Set tFound = 1
    }
    Do $$$AssertTrue(tFound, "shell_screen_open is advertised")
}

/// <p><b>Every <code>NAV.*</code> code carries a written sentence</b>, and an undeclared one
/// carries none -- the same assertion <class>OcuPilot.Test.Restraint</class> makes for
/// <code>RestraintCodes()</code>/<code>ReasonForRestraint()</code>, because a code with no
/// sentence behind it reaches a tool result's <code>reason</code> as a blank line.</p>
Method TestEveryNavCodeHasAWrittenSentence()
{
    Set tCodes = ##class(OcuPilot.Api.Error).NavCodes()
    Do $$$AssertEquals($ListLength(tCodes), 6, "the vocabulary holds six NAV codes; adding one is a deliberate edit in OcuPilot.Api.Error")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForNav(tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a sentence")
        Do $$$AssertTrue($Length(tReason) > 10, tCode _ "'s sentence says something: '" _ tReason _ "'")
        Do $$$AssertTrue(##class(OcuPilot.Api.Error).IsValidCode(tCode), tCode _ " is a well-formed machine code (AD-39)")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ "'s sentence is reachable through the shared ReasonForToolCode resolver")
    }
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForNav("NAV.NO.SUCH.CODE"), "", "and a code the vocabulary does not hold carries none")
}

/// <p><b>Every key the settled result emits is declared in <method>ResultSchema</method> with a
/// matching JSON type</b> (DW-1095). <method>ResultSchema</method> is documentation and shape
/// validation only -- nothing validates a client-fulfilled result at runtime -- so a declaration
/// the payload contradicts is a claim nothing checks.</p>
/// <p>The hard case is the <code>opened</code>, no-row outcome, which carries neither
/// <code>entityId</code> nor <code>code</code>: both are declared <code>"type": "string"</code>
/// and both are outside <code>required</code>, so the payload has to <b>omit</b> them rather than
/// emit JSON null.</p>
/// <p>Mutation (Rule 19): re-emit <code>%Set("code", "", "null")</code> in
/// <method>OcuPilot.Kernel.Agent.Dispatch.SettleClient</method> -- this goes red naming
/// <code>code</code>, its declared type and the null it emitted.</p>
Method TestSettledResultEmitsOnlyDeclaredKeysWithDeclaredTypes()
{
    Set tSchema = $ClassMethod(..#TOOL, "ResultSchema")
    Do $$$AssertTrue($IsObject(tSchema), "the result schema reads")
    Do $$$AssertEquals(''tSchema.additionalProperties, 0, "and admits no key it does not declare")

    ; Every outcome the settle answers, not only the interesting one, so a member that is right in
    ; one shape and wrong in another cannot hide.
    Set tCases = $ListBuild($ListBuild("opened", "", ""), $ListBuild("opened", "_SYSTEM", ""), $ListBuild("refused", "", ##class(OcuPilot.Api.Error).#NAVREFUSEDUNSAVED), $ListBuild("unavailable", "_SYSTEM", ##class(OcuPilot.Api.Error).#NAVUNAVAILABLE))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tOutcome = $List(tCase, 1)
        Set tEntity = $List(tCase, 2)
        Set tCode = $List(tCase, 3)
        Set tDetail = {}
        Do tDetail.%Set("route", "tasks/schedule", "string")
        Do tDetail.%Set("entityId", tEntity, "string")
        Do ##class(OcuPilot.Kernel.Agent.Dispatch).SettleClient(tDetail, tOutcome, tCode, .tContent)
        Set tLabel = tOutcome _ "/" _ $Select(tEntity = "": "no row", 1: "row") _ ": "
        Set tResult = ##class(%DynamicAbstractObject).%FromJSON(tContent)
        Do $$$AssertTrue($IsObject(tResult), tLabel _ "the settled content parses: " _ tContent)
        Set tIterator = tResult.%GetIterator()
        Set tSeen = 0
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tSeen = tSeen + 1
            Set tDeclared = tSchema.properties.%Get(tKey)
            Do $$$AssertTrue($IsObject(tDeclared), tLabel _ "key '" _ tKey _ "' is declared in ResultSchema")
            If '$IsObject(tDeclared) Continue
            Do $$$AssertEquals(tResult.%GetTypeOf(tKey), tDeclared.type, tLabel _ "key '" _ tKey _ "' is emitted as its declared type: " _ tContent)
        }
        ; A payload that emitted nothing would pass every row above having checked nothing.
        Do $$$AssertTrue(tSeen >= 2, tLabel _ "the payload carries at least the two required members (" _ tSeen _ ")")
        Do $$$AssertEquals(tResult.%GetTypeOf("navigated"), "boolean", tLabel _ "navigated is a boolean")
        Do $$$AssertEquals(tResult.%GetTypeOf("route"), "string", tLabel _ "route is a string")
        If tEntity = "" Do $$$AssertEquals(tResult.%IsDefined("entityId"), 0, tLabel _ "entityId is omitted, not null")
        If tOutcome = "opened" Do $$$AssertEquals(tResult.%IsDefined("code"), 0, tLabel _ "code is omitted, not null")
    }
}

/// <p>Story 5.8, AD-21: <b>exactly one built descriptor declares a flag criterion, and it is the
/// audit database viewer's <code>marker</code></b>. A roster equality, in this project's own
/// idiom, because the two halves of the criterion channel are not symmetric:
/// <method>OcuPilot.Screen.Descriptor.Base.FlagCriteria</method> <i>derives</i> a flag from any
/// well-formed <code>{param, value}</code> criteria entry on <i>any</i> descriptor, so
/// <method>OcuPilot.Screen.Tool.Navigate.Directive</method> would accept a second one and
/// <class>OcuPilot.Kernel.State.Nav</class> would carry it -- while the client's
/// <file>ui/src/app/shell/agent-navigator.ts</file> hands every arrival to one screen's store,
/// which declines anything else. A flag declared on a second screen would therefore be advertised
/// to the model, accepted, announced, and then silently applied to nothing.</p>
/// <p><b>Read this before deleting it.</b> It is not a claim that one flag is the right number: it
/// is a tripwire aimed at whichever story declares the second. The fix is to give the client a way
/// to reach that screen's store -- not to widen this assertion -- and until that exists the
/// refusal this pins is the honest answer.</p>
/// <p>Mutation (Rule 19): declare a second <code>{param, value}</code> criterion on any other
/// built descriptor's read -&gt; this goes red naming that descriptor.</p>
Method TestTheAuditScreenIsTheOnlyDeclarerOfAFlagCriterion()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tDescriptors)
    Do $$$AssertStatusOK(tSC, "the descriptor roster reads")
    Do $$$AssertTrue($ListLength(tDescriptors) > 0, "and is not empty, so this sweep asserts something")
    Set tDeclarers = ""
    For tI = 1:1:$ListLength(tDescriptors) {
        Set tDescriptor = $List(tDescriptors, tI)
        If '$ClassMethod(tDescriptor, "IsBuilt") Continue
        Set tFlags = $ClassMethod(tDescriptor, "FlagCriteria")
        If tFlags = "" Continue
        Set tDeclarers = tDeclarers _ $ListBuild(tDescriptor _ " -> " _ $ListToString(tFlags, ","))
    }
    Do $$$AssertEquals($ListToString(tDeclarers, " | "), "OcuPilot.Screen.Descriptor.AuditList -> marker", "exactly one built descriptor declares a flag criterion, and the client can reach its store")
}

}
