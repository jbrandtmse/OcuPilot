/// <p>Replace the key of an existing symmetric-key secret by one a person imports on the Secret form
/// (Story 18.24, DW-1555). <b>It is unadvertised</b> (<parameter>ADVERTISED</parameter> 0, AD-53): the
/// key is material the model never sees or supplies, so the provider's tool list, the dispatch lookup and
/// the screen context's tools never carry it, and its governance key ships disabled. The vendor
/// generates a symmetric key only on create, so this tool has no generate form. The Secret form's
/// Replace the key is its one caller, through <class>OcuPilot.Area.Security.WalletKeySave</class>.</p>
/// <p>Destructive: data encrypted with the old key can no longer be decrypted with this secret. The
/// secret keeps its <code>KeyId</code>.</p>
Class OcuPilot.Screen.Tool.WalletKeyReplaceSymmetric Extends OcuPilot.Screen.Tool.WalletKeyReplace
{

Parameter TOOLNAME = "security.secrets.replacesymmetric";

Parameter DESCRIPTION = "Replace the key of an existing symmetric-key secret. Only a person replaces a symmetric key, from the Secret form; the agent never sends key material.";

/// <p>Reached by the Secret form alone (AD-53).</p>
Parameter ADVERTISED As BOOLEAN = 0;

Parameter SECRETTYPE = "%Wallet.SymmetricKey";

Parameter CONSEQUENCE = "WALLETKEY.REPLACE.SYMMETRIC";

Parameter FINGERPRINTSUBJECT = "Type,Length,KeyId";

Parameter READANSWERS = "Type,Length,KeyId";

/// <p>The key, as base64 (AD-56 (i)).</p>
Parameter SECRETBODY = "Secret64";

/// <p>The card's one masked row names the key; it carries no value.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = [{"field": "Secret64", "before": "", "after": ""}]
    Set pProblem = ""
    Quit $$$OK
}

}
