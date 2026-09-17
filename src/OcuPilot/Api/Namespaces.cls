/// <p>The handler behind <code>GET /api/ocupilot/namespaces</code>, and the namespace entry check
/// the router applies to <code>?ns=</code>.</p>
/// <p>Thin, per the router's <code>Call=</code> contract: the body is
/// <class>OcuPilot.Kernel.Shell.Namespaces</class>'s <method>Payload</method>, the same object the
/// <code>shell.namespaces.read</code> tool answers, and the response is written by
/// <class>OcuPilot.Api.Response</class> (AD-12).</p>
Class OcuPilot.Api.Namespaces Extends OcuPilot.Kernel.Shell.Namespaces
{

/// <p>Whether the calling process may make a request scoped to <var>pNamespace</var>: it holds
/// <parameter>READPERMISSION</parameter> on that namespace's global-database resource.
/// <var>pFailedPair</var> names the pair that failed, and is <code>""</code> when the answer is
/// yes or when the namespace has no resource to test.</p>
/// <p>This is the entry check <method>OcuPilot.Api.Router.OnPreDispatch</method> applies to
/// <code>?ns=</code>, and it is deliberately <code>READ</code> alone: a namespace the caller can
/// read but not write scopes every read made there (DW-7), and the switch's own narrower rule
/// lives on the client.</p>
ClassMethod MayEnter(pNamespace As %String, Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    Set tAllowed = 0
    Try {
        If '..GlobalDatabase(pNamespace, .tResource, .tReadOnly) Quit
        Set tAllowed = ..Holds(tResource, ..#READPERMISSION, .pFailedPair)
    } Catch {
        Set tAllowed = 0
        Set pFailedPair = ""
    }
    Quit tAllowed
}

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
