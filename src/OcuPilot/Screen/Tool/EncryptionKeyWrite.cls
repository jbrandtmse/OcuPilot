/// <p>The base of Story 18.22's four encryption key tools (AD-21's sixth case, AD-51, AD-52, AD-56 (i)):
/// an activation of a key file's keys and a deactivation of one active key, for database keys and for
/// data-element keys. Each targets its descriptor's singleton, the instance's set of active keys of that
/// kind, scope <code>instance</code>, id <code>SYSTEM</code> (AD-13), so an activation and a deactivation
/// of one kind share AD-34's lock.</p>
/// <p><b>Action-style with a port-built body.</b> No body is sent from the payload: the tool's declared
/// non-secret arguments and its constant <parameter>ACTION</parameter> travel in the port query
/// (<method>PortQuery</method>) and its declared secret as the secret-only body, and
/// <class>OcuPilot.Port.EncryptionPort</class> builds the vendor's body. The fresh read is the
/// port-composed active keys of the kind (<parameter>READTYPE</parameter>), beside each argument empty, so
/// the merge carries the arguments into the stored payload the port query reads; the fingerprint covers
/// the key list and the arguments (AD-51).</p>
/// <p><b>Its pairs</b> are the screen's own, then <parameter>EXTRAPAIRS</parameter>, then the custom
/// resource of each <parameter>CLASSICPAGES</parameter> page, refused by name before any port call (AD-8,
/// AD-44). The vendor records <code>%System/%Security/DBEncChange</code> for every activation and
/// deactivation (AD-15, measured).</p>
/// <p>A concrete tool declares <parameter>TOOLNAME</parameter>, <parameter>DESCRIPTORCLASS</parameter>,
/// <parameter>DESCRIPTION</parameter>, <parameter>ENDPOINT</parameter>, <parameter>READTYPE</parameter>,
/// <parameter>WRITETYPE</parameter>, <parameter>ACTION</parameter>, <parameter>ARGUMENTS</parameter>,
/// <parameter>REQUIREDARGUMENTS</parameter> and <parameter>CONSEQUENCE</parameter>, and answers
/// <method>StateRefusal</method> where the active list rules the action out.</p>
Class OcuPilot.Screen.Tool.EncryptionKeyWrite Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

/// <p>The port that resolves the key file and builds every body (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.EncryptionPort";

/// <p>No merge body: the port builds the vendor's (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>What the port-composed fresh read answers.</p>
Parameter READANSWERS = "Keys,root,path,AdminName,KeyId";

/// <p>The active list, whose movement invalidates the reviewed intent (AD-51).</p>
Parameter PRECONDITIONFIELD = "Keys";

/// <p>The vendor endpoint this tool's write goes to, declared by the subclass.</p>
Parameter ENDPOINT;

/// <p>The vendor action this tool's write sends, a constant and never a caller value.</p>
Parameter ACTION;

/// <p>The tool's declared non-secret arguments, comma-separated, each a key the port query carries.</p>
Parameter ARGUMENTS;

/// <p>The arguments the schema requires, beside the target.</p>
Parameter REQUIREDARGUMENTS;

/// <p>The arguments <class>OcuPilot.Area.Security.EncryptionRules</class> judges at the mint.</p>
Parameter RULEFIELDS;

/// <p>The pairs beyond the screen's own, as comma-separated <code>resource:permission</code>.</p>
Parameter EXTRAPAIRS;

/// <p>The consequence the card states.</p>
Parameter CONSEQUENCE;

/// <p>The deactivations' state refusal, published once in EXPERIENCE.md and pinned equal to
/// <code>OcuPilot.Api.EncryptionError.REASONKEYINACTIVE</code>.</p>
Parameter REASONKEYINACTIVE = "This key is not active.";

/// <p>The argument the activate mint sets to the key file's key ids, which the card lists
/// (<method>MergeUpdate</method>); no caller supplies it.</p>
Parameter FILEKEYSARGUMENT = "FileKeys";

ClassMethod Endpoint() As %String
{
    Quit ..#ENDPOINT
}

/// <p><parameter>ARGUMENTS</parameter>: the tool sends no body, and these reach the port through
/// <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#ARGUMENTS)
}

/// <p>The schema: the singleton target, then each argument with its shape in prose, the required ones
/// required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The target is this instance's one set of active keys of this screen's kind, so send the literal '" _ ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID _ "'.", "string")
    }
    Set tArguments = $ListFromString(..#ARGUMENTS)
    For tI = 1:1:$ListLength(tArguments) {
        Set tName = $List(tArguments, tI)
        Do tProperties.%Set(tName, ..ArgumentProperty(tName))
    }
    Set tRequired = $ListFromString(..#REQUIREDARGUMENTS)
    For tI = 1:1:$ListLength(tRequired) {
        Do tSchema.%Get("required").%Push($List(tRequired, tI))
    }
    Quit tSchema
}

/// <p>The schema property of argument <var>pName</var>.</p>
ClassMethod ArgumentProperty(pName As %String) As %DynamicObject
{
    If pName = "root" Quit {"type": "string", "description": "The allowed directory the key file is in, exactly as this instance's Allowed directories screen lists it. Any other value is refused."}
    If pName = "path" Quit {"type": "string", "description": "The key file's name relative to root: up to eight names separated by '/', each starting with a letter or digit and holding only letters, digits, dots, underscores and dashes. Never a full path."}
    If pName = "AdminName" Quit {"type": "string", "description": "An administrator the key file lists, up to 50 characters; the person supplies its password at confirmation."}
    If pName = "KeyId" Quit {"type": "string", "description": "The key identifier to deactivate, exactly as this screen's list of active keys reports it."}
    Quit {"type": "string"}
}

/// <p>The screen's own pairs, then <parameter>EXTRAPAIRS</parameter>, then the custom resource of each
/// <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tExtra = ..#EXTRAPAIRS
    For tI = 1:1:$Length(tExtra, ",") {
        Set tEntry = $Piece(tExtra, ",", tI)
        If tEntry = "" Continue
        Set tPair = $ListBuild($Piece(tEntry, ":", 1), $Piece(tEntry, ":", 2))
        If '$ListFind(tPairs, tPair) Set tPairs = tPairs _ $ListBuild(tPair)
    }
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>The agent's arguments refused by the key-file rules over <parameter>RULEFIELDS</parameter>
/// (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ##class(OcuPilot.Area.Security.EncryptionRules).Problem(pArgs, $ListFromString(..#RULEFIELDS))
    Quit $$$OK
}

/// <p>The kernel's merge, then <method>StateRefusal</method> over the fresh read and the arguments, so the
/// mint and the confirm's re-merge refuse what the active list rules out; where the arguments carry
/// <parameter>FILEKEYSARGUMENT</parameter>, a card row naming the key file's keys follows.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set pProblem = ..StateRefusal(pFresh, pArgs)
    If pProblem '= "" {
        Set pPayload = ""
        Set pDiff = []
        Quit tSC
    }
    Set tFileKeys = ..Argument(pArgs, ..#FILEKEYSARGUMENT)
    If tFileKeys '= "" Do pDiff.%Push({"field": (..#FILEKEYSARGUMENT), "before": "", "after": (tFileKeys)})
    Quit tSC
}

/// <p>The screen's values as this tool's arguments, refused by <method>StateRefusal</method> exactly as
/// the mint refuses them (AD-56 (ii)). The rules are the port's at the write, so a refusal is drawn on
/// its field.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tArguments = $ListFromString(..#ARGUMENTS)
    For tI = 1:1:$ListLength(tArguments) {
        Set tName = $List(tArguments, tI)
        If $IsObject(pValues) && (pValues.%GetTypeOf(tName) = "string") Do pArgs.%Set(tName, pValues.%Get(tName), "string")
    }
    Set pProblem = ..StateRefusal(pFresh, pArgs)
    Quit $$$OK
}

/// <p>Why the active list, as the fresh read <var>pFresh</var> answers it, rules out this action with
/// <var>pArgs</var>, or <code>""</code>. <code>""</code> here.</p>
ClassMethod StateRefusal(pFresh As %DynamicObject, pArgs As %DynamicObject) As %String
{
    Quit ""
}

/// <p>The card's secret rows (AD-6, AD-56 (i)): one <code>{field, before: "", after: ""}</code> row per
/// <parameter>SECRETBODY</parameter> name, so the card masks it and asks for it at the confirm; neither
/// side carries a value. A tool that sends no secret answers none.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tNames = ..SecretBodyNames()
    For tI = 1:1:$ListLength(tNames) {
        Do pRows.%Push({"field": ($List(tNames, tI)), "before": "", "after": ""})
    }
    Quit $$$OK
}

/// <p>The stored payload's arguments under the port's own query keys, and the constant
/// <parameter>ACTION</parameter>, so the confirm's write and the screen's carry what the user reviewed
/// (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Set pQuery(##class(OcuPilot.Port.EncryptionPort).#ACTIONPARAM) = ..#ACTION
    If '$IsObject(pPayload) Quit
    Set tArguments = $ListFromString(..#ARGUMENTS)
    For tI = 1:1:$ListLength(tArguments) {
        Set tName = $List(tArguments, tI)
        Set tType = pPayload.%GetTypeOf(tName)
        If (tType = "string") || (tType = "number") Set pQuery(tName) = pPayload.%Get(tName) _ ""
    }
}

/// <p>The active key row of <var>pFresh</var> whose <code>Id</code> is <var>pId</var>, compared exactly,
/// or <code>""</code>.</p>
ClassMethod KeyRow(pFresh As %DynamicObject, pId As %String) As %DynamicObject
{
    Set tFound = ""
    If (pId = "") || '$IsObject(pFresh) || (pFresh.%GetTypeOf(##class(OcuPilot.Port.EncryptionPort).#KEYS) '= "array") Quit tFound
    Set tIterator = pFresh.%Get(##class(OcuPilot.Port.EncryptionPort).#KEYS).%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && (tRow.%Get("Id") = pId) Set tFound = tRow Quit
    }
    Quit tFound
}

/// <p>How many keys <var>pFresh</var> lists as active.</p>
ClassMethod ActiveCount(pFresh As %DynamicObject) As %Integer
{
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(##class(OcuPilot.Port.EncryptionPort).#KEYS) '= "array") Quit 0
    Quit pFresh.%Get(##class(OcuPilot.Port.EncryptionPort).#KEYS).%Size()
}

/// <p><var>pArgs</var>'s scalar <var>pName</var> as text, or <code>""</code>.</p>
ClassMethod Argument(pArgs As %DynamicObject, pName As %String) As %String
{
    Quit ##class(OcuPilot.Area.Security.EncryptionRules).Value(pArgs, pName)
}

/// <p><parameter>CONSEQUENCE</parameter>, whatever the payload.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

}
