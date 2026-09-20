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

/// <p>The agent ledger every answered call is recorded in (Story 4.9, AD-41). Overridable so a test
/// can observe what a dispatch recorded without reading the store; production never overrides it.</p>
ClassMethod LedgerClass() As %String
{
    Quit "OcuPilot.Kernel.Audit.Ledger"
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
/// <p><var>pDetails</var> comes back parallel to <var>pResults</var>/<var>pNames</var>, one
/// <code>{target, arguments, argumentsTruncated, result, reason, failedPair}</code> per call
/// (Story 4.5, DW-451): <code>target</code> and <code>arguments</code> describe the call itself
/// and are present whether it succeeded or failed; <code>argumentsTruncated</code> is
/// <method>RedactedArguments</method>'s own cap answer, threaded through so the caller storing
/// <code>arguments</code> never has to re-cap it to learn whether it was cut; <code>result</code>
/// is <code>{rowsReturned, rowsSent, truncated}</code> when the call succeeded with a rows-shaped
/// result, else <code>""</code>; <code>reason</code> and <code>failedPair</code> are set only on
/// failure, the latter only when the failure carries <code>detail.failedPair</code>.</p>
ClassMethod Answer(pKey As %String, pUser As %String, pDefinitionId As %String, pToolUses As %DynamicArray, pLimitsClass As %String, Output pResults As %DynamicArray, Output pNames As %DynamicArray, pRowCap As %Integer = 0, pMaxLength As %Integer = 0, Output pDetails As %DynamicArray, pRoute As %String = "") As %Status
{
    Set tSC = $$$OK
    Set pResults = []
    Set pNames = []
    Set pDetails = []
    Try {
        Set tRows = $Select(+pRowCap > 0: +pRowCap, 1: +$Parameter(pLimitsClass, "TOOLROWS"))
        Set tMaxLength = $Select(+pMaxLength > 0: +pMaxLength, 1: +$Parameter(pLimitsClass, "TOOLRESULTMAXLENGTH"))
        Set tIterator = pToolUses.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tBlock) {
            Set tIsError = ..AnswerOne(pKey, pUser, pDefinitionId, tBlock, tRows, tMaxLength, pLimitsClass, .tName, .tContent, .tTarget, .tArguments, .tResultInfo, .tReason, .tFailedPair, .tArgumentsTruncated, pRoute)
            Set tResult = {}
            Do tResult.%Set("type", "tool_result", "string")
            Do tResult.%Set("tool_use_id", $Select($IsObject(tBlock) && (tBlock.%Get("id") '= ""): tBlock.%Get("id"), 1: "unknown"), "string")
            Do tResult.%Set("is_error", ''tIsError, "boolean")
            Do tResult.%Set("content", tContent, "string")
            Do pResults.%Push(tResult)
            Do pNames.%Push(tName, "string")
            Set tDetail = {}
            Do tDetail.%Set("target", tTarget, "string")
            Do tDetail.%Set("arguments", tArguments, "string")
            Do tDetail.%Set("argumentsTruncated", ''tArgumentsTruncated, "boolean")
            Do tDetail.%Set("result", tResultInfo, "string")
            Do tDetail.%Set("reason", tReason, "string")
            Do tDetail.%Set("failedPair", tFailedPair, "string")
            Do pDetails.%Push(tDetail)
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
/// <p><var>pTarget</var> and <var>pArguments</var> (Story 4.5, DW-451) describe the call and are
/// set as soon as its input is parsed, whichever branch below answers it; <var>pArgumentsTruncated</var>
/// is <method>RedactedArguments</method>'s own answer for whether its cap cut <var>pArguments</var>.
/// <var>pResultInfo</var> is JSON <code>{rowsReturned, rowsSent, truncated}</code> on a rows-shaped
/// success, else <code>""</code>. <var>pReason</var> is the failing code's published sentence
/// (<method>OcuPilot.Api.Error.ReasonForToolCode</method>), set on every failure branch;
/// <var>pFailedPair</var> is set only by the two privilege-pair refusals.</p>
ClassMethod AnswerOne(pKey As %String, pUser As %String, pDefinitionId As %String, pBlock As %DynamicObject, pRows As %Integer, pMaxLength As %Integer, pLimitsClass As %String, Output pName As %String, Output pContent As %String, Output pTarget As %String, Output pArguments As %String, Output pResultInfo As %String, Output pReason As %String, Output pFailedPair As %String, Output pArgumentsTruncated As %Boolean, pRoute As %String = "") As %Boolean [ Private ]
{
    Set tUnavailable = ##class(OcuPilot.Api.Error).#TOOLUNAVAILABLE
    Set pName = ""
    Set pContent = ..ErrorContent(tUnavailable)
    Set pTarget = ""
    Set pArguments = ""
    Set pArgumentsTruncated = 0
    Set pResultInfo = ""
    Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(tUnavailable)
    Set pFailedPair = ""
    Set tIsError = 1
    Try {
        Set tWire = ""
        Set tInput = ""
        If $IsObject(pBlock) && pBlock.%IsA("%Library.DynamicObject") {
            Set tWire = pBlock.%Get("name")
            Set tInput = pBlock.%Get("input")
        }
        Set pName = tWire
        Set pTarget = ..TargetOf(tInput)
        Set pArguments = ..RedactedArguments(tInput, +$Parameter(pLimitsClass, "SUMMARYMAXLENGTH"), .pArgumentsTruncated)
        Set tRegistry = ..RegistryClass()

        Set tSC = $ClassMethod(tRegistry, "ResolveWire", tWire, .tTool)
        If $$$ISERR(tSC) {
            Do ..LogFault("turn " _ pKey _ ": the tool registry could not be read", tSC, tUnavailable)
            Quit
        }
        If '$IsObject(tTool) {
            Set pContent = ..ErrorContent(##class(OcuPilot.Api.Error).#TOOLUNKNOWN)
            Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(##class(OcuPilot.Api.Error).#TOOLUNKNOWN)
            Quit
        }
        Set pName = tTool.%Get("name")
        ; The tool's own secret-argument declaration, taken as soon as the tool resolves so every
        ; later refusal branch records its row with the same classification a success would (AD-3).
        Set tSecretNames = $ClassMethod(tRegistry, "SecretArguments", tTool, .tSecretDeclared)
        ; The step's argument summary is re-derived now that the declaration is known, so layer 1
        ; runs on it too. Set above from the name pattern alone, because a call refused before its
        ; tool resolved has no declaration to read; a pattern-only summary of a resolved call's
        ; arguments would store a secret held in a field called Value in clear (AD-3).
        Set pArguments = ..StepArguments(tInput, tSecretNames, pLimitsClass, .pArgumentsTruncated)

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
            Set tCode = $Select(tCode '= "": tCode, 1: ##class(OcuPilot.Api.Error).#TOOLDENIED)
            Set pContent = ..ErrorContent(tCode)
            Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(tCode)
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
                If $Get(tVerdict("code")) '= "" {
                    Set pContent = ..ErrorContent(tVerdict("code"))
                    Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(tVerdict("code"))
                }
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
            Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE)
            Set pFailedPair = tFailedPair
            Quit
        }

        Set tSC = $ClassMethod(tRegistry, "ValidateArguments", $ClassMethod(tRegistry, "InputSchemaOf", tTool), tInput, .tProblem)
        If $$$ISERR(tSC) {
            Set tDetail = {}
            Do tDetail.%Set("problem", tProblem, "string")
            Set pContent = ..ErrorContent(##class(OcuPilot.Api.Error).#TOOLARGUMENTS, tDetail)
            Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(##class(OcuPilot.Api.Error).#TOOLARGUMENTS)
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
            Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE)
            Set pFailedPair = tFailedPair
            Quit
        }

        Set tSC = $ClassMethod(tRegistry, "InvokeTool", tTool, tInput, pRows, .tResult, .tHttp, .tFault)
        If $$$ISERR(tSC) {
            If $IsObject(tFault) && (tFault.%Get("code") '= "") {
                Set pContent = ..ErrorContent(tFault.%Get("code"), $Select(tFault.%GetTypeOf("detail") = "object": tFault.%Get("detail"), 1: ""))
                Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(tFault.%Get("code"))
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
        ; Every rows-shaped read result (AD-36) is bounded through the kernel cutter shared with
        ; screen context (AD-24, DW-281): the per-field cut and the richer report. This is a
        ; descriptor-derived read, or a class-of-its-own tool whose own result still carries a
        ; rows array (OcuPilot.Screen.Tool.ErrorRead among them) -- FieldMaxLengths answers empty
        ; for a tool with no descriptor, so such a tool falls back everywhere to FIELDMAXLENGTH. A
        ; result with no rows array at all (a shell read's opaque payload) keeps the plain
        ; row-and-size cut unchanged, byte for byte: Bound would otherwise stamp
        ; rows/rowsSent/rowsAvailable/truncatedFields onto a payload that never declared them.
        Set tResultRows = tResult.%Get("rows")
        Set tRowsShaped = $IsObject(tResultRows) && tResultRows.%IsA("%Library.DynamicArray")
        If tRowsShaped {
            Do ##class(OcuPilot.Screen.Tool.Registry).FieldMaxLengths(tTool, .tFieldMax)
            Set tDefaultFieldMax = +$Parameter(pLimitsClass, "FIELDMAXLENGTH")
            If '##class(OcuPilot.Kernel.Agent.Bound).Apply(tResult, pRows, .tFieldMax, tDefaultFieldMax, pMaxLength, .tJson) {
                Set pContent = ..ErrorContent(##class(OcuPilot.Api.Error).#TOOLRESULTTOOLARGE)
                Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(##class(OcuPilot.Api.Error).#TOOLRESULTTOOLARGE)
                Quit
            }
        } ElseIf '..Capped(tResult, pRows, pMaxLength, .tJson) {
            Set pContent = ..ErrorContent(##class(OcuPilot.Api.Error).#TOOLRESULTTOOLARGE)
            Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(##class(OcuPilot.Api.Error).#TOOLRESULTTOOLARGE)
            Quit
        }
        Set pContent = tJson
        Set pReason = ""
        If tRowsShaped {
            Set tResultInfoObj = {}
            Do tResultInfoObj.%Set("rowsReturned", +tResult.%Get("rowsAvailable"), "number")
            Do tResultInfoObj.%Set("rowsSent", +tResult.%Get("rowsSent"), "number")
            Do tResultInfoObj.%Set("truncated", ''tResult.%Get("truncated"), "boolean")
            Set pResultInfo = tResultInfoObj.%ToJSON()
        }
        Set tIsError = 0
    } Catch ex {
        Set tIsError = 1
        Set pContent = ..ErrorContent(tUnavailable)
        Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(tUnavailable)
        Do ..LogFault("turn " _ pKey _ ": a tool call failed inside the dispatcher", ex.AsStatus(), tUnavailable)
    }
    ; The common exit, reached by every branch above: one ledger row per answered call, carrying
    ; whatever the call got as far as (Story 4.9). tPairs and tArgumentPairs are undefined on a
    ; refusal that never reached them, which is what $Get guards; a row whose call was refused
    ; before its pairs were read records none, which is the truth about that call.
    Do ..RecordLedger(pKey, pUser, pRoute, pName, pTarget, $Get(tInput), $Get(tPairs), $Get(tArgumentPairs), $Get(tSecretNames), tIsError, pContent, pLimitsClass, $Get(tSecretDeclared))
    Quit tIsError
}

/// <p>Record one answered call in the agent ledger (Story 4.9). <var>pIsError</var> and
/// <var>pContent</var> are the answer <method>AnswerOne</method> is about to return, from which the
/// row's <code>status</code> and machine <code>code</code> are read the same way
/// <class>OcuPilot.Kernel.Agent.Loop</class> reads them off a result block.</p>
/// <p><b><code>Do</code>-and-log, never propagated</b> (AD-15): the ledger never fails a turn, and
/// the writer logs its own failure.</p>
/// <p><var>pClassified</var> is <method>AnswerOne</method>'s <code>$Get</code> of the registry's own
/// <code>pDeclared</code> output, undefined -- and so 0 -- on the branches where the wire name
/// resolved no tool. The ledger withholds such a row's arguments whole.</p>
ClassMethod RecordLedger(pKey As %String, pUser As %String, pRoute As %String, pName As %String, pTarget As %String, pInput As %DynamicAbstractObject, pPairs As %List, pArgumentPairs As %List, pSecretNames As %List, pIsError As %Boolean, pContent As %String, pLimitsClass As %String, pClassified As %Boolean = 0) [ Private ]
{
    Try {
        Set tCode = ""
        If pIsError {
            Try {
                Set tCode = ##class(%DynamicAbstractObject).%FromJSON(pContent).%Get("code")
            } Catch {
                Set tCode = ""
            }
        }
        Do $ClassMethod(..LedgerClass(), "RecordToolCall", pKey, pUser, pRoute, pName, pTarget, pInput, pPairs, pArgumentPairs, pSecretNames, $Select(pIsError: "error", 1: "ok"), tCode, pLimitsClass, pClassified)
    } Catch ex {
        Do ..LogFault("turn " _ pKey _ ": a tool call could not be recorded in the agent ledger", ex.AsStatus(), ##class(OcuPilot.Api.Error).#LEDGERUNAVAILABLE)
    }
}

/// <p>Resolve and validate a client-fulfilled tool call (Story 4.7, AD-11 rule 3) through the same
/// ordered chain <method>AnswerOne</method>'s header describes -- wire name, identity, gate, pairs
/// and arguments -- then call the resolved tool's own <code>Directive</code> in place of
/// <code>InvokeTool</code>. Never called for an <code>instance</code>-fulfilled tool.</p>
/// <p><var>pPending</var> is 1 only once every check has passed and <code>Directive</code> answered
/// a route to open, with <var>pRoute</var>/<var>pEntityId</var> the values it validated and
/// <var>pToolName</var> the canonical name the caller records the announce and tool steps under.
/// <var>pTarget</var>, <var>pArguments</var> and <var>pArgumentsTruncated</var> are set the same way
/// <method>AnswerOne</method> sets them (Story 4.5), whichever branch answers.</p>
/// <p>Otherwise <var>pPending</var> is 0 and <var>pIsError</var>/<var>pContent</var>/<var>pReason</var>
/// are the finished <code>tool_result</code> -- always <code>is_error</code> true, and always
/// answered before any announce step or directive exists (AC2): a refusal from a check before
/// <code>Directive</code> carries that check's own code, and a refusal from <code>Directive</code>
/// itself carries <code>NAV.ROUTEUNKNOWN</code> or <code>NAV.ENTITYNOTALLOWED</code>.
/// <var>pFailedPair</var> is set only by the two privilege-pair refusals.</p>
/// <p><var>pKey</var> is the turn the call belongs to, which every log line here names.
/// <var>pInput</var>, <var>pDeclaredPairs</var>, <var>pCallPairs</var> and <var>pSecretNames</var>
/// come back so the caller can record the call's ledger row at the point its outcome is known
/// (Story 4.9): a client-fulfilled call settles in <class>OcuPilot.Kernel.Agent.Loop</class>, not
/// here, so this method records nothing itself. Each is whatever the ordered chain above got as far
/// as reading. <var>pSecretDeclared</var> is 1 only when the resolved tool answered the
/// secret-argument question; it is 0 for a wire name that resolved no tool, and the ledger withholds
/// such a row's arguments whole rather than storing a blob the name pattern alone has seen.</p>
ClassMethod ResolveClientCall(pUser As %String, pBlock As %DynamicObject, pLimitsClass As %String, Output pPending As %Boolean, Output pToolName As %String, Output pRoute As %String, Output pEntityId As %String, Output pTarget As %String, Output pArguments As %String, Output pArgumentsTruncated As %Boolean, Output pIsError As %Boolean, Output pContent As %String, Output pReason As %String, Output pFailedPair As %String, pKey As %String = "", Output pInput As %DynamicAbstractObject, Output pDeclaredPairs As %List, Output pCallPairs As %List, Output pSecretNames As %List, Output pSecretDeclared As %Boolean) As %Status
{
    Set pInput = ""
    Set pDeclaredPairs = ""
    Set pCallPairs = ""
    Set pSecretNames = ""
    Set pSecretDeclared = 0
    Set tUnavailable = ##class(OcuPilot.Api.Error).#TOOLUNAVAILABLE
    Set pPending = 0
    Set pToolName = ""
    Set pRoute = ""
    Set pEntityId = ""
    Set pTarget = ""
    Set pArguments = ""
    Set pArgumentsTruncated = 0
    Set pIsError = 1
    Set pContent = ..ErrorContent(tUnavailable)
    Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(tUnavailable)
    Set pFailedPair = ""
    Set tSC = $$$OK
    Try {
        Set tWire = ""
        Set tInput = ""
        If $IsObject(pBlock) && pBlock.%IsA("%Library.DynamicObject") {
            Set tWire = pBlock.%Get("name")
            Set tInput = pBlock.%Get("input")
        }
        Set pToolName = tWire
        Set pInput = tInput
        Set pTarget = ..TargetOf(tInput)
        Set pArguments = ..RedactedArguments(tInput, +$Parameter(pLimitsClass, "SUMMARYMAXLENGTH"), .pArgumentsTruncated)
        Set tRegistry = ..RegistryClass()

        Set tSC = $ClassMethod(tRegistry, "ResolveWire", tWire, .tTool)
        If $$$ISERR(tSC) {
            Do ..LogFault("turn " _ pKey _ ": a client tool call could not resolve its registry", tSC, tUnavailable)
            Set tSC = $$$OK
            Quit
        }
        If '$IsObject(tTool) {
            Set pContent = ..ErrorContent(##class(OcuPilot.Api.Error).#TOOLUNKNOWN)
            Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(##class(OcuPilot.Api.Error).#TOOLUNKNOWN)
            Quit
        }
        Set pToolName = tTool.%Get("name")
        Set pSecretNames = $ClassMethod(tRegistry, "SecretArguments", tTool, .pSecretDeclared)
        ; Layer 1 over the argument summary, for the same reason AnswerOne re-derives it here.
        Set pArguments = ..StepArguments(tInput, pSecretNames, pLimitsClass, .pArgumentsTruncated)

        If $Username '= pUser {
            Do ..LogFault("turn " _ pKey _ ": a client tool call ran as a user other than the turn's", $$$ERROR($$$GeneralError, "the process user differs from the turn's user"), tUnavailable)
            Quit
        }

        Kill tDecision
        Set tSC = $ClassMethod(..GateClass(), "Decide", pToolName, tTool.%Get("kind"), pUser, tInput, .tDecision)
        If $$$ISERR(tSC) {
            Do ..LogFault("turn " _ pKey _ ": a client tool call's governance gate could not decide " _ pToolName, tSC, tUnavailable)
            Set tSC = $$$OK
            Quit
        }
        If '$Get(tDecision("allowed")) {
            Set tCode = $Get(tDecision("code"))
            Set tCode = $Select(tCode '= "": tCode, 1: ##class(OcuPilot.Api.Error).#TOOLDENIED)
            Set pContent = ..ErrorContent(tCode)
            Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(tCode)
            Quit
        }

        ; A client-fulfilled tool is never write-kind -- OcuPilot.Screen.Tool.Registry.FulfilmentProblem
        ; refuses that combination at build time -- so the restraint verdict never applies here
        ; (AC9's own KIND="read" note).

        Set tPairs = $ClassMethod(tRegistry, "RequiredPairs", tTool, .tResolved)
        Set pDeclaredPairs = tPairs
        If 'tResolved {
            Do ..LogFault("turn " _ pKey _ ": a client tool call's privilege pairs of " _ pToolName _ " could not be read", $$$ERROR($$$GeneralError, "unresolved pairs"), tUnavailable)
            Quit
        }
        Set tFailedPair = ..MissingPair(pUser, tPairs)
        If tFailedPair '= "" {
            Set pContent = ..DeniedContent(tFailedPair)
            Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE)
            Set pFailedPair = tFailedPair
            Quit
        }

        Set tSC = $ClassMethod(tRegistry, "ValidateArguments", $ClassMethod(tRegistry, "InputSchemaOf", tTool), tInput, .tProblem)
        If $$$ISERR(tSC) {
            Set tDetail = {}
            Do tDetail.%Set("problem", tProblem, "string")
            Set pContent = ..ErrorContent(##class(OcuPilot.Api.Error).#TOOLARGUMENTS, tDetail)
            Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(##class(OcuPilot.Api.Error).#TOOLARGUMENTS)
            ; An ordinary refusal, ready in pContent -- the dispatcher itself did not fail, so this
            ; method's own status must read OK or the caller (Loop.AnswerClientCall) would read an
            ; ordinary refusal as an internal failure and fail the whole turn.
            Set tSC = $$$OK
            Quit
        }

        Set tArgumentPairs = $ClassMethod(tRegistry, "ArgumentPairs", tTool, tInput, .tResolved)
        Set pCallPairs = tArgumentPairs
        If 'tResolved {
            Do ..LogFault("turn " _ pKey _ ": a client tool call's argument pairs of " _ pToolName _ " could not be read", $$$ERROR($$$GeneralError, "unresolved argument pairs"), tUnavailable)
            Quit
        }
        Set tFailedPair = ..MissingPair(pUser, tArgumentPairs)
        If tFailedPair '= "" {
            Set pContent = ..DeniedContent(tFailedPair)
            Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE)
            Set pFailedPair = tFailedPair
            Quit
        }

        Set tSC = $ClassMethod(tTool.%Get("class"), "Directive", tTool.%Get("descriptor"), tInput, .tDirectiveRoute, .tDirectiveEntityId, .tFault)
        If $$$ISERR(tSC) {
            If $IsObject(tFault) && (tFault.%Get("code") '= "") {
                Set pContent = ..ErrorContent(tFault.%Get("code"))
                Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(tFault.%Get("code"))
                ; Same reasoning as the ValidateArguments branch above: Directive's own refusal is
                ; an ordinary result, not a dispatcher failure.
                Set tSC = $$$OK
            } Else {
                Do ..LogFault("turn: " _ pToolName _ " failed inside Directive", tSC, tUnavailable)
                Set tSC = $$$OK
            }
            Quit
        }

        Set pRoute = tDirectiveRoute
        Set pEntityId = tDirectiveEntityId
        Set pPending = 1
        Set pIsError = 0
        Set pContent = ""
        Set pReason = ""
    } Catch ex {
        Set pPending = 0
        Set pIsError = 1
        Set pContent = ..ErrorContent(tUnavailable)
        Set pReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(tUnavailable)
        Do ..LogFault("turn " _ pKey _ ": a client tool call failed inside the dispatcher", ex.AsStatus(), tUnavailable)
    }
    Quit tSC
}

/// <p>The <code>tool_result</code> content for a client-fulfilled call that has been announced and
/// waited on (Story 4.7, AD-11 invariant 3, AD-39): <code>navigated</code> and <code>route</code>
/// always, plus <code>entityId</code> when the call named a row and <code>code</code> when it did
/// not navigate. <var>pOutcome</var> is <code>"opened"</code> (<code>navigated</code> true, no
/// <code>code</code>) or anything else -- <code>"refused"</code> or <code>"unavailable"</code>
/// (<code>navigated</code> false, <code>pCode</code> carried through).</p>
/// <p><b>An absent member is omitted, never emitted as JSON <code>null</code></b>: both are
/// outside <method>OcuPilot.Screen.Tool.Navigate.ResultSchema</method>'s <code>required</code> and
/// both are declared <code>"type": "string"</code>, so a null would be a value the declared type
/// does not admit. This shape is owned here so <class>OcuPilot.Kernel.Agent.Loop</class> never
/// composes a tool result of its own: whatever <var>pOutcome</var> is, the call is an ordinary
/// result, never an error (AD-11 invariant 3) -- the caller sets <code>is_error</code> false
/// unconditionally.</p>
ClassMethod SettleClient(pDetail As %DynamicObject, pOutcome As %String, pCode As %String, Output pContent As %String)
{
    Set tResult = {}
    Do tResult.%Set("navigated", (pOutcome = "opened"), "boolean")
    Do tResult.%Set("route", pDetail.%Get("route"), "string")
    Set tEntityId = pDetail.%Get("entityId")
    If tEntityId '= "" {
        Do tResult.%Set("entityId", tEntityId, "string")
    }
    If pOutcome '= "opened" {
        Do tResult.%Set("code", pCode, "string")
    }
    Set pContent = tResult.%ToJSON()
}

/// <p>A tool step's target (Story 4.5): <var>pInput</var>'s <code>id</code>, else
/// <code>entity</code>, else <code>route</code>, else <code>""</code> -- whichever is present
/// first and is a non-empty string. Public so <class>OcuPilot.Kernel.Agent.Loop</class> can
/// derive the same target for a step that never reached dispatch (the size-budget refusal, and a
/// stop that trips before the call).</p>
ClassMethod TargetOf(pInput As %DynamicObject) As %String
{
    Set tTarget = ""
    Try {
        If $IsObject(pInput) && pInput.%IsA("%Library.DynamicObject") {
            If (pInput.%GetTypeOf("id") = "string") && (pInput.%Get("id") '= "") {
                Set tTarget = pInput.%Get("id")
            } ElseIf (pInput.%GetTypeOf("entity") = "string") && (pInput.%Get("entity") '= "") {
                Set tTarget = pInput.%Get("entity")
            } ElseIf (pInput.%GetTypeOf("route") = "string") && (pInput.%Get("route") '= "") {
                Set tTarget = pInput.%Get("route")
            }
        }
    } Catch ex {
        Set tTarget = ""
    }
    Quit tTarget
}

/// <p>The argument string a <code>tool</code> step stores for <var>pInput</var>, cut at
/// <var>pLimitsClass</var>'s <code>SUMMARYMAXLENGTH</code>.</p>
/// <p><b>It runs the same two redaction layers, in the same order, that a ledger row's argument
/// string does</b> (AD-3): the tool's own <var>pSecretNames</var> declaration first, then
/// <method>OcuPilot.Kernel.Audit.Log.Redact</method>'s name pattern. It delegates to
/// <method>OcuPilot.Kernel.Audit.Ledger.RedactArguments</method> rather than repeating the layers,
/// so the step's string and the ledger row's are produced by one implementation and cannot come to
/// disagree about what a secret is -- and so the step does not store a wallet secret held in a
/// field called <code>Value</code> in clear, which the name pattern alone cannot see.</p>
/// <p>A caller that has no declaration to pass -- a call refused before its wire name resolved --
/// passes <code>""</code> and gets the name pattern alone, which is all an unclassifiable input
/// can be given.</p>
ClassMethod StepArguments(pInput As %DynamicAbstractObject, pSecretNames As %List, pLimitsClass As %String, Output pTruncated As %Boolean) As %String
{
    Quit ##class(OcuPilot.Kernel.Audit.Ledger).RedactArguments(pInput, pSecretNames, +$Parameter(pLimitsClass, "SUMMARYMAXLENGTH"), .pTruncated, .tRedactedNames)
}

/// <p><b>Layer 2 alone</b> (AD-3): compact JSON of <var>pInput</var>, every key matching
/// <method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method> redacted the same way that class
/// redacts a log entry, cut at <var>pMaxLength</var> characters with a trailing U+2026.
/// <var>pTruncated</var> answers whether that cut cut anything, so a caller that stores the result
/// does not have to re-cap it to learn. Public for the same reason <method>TargetOf</method>
/// is.</p>
/// <p><b>Not, on its own, the string a tool step stores.</b> The name pattern is a backstop and
/// cannot see a secret held in a field called <code>Value</code>, so a resolved call's step string
/// comes from <method>StepArguments</method>, which runs the declaration first. This method is
/// reached directly only where no declaration is knowable yet -- the default set before a call's
/// wire name has resolved -- and from
/// <method>OcuPilot.Kernel.Audit.Ledger.RedactArguments</method> as its second layer.</p>
ClassMethod RedactedArguments(pInput As %DynamicObject, pMaxLength As %Integer, Output pTruncated As %Boolean) As %String
{
    Set tOut = ""
    Set pTruncated = 0
    Try {
        If '$IsObject(pInput) Quit
        Set tJson = ##class(OcuPilot.Kernel.Audit.Log).Redact(pInput).%ToJSON()
        Set tOut = ##class(OcuPilot.Kernel.State.Turn).Cap(tJson, pMaxLength, .pTruncated)
        If pTruncated Set tOut = ##class(OcuPilot.Kernel.State.Turn).Cap(tJson, pMaxLength - 1, .pTruncated) _ $Char(8230)
    } Catch ex {
        Set tOut = ""
        Set pTruncated = 0
    }
    Quit tOut
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
/// <p>The tool half of the one privilege refusal (AD-39). The code and the detail are
/// <class>OcuPilot.Kernel.Denial</class>'s, which is also what
/// <class>OcuPilot.Api.ScreenRead</class>'s 403 renders, so the two cannot diverge.</p>
ClassMethod DeniedContent(pFailedPair As %String) As %String [ Private ]
{
    Quit ##class(OcuPilot.Kernel.Denial).Content(pFailedPair)
}

/// <p>The content of an error <code>tool_result</code>: <code>{code}</code>, plus
/// <code>detail</code> when <var>pDetail</var> is an object (AD-39).</p>
/// <p><b>A <code>detail.violations[]</code> member reaches the model as <code>{field, code}</code>
/// alone.</b> A validation envelope's violation carries <code>{field, code, reason}</code>, and the
/// <code>reason</code> is the screen's half: a tool result renders the machine half, so the written
/// sentence is projected out here rather than at each producer. Every other detail key travels
/// unchanged, and <var>pDetail</var> itself is never modified -- the ledger and the progress step
/// read the same object after this returns.</p>
ClassMethod ErrorContent(pCode As %String, pDetail As %DynamicObject = "") As %String
{
    Set tContent = {}
    Do tContent.%Set("code", pCode, "string")
    If $IsObject(pDetail) Do tContent.%Set("detail", ..ProjectedDetail(pDetail))
    Quit tContent.%ToJSON()
}

/// <p>A copy of <var>pDetail</var> whose <code>violations</code> array, when it has one, holds
/// <code>{field, code}</code> objects alone (AD-39, DW-450). A violation that is not an object is
/// dropped, since a tool result can carry no shape the model would have to interpret.</p>
ClassMethod ProjectedDetail(pDetail As %DynamicObject) As %DynamicObject [ Private ]
{
    Set tOut = pDetail
    Try {
        If pDetail.%GetTypeOf("violations") '= "array" Quit
        Set tOut = ##class(%DynamicAbstractObject).%FromJSON(pDetail.%ToJSON())
        Set tProjected = []
        Set tIterator = tOut.%Get("violations").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tViolation) {
            If '$IsObject(tViolation) || 'tViolation.%IsA("%Library.DynamicObject") Continue
            Set tRow = {}
            Do tRow.%Set("field", tViolation.%Get("field"), "string")
            Do tRow.%Set("code", tViolation.%Get("code"), "string")
            Do tProjected.%Push(tRow)
        }
        Do tOut.%Set("violations", tProjected)
    } Catch ex {
        ; Fail closed: a projection that threw must not hand the model the detail it was there to
        ; narrow, so the violations go out empty rather than whole.
        Set tOut = {"violations": []}
    }
    Quit tOut
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
