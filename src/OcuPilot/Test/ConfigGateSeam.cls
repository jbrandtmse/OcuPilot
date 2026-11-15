/// <p><class>OcuPilot.Port.ConfigPort</class> with its pair sets evaluated through <class>OcuPilot.Test.ScreenGate</class>, whose held
/// set a test declares, so <class>OcuPilot.Test.PortGate</class> and <class>OcuPilot.Test.ConfigSettingRead</class> drive the port's
/// refusal in a process holding <code>%All</code>, and with <method>SendProperties</method> recording the call instead of making it, so a
/// test sees what the port would send and no setting changes; <method>VendorRefuses</method> makes it answer an error. The SQL Shell,
/// ISQL and TSQL writes and the purge of the cached queries are recorded the same way (<method>SendNode</method>,
/// <method>SendTsql</method>, <method>PurgeCachedQueries</method>), the stored TSQL dialect a flag set passes on is the one
/// <method>HoldDialect</method> names, and <method>PurgeFails</method> makes the purge answer an error. <method>WriteThrough</method> makes
/// <method>SendProperties</method> make its call after recording it. Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ConfigGateSeam Extends OcuPilot.Port.ConfigPort
{

/// <p>The test gate, in place of the instance's own answer.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.ScreenGate"
}

/// <p>The shipped answers again, and no recorded call.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotConfigRefuses, ^||OcuPilotConfigModifies, ^||OcuPilotConfigDialect, ^||OcuPilotConfigDialectSent, ^||OcuPilotConfigPurges, ^||OcuPilotConfigPurgeFails, ^||OcuPilotConfigWriteThrough
}

/// <p>Make <method>StoredDialect</method> answer <var>pDialect</var> (possibly empty) until <method>Reset</method>.</p>
ClassMethod HoldDialect(pDialect As %String)
{
    Set ^||OcuPilotConfigDialect = pDialect
}

/// <p>The dialect the last recorded <method>SendTsql</method> was given.</p>
ClassMethod DialectSent() As %String
{
    Quit $Get(^||OcuPilotConfigDialectSent)
}

/// <p>The number of purges <method>PurgeCachedQueries</method> recorded.</p>
ClassMethod Purges() As %Integer
{
    Quit +$Get(^||OcuPilotConfigPurges)
}

/// <p>Answer an error from <method>PurgeCachedQueries</method> until <method>Reset</method>.</p>
ClassMethod PurgeFails()
{
    Set ^||OcuPilotConfigPurgeFails = 1
}

/// <p>Make <method>SendProperties</method> send its call to the instance after recording it, so a class write really changes the setting,
/// until <method>Reset</method>.</p>
ClassMethod WriteThrough()
{
    Set ^||OcuPilotConfigWriteThrough = 1
}

/// <p>Answer an error from <method>VendorModify</method> until <method>Reset</method>.</p>
ClassMethod VendorRefuses()
{
    Set ^||OcuPilotConfigRefuses = 1
}

/// <p>The calls <method>SendProperties</method> recorded, as <code>class|name|value</code>, comma-joined.</p>
ClassMethod Modifies() As %String
{
    Set tOut = ""
    Set tI = ""
    For {
        Set tI = $Order(^||OcuPilotConfigModifies(tI))
        If tI = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $List(^||OcuPilotConfigModifies(tI), 1)
    }
    Quit tOut
}

/// <p>The keys the last recorded call sent, comma-joined, or <code>""</code> when none was recorded.</p>
ClassMethod SentKeys() As %String
{
    Set tLast = $Order(^||OcuPilotConfigModifies(""), -1)
    If tLast = "" Quit ""
    Quit $List(^||OcuPilotConfigModifies(tLast), 2)
}

ClassMethod SendProperties(pClass As %String, pName As %String, ByRef pProps) As %Status [ Private ]
{
    Set tKeys = ""
    Set tKey = ""
    For {
        Set tKey = $Order(pProps(tKey))
        If tKey = "" Quit
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Set ^||OcuPilotConfigModifies($Increment(^||OcuPilotConfigModifies)) = $ListBuild(pClass _ "|" _ pName _ "|" _ $Get(pProps(pName)), tKeys)
    If $Get(^||OcuPilotConfigRefuses) Quit $$$ERROR($$$GeneralError, "a vendor refusal fed by the test")
    If $Get(^||OcuPilotConfigWriteThrough) Quit ##super(pClass, pName, .pProps)
    Quit $$$OK
}

ClassMethod StoredDialect() As %String
{
    If $Data(^||OcuPilotConfigDialect) Quit ^||OcuPilotConfigDialect
    Quit ##super()
}

ClassMethod SendNode(pEndpoint As %String, pName As %String, pStored As %String) As %Status [ Private ]
{
    Set ^||OcuPilotConfigModifies($Increment(^||OcuPilotConfigModifies)) = $ListBuild(pEndpoint _ "|" _ pName _ "|" _ pStored, "")
    If $Get(^||OcuPilotConfigRefuses) Quit $$$ERROR($$$GeneralError, "a vendor refusal fed by the test")
    Quit $$$OK
}

ClassMethod SendTsql(pName As %String, pDialect As %String, pValue As %String) As %Status [ Private ]
{
    Set ^||OcuPilotConfigDialectSent = pDialect
    Set ^||OcuPilotConfigModifies($Increment(^||OcuPilotConfigModifies)) = $ListBuild("TSQL|" _ pName _ "|" _ pValue, "")
    If $Get(^||OcuPilotConfigRefuses) Quit $$$ERROR($$$GeneralError, "a vendor refusal fed by the test")
    Quit $$$OK
}

ClassMethod PurgeCachedQueries() As %Status
{
    Set ^||OcuPilotConfigPurges = $Get(^||OcuPilotConfigPurges) + 1
    If $Get(^||OcuPilotConfigPurgeFails) Quit $$$ERROR($$$GeneralError, "a purge failure fed by the test")
    Quit $$$OK
}

}
