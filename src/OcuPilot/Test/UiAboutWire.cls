/// <p><code>GET /api/ocupilot/ui/about</code> and <code>GET /api/ocupilot/ui/help</code> over HTTP
/// (Story 15.3): every row of the story's I/O matrix the instance owns, asserted on status,
/// content type and body shape through the shipped router rather than by calling the handler in
/// process.</p>
/// <p>Both routes are reads and write nothing, so there is no state to set up or tear down. The
/// routes exercised are resolved from their descriptor classes rather than spelled, because a
/// descriptor's class name is the stable identity and its route is not (AD-5).</p>
/// <p>Three matrix rows are not this class's: the same-origin DocBook branch and a refused source
/// need a seam and are pinned in <class>OcuPilot.Test.UiAboutRead</class>, and an unreachable
/// instance is the client's and is pinned in <file>ui/tools/about.test.mjs</file>.</p>
Class OcuPilot.Test.UiAboutWire Extends %UnitTest.TestCase
{

/// <p>The two routes under test, from the origin root.</p>
Parameter ABOUTPATH As %String = "/api/ocupilot/ui/about";

Parameter HELPPATH As %String = "/api/ocupilot/ui/help";

/// <p>The verb both answer. Spelled so the build gate can see that this class covers the routes
/// the router declares for it.</p>
Parameter READVERB As %String = "GET";

/// <p>The thirteen scalar members the About body carries. The wire contract, spelled here.</p>
Parameter WIREMEMBERS As %String = "version,productComponents,configuration,databaseCacheMb,routineCacheMb,journalFile,superServerPort,webServerPort,licenseServer,licensedTo,encryptionKeyId,locale,buildIdentity";

/// <p>One request to <var>pPath</var> as the suite's own credentials.</p>
ClassMethod Call(pPath As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(..#READVERB, pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .pHeaders)
}

/// <p>The help read for <var>pRoute</var>, with the route carried as the one query parameter.</p>
ClassMethod CallHelp(pRoute As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ..Call(..#HELPPATH _ "?route=" _ ##class(%CSP.Page).EscapeURL(pRoute), .pStatus, .pBodyText, .pHeaders)
}

/// <p>Whether <var>pHeaders</var> says the answer is JSON.</p>
ClassMethod IsJson(ByRef pHeaders) As %Boolean
{
    Quit $ZConvert($Get(pHeaders("CONTENT-TYPE")), "L") [ "application/json"
}

/// <p><b>The About read answers 200 with every member and the three links.</b></p>
/// <p>Mutation: drop <code>journalFile</code> from
/// <method>OcuPilot.Kernel.Shell.About.Members</method> -- this goes red naming the member.</p>
Method TestTheAboutReadCarriesEveryMemberOverTheWire()
{
    Set tSC = ..Call(..#ABOUTPATH, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Do $$$AssertTrue(..IsJson(.tHeaders), "as application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    For tI = 1:1:$Length(..#WIREMEMBERS, ",") {
        Set tMember = $Piece(..#WIREMEMBERS, ",", tI)
        Do $$$AssertTrue(tAnswer.%IsDefined(tMember), "the body carries " _ tMember)
    }
    Do $$$AssertEquals(tAnswer.%GetTypeOf("links"), "object", "and a links object")
    Do $$$AssertNotEquals(tAnswer.links.documentation, "", "naming a documentation destination")
    Do $$$AssertNotEquals(tAnswer.links.support, "", "a support destination")
    Do $$$AssertNotEquals(tAnswer.links.intersystems, "", "and InterSystems")
    Do $$$AssertEquals(tAnswer.version, $ZVersion, "the version is the instance's own")
}

/// <p><b>The documentation destination is the versioned documentation site on this image</b>,
/// which ships no <code>/csp/docbook</code> application -- the matrix's degraded row, observed
/// over the wire rather than only behind a seam.</p>
Method TestTheDocumentationLinkDegradesToTheVersionedSite()
{
    Set tSC = ..Call(..#ABOUTPATH, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Do $$$AssertTrue(..IsJson(.tHeaders), "as application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue(tAnswer.links.documentation [ "https://docs.intersystems.com/", "the documentation link names the documentation site: " _ tAnswer.links.documentation)
    Do $$$AssertTrue(tAnswer.links.documentation [ ($System.Version.GetMajor() _ $System.Version.GetMinor()), "carrying this build's version")
    Do $$$AssertTrue($Extract(tAnswer.links.support, 1, 8) = "https://", "and every outbound link is https: " _ tAnswer.links.support)
    Do $$$AssertTrue($Extract(tAnswer.links.intersystems, 1, 8) = "https://", "including the InterSystems one: " _ tAnswer.links.intersystems)
}

/// <p><b>A screen whose classic page publishes a help address answers it.</b></p>
Method TestTheHelpReadResolvesAScreenWithAClassicHelpAddress()
{
    Set tRoute = ##class(OcuPilot.Screen.Descriptor.UserList).Route()
    Set tSC = ..CallHelp(tRoute, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Do $$$AssertTrue(..IsJson(.tHeaders), "as application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.%GetTypeOf("available"), "boolean", "available travels as a boolean")
    Do $$$AssertEquals(''tAnswer.available, 1, "and is true for a screen with a classic help address")
    Do $$$AssertNotEquals(tAnswer.href, "", "with an address answered: " _ tAnswer.href)
    Do $$$AssertTrue(tAnswer.href [ "KEY=", "carried as the DocBook KEY: " _ tAnswer.href)
}

/// <p><b>A screen with no classic equivalent answers 200 and unavailable</b> -- not an error
/// (AD-44).</p>
Method TestTheHelpReadAnswersUnavailableForAScreenWithNoClassicPage()
{
    Set tRoute = ##class(OcuPilot.Screen.Descriptor.AgentDefinitionList).Route()
    Set tSC = ..CallHelp(tRoute, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200, never an error: " _ tBody)
    Do $$$AssertTrue(..IsJson(.tHeaders), "as application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(''tAnswer.available, 0, "reporting no help address")
    Do $$$AssertEquals(tAnswer.href, "", "and answering none")
}

/// <p><b>A classic page carrying no <code>HELPADDRESS</code> answers 200 and unavailable</b> --
/// an absent parameter reads <code>""</code>, never a fault.</p>
Method TestTheHelpReadAnswersUnavailableForAClassicPageWithNoHelpAddress()
{
    Set tRoute = ##class(OcuPilot.Screen.Descriptor.LogAlertViewer).Route()
    Set tSC = ..CallHelp(tRoute, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Do $$$AssertTrue(..IsJson(.tHeaders), "as application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(''tAnswer.available, 0, "reporting no help address")
    Do $$$AssertEquals(tAnswer.href, "", "and answering none")
}

/// <p><b>A route no screen declares is refused 422 on <code>route</code></b> under
/// <parameter>OcuPilot.Api.Error.HELPROUTE</parameter>, carrying the sentence the server writes
/// for that code.</p>
/// <p>This is where the code and its reason are pinned over the wire, because
/// <method>OcuPilot.Api.Error.ViolationCodes</method> sweeps <code>AGENT.*</code> alone -- the same
/// division <class>OcuPilot.Test.AccountPasswordWire</class> holds for the
/// <code>ACCOUNT.*</code> pair.</p>
/// <p>Mutation: make <method>OcuPilot.Api.UiAbout.IsRosterRoute</method> answer 1 unconditionally
/// -- the refusal becomes a 200 and this goes red.</p>
Method TestAnUnknownRouteIsRefusedWithTheHelpRouteCode()
{
    Set tSC = ..CallHelp("no-such-area/no-such-screen", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused 422: " _ tBody)
    Do $$$AssertTrue(..IsJson(.tHeaders), "as application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.error, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, "on the validation slug")
    Do $$$AssertEquals(tAnswer.code, ##class(OcuPilot.Api.Error).#HELPROUTE, "under the HELP.ROUTE code")
    Do $$$AssertEquals(tAnswer.detail.violations.%Size(), 1, "with exactly one violation")
    Do $$$AssertEquals(tAnswer.detail.violations.%Get(0).field, "route", "on the route field")
    Do $$$AssertEquals(tAnswer.detail.violations.%Get(0).code, ##class(OcuPilot.Api.Error).#HELPROUTE, "carrying the same code")
    Do $$$AssertEquals(tAnswer.detail.violations.%Get(0).reason, ##class(OcuPilot.Api.Error).#REASONHELPROUTE, "and the sentence the server writes for it")
}

/// <p><b>A missing and an empty <code>route</code> take the same refusal</b>, and so does one
/// longer than <parameter>OcuPilot.Kernel.State.Base.ROUTEMAXLENGTH</parameter> -- validated
/// before any lookup, so an over-long value never reaches the registry.</p>
Method TestAMissingEmptyOrOverlongRouteTakesTheSameRefusal()
{
    Set tSC = ..Call(..#HELPPATH, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "a request with no route completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused 422: " _ tBody)
    Do $$$AssertTrue(..IsJson(.tHeaders), "as application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.code, ##class(OcuPilot.Api.Error).#HELPROUTE, "under the HELP.ROUTE code")

    Set tSC = ..CallHelp("", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "an empty route completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused 422: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.code, ##class(OcuPilot.Api.Error).#HELPROUTE, "under the same code, which is also Home's own declared route")

    Set tLong = ""
    For tI = 1:1:(##class(OcuPilot.Kernel.State.Base).#ROUTEMAXLENGTH + 1) {
        Set tLong = tLong _ "a"
    }
    Set tSC = ..CallHelp(tLong, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "an over-long route completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused 422: " _ tBody)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.code, ##class(OcuPilot.Api.Error).#HELPROUTE, "under the same code")
}

}
