/// <p><class>OcuPilot.Port.AuditPort</class> with its pairs evaluated through <class>OcuPilot.Test.ScreenGate</class>, whose
/// held set a test declares, so <class>OcuPilot.Test.AuditExportWrite</class> drives the export's gate in a process holding
/// <code>%All</code>; and with <method>VendorStart</method> recording the call instead of making it, so a test sees whether
/// a refusal came before any task started. <method>Reset</method> forgets the record.</p>
/// <p>Nothing here overrides the file resolution: the real <class>OcuPilot.Port.PathPort</class> answers.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AuditExportSeam Extends OcuPilot.Port.AuditPort
{

/// <p>Whether the declared set holds <var>pPair</var>, in place of the instance's own answer.</p>
ClassMethod HoldsPair(pPair As %String) As %Boolean
{
    Quit ##class(OcuPilot.Test.ScreenGate).HoldsPrivilege($Piece(pPair, ":", 1), $Piece(pPair, ":", 2))
}

/// <p>No recorded vendor call.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotAuditExportCalls
}

/// <p>The vendor calls recorded since <method>Reset</method>, as <code>file|day</code> joined by <code>;</code>.</p>
ClassMethod Calls() As %String
{
    Set tCalls = ""
    Set tIndex = ""
    For {
        Set tIndex = $Order(^||OcuPilotAuditExportCalls(tIndex), 1, tCall)
        If tIndex = "" Quit
        Set tCalls = tCalls _ $Select(tCalls = "": "", 1: ";") _ tCall
    }
    Quit tCalls
}

/// <p>Record the start and make none.</p>
ClassMethod VendorStart(pFile As %String, pBefore As %String, Output pJob As %Integer) As %Status [ Private ]
{
    Set pJob = 1
    Set ^||OcuPilotAuditExportCalls($Increment(^||OcuPilotAuditExportCalls)) = pFile _ "|" _ pBefore
    Quit $$$OK
}

}
