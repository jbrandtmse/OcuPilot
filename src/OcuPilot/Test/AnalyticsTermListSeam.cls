/// <p><class>OcuPilot.Port.AnalyticsPort</class> with the term list editor's vendor calls counted, one of them failed on demand, and the
/// destination's journal and mount state answered as a test arms them, so <class>OcuPilot.Test.AnalyticsTermListEdit</class> and
/// <class>OcuPilot.Test.AnalyticsTermListGate</class> drive the port's refusals and its rollback in process. Every call that is not failed
/// is made on the vendor, in <code>USER</code>.</p>
/// <p><method>Arm</method> names the mode: <code>failsecond</code> (the second <code>%SetValue</code> since <method>Reset</method> answers an
/// error), <code>throwsecond</code> (it raises an exception instead), <code>failthird</code> (the third <code>%SetValue</code> answers an error, which an import or a copy of a list with entries reaches), <code>failhide</code> (the hide-value write answers an error), <code>nonjournaled</code> (the term list database reads as not journaled), <code>unknownjournal</code> (its journal state cannot be
/// read) or <code>readonly</code> (it reads as mounted read-only). <method>Calls</method> counts the vendor calls made, an export's included.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AnalyticsTermListSeam Extends OcuPilot.Port.AnalyticsPort
{

ClassMethod Reset()
{
    Kill ^||OcuPilotTermListSeam
}

ClassMethod Arm(pMode As %String)
{
    Set ^||OcuPilotTermListSeam("mode") = pMode
}

/// <p>How many vendor write calls were made since <method>Reset</method>.</p>
ClassMethod Calls() As %Integer
{
    Quit +$Get(^||OcuPilotTermListSeam("calls"))
}

ClassMethod Count(pKind As %String) As %Status [ Private ]
{
    Set ^||OcuPilotTermListSeam("calls") = $Get(^||OcuPilotTermListSeam("calls")) + 1
    If pKind = "set" Set ^||OcuPilotTermListSeam("sets") = $Get(^||OcuPilotTermListSeam("sets")) + 1
    If ($Get(^||OcuPilotTermListSeam("mode")) = "failsecond") && (pKind = "set") && ($Get(^||OcuPilotTermListSeam("sets")) = 2) Quit $$$ERROR($$$GeneralError, "armed failure of the second value write")
    If ($Get(^||OcuPilotTermListSeam("mode")) = "failthird") && (pKind = "set") && ($Get(^||OcuPilotTermListSeam("sets")) = 3) Quit $$$ERROR($$$GeneralError, "armed failure of the third value write")
    If ($Get(^||OcuPilotTermListSeam("mode")) = "failhide") && (pKind = "hide") Quit $$$ERROR($$$GeneralError, "armed failure of the hide-value write")
    Quit $$$OK
}

ClassMethod VendorTermListCreate(pNamespace As %String, pName As %String, pCaption As %String, pFieldList As %String, pPattern As %String, pDescription As %String, pSubject As %String, pHide As %Boolean, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set tSC = ..Count("create")
    If $$$ISERR(tSC) Quit tSC
    Quit ##super(pNamespace, pName, pCaption, pFieldList, pPattern, pDescription, pSubject, pHide, .pCaught)
}

ClassMethod VendorTermListHeader(pNamespace As %String, pName As %String, pCaption As %String, pFieldList As %String, pPattern As %String, pDescription As %String, pSubject As %String, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set tSC = ..Count("header")
    If $$$ISERR(tSC) Quit tSC
    Quit ##super(pNamespace, pName, pCaption, pFieldList, pPattern, pDescription, pSubject, .pCaught)
}

ClassMethod VendorTermListHide(pNamespace As %String, pName As %String, pHide As %Boolean, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set tSC = ..Count("hide")
    If $$$ISERR(tSC) Quit tSC
    Quit ##super(pNamespace, pName, pHide, .pCaught)
}

ClassMethod VendorTermListSetValue(pNamespace As %String, pName As %String, pKey As %String, pValue As %String, pField As %String, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set tSC = ..Count("set")
    If $$$ISERR(tSC) Quit tSC
    If ($Get(^||OcuPilotTermListSeam("mode")) = "throwsecond") && ($Get(^||OcuPilotTermListSeam("sets")) = 2) {
        Set pCaught = ##class(%Exception.General).%New("ArmedFailure", 5001, , "armed exception of the second value write")
        Quit $$$OK
    }
    Quit ##super(pNamespace, pName, pKey, pValue, pField, .pCaught)
}

ClassMethod VendorTermListRemoveEntry(pNamespace As %String, pName As %String, pKey As %String, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set tSC = ..Count("remove")
    If $$$ISERR(tSC) Quit tSC
    Quit ##super(pNamespace, pName, pKey, .pCaught)
}

ClassMethod VendorTermListExport(pNamespace As %String, pName As %String, pFile As %String, Output pLines As %DynamicArray, Output pTooLarge As %Boolean, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set pLines = ""
    Set pTooLarge = 0
    Set tSC = ..Count("export")
    If $$$ISERR(tSC) Quit tSC
    Quit ##super(pNamespace, pName, pFile, .pLines, .pTooLarge, .pCaught)
}

ClassMethod VendorTermListDelete(pNamespace As %String, pName As %String, Output pCaught As %Exception.AbstractException) As %Status
{
    Set pCaught = ""
    Set tSC = ..Count("delete")
    If $$$ISERR(tSC) Quit tSC
    Quit ##super(pNamespace, pName, .pCaught)
}

/// <p>The armed journal state of the term list database, else the instance's own.</p>
ClassMethod DestinationJournaled(pNamespace As %String, pGlobal As %String, Output pJournaled As %Boolean) As %Boolean
{
    Set tMode = $Get(^||OcuPilotTermListSeam("mode"))
    If tMode = "nonjournaled" {
        Set pJournaled = 0
        Quit 1
    }
    If tMode = "unknownjournal" {
        Set pJournaled = 0
        Quit 0
    }
    Quit ##super(pNamespace, pGlobal, .pJournaled)
}

/// <p>The term list database mounted read-only when armed <code>readonly</code>, else the instance's own answer.</p>
ClassMethod DestinationDatabase(pNamespace As %String, pGlobal As %String, Output pResource As %String, Output pReadOnly As %Boolean, Output pMounted As %Boolean) As %Boolean
{
    Set tResolved = ##super(pNamespace, pGlobal, .pResource, .pReadOnly, .pMounted)
    If (pGlobal = ..#TERMLISTGLOBAL) && ($Get(^||OcuPilotTermListSeam("mode")) = "readonly") Set pReadOnly = 1
    Quit tResolved
}

ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set ^||OcuPilotTermListSeam("log") = $Get(^||OcuPilotTermListSeam("log")) _ pMessage _ ";"
}

}
