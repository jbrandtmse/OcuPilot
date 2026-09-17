/// <p>The handler behind <code>GET /api/ocupilot/instance</code> -- OcuPilot's first data
/// call, so the shell can verify the instance it is talking to before rendering any screen
/// (AD-27, NFR-8).</p>
/// <p>Thin, per the router's <code>Call=</code> contract: the body is
/// <class>OcuPilot.Kernel.Shell.Instance</class>'s <method>Payload</method>, the same object the
/// <code>shell.instance.read</code> tool answers, and the response is written by
/// <class>OcuPilot.Api.Response</class> (AD-12). A version other than 2 is a 200 carrying that
/// number, never an error envelope -- the client needs the number to name it.</p>
Class OcuPilot.Api.Instance Extends OcuPilot.Kernel.Shell.Instance
{

/// <p>Answer the request: one success envelope through the one success writer, or the one
/// generic internal envelope when the body could not be built.</p>
ClassMethod Handle() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..Payload(.tObject)
        If $$$ISERR(tSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSC))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tObject)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

}
