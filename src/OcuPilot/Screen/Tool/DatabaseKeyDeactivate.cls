/// <p>Database encryption's Deactivate (AD-51, AD-53, Story 18.22): propose deactivating one active
/// database encryption key. Two callers reach it: the list's typed-name dialog, whose typed name is the
/// key's identifier, and the agent's proposal and confirmation. No password is asked, as the vendor and
/// the classic page ask none.</p>
/// <p>A key the active list does not hold, and the default key while another key is active, are refused
/// before anything is sent (<method>StateRefusal</method>). A key a mounted encrypted database or the
/// journal still needs is the vendor's refusal, 409
/// <code>ENCRYPTION.KEY.INUSE</code>, and the journal key while another is
/// active 409 <code>ENCRYPTION.KEY.ROLE</code>. It is destructive: a database
/// that needs the key cannot be mounted until it is activated again from a key file.</p>
Class OcuPilot.Screen.Tool.DatabaseKeyDeactivate Extends OcuPilot.Screen.Tool.EncryptionKeyWrite
{

Parameter TOOLNAME = "security.databaseencryption.deactivate";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DatabaseEncryption";

Parameter DESCRIPTION = "Propose deactivating one active database encryption key. Name the key as `KeyId`, its identifier exactly as the Database encryption list reports it. An encrypted database that needs the key cannot be mounted until the key is activated again from a key file: say so in the rationale. The default key cannot be deactivated while another key is active, and the instance refuses a key a mounted database or the journal still needs.";

Parameter ENDPOINT = "Security.Encryption.Key";

Parameter READTYPE = "DATABASEKEYS";

Parameter WRITETYPE = "DEACTIVATE";

Parameter ACTION = "DeactivateDB";

Parameter SCREENACTIONS = "deactivate";

Parameter SCREENVALUES = "deactivate=KeyId";

Parameter ARGUMENTS = "KeyId";

Parameter REQUIREDARGUMENTS = "KeyId";

Parameter RULEFIELDS;

Parameter FINGERPRINTSUBJECT = "Keys,KeyId";

Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

/// <p>The row the card lists.</p>
Parameter REMOVALROWS = "KeyId";

Parameter CONSEQUENCE = "ENCRYPTION.KEY.DEACTIVATE";

/// <p>The default key's state refusal, published once in EXPERIENCE.md and pinned equal to
/// <code>OcuPilot.Api.EncryptionError.REASONKEYDEFAULT</code>.</p>
Parameter REASONKEYDEFAULT = "This is the default key for new encrypted databases while another key is active. Make another active key the default first.";

/// <p>A key the fresh read does not list as active, and the default key while another is active, which
/// the vendor refuses (measured, #1214) and the classic page draws unavailable.</p>
ClassMethod StateRefusal(pFresh As %DynamicObject, pArgs As %DynamicObject) As %String
{
    Set tRow = ..KeyRow(pFresh, ..Argument(pArgs, "KeyId"))
    If '$IsObject(tRow) Quit ..#REASONKEYINACTIVE
    If (tRow.%Get("IsDefault") = 1) && (..ActiveCount(pFresh) > 1) Quit ..#REASONKEYDEFAULT
    Quit ""
}

/// <p>The kernel's merge with the removal row the card lists: the key, as it was, deactivated.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set pDiff = [{"field": (..#REMOVALROWS), "before": (..Argument(pArgs, ..#REMOVALROWS)), "after": "", "removed": true}]
    Quit tSC
}

/// <p>Gone once the re-read's active list no longer holds the key the payload deactivated (AD-58).</p>
ClassMethod ReadBackGone(pAfter As %DynamicObject, pPayload As %DynamicObject) As %Boolean
{
    If '$IsObject(pAfter) || '$IsObject(pPayload) Quit 0
    Quit '$IsObject(..KeyRow(pAfter, ..Argument(pPayload, ..#REMOVALROWS)))
}

}
