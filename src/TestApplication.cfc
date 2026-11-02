component {

	variables._presideTestHelpersDir = GetDirectoryFromPath( GetCurrentTemplatePath() );

	this.mappings[ "/tests"                ] = ExpandPath( "/" );
	this.mappings[ "/preside-test-helpers" ] = variables._presideTestHelpersDir;
	this.mappings[ "/testbox"              ] = variables._presideTestHelpersDir & "testbox";
	this.mappings[ "/preside"              ] = variables._presideTestHelpersDir & "stubs/preside";
	this.mappings[ "/coldbox"              ] = variables._presideTestHelpersDir & "stubs/coldbox";

	setting requesttimeout=60000;

}
