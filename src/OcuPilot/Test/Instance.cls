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

/// <p>AC2 -- the probe is constructed at the pinned API version, which is AD-2's step 1 and
/// the thing the whole port is built on.</p>
/// <p>Mutation: construct the probe at the vendor's default version instead of
/// <parameter>APIVERSION</parameter> -> this goes red.</p>
Method TestTheProbeIsConstructedAtTheApiVersionOcuPilotPins()
{
    Do ##class(OcuPilot.Test.PortFixture).SetProbeEndpointClass("OcuPilot.Test.ProbeFixture")
    Set tSC = ##class(OcuPilot.Test.PortFixture).VerifyInstance(.tVersion, .tDetail)
    Do $$$AssertStatusOK(tSC, "the verification completes")
    Do $$$AssertEquals(tDetail, "", "a well-behaved probe answers everything the port asks")
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
Method TestACleanVerificationLogsNothing()
{
    Do ##class(OcuPilot.Test.InstanceFixture).SetVerification(2, "")
    Set tSC = ##class(OcuPilot.Test.InstanceFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(tObject.adminApiVersion, 2, "the response carries the reported version")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstanceFixture).Logged(), "", "and nothing was logged")
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

}
