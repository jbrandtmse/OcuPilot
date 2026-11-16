Include %msql

/// <p>Pins that <method>OcuPilot.Port.AdminPort.Invoke</method> answers a class-query list after the instance's SQL
/// compile context version has advanced past this process's context: the first uncached read afterwards answers 200
/// with its rows, where the vendor's class-query prepare alone fails once with SQLCODE -428 (DW-2646).</p>
/// <p>Runs through <class>OcuPilot.Test.PortFixture</class> with no endpoint override, so the vendor sequence is the
/// production one. Needs <code>%Admin_Secure:U</code> and <code>%DB_IRISSYS:R</code>. <b>It leaves the version
/// advanced and <code>%SYS</code>'s cached queries purged</b>, which is what any SQL settings save does to the
/// instance.</p>
Class OcuPilot.Test.AdminPortCompileContext Extends %UnitTest.TestCase
{

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Quit $$$OK
}

/// <p>A scheduled-occurrence list read after another process's SQL settings change answers 200 and its rows on the
/// first try.</p>
/// <p>Mutation: remove the <code>Do ..RefreshCompileContext()</code> call from
/// <method>OcuPilot.Port.AdminPort.InvokeLocated</method> -&gt; the second read answers 500 and the status and rows
/// assertions go red.</p>
Method TestAnUpcomingTasksReadSurvivesASqlSettingsChange()
{
    Set tFirstSC = ##class(OcuPilot.Test.PortFixture).Invoke("Task.CRUD", "UPCOMING", , , .tFirst, .tFirstHttp, .tFirstFault)
    Do $$$AssertStatusOK(tFirstSC, "the first read, which creates this process's context and caches the query, succeeds")
    Do $$$AssertEquals(tFirstHttp, 200, "and answers 200")
    ; Another process's Config.SQL activation advances the instance-wide version; this process's context is now stale.
    Do $Increment($$$SYSTEMContextGlo("SQLCompile"))
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tPurgeSC = $SYSTEM.SQL.PurgeQueries()
    } Catch tEx {
        Set tPurgeSC = tEx.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Do $$$AssertStatusOK(tPurgeSC, "the cached queries of %SYS are purged, so the next prepare compiles")
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("Task.CRUD", "UPCOMING", , , .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read after the change succeeds")
    Do $$$AssertEquals(tHttp, 200, "and answers 200, not 500 INTERNAL")
    Do $$$AssertTrue($IsObject(tResult) && tResult.%IsA("%Library.DynamicArray"), "and answers a rows array")
}

}
