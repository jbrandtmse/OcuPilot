/// <p>Story 9.8's probe-task helper: <class>OcuPilot.Test.TaskProbe</class> over the
/// <parameter>PREFIX</parameter> <code>OcuP98</code>, with the tasks Edit task's tests edit. Nothing
/// here touches a task whose name does not start with it, so a vendor task is never edited, read for
/// removal or deleted.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. Its
/// callers are armed on <code>OCUPILOT_ALLOW_TASK_CONTROL</code>.</p>
Class OcuPilot.Test.TaskEditProbe Extends OcuPilot.Test.TaskProbe
{

/// <p>The name prefix every Edit task probe carries.</p>
Parameter PREFIX = "OcuP98";

/// <p>The task type holding a secret-typed setting (<code>SMTPPass</code>, a
/// <code>%SYS.Task.Password</code>).</p>
Parameter SECRETTYPE = "%SYS.Task.DiagnosticReport";

/// <p>A task created through the wizard's own Save from <var>pArgs</var>, in <var>pId</var>; the
/// name must carry <parameter>PREFIX</parameter>.</p>
ClassMethod Create(pArgs As %DynamicObject, Output pId As %String) As %Status
{
    Set pId = ""
    If $Extract(pArgs.%Get("Name"), 1, $Length(..#PREFIX)) '= ..#PREFIX Quit $$$ERROR($$$GeneralError, "a probe task's name starts with " _ ..#PREFIX)
    Set tSC = ##class(OcuPilot.Area.Task.TaskSave).Create(pArgs, .tHttp, .tFault, .tViolations, .pId)
    If $$$ISERR(tSC) Quit tSC
    If $Get(tViolations) > 0 Quit $$$ERROR($$$GeneralError, "the probe task was refused: " _ $ListToString(tViolations(1)))
    If pId = "" Quit $$$ERROR($$$GeneralError, "the probe task answered no id")
    Quit $$$OK
}

/// <p>The AC7 values the wizard's own browser test creates a task with, named <var>pName</var>:
/// weekly on Monday and Wednesday, every 30 minutes from 01:00 to 05:00 from tomorrow, low priority, batch,
/// an output file emailed as binary, suspend on error, reschedule on start, three address lists and
/// mirror status Any.</p>
ClassMethod Ac7(pName As %String) As %DynamicObject
{
    Quit {"Name": (pName), "Description": "OcuPilot edit probe", "NameSpace": "%SYS", "TaskClass": "%SYS.Task.PurgeTaskHistory", "Settings": {"KeepDays": "30"}, "TimePeriod": "Weekly", "TimePeriodEvery": "1", "TimePeriodDay": "24", "DailyFrequency": "Several", "DailyFrequencyTime": "Minutes", "DailyIncrement": "30", "DailyStartTime": "01:00", "DailyEndTime": "05:00", "StartDate": ($ZDate(+$Horolog + 1, 3)), "Priority": "Low", "MirrorStatus": "Any", "IsBatch": true, "OpenOutputFile": true, "OutputFilename": "ocup98edit.txt", "OutputFileIsBinary": true, "EmailOutput": true, "SuspendOnError": true, "RescheduleOnStart": true, "EmailOnCompletion": ["ops@example.com"], "EmailOnError": ["dev@example.com"], "EmailOnExpiration": ["late@example.com"]}
}

/// <p>A <parameter>SECRETTYPE</parameter> task named <var>pName</var>, on demand, whose
/// <code>SMTPPass</code> is <var>pSecret</var>, in <var>pId</var>. It is created through the vendor
/// endpoint directly, because the wizard's rules refuse a secret setting.</p>
ClassMethod CreateSecret(pName As %String, pSecret As %String, Output pId As %String) As %Status
{
    Set pId = ""
    If $Extract(pName, 1, $Length(..#PREFIX)) '= ..#PREFIX Quit $$$ERROR($$$GeneralError, "a probe task's name starts with " _ ..#PREFIX)
    Set tArgs = {"Name": (pName), "TaskClass": (..#SECRETTYPE), "NameSpace": "%SYS", "TimePeriod": "On Demand", "Settings": {"SMTPUser": "ocup98user", "SMTPPass": (pSecret)}}
    Set tSC = ##class(OcuPilot.Area.Task.TaskRules).Compose(tArgs, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Set tArgs = ""
    Set tDiff = ""
    If $$$ISERR(tSC) Quit tSC
    If tProblem '= "" Quit $$$ERROR($$$GeneralError, tProblem)
    Do ##class(OcuPilot.Screen.Tool.TaskCreate).DerivedFields(tPayload)
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = ##class(OcuPilot.Port.TaskPort).Invoke("Task.CRUD", "POST", .tQuery, tPayload, .tAnswer, .tHttp, .tFault)
    Set tPayload = ""
    If $$$ISERR(tSC) Quit tSC
    If $IsObject($Get(tAnswer)) Set pId = tAnswer.%Get("Id")
    If pId = "" Quit $$$ERROR($$$GeneralError, "the secret probe answered no id")
    Quit $$$OK
}

/// <p>Whether task <var>pId</var>'s stored <code>SMTPPass</code> is <var>pSecret</var>, compared in
/// this process; the value is never returned or written anywhere.</p>
ClassMethod SecretHeld(pId As %String, pSecret As %String) As %Boolean
{
    Set tHeld = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tTask = ##class(%SYS.Task).%OpenId(pId, 0)
        If $IsObject(tTask) && ($Extract(tTask.Name, 1, $Length(..#PREFIX)) = ..#PREFIX) {
            Do tTask.GetSettings(.tSettings)
            Set tAt = $ListFind(tSettings, "SMTPPass")
            If tAt Set tHeld = ($ListGet(tSettings, tAt + 1) = pSecret)
            Kill tSettings
        }
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tHeld = 0
    }
    Quit tHeld
}

/// <p>Move probe task <var>pId</var>'s stored start to <var>pDaysAgo</var> days before today, by a
/// SQL <code>UPDATE</code> as an older task would hold it.</p>
ClassMethod StartInThePast(pId As %String, pDaysAgo As %Integer = 3) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tName = ""
        Set tTask = ##class(%SYS.Task).%OpenId(pId, 0)
        If $IsObject(tTask) Set tName = tTask.Name
        Set tTask = ""
        If $Extract(tName, 1, $Length(..#PREFIX)) '= ..#PREFIX {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ERROR($$$GeneralError, "not a probe task")
            Quit
        }
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE %SYS.Task SET StartDate = ? WHERE ID = ?", +$Horolog - pDaysAgo, pId)
        If tRS.%SQLCODE < 0 Set tSC = $$$ERROR($$$GeneralError, "the start could not be moved: SQLCODE " _ tRS.%SQLCODE)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ask the Task Manager to run probe task <var>pId</var> now, holding no OREF across the call's
/// return, so its <code>NextScheduled</code> moves at once.</p>
ClassMethod RunNow(pId As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(%SYS.Task).RunNow(pId)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Task <var>pId</var>'s <code>INFO</code> field <var>pField</var>, through the task port.</p>
ClassMethod Info(pId As %String, pField As %String) As %String
{
    Kill tQuery
    Set tQuery("id") = pId
    Set tSC = ##class(OcuPilot.Port.TaskPort).Invoke("Task.CRUD", "INFO", .tQuery, "", .tInfo, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tInfo)) Quit ""
    Quit tInfo.%Get(pField)
}

}
