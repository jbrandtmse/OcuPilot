Include %msql

/// <p>Pins that <method>OcuPilot.Port.AdminPort.Invoke</method> answers a class-query list after the instance's SQL
/// compile context version has advanced past this process's context: the first uncached read afterwards answers 200
/// with its rows, where the vendor's class-query prepare alone fails once with SQLCODE -428 (DW-2646).</p>
/// <p>Runs through <class>OcuPilot.Test.PortFixture</class> with no endpoint override, so the vendor sequence is the
/// production one. Needs <code>%Admin_Task:U</code> and <code>%DB_IRISSYS:RW</code>, since it writes the version
/// global. <b>It advances the version and purges <code>%SYS</code>'s cached queries</b>, which is what any SQL settings
/// save does to the instance; <class>%UnitTest.Manager</class> puts the version back when the run closes.</p>
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
    Do $$$AssertTrue($IsObject(tFirst) && tFirst.%IsA("%Library.DynamicArray"), "and answers a rows array")
    ; Another process's Config.SQL activation advances the instance-wide version; this process's context is now stale.
    Do $Increment($$$SYSTEMContextGlo("SQLCompile"))
    Do $$$AssertNotEquals($SYSTEM.Context.SQLCompile().Version, $Get($$$SYSTEMContextGlo("SQLCompile")), "this process's context is now older than the instance's version")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tPurgeSC = $SYSTEM.SQL.PurgeQueries()
        Set $NAMESPACE = tOrigNS
    } Catch tEx {
        Set $NAMESPACE = tOrigNS
        Set tPurgeSC = tEx.AsStatus()
    }
    Do $$$AssertStatusOK(tPurgeSC, "the cached queries of %SYS are purged, so the next prepare compiles")
    Set tSC = ##class(OcuPilot.Test.PortFixture).Invoke("Task.CRUD", "UPCOMING", , , .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read after the change succeeds")
    Do $$$AssertEquals(tHttp, 200, "and answers 200, not 500 INTERNAL")
    Do $$$AssertTrue($IsObject(tResult) && tResult.%IsA("%Library.DynamicArray"), "and answers a rows array")
}

}
