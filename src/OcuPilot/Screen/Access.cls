/// <p>The Screen permissions list's rows (AD-64, AD-36, Story 20.15): one row per built screen, ordered by
/// area and then identifier, answering what the screen declares, what an operator adjusted it to, the
/// classic page's custom resource, what it requires now, and whether the caller holds that.</p>
/// <p><b><code>Effective</code> is what <method>OcuPilot.Screen.Gate.RequiredPairs</method> answers for the
/// screen</b>, the classic page's custom resource included, so the list can never show a requirement the
/// gates do not apply. <code>Holds</code> and <code>FailedPair</code> are the calling process's own verdict
/// on that set (<method>OcuPilot.Screen.Gate.EvaluatePairs</method>). A screen whose requirement cannot be
/// read has an empty <code>Effective</code>, <code>Holds</code> false and no failed pair.</p>
/// <p>Every pair is spelled <code>resource:permission</code> and a set is comma-and-space separated.
/// <code>Adjustment</code> is <code>""</code> for a screen with no stored row, or one that cannot be adjusted.
/// The store is read once for the whole list (<method>OcuPilot.Kernel.State.Access.GuardedAll</method>).</p>
Class OcuPilot.Screen.Access Extends %RegisteredObject
{

/// <p>The separator a set is spelled with.</p>
Parameter SEPARATOR = ", ";

/// <p>The rows, in <var>pRows</var> as a JSON array of
/// <code>{Screen, Area, Declared, Adjustment, ClassicResource, Effective, Holds, FailedPair, Adjustable}</code>
/// objects, at most <var>pMaxRows</var> of them when it is above zero; <var>pTruncated</var> is 1 when more
/// screens exist. An error status is a roster or store that could not be read.</p>
ClassMethod Rows(Output pRows As %DynamicArray, pMaxRows As %Integer = 0, Output pTruncated As %Boolean) As %Status
{
    Set pRows = []
    Set pTruncated = 0
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tDescriptors)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Access).GuardedAll(.tStored)
        If $$$ISERR(tSC) Quit
        Kill tOrdered
        For tI = 1:1:$ListLength(tDescriptors) {
            Set tClass = $List(tDescriptors, tI)
            If '$ClassMethod(tClass, "IsBuilt") Continue
            Set tOrdered($ClassMethod(tClass, "AreaKey"), $ClassMethod(tClass, "ToolIdentifier")) = tClass
        }
        Set tArea = ""
        For {
            Set tArea = $Order(tOrdered(tArea))
            If tArea = "" Quit
            Set tScreen = ""
            For {
                Set tScreen = $Order(tOrdered(tArea, tScreen), 1, tClass)
                If tScreen = "" Quit
                If (pMaxRows > 0) && (pRows.%Size() >= pMaxRows) {
                    Set pTruncated = 1
                    Quit
                }
                Do pRows.%Push(..RowFor(tClass, tArea, tScreen, .tStored))
            }
            If pTruncated Quit
        }
    } Catch ex {
        Set pRows = []
        Set pTruncated = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One screen's row. <var>pStored</var> is <method>OcuPilot.Kernel.State.Access.GuardedAll</method>'s
/// answer.</p>
ClassMethod RowFor(pClass As %String, pArea As %String, pScreen As %String, ByRef pStored) As %DynamicObject [ Private ]
{
    Set tGate = "OcuPilot.Screen.Gate"
    Set tAdjustable = ''$ClassMethod(tGate, "Adjustable", pClass)
    Set tAdjustment = $Select(tAdjustable: $Get(pStored(pScreen)), 1: "")
    Set tEffective = $ClassMethod(tGate, "RequiredPairs", pClass, .tResolved)
    Set tHolds = 0
    Set tFailed = ""
    If tResolved Set tHolds = ''$ClassMethod(tGate, "EvaluatePairs", tEffective, .tFailed)
    Set tRow = {}
    Do tRow.%Set("Screen", pScreen, "string")
    Do tRow.%Set("Area", pArea, "string")
    Do tRow.%Set("Declared", ..Spelled($ClassMethod(pClass, "PrivilegePairs")), "string")
    Do tRow.%Set("Adjustment", $Select(tAdjustment = "": "", 1: $ListToString($ListFromString(tAdjustment, ","), ..#SEPARATOR)), "string")
    Do tRow.%Set("ClassicResource", ..ClassicResourceOf(pClass), "string")
    Do tRow.%Set("Effective", $Select(tResolved: ..Spelled(tEffective), 1: ""), "string")
    Do tRow.%Set("Holds", $Select(tHolds: 1, 1: 0), "boolean")
    Do tRow.%Set("FailedPair", tFailed, "string")
    Do tRow.%Set("Adjustable", $Select(tAdjustable: 1, 1: 0), "boolean")
    Quit tRow
}

/// <p>The custom resource assigned to the classic page descriptor <var>pClass</var> replaces, or
/// <code>""</code> (<method>OcuPilot.Screen.Gate.ClassicResource</method>).</p>
ClassMethod ClassicResourceOf(pClass As %String) As %String [ Private ]
{
    Quit $ClassMethod("OcuPilot.Screen.Gate", "ClassicResource", $ClassMethod(pClass, "ClassicPage"))
}

/// <p>The gate's pair list <var>pPairs</var> spelled <code>resource:permission</code>, separated by
/// <parameter>SEPARATOR</parameter>.</p>
ClassMethod Spelled(pPairs As %List) As %String [ Private ]
{
    Set tText = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tPair = $List(pPairs, tI)
        Set tText = tText _ $Select(tText = "": "", 1: ..#SEPARATOR) _ ##class(OcuPilot.Screen.Gate).SpellPair($List(tPair, 1), $List(tPair, 2))
    }
    Quit tText
}

}
