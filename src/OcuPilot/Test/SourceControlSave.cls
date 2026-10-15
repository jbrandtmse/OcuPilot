/// <p>Pins Story 20.10's half of a namespace under source control (AD-8, AD-53, AD-61 rules 6 and 8): OcuPilot's own
/// saves, compiles and deletes of classes run the namespace's hooks in the calling process, as the caller, with the
/// caller's <code>%SourceControl</code> unchanged; a document the source-control class has not released for editing is
/// refused 409 <code>EXPLORER.DOCUMENT.SOURCECONTROL</code> by the person's save over HTTP and by the agent's editor
/// save at Confirm, the document unchanged and the vendor's text at information severity; and a hook's own refusal of a
/// save stays 422 <code>EXPLORER.SAVE.REFUSED</code>, logged as a fault.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, a <code>USER</code> namespace that runs interoperability, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because each test puts <code>USER</code> under
/// <class>OcuPilot.Test.SourceControlProbe</class>'s source-control class and takes it away again. It makes its probe
/// documents before it enables the class, removes them after it disables it, asserts that <code>USER</code> then names no
/// source-control class, and snapshots the stored governance policy before each test and puts it back after it.</p>
Class OcuPilot.Test.SourceControlSave Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_NAMESPACE_CONFIG";

Parameter NAMESPACE = "USER";

Parameter SC = "OcuPilot.Test.SourceControlProbe";

Parameter PROBE = "OcuPilot.Test.ExplorerSaveProbe";

Parameter INTEROPPROBE = "OcuPilot.Test.InteropEditorProbe";

Parameter SAVE = "OcuPilot.Test.AtelierPortSave";

Parameter FIXTURE = "OcuPilot.Test.AtelierPortFixture";

/// <p>The probe class every class leg saves.</p>
Parameter ALPHA = "OcuProbe193.Alpha";

/// <p>The package of the probe data transformation the agent's leg edits.</p>
Parameter PACKAGE = "OcuProbe2010Ui";

Parameter EDITTOOL = "interop.transformeditor.save";

/// <p>The hooks a save that compiles runs, in order, with the status checks left out.</p>
Parameter SAVEHOOKS = "OnBeforeSave,OnAfterSave,OnBeforeCompile,OnAfterCompile";

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SourceControlSave puts " _ ..#NAMESPACE _ " under a source-control class and takes it away again, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Set tSC = $ClassMethod(..#SC, "Disable", ..#NAMESPACE)
    If $$$ISERR(tSC) Quit tSC
    Do ..ClearFixtures()
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Remove", ..#NAMESPACE)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#INTEROPPROBE, "Remove", ..#PACKAGE)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#SC, "Disable", ..#NAMESPACE), "the probe's source-control class is taken out of " _ ..#NAMESPACE)
    Do $$$AssertEquals(##class(%Studio.SourceControl.Interface).SourceControlClassGet(..#NAMESPACE), "", ..#NAMESPACE _ " names no source-control class")
    Set tGlobal = $ClassMethod(..#SC, "Global", ..#NAMESPACE)
    Do $$$AssertTrue('$Data(@tGlobal), "the probe's log global is gone")
    Do ..ClearFixtures()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#NAMESPACE), "every probe class is removed")
    Do $$$AssertStatusOK($ClassMethod(..#INTEROPPROBE, "Remove", ..#PACKAGE), "the probe transformation and what it generated are removed")
    Do $$$AssertStatusOK($ClassMethod(..#INTEROPPROBE, "ForgetLedger"), "the ledger rows of the probe turns are removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

Method ClearFixtures()
{
    Do $ClassMethod(..#FIXTURE, "Clear")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>The hook names of <var>pEntries</var> (the probe's log), comma-joined in order, with those in the comma list
/// <var>pOmit</var> left out.</p>
ClassMethod Sequence(pEntries As %DynamicArray, pOmit As %String = "GetStatus") As %String
{
    Set tSequence = ""
    Set tIterator = pEntries.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If $ListFind($ListFromString(pOmit), tEntry.hook) Continue
        Set tSequence = tSequence _ $Select(tSequence = "": "", 1: ",") _ tEntry.hook
    }
    Quit tSequence
}

/// <p>Asserts that every entry of <var>pEntries</var> names document <var>pDocument</var> and was recorded by the
/// process <var>pJob</var> as <var>pUser</var>.</p>
Method AssertCaller(pEntries As %DynamicArray, pDocument As %String, pJob As %String, pUser As %String, pLabel As %String)
{
    Set tWrong = ""
    Set tIterator = pEntries.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If ($ZConvert(tEntry.name, "U") '= $ZConvert(pDocument, "U")) || (tEntry.job '= pJob) || (tEntry.user '= pUser) Set tWrong = tWrong _ " " _ tEntry.%ToJSON()
    }
    Do $$$AssertTrue((pEntries.%Size() > 0) && (tWrong = ""), pLabel _ ": every hook call names " _ pDocument _ " and ran in job " _ pJob _ " as " _ pUser _ ": " _ tWrong)
}

/// <p>Probe class <parameter>ALPHA</parameter>, made before the source-control class is enabled, with its version; then
/// the class enabled and its log cleared.</p>
Method Arm(Output pVersion As %String)
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeClass", ..#NAMESPACE, ..#ALPHA), "a probe class is saved")
    Set pVersion = $ClassMethod(..#PROBE, "Version", ..#NAMESPACE, ..#ALPHA _ ".cls")
    Do $$$AssertStatusOK($ClassMethod(..#SC, "Enable", ..#NAMESPACE), "the probe's source-control class is enabled in " _ ..#NAMESPACE)
    Do $ClassMethod(..#SC, "Clear", ..#NAMESPACE)
}

/// <p>The probe class's stored text.</p>
ClassMethod Source() As %String
{
    Quit $ClassMethod(..#PROBE, "Source", ..#NAMESPACE, ..#ALPHA _ ".cls")
}

/// <p>AC4: the port's save with Compile on runs <code>OnBeforeSave</code>, <code>OnAfterSave</code>,
/// <code>OnBeforeCompile</code> and <code>OnAfterCompile</code> in the calling process, as the caller, after a status
/// check, and the caller's <code>%SourceControl</code> is the object it was before the call.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AtelierPort.SaveSet</method> stores the text with
/// <code>%Compiler.UDL.TextServices.SetTextFromString</code> in place of the put -- the hooks clause goes red. Drop
/// <code>%SourceControl</code> from the <code>New</code> in <method>OcuPilot.Port.AtelierPort.Route</method> -- the
/// <code>%SourceControl</code> clause goes red.</p>
Method TestThePortRunsTheHooksInTheCallersProcess()
{
    Do ..Arm(.tVersion)
    Set tText = $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "2")
    Set tSentinel = {}
    Set %SourceControl = tSentinel
    Do $ClassMethod(..#SAVE, "Save", "Classes", ..#ALPHA _ ".cls", tText, tVersion, 1, .tResult, .tHttp, .tFault)
    Do $$$AssertTrue($IsObject($Get(%SourceControl)) && ($Get(%SourceControl) = tSentinel), "the caller's %SourceControl is the object it was before the call")
    Kill %SourceControl
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tResult)): tResult.errors, 1: ""), "200 0", "the save with Compile on answers 200 and a clean compile: " _ ##class(OcuPilot.Test.AtelierPortSave).Said(.tHttp, .tResult, .tFault))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Source", ..#NAMESPACE, ..#ALPHA _ ".cls"), tText, "the class holds the text")
    Set tEntries = $ClassMethod(..#SC, "Entries", ..#NAMESPACE)
    Do $$$AssertEquals(..Sequence(tEntries), ..#SAVEHOOKS, "the save and compile hooks run once each, in order: " _ tEntries.%ToJSON())
    Do $$$AssertEquals(tEntries.%Get(0).hook, "GetStatus", "after a status check")
    Do ..AssertCaller(tEntries, ..#ALPHA _ ".cls", $Job, $Username, "the port's save")
}

/// <p>AC4: the port's compile runs <code>OnBeforeCompile</code> and <code>OnAfterCompile</code>, and its delete
/// <code>OnBeforeDelete</code> and <code>OnAfterDelete</code>, in the calling process, as the caller; the class is gone
/// after the delete.</p>
/// <p>Mutation (Rule 19): the probe's hooks class records no <code>OnBeforeCompile</code> -- the compile leg goes red; it records no
/// <code>OnBeforeDelete</code> -- the delete leg goes red.</p>
Method TestTheCompileAndDeleteRunTheirHooks()
{
    Do ..Arm(.tVersion)
    Set tName = ..#ALPHA _ ".cls"
    Set tSC = $ClassMethod(..#SAVE, "Act", "Classes", "COMPILE", $ListBuild("names=" _ tName, "KeepSource=1", "CompileDependents=0", "SkipUpToDate=0"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tResult)): tResult.errors, 1: ""), "200 0", "the compile answers 200 and a clean compile: " _ ##class(OcuPilot.Test.AtelierPortSave).Said(.tHttp, .tResult, .tFault))
    Set tEntries = $ClassMethod(..#SC, "Entries", ..#NAMESPACE)
    Do $$$AssertEquals(..Sequence(tEntries), "OnBeforeCompile,OnAfterCompile", "the compile hooks run once each, in order: " _ tEntries.%ToJSON())
    Do ..AssertCaller(tEntries, tName, $Job, $Username, "the port's compile")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Compiled", ..#NAMESPACE, ..#ALPHA), "the class is compiled")
    Do $ClassMethod(..#SC, "Clear", ..#NAMESPACE)
    Set tSC = $ClassMethod(..#SAVE, "Act", "Classes", "DELETE", $ListBuild("names=" _ tName), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the delete answers 200: " _ ##class(OcuPilot.Test.AtelierPortSave).Said(.tHttp, .tResult, .tFault))
    Set tEntries = $ClassMethod(..#SC, "Entries", ..#NAMESPACE)
    Do $$$AssertEquals(..Sequence(tEntries, "GetStatus,UserAction"), "OnBeforeDelete,OnAfterDelete", "the delete hooks run once each, in order: " _ tEntries.%ToJSON())
    Do ..AssertCaller(tEntries, tName, $Job, $Username, "the port's delete")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, tName), "the class is gone")
}

/// <p>The size of the messages log, whose path is <var>pLog</var>.</p>
ClassMethod LogSize(Output pLog As %String) As %Integer
{
    Set pLog = ##class(%File).NormalizeFilename(##class(OcuPilot.Port.LogSourcePort).FileFor("messages"), ##class(OcuPilot.Port.LogSourcePort).ManagerDirectory())
    Quit ##class(%File).GetFileSize(pLog)
}

/// <p>The last line of the log <var>pLog</var>, read from byte <var>pFrom</var> on, that holds
/// <var>pMarker</var>; <code>""</code> when none does.</p>
ClassMethod LogLine(pLog As %String, pFrom As %Integer, pMarker As %String) As %String
{
    Set tLine = ""
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If tStream.LinkToFile(pLog) && (tStream.Size > pFrom) && tStream.MoveTo(pFrom + 1) {
        While 'tStream.AtEnd {
            Set tRead = tStream.ReadLine()
            If tRead [ pMarker Set tLine = tRead
        }
    }
    Quit tLine
}

/// <p>AC5: over the Classes list's route, a save of a class the source-control class has not released is refused 409
/// <code>EXPLORER.DOCUMENT.SOURCECONTROL</code> with the published sentence, before any save hook ran and with the class
/// unchanged, and the vendor's text reaches <code>messages.log</code> at information severity; once the class is released the
/// same save is stored and its save hooks run under the HTTP account, in another process.</p>
/// <p>Mutation (Rule 19): remove the source-control branches from <method>OcuPilot.Port.AtelierPort.Outcome</method> -- the
/// refusal clause goes red, and so do the canned rows of <class>OcuPilot.Test.AtelierPortSave</class>.</p>
Method TestThePersonsSaveIsRefusedByName()
{
    Do ..Arm(.tVersion)
    Set tBefore = ..Source()
    Set tText = $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "2")
    Do $ClassMethod(..#SC, "Refuse", ..#NAMESPACE, ..#ALPHA _ ".cls", 1)
    Set tFrom = ..LogSize(.tLog)
    Do $$$AssertTrue(tFrom >= 0, "the messages log resolves, so its tail can be read: " _ tLog)
    Do ##class(OcuPilot.Test.ExplorerSave).Save("classes", ..#ALPHA _ ".cls", tText, tVersion, "false", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.code _ " " _ tBody.reason, 1: ""), "409 EXPLORER.DOCUMENT.SOURCECONTROL " _ ##class(OcuPilot.Api.AtelierError).#REASONDOCUMENTSOURCECONTROL, "the save is refused with the published sentence: " _ ##class(OcuPilot.Test.ExplorerSave).Json(tBody))
    Do $$$AssertTrue(##class(OcuPilot.Test.ExplorerSave).Json(tBody) '[ "5865", "and the body carries none of the vendor's text: " _ ##class(OcuPilot.Test.ExplorerSave).Json(tBody))
    Do $$$AssertEquals(..Source(), tBefore, "and the class is unchanged")
    Set tEntries = $ClassMethod(..#SC, "Entries", ..#NAMESPACE)
    Do $$$AssertEquals(..Sequence(tEntries, "GetStatus"), "", "no save hook ran: " _ tEntries.%ToJSON())
    Set tLine = ..LogLine(tLog, tFrom, "PutDoc found the document not released for editing by source control")
    Do $$$AssertTrue((tLine [ "#5865") && ($Piece($Piece(tLine, ") ", 2), " ", 1) = "0"), "the vendor's text is logged at information severity: " _ tLine)
    Do $ClassMethod(..#SC, "Refuse", ..#NAMESPACE, ..#ALPHA _ ".cls", 0)
    Do $ClassMethod(..#SC, "Clear", ..#NAMESPACE)
    Do ##class(OcuPilot.Test.ExplorerSave).Save("classes", ..#ALPHA _ ".cls", tText, tVersion, "false", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "released, the same save is stored: " _ ##class(OcuPilot.Test.ExplorerSave).Json(tBody))
    Do $$$AssertEquals(..Source(), tText, "the class holds the text")
    Set tEntries = $ClassMethod(..#SC, "Entries", ..#NAMESPACE)
    Do $$$AssertEquals(..Sequence(tEntries), "OnBeforeSave,OnAfterSave", "the save hooks ran: " _ tEntries.%ToJSON())
    Set tHooks = ""
    Set tIterator = tEntries.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If (tEntry.user '= ##class(OcuPilot.Test.Http).GetTestUsername()) || (tEntry.job = $Job) Set tHooks = tHooks _ " " _ tEntry.%ToJSON()
    }
    Do $$$AssertEquals(tHooks, "", "all of them as " _ ##class(OcuPilot.Test.Http).GetTestUsername() _ " in the web process, not this one")
}

/// <p>AC5: an import of one UDL file over a class the source-control class has not released is refused 409
/// <code>EXPLORER.DOCUMENT.SOURCECONTROL</code> as the save is, with the class unchanged and no save hook run.</p>
/// <p>Mutation (Rule 19): make the 400 branch of <method>OcuPilot.Port.AtelierPort.Outcome</method> skip soft callers
/// (<code>&amp;&amp; 'pSoft</code>) -- the import goes red alone.</p>
Method TestAnImportOfAnUnreleasedDocumentIsRefusedBySourceControl()
{
    Do ..Arm(.tVersion)
    Set tBefore = ..Source()
    Set tText = $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "6")
    Do $ClassMethod(..#SAVE, "Act", "Classes", "PREVIEW", $ListBuild("id=import", "fileName=Alpha.cls", "content=" _ tText), .tPreview, .tHttp, .tFault)
    Do $$$AssertTrue((tHttp = 200) && $IsObject($Get(tPreview)), "the file previews: " _ ##class(OcuPilot.Test.AtelierPortSave).Said(.tHttp, .tPreview, .tFault))
    Do $ClassMethod(..#SC, "Refuse", ..#NAMESPACE, ..#ALPHA _ ".cls", 1)
    Do $ClassMethod(..#SC, "Clear", ..#NAMESPACE)
    Do $ClassMethod(..#SAVE, "Act", "Classes", "IMPORT", $ListBuild("id=import", "fileName=Alpha.cls", "content=" _ tText, "documents=" _ $Select($IsObject($Get(tPreview)): tPreview.documents, 1: ""), "Compile=false"), .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortSave).Said(.tHttp, .tResult, .tFault), "409 EXPLORER.DOCUMENT.SOURCECONTROL", "the import is refused as the save is")
    Do $$$AssertEquals(..Source(), tBefore, "and the class is unchanged")
    Set tEntries = $ClassMethod(..#SC, "Entries", ..#NAMESPACE)
    Do $$$AssertEquals(..Sequence(tEntries, "GetStatus"), "", "no save hook ran: " _ tEntries.%ToJSON())
}

/// <p>AC5: a source-control class whose own <code>OnBeforeSave</code> fails is the save's refusal 422
/// <code>EXPLORER.SAVE.REFUSED</code>, logged as a fault, with the class unchanged and no later hook run: the vendor wraps the
/// hook's error, so the port cannot tell it from any other text the instance refuses.</p>
/// <p>Mutation (Rule 19): add <code>16008</code> to <parameter>OcuPilot.Port.AtelierPort.SOURCECONTROLCODES</parameter> -- this
/// goes red.</p>
Method TestAHookVetoIsTheSavesRefusal()
{
    Do ..Arm(.tVersion)
    Set tBefore = ..Source()
    Do $ClassMethod(..#SC, "Veto", ..#NAMESPACE, ..#ALPHA _ ".cls", 1)
    Do $ClassMethod(..#SAVE, "Save", "Classes", ..#ALPHA _ ".cls", $ClassMethod(..#PROBE, "ClassText", ..#ALPHA, "2"), tVersion, 1, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortSave).Said(.tHttp, .tResult, .tFault), "422 EXPLORER.SAVE.REFUSED", "the save is refused as the instance's refusal of the text")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("severity"), 2, "and is logged as a fault: " _ ##class(OcuPilot.Test.LogProbe).Captured("message"))
    Do $$$AssertEquals(..Source(), tBefore, "the class is unchanged")
    Set tEntries = $ClassMethod(..#SC, "Entries", ..#NAMESPACE)
    Do $$$AssertEquals(..Sequence(tEntries), "OnBeforeSave", "and only the hook that refused ran: " _ tEntries.%ToJSON())
}

/// <p>The agent's <code>interop.transformeditor.save</code> proposal for the probe transformation, minted through the
/// dispatcher: the edit appends a suffix to the assignment's source, which the stored text holds once.</p>
Method Mint(pDocument As %String, Output pProposal As %DynamicObject) As %Boolean
{
    Set pProposal = ""
    Set tOld = "source.StringValue'"
    Set tNew = "source.StringValue_""-edited""'"
    Set tInput = {"Names": (pDocument), "Edits": [{"Old": (tOld), "New": (tNew)}], "rationale": "change the probe", "expectedImpact": "the probe changes"}
    Set tSC = ##class(OcuPilot.Test.ExplorerSaveFlow).Dispatch(..#NAMESPACE, ..#EDITTOOL, tInput, .tContent, .tIsError, .tProposal)
    If '$IsObject($Get(tProposal)) || tIsError || $$$ISERR(tSC) {
        Do $$$AssertTrue(0, "the edit is minted: " _ $Extract($Get(tContent), 1, 300))
        Quit 0
    }
    Set pProposal = tProposal
    Quit 1
}

/// <p>AC6: the agent's editor save, confirmed while the source-control class has not released the transformation, is refused
/// 409 <code>EXPLORER.DOCUMENT.SOURCECONTROL</code> with the text unchanged; a second proposal confirmed once it is released is
/// saved, and the four save and compile hooks run in the confirm process.</p>
/// <p>Mutation (Rule 19): remove the source-control branches from <method>OcuPilot.Port.AtelierPort.Outcome</method> -- the
/// refused leg goes red, as the person's does; store the text with
/// <code>%Compiler.UDL.TextServices.SetTextFromString</code> in <method>OcuPilot.Port.AtelierPort.SaveSet</method> -- nothing
/// refuses and no hook runs, so the refused leg goes red.</p>
Method TestTheAgentsEditorSaveRunsTheHooksAndIsRefusedByName()
{
    Set tName = $ClassMethod(..#INTEROPPROBE, "Name", "transform", ..#PACKAGE)
    Set tDocument = tName _ ".cls"
    Do $$$AssertStatusOK($ClassMethod(..#INTEROPPROBE, "Make", "transform", ..#PACKAGE), "the probe transformation is saved and compiled")
    Set tBefore = $ClassMethod(..#PROBE, "Source", ..#NAMESPACE, tDocument)
    Do $$$AssertTrue(tBefore [ "source.StringValue'", "the stored text holds the text the edit replaces")
    Do $$$AssertEquals($Length(tBefore, "source.StringValue'") - 1, 1, "once")
    Do $$$AssertStatusOK($ClassMethod(..#SC, "Enable", ..#NAMESPACE), "the probe's source-control class is enabled in " _ ..#NAMESPACE)
    If '..Mint(tDocument, .tRefused) Quit
    Do $ClassMethod(..#SC, "Refuse", ..#NAMESPACE, tDocument, 1)
    Do $ClassMethod(..#SC, "Clear", ..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#NAMESPACE, tRefused, .tResult, .tHttp, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 EXPLORER.DOCUMENT.SOURCECONTROL", "the confirm is refused by name while the transformation is not released")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Source", ..#NAMESPACE, tDocument), tBefore, "and the text is unchanged")
    Do $$$AssertEquals(..Sequence($ClassMethod(..#SC, "Entries", ..#NAMESPACE), "GetStatus"), "", "with no save hook run")
    Do $ClassMethod(..#SC, "Refuse", ..#NAMESPACE, tDocument, 0)
    Do $ClassMethod(..#SC, "Clear", ..#NAMESPACE)
    If '..Mint(tDocument, .tAllowed) Quit
    Set tSC = ##class(OcuPilot.Test.ExplorerWrite).ConfirmIn(..#NAMESPACE, tAllowed, .tResult, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "released, the second proposal is confirmed: " _ tHttp _ " " _ $Get(tCode))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Source", ..#NAMESPACE, tDocument) [ "source.StringValue_""-edited""'", "and the text holds the edit")
    Set tEntries = $ClassMethod(..#SC, "Entries", ..#NAMESPACE)
    Do $$$AssertEquals(..Sequence(tEntries), ..#SAVEHOOKS, "the save and compile hooks run once each, in order: " _ tEntries.%ToJSON())
    Do ..AssertCaller(tEntries, tDocument, $Job, $Username, "the agent's confirmed save")
}

}
