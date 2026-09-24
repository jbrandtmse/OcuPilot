/// <p>The harmless tasks the task-action tests act on, and the reads that watch them (Stories 7.5
/// and 7.6). Not a test case and not armed: it runs nothing itself, and a test that writes one of
/// its tasks runs on a throwaway only.</p>
/// <p>The schedule probe is <parameter>SCHEDULETASKNAME</parameter>, the same harmless task
/// scheduled daily at 03:00, which Story 7.6's suspend, resume and delete act on; it can be made a
/// system task (<code>Type</code> 0) so a delete of one can be proposed without touching a vendor
/// task.</p>
/// <p>The task is <parameter>PROBETASKNAME</parameter>, a <code>%SYS.Task.RunLegacyTask</code>
/// whose code is <code>Quit</code>, scheduled on demand in <code>%SYS</code>. Every method here
/// switches to <code>%SYS</code> by save and restore (AD-16) and <b>holds no task OREF across a
/// wait</b>: <code>%SYS.Task.RunNow</code> leaves a lock the Task Manager skips for as long as a
/// caller holds the task's OREF, so a fixture that held one would stop the run it waits for.</p>
Class OcuPilot.Test.TaskRunFixture
{

/// <p>The probe task's name, with the probe prefix the rest of the suite uses.</p>
Parameter PROBETASKNAME = "OcuPilotProbeRunTask";

/// <p>The vendor's on-demand schedule (<code>%SYS.TaskSuper.TimePeriod</code> 5).</p>
Parameter ONDEMAND = 5;

/// <p>The schedule probe's name.</p>
Parameter SCHEDULETASKNAME = "OcuPilotProbeScheduleTask";

/// <p>The vendor's daily schedule (<code>TimePeriod</code> 0) and the probe's start time, 03:00 in
/// seconds past midnight.</p>
Parameter DAILY = 0;

Parameter DAILYSTART = 10800;

/// <p><code>%SYS.Task.Type</code>'s system and user values.</p>
Parameter TYPESYSTEM = 0;

Parameter TYPEUSER = 2;

/// <p>Seconds between two reads of the task's history.</p>
Parameter POLLSECONDS = 5;

/// <p>The id of the probe task, created when absent. A reused one is left not suspended.</p>
ClassMethod EnsureRunProbeTask(Output pId As %String) As %Status
{
    Set pId = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %SYS.Task WHERE %EXACT(Name) = ?", ..#PROBETASKNAME)
        While tRS.%Next() {
            Set pId = tRS.%Get("ID")
        }
        If pId = "" {
            Set tTask = ##class(%SYS.Task).%New()
            Set tTask.Name = ..#PROBETASKNAME
            Set tTask.Description = "OcuPilot's run probe: runs Quit on demand, created and deleted by its tests"
            Set tTask.NameSpace = "%SYS"
            Set tTask.TaskClass = "%SYS.Task.RunLegacyTask"
            Set tTask.TimePeriod = ..#ONDEMAND
            Set tDefinition = ##class(%SYS.Task.RunLegacyTask).%New()
            Set tDefinition.ExecuteCode = "Quit"
            Set tSC = tTask.AssignSettings(tDefinition)
            Set tDefinition = ""
            If $$$ISOK(tSC) Set tSC = tTask.%Save()
            If $$$ISOK(tSC) Set pId = tTask.%Id()
            Set tTask = ""
        } Else {
            Set tTask = ##class(%SYS.Task).%OpenId(pId)
            If $IsObject(tTask) && (+tTask.Suspended '= 0) {
                Set tTask.Suspended = 0
                Set tSC = tTask.%Save()
            }
            Set tTask = ""
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        If pId = "" Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskRunFixture could not create its probe task")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The highest <code>%SYS.Task.History</code> row id now, or 0.</p>
ClassMethod HistoryHighWater() As %Integer
{
    Set tMax = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(ID) AS M FROM %SYS_Task.History")
        If tRS.%Next() Set tMax = +tRS.%Get("M")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tMax = 0
    }
    Quit tMax
}

/// <p>Whether task <var>pId</var>'s history gains a <code>Success</code> row newer than row
/// <var>pSince</var> within <var>pBudget</var> seconds, reading afresh every
/// <parameter>POLLSECONDS</parameter>. <var>pElapsed</var> is the seconds waited.</p>
ClassMethod AwaitRun(pId As %String, pSince As %Integer, pBudget As %Integer = 180, Output pElapsed As %Numeric) As %Boolean
{
    Set tStarted = $ZHorolog
    Set pElapsed = 0
    Set tLanded = 0
    For {
        Set tLanded = ..SuccessSince(pId, pSince)
        Set pElapsed = $ZHorolog - tStarted
        If tLanded || (pElapsed >= pBudget) Quit
        Hang ..#POLLSECONDS
    }
    Quit tLanded
}

/// <p>Whether task <var>pId</var>'s history holds a <code>Success</code> row newer than row
/// <var>pSince</var>, read now.</p>
ClassMethod SuccessSince(pId As %String, pSince As %Integer) As %Boolean
{
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM %SYS_Task.History WHERE ID > ? AND Task = ? AND Error = 'Success'", pSince, pId)
        If tRS.%Next() Set tFound = (+tRS.%Get("N") > 0)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tFound = 0
    }
    Quit tFound
}

/// <p>Whether this process owns no lock on task <var>pId</var>'s storage node, which is the lock
/// <code>%SYS.Task.RunNow</code> leaves while a caller holds the task's OREF.</p>
ClassMethod NoLockHeld(pId As %String) As %Boolean
{
    Set tFree = 1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tName = $Name(^SYS("Task", "TaskD", pId))
        Set tOwners = $Get(^$LOCK(tName, "OWNER"))
        Set tFree = '(("," _ tOwners _ ",") [ ("," _ $Job _ ","))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tFree = 0
    }
    Quit tFree
}

/// <p>Field <var>pField</var> of task <var>pId</var>'s <code>INFO</code>, as the shipped port
/// answers it now, rendered as the mint renders a value; <code>""</code> when the read fails.
/// <var>pRead</var> is 1 only when the read answered, so a caller comparing two empty values can
/// tell an empty field from a failed read.</p>
ClassMethod InfoField(pId As %String, pField As %String, Output pRead As %Boolean) As %String
{
    Set tRendered = ""
    Set pRead = 0
    Try {
        Kill tQuery
        Set tQuery("id") = pId
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Task.CRUD", "INFO", .tQuery, "", .tFresh, .tHttp, .tFault)
        If $$$ISERR(tSC) || '$IsObject(tFresh) Quit
        Set tRendered = ##class(OcuPilot.Kernel.Proposal.Mint).Display(tFresh.%Get(pField), tFresh.%GetTypeOf(pField))
        Set pRead = 1
    } Catch ex {
        Set tRendered = ""
        Set pRead = 0
    }
    Quit tRendered
}

/// <p>The HTTP status task <var>pId</var>'s <code>INFO</code> answers through the shipped port now:
/// 200 for a task the instance holds, 404 for one it does not, <code>0</code> when the call
/// raised.</p>
ClassMethod InfoStatus(pId As %String) As %Integer
{
    Set tHttp = 0
    Try {
        Kill tQuery
        Set tQuery("id") = pId
        Do ##class(OcuPilot.Port.AdminPort).Invoke("Task.CRUD", "INFO", .tQuery, "", .tFresh, .tHttp, .tFault)
    } Catch ex {
        Set tHttp = 0
    }
    Quit +tHttp
}

/// <p>How many rows the shipped <code>tasks.taskhistory</code> read answers for task
/// <var>pId</var>, or <code>-1</code> when the read fails. It goes through
/// <class>OcuPilot.Screen.Read</class>, because that read's cap and sort decide what a reader
/// sees.</p>
ClassMethod HistoryReadRows(pId As %String) As %Integer
{
    Set tRows = 0
    Try {
        Kill tCriteria
        Set tCriteria("taskId") = pId
        Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.TaskRunList", 1000, .tAnswer, .tHttp, .tFault, .tCriteria)
        If $$$ISERR(tSC) || '$IsObject(tAnswer) {
            Set tRows = -1
            Quit
        }
        Set tIterator = tAnswer.%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If $IsObject(tRow) && (tRow.%Get("TaskId") = pId) Set tRows = tRows + 1
        }
    } Catch ex {
        Set tRows = -1
    }
    Quit tRows
}

/// <p>The id of the schedule probe, created when absent, left not suspended, and of
/// <code>Type</code> system when <var>pSystem</var> is 1 and user otherwise.</p>
ClassMethod EnsureScheduleProbeTask(Output pId As %String, pSystem As %Boolean = 0) As %Status
{
    Set pId = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tType = $Select(pSystem: ..#TYPESYSTEM, 1: ..#TYPEUSER)
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %SYS.Task WHERE %EXACT(Name) = ?", ..#SCHEDULETASKNAME)
        While tRS.%Next() {
            Set pId = tRS.%Get("ID")
        }
        If pId = "" {
            Set tTask = ##class(%SYS.Task).%New()
            Set tTask.Name = ..#SCHEDULETASKNAME
            Set tTask.Description = "OcuPilot's schedule probe: runs Quit daily at 03:00, created and deleted by its tests"
            Set tTask.NameSpace = "%SYS"
            Set tTask.TaskClass = "%SYS.Task.RunLegacyTask"
            Set tTask.TimePeriod = ..#DAILY
            Set tTask.TimePeriodEvery = 1
            Set tTask.DailyFrequency = 0
            Set tTask.DailyStartTime = ..#DAILYSTART
            Set tTask.Type = tType
            Set tDefinition = ##class(%SYS.Task.RunLegacyTask).%New()
            Set tDefinition.ExecuteCode = "Quit"
            Set tSC = tTask.AssignSettings(tDefinition)
            Set tDefinition = ""
            If $$$ISOK(tSC) Set tSC = tTask.%Save()
            If $$$ISOK(tSC) Set pId = tTask.%Id()
            Set tTask = ""
        } Else {
            Set tTask = ##class(%SYS.Task).%OpenId(pId)
            If $IsObject(tTask) && ((+tTask.Suspended '= 0) || (+tTask.Type '= tType)) {
                Set tTask.Suspended = 0
                Set tTask.Type = tType
                Set tSC = tTask.%Save()
            }
            Set tTask = ""
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        If pId = "" Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskRunFixture could not create its schedule probe task")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete every task named <parameter>SCHEDULETASKNAME</parameter>.</p>
ClassMethod DeleteScheduleProbeTask()
{
    Do ..DeleteNamed(..#SCHEDULETASKNAME)
}

/// <p>How many tasks named <parameter>SCHEDULETASKNAME</parameter> exist, or <code>-1</code> when
/// the count fails.</p>
ClassMethod ScheduleProbeCount() As %Integer
{
    Quit ..CountNamed(..#SCHEDULETASKNAME)
}

/// <p>How many <code>%SYS.Task.History</code> rows task <var>pId</var> holds, or <code>-1</code>
/// when the count fails. The vendor keeps a deleted task's rows, so this answers for one that is
/// gone.</p>
ClassMethod HistoryRowCount(pId As %String) As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM %SYS_Task.History WHERE Task = ?", pId)
        If tRS.%Next() Set tCount = +tRS.%Get("N")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Delete every task named <parameter>PROBETASKNAME</parameter>.</p>
ClassMethod DeleteRunProbeTask()
{
    Do ..DeleteNamed(..#PROBETASKNAME)
}

/// <p>Delete every task named <var>pName</var>.</p>
ClassMethod DeleteNamed(pName As %String) [ Private ]
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tIds = ""
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %SYS.Task WHERE %EXACT(Name) = ?", pName)
        While tRS.%Next() {
            Set tIds = tIds _ $ListBuild(tRS.%Get("ID"))
        }
        For tI = 1:1:$ListLength(tIds) {
            Do ##class(%SYS.Task).%DeleteId($List(tIds, tI))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>How many tasks named <parameter>PROBETASKNAME</parameter> exist.</p>
ClassMethod ProbeCount() As %Integer
{
    Quit ..CountNamed(..#PROBETASKNAME)
}

/// <p>How many tasks named <var>pName</var> exist, or <code>-1</code> when the count fails.</p>
ClassMethod CountNamed(pName As %String) As %Integer [ Private ]
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM %SYS.Task WHERE %EXACT(Name) = ?", pName)
        If tRS.%Next() Set tCount = +tRS.%Get("N")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

}
