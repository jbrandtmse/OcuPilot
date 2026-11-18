/// <p>The locale definitions' refusals (AD-29, AD-51, AD-55, Story 21.14): which write may not run against the locale's state, as one
/// code from <class>OcuPilot.Api.LocaleError</class>, before any vendor call. Two callers ask the same question: the write tools' mint
/// (<method>WriteProblem</method>), which phrases it for the person or the agent, and <class>OcuPilot.Port.LocalePort</class>, which asks
/// it again at the write for the confirm and for a screen's action alike (<method>Code</method>). It also answers the screen-only route
/// <code>GET /locales/:name/validation</code> (<method>HandleValidate</method>).</p>
/// <p><b>The state is the port's own read</b> of the locale (<code>GET</code>): its row's <code>Custom</code> and <code>Current</code>.
/// Whether the vendor's own check admits an install is the port's to ask, inside the confirmed install (<code>pInstallable</code> of
/// <method>Code</method>); the mint never asks it, because the vendor's check writes some locales' definitions. Nothing here reads the
/// instance.</p>
Class OcuPilot.Area.OsMgmt.LocaleRules Extends %RegisteredObject
{

/// <p>The write types this class judges.</p>
Parameter INSTALL = "INSTALL";

Parameter DELETE = "DELETE";

/// <p>The screen whose declared pairs gate the validation route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocaleList";

/// <p>The code of the refusal the write <var>pWriteType</var> meets against the locale row <var>pRow</var>, or <code>""</code> when it
/// may run. An install is refused when <var>pInstallable</var>, the vendor's own answer, is false. A delete is refused for a locale InterSystems ships (its name
/// does not start with <code>y</code>) and then for the current locale.</p>
ClassMethod Code(pWriteType As %String, pRow As %DynamicObject, pInstallable As %Boolean = 1) As %String
{
    If pWriteType = ..#INSTALL {
        If 'pInstallable Quit ##class(OcuPilot.Api.LocaleError).#NOTINSTALLABLE
        Quit ""
    }
    If pWriteType = ..#DELETE {
        If '..Flag(pRow, "Custom") Quit ##class(OcuPilot.Api.LocaleError).#SYSTEM
        If ..Flag(pRow, "Current") Quit ##class(OcuPilot.Api.LocaleError).#CURRENT
        Quit ""
    }
    Quit ""
}

/// <p>The agent's arguments refused by the write's rules against the locale's state, before anything is stored (AD-55): the locale is read
/// through the tool's own port and <method>Code</method> asks the question. A locale the port reports absent is its own refusal sentence; any other failed read is an error status.</p>
/// <p><var>pProblem</var> is the sentence, or <code>""</code> when the write may run.</p>
ClassMethod WriteProblem(pToolClass As %String, pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tPort = $ClassMethod(pToolClass, "PortClass")
        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "ReadIdParam")) = pIdValue
        Set tReadSC = $ClassMethod(tPort, "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .tRow, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            If ..IsRefusal($Get(tFault)) {
                Set pProblem = tFault.%Get("reason")
                Quit
            }
            Set tSC = tReadSC
            Quit
        }
        Set tCode = ..Code($ClassMethod(pToolClass, "WriteType"), tRow)
        If tCode '= "" Set pProblem = ##class(OcuPilot.Api.LocaleError).ReasonFor(tCode)
    } Catch ex {
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><code>GET /locales/:name/validation</code>: the Validate dialog's read, screen-only. The caller's pairs are the screen's (AD-8), then
/// <class>OcuPilot.Port.LocalePort</class> reads the locale named by the percent-encoded segment <var>pName</var> and answers
/// <code>{Name, Valid, ErrorCount, WarningCount}</code>, no vendor-written line (AD-39). A locale the instance does not list is
/// 404 <code>LOCALE.NOTFOUND</code>.</p>
ClassMethod HandleValidate(pName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tFailedPair = ""
        If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
            Set tSC = ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
            Quit
        }
        Set tPort = "OcuPilot.Port.LocalePort"
        Kill tQuery
        Set tQuery($Parameter(tPort, "NAMEKEY")) = ##class(OcuPilot.Kernel.EntityId).Decode(pName)
        Set tReadSC = $ClassMethod(tPort, "Invoke", $Parameter(tPort, "VALIDATIONENDPOINT"), $Parameter(tPort, "TYPEGET"), .tQuery, "", .tAnswer, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            Set tSC = ..RenderRefusal(tReadSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The envelope for the port's refusal <var>pFault</var> on status <var>pHttpStatus</var>; a fault that is the generic internal one, or
/// none, is rendered as an internal error carrying <var>pSC</var>.</p>
ClassMethod RenderRefusal(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status [ Private ]
{
    If '..IsRefusal($Get(pFault)) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Whether <var>pFault</var> is a wire fault carrying a written reason that is not the generic internal one.</p>
ClassMethod IsRefusal(pFault) As %Boolean [ Private ]
{
    If '$IsObject(pFault) || 'pFault.%IsA("%Library.DynamicObject") Quit 0
    Quit (pFault.%Get("reason") '= "") && (pFault.%Get("code") '= ##class(OcuPilot.Api.Error).#INTERNAL)
}

/// <p>Whether <var>pObject</var>'s <var>pField</var> is true or 1.</p>
ClassMethod Flag(pObject, pField As %String) As %Boolean [ Private ]
{
    If '$IsObject(pObject) || 'pObject.%IsA("%Library.DynamicObject") Quit 0
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit 0
    Set tText = pObject.%Get(pField) _ ""
    Quit (tText = 1) || (tText = "true")
}

}
