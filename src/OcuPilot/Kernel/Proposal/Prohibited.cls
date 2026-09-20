/// <p>AD-10's prohibited set, and its one home. What Release 1 refuses is declared here, as
/// predicates evaluated against the <b>resolved target as the instance holds it now</b>, and is
/// reached only through <method>OcuPilot.Kernel.Proposal.Write.ProhibitedClass</method>.</p>
/// <p><b>Effect, not verb.</b> A predicate compares the stored payload against a fresh read of the
/// target, so it answers "what would this write do", never "what did the caller ask for". AD-4
/// makes the payload the complete property set, so every field named below is present in every
/// web-application payload whether or not it changes; firing on presence would refuse every write.
/// Hardening is therefore available and weakening is not: adding the unauthenticated bit is
/// refused, removing it is not; clearing a resource is refused, setting one is not.</p>
/// <p><b>Refused whatever the caller.</b> This class reads no governance state, no policy and no
/// switch, so governance can disable a permitted tool and can never enable a prohibited one. It is
/// asked inside the confirm transition, before the port call (AD-34, AD-40).</p>
/// <p><b>It fails closed.</b> A target reference it cannot parse, an entity type it holds no
/// predicates for, and a covered type whose dispatch is missing are all
/// <parameter>UNCOVERED</parameter>. A target the port cannot read is an error status, which the
/// confirm renders 500 and no write follows. Only a target the instance no longer holds is "not
/// prohibited": that is the fingerprint gate's refusal a few lines later, not this one's.</p>
/// <p><b>The two fields whose every change is prohibited are absent from the tool set as well</b>
/// (<method>AlwaysProhibitedFields</method>). A write tool excludes them by name so the model
/// cannot author them; this class refuses them at the write so no other route can either.</p>
/// <p>Seams a subclass overrides: <method>PortClass</method> and <method>RegistryClass</method>.
/// Production overrides neither.</p>
Class OcuPilot.Kernel.Proposal.Prohibited Extends %RegisteredObject
{

/// <p>The write would let the target be reached without authenticating: the payload adds the
/// unauthenticated bit (<parameter>UNAUTHENTICATEDBIT</parameter>) the target does not carry.</p>
Parameter UNAUTHENTICATED = "PROHIBITED.UNAUTHENTICATED";

/// <p>The write would drop the target's authorization resource: the target names one and the
/// payload names none.</p>
Parameter AUTHORIZATION = "PROHIBITED.AUTHORIZATION";

/// <p>The write would change which compiled code answers at the target's URL.</p>
Parameter DISPATCH = "PROHIBITED.DISPATCH";

/// <p>The write would change the roles the target grants, which is a privilege grant through a
/// path (AD-10).</p>
Parameter PRIVILEGEGRANT = "PROHIBITED.PRIVILEGEGRANT";

/// <p>The write would leave a web application that serves OcuPilot itself disabled.</p>
Parameter SERVINGPATH = "PROHIBITED.SERVINGPATH";

/// <p>The target's entity type is one this release evaluates no predicates for, or its reference
/// could not be read at all. Refusing wholesale is strictly stronger than the enumerated effects,
/// and it is what keeps a later story's write tool from shipping without its predicates.</p>
Parameter UNCOVERED = "PROHIBITED.UNCOVERED";

/// <p>The entity types this release evaluates predicates for, comma-separated
/// (<class>OcuPilot.Kernel.EntityType</class>'s spelling). A type outside this list is
/// <parameter>UNCOVERED</parameter>.</p>
Parameter COVEREDTYPES = "web-application";

/// <p>The one covered type, named once so the dispatch and the list cannot drift apart.</p>
Parameter TYPEWEBAPPLICATION = "web-application";

/// <p><code>AutheUnauthenticated</code> (<file>irissys/%sySecurityMacros.inc</file>:20). Verified
/// on the instance 2026-09-20: <code>AuthePassword</code> is 32, so a target reading 32 whose
/// payload reads 96 is gaining this bit.</p>
Parameter UNAUTHENTICATEDBIT = 64;

/// <p>The admin request type the target is re-read with (AD-36's single-object <code>GET</code>),
/// the same one the fingerprint re-read uses.</p>
Parameter READTYPE = "GET";

/// <p>Every <code>PROHIBITED.*</code> code this class declares, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#UNAUTHENTICATED, ..#AUTHORIZATION, ..#DISPATCH, ..#PRIVILEGEGRANT, ..#SERVINGPATH, ..#UNCOVERED)
}

/// <p>The written sentence a <code>PROHIBITED.*</code> code carries, or <code>""</code> for any
/// other code (AD-39). <method>OcuPilot.Kernel.Proposal.Write.ReasonFor</method> delegates the
/// family here, so the set still has one home.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#UNAUTHENTICATED Quit "Letting a web application be reached without signing in is not something the agent can propose."
    If pCode = ..#AUTHORIZATION Quit "Removing the resource that guards a web application is not something the agent can propose."
    If pCode = ..#DISPATCH Quit "Changing which code answers at a web application's address is not something the agent can propose."
    If pCode = ..#PRIVILEGEGRANT Quit "Changing the roles a web application grants is not something the agent can propose."
    If pCode = ..#SERVINGPATH Quit "Disabling a web application that serves OcuPilot itself is not something the agent can propose."
    If pCode = ..#UNCOVERED Quit "This release does not check writes to that kind of object against its prohibited set, so none is proposable yet."
    Quit ""
}

/// <p><parameter>COVEREDTYPES</parameter> as a <class>%List</class>.</p>
ClassMethod CoveredTypes() As %List
{
    Set tList = ""
    For tI = 1:1:$Length(..#COVEREDTYPES, ",") {
        Set tValue = $Piece(..#COVEREDTYPES, ",", tI)
        If tValue '= "" Set tList = tList _ $ListBuild(tValue)
    }
    Quit tList
}

/// <p>The payload field names of entity type <var>pType</var> whose <b>every</b> change is
/// prohibited, as a <class>%List</class>; <code>""</code> for a type with none.</p>
/// <p>These are the names AD-10's title is about: a write tool must not advertise them, because a
/// field no change to is permitted is a field the model has no use for. The tool states its own
/// exclusion, and a test asserts the two agree -- the tool layer never reads the kernel.</p>
ClassMethod AlwaysProhibitedFields(pType As %String) As %List
{
    If pType = ..#TYPEWEBAPPLICATION Quit $ListBuild("MatchRoles", "DispatchClass")
    Quit ""
}

/// <p>The port the target is read through. Overridable so a fixture can answer a known object;
/// production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>The tool registry the target's endpoint and identifying parameter are resolved through, and
/// the only name this class holds outside the kernel. The kernel may read the registry; the
/// registry never reads the kernel. Overridable for the reason <method>PortClass</method> is.</p>
ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Screen.Tool.Registry"
}

/// <p>Whether the write that <var>pToolName</var> proposed against <var>pTargetRef</var>, carrying
/// the stored payload <var>pPayload</var>, is prohibited -- in <var>pProhibits</var>, with the
/// refusing code in <var>pCode</var>.</p>
/// <p><b>Caller contract:</b> the three arguments are the stored row's, never the request's, and
/// this is called inside the confirm transition before the port call. An error status means the
/// question could not be answered and the caller must not write: <var>pProhibits</var> is 0 and
/// <var>pCode</var> is <code>""</code> on that path, so a caller that reads them without checking
/// the status is refused by its own <code>$$$ISERR</code> rather than by a false negative.</p>
ClassMethod Prohibits(pToolName As %String, pTargetRef As %String, pPayload As %String, Output pProhibits As %Boolean, Output pCode As %String) As %Status
{
    Set pProhibits = 0
    Set pCode = ""
    Set tSC = $$$OK
    Try {
        Set tParseSC = ##class(OcuPilot.Kernel.EntityRef).Parse(pTargetRef, .tType, .tScope, .tId)
        If $$$ISERR(tParseSC) || '$ListFind(..CoveredTypes(), tType) {
            Do ..Refuse(..#UNCOVERED, .pProhibits, .pCode)
            Quit
        }
        If tType '= ..#TYPEWEBAPPLICATION {
            ; A type COVEREDTYPES lists and no branch evaluates. Fail closed rather than write.
            Do ..Refuse(..#UNCOVERED, .pProhibits, .pCode)
            Quit
        }

        ; AD-9: the escalated state read runs to completion before the port is entered. Its frame
        ; has unwound by the time Target() calls the port, so the two are never nested.
        Set tSC = ..ServesOcuPilot(tId, .tServes)
        If $$$ISERR(tSC) Quit

        Set tSC = ..Target(pToolName, tId, .tTarget, .tPresent)
        If $$$ISERR(tSC) Quit
        ; A target the instance no longer holds is not prohibited: the fingerprint re-read refuses
        ; it TARGETCHANGED a few lines later and closes the row, which is the answer the user sees.
        If 'tPresent Quit

        Set tSC = ..WebApplication(..ParsedObject(pPayload), tTarget, tServes, .pProhibits, .pCode)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) {
        Set pProhibits = 0
        Set pCode = ""
    }
    Quit tSC
}

/// <p>The registered write tools whose entity type this class evaluates no predicates for, as a
/// <class>%List</class> of tool names.</p>
/// <p>It is empty in Release 1 and a test asserts so, which is what stops a write tool registering
/// over a type <parameter>COVEREDTYPES</parameter> does not list. It reads that list alone: a type
/// added to the list with no predicate branch passes this gate and is refused
/// <parameter>UNCOVERED</parameter> at every write instead. A registry that cannot be read is an
/// error, never an empty list: an empty list is the passing answer.</p>
ClassMethod UncoveredWriteTools(Output pTools As %List) As %Status
{
    Set pTools = ""
    Set tSC = $$$OK
    Try {
        Set tSC = $ClassMethod(..RegistryClass(), "ListTools", .tAll)
        If $$$ISERR(tSC) Quit
        Set tCovered = ..CoveredTypes()
        Set tIterator = tAll.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If '$IsObject(tEntry) Continue
            If tEntry.%Get("kind") '= "write" Continue
            Set tType = ""
            Set tDescriptor = $Parameter(tEntry.%Get("class"), "DESCRIPTORCLASS")
            If tDescriptor '= "" Set tType = $ClassMethod(tDescriptor, "PrimaryEntityType")
            If '$ListFind(tCovered, tType) Set pTools = pTools _ $ListBuild(tEntry.%Get("name"))
        }
    } Catch ex {
        Set pTools = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The web-application predicates, in declared order, first hit wins: the unauthenticated bit,
/// the dropped resource, the repointed dispatch, the changed roles, and OcuPilot's own serving
/// path.</p>
/// <p><var>pServes</var> is whether the target is one of OcuPilot's own applications, already
/// resolved by <method>ServesOcuPilot</method> so no escalated read happens here.</p>
ClassMethod WebApplication(pPayload As %DynamicObject, pTarget As %DynamicObject, pServes As %Boolean, Output pProhibits As %Boolean, Output pCode As %String) As %Status [ Private ]
{
    Set pProhibits = 0
    Set pCode = ""
    Set tSC = $$$OK
    Try {
        If ..Unauthenticated(..Rendered(pPayload, "AutheEnabled")) && '..Unauthenticated(..Rendered(pTarget, "AutheEnabled")) {
            Do ..Refuse(..#UNAUTHENTICATED, .pProhibits, .pCode)
            Quit
        }
        If (..Rendered(pTarget, "Resource") '= "") && (..Rendered(pPayload, "Resource") = "") {
            Do ..Refuse(..#AUTHORIZATION, .pProhibits, .pCode)
            Quit
        }
        If ..Rendered(pPayload, "DispatchClass") '= ..Rendered(pTarget, "DispatchClass") {
            Do ..Refuse(..#DISPATCH, .pProhibits, .pCode)
            Quit
        }
        If ..Rendered(pPayload, "MatchRoles") '= ..Rendered(pTarget, "MatchRoles") {
            Do ..Refuse(..#PRIVILEGEGRANT, .pProhibits, .pCode)
            Quit
        }
        ; Stronger than "would disable it": a payload that leaves one of OcuPilot's own paths not
        ; enabled is refused whatever the target reads now, because a write that leaves OcuPilot
        ; unreachable is not one the agent proposes even as a no-op.
        If pServes && '..Enabled(..Rendered(pPayload, "Enabled")) {
            Do ..Refuse(..#SERVINGPATH, .pProhibits, .pCode)
            Quit
        }
    } Catch ex {
        Set pProhibits = 0
        Set pCode = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The target at <var>pId</var> as <var>pToolName</var>'s own endpoint answers it now, in
/// <var>pTarget</var>, with <var>pPresent</var> 0 for a target the instance no longer holds.</p>
/// <p>The endpoint and the identifying parameter come from the tool the proposal names, through
/// the registry, so this class names no endpoint of its own. A 404 is absence; any other refusal,
/// and a success that carried no object, are error statuses, because a target that could not be
/// read is not a target that was checked.</p>
ClassMethod Target(pToolName As %String, pId As %String, Output pTarget As %DynamicObject, Output pPresent As %Boolean) As %Status [ Private ]
{
    Set pTarget = ""
    Set pPresent = 0
    Set tSC = $$$OK
    Try {
        Set tSC = $ClassMethod(..RegistryClass(), "Resolve", pToolName, .tTool)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tTool) {
            Set tSC = $$$ERROR($$$GeneralError, "the prohibited set was asked about a tool this instance does not carry: '" _ pToolName _ "'")
            Quit
        }
        Set tClass = tTool.%Get("class")
        Set tEndpoint = $ClassMethod(tClass, "Endpoint")
        Set tIdParam = $ClassMethod(tClass, "IdParam")
        If (tEndpoint = "") || (tIdParam = "") || (pId = "") {
            Set tSC = $$$ERROR($$$GeneralError, "the prohibited set could not address the target of '" _ pToolName _ "'")
            Quit
        }
        Kill tQuery
        Set tQuery(tIdParam) = pId
        Set tReadSC = $ClassMethod(..PortClass(), "Invoke", tEndpoint, ..#READTYPE, .tQuery, "", .tFresh, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            If +$Get(tHttp) = 404 Quit
            Set tSC = tReadSC
            Quit
        }
        If '$IsObject(tFresh) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set tSC = $$$ERROR($$$GeneralError, "the prohibited set read the target of '" _ pToolName _ "' and was answered no object")
            Quit
        }
        Set pTarget = tFresh
        Set pPresent = 1
    } Catch ex {
        Set pTarget = ""
        Set pPresent = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the web application at <var>pPath</var> is one OcuPilot is served by, in
/// <var>pServes</var>: a path <class>OcuPilot.Install.Roster</class> declares, or one
/// <class>OcuPilot.Kernel.State.WebApp</class> recorded at install -- the production applications
/// and a probe profile's alike.</p>
/// <p>A roster that cannot be read is an error, never an empty declaration: an empty one would
/// make every OcuPilot path writable.</p>
ClassMethod ServesOcuPilot(pPath As %String, Output pServes As %Boolean) As %Status [ Private ]
{
    Set pServes = 0
    Set tSC = $$$OK
    Try {
        Set tKeys = ##class(OcuPilot.Install.Roster).Keys()
        If tKeys = "" {
            Set tSC = $$$ERROR($$$GeneralError, "the install roster's application keys could not be read, so which paths serve OcuPilot is unknown")
            Quit
        }
        For tI = 1:1:$Length(tKeys, ",") {
            Set tSC = ##class(OcuPilot.Install.Roster).Application($Piece(tKeys, ",", tI), .tApp)
            If $$$ISERR(tSC) Quit
            If $IsObject(tApp) && (tApp.path = pPath) Set pServes = 1
        }
        If $$$ISERR(tSC) Quit
        If pServes Quit
        Set tSC = ##class(OcuPilot.Kernel.State.WebApp).GuardedForPath(pPath, .tRow)
        If $$$ISERR(tSC) Quit
        If $IsObject(tRow) Set pServes = 1
        Set tRow = ""
    } Catch ex {
        Set pServes = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><var>pObject</var>'s member <var>pName</var> in the rendered form the diff and the
/// fingerprint compare values in (<method>OcuPilot.Kernel.Proposal.Mint.Display</method>), or
/// <code>""</code> when it carries none. One comparison, so a predicate and the diff the user read
/// cannot disagree about whether a value changed.</p>
ClassMethod Rendered(pObject As %DynamicObject, pName As %String) As %String [ Private ]
{
    If '$IsObject(pObject) Quit ""
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Display(pObject.%Get(pName), pObject.%GetTypeOf(pName))
}

/// <p>Whether a rendered <code>AutheEnabled</code> carries
/// <parameter>UNAUTHENTICATEDBIT</parameter>. A value that is not a number carries no bit.</p>
ClassMethod Unauthenticated(pAutheEnabled As %String) As %Boolean [ Private ]
{
    If '$IsValidNum(pAutheEnabled) Quit 0
    Quit ((pAutheEnabled \ ..#UNAUTHENTICATEDBIT) # 2) = 1
}

/// <p>Whether a rendered <code>Enabled</code> says the application is on. Anything else -- the
/// empty string a payload with no such member renders as among them -- is not on.</p>
ClassMethod Enabled(pEnabled As %String) As %Boolean [ Private ]
{
    Quit (pEnabled = "true") || (pEnabled = "1")
}

/// <p><var>pText</var> parsed as a JSON object, or <code>{}</code> when it is empty or
/// unreadable. Such a payload carries no members, so every predicate compares an absent value
/// against the target: a target holding any of them reads the write as a change and refuses it,
/// and a target holding none of them is left to the fingerprint gate behind the set.</p>
ClassMethod ParsedObject(pText As %String) As %DynamicObject [ Private ]
{
    Set tObject = {}
    Try {
        If pText = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pText)
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicObject") Set tObject = tParsed
    } Catch {
        Set tObject = {}
    }
    Quit tObject
}

/// <p>Record the refusal <var>pCode</var> for the caller. A refusal is a successful answer to the
/// question, never an error status: the confirm renders it 403.</p>
ClassMethod Refuse(pCode As %String, Output pProhibits As %Boolean, Output pOutCode As %String) [ Private ]
{
    Set pProhibits = 1
    Set pOutCode = pCode
}

}
