/// <p>Propose generating a new RSA key pair as a wallet secret (Story 18.24, DW-1555): the instance
/// generates it from <code>Length</code> and no read returns it, its public half included. Its governance
/// key ships enabled, because a new secret changes no existing encryption (AD-22). A person imports an
/// existing key on the Secret form instead; see <class>OcuPilot.Screen.Tool.WalletKeyCreate</class>.</p>
Class OcuPilot.Screen.Tool.WalletKeyCreateRsa Extends OcuPilot.Screen.Tool.WalletKeyCreate
{

Parameter TOOLNAME = "security.secrets.creatersa";

Parameter DESCRIPTION = "Propose generating a new RSA key pair as a secret in an existing wallet collection on this instance. It generates nothing by itself: it answers a proposal the user reviews and confirms, and the instance then generates the key. Name the secret and its length in bits: 2048, 3072 or 4096. No read ever returns the key, its public half included, and you never hold or send key material; importing an existing key is the user's, on the Secret form.";

Parameter SECRETTYPE = "%Wallet.RSA";

Parameter LENGTHS = "2048,3072,4096";

ClassMethod LengthDescription() As %String
{
    Quit "The key's length in bits: 2048, 3072 or 4096. The instance generates the key pair."
}

}
