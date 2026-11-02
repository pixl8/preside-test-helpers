component {

	variables.helperExcludes = [ "presideProxies", "datamanagerAuditHelpers", "datamanagerWorkflowHelpers", "webflowHelpers" ];
	variables.stubDirectories = [ "system/base", "system/handlers" ];
	variables.stubClasses     = [
		  "coldbox.system.FrameworkSupertype"
		, "coldbox.system.EventHandler"
		, "coldbox.system.Interceptor"
		, "coldbox.system.logging.AbstractAppender"
		, "preside.system.services.concurrency.AbstractHeartBeat"
	];

	public void function run( string version="", string testboxVersion="", string presideRoot="", boolean zip=true ) {
		var packageRoot = _normalise( GetDirectoryFromPath( GetCurrentTemplatePath() ) );
		var presideDir  = Len( arguments.presideRoot ) ? arguments.presideRoot : getSystemSetting( "PRESIDE_ROOT", "" );
		presideDir      = Len( presideDir ) ? resolvePath( presideDir ) : "";

		if ( !Len( presideDir ) || !FileExists( presideDir & "/system/services/PresideSuperClass.cfc" ) ) {
			error( "No Preside source found. Pass :presideRoot=/path/to/preside or set the PRESIDE_ROOT environment variable to a Preside checkout or installed package of the version being built." );
		}

		var root        = _normalise( presideDir );
		var presideBox  = DeserializeJson( FileRead( root & "box.json" ) );
		var version     = Len( arguments.version ) ? arguments.version : getSystemSetting( "RELEASE_VERSION", "" );
		var tbVersion   = Len( arguments.testboxVersion ) ? arguments.testboxVersion : ( presideBox.devDependencies.testbox ?: "5.4.0" );
		var distRoot    = packageRoot & "dist/";
		var outDir      = distRoot & "preside-test-helpers/";

		if ( !Len( version ) || Find( "$", version ) ) {
			error( "No Preside version given. Pass :version=x.y.z or set the RELEASE_VERSION environment variable." );
		}

		print.line( "Building preside-test-helpers@#version# from #root#" ).toConsole();

		if ( DirectoryExists( outDir ) ) {
			DirectoryDelete( outDir, true );
		}
		DirectoryCreate( outDir, true, true );
		DirectoryCopy( packageRoot & "src", outDir, true );
		FileCopy( packageRoot & "README.md", outDir & "README.md" );
		FileCopy( packageRoot & "LICENSE.txt", outDir & "LICENSE.txt" );

		_setMappings( root );

		var signatures = _generateHelperSignatures();
		DirectoryCreate( outDir & "generated", true, true );
		FileWrite( outDir & "generated/HelperSignatures.json", SerializeJson( signatures ) );
		print.line( "  helper signatures: #ArrayLen( signatures )#" ).toConsole();

		var helperFiles = _copyHelpers( root & "system/helpers/", outDir & "generated/helpers/" );
		print.line( "  helper includes:   #ArrayLen( helperFiles )#" ).toConsole();

		var stubbed = _writeStubs( root, outDir & "stubs/" );
		print.line( "  framework stubs:   #stubbed#" ).toConsole();

		var boxJson = FileRead( outDir & "box.json" );
		boxJson = Replace( boxJson, "PRESIDE_VERSION", version, "all" );
		boxJson = Replace( boxJson, "TESTBOX_VERSION", tbVersion, "all" );
		FileWrite( outDir & "box.json", boxJson );

		FileWrite( outDir & "version.json", SerializeJson( {
			  "presideVersion" = version
			, "testboxVersion" = tbVersion
			, "built"          = DateTimeFormat( Now(), "yyyy-mm-dd'T'HH:nn:ss" )
		} ) );

		if ( arguments.zip ) {
			var zipFile = distRoot & "preside-test-helpers-#version#.zip";
			if ( FileExists( zipFile ) ) {
				FileDelete( zipFile );
			}
			cfzip( action="zip", file=zipFile, source=outDir, recurse=true );
			print.line( "  zip: #zipFile#" ).toConsole();
		}

		print.greenLine( "Built #outDir#" );
	}

	private void function _setMappings( required string root ) {
		var maps = getApplicationSettings().mappings ?: {};

		maps[ "/preside" ] = arguments.root;
		maps[ "/coldbox" ] = arguments.root & "system/externals/coldbox";

		application action="update" mappings=maps;
	}

	private array function _generateHelperSignatures() {
		var meta       = GetComponentMetadata( "preside.system.services.PresideSuperClass" );
		var signatures = [];

		for ( var fn in meta.functions ) {
			if ( Left( fn.name, 1 ) == "$" && ( fn.access ?: "public" ) == "public" ) {
				var params = [];
				for ( var param in fn.parameters ) {
					ArrayAppend( params, {
						  "name"     = param.name
						, "type"     = param.type ?: "any"
						, "required" = param.required ?: false
					} );
				}
				ArrayAppend( signatures, { "name"=fn.name, "returnType"=fn.returntype ?: "any", "parameters"=params } );
			}
		}

		ArraySort( signatures, function( a, b ) {
			return Compare( a.name, b.name );
		} );

		return signatures;
	}

	private array function _copyHelpers( required string helpersDir, required string outDir ) {
		var files    = DirectoryList( arguments.helpersDir, false, "name", "*.cfm", "name" );
		var included = [];
		var lines    = [];

		DirectoryCreate( arguments.outDir, true, true );

		for ( var fileName in files ) {
			var helperName = ListFirst( fileName, "." );

			if ( ArrayFindNoCase( variables.helperExcludes, helperName ) ) {
				continue;
			}
			FileCopy( arguments.helpersDir & fileName, arguments.outDir & fileName );
			ArrayAppend( included, helperName );
			ArrayAppend( lines, '<cfinclude template="/preside-test-helpers/generated/helpers/#fileName#">' );
		}

		FileWrite( arguments.outDir & "index.cfm", ArrayToList( lines, Chr( 10 ) ) & Chr( 10 ) );

		return included;
	}

	private numeric function _writeStubs( required string root, required string stubsDir ) {
		var queue    = Duplicate( variables.stubClasses );
		var done     = {};
		var failures = [];

		for ( var dir in variables.stubDirectories ) {
			var files = DirectoryList( arguments.root & dir, true, "path", "*.cfc" );
			for ( var filePath in files ) {
				var relative = ReReplaceNoCase( Mid( Replace( filePath, "\", "/", "all" ), Len( arguments.root ) + 1, Len( filePath ) ), "\.cfc$", "" );
				ArrayAppend( queue, "preside." & Replace( relative, "/", ".", "all" ) );
			}
		}

		while ( ArrayLen( queue ) ) {
			var className = queue[ 1 ];
			ArrayDeleteAt( queue, 1 );

			if ( StructKeyExists( done, className ) ) {
				continue;
			}
			done[ className ] = true;

			try {
				var parent = _writeStub( className, arguments.stubsDir );
				if ( Len( parent ) && !StructKeyExists( done, parent ) ) {
					ArrayAppend( queue, parent );
				}
			} catch ( any e ) {
				ArrayAppend( failures, "#className#: #e.message#" );
			}
		}

		if ( ArrayLen( failures ) ) {
			error( "Could not generate #ArrayLen( failures )# framework stub(s):#Chr( 10 )##ArrayToList( failures, Chr( 10 ) )#" );
		}

		return StructCount( done );
	}

	private string function _writeStub( required string className, required string stubsDir ) {
		var meta      = GetComponentMetadata( arguments.className );
		var parent    = meta.extends.name ?: "";
		var stubbable = ReFindNoCase( "^(preside|coldbox)\.", parent ) > 0;
		var extendsAt = stubbable ? ' extends="#parent#"' : "";
		var lines     = [ "component#extendsAt# {", "" ];
		var functions = meta.functions ?: [];

		ArraySort( functions, function( a, b ) {
			return Compare( a.name, b.name );
		} );

		for ( var fn in functions ) {
			var access = ( fn.access ?: "public" ) == "private" ? "private" : "public";
			var params = [];
			for ( var param in fn.parameters ) {
				ArrayAppend( params, "any #param.name#" );
			}
			var body = fn.name == "init" ? " return this; " : "";

			ArrayAppend( lines, Chr( 9 ) & "#access# any function #fn.name#( #ArrayToList( params, ', ' )# ) {#body#}" );
		}

		ArrayAppend( lines, "" );
		ArrayAppend( lines, "}" );

		var filePath = arguments.stubsDir & Replace( arguments.className, ".", "/", "all" ) & ".cfc";
		DirectoryCreate( GetDirectoryFromPath( filePath ), true, true );
		FileWrite( filePath, ArrayToList( lines, Chr( 10 ) ) & Chr( 10 ) );

		return stubbable ? parent : "";
	}

	private string function _normalise( required string path ) {
		var normalised = Replace( CreateObject( "java", "java.io.File" ).init( arguments.path ).getCanonicalPath(), "\", "/", "all" );

		return Right( normalised, 1 ) == "/" ? normalised : normalised & "/";
	}

}
