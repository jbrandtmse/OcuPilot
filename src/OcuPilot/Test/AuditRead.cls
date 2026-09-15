/// <p>Four properties of the audit database viewer's read. Three belong to the vendor's query
/// rather than to OcuPilot, and the screen is planned around them: an end time with a zero time
/// part is rolled back to the previous day, the row cap bounds the rows a caller receives and not
/// the population the instance searched, and the query records an audit event of its own. The
/// fourth is OcuPilot's own answer to the first -- a <code>datetime</code> criterion with no time
/// part is refused by name rather than searched on (DW-280).</p>
/// <p>Each runs the shipped descriptor through <method>OcuPilot.Screen.Read.Execute</method> and
/// the real <class>OcuPilot.Port.AdminPort</class>, so what is asserted is what a caller gets
/// rather than what a fixture was told to answer. Needs the screen's three pairs
/// (<code>%Admin_Secure:USE</code>, <code>%Admin_Operate:USE</code>,
/// <code>%DB_IRISSYS:READ</code>), auditing enabled, and audit rows recorded on the instance's own
/// current date -- an install and a sign-in leave both, and each read here adds one of its own.</p>
/// <p><b>No audit row is written deliberately and none is deleted.</b> The rows read back are the
/// ones the vendor records for its own queries, which is the third property below.</p>
Class OcuPilot.Test.AuditRead Extends %UnitTest.TestCase
{

/// <p>The shipped descriptor whose read these tests issue.</p>
Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.AuditList";

/// <p>The event source the vendor records its own audit queries under.</p>
Parameter SELFSOURCE = "%System";

/// <p>The event type the vendor records its own audit queries under.</p>
Parameter SELFTYPE = "%Security";

/// <p>The event name the vendor records its own audit queries under.</p>
Parameter SELFEVENT = "AuditReport";

/// <p>The shipped read's answer for <var>pCriteria</var> at <var>pMaxRows</var>, through the real
/// port. The status is the executor's own, so a refusal is visible to the caller rather than read
/// as an empty result.</p>
Method Answer(ByRef pCriteria, pMaxRows As %Integer, Output pAnswer As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Quit ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, pMaxRows, .pAnswer, .tHttp, .tFault, .pCriteria)
}

/// <p>How many rows that read answers, or <code>-1</code> when it did not succeed -- never 0, so a
/// failed read cannot be read as an empty one.</p>
Method RowCount(ByRef pCriteria, pMaxRows As %Integer, Output pWhy As %String) As %Integer
{
    Set pWhy = ""
    Set tCount = -1
    Set tSC = ..Answer(.pCriteria, pMaxRows, .tAnswer)
    If $$$ISOK(tSC) && $IsObject(tAnswer) {
        Set tCount = tAnswer.rows.%Size()
    } Else {
        ; Named, so an unmet precondition -- a missing pair, a port fault -- is told apart from a
        ; genuinely empty result rather than reported as a product failure.
        Set pWhy = "the read did not succeed: " _ $System.Status.GetErrorText(tSC)
    }
    Quit tCount
}

/// <p>Whether any of the newest audit-query events the vendor recorded for itself names
/// <var>pToken</var> among the parameters it ran with.</p>
/// <p>Read in <code>%SYS</code>, which is the only namespace the audit query answers in at all --
/// the reason the screen declares <code>%DB_IRISSYS:READ</code> and the port runs every endpoint
/// there. This read records an audit event of its own, naming
/// <parameter>SELFEVENT</parameter> and never the caller's token, so it cannot satisfy its own
/// question.</p>
Method SelfAuditNames(pToken As %String) As %Boolean
{
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 25 EventData FROM %SYS.Audit_List(,,?,?,?)", ..#SELFSOURCE, ..#SELFTYPE, ..#SELFEVENT)
        While tRS.%Next() {
            If tRS.%GetData(1) [ pToken Set tFound = 1 Quit
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tFound = 0
    }
    Set $NAMESPACE = tOrigNS
    Quit tFound
}

/// <p>Matrix row "End time at midnight" -- an <code>endDateTime</code> whose time part is zero is
/// rolled back by the vendor to the <b>previous</b> day at 86399.999. An explicit
/// <code>00:00:00</code> is a bound the caller chose and is honoured; a date with no time part at
/// all is refused instead, which is the method below.</p>
/// <p>The explicit-end count is asserted first, as the precondition: without it two reads that
/// both answered nothing would pass for the wrong reason.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Read.SeedCriteria</method> validate without writing
/// into the query -&gt; the midnight bound is never sent, the read answers today's rows, and the
/// second assertion goes red.</p>
Method TestAnEndTimeAtMidnightIsRolledBackToThePreviousDay()
{
    Set tToday = $ZDate($Horolog, 3)

    Kill tCriteria
    Set tCriteria("beginDateTime") = tToday _ " 00:00:00"
    Set tCriteria("endDateTime") = tToday _ " 00:00:00"
    Set tMidnight = ..RowCount(.tCriteria, 5, .tMidnightWhy)

    Kill tCriteria
    Set tCriteria("beginDateTime") = tToday _ " 00:00:00"
    Set tCriteria("endDateTime") = tToday _ " 23:59:59"
    Set tExplicit = ..RowCount(.tCriteria, 5, .tExplicitWhy)

    Do $$$AssertEquals(tMidnightWhy _ tExplicitWhy, "", "both reads completed" _ $Select(tMidnightWhy _ tExplicitWhy = "": "", 1: " -- " _ tMidnightWhy _ " " _ tExplicitWhy))
    Do $$$AssertTrue(tExplicit > 0, "today has rows to find, so the count below is the rollback and not an empty day: " _ tExplicit)
    Do $$$AssertEquals(tMidnight, 0, "an end time with a zero time part rolls the bound back to the previous day and answers none")
}

/// <p>DW-280 -- a bare date reaches <code>$zdatetimeh(EndDateTime,3,...)</code> exactly as an
/// explicit <code>00:00:00</code> does, so without a check it takes the rollback above and drops the
/// whole of the day it names. <method>OcuPilot.Screen.Read.SeedCriteria</method> therefore requires
/// a <code>datetime</code> criterion to carry its time part and refuses a date alone by name, 400
/// <code>READ.CRITERION</code>, before the port is called -- the same shape as the off-list
/// <code>choice</code> refusal, and on the one path both the route and the read tool cross.</p>
/// <p>The served read below is what makes the refusal a refusal rather than a screen that answers
/// 400 to every end bound.</p>
/// <p>Mutation: remove the <code>datetime</code> arm from
/// <method>OcuPilot.Screen.Read.SeedCriteria</method> -&gt; the bare date is seeded, the read
/// succeeds, and the first three assertions go red.</p>
Method TestABareDateEndTimeIsRefusedRatherThanSilentlyDroppingThatDay()
{
    Set tToday = $ZDate($Horolog, 3)

    Kill tCriteria
    Set tCriteria("beginDateTime") = tToday _ " 00:00:00"
    Set tCriteria("endDateTime") = tToday
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 5, .tAnswer, .tHttp, .tFault, .tCriteria)
    Set tCode = $Select($IsObject(tFault): tFault.code, 1: "")
    Set tReason = $Select($IsObject(tFault): tFault.reason, 1: "")
    Do $$$AssertStatusNotOK(tSC, "a bare end date is refused rather than searched on")
    Do $$$AssertEquals(tHttp, 400, "as a bad request")
    Do $$$AssertEquals(tCode, "READ.CRITERION", "on the criterion machine code")
    Do $$$AssertTrue(tReason [ "endDateTime", "naming the criterion the caller sent: " _ tReason)

    Kill tCriteria
    Set tCriteria("beginDateTime") = tToday _ " 00:00:00"
    Set tCriteria("endDateTime") = tToday _ " 23:59:59"
    Set tExplicit = ..RowCount(.tCriteria, 5, .tExplicitWhy)
    Do $$$AssertEquals(tExplicitWhy, "", "the same bound with its time part is served" _ $Select(tExplicitWhy = "": "", 1: " -- " _ tExplicitWhy))
    Do $$$AssertTrue(tExplicit > 0, "and answers today's rows, so the refusal above is the missing time and not an empty day: " _ tExplicit)
}

/// <p>Matrix rows "Cap honoured" and "Vendor cap trap". What is asserted here is the observable
/// half of both: the cap bounds the rows a caller receives, out of a population read back wider
/// than it, and the answer says it was cut.</p>
/// <p>The other half of "Vendor cap trap" -- that the SQL behind the vendor's task is itself
/// unbounded, so the work tracks the <b>matching</b> population and not the cap -- is read from
/// <code>Audit.cls</code>, not observed here: no OcuPilot behaviour changes with it, so no
/// assertion can be written that a bounded vendor query would redden. It is why the thousand-row
/// measurement seeds a matching population of roughly the cap rather than ten times it.</p>
/// <p>Mutation: remove the <code>If tSurviving = tMax Quit</code> guard from
/// <method>OcuPilot.Screen.Read.Execute</method> -&gt; the capped read answers the cap plus one
/// and the exact-cap assertion goes red.</p>
Method TestTheRowCapBoundsTheAnswerAndNotThePopulation()
{
    Kill tCriteria
    Set tWide = ..RowCount(.tCriteria, 50, .tWhy)
    Do $$$AssertEquals(tWhy, "", "the wide read completed" _ $Select(tWhy = "": "", 1: " -- " _ tWhy))
    Do $$$AssertTrue(tWide > 2, "the instance holds more audit rows than the cap asked for below: " _ tWide)

    Set tSC = ..Answer(.tCriteria, 2, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the capped read succeeds")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tAnswer.rows.%Size(), 2, "and answers exactly the cap, out of a population larger than it")
    Do $$$AssertEquals(''tAnswer.truncated, 1, "saying that the answer was cut")
}

/// <p>Matrix row "Self-auditing read" -- the vendor records an audit event of its own for every
/// audit query, unless the caller holds <code>%All</code> and asks it not to, so the viewer appears
/// in its own results. The recorded event names the parameters the query ran with, which is what
/// makes this assertion specific: the token below is unique to this run, reaches the vendor only as
/// a declared criterion, and no read this method issues to look for it can name it.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Read.SeedCriteria</method> validate without writing
/// into the query -&gt; the token never reaches the vendor, the recorded event names
/// <code>*</code> where it would have named the token, and the last assertion goes red.</p>
Method TestTheAuditReadRecordsAnAuditEventOfItsOwn()
{
    Set tToken = "OcuPilotAuditProbe" _ $Job _ $Translate($Piece($ZTimeStamp, ",", 2), ".", "")
    Do $$$AssertEquals(..SelfAuditNames(tToken), 0, "no recorded audit query names this run's token before the read")

    Kill tCriteria
    Set tCriteria("events") = tToken
    Set tRows = ..RowCount(.tCriteria, 1, .tWhy)
    Do $$$AssertEquals(tWhy, "", "the probe read completed" _ $Select(tWhy = "": "", 1: " -- " _ tWhy))
    Do $$$AssertEquals(tRows, 0, "the probe criterion matches no event name, so the read answers none")

    Do $$$AssertEquals(..SelfAuditNames(tToken), 1, "and the read is recorded as an audit event of its own, naming the criterion it ran with")
}

}
