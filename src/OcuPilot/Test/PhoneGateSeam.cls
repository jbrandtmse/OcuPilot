/// <p><class>OcuPilot.Port.PhoneProviderPort</class> with its pair sets evaluated through <class>OcuPilot.Test.ScreenGate</class>, whose held set a
/// test declares, so <class>OcuPilot.Test.PhoneProviderRead</class> drives the port's refusal in a process holding <code>%All</code>; and with
/// <method>VendorWrite</method> and <method>VendorDelete</method> recording the call instead of making it, so a test sees which writes reached the
/// vendor and no provider changes. <method>Reset</method> forgets the record.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.PhoneGateSeam Extends OcuPilot.Port.PhoneProviderPort
{

/// <p>The test gate, in place of the instance's own answer.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.ScreenGate"
}

/// <p>No recorded vendor call.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotPhoneCalls
}

/// <p>The vendor calls recorded since <method>Reset</method>, as <code>CREATE|name|gateway</code>, <code>MODIFY|name|gateway</code> and
/// <code>DELETE|name</code> joined by <code>;</code>.</p>
ClassMethod Calls() As %String
{
    Set tCalls = ""
    Set tIndex = ""
    For {
        Set tIndex = $Order(^||OcuPilotPhoneCalls(tIndex), 1, tCall)
        If tIndex = "" Quit
        Set tCalls = tCalls _ $Select(tCalls = "": "", 1: ";") _ tCall
    }
    Quit tCalls
}

/// <p>Record the write and make none.</p>
ClassMethod VendorWrite(pName As %String, pGateway As %String, pCreate As %Boolean) As %Status [ Private ]
{
    Set ^||OcuPilotPhoneCalls($Increment(^||OcuPilotPhoneCalls)) = $Select(pCreate: "CREATE", 1: "MODIFY") _ "|" _ pName _ "|" _ pGateway
    Quit $$$OK
}

/// <p>Record the delete and make none.</p>
ClassMethod VendorDelete(pName As %String) As %Status [ Private ]
{
    Set ^||OcuPilotPhoneCalls($Increment(^||OcuPilotPhoneCalls)) = "DELETE|" _ pName
    Quit $$$OK
}

}
