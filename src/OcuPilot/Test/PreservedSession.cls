/// <p>A page that puts the web session serving it in preserve mode (<code>%session.Preserve</code>
/// 1), so <file>ui/browser/web-sessions.browser-spec.mjs</file> can list a real preserve-mode
/// session on a throwaway: such a session keeps its own process, which holds the session's lock.</p>
/// <p>It answers an empty 200 at <code>/csp/hscustom/OcuPilot.Test.PreservedSession.cls</code>, to
/// a caller holding <code>%Admin_Operate:USE</code> -- the pair that ends a session or terminates
/// its process. Its session expires after <parameter>TIMEOUT</parameter> seconds without a request,
/// so a session a run leaves behind does not outlive it for long.</p>
Class OcuPilot.Test.PreservedSession Extends %CSP.Page
{

Parameter CONTENTTYPE = "text/plain";

Parameter SECURITYRESOURCE = "%Admin_Operate:USE";

/// <p>Seconds a preserve-mode session this page opened lives without a request.</p>
Parameter TIMEOUT As INTEGER = 300;

/// <p>Keeps this session's process for the session and bounds its life.</p>
ClassMethod OnPreHTTP() As %Boolean [ ServerOnly = 1 ]
{
    Set %session.AppTimeout = ..#TIMEOUT
    Set %session.Preserve = 1
    Quit 1
}

/// <p>The body is empty; the session is what the request leaves.</p>
ClassMethod OnPage() As %Status [ ServerOnly = 1 ]
{
    Quit $$$OK
}

}
