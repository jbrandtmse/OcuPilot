/// <p>Narrowed limits for the turn's token bound at billed weight (Story 18.39):
/// <class>OcuPilot.Test.TurnLimitsBudget</class>'s four calls, with a token limit of 3,200 -- under
/// the 4,000 or more that two replies of a cached prompt report whole, and over what the second of
/// them counts once its cache reads are weighted.</p>
Class OcuPilot.Test.TurnLimitsBilled Extends OcuPilot.Test.TurnLimitsBudget
{

Parameter MAXTOKENS As %Integer = 3200;

}
