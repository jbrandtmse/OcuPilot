/// <p>What Story 24.17 Batch 4's workflow task suites arrange beyond <class>OcuPilot.Test.InteropWorkflowFixture</class>: a probe task stored under a chosen id in either namespace, the probe
/// tasks' facts and worklist users read exactly, and a live task, one a probe business process sent through the vendor's own <class>EnsLib.Workflow.Operation</class> in the probe production
/// of <class>OcuPilot.Test.ProductionProbe</class> in <code>USER</code>, which its response is delivered to. <method>DropProbes</method> also takes the live state: the production is stopped
/// and removed, its messages, log rows and the process's rows are swept, and the process's received responses are forgotten.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. It runs only on a throwaway instance, which sets the arming variable the probe names.</p>
Class OcuPilot.Test.InteropWorkflowTaskFixture Extends OcuPilot.Test.InteropWorkflowFixture
{

/// <p>The probe business process the live task is sent by, and its production item's name; the workflow operation's item is named for the role.</p>
Parameter PROCCLASS = "OcuPilotProbe.Workflow.Proc";

Parameter PROCNAME = "OcuP2417wLiveProc";

/// <p>The live state is kept in <code>^IRIS.Temp.OcuP2417wLive</code> (the flag that it was made, and under <code>mark</code> the event mark taken before it was) and the responses the process
/// received in <code>^IRIS.Temp.OcuP2417wRecv</code>.</p>
/// <p>The text of the probe business process: it sends one task of the role its <code>TargetRole</code> names and records the response it is given.</p>
ClassMethod ProcText() As %String [ Private ]
{
    Set tText = ""
    For tLine = "Class " _ ..#PROCCLASS _ " Extends Ens.BusinessProcess", "{", "Parameter INVOCATION = ""Queue"";", "Parameter SETTINGS = ""TargetRole:Probe"";", "Property TargetRole As %String;", "Method OnRequest(pRequest As Ens.Request, Output pResponse As Ens.Response) As %Status", "{", " Set tTask = ##class(EnsLib.Workflow.TaskRequest).%New()", " Set tTask.%Subject = """ _ ..#TASKSUBJECT _ """", " Set tTask.%Message = ""probe""", " Set tTask.%Actions = ""Approve,Reject""", " Quit ..SendRequestAsync(..TargetRole, tTask, 1, ""wf"")", "}", "Method OnResponse(pRequest As Ens.Request, ByRef pResponse As Ens.Response, pCallRequest As Ens.Request, pCallResponse As Ens.Response, pCompletionKey As %String) As %Status", "{", " Set ^IRIS.Temp.OcuP2417wRecv($Increment(^IRIS.Temp.OcuP2417wRecv)) =..%ConfigName _ ""|"" _ pCallResponse.%Id() _ ""|"" _ pCallResponse.%Status _ ""|"" _ pCallResponse.%Action", " Quit $$$OK", "}", "}" {
        Set tText = tText _ tLine _ $Char(13, 10)
    }
    Quit tText
}

/// <p>Store a task of the role <var>pRole</var> in <var>pNamespace</var> under the id <var>pId</var>, assigned to <var>pOwner</var> (empty for none) with a worklist item for
/// <var>pWorklistUser</var> when that is not empty, by raising the namespace's message body counter to two below the id first (the task's request takes the id before it); answers the task's id,
/// or 0 when the namespace's counter is already above that.</p>
ClassMethod ProbeTaskWithId(pId As %Integer, pRole As %String, pOwner As %String, pWorklistUser As %String, pNamespace As %String = {..#SOURCE}) As %Integer
{
    Set tId = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        ; The task's request takes the id before the response does.
        If +$Get(^Ens.MessageBodyD) '> (pId - 2) {
            Set tWas = +$Get(^Ens.MessageBodyD)
            Set ^Ens.MessageBodyD = pId - 2
            Set $NAMESPACE = tOrigNS
            Set tId = ..ProbeTask(pRole, pOwner, pWorklistUser, pNamespace)
            ; What the counter held before and holds now, so DropProbes puts it back when nothing moved it since.
            Set $NAMESPACE = pNamespace
            Set ^IRIS.Temp.OcuP2417wBody(pNamespace) = $ListBuild(tWas, +$Get(^Ens.MessageBodyD))
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tId = 0
    }
    Quit tId
}

/// <p>Mark the probe task <var>pId</var> of <var>pNamespace</var> complete with the status <var>pStatus</var> and take its worklist items, as a task the engine finished is left.</p>
ClassMethod CompleteProbe(pId As %String, pStatus As %String = "Completed", pNamespace As %String = {..#SOURCE}) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tTask = ##class(EnsLib.Workflow.TaskResponse).%OpenId(pId)
        Set tTask.%TaskStatus.IsComplete = 1
        Set tTask.%Status = pStatus
        Set tSC = tTask.%Save()
        Set tTask = ""
        Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "DELETE FROM EnsLib_Workflow.Worklist WHERE Task = ?", pId)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The child process: open the task <var>pId</var> of <code>USER</code> at concurrency 4, which holds its lock, tell process <var>pParent</var> whether that worked, and hold it
/// <var>pSeconds</var> seconds.</p>
ClassMethod HoldTask(pParent As %Integer, pId As %String, pSeconds As %Integer)
{
    Set tHeld = 0
    Try {
        Set $NAMESPACE = ..#SOURCE
        Set tTask = ##class(EnsLib.Workflow.TaskResponse).%OpenId(pId, 4)
        Set tHeld = $IsObject(tTask)
        Do $System.Event.Signal(pParent, tHeld)
        Hang pSeconds
        Set tTask = ""
    } Catch {
        If 'tHeld Do $System.Event.Signal(pParent, 0)
    }
}

/// <p>Hold the lock of the probe task <var>pId</var> in a child process for <var>pSeconds</var> seconds, and answer 1 once it holds it, 0 when it could not.</p>
ClassMethod HoldLock(pId As %String, pSeconds As %Integer) As %Boolean
{
    Do $System.Event.Clear($Job)
    Job ##class(OcuPilot.Test.InteropWorkflowTaskFixture).HoldTask($Job, pId, pSeconds)::10
    If '$Test Quit 0
    Set tMessage = $System.Event.WaitMsg("", 20)
    Quit ($ListGet(tMessage, 1) = 1) && ($ListGet(tMessage, 2) = 1)
}

/// <p>Set the priority of the probe task <var>pId</var> of <var>pNamespace</var> to <var>pPriority</var>, which the probe tasks are stored without.</p>
ClassMethod SetPriority(pId As %String, pPriority As %Integer, pNamespace As %String = {..#SOURCE}) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tOk = 0
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "UPDATE EnsLib_Workflow.TaskResponse SET %Priority = ? WHERE %ID = ?", pPriority, pId)
        Set tOk = (tRS.%SQLCODE = 0)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tOk
}

/// <p>The id both namespaces can store a probe task under: two above the higher of their message body counters, the task's request taking the id below it.</p>
ClassMethod SharedId() As %Integer
{
    Set tMax = 0
    Set tOrigNS = $NAMESPACE
    For tNamespace = ..#SOURCE, ..#OTHER {
        Try {
            Set $NAMESPACE = tNamespace
            Set tCounter = +$Get(^Ens.MessageBodyD)
            Set $NAMESPACE = tOrigNS
            If tCounter > tMax Set tMax = tCounter
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
    }
    Quit tMax + 2
}

/// <p>The task <var>pId</var> of <var>pNamespace</var> as <code>role|assignedTo|priority|status|complete</code>, or <code>&lt;absent&gt;</code>.</p>
ClassMethod TaskText(pNamespace As %String, pId As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "<absent>"
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT TaskStatus_RoleName, TaskStatus_AssignedTo, %Priority, %Status, TaskStatus_IsComplete FROM EnsLib_Workflow.TaskResponse WHERE %ID = ?", pId)
        If (tRS.%SQLCODE = 0) && tRS.%Next() Set tText = tRS.%GetData(1) _ "|" _ tRS.%GetData(2) _ "|" _ +tRS.%GetData(3) _ "|" _ tRS.%GetData(4) _ "|" _ tRS.%GetData(5)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tText = "<unreadable>"
    }
    Quit tText
}

/// <p>The users the task <var>pId</var> of <var>pNamespace</var> sits on the worklist of, comma-separated in name order; <code>-</code> for none.</p>
ClassMethod ItemUsers(pNamespace As %String, pId As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT UserName FROM EnsLib_Workflow.Worklist WHERE Task = ? ORDER BY UserName", pId)
        While (tRS.%SQLCODE = 0) && tRS.%Next() {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRS.%GetData(1)
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tText = "<unreadable>"
    }
    Quit $Select(tText = "": "-", 1: tText)
}

/// <p>How many worklist items and tasks <var>pNamespace</var> holds, as <code>items|tasks</code>, whoever they belong to.</p>
ClassMethod TaskCounts(pNamespace As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = "?"
    Try {
        Set $NAMESPACE = pNamespace
        Set tText = ..CountOf("SELECT COUNT(*) FROM EnsLib_Workflow.Worklist") _ "|" _ ..CountOf("SELECT COUNT(*) FROM EnsLib_Workflow.TaskResponse")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tText = "?"
    }
    Quit tText
}

/// <p>Make the live state in <code>USER</code>: the probe production with the workflow operation of the role <var>pRole</var>, which the caller has stored with its members, and the probe
/// business process that sends to it, started and running. A failing status says what did not come. <method>DropProbes</method> takes it all away.</p>
ClassMethod LiveStart(pRole As %String) As %Status
{
    Set tProbe = "OcuPilot.Test.ProductionProbe"
    Set tSC = $ClassMethod(tProbe, "CheckOwn")
    If $$$ISERR(tSC) Quit tSC
    Set ^IRIS.Temp.OcuP2417wLive = 1
    Kill ^IRIS.Temp.OcuP2417wRecv
    Set tSC = $ClassMethod(tProbe, "Remove")
    Set ^IRIS.Temp.OcuP2417wLive("mark") = $ClassMethod(tProbe, "HighWater")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#SOURCE
        Set tCounter = +$Get(^Ens.MessageHeaderD)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCounter = 0
    }
    Set ^IRIS.Temp.OcuP2417wLive("counter") = tCounter
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tProbe, "Create")
    If $$$ISOK(tSC) Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#SOURCE, ..#PROCCLASS, ..ProcText())
    If $$$ISOK(tSC) {
        Set tOrigNS = $NAMESPACE
        Try {
            Set $NAMESPACE = ..#SOURCE
            Set tSC = $System.OBJ.Compile(..#PROCCLASS, "ck-d")
            Set $NAMESPACE = tOrigNS
        } Catch ex {
            Set $NAMESPACE = tOrigNS
            Set tSC = ex.AsStatus()
        }
    }
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tProbe, "AddItem", pRole, "EnsLib.Workflow.Operation", 1, 1)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tProbe, "AddItem", ..#PROCNAME, ..#PROCCLASS, 1, 1, "TargetRole", pRole)
    If $$$ISOK(tSC) {
        Set tOrigNS = $NAMESPACE
        Set tProduction = $Parameter(tProbe, "PRODUCTION")
        Try {
            Set $NAMESPACE = ..#SOURCE
            Set tSC = ##class(Ens.Director).StartProduction(tProduction)
            Set $NAMESPACE = tOrigNS
        } Catch ex {
            Set $NAMESPACE = tOrigNS
            Set tSC = ex.AsStatus()
        }
    }
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tProbe, "AwaitRunning", 30)
    Quit tSC
}

/// <p>Stop the live production and leave it stopped, as <class>OcuPilot.Test.ProductionProbe</class> settles it.</p>
ClassMethod LiveStop() As %Status
{
    Quit $ClassMethod("OcuPilot.Test.ProductionProbe", "Settle")
}

/// <p>Start the live production again after <method>LiveStop</method> and wait until it runs.</p>
ClassMethod LiveRestart() As %Status
{
    Set tProbe = "OcuPilot.Test.ProductionProbe"
    Set tOrigNS = $NAMESPACE
    Set tProduction = $Parameter(tProbe, "PRODUCTION")
    Try {
        Set $NAMESPACE = ..#SOURCE
        Set tSC = ##class(Ens.Director).StartProduction(tProduction)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tProbe, "AwaitRunning", 30)
    Quit tSC
}

/// <p>The response token of the task <var>pId</var> in <code>USER</code>, <code>&lt;request header id&gt;|&lt;production&gt;</code>.</p>
ClassMethod TokenOf(pId As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tToken = ""
    Try {
        Set $NAMESPACE = ..#SOURCE
        Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT TaskStatus_ResponseToken FROM EnsLib_Workflow.TaskResponse WHERE %ID = ?", pId)
        If (tRS.%SQLCODE = 0) && tRS.%Next() Set tToken = tRS.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tToken
}

/// <p>Set the response token of the task <var>pId</var> in <code>USER</code> to <var>pToken</var>, which is how a task whose sender is in another production is made.</p>
ClassMethod SetToken(pId As %String, pToken As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tOk = 0
    Try {
        Set $NAMESPACE = ..#SOURCE
        Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "UPDATE EnsLib_Workflow.TaskResponse SET TaskStatus_ResponseToken = ? WHERE %ID = ?", pToken, pId)
        Set tOk = (tRS.%SQLCODE = 0)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tOk
}

/// <p>Set the return queue of the request header <var>pHeader</var> in <code>USER</code> to <var>pQueue</var>, or delete the header when <var>pDelete</var>.</p>
ClassMethod SetHeader(pHeader As %String, pQueue As %String, pDelete As %Boolean = 0) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tOk = 0
    Try {
        Set $NAMESPACE = ..#SOURCE
        If pDelete {
            Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "DELETE FROM Ens.MessageHeader WHERE %ID = ?", pHeader)
        } Else {
            Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "UPDATE Ens.MessageHeader SET ReturnQueueName = ? WHERE %ID = ?", pQueue, pHeader)
        }
        Set tOk = (tRS.%SQLCODE = 0)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tOk
}

/// <p>The return queue of the request header <var>pHeader</var> in <code>USER</code>, or <code>&lt;absent&gt;</code>.</p>
ClassMethod ReturnQueue(pHeader As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tQueue = "<absent>"
    Try {
        Set $NAMESPACE = ..#SOURCE
        Set tRS = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT ReturnQueueName FROM Ens.MessageHeader WHERE %ID = ?", pHeader)
        If (tRS.%SQLCODE = 0) && tRS.%Next() Set tQueue = tRS.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tQueue
}

/// <p>The highest task id <code>USER</code> holds, 0 for none.</p>
ClassMethod TopTask() As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tTop = 0
    Try {
        Set $NAMESPACE = ..#SOURCE
        Set tTop = $Select(..CountOf("SELECT COUNT(*) FROM EnsLib_Workflow.TaskResponse") > 0: ..CountOf("SELECT MAX(%ID) FROM EnsLib_Workflow.TaskResponse"), 1: 0)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tTop
}

/// <p>Send one task through the live business process, wait up to ten seconds until it is stored and sits on a worklist (the vendor saves the task before it sends the items), and answer its
/// id, 0 when none came.</p>
ClassMethod LiveTask() As %Integer
{
    Set tProbe = "OcuPilot.Test.ProductionProbe"
    Set tBefore = ..TopTask()
    Set tSC = $ClassMethod(tProbe, "Send", ..#PROCNAME)
    If $$$ISERR(tSC) Quit 0
    Set tId = 0
    For tTry = 1:1:40 {
        Set tTop = ..TopTask()
        If (tTop > tBefore) && (..ItemUsers(..#SOURCE, tTop) '= "-") {
            Set tId = tTop
            Quit
        }
        Hang 0.25
    }
    Quit tId
}

/// <p>What the live business process was given back, one response for each line as <code>process|task id|status|action</code>, comma-separated in the order they came; <code>-</code> for none.</p>
ClassMethod Received() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^IRIS.Temp.OcuP2417wRecv(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ ^IRIS.Temp.OcuP2417wRecv(tAt)
    }
    Quit $Select(tText = "": "-", 1: tText)
}

/// <p>Wait up to <var>pSeconds</var> until the business process has been given <var>pCount</var> responses; 1 when it has.</p>
ClassMethod AwaitReceived(pCount As %Integer, pSeconds As %Integer = 10) As %Boolean
{
    For tTry = 1:1:(pSeconds * 4) {
        If +$Get(^IRIS.Temp.OcuP2417wRecv) '< pCount Quit
        Hang 0.25
    }
    Quit +$Get(^IRIS.Temp.OcuP2417wRecv) '< pCount
}

/// <p>Take the live state away: sweep the messages and log rows made since <method>LiveStart</method>, delete the business process's rows while its class is still compiled, stop and remove the
/// probe production, forget the received responses and the flag.</p>
ClassMethod DropLive()
{
    Set tProbe = "OcuPilot.Test.ProductionProbe"
    Set tMark = $Get(^IRIS.Temp.OcuP2417wLive("mark"))
    Do $ClassMethod(tProbe, "Settle")
    If tMark '= "" Do $ClassMethod(tProbe, "SweepSince", tMark)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#SOURCE
        Kill tIds
        If ##class(%Dictionary.CompiledClass).%ExistsId(..#PROCCLASS) {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT %ID FROM Ens.BusinessProcess WHERE %ConfigName %STARTSWITH ?", ..#MARKER)
            While tRS.%Next() {
                Set tIds(tRS.%GetData(1)) = ""
            }
            Set tId = ""
            For {
                Set tId = $Order(tIds(tId))
                If tId = "" Quit
                Do ##class(Ens.BusinessProcess).%DeleteId(tId)
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Do $ClassMethod(tProbe, "Remove")
    ; The headers the live state made are gone, so the namespace's header counter goes back toward where it stood: a suite that reads the ids of two namespaces' headers as different
    ; would otherwise meet them equal when this one moved the counter of USER alone. It never goes below the highest header id USER holds.
    Set tCounter = +$Get(^IRIS.Temp.OcuP2417wLive("counter"))
    If (tMark '= "") && (tCounter > 0) {
        Try {
            Set $NAMESPACE = ..#SOURCE
            Do ..LowerCounter("^Ens.MessageHeaderD", tCounter, "")
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
    }
    Kill ^IRIS.Temp.OcuP2417wRecv
    Kill ^IRIS.Temp.OcuP2417wLive
}

/// <p>How many probes are left: <method>OcuPilot.Test.InteropWorkflowFixture.Left</method>'s, and one for each of the live state's flag, the process's received responses, the process's class,
/// the probe production while it is <code>USER</code>'s current one and each row of the probe process.</p>
ClassMethod Left() As %Integer
{
    Set tLeft = ##super()
    If tLeft < 0 Quit tLeft
    If $Data(^IRIS.Temp.OcuP2417wLive) Set tLeft = tLeft + 1
    If $Data(^IRIS.Temp.OcuP2417wRecv) Set tLeft = tLeft + 1
    Set tProduction = $Parameter("OcuPilot.Test.ProductionProbe", "PRODUCTION")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#SOURCE
        If ##class(%Dictionary.ClassDefinition).%ExistsId(..#PROCCLASS) Set tLeft = tLeft + 1
        Do ##class(Ens.Director).GetProductionStatus(.tCurrent, .tState, 2)
        If $Get(tCurrent) = tProduction Set tLeft = tLeft + 1
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Ens.BusinessProcess WHERE %ConfigName %STARTSWITH ?", ..#MARKER)
        If (tRS.%SQLCODE '= 0) || 'tRS.%Next() Throw ##class(%Exception.General).%New("the probe process's rows could not be counted")
        Set tLeft = tLeft + tRS.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tLeft = tLeft + 1000000
    }
    Quit tLeft
}

/// <p>Remove every probe, the live state first when one was made.</p>
ClassMethod DropProbes() As %Boolean
{
    If $Data(^IRIS.Temp.OcuP2417wLive) Do ..DropLive()
    Set tLeft = ##super()
    Do ..RestoreBodyCounters()
    Quit tLeft
}

/// <p>Put back each namespace's message body counter that <method>ProbeTaskWithId</method> raised, when nothing has moved it since, so the two namespaces do not keep the one counter for another
/// suite to read. It never goes below the highest body id the namespace holds, so a probe that was not dropped keeps its id.</p>
ClassMethod RestoreBodyCounters()
{
    Set tOrigNS = $NAMESPACE
    Set tNamespace = ""
    For {
        Set tNamespace = $Order(^IRIS.Temp.OcuP2417wBody(tNamespace), 1, tKept)
        If tNamespace = "" Quit
        Try {
            Set $NAMESPACE = tNamespace
            Do ..LowerCounter("^Ens.MessageBodyD", $List(tKept, 1), $List(tKept, 2))
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
        Kill ^IRIS.Temp.OcuP2417wBody(tNamespace)
    }
}

/// <p>Lower the id counter <var>pGlobal</var> of the current namespace to <var>pTo</var>, or to the highest id the global holds when that is above it, and never raise it; with <var>pAfter</var>
/// only while the counter still reads that value. Answers the counter as left.</p>
ClassMethod LowerCounter(pGlobal As %String, pTo As %Integer, pAfter As %String = "") As %Integer
{
    Set tNow = +$Get(@pGlobal)
    If (pAfter '= "") && (tNow '= pAfter) Quit tNow
    ; The highest numeric id: a string subscript would sort after every number.
    Set tTop = ""
    For {
        Set tTop = $Order(@pGlobal@(tTop), -1)
        If (tTop = "") || (tTop = +tTop) Quit
    }
    Set tTo = $Select(+tTop > pTo: +tTop, 1: +pTo)
    If tTo < tNow Set @pGlobal = tTo
    Quit +$Get(@pGlobal)
}

}
