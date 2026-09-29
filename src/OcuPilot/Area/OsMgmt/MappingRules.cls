/// <p>The namespace mapping editor's rules (AD-39, AD-55, Story 18.14): the one rule set every caller
/// of a mapping create or edit tool applies (<method>Validate</method>), the form's read
/// (<method>HandleForm</method>) and the name look-up (<method>HandleName</method>,
/// <method>Taken</method>), for each of the three kinds -- <code>global</code>, <code>routine</code>
/// and <code>package</code>.</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, and the form
/// read serves the same sentences, so an inline blur refusal and a failed Save are one wording.</p>
/// <p>Every read goes through the kind's own tools' port, endpoint and read type as the caller
/// (AD-52). The database list is <class>OcuPilot.Area.OsMgmt.NamespaceRules</class>' own.</p>
Class OcuPilot.Area.OsMgmt.MappingRules Extends %RegisteredObject
{

/// <p>The kinds a mapping route takes, comma-separated.</p>
Parameter KINDS = "global,routine,package";

/// <p>The package the kinds' tools and descriptors live in.</p>
Parameter TOOLPACKAGE = "OcuPilot.Screen.Tool.";

Parameter DESCRIPTORPACKAGE = "OcuPilot.Screen.Descriptor.";

/// <p>The endpoint whose <code>GET</code> answers whether a namespace exists.</p>
Parameter NAMESPACEENDPOINT = "Namespace.Namespace";

/// <p>The fields a create must carry, comma-separated.</p>
Parameter REQUIREDFIELDS = "Name,Database";

/// <p>The fields the rules read, named once.</p>
Parameter FIELDNAMESPACE = "Namespace";

Parameter FIELDNAME = "Name";

Parameter FIELDDATABASE = "Database";

Parameter FIELDLOCKDATABASE = "LockDatabase";

Parameter FIELDCOLLATION = "Collation";

/// <p>A routine mapping's name whose type suffix -- the text after its last <code>_</code> -- holds
/// a lower-case letter. The vendor applies such a suffix upper-cased, creating the mapping, and then
/// answers 500 (measured on <code>ocupilot-b-ci</code>), so it is refused before any call.</p>
Parameter ROUTINESUFFIXPATTERN = ".*_[^_]*[a-z][^_]*";

/// <p>Whether <var>pKind</var> is one of <parameter>KINDS</parameter>.</p>
ClassMethod IsKind(pKind As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#KINDS), pKind)
}

/// <p>The 404 a route answers for a kind outside <parameter>KINDS</parameter>: there is no
/// operation at that address.</p>
ClassMethod NotAKind() As %Status
{
    Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, "The requested route does not exist", ##class(OcuPilot.Api.Error).#ROUTENOTFOUND)
}

/// <p>The kind's capitalized name, the prefix of its tools' and descriptors' class names.</p>
ClassMethod KindName(pKind As %String) As %String [ Private ]
{
    Quit $ZConvert($Extract(pKind), "U") _ $Extract(pKind, 2, *)
}

/// <p>The kind's create, edit or delete tool class, for <var>pVerb</var> <code>Create</code>,
/// <code>Update</code> or <code>Delete</code>.</p>
ClassMethod ToolClass(pKind As %String, pVerb As %String) As %String
{
    Quit ..#TOOLPACKAGE _ ..KindName(pKind) _ "Mapping" _ pVerb
}

/// <p>The kind's form descriptor class, whose pairs gate these routes (AD-8).</p>
ClassMethod FormDescriptor(pKind As %String) As %String
{
    Quit ..#DESCRIPTORPACKAGE _ ..KindName(pKind) _ "MappingForm"
}

/// <p>The kind's template fields, in the classic dialog's order.</p>
ClassMethod Fields(pKind As %String) As %List
{
    If pKind = "global" Quit $ListBuild(..#FIELDDATABASE, ..#FIELDLOCKDATABASE, ..#FIELDCOLLATION)
    Quit $ListBuild(..#FIELDDATABASE)
}

/// <p>Every rule a mapping write of kind <var>pKind</var> applies to <var>pArgs</var> for the mapping
/// <var>pName</var> of namespace <var>pNamespace</var>, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pMode</var> <code>create</code> requires the name and the database and applies the name's
/// own rules; <code>update</code> skips the name, which is the present mapping's, and refuses the
/// database only when <var>pArgs</var> empties it. The namespace must be one the instance holds. A
/// database field that is sent must name a database the instance lists, compared without regard to
/// case, and a lock database may be empty. A collation, when sent, is a whole number.
/// <var>pCheckTaken</var> 0 skips the name look-up, for the agent's mint, which has read the target
/// itself.</p>
/// <p>A read that cannot be made is an error status, never a pass.</p>
ClassMethod Validate(pKind As %String, pNamespace As %String, pName As %String, pArgs As %DynamicObject, Output pViolations, pMode As %String = "create", pCheckTaken As %Boolean = 1) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tCreates = (pMode = "create")
        Set tSC = ..NamespaceHeld(pNamespace, .tHeld)
        If $$$ISERR(tSC) Quit
        If 'tHeld Do ..Add(.pViolations, ..#FIELDNAMESPACE, ##class(OcuPilot.Api.Error).#MAPPINGNAMESPACEABSENT)
        If tCreates Do ..NameViolation(pKind, pName, .pViolations)
        If tCreates && tHeld && (pViolations = 0) && pCheckTaken {
            Set tSC = ..Taken(pKind, pNamespace, pName, .tTaken)
            If $$$ISERR(tSC) Quit
            If tTaken Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#MAPPINGNAMETAKEN)
        }
        If '$IsObject(pArgs) Set pArgs = {}
        Set tFields = ..Fields(pKind)
        Set tListed = 0
        Set tDatabases = ""
        For tI = 1:1:$ListLength(tFields) {
            Set tField = $List(tFields, tI)
            Set tType = pArgs.%GetTypeOf(tField)
            If (tType = "object") || (tType = "array") {
                Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Continue
            }
            If tField = ..#FIELDCOLLATION {
                If tType = "unassigned" Continue
                If '$Match(..Text(pArgs, tField), "^[0-9]+$") Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#MAPPINGCOLLATIONVALUE)
                Continue
            }
            Set tRequired = (tField = ..#FIELDDATABASE)
            If tType = "unassigned" {
                If tCreates && tRequired Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#MAPPINGDATABASEREQUIRED)
                Continue
            }
            Set tValue = ..Text(pArgs, tField)
            If tValue = "" {
                If tRequired Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#MAPPINGDATABASEREQUIRED)
                Continue
            }
            If 'tListed {
                Set tSC = ##class(OcuPilot.Area.OsMgmt.NamespaceRules).Databases(.tDatabases)
                If $$$ISERR(tSC) Quit
                Set tListed = 1
            }
            If ##class(OcuPilot.Area.OsMgmt.NamespaceRules).Spelled(tDatabases, tValue) = "" Do ..Add(.pViolations, tField, $Select(tRequired: ##class(OcuPilot.Api.Error).#MAPPINGDATABASEABSENT, 1: ##class(OcuPilot.Api.Error).#MAPPINGLOCKDATABASEABSENT))
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add the name's own violation to <var>pViolations</var>, or none: an absent name, and a
/// routine name whose type suffix is not written in capitals
/// (<parameter>ROUTINESUFFIXPATTERN</parameter>). Every other name is the vendor's to judge, and its
/// refusal reaches the field through the port (<parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter>).</p>
ClassMethod NameViolation(pKind As %String, pName As %String, Output pViolations)
{
    If pName = "" {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#MAPPINGNAMEREQUIRED)
        Quit
    }
    If (pKind = "routine") && $Match(pName, ..#ROUTINESUFFIXPATTERN) Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#MAPPINGNAMESHAPE)
}

/// <p>The template fields <var>pArgs</var> sets to a value other than <var>pFresh</var>'s, compared as
/// the diff renders them, as a new <class>%DynamicObject</class>. With no fresh read every one
/// <var>pArgs</var> carries is changed.</p>
ClassMethod Changed(pKind As %String, pArgs As %DynamicObject, pFresh As %DynamicObject = "") As %DynamicObject
{
    Set tChanged = {}
    If '$IsObject(pArgs) Quit tChanged
    Set tFields = ..Fields(pKind)
    For tI = 1:1:$ListLength(tFields) {
        Set tField = $List(tFields, tI)
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

/// <p>Set <var>pPayload</var>'s database fields to the spelling this instance's databases list gives
/// them, where the list names them without regard to case. A list that cannot be read, and a value
/// it does not name, leave the field as it is, for the vendor to answer.</p>
ClassMethod Spell(pPayload As %DynamicObject)
{
    If '$IsObject(pPayload) Quit
    Set tSC = ##class(OcuPilot.Area.OsMgmt.NamespaceRules).Databases(.tDatabases)
    If $$$ISERR(tSC) Quit
    For tField = ..#FIELDDATABASE, ..#FIELDLOCKDATABASE {
        If pPayload.%GetTypeOf(tField) '= "string" Continue
        Set tSpelled = ##class(OcuPilot.Area.OsMgmt.NamespaceRules).Spelled(tDatabases, pPayload.%Get(tField))
        If tSpelled '= "" Do pPayload.%Set(tField, tSpelled, "string")
    }
}

/// <p>Answer <code>GET /mapping/:kind/form?namespace=&lt;ns&gt;[&amp;name=&lt;n&gt;]</code>: everything
/// the form needs before it can draw a field (AD-39): <code>{requiredFields, rules, databases,
/// namespace}</code>, the namespace as the instance holds it. With a name it adds
/// <code>mapping</code>, the name and the kind's template fields from the edit tool's fresh read. A
/// namespace the instance does not hold is 404 <code>MAPPING.NAMESPACE.ABSENT</code>, and a mapping it
/// does not hold 404 <code>MAPPING.NAME.ABSENT</code>.</p>
ClassMethod HandleForm(pKind As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If '..IsKind(pKind) {
            Set tSC = ..NotAKind()
            Quit
        }
        Set tGateSC = ..Gate(pKind, .tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tNamespace = $Get(%request.Data("namespace", 1))
        Set tHeldSC = ..NamespaceHeld(tNamespace, .tHeld)
        If $$$ISERR(tHeldSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tHeldSC))
            Quit
        }
        If 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONNAMESPACENAMEABSENT, ##class(OcuPilot.Api.Error).#MAPPINGNAMESPACEABSENT)
            Quit
        }
        Set tBody = {}
        Set tRequired = []
        For tI = 1:1:$Length(..#REQUIREDFIELDS, ",") Do tRequired.%Push($Piece(..#REQUIREDFIELDS, ",", tI))
        Do tBody.%Set("requiredFields", tRequired)
        Do tBody.%Set("rules", ..Rules(pKind))
        Set tListSC = ##class(OcuPilot.Area.OsMgmt.NamespaceRules).Databases(.tDatabases)
        If $$$ISERR(tListSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tListSC))
            Quit
        }
        Set tNames = []
        For tI = 1:1:$ListLength(tDatabases) Do tNames.%Push($List(tDatabases, tI))
        Do tBody.%Set("databases", tNames)
        Do tBody.%Set("namespace", $ZConvert(tNamespace, "U"), "string")
        Set tName = $Get(%request.Data("name", 1))
        If tName '= "" {
            Set tReadSC = ..Present(pKind, tNamespace, tName, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, tHttp, tFault)
                Quit
            }
            Set tMapping = {}
            Do tMapping.%Set(..#FIELDNAME, tName, "string")
            Set tFields = ..Fields(pKind)
            For tI = 1:1:$ListLength(tFields) {
                Set tField = $List(tFields, tI)
                If tField = ..#FIELDCOLLATION {
                    If tFresh.%GetTypeOf(tField) = "number" {
                        Do tMapping.%Set(tField, tFresh.%Get(tField), "number")
                    } Else {
                        Do tMapping.%Set(tField, ..Text(tFresh, tField), "string")
                    }
                    Continue
                }
                Do tMapping.%Set(tField, ..Text(tFresh, tField), "string")
            }
            Do tBody.%Set("mapping", tMapping)
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /mapping/:kind/name?namespace=&lt;ns&gt;&amp;name=&lt;n&gt;</code>: whether that
/// namespace already has a mapping of this kind with that name, in <code>{name, taken,
/// reason}</code>. A look-up that cannot be made is a refusal envelope, never an assertion that the
/// name is free.</p>
ClassMethod HandleName(pKind As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If '..IsKind(pKind) {
            Set tSC = ..NotAKind()
            Quit
        }
        Set tGateSC = ..Gate(pKind, .tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tNamespace = $Get(%request.Data("namespace", 1))
        Set tName = $Get(%request.Data("name", 1))
        If tName = "" {
            Set tSC = ##class(OcuPilot.Area.OsMgmt.MappingSave).RenderOne(..#FIELDNAME, ##class(OcuPilot.Api.Error).#MAPPINGNAMEREQUIRED)
            Quit
        }
        If tNamespace = "" {
            Set tSC = ##class(OcuPilot.Area.OsMgmt.MappingSave).RenderOne(..#FIELDNAMESPACE, ##class(OcuPilot.Api.Error).#MAPPINGNAMESPACEABSENT)
            Quit
        }
        Set tTakenSC = ..Taken(pKind, tNamespace, tName, .tTaken)
        If $$$ISERR(tTakenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tTakenSC))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("name", tName, "string")
        Do tBody.%Set("taken", tTaken, "boolean")
        Do tBody.%Set("reason", $Select(tTaken: ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#MAPPINGNAMETAKEN), 1: ""), "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Whether namespace <var>pNamespace</var> already has a mapping of kind <var>pKind</var> named
/// <var>pName</var>, in <var>pTaken</var>: the create tool's own read does not answer 404 (AD-52).</p>
/// <p><b>Caller contract:</b> an error status means the question was not answered; only a 404 is
/// "free".</p>
ClassMethod Taken(pKind As %String, pNamespace As %String, pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Set tSC = ..Read(..ToolClass(pKind, "Create"), pNamespace, pName, .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) = 404 Quit $$$OK
        Quit tSC
    }
    Set pTaken = ($IsObject(tFresh) && tFresh.%IsA("%Library.DynamicObject"))
    Quit $$$OK
}

/// <p>The present mapping <var>pName</var> of namespace <var>pNamespace</var>, read through the kind's
/// edit tool's own port, endpoint and read type (AD-52), in <var>pFresh</var>. An absent one is an
/// error status with <var>pHttpStatus</var> 404.</p>
ClassMethod Present(pKind As %String, pNamespace As %String, pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ..Read(..ToolClass(pKind, "Update"), pNamespace, pName, .pFresh, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#MAPPINGNAMEABSENT)
    }
    Quit tSC
}

/// <p>Whether the instance holds namespace <var>pNamespace</var>, in <var>pHeld</var>, read through
/// the kind-independent <parameter>NAMESPACEENDPOINT</parameter> <code>GET</code> on the mapping
/// tools' port, as the caller. An empty name is not held.</p>
ClassMethod NamespaceHeld(pNamespace As %String, Output pHeld As %Boolean) As %Status
{
    Set pHeld = 0
    If pNamespace = "" Quit $$$OK
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery("name") = pNamespace
        Set tPort = $ClassMethod(..ToolClass("global", "Create"), "PortClass")
        Set tSC = $ClassMethod(tPort, "Invoke", ..#NAMESPACEENDPOINT, "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
        If $$$ISERR(tSC) {
            If +$Get(tHttp) = 404 Set tSC = $$$OK
            Quit
        }
        Set pHeld = ($IsObject(tFresh) && tFresh.%IsA("%Library.DynamicObject"))
    } Catch ex {
        Set pHeld = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Render a failed read: a 404 as <code>MAPPING.NAME.ABSENT</code>, any other refusal as the
/// port's own envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONMAPPINGNAMEABSENT, ##class(OcuPilot.Api.Error).#MAPPINGNAMEABSENT)
    }
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Read mapping <var>pName</var> of namespace <var>pNamespace</var> through tool
/// <var>pToolClass</var>'s own port, endpoint and read type, by its composite id.</p>
ClassMethod Read(pToolClass As %String, pNamespace As %String, pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pFresh = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "IdParam")) = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pNamespace, pName))
        Set tSC = $ClassMethod($ClassMethod(pToolClass, "PortClass"), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    } Catch ex {
        Set pFresh = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every rule this form applies, as <code>[{field, code, reason}]</code>: the
/// <code>MAPPING.*</code> codes whose field is one of kind <var>pKind</var>'s fields, its name or its
/// namespace. The sentences are <method>OcuPilot.Api.Error.ReasonForViolation</method>'s.</p>
ClassMethod Rules(pKind As %String) As %DynamicArray
{
    Set tRows = []
    Set tFields = ..Fields(pKind) _ $ListBuild(..#FIELDNAME, ..#FIELDNAMESPACE)
    Set tCodes = ##class(OcuPilot.Api.Error).MappingViolationCodes()
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tField = ..FieldOf(tCode)
        If '$ListFind(tFields, tField) Continue
        If (tCode = ##class(OcuPilot.Api.Error).#MAPPINGNAMESUBSCRIPTS) && (pKind '= "global") Continue
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        If tReason = "" Continue
        Set tRow = {}
        Do tRow.%Set("field", tField, "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", tReason, "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>The form field a <code>MAPPING.&lt;FIELD&gt;.&lt;RULE&gt;</code> code refuses.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    Set tPart = $Piece(pCode, ".", 2)
    For tField = ..#FIELDNAME, ..#FIELDNAMESPACE, ..#FIELDDATABASE, ..#FIELDLOCKDATABASE, ..#FIELDCOLLATION {
        If $ZConvert(tField, "U") = tPart Quit
    }
    If $ZConvert(tField, "U") '= tPart Quit ""
    Quit tField
}

/// <p>Refuse a caller who does not hold kind <var>pKind</var>'s form's declared pairs (AD-8):
/// <var>pRefused</var> 1 means the envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(pKind As %String, Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..FormDescriptor(pKind), .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
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
