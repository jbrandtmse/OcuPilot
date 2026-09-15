/// <p>The handler behind the four application-error-log routes --
/// <code>GET /api/ocupilot/logs/errors/namespaces</code>, <code>/dates</code>, <code>/list</code>
/// and <code>/detail</code>. It reads this endpoint's own parameters off the request and answers
/// what <class>OcuPilot.Port.LogSourcePort</class> returns, through OcuPilot's one success writer
/// or its one error writer (AD-12).</p>
/// <p>Thin, per the router's <code>Call=</code> contract: <b>the drill level is bound by the
/// route</b>, never taken from the request. Validation of <code>namespace</code>,
/// <code>date</code>, <code>errorNumber</code> and <code>maxRows</code> is the port's, so this
/// passes each query parameter through as the caller sent it.</p>
/// <p><b>It never reads <code>ns</code></b> (AD-48). The route's <code>?ns=</code> is data scope
/// for every other screen (AD-44), and this one source overrides it: the namespace an application
/// error read acts on has exactly one source, the level the user drilled to, and it travels under
/// this endpoint's own <code>namespace</code> parameter. Two sources would let a later delete purge
/// a namespace other than the one on screen.</p>
Class OcuPilot.Api.ErrorLog Extends %RegisteredObject
{

/// <p>The port this handler reads through.</p>
Parameter PORTCLASS = "OcuPilot.Port.LogSourcePort";

/// <p>The query parameter carrying the namespace the user drilled to. Never <code>ns</code>.</p>
Parameter NAMESPACEPARAM = "namespace";

/// <p>The query parameter carrying the date the user drilled to, as the instance itself emitted
/// it.</p>
Parameter DATEPARAM = "date";

/// <p>The query parameter carrying the error number the user opened.</p>
Parameter ERRORNUMBERPARAM = "errorNumber";

/// <p>The query parameter carrying the row cap (AD-36).</p>
Parameter MAXROWSPARAM = "maxRows";

/// <p>The port seam, in the shape <class>OcuPilot.Api.LogPage</class> uses: a class <b>name</b>, so
/// a subclass of this handler can answer a substitute port without this method knowing what one is.
/// Nothing overrides it today -- every test of this handler goes over HTTP through the production
/// port, and the port's own branches are driven at the port
/// (<class>OcuPilot.Test.ErrorLogFixture</class>, which subclasses the port and not this
/// class).</p>
ClassMethod PortClass() As %String
{
    Quit ..#PORTCLASS
}

/// <p>Answer one drill level <var>pLevel</var> of the application error log: one success envelope
/// through the one success writer, the port's own fault through the one error writer, or the one
/// generic internal envelope when neither could be produced.</p>
ClassMethod Handle(pLevel As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tNamespace = %request.Get(..#NAMESPACEPARAM, "")
        Set tDate = %request.Get(..#DATEPARAM, "")
        Set tErrorNumber = %request.Get(..#ERRORNUMBERPARAM, "")
        Set tMaxRows = %request.Get(..#MAXROWSPARAM, "")
        Set tReadSC = $ClassMethod(..PortClass(), "Errors", pLevel, tNamespace, tDate, tErrorNumber, tMaxRows, .tResult, .tHttpStatus, .tFault)
        If $$$ISERR(tReadSC) {
            If '$IsObject($Get(tFault)) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tReadSC))
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
