/// <p>The impact of a removal (AD-8, AD-53): what else depends on a role or a resource about to be
/// deleted, what a user actually loses when a role is taken from them, what a namespace delete
/// takes with it and leaves, and what uses a database about to be deleted. Both callers of the four write tools share it: the agent's mint records it on the proposal row, and the screen's
/// dialog asks <class>OcuPilot.Api.ScreenImpact</class> for it when it opens.</p>
/// <p><b>Names only.</b> The answer is
/// <code>{kind, refused, parts: [{part, count, names, unchecked}]}</code>: counts, at most
/// <parameter>NAMESSHOWN</parameter> names per part in name order, the pair a caller lacks, and a
/// refusal's code and sentence. It never enters screen context or a tool result (AD-24).</p>
/// <p><b>Refused before counted</b> (AD-10). The prohibited set is asked first, with the write's
/// own tool, target, payload and diff; a removal it refuses answers that refusal and no parts. The
/// write-time check is unchanged and stays the verdict (AD-40).</p>
/// <p><b>Every part is read as the caller</b> (AD-8, AD-29), through the declared read or port call
/// of the screen that owns the data, after that screen's own pair gate
/// (<method>OcuPilot.Screen.Gate.RequiredPairs</method>). A part whose pair the caller lacks is never
/// read and answers <code>unchecked</code> naming the pair; a read cut at its cap answers
/// <code>unchecked</code> <parameter>TRUNCATED</parameter>. Nothing reads <code>%SYS</code> directly.</p>
Class OcuPilot.Kernel.Proposal.Impact Extends %RegisteredObject
{

Parameter ROLEDELETETOOL = "permissions.roles.delete";

Parameter RESOURCEDELETETOOL = "permissions.resources.delete";

Parameter USERUPDATETOOL = "permissions.users.update";

Parameter NAMESPACEDELETETOOL = "osmgmt.namespaces.delete";

Parameter DATABASEDELETETOOL = "osmgmt.localdatabases.delete";

Parameter KINDROLEDELETE = "role-delete";

Parameter KINDRESOURCEDELETE = "resource-delete";

Parameter KINDROLEREMOVAL = "role-removal";

Parameter KINDNAMESPACEDELETE = "namespace-delete";

Parameter KINDDATABASEDELETE = "database-delete";

Parameter PARTHOLDERS = "holders";

Parameter PARTGRANTINGAPPLICATIONS = "grantingApplications";

Parameter PARTGRANTINGROLES = "grantingRoles";

Parameter PARTGUARDEDAPPLICATIONS = "guardedApplications";

Parameter PARTGUARDEDDATABASES = "guardedDatabases";

Parameter PARTLOSES = "loses";

Parameter PARTBOUNDAPPLICATIONS = "boundApplications";

Parameter PARTDATABASES = "databases";

/// <p>A database delete's three parts (Story 18.3): the namespaces that use the database, the web
/// applications that run in them, and the other configuration names that share its file.</p>
Parameter PARTNAMESPACES = "namespaces";

Parameter PARTAPPLICATIONS = "applications";

Parameter PARTSHAREDFILE = "sharedFile";

/// <p>The fresh read's database fields a namespace delete's <parameter>PARTDATABASES</parameter> is
/// named from, comma-separated.</p>
Parameter NAMESPACEDATABASEFIELDS = "Globals,Routines,TempGlobals";

/// <p>How many names a part carries.</p>
Parameter NAMESSHOWN As INTEGER = 3;

/// <p>A part's <code>unchecked</code> when its read was cut at its cap.</p>
Parameter TRUNCATED = "truncated";

Parameter ROLEDESCRIPTOR = "OcuPilot.Screen.Descriptor.RoleList";

Parameter WEBAPPDESCRIPTOR = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter DATABASEDESCRIPTOR = "OcuPilot.Screen.Descriptor.DatabaseList";

Parameter NAMESPACEDESCRIPTOR = "OcuPilot.Screen.Descriptor.NamespaceList";

/// <p>The three mapping lists a database delete's namespaces part reads, each with its one
/// <code>namespace</code> criterion.</p>
Parameter MAPPINGDESCRIPTORS = "OcuPilot.Screen.Descriptor.GlobalMappingList,OcuPilot.Screen.Descriptor.RoutineMappingList,OcuPilot.Screen.Descriptor.PackageMappingList";

Parameter LOCALDATABASEDESCRIPTOR = "OcuPilot.Screen.Descriptor.LocalDatabaseList";

/// <p>A namespace's database fields a database delete's namespaces part matches, comma-separated.</p>
Parameter NAMESPACEUSEFIELDS = "Globals,Routines,TempGlobals";

Parameter ROLEENDPOINT = "Security.Role";

/// <p>The role endpoint's request type that lists a role's direct holders.</p>
Parameter OWNERTYPE = "OWNERLIST";

/// <p>The prefix of every holder type that is an account (<code>User</code>,
/// <code>User (escalation)</code>).</p>
Parameter HOLDERTYPEPREFIX = "User";

Parameter WEBAPPENDPOINT = "WebApp.App";

Parameter IDPARAM = "name";

/// <p>The user field a role removal is read from; an account's escalation roles are never read.</p>
Parameter ROLESFIELD = "Roles";

Parameter LOGSUBSYSTEM = "proposal";

/// <p>The port every part's own call goes through.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>AD-10's prohibited set, the one the write path asks.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>The impact of the write <var>pToolName</var> would make to <var>pTargetRef</var>, carrying
/// <var>pPayloadJson</var> and <var>pDiffJson</var> over the fresh read <var>pFreshJson</var>, or
/// <code>""</code> for a write that removes nothing this class covers: a role delete, a resource
/// delete, a namespace delete, and a user update whose <code>Roles</code> lacks a role the fresh read
/// held.</p>
/// <p><b>Never throws and never fails its caller</b>: a fault anywhere logs one line and answers
/// <code>""</code>, so a mint or a dialog carries no impact rather than a wrong one.</p>
ClassMethod Of(pToolName As %String, pTargetRef As %String, pFreshJson As %String, pPayloadJson As %String, pDiffJson As %String) As %DynamicObject
{
    Set tImpact = ""
    Try {
        Set tFresh = ..Parsed(pFreshJson)
        Set tPayload = ..Parsed(pPayloadJson)
        Set tKind = ..KindOf(pToolName, tFresh, tPayload)
        If tKind = "" Quit
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Parse(pTargetRef, .tType, .tScope, .tId)
        If $$$ISERR(tSC) Quit

        Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", pToolName, pTargetRef, pPayloadJson, pDiffJson, .tProhibits, .tCode)
        If $$$ISERR(tSC) Quit
        Set tAnswer = {}
        Do tAnswer.%Set("kind", tKind, "string")
        Set tParts = []
        If tProhibits {
            Set tRefused = {}
            Do tRefused.%Set("code", tCode, "string")
            Do tRefused.%Set("reason", $ClassMethod(..ProhibitedClass(), "ReasonFor", tCode), "string")
            Do tAnswer.%Set("refused", tRefused)
            Do tAnswer.%Set("parts", tParts)
            Set tImpact = tAnswer
            Quit
        }
        Do tAnswer.%Set("refused", "", "null")

        If tKind = ..#KINDROLEDELETE {
            Set tSC = ..Holders(tId, .tPart)
            If $$$ISERR(tSC) Quit
            Do tParts.%Push(tPart)
            Set tSC = ..GrantingApplications(tId, .tPart)
            If $$$ISERR(tSC) Quit
            Do tParts.%Push(tPart)
        } ElseIf tKind = ..#KINDRESOURCEDELETE {
            Set tSC = ..GrantingRoles(tId, .tPart)
            If $$$ISERR(tSC) Quit
            Do tParts.%Push(tPart)
            Set tSC = ..Guarded(..#WEBAPPDESCRIPTOR, ..#PARTGUARDEDAPPLICATIONS, "Name", tId, .tPart)
            If $$$ISERR(tSC) Quit
            Do tParts.%Push(tPart)
            Set tSC = ..Guarded(..#DATABASEDESCRIPTOR, ..#PARTGUARDEDDATABASES, "Directory", tId, .tPart)
            If $$$ISERR(tSC) Quit
            Do tParts.%Push(tPart)
        } ElseIf tKind = ..#KINDNAMESPACEDELETE {
            Set tSC = ..Guarded(..#WEBAPPDESCRIPTOR, ..#PARTBOUNDAPPLICATIONS, "Name", tId, .tPart, "Namespace")
            If $$$ISERR(tSC) Quit
            Do tParts.%Push(tPart)
            Set tSC = ..Databases(tFresh, .tPart)
            If $$$ISERR(tSC) Quit
            Do tParts.%Push(tPart)
        } ElseIf tKind = ..#KINDDATABASEDELETE {
            Set tSC = ..UsingNamespaces(tId, .tPart, .tUsing)
            If $$$ISERR(tSC) Quit
            Do tParts.%Push(tPart)
            Set tSC = ..RunningIn(tUsing, .tPart)
            If $$$ISERR(tSC) Quit
            Do tParts.%Push(tPart)
            Set tSC = ..SharedFile(tId, tFresh, .tPart)
            If $$$ISERR(tSC) Quit
            Do tParts.%Push(tPart)
        } Else {
            Set tSC = ..Loses(tFresh, tPayload, .tPart)
            If $$$ISERR(tSC) Quit
            Do tParts.%Push(tPart)
        }
        Do tAnswer.%Set("parts", tParts)
        Set tImpact = tAnswer
    } Catch ex {
        Set tImpact = ""
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR($Get(tSC, $$$OK)) {
        Set tImpact = ""
        Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, "the removal's impact could not be computed", tSC, "")
    }
    Quit tImpact
}

/// <p>Which kind of removal <var>pToolName</var> makes, or <code>""</code>: a user update is a
/// role removal only when <var>pPayload</var>'s <parameter>ROLESFIELD</parameter> lacks a role
/// <var>pFresh</var>'s holds, compared without regard to case.</p>
ClassMethod KindOf(pToolName As %String, pFresh As %DynamicObject, pPayload As %DynamicObject) As %String
{
    If pToolName = ..#ROLEDELETETOOL Quit ..#KINDROLEDELETE
    If pToolName = ..#RESOURCEDELETETOOL Quit ..#KINDRESOURCEDELETE
    If pToolName = ..#NAMESPACEDELETETOOL Quit ..#KINDNAMESPACEDELETE
    If pToolName = ..#DATABASEDELETETOOL Quit ..#KINDDATABASEDELETE
    If pToolName '= ..#USERUPDATETOOL Quit ""
    If '$IsObject(pPayload) || (pPayload.%GetTypeOf(..#ROLESFIELD) '= "array") Quit ""
    Kill tSent
    Do ..Keys(pPayload.%Get(..#ROLESFIELD), .tSent)
    Kill tHeld
    Do ..Keys(..Roles(pFresh), .tHeld)
    Set tRemoves = 0
    Set tKey = ""
    For {
        Set tKey = $Order(tHeld(tKey))
        If tKey = "" Quit
        If '$Data(tSent(tKey)) Set tRemoves = 1 Quit
    }
    Quit $Select(tRemoves: ..#KINDROLEREMOVAL, 1: "")
}

/// <p>The role's direct holders that are accounts, escalation holders included, each once
/// (<parameter>OWNERTYPE</parameter>), read under the Roles screen's pairs.</p>
/// <p>The role is named in the spelling the Roles list reports: measured on this build, the owner
/// list matches escalation holders only under the role's own spelling, so the canonical lower-case
/// id would miss them.</p>
ClassMethod Holders(pRole As %String, Output pPart As %DynamicObject) As %Status
{
    Set pPart = ..Part(..#PARTHOLDERS)
    Set tSC = ..ListRows(..#ROLEDESCRIPTOR, pPart, .tRows)
    If $$$ISERR(tSC) || '$IsObject(tRows) Quit tSC
    Set tSpelled = pRole
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && ($ZConvert(tRow.%Get("Name"), "U") = $ZConvert(pRole, "U")) Set tSpelled = tRow.%Get("Name") Quit
    }
    Kill tQuery
    Set tQuery(..#IDPARAM) = tSpelled
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..#ROLEENDPOINT, ..#OWNERTYPE, .tQuery, "", .tList, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    Kill tNames
    If $IsObject($Get(tList)) && tList.%IsA("%Library.DynamicArray") {
        Set tIterator = tList.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            If $Extract(tRow.%Get("Type"), 1, $Length(..#HOLDERTYPEPREFIX)) '= ..#HOLDERTYPEPREFIX Continue
            Do ..Add(.tNames, tRow.%Get("Name"))
        }
    }
    Quit ..Fill(pPart, .tNames)
}

/// <p>The web applications whose <code>MatchRoles</code> grant the role, as an application role or
/// a matching role's target: each Web applications list row's own read, under that screen's
/// pairs.</p>
ClassMethod GrantingApplications(pRole As %String, Output pPart As %DynamicObject) As %Status
{
    Set pPart = ..Part(..#PARTGRANTINGAPPLICATIONS)
    Set tSC = ..ListRows(..#WEBAPPDESCRIPTOR, pPart, .tRows)
    If $$$ISERR(tSC) || '$IsObject(tRows) Quit tSC
    Set tWanted = $ZConvert(pRole, "U")
    Kill tNames
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || (tRow.%Get("Name") = "") Continue
        Kill tQuery
        Set tQuery(..#IDPARAM) = tRow.%Get("Name")
        Set tSC = $ClassMethod(..PortClass(), "Invoke", ..#WEBAPPENDPOINT, "GET", .tQuery, "", .tApp, .tHttp, .tFault)
        If $$$ISERR(tSC) {
            If +$Get(tHttp) = 404 {
                Set tSC = $$$OK
                Continue
            }
            Quit
        }
        If '$IsObject($Get(tApp)) || (tApp.%GetTypeOf("MatchRoles") '= "array") Continue
        Set tGrants = 0
        Set tMatches = tApp.%Get("MatchRoles").%GetIterator()
        While tMatches.%GetNext(.tMatchIndex, .tMatch) {
            If '$IsObject(tMatch) || (tMatch.%GetTypeOf("TargetRoles") '= "array") Continue
            Kill tTargets
            Do ..Keys(tMatch.%Get("TargetRoles"), .tTargets)
            If $Data(tTargets(tWanted)) Set tGrants = 1 Quit
        }
        If tGrants Do ..Add(.tNames, tRow.%Get("Name"))
    }
    If $$$ISERR(tSC) Quit tSC
    Quit ..Fill(pPart, .tNames)
}

/// <p>The roles whose <code>Resources</code> grant the resource: each Roles list row's own read,
/// under that screen's pairs.</p>
ClassMethod GrantingRoles(pResource As %String, Output pPart As %DynamicObject) As %Status
{
    Set pPart = ..Part(..#PARTGRANTINGROLES)
    Set tSC = ..ListRows(..#ROLEDESCRIPTOR, pPart, .tRows)
    If $$$ISERR(tSC) || '$IsObject(tRows) Quit tSC
    Set tWanted = $ZConvert(pResource, "U")
    Kill tNames
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || (tRow.%Get("Name") = "") Continue
        Kill tQuery
        Set tQuery(..#IDPARAM) = tRow.%Get("Name")
        Set tSC = $ClassMethod(..PortClass(), "Invoke", ..#ROLEENDPOINT, "GET", .tQuery, "", .tRole, .tHttp, .tFault)
        If $$$ISERR(tSC) {
            If +$Get(tHttp) = 404 {
                Set tSC = $$$OK
                Continue
            }
            Quit
        }
        If '$IsObject($Get(tRole)) || (tRole.%GetTypeOf("Resources") '= "array") Continue
        Set tGrants = 0
        Set tResources = tRole.%Get("Resources").%GetIterator()
        While tResources.%GetNext(.tResourceIndex, .tGrant) {
            If $IsObject(tGrant) && ($ZConvert(tGrant.%Get("Name"), "U") = tWanted) Set tGrants = 1 Quit
        }
        If tGrants Do ..Add(.tNames, tRow.%Get("Name"))
    }
    If $$$ISERR(tSC) Quit tSC
    Quit ..Fill(pPart, .tNames)
}

/// <p>The rows of <var>pDescriptor</var>'s declared read whose <var>pMatchField</var> is
/// <var>pResource</var>, compared without regard to case, named by their <var>pNameField</var>, under
/// that screen's pairs.</p>
ClassMethod Guarded(pDescriptor As %String, pPartName As %String, pNameField As %String, pResource As %String, Output pPart As %DynamicObject, pMatchField As %String = "Resource") As %Status
{
    Set pPart = ..Part(pPartName)
    Set tSC = ..ListRows(pDescriptor, pPart, .tRows)
    If $$$ISERR(tSC) || '$IsObject(tRows) Quit tSC
    Set tWanted = $ZConvert(pResource, "U")
    Kill tNames
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        If $ZConvert(tRow.%Get(pMatchField), "U") '= tWanted Continue
        Do ..Add(.tNames, tRow.%Get(pNameField))
    }
    Quit ..Fill(pPart, .tNames)
}

/// <p>The databases a namespace names, which its delete leaves in place: the distinct
/// <parameter>NAMESPACEDATABASEFIELDS</parameter> of its fresh read <var>pFresh</var>. Read from the
/// fresh read the write itself needs, so it is never unchecked.</p>
ClassMethod Databases(pFresh As %DynamicObject, Output pPart As %DynamicObject) As %Status
{
    Set pPart = ..Part(..#PARTDATABASES)
    Kill tNames
    If $IsObject(pFresh) {
        For tI = 1:1:$Length(..#NAMESPACEDATABASEFIELDS, ",") {
            Set tField = $Piece(..#NAMESPACEDATABASEFIELDS, ",", tI)
            If pFresh.%GetTypeOf(tField) '= "string" Continue
            Do ..Add(.tNames, pFresh.%Get(tField))
        }
    }
    Quit ..Fill(pPart, .tNames)
}

/// <p>The namespaces that use the database configuration <var>pDatabase</var>, compared without
/// regard to case (Story 18.3): each Namespaces list row whose <parameter>NAMESPACEUSEFIELDS</parameter>
/// names it, and each namespace of that read one of whose global, routine or package mappings
/// (<parameter>MAPPINGDESCRIPTORS</parameter>, criterion <code>namespace</code>) names it as its
/// <code>Database</code>, each list read under its own screen's pairs. A refused or cut list makes the
/// part unchecked. The namespaces found are <var>pUsing</var>, empty when the part is unchecked.</p>
ClassMethod UsingNamespaces(pDatabase As %String, Output pPart As %DynamicObject, Output pUsing As %List) As %Status
{
    Set pUsing = ""
    Set pPart = ..Part(..#PARTNAMESPACES)
    Set tSC = ..ListRows(..#NAMESPACEDESCRIPTOR, pPart, .tRows)
    If $$$ISERR(tSC) || '$IsObject(tRows) Quit tSC
    Set tWanted = $ZConvert(pDatabase, "U")
    Kill tNames
    Set tAll = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || (tRow.%Get("Name") = "") Continue
        Set tAll = tAll _ $ListBuild(tRow.%Get("Name"))
        For tI = 1:1:$Length(..#NAMESPACEUSEFIELDS, ",") {
            If $ZConvert(tRow.%Get($Piece(..#NAMESPACEUSEFIELDS, ",", tI)), "U") = tWanted Do ..Add(.tNames, tRow.%Get("Name"))
        }
    }
    For tI = 1:1:$ListLength(tAll) {
        Set tNamespace = $List(tAll, tI)
        If $Data(tNames($ZConvert(tNamespace, "U"))) Continue
        For tJ = 1:1:$Length(..#MAPPINGDESCRIPTORS, ",") {
            Kill tCriteria
            Set tCriteria("namespace") = tNamespace
            Set tSC = ..ListRows($Piece(..#MAPPINGDESCRIPTORS, ",", tJ), pPart, .tMappings, .tCriteria)
            If $$$ISERR(tSC) || '$IsObject(tMappings) Quit
            Set tMapIterator = tMappings.%GetIterator()
            While tMapIterator.%GetNext(.tMapIndex, .tMapping) {
                If $IsObject(tMapping) && ($ZConvert(tMapping.%Get("Database"), "U") = tWanted) {
                    Do ..Add(.tNames, tNamespace)
                    Quit
                }
            }
            If $Data(tNames($ZConvert(tNamespace, "U"))) Quit
        }
        If $$$ISERR(tSC) || (pPart.%Get("unchecked") '= "") Quit
    }
    If $$$ISERR(tSC) Quit tSC
    If pPart.%Get("unchecked") '= "" Quit $$$OK
    Set tKey = ""
    For {
        Set tKey = $Order(tNames(tKey))
        If tKey = "" Quit
        Set pUsing = pUsing _ $ListBuild(tNames(tKey))
    }
    Quit ..Fill(pPart, .tNames)
}

/// <p>The web applications whose <code>Namespace</code> is one of <var>pNamespaces</var>, compared
/// without regard to case: the Web applications list's own read, under that screen's pairs. None when
/// <var>pNamespaces</var> is empty.</p>
ClassMethod RunningIn(pNamespaces As %List, Output pPart As %DynamicObject) As %Status
{
    Set pPart = ..Part(..#PARTAPPLICATIONS)
    If pNamespaces = "" Quit $$$OK
    Set tSC = ..ListRows(..#WEBAPPDESCRIPTOR, pPart, .tRows)
    If $$$ISERR(tSC) || '$IsObject(tRows) Quit tSC
    Kill tWanted
    For tI = 1:1:$ListLength(pNamespaces) Set tWanted($ZConvert($List(pNamespaces, tI), "U")) = ""
    Kill tNames
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || (tRow.%Get("Namespace") = "") Continue
        If $Data(tWanted($ZConvert(tRow.%Get("Namespace"), "U"))) Do ..Add(.tNames, tRow.%Get("Name"))
    }
    Quit ..Fill(pPart, .tNames)
}

/// <p>The other configuration names whose directory is the directory of <var>pDatabase</var>'s fresh
/// read <var>pFresh</var> (<method>OcuPilot.Port.DatabasePort.SameDirectory</method>): the Local
/// databases list's own read, under that screen's pairs. A delete keeps a shared file.</p>
ClassMethod SharedFile(pDatabase As %String, pFresh As %DynamicObject, Output pPart As %DynamicObject) As %Status
{
    Set pPart = ..Part(..#PARTSHAREDFILE)
    Set tDirectory = ""
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Directory") = "string") Set tDirectory = pFresh.%Get("Directory")
    If tDirectory = "" Quit $$$OK
    Set tSC = ..ListRows(..#LOCALDATABASEDESCRIPTOR, pPart, .tRows)
    If $$$ISERR(tSC) || '$IsObject(tRows) Quit tSC
    Kill tNames
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || (tRow.%Get("Name") = "") Continue
        If $ZConvert(tRow.%Get("Name"), "U") = $ZConvert(pDatabase, "U") Continue
        If ##class(OcuPilot.Port.DatabasePort).SameDirectory(tRow.%Get("Directory"), tDirectory) Do ..Add(.tNames, tRow.%Get("Name"))
    }
    Quit ..Fill(pPart, .tNames)
}

/// <p>What the account loses: <method>OcuPilot.Kernel.Shell.Effective.Loss</method> of its fresh
/// <code>Roles</code> against the sent ones, the public permissions netted out. Its
/// <code>EscalationRoles</code> are never read.</p>
ClassMethod Loses(pFresh As %DynamicObject, pPayload As %DynamicObject, Output pPart As %DynamicObject) As %Status
{
    Set pPart = ..Part(..#PARTLOSES)
    Set tBefore = ..Roles(pFresh)
    Set tAfter = pPayload.%Get(..#ROLESFIELD)
    Set tRoots = []
    Set tIterator = tBefore.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tOne) {
        Do tRoots.%Push(tOne)
    }
    Set tIterator = tAfter.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tOne) {
        Do tRoots.%Push(tOne)
    }
    Set tSC = ##class(OcuPilot.Kernel.Shell.Effective).Read(tRoots, .tRows, .tPublic, .tUnchecked)
    If $$$ISERR(tSC) Quit tSC
    If tUnchecked '= "" Quit ..Unchecked(pPart, tUnchecked)
    Set tLoss = ##class(OcuPilot.Kernel.Shell.Effective).Loss(##class(OcuPilot.Kernel.Shell.Effective).Compose(tBefore, tRows, tPublic), ##class(OcuPilot.Kernel.Shell.Effective).Compose(tAfter, tRows, tPublic), tPublic)
    Do pPart.%Set("count", tLoss.%Size(), "number")
    Set tNames = []
    Set tIterator = tLoss.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        If tNames.%Size() = ..#NAMESSHOWN Quit
        Do tNames.%Push(tName, "string")
    }
    Do pPart.%Set("names", tNames)
    Quit $$$OK
}

/// <p>The rows of <var>pDescriptor</var>'s declared read, after its pair gate, in
/// <var>pRows</var>; <code>""</code> when <var>pPart</var> has been marked unchecked instead.
/// <var>pCriteria</var>, where given, is the read's criteria, keyed by parameter.</p>
ClassMethod ListRows(pDescriptor As %String, pPart As %DynamicObject, Output pRows As %DynamicArray, ByRef pCriteria) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ##class(OcuPilot.Kernel.Shell.Effective).Gate(pDescriptor, .tUnchecked)
    If $$$ISERR(tSC) Quit tSC
    If tUnchecked '= "" Quit ..Unchecked(pPart, tUnchecked)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(pDescriptor, "", .tResult, .tHttp, .tFault, .pCriteria)
    If $$$ISERR(tSC) Quit tSC
    If tResult.%Get("truncated") Quit ..Unchecked(pPart, ..#TRUNCATED)
    Set pRows = tResult.%Get("rows")
    Quit $$$OK
}

/// <p>One part, counted as nothing until filled.</p>
ClassMethod Part(pName As %String) As %DynamicObject [ Private ]
{
    Set tPart = {}
    Do tPart.%Set("part", pName, "string")
    Do tPart.%Set("count", 0, "number")
    Do tPart.%Set("names", [])
    Do tPart.%Set("unchecked", "", "string")
    Quit tPart
}

/// <p>Mark <var>pPart</var> not read, naming why.</p>
ClassMethod Unchecked(pPart As %DynamicObject, pWhy As %String) As %Status [ Private ]
{
    Do pPart.%Set("unchecked", pWhy, "string")
    Quit $$$OK
}

/// <p>Record <var>pName</var> once, keyed by its upper-cased spelling.</p>
ClassMethod Add(ByRef pNames, pName As %String) [ Private ]
{
    If pName = "" Quit
    Set tKey = $ZConvert(pName, "U")
    If '$Data(pNames(tKey)) Set pNames(tKey) = pName
}

/// <p>Set <var>pPart</var>'s count to every name in <var>pNames</var> and its names to the first
/// <parameter>NAMESSHOWN</parameter> in name order.</p>
ClassMethod Fill(pPart As %DynamicObject, ByRef pNames) As %Status [ Private ]
{
    Set tCount = 0
    Set tShown = []
    Set tKey = ""
    For {
        Set tKey = $Order(pNames(tKey))
        If tKey = "" Quit
        Set tCount = tCount + 1
        If tShown.%Size() < ..#NAMESSHOWN Do tShown.%Push(pNames(tKey), "string")
    }
    Do pPart.%Set("count", tCount, "number")
    Do pPart.%Set("names", tShown)
    Quit $$$OK
}

/// <p>The upper-cased strings of <var>pArray</var>, as subscripts of <var>pKeys</var>.</p>
ClassMethod Keys(pArray As %DynamicArray, Output pKeys) [ Private ]
{
    If '$IsObject(pArray) Quit
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tOne) {
        If $IsObject(tOne) || (tOne = "") Continue
        Set pKeys($ZConvert(tOne, "U")) = ""
    }
}

/// <p><var>pUser</var>'s <parameter>ROLESFIELD</parameter>, or an empty array.</p>
ClassMethod Roles(pUser As %DynamicObject) As %DynamicArray [ Private ]
{
    If '$IsObject(pUser) || (pUser.%GetTypeOf(..#ROLESFIELD) '= "array") Quit []
    Quit pUser.%Get(..#ROLESFIELD)
}

/// <p><var>pJson</var> as an object, or <code>""</code>.</p>
ClassMethod Parsed(pJson As %String) As %DynamicObject [ Private ]
{
    Set tObject = ""
    Try {
        If pJson = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pJson)
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicObject") Set tObject = tParsed
    } Catch {
        Set tObject = ""
    }
    Quit tObject
}

}
