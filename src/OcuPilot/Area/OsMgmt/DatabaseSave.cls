/// <p>The local database editor's Save (AD-55): <code>POST /database</code> creates one database
/// through <class>OcuPilot.Screen.Tool.LocalDatabaseCreate</class>, and <code>PUT /database/:id</code>
/// changes one through <class>OcuPilot.Screen.Tool.LocalDatabaseUpdateMount</class> and
/// <class>OcuPilot.Screen.Tool.LocalDatabaseUpdate</class>. The agent's half is the same tool classes
/// read by <class>OcuPilot.Kernel.Proposal.Mint</class> and
/// <class>OcuPilot.Kernel.Proposal.Confirm</class>.</p>
/// <p><b>It resolves everything about each write from its tool class</b>: the endpoint, the request
/// types, the port, the settable fields, the payload, the derived fields, the port query and the
/// pairs, the argument pairs among them, each asked before anything is read or sent. It mints no
/// proposal and takes no confirm token.</p>
/// <p><b>An edit is up to three groups, each one write</b>: <code>configuration</code> (the mounting
/// edit), then <code>file</code> (the file edit), each over its own fresh read with its endpoint's
/// complete set (AD-4), and last <code>size</code>, the size grow
/// (<class>OcuPilot.Screen.Tool.LocalDatabaseGrow</class>, Story 18.4), an action write whose body the
/// port builds from the group's <code>Size</code>. Each is sent only when the body carries it. A failed
/// later group leaves the earlier ones applied, and the refusal's <code>detail.applied</code> says
/// so.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.OsMgmt.DatabaseSave Extends %RegisteredObject
{

/// <p>The tool classes the two callers resolve the writes through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.LocalDatabaseCreate";

Parameter MOUNTTOOL = "OcuPilot.Screen.Tool.LocalDatabaseUpdateMount";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.LocalDatabaseUpdate";

/// <p>The edit's groups, in the order they are written, each <code>&lt;key&gt;:&lt;tool&gt;</code>.</p>
Parameter GROUPS = "configuration:OcuPilot.Screen.Tool.LocalDatabaseUpdateMount,file:OcuPilot.Screen.Tool.LocalDatabaseUpdate,size:OcuPilot.Screen.Tool.LocalDatabaseGrow";

/// <p>The screen whose declared pairs gate these routes, and whose entity type and scope the
/// prohibited set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocalDatabaseForm";

/// <p>The input property that names the target: the vendor's <code>name</code> query parameter.</p>
Parameter IDARGUMENT = "Name";

/// <p>The rules class both routes apply.</p>
Parameter RULES = "OcuPilot.Area.OsMgmt.DatabaseRules";

/// <p>The port the writes and the fresh reads go through, which is the tools' own declaration
/// (AD-52). Overridable so a fixture can observe what was sent; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#CREATETOOL, "PortClass")
}

/// <p>AD-10's set, asked before the port is touched. Overridable for the reason
/// <method>PortClass</method> is; production never overrides it.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>Answer <code>POST /database</code>: create one database from the body and answer
/// <code>{name, readBack}</code> with 201 (AD-58). A broken rule is one 422
/// <parameter>OcuPilot.Api.DatabaseError.VALIDATION</parameter> envelope carrying every violation;
/// any other refusal is the port's or the prohibited set's own envelope.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Set tHoldKey = ""
    Try {
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tGateSC = ..Gate(.tRefused, ..#CREATETOOL, tBody)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tName = ""
        If tBody.%GetTypeOf(..#IDARGUMENT) = "string" Set tName = tBody.%Get(..#IDARGUMENT)
        Set tHoldSC = ##class(OcuPilot.Kernel.Proposal.Operation).HoldTool(..#CREATETOOL, tName, .tHeld, .tHoldKey)
        If $$$ISERR(tHoldSC) || 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).RenderTargetBusy(tHoldSC)
            Quit
        }
        Set tPerformSC = ..Create(tName, tBody, .tHttp, .tFault, .tViolations, .tReadBack)
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 201, $ZConvert(tName, "U"), $Get(tReadBack))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Release(tHoldKey)
    Quit tSC
}

/// <p>Answer <code>PUT /database/:id</code>: change the configuration <var>pId</var> -- one path
/// segment, decoded once here (AD-13) -- from the body's <code>configuration</code>, <code>file</code>
/// and <code>size</code> groups, and answer <code>{name, configuration?, file?, size?}</code> with 200,
/// each group <code>{readBack}</code>, and <code>continues: true</code> when the size grow is still
/// running on the instance (AD-26). A key outside the groups, or outside a group's tool, is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>; a configuration the instance does not
/// hold is 404 <parameter>OcuPilot.Api.DatabaseError.NAMEABSENT</parameter>.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
    Set tHoldKey = ""
    Try {
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tName = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        ; The group names and shapes first, then every group's pairs, before anything is read; a key
        ; inside a group is its own Update's check, made before that group is written.
        Set tBad = ""
        Set tIterator = tBody.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If (..ToolOf(tKey) = "") || (tBody.%GetTypeOf(tKey) '= "object") Set tBad = tKey Quit
        }
        If tBad '= "" {
            Set tSC = ..RenderUnexpected(tBad)
            Quit
        }
        Set tGateSC = ..Gate(.tRefused)
        Set tGroups = ""
        For tI = 1:1:$Length(..#GROUPS, ",") {
            If tRefused || $$$ISERR(tGateSC) Quit
            Set tGroup = $Piece($Piece(..#GROUPS, ",", tI), ":", 1)
            If tBody.%GetTypeOf(tGroup) '= "object" Continue
            Set tGroups = tGroups _ $ListBuild(tGroup)
            ; The group's arguments with its target named, as the agent's are, so a tool whose pairs
            ; depend on the target's stored values resolves them for this database.
            Set tArgs = ##class(OcuPilot.Port.DatabasePort).Without(tBody.%Get(tGroup), $ListBuild(..#IDARGUMENT))
            Do tArgs.%Set(..#IDARGUMENT, tName, "string")
            Set tGateSC = ..Gate(.tRefused, ..ToolOf(tGroup), tArgs)
        }
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tHoldSC = ##class(OcuPilot.Kernel.Proposal.Operation).HoldTool(..#UPDATETOOL, tName, .tHeld, .tHoldKey)
        If $$$ISERR(tHoldSC) || 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).RenderTargetBusy(tHoldSC)
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("name", $ZConvert(tName, "U"), "string")
        Set tApplied = []
        Set tDone = 1
        For tI = 1:1:$ListLength(tGroups) {
            Set tGroup = $List(tGroups, tI)
            Kill tViolations
            Set tPerformSC = ..Update(..ToolOf(tGroup), tName, tBody.%Get(tGroup), .tHttp, .tFault, .tViolations, .tReadBack)
            If $$$ISERR(tPerformSC) || (+$Get(tViolations) > 0) {
                Set tDone = 0
                If (tApplied.%Size() = 0) && (+$Get(tHttp) = 404) {
                    Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.DatabaseError).#REASONNAMEABSENT, ##class(OcuPilot.Api.DatabaseError).#NAMEABSENT)
                    Quit
                }
                Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, tName, "", tApplied)
                Quit
            }
            Set tOutcome = {}
            If $IsObject($Get(tReadBack)) Do tOutcome.%Set("readBack", tReadBack)
            Do tAnswer.%Set(tGroup, tOutcome)
            ; AD-26: a queued size grow the port answered 202 was made and continues on the instance.
            If +$Get(tHttp) = 202 Do tAnswer.%Set("continues", 1, "boolean")
            Do tApplied.%Push(tGroup, "string")
        }
        If 'tDone Quit
        Set tSC = ##class(OcuPilot.Api.Response).JSONStatus(200, tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Release(tHoldKey)
    Quit tSC
}

/// <p>Create the database <var>pName</var> from <var>pArgs</var>.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array (<code>pViolations(n) =
/// $ListBuild(field, code)</code>, count in <code>pViolations</code>); a non-zero count means
/// nothing was written and the other outputs say nothing. Otherwise an error status carries
/// <var>pHttpStatus</var> and <var>pFault</var>; a refusal that names a field arrives as a violation
/// too (<method>PortViolations</method>). On success <var>pReadBack</var> is the write's read-back
/// (AD-58).</p>
ClassMethod Create(pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Do $ClassMethod(..#RULES, "NameViolation", pName, .pViolations)
        If pViolations > 0 Quit
        Set tClass = ..#CREATETOOL

        ; AD-10, AD-55: the set the confirm asks, over the caller's own fields, before the port.
        Set tSC = ..Prohibited(tClass, pName, ..CallerFields(pArgs), [], .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tSC = $ClassMethod(..#RULES, "Validate", pName, pArgs, .pViolations, "create", 1, "", .pHttpStatus, .pFault)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = $ClassMethod(tClass, "ComposeCreate", pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the database's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Set tSC = ..Send(tClass, pName, tPayload, .pHttpStatus, .pFault, .tWritten)
        If $$$ISERR(tSC) Do ..PortViolations(pFault, .pViolations)
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, pName, tPayload, "", ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Change the configuration <var>pName</var> through tool <var>pToolClass</var> by the fields
/// <var>pArgs</var> sends, merged over that tool's fresh read, so a field the caller did not send keeps
/// the instance's value and the body is the complete set (AD-4).</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s. A configuration the instance does not hold
/// is an error status with <var>pHttpStatus</var> 404 and nothing sent; a key the tool does not admit
/// is an error status with <var>pHttpStatus</var> 400.</p>
ClassMethod Update(pToolClass As %String, pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tAllowed = $ClassMethod(pToolClass, "SettableFields")
        Set tIterator = pArgs.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If '$ListFind(tAllowed, tKey) {
                Set pHttpStatus = 400
                Set pFault = ..Unexpected(tKey)
                Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED)
                Quit
            }
        }
        If $$$ISERR(tSC) Quit

        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "IdParam")) = pName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tFresh) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set pHttpStatus = 404
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.DatabaseError).#NAMEABSENT)
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""

        Set tSC = $ClassMethod(..#RULES, "Validate", pName, pArgs, .pViolations, "update", 0, "", .pHttpStatus, .pFault)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = $ClassMethod(pToolClass, "MergeUpdate", tFresh, pArgs, ..#IDARGUMENT, tAllowed, .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set pHttpStatus = 400
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS)
            Do pFault.%Set("detail", {"problem": (tProblem)})
            Set tSC = $$$ERROR($$$GeneralError, tProblem)
            Quit
        }

        Set tSC = ..Prohibited(pToolClass, pName, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tSC = ..Send(pToolClass, pName, tPayload, .pHttpStatus, .pFault, .tWritten)
        If $$$ISERR(tSC) Do ..PortViolations(pFault, .pViolations)
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(pToolClass, pName, tPayload, tFresh, ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Move a refusal whose fault names <code>DATABASE.*</code> or <code>PATH.*</code> fields into
/// <var>pViolations</var>, so it answers as the form's own 422.</p>
ClassMethod PortViolations(pFault As %DynamicObject, ByRef pViolations) [ Private ]
{
    If '$IsObject($Get(pFault)) || (pFault.%GetTypeOf("detail") '= "object") Quit
    Set tRows = pFault.%Get("detail").%Get("violations")
    If '$IsObject(tRows) Quit
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tFamily = $Piece(tRow.%Get("code"), ".", 1)
        If (tFamily '= "DATABASE") && (tFamily '= "PATH") Continue
        Set pViolations($Increment(pViolations)) = $ListBuild(tRow.%Get("field"), tRow.%Get("code"))
    }
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make to <var>pName</var>
/// carrying <var>pPayload</var> and <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an error
/// status with a 403 fault.</p>
ClassMethod Prohibited(pToolClass As %String, pName As %String, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pName, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), pDiff.%ToJSON(), .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Issue tool <var>pToolClass</var>'s own write for <var>pName</var> with <var>pPayload</var>, its
/// derived fields added and its port query set, through <method>PortClass</method>;
/// <var>pWritten</var> is the port's answer. A tool that sends no body (AD-51), such as the size grow,
/// is sent none, as its confirm is: the port builds that body from the query.</p>
ClassMethod Send(pToolClass As %String, pName As %String, pPayload As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pWritten) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery($ClassMethod(pToolClass, "IdParam")) = pName
    Do $ClassMethod(pToolClass, "PortQuery", pPayload, .tQuery)
    Set tBody = ""
    If ##class(OcuPilot.Kernel.Proposal.Operation).SendsBody(pToolClass) {
        Do $ClassMethod(pToolClass, "DerivedFields", pPayload)
        Set tBody = pPayload
    }
    Quit $ClassMethod(..PortClass(), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "WriteType"), .tQuery, tBody, .pWritten, .pHttpStatus, .pFault)
}

/// <p>Render the outcome: the violations as one 422 envelope, a refusal as its own envelope, and
/// success as <code>{name}</code> at <var>pSuccess</var> with <var>pReadBack</var> as
/// <code>readBack</code> (AD-58). <var>pApplied</var>, where not empty, names the groups an edit had
/// already written, carried in the refusal's <code>detail.applied</code>.</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pName As %String, pReadBack As %DynamicObject = "", pApplied As %DynamicArray = "") As %Status [ Private ]
{
    Set tApplied = $IsObject(pApplied) && (pApplied.%Size() > 0)
    If $Get(pViolations) > 0 {
        Set tDetail = {}
        Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
        If tApplied Do tDetail.%Set("applied", pApplied)
        Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.DatabaseError).#REASONVALIDATION, ##class(OcuPilot.Api.DatabaseError).#VALIDATION, tDetail)
    }
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Set tDetail = pFault.%Get("detail")
        If tApplied {
            If '$IsObject(tDetail) Set tDetail = {}
            Do tDetail.%Set("applied", pApplied)
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, tDetail)
    }
    Set tAnswer = {}
    Do tAnswer.%Set("name", pName, "string")
    If $IsObject(pReadBack) Do tAnswer.%Set("readBack", pReadBack)
    Quit ##class(OcuPilot.Api.Response).JSONStatus(pSuccess, tAnswer)
}

/// <p>The tool that writes group <var>pGroup</var>, or <code>""</code>.</p>
ClassMethod ToolOf(pGroup As %String) As %String
{
    For tI = 1:1:$Length(..#GROUPS, ",") {
        Set tEntry = $Piece(..#GROUPS, ",", tI)
        If $Piece(tEntry, ":", 1) = pGroup Quit
        Set tEntry = ""
    }
    Quit $Piece($Get(tEntry), ":", 2)
}

/// <p>The 400 <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter> fault for key
/// <var>pKey</var>.</p>
ClassMethod Unexpected(pKey As %String) As %DynamicObject [ Private ]
{
    Set tFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push({"field": (pKey), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)})
    Do tFault.%Set("detail", tDetail)
    Quit tFault
}

/// <p>Render <method>Unexpected</method>'s fault for <var>pKey</var>.</p>
ClassMethod RenderUnexpected(pKey As %String) As %Status [ Private ]
{
    Set tFault = ..Unexpected(pKey)
    Quit ##class(OcuPilot.Api.Error).Render(400, tFault.error, tFault.reason, tFault.code, tFault.%Get("detail"))
}

/// <p>Read the request body into <var>pBody</var>; 0 when it is not a JSON object.</p>
ClassMethod Body(Output pBody As %DynamicObject) As %Boolean [ Private ]
{
    Set pBody = ""
    Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.pBody, .tStage)
    If $$$ISERR(tReadSC) || '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Quit 1
}

/// <p>The caller's own body fields, minus the identifying argument, as one
/// <class>%DynamicObject</class>: what AD-10's set is asked about on a create.</p>
ClassMethod CallerFields(pArgs As %DynamicObject) As %DynamicObject
{
    Set tFields = {}
    If '$IsObject(pArgs) Quit tFields
    Set tIterator = pArgs.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If tKey = ..#IDARGUMENT Continue
        Set tType = pArgs.%GetTypeOf(tKey)
        If (tType = "object") || (tType = "array") {
            Do tFields.%Set(tKey, pArgs.%Get(tKey))
        } Else {
            Do tFields.%Set(tKey, pArgs.%Get(tKey), tType)
        }
    }
    Quit tFields
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs (AD-8)
/// or, with a tool class in <var>pWriteTool</var>, every pair that tool's write declares -- its
/// <code>PrivilegePairs</code> and, for the arguments <var>pArgs</var>, its <code>ArgumentPairs</code>
/// -- before anything is read or sent: <var>pRefused</var> 1 means the envelope is written and the
/// handler writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean, pWriteTool As %String = "", pArgs As %DynamicObject = "") As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    If pWriteTool = "" Quit $$$OK
    Set tPairs = $ClassMethod(pWriteTool, "PrivilegePairs", "", .tResolved)
    Set tArgumentPairs = $ClassMethod(pWriteTool, "ArgumentPairs", "", $Select($IsObject(pArgs): pArgs, 1: {}), .tArgumentsResolved)
    If 'tResolved || 'tArgumentsResolved {
        Set pRefused = 1
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the privilege pairs of " _ pWriteTool _ " could not be read")))
    }
    For tI = 1:1:$ListLength(tArgumentPairs) {
        If '$ListFind(tPairs, $List(tArgumentPairs, tI)) Set tPairs = tPairs _ $ListBuild($List(tArgumentPairs, tI))
    }
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs(tPairs, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
