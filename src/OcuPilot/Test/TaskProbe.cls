/// <p>Story 9.7's probe-task helper: finds, reads and removes the tasks the task create tests make.
/// Every probe task is named with <parameter>PREFIX</parameter>, and nothing here touches a task
/// whose name does not start with it, so a vendor task is never read for removal or deleted.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. Its
/// callers are armed on <code>OCUPILOT_ALLOW_TASK_CONTROL</code>.</p>
Class OcuPilot.Test.TaskProbe Extends %RegisteredObject
{

/// <p>The name prefix every probe task carries.</p>
Parameter PREFIX = "OcuP97";

/// <p>The ids of the tasks whose name starts with <parameter>PREFIX</parameter>, as a
/// <class>%List</class>, with <var>pNames</var> alongside.</p>
ClassMethod Probes(Output pNames As %List) As %List
{
    Set tIds = ""
    Set pNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, Name FROM %SYS.Task WHERE Name %STARTSWITH ?", ..#PREFIX)
        While tRS.%Next() {
            If $Extract(tRS.%Get("Name"), 1, $Length(..#PREFIX)) '= ..#PREFIX Continue
            Set tIds = tIds _ $ListBuild(tRS.%Get("ID"))
            Set pNames = pNames _ $ListBuild(tRS.%Get("Name"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tIds
}

/// <p>Delete every probe task, each by id after re-reading its exact name; a failing status when
/// any survives.</p>
ClassMethod RemoveAll() As %Status
{
    Set tSC = $$$OK
    Set tIds = ..Probes()
    For tI = 1:1:$ListLength(tIds) Set tSC = $$$ADDSC(tSC, ..Remove($List(tIds, tI)))
    If ..Probes() '= "" Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "a probe task survived its removal"))
    Quit tSC
}

/// <p>Delete task <var>pId</var> when its name starts with <parameter>PREFIX</parameter>; any other
/// task is left alone.</p>
ClassMethod Remove(pId As %String) As %Status
{
    Set tSC = $$$OK
    If pId = "" Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tTask = ##class(%SYS.Task).%OpenId(pId, 0)
        If $IsObject(tTask) && ($Extract(tTask.Name, 1, $Length(..#PREFIX)) = ..#PREFIX) {
            Set tTask = ""
            Set tSC = ##class(%SYS.Task).%DeleteId(pId)
        }
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The id of the probe task named exactly <var>pName</var>, or <code>""</code>.</p>
ClassMethod IdOf(pName As %String) As %String
{
    Set tIds = ..Probes(.tNames)
    Set tPosition = $ListFind(tNames, pName)
    If 'tPosition Quit ""
    Quit $List(tIds, tPosition)
}

/// <p>Task <var>pId</var>'s stored properties as the instance holds them, logical values, with its
/// settings as <code>Settings.&lt;name&gt;</code> members; <code>""</code> when it is absent.</p>
ClassMethod Stored(pId As %String) As %DynamicObject
{
    Set tStored = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tTask = ##class(%SYS.Task).%OpenId(pId, 0)
        If '$IsObject(tTask) {
            Set $NAMESPACE = tOrigNS
            Quit
        }
        Set tStored = {}
        For tField = "Name", "Description", "NameSpace", "TaskClass", "TimePeriod", "TimePeriodEvery", "TimePeriodDay", "RunAfterGUID", "DailyFrequency", "DailyFrequencyTime", "DailyIncrement", "DailyStartTime", "DailyEndTime", "StartDate", "EndDate", "Expires", "ExpiresDays", "ExpiresHours", "ExpiresMinutes", "RunAsUser", "Priority", "IsBatch", "MirrorStatus", "OpenOutputFile", "OutputDirectory", "OutputFilename", "OutputFileIsBinary", "EmailOutput", "SuspendOnError", "SuspendTerminated", "RescheduleOnStart", "JobGUID" {
            Do tStored.%Set(tField, $Property(tTask, tField) _ "", "string")
        }
        For tField = "EmailOnCompletion", "EmailOnError", "EmailOnExpiration" {
            Set tText = ""
            Set tList = $Property(tTask, tField)
            For tI = 1:1:tList.Count() Set tText = tText _ $Select(tText = "": "", 1: ",") _ tList.GetAt(tI)
            Do tStored.%Set(tField, tText, "string")
        }
        Set tSettings = ""
        Set $NAMESPACE = tTask.NameSpace
        Do tTask.GetSettings(.tSettings)
        For tI = 1:2:$ListLength(tSettings) Do tStored.%Set("Settings." _ $ListGet(tSettings, tI), $ListGet(tSettings, tI + 1) _ "", "string")
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tStored = ""
    }
    Quit tStored
}

/// <p>The name of a task the instance holds that is not a probe -- the first the list answers -- for
/// a taken-name case, or <code>""</code>.</p>
ClassMethod VendorName() As %String
{
    Set tName = ""
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Task.CRUD", "LIST", .tQuery, "", .tList, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tList)) Quit ""
    Set tIterator = tList.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tCandidate = tRow.%Get("Name")
        If (tCandidate = "") || ($Extract(tCandidate, 1, $Length(..#PREFIX)) = ..#PREFIX) Continue
        If '$Match(tCandidate, "^[A-Za-z].*") Continue
        Set tName = tCandidate
        Quit
    }
    Quit tName
}

}
