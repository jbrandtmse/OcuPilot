/// <p>Test-only <class>OcuPilot.Api.Namespaces</class> subclass recording the
/// <code>DontConnect</code> argument its namespace-information seam is handed, then answering from
/// the instance.</p>
Class OcuPilot.Test.NamespaceInfoFixture Extends OcuPilot.Api.Namespaces
{

/// <p>The <code>DontConnect</code> last handed to <method>NamespaceInfo</method>, or
/// <code>""</code>.</p>
ClassMethod RecordedDontConnect() As %String
{
    Quit $Get(^||OcuPilotNamespaceInfo, "")
}

/// <p>Forget the record.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotNamespaceInfo
}

ClassMethod NamespaceInfo(pNamespace As %String, ByRef pInfo, pDontConnect As %Boolean)
{
    Set ^||OcuPilotNamespaceInfo = pDontConnect
    Do ##super(pNamespace, .pInfo, pDontConnect)
}

}
