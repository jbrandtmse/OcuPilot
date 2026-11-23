/// <p>The base of the fixed-statistics setters (Story 21.31, AD-6, AD-10, AD-21, AD-51, AD-53, AD-56): the extent size of a table, the selectivity of a
/// field and the size of a map, each through <class>OcuPilot.Port.SqlPort</class>'s <code>Tables</code> endpoint. Its declared values are numbers and
/// text, not booleans (<method>OcuPilot.Screen.Tool.SqlTableTuneAction.ValueType</method>): <code>ExtentSize</code>, <code>SizeMB</code> and
/// <code>AverageFieldSize</code> are whole numbers, and <code>Selectivity</code>, <code>OutlierSelectivity</code> and <code>OutlierValue</code> are
/// text. Each is judged by the port's own shape check (<method>OcuPilot.Port.SqlPort.ValueProblem</method>) before anything is stored, so the agent's mint
/// and the screen's action refuse what the port would, with the same published sentence.</p>
/// <p>The fresh read of each setter answers the value it sets, so the merge of the declared value over it shows the old and the new value on the card.</p>
/// <p>A setter of a field or a map names its target as the composite <code>[Table, &lt;SECONDARGUMENT&gt;]</code>
/// (<class>OcuPilot.Screen.Tool.MappingMint</class>'s id); one of a table names it as <code>Schema.Table</code>.</p>
Class OcuPilot.Screen.Tool.SqlTableSetAction Extends OcuPilot.Screen.Tool.SqlTableTuneAction [ Abstract ]
{

/// <p>The argument naming the field or the map a setter of one acts on, or <code>""</code> for a setter of a table.</p>
Parameter SECONDARGUMENT;

/// <p>The description the input schema gives <parameter>SECONDARGUMENT</parameter>.</p>
Parameter SECONDDESCRIPTION;

/// <p>A whole number, as the extent size, the map's size in MB and a field's average size are; any other declared value is text.</p>
ClassMethod ValueType(pName As %String) As %String
{
    Quit $Select($ListFind($ListBuild("ExtentSize", "SizeMB", "AverageFieldSize"), pName): "integer", 1: "string")
}

/// <p>The port's published sentence for <var>pValue</var> as <var>pName</var>, or <code>""</code>. An outlier value the instance would run as code,
/// because it is not a number or double-quoted text, is refused here with a sentence for the agent that names the shape.</p>
ClassMethod ValueProblem(pName As %String, pValue As %String) As %String
{
    Set tPort = "OcuPilot.Port.SqlPort"
    If (pName = $Parameter(tPort, "OUTLIERVALUEKEY")) && ($Length(pValue) <= $Parameter(tPort, "MAXOUTLIERVALUE")) && '$ClassMethod(tPort, "OutlierLiteral", pValue) {
        Quit "'" _ pName _ "' is a number, or text in double quotes"
    }
    Quit $ClassMethod(tPort, "ValueProblem", pName, pValue)
}

/// <p>The merge of the arguments over the fresh read, with each optional value the caller did not send made <code>null</code>: the fresh read answers
/// every value in use, and the payload's values of a declared kind reach the port as the declared ones, so one left in would be sent as though the caller
/// had declared it. The port then reads the field's own value for each one it is not sent.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || '$IsObject($Get(pPayload)) Quit tSC
    Set tNames = ..SettableFields()
    Set tRequired = ..RequiredFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        If '$ListFind(tRequired, tName) && ('$IsObject(pArgs) || (pArgs.%GetTypeOf(tName) = "unassigned")) Do pPayload.%Set(tName, "", "null")
    }
    Quit tSC
}

/// <p>The identifying argument: the field's or map's name for a setter of one, else the table.</p>
ClassMethod IdArgument() As %String
{
    Quit $Select(..#SECONDARGUMENT = "": "Table", 1: ..#SECONDARGUMENT)
}

/// <p>The field's or map's name, which the card titles a setter of one by: the fresh read's, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If ..#SECONDARGUMENT = "" Quit ##super(pFresh, pId, pArgs)
    If $IsObject(pFresh) && (pFresh.%GetTypeOf(..#SECONDARGUMENT) = "string") Quit pFresh.%Get(..#SECONDARGUMENT)
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#SECONDARGUMENT) = "string") Quit pArgs.%Get(..#SECONDARGUMENT)
    Quit ""
}

/// <p>The composite id's table, which the kernel's own-name refusal judges.</p>
ClassMethod NameOf(pIdValue As %String) As %String
{
    If ..#SECONDARGUMENT = "" Quit pIdValue
    Quit $ListGet(##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue), 1)
}

/// <p>The derived schema with each declared value added and, for a setter of a field or a map, the table added and required and its name described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If ..#SECONDARGUMENT = "" Quit tSchema
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set("Table", {"type": "string", "description": "The table the target belongs to, as Schema.Table, as this namespace's SQL tables list reports it in its Table column."})
    If tProperties.%GetTypeOf(..#SECONDARGUMENT) = "object" Do tProperties.%Get(..#SECONDARGUMENT).%Set("description", ..#SECONDDESCRIPTION, "string")
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push("Table")
    Quit tSchema
}

/// <p>Why <var>pId</var> is not a target this tool acts on, or <code>""</code>: for a field or a map, the composite <code>[Table, SECONDARGUMENT]</code>, the
/// table shaped as a table name (<method>OcuPilot.Screen.Tool.SqlTableAction.TableShaped</method>) and the second part a non-empty name within the name bound
/// (<parameter>OcuPilot.Port.SqlPort.MAXNAME</parameter>) holding no control character; for a table, <method>OcuPilot.Screen.Tool.SqlTableAction.IdProblem</method>'s.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    If ..#SECONDARGUMENT = "" Quit ##super(pId)
    If '$IsObject(pId) {
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pId)
        Set tSecond = $ListGet(tParts, 2)
        If ($ListLength(tParts) = 2) && ..TableShaped($List(tParts, 1)) && (tSecond '= "") && ($Length(tSecond) <= ##class(OcuPilot.Port.SqlPort).#MAXNAME) && ($ZStrip(tSecond, "*C") = tSecond) Quit ""
    }
    Quit "'Table' names one table as Schema.Table and '" _ ..IdArgument() _ "' one of its " _ ..#SECONDARGUMENT _ "s, as the table's tabs report them"
}

}
