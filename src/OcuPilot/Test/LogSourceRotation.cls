/// <p>AC3's outermost-surface leg: a cursor held across a <b>real</b> IRIS rotation, observed over
/// HTTP. It takes a page from <code>GET /api/ocupilot/logs/messages</code>, has the instance
/// rotate its own <file>messages.log</file>, and calls again with the held
/// <code>offset</code> and <code>identity</code>.</p>
/// <p><b>It rotates and writes to the instance's own console log, so it runs on a throwaway
/// container only</b> (<file>scripts/ci-throwaway.sh</file>, <code>ocupilot-ci</code>), where the
/// test owns the whole instance and the container is discarded afterwards. Run against any
/// instance you care about, it rotates that instance's log. Nothing else in this story's suite
/// writes to a console log at all: <class>OcuPilot.Test.LogSource</class> rotates a scratch file
/// of its own and <class>OcuPilot.Test.LogSourceWire</class> only reads.</p>
/// <p>The restart is anchored here rather than proxied: the file the port reads is renamed away by
/// IRIS, not by the test, which is the event a viewer's held offset actually has to survive.</p>
Class OcuPilot.Test.LogSourceRotation Extends %UnitTest.TestCase
{

/// <p>The console-log route.</p>
Parameter LOGPATH = "/api/ocupilot/logs/messages";

/// <p>The console log's file name in the manager directory.</p>
Parameter LOGFILE = "messages.log";

/// <p>The pattern a rotated generation is named with on this build:
/// <code>messages.old_&lt;YYYYMMDD&gt;</code>, with <code>_1</code> for a second rotation the same
/// day.</p>
Parameter ROTATEDPATTERN = "messages.old_*";

/// <p>The window every page here asks for. Small, so the cursor the first page returns is a
/// position the rotated-in file also has -- which is what leaves the identity as the only thing
/// that can restart the second page.</p>
Parameter WINDOW As INTEGER = 200;

/// <p>The window the held cursor is replayed with, once the file has rotated: wide enough to cover
/// the whole rotated-in file, so "served from byte 1" can be compared against that file's opening
/// bytes read off disk.</p>
Parameter REPLAYWINDOW As INTEGER = 65536;

/// <p>How many lines are written into the rotated-in log before the held cursor is replayed, so
/// that cursor is comfortably inside it.</p>
Parameter PADLINES As INTEGER = 40;

/// <p>The environment variable that arms this class. Only
/// <file>scripts/ci-throwaway.sh</file> sets it, so the rotation runs on the container that
/// script builds and nowhere else.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_LOG_ROTATION";

/// <p>Refuse to run at all unless this instance is armed for a console-log rotation.</p>
/// <p><b>A doc comment does not keep a destructive class off a development instance.</b> Test
/// classes are selected by package -- <file>ui/tools/ci-runner.mjs</file> runs every
/// <class>%UnitTest.TestCase</class> the instance offers under <code>OcuPilot.Test</code> -- so
/// pointing the runner at a container someone cares about would rotate its log before anyone read
/// the header. Failing here is the honest outcome: nothing is rotated and the reason is
/// named.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) = "" {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LogSourceRotation rotates this instance's own messages.log and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " is not set here, so nothing was rotated. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>The console log's path.</p>
ClassMethod LogPath() As %String
{
    Quit ##class(%File).NormalizeFilename(..#LOGFILE, $System.Util.ManagerDirectory())
}

/// <p>How many rotated generations sit beside the console log right now.</p>
ClassMethod RotatedGenerations() As %Integer
{
    Set tCount = 0
    Set tRS = ##class(%ResultSet).%New("%File:FileSet")
    Set tSC = tRS.Execute($System.Util.ManagerDirectory(), ..#ROTATEDPATTERN)
    If $$$ISERR(tSC) Quit -1
    While tRS.Next() {
        Set tCount = tCount + 1
    }
    Do tRS.Close()
    Quit tCount
}

/// <p>The console log's first <var>pWant</var> bytes as they are on disk right now, decoded the
/// way the endpoint decodes them -- an independent witness of what a page that started at byte 1
/// must have served.</p>
ClassMethod Head(pWant As %Integer) As %String
{
    Set tStream = ##class(%Stream.FileBinary).%New()
    Set tSC = tStream.LinkToFile(..LogPath())
    If $$$ISERR(tSC) Quit ""
    Set tHead = ""
    While ($Length(tHead) < pWant) && 'tStream.AtEnd {
        Set tHead = tHead _ tStream.Read(32000)
    }
    Quit $ZConvert($Extract(tHead, 1, pWant), "I", "UTF8")
}

/// <p>Have the instance rotate its own console log: <code>Config.Startup.MoveConsoleLog</code> in
/// <code>%SYS</code> by explicit save and restore (AD-16), which is the rename the System Monitor
/// itself performs.</p>
/// <p><b>Not <code>SwitchConsoleLog()</code>.</b> Measured on the pinned image: it returns
/// <code>$$$OK</code> and schedules the switch for a later monitor pass -- the file was still
/// whole, and the generation count still unchanged, tens of seconds after the call -- so a test
/// built on it would be measuring the monitor's cycle. This one renames the file before it
/// returns. It reports no status of its own, which is why the caller observes the rotation
/// rather than trusting it.</p>
ClassMethod Rotate() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    ; Resolved before the switch: OcuPilot's classes are mapped nowhere but the install
    ; namespace, so a ##class(OcuPilot....) dispatch from %SYS raises <CLASS DOES NOT EXIST>.
    Set tPath = ..LogPath()
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Config.Startup).Get(.tProps)
        Set tMax = $Get(tProps("MaxConsoleLogSize"), 1)
        Do ##class(Config.Startup).MoveConsoleLog(tPath, tMax)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Write <parameter>PADLINES</parameter> lines into the console log, so the rotated-in file is
/// larger than the cursor held across the rotation.</p>
ClassMethod Pad() As %Status
{
    Set tSC = $$$OK
    For tI = 1:1:..#PADLINES {
        Set tSC = ##class(%SYS.System).WriteToConsoleLog("OcuPilot.Test.LogSourceRotation padding line " _ tI, 0, 0)
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>Request the console-log page as the configured test principal.</p>
Method Fetch(pQuery As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Set tPath = ..#LOGPATH
    If pQuery '= "" Set tPath = tPath _ "?" _ pQuery
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBody, .pHeaders)
}

/// <p>AC3 -- a viewer holding an <code>offset</code> and an <code>identity</code> across a real
/// rotation is answered <code>restarted: true</code> and served from byte 1 of the file that is
/// there now, rather than from a stale position in a file that has been renamed away.</p>
/// <p><b>Three preconditions are asserted before the restart is</b>, so a rotation that did not
/// happen cannot pass for one that did and the offset condition cannot pass for the identity's:
/// a new <code>messages.old_*</code> generation exists, the file left behind is smaller than the
/// one renamed away, and the held cursor is still a position <i>inside</i> the rotated-in file --
/// which is what leaves the identity as the only thing that can restart this page.</p>
/// <p>Mutation: make <method>OcuPilot.Port.LogSourcePort.Identity</method> answer a constant
/// -&gt; the held identity matches the rotated-in file's, nothing restarts, and the
/// <code>restarted</code> and served-region assertions go red.</p>
Method TestARealRotationRestartsThePageOverTheWire()
{
    Set tSC = ..Fetch("maxBytes=" _ ..#WINDOW, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the first request completes")
    Do $$$AssertEquals(tStatus, 200, "the page answers")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    If tStatus '= 200 Quit
    Set tIdentity = ##class(%DynamicObject).%FromJSON(tBody).identity

    Set tSC2 = ..Fetch("offset=1&maxBytes=" _ ..#WINDOW _ "&identity=" _ $ZConvert(tIdentity, "O", "URL"), .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC2, "the page from byte 1 completes")
    Do $$$AssertEquals(tStatus2, 200, "and answers")
    If tStatus2 '= 200 Quit
    Set tFirst = ##class(%DynamicObject).%FromJSON(tBody2)
    Do $$$AssertEquals(tFirst.restarted, 0, "the identity matched, so nothing restarted yet")
    Set tHeldOffset = tFirst.offset
    Set tOldSize = tFirst.size
    Set tOldGenerations = ..RotatedGenerations()
    Do $$$AssertTrue(tOldGenerations >= 0, "the rotated generations beside the log can be counted")

    ; This asserts only that the call completed -- MoveConsoleLog reports nothing, so whether a
    ; rotation happened is the next two assertions' job and not this one's.
    Do $$$AssertStatusOK(..Rotate(), "the rotation call completes")
    ; Measured before the padding below, which is what makes "the file was replaced" a statement
    ; about the rotation rather than about how much this test wrote afterwards.
    Set tRotatedSize = ##class(%File).GetFileSize(..LogPath())
    Do $$$AssertEquals(..RotatedGenerations(), tOldGenerations + 1, "a rotated generation appeared, so a rotation really happened: " _ tOldGenerations _ " before")
    Do $$$AssertTrue(tRotatedSize < tOldSize, "and the file left behind is smaller than the one that was renamed away: " _ tRotatedSize _ " against " _ tOldSize)

    Do $$$AssertStatusOK(..Pad(), "the rotated-in file is written past the held cursor")
    Set tNewSize = ##class(%File).GetFileSize(..LogPath())
    Do $$$AssertTrue(tHeldOffset <= (tNewSize + 1), "the held cursor is still a position inside the rotated-in file, so only its identity can restart this page: offset " _ tHeldOffset _ " against size " _ tNewSize)

    Set tSC3 = ..Fetch("offset=" _ tHeldOffset _ "&maxBytes=" _ ..#REPLAYWINDOW _ "&identity=" _ $ZConvert(tIdentity, "O", "URL"), .tStatus3, .tBody3, .tHeaders3)
    Do $$$AssertStatusOK(tSC3, "the held cursor is answered after the rotation")
    Do $$$AssertEquals(tStatus3, 200, "with 200, because a restart is an outcome and not a fault")
    If tStatus3 '= 200 Quit
    Set tSecond = ##class(%DynamicObject).%FromJSON(tBody3)
    Do $$$AssertNotEquals(tSecond.identity, tIdentity, "the file's identity moved with the rotation")
    Do $$$AssertEquals(tSecond.restarted, 1, "the page restarted")
    Do $$$AssertTrue(tSecond.lines.%Size() > 0, "and served lines: " _ tSecond.lines.%Size())
    If tSecond.lines.%Size() = 0 Quit

    ; What "from byte 1" means, against the file read independently off disk: the lines served,
    ; laid end to end, are the opening bytes of the file that is there now. A prefix rather than
    ; an equality because the instance keeps appending to it while this runs.
    Set tServed = ""
    Set tLineIterator = tSecond.lines.%GetIterator()
    While tLineIterator.%GetNext(.tIndex, .tLine) {
        Set tServed = tServed _ $Select(tIndex = 0: "", 1: $Char(10)) _ tLine
    }
    Do $$$AssertTrue($Length(tServed) > 0, "the served region is not empty: " _ $Length(tServed) _ " characters")
    Do $$$AssertEquals($Extract(..Head($Length(tServed)), 1, $Length(tServed)), tServed, "and it is the opening bytes of the rotated-in file, read independently off disk")
}

}
