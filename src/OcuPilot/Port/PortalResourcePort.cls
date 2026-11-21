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
/// <p>Seams a test subclass overrides: <method>Stored</method>, <method>Resolve</method>, <method>Held</method> and <method>Declaring</method>, with the admin
/// port's own <method>HoldsPair</method> and <method>LogFault</method>. Production overrides none of them.</p>
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
/// <code>ACCESS.PAGE.UNKNOWN</code> for a name no portal page answers to. Any other type is 501 <code>PORT.NOTIMPLEMENTED</code>.</p>
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
            Set tSC = ..Row($Get(pQuery(..#IDPARAM)), .pResult, .pHttpStatus, .pFault)
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

/// <p>The one row the page <var>pPage</var> names, in <var>pRow</var> at 200. A name that is not a portal page is 422
/// <code>ACCESS.PAGE.UNKNOWN</code> on <code>Page</code>.</p>
ClassMethod Row(pPage As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Normalized(pPage, .tNormalized)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    If tNormalized = "" Quit ..Unknown(.pHttpStatus, .pFault)
    Set tSC = ..Held(tNormalized, .tResource)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    Set pRow = ..Listed(tNormalized, tResource)
    Set pHttpStatus = 200
    Quit $$$OK
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
    Set tScreens = ..Declaring(pPage)
    Set tTitles = ""
    For tI = 1:1:$ListLength(tScreens) {
        Set tDescriptor = $List(tScreens, tI)
        Set tTitle = ##class(OcuPilot.Screen.Tool.Read).Title(tDescriptor)
        If tTitle = "" Set tTitle = $ClassMethod(tDescriptor, "ToolIdentifier")
        Set tTitles = tTitles _ $Select(tTitles = "": "", 1: ..#TITLESEPARATOR) _ tTitle
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
    Set tCode = ##class(OcuPilot.Api.AccessError).#PAGEUNKNOWN
    Set tReason = ##class(OcuPilot.Api.AccessError).ReasonFor(tCode)
    Set tViolation = {}
    Do tViolation.%Set("field", ..#PAGEFIELD, "string")
    Do tViolation.%Set("code", tCode, "string")
    Do tViolation.%Set("reason", tReason, "string")
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push(tViolation)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, tCode, tReason, .pHttpStatus, .pFault, tDetail)
}

/// <p>The 403 the gate answers: the admin port's own mapping of 403, with the pair in <code>detail.failedPair</code> (AD-8, AD-39).</p>
ClassMethod GateRefusal(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("failedPair", pFailedPair, "string")
    Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tVendorText)
    Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, tDetail)
}

/// <p>The kind of script step <method>Snippet</method> renders: <code>objectscript</code> for <parameter>ENDPOINT</parameter>, the admin port's answer
/// otherwise.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If pEndpoint = ..#ENDPOINT Quit "objectscript"
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s call as a script (AD-59): a read of <parameter>ENDPOINT</parameter> writes nothing and answers no step. Every other
/// endpoint is the admin port's script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If pEndpoint '= ..#ENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    Quit []
}

}
