/// <p>The command and class-method console bodies (AD-10's run-code exception, AD-23, Story 24.6): the person's own command, or
/// the class method they name with their arguments, run in the request's own process in the namespace the port names, with
/// the person's rights. A harvested handler body, called only through <class>OcuPilot.Port.HarvestPort</class> by
/// <class>OcuPilot.Port.DevToolPort</class>, which has already checked the caller, the input and the class method, and which
/// rolls back any transaction the code leaves open.</p>
/// <p>The code's device output is the port's capture, which the harness hands to <method>OnCaptured</method>; it reaches the
/// screen alone, cut to the budget left after the return value and the by-reference values (AD-39's eighth exception). An
/// error the person's own code raises is the answer's <code>error</code>, never a fault. Neither body names a device, so the
/// capture the port made is the only one.</p>
Class OcuPilot.Port.Harvest.ConsoleRun Extends OcuPilot.Port.Harvest.Console
{

/// <p>Run the command <code>command</code> in <code>namespace</code>, which the body switches to by save and restore. The
/// answer is <code>{truncated, error, outputBudget}</code> until <method>OnCaptured</method> adds <code>output</code>:
/// <code>error</code> is the text of the error the command raised, or <code>""</code>.</p>
ClassMethod Command() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tFailed = 0
    Set tFailSC = $$$OK
    Set tError = ""
    Try {
        Set tCommand = $Get(%request.Data("command", 1))
        Set tNamespace = $Get(%request.Data("namespace", 1))
        If tNamespace '= "" {
            Set tSwitchSC = ..SwitchNamespace(tNamespace, .tOrigNS)
            If $$$ISERR(tSwitchSC) {
                Set tFailed = 1
                Set tFailSC = tSwitchSC
                Quit
            }
        }
        Set tError = ..Execute(tCommand)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tFailed = 1
        Set tFailSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If tFailed {
        Do ..RenderResponseBody(..SanitizeError(tFailSC))
        Quit tSC
    }
    Set tResult = {}
    Do tResult.%Set("truncated", 0, "boolean")
    Do tResult.%Set("error", tError, "string")
    Do tResult.%Set("outputBudget", ..#OUTPUTCEILING, "number")
    Do ..RenderResponseBody($$$OK, , tResult)
    Quit tSC
}

/// <p>Run <var>pCommand</var> in a frame of its own, so the command's variables are never the caller's. The harvest port's
/// request, response and session variables are made new for the run, so a command that kills or sets them changes only its own
/// copies. Answers the text of the error the command raised, or <code>""</code>.</p>
ClassMethod Execute(pCommand As %String) As %String [ Private ]
{
    Set tError = ""
    New %request, %response, %session
    Try {
        Xecute pCommand
    } Catch exCommand {
        Set tError = $System.Status.GetErrorText(exCommand.AsStatus())
    }
    Quit tError
}

/// <p>Call the class method <code>method</code> of <code>class</code> in <code>namespace</code> with the arguments
/// <code>args</code>, a JSON array's text (<method>InvokeWithArgs</method>). The answer is <code>{returnValue, argCount,
/// byRefValues, truncated, byRefTruncated, returnValueTruncated, error, outputBudget}</code> until
/// <method>OnCaptured</method> adds <code>output</code>; <code>error</code> is the text of the error the method or the
/// argument list raised, or <code>""</code>, and then <code>returnValue</code> is <code>""</code>.</p>
ClassMethod ClassMethod() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tFailed = 0
    Set tFailSC = $$$OK
    Try {
        Set tClass = $Get(%request.Data("class", 1))
        Set tMethod = $Get(%request.Data("method", 1))
        Set tArgsText = $Get(%request.Data("args", 1))
        Set tNamespace = $Get(%request.Data("namespace", 1))
        Set tArgs = ""
        If tArgsText '= "" Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(tArgsText)
        If tNamespace '= "" {
            Set tSwitchSC = ..SwitchNamespace(tNamespace, .tOrigNS)
            If $$$ISERR(tSwitchSC) {
                Set tFailed = 1
                Set tFailSC = tSwitchSC
                Quit
            }
        }
        Set tCallSC = ..Call(tClass, tMethod, tArgs, .tReturn, .tByRefValues, .tArgCount, .tTruncated, .tByRefTruncated, .tOutputBudget)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tFailed = 1
        Set tFailSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If tFailed {
        Do ..RenderResponseBody(..SanitizeError(tFailSC))
        Quit tSC
    }
    Set tReturnText = ""
    Set tReturnValueTruncated = 0
    Set tError = ""
    If $$$ISERR(tCallSC) {
        Set tError = $System.Status.GetErrorText(tCallSC)
    } Else {
        If $IsObject(tReturn) {
            Set tReturnText = "<Object:" _ $ClassName(tReturn) _ ">"
        } Else {
            Set tReturnText = tReturn
        }
        Set tReturnText = ..ApplyOutputCeiling(tReturnText, .tReturnValueTruncated)
    }
    Set tResult = {}
    Do tResult.%Set("returnValue", tReturnText, "string")
    Do tResult.%Set("argCount", +$Get(tArgCount), "number")
    Do tResult.%Set("byRefValues", $Select($IsObject($Get(tByRefValues)): tByRefValues, 1: {}))
    Do tResult.%Set("truncated", +$Get(tTruncated), "boolean")
    Do tResult.%Set("byRefTruncated", +$Get(tByRefTruncated), "boolean")
    Do tResult.%Set("returnValueTruncated", tReturnValueTruncated, "boolean")
    Do tResult.%Set("error", tError, "string")
    Do tResult.%Set("outputBudget", $Get(tOutputBudget, ..#OUTPUTCEILING), "number")
    Do ..RenderResponseBody($$$OK, , tResult)
    Quit tSC
}

/// <p>Call <method>InvokeWithArgs</method> with the harvest port's request, response and session variables made new, so a
/// method that kills or sets them changes only its own copies. The arguments and outputs are <method>InvokeWithArgs</method>'s.</p>
ClassMethod Call(pClass As %String, pMethod As %String, pArgs, Output pReturn, Output pByRefValues As %DynamicObject, Output pArgCount As %Integer, Output pTruncated As %Boolean, Output pByRefTruncated As %Boolean, Output pOutputBudget As %Integer) As %Status [ Private ]
{
    New %request, %response, %session
    Quit ..InvokeWithArgs(pClass, pMethod, pArgs, .pReturn, .pByRefValues, .pArgCount, .pTruncated, .pByRefTruncated, .pOutputBudget)
}

/// <p>Add the captured device output to the answer: <var>pLines</var> joined with line feeds, read up to one character past the
/// answer's <code>outputBudget</code>, cut to that budget (<method>ApplyOutputCeiling</method>), as <code>output</code>. The
/// cut is ORed into <code>truncated</code>, and the budget leaves the answer. The output is the person's own code's and
/// reaches the screen alone.</p>
ClassMethod OnCaptured(pLines As %DynamicArray, pResult As %DynamicObject) As %Status
{
    Set tBudget = pResult.%Get("outputBudget")
    If tBudget = "" Set tBudget = ..#OUTPUTCEILING
    Set tText = ""
    Set tIterator = pLines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        If tIndex > 0 Set tText = tText _ $Char(10)
        Set tText = tText _ $Extract(tLine, 1, tBudget + 1 - $Length(tText))
        If $Length(tText) > tBudget Quit
    }
    Set tTruncated = +pResult.%Get("truncated")
    Set tText = ..ApplyOutputCeiling(tText, .tTruncated, tBudget)
    Do pResult.%Set("output", tText, "string")
    Do pResult.%Set("truncated", tTruncated, "boolean")
    Do pResult.%Remove("outputBudget")
    Quit $$$OK
}

}
