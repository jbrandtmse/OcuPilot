/// <p>The older console-log files over the wire (Story 16.20, AD-21's fourth named case):
/// <code>GET /api/ocupilot/logs/messages/files</code> and <code>GET /api/ocupilot/logs/messages?file=</code>
/// through the real <code>/api/ocupilot</code> application, as the configured test principal
/// (<class>OcuPilot.Test.Http</class>).</p>
/// <p><b>It writes a file into the instance's own manager directory</b> -- a rotated-looking
/// <parameter>SEEDNAME</parameter> holding a few head-format lines -- and removes it in
/// <method>OnAfterAllTests</method>, so it runs on a throwaway container only
/// (<file>scripts/ci-throwaway.sh</file>) and refuses anywhere <parameter>ARMINGVARIABLE</parameter>
/// does not arm it. It never writes, rotates or removes <file>messages.log</file>. Needs the API
/// application installed and the test principal holding <code>%Admin_Operate:USE</code>.</p>
Class OcuPilot.Test.LogOlderFilesWire Extends %UnitTest.TestCase
{

/// <p>The list route, spelled once and literal.</p>
Parameter FILESPATH = "/api/ocupilot/logs/messages/files";

/// <p>The console-log page route.</p>
Parameter LOGPATH = "/api/ocupilot/logs/messages";

/// <p>The alert-log page route, which takes no file.</p>
Parameter ALERTPATH = "/api/ocupilot/logs/alerts";

/// <p>The file this class writes into the manager directory: a name the rotation pattern admits
/// and no instance writes, so it can be neither mistaken for nor collide with a real
/// generation.</p>
Parameter SEEDNAME = "messages.old_20000101_4242";

/// <p>The environment variable that arms this class, and the one value that arms it: <code>1</code>.
/// Only <file>scripts/ci-throwaway.sh</file> sets it; it is the variable
/// <class>OcuPilot.Test.LogSourceRotation</class> reads, because both write the instance's own
/// console-log family.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_LOG_ROTATION";

/// <p>Every <code>file</code> value that must be refused <code>LOG.FILE</code>.</p>
Parameter BADNAMES = "/etc/passwd,../messages.log,messages.log,messages.old_2026,messages.old_20260101_1.bak,alerts.log";

/// <p>The seeded file's path.</p>
ClassMethod SeedPath() As %String
{
    Quit ##class(%File).NormalizeFilename(..#SEEDNAME, $System.Util.ManagerDirectory())
}

/// <p>The seeded file's content: three head-format lines that name it.</p>
ClassMethod SeedContent() As %String
{
    Set tText = ""
    For tI = 1:1:3 {
        Set tText = tText _ "01/01/00-00:00:0" _ tI _ ":000 (4242) 0 [OcuPilot.OlderFilesWire] seeded line " _ tI _ $Char(10)
    }
    Quit tText
}

/// <p>Refuse unless armed; otherwise write <parameter>SEEDNAME</parameter>.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LogOlderFilesWire writes a file into this instance's manager directory and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ##class(OcuPilot.Test.LogSource).WriteFile(..SeedPath(), ..SeedContent())
}

/// <p>Remove the seeded file, and return a failing status if it survives.</p>
Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Do ##class(%File).Delete(..SeedPath())
    If ##class(%File).Exists(..SeedPath()) Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LogOlderFilesWire left its seeded file in the manager directory: " _ ..#SEEDNAME)
    Quit $$$OK
}

/// <p>Request <var>pPath</var> as the configured test principal.</p>
Method Fetch(pPath As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBody, .pHeaders)
}

/// <p>AC1 -- the list answers <file>messages.log</file> first and the seeded file among the rest,
/// with the size written and the modification time the file carries, in UTC; every later entry is
/// no newer than the one before it.</p>
Method TestTheListNamesTheSeededFile()
{
    Set tSC = ..Fetch(..#FILESPATH, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the list answers")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    If tStatus '= 200 Quit
    Set tList = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tList.source, "messages", "for the console log")
    Do $$$AssertEquals(tList.%GetTypeOf("truncated"), "boolean", "reporting whether it cut")
    Do $$$AssertEquals(tList.files.%Get(0).name, "messages.log", "messages.log first")
    Set tSeed = ""
    Set tPrevious = ""
    Set tOrdered = 1
    For tI = 1:1:(tList.files.%Size() - 1) {
        Set tEntry = tList.files.%Get(tI)
        If tEntry.name = ..#SEEDNAME Set tSeed = tEntry
        If (tPrevious '= "") && (tEntry.modified ] tPrevious) Set tOrdered = 0
        Set tPrevious = tEntry.modified
    }
    Do $$$AssertTrue(tOrdered, "the rotated files are newest first")
    Do $$$AssertTrue($IsObject(tSeed), "the seeded file is listed")
    If '$IsObject(tSeed) Quit
    Do $$$AssertEquals(tSeed.size, $Length(..SeedContent()), "with the size written")
    Set tOnDisk = $Translate($ZDateTime(##class(%File).GetFileDateModified(..SeedPath(), 1), 3, 1), " ", "T") _ "Z"
    Do $$$AssertEquals(tSeed.modified, tOnDisk, "and the file's own modification time, in UTC")
}

/// <p>AC2 -- the seeded file pages as <file>messages.log</file> does: its tail carries its own
/// lines under the <code>messages</code> source, and the cursor it returns continues.</p>
Method TestTheSeededFileIsPaged()
{
    Set tSC = ..Fetch(..#LOGPATH _ "?file=" _ ..#SEEDNAME, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the seeded file is served")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    If tStatus '= 200 Quit
    Set tPage = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tPage.source, "messages", "as the console log's source")
    Do $$$AssertEquals(tPage.lines.%Size(), 3, "its three lines")
    Do $$$AssertTrue(tPage.lines.%Get(0) [ "[OcuPilot.OlderFilesWire] seeded line 1", "which are the seeded ones: " _ tPage.lines.%Get(0))
    Do $$$AssertEquals(tPage.size, $Length(..SeedContent()), "its size")

    Set tSC = ..Fetch(..#LOGPATH _ "?file=" _ ..#SEEDNAME _ "&offset=1&maxBytes=100&identity=" _ $ZConvert(tPage.identity, "O", "URL"), .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertEquals(tStatus2, 200, "a page from byte 1 under its identity")
    If tStatus2 '= 200 Quit
    Set tFirst = ##class(%DynamicObject).%FromJSON(tBody2)
    Do $$$AssertEquals(tFirst.restarted, 0, "does not restart")
    Set tSC = ..Fetch(..#LOGPATH _ "?file=" _ ..#SEEDNAME _ "&offset=" _ tFirst.offset _ "&identity=" _ $ZConvert(tFirst.identity, "O", "URL"), .tStatus3, .tBody3, .tHeaders3)
    Do $$$AssertEquals(tStatus3, 200, "and the next page answers")
    If tStatus3 '= 200 Quit
    Set tNext = ##class(%DynamicObject).%FromJSON(tBody3)
    Do $$$AssertEquals(tNext.restarted, 0, "continuing")
    Do $$$AssertTrue(tNext.lines.%Get(0) [ "seeded line 2", "from where the first stopped: " _ tNext.lines.%Get(0))
}

/// <p>AC3 -- every other name is refused 400 <code>LOG.FILE</code> in one envelope that repeats
/// neither the value nor a path, and so is any name on the alert log.</p>
Method TestEveryOtherNameIsRefusedWithoutAPath()
{
    Set tManager = $System.Util.ManagerDirectory()
    For tI = 1:1:$Length(..#BADNAMES, ",") {
        Set tName = $Piece(..#BADNAMES, ",", tI)
        Set tSC = ..Fetch(..#LOGPATH _ "?file=" _ $ZConvert(tName, "O", "URL"), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tName _ ": the request completes")
        Do $$$AssertEquals(tStatus, 400, tName _ ": refused 400")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tName _ ": as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, tName _ ": exactly one envelope")
        Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tFault.code, "LOG.FILE", tName _ ": on LOG.FILE")
        Do $$$AssertTrue((tBody '[ "/") && (tBody '[ tManager) && (tBody '[ tName), tName _ ": naming neither a path nor the value: " _ tBody)
    }
    Set tSC = ..Fetch(..#ALERTPATH _ "?file=messages.old_20260101", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 400, "a name on the alert log is refused 400")
    Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tFault.code, "LOG.FILE", "on LOG.FILE")
}

}
