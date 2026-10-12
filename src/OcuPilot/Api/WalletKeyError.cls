/// <p>The wallet key tools' codes (AD-39, Story 18.24): every <code>WALLETKEY.*</code> code the RSA and
/// symmetric-key secret create, import and replace answer, and the one sentence each carries. They live
/// beside <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's
/// limit of 1,000 parameters (ERROR #5290); <method>OcuPilot.Api.Error.ReasonForToolCode</method> and
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> answer these codes through
/// <method>ReasonFor</method>.</p>
/// <p>No sentence quotes key material, a password or any part of a caller's input (AD-35).</p>
Class OcuPilot.Api.WalletKeyError Extends %RegisteredObject
{

/// <p>Envelope code: a key request refused on one or more of its fields, its
/// <code>detail.violations</code> naming each (422).</p>
Parameter VALIDATION = "WALLETKEY.VALIDATION";

Parameter REASONVALIDATION = "The key was refused.";

/// <p>Violation code: neither a length to generate nor a key to import, on <code>Length</code>.</p>
Parameter SOURCEREQUIRED = "WALLETKEY.SOURCE.REQUIRED";

Parameter REASONSOURCEREQUIRED = "Choose a length to generate a key, or enter a key to import.";

/// <p>Violation code: a length and key material together, on <code>Length</code>.</p>
Parameter SOURCEBOTH = "WALLETKEY.SOURCE.BOTH";

Parameter REASONSOURCEBOTH = "Generate a key or import one, not both.";

/// <p>Violation code: an RSA length outside the closed set, on <code>Length</code>.</p>
Parameter LENGTHRSA = "WALLETKEY.LENGTH.RSA";

Parameter REASONLENGTHRSA = "An RSA key is 2048, 3072 or 4096 bits long.";

/// <p>Violation code: a symmetric length outside the closed set, on <code>Length</code>.</p>
Parameter LENGTHSYMMETRIC = "WALLETKEY.LENGTH.SYMMETRIC";

Parameter REASONLENGTHSYMMETRIC = "A symmetric key is 16, 24 or 32 bytes long.";

/// <p>Violation code: an RSA import with neither a certificate nor a public key, on
/// <code>Certificate</code>.</p>
Parameter PUBLICREQUIRED = "WALLETKEY.PUBLIC.REQUIRED";

Parameter REASONPUBLICREQUIRED = "An imported RSA key needs its certificate or its public key.";

/// <p>Violation codes: a certificate, public key or private key that is not one PEM block of its
/// kind.</p>
Parameter CERTIFICATESHAPE = "WALLETKEY.CERTIFICATE.SHAPE";

Parameter REASONCERTIFICATESHAPE = "Paste one PEM certificate.";

Parameter PUBLICKEYSHAPE = "WALLETKEY.PUBLICKEY.SHAPE";

Parameter REASONPUBLICKEYSHAPE = "Paste one PEM RSA public key.";

Parameter PRIVATEKEYSHAPE = "WALLETKEY.PRIVATEKEY.SHAPE";

Parameter REASONPRIVATEKEYSHAPE = "Paste one PEM private key.";

/// <p>Violation code: a certificate that has expired or is not yet valid.</p>
Parameter CERTIFICATEINVALID = "WALLETKEY.CERTIFICATE.INVALID";

Parameter REASONCERTIFICATEINVALID = "This certificate is not valid now: it has expired or is not yet valid.";

/// <p>Violation code: a private key that does not belong to the certificate or public key, or is not
/// an RSA key.</p>
Parameter PRIVATEKEYMISMATCH = "WALLETKEY.PRIVATEKEY.MISMATCH";

Parameter REASONPRIVATEKEYMISMATCH = "This private key does not belong to the certificate or public key, or is not an RSA key.";

/// <p>Violation codes: an encrypted private key sent with no password, a password that does not open
/// it, and a password sent with no encrypted private key.</p>
Parameter PASSWORDREQUIRED = "WALLETKEY.PASSWORD.REQUIRED";

Parameter REASONPASSWORDREQUIRED = "This private key is encrypted. Enter its password.";

Parameter PASSWORDWRONG = "WALLETKEY.PASSWORD.WRONG";

Parameter REASONPASSWORDWRONG = "This password does not open the private key.";

Parameter PASSWORDWITHOUTKEY = "WALLETKEY.PASSWORD.WITHOUTKEY";

Parameter REASONPASSWORDWITHOUTKEY = "A password is used only with an encrypted private key.";

/// <p>Violation code: a symmetric key that is not base64 decoding to 16, 24 or 32 bytes, on
/// <code>Secret64</code>.</p>
Parameter SECRET64SHAPE = "WALLETKEY.SECRET64.SHAPE";

Parameter REASONSECRET64SHAPE = "Enter the key as base64 that decodes to 16, 24 or 32 bytes.";

/// <p>Violation code: a secret that holds another type of key than the tool's, on
/// <code>Type</code>.</p>
Parameter TYPEMISMATCH = "WALLETKEY.TYPE.MISMATCH";

Parameter REASONTYPEMISMATCH = "This secret holds another type of key, and a secret's type cannot change.";

/// <p>Consequence codes of the two replace tools, which
/// <class>OcuPilot.Kernel.Proposal.Mint</class> stores and the card renders.</p>
Parameter REPLACERSA = "WALLETKEY.REPLACE.RSA";

Parameter REASONREPLACERSA = "Replaces the whole key pair. The old private key is discarded, so data encrypted to the old public key can no longer be decrypted with this secret. An import without a private key leaves the secret with none.";

Parameter REPLACESYMMETRIC = "WALLETKEY.REPLACE.SYMMETRIC";

Parameter REASONREPLACESYMMETRIC = "Replaces the key. Data encrypted with the old key can no longer be decrypted with this secret.";

/// <p>Every <code>WALLETKEY.*</code> code, as a <class>%List</class>.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#VALIDATION, ..#SOURCEREQUIRED, ..#SOURCEBOTH, ..#LENGTHRSA, ..#LENGTHSYMMETRIC, ..#PUBLICREQUIRED, ..#CERTIFICATESHAPE, ..#PUBLICKEYSHAPE, ..#PRIVATEKEYSHAPE, ..#CERTIFICATEINVALID, ..#PRIVATEKEYMISMATCH, ..#PASSWORDREQUIRED, ..#PASSWORDWRONG, ..#PASSWORDWITHOUTKEY, ..#SECRET64SHAPE, ..#TYPEMISMATCH, ..#REPLACERSA, ..#REPLACESYMMETRIC)
}

/// <p>The field-level codes, as a <class>%List</class>, each with its field in
/// <method>FieldOf</method>.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#SOURCEREQUIRED, ..#SOURCEBOTH, ..#LENGTHRSA, ..#LENGTHSYMMETRIC, ..#PUBLICREQUIRED, ..#CERTIFICATESHAPE, ..#PUBLICKEYSHAPE, ..#PRIVATEKEYSHAPE, ..#CERTIFICATEINVALID, ..#PRIVATEKEYMISMATCH, ..#PASSWORDREQUIRED, ..#PASSWORDWRONG, ..#PASSWORDWITHOUTKEY, ..#SECRET64SHAPE, ..#TYPEMISMATCH)
}

/// <p>The form field a violation code refuses, or <code>""</code>.</p>
ClassMethod FieldOf(pCode As %String) As %String
{
    If (pCode = ..#SOURCEREQUIRED) || (pCode = ..#SOURCEBOTH) || (pCode = ..#LENGTHRSA) || (pCode = ..#LENGTHSYMMETRIC) Quit "Length"
    If (pCode = ..#PUBLICREQUIRED) || (pCode = ..#CERTIFICATESHAPE) || (pCode = ..#CERTIFICATEINVALID) Quit "Certificate"
    If pCode = ..#PUBLICKEYSHAPE Quit "PublicKey"
    If (pCode = ..#PRIVATEKEYSHAPE) || (pCode = ..#PRIVATEKEYMISMATCH) Quit "PrivateKey"
    If (pCode = ..#PASSWORDREQUIRED) || (pCode = ..#PASSWORDWRONG) || (pCode = ..#PASSWORDWITHOUTKEY) Quit "Password"
    If pCode = ..#SECRET64SHAPE Quit "Secret64"
    If pCode = ..#TYPEMISMATCH Quit "Type"
    Quit ""
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#VALIDATION Quit ..#REASONVALIDATION
    If pCode = ..#SOURCEREQUIRED Quit ..#REASONSOURCEREQUIRED
    If pCode = ..#SOURCEBOTH Quit ..#REASONSOURCEBOTH
    If pCode = ..#LENGTHRSA Quit ..#REASONLENGTHRSA
    If pCode = ..#LENGTHSYMMETRIC Quit ..#REASONLENGTHSYMMETRIC
    If pCode = ..#PUBLICREQUIRED Quit ..#REASONPUBLICREQUIRED
    If pCode = ..#CERTIFICATESHAPE Quit ..#REASONCERTIFICATESHAPE
    If pCode = ..#PUBLICKEYSHAPE Quit ..#REASONPUBLICKEYSHAPE
    If pCode = ..#PRIVATEKEYSHAPE Quit ..#REASONPRIVATEKEYSHAPE
    If pCode = ..#CERTIFICATEINVALID Quit ..#REASONCERTIFICATEINVALID
    If pCode = ..#PRIVATEKEYMISMATCH Quit ..#REASONPRIVATEKEYMISMATCH
    If pCode = ..#PASSWORDREQUIRED Quit ..#REASONPASSWORDREQUIRED
    If pCode = ..#PASSWORDWRONG Quit ..#REASONPASSWORDWRONG
    If pCode = ..#PASSWORDWITHOUTKEY Quit ..#REASONPASSWORDWITHOUTKEY
    If pCode = ..#SECRET64SHAPE Quit ..#REASONSECRET64SHAPE
    If pCode = ..#TYPEMISMATCH Quit ..#REASONTYPEMISMATCH
    If pCode = ..#REPLACERSA Quit ..#REASONREPLACERSA
    If pCode = ..#REPLACESYMMETRIC Quit ..#REASONREPLACESYMMETRIC
    Quit ""
}

}
