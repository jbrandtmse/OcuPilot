/// <p>What the quality measure editor's four write tools share (AD-6, AD-51, AD-52, AD-53, AD-61, AD-65, Story 24.12): a write of one quality measure of the request's namespace through
/// <class>OcuPilot.Port.AnalyticsPort</class>, reached by two callers, the Quality measures screen's own actions and the agent's proposal and confirmation. It is
/// <class>OcuPilot.Screen.Tool.AnalyticsListingGroupAction</class> with the measure's own screen, destination global (<code>^DeepSee.QMsrs</code>), classic page, read and port rules,
/// declared as parameters; the measure's edit resource is the screen's own pair, so it adds no pair beyond the source code API's.</p>
/// <p><b>The fresh read is the port's <code>QUALITYMEASURE</code></b>, composed for the action at the mint and at a screen action: an add reads absent, and the others are refused by the
/// port's own codes when the measure is not there or two classes declare it. The row carries the class's <code>Version</code>, so a class changed after the mint closes the proposal
/// through the fingerprint. A measure is named by its full name, <code>catalog/set/id</code>, kept exactly (AD-13).</p>
Class OcuPilot.Screen.Tool.AnalyticsQualityMeasureAction Extends OcuPilot.Screen.Tool.AnalyticsListingGroupAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureList";

Parameter DESTINATIONGLOBAL = "^DeepSee.QMsrs";

Parameter CLASSICPAGES = "%DeepSee.UI.QualityMeasures";

/// <p>The fresh read: one quality measure.</p>
Parameter READTYPE = "QUALITYMEASURE";

Parameter READANSWERS = "Name,Catalog,Set,Id,Class,Caption,Description,SubjectArea,Expression,LinkedTo,Published,Format,Href,Compiled,Groups,Version,Namespace";

/// <p>The consequence every write states unless it declares its own: the class is saved and compiled (published once in EXPERIENCE.md's Fixed strings).</p>
Parameter CONSEQUENCECODE = "ANALYTICS.QUALITYMEASURE.SAVE";

/// <p>No SQL consequence: a measure holds no SQL.</p>
Parameter SQLCONSEQUENCECODE = "";

/// <p>The measure's edit resource is the screen's own pair, which the pairs already hold.</p>
ClassMethod EditPairs() As %String
{
    Quit ""
}

Parameter VIOLATIONSMETHOD = "QualityMeasureViolations";

Parameter PROBLEMMETHOD = "QualityMeasureProblem";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTQUALITYMEASURES
}

}
