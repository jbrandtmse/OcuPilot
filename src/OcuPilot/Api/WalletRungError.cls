/// <p>The wallet credential rung's codes (AD-39, AD-42): every <code>WALLETRUNG.*</code> code a definition save, the
/// credential store route and a provider call answer, and the one sentence each carries. They live beside
/// <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit of 1,000 parameters
/// (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method>, <method>OcuPilot.Api.Error.ReasonForViolation</method>
/// and <method>OcuPilot.Api.Error.ReasonForTurnError</method> answer these codes through <method>ReasonFor</method>.</p>
/// <p>No sentence quotes a caller's input (AD-35) or the instance's own text (AD-39).</p>
Class OcuPilot.Api.WalletRungError Extends %RegisteredObject
{

/// <p>Violation code (422): <code>credentialName</code> of a <code>wallet</code> definition is not a secret name,
/// <code>collection.secret</code>, of at most 128 characters. Nothing is stored.</p>
Parameter NAME = "WALLETRUNG.NAME";

Parameter REASONNAME = "Name the wallet secret as collection.secret, as the Secrets screen lists it, in at most 128 characters.";

/// <p>Violation code (422): a key is posted to the credential store route of a <code>wallet</code> definition. The
/// Secrets screen owns every wallet secret, so nothing is written.</p>
Parameter KEYSTORE = "WALLETRUNG.KEYSTORE";

Parameter REASONKEYSTORE = "This definition reads its key from a wallet secret, which OcuPilot never stores. Set the key on the Secrets screen.";

/// <p>Refusal (403): the caller holds neither the use resource of the secret's collection nor
/// <code>%Admin_Wallet:USE</code>, so the secret is not read. <code>detail.failedPair</code> names the use resource.</p>
Parameter USE = "WALLETRUNG.USE";

Parameter REASONUSE = "This account may not use the wallet secret this definition names. It needs the use resource of the secret's collection, or %Admin_Wallet:USE.";

/// <p>Refusal (503): the secret does not allow custom use and the caller lacks <code>%Admin_Wallet:USE</code>, so the
/// secret is not read. <code>detail.failedPair</code> names <code>%Admin_Wallet:USE</code>.</p>
Parameter USAGE = "WALLETRUNG.USAGE";

Parameter REASONUSAGE = "The wallet secret this definition names does not allow custom use, so reading it needs %Admin_Wallet:USE, which this account does not hold.";

/// <p>Refusal (503): the secret sets <code>RequireTLS</code> and the endpoint the call goes to is not https, so the secret
/// is not read. <code>detail.setting</code> names <code>RequireTLS</code>.</p>
Parameter REQUIRETLS = "WALLETRUNG.REQUIRETLS";

Parameter REASONREQUIRETLS = "The wallet secret this definition names requires TLS, and this definition's endpoint is not https, so the secret was not read. Use an https endpoint, or change the secret's RequireTLS setting.";

/// <p>Refusal (503): the secret sets <code>RequireTLS</code> and lists the hosts it may be sent to, and the endpoint's host
/// is none of them, so the secret is not read. <code>detail.setting</code> names <code>AllowedHosts</code>.</p>
Parameter ALLOWEDHOSTS = "WALLETRUNG.ALLOWEDHOSTS";

Parameter REASONALLOWEDHOSTS = "The wallet secret this definition names may be sent only to the hosts in its AllowedHosts setting, and this definition's endpoint host is not one of them, so the secret was not read. Use a listed host, or change the secret's AllowedHosts setting.";

/// <p>The text the use refusal's sentence is written around, replaced by the pair that failed when one is named.</p>
Parameter USERESOURCEPHRASE = "the use resource of the secret's collection";

/// <p>Every <code>WALLETRUNG.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#NAME, ..#KEYSTORE, ..#USE, ..#USAGE, ..#REQUIRETLS, ..#ALLOWEDHOSTS)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not declare.
/// <var>pPair</var>, where it is given, replaces the use resource the use refusal is written around, so the sentence
/// names the pair that failed (AD-8); the usage refusal already names its pair, and the two setting refusals name their
/// setting.</p>
ClassMethod ReasonFor(pCode As %String, pPair As %String = "") As %String
{
    If pCode = ..#NAME Quit ..#REASONNAME
    If pCode = ..#KEYSTORE Quit ..#REASONKEYSTORE
    If pCode = ..#USE {
        If pPair = "" Quit ..#REASONUSE
        Quit $Replace(..#REASONUSE, ..#USERESOURCEPHRASE, pPair)
    }
    If pCode = ..#USAGE Quit ..#REASONUSAGE
    If pCode = ..#REQUIRETLS Quit ..#REASONREQUIRETLS
    If pCode = ..#ALLOWEDHOSTS Quit ..#REASONALLOWEDHOSTS
    Quit ""
}

/// <p>The numeric status a route answers <var>pCode</var> with: a refusal for want of the use resource is 403, one for
/// want of custom use, or by the secret's own transport settings, is 503 (the definition is not usable as configured, and is
/// left enabled), and a malformed name or a key posted to a wallet definition is 422.</p>
ClassMethod HttpFor(pCode As %String) As %Integer
{
    If pCode = ..#USE Quit 403
    If (pCode = ..#USAGE) || (pCode = ..#REQUIRETLS) || (pCode = ..#ALLOWEDHOSTS) Quit 503
    Quit 422
}

/// <p>The member of a refusal's <code>detail</code> that carries the second element of the ladder's refusal for
/// <var>pCode</var>: <code>setting</code>, the setting of the secret that refused the call, for the two setting refusals,
/// and <code>failedPair</code>, the pair the caller lacks, for the others.</p>
ClassMethod DetailKeyFor(pCode As %String) As %String
{
    If (pCode = ..#REQUIRETLS) || (pCode = ..#ALLOWEDHOSTS) Quit "setting"
    Quit "failedPair"
}

}
