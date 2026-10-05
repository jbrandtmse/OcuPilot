/// <p>Encryption key files' Remove key (AD-10, AD-51, AD-53, Story 18.7): propose removing one key from
/// a key file. Two callers reach it: the keys table's typed-name dialog, whose typed name is the key's
/// identifier, and the agent's proposal and confirmation. No password is asked, as the vendor and the
/// classic page ask none.</p>
/// <p>A key the file does not list is refused before anything is sent, with
/// <parameter>REASONKEYABSENT</parameter>. A key that encrypts OcuPilot's
/// own database, the install namespace's databases, a protected database or the journal is refused
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTKEY</parameter> by the prohibited set, read at the write; reading that state
/// needs <code>%Admin_Manage:USE</code>, which the tool declares (measured). It is destructive and its
/// card states the loss consequence.</p>
Class OcuPilot.Screen.Tool.EncryptionKeyFileRemoveKey Extends OcuPilot.Screen.Tool.EncryptionKeyFileWrite
{

Parameter TOOLNAME = "security.encryptionkeyfile.removekey";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EncryptionKeyFile";

Parameter DESCRIPTION = "Propose removing one key from an encryption key file. Name the file by `root` and `path` as the Encryption key files screen opens it, and the key as `KeyId`, its identifier exactly as the file's key list reports it. If no other key file holds that key, data encrypted with it becomes permanently inaccessible: say so in the rationale. A key OcuPilot or the instance itself depends on is refused.";

Parameter ENDPOINT = "Security.Encryption.KeyInFile";

Parameter WRITETYPE = "DELETE";

Parameter SCREENACTIONS = "removekey";

Parameter SCREENVALUES = "removekey=KeyId";

Parameter ARGUMENTS = "KeyId";

Parameter REQUIREDARGUMENTS = "KeyId";

Parameter RULEFIELDS;

Parameter PRECONDITIONFIELD = "Keys";

Parameter FINGERPRINTSUBJECT = "Keys,KeyId";

Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

/// <p>The rows the card lists.</p>
Parameter REMOVALROWS = "KeyId";

/// <p>The self-protection read's pair (AD-8, AD-10, measured at Task 0).</p>
Parameter EXTRAPAIRS = "%Admin_Manage:USE";

Parameter CONSEQUENCE = "ENCRYPTION.KEYFILE.REMOVEKEY";

/// <p>The state refusal, published once in EXPERIENCE.md and pinned equal to
/// <code>OcuPilot.Api.EncryptionError.REASONKEYABSENT</code>.</p>
Parameter REASONKEYABSENT = "This key is not in this key file.";

/// <p>A key the fresh read does not list.</p>
ClassMethod StateRefusal(pFresh As %DynamicObject, pArgs As %DynamicObject) As %String
{
    If '..Holds(pFresh, ##class(OcuPilot.Port.EncryptionPort).#KEYS, ..Argument(pArgs, "KeyId")) Quit ..#REASONKEYABSENT
    Quit ""
}

/// <p>The kernel's merge with the removal row the card lists: the key, as it was, removed.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set pDiff = [{"field": (..#REMOVALROWS), "before": (..Argument(pArgs, ..#REMOVALROWS)), "after": "", "removed": true}]
    Quit tSC
}

/// <p>Gone once the re-read's key list no longer holds the key the payload removed (AD-58).</p>
ClassMethod ReadBackGone(pAfter As %DynamicObject, pPayload As %DynamicObject) As %Boolean
{
    If '$IsObject(pAfter) || '$IsObject(pPayload) Quit 0
    Quit '..Holds(pAfter, ##class(OcuPilot.Port.EncryptionPort).#KEYS, ..Argument(pPayload, ..#REMOVALROWS))
}

/// <p><parameter>CONSEQUENCE</parameter>, whatever the payload.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCE
}

}
