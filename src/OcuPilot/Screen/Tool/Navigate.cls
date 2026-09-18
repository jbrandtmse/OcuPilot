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
/// <p><b>No second composite grammar</b> (AD-5). <code>entityId</code> is accepted only when the
/// target's <code>id.kind</code> is <code>single</code>; a screen whose id is <code>none</code> or
/// <code>composite</code> is openable only without one, refused <code>NAV.ENTITYNOTALLOWED</code>
/// otherwise rather than inventing a way to select a composite row.</p>
Class OcuPilot.Screen.Tool.Navigate Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "shell.screen.open";

Parameter KIND = "read";

Parameter FULFILMENT = "client";

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
/// never a URL or a filesystem path.</p>
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
/// out: <var>pRoute</var> and <var>pEntityId</var>, or <var>pFault</var> naming the refusal.
/// <var>pDescriptor</var> is ignored. <b>Caller contract:</b> <var>pArgs</var> has already passed
/// <method>InputSchema</method>'s validation, so <code>route</code> is present and, but for the
/// defensive re-check below, one of <method>BuiltRoutes</method>.</p>
/// <p>Refuses <code>NAV.ROUTEUNKNOWN</code> when <var>pArgs</var>' <code>route</code> no longer
/// resolves to a built screen -- the enum and the registry have disagreed, which the enum
/// construction at advertise time (AC1) makes rare rather than impossible between one turn's
/// advertisement and the next. Refuses <code>NAV.ENTITYNOTALLOWED</code> when <code>entityId</code>
/// is supplied against a screen whose <code>id.kind</code> is not <code>single</code> (AD-5).</p>
ClassMethod Directive(pDescriptor As %String, pArgs As %DynamicAbstractObject, Output pRoute As %String, Output pEntityId As %String, Output pFault As %DynamicObject) As %Status
{
    Set pRoute = ""
    Set pEntityId = ""
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
        If (tEntityId '= "") && ($ClassMethod(tTargetDescriptor, "IdKind") '= "single") {
            Set pFault = ..RefusalFault(##class(OcuPilot.Api.Error).#NAVENTITYNOTALLOWED)
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#NAVENTITYNOTALLOWED)
            Quit
        }
        Set pRoute = tRoute
        Set pEntityId = tEntityId
    } Catch ex {
        Set pFault = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One <code>{code}</code> fault object, the shape
/// <method>OcuPilot.Kernel.Agent.Dispatch.ResolveClientCall</method> reads.</p>
ClassMethod RefusalFault(pCode As %String) As %DynamicObject [ Private ]
{
    Set tFault = {}
    Do tFault.%Set("code", pCode, "string")
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
