/// <p>Task Manager email's mail password tool (AD-35, AD-51, AD-56 (i), AD-58, AD-59, Story 21.36): propose setting or clearing the password the Task Manager signs in to the
/// mail server with. It reads the sign-in name's row through <class>OcuPilot.Port.ConfigPort</class> and mints a proposal whose card asks for the password at confirm. It writes nothing.</p>
/// <p><b>Its body is its declared secret and nothing else</b> (<parameter>SECRETBODY</parameter>): the kernel carries the password as the descriptor's one declaration and supplies it at
/// the write (<method>OcuPilot.Kernel.Proposal.Operation.SecretBody</method>); the model can never supply it, because the tool admits no settable field and the mint refuses a declared
/// secret outright. An empty password clears the setting (<parameter>CLEARABLESECRETS</parameter>).</p>
/// <p><b>Its fingerprint covers <code>Value</code></b>, the sign-in name the password belongs with; the password is never part of it, and no read answers whether one is stored. Its read-back
/// reports the password written and never reads it. Its pairs are exactly <class>OcuPilot.Screen.Tool.TaskMailSettingSet</class>'s.</p>
Class OcuPilot.Screen.Tool.TaskMailPassword Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "tasks.mail.password";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.TaskMailSettingList";

Parameter DESCRIPTION = "Propose setting a new mail password for the Task Manager, the password it signs in to the mail server with. It changes nothing by itself: it answers a proposal the user reviews, and the user types the password on the card when confirming. Never send a password: send the literal 'AuthUser' as the name and nothing else. Leaving the password empty at confirmation clears it.";

Parameter PORTCLASS = "OcuPilot.Port.ConfigPort";

Parameter WRITETYPE = "PASSWORD";

/// <p>No merge body: the write sends <parameter>SECRETBODY</parameter> alone (AD-56 (i)).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter SECRETBODY = "AuthPassword";

Parameter CLEARABLESECRETS = "AuthPassword";

/// <p>The card's one row is labelled <code>AuthPassword</code>, which names the secret the card asks for rather than a field the payload carries.</p>
Parameter STATEFIELD = "AuthPassword";

Parameter PRECONDITIONFIELD = "Value";

Parameter FINGERPRINTSUBJECT = "Value";

Parameter CLASSICPAGES = "%cspapp.mgr.utilsystaskmail";

/// <p>The pair the write itself names, the setting set's (<class>OcuPilot.Screen.Tool.ConfigSettingSet</class>).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

Parameter READANSWERS = "Name,Value,Kind,Accepts,Restart,ReadOnly";

Parameter SCREENACTIONS = "password";

Parameter SCREENVALUES = "password=AuthPassword";

/// <p>The dialog may send the password empty, which clears it (<parameter>CLEARABLESECRETS</parameter>, AD-56).</p>
Parameter SCREENEMPTY = "password=AuthPassword";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.ConfigPort).#TASKMAILENDPOINT
}

/// <p>None: the write sends no merge body.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the target described: the sign-in name, a literal.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The setting is the sign-in name the password belongs with, so send the literal '" _ ##class(OcuPilot.Port.ConfigPort).#PASSWORDTARGET _ "'. The password is typed by the user at confirmation and is never an argument.", "string")
    Quit tSchema
}

/// <p>What the caller must hold: <class>OcuPilot.Screen.Tool.TaskMailSettingSet</class>'s pairs, which are the screen's own, <code>%DB_IRISSYS:WRITE</code> and the custom
/// resource of the classic page (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Tool.TaskMailSettingSet).PrivilegePairs(pDescriptor, .pResolved)
}

/// <p>The card's one row, from the fresh read <var>pFresh</var>: <code>{field: "AuthPassword", before: "", after: ""}</code>. It names the declared secret, so the card masks it and asks for it;
/// neither side carries a value, because no read returns one and the new one is supplied at confirm. A read that answered no <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
            Set pProblem = "this instance did not report the Task Manager's mail sign-in name, so no mail password is set for it"
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
