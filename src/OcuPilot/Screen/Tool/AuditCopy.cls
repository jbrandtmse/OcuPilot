/// <p>The audit database's copy tool (AD-51, AD-52, AD-53, FR-75): copy every record in this
/// instance's audit database into another namespace's audit globals. The agent reaches it through a
/// proposal the user confirms; the Auditing screen reaches it through its <code>copy</code> row
/// action, with the namespace as the action's one value (AD-56 (ii)).</p>
/// <p><b>It is action-style</b> (AD-51): the tool sends no body, and
/// <class>OcuPilot.Port.AuditPort</class> composes the vendor's
/// <code>Security.Audit.Record</code> <code>COPY</code> body from <code>CopyNamespace</code>, which
/// travels in the port query (<method>PortQuery</method>). The copy deletes nothing, and no caller
/// can ask it to. The vendor runs it in a Work Queue worker and the port awaits it within its bound
/// (AD-26); past the bound the port answers that the copy has started, and the worker finishes
/// it.</p>
/// <p><b>The fingerprint subject is the argument itself</b> (AD-51 adequacy): nothing in the audit
/// database is a precondition of copying it, so what the user reviewed is this namespace. The card's
/// one row is the merge's <code>CopyNamespace</code> row.</p>
/// <p><b>Its pairs are the Auditing screen's and <code>%Admin_Operate:USE</code></b> (AD-8 as
/// amended 2026-09-24): the port polls the queued copy through the <code>AsyncResult</code>
/// endpoint, whose own gate names that resource, so a caller without it is refused by name before
/// anything is queued.</p>
/// <p>It is not destructive: the copy removes nothing, and the vendor records its own
/// <code>%System/%Security/AuditChange</code> event.</p>
Class OcuPilot.Screen.Tool.AuditCopy Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.auditing.copy";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuditingConfig";

Parameter DESCRIPTION = "Propose copying every record in this instance's audit database into another namespace's audit globals. It changes nothing by itself: it answers a proposal the user reviews and confirms. The copy deletes nothing, and the originals stay where they are. Anyone who can read that namespace's database can read the copy, so say so in the rationale. The target is the instance's auditing configuration, which has exactly one instance.";

/// <p>The port that composes the vendor body from the namespace (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.AuditPort";

/// <p>The fresh read: the audit database's state, answered by the port with the argument field
/// empty.</p>
Parameter READTYPE = "DATABASE";

Parameter WRITETYPE = "COPY";

/// <p>No body: the port composes it (<parameter>OcuPilot.Port.AuditPort.COMPOSEDTYPES</parameter>).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>Not destructive: the copy removes nothing.</p>
Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>The Auditing screen's <code>copy</code> row action (AD-53), whose one value is
/// <parameter>NAMESPACEFIELD</parameter>.</p>
Parameter SCREENACTIONS = "copy";

Parameter SCREENVALUES = "copy=CopyNamespace";

/// <p>What <parameter>READTYPE</parameter> answers (DW-1475).</p>
Parameter READANSWERS = "Enabled,CopyNamespace,PurgeBefore";

Parameter PRECONDITIONFIELD = "CopyNamespace";

Parameter FINGERPRINTSUBJECT = "CopyNamespace";

/// <p>The one argument this tool admits: the namespace the records are copied into.</p>
Parameter NAMESPACEFIELD = "CopyNamespace";

/// <p>The pair the port's poll of the queued copy requires beyond the screen's own.</p>
Parameter WRITERESOURCE = "%Admin_Operate";

Parameter WRITEPERMISSION = "USE";

/// <p>A namespace name: a letter or <code>%</code>, then letters, digits, <code>_</code> and
/// <code>-</code>. An implied namespace names a directory, which no caller may (AD-21).</p>
Parameter NAMESPACEPATTERN = "^[%A-Za-z][A-Za-z0-9_-]*$";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AuditPort).#RECORDENDPOINT
}

/// <p><parameter>NAMESPACEFIELD</parameter> alone: the tool sends no body, so its field list is
/// empty by derivation, and the one argument it takes reaches the port through
/// <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#NAMESPACEFIELD)
}

/// <p>The identifying property as <class>OcuPilot.Screen.Tool.AuditingUpdate</class> describes it,
/// and <parameter>NAMESPACEFIELD</parameter>, required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The target is this instance's one auditing configuration, so send the literal '" _ ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID _ "'. Any other spelling names the same configuration.", "string")
    }
    Do tProperties.%Set(..#NAMESPACEFIELD, {"type": "string", "description": "The namespace whose audit globals receive the copy, exactly as this instance's namespace list reports it. %SYS, which holds the audit database itself, and a namespace this instance does not have are refused."})
    Do tSchema.%Get("required").%Push(..#NAMESPACEFIELD)
    Quit tSchema
}

/// <p>No state row: the merge's <parameter>NAMESPACEFIELD</parameter> row is the card's.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The stored payload's <parameter>NAMESPACEFIELD</parameter>, under the port's own query key, so
/// the confirm's write and the screen's write carry the namespace the user reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#NAMESPACEFIELD) '= "string" Quit
    Set pQuery(##class(OcuPilot.Port.AuditPort).#NAMESPACEQUERY) = pPayload.%Get(..#NAMESPACEFIELD)
}

/// <p>What is wrong with <var>pValue</var> as the namespace a copy targets, or <code>""</code>: it
/// must be a namespace name this instance has, and not <code>%SYS</code>, which holds the audit
/// database and which the vendor refuses to copy into.</p>
ClassMethod NamespaceProblem(pValue As %String) As %String
{
    If pValue = "" Quit "'" _ ..#NAMESPACEFIELD _ "' names the namespace to copy into and cannot be empty"
    If '$Match(pValue, ..#NAMESPACEPATTERN) Quit "'" _ ..#NAMESPACEFIELD _ "' must be a namespace name, not a path or an expression"
    If $ZConvert(pValue, "U") = "%SYS" Quit "the audit database is %SYS's own, so it cannot be copied into %SYS"
    If '##class(%SYS.Namespace).Exists($ZConvert(pValue, "U")) Quit "this instance has no namespace '" _ pValue _ "'"
    Quit ""
}

/// <p>The agent's arguments refused by <method>NamespaceProblem</method> before anything is stored
/// (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) Quit $$$OK
    Set pProblem = ..NamespaceProblem(pArgs.%Get(..#NAMESPACEFIELD))
    Quit $$$OK
}

/// <p>The screen's <code>copy</code> value as this tool's argument, refused by
/// <method>NamespaceProblem</method> exactly as the agent's is (AD-56 (ii)).</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tValue = ""
    If $IsObject(pValues) Set tValue = pValues.%Get(..#NAMESPACEFIELD)
    Set pProblem = ..NamespaceProblem(tValue)
    If pProblem = "" Do pArgs.%Set(..#NAMESPACEFIELD, tValue, "string")
    Quit $$$OK
}

/// <p>The screen's own pairs (<method>OcuPilot.Screen.Gate.RequiredPairs</method>) and
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, appended once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
