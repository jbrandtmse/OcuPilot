/// <p>The Resources list's export and import port (AD-21's sixth case, AD-29, AD-51, AD-52): resources written to a server file, and the
/// resources of a file or of a screen's local text created or replaced, through the vendor's own
/// <parameter>RESOURCECLASS</parameter> <code>Export</code> and <code>Import</code> in <code>%SYS</code> (AD-16), which is what the classic
/// <code>%CSP.UI.Portal.Dialog.ExportResource</code> and the Resources page's import call. It is <class>OcuPilot.Port.AdminPort</class> with
/// one pseudo-endpoint, <parameter>ENDPOINT</parameter>, carried out here; every other call is the admin port's own. It is a sibling of
/// <class>OcuPilot.Port.TaskTransferPort</class> rather than an addition to it: that port is the Task schedule's, with its own pairs.</p>
/// <p><b>The file is never a caller's path</b>. An export takes <code>root</code> and <code>path</code> and resolves them through
/// <method>PathPortClass</method>'s <code>Resolve</code> as an overwriting <code>file</code> (<parameter>EXPORTOVERWRITES</parameter>, a
/// constant), refusing a name whose directory does not exist. An import takes a server file, resolved as a <code>source</code>, or a local
/// file's <code>fileName</code> and <code>content</code>, a screen value never stored or logged. The vendor's import is handed only a temporary
/// file this port names and deletes on every path, written from the text the port reviewed.</p>
/// <p><b>Its own gate comes first</b> (AD-29): <parameter>PAIRS</parameter> in the calling process before any read or vendor call, measured as
/// the vendor's own requirement for both calls; a caller missing one is refused 403 <code>PORT.ACCESSDENIED</code> with
/// <code>detail.failedPair</code>. PathPort's gate still runs inside <code>Resolve</code>.</p>
/// <p><b>An import is reviewed, then made whole</b>. The vendor's preview (<code>Flags</code> 1) answers only a count and accepts a file of
/// the wrong shape, so <method>Review</method> reads the file's resource names itself through <class>%XML.Reader</class>, saving nothing, and
/// asks the vendor's preview for the same count. The write is refused <code>RESOURCEFILE.CHANGED</code> unless the file still yields the reviewed
/// names and digest, and the vendor imports nothing when any resource of the file fails.</p>
/// <p>Seams a test subclass overrides: <method>PathPortClass</method>, <method>VendorExport</method>, <method>VendorImport</method>,
/// <method>TransferParent</method> and <method>TransferName</method>, with the admin port's own <method>HoldsPair</method> and
/// <method>LogFault</method>. Production overrides none of them.</p>
Class OcuPilot.Port.ResourceTransferPort Extends OcuPilot.Port.AdminPort
{

/// <p>The pseudo-endpoint this port carries out itself.</p>
Parameter ENDPOINT = "ResourceTransfer";

/// <p>The port's own pair set, checked in this order before any read or vendor call (AD-29): the vendor's own requirement for
/// <code>Export</code> and <code>Import</code> (measured: <code>%Admin_Secure:USE</code> for the call and <code>%DB_IRISSYS:READ</code> for
/// <code>%SYS</code>).</p>
Parameter PAIRS = "%Admin_Secure:USE,%DB_IRISSYS:READ";

/// <p>The one id an import targets (AD-13), compared without regard to case, and the id that exports every resource.</p>
Parameter IMPORTID = "import";

Parameter ALLID = "*";

/// <p>The read types: the export's target and the import's reviewed file.</p>
Parameter EXPORTSETTYPE = "EXPORTSET";

Parameter IMPORTSETTYPE = "IMPORTSET";

/// <p>The write types.</p>
Parameter EXPORTTYPE = "EXPORT";

Parameter IMPORTTYPE = "IMPORT";

/// <p>The <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> pairs whose vendor call this port composes (AD-51).</p>
Parameter COMPOSEDTYPES = "ResourceTransfer/EXPORT,ResourceTransfer/IMPORT";

/// <p>The query parameters the target, the two file arguments, the local file and the reviewed values travel under.</p>
Parameter IDPARAM = "id";

Parameter ROOTPARAM = "root";

Parameter PATHPARAM = "path";

Parameter FILENAMEPARAM = "fileName";

Parameter CONTENTPARAM = "content";

Parameter NAMESPARAM = "names";

Parameter DIGESTPARAM = "digest";

/// <p>Whether an export replaces a file already at its name: declared by the export itself, never a caller value (AD-21).</p>
Parameter EXPORTOVERWRITES As BOOLEAN = 1;

/// <p>The vendor class, the export file's root element and the element each resource is.</p>
Parameter RESOURCECLASS = "Security.Resources";

Parameter ROOTELEMENT = "ResourcesExport";

Parameter ENTRYELEMENT = "Resources";

/// <p>The most resources a file may hold and an import reviews.</p>
Parameter MAXRESOURCES As INTEGER = 2000;

/// <p>The separator between two names in the reviewed <parameter>NAMESPARAM</parameter>; a resource name holds no comma.</p>
Parameter NAMESEPARATOR = ",";

/// <p>The directory an import's temporary file is made in, under <method>TransferParent</method>.</p>
Parameter TRANSFERDIRECTORY = "ocupilot-resources";

/// <p>The public-permission bits and the letter each stands for, in <code>RWU</code> order.</p>
Parameter LETTERS = "RWU";

/// <p>The admin port's call, except for <parameter>ENDPOINT</parameter>. <parameter>EXPORTSETTYPE</parameter> answers
/// <code>{Name, Count, root, path}</code> for the one resource <parameter>IDPARAM</parameter> names, or for every resource when it is
/// <parameter>ALLID</parameter>, and 404 for a resource the instance does not hold. <parameter>IMPORTSETTYPE</parameter> answers
/// <code>{Names, Digest, Count, Replaces, Entries, root, path, fileName, content}</code> for the file the query names, for the id
/// <parameter>IMPORTID</parameter> and 404 for any other; <code>content</code> is always empty. <parameter>EXPORTTYPE</parameter> and
/// <parameter>IMPORTTYPE</parameter> are <method>Export</method> and <method>Import</method>.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are <method>OcuPilot.Port.AdminPort.Invoke</method>'s. <parameter>ENDPOINT</parameter>
/// takes no body; any other type is 501 <code>PORT.NOTIMPLEMENTED</code>. Must not be called from an escalated frame (AD-9); the caller's
/// namespace is unchanged on return (AD-16).</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pEndpoint '= ..#ENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '..Gate(.tFailedPair) {
            Set tSC = ..GateRefusal(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " " _ pType _ " was given a caller body, and its call is composed by the port", $$$ERROR($$$GeneralError, "a COMPOSEDTYPES pair takes no caller body"), pFault.code)
            Quit
        }
        Set tId = $Get(pQuery(..#IDPARAM))
        If pType = ..#EXPORTSETTYPE {
            Set tSC = ..ExportSet(tId, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#IMPORTSETTYPE {
            Set tSC = ..ImportSet(tId, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#EXPORTTYPE {
            Set tSC = ..Export(tId, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#IMPORTTYPE {
            Set tSC = ..Import(tId, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "This instance does not implement that operation", .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether the calling process holds every pair in <parameter>PAIRS</parameter>, checked in order through
/// <method>OcuPilot.Port.AdminPort.HoldsPair</method>. <var>pFailedPair</var> names the first it lacks, or is <code>""</code>.</p>
ClassMethod Gate(Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    Set tPairs = $ListFromString(..#PAIRS)
    For tI = 1:1:$ListLength(tPairs) {
        If ..HoldsPair($List(tPairs, tI)) Continue
        Set pFailedPair = $List(tPairs, tI)
        Quit
    }
    Quit (pFailedPair = "")
}

/// <p>The export's file for <var>pRoot</var> and <var>pPath</var>, resolved and checked exactly as <method>Export</method> checks it before its
/// vendor call, for a mint that must refuse what the write would: the gate, <method>Locate</method>, and the directory check. Nothing is
/// written.</p>
ClassMethod CheckExport(pRoot As %String, pPath As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '..Gate(.tFailedPair) {
            Set tSC = ..GateRefusal(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ExportFile(pRoot, pPath, .tResolved, .tAbsent, .pHttpStatus, .pFault)
    } Catch ex {
        Set tSC = ..Fail(..#ENDPOINT, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The class <method>Locate</method> resolves through. Overridable so a fixture can observe the resolve; production never overrides
/// it.</p>
ClassMethod PathPortClass() As %String
{
    Quit "OcuPilot.Port.PathPort"
}

/// <p>Resolve <var>pRoot</var> and <var>pPath</var> through <method>PathPortClass</method> (AD-21): as an overwriting <code>file</code> when
/// <var>pExport</var>, else as a <code>source</code>, each refusal on the <code>root</code> or <code>path</code> field. On success
/// <var>pResolved</var> is the path and <var>pAbsent</var> whether no file stood at it.</p>
ClassMethod Locate(pExport As %Boolean, pRoot As %String, pPath As %String, Output pResolved As %String, Output pAbsent As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResolved = ""
    Set pAbsent = 0
    Set tPathPort = ..PathPortClass()
    If pExport {
        Set tSC = $ClassMethod(tPathPort, "Resolve", pRoot, pPath, $Parameter(tPathPort, "KINDFILE"), ..#ROOTPARAM, ..#PATHPARAM, .pResolved, .pHttpStatus, .pFault, ..#EXPORTOVERWRITES)
    } Else {
        Set tSC = $ClassMethod(tPathPort, "Resolve", pRoot, pPath, $Parameter(tPathPort, "KINDSOURCE"), ..#ROOTPARAM, ..#PATHPARAM, .pResolved, .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) {
        Set pResolved = ""
        Quit tSC
    }
    Set pAbsent = '##class(%File).Exists(pResolved)
    Quit tSC
}

/// <p>The export's file: <method>Locate</method>, then <code>TASK.EXPORT.DIRECTORY</code>, 400 with one violation on <code>path</code>, when the
/// resolved name's directory does not exist. A directory is never created.</p>
ClassMethod ExportFile(pRoot As %String, pPath As %String, Output pResolved As %String, Output pAbsent As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..Locate(1, pRoot, pPath, .pResolved, .pAbsent, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '##class(%File).DirectoryExists(##class(%File).GetDirectory(pResolved)) {
        Set pResolved = ""
        Quit ..Violation(##class(OcuPilot.Api.Error).#TASKEXPORTDIRECTORY, ##class(OcuPilot.Api.Error).#REASONTASKEXPORTDIRECTORY, ..#PATHPARAM, .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The export's target: <code>{Name, Count, root, path}</code> at 200. <parameter>ALLID</parameter> counts every resource the instance
/// holds; any other id is one resource, found by <method>Held</method>, and 404 when absent or malformed. <code>root</code> and
/// <code>path</code> are always empty, so the read is one whether or not the query names a file.</p>
ClassMethod ExportSet(pId As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tName = pId
    If pId = ..#ALLID {
        Set tSC = ..Count(.tCount)
        If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    } Else {
        Set tSC = ..Held(pId, .tBits, .tPresent, .tName)
        If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
        If 'tPresent Quit ..Fail(..#ENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
        Set tCount = 1
    }
    Set pResult = {}
    Do pResult.%Set("Name", tName, "string")
    Do pResult.%Set("Count", tCount, "number")
    Do pResult.%Set(..#ROOTPARAM, "", "string")
    Do pResult.%Set(..#PATHPARAM, "", "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Write the resources <var>pId</var> names to the file <var>pQuery</var>'s <code>root</code> and <code>path</code> name, and answer
/// <code>{root, path, Count}</code> at 200. In order: the file is resolved and its directory checked (<method>ExportFile</method>); a resource
/// the instance no longer holds is 404; then <method>VendorExport</method>, which must write the count read. When the vendor call fails, or
/// writes another count, and no file stood at the name when it was resolved, the file now standing there is the call's own and is deleted.</p>
ClassMethod Export(pId As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tRoot = $Get(pQuery(..#ROOTPARAM))
    Set tPath = $Get(pQuery(..#PATHPARAM))
    Set tSC = ..ExportFile(tRoot, tPath, .tResolved, .tAbsent, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ExportSet(pId, .pQuery, .tSet, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pHttpStatus = 0
    Set tVendorSC = $$$OK
    Set tNumber = 0
    Try {
        Set tVendorSC = ..VendorExport(tResolved, pId, .tNumber)
    } Catch ex {
        Set tVendorSC = ex.AsStatus()
    }
    If $$$ISOK(tVendorSC) && (+tNumber '= tSet.%Get("Count")) Set tVendorSC = $$$ERROR($$$GeneralError, "the vendor exported " _ +tNumber _ " resources of " _ tSet.%Get("Count"))
    If $$$ISERR(tVendorSC) {
        If tAbsent && ##class(%File).Exists(tResolved) Do ##class(%File).Delete(tResolved)
        Quit ..Fail(..#ENDPOINT, 500, tVendorSC, .pHttpStatus, .pFault)
    }
    Set pResult = {}
    Do pResult.%Set(..#ROOTPARAM, tRoot, "string")
    Do pResult.%Set(..#PATHPARAM, tPath, "string")
    Do pResult.%Set("Count", +tNumber, "number")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The reviewed file of an import, for the id <var>pId</var>: <code>{Names, Digest, Count, Replaces, Entries, root, path, fileName,
/// content}</code> at 200, with <code>content</code> always empty so the row never holds a local file's text. <code>Entries</code> is each
/// resource of the file as <code>{Name, PublicPermission, Held}</code>, the letters the file gives, and the letters the instance holds or
/// <code>null</code> for a resource it does not. An id other than <parameter>IMPORTID</parameter> is 404.</p>
ClassMethod ImportSet(pId As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If $ZConvert(pId, "L") '= ..#IMPORTID Quit ..Fail(..#ENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    Set tSC = ..ImportText(.pQuery, .tText, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Review(tText, .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Do pResult.%Set(..#ROOTPARAM, $Get(pQuery(..#ROOTPARAM)), "string")
    Do pResult.%Set(..#PATHPARAM, $Get(pQuery(..#PATHPARAM)), "string")
    Do pResult.%Set(..#FILENAMEPARAM, $Get(pQuery(..#FILENAMEPARAM)), "string")
    Do pResult.%Set(..#CONTENTPARAM, "", "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Import the file <var>pQuery</var> names and answer <code>{Count}</code> at 200. In order: the text is read (<method>ImportText</method>)
/// and reviewed (<method>Review</method>); a file that gives one of OcuPilot's own resources a public permission it does not hold is refused as
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ImportedResources</method> refuses it; a reviewed names or digest that is not the file's now is
/// 409 <code>RESOURCEFILE.CHANGED</code>; then <method>SendImport</method>. The vendor must import the reviewed count and every reviewed name
/// must be held after it.</p>
ClassMethod Import(pId As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If $ZConvert(pId, "L") '= ..#IMPORTID Quit ..Fail(..#ENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    Set tSC = ..ImportText(.pQuery, .tText, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Review(tText, .tReview, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tProhibitsSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).ImportedResources(tReview.%Get("Entries"), .tProhibits, .tCode)
    If $$$ISERR(tProhibitsSC) Quit ..Fail(..#ENDPOINT, 500, tProhibitsSC, .pHttpStatus, .pFault)
    If tProhibits Quit ..Refuse(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode), .pHttpStatus, .pFault)
    If '$Data(pQuery(..#NAMESPARAM)) || '$Data(pQuery(..#DIGESTPARAM)) || (pQuery(..#NAMESPARAM) '= tReview.%Get("Names")) || (pQuery(..#DIGESTPARAM) '= tReview.%Get("Digest")) {
        Quit ..Refused(##class(OcuPilot.Api.ResourceFileError).#CHANGED, .pHttpStatus, .pFault)
    }
    Set tNumber = 0
    Set tVendorSC = ..SendImport(tText, .tNumber)
    Set tText = ""
    ; Only the vendor's error numbers are logged: its text quotes the file's values.
    If $$$ISERR(tVendorSC) Quit ..Fail(..#ENDPOINT, 500, $$$ERROR($$$GeneralError, "vendor error " _ $System.Status.GetErrorCodes(tVendorSC)), .pHttpStatus, .pFault)
    If +tNumber '= tReview.%Get("Count") {
        Quit ..Fail(..#ENDPOINT, 500, $$$ERROR($$$GeneralError, "the vendor imported " _ +tNumber _ " resources of " _ tReview.%Get("Count")), .pHttpStatus, .pFault)
    }
    Set tHeldSC = $$$OK
    Set tMissing = 0
    Set tIterator = tReview.%Get("Entries").%GetIterator()
    While tHeldSC && 'tMissing && tIterator.%GetNext(.tIndex, .tEntry) {
        Set tHeldSC = ..Held(tEntry.%Get("Name"), .tBits, .tPresent)
        If $$$ISOK(tHeldSC) && 'tPresent Set tMissing = 1
    }
    If $$$ISERR(tHeldSC) Quit ..Fail(..#ENDPOINT, 500, tHeldSC, .pHttpStatus, .pFault)
    If tMissing Quit ..Fail(..#ENDPOINT, 500, $$$ERROR($$$GeneralError, "an imported resource is not held after the import"), .pHttpStatus, .pFault)
    Set pResult = {}
    Do pResult.%Set("Count", +tNumber, "number")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The text of the file an import names in <var>pQuery</var>, in <var>pText</var>: the server file <parameter>ROOTPARAM</parameter> and
/// <parameter>PATHPARAM</parameter> name, resolved through <method>PathPortClass</method> as a <code>source</code> and read as UTF-8 text, or the
/// local file <parameter>FILENAMEPARAM</parameter> and <parameter>CONTENTPARAM</parameter> send. Refused before any vendor call: 400
/// <code>PORT.VALIDATION</code> when both files or neither is named, or a local file's name is longer than
/// <parameter>OcuPilot.Port.AtelierPort.MAXFILENAME</parameter> or holds <code>/</code>, <code>\</code> or a control character; the resolve's own
/// refusal on its field; and 409 <code>RESOURCEFILE.TOOLARGE</code> for text longer than
/// <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter>.</p>
ClassMethod ImportText(ByRef pQuery, Output pText As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pText = ""
    Set tRoot = $Get(pQuery(..#ROOTPARAM))
    Set tPath = $Get(pQuery(..#PATHPARAM))
    Set tFileName = $Get(pQuery(..#FILENAMEPARAM))
    Set tContent = $Get(pQuery(..#CONTENTPARAM))
    Set tServer = (tRoot '= "") || (tPath '= "")
    Set tLocal = (tFileName '= "") || (tContent '= "")
    If tServer = tLocal Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.InteropPort).#REASONIMPORTSOURCE, .pHttpStatus, .pFault)
    If tLocal {
        If (tFileName = "") || ($Length(tFileName) > ##class(OcuPilot.Port.AtelierPort).#MAXFILENAME) || (tFileName [ "/") || (tFileName [ "\") || ($ZStrip(tFileName, "*C") '= tFileName) {
            Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.InteropPort).#REASONIMPORTFILENAME, .pHttpStatus, .pFault)
        }
        If $Length(tContent) > ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS Quit ..Refused(##class(OcuPilot.Api.ResourceFileError).#TOOLARGE, .pHttpStatus, .pFault)
        Set pText = tContent
        Quit $$$OK
    }
    Set tSC = ..Locate(0, tRoot, tPath, .tResolved, .tAbsent, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Port.AtelierPort).ReadText(tResolved, .pText, .tTooLarge)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    If tTooLarge {
        Set pText = ""
        Quit ..Refused(##class(OcuPilot.Api.ResourceFileError).#TOOLARGE, .pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p>What the import of <var>pText</var> would do, in <var>pReview</var>: <code>{Names, Digest, Count, Replaces, Entries}</code> -- the
/// file's resource names in file order joined by <parameter>NAMESEPARATOR</parameter>, the SHA-256 of its text, how many resources it holds,
/// how many of them the instance already holds, and each resource as <method>ImportSet</method> describes <code>Entries</code>. Refused
/// before any vendor write: 409 <code>RESOURCEFILE.SHAPE</code> for text that is not a resource export (a document type declaration,
/// malformed, another root, no resource, a resource with no usable name or a repeated one, a public permission outside 0 to 7, or a count
/// the vendor's own preview (<code>Flags</code> 1) does not read the same) and 409 <code>RESOURCEFILE.TOOLARGE</code> for more than
/// <parameter>MAXRESOURCES</parameter> resources.</p>
ClassMethod Review(pText As %String, Output pReview As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pReview = ""
    If $Find($ZConvert(pText, "U"), "<!DOCTYPE") Quit ..Refused(##class(OcuPilot.Api.ResourceFileError).#SHAPE, .pHttpStatus, .pFault)
    Set tSC = ..FileEntries(pText, .tRaw, .tReadable)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    If 'tReadable || (tRaw.%Size() = 0) Quit ..Refused(##class(OcuPilot.Api.ResourceFileError).#SHAPE, .pHttpStatus, .pFault)
    If tRaw.%Size() > ..#MAXRESOURCES Quit ..Refused(##class(OcuPilot.Api.ResourceFileError).#TOOLARGE, .pHttpStatus, .pFault)
    Set tEntries = []
    Set tNames = ""
    Set tReplaces = 0
    Kill tSeen
    Set tHeldSC = $$$OK
    Set tIterator = tRaw.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tName = tRow.%Get("Name")
        Kill tViolations
        Do ##class(OcuPilot.Area.Permissions.ResourceRules).NameViolation(tName, .tViolations)
        Set tBits = tRow.%Get("Bits")
        If $Data(tViolations) || $Data(tSeen($ZConvert(tName, "U"))) || '$Match(tBits, "^[0-7]$") {
            Quit
        }
        Set tSeen($ZConvert(tName, "U")) = ""
        Set tHeldSC = ..Held(tName, .tHeldBits, .tPresent)
        If $$$ISERR(tHeldSC) Quit
        Set tEntry = {}
        Do tEntry.%Set("Name", tName, "string")
        Do tEntry.%Set("PublicPermission", ..LettersOf(tBits), "string")
        If tPresent {
            Do tEntry.%Set("Held", ..LettersOf(tHeldBits), "string")
            Set tReplaces = tReplaces + 1
        } Else {
            Do tEntry.%Set("Held", "", "null")
        }
        Do tEntries.%Push(tEntry)
        Set tNames = tNames _ $Select(tNames = "": "", 1: ..#NAMESEPARATOR) _ tName
    }
    If $$$ISERR(tHeldSC) Quit ..Fail(..#ENDPOINT, 500, tHeldSC, .pHttpStatus, .pFault)
    If tEntries.%Size() '= tRaw.%Size() Quit ..Refused(##class(OcuPilot.Api.ResourceFileError).#SHAPE, .pHttpStatus, .pFault)
    Set tPreviewSC = ..SendPreview(pText, .tCounted)
    If $$$ISERR(tPreviewSC) || (+tCounted '= tRaw.%Size()) Quit ..Refused(##class(OcuPilot.Api.ResourceFileError).#SHAPE, .pHttpStatus, .pFault)
    Set tDigest = ..TextDigest(pText)
    If tDigest = "" Quit ..Fail(..#ENDPOINT, 500, $$$ERROR($$$GeneralError, "the import file's digest could not be computed"), .pHttpStatus, .pFault)
    Set pReview = {}
    Do pReview.%Set("Names", tNames, "string")
    Do pReview.%Set("Digest", tDigest, "string")
    Do pReview.%Set("Count", tEntries.%Size(), "number")
    Do pReview.%Set("Replaces", tReplaces, "number")
    Do pReview.%Set("Entries", tEntries)
    Quit $$$OK
}

/// <p>The resources of the export <var>pText</var>, in file order, each <code>{Name, Bits}</code>, read in <code>%SYS</code> (AD-16)
/// through <class>%XML.Reader</class> correlated to <parameter>RESOURCECLASS</parameter>, with external entities resolved to nothing. Nothing is
/// saved. <var>pReadable</var> is 0 for text that does not parse or whose root element is not <parameter>ROOTELEMENT</parameter>. The
/// returned status is an error only when the read could not be made.</p>
ClassMethod FileEntries(pText As %String, Output pEntries As %DynamicArray, Output pReadable As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pEntries = []
    Set pReadable = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tReader = ##class(%XML.Reader).%New()
        Set tReader.EntityResolver = ##class(%XML.SAX.NullEntityResolver).%New()
        Set tOpenSC = tReader.OpenString(pText)
        If $$$ISOK(tOpenSC) && $IsObject(tReader.Document) {
            Set tRoot = tReader.Document.GetDocumentElement()
            If $IsObject(tRoot) && (tRoot.LocalName = ..#ROOTELEMENT) {
                Do tReader.Correlate(..#ENTRYELEMENT, ..#RESOURCECLASS)
                Set tNextSC = $$$OK
                While tReader.Next(.tObject, .tNextSC) {
                    Set tRow = {}
                    Do tRow.%Set("Name", $Property(tObject, "Name") _ "", "string")
                    Do tRow.%Set("Bits", $Property(tObject, "PublicPermission") _ "", "string")
                    Set tObject = ""
                    Do pEntries.%Push(tRow)
                }
                Set pReadable = $$$ISOK(tNextSC)
            }
            Set tRoot = ""
        }
        Do tReader.Close()
        Set tReader = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tObject = ""
        Set tReader = ""
        Set pEntries = []
        Set pReadable = 0
        Set tSC = ex.AsStatus()
    }
    If 'pReadable Set pEntries = []
    Quit tSC
}

/// <p>Whether the instance holds the resource <var>pName</var>, in <var>pPresent</var>, with its public-permission bits in <var>pBits</var>,
/// read in <code>%SYS</code> (AD-16). A name the vendor cannot hold is not present. A failed read is an error, never an absent answer.</p>
ClassMethod Held(pName As %String, Output pBits As %Integer, Output pPresent As %Boolean, Output pCanonical As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pBits = 0
    Set pPresent = 0
    Set pCanonical = pName
    Set tOrigNS = $NAMESPACE
    Try {
        If (pName = "") || ($ZStrip(pName, "*C") '= pName) || (pName [ ",") || ($Length(pName) > 64) Quit
        Set $NAMESPACE = "%SYS"
        Set pPresent = ''##class(Security.Resources).Exists(pName, .tResource)
        If pPresent {
            Set pBits = +tResource.PublicPermission
            Set pCanonical = tResource.Name
            Set tResource = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pPresent = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>How many resources the instance holds, in <var>pCount</var>, from <parameter>RESOURCECLASS</parameter>'s own <code>List</code> query in
/// <code>%SYS</code> (AD-16).</p>
ClassMethod Count(Output pCount As %Integer) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%ResultSet).%New(..#RESOURCECLASS _ ":List")
        Set tSC = tResult.Execute("*", -1, -1)
        If $$$ISOK(tSC) {
            While tResult.Next() {
                Set pCount = pCount + 1
            }
        }
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The letters of the public-permission bits <var>pBits</var>, in <parameter>LETTERS</parameter> order.</p>
ClassMethod LettersOf(pBits As %Integer) As %String
{
    Set tLetters = ""
    For tI = 1:1:3 {
        If $ZBoolean(+pBits, 2 ** (tI - 1), 1) Set tLetters = tLetters _ $Extract(..#LETTERS, tI)
    }
    Quit tLetters
}

/// <p>The SHA-256 of <var>pText</var>'s UTF-8 bytes, as lower-case hex; <code>""</code> when it cannot be computed.</p>
ClassMethod TextDigest(pText As %String) As %String [ Private ]
{
    Set tDigest = ""
    Try {
        Set tBytes = ##class(%Stream.GlobalBinary).%New()
        For tAt = 1:30000:$Length(pText) {
            Do tBytes.Write($ZConvert($Extract(pText, tAt, tAt + 29999), "O", "UTF8"))
        }
        Do tBytes.Rewind()
        Set tHash = $System.Encryption.SHAHashStream(256, tBytes, .tHashSC)
        If $$$ISOK(tHashSC) Set tDigest = $ZConvert(##class(%xsd.hexBinary).LogicalToXSD(tHash), "L")
    } Catch {
        Set tDigest = ""
    }
    Quit tDigest
}

/// <p>The vendor's preview (<code>Flags</code> 1) of <var>pText</var>, written to a temporary file this port names, in <var>pCounted</var>.
/// The file is deleted on every path.</p>
ClassMethod SendPreview(pText As %String, Output pCounted As %Integer) As %Status [ Private ]
{
    Quit ..Transfer(pText, 1, .pCounted)
}

/// <p>The vendor's import of <var>pText</var>, written to a temporary file this port names, in <var>pNumber</var>. The file is deleted on
/// every path.</p>
ClassMethod SendImport(pText As %String, Output pNumber As %Integer) As %Status [ Private ]
{
    Quit ..Transfer(pText, 0, .pNumber)
}

/// <p>Write <var>pText</var> to a temporary file in a directory made for this call and run <method>VendorImport</method> on it with
/// <var>pFlags</var>; the file and its directory are removed on every path.</p>
ClassMethod Transfer(pText As %String, pFlags As %Integer, Output pNumber As %Integer) As %Status [ Private ]
{
    Set tFile = ""
    Set tDirectory = ""
    Set pNumber = 0
    Try {
        Set tSC = ..TransferFile(.tFile, .tDirectory)
        If $$$ISOK(tSC) Set tSC = ..WriteTransferFile(tFile, pText)
        If $$$ISOK(tSC) Set tSC = ..VendorImport(tFile, pFlags, .pNumber)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If tFile '= "" Do ##class(%File).Delete(tFile)
    If tDirectory '= "" Do ##class(%File).RemoveDirectoryTree(tDirectory)
    Quit tSC
}

/// <p>A directory this port makes for one transfer, in <var>pDirectory</var>, and an empty temporary file in it, in <var>pFile</var>. The
/// directory is named <parameter>TRANSFERDIRECTORY</parameter> and <method>TransferName</method> under <method>TransferParent</method>; one
/// already at that name is refused and left as it is.</p>
ClassMethod TransferFile(Output pFile As %String, Output pDirectory As %String) As %Status [ Private ]
{
    Set pFile = ""
    Set pDirectory = ""
    Set tParent = ..TransferParent()
    If tParent = "" Quit $$$ERROR($$$GeneralError, "the resource transfer directory could not be placed")
    Set tDirectory = ##class(%File).NormalizeDirectory(..#TRANSFERDIRECTORY _ "-" _ ..TransferName(), tParent)
    If ##class(%File).DirectoryExists(tDirectory) Quit $$$ERROR($$$GeneralError, "the resource transfer directory is already there")
    If '##class(%File).CreateDirectory(tDirectory) Quit $$$ERROR($$$GeneralError, "the resource transfer directory could not be made")
    Set pDirectory = tDirectory
    Set pFile = ##class(%File).TempFilename("xml", tDirectory)
    If pFile = "" Quit $$$ERROR($$$GeneralError, "the resource transfer file could not be made")
    Quit $$$OK
}

/// <p>The operating system's temporary directory, where each transfer's directory is made; <code>""</code> when it cannot be found.
/// Overridable so a fixture can name its own; production never overrides it.</p>
ClassMethod TransferParent() As %String
{
    Set tProbe = ##class(%File).TempFilename("tmp")
    If tProbe = "" Quit ""
    Set tParent = ##class(%File).GetDirectory(tProbe)
    Do ##class(%File).Delete(tProbe)
    Quit tParent
}

/// <p>The part of a transfer directory's name that is unique to the transfer. Overridable so a fixture can pose a name that is taken;
/// production never overrides it.</p>
ClassMethod TransferName() As %String
{
    Quit $Translate($System.Util.CreateGUID(), "{}", "")
}

/// <p><var>pText</var> written to the file <var>pFile</var> as UTF-8.</p>
ClassMethod WriteTransferFile(pFile As %String, pText As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tFile = ##class(%Stream.FileCharacter).%New()
        Set tFile.TranslateTable = "UTF8"
        Set tSC = tFile.LinkToFile(pFile)
        If $$$ISERR(tSC) Quit
        For tAt = 1:30000:$Length(pText) {
            Set tSC = tFile.Write($Extract(pText, tAt, tAt + 29999))
            If $$$ISERR(tSC) Quit
        }
        If $$$ISOK(tSC) Set tSC = tFile.%Save()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The vendor's export of <var>pNames</var> (<parameter>ALLID</parameter> for every resource) to <var>pFile</var>, in <code>%SYS</code>
/// (AD-16), counting the resources written in <var>pNumber</var>. Overridable so a fixture can observe or deny the call; production never
/// overrides it.</p>
ClassMethod VendorExport(pFile As %String, pNames As %String, Output pNumber As %Integer) As %Status [ Private ]
{
    Set pNumber = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = $ClassMethod(..#RESOURCECLASS, "Export", pFile, .pNumber, pNames, -1, -1)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The vendor's import of <var>pFile</var>, an OcuPilot-named temporary file, with <var>pFlags</var> (1 counts only, 0 imports), in
/// <code>%SYS</code> (AD-16), counting the resources in <var>pNumber</var>. Overridable so a fixture can observe or deny the call;
/// production never overrides it.</p>
ClassMethod VendorImport(pFile As %String, pFlags As %Integer, Output pNumber As %Integer) As %Status [ Private ]
{
    Set pNumber = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = $ClassMethod(..#RESOURCECLASS, "Import", pFile, .pNumber, pFlags)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The 403 the gate answers: the admin port's own mapping of 403, with the pair in <code>detail.failedPair</code> (AD-8, AD-39).</p>
ClassMethod GateRefusal(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("failedPair", pFailedPair, "string")
    Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tVendorText)
    Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, tDetail)
}

/// <p>A 400 refusal on one field, as <var>pCode</var> with its sentence, carried again as that field's one violation (AD-39).</p>
ClassMethod Violation(pCode As %String, pReason As %String, pField As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tViolation = {}
    Do tViolation.%Set("field", pField, "string")
    Do tViolation.%Set("code", pCode, "string")
    Do tViolation.%Set("reason", pReason, "string")
    Set tDetail = {}
    Do tDetail.%Set("violations", [(tViolation)])
    Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, pCode, pReason, .pHttpStatus, .pFault, tDetail)
}

/// <p>The refusal <var>pCode</var> of <class>OcuPilot.Api.ResourceFileError</class>, on the conflict slug and with its sentence. Nothing is
/// logged: a refusal is an answer, not a fault.</p>
ClassMethod Refused(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(##class(OcuPilot.Api.ResourceFileError).HttpStatusFor(pCode), ##class(OcuPilot.Api.Error).#CONFLICT, pCode, ##class(OcuPilot.Api.ResourceFileError).ReasonFor(pCode), .pHttpStatus, .pFault)
}

/// <p>The kind of script step <method>Snippet</method> renders: <code>objectscript</code> for <parameter>ENDPOINT</parameter>, the admin
/// port's answer otherwise.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If pEndpoint = ..#ENDPOINT Quit "objectscript"
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s writes as a script (AD-59), in <code>%SYS</code>: <parameter>EXPORTTYPE</parameter> is the vendor's
/// <code>Export</code> of the target to the file <code>root</code> and <code>path</code> name, and <parameter>IMPORTTYPE</parameter> its
/// <code>Import</code> of that file; an import that names no server file renders no step, since a local file's text is never in a script. A
/// read type writes nothing and answers no step. Every other endpoint is the admin port's script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If pEndpoint '= ..#ENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    Set tFile = ..Literal($Get(pQuery(..#ROOTPARAM)) _ $Get(pQuery(..#PATHPARAM)))
    If pType = ..#EXPORTTYPE {
        Set tLines = $ListBuild("Set tSC = ##class(" _ ..#RESOURCECLASS _ ").Export(" _ tFile _ ", .tNumber, " _ ..Literal($Get(pQuery(..#IDPARAM))) _ ", -1, -1)", "Do $System.Status.DisplayError(tSC)")
        Quit [(..ObjectScriptStep(tLines))]
    }
    If (pType = ..#IMPORTTYPE) && (($Get(pQuery(..#ROOTPARAM)) '= "") || ($Get(pQuery(..#PATHPARAM)) '= "")) {
        Set tLines = $ListBuild("Set tSC = ##class(" _ ..#RESOURCECLASS _ ").Import(" _ tFile _ ", .tNumber, 0)", "Do $System.Status.DisplayError(tSC)")
        Quit [(..ObjectScriptStep(tLines))]
    }
    Quit []
}

}
