/// <p>The failure half of OcuPilot's one response envelope (AD-12, AD-39).</p>
/// <p>This is the single entry point for every error response in the tree. Handlers
/// never construct an error envelope inline, and this class, together with
/// <class>OcuPilot.Api.Response</class>, is the only code permitted to <code>Write</code>
/// to the response device.</p>
/// <p>The wire shape is <code>{error, reason, code}</code>, plus <code>detail</code> only
/// when supplied — never <code>null</code>. <var>error</var> is a coarse slug drawn from
/// the closed enum below; <var>reason</var> is human text a screen renders and may be
/// reworded freely; <var>code</var> is a stable, dotted-uppercase machine identifier a
/// tool result renders and that is never reworded once shipped; <var>detail</var> is an
/// optional structured object. An unknown slug is refused outright — nothing is written
/// and an error <class>%Status</class> is returned — because the slug enum is closed.</p>
/// <p>For internal (500) failures: the full exception detail goes to
/// <class>OcuPilot.Kernel.Audit.Log</class> only. The client always gets a generic
/// reason and the machine code <code>INTERNAL</code> — see <method>RenderInternal</method>.</p>
Class OcuPilot.Api.Error Extends %RegisteredObject
{

/// <p>Error slug: malformed request.</p>
Parameter BADREQUEST = "bad_request";

/// <p>Error slug: authentication required.</p>
Parameter UNAUTHORIZED = "unauthorized";

/// <p>Error slug: authenticated but not permitted.</p>
Parameter FORBIDDEN = "forbidden";

/// <p>Error slug: resource not found.</p>
Parameter NOTFOUND = "not_found";

/// <p>Error slug: HTTP method not allowed on this route.</p>
Parameter METHODNOTALLOWED = "method_not_allowed";

/// <p>Error slug: the request conflicts with the resource's current state.</p>
Parameter CONFLICT = "conflict";

/// <p>Error slug: a stated precondition was not met.</p>
Parameter PRECONDITIONFAILED = "precondition_failed";

/// <p>Error slug: unsupported or missing content type.</p>
Parameter BADCONTENTTYPE = "bad_content_type";

/// <p>Error slug: the request body failed validation.</p>
Parameter VALIDATIONFAILED = "validation_failed";

/// <p>Error slug: an internal failure. The client-facing reason is always generic —
/// see <method>RenderInternal</method>.</p>
Parameter SERVERERROR = "server_error";

/// <p>Error slug: the feature is not implemented.</p>
Parameter NOTIMPLEMENTED = "not_implemented";

/// <p>Error slug: the service is temporarily unavailable.</p>
Parameter UNAVAILABLE = "unavailable";

/// <p>Machine code (AD-38, AD-39): install is still running. Rendered on the
/// <parameter>UNAVAILABLE</parameter> slug by <class>OcuPilot.Api.Router</class>'s
/// traffic gate -- never a new envelope field, never a number.</p>
Parameter INSTALLINSTALLING = "INSTALL.INSTALLING";

/// <p>Machine code (AD-38, AD-39): the stored schema version is behind the deployed
/// code and forward migration has not completed. Rendered on the
/// <parameter>UNAVAILABLE</parameter> slug by <class>OcuPilot.Api.Router</class>'s
/// traffic gate.</p>
Parameter INSTALLUPGRADEREQUIRED = "INSTALL.UPGRADEREQUIRED";

/// <p>Machine code (AD-38, AD-39): the last install attempt failed. Rendered on the
/// <parameter>UNAVAILABLE</parameter> slug by <class>OcuPilot.Api.Router</class>'s
/// traffic gate.</p>
Parameter INSTALLFAILED = "INSTALL.FAILED";

/// <p>Machine code (AD-12, AD-39): the requested shell path is not one
/// <class>OcuPilot.Api.StaticHandler</class> will resolve to a file -- it carries a
/// literal <code>..</code>, a null, a backslash or a colon, or it normalizes outside the
/// bundle directory. Rendered on the <parameter>BADREQUEST</parameter> slug, and the
/// request text is never echoed back with it (AD-21, AD-47).</p>
Parameter STATICBADPATH = "STATIC.BADPATH";

/// <p>Machine code (AD-12, AD-39): the shell application is serving, but its bundle
/// directory holds no usable <code>index.html</code> -- the client was never built, or was
/// never copied in. Rendered on the <parameter>UNAVAILABLE</parameter> slug by
/// <class>OcuPilot.Api.StaticHandler</class>; install reports the same condition as a
/// <code>warn</code> and completes regardless.</p>
Parameter STATICNOBUNDLE = "STATIC.NOBUNDLE";

/// <p>Machine code (AD-12, AD-39): the caller is authenticated but holds no
/// <code>%Admin_*</code> resource at <code>USE</code>, so
/// <class>OcuPilot.Api.Router</class>'s administrative gate refuses before any route
/// runs. Rendered on the <parameter>FORBIDDEN</parameter> slug.</p>
Parameter AUTHNOADMIN = "AUTH.NOADMIN";

/// <p>Machine code (AD-12, AD-39): the caller holds an administrative resource and so cleared
/// <class>OcuPilot.Api.Router</class>'s instance-level gate, but does not hold one screen's own
/// <code>(resource, permission)</code> pair set (AD-8). Rendered on the
/// <parameter>FORBIDDEN</parameter> slug, with the failed pair as the envelope's
/// <code>detail</code>.</p>
/// <p><b>Distinct from <parameter>AUTHNOADMIN</parameter> on purpose.</b> That one means "this
/// account administers nothing on this instance" and drives a blocking notice whose only
/// control is Sign out; this one means "this account administers this instance but not this
/// screen" and drives an inline refusal beside a working shell. A client that read one for the
/// other would show the wrong surface.</p>
/// <p>Declared here, with no call site yet: the screen reads that render it are Epic 2's, and
/// Story 1.9 resolves a screen's gate from the navigation map rather than from a refused
/// request. The code is fixed now so the first of those reads does not mint a second one.</p>
Parameter AUTHNOPRIVILEGE = "AUTH.NOPRIVILEGE";

/// <p>The single entry point for every error response.</p>
/// <p>Sets the HTTP status and writes exactly one JSON envelope
/// <code>{error, reason, code}</code>, plus <var>pDetail</var> under the key
/// <code>detail</code> only when it is a supplied object — the key is omitted, never
/// <code>null</code>, when absent. Refuses an unknown <var>pSlug</var> or a missing
/// <var>pCode</var> by returning an error <class>%Status</class> without writing
/// anything, so a caller that mistypes a slug fails loudly rather than shipping an
/// envelope the closed enum does not recognize.</p>
/// @param pStatus HTTP status code (e.g., 400, 404, 500)
/// @param pSlug Coarse error slug from the closed enum above
/// @param pReason Human-readable reason a screen may render and reword freely
/// @param pCode Stable dotted-uppercase machine identifier (e.g. "ROUTE.NOTFOUND")
/// @param pDetail Optional structured detail object
ClassMethod Render(pStatus As %Integer, pSlug As %String, pReason As %String, pCode As %String, pDetail As %DynamicObject = "") As %Status
{
    Set tSC = $$$OK
    Try {
        If '..IsKnownSlug(pSlug) {
            Set tSC = $$$ERROR($$$GeneralError, "Unknown error slug: '" _ pSlug _ "'")
            Quit
        }
        If pCode = "" {
            Set tSC = $$$ERROR($$$GeneralError, "Error code is required")
            Quit
        }
        Set %response.Status = pStatus
        Set %response.ContentType = "application/json"
        Set tObj = {}
        Do tObj.%Set("error", pSlug)
        Do tObj.%Set("reason", pReason)
        Do tObj.%Set("code", pCode)
        If $IsObject(pDetail) {
            Do tObj.%Set("detail", pDetail)
        }
        Write tObj.%ToJSON()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Render a 500 with safe client output. Full exception detail goes to
/// <class>OcuPilot.Kernel.Audit.Log</class>; the client always receives a generic
/// reason and the machine code <code>INTERNAL</code> — splitting logged detail from
/// client reason is exactly what keeps a stack trace off the wire.</p>
/// @param pReason Generic reason string sent to the client (defaults to a fixed generic message)
/// @param pException Optional exception object; its detail is logged, never sent to the client
ClassMethod RenderInternal(pReason As %String = "An internal error occurred", pException As %Exception.AbstractException = "") As %Status
{
    Set tSC = $$$OK
    Try {
        If $IsObject(pException) {
            Do ..LogError("router", "Internal error", {"detail": (pException.DisplayString())})
        }
        Set tSC = ..Render(500, ..#SERVERERROR, pReason, "INTERNAL")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The single audit-log seam <method>RenderInternal</method> writes through. Exists as
/// its own overridable method for one reason: <method>RenderInternal</method> used to name
/// <class>OcuPilot.Kernel.Audit.Log</class> by hard class name, which no test could
/// intercept — the same problem <class>OcuPilot.Kernel.Audit.Log.WriteConsole</class> was
/// given this seam treatment for. <class>OcuPilot.Test.ErrorProbe</class> overrides this
/// method to capture the three arguments exactly as <method>RenderInternal</method> passes
/// them, so <class>OcuPilot.Test.Envelope</class> can assert the wiring itself.</p>
/// <p>Production never overrides this — it forwards, unchanged, to
/// <class>OcuPilot.Kernel.Audit.Log</class>.</p>
/// @param pSubsystem Subsystem name passed to Log.Error
/// @param pMessage Message passed to Log.Error
/// @param pData Optional structured detail object passed to Log.Error
ClassMethod LogError(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ##class(OcuPilot.Kernel.Audit.Log).Error(pSubsystem, pMessage, pData)
}

/// <p>Render a 405 Method Not Allowed response, setting the <code>Allow</code> header
/// to the supported verbs.</p>
/// @param pAllowedMethods Comma-separated list of allowed HTTP methods (e.g., "GET, HEAD")
ClassMethod Render405(pAllowedMethods As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Do %response.SetHeader("Allow", pAllowedMethods)
        ; "This route allows only X, Y", not "Only X, Y is allowed" — pAllowedMethods is
        ; a comma-separated list whenever more than one verb is mapped, and the client
        ; renders this reason verbatim.
        Set tSC = ..Render(405, ..#METHODNOTALLOWED, "This route allows only " _ pAllowedMethods, "ROUTE.METHODNOTALLOWED")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Render a 501 Not Implemented response.</p>
/// @param pReason Reason string naming the unimplemented subsystem or feature
ClassMethod Render501(pReason As %String) As %Status
{
    Quit ..Render(501, ..#NOTIMPLEMENTED, pReason, "ROUTE.NOTIMPLEMENTED")
}

/// <p>Map an HTTP status code to its default error slug. Used where only a status is
/// known — e.g. the router's framework-404 override.</p>
/// @param pStatusCode HTTP status code (e.g., 404, 409, 500)
/// @return The default error slug for that status; unknown codes default to server_error
ClassMethod GetSlugForStatus(pStatusCode As %Integer) As %String
{
    If pStatusCode = 400 Quit ..#BADREQUEST
    If pStatusCode = 401 Quit ..#UNAUTHORIZED
    If pStatusCode = 403 Quit ..#FORBIDDEN
    If pStatusCode = 404 Quit ..#NOTFOUND
    If pStatusCode = 405 Quit ..#METHODNOTALLOWED
    If pStatusCode = 409 Quit ..#CONFLICT
    If pStatusCode = 412 Quit ..#PRECONDITIONFAILED
    If pStatusCode = 415 Quit ..#BADCONTENTTYPE
    If pStatusCode = 422 Quit ..#VALIDATIONFAILED
    If pStatusCode = 500 Quit ..#SERVERERROR
    If pStatusCode = 501 Quit ..#NOTIMPLEMENTED
    If pStatusCode = 503 Quit ..#UNAVAILABLE
    Quit ..#SERVERERROR
}

/// <p>Whether <var>pSlug</var> is one of the twelve closed-enum slugs above. Private —
/// the enum is closed and this is the only code that needs to test membership in it.</p>
ClassMethod IsKnownSlug(pSlug As %String) As %Boolean [ Private ]
{
    Quit $ListFind($ListBuild(..#BADREQUEST, ..#UNAUTHORIZED, ..#FORBIDDEN, ..#NOTFOUND, ..#METHODNOTALLOWED, ..#CONFLICT, ..#PRECONDITIONFAILED, ..#BADCONTENTTYPE, ..#VALIDATIONFAILED, ..#SERVERERROR, ..#NOTIMPLEMENTED, ..#UNAVAILABLE), pSlug) > 0
}

}
