/// <p>The handler behind the log-page routes -- <code>GET /api/ocupilot/logs/messages</code>,
/// <code>GET /api/ocupilot/logs/alerts</code> and <code>GET /api/ocupilot/logs/messages/files</code>.
/// It reads the page parameters off the request and answers what
/// <class>OcuPilot.Port.LogSourcePort</class> returns, through OcuPilot's one success writer or
/// its one error writer (AD-12).</p>
/// <p>Thin, per the router's <code>Call=</code> contract: <b>the source key is bound by the
/// route</b>, never taken from the request (AD-21). The one name a caller supplies is the
/// <code>file</code> parameter, AD-21's fourth named case, which the port admits only as a rotated
/// console log's name. Validation of <code>offset</code>, <code>maxBytes</code>,
/// <code>identity</code> and <code>file</code> is the port's, so this passes each query parameter
/// through as the caller sent it.</p>
Class OcuPilot.Api.LogPage Extends %RegisteredObject
{

/// <p>The port this handler reads through.</p>
Parameter PORTCLASS = "OcuPilot.Port.LogSourcePort";

/// <p>The port seam, in the shape <class>OcuPilot.Api.Instance</class> uses: a class <b>name</b>,
/// so a subclass of this handler can answer a substitute port without this method knowing what
/// one is. Nothing overrides it today -- every test of this handler goes over HTTP through the
/// production port, and the port's own branches are driven at the port
/// (<class>OcuPilot.Test.LogSourceFixture</class>, which subclasses the port and not this
/// class).</p>
ClassMethod PortClass() As %String
{
    Quit ..#PORTCLASS
}

/// <p>Answer a page of log source <var>pSource</var>: one success envelope through the one
/// success writer, the port's own fault through the one error writer, or the one generic
/// internal envelope when neither could be produced.</p>
ClassMethod Handle(pSource As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tOffset = %request.Get("offset", "")
        Set tMaxBytes = %request.Get("maxBytes", "")
        Set tIdentity = %request.Get("identity", "")
        Set tFile = %request.Get("file", "")
        Set tPageSC = $ClassMethod(..PortClass(), "Page", pSource, tOffset, tMaxBytes, tIdentity, .tResult, .tHttpStatus, .tFault, tFile)
        Set tSC = ..Answer(tPageSC, .tResult, .tHttpStatus, .tFault)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer the list of files log source <var>pSource</var> can page
/// (<method>OcuPilot.Port.LogSourcePort.Files</method>), through the same two writers.</p>
ClassMethod HandleFiles(pSource As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tFilesSC = $ClassMethod(..PortClass(), "Files", pSource, .tResult, .tHttpStatus, .tFault)
        Set tSC = ..Answer(tFilesSC, .tResult, .tHttpStatus, .tFault)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Write the port's answer: <var>pResult</var> through the success writer when
/// <var>pPortSC</var> is OK, else <var>pFault</var> through the error writer, or the generic
/// internal envelope when the port produced no fault.</p>
ClassMethod Answer(pPortSC As %Status, ByRef pResult, ByRef pHttpStatus, ByRef pFault) As %Status [ Private ]
{
    If $$$ISOK(pPortSC) Quit ##class(OcuPilot.Api.Response).JSON(pResult)
    If '$IsObject($Get(pFault)) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pPortSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render(pHttpStatus, pFault.error, pFault.reason, pFault.code, pFault.detail)
}

}
