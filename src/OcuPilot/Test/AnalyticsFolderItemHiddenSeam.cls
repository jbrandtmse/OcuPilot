/// <p><class>OcuPilot.Test.AnalyticsTermListSeam</class> with one folder item answered as the vendor answers an item the caller's resources hide
/// (<code>%FolderItemExists</code> 2), so <class>OcuPilot.Test.AnalyticsFolderItemEdge</class> drives the port's treatment of such an item in process.
/// <method>Hide</method> names the item; every other item, and the item before <method>Hide</method>, reads as the instance reads it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AnalyticsFolderItemHiddenSeam Extends OcuPilot.Test.AnalyticsTermListSeam
{

/// <p>Answer the item <var>pName</var> (its full name, in any letter case) as held but hidden from the caller.</p>
ClassMethod Hide(pName As %String)
{
    Set ^||OcuPilotFolderItemHidden = $ZConvert(pName, "U")
}

ClassMethod Unhide()
{
    Kill ^||OcuPilotFolderItemHidden
}

ClassMethod ReadFolderItem(pNamespace As %String, pName As %String, Output pData, Output pCaught As %Exception.AbstractException, pDetail As %Boolean = 0)
{
    Do ##super(pNamespace, pName, .pData, .pCaught, pDetail)
    If ($Get(^||OcuPilotFolderItemHidden) '= "") && ($ZConvert(pName, "U") = ^||OcuPilotFolderItemHidden) && ((+$Get(pData("code")) = 1) || (+$Get(pData("code")) = 3)) {
        Kill pData
        Set pData("code") = 2
    }
}

}
