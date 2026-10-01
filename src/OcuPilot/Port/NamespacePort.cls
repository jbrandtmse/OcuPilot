/// <p>The namespace mappings' port (AD-52, Story 18.14): <class>OcuPilot.Port.AdminPort</class> with
/// two things added, each on a named endpoint, and every other call the admin port's own,
/// unchanged.</p>
/// <p><b>A vendor refusal of a mapping's name answers on the field.</b> A mapping write whose fault
/// names a <code>MAPPING.*</code> field is answered 422 <code>MAPPING.VALIDATION</code> with its
/// violations (<method>Refused</method>).</p>
/// <p><b>A mapping's composite id is split here.</b> The three
/// <parameter>MAPPINGENDPOINTS</parameter> address a mapping by the <code>namespace</code> and
/// <code>name</code> query parameters, while the product carries one id, <code>[namespace,
/// Name]</code> joined by <method>OcuPilot.Kernel.EntityId.JoinComposite</method>, under
/// <code>name</code>. A query that already carries <code>namespace</code> -- a list, and every
/// re-read the port makes itself -- passes through unchanged. Otherwise the namespace part is sent
/// upper-cased, the spelling the instance stores (Story 18.2), and the name part as it is, because a
/// global or routine name is case-sensitive. An id that is not exactly two non-empty parts names no
/// mapping: 404 <code>PORT.NOTFOUND</code>, and the vendor is not called.</p>
/// <p><b>A copy of mappings is composed here</b> (AD-51 as amended 2026-09-28). The copy tool sends
/// no body; the destination is its target id, in <code>name</code>, and the source travels as
/// <parameter>SOURCEQUERY</parameter>. This port builds <code>{SourceNamespace,
/// DestinationNamespace}</code>, both upper-cased, and sends it with an empty query. The vendor
/// queues the copy (<parameter>OcuPilot.Port.AdminPort.QUEUEDWRITES</parameter>) and the admin
/// port's <code>AwaitTask</code> is its one poller, reading the finished result once. A copy still
/// running at the bound has started: success with HTTP <parameter>STARTEDHTTP</parameter>, never
/// <code>PORT.TIMEOUT</code> (AD-26), and nothing reads its task again.</p>
/// <p><b>An enable of interoperability is sent here</b> (AD-26, Story 18.15). The enable tool sends
/// no body; its target, in <code>name</code>, is sent upper-cased in the query alone. The vendor queues
/// it (<parameter>OcuPilot.Port.AdminPort.QUEUEDWRITES</parameter>), the admin port's
/// <code>AwaitTask</code> reads the finished result once, and past the bound it has started, as a copy
/// has.</p>
/// <p><b>The copy tool's read adds its argument field.</b> <code>Namespace.Namespace</code>'s
/// <code>GET</code> through this port answers the vendor's object with
/// <parameter>SOURCEQUERY</parameter> added empty, so a merge of the tool's argument makes the one
/// diff row (the <class>OcuPilot.Port.AuditPort</class> precedent).</p>
/// <p><b>It names no administration API class.</b> Every call goes through
/// <method>OcuPilot.Port.AdminPort.Invoke</method>, so the gate, the stubs, the namespace switch, the
/// queued-write await and the fault mapping are the admin port's (AD-27).</p>
Class OcuPilot.Port.NamespacePort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoints whose composite id this port splits.</p>
Parameter MAPPINGENDPOINTS = "Namespace.GlobalMappings,Namespace.RoutineMappings,Namespace.PackageMappings";

/// <p>The endpoint whose copy of mappings this port composes, and whose read it answers with the
/// copy's argument added.</p>
Parameter NAMESPACEENDPOINT = "Namespace.Namespace";

/// <p>The one pair whose body this port composes from the query rather than takes from its caller
/// (AD-51 as amended by Story 12.3): the vendor's copy of mappings, sent
/// <code>{SourceNamespace, DestinationNamespace}</code>.</p>
Parameter COMPOSEDTYPES = "Namespace.Namespace/MAPPINGS";

/// <p>The one pair this port sends with its target alone, upper-cased, and no body: the vendor's
/// enable of interoperability.</p>
Parameter INTEROPTYPES = "Namespace.Namespace/INTEROP";

/// <p>The read type whose answer gains <parameter>SOURCEQUERY</parameter>.</p>
Parameter READTYPE = "GET";

/// <p>The query key the copy's source travels under, which is also the field the read adds
/// empty.</p>
Parameter SOURCEQUERY = "SourceNamespace";

/// <p>The query key the target id travels under.</p>
Parameter IDQUERY = "name";

/// <p>The vendor's query keys a mapping is addressed by.</p>
Parameter NAMESPACEPARAM = "namespace";

Parameter NAMEPARAM = "name";

/// <p>The HTTP status of a copy the vendor's worker is still running when
/// <method>AsyncTimeout</method> passes: accepted, and continuing on the instance.</p>
Parameter STARTEDHTTP = 202;

/// <p>The admin port's call, with a mapping's composite id split and the copy of mappings composed
/// here.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s. For a <parameter>MAPPINGENDPOINTS</parameter>
/// call whose query carries no <code>namespace</code>, <code>name</code> is the composite id; a
/// malformed one is 404 <code>PORT.NOTFOUND</code> with no vendor call. For
/// the <parameter>COMPOSEDTYPES</parameter> pair, <code>name</code> is
/// the destination and <parameter>SOURCEQUERY</parameter> the source; a caller body is refused as
/// the admin port refuses one for a constant-body pair, a query missing either is 400
/// <code>PORT.VALIDATION</code>, and a copy not finished within <method>AsyncTimeout</method>
/// returns OK with <var>pHttpStatus</var> <parameter>STARTEDHTTP</parameter> and <var>pResult</var>
/// and <var>pFault</var> empty. For the <parameter>INTEROPTYPES</parameter> pair, <code>name</code> is
/// the namespace, sent upper-cased; a caller body is refused the same way, and an enable not finished
/// within <method>AsyncTimeout</method> is answered as a copy is. <parameter>NAMESPACEENDPOINT</parameter>'s
/// <parameter>READTYPE</parameter> answers the vendor's object with <parameter>SOURCEQUERY</parameter>
/// added empty.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If ..IsMappingEndpoint(pEndpoint) && '($Data(pQuery(..#NAMESPACEPARAM)) # 2) {
        Set pResult = ""
        Set pHttpStatus = 0
        Set pFault = ""
        If '..MappingQuery(.pQuery, .tQuery) Quit ..Fail(pEndpoint, 404, $$$OK, .pHttpStatus, .pFault)
        Set tSC = ##super(pEndpoint, pType, .tQuery, pBody, .pResult, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Do ..Refused(.pHttpStatus, .pFault)
        Quit tSC
    }
    If (pEndpoint = ..#NAMESPACEENDPOINT) && (pType = ..#READTYPE) {
        Set tSC = ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
        If $$$ISOK(tSC) && $IsObject($Get(pResult)) && pResult.%IsA("%Library.DynamicObject") Do pResult.%Set(..#SOURCEQUERY, "", "string")
        Quit tSC
    }
    If $ListFind($ListFromString(..#COMPOSEDTYPES), pEndpoint _ "/" _ pType) {
        Set pResult = ""
        Set pHttpStatus = 0
        Set pFault = ""
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " " _ pType _ " was given a caller body, and its body is composed by the port", $$$ERROR($$$GeneralError, "a copy of mappings takes no caller body"), pFault.code)
            Quit tSC
        }
        Set tBody = ..CopyBody(.pQuery)
        If '$IsObject(tBody) Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "The copy of mappings was not given a source and a destination namespace it can use", .pHttpStatus, .pFault)
        Kill tNone
        Set tSC = ##super(pEndpoint, pType, .tNone, tBody, .pResult, .pHttpStatus, .pFault)
        Quit ..Started(pEndpoint, pType, tSC, .pResult, .pHttpStatus, .pFault)
    }
    If $ListFind($ListFromString(..#INTEROPTYPES), pEndpoint _ "/" _ pType) {
        Set pResult = ""
        Set pHttpStatus = 0
        Set pFault = ""
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " " _ pType _ " was given a caller body, and it sends none", $$$ERROR($$$GeneralError, "an enable of interoperability takes no caller body"), pFault.code)
            Quit tSC
        }
        Do ..InteropQuery(.pQuery, .tQuery)
        Set tSC = ##super(pEndpoint, pType, .tQuery, "", .pResult, .pHttpStatus, .pFault)
        Quit ..Started(pEndpoint, pType, tSC, .pResult, .pHttpStatus, .pFault)
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>AD-26: a queued write whose task is not terminal at the bound has started, and the vendor's
/// worker finishes it, so its <code>PORT.TIMEOUT</code> answers <var>pSC</var>'s caller OK with
/// <parameter>STARTEDHTTP</parameter> and an empty result and fault. Every other outcome is
/// <var>pSC</var> as it is.</p>
ClassMethod Started(pEndpoint As %String, pType As %String, pSC As %Status, ByRef pResult, ByRef pHttpStatus As %Integer, ByRef pFault As %DynamicObject) As %Status [ Private ]
{
    If $$$ISERR(pSC) && ..IsQueuedWrite(pEndpoint, pType) && $IsObject($Get(pFault)) && (pFault.%Get("code") = ##class(OcuPilot.Api.Error).#PORTTIMEOUT) {
        Set pResult = ""
        Set pHttpStatus = ..#STARTEDHTTP
        Set pFault = ""
        Quit $$$OK
    }
    Quit pSC
}

/// <p>The query an enable of interoperability sends, in <var>pSent</var>: <var>pQuery</var>'s
/// <parameter>IDQUERY</parameter> alone, upper-cased, the spelling the instance stores.</p>
ClassMethod InteropQuery(ByRef pQuery, Output pSent)
{
    Kill pSent
    Set pSent(..#IDQUERY) = $ZConvert($Get(pQuery(..#IDQUERY)), "U")
}

/// <p>Turn a mapping write's fault that names a <code>MAPPING.*</code> field refusal
/// (<parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter>) into the 422
/// <code>MAPPING.VALIDATION</code> refusal it is, keeping its <code>detail.violations</code>: the
/// vendor refused the name and changed nothing (measured on <code>ocupilot-b-ci</code>), so each
/// caller answers it on the field rather than as an internal error. When one such row is the whole
/// refusal, its sentence is the envelope's reason too, so a row action on a list, which has no field
/// to show it on, says what to do. Any other fault is left as it is.</p>
ClassMethod Refused(ByRef pHttpStatus As %Integer, ByRef pFault As %DynamicObject) [ Private ]
{
    If '$IsObject($Get(pFault)) || (pFault.%GetTypeOf("detail") '= "object") Quit
    Set tRows = pFault.%Get("detail").%Get("violations")
    If '$IsObject(tRows) Quit
    Set tNamed = 0
    Set tReason = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && ($Piece(tRow.%Get("code"), ".", 1) = "MAPPING") {
            Set tNamed = tNamed + 1
            Set tReason = tRow.%Get("reason")
        }
    }
    If 'tNamed Quit
    If (tNamed '= 1) || (tRows.%Size() '= 1) || (tReason = "") Set tReason = ##class(OcuPilot.Api.Error).#REASONMAPPINGVALIDATION
    Set tDetail = pFault.%Get("detail")
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#MAPPINGVALIDATION, tReason)
    Do pFault.%Set("detail", tDetail)
    Set pHttpStatus = 422
}

/// <p>Whether <var>pEndpoint</var> is one of <parameter>MAPPINGENDPOINTS</parameter>.</p>
ClassMethod IsMappingEndpoint(pEndpoint As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#MAPPINGENDPOINTS), pEndpoint)
}

/// <p>A copy of <var>pQuery</var> in <var>pSplit</var> with its composite <code>name</code> split
/// into the vendor's <code>namespace</code>, upper-cased, and <code>name</code>, as it is; 0 when
/// <code>name</code> is not exactly two non-empty parts.</p>
ClassMethod MappingQuery(ByRef pQuery, Output pSplit) As %Boolean
{
    Kill pSplit
    Merge pSplit = pQuery
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite($Get(pQuery(..#IDQUERY)))
    If $ListLength(tParts) '= 2 Quit 0
    Set tNamespace = $ListGet(tParts, 1)
    Set tName = $ListGet(tParts, 2)
    If (tNamespace = "") || (tName = "") Quit 0
    Set pSplit(..#NAMESPACEPARAM) = $ZConvert(tNamespace, "U")
    Set pSplit(..#NAMEPARAM) = tName
    Quit 1
}

/// <p>The vendor body for a copy of mappings, <code>{SourceNamespace, DestinationNamespace}</code>
/// with both upper-cased, from <var>pQuery</var>'s <parameter>SOURCEQUERY</parameter> and
/// <parameter>IDQUERY</parameter>, or <code>""</code> when either is empty.</p>
ClassMethod CopyBody(ByRef pQuery) As %DynamicObject
{
    Set tSource = $Get(pQuery(..#SOURCEQUERY))
    Set tDestination = $Get(pQuery(..#IDQUERY))
    If (tSource = "") || (tDestination = "") Quit ""
    Set tBody = {}
    Do tBody.%Set("SourceNamespace", $ZConvert(tSource, "U"), "string")
    Do tBody.%Set("DestinationNamespace", $ZConvert(tDestination, "U"), "string")
    Quit tBody
}

/// <p>The admin port's answer: this port's mapping writes and copy are the vendor's own routes.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s branches as a script (AD-59): a mapping call is the vendor call with
/// the split query, and a malformed composite id answers no step; a copy of mappings is the vendor
/// call with <method>CopyBody</method>'s body and an empty query, and a query it cannot compose from
/// answers no step; an enable of interoperability is the vendor call with
/// <method>InteropQuery</method>'s query and no body; every other call is the admin port's
/// script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..IsMappingEndpoint(pEndpoint) && '($Data(pQuery(..#NAMESPACEPARAM)) # 2) {
        If '..MappingQuery(.pQuery, .tQuery) Quit []
        Quit ##super(pEndpoint, pType, .tQuery, pBody, pContext)
    }
    If $ListFind($ListFromString(..#COMPOSEDTYPES), pEndpoint _ "/" _ pType) {
        Set tBody = ..CopyBody(.pQuery)
        If '$IsObject(tBody) Quit []
        Kill tNone
        Quit ##super(pEndpoint, pType, .tNone, tBody, pContext)
    }
    If $ListFind($ListFromString(..#INTEROPTYPES), pEndpoint _ "/" _ pType) {
        Do ..InteropQuery(.pQuery, .tQuery)
        Quit ##super(pEndpoint, pType, .tQuery, "", pContext)
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
}

}
