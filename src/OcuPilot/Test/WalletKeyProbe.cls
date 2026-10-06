/// <p>Test-only helper for the wallet key suites (Story 18.24): <class>OcuPilot.Test.WalletProbe</class>
/// over its own probe collection <parameter>COLLECTION</parameter>, with the reads and the mint and confirm
/// the key tests share. Key material is made by the tests at run time
/// (<class>OcuPilot.Test.X509Material</class>, <code>$System.Encryption.GenCryptRand</code>) and the probe
/// collection and its secrets are removed by exact name.</p>
/// <p><b>It reads a stored key in one place</b>, <method>StoredKeyEquals</method>, which a test uses to
/// prove that an imported symmetric key is stored as given. No shipped class reads a key; this helper is
/// not shipped.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.WalletKeyProbe Extends OcuPilot.Test.WalletProbe
{

/// <p>The probe collection every wallet key suite writes into.</p>
Parameter COLLECTION = "OcuPilotProbe1824";

Parameter LIST = "OcuPilot.Screen.Descriptor.WalletSecretList";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter CONFIRM = "OcuPilot.Test.WalletConfirm";

/// <p>The probe collection's full name for the secret <var>pPart</var>.</p>
ClassMethod Name(pPart As %String) As %String
{
    Quit ..#COLLECTION _ "." _ pPart
}

/// <p>Store an RSA key pair of <var>pLength</var> bits as <var>pName</var>, as the vendor class's own
/// <code>Create</code> does.</p>
ClassMethod AddRsa(pName As %String, pLength As %Integer = 2048) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(%Wallet.RSA).Create(pName, {"Length": (pLength)})
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The secret <var>pName</var> as the wallet port reads it: an object of its metadata, or
/// <code>""</code>.</p>
ClassMethod Metadata(pName As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = ##class(OcuPilot.Port.WalletPort).Invoke("Wallet.Secret", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) Quit ""
    Quit tResult
}

/// <p>Whether the symmetric key stored as <var>pName</var> is the key <var>pKey</var> (bytes): the same
/// AES-CBC encryption of one plaintext under one initialization vector, taken through the wallet class
/// and through the key.</p>
ClassMethod StoredKeyEquals(pName As %String, pKey As %String) As %Boolean
{
    Set tEqual = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tPlain = "OcuPilot wallet key round trip"
        Set tIV = $System.Encryption.GenCryptRand(16)
        Set tExpected = $System.Encryption.AESCBCEncrypt(tPlain, pKey, tIV)
        Set $NAMESPACE = "%SYS"
        Set tStored = ##class(%Wallet.SymmetricKey).AESCBCEncrypt(pName, tPlain, tIV)
        Set $NAMESPACE = tOrigNS
        Set tEqual = ((tStored '= "") && (tStored = tExpected))
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tEqual = 0
    }
    Quit tEqual
}

/// <p>Mint one write of tool <var>pTool</var> against <var>pName</var> through the shipped mint, as
/// <method>OcuPilot.Screen.Tool.Write.View</method> would; <var>pTurnKey</var> is the seeded turn.</p>
ClassMethod Mint(pTool As %String, pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pTurnKey As %String) As %Status
{
    Set pProposal = ""
    Set pTurnKey = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#LIST, $Parameter(pTool, "TOOLNAME"), $Username, "", pTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pName, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
}

/// <p>Confirm <var>pKey</var> through the shipped transition, its port recorded, with <var>pSecrets</var>
/// as the body.</p>
ClassMethod Confirm(pKey As %String, pSecrets As %DynamicObject, Output pHttp As %Integer, Output pCode As %String, Output pResult As %DynamicObject) As %Status
{
    Set pResult = ""
    Quit $ClassMethod(..#CONFIRM, "Confirm", pKey, pSecrets, $Username, .pResult, .pHttp, .pCode, .tDetail)
}

/// <p>The code <var>pViolations</var> carries for <var>pField</var>, or <code>""</code>.</p>
ClassMethod CodeFor(ByRef pViolations, pField As %String) As %String
{
    Set tCode = ""
    For tI = 1:1:+$Get(pViolations) {
        If $List(pViolations(tI), 1) = pField Set tCode = $List(pViolations(tI), 2) Quit
    }
    Quit tCode
}

/// <p>Every code <var>pViolations</var> carries, comma-separated.</p>
ClassMethod CodesOf(ByRef pViolations) As %String
{
    Set tCodes = ""
    For tI = 1:1:+$Get(pViolations) Set tCodes = tCodes _ $Select(tCodes = "": "", 1: ",") _ $List(pViolations(tI), 2)
    Quit tCodes
}

/// <p>The message log's size, for a scan of what a leg added.</p>
ClassMethod LogSize() As %Integer
{
    Quit ##class(%File).GetFileSize(##class(%File).NormalizeFilename("messages.log", $System.Util.ManagerDirectory()))
}

/// <p>What the message log gained after byte <var>pOffset</var>, at most 4 MB of it.</p>
ClassMethod LogSince(pOffset As %Integer) As %String
{
    Set tText = ""
    Try {
        Set tStream = ##class(%Stream.FileBinary).%New()
        Set tSC = tStream.LinkToFile(##class(%File).NormalizeFilename("messages.log", $System.Util.ManagerDirectory()))
        If $$$ISERR(tSC) Quit
        If pOffset > 0 Do tStream.MoveTo(pOffset + 1)
        While 'tStream.AtEnd && ($Length(tText) < 4000000) {
            Set tText = tText _ tStream.Read(32000)
        }
    } Catch {
        Set tText = ""
    }
    Quit tText
}

}
