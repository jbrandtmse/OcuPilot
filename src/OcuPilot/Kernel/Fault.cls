/// <p>AD-39's normalization, in one place: a vendor <class>%Status</class> becomes an OcuPilot
/// slug, a stable machine code and a written reason, and its raw text goes to the log alone.</p>
/// <p>A <class>%Status</class> from an <code>%Api.Admin.*</code> class is written for a portal
/// developer. It names internal classes, message ids and occasionally paths, and none of that
/// may reach a screen or the model (AD-11, AD-21, AD-35, AD-47). This class is where a port
/// turns one into something both consumers can read, before either sees it.</p>
/// <p><b>The reason is OcuPilot's own sentence, never the vendor's.</b> A matched status takes
/// the written reason from the table below; an unmatched one defaults to
/// <class>OcuPilot.Api.Error</class>'s <parameter>SERVERERROR</parameter> slug and
/// <parameter>INTERNAL</parameter> code with a generic reason. So no branch can put vendor-authored text on the wire -- which is the AC, and is
/// stronger than stripping the domain and id off it would be:
/// <method>%SYSTEM.Status.GetOneStatusText</method> removes the domain, the id and the source,
/// but not a class name interpolated into the message body, and interpolated class names are
/// exactly what an <code>%Api.Admin.*</code> failure carries.</p>
/// <p>That stripped text is still used -- as <var>pDetail</var>, a one-line companion for the
/// log beside the raw <method>GetErrorText</method> output, where both are wanted in full.</p>
/// <p><class>OcuPilot.Port.AdminPort</class> is the call site: its invocation reads an outcome
/// from both the vendor status and the HTTP status the endpoint left, and
/// <method>Outcome</method> turns that pair into the fault a caller receives. The HTTP status is
/// mapped first, because an endpoint that sets <code>404 Not Found</code> often leaves an OK or
/// unrelated status behind it; only an unmapped HTTP status falls back to
/// <method>Normalize</method>.</p>
Class OcuPilot.Kernel.Fault Extends %RegisteredObject
{

/// <p>The reason an unmapped status takes. Generic by construction (AD-39), and the same
/// sentence <method>OcuPilot.Api.Error.RenderInternal</method> defaults to, so a client cannot
/// tell a normalized unknown from an unhandled exception -- which is correct, since to a client
/// they are the same event.</p>
Parameter DEFAULTREASON = "An internal error occurred";

/// <p>Normalize <var>pStatus</var> into the three values the envelope carries, plus a detail
/// line for the log.</p>
/// <p>Matching is by <method>%SYSTEM.Status.Equals</method> against the table below, which
/// compares the status's <b>domain and message id</b> -- not its rendered text, which is
/// localized and reworded between releases and would make the mapping a string match on
/// English.</p>
/// <p>Returns an error <class>%Status</class> for an OK input and sets nothing: normalizing a
/// success is a programming error, and answering it with a plausible-looking
/// <code>server_error</code> would hide the call site that did it.</p>
/// @param pStatus The vendor status to normalize
/// @param pSlug Output: a slug from OcuPilot.Api.Error's closed enum
/// @param pCode Output: a stable dotted-uppercase machine code (AD-39)
/// @param pReason Output: OcuPilot's own written reason, safe for a screen and for a tool result
/// @param pDetail Output: the vendor text with its domain, id and source stripped -- for the
/// log only, never for the envelope
ClassMethod Normalize(pStatus As %Status, Output pSlug As %String, Output pCode As %String, Output pReason As %String, Output pDetail As %String) As %Status
{
    Set tSC = $$$OK
    ; The defaults, and every mapped row below, name OcuPilot.Api.Error's own parameters. The
    ; slug is deliberately the most conservative of the twelve -- a failure OcuPilot does not
    ; recognize is one it cannot describe, and calling it bad_request or not_found would blame
    ; the caller for it -- and the code is the one RenderInternal renders, because to a client
    ; it is the same event.
    Set pSlug = ##class(OcuPilot.Api.Error).#SERVERERROR
    Set pCode = ##class(OcuPilot.Api.Error).#INTERNAL
    Set pReason = ..#DEFAULTREASON
    Set pDetail = ""
    Try {
        If $$$ISOK(pStatus) {
            Set tSC = $$$ERROR($$$GeneralError, "Fault.Normalize was given an OK status")
            Quit
        }
        Set pDetail = $System.Status.GetOneStatusText(pStatus, 1)

        If $System.Status.Equals(pStatus, $$$ERRORCODE($$$AccessDenied)) {
            Set pCode = ##class(OcuPilot.Api.Error).#PORTACCESSDENIED
            Do ..Classify(pCode, .pSlug, .pReason)
            Quit
        }
        If $System.Status.Equals(pStatus, $$$ERRORCODE($$$LoadObjectNotFound), $$$ERRORCODE($$$DeleteObjectNotFound)) {
            Set pCode = ##class(OcuPilot.Api.Error).#PORTNOTFOUND
            Do ..Classify(pCode, .pSlug, .pReason)
            Quit
        }
        If $System.Status.Equals(pStatus, $$$ERRORCODE($$$IDKeyNotUnique), $$$ERRORCODE($$$KeyNotUnique)) {
            Set pCode = ##class(OcuPilot.Api.Error).#PORTCONFLICT
            Do ..Classify(pCode, .pSlug, .pReason)
            Quit
        }
        If $System.Status.Equals(pStatus, $$$ERRORCODE($$$PropertyRequired), $$$ERRORCODE($$$DatatypeValidationFailed)) {
            Set pCode = ##class(OcuPilot.Api.Error).#PORTVALIDATION
            Do ..Classify(pCode, .pSlug, .pReason)
            Quit
        }
        If $System.Status.Equals(pStatus, $$$ERRORCODE($$$NotImplemented)) {
            Set pCode = ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED
            Do ..Classify(pCode, .pSlug, .pReason)
            Quit
        }
        ; Everything else keeps the defaults set above. The table grows when a port meets a
        ; status worth telling apart -- never by widening one of the rows to cover it.
    } Catch ex {
        ; All four outputs, not three: pDetail is assigned before the table is walked, so a
        ; throw after that line left a caller holding vendor text in an output the rest of this
        ; block had just reset to a safe default.
        Set pSlug = ##class(OcuPilot.Api.Error).#SERVERERROR
        Set pCode = ##class(OcuPilot.Api.Error).#INTERNAL
        Set pReason = ..#DEFAULTREASON
        Set pDetail = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The fault for a vendor call that did not succeed, from the HTTP status the endpoint left
/// and the status it returned. <var>pFault</var> is <code>{error, reason, code}</code>, safe for
/// the wire; <var>pDetail</var> is the vendor's stripped text for the log, or <code>""</code>
/// when <var>pStatus</var> is OK.</p>
/// <p>The HTTP status decides first: 403 is <code>PORT.ACCESSDENIED</code>, 404
/// <code>PORT.NOTFOUND</code>, 409 <code>PORT.CONFLICT</code>, and 400 or 422
/// <code>PORT.VALIDATION</code>. Any other HTTP status takes <method>Normalize</method>'s answer
/// for <var>pStatus</var>, or the internal default when <var>pStatus</var> is OK.
/// <var>pFault</var> is always set: when this method itself returns an error, it is the internal
/// default.</p>
/// @param pHttpStatus The numeric HTTP status the endpoint left
/// @param pStatus The status the vendor sequence returned
/// @param pFault Output: the wire fault
/// @param pDetail Output: the vendor text with its domain, id and source stripped -- for the log only
ClassMethod Outcome(pHttpStatus As %Integer, pStatus As %Status, Output pFault As %DynamicObject, Output pDetail As %String) As %Status
{
    Set tSC = $$$OK
    Set pDetail = ""
    Set pFault = ..Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ..#DEFAULTREASON)
    Set tCode = ""
    Try {
        Set tHttp = +pHttpStatus
        If tHttp = 403 Set tCode = ##class(OcuPilot.Api.Error).#PORTACCESSDENIED
        If tHttp = 404 Set tCode = ##class(OcuPilot.Api.Error).#PORTNOTFOUND
        If tHttp = 409 Set tCode = ##class(OcuPilot.Api.Error).#PORTCONFLICT
        If (tHttp = 400) || (tHttp = 422) Set tCode = ##class(OcuPilot.Api.Error).#PORTVALIDATION
        If $$$ISERR(pStatus) {
            Set tSC = ..Normalize(pStatus, .tSlug, .tNormCode, .tReason, .pDetail)
            If $$$ISERR(tSC) Quit
        } Else {
            Set tSlug = ##class(OcuPilot.Api.Error).#SERVERERROR
            Set tNormCode = ##class(OcuPilot.Api.Error).#INTERNAL
            Set tReason = ..#DEFAULTREASON
        }
        If tCode '= "" {
            Do ..Classify(tCode, .tSlug, .tReason)
        } Else {
            Set tCode = tNormCode
        }
        Set pFault = ..Build(tSlug, tCode, tReason)
    } Catch ex {
        Set pDetail = ""
        Set pFault = ..Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ..#DEFAULTREASON)
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The wire fault <code>{error, reason, code}</code> for a refusal OcuPilot itself decided,
/// where there is no vendor status to normalize. <var>pReason</var> is OcuPilot's own sentence.</p>
ClassMethod Build(pSlug As %String, pCode As %String, pReason As %String) As %DynamicObject
{
    Set tFault = {}
    Do tFault.%Set("error", pSlug)
    Do tFault.%Set("reason", pReason)
    Do tFault.%Set("code", pCode, "string")
    Quit tFault
}

/// <p>The slug and written reason for one of the mapped <code>PORT.*</code> codes. The one
/// place those sentences are written, so <method>Normalize</method> and <method>Outcome</method>
/// cannot word the same code two ways. An unlisted code leaves both outputs unchanged.</p>
ClassMethod Classify(pCode As %String, ByRef pSlug As %String, ByRef pReason As %String) [ Private ]
{
    If pCode = ##class(OcuPilot.Api.Error).#PORTACCESSDENIED {
        Set pSlug = ##class(OcuPilot.Api.Error).#FORBIDDEN
        Set pReason = "This account may not perform that operation on this instance"
    } ElseIf pCode = ##class(OcuPilot.Api.Error).#PORTNOTFOUND {
        Set pSlug = ##class(OcuPilot.Api.Error).#NOTFOUND
        Set pReason = "That item is no longer present on this instance"
    } ElseIf pCode = ##class(OcuPilot.Api.Error).#PORTCONFLICT {
        Set pSlug = ##class(OcuPilot.Api.Error).#CONFLICT
        Set pReason = "An item with that name already exists on this instance"
    } ElseIf pCode = ##class(OcuPilot.Api.Error).#PORTVALIDATION {
        Set pSlug = ##class(OcuPilot.Api.Error).#VALIDATIONFAILED
        Set pReason = "The instance rejected one of the values supplied"
    } ElseIf pCode = ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED {
        Set pSlug = ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED
        Set pReason = "This instance does not implement that operation"
    }
}

/// <p>Send a normalized fault's <b>raw</b> vendor text to the log, and nowhere else.</p>
/// <p>The split is the whole point of this class: <method>Normalize</method> hands a caller
/// three values fit for the wire, and this hands the log the text those three replaced --
/// <method>%SYSTEM.Status.GetErrorText</method>'s full output, message ids and class names
/// included, which is what makes a normalized failure diagnosable at all.</p>
/// @param pSubsystem Subsystem name for the log entry
/// @param pMessage The log entry's message
/// @param pStatus The vendor status whose raw text is logged
/// @param pCode The machine code the client was given, so the log line and the response pair up
ClassMethod LogRaw(pSubsystem As %String, pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Try {
        Set tData = {}
        Do tData.%Set("code", pCode, "string")
        Do tData.%Set("status", $System.Status.GetErrorText(pStatus))
        Do ..LogError(pSubsystem, pMessage, tData)
    } Catch ex {
        ; Logging failures must never propagate (Consistency Conventions: Logging).
    }
}

/// <p>The single audit-log seam <method>LogRaw</method> writes through, for the reason
/// <method>OcuPilot.Api.Error.LogError</method> has one: naming
/// <class>OcuPilot.Kernel.Audit.Log</class> by hard class name leaves nothing a test can
/// intercept, so the claim "the raw text reaches the log" would be unfalsifiable.
/// <class>OcuPilot.Test.FaultProbe</class> overrides this; production never does.</p>
/// @param pSubsystem Subsystem name passed to Log.Error
/// @param pMessage Message passed to Log.Error
/// @param pData Structured detail object passed to Log.Error
ClassMethod LogError(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ##class(OcuPilot.Kernel.Audit.Log).Error(pSubsystem, pMessage, pData)
}

}
