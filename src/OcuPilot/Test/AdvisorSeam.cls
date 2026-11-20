/// <p><class>OcuPilot.Port.AdvisorPort</class> with its seams armable by a test: <method>Arm</method> answers the recommendations from rows the
/// test names, so <method>OcuPilot.Port.AdvisorPort.SetFlag</method> changes the armed rows and never the instance's ignore flags;
/// <method>DenyPair</method> answers the gate as not holding one pair; and <method>NoEffect</method> makes the flag call change nothing. Every
/// read and flag call made while armed is recorded (<method>Calls</method>). Unarmed, every seam is the port's own, so a test can drive the real
/// instance through this class too.</p>
/// <p><method>PaneLines</method> and <method>Vendor</method> are the real pane and the real flag call, whatever is armed, for the tests that compare
/// the port with the instance and put a flag back. State lives in <code>^||OcuPilotAdvisorSeam</code>; <method>Clear</method> forgets it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AdvisorSeam Extends OcuPilot.Port.AdvisorPort
{

/// <p>Forget every armed answer and every recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotAdvisorSeam
}

/// <p>Answer the recommendations with <var>pRows</var>, an array of <code>[type, element, code, ignored]</code>.</p>
ClassMethod Arm(pRows As %DynamicArray)
{
    Kill ^||OcuPilotAdvisorSeam("rec")
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set ^||OcuPilotAdvisorSeam("rec", tRow.%Get(0), tRow.%Get(1), "list", tRow.%Get(2)) = $Select(tRow.%Get(3): 1, 1: "")
    }
    Set ^||OcuPilotAdvisorSeam = 1
}

/// <p>Answer the gate as not holding <var>pPair</var>.</p>
ClassMethod DenyPair(pPair As %String)
{
    Set ^||OcuPilotAdvisorSeam("denied") = pPair
}

/// <p>Make a flag call change nothing, as the page's own method does when its store refuses.</p>
ClassMethod NoEffect()
{
    Set ^||OcuPilotAdvisorSeam("noeffect") = 1
}

/// <p>Every call made while armed, oldest first, each <code>READ</code> or <code>SET &lt;type&gt;|&lt;element&gt;|&lt;code&gt;|&lt;flag&gt;</code>,
/// joined by <code>;</code>.</p>
ClassMethod Calls() As %String
{
    Set tOut = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotAdvisorSeam("calls", tAt), 1, tCall)
        If tAt = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ";") _ tCall
    }
    Quit tOut
}

/// <p>The armed rows, or the instance's own when none are armed.</p>
ClassMethod Recommendations(Output pRecommend) As %Status [ Private ]
{
    If '$Get(^||OcuPilotAdvisorSeam) Quit ##super(.pRecommend)
    Set ^||OcuPilotAdvisorSeam("calls", $Increment(^||OcuPilotAdvisorSeam("calls"))) = "READ"
    Kill pRecommend
    Merge pRecommend = ^||OcuPilotAdvisorSeam("rec")
    Quit $$$OK
}

/// <p>The armed row's flag set, and the call recorded; the instance's own flag call when none are armed.</p>
ClassMethod SetFlag(pType As %String, pElement As %String, pCode As %String, pFlag As %Boolean) As %Status [ Private ]
{
    If '$Get(^||OcuPilotAdvisorSeam) || $Get(^||OcuPilotAdvisorSeam("bypass")) Quit ##super(pType, pElement, pCode, pFlag)
    Set ^||OcuPilotAdvisorSeam("calls", $Increment(^||OcuPilotAdvisorSeam("calls"))) = "SET " _ pType _ "|" _ pElement _ "|" _ pCode _ "|" _ ''pFlag
    If '$Get(^||OcuPilotAdvisorSeam("noeffect")) Set ^||OcuPilotAdvisorSeam("rec", pType, pElement, "list", pCode) = $Select(pFlag: 1, 1: "")
    Quit $$$OK
}

/// <p>The gate's pair check, answering a denied pair as not held; the port's own check otherwise.</p>
ClassMethod HoldsPair(pPair As %String) As %Boolean
{
    If $Data(^||OcuPilotAdvisorSeam("denied")) Quit ($Get(^||OcuPilotAdvisorSeam("denied")) '= pPair)
    Quit ##super(pPair)
}

/// <p>The page's own recommendations, read in <code>%SYS</code> whatever is armed, as <code>pLines(&lt;n&gt;) =
/// &lt;type&gt;|&lt;element&gt;|&lt;code&gt;|&lt;ignored&gt;</code> in the page's order, and their count; <code>-1</code> when the page cannot be read.</p>
ClassMethod PaneLines(Output pLines) As %Integer
{
    Kill pLines
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(%CSP.UI.System.SecurityAdvisorPane).GetRecommendations(.tRec)
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) {
            Set tCount = -1
            Quit
        }
        Set tType = ""
        For {
            Set tType = $Order(tRec(tType))
            If tType = "" Quit
            Set tElement = ""
            For {
                Set tElement = $Order(tRec(tType, tElement))
                If tElement = "" Quit
                Set tCode = ""
                For {
                    Set tCode = $Order(tRec(tType, tElement, "list", tCode), 1, tFlag)
                    If tCode = "" Quit
                    Set tCount = tCount + 1
                    Set pLines(tCount) = tType _ "|" _ tElement _ "|" _ tCode _ "|" _ ''tFlag
                }
            }
        }
    } Catch {
        Set tCount = -1
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p>The page's own ignore flag call, whatever is armed.</p>
ClassMethod Vendor(pType As %String, pElement As %String, pCode As %String, pFlag As %Boolean) As %Status
{
    Set ^||OcuPilotAdvisorSeam("bypass") = 1
    Set tSC = ..SetFlag(pType, pElement, pCode, pFlag)
    Kill ^||OcuPilotAdvisorSeam("bypass")
    Quit tSC
}

}
