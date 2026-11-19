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
/// <p><b>The export is the one request type it carries out itself</b> (<parameter>EXPORTTYPE</parameter>): the
/// vendor's own background task, started as the classic export page starts it, because the administration API has
/// no audit export. The file is named by an allowed root and a relative name, never a path (AD-21's sixth case),
/// and a file already at the name is refused, never replaced.</p>
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

/// <p>The export's request type, and the query keys its two file arguments and its optional cut-off day travel
/// under, which are also the fields the read adds empty.</p>
Parameter EXPORTTYPE = "EXPORT";

Parameter EXPORTROOTQUERY = "ExportRoot";

Parameter EXPORTPATHQUERY = "ExportPath";

Parameter EXPORTBEFOREQUERY = "ExportBefore";

/// <p>The export's own pair set, checked in this order in the calling process before any vendor call (AD-29). The
/// vendor's export reads the audit database, so it needs <code>%DB_IRISAUDIT:READ</code> beside the pairs the
/// auditing screen declares, and writes a file, so it needs the file system pair.</p>
Parameter EXPORTPAIRS = "%Admin_Secure:USE,%DB_IRISSYS:READ,%DB_IRISAUDIT:READ,%Admin_FileSystemAccess:USE";

/// <p>The vendor's background task runner, the task it is asked for and the namespace it runs in: what the classic
/// export page starts.</p>
Parameter EXPORTTASKCLASS = "%CSP.UI.System.BackgroundTask";

Parameter EXPORTTASK = "AuditExport";

Parameter EXPORTNAMESPACE = "%SYS";

/// <p>The <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> pairs whose vendor body this
/// port composes from the tool's declared arguments, as comma-separated
/// <code>&lt;endpoint&gt;/&lt;type&gt;</code> entries (AD-51).</p>
Parameter COMPOSEDTYPES = "Security.Audit.Record/COPY,Security.Audit.Record/PURGE,Security.Audit.Record/EXPORT";

/// <p>The admin port's call, with <parameter>RECORDENDPOINT</parameter>'s
/// <parameter>DATABASETYPE</parameter> and every <parameter>COMPOSEDTYPES</parameter> pair resolved
/// here; a listed pair <method>Body</method> cannot compose is refused, never sent.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s. <parameter>DATABASETYPE</parameter> answers
/// <code>{Enabled, CopyNamespace: "", PurgeBefore: "", ExportRoot: "", ExportPath: "", ExportBefore: ""}</code>. A copy or a purge sends
/// <method>Body</method>'s answer with an empty query; a query <method>Body</method> cannot compose
/// from is 400 <code>PORT.VALIDATION</code> and nothing is sent. A caller body for either is refused
/// as the admin port refuses one for a constant-body pair. A <parameter>QUEUEDWRITES</parameter>
/// pair the vendor has not finished within <method>AsyncTimeout</method> returns OK with
/// <var>pHttpStatus</var> <parameter>STARTEDHTTP</parameter>, <var>pResult</var> and
/// <var>pFault</var> empty.</p>
/// <p><parameter>EXPORTTYPE</parameter> is <method>Export</method>: it starts the vendor's export task and
/// answers <var>pHttpStatus</var> <parameter>STARTEDHTTP</parameter> with <var>pResult</var> <code>{id}</code>,
/// the Background tasks row's id, and takes no caller body.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If (pEndpoint = ..#RECORDENDPOINT) && (pType = ..#EXPORTTYPE) Quit ..Export(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
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
        Do pResult.%Set(..#EXPORTROOTQUERY, "", "string")
        Do pResult.%Set(..#EXPORTPATHQUERY, "", "string")
        Do pResult.%Set(..#EXPORTBEFOREQUERY, "", "string")
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
/// itself. The authorization server rows carry <code>ServerPassword</code> in a <code>modified</code>
/// block and on a property line (Story 12.7). The server client rows carry
/// <code>registration_access_token</code> as a metadata <code>modified</code> block and on the
/// <code>Metadata</code> line (Story 12.8). A secret found in any other event is a new entry
/// here.</p>
Parameter VENDORSECRETS = "Create OAuth2 Server Definition=InitialAccessToken:registration_access_token;Modify OAuth2 Server Definition=InitialAccessToken:registration_access_token;Create OAuth2 Client Metadata=registration_access_token;Modify OAuth2 Client Metadata=registration_access_token;Create OAuth2 Client=registration_access_token;Modify OAuth2 Client=registration_access_token;Create OAuth2 Server=ServerPassword;Modify OAuth2 Server=ServerPassword;Create OAuth2 Server Client=registration_access_token;Modify OAuth2 Server Client=registration_access_token";

/// <p>The vendor event every <parameter>VENDORSECRETS</parameter> entry is a row of:
/// <code>&lt;source&gt;/&lt;type&gt;/&lt;name&gt;</code>.</p>
Parameter VENDORSECRETSOURCE = "%System/%Security/OAuth2";

/// <p>The secrets IRIS writes in plain text into its own system change rows, declared in
/// <parameter>VENDORSECRETS</parameter>'s grammar under <parameter>VENDORSYSTEMSOURCE</parameter> (AD-35 as
/// amended 2026-10-07, Story 18.8). Measured on <code>ocupilot-ci</code>: an SMTP password write
/// (<code>Security.WebAuth</code> <code>CHANGESMTPPWD</code>) puts the new password in clear on the
/// <code>New value</code> line under <code>SMTP Password modified:</code> of a "Modify System" row.</p>
Parameter VENDORSYSTEMSECRETS = "Modify System=SMTP Password";

/// <p>The vendor event every <parameter>VENDORSYSTEMSECRETS</parameter> entry is a row of.</p>
Parameter VENDORSYSTEMSOURCE = "%System/%Security/SystemChange";

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

/// <p>The vendor configuration rows whose every <code>Old value</code> and <code>New value</code> line
/// is a secret, declared per vendor event (AD-35): semicolon-separated <code>&lt;event&gt;</code>
/// entries, where <code>&lt;event&gt;</code> is the leading words of the row's <code>Description</code>
/// under <parameter>VENDORCONFIGSOURCE</parameter>. Measured on <code>ocupilot-ci</code>:
/// <code>%SYS.Task.Config.AuthPassSet</code> writes the Task Manager mail password, Base64-encoded,
/// as the <code>Old value</code> and <code>New value</code> of a "Modify Task Config.MailAuthPassword"
/// row, which has no <code>&lt;key&gt; modified:</code> header. The encoding breaks a value longer
/// than 76 characters onto further lines.</p>
Parameter VENDORCONFIGSECRETS = "Modify Task Config.MailAuthPassword";

/// <p>The vendor event every <parameter>VENDORCONFIGSECRETS</parameter> entry is a row of.</p>
Parameter VENDORCONFIGSOURCE = "%System/%System/ConfigurationChange";

/// <p>Mask, in place, the declared secrets (<parameter>VENDORSECRETS</parameter>,
/// <parameter>VENDORSYSTEMSECRETS</parameter>, <parameter>VENDORSETTINGSECRETS</parameter> and
/// <parameter>VENDORCONFIGSECRETS</parameter>) in the <code>EventData</code> of every row of
/// <var>pRows</var>, an audit record read's rows. A row of the fourth family has every
/// <code>Old value</code> and <code>New value</code> masked, the lines a long value continues onto
/// included, so a set, a change and a clear all read masked; a value the vendor left empty stays
/// empty.</p>
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
        If ..ConfigSecret(tRow) {
            Do tRow.%Set("EventData", ..MaskedEventData(tRow.%Get("EventData"), "", 1), "string")
            Continue
        }
        Set tSettings = ..SettingKeys(tRow)
        If tSettings '= "" Do tRow.%Set("EventData", ..MaskedSettingData(tRow.%Get("EventData"), tSettings), "string")
        Set tKeys = ..SecretKeys(tRow)
        If tKeys = "" Continue
        Do tRow.%Set("EventData", ..MaskedEventData(tRow.%Get("EventData"), tKeys), "string")
    }
}

/// <p>The keys <parameter>VENDORSECRETS</parameter>, or <parameter>VENDORSYSTEMSECRETS</parameter> for a
/// system change row, declares for <var>pRow</var>'s event, as a <class>%List</class>, or <code>""</code>.
/// The longest declared event its <code>Description</code> begins with, as whole words, wins.</p>
ClassMethod SecretKeys(pRow As %DynamicObject) As %List
{
    Set tSource = pRow.%Get("EventSource") _ "/" _ pRow.%Get("EventType") _ "/" _ pRow.%Get("Event")
    Set tDeclared = $Select(tSource = ..#VENDORSECRETSOURCE: ..#VENDORSECRETS, tSource = ..#VENDORSYSTEMSOURCE: ..#VENDORSYSTEMSECRETS, 1: "")
    If tDeclared = "" Quit ""
    Set tEntry = ..DeclaredEntry(pRow.%Get("Description"), tDeclared)
    If tEntry = "" Quit ""
    Quit $ListFromString($Piece(tEntry, "=", 2), ":")
}

/// <p>The entry of <var>pDeclared</var>, a semicolon-separated list of
/// <code>&lt;event&gt;[=&lt;keys&gt;]</code> entries, whose <code>&lt;event&gt;</code> the
/// <var>pDescription</var> begins with, as whole words, or <code>""</code>. The longest event wins.</p>
ClassMethod DeclaredEntry(pDescription As %String, pDeclared As %String) As %String [ Private ]
{
    Set (tFound, tMatched) = ""
    For tI = 1:1:$Length(pDeclared, ";") {
        Set tEntry = $Piece(pDeclared, ";", tI)
        Set tEvent = $Piece(tEntry, "=", 1)
        If (pDescription '= tEvent) && ($Extract(pDescription, 1, $Length(tEvent) + 1) '= (tEvent _ " ")) Continue
        If $Length(tEvent) <= $Length(tMatched) Continue
        Set tMatched = tEvent
        Set tFound = tEntry
    }
    Quit tFound
}

/// <p>Whether <var>pRow</var> is a row of an event <parameter>VENDORCONFIGSECRETS</parameter> declares,
/// under <parameter>VENDORCONFIGSOURCE</parameter>.</p>
ClassMethod ConfigSecret(pRow As %DynamicObject) As %Boolean
{
    Set tSource = pRow.%Get("EventSource") _ "/" _ pRow.%Get("EventType") _ "/" _ pRow.%Get("Event")
    If tSource '= ..#VENDORCONFIGSOURCE Quit 0
    Quit ..DeclaredEntry(pRow.%Get("Description"), ..#VENDORCONFIGSECRETS) '= ""
}

/// <p><var>pData</var>, a vendor row's <code>EventData</code>, with each value of a key in
/// <var>pKeys</var> replaced by <parameter>MASK</parameter> in the three places the vendor writes one:
/// the <code>New value</code> and <code>Old value</code> lines under a
/// <code>&lt;key&gt; modified:</code> or <code>metadata.&lt;key&gt; modified:</code> line; a
/// <code>&lt;key&gt;:</code> property line; and the member of that name in a
/// <code>Metadata:</code> line's JSON. With <var>pEveryValue</var> true, every <code>Old value</code>
/// and <code>New value</code> line is masked, header or not, and each line after it up to the next one
/// is dropped, since it continues the value. An empty value stays empty.</p>
ClassMethod MaskedEventData(pData As %String, pKeys As %List, pEveryValue As %Boolean = 0) As %String
{
    Set tBreak = $Char(13, 10)
    If pData '[ tBreak Set tBreak = $Char(10)
    Set tOut = ""
    Set tMasking = 0
    Set tInValue = 0
    For tI = 1:1:$Length(pData, tBreak) {
        Set tLine = $Piece(pData, tBreak, tI)
        Set tTrimmed = $ZStrip(tLine, "<>W")
        Set tValueLine = ($Extract(tTrimmed, 1, 10) = "New value:") || ($Extract(tTrimmed, 1, 10) = "Old value:")
        If tInValue && 'tValueLine Continue
        If (tMasking || pEveryValue) && tValueLine {
            Set tLine = ..MaskedAfter(tLine, ":")
            Set tMasking = $Select(tMasking > 0: tMasking - 1, 1: 0)
            Set tInValue = pEveryValue
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
    Set tEntry = ..DeclaredEntry(pRow.%Get("Description"), ..#VENDORSETTINGSECRETS)
    If tEntry = "" Quit ""
    Quit $ListFromString($Piece(tEntry, "=", 2), ":")
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

/// <p>Start the vendor's audit export (<parameter>EXPORTTYPE</parameter>) and answer
/// <parameter>STARTEDHTTP</parameter>: a task that outlasts the request, so its end is the Background tasks row's to
/// show (AD-26). In order: the gate (<method>ExportGate</method>); a caller body is refused; the file
/// (<method>ExportFile</method>); the cut-off day; then <method>VendorStart</method>. <var>pResult</var> is
/// <code>{id}</code>, the row's composite id. Nothing is written before the vendor call, and no caller value
/// reaches the vendor except as the resolved path and the day.</p>
ClassMethod Export(ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '..ExportGate(.tFailedPair) {
            Set tSC = ..ExportGateRefusal(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
            Do ..LogFault(..#RECORDENDPOINT _ " " _ ..#EXPORTTYPE _ " was given a caller body, and its call is composed by the port", $$$ERROR($$$GeneralError, "a COMPOSEDTYPES pair takes no caller body"), pFault.code)
            Quit
        }
        Set tSC = ..ExportFile($Get(pQuery(..#EXPORTROOTQUERY)), $Get(pQuery(..#EXPORTPATHQUERY)), .tResolved, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tBefore = $Get(pQuery(..#EXPORTBEFOREQUERY))
        If '..BeforeAdmitted(tBefore) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "The audit export was not given a day it can use", .pHttpStatus, .pFault)
            Quit
        }
        Set tJob = 0
        Set tVendorSC = ..VendorStart(tResolved, tBefore, .tJob)
        If $$$ISOK(tVendorSC) && ('+tJob) Set tVendorSC = $$$ERROR($$$GeneralError, "the export task started no job")
        If $$$ISERR(tVendorSC) {
            Set tSC = ..Fail(..#RECORDENDPOINT, 500, tVendorSC, .pHttpStatus, .pFault)
            Quit
        }
        Set pResult = {}
        Do pResult.%Set("id", ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(##class(OcuPilot.Port.BackgroundTaskPort).#SOURCEPORTAL, +tJob)), "string")
        Set pHttpStatus = ..#STARTEDHTTP
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(..#RECORDENDPOINT, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The export's file for <var>pRoot</var> and <var>pPath</var>, resolved and checked exactly as
/// <method>Export</method> checks it before its vendor call, for a mint that must refuse what the write would:
/// the gate, then <method>ExportFile</method>. Nothing is written.</p>
ClassMethod CheckExport(pRoot As %String, pPath As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '..ExportGate(.tFailedPair) {
            Set tSC = ..ExportGateRefusal(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ExportFile(pRoot, pPath, .tResolved, .pHttpStatus, .pFault)
    } Catch ex {
        Set tSC = ..Fail(..#RECORDENDPOINT, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether the calling process holds every pair in <parameter>EXPORTPAIRS</parameter>, checked in order through
/// <method>OcuPilot.Port.AdminPort.HoldsPair</method>. <var>pFailedPair</var> names the first it lacks, or is
/// <code>""</code>.</p>
ClassMethod ExportGate(Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    Set tPairs = $ListFromString(..#EXPORTPAIRS)
    For tI = 1:1:$ListLength(tPairs) {
        If ..HoldsPair($List(tPairs, tI)) Continue
        Set pFailedPair = $List(tPairs, tI)
        Quit
    }
    Quit (pFailedPair = "")
}

/// <p>The 403 the export's gate answers: the admin port's own mapping of 403, with the pair in
/// <code>detail.failedPair</code> (AD-8, AD-39).</p>
ClassMethod ExportGateRefusal(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("failedPair", pFailedPair, "string")
    Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tVendorText)
    Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, tDetail)
}

/// <p>The new file <var>pRoot</var> and <var>pPath</var> name, in <var>pResolved</var>: resolved through
/// <class>OcuPilot.Port.PathPort</class> as a file that is never replaced (AD-21's sixth case), each refusal on
/// <parameter>EXPORTROOTQUERY</parameter> or <parameter>EXPORTPATHQUERY</parameter>, then
/// <code>AUDIT.EXPORT.DIRECTORY</code>, 400 with one violation on <parameter>EXPORTPATHQUERY</parameter>, when the
/// name's directory does not exist. The vendor overwrites a file that exists and fails only after its task has
/// started when the directory is missing, so both refusals are made here. A directory is never created.</p>
ClassMethod ExportFile(pRoot As %String, pPath As %String, Output pResolved As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResolved = ""
    Set tSC = ##class(OcuPilot.Port.PathPort).Resolve(pRoot, pPath, ##class(OcuPilot.Port.PathPort).#KINDFILE, ..#EXPORTROOTQUERY, ..#EXPORTPATHQUERY, .pResolved, .pHttpStatus, .pFault, 0)
    If $$$ISERR(tSC) {
        Set pResolved = ""
        Quit tSC
    }
    If '##class(%File).DirectoryExists(##class(%File).GetDirectory(pResolved)) {
        Set pResolved = ""
        Quit ..ExportViolation(##class(OcuPilot.Api.Error).#AUDITEXPORTDIRECTORY, ##class(OcuPilot.Api.Error).#REASONAUDITEXPORTDIRECTORY, ..#EXPORTPATHQUERY, .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>A 400 refusal on one field, as <var>pCode</var> with its sentence, carried again as that field's one violation
/// (AD-39).</p>
ClassMethod ExportViolation(pCode As %String, pReason As %String, pField As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tViolation = {}
    Do tViolation.%Set("field", pField, "string")
    Do tViolation.%Set("code", pCode, "string")
    Do tViolation.%Set("reason", pReason, "string")
    Set tDetail = {}
    Do tDetail.%Set("violations", [(tViolation)])
    Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, pCode, pReason, .pHttpStatus, .pFault, tDetail)
}

/// <p>Whether <var>pBefore</var> is empty, every record, or a real day written <code>YYYY-MM-DD</code>.</p>
ClassMethod BeforeAdmitted(pBefore As %String) As %Boolean
{
    If pBefore = "" Quit 1
    If '$Match(pBefore, "^\d{4}-\d{2}-\d{2}$") Quit 0
    Quit ($ZDateH(pBefore, 3, , , , , , , -1) '= -1)
}

/// <p>The vendor's export of the audit records dated before <var>pBefore</var> (every record when empty) to
/// <var>pFile</var>, started as a background task in <parameter>EXPORTNAMESPACE</parameter> (AD-16), with no deletion
/// and no start day. <var>pJob</var> is the job the task runs in, <code>0</code> when none started. Overridable so a
/// fixture can observe or deny the call; production never overrides it.</p>
ClassMethod VendorStart(pFile As %String, pBefore As %String, Output pJob As %Integer) As %Status [ Private ]
{
    Set pJob = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#EXPORTNAMESPACE
        Kill tParms, tItems
        Set tParms("FileName") = pFile
        Set tParms("AuditFlag") = 0
        Set tParms("BeginDateTime") = ""
        Set tParms("EndDateTime") = $Select(pBefore = "": "", 1: pBefore _ " 00:00:00")
        Set tSC = $ClassMethod(..#EXPORTTASKCLASS, "RunTask", ..#EXPORTTASK, ..#EXPORTNAMESPACE, .tParms, .tItems, .pJob)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pJob = 0
        Set tSC = ex.AsStatus()
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

/// <p><code>objectscript</code> for <parameter>EXPORTTYPE</parameter>, which this port carries out itself; the admin
/// port's answer otherwise, since this port's copy and purge are the vendor's own routes.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If (pEndpoint = ..#RECORDENDPOINT) && (pType = ..#EXPORTTYPE) Quit "objectscript"
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s branches as a script (AD-59): <parameter>EXPORTTYPE</parameter> is the vendor's
/// task started in <parameter>EXPORTNAMESPACE</parameter> for the file <code>ExportRoot</code> and
/// <code>ExportPath</code> name, resolved as <class>OcuPilot.Port.PathPort</class> joins them and started only while no
/// file stands there, since the vendor replaces one; any other <parameter>COMPOSEDTYPES</parameter> pair is the vendor call with
/// <method>Body</method>'s body and an empty query, and a query <method>Body</method> cannot compose from answers no
/// step; every other call is the admin port's script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint = ..#RECORDENDPOINT) && (pType = ..#EXPORTTYPE) {
        Set tBefore = $Get(pQuery(..#EXPORTBEFOREQUERY))
        Set tFile = ##class(%File).NormalizeFilename(##class(%File).NormalizeDirectory($Get(pQuery(..#EXPORTROOTQUERY))) _ $Get(pQuery(..#EXPORTPATHQUERY)))
        Set tLines = $ListBuild("Kill tParms, tItems", "Set tParms(""FileName"") = " _ ..Literal(tFile), "Set tParms(""AuditFlag"") = 0", "Set tParms(""BeginDateTime"") = """"", "Set tParms(""EndDateTime"") = " _ ..Literal($Select(tBefore = "": "", 1: tBefore _ " 00:00:00")))
        Set tLines = tLines _ $ListBuild("Set tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.Error).#REASONPATHEXISTS) _ ")")
        Set tLines = tLines _ $ListBuild("If '##class(%File).Exists(tParms(""FileName"")) Set tSC = ##class(" _ ..#EXPORTTASKCLASS _ ").RunTask(" _ ..Literal(..#EXPORTTASK) _ ", " _ ..Literal(..#EXPORTNAMESPACE) _ ", .tParms, .tItems, .tJob)", "Do $System.Status.DisplayError(tSC)")
        Quit [(..ObjectScriptStep(tLines))]
    }
    If (pEndpoint '= ..#RECORDENDPOINT) || '$ListFind($ListFromString(..#COMPOSEDTYPES), pEndpoint _ "/" _ pType) Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    Set tBody = ..Body(pType, .pQuery)
    If '$IsObject(tBody) Quit []
    Kill tNone
    Quit ##super(pEndpoint, pType, .tNone, tBody, pContext)
}

}
