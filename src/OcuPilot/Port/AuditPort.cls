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

/// <p>The secrets IRIS writes in plain text into its own audit rows, declared per vendor event
/// (AD-35 as amended 2026-09-25, DW-1640): semicolon-separated
/// <code>&lt;event&gt;=&lt;key&gt;[:&lt;key&gt;...]</code> entries, where <code>&lt;event&gt;</code>
/// is the leading words of the row's <code>Description</code> under
/// <parameter>VENDORSECRETSOURCE</parameter> and <code>&lt;key&gt;</code> a property or metadata
/// member name whose value the row's <code>EventData</code> carries. Measured on a throwaway: the
/// server definition rows carry <code>InitialAccessToken</code>, and the client and client metadata
/// rows <code>registration_access_token</code>, each in a <code>modified</code> block, a property
/// line or the metadata's JSON; the vendor masks the client secret, the password and the key sets
/// itself. A secret found in any other event is a new entry here.</p>
Parameter VENDORSECRETS = "Create OAuth2 Server Definition=InitialAccessToken:registration_access_token;Modify OAuth2 Server Definition=InitialAccessToken:registration_access_token;Create OAuth2 Client Metadata=registration_access_token;Modify OAuth2 Client Metadata=registration_access_token;Create OAuth2 Client=registration_access_token;Modify OAuth2 Client=registration_access_token";

/// <p>The vendor event every <parameter>VENDORSECRETS</parameter> entry is a row of:
/// <code>&lt;source&gt;/&lt;type&gt;/&lt;name&gt;</code>.</p>
Parameter VENDORSECRETSOURCE = "%System/%Security/OAuth2";

/// <p>What a masked value reads, the vendor's own mask.</p>
Parameter MASK = "*****";

/// <p>The resource server authenticator settings IRIS writes in plain text into its own audit rows,
/// declared per vendor event (AD-35 as amended 2026-09-25, Story 12.6): semicolon-separated
/// <code>&lt;event&gt;=&lt;key&gt;</code> entries, where <code>&lt;event&gt;</code> is the leading
/// words of the row's <code>Description</code> under <parameter>VENDORSETTINGSOURCE</parameter> and
/// <code>&lt;key&gt;</code> the property whose value is the authenticator as JSON. In that JSON every
/// member whose name is a credential's (Conventions, Secrets), which the resource server tools
/// classify secret, is masked. Measured on a throwaway: the Create and Modify rows carry the
/// authenticator on a property line, and a Modify row also in a <code>modified</code> block.</p>
Parameter VENDORSETTINGSECRETS = "Create Resource Server=Authenticator;Modify Resource Server=Authenticator";

/// <p>The vendor event every <parameter>VENDORSETTINGSECRETS</parameter> entry is a row of.</p>
Parameter VENDORSETTINGSOURCE = "%System/%Security/OAuth2ResourceServerChange";

/// <p>Mask, in place, the declared secrets (<parameter>VENDORSECRETS</parameter> and
/// <parameter>VENDORSETTINGSECRETS</parameter>) in the
/// <code>EventData</code> of every row of <var>pRows</var>, an audit record read's rows.</p>
/// <p><b>Caller contract:</b> <class>OcuPilot.Screen.Read</class> calls it on every
/// <parameter>RECORDENDPOINT</parameter> answer before it projects a row, so the Logs audit screen and
/// <code>logs.audit.read</code> read the same masked rows. A row of another event, or a value a
/// declared key does not name, is unchanged.</p>
ClassMethod MaskVendorSecrets(pRows As %DynamicArray)
{
    If '$IsObject(pRows) || 'pRows.%IsA("%Library.DynamicArray") Quit
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") Continue
        If tRow.%GetTypeOf("EventData") '= "string" Continue
        Set tSettings = ..SettingKeys(tRow)
        If tSettings '= "" Do tRow.%Set("EventData", ..MaskedSettingData(tRow.%Get("EventData"), tSettings), "string")
        Set tKeys = ..SecretKeys(tRow)
        If tKeys = "" Continue
        Do tRow.%Set("EventData", ..MaskedEventData(tRow.%Get("EventData"), tKeys), "string")
    }
}

/// <p>The keys <parameter>VENDORSECRETS</parameter> declares for <var>pRow</var>'s event, as a
/// <class>%List</class>, or <code>""</code>. The longest declared event its <code>Description</code>
/// begins with, as whole words, wins.</p>
ClassMethod SecretKeys(pRow As %DynamicObject) As %List
{
    Set tSource = pRow.%Get("EventSource") _ "/" _ pRow.%Get("EventType") _ "/" _ pRow.%Get("Event")
    If tSource '= ..#VENDORSECRETSOURCE Quit ""
    Set tDescription = pRow.%Get("Description")
    Set (tKeys, tMatched) = ""
    For tI = 1:1:$Length(..#VENDORSECRETS, ";") {
        Set tEntry = $Piece(..#VENDORSECRETS, ";", tI)
        Set tEvent = $Piece(tEntry, "=", 1)
        If (tDescription '= tEvent) && ($Extract(tDescription, 1, $Length(tEvent) + 1) '= (tEvent _ " ")) Continue
        If $Length(tEvent) <= $Length(tMatched) Continue
        Set tMatched = tEvent
        Set tKeys = $ListFromString($Piece(tEntry, "=", 2), ":")
    }
    Quit tKeys
}

/// <p><var>pData</var>, a vendor row's <code>EventData</code>, with each value of a key in
/// <var>pKeys</var> replaced by <parameter>MASK</parameter> in the three places the vendor writes one:
/// the <code>New value</code> and <code>Old value</code> lines under a
/// <code>&lt;key&gt; modified:</code> or <code>metadata.&lt;key&gt; modified:</code> line; a
/// <code>&lt;key&gt;:</code> property line; and the member of that name in a
/// <code>Metadata:</code> line's JSON. An empty value stays empty.</p>
ClassMethod MaskedEventData(pData As %String, pKeys As %List) As %String
{
    Set tBreak = $Char(13, 10)
    If pData '[ tBreak Set tBreak = $Char(10)
    Set tOut = ""
    Set tMasking = 0
    For tI = 1:1:$Length(pData, tBreak) {
        Set tLine = $Piece(pData, tBreak, tI)
        Set tTrimmed = $ZStrip(tLine, "<>W")
        If tMasking && (($Extract(tTrimmed, 1, 10) = "New value:") || ($Extract(tTrimmed, 1, 10) = "Old value:")) {
            Set tLine = ..MaskedAfter(tLine, ":")
            Set tMasking = tMasking - 1
        } Else {
            Set tMasking = 0
            For tK = 1:1:$ListLength(pKeys) {
                Set tKey = $List(pKeys, tK)
                If (tTrimmed = (tKey _ " modified:")) || (tTrimmed = ("metadata." _ tKey _ " modified:")) {
                    Set tMasking = 2
                } ElseIf $Extract(tTrimmed, 1, $Length(tKey) + 1) = (tKey _ ":") {
                    Set tLine = ..MaskedAfter(tLine, ":")
                }
            }
            If $Extract(tTrimmed, 1, 9) = "Metadata:" Set tLine = ..MaskedMetadataLine(tLine, pKeys)
        }
        Set tOut = tOut _ $Select(tI = 1: "", 1: tBreak) _ tLine
    }
    Quit tOut
}

/// <p><var>pLine</var> with the non-empty text after its first <var>pDelimiter</var> and the spaces
/// that follow it replaced by <parameter>MASK</parameter>.</p>
ClassMethod MaskedAfter(pLine As %String, pDelimiter As %String) As %String [ Private ]
{
    Set tHead = $Piece(pLine, pDelimiter, 1) _ pDelimiter
    Set tRest = $Extract(pLine, $Length(tHead) + 1, *)
    If $ZStrip(tRest, "<>W") = "" Quit pLine
    Set tPad = $Extract(tRest, 1, $Length(tRest) - $Length($ZStrip(tRest, "<W")))
    Quit tHead _ tPad _ ..#MASK
}

/// <p>A <code>Metadata:</code> property line <var>pLine</var> with each member <var>pKeys</var> names
/// in its JSON masked. A line whose JSON does not parse is answered as a masked line, because a
/// declared secret may sit inside it.</p>
ClassMethod MaskedMetadataLine(pLine As %String, pKeys As %List) As %String [ Private ]
{
    Set tHead = $Piece(pLine, ":", 1) _ ":"
    Set tRest = $Extract(pLine, $Length(tHead) + 1, *)
    Set tJson = $ZStrip(tRest, "<>W")
    If tJson = "" Quit pLine
    Set tPad = $Extract(tRest, 1, $Length(tRest) - $Length($ZStrip(tRest, "<W")))
    Try {
        Set tObject = ##class(%DynamicAbstractObject).%FromJSON(tJson)
        If '$IsObject(tObject) || 'tObject.%IsA("%Library.DynamicObject") {
            Set tJson = ..#MASK
            Quit
        }
        For tK = 1:1:$ListLength(pKeys) {
            Set tKey = $List(pKeys, tK)
            If (tObject.%GetTypeOf(tKey) = "string") && (tObject.%Get(tKey) '= "") Do tObject.%Set(tKey, ..#MASK, "string")
        }
        Set tJson = tObject.%ToJSON()
    } Catch {
        Set tJson = ..#MASK
    }
    Quit tHead _ tPad _ tJson
}

/// <p>The keys <parameter>VENDORSETTINGSECRETS</parameter> declares for <var>pRow</var>'s event, as a
/// <class>%List</class>, or <code>""</code>. The longest declared event its <code>Description</code>
/// begins with, as whole words, wins.</p>
ClassMethod SettingKeys(pRow As %DynamicObject) As %List
{
    Set tSource = pRow.%Get("EventSource") _ "/" _ pRow.%Get("EventType") _ "/" _ pRow.%Get("Event")
    If tSource '= ..#VENDORSETTINGSOURCE Quit ""
    Set tDescription = pRow.%Get("Description")
    Set (tKeys, tMatched) = ""
    For tI = 1:1:$Length(..#VENDORSETTINGSECRETS, ";") {
        Set tEntry = $Piece(..#VENDORSETTINGSECRETS, ";", tI)
        Set tEvent = $Piece(tEntry, "=", 1)
        If (tDescription '= tEvent) && ($Extract(tDescription, 1, $Length(tEvent) + 1) '= (tEvent _ " ")) Continue
        If $Length(tEvent) <= $Length(tMatched) Continue
        Set tMatched = tEvent
        Set tKeys = $ListFromString($Piece(tEntry, "=", 2), ":")
    }
    Quit tKeys
}

/// <p><var>pData</var>, a vendor row's <code>EventData</code>, with the credential-named members of
/// the JSON each key in <var>pKeys</var> holds replaced by <parameter>MASK</parameter>, in the two
/// places the vendor writes it: the <code>New value</code> and <code>Old value</code> lines under a
/// <code>&lt;key&gt; modified:</code> line, and a <code>&lt;key&gt;:</code> property line.</p>
ClassMethod MaskedSettingData(pData As %String, pKeys As %List) As %String
{
    Set tBreak = $Char(13, 10)
    If pData '[ tBreak Set tBreak = $Char(10)
    Set tOut = ""
    Set tMasking = 0
    For tI = 1:1:$Length(pData, tBreak) {
        Set tLine = $Piece(pData, tBreak, tI)
        Set tTrimmed = $ZStrip(tLine, "<>W")
        If tMasking && (($Extract(tTrimmed, 1, 10) = "New value:") || ($Extract(tTrimmed, 1, 10) = "Old value:")) {
            Set tLine = ..MaskedSettingLine(tLine)
            Set tMasking = tMasking - 1
        } Else {
            Set tMasking = 0
            For tK = 1:1:$ListLength(pKeys) {
                Set tKey = $List(pKeys, tK)
                If tTrimmed = (tKey _ " modified:") {
                    Set tMasking = 2
                } ElseIf $Extract(tTrimmed, 1, $Length(tKey) + 1) = (tKey _ ":") {
                    Set tLine = ..MaskedSettingLine(tLine)
                }
            }
        }
        Set tOut = tOut _ $Select(tI = 1: "", 1: tBreak) _ tLine
    }
    Quit tOut
}

/// <p><var>pLine</var>, whose text after its first colon is an authenticator's JSON, with each
/// non-empty member whose name is a credential's masked. A line whose JSON does not parse is answered
/// as a masked line, because a credential setting may sit inside it.</p>
ClassMethod MaskedSettingLine(pLine As %String) As %String [ Private ]
{
    Set tHead = $Piece(pLine, ":", 1) _ ":"
    Set tRest = $Extract(pLine, $Length(tHead) + 1, *)
    Set tJson = $ZStrip(tRest, "<>W")
    If tJson = "" Quit pLine
    Set tPad = $Extract(tRest, 1, $Length(tRest) - $Length($ZStrip(tRest, "<W")))
    Try {
        Set tObject = ##class(%DynamicAbstractObject).%FromJSON(tJson)
        If '$IsObject(tObject) || 'tObject.%IsA("%Library.DynamicObject") {
            Set tJson = ..#MASK
            Quit
        }
        Set tNames = ""
        Set tIterator = tObject.%GetIterator()
        While tIterator.%GetNext(.tName, .tValue) {
            If ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tName) && (tValue '= "") Set tNames = tNames _ $ListBuild(tName)
        }
        For tN = 1:1:$ListLength(tNames) Do tObject.%Set($List(tNames, tN), ..#MASK, "string")
        Set tJson = tObject.%ToJSON()
    } Catch {
        Set tJson = ..#MASK
    }
    Quit tHead _ tPad _ tJson
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
