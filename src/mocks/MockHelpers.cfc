component {

	include "/preside-test-helpers/generated/helpers/index.cfm";

	public any function init( any coldbox ) {
		if ( StructKeyExists( arguments, "coldbox" ) ) {
			variables._presideTestHelpersColdbox = arguments.coldbox;
		}

		return this;
	}

	public any function onMissingMethod( required string missingMethodName, any missingMethodArguments ) {
		var internal = [ "init", "onMissingMethod", "getController", "getSingleton" ];

		if ( !ArrayFindNoCase( internal, arguments.missingMethodName ) && IsCustomFunction( variables[ arguments.missingMethodName ] ?: "" ) ) {
			this[ arguments.missingMethodName ] = variables[ arguments.missingMethodName ];

			return variables[ arguments.missingMethodName ]( argumentCollection=arguments.missingMethodArguments );
		}

		throw(
			  type    = "PresideTestHelpers.helperNotStubbed"
			, message = "$helpers.#arguments.missingMethodName#() was called but is not stubbed. Stub it with getMockHelpers( service ).$( ""#arguments.missingMethodName#"", ... )."
		);
	}

	private any function getController() {
		if ( !StructKeyExists( variables, "_presideTestHelpersColdbox" ) ) {
			throw(
				  type    = "PresideTestHelpers.noColdbox"
				, message = "A $helpers function needed the ColdBox controller. Build the helpers with newMockPresideHelpers( coldbox=newMockColdbox() ) or use prepareService()."
			);
		}

		return variables._presideTestHelpersColdbox;
	}

	private any function getSingleton( required string name ) {
		return getController().getWireBox().getInstance( arguments.name );
	}

}
