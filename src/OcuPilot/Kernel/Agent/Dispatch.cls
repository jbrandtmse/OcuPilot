/// <p>The turn job's tool dispatcher (AD-1, AD-8, AD-11, AD-22, AD-24, AD-30, AD-39): what a provider
/// request advertises, and the one path by which a model's <code>tool_use</code> reaches a tool.</p>
/// <p><b>Every call runs the same order, and stops at the first refusal:</b></p>
/// <ol>
/// <li>resolve the wire name to a registered tool -- none is <code>TOOL.UNKNOWN</code>;</li>
/// <li>identity: <code>$USERNAME</code> is the turn's user -- otherwise <code>TOOL.UNAVAILABLE</code>,
/// logged;</li>
/// <li>the governance gate point (<class>OcuPilot.Kernel.Governance.Gate</class>) -- a refusal is its
/// code, or <code>TOOL.DENIED</code>;</li>
/// <li>for a write tool, the restraint verdict (<class>OcuPilot.Kernel.Restraint</class>) -- blocked
/// is the verdict's own code, and a verdict that could not be read is
/// <code>TOOL.UNAVAILABLE</code> whatever it says;</li>
/// <li>every declared pair against the user's <b>current</b> grants
/// (<code>$SYSTEM.Security.CheckUserPermission</code>, not the job's frozen <code>$ROLES</code>) --
/// <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>, never retried; pairs that
/// cannot be read are <code>TOOL.UNAVAILABLE</code>;</li>
/// <li>the arguments against the tool's input schema -- <code>TOOL.ARGUMENTS</code> with
/// <code>detail.problem</code>;</li>
/// <li>the pairs the arguments add (a namespace a read names, for instance), against the same
/// current grants and answered the same way;</li>
/// <li>the tool's view, in this process, through
/// <method>OcuPilot.Screen.Tool.Registry.InvokeTool</method> -- a fault answers its own code and
/// detail, and one at HTTP 500 or above is also logged with the view's status.</li>
/// </ol>
/// <p><b>A result reaches the model only as <code>tool_result</code> content</b> (AD-11): the result
/// JSON, capped at <code>TOOLROWS</code> rows and <code>TOOLRESULTMAXLENGTH</code> characters with
/// <code>truncated</code> set when either cut, or <code>{code, detail?}</code> on failure -- never a
/// <code>reason</code> and never vendor text (AD-39). Nothing here names a restraint code; a
/// blocked verdict's code is passed through.</p>
/// <p>Seams a subclass overrides: <method>RegistryClass</method>, <method>GateClass</method>,
/// <method>Restraint</method>, <method>HoldsPair</method> and <method>LogFault</method>. Production
/// overrides none.</p>
Class OcuPilot.Kernel.Agent.Dispatch Extends %RegisteredObject
{

/// <p>The kind whose calls the restraint verdict gates.</p>
Parameter WRITEKIND = "write";

/// <p>The subsystem a dispatch failure is logged under.</p>
Parameter LOGSUBSYSTEM = "tool";

/// <p>The tool registry calls are resolved in and invoked through.</p>
ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Screen.Tool.Registry"
}

/// <p>The governance gate point every call is asked at (AD-22).</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Kernel.Governance.Gate"
}

/// <p>The restraint verdict for a write tool called by <var>pUser</var> under
/// <var>pDefinitionId</var>, read afresh (AD-30).</p>
ClassMethod Restraint(pUser As %String, pDefinitionId As %String, Output pVerdict) As %Status
{
    Quit ##class(OcuPilot.Kernel.Restraint).Verdict(pUser, pDefinitionId, .pVerdict)
}

/// <p>Whether <var>pUser</var>'s current grants hold <var>pPermission</var> on
/// <var>pResource</var> (AD-8, AD-31). A user the instance no longer holds holds nothing.</p>
/// <p><b>Caller contract:</b> <var>pUser</var> is <code>$USERNAME</code>, which is what lets an
/// unprivileged job ask about itself.</p>
ClassMethod HoldsPair(pUser As %String, pResource As %String, pPermission As %String) As %Boolean
{
    Set tHolds = 0
    Try {
        Set tHolds = ($SYSTEM.Security.CheckUserPermission(pUser, pResource, pPermission) = 1)
    } Catch {
        Set tHolds = 0
    }
    Quit tHolds
}

/// <p>Log a dispatch failure with the code the model was answered.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String)
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>The tool array every provider request of a turn carries: every registered tool, in name
/// order, in the shape <method>OcuPilot.Screen.Tool.Registry.ProviderTools</method> answers. On an
/// error <var>pTools</var> is 0 and the turn must make no provider call.</p>
ClassMethod Advertise(Output pTools) As %Status
{
    Kill pTools
    Set pTools = 0
    Set tSC = $$$OK
    Try {
        Set tSC = $ClassMethod(..RegistryClass(), "ProviderTools", .pTools)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) {
        Kill pTools
        Set pTools = 0
    }
    Quit tSC
}

/// <p>Answer the <code>tool_use</code> blocks <var>pToolUses</var> of turn <var>pKey</var>, run
/// for <var>pUser</var> under <var>pDefinitionId</var>, with the caps
/// <var>pLimitsClass</var> declares.</p>
/// <p><var>pResults</var> comes back with one <code>tool_result</code> block per call, in the same
/// order, each carrying the call's <code>tool_use_id</code>, <code>is_error</code> and string
/// <code>content</code>. <var>pNames</var> carries, in the same order, the canonical dotted name of
/// each resolved tool, or the name the model sent for one that did not resolve.</p>
/// <p>An error status means the dispatcher itself failed; every refusal is a result.</p>
/// <p><var>pRowCap</var> and <var>pMaxLength</var> are optional overrides of the row cap and the
/// per-call size budget (AD-24, DW-452): a value above zero is used in place of
/// <var>pLimitsClass</var>'s own <code>TOOLROWS</code> / <code>TOOLRESULTMAXLENGTH</code>, so a
/// caller resolving <code>Switch.ContextRowCap</code> or a shrinking per-reply budget can hand it
/// down without every existing caller having to change.</p>
ClassMethod Answer(pKey As %String, pUser As %String, pDefinitionId As %String, pToolUses As %DynamicArray, pLimitsClass As %String, Output pResults As %DynamicArray, Output pNames As %DynamicArray, pRowCap As %Integer = 0, pMaxLength As %Integer = 0) As %Status
{
    Set tSC = $$$OK
    Set pResults = []
    Set pNames = []
    Try {
        Set tRows = $Select(+pRowCap > 0: +pRowCap, 1: +$Parameter(pLimitsClass, "TOOLROWS"))
        Set tMaxLength = $Select(+pMaxLength > 0: +pMaxLength, 1: +$Parameter(pLimitsClass, "TOOLRESULTMAXLENGTH"))
        Set tIterator = pToolUses.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tBlock) {
            Set tIsError = ..AnswerOne(pKey, pUser, pDefinitionId, tBlock, tRows, tMaxLength, pLimitsClass, .tName, .tContent)
            Set tResult = {}
            Do tResult.%Set("type", "tool_result", "string")
            Do tResult.%Set("tool_use_id", $Select($IsObject(tBlock) && (tBlock.%Get("id") '= ""): tBlock.%Get("id"), 1: "unknown"), "string")
            Do tResult.%Set("is_error", ''tIsError, "boolean")
            Do tResult.%Set("content", tContent, "string")
            Do pResults.%Push(tResult)
            Do pNames.%Push(tName, "string")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Answer one <code>tool_use</code> block in the order this class's header gives. Returns 1 when
/// the answer is an error, with <var>pName</var> the tool's name and <var>pContent</var> the
/// <code>tool_result</code> content. <var>pLimitsClass</var> is the caller's configurable limits
/// class -- the descriptor branch reads <code>FIELDMAXLENGTH</code> from it, the same way
/// <method>Answer</method> reads <code>TOOLROWS</code>/<code>TOOLRESULTMAXLENGTH</code> from it,
/// so a test overriding the limits class sees its override here too.</p>
ClassMethod AnswerOne(pKey As %String, pUser As %String, pDefinitionId As %String, pBlock As %DynamicObject, pRows As %Integer, pMaxLength As %Integer, pLimitsClass As %String, Output pName As %String, Output pContent As %String) As %Boolean [ Private ]
{
    Set tUnavailable = ##class(OcuPilot.Api.Error).#TOOLUNAVAILABLE
    Set pName = ""
    Set pContent = ..ErrorContent(tUnavailable)
    Set tIsError = 1
    Try {
        Set tWire = ""
        Set tInput = ""
        If $IsObject(pBlock) && pBlock.%IsA("%Library.DynamicObject") {
            Set tWire = pBlock.%Get("name")
            Set tInput = pBlock.%Get("input")
        }
        Set pName = tWire
        Set tRegistry = ..RegistryClass()

        Set tSC = $ClassMethod(tRegistry, "ResolveWire", tWire, .tTool)
        If $$$ISERR(tSC) {
            Do ..LogFault("turn " _ pKey _ ": the tool registry could not be read", tSC, tUnavailable)
            Quit
        }
        If '$IsObject(tTool) {
            Set pContent = ..ErrorContent(##class(OcuPilot.Api.Error).#TOOLUNKNOWN)
            Quit
        }
        Set pName = tTool.%Get("name")

        If $Username '= pUser {
            Do ..LogFault("turn " _ pKey _ ": a tool call ran as a user other than the turn's", $$$ERROR($$$GeneralError, "the process user differs from the turn's user"), tUnavailable)
            Quit
        }

        Kill tDecision
        Set tSC = $ClassMethod(..GateClass(), "Decide", pName, tTool.%Get("kind"), pUser, tInput, .tDecision)
        If $$$ISERR(tSC) {
            Do ..LogFault("turn " _ pKey _ ": the governance gate could not decide " _ pName, tSC, tUnavailable)
            Quit
        }
        If '$Get(tDecision("allowed")) {
            Set tCode = $Get(tDecision("code"))
            Set pContent = ..ErrorContent($Select(tCode '= "": tCode, 1: ##class(OcuPilot.Api.Error).#TOOLDENIED))
            Quit
        }

        If tTool.%Get("kind") = ..#WRITEKIND {
            Kill tVerdict
            Set tSC = ..Restraint(pUser, pDefinitionId, .tVerdict)
            If $$$ISERR(tSC) {
                Do ..LogFault("turn " _ pKey _ ": the restraint verdict could not be read for " _ pName, tSC, tUnavailable)
                Quit
            }
            If +$Get(tVerdict("blocked")) {
                If $Get(tVerdict("code")) '= "" Set pContent = ..ErrorContent(tVerdict("code"))
                Quit
            }
        }

        Set tPairs = $ClassMethod(tRegistry, "RequiredPairs", tTool, .tResolved)
        If 'tResolved {
            Do ..LogFault("turn " _ pKey _ ": the privilege pairs of " _ pName _ " could not be read", $$$ERROR($$$GeneralError, "unresolved pairs"), tUnavailable)
            Quit
        }
        Set tFailedPair = ..MissingPair(pUser, tPairs)
        If tFailedPair '= "" {
            Set pContent = ..DeniedContent(tFailedPair)
            Quit
        }

        Set tSC = $ClassMethod(tRegistry, "ValidateArguments", $ClassMethod(tRegistry, "InputSchemaOf", tTool), tInput, .tProblem)
        If $$$ISERR(tSC) {
            Set tDetail = {}
            Do tDetail.%Set("problem", tProblem, "string")
            Set pContent = ..ErrorContent(##class(OcuPilot.Api.Error).#TOOLARGUMENTS, tDetail)
            Quit
        }

        Set tArgumentPairs = $ClassMethod(tRegistry, "ArgumentPairs", tTool, tInput, .tResolved)
        If 'tResolved {
            Do ..LogFault("turn " _ pKey _ ": the privilege pairs the arguments of " _ pName _ " add could not be read", $$$ERROR($$$GeneralError, "unresolved argument pairs"), tUnavailable)
            Quit
        }
        Set tFailedPair = ..MissingPair(pUser, tArgumentPairs)
        If tFailedPair '= "" {
            Set pContent = ..DeniedContent(tFailedPair)
            Quit
        }

        Set tSC = $ClassMethod(tRegistry, "InvokeTool", tTool, tInput, pRows, .tResult, .tHttp, .tFault)
        If $$$ISERR(tSC) {
            If $IsObject(tFault) && (tFault.%Get("code") '= "") {
                Set pContent = ..ErrorContent(tFault.%Get("code"), $Select(tFault.%GetTypeOf("detail") = "object": tFault.%Get("detail"), 1: ""))
                If +$Get(tHttp) >= 500 Do ..LogFault("turn " _ pKey _ ": " _ pName _ " failed on the instance", tSC, tFault.%Get("code"))
            } Else {
                Do ..LogFault("turn " _ pKey _ ": " _ pName _ " failed with no fault", tSC, tUnavailable)
            }
            Quit
        }
        If '$IsObject(tResult) || 'tResult.%IsA("%Library.DynamicObject") {
            Do ..LogFault("turn " _ pKey _ ": " _ pName _ " answered no result", $$$ERROR($$$GeneralError, "no result object"), tUnavailable)
            Quit
        }
        ; A descriptor-derived read tool's result (AD-36) is bounded through the kernel cutter
        ; shared with screen context (AD-24, DW-281): the per-field cut and the richer report. A
        ; tool with a class of its own -- including every fixture in this suite -- has no
        ; descriptor and no per-field bound to apply, so it keeps the plain row-and-size cut
        ; unchanged, byte for byte.
        If tTool.%Get("descriptor") '= "" {
            Do ##class(OcuPilot.Screen.Tool.Registry).FieldMaxLengths(tTool, .tFieldMax)
            Set tDefaultFieldMax = +$Parameter(pLimitsClass, "FIELDMAXLENGTH")
            If '##class(OcuPilot.Kernel.Agent.Bound).Apply(tResult, pRows, .tFieldMax, tDefaultFieldMax, pMaxLength, .tJson) {
                Set pContent = ..ErrorContent(##class(OcuPilot.Api.Error).#TOOLRESULTTOOLARGE)
                Quit
            }
        } ElseIf '..Capped(tResult, pRows, pMaxLength, .tJson) {
            Set pContent = ..ErrorContent(##class(OcuPilot.Api.Error).#TOOLRESULTTOOLARGE)
            Quit
        }
        Set pContent = tJson
        Set tIsError = 0
    } Catch ex {
        Set tIsError = 1
        Set pContent = ..ErrorContent(tUnavailable)
        Do ..LogFault("turn " _ pKey _ ": a tool call failed inside the dispatcher", ex.AsStatus(), tUnavailable)
    }
    Quit tIsError
}

/// <p>The first pair in <var>pPairs</var>, spelled <code>resource:permission</code>, that
/// <var>pUser</var>'s current grants do not hold (<method>HoldsPair</method>), or <code>""</code>
/// when they hold every one.</p>
ClassMethod MissingPair(pUser As %String, pPairs As %List) As %String [ Private ]
{
    Set tFailedPair = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tPair = $List(pPairs, tI)
        If '..HoldsPair(pUser, $List(tPair, 1), $List(tPair, 2)) {
            Set tFailedPair = $List(tPair, 1) _ ":" _ $List(tPair, 2)
            Quit
        }
    }
    Quit tFailedPair
}

/// <p>The content of a pair refusal: <code>AUTH.NOPRIVILEGE</code> naming
/// <var>pFailedPair</var> as <code>detail.failedPair</code> (AD-8).</p>
ClassMethod DeniedContent(pFailedPair As %String) As %String [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("failedPair", pFailedPair, "string")
    Quit ..ErrorContent(##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, tDetail)
}

/// <p>The content of an error <code>tool_result</code>: <code>{code}</code>, plus
/// <code>detail</code> when <var>pDetail</var> is an object (AD-39).</p>
ClassMethod ErrorContent(pCode As %String, pDetail As %DynamicObject = "") As %String
{
    Set tContent = {}
    Do tContent.%Set("code", pCode, "string")
    If $IsObject(pDetail) Do tContent.%Set("detail", pDetail)
    Quit tContent.%ToJSON()
}

/// <p><var>pResult</var> within both caps, serialized into <var>pJson</var>. A <code>rows</code>
/// array longer than <var>pRows</var> is cut to it; a serialization longer than
/// <var>pMaxLength</var> characters has trailing rows dropped until it fits. Either cut sets
/// <code>truncated</code> true. Returns 0 when the result cannot fit, having no rows left to drop.</p>
ClassMethod Capped(pResult As %DynamicObject, pRows As %Integer, pMaxLength As %Integer, Output pJson As %String) As %Boolean
{
    Set pJson = ""
    Set tRows = pResult.%Get("rows")
    Set tHasRows = $IsObject(tRows) && tRows.%IsA("%Library.DynamicArray")
    If tHasRows && (tRows.%Size() > pRows) {
        Set tKept = []
        For tI = 0:1:pRows - 1 {
            Do tKept.%Push(tRows.%Get(tI))
        }
        Do pResult.%Set("rows", tKept)
        Do pResult.%Set("truncated", 1, "boolean")
        Set tRows = tKept
    }
    Set tFits = 0
    Try {
        Set pJson = pResult.%ToJSON()
        Set tFits = ($Length(pJson) <= pMaxLength)
    } Catch {
        Set tFits = 0
    }
    If tFits Quit 1
    Set pJson = ""
    If 'tHasRows Quit 0

    ; Measure each row once, then keep the longest prefix that fits beside the rest of the result.
    Set tCount = tRows.%Size()
    Do pResult.%Set("rows", [])
    Do pResult.%Set("truncated", 1, "boolean")
    Set tTotal = $Length(pResult.%ToJSON())
    Set tKeep = 0
    For tI = 0:1:tCount - 1 {
        Set tHolder = []
        Do tHolder.%Push(tRows.%Get(tI))
        Set tAdd = ($Length(tHolder.%ToJSON()) - 2) + (tKeep > 0)
        If (tTotal + tAdd) > pMaxLength Quit
        Set tTotal = tTotal + tAdd
        Set tKeep = tKeep + 1
    }
    If tTotal > pMaxLength Quit 0
    Set tKept = []
    For tI = 0:1:tKeep - 1 {
        Do tKept.%Push(tRows.%Get(tI))
    }
    Do pResult.%Set("rows", tKept)
    Set pJson = pResult.%ToJSON()
    If $Length(pJson) > pMaxLength {
        Set pJson = ""
        Quit 0
    }
    Quit 1
}

}
