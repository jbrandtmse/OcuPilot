/// <p>The build-time derivation of every write payload's field list (AD-3), in test scope so that
/// nothing derives a schema at runtime. <method>Derive</method> reads the running instance;
/// <method>Stored</method> reads the committed <class>OcuPilot.Screen.Tool.FieldLists</class>;
/// <method>Regenerate</method> returns that class's whole source, which
/// <file>scripts/field-lists.sh</file> writes to disk. <class>OcuPilot.Test.DerivedFields</class>
/// compares the first two.</p>
/// <p><b>Three sources.</b> Every endpoint <method>OcuPilot.Test.AdminInventory.Derive</method>
/// reports with a template is derived from that template through
/// <method>OcuPilot.Port.AdminPort.Template</method> (<code>source</code> <code>template</code>,
/// keyed by the endpoint name). The two field-bearing template-less endpoints are derived from
/// their underlying classes (<code>source</code> <code>class</code>, keyed
/// <code>&lt;endpoint&gt;:&lt;class&gt;</code>): one list per wallet secret <code>Type</code>, and
/// one for the audit event. The server description's <code>Metadata</code> members are derived from
/// <parameter>SERVERMETADATACLASS</parameter> the same way, beside that endpoint's template list. The
/// action-style endpoints in <parameter>NOTEMPLATE</parameter> are recorded with <code>source</code>
/// <code>none</code> and no rows.</p>
/// <p><b>Rows.</b> Each row is <code>path|shape|templateType|itemType</code>. Every node of a
/// template is a row, in the template's own order: a literal is <code>literal</code> with its
/// placeholder's JSON type; an object is <code>object</code> and its members follow as
/// <code>Parent.Child</code>; an array is <code>array</code> with its first element's JSON type as
/// <code>itemType</code>, and that element follows as <code>Parent[]</code>. A member-less object
/// or array is one row. A class-derived row is one non-<code>Private</code>,
/// non-<code>Internal</code>, non-<code>%</code> property, identifying properties excluded, in name
/// order: a <code>LIST</code> is a member-less <code>array</code>, anything else a
/// <code>literal</code> whose type is mapped from its <code>ClientDataType</code>. The placeholder
/// type is information; the shape is contract.</p>
/// <p>Every derivation failure is an error status, never a shorter list: an endpoint whose
/// template does not evaluate, a class with no readable property, an unmapped
/// <code>ClientDataType</code>, or a class-derived or no-template endpoint the inventory does not
/// report as mutating and template-less.</p>
Class OcuPilot.Test.FieldDerive Extends %RegisteredObject
{

/// <p>The committed class holding the lists.</p>
Parameter FIELDLISTSCLASS = "OcuPilot.Screen.Tool.FieldLists";

/// <p>The XData block in <parameter>FIELDLISTSCLASS</parameter>.</p>
Parameter LISTSXDATA = "Lists";

/// <p>The wallet secret endpoint, whose body is <code>{Type, WalletSecretConfig}</code>.</p>
Parameter WALLETENDPOINT = "Wallet.Secret";

/// <p>The <code>Type</code> values the wallet secret endpoint accepts, each the class its
/// <code>WalletSecretConfig</code> is applied to.</p>
Parameter WALLETTYPES = "%Wallet.KeyValue,%Wallet.RSA,%Wallet.SymmetricKey";

/// <p>The body member a wallet secret's fields sit under.</p>
Parameter WALLETENVELOPE = "WalletSecretConfig";

/// <p>The wallet secret property identified by the request's <code>name</code> query parameter
/// rather than carried in the body.</p>
Parameter WALLETIDENTIFYING = "Name";

/// <p>The audit event endpoint.</p>
Parameter AUDITEVENTENDPOINT = "Security.Audit.Event";

/// <p>The class an audit event's body is applied to.</p>
Parameter AUDITEVENTCLASS = "Security.Events";

/// <p>The audit event properties identified by the request's query parameters.</p>
Parameter AUDITEVENTIDENTIFYING = "Source,Type,Name";

/// <p>The mutating endpoints whose bodies are trivial or empty and need no field list.</p>
Parameter NOTEMPLATE = "Lock,Process,Task.Manager";

/// <p>The OAuth 2.0 server description endpoint, whose template carries <code>Metadata</code> as a
/// member-less object.</p>
Parameter SERVERDEFINITIONENDPOINT = "Security.OAuth2.Client.ServerDefinition";

/// <p>The class the endpoint imports <code>Metadata</code> into, member by member, through its
/// generated <code>ImportJSON</code>: the members' list is derived from it.</p>
Parameter SERVERMETADATACLASS = "OAuth2.Server.Metadata";

/// <p>The body member the server description's metadata members sit under.</p>
Parameter SERVERMETADATAENVELOPE = "Metadata";

/// <p>Derive every list from the running instance. <var>pLists</var> comes back subscripted by
/// list key: <code>pLists(key)</code> is
/// <code>endpoint|source|method|class|type|envelope</code>, and <code>pLists(key, n)</code> is
/// row <var>n</var> as <code>path|shape|templateType|itemType</code>, numbered from 1.</p>
ClassMethod Derive(Output pLists) As %Status
{
    Set tSC = $$$OK
    Kill pLists
    Try {
        Set tSC = ##class(OcuPilot.Test.AdminInventory).Derive(.tInventory)
        If $$$ISERR(tSC) Quit

        Set tEndpoint = ""
        For {
            Set tEndpoint = $Order(tInventory(tEndpoint))
            Quit:tEndpoint=""
            If $Piece(tInventory(tEndpoint), "|", 1) = "" Continue
            Set tSC = ##class(OcuPilot.Port.AdminPort).Template(tEndpoint, .tTemplate, .tMethod)
            If $$$ISERR(tSC) Set tSC = $$$ADDSC($$$ERROR($$$GeneralError, tEndpoint _ "'s body template did not evaluate"), tSC) Quit
            Set pLists(tEndpoint) = ..Header(tEndpoint, "template", tMethod, "", "", "")
            Set tSC = ..WalkMembers(tTemplate, "", tEndpoint, .pLists)
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit

        Set tTemplateless = $ListFromString(..#NOTEMPLATE) _ $ListBuild(..#WALLETENDPOINT, ..#AUDITEVENTENDPOINT)
        For tI = 1:1:$ListLength(tTemplateless) {
            Set tName = $ListGet(tTemplateless, tI)
            Set tRow = $Get(tInventory(tName))
            If (tRow = "") || ($Piece(tRow, "|", 1) '= "") || ($Piece(tRow, "|", 5) '= 1) {
                Set tSC = $$$ERROR($$$GeneralError, tName _ " is not a mutating template-less endpoint on this instance (inventory row '" _ tRow _ "')")
                Quit
            }
        }
        If $$$ISERR(tSC) Quit

        Set tTypes = $ListFromString(..#WALLETTYPES)
        For tI = 1:1:$ListLength(tTypes) {
            Set tType = $ListGet(tTypes, tI)
            Set tKey = ..#WALLETENDPOINT _ ":" _ tType
            Set pLists(tKey) = ..Header(..#WALLETENDPOINT, "class", "", tType, tType, ..#WALLETENVELOPE)
            Set tSC = ..ClassRows(tType, ..#WALLETIDENTIFYING, tKey, .pLists)
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit

        Set tKey = ..#AUDITEVENTENDPOINT _ ":" _ ..#AUDITEVENTCLASS
        Set pLists(tKey) = ..Header(..#AUDITEVENTENDPOINT, "class", "", ..#AUDITEVENTCLASS, "", "")
        Set tSC = ..ClassRows(..#AUDITEVENTCLASS, ..#AUDITEVENTIDENTIFYING, tKey, .pLists)
        If $$$ISERR(tSC) Quit

        ; The server description's Metadata members, beside its template list, which carries
        ; Metadata as one member-less object. The endpoint has a template, so the template-less
        ; inventory check above does not apply to it.
        Set tKey = ..#SERVERDEFINITIONENDPOINT _ ":" _ ..#SERVERMETADATACLASS
        Set pLists(tKey) = ..Header(..#SERVERDEFINITIONENDPOINT, "class", "", ..#SERVERMETADATACLASS, "", ..#SERVERMETADATAENVELOPE)
        Set tSC = ..ClassRows(..#SERVERMETADATACLASS, "", tKey, .pLists)
        If $$$ISERR(tSC) Quit

        Set tNone = $ListFromString(..#NOTEMPLATE)
        For tI = 1:1:$ListLength(tNone) {
            Set tName = $ListGet(tNone, tI)
            Set pLists(tName) = ..Header(tName, "none", "", "", "", "")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Read the committed lists out of <parameter>FIELDLISTSCLASS</parameter>'s
/// <parameter>LISTSXDATA</parameter> block, in the shape <method>Derive</method> returns. A block
/// that is missing, not JSON, or missing a list field is an error status.</p>
ClassMethod Stored(Output pLists) As %Status
{
    Set tSC = $$$OK
    Kill pLists
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen(..#FIELDLISTSCLASS, ..#LISTSXDATA, , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the " _ ..#LISTSXDATA _ " XData block of " _ ..#FIELDLISTSCLASS _ " could not be opened")
            Quit
        }
        Set tJson = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
        Set tIterator = tJson.%GetIterator()
        While tIterator.%GetNext(.tKey, .tList) {
            If '$IsObject(tList) || '$IsObject(tList.rows) {
                Set tSC = $$$ERROR($$$GeneralError, "list " _ tKey _ " carries no rows array")
                Quit
            }
            For tField = "endpoint", "source", "method", "class", "type", "envelope" {
                If 'tList.%IsDefined(tField) Set tSC = $$$ERROR($$$GeneralError, "list " _ tKey _ " carries no " _ tField)
            }
            If $$$ISERR(tSC) Quit
            Set pLists(tKey) = ..Header(tList.endpoint, tList.source, tList.method, tList.class, tList.type, tList.envelope)
            For tN = 0:1:(tList.rows.%Size() - 1) {
                Set tRow = tList.rows.%Get(tN)
                Set pLists(tKey, tN + 1) = tRow.path _ "|" _ tRow.shape _ "|" _ tRow.templateType _ "|" _ tRow.itemType
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The whole source of <parameter>FIELDLISTSCLASS</parameter>, derived live. Returned rather
/// than written, since only the response and error writers may <code>Write</code> (AD-12).</p>
ClassMethod Regenerate(Output pSource As %String) As %Status
{
    Set tSC = $$$OK
    Set pSource = ""
    Try {
        Set tSC = ..Derive(.tLists)
        If $$$ISERR(tSC) Quit
        Set tLF = $Char(10)
        Set tText = "/// <p>GENERATED FILE -- DO NOT EDIT. The field list and JSON shape of every write payload the" _ tLF
        Set tText = tText _ "/// admin API accepts (AD-3), derived from the instance by" _ tLF
        Set tText = tText _ "/// <method>OcuPilot.Test.FieldDerive.Regenerate</method> and written by" _ tLF
        Set tText = tText _ "/// <file>scripts/field-lists.sh</file>. <class>OcuPilot.Test.DerivedFields</class> fails when the" _ tLF
        Set tText = tText _ "/// instance disagrees; <file>ui/tools/field-lists.mjs</file> joins these lists with the reviewed" _ tLF
        Set tText = tText _ "/// entries in <class>OcuPilot.Screen.Tool.Classification</class>.</p>" _ tLF
        Set tText = tText _ "/// <p>Each list carries <code>endpoint</code>, <code>source</code> (<code>template</code>," _ tLF
        Set tText = tText _ "/// <code>class</code> or <code>none</code>), <code>method</code>, <code>class</code>," _ tLF
        Set tText = tText _ "/// <code>type</code> and <code>envelope</code> (a wallet secret's <code>Type</code> value and body" _ tLF
        Set tText = tText _ "/// member), and <code>rows</code>. A row is <code>{path, shape, templateType, itemType}</code>:" _ tLF
        Set tText = tText _ "/// <code>shape</code> (<code>literal</code>, <code>object</code>, <code>array</code>) is contract," _ tLF
        Set tText = tText _ "/// <code>templateType</code> and <code>itemType</code> are information. Members of an object" _ tLF
        Set tText = tText _ "/// follow it as <code>Parent.Child</code>, an array's first element as <code>Parent[]</code>.</p>" _ tLF
        Set tText = tText _ "Class " _ ..#FIELDLISTSCLASS _ " Extends %RegisteredObject" _ tLF _ "{" _ tLF _ tLF
        Set tText = tText _ "XData " _ ..#LISTSXDATA _ tLF _ "{" _ tLF _ "{" _ tLF
        Set tKey = ""
        Set tFirst = 1
        For {
            Set tKey = $Order(tLists(tKey))
            Quit:tKey=""
            Set tHeader = tLists(tKey)
            Set tObject = {}
            Do tObject.%Set("endpoint", $Piece(tHeader, "|", 1))
            Do tObject.%Set("source", $Piece(tHeader, "|", 2))
            Do tObject.%Set("method", $Piece(tHeader, "|", 3))
            Do tObject.%Set("class", $Piece(tHeader, "|", 4))
            Do tObject.%Set("type", $Piece(tHeader, "|", 5))
            Do tObject.%Set("envelope", $Piece(tHeader, "|", 6))
            Set tHead = tObject.%ToJSON()
            Set tName = {}
            Do tName.%Set("k", tKey)
            Set tQuoted = $Extract(tName.%ToJSON(), 6, *-1)
            Set tText = tText _ $Select(tFirst: "", 1: "," _ tLF) _ tQuoted _ ": " _ $Extract(tHead, 1, *-1) _ ",""rows"":["
            Set tFirst = 0
            Set tCount = $Order(tLists(tKey, ""), -1)
            For tN = 1:1:tCount {
                Set tRow = tLists(tKey, tN)
                Set tRowObject = {}
                Do tRowObject.%Set("path", $Piece(tRow, "|", 1))
                Do tRowObject.%Set("shape", $Piece(tRow, "|", 2))
                Do tRowObject.%Set("templateType", $Piece(tRow, "|", 3))
                Do tRowObject.%Set("itemType", $Piece(tRow, "|", 4))
                Set tText = tText _ tLF _ "  " _ tRowObject.%ToJSON() _ $Select(tN < tCount: ",", 1: "")
            }
            Set tText = tText _ $Select(tCount > 0: tLF, 1: "") _ "]}"
        }
        Set tText = tText _ tLF _ "}" _ tLF _ "}" _ tLF _ tLF _ "}"
        Set pSource = tText
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>A list header in the pipe-joined form <method>Derive</method> documents.</p>
ClassMethod Header(pEndpoint As %String, pSource As %String, pMethod As %String, pClass As %String, pType As %String, pEnvelope As %String) As %String [ Private ]
{
    Quit pEndpoint _ "|" _ pSource _ "|" _ pMethod _ "|" _ pClass _ "|" _ pType _ "|" _ pEnvelope
}

/// <p>Append one row to list <var>pKey</var>.</p>
ClassMethod AddRow(pKey As %String, pPath As %String, pShape As %String, pTemplateType As %String, pItemType As %String, ByRef pLists) [ Private ]
{
    Set tN = $Order(pLists(pKey, ""), -1) + 1
    Set pLists(pKey, tN) = pPath _ "|" _ pShape _ "|" _ pTemplateType _ "|" _ pItemType
}

/// <p>Emit a row for every member of the object or array <var>pContainer</var> at
/// <var>pPath</var>, depth first: an object's members as <code>path.member</code>, an array's
/// only element as <code>path[]</code>. An array with more than one element is an error, and so
/// is a member name other than letters, digits, <code>_</code> and <code>%</code>, the path
/// segments <file>ui/tools/field-lists.mjs</file> accepts.</p>
ClassMethod WalkMembers(pContainer As %DynamicAbstractObject, pPath As %String, pKey As %String, ByRef pLists) As %Status
{
    Set tSC = $$$OK
    If pContainer.%IsA("%Library.DynamicArray") {
        If pContainer.%Size() = 0 Quit tSC
        If pContainer.%Size() > 1 Quit $$$ERROR($$$GeneralError, "list " _ pKey _ " has an array at '" _ pPath _ "' with more than one element, and only the first is derived")
        Quit ..WalkNode(pContainer, 0, pPath _ "[]", pKey, .pLists)
    }
    Set tIterator = pContainer.%GetIterator()
    While tIterator.%GetNext(.tMember) {
        If '$Match(tMember, "^[A-Za-z0-9_%]+$") {
            Set tSC = $$$ERROR($$$GeneralError, "list " _ pKey _ " has a member '" _ tMember _ "' under '" _ pPath _ "' that cannot be written as a path")
            Quit
        }
        Set tSC = ..WalkNode(pContainer, tMember, $Select(pPath = "": tMember, 1: pPath _ "." _ tMember), pKey, .pLists)
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>Emit the row for member <var>pMember</var> of <var>pContainer</var> at <var>pPath</var>,
/// then its own members.</p>
ClassMethod WalkNode(pContainer As %DynamicAbstractObject, pMember, pPath As %String, pKey As %String, ByRef pLists) As %Status [ Private ]
{
    Set tType = pContainer.%GetTypeOf(pMember)
    If (tType '= "object") && (tType '= "array") {
        Do ..AddRow(pKey, pPath, "literal", tType, "", .pLists)
        Quit $$$OK
    }
    Set tValue = pContainer.%Get(pMember)
    Set tItemType = ""
    If (tType = "array") && (tValue.%Size() > 0) Set tItemType = tValue.%GetTypeOf(0)
    Do ..AddRow(pKey, pPath, tType, tType, tItemType, .pLists)
    Quit ..WalkMembers(tValue, pPath, pKey, .pLists)
}

/// <p>Append a row to list <var>pKey</var> for every property of <var>pClass</var> that is not
/// <code>Private</code>, not <code>Internal</code>, not <code>%</code>-named and not in
/// <var>pIdentifying</var> (comma-separated), in name order. Read in <code>%SYS</code>, where
/// <parameter>AUDITEVENTCLASS</parameter> is defined, by save and restore (AD-16).</p>
ClassMethod ClassRows(pClass As %String, pIdentifying As %String, pKey As %String, ByRef pLists) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tExcluded = $ListFromString(pIdentifying)
        Set $NAMESPACE = "%SYS"
        Set tStmt = ##class(%SQL.Statement).%New()
        Set tSC = tStmt.%Prepare("SELECT %EXACT(p.Name) AS Name, p.Collection AS Collection, c.ClientDataType AS ClientDataType FROM %Dictionary.CompiledProperty p LEFT JOIN %Dictionary.CompiledClass c ON c.Name = p.Type WHERE %EXACT(p.parent) = ? AND p.Private = 0 AND p.Internal = 0 AND NOT (p.Name %STARTSWITH '%') ORDER BY %EXACT(p.Name)")
        If $$$ISERR(tSC) {
            Set $NAMESPACE = tOrigNS
            Quit
        }
        Set tRs = tStmt.%Execute(pClass)
        If '$IsObject(tRs) || (tRs.%SQLCODE < 0) {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ERROR($$$GeneralError, "the property query for " _ pClass _ " did not run")
            Quit
        }
        Set tRows = 0
        While tRs.%Next() {
            Set tName = tRs.%Get("Name")
            If $ListFind(tExcluded, tName) Continue
            If tRs.%Get("Collection") '= "" {
                Set tSC = $$$ERROR($$$GeneralError, pClass _ "." _ tName _ " is a collection property, which has no derivation rule")
                Quit
            }
            Set tClientType = tRs.%Get("ClientDataType")
            Set tJsonType = ..JsonType(tClientType)
            If tJsonType = "" {
                Set tSC = $$$ERROR($$$GeneralError, pClass _ "." _ tName _ " has ClientDataType '" _ tClientType _ "', which maps to no JSON type")
                Quit
            }
            Set tRows = tRows + 1
            Do ..AddRow(pKey, tName, $Select(tJsonType = "array": "array", 1: "literal"), tJsonType, "", .pLists)
        }
        Set tSQLCODE = tRs.%SQLCODE
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        If tSQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "the property fetch for " _ pClass _ " stopped early: SQLCODE " _ tSQLCODE)
            Quit
        }
        If tRows = 0 Set tSC = $$$ERROR($$$GeneralError, pClass _ " has no readable property")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The JSON type a property of <var>pClientDataType</var> takes in a request body, or
/// <code>""</code> when none is mapped.</p>
ClassMethod JsonType(pClientDataType As %String) As %String [ Private ]
{
    Quit $Case(pClientDataType, "VARCHAR": "string", "BINARY": "string", "DATE": "string", "TIME": "string", "TIMESTAMP": "string", "BOOLEAN": "boolean", "INTEGER": "number", "DECIMAL": "number", "DOUBLE": "number", "NUMERIC": "number", "BIGINT": "number", "SMALLINT": "number", "TINYINT": "number", "CURRENCY": "number", "LIST": "array", : "")
}

}
