/// <p>The Guardrails page's answer (Story 16.22), served by <class>OcuPilot.Api.UiGuardrails</class> as
/// <code>GET /api/ocupilot/ui/guardrails</code>. It is shell chrome (AD-50), like
/// <code>/agent/restraint</code>: not a declared read, a tool or screen context (AD-24, AD-36).</p>
/// <p><b>It reads the declarations that already enforce, and adds no enforcement of its own</b>
/// (AD-30):</p>
/// <ul>
/// <li><code>prohibited</code> -- the prohibited set's codes in declared order, each with the
/// sentence its <code>ReasonFor</code> answers, both from <method>ProhibitedClass</method> (AD-10,
/// AD-53);</li>
/// <li><code>switches</code> -- the caller's own restraint verdict's <code>killSwitch</code>,
/// <code>killSwitchAudience</code> and <code>enforcedReadOnly</code>, the answer
/// <code>GET /agent/restraint</code> gives (AD-30);</li>
/// <li><code>confirmTools</code> -- every advertised tool the registry classifies
/// <code>write</code>, in name order, with the descriptor class it writes for (AD-22, AD-53);</li>
/// <li><code>secrets</code> -- for each of those tools declaring at least one secret argument,
/// its names (AD-3, AD-35);</li>
/// <li><code>limits</code> -- the context row cap in force and the two character caps
/// (AD-24).</li>
/// </ul>
/// <p><b>It fails closed.</b> A part that cannot be read fails the whole answer, and a tool whose
/// secret arguments could not be read is such a part rather than a tool with none.</p>
Class OcuPilot.Kernel.Shell.Guardrails Extends %RegisteredObject
{

/// <p>The tool kind whose tools always need a Confirm (AD-22).</p>
Parameter WRITEKIND = "write";

/// <p>AD-10's prohibited set, the one the write path asks. Overridable so a fixture can add a
/// code; production never overrides it.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit ##class(OcuPilot.Kernel.Proposal.Write).ProhibitedClass()
}

/// <p>The tool registry the dispatch path resolves through. Overridable for a fixture.</p>
ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Screen.Tool.Registry"
}

/// <p><var>pUser</var>'s restraint verdict, subscripted as
/// <method>OcuPilot.Kernel.Restraint.Resolved</method> answers it. Overridable for a fixture.</p>
ClassMethod Verdict(pUser As %String, Output pVerdict) As %Status
{
    Quit ##class(OcuPilot.Kernel.Restraint).Resolved(pUser, .pVerdict)
}

/// <p>Compose the answer for the calling user into <var>pAnswer</var>, writing nothing. On an
/// error <var>pAnswer</var> is <code>""</code>.</p>
ClassMethod Read(Output pAnswer As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Try {
        Set tAnswer = {}

        Set tProhibitedClass = ..ProhibitedClass()
        Set tCodes = $ClassMethod(tProhibitedClass, "Codes")
        Set tProhibited = []
        For tI = 1:1:$ListLength(tCodes) {
            Set tCode = $List(tCodes, tI)
            Do tProhibited.%Push({"code": (tCode), "reason": ($ClassMethod(tProhibitedClass, "ReasonFor", tCode))})
        }
        Do tAnswer.%Set("prohibited", tProhibited)

        Set tSC = ..Verdict($Username, .tVerdict)
        If $$$ISERR(tSC) Quit
        Set tSwitches = {}
        Do tSwitches.%Set("killSwitch", $Select(+$Get(tVerdict("killSwitch")): 1, 1: 0), "boolean")
        Do tSwitches.%Set("killSwitchAudience", $Get(tVerdict("killSwitchAudience")), "string")
        Do tSwitches.%Set("enforcedReadOnly", $Select(+$Get(tVerdict("enforcedReadOnly")): 1, 1: 0), "boolean")
        Do tAnswer.%Set("switches", tSwitches)

        Set tRegistry = ..RegistryClass()
        Set tSC = $ClassMethod(tRegistry, "ListTools", .tTools)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tTools) {
            Set tSC = $$$ERROR($$$GeneralError, "the tool registry answered no list")
            Quit
        }
        Set tConfirm = []
        Set tSecrets = []
        Set tIterator = tTools.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tTool) {
            If tTool.%Get("kind") '= ..#WRITEKIND Continue
            If 'tTool.%Get("advertised") Continue
            Set tName = tTool.%Get("name")
            Do tConfirm.%Push({"name": (tName), "descriptor": ($Parameter(tTool.%Get("class"), "DESCRIPTORCLASS"))})
            Set tNames = $ClassMethod(tRegistry, "SecretArguments", tTool, .tDeclared)
            If 'tDeclared {
                Set tSC = $$$ERROR($$$GeneralError, tName _ " declares no answer for its secret arguments")
                Quit
            }
            If $ListLength(tNames) = 0 Continue
            Set tFields = []
            For tJ = 1:1:$ListLength(tNames) Do tFields.%Push($List(tNames, tJ))
            Do tSecrets.%Push({"tool": (tName), "fields": (tFields)})
        }
        If $$$ISERR(tSC) Quit
        Do tAnswer.%Set("confirmTools", tConfirm)
        Do tAnswer.%Set("secrets", tSecrets)

        Set tSC = ##class(OcuPilot.Kernel.State.Switch).Resolve(.tSwitchValues)
        If $$$ISERR(tSC) Quit
        Set tLimits = {}
        Do tLimits.%Set("contextRowCap", +tSwitchValues("contextRowCap"), "number")
        Do tLimits.%Set("totalMaxLength", +##class(OcuPilot.Kernel.Agent.Limits).#TOOLRESULTMAXLENGTH, "number")
        Do tLimits.%Set("fieldMaxLength", +##class(OcuPilot.Kernel.Agent.Limits).#FIELDMAXLENGTH, "number")
        Do tAnswer.%Set("limits", tLimits)

        Set pAnswer = tAnswer
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Set pAnswer = ""
    Quit tSC
}

}
