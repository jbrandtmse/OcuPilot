/// <p>Test-only <class>OcuPilot.Port.ProcessPort</class> subclass with two replaced seams: it records
/// the query parameter names the vendor endpoint is handed, so a test can see what the port removed
/// before the admin port's own sequence ran, and after <method>Deny</method> it answers that the
/// caller holds no resource, so a test can drive the port's own gate. Nothing else changes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ProcessPortProbe Extends OcuPilot.Port.ProcessPort
{

/// <p>Record the names <code>%request.Data</code> carries, comma-separated, in
/// <code>^||OcuPilotProcessPortProbe("params")</code>.</p>
ClassMethod OnBeforeRun(pEndpoint As %RegisteredObject)
{
    Try {
        Set tNames = ""
        Set tName = $Order(%request.Data(""))
        While tName '= "" {
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName
            Set tName = $Order(%request.Data(tName))
        }
        Set ^||OcuPilotProcessPortProbe("params") = tNames
    } Catch {
    }
}

/// <p>Answer that the caller holds no resource while <method>Deny</method> is in force; otherwise
/// the admin port's own check.</p>
ClassMethod HoldsResource(pResource As %String) As %Boolean
{
    If $Get(^||OcuPilotProcessPortProbe("deny")) Quit 0
    Quit ##super(pResource)
}

/// <p>Refuse every resource until <method>Clear</method>.</p>
ClassMethod Deny()
{
    Set ^||OcuPilotProcessPortProbe("deny") = 1
}

/// <p>The names the last call recorded, or <code>""</code>.</p>
ClassMethod RecordedParams() As %String
{
    Quit $Get(^||OcuPilotProcessPortProbe("params"))
}

/// <p>Forget what was recorded.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotProcessPortProbe
}

}
