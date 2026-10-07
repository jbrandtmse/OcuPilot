/// <p>Test-only <class>OcuPilot.Area.Security.SuperserverRules</class> subclass for the legs the throwaway
/// cannot reach for real: the vendor refuses a server-type SSL/TLS configuration without certificate and key
/// files (#982, measured at Story 18.25's Task 0), so no such configuration exists to be named.
/// <method>ServerConfiguration</method> answers the configuration <parameter>SERVERNAME</parameter> as a
/// server configuration and every other name as the instance reads it, and <method>Windows</method> answers
/// what <code>^||OcuPilotSuperserverWindows</code> holds when set.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SuperserverRulesSeam Extends OcuPilot.Area.Security.SuperserverRules
{

/// <p>The one name answered as a server configuration.</p>
Parameter SERVERNAME = "OcuProbeServerTLS";

ClassMethod ServerConfiguration(pPortClass As %String, pName As %String, Output pValid As %Boolean) As %Status
{
    If pName = ..#SERVERNAME {
        Set pValid = 1
        Quit $$$OK
    }
    Quit ##super(pPortClass, pName, .pValid)
}

ClassMethod Windows() As %Boolean
{
    If $Data(^||OcuPilotSuperserverWindows) Quit ''^||OcuPilotSuperserverWindows
    Quit ##super()
}

}
