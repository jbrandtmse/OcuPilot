/// <p>The audit database's export tool (AD-6, AD-21, AD-51, AD-52, AD-53): write the audit records of this instance
/// to a new server file, in the instance's own export format. The agent reaches it through a proposal the user
/// confirms; the Auditing screen reaches it through its <code>export</code> row action, with the file and an
/// optional cut-off day as the action's three values (AD-56 (ii)).</p>
/// <p><b>The file is named by <code>ExportRoot</code> and <code>ExportPath</code></b>, an allowed directory and a
/// relative name under it (AD-21's sixth case), and nothing else. They travel in the port query
/// (<method>PortQuery</method>); <class>OcuPilot.Port.AuditPort</class> resolves them through
/// <class>OcuPilot.Port.PathPort</class> at the write, and the agent's mint resolves them first
/// (<class>OcuPilot.Screen.Tool.AuditExportMint</class>), so a refusal lands on its field on either path. A file
/// already at the name is refused, never replaced.</p>
/// <p><b>It is action-style</b> (AD-51): the tool sends no body, and the port starts the vendor's own export task,
/// as the classic export page does, so the write is answered 202 started and the task's end is the Background tasks
/// row's to show (AD-26). <code>ExportBefore</code>, a day <code>YYYY-MM-DD</code>, limits the export to records
/// dated before that day's midnight, instance time; empty exports every record.</p>
/// <p>The export file holds what the vendor writes, <code>EventData</code> included, unmasked (AD-35 masks
/// OcuPilot's own surfaces only), so the card says what the file is. It is not destructive: it removes nothing, and
/// the vendor records its own <code>AuditChange</code> event.</p>
/// <p><b>Its pairs are the Auditing screen's, <code>%Admin_FileSystemAccess:USE</code> for the file and
/// <code>%DB_IRISAUDIT:READ</code> for the audit database the task reads</b> (AD-8), then the custom resource of
/// the classic export page (AD-44).</p>
Class OcuPilot.Screen.Tool.AuditExport Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.auditing.export";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuditingConfig";

Parameter DESCRIPTION = "Propose writing this instance's audit records to a new file on the server, in the instance's own audit export format. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the file by `ExportRoot`, an allowed directory exactly as the Allowed directories screen lists it, and `ExportPath`, a relative file name under it whose directory exists; a file already at that name is refused. Name `ExportBefore`, a day written YYYY-MM-DD, to export only the records dated before it, or leave it out to export every record, which can be a very large file. The file holds the records as the audit database stores them, including each event's data, so say so in the rationale. The export runs in the background and ends in the Background tasks list. The target is the instance's auditing configuration, which has exactly one instance.";

Parameter PORTCLASS = "OcuPilot.Port.AuditPort";

/// <p>The fresh read: the audit database's state, answered by the port with the three argument fields empty.</p>
Parameter READTYPE = "DATABASE";

Parameter WRITETYPE = "EXPORT";

/// <p>No body: the port composes the call (<parameter>OcuPilot.Port.AuditPort.COMPOSEDTYPES</parameter>).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>Not destructive: an export removes nothing.</p>
Parameter DESTRUCTIVE As BOOLEAN = 0;

Parameter SCREENACTIONS = "export";

Parameter SCREENVALUES = "export=ExportRoot:ExportPath:ExportBefore";

/// <p>The cut-off day may be left out or sent empty: either exports every record.</p>
Parameter SCREENOPTIONAL = "export=ExportBefore";

Parameter SCREENEMPTY = "export=ExportBefore";

Parameter READANSWERS = "Enabled,CopyNamespace,PurgeBefore,ExportRoot,ExportPath,ExportBefore";

/// <p>A file names the export, so a read that did not answer <code>ExportPath</code> is not one to export from.</p>
Parameter PRECONDITIONFIELD = "ExportPath";

/// <p>The file and the cut-off the user reviewed. They are in the subject because the stored payload is narrowed to
/// them, and <method>PortQuery</method> reads them from that payload.</p>
Parameter FINGERPRINTSUBJECT = "ExportRoot,ExportPath,ExportBefore";

/// <p>The classic page whose Export this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Audit.ExportLog";

/// <p>The pair the file adds to the screen's own (AD-21).</p>
Parameter WRITERESOURCE = "%Admin_FileSystemAccess";

Parameter WRITEPERMISSION = "USE";

/// <p>The pair the export task's read of the audit database adds (AD-8).</p>
Parameter EXTRAPAIRS = "%DB_IRISAUDIT:READ";

/// <p>The consequence code the proposal carries: the export writes the audit records, event data included, to a new
/// file.</p>
Parameter CONSEQUENCE = "AUDIT.EXPORT.WRITES";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AuditPort).#RECORDENDPOINT
}

/// <p>The file and the optional cut-off: the tool sends no body, so its field list is empty by derivation, and the
/// three arguments reach the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.AuditPort).#EXPORTROOTQUERY, ##class(OcuPilot.Port.AuditPort).#EXPORTPATHQUERY, ##class(OcuPilot.Port.AuditPort).#EXPORTBEFOREQUERY)
}

/// <p>The class the agent's proposal is minted by: the kernel's own mint, after the file is resolved
/// (<class>OcuPilot.Screen.Tool.AuditExportMint</class>).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.AuditExportMint"
}

/// <p>The identifying property as <class>OcuPilot.Screen.Tool.AuditingUpdate</class> describes it, then
/// <code>ExportRoot</code> and <code>ExportPath</code> required and <code>ExportBefore</code> optional.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The target is this instance's one auditing configuration, so send the literal '" _ ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID _ "'. Any other spelling names the same configuration.", "string")
    }
    Do tProperties.%Set(##class(OcuPilot.Port.AuditPort).#EXPORTROOTQUERY, {"type": "string", "description": "An allowed directory on the server, exactly as this instance's Allowed directories screen lists it. Any other value is refused."})
    Do tProperties.%Set(##class(OcuPilot.Port.AuditPort).#EXPORTPATHQUERY, {"type": "string", "description": "The new file's name relative to ExportRoot: up to eight names separated by '/', each starting with a letter or digit and holding only letters, digits, dots, underscores and dashes. Never a full path. A file already at the name is refused."})
    Do tProperties.%Set(##class(OcuPilot.Port.AuditPort).#EXPORTBEFOREQUERY, {"type": "string", "maxLength": 10, "description": "Optional. A day written YYYY-MM-DD: only the records dated before its midnight, instance time, are exported. Leave it out to export every record. A day after today on this instance is refused."})
    Do tSchema.%Get("required").%Push(##class(OcuPilot.Port.AuditPort).#EXPORTROOTQUERY)
    Do tSchema.%Get("required").%Push(##class(OcuPilot.Port.AuditPort).#EXPORTPATHQUERY)
    Quit tSchema
}

/// <p>The screen's own pairs, then <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter> and
/// each <parameter>EXTRAPAIRS</parameter> pair the set lacks, then the custom resource of the
/// <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-21, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    For tI = 1:1:$Length(..#EXTRAPAIRS, ",") {
        Set tEntry = $ZStrip($Piece(..#EXTRAPAIRS, ",", tI), "<>W")
        If tEntry = "" Continue
        Set tPair = $ListBuild($Piece(tEntry, ":", 1), $Piece(tEntry, ":", 2))
        If '$ListFind(tPairs, tPair) Set tPairs = tPairs _ $ListBuild(tPair)
    }
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>What is wrong with <var>pArgs</var>' file arguments, or <code>""</code>: <code>ExportRoot</code> and
/// <code>ExportPath</code> are each a non-empty string. Their shape and place are the port's to judge at the
/// resolve, so a refusal lands on its field.</p>
ClassMethod FileProblem(pArgs As %DynamicObject) As %String
{
    Set tRoot = ##class(OcuPilot.Port.AuditPort).#EXPORTROOTQUERY
    Set tPath = ##class(OcuPilot.Port.AuditPort).#EXPORTPATHQUERY
    If '$IsObject(pArgs) Quit "'" _ tRoot _ "' and '" _ tPath _ "' name the file"
    If (pArgs.%GetTypeOf(tRoot) '= "string") || (pArgs.%Get(tRoot) = "") Quit "'" _ tRoot _ "' names an allowed directory and cannot be empty"
    If (pArgs.%GetTypeOf(tPath) '= "string") || (pArgs.%Get(tPath) = "") Quit "'" _ tPath _ "' names the file under " _ tRoot _ " and cannot be empty"
    Quit ""
}

/// <p>What is wrong with <var>pValue</var> as the cut-off day, or <code>""</code>: empty, or
/// <code>YYYY-MM-DD</code>, a real date, and no later than today on the instance's own calendar
/// (<code>+$Horolog</code>, Conventions, Dates).</p>
ClassMethod BeforeProblem(pValue As %String) As %String
{
    Set tName = ##class(OcuPilot.Port.AuditPort).#EXPORTBEFOREQUERY
    If pValue = "" Quit ""
    If '$Match(pValue, "^\d{4}-\d{2}-\d{2}$") Quit "'" _ tName _ "' must be a date written YYYY-MM-DD"
    Set tDay = $ZDateH(pValue, 3, , , , , , , -1)
    If tDay = -1 Quit "'" _ pValue _ "' is not a date"
    If tDay > +$Horolog Quit "'" _ pValue _ "' is after today on this instance, and an export cannot cut off in the future"
    Quit ""
}

/// <p>The agent's arguments refused by <method>FileProblem</method> and <method>BeforeProblem</method> before
/// anything is stored (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..FileProblem(pArgs)
    If (pProblem = "") && $IsObject(pArgs) {
        Set tBefore = ##class(OcuPilot.Port.AuditPort).#EXPORTBEFOREQUERY
        If (pArgs.%GetTypeOf(tBefore) '= "unassigned") && (pArgs.%GetTypeOf(tBefore) '= "string") {
            Set pProblem = "'" _ tBefore _ "' must be a date written YYYY-MM-DD"
        } Else {
            Set pProblem = ..BeforeProblem(pArgs.%Get(tBefore))
        }
    }
    Quit $$$OK
}

/// <p>The screen's three values as this tool's arguments, the file unresolved so the write's own <code>PATH.*</code>
/// refusal reaches the field it is about, and the cut-off refused by <method>BeforeProblem</method> as the agent's
/// is (AD-56 (ii)). An empty cut-off is no argument.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    For tField = ##class(OcuPilot.Port.AuditPort).#EXPORTROOTQUERY, ##class(OcuPilot.Port.AuditPort).#EXPORTPATHQUERY, ##class(OcuPilot.Port.AuditPort).#EXPORTBEFOREQUERY {
        If $IsObject(pValues) && (pValues.%GetTypeOf(tField) = "string") && ((pValues.%Get(tField) '= "") || (tField '= ##class(OcuPilot.Port.AuditPort).#EXPORTBEFOREQUERY)) Do pArgs.%Set(tField, pValues.%Get(tField), "string")
    }
    Set pProblem = ..FileProblem(pArgs)
    If pProblem = "" Set pProblem = ..BeforeProblem(pArgs.%Get(##class(OcuPilot.Port.AuditPort).#EXPORTBEFOREQUERY))
    Quit $$$OK
}

/// <p>The stored payload's three arguments under the port's own query keys, so the confirm's write and the screen's
/// carry the file and the day the user reviewed (AD-52). An absent cut-off is the empty one.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    For tField = ##class(OcuPilot.Port.AuditPort).#EXPORTROOTQUERY, ##class(OcuPilot.Port.AuditPort).#EXPORTPATHQUERY, ##class(OcuPilot.Port.AuditPort).#EXPORTBEFOREQUERY {
        If pPayload.%GetTypeOf(tField) = "string" Set pQuery(tField) = pPayload.%Get(tField)
    }
}

/// <p>No state row: the merge's file and day rows are the card's.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p><parameter>CONSEQUENCE</parameter>, whatever the payload: the file holds the audit records, event data
/// included.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

}
