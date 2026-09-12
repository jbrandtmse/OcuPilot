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
/// <p>Declared with no port call site yet: <class>OcuPilot.Port.AdminPort</class> returns raw
/// statuses plus hand-built English today, and Epic 2 is where the invocation sequence that
/// produces vendor failures lands. The mapping is fixed now so the first of those reads does
/// not mint a second one (the reason <parameter>AUTHNOPRIVILEGE</parameter> was declared early
/// in <class>OcuPilot.Api.Error</class>).</p>
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
            Set pSlug = ##class(OcuPilot.Api.Error).#FORBIDDEN, pCode = ##class(OcuPilot.Api.Error).#PORTACCESSDENIED
            Set pReason = "This account may not perform that operation on this instance"
            Quit
        }
        If $System.Status.Equals(pStatus, $$$ERRORCODE($$$LoadObjectNotFound), $$$ERRORCODE($$$DeleteObjectNotFound)) {
            Set pSlug = ##class(OcuPilot.Api.Error).#NOTFOUND, pCode = ##class(OcuPilot.Api.Error).#PORTNOTFOUND
            Set pReason = "That item is no longer present on this instance"
            Quit
        }
        If $System.Status.Equals(pStatus, $$$ERRORCODE($$$IDKeyNotUnique), $$$ERRORCODE($$$KeyNotUnique)) {
            Set pSlug = ##class(OcuPilot.Api.Error).#CONFLICT, pCode = ##class(OcuPilot.Api.Error).#PORTCONFLICT
            Set pReason = "An item with that name already exists on this instance"
            Quit
        }
        If $System.Status.Equals(pStatus, $$$ERRORCODE($$$PropertyRequired), $$$ERRORCODE($$$DatatypeValidationFailed)) {
            Set pSlug = ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, pCode = ##class(OcuPilot.Api.Error).#PORTVALIDATION
            Set pReason = "The instance rejected one of the values supplied"
            Quit
        }
        If $System.Status.Equals(pStatus, $$$ERRORCODE($$$NotImplemented)) {
            Set pSlug = ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, pCode = ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED
            Set pReason = "This instance does not implement that operation"
            Quit
        }
        ; Everything else keeps the defaults set above. The table grows when a port meets a
        ; status worth telling apart -- never by widening one of the rows to cover it.
    } Catch ex {
        Set pSlug = ##class(OcuPilot.Api.Error).#SERVERERROR
        Set pCode = ##class(OcuPilot.Api.Error).#INTERNAL
        Set pReason = ..#DEFAULTREASON
        Set tSC = ex.AsStatus()
    }
    Quit tSC
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
