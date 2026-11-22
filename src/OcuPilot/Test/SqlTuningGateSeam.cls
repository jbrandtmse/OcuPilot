/// <p>The gate class <class>OcuPilot.Test.SqlTuningPortFixture</class> evaluates through (Story 21.6): it records every pair set it is asked and
/// refuses the first pair whose permission <method>Deny</method> armed, so a test drives the port's 403 in process, with no principal. It
/// answers no pair held for an empty set, as the production gate does.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions. Its record is process-private.</p>
Class OcuPilot.Test.SqlTuningGateSeam Extends %RegisteredObject
{

/// <p>Forget what was armed and recorded.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotSqlTuningDeny, ^||OcuPilotSqlTuningAsked, ^||OcuPilotSqlTuningCalls, ^||OcuPilotSqlTuningRefuse
}

/// <p>Refuse every pair whose permission is <var>pPermission</var> until <method>Reset</method>.</p>
ClassMethod Deny(pPermission As %String)
{
    Set ^||OcuPilotSqlTuningDeny = pPermission
}

/// <p>The pair sets asked since <method>Reset</method>, one JSON text per call, joined by <code>;</code>.</p>
ClassMethod Asked() As %String
{
    Set tText = ""
    Set tKey = ""
    For {
        Set tKey = $Order(^||OcuPilotSqlTuningAsked(tKey))
        If tKey = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ ^||OcuPilotSqlTuningAsked(tKey)
    }
    Quit tText
}

/// <p>How many vendor calls <method>OcuPilot.Test.SqlTuningPortFixture.StatementCall</method> was asked.</p>
ClassMethod Calls() As %Integer
{
    Quit +$Get(^||OcuPilotSqlTuningCalls)
}

/// <p>Make <method>OcuPilot.Test.SqlTuningPortFixture.StatementCall</method> answer an error status, naming <var>pMessage</var>, until
/// <method>Reset</method>.</p>
ClassMethod Refuse(pMessage As %String)
{
    Set ^||OcuPilotSqlTuningRefuse = pMessage
}

/// <p>As <method>OcuPilot.Screen.Gate.EvaluateRequired</method>: the pairs held, or <var>pFailedPair</var> the first the armed permission names.</p>
ClassMethod EvaluateRequired(pPairs As %List, Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    If '$ListValid(pPairs) || ($ListLength(pPairs) = 0) Quit 0
    Set tText = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ $List($List(pPairs, tI), 1) _ ":" _ $List($List(pPairs, tI), 2)
        If ($Get(^||OcuPilotSqlTuningDeny) '= "") && ($List($List(pPairs, tI), 2) = ^||OcuPilotSqlTuningDeny) && (pFailedPair = "") Set pFailedPair = ##class(OcuPilot.Screen.Gate).SpellPair($List($List(pPairs, tI), 1), $List($List(pPairs, tI), 2))
    }
    Set ^||OcuPilotSqlTuningAsked($Increment(^||OcuPilotSqlTuningAsked)) = tText
    Quit (pFailedPair = "")
}

}
