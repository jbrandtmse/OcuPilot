/// <p>Encryption key files' create (AD-54, AD-55, AD-56 (i), Story 18.7): propose a new key file at an
/// allowed directory and a relative name, with its first administrator and one key of the chosen
/// length. Two callers reach it: the create form's Save through
/// <class>OcuPilot.Area.Security.EncryptionKeyFileSave</class>, and the agent's proposal and
/// confirmation, where the person supplies the administrator's password.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no key file at the name, and a name taken since
/// the mint reads present at the confirm's re-read and closes the proposal target-changed; the write's
/// own resolution refuses it <code>PATH.EXISTS</code> too. The port refuses a folder that does not exist,
/// because the vendor would create it. Its body is built by the port from the arguments and the
/// password (AD-51, AD-56 (i)).</p>
/// <p>The vendor generates the key; nothing here or in its answer carries key material. It is not
/// destructive, and its card states the backup consequence.</p>
Class OcuPilot.Screen.Tool.EncryptionKeyFileCreate Extends OcuPilot.Screen.Tool.EncryptionKeyFileWrite
{

Parameter TOOLNAME = "security.encryptionkeyfile.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EncryptionKeyFile";

Parameter DESCRIPTION = "Propose creating a new encryption key file holding one new key, with its first administrator. Name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a new file name under it whose folder already exists; an existing file is refused. The person types the administrator's password when confirming. The key is new and unique: say in the rationale that the person must back up the key file, because data encrypted with a key whose every key file is lost cannot be recovered. Creating a key file activates nothing.";

Parameter ENDPOINT = "Security.Encryption.File";

Parameter WRITETYPE = "POST";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter SECRETBODY = "AdminPassword";

Parameter ARGUMENTS = "AdminName,KeyLen,Description";

Parameter REQUIREDARGUMENTS = "AdminName,KeyLen";

Parameter RULEFIELDS = "AdminName,KeyLen";

/// <p>What the registry's adequacy rule holds every action-style write to (AD-51); a create's digest is
/// its target's absence (AD-54), so nothing reads it.</p>
Parameter PRECONDITIONFIELD = "Keys";

Parameter FINGERPRINTSUBJECT = "Keys";

/// <p>The classic create page whose Save this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.EncryptionCreate";

/// <p>The secret the card asks for beside the arguments: the administrator's password, supplied at the
/// confirm and never stored (AD-6, AD-56 (i)).</p>
Parameter COMPOSEDSECRETS = "AdminPassword";

/// <p>The consequence the card states: the key is new and must be backed up.</p>
Parameter CONSEQUENCE = "ENCRYPTION.KEYFILE.NEWKEY";

/// <p>The kernel's composition, with one <code>Location</code> row first naming the key file the
/// arguments place, so the card says where the file goes.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pDiff) Quit tSC
    Set tRows = []
    Set tLocation = {}
    Do tLocation.%Set("field", "Location", "string")
    Do tLocation.%Set("before", "", "string")
    Do tLocation.%Set("after", ..Argument(pArgs, ..#ROOTARGUMENT) _ ..Argument(pArgs, ..IdArgument()), "string")
    Do tRows.%Push(tLocation)
    Set tIterator = pDiff.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do tRows.%Push(tRow)
    }
    Set pDiff = tRows
    Quit tSC
}

/// <p><parameter>COMPOSEDSECRETS</parameter>, the row the card shows empty.</p>
ClassMethod ComposedSecrets() As %List
{
    Quit $ListFromString(..#COMPOSEDSECRETS)
}

/// <p><parameter>CONSEQUENCE</parameter>, whatever the payload.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

}
