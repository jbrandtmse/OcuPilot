/// <p>The classic pages' custom resources (AD-29, AD-36, AD-44, AD-52, Story 21.37): the pages of the classic portal that hold a custom resource
/// and the one resource each holds, over the vendor's own <parameter>RESOURCECLASS</parameter> in <code>%SYS</code> (AD-16), which is what the
/// classic <code>%CSP.Portal.ResourceDialog</code> reads and writes. It is <class>OcuPilot.Port.AdminPort</class> with one pseudo-endpoint,
/// <parameter>ENDPOINT</parameter>, carried out here; every other call is the admin port's own.</p>
/// <p><b>A page is named by its class</b>, as the instance stores it. The port URL-encodes the name before every vendor call, because the
/// vendor decodes it once and a <code>%</code> in a class name would otherwise read as an escape; the name the vendor resolves it to
/// (<method>Resolve</method>) is the key it is stored and shown under. A name outside <parameter>PAGEPATTERN</parameter>, or longer than
/// <parameter>MAXPAGE</parameter>, and a name the vendor does not resolve to a portal page, is refused 422 <code>ACCESS.PAGE.UNKNOWN</code> on
/// <code>Page</code>.</p>
/// <p><b>Its own gate comes first</b> (AD-29): <parameter>PAIRS</parameter> in the calling process before any read or vendor call, measured as
/// the vendor's own requirement for the call (<code>%Admin_Secure:USE</code>) and for entering <code>%SYS</code>
/// (<code>%DB_IRISSYS:READ</code>); a caller missing one is refused 403 <code>PORT.ACCESSDENIED</code> with <code>detail.failedPair</code>.</p>
/// <p><b>A row</b> is <code>{Page, Resource, Screen}</code>: the page's normalized class name, the resource it holds (<code>""</code> for a page
/// that holds none) and the titles of the built screens that declare the page, joined by <parameter>TITLESEPARATOR</parameter>
/// (<method>OcuPilot.Screen.Registry.ScreensDeclaringPage</method>), <code>""</code> when none does. The declaring screens are read from the
/// registry on every call and cached nowhere.</p>
/// <p><b>Two writes</b>, each refused before the vendor is called when its input is unsound. <parameter>SETTYPE</parameter> assigns the resource
/// <parameter>RESOURCEPARAM</parameter> names to the page, refusing 422 <code>ACCESS.PAGE.RESOURCEREQUIRED</code> on <code>Resource</code> for none
/// and 422 <code>ACCESS.RESOURCE.UNKNOWN</code> on <code>Resource</code> for a resource this instance does not define (the vendor stores either).
/// <parameter>CLEARTYPE</parameter> removes the page's resource through the same vendor call with an empty resource, refusing 409
/// <code>ACCESS.PAGE.NOTASSIGNED</code> for a page that holds none. A <code>GET</code> carrying <parameter>RESOURCEPARAM</parameter> or
/// <parameter>CLEARPARAM</parameter> is the same page read composed for that write, and refuses what the write would refuse; its row also answers
/// <code>Current</code>, the resource the page holds now.</p>
/// <p><b>Each accepted write records OcuPilot's own <code>SecurityChange</code> event</b> with the page and the resource before and after
/// (AD-15, <method>Audit</method>), whoever the caller is; a write that changes nothing and a refused write record none. The vendor records no
/// event for either call.</p>
/// <p>Seams a test subclass overrides: <method>Stored</method>, <method>Resolve</method>, <method>Held</method>, <method>Store</method>,
/// <method>Declaring</method> and <method>ResourceDefined</method>, with the admin port's own <method>HoldsPair</method> and
/// <method>LogFault</method>. Production overrides none of them.</p>
Class OcuPilot.Port.PortalResourcePort Extends OcuPilot.Port.AdminPort
{

/// <p>The pseudo-endpoint this port carries out itself.</p>
Parameter ENDPOINT = "PortalResource";

/// <p>The port's own pair set, checked in this order before any read or vendor call (AD-29).</p>
Parameter PAIRS = "%Admin_Secure:USE,%DB_IRISSYS:READ";

/// <p>The read type of every page that holds a custom resource.</p>
Parameter LISTTYPE = "LIST";

/// <p>The read type of one page, named by <parameter>IDPARAM</parameter>.</p>
Parameter GETTYPE = "GET";

/// <p>The write types: an assignment and a clear. Both are <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> pairs this port composes.</p>
Parameter SETTYPE = "PUT";

Parameter CLEARTYPE = "DELETE";

Parameter COMPOSEDTYPES = "PortalResource/PUT,PortalResource/DELETE";

/// <p>The query key naming the resource an assignment sets, and the key marking a read composed for a clear.</p>
Parameter RESOURCEPARAM = "resource";

Parameter CLEARPARAM = "clear";

/// <p>The field a refusal about the resource names, and the member of a one-page row that answers the resource the page holds now.</p>
Parameter RESOURCEFIELD = "Resource";

Parameter CURRENTFIELD = "Current";

/// <p>The entity type and the verbs a write's <code>SecurityChange</code> event records (AD-14, AD-15).</p>
Parameter ENTITYTYPE = "page-resource";

Parameter VERBUPDATED = "updated";

Parameter VERBDELETED = "deleted";

/// <p>The query parameter a page's class name travels under.</p>
Parameter IDPARAM = "id";

/// <p>The query parameter a list's row cap travels under.</p>
Parameter MAXROWSPARAM = "maxRows";

/// <p>The row cap a list that names none is read under.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>The vendor class that stores each page's custom resource, and the class that resolves a page name.</p>
Parameter RESOURCECLASS = "%SYS.Portal.Resources";

Parameter PORTALCLASS = "%CSP.Portal.Utils";

/// <p>The shape of a page's class name, and the most characters one holds.</p>
Parameter PAGEPATTERN = "^%?[A-Za-z][A-Za-z0-9.]*$";

Parameter MAXPAGE As INTEGER = 256;

/// <p>The field a refusal about the page names.</p>
Parameter PAGEFIELD = "Page";

/// <p>The separator between two screen titles in a row's <code>Screen</code>.</p>
Parameter TITLESEPARATOR = ", ";

/// <p>The admin port's call, except for <parameter>ENDPOINT</parameter>: <parameter>LISTTYPE</parameter> answers the rows, at most
/// <parameter>MAXROWSPARAM</parameter> of them, ordered by page; <parameter>GETTYPE</parameter> answers the one row the page
/// <parameter>IDPARAM</parameter> names as an object, with an empty <code>Resource</code> for a page that holds none, and 422
/// <code>ACCESS.PAGE.UNKNOWN</code> for a name no portal page answers to. <parameter>SETTYPE</parameter> and <parameter>CLEARTYPE</parameter>
/// answer the page's row after the write (the header). Any other type is 501 <code>PORT.NOTIMPLEMENTED</code>.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are <method>OcuPilot.Port.AdminPort.Invoke</method>'s. <parameter>ENDPOINT</parameter>
/// takes no body. Must not be called from an escalated frame (AD-9); the caller's namespace is unchanged on return (AD-16).</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pEndpoint '= ..#ENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '..Gate(.tFailedPair) {
            Set tSC = ..GateRefusal(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a page resource call takes no body"), pFault.code)
            Quit
        }
        If pType = ..#LISTTYPE {
            Set tSC = ..Rows($Get(pQuery(..#MAXROWSPARAM)), .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#GETTYPE {
            Set tSC = ..Row($Get(pQuery(..#IDPARAM)), .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#SETTYPE {
            Set tSC = ..AssignResource($Get(pQuery(..#IDPARAM)), $Get(pQuery(..#RESOURCEPARAM)), .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#CLEARTYPE {
            Set tSC = ..ClearResource($Get(pQuery(..#IDPARAM)), .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "This instance does not implement that operation", .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether the calling process holds every pair in <parameter>PAIRS</parameter>, checked in order through
/// <method>OcuPilot.Port.AdminPort.HoldsPair</method>. <var>pFailedPair</var> names the first it lacks, or is <code>""</code>.</p>
ClassMethod Gate(Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    Set tPairs = $ListFromString(..#PAIRS)
    For tI = 1:1:$ListLength(tPairs) {
        If ..HoldsPair($List(tPairs, tI)) Continue
        Set pFailedPair = $List(tPairs, tI)
        Quit
    }
    Quit (pFailedPair = "")
}

/// <p>The rows, at most <var>pMax</var> of them (<parameter>DEFAULTMAXROWS</parameter> when it is empty), in <var>pRows</var> at 200, ordered by
/// page. A cap that is not a whole number above zero is 500.</p>
ClassMethod Rows(pMax As %String, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tMax = $Select(pMax = "": ..#DEFAULTMAXROWS, 1: pMax)
    If '$Match(tMax, "^[1-9][0-9]*$") Quit ..Fail(..#ENDPOINT, 500, $$$ERROR($$$GeneralError, "the list was asked for '" _ pMax _ "' rows"), .pHttpStatus, .pFault)
    Set tSC = ..Stored(tMax, .tStored)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:$ListLength(tStored) {
        Set tEntry = $List(tStored, tI)
        Do pRows.%Push(..Listed($List(tEntry, 1), $List(tEntry, 2)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The one row the page <var>pPage</var> names, in <var>pRow</var> at 200: <code>{Page, Resource, Screen, Current}</code>, where
/// <code>Current</code> is the resource the page holds now. A name that is not a portal page is 422 <code>ACCESS.PAGE.UNKNOWN</code> on
/// <code>Page</code>. When <var>pQuery</var> carries <parameter>RESOURCEPARAM</parameter> the read is composed for an assignment and refuses what
/// <method>AssignResource</method> would refuse; when it carries <parameter>CLEARPARAM</parameter> it refuses a page that holds no resource, 409
/// <code>ACCESS.PAGE.NOTASSIGNED</code>.</p>
ClassMethod Row(pPage As %String, ByRef pQuery, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Normalized(pPage, .tNormalized)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    If tNormalized = "" Quit ..Unknown(.pHttpStatus, .pFault)
    If $Data(pQuery(..#RESOURCEPARAM)) # 2 {
        Set tCode = ..ResourceProblem(pQuery(..#RESOURCEPARAM))
        If tCode '= "" Quit ..Violate(tCode, ..#RESOURCEFIELD, .pHttpStatus, .pFault)
    }
    Set tSC = ..Held(tNormalized, .tResource)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    If ''$Get(pQuery(..#CLEARPARAM)) && (tResource = "") Quit ..Conflict(##class(OcuPilot.Api.AccessError).#PAGENOTASSIGNED, .pHttpStatus, .pFault)
    Set pRow = ..Listed(tNormalized, tResource)
    Do pRow.%Set(..#CURRENTFIELD, tResource _ "", "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The <class>OcuPilot.Api.AccessError</class> code that refuses <var>pResource</var> as the resource to assign: <code>ACCESS.PAGE.RESOURCEREQUIRED</code>
/// for none, <code>ACCESS.RESOURCE.UNKNOWN</code> for one this instance does not define (<method>ResourceDefined</method>), <code>""</code> for neither.</p>
ClassMethod ResourceProblem(pResource As %String) As %String [ Private ]
{
    If pResource = "" Quit ##class(OcuPilot.Api.AccessError).#PAGERESOURCEREQUIRED
    If '..ResourceDefined(pResource) Quit ##class(OcuPilot.Api.AccessError).#RESOURCEUNKNOWN
    Quit ""
}

/// <p>Whether this instance defines a resource named <var>pName</var>, through <method>OcuPilot.Port.ScreenAccessPort.ResourceDefined</method>, the
/// one reader of that question. Overridable so a fixture can pose an answer; production never overrides it.</p>
ClassMethod ResourceDefined(pName As %String) As %Boolean
{
    Quit ##class(OcuPilot.Port.ScreenAccessPort).ResourceDefined(pName)
}

/// <p>Assign <var>pResource</var> to the page <var>pPage</var>, answering the page's row after the write in <var>pRow</var> at 200. Everything it
/// refuses is refused before <method>Store</method> is called. An assignment of the resource the page already holds stores and records
/// nothing.</p>
ClassMethod AssignResource(pPage As %String, pResource As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Normalized(pPage, .tNormalized)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    If tNormalized = "" Quit ..Unknown(.pHttpStatus, .pFault)
    Set tCode = ..ResourceProblem(pResource)
    If tCode '= "" Quit ..Violate(tCode, ..#RESOURCEFIELD, .pHttpStatus, .pFault)
    Set tSC = ..Held(tNormalized, .tOld)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    If tOld '= pResource {
        Set tSC = ..Store(tNormalized, pResource)
        If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
        Do ..Audit(..#VERBUPDATED, tNormalized, tOld, pResource)
    }
    Set pRow = ..Listed(tNormalized, pResource)
    Do pRow.%Set(..#CURRENTFIELD, pResource _ "", "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Remove the resource of the page <var>pPage</var>, answering the page's row after the write in <var>pRow</var> at 200. A page that holds none is
/// 409 <code>ACCESS.PAGE.NOTASSIGNED</code>, with nothing stored and nothing recorded.</p>
ClassMethod ClearResource(pPage As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Normalized(pPage, .tNormalized)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    If tNormalized = "" Quit ..Unknown(.pHttpStatus, .pFault)
    Set tSC = ..Held(tNormalized, .tOld)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    If tOld = "" Quit ..Conflict(##class(OcuPilot.Api.AccessError).#PAGENOTASSIGNED, .pHttpStatus, .pFault)
    Set tSC = ..Store(tNormalized, "")
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    Do ..Audit(..#VERBDELETED, tNormalized, tOld, "")
    Set pRow = ..Listed(tNormalized, "")
    Do pRow.%Set(..#CURRENTFIELD, "", "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Store <var>pResource</var> as the custom resource of the normalized page <var>pNormalized</var> (<code>""</code> removes it) through
/// <parameter>PORTALCLASS</parameter>'s <code>%SetCustomResource</code> with the page URL-encoded, in <code>%SYS</code> by save and restore (AD-16).
/// Overridable so a fixture can observe or fail the call; production never overrides it.</p>
ClassMethod Store(pNormalized As %String, pResource As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tStoreSC = $ClassMethod(..#PORTALCLASS, "%SetCustomResource", $ZConvert(pNormalized, "O", "URL"), pResource)
        Set $NAMESPACE = tOrigNS
        Set tSC = tStoreSC
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Record <code>SecurityChange</code> for an accepted write to the page <var>pPage</var>: the resource before and after (AD-15). It never fails
/// the write.</p>
ClassMethod Audit(pVerb As %String, pPage As %String, pOld As %String, pNew As %String) [ Private ]
{
    Try {
        Set tResource = {}
        Do tResource.%Set("old", pOld _ "", "string")
        Do tResource.%Set("new", pNew _ "", "string")
        Set tChanges = {}
        Do tChanges.%Set("resource", tResource)
        Do ##class(OcuPilot.Kernel.Audit.Event).Record(pVerb, ..#ENTITYTYPE, pPage, tChanges, 1)
    } Catch ex {
        Do ..LogFault("the page resource change could not be audited", ex.AsStatus())
    }
}

/// <p>The row for the page <var>pPage</var> holding <var>pResource</var>: both as text, and <code>Screen</code> the declaring screens' titles.</p>
ClassMethod Listed(pPage As %String, pResource As %String) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Page", pPage _ "", "string")
    Do tRow.%Set("Resource", pResource _ "", "string")
    Do tRow.%Set("Screen", ..ScreenTitles(pPage), "string")
    Quit tRow
}

/// <p>The titles of the built screens that declare <var>pPage</var>, joined by <parameter>TITLESEPARATOR</parameter>; the screen's tool
/// identifier stands for a title the string source does not give. <code>""</code> when no screen declares the page.</p>
ClassMethod ScreenTitles(pPage As %String) As %String [ Private ]
{
    Set tList = ..TitleList(pPage)
    Set tTitles = ""
    For tI = 1:1:$ListLength(tList) {
        Set tTitles = tTitles _ $Select(tTitles = "": "", 1: ..#TITLESEPARATOR) _ $List(tList, tI)
    }
    Quit tTitles
}

/// <p>The titles of the built screens that declare <var>pPage</var>, as a <class>%List</class> in the registry's order, one per screen; the screen's
/// tool identifier stands for a title the string source does not give. Empty when no screen declares the page.</p>
ClassMethod TitleList(pPage As %String) As %List
{
    Set tScreens = ..Declaring(pPage)
    Set tTitles = ""
    For tI = 1:1:$ListLength(tScreens) {
        Set tDescriptor = $List(tScreens, tI)
        Set tTitle = ##class(OcuPilot.Screen.Tool.Read).Title(tDescriptor)
        If tTitle = "" Set tTitle = $ClassMethod(tDescriptor, "ToolIdentifier")
        Set tTitles = tTitles _ $ListBuild(tTitle)
    }
    Quit tTitles
}

/// <p>The descriptor classes of the built screens that declare the page <var>pPage</var>, read from the registry on every call. Overridable so a
/// fixture can pose a declaring screen; production never overrides it.</p>
ClassMethod Declaring(pPage As %String) As %List
{
    Quit ##class(OcuPilot.Screen.Registry).ScreensDeclaringPage(pPage)
}

/// <p>The page <var>pPage</var> as the instance stores it, in <var>pNormalized</var>: the class name <method>Resolve</method> answers for the name
/// URL-encoded as the vendor expects, or <code>""</code> for a name outside <parameter>PAGEPATTERN</parameter>, longer than
/// <parameter>MAXPAGE</parameter>, or that is no portal page. The status is an error only when the vendor could not be asked.</p>
ClassMethod Normalized(pPage As %String, Output pNormalized As %String) As %Status
{
    Set pNormalized = ""
    If '$Match(pPage, ..#PAGEPATTERN) || ($Length(pPage) > ..#MAXPAGE) Quit $$$OK
    Quit ..Resolve($ZConvert(pPage, "O", "URL"), .pNormalized)
}

/// <p>The normalized class name the vendor resolves the URL-encoded <var>pEncoded</var> to, in <var>pNormalized</var>, or <code>""</code> when it is no
/// page of the portal, asked in <code>%SYS</code> by save and restore (AD-16). Overridable so a fixture can pose an answer.</p>
ClassMethod Resolve(pEncoded As %String, Output pNormalized As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pNormalized = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If $ClassMethod(..#PORTALCLASS, "%IsPortalPage", pEncoded, .tNormalized) Set pNormalized = tNormalized
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pNormalized = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The resource the normalized page <var>pNormalized</var> holds, in <var>pResource</var>, <code>""</code> when it holds none, read in
/// <code>%SYS</code> by save and restore (AD-16). A failed read is an error, never an absent answer. Overridable so a fixture can pose an answer.</p>
ClassMethod Held(pNormalized As %String, Output pResource As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResource = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResource = $ClassMethod(..#RESOURCECLASS, "%GetCustomResource", $ZConvert(pNormalized, "O", "URL"))
        Set $NAMESPACE = tOrigNS
        Set pResource = tResource _ ""
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pResource = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The pages that hold a resource, in <var>pStored</var> as a <class>%List</class> of <code>$ListBuild(page, resource)</code>, ordered by page,
/// at most <var>pMax</var> of them, read through <parameter>RESOURCECLASS</parameter>'s <code>List</code> query in <code>%SYS</code> by save and
/// restore (AD-16). Overridable so a fixture can pose rows.</p>
ClassMethod Stored(pMax As %Integer, Output pStored As %List) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pStored = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%ResultSet).%New(..#RESOURCECLASS _ ":List")
        Set tSC = tResult.Execute("*", "*")
        Set tCount = 0
        If $$$ISOK(tSC) {
            While (tCount < pMax) && tResult.Next() {
                Set pStored = pStored _ $ListBuild($ListBuild(tResult.Get("Page"), tResult.Get("Resource")))
                Set tCount = tCount + 1
            }
        }
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pStored = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The 422 <code>ACCESS.PAGE.UNKNOWN</code> on <code>Page</code>, with its published sentence carried again as the field's one violation (AD-39).</p>
ClassMethod Unknown(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Violate(##class(OcuPilot.Api.AccessError).#PAGEUNKNOWN, ..#PAGEFIELD, .pHttpStatus, .pFault)
}

/// <p>The 422 <var>pCode</var> on the field <var>pField</var>, with its published sentence carried again as the field's one violation (AD-39).</p>
ClassMethod Violate(pCode As %String, pField As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tReason = ##class(OcuPilot.Api.AccessError).ReasonFor(pCode)
    Set tViolation = {}
    Do tViolation.%Set("field", pField, "string")
    Do tViolation.%Set("code", pCode, "string")
    Do tViolation.%Set("reason", tReason, "string")
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push(tViolation)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, pCode, tReason, .pHttpStatus, .pFault, tDetail)
}

/// <p>The 409 <var>pCode</var>, with its published sentence.</p>
ClassMethod Conflict(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, pCode, ##class(OcuPilot.Api.AccessError).ReasonFor(pCode), .pHttpStatus, .pFault)
}

/// <p>The codes a write's fresh read refuses with when the action's precondition does not hold: the tools'
/// <method>OcuPilot.Screen.Tool.Write.PreconditionCodes</method>, which may not name <class>OcuPilot.Api.AccessError</class> themselves.</p>
ClassMethod PreconditionCodes() As %List
{
    Quit ##class(OcuPilot.Api.AccessError).PagePreconditionCodes()
}

/// <p>The 403 the gate answers: the admin port's own mapping of 403, with the pair in <code>detail.failedPair</code> (AD-8, AD-39).</p>
ClassMethod GateRefusal(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("failedPair", pFailedPair, "string")
    Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tVendorText)
    Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, tDetail)
}

/// <p>The kind of script step <method>Snippet</method> renders: <code>objectscript</code> for the two writes of <parameter>ENDPOINT</parameter>, which have a
/// script form, and <code>""</code> for its reads, which write nothing; the admin port's answer for any other endpoint.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If pEndpoint '= ..#ENDPOINT Quit ##super(pEndpoint, pType)
    If (pType = ..#SETTYPE) || (pType = ..#CLEARTYPE) Quit "objectscript"
    Quit ""
}

/// <p><method>Invoke</method>'s two writes as a script (AD-59), in <code>%SYS</code>: the vendor's <code>%SetCustomResource</code> of the page, URL-encoded
/// as the port encodes it, with the resource the query carries, or with <code>""</code> for <parameter>CLEARTYPE</parameter>. Every value is a string
/// literal, so nothing the query carries runs as code. Whoever runs the script is checked by the vendor's own gate. A read writes nothing and answers
/// no step. Every other endpoint is the admin port's script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If pEndpoint '= ..#ENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tPage = ..Literal($ZConvert($Get(pQuery(..#IDPARAM)), "O", "URL"))
    Set tResource = $Select(pType = ..#SETTYPE: ..Literal($Get(pQuery(..#RESOURCEPARAM))), 1: """""")
    Set tLines = $ListBuild("Set tSC = ##class(" _ ..#PORTALCLASS _ ").%SetCustomResource(" _ tPage _ ", " _ tResource _ ")", "Do $System.Status.DisplayError(tSC)")
    Quit [(..ObjectScriptStep(tLines))]
}

}
