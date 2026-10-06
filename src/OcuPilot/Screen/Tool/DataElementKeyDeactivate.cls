/// <p>Data element encryption's Deactivate (AD-51, AD-53, Story 18.22): propose deactivating one active
/// data-element encryption key. Two callers reach it: the list's typed-name dialog, whose typed name is
/// the key's identifier, and the agent's proposal and confirmation. No password is asked, as the vendor
/// and the classic page ask none.</p>
/// <p>A key the active list does not hold is refused before anything is sent
/// (<method>StateRefusal</method>). It is destructive: data encrypted with the key cannot be read or
/// written until the key is activated again from a key file.</p>
Class OcuPilot.Screen.Tool.DataElementKeyDeactivate Extends OcuPilot.Screen.Tool.EncryptionKeyWrite
{

Parameter TOOLNAME = "security.dataelementencryption.deactivate";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DataElementEncryption";

Parameter DESCRIPTION = "Propose deactivating one active data element encryption key. Name the key as `KeyId`, its identifier exactly as the Data element encryption list reports it. Data encrypted with the key cannot be read or written until the key is activated again from a key file: say so in the rationale.";

Parameter ENDPOINT = "Security.Encryption.Key";

Parameter READTYPE = "DATAELEMENTKEYS";

Parameter WRITETYPE = "DEACTIVATE";

Parameter ACTION = "DeactivateMK";

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

Parameter CONSEQUENCE = "ENCRYPTION.KEY.DEACTIVATEDATAELEMENT";

/// <p>A key the fresh read does not list as active.</p>
ClassMethod StateRefusal(pFresh As %DynamicObject, pArgs As %DynamicObject) As %String
{
    If '$IsObject(..KeyRow(pFresh, ..Argument(pArgs, "KeyId"))) Quit ..#REASONKEYINACTIVE
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
