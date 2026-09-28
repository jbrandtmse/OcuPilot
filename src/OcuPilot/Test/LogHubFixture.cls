/// <p>Subclass of <class>OcuPilot.Screen.Timeline</class> overriding only its four seams, so
/// <class>OcuPilot.Test.LogHub</class> drives the real composition -- projection, window, merge, cut
/// and per-source summary -- against member rows it arms. It never reads a member: an unarmed
/// member answers no rows.</p>
/// <p>Every gate and read is counted, in total and per member, which is how "read zero times" and
/// "before any member is read" are observed. State lives in <code>^||OcuPilotLogHubFixture</code>;
/// <method>Clear</method> forgets it.</p>
Class OcuPilot.Test.LogHubFixture Extends OcuPilot.Screen.Timeline
{

/// <p>Forget every armed row, refusal and count.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotLogHubFixture
}

/// <p>Refuse member <var>pDescriptor</var> at its gate, naming <var>pPair</var>.</p>
ClassMethod Deny(pDescriptor As %String, pPair As %String)
{
    Set ^||OcuPilotLogHubFixture("deny", pDescriptor) = pPair
}

/// <p>Arm member <var>pDescriptor</var>'s read to answer <var>pRows</var>, in that member's own row
/// shape, cut when <var>pTruncated</var>.</p>
ClassMethod Arm(pDescriptor As %String, pRows As %DynamicArray, pTruncated As %Boolean = 0)
{
    Set ^||OcuPilotLogHubFixture("rows", pDescriptor) = pRows.%ToJSON()
    Set ^||OcuPilotLogHubFixture("cut", pDescriptor) = ''pTruncated
}

/// <p>Arm member <var>pDescriptor</var>'s newest row whatever the bound, <var>pRow</var> in that
/// member's own row shape, which <method>LastMember</method> answers.</p>
ClassMethod ArmLast(pDescriptor As %String, pRow As %DynamicObject)
{
    Set ^||OcuPilotLogHubFixture("last", pDescriptor) = pRow.%ToJSON()
}

/// <p>Make member <var>pDescriptor</var>'s read fail with <var>pHttp</var> and <var>pCode</var>,
/// naming <var>pPair</var> as <code>detail.failedPair</code> when there is one.</p>
ClassMethod Fault(pDescriptor As %String, pHttp As %Integer, pCode As %String, pPair As %String = "")
{
    Set ^||OcuPilotLogHubFixture("fault", pDescriptor) = $ListBuild(pHttp, pCode, pPair)
}

/// <p>Answer <method>LocalTime</method> as UTC shifted forward by <var>pSeconds</var> (zero or more), so an audit row's
/// conversion is observable whatever zone the instance runs in.</p>
ClassMethod Offset(pSeconds As %Integer)
{
    Set ^||OcuPilotLogHubFixture("offset") = pSeconds
}

/// <p>How many member reads were issued, for <var>pDescriptor</var> or in total.</p>
ClassMethod Reads(pDescriptor As %String = "") As %Integer
{
    If pDescriptor = "" Quit +$Get(^||OcuPilotLogHubFixture("reads"))
    Quit +$Get(^||OcuPilotLogHubFixture("readsFor", pDescriptor))
}

/// <p>How many times <var>pDescriptor</var>'s newest row whatever the bound was asked for.</p>
ClassMethod LastReads(pDescriptor As %String) As %Integer
{
    Quit +$Get(^||OcuPilotLogHubFixture("lastReads", pDescriptor))
}

/// <p>How many member gates were asked.</p>
ClassMethod Gates() As %Integer
{
    Quit +$Get(^||OcuPilotLogHubFixture("gates"))
}

/// <p>The row cap the last read of <var>pDescriptor</var> was given.</p>
ClassMethod MaxFor(pDescriptor As %String) As %String
{
    Quit $Get(^||OcuPilotLogHubFixture("max", pDescriptor))
}

/// <p>The bound the last read of <var>pDescriptor</var> was given.</p>
ClassMethod SinceFor(pDescriptor As %String) As %String
{
    Quit $Get(^||OcuPilotLogHubFixture("since", pDescriptor))
}

ClassMethod LocalTime(pUtc As %String) As %String
{
    If '$Data(^||OcuPilotLogHubFixture("offset")) Quit ##super(pUtc)
    Set tAt = $ZDateTimeH($Extract(pUtc, 1, 19), 3)
    Set tSeconds = $Piece(tAt, ",", 2) + ^||OcuPilotLogHubFixture("offset")
    Set tDays = +tAt + (tSeconds \ 86400)
    Set tSeconds = tSeconds # 86400
    Set tFraction = $Extract(pUtc, 21, 23)
    Quit $Translate($ZDateTime(tDays _ "," _ tSeconds, 3), " ", "T") _ "." _ $Select(tFraction = "": "000", 1: tFraction)
}

ClassMethod GateMember(pDescriptor As %String, Output pFailedPair As %String) As %Boolean
{
    Set ^||OcuPilotLogHubFixture("gates") = $Get(^||OcuPilotLogHubFixture("gates")) + 1
    Set pFailedPair = $Get(^||OcuPilotLogHubFixture("deny", pDescriptor))
    Quit pFailedPair = ""
}

ClassMethod ReadMember(pDescriptor As %String, pKind As %String, pMaxRows As %Integer, pSince As %String, Output pRows As %DynamicArray, Output pTruncated As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set ^||OcuPilotLogHubFixture("reads") = $Get(^||OcuPilotLogHubFixture("reads")) + 1
    Set ^||OcuPilotLogHubFixture("readsFor", pDescriptor) = $Get(^||OcuPilotLogHubFixture("readsFor", pDescriptor)) + 1
    Set ^||OcuPilotLogHubFixture("since", pDescriptor) = pSince
    Set ^||OcuPilotLogHubFixture("max", pDescriptor) = pMaxRows
    Set pRows = []
    Set pTruncated = 0
    Set pHttpStatus = 200
    Set pFault = ""
    Set tFault = $Get(^||OcuPilotLogHubFixture("fault", pDescriptor))
    If tFault '= "" {
        Set pRows = ""
        Set pHttpStatus = $List(tFault, 1)
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build("server_error", $List(tFault, 2), "armed by the fixture")
        If $List(tFault, 3) '= "" Do pFault.%Set("detail", {"failedPair": ($List(tFault, 3))})
        Quit $$$ERROR($$$GeneralError, $List(tFault, 2) _ ": armed by the fixture")
    }
    Set tJson = $Get(^||OcuPilotLogHubFixture("rows", pDescriptor))
    If tJson '= "" Set pRows = ##class(%DynamicArray).%FromJSON(tJson)
    Set pTruncated = +$Get(^||OcuPilotLogHubFixture("cut", pDescriptor))
    Quit $$$OK
}

ClassMethod LastMember(pDescriptor As %String, pKind As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set ^||OcuPilotLogHubFixture("lastReads", pDescriptor) = $Get(^||OcuPilotLogHubFixture("lastReads", pDescriptor)) + 1
    Set pRow = ""
    Set pHttpStatus = 200
    Set pFault = ""
    Set tJson = $Get(^||OcuPilotLogHubFixture("last", pDescriptor))
    If tJson '= "" Set pRow = ##class(%DynamicObject).%FromJSON(tJson)
    Quit $$$OK
}

}
