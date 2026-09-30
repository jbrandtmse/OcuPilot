/// <p>Stand-in <code>LanguageServer</code> endpoint for <class>OcuPilot.Test.LanguageServer</class>,
/// reached through <method>OcuPilot.Test.PortFixture.SetEndpointClass</method>: an
/// <class>OcuPilot.Test.EndpointFixture</class> that also declares <code>ACTIVITY</code>,
/// <code>START</code> and <code>STOP</code>. An <code>ACTIVITY</code> call answers
/// <code>{Activity, CurrentlyRunning}</code> for a name <method>ArmServer</method> armed, its rows cut
/// at the seeded <code>maxRows</code> as the vendor's class query cuts them, and 404 for any other
/// name; each call's seeded <code>maxRows</code> is recorded. Every other type is the parent's.</p>
/// <p>State lives in <code>^||OcuPilotLanguageServerFixture</code>; <method>Clear</method> forgets it
/// and the parent's.</p>
Class OcuPilot.Test.LanguageServerEndpoint Extends OcuPilot.Test.EndpointFixture
{

/// <p>The vendor's type numbers, read on this build.</p>
Parameter TYPEACTIVITY As INTEGER = 10;

Parameter TYPESTART As INTEGER = 11;

Parameter TYPESTOP As INTEGER = 12;

/// <p>Declared so <class>OcuPilot.Test.LanguageServerSeamPort</class>'s gated delete reaches this
/// endpoint once its gate passes (Story 16.25); it answers as the parent's other types do.</p>
Parameter TYPEDELETE As INTEGER = 3;

/// <p>Arm server <var>pName</var>: whether it runs, and its activity rows as a JSON array, newest
/// first.</p>
ClassMethod ArmServer(pName As %String, pRunning As %Boolean, pRowsJson As %String = "[]")
{
    Set ^||OcuPilotLanguageServerFixture("running", pName) = ''pRunning
    Set ^||OcuPilotLanguageServerFixture("rows", pName) = pRowsJson
}

/// <p>The <code>maxRows</code> each <code>ACTIVITY</code> call was seeded with, comma-separated in
/// call order, an unseeded call reading as <code>-</code>.</p>
ClassMethod ActivityMaxRows() As %String
{
    Quit $Get(^||OcuPilotLanguageServerFixture("maxRows"), "")
}

/// <p>Forget every armed server and record, and the parent's.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotLanguageServerFixture
    Do ##super()
}

Method Run(ByRef pSC As %Status, pBody As %DynamicAbstractObject) As %DynamicAbstractObject
{
    If ..Type '= ..#TYPEACTIVITY Quit ##super(.pSC, pBody)
    Set tSeeded = $Get(%request.Data("maxRows", 1), "-")
    Set tSeen = $Get(^||OcuPilotLanguageServerFixture("maxRows"), "")
    Set ^||OcuPilotLanguageServerFixture("maxRows") = tSeen _ $Select(tSeen = "": "", 1: ",") _ tSeeded
    If (..Name = "") || '$Data(^||OcuPilotLanguageServerFixture("running", ..Name)) {
        Do ..SetRespStatus("404 Not Found")
        Quit {}
    }
    Set tRows = ##class(%DynamicArray).%FromJSON(^||OcuPilotLanguageServerFixture("rows", ..Name))
    Set tAnswer = []
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (+tSeeded > 0) && (tAnswer.%Size() >= +tSeeded) Quit
        Do tAnswer.%Push(tRow)
    }
    Set tResult = {}
    Do tResult.%Set("Activity", tAnswer)
    Do tResult.%Set("CurrentlyRunning", ^||OcuPilotLanguageServerFixture("running", ..Name), "boolean")
    Quit tResult
}

}
