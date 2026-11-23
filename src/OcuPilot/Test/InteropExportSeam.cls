/// <p><class>OcuPilot.Test.InteropSuspendedSeam</class> with the render of Story 24.16 Batch 3's export named by a test: the render of each message id <method>FailRenderOf</method>
/// lists is answered with an error status that carries <parameter>MARKER</parameter>, and that of each id <method>ThrowRenderOf</method> lists throws, until <method>Disarm</method>.
/// <method>RenderedIn</method> keeps the namespace each render ran in, so a test reads that it ran in the message's own. Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropExportSeam Extends OcuPilot.Test.InteropSuspendedSeam
{

/// <p>Answer the render of each message id in <var>pIds</var> (comma-separated) with an error status, until <method>Disarm</method>.</p>
ClassMethod FailRenderOf(pIds As %String)
{
    Set ^||OcuPilotExportFail = "," _ pIds _ ","
}

/// <p>Throw from the render of each message id in <var>pIds</var> (comma-separated), until <method>Disarm</method>.</p>
ClassMethod ThrowRenderOf(pIds As %String)
{
    Set ^||OcuPilotExportThrow = "," _ pIds _ ","
}

ClassMethod Disarm()
{
    Do ##super()
    Kill ^||OcuPilotExportFail
    Kill ^||OcuPilotExportThrow
    Kill ^||OcuPilotExportRenders
}

/// <p>The namespaces each render since <method>Disarm</method> ran in, comma-separated, one for each render.</p>
ClassMethod RenderedIn() As %String
{
    Set tText = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotExportRenders(tAt))
        If tAt = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ ^||OcuPilotExportRenders(tAt)
    }
    Quit tText
}

ClassMethod ExportRenderHere(pHeaderId As %String, pObject As %RegisteredObject, Output pWire As %String, Output pTooLarge As %Boolean) As %Status [ Private ]
{
    Set ^||OcuPilotExportRenders($Increment(^||OcuPilotExportRenders)) = $NAMESPACE
    If $Get(^||OcuPilotExportThrow) [ ("," _ pHeaderId _ ",") Throw ##class(%Exception.General).%New("ExportThrown", 5001, , ..#MARKER _ " threw in the render of " _ pHeaderId)
    If $Get(^||OcuPilotExportFail) [ ("," _ pHeaderId _ ",") {
        Set pWire = ""
        Set pTooLarge = 0
        Quit $System.Status.Error(5001, ..#MARKER _ " refused the render of " _ pHeaderId)
    }
    Quit ##super(pHeaderId, pObject, .pWire, .pTooLarge)
}

}
