/// <p>Encryption key files' Add administrator (AD-51, AD-53, AD-56 (i), Story 18.7): propose adding an
/// administrator to a key file, opened with an existing administrator's name and password. Two callers
/// reach it: the Administrators table's dialog and the agent's proposal and confirmation, where the
/// person supplies both passwords.</p>
/// <p>A new name the file already lists, compared without regard to case as the vendor compares it, is
/// refused with <parameter>REASONADMINTAKEN</parameter> before anything is
/// sent; a wrong password is the vendor's answer, 422
/// <parameter>OcuPilot.Api.EncryptionError.KEYFILECREDENTIALS</parameter>. Its fingerprint covers the
/// administrator list and the two names.</p>
Class OcuPilot.Screen.Tool.EncryptionKeyFileAddAdmin Extends OcuPilot.Screen.Tool.EncryptionKeyFileWrite
{

Parameter TOOLNAME = "security.encryptionkeyfileadmins.addadministrator";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EncryptionKeyFileAdminList";

Parameter DESCRIPTION = "Propose adding an administrator to an encryption key file. Name the file by `root` and `path` as the Encryption key files screen opens it, an administrator the file already lists as `OldAdminName`, and the new administrator as `NewAdminName`, not already listed. The person types the existing administrator's password and the new password when confirming. Adding an emergency recovery administrator is the classic page's recommendation for every new key file.";

Parameter ENDPOINT = "Security.Encryption.AdminInFile";

Parameter WRITETYPE = "POST";

Parameter SECRETBODY = "OldAdminPassword,NewAdminPassword";

Parameter SCREENACTIONS = "addadministrator";

Parameter SCREENVALUES = "addadministrator=OldAdminName:NewAdminName:OldAdminPassword:NewAdminPassword";

Parameter ARGUMENTS = "OldAdminName,NewAdminName";

Parameter REQUIREDARGUMENTS = "OldAdminName,NewAdminName";

Parameter RULEFIELDS = "OldAdminName,NewAdminName";

Parameter PRECONDITIONFIELD = "Administrators";

Parameter FINGERPRINTSUBJECT = "Administrators,OldAdminName,NewAdminName";

/// <p>The classic dialog whose add this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.EncAddAdmin";

/// <p>The state refusal, published once in EXPERIENCE.md and pinned equal to
/// <code>OcuPilot.Api.EncryptionError.REASONADMINTAKEN</code>.</p>
Parameter REASONADMINTAKEN = "This key file already has an administrator of that name.";

/// <p>A new name the fresh read already lists.</p>
ClassMethod StateRefusal(pFresh As %DynamicObject, pArgs As %DynamicObject) As %String
{
    If ..Holds(pFresh, ##class(OcuPilot.Port.EncryptionPort).#ADMINISTRATORS, ..Argument(pArgs, "NewAdminName")) Quit ..#REASONADMINTAKEN
    Quit ""
}

}
