/// <p>The handler behind <code>GET /api/ocupilot/navigation</code>: every area and every built
/// screen, each carrying whether the calling process may reach it.</p>
/// <p>Thin, per the router's <code>Call=</code> contract: the body is
/// <class>OcuPilot.Kernel.Shell.Navigation</class>'s <method>Payload</method>, the same object the
/// <code>shell.privileges.read</code> tool answers, and the response is written by
/// <class>OcuPilot.Api.Response</class> (AD-12).</p>
Class OcuPilot.Api.Navigation Extends OcuPilot.Kernel.Shell.Navigation
{

/// <p>Answer the request: one success envelope through the one success writer, or the one
/// generic internal envelope when the roster could not be built.</p>
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
