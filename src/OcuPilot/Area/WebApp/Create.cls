/// <p>The screen's half of a web-application create (AD-55), over <code>POST /web-applications</code>.
/// The agent's half is the same tool class read by <class>OcuPilot.Kernel.Proposal.Mint</class> and
/// <class>OcuPilot.Kernel.Proposal.Confirm</class>, and its mint applies <method>Validate</method>'s
/// rules through <method>OcuPilot.Screen.Tool.WebAppCreate.ArgumentProblem</method>.</p>
/// <p><b>It resolves everything about the write from the tool class</b>
/// (<class>OcuPilot.Screen.Tool.WebAppCreate</class>): the endpoint, the request type, the port,
/// the settable field list and the derived fields. Nothing here names an endpoint, a field or a
/// port of its own -- a screen path that composed its own payload would be a second source for
/// exactly what AD-5 and AD-3 exist to keep single, and it is also how a prohibited action becomes
/// reachable from the UI while staying refused for the agent, which would make AD-10's "refused on
/// the instance, whatever the caller" false.</p>
/// <p><b>The screen mints no proposal and takes no confirm token</b>, and that is the whole of what
/// it skips. AD-6's confirmation exists because a <i>model</i> proposed the change, and a person
/// pressing Save has already confirmed it; every gate AD-10 and AD-40 place "at the write" still
/// applies, in the same order the confirm applies them -- the caller's own pairs (AD-8), then
/// AD-10's prohibited set, then the port.</p>
/// <p><b>A name already taken is refused here rather than left to the vendor.</b>
/// <code>%Api.Admin.Endpoints.WebApp.App:RunPut</code> is an upsert with no refusal path, so a Save
/// against a name somebody took would rewrite their application and answer 200. The agent's path
/// is protected by AD-54's absence fingerprint; the screen's is protected by this read.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither, and nothing in the tree
/// subclasses this yet. They cover the write alone: the name look-up
/// <method>Validate</method> makes goes through
/// <method>OcuPilot.Area.WebApp.FormRules.Taken</method>, which resolves the tool's own port
/// directly, so a subclass that overrode <method>PortClass</method> would still read the instance
/// to answer whether the name is free.</p>
Class OcuPilot.Area.WebApp.Create Extends %RegisteredObject
{

/// <p>The tool class both callers resolve the write through (AD-55).</p>
Parameter TOOLCLASS = "OcuPilot.Screen.Tool.WebAppCreate";

/// <p>The form screen whose declared pairs gate this route (AD-8). The form's set is the list's
/// own, so the route and the screen cannot require different things.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WebAppForm";

/// <p>The input property that names the target, which is the vendor's <code>name</code> query
/// parameter and never a body field.</p>
Parameter IDARGUMENT = "Name";

/// <p>The body fields a type's own rules turn on, named once.</p>
Parameter FIELDDISPATCH = "DispatchClass";

Parameter FIELDWSGINAME = "WSGIAppName";

Parameter FIELDWSGILOCATION = "WSGIAppLocation";

Parameter FIELDWSGITYPE = "WSGIType";

Parameter FIELDWSGICALLABLE = "WSGICallable";

/// <p>The authentication mask field, always sent explicitly (AD-54's create list).</p>
Parameter FIELDAUTHE = "AutheEnabled";

/// <p>The namespace field the vendor requires on a create and on no other request.</p>
Parameter FIELDNAMESPACE = "NameSpace";

/// <p>The application-roles field: an array of <code>{MatchRole, TargetRoles}</code> entries
/// (<parameter>OcuPilot.Screen.Tool.WebAppCreate.MATCHROLESARGUMENT</parameter>).</p>
Parameter FIELDMATCHROLES = "MatchRoles";

/// <p>The characters a web application's name may not carry. <code>%2F</code> and <code>%00</code>
/// are refused by the web server before IRIS sees them (AD-13), so a name holding a percent sign
/// or a space is one no route could address afterwards.</p>
Parameter NAMEFORBIDDEN = " %";

ClassMethod ToolClass() As %String
{
    Quit ..#TOOLCLASS
}

/// <p>The port the write goes through, which is the tool's own declaration (AD-52). Overridable so
/// a fixture can observe what was sent; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#TOOLCLASS, "PortClass")
}

/// <p>AD-10's set, asked before the port is touched. Overridable for the reason
/// <method>PortClass</method> is; production never overrides it.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>Answer <code>POST /web-applications</code>: create one web application from the body and
/// answer the application the instance then holds, with <code>readBack</code> the application read
/// back and compared with what was sent (AD-58).</p>
/// <p>In order, and the order is AD-55's: the caller's own pairs; the body is read; the rules
/// this release applies are evaluated and answered as one
/// <parameter>OcuPilot.Api.Error.WEBAPPVALIDATION</parameter> envelope carrying every violation;
/// the payload is composed from the tool's settable fields; AD-10's prohibited set is asked; the
/// tool's derived fields are applied; and only then is the port invoked. A vendor refusal reaches
/// the caller as the port's own normalized envelope, with
/// <code>detail.violations</code> where the vendor named a field (AD-39).</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) || '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }

        Set tName = ""
        If tBody.%GetTypeOf(..#IDARGUMENT) = "string" Set tName = tBody.%Get(..#IDARGUMENT)
        Set tPerformSC = ..Perform(tName, tBody, .tCreated, .tHttp, .tFault, .tViolations, .tReadBack)
        If $Get(tViolations) > 0 {
            Set tSC = ..RenderViolations(.tViolations)
            Quit
        }
        If $$$ISERR(tPerformSC) {
            If '$IsObject($Get(tFault)) || (tFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tPerformSC))
                Quit
            }
            Set tSC = ##class(OcuPilot.Api.Error).Render($Select(+$Get(tHttp): +tHttp, 1: 500), tFault.error, tFault.reason, tFault.code, tFault.%Get("detail"))
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("name", tName, "string")
        Do tAnswer.%Set("application", $Select($IsObject($Get(tCreated)): tCreated, 1: {}))
        If $IsObject($Get(tReadBack)) Do tAnswer.%Set("readBack", tReadBack)
        Set tSC = ##class(OcuPilot.Api.Response).JSONStatus(201, tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Create the web application <var>pName</var> from <var>pArgs</var>, and answer the
/// application the instance then holds in <var>pCreated</var>.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the rule-violation array
/// (<code>pViolations(n) = $ListBuild(field, code)</code>, count in <code>pViolations</code>) and a
/// non-zero count means nothing was written and the other outputs say nothing. Otherwise an error
/// status carries <var>pHttpStatus</var> and <var>pFault</var> from the port, and success carries
/// the created application and, in <var>pReadBack</var>, the write's read-back (AD-58).</p>
/// <p>It is the screen's half of AD-55. The agent's half is the same tool class read by
/// <class>OcuPilot.Kernel.Proposal.Mint</class> and <class>OcuPilot.Kernel.Proposal.Confirm</class>,
/// so the two compose one payload from one field list and pass one prohibited set.</p>
ClassMethod Perform(pName As %String, pArgs As %DynamicObject, Output pCreated As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pCreated = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        ; The name alone first, because everything below addresses a target by it: a name that is
        ; not a path this instance can serve cannot be made into a reference, and a refusal about
        ; its shape is one the caller can act on without any of the rest running.
        Do ..NameViolation(pName, .pViolations)
        If pViolations > 0 Quit

        Set tClass = ..#TOOLCLASS
        Set tComposeSC = ##class(OcuPilot.Kernel.Proposal.Mint).Compose(pArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tComposeSC) {
            Set tSC = tComposeSC
            Quit
        }
        If tProblem '= "" {
            Do ..Add(.pViolations, ..#IDARGUMENT, ##class(OcuPilot.Api.Error).#WEBAPPNAMESHAPE)
            Quit
        }

        ; AD-10, AD-55. The same set the confirm asks, asked here before anything else and before
        ; the port is touched -- so a prohibited create is refused whatever the caller, and is
        ; refused on the prohibition rather than on whichever field rule happened to run first.
        ;
        ; **The payload it is asked about is the CALLER's own fields, not the composed body.**
        ; Compose keeps only what the tool admits, so a body carrying a field it does not admit
        ; would reach the vendor with that key silently dropped -- a 201 for a request AD-10 says is
        ; refused. The agent cannot author such a key at all (its schema is closed), so this is the
        ; screen path's own half of "refused on the instance, whatever the caller".
        Set tRefSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pName, .tTargetRef)
        If $$$ISERR(tRefSC) {
            Set tSC = tRefSC
            Quit
        }
        Set tProhibitSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(tClass, "TOOLNAME"), tTargetRef, ..CallerFields(pArgs).%ToJSON(), tDiff.%ToJSON(), .tProhibits, .tProhibitCode)
        If $$$ISERR(tProhibitSC) {
            Set tSC = tProhibitSC
            Quit
        }
        If tProhibits {
            Set pHttpStatus = 403
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tProhibitCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tProhibitCode))
            Set tSC = $$$ERROR($$$GeneralError, tProhibitCode)
            Quit
        }

        Set tSC = ..Validate(pName, pArgs, .pViolations)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        ; AD-55: the derivation lives on the tool, so the screen and the confirm send one body.
        Do $ClassMethod(tClass, "DerivedFields", tPayload)

        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .pCreated, .pHttpStatus, .pFault)
        ; AD-58: the application read back through the tool's port and compared with what was sent.
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, pName, tPayload, "", ..PortClass(), $Get(pCreated), pHttpStatus)
    } Catch ex {
        Set pCreated = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every rule this release applies to a create, in <var>pViolations</var> (AD-39): one entry
/// per broken rule, so a submission that breaks four earns one response naming four fields.</p>
/// <p><b>Every sentence behind these codes is authored once</b> in
/// <class>OcuPilot.Api.Error</class>, beside the envelope reasons, and
/// <class>OcuPilot.Area.WebApp.FormRules</class> serves the same sentences to the form so an
/// inline blur refusal and a failed Save are one wording (DW-376).</p>
/// <p>The type-dependent rules read the body rather than a control: a dispatch class makes a REST
/// application, the three WSGI fields make a WSGI or ASGI one, and an application that names
/// neither is a CSP application, which is what the vendor's own hard-coded
/// <code>Type = $$$AppTypeCSP</code> makes every one of them at the class level anyway.</p>
/// <p><var>pCheckTaken</var> 0 skips the name look-up, for a caller that has already read the
/// target's absence (the agent's mint, through
/// <method>OcuPilot.Screen.Tool.WebAppCreate.ArgumentProblem</method>).</p>
/// <p><var>pMode</var> <code>update</code> is an edit's rules (<method>UpdateViolations</method>):
/// <var>pArgs</var> is the fields the edit changes (<method>Changed</method>) and <var>pFresh</var>
/// the application as the edit tool's read answered it. Both callers of an edit apply it -- the
/// editor's Save and the agent's mint (<method>OcuPilot.Screen.Tool.WebAppUpdate.ArgumentProblem</method>).</p>
ClassMethod Validate(pName As %String, pArgs As %DynamicObject, Output pViolations, pCheckTaken As %Boolean = 1, pMode As %String = "create", pFresh As %DynamicObject = "") As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    If pMode = "update" Quit ..UpdateViolations(pArgs, pFresh, .pViolations)
    Try {
        Do ..NameViolation(pName, .pViolations)
        If (pViolations = 0) && pCheckTaken {
            Set tTakenSC = ##class(OcuPilot.Area.WebApp.FormRules).Taken(pName, .tTaken)
            If $$$ISERR(tTakenSC) {
                Set tSC = tTakenSC
                Quit
            }
            If tTaken Do ..Add(.pViolations, ..#IDARGUMENT, ##class(OcuPilot.Api.Error).#WEBAPPNAMETAKEN)
        }

        If ..Text(pArgs, ..#FIELDNAMESPACE) = "" Do ..Add(.pViolations, ..#FIELDNAMESPACE, ##class(OcuPilot.Api.Error).#WEBAPPNAMESPACEREQUIRED)

        ; AD-54's create list sends AutheEnabled explicitly, because the property's own
        ; InitialExpression is 64 (Unauthenticated) and an omitted value would create an
        ; application anybody can reach without signing in.
        Set tAuthe = ..Text(pArgs, ..#FIELDAUTHE)
        If '..IsMask(tAuthe) {
            Do ..Add(.pViolations, ..#FIELDAUTHE, ##class(OcuPilot.Api.Error).#WEBAPPAUTHEREQUIRED)
        } ElseIf ..OutsideMask(+tAuthe) {
            Do ..Add(.pViolations, ..#FIELDAUTHE, ##class(OcuPilot.Api.Error).#WEBAPPAUTHEUNKNOWN)
        }

        ; The type a create asks for is read off the body's own shape rather than from a control
        ; the agent has no access to: three fields make a Python application, a dispatch class
        ; makes a REST one, and a body naming neither is the CSP application the vendor's
        ; hard-coded Type = $$$AppTypeCSP makes every one of them at the class level anyway. A
        ; body naming both is a contradiction and is refused rather than resolved.
        Set tWsgiName = ..Text(pArgs, ..#FIELDWSGINAME)
        Set tWsgiLocation = ..Text(pArgs, ..#FIELDWSGILOCATION)
        Set tWsgiType = ..Text(pArgs, ..#FIELDWSGITYPE)
        Set tIsWsgi = ((tWsgiName '= "") || (tWsgiLocation '= "") || (tWsgiType '= "") || (..Text(pArgs, ..#FIELDWSGICALLABLE) '= ""))
        If tIsWsgi {
            If tWsgiName = "" Do ..Add(.pViolations, ..#FIELDWSGINAME, ##class(OcuPilot.Api.Error).#WEBAPPWSGIAPPNAME)
            ; AD-21: the location is one directory name resolved under the fixed WSGI root, never a
            ; path; OcuPilot.Area.WebApp.Location is the one resolver both callers pass.
            If tWsgiLocation = "" {
                Do ..Add(.pViolations, ..#FIELDWSGILOCATION, ##class(OcuPilot.Api.Error).#WEBAPPWSGILOCATION)
            } ElseIf '##class(OcuPilot.Area.WebApp.Location).Resolve(tWsgiLocation, .tResolvedLocation) {
                Do ..Add(.pViolations, ..#FIELDWSGILOCATION, ##class(OcuPilot.Api.Error).#WEBAPPWSGIAPPLOCATIONSHAPE)
            }
            If '..IsWsgiType(tWsgiType) Do ..Add(.pViolations, ..#FIELDWSGITYPE, ##class(OcuPilot.Api.Error).#WEBAPPWSGITYPE)
            If ..Text(pArgs, ..#FIELDDISPATCH) '= "" Do ..Add(.pViolations, ..#FIELDDISPATCH, ##class(OcuPilot.Api.Error).#WEBAPPTYPECONFLICT)
        } ElseIf (pArgs.%GetTypeOf(..#FIELDDISPATCH) = "string") && (..Text(pArgs, ..#FIELDDISPATCH) = "") {
            ; A body that carries the dispatch class at all asks for a REST application, and one
            ; carrying it empty would be created as a CSP one.
            Do ..Add(.pViolations, ..#FIELDDISPATCH, ##class(OcuPilot.Api.Error).#WEBAPPDISPATCHREQUIRED)
        }

        Set tSC = ..MatchRolesViolation(pArgs, .pViolations)
        If $$$ISERR(tSC) Quit

        Do ..AddLengthViolations(pArgs, .pViolations)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The fields the edit a caller sent actually changes: every member of <var>pArgs</var> but the
/// identifying <var>pIdArgument</var> whose rendered value differs from <var>pFresh</var>'s (a member
/// <var>pFresh</var> does not carry counts as changed). An edit that restates what the application
/// holds is judged on nothing.</p>
ClassMethod Changed(pArgs As %DynamicObject, pFresh As %DynamicObject, pIdArgument As %String = {..#IDARGUMENT}) As %DynamicObject
{
    Set tChanged = {}
    If '$IsObject(pArgs) Quit tChanged
    Set tIterator = pArgs.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If tKey = pIdArgument Continue
        Set tType = pArgs.%GetTypeOf(tKey)
        If $IsObject(pFresh) && (pFresh.%GetTypeOf(tKey) '= "unassigned") {
            Set tBefore = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tKey), pFresh.%GetTypeOf(tKey))
            If ##class(OcuPilot.Kernel.Proposal.Mint).Display(tValue, tType) = tBefore Continue
        }
        If (tType = "object") || (tType = "array") {
            Do tChanged.%Set(tKey, tValue)
        } Else {
            Do tChanged.%Set(tKey, tValue, tType)
        }
    }
    Quit tChanged
}

/// <p>An edit's rules (AD-39), each broken one added to <var>pViolations</var>: <var>pChanged</var>
/// is the fields the edit changes and <var>pFresh</var> the application before it.</p>
/// <p>Over the changed fields: the namespace is not empty; each text field no longer than this
/// instance stores (<method>AddLengthViolations</method>); each flag a boolean, each timeout a whole
/// number of 0 or more, the file-serving setting one of
/// <parameter>OcuPilot.Area.WebApp.FormRules.SERVEFILESCHOICES</parameter>, the Python protocol one of
/// its two, each CORS list a list of strings and each text field a scalar
/// (<parameter>OcuPilot.Api.Error.PORTFIELDSHAPE</parameter> unless a code of its own applies); a
/// changed authentication mask a whole number above zero that adds no bit the instance does not
/// offer; and the application roles' shape and names (<method>MatchRolesViolation</method>).</p>
/// <p>Over the merged application -- <var>pFresh</var> with the changes applied -- the type-shape
/// rules: an application naming a Python application file or directory is a Python one, which
/// needs its file, its directory as the instance holds it, its protocol, and no dispatch class.
/// Its directory is the instance's and never changes here (AD-21).</p>
ClassMethod UpdateViolations(pChanged As %DynamicObject, pFresh As %DynamicObject, Output pViolations) As %Status [ Private ]
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pChanged) Set pChanged = {}
        Set tMerged = $Select($IsObject(pFresh): ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON()), 1: {})
        Set tIterator = pChanged.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tType = pChanged.%GetTypeOf(tKey)
            If (tType = "object") || (tType = "array") {
                Do tMerged.%Set(tKey, tValue)
            } Else {
                Do tMerged.%Set(tKey, tValue, tType)
            }
        }

        For tField = "Description", "DispatchClass", "GroupById", "NameSpace", "Package", "Resource", "SuperClass", "WSGIAppName", "WSGICallable", "WSGIType", "ServeFiles" {
            Set tType = pChanged.%GetTypeOf(tField)
            If (tType = "object") || (tType = "array") Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        If (pChanged.%GetTypeOf(..#FIELDNAMESPACE) '= "unassigned") && (..Text(tMerged, ..#FIELDNAMESPACE) = "") {
            Do ..Add(.pViolations, ..#FIELDNAMESPACE, ##class(OcuPilot.Api.Error).#WEBAPPNAMESPACEREQUIRED)
        }

        If pChanged.%GetTypeOf(..#FIELDAUTHE) '= "unassigned" {
            Set tAuthe = ..Text(pChanged, ..#FIELDAUTHE)
            If '..IsMask(tAuthe) {
                Do ..Add(.pViolations, ..#FIELDAUTHE, ##class(OcuPilot.Api.Error).#WEBAPPAUTHEREQUIRED)
            } Else {
                Set tBefore = ..Text(pFresh, ..#FIELDAUTHE)
                Set tBefore = $Select(..IsMask(tBefore): tBefore \ 1, 1: 0)
                Set tAdded = $ZBoolean(tAuthe \ 1, tBefore, 2)
                If ..OutsideMask(tAdded) && (tAdded '= 0) Do ..Add(.pViolations, ..#FIELDAUTHE, ##class(OcuPilot.Api.Error).#WEBAPPAUTHEUNKNOWN)
            }
        }

        For tField = "AutoCompile", "CorsCredentialsAllowed", "Enabled", "IsNameSpaceDefault", "JWTAuthEnabled", "LockCSPName", "Recurse" {
            Set tType = pChanged.%GetTypeOf(tField)
            If tType = "unassigned" Continue
            Set tValue = pChanged.%Get(tField)
            If (tType = "boolean") || ((tType '= "object") && (tType '= "array") && ((tValue = "true") || (tValue = "false") || (tValue = "0") || (tValue = "1"))) Continue
            Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        For tField = "Timeout", "ServeFilesTimeout", "JWTAccessTokenTimeout", "JWTRefreshTokenTimeout" {
            Set tType = pChanged.%GetTypeOf(tField)
            If tType = "unassigned" Continue
            Set tValue = ..Text(pChanged, tField)
            If ((tType = "number") || (tType = "string")) && $IsValidNum(tValue) && (+tValue = (tValue \ 1)) && (+tValue >= 0) Continue
            Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        ; A choice-valued setting is one of its display strings; any other scalar -- a number, a
        ; boolean, null -- is refused here rather than coerced by the merge. Objects and arrays were
        ; refused above.
        Set tType = pChanged.%GetTypeOf("ServeFiles")
        If '$ListFind($ListBuild("unassigned", "object", "array"), tType) && ((tType '= "string") || '$ListFind($ListFromString(##class(OcuPilot.Area.WebApp.FormRules).#SERVEFILESCHOICES), pChanged.%Get("ServeFiles"))) {
            Do ..Add(.pViolations, "ServeFiles", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        Set tType = pChanged.%GetTypeOf(..#FIELDWSGITYPE)
        If '$ListFind($ListBuild("unassigned", "object", "array"), tType) && ((tType '= "string") || '..IsWsgiType(pChanged.%Get(..#FIELDWSGITYPE))) {
            Do ..Add(.pViolations, ..#FIELDWSGITYPE, ##class(OcuPilot.Api.Error).#WEBAPPWSGITYPE)
        }
        For tField = "CorsAllowlist", "CorsHeadersList" {
            Set tType = pChanged.%GetTypeOf(tField)
            If tType = "unassigned" Continue
            Set tShape = (tType '= "array")
            If 'tShape {
                Set tItems = pChanged.%Get(tField).%GetIterator()
                While tItems.%GetNext(.tIndex, .tItem, .tItemType) {
                    If tItemType '= "string" Set tShape = 1 Quit
                }
            }
            If tShape Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }

        ; The type-shape rules read the merged application: the file or the directory makes a
        ; Python application, whatever the edit changed.
        Set tWsgiName = ..Text(tMerged, ..#FIELDWSGINAME)
        Set tWsgiLocation = ..Text(tMerged, ..#FIELDWSGILOCATION)
        If (tWsgiName '= "") || (tWsgiLocation '= "") {
            If tWsgiName = "" Do ..Add(.pViolations, ..#FIELDWSGINAME, ##class(OcuPilot.Api.Error).#WEBAPPWSGIAPPNAME)
            If tWsgiLocation = "" Do ..Add(.pViolations, ..#FIELDWSGILOCATION, ##class(OcuPilot.Api.Error).#WEBAPPWSGILOCATION)
            If '..IsWsgiType(..Text(tMerged, ..#FIELDWSGITYPE)) && (pChanged.%GetTypeOf(..#FIELDWSGITYPE) = "unassigned") Do ..Add(.pViolations, ..#FIELDWSGITYPE, ##class(OcuPilot.Api.Error).#WEBAPPWSGITYPE)
            If ..Text(tMerged, ..#FIELDDISPATCH) '= "" Do ..Add(.pViolations, ..#FIELDDISPATCH, ##class(OcuPilot.Api.Error).#WEBAPPTYPECONFLICT)
        }

        Set tSC = ..MatchRolesViolation(pChanged, .pViolations)
        If $$$ISERR(tSC) Quit

        Do ..AddLengthViolations(pChanged, .pViolations)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add the application roles' violation to <var>pViolations</var>, or none: a member that is not
/// a list of <code>{MatchRole, TargetRoles}</code> objects -- a string matching role, possibly
/// empty, and a list of role names (<parameter>OcuPilot.Api.Error.WEBAPPMATCHROLESSHAPE</parameter>)
/// -- or one naming a role the instance does not hold
/// (<parameter>OcuPilot.Api.Error.WEBAPPMATCHROLESUNKNOWN</parameter>). An absent member grants no
/// role. Role names are looked up in <code>%SYS</code> by AD-16's explicit save and restore.</p>
ClassMethod MatchRolesViolation(pArgs As %DynamicObject, Output pViolations) As %Status [ Private ]
{
    Set tSC = $$$OK
    If '$IsObject(pArgs) Quit tSC
    Set tType = pArgs.%GetTypeOf(..#FIELDMATCHROLES)
    If tType = "unassigned" Quit tSC
    Set tShape = (tType '= "array")
    Set tNames = ""
    If 'tShape {
        Set tIterator = pArgs.%Get(..#FIELDMATCHROLES).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If '$IsObject(tEntry) || 'tEntry.%IsA("%Library.DynamicObject") Set tShape = 1 Quit
            If tEntry.%GetTypeOf("MatchRole") '= "string" Set tShape = 1 Quit
            If tEntry.%GetTypeOf("TargetRoles") '= "array" Set tShape = 1 Quit
            Set tKeys = tEntry.%GetIterator()
            While tKeys.%GetNext(.tKey, .tIgnored) {
                If (tKey '= "MatchRole") && (tKey '= "TargetRoles") Set tShape = 1
            }
            If tShape Quit
            If tEntry.%Get("MatchRole") '= "" Set tNames = tNames _ $ListBuild(tEntry.%Get("MatchRole"))
            Set tTargets = tEntry.%Get("TargetRoles").%GetIterator()
            While tTargets.%GetNext(.tTargetIndex, .tRole, .tRoleType) {
                If (tRoleType '= "string") || (tRole = "") Set tShape = 1 Quit
                Set tNames = tNames _ $ListBuild(tRole)
            }
            If tShape Quit
        }
    }
    If tShape {
        Do ..Add(.pViolations, ..#FIELDMATCHROLES, ##class(OcuPilot.Api.Error).#WEBAPPMATCHROLESSHAPE)
        Quit tSC
    }
    If tNames = "" Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set tUnknown = 0
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tNames) {
            If '##class(Security.Roles).Exists($List(tNames, tI)) Set tUnknown = 1 Quit
        }
        Set $NAMESPACE = tOrigNS
        If tUnknown Do ..Add(.pViolations, ..#FIELDMATCHROLES, ##class(OcuPilot.Api.Error).#WEBAPPMATCHROLESUNKNOWN)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add the name's own shape violation to <var>pViolations</var>, or none: an absent name, and
/// one that is not a path this instance can serve.</p>
/// <p>It is separate from the rest of <method>Validate</method> because <method>Perform</method>
/// runs it first: every other rule, and the prohibited set, address a target by this name, so a
/// name they cannot be built from is refused before any of them runs.</p>
ClassMethod NameViolation(pName As %String, Output pViolations)
{
    If pName = "" {
        Do ..Add(.pViolations, ..#IDARGUMENT, ##class(OcuPilot.Api.Error).#WEBAPPNAMEREQUIRED)
        Quit
    }
    If '..NameIsUsable(pName) Do ..Add(.pViolations, ..#IDARGUMENT, ##class(OcuPilot.Api.Error).#WEBAPPNAMESHAPE)
}

/// <p>The caller's own body fields, minus the identifying argument, as one
/// <class>%DynamicObject</class> -- what AD-10's set is asked about on the screen path.</p>
/// <p><b>It is not the composed payload</b>, and the difference is the point.
/// <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> keeps only the fields the tool admits,
/// so a body carrying one it does not would reach the vendor with that key silently dropped. The
/// set sees what the caller asked for, which is what makes "refused whatever the caller" true of
/// this route.</p>
ClassMethod CallerFields(pArgs As %DynamicObject) As %DynamicObject [ Private ]
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

/// <p>Add a <parameter>OcuPilot.Api.Error.WEBAPPFIELDLENGTH</parameter> violation for every field
/// whose value is longer than this instance stores, read from the same bounds
/// <method>OcuPilot.Area.WebApp.FormRules.Lengths</method> serves the form.</p>
ClassMethod AddLengthViolations(pArgs As %DynamicObject, Output pViolations) [ Private ]
{
    Set tLengths = ##class(OcuPilot.Area.WebApp.FormRules).Lengths()
    If '$IsObject(tLengths) Quit
    Set tIterator = tLengths.%GetIterator()
    While tIterator.%GetNext(.tField, .tMax) {
        If +tMax = 0 Continue
        Set tValue = ..Text(pArgs, tField)
        If tValue = "" Continue
        If $Length(tValue) > +tMax Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#WEBAPPFIELDLENGTH)
    }
}

/// <p>Whether <var>pValue</var> is an authentication mask at all: a whole number above zero. An
/// empty, absent, fractional or negative value is not, and earns
/// <parameter>OcuPilot.Api.Error.WEBAPPAUTHEREQUIRED</parameter> rather than the unknown-method
/// sentence -- both are true of it, and "choose at least one method" is the one a person can
/// act on.</p>
ClassMethod IsMask(pValue As %String) As %Boolean [ Private ]
{
    If pValue = "" Quit 0
    If '$IsValidNum(pValue) Quit 0
    If +pValue '= (pValue \ 1) Quit 0
    Quit (+pValue > 0)
}

/// <p>Whether <var>pMask</var> carries a bit outside the ones this instance offers
/// (<method>OcuPilot.Area.WebApp.FormRules.Mask</method>). An instance offering nothing puts every
/// mask outside it, which is the fail-closed direction.</p>
ClassMethod OutsideMask(pMask As %Integer) As %Boolean [ Private ]
{
    Set tOffered = ##class(OcuPilot.Area.WebApp.FormRules).Mask()
    If tOffered = 0 Quit 1
    Quit ((pMask \ 1) '= $ZBoolean(pMask \ 1, tOffered, 1))
}

/// <p>Whether <var>pName</var> is a path this instance can serve: it starts with <code>/</code>,
/// is no longer than <parameter>OcuPilot.Area.WebApp.FormRules.NAMEMAXLENGTH</parameter>, and
/// carries none of <parameter>NAMEFORBIDDEN</parameter>.</p>
ClassMethod NameIsUsable(pName As %String) As %Boolean
{
    Set tUsable = 1
    If $Extract(pName, 1) '= "/" Quit 0
    If $Length(pName) > ##class(OcuPilot.Area.WebApp.FormRules).#NAMEMAXLENGTH Quit 0
    For tI = 1:1:$Length(..#NAMEFORBIDDEN) {
        If pName [ $Extract(..#NAMEFORBIDDEN, tI) Set tUsable = 0 Quit
    }
    Quit tUsable
}

/// <p>Whether <var>pType</var> is one of the two display strings
/// <property>Security.Applications.WSGIType</property> publishes.</p>
ClassMethod IsWsgiType(pType As %String) As %Boolean [ Private ]
{
    Set tTypes = $ListFromString($Parameter("OcuPilot.Area.WebApp.FormRules", "WSGITYPES"))
    Quit ''$ListFind(tTypes, pType)
}

/// <p><var>pArgs</var>'s member <var>pName</var> as the rules read it: a string or a number
/// verbatim, a boolean as <code>true</code>/<code>false</code>, and anything else
/// <code>""</code>.</p>
ClassMethod Text(pArgs As %DynamicObject, pName As %String) As %String [ Private ]
{
    If '$IsObject(pArgs) Quit ""
    Set tType = pArgs.%GetTypeOf(pName)
    If (tType = "unassigned") || (tType = "null") Quit ""
    If (tType = "object") || (tType = "array") Quit ""
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Display(pArgs.%Get(pName), tType)
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

/// <p>Render one <code>(field, code)</code> violation as the 422 envelope
/// <method>RenderViolations</method> writes, for a caller that has exactly one to report.</p>
ClassMethod RenderOne(pField As %String, pCode As %String) As %Status
{
    Kill tViolations
    Set tViolations = 0
    Do ..Add(.tViolations, pField, pCode)
    Quit ..RenderViolations(.tViolations)
}

/// <p>Render <var>pViolations</var> as one 422 envelope carrying every broken rule in
/// <code>detail.violations</code>, each a <code>{field, code, reason}</code> object (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONWEBAPPVALIDATION, ##class(OcuPilot.Api.Error).#WEBAPPVALIDATION, tDetail)
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs
/// (AD-8), by rendering the one privilege envelope
/// <method>OcuPilot.Kernel.Denial.Envelope</method> writes.</p>
/// <p><b>Caller contract:</b> <var>pRefused</var> 1 means the envelope has been written and the
/// handler writes nothing else; the returned status is the render's, which is <code>$$$OK</code>
/// on a refusal as on a pass, so it cannot be the signal.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
