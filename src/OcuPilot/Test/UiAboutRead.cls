/// <p>The About payload and the help-address resolution (Story 15.3): every member present, one
/// refused source degrading that member alone, the two branches of the documentation base, and
/// <method>OcuPilot.Kernel.Shell.About.HelpHref</method>'s three answers.</p>
/// <p>Needs an installed instance whose screen descriptors are compiled; it reads them and writes
/// nothing. The routes it exercises are resolved from their descriptor classes rather than
/// spelled, because a descriptor's class name is the stable identity and its route is not
/// (AD-5).</p>
/// <p>Two branches are unreachable on this image without a seam, and
/// <class>OcuPilot.Test.UiAboutFixture</class> is that seam: the pinned container ships no
/// <code>/csp/docbook</code> application at all, so the same-origin documentation base cannot be
/// observed from the instance's own state, and no source refuses on a healthy instance.</p>
Class OcuPilot.Test.UiAboutRead Extends %UnitTest.TestCase
{

/// <p>The thirteen scalar members the payload carries, spelled here rather than read from
/// <method>OcuPilot.Kernel.Shell.About.Members</method>: the wire contract is what this pins, and
/// deriving the expectation from the code under test would assert it against itself.</p>
Parameter WIREMEMBERS As %String = "version,productComponents,configuration,databaseCacheMb,routineCacheMb,journalFile,superServerPort,webServerPort,licenseServer,licensedTo,encryptionKeyId,locale,buildIdentity";

/// <p>The same-origin per-screen help page, when this instance serves its own copy. Every help
/// address is a <code>KEY</code> of it.</p>
Parameter LOCALDOCBASE As %String = "/csp/docbook/DocBook.UI.PortalHelpPage.cls";

/// <p>The documentation home the links panel names, which is a different page: the one above
/// renders the help for one <code>KEY</code> and shows nothing without one.</p>
Parameter LOCALDOCHOME As %String = "/csp/docbook/DocBook.UI.Page.cls";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.UiAboutFixture).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.UiAboutFixture).Clear()
    Quit $$$OK
}

/// <p><b>Every member is on the payload</b>, and <code>links</code> carries its three
/// destinations. A member the instance could not report is <code>""</code>, never an absent
/// key.</p>
/// <p>Mutation: drop the <code>journalFile</code> assignment from
/// <method>OcuPilot.Kernel.Shell.About.Payload</method> -- by removing
/// <code>journalFile</code> from <method>Members</method> -- and this goes red naming the member,
/// as does <class>OcuPilot.Test.UiAboutWire</class> over the wire.</p>
Method TestThePayloadCarriesEveryMemberAndTheThreeLinks()
{
    Set tSC = ##class(OcuPilot.Kernel.Shell.About).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertTrue($IsObject(tObject), "and is an object")
    If '$IsObject(tObject) Quit
    For tI = 1:1:$Length(..#WIREMEMBERS, ",") {
        Set tMember = $Piece(..#WIREMEMBERS, ",", tI)
        Do $$$AssertTrue(tObject.%IsDefined(tMember), "the payload carries " _ tMember)
        Do $$$AssertEquals(tObject.%GetTypeOf(tMember), "string", tMember _ " travels as a string")
    }
    Do $$$AssertEquals(tObject.%GetTypeOf("links"), "object", "and links is an object")
    Do $$$AssertTrue(tObject.links.%IsDefined("documentation"), "carrying documentation")
    Do $$$AssertTrue(tObject.links.%IsDefined("support"), "support")
    Do $$$AssertTrue(tObject.links.%IsDefined("intersystems"), "and intersystems")
}

/// <p><b>The values are the instance's own</b>, asserted through the same calls the reader makes
/// rather than against literals this container happens to answer -- all thirteen, because a member
/// pinned only by key presence ships whatever the wrong accessor returned.</p>
/// <p>Mutation: swap the <code>superServerPort</code> and <code>webServerPort</code> arms of
/// <method>OcuPilot.Kernel.Shell.About.ReadSource</method> -- both members are still defined and
/// still travel as strings, so a presence-only pin stays green; this goes red on both.</p>
Method TestTheCarriedValuesAreTheInstancesOwn()
{
    Set tSC = ##class(OcuPilot.Kernel.Shell.About).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    If '$IsObject(tObject) Quit
    Do $$$AssertEquals(tObject.version, $ZVersion, "the version banner travels verbatim")
    Do $$$AssertEquals(tObject.configuration, ##class(%SYS.System).GetCPFFileName(), "as does the configuration file path")
    Do $$$AssertEquals(tObject.journalFile, ##class(%SYS.Journal.System).GetCurrentFileName(), "and the current journal file")
    Do $$$AssertEquals(tObject.licensedTo, $SYSTEM.License.KeyCustomerName(), "and the licensee")
    Do $$$AssertEquals(tObject.buildIdentity, ##class(OcuPilot.Kernel.Shell.Instance).BuildIdentity(), "and the build stamp is the version row's own value")
    Do $$$AssertEquals(tObject.productComponents, $ListToString($System.Version.GetISCComponentVersionList($System.Version.GetISCProduct()), "|", 1), "the component list")
    Do $$$AssertEquals(tObject.databaseCacheMb, ##class(%SYS.System).GetGlobalCache(), "the global buffer size")
    Do $$$AssertEquals(tObject.routineCacheMb, ##class(%SYS.System).GetRoutineCache(), "the routine buffer size")
    Do $$$AssertEquals(tObject.licenseServer, $SYSTEM.License.KeyServer(), "the license server")
    Do $$$AssertEquals(tObject.encryptionKeyId, $System.Security.System.GetDBEncKeyID(), "the database encryption key id")
    Do $$$AssertEquals(tObject.locale, ##class(%SYS.NLS.Locale).%New().Name, "and the locale")

    ; The two ports are the pair a reader cannot tell apart by shape, and their accessors differ in
    ; kind -- one returns the port, the other reports it as an Output argument -- so a swap between
    ; them is the mistake this asserts against. Every other member above is pinned to its own
    ; documented accessor for the same reason.
    Set tWebPort = ""
    Do ##class(%Studio.General).GetWebServerPort(.tWebPort, .tServer, .tPrefix, .tUrl)
    Do $$$AssertEquals(tObject.superServerPort, ##class(%SQL.Manager.API).GetPort(), "the superserver port is the superserver's")
    Do $$$AssertEquals(tObject.webServerPort, tWebPort, "and the web server port is the web server's")
    Do $$$AssertNotEquals(tObject.superServerPort, tObject.webServerPort, "the two ports are different values, so a swap between them is observable")
}

/// <p><b>One refused source degrades that member alone</b> and names itself in the log; the other
/// twelve answer and the payload's status is still OK.</p>
/// <p>Mutation: remove the per-field <code>Try</code> from
/// <method>OcuPilot.Kernel.Shell.About.Field</method> -- the payload's status goes to an error and
/// every assertion below reddens.</p>
Method TestARefusedSourceDegradesThatMemberAloneAndIsLogged()
{
    Do ##class(OcuPilot.Test.UiAboutFixture).SetSourceThrows("journalFile")
    Set tSC = ##class(OcuPilot.Test.UiAboutFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "a refused source is not a failed payload")
    Do $$$AssertTrue($IsObject(tObject), "which is still built")
    If '$IsObject(tObject) Quit
    Do $$$AssertEquals(tObject.journalFile, "", "the refused member degrades to the empty string")
    Do $$$AssertTrue(tObject.%IsDefined("journalFile"), "and is still a key on the wire")
    Do $$$AssertNotEquals(tObject.version, "", "while the version still answers")
    Do $$$AssertNotEquals(tObject.configuration, "", "and so does the configuration")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiAboutFixture).SourceLogCalls(), 1, "the refusal reached the log exactly once")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiAboutFixture).SourceLogged(), "journalFile", "naming the member that failed")
}

/// <p><b>A healthy read logs nothing.</b> Without this the assertion above would pass on a reader
/// that logged on every field.</p>
Method TestAHealthyReadLogsNothing()
{
    Set tSC = ##class(OcuPilot.Test.UiAboutFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiAboutFixture).SourceLogCalls(), 0, "and no source failure was logged")
}

/// <p><b>The documentation base has two branches and takes the right one.</b> With the
/// application present every address is same-origin; without it, the versioned
/// <code>docs.intersystems.com</code> form. Both the links panel's <code>documentation</code> and
/// a help address are built on it, so the two cannot disagree.</p>
Method TestTheDocumentationBaseFollowsWhetherThisInstanceServesIt()
{
    Do ##class(OcuPilot.Test.UiAboutFixture).SetDocBookEnabled(1)
    Set tLocal = ##class(OcuPilot.Test.UiAboutFixture).DocBookBase()
    Do $$$AssertEquals(tLocal, ..#LOCALDOCBASE, "an instance serving its own documentation answers the same-origin page")
    Do $$$AssertTrue($Extract(tLocal, 1) = "/", "which is root-relative, so nothing off-origin is named")

    Do ##class(OcuPilot.Test.UiAboutFixture).SetDocBookEnabled(0)
    Set tRemote = ##class(OcuPilot.Test.UiAboutFixture).DocBookBase()
    Set tWanted = ##class(OcuPilot.Test.UiAboutFixture).DocsSiteBase() _ ..#LOCALDOCBASE
    Do $$$AssertEquals(tRemote, tWanted, "and one that does not answers the versioned documentation site")
    Do $$$AssertTrue(tRemote [ "https://docs.intersystems.com/", "over https: " _ tRemote)
    Do $$$AssertTrue(tRemote [ ($System.Version.GetMajor() _ $System.Version.GetMinor()), "carrying this build's own version: " _ tRemote)
}

/// <p><b>This container's real answer is the degraded one</b>, because the pinned image ships no
/// <code>/csp/docbook</code> application. Asserted so the fixture above cannot be the only
/// evidence that the branch is taken.</p>
Method TestThisImageServesNoDocumentationOfItsOwn()
{
    Do $$$AssertTrue('##class(OcuPilot.Kernel.Shell.About).DocBookEnabled(), "the pinned image declares no /csp/docbook application")
    Set tLinks = ##class(OcuPilot.Kernel.Shell.About).Links()
    Do $$$AssertEquals(tLinks.documentation, ##class(OcuPilot.Kernel.Shell.About).DocsSiteBase() _ ..#LOCALDOCHOME, "so the links panel names the documentation site")
    Do $$$AssertTrue(tLinks.documentation '[ "PortalHelpPage", "and names the documentation home, not the per-screen help page, which shows nothing without a KEY: " _ tLinks.documentation)
}

/// <p><b>A refused DocBook check degrades to the documentation site and writes no log line.</b>
/// A caller who cannot read <class>Security.Applications</class> gets the same correct answer as
/// one who reads it and finds no application, so the refusal is an ordinary privilege outcome
/// (AD-8), not a source that failed.</p>
/// <p>Mutation: log the refusal from
/// <method>OcuPilot.Kernel.Shell.About.DocBookEnabled</method>'s <code>Catch</code> -- the second
/// and fourth assertions go red. Measured: one such line per About read, which is one per Home
/// render, into the log OcuPilot renders on its own screens.</p>
Method TestARefusedDocBookCheckDegradesWithoutLogging()
{
    Do ##class(OcuPilot.Test.UiAboutFixture).SetDocBookThrows()
    Set tBase = ##class(OcuPilot.Test.UiAboutFixture).DocBookBase()
    Set tWanted = ##class(OcuPilot.Test.UiAboutFixture).DocsSiteBase() _ ..#LOCALDOCBASE
    Do $$$AssertEquals(tBase, tWanted, "a refused check answers the versioned documentation site")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiAboutFixture).SourceLogCalls(), 0, "and writes no log line")

    Set tSC = ##class(OcuPilot.Test.UiAboutFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "a whole read still builds its payload")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiAboutFixture).SourceLogCalls(), 0, "and logs nothing at all")
    Do $$$AssertEquals(tObject.links.documentation, ##class(OcuPilot.Test.UiAboutFixture).DocsSiteBase() _ ..#LOCALDOCHOME, "with the links panel naming the same degraded host")
}

/// <p><b>A screen whose classic page publishes a <code>HELPADDRESS</code></b> resolves to that
/// address, percent-encoded as the DocBook <code>KEY</code>.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Shell.About.HelpHref</method> answer
/// <var>pAvailable</var> 0 for such a route -- this goes red, and so does
/// <file>ui/src/app/shell/locator-bar.spec.ts</file>'s Help-control row.</p>
Method TestAScreenWithAClassicHelpAddressResolvesIt()
{
    Set tRoute = ##class(OcuPilot.Screen.Descriptor.UserList).Route()
    Set tClass = ##class(OcuPilot.Screen.Descriptor.UserList).ClassicPage()
    Do $$$AssertNotEquals(tClass, "", "the Users list declares a classic page")
    Set tAddress = ##class(OcuPilot.Kernel.Shell.About).HelpAddress(tClass)
    Do $$$AssertNotEquals(tAddress, "", "whose class publishes a HELPADDRESS")

    Set tAvailable = 0
    Set tHref = ##class(OcuPilot.Kernel.Shell.About).HelpHref(tRoute, .tAvailable)
    Do $$$AssertEquals(''tAvailable, 1, "so the help address is available")
    Do $$$AssertEquals(tHref, ##class(OcuPilot.Kernel.Shell.About).DocBookBase() _ "?KEY=" _ ##class(%CSP.Page).EscapeURL(tAddress), "and is the classic page's own address as the KEY")
    Do $$$AssertTrue(tHref '[ " ", "percent-encoded, so no raw space reaches the URL: " _ tHref)
}

/// <p><b>A screen with no classic equivalent</b> answers unavailable and an empty address, which
/// AD-44 makes a declaration rather than an error.</p>
Method TestAScreenWithNoClassicPageIsUnavailable()
{
    Set tRoute = ##class(OcuPilot.Screen.Descriptor.AgentDefinitionList).Route()
    Do $$$AssertEquals(##class(OcuPilot.Screen.Descriptor.AgentDefinitionList).ClassicPage(), "", "the Definitions list declares no classic page")
    Set tAvailable = 1
    Set tHref = ##class(OcuPilot.Kernel.Shell.About).HelpHref(tRoute, .tAvailable)
    Do $$$AssertEquals(''tAvailable, 0, "so no help address is available")
    Do $$$AssertEquals(tHref, "", "and none is answered")
}

/// <p><b>A classic page that publishes no <code>HELPADDRESS</code></b> answers unavailable too.
/// Driven twice: once against the shipped alerts.log viewer, whose classic page is a CSP page with
/// no address, and once with the address armed empty on a class that does have one -- so the
/// assertion cannot pass merely because that one screen's own declaration changed.</p>
Method TestAClassicPageWithNoHelpAddressIsUnavailable()
{
    Set tRoute = ##class(OcuPilot.Screen.Descriptor.LogAlertViewer).Route()
    Set tClass = ##class(OcuPilot.Screen.Descriptor.LogAlertViewer).ClassicPage()
    Do $$$AssertNotEquals(tClass, "", "the alerts.log viewer does declare a classic page")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Shell.About).HelpAddress(tClass), "", "which publishes no HELPADDRESS")
    Set tAvailable = 1
    Set tHref = ##class(OcuPilot.Kernel.Shell.About).HelpHref(tRoute, .tAvailable)
    Do $$$AssertEquals(''tAvailable, 0, "so no help address is available")
    Do $$$AssertEquals(tHref, "", "and none is answered")

    Set tUsersRoute = ##class(OcuPilot.Screen.Descriptor.UserList).Route()
    Do ##class(OcuPilot.Test.UiAboutFixture).SetHelpAddress(##class(OcuPilot.Screen.Descriptor.UserList).ClassicPage(), "")
    Set tAvailable = 1
    Set tArmed = ##class(OcuPilot.Test.UiAboutFixture).HelpHref(tUsersRoute, .tAvailable)
    Do $$$AssertEquals(''tAvailable, 0, "an emptied address makes an otherwise-resolving screen unavailable")
    Do $$$AssertEquals(tArmed, "", "with no address answered")
}

/// <p><b>A route no screen declares, and the empty route, resolve to nothing</b> -- the read's own
/// last line of defence behind the handler's roster check.</p>
Method TestAnUnknownRouteResolvesToNothing()
{
    Set tAvailable = 1
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Shell.About).HelpHref("no-such-area/no-such-screen", .tAvailable), "", "an unknown route answers no address")
    Do $$$AssertEquals(''tAvailable, 0, "and says it is unavailable")
    Set tAvailable = 1
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Shell.About).HelpHref("", .tAvailable), "", "and so does the empty route Home declares")
    Do $$$AssertEquals(''tAvailable, 0, "reported unavailable")
}

}
