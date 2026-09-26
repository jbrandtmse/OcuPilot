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
/// <p><b>It runs OcuPilot's production install, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>, <code>ocupilot-ci</code>), and
/// <method>OnBeforeAllTests</method> refuses anywhere <parameter>ARMINGVARIABLE</parameter> does
/// not arm it.</p>
Class OcuPilot.Test.GatewayGapIpmPath Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it, so the install this class
/// runs happens on the container that script builds and nowhere else.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

/// <p>Refuse to run at all unless this instance is armed for a production install.</p>
/// <p><b>A doc comment does not keep a class that installs from installing.</b> Test classes are
/// selected by package, so pointing the runner at a container someone cares about would run
/// OcuPilot's production install on it. Failing here is the honest outcome: nothing is installed
/// and the reason is named.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.GatewayGapIpmPath runs OcuPilot's PRODUCTION install on this instance -- a database, a resource, a role, three web applications, the audit registrations and the _SYSTEM unexpire -- and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was installed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

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

/// <p>Story 4.8 AC11 -- the Web Gateway response timeout is <b>information</b>. The spine's
/// Superseded entry settles it: AD-7's background job holds no request open, so the stock timeout
/// suffices and the value is no prerequisite. Install reports it once, at <code>info</code>, names
/// it as a prerequisite nowhere, succeeds when the Gateway registry answers nothing, and writes no
/// Gateway value -- the behaviour Story 1.4 shipped, given a test here rather than a claim. That
/// install itself succeeds is what the container's own start hook and
/// <file>scripts/smoke.sh</file> assert on every run; what is asserted here is the report step
/// this class drives, and that the value it read is the value still there afterwards.</p>
/// <p><b>Two before/after pairs, because one cannot see both surfaces.</b> The armed pair reads
/// through <method>OcuPilot.Test.GatewayGap.GatewayResponseTimeout</method>, whose registry read is
/// stubbed silent, so it observes only the configuration file. A write into the <i>registry</i> --
/// the surface an install would most plausibly touch -- is invisible to it, so the unarmed pair
/// brackets the same report step through <class>OcuPilot.Install.Installer</class> itself, where
/// the real registry read runs. That value is asserted non-empty first, so the comparison has a
/// subject rather than being <code>"" = ""</code>.</p>
/// <p>Mutation (Rule 19): report the timeout at <code>warn</code> instead of <code>info</code> --
/// the severity assertion goes red. Mutation: have
/// <method>OcuPilot.Install.Installer.ReportGatewayGap</method> write the timeout it read back
/// through the Gateway registry -- the unarmed pair's equality assertion goes red.</p>
Method TestTheGatewayTimeoutIsReportedOnceAsInformationAndNeverAsAPrerequisite()
{
    ; Taken through the shipped class, with no probe armed, so the real registry read runs and a
    ; write into it would move this value.
    Set tRealBefore = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).GatewayResponseTimeout(.tRealBefore, .tRealBeforeSource), "the instance answers a Web Gateway response timeout with no probe armed")
    Do $$$AssertTrue(tRealBefore '= "", "and answers a value, so the before/after comparison below has a subject: " _ tRealBeforeSource)
    Do ##class(OcuPilot.Test.GatewayGap).SetRegistryMode(##class(OcuPilot.Test.GatewayGap).#SILENTMODE)
    Try {
        ; Read through the same armed path the after-read takes, or the two compare a registry
        ; value with a configuration-file one and the assertion says nothing about writing.
        Set tBefore = ""
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GatewayGap).GatewayResponseTimeout(.tBefore, .tBeforeSource), "the value is readable before the report step runs")
        Kill tReports
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GatewayGap).ReportGatewayGap(.tReports, "probe"), "install's report step succeeds with a registry that answers nothing")
        Set tTimeoutLines = 0
        Set tLevels = ""
        Set tPrerequisite = 0
        Set tN = $Order(tReports(""))
        While tN '= "" {
            Set tMessage = $Get(tReports(tN, "message"))
            If tMessage [ "response timeout" {
                Set tTimeoutLines = tTimeoutLines + 1
                Set tLevels = tLevels _ $Select(tLevels = "": "", 1: ",") _ $Get(tReports(tN, "level"))
            }
            If $ZConvert(tMessage, "L") [ "prerequisite" Set tPrerequisite = 1
            Set tN = $Order(tReports(tN))
        }
        Do $$$AssertEquals(tTimeoutLines, 1, "the response timeout appears exactly once")
        Do $$$AssertEquals(tLevels, "info", "at severity info, because it is information and not a requirement")
        Do $$$AssertEquals(tPrerequisite, 0, "and no report names it, or anything else, as a prerequisite")
        Set tTimeout = ""
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GatewayGap).GatewayResponseTimeout(.tTimeout, .tSource), "a silent registry is not an error, it falls back to the configuration file")
        Do $$$AssertEquals($Find($ZConvert(tSource, "L"), "registry"), 0, "and the value that answered did not come from the registry: " _ tSource)
        Do $$$AssertEquals(tTimeout, tBefore, "and the value the report step read before it ran is the value still there after it, so nothing wrote one: " _ tBefore _ " -> " _ tTimeout)
    } Catch ex {
        Do ##class(OcuPilot.Test.GatewayGap).Disarm()
        Do $$$AssertStatusOK(ex.AsStatus(), "the Gateway report step raised")
    }
    Do ##class(OcuPilot.Test.GatewayGap).Disarm()
    Set tRealAfter = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).GatewayResponseTimeout(.tRealAfter, .tRealAfterSource), "the unarmed read still answers after the report step ran")
    Do $$$AssertEquals(tRealAfter _ "|" _ tRealAfterSource, tRealBefore _ "|" _ tRealBeforeSource, "and answers the same value from the same source, so the report step wrote no Gateway value -- registry included")
}

}
