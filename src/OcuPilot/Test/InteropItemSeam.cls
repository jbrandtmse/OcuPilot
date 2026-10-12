/// <p><class>OcuPilot.Port.InteropPort</class> with its pair sets evaluated through
/// <class>OcuPilot.Test.ScreenGate</class> (<class>OcuPilot.Test.InteropGateSeam</class>), and with the three
/// facts a throwaway cannot arrange named by a test (Story 20.3): the resource guarding the routines
/// database, which in <code>USER</code> is the globals database's and so cannot be withheld alone;
/// whether the namespace is under source control; and the lines the port logs. Each is armed by
/// <method>Arm</method> and cleared by <method>Disarm</method>. Nothing else differs from the shipped
/// port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropItemSeam Extends OcuPilot.Test.InteropGateSeam
{

/// <p>Name <var>pRoutineResource</var> as the routines database's resource when it is not empty, and answer
/// source control when <var>pSourceControlled</var> is 1; clear the log.</p>
ClassMethod Arm(pRoutineResource As %String = "", pSourceControlled As %Boolean = 0)
{
    Set ^||OcuPilotInteropItemRoutine = pRoutineResource
    Set ^||OcuPilotInteropItemSource = ''pSourceControlled
    Kill ^||OcuPilotInteropItemLog
}

/// <p>The shipped answers again, and an empty log.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotInteropItemRoutine
    Kill ^||OcuPilotInteropItemSource
    Kill ^||OcuPilotInteropItemLog
    Kill ^||OcuPilotInteropItemSend
    Kill ^||OcuPilotInteropItemSent
    Kill ^||OcuPilotInteropItemJobCode
    Kill ^||OcuPilotInteropItemAbortMode
    Kill ^||OcuPilotInteropItemMove
}

/// <p>Answer the next job writes with a vendor status carrying code <var>pCode</var> instead of calling the vendor (Story 20.23), so a
/// refusal the vendor gives only under load or a held lock reaches the port's own mapping. <method>Disarm</method> clears it.</p>
ClassMethod RefuseJobWith(pCode As %String)
{
    Set ^||OcuPilotInteropItemJobCode = pCode
}

ClassMethod VendorJob(pNamespace As %String, pType As %String, pPid As %String, pCap As %Integer, Output pCaught) As %Status [ Private ]
{
    If $Get(^||OcuPilotInteropItemJobCode) '= "" {
        Set pCaught = ""
        Quit $System.Status.Error(^||OcuPilotInteropItemJobCode, pPid, pCap)
    }
    Quit ##super(pNamespace, pType, pPid, pCap, .pCaught)
}

/// <p>Send the probe production one message just after the next queue entry is aborted (Story 20.23), so it joins the queue after a
/// queue abort has enumerated the entries and before the abort is done. <method>Disarm</method> clears it.</p>
ClassMethod SendAfterNextAbort()
{
    Set ^||OcuPilotInteropItemSend = 1
}

/// <p>How many messages <method>SendAfterNextAbort</method> sent since <method>Disarm</method>.</p>
ClassMethod Sent() As %Integer
{
    Quit +$Get(^||OcuPilotInteropItemSent)
}

/// <p>Make the next queue entry abort reach the vendor twice (Story 20.23), so the second call answers the vendor's error for an entry that
/// is no longer there, as when another process took it first. <method>Disarm</method> clears it.</p>
ClassMethod AbortItemGoneOnce()
{
    Set ^||OcuPilotInteropItemAbortMode = "goneonce"
}

/// <p>Answer every queue entry abort with a vendor error, without calling the vendor, so the entry stays queued.
/// <method>Disarm</method> clears it.</p>
ClassMethod AbortItemRefused()
{
    Set ^||OcuPilotInteropItemAbortMode = "refused"
}

ClassMethod VendorAbortItem(pNamespace As %String, pQueue As %String, pPriority As %Integer, pIndex As %Integer, Output pCaught) As %Status [ Private ]
{
    Set tMode = $Get(^||OcuPilotInteropItemAbortMode)
    If tMode = "refused" {
        Set pCaught = ""
        Quit $System.Status.Error(5001, "abort refused for the test")
    }
    Set tSC = ##super(pNamespace, pQueue, pPriority, pIndex, .pCaught)
    If tMode = "goneonce" {
        Kill ^||OcuPilotInteropItemAbortMode
        Set tSC = ##super(pNamespace, pQueue, pPriority, pIndex, .pCaught)
    }
    If $Get(^||OcuPilotInteropItemSend) {
        Kill ^||OcuPilotInteropItemSend
        If $$$ISOK($ClassMethod("OcuPilot.Test.ProductionProbe", "Send")) Set ^||OcuPilotInteropItemSent = 1
    }
    Quit tSC
}

/// <p>Store <var>pValue</var> for <var>pKey</var> of lookup table <var>pTable</var>, creating the entry, just before the next
/// <method>LockTable</method> of that table (Story 20.5), so the table moves between a write's first read and its lock.
/// <method>Disarm</method> clears it.</p>
ClassMethod MoveTableBeforeLock(pTable As %String, pKey As %String, pValue As %String)
{
    Set ^||OcuPilotInteropItemMove = $ListBuild(pTable, pKey, pValue)
}

/// <p>The shipped lock, after the one move <method>MoveTableBeforeLock</method> armed for this table.</p>
ClassMethod LockTable(pTable As %String) As %Boolean
{
    If $Data(^||OcuPilotInteropItemMove) {
        Set tMove = ^||OcuPilotInteropItemMove
        If $List(tMove, 1) = pTable {
            Kill ^||OcuPilotInteropItemMove
            Do ##class(Ens.Util.LookupTable).%UpdateValue(pTable, $List(tMove, 2), $List(tMove, 3), 1)
        }
    }
    Quit ##super(pTable)
}

ClassMethod RoutineResource(pNamespace As %String, Output pResource As %String) As %Boolean
{
    If $Get(^||OcuPilotInteropItemRoutine) '= "" {
        Set pResource = ^||OcuPilotInteropItemRoutine
        Quit 1
    }
    Quit ##super(pNamespace, .pResource)
}

ClassMethod SourceControlled(pNamespace As %String) As %Boolean
{
    If $Get(^||OcuPilotInteropItemSource) Quit 1
    Quit ##super(pNamespace)
}

/// <p>Keep the line instead of logging it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set ^||OcuPilotInteropItemLog($Increment(^||OcuPilotInteropItemLog)) = pMessage
}

/// <p>How many lines the port logged since <method>Arm</method>.</p>
ClassMethod Logged() As %Integer
{
    Quit +$Get(^||OcuPilotInteropItemLog)
}

}
