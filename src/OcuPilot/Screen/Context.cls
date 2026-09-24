/// <p>Resolves a validated wire <code>context</code> object to its screen and projects it into the
/// payload a turn's synthetic <code>screen_context</code> tool result carries (Story 4.4, AD-24).
/// Its one caller is <class>OcuPilot.Api.Turn</class>, which bounds the payload this class returns
/// through <class>OcuPilot.Kernel.Agent.Bound</class> and hands the result on as a plain
/// <code>JOB</code> value to <class>OcuPilot.Kernel.Agent.Job</class>. <b>This class names no
/// <code>Kernel/Agent</code> class</b>: it projects identity, rows, sort and filter, and returns
/// the field-maximum map, and names the tools that act on a screen (<method>ScreenTools</method>);
/// the row cap and the size cut are the caller's, through
/// <method>OcuPilot.Kernel.Agent.Bound.Apply</method>.</p>
Class OcuPilot.Screen.Context Extends %RegisteredObject
{

/// <p>The screen registry the route is resolved against. Overridable for a test fixture;
/// production never overrides it.</p>
ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Screen.Registry"
}

/// <p>The tool registry <method>ScreenTools</method> lists. Overridable for a test fixture;
/// production never overrides it.</p>
ClassMethod ToolRegistryClass() As %String
{
    Quit "OcuPilot.Screen.Tool.Registry"
}

/// <p>Build the payload for a validated <var>pContext</var> (the wire object
/// <code>{route, namespace, entity?, view?}</code>, already passed
/// <method>OcuPilot.Api.Turn.ContextViolation</method>). <var>pBuilt</var> is 0, with
/// <var>pPayload</var> <code>""</code>, when the route resolves to no descriptor -- an unknown
/// route builds no <code>screen_context</code> call at all.</p>
/// <p>A descriptor declaring <code>context.secretFields</code> answers identity only:
/// <var>pPayload</var> carries <code>screen</code>, <code>route</code>, <code>namespace</code> and
/// <code>entity</code>, with no <code>rows</code> key at all, and <var>pFieldMaxLengths</var>
/// comes back empty. Otherwise <var>pPayload</var> also carries <code>sort</code>,
/// <code>direction</code>, <code>filter</code>, <code>rows</code> (each row narrowed to
/// <code>context.fields</code>, a non-scalar member dropped) and, when the caller sent one,
/// <code>rowsAvailable</code>; <var>pFieldMaxLengths</var> is the descriptor's declared
/// <code>context.maxLength</code> map, subscripted by field name, for the caller's cutter to
/// apply. <var>pDroppedFields</var> comes back as a <class>%List</class> of the field names a
/// non-scalar row value was dropped from -- the caller folds these into
/// <code>truncatedFields</code> beside whatever <method>OcuPilot.Kernel.Agent.Bound.Apply</method>
/// adds, since a dropped object or array is never a value that cutter's own per-field string check
/// sees.</p>
ClassMethod Build(pContext As %DynamicObject, Output pBuilt As %Boolean, Output pPayload As %DynamicObject, Output pFieldMaxLengths, Output pDroppedFields As %List) As %Status
{
    Set tSC = $$$OK
    Set pBuilt = 0
    Set pPayload = ""
    Set pDroppedFields = ""
    Kill pFieldMaxLengths
    Try {
        Set tRoute = pContext.%Get("route")
        Set tDescriptor = $ClassMethod(..RegistryClass(), "DescriptorForRoute", tRoute)
        If tDescriptor = "" Quit

        Set tScreen = $ClassMethod(tDescriptor, "ToolIdentifier")
        Set tNamespace = pContext.%Get("namespace")
        Set tEntity = ""
        If pContext.%IsDefined("entity") && (pContext.%GetTypeOf("entity") = "string") Set tEntity = pContext.%Get("entity")

        Set tPayload = {}
        Do tPayload.%Set("screen", tScreen, "string")
        Do tPayload.%Set("route", tRoute, "string")
        Do tPayload.%Set("namespace", tNamespace, "string")
        If tEntity = "" {
            Do tPayload.%Set("entity", "", "null")
        } Else {
            Do tPayload.%Set("entity", tEntity, "string")
        }

        Set tSecretList = $ClassMethod(tDescriptor, "ContextSecretFields")
        If $ListLength(tSecretList) > 0 {
            Set pPayload = tPayload
            Set pBuilt = 1
            Quit
        }

        Set tFieldList = $ClassMethod(tDescriptor, "ContextFields")

        Set tView = pContext.%Get("view")
        Set tSort = ""
        Set tDirection = ""
        Set tFilter = ""
        Set tRowsAvailable = ""
        Set tRawRows = []
        If $IsObject(tView) {
            If (tView.%GetTypeOf("sort") = "string") Set tSort = tView.%Get("sort")
            If (tSort '= "") && '$ListFind(tFieldList, tSort) Set tSort = ""
            If (tView.%GetTypeOf("direction") = "string") Set tDirection = tView.%Get("direction")
            If (tView.%GetTypeOf("filter") = "string") Set tFilter = tView.%Get("filter")
            If (tView.%GetTypeOf("rowsAvailable") = "number") Set tRowsAvailable = tView.%Get("rowsAvailable")
            If $IsObject(tView.%Get("rows")) Set tRawRows = tView.%Get("rows")
        }
        Do tPayload.%Set("sort", tSort, "string")
        Do tPayload.%Set("direction", tDirection, "string")
        Do tPayload.%Set("filter", tFilter, "string")

        Set tRows = []
        Set tRowIterator = tRawRows.%GetIterator()
        While tRowIterator.%GetNext(.tRowIndex, .tRow) {
            Set tNewRow = {}
            If $IsObject(tRow) && tRow.%IsA("%Library.DynamicObject") {
                Set tFieldIterator = tRow.%GetIterator()
                While tFieldIterator.%GetNext(.tKey, .tValue, .tValueType) {
                    If '$ListFind(tFieldList, tKey) Continue
                    If (tValueType = "object") || (tValueType = "array") {
                        If '$ListFind(pDroppedFields, tKey) Set pDroppedFields = pDroppedFields _ $ListBuild(tKey)
                        Continue
                    }
                    Do tNewRow.%Set(tKey, tValue, tValueType)
                }
            }
            Do tRows.%Push(tNewRow)
        }
        Do tPayload.%Set("rows", tRows)
        If tRowsAvailable '= "" Do tPayload.%Set("rowsAvailable", tRowsAvailable, "number")

        Do $ClassMethod(tDescriptor, "ContextMaxLengths", .pFieldMaxLengths)
        Set pPayload = tPayload
        Set pBuilt = 1
    } Catch ex {
        Set pBuilt = 0
        Set pPayload = ""
        Set pDroppedFields = ""
        Kill pFieldMaxLengths
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The wire names of the tools that act on the screen <var>pDescriptor</var>, as
/// <var>pTools</var> (AD-5, AD-24, AD-53): its read tools first, then its write tools, each group in
/// <method>OcuPilot.Screen.Tool.Registry.ListTools</method> name order, with no duplicates.</p>
/// <p>A tool is bound to a descriptor when its list entry's <code>descriptor</code> or its class's
/// <code>DESCRIPTORCLASS</code> is that descriptor. The read group is every read tool bound to
/// <var>pDescriptor</var>. The write group is every write tool bound to it that carries one of its
/// declared row actions (<code>ScreenActionIds</code>) or, when it declares a primary action,
/// creates its target (<code>Creates()</code>). A declared row action no tool bound to
/// <var>pDescriptor</var> carries is resolved against the descriptor its <code>parentScope</code>
/// route names. A screen that declares no read, no action and no parent -- a form page -- answers
/// <code>[]</code>.</p>
/// <p>A tool list that cannot be built returns its error, with <var>pTools</var> empty.</p>
ClassMethod ScreenTools(pDescriptor As %String, Output pTools As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set pTools = []
    Try {
        Set tSC = $ClassMethod(..ToolRegistryClass(), "ListTools", .tList)
        If $$$ISERR(tSC) Quit
        Set tRowActions = $ClassMethod(pDescriptor, "RowActionIds")
        Set tHasPrimary = ($ClassMethod(pDescriptor, "PrimaryActionId") '= "")
        Kill tRead, tWrite
        Set tCarried = ""
        Set tIterator = tList.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If '..BoundTo(tEntry, pDescriptor) Continue
            Set tName = tEntry.%Get("name")
            If tEntry.%Get("kind") = "read" {
                Set tRead(tName) = ""
                Continue
            }
            If tEntry.%Get("kind") '= "write" Continue
            Set tActionIds = ..ActionIds(tEntry)
            Set tCarries = 0
            For tI = 1:1:$ListLength(tRowActions) {
                Set tAction = $List(tRowActions, tI)
                If '$ListFind(tActionIds, tAction) Continue
                Set tCarries = 1
                If '$ListFind(tCarried, tAction) Set tCarried = tCarried _ $ListBuild(tAction)
            }
            If tCarries || (tHasPrimary && ..CreatesTarget(tEntry)) Set tWrite(tName) = ""
        }

        Set tUnreached = ""
        For tI = 1:1:$ListLength(tRowActions) {
            If '$ListFind(tCarried, $List(tRowActions, tI)) Set tUnreached = tUnreached _ $ListBuild($List(tRowActions, tI))
        }
        Set tParentScope = $ClassMethod(pDescriptor, "ParentScope")
        Set tParent = ""
        If (tUnreached '= "") && (tParentScope '= "") Set tParent = $ClassMethod(..RegistryClass(), "DescriptorForRoute", tParentScope)
        If tParent '= "" {
            Set tIterator = tList.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tEntry) {
                If tEntry.%Get("kind") '= "write" Continue
                If '..BoundTo(tEntry, tParent) Continue
                Set tActionIds = ..ActionIds(tEntry)
                For tI = 1:1:$ListLength(tUnreached) {
                    If $ListFind(tActionIds, $List(tUnreached, tI)) Set tWrite(tEntry.%Get("name")) = ""
                }
            }
        }

        For tKind = "read", "write" {
            Set tIterator = tList.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tEntry) {
                Set tName = tEntry.%Get("name")
                If (tKind = "read") && '$Data(tRead(tName)) Continue
                If (tKind = "write") && '$Data(tWrite(tName)) Continue
                Do pTools.%Push($ClassMethod(..ToolRegistryClass(), "WireName", tName))
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Set pTools = []
    Quit tSC
}

/// <p>Whether the tool list entry <var>pEntry</var> is bound to <var>pDescriptor</var>: its own
/// <code>descriptor</code>, or its class's <code>DESCRIPTORCLASS</code>, is that descriptor.</p>
ClassMethod BoundTo(pEntry As %DynamicObject, pDescriptor As %String) As %Boolean [ Private ]
{
    If pDescriptor = "" Quit 0
    If pEntry.%Get("descriptor") = pDescriptor Quit 1
    Set tClass = pEntry.%Get("class")
    If tClass = "" Quit 0
    Quit ($Parameter(tClass, "DESCRIPTORCLASS") = pDescriptor)
}

/// <p>The row-action ids the write tool <var>pEntry</var> carries, or <code>""</code> for a tool
/// class that declares none.</p>
ClassMethod ActionIds(pEntry As %DynamicObject) As %List [ Private ]
{
    Set tClass = pEntry.%Get("class")
    If (tClass = "") || '##class(%Dictionary.CompiledMethod).%ExistsId(tClass _ "||ScreenActionIds") Quit ""
    Quit $ClassMethod(tClass, "ScreenActionIds")
}

/// <p>Whether the write tool <var>pEntry</var> creates its target (AD-54).</p>
ClassMethod CreatesTarget(pEntry As %DynamicObject) As %Boolean [ Private ]
{
    Set tClass = pEntry.%Get("class")
    If (tClass = "") || '##class(%Dictionary.CompiledMethod).%ExistsId(tClass _ "||Creates") Quit 0
    Quit ''$ClassMethod(tClass, "Creates")
}

}
