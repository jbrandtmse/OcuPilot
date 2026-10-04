/// <p><class>OcuPilot.Test.SqlPortFixture</class>'s two-second port with two seams the data browser's
/// tests read: each bound <method>Executed</method> is given is recorded in
/// <code>^||OcuProbe197Bounds</code>, in call order, and while <code>^||OcuProbe197Unindexed</code>
/// reads 1 <method>Prepared</method> answers that the statement index does not record the statement.
/// Everything else is the production port's.</p>
Class OcuPilot.Test.SqlBrowseFixture Extends OcuPilot.Test.SqlPortFixture
{

ClassMethod Executed(pNamespace As %String, pText As %String, pType As %Integer, pValues As %DynamicArray, pBound As %Integer, pFetch As %Boolean, pMaxRows As %Integer, Output pRaw As %DynamicObject) As %Status [ Private ]
{
    Set ^||OcuProbe197Bounds($Increment(^||OcuProbe197Bounds)) = pBound
    Quit ##super(pNamespace, pText, pType, pValues, pBound, pFetch, pMaxRows, .pRaw)
}

ClassMethod Prepared(pNamespace As %String, pText As %String, Output pRaw As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ##super(pNamespace, pText, .pRaw)
    If $$$ISOK(tSC) && $Get(^||OcuProbe197Unindexed) && $IsObject($Get(pRaw)) && (pRaw.%GetTypeOf("error") '= "object") {
        Do pRaw.%Set("indexed", 0, "boolean")
        Do pRaw.%Set("tables", [])
    }
    Quit tSC
}

/// <p>The bounds recorded since <code>^||OcuProbe197Bounds</code> was last killed, comma-separated.</p>
ClassMethod Bounds() As %String
{
    Set tOut = ""
    For tI = 1:1:$Get(^||OcuProbe197Bounds) Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $Get(^||OcuProbe197Bounds(tI))
    Quit tOut
}

}
