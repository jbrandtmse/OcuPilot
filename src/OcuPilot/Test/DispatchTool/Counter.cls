/// <p>Fixture: the body of <class>OcuPilot.Test.DispatchTool.Reader</class> and
/// <class>OcuPilot.Test.DispatchTool.Writer</class>, which differ only in name and kind. Each call
/// to <method>View</method> is counted per tool, with the input and the cap it was given, so a test
/// observes whether the dispatcher reached the tool at all.</p>
/// <p>The view answers <code>{marker, rows, truncated}</code>: <code>rows</code> is the input's
/// <code>rows</code> objects, each carrying a <code>text</code> of <code>width</code> characters.
/// Input <code>blob</code> answers <code>{text}</code> of that many characters, plus the
/// <code>rows</code> when <code>rows</code> is also given. Input <code>throw</code> 1 makes the view
/// throw, and <code>empty</code> 1 makes it answer success with no result. An armed fault
/// (<method>ArmFault</method>) answers an error with that fault instead. Its pairs are two probe
/// pairs, or unresolved once <method>ArmUnresolvedPairs</method> is called; input <code>scope</code>
/// adds the pair <code>OcuPilotProbeScope&lt;scope&gt;:WRITE</code>, unresolved once
/// <method>ArmUnresolvedArgumentPairs</method> is called.</p>
/// <p>State lives in <code>^||OcuPilotDispatchTool</code>; <method>Clear</method> forgets it.</p>
Class OcuPilot.Test.DispatchTool.Counter Extends OcuPilot.Screen.Tool.Base [ Abstract ]
{

/// <p>The two pairs every counter tool declares, <code>resource:permission</code>, comma-separated.</p>
Parameter PAIRS = "OcuPilotProbeResourceA:USE,OcuPilotProbeResourceB:READ";

ClassMethod Clear()
{
    Kill ^||OcuPilotDispatchTool
}

/// <p>How many times <var>pTool</var>'s view ran since the last <method>Clear</method>.</p>
ClassMethod Calls(pTool As %String) As %Integer
{
    Quit +$Get(^||OcuPilotDispatchTool("calls", pTool))
}

/// <p>What <var>pTool</var>'s last view was given: <code>input</code> as JSON, or <code>cap</code>.</p>
ClassMethod Last(pTool As %String, pField As %String) As %String
{
    Quit $Get(^||OcuPilotDispatchTool("last", pTool, pField))
}

/// <p>Answer every view with an error carrying <var>pHttpStatus</var> and the fault
/// <code>{error, reason, code}</code>, plus <var>pDetailJson</var> as <code>detail</code> when it is
/// not empty.</p>
ClassMethod ArmFault(pHttpStatus As %Integer, pCode As %String, pDetailJson As %String = "")
{
    Set ^||OcuPilotDispatchTool("fault") = $ListBuild(pHttpStatus, pCode, pDetailJson)
}

/// <p>Answer every tool's pairs as unresolved.</p>
ClassMethod ArmUnresolvedPairs()
{
    Set ^||OcuPilotDispatchTool("unresolved") = 1
}

/// <p>Answer every call's argument pairs as unresolved.</p>
ClassMethod ArmUnresolvedArgumentPairs()
{
    Set ^||OcuPilotDispatchTool("unresolvedArguments") = 1
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "marker": {"type": "string", "maxLength": 64, "description": "Echoed in the result."},
            "scope": {"type": "string", "maxLength": 32, "description": "A scope whose probe pair the call also requires."},
            "rows": {"type": "integer", "minimum": 0, "maximum": 5000, "description": "Rows to answer."},
            "width": {"type": "integer", "minimum": 0, "maximum": 100000, "description": "Characters per row."},
            "blob": {"type": "integer", "minimum": 0, "maximum": 1000000, "description": "Characters of the result's text."},
            "throw": {"type": "integer", "minimum": 0, "maximum": 1, "description": "1 makes the view throw."},
            "empty": {"type": "integer", "minimum": 0, "maximum": 1, "description": "1 makes the view answer no result."}
        },
        "required": [],
        "additionalProperties": false
    }
}

/// <p>Declared: none (AD-3). Fixture.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p>Includes <code>rowsSent</code>, <code>rowsAvailable</code> and <code>truncatedFields</code>:
/// a rows-shaped result is dispatched through <class>OcuPilot.Kernel.Agent.Bound</class>, which adds
/// them (AD-24), so the schema admits what a caller actually receives.</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "marker": {"type": "string"},
            "rows": {"type": "array", "items": {"type": "object"}},
            "truncated": {"type": "boolean"},
            "text": {"type": "string"},
            "rowsSent": {"type": "integer"},
            "rowsAvailable": {"type": "integer"},
            "truncatedFields": {"type": "array", "items": {"type": "string"}}
        },
        "required": [],
        "additionalProperties": false
    }
}

ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    If $Get(^||OcuPilotDispatchTool("unresolved")) {
        Set pResolved = 0
        Quit ""
    }
    Set pResolved = 1
    Set tPairs = ""
    For tI = 1:1:$Length(..#PAIRS, ",") {
        Set tPair = $Piece(..#PAIRS, ",", tI)
        Set tPairs = tPairs _ $ListBuild($ListBuild($Piece(tPair, ":", 1), $Piece(tPair, ":", 2)))
    }
    Quit tPairs
}

ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    If $Get(^||OcuPilotDispatchTool("unresolvedArguments")) {
        Set pResolved = 0
        Quit ""
    }
    Set pResolved = 1
    If pArgs.%Get("scope") = "" Quit ""
    Quit $ListBuild($ListBuild("OcuPilotProbeScope" _ pArgs.%Get("scope"), "WRITE"))
}

ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tTool = ..#TOOLNAME
    Set ^||OcuPilotDispatchTool("calls", tTool) = $Get(^||OcuPilotDispatchTool("calls", tTool)) + 1
    Set ^||OcuPilotDispatchTool("last", tTool, "input") = $Select($IsObject(pArgs): pArgs.%ToJSON(), 1: pArgs)
    Set ^||OcuPilotDispatchTool("last", tTool, "cap") = pContextCap
    Set tFault = $Get(^||OcuPilotDispatchTool("fault"))
    If tFault '= "" {
        Set pHttpStatus = $List(tFault, 1)
        Set pFault = {"error": "not_found", "reason": "The probe fault's own sentence, which must not reach the model."}
        Do pFault.%Set("code", $List(tFault, 2), "string")
        If $List(tFault, 3) '= "" Do pFault.%Set("detail", ##class(%DynamicAbstractObject).%FromJSON($List(tFault, 3)))
        Quit $$$ERROR($$$GeneralError, "the probe fault")
    }
    If +pArgs.%Get("throw") Throw ##class(%Exception.General).%New("the probe view threw")
    If +pArgs.%Get("empty") {
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Set tRows = []
    Set tText = $Translate($Justify("", +pArgs.%Get("width")), " ", "r")
    For tI = 1:1:+pArgs.%Get("rows") {
        Set tRow = {}
        Do tRow.%Set("n", tI, "number")
        Do tRow.%Set("text", tText, "string")
        Do tRows.%Push(tRow)
    }
    If +pArgs.%Get("blob") > 0 {
        Set pResult = {}
        Do pResult.%Set("text", $Translate($Justify("", +pArgs.%Get("blob")), " ", "b"), "string")
        If tRows.%Size() > 0 Do pResult.%Set("rows", tRows)
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Set pResult = {}
    Do pResult.%Set("marker", pArgs.%Get("marker"), "string")
    Do pResult.%Set("rows", tRows)
    Do pResult.%Set("truncated", 0, "boolean")
    Set pHttpStatus = 200
    Quit $$$OK
}

}
