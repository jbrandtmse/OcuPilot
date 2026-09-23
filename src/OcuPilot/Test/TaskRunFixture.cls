/// <p>The harmless task a run test runs, and the reads that watch it run (Story 7.5). Not a test
/// case and not armed: it runs nothing itself, and a test that runs its task runs on a throwaway
/// only.</p>
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

/// <p>Delete every task named <parameter>PROBETASKNAME</parameter>.</p>
ClassMethod DeleteRunProbeTask()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tIds = ""
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %SYS.Task WHERE %EXACT(Name) = ?", ..#PROBETASKNAME)
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
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM %SYS.Task WHERE %EXACT(Name) = ?", ..#PROBETASKNAME)
        If tRS.%Next() Set tCount = +tRS.%Get("N")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

}
