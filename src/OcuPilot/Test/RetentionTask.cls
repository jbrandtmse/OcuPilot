/// <p>The daily retention task (Story 14.4, AC2, AD-17, AD-37): the production install schedules
/// exactly one task of <class>OcuPilot.Kernel.RetentionTask</class>, named "OcuPilot transcript
/// retention", daily at 03:15 in the install namespace, however many times it runs and whatever
/// drift it finds; a forced run through the Task Manager records success in its history; and the
/// uninstall's own removal step deletes it.</p>
/// <p><b>It runs OcuPilot's production install, so <method>OnBeforeAllTests</method> refuses to
/// run unless <parameter>ARMINGVARIABLE</parameter> reads 1.</b> The forced run sweeps the whole
/// instance, so it is taken only when <method>OcuPilot.Test.Retention.ForeignExpired</method> finds
/// no row another suite created past its retention. Every method leaves the one task installed.</p>
Class OcuPilot.Test.RetentionTask Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

Parameter TASKCLASS = "OcuPilot.Kernel.RetentionTask";

Parameter TASKNAME = "OcuPilot transcript retention";

/// <p>How long a forced run is waited for: the Task Manager takes a run request at its next
/// once-a-minute pass.</p>
Parameter RUNWAITSECONDS As %Integer = 180;

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RetentionTask runs OcuPilot's production install, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was run.")
    }
    ; Every method starts from the installed task, whatever order they run in and whether or not
    ; the container's start hook installed this code.
    Quit ##class(OcuPilot.Install.Installer).Install("")
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(""), "the production install leaves the task in place")
    Quit $$$OK
}

/// <p>The ids of every task of the retention class, as <var>pIds(n)</var>.</p>
ClassMethod TaskIds(Output pIds) As %Status
{
    Kill pIds
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(%SYS.TaskSuper).QueryTasks(..#TASKCLASS, "", "", .tRaw)
        Set tSub = ""
        For {
            Set tSub = $Order(tRaw(tSub), 1, tId)
            If tSub = "" Quit
            Set pIds($Increment(pIds)) = tId
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Task <var>pId</var>'s schedule, as <code>name|namespace|period|every|frequency|start</code>,
/// read freshly by SQL.</p>
ClassMethod Schedule(pId As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tOut = ""
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name, NameSpace, TimePeriod, TimePeriodEvery, DailyFrequency, DailyStartTime FROM %SYS.Task WHERE ID = ?", pId)
        If tRS.%Next() Set tOut = tRS.%GetData(1) _ "|" _ tRS.%GetData(2) _ "|" _ tRS.%GetData(3) _ "|" _ tRS.%GetData(4) _ "|" _ tRS.%GetData(5) _ "|" _ tRS.%GetData(6)
    } Catch ex {
        Set tOut = ex.DisplayString()
    }
    Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p>Set task <var>pId</var>'s <var>pProperty</var>, or save a second task of the class when
/// <var>pId</var> is <code>""</code>.</p>
ClassMethod Drift(pId As %String, pProperty As %String = "", pValue As %String = "") As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If pId = "" {
            Set tTask = ##class(%SYS.Task).%New()
            Set tTask.Name = "OcuPilotProbeRetentionSecond"
            Set tTask.NameSpace = tOrigNS
            Set tTask.TaskClass = ..#TASKCLASS
            Set tTask.TimePeriod = 5
        } Else {
            Set tTask = ##class(%SYS.Task).%OpenId(pId)
            Set $Property(tTask, pProperty) = pValue
        }
        Set tSC = tTask.%Save()
        Set tTask = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>AC2: the uninstall's removal step leaves no task of the class; install run twice then
/// schedules one task, as declared; it creates one where none exists, repairs a drifted schedule and
/// deletes a second task of the class.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Install.Installer.EnsureRetentionTask</method> a
/// no-op -- no task exists after the install and this goes red.</p>
Method TestInstallSchedulesExactlyOneTaskAndRepairsDrift()
{
    Set tNs = $NAMESPACE
    Kill tNames
    Set tNames("retentionTaskClass") = ..#TASKCLASS
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).RemoveRetentionTask(.tNames), "the uninstall's removal step deletes every retention task")
    Do $$$AssertEquals($NAMESPACE, tNs, "and leaves the caller's namespace as it found it")
    Do $$$AssertStatusOK(..TaskIds(.tNone), "the tasks read")
    Do $$$AssertEquals(+$Get(tNone), 0, "and none is left")

    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(""), "the production install runs")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(""), "and runs again")
    Do $$$AssertStatusOK(..TaskIds(.tIds), "the tasks read")
    Do $$$AssertEquals(+$Get(tIds), 1, "exactly one retention task is scheduled")
    If +$Get(tIds) '= 1 Quit
    Set tExpected = ..#TASKNAME _ "|" _ tNs _ "|0|1|0|11700"
    Do $$$AssertEquals(..Schedule(tIds(1)), tExpected, "named, in the install namespace, daily at 03:15")

    Do $$$AssertStatusOK(..Drift(tIds(1), "DailyStartTime", 3600), "its start time drifts")
    Do $$$AssertStatusOK(..Drift(""), "and a second task of the class appears")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(""), "the install runs again")
    Do $$$AssertStatusOK(..TaskIds(.tAfter), "the tasks read")
    Do $$$AssertEquals(+$Get(tAfter), 1, "one task is left")
    If +$Get(tAfter) = 1 Do $$$AssertEquals(..Schedule(tAfter(1)), tExpected, "with its schedule repaired")
}

/// <p>AC2: a forced run of the scheduled task through the Task Manager removes an entry older than
/// its definition's retention and records success in the task's history -- the sweep ran as the
/// task's own user, in the install namespace, and answered OK.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.RetentionTask.OnTask</method> answer OK
/// without sweeping -- the entry stays and this goes red.</p>
Method TestAForcedRunRemovesAnExpiredEntryAndRecordsSuccess()
{
    Do $$$AssertStatusOK(..TaskIds(.tIds), "the tasks read")
    Do $$$AssertEquals(+$Get(tIds), 1, "one retention task is scheduled")
    If +$Get(tIds) '= 1 Quit
    Set tForeign = ##class(OcuPilot.Test.Retention).ForeignExpired()
    Do $$$AssertEquals(tForeign, "", "no row another suite created is past its retention, so a run removes nothing of theirs")
    If tForeign '= "" Quit
    Set tRetention = "OcuPilot.Test.Retention"
    Set tDefinition = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tDefinition.Name = "OcuPilotProbeRetentionTask"
    Set tDefinition.Provider = "anthropic"
    Set tDefinition.Model = "probe"
    Set tDefinition.RetentionDays = 1
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tDefinition), "a probe definition keeping one day exists")
    Set tDefinitionId = tDefinition.%Id()
    Set tDefinition = ""
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", $Parameter(tRetention, "PROBEUSER"), 5, .tLoadSC, .tConflict)
    Set tKey = $Select($IsObject(tConvo): tConvo.ConvKey, 1: "")
    Set tConvo = ""
    Do $$$AssertStatusOK($ClassMethod(tRetention, "Append", tKey, "expired", tDefinitionId), "and a conversation holds an entry of it")
    Do $$$AssertEquals($ClassMethod(tRetention, "Exec", "UPDATE OcuPilot_Kernel_State.Entry SET AppendedAt = ? WHERE %EXACT(ConvoKey) = ?", $ClassMethod(tRetention, "DaysAgo", 2), tKey), 0, "two days old")
    Set tId = tIds(1)
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(ID) FROM %SYS_Task.History")
    Set tMark = $Select(tRS.%Next(): +tRS.%GetData(1), 1: 0)
    Set tRunSC = ##class(%SYS.Task).RunNow(tId)
    Set $NAMESPACE = tOrigNS
    Do $$$AssertStatusOK(tRunSC, "a run is requested")

    Set tStatus = ""
    Set tDeadline = $ZHorolog + ..#RUNWAITSECONDS
    While ($ZHorolog < tDeadline) && (tStatus = "") {
        Hang 5
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Status, Error FROM %SYS_Task.History WHERE Task = ? AND ID > ? ORDER BY ID DESC", tId, tMark)
        If tRS.%Next() Set tStatus = tRS.%GetData(1) _ "|" _ tRS.%GetData(2)
        Set $NAMESPACE = tOrigNS
    }
    Do $$$AssertEquals($Piece(tStatus, "|", 1), 1, "the run is recorded as a success: " _ tStatus)
    Do $$$AssertEquals($ClassMethod(tRetention, "Count", "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = ?", tKey), 0, "and the run removed the expired entry")
    Do ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tKey)
    Do ##class(OcuPilot.Kernel.State.Agent).GuardedDeleteId(tDefinitionId)
}

/// <p>A probe profile schedules no task, and its uninstall leaves the production task in place:
/// only the production install owns the one task of the class.</p>
/// <p>Mutation (Rule 19): drop the probe branch from the retention task's names in
/// <method>OcuPilot.Install.Installer.Names</method> -- the probe uninstall deletes the production
/// task and this goes red.</p>
Method TestAProbeProfileSchedulesNoTaskAndLeavesTheProductionOne()
{
    Do $$$AssertStatusOK(..TaskIds(.tBefore), "the tasks read")
    Do $$$AssertEquals(+$Get(tBefore), 1, "the production install's task is scheduled")
    If +$Get(tBefore) '= 1 Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install("probe"), "the probe profile installs")
    Do $$$AssertStatusOK(..TaskIds(.tInstalled), "the tasks read")
    Do $$$AssertEquals(+$Get(tInstalled) _ "|" _ $Get(tInstalled(1)), "1|" _ tBefore(1), "and schedules no task of its own")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Uninstall("probe", 1), "the probe profile uninstalls")
    Do $$$AssertStatusOK(..TaskIds(.tAfter), "the tasks read")
    Do $$$AssertEquals(+$Get(tAfter) _ "|" _ $Get(tAfter(1)), "1|" _ tBefore(1), "and the production task is left in place")
}

/// <p>DW-1750: <method>OcuPilot.Install.Installer.Uninstall</method>'s own body carries the
/// statement <code>Set tSC = ..RemoveRetentionTask(.tNames)</code> on a line of its own, not
/// commented out and not behind a one-line condition. A production <code>Uninstall</code> would
/// tear down the instance under this suite, and a probe profile names no task class, so the
/// statement is read from the method's own implementation rather than run;
/// <method>TestInstallSchedulesExactlyOneTaskAndRepairsDrift</method> runs the step it calls.</p>
/// <p>Mutation (Rule 19): comment out the call in
/// <method>OcuPilot.Install.Installer.Uninstall</method> with <code>;</code> -- this goes red.</p>
Method TestUninstallsBodyCallsRemoveRetentionTask()
{
    Set tMethod = ##class(%Dictionary.MethodDefinition).%OpenId("OcuPilot.Install.Installer||Uninstall")
    Do $$$AssertTrue($IsObject(tMethod), "Uninstall's definition opens")
    If '$IsObject(tMethod) Quit
    Set tFound = 0
    Do tMethod.Implementation.Rewind()
    While 'tMethod.Implementation.AtEnd {
        Set tLine = $ZStrip(tMethod.Implementation.ReadLine(), "<>WC")
        If tLine = "Set tSC = ..RemoveRetentionTask(.tNames)" Set tFound = tFound + 1
    }
    Set tMethod = ""
    Do $$$AssertEquals(tFound, 1, "Uninstall's own body runs the retention task's removal once, as a statement of its own")
}

}
