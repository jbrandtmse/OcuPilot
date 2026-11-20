/// <p>The globals port (AD-16, AD-21, AD-29, AD-36, AD-51, AD-52, AD-53, AD-58, Story 21.5): the only product class that reads or
/// writes a global's nodes. It lists a namespace's globals, reads one global's presence and mappings, reads, sets and kills one node, and
/// pages through a global's nodes. It switches <code>$NAMESPACE</code> to the request's namespace by save and restore around each vendor
/// call (AD-16), and calls no <code>OcuPilot.*</code> class while switched, so every vendor step is one overridable method of its own.</p>
/// <p><b>Its gate comes first</b> (AD-29): <parameter>PAIRS</parameter>, then the namespace's own READ pairs
/// (<method>OcuPilot.Port.AtelierPort.NamespacePairs</method>), evaluated through <method>GateClass</method> in the calling process before
/// any vendor call. A caller missing one is refused 403 <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>. A write also
/// needs WRITE on the database the node resolves to, which the instance checks: a vendor <code>&lt;PROTECT&gt;</code> is 403
/// <code>PORT.ACCESSDENIED</code>.</p>
/// <p><b>A node is named by its canonical reference</b>, the text <code>$Name</code> answers, with no environment part
/// (<method>ParseReference</method>). The text is parsed only with <code>$QLength</code> and <code>$QSubscript</code>; the reference is
/// rebuilt by subscript indirection over the parsed values and the rebuilt text must equal the text given. Caller text never reaches
/// <code>Xecute</code>, and a name indirection only ever holds a reference <code>$Name</code> built.</p>
/// <p><b>Endpoints and request types.</b> <parameter>ENDPOINTGLOBALS</parameter>: <code>LIST</code> (rows
/// <code>{Name, Database, Collation, Journal}</code> of the namespace's globals, a row of a subscript-level mapping left out),
/// <code>GET</code> (<code>{Name, Defined, Locations, Namespace}</code>, <code>Locations</code> every directory the global's rows answer,
/// subscript-level rows included), <code>DELETE</code> (<code>Kill ^Name</code>), and the two reads an export and an import version a global
/// by (<code>SIZE</code>, <code>DIGEST</code>; <method>GlobalSize</method>, <method>GlobalDigest</method>). <parameter>ENDPOINTNODE</parameter>: <code>GET</code>
/// (<code>{Reference, Value, Defined, Editable, Location, Namespace}</code>), <code>PUT</code> (sets the value the query's
/// <parameter>VALUEKEY</parameter> carries) and <code>DELETE</code> (kills the node and every node below it). A value is editable when
/// the node holds a value, <code>%Studio.Global.format</code> reads it as plain text and it is at most
/// <parameter>MAXDISPLAY</parameter> characters.</p>
/// <p><b><method>Page</method> is screen-only</b> (AD-36): a bounded walk of one global's nodes in <code>$Query</code> order from an
/// explicit cursor. Node values and subscripts are never logged, and a failure in it logs the exception's name alone.</p>
/// <p><b>Find and replace</b> (Story 21.18, AD-51): <code>Globals</code> <code>REPLACE</code> reads what a replace would change and
/// <code>REPLACEALL</code> makes it, both composed by the port from the query's <parameter>FINDKEY</parameter>,
/// <parameter>REPLACEKEY</parameter> and <parameter>MATCHCASEKEY</parameter>, never as code. Only a plain-text node value
/// (<method>Candidate</method>) is searched, and a walk visits at most <parameter>REPLACESCAN</parameter> nodes. The read answers
/// <code>{Name, Find, Replace, MatchCase, Nodes, Occurrences, Locations, Digest, Reviewed, Namespace}</code>, holding no value and no
/// subscript, where <code>Nodes</code> and <code>Occurrences</code> count what changes, <code>Locations</code> is the directories of the
/// nodes that change and <code>Digest</code> a SHA-256 of their references and values. The write walks again, refuses a digest other than
/// the query's <parameter>DIGESTKEY</parameter>, then sets every recorded node in one transaction while it still holds the value the
/// walk read, and answers <code>{Name, Namespace, Nodes, Occurrences}</code>. <method>Page</method> filters its rows with the same
/// <method>Matches</method>.</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>LogFault</method>, <method>VendorList</method>,
/// <method>VendorLocations</method>, <method>VendorTotals</method>, <method>VendorNode</method>, <method>VendorWalk</method>,
/// <method>VendorFindWalk</method>, <method>VendorReplaceScan</method>, <method>VendorReplaceApply</method>, <method>VendorSet</method>,
/// <method>VendorKillNode</method> and <method>VendorKillGlobal</method>. Production overrides none of them.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace is unchanged on return.</p>
Class OcuPilot.Port.GlobalPort Extends %RegisteredObject
{

/// <p>The pair set every call requires, comma-separated as <code>resource:permission</code> (AD-8, AD-29): the classic Globals page's own.</p>
Parameter PAIRS = "%Development:USE";

Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The endpoints a screen's read lists, in <code>LIST</code>.</p>
Parameter ENDPOINTS = "Globals";

/// <p>The request types whose vendor call the port composes from its query, as <code>endpoint/type</code>: a node's value is set from the query's
/// <parameter>VALUEKEY</parameter>, sent in no body (AD-51, AD-52).</p>
Parameter COMPOSEDTYPES = "Node/PUT,Globals/REPLACE,Globals/REPLACEALL";

Parameter ENDPOINTGLOBALS = "Globals";

Parameter ENDPOINTNODE = "Node";

Parameter TYPELIST = "LIST";

Parameter TYPEGET = "GET";

Parameter TYPEPUT = "PUT";

Parameter TYPEDELETE = "DELETE";

/// <p>The two reads on <parameter>ENDPOINTGLOBALS</parameter> that version a global for an export and an import (Story 21.17).</p>
Parameter TYPESIZE = "SIZE";

Parameter TYPEDIGEST = "DIGEST";

/// <p>The read and the write of a find and replace on <parameter>ENDPOINTGLOBALS</parameter> (Story 21.18).</p>
Parameter TYPEREPLACE = "REPLACE";

Parameter TYPEREPLACEALL = "REPLACEALL";

/// <p>The most nodes one replace walk, or one filtered page, visits.</p>
Parameter REPLACESCAN As INTEGER = 20000;

/// <p>The longest value a replace writes.</p>
Parameter REPLACEVALUEMAX As INTEGER = 32767;

/// <p>The longest text a replace looks for or writes.</p>
Parameter MAXTEXT As INTEGER = 1000;

/// <p>About how many characters of a <code>DIGEST</code> walk are written to the hash stream at once.</p>
Parameter DIGESTBATCH As INTEGER = 32000;

/// <p>The query keys: the namespace, a global's name, a node's reference, a new value, the rows a list is read for, and the list's two
/// criteria.</p>
Parameter NAMESPACEKEY = "namespace";

Parameter NAMEKEY = "name";

Parameter REFERENCEKEY = "reference";

Parameter VALUEKEY = "value";

Parameter MAXROWSKEY = "maxRows";

Parameter PATTERNKEY = "pattern";

Parameter SYSTEMKEY = "system";

/// <p>The keys of a replace: the text to find, its replacement, whether case matters (<code>1</code> or <code>0</code>, default
/// <code>1</code>) and the digest the replace was reviewed at.</p>
Parameter FINDKEY = "find";

Parameter REPLACEKEY = "replace";

Parameter MATCHCASEKEY = "matchCase";

Parameter DIGESTKEY = "digest";

/// <p>The keys of a page request and the answer's.</p>
Parameter PAGEGLOBALKEY = "global";

Parameter PAGEFINDKEY = "find";

Parameter PAGEMATCHCASEKEY = "matchCase";

Parameter PAGESTARTKEY = "start";

Parameter PAGEAFTERKEY = "after";

Parameter PAGESIZEKEY = "pageSize";

/// <p>The cap a list that names none is read under.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>A global name: an optional <code>%</code>, a letter, letters and digits.</p>
Parameter NAMEPATTERN = "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z0-9]+)*$";

/// <p>The longest global name, <code>%</code> included.</p>
Parameter MAXNAME As INTEGER = 31;

/// <p>A list pattern: names, wildcards, commas and ranges.</p>
Parameter PATTERNPATTERN = "^[A-Za-z0-9%.*?,:]{1,256}$";

/// <p>The longest reference text a call accepts.</p>
Parameter MAXREFERENCE As INTEGER = 8000;

/// <p>The longest value or reference displayed, and the longest value editable.</p>
Parameter MAXDISPLAY As INTEGER = 1000;

/// <p>The fewest, the most and the default rows of a node page.</p>
Parameter MINPAGE As INTEGER = 50;

Parameter MAXPAGE As INTEGER = 500;

Parameter DEFAULTPAGE As INTEGER = 100;

/// <p>The most characters, references and displayed values together, a node page holds.</p>
Parameter MAXCHARS As INTEGER = 1000000;

Parameter LOGSUBSYSTEM = "globalport";

Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

Parameter REASONNAMESPACESHAPE = "Name the namespace the call runs in.";

Parameter REASONNAMESPACEUNKNOWN = "This instance cannot name the databases that namespace reads code from.";

Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

Parameter REASONNAME = "The global name must be 1 to 31 letters and digits, optionally starting with %.";

Parameter REASONPATTERN = "The pattern must be 1 to 256 characters of letters, digits, %, ., *, ?, commas and colons.";

Parameter REASONSYSTEM = "system must be yes or no.";

Parameter REASONREFERENCE = "The node reference must be a canonical global reference with no environment.";

Parameter REASONPAGE = "The page request names a global, optionally a start node or a node to continue after, and a page size of 50 to 500.";

Parameter REASONMATCHCASE = "matchCase must be 1 or 0.";

/// <p>The class the pair sets are evaluated through. Overridable so a fixture can drive a denial in process; production never overrides
/// it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture the line; production never overrides
/// it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>The pair set <parameter>PAIRS</parameter> as the <code>%List</code> the gate evaluates.</p>
ClassMethod Pairs() As %List
{
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(..#PAIRS)
}

/// <p>The published sentence of <var>pCode</var>, one of <class>OcuPilot.Api.GlobalError</class>'s codes: what a tool states for a refusal this port
/// answers, so a tool names the port and not the API class.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    Quit ##class(OcuPilot.Api.GlobalError).ReasonFor(pCode)
}

/// <p>Whether <var>pName</var>, without its <code>^</code>, is a global name.</p>
ClassMethod NameValid(pName As %String) As %Boolean
{
    Quit ($Length(pName) '> ..#MAXNAME) && $Match(pName, ..#NAMEPATTERN)
}

/// <p>Whether <var>pValue</var> is a value a node can be edited to: at most <parameter>MAXDISPLAY</parameter> characters, no control
/// character.</p>
ClassMethod ValueValid(pValue As %String) As %Boolean
{
    Quit ($Length(pValue) '> ..#MAXDISPLAY) && ($ZStrip(pValue, "*C") = pValue)
}

/// <p>Parse reference <var>pReference</var>. <var>pName</var> is the global's name without <code>^</code> and <var>pRebuilt</var> the
/// reference rebuilt by subscript indirection over the parsed subscripts, <code>$Name</code>'s canonical text. The answer is 1 only when
/// the text starts with <code>^</code>, parses with <code>$QLength</code> and <code>$QSubscript</code> alone, names a global of
/// <parameter>NAMEPATTERN</parameter> with no environment, and the rebuilt text equals the text given. Anything else answers 0 and leaves
/// <var>pName</var> and <var>pRebuilt</var> empty; nothing is evaluated and nothing is read.</p>
ClassMethod ParseReference(pReference As %String, Output pName As %String, Output pRebuilt As %String) As %Boolean
{
    Set pName = ""
    Set pRebuilt = ""
    If ($Length(pReference) < 2) || ($Length(pReference) > ..#MAXREFERENCE) || ($Extract(pReference) '= "^") Quit 0
    Set tOk = 0
    Try {
        Set tLength = $QLength(pReference)
        Set tName = $Extract($QSubscript(pReference, 0), 2, *)
        If ($QSubscript(pReference, -1) '= "") || '..NameValid(tName) Quit
        Set tRef = "^" _ tName
        For tI = 1:1:tLength {
            Set tSub = $QSubscript(pReference, tI)
            Set tRef = $Name(@tRef@(tSub))
        }
        If tRef '= pReference Quit
        Set pName = tName
        Set pRebuilt = tRef
        Set tOk = 1
    } Catch {
        Set tOk = 0
    }
    If 'tOk {
        Set pName = ""
        Set pRebuilt = ""
    }
    Quit tOk
}

/// <p>The text between the outer parentheses of canonical reference <var>pReference</var>, <code>""</code> for a global's root.</p>
ClassMethod SubscriptText(pReference As %String) As %String
{
    Set tOpen = $Find(pReference, "(")
    If tOpen = 0 Quit ""
    Quit $Extract(pReference, tOpen, $Length(pReference) - 1)
}

/// <p>Serve <var>pEndpoint</var> for request type <var>pType</var>, after the gate.</p>
/// <p><var>pQuery</var> carries <parameter>NAMESPACEKEY</parameter> (optional: the request's scope when absent), the keys the call needs
/// (<parameter>NAMEKEY</parameter>, <parameter>REFERENCEKEY</parameter>, <parameter>VALUEKEY</parameter>,
/// <parameter>MAXROWSKEY</parameter>, <parameter>PATTERNKEY</parameter>, <parameter>SYSTEMKEY</parameter>, and a replace's
/// <parameter>FINDKEY</parameter>, <parameter>REPLACEKEY</parameter>, <parameter>MATCHCASEKEY</parameter> and
/// <parameter>DIGESTKEY</parameter>). <var>pBody</var> must be empty.</p>
/// <p>Otherwise an error status is returned, <var>pHttpStatus</var> is the status to answer with and <var>pFault</var> the wire fault: 403
/// <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>; 400 <code>PORT.VALIDATION</code> for a namespace, name, reference,
/// pattern or cap of the wrong shape; 501 <code>PORT.NOTIMPLEMENTED</code> for another endpoint or type; each <code>GLOBAL.*</code>
/// refusal on the status <class>OcuPilot.Api.GlobalError</class> names; 403 <code>PORT.ACCESSDENIED</code> for a vendor
/// <code>&lt;PROTECT&gt;</code>; and 500 <code>INTERNAL</code>, logged, for a body or any failure.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSC = ..Admit(.pQuery, .tNamespace, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '..Serves(pEndpoint, pType) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Fail(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a globals call takes no body"), .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTGLOBALS {
            If pType = ..#TYPELIST {
                Set tSC = ..Listing(tNamespace, .pQuery, .pResult, .pHttpStatus, .pFault)
            } ElseIf pType = ..#TYPEGET {
                Set tSC = ..GlobalState(tNamespace, .pQuery, .pResult, .pHttpStatus, .pFault)
            } ElseIf (pType = ..#TYPESIZE) || (pType = ..#TYPEDIGEST) {
                Set tSC = ..GlobalTotals(tNamespace, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            } ElseIf (pType = ..#TYPEREPLACE) || (pType = ..#TYPEREPLACEALL) {
                Set tSC = ..Replacing(tNamespace, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            } Else {
                Set tSC = ..GlobalRemove(tNamespace, .pQuery, .pResult, .pHttpStatus, .pFault)
            }
        } ElseIf pType = ..#TYPEGET {
            Set tSC = ..NodeState(tNamespace, .pQuery, .pResult, .pHttpStatus, .pFault)
        } ElseIf pType = ..#TYPEPUT {
            Set tSC = ..NodeSet(tNamespace, .pQuery, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..NodeRemove(tNamespace, .pQuery, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", $$$ERROR($$$GeneralError, ex.Name), .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) Set pResult = ""
    Quit tSC
}

/// <p>Whether <var>pEndpoint</var> serves request type <var>pType</var>.</p>
ClassMethod Serves(pEndpoint As %String, pType As %String) As %Boolean
{
    If pEndpoint = ..#ENDPOINTGLOBALS Quit (pType = ..#TYPELIST) || (pType = ..#TYPEGET) || (pType = ..#TYPEDELETE) || (pType = ..#TYPESIZE) || (pType = ..#TYPEDIGEST) || (pType = ..#TYPEREPLACE) || (pType = ..#TYPEREPLACEALL)
    If pEndpoint = ..#ENDPOINTNODE Quit (pType = ..#TYPEGET) || (pType = ..#TYPEPUT) || (pType = ..#TYPEDELETE)
    Quit 0
}

/// <p>The gate, in order: <parameter>PAIRS</parameter>, the namespace's shape (<var>pQuery</var>'s <parameter>NAMESPACEKEY</parameter>, or
/// the request's scope), and the namespace's READ pairs. <var>pNamespace</var> is the namespace.</p>
ClassMethod Admit(ByRef pQuery, Output pNamespace As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pNamespace = ""
    Set tFailedPair = ""
    ; EvaluateRequired, not EvaluatePairs: a pair parameter mis-edited to empty fails closed.
    If '$ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
    If tNamespace = "" Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
    If '$Match(tNamespace, ##class(OcuPilot.Port.AtelierPort).#NAMESPACEPATTERN) {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACESHAPE, .pHttpStatus, .pFault)
    }
    Set tPairs = ##class(OcuPilot.Port.AtelierPort).NamespacePairs(tNamespace)
    If tPairs = "" {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
    }
    If '$ClassMethod(..GateClass(), "EvaluateRequired", tPairs, .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    Set pNamespace = tNamespace
    Quit $$$OK
}

/// <p>The namespace's global rows, at most <parameter>MAXROWSKEY</parameter> of them, each <code>{Name, Database, Collation, Journal}</code>:
/// <code>NameSpaceList</code> over the query's <parameter>PATTERNKEY</parameter> (default <code>*</code>) and
/// <parameter>SYSTEMKEY</parameter> (<code>yes</code> or <code>no</code>, default <code>no</code>), a row of a subscript-level mapping
/// (a name holding <code>(</code>) left out.</p>
ClassMethod Listing(pNamespace As %String, ByRef pQuery, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
    If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
    }
    Set tMax = $Select(tMaxText = "": ..#DEFAULTMAXROWS, 1: +tMaxText)
    Set tPattern = $Get(pQuery(..#PATTERNKEY))
    If tPattern = "" Set tPattern = "*"
    If '$Match(tPattern, ..#PATTERNPATTERN) {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONPATTERN, .pHttpStatus, .pFault)
    }
    Set tSystemText = $Get(pQuery(..#SYSTEMKEY))
    If (tSystemText '= "") && (tSystemText '= "yes") && (tSystemText '= "no") {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONSYSTEM, .pHttpStatus, .pFault)
    }
    Do ..VendorList(pNamespace, tPattern, (tSystemText = "yes"), tMax, .tFound, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the global list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:+$Get(tFound) {
        Set tRow = {}
        Do tRow.%Set("Name", $ListGet(tFound(tI), 1) _ "", "string")
        Do tRow.%Set("Database", $ListGet(tFound(tI), 2) _ "", "string")
        Do tRow.%Set("Collation", $ListGet(tFound(tI), 3) _ "", "string")
        Do tRow.%Set("Journal", $ListGet(tFound(tI), 4) _ "", "string")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The vendor's list of <var>pNamespace</var>'s globals matching <var>pPattern</var>, in the vendor's order, as
/// <code>pFound(n) = $ListBuild(Name, Database, Collation, Journal)</code> with the count in <code>pFound</code>, at most
/// <var>pMax</var> rows, none of a subscript-level mapping. <var>pCaught</var> is the exception, or <code>""</code>. The namespace is
/// switched for the call alone and no <code>OcuPilot.*</code> class runs while it is.</p>
ClassMethod VendorList(pNamespace As %String, pPattern As %String, pSystem As %Boolean, pMax As %Integer, Output pFound, Output pCaught)
{
    Set pFound = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%ResultSet).%New("%SYS.GlobalQuery:NameSpaceList")
        Set tSC = tRS.Execute(pNamespace, pPattern, pSystem + 0, , , 1)
        If $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
        While (pFound < pMax) && tRS.Next() {
            Set tName = tRS.Get("Name")
            If tName [ "(" Continue
            Set pFound = pFound + 1
            Set pFound(pFound) = $ListBuild(tName, tRS.Get("Location"), tRS.Get("Collation"), tRS.Get("Journal"))
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>The global named by the query: <code>{Name, Defined, Locations, Namespace}</code>. An absent global is not an error: it answers
/// <code>Defined</code> false and the directory its name resolves to.</p>
ClassMethod GlobalState(pNamespace As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tName = $Get(pQuery(..#NAMEKEY))
    If '..NameValid(tName) {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAME, .pHttpStatus, .pFault)
    }
    Do ..VendorLocations(pNamespace, tName, .tLocations, .tDefined, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the global could not be read", .pHttpStatus, .pFault)
    Set pResult = {}
    Do pResult.%Set("Name", tName, "string")
    Do pResult.%Set("Defined", ''tDefined, "boolean")
    Set tArray = []
    For tI = 1:1:$ListLength(tLocations) {
        Do tArray.%Push($List(tLocations, tI), "string")
    }
    Do pResult.%Set("Locations", tArray)
    Do pResult.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Whether global <var>pName</var> holds data in <var>pNamespace</var> (<var>pDefined</var>), and every directory its rows answer
/// (<var>pLocations</var>, a <code>%List</code>, each once): the directory its name resolves to, then the directory of each row
/// <code>NameSpaceList</code> answers for the exact name, a row of a subscript-level mapping included. The namespace is switched for the
/// call alone.</p>
ClassMethod VendorLocations(pNamespace As %String, pName As %String, Output pLocations As %List, Output pDefined As %Boolean, Output pCaught)
{
    Set pLocations = ""
    Set pDefined = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRoot = "^" _ pName
        Set pDefined = ($Data(@tRoot) > 0)
        Set tDirectory = $Piece(##class(%SYS.Namespace).GetGlobalDest(pNamespace, tRoot), "^", 2)
        If tDirectory '= "" Set pLocations = $ListBuild(tDirectory)
        Set tRS = ##class(%ResultSet).%New("%SYS.GlobalQuery:NameSpaceList")
        Set tSC = tRS.Execute(pNamespace, pName, 1, , , 1)
        If $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
        While tRS.Next() {
            If $Piece(tRS.Get("Name"), "(", 1) '= pName Continue
            Set tLocation = tRS.Get("Location")
            If (tLocation '= "") && '$ListFind(pLocations, tLocation) Set pLocations = pLocations _ $ListBuild(tLocation)
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>The global named by the query read for an export (<code>SIZE</code>: <code>{Name, Defined, Characters}</code>) or an import
/// (<code>DIGEST</code>: <code>{Name, Defined, Digest}</code>), by one bounded walk of every node (<method>VendorTotals</method>). Refused
/// 400 <code>PORT.VALIDATION</code> for a name of the wrong shape; for <code>SIZE</code> alone, 403 <code>GLOBAL.OWNDATA</code> for a global
/// whose name begins with one of OcuPilot's own name stems, in any case, and 404 <code>GLOBAL.NOTFOUND</code> for one that holds no data;
/// and 422 <code>GLOBAL.TOOLARGE</code> for either when the walk passes <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter>,
/// the most an XML file is read or written at, so whatever exports also imports. An undefined global
/// answers <code>Defined</code> false and an empty <code>Digest</code> to a <code>DIGEST</code>.</p>
ClassMethod GlobalTotals(pNamespace As %String, pType As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tName = $Get(pQuery(..#NAMEKEY))
    If '..NameValid(tName) {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAME, .pHttpStatus, .pFault)
    }
    Set tSize = (pType = ..#TYPESIZE)
    If tSize && ##class(OcuPilot.Kernel.Proposal.Prohibited).IsOcuPilotCode(tName) Quit ..Violation(##class(OcuPilot.Api.GlobalError).#OWNDATA, .pHttpStatus, .pFault)
    Do ..VendorTotals(pNamespace, tName, ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS, 'tSize, .tDefined, .tCharacters, .tOver, .tStream, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the global could not be read", .pHttpStatus, .pFault, 1)
    If tOver Quit ..Violation(##class(OcuPilot.Api.GlobalError).#TOOLARGE, .pHttpStatus, .pFault)
    If tSize && 'tDefined Quit ..Violation(##class(OcuPilot.Api.GlobalError).#NOTFOUND, .pHttpStatus, .pFault)
    Set pResult = {}
    Do pResult.%Set("Name", tName, "string")
    Do pResult.%Set("Defined", ''tDefined, "boolean")
    If tSize {
        Do pResult.%Set("Characters", tCharacters, "number")
    } Else {
        Set tDigest = ""
        If tDefined {
            Set tDigest = ..StreamDigest(tStream, .tStatus)
            If $$$ISERR(tStatus) Quit ..Fail("the global's digest could not be computed", tStatus, .pHttpStatus, .pFault)
        }
        Do pResult.%Set("Digest", tDigest, "string")
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>One bounded walk of global <var>pName</var> in <var>pNamespace</var>, every node that holds a value in <code>$Query</code> order
/// from the root, the root included: <var>pDefined</var> is whether the global holds data, <var>pCharacters</var> the characters of every
/// node's <code>$Name</code> reference and value, and <var>pOver</var> whether that passed <var>pBound</var> (the walk stops there). With <var>pDigest</var>, <var>pStream</var> holds each node as the length of its
/// reference, the reference, the length of its value and the value, UTF-8 encoded and written in batches of about
/// <parameter>DIGESTBATCH</parameter> characters. The namespace is switched for the call alone.</p>
ClassMethod VendorTotals(pNamespace As %String, pName As %String, pBound As %Integer, pDigest As %Boolean, Output pDefined As %Boolean, Output pCharacters As %Integer, Output pOver As %Boolean, Output pStream As %Stream.TmpBinary, Output pCaught)
{
    Set pDefined = 0
    Set pCharacters = 0
    Set pOver = 0
    Set pStream = ""
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRoot = "^" _ pName
        Set pDefined = ($Data(@tRoot) > 0)
        If pDefined {
            If pDigest Set pStream = ##class(%Stream.TmpBinary).%New()
            Set tBatch = ""
            Set tNext = $Select($Data(@tRoot) # 2: tRoot, 1: $Query(@tRoot))
            While (tNext '= "") && 'pOver {
                Set tValue = $Get(@tNext)
                Set pCharacters = pCharacters + $Length(tNext) + $Length(tValue)
                If pCharacters > pBound {
                    Set pOver = 1
                } Else {
                    If pDigest {
                        Set tBatch = tBatch _ $Length(tNext) _ ":" _ tNext _ $Length(tValue) _ ":" _ tValue
                        If $Length(tBatch) '< ..#DIGESTBATCH Do ..WriteDigestBatch(pStream, .tBatch)
                    }
                    Set tNext = $Query(@tNext)
                }
            }
            If pDigest && 'pOver Do ..WriteDigestBatch(pStream, .tBatch)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>Write <var>pBatch</var> to <var>pStream</var> as UTF-8, <parameter>DIGESTBATCH</parameter> characters at a time so that no one conversion
/// passes the longest string, and empty it.</p>
ClassMethod WriteDigestBatch(pStream As %Stream.TmpBinary, ByRef pBatch As %String) [ Private ]
{
    For tAt = 1:..#DIGESTBATCH:$Length(pBatch) {
        Do pStream.Write($ZConvert($Extract(pBatch, tAt, tAt + ..#DIGESTBATCH - 1), "O", "UTF8"))
    }
    Set pBatch = ""
}

/// <p>The SHA-256 of <var>pStream</var>, in lower-case hexadecimal; <var>pStatus</var> is the hash's own status.</p>
ClassMethod StreamDigest(pStream As %Stream.TmpBinary, Output pStatus As %Status) As %String
{
    Set pStatus = $$$OK
    Do pStream.Rewind()
    Set tHash = $System.Encryption.SHAHashStream(256, pStream, .pStatus)
    If $$$ISERR(pStatus) Quit ""
    Quit $ZConvert(##class(%xsd.hexBinary).LogicalToXSD(tHash), "L")
}

/// <p>Whether <var>pText</var> is a text a replace looks for or writes: at least <var>pMinimum</var> and at most
/// <parameter>MAXTEXT</parameter> characters, no control character.</p>
ClassMethod TextValid(pText As %String, pMinimum As %Integer = 0) As %Boolean
{
    Quit ($Length(pText) '< pMinimum) && ($Length(pText) '> ..#MAXTEXT) && ($ZStrip(pText, "*C") = pText)
}

/// <p>Whether <var>pValue</var>, a node's value, is one a find or a replace reads: plain text (<code>%Studio.Global.format</code> answers
/// 1) with no control character. A <code>$List</code> and a value holding a tab or any other control character are not.</p>
ClassMethod Candidate(pValue As %String) As %Boolean
{
    If $ZStrip(pValue, "*C") '= pValue Quit 0
    Quit (##class(%Studio.Global).format(pValue, .tOut, 1) = 1)
}

/// <p><var>pValue</var> with every occurrence of <var>pFind</var> replaced by <var>pReplace</var>, left to right and without overlap, and
/// <var>pOccurrences</var> how many there were. Without <var>pMatchCase</var> the occurrences are found by comparing the lower-case
/// forms, which keep every character's position, and the original characters are replaced. A text whose lower-case form changes its length
/// is never matched. It does not judge <var>pValue</var> (<method>Candidate</method>).</p>
ClassMethod Replaced(pValue As %String, pFind As %String, pReplace As %String, pMatchCase As %Boolean, Output pOccurrences As %Integer) As %String
{
    Set pOccurrences = 0
    If pFind = "" Quit pValue
    Set tHay = $Select(pMatchCase: pValue, 1: $ZConvert(pValue, "L"))
    Set tNeedle = $Select(pMatchCase: pFind, 1: $ZConvert(pFind, "L"))
    If ($Length(tHay) '= $Length(pValue)) || ($Length(tNeedle) '= $Length(pFind)) Quit pValue
    Set tLength = $Length(tNeedle)
    Set tOut = ""
    Set tFrom = 1
    For {
        Set tAt = $Find(tHay, tNeedle, tFrom)
        If tAt = 0 Quit
        Set tOut = tOut _ $Extract(pValue, tFrom, tAt - tLength - 1) _ pReplace
        Set pOccurrences = pOccurrences + 1
        Set tFrom = tAt
    }
    If pOccurrences = 0 Quit pValue
    Quit tOut _ $Extract(pValue, tFrom, *)
}

/// <p>Whether the node value <var>pValue</var> is a candidate (<method>Candidate</method>) that holds <var>pFind</var>
/// (<method>Replaced</method>'s comparison).</p>
ClassMethod Matches(pValue As %String, pFind As %String, pMatchCase As %Boolean) As %Boolean
{
    If '..Candidate(pValue) Quit 0
    Set tUnused = ..Replaced(pValue, pFind, "", pMatchCase, .tCount)
    Quit (tCount > 0)
}

/// <p>The find and replace the query names, after the gate: <var>pType</var> <code>REPLACE</code> reads what it would change and
/// <code>REPLACEALL</code> makes the change (Story 21.18). Refused 400 <code>GLOBAL.VALUE.SHAPE</code> for a find or a replacement that is
/// no text of <method>TextValid</method>, 400 <code>PORT.VALIDATION</code> for a name or a <parameter>MATCHCASEKEY</parameter> of the wrong
/// shape, 409 <code>GLOBAL.REPLACE.SYSNAMESPACE</code> in <code>%SYS</code>, 404 <code>GLOBAL.NOTFOUND</code> for a global that holds no
/// data, 409 <code>GLOBAL.REPLACE.TOOLARGE</code> when the walk passes <parameter>REPLACESCAN</parameter> nodes or a replaced value passes
/// <parameter>REPLACEVALUEMAX</parameter> characters, and 409 <code>GLOBAL.REPLACE.NOCHANGE</code> when no value changes. The write is
/// 409 <code>GLOBAL.REPLACE.REVIEWCHANGED</code>, with nothing written, when the walk's digest is not the query's
/// <parameter>DIGESTKEY</parameter> or a recorded node no longer holds the value the walk read. A vendor <code>&lt;PROTECT&gt;</code> is
/// 403 <code>PORT.ACCESSDENIED</code> with every node as it was. Nothing a node holds is logged.</p>
ClassMethod Replacing(pNamespace As %String, pType As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..ReplacingRun(pNamespace, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("a global's replace failed inside the port", $$$ERROR($$$GeneralError, ex.Name), .pHttpStatus, .pFault)
    }
    Kill ^||OcuPilotGlobalReplace
    Quit tSC
}

/// <p><method>Replacing</method>'s work. The change is recorded in <code>^||OcuPilotGlobalReplace</code>, which the caller kills.</p>
ClassMethod ReplacingRun(pNamespace As %String, pType As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tName = $Get(pQuery(..#NAMEKEY))
    If '..NameValid(tName) {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAME, .pHttpStatus, .pFault)
    }
    Set tFind = $Get(pQuery(..#FINDKEY))
    Set tReplace = $Get(pQuery(..#REPLACEKEY))
    If '($Data(pQuery(..#FINDKEY)) # 2) || '($Data(pQuery(..#REPLACEKEY)) # 2) || '..TextValid(tFind, 1) || '..TextValid(tReplace, 0) {
        Quit ..Violation(##class(OcuPilot.Api.GlobalError).#VALUESHAPE, .pHttpStatus, .pFault)
    }
    Set tCaseText = $Get(pQuery(..#MATCHCASEKEY))
    If (tCaseText '= "") && '$Match(tCaseText, "^[01]$") {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMATCHCASE, .pHttpStatus, .pFault)
    }
    Set tMatchCase = (tCaseText '= "0")
    If $ZConvert(pNamespace, "U") = "%SYS" Quit ..Violation(##class(OcuPilot.Api.GlobalError).#SYSNAMESPACE, .pHttpStatus, .pFault)
    Set tWrite = (pType = ..#TYPEREPLACEALL)
    Do ..VendorLocations(pNamespace, tName, .tLocations, .tDefined, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the global could not be read", .pHttpStatus, .pFault, 1)
    If 'tDefined Quit ..Violation(##class(OcuPilot.Api.GlobalError).#NOTFOUND, .pHttpStatus, .pFault)
    Set tFixed = $Select($ListLength(tLocations) = 1: $List(tLocations, 1), 1: "")
    Do ..VendorReplaceScan(pNamespace, tName, tFind, tReplace, tMatchCase, tWrite, ..#REPLACESCAN, ..#REPLACEVALUEMAX, tFixed, .tNodes, .tOccurrences, .tOver, .tNodeLocations, .tStream, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the global could not be walked", .pHttpStatus, .pFault, 1)
    If tOver Quit ..Violation(##class(OcuPilot.Api.GlobalError).#REPLACETOOLARGE, .pHttpStatus, .pFault)
    If tNodes = 0 Quit ..Violation(##class(OcuPilot.Api.GlobalError).#NOCHANGE, .pHttpStatus, .pFault)
    Set tDigest = ..StreamDigest(tStream, .tStatus)
    If $$$ISERR(tStatus) Quit ..Fail("the replace's digest could not be computed", tStatus, .pHttpStatus, .pFault)
    Set pResult = {}
    If tWrite {
        Set tReviewed = $Get(pQuery(..#DIGESTKEY))
        If (tReviewed = "") || (tReviewed '= tDigest) Quit ..Violation(##class(OcuPilot.Api.GlobalError).#REVIEWCHANGED, .pHttpStatus, .pFault)
        Do ..VendorReplaceApply(pNamespace, .tStale, .tCaught)
        If $IsObject(tCaught) Quit ..Mapped(tCaught, "the global could not be replaced", .pHttpStatus, .pFault, 1)
        If tStale Quit ..Violation(##class(OcuPilot.Api.GlobalError).#REVIEWCHANGED, .pHttpStatus, .pFault)
    } Else {
        Do pResult.%Set("Find", tFind, "string")
        Do pResult.%Set("Replace", tReplace, "string")
        Do pResult.%Set("MatchCase", ''tMatchCase, "boolean")
    }
    Do pResult.%Set("Name", tName, "string")
    Do pResult.%Set("Nodes", tNodes, "number")
    Do pResult.%Set("Occurrences", tOccurrences, "number")
    If 'tWrite {
        Set tArray = []
        For tI = 1:1:$ListLength(tNodeLocations) {
            Do tArray.%Push($List(tNodeLocations, tI), "string")
        }
        Do pResult.%Set("Locations", tArray)
        Do pResult.%Set("Digest", tDigest, "string")
        Do pResult.%Set("Reviewed", "", "string")
    }
    Do pResult.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>One walk of global <var>pName</var> in <var>pNamespace</var> for a replace of <var>pFind</var> by <var>pReplace</var>, every node that
/// holds a value in <code>$Query</code> order from the root, the root included. <var>pNodes</var> and <var>pOccurrences</var> count the nodes
/// that change (a candidate whose replaced value differs from its value) and the occurrences in them; <var>pLocations</var> (a
/// <code>%List</code>) is the directories those nodes resolve to, <var>pFixed</var> when it is not empty (the one directory every node of the
/// global resolves to) and each node's own otherwise; <var>pStream</var> holds each changing node's reference and value for the digest. A walk
/// that visits more than <var>pBound</var> nodes, or meets a replaced value longer than <var>pValueMax</var> characters, stops with
/// <var>pOver</var>. With <var>pRecord</var>, each changing node is recorded as <code>$ListBuild(reference, value, replaced value)</code> in
/// <code>^||OcuPilotGlobalReplace</code>. The namespace is switched for the call alone.</p>
ClassMethod VendorReplaceScan(pNamespace As %String, pName As %String, pFind As %String, pReplace As %String, pMatchCase As %Boolean, pRecord As %Boolean, pBound As %Integer, pValueMax As %Integer, pFixed As %String, Output pNodes As %Integer, Output pOccurrences As %Integer, Output pOver As %Boolean, Output pLocations As %List, Output pStream As %Stream.TmpBinary, Output pCaught)
{
    Set pNodes = 0
    Set pOccurrences = 0
    Set pOver = 0
    Set pLocations = ""
    Set pStream = ""
    Set pCaught = ""
    Kill ^||OcuPilotGlobalReplace
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRoot = "^" _ pName
        Set pStream = ##class(%Stream.TmpBinary).%New()
        Set tBatch = ""
        Set tVisited = 0
        Set tNext = $Select($Data(@tRoot) # 2: tRoot, 1: $Query(@tRoot))
        While (tNext '= "") && 'pOver {
            Set tVisited = tVisited + 1
            If tVisited > pBound {
                Set pOver = 1
                Quit
            }
            Set tValue = $Get(@tNext)
            If ..Candidate(tValue) {
                Set tNew = ..Replaced(tValue, pFind, pReplace, pMatchCase, .tCount)
                If tNew '= tValue {
                    If $Length(tNew) > pValueMax {
                        Set pOver = 1
                        Quit
                    }
                    Set pNodes = pNodes + 1
                    Set pOccurrences = pOccurrences + tCount
                    Set tBatch = tBatch _ $Length(tNext) _ ":" _ tNext _ $Length(tValue) _ ":" _ tValue
                    If $Length(tBatch) '< ..#DIGESTBATCH Do ..WriteDigestBatch(pStream, .tBatch)
                    If pRecord Set ^||OcuPilotGlobalReplace(pNodes) = $ListBuild(tNext, tValue, tNew)
                    If pFixed = "" {
                        Set tDirectory = $Piece(##class(%SYS.Namespace).GetGlobalDest(pNamespace, tRoot, ..SubscriptText(tNext)), "^", 2)
                        If (tDirectory '= "") && '$ListFind(pLocations, tDirectory) Set pLocations = pLocations _ $ListBuild(tDirectory)
                    }
                }
            }
            Set tNext = $Query(@tNext)
        }
        If 'pOver Do ..WriteDigestBatch(pStream, .tBatch)
        If (pFixed '= "") && (pNodes > 0) Set pLocations = $ListBuild(pFixed)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>Set every node <method>VendorReplaceScan</method> recorded to its replaced value, in <var>pNamespace</var>, in one transaction: a node
/// that no longer holds the value that was recorded for it (<var>pStale</var>) rolls everything back and nothing is written. No event, job
/// or other effect runs inside the transaction. The namespace is switched for the call alone.</p>
ClassMethod VendorReplaceApply(pNamespace As %String, Output pStale As %Boolean, Output pCaught)
{
    Set pStale = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Set tLevel = $TLevel
    Try {
        Set $NAMESPACE = pNamespace
        TSTART
        Set tIndex = ""
        For {
            Set tIndex = $Order(^||OcuPilotGlobalReplace(tIndex), 1, tRecord)
            If tIndex = "" Quit
            Set tNode = $List(tRecord, 1)
            If '($Data(@tNode) # 2) || ($Get(@tNode) '= $List(tRecord, 2)) {
                Set pStale = 1
                Quit
            }
            Set @tNode = $List(tRecord, 3)
        }
        If pStale {
            TROLLBACK 1
        } Else {
            TCOMMIT
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        While $TLevel > tLevel {
            TROLLBACK 1
        }
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>Kill the global the query names and every node in it: 404 <code>GLOBAL.NOTFOUND</code> when it holds no data.</p>
ClassMethod GlobalRemove(pNamespace As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tName = $Get(pQuery(..#NAMEKEY))
    If '..NameValid(tName) {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAME, .pHttpStatus, .pFault)
    }
    Do ..VendorLocations(pNamespace, tName, .tLocations, .tDefined, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the global could not be read", .pHttpStatus, .pFault)
    If 'tDefined Quit ..Violation(##class(OcuPilot.Api.GlobalError).#NOTFOUND, .pHttpStatus, .pFault)
    Do ..VendorKillGlobal(pNamespace, tName, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the global could not be deleted", .pHttpStatus, .pFault)
    Set pResult = {}
    Do pResult.%Set("Name", tName, "string")
    Do pResult.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Kill global <var>pName</var> in <var>pNamespace</var>. The namespace is switched for the call alone.</p>
ClassMethod VendorKillGlobal(pNamespace As %String, pName As %String, Output pCaught)
{
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRoot = "^" _ pName
        Kill @tRoot
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>The node the query's <parameter>REFERENCEKEY</parameter> names: 400 <code>PORT.VALIDATION</code> for a reference that does not
/// parse, otherwise <var>pName</var> and <var>pReference</var>, its canonical text.</p>
ClassMethod NodeReference(ByRef pQuery, Output pName As %String, Output pReference As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    If '..ParseReference($Get(pQuery(..#REFERENCEKEY)), .pName, .pReference) {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONREFERENCE, .pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p>The node's fresh read: <code>{Reference, Value, Defined, Editable, Location, Namespace}</code>, 404 <code>GLOBAL.NODE.NOTFOUND</code>
/// when it holds neither a value nor a node below it. <code>Value</code> is the value itself for an editable node and the vendor's display
/// form, cut at <parameter>MAXDISPLAY</parameter> characters, otherwise.</p>
ClassMethod NodeState(pNamespace As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..NodeReference(.pQuery, .tName, .tReference, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Do ..VendorNode(pNamespace, tName, tReference, .tNode, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the node could not be read", .pHttpStatus, .pFault, 1)
    If +tNode("data") = 0 Quit ..Violation(##class(OcuPilot.Api.GlobalError).#NODENOTFOUND, .pHttpStatus, .pFault)
    Set tEditable = ..NodeEditable(.tNode)
    Set pResult = {}
    Do pResult.%Set("Reference", tReference, "string")
    Do pResult.%Set("Value", $Select(tEditable: tNode("value"), 1: $Extract(tNode("display"), 1, ..#MAXDISPLAY)), "string")
    Do pResult.%Set("Defined", 1, "boolean")
    Do pResult.%Set("Editable", tEditable, "boolean")
    Do pResult.%Set("Location", tNode("location"), "string")
    Do pResult.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Whether the node read as <var>pNode</var> (<method>VendorNode</method>) holds a value an edit may replace.</p>
ClassMethod NodeEditable(ByRef pNode) As %Boolean [ Private ]
{
    Quit (pNode("data") # 2) && (pNode("format") = 1) && (pNode("length") '> ..#MAXDISPLAY) && 'pNode("control")
}

/// <p>The node <var>pReference</var>, a canonical reference of global <var>pName</var>, in <var>pNamespace</var>. <var>pNode</var>:
/// <code>data</code> (<code>$Data</code>), <code>value</code> (the node's value, kept only when it is at most
/// <parameter>MAXDISPLAY</parameter> characters), <code>display</code> (the vendor's display form, at most one character over
/// <parameter>MAXDISPLAY</parameter>), <code>length</code>, <code>format</code> (<code>%Studio.Global.format</code>'s answer, 1 for plain
/// text), <code>control</code> (the value holds a control character) and <code>location</code> (the directory the node resolves to). The
/// namespace is switched for the call alone.</p>
ClassMethod VendorNode(pNamespace As %String, pName As %String, pReference As %String, Output pNode, Output pCaught)
{
    Kill pNode
    Set pNode("data") = 0
    Set pNode("value") = ""
    Set pNode("display") = ""
    Set pNode("length") = 0
    Set pNode("format") = 1
    Set pNode("control") = 0
    Set pNode("location") = ""
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set pNode("data") = $Data(@pReference)
        If pNode("data") '= 0 {
            Set tValue = $Get(@pReference)
            Set pNode("length") = $Length(tValue)
            Set pNode("control") = ($ZStrip(tValue, "*C") '= tValue)
            Set pNode("format") = ##class(%Studio.Global).format(tValue, .tOut, 1)
            Set pNode("display") = $Extract(tOut, 1, 1001)
            If pNode("length") '> 1000 Set pNode("value") = tValue
            Set tOpen = $Find(pReference, "(")
            Set tSubscripts = $Select(tOpen = 0: "", 1: $Extract(pReference, tOpen, $Length(pReference) - 1))
            Set pNode("location") = $Piece(##class(%SYS.Namespace).GetGlobalDest(pNamespace, "^" _ pName, tSubscripts), "^", 2)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>Set the node the query names to the query's <parameter>VALUEKEY</parameter>: 400 <code>GLOBAL.VALUE.SHAPE</code> for a value that is
/// not plain text of <parameter>MAXDISPLAY</parameter> characters at most, 404 <code>GLOBAL.NODE.NOTFOUND</code> for a node that holds no
/// value, and 409 <code>GLOBAL.NODE.NOTEDITABLE</code> for a node whose value is not editable. No node is created.</p>
ClassMethod NodeSet(pNamespace As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..NodeReference(.pQuery, .tName, .tReference, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$Data(pQuery(..#VALUEKEY)) || '..ValueValid($Get(pQuery(..#VALUEKEY))) Quit ..Violation(##class(OcuPilot.Api.GlobalError).#VALUESHAPE, .pHttpStatus, .pFault)
    Do ..VendorNode(pNamespace, tName, tReference, .tNode, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the node could not be read", .pHttpStatus, .pFault, 1)
    If '(tNode("data") # 2) Quit ..Violation(##class(OcuPilot.Api.GlobalError).#NODENOTFOUND, .pHttpStatus, .pFault)
    If '..NodeEditable(.tNode) Quit ..Violation(##class(OcuPilot.Api.GlobalError).#NODENOTEDITABLE, .pHttpStatus, .pFault)
    Do ..VendorSet(pNamespace, tReference, pQuery(..#VALUEKEY), .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the node could not be set", .pHttpStatus, .pFault, 1)
    Set pResult = {}
    Do pResult.%Set("Reference", tReference, "string")
    Do pResult.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Set node <var>pReference</var>, a canonical reference, to <var>pValue</var> in <var>pNamespace</var>. The namespace is switched for
/// the call alone.</p>
ClassMethod VendorSet(pNamespace As %String, pReference As %String, pValue As %String, Output pCaught)
{
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set @pReference = pValue
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>Kill the node the query names and every node below it: 404 <code>GLOBAL.NODE.NOTFOUND</code> for a node that holds neither a value
/// nor a node below it.</p>
ClassMethod NodeRemove(pNamespace As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..NodeReference(.pQuery, .tName, .tReference, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Do ..VendorNode(pNamespace, tName, tReference, .tNode, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the node could not be read", .pHttpStatus, .pFault, 1)
    If +tNode("data") = 0 Quit ..Violation(##class(OcuPilot.Api.GlobalError).#NODENOTFOUND, .pHttpStatus, .pFault)
    Do ..VendorKillNode(pNamespace, tReference, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the node could not be deleted", .pHttpStatus, .pFault, 1)
    Set pResult = {}
    Do pResult.%Set("Reference", tReference, "string")
    Do pResult.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Kill node <var>pReference</var>, a canonical reference, and every node below it, in <var>pNamespace</var>. The namespace is switched
/// for the call alone.</p>
ClassMethod VendorKillNode(pNamespace As %String, pReference As %String, Output pCaught)
{
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Kill @pReference
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>Whether <var>pBody</var>, a request body, is a node page request, and the request: <code>{global, start, after, pageSize}</code>,
/// <code>global</code> a global name with an optional <code>^</code>, <code>start</code> and <code>after</code> (at most one) canonical
/// references of that global, <code>pageSize</code> a whole number from <parameter>MINPAGE</parameter> to <parameter>MAXPAGE</parameter>
/// (default <parameter>DEFAULTPAGE</parameter>), and optionally <code>find</code> (a text of <method>TextValid</method>; empty is none)
/// and <code>matchCase</code> (a boolean, default true). <var>pRequest</var> is <code>{global, start, after, pageSize}</code> with the
/// global's name bare and each reference canonical, and <code>find</code> and <code>matchCase</code> when a text is given, or
/// <code>""</code>. Pure: it reads nothing.</p>
ClassMethod PageRequest(pBody, Output pRequest As %DynamicObject) As %Boolean
{
    Set pRequest = ""
    If '$IsObject($Get(pBody)) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Set tKeys = $ListBuild(..#PAGEGLOBALKEY, ..#PAGESTARTKEY, ..#PAGEAFTERKEY, ..#PAGESIZEKEY, ..#PAGEFINDKEY, ..#PAGEMATCHCASEKEY)
    Set tStray = 0
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If '$ListFind(tKeys, tKey) Set tStray = 1
    }
    If tStray Quit 0
    If pBody.%GetTypeOf(..#PAGEGLOBALKEY) '= "string" Quit 0
    Set tName = pBody.%Get(..#PAGEGLOBALKEY)
    If $Extract(tName) = "^" Set tName = $Extract(tName, 2, *)
    If '..NameValid(tName) Quit 0
    Set tRefs = ""
    For tKey = ..#PAGESTARTKEY, ..#PAGEAFTERKEY {
        Set tType = pBody.%GetTypeOf(tKey)
        If (tType = "unassigned") || (tType = "null") {
            Set tRefs(tKey) = ""
            Continue
        }
        If tType '= "string" Quit
        If pBody.%Get(tKey) = "" {
            Set tRefs(tKey) = ""
            Continue
        }
        If '..ParseReference(pBody.%Get(tKey), .tRefName, .tRebuilt) || (tRefName '= tName) Quit
        Set tRefs(tKey) = tRebuilt
    }
    If '$Data(tRefs(..#PAGEAFTERKEY)) || '$Data(tRefs(..#PAGESTARTKEY)) Quit 0
    If (tRefs(..#PAGESTARTKEY) '= "") && (tRefs(..#PAGEAFTERKEY) '= "") Quit 0
    Set tSize = ..#DEFAULTPAGE
    Set tType = pBody.%GetTypeOf(..#PAGESIZEKEY)
    If tType = "number" {
        Set tSize = pBody.%Get(..#PAGESIZEKEY)
        If '$Match(tSize, "^[1-9][0-9]{1,2}$") || (tSize < ..#MINPAGE) || (tSize > ..#MAXPAGE) Quit 0
    } ElseIf (tType '= "unassigned") && (tType '= "null") {
        Quit 0
    }
    Set tFind = ""
    Set tType = pBody.%GetTypeOf(..#PAGEFINDKEY)
    If tType = "string" {
        Set tFind = pBody.%Get(..#PAGEFINDKEY)
        If '..TextValid(tFind) Quit 0
    } ElseIf (tType '= "unassigned") && (tType '= "null") {
        Quit 0
    }
    Set tMatchCase = 1
    Set tType = pBody.%GetTypeOf(..#PAGEMATCHCASEKEY)
    If tType = "boolean" {
        Set tMatchCase = pBody.%Get(..#PAGEMATCHCASEKEY)
    } ElseIf (tType '= "unassigned") && (tType '= "null") {
        Quit 0
    }
    Set pRequest = {}
    Do pRequest.%Set(..#PAGEGLOBALKEY, tName, "string")
    Do pRequest.%Set(..#PAGESTARTKEY, tRefs(..#PAGESTARTKEY), "string")
    Do pRequest.%Set(..#PAGEAFTERKEY, tRefs(..#PAGEAFTERKEY), "string")
    Do pRequest.%Set(..#PAGESIZEKEY, +tSize, "number")
    If tFind '= "" {
        Do pRequest.%Set(..#PAGEFINDKEY, tFind, "string")
        Do pRequest.%Set(..#PAGEMATCHCASEKEY, ''tMatchCase, "boolean")
    }
    Quit 1
}

/// <p>One page of the global <var>pRequest</var> names in <var>pNamespace</var> (<method>PageRequest</method>'s answer), after the gate:
/// <var>pAnswer</var> is <code>{rows, next, cut}</code>. A row is <code>{reference, value, cut, editable, below}</code>, in
/// <code>$Query</code> order from the start node (included when it holds a value), the node after the cursor, or the global's first
/// node; each value and reference is cut at <parameter>MAXDISPLAY</parameter> characters, a row holding a cut value or reference is not
/// editable and <code>cut</code> is true on the row and on the page; the page holds at most <parameter>MAXCHARS</parameter> characters.
/// <code>next</code> is the last row's reference when a node follows it and <code>""</code> otherwise. With the request's <code>find</code>
/// only the nodes whose value <method>Matches</method> it are rows, a walk visits at most <parameter>REPLACESCAN</parameter> nodes, and a
/// page that scanned that many without filling answers what it found and the last node it visited as <code>next</code>. Otherwise the
/// gate's refusals (<method>Invoke</method>) and 500. Nothing the request or a node holds is logged.</p>
ClassMethod Page(pNamespace As %String, pRequest As %DynamicObject, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Kill tQuery
        Set tQuery(..#NAMESPACEKEY) = pNamespace
        Set tSC = ..Admit(.tQuery, .tNamespace, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tName = pRequest.%Get(..#PAGEGLOBALKEY)
        Set tSize = +pRequest.%Get(..#PAGESIZEKEY)
        Set tFrom = pRequest.%Get(..#PAGESTARTKEY)
        Set tAfter = pRequest.%Get(..#PAGEAFTERKEY)
        Set tFind = pRequest.%Get(..#PAGEFINDKEY)
        Set tCursor = ""
        If tFind '= "" {
            Set tMatchCase = $Select(pRequest.%GetTypeOf(..#PAGEMATCHCASEKEY) = "boolean": pRequest.%Get(..#PAGEMATCHCASEKEY), 1: 1)
            Do ..VendorFindWalk(tNamespace, tName, tFrom, tAfter, tSize, tFind, tMatchCase, .tRaw, .tMore, .tCursor, .tCaught)
        } Else {
            Do ..VendorWalk(tNamespace, tName, tFrom, tAfter, tSize, .tRaw, .tMore, .tCaught)
        }
        If $IsObject(tCaught) {
            Set tSC = ..Mapped(tCaught, "a global's nodes could not be read", .pHttpStatus, .pFault, 1)
            Quit
        }
        Set tRows = []
        Set tCut = 0
        Set tTotal = 0
        Set tLast = ""
        Set tStopped = 0
        For tI = 1:1:+$Get(tRaw) {
            Set tReference = $List(tRaw(tI), 1)
            Set tDisplay = $List(tRaw(tI), 2)
            Set tRowCut = ($Length(tDisplay) > ..#MAXDISPLAY) || ($Length(tReference) > ..#MAXDISPLAY)
            Set tShownReference = $Extract(tReference, 1, ..#MAXDISPLAY)
            Set tShownValue = $Extract(tDisplay, 1, ..#MAXDISPLAY)
            If tTotal + $Length(tShownReference) + $Length(tShownValue) > ..#MAXCHARS {
                Set tStopped = 1
                Quit
            }
            Set tTotal = tTotal + $Length(tShownReference) + $Length(tShownValue)
            Set tRow = {}
            Do tRow.%Set("reference", tShownReference, "string")
            Do tRow.%Set("value", tShownValue, "string")
            Do tRow.%Set("cut", ''tRowCut, "boolean")
            Do tRow.%Set("editable", ''(($List(tRaw(tI), 6) # 2) && ($List(tRaw(tI), 4) = 1) && ($List(tRaw(tI), 3) '> ..#MAXDISPLAY) && '$List(tRaw(tI), 5) && 'tRowCut), "boolean")
            Do tRow.%Set("below", ''($List(tRaw(tI), 6) \ 10), "boolean")
            If tRowCut Set tCut = 1
            Do tRows.%Push(tRow)
            Set tLast = tReference
        }
        Set pAnswer = {}
        Do pAnswer.%Set("rows", tRows)
        Set tNextRef = $Select(tLast '= "" && (tMore || tStopped): tLast, 1: "")
        ; A filtered walk that scanned past rows it dropped continues after the last node it visited, not the last row it kept.
        If (tFind '= "") && 'tStopped && tMore Set tNextRef = tCursor
        Do pAnswer.%Set("next", tNextRef, "string")
        Do pAnswer.%Set("cut", ''tCut, "boolean")
        Set pHttpStatus = 200
    } Catch ex {
        Set pAnswer = ""
        Set tSC = ..Fail("a global's nodes could not be read", $$$ERROR($$$GeneralError, ex.Name), .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) Set pAnswer = ""
    Quit tSC
}

/// <p>The vendor walk behind <method>Page</method>: up to <var>pSize</var> nodes of global <var>pName</var> that hold a value, in
/// <code>$Query</code> order, as <code>pRaw(n) = $ListBuild(reference, display, length, format, control, data)</code> with the count in
/// <code>pRaw</code>. The first is <var>pFrom</var> when it holds a value, otherwise the node after it; with <var>pAfter</var> it is the
/// node after that; with neither it is the global's root when that holds a value, otherwise the first node. <var>pMore</var> is whether
/// a node follows the last one. <var>pFrom</var> and <var>pAfter</var> are canonical references of the global (or empty). The namespace
/// is switched for the call alone.</p>
ClassMethod VendorWalk(pNamespace As %String, pName As %String, pFrom As %String, pAfter As %String, pSize As %Integer, Output pRaw, Output pMore As %Boolean, Output pCaught)
{
    Kill pRaw
    Set pRaw = 0
    Set pMore = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRoot = "^" _ pName
        Set tRef = $Select(pAfter '= "": pAfter, pFrom '= "": pFrom, 1: tRoot)
        If (pAfter = "") && ($Data(@tRef) # 2) {
            Set tNext = tRef
        } Else {
            Set tNext = $Query(@tRef)
        }
        While (tNext '= "") && (pRaw < pSize) {
            Set pRaw = pRaw + 1
            Set pRaw(pRaw) = ..RawRow(tNext)
            Set tNext = $Query(@tNext)
        }
        Set pMore = (tNext '= "")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>The raw row of node <var>pReference</var>, a canonical reference in the current namespace, as <method>VendorWalk</method> lists it:
/// <code>$ListBuild(reference, display, length, format, control, data)</code>.</p>
ClassMethod RawRow(pReference As %String) As %List [ Private ]
{
    Set tValue = $Get(@pReference)
    Set tFormat = ##class(%Studio.Global).format(tValue, .tOut, 1)
    Quit $ListBuild(pReference, $Extract(tOut, 1, 1001), $Length(tValue), tFormat, ($ZStrip(tValue, "*C") '= tValue), $Data(@pReference))
}

/// <p><method>VendorWalk</method> that keeps only the nodes whose value <method>Matches</method> <var>pFind</var> (<var>pMatchCase</var>),
/// and stops after visiting <parameter>REPLACESCAN</parameter> nodes. <var>pLast</var> is the last node it visited, <var>pMore</var> is
/// whether a node follows it, so a page that scanned without filling continues after <var>pLast</var>. The namespace is switched for the
/// call alone.</p>
ClassMethod VendorFindWalk(pNamespace As %String, pName As %String, pFrom As %String, pAfter As %String, pSize As %Integer, pFind As %String, pMatchCase As %Boolean, Output pRaw, Output pMore As %Boolean, Output pLast As %String, Output pCaught)
{
    Kill pRaw
    Set pRaw = 0
    Set pMore = 0
    Set pLast = ""
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRoot = "^" _ pName
        Set tRef = $Select(pAfter '= "": pAfter, pFrom '= "": pFrom, 1: tRoot)
        If (pAfter = "") && ($Data(@tRef) # 2) {
            Set tNext = tRef
        } Else {
            Set tNext = $Query(@tRef)
        }
        Set tVisited = 0
        While (tNext '= "") && (pRaw < pSize) && (tVisited < ..#REPLACESCAN) {
            Set tVisited = tVisited + 1
            Set pLast = tNext
            If ..Matches($Get(@tNext), pFind, pMatchCase) {
                Set pRaw = pRaw + 1
                Set pRaw(pRaw) = ..RawRow(tNext)
            }
            Set tNext = $Query(@tNext)
        }
        Set pMore = (tNext '= "")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>A vendor exception <var>pException</var> in this port's own words: <code>&lt;PROTECT&gt;</code> is 403
/// <code>PORT.ACCESSDENIED</code>, unlogged; anything else is 500 <code>INTERNAL</code>. Both log <var>pMessage</var> and the
/// exception's text (<var>pQuiet</var> 0) or its name alone (<var>pQuiet</var> 1, the node page and every node call: a vendor text can name a subscript).</p>
ClassMethod Mapped(pException As %Exception.AbstractException, pMessage As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pQuiet As %Boolean = 0) As %Status [ Private ]
{
    Set tProtect = 0
    Try {
        Set tProtect = (pException.Name [ "<PROTECT>")
    } Catch {
        Set tProtect = 0
    }
    If tProtect {
        Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .pFault, .tDetail)
        Set pHttpStatus = 403
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED)
    }
    Quit ..Fail(pMessage, $Select(pQuiet: $$$ERROR($$$GeneralError, pException.Name), 1: pException.AsStatus()), .pHttpStatus, .pFault)
}

/// <p>The privilege refusal naming <var>pFailedPair</var> (AD-8, AD-39).</p>
ClassMethod Deny(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDenial = ##class(OcuPilot.Kernel.Denial).Detail(pFailedPair)
    Quit ..Refuse(##class(OcuPilot.Kernel.Denial).#STATUS, ##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason(), .pHttpStatus, .pFault, tDenial)
}

/// <p>A refusal this port decided, with a written reason. <var>pDetail</var>, when supplied, becomes the fault's <code>detail</code>
/// (AD-39).</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pDetail As %DynamicObject = "") As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    If $IsObject(pDetail) Do pFault.%Set("detail", pDetail)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>The refusal <var>pCode</var> of <class>OcuPilot.Api.GlobalError</class>, with its published sentence, status and slug.</p>
ClassMethod Violation(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(##class(OcuPilot.Api.GlobalError).HttpStatusFor(pCode), ##class(OcuPilot.Api.GlobalError).SlugFor(pCode), pCode, ##class(OcuPilot.Api.GlobalError).ReasonFor(pCode), .pHttpStatus, .pFault)
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p><code>objectscript</code> for the four writes this port carries (<code>Globals</code> <code>DELETE</code> and
/// <code>REPLACEALL</code>, <code>Node</code> <code>PUT</code> and <code>DELETE</code>); <code>""</code> for a read, which has no script
/// form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If (pEndpoint = ..#ENDPOINTGLOBALS) && ((pType = ..#TYPEDELETE) || (pType = ..#TYPEREPLACEALL)) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTNODE) && ((pType = ..#TYPEPUT) || (pType = ..#TYPEDELETE)) Quit "objectscript"
    Quit ""
}

/// <p><method>Invoke</method>'s write branches as a script (AD-59), in the namespace <parameter>NAMESPACEKEY</parameter> names: a global's
/// delete is <code>Kill</code> of its name, a node's the <code>Set</code> or <code>Kill</code> of the reference. Every value, a reference
/// and a node's value included, is rendered as a string literal and reached by name indirection, so nothing the query carries runs as code.
/// A global's find and replace (<code>REPLACEALL</code>) is <method>ReplaceScript</method>. Every line of a script opens no block it does
/// not close on that line. A read writes nothing and answers no step.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tText = " Set $NAMESPACE = " _ ..Literal($Get(pQuery(..#NAMESPACEKEY)))
    If (pEndpoint = ..#ENDPOINTGLOBALS) && (pType = ..#TYPEREPLACEALL) {
        Set tText = tText _ ..ReplaceScript(.pQuery)
    } ElseIf pEndpoint = ..#ENDPOINTGLOBALS {
        Set tText = tText _ $Char(10) _ " Set tGlobal = " _ ..Literal("^" _ $Get(pQuery(..#NAMEKEY))) _ $Char(10) _ " Kill @tGlobal"
    } Else {
        Set tText = tText _ $Char(10) _ " Set tNode = " _ ..Literal($Get(pQuery(..#REFERENCEKEY))) _ $Char(10)
        Set tText = tText _ $Select(pType = ..#TYPEPUT: " Set @tNode = " _ ..Literal($Get(pQuery(..#VALUEKEY))), 1: " Kill @tNode")
    }
    Set tStep = {}
    Do tStep.%Set("kind", "objectscript", "string")
    Do tStep.%Set("text", tText, "string")
    Quit [(tStep)]
}

/// <p>The lines, each led by a line feed, that make <method>ReplacingRun</method>'s write: walk the named global in <code>$Query</code>
/// order, the root included, and in each plain-text value (<method>Candidate</method>'s test) replace every occurrence of the find text
/// left to right without overlap, matching case unless <parameter>MATCHCASEKEY</parameter> is <code>0</code> and leaving a value alone
/// when its lower-case form, or the find's, changes length (<method>Replaced</method>), setting only a value that changes, all in one
/// transaction rolled back on error. The namespace, name, find, replace and match-case flag are string literals, never code; only the name
/// is reached by indirection. It carries none of the write's refusals (the bounds, the digest, the <code>%SYS</code> namespace): the
/// proposal it is drawn from passed them at its read, and whoever runs it is checked by the instance (AD-59).</p>
ClassMethod ReplaceScript(ByRef pQuery) As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tText = tNL _ " Set tRoot = " _ ..Literal("^" _ $Get(pQuery(..#NAMEKEY)))
    Set tText = tText _ tNL _ " Set tFind = " _ ..Literal($Get(pQuery(..#FINDKEY)))
    Set tText = tText _ tNL _ " Set tReplace = " _ ..Literal($Get(pQuery(..#REPLACEKEY)))
    Set tText = tText _ tNL _ " Set tMatchCase = (" _ ..Literal($Get(pQuery(..#MATCHCASEKEY))) _ " '= ""0"")"
    Set tText = tText _ tNL _ " Set tNeedle = $Select(tMatchCase: tFind, 1: $ZConvert(tFind, ""L""))"
    Set tText = tText _ tNL _ " Set tLevel = $TLevel, tNext = $Select($Data(@tRoot) # 2: tRoot, 1: $Query(@tRoot))"
    Set tText = tText _ tNL _ " TSTART"
    Set tText = tText _ tNL _ " Try { While tNext '= """" { Set tValue = $Get(@tNext) If ($ZStrip(tValue, ""*C"") = tValue) && (##class(%Studio.Global).format(tValue, .tOut, 1) = 1) && (tFind '= """") && ($Length(tNeedle) = $Length(tFind)) {"
    Set tText = tText _ " Set tHay = $Select(tMatchCase: tValue, 1: $ZConvert(tValue, ""L"")) If $Length(tHay) = $Length(tValue) { Set tNew = """", tFrom = 1"
    Set tText = tText _ " For { Set tAt = $Find(tHay, tNeedle, tFrom) Quit:tAt=0  Set tNew = tNew _ $Extract(tValue, tFrom, tAt - $Length(tNeedle) - 1) _ tReplace, tFrom = tAt }"
    Set tText = tText _ " Set tNew = tNew _ $Extract(tValue, tFrom, *) If tNew '= tValue Set @tNext = tNew } } Set tNext = $Query(@tNext) } TCOMMIT }"
    Set tText = tText _ " Catch tEx { While $TLevel > tLevel { TROLLBACK 1 } Throw tEx }"
    Quit tText
}

/// <p><var>pValue</var> as an ObjectScript string literal, a control character spelled as a <code>$Char</code>.</p>
ClassMethod Literal(pValue As %String) As %String [ Private ]
{
    Set tText = """" _ $Replace(pValue, """", """""") _ """"
    For tCode = 0:1:31 {
        If tText [ $Char(tCode) Set tText = $Replace(tText, $Char(tCode), """_$Char(" _ tCode _ ")_""")
    }
    Quit tText
}

}
