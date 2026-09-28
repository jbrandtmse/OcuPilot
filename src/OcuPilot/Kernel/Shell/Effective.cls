/// <p>Effective privilege, composed as the instance composes it (AD-8, measured on
/// <code>ocupilot-ci</code> 2026-09-26): the union over a user's roles and, transitively, every role
/// they grant; <code>%All</code> anywhere in that closure holds everything; a resource's public
/// permission is held by every user; an escalation role counts for nothing until the user
/// escalates, so a caller never passes one in. This class is the one composition, and a later
/// effective-privilege read uses it.</p>
/// <p><method>Compose</method>, <method>Loss</method> and <method>Holds</method> are pure: they read
/// nothing and are driven over literal rows. <method>Read</method> fetches what they need through the
/// Roles and Resources screens' own reads, each after that screen's pair gate, with the caller's own
/// privileges. The impact of a removal (Story 16.19), the user editor's Effective privileges tab and
/// the permission check (Story 16.3) all compose here.</p>
/// <p>Every name is compared without regard to case (inference: IRIS resolves role and resource
/// names that way); an answer keeps the spelling first met.</p>
Class OcuPilot.Kernel.Shell.Effective Extends %RegisteredObject
{

/// <p>The role that holds everything. Its own read answers no resources, so it is recognised by
/// name.</p>
Parameter ALLROLE = "%All";

/// <p>The permission letters, in the order a lost pair spells them.</p>
Parameter LETTERS = "RWU";

/// <p>The screen whose pairs and endpoint a role row is read under.</p>
Parameter ROLEDESCRIPTOR = "OcuPilot.Screen.Descriptor.RoleList";

/// <p>The screen whose declared read answers the public permissions.</p>
Parameter RESOURCEDESCRIPTOR = "OcuPilot.Screen.Descriptor.ResourceList";

Parameter ROLEENDPOINT = "Security.Role";

Parameter ROLEREADTYPE = "GET";

Parameter ROLEIDPARAM = "name";

/// <p>What <method>Read</method>'s <var>pUnchecked</var> reads when a read was cut at its cap.</p>
Parameter TRUNCATED = "truncated";

/// <p>The port the role rows are read through.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>What the role names in <var>pRoles</var> hold together, as
/// <code>{all, allVia, resources, sources, roles}</code>:</p>
/// <ul>
/// <li><code>resources</code>: <code>{&lt;resource&gt;: {&lt;letter&gt;: &lt;role&gt;}}</code>, the role
/// in <var>pRoles</var> whose closure reaches the letter first;</li>
/// <li><code>sources</code>: the same shape, naming the role whose own <code>Resources</code> grant
/// that letter;</li>
/// <li><code>roles</code>: <code>[{name, through}]</code>, every role in the closure in the order it is
/// reached, <code>through</code> naming the role in <var>pRoles</var> it was reached from, or
/// <code>""</code> for a role of <var>pRoles</var> itself.</li>
/// </ul>
/// <p>A letter held only publicly records <code>""</code> in both maps. <var>pRoleRows</var> holds
/// each role's own read (<code>GrantedRoles</code>, <code>Resources[{Name, Permissions}]</code>),
/// keyed by role name; <var>pPublic</var> each resource's public permission letters, keyed by
/// resource name. The closure follows <code>GrantedRoles</code> at every depth and visits each role
/// once. <code>all</code> is true when <parameter>ALLROLE</parameter> is in the closure, and
/// <code>allVia</code> names the role in <var>pRoles</var> it was reached through. A role with no row
/// grants only itself.</p>
ClassMethod Compose(pRoles As %DynamicArray, pRoleRows As %DynamicObject, pPublic As %DynamicObject) As %DynamicObject
{
    Set tOut = {"all": false, "allVia": "", "resources": {}, "sources": {}, "roles": []}
    Kill tRows, tSeen, tQueue, tSpelled
    If $IsObject(pRoleRows) {
        Set tIterator = pRoleRows.%GetIterator()
        While tIterator.%GetNext(.tName, .tRow) {
            If $IsObject(tRow) Set tRows($ZConvert(tName, "U")) = tRow
        }
    }
    Set tTail = 0
    If $IsObject(pRoles) {
        Set tIterator = pRoles.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRole) {
            If $IsObject(tRole) || (tRole = "") Continue
            Set tKey = $ZConvert(tRole, "U")
            If $Data(tSeen(tKey)) Continue
            Set tSeen(tKey) = ""
            Set tTail = tTail + 1
            Set tQueue(tTail) = $ListBuild(tRole, tRole, 1)
        }
    }
    Set tResources = tOut.%Get("resources")
    Set tSources = tOut.%Get("sources")
    Set tClosure = tOut.%Get("roles")
    Set tHead = 0
    While tHead < tTail {
        Set tHead = tHead + 1
        Set tName = $List(tQueue(tHead), 1)
        Set tRoot = $List(tQueue(tHead), 2)
        Set tKey = $ZConvert(tName, "U")
        Set tReached = {}
        Do tReached.%Set("name", tName, "string")
        Do tReached.%Set("through", $Select($List(tQueue(tHead), 3): "", 1: tRoot), "string")
        Do tClosure.%Push(tReached)
        If (tKey = $ZConvert(..#ALLROLE, "U")) && 'tOut.%Get("all") {
            Do tOut.%Set("all", 1, "boolean")
            Do tOut.%Set("allVia", tRoot, "string")
        }
        Set tRow = $Get(tRows(tKey))
        If '$IsObject(tRow) Continue
        If tRow.%GetTypeOf("Resources") = "array" {
            Set tGrants = tRow.%Get("Resources").%GetIterator()
            While tGrants.%GetNext(.tGrantIndex, .tGrant) {
                If '$IsObject(tGrant) Continue
                Do ..Grant(tResources, tSources, .tSpelled, tGrant.%Get("Name"), tGrant.%Get("Permissions"), tRoot, tName)
            }
        }
        If tRow.%GetTypeOf("GrantedRoles") = "array" {
            Set tGranted = tRow.%Get("GrantedRoles").%GetIterator()
            While tGranted.%GetNext(.tGrantedIndex, .tOne) {
                If $IsObject(tOne) || (tOne = "") Continue
                Set tOneKey = $ZConvert(tOne, "U")
                If $Data(tSeen(tOneKey)) Continue
                Set tSeen(tOneKey) = ""
                Set tTail = tTail + 1
                Set tQueue(tTail) = $ListBuild(tOne, tRoot, 0)
            }
        }
    }
    If $IsObject(pPublic) {
        Set tIterator = pPublic.%GetIterator()
        While tIterator.%GetNext(.tResource, .tLetters) {
            If $IsObject(tLetters) Continue
            Do ..Grant(tResources, tSources, .tSpelled, tResource, tLetters, "", "")
        }
    }
    Quit tOut
}

/// <p>What a user holding <var>pBefore</var> loses on holding <var>pAfter</var> instead, both
/// <method>Compose</method> answers, as <code>resource:letters</code> names
/// (<code>%DB_USER:RW</code>): <parameter>ALLROLE</parameter> first when only
/// <var>pBefore</var> holds everything, then every pair <var>pBefore</var> grants that neither
/// <var>pAfter</var> nor <var>pPublic</var> does, by resource name. An <var>pAfter</var> that holds
/// everything loses nothing.</p>
ClassMethod Loss(pBefore As %DynamicObject, pAfter As %DynamicObject, pPublic As %DynamicObject) As %DynamicArray
{
    Set tLoss = []
    If '$IsObject(pBefore) Quit tLoss
    If $IsObject(pAfter) && pAfter.%Get("all") Quit tLoss
    Kill tHeld, tSorted
    If $IsObject(pAfter) Do ..Index(pAfter.%Get("resources"), .tHeld)
    If $IsObject(pPublic) {
        Set tIterator = pPublic.%GetIterator()
        While tIterator.%GetNext(.tResource, .tLetters) {
            If $IsObject(tLetters) Continue
            Set tUpper = $ZConvert(tLetters, "U")
            For tI = 1:1:$Length(tUpper) Set tHeld($ZConvert(tResource, "U"), $Extract(tUpper, tI)) = ""
        }
    }
    If pBefore.%Get("all") Do tLoss.%Push(..#ALLROLE)
    Set tResources = pBefore.%Get("resources")
    If $IsObject(tResources) {
        Set tIterator = tResources.%GetIterator()
        While tIterator.%GetNext(.tResource, .tGranted) {
            If '$IsObject(tGranted) Continue
            Set tKey = $ZConvert(tResource, "U")
            Set tLost = ""
            For tI = 1:1:$Length(..#LETTERS) {
                Set tLetter = $Extract(..#LETTERS, tI)
                If tGranted.%GetTypeOf(tLetter) = "unassigned" Continue
                If $Data(tHeld(tKey, tLetter)) Continue
                Set tLost = tLost _ tLetter
            }
            If tLost '= "" Set tSorted(tKey) = tResource _ ":" _ tLost
        }
    }
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Do tLoss.%Push(tSorted(tKey))
    }
    Quit tLoss
}

/// <p>Whether <var>pComposed</var>, a <method>Compose</method> answer, holds <var>pLetter</var>
/// (<code>R</code>, <code>W</code> or <code>U</code>) on <var>pResource</var>, matched without
/// regard to case, as <code>{held, all, public, grantedBy, root}</code>, filled by the first case
/// that applies:</p>
/// <ul>
/// <li><parameter>ALLROLE</parameter> in the closure: held and <code>all</code>,
/// <code>grantedBy</code> <parameter>ALLROLE</parameter>, <code>root</code> <code>allVia</code>;</li>
/// <li>a role grants the letter: held, <code>grantedBy</code> the <code>sources</code> role,
/// <code>root</code> the <code>resources</code> role;</li>
/// <li>the letter is only public: held and <code>public</code>, both roles <code>""</code>;</li>
/// <li>otherwise not held.</li>
/// </ul>
/// <p>It does not ask whether the resource exists; a caller that must refuse a missing one does so
/// first.</p>
ClassMethod Holds(pComposed As %DynamicObject, pResource As %String, pLetter As %String) As %DynamicObject
{
    Set tOut = {"held": false, "all": false, "public": false, "grantedBy": "", "root": ""}
    If '$IsObject(pComposed) Quit tOut
    If pComposed.%Get("all") {
        Do tOut.%Set("held", 1, "boolean")
        Do tOut.%Set("all", 1, "boolean")
        Do tOut.%Set("grantedBy", ..#ALLROLE, "string")
        Do tOut.%Set("root", pComposed.%Get("allVia"), "string")
        Quit tOut
    }
    Set tLetter = $ZConvert(pLetter, "U")
    Set tWanted = $ZConvert(pResource, "U")
    Set tResources = pComposed.%Get("resources")
    Set tSources = pComposed.%Get("sources")
    If '$IsObject(tResources) Quit tOut
    Set tIterator = tResources.%GetIterator()
    While tIterator.%GetNext(.tResource, .tGranted) {
        If $ZConvert(tResource, "U") '= tWanted Continue
        If '$IsObject(tGranted) || (tGranted.%GetTypeOf(tLetter) = "unassigned") Quit
        Set tRoot = tGranted.%Get(tLetter)
        Set tBy = ""
        If $IsObject(tSources) && $IsObject(tSources.%Get(tResource)) Set tBy = tSources.%Get(tResource).%Get(tLetter)
        Do tOut.%Set("held", 1, "boolean")
        If tRoot = "" {
            Do tOut.%Set("public", 1, "boolean")
            Quit
        }
        Do tOut.%Set("grantedBy", tBy, "string")
        Do tOut.%Set("root", tRoot, "string")
        Quit
    }
    Quit tOut
}

/// <p>Fetch what <method>Compose</method> needs for the roles <var>pRoots</var>, as the caller: each
/// role's own read in <var>pRoleRows</var>, following <code>GrantedRoles</code> once per role, and
/// the public permissions in <var>pPublic</var> from the Resources screen's declared read.</p>
/// <p>Each read answers only after its screen's pair gate: a caller short of a pair gets
/// <var>pUnchecked</var> naming it (<code>resource:permission</code>) and nothing is read. A read cut
/// at its cap gets <parameter>TRUNCATED</parameter>. A role that answers 404 is skipped; any other
/// fault is an error status.</p>
ClassMethod Read(pRoots As %DynamicArray, Output pRoleRows As %DynamicObject, Output pPublic As %DynamicObject, Output pUnchecked As %String) As %Status
{
    Set pRoleRows = {}
    Set pPublic = {}
    Set pUnchecked = ""
    Set tSC = $$$OK
    Try {
        Set tSC = ..Gate(..#ROLEDESCRIPTOR, .pUnchecked)
        If $$$ISERR(tSC) || (pUnchecked '= "") Quit
        Set tSC = ..Gate(..#RESOURCEDESCRIPTOR, .pUnchecked)
        If $$$ISERR(tSC) || (pUnchecked '= "") Quit

        Kill tSeen, tQueue
        Set tTail = 0
        If $IsObject(pRoots) {
            Set tIterator = pRoots.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRole) {
                If $IsObject(tRole) || (tRole = "") Continue
                If $Data(tSeen($ZConvert(tRole, "U"))) Continue
                Set tSeen($ZConvert(tRole, "U")) = ""
                Set tTail = tTail + 1
                Set tQueue(tTail) = tRole
            }
        }
        Set tHead = 0
        While tHead < tTail {
            Set tHead = tHead + 1
            ; The declared read's own cap bounds the role rows one Read fetches.
            If tHead > ##class(OcuPilot.Screen.Read).#DEFAULTMAXROWS {
                Set pUnchecked = ..#TRUNCATED
                Quit
            }
            Set tName = tQueue(tHead)
            Kill tQuery
            Set tQuery(..#ROLEIDPARAM) = tName
            Set tReadSC = $ClassMethod(..PortClass(), "Invoke", ..#ROLEENDPOINT, ..#ROLEREADTYPE, .tQuery, "", .tRow, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                If +$Get(tHttp) = 404 Continue
                Set tSC = tReadSC
                Quit
            }
            If '$IsObject($Get(tRow)) || 'tRow.%IsA("%Library.DynamicObject") Continue
            Do pRoleRows.%Set(tName, tRow)
            If tRow.%GetTypeOf("GrantedRoles") '= "array" Continue
            Set tGranted = tRow.%Get("GrantedRoles").%GetIterator()
            While tGranted.%GetNext(.tGrantedIndex, .tOne) {
                If $IsObject(tOne) || (tOne = "") Continue
                If $Data(tSeen($ZConvert(tOne, "U"))) Continue
                Set tSeen($ZConvert(tOne, "U")) = ""
                Set tTail = tTail + 1
                Set tQueue(tTail) = tOne
            }
        }
        If $$$ISERR(tSC) || (pUnchecked '= "") Quit

        Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#RESOURCEDESCRIPTOR, "", .tResult, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit
        If tResult.%Get("truncated") {
            Set pUnchecked = ..#TRUNCATED
            Quit
        }
        Set tIterator = tResult.%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) Continue
            Set tLetters = tRow.%Get("PublicPermission")
            If (tLetters = "") || (tRow.%Get("Name") = "") Continue
            Do pPublic.%Set(tRow.%Get("Name"), tLetters, "string")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) || (pUnchecked '= "") {
        Set pRoleRows = {}
        Set pPublic = {}
    }
    Quit tSC
}

/// <p>Whether the caller holds <var>pDescriptor</var>'s pair set
/// (<method>OcuPilot.Screen.Gate.RequiredPairs</method>): <var>pUnchecked</var> names the first pair
/// it lacks, or <code>""</code>. A set that cannot be resolved is an error.</p>
ClassMethod Gate(pDescriptor As %String, Output pUnchecked As %String) As %Status
{
    Set pUnchecked = ""
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(pDescriptor, .tResolved)
    If 'tResolved Quit $$$ERROR($$$GeneralError, "the pair set of " _ pDescriptor _ " could not be resolved")
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs(tPairs, .tFailed) Quit $$$OK
    Set pUnchecked = tFailed
    If pUnchecked = "" Quit $$$ERROR($$$GeneralError, "the pair set of " _ pDescriptor _ " could not be evaluated")
    Quit $$$OK
}

/// <p>Record each letter of <var>pLetters</var> on <var>pResource</var> as reached through
/// <var>pRole</var> in <var>pResources</var> and granted by <var>pSource</var> in
/// <var>pSources</var>, unless it is recorded already. <var>pSpelled</var> maps an upper-cased name
/// to the spelling first met.</p>
ClassMethod Grant(pResources As %DynamicObject, pSources As %DynamicObject, ByRef pSpelled, pResource As %String, pLetters As %String, pRole As %String, pSource As %String) [ Private ]
{
    If pResource = "" Quit
    Set tKey = $ZConvert(pResource, "U")
    If '$Data(pSpelled(tKey)) {
        Set pSpelled(tKey) = pResource
        Do pResources.%Set(pResource, {})
        Do pSources.%Set(pResource, {})
    }
    Set tGranted = pResources.%Get(pSpelled(tKey))
    Set tGrantedBy = pSources.%Get(pSpelled(tKey))
    Set tUpper = $ZConvert(pLetters, "U")
    For tI = 1:1:$Length(..#LETTERS) {
        Set tLetter = $Extract(..#LETTERS, tI)
        If '(tUpper [ tLetter) Continue
        If tGranted.%GetTypeOf(tLetter) '= "unassigned" Continue
        Do tGranted.%Set(tLetter, pRole, "string")
        Do tGrantedBy.%Set(tLetter, pSource, "string")
    }
}

/// <p>Every letter <var>pResources</var> records, as <var>pHeld</var>(upper-cased resource,
/// letter).</p>
ClassMethod Index(pResources As %DynamicObject, Output pHeld) [ Private ]
{
    If '$IsObject(pResources) Quit
    Set tIterator = pResources.%GetIterator()
    While tIterator.%GetNext(.tResource, .tGranted) {
        If '$IsObject(tGranted) Continue
        Set tLetters = tGranted.%GetIterator()
        While tLetters.%GetNext(.tLetter, .tRole) {
            Set pHeld($ZConvert(tResource, "U"), tLetter) = ""
        }
    }
}

}
