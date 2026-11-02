component extends="testbox.system.BaseSpec" {

	public any function prepareService(
		  required any     service
		,          struct  features            = {}
		,          boolean defaultFeatureState = true
		,          struct  settings            = {}
		,          struct  coldboxSettings     = {}
		,          struct  objects             = {}
		,          struct  extensions          = {}
		,          any     helpers
	) {
		var svc   = prepareMock( arguments.service );
		var state = {
			  features            = Duplicate( arguments.features )
			, defaultFeatureState = arguments.defaultFeatureState
			, settings            = Duplicate( arguments.settings )
			, extensions          = Duplicate( arguments.extensions )
			, objects             = StructCopy( arguments.objects )
			, listeners           = {}
		};

		state.requestContext       = newMockRequestContext();
		state.coldbox              = newMockColdbox( requestContext=state.requestContext, settings=Duplicate( arguments.coldboxSettings ) );
		state.presideObjectService = newMockPresideObjectService( objects=state.objects );
		state.systemConfiguration  = newMockSystemConfigurationService( settings=state.settings );
		state.validationEngine     = newMockValidationEngine();
		state.helpers              = StructKeyExists( arguments, "helpers" ) ? arguments.helpers : newMockPresideHelpers( coldbox=state.coldbox );

		for ( var helper in getPresideHelperSignatures() ) {
			svc.$( helper.name ).$callback( _notStubbedCallback( helper.name ) );
		}

		svc.$( "$getPresideObject" ).$callback( function( objectName ) {
			return _getOrCreateObjectMock( state.objects, arguments.objectName ?: "" );
		} );
		svc.$( "$getPresideObjectService", state.presideObjectService );
		svc.$( "$getSystemConfigurationService", state.systemConfiguration );
		svc.$( "$getPresideSetting" ).$callback( function( category, setting, default="" ) {
			return _getSetting( state.settings, arguments.category ?: "", arguments.setting ?: "", arguments.default );
		} );
		svc.$( "$getPresideCategorySettings" ).$callback( function( category ) {
			return Duplicate( state.settings[ arguments.category ?: "" ] ?: {} );
		} );
		svc.$( "$isFeatureEnabled" ).$callback( function( feature ) {
			return _isFeatureEnabled( state, arguments.feature ?: "" );
		} );
		svc.$( "$isExtensionInstalled" ).$callback( function( extensionId ) {
			return state.extensions[ arguments.extensionId ?: "" ] ?: false;
		} );
		svc.$( "$translateResource" ).$callback( function( uri="", defaultValue="" ) {
			return Len( arguments.defaultValue ) ? arguments.defaultValue : arguments.uri;
		} );
		svc.$( "$translateObjectName" ).$callback( function( objectName="" ) {
			return arguments.objectName;
		} );
		svc.$( "$translatePropertyName" ).$callback( function( objectName="", propertyName="" ) {
			return arguments.propertyName;
		} );
		svc.$( "$getI18nLocale", "en" );
		svc.$( "$announceInterception" ).$callback( _announceCallback( state.listeners ) );
		svc.$( "$raiseError" );
		svc.$( "$audit" );
		svc.$( "$systemOutput" );
		svc.$( "$isInterrupted", false );
		svc.$( "$getApplicationId", "presidetesthelpers" );
		svc.$( "$getColdbox", state.coldbox );
		svc.$( "$getRequestContext", state.requestContext );
		svc.$( "$getValidationEngine", state.validationEngine );
		svc.$( "$newValidationResult" ).$callback( function() {
			return newMockValidationResult();
		} );
		svc.$( "$isAdminUserLoggedIn", false );
		svc.$( "$getAdminLoggedInUserId", "" );
		svc.$( "$getAdminLoggedInUserDetails", {} );
		svc.$( "$isWebsiteUserLoggedIn", false );
		svc.$( "$isWebsiteUserImpersonated", false );
		svc.$( "$getWebsiteLoggedInUserId", "" );
		svc.$( "$getWebsiteLoggedInUserDetails", {} );
		svc.$( "$slugify" ).$callback( function( str="", numeric maxLength=0, allow="", preserveCase=false ) {
			return _slugify( argumentCollection=arguments );
		} );

		svc.$property( propertyName="$helpers", propertyScope="this", mock=state.helpers );
		svc.$property( propertyName="$helpers", mock=state.helpers );
		svc.$property( propertyName="_presideTestHelpersState", mock=state );

		return svc;
	}

	public any function getMockPresideObject( required any service, required string objectName ) {
		return _getOrCreateObjectMock( _getState( arguments.service ).objects, arguments.objectName );
	}

	public any function getMockHelpers( required any service ) {
		return _getState( arguments.service ).helpers;
	}

	public any function getMockColdbox( required any service ) {
		return _getState( arguments.service ).coldbox;
	}

	public any function getMockRequestContext( required any service ) {
		return _getState( arguments.service ).requestContext;
	}

	public any function getMockValidationEngine( required any service ) {
		return _getState( arguments.service ).validationEngine;
	}

	public any function getMockPresideObjectService( required any service ) {
		return _getState( arguments.service ).presideObjectService;
	}

	public any function getMockSystemConfigurationService( required any service ) {
		return _getState( arguments.service ).systemConfiguration;
	}

	public void function setFeature( required any service, required string feature, required boolean enabled ) {
		_getState( arguments.service ).features[ arguments.feature ] = arguments.enabled;
	}

	public void function setPresideSetting( required any service, required string category, required string setting, required any value ) {
		var settings = _getState( arguments.service ).settings;

		if ( !StructKeyExists( settings, arguments.category ) ) {
			settings[ arguments.category ] = {};
		}
		settings[ arguments.category ][ arguments.setting ] = arguments.value;
	}

	public void function onAnnounce( required any service, required string interceptionPoint, required any listener ) {
		var listeners = _getState( arguments.service ).listeners;

		if ( !StructKeyExists( listeners, arguments.interceptionPoint ) ) {
			listeners[ arguments.interceptionPoint ] = [];
		}
		ArrayAppend( listeners[ arguments.interceptionPoint ], arguments.listener );
	}

	public array function getAnnouncedInterceptions( required any service, string interceptionPoint="" ) {
		var calls     = arguments.service.$callLog()[ "$announceInterception" ] ?: [];
		var announced = [];

		for ( var callArgs in calls ) {
			var point = callArgs.state ?: ( callArgs[ 1 ] ?: "" );
			var data  = callArgs.interceptData ?: ( callArgs[ 2 ] ?: {} );

			if ( !Len( arguments.interceptionPoint ) || point == arguments.interceptionPoint ) {
				ArrayAppend( announced, { interceptionPoint=point, interceptData=data } );
			}
		}

		return announced;
	}

	public void function expectAnnounced( required any service, required string interceptionPoint, struct interceptData ) {
		var announced = getAnnouncedInterceptions( arguments.service, arguments.interceptionPoint );

		expect( ArrayLen( announced ) ).toBeGT( 0, "Expected interception [#arguments.interceptionPoint#] to be announced but it was not." );

		if ( StructKeyExists( arguments, "interceptData" ) ) {
			var matched = false;
			for ( var announcement in announced ) {
				if ( _structContains( announcement.interceptData, arguments.interceptData ) ) {
					matched = true;
					break;
				}
			}
			expect( matched ).toBeTrue( "Interception [#arguments.interceptionPoint#] was announced but never with data matching #SerializeJson( arguments.interceptData )#." );
		}
	}

	public void function expectNotAnnounced( required any service, required string interceptionPoint ) {
		expect( ArrayLen( getAnnouncedInterceptions( arguments.service, arguments.interceptionPoint ) ) ).toBe( 0, "Expected interception [#arguments.interceptionPoint#] not to be announced." );
	}

	public array function getRaisedErrors( required any service ) {
		var calls  = arguments.service.$callLog()[ "$raiseError" ] ?: [];
		var errors = [];

		for ( var callArgs in calls ) {
			ArrayAppend( errors, callArgs.error ?: ( callArgs[ 1 ] ?: {} ) );
		}

		return errors;
	}

	public any function newMockPresideObjectService( struct objects={} ) {
		var objectMocks = arguments.objects;
		var pos         = createStub();

		pos.$( "getObject" ).$callback( function( objectName ) {
			return _getOrCreateObjectMock( objectMocks, arguments.objectName ?: "" );
		} );
		pos.$( "objectExists", true );
		pos.$( "fieldExists", true );
		pos.$( "getObjectAttribute" ).$callback( function( objectName, attributeName, defaultValue="" ) {
			return arguments.defaultValue;
		} );
		pos.$( "getObjectPropertyAttribute" ).$callback( function( objectName, propertyName, attributeName, defaultValue="" ) {
			return arguments.defaultValue;
		} );
		pos.$( "getIdField", "id" );
		pos.$( "getLabelField", "label" );
		pos.$( "selectData" ).$callback( function( objectName ) {
			return _getOrCreateObjectMock( objectMocks, arguments.objectName ?: "" ).selectData( argumentCollection=arguments );
		} );
		pos.$( "insertData" ).$callback( function( objectName ) {
			return _getOrCreateObjectMock( objectMocks, arguments.objectName ?: "" ).insertData( argumentCollection=arguments );
		} );
		pos.$( "updateData" ).$callback( function( objectName ) {
			return _getOrCreateObjectMock( objectMocks, arguments.objectName ?: "" ).updateData( argumentCollection=arguments );
		} );
		pos.$( "deleteData" ).$callback( function( objectName ) {
			return _getOrCreateObjectMock( objectMocks, arguments.objectName ?: "" ).deleteData( argumentCollection=arguments );
		} );
		pos.$( "dataExists" ).$callback( function( objectName ) {
			return _getOrCreateObjectMock( objectMocks, arguments.objectName ?: "" ).dataExists( argumentCollection=arguments );
		} );
		pos.$property( propertyName="_objectMocks", mock=objectMocks );

		return pos;
	}

	public any function newMockRequestContext( struct collection={}, struct privateCollection={} ) {
		var rc    = createStub();
		var store = { public=arguments.collection, private=arguments.privateCollection };

		rc.$( "getCollection" ).$callback( function( boolean private=false ) {
			return arguments.private ? store.private : store.public;
		} );
		rc.$( "getValue" ).$callback( function( required string name, any defaultValue="", boolean private=false ) {
			var scope = arguments.private ? store.private : store.public;

			return StructKeyExists( scope, arguments.name ) ? scope[ arguments.name ] : arguments.defaultValue;
		} );
		rc.$( "setValue" ).$callback( function( required string name, any value, boolean private=false ) {
			var scope = arguments.private ? store.private : store.public;
			scope[ arguments.name ] = arguments.value ?: "";

			return rc;
		} );
		rc.$( "valueExists" ).$callback( function( required string name, boolean private=false ) {
			return StructKeyExists( arguments.private ? store.private : store.public, arguments.name );
		} );
		rc.$( "paramValue" ).$callback( function( required string name, required any value, boolean private=false ) {
			var scope = arguments.private ? store.private : store.public;
			if ( !StructKeyExists( scope, arguments.name ) ) {
				scope[ arguments.name ] = arguments.value;
			}

			return rc;
		} );
		rc.$( "getPrivateCollection" ).$callback( function() {
			return store.private;
		} );
		rc.$( "isAdminRequest", false );
		rc.$( "isAjax", false );
		rc.$( "isApiRequest", false );
		rc.$( "getSite", { id="", name="", domain="localhost", path="/", protocol="https", template="" } );
		rc.$( "getSiteId", "" );
		rc.$( "getLanguage", "" );
		rc.$( "getLocale", "en" );
		rc.$( "getCurrentUrl", "/" );
		rc.$( "getCurrentEvent", "" );
		rc.$( "getHTTPMethod", "GET" );
		rc.$( "getClientIp", "127.0.0.1" );
		rc.$( "getUserAgent", "" );
		rc.$( "getCurrentPageId", "" );
		rc.$( "isBackgroundThread", false );
		rc.$( "buildLink" ).$callback( function() {
			return "/link/?" & _linkQueryString( arguments );
		} );
		rc.$( "buildAdminLink" ).$callback( function() {
			return "/admin/link/?" & _linkQueryString( arguments );
		} );

		return rc;
	}

	public any function newMockColdbox( any requestContext, struct settings={} ) {
		var controller     = createStub();
		var event          = StructKeyExists( arguments, "requestContext" ) ? arguments.requestContext : newMockRequestContext();
		var configSettings = arguments.settings;
		var requestService = createStub();
		var wirebox        = createStub();
		var instances      = { i18n=createStub() };

		instances.i18n.$( "getFwLocale", "en_GB" );
		instances.i18n.$( "getFwLanguageCode", "en" );
		instances.i18n.$( "getFwCountryCode", "GB" );
		requestService.$( "getContext", event );
		wirebox.$( "getInstance" ).$callback( function( name ) {
			var instanceName = arguments.name ?: "";
			if ( !StructKeyExists( instances, instanceName ) ) {
				instances[ instanceName ] = createStub();
			}

			return instances[ instanceName ];
		} );
		wirebox.$( "containsInstance", true );

		controller.$( "getRequestContext", event );
		controller.$( "getRequestService", requestService );
		controller.$( "getWireBox", wirebox );
		controller.$( "getSetting" ).$callback( function( name, fwSetting=false, defaultValue="" ) {
			return configSettings[ arguments.name ?: "" ] ?: arguments.defaultValue;
		} );
		controller.$( "settingExists" ).$callback( function( name ) {
			return StructKeyExists( configSettings, arguments.name ?: "" );
		} );
		controller.$( "getConfigSettings", configSettings );
		controller.$( "runEvent" );
		controller.$( "renderViewlet", "" );
		controller.$( "setNextEvent" );
		controller.$( "relocate" );

		return controller;
	}

	public any function newMockSystemConfigurationService( struct settings={} ) {
		var configSettings = arguments.settings;
		var service        = createStub();

		service.$( "getSetting" ).$callback( function( category, setting, default="" ) {
			return _getSetting( configSettings, arguments.category ?: "", arguments.setting ?: "", arguments.default );
		} );
		service.$( "getCategorySettings" ).$callback( function( category ) {
			return Duplicate( configSettings[ arguments.category ?: "" ] ?: {} );
		} );
		service.$( "saveSetting" ).$callback( function( category, setting, value="" ) {
			if ( !StructKeyExists( configSettings, arguments.category ) ) {
				configSettings[ arguments.category ] = {};
			}
			configSettings[ arguments.category ][ arguments.setting ] = arguments.value;
		} );

		return service;
	}

	public any function newMockValidationEngine() {
		var engine = createStub();

		engine.$( "newValidationResult" ).$callback( function() {
			return newMockValidationResult();
		} );
		engine.$( "validate" ).$callback( function() {
			return newMockValidationResult();
		} );

		return engine;
	}

	public any function newMockValidationResult( struct errors={}, string generalMessage="" ) {
		var result = createStub();
		var state  = { errors=StructCopy( arguments.errors ), generalMessage=arguments.generalMessage };

		result.$( "validated" ).$callback( function() {
			return StructIsEmpty( state.errors ) && !Len( state.generalMessage );
		} );
		result.$( "addError" ).$callback( function( required string fieldName, required string message, array params=[] ) {
			state.errors[ arguments.fieldName ] = { message=arguments.message, params=arguments.params };
		} );
		result.$( "fieldHasError" ).$callback( function( required string fieldName ) {
			return StructKeyExists( state.errors, arguments.fieldName );
		} );
		result.$( "getError" ).$callback( function( required string fieldName ) {
			return state.errors[ arguments.fieldName ].message ?: "";
		} );
		result.$( "getMessages" ).$callback( function() {
			return state.errors;
		} );
		result.$( "listErrorFields" ).$callback( function() {
			return StructKeyList( state.errors );
		} );
		result.$( "setGeneralMessage" ).$callback( function( required string message ) {
			state.generalMessage = arguments.message;
		} );
		result.$( "getGeneralMessage" ).$callback( function() {
			return state.generalMessage;
		} );

		return result;
	}

	public any function newMockPresideHelpers( any coldbox ) {
		return prepareMock( CreateObject( "component", "preside-test-helpers.mocks.MockHelpers" ).init( argumentCollection=arguments ) );
	}

	public query function queryFromRows( required array rows, string columns="", struct columnTypes={} ) {
		var columnList = arguments.columns;

		if ( !Len( columnList ) && ArrayLen( arguments.rows ) ) {
			columnList = StructKeyList( arguments.rows[ 1 ] );
		}

		var columnArray = ListToArray( columnList );
		var typeArray   = [];
		for ( var column in columnArray ) {
			ArrayAppend( typeArray, arguments.columnTypes[ column ] ?: "varchar" );
		}

		var qry = QueryNew( ArrayToList( columnArray ), ArrayToList( typeArray ) );
		for ( var row in arguments.rows ) {
			QueryAddRow( qry );
			for ( var column in columnArray ) {
				if ( StructKeyExists( row, column ) && !IsNull( row[ column ] ) ) {
					QuerySetCell( qry, column, row[ column ] );
				}
			}
		}

		return qry;
	}

	public array function getPresideHelperSignatures() {
		if ( !StructKeyExists( request, "_presideTestHelpersHelperSignatures" ) ) {
			request._presideTestHelpersHelperSignatures = DeserializeJson( FileRead( ExpandPath( "/preside-test-helpers/generated/HelperSignatures.json" ) ) );
		}

		return request._presideTestHelpersHelperSignatures;
	}

	private any function _getState( required any service ) {
		return arguments.service.$getProperty( name="_presideTestHelpersState" );
	}

	private any function _getOrCreateObjectMock( required struct objectMocks, required string objectName ) {
		if ( !StructKeyExists( arguments.objectMocks, arguments.objectName ) ) {
			arguments.objectMocks[ arguments.objectName ] = createStub();
		}

		return arguments.objectMocks[ arguments.objectName ];
	}

	private any function _getSetting( required struct settings, required string category, required string setting, any default="" ) {
		if ( StructKeyExists( arguments.settings, arguments.category ) && StructKeyExists( arguments.settings[ arguments.category ], arguments.setting ) ) {
			return arguments.settings[ arguments.category ][ arguments.setting ];
		}

		return arguments.default;
	}

	private boolean function _isFeatureEnabled( required struct state, required string feature ) {
		var feature = Trim( arguments.feature );

		if ( ReFind( "[|&\(\)!\s]+", feature ) && ReFind( "^[|&\(\)!\sa-zA-Z0-9_\-]+$", feature ) ) {
			var compiled = feature;
			var names    = ReMatch( "\b[a-zA-Z0-9_\-]+\b", feature );

			ArraySort( names, function( a, b ) {
				return Len( arguments.a ) == Len( arguments.b ) ? 0 : ( Len( arguments.a ) < Len( arguments.b ) ? 1 : -1 );
			} );

			for ( var name in names ) {
				if ( name != "not" && name != "and" && name != "or" ) {
					compiled = ReplaceNoCase( compiled, name, _isFeatureEnabled( arguments.state, name ) ? "true" : "false", "all" );
				}
			}

			try {
				return Evaluate( compiled );
			} catch ( any e ) {
				throw( type="preside.feature.bad.expression", message="The feature name expression, [#feature#], could not be evaluated. Compiler error: [#e.message#]." );
			}
		}

		return StructKeyExists( arguments.state.features, feature ) ? arguments.state.features[ feature ] : arguments.state.defaultFeatureState;
	}

	private string function _slugify( required string str, numeric maxLength=0, string allow="", boolean preserveCase=false ) {
		var slug         = Trim( arguments.str );
		var specialChars = "á,à,â,ä,ã,å,é,è,ê,ë,í,ì,î,ï,ó,ò,ô,ö,õ,ø,ú,ù,û,ü,ñ,ç,ß,Á,À,Â,Ä,Ã,Å,É,È,Ê,Ë,Í,Ì,Î,Ï,Ó,Ò,Ô,Ö,Õ,Ø,Ú,Ù,Û,Ü,Ñ,Ç";
		var asciiChars   = "a,a,a,ae,a,a,e,e,e,e,i,i,i,i,o,o,o,oe,o,o,u,u,ue,u,n,c,ss,A,A,A,Ae,A,A,E,E,E,E,I,I,I,I,O,O,O,Oe,O,O,U,U,U,Ue,N,C";

		slug = ReplaceList( slug, specialChars, asciiChars );

		if ( !arguments.preserveCase ) {
			slug = LCase( slug );
		}

		slug = ReReplace( slug, "[^a-zA-Z0-9-\s#arguments.allow#]", "", "all" );
		slug = Trim( ReReplace( slug, "[\s-]+", " ", "all" ) );
		slug = ReReplace( slug, "\s", "-", "all" );

		if ( arguments.maxLength ) {
			slug = Left( slug, arguments.maxLength );
		}

		return slug;
	}

	private string function _linkQueryString( required struct linkArgs ) {
		var parts = [];

		for ( var key in arguments.linkArgs ) {
			if ( !IsNumeric( key ) && IsSimpleValue( arguments.linkArgs[ key ] ) && Len( arguments.linkArgs[ key ] ) ) {
				ArrayAppend( parts, LCase( key ) & "=" & arguments.linkArgs[ key ] );
			}
		}
		ArraySort( parts, "text" );

		return ArrayToList( parts, "&" );
	}

	private any function _announceCallback( required struct listeners ) {
		var listeners = arguments.listeners;

		return function( state, interceptData ) {
			var point = arguments.state ?: "";
			var data  = arguments.interceptData ?: {};

			for ( var listener in listeners[ point ] ?: [] ) {
				listener( data );
			}

			return true;
		};
	}

	private any function _notStubbedCallback( required string helperName ) {
		var helperName = arguments.helperName;

		return function() {
			throw(
				  type    = "PresideTestHelpers.helperNotStubbed"
				, message = "#helperName#() was called but has no default in preside-test-helpers. Stub it in your spec with service.$( ""#helperName#"", ... )."
			);
		};
	}

	private boolean function _structContains( required any actual, required struct expected ) {
		if ( !IsStruct( arguments.actual ) ) {
			return false;
		}

		for ( var key in arguments.expected ) {
			if ( !StructKeyExists( arguments.actual, key ) ) {
				return false;
			}
			var actualValue   = arguments.actual[ key ];
			var expectedValue = arguments.expected[ key ];

			if ( IsStruct( expectedValue ) ) {
				if ( !_structContains( actualValue, expectedValue ) ) {
					return false;
				}
			} else if ( IsSimpleValue( expectedValue ) ) {
				if ( !IsSimpleValue( actualValue ) || Compare( ToString( actualValue ), ToString( expectedValue ) ) != 0 ) {
					return false;
				}
			} else if ( SerializeJson( actualValue ) != SerializeJson( expectedValue ) ) {
				return false;
			}
		}

		return true;
	}

}
