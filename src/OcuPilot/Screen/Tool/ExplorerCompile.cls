/// <p>System Explorer's compile of a set of documents (AD-6, AD-51, AD-53, Story 19.2): what the
/// Classes and Routines lists' compile tools share. The screen's caller sends one document per
/// request, so its output pane follows the sequence; the agent's confirm compiles its whole set in
/// one call.</p>
/// <p><b>The compiler flags are always <code>c</code> plus three declared booleans</b>
/// (<method>OcuPilot.Port.AtelierPort.CompileFlags</method>): <code>KeepSource</code>
/// (<code>k</code>), <code>CompileDependents</code> (<code>b</code>) and <code>SkipUpToDate</code>
/// (<code>u</code>). No caller names a flag, and nothing else reaches the compiler.</p>
/// <p>The fingerprint subject is the set held and missing, the namespace and the three values, so a
/// document that comes or goes refuses the confirm while an edit to one does not. A compile is not
/// destructive, and its console lines are its result, errors included (<method>WriteOutput</method>).
/// It performs the classic Compile dialog's operation, whose custom resource it also requires
/// (AD-44).</p>
Class OcuPilot.Screen.Tool.ExplorerCompile Extends OcuPilot.Screen.Tool.ExplorerWrite [ Abstract ]
{

/// <p>The list's compile, whose three values are the declared booleans.</p>
Parameter SCREENACTIONS = "compile";

Parameter SCREENVALUES = "compile=KeepSource:CompileDependents:SkipUpToDate";

Parameter WRITETYPE = "COMPILE";

Parameter DESTRUCTIVE As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>A compile acts on the documents present; a set none of whose documents the read answered is
/// not one to compile.</p>
Parameter PRECONDITIONFIELD = "Present";

Parameter FINGERPRINTSUBJECT = "Present,Absent,Namespace,KeepSource,CompileDependents,SkipUpToDate";

/// <p>The classic dialog whose operation this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.Compile";

/// <p>The three declared values, in the order the dialog draws them.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.AtelierPort).#KEEPSOURCEKEY, ##class(OcuPilot.Port.AtelierPort).#COMPILEDEPENDENTSKEY, ##class(OcuPilot.Port.AtelierPort).#SKIPUPTODATEKEY)
}

/// <p>The derived schema with the three values added, each a required boolean.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(##class(OcuPilot.Port.AtelierPort).#KEEPSOURCEKEY, {"type": "boolean", "description": "true keeps the generated intermediate source after the compile, as the classic Compile dialog's Keep generated source code does."})
    Do tProperties.%Set(##class(OcuPilot.Port.AtelierPort).#COMPILEDEPENDENTSKEY, {"type": "boolean", "description": "true also compiles every class that depends on these, which takes longer."})
    Do tProperties.%Set(##class(OcuPilot.Port.AtelierPort).#SKIPUPTODATEKEY, {"type": "boolean", "description": "true skips a document that is already compiled and unchanged."})
    For tField = ##class(OcuPilot.Port.AtelierPort).#KEEPSOURCEKEY, ##class(OcuPilot.Port.AtelierPort).#COMPILEDEPENDENTSKEY, ##class(OcuPilot.Port.AtelierPort).#SKIPUPTODATEKEY {
        Do tSchema.%Get("required").%Push(tField)
    }
    Quit tSchema
}

/// <p>The screen's three values as this tool's arguments, each <code>true</code> or
/// <code>false</code>, and any other spelling refused (AD-56 (ii)).</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    For tField = ##class(OcuPilot.Port.AtelierPort).#KEEPSOURCEKEY, ##class(OcuPilot.Port.AtelierPort).#COMPILEDEPENDENTSKEY, ##class(OcuPilot.Port.AtelierPort).#SKIPUPTODATEKEY {
        Set tValue = ""
        If $IsObject(pValues) Set tValue = pValues.%Get(tField)
        If (tValue '= "true") && (tValue '= "false") {
            Set pProblem = "'" _ tField _ "' is true or false"
            Quit
        }
        Do pArgs.%Set(tField, (tValue = "true"), "boolean")
    }
    If pProblem '= "" Set pArgs = {}
    Quit $$$OK
}

/// <p>The namespace, then the three values of the stored payload <var>pPayload</var> under the
/// port's own query keys, each <code>1</code> or <code>0</code>, so the confirm's write and the
/// screen's compile with the values the user reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    For tField = ##class(OcuPilot.Port.AtelierPort).#KEEPSOURCEKEY, ##class(OcuPilot.Port.AtelierPort).#COMPILEDEPENDENTSKEY, ##class(OcuPilot.Port.AtelierPort).#SKIPUPTODATEKEY {
        If pPayload.%GetTypeOf(tField) = "boolean" Set pQuery(tField) = $Select(pPayload.%Get(tField): 1, 1: 0)
    }
}

/// <p>The one state row this proposal's card shows beside the three values' rows:
/// <code>Documents</code>, whose after-value names the documents the fresh read <var>pFresh</var>
/// holds. A set it holds none of is the port's to refuse.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tRow = {}
    Do tRow.%Set("field", ..#STATEFIELD, "string")
    Do tRow.%Set("before", "", "string")
    Do tRow.%Set("after", ..NamesShown(pFresh, "Present"), "string")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

}
