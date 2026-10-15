/// <p>Pins the sweep every armed message suite ends with (Story 20.31, <method>OcuPilot.Test.ProductionProbe.HighWater</method> and
/// <method>OcuPilot.Test.ProductionProbe.SweepSince</method>): the sweep removes each header above its mark with the body that header
/// names -- the persistent request, the HL7 document and the stream alike, each read from the header and not from an index that spells
/// the class in capitals -- and keeps a body a header at or below the mark still names, as a resend shares its original's; it removes
/// the log rows above the mark and nothing at or below; it answers what is left above the mark; and a mark that is not a pair of
/// numbers sweeps nothing.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code>, an interoperability-enabled
/// <code>USER</code> namespace, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a probe
/// production in <code>USER</code></b>, stores messages in it and deletes them (<class>OcuPilot.Test.InteropResendCase</class>). The
/// sweeps here start at a mark of their own, taken after the suite's, so the suite's own sweep still finds nothing left. One class per
/// run.</p>
Class OcuPilot.Test.InteropResendSweep Extends OcuPilot.Test.InteropResendCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>Whether the body <var>pClass</var> <var>pId</var> exists in <code>USER</code>.</p>
ClassMethod Exists(pClass As %String, pId As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tExists = $ClassMethod(pClass, "%ExistsId", pId)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tExists
}

/// <p>The header <var>pId</var> in <code>USER</code>: <code>1</code> when it exists.</p>
ClassMethod HeaderExists(pId As %String) As %Boolean
{
    Quit ..Exists("Ens.MessageHeader", pId)
}

/// <p>How many event-log rows <code>USER</code> holds above the id <var>pAbove</var>.</p>
ClassMethod LogsAbove(pAbove As %Integer) As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Ens_Util.Log WHERE ID > ?", pAbove)
        If tRS.%Next() Set tCount = +tRS.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>One event-log row in <code>USER</code>, through the vendor's own logger; the number of rows above the id <var>pAbove</var> after
/// it.</p>
ClassMethod LogOne(pAbove As %Integer) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Do ##class(Ens.Util.Log).LogInfo("OcuPilot.Test.InteropResendSweep", "sweep", "a row to sweep")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit ..LogsAbove(pAbove)
}

/// <p>The vendor's resend of the message header <var>pId</var> in <code>USER</code>: the new header's id in <var>pNew</var>.</p>
ClassMethod Resend(pId As %String, Output pNew As %String) As %Status
{
    Set pNew = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ##class(Ens.MessageHeader).ResendDuplicatedMessage(pId, .pNew)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The mark is the pair <code>&lt;highest header id&gt;|&lt;highest log id&gt;</code>; the sweep removes the headers, their persistent,
/// document and stream bodies, and the log rows made after it, and answers <code>0|0</code>; the body a header at or below the mark names
/// survives the sweep of the resend that shares it, as does that header.</p>
/// <p>Mutation (Rule 19): read the class of each body in upper case in <method>OcuPilot.Test.ProductionProbe.SweepSince</method> -- the
/// bodies of the three kinds stay and this goes red; delete a body without asking whether a header at or below the mark names it -- the
/// shared body goes and this goes red.</p>
Method TestTheSweepRemovesWhatAboveTheMarkAndKeepsWhatAHeaderBelowItNames()
{
    Set tOld = ..Make("old")
    Set tOldClass = $ClassMethod(..#FIXTURE, "Property", tOld, "MessageBodyClassName")
    Set tOldBody = $ClassMethod(..#FIXTURE, "Property", tOld, "MessageBodyId")
    Set tMark = $ClassMethod(..#PROBE, "HighWater")
    Do $$$AssertTrue($Match(tMark, "^[0-9]+\|[0-9]+$"), "the mark is a pair of numbers: " _ tMark)
    Set tLogMark = +$Piece(tMark, "|", 2)
    Set tNew = ..Make("new")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "StreamBody", "streamed", ..#OPNAME, .tStream), "a stream is stored as a body")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Hl7", $Parameter("OcuPilot.Test.InteropTestFixture", "DOCUMENTTEXT"), ..#OPNAME, .tHl7), "so is an HL7 message")
    Set tNewClass = $ClassMethod(..#FIXTURE, "Property", tNew, "MessageBodyClassName")
    Set tNewBody = $ClassMethod(..#FIXTURE, "Property", tNew, "MessageBodyId")
    Set tStreamClass = $ClassMethod(..#FIXTURE, "Property", tStream, "MessageBodyClassName")
    Set tStreamBody = $ClassMethod(..#FIXTURE, "Property", tStream, "MessageBodyId")
    Set tHl7Class = $ClassMethod(..#FIXTURE, "Property", tHl7, "MessageBodyClassName")
    Set tHl7Body = $ClassMethod(..#FIXTURE, "Property", tHl7, "MessageBodyId")
    Do $$$AssertEquals(tNewClass _ "|" _ tStreamClass _ "|" _ tHl7Class, "Ens.StringRequest|%Stream.GlobalCharacter|EnsLib.HL7.Message", "the three bodies are of three kinds")
    Do $$$AssertTrue(..Exists(tNewClass, tNewBody) && ..Exists(tStreamClass, tStreamBody) && ..Exists(tHl7Class, tHl7Body), "and exist")
    Do $$$AssertStatusOK(..Resend(tOld, .tShared), "the old message is resent, so a header above the mark names the body below it")
    Do $$$AssertTrue(+..LogOne(tLogMark) > 0, "a log row is made above the mark")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the production is stopped, so nothing else is written")
    Set tLeft = $ClassMethod(..#PROBE, "SweepSince", tMark)
    Do $$$AssertEquals(tLeft, "0|0", "the sweep answers nothing left above the mark")
    Do $$$AssertEquals(..HeaderExists(tNew) _ ..HeaderExists(tStream) _ ..HeaderExists(tHl7) _ ..HeaderExists(tShared), "0000", "every header above the mark is gone")
    Do $$$AssertEquals(..Exists(tNewClass, tNewBody) _ ..Exists(tStreamClass, tStreamBody) _ ..Exists(tHl7Class, tHl7Body), "000", "with its persistent, stream and HL7 body")
    Do $$$AssertEquals(..LogsAbove(tLogMark), 0, "and every log row above the mark")
    Do $$$AssertEquals(..HeaderExists(tOld) _ ..Exists(tOldClass, tOldBody), "11", "while the header at the mark and the body its resend shared are kept")
}

/// <p>A mark that is not <code>&lt;digits&gt;|&lt;digits&gt;</code> -- empty, one number, a word, an extra piece, a negative id -- sweeps
/// nothing and answers <code>?|?</code>, so a failed read of the mark never becomes a sweep of the whole store.</p>
/// <p>Mutation (Rule 19): drop the pattern test at the top of <method>OcuPilot.Test.ProductionProbe.SweepSince</method> -- the empty
/// mark deletes the suite's messages and this goes red.</p>
Method TestAMarkThatIsNotAPairOfNumbersSweepsNothing()
{
    Set tA = ..Make("alpha")
    Set tTop = $ClassMethod(..#FIXTURE, "TopId")
    For tMark = "", "12", "a|b", "12|", "|12", "1|2|3", "-1|-1", "1.5|2" {
        Do $$$AssertEquals($ClassMethod(..#PROBE, "SweepSince", tMark), "?|?", "'" _ tMark _ "' sweeps nothing")
    }
    Do $$$AssertTrue(..HeaderExists(tA) && ($ClassMethod(..#FIXTURE, "TopId") = tTop), "and the message is still there")
}

}
