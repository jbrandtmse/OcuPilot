/// <p>The local database editor's rules (AD-39, AD-55): the one rule set every caller of
/// <class>OcuPilot.Screen.Tool.LocalDatabaseCreate</class> and
/// <class>OcuPilot.Screen.Tool.LocalDatabaseUpdate</class> applies (<method>Validate</method>), the
/// form's read (<method>HandleForm</method>) and the wizard's step check
/// (<method>HandleCheck</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, and the form
/// read serves the same sentences, so a step's refusal and a failed Save are one wording. A directory's
/// refusals are <class>OcuPilot.Port.PathPort</class>'s own, on the field the caller's form names, and
/// a create's directory that already holds a database file is refused
/// <parameter>OcuPilot.Api.DatabaseError.DIRECTORYINUSE</parameter> (DW-1791). Every read goes through
/// the create tool's port as the caller.</p>
/// <p><b>The disk operations' rules</b> (Story 18.4) are
/// <method>OcuPilot.Port.DatabasePort.ActionViolations</method>, asked against the operation's
/// <code>STATE</code> read: at the mint (<method>ActionProblem</method>), at a Save's size group
/// (<method>Validate</method>, a <code>Size</code> in an edit) and at the integrity flow's
/// <code>globals</code> step (<method>HandleCheck</method>); the port asks them again at the write. A
/// new volume directory in use by another database is refused
/// <parameter>OcuPilot.Api.DatabaseError.DIRECTORYINUSE</parameter> (DW-1791,
/// <method>OcuPilot.Port.DatabasePort.VolumeDirectoryInUse</method>).</p>
Class OcuPilot.Area.OsMgmt.DatabaseRules Extends %RegisteredObject
{

/// <p>The tools the callers resolve the writes through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.LocalDatabaseCreate";

Parameter MOUNTTOOL = "OcuPilot.Screen.Tool.LocalDatabaseUpdateMount";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.LocalDatabaseUpdate";

/// <p>The size grow (Story 18.4), whose fresh read gives the editor the file's current size.</p>
Parameter GROWTOOL = "OcuPilot.Screen.Tool.LocalDatabaseGrow";

/// <p>The screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocalDatabaseForm";

/// <p>The screen whose declared read answers the resources a database may use.</p>
Parameter RESOURCEDESCRIPTOR = "OcuPilot.Screen.Descriptor.ResourceList";

/// <p>The endpoint whose list is the instance's database configurations.</p>
Parameter CONFIGENDPOINT = "Database.ConfigCRUD";

/// <p>The endpoint a named resource is read through.</p>
Parameter RESOURCEENDPOINT = "Security.Resource";

/// <p>The fields a create must carry, comma-separated.</p>
Parameter REQUIREDFIELDS = "Name,root";

/// <p>A name <class>Config.Databases</class> accepts: a letter, then letters, digits, <code>_</code> or
/// <code>-</code>, at most 64 characters in all (measured on <code>ocupilot-b-ci</code>, Story 18.3
/// Task 0).</p>
Parameter NAMEPATTERN = "[A-Za-z][A-Za-z0-9_-]{0,63}";

/// <p>The fields each wizard step validates, as <code>&lt;step&gt;=&lt;field&gt;:&lt;field&gt;</code>
/// entries.</p>
Parameter STEPS = "name=Name:root:path,size=Size:GlobalJournalState,resource=ResourceName,globals=Databases:Globals";

/// <p>The disk operations' endpoint and fresh read type (Story 18.4).</p>
Parameter ACTIONSENDPOINT = "Database.Actions";

Parameter STATETYPE = "STATE";

/// <p>The integrity flow's two fields: the checked directories and the global names.</p>
Parameter FIELDDATABASES = "Databases";

Parameter FIELDGLOBALS = "Globals";

/// <p>The whole-megabyte fields an edit may send, each 0 or more.</p>
Parameter MEGABYTEFIELDS = "MaxSize,ExpansionSize,NewVolumeThreshold";

/// <p>The prefix every database's resource name carries.</p>
Parameter RESOURCEPREFIX = "%DB_";

/// <p>How many resources the form read lists.</p>
Parameter RESOURCEMAXROWS As INTEGER = 1000;

Parameter FIELDNAME = "Name";

Parameter FIELDSIZE = "Size";

Parameter FIELDRESOURCE = "ResourceName";

/// <p>Every rule a database write applies to <var>pArgs</var> for the configuration <var>pName</var>,
/// in <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pMode</var> <code>create</code> applies the name's own rules, the initial size, a named
/// resource, and the directory from <code>root</code> and <code>path</code>; <code>update</code> applies
/// each whole-megabyte field, a resource (which may not be emptied) and a new volume directory from
/// <code>volumeRoot</code> and <code>volumePath</code>, each only when <var>pArgs</var> carries it (a
/// path without its root is refused on the root).
/// <var>pCheckTaken</var> 0 skips the name look-up. <var>pFields</var>, where not <code>""</code>,
/// limits the rules to those fields (a wizard step).</p>
/// <p>A read that cannot be made is an error status, never a pass; a path refusal that names no
/// field (the port's own gate) is an error status with its fault in <var>pFault</var>.</p>
ClassMethod Validate(pName As %String, pArgs As %DynamicObject, Output pViolations, pMode As %String = "create", pCheckTaken As %Boolean = 1, pFields As %List = "", Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pArgs) Set pArgs = {}
        Set tCreates = (pMode = "create")
        If tCreates && ..Checks(pFields, ..#FIELDNAME) {
            Do ..NameViolation(pName, .pViolations)
            If (pViolations = 0) && pCheckTaken {
                Set tSC = ..Taken(pName, .tTaken)
                If $$$ISERR(tSC) Quit
                If tTaken Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.DatabaseError).#NAMETAKEN)
            }
        }
        If tCreates && ..Checks(pFields, ..#FIELDSIZE) && (pArgs.%GetTypeOf(..#FIELDSIZE) '= "unassigned") {
            If '..WholeAtLeast(pArgs, ..#FIELDSIZE, 1) Do ..Add(.pViolations, ..#FIELDSIZE, ##class(OcuPilot.Api.DatabaseError).#SIZESHAPE)
        }
        If 'tCreates {
            For tI = 1:1:$Length(..#MEGABYTEFIELDS, ",") {
                Set tField = $Piece(..#MEGABYTEFIELDS, ",", tI)
                If '..Checks(pFields, tField) || (pArgs.%GetTypeOf(tField) = "unassigned") Continue
                If '..WholeAtLeast(pArgs, tField, 0) Do ..Add(.pViolations, tField, "DATABASE." _ $ZConvert(tField, "U") _ ".SHAPE")
            }
        }
        If ..Checks(pFields, ..#FIELDRESOURCE) && (pArgs.%GetTypeOf(..#FIELDRESOURCE) '= "unassigned") {
            Set tResource = ..Text(pArgs, ..#FIELDRESOURCE)
            If (tResource '= "") || 'tCreates {
                Set tSC = ..ResourceViolation(tResource, .pViolations, .pHttpStatus, .pFault)
                If $$$ISERR(tSC) Quit
            }
        }
        If tCreates && ..Checks(pFields, "root") {
            Set tSC = ..DirectoryViolations(..Text(pArgs, "root"), ..Text(pArgs, "path"), "root", "path", 1, .pViolations, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
        }
        If 'tCreates && ..Checks(pFields, "volumeRoot") && ((..Text(pArgs, "volumeRoot") '= "") || (..Text(pArgs, "volumePath") '= "")) {
            Set tSC = ##class(OcuPilot.Port.DatabasePort).DirectoryOf(pName, .tOwn, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            Set tSC = ..DirectoryViolations(..Text(pArgs, "volumeRoot"), ..Text(pArgs, "volumePath"), "volumeRoot", "volumePath", 0, .pViolations, .pHttpStatus, .pFault, tOwn)
            If $$$ISERR(tSC) Quit
        }
        If 'tCreates && ..Checks(pFields, ..#FIELDSIZE) && (pArgs.%GetTypeOf(..#FIELDSIZE) '= "unassigned") {
            Set tSC = ..GrowViolations(pName, pArgs, .pViolations, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
        }
        If (pFields '= "") && ..Checks(pFields, ..#FIELDGLOBALS) Do ..IntegrityViolations(pArgs, .pViolations)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><method>Validate</method> over the agent's arguments for <var>pIdValue</var> in mode
/// <var>pMode</var>, the name look-up never, as one <var>pProblem</var> naming each field and its
/// published sentence (AD-55). A path refusal that names no field is its reason.</p>
ClassMethod Problem(pIdValue As %String, pArgs As %DynamicObject, pMode As %String, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ..Validate(pIdValue, pArgs, .tViolations, pMode, 0, "", .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If $IsObject($Get(tFault)) && (tFault.%Get("reason") '= "") && (tFault.%Get("code") '= ##class(OcuPilot.Api.Error).#INTERNAL) {
            Set pProblem = tFault.%Get("reason")
            Quit $$$OK
        }
        Quit tSC
    }
    For tI = 1:1:$Get(tViolations) {
        Set tField = $List(tViolations(tI), 1)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ tField _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>Add the name's own violation to <var>pViolations</var>, or none: an absent name, and one
/// <parameter>NAMEPATTERN</parameter> refuses.</p>
ClassMethod NameViolation(pName As %String, Output pViolations)
{
    If pName = "" {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.DatabaseError).#NAMEREQUIRED)
        Quit
    }
    If '$Match(pName, ..#NAMEPATTERN) Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.DatabaseError).#NAMESHAPE)
}

/// <p>Add <var>pResource</var>'s violation, or none: it must begin
/// <parameter>RESOURCEPREFIX</parameter> and name a resource this instance holds, read through the
/// create tool's port as the caller (a 404 is absent). A read refused for any other reason is an error
/// status with the port's own <var>pHttpStatus</var> and <var>pFault</var>, a denial naming its
/// pair.</p>
ClassMethod ResourceViolation(pResource As %String, Output pViolations, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    If $ZConvert($Extract(pResource, 1, $Length(..#RESOURCEPREFIX)), "U") '= ..#RESOURCEPREFIX {
        Do ..Add(.pViolations, ..#FIELDRESOURCE, ##class(OcuPilot.Api.DatabaseError).#RESOURCESHAPE)
        Quit $$$OK
    }
    Kill tQuery
    Set tQuery("name") = pResource
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..#RESOURCEENDPOINT, "GET", .tQuery, "", .tHeld, .tHttp, .tFault)
    If $$$ISOK(tSC) Quit $$$OK
    If +$Get(tHttp) '= 404 {
        Set pHttpStatus = $Get(tHttp)
        Set pFault = $Get(tFault)
        Quit tSC
    }
    Do ..Add(.pViolations, ..#FIELDRESOURCE, ##class(OcuPilot.Api.DatabaseError).#RESOURCEABSENT)
    Quit $$$OK
}

/// <p>Add the directory's violations for <var>pRoot</var> and <var>pPath</var>, refused on the fields
/// <var>pRootField</var> and <var>pPathField</var>: each <class>OcuPilot.Port.PathPort</class> refusal
/// as the port names it, and, when <var>pNewDatabase</var> is 1, a directory already holding a
/// database file as <parameter>OcuPilot.Api.DatabaseError.DIRECTORYINUSE</parameter> on
/// <var>pPathField</var>. A refusal that names no field is an error status with its fault.</p>
ClassMethod DirectoryViolations(pRoot As %String, pPath As %String, pRootField As %String, pPathField As %String, pNewDatabase As %Boolean, Output pViolations, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pOwnDirectory As %String = "") As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Port.PathPort).Resolve(pRoot, pPath, ##class(OcuPilot.Port.PathPort).#KINDDIRECTORY, pRootField, pPathField, .tDirectory, .tHttp, .tFault, 0, 1)
    If $$$ISERR(tSC) {
        Set tNamed = 0
        If $IsObject($Get(tFault)) && (tFault.%GetTypeOf("detail") = "object") && $IsObject(tFault.%Get("detail").%Get("violations")) {
            Set tIterator = tFault.%Get("detail").%Get("violations").%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If '$IsObject(tRow) Continue
                Do ..Add(.pViolations, tRow.%Get("field"), tRow.%Get("code"))
                Set tNamed = 1
            }
        }
        If tNamed Quit $$$OK
        Set pHttpStatus = $Get(tHttp)
        Set pFault = $Get(tFault)
        Quit tSC
    }
    If pNewDatabase && ##class(OcuPilot.Port.DatabasePort).HoldsDatabase(tDirectory) Do ..Add(.pViolations, pPathField, ##class(OcuPilot.Api.DatabaseError).#DIRECTORYINUSE)
    If 'pNewDatabase && (pOwnDirectory '= "") {
        Set tSC = ##class(OcuPilot.Port.DatabasePort).VolumeDirectoryInUse(pOwnDirectory, tDirectory, .tInUse)
        If $$$ISERR(tSC) Quit tSC
        If tInUse Do ..Add(.pViolations, pPathField, ##class(OcuPilot.Api.DatabaseError).#DIRECTORYINUSE)
    }
    Quit $$$OK
}

/// <p>Add the size grow's violations for the configuration <var>pName</var> (Story 18.4): its
/// <code>STATE</code> read through the port as the caller, then
/// <method>OcuPilot.Port.DatabasePort.ActionViolations</method> for <code>MODIFYSIZE</code>, a state
/// refusal (a database that is not mounted) reported on <code>Size</code>. A read refused for any
/// reason is an error status with its fault.</p>
ClassMethod GrowViolations(pName As %String, pArgs As %DynamicObject, Output pViolations, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..#ACTIONSENDPOINT, ..#STATETYPE, .tQuery, "", .tState, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pHttpStatus = 0
    Set pFault = ""
    Kill tArgQuery
    Set tArgQuery(..#FIELDSIZE) = ..Text(pArgs, ..#FIELDSIZE)
    Set tCode = ##class(OcuPilot.Port.DatabasePort).ActionViolations("MODIFYSIZE", tState, .tArgQuery, .tViolations)
    If tCode '= "" Do ..Add(.pViolations, ..#FIELDSIZE, tCode)
    For tI = 1:1:+$Get(tViolations) {
        Do ..Add(.pViolations, $List(tViolations(tI), 1), $List(tViolations(tI), 2))
    }
    Quit $$$OK
}

/// <p>Add the integrity flow's violations for <var>pArgs</var>'s <parameter>FIELDDATABASES</parameter>
/// (an array of directories) and <parameter>FIELDGLOBALS</parameter> (an array of global names), as
/// <method>OcuPilot.Port.DatabasePort.ActionViolations</method> answers them for
/// <code>INTEGRITYCHECK</code> without a state read: at least one database, each name's shape, and
/// globals for one database only.</p>
ClassMethod IntegrityViolations(pArgs As %DynamicObject, Output pViolations)
{
    Set tDirectories = []
    If pArgs.%GetTypeOf(..#FIELDDATABASES) = "array" Set tDirectories = pArgs.%Get(..#FIELDDATABASES)
    Set tState = {"Dismounted": ""}
    Do tState.%Set("Directory", ##class(OcuPilot.Port.DatabasePort).CanonicalSet(tDirectories.%ToJSON()), "string")
    If tDirectories.%Size() = 0 Do tState.%Set("Directory", "", "string")
    Kill tQuery
    If pArgs.%GetTypeOf(..#FIELDGLOBALS) = "array" {
        Set tQuery(..#FIELDGLOBALS) = pArgs.%Get(..#FIELDGLOBALS).%ToJSON()
    } ElseIf pArgs.%GetTypeOf(..#FIELDGLOBALS) '= "unassigned" {
        Set tQuery(..#FIELDGLOBALS) = "invalid"
    }
    Set tCode = ##class(OcuPilot.Port.DatabasePort).ActionViolations("INTEGRITYCHECK", tState, .tQuery, .tViolations)
    For tI = 1:1:+$Get(tViolations) {
        Do ..Add(.pViolations, $List(tViolations(tI), 1), $List(tViolations(tI), 2))
    }
}

/// <p>The agent's arguments <var>pArgs</var> for disk operation tool <var>pToolClass</var> against
/// <var>pIdValue</var>, refused as one <var>pProblem</var> (AD-55): the target's <code>STATE</code>
/// read through the tool's own port and read type as the caller, the tool's own port query built from
/// <var>pArgs</var>, and <method>OcuPilot.Port.DatabasePort.ActionViolations</method> for the tool's
/// write type -- a state refusal as its published sentence, an integrity set's dismounted members
/// named after it in parentheses, and each argument refusal as <code>'field': sentence</code>. A read
/// refused for any reason but absence is its reason; an absent target is the mint's own refusal,
/// reached before this.</p>
ClassMethod ActionProblem(pToolClass As %String, pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "IdParam")) = pIdValue
        Set tReadSC = $ClassMethod($ClassMethod(pToolClass, "PortClass"), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .tState, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            If $IsObject($Get(tFault)) && (tFault.%Get("reason") '= "") && (tFault.%Get("code") '= ##class(OcuPilot.Api.Error).#INTERNAL) {
                Set pProblem = tFault.%Get("reason")
                Quit
            }
            Set tSC = tReadSC
            Quit
        }
        Kill tArgQuery
        Do $ClassMethod(pToolClass, "PortQuery", pArgs, .tArgQuery)
        Set tCode = ##class(OcuPilot.Port.DatabasePort).ActionViolations($ClassMethod(pToolClass, "WriteType"), tState, .tArgQuery, .tViolations)
        If tCode '= "" {
            Set pProblem = ##class(OcuPilot.Api.DatabaseError).ReasonFor(tCode)
            If ##class(OcuPilot.Port.DatabasePort).IsSet(..Text(tState, "Directory")) && (..Text(tState, "Dismounted") '= "") Set pProblem = pProblem _ " (" _ ..Text(tState, "Dismounted") _ ")"
            Quit
        }
        For tI = 1:1:+$Get(tViolations) {
            Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        }
    } Catch ex {
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether a configuration already carries <var>pName</var>, compared without regard to case, in
/// <var>pTaken</var>, read from <parameter>CONFIGENDPOINT</parameter>'s <code>LIST</code> through the
/// create tool's port as the caller. A name <parameter>NAMEPATTERN</parameter> refuses is never looked
/// up and reads free; a list that cannot be read is an error status.</p>
ClassMethod Taken(pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    If '$Match(pName, ..#NAMEPATTERN) Quit $$$OK
    Kill tQuery
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..#CONFIGENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tRows)) || 'tRows.%IsA("%Library.DynamicArray") Quit $$$ERROR($$$GeneralError, "the database configuration list did not answer an array")
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && ($ZConvert(tRow.%Get("Name"), "U") = $ZConvert(pName, "U")) Set pTaken = 1 Quit
    }
    Quit $$$OK
}

/// <p>The port every read here goes through: the create tool's own declaration (AD-52).</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#CREATETOOL, "PortClass")
}

/// <p>Answer <code>GET /database/form[?name=&lt;n&gt;]</code>: <code>{requiredFields, rules}</code>,
/// with <code>resources</code>, the <code>%DB_*</code> resource names, when the caller may read the
/// Resources list, and <code>resourcesRefused</code> naming the pair it lacks otherwise. With a name it
/// adds <code>Name</code>, <code>configuration</code> (the mounting edit's fresh read) and
/// <code>file</code> (the file edit's fresh read, <code>Directory</code> included), and
/// <code>size</code>, <code>{Size}</code> from the size grow's fresh read (Story 18.4), where that read
/// answers; a name this instance does not hold is 404
/// <parameter>OcuPilot.Api.DatabaseError.NAMEABSENT</parameter>.</p>
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
        Set tRequired = []
        For tI = 1:1:$Length(..#REQUIREDFIELDS, ",") Do tRequired.%Push($Piece(..#REQUIREDFIELDS, ",", tI))
        Do tBody.%Set("requiredFields", tRequired)
        Do tBody.%Set("rules", ..Rules())
        Set tFailedPair = ""
        If ##class(OcuPilot.Screen.Gate).Evaluate(..#RESOURCEDESCRIPTOR, .tFailedPair) {
            Set tListSC = ..Resources(.tResources)
            If $$$ISERR(tListSC) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tListSC))
                Quit
            }
            Do tBody.%Set("resources", tResources)
        } Else {
            Do tBody.%Set("resourcesRefused", tFailedPair, "string")
        }
        Set tName = $Get(%request.Data("name", 1))
        If tName '= "" {
            Set tReadSC = ..Read(..#MOUNTTOOL, tName, .tConfiguration, .tHttp, .tFault)
            If $$$ISOK(tReadSC) Set tReadSC = ..Read(..#UPDATETOOL, tName, .tFile, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, $Get(tHttp), $Get(tFault))
                Quit
            }
            Do tBody.%Set(..#FIELDNAME, $ZConvert(tName, "U"), "string")
            Do tBody.%Set("configuration", ##class(OcuPilot.Port.DatabasePort).Without(tConfiguration, $ListBuild("DeleteFile")))
            Do tBody.%Set("file", ##class(OcuPilot.Port.DatabasePort).Without(tFile, $ListBuild("volumeRoot", "volumePath")))
            ; The editor's Size (MB): the grow's own read, left out where it does not answer, so a
            ; file the size read cannot reach still opens the rest of the editor.
            If $$$ISOK(..Read(..#GROWTOOL, tName, .tState, .tSizeHttp, .tSizeFault)) && (tState.%GetTypeOf("Size") = "number") {
                Set tSize = {}
                Do tSize.%Set("Size", tState.%Get("Size"), "number")
                Do tBody.%Set("size", tSize)
            }
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>POST /database/check</code>: the wizard's Next, <code>{step, values}</code>
/// validated on the instance for that step's fields (<parameter>STEPS</parameter>), answered as
/// <code>{violations}</code>. A step this form does not have is 400; a path refusal that names no
/// field is its own envelope.</p>
ClassMethod HandleCheck() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tBody = ""
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) || '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") || (tBody.%GetTypeOf("values") '= "object") {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tFields = ..StepFields(tBody.%Get("step"))
        If tFields = "" {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tValues = tBody.%Get("values")
        Set tValidSC = ..Validate(..Text(tValues, ..#FIELDNAME), tValues, .tViolations, "create", 1, tFields, .tHttp, .tFault)
        If $$$ISERR(tValidSC) {
            If $IsObject($Get(tFault)) && (tFault.%Get("code") '= ##class(OcuPilot.Api.Error).#INTERNAL) {
                Set tSC = ##class(OcuPilot.Api.Error).Render($Select(+$Get(tHttp): +tHttp, 1: 500), tFault.error, tFault.reason, tFault.code, tFault.%Get("detail"))
                Quit
            }
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tValidSC))
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.tViolations))
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The fields wizard step <var>pStep</var> validates, as a <class>%List</class>, or
/// <code>""</code> for a step this form does not have.</p>
ClassMethod StepFields(pStep As %String) As %List
{
    Set tFields = ""
    For tI = 1:1:$Length(..#STEPS, ",") {
        Set tEntry = $Piece(..#STEPS, ",", tI)
        If $Piece(tEntry, "=", 1) '= pStep Continue
        Set tFields = $ListFromString($Piece(tEntry, "=", 2), ":")
        Quit
    }
    Quit tFields
}

/// <p>The <code>%DB_*</code> resource names the Resources list's declared read answers the caller,
/// in its order.</p>
ClassMethod Resources(Output pNames As %DynamicArray) As %Status
{
    Set pNames = []
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#RESOURCEDESCRIPTOR, ..#RESOURCEMAXROWS, .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    Set tRows = tResult.%Get("rows")
    If '$IsObject(tRows) Quit $$$OK
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tName = tRow.%Get("Name")
        If $ZConvert($Extract(tName, 1, $Length(..#RESOURCEPREFIX)), "U") = ..#RESOURCEPREFIX Do pNames.%Push(tName, "string")
    }
    Quit $$$OK
}

/// <p>Read <var>pName</var> through tool <var>pToolClass</var>'s own port, endpoint and read type. An
/// absent configuration is an error status with <var>pHttpStatus</var> 404.</p>
ClassMethod Read(pToolClass As %String, pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pFresh = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "IdParam")) = pName
        Set tSC = $ClassMethod($ClassMethod(pToolClass, "PortClass"), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
        If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
            Set pHttpStatus = 404
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.DatabaseError).#NAMEABSENT)
        }
    } Catch ex {
        Set pFresh = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Render a failed read: a 404 as <parameter>OcuPilot.Api.DatabaseError.NAMEABSENT</parameter>, any
/// other refusal as the port's own envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.DatabaseError).#REASONNAMEABSENT, ##class(OcuPilot.Api.DatabaseError).#NAMEABSENT)
    }
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Every rule this form applies, as <code>[{field, code, reason}]</code>.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = ##class(OcuPilot.Api.Error).DatabaseViolationCodes()
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

/// <p>The form field a <code>DATABASE.&lt;FIELD&gt;.&lt;RULE&gt;</code> code refuses.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    Set tPart = $Piece(pCode, ".", 2)
    If tPart = "NAME" Quit ..#FIELDNAME
    If tPart = "DIRECTORY" Quit "path"
    If tPart = "SIZE" Quit ..#FIELDSIZE
    If tPart = "RESOURCE" Quit ..#FIELDRESOURCE
    If tPart = "MAXSIZE" Quit "MaxSize"
    If tPart = "EXPANSIONSIZE" Quit "ExpansionSize"
    If tPart = "NEWVOLUMETHRESHOLD" Quit "NewVolumeThreshold"
    If tPart = "TARGETSIZE" Quit "TargetSize"
    If tPart = "TARGETFREE" Quit "TargetFreeSpace"
    If tPart = "GROWSIZE" Quit ..#FIELDSIZE
    If tPart = "INITIALSIZE" Quit "InitialSize"
    If tPart = "INTEGRITY" Quit ..#FIELDDATABASES
    If tPart = "GLOBALS" Quit ..#FIELDGLOBALS
    Quit ""
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

/// <p>Whether <var>pArgs</var>'s <var>pField</var> is a whole number of at least <var>pMinimum</var>:
/// a JSON number, or a string of digits.</p>
ClassMethod WholeAtLeast(pArgs As %DynamicObject, pField As %String, pMinimum As %Integer) As %Boolean
{
    Set tType = pArgs.%GetTypeOf(pField)
    If (tType '= "number") && (tType '= "string") Quit 0
    Set tValue = pArgs.%Get(pField)
    If '$Match(tValue, "[0-9]{1,9}") Quit 0
    Quit (+tValue >= pMinimum)
}

/// <p>Whether <var>pField</var> is among <var>pFields</var>, where <code>""</code> is every field.</p>
ClassMethod Checks(pFields As %List, pField As %String) As %Boolean [ Private ]
{
    If pFields = "" Quit 1
    Quit ''$ListFind(pFields, pField)
}

/// <p><var>pObject</var>'s <var>pField</var> as text: a null or absent field as <code>""</code>.</p>
ClassMethod Text(pObject As %DynamicObject, pField As %String) As %String [ Private ]
{
    If '$IsObject(pObject) Quit ""
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pObject.%Get(pField)
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
