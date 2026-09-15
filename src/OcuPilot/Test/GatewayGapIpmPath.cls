/// <p>DW-198 (Story 1.17, closed). On the IPM path both production web applications are created
/// by IPM's own <code>&lt;WebApplication&gt;</code> elements in <code>Activate</code>, before the
/// <code>When="After"</code> <code>&lt;Invoke&gt;</code> ever runs
/// <method>OcuPilot.Install.Installer.Install</method>. The gap report used to read a per-run
/// array that only a <i>create</i> branch wrote to, so on that path it was empty and install
/// reported "created no web application" -- about two brand-new applications the CSP Gateway had
/// never been told about.</p>
/// <p>It now reads <class>OcuPilot.Kernel.State.WebApp</class>: a row is written the first time
/// install creates <b>or recognises</b> an application, and the gap is reported once, for a row
/// that has not had it reported yet. So the run with news is the run that reports, whichever way
/// the application arrived, and a repeat install says nothing.</p>
/// <p>Every <b>assertion</b> is driven on the disposable <code>"probe"</code> profile, whose
/// application paths are distinct literals from production's, so no production application or
/// record is asserted about, created or removed. <method>OnBeforeOneTest</method> does run a
/// production <method>Install</method> first, for the reason
/// <class>OcuPilot.Test.Provenance</class>'s header records: the probe profile escalates through
/// production's own routine application, and a production install repairs rather than creates on
/// an instance already installed (AD-17).</p>
/// <p>The tests write and delete the provenance row of a real probe path, and uninstall removes
/// only applications a row records, so setup and teardown both remove the probe profile through
/// <method>OcuPilot.Test.ProbeApps.Remove</method>, which removes by roster.</p>
Class OcuPilot.Test.GatewayGapIpmPath Extends %UnitTest.TestCase
{

/// <p>The probe profile's readiness path -- the one this class records, reports and forgets.</p>
Parameter PROBEREADINESS As %String = "/api/probeocupilot/readiness";

Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Test.ProbeApps).Remove()
}

Method OnAfterOneTest() As %Status
{
    Quit ##class(OcuPilot.Test.ProbeApps).Remove()
}

/// <p>Whether <var>pReports</var> carries the Gateway-gap line for <var>pPath</var>.</p>
Method ReportsGapFor(ByRef pReports, pPath As %String) As %Boolean
{
    Set tFound = 0
    Set tN = $Order(pReports(""))
    While tN '= "" {
        Set tData = $Get(pReports(tN, "data"))
        If ($Get(pReports(tN, "message")) [ "does not notify the CSP Gateway"), $IsObject(tData), tData.path = pPath {
            Set tFound = 1
        }
        Set tN = $Order(pReports(tN))
    }
    Quit tFound
}

/// <p>DW-198 -- a provenance row nobody has reported the gap for yet produces the gap line,
/// whether install created that application itself or recognised one IPM had just created. The
/// row is written with <code>Origin</code> <code>adopted</code> here, which is exactly the
/// shape the IPM path leaves behind.</p>
/// <p>Mutation (Rule 19): make
/// <method>OcuPilot.Install.Installer.ReportGatewayGap</method> read a per-run array again --
/// this run records the row and reports nothing, so the first assertion goes red.</p>
Method TestANewlyRecordedApplicationReportsItsGatewayGap()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#PROBEREADINESS), "no record of this path survives from an earlier run")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).GuardedRecord("probe", ..#PROBEREADINESS, "adopted"), "a row is recorded the way the IPM path leaves one")

    Kill tReports
    Set tSC = ##class(OcuPilot.Install.Installer).ReportGatewayGap(.tReports, "probe")
    Do $$$AssertStatusOK(tSC, "ReportGatewayGap never fails install (AD-27's fallback)")
    Do $$$AssertTrue(..ReportsGapFor(.tReports, ..#PROBEREADINESS), "the run that recorded the application names its Gateway gap, even though it created nothing itself -- which is the IPM path's own shape")
}

/// <p>The gap is reported once. A repeat install over an instance whose applications were all
/// recorded on an earlier run has no news, and says so rather than repeating a line about an
/// application the Gateway has long since picked up.</p>
/// <p>Mutation (Rule 19): stop marking the row reported in
/// <method>OcuPilot.Install.Installer.ReportGatewayGap</method> -- the second run repeats the
/// line and both assertions below go red.</p>
Method TestTheGapIsReportedOnceAndThenTheRunSaysItRecordedNothingNew()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#PROBEREADINESS), "no record survives from an earlier run")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).GuardedRecord("probe", ..#PROBEREADINESS, "created"), "a row is recorded")

    Kill tFirst
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).ReportGatewayGap(.tFirst, "probe"), "the first report succeeds")
    Do $$$AssertTrue(..ReportsGapFor(.tFirst, ..#PROBEREADINESS), "and names the gap")

    Kill tSecond
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).ReportGatewayGap(.tSecond, "probe"), "the second report succeeds")
    Do $$$AssertTrue('..ReportsGapFor(.tSecond, ..#PROBEREADINESS), "and names nothing, because the record has already been reported")

    Set tSaidNothingNew = 0
    Set tN = $Order(tSecond(""))
    While tN '= "" {
        If $Get(tSecond(tN, "message")) [ "recorded no new web application" Set tSaidNothingNew = 1
        Set tN = $Order(tSecond(tN))
    }
    Do $$$AssertTrue(tSaidNothingNew, "the second run says it recorded nothing new, rather than saying nothing at all")
}

}
