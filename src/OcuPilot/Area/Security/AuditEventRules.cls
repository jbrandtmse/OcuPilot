/// <p>The user audit event editor's rules (AD-39, AD-55): the one rule set
/// <class>OcuPilot.Area.Security.AuditEventSave</class>'s Save and the audit event tools'
/// <code>ArgumentProblem</code> apply (<method>Validate</method>, <method>ArgumentViolations</method>),
/// the ownership rule every audit event tool applies (<method>OwnerProblem</method>), and the
/// editor's form read (<method>HandleForm</method>).</p>
/// <p><b>The rules are the vendor's, measured on this build</b>, checked before any port call so a
/// refusal is OcuPilot's sentence on the field: each of Source, Type and Name is required, at most
/// 64 characters and free of <code>/</code>; a Source or Type beginning with <code>%</code> is
/// reserved for the instance's own events, while a Name beginning with <code>%</code> is accepted;
/// a Description is at most 256 characters.</p>
/// <p><b>A system event is one whose Source begins with <code>%</code></b>, which is how the
/// vendor's two event lists split. Every sentence is
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s.</p>
Class OcuPilot.Area.Security.AuditEventRules Extends %RegisteredObject
{

/// <p>The tools the editor's two Saves resolve their writes through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.AuditUserEventCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.AuditUserEventUpdate";

/// <p>The screen whose declared pairs gate the routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuditUserEventList";

/// <p>The <code>MAXLEN</code> of <class>Security.Events</class>'s Source, Type and Name
/// (measured: 65 characters answer #7201).</p>
Parameter PARTMAXLENGTH As INTEGER = 64;

/// <p>The longest Description the vendor stores (measured: 257 characters answer 500).</p>
Parameter DESCRIPTIONMAXLENGTH As INTEGER = 256;

/// <p>The first character of a system event's Source, and of a reserved Source or Type.</p>
Parameter SYSTEMPREFIX = "%";

/// <p>The three identity parts, in <code>Source/Type/Name</code> order.</p>
Parameter PARTS = "Source,Type,Name";

/// <p>The agent's single identifying argument.</p>
Parameter EVENTNAMEFIELD = "EventName";

Parameter DESCRIPTIONFIELD = "Description";

/// <p>The list an audit event tool administers: <code>system</code> or <code>user</code>, read
/// from the tool's own <code>EVENTOWNER</code> parameter.</p>
Parameter OWNERSYSTEM = "system";

Parameter OWNERUSER = "user";

/// <p>Whether <var>pEventName</var> names a system event: its Source, and so the name itself,
/// begins with <parameter>SYSTEMPREFIX</parameter>.</p>
ClassMethod IsSystemEvent(pEventName As %String) As %Boolean
{
    Quit $Extract(pEventName) = ..#SYSTEMPREFIX
}

/// <p>The ownership refusal of audit event tool <var>pTool</var> (a class name) acting on
/// <var>pEventName</var>: <code>AUDITEVENT.SYSTEM</code> when a user tool is given a system event,
/// <code>AUDITEVENT.USER</code> when a system tool is given a user event, otherwise
/// <code>""</code>. A class that declares no <code>EVENTOWNER</code> answers <code>""</code>.</p>
ClassMethod OwnerProblem(pTool As %String, pEventName As %String) As %String
{
    Set tOwner = ""
    Try {
        Set tOwner = $Parameter(pTool, "EVENTOWNER")
    } Catch {
        Set tOwner = ""
    }
    Set tSystem = ..IsSystemEvent(pEventName)
    If (tOwner = ..#OWNERUSER) && tSystem Quit ##class(OcuPilot.Api.Error).#AUDITEVENTSYSTEM
    If (tOwner = ..#OWNERSYSTEM) && 'tSystem Quit ##class(OcuPilot.Api.Error).#AUDITEVENTUSER
    Quit ""
}

/// <p><method>OwnerProblem</method> as the one-line problem a tool's <code>ArgumentProblem</code>
/// or <code>ScreenActionDelta</code> answers, or <code>""</code>.</p>
ClassMethod OwnerRefusal(pTool As %String, pEventName As %String) As %String
{
    Set tCode = ..OwnerProblem(pTool, pEventName)
    If tCode = "" Quit ""
    Kill tViolations
    Set tViolations = 1
    Set tViolations(1) = $ListBuild(..#EVENTNAMEFIELD, tCode)
    Quit ..ProblemText(.tViolations)
}

/// <p>Split <var>pEventName</var> into its three parts, answering 0 when it is not exactly three
/// <code>/</code>-separated pieces. An empty piece is split, not refused: the part rules name it.</p>
ClassMethod Split(pEventName As %String, Output pSource As %String, Output pType As %String, Output pName As %String) As %Boolean
{
    Set pSource = ""
    Set pType = ""
    Set pName = ""
    If $Length(pEventName, "/") '= 3 Quit 0
    Set pSource = $Piece(pEventName, "/", 1)
    Set pType = $Piece(pEventName, "/", 2)
    Set pName = $Piece(pEventName, "/", 3)
    Quit 1
}

/// <p>Every rule over <var>pArgs</var>, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>. With <var>pIdentity</var> the three parts <code>Source</code>,
/// <code>Type</code> and <code>Name</code> are required and checked; without it only the
/// Description is, when present.</p>
ClassMethod Validate(pArgs As %DynamicObject, pIdentity As %Boolean, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pArgs) Set pArgs = {}
        If pIdentity {
            For tI = 1:1:$Length(..#PARTS, ",") {
                Set tField = $Piece(..#PARTS, ",", tI)
                Set tValue = ""
                If pArgs.%GetTypeOf(tField) = "string" Set tValue = pArgs.%Get(tField)
                Set tCode = ..PartViolation(tField, tValue)
                If tCode '= "" Do ..Add(.pViolations, tField, tCode)
            }
        }
        Set tType = pArgs.%GetTypeOf(..#DESCRIPTIONFIELD)
        If tType = "string" {
            If $Length(pArgs.%Get(..#DESCRIPTIONFIELD)) > ..#DESCRIPTIONMAXLENGTH Do ..Add(.pViolations, ..#DESCRIPTIONFIELD, ##class(OcuPilot.Api.Error).#AUDITEVENTDESCRIPTIONLENGTH)
        } ElseIf tType '= "unassigned" {
            Do ..Add(.pViolations, ..#DESCRIPTIONFIELD, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        Set tType = pArgs.%GetTypeOf("Enabled")
        If (tType '= "unassigned") && (tType '= "boolean") Do ..Add(.pViolations, "Enabled", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
    } Catch ex {
        Kill pViolations
        Set pViolations = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The code part <var>pField</var> (Source, Type or Name) breaks with <var>pValue</var>, or
/// <code>""</code>: required, at most <parameter>PARTMAXLENGTH</parameter> characters, no
/// <code>/</code>, and, for a Source or Type, not beginning with
/// <parameter>SYSTEMPREFIX</parameter>.</p>
ClassMethod PartViolation(pField As %String, pValue As %String) As %String
{
    If pValue = "" Quit ##class(OcuPilot.Api.Error).#AUDITEVENTPARTREQUIRED
    If $Length(pValue) > ..#PARTMAXLENGTH Quit ##class(OcuPilot.Api.Error).#AUDITEVENTPARTLENGTH
    If pValue [ "/" Quit ##class(OcuPilot.Api.Error).#AUDITEVENTPARTSLASH
    If (pField '= "Name") && ($Extract(pValue) = ..#SYSTEMPREFIX) Quit ##class(OcuPilot.Api.Error).#AUDITEVENTPARTRESERVED
    Quit ""
}

/// <p>The agent's arguments <var>pArgs</var> for the event <var>pEventName</var> under the rules, in
/// <var>pViolations</var>: with <var>pIdentity</var>, a name that is not three
/// <code>/</code>-separated parts is <code>AUDITEVENT.EVENTNAME.SHAPE</code> and each part is held to
/// its own rules; the Description is checked whenever it is sent.</p>
ClassMethod ArgumentViolations(pEventName As %String, pArgs As %DynamicObject, pIdentity As %Boolean, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tChecked = {}
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#DESCRIPTIONFIELD) '= "unassigned") Do tChecked.%Set(..#DESCRIPTIONFIELD, pArgs.%Get(..#DESCRIPTIONFIELD), pArgs.%GetTypeOf(..#DESCRIPTIONFIELD))
    If pIdentity {
        If '..Split(pEventName, .tSource, .tType, .tName) {
            Do ..Add(.pViolations, ..#EVENTNAMEFIELD, ##class(OcuPilot.Api.Error).#AUDITEVENTEVENTNAMESHAPE)
            Set pIdentity = 0
        } Else {
            Do tChecked.%Set("Source", tSource, "string")
            Do tChecked.%Set("Type", tType, "string")
            Do tChecked.%Set("Name", tName, "string")
        }
    }
    Set tSC = ..Validate(tChecked, pIdentity, .tMore)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tMore) Set pViolations($Increment(pViolations)) = tMore(tI)
    Quit $$$OK
}

/// <p><var>pViolations</var> as one problem naming each field and its published sentence, the shape
/// a tool's <code>ArgumentProblem</code> answers.</p>
ClassMethod ProblemText(ByRef pViolations) As %String
{
    Set tProblem = ""
    For tI = 1:1:$Get(pViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(pViolations(tI), 2))
        Set tProblem = tProblem _ $Select(tProblem = "": "", 1: " ") _ "'" _ $List(pViolations(tI), 1) _ "': " _ tReason
    }
    Quit tProblem
}

/// <p>Answer <code>GET /audit-events/form</code>: with no <code>event</code>,
/// <code>{maxLengths}</code>; with one, <code>{event: {Source, Type, Name, Description, Enabled},
/// maxLengths}</code> from a fresh read through the update tool's own port (AD-52). A system event
/// is refused 422 <code>AUDITEVENT.SYSTEM</code>, and one the instance does not hold 404
/// <code>AUDITEVENT.ABSENT</code>.</p>
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
        Set tLengths = {}
        For tI = 1:1:$Length(..#PARTS, ",") Do tLengths.%Set($Piece(..#PARTS, ",", tI), ..#PARTMAXLENGTH, "number")
        Do tLengths.%Set(..#DESCRIPTIONFIELD, ..#DESCRIPTIONMAXLENGTH, "number")
        Set tEventName = $Get(%request.Data("event", 1))
        If tEventName '= "" {
            Set tCode = ..OwnerProblem(..#UPDATETOOL, tEventName)
            If tCode '= "" {
                Set tSC = ..RenderCode(422, tCode)
                Quit
            }
            Set tReadSC = ..Present(tEventName, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, tHttp, tFault)
                Quit
            }
            Do ..Split(tEventName, .tSource, .tType, .tName)
            Set tEvent = {}
            Do tEvent.%Set("Source", tSource, "string")
            Do tEvent.%Set("Type", tType, "string")
            Do tEvent.%Set("Name", tName, "string")
            Set tDescription = tFresh.%Get(..#DESCRIPTIONFIELD)
            If tDescription = $Char(0) Set tDescription = ""
            Do tEvent.%Set(..#DESCRIPTIONFIELD, tDescription, "string")
            Do tEvent.%Set("Enabled", ''tFresh.%Get("Enabled"), "boolean")
            Do tBody.%Set("event", tEvent)
        }
        Do tBody.%Set("maxLengths", tLengths)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The event <var>pEventName</var>, read through the update tool's own port, endpoint and read
/// type (AD-52), in <var>pFresh</var>. An event the instance does not hold is an error status with
/// <var>pHttpStatus</var> 404.</p>
ClassMethod Present(pEventName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pFresh = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Set tClass = ..#UPDATETOOL
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pEventName
        Set tSC = $ClassMethod($ClassMethod(tClass, "PortClass"), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    } Catch ex {
        Set pFresh = ""
        Set tSC = ex.AsStatus()
    }
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#AUDITEVENTABSENT)
    }
    Quit tSC
}

/// <p>Render a failed read: a 404 as <code>AUDITEVENT.ABSENT</code>, any other refusal as the port's
/// own envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 Quit ..RenderCode(404, ##class(OcuPilot.Api.Error).#AUDITEVENTABSENT)
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Render the one refusal <var>pCode</var> at <var>pHttpStatus</var>, its published sentence as
/// the envelope's reason and as its one violation on <code>EventName</code>.</p>
ClassMethod RenderCode(pHttpStatus As %Integer, pCode As %String) As %Status
{
    Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(pCode)
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push({"field": (..#EVENTNAMEFIELD), "code": (pCode), "reason": (tReason)})
    Quit ##class(OcuPilot.Api.Error).Render(pHttpStatus, $Select(pHttpStatus = 404: ##class(OcuPilot.Api.Error).#NOTFOUND, 1: ##class(OcuPilot.Api.Error).#VALIDATIONFAILED), tReason, pCode, tDetail)
}

/// <p>Refuse a caller who does not hold the list's declared pairs, or the pair the tools' writes
/// declare beyond them (AD-8), before anything is read or sent: <var>pRefused</var> 1 means the
/// envelope is written.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    Set tPair = $ListBuild($Parameter(..#UPDATETOOL, "WRITERESOURCE"), $Parameter(..#UPDATETOOL, "WRITEPERMISSION"))
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs($ListBuild(tPair), .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
