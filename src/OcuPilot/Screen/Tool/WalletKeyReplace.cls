/// <p>The base of the two wallet key replace tools (AD-51, AD-52, AD-56 (i), Story 18.24). Each replaces
/// the key material of one existing RSA or symmetric secret, whose type the vendor never changes
/// (measured), and is <b>destructive</b>: the old key cannot be restored. The consequence names what
/// is lost.</p>
/// <p><b>Action-style with a port-built body.</b> The tool sends no merge body: the declared length
/// travels in the port query (<method>PortQuery</method>) and the secret members as the secret-only
/// body, and <class>OcuPilot.Port.WalletPort</class> builds the vendor's body from both. The fresh read is
/// the secret's metadata; the merge carries the arguments into the stored payload the port query reads,
/// so the fingerprint covers the metadata the reviewer saw and the length asked for (AD-51).</p>
/// <p>A fresh read of another type refuses <code>WALLETKEY.TYPE.MISMATCH</code> at the mint, and at the
/// confirm as a moved target, before any <code>PUT</code>.</p>
/// <p>A concrete tool declares <parameter>TOOLNAME</parameter>, <parameter>DESCRIPTION</parameter>,
/// <parameter>SECRETTYPE</parameter>, <parameter>CONSEQUENCE</parameter>,
/// <parameter>FINGERPRINTSUBJECT</parameter> and <parameter>READANSWERS</parameter>, and a tool that is
/// sent a key as its body also <parameter>SECRETBODY</parameter>.</p>
Class OcuPilot.Screen.Tool.WalletKeyReplace Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WalletSecretList";

Parameter PORTCLASS = "OcuPilot.Port.WalletPort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

/// <p>No merge body: the port builds the vendor's (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>Declared: a replaced key cannot be restored.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The type this tool replaces, the code of its consequence, and the argument it takes.</p>
Parameter SECRETTYPE;

Parameter CONSEQUENCE;

Parameter ARGUMENTS;

Parameter PRECONDITIONFIELD = "Type";

Parameter TYPEFIELD = "Type";

Parameter WRITERESOURCE = "%Admin_Wallet";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Wallet.Secret"
}

/// <p><parameter>ARGUMENTS</parameter>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#ARGUMENTS)
}

/// <p>The kernel's merge refused by type, then <method>Arguments</method>: the payload is the fresh
/// read, which the fingerprint covers, with the arguments added.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ""
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%Get(..#TYPEFIELD) '= ..#SECRETTYPE) {
            Set pProblem = "'" _ ..#TYPEFIELD _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation("WALLETKEY.TYPE.MISMATCH")
            Quit
        }
        Set pPayload = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON())
        Do ..Arguments(pFresh, pArgs, pPayload, pDiff, .pProblem)
        If pProblem '= "" {
            Set pPayload = ""
            Set pDiff = []
        }
    } Catch ex {
        Set pPayload = ""
        Set pDiff = []
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Add the arguments to <var>pPayload</var> and the rows they move to <var>pDiff</var>. Nothing here
/// by default.</p>
ClassMethod Arguments(pFresh As %DynamicObject, pArgs As %DynamicObject, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pProblem As %String)
{
    Set pProblem = ""
}

/// <p>The card's secret rows: one masked <code>{field, before, after}</code> per
/// <parameter>SECRETBODY</parameter> name a concrete tool asks the card for.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The stored payload's type and length argument under the port's own query keys, so the confirm's
/// write and the screen's carry what the user reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#TYPEFIELD) = "string" Set pQuery(..#TYPEFIELD) = pPayload.%Get(..#TYPEFIELD)
    If pPayload.%GetTypeOf("NewLength") = "number" Set pQuery("Length") = pPayload.%Get("NewLength")
}

/// <p><parameter>CONSEQUENCE</parameter>, whatever the payload.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

/// <p>The schema: the identifying property and, where a tool takes one, its argument.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf("Name") = "object" {
        Do tProperties.%Get("Name").%Set("description", "The secret whose key to replace, exactly as the collection's Secrets list reports its name, case included. It must hold a key of this tool's type, and the type never changes.", "string")
    }
    Do ..DescribeArguments(tSchema)
    Quit tSchema
}

/// <p>Add the tool's arguments to <var>pSchema</var>. Nothing here by default.</p>
ClassMethod DescribeArguments(pSchema As %DynamicObject)
{
}

/// <p>The agent's arguments refused by the key rules in their <code>generate</code> mode, where this
/// tool takes a length. Nothing here by default.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Quit $$$OK
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
