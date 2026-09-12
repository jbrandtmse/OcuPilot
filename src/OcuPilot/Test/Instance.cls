/// <p>The version guard and the identity handler, pinned over fixture seams.</p>
/// <p><b>Nothing here touches the instance's own state.</b> The admin API's version is
/// pinned by pointing <class>OcuPilot.Test.PortFixture</class> at fixture classes carrying
/// fixture <code>UrlMap</code> blocks, so the real derivation runs against real XData; the
/// probe contract is broken one way at a time through
/// <class>OcuPilot.Test.ProbeFixture</class>; and the handler's own branches run over
/// <class>OcuPilot.Test.InstanceFixture</class>. The instance's admin API, its version row
/// and its security are only ever read.</p>
Class OcuPilot.Test.Instance Extends %UnitTest.TestCase
{

/// <p>A build identity no real version row would carry, so the passthrough assertion cannot
/// pass by accident against the live <code>dev</code> stamp.</p>
Parameter FIXTUREBUILD = "fixture-build-1.8";

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.ProbeFixture).Clear()
    Do ##class(OcuPilot.Test.InstanceFixture).Clear()
    Quit $$$OK
}

/// <p>AC1 -- the production port reads the instance's real admin API and reports the
/// version OcuPilot is built against, with nothing to log.</p>
/// <p>Mutation: change <parameter>OcuPilot.Port.AdminPort.ADMINAPICLASS</parameter> to a
/// class that does not exist -> this reports 0 and goes red.</p>
Method TestTheRealAdminApiIsReportedAtVersionTwo()
{
    Set tSC = ##class(OcuPilot.Port.AdminPort).VerifyInstance(.tVersion, .tDetail)
    Do $$$AssertStatusOK(tSC, "the verification completes")
    Do $$$AssertEquals(tVersion, 2, "this instance's admin API is the v2 OcuPilot is built against")
    Do $$$AssertEquals(tDetail, "", "and there is nothing to log")
}

/// <p>AC2 -- an admin API at version 1 is reported as 1, not refused and not rounded to the
/// version OcuPilot wants. The fixture carries a real <code>UrlMap</code>, so the
/// derivation under test is the production one.</p>
/// <p>Mutation: make <method>OcuPilot.Port.AdminPort.HighestDispatchVersion</method> return
/// <parameter>APIVERSION</parameter> whenever it finds any forward -> this goes red, and so
/// does the version-3 case below.</p>
Method TestAFixtureApiAtVersionOneIsReportedAsOne()
{
    Do ##class(OcuPilot.Test.PortFixture).SetAdminApiClass("OcuPilot.Test.AdminApiV1")
    Set tSC = ##class(OcuPilot.Test.PortFixture).VerifyInstance(.tVersion, .tDetail)
    Do $$$AssertStatusOK(tSC, "the verification completes")
    Do $$$AssertEquals(tVersion, 1, "the reported version is the one the route table forwards to")
    Do $$$AssertEquals(tDetail, "", "a version mismatch is not a failure: the client needs the number")
}

/// <p>AC2 -- three forwards, and the highest wins wherever it sits in the block. The
/// fixture lists v1, v3 then v2 on purpose: taking the first or the last forward would
/// report 1 or 2 and pass a test built on an ordered map.</p>
/// <p>Mutation: replace <code>If tFound > tVersion</code> with an unconditional
/// <code>Set tVersion = tFound</code> -> this reports 2 and goes red.</p>
Method TestAFixtureApiAtVersionThreeReportsTheHighestForward()
{
    Do ##class(OcuPilot.Test.PortFixture).SetAdminApiClass("OcuPilot.Test.AdminApiV3")
    Set tSC = ##class(OcuPilot.Test.PortFixture).VerifyInstance(.tVersion, .tDetail)
    Do $$$AssertStatusOK(tSC, "the verification completes")
    Do $$$AssertEquals(tVersion, 3, "the highest Dispatch.v<N> is the usable version")
}

/// <p>AC2 -- an admin API that is not on the instance at all reports 0 and an actionable
/// detail naming the class, rather than a silently degraded screen.</p>
/// <p>Mutation: seed the derivation at 1, as the vendor's own <code>Info()</code> does ->
/// the version assertion goes red and the shell would report a v1 API on an instance that
/// has none.</p>
Method TestAnAbsentAdminApiIsReportedAsZeroWithADetail()
{
    Do ##class(OcuPilot.Test.PortFixture).SetAdminApiClass("OcuPilot.Test.NoSuchAdminApi")
    Set tSC = ##class(OcuPilot.Test.PortFixture).VerifyInstance(.tVersion, .tDetail)
    Do $$$AssertStatusOK(tSC, "the verification completes")
    Do $$$AssertEquals(tVersion, 0, "an absent admin API is version 0")
    Do $$$AssertTrue(tDetail [ "OcuPilot.Test.NoSuchAdminApi", "and the detail names what was looked for")
}

/// <p>AC2 -- the API's routing class exists and its <code>UrlMap</code> forwards to no
/// dispatch class of its own. The fixture's one forward names another class deliberately,
/// so a derivation that matched any <code>Dispatch.v&lt;N&gt;</code> rather than the routing
/// class's own would report 1 here.</p>
Method TestAUrlMapThatForwardsNowhereIsReportedAsZero()
{
    Do ##class(OcuPilot.Test.PortFixture).SetAdminApiClass("OcuPilot.Test.AdminApiFlat")
    Set tSC = ##class(OcuPilot.Test.PortFixture).VerifyInstance(.tVersion, .tDetail)
    Do $$$AssertStatusOK(tSC, "the verification completes")
    Do $$$AssertEquals(tVersion, 0, "a route table that forwards to no dispatch class of its own is version 0")
    Do $$$AssertNotEquals(tDetail, "", "with a detail to log")
}

/// <p>AC2 -- the probe is constructed at the pinned API version and the pinned request
/// type, which is AD-2's step 1 and the thing the whole port is built on.</p>
/// <p>Both are asserted against the literals rather than against the port's own parameters,
/// so the assertion catches a parameter drifting away from the vendor's
/// <code>TYPELIST</code> as well as a call site that stopped reading it. They are the two
/// vendor values this port copies by hand.</p>
/// <p>Mutation: construct the probe at the vendor's default version instead of
/// <parameter>APIVERSION</parameter> -> this goes red.</p>
Method TestTheProbeIsConstructedAtTheApiVersionOcuPilotPins()
{
    Do ##class(OcuPilot.Test.PortFixture).SetProbeEndpointClass("OcuPilot.Test.ProbeFixture")
    Set tSC = ##class(OcuPilot.Test.PortFixture).VerifyInstance(.tVersion, .tDetail)
    Do $$$AssertStatusOK(tSC, "the verification completes")
    Do $$$AssertEquals(tDetail, "", "a well-behaved probe answers everything the port asks")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProbeFixture).Constructed("type"), 0, "and at the request type the vendor's TYPELIST spells")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProbeFixture).Constructed("apiVersion"), 2, "the probe is constructed at version 2")
}

/// <p>AC2 -- a probe that will not construct costs the whole report: version 0 and a detail
/// naming the class. Each of the three contract halves is broken separately, because each is
/// separately falsifiable.</p>
/// <p>Mutation: drop the <code>'$IsObject(tEndpoint)</code> branch from
/// <method>OcuPilot.Port.AdminPort.ProbeAnswers</method> -> the next line throws, the Catch
/// still reports a detail, but the version assertion holds; delete the probe check from
/// <method>VerifyInstance</method> instead and all three of these go red.</p>
Method TestAProbeThatWillNotConstructRefusesToReportAVersion()
{
    Do ##class(OcuPilot.Test.ProbeFixture).SetMode("noconstruct")
    Do ##class(OcuPilot.Test.PortFixture).SetProbeEndpointClass("OcuPilot.Test.ProbeFixture")
    Set tSC = ##class(OcuPilot.Test.PortFixture).VerifyInstance(.tVersion, .tDetail)
    Do $$$AssertStatusOK(tSC, "the verification completes")
    Do $$$AssertEquals(tVersion, 0, "a probe that will not construct is reported as an absent API")
    Do $$$AssertTrue(tDetail [ "OcuPilot.Test.ProbeFixture", "and the detail names the probe class")
}

/// <p>AC2 -- an endpoint whose <code>ResourcesOR()</code> is empty would leave AD-2's gate
/// with nothing to evaluate, so the port refuses to report a version.</p>
Method TestAProbeWithNoResourcesRefusesToReportAVersion()
{
    Do ##class(OcuPilot.Test.ProbeFixture).SetMode("noresources")
    Do ##class(OcuPilot.Test.PortFixture).SetProbeEndpointClass("OcuPilot.Test.ProbeFixture")
    Set tSC = ##class(OcuPilot.Test.PortFixture).VerifyInstance(.tVersion, .tDetail)
    Do $$$AssertStatusOK(tSC, "the verification completes")
    Do $$$AssertEquals(tVersion, 0, "an endpoint that names no resource fails the port's contract")
    Do $$$AssertTrue(tDetail [ "ResourcesOR", "and the detail names what it lacked")
}

/// <p>AC2 -- an endpoint that cannot answer <code>ShouldRunAsync()</code> leaves the
/// synchronous and async paths indistinguishable (AD-26), so the port refuses.</p>
Method TestAProbeThatCannotAnswerAsyncRefusesToReportAVersion()
{
    Do ##class(OcuPilot.Test.ProbeFixture).SetMode("asyncthrows")
    Do ##class(OcuPilot.Test.PortFixture).SetProbeEndpointClass("OcuPilot.Test.ProbeFixture")
    Set tSC = ##class(OcuPilot.Test.PortFixture).VerifyInstance(.tVersion, .tDetail)
    Do $$$AssertStatusOK(tSC, "the verification completes")
    Do $$$AssertEquals(tVersion, 0, "an endpoint that cannot answer the async question fails the contract")
    Do $$$AssertTrue(tDetail [ "OcuPilot.Test.ProbeFixture", "and the detail names the probe class")
    Do $$$AssertTrue(tDetail [ "failed the port's contract", "in the wording that separates an endpoint that threw from one that answered wrongly")
}

/// <p>AC2, DW-122 -- an endpoint that answers <code>ShouldRunAsync()</code> with neither
/// <code>0</code> nor <code>1</code>, without throwing, is the third and previously
/// undriven way the probe's contract can be broken: distinct from <code>asyncthrows</code>,
/// which lands in <method>OcuPilot.Port.AdminPort.ProbeAnswers</method>'s <code>Catch</code>
/// with a different message, this exercises the method's own comparison branch.</p>
/// <p>Mutation: delete the <code>(tAsync '= 0) && (tAsync '= 1)</code> branch from
/// <method>ProbeAnswers</method> -> this reports the real instance's version 2 (a healthy
/// port) instead of refusing, and both assertions go red.</p>
Method TestAProbeThatAnswersAsyncWithANonBooleanRefusesToReportAVersion()
{
    Do ##class(OcuPilot.Test.ProbeFixture).SetMode("asyncnonboolean")
    Do ##class(OcuPilot.Test.PortFixture).SetProbeEndpointClass("OcuPilot.Test.ProbeFixture")
    Set tSC = ##class(OcuPilot.Test.PortFixture).VerifyInstance(.tVersion, .tDetail)
    Do $$$AssertStatusOK(tSC, "the verification completes")
    Do $$$AssertEquals(tVersion, 0, "a non-boolean answer to ShouldRunAsync() fails the contract")
    Do $$$AssertTrue(tDetail [ "answered ShouldRunAsync() with 5", "and the detail names what it answered")
}

/// <p>AC2 -- the handler reports whatever version the port gave it and sends the detail to
/// the log rather than to the browser.</p>
/// <p>Mutation: delete the <code>If tDetail '= "" Do ..LogDetail(tDetail)</code> line from
/// <method>OcuPilot.Api.Instance.Payload</method> -> the log assertion goes red while the
/// response stays correct, which is the failure mode AD-27 calls "a screen that half
/// works".</p>
Method TestThePayloadReportsTheVersionAndSendsTheDetailToTheLog()
{
    Do ##class(OcuPilot.Test.InstanceFixture).SetVerification(1, "fixture detail for the log")
    Set tSC = ##class(OcuPilot.Test.InstanceFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(tObject.adminApiVersion, 1, "the response carries the reported version")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstanceFixture).Logged(), "fixture detail for the log", "and the detail reached the log")
    Do $$$AssertEquals(tObject.%ToJSON() [ "fixture detail for the log", 0, "never the browser")
}

/// <p>AC2 -- a clean verification logs nothing, so the log is a signal rather than noise.</p>
/// <p>The call count, not the captured detail, is what carries this: an empty detail logged
/// and a detail never logged both read back as <code>""</code>, so an assertion on
/// <method>OcuPilot.Test.InstanceFixture.Logged</method> alone stays green with the guard
/// removed and one error entry emitted per healthy request.</p>
/// <p>Mutation: drop the <code>If tDetail '= ""</code> condition from
/// <method>OcuPilot.Api.Instance.Payload</method>, leaving the call unconditional -> the
/// count assertion goes red.</p>
Method TestACleanVerificationLogsNothing()
{
    Do ##class(OcuPilot.Test.InstanceFixture).SetVerification(2, "")
    Set tSC = ##class(OcuPilot.Test.InstanceFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(tObject.adminApiVersion, 2, "the response carries the reported version")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstanceFixture).LogCalls(), 0, "and the log was never called")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstanceFixture).Logged(), "", "so nothing was logged")
}

/// <p>DW-3, server half -- the response's <code>buildIdentity</code> is the version row's
/// value byte for byte, not a re-read of the deployed constant.</p>
/// <p>Mutation: emit
/// <parameter>OcuPilot.Install.Installer.BUILDIDENTITY</parameter> from
/// <method>OcuPilot.Api.Instance.Payload</method> instead of calling
/// <method>BuildIdentity</method> -> the fixture assertion goes red. The mutation has to
/// bypass the seam rather than change what it reads: on the live instance the deployed
/// constant and the row's value are both <code>dev</code>, so only a fixture value no row
/// carries can tell the two apart.</p>
Method TestThePayloadCarriesTheVersionRowsBuildIdentity()
{
    Do ##class(OcuPilot.Test.InstanceFixture).SetVerification(2, "")
    Do ##class(OcuPilot.Test.InstanceFixture).SetBuildIdentity(..#FIXTUREBUILD)
    Set tSC = ##class(OcuPilot.Test.InstanceFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(tObject.buildIdentity, ..#FIXTUREBUILD, "the stamp travels unchanged")

    Set tRowSC = ##class(OcuPilot.Install.Installer).CurrentVersionRow("", .tRow)
    Do $$$AssertStatusOK(tRowSC, "the production version row reads")
    Do $$$AssertTrue($IsObject(tRow), "and exists on an installed instance")
    If $IsObject(tRow) {
        Do $$$AssertEquals(##class(OcuPilot.Api.Instance).BuildIdentity(), tRow.BuildIdentity, "and the production read is that row's own value")
    }
}

/// <p>DW-120 -- <method>OcuPilot.Api.Instance.Handle</method>'s own internal-error branch,
/// reached only when the verification seam <code>Throw</code>s rather than returns an error
/// <class>%Status</class>: <method>Payload</method> reads a bad status only to source a log
/// detail and still returns <code>$$$OK</code> (see
/// <method>TestThePayloadReportsTheVersionAndSendsTheDetailToTheLog</method>), so nothing
/// short of a genuine exception ever exercises this branch. Dispatched through
/// <class>OcuPilot.Test.RouterFixture</class>'s <code>/instance-fault</code> route, the only
/// path that reaches <class>OcuPilot.Test.InstanceFixture</class>'s <code>Handle</code>
/// with real output capture (<class>OcuPilot.Test.Dispatch</class>).</p>
/// <p>Mutation: delete the <code>$$$ISERR(tSC)</code> branch from
/// <method>OcuPilot.Api.Instance.Handle</method> (call <method>Response.JSON</method> on
/// whatever <method>Payload</method> returned regardless) -> the dispatch renders a bare
/// <code>{}</code> at 200 instead of the internal-error envelope, and every assertion below
/// goes red.</p>
Method TestHandleRendersTheInternalErrorEnvelopeWhenVerificationThrows()
{
    Do ##class(OcuPilot.Test.InstanceFixture).SetVerificationThrows("fixture: verification exploded")
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/instance-fault", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 500, "a verification exception renders the internal-error envelope")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope reaches the wire")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.error, "server_error", "through the one error writer")
    Do $$$AssertEquals(tObj.code, "INTERNAL", "with the internal machine code")
    Do $$$AssertEquals(tObj.reason, "An internal error occurred", "and a generic reason, never the exception text")
    Do $$$AssertTrue((tBody '[ "fixture: verification exploded"), "the real exception text is logged, never sent")
}

/// <p>AC1 -- the instance's own name and version reach the response, from the two reads
/// AD-16 says need no namespace switch.</p>
Method TestThePayloadCarriesTheInstanceNameAndVersion()
{
    Set tStartNs = $NAMESPACE
    Do ##class(OcuPilot.Test.InstanceFixture).SetVerification(2, "")
    Set tSC = ##class(OcuPilot.Test.InstanceFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(tObject.instanceName, ##class(%SYS.System).GetInstanceName(), "the instance names itself")
    Do $$$AssertEquals(tObject.instanceVersion, $ZVersion, "and reports its own version banner")
    Do $$$AssertEquals($NAMESPACE, tStartNs, "with no namespace left switched")
}

/// <p>Story 1.10 -- the three status-bar fields are the instance's own reads, verbatim, and
/// no read leaves the namespace switched.</p>
/// <p>Mutation: emit <code>$ZVersion</code> for <code>serverName</code> instead of calling
/// <method>OcuPilot.Api.Instance.ServerName</method> -> this goes red.</p>
Method TestThePayloadCarriesTheFlagLicenseeAndServerName()
{
    Set tStartNs = $NAMESPACE
    Do ##class(OcuPilot.Test.InstanceFixture).SetVerification(2, "")
    Set tSC = ##class(OcuPilot.Test.InstanceFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(tObject.serverFlag, $SYSTEM.Version.SystemMode(), "the flag is the instance's own system mode")
    Do $$$AssertEquals(tObject.licensedTo, $SYSTEM.License.KeyCustomerName(), "the licensee is the active key's customer name")
    Do $$$AssertEquals(tObject.serverName, ##class(%SYS.System).GetNodeName(), "the server name is the host node")
    Do $$$AssertEquals($NAMESPACE, tStartNs, "with no namespace left switched")
}

/// <p>DW-10, server half -- an instance with no system mode set reports <code>""</code>, and
/// the key is still on the wire so the client can tell "no flag" from "no such field". This
/// container is exactly that case, but the source is armed rather than assumed, so the
/// assertion does not quietly become a tautology on an instance somebody has flagged.</p>
/// <p>Mutation: have <method>OcuPilot.Api.Instance.ServerFlag</method> return
/// <code>"LIVE"</code> when the read is empty -- DW-10's own rejected suggestion -> this goes
/// red, and an unflagged instance would be dressed as production.</p>
Method TestAnUnflaggedInstanceReportsAnEmptyFlagAndStillCarriesTheKey()
{
    Do ##class(OcuPilot.Test.InstanceFixture).SetVerification(2, "")
    Do ##class(OcuPilot.Test.InstanceFixture).SetSource("flag", "")
    ; Armed, not read from the live key: an instance whose licence carries no customer name
    ; would otherwise fail this on a point that has nothing to do with DW-10.
    Do ##class(OcuPilot.Test.InstanceFixture).SetSource("licensee", "Acme Health")
    Set tSC = ##class(OcuPilot.Test.InstanceFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(tObject.serverFlag, "", "an unset system mode is reported as absent, never defaulted")
    Do $$$AssertTrue(tObject.%IsDefined("serverFlag"), "and the key is present so the client can drop the badge deliberately")
    Do $$$AssertEquals(tObject.licensedTo, "Acme Health", "while the other status-bar fields are unchanged")
}

/// <p>DW-10, server half -- a mode outside the vendor's four can only reach the global by a
/// direct write, and travels verbatim rather than being mapped onto one of the four or
/// dropped. Driven through the fixture seam: <code>^%SYS("SystemMode")</code> is never
/// written on this instance.</p>
Method TestAFlagOutsideTheVendorsFourTravelsVerbatim()
{
    Do ##class(OcuPilot.Test.InstanceFixture).SetVerification(2, "")
    Do ##class(OcuPilot.Test.InstanceFixture).SetSource("flag", "STANDBY")
    Set tSC = ##class(OcuPilot.Test.InstanceFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(tObject.serverFlag, "STANDBY", "an unrecognised mode is reported as it was read")
}

/// <p>Story 1.10 -- a status-bar source that throws costs that one field and nothing else:
/// it reads <code>""</code>, every other field still carries its value, the response is
/// still a 200 with one envelope, and the refusal names itself in the log rather than
/// leaving the segment silently absent.</p>
/// <p>Mutation: delete the <code>Try</code> from
/// <method>OcuPilot.Api.Instance.LicensedTo</method> -> the exception escapes
/// <method>Payload</method>'s own <code>Catch</code>, <method>Handle</method> renders the
/// internal-error envelope, and the status assertion goes red at 500.</p>
Method TestAThrowingStatusBarSourceDegradesToAnEmptyField()
{
    Do ##class(OcuPilot.Test.InstanceFixture).SetVerification(2, "")
    Do ##class(OcuPilot.Test.InstanceFixture).SetSourceThrows("licensee")
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Test.RouterFixture", "/instance-fault", "GET", , .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 200, "a refused field is not a failed request")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope reaches the wire")
    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObj.licensedTo, "", "the field that could not be read is empty")
    Do $$$AssertEquals(tObj.serverName, ##class(%SYS.System).GetNodeName(), "and the fields beside it are untouched")
    Do $$$AssertTrue((tBody '[ "source refused"), "the exception text is never sent to the browser")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstanceFixture).SourceLogCalls(), 1, "the refusal reaches the log exactly once")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstanceFixture).SourceLogged(), "licensee", "naming the field that degraded, so an absent segment is recoverable")
}

/// <p>Story 1.10 -- the production log seam itself runs, and swallows its own failure. Every
/// other test here reaches it through <class>OcuPilot.Test.InstanceFixture</class>'s
/// override, so the real body has no test host: it could be empty, or throw, and the suite
/// would stay green while a refused read logged nothing.</p>
/// <p>Mutation: delete the <code>Try</code> from
/// <method>OcuPilot.Api.Instance.LogSourceFailure</method> -> the second case goes red,
/// because <code>DisplayString()</code> on a non-object throws, and in production that
/// exception would escape the per-field <code>Catch</code> and become the 500 it exists to
/// prevent.</p>
Method TestTheProductionLogSeamRunsAndSwallowsItsOwnFailure()
{
    Set tThrew = 0
    Try {
        Set tEx = ##class(%Exception.General).%New("InstanceTest", 1, , "probe: source refused")
        Do ##class(OcuPilot.Api.Instance).LogSourceFailure("licensee", tEx)
    } Catch {
        Set tThrew = 1
    }
    Do $$$AssertEquals(tThrew, 0, "the real seam completes rather than escaping the per-field Catch")

    Set tThrewOnBadArgument = 0
    Try {
        Do ##class(OcuPilot.Api.Instance).LogSourceFailure("licensee", "")
    } Catch {
        Set tThrewOnBadArgument = 1
    }
    Do $$$AssertEquals(tThrewOnBadArgument, 0, "and a caller with no exception object costs the field, never the response")
}

/// <p>Story 1.10 -- the converse, and the half that makes the assertion above falsifiable:
/// three sources that answer log nothing at all.</p>
Method TestStatusBarSourcesThatAnswerLogNothing()
{
    Do ##class(OcuPilot.Test.InstanceFixture).SetVerification(2, "")
    Set tSC = ##class(OcuPilot.Test.InstanceFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstanceFixture).SourceLogCalls(), 0, "a read that succeeded is not an error to log")
}

}
