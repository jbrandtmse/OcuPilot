/// <p>The handler behind <code>GET /api/ocupilot/logs/alerts/recent</code>: the alerts the
/// monitoring API reports as newer than a cursor the caller holds. It reads one parameter off the
/// request and answers what <class>OcuPilot.Port.MonitorPort</class> returns, through OcuPilot's one
/// success writer or its one error writer (AD-12).</p>
/// <p>Thin, per the router's <code>Call=</code> contract: <b>the endpoint and the request type are
/// bound here</b>, from the port's own parameters, so no caller names either (AD-21). Validation of
/// <code>tag</code> is the port's, so this passes it through as the caller sent it.</p>
/// <p>The answer is <code>{rows, tag}</code>: the rows the monitoring API reported, and the cursor
/// to send back on the next call. The bounded file tail travels on
/// <class>OcuPilot.Api.LogPage</class>'s own route; the screen merges the two, and this route
/// answers only its own half, so either half faulting leaves the other standing.</p>
Class OcuPilot.Api.MonitorLog Extends %RegisteredObject
{

/// <p>The port this handler reads through.</p>
Parameter PORTCLASS = "OcuPilot.Port.MonitorPort";

/// <p>The request key carrying the caller's cursor.</p>
Parameter TAGKEY = "tag";

/// <p>The answer's key carrying the cursor for the next call.</p>
Parameter TAGFIELD = "tag";

/// <p>The answer's key carrying the rows.</p>
Parameter ROWSFIELD = "rows";

/// <p>The port seam, in the shape <class>OcuPilot.Api.LogPage</class> uses: a class <b>name</b>, so
/// a subclass of this handler can answer a substitute port without this method knowing what one is.
/// Nothing overrides it today -- every test of this handler goes over HTTP through the production
/// port, and the port's own branches are driven at the port
/// (<class>OcuPilot.Test.MonitorPortFixture</class>, which subclasses the port and not this
/// class).</p>
ClassMethod PortClass() As %String
{
    Quit ..#PORTCLASS
}

/// <p>Answer the alerts newer than the request's <code>tag</code>: one success envelope through the
/// one success writer, the port's own fault through the one error writer, or the one generic
/// internal envelope when neither could be produced.</p>
/// <p><var>pEndpoint</var> and <var>pType</var> are bound by the route, from the port's own
/// parameters, and never read from the request (AD-21).</p>
ClassMethod Handle(pEndpoint As %String, pType As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery(..#TAGKEY) = %request.Get(..#TAGKEY, "")
        Set tInvokeSC = $ClassMethod(..PortClass(), "Invoke", pEndpoint, pType, .tQuery, "", .tRows, .tHttpStatus, .tFault, .tTag)
        If $$$ISERR(tInvokeSC) {
            If '$IsObject($Get(tFault)) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tInvokeSC))
                Quit
            }
            Set tSC = ##class(OcuPilot.Api.Error).Render(tHttpStatus, tFault.error, tFault.reason, tFault.code, tFault.detail)
            Quit
        }
        Set tResult = {}
        Do tResult.%Set(..#ROWSFIELD, tRows)
        Do tResult.%Set(..#TAGFIELD, tTag)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tResult)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

}
