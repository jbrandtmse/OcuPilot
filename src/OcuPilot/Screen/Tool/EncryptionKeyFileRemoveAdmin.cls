/// <p>Encryption key files' Remove administrator (AD-51, AD-53, Story 18.7): propose removing an
/// administrator from a key file, so its name and password no longer open the file. Two callers reach
/// it: the Administrators table's typed-name dialog and the agent's proposal and confirmation. No
/// password is asked, as the vendor and the classic page ask none; the screen's pairs are the check.</p>
/// <p>A name the file does not list, and the file's last administrator, are refused before anything is
/// sent, with <parameter>REASONADMINABSENT</parameter> and
/// <parameter>REASONADMINLAST</parameter>. It is destructive; its
/// read-back is the name gone from the list.</p>
Class OcuPilot.Screen.Tool.EncryptionKeyFileRemoveAdmin Extends OcuPilot.Screen.Tool.EncryptionKeyFileWrite
{

Parameter TOOLNAME = "security.encryptionkeyfileadmins.removeadministrator";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EncryptionKeyFileAdminList";

Parameter DESCRIPTION = "Propose removing one administrator from an encryption key file, so that name and password no longer open the file. Name the file by `root` and `path` as the Encryption key files screen opens it, and the administrator as `Admin`, exactly as the file's administrator list reports it. A key file keeps at least one administrator, so its last one is refused.";

Parameter ENDPOINT = "Security.Encryption.AdminInFile";

Parameter WRITETYPE = "DELETE";

Parameter SCREENACTIONS = "removeadministrator";

Parameter SCREENVALUES = "removeadministrator=Admin";

Parameter ARGUMENTS = "Admin";

Parameter REQUIREDARGUMENTS = "Admin";

Parameter RULEFIELDS;

Parameter PRECONDITIONFIELD = "Administrators";

Parameter FINGERPRINTSUBJECT = "Administrators,Admin";

Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

/// <p>The rows the card lists.</p>
Parameter REMOVALROWS = "Admin";

/// <p>The state refusal, published once in EXPERIENCE.md and pinned equal to
/// <code>OcuPilot.Api.EncryptionError.REASONADMINABSENT</code>.</p>
Parameter REASONADMINABSENT = "This administrator is not in this key file.";

/// <p>The state refusal, published once in EXPERIENCE.md and pinned equal to
/// <code>OcuPilot.Api.EncryptionError.REASONADMINLAST</code>.</p>
Parameter REASONADMINLAST = "A key file keeps at least one administrator.";

/// <p>A name the fresh read does not list, and the file's last administrator.</p>
ClassMethod StateRefusal(pFresh As %DynamicObject, pArgs As %DynamicObject) As %String
{
    Set tMember = ##class(OcuPilot.Port.EncryptionPort).#ADMINISTRATORS
    If '..Holds(pFresh, tMember, ..Argument(pArgs, "Admin")) Quit ..#REASONADMINABSENT
    If pFresh.%Get(tMember).%Size() <= 1 Quit ..#REASONADMINLAST
    Quit ""
}

/// <p>The kernel's merge with the removal row the card lists: the administrator, as it was, removed.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set pDiff = [{"field": (..#REMOVALROWS), "before": (..Argument(pArgs, ..#REMOVALROWS)), "after": "", "removed": true}]
    Quit tSC
}

/// <p>Gone once the re-read's administrator list no longer holds the name the payload removed (AD-58).</p>
ClassMethod ReadBackGone(pAfter As %DynamicObject, pPayload As %DynamicObject) As %Boolean
{
    If '$IsObject(pAfter) || '$IsObject(pPayload) Quit 0
    Quit '..Holds(pAfter, ##class(OcuPilot.Port.EncryptionPort).#ADMINISTRATORS, ..Argument(pPayload, ..#REMOVALROWS))
}

}
