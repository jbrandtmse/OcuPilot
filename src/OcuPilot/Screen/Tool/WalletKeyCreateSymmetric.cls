/// <p>Propose generating a new symmetric key as a wallet secret (Story 18.24, DW-1555): the instance
/// generates it from <code>Length</code> and no read returns it. Its governance key ships enabled,
/// because a new secret changes no existing encryption (AD-22). A person imports an existing key on the
/// Secret form instead; see <class>OcuPilot.Screen.Tool.WalletKeyCreate</class>.</p>
Class OcuPilot.Screen.Tool.WalletKeyCreateSymmetric Extends OcuPilot.Screen.Tool.WalletKeyCreate
{

Parameter TOOLNAME = "security.secrets.createsymmetric";

Parameter DESCRIPTION = "Propose generating a new symmetric key as a secret in an existing wallet collection on this instance. It generates nothing by itself: it answers a proposal the user reviews and confirms, and the instance then generates the key. Name the secret and its length in bytes: 16, 24 or 32 (AES-128, AES-192 or AES-256). No read ever returns the key and you never hold or send key material; importing an existing key is the user's, on the Secret form.";

Parameter SECRETTYPE = "%Wallet.SymmetricKey";

Parameter LENGTHS = "16,24,32";

ClassMethod LengthDescription() As %String
{
    Quit "The key's length in bytes: 16, 24 or 32. The instance generates the key."
}

}
