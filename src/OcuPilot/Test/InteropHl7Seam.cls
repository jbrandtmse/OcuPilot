/// <p><class>OcuPilot.Test.InteropWorkflowSeam</class> with the HL7 schema seams of <class>OcuPilot.Port.InteropPort</class> answering what
/// <code>^IRIS.Temp.OcuProbe2417wMode</code> says (Story 24.18 Batch 1): <code>status</code> makes the vendor's add, delete, load or export answer an error status that carries a
/// marker text, without calling it; <code>fault</code> raises an error carrying the marker; <code>lock</code> makes the schema lock answer 0; <code>nohl7</code> makes
/// <method>Hl7Installed</method> answer 0; <code>here</code> raises inside each namespace-switched block, keeping the namespace under the global's <code>hereIn</code> subscript; anything else is the
/// vendor's own call. The namespace and count of the last vendor call are kept under <code>ranIn</code> and <code>ran</code>. The line log and source-control answer are the workflow seam's.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropHl7Seam Extends OcuPilot.Test.InteropWorkflowSeam
{

/// <p>The text a probe fault and a probe status carry, which no log line may.</p>
Parameter HL7MARKER = "OcuMarkerText2418Hl7";

ClassMethod Hl7VendorWrite(pType As %String, pName As %String, pBase As %String, pDescription As %String) As %Status
{
    Set tMode = $Get(^IRIS.Temp.OcuProbe2417wMode)
    Set ^IRIS.Temp.OcuProbe2417wMode("ranIn") = $NAMESPACE
    Set ^IRIS.Temp.OcuProbe2417wMode("ran") = $Get(^IRIS.Temp.OcuProbe2417wMode("ran")) + 1
    If tMode = "status" Quit $$$ERROR($$$GeneralError, ..#HL7MARKER _ " answered for " _ pName)
    If tMode = "fault" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#HL7MARKER _ " raised for " _ pName))
    Quit ##super(pType, pName, pBase, pDescription)
}

ClassMethod Hl7VendorLoad(pStream As %Stream.Object, pItem As %String, Output pLoaded) As %Status
{
    Set tMode = $Get(^IRIS.Temp.OcuProbe2417wMode)
    Set ^IRIS.Temp.OcuProbe2417wMode("ranIn") = $NAMESPACE
    Set ^IRIS.Temp.OcuProbe2417wMode("ran") = $Get(^IRIS.Temp.OcuProbe2417wMode("ran")) + 1
    If tMode = "status" Quit $$$ERROR($$$GeneralError, ..#HL7MARKER _ " answered for " _ pItem)
    If tMode = "fault" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#HL7MARKER _ " raised for " _ pItem))
    Quit ##super(pStream, pItem, .pLoaded)
}

ClassMethod Hl7VendorExport(pName As %String, pToFile As %Boolean, pFile As %String, pMax As %Integer, Output pText As %String, Output pTooLarge As %Boolean) As %Status
{
    Set tMode = $Get(^IRIS.Temp.OcuProbe2417wMode)
    Set ^IRIS.Temp.OcuProbe2417wMode("ranIn") = $NAMESPACE
    Set ^IRIS.Temp.OcuProbe2417wMode("ran") = $Get(^IRIS.Temp.OcuProbe2417wMode("ran")) + 1
    If tMode = "status" Quit $$$ERROR($$$GeneralError, ..#HL7MARKER _ " answered for " _ pName)
    If tMode = "fault" Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#HL7MARKER _ " raised for " _ pName))
    Quit ##super(pName, pToFile, pFile, pMax, .pText, .pTooLarge)
}

/// <p>Answer 0 when the mode is <code>lock</code>, else the vendor's lock; each lock taken is counted under <code>locked</code>.</p>
ClassMethod Hl7Lock(pName As %String) As %Boolean
{
    If $Get(^IRIS.Temp.OcuProbe2417wMode) = "lock" Quit 0
    Set tLocked = ##super(pName)
    If tLocked Set ^IRIS.Temp.OcuProbe2417wMode("locked") = $Get(^IRIS.Temp.OcuProbe2417wMode("locked")) + 1
    Quit tLocked
}

/// <p>Release the vendor's lock, counting each release under <code>unlocked</code>.</p>
ClassMethod Hl7Unlock(pName As %String)
{
    Set ^IRIS.Temp.OcuProbe2417wMode("unlocked") = $Get(^IRIS.Temp.OcuProbe2417wMode("unlocked")) + 1
    Do ##super(pName)
}

/// <p>Answer 0 when the mode is <code>nohl7</code>.</p>
ClassMethod Hl7Installed(pNamespace As %String) As %Boolean
{
    If $Get(^IRIS.Temp.OcuProbe2417wMode) = "nohl7" Quit 0
    Quit ##super(pNamespace)
}

/// <p>Raise inside a namespace-switched block when the mode is <code>here</code>: in every block after the first <code>hereSkip</code> (default 0) that the process has entered since
/// <code>hereCount</code> was last killed.</p>
ClassMethod Hl7Here() [ Private ]
{
    If $Get(^IRIS.Temp.OcuProbe2417wMode) = "here" {
        Set tCount = $Get(^IRIS.Temp.OcuProbe2417wMode("hereCount")) + 1
        Set ^IRIS.Temp.OcuProbe2417wMode("hereCount") = tCount
        If tCount > +$Get(^IRIS.Temp.OcuProbe2417wMode("hereSkip")) {
            Set ^IRIS.Temp.OcuProbe2417wMode("hereIn") = $NAMESPACE
            Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#HL7MARKER _ " raised in the schema's namespace"))
        }
    }
}

}
