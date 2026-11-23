/// <p>SQL field statistics' Set selectivity (Story 21.31, AD-6, AD-7, AD-51, AD-53, AD-56, AD-58): set one field's selectivity as a fixed statistic, which the
/// optimizer uses in place of the collected one. Two callers reach it: the Field statistics tab's Set selectivity row action, whose one value is
/// <code>Selectivity</code>, and the agent's proposal and confirmation, which may also send the outlier selectivity, the outlier value and the average
/// field size. The target is the composite <code>[Table, Field]</code> (<class>OcuPilot.Screen.Tool.SqlFieldMint</class>). It runs in the request. A
/// table whose statistics were collected has them saved as its fixed statistics first. An outlier selectivity, outlier value or average size that is not
/// sent keeps the fixed value the field holds, since the instance clears one it is not given. The instance runs an outlier value as an ObjectScript
/// expression, so it is accepted only as a number or as text in double quotes. A field the table does not hold is refused at the fresh read, 400, and
/// a field of a table of OcuPilot's own is refused, for both callers, before anything is written. Its governance key ships disabled.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlFieldSetSelectivity Extends OcuPilot.Screen.Tool.SqlTableSetAction
{

Parameter TOOLNAME = "explorer.sqlfieldstatistics.setselectivity";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlFieldStatistics";

Parameter DESCRIPTION = "Propose setting the selectivity of one field of one SQL table as a fixed statistic, which the optimizer uses in place of the collected one until the table's fixed statistics are cleared. If the table's statistics were collected, they are first saved as its fixed statistics. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the table as Schema.Table, as explorer.sqltables.read reports it in its Table column, and the field as explorer.sqlfieldstatistics.read reports it in its Field column. Give Selectivity as 1, for a unique field, or as a percentage over 0% and up to 99.999%. OutlierSelectivity, OutlierValue and AverageFieldSize are optional: one you leave out keeps the value the field holds. OutlierValue is a number, or text in double quotes, of at most 128 characters, and only takes effect with an OutlierSelectivity. A field of a table of OcuPilot's own is refused.";

/// <p>The fresh read: the one field's statistics.</p>
Parameter READTYPE = "FIELDSTATS";

Parameter READANSWERS = "Namespace,Table,Class,Field,Selectivity,OutlierSelectivity,OutlierValue,AverageFieldSize,StatsKind,HasFixed";

Parameter WRITETYPE = "SETSELECTIVITY";

Parameter SCREENACTIONS = "set-selectivity";

Parameter SCREENVALUES = "set-selectivity=Selectivity";

Parameter VALUENAMES = "Selectivity,OutlierSelectivity,OutlierValue,AverageFieldSize";

Parameter REQUIREDVALUES = "Selectivity";

Parameter VALUEDESCRIPTIONS = "Selectivity=The field's new selectivity: 1, for a unique field, or a percentage over 0% and up to 99.999%, with or without the percent sign.|OutlierSelectivity=The selectivity of the field's outlier value, as a percentage over 0% and up to 99.999%. Omit it to keep the one the field holds.|OutlierValue=The field's outlier value: a number, or text in double quotes, of at most 128 characters. It only takes effect with an outlier selectivity. Omit it to keep the one the field holds.|AverageFieldSize=The field's average size, as a whole number, 0 or more. Omit it to keep the one the field holds.";

Parameter FINGERPRINTSUBJECT = "Namespace,Table,Field,Selectivity,OutlierSelectivity,OutlierValue,AverageFieldSize,StatsKind,HasFixed";

Parameter PRECONDITIONFIELD = "StatsKind";

Parameter SECONDARGUMENT = "Field";

Parameter SECONDDESCRIPTION = "The field to change, named as the table's Field statistics tab reports it in its Field column.";

Parameter CONSEQUENCECODE = "SQL.TABLE.SETSELECTIVITY";

/// <p><class>OcuPilot.Screen.Tool.SqlFieldMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.SqlFieldMint"
}

}
