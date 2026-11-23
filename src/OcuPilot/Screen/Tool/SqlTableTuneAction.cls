/// <p>The base of the statistics writes that take the tune's declared booleans (Story 21.25, AD-6, AD-10, AD-21, AD-51, AD-53, AD-56): the collection of a
/// table's statistics and of every table's in a schema, through <class>OcuPilot.Port.SqlPort</class>'s <code>Tables</code> endpoint. Each value named in
/// <parameter>VALUENAMES</parameter> is a required boolean argument, <code>true</code> or <code>false</code>, which reaches the port in its query
/// (<method>PortQuery</method>) and is part of the fingerprint's subject, so a confirm writes the values the person reviewed.</p>
/// <p>The fresh read answers each value as <code>null</code>, so the merge of the arguments makes a row on the card for each value and the stored payload
/// carries every one.</p>
Class OcuPilot.Screen.Tool.SqlTableTuneAction Extends OcuPilot.Screen.Tool.SqlTableAction [ Abstract ]
{

/// <p>The boolean arguments this tool admits, comma-separated, in the order the dialog draws them.</p>
Parameter VALUENAMES = "KeepClassUpToDate";

/// <p>The description the input schema gives each of the booleans, as <code>name=description</code> entries separated by <code>|</code>.</p>
Parameter VALUEDESCRIPTIONS = "KeepClassUpToDate=true passes the instance's Keep class up to date option, as the classic Tune Table window's box does; the class is not recompiled and is not marked out of date.|ClearValues=true also clears the fixed selectivity and extent size saved for each table, so the optimizer uses the collected ones.";

/// <p>The declared booleans as a list.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#VALUENAMES)
}

/// <p>The derived schema with each declared boolean added and required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Set tNames = ..SettableFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Set tProperty = {"type": "boolean"}
        Do tProperty.%Set("description", ..ValueDescription(tName), "string")
        Do tProperties.%Set(tName, tProperty)
        If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(tName)
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

/// <p>The namespace, then each declared boolean of the stored payload (or of the caller's arguments) <var>pPayload</var> under the port's own query keys,
/// <code>true</code> or <code>false</code>, so the confirm's write and the screen's action tune with the values the person reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    Set tNames = ..SettableFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        If pPayload.%GetTypeOf(tName) = "boolean" Set pQuery(tName) = $Select(pPayload.%Get(tName): "true", 1: "false")
    }
}

/// <p>The target refused as <method>IdProblem</method> refuses it, then each declared boolean that is not one, before anything is stored (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pIdValue, pArgs, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tNames = ..SettableFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        If '$IsObject(pArgs) || (pArgs.%GetTypeOf(tName) '= "boolean") {
            Set pProblem = "'" _ tName _ "' is true or false"
            Quit
        }
    }
    Quit $$$OK
}

/// <p>The target as <method>OcuPilot.Screen.Tool.SqlStatementAction.ScreenActionDelta</method> checks it, then the screen's values as this tool's
/// arguments, each <code>true</code> or <code>false</code> and any other spelling refused (AD-56 (ii)).</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pActionId, pValues, pFresh, .pArgs, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tNames = ..SettableFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Set tValue = ""
        If $IsObject(pValues) Set tValue = pValues.%Get(tName)
        If (tValue '= "true") && (tValue '= "false") {
            Set pProblem = "'" _ tName _ "' is true or false"
            Set pArgs = {}
            Quit
        }
        Do pArgs.%Set(tName, (tValue = "true"), "boolean")
    }
    Quit $$$OK
}

}
