/// <p>The handler behind <code>GET /ui/findings</code> (Story 16.21): Home's Findings panel.</p>
/// <p>Thin, per the router's <code>Call=</code> contract: the body is
/// <class>OcuPilot.Kernel.Shell.Findings</class>'s, and the response is written by
/// <class>OcuPilot.Api.Response</class> and <class>OcuPilot.Api.Error</class> (AD-12). It takes no
/// argument and has no gate of its own: a check the caller may not read answers
/// <code>unchecked</code> naming the pair, never a 403 (AD-8).</p>
Class OcuPilot.Api.UiFindings Extends %RegisteredObject
{

/// <p>Answer <code>GET /ui/findings</code>: one success envelope through the one success writer,
/// or the one generic internal envelope when the answer could not be built.</p>
ClassMethod HandleFindings() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tReadSC = ##class(OcuPilot.Kernel.Shell.Findings).Read(.tAnswer)
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
