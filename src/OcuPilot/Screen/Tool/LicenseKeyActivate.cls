/// <p>License key's activation (AD-51, AD-53, AD-56 (i), Story 18.6): replace the instance's license
/// key with the key text a person pastes or loads from a local file in the browser. Its body is its
/// declared secret <code>Key</code> and nothing else, and its port,
/// <class>OcuPilot.Port.LicensePort</class>, sends <code>License.Key</code> <code>VALIDATE</code> of the
/// same text first and the vendor's <code>PUT</code> only when that answered valid (AD-52).</p>
/// <p><b>It is unadvertised</b> (<parameter>ADVERTISED</parameter> 0, AD-53's third named case): the
/// key text is key material the model never sees or supplies, so the provider's tool list, the
/// dispatch lookup and the screen context's <code>tools</code> never carry it, and its baseline key
/// ships disabled. The License key screen's <code>activate</code> action is its one caller.</p>
/// <p><b>The text is never stored</b>: it reaches the write as the action's secret value, held in the
/// request's own local, and never a proposal, a diff, a log line or an answer (AD-6, AD-35).</p>
/// <p><b>It is destructive</b>: the new key replaces the active one, which OcuPilot cannot restore. Its
/// fingerprint covers the key's customer, order, expiration and capacity, the state the person reviewed
/// on the screen. Its success path has never run on any instance (Story 18.6's Named limit 1).</p>
Class OcuPilot.Screen.Tool.LicenseKeyActivate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.licensekey.activate";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LicenseKey";

Parameter DESCRIPTION = "Replace this instance's license key. Only a person activates a key, from the License key screen; the agent never sends a key's text.";

/// <p>Reached by the screen's action alone (AD-53).</p>
Parameter ADVERTISED As BOOLEAN = 0;

/// <p>The port that validates the text before the write (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.LicensePort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

/// <p>No merge body: the write sends <parameter>SECRETBODY</parameter> alone (AD-56 (i)).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter SECRETBODY = "Key";

/// <p>The card's one row names the secret the action carries.</p>
Parameter STATEFIELD = "Key";

Parameter SCREENACTIONS = "activate";

Parameter SCREENVALUES = "activate=Key";

/// <p>Declared: an activated key replaces the active one.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>What <parameter>READTYPE</parameter> answers that the subject names.</p>
Parameter READANSWERS = "CustomerName,OrderNumber,ExpirationDate,LicenseCapacity";

Parameter PRECONDITIONFIELD = "CustomerName";

Parameter FINGERPRINTSUBJECT = "CustomerName,OrderNumber,ExpirationDate,LicenseCapacity";

/// <p>The classic dialog whose operation this tool performs beyond the screen's own page (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.LicenseActivate";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.LicensePort).#KEYENDPOINT
}

/// <p>None: the write sends no merge body.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property's description replaced.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The target is this instance's one license key, so send the literal '" _ ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID _ "'.", "string")
    }
    Quit tSchema
}

/// <p>The card's one row, from the fresh read <var>pFresh</var>: <code>{field: "Key", before: "",
/// after: ""}</code>, carrying no value. A read that answered no
/// <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
        Set pProblem = "this instance did not report its license key, and a key that is unknown is not one to replace"
        Quit $$$OK
    }
    Set tRow = {}
    Do tRow.%Set("field", ..#STATEFIELD, "string")
    Do tRow.%Set("before", "", "string")
    Do tRow.%Set("after", "", "string")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

/// <p>What the caller must hold: the screen's own pairs, then the custom resource of the
/// <parameter>CLASSICPAGES</parameter> dialog, each once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
