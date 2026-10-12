/// <p>Replace the key pair of an existing RSA secret by a newly generated one (Story 18.24, DW-1555):
/// <code>Length</code> in bits, from the closed set. The agent generates and never imports; a person
/// imports on the Secret form. Destructive, and its governance key ships disabled (AD-22): the old
/// private key is discarded, so data encrypted to the old public key can no longer be decrypted with this
/// secret.</p>
/// <p>The fingerprint covers the secret's type, length, whether it holds a private key and a
/// certificate, and the length asked for (<code>NewLength</code>), so a confirm after any of them moved
/// is refused as a moved target with nothing sent.</p>
Class OcuPilot.Screen.Tool.WalletKeyReplaceRsa Extends OcuPilot.Screen.Tool.WalletKeyReplace
{

Parameter TOOLNAME = "security.secrets.replacersa";

Parameter DESCRIPTION = "Propose replacing the key pair of an existing RSA secret with a newly generated one on this instance. It replaces nothing by itself: it answers a proposal the user reviews and confirms. Name the secret exactly as the collection's Secrets list reports it, and the new length in bits: 2048, 3072 or 4096. The old private key is discarded, so data encrypted to the old public key can no longer be decrypted with this secret: say so in the rationale. You never hold or send key material.";

Parameter SECRETTYPE = "%Wallet.RSA";

Parameter CONSEQUENCE = "WALLETKEY.REPLACE.RSA";

Parameter ARGUMENTS = "Length";

Parameter FINGERPRINTSUBJECT = "Type,Length,HasPrivateKey,HasCertificate,NewLength";

Parameter READANSWERS = "Type,Length,HasPrivateKey,HasCertificate,NewLength";

/// <p>The material members a confirm may carry: this tool generates, so the port refuses any of them
/// beside the length (<code>WALLETKEY.SOURCE.BOTH</code>) and nothing is sent. An import is the person's,
/// on the Secret form.</p>
Parameter SECRETBODY = "Certificate,PublicKey,PrivateKey,Password,Secret64";

/// <p>The new length joins the payload as <code>NewLength</code> and the card's one row shows the
/// length before and after, always: a replacement at the same length still replaces the pair.</p>
ClassMethod Arguments(pFresh As %DynamicObject, pArgs As %DynamicObject, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pProblem As %String)
{
    Set pProblem = ""
    Set tType = pArgs.%GetTypeOf("Length")
    If ((tType '= "number") && (tType '= "string")) || '$ListFind($ListFromString(##class(OcuPilot.Area.Security.WalletKeyRules).#RSALENGTHS), +pArgs.%Get("Length")) {
        Set pProblem = "'Length': " _ ##class(OcuPilot.Api.Error).ReasonForViolation("WALLETKEY.LENGTH.RSA")
        Quit
    }
    Do pPayload.%Set("NewLength", +pArgs.%Get("Length"), "number")
    Set tRow = {}
    Do tRow.%Set("field", "Length", "string")
    Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get("Length"), pFresh.%GetTypeOf("Length")), "string")
    Do tRow.%Set("after", +pArgs.%Get("Length"), "string")
    Do pDiff.%Push(tRow)
}

ClassMethod DescribeArguments(pSchema As %DynamicObject)
{
    Set tLength = {"type": "integer", "enum": [2048, 3072, 4096]}
    Do tLength.%Set("description", "The new key's length in bits: 2048, 3072 or 4096. The instance generates the key pair.", "string")
    Do pSchema.%Get("properties").%Set("Length", tLength)
    Do pSchema.%Get("required").%Push("Length")
}

/// <p>The key rules' <code>generate</code> mode over the arguments (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Area.Security.WalletKeyRules).Validate(..#SECRETTYPE, ##class(OcuPilot.Area.Security.WalletKeyRules).#MODEGENERATE, pArgs, .tViolations, 0)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
    }
    Quit $$$OK
}

}
