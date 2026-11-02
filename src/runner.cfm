<cfscript>
	param name="url.reporter"  default="simple";
	param name="url.directory" default="tests.unit";
	param name="url.bundles"   default="";
	param name="url.labels"    default="";

	if ( Len( url.bundles ) ) {
		testbox = new testbox.system.TestBox( options={}, reporter=url.reporter, labels=url.labels, bundles=url.bundles );
	} else {
		testbox = new testbox.system.TestBox( options={}, reporter=url.reporter, labels=url.labels, directory={
			  recurse = true
			, mapping = url.directory
		} );
	}

	results = Trim( testbox.run() );

	content reset=true; echo( results ); abort;
</cfscript>
