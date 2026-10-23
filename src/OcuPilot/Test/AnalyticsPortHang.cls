/// <p><class>OcuPilot.Port.AnalyticsPort</class> whose DRILLTHROUGH waits end only when the run's alarm interrupts them, so a test sees the
/// alarm arrive as an <code>&lt;ALARM&gt;</code> exception, the form the SQL engine's SQLCODE -450 does not take. A DRILLTHROUGH over
/// <parameter>STARTCUBE</parameter> waits in <method>MdxStart</method>; one over any other cube waits <parameter>STARTPAUSE</parameter>
/// seconds in <method>MdxStart</method>, running no statement, then starts as the port's does and waits in <method>FetchRows</method>.
/// Everything else is the port's.</p>
Class OcuPilot.Test.AnalyticsPortHang Extends OcuPilot.Port.AnalyticsPort
{

/// <p>The cube whose DRILLTHROUGH waits in <method>MdxStart</method>.</p>
Parameter STARTCUBE = "OCUPILOTPROBEVISITS";

/// <p>The seconds a DRILLTHROUGH over any other cube waits in <method>MdxStart</method> before it starts: shorter than the two-second
/// fixture bound, so the bound still ends that run in <method>FetchRows</method>.</p>
Parameter STARTPAUSE = 1;

ClassMethod MdxStart(pNamespace As %String, pRS, Output pCube As %String, Output pKey As %String) As %Status
{
    If $IsObject(pRS) && (pRS.%Query.queryType = "DRILLTHROUGH") {
        If $ZConvert(pRS.%GetCubeName(), "U") = ..#STARTCUBE {
            For {
                Hang 0.1
            }
        }
        Hang ..#STARTPAUSE
    }
    Quit ##super(pNamespace, pRS, .pCube, .pKey)
}

ClassMethod FetchRows(pSet, pColumns As %DynamicArray, pMaxRows As %Integer, Output pRows As %DynamicArray, Output pTruncated As %Boolean, Output pMore As %Boolean, Output pCut As %Boolean)
{
    For {
        Hang 0.1
    }
}

}
