/// <p>Data element encryption's Activate key (AD-21's sixth case, AD-51, AD-53, AD-56 (i), Story 18.22):
/// propose activating every key in a key file as a data-element encryption key, opened with an
/// administrator's name and password. Two callers reach it: the screen's Activate key dialog and the
/// agent's proposal and confirmation, where the person supplies the password.</p>
/// <p>The key file is a <code>source</code> resolved through <class>OcuPilot.Port.PathPort</class> at the
/// mint and again at the write; a missing or unreadable file and a file whose every key is already active
/// are refused before anything is sent (<class>OcuPilot.Screen.Tool.EncryptionKeyActivateMint</class>), and
/// a wrong password is the vendor's answer, 422
/// <code>ENCRYPTION.KEYFILE.CREDENTIALS</code>.</p>
Class OcuPilot.Screen.Tool.DataElementKeyActivate Extends OcuPilot.Screen.Tool.EncryptionKeyWrite
{

Parameter TOOLNAME = "security.dataelementencryption.activate";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DataElementEncryption";

Parameter DESCRIPTION = "Propose activating the keys in an encryption key file as data element encryption keys, which applications use to encrypt individual values. Name the file by `root` and `path` as the Encryption key files screen opens it, and an administrator the file lists as `AdminName`. The person types the administrator's password when confirming.";

Parameter ENDPOINT = "Security.Encryption.File";

Parameter READTYPE = "DATAELEMENTKEYS";

Parameter WRITETYPE = "ACTIVATE";

Parameter ACTION = "ActivateMK";

Parameter SECRETBODY = "AdminPassword";

Parameter SCREENACTIONS = "activate";

Parameter SCREENVALUES = "activate=root:path:AdminName:AdminPassword";

Parameter ARGUMENTS = "root,path,AdminName";

Parameter REQUIREDARGUMENTS = "root,path,AdminName";

Parameter RULEFIELDS = "AdminName";

Parameter FINGERPRINTSUBJECT = "Keys,root,path,AdminName";

/// <p>The pair <class>OcuPilot.Port.PathPort</class>'s resolve requires (AD-21, AD-8; measured at Task
/// 0).</p>
Parameter EXTRAPAIRS = "%Admin_FileSystemAccess:USE";

Parameter CONSEQUENCE = "ENCRYPTION.KEY.ACTIVATEDATAELEMENT";

/// <p><class>OcuPilot.Screen.Tool.EncryptionKeyActivateMint</class>, which checks the key file first.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.EncryptionKeyActivateMint"
}

}
