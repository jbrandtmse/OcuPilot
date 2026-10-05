/// <p><class>OcuPilot.Port.SqlActivityPort</class> with its seams armed from
/// <code>^||OcuPilotSqlActivitySeam</code>, so <class>OcuPilot.Test.SqlActivityPort</class> can drive
/// a denial, another instance's server, a namespace's database resources, a vendor text and a vendor
/// fault in process: <method>Arm</method> sets one node, <method>Clear</method> forgets them all. An
/// unarmed seam behaves as the shipped port, and every call to <method>Rows</method> and
/// <method>Text</method> and every log line is counted.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SqlActivitySeam Extends OcuPilot.Port.SqlActivityPort
{

/// <p>Arm node <var>pKey</var> with <var>pValue</var>: <code>gate</code> 1 evaluates the pairs through
/// <class>OcuPilot.Test.ScreenGate</class>; <code>local</code> is the server
/// <method>LocalServer</method> answers; <code>resources</code> is the <code>routine,global</code>
/// pair <method>Resources</method> answers for every namespace not armed by <method>ArmFor</method>;
/// <code>text</code> is the text <method>Text</method> answers, <code>status</code> the status it
/// answers with, and <code>throw</code> 1 makes it throw.</p>
ClassMethod Arm(pKey As %String, pValue As %String)
{
    Set ^||OcuPilotSqlActivitySeam(pKey) = pValue
}

/// <p>Arm node <var>pKey</var> for <var>pSubscript</var> alone: <code>resources</code> for one
/// namespace.</p>
ClassMethod ArmFor(pKey As %String, pSubscript As %String, pValue As %String)
{
    Set ^||OcuPilotSqlActivitySeam(pKey, pSubscript) = pValue
}

/// <p>Forget every armed node and count.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotSqlActivitySeam
}

/// <p>How many times <var>pKey</var> (<code>rows</code>, <code>text</code> or <code>log</code>) was
/// counted since <method>Clear</method>.</p>
ClassMethod Count(pKey As %String) As %Integer
{
    Quit +$Get(^||OcuPilotSqlActivitySeam("count", pKey))
}

/// <p>The code of log line <var>pIndex</var>, in the order written.</p>
ClassMethod LoggedCode(pIndex As %Integer) As %String
{
    Quit $Get(^||OcuPilotSqlActivitySeam("log", pIndex))
}

/// <p>The status text of log line <var>pIndex</var>, in the order written.</p>
ClassMethod LoggedText(pIndex As %Integer) As %String
{
    Quit $Get(^||OcuPilotSqlActivitySeam("logtext", pIndex))
}

/// <p>The port's statement-text pre-check for <var>pNamespace</var>, exposed for a test.</p>
ClassMethod MayRead(pNamespace As %String) As %Boolean
{
    Quit ..MayReadText(pNamespace)
}

ClassMethod GateClass() As %String
{
    If $Get(^||OcuPilotSqlActivitySeam("gate")) Quit "OcuPilot.Test.ScreenGate"
    Quit ##super()
}

ClassMethod LocalServer() As %String
{
    If $Data(^||OcuPilotSqlActivitySeam("local")) Quit ^||OcuPilotSqlActivitySeam("local")
    Quit ##super()
}

ClassMethod Resources(pNamespace As %String, Output pRoutine As %String, Output pGlobal As %String) [ Private ]
{
    If $Data(^||OcuPilotSqlActivitySeam("resources", pNamespace)) # 2 {
        Set tArmed = ^||OcuPilotSqlActivitySeam("resources", pNamespace)
    } ElseIf $Data(^||OcuPilotSqlActivitySeam("resources")) # 2 {
        Set tArmed = ^||OcuPilotSqlActivitySeam("resources")
    } Else {
        Do ##super(pNamespace, .pRoutine, .pGlobal)
        Quit
    }
    Set pRoutine = $Piece(tArmed, ",", 1)
    Set pGlobal = $Piece(tArmed, ",", 2)
}

ClassMethod Rows(pMax As %Integer, Output pRows As %DynamicArray) As %Status [ Private ]
{
    Do $Increment(^||OcuPilotSqlActivitySeam("count", "rows"))
    Quit ##super(pMax, .pRows)
}

ClassMethod Text(pNamespace As %String, pHash As %String, Output pStatus As %Status) As %String [ Private ]
{
    Do $Increment(^||OcuPilotSqlActivitySeam("count", "text"))
    If $Get(^||OcuPilotSqlActivitySeam("throw")) Throw ##class(%Exception.General).%New("OcuVendorThrow1910")
    If '$Data(^||OcuPilotSqlActivitySeam("text")) && '$Data(^||OcuPilotSqlActivitySeam("status")) Quit ##super(pNamespace, pHash, .pStatus)
    Set pStatus = $Get(^||OcuPilotSqlActivitySeam("status"), $$$OK)
    Quit $Get(^||OcuPilotSqlActivitySeam("text"))
}

/// <p>Record the line's code and status text in place of writing them to the log.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set tIndex = $Increment(^||OcuPilotSqlActivitySeam("count", "log"))
    Set ^||OcuPilotSqlActivitySeam("log", tIndex) = pCode
    Set ^||OcuPilotSqlActivitySeam("logtext", tIndex) = $System.Status.GetErrorText(pStatus)
}

}
