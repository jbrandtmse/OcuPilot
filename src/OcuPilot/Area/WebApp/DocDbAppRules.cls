/// <p>The Doc DB applications' rules (AD-39, AD-55, Story 18.30): the one rule set
/// <class>OcuPilot.Screen.Tool.DocDbAppCreate</class> and <class>OcuPilot.Screen.Tool.DocDbAppUpdate</class> apply at
/// the mint and the confirm and <class>OcuPilot.Area.WebApp.DocDbAppSave</class> applies at the Save, every condition
/// before any <code>PUT</code> (<method>Check</method>, <method>Problem</method>), and the editor's form read
/// (<method>HandleForm</method>).</p>
/// <p><b>The rules are OcuPilot's own.</b> The vendor stores a record for an absent namespace or resource, and an
/// invalid class name fails as a logged 500 (measured at Story 18.30's plan), so every condition is decided here.
/// Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s, from
/// <class>OcuPilot.Api.DocDbAppError</class>.</p>
/// <p><b>A create judges the name and the namespace and every field it sends.</b> The three settings are optional
/// on a create: an omitted one takes the instance's default. An update judges only the fields it changes, so a stored
/// value is never refused for being as it is.</p>
Class OcuPilot.Area.WebApp.DocDbAppRules Extends %RegisteredObject
{

/// <p>The screen whose declared pairs gate the form read (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DocDbAppForm";

/// <p>The tool whose port and endpoint the form read asks (AD-52).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.DocDbAppUpdate";

/// <p>The three settings a record carries, in the order they are judged.</p>
Parameter FIELDS = "Description,Enabled,Resource";

/// <p>The resource endpoint, the member of its rows that names a resource's kind, and the kinds a record may
/// name.</p>
Parameter RESOURCEENDPOINT = "Security.Resource";

Parameter RESOURCETYPEFIELD = "ResourceType";

Parameter RESOURCETYPES = "Service,Application";

/// <p>Every rule over <var>pBody</var>, in <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field,
/// code)</code> with the count in <code>pViolations</code>.</p>
/// <p>A value that is not text where text is meant is a shape violation on its field. When <var>pMode</var> is
/// <code>create</code>, <var>pName</var> must be a valid class name (<method>IsName</method>) and <var>pNamespace</var>
/// one this instance defines, and each setting sent must be valid. When it is <code>update</code> and
/// <var>pFull</var> is 1, a setting is judged only where it differs from <var>pFresh</var>'s; with <var>pFull</var>
/// 0 every setting sent is judged by the rules that need no read. With <var>pFull</var> 1 the rule that reads the
/// instance applies too: a resource that is sent and changed, or any one on a create, must be empty or a service or
/// application resource the instance lists, read through <var>pPortClass</var> as the caller. A look-up that cannot
/// be made is an error status, never a pass. <var>pFresh</var> is <code>""</code> for a create.</p>
ClassMethod Check(pNamespace As %String, pName As %String, pBody As %DynamicObject, pFresh As %DynamicObject, pMode As %String, pPortClass As %String, Output pViolations, pFull As %Boolean = 1) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pBody) Set pBody = {}
        Set tCreate = (pMode = "create")
        Set tFresh = $Select($IsObject(pFresh): pFresh, 1: {})
        If tCreate {
            If '..IsName(pName) Do ..Add(.pViolations, "Name", ##class(OcuPilot.Api.DocDbAppError).#NAME)
            If '##class(OcuPilot.Port.AdminPort).NamespaceDefined(pNamespace) Do ..Add(.pViolations, "Namespace", ##class(OcuPilot.Api.DocDbAppError).#NAMESPACE)
        }
        Set tFields = $ListFromString(..#FIELDS)
        For tI = 1:1:$ListLength(tFields) {
            Set tField = $List(tFields, tI)
            Set tType = pBody.%GetTypeOf(tField)
            If tType = "unassigned" Continue
            If (tField '= "Enabled") && (tType '= "string") {
                Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Continue
            }
            If 'tCreate && pFull && (..Text(pBody, tField) = ..Text(tFresh, tField)) Continue
            If '..Valid(tField, pBody) Do ..Add(.pViolations, tField, ..CodeFor(tField))
        }
        If 'pFull Quit
        If (pBody.%GetTypeOf("Resource") = "string") && (tCreate || (pBody.%Get("Resource") '= ..Text(tFresh, "Resource"))) && (pBody.%Get("Resource") '= "") {
            Set tSC = ..ResourceListed(pPortClass, pBody.%Get("Resource"), .tListed)
            If $$$ISERR(tSC) Quit
            If 'tListed Do ..Add(.pViolations, "Resource", ##class(OcuPilot.Api.DocDbAppError).#RESOURCE)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The violation code of the setting <var>pField</var>.</p>
ClassMethod CodeFor(pField As %String) As %String
{
    If pField = "Description" Quit ##class(OcuPilot.Api.DocDbAppError).#DESCRIPTION
    If pField = "Enabled" Quit ##class(OcuPilot.Api.DocDbAppError).#ENABLED
    Quit ##class(OcuPilot.Api.DocDbAppError).#RESOURCE
}

/// <p>Whether the setting <var>pField</var> of <var>pBody</var> is acceptable by shape and length alone: a description
/// at most 256 characters and an enabled flag <method>IsEnabled</method> admits. A resource has no rule of this kind,
/// because <method>ResourceListed</method> decides it.</p>
ClassMethod Valid(pField As %String, pBody As %DynamicObject) As %Boolean
{
    If pField = "Enabled" Quit ..IsEnabled(pBody.%GetTypeOf("Enabled"), pBody.%Get("Enabled"))
    If pField = "Description" Quit $Length(pBody.%Get("Description")) <= ##class(OcuPilot.Api.DocDbAppError).#DESCRIPTIONMAX
    Quit 1
}

/// <p>Whether a value of JSON type <var>pType</var> reading <var>pValue</var> is an enabled flag: <code>true</code>,
/// <code>false</code>, the number 1 or 0, or the text <code>"1"</code> or <code>"0"</code>.</p>
ClassMethod IsEnabled(pType As %String, pValue As %String) As %Boolean
{
    If pType = "boolean" Quit 1
    If pType = "number" Quit (pValue = 0) || (pValue = 1)
    If pType = "string" Quit (pValue = "0") || (pValue = "1")
    Quit 0
}

/// <p>A copy of <var>pArgs</var> as a create sends it: <code>Enabled</code>, where <method>IsEnabled</method> admits it,
/// a boolean (the number or text 1 or 0 read as <code>true</code> or <code>false</code>), and each of the three
/// settings the caller left out at the instance's own default -- no description, enabled, no resource -- so the body is
/// the complete set and its read-back compares all three. Every other member, and a setting the rules refuse, is as it
/// was.</p>
ClassMethod CreateBody(pArgs As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pArgs) Quit pArgs
    Set tCopy = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    Set tType = tCopy.%GetTypeOf("Enabled")
    If tType = "unassigned" {
        Do tCopy.%Set("Enabled", 1, "boolean")
    } ElseIf (tType '= "boolean") && ..IsEnabled(tType, tCopy.%Get("Enabled")) {
        Do tCopy.%Set("Enabled", +tCopy.%Get("Enabled"), "boolean")
    }
    If tCopy.%GetTypeOf("Description") = "unassigned" Do tCopy.%Set("Description", "", "string")
    If tCopy.%GetTypeOf("Resource") = "unassigned" Do tCopy.%Set("Resource", "", "string")
    Quit tCopy
}

/// <p>Whether <var>pName</var> is a record name: <code>%Dictionary.Classname</code>'s own check, which the stored
/// property applies.</p>
ClassMethod IsName(pName As %String) As %Boolean
{
    Quit $$$ISOK($ClassMethod("%Dictionary.Classname", "IsValid", pName))
}

/// <p>Whether the resource <var>pName</var> is one the instance lists as a service or application resource, in
/// <var>pListed</var>, read through <var>pPortClass</var> as the caller. A failed read is an error status.</p>
ClassMethod ResourceListed(pPortClass As %String, pName As %String, Output pListed As %Boolean) As %Status
{
    Set pListed = 0
    Kill tQuery
    Set tSC = $ClassMethod(pPortClass, "Invoke", ..#RESOURCEENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tRows)) || 'tRows.%IsA("%Library.DynamicArray") Quit $$$ERROR($$$GeneralError, "the resources list was not an array")
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") Continue
        If ..Text(tRow, "Name") '= pName Continue
        If $ListFind($ListFromString(..#RESOURCETYPES), ..Text(tRow, ..#RESOURCETYPEFIELD)) Set pListed = 1
        Quit
    }
    Quit $$$OK
}

/// <p>Whether a record exists under the composite id of <var>pNamespace</var> and <var>pName</var>, in
/// <var>pTaken</var>, read through <var>pPortClass</var> as the caller with the update tool's own endpoint and read
/// type (AD-52); only a 404 is free, and any other failed read is an error status.</p>
ClassMethod Taken(pPortClass As %String, pNamespace As %String, pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Kill tQuery
    Set tQuery($ClassMethod(..#UPDATETOOL, "IdParam")) = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pNamespace, pName))
    Set tSC = $ClassMethod(pPortClass, "Invoke", $ClassMethod(..#UPDATETOOL, "Endpoint"), $ClassMethod(..#UPDATETOOL, "ReadType"), .tQuery, "", .tRead, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) = 404 Quit $$$OK
        Quit tSC
    }
    Set pTaken = ($IsObject($Get(tRead)) && tRead.%IsA("%Library.DynamicObject"))
    Quit $$$OK
}

/// <p><method>Check</method> as one problem sentence naming each field and its published sentence, or
/// <code>""</code>, in <var>pProblem</var>: what the tools' <code>ArgumentProblem</code> and
/// <code>MergeUpdate</code> answer.</p>
ClassMethod Problem(pNamespace As %String, pName As %String, pBody As %DynamicObject, pFresh As %DynamicObject, pMode As %String, pPortClass As %String, Output pProblem As %String, pFull As %Boolean = 1) As %Status
{
    Set pProblem = ""
    Set tSC = ..Check(pNamespace, pName, pBody, pFresh, pMode, pPortClass, .tViolations, pFull)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>Render <var>pViolations</var> as one 422 <parameter>OcuPilot.Api.DocDbAppError.VALIDATION</parameter>
/// envelope carrying every broken rule in <code>detail.violations</code> (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.DocDbAppError).#REASONVALIDATION, ##class(OcuPilot.Api.DocDbAppError).#VALIDATION, tDetail)
}

/// <p>Render a failed read of a record: 404 <code>PORT.NOTFOUND</code>, the fault the port answered, or an
/// internal error when it answered none.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Set tMapSC = ##class(OcuPilot.Kernel.Fault).Outcome(404, $$$OK, .tAbsent, .tVendorText)
        Quit ##class(OcuPilot.Api.Error).Render(404, tAbsent.error, tAbsent.reason, tAbsent.code)
    }
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Answer <code>GET /docdb-application/form[?id=&lt;composite id&gt;]</code>: <code>{row}</code>. With an id,
/// <code>row</code> is <code>Name</code>, <code>Namespace</code> and the three settings from the update tool's fresh
/// <code>GET</code>, <code>Enabled</code> a boolean; an id the instance does not hold, or that is not two parts, is 404
/// <code>PORT.NOTFOUND</code>. Without one it is a new record's, enabled and otherwise empty.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tId = $Get(%request.Data("id", 1))
        Set tRow = {}
        If tId = "" {
            Do ..DefaultRow(tRow)
        } Else {
            Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(tId)
            If ($ListLength(tParts) '= 2) || ($ListGet(tParts, 1) = "") || ($ListGet(tParts, 2) = "") {
                Set tSC = ..RenderRead($$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND), 404, "")
                Quit
            }
            Set tPort = $ClassMethod(..#UPDATETOOL, "PortClass")
            Kill tQuery
            Set tQuery($ClassMethod(..#UPDATETOOL, "IdParam")) = tId
            Set tReadSC = $ClassMethod(tPort, "Invoke", $ClassMethod(..#UPDATETOOL, "Endpoint"), $ClassMethod(..#UPDATETOOL, "ReadType"), .tQuery, "", .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, $Get(tHttp), $Get(tFault))
                Quit
            }
            If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") {
                Set tSC = ..RenderRead($$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND), 404, "")
                Quit
            }
            Do tRow.%Set("Name", $ListGet(tParts, 2), "string")
            Do tRow.%Set("Namespace", $ZConvert($ListGet(tParts, 1), "U"), "string")
            Do tRow.%Set("Description", ..Text(tFresh, "Description"), "string")
            Do tRow.%Set("Enabled", ''..Truth(tFresh), "boolean")
            Do tRow.%Set("Resource", ..Text(tFresh, "Resource"), "string")
        }
        Set tBody = {}
        Do tBody.%Set("row", tRow)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Set into <var>pRow</var> a new record's fields: enabled, as the instance defaults it, and every other one
/// empty.</p>
ClassMethod DefaultRow(pRow As %DynamicObject)
{
    Do pRow.%Set("Name", "", "string")
    Do pRow.%Set("Namespace", "", "string")
    Do pRow.%Set("Description", "", "string")
    Do pRow.%Set("Enabled", 1, "boolean")
    Do pRow.%Set("Resource", "", "string")
}

/// <p>Whether <var>pFresh</var>'s <code>Enabled</code> reads as set: a boolean, number or text the way
/// <method>IsEnabled</method> admits.</p>
ClassMethod Truth(pFresh As %DynamicObject) As %Boolean
{
    Set tType = pFresh.%GetTypeOf("Enabled")
    If tType = "boolean" Quit pFresh.%Get("Enabled")
    Quit (..Text(pFresh, "Enabled") = "1")
}

/// <p>Refuse a caller who does not hold the form's declared pairs (AD-8): <var>pRefused</var> 1 means the
/// envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p><var>pBody</var>'s <var>pName</var> as text, <code>""</code> when it carries none.</p>
ClassMethod Text(pBody As %DynamicObject, pName As %String) As %String
{
    Set tType = pBody.%GetTypeOf(pName)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pBody.%Get(pName) _ ""
}

/// <p>Append one violation.</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
