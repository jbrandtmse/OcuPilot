/// <p>The System information payload (Story 15.4): every member present, one refused source
/// degrading that member alone, an unsampled metric reading <code>""</code>, the mirror
/// accessor's caught-error answer normalized, and the two production branches.</p>
/// <p>Needs an installed instance whose process may reach <code>%SYS</code>. It changes no
/// instance state; the one row that drives the real audit-log seam emits two error lines to
/// <code>messages.log</code>, which is that seam running rather than a side effect to clean up.
/// Four branches are unreachable on a healthy container without a seam --
/// <class>OcuPilot.Test.UiSystemFixture</class> is that seam: no source refuses here, the monitor
/// has collected every metric, this instance is not a mirror member, and
/// <code>HSCUSTOM</code> is production-enabled.</p>
Class OcuPilot.Test.UiSystemRead Extends %UnitTest.TestCase
{

/// <p>The seven scalar members the payload carries, spelled here rather than read from
/// <method>OcuPilot.Kernel.Shell.SystemInfo.Members</method>: the wire contract is what this
/// pins, and deriving the expectation from the code under test would assert it against
/// itself.</p>
Parameter WIREMEMBERS As %String = "uptime,mirror,databaseSpace,journalSpace,lockTable,writeDaemon,production";

/// <p>The five members one dashboard sample serves.</p>
Parameter DASHBOARDMEMBERS As %String = "uptime,databaseSpace,journalSpace,lockTable,writeDaemon";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.UiSystemFixture).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.UiSystemFixture).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p><b>Every member is on the payload</b>, as a string. A member the instance could not report
/// is <code>""</code>, never an absent key.</p>
/// <p>Mutation: drop one member from
/// <method>OcuPilot.Kernel.Shell.SystemInfo.Members</method>, recompile the class and every
/// descendant -- this goes red naming the member, as does
/// <class>OcuPilot.Test.UiSystemWire</class> over the wire.</p>
Method TestThePayloadCarriesEveryMember()
{
    Set tSC = ##class(OcuPilot.Kernel.Shell.SystemInfo).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertTrue($IsObject(tObject), "and is an object")
    If '$IsObject(tObject) Quit
    For tI = 1:1:$Length(..#WIREMEMBERS, ",") {
        Set tMember = $Piece(..#WIREMEMBERS, ",", tI)
        Do $$$AssertTrue(tObject.%IsDefined(tMember), "the payload carries " _ tMember)
        Do $$$AssertEquals(tObject.%GetTypeOf(tMember), "string", tMember _ " travels as a string")
    }
}

/// <p><b>The carried values are the instance's own</b>, the four alert words asserted against the
/// vendor sample's own properties rather than against a second call to the code under test, so a
/// property-to-member mapping swapped inside the reader moves one side only.</p>
/// <p>Mutation: reformat the uptime in
/// <method>OcuPilot.Kernel.Shell.SystemInfo.ReadSource</method> -- for instance
/// <code>$ZStrip(&lt;value&gt;, "*W")</code>, which a reader "tidying" the vendor's double space
/// would write -- and the armed assertion at the end goes red.</p>
Method TestTheCarriedValuesAreTheInstancesOwn()
{
    Set tSC = ##class(OcuPilot.Kernel.Shell.SystemInfo).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    If '$IsObject(tObject) Quit

    ; The four alert words are compared against the vendor object this test samples itself, in
    ; %SYS, by the class name the reader also reaches by name. The uptime is not: it is a live
    ; duration and two samples a moment apart may legitimately differ by a minute, so it is pinned
    ; against an armed value instead -- which is the stronger assertion anyway, because the armed
    ; string carries the double space the vendor formats with and any reformatting would lose it.
    Set tOrigNS = $NAMESPACE
    Set tSample = ""
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSample = $ClassMethod("SYS.Stats.Dashboard", "Sample")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Do $$$AssertTrue($IsObject(tSample), "the vendor's own dashboard sample is available to compare against")
    If $IsObject(tSample) {
        Do $$$AssertEquals(tObject.databaseSpace, tSample.DatabaseSpace, "databaseSpace is the sample's own DatabaseSpace")
        Do $$$AssertEquals(tObject.journalSpace, tSample.JournalSpace, "journalSpace is the sample's own JournalSpace")
        Do $$$AssertEquals(tObject.lockTable, tSample.LockTable, "lockTable is the sample's own LockTable")
        Do $$$AssertEquals(tObject.writeDaemon, tSample.WriteDaemon, "writeDaemon is the sample's own WriteDaemon")
    }
    Set tSample = ""
    Do $$$AssertNotEquals(tObject.uptime, "", "this instance reports an uptime: " _ tObject.uptime)
    Do $$$AssertEquals(tObject.mirror, $ListGet($SYSTEM.Mirror.GetMemberStatus(), 1), "the mirror member state is the accessor's own word")
    Do $$$AssertEquals(tObject.mirror, "Not initialized", "which on this container is the non-member word, spelled as the vendor spells it")
    Do $$$AssertTrue(tObject.writeDaemon = "Normal" || (tObject.writeDaemon = "Troubled"), "the write daemon carries one of the two words its source publishes: " _ tObject.writeDaemon)

    Set tUptime = "4d  4h 08m"
    Do ##class(OcuPilot.Test.UiSystemFixture).SetDashboardValue("uptime", tUptime)
    Set tSC = ##class(OcuPilot.Test.UiSystemFixture).Payload(.tArmed)
    Do $$$AssertStatusOK(tSC, "an armed sample builds")
    Do $$$AssertEquals(tArmed.uptime, tUptime, "the uptime is carried verbatim, double space included -- never computed and never reformatted")
}

/// <p><b>One refused source degrades that member alone</b> and names itself in the log; the other
/// six answer and the payload's status is still OK.</p>
/// <p>Mutation: remove the per-field <code>Try</code> from
/// <method>OcuPilot.Kernel.Shell.SystemInfo.Field</method> -- the payload's status goes to an
/// error and every assertion below reddens.</p>
Method TestARefusedSourceDegradesThatMemberAloneAndIsLogged()
{
    Do ##class(OcuPilot.Test.UiSystemFixture).SetSourceThrows("mirror")
    Set tSC = ##class(OcuPilot.Test.UiSystemFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "a refused source is not a failed payload")
    Do $$$AssertTrue($IsObject(tObject), "which is still built")
    If '$IsObject(tObject) Quit
    Do $$$AssertEquals(tObject.mirror, "", "the refused member degrades to the empty string")
    Do $$$AssertTrue(tObject.%IsDefined("mirror"), "and is still a key on the wire")
    Do $$$AssertNotEquals(tObject.uptime, "", "while the uptime still answers")
    Do $$$AssertNotEquals(tObject.writeDaemon, "", "and so does the write daemon")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiSystemFixture).SourceLogCalls(), 1, "the refusal reached the log exactly once")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiSystemFixture).SourceLogged(), "mirror", "naming the member that failed")
}

/// <p><b>A healthy read logs nothing.</b> Without this the assertion above would pass on a reader
/// that logged on every member.</p>
Method TestAHealthyReadLogsNothing()
{
    Set tSC = ##class(OcuPilot.Test.UiSystemFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiSystemFixture).SourceLogCalls(), 0, "and no source failure was logged")
}

/// <p><b>A refused dashboard sample degrades its five members together</b> -- the ordinary case
/// for a caller without <code>%Admin_Operate:USE</code> -- while mirror and production answer,
/// and the failure is logged once rather than once per member.</p>
Method TestARefusedDashboardSampleDegradesItsFiveMembersAndLogsOnce()
{
    Do ##class(OcuPilot.Test.UiSystemFixture).SetDashboardThrows()
    Set tSC = ##class(OcuPilot.Test.UiSystemFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "a refused sample is not a failed payload")
    If '$IsObject(tObject) Quit
    For tI = 1:1:$Length(..#DASHBOARDMEMBERS, ",") {
        Set tMember = $Piece(..#DASHBOARDMEMBERS, ",", tI)
        Do $$$AssertEquals(tObject.%Get(tMember), "", tMember _ " degrades to the empty string")
        Do $$$AssertTrue(tObject.%IsDefined(tMember), "and is still a key on the wire")
    }
    Do $$$AssertNotEquals(tObject.mirror, "", "while the mirror state still answers")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiSystemFixture).SourceLogCalls(), 1, "and one sample failure is one log line, not five")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiSystemFixture).SourceLogged(), "dashboard", "naming the shared sample rather than one of the members it serves")
}

/// <p><b>A metric the Application Monitor has not collected reads <code>""</code></b>, keeping
/// its key. Absence is not a fault and never a refusal: the payload's status is unchanged and
/// nothing is logged.</p>
Method TestAnUnsampledMetricReadsEmptyAndIsNotAFailure()
{
    Do ##class(OcuPilot.Test.UiSystemFixture).SetDashboardValue("lockTable", "")
    Set tSC = ##class(OcuPilot.Test.UiSystemFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "an unsampled metric is not a failed payload")
    If '$IsObject(tObject) Quit
    Do $$$AssertEquals(tObject.lockTable, "", "the unsampled member reads the empty string")
    Do $$$AssertTrue(tObject.%IsDefined("lockTable"), "and is still a key on the wire")
    Do $$$AssertNotEquals(tObject.journalSpace, "", "while the other dashboard members answer")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiSystemFixture).SourceLogCalls(), 0, "and nothing is logged, because absence is not a refusal")
}

/// <p><b>The mirror accessor's caught-error answer is normalized to <code>""</code> and
/// logged</b>, never rendered as a mirror state. It catches its own error and returns
/// <code>$LB("Error", $ZE)</code> rather than raising, so without this normalization the panel
/// would show the word <code>Error</code> as though it were a state the instance is in.</p>
/// <p>Mutation: answer the mirror member from
/// <method>%SYSTEM.Mirror.GetStatus</method> instead of
/// <method>GetMemberStatus</method> -- the raw token is not a <code>$List</code> and carries no
/// word, and both this and <method>TestTheCarriedValuesAreTheInstancesOwn</method> go red.</p>
Method TestTheMirrorAccessorsCaughtErrorIsNotRenderedAsAState()
{
    Do ##class(OcuPilot.Test.UiSystemFixture).SetMirrorStatus($ListBuild("Error", "<UNDEFINED>zMirrorRead+3"))
    Set tSC = ##class(OcuPilot.Test.UiSystemFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "a failed mirror read is not a failed payload")
    If '$IsObject(tObject) Quit
    Do $$$AssertEquals(tObject.mirror, "", "the caught error degrades to the empty string")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiSystemFixture).SourceLogged(), "mirror", "and reaches the log naming the member")

    Do ##class(OcuPilot.Test.UiSystemFixture).Clear()
    Do ##class(OcuPilot.Test.UiSystemFixture).SetMirrorStatus($ListBuild("Primary", "Trouble"))
    Set tSC = ##class(OcuPilot.Test.UiSystemFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "a member state builds")
    Do $$$AssertEquals(tObject.mirror, "Primary", "a real state is carried as the vendor's own word")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiSystemFixture).SourceLogCalls(), 0, "and logs nothing")
}

/// <p><b>A production-enabled namespace answers the vendor's own English state word.</b> This
/// container's <code>HSCUSTOM</code> has never run one, which is <code>Stopped</code> with no
/// name -- not an error and not an empty value.</p>
/// <p>The expectation is the vendor's own mapping called with <var>pLocalize</var> 0, so the
/// assertion holds whatever the session language is (NFR-14).</p>
Method TestAProductionEnabledNamespaceAnswersTheVendorsStateWord()
{
    Do $$$AssertTrue(##class(%Library.EnsembleMgr).IsEnsembleNamespace($NAMESPACE), "this namespace is production-enabled: " _ $NAMESPACE)
    Set tName = ""
    Set tState = ""
    Set tSC = ##class(Ens.Director).GetProductionStatus(.tName, .tState)
    Do $$$AssertStatusOK(tSC, "and answers a production status")
    Set tWanted = ##class(Ens.Config.Production).ProductionStateToText(tState, 0)
    If tName '= "" Set tWanted = tWanted _ " (" _ tName _ ")"
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Shell.SystemInfo).ProductionState(), tWanted, "which is what the member carries")
    Do $$$AssertTrue(tWanted '= "", "and it is a word, not an empty value: " _ tWanted)
}

/// <p><b>A namespace that is not production-enabled answers <code>""</code></b> and is not a
/// fault: the row keeps its label and shows its not-reported word.</p>
Method TestANonInteroperabilityNamespaceAnswersNothingAndIsNotAFault()
{
    Do ##class(OcuPilot.Test.UiSystemFixture).SetEnsembleNamespace(0)
    Set tSC = ##class(OcuPilot.Test.UiSystemFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "a non-interoperability namespace is not a failed payload")
    If '$IsObject(tObject) Quit
    Do $$$AssertEquals(tObject.production, "", "the production member reads the empty string")
    Do $$$AssertTrue(tObject.%IsDefined("production"), "and is still a key on the wire")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiSystemFixture).SourceLogCalls(), 0, "and nothing is logged: not production-enabled is a declaration, not a refusal")
}

/// <p><b>The <code>%SYS</code> switch is restored on both paths</b> -- the sample's own and the
/// refused one -- so a later read in the caller's namespace is unaffected (AD-16).</p>
Method TestTheNamespaceIsRestoredOnBothDashboardPaths()
{
    Set tOrigNS = $NAMESPACE
    Kill tSampled
    Do ##class(OcuPilot.Kernel.Shell.SystemInfo).Dashboard(.tSampled)
    Do $$$AssertEquals($NAMESPACE, tOrigNS, "a sample that answers restores the caller's namespace")

    Do ##class(OcuPilot.Test.UiSystemFixture).SetDashboardThrows()
    Kill tRefused
    Do ##class(OcuPilot.Test.UiSystemFixture).Dashboard(.tRefused)
    Do $$$AssertEquals($NAMESPACE, tOrigNS, "and so does one that raises")
    Do $$$AssertEquals($Data(tRefused), 0, "which leaves no sampled value behind")
}

/// <p><b>The production member follows the request's scope, not the process's namespace.</b>
/// <method>OcuPilot.Api.Router.OnPreDispatch</method> stashes the validated <code>?ns=</code> in
/// <class>OcuPilot.Kernel.Scope</class> and never assigns <code>$NAMESPACE</code>, so a read that
/// consulted <code>$NAMESPACE</code> would answer this namespace's production status for every
/// scope -- including <code>%SYS</code>, which is not production-enabled.</p>
/// <p>Mutation: answer <method>OcuPilot.Kernel.Shell.SystemInfo.ProductionEnabled</method> from
/// <code>$NAMESPACE</code> instead of <method>OcuPilot.Kernel.Scope.Current</method>, recompile
/// the class and every descendant -- this goes red on the scoped assertion.</p>
Method TestTheProductionMemberFollowsTheRequestsScope()
{
    Do $$$AssertNotEquals(##class(OcuPilot.Kernel.Shell.SystemInfo).ProductionState(), "", "unscoped, this production-enabled namespace answers a word")

    Do ##class(OcuPilot.Kernel.Scope).Set("%SYS")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Shell.SystemInfo).ProductionState(), "", "a scope that is not production-enabled answers nothing")
}

/// <p><b>The production read runs in the scoped namespace and restores the caller's</b> (AD-16).
/// The row above settles which namespace the <i>enabled</i> check consults; it cannot settle this
/// one, because a scope that is not production-enabled returns before the switch is reached.</p>
/// <p>Mutation: delete <code>Set $NAMESPACE = tScope</code> from
/// <method>OcuPilot.Kernel.Shell.SystemInfo.ProductionState</method>, recompile the class and
/// every descendant -- the seam then records the caller's namespace and this goes red.</p>
Method TestTheProductionReadRunsInTheScopedNamespace()
{
    Set tOrigNS = $NAMESPACE
    Do ##class(OcuPilot.Test.UiSystemFixture).SetEnsembleNamespace(1)
    Do ##class(OcuPilot.Test.UiSystemFixture).SetProductionStatusFails()
    Do ##class(OcuPilot.Kernel.Scope).Set("%SYS")

    Set tSC = ##class(OcuPilot.Test.UiSystemFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiSystemFixture).ProductionNamespace(), "%SYS", "the production seam ran in the scoped namespace, not the caller's")
    Do $$$AssertEquals($NAMESPACE, tOrigNS, "and the caller's own namespace is restored afterwards")
}

/// <p><b>A production read that raises restores the namespace before it rethrows</b> (AD-16: the
/// restore is the first line of the <code>Catch</code>). Without it the process would carry on in
/// the scoped namespace for the rest of the payload and the rest of the request.</p>
/// <p>Mutation: delete <code>Set $NAMESPACE = tOrigNS</code> from that <code>Catch</code>,
/// recompile the class and every descendant -- the namespace assertion goes red.</p>
Method TestARaisingProductionReadRestoresTheNamespaceBeforeItRethrows()
{
    Set tOrigNS = $NAMESPACE
    Do ##class(OcuPilot.Test.UiSystemFixture).SetEnsembleNamespace(1)
    Do ##class(OcuPilot.Test.UiSystemFixture).SetProductionStatusThrows()
    Do ##class(OcuPilot.Kernel.Scope).Set("%SYS")

    Set tSC = ##class(OcuPilot.Test.UiSystemFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "a raising production read is not a failed payload")
    Do $$$AssertEquals($NAMESPACE, tOrigNS, "the caller's namespace is restored before the rethrow")
    If '$IsObject(tObject) Quit
    Do $$$AssertEquals(tObject.production, "", "the member degrades to the empty string")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiSystemFixture).SourceLogged(), "production", "and the failure reaches the log naming the member")
}

/// <p><b>A state the vendor's own text mapping has no arm for degrades to <code>""</code></b>
/// rather than publishing its <code>Unrecognized:&lt;code&gt;</code> diagnostic token as though it
/// were a state. Codes 5, 6 and -5 all reach that fall-through;
/// <method>Ens.Director.GetProductionStatus</method> answers 5 on its
/// <code>$$$EnsRuntime("System")</code> branch and 6 on its shard-worker one.</p>
/// <p>It is not a refusal: absence is what the row shows, and nothing is logged.</p>
Method TestAnUnrecognizedProductionStateIsNotPublishedAsAToken()
{
    Do ##class(OcuPilot.Test.UiSystemFixture).SetProductionStatus("", 5)
    Set tSC = ##class(OcuPilot.Test.UiSystemFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "an unrecognized state is not a failed payload")
    If '$IsObject(tObject) Quit
    Do $$$AssertEquals(tObject.production, "", "the unrecognized state degrades to the empty string")
    Do $$$AssertTrue(tObject.%IsDefined("production"), "and is still a key on the wire")
    Do $$$AssertTrue(##class(Ens.Config.Production).ProductionStateToText(5, 0) [ "Unrecognized", "the vendor still has no arm for this code: " _ ##class(Ens.Config.Production).ProductionStateToText(5, 0))
    Do $$$AssertEquals(##class(OcuPilot.Test.UiSystemFixture).SourceLogCalls(), 0, "and nothing is logged: an unrecognized state is not a refused read")

    Do ##class(OcuPilot.Test.UiSystemFixture).Clear()
    Do ##class(OcuPilot.Test.UiSystemFixture).SetProductionStatus("Demo", 1)
    Set tSC = ##class(OcuPilot.Test.UiSystemFixture).Payload(.tRunning)
    Do $$$AssertStatusOK(tSC, "a recognized state builds")
    Do $$$AssertEquals(tRunning.production, "Running (Demo)", "and is carried as the vendor's own word with the production's name")
}

/// <p><b>A refused production read degrades that member alone and reaches the log</b> -- the case
/// a runtime lock this read cannot take within
/// <parameter>OcuPilot.Kernel.Shell.SystemInfo.PRODUCTIONLOCKTIMEOUT</parameter> seconds
/// produces on a contended instance.</p>
Method TestARefusedProductionReadDegradesThatMemberAndIsLogged()
{
    Do ##class(OcuPilot.Test.UiSystemFixture).SetProductionStatusFails()
    Set tSC = ##class(OcuPilot.Test.UiSystemFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "a refused production read is not a failed payload")
    If '$IsObject(tObject) Quit
    Do $$$AssertEquals(tObject.production, "", "the refused member degrades to the empty string")
    Do $$$AssertNotEquals(tObject.mirror, "", "while the mirror state still answers")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiSystemFixture).SourceLogCalls(), 1, "the refusal reached the log exactly once")
    Do $$$AssertEquals(##class(OcuPilot.Test.UiSystemFixture).SourceLogged(), "production", "naming the member that failed")
}

/// <p><b>The production log seam runs and swallows its own failure.</b> Every other row here
/// reaches it through <class>OcuPilot.Test.UiSystemFixture</class>'s override, so without this the
/// body that keeps a degraded member from becoming a 500 would never execute at all.</p>
/// <p>Mutation: delete the <code>Try</code> from
/// <method>OcuPilot.Kernel.Shell.SystemInfo.LogSourceFailure</method> -> the second case goes red,
/// because <code>DisplayString()</code> on a non-object throws.</p>
Method TestTheProductionLogSeamRunsAndSwallowsItsOwnFailure()
{
    Set tThrew = 0
    Try {
        Set tEx = ##class(%Exception.General).%New("UiSystemRead", 1, , "probe: source refused")
        Do ##class(OcuPilot.Kernel.Shell.SystemInfo).LogSourceFailure("mirror", tEx)
    } Catch {
        Set tThrew = 1
    }
    Do $$$AssertEquals(tThrew, 0, "the real seam completes rather than escaping the per-field Catch")

    Set tThrewOnBadArgument = 0
    Try {
        Do ##class(OcuPilot.Kernel.Shell.SystemInfo).LogSourceFailure("mirror", "")
    } Catch {
        Set tThrewOnBadArgument = 1
    }
    Do $$$AssertEquals(tThrewOnBadArgument, 0, "and a caller with no exception object costs the member, never the response")
}

/// <p><b>Uptime and mirror state are reported exactly once</b> (AC4). Story 15.3's About declines
/// both on the express ground that this panel owns them, so a later change that gave About either
/// back would put two sources on one screen pair with nothing to say which is authoritative.</p>
/// <p>Mutation: add <code>"uptime"</code> to
/// <method>OcuPilot.Kernel.Shell.About.Members</method>, recompile the class and every descendant
/// -- this goes red.</p>
Method TestUptimeAndMirrorAreReportedOnceAcrossTheTwoChromeReads()
{
    Set tAbout = ##class(OcuPilot.Kernel.Shell.About).Members()
    Set tPanel = ##class(OcuPilot.Kernel.Shell.SystemInfo).Members()
    Do $$$AssertEquals($ListFind(tAbout, "uptime"), 0, "About declines the uptime")
    Do $$$AssertEquals($ListFind(tAbout, "mirror"), 0, "and the mirror member")
    Do $$$AssertNotEquals($ListFind(tPanel, "uptime"), 0, "while the panel carries the uptime")
    Do $$$AssertNotEquals($ListFind(tPanel, "mirror"), 0, "and the mirror member")
}

}
