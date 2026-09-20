/// <p>The system overview the About dialog shows and the documentation address a screen's Help
/// control opens (Story 15.3, FR-73, AD-5, AD-36's shell-chrome exception, AD-44).</p>
/// <p><class>OcuPilot.Api.UiAbout</class> answers both as
/// <code>GET /api/ocupilot/ui/about</code> and <code>GET /api/ocupilot/ui/help</code>. Neither is a
/// screen, a declared read or a tool: About is opened on demand and needs twelve reads
/// <code>/instance</code> does not make, so widening the hot identity call would cost every
/// sign-in those reads.</p>
/// <p><b>Every one of the twelve <method>Members</method> is read in the calling process, each
/// behind its own <code>Try</code></b> (<method>Field</method>), so a refused or broken source
/// degrades that one member to <code>""</code>, names itself in the log and leaves the other eleven
/// answering --
/// <class>OcuPilot.Kernel.Shell.Instance</class>'s <method>ReadSource</method> seam, copied. None
/// of the twelve switches namespace (AD-16); <method>DocBookEnabled</method> is the one thing here
/// that does, by explicit save and restore.</p>
/// <p>Three of the classic page's fourteen fields are declined and say why in the story's Design
/// Notes: mirror state, cluster support and uptime all belong to Story 15.4's System Information
/// panel, which reads them from one source.</p>
Class OcuPilot.Kernel.Shell.About Extends %RegisteredObject
{

/// <p>The subsystem name a refused source is logged under.</p>
Parameter LOGSUBSYSTEM = "uiabout";

/// <p>The web application whose presence decides whether documentation is served by this instance
/// or by the web (<code>irissys/%ZEN/Portal/standardPage.cls</code>'s <method>GetDocURL</method>).</p>
Parameter DOCBOOKAPPLICATION As %String = "/csp/docbook";

/// <p>The DocBook page every help address is a <code>KEY</code> of, same-origin when this instance
/// serves it and appended to <method>DocsSiteBase</method> when it does not.</p>
Parameter DOCBOOKPAGE As %String = "/csp/docbook/DocBook.UI.PortalHelpPage.cls";

/// <p>The documentation home the links panel names, which is a different page from
/// <parameter>DOCBOOKPAGE</parameter>: that one renders the help for one <code>KEY</code> and
/// answers nothing useful without one, while this is the documentation's own front door. It is the
/// page the classic portal's links panel opens (<code>irissys/%CSP/Portal/Home.cls</code>'s
/// <method>%DrawLinks</method>).</p>
Parameter DOCBOOKHOMEPAGE As %String = "/csp/docbook/DocBook.UI.Page.cls";

/// <p>The documentation host, and the versionless path used when the instance's own version cannot
/// be read -- a real docs address rather than a broken one.</p>
Parameter DOCSSITE As %String = "https://docs.intersystems.com/";

Parameter DOCSSITEFALLBACK As %String = "irislatest";

/// <p>The two outbound destinations the classic portal's own links panel names
/// (<code>irissys/%CSP/Portal/Home.cls</code>'s <method>%DrawLinks</method>), over
/// <code>https</code> rather than the <code>http</code> it hardcodes.</p>
Parameter SUPPORTURL As %String = "https://www.intersystems.com/support/index.html";

Parameter INTERSYSTEMSURL As %String = "https://www.intersystems.com";

/// <p>The twelve members <method>Payload</method> reads through <method>Field</method>, in the
/// order the dialog lists them. A member's name is also its <method>ReadSource</method> field name,
/// so there is one vocabulary rather than two to keep aligned.</p>
ClassMethod Members() As %List
{
    Quit $ListBuild("version", "productComponents", "configuration", "databaseCacheMb", "routineCacheMb", "journalFile", "superServerPort", "webServerPort", "licenseServer", "licensedTo", "encryptionKeyId", "locale")
}

/// <p>Build the system overview, writing nothing. <var>pObject</var> carries the twelve members
/// <method>Members</method> names, <code>buildIdentity</code>, and <code>links</code> with
/// <code>documentation</code>, <code>support</code> and <code>intersystems</code>.</p>
/// <p>Every member is emitted, <code>""</code> included: a field the instance cannot report is
/// <code>""</code> on the wire and the dialog renders an empty value, which is a different thing
/// from a key the response never carried.</p>
ClassMethod Payload(Output pObject As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pObject = ""
    Try {
        Set pObject = {}
        Set tMembers = ..Members()
        For tI = 1:1:$ListLength(tMembers) {
            Set tMember = $List(tMembers, tI)
            Do pObject.%Set(tMember, ..Field(tMember), "string")
        }
        Do pObject.%Set("buildIdentity", ##class(OcuPilot.Kernel.Shell.Instance).BuildIdentity(), "string")
        Do pObject.%Set("links", ..Links())
    } Catch ex {
        Set pObject = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One raw read, behind its own <code>Try</code>. <var>pField</var> is one of
/// <method>Members</method>; a refusal reads <code>""</code> and reaches the log through
/// <method>LogSourceFailure</method> rather than failing the payload.</p>
ClassMethod Field(pField As %String) As %String
{
    Set tValue = ""
    Try {
        Set tValue = ..ReadSource(pField)
    } Catch ex {
        Set tValue = ""
        Do ..LogSourceFailure(pField, ex)
    }
    Quit tValue
}

/// <p>The twelve raw reads behind one seam; an unknown field reads <code>""</code>.</p>
/// <p>The seam exists so a test can make one source fail without touching the instance, and so
/// the per-field <code>Try</code> in <method>Field</method> has something to guard. Production
/// never overrides it. None of these switches namespace (AD-16).</p>
/// <p>Two accessors are marked <code>[ Internal ]</code> by the vendor --
/// <method>%SYS.System.GetGlobalCache</method> and <method>GetRoutineCache</method> -- and are the
/// classic About page's own calls on a class this product already reads twice. Accepted for a
/// display-only integer: the per-field <code>Try</code> turns a vendor change into one blank
/// field. <method>%Studio.General.GetWebServerPort</method> is used rather than
/// <method>%RoutineMgr.GetWebServerPort</method>, which is itself <code>[ Internal ]</code> and
/// forwards to it.</p>
ClassMethod ReadSource(pField As %String) As %String
{
    If pField = "version" Quit $ZVersion
    If pField = "productComponents" Quit $ListToString($System.Version.GetISCComponentVersionList($System.Version.GetISCProduct()), "|", 1)
    If pField = "configuration" Quit ##class(%SYS.System).GetCPFFileName()
    If pField = "databaseCacheMb" Quit ##class(%SYS.System).GetGlobalCache()
    If pField = "routineCacheMb" Quit ##class(%SYS.System).GetRoutineCache()
    If pField = "journalFile" Quit ##class(%SYS.Journal.System).GetCurrentFileName()
    If pField = "superServerPort" Quit ##class(%SQL.Manager.API).GetPort()
    If pField = "webServerPort" Quit ..WebServerPort()
    If pField = "licenseServer" Quit $SYSTEM.License.KeyServer()
    If pField = "licensedTo" Quit $SYSTEM.License.KeyCustomerName()
    If pField = "encryptionKeyId" Quit $System.Security.System.GetDBEncKeyID()
    If pField = "locale" Quit ##class(%SYS.NLS.Locale).%New().Name
    Quit ""
}

/// <p>The port the instance's own web server answers on, which
/// <method>%Studio.General.GetWebServerPort</method> reports as its first <code>Output</code>
/// argument rather than as its return value.</p>
ClassMethod WebServerPort() As %String
{
    Set tPort = ""
    Do ##class(%Studio.General).GetWebServerPort(.tPort, .tServer, .tPrefix, .tUrl)
    Quit tPort
}

/// <p>The three links panel destinations. <code>documentation</code> follows the same
/// same-origin-or-web decision every help address does, so the panel and the Help control cannot
/// disagree about where this instance's documentation is.</p>
ClassMethod Links() As %DynamicObject
{
    Set tLinks = {}
    Do tLinks.%Set("documentation", ..DocumentationHref(), "string")
    Do tLinks.%Set("support", ..#SUPPORTURL, "string")
    Do tLinks.%Set("intersystems", ..#INTERSYSTEMSURL, "string")
    Quit tLinks
}

/// <p>The documentation address of the classic page <var>pRoute</var>'s screen replaces, or
/// <code>""</code>. <var>pAvailable</var> is 1 only when an address was resolved, so a caller can
/// tell "no documentation for this screen" from an empty string it has to interpret.</p>
/// <p><b>A class name is never accepted from a caller.</b> <var>pRoute</var> resolves to a
/// descriptor, the descriptor declares the classic page's class name (AD-44), and that class's own
/// <code>HELPADDRESS</code> is the <code>KEY</code>. A screen with no classic equivalent declares
/// <code>""</code> and a classic page that publishes no <code>HELPADDRESS</code> reads
/// <code>""</code>; both answer unavailable rather than a fault.</p>
ClassMethod HelpHref(pRoute As %String, Output pAvailable As %Boolean) As %String
{
    Set pAvailable = 0
    Set tHref = ""
    Try {
        Set tDescriptor = ##class(OcuPilot.Screen.Registry).DescriptorForRoute(pRoute)
        If tDescriptor = "" Quit
        If '$ClassMethod(tDescriptor, "IsBuilt") Quit
        Set tClass = $ClassMethod(tDescriptor, "ClassicPage")
        If tClass = "" Quit
        Set tAddress = ..HelpAddress(tClass)
        If tAddress = "" Quit
        Set tHref = ..DocBookBase() _ "?KEY=" _ ##class(%CSP.Page).EscapeURL(tAddress)
        Set pAvailable = 1
    } Catch {
        Set pAvailable = 0
        Set tHref = ""
    }
    Quit tHref
}

/// <p><var>pClass</var>'s own <code>HELPADDRESS</code> parameter, or <code>""</code> when it
/// declares none or no longer exists. Overridable so a test can drive the unavailable branch
/// without a compiled class that has no address; production never overrides it.</p>
ClassMethod HelpAddress(pClass As %String) As %String
{
    Set tAddress = ""
    Try {
        Set tAddress = $Parameter(pClass, "HELPADDRESS")
    } Catch {
        Set tAddress = ""
    }
    Quit tAddress
}

/// <p>The DocBook page every documentation address is built on: the same-origin path when this
/// instance serves <parameter>DOCBOOKAPPLICATION</parameter>, and the versioned
/// <code>docs.intersystems.com</code> form when it does not.</p>
ClassMethod DocBookBase() As %String
{
    If ..DocBookEnabled() Quit ..#DOCBOOKPAGE
    Quit ..DocsSiteBase() _ ..#DOCBOOKPAGE
}

/// <p>The links panel's documentation destination: <parameter>DOCBOOKHOMEPAGE</parameter> under
/// the same same-origin-or-web decision every help address takes, so the panel and the Help
/// control cannot disagree about where this instance's documentation is.</p>
/// <p>It is <b>not</b> <method>DocBookBase</method>: that one is the per-screen help page, which
/// needs a <code>KEY</code> and renders nothing without one.</p>
ClassMethod DocumentationHref() As %String
{
    If ..DocBookEnabled() Quit ..#DOCBOOKHOMEPAGE
    Quit ..DocsSiteBase() _ ..#DOCBOOKHOMEPAGE
}

/// <p>Whether this instance serves its own copy of the documentation. Read from
/// <class>Security.Applications</class> in <code>%SYS</code> by explicit save and restore, with
/// the restore as the first line of the <code>Catch</code> (AD-16).</p>
/// <p>A refused read is <b>not</b> distinguished from an absent application: both mean this
/// instance cannot be relied on to serve the page, and the web form is correct either way.
/// Overridable so a test can drive both branches on one container; production never overrides
/// it.</p>
/// <p><b>Neither outcome is logged.</b> A caller who cannot read <code>Security.Applications</code>
/// gets the same correct answer as one who reads it and finds no application, so a refusal here is
/// an ordinary privilege outcome (AD-8) rather than a source that failed. Logging it would write
/// one error line per About read -- that is, per Home render -- into the very log OcuPilot renders
/// on its own screens, for exactly the least-privileged callers this product is for. The per-field
/// <method>LogSourceFailure</method> seam covers the twelve members named by
/// <method>Members</method>, which is what it is for.</p>
ClassMethod DocBookEnabled() As %Boolean
{
    Set tEnabled = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tEnabled = ..ReadDocBookApplication()
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tEnabled = 0
    }
    Quit tEnabled
}

/// <p>Whether <parameter>DOCBOOKAPPLICATION</parameter> exists and is enabled.</p>
/// <p><b>Caller contract: <code>$NAMESPACE</code> is already <code>%SYS</code></b> --
/// <method>DocBookEnabled</method> switches and restores around this call, and
/// <class>Security.Applications</class> exists nowhere else. Raises whatever the read raises; the
/// caller owns the degrade. Overridable so a test can drive the refused branch on a container
/// whose own privileges never refuse; production never overrides it.</p>
ClassMethod ReadDocBookApplication() As %Boolean
{
    Set tEnabled = 0
    If ##class(Security.Applications).Exists(..#DOCBOOKAPPLICATION, .tApplication, .tExistSC) {
        Set tEnabled = ''tApplication.Enabled
    }
    Set tApplication = ""
    Quit tEnabled
}

/// <p>The versioned documentation host for this build, as the classic portal derives it:
/// <code>https://docs.intersystems.com/&lt;product&gt;&lt;major&gt;&lt;minor&gt;</code>. A version
/// this instance will not report degrades to <parameter>DOCSSITEFALLBACK</parameter>, which is a
/// real docs path rather than a broken one.</p>
/// <p>Not logged, for <method>DocBookEnabled</method>'s reason: this runs on every About read and
/// every help read, so a source that stopped answering would write one error line per Home render
/// into the log OcuPilot renders on its own screens. The degrade is a working address, not a
/// failure a reader has to act on.</p>
ClassMethod DocsSiteBase() As %String
{
    Set tBase = ..#DOCSSITE _ ..#DOCSSITEFALLBACK
    Try {
        Set tBase = ..#DOCSSITE _ ..DocsSiteProduct() _ $System.Version.GetMajor() _ $System.Version.GetMinor()
    } Catch {
        Set tBase = ..#DOCSSITE _ ..#DOCSSITEFALLBACK
    }
    Quit tBase
}

/// <p>The documentation site's path segment for the installed product, the branching
/// <method>%ZEN.Portal.standardPage.GetDocURL</method> performs. Probed on this build: product 4
/// with the <code>Health</code> component reads <code>irisforhealth</code>.</p>
ClassMethod DocsSiteProduct() As %String
{
    Set tComponents = $SYSTEM.Version.GetISCComponents()
    If $System.Version.GetISCProduct() = 3 {
        If $ListFind(tComponents, "HealthConnect") Quit "healthconnect"
        Quit "hs"
    }
    If $ListFind(tComponents, "Health") Quit "irisforhealth"
    If $ListFind(tComponents, "HealthConnect") Quit "healthconnect"
    Quit "iris"
}

/// <p>The audit-log seam a refused read travels through, so a field that degraded to
/// <code>""</code> is recoverable from the log rather than silently absent from the dialog.
/// <var>pField</var> is the field that failed.</p>
/// <p>It swallows its own failure: it is called from inside a per-field <code>Catch</code>, and an
/// exception escaping here would reach <method>Payload</method>'s <code>Catch</code> and turn a
/// degraded field into the failure the per-field <code>Try</code> exists to prevent. Overridable
/// for capture in a test; production never overrides it.</p>
ClassMethod LogSourceFailure(pField As %String, pException As %Exception.AbstractException)
{
    Try {
        Do ##class(OcuPilot.Kernel.Audit.Log).Error(..#LOGSUBSYSTEM, "An About source could not be read", {"field": (pField), "detail": (pException.DisplayString())})
    } Catch {
    }
}

}
