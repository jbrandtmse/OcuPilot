/// <p>The seam <class>OcuPilot.Test.ScreenAccessGate</class> drives <class>OcuPilot.Screen.Gate</class>
/// through (AD-64): its adjustment read and its classic-resource lookup answer what the process-private
/// <code>^||OcuPilotAccessSeam</code> says -- <code>("mode")</code> <code>fail</code> makes the adjustment
/// unreadable, <code>("classic")</code> names a custom resource every page carries -- and otherwise the
/// real gate's answers. Not a test class.</p>
Class OcuPilot.Test.ScreenAccessGateSeam Extends OcuPilot.Screen.Gate
{

/// <p>Unreadable under <code>("mode") = "fail"</code>, else the real store's answer.</p>
ClassMethod AdjustedPairs(pDescriptor As %String, Output pFound As %Boolean, Output pResolved As %Boolean) As %List
{
    If $Get(^||OcuPilotAccessSeam("mode")) = "fail" {
        Set pFound = 0
        Set pResolved = 0
        Quit ""
    }
    Quit ##super(pDescriptor, .pFound, .pResolved)
}

/// <p><code>("classic")</code> when set, else the real lookup.</p>
ClassMethod ClassicResource(pPageClass As %String) As %String
{
    If $Get(^||OcuPilotAccessSeam("classic")) '= "" Quit ^||OcuPilotAccessSeam("classic")
    Quit ##super(pPageClass)
}

}
