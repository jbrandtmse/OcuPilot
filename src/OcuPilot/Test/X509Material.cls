/// <p>PEM material for the X.509 tests, made at run time by the instance's own OpenSSL, so the
/// repository holds no private key. <method>Generate</method> runs the commands below through
/// <code>$ZF(-100)</code> in a directory of its own under the instance's temp directory and reads each
/// file into this process as text; <method>Discard</method> forgets the text and deletes the directory,
/// failing when it survives. A test class calls the first from <code>OnBeforeAllTests</code> and the
/// second from <code>OnAfterAllTests</code>. None of it is used but a throwaway instance's probe
/// credentials, each deleted by exact alias.</p>
/// <p><b>Needs:</b> <code>/usr/bin/openssl</code> (OpenSSL 3.0 on the pinned image) and the privilege
/// <code>$ZF(-100)</code> requires. A refusal of either fails <method>Generate</method>; nothing falls
/// back to stored material.</p>
/// <pre>
/// openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 36500 -subj "/CN=OcuPilot Test Certificate"
/// openssl pkcs8 -topk8 -in key.pem -out key-enc.pem -v2 aes-256-cbc -passout pass:PASSWORD
/// openssl rsa -in key.pem -out key-legacy.pem -aes256 -traditional -passout pass:PASSWORD
/// openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out other.pem
/// openssl req -new -key key.pem -out expired.csr -subj "/CN=OcuPilot Expired Certificate"
/// openssl ca -config ca.cnf -selfsign -keyfile key.pem -in expired.csr -startdate 20200101000000Z -enddate 20210101000000Z -batch -notext -out expired.pem
/// </pre>
Class OcuPilot.Test.X509Material Extends %RegisteredObject
{

/// <p>The password the encrypted and legacy keys are encrypted under.</p>
Parameter PASSWORD = "OcuPilotTest85";

Parameter OPENSSL = "/usr/bin/openssl";

/// <p>The prefix of every directory <method>Generate</method> makes, which is also the only kind
/// <method>Discard</method> deletes.</p>
Parameter PREFIX = "ocupilot-x509-";

/// <p>Each block's name and the file it is read from.</p>
Parameter FILES = "Certificate:cert.pem,PrivateKey:key.pem,EncryptedKey:key-enc.pem,LegacyKey:key-legacy.pem,OtherKey:other.pem,ExpiredCertificate:expired.pem";

/// <p>Make the material in a new directory under the instance's temp directory, returned in
/// <var>pDirectory</var>, and hold each block in this process for <method>Pem</method>. On failure
/// the directory is already deleted.</p>
ClassMethod Generate(Output pDirectory As %String) As %Status
{
    Set tSC = $$$OK
    Kill ^||OcuPilotX509Material
    Set pDirectory = ##class(%File).NormalizeDirectory(..#PREFIX _ $Job _ "-" _ $Random(1000000000), ##class(%SYS.System).TempDirectory())
    Try {
        If '##class(%File).CreateDirectoryChain(pDirectory, .tReturn) {
            Set tSC = $$$ERROR($$$GeneralError, "could not create " _ pDirectory _ " (" _ $Get(tReturn) _ ")")
            Quit
        }
        Set tPass = "pass:" _ ..#PASSWORD
        Set tSC = ..Run(pDirectory, "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", pDirectory _ "key.pem", "-out", pDirectory _ "cert.pem", "-days", 36500, "-subj", "/CN=OcuPilot Test Certificate")
        If $$$ISERR(tSC) Quit
        Set tSC = ..Run(pDirectory, "pkcs8", "-topk8", "-in", pDirectory _ "key.pem", "-out", pDirectory _ "key-enc.pem", "-v2", "aes-256-cbc", "-passout", tPass)
        If $$$ISERR(tSC) Quit
        Set tSC = ..Run(pDirectory, "rsa", "-in", pDirectory _ "key.pem", "-out", pDirectory _ "key-legacy.pem", "-aes256", "-traditional", "-passout", tPass)
        If $$$ISERR(tSC) Quit
        Set tSC = ..Run(pDirectory, "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048", "-out", pDirectory _ "other.pem")
        If $$$ISERR(tSC) Quit
        Set tSC = ..Run(pDirectory, "req", "-new", "-key", pDirectory _ "key.pem", "-out", pDirectory _ "expired.csr", "-subj", "/CN=OcuPilot Expired Certificate")
        If $$$ISERR(tSC) Quit
        Set tSC = ..WriteAuthority(pDirectory)
        If $$$ISERR(tSC) Quit
        Set tSC = ..Run(pDirectory, "ca", "-config", pDirectory _ "ca.cnf", "-selfsign", "-keyfile", pDirectory _ "key.pem", "-in", pDirectory _ "expired.csr", "-startdate", "20200101000000Z", "-enddate", "20210101000000Z", "-batch", "-notext", "-out", pDirectory _ "expired.pem")
        If $$$ISERR(tSC) Quit
        For tI = 1:1:$Length(..#FILES, ",") {
            Set tEntry = $Piece(..#FILES, ",", tI)
            Set tText = ..ReadText(pDirectory _ $Piece(tEntry, ":", 2))
            If tText '[ "-----BEGIN " {
                Set tSC = $$$ERROR($$$GeneralError, "openssl wrote no PEM block to " _ $Piece(tEntry, ":", 2))
                Quit
            }
            Set ^||OcuPilotX509Material($Piece(tEntry, ":", 1)) = tText
        }
    } Catch tEx {
        Set tSC = $$$ERROR($$$GeneralError, "$ZF(-100) openssl refused: " _ tEx.DisplayString())
    }
    ; A class whose OnBeforeAllTests fails never reaches its OnAfterAllTests, so a failed run removes
    ; its own directory here.
    If $$$ISERR(tSC) Do ..Discard(pDirectory)
    Quit tSC
}

/// <p>Forget the material and delete <var>pDirectory</var>, a directory <method>Generate</method>
/// made; answer an error when the directory survives.</p>
ClassMethod Discard(pDirectory As %String) As %Status
{
    Kill ^||OcuPilotX509Material
    If pDirectory = "" Quit $$$OK
    Set tRoot = ##class(%File).NormalizeDirectory(##class(%SYS.System).TempDirectory())
    If ($Extract(pDirectory, 1, $Length(tRoot)) '= tRoot) || (pDirectory '[ ..#PREFIX) {
        Quit $$$ERROR($$$GeneralError, "refusing to delete " _ pDirectory _ ", which X509Material did not make")
    }
    Do ##class(%File).RemoveDirectoryTree(pDirectory)
    If ##class(%File).DirectoryExists(pDirectory) {
        Quit $$$ERROR($$$GeneralError, "the X.509 test material directory " _ pDirectory _ " survived its removal")
    }
    Quit $$$OK
}

/// <p>The PEM text of the block named <var>pName</var> (a name in <parameter>FILES</parameter>),
/// lines separated by a line feed and none leading or trailing, or <code>""</code> before
/// <method>Generate</method>.</p>
ClassMethod Pem(pName As %String) As %String
{
    Quit $Get(^||OcuPilotX509Material(pName))
}

/// <p><var>pPem</var> with every line feed removed, as a password input or the proposal card leaves
/// a pasted block.</p>
ClassMethod Flattened(pPem As %String) As %String
{
    Quit $Translate(pPem, $Char(10) _ $Char(13), "")
}

/// <p>Every block and the password, for a scan that must find none of them.</p>
ClassMethod All() As %DynamicObject
{
    Set tAll = {}
    For tI = 1:1:$Length(..#FILES, ",") {
        Set tName = $Piece($Piece(..#FILES, ",", tI), ":", 1)
        Do tAll.%Set(tName, ..Pem(tName), "string")
    }
    Do tAll.%Set("PrivateKeyPassword", ..#PASSWORD, "string")
    Quit tAll
}

/// <p>The name of the first secret in <var>pSecrets</var> whose text <var>pText</var> carries, or
/// <code>""</code>. A PEM value is looked for by a 48-character slice from the middle of its body,
/// which no other text shares, in <var>pText</var> with its line feeds and JSON line-feed escapes
/// removed; a short value is looked for as it is.</p>
ClassMethod Leak(pText As %String, pSecrets As %DynamicObject) As %String
{
    Set tFound = ""
    Set tText = $Replace($Translate(pText, $Char(10, 13), ""), "\n", "")
    Set tIterator = pSecrets.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If tValue = "" Continue
        Set tFlat = $Translate(tValue, $Char(10, 13), "")
        Set tProbe = $Select($Length(tFlat) > 200: $Extract(tFlat, $Length(tFlat) \ 2, ($Length(tFlat) \ 2) + 47), 1: tFlat)
        If tText [ tProbe Set tFound = tKey Quit
    }
    Quit tFound
}

/// <p>Run <parameter>OPENSSL</parameter> with <var>pArgs</var>, no shell between, its output and
/// errors kept in <var>pDirectory</var>; a non-zero exit is an error naming the subcommand.</p>
ClassMethod Run(pDirectory As %String, pArgs...) As %Status
{
    Set tErrors = pDirectory _ "openssl.err"
    Set tExit = $ZF(-100, "/STDOUT=""" _ pDirectory _ "openssl.out"" /STDERR=""" _ tErrors _ """", ..#OPENSSL, pArgs...)
    If tExit = 0 Quit $$$OK
    Quit $$$ERROR($$$GeneralError, "openssl " _ $Get(pArgs(1)) _ " exited " _ tExit _ ": " _ $Extract($Translate(..ReadText(tErrors), $Char(10), " "), *-399, *))
}

/// <p>The minimal configuration <code>openssl ca</code> needs to sign the expired certificate, and
/// its empty database, in <var>pDirectory</var>.</p>
ClassMethod WriteAuthority(pDirectory As %String) As %Status
{
    Set tIndex = ##class(%File).%New(pDirectory _ "index.txt")
    Set tSC = tIndex.Open("NW")
    If $$$ISERR(tSC) Quit tSC
    Do tIndex.Close()
    For tFile = "serial", "ca.cnf" {
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Set tSC = tStream.LinkToFile(pDirectory _ tFile)
        If $$$ISERR(tSC) Quit
        If tFile = "serial" Do tStream.WriteLine("01")
        If tFile = "ca.cnf" {
            Do tStream.WriteLine("[ca]"), tStream.WriteLine("default_ca=d"), tStream.WriteLine("[d]")
            Do tStream.WriteLine("database=" _ pDirectory _ "index.txt"), tStream.WriteLine("new_certs_dir=" _ pDirectory), tStream.WriteLine("serial=" _ pDirectory _ "serial")
            Do tStream.WriteLine("default_md=sha256"), tStream.WriteLine("policy=p"), tStream.WriteLine("[p]"), tStream.WriteLine("commonName=supplied")
        }
        Set tSC = tStream.%Save()
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>The text of file <var>pFile</var>, carriage returns removed and surrounding white space
/// trimmed, or <code>""</code>.</p>
ClassMethod ReadText(pFile As %String) As %String
{
    Set tText = ""
    Try {
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Set tSC = tStream.LinkToFile(pFile)
        If $$$ISERR(tSC) Quit
        While 'tStream.AtEnd {
            Set tText = tText _ tStream.Read(32000)
        }
    } Catch {
        Set tText = ""
    }
    Quit $ZStrip($Translate(tText, $Char(13), ""), "<>WC")
}

}
