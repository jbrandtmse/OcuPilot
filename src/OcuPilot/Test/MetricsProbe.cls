/// <p>The Story 18.11 fixture: the throwaway principals <class>OcuPilot.Test.MetricsGate</class> signs
/// in as. It is <class>OcuPilot.Test.SqlActivityProbe</class>'s principal helpers under a prefix of its
/// own, so a name of either story is refused by the other's, and it counts the users and roles that
/// prefix leaves behind (<method>Remaining</method>).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MetricsProbe Extends OcuPilot.Test.SqlActivityProbe
{

/// <p>The prefix every principal's name carries.</p>
Parameter PRINCIPALPREFIX = "OcuProbe1811";

/// <p>How many users and roles named with <parameter>PRINCIPALPREFIX</parameter> the instance holds;
/// <code>-1</code> when they could not be counted.</p>
ClassMethod Remaining() As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tTable = "Security.Users", "Security.Roles" {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM " _ tTable _ " WHERE Name %STARTSWITH ?", ..#PRINCIPALPREFIX)
            If (tRS.%SQLCODE < 0) || 'tRS.%Next() {
                Set tCount = -1
                Quit
            }
            Set tCount = tCount + tRS.%GetData(1)
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

}
