/// <p>Pins the edges of Story 24.10's term list export and import (AD-21, AD-54, AD-65) that <class>OcuPilot.Test.AnalyticsTermListTransfer</class>
/// leaves open, against <code>USER</code>, with analytics on through <class>OcuPilot.Test.AnalyticsProbe</class>, lists named with this class's own
/// marker and server files in <class>OcuPilot.Test.ExplorerTransferProbe</class>'s directory: a file already at the export's name is replaced, the text
/// bound of a server file and at its limit, the way the import reads a file's header lines, blank space, repeated keys and columns, and the person's
/// refusals on their field. It uses the first class's helpers for calls, dumps and snapshots.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it turns analytics on in
/// <code>USER</code> and writes term lists and files there. It removes everything after the last test. One class per run.</p>
Class OcuPilot.Test.AnalyticsTermListTransferEdge Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter FILES = "OcuPilot.Test.ExplorerTransferProbe";

Parameter BASE = "OcuPilot.Test.AnalyticsTermListTransfer";

Parameter SEAM = "OcuPilot.Test.AnalyticsTermListSeam";

Parameter NAMESPACE = "USER";

/// <p>The prefix of every list this class makes, upper-cased by the vendor. It begins with the first class's marker's stem, so that its snapshot sees
/// these lists, and differs from that marker, so that neither class sweeps the other's.</p>
Parameter MARKER = "OcuProbeTL24Edge";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListTransferEdge turns analytics on in USER and writes term lists and files there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe, the lists and the directory; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Do ..Sweep()
    Set tSC = $ClassMethod(..#FILES, "RemoveDirectory")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListTransferEdge left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && (..Marked() '= "") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsTermListTransferEdge left term lists in USER: " _ ..Marked())
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ..Sweep()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $ClassMethod(..#FILES, "MakeDirectory")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ..Sweep()
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "RemoveDirectory"), "the probe directory is removed")
    Quit $$$OK
}

/// <p>Kill every list this class marked in <code>USER</code>.</p>
ClassMethod Sweep()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tId = $Order(^DeepSee.TermList(""))
        While tId '= "" {
            Set tNext = $Order(^DeepSee.TermList(tId))
            If $Extract(tId, 1, $Length(..#MARKER)) = $ZConvert(..#MARKER, "U") Do ##class(%DeepSee.TermList).%DeleteTermList(tId)
            Set tId = tNext
        }
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>The lists this class marked that remain in <code>USER</code>, comma-separated.</p>
ClassMethod Marked() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tNames = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tId = $Order(^DeepSee.TermList(""))
        While tId '= "" {
            If $Extract(tId, 1, $Length(..#MARKER)) = $ZConvert(..#MARKER, "U") Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tId
            Set tId = $Order(^DeepSee.TermList(tId))
        }
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tNames
}

/// <p>The port's answer for <var>pType</var> on <var>pId</var> with the query <var>pExtra</var>, as <code>&lt;http&gt; &lt;code&gt;</code>.</p>
ClassMethod T(pType As %String, pId As %String, pExtra As %DynamicObject, Output pResult, Output pFault, pAction As %String = "") As %String
{
    Quit $ClassMethod(..#BASE, "T", pType, pId, pExtra, .pResult, .pFault, pAction)
}

/// <p>Import the text <var>pText</var> as a local file with the digest the port gives it: the answer as <code>&lt;http&gt; &lt;code&gt;</code>.</p>
ClassMethod ImportText(pText As %String, Output pResult, Output pFault) As %String
{
    Quit ..T("IMPORT", "import", {"fileName": "edge.csv", "content": (pText), "digest": ($ClassMethod(..#BASE, "TextDigest", pText))}, .pResult, .pFault)
}

/// <p>AC1: a file already at the export's name is replaced whole: a longer file that was there is gone and the new file equals an export to a name
/// that was free.</p>
/// <p>Mutation (Rule 19): declare the export's overwrite <code>0</code> in <parameter>OcuPilot.Port.AnalyticsPort.EXPORTOVERWRITES</parameter> -- the
/// export is refused and this goes red.</p>
Method TestAnExportReplacesAFileAlreadyAtItsName()
{
    Set tName = ..#MARKER _ "Replace"
    Do $ClassMethod(..#BASE, "Arrange", tName)
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "WriteFile", "old.csv", $Translate($Justify("", 20000), " ", "o")), "a long file is at the name")
    Do $$$AssertEquals(..T("EXPORT", tName, $ClassMethod(..#BASE, "FileQuery", "old.csv"), .tRes, .tFault), "200 ", "the export to that name answers 200: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..T("EXPORT", tName, $ClassMethod(..#BASE, "FileQuery", "new.csv"), .tRes, .tFault), "200 ", "an export to a free name answers 200")
    Set tReplaced = $ClassMethod(..#FILES, "ReadFile", "old.csv")
    Do $$$AssertTrue($Extract(tReplaced, 1, 7) = "%%NAME,", "the file now starts with the vendor's name line")
    Do $$$AssertTrue(tReplaced '[ "oooo", "and none of the earlier text remains")
    Do $$$AssertEquals(tReplaced, $ClassMethod(..#FILES, "ReadFile", "new.csv"), "so it equals an export to a free name")
}

/// <p>AC1, AC2: a server file past the text bound is refused <code>TOOLARGE</code> by an import and by the read composed for it, and a local text
/// of exactly the bound is read, so it is judged by its shape and not refused for its size.</p>
/// <p>Mutation (Rule 19): make the server file's too-large branch of <method>OcuPilot.Port.AnalyticsPort.ImportText</method> never run -- the
/// server leg goes red; and compare the local text with <code>&gt;=</code> -- the limit leg goes red.</p>
Method TestAnImportFilePastTheTextBoundIsRefusedAndOneAtTheBoundIsRead()
{
    Set tBound = $Parameter("OcuPilot.Port.AtelierPort", "MAXIMPORTCHARACTERS")
    Do $$$AssertTrue(tBound > 0, "the bound is a number: " _ tBound)
    Set tLine = $Translate($Justify("", 30000), " ", "x") _ $Char(10)
    Set tBig = ""
    For tAt = 1:1:(tBound \ $Length(tLine)) + 1 {
        Set tBig = tBig _ tLine
    }
    Do $$$AssertTrue($Length(tBig) > tBound, "the arranged text passes the bound")
    Do $$$AssertStatusOK($ClassMethod(..#FILES, "WriteFile", "big.csv", tBig), "the large file is written")
    Set tFile = $ClassMethod(..#BASE, "FileQuery", "big.csv")
    Set tBefore = $ClassMethod(..#BASE, "Snapshot")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertEquals(..T("IMPORT", "import", tFile, .tRes, .tFault), "409 ANALYTICS.TERMLIST.TOOLARGE", "an import of a server file past the bound is refused")
    Do $$$AssertEquals(..T("IMPORTFILE", "import", tFile, .tRead, .tFault, "IMPORT"), "409 ANALYTICS.TERMLIST.TOOLARGE", "and so is its read composed for the import")
    Set tAtBound = $Translate($Justify("", tBound), " ", "x")
    Do $$$AssertEquals(..T("IMPORTFILE", "import", {"fileName": "bound.csv", "content": (tAtBound)}, .tRead, .tFault, "IMPORT"), "409 ANALYTICS.TERMLIST.IMPORTSHAPE", "a local text of exactly the bound is read and found to be no export")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Snapshot") _ "|" _ $ClassMethod(..#SEAM, "Calls"), tBefore _ "|0", "nothing was written and no vendor call was made")
}

/// <p>AC2: the import reads a file as the vendor's own import reads the header: only the leading <code>%%</code> lines, the first name, each by its
/// name in any letter case; blank space around an entry line is dropped; a repeated key keeps its later line; columns past the field list are
/// ignored and a missing column is empty; and a <code>%%</code> line after an entry is no header.</p>
/// <p>Mutation (Rule 19): never end the header at the first entry in <method>OcuPilot.Port.AnalyticsPort.TermListParse</method> -- the late caption leg
/// goes red; and keep a repeated key's first line -- the repeated-key leg goes red; and keep an entry line's blank space -- the key leg goes red.</p>
Method TestTheImportReadsHeadersBlanksRepeatedKeysAndColumns()
{
    Set tName = ..#MARKER _ "Parse"
    Set tLf = $Char(10)
    Set tText = "%%NAME," _ tName _ tLf _ "%%name,Other" _ tLf _ "%%Caption,Cap" _ tLf _ "%%FIELDLIST,Region" _ tLf _ "k1,v1,West" _ tLf _ "   k2,v2,West,extra,more   " _ tLf _ "k1,v1b,East" _ tLf _ "%%CAPTION,Late" _ tLf _ "k3" _ tLf
    Do $$$AssertEquals(..ImportText(tText, .tRes, .tFault), "200 ", "the import answers 200: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#BASE, "Dump", tName), "Cap||||Region~k1^East^v1b~k2^West^v2~k3^^", "the first name and the caption of the header are read, a later caption is not, the later line of a repeated key wins, an extra column is dropped and a missing one is empty")
    Do $$$AssertEquals(..Marked(), $ZConvert(tName, "U"), "and no other list was created")
}

/// <p>AC4: the person's refusals reach the field the instance names and write nothing: an export to a path with <code>..</code> or a root that is not
/// allowed (400 on that field), of a list that is not held (404); an import of a file that is no export (409), from a root that is not allowed (400 on
/// its field); and a copy to a name the rules refuse (422), of a list that is not held (404).</p>
/// <p>Mutation (Rule 19): send only the <code>root</code> in <method>OcuPilot.Screen.Tool.AnalyticsTermListExport.ScreenActionDelta</method> -- the
/// path leg goes red.</p>
Method TestThePersonsRefusalsNameTheirFieldAndWriteNothing()
{
    Set tName = ..#MARKER _ "Refused"
    Do $ClassMethod(..#BASE, "Arrange", tName)
    Set tBefore = $ClassMethod(..#BASE, "Snapshot")
    Set tRoot = $ClassMethod(..#FILES, "Root")
    Do $$$AssertEquals(..Refusal("export", tName, {"root": (tRoot), "path": "../out.csv"}, 400, "PATH.", "path"), 1, "an export to a path with .. is refused on the path")
    Do $$$AssertEquals(..Refusal("export", tName, {"root": "/nowhere/", "path": "out.csv"}, 400, "PATH.", "root"), 1, "an export to a root that is not allowed is refused on the root")
    Do $$$AssertEquals(..Refusal("export", tName _ "Gone", {"root": (tRoot), "path": "out.csv"}, 404, "ANALYTICS.TERMLIST.ABSENT", ""), 1, "an export of a list that is not held is refused 404")
    Do $$$AssertEquals(..Refusal("import-local", "import", {"fileName": "a.csv", "content": ("k1,v1" _ $Char(10))}, 409, "ANALYTICS.TERMLIST.IMPORTSHAPE", ""), 1, "an import of a file that is no export is refused 409")
    Do $$$AssertEquals(..Refusal("import", "import", {"root": "/nowhere/", "path": "in.csv"}, 400, "PATH.", "root"), 1, "an import from a root that is not allowed is refused on the root")
    Do $$$AssertEquals(..Refusal("copy", tName, {"NewName": ($Justify("", 256))}, 422, "ANALYTICS.TERMLIST.NAME", ""), 1, "a copy to a name over 255 characters is refused 422")
    Do $$$AssertEquals(..Refusal("copy", tName _ "Gone", {"NewName": (tName _ "C")}, 404, "ANALYTICS.TERMLIST.ABSENT", ""), 1, "a copy of a list that is not held is refused 404")
    Do $$$AssertEquals($ClassMethod(..#BASE, "Snapshot"), tBefore, "and nothing was written")
    Do $$$AssertEquals($ClassMethod(..#FILES, "FileExists", "out.csv"), 0, "and no file was written")
}

/// <p>1 when the person's action <var>pAction</var> on <var>pId</var> with <var>pValues</var> is refused with the status <var>pStatus</var> and a
/// code starting <var>pCode</var>, naming the field <var>pField</var> when it is not empty; else 0, with the reason in the failing assertion.</p>
Method Refusal(pAction As %String, pId As %String, pValues As %DynamicObject, pStatus As %Integer, pCode As %String, pField As %String) As %Boolean
{
    Set tStatus = $ClassMethod(..#BASE, "Act", pAction, pId, pValues, .tAnswer)
    Set tCode = $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: "")
    Set tField = ""
    If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")) && $IsObject(tAnswer.detail.%Get("violations")) Set tField = tAnswer.detail.violations.%Get(0).field
    Set tGood = (tStatus = pStatus) && ($Extract(tCode, 1, $Length(pCode)) = pCode) && ((pField = "") || (tField = pField))
    If 'tGood Do $$$AssertTrue(0, pAction _ " answered " _ tStatus _ " " _ tCode _ " on field '" _ tField _ "', not " _ pStatus _ " " _ pCode _ " on '" _ pField _ "': " _ $Select($IsObject(tAnswer): $Extract(tAnswer.%ToJSON(), 1, 300), 1: tAnswer))
    Quit tGood
}

}
