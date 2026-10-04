/// <p><class>OcuPilot.Port.SqlPort</class> whose statement index answers no row for any statement it
/// prepares, so a test drives the port's fail-closed refusal. Everything else is the production
/// port's.</p>
Class OcuPilot.Test.SqlPortUnindexed Extends OcuPilot.Port.SqlPort
{

/// <p>The production prepare, its answer marked as having no statement-index row.</p>
ClassMethod Prepared(pNamespace As %String, pText As %String, Output pRaw As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ##super(pNamespace, pText, .pRaw)
    If $IsObject($Get(pRaw)) && (pRaw.%GetTypeOf("indexed") = "boolean") Do pRaw.%Set("indexed", 0, "boolean")
    Quit tSC
}

}
