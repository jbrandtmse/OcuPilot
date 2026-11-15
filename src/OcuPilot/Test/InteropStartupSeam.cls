/// <p><class>OcuPilot.Port.InteropPort</class> with its startup seams answerable by a test and its two vendor calls recorded
/// (Story 24.3): <method>AllNamespacesReadable</method> and <method>DefaultReadOnly</method> answer what <method>Arm</method> set until
/// <method>Restore</method>, and <method>VendorSetAutoStart</method> and <method>VendorSetShutdownGroup</method> note each call in
/// <method>Calls</method> before making it. The state is process-private. Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropStartupSeam Extends OcuPilot.Port.InteropPort
{

/// <p>Answer <var>pAllReadable</var> to the all-namespaces question and <var>pReadOnly</var> to the read-only one, and forget the
/// calls recorded.</p>
ClassMethod Arm(pAllReadable As %Boolean, pReadOnly As %Boolean)
{
    Kill ^||OcuPilotStartupSeam
    Set ^||OcuPilotStartupSeam("all") = ''pAllReadable
    Set ^||OcuPilotStartupSeam("readOnly") = ''pReadOnly
}

/// <p>The shipped answers again, and no call recorded.</p>
ClassMethod Restore()
{
    Kill ^||OcuPilotStartupSeam
}

/// <p>The vendor calls made since <method>Arm</method>, as <code>SetAutoStart(name,priority)</code> and
/// <code>SetProductionShutdownGroup(name,group)</code> joined by <code>;</code>.</p>
ClassMethod Calls() As %String
{
    Quit $Get(^||OcuPilotStartupSeam("calls"))
}

ClassMethod Note(pCall As %String)
{
    Set ^||OcuPilotStartupSeam("calls") = $Get(^||OcuPilotStartupSeam("calls")) _ $Select($Get(^||OcuPilotStartupSeam("calls")) = "": "", 1: ";") _ pCall
}

ClassMethod AllNamespacesReadable(pType As %String) As %Boolean
{
    If $Data(^||OcuPilotStartupSeam("all")) Quit ^||OcuPilotStartupSeam("all")
    Quit ##super(pType)
}

ClassMethod DefaultReadOnly(pNamespace As %String) As %Boolean
{
    If $Data(^||OcuPilotStartupSeam("readOnly")) Quit ^||OcuPilotStartupSeam("readOnly")
    Quit ##super(pNamespace)
}

ClassMethod VendorSetAutoStart(pName As %String, pPriority As %String = "") As %Status
{
    Do ..Note("SetAutoStart(" _ pName _ "," _ pPriority _ ")")
    Quit ##super(pName, pPriority)
}

ClassMethod VendorSetShutdownGroup(pName As %String, pGroup As %Integer) As %Status
{
    Do ..Note("SetProductionShutdownGroup(" _ pName _ "," _ pGroup _ ")")
    Quit ##super(pName, pGroup)
}

}
