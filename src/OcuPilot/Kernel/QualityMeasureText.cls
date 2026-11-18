/// <p>The text of a quality measure's class (Story 24.12): a class extending <code>%DeepSee.QualityMeasure.QualityMeasure</code> whose <code>QualityMeasure</code>
/// XData holds the measure, in the form <class>OcuPilot.Kernel.ListingGroupText</class> keeps a class: it extends that class and differs by the superclass, the XML
/// namespace and the XData's name, and by declaring no <code>DependsOn</code>, so an update replaces only the XData body. Every method is pure.</p>
Class OcuPilot.Kernel.QualityMeasureText Extends OcuPilot.Kernel.ListingGroupText
{

Parameter SUPERCLASS = "%DeepSee.QualityMeasure.QualityMeasure";

Parameter XMLNAMESPACE = "http://www.intersystems.com/deepsee/qualityMeasure";

Parameter XDATANAME = "QualityMeasure";

Parameter DEPENDSON = 0;

}
