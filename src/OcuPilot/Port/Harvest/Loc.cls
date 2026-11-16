/// <p>The line-count body (AD-23). It validates the request, switches to the target namespace by
/// save and restore, runs <method>OcuPilot.Port.Harvest.LocGenerate.Count</method> and renders its
/// result once. The library classes are inherited, so the body's calls resolve while the namespace
/// is switched. A harvested handler body, called only through <class>OcuPilot.Port.HarvestPort</class>.</p>
Class OcuPilot.Port.Harvest.Loc Extends (OcuPilot.Port.Harvest.Handler, OcuPilot.Port.Harvest.LocGenerate, OcuPilot.Port.Harvest.LocScanner, OcuPilot.Port.Harvest.LocClassifier)
{

/// <p>Count the lines of the documents a spec names. The query keys are <code>spec</code>, required
/// (comma-separated names with <code>*</code> and <code>?</code> wildcards, such as
/// <code>MyApp.*.cls,*.mac</code>), <code>namespace</code> (default the current one),
/// <code>includeGenerated</code> (0, 1, true or false; default 0) and <code>topN</code> (a positive integer,
/// default 20, clamped to 1 through 100). A bad value is an error status, rendered sanitized.</p>
ClassMethod LocCount() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSpec = $ZStrip($Get(%request.Data("spec",1)), "<>W")
        Set tNamespace = $Get(%request.Data("namespace",1))
        Set tIncludeGeneratedRaw = $ZConvert($Get(%request.Data("includeGenerated",1)), "L")
        Set tTopNRaw = $Get(%request.Data("topN",1))

        ; spec is REQUIRED (decision D2 — no implicit whole-namespace scan)
        Set tSC = ..ValidateRequired(tSpec, "spec")
        If $$$ISERR(tSC) {
            Do ..RenderResponseBody(..SanitizeError(tSC))
            Set tSC = $$$OK
            Quit
        }

        ; includeGenerated: 0/1/true/false, default false when omitted
        Set tIncludeGenerated = 0
        If tIncludeGeneratedRaw '= "" {
            If (tIncludeGeneratedRaw = "1") || (tIncludeGeneratedRaw = "true") {
                Set tIncludeGenerated = 1
            } ElseIf (tIncludeGeneratedRaw '= "0") && (tIncludeGeneratedRaw '= "false") {
                Set tSC = $$$ERROR($$$GeneralError, "Parameter 'includeGenerated' must be one of: 0, 1, true, false")
                Do ..RenderResponseBody(..SanitizeError(tSC))
                Set tSC = $$$OK
                Quit
            }
        }

        ; topN: positive integer, default 20, clamped to 1..100
        Set tTopN = 20
        If tTopNRaw '= "" {
            If tTopNRaw '? 1.N {
                Set tSC = $$$ERROR($$$GeneralError, "Parameter 'topN' must be a positive integer")
                Do ..RenderResponseBody(..SanitizeError(tSC))
                Set tSC = $$$OK
                Quit
            }
            Set tTopN = +tTopNRaw
            If tTopN < 1 Set tTopN = 1
            If tTopN > 100 Set tTopN = 100
        }

        ; switch to the target namespace (explicit save/restore — Rule #7)
        If tNamespace '= "" {
            Set tSC = ..SwitchNamespace(tNamespace, .tOrigNS)
            If $$$ISERR(tSC) { Do ..RenderResponseBody(..SanitizeError(tSC)) Set tSC = $$$OK Quit }
        }

        ; delegate to the LOC library facade
        Set tOptions = {}
        Do tOptions.%Set("includeGenerated", tIncludeGenerated, "boolean")
        Do tOptions.%Set("topN", tTopN, "number")
        Set tResult = ""
        Set tSC = ..Count(tNamespace, tSpec, tOptions, .tResult)
        If $$$ISERR(tSC) {
            Set $NAMESPACE = tOrigNS
            Do ..RenderResponseBody(..SanitizeError(tSC))
            Set tSC = $$$OK
            Quit
        }

        Set $NAMESPACE = tOrigNS
        Do ..RenderResponseBody($$$OK, , tResult)
    }
    Catch ex {
        Set $NAMESPACE = tOrigNS
        Do ..RenderResponseBody(..SanitizeError(ex.AsStatus()))
        Set tSC = $$$OK
    }
    Quit $$$OK
}

}
