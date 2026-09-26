/// <p><code>shell.screen.open</code> (AD-5, AD-11 rule 3, DW-1084): the one tool by which the agent
/// moves the browser, whether opening a screen or selecting a row -- opening a screen with an id is
/// the same argument pair. Client-fulfilled (<parameter>FULFILMENT</parameter> = <code>client</code>):
/// this class validates the call and, through <method>Directive</method>, answers the allow-listed
/// <code>route</code> and optional <code>entityId</code> the browser is asked to open, but its own
/// <method>View</method> never runs on the instance -- <class>OcuPilot.Kernel.Agent.Dispatch</class>
/// calls <method>Directive</method> in place of <code>InvokeTool</code>, records a pending
/// directive, and the browser is what actually navigates.</p>
/// <p><b>The allow-list is the descriptor registry, twice</b> (AD-5). <code>route</code>'s
/// <code>enum</code> is built from every built screen's own <method>OcuPilot.Screen.Descriptor.Base.Route</method>,
/// so an off-list value is refused by <method>OcuPilot.Screen.Tool.Registry.ValidateArguments</method>
/// before this class runs at all, and no URL is ever representable -- the argument is an
/// enumeration of identifiers, never a string a caller composes. <method>Directive</method>
/// re-resolves the same route against <method>OcuPilot.Screen.Registry.DescriptorForRoute</method>
/// and refuses <code>NAV.ROUTEUNKNOWN</code> on the rare disagreement between the two: a route that
/// exists as an enum member at build time but is no longer a built screen when the call actually
/// runs.</p>
/// <p><b>No second composite grammar</b> (AD-5, DW-1419). <code>entityId</code> is accepted when
/// the target's <code>id.kind</code> is <code>single</code>, and when it is <code>composite</code>
/// over exactly <b>one</b> part -- a composite of one part occupies the same single route segment
/// a <code>single</code> id does, through the same shared encoder, so admitting it invents no
/// grammar. A screen whose id is <code>none</code>, and a composite of two or more parts, are
/// openable only without one and refused <code>NAV.ENTITYNOTALLOWED</code>.</p>
/// <p><b>Two arguments carry a search to the arriving screen</b> (AD-11, AD-21, AD-36), and neither
/// travels in the URL: <code>withQuery</code> in <file>ui/src/app/core/navigation.ts</file> carries
/// only <code>ns</code>, and both ride the directive.</p>
/// <ul>
/// <li><code>criterion</code> <b>names a flag; it never carries a value</b> (Story 5.8). It is
/// accepted only when the target descriptor declares a criterion of that name as a flag -- one whose
/// query parameter and value are both the descriptor's own
/// (<method>OcuPilot.Screen.Descriptor.Base.FlagCriteria</method>). Any other name, a criterion
/// field's name and a name carrying a value are each refused <code>NAV.CRITERIONUNKNOWN</code>.</li>
/// <li><code>criteria</code> <b>carries values</b>, keyed by the target's declared criteria fields:
/// the criteria the agent's own read of that screen applied (its answer's <code>criteria</code>).
/// Each key is checked against <method>OcuPilot.Screen.Read.CriteriaParams</method> and refused
/// <code>NAV.CRITERIONUNKNOWN</code> when the target does not declare it, or when the target is not
/// a <parameter>ARRIVALARCHETYPE</parameter> screen, the one archetype whose page runs an arrival's
/// search; each value must be a
/// string the read's own check (<method>OcuPilot.Screen.Read.SeedCriteria</method>) accepts, or it
/// is refused <code>NAV.CRITERIONINVALID</code>. Either refusal names the criterion in
/// <code>detail.criterion</code>. A value reaches the read only as that read's own criterion.</li>
/// </ul>
/// <p>Every refusal happens before any announcement exists.</p>
Class OcuPilot.Screen.Tool.Navigate Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "shell.screen.open";

Parameter KIND = "read";

Parameter FULFILMENT = "client";

/// <p>The archetype whose page takes an arrival's <code>criteria</code> in place of its default read
/// (Story 11.11). A target of any other archetype has no page that would run them, so its
/// <code>criteria</code> are refused rather than announced and ignored.</p>
Parameter ARRIVALARCHETYPE = "list (server criteria)";

Parameter DESCRIPTION = "Open a screen for the user, optionally selecting one row by its id. Announces the move before it happens, then waits about a second before the browser moves; the departing screen may refuse the move (for example, unsaved changes), and the user may always return with Back.";

/// <p>The screen registry the allow-list and the re-check are built from. Overridable for a
/// fixture; production never overrides it.</p>
ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Screen.Registry"
}

/// <p>Every built screen's declared route (AD-5), in the registry's own class-name order -- the
/// exact set <code>InputSchema</code>'s <code>enum</code> publishes and <method>Directive</method>
/// re-checks a call's <code>route</code> against.</p>
ClassMethod BuiltRoutes() As %List
{
    Set tRoutes = ""
    Try {
        Set tSC = $ClassMethod(..RegistryClass(), "Descriptors", .tDescriptors)
        If $$$ISOK(tSC) {
            For tI = 1:1:$ListLength(tDescriptors) {
                Set tDescriptor = $List(tDescriptors, tI)
                If ''$ClassMethod(tDescriptor, "IsBuilt") Set tRoutes = tRoutes _ $ListBuild($ClassMethod(tDescriptor, "Route"))
            }
        }
    } Catch {
        Set tRoutes = ""
    }
    Quit tRoutes
}

/// <p><var>pDescriptor</var> is ignored: this is a class tool of its own, not descriptor-derived.
/// <code>route</code> is required and closed to <method>BuiltRoutes</method>; <code>entityId</code>
/// is optional, at most 256 characters -- the encoded form <code>encodeEntityId</code> produces,
/// never a URL or a filesystem path. <code>criteria</code> is a bare object, because the emitted
/// schema subset admits no nested <code>properties</code>; <method>Directive</method> checks each
/// key.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {
        "type": "object",
        "properties": {
            "route": {
                "type": "string",
                "description": "The screen to open, exactly as this instance's own built screens report it. A route this instance does not build is refused."
            },
            "entityId": {
                "type": "string",
                "maxLength": 256,
                "description": "The row to select, once resolved from the row's own identifying value. Refused on a screen whose id is none or composite."
            },
            "criterion": {
                "type": "string",
                "maxLength": 64,
                "description": "The name of a filter the target screen itself declares, applied on arrival. Name it only; its value is the screen's own and is never supplied here. A name the screen does not declare is refused."
            },
            "criteria": {
                "type": "object",
                "description": "The criteria your read of that screen used (its answer's criteria), so the screen shows the same rows. Keys are the screen's own criteria and values are strings; an empty string leaves that bound unset and an omitted key takes the screen's default. Only a screen whose criteria form searches on the instance takes them. A key the screen does not declare, criteria on any other screen, or a value its read refuses, is refused."
            }
        },
        "required": ["route"],
        "additionalProperties": false
    }
    Set tEnum = []
    Set tRoutes = ..BuiltRoutes()
    For tI = 1:1:$ListLength(tRoutes) Do tEnum.%Push($List(tRoutes, tI))
    Do tSchema.properties.route.%Set("enum", tEnum)
    Quit tSchema
}

/// <p>Declared: none (AD-3). A route drawn from a closed enum and an encoded entity id are both identifiers.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p><code>{navigated, route, entityId, code}</code> -- what the browser answers once the wait
/// settles (<method>OcuPilot.Kernel.Agent.Dispatch.SettleClient</method> builds it; this schema is
/// documentation and shape validation only, since a client-fulfilled tool's result never passes
/// through this class's own <method>View</method>).</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "navigated": {"type": "boolean", "description": "Whether the browser actually moved."},
            "route": {"type": "string", "description": "The route that was requested."},
            "entityId": {"type": "string", "description": "The row that was requested, when one was."},
            "code": {"type": "string", "description": "The machine code the browser or the wait answered; present only when navigated is false."}
        },
        "required": ["navigated", "route"],
        "additionalProperties": false
    }
}

/// <p>No requirement of this tool's own: the caller's privileges are the target screen's, resolved
/// per call in <method>ArgumentPairs</method> once the route is known (AD-8). A route the caller
/// cannot open is refused there, not here.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    Quit ""
}

/// <p>The target screen's own required pairs (AD-8): <method>OcuPilot.Screen.Gate.RequiredPairs</method>
/// for the descriptor <var>pArgs</var>' <code>route</code> names, so <class>OcuPilot.Kernel.Agent.Dispatch</class>'s
/// existing step-7 check answers <code>AUTH.NOPRIVILEGE</code> against the caller's current grants
/// exactly as it would for that screen's own read tool. A route this instance does not build
/// requires nothing here -- <method>Directive</method> is what refuses it, with
/// <code>NAV.ROUTEUNKNOWN</code>, before this ever matters.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    Set tPairs = ""
    Try {
        If $IsObject(pArgs) {
            Set tTargetDescriptor = $ClassMethod(..RegistryClass(), "DescriptorForRoute", pArgs.%Get("route"))
            If tTargetDescriptor '= "" {
                Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(tTargetDescriptor, .pResolved)
            }
        }
    } Catch {
        Set tPairs = ""
        Set pResolved = 0
    }
    Quit tPairs
}

/// <p>Validate a call's <var>pArgs</var> and answer the directive the browser is asked to carry
/// out: <var>pRoute</var>, <var>pEntityId</var>, <var>pCriterion</var> and <var>pCriteria</var>
/// (an object, empty when the call carries none), or <var>pFault</var> naming the refusal.
/// <var>pDescriptor</var> is ignored. <b>Caller contract:</b> <var>pArgs</var> has already passed
/// <method>InputSchema</method>'s validation, so <code>route</code> is present and, but for the
/// defensive re-check below, one of <method>BuiltRoutes</method>.</p>
/// <p>Refuses <code>NAV.ROUTEUNKNOWN</code> when <var>pArgs</var>' <code>route</code> no longer
/// resolves to a built screen -- the enum and the registry have disagreed, which the enum
/// construction at advertise time (AC1) makes rare rather than impossible between one turn's
/// advertisement and the next. Refuses <code>NAV.ENTITYNOTALLOWED</code> when <code>entityId</code>
/// is supplied against a screen <method>AcceptsEntityId</method> refuses (AD-5),
/// <code>NAV.CRITERIONUNKNOWN</code> when <code>criterion</code> names anything but a flag
/// criterion that screen declares or a <code>criteria</code> key names no criterion it declares
/// (AD-21), and <code>NAV.CRITERIONINVALID</code> when a <code>criteria</code> value is not a
/// string or the read would refuse it (AD-11); those two carry <code>detail.criterion</code>.</p>
ClassMethod Directive(pDescriptor As %String, pArgs As %DynamicAbstractObject, Output pRoute As %String, Output pEntityId As %String, Output pFault As %DynamicObject, Output pCriterion As %String, Output pCriteria As %DynamicObject) As %Status
{
    Set pRoute = ""
    Set pEntityId = ""
    Set pCriterion = ""
    Set pCriteria = ""
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Set tArgs = $Select($IsObject(pArgs): pArgs, 1: {})
        Set tRoute = tArgs.%Get("route")
        Set tTargetDescriptor = $ClassMethod(..RegistryClass(), "DescriptorForRoute", tRoute)
        If (tTargetDescriptor = "") || '$ClassMethod(tTargetDescriptor, "IsBuilt") {
            Set pFault = ..RefusalFault(##class(OcuPilot.Api.Error).#NAVROUTEUNKNOWN)
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#NAVROUTEUNKNOWN)
            Quit
        }
        Set tEntityId = ""
        If tArgs.%IsDefined("entityId") && (tArgs.%GetTypeOf("entityId") = "string") Set tEntityId = tArgs.%Get("entityId")
        If (tEntityId '= "") && '..AcceptsEntityId(tTargetDescriptor) {
            Set pFault = ..RefusalFault(##class(OcuPilot.Api.Error).#NAVENTITYNOTALLOWED)
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#NAVENTITYNOTALLOWED)
            Quit
        }
        Set tCriterion = ""
        If tArgs.%IsDefined("criterion") && (tArgs.%GetTypeOf("criterion") = "string") Set tCriterion = tArgs.%Get("criterion")
        If (tCriterion '= "") && '$ListFind($ClassMethod(tTargetDescriptor, "FlagCriteria"), tCriterion) {
            ; One refusal for three shapes, and deliberately so: a name the screen declares nothing
            ; under, a criterion field whose value a person types, and a name carrying a value
            ; ("marker=OcuPilot") are all "this screen declares no such flag". Matching the
            ; declared name exactly is what keeps a caller's value out of a read (AD-21).
            Set pFault = ..RefusalFault(##class(OcuPilot.Api.Error).#NAVCRITERIONUNKNOWN)
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#NAVCRITERIONUNKNOWN)
            Quit
        }
        Set tCriteria = {}
        If tArgs.%GetTypeOf("criteria") = "object" {
            Set tCode = ..CriteriaRefusal(tTargetDescriptor, tArgs.%Get("criteria"), tCriteria, .tNamed)
            If tCode '= "" {
                Set pFault = ..RefusalFault(tCode, tNamed)
                Set tSC = $$$ERROR($$$GeneralError, tCode)
                Quit
            }
        }
        Set pRoute = tRoute
        Set pEntityId = tEntityId
        Set pCriterion = tCriterion
        Set pCriteria = tCriteria
    } Catch ex {
        Set pFault = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the screen <var>pDescriptor</var> declares can be opened on one row (AD-5,
/// DW-1419): its id is <code>single</code>, or <code>composite</code> over exactly one part.</p>
/// <p><b>Both refusals are kept.</b> A screen whose id is <code>none</code> has no segment for a
/// row to occupy, and a composite of two or more parts would need the agent to compose the shared
/// encoder's join -- which is the second grammar AD-5 forbids. One part needs no join at all.</p>
ClassMethod AcceptsEntityId(pDescriptor As %String) As %Boolean
{
    Set tAccepts = 0
    Try {
        Set tKind = $ClassMethod(pDescriptor, "IdKind")
        If tKind = "single" {
            Set tAccepts = 1
            Quit
        }
        If tKind '= "composite" Quit
        Set tAccepts = ($ListLength($ClassMethod(pDescriptor, "IdParts")) = 1)
    } Catch {
        Set tAccepts = 0
    }
    Quit tAccepts
}

/// <p>The refusal <var>pGiven</var>, a call's <code>criteria</code>, earns against
/// <var>pTarget</var>'s declared read, or <code>""</code> having copied every value into
/// <var>pAccepted</var>. Checked one key at a time, in the call's own order: the key against
/// <method>OcuPilot.Screen.Read.CriteriaParams</method>, which is empty for a target that is not a
/// <parameter>ARRIVALARCHETYPE</parameter> screen (<code>NAV.CRITERIONUNKNOWN</code>), then
/// the value's JSON type, then the read's own check alone on that value
/// (<code>NAV.CRITERIONINVALID</code>). <var>pNamed</var> is the refused key.</p>
ClassMethod CriteriaRefusal(pTarget As %String, pGiven As %DynamicObject, pAccepted As %DynamicObject, Output pNamed As %String) As %String [ Private ]
{
    Set pNamed = ""
    Set tCode = ""
    Set tParams = ""
    If $ClassMethod(pTarget, "Archetype") = ..#ARRIVALARCHETYPE Set tParams = ##class(OcuPilot.Screen.Read).CriteriaParams(pTarget)
    Set tRead = $ClassMethod(pTarget, "Read")
    Set tIterator = pGiven.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue, .tType) {
        If '$ListFind(tParams, tKey) {
            Set tCode = ##class(OcuPilot.Api.Error).#NAVCRITERIONUNKNOWN
        } ElseIf tType '= "string" {
            Set tCode = ##class(OcuPilot.Api.Error).#NAVCRITERIONINVALID
        } Else {
            Kill tOne, tQuery
            Set tOne(tKey) = tValue
            If ##class(OcuPilot.Screen.Read).SeedCriteria(tRead, .tOne, .tQuery) '= "" Set tCode = ##class(OcuPilot.Api.Error).#NAVCRITERIONINVALID
        }
        If tCode '= "" {
            Set pNamed = tKey
            Quit
        }
        Do pAccepted.%Set(tKey, tValue, "string")
    }
    Quit tCode
}

/// <p>One <code>{code}</code> fault object, the shape
/// <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method> reads, carrying
/// <code>detail.criterion</code> when <var>pCriterion</var> names one.</p>
ClassMethod RefusalFault(pCode As %String, pCriterion As %String = "") As %DynamicObject [ Private ]
{
    Set tFault = {}
    Do tFault.%Set("code", pCode, "string")
    If pCriterion '= "" {
        Set tDetail = {}
        Do tDetail.%Set("criterion", pCriterion, "string")
        Do tFault.%Set("detail", tDetail)
    }
    Quit tFault
}

/// <p>Never called in production: a client-fulfilled tool's body runs in the browser, and
/// <class>OcuPilot.Kernel.Agent.Dispatch</class> never invokes this. Answers
/// <code>NAV.NOTINSTANCE</code> loudly rather than serving anything, so a mis-wiring (this class's
/// own <parameter>FULFILMENT</parameter> read back as <code>instance</code>, for instance) fails
/// where it happened instead of silently answering a screen read nobody asked for.</p>
ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#NAVNOTINSTANCE, ##class(OcuPilot.Api.Error).#REASONNAVNOTINSTANCE)
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#NAVNOTINSTANCE)
}

}
