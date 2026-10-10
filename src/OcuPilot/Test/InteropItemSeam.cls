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
