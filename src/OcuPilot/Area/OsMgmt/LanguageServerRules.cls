/// <p>The external language server editor's rules (AD-39, AD-55, Story 16.25): the one rule set every
/// caller of <class>OcuPilot.Screen.Tool.LanguageServerCreate</class> and
/// <class>OcuPilot.Screen.Tool.LanguageServerUpdate</class> applies (<method>Validate</method>), each
/// type's <code>Custom</code> members (<method>Members</method>), the resource a create defaults to
/// (<method>ResourceDefault</method>), the running refusal (<method>Running</method>), the form's read
/// (<method>HandleForm</method>) and the name look-up (<method>HandleName</method>,
/// <method>Taken</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, and the form
/// read serves the same sentences, so an inline refusal and a failed Save are one wording.</p>
/// <p><b>A type's <code>Custom</code> members are read from <class>OcuPilot.Screen.Tool.FieldLists</class></b>,
/// the <code>LanguageServer:&lt;Type&gt;</code> list derived from the instance (AD-3). A member named
/// in <parameter>PATHFIELDS</parameter> is a file location, shown and never set (AD-21); every other
/// member is settable.</p>
Class OcuPilot.Area.OsMgmt.LanguageServerRules Extends %RegisteredObject
{

/// <p>The tools the callers resolve the writes through (AD-55): the create for a name look-up, the
/// edit for a present server's read.</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.LanguageServerCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.LanguageServerUpdate";

/// <p>The screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LanguageServerForm";

/// <p>The generated field lists: the untyped template list and the per-type ones.</p>
Parameter FIELDLISTSCLASS = "OcuPilot.Screen.Tool.FieldLists";

Parameter TEMPLATELIST = "LanguageServer";

/// <p>The types <code>Config.Gateways</code> defines, spelled with their case, in the vendor's own
/// order. <class>OcuPilot.Test.LanguageServerEditor</class> holds it equal to the derivation's.</p>
Parameter TYPES = "Remote,Java,XSLT,JDBC,ODBC,ML,.NET,Python,R";

/// <p>The file locations, top-level and <code>Custom</code> members alike: shown, never set
/// (AD-21).</p>
Parameter PATHFIELDS = "LogFile,ClassPath,JavaHome,FilePath,PythonPath";

/// <p>The object a type's own settings travel under.</p>
Parameter CUSTOMFIELD = "Custom";

/// <p>The .NET versions a server may name, <code>Config.Gateways</code>'s <code>VALIDNETVERSIONS</code>
/// (read on this build; a test holds them equal).</p>
Parameter DOTNETVERSIONS = "N8.0,N9.0,N10.0";

Parameter DOTNETVERSIONMEMBER = "DotNetVersion";

/// <p>The <code>Custom</code> members that are flags.</p>
Parameter FLAGMEMBERS = "Exec32";

/// <p><code>Config.Gateways</code>'s own bounds: a name, and the resource and TLS names.</p>
Parameter NAMEMAXLENGTH As INTEGER = 50;

Parameter TEXTMAXLENGTH As INTEGER = 64;

/// <p>A name <code>Config.Gateways</code> accepts: 1 to 50 characters, none a control
/// character.</p>
Parameter NAMEPATTERN = "[^\x00-\x1F\x7F]{1,50}";

/// <p>The whole-number fields, each <code>&lt;field&gt;:&lt;min&gt;:&lt;max&gt;</code> as
/// <code>Config.Gateways</code> bounds it.</p>
Parameter WHOLEFIELDS = "Port:1:65535,ConnectionTimeout:2:300,InitializationTimeout:2:300";

/// <p>The flag fields.</p>
Parameter FLAGFIELDS = "UseSharedMemory,VerifySSLHostName";

/// <p>The names of other objects, each at most <parameter>TEXTMAXLENGTH</parameter> characters and not
/// checked against the instance, as the vendor does not check them.</p>
Parameter NAMEFIELDS = "Resource,SSLConfigurationServer,SSLConfigurationClient";

/// <p>Free text the vendor does not validate.</p>
Parameter TEXTFIELDS = "BindToIPAddress";

/// <p>The fields a create must carry.</p>
Parameter REQUIREDFIELDS = "Name,Type,Port";

/// <p>The resource the classic editor gives a new server of each type, and the one it gives every
/// other type (read in <code>%CSP.UI.Portal.ExternalLanguageServer</code>).</p>
Parameter RESOURCEDEFAULTS = "JDBC:%Gateway_SQL,ODBC:%Gateway_SQL,ML:%Gateway_ML";

Parameter RESOURCEDEFAULT = "%Gateway_Object";

/// <p>The type a running server may still be changed or deleted as, because nothing local listens,
/// and the one whose <code>Custom</code> carries the virtual-environment consequence.</p>
Parameter REMOTETYPE = "Remote";

Parameter PYTHONTYPE = "Python";

/// <p>The fields the rules read, named once.</p>
Parameter FIELDNAME = "Name";

Parameter FIELDTYPE = "Type";

Parameter FIELDPORT = "Port";

Parameter FIELDRUNNING = "CurrentlyRunning";

/// <p>Every rule a server write applies to <var>pArgs</var>, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pMode</var> <code>create</code> applies the name's own rules, requires the name, the type
/// and the port, and judges <code>Custom</code> against the type <var>pArgs</var> names;
/// <code>update</code> judges it against <var>pFresh</var>'s type, and refuses a required field only
/// when <var>pArgs</var> empties it. A .NET version is judged only where it changes, so an edit keeps
/// a stored version outside the list until it is changed. <var>pCheckTaken</var> 0 skips the name
/// look-up, for the agent's mint, which has read the target itself.</p>
/// <p>A list that cannot be read is an error status, never a pass.</p>
ClassMethod Validate(pName As %String, pArgs As %DynamicObject, Output pViolations, pMode As %String = "create", pCheckTaken As %Boolean = 1, pFresh As %DynamicObject = "") As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tCreates = (pMode = "create")
        If '$IsObject(pArgs) Set pArgs = {}
        Set tType = ""
        If tCreates {
            Do ..NameViolation(pName, .pViolations)
            If (pViolations = 0) && pCheckTaken {
                Set tSC = ..Taken(pName, .tTaken)
                If $$$ISERR(tSC) Quit
                If tTaken Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.LanguageServerError).#NAMETAKEN)
            }
            Set tTypeKind = pArgs.%GetTypeOf(..#FIELDTYPE)
            If (tTypeKind = "unassigned") || ((tTypeKind = "string") && (pArgs.%Get(..#FIELDTYPE) = "")) {
                Do ..Add(.pViolations, ..#FIELDTYPE, ##class(OcuPilot.Api.LanguageServerError).#TYPEREQUIRED)
            } ElseIf (tTypeKind '= "string") || '..IsType(pArgs.%Get(..#FIELDTYPE)) {
                Do ..Add(.pViolations, ..#FIELDTYPE, ##class(OcuPilot.Api.LanguageServerError).#TYPEUNKNOWN)
            } Else {
                Set tType = pArgs.%Get(..#FIELDTYPE)
            }
        } ElseIf $IsObject(pFresh) {
            Set tType = pFresh.%Get(..#FIELDTYPE)
        }
        For tI = 1:1:$Length(..#WHOLEFIELDS, ",") {
            Set tEntry = $Piece(..#WHOLEFIELDS, ",", tI)
            Set tField = $Piece(tEntry, ":", 1)
            Set tKind = pArgs.%GetTypeOf(tField)
            If tKind = "unassigned" {
                If tCreates && (tField = ..#FIELDPORT) Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.LanguageServerError).#PORTREQUIRED)
                Continue
            }
            If (tKind = "object") || (tKind = "array") {
                Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Continue
            }
            ; An emptied port is a missing one, on a create and on an edit alike.
            If (tField = ..#FIELDPORT) && (tKind = "string") && (pArgs.%Get(tField) = "") {
                Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.LanguageServerError).#PORTREQUIRED)
                Continue
            }
            If '..Whole(pArgs, tField, $Piece(tEntry, ":", 2), $Piece(tEntry, ":", 3)) Do ..Add(.pViolations, tField, ..Code(tField, "RANGE"))
        }
        For tI = 1:1:$Length(..#FLAGFIELDS, ",") {
            Set tField = $Piece(..#FLAGFIELDS, ",", tI)
            Set tKind = pArgs.%GetTypeOf(tField)
            If (tKind '= "unassigned") && (tKind '= "boolean") Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        For tI = 1:1:$Length(..#TEXTFIELDS, ",") {
            Set tField = $Piece(..#TEXTFIELDS, ",", tI)
            Set tKind = pArgs.%GetTypeOf(tField)
            If (tKind '= "unassigned") && (tKind '= "string") Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        For tI = 1:1:$Length(..#NAMEFIELDS, ",") {
            Set tField = $Piece(..#NAMEFIELDS, ",", tI)
            Set tKind = pArgs.%GetTypeOf(tField)
            If tKind = "unassigned" Continue
            If tKind '= "string" {
                Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Continue
            }
            If $Length(pArgs.%Get(tField)) > ..#TEXTMAXLENGTH Do ..Add(.pViolations, tField, ..Code(tField, "LENGTH"))
        }
        For tI = 1:1:$Length(..#PATHFIELDS, ",") {
            Set tField = $Piece(..#PATHFIELDS, ",", tI)
            If pArgs.%GetTypeOf(tField) '= "unassigned" Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.LanguageServerError).#PATH)
        }
        Set tCustomKind = pArgs.%GetTypeOf(..#CUSTOMFIELD)
        If tCustomKind = "unassigned" Quit
        If tCustomKind '= "object" {
            Do ..Add(.pViolations, ..#CUSTOMFIELD, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
            Quit
        }
        If tType = "" Quit
        Set tSC = ..Members(tType, .tSettable, .tPaths)
        If $$$ISERR(tSC) Quit
        Set tHeld = ""
        If $IsObject(pFresh) && (pFresh.%GetTypeOf(..#CUSTOMFIELD) = "object") Set tHeld = pFresh.%Get(..#CUSTOMFIELD)
        Set tIterator = pArgs.%Get(..#CUSTOMFIELD).%GetIterator()
        While tIterator.%GetNext(.tMember, .tValue) {
            Set tField = ..#CUSTOMFIELD _ "." _ tMember
            If $ListFind(tPaths, tMember) {
                Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.LanguageServerError).#CUSTOMPATH)
                Continue
            }
            If '$ListFind(tSettable, tMember) {
                Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.LanguageServerError).#CUSTOMUNKNOWN)
                Continue
            }
            Set tKind = pArgs.%Get(..#CUSTOMFIELD).%GetTypeOf(tMember)
            If $ListFind($ListFromString(..#FLAGMEMBERS), tMember) {
                If '..FlagValue(tKind, tValue) Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Continue
            }
            If tKind '= "string" {
                Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Continue
            }
            If tMember '= ..#DOTNETVERSIONMEMBER Continue
            If $ListFind($ListFromString(..#DOTNETVERSIONS), tValue) Continue
            If $IsObject(tHeld) && (tHeld.%GetTypeOf(tMember) '= "unassigned") && (("" _ tHeld.%Get(tMember)) = tValue) Continue
            Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.LanguageServerError).#DOTNETVERSIONUNKNOWN)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add the name's own violation to <var>pViolations</var>, or none: an absent name, and one
/// <parameter>NAMEPATTERN</parameter> refuses.</p>
ClassMethod NameViolation(pName As %String, Output pViolations)
{
    If pName = "" {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.LanguageServerError).#NAMEREQUIRED)
        Quit
    }
    If '$Match(pName, ..#NAMEPATTERN) Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.LanguageServerError).#NAMESHAPE)
}

/// <p>Whether <var>pType</var> is one of <parameter>TYPES</parameter>, spelled with its case.</p>
ClassMethod IsType(pType As %String) As %Boolean
{
    If pType = "" Quit 0
    Quit ''$ListFind($ListFromString(..#TYPES), pType)
}

/// <p>The resource a create of type <var>pType</var> sends when the caller names none: the classic
/// editor's default for that type.</p>
ClassMethod ResourceDefault(pType As %String) As %String
{
    For tI = 1:1:$Length(..#RESOURCEDEFAULTS, ",") {
        Set tEntry = $Piece(..#RESOURCEDEFAULTS, ",", tI)
        If $Piece(tEntry, ":", 1) = pType Quit
        Set tEntry = ""
    }
    If tEntry '= "" Quit $Piece(tEntry, ":", 2, *)
    Quit ..#RESOURCEDEFAULT
}

/// <p>Whether the fresh read <var>pFresh</var> is of a server that runs and is not
/// <parameter>REMOTETYPE</parameter>: the one an edit or a delete refuses, as the classic editor does.
/// A read that answered no boolean running state reads as running, so a state nobody established is
/// never one to write over.</p>
ClassMethod Running(pFresh As %DynamicObject) As %Boolean
{
    If '$IsObject(pFresh) Quit 1
    If pFresh.%Get(..#FIELDTYPE) = ..#REMOTETYPE Quit 0
    If pFresh.%GetTypeOf(..#FIELDRUNNING) '= "boolean" Quit 1
    Quit ''pFresh.%Get(..#FIELDRUNNING)
}

/// <p>Type <var>pType</var>'s <code>Custom</code> members, from its derived
/// <code>LanguageServer:&lt;Type&gt;</code> list, in the list's order: the settable ones in
/// <var>pSettable</var> and the file locations in <var>pPaths</var>. A type with no list is an error
/// status.</p>
ClassMethod Members(pType As %String, Output pSettable As %List, Output pPaths As %List) As %Status
{
    Set pSettable = ""
    Set pPaths = ""
    If '..IsType(pType) Quit $$$ERROR($$$GeneralError, "'" _ pType _ "' is not a language server type")
    Set tSC = ..ListRows(..#TEMPLATELIST _ ":" _ pType, .tRows)
    If $$$ISERR(tSC) Quit tSC
    Set tPrefix = ..#CUSTOMFIELD _ "."
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tPath = tRow.%Get("path")
        If $Extract(tPath, 1, $Length(tPrefix)) '= tPrefix Continue
        Set tMember = $Extract(tPath, $Length(tPrefix) + 1, *)
        If $ListFind($ListFromString(..#PATHFIELDS), tMember) {
            Set pPaths = pPaths _ $ListBuild(tMember)
        } Else {
            Set pSettable = pSettable _ $ListBuild(tMember)
        }
    }
    Quit $$$OK
}

/// <p>The top-level fields of the untyped derived list, in its order, less the type and
/// <parameter>CUSTOMFIELD</parameter>: the settable ones in <var>pSettable</var> and the file
/// locations in <var>pPaths</var>.</p>
ClassMethod TopFields(Output pSettable As %List, Output pPaths As %List) As %Status
{
    Set pSettable = ""
    Set pPaths = ""
    Set tSC = ..ListRows(..#TEMPLATELIST, .tRows)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tPath = tRow.%Get("path")
        If (tPath = "") || (tPath [ ".") || (tPath = ..#FIELDTYPE) || (tPath = ..#CUSTOMFIELD) Continue
        If $ListFind($ListFromString(..#PATHFIELDS), tPath) {
            Set pPaths = pPaths _ $ListBuild(tPath)
        } Else {
            Set pSettable = pSettable _ $ListBuild(tPath)
        }
    }
    If pSettable = "" Quit $$$ERROR($$$GeneralError, ..#TEMPLATELIST _ " has no top-level fields")
    Quit $$$OK
}

/// <p>Answer <code>GET /language-server/form[?name=&lt;n&gt;]</code>: everything the form needs before
/// it can draw a field (AD-39): <code>{requiredFields, rules, types, fields, paths, typeFields,
/// resourceDefaults, dotNetVersions}</code>, where <code>typeFields</code> holds each type's settable
/// and path <code>Custom</code> members. With a name it adds <code>server</code>, the edit tool's fresh
/// read with its name and <code>CurrentlyRunning</code>, and <code>running</code>, whether the edit is
/// refused (<method>Running</method>); a name this instance does not define is 404
/// <parameter>OcuPilot.Api.LanguageServerError.NAMEABSENT</parameter>.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("requiredFields", ..Array($ListFromString(..#REQUIREDFIELDS)))
        Do tBody.%Set("rules", ..Rules())
        Do tBody.%Set("types", ..Array($ListFromString(..#TYPES)))
        Set tListSC = ..TopFields(.tTop, .tTopPaths)
        Set tTypeFields = {}
        Set tDefaults = {}
        Set tTypes = $ListFromString(..#TYPES)
        For tI = 1:1:$ListLength(tTypes) {
            If $$$ISERR(tListSC) Quit
            Set tType = $List(tTypes, tI)
            Set tListSC = ..Members(tType, .tSettable, .tPaths)
            If $$$ISERR(tListSC) Quit
            Set tEntry = {}
            Do tEntry.%Set("settable", ..Array(tSettable))
            Do tEntry.%Set("paths", ..Array(tPaths))
            Do tTypeFields.%Set(tType, tEntry)
            Do tDefaults.%Set(tType, ..ResourceDefault(tType), "string")
        }
        If $$$ISERR(tListSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tListSC))
            Quit
        }
        Do tBody.%Set("fields", ..Array(tTop))
        Do tBody.%Set("paths", ..Array(tTopPaths))
        Do tBody.%Set("typeFields", tTypeFields)
        Do tBody.%Set("resourceDefaults", tDefaults)
        Do tBody.%Set("dotNetVersions", ..Array($ListFromString(..#DOTNETVERSIONS)))
        Set tName = $Get(%request.Data("name", 1))
        If tName '= "" {
            Set tReadSC = ..Present(tName, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, tHttp, tFault)
                Quit
            }
            Set tServer = ##class(%DynamicAbstractObject).%FromJSON(tFresh.%ToJSON())
            Do tServer.%Set(..#FIELDNAME, tName, "string")
            Do tBody.%Set("server", tServer)
            Do tBody.%Set("running", ..Running(tFresh), "boolean")
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /language-server/name?name=&lt;n&gt;</code>: whether that name is taken, in
/// <code>{name, taken, reason}</code>. A look-up that cannot be made is a refusal envelope, never an
/// assertion that the name is free.</p>
ClassMethod HandleName() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tName = $Get(%request.Data("name", 1))
        If tName = "" {
            Set tSC = ##class(OcuPilot.Area.OsMgmt.LanguageServerSave).RenderOne(..#FIELDNAME, ##class(OcuPilot.Api.LanguageServerError).#NAMEREQUIRED)
            Quit
        }
        Set tTakenSC = ..Taken(tName, .tTaken)
        If $$$ISERR(tTakenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tTakenSC))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("name", tName, "string")
        Do tBody.%Set("taken", tTaken, "boolean")
        Do tBody.%Set("reason", $Select(tTaken: ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.LanguageServerError).#NAMETAKEN), 1: ""), "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Whether a server already carries <var>pName</var>, compared with its case as the instance
/// compares it, in <var>pTaken</var>, read through the create tool's own port, endpoint and read type
/// (AD-52).</p>
/// <p><b>Caller contract:</b> an error status means the question was not answered; only a 404 is
/// "free". A name <parameter>NAMEPATTERN</parameter> refuses is never looked up and reads free.</p>
ClassMethod Taken(pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    If '$Match(pName, ..#NAMEPATTERN) Quit $$$OK
    Set tSC = ..Read(..#CREATETOOL, pName, .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) = 404 Quit $$$OK
        Quit tSC
    }
    Set pTaken = ($IsObject(tFresh) && tFresh.%IsA("%Library.DynamicObject"))
    Quit $$$OK
}

/// <p>The present server <var>pName</var>, read through the edit tool's own port, endpoint and read
/// type (AD-52), with its running state, in <var>pFresh</var>. An absent one is an error status with
/// <var>pHttpStatus</var> 404.</p>
ClassMethod Present(pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ..Read(..#UPDATETOOL, pName, .pFresh, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.LanguageServerError).#NAMEABSENT)
    }
    Quit tSC
}

/// <p>Render a failed read: a 404 as <parameter>OcuPilot.Api.LanguageServerError.NAMEABSENT</parameter>,
/// any other refusal as the port's own envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.LanguageServerError).#REASONNAMEABSENT, ##class(OcuPilot.Api.LanguageServerError).#NAMEABSENT)
    }
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Every rule this form applies, as <code>[{field, code, reason}]</code>. The sentences are
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s; a code with no sentence is absent.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = ##class(OcuPilot.Api.Error).LanguageServerViolationCodes()
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        If tReason = "" Continue
        Set tRow = {}
        Do tRow.%Set("field", ..FieldOf(tCode), "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", tReason, "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>The form field a <code>LANGUAGESERVER.&lt;FIELD&gt;.&lt;RULE&gt;</code> code refuses, or
/// <code>""</code> for a code that names no one field.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    Set tPart = $Piece(pCode, ".", 2)
    If tPart = "DOTNETVERSION" Quit ..#CUSTOMFIELD _ "." _ ..#DOTNETVERSIONMEMBER
    If tPart = "CUSTOM" Quit ..#CUSTOMFIELD
    Set tFields = ..#FIELDNAME _ "," _ ..#FIELDTYPE _ "," _ $Translate(..#WHOLEFIELDS, ":0123456789", "") _ "," _ ..#NAMEFIELDS
    For tI = 1:1:$Length(tFields, ",") {
        Set tField = $Piece(tFields, ",", tI)
        If (tField '= "") && ($ZConvert(tField, "U") = tPart) Quit
        Set tField = ""
    }
    Quit tField
}

/// <p>The violations <var>pViolations</var> as one problem naming each field and its published
/// sentence, for a tool's <code>ArgumentProblem</code>; <code>""</code> for none.</p>
ClassMethod Problem(ByRef pViolations) As %String
{
    Set tProblem = ""
    For tI = 1:1:+$Get(pViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(pViolations(tI), 2))
        Set tProblem = tProblem _ $Select(tProblem = "": "", 1: " ") _ "'" _ $List(pViolations(tI), 1) _ "': " _ tReason
    }
    Quit tProblem
}

/// <p>The one-line problem a <code>Custom</code> member <var>pField</var> that a type does not take is
/// refused with, for a tool's merge or composition: the file location's sentence when <var>pPath</var>
/// is 1, and the unknown member's otherwise.</p>
ClassMethod MemberProblem(pField As %String, pPath As %Boolean) As %String
{
    Set tCode = $Select(pPath: ##class(OcuPilot.Api.LanguageServerError).#CUSTOMPATH, 1: ##class(OcuPilot.Api.LanguageServerError).#CUSTOMUNKNOWN)
    Quit "'" _ pField _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
}

/// <p>Refuse a caller who does not hold the form's declared pairs (AD-8): <var>pRefused</var> 1
/// means the envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>Whether <var>pArgs</var>'s <var>pField</var> is a whole number from <var>pMin</var> to
/// <var>pMax</var>, sent as a JSON number or as its digits.</p>
ClassMethod Whole(pArgs As %DynamicObject, pField As %String, pMin As %Integer, pMax As %Integer) As %Boolean
{
    Set tKind = pArgs.%GetTypeOf(pField)
    If (tKind '= "number") && (tKind '= "string") Quit 0
    Set tText = "" _ pArgs.%Get(pField)
    If '$Match(tText, "[0-9]{1,6}") Quit 0
    Quit (+tText >= pMin) && (+tText <= pMax)
}

/// <p>Whether a <code>Custom</code> flag's value, of JSON kind <var>pKind</var>, is a flag: a
/// boolean, or the number 0 or 1 the instance answers it as.</p>
ClassMethod FlagValue(pKind As %String, pValue) As %Boolean
{
    If pKind = "boolean" Quit 1
    If pKind = "number" Quit (pValue = 0) || (pValue = 1)
    Quit 0
}

/// <p>Read <var>pName</var> through tool <var>pToolClass</var>'s own port, endpoint and read
/// type.</p>
ClassMethod Read(pToolClass As %String, pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pFresh = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "IdParam")) = pName
        Set tSC = $ClassMethod($ClassMethod(pToolClass, "PortClass"), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    } Catch ex {
        Set pFresh = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The rows of generated field list <var>pKey</var>.</p>
ClassMethod ListRows(pKey As %String, Output pRows As %DynamicArray) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = $$$OK
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen(..#FIELDLISTSCLASS, "Lists", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the generated field lists are missing from " _ ..#FIELDLISTSCLASS)
            Quit
        }
        Do tXData.Data.Rewind()
        Set tLists = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
        Set tXData = ""
        Set tList = ""
        If $IsObject(tLists) Set tList = tLists.%Get(pKey)
        If '$IsObject(tList) || (tList.%GetTypeOf("rows") '= "array") {
            Set tSC = $$$ERROR($$$GeneralError, pKey _ " has no list in " _ ..#FIELDLISTSCLASS)
            Quit
        }
        Set pRows = tList.%Get("rows")
    } Catch ex {
        Set pRows = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><var>pList</var> as a JSON array of strings.</p>
ClassMethod Array(pList As %List) As %DynamicArray [ Private ]
{
    Set tArray = []
    For tI = 1:1:$ListLength(pList) Do tArray.%Push($List(pList, tI))
    Quit tArray
}

/// <p>The violation code <code>LANGUAGESERVER.&lt;FIELD&gt;.&lt;RULE&gt;</code> for <var>pField</var>.</p>
ClassMethod Code(pField As %String, pRule As %String) As %String [ Private ]
{
    Quit "LANGUAGESERVER." _ $ZConvert(pField, "U") _ "." _ pRule
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
