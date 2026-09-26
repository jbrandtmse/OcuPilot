/// <p>The readiness endpoint (AD-45): the one question a machine outside the instance can ask
/// over HTTP and get a believable answer to -- <b>is OcuPilot installed here</b>. It is the
/// dispatch class of OcuPilot's third web application, an unauthenticated one at a path under
/// <code>/api/ocupilot/</code> which IRIS resolves by longest prefix, so it is reached without
/// touching <class>OcuPilot.Api.Router</class>'s route table, its identity gate or its
/// administrative gate.</p>
/// <p><b>The endpoint is <code>/api/ocupilot/readiness/</code>, with the trailing slash.</b>
/// That is IRIS's own rule for every REST web application and not a nesting quirk: verified
/// live on this build that the vendor's own <code>/api/atelier</code> answers 404 without it
/// and 200 with it. Here the bare path additionally resolves to the parent
/// <code>/api/ocupilot</code> application, which is password-authenticated and has no such
/// route, so it answers 401 to an anonymous caller and 404 to an authenticated one --
/// <file>scripts/smoke.sh</file>, <file>docs/DEVELOPMENT.md</file>'s "The readiness endpoint" and
/// every test therefore spell the slash.</p>
/// <p><b>It reports exactly three things and nothing else</b> (AD-45): whether the instance is
/// installed, the version stamp, and which of
/// <method>OcuPilot.Install.Installer.GateStatus</method>'s five states it is in --
/// <code>installed</code>, <code>installing</code>, <code>failed</code>,
/// <code>upgraderequired</code> or <code>unreadable</code>. It names no namespace, no directory, no account, no failing
/// step and no instance detail of any kind, because an anonymous caller is the only kind it
/// has.</p>
/// <p><b><code>failed</code> is reported, the failing step is not</b> (DW-2, the owner's
/// overnight decision). DW-2 asks for a fourth state distinguishing "install failed" from
/// "install never started", and that is met by the state alone; AD-45 forbids anything that
/// aids reconnaissance, and the name of a failing installer step is internal detail. The step
/// stays on the version row, in the container logs and in AD-45's authenticated deeper health
/// view. The disclosure this makes is not new either: <method>OcuPilot.Api.Router</method>'s
/// own install gate is evaluated <b>before</b> identity, so an anonymous caller can already
/// tell <code>INSTALL.FAILED</code> from <code>INSTALL.INSTALLING</code> on the API.</p>
/// <p><b>It is the same ladder the container health check reads.</b> Both resolve through
/// <method>OcuPilot.Install.Installer.GateStatus</method>, so they cannot disagree;
/// <class>OcuPilot.Test.Readiness</class> pins that equality. The health check is deliberately
/// not rewritten to call this endpoint: the pinned image ships no HTTP client at all (verified,
/// Story 1.4), which is why it shells <code>iris session</code>.</p>
/// <p><b>It adds no envelope and no response writer</b> (AD-12, AD-39): success goes through
/// <class>OcuPilot.Api.Response</class> and a wrong verb through
/// <method>OcuPilot.Api.Error.Render405</method>, exactly as every other handler in the tree
/// does.</p>
/// <p><b>Anonymous is not unprivileged</b> (AD-21). The application carries one purpose-built
/// matching role, declared in <class>OcuPilot.Install.Roster</class> and asserted by the
/// installer, granting read on the install namespace's code database and nothing else --
/// without it IRIS refuses an anonymous request 403 with an empty body before this class runs.
/// This class resolves no user and infers nothing from <code>$Roles</code>.</p>
Class OcuPilot.Api.Readiness Extends %CSP.REST
{

/// <p>Stateless: no CSP session per request, the same as
/// <class>OcuPilot.Api.Router</class>. An unauthenticated endpoint that minted a session per
/// probe would let an unauthenticated caller consume session resources.</p>
Parameter UseSession = 0;

/// <p>Every response is JSON.</p>
Parameter CONTENTTYPE = "application/json";

/// <p>CORS processing is off unconditionally (AD-47), stated rather than inherited for the
/// reason <class>OcuPilot.Api.Router</class> states it: <code>0</code> is the falsifiable
/// form, and no route added later can opt back in without changing this line.</p>
Parameter HandleCorsRequest = 0;

/// <p>The application's own root is the only route. IRIS matches the web application by
/// longest path prefix, so a request to the readiness path arrives here with nothing left
/// over; any verb but <code>GET</code> at that path is the framework's 405, rendered by
/// <method>Http405</method> below.</p>
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/" Method="GET" Call="Readiness"/>
</Routes>
}

/// <p>The answer: <code>{"installed": &lt;boolean&gt;, "version": &lt;string&gt;,
/// "state": &lt;string&gt;}</code>, always those three keys and always those types.</p>
/// <p><code>installed</code> is true only when <var>state</var> is <code>installed</code>, so a
/// caller that reads one field and a caller that reads the other can never disagree.
/// <code>version</code> is the stored schema version, as a string, and is <code>""</code> in
/// every state but <code>installed</code> -- an instance that is not installed has no version
/// to report, and reporting one from a half-finished row would be a number a caller could act
/// on.</p>
ClassMethod Readiness() As %Status
{
    Set tState = ..GateStatus()
    ; A readiness answer is true of one instant. Monitors poll it and proxies cache what they
    ; are not told not to, and a cached {"installed":true} outliving the state it reported is
    ; the one failure this endpoint exists to prevent. Set here rather than in
    ; OcuPilot.Api.Response, which is shared with handlers whose answers are cacheable.
    Set %response.Headers("Cache-Control") = "no-store"
    Set tBody = {}
    Do tBody.%Set("installed", $Select(tState = "installed": 1, 1: 0), "boolean")
    Do tBody.%Set("version", ..VersionStamp(tState), "string")
    Do tBody.%Set("state", tState, "string")
    Quit ##class(OcuPilot.Api.Response).JSON(tBody)
}

/// <p>The install gate's current state, delegated to
/// <class>OcuPilot.Install.Installer</class>, which owns the version-row read and its
/// fail-closed discipline (a read failure or an absent row is never
/// <code>installed</code>).</p>
/// <p>Overridable so <class>OcuPilot.Test.Readiness</class> can drive all five states without
/// forcing a real install into each of them; production never overrides it. It is also the
/// seam that makes the equality with <file>scripts/container-health.sh</file> testable: both
/// read this one ladder.</p>
ClassMethod GateStatus() As %String
{
    Quit ##class(OcuPilot.Install.Installer).GateStatus()
}

/// <p>The version stamp for <var>pState</var>: the stored schema version as a string when the
/// instance is installed, <code>""</code> otherwise. Never an error and never a throw -- a row
/// that cannot be read is reported as no version, which is what an unreadable row means.</p>
ClassMethod VersionStamp(pState As %String) As %String
{
    If pState '= "installed" Quit ""
    Set tStamp = ""
    Try {
        Set tSC = ##class(OcuPilot.Install.Installer).CurrentVersionRow("", .tRow)
        If $$$ISOK(tSC), $IsObject(tRow) Set tStamp = tRow.SchemaVersion
        ; Consistency Conventions, %String reads: a %String column a SQL UPDATE set to '' reads
        ; back through the object layer as $Char(0), which is a non-empty one-character string
        ; and so survives every '= "" guard. Normalized here because this value is written
        ; verbatim into the anonymous JSON body, where a raw NUL byte would ship to the caller.
        If tStamp = $Char(0) Set tStamp = ""
    } Catch {
        Set tStamp = ""
    }
    Quit tStamp
}

/// <p>Framework-error override for a mapped route with no matching verb: delegates to
/// <method>OcuPilot.Api.Error.Render405</method>, which sets the <code>Allow</code> header.
/// One envelope, and the request is never echoed back in it.</p>
ClassMethod Http405(pSupportedVerbs As %String = "") As %Status
{
    Do ##class(OcuPilot.Api.Error).Render405(pSupportedVerbs)
    Quit $$$OK
}

/// <p>Framework-error override for every other status, rendering through the tree's one error
/// writer rather than the superclass's own shape -- the same override
/// <class>OcuPilot.Api.Router</class> carries, and for the same reason.</p>
ClassMethod ReportHttpStatusCode(pHttpStatus, pSC As %Status = {$$$OK}) As %Status
{
    Set tStatus = +pHttpStatus
    If $$$ISERR(pSC) {
        Do ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    } ElseIf tStatus = 404 {
        Do ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, "The requested route does not exist", ##class(OcuPilot.Api.Error).#ROUTENOTFOUND)
    } Else {
        Set tSlug = ##class(OcuPilot.Api.Error).GetSlugForStatus(tStatus)
        Do ##class(OcuPilot.Api.Error).Render(tStatus, tSlug, "Request failed", ##class(OcuPilot.Api.Error).CodeForStatus(tStatus))
    }
    Quit $$$OK
}

}
