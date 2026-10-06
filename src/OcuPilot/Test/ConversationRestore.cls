/// <p>Pins that restoring a conversation whose JSON exceeds one ObjectScript string answers 200
/// with every turn in one envelope (AD-12, AD-39): ten entries of about 420 KB of step text, one
/// carrying a non-ASCII character that must round-trip.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and the suite's HTTP
/// account owning the conversation it seeds. It creates one conversation and removes it again.</p>
Class OcuPilot.Test.ConversationRestore Extends %UnitTest.TestCase
{

/// <p>Entries seeded.</p>
Parameter ENTRIES = 10;

/// <p>Characters of step text per entry.</p>
Parameter STEPCHARS = 420000;

/// <p>The conversation seeded, which <method>OnAfterOneTest</method> removes.</p>
Property SeededKey As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..SeededKey = ""
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tSC = $$$OK
    If ..SeededKey '= "" {
        Set tSC = ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(..SeededKey)
        Set ..SeededKey = ""
    }
    Quit tSC
}

/// <p>A restore of ten large entries answers 200, one envelope, ten turns, the non-ASCII character
/// intact.</p>
/// <p>Mutation (Rule 19): write <code>pData.%ToJSON()</code> as one string in
/// <method>OcuPilot.Api.Response.JSON</method> -> the status is 500.</p>
Method TestALargeConversationRestoresInOneEnvelope()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", tUser, 5, .tStatus, .tConflict)
    Do $$$AssertStatusOK(tStatus, "a conversation is created")
    If '$IsObject(tConvo) Quit
    Set tKey = tConvo.ConvKey
    Set tConvo = ""
    Set ..SeededKey = tKey
    Set tLimits = "OcuPilot.Kernel.Agent.Limits"
    Set tText = $Extract($Justify("", ..#STEPCHARS), 1, ..#STEPCHARS - 1) _ $Char(233)
    Set tText = $Translate(tText, " ", "x")
    Set tSteps = "[{""seq"":1,""kind"":""tool"",""name"":""probe"",""text"":""" _ tText _ """}]"
    For tI = 1:1:..#ENTRIES {
        Set tAppendSC = ##class(OcuPilot.Kernel.State.Entry).GuardedAppend(tKey, "message " _ tI, "done", "reply " _ tI, "", 0, tSteps, 0, tLimits)
        Do $$$AssertStatusOK(tAppendSC, "entry " _ tI _ " is appended")
    }
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = ##class(OcuPilot.Test.Http).GetTestServer()
    Set tReq.Port = ##class(OcuPilot.Test.Http).GetTestPort()
    Set tReq.Username = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tReq.Password = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tReq.Timeout = 120
    Set tGetSC = tReq.Get("/api/ocupilot/conversation/" _ tKey)
    Do $$$AssertStatusOK(tGetSC, "the request completes")
    Set tHttpStatus = tReq.HttpResponse.StatusCode
    Do $$$AssertEquals(tHttpStatus, 200, "the restore answers 200")
    If tHttpStatus '= 200 Quit
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tReq.HttpResponse.Data)
    Do $$$AssertEquals(tBody.turns.%Size(), ..#ENTRIES, "every turn is in the one envelope")
    Set tLastText = tBody.turns.%Get(..#ENTRIES - 1).steps.%Get(0).text
    Do $$$AssertEquals($Length(tLastText), ..#STEPCHARS, "the last turn's step text keeps its length")
    Do $$$AssertEquals($Extract(tLastText, *), $Char(233), "and its non-ASCII character round-trips")
}

}
