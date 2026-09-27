/// <p>The handler behind <code>GET /ui/guardrails</code> (Story 16.22): the Guardrails page.</p>
/// <p>Thin, per the router's <code>Call=</code> contract: the body is
/// <class>OcuPilot.Kernel.Shell.Guardrails</class>'s, and the response is written by
/// <class>OcuPilot.Api.Response</class> and <class>OcuPilot.Api.Error</class> (AD-12). It takes no
/// argument and has no gate of its own: it answers declarations every caller's tool set already
/// advertises and the caller's own verdict (AD-8).</p>
Class OcuPilot.Api.UiGuardrails Extends %RegisteredObject
{

/// <p>Answer <code>GET /ui/guardrails</code>: one success envelope through the one success writer,
/// or the one generic internal envelope when any part of the answer could not be read.</p>
ClassMethod HandleGuardrails() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tReadSC = ##class(OcuPilot.Kernel.Shell.Guardrails).Read(.tAnswer)
        If $$$ISERR(tReadSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tReadSC))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

}
