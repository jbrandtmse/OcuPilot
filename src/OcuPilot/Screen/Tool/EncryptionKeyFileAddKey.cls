/// <p>Encryption key files' Add key (AD-51, AD-53, AD-56 (i), Story 18.7): propose adding one new key
/// of the chosen length to a key file, opened with an administrator's name and password. Two callers
/// reach it: the keys table's dialog and the agent's proposal and confirmation, where the person
/// supplies the password.</p>
/// <p>A wrong password is the vendor's answer, 422
/// <parameter>OcuPilot.Api.EncryptionError.KEYFILECREDENTIALS</parameter>. The vendor generates the
/// key; its card states the backup consequence. Its fingerprint covers the key list and the
/// arguments.</p>
Class OcuPilot.Screen.Tool.EncryptionKeyFileAddKey Extends OcuPilot.Screen.Tool.EncryptionKeyFileWrite
{

Parameter TOOLNAME = "security.encryptionkeyfile.addkey";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EncryptionKeyFile";

Parameter DESCRIPTION = "Propose adding one new encryption key to a key file. Name the file by `root` and `path` as the Encryption key files screen opens it, an administrator the file lists as `AdminName`, the key length as `KeyLen` (128, 192 or 256) and a `Description`. The person types the administrator's password when confirming. The key is new and unique: say in the rationale that the key file must be backed up again. Adding a key activates nothing.";

Parameter ENDPOINT = "Security.Encryption.KeyInFile";

Parameter WRITETYPE = "POST";

Parameter SECRETBODY = "AdminPassword";

Parameter SCREENACTIONS = "addkey";

Parameter SCREENVALUES = "addkey=AdminName:KeyLen:Description:AdminPassword";

Parameter ARGUMENTS = "AdminName,KeyLen,Description";

Parameter REQUIREDARGUMENTS = "AdminName,KeyLen";

Parameter RULEFIELDS = "AdminName,KeyLen";

Parameter PRECONDITIONFIELD = "Keys";

Parameter FINGERPRINTSUBJECT = "Keys,AdminName,KeyLen,Description";

/// <p>The classic dialog whose add this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.EncAddAdmin";

Parameter CONSEQUENCE = "ENCRYPTION.KEYFILE.NEWKEY";

/// <p><parameter>CONSEQUENCE</parameter>, whatever the payload.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

}
