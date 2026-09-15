/// <p>The handler behind the log-page routes -- <code>GET /api/ocupilot/logs/messages</code>
/// today. It reads the three page parameters off the request and answers what
/// <class>OcuPilot.Port.LogSourcePort</class> returns, through OcuPilot's one success writer or
/// its one error writer (AD-12).</p>
/// <p>Thin, per the router's <code>Call=</code> contract: <b>the source key is bound by the
/// route</b>, never taken from the request, so no caller names a file or any part of one
/// (AD-21). Validation of <code>offset</code>, <code>maxBytes</code> and <code>identity</code> is
/// the port's, so this passes each query parameter through as the caller sent it.</p>
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
        Set tPageSC = $ClassMethod(..PortClass(), "Page", pSource, tOffset, tMaxBytes, tIdentity, .tResult, .tHttpStatus, .tFault)
        If $$$ISERR(tPageSC) {
            If '$IsObject($Get(tFault)) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tPageSC))
                Quit
            }
            Set tSC = ##class(OcuPilot.Api.Error).Render(tHttpStatus, tFault.error, tFault.reason, tFault.code, tFault.detail)
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tResult)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

}
