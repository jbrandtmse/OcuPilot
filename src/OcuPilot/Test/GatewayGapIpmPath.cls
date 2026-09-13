/// <p>(QA) DW-198 (deferred). On the IPM path, both production web applications are created
/// by IPM's own <code>&lt;WebApplication&gt;</code> elements in <code>Activate</code>,
/// before the <code>When="After"</code> <code>&lt;Invoke&gt;</code> ever runs
/// <method>OcuPilot.Install.Installer.Install</method>. So when <method>Install</method>'s
/// own <method>EnsureShellApplication</method> / <method>EnsureApiApplication</method> steps
/// run, both applications already exist and take the "already exists" branch of
/// <method>EnsureWebApplication</method> rather than the "create" branch --
/// <var>pCreatedApps</var> stays empty, and
/// <method>OcuPilot.Install.Installer.ReportGatewayGap</method> reports "This install run
/// created no web application", even though two brand-new applications, created moments
/// earlier in the very same <code>Activate</code> phase, have never been registered with the
/// CSP Gateway. This story's review recorded the defect (BH9/EC9) and deferred a fix,
/// because detecting it "adds surface". This class pins the message
/// <method>ReportGatewayGap</method> emits today for an empty <var>pCreatedApps</var>, so a
/// future fix that changes what that emptiness is taken to mean is a deliberate, visible
/// edit here rather than a silent behavior change.</p>
Class OcuPilot.Test.GatewayGapIpmPath Extends %UnitTest.TestCase
{

/// <p>Mutation (Rule 19): change the wording of <method>ReportGatewayGap</method>'s
/// <code>'tAny</code> branch, or make it consult anything other than <var>pCreatedApps</var>'s
/// own emptiness to decide it -- this assertion goes red.</p>
Method TestEmptyCreatedAppsReportsNoApplicationWasCreated()
{
    Kill tReports, tCreatedApps
    Set tSC = ##class(OcuPilot.Install.Installer).ReportGatewayGap(.tReports, .tCreatedApps)
    Do $$$AssertStatusOK(tSC, "ReportGatewayGap never fails install (AD-27's fallback)")

    Set tFound = 0
    Set tN = $Order(tReports(""))
    While tN '= "" {
        If $Get(tReports(tN, "message")) [ "This install run created no web application" Set tFound = 1
        Set tN = $Order(tReports(tN))
    }
    Do $$$AssertTrue(tFound, "an empty pCreatedApps -- the shape Install() sees when IPM's own <WebApplication> elements already created both applications in this same Activate phase -- reports 'no web application was created' (DW-198, deferred): a caller cannot yet tell that shape apart from a genuinely unchanged repeat install")
}

}
