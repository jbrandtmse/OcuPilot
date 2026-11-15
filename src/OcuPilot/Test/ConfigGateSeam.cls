/// <p><class>OcuPilot.Port.ConfigPort</class> with its pair sets evaluated through <class>OcuPilot.Test.ScreenGate</class>, whose held
/// set a test declares, so <class>OcuPilot.Test.PortGate</class> and <class>OcuPilot.Test.ConfigSettingRead</class> drive the port's
/// refusal in a process holding <code>%All</code>, and with <method>SendProperties</method> recording the call instead of making it, so a
/// test sees what the port would send and no setting changes; <method>VendorRefuses</method> makes it answer an error. Nothing else
/// differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ConfigGateSeam Extends OcuPilot.Port.ConfigPort
{

/// <p>The test gate, in place of the instance's own answer.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.ScreenGate"
}

/// <p>The shipped answers again, and no recorded call.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotConfigRefuses, ^||OcuPilotConfigModifies
}

/// <p>Answer an error from <method>VendorModify</method> until <method>Reset</method>.</p>
ClassMethod VendorRefuses()
{
    Set ^||OcuPilotConfigRefuses = 1
}

/// <p>The calls <method>SendProperties</method> recorded, as <code>class|name|value</code>, comma-joined.</p>
ClassMethod Modifies() As %String
{
    Set tOut = ""
    Set tI = ""
    For {
        Set tI = $Order(^||OcuPilotConfigModifies(tI))
        If tI = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $List(^||OcuPilotConfigModifies(tI), 1)
    }
    Quit tOut
}

/// <p>The keys the last recorded call sent, comma-joined, or <code>""</code> when none was recorded.</p>
ClassMethod SentKeys() As %String
{
    Set tLast = $Order(^||OcuPilotConfigModifies(""), -1)
    If tLast = "" Quit ""
    Quit $List(^||OcuPilotConfigModifies(tLast), 2)
}

ClassMethod SendProperties(pClass As %String, pName As %String, ByRef pProps) As %Status [ Private ]
{
    Set tKeys = ""
    Set tKey = ""
    For {
        Set tKey = $Order(pProps(tKey))
        If tKey = "" Quit
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Set ^||OcuPilotConfigModifies($Increment(^||OcuPilotConfigModifies)) = $ListBuild(pClass _ "|" _ pName _ "|" _ $Get(pProps(pName)), tKeys)
    If $Get(^||OcuPilotConfigRefuses) Quit $$$ERROR($$$GeneralError, "a vendor refusal fed by the test")
    Quit $$$OK
}

}
