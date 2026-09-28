/// <p>The log hub's composed read (AD-36 as amended, Story 16.9): each listed screen of the area,
/// other than the hub, read through its own gate and its own read in side-bar order, in the
/// caller's process, projected to <code>{time, source, severity, text, id}</code> on the instance's
/// clock, windowed by one bound and merged newest first.</p>
/// <p><b>Members are the registry's, never a caller's</b> (AD-21): <method>Members</method> derives
/// them from the area's listed built screens, and the read's only inputs are the cap and the
/// bound. A member the caller may not read is left out and named with its failed pair; any other
/// member fault fails the whole read (AD-36).</p>
/// <p>Seams a test subclass overrides (<class>OcuPilot.Test.LogHubFixture</class>):
/// <method>GateMember</method>, <method>ReadMember</method> and <method>LocalTime</method>.
/// Production overrides none.</p>
Class OcuPilot.Screen.Timeline Extends %RegisteredObject
{

/// <p>The criterion a member's read is given the bound under, where it declares one: the audit
/// viewer's begin.</p>
Parameter BEGINPARAM = "beginDateTime";

/// <p>The most characters a source's <code>last</code> entry carries in its text, a cut one ending
/// U+2026.</p>
Parameter LASTTEXTMAX As INTEGER = 1000;

/// <p>The one member that declares no read: the application error log, read through
/// <method>OcuPilot.Port.LogSourcePort.RecentErrors</method> behind its own gate.</p>
Parameter ERRORSDESCRIPTOR = "OcuPilot.Screen.Descriptor.LogErrorList";

/// <p>A member read through a <code>logsource</code> declared read, projected as read.</p>
Parameter KINDLOG = "log";

/// <p>A member read through the audit record LIST (AD-2, AD-27), projected from its UTC stamp.</p>
Parameter KINDAUDIT = "audit";

/// <p>The application error log.</p>
Parameter KINDERRORS = "errors";

/// <p><var>pArea</var>'s members in side-bar order, as a <code>%List</code> of descriptor classes:
/// its listed built screens (<code>sideBarPosition</code> above 0) whose own read is not a
/// timeline.</p>
ClassMethod Members(pArea As %String, Output pMembers As %List) As %Status
{
    Set tSC = $$$OK
    Set pMembers = ""
    Try {
        Set tSC = ##class(OcuPilot.Screen.Registry).ScreensForArea(pArea, 1, .tList)
        If $$$ISERR(tSC) Quit
        For tI = 1:1:$ListLength(tList) {
            Set tClass = $List(tList, tI)
            If +$ClassMethod(tClass, "SideBarPosition") < 1 Continue
            If ..IsTimeline(tClass) Continue
            Set pMembers = pMembers _ $ListBuild(tClass)
        }
    } Catch ex {
        Set pMembers = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pDescriptor</var> declares a timeline read.</p>
ClassMethod IsTimeline(pDescriptor As %String) As %Boolean
{
    Set tRead = $ClassMethod(pDescriptor, "Read")
    If '$IsObject(tRead) || (tRead.%GetTypeOf("source") '= "object") Quit 0
    Quit tRead.source.%Get("port") = ##class(OcuPilot.Screen.Read).#SOURCETIMELINE
}

/// <p>How member <var>pDescriptor</var> is read and projected: <parameter>KINDLOG</parameter>,
/// <parameter>KINDAUDIT</parameter>, <parameter>KINDERRORS</parameter>, or <code>""</code> for a
/// member this read cannot compose, which fails the read.</p>
ClassMethod MemberKind(pDescriptor As %String) As %String
{
    Set tRead = $ClassMethod(pDescriptor, "Read")
    If '$IsObject(tRead) Quit $Select(pDescriptor = ..#ERRORSDESCRIPTOR: ..#KINDERRORS, 1: "")
    Set tSource = tRead.%Get("source")
    If '$IsObject(tSource) Quit ""
    If tSource.%Get("port") = ##class(OcuPilot.Screen.Read).#SOURCELOGSOURCE Quit ..#KINDLOG
    If (tSource.%Get("port") = ##class(OcuPilot.Screen.Read).#SOURCEADMIN) && (tSource.%Get("endpoint") = ##class(OcuPilot.Port.AuditPort).#RECORDENDPOINT) Quit ..#KINDAUDIT
    Quit ""
}

/// <p>Whether the calling process may read member <var>pDescriptor</var>: that screen's own gate,
/// its classic page's custom resource included (AD-8, AD-44). <var>pFailedPair</var> names the
/// first pair that failed.</p>
ClassMethod GateMember(pDescriptor As %String, Output pFailedPair As %String) As %Boolean
{
    Quit ##class(OcuPilot.Screen.Gate).Evaluate(pDescriptor, .pFailedPair)
}

/// <p>Member <var>pDescriptor</var>'s own read at <var>pMaxRows</var>, as its own rows
/// (<var>pRows</var>) and its own cut (<var>pTruncated</var>). A <parameter>KINDERRORS</parameter>
/// member is read through <method>OcuPilot.Port.LogSourcePort.RecentErrors</method>; every other
/// through <method>OcuPilot.Screen.Read.Execute</method>, given <var>pSince</var> as
/// <parameter>BEGINPARAM</parameter> where it declares that criterion (<method>MemberCriteria</method>).
/// A failure passes the member's own status, HTTP status and fault through.</p>
ClassMethod ReadMember(pDescriptor As %String, pKind As %String, pMaxRows As %Integer, pSince As %String, Output pRows As %DynamicArray, Output pTruncated As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pRows = ""
    Set pTruncated = 0
    Set pHttpStatus = 0
    Set pFault = ""
    If pKind = ..#KINDERRORS {
        Set tSC = ##class(OcuPilot.Port.LogSourcePort).RecentErrors(pMaxRows, pSince, .tAnswer, .pHttpStatus, .pFault)
    } Else {
        Do ..MemberCriteria(pDescriptor, pSince, .tCriteria)
        Set tSC = ##class(OcuPilot.Screen.Read).Execute(pDescriptor, pMaxRows, .tAnswer, .pHttpStatus, .pFault, .tCriteria)
    }
    If $$$ISERR(tSC) Quit tSC
    Set pRows = tAnswer.rows
    Set pTruncated = ''tAnswer.truncated
    Quit tSC
}

/// <p>The criteria member <var>pDescriptor</var>'s own read is given: <var>pSince</var> as
/// <parameter>BEGINPARAM</parameter> where that read declares the criterion (the audit viewer), and
/// none otherwise.</p>
ClassMethod MemberCriteria(pDescriptor As %String, pSince As %String, Output pCriteria)
{
    Kill pCriteria
    If $ListFind(##class(OcuPilot.Screen.Read).CriteriaParams(pDescriptor), ..#BEGINPARAM) Set pCriteria(..#BEGINPARAM) = pSince
}

/// <p><var>pUtc</var>, a UTC <code>YYYY-MM-DD HH:MM:SS[.fff]</code> stamp, on the instance's clock in
/// the hub's form (<method>OcuPilot.Port.LogSourcePort.LocalFromUtc</method>). A test fixture
/// overrides it with a fixed offset, so the conversion is observable on an instance kept in UTC.</p>
ClassMethod LocalTime(pUtc As %String) As %String
{
    Quit ##class(OcuPilot.Port.LogSourcePort).LocalFromUtc(pUtc)
}

/// <p>One member row as the hub's row: <code>{time, source, severity, text, id}</code>, with
/// <var>pRoute</var> as <code>source</code> (Story 16.9's projection table). A log member's row is
/// as read; an application error's time is its date and time, its severity <code>2</code> and its
/// id its composite; an audit row's time is its <code>UTCTimeStamp</code> in the instance's local
/// time, its severity <code>""</code>, its text
/// <code>&lt;EventSource&gt;/&lt;EventType&gt;/&lt;Event&gt;</code> and <code>: &lt;Description&gt;</code>
/// when there is one, never <code>EventData</code>, and its id its composite (AD-13).</p>
ClassMethod Project(pKind As %String, pRoute As %String, pRow As %DynamicObject) As %DynamicObject
{
    Set tTime = ""
    Set tSeverity = ""
    Set tText = ""
    Set tId = ""
    If pKind = ..#KINDAUDIT {
        Set tTime = ..LocalTime(pRow.%Get("UTCTimeStamp"))
        Set tText = pRow.%Get("EventSource") _ "/" _ pRow.%Get("EventType") _ "/" _ pRow.%Get("Event")
        If pRow.%Get("Description") '= "" Set tText = tText _ ": " _ pRow.%Get("Description")
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pRow.%Get("UTCTimeStamp"), pRow.%Get("SystemID"), pRow.%Get("AuditIndex")))
    } ElseIf pKind = ..#KINDERRORS {
        Set tTime = pRow.%Get("time")
        Set tSeverity = "2"
        Set tText = pRow.%Get("text")
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pRow.%Get("namespace"), pRow.%Get("date"), pRow.%Get("errorNumber")))
    } Else {
        Set tTime = pRow.%Get("time")
        Set tSeverity = pRow.%Get("severity")
        Set tText = pRow.%Get("text")
    }
    Set tOut = {}
    Do tOut.%Set("time", tTime _ "", "string")
    Do tOut.%Set("source", pRoute, "string")
    Do tOut.%Set("severity", tSeverity _ "", "string")
    Do tOut.%Set("text", tText _ "", "string")
    Do tOut.%Set("id", tId _ "", "string")
    Quit tOut
}

/// <p>Compose <var>pArea</var>'s members' reads, each at <var>pMaxRows</var>, windowed at
/// <var>pSince</var> (instance-local <code>YYYY-MM-DD HH:MM:SS</code>, already validated by the
/// caller; <code>""</code> for no bound).</p>
/// <p>On success <var>pAnswer</var> is <code>{rows, truncated, sources}</code>. <code>rows</code>
/// holds every shown member's rows at or after the bound, a row with no time left out, newest
/// first, ties in roster order then each member's own order, cut to <var>pMaxRows</var>.
/// <code>sources</code> holds one <code>{source, shown, requires, count, truncated, last}</code> per
/// member in roster order: <code>requires</code> the failed pair of a member not shown,
/// <code>count</code> its rows in the answer, <code>last</code> its newest timed row whatever the
/// bound, its text cut at <parameter>LASTTEXTMAX</parameter>, or <code>null</code>. A member is
/// <code>truncated</code> when its own read was cut while its oldest returned row is still at or
/// after the bound, or when the merged cut dropped one of its rows; the answer's
/// <code>truncated</code> is their OR.</p>
/// <p>A member refused at its gate is read zero times; a 403 from its read is treated the same way.
/// Any other member failure fails the whole read with that member's status, HTTP status and fault;
/// the answer is never partial.</p>
ClassMethod Compose(pMaxRows As %Integer, pSince As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pArea As %String = "logs") As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tMax = $Select(+pMaxRows < 1: ##class(OcuPilot.Screen.Read).#DEFAULTMAXROWS, 1: +pMaxRows \ 1)
        Set tBound = ##class(OcuPilot.Port.LogSourcePort).ClockStamp(pSince)
        Set tSC = ..Members(pArea, .tMembers)
        If $$$ISERR(tSC) {
            Set tSC = ..Internal("the timeline could not list its members: " _ $System.Status.GetErrorText(tSC), .pHttpStatus, .pFault)
            Quit
        }
        Set tSources = []
        Kill tHeld, tOwner
        Set tSeq = 0
        For tM = 1:1:$ListLength(tMembers) {
            Set tMember = $List(tMembers, tM)
            Set tRoute = $ClassMethod(tMember, "Route")
            Set tEntry = {"source": (tRoute), "shown": true, "requires": "", "count": 0, "truncated": false, "last": null}
            Set tKind = ..MemberKind(tMember)
            If tKind = "" {
                Set tSC = ..Internal(tMember _ " is a timeline member this read cannot compose", .pHttpStatus, .pFault)
                Quit
            }
            Do tSources.%Push(tEntry)
            Set tFailedPair = ""
            If '..GateMember(tMember, .tFailedPair) {
                Do tEntry.%Set("shown", 0, "boolean")
                Do tEntry.%Set("requires", tFailedPair)
                Continue
            }
            Set tReadSC = ..ReadMember(tMember, tKind, tMax, pSince, .tRows, .tReadCut, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                If +tHttp = 403 {
                    Set tRefused = ""
                    If $IsObject(tFault) && $IsObject(tFault.%Get("detail")) Set tRefused = tFault.detail.%Get("failedPair")
                    Do tEntry.%Set("shown", 0, "boolean")
                    Do tEntry.%Set("requires", tRefused)
                    Continue
                }
                Set pHttpStatus = tHttp
                Set pFault = tFault
                Set tSC = tReadSC
                Quit
            }
            Set tNewest = ""
            Set tOldest = ""
            Set tIterator = tRows.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If '$IsObject(tRow) Continue
                Set tProjected = ..Project(tKind, tRoute, tRow)
                Set tTime = tProjected.time
                If tTime = "" Continue
                If '$IsObject(tNewest) || (tTime ] tNewest.time) Set tNewest = tProjected
                If (tOldest = "") || (tOldest ] tTime) Set tOldest = tTime
                If (tBound '= "") && (tTime '= tBound) && '(tTime ] tBound) Continue
                Set tSeq = tSeq + 1
                Set tHeld(" " _ tTime, tSeq) = tProjected
                Set tOwner(tSeq) = tEntry
            }
            ; A cut read whose oldest row is still inside the window may have left window rows
            ; unread; one whose oldest row is before the bound read the whole window.
            If tReadCut && ((tBound = "") || (tOldest = "") || '(tBound ] tOldest)) Do tEntry.%Set("truncated", 1, "boolean")
            If $IsObject(tNewest) Do tEntry.%Set("last", ..LastOf(tNewest))
        }
        If $$$ISERR(tSC) Quit

        Set tOut = []
        Set tTime = ""
        For {
            Set tTime = $Order(tHeld(tTime), -1)
            If tTime = "" Quit
            Set tAt = ""
            For {
                Set tAt = $Order(tHeld(tTime, tAt), 1, tRow)
                If tAt = "" Quit
                Set tOwned = tOwner(tAt)
                If tOut.%Size() >= tMax {
                    Do tOwned.%Set("truncated", 1, "boolean")
                    Continue
                }
                Do tOut.%Push(tRow)
                Do tOwned.%Set("count", tOwned.count + 1, "number")
            }
        }
        Set tAnyCut = 0
        Set tIterator = tSources.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tSource) {
            If tSource.truncated Set tAnyCut = 1
        }
        Set pAnswer = {}
        Do pAnswer.%Set("rows", tOut)
        Do pAnswer.%Set("truncated", tAnyCut, "boolean")
        Do pAnswer.%Set("sources", tSources)
        Set pHttpStatus = 200
    } Catch ex {
        Set pAnswer = ""
        Set tSC = ..Internal("the timeline failed: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p><var>pRow</var> as a source's <code>last</code>: a copy whose text is cut at
/// <parameter>LASTTEXTMAX</parameter> characters, the last of them U+2026.</p>
ClassMethod LastOf(pRow As %DynamicObject) As %DynamicObject
{
    Set tLast = ##class(%DynamicObject).%FromJSON(pRow.%ToJSON())
    Set tText = tLast.text
    If $Length(tText) > ..#LASTTEXTMAX Do tLast.%Set("text", $Extract(tText, 1, ..#LASTTEXTMAX - 1) _ $Char(8230), "string")
    Quit tLast
}

/// <p>An internal failure: the generic fault on the wire, the detail in the status alone.</p>
ClassMethod Internal(pDetail As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Quit $$$ERROR($$$GeneralError, pDetail)
}

}
