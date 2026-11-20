/// <p>What the User-defined icons tab's three write tools share (AD-6, AD-13, AD-51, AD-53, AD-65, Story 24.13, Batch 3): adding, changing and removing one user-defined icon of the request's namespace by its
/// name, through <class>OcuPilot.Port.AnalyticsPort</class> and <code>%DeepSee.UserPortal.Utils</code>' own setters. It is <class>OcuPilot.Screen.Tool.AnalyticsSettingEntryAction</class> over the icons' global,
/// <code>^DeepSee.User.Icons</code>, with the port's <code>USERICON</code> row <code>{Name, Path, Namespace}</code> as its fresh read. A path is text: nothing loads it or draws it as an image (AD-11).</p>
Class OcuPilot.Screen.Tool.AnalyticsUserIconAction Extends OcuPilot.Screen.Tool.AnalyticsSettingEntryAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsUserIconList";

Parameter DESTINATIONGLOBAL = "^DeepSee.User.Icons";

/// <p>The fresh read: one user-defined icon.</p>
Parameter READTYPE = "USERICON";

Parameter READANSWERS = "Name,Path,Namespace";

Parameter ENTRYMEMBERS = "Path";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTUSERICONS
}

}
