/// <p>The handler behind <code>GET /ui/performance</code> (Story 16.18): the five metrics Home's
/// performance row reports.</p>
/// <p>Thin, per the router's <code>Call=</code> contract: the body is
/// <class>OcuPilot.Kernel.Shell.Performance</class>'s, and the response is written by
/// <class>OcuPilot.Api.Response</class> and <class>OcuPilot.Api.Error</class> (AD-12). It takes no
/// argument, so it has no validation ladder; a refusal is the port's own 403 naming the pair that
/// failed, and any other failure is the generic internal envelope.</p>
Class OcuPilot.Api.UiPerformance Extends %RegisteredObject
{

/// <p>Answer <code>GET /ui/performance</code>: <code>{cacheEfficiency, globalReferencesPerSecond,
/// globalUpdatesPerSecond, diskReadsPerSecond, diskWritesPerSecond}</code> through the one success
/// writer, or the port's fault through the one error writer.</p>
ClassMethod HandlePerformance() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tReadSC = ##class(OcuPilot.Kernel.Shell.Performance).Read(.tValues, .tHttpStatus, .tFault)
        If $$$ISERR(tReadSC) {
            If '$IsObject($Get(tFault)) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tReadSC))
                Quit
            }
            Set tSC = ##class(OcuPilot.Api.Error).Render(tHttpStatus, tFault.error, tFault.reason, tFault.code, tFault.detail)
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tValues)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

}
