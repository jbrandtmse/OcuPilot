/// <p>Pins AD-35's masking of the Task Manager mail password in the audit read (DW-2625, Story 21.24):
/// <code>%SYS.Task.Config.AuthPassSet</code> writes the password, Base64-encoded, on the
/// <code>Old value</code> and <code>New value</code> lines of the vendor's "Modify Task
/// Config.MailAuthPassword" row. Setting it from empty, changing it and clearing it are each read
/// through the Logs audit screen's read over the wire and through <code>logs.audit.read</code>, both
/// answering the lines masked (an empty one stays empty) while the audit database still holds the
/// Base64 value; and the mask reads the per-event declaration alone.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, auditing on, an account
/// holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because
/// it changes the instance's Task Manager mail password to probe values. It stores the value it found
/// before the run and writes it back after every method. The rows it writes stay in the audit
/// database and the Task Manager history.</p>
Class OcuPilot.Test.TaskMailAuditMask Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PORT = "OcuPilot.Port.AuditPort";

Parameter MODEL = "OcuPilot.Test.AuditVendorSecrets";

Parameter TOOLNAME = "logs.audit.read";

/// <p>The vendor event the row belongs to, as <code>&lt;source&gt;/&lt;type&gt;/&lt;name&gt;</code>.</p>
Parameter EVENT = "%System/%System/ConfigurationChange";

/// <p>The leading words of the row's <code>Description</code>.</p>
Parameter PREFIX = "Modify Task Config.MailAuthPassword";

/// <p>The probe passwords. Neither is a real secret. The second is long enough that the vendor's
/// Base64 of it runs onto a second line.</p>
Parameter FIRSTPROBE = "OcuProbe2624PwOne";

Parameter SECONDPROBE = "OcuProbe2624PwTwoLongEnoughToWrapTheVendorsBase64LineAtSeventySixChars";

/// <p>The mail password's stored value before the run.</p>
Property PreparedMail As %String(MAXLEN = "") [ InitialExpression = "" ];

/// <p>Whether <method>OnBeforeAllTests</method> took <property>PreparedMail</property>.</p>
Property PreparedMailTaken As %Boolean [ InitialExpression = 0 ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskMailAuditMask changes this instance's Task Manager mail password and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set ..PreparedMail = ..Stored()
    Set ..PreparedMailTaken = 1
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    If '..PreparedMailTaken Quit $$$OK
    Do $$$AssertStatusOK(..Store(..PreparedMail), "the mail password's stored value is put back")
    Do $$$AssertEquals(..Stored(), ..PreparedMail, "and reads as before the run")
    Quit $$$OK
}

/// <p>AC2: the declaration names the one vendor setter of this shape the survey found, under the
/// vendor event its row belongs to, and nothing else.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Port.AuditPort.VENDORCONFIGSECRETS</parameter> --
/// this goes red.</p>
Method TestTheDeclarationNamesTheSurveyedSetter()
{
    Set tDeclared = $Parameter(..#PORT, "VENDORCONFIGSECRETS")
    Do $$$AssertEquals(tDeclared, ..#PREFIX, "the declaration is the one Task Config row")
    Do $$$AssertEquals($Parameter(..#PORT, "VENDORCONFIGSOURCE"), ..#EVENT, "under the vendor's configuration change event")
}

/// <p>The mask reads the declaration alone: a declared row's two values are masked, the line a long
/// value continues onto included, and an empty one stays empty, while another Task Config row, the
/// same text under another vendor event, and a description that only begins with the declared words
/// are unchanged.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Port.AuditPort.VENDORCONFIGSECRETS</parameter> --
/// the first three assertions go red.</p>
Method TestTheMaskReadsTheDeclarationAlone()
{
    Set tCrlf = $Char(13, 10)
    Set tBoth = "  Old value: ocupilotmaskprobe001" _ tCrlf _ "  New value: ocupilotmaskprobe002"
    Set tSet = "  Old value: " _ tCrlf _ "  New value: ocupilotmaskprobe002"
    Set tClear = "  Old value: ocupilotmaskprobe001" _ tCrlf _ "  New value: "
    Set tLong = ..Encoded(..#SECONDPROBE)
    Set tWrapped = "  Old value: " _ tLong _ tCrlf _ "  New value: " _ tLong
    Set tMask = $Parameter(..#PORT, "MASK")
    Set tRows = []
    Do tRows.%Push($ClassMethod(..#MODEL, "Row", "%System", "%System", "ConfigurationChange", ..#PREFIX, tBoth))
    Do tRows.%Push($ClassMethod(..#MODEL, "Row", "%System", "%System", "ConfigurationChange", ..#PREFIX, tSet))
    Do tRows.%Push($ClassMethod(..#MODEL, "Row", "%System", "%System", "ConfigurationChange", ..#PREFIX, tClear))
    Do tRows.%Push($ClassMethod(..#MODEL, "Row", "%System", "%System", "ConfigurationChange", "Modify Task Config.MailServer", tBoth))
    Do tRows.%Push($ClassMethod(..#MODEL, "Row", "%System", "%Security", "SystemChange", ..#PREFIX, tBoth))
    Do tRows.%Push($ClassMethod(..#MODEL, "Row", "%System", "%System", "ConfigurationChange", ..#PREFIX _ "Extra", tBoth))
    Do tRows.%Push($ClassMethod(..#MODEL, "Row", "%System", "%System", "ConfigurationChange", ..#PREFIX, tWrapped))
    Do $ClassMethod(..#PORT, "MaskVendorSecrets", tRows)
    Do $$$AssertEquals(tRows.%Get(0).%Get("EventData"), "  Old value: " _ tMask _ tCrlf _ "  New value: " _ tMask, "a declared row's two lines are masked")
    Do $$$AssertEquals(tRows.%Get(1).%Get("EventData"), "  Old value: " _ tCrlf _ "  New value: " _ tMask, "an empty old value stays empty")
    Do $$$AssertEquals(tRows.%Get(2).%Get("EventData"), "  Old value: " _ tMask _ tCrlf _ "  New value: ", "and so does an empty new value")
    Do $$$AssertEquals(tRows.%Get(3).%Get("EventData"), tBoth, "another Task Config row is unchanged")
    Do $$$AssertEquals(tRows.%Get(4).%Get("EventData"), tBoth, "and so is the same text under another vendor event")
    Do $$$AssertEquals(tRows.%Get(5).%Get("EventData"), tBoth, "and a description that only begins with the declared words")
    Do $$$AssertTrue(tLong [ tCrlf, "the long probe's Base64 runs onto a second line")
    Do $$$AssertEquals(tRows.%Get(6).%Get("EventData"), "  Old value: " _ tMask _ tCrlf _ "  New value: " _ tMask, "a long value is masked with the line it continues onto")
}

/// <p>AC1, set: from an empty password, <code>AuthPassSet</code> writes a row whose old value is empty
/// and whose new value is the probe's Base64; both reads answer the new value masked.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Port.AuditPort.VENDORCONFIGSECRETS</parameter> --
/// both reads carry the Base64 value and this goes red.</p>
Method TestSettingThePasswordReadsMasked()
{
    Do $$$AssertStatusOK(..Arm(""), "the password starts empty")
    Set tSince = $ZDateTime($Horolog, 3)
    Set tUtcSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tNew = ..Encoded(..#FIRSTPROBE)
    Do $$$AssertStatusOK(..Arm(..#FIRSTPROBE, 0), "the password is set")
    Do $$$AssertTrue($ClassMethod(..#MODEL, "VendorCarries", tUtcSince, tNew, ..#EVENT) >= 1, "and the vendor's own row carries the Base64 value")
    Do ..AssertRead(tSince, $ListBuild(tNew, ..#FIRSTPROBE), "", $Parameter(..#PORT, "MASK"))
}

/// <p>AC1, change: from one probe password to another, both lines are Base64 values; both reads answer
/// both masked and neither value appears.</p>
/// <p>Mutation (Rule 19): as <method>TestSettingThePasswordReadsMasked</method>.</p>
Method TestChangingThePasswordReadsMasked()
{
    Do $$$AssertStatusOK(..Arm(..#FIRSTPROBE), "the password starts as the first probe")
    Set tSince = $ZDateTime($Horolog, 3)
    Set tUtcSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tOld = ..Encoded(..#FIRSTPROBE)
    Set tNew = ..Encoded(..#SECONDPROBE)
    Do $$$AssertStatusOK(..Arm(..#SECONDPROBE, 0), "the password is changed")
    Do $$$AssertTrue(($ClassMethod(..#MODEL, "VendorCarries", tUtcSince, tOld, ..#EVENT) >= 1) && ($ClassMethod(..#MODEL, "VendorCarries", tUtcSince, tNew, ..#EVENT) >= 1), "and the vendor's own row carries both Base64 values")
    Set tMask = $Parameter(..#PORT, "MASK")
    Do ..AssertRead(tSince, $ListBuild(tOld, tNew, ..#FIRSTPROBE, ..#SECONDPROBE), tMask, tMask)
}

/// <p>AC1, clear: from a probe password to an empty one, the old value is a Base64 value and the new
/// value is empty; both reads answer the old value masked and the new value empty.</p>
/// <p>Mutation (Rule 19): as <method>TestSettingThePasswordReadsMasked</method>.</p>
Method TestClearingThePasswordReadsMasked()
{
    Do $$$AssertStatusOK(..Arm(..#SECONDPROBE), "the password starts as the second probe")
    Set tSince = $ZDateTime($Horolog, 3)
    Set tUtcSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tOld = ..Encoded(..#SECONDPROBE)
    Do $$$AssertStatusOK(..Arm("", 0), "the password is cleared")
    Do $$$AssertTrue($ClassMethod(..#MODEL, "VendorCarries", tUtcSince, tOld, ..#EVENT) >= 1, "and the vendor's own row carries the Base64 value")
    Do ..AssertRead(tSince, $ListBuild(tOld, ..#SECONDPROBE), $Parameter(..#PORT, "MASK"), "")
}

/// <p>Assert that the audit screen's read over the wire and <code>logs.audit.read</code> each answer
/// exactly one row of the declared event since <var>pSince</var>, carry no line of any value in the
/// list <var>pValues</var> anywhere in the answer, and read <var>pOld</var> and <var>pNew</var> on the row's
/// <code>Old value</code> and <code>New value</code> lines.</p>
Method AssertRead(pSince As %String, pValues As %List, pOld As %String, pNew As %String)
{
    Set tPrefixes = $ListBuild(..#PREFIX)
    Set tSC = $ClassMethod(..#MODEL, "ReadScreen", "ConfigurationChange", pSince, "MailAuthPassword", tPrefixes, .tStatus, .tRaw, .tScreen)
    Do $$$AssertStatusOK(tSC, "the audit screen's read is sent")
    Do $$$AssertEquals(tStatus, 200, "the audit screen's read answers: " _ $Extract(tRaw, 1, 200))
    Do ..AssertAnswer($Get(tScreen), tRaw, pValues, pOld, pNew, "the screen's read")

    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#TOOLNAME, .tTool)
    Do $$$AssertStatusOK(tSC, "the read tool resolves")
    Set tSC = $ClassMethod(..#MODEL, "ReadTool", tTool, "ConfigurationChange", pSince, "MailAuthPassword", tPrefixes, .tResult, .tRows)
    Do $$$AssertStatusOK(tSC, "logs.audit.read answers")
    Do ..AssertAnswer($Get(tRows), $Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: ""), pValues, pOld, pNew, "logs.audit.read")
}

/// <p>The assertions of <method>AssertRead</method> on one answer: <var>pRows</var> its rows,
/// <var>pText</var> its whole text, <var>pWho</var> what to call it.</p>
Method AssertAnswer(pRows, pText As %String, pValues As %List, pOld As %String, pNew As %String, pWho As %String)
{
    Set tCount = 0
    Set tOld = ""
    Set tNew = ""
    If $IsObject(pRows) {
        Set tIterator = pRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) || ($Extract(tRow.%Get("Description"), 1, $Length(..#PREFIX)) '= ..#PREFIX) Continue
            Set tCount = tCount + 1
            Set tData = tRow.%Get("EventData")
            Set tBreak = $Select(tData [ $Char(13, 10): $Char(13, 10), 1: $Char(10))
            For tI = 1:1:$Length(tData, tBreak) {
                Set tLine = $ZStrip($Piece(tData, tBreak, tI), "<>W")
                If $Extract(tLine, 1, 10) = "Old value:" Set tOld = $ZStrip($Extract(tLine, 11, *), "<>W")
                If $Extract(tLine, 1, 10) = "New value:" Set tNew = $ZStrip($Extract(tLine, 11, *), "<>W")
            }
        }
    }
    Do $$$AssertEquals(tCount, 1, pWho _ " answers exactly one declared row")
    Set tPosition = 0
    While $ListNext(pValues, tPosition, tValue) {
        For tP = 1:1:$Length(tValue, $Char(13, 10)) {
            Do $$$AssertEquals(pText [ $Piece(tValue, $Char(13, 10), tP), 0, pWho _ " carries no line of a probe value or its Base64")
        }
    }
    Do $$$AssertEquals(tOld, pOld, pWho _ ": the old value line reads as expected")
    Do $$$AssertEquals(tNew, pNew, pWho _ ": the new value line reads as expected")
}

/// <p>The Base64 value the vendor stores for <var>pPassword</var>.</p>
ClassMethod Encoded(pPassword As %String) As %String
{
    Quit $System.Encryption.Base64Encode(pPassword)
}

/// <p>Set the mail password to <var>pPassword</var> through <code>%SYS.Task.Config.AuthPassSet</code>.
/// With <var>pWait</var> true, wait past the audit clock's second afterward, so a since-time taken next
/// sees none of the row this set wrote.</p>
ClassMethod Arm(pPassword As %String, pWait As %Boolean = 1) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(%SYS.Task.Config).AuthPassSet(pPassword)
        Set $NAMESPACE = tOrigNS
    } Catch tEx {
        Set $NAMESPACE = tOrigNS
        Set tSC = tEx.AsStatus()
    }
    If pWait Hang 1.1
    Quit tSC
}

/// <p>The stored value of the mail password setting, as the vendor keeps it.</p>
ClassMethod Stored() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tValue = ""
    Try {
        Set $NAMESPACE = "%SYS"
        Set tValue = ##class(%SYS.Task.Config).GetData("MailAuthPassword")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tValue
}

/// <p>Write <var>pValue</var>, a value <method>Stored</method> returned, back as the stored value.</p>
ClassMethod Store(pValue As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(%SYS.Task.Config).UpdateData("MailAuthPassword", pValue)
        Set $NAMESPACE = tOrigNS
    } Catch tEx {
        Set $NAMESPACE = tOrigNS
        Set tSC = tEx.AsStatus()
    }
    Quit tSC
}

}
