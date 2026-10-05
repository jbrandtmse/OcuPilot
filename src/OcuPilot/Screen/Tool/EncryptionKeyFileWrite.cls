/// <p>The base of the five encryption key file tools (AD-21's sixth case, AD-51, AD-52, AD-56 (i), Story
/// 18.7). Each targets one key file, entity type <code>encryption-key-file</code>, scope
/// <code>instance</code>, whose id is the composite of the allowed directory <code>root</code> and the
/// relative name <code>path</code> (AD-13); <class>OcuPilot.Screen.Tool.EncryptionKeyFileMint</class>
/// builds it from the agent's two arguments, and a screen action sends it as its row's id.</p>
/// <p><b>Action-style with a port-built body.</b> No body is sent from the payload: the tool's declared
/// non-secret arguments travel in the port query (<method>PortQuery</method>) and its declared secrets
/// as the secret-only body, and <class>OcuPilot.Port.EncryptionPort</class> builds the vendor's body
/// from both and the resolved key file. The fresh read is the port-composed <code>KEYFILE</code>: the
/// file's administrators and keys, beside each argument empty, so the merge carries the arguments into
/// the stored payload the port query reads; the fingerprint covers the list the action changes and the
/// arguments (AD-51).</p>
/// <p><b>Its pairs</b> are the screen's three, then <parameter>EXTRAPAIRS</parameter>, then the custom
/// resource of each <parameter>CLASSICPAGES</parameter> page, refused by name before any port call (AD-8,
/// AD-44). The vendor records <code>%System/%Security/DBEncChange</code> for every key file write (AD-15,
/// measured).</p>
/// <p>A concrete tool declares <parameter>TOOLNAME</parameter>, <parameter>DESCRIPTORCLASS</parameter>,
/// <parameter>DESCRIPTION</parameter>, <parameter>ENDPOINT</parameter>, <parameter>WRITETYPE</parameter>,
/// <parameter>ARGUMENTS</parameter>, <parameter>REQUIREDARGUMENTS</parameter> and
/// <parameter>RULEFIELDS</parameter>, and answers <method>StateRefusal</method> where the list's state
/// refuses the action.</p>
Class OcuPilot.Screen.Tool.EncryptionKeyFileWrite Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

/// <p>The port that resolves the key file and builds every body (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.EncryptionPort";

/// <p>The fresh read: the port-composed key file.</p>
Parameter READTYPE = "KEYFILE";

/// <p>No merge body: the port builds the vendor's (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>What the <code>KEYFILE</code> read answers.</p>
Parameter READANSWERS = "Administrators,Keys,AdminName,KeyLen,Description,OldAdminName,NewAdminName,Admin,KeyId";

/// <p>The vendor endpoint this tool's write goes to, declared by the subclass.</p>
Parameter ENDPOINT;

/// <p>The tool's declared non-secret arguments, comma-separated, each a key the port query carries.</p>
Parameter ARGUMENTS;

/// <p>The arguments the schema requires, beside <code>root</code> and <code>path</code>.</p>
Parameter REQUIREDARGUMENTS;

/// <p>The arguments <class>OcuPilot.Area.Security.EncryptionRules</class> judges at the mint.</p>
Parameter RULEFIELDS;

/// <p>The pairs beyond the screen's three, as comma-separated <code>resource:permission</code>.</p>
Parameter EXTRAPAIRS;

/// <p>The argument naming the allowed directory; <code>path</code> is <method>IdArgument</method>.</p>
Parameter ROOTARGUMENT = "root";

ClassMethod Endpoint() As %String
{
    Quit ..#ENDPOINT
}

/// <p>The relative name: the composite target's second part, which the mint joins to
/// <parameter>ROOTARGUMENT</parameter>.</p>
ClassMethod IdArgument() As %String
{
    Quit "path"
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.EncryptionPort).#KEYFILEPARAM
}

/// <p><parameter>ARGUMENTS</parameter>: the tool sends no body, and these reach the port through
/// <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#ARGUMENTS)
}

/// <p><class>OcuPilot.Screen.Tool.EncryptionKeyFileMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.EncryptionKeyFileMint"
}

/// <p>The schema: <code>root</code> and <code>path</code>, each required, then each argument with its
/// shape and limit in prose, the required ones required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#ROOTARGUMENT, {"type": "string", "description": "The allowed directory the key file is in, exactly as this instance's Allowed directories screen lists it. Any other value is refused."})
    Do tProperties.%Set(..IdArgument(), {"type": "string", "description": "The key file's name relative to root: up to eight names separated by '/', each starting with a letter or digit and holding only letters, digits, dots, underscores and dashes. Never a full path."})
    Do tSchema.%Get("required").%Push(..#ROOTARGUMENT)
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
    If pName = "KeyLen" Quit {"type": "integer", "description": "The key's length in bits: 128, 192 or 256."}
    If pName = "Description" Quit {"type": "string", "description": "A description stored with the key, free text."}
    If pName = "AdminName" Quit {"type": "string", "description": "The key file administrator's name, up to 50 characters, as the key file lists it."}
    If pName = "OldAdminName" Quit {"type": "string", "description": "An administrator the key file already lists, up to 50 characters; the person supplies its password at confirmation."}
    If pName = "NewAdminName" Quit {"type": "string", "description": "The new administrator's name, up to 50 characters, not already listed; the person supplies its password at confirmation."}
    If pName = "Admin" Quit {"type": "string", "description": "The administrator to remove, exactly as this key file's administrator list reports it."}
    If pName = "KeyId" Quit {"type": "string", "description": "The key identifier to remove, exactly as this key file's key list reports it."}
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

/// <p>The kernel's merge, then <method>StateRefusal</method> over the fresh read and the arguments, so
/// the mint and the confirm's re-merge refuse what the list's state rules out.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set pProblem = ..StateRefusal(pFresh, pArgs)
    If pProblem '= "" {
        Set pPayload = ""
        Set pDiff = []
    }
    Quit tSC
}

/// <p>The screen's values as this tool's arguments, refused by the rules and by
/// <method>StateRefusal</method> exactly as the mint refuses them (AD-56 (ii)).</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tArguments = $ListFromString(..#ARGUMENTS)
    For tI = 1:1:$ListLength(tArguments) {
        Set tName = $List(tArguments, tI)
        If $IsObject(pValues) && (pValues.%GetTypeOf(tName) = "string") Do pArgs.%Set(tName, pValues.%Get(tName), "string")
    }
    Set pProblem = ##class(OcuPilot.Area.Security.EncryptionRules).Problem(pArgs, $ListFromString(..#RULEFIELDS))
    If pProblem = "" Set pProblem = ..StateRefusal(pFresh, pArgs)
    Quit $$$OK
}

/// <p>Why the key file's state, as the fresh read <var>pFresh</var> answers it, rules out this action
/// with <var>pArgs</var>, or <code>""</code>. <code>""</code> here.</p>
ClassMethod StateRefusal(pFresh As %DynamicObject, pArgs As %DynamicObject) As %String
{
    Quit ""
}

/// <p>The card's secret rows (AD-6, AD-56 (i)): one <code>{field, before: "", after: ""}</code> row per
/// <parameter>SECRETBODY</parameter> name, so the card masks each and asks for it at the confirm; neither
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

/// <p>The stored payload's arguments under the port's own query keys, so the confirm's write and the
/// screen's carry what the user reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    Set tArguments = $ListFromString(..#ARGUMENTS)
    For tI = 1:1:$ListLength(tArguments) {
        Set tName = $List(tArguments, tI)
        Set tType = pPayload.%GetTypeOf(tName)
        If (tType = "string") || (tType = "number") Set pQuery(tName) = pPayload.%Get(tName) _ ""
    }
}

/// <p>Whether <var>pFresh</var>'s list <var>pMember</var> holds <var>pValue</var>: an administrator's
/// name compared without regard to case, as the vendor compares it, or a key's <code>Id</code>
/// exactly.</p>
ClassMethod Holds(pFresh As %DynamicObject, pMember As %String, pValue As %String) As %Boolean
{
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(pMember) '= "array") Quit 0
    Set tFound = 0
    Set tIterator = pFresh.%Get(pMember).%GetIterator()
    While tIterator.%GetNext(.tIndex, .tItem) {
        If $IsObject(tItem) {
            If tItem.%Get("Id") = pValue Set tFound = 1 Quit
        } ElseIf $ZConvert(tItem, "U") = $ZConvert(pValue, "U") {
            Set tFound = 1
            Quit
        }
    }
    Quit tFound
}

/// <p><var>pArgs</var>'s scalar <var>pName</var> as text, or <code>""</code>.</p>
ClassMethod Argument(pArgs As %DynamicObject, pName As %String) As %String
{
    Quit ##class(OcuPilot.Area.Security.EncryptionRules).Value(pArgs, pName)
}

}
