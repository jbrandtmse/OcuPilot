/// <p>Story 16.9 (AD-48) -- one application error seeded in HSCUSTOM through
/// <method>OcuPilot.Test.ErrorLogSeed.SeedInto</method> reads through
/// <method>OcuPilot.Port.LogSourcePort.RecentErrors</method> and the log hub in the hub's form: its
/// date and time as <code>YYYY-MM-DDTHH:MM:SS.000</code>, severity 2, its summary text led by
/// <code>[HSCUSTOM] </code>, and its composite id over the namespace, <code>DateList</code>'s own
/// date and the error number. A second seed, and a stand-in seeded in USER after it, pin the cap
/// and its cut, a bound after every error still answers the newest one as the hub's last entry, and
/// a namespace whose own pairs fail is left out unread.</p>
/// <p>It writes to <code>^ERRORS</code> in HSCUSTOM and USER and deletes what it wrote in
/// <method>OnAfterOneTest</method>; it runs only where <parameter>ARMINGVARIABLE</parameter> reads
/// 1 -- a <file>scripts/ci-throwaway.sh</file> container.</p>
Class OcuPilot.Test.LogHubErrors Extends %UnitTest.TestCase
{

/// <p>The variable that arms this class: it writes an application error, as
/// <class>OcuPilot.Test.ErrorLogSeed</class> does.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ERROR_SEED";

/// <p>The namespace the error is seeded in.</p>
Parameter NAMESPACE = "HSCUSTOM";

/// <p>The errors this test seeded, as <code>$ListBuild(namespace, day, number)</code> entries, which
/// <method>OnAfterOneTest</method> deletes.</p>
Property PreparedSeeds As %List;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedSeeds = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LogHubErrors writes an application error to this instance's own ^ERRORS and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>The seeded entry reads the same through the port's newest-errors reader and the hub.</p>
/// <p>Mutation (Rule 19): drop the <code>[NS] </code> prefix in
/// <method>OcuPilot.Port.LogSourcePort.RecentErrors</method> -&gt; the text assertions go red; read no
/// date before the bound -&gt; the last-entry assertions go red.</p>
Method TestASeededErrorReadsInTheHubsForm()
{
    Set tSC = ##class(OcuPilot.Test.ErrorLogSeed).SeedInto(..#NAMESPACE, .tDay, .tNumber)
    Do $$$AssertStatusOK(tSC, "an application error is seeded")
    If $$$ISERR(tSC) Quit
    Do ..Track(..#NAMESPACE, tDay, tNumber)

    Set tSC = ##class(OcuPilot.Port.LogSourcePort).Errors("dates", ..#NAMESPACE, "", "", "", .tDates, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the namespace's dates read")
    Set tDate = ""
    Set tIterator = tDates.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $ZDateH(tRow.date, 1, , , , , , , "") = tDay Set tDate = tRow.date
    }
    Do $$$AssertTrue(tDate '= "", "the seed's day is one DateList answers: " _ tDate)
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).Errors("list", ..#NAMESPACE, tDate, "", "", .tList, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "that date's errors read")
    Set tEntry = ""
    Set tIterator = tList.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.errorNumber = tNumber Set tEntry = tRow
    }
    Do $$$AssertTrue($IsObject(tEntry), "the seeded entry is listed")
    If '$IsObject(tEntry) Quit
    Set tTime = $ZDate(tDay, 3) _ "T" _ tEntry.time _ ".000"
    Set tText = "[" _ ..#NAMESPACE _ "] " _ tEntry.errorText
    Set tSince = $ZDate(tDay, 3) _ " 00:00:00"

    Set tSC = ##class(OcuPilot.Port.LogSourcePort).RecentErrors(1000, tSince, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the newest errors read")
    Set tFound = ""
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.namespace = ..#NAMESPACE) && (tRow.date = tDate) && (tRow.errorNumber = tNumber) Set tFound = tRow
    }
    Do $$$AssertTrue($IsObject(tFound), "RecentErrors carries the seeded entry")
    If $IsObject(tFound) Do $$$AssertEquals(tFound.time _ "|" _ tFound.severity _ "|" _ tFound.text, tTime _ "|2|" _ tText, "in the hub's time form, at severity 2, led by its namespace")

    Kill tCriteria
    Set tCriteria("since") = tSince
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.LogHub", 1000, .tHub, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the hub reads")
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#NAMESPACE, tDate, tNumber))
    Set tHubRow = ""
    Set tIterator = tHub.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.source = "logs/errors") && (tRow.id = tId) Set tHubRow = tRow
    }
    Do $$$AssertTrue($IsObject(tHubRow), "the hub's timeline carries it under its composite id")
    If $IsObject(tHubRow) Do $$$AssertEquals(tHubRow.time _ "|" _ tHubRow.severity _ "|" _ tHubRow.text, tTime _ "|2|" _ tText, "the same time, severity and text")

    ; The cap: a second seed, a second after the first, puts two errors in the window, so a cap
    ; of one answers a row no older than the second seed's alone and says it cut, and a cap above
    ; every error cuts nothing. A later error in any namespace may take the row, so the read is
    ; compared with the second seed's own time, and a stand-in seeded in USER after the full read
    ; keeps the newer-row case in every run.
    Hang 1
    Set tSC = ##class(OcuPilot.Test.ErrorLogSeed).SeedInto(..#NAMESPACE, .tDay2, .tNumber2)
    Do $$$AssertStatusOK(tSC, "a second application error is seeded")
    If $$$ISERR(tSC) Quit
    Do ..Track(..#NAMESPACE, tDay2, tNumber2)
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).RecentErrors(100000, tSince, .tAll, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "every error in the window reads")
    Set tSecondTime = ""
    If $IsObject($Get(tAll)) {
        Do $$$AssertEquals(tAll.truncated, 0, "a cap above every error cuts nothing")
        Set tIterator = tAll.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If (tRow.namespace = ..#NAMESPACE) && (tRow.errorNumber = tNumber2) && ($ZDateH(tRow.date, 1, , , , , , , "") = tDay2) Set tSecondTime = tRow.time
        }
    }
    Do $$$AssertTrue(tSecondTime '= "", "the full read carries the second seed under its own error number")
    Hang 1.1
    Set tSC = ##class(OcuPilot.Test.ErrorLogSeed).SeedInto("USER", .tDay3, .tNumber3)
    Do $$$AssertStatusOK(tSC, "a stand-in error, newer than the second seed, is seeded in USER")
    If $$$ISOK(tSC) Do ..Track("USER", tDay3, tNumber3)
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).RecentErrors(1, tSince, .tOne, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a cap of one reads")
    If $IsObject($Get(tOne)) && (tSecondTime '= "") {
        Set tOneTime = $Select(tOne.rows.%Size() > 0: tOne.rows.%Get(0).time, 1: "")
        Do $$$AssertEquals(tOne.rows.%Size() _ "|" _ tOne.truncated _ "|" _ ('(tSecondTime ] tOneTime) && (tOneTime '= "")), "1|1|1", "one row, no older than the second seed's, and the read says it cut: " _ tOneTime _ " against " _ tSecondTime)
    }

    ; A bound after every error still answers each namespace's newest date, so the error log's last
    ; entry is its newest whatever the window, while the timeline holds none of it (AD-36).
    Set tTomorrow = $ZDate(tDay + 1, 3) _ " 00:00:00"
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).RecentErrors(1000, tTomorrow, .tLater, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a bound after every error reads")
    Set tSeen = 0
    If $IsObject($Get(tLater)) {
        Set tIterator = tLater.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If (tRow.namespace = ..#NAMESPACE) && (tRow.errorNumber = tNumber2) Set tSeen = 1
        }
    }
    Do $$$AssertEquals(tSeen, 1, "the namespace's newest date is read though it is before the bound")
    Kill tCriteria
    Set tCriteria("since") = tTomorrow
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.LogHub", 1000, .tLaterHub, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the hub reads with that bound")
    Set tErrors = ""
    If $IsObject($Get(tLaterHub)) {
        Set tIterator = tLaterHub.sources.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tSource) {
            If tSource.source = "logs/errors" Set tErrors = tSource
        }
    }
    Do $$$AssertTrue($IsObject(tErrors) && $IsObject(tErrors.last), "the error log's summary carries a last entry")
    If $IsObject(tErrors) && $IsObject(tErrors.last) Do $$$AssertEquals(tErrors.count _ "|" _ $Extract(tErrors.last.time, 1, 10), "0|" _ $ZDate(tDay, 3), "today's newest error, outside the window, with no entry counted")

    ; A namespace whose own pairs the caller does not hold is left out unread, and that is not a
    ; fault (AD-48). The in-process gate is the test gate, since %UnitTest holds %All.
    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogSourceFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.LogSourceFixture).SetNamespacePairs("applicationerrors", ..#NAMESPACE, "%Admin_Operate:USE,OcuPilotNeverHeld:USE")
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).RecentErrors(1000, tSince, .tRefused, .tHttp, .tFault)
    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $$$AssertStatusOK(tSC, "a namespace the caller may not read is not a fault")
    Do $$$AssertEquals(tHttp, 200, "the read answers 200")
    Set tLeft = 0
    If $IsObject($Get(tRefused)) {
        Set tIterator = tRefused.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.namespace = ..#NAMESPACE Set tLeft = tLeft + 1
        }
    }
    Do $$$AssertEquals(tLeft, 0, "and none of that namespace's errors are read")
}

/// <p>Record an error this test seeded, so <method>OnAfterOneTest</method> deletes it.</p>
Method Track(pNamespace As %String, pDay As %Integer, pNumber As %Integer)
{
    Set ..PreparedSeeds = ..PreparedSeeds _ $ListBuild($ListBuild(pNamespace, pDay, pNumber))
}

/// <p>Delete every error this test seeded through the vendor's own delete, and assert that none
/// remains.</p>
Method OnAfterOneTest() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tDeleted = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(..PreparedSeeds) {
            Set tSeed = $List(..PreparedSeeds, tI)
            Set tDeleted = $$$ADDSC(tDeleted, ##class(SYS.ApplicationError).DeleteByError($List(tSeed, 1), $ZDate($List(tSeed, 2), 1), $List(tSeed, 3)))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tDeleted = $$$ADDSC(tDeleted, ex.AsStatus())
    }
    Do $$$AssertStatusOK(tDeleted, "the seeded errors are deleted")
    For tI = 1:1:$ListLength(..PreparedSeeds) {
        Set tSeed = $List(..PreparedSeeds, tI)
        Set tSC = ##class(OcuPilot.Test.ErrorLogSeed).Read("list", $List(tSeed, 1), $ZDate($List(tSeed, 2), 1), "", .tList, .tStatus, .tFault)
        Set tLeft = 0
        ; A day with no errors left answers 404; any other answer than 200 or 404 is a refused read.
        Do $$$AssertTrue(($Get(tStatus) = 200) || ($Get(tStatus) = 404), "the day of the seeded error " _ $List(tSeed, 1) _ " #" _ $List(tSeed, 3) _ " reads back as its rows or as a day with none: " _ $Get(tStatus))
        If $$$ISOK(tSC) && $IsObject($Get(tList)) {
            Set tIterator = tList.rows.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If tRow.errorNumber = $List(tSeed, 3) Set tLeft = tLeft + 1
            }
        }
        Do $$$AssertEquals(tLeft, 0, "the seeded error " _ $List(tSeed, 1) _ " #" _ $List(tSeed, 3) _ " is gone")
    }
    Set ..PreparedSeeds = ""
    Quit $$$OK
}
}
