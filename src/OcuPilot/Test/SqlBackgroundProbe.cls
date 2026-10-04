/// <p>Story 19.15's probe SQL objects and principals: <class>OcuPilot.Test.SqlConsoleProbe</class>'s,
/// under the schema <parameter>SCHEMA</parameter> and the principal names below, so this story's tests
/// create and remove only their own objects. <method>Make</method>, <method>Remove</method>,
/// <method>EnsurePrincipals</method> and <method>RemovePrincipals</method> are the parent's.</p>
Class OcuPilot.Test.SqlBackgroundProbe Extends OcuPilot.Test.SqlConsoleProbe
{

Parameter SCHEMA = "OcuProbe1915";

Parameter GRANTED = "OcuProbe1915.Granted";

Parameter HIDDEN = "OcuProbe1915.Hidden";

Parameter SLOW = "OcuProbe1915.Slow";

Parameter LEAVEOPEN = "OcuProbe1915.LeaveOpen";

Parameter LISTING = "OcuProbe1915.Listing";

Parameter HIDDENCOUNT = "OcuProbe1915.HiddenCount";

Parameter ECHO = "OcuProbe1915.Echo";

Parameter OWNVIEW = "OcuProbe1915.OwnView";

Parameter USER = "OcuProbe1915User";

Parameter NODEVUSER = "OcuProbe1915NoDev";

Parameter NOUSERUSER = "OcuProbe1915NoUser";

/// <p>A query over <parameter>GRANTED</parameter> that runs for about five seconds: a five-way cross
/// join's count.</p>
Parameter LONGQUERY = "SELECT COUNT(*) AS N FROM OcuProbe1915.Granted a, OcuProbe1915.Granted b, OcuProbe1915.Granted c, OcuProbe1915.Granted d, OcuProbe1915.Granted e";

}
