/// <p><class>OcuPilot.Port.PortalResourcePort</class> over a store of its own, so a test can drive the port's rules and the write tools' classification
/// without touching the instance's classic pages (Story 21.37). The pages the portal "has", the resource each holds and the resources the instance
/// "defines" live in the process-private <code>^||OcuPilotPageResourceStore</code>: <method>Page</method> adds a page, <method>Define</method> a
/// resource. Every <method>Store</method> and <method>Audit</method> call is recorded in order (<method>Writes</method>, <method>Audits</method>), and
/// <method>Clear</method> forgets everything.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.PageResourceStoreSeam Extends OcuPilot.Port.PortalResourcePort
{

/// <p>Forget every page, resource and recorded call.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotPageResourceStore
}

/// <p>Make <var>pPage</var> a page of the portal holding <var>pResource</var> (<code>""</code> for none).</p>
ClassMethod Page(pPage As %String, pResource As %String = "")
{
    Set ^||OcuPilotPageResourceStore("page", pPage) = pResource
}

/// <p>Make <var>pName</var> a resource the instance defines.</p>
ClassMethod Define(pName As %String)
{
    Set ^||OcuPilotPageResourceStore("resource", pName) = ""
}

/// <p>The resource <var>pPage</var> holds in the seam's store, <code>""</code> for none.</p>
ClassMethod HeldBy(pPage As %String) As %String
{
    Quit $Get(^||OcuPilotPageResourceStore("page", pPage))
}

/// <p>Every <method>Store</method> call, oldest first, as <code>page=resource</code> joined by <code>;</code>.</p>
ClassMethod Writes() As %String
{
    Quit ..Joined("writes")
}

/// <p>Every <method>Audit</method> call, oldest first, as <code>verb page old&gt;new</code> joined by <code>;</code>.</p>
ClassMethod Audits() As %String
{
    Quit ..Joined("audits")
}

ClassMethod Joined(pNode As %String) As %String [ Private ]
{
    Set tOut = ""
    Set tAt = ""
    For {
        Set tAt = $Order(^||OcuPilotPageResourceStore(pNode, tAt), 1, tEntry)
        If tAt = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ";") _ tEntry
    }
    Quit tOut
}

/// <p>The pages of the seam's store, which the real vendor is never asked about; a name with a <code>.cls</code> suffix is its page, as the vendor
/// resolves it.</p>
ClassMethod Resolve(pEncoded As %String, Output pNormalized As %String) As %Status [ Private ]
{
    Set pNormalized = ""
    Set tPage = $ZConvert(pEncoded, "I", "URL")
    If $Extract(tPage, *-3, *) = ".cls" Set tPage = $Extract(tPage, 1, *-4)
    If $Data(^||OcuPilotPageResourceStore("page", tPage)) Set pNormalized = tPage
    Quit $$$OK
}

ClassMethod Held(pNormalized As %String, Output pResource As %String) As %Status [ Private ]
{
    Set pResource = $Get(^||OcuPilotPageResourceStore("page", pNormalized))
    Quit $$$OK
}

ClassMethod Stored(pMax As %Integer, Output pStored As %List) As %Status [ Private ]
{
    Set pStored = ""
    Set tPage = ""
    For {
        Set tPage = $Order(^||OcuPilotPageResourceStore("page", tPage), 1, tResource)
        If tPage = "" Quit
        If tResource '= "" Set pStored = pStored _ $ListBuild($ListBuild(tPage, tResource))
    }
    Quit $$$OK
}

ClassMethod ResourceDefined(pName As %String) As %Boolean
{
    Quit $Data(^||OcuPilotPageResourceStore("resource", pName)) > 0
}

ClassMethod Store(pNormalized As %String, pResource As %String) As %Status [ Private ]
{
    Set ^||OcuPilotPageResourceStore("writes", $Increment(^||OcuPilotPageResourceStore("writes"))) = pNormalized _ "=" _ pResource
    Set ^||OcuPilotPageResourceStore("page", pNormalized) = pResource
    Quit $$$OK
}

ClassMethod Audit(pVerb As %String, pPage As %String, pOld As %String, pNew As %String) [ Private ]
{
    Set ^||OcuPilotPageResourceStore("audits", $Increment(^||OcuPilotPageResourceStore("audits"))) = pVerb _ " " _ pPage _ " " _ pOld _ ">" _ pNew
}

}
