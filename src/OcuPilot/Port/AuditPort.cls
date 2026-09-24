/// <p>The audit database's port (AD-52): <class>OcuPilot.Port.AdminPort</class> with
/// <parameter>RECORDENDPOINT</parameter>'s copy and purge composed from the calling tool's own
/// arguments. On that endpoint it answers the read type <parameter>DATABASETYPE</parameter> itself,
/// and builds the vendor body for <parameter>COPYTYPE</parameter> and <parameter>PURGETYPE</parameter>
/// from the query (AD-51 as amended 2026-09-24). Every other endpoint and request type is the admin
/// port's own call, unchanged.</p>
/// <p><b>Why the read is the auditing flag.</b> <code>Security.Audit.Record</code>'s
/// <code>GET</code> needs one record's key, and the copy and the purge act on the whole database, so
/// the mint's fresh read, the confirm's re-read, the prohibited set's live read and the screen
/// caller's read are all <code>Security.Audit.Enabled</code>'s <code>GET</code>, behind its own gate
/// (AD-29), with the two argument fields added empty so a merge can set them.</p>
/// <p><b>Why the port composes the body.</b> The tools send none (<code>SENDSBODY</code> 0); the
/// namespace a copy targets and the date a purge cuts off at travel in the port query, and only
/// here do they become the vendor's wire shape. A copy never deletes what it copied, and a purge
/// always sends a cut-off, so neither can become a purge of everything.</p>
/// <p><b>A copy or a purge still running at the bound has started.</b> The vendor's worker carries
/// it on after the admin port stops waiting, so that answer is a success with HTTP
/// <parameter>STARTEDHTTP</parameter>, never <code>PORT.TIMEOUT</code>: the write was made and
/// continues on the instance (AD-26).</p>
/// <p><b>It names no administration API class.</b> Both calls go through
/// <method>OcuPilot.Port.AdminPort.Invoke</method>, so the gate, the stubs, the namespace switch,
/// the queued-write await and the fault mapping are the admin port's (AD-27).</p>
Class OcuPilot.Port.AuditPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint whose read and writes this port composes.</p>
Parameter RECORDENDPOINT = "Security.Audit.Record";

/// <p>The read type this port answers itself: the audit database's state.</p>
Parameter DATABASETYPE = "DATABASE";

/// <p>The vendor's copy and purge request types.</p>
Parameter COPYTYPE = "COPY";

Parameter PURGETYPE = "PURGE";

/// <p>The endpoint and request type the read is answered from.</p>
Parameter ENABLEDENDPOINT = "Security.Audit.Enabled";

Parameter ENABLEDTYPE = "GET";

/// <p>The HTTP status of a copy or a purge the vendor's worker is still running when
/// <method>AsyncTimeout</method> passes: accepted, and continuing on the instance.</p>
Parameter STARTEDHTTP = 202;

/// <p>The query keys the tools' arguments travel under, which are also the fields the read adds
/// empty.</p>
Parameter NAMESPACEQUERY = "CopyNamespace";

Parameter CUTOFFQUERY = "PurgeBefore";

/// <p>The <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> pairs whose vendor body this
/// port composes from the tool's declared arguments, as comma-separated
/// <code>&lt;endpoint&gt;/&lt;type&gt;</code> entries (AD-51).</p>
Parameter COMPOSEDTYPES = "Security.Audit.Record/COPY,Security.Audit.Record/PURGE";

/// <p>The admin port's call, with <parameter>RECORDENDPOINT</parameter>'s
/// <parameter>DATABASETYPE</parameter> and every <parameter>COMPOSEDTYPES</parameter> pair resolved
/// here; a listed pair <method>Body</method> cannot compose is refused, never sent.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s. <parameter>DATABASETYPE</parameter> answers
/// <code>{Enabled, CopyNamespace: "", PurgeBefore: ""}</code>. A copy or a purge sends
/// <method>Body</method>'s answer with an empty query; a query <method>Body</method> cannot compose
/// from is 400 <code>PORT.VALIDATION</code> and nothing is sent. A caller body for either is refused
/// as the admin port refuses one for a constant-body pair. A <parameter>QUEUEDWRITES</parameter>
/// pair the vendor has not finished within <method>AsyncTimeout</method> returns OK with
/// <var>pHttpStatus</var> <parameter>STARTEDHTTP</parameter>, <var>pResult</var> and
/// <var>pFault</var> empty.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If (pEndpoint '= ..#RECORDENDPOINT) || ((pType '= ..#DATABASETYPE) && '$ListFind($ListFromString(..#COMPOSEDTYPES), pEndpoint _ "/" _ pType)) Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If pType = ..#DATABASETYPE {
        Kill tNone
        Set tSC = ##super(..#ENABLEDENDPOINT, ..#ENABLEDTYPE, .tNone, "", .tEnabled, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        If '$IsObject($Get(tEnabled)) || 'tEnabled.%IsA("%Library.DynamicObject") Quit ..Fail(pEndpoint, 500, $$$ERROR($$$GeneralError, "the auditing flag answered no object"), .pHttpStatus, .pFault)
        Set pResult = {}
        Do pResult.%Set("Enabled", tEnabled.%Get("Enabled"), tEnabled.%GetTypeOf("Enabled"))
        Do pResult.%Set(..#NAMESPACEQUERY, "", "string")
        Do pResult.%Set(..#CUTOFFQUERY, "", "string")
        Set pHttpStatus = 200
        Quit $$$OK
    }
    If $IsObject(pBody) || (pBody '= "") {
        Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
        Do ..LogFault(pEndpoint _ " " _ pType _ " was given a caller body, and its body is composed by the port", $$$ERROR($$$GeneralError, "a COMPOSEDTYPES pair takes no caller body"), pFault.code)
        Quit tSC
    }
    Set tBody = ..Body(pType, .pQuery)
    If '$IsObject(tBody) Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "The audit database operation was not given a namespace or a cut-off date it can use", .pHttpStatus, .pFault)
    Kill tNone
    Set tSC = ##super(pEndpoint, pType, .tNone, tBody, .pResult, .pHttpStatus, .pFault)
    ; AD-26: past the bound the queued write has started, and the vendor's worker finishes it.
    If $$$ISERR(tSC) && ..IsQueuedWrite(pEndpoint, pType) && $IsObject(pFault) && (pFault.%Get("code") = ##class(OcuPilot.Api.Error).#PORTTIMEOUT) {
        Set pResult = ""
        Set pHttpStatus = ..#STARTEDHTTP
        Set pFault = ""
        Quit $$$OK
    }
    Quit tSC
}

/// <p>The vendor body for <var>pType</var>, composed from <var>pQuery</var>, or <code>""</code> when
/// the query cannot supply it.</p>
/// <p><parameter>COPYTYPE</parameter>: <code>{AuditCopyNamespace, DeleteAfterCopy: false,
/// BeginDateTime: "", EndDateTime: ""}</code> from a non-empty
/// <parameter>NAMESPACEQUERY</parameter>, which copies every record and deletes none.
/// <parameter>PURGETYPE</parameter>: <code>{BeginDateTime: "", EndDateTime: "&lt;date&gt;
/// 00:00:00"}</code> from a <parameter>CUTOFFQUERY</parameter> of the form
/// <code>YYYY-MM-DD</code>, which removes every record dated before that day's midnight, instance
/// time, and none after it. Any other type answers <code>""</code>.</p>
ClassMethod Body(pType As %String, ByRef pQuery) As %DynamicObject
{
    If pType = ..#COPYTYPE {
        Set tNamespace = $Get(pQuery(..#NAMESPACEQUERY))
        If tNamespace = "" Quit ""
        Set tBody = {}
        Do tBody.%Set("AuditCopyNamespace", tNamespace, "string")
        Do tBody.%Set("DeleteAfterCopy", 0, "boolean")
        Do tBody.%Set("BeginDateTime", "", "string")
        Do tBody.%Set("EndDateTime", "", "string")
        Quit tBody
    }
    If pType = ..#PURGETYPE {
        Set tCutoff = $Get(pQuery(..#CUTOFFQUERY))
        If '$Match(tCutoff, "^\d{4}-\d{2}-\d{2}$") Quit ""
        Set tBody = {}
        Do tBody.%Set("BeginDateTime", "", "string")
        Do tBody.%Set("EndDateTime", tCutoff _ " 00:00:00", "string")
        Quit tBody
    }
    Quit ""
}

}
