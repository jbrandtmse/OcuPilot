/// <p>The namespace editor's rules (AD-39, AD-55): the one rule set every caller of
/// <class>OcuPilot.Screen.Tool.NamespaceCreate</class> and
/// <class>OcuPilot.Screen.Tool.NamespaceUpdate</class> applies (<method>Validate</method>), the form's
/// read (<method>HandleForm</method>) and the name look-up (<method>HandleName</method>,
/// <method>Taken</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, and the form
/// read serves the same sentences, so an inline blur refusal and a failed Save are one wording.</p>
/// <p>A name is refused before any vendor call when it is not one <class>Config.Namespaces</class>
/// accepts, and a database field when it names no database the instance lists; the list is read
/// through the create tool's port as the caller.</p>
Class OcuPilot.Area.OsMgmt.NamespaceRules Extends %RegisteredObject
{

/// <p>The tools the callers resolve the writes through (AD-55): the create for a name look-up and
/// the database list, the edit for a present namespace's read.</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.NamespaceCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.NamespaceUpdate";

/// <p>The screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.NamespaceForm";

/// <p>The endpoint whose list is the instance's databases.</p>
Parameter DATABASEENDPOINT = "Database.ConfigCRUD";

/// <p>The fields a create must carry, comma-separated.</p>
Parameter REQUIREDFIELDS = "Name,Globals,Routines";

/// <p>The namespace's three settable fields, in the classic page's order.</p>
Parameter FIELDS = "Globals,Routines,TempGlobals";

/// <p>A name <class>Config.Namespaces</class> accepts: a letter or <code>%</code>, then letters,
/// digits, <code>_</code> or <code>-</code>, at most 64 characters in all (measured on
/// <code>ocupilot-b-ci</code>: a dot, a leading digit, a space or <code>$</code> is refused 457, and a
/// 65th character 7201).</p>
Parameter NAMEPATTERN = "[%A-Za-z][A-Za-z0-9_-]{0,63}";

/// <p>The fields the rules read, named once.</p>
Parameter FIELDNAME = "Name";

Parameter FIELDGLOBALS = "Globals";

Parameter FIELDROUTINES = "Routines";

Parameter FIELDTEMPGLOBALS = "TempGlobals";

/// <p>Every rule a namespace write applies to <var>pArgs</var>, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pMode</var> <code>create</code> applies the name's own rules and requires the globals and
/// routines databases; <code>update</code> skips the name, which is the present namespace's, and
/// refuses a required field only when <var>pArgs</var> empties it. A database field that is sent
/// must name a database the instance lists, compared without regard to case.
/// <var>pCheckTaken</var> 0 skips the name look-up, for the agent's mint, which has read the target
/// itself. <var>pFresh</var> is the edit's fresh read and is not read here.</p>
/// <p>A list that cannot be read is an error status, never a pass.</p>
ClassMethod Validate(pName As %String, pArgs As %DynamicObject, Output pViolations, pMode As %String = "create", pCheckTaken As %Boolean = 1, pFresh As %DynamicObject = "") As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tCreates = (pMode = "create")
        If tCreates Do ..NameViolation(pName, .pViolations)
        If tCreates && (pViolations = 0) && pCheckTaken {
            Set tSC = ..Taken(pName, .tTaken)
            If $$$ISERR(tSC) Quit
            If tTaken Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#NAMESPACENAMETAKEN)
        }
        If '$IsObject(pArgs) Set pArgs = {}
        Set tDatabases = ""
        Set tListed = 0
        For tI = 1:1:$Length(..#FIELDS, ",") {
            Set tField = $Piece(..#FIELDS, ",", tI)
            Set tType = pArgs.%GetTypeOf(tField)
            If (tType = "object") || (tType = "array") {
                Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Continue
            }
            Set tRequired = (tField '= ..#FIELDTEMPGLOBALS)
            If tType = "unassigned" {
                If tCreates && tRequired Do ..Add(.pViolations, tField, ..Code(tField, "REQUIRED"))
                Continue
            }
            Set tValue = ..Text(pArgs, tField)
            If tValue = "" {
                Do ..Add(.pViolations, tField, ..Code(tField, $Select(tRequired: "REQUIRED", 1: "ABSENT")))
                Continue
            }
            If 'tListed {
                Set tSC = ..Databases(.tDatabases)
                If $$$ISERR(tSC) Quit
                Set tListed = 1
            }
            If ..Spelled(tDatabases, tValue) = "" Do ..Add(.pViolations, tField, ..Code(tField, "ABSENT"))
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add the name's own violation to <var>pViolations</var>, or none: an absent name, and one
/// <parameter>NAMEPATTERN</parameter> refuses.</p>
ClassMethod NameViolation(pName As %String, Output pViolations)
{
    If pName = "" {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#NAMESPACENAMEREQUIRED)
        Quit
    }
    If '$Match(pName, ..#NAMEPATTERN) Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#NAMESPACENAMESHAPE)
}

/// <p>The fields among the three that <var>pArgs</var> sets to a value other than
/// <var>pFresh</var>'s, compared as the diff renders them, as a new <class>%DynamicObject</class>.
/// With no fresh read every one <var>pArgs</var> carries is changed.</p>
ClassMethod Changed(pArgs As %DynamicObject, pFresh As %DynamicObject = "") As %DynamicObject
{
    Set tChanged = {}
    If '$IsObject(pArgs) Quit tChanged
    For tI = 1:1:$Length(..#FIELDS, ",") {
        Set tField = $Piece(..#FIELDS, ",", tI)
        Set tType = pArgs.%GetTypeOf(tField)
        If tType = "unassigned" Continue
        If $IsObject(pFresh) && (pFresh.%GetTypeOf(tField) '= "unassigned") {
            Set tBefore = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField))
            Set tAfter = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pArgs.%Get(tField), tType)
            If tAfter = tBefore Continue
        }
        If (tType = "object") || (tType = "array") {
            Do tChanged.%Set(tField, pArgs.%Get(tField))
        } Else {
            Do tChanged.%Set(tField, pArgs.%Get(tField), tType)
        }
    }
    Quit tChanged
}

/// <p>Set each database field of <var>pPayload</var> to the spelling this instance's databases list
/// gives it, where the list names it without regard to case. A list that cannot be read, and a value
/// it does not name, leave the field as it is, for the vendor to answer.</p>
ClassMethod Spell(pPayload As %DynamicObject)
{
    If '$IsObject(pPayload) Quit
    Set tSC = ..Databases(.tDatabases)
    If $$$ISERR(tSC) Quit
    For tI = 1:1:$Length(..#FIELDS, ",") {
        Set tField = $Piece(..#FIELDS, ",", tI)
        If pPayload.%GetTypeOf(tField) '= "string" Continue
        Set tSpelled = ..Spelled(tDatabases, pPayload.%Get(tField))
        If tSpelled '= "" Do pPayload.%Set(tField, tSpelled, "string")
    }
}

/// <p>Answer <code>GET /namespace/form[?name=&lt;n&gt;]</code>: everything the form needs before it
/// can draw a field (AD-39): <code>{requiredFields, rules, databases}</code>. With a name it adds
/// <code>namespace: {Name, Globals, Routines, TempGlobals}</code> from the edit tool's fresh read; a
/// name this instance does not hold is 404
/// <parameter>OcuPilot.Api.Error.NAMESPACENAMEABSENT</parameter>.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tBody = {}
        Set tRequired = []
        For tI = 1:1:$Length(..#REQUIREDFIELDS, ",") Do tRequired.%Push($Piece(..#REQUIREDFIELDS, ",", tI))
        Do tBody.%Set("requiredFields", tRequired)
        Do tBody.%Set("rules", ..Rules())
        Set tListSC = ..Databases(.tDatabases)
        If $$$ISERR(tListSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tListSC))
            Quit
        }
        Set tNames = []
        For tI = 1:1:$ListLength(tDatabases) Do tNames.%Push($List(tDatabases, tI))
        Do tBody.%Set("databases", tNames)
        Set tName = $Get(%request.Data("name", 1))
        If tName '= "" {
            Set tReadSC = ..Present(tName, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, tHttp, tFault)
                Quit
            }
            Set tNamespace = {}
            Do tNamespace.%Set(..#FIELDNAME, $ZConvert(tName, "U"), "string")
            For tI = 1:1:$Length(..#FIELDS, ",") {
                Set tField = $Piece(..#FIELDS, ",", tI)
                Do tNamespace.%Set(tField, ..Text(tFresh, tField), "string")
            }
            Do tBody.%Set("namespace", tNamespace)
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /namespace/name?name=&lt;n&gt;</code>: whether that name is taken, in
/// <code>{name, taken, reason}</code>. A look-up that cannot be made is a refusal envelope, never an
/// assertion that the name is free.</p>
ClassMethod HandleName() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tName = $Get(%request.Data("name", 1))
        If tName = "" {
            Set tSC = ##class(OcuPilot.Area.OsMgmt.NamespaceSave).RenderOne(..#FIELDNAME, ##class(OcuPilot.Api.Error).#NAMESPACENAMEREQUIRED)
            Quit
        }
        Set tTakenSC = ..Taken(tName, .tTaken)
        If $$$ISERR(tTakenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tTakenSC))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("name", tName, "string")
        Do tBody.%Set("taken", tTaken, "boolean")
        Do tBody.%Set("reason", $Select(tTaken: ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#NAMESPACENAMETAKEN), 1: ""), "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Whether a namespace already carries <var>pName</var>, compared without regard to case, in
/// <var>pTaken</var>, read through the create tool's own port, endpoint and read type (AD-52).</p>
/// <p><b>Caller contract:</b> an error status means the question was not answered; only a 404 is
/// "free". A name <parameter>NAMEPATTERN</parameter> refuses is never looked up and reads free.</p>
ClassMethod Taken(pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    If '$Match(pName, ..#NAMEPATTERN) Quit $$$OK
    Set tSC = ..Read(..#CREATETOOL, pName, .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) = 404 Quit $$$OK
        Quit tSC
    }
    Set pTaken = ($IsObject(tFresh) && tFresh.%IsA("%Library.DynamicObject"))
    Quit $$$OK
}

/// <p>The present namespace <var>pName</var>, read through the edit tool's own port, endpoint and
/// read type (AD-52), in <var>pFresh</var>. An absent one is an error status with
/// <var>pHttpStatus</var> 404.</p>
ClassMethod Present(pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ..Read(..#UPDATETOOL, pName, .pFresh, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#NAMESPACENAMEABSENT)
    }
    Quit tSC
}

/// <p>Render a failed read: a 404 as <parameter>OcuPilot.Api.Error.NAMESPACENAMEABSENT</parameter>,
/// any other refusal as the port's own envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONNAMESPACENAMEABSENT, ##class(OcuPilot.Api.Error).#NAMESPACENAMEABSENT)
    }
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Read <var>pName</var> through tool <var>pToolClass</var>'s own port, endpoint and read
/// type.</p>
ClassMethod Read(pToolClass As %String, pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pFresh = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "IdParam")) = pName
        Set tSC = $ClassMethod($ClassMethod(pToolClass, "PortClass"), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    } Catch ex {
        Set pFresh = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The names of the databases this instance lists, as a <class>%List</class> in the vendor's
/// order, read through the create tool's port from <parameter>DATABASEENDPOINT</parameter>'s
/// <code>LIST</code> as the caller.</p>
ClassMethod Databases(Output pNames As %List) As %Status
{
    Set pNames = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tPort = $ClassMethod(..#CREATETOOL, "PortClass")
        Set tSC = $ClassMethod(tPort, "Invoke", ..#DATABASEENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject($Get(tRows)) || 'tRows.%IsA("%Library.DynamicArray") {
            Set tSC = $$$ERROR($$$GeneralError, "the database list did not answer an array")
            Quit
        }
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            Set tName = tRow.%Get("Name")
            If (tName '= "") && '$ListFind(pNames, tName) Set pNames = pNames _ $ListBuild(tName)
        }
    } Catch ex {
        Set pNames = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The entry of <var>pNames</var> equal to <var>pValue</var> without regard to case, or
/// <code>""</code>.</p>
ClassMethod Spelled(pNames As %List, pValue As %String) As %String
{
    Set tWanted = $ZConvert(pValue, "U")
    Set tFound = ""
    For tI = 1:1:$ListLength(pNames) {
        If $ZConvert($List(pNames, tI), "U") = tWanted Set tFound = $List(pNames, tI) Quit
    }
    Quit tFound
}

/// <p>Every rule this form applies, as <code>[{field, code, reason}]</code>. The sentences are
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s; a code with no sentence is absent.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = ##class(OcuPilot.Api.Error).NamespaceViolationCodes()
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        If tReason = "" Continue
        Set tRow = {}
        Do tRow.%Set("field", ..FieldOf(tCode), "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", tReason, "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>The form field a <code>NAMESPACE.&lt;FIELD&gt;.&lt;RULE&gt;</code> code refuses.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    Set tPart = $Piece(pCode, ".", 2)
    If tPart = "NAME" Quit ..#FIELDNAME
    For tI = 1:1:$Length(..#FIELDS, ",") {
        Set tField = $Piece(..#FIELDS, ",", tI)
        If $ZConvert(tField, "U") = tPart Quit
        Set tField = ""
    }
    Quit tField
}

/// <p>Refuse a caller who does not hold the form's declared pairs (AD-8): <var>pRefused</var> 1
/// means the envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>The violation code <code>NAMESPACE.&lt;FIELD&gt;.&lt;RULE&gt;</code> for <var>pField</var>.</p>
ClassMethod Code(pField As %String, pRule As %String) As %String [ Private ]
{
    Quit "NAMESPACE." _ $ZConvert(pField, "U") _ "." _ pRule
}

/// <p><var>pObject</var>'s <var>pField</var> as text: a null or absent field as <code>""</code>.</p>
ClassMethod Text(pObject As %DynamicObject, pField As %String) As %String [ Private ]
{
    If '$IsObject(pObject) Quit ""
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") Quit ""
    Quit pObject.%Get(pField)
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
