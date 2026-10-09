/// <p>Subclass of <class>OcuPilot.Port.AtelierPort</class> that reaches its private <code>Route</code> for the
/// one call a create makes and no public entry makes alone: the vendor's <code>PutDoc</code> with no
/// <code>If-None-Match</code> and no <code>ignoreConflict</code>, after the taken check.
/// <class>OcuPilot.Test.AtelierPortScriptRun</class> asks it what the vendor does with a name that was taken
/// after the check.</p>
Class OcuPilot.Test.AtelierPortPutProbe Extends OcuPilot.Port.AtelierPort
{

/// <p>Put the whole text <var>pText</var> as document <var>pName</var> in <var>pNamespace</var> through the
/// port's own route call, sending no version. <var>pHttpStatus</var> and <var>pFault</var> are the port's
/// outcome for the vendor's answer: a document the vendor refuses is a failing status with its 409.</p>
ClassMethod PutWithoutVersion(pNamespace As %String, pName As %String, pText As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tHighest = +..HighestVersion()
    Set tVersion = $Select(tHighest > ..#PINNEDVERSION: ..#PINNEDVERSION, 1: tHighest)
    Set tDocument = {"enc": false}
    Do tDocument.%Set("content", ..SavedLines(pText))
    Kill tNoParams
    Quit ..Route(tVersion, pNamespace, "PutDoc", pName, .tNoParams, tDocument, .tAnswer, .pHttpStatus, .pFault, 0, , , "")
}

}
