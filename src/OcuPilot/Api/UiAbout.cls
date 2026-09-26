/// <p>The handlers behind <code>GET /ui/about</code> and <code>GET /ui/help</code> (Story 15.3,
/// FR-73): the system overview the About dialog shows, and the documentation address one screen's
/// Help control opens.</p>
/// <p>Thin, per the router's <code>Call=</code> contract: the bodies are
/// <class>OcuPilot.Kernel.Shell.About</class>'s, and the responses are written by
/// <class>OcuPilot.Api.Response</class> and <class>OcuPilot.Api.Error</class> (AD-12).</p>
/// <p><b>Caller-own and ungated beyond the router</b>, like <class>OcuPilot.Api.Instance</class>.
/// Both answer the same thing to every caller who reaches them, so neither reads an identity of its
/// own -- unlike <class>OcuPilot.Api.Preferences</class>, whose rows are one account's. Neither
/// route takes a user name, a class name or a path: <code>/ui/help</code> takes a screen route,
/// validated against the screen registry's own roster before any lookup, and the classic page's
/// class name is resolved from that screen's descriptor (AD-5, AD-21).</p>
Class OcuPilot.Api.UiAbout Extends OcuPilot.Kernel.Shell.About
{

/// <p>The query parameter <code>GET /ui/help</code> takes, and the field a refusal lands on.</p>
Parameter ROUTEPARAM As %String = "route";

/// <p>Answer <code>GET /ui/about</code>: one success envelope through the one success writer, or
/// the one generic internal envelope when the body could not be built.</p>
ClassMethod HandleAbout() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..Payload(.tObject)
        If $$$ISERR(tSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSC))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tObject)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /ui/help?route=&lt;route&gt;</code>:
/// <code>{"available":true|false,"href":"..."}</code>.</p>
/// <p>A <code>route</code> that is missing, empty, longer than
/// <parameter>OcuPilot.Kernel.State.Base.ROUTEMAXLENGTH</parameter> or not a route the registry's
/// roster carries is refused 422 <parameter>OcuPilot.Api.Error.HELPROUTE</parameter> on
/// <code>route</code>, before any lookup. A screen the roster does carry but which declares no
/// classic page, or whose classic page publishes no <code>HELPADDRESS</code>, is a 200 answering
/// <code>available</code> false -- not an error: AD-44 says a screen may declare no classic
/// equivalent.</p>
ClassMethod HandleHelp() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tRoute = ..RequestedRoute()
        If '..IsRosterRoute(tRoute) {
            Set tSC = ..RenderRouteRefusal()
            Quit
        }
        Set tAvailable = 0
        Set tHref = ..HelpHref(tRoute, .tAvailable)
        Set tBody = {}
        Do tBody.%Set("available", ''tAvailable, "boolean")
        Do tBody.%Set("href", tHref, "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The <code>route</code> the request carried, or <code>""</code> when it carried none.
/// Overridable so a test can drive <method>HandleHelp</method> without an HTTP request;
/// production never overrides it.</p>
ClassMethod RequestedRoute() As %String
{
    If '$Data(%request) Quit ""
    If '$IsObject(%request) Quit ""
    Quit %request.Get(..#ROUTEPARAM, "")
}

/// <p>Whether <var>pRoute</var> is a route the screen registry's roster carries -- a built screen
/// of a declared area -- and short enough to have been stored anywhere (AD-5).</p>
/// <p>Answered by the roster, which is the one source for what screens exist, and never by
/// matching a pattern here. Home's declared route is the empty string and is refused with every
/// other empty value: Home replaces no classic page's documentation, and a caller asking for
/// "the help for no screen" has asked for nothing.</p>
ClassMethod IsRosterRoute(pRoute As %String) As %Boolean [ Private ]
{
    Set tFound = 0
    Try {
        If pRoute = "" Quit
        If $Length(pRoute) > ##class(OcuPilot.Kernel.State.Base).#ROUTEMAXLENGTH Quit
        Set tSC = ##class(OcuPilot.Screen.Registry).Roster(.tRoster)
        If $$$ISERR(tSC) Quit
        Set tAreas = tRoster.%GetIterator()
        While tAreas.%GetNext(.tAreaIndex, .tArea) {
            Set tScreens = tArea.screens.%GetIterator()
            While tScreens.%GetNext(.tScreenIndex, .tScreen) {
                If tScreen.route = pRoute Set tFound = 1
            }
        }
    } Catch {
        Set tFound = 0
    }
    Quit tFound
}

/// <p>Refuse with <b>one</b> 422 carrying a single violation on <code>route</code> under
/// <parameter>OcuPilot.Api.Error.HELPROUTE</parameter> (AD-39). The sentence is
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s, so the refusal copy is written once
/// on the server.</p>
ClassMethod RenderRouteRefusal() As %Status [ Private ]
{
    Set tCode = ##class(OcuPilot.Api.Error).#HELPROUTE
    Set tViolations = 1
    Set tViolations(1) = $ListBuild(..#ROUTEPARAM, tCode, "")
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.tViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tCode, tDetail)
}

}
