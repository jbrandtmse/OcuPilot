/// <p>The one constructor for a privilege refusal (AD-8, AD-39). A caller that holds an
/// administrative resource but not the <code>(resource, permission)</code> pair a screen, a tool
/// or a port declares is refused here, and the refusal is built once and rendered twice: the
/// screen renders the human half through <method>Envelope</method>, a tool result renders the
/// machine half through <method>Content</method>.</p>
/// <p>The triple is fixed -- HTTP <parameter>STATUS</parameter>,
/// <parameter>OcuPilot.Api.Error.FORBIDDEN</parameter> and
/// <parameter>OcuPilot.Api.Error.AUTHNOPRIVILEGE</parameter> -- and the sentence is
/// <parameter>OcuPilot.Api.Error.REASONAUTHNOPRIVILEGE</parameter>, so no refusal authors a
/// second sentence of its own and screen and tool cannot come to disagree about what the same
/// missing pair means.</p>
/// <p><b>It lives in the kernel, not under <package>OcuPilot.Screen</package>.</b>
/// <class>OcuPilot.Kernel.Agent.Dispatch</class> is one of the two renderings, and
/// <file>scripts/check-objectscript.py</file>'s turn-job reach rule refuses any
/// <code>OcuPilot.Screen.*</code> name other than the tool registry under
/// <folder>Kernel/Agent/</folder> (AD-7, AD-9), so a screen-package home would be unreachable
/// from the half that needs it most.</p>
/// <p>This class calls no port, no tool and no store, and holds no state.</p>
Class OcuPilot.Kernel.Denial Extends %RegisteredObject
{

/// <p>The HTTP status a privilege refusal carries.</p>
Parameter STATUS As %Integer = 403;

/// <p>The envelope slug a privilege refusal carries.</p>
ClassMethod Slug() As %String
{
    Quit ##class(OcuPilot.Api.Error).#FORBIDDEN
}

/// <p>The stable machine code a privilege refusal carries (AD-39).</p>
ClassMethod Code() As %String
{
    Quit ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE
}

/// <p>The one written sentence a privilege refusal carries, whichever surface renders it.</p>
ClassMethod Reason() As %String
{
    Quit ##class(OcuPilot.Api.Error).#REASONAUTHNOPRIVILEGE
}

/// <p>The refusal's structured detail: <code>{failedPair}</code> for a named pair, and
/// <code>""</code> when no pair can be named.</p>
/// <p>The key is omitted, never sent empty: a refusal with a blank pair reads as "refused for
/// nothing stated", which is a different thing from a requirement that named no pair at all.</p>
ClassMethod Detail(pFailedPair As %String = "") As %DynamicObject
{
    If pFailedPair = "" Quit ""
    Set tDetail = {}
    Do tDetail.%Set("failedPair", pFailedPair, "string")
    Quit tDetail
}

/// <p>Render the refusal as an error envelope on the response (AD-12): the human half, for a
/// handler. Returns the status <method>OcuPilot.Api.Error.Render</method> answered.</p>
/// <p><b>Caller contract:</b> a handler calls this instead of rendering a 403 of its own, and
/// writes nothing else on that path.</p>
ClassMethod Envelope(pFailedPair As %String = "") As %Status
{
    Quit ##class(OcuPilot.Api.Error).Render(..#STATUS, ..Slug(), ..Reason(), ..Code(), ..Detail(pFailedPair))
}

/// <p>The refusal as the content of an error <code>tool_result</code> (AD-39): the machine half,
/// for the dispatcher. <code>{code}</code>, plus <code>detail.failedPair</code> when a pair is
/// named.</p>
ClassMethod Content(pFailedPair As %String = "") As %String
{
    Set tContent = {}
    Do tContent.%Set("code", ..Code(), "string")
    Set tDetail = ..Detail(pFailedPair)
    If $IsObject(tDetail) Do tContent.%Set("detail", tDetail)
    Quit tContent.%ToJSON()
}

}
