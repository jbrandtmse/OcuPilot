/// <p>The handler behind <code>GET /ui/system</code> (Story 15.4, FR-73): the instance state
/// Home's System Information panel reports.</p>
/// <p>Thin, per the router's <code>Call=</code> contract: the body is
/// <class>OcuPilot.Kernel.Shell.SystemInfo</class>'s, and the response is written by
/// <class>OcuPilot.Api.Response</class> and <class>OcuPilot.Api.Error</class> (AD-12).</p>
/// <p><b>Caller-own and ungated beyond the router</b>, like <class>OcuPilot.Api.UiAbout</class>:
/// it answers what the calling process may read and degrades each member the process may not
/// (AD-8). It takes no argument at all -- no namespace, no path, no class name -- so it has no
/// validation ladder and adds no error code; the only scope it has is the one the router already
/// resolved from <code>?ns=</code> (AD-44, AD-21).</p>
Class OcuPilot.Api.UiSystem Extends OcuPilot.Kernel.Shell.SystemInfo
{

/// <p>Answer <code>GET /ui/system</code>: one success envelope through the one success writer,
/// or the one generic internal envelope when the body could not be built.</p>
ClassMethod HandleSystem() As %Status
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
