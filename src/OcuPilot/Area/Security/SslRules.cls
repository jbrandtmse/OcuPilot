/// <p>The SSL/TLS configuration form's rules (AD-39, AD-55): the one rule set every caller of
/// <class>OcuPilot.Screen.Tool.SslCreate</class> and <class>OcuPilot.Screen.Tool.SslUpdate</class>
/// applies (<method>Validate</method>), the form's read (<method>HandleForm</method>), the name
/// look-up (<method>HandleName</method>) and Test connection (<method>HandleTest</method>).</p>
/// <p><b>The rules check what the vendor refuses only with a 500</b>, measured on this build, so a
/// refusal lands on its field in OcuPilot's own sentence
/// (<method>OcuPilot.Api.Error.ReasonForViolation</method>) rather than as an internal error. What
/// the vendor alone can judge -- a cipher list that selects nothing, an unknown cipher suite, a
/// password that does not decrypt the key file -- the port maps to the same fields
/// (<parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter>).</p>
/// <p><b>No caller names a file</b> (AD-21): <code>CAFile</code> is none, the operating system's
/// store, or the fresh read's own value unchanged. No sentence here names a path or quotes a
/// password, and the password is read into a local cleared before return (AD-35).</p>
Class OcuPilot.Area.Security.SslRules Extends %RegisteredObject
{

/// <p>The tools the callers resolve the writes through (AD-55): the create for a name look-up, the
/// change for a present configuration's read, whose port is also the test's.</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.SslCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.SslUpdate";

/// <p>The screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SslForm";

/// <p>The fields a create must carry, comma-separated: the name and the three the vendor
/// requires.</p>
Parameter REQUIREDFIELDS = "Name,Type,VerifyPeer,Enabled";

/// <p>The longest values the vendor stores: the <code>MAXLEN</code> of
/// <class>Security.SSLConfigs</class>' <code>Name</code>, <code>Description</code>,
/// <code>CipherList</code>, <code>Ciphersuites</code> and <code>PrivateKeyPassword</code> on this
/// build, and the test host's bound.</p>
Parameter NAMEMAXLENGTH As INTEGER = 64;

Parameter DESCRIPTIONMAXLENGTH As INTEGER = 256;

Parameter CIPHERLISTMAXLENGTH As INTEGER = 4096;

Parameter CIPHERSUITESMAXLENGTH As INTEGER = 128;

Parameter PASSWORDMAXLENGTH As INTEGER = 255;

Parameter HOSTMAXLENGTH As INTEGER = 255;

/// <p>The vendor keyword for the operating system's certificate store, which names no location.</p>
Parameter OSSTORE = "%OSCertificateStore";

/// <p>The values the vendor accepts, each comma-separated.</p>
Parameter TLSVERSIONS = "4,8,16,32";

Parameter DIFFIEHELLMANBITS = "0,512,1024,2048,4096";

Parameter CLIENTVERIFYPEER = "0,1";

Parameter SERVERVERIFYPEER = "0,1,3";

/// <p>The fields the rules read, named once.</p>
Parameter FIELDNAME = "Name";

Parameter FIELDPASSWORD = "PrivateKeyPassword";

/// <p>The twenty-one keys the vendor's <code>GET</code> answers, the form read's
/// <code>configuration</code> exactly: every field of <class>Security.SSLConfigs</class>' template but
/// the private key password, which the read never answers (AD-35).</p>
Parameter CONFIGURATIONFIELDS = "AuthorizeCN,CAFile,CAPath,CertificateFile,CipherList,Ciphersuites,Description,DiffieHellmanBits,Enabled,OCSP,OCSPIssuerCert,OCSPResponseFile,OCSPTimeout,OCSPURL,PrivateKeyFile,PrivateKeyType,TLSMaxVersion,TLSMinVersion,Type,VerifyDepth,VerifyPeer";

/// <p>Every rule an SSL/TLS write applies, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pMode</var> is <code>create</code> or <code>update</code>. A create checks the name
/// <var>pName</var>'s shape and the three fields the vendor requires, and reads the others against
/// the vendor's own defaults (<method>Defaults</method>); an update reads them against its fresh
/// read <var>pFresh</var>. Each field <var>pArgs</var> carries is checked for its own shape, and a
/// rule across fields -- a server's files, peer verification's trusted certificates, the TLS
/// versions' order -- runs when one of its fields is carried, over the state the write would
/// leave. A name's look-up is the caller's.</p>
ClassMethod Validate(pMode As %String, pName As %String, pArgs As %DynamicObject, pFresh As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set tPassword = ""
    Try {
        Set tCreate = (pMode = "create")
        If tCreate Do ..NameViolation(pName, .pViolations)
        If '$IsObject(pArgs) Set pArgs = {}
        Set tFresh = $Select($IsObject(pFresh): pFresh, 1: {})
        Set tBase = $Select(tCreate: ..Defaults(), 1: tFresh)
        If tCreate {
            For tField = "Type", "VerifyPeer", "Enabled" {
                If pArgs.%GetTypeOf(tField) = "unassigned" Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#SSLFIELDREQUIRED)
            }
        }

        If ..Carries(pArgs, "Description") {
            If (pArgs.%GetTypeOf("Description") '= "string") || ($Length(pArgs.%Get("Description")) > ..#DESCRIPTIONMAXLENGTH) Do ..Add(.pViolations, "Description", ##class(OcuPilot.Api.Error).#SSLDESCRIPTIONLENGTH)
        }
        If ..Carries(pArgs, "Enabled") && '..IsFlag(pArgs, "Enabled") Do ..Add(.pViolations, "Enabled", ##class(OcuPilot.Api.Error).#SSLENABLEDSHAPE)

        Set tType = ..Whole(pArgs, "Type")
        If ..Carries(pArgs, "Type") && '$ListFind($ListBuild("0", "1"), tType) Do ..Add(.pViolations, "Type", ##class(OcuPilot.Api.Error).#SSLTYPEVALUE)
        Set tEffectiveType = $Select(..Carries(pArgs, "Type"): tType, 1: ..Whole(tBase, "Type"))
        If ..Carries(pArgs, "Type") && (tType = "1") {
            If ($ZStrip(tFresh.%Get("CertificateFile"), "<>W") = "") || ($ZStrip(tFresh.%Get("PrivateKeyFile"), "<>W") = "") Do ..Add(.pViolations, "Type", ##class(OcuPilot.Api.Error).#SSLTYPESERVERFILES)
        }

        If ..Carries(pArgs, "VerifyPeer") || ..Carries(pArgs, "Type") {
            Set tPeer = $Select(..Carries(pArgs, "VerifyPeer"): ..Whole(pArgs, "VerifyPeer"), 1: ..Whole(tBase, "VerifyPeer"))
            Set tAllowed = $ListFromString($Select(tEffectiveType = "1": ..#SERVERVERIFYPEER, 1: ..#CLIENTVERIFYPEER))
            If '$ListFind(tAllowed, tPeer) Do ..Add(.pViolations, "VerifyPeer", ##class(OcuPilot.Api.Error).#SSLVERIFYPEERVALUE)
        }
        If ..Carries(pArgs, "VerifyDepth") && (..Whole(pArgs, "VerifyDepth") = "") Do ..Add(.pViolations, "VerifyDepth", ##class(OcuPilot.Api.Error).#SSLVERIFYDEPTHSHAPE)

        If ..Carries(pArgs, "CAFile") {
            Set tCAFile = $Select(pArgs.%GetTypeOf("CAFile") = "string": pArgs.%Get("CAFile"), 1: $Char(0))
            If (tCAFile '= "") && (tCAFile '= ..#OSSTORE) && ((tCAFile = $Char(0)) || (tCAFile '= tFresh.%Get("CAFile"))) Do ..Add(.pViolations, "CAFile", ##class(OcuPilot.Api.Error).#SSLCAFILEPATH)
        }
        If ..Carries(pArgs, "VerifyPeer") || ..Carries(pArgs, "CAFile") {
            Set tPeer = $Select(..Carries(pArgs, "VerifyPeer"): ..Whole(pArgs, "VerifyPeer"), 1: ..Whole(tBase, "VerifyPeer"))
            Set tCAFile = $Select(..Carries(pArgs, "CAFile") && (pArgs.%GetTypeOf("CAFile") = "string"): pArgs.%Get("CAFile"), 1: tBase.%Get("CAFile"))
            If (+tPeer > 0) && ($ZStrip(tCAFile, "<>W") = "") && ($ZStrip(tFresh.%Get("CAPath"), "<>W") = "") {
                Do ..Add(.pViolations, $Select(..Carries(pArgs, "VerifyPeer"): "VerifyPeer", 1: "CAFile"), ##class(OcuPilot.Api.Error).#SSLVERIFYPEERCAREQUIRED)
            }
        }

        Set tVersions = $ListFromString(..#TLSVERSIONS)
        Set tMin = $Select(..Carries(pArgs, "TLSMinVersion"): ..Whole(pArgs, "TLSMinVersion"), 1: ..Whole(tBase, "TLSMinVersion"))
        Set tMax = $Select(..Carries(pArgs, "TLSMaxVersion"): ..Whole(pArgs, "TLSMaxVersion"), 1: ..Whole(tBase, "TLSMaxVersion"))
        Set tVersionsValid = 1
        If ..Carries(pArgs, "TLSMinVersion") && '$ListFind(tVersions, tMin) {
            Do ..Add(.pViolations, "TLSMinVersion", ##class(OcuPilot.Api.Error).#SSLTLSMINVERSIONVALUE)
            Set tVersionsValid = 0
        }
        If ..Carries(pArgs, "TLSMaxVersion") && '$ListFind(tVersions, tMax) {
            Do ..Add(.pViolations, "TLSMaxVersion", ##class(OcuPilot.Api.Error).#SSLTLSMAXVERSIONVALUE)
            Set tVersionsValid = 0
        }
        If tVersionsValid && (..Carries(pArgs, "TLSMinVersion") || ..Carries(pArgs, "TLSMaxVersion")) && (tMin '= "") && (tMax '= "") && (+tMax < +tMin) {
            Do ..Add(.pViolations, "TLSMaxVersion", ##class(OcuPilot.Api.Error).#SSLTLSMAXVERSIONORDER)
        }

        If ..Carries(pArgs, "DiffieHellmanBits") && '$ListFind($ListFromString(..#DIFFIEHELLMANBITS), ..Whole(pArgs, "DiffieHellmanBits")) Do ..Add(.pViolations, "DiffieHellmanBits", ##class(OcuPilot.Api.Error).#SSLDIFFIEHELLMANBITSVALUE)
        If ..Carries(pArgs, "OCSP") && '$ListFind($ListBuild("0", "1"), ..Whole(pArgs, "OCSP")) Do ..Add(.pViolations, "OCSP", ##class(OcuPilot.Api.Error).#SSLOCSPVALUE)
        If ..Carries(pArgs, "OCSPTimeout") && (..Whole(pArgs, "OCSPTimeout") = "") Do ..Add(.pViolations, "OCSPTimeout", ##class(OcuPilot.Api.Error).#SSLOCSPTIMEOUTSHAPE)

        Do ..CipherViolation(pArgs, "CipherList", ..#CIPHERLISTMAXLENGTH, ##class(OcuPilot.Api.Error).#SSLCIPHERLISTSHAPE, ##class(OcuPilot.Api.Error).#SSLCIPHERLISTLENGTH, .pViolations)
        Do ..CipherViolation(pArgs, "Ciphersuites", ..#CIPHERSUITESMAXLENGTH, ##class(OcuPilot.Api.Error).#SSLCIPHERSUITESSHAPE, ##class(OcuPilot.Api.Error).#SSLCIPHERSUITESLENGTH, .pViolations)

        If ..Carries(pArgs, ..#FIELDPASSWORD) {
            If pArgs.%GetTypeOf(..#FIELDPASSWORD) = "string" Set tPassword = pArgs.%Get(..#FIELDPASSWORD)
            If $Length(tPassword) > ..#PASSWORDMAXLENGTH {
                Do ..Add(.pViolations, ..#FIELDPASSWORD, ##class(OcuPilot.Api.Error).#SSLPRIVATEKEYPASSWORDLENGTH)
            } ElseIf (tPassword '= "") && ($ZStrip(tFresh.%Get("PrivateKeyFile"), "<>W") = "") {
                Do ..Add(.pViolations, ..#FIELDPASSWORD, ##class(OcuPilot.Api.Error).#SSLPRIVATEKEYPASSWORDKEYFILE)
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set tPassword = ""
    Quit tSC
}

/// <p>The members of <var>pArgs</var> among the settable fields
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.SslFields</method>) whose value differs from
/// <var>pFresh</var>'s, compared in the diff's rendered form, as a new
/// <class>%DynamicObject</class>. Every carried one is kept when there is no fresh read.</p>
ClassMethod Changed(pArgs As %DynamicObject, pFresh As %DynamicObject = "") As %DynamicObject
{
    Set tChanged = {}
    If '$IsObject(pArgs) Quit tChanged
    Set tFields = ##class(OcuPilot.Kernel.Proposal.Prohibited).SslFields()
    For tI = 1:1:$ListLength(tFields) {
        Set tField = $List(tFields, tI)
        Set tType = pArgs.%GetTypeOf(tField)
        If tType = "unassigned" Continue
        If $IsObject(pFresh) && (pFresh.%GetTypeOf(tField) '= "unassigned") {
            Set tBefore = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField))
            Set tAfter = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pArgs.%Get(tField), tType)
            If tAfter = tBefore Continue
        }
        If (tType = "object") || (tType = "array") {
            Do tChanged.%Set(tField, pArgs.%Get(tField))
        } Else {
            Do tChanged.%Set(tField, pArgs.%Get(tField), tType)
        }
    }
    Quit tChanged
}

/// <p><var>pViolations</var> as one problem sentence naming each field and its published sentence,
/// or <code>""</code> for none: what a tool's <code>ArgumentProblem</code> answers.</p>
ClassMethod Problem(ByRef pViolations) As %String
{
    Set tProblem = ""
    For tI = 1:1:$Get(pViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(pViolations(tI), 2))
        Set tProblem = tProblem _ $Select(tProblem = "": "", 1: " ") _ "'" _ $List(pViolations(tI), 1) _ "': " _ tReason
    }
    Quit tProblem
}

/// <p>Add the name's own violation to <var>pViolations</var>, or none: an absent name, and one longer
/// than <parameter>NAMEMAXLENGTH</parameter> or carrying a control character, a slash or a
/// backslash. A name is compared exactly, case included, so nothing here folds it.</p>
ClassMethod NameViolation(pName As %String, Output pViolations)
{
    If pName = "" {
        Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#SSLNAMEREQUIRED)
        Quit
    }
    Set tUsable = ($Length(pName) <= ..#NAMEMAXLENGTH) && '(pName [ "/") && '(pName [ "\")
    For tI = 1:1:$Length(pName) {
        Set tCode = $Ascii(pName, tI)
        If (tCode < 32) || (tCode = 127) Set tUsable = 0 Quit
    }
    If 'tUsable Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.Error).#SSLNAMESHAPE)
}

/// <p>The vendor's own initial value of each settable field
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.SslFields</method>), read from a
/// <class>Security.SSLConfigs</class> <code>%New()</code> in <code>%SYS</code> (AD-16) and typed as
/// the vendor's read answers it: the cipher lists as arrays, <code>Enabled</code> a boolean and the
/// numbers numbers. Nothing is saved.</p>
ClassMethod Defaults() As %DynamicObject
{
    Set tDefaults = {}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tNew = ##class(Security.SSLConfigs).%New()
        Set tValues("Description") = tNew.Description
        Set tValues("Enabled") = tNew.Enabled
        Set tValues("CAFile") = tNew.CAFile
        Set tValues("CipherList") = tNew.CipherList
        Set tValues("Ciphersuites") = tNew.Ciphersuites
        For tField = "Type", "VerifyPeer", "VerifyDepth", "TLSMinVersion", "TLSMaxVersion", "DiffieHellmanBits", "OCSP", "OCSPTimeout" {
            Set tValues(tField) = $Property(tNew, tField)
        }
        Set tNew = ""
        Set $NAMESPACE = tOrigNS
        Do tDefaults.%Set("Description", tValues("Description"), "string")
        Do tDefaults.%Set("Enabled", ''tValues("Enabled"), "boolean")
        For tField = "Type", "VerifyPeer", "VerifyDepth" {
            Do tDefaults.%Set(tField, +tValues(tField), "number")
        }
        Do tDefaults.%Set("CAFile", tValues("CAFile"), "string")
        For tField = "TLSMinVersion", "TLSMaxVersion", "DiffieHellmanBits", "OCSP", "OCSPTimeout" {
            Do tDefaults.%Set(tField, +tValues(tField), "number")
        }
        For tField = "CipherList", "Ciphersuites" {
            Set tList = []
            For tI = 1:1:$Length(tValues(tField), ":") {
                Set tEntry = $Piece(tValues(tField), ":", tI)
                If tEntry '= "" Do tList.%Push(tEntry, "string")
            }
            Do tDefaults.%Set(tField, tList)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tDefaults = {}
    }
    Quit tDefaults
}

/// <p>Answer <code>GET /ssl/form[?name=&lt;n&gt;]</code>: everything the form needs before it can
/// draw a field (AD-39): <code>{requiredFields, maxLengths, rules, defaults}</code>, the defaults
/// being <method>Defaults</method>. With a name it adds <code>name</code>,
/// <code>configuration</code> -- the vendor <code>GET</code>'s twenty-one keys
/// (<parameter>CONFIGURATIONFIELDS</parameter>), read through the change tool's own port, which
/// never answers the private key password -- and <code>ocupilot</code>, whether it is OcuPilot's own
/// provider configuration. A name this instance does not hold is 404
/// <parameter>OcuPilot.Api.Error.SSLNAMEABSENT</parameter>.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tBody = {}
        Set tRequired = []
        For tI = 1:1:$Length(..#REQUIREDFIELDS, ",") Do tRequired.%Push($Piece(..#REQUIREDFIELDS, ",", tI))
        Do tBody.%Set("requiredFields", tRequired)
        Set tLengths = {}
        Do tLengths.%Set(..#FIELDNAME, ..#NAMEMAXLENGTH, "number")
        Do tLengths.%Set("Description", ..#DESCRIPTIONMAXLENGTH, "number")
        Do tLengths.%Set(..#FIELDPASSWORD, ..#PASSWORDMAXLENGTH, "number")
        Do tLengths.%Set("Host", ..#HOSTMAXLENGTH, "number")
        Do tBody.%Set("maxLengths", tLengths)
        Do tBody.%Set("rules", ..Rules())
        Do tBody.%Set("defaults", ..Defaults())
        Set tName = $Get(%request.Data("name", 1))
        If tName '= "" {
            Set tReadSC = ..Present(tName, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, tHttp, tFault)
                Quit
            }
            Do tBody.%Set("name", tName, "string")
            Do tBody.%Set("configuration", ..Configuration(tFresh))
            Do tBody.%Set("ocupilot", (tName = ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG), "boolean")
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p><var>pFresh</var> projected to <parameter>CONFIGURATIONFIELDS</parameter>, each in the type
/// the vendor answered it in: the form read's <code>configuration</code>.</p>
ClassMethod Configuration(pFresh As %DynamicObject) As %DynamicObject
{
    Set tOut = {}
    For tI = 1:1:$Length(..#CONFIGURATIONFIELDS, ",") {
        Set tField = $Piece(..#CONFIGURATIONFIELDS, ",", tI)
        Set tType = pFresh.%GetTypeOf(tField)
        If tType = "unassigned" Continue
        If (tType = "object") || (tType = "array") {
            Do tOut.%Set(tField, pFresh.%Get(tField))
        } Else {
            Do tOut.%Set(tField, pFresh.%Get(tField), tType)
        }
    }
    Quit tOut
}

/// <p>Answer <code>GET /ssl/name?name=&lt;n&gt;</code>: whether that name is taken, in
/// <code>{name, taken, reason}</code>. A look-up that cannot be made is a refusal envelope, never an
/// assertion that the name is free.</p>
ClassMethod HandleName() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tName = $Get(%request.Data("name", 1))
        If tName = "" {
            Set tSC = ##class(OcuPilot.Area.Security.SslSave).RenderOne(..#FIELDNAME, ##class(OcuPilot.Api.Error).#SSLNAMEREQUIRED)
            Quit
        }
        Set tTakenSC = ..Taken(tName, .tTaken)
        If $$$ISERR(tTakenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tTakenSC))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("name", tName, "string")
        Do tBody.%Set("taken", tTaken, "boolean")
        Do tBody.%Set("reason", $Select(tTaken: ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#SSLNAMETAKEN), 1: ""), "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>POST /ssl/:id/test</code>: test the saved configuration <var>pId</var> -- one path
/// segment, decoded once here (AD-13) -- against the body's <code>{Host, Port}</code>, and answer
/// <code>{passed, lines}</code> with 200, pass or fail
/// (<parameter>OcuPilot.Port.AdminPort.CONNECTIONTESTTYPES</parameter>).</p>
/// <p><b>Screen-only</b> (AD-39's named exception): no tool issues it, and its lines are answered to
/// this request and written nowhere else -- no log line, ledger row, audit payload, screen context or
/// tool result. A broken host or port is one 422 envelope; a configuration the instance does not
/// hold is 404 <parameter>OcuPilot.Api.Error.SSLNAMEABSENT</parameter>.</p>
ClassMethod HandleTest(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) || '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tName = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tTestSC = ..Test(tName, tBody, .tResult, .tHttp, .tFault, .tViolations)
        If $Get(tViolations) > 0 {
            Set tSC = ##class(OcuPilot.Area.Security.SslSave).RenderViolations(.tViolations)
            Quit
        }
        If $$$ISERR(tTestSC) {
            Set tSC = ..RenderRead(tTestSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tResult)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Test the configuration <var>pName</var> against <var>pBody</var>'s <code>Host</code> and
/// <code>Port</code> through the change tool's own port, answering <code>{passed, lines}</code> in
/// <var>pResult</var>.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array; a non-zero count means
/// nothing was tested. Otherwise an error status carries <var>pHttpStatus</var> and
/// <var>pFault</var>, 404 for a configuration the instance does not hold.</p>
ClassMethod Test(pName As %String, pBody As %DynamicObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pViolations
    Set pViolations = 0
    Set tHost = ""
    If pBody.%GetTypeOf("Host") = "string" Set tHost = pBody.%Get("Host")
    Set tHostUsable = (tHost '= "") && ($Length(tHost) <= ..#HOSTMAXLENGTH) && '(tHost [ "://")
    For tI = 1:1:$Length(tHost) {
        Set tCode = $Ascii(tHost, tI)
        If (tCode <= 32) || (tCode = 127) Set tHostUsable = 0 Quit
    }
    If 'tHostUsable Do ..Add(.pViolations, "Host", ##class(OcuPilot.Api.Error).#SSLTESTHOST)
    Set tPort = ..Whole(pBody, "Port")
    If (tPort = "") || (+tPort < 1) || (+tPort > 65535) Do ..Add(.pViolations, "Port", ##class(OcuPilot.Api.Error).#SSLTESTPORT)
    If pViolations > 0 Quit $$$OK
    Kill tQuery
    Set tQuery($ClassMethod(..#UPDATETOOL, "IdParam")) = pName
    Set tRequest = {}
    Do tRequest.%Set("Host", tHost, "string")
    Do tRequest.%Set("Port", +tPort, "number")
    Quit $ClassMethod($ClassMethod(..#UPDATETOOL, "PortClass"), "Invoke", $ClassMethod(..#UPDATETOOL, "Endpoint"), "TEST", .tQuery, tRequest, .pResult, .pHttpStatus, .pFault)
}

/// <p>Whether a configuration already carries <var>pName</var>, in <var>pTaken</var>, read through
/// the create tool's own port, endpoint and read type (AD-52). The vendor opens a name exactly, case
/// included.</p>
/// <p><b>Caller contract:</b> an error status means the question was not answered; only a 404 is
/// "free".</p>
ClassMethod Taken(pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Set tSC = ..Read(..#CREATETOOL, pName, .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) = 404 Quit $$$OK
        Quit tSC
    }
    Set pTaken = ($IsObject(tFresh) && tFresh.%IsA("%Library.DynamicObject"))
    Quit $$$OK
}

/// <p>The present configuration <var>pName</var>, read through the change tool's own port, endpoint
/// and read type (AD-52), in <var>pFresh</var>. An absent one is an error status with
/// <var>pHttpStatus</var> 404.</p>
ClassMethod Present(pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ..Read(..#UPDATETOOL, pName, .pFresh, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#SSLNAMEABSENT)
    }
    Quit tSC
}

/// <p>Render a failed read or test: a 404 as <parameter>OcuPilot.Api.Error.SSLNAMEABSENT</parameter>,
/// any other refusal as the port's own envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONSSLNAMEABSENT, ##class(OcuPilot.Api.Error).#SSLNAMEABSENT)
    }
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Read <var>pName</var> through tool <var>pToolClass</var>'s own port, endpoint and read
/// type.</p>
ClassMethod Read(pToolClass As %String, pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pFresh = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "IdParam")) = pName
        Set tSC = $ClassMethod($ClassMethod(pToolClass, "PortClass"), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    } Catch ex {
        Set pFresh = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every rule this form applies, as <code>[{field, code, reason}]</code>. The sentences are
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s; a code with no single field is
/// absent.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = ##class(OcuPilot.Api.Error).SslViolationCodes()
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tField = ..FieldOf(tCode)
        If tField = "" Continue
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        If tReason = "" Continue
        Set tRow = {}
        Do tRow.%Set("field", tField, "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", tReason, "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>The form field an <code>SSL.&lt;FIELD&gt;.&lt;RULE&gt;</code> code refuses, or
/// <code>""</code> for a code that refuses no one field.</p>
ClassMethod FieldOf(pCode As %String) As %String [ Private ]
{
    Set tPart = $Piece(pCode, ".", 2)
    Set tFields = "Name,Description,Enabled,Type,VerifyPeer,VerifyDepth,CAFile,TLSMinVersion,TLSMaxVersion,DiffieHellmanBits,CipherList,Ciphersuites,OCSP,OCSPTimeout,PrivateKeyPassword,Host,Port"
    For tI = 1:1:$Length(tFields, ",") {
        Set tField = $Piece(tFields, ",", tI)
        If $ZConvert(tField, "U") = tPart Quit
        Set tField = ""
    }
    If tPart = "TEST" Set tField = $Select($Piece(pCode, ".", 3) = "HOST": "Host", 1: "Port")
    Quit tField
}

/// <p>Refuse a caller who does not hold the form's declared pairs (AD-8): <var>pRefused</var> 1
/// means the envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>Whether <var>pArgs</var> carries <var>pField</var>.</p>
ClassMethod Carries(pArgs As %DynamicObject, pField As %String) As %Boolean [ Private ]
{
    Quit (pArgs.%GetTypeOf(pField) '= "unassigned")
}

/// <p><var>pObject</var>'s <var>pField</var> as a plain whole number of 0 or more, or
/// <code>""</code> when it is absent or anything else: a JSON number, or a string of digits.</p>
ClassMethod Whole(pObject As %DynamicObject, pField As %String) As %String [ Private ]
{
    If '$IsObject(pObject) Quit ""
    Set tType = pObject.%GetTypeOf(pField)
    If (tType '= "number") && (tType '= "string") Quit ""
    Set tValue = pObject.%Get(pField)
    If '$Match(tValue, "^[0-9]+$") Quit ""
    Quit (+tValue) _ ""
}

/// <p>Whether <var>pObject</var>'s <var>pField</var> is a boolean, or the number 0 or 1.</p>
ClassMethod IsFlag(pObject As %DynamicObject, pField As %String) As %Boolean [ Private ]
{
    Set tType = pObject.%GetTypeOf(pField)
    If tType = "boolean" Quit 1
    If tType = "number" Quit $ListFind($ListBuild("0", "1"), pObject.%Get(pField) _ "") > 0
    Quit 0
}

/// <p>Add <var>pField</var>'s cipher-list violation to <var>pViolations</var>, or none: a value that
/// is not an array of non-empty strings free of colons and white space is <var>pShape</var>, and one
/// whose entries joined with colons are longer than <var>pMax</var> is <var>pLength</var>.</p>
ClassMethod CipherViolation(pArgs As %DynamicObject, pField As %String, pMax As %Integer, pShape As %String, pLength As %String, ByRef pViolations) [ Private ]
{
    If '..Carries(pArgs, pField) Quit
    If pArgs.%GetTypeOf(pField) '= "array" {
        Do ..Add(.pViolations, pField, pShape)
        Quit
    }
    Set tJoined = ""
    Set tShape = 1
    Set tIterator = pArgs.%Get(pField).%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry, .tType) {
        If (tType '= "string") || (tEntry = "") || (tEntry [ ":") || ($ZStrip(tEntry, "*W") '= tEntry) || ($ZStrip(tEntry, "*C") '= tEntry) {
            Set tShape = 0
            Quit
        }
        Set tJoined = tJoined _ $Select(tJoined = "": "", 1: ":") _ tEntry
    }
    If 'tShape {
        Do ..Add(.pViolations, pField, pShape)
        Quit
    }
    If $Length(tJoined) > pMax Do ..Add(.pViolations, pField, pLength)
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
