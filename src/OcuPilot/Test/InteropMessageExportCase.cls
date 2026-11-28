/// <p>What Story 24.16 Batch 3's armed export suites share, beyond <class>OcuPilot.Test.InteropSuspendedCase</class> (the HTTP and port calls, the governance key a test turns
/// on, the fake gate, the proposal sweep): the Messages screen's review and action, the export's port call, the classic export as the oracle the bytes are compared with, the
/// audit rows an export leaves, and the sweep of OcuPilot's own stored state for a body's text. The probe messages are <class>OcuPilot.Test.InteropMessageExportFixture</class>'s,
/// removed from both namespaces before and after every test and asserted gone. <b>No production is started</b>: an export reads stored messages.</p>
/// <p><b>Not run itself</b>: it declares no test.</p>
Class OcuPilot.Test.InteropMessageExportCase Extends OcuPilot.Test.InteropSuspendedCase [ Abstract ]
{

Parameter SEAM = "OcuPilot.Test.InteropExportSeam";

Parameter EXPORTFIXTURE = "OcuPilot.Test.InteropMessageExportFixture";

Parameter ENDPOINT = "Messages";

Parameter SCREEN = "/screens/interop.messages";

Parameter EXPORTKEY = "interop.messages.export";

Parameter EXPORTTOOL = "OcuPilot.Screen.Tool.InteropMessageExport";

/// <p>The classic export dialog's name for the file it writes, and the key it names it by.</p>
Parameter ORACLEDOC = "probe2416.txt";

Parameter ORACLEKEY = "oracle2416";

/// <p>The arming check, then the probes of both namespaces removed. No probe production is compiled or started.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, ..%ClassName(1) _ " stores probe messages in USER and HSCUSTOM and reads them through the instance's own accounts, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Do $ClassMethod(..#EXPORTFIXTURE, "DropProbes")
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Set ..PreparedPolicyTaken = 0
    Set tSC = $$$OK
    If '$ClassMethod(..#EXPORTFIXTURE, "DropProbes") Set tSC = $$$ERROR($$$GeneralError, ..%ClassName(1) _ " found probe messages in USER or HSCUSTOM before a test")
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    If ..PreparedPolicyTaken {
        Kill tPolicy
        Merge tPolicy = ..PreparedPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
        Set ..PreparedPolicyTaken = 0
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Do $$$AssertTrue($ClassMethod(..#EXPORTFIXTURE, "DropProbes"), "the probe headers and bodies of USER and HSCUSTOM are removed after the test")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Quit $Select($ClassMethod(..#EXPORTFIXTURE, "DropProbes"): $$$OK, 1: $$$ERROR($$$GeneralError, ..%ClassName(1) _ " left probe messages in USER or HSCUSTOM"))
}

/// <p>The person's review of an export of the set <var>pSet</var> (<code>POST /dryrun</code>), with the separator and character set when they are not empty:
/// <code>status code</code>.</p>
ClassMethod ExportDry(pSet As %String, Output pAnswer, pSeparator As %String = "", pCharset As %String = "") As %String
{
    Set tBody = {}
    Do tBody.%Set("action", "export", "string")
    Do tBody.%Set("id", pSet, "string")
    Set tValues = {}
    If pSeparator '= "" Do tValues.%Set("Separator", pSeparator, "string")
    If pCharset '= "" Do tValues.%Set("Charset", pCharset, "string")
    Do tBody.%Set("values", tValues)
    Quit ..Post(..#SCREEN _ "/dryrun", tBody, .pAnswer)
}

/// <p>The person's export of <var>pSet</var> carrying the digest <var>pReviewed</var>, the separator and the character set (<code>POST /action</code>): <code>status code</code>.</p>
ClassMethod ExportSend(pSet As %String, pReviewed As %String, Output pAnswer, pSeparator As %String = "", pCharset As %String = "") As %String
{
    Set tBody = {}
    Do tBody.%Set("action", "export", "string")
    Do tBody.%Set("id", pSet, "string")
    Set tValues = {}
    Do tValues.%Set("Reviewed", pReviewed, "string")
    If pSeparator '= "" Do tValues.%Set("Separator", pSeparator, "string")
    If pCharset '= "" Do tValues.%Set("Charset", pCharset, "string")
    Do tBody.%Set("values", tValues)
    Quit ..Post(..#SCREEN _ "/action", tBody, .pAnswer)
}

/// <p>The person's whole export of <var>pSet</var>: the review, then the action carrying its digest. <code>status code</code> of the action in the answer <var>pAnswer</var>; the review's in <var>pDry</var>.</p>
ClassMethod ExportThrough(pSet As %String, Output pAnswer, pSeparator As %String = "", pCharset As %String = "", Output pDry) As %String
{
    Set tCode = ..ExportDry(pSet, .pDry, pSeparator, pCharset)
    If tCode '= "200 " Quit tCode
    Quit ..ExportSend(pSet, ..Digest(pDry), .pAnswer, pSeparator, pCharset)
}

/// <p>The export call <var>pType</var> (<code>EXPORT</code>, <code>EXPORTMESSAGES</code> or <code>EXPORTCHOICES</code>) of the port as the running account over the ids <var>pId</var> in
/// <var>pNamespace</var>, with the digest, separator, character set and composing action when they are not empty: <code>status code</code>, the answer in <var>pResult</var> and the fault in
/// <var>pFault</var>. <var>pPort</var> names the class that serves it (a seam, to hold the gate's pairs or fail a render).</p>
ClassMethod XPort(pType As %String, pId As %String, Output pResult, pReviewed As %String = "", pSeparator As %String = "", pCharset As %String = "", pAction As %String = "", Output pFault, pNamespace As %String = {..#NAMESPACE}, pPort As %String = {..#PORT}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    If pId '= "" Set tQuery("id") = pId
    If pReviewed '= "" Set tQuery("digest") = pReviewed
    If pSeparator '= "" Set tQuery("separator") = pSeparator
    If pCharset '= "" Set tQuery("charset") = pCharset
    If pAction '= "" Set tQuery("action") = pAction
    Set pResult = ""
    Set pFault = ""
    Set tSC = $ClassMethod(pPort, "Invoke", ..#ENDPOINT, pType, .tQuery, "", .pResult, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>Hold, for the fake gate, the pairs of a principal who exports messages: the Interoperability menu's, the message viewer's, the export dialog's, the Contents pane's and READ on
/// <code>USER</code>'s database (and not WRITE).</p>
ClassMethod HoldForExport()
{
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_MessageHeader", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_MessageExport", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_MessageContent", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
}

/// <p>The bytes of the file an export answer <var>pAnswer</var> carries as <code>output.file</code> (a confirm's or an action's answer), or the port's result's <code>File</code>:
/// <code>&lt;none&gt;</code> for an answer that carries none.</p>
ClassMethod BytesOf(pAnswer) As %String
{
    If '$IsObject(pAnswer) Quit "<none>"
    Set tFile = ""
    If $IsObject(pAnswer.%Get("output")) && (pAnswer.output.%GetTypeOf("file") = "string") {
        Set tFile = pAnswer.output.%Get("file")
    } ElseIf pAnswer.%GetTypeOf("File") = "string" {
        Set tFile = pAnswer.%Get("File")
    }
    Quit $Select(tFile = "": "<none>", 1: $System.Encryption.Base64Decode(tFile))
}

/// <p>What the instance's own entries in the temporary directory read now, as one line of names, for an assertion that an export left no file or directory there.</p>
ClassMethod TempListing() As %String
{
    Set tProbe = ##class(%File).TempFilename("txt")
    Set tDirectory = ##class(%File).GetDirectory(tProbe)
    Do ##class(%File).Delete(tProbe)
    Set tText = ""
    Set tRS = ##class(%ResultSet).%New("%File:FileSet")
    Set tSC = tRS.Execute(tDirectory, "*", "Name")
    While $$$ISOK(tSC) && tRS.Next() {
        Set tText = tText _ "|" _ tRS.Get("Name")
    }
    Quit tText
}

/// <p>The bytes the classic export (<class>EnsPortal.Dialog.ExportMessages</class>) writes for the message ids <var>pIds</var> (comma-separated digits) of <var>pNamespace</var> with the
/// character set <var>pCharset</var> and the separator <var>pSeparator</var>: the oracle the tests compare an export with. It writes its file to the instance's temporary directory
/// and a log line for each message, which are both removed here.</p>
ClassMethod Oracle(pIds As %String, pCharset As %String, pSeparator As %String, pNamespace As %String = {..#NAMESPACE}) As %String
{
    Set tBytes = "<unread>"
    If '$Match(pIds, "^[0-9]+(,[0-9]+)*$") Quit tBytes
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%ResultSet).%New("%DynamicQuery:SQL")
        Set tSC = tRS.Prepare("SELECT ID FROM Ens.MessageHeader WHERE ID IN (" _ pIds _ ") ORDER BY ID")
        If $$$ISOK(tSC) Set tSC = tRS.Execute()
        Set tFile = ##class(EnsPortal.Dialog.ExportMessages).tempServerFilename(..#ORACLEDOC, ..#ORACLEKEY)
        If ##class(%File).Exists(tFile) Do ##class(%File).Delete(tFile)
        If $$$ISOK(tSC) Do ##class(EnsPortal.Dialog.ExportMessages).CreateTempFile(..#ORACLEDOC, ..#ORACLEKEY, pCharset, pSeparator, tRS)
        If ##class(%File).Exists(tFile) {
            Set tStream = ##class(%Stream.FileBinary).%New()
            Set tSC = tStream.LinkToFile(tFile)
            Set tBytes = tStream.Read(3000000)
            Set tStream = ""
            Do ##class(%File).Delete(tFile)
        }
        Set tDelete = ##class(%SQL.Statement).%ExecDirectNoPriv(, "DELETE FROM Ens_Util.Log WHERE Text LIKE 'Attempting % export with buffer size%'")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tBytes = "<unread>"
    }
    Quit tBytes
}

/// <p>How many <code>%Ensemble/%Message/ViewContents</code> rows since <var>pSince</var> name the header <var>pId</var>, with the last row's description in <var>pDescription</var>.</p>
ClassMethod Views(pSince As %String, pId As %String, Output pDescription As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ViewContents", "MessageHeaderId = " _ pId _ ",", .tData, "", "%Ensemble", "%Message", .pDescription)
}

/// <p>The text of the stored state OcuPilot keeps for proposals, turns and the ledger that holds <var>pSentinel</var>, as the names of the globals that do (<code>none</code> for no one):
/// every global of the install namespace whose name begins <code>OcuPilot.Kernel.State</code> is read.</p>
ClassMethod StateHolding(pSentinel As %String) As %String
{
    Set tFound = ""
    Set tRS = ##class(%ResultSet).%New("%SYS.GlobalQuery:NameSpaceList")
    Set tSC = tRS.Execute($NAMESPACE, "OcuPilot.Kernel.State.*", 1)
    If $$$ISERR(tSC) Quit "unread"
    While tRS.Next() {
        Set tName = "^" _ tRS.Get("Name")
        Set tRef = tName
        Set tLength = $Length(tName)
        If $Get(@tRef) [ pSentinel Set tFound = tFound _ $Select(tFound = "": "", 1: ",") _ tName
        Set tRef = $Query(@tRef)
        While tRef '= "" {
            If $Extract(tRef, 1, tLength) '= tName Quit
            If $Get(@tRef) [ pSentinel Set tFound = tFound _ $Select(tFound = "": "", 1: ",") _ tName Quit
            Set tRef = $Query(@tRef)
        }
    }
    Quit $Select(tFound = "": "none", 1: tFound)
}

/// <p>The port's own fault log, read from the seam: every line kept since <method>OcuPilot.Test.InteropSuspendedSeam.Disarm</method>.</p>
ClassMethod LoggedLines() As %String
{
    Quit $ClassMethod(..#SEAM, "LoggedText")
}

}
