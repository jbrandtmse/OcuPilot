/// <p>Subclass of <class>OcuPilot.Port.ResourceTransferPort</class> overriding only its seams, so the read tests run the port's real resolve,
/// review and refusal mapping: a pair the gate answers as not held, every vendor call recorded before it is made, and a vendor call that
/// fails. State lives in <code>^||OcuPilotResourceTransferFixture</code>; <method>Clear</method> forgets it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ResourceTransferFixture Extends OcuPilot.Port.ResourceTransferPort
{

/// <p>Forget every armed answer and recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotResourceTransferFixture
    Do ##class(OcuPilot.Test.PathPortFixture).Reset()
}

/// <p>Resolve through <class>OcuPilot.Test.PathPortFixture</class>, whose seams the caller sets, until <method>Clear</method>.</p>
ClassMethod UsePathPortFixture()
{
    Set ^||OcuPilotResourceTransferFixture("pathport") = 1
}

ClassMethod PathPortClass() As %String
{
    If $Get(^||OcuPilotResourceTransferFixture("pathport")) Quit "OcuPilot.Test.PathPortFixture"
    Quit ##super()
}

/// <p>Answer the gate as not holding <var>pPair</var>.</p>
ClassMethod DenyPair(pPair As %String)
{
    Set ^||OcuPilotResourceTransferFixture("denied") = pPair
}

/// <p>Fail the next vendor call.</p>
ClassMethod FailVendor()
{
    Set ^||OcuPilotResourceTransferFixture("fail") = 1
}

/// <p>Every vendor call made, oldest first, each <code>EXPORT &lt;names&gt; &lt;file&gt;</code> or <code>IMPORT &lt;flags&gt;</code>,
/// joined by <code>|</code>.</p>
ClassMethod Calls() As %String
{
    Set tOut = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotResourceTransferFixture("calls", tAt), 1, tCall)
        If tAt = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: "|") _ tCall
    }
    Quit tOut
}

ClassMethod HoldsPair(pPair As %String) As %Boolean
{
    If pPair = $Get(^||OcuPilotResourceTransferFixture("denied")) Quit 0
    Quit ##super(pPair)
}

ClassMethod VendorExport(pFile As %String, pNames As %String, Output pNumber As %Integer) As %Status [ Private ]
{
    Set ^||OcuPilotResourceTransferFixture("calls", $Increment(^||OcuPilotResourceTransferFixture("calls"))) = "EXPORT " _ pNames
    If $Get(^||OcuPilotResourceTransferFixture("fail")) {
        Kill ^||OcuPilotResourceTransferFixture("fail")
        Set pNumber = 0
        Quit $$$ERROR($$$GeneralError, "armed vendor failure")
    }
    Quit ##super(pFile, pNames, .pNumber)
}

ClassMethod VendorImport(pFile As %String, pFlags As %Integer, Output pNumber As %Integer) As %Status [ Private ]
{
    Set ^||OcuPilotResourceTransferFixture("calls", $Increment(^||OcuPilotResourceTransferFixture("calls"))) = "IMPORT " _ pFlags
    If $Get(^||OcuPilotResourceTransferFixture("fail")) && (pFlags = 0) {
        Kill ^||OcuPilotResourceTransferFixture("fail")
        Set pNumber = 0
        Quit $$$ERROR($$$GeneralError, "armed vendor failure")
    }
    Quit ##super(pFile, pFlags, .pNumber)
}

/// <p>The port's answer to <var>pType</var>: <code>http|code</code>, with the result in <var>pOut</var>.</p>
ClassMethod Ask(pType As %String, ByRef pQuery, Output pOut) As %String
{
    Set tSC = ..Invoke(..#ENDPOINT, pType, .pQuery, "", .pOut, .tHttp, .tFault)
    Quit tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

}
