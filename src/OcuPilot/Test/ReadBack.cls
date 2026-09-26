/// <p>Pins <class>OcuPilot.Kernel.Proposal.ReadBack</class> (AD-58, Story 16.17): the default
/// comparison rules, each declared mode, each write kind's verdict and the rule that no value
/// leaves the comparison. Every re-read goes through <class>OcuPilot.Test.ReadBackPort</class>, so
/// nothing here reads or changes the instance; it needs only the compiled tool classes and the
/// generated <class>OcuPilot.Screen.Tool.ToolFields</class>.</p>
Class OcuPilot.Test.ReadBack Extends %UnitTest.TestCase
{

Parameter RB = "OcuPilot.Kernel.Proposal.ReadBack";

Parameter PORT = "OcuPilot.Test.ReadBackPort";

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ReadBackPort).Reset()
    Quit $$$OK
}

/// <p>The re-read of <var>pTool</var> armed with <var>pStatus</var> and <var>pRead</var>, having
/// sent <var>pSent</var> over <var>pFresh</var>.</p>
Method ReadBackOf(pTool As %String, pStatus As %Integer, pRead As %String, pSent As %DynamicObject, pFresh As %DynamicObject = "", pPayload As %String = "{}") As %DynamicObject
{
    Do ##class(OcuPilot.Test.ReadBackPort).Arm(pStatus, pRead)
    Quit $ClassMethod(..#RB, "Of", pTool, "probe", pSent, pFresh, pPayload, ..#PORT)
}

Method TestTheDefaultRules()
{
    Set tRB = ..#RB
    Do $$$AssertTrue($ClassMethod(tRB, "Compare", {"A": ""}, {}, "A"), "an empty string and an absent member are equal")
    Do $$$AssertTrue($ClassMethod(tRB, "Compare", {"A": []}, {"A": null}, "A"), "an empty array and null are equal")
    Do $$$AssertTrue($ClassMethod(tRB, "Compare", {"A": {}}, {"A": ""}, "A"), "an empty object and an empty string are equal")
    Do $$$AssertTrue($ClassMethod(tRB, "Compare", {"A": 0}, {"A": false}, "A"), "0 reads back as false")
    Do $$$AssertTrue($ClassMethod(tRB, "Compare", {"A": "true"}, {"A": true}, "A"), "the string true reads back as true")
    Do $$$AssertTrue($ClassMethod(tRB, "Compare", {"A": ""}, {"A": false}, "A"), "an empty string reads back as false")
    Do $$$AssertTrue('$ClassMethod(tRB, "Compare", {"A": "1"}, {"A": false}, "A"), "1 does not read back as false")
    Do $$$AssertTrue($ClassMethod(tRB, "Compare", {"A": "0900"}, {"A": 900}, "A"), "0900 reads back as 900 by value")
    Do $$$AssertTrue($ClassMethod(tRB, "Compare", {"A": "28800"}, {"A": 28800}, "A"), "a number sent as a string reads back as the number")
    Do $$$AssertTrue('$ClassMethod(tRB, "Compare", {"A": "x"}, {"A": "y"}, "A"), "two different strings differ")
    Do $$$AssertTrue('$ClassMethod(tRB, "Compare", {"A": "x"}, {}, "A"), "a sent value the read lacks differs")
    Do $$$AssertTrue('$ClassMethod(tRB, "Compare", {"A": ["b","a"]}, {"A": ["a","b"]}, "A"), "an array keeps its order by default")
    Do $$$AssertTrue($ClassMethod(tRB, "Compare", {"A": ["a","b"]}, {"A": ["a","b"]}, "A"), "and an array in the same order is equal")
}

Method TestEachDeclaredMode()
{
    Set tRB = ..#RB
    Do $$$AssertTrue($ClassMethod(tRB, "Compare", {"A": ["%SQL","%Developer","%Operator"]}, {"A": ["%Developer","%Operator","%SQL"]}, "A", "unordered"), "unordered: a sorted read of the same members matches")
    Do $$$AssertTrue('$ClassMethod(tRB, "Compare", {"A": ["x","x"]}, {"A": ["x"]}, "A", "unordered"), "unordered: a multiset, so a lost duplicate differs")
    Do $$$AssertTrue($ClassMethod(tRB, "Compare", {"A": "https://h/cb/"}, {"A": "https://h/cb"}, "A", "unslashed"), "unslashed: one trailing slash is dropped")
    Do $$$AssertTrue('$ClassMethod(tRB, "Compare", {"A": "https://h/a"}, {"A": "https://h/b"}, "A", "unslashed"), "unslashed: a different path still differs")
    Do $$$AssertTrue($ClassMethod(tRB, "Compare", {"A": " openid   profile "}, {"A": "openid profile"}, "A", "words"), "words: whitespace is collapsed")
    Do $$$AssertTrue($ClassMethod(tRB, "Compare", {"A": "WR"}, {"A": "RW"}, "A", "letters"), "letters: WR reads back as RW")
    Do $$$AssertTrue('$ClassMethod(tRB, "Compare", {"A": "RWU"}, {"A": "RW"}, "A", "letters"), "letters: a lost letter differs")
    Do $$$AssertTrue($ClassMethod(tRB, "Compare", {"A": {"a": "1", "b": ""}}, {"A": {"a": "1", "c": "z"}}, "A", "members"), "members: only the members sent, empty equal to absent")
    Do $$$AssertTrue('$ClassMethod(tRB, "Compare", {"A": {"a": "1"}}, {"A": {"a": "2"}}, "A", "members"), "members: a sent member read back otherwise differs")
}

Method TestAMergeThatHoldsWhatWasSentMatches()
{
    Set tRead = {"Name": "/csp/probe", "Timeout": 900, "Enabled": false, "Description": "probe"}
    Set tAnswer = ..ReadBackOf("OcuPilot.Screen.Tool.WebAppUpdate", 200, tRead.%ToJSON(), {"Name": "/csp/probe", "Timeout": "0900", "Enabled": 0, "Description": "probe"})
    Do $$$AssertEquals(tAnswer.verdict, "matches", "Timeout 0900 and Enabled 0 read back as 900 and false: " _ tAnswer.%ToJSON())
    Do $$$AssertEquals(tAnswer.fields.%Size(), 0, "and no field differs")
    Do $$$AssertEquals(^||OcuPilotReadBackPort("types", 1), "GET", "the re-read is the tool's own read type")
}

Method TestAChangedValueDiffersByName()
{
    Set tAnswer = ..ReadBackOf("OcuPilot.Screen.Tool.WebAppUpdate", 200, {"Description": "changed by the vendor", "Enabled": true}.%ToJSON(), {"Description": "sent text", "Enabled": 1})
    Do $$$AssertEquals(tAnswer.verdict, "differs", "a different Description is differs")
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), "[""Description""]", "naming only Description")
    Do $$$AssertTrue(tAnswer.%ToJSON() '[ "sent text", "no sent value is in the answer")
    Do $$$AssertTrue(tAnswer.%ToJSON() '[ "changed by the vendor", "and no read value is in the answer")
}

/// <p>Mutation (Rule 19): answer <code>matches</code> for a 404 re-read in
/// <method>OcuPilot.Kernel.Proposal.ReadBack.Of</method> -> this goes red.</p>
Method TestAnUpdateWhoseTargetIsGoneIsNotFound()
{
    Set tAnswer = ..ReadBackOf("OcuPilot.Screen.Tool.WebAppUpdate", 404, "", {"Description": "x"})
    Do $$$AssertEquals(tAnswer.verdict, "notFound", "an update whose re-read is 404 is notFound, never matches")
}

/// <p>A merge with no sent object to compare is <code>unchecked</code>, never a <code>matches</code>
/// over an empty set.</p>
Method TestAMergeWithNothingToCompareIsUnchecked()
{
    Set tAnswer = ..ReadBackOf("OcuPilot.Screen.Tool.WebAppUpdate", 200, {"Description": "d"}.%ToJSON(), "")
    Do $$$AssertEquals(tAnswer.verdict _ "/" _ tAnswer.reason, "unchecked/unreadable", "no sent body reads unchecked, unreadable: " _ tAnswer.%ToJSON())
}

Method TestARefusedReReadIsUncheckedUnreadable()
{
    For tStatus = 403, 500 {
        Set tAnswer = ..ReadBackOf("OcuPilot.Screen.Tool.WebAppUpdate", tStatus, "", {"Description": "x"})
        Do $$$AssertEquals(tAnswer.verdict, "unchecked", "a re-read answered " _ tStatus _ " is unchecked")
        Do $$$AssertEquals(tAnswer.reason, "unreadable", "with reason unreadable")
    }
    Set tRunning = $ClassMethod(..#RB, "Running")
    Do $$$AssertEquals(tRunning.verdict _ "/" _ tRunning.reason, "unchecked/running", "a queued write is unchecked, running")
}

Method TestADeleteExpectsAbsence()
{
    Set tGone = ..ReadBackOf("OcuPilot.Screen.Tool.WebAppDelete", 404, "", "")
    Do $$$AssertEquals(tGone.verdict, "notFound", "a delete whose target re-reads 404 is notFound")
    Set tStill = ..ReadBackOf("OcuPilot.Screen.Tool.WebAppDelete", 200, {"Name": "/csp/probe"}.%ToJSON(), "")
    Do $$$AssertEquals(tStill.verdict, "present", "a delete whose target still answers is present")
}

/// <p>The application-error delete's set re-read: gone when none of the enumerated
/// <code>(date, errorNumber, time)</code> re-enumerates.</p>
Method TestTheErrorDeleteIsGoneWhenNoEnumeratedIdReEnumerates()
{
    Set tPayload = {"namespace": "USER", "entries": [{"date": "09/26/2026", "errorNumber": 1, "time": "10:00:00"}, {"date": "09/26/2026", "errorNumber": 2, "time": "10:01:00"}]}
    Set tNone = {"namespace": "USER", "entries": [], "count": 0, "truncated": false}
    Set tOne = {"namespace": "USER", "entries": [{"date": "09/26/2026", "errorNumber": 2, "time": "10:01:00"}], "count": 1, "truncated": false}
    Set tReused = {"namespace": "USER", "entries": [{"date": "09/26/2026", "errorNumber": 1, "time": "11:30:00"}], "count": 1, "truncated": false}
    Set tAnswer = ..ReadBackOf("OcuPilot.Screen.Tool.ErrorDelete", 200, tNone.%ToJSON(), "", "", tPayload.%ToJSON())
    Do $$$AssertEquals(tAnswer.verdict, "notFound", "none re-enumerates: notFound")
    Set tAnswer = ..ReadBackOf("OcuPilot.Screen.Tool.ErrorDelete", 200, tOne.%ToJSON(), "", "", tPayload.%ToJSON())
    Do $$$AssertEquals(tAnswer.verdict, "present", "one re-enumerates: present")
    Do $$$AssertTrue(##class(OcuPilot.Screen.Tool.ErrorDelete).ReadBackGone(tReused, tPayload), "a reused number with another Time is not one of the enumerated ids")
}

/// <p>Mutation (Rule 19): compare a secret's sent value with its re-read value in
/// <method>OcuPilot.Kernel.Proposal.ReadBack.Compared</method> -> this goes red.</p>
Method TestASecretIsWrittenAndItsReadValueIsNeverExamined()
{
    Set tAnswer = ..ReadBackOf("OcuPilot.Screen.Tool.SslUpdate", 200, {"Description": "d", "PrivateKeyPassword": "whatever the read says"}.%ToJSON(), {"Description": "d", "PrivateKeyPassword": "supplied-secret"}, {"Description": "d"})
    Do $$$AssertEquals(tAnswer.verdict, "matches", "a secret whose read value differs does not make the write differ: " _ tAnswer.%ToJSON())
    Do $$$AssertEquals(tAnswer.written.%ToJSON(), "[""PrivateKeyPassword""]", "it is listed written")
    Do $$$AssertTrue(tAnswer.%ToJSON() '[ "supplied-secret", "and its value is not in the answer")
    Set tCarried = ..ReadBackOf("OcuPilot.Screen.Tool.SslUpdate", 200, {"Description": "d"}.%ToJSON(), {"Description": "d", "PrivateKeyPassword": "held"}, {"Description": "d", "PrivateKeyPassword": "held"})
    Do $$$AssertEquals(tCarried.written.%Size(), 0, "a secret the merge carried unchanged is not written")
    Set tOnly = ..ReadBackOf("OcuPilot.Screen.Tool.UserPassword", 200, {"Name": "probe"}.%ToJSON(), {"Password": "supplied-secret"})
    Do $$$AssertEquals(tOnly.verdict, "written", "a secret-only write is written")
    Do $$$AssertEquals(tOnly.written.%ToJSON(), "[""Password""]", "naming its secret")
    Do $$$AssertTrue(tOnly.%ToJSON() '[ "supplied-secret", "and never its value")
}

Method TestAnActionStyleWriteSendsNothingToCompare()
{
    For tTool = "OcuPilot.Screen.Tool.TaskSuspend", "OcuPilot.Screen.Tool.ProcessResume", "OcuPilot.Screen.Tool.TaskRun" {
        Set tAnswer = ..ReadBackOf(tTool, 200, {"Suspended": true}.%ToJSON(), "")
        Do $$$AssertEquals(tAnswer.verdict, "nothingSent", tTool _ " is nothingSent")
    }
    Set tGone = ..ReadBackOf("OcuPilot.Screen.Tool.TaskSuspend", 404, "", "")
    Do $$$AssertEquals(tGone.verdict, "notFound", "and a gone target is notFound")
}

/// <p>Mutation (Rule 19): remove <code>GrantedRoles</code> from
/// <code>permissions.roles.update</code>'s <code>compare</code> and regenerate -> this goes red.</p>
Method TestADeclaredUnorderedListMatchesReordered()
{
    Set tSent = {"Description": "d", "GrantedRoles": ["%Operator", "%Developer"], "Resources": [{"Name": "%Development", "Permissions": "U"}, {"Name": "%Admin_Operate", "Permissions": "U"}], "EscalationOnly": false}
    Set tRead = {"Description": "d", "GrantedRoles": ["%Developer", "%Operator"], "Resources": [{"Name": "%Admin_Operate", "Permissions": "U"}, {"Name": "%Development", "Permissions": "U"}], "EscalationOnly": false}
    Set tAnswer = ..ReadBackOf("OcuPilot.Screen.Tool.RoleUpdate", 200, tRead.%ToJSON(), tSent)
    Do $$$AssertEquals(tAnswer.verdict, "matches", "GrantedRoles and Resources read back sorted match: " _ tAnswer.%ToJSON())
    Set tCreate = ..ReadBackOf("OcuPilot.Screen.Tool.RoleCreate", 200, tRead.%ToJSON(), tSent)
    Do $$$AssertEquals(tCreate.verdict, "matches", "and so does the create's")
}

Method TestTheKindIsDerivedFromTheToolsParameters()
{
    Set tRB = ..#RB
    Do $$$AssertEquals($ClassMethod(tRB, "KindOf", "OcuPilot.Screen.Tool.WebAppUpdate"), "merge", "a body-sending change is a merge")
    Do $$$AssertEquals($ClassMethod(tRB, "KindOf", "OcuPilot.Screen.Tool.WebAppCreate"), "create", "CREATES is a create")
    Do $$$AssertEquals($ClassMethod(tRB, "KindOf", "OcuPilot.Screen.Tool.WebAppDelete"), "delete", "CHANGEACTION deleted is a delete")
    Do $$$AssertEquals($ClassMethod(tRB, "KindOf", "OcuPilot.Screen.Tool.ProcessTerminate"), "delete", "a bodyless write that removes its target is a delete")
    Do $$$AssertEquals($ClassMethod(tRB, "KindOf", "OcuPilot.Screen.Tool.UserPassword"), "secret", "SECRETBODY is secret-only")
    Do $$$AssertEquals($ClassMethod(tRB, "KindOf", "OcuPilot.Screen.Tool.TaskResume"), "action", "a bodyless write is action-style")
}

}
