/// <p>The agent's locale validation (Story 21.14, AD-36, AD-39, AD-60): whether one locale of this instance is valid, read as the vendor's
/// <code>IsValid</code> answers it. It is a read tool with a class of its own, bound to Locale definitions
/// (<class>OcuPilot.Screen.Descriptor.LocaleList</class>): it has no proposal. Its lines are vendor-written and reach no consumer (AD-39):
/// this tool answers the verdict and the <b>counts</b> of the errors and the warnings, never a line.</p>
/// <p><b>It reads through the same entry point the screen's route reads through</b>: <method>OcuPilot.Port.LocalePort.Invoke</method> on its
/// <code>Validation</code> endpoint, behind the port's own gate (AD-29). The result is built here from the verdicts and the counts alone, so a
/// field the port later adds never reaches the model.</p>
Class OcuPilot.Screen.Tool.LocaleValidate Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "osmgmt.locales.validate";

Parameter KIND = "read";

Parameter DESCRIPTION = "Validate one locale of this instance, named exactly as the Locale definitions list reports it, and read whether the instance finds its definition valid, with how many errors and warnings it found. The text of the errors and warnings is not shown, here or on the screen. A name the list does not report is refused.";

/// <p>The screen this tool reads for, whose pairs are this tool's.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocaleList";

/// <p>The port this tool reads through. Overridable so a fixture can observe the read; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.LocalePort"
}

/// <p>The one argument: the locale's name, as the instance lists it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "name": {"type": "string", "description": "The locale to validate, named exactly as the Locale definitions list reports it in its Name column. A locale the list does not report is refused."}
        },
        "required": ["name"],
        "additionalProperties": false
    }
}

/// <p>The Locale definitions screen's own pairs and nothing beyond them (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
}

/// <p>Declared: none (AD-3). The argument is a locale's name.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p>The result: <code>{Name, Valid, ErrorCount, WarningCount}</code>, the last two whole numbers.</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "Name": {"type": "string", "description": "The locale validated."},
            "Valid": {"type": "boolean", "description": "True when the instance finds the locale's definition valid."},
            "ErrorCount": {"type": "integer", "description": "How many errors the instance found. Their text is not shown."},
            "WarningCount": {"type": "integer", "description": "How many warnings the instance found. Their text is not shown."}
        },
        "required": ["Name", "Valid", "ErrorCount", "WarningCount"],
        "additionalProperties": false
    }
}

/// <p>The tool's view of one locale's validation. <var>pArgs</var> is validated against <method>InputSchema</method> before anything is
/// read; a refusal is 400 <code>TOOL.ARGUMENTS</code> and no port is called. A port refusal is returned as the port's own status, HTTP status
/// and fault, with <var>pResult</var> empty. <var>pContextCap</var> and <var>pDescriptor</var> are ignored: the result is one object.</p>
ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tArgs = $Select($IsObject(pArgs): pArgs, pArgs = "": {}, 1: pArgs)
        Set tValidSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(..InputSchema(), tArgs, .tProblem)
        If $$$ISERR(tValidSC) {
            Set tSC = ..ArgumentsRefusal(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tPort = ..PortClass()
        Kill tQuery
        Set tQuery($Parameter(tPort, "NAMEKEY")) = tArgs.%Get("name")
        Set tSC = $ClassMethod(tPort, "Invoke", $Parameter(tPort, "VALIDATIONENDPOINT"), $Parameter(tPort, "TYPEGET"), .tQuery, "", .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tAnswer) || 'tAnswer.%IsA("%Library.DynamicObject") {
            Set tSC = ..InternalRefusal("the locale validation answered no payload", .pHttpStatus, .pFault)
            Quit
        }
        Set pResult = {}
        Do pResult.%Set("Name", tAnswer.%Get("Name"), "string")
        Do pResult.%Set("Valid", ''tAnswer.%Get("Valid"), "boolean")
        Do pResult.%Set("ErrorCount", +tAnswer.%Get("ErrorCount"), "number")
        Do pResult.%Set("WarningCount", +tAnswer.%Get("WarningCount"), "number")
        Set pHttpStatus = 200
        Set pFault = ""
    } Catch ex {
        Set pResult = ""
        Set tSC = ..InternalRefusal("the locale validation read tool failed: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

}
