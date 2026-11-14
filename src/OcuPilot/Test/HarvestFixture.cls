/// <p>Harvested-body fixture for <class>OcuPilot.Test.Harvest</class>: one class that extends
/// <class>OcuPilot.Port.Harvest.Handler</class>, with a method for each case the port must tell
/// apart. <method>TaskList</method> is the sibling suite's body at its current revision, changed
/// only by its base class and the renamed helper call.</p>
/// <p>Every other method counts its run in <code>^||OcuPilotHarvestFixture</code> first, before it
/// touches <code>$NAMESPACE</code>, so a test reads <method>Runs</method> to see whether the port ran
/// the body at all.</p>
Class OcuPilot.Test.HarvestFixture Extends OcuPilot.Port.Harvest.Handler
{

/// <p>Forget the run counter.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotHarvestFixture
}

/// <p>How many counted bodies ran since <method>Reset</method>.</p>
ClassMethod Runs() As %Integer
{
    Quit +$Get(^||OcuPilotHarvestFixture)
}

/// <p>Count one run.</p>
ClassMethod Count() [ Private ]
{
    Set tRuns = $Increment(^||OcuPilotHarvestFixture)
}

/// List all scheduled tasks with details.
/// <p>Queries <code>%SYS.Task:TaskListDetail</code> named query in %SYS
/// namespace to return all scheduled tasks with schedule, status, and
/// configuration information.</p>
ClassMethod TaskList() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = {}
        Set tTasks = []

        Set tRS = ##class(%ResultSet).%New("%SYS.Task:TaskListDetail")
        Set tSC2 = tRS.Execute()
        If $$$ISERR(tSC2) {
            Set $NAMESPACE = tOrigNS
            Do ..RenderResponseBody(..SanitizeError(tSC2))
            Set tSC = $$$OK
            Quit
        }

        While tRS.Next() {
            Set tTask = {}
            Do tTask.%Set("id", tRS.Get("ID"), "number")
            Do tTask.%Set("name", tRS.Get("Task Name"))
            Do tTask.%Set("description", tRS.Get("Description"))
            Do tTask.%Set("taskClass", tRS.Get("TaskClass"))
            Do tTask.%Set("namespace", tRS.Get("Namespace"))
            Do tTask.%Set("suspended", tRS.Get("Suspended"))
            Do tTask.%Set("priority", tRS.Get("Priority"))
            Do tTask.%Set("runInterval", tRS.Get("Run Interval"))
            Do tTask.%Set("nextScheduledDate", tRS.Get("Next Scheduled Date"))
            Do tTask.%Set("nextScheduledTime", tRS.Get("Next Scheduled Time"))
            Do tTask.%Set("lastStarted", tRS.Get("Last Started"))
            Do tTask.%Set("lastFinished", tRS.Get("Last Finished"))
            Do tTask.%Set("lastStatus", tRS.Get("Last Status"))
            Do tTask.%Set("lastResult", tRS.Get("Last Result"))
            Do tTasks.%Push(tTask)
        }
        Do tRS.Close()

        Do tResult.%Set("tasks", tTasks)
        Do tResult.%Set("count", tTasks.%Size(), "number")
        Set $NAMESPACE = tOrigNS
        Do ..RenderResponseBody($$$OK, , tResult)
    }
    Catch ex {
        Set $NAMESPACE = tOrigNS
        Do ..RenderResponseBody(..SanitizeError(ex.AsStatus()))
        Set tSC = $$$OK
    }
    Quit $$$OK
}

/// <p>One success: the bare result.</p>
ClassMethod Success() As %Status
{
    Do ..Count()
    Do ..RenderResponseBody($$$OK, , {"a":1})
    Quit $$$OK
}

/// <p>A vendor failure sanitized the way the harvested bodies do.</p>
ClassMethod Failure() As %Status
{
    Do ..Count()
    Do ..RenderResponseBody(..SanitizeError($$$ERROR($$$GeneralError, "vendor text X")))
    Quit $$$OK
}

/// <p>An access refusal: a <code>&lt;PROTECT&gt;</code> exception, sanitized.</p>
ClassMethod Protect() As %Status
{
    Do ..Count()
    Try {
        Throw ##class(%Exception.SystemException).%New("<PROTECT>", 0, "Fixture+1^OcuPilot.Test.HarvestFixture.1")
    } Catch ex {
        Do ..RenderResponseBody(..SanitizeError(ex.AsStatus()))
    }
    Quit $$$OK
}

/// <p>A raw status the fault mapping classifies as not found.</p>
ClassMethod Absent() As %Status
{
    Do ..Count()
    Do ..RenderResponseBody($$$ERROR($$$LoadObjectNotFound, "Thing", "id"))
    Quit $$$OK
}

/// <p>Two renders: a not-found status, then a success. The port answers neither.</p>
ClassMethod Twice() As %Status
{
    Do ..Count()
    Do ..RenderResponseBody($$$ERROR($$$LoadObjectNotFound, "Thing", "id"))
    Do ..RenderResponseBody($$$OK, , {"a":1})
    Quit $$$OK
}

/// <p>No render.</p>
ClassMethod Never() As %Status
{
    Do ..Count()
    Quit $$$OK
}

/// <p>A helper called while the namespace is switched to <code>%SYS</code>, then restored.</p>
ClassMethod Switched() As %Status
{
    Do ..Count()
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Do ..RenderResponseBody(..SanitizeError($$$ERROR($$$GeneralError, "vendor text X")))
    Set $NAMESPACE = tOrigNS
    Quit $$$OK
}

/// <p>Renders a success and returns with the namespace still switched to <code>%SYS</code>.</p>
ClassMethod Strand() As %Status
{
    Do ..Count()
    Set $NAMESPACE = "%SYS"
    Do ..RenderResponseBody($$$OK, , {"a":1})
    Quit $$$OK
}

/// <p>Renders a failure and returns with the namespace still switched to <code>%SYS</code>.</p>
ClassMethod StrandFailure() As %Status
{
    Do ..Count()
    Set $NAMESPACE = "%SYS"
    Do ..RenderResponseBody($$$ERROR($$$LoadObjectNotFound, "Thing", "id"))
    Quit $$$OK
}

/// <p>Raises after switching to <code>%SYS</code>.</p>
ClassMethod Raise() As %Status
{
    Do ..Count()
    Set $NAMESPACE = "%SYS"
    Set tValue = 1 / 0
    Quit $$$OK
}

/// <p>A raw status the fault mapping classifies as a conflict.</p>
ClassMethod Conflict() As %Status
{
    Do ..Count()
    Do ..RenderResponseBody($$$ERROR($$$IDKeyNotUnique, "Thing", "IDKEY", "id"))
    Quit $$$OK
}

/// <p>A raw status the fault mapping classifies as a validation refusal.</p>
ClassMethod Validation() As %Status
{
    Do ..Count()
    Do ..RenderResponseBody($$$ERROR($$$PropertyRequired, "Name"))
    Quit $$$OK
}

/// <p>A raw status the fault mapping classifies as not implemented.</p>
ClassMethod NotImplemented() As %Status
{
    Do ..Count()
    Do ..RenderResponseBody($$$ERROR($$$NotImplemented))
    Quit $$$OK
}

/// <p>Renders a success with a message part.</p>
ClassMethod Console() As %Status
{
    Do ..Count()
    Do ..RenderResponseBody($$$OK, ["note"], {"a":1})
    Quit $$$OK
}

/// <p>Renders a success with no result part.</p>
ClassMethod Bare() As %Status
{
    Do ..Count()
    Do ..RenderResponseBody($$$OK)
    Quit $$$OK
}

/// <p>Renders a failure with a message part.</p>
ClassMethod ConsoleFailure() As %Status
{
    Do ..Count()
    Do ..RenderResponseBody($$$ERROR($$$LoadObjectNotFound, "Thing", "id"), ["vendor line"])
    Quit $$$OK
}

/// <p>Answers the two arguments it was called with.</p>
ClassMethod Args(pFirst As %String, pSecond As %String) As %Status
{
    Do ..Count()
    Do ..RenderResponseBody($$$OK, , {"first":(pFirst),"second":(pSecond)})
    Quit $$$OK
}

/// <p>Writes to the device, then renders a success.</p>
ClassMethod Chatter() As %Status
{
    Do ..Count()
    Do $System.Status.DisplayError($$$ERROR($$$GeneralError, "chatter"))
    Do ..RenderResponseBody($$$OK, , {"chatter":true})
    Quit $$$OK
}

/// <p>Answers what the stub request carries: the query key <code>k</code>, the JSON body and the
/// method.</p>
ClassMethod Echo() As %Status
{
    Do ..Count()
    Set tResult = {}
    Do tResult.%Set("k", %request.Get("k"))
    Do tResult.%Set("method", %request.Method)
    Set tSC = ..ReadRequestBody(.tBody)
    If $IsObject(tBody) Do tResult.%Set("body", tBody)
    Do ..RenderResponseBody($$$OK, , tResult)
    Quit $$$OK
}

}
