/// <p>The base of the statistics writes that take declared values (Story 21.25, AD-6, AD-10, AD-21, AD-51, AD-53, AD-56): the collection of every
/// table's statistics in a schema, through <class>OcuPilot.Port.SqlPort</class>'s <code>Tables</code> endpoint. Each value named in
/// <parameter>VALUENAMES</parameter> is a declared argument of the kind <method>ValueType</method> names, a boolean here, <code>true</code> or
/// <code>false</code>, which reaches the port in its query (<method>PortQuery</method>) and is part of the fingerprint's subject, so a confirm writes
/// the values the person reviewed. Each is required unless <parameter>REQUIREDVALUES</parameter> names the required ones.</p>
/// <p>The fresh read answers each value as <code>null</code>, so the merge of the arguments makes a row on the card for each value and the stored payload
/// carries every one.</p>
Class OcuPilot.Screen.Tool.SqlTableTuneAction Extends OcuPilot.Screen.Tool.SqlTableAction [ Abstract ]
{

/// <p>The arguments this tool admits, comma-separated, in the order the dialog draws them.</p>
Parameter VALUENAMES = "ClearValues";

/// <p>The names among <parameter>VALUENAMES</parameter> an argument must carry, comma-separated, or <code>""</code>: every one. A name left out of a
/// non-empty list is optional, and an omitted one is not sent.</p>
Parameter REQUIREDVALUES;

/// <p>The description the input schema gives each of the arguments, as <code>name=description</code> entries separated by <code>|</code>.</p>
Parameter VALUEDESCRIPTIONS = "ClearValues=true also clears the fixed selectivity and extent size saved for each table, so the optimizer uses the collected ones.";

/// <p>The declared arguments as a list.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#VALUENAMES)
}

/// <p>The declared arguments an argument set must carry, as a list: <parameter>REQUIREDVALUES</parameter>, or every declared one.</p>
ClassMethod RequiredFields() As %List
{
    If ..#REQUIREDVALUES = "" Quit ..SettableFields()
    Quit $ListFromString(..#REQUIREDVALUES)
}

/// <p>The kind of declared argument <var>pName</var>: <code>boolean</code> here, <code>true</code> or <code>false</code>. A tool that takes another
/// kind answers <code>integer</code> (a number) or <code>string</code>, and judges each value in <method>ValueProblem</method>.</p>
ClassMethod ValueType(pName As %String) As %String
{
    Quit "boolean"
}

/// <p>Why <var>pValue</var>, the text of declared argument <var>pName</var>, is not a value this tool sends, as a sentence, or <code>""</code>. A
/// boolean is judged by its type, so none here; a tool that takes another kind judges its shape here, as the port does.</p>
ClassMethod ValueProblem(pName As %String, pValue As %String) As %String
{
    Quit ""
}

/// <p>The text of the stored value <var>pValue</var> of declared argument <var>pName</var>, of the JSON type <var>pType</var>, as it travels in the
/// port's query: <code>true</code> or <code>false</code> for a boolean, the value's own text otherwise.</p>
ClassMethod QueryValue(pName As %String, pValue As %String, pType As %String) As %String
{
    If pType = "boolean" Quit $Select(pValue: "true", 1: "false")
    Quit pValue
}

/// <p>The derived schema with each declared argument added, of its kind, and each required one required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Set tNames = ..SettableFields()
    Set tRequired = ..RequiredFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Set tProperty = {}
        Do tProperty.%Set("type", ..ValueType(tName), "string")
        Do tProperty.%Set("description", ..ValueDescription(tName), "string")
        Do tProperties.%Set(tName, tProperty)
        If $ListFind(tRequired, tName) && (tSchema.%GetTypeOf("required") = "array") Do tSchema.%Get("required").%Push(tName)
    }
    Quit tSchema
}

/// <p>The description <parameter>VALUEDESCRIPTIONS</parameter> gives <var>pName</var>, or <code>""</code>.</p>
ClassMethod ValueDescription(pName As %String) As %String
{
    For tI = 1:1:$Length(..#VALUEDESCRIPTIONS, "|") {
        Set tEntry = $Piece(..#VALUEDESCRIPTIONS, "|", tI)
        If $Piece(tEntry, "=", 1) = pName Quit
    }
    If $Piece(tEntry, "=", 1) '= pName Quit ""
    Quit $Piece(tEntry, "=", 2, *)
}

/// <p>The namespace, then each declared argument of the stored payload (or of the caller's arguments) <var>pPayload</var> under the port's own query
/// keys, as <method>QueryValue</method> renders it, so the confirm's write and the screen's action tune with the values the person reviewed (AD-52).
/// A value of the wrong kind, or one the payload does not hold, is not sent.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    Set tNames = ..SettableFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Set tType = pPayload.%GetTypeOf(tName)
        If tType = ..JsonTypeOf(..ValueType(tName)) Set pQuery(tName) = ..QueryValue(tName, pPayload.%Get(tName), tType)
    }
}

/// <p>The JSON type a declared argument of kind <var>pKind</var> is stored as: <code>boolean</code>, <code>number</code> or <code>string</code>.</p>
ClassMethod JsonTypeOf(pKind As %String) As %String
{
    Quit $Case(pKind, "integer": "number", : pKind)
}

/// <p>The target refused as <method>IdProblem</method> refuses it, then each required declared argument that is not of its kind, and each other one
/// that is present and not (<method>ValueProblem</method>), before anything is stored (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pIdValue, pArgs, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tNames = ..SettableFields()
    Set tRequired = ..RequiredFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Set tType = $Select($IsObject(pArgs): pArgs.%GetTypeOf(tName), 1: "unassigned")
        If '$ListFind(tRequired, tName) && (tType = "unassigned") Continue
        If ..ValueType(tName) = "boolean" {
            If tType '= "boolean" {
                Set pProblem = "'" _ tName _ "' is true or false"
                Quit
            }
            Continue
        }
        Set tText = $Select(tType = ..JsonTypeOf(..ValueType(tName)): pArgs.%Get(tName), 1: "")
        Set pProblem = ..ValueProblem(tName, tText)
        If pProblem '= "" Quit
    }
    Quit $$$OK
}

/// <p>The target as <method>OcuPilot.Screen.Tool.SqlStatementAction.ScreenActionDelta</method> checks it, then the screen's values as this tool's
/// arguments, each of its kind and any other spelling refused (AD-56 (ii)): a boolean is <code>true</code> or <code>false</code>, and another kind is
/// judged by <method>ValueProblem</method>. An optional value the screen does not send is left out.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pActionId, pValues, pFresh, .pArgs, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tNames = ..SettableFields()
    Set tRequired = ..RequiredFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Set tValue = ""
        If $IsObject(pValues) Set tValue = pValues.%Get(tName)
        If '$ListFind(tRequired, tName) && (tValue = "") Continue
        If ..ValueType(tName) = "boolean" {
            If (tValue '= "true") && (tValue '= "false") {
                Set pProblem = "'" _ tName _ "' is true or false"
                Set pArgs = {}
                Quit
            }
            Do pArgs.%Set(tName, (tValue = "true"), "boolean")
            Continue
        }
        Set pProblem = ..ValueProblem(tName, tValue)
        If pProblem '= "" {
            Set pArgs = {}
            Quit
        }
        If ..ValueType(tName) = "integer" {
            Do pArgs.%Set(tName, +tValue, "number")
        } Else {
            Do pArgs.%Set(tName, tValue, "string")
        }
    }
    Quit $$$OK
}

}
