/// <p>The wallet key rules (AD-39, AD-55, Story 18.24): the one rule set every caller of an RSA or
/// symmetric key secret's create or replace applies (<method>Validate</method>), and the list the form
/// read serves (<method>Rules</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.WalletKeyError.ReasonFor</method>'s.</b> No sentence
/// quotes key material, a password or any part of a caller's input, and the checks hold the text in
/// locals cleared before they return (AD-35). The checks pre-empt every refusal the vendor answers with
/// a logged 500: the length sets, one source, PEM shape, certificate validity, the private key's
/// pairing and password, and a symmetric key's decoded length. The pairing test is
/// <method>OcuPilot.Area.Security.X509Rules.KeyMatches</method>, which is the vendor's own.</p>
Class OcuPilot.Area.Security.WalletKeyRules Extends %RegisteredObject
{

/// <p>The two key types.</p>
Parameter RSATYPE = "%Wallet.RSA";

Parameter SYMMETRICTYPE = "%Wallet.SymmetricKey";

/// <p>The body fields the rules read, named once.</p>
Parameter FIELDLENGTH = "Length";

Parameter FIELDCERTIFICATE = "Certificate";

Parameter FIELDPUBLICKEY = "PublicKey";

Parameter FIELDPRIVATEKEY = "PrivateKey";

Parameter FIELDPASSWORD = "Password";

Parameter FIELDSECRET64 = "Secret64";

/// <p>The closed sets of lengths: RSA in bits, symmetric in bytes.</p>
Parameter RSALENGTHS = "2048,3072,4096";

Parameter SYMMETRICLENGTHS = "16,24,32";

/// <p>The modes <method>Validate</method> takes: a person's <code>create</code> or <code>replace</code>
/// (generate or import), and the agent's <code>generate</code>, which carries a length alone.</p>
Parameter MODECREATE = "create";

Parameter MODEREPLACE = "replace";

Parameter MODEGENERATE = "generate";

/// <p>Every rule an RSA or symmetric key write applies, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>. <var>pType</var> is the key type, <var>pMode</var> one of the
/// <code>MODE*</code> parameters and <var>pArgs</var> the body's fields.</p>
/// <p><var>pCanonical</var> is, when nothing was refused, the body the port is sent: the length as a
/// number, or each key block as <method>OcuPilot.Port.AdminPort.PemBlock</method> writes it and the
/// password and <code>Secret64</code> as sent (the symmetric key without white space). The caller owns
/// it and clears it once the port has answered.</p>
/// <p><var>pCheckTaken</var> is accepted for the callers' symmetry with the other forms' rules: the
/// name look-up is the caller's (<method>OcuPilot.Area.Security.WalletRules.Taken</method>), made once
/// for a create, and 0 here.</p>
ClassMethod Validate(pType As %String, pMode As %String, pArgs As %DynamicObject, Output pViolations, pCheckTaken As %Boolean = 0, Output pCanonical As %DynamicObject) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set pCanonical = ""
    Set tSC = $$$OK
    Set (tCert, tPublic, tKey, tPassword, tSecret64, tCanonicalCert, tCanonicalPublic, tCanonicalKey, tBytes) = ""
    Try {
        If '$IsObject(pArgs) {
            Do ..Add(.pViolations, ..#FIELDLENGTH, ##class(OcuPilot.Api.WalletKeyError).#SOURCEREQUIRED)
            Quit
        }
        Set tIsRsa = (pType = ..#RSATYPE)
        Set tCanonical = {}

        ; The source: a length to generate, or key material to import, never both.
        Set tLengthType = pArgs.%GetTypeOf(..#FIELDLENGTH)
        Set tHasLength = ((tLengthType '= "unassigned") && (tLengthType '= "null") && '((tLengthType = "string") && (pArgs.%Get(..#FIELDLENGTH) = "")))
        Set tMaterial = $Select(tIsRsa: $ListBuild(..#FIELDCERTIFICATE, ..#FIELDPUBLICKEY, ..#FIELDPRIVATEKEY), 1: $ListBuild(..#FIELDSECRET64))
        Set tHasMaterial = 0
        For tI = 1:1:$ListLength(tMaterial) {
            Set tField = $List(tMaterial, tI)
            If (pArgs.%GetTypeOf(tField) = "string") && ($ZStrip(pArgs.%Get(tField), "<>WC") '= "") Set tHasMaterial = 1
            If (pArgs.%GetTypeOf(tField) '= "unassigned") && (pArgs.%GetTypeOf(tField) '= "null") && (pArgs.%GetTypeOf(tField) '= "string") {
                Do ..Add(.pViolations, tField, ..ShapeCode(pType, tField))
                Set tHasMaterial = 1
            }
        }
        If pMode = ..#MODEGENERATE {
            If 'tHasLength Do ..Add(.pViolations, ..#FIELDLENGTH, ##class(OcuPilot.Api.WalletKeyError).#SOURCEREQUIRED)
            If tHasMaterial Do ..Add(.pViolations, ..#FIELDLENGTH, ##class(OcuPilot.Api.WalletKeyError).#SOURCEBOTH)
        } ElseIf tHasLength && tHasMaterial {
            Do ..Add(.pViolations, ..#FIELDLENGTH, ##class(OcuPilot.Api.WalletKeyError).#SOURCEBOTH)
        } ElseIf 'tHasLength && 'tHasMaterial && (pViolations = 0) {
            Do ..Add(.pViolations, ..#FIELDLENGTH, ##class(OcuPilot.Api.WalletKeyError).#SOURCEREQUIRED)
        }

        If tHasLength {
            Set tLength = pArgs.%Get(..#FIELDLENGTH)
            Set tSet = $Select(tIsRsa: ..#RSALENGTHS, 1: ..#SYMMETRICLENGTHS)
            If ((tLengthType '= "number") && (tLengthType '= "string")) || '$IsValidNum(tLength) || '$ListFind($ListFromString(tSet), +tLength) {
                Do ..Add(.pViolations, ..#FIELDLENGTH, $Select(tIsRsa: ##class(OcuPilot.Api.WalletKeyError).#LENGTHRSA, 1: ##class(OcuPilot.Api.WalletKeyError).#LENGTHSYMMETRIC))
            } Else {
                Do tCanonical.%Set(..#FIELDLENGTH, +tLength, "number")
            }
        }
        If (pMode = ..#MODEGENERATE) || 'tHasMaterial {
            If pViolations = 0 Set pCanonical = tCanonical
            Quit
        }

        If 'tIsRsa {
            Set tSecret64 = pArgs.%Get(..#FIELDSECRET64)
            Set tBytes = ##class(OcuPilot.Port.WalletPort).DecodedKey(tSecret64)
            If '$ListFind($ListFromString(..#SYMMETRICLENGTHS), $Length(tBytes)) {
                Do ..Add(.pViolations, ..#FIELDSECRET64, ##class(OcuPilot.Api.WalletKeyError).#SECRET64SHAPE)
            } Else {
                Do tCanonical.%Set(..#FIELDSECRET64, $ZStrip(tSecret64, "*W"), "string")
            }
            If pViolations = 0 Set pCanonical = tCanonical
            Quit
        }

        ; An RSA import: a certificate or a public key, optionally with the private key and its password.
        Set tPort = "OcuPilot.Port.WalletPort"
        If pArgs.%GetTypeOf(..#FIELDCERTIFICATE) = "string" Set tCert = pArgs.%Get(..#FIELDCERTIFICATE)
        If pArgs.%GetTypeOf(..#FIELDPUBLICKEY) = "string" Set tPublic = pArgs.%Get(..#FIELDPUBLICKEY)
        If pArgs.%GetTypeOf(..#FIELDPRIVATEKEY) = "string" Set tKey = pArgs.%Get(..#FIELDPRIVATEKEY)
        If pArgs.%GetTypeOf(..#FIELDPASSWORD) = "string" Set tPassword = pArgs.%Get(..#FIELDPASSWORD)

        Set tCertPresent = ($ZStrip(tCert, "<>WC") '= "")
        Set tPublicPresent = ($ZStrip(tPublic, "<>WC") '= "")
        Set tKeyPresent = ($ZStrip(tKey, "<>WC") '= "")
        If 'tCertPresent && 'tPublicPresent Do ..Add(.pViolations, ..#FIELDCERTIFICATE, ##class(OcuPilot.Api.WalletKeyError).#PUBLICREQUIRED)

        Set tCertOK = 0
        If tCertPresent {
            If '$ClassMethod(tPort, "PemBlock", tCert, "cert", .tCanonicalCert) {
                Do ..Add(.pViolations, ..#FIELDCERTIFICATE, ##class(OcuPilot.Api.WalletKeyError).#CERTIFICATESHAPE)
            } Else {
                Set tCertBytes = $ClassMethod(tPort, "PemBytes", tCanonicalCert)
                Set (tNotAfter, tNotBefore) = ""
                Try {
                    If tCertBytes '= "" {
                        Set tNotAfter = $System.Encryption.X509GetField(tCertBytes, "ValidityNotAfter")
                        Set tNotBefore = $System.Encryption.X509GetField(tCertBytes, "ValidityNotBefore")
                    }
                } Catch {
                    Set (tNotAfter, tNotBefore) = ""
                }
                Set tCertBytes = ""
                If (tNotAfter = "") || (tNotBefore = "") {
                    Do ..Add(.pViolations, ..#FIELDCERTIFICATE, ##class(OcuPilot.Api.WalletKeyError).#CERTIFICATESHAPE)
                } Else {
                    Set tNow = $ZDateTime($ZTimeStamp, 3)
                    If (tNow ] tNotAfter) || '(tNow ] tNotBefore) {
                        Do ..Add(.pViolations, ..#FIELDCERTIFICATE, ##class(OcuPilot.Api.WalletKeyError).#CERTIFICATEINVALID)
                    } Else {
                        Set tCertOK = 1
                    }
                }
            }
        }

        Set tPublicOK = 0
        If tPublicPresent {
            If '$ClassMethod(tPort, "PemBlock", tPublic, "public", .tCanonicalPublic) {
                Do ..Add(.pViolations, ..#FIELDPUBLICKEY, ##class(OcuPilot.Api.WalletKeyError).#PUBLICKEYSHAPE)
            } ElseIf $System.Encryption.RSAEncrypt("OcuPilot", tCanonicalPublic) = "" {
                Do ..Add(.pViolations, ..#FIELDPUBLICKEY, ##class(OcuPilot.Api.WalletKeyError).#PUBLICKEYSHAPE)
            } Else {
                Set tPublicOK = 1
            }
        }

        Set tKeyOK = 0
        If tKeyPresent {
            If '$ClassMethod(tPort, "PemBlock", tKey, "key", .tCanonicalKey) {
                Do ..Add(.pViolations, ..#FIELDPRIVATEKEY, ##class(OcuPilot.Api.WalletKeyError).#PRIVATEKEYSHAPE)
            } Else {
                Set tKeyOK = 1
            }
        }

        Set tEncrypted = (tKeyOK && (tCanonicalKey [ "ENCRYPTED"))
        If (tPassword '= "") && ('tKeyPresent || (tKeyOK && 'tEncrypted)) {
            Do ..Add(.pViolations, ..#FIELDPASSWORD, ##class(OcuPilot.Api.WalletKeyError).#PASSWORDWITHOUTKEY)
        } ElseIf tEncrypted && (tPassword = "") {
            Do ..Add(.pViolations, ..#FIELDPASSWORD, ##class(OcuPilot.Api.WalletKeyError).#PASSWORDREQUIRED)
        } ElseIf tKeyOK && ((tCertPresent && tCertOK) || (tPublicOK && 'tCertPresent)) {
            Set tMatch = ##class(OcuPilot.Area.Security.X509Rules).KeyMatches($Select(tCertPresent: tCanonicalCert, 1: tCanonicalPublic), tCanonicalKey, tPassword)
            If tMatch = "wrong" Do ..Add(.pViolations, ..#FIELDPASSWORD, ##class(OcuPilot.Api.WalletKeyError).#PASSWORDWRONG)
            If tMatch = "mismatch" Do ..Add(.pViolations, ..#FIELDPRIVATEKEY, ##class(OcuPilot.Api.WalletKeyError).#PRIVATEKEYMISMATCH)
        }

        If pViolations = 0 {
            If tCertPresent Do tCanonical.%Set(..#FIELDCERTIFICATE, tCanonicalCert, "string")
            If tPublicPresent Do tCanonical.%Set(..#FIELDPUBLICKEY, tCanonicalPublic, "string")
            If tKeyPresent Do tCanonical.%Set(..#FIELDPRIVATEKEY, tCanonicalKey, "string")
            If tPassword '= "" Do tCanonical.%Set(..#FIELDPASSWORD, tPassword, "string")
            Set pCanonical = tCanonical
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
        Set pCanonical = ""
    }
    Set (tCert, tPublic, tKey, tPassword, tSecret64, tCanonicalCert, tCanonicalPublic, tCanonicalKey, tBytes) = ""
    Set tCanonical = ""
    Quit tSC
}

/// <p>The code a member of the wrong JSON type refuses with: the shape code of its own field.</p>
ClassMethod ShapeCode(pType As %String, pField As %String) As %String [ Private ]
{
    If pField = ..#FIELDCERTIFICATE Quit ##class(OcuPilot.Api.WalletKeyError).#CERTIFICATESHAPE
    If pField = ..#FIELDPUBLICKEY Quit ##class(OcuPilot.Api.WalletKeyError).#PUBLICKEYSHAPE
    If pField = ..#FIELDPRIVATEKEY Quit ##class(OcuPilot.Api.WalletKeyError).#PRIVATEKEYSHAPE
    Quit ##class(OcuPilot.Api.WalletKeyError).#SECRET64SHAPE
}

/// <p>The fields a key write of type <var>pType</var> may carry, as a <class>%List</class>: an RSA key's
/// <code>Length</code>, <code>Certificate</code>, <code>PublicKey</code>, <code>PrivateKey</code> and
/// <code>Password</code>; a symmetric key's <code>Length</code> and <code>Secret64</code>, and for a
/// replace <code>Secret64</code> alone, since a replacement is an import. <var>pCreates</var> is 1 for a
/// create.</p>
ClassMethod KeyFields(pType As %String, pCreates As %Boolean) As %List
{
    If pType = ..#RSATYPE Quit $ListBuild(..#FIELDLENGTH, ..#FIELDCERTIFICATE, ..#FIELDPUBLICKEY, ..#FIELDPRIVATEKEY, ..#FIELDPASSWORD)
    If pType = ..#SYMMETRICTYPE Quit $Select(pCreates: $ListBuild(..#FIELDLENGTH, ..#FIELDSECRET64), 1: $ListBuild(..#FIELDSECRET64))
    Quit ""
}

/// <p>Every key rule, as <code>[{field, code, reason}]</code>, for the form read. The sentences are
/// <method>OcuPilot.Api.WalletKeyError.ReasonFor</method>'s.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = ##class(OcuPilot.Api.WalletKeyError).ViolationCodes()
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tRow = {}
        Do tRow.%Set("field", ##class(OcuPilot.Api.WalletKeyError).FieldOf(tCode), "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", ##class(OcuPilot.Api.WalletKeyError).ReasonFor(tCode), "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
