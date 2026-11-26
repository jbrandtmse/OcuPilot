/// <p><class>OcuPilot.Port.SqlPort</class> with the seams of Alternate plans in a test's hands (Story 21.28): <method>PlansVendor</method> and
/// <method>Explained</method> count each call, <method>PlansVendor</method> records its query, plan numbers and text, and a test can arm it to answer
/// <var>Fake</var> rows without calling the instance, to answer an SQLCODE, or to take its time; <method>BoundSeconds</method> answers the bound a test
/// armed. Everything else is the production port's. The state is in <code>^||OcuPilotSqlAlt</code>, which <method>Reset</method> kills.</p>
Class OcuPilot.Test.SqlAlternateFixture Extends OcuPilot.Port.SqlPort
{

/// <p>Kill the fixture's state: the counts, the records and every armed answer.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotSqlAlt
}

/// <p>Answer <var>pPlans</var> possible plans for the list, and one statistics row for each statistics call, without calling the instance.</p>
ClassMethod Fake(pPlans As %Integer)
{
    Set ^||OcuPilotSqlAlt("fake") = pPlans
}

/// <p>Answer <var>pCode</var> and <var>pMessage</var> to every plans call, without calling the instance.</p>
ClassMethod Answer(pCode As %Integer, pMessage As %String = "probe")
{
    Set ^||OcuPilotSqlAlt("code") = pCode
    Set ^||OcuPilotSqlAlt("message") = pMessage
}

/// <p>Answer <var>pCode</var> only to the statistics call.</p>
ClassMethod AnswerStats(pCode As %Integer, pMessage As %String = "probe")
{
    Set ^||OcuPilotSqlAlt("statscode") = pCode
    Set ^||OcuPilotSqlAlt("message") = pMessage
}

/// <p>Take <var>pSeconds</var> more after each statistics call, and answer <var>pBound</var> as the bound.</p>
ClassMethod Slow(pSeconds As %Double, pBound As %Integer)
{
    Set ^||OcuPilotSqlAlt("hang") = pSeconds
    Set ^||OcuPilotSqlAlt("bound") = pBound
}

/// <p>How many plans calls the port made, and how many of them were the list and the statistics query.</p>
ClassMethod Calls() As %Integer
{
    Quit +$Get(^||OcuPilotSqlAlt("calls"))
}

ClassMethod Lists() As %Integer
{
    Quit +$Get(^||OcuPilotSqlAlt("list"))
}

ClassMethod Stats() As %Integer
{
    Quit +$Get(^||OcuPilotSqlAlt("stats"))
}

/// <p>How many plan texts were read through <code>Explain</code> with plan numbers, and how many in all.</p>
ClassMethod Explains() As %Integer
{
    Quit +$Get(^||OcuPilotSqlAlt("explained"))
}

/// <p>The query, plan numbers and text of the plans call number <var>pNumber</var>, as the port passed them.</p>
ClassMethod Call(pNumber As %Integer) As %String
{
    Quit $Get(^||OcuPilotSqlAlt("calls", pNumber))
}

ClassMethod BoundSeconds() As %Integer
{
    Quit $Get(^||OcuPilotSqlAlt("bound"), ##super())
}

ClassMethod PlansVendor(pNamespace As %String, pQuery As %String, pText As %String, pIds As %String, Output pRows As %DynamicArray, Output pCode As %Integer, Output pMessage As %String) As %Status [ Private ]
{
    Set tNumber = $Increment(^||OcuPilotSqlAlt("calls"))
    Set ^||OcuPilotSqlAlt("calls", tNumber) = pQuery _ "|" _ pIds _ "|" _ pText
    Set tStats = (pQuery = ..#ALTSTATSQUERY)
    If tStats {
        Set tIgnored = $Increment(^||OcuPilotSqlAlt("stats"))
    } Else {
        Set tIgnored = $Increment(^||OcuPilotSqlAlt("list"))
    }
    Set pRows = []
    Set pCode = 0
    Set pMessage = ""
    If $Data(^||OcuPilotSqlAlt("code")) || (tStats && $Data(^||OcuPilotSqlAlt("statscode"))) {
        Set pCode = $Select(tStats && $Data(^||OcuPilotSqlAlt("statscode")): ^||OcuPilotSqlAlt("statscode"), 1: ^||OcuPilotSqlAlt("code"))
        Set pMessage = $Get(^||OcuPilotSqlAlt("message"))
        Quit $$$OK
    }
    If +$Get(^||OcuPilotSqlAlt("fake")) {
        If tStats {
            Do pRows.%Push([(pIds), "10.5", "master map", "7", "1,368", "0.000049", "400,000", "Plan"])
        } Else {
            For tI = 1:1:^||OcuPilotSqlAlt("fake") Do pRows.%Push([(tI), "10.5", "master map ", "OcuProbe228.T.IDKEY", "Plan"])
        }
        Quit $$$OK
    }
    Set tSC = ##super(pNamespace, pQuery, pText, pIds, .pRows, .pCode, .pMessage)
    Set tHang = +$Get(^||OcuPilotSqlAlt("hang"))
    If tStats && (tHang > 0) Hang tHang
    Quit tSC
}

ClassMethod Explained(pNamespace As %String, pText As %String, Output pPlan As %String, Output pCode As %String, Output pMessage As %String, pStats As %Boolean = 0, pBound As %Integer = 0, Output pStopped As %Boolean, pIds As %String = "") As %Status [ Private ]
{
    Set ^||OcuPilotSqlAlt("explained") = $Get(^||OcuPilotSqlAlt("explained")) + 1
    Quit ##super(pNamespace, pText, .pPlan, .pCode, .pMessage, pStats, pBound, .pStopped, pIds)
}

}
