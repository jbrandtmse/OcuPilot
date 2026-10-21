/// <p>The closed vocabulary of the vendor pages an <code>external</code> screen opens in a new tab, and the address of each
/// in a namespace (AD-5, AD-44, AD-47, AD-65, Story 20.32). It is keyed by the screen's tool identifier, never by its
/// <code>classicPage</code>: no URL is derived from a class name (AD-44), so each entry names its page file and the classic
/// page that file normalizes to, and <method>OcuPilot.Screen.Registry.ExternalProblem</method> holds a descriptor to both.</p>
/// <p><b>The address is the instance's.</b> <method>Href</method> composes it in four parts: the namespace's default CSP
/// application (<code>$System.CSP.GetDefaultApp</code>, given a leading and a trailing <code>/</code> exactly as
/// <code>%DeepSee.Utils.%IsDeepSeeEnabled</code> does, so the link opens the application whose flag made the area apply), the
/// vocabulary's page file, <code>?$NAMESPACE=</code> and the URL-encoded namespace. The namespace is the route's resolved
/// scope (<class>OcuPilot.Kernel.Scope</class>), already admitted by the router; no caller text enters the address, and the
/// result must pass <method>OcuPilot.Screen.Registry.ClassicHrefProblem</method> or it is empty.</p>
/// <p>The class is pure: it checks no privilege, switches no namespace and writes nothing. The screen's own gate, the area's
/// <code>applies</code> and the navigation map decide who is offered the address
/// (<method>OcuPilot.Kernel.Shell.Navigation.Payload</method>); the vendor page checks its own resources when opened.</p>
Class OcuPilot.Screen.ExternalPage Extends %RegisteredObject
{

/// <p>The tool identifiers of the vocabulary, in declaration order.</p>
ClassMethod Identifiers() As %List
{
    Quit $ListBuild("analytics.architect", "analytics.analyzer", "analytics.userportal")
}

/// <p>The vocabulary's entry for <var>pScreen</var> as <code>$ListBuild(file, classicPage)</code>, or <code>""</code> when
/// the vocabulary has none.</p>
ClassMethod Entry(pScreen As %String) As %List [ Private ]
{
    Quit $Case(pScreen,
        "analytics.architect": $ListBuild("_DeepSee.UI.Architect.zen", "%DeepSee.UI.Architect"),
        "analytics.analyzer": $ListBuild("_DeepSee.UI.Analyzer.zen", "%DeepSee.UI.Analyzer"),
        "analytics.userportal": $ListBuild("_DeepSee.UserPortal.Home.zen", "%DeepSee.UserPortal.Home"),
        : "")
}

/// <p>Whether the vocabulary names <var>pScreen</var>, a tool identifier.</p>
ClassMethod Has(pScreen As %String) As %Boolean
{
    Quit ..Entry(pScreen) '= ""
}

/// <p>The page file the vocabulary names for <var>pScreen</var>, or <code>""</code>.</p>
ClassMethod File(pScreen As %String) As %String
{
    Set tEntry = ..Entry(pScreen)
    If tEntry = "" Quit ""
    Quit $List(tEntry, 1)
}

/// <p>The classic page (a normalized class name, AD-44) the vocabulary names for <var>pScreen</var>, or <code>""</code>.</p>
ClassMethod ClassicPage(pScreen As %String) As %String
{
    Set tEntry = ..Entry(pScreen)
    If tEntry = "" Quit ""
    Quit $List(tEntry, 2)
}

/// <p>The root-relative address of <var>pScreen</var>'s page in <var>pNamespace</var>, or <code>""</code> when the vocabulary
/// has no entry, the namespace is empty, the namespace has no default application, or the composed address fails
/// <method>OcuPilot.Screen.Registry.ClassicHrefProblem</method> (AD-47).</p>
ClassMethod Href(pScreen As %String, pNamespace As %String) As %String
{
    Set tHref = ""
    Try {
        Set tFile = ..File(pScreen)
        If (tFile = "") || (pNamespace = "") Quit
        Set tApplication = $System.CSP.GetDefaultApp(pNamespace)
        If tApplication = "" Quit
        If $Extract(tApplication, 1) '= "/" Set tApplication = "/" _ tApplication
        If $Extract(tApplication, *) '= "/" Set tApplication = tApplication _ "/"
        Set tCandidate = tApplication _ tFile _ "?$NAMESPACE=" _ ##class(%CSP.Page).EscapeURL(pNamespace)
        If ##class(OcuPilot.Screen.Registry).ClassicHrefProblem(tCandidate) '= "" Quit
        Set tHref = tCandidate
    } Catch {
        Set tHref = ""
    }
    Quit tHref
}

}
