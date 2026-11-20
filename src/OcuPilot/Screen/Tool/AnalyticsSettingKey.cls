/// <p>Analytics' Google Maps key tool (AD-51, AD-56 (i), AD-58, AD-65, Story 24.13): propose setting or clearing the key the classic Settings page's General tab keeps for the map widgets of dashboards.
/// It reads the setting's row through <class>OcuPilot.Port.AnalyticsPort</class> and mints a proposal whose card asks for the key at confirm. It writes nothing.</p>
/// <p><b>Its body is its declared secret and nothing else</b> (<parameter>SECRETBODY</parameter>): the kernel carries the key as the descriptor's one declaration and supplies it at the write
/// (<method>OcuPilot.Kernel.Proposal.Operation.SecretBody</method>); the model can never supply it, because the tool admits no settable field and the mint refuses a declared secret outright. The port saves
/// the General form with the key in it, every other setting as its row shows it (the same composition as <class>OcuPilot.Screen.Tool.AnalyticsSettingSet</class>). An empty key clears the setting
/// (<parameter>CLEARABLESECRETS</parameter>).</p>
/// <p><b>Its fingerprint covers <code>Stored</code></b>, whether a key is stored; the key is never part of it, and no read answers one: the row's <code>Value</code> is the credential mask. Its read-back
/// reports the key written and never reads it (AD-58).</p>
Class OcuPilot.Screen.Tool.AnalyticsSettingKey Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "analytics.settings.setkey";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsSettingList";

Parameter DESCRIPTION = "Propose setting a new Google Maps key for the namespace the user is working in, the key the map widgets of dashboards use. It changes nothing by itself: it answers a proposal the user reviews, and the user types the key on the card when confirming. Never send a key: send the literal 'GoogleMapsKey' as the name and nothing else. Leaving the key empty at confirmation clears it.";

Parameter PORTCLASS = "OcuPilot.Port.AnalyticsPort";

Parameter READTYPE = "SETTING";

Parameter WRITETYPE = "SETTINGKEY";

/// <p>No merge body: the write sends <parameter>SECRETBODY</parameter> alone (AD-56 (i)).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The fresh read is composed from the action it is read for (<method>PortQuery</method>), at the mint as at a screen action.</p>
Parameter READSVALUES As BOOLEAN = 1;

Parameter SECRETBODY = "GoogleMapsKey";

Parameter CLEARABLESECRETS = "GoogleMapsKey";

/// <p>The card's one row is labelled <code>GoogleMapsKey</code>, which names the secret the card asks for rather than a field the payload carries.</p>
Parameter STATEFIELD = "GoogleMapsKey";

Parameter PRECONDITIONFIELD = "Stored";

Parameter FINGERPRINTSUBJECT = "Stored,Namespace";

Parameter CLASSICPAGES = "%DeepSee.UI.Settings";

Parameter READANSWERS = "Name,Value,Stored,Kind,Accepts,Namespace";

Parameter SCREENACTIONS = "setkey";

Parameter SCREENVALUES = "setkey=GoogleMapsKey";

/// <p>The dialog may send the key empty, which clears it (<parameter>CLEARABLESECRETS</parameter>, AD-56).</p>
Parameter SCREENEMPTY = "setkey=GoogleMapsKey";

/// <p>The consequence code of a save that stores every General row, as <class>OcuPilot.Screen.Tool.AnalyticsSettingSet</class>'s.</p>
Parameter CONSEQUENCECODE = "ANALYTICS.SETTING.SAVE";

Parameter PRECONDITIONCODES = "CONFIG.SETTING.NOTFOUND,ANALYTICS.SETTING.READONLY,ANALYTICS.NAMESPACE";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTSETTINGS
}

/// <p>The query parameter the port reads the setting's name under.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#IDKEY
}

/// <p>None: the write sends no merge body.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the target described: the one setting that is a key.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The setting is the Google Maps key, so send the literal '" _ ##class(OcuPilot.Port.AnalyticsPort).#SETTINGSECRETNAME _ "'. The key is typed by the user at confirmation and is never an argument.", "string")
    Quit tSchema
}

/// <p>The action key (composing the read for this write) and the namespace a stored payload names.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##class(OcuPilot.Port.AnalyticsPort).ActionQuery(pPayload, ..#PRECONDITIONFIELD, ..#WRITETYPE, .pQuery)
}

/// <p>What the caller must hold: the screen's own pairs, WRITE on the database the settings global maps to, READ on the routines database and the custom
/// resource of the classic Settings page (AD-8, AD-44, AD-65).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).WritePairs(..#DESCRIPTORCLASS, ##class(OcuPilot.Port.AnalyticsPort).#SETTINGSGLOBAL, ..#CLASSICPAGES, .pResolved)
}

/// <p><parameter>CONSEQUENCECODE</parameter> when the namespace the payload names holds a General row that is not stored, which this write stores, else <code>""</code>.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If '$IsObject(pPayload) Quit ""
    Quit $Select(##class(OcuPilot.Port.AnalyticsPort).UnstoredGeneral($Select(pPayload.%GetTypeOf("Namespace") = "string": pPayload.%Get("Namespace"), 1: "")): ..#CONSEQUENCECODE, 1: "")
}

/// <p>The card's one row, from the fresh read <var>pFresh</var>: <code>{field: "GoogleMapsKey", before: "", after: ""}</code>. It names the declared secret, so the card masks it and asks for it; neither
/// side carries a value, because no read returns one and the new one is supplied at confirm. A read that answered no <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "boolean") {
            Set pProblem = "this instance did not report whether a Google Maps key is stored, so no key is set for it"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", "", "string")
        Do tRow.%Set("after", "", "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
