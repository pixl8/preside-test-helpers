component extends="preside-test-helpers.PresideMockSpec" {

	function run() {
		describe( "prepareService()", function() {

			it( "should give each preside object its own cached mock", function() {
				var service = prepareService( new fixtures.SampleService() );

				getMockPresideObject( service, "sample_product" ).$( "selectData", 3 );

				expect( service.countActiveProducts() ).toBe( 3 );
				expect( getMockPresideObject( service, "sample_product" ).$callLog().selectData[ 1 ].recordCountOnly ).toBeTrue();
				expect( getMockPresideObject( service, "other_object" ) ).notToBe( getMockPresideObject( service, "sample_product" ) );
			} );

			it( "should use preside object mocks passed in", function() {
				var productObj = createStub();
				productObj.$( "selectData", 7 );

				var service = prepareService( service=new fixtures.SampleService(), objects={ sample_product=productObj } );

				expect( service.countActiveProducts() ).toBe( 7 );
			} );

			it( "should route preside object service calls to the same object mocks", function() {
				var service = prepareService( new fixtures.SampleService() );

				getMockPresideObject( service, "sample_order" ).$( "selectData", QueryNew( "label", "varchar", [ [ "Order 1" ] ] ) );

				expect( service.getOrderLabel( "order-1" ) ).toBe( "Order 1" );
			} );

			it( "should return the default value or the uri from $translateResource", function() {
				var service = prepareService( new fixtures.SampleService() );

				expect( service.getLabel() ).toBe( "sample:label" );
				expect( service.getTitle() ).toBe( "Sample title" );
			} );

			it( "should enable features by default and let tests turn them off", function() {
				var service = prepareService( new fixtures.SampleService() );
				expect( service.isShopEnabled() ).toBeTrue();

				setFeature( service, "sampleShop", false );
				expect( service.isShopEnabled() ).toBeFalse();

				var disabledByDefault = prepareService( service=new fixtures.SampleService(), defaultFeatureState=false );
				expect( disabledByDefault.isShopEnabled() ).toBeFalse();
			} );

			it( "should evaluate feature expressions the same way as the feature service", function() {
				var service = prepareService( service=new fixtures.SampleService(), features={ shopA=true, shopB=false } );

				expect( service.isFeatureExpressionEnabled( "!shopB" ) ).toBeTrue();
				expect( service.isFeatureExpressionEnabled( "!shopA" ) ).toBeFalse();
				expect( service.isFeatureExpressionEnabled( "shopA && shopB" ) ).toBeFalse();
				expect( service.isFeatureExpressionEnabled( "shopA || shopB" ) ).toBeTrue();
				expect( service.isFeatureExpressionEnabled( "shopA && !shopB" ) ).toBeTrue();
			} );

			it( "should slugify the same way as preside", function() {
				var service = prepareService( new fixtures.SampleService() );

				expect( service.slugify( "My Site: About Us" ) ).toBe( "my-site-about-us" );
				expect( service.slugify( "Café_Bar" ) ).toBe( "cafebar" );
				expect( service.slugify( str="Hello World Again", maxLength=11 ) ).toBe( "hello-world" );
			} );

			it( "should let $helpers functions that need the coldbox controller run", function() {
				var service = prepareService( new fixtures.SampleService() );

				expect( service.formatFileSize( 2048 ) ).toBe( "2.0 KB" );
			} );

			it( "should read preside settings from the settings struct and fall back to the default", function() {
				var service = prepareService( new fixtures.SampleService( defaultCurrency="USD" ) );
				expect( service.getCurrency() ).toBe( "USD" );

				setPresideSetting( service, "sample", "currency", "EUR" );
				expect( service.getCurrency() ).toBe( "EUR" );

				var configured = prepareService( service=new fixtures.SampleService(), settings={ sample={ currency="JPY" } } );
				expect( configured.getCurrency() ).toBe( "JPY" );
			} );

			it( "should return a copy of a settings category", function() {
				var service = prepareService( service=new fixtures.SampleService(), settings={ sample={ currency="JPY" } } );

				setPresideSetting( service, "sample", "region", "APAC" );

				var settings = service.getSampleSettings();
				expect( settings ).toBe( { currency="JPY", region="APAC" } );

				settings.currency = "changed";
				expect( service.getCurrency() ).toBe( "JPY" );
			} );

			it( "should not change the structs passed in when features or settings are changed", function() {
				var features = { sampleShop=true };
				var settings = { sample={ currency="JPY" } };
				var service  = prepareService( service=new fixtures.SampleService(), features=features, settings=settings );

				setFeature( service, "sampleShop", false );
				setPresideSetting( service, "sample", "currency", "EUR" );
				getMockSystemConfigurationService( service ).saveSetting( "sample", "region", "APAC" );

				expect( features.sampleShop ).toBeTrue();
				expect( settings.sample ).toBe( { currency="JPY" } );

				var next = prepareService( service=new fixtures.SampleService(), features=features, settings=settings );
				expect( next.isShopEnabled() ).toBeTrue();
				expect( next.getCurrency() ).toBe( "JPY" );
			} );

			it( "should report extensions as installed only when listed", function() {
				var service = prepareService( new fixtures.SampleService() );
				expect( service.isPaymentsInstalled() ).toBeFalse();

				var withPayments = prepareService( service=new fixtures.SampleService(), extensions={ "preside-ext-payments"=true } );
				expect( withPayments.isPaymentsInstalled() ).toBeTrue();
			} );

			it( "should build predictable links from the request context", function() {
				var service = prepareService( new fixtures.SampleService() );

				expect( service.getProductLink( "p1" ) ).toBe( "/link/?id=p1&page=product" );
			} );

			it( "should provide the real preside boolean helpers on $helpers", function() {
				var service = prepareService( new fixtures.SampleService() );

				expect( service.isTruthy( "true" ) ).toBeTrue();
				expect( service.isTruthy( "yes" ) ).toBeTrue();
				expect( service.isTruthy( "" ) ).toBeFalse();
				expect( service.isTruthy( "rubbish" ) ).toBeFalse();
			} );

			it( "should let tests stub extension specific helpers on $helpers", function() {
				var service = prepareService( new fixtures.SampleService() );

				getMockHelpers( service ).$( "isTrue", true );

				expect( service.isTruthy( "rubbish" ) ).toBeTrue();
			} );

			it( "should not expose the helper mock's own internals as helpers", function() {
				var helpers = getMockHelpers( prepareService( new fixtures.SampleService() ) );

				expect( function() {
					helpers.getController();
				} ).toThrow( type="PresideTestHelpers.helperNotStubbed" );
				expect( function() {
					helpers.getSingleton( "i18n" );
				} ).toThrow( type="PresideTestHelpers.helperNotStubbed" );
			} );

			it( "should provide a request context mock backed by a collection", function() {
				var service = prepareService( new fixtures.SampleService() );

				expect( service.getRcValue( "foo" ) ).toBe( "none" );

				getMockRequestContext( service ).setValue( "foo", "bar" );
				expect( service.getRcValue( "foo" ) ).toBe( "bar" );
			} );

			it( "should provide a coldbox controller mock with config settings", function() {
				var service = prepareService( service=new fixtures.SampleService(), coldboxSettings={ siteName="Test site" } );

				expect( service.getColdboxSetting( "siteName" ) ).toBe( "Test site" );
				expect( service.getColdboxSetting( "missing" ) ).toBe( "" );
			} );

			it( "should provide validation results that track errors", function() {
				var service = prepareService( new fixtures.SampleService() );

				expect( service.validateName( "Jo" ) ).toBeTrue();
				expect( service.validateName( "" ) ).toBeFalse();
			} );

			it( "should throw a clear error when a helper with no default is called", function() {
				var service = prepareService( new fixtures.SampleService() );

				expect( function() {
					service.sendWelcome();
				} ).toThrow( type="PresideTestHelpers.helperNotStubbed", regex="\$sendEmail" );
			} );

			it( "should let a spec replace any default with its own stub", function() {
				var service = prepareService( new fixtures.SampleService() );

				service.$( "$sendEmail", "email-1" );
				service.$( "$translateResource", "overridden" );
				service.$( "$isFeatureEnabled" ).$args( "sampleShop" ).$results( false );

				expect( service.sendWelcome() ).toBe( "email-1" );
				expect( service.getTitle() ).toBe( "overridden" );
				expect( service.isShopEnabled() ).toBeFalse();
			} );

			it( "should stub every public $ helper from PresideSuperClass", function() {
				var service = prepareService( new fixtures.SampleService() );
				var helpers = getPresideHelperSignatures();

				expect( ArrayLen( helpers ) ).toBeGT( 50 );
				for ( var helper in helpers ) {
					expect( StructKeyExists( service, helper.name ) ).toBeTrue( "#helper.name# is not stubbed" );
				}
			} );
		} );

		describe( "interception assertions", function() {

			it( "should record announced interceptions with their data", function() {
				var service = prepareService( new fixtures.SampleService() );
				getMockPresideObject( service, "sample_product" ).$( "insertData", "new-id" );

				service.saveProduct( { label="Widget" } );

				expectAnnounced( service, "postSaveSampleProduct" );
				expectAnnounced( service, "postSaveSampleProduct", { id="new-id", data={ label="Widget" } } );
				expectNotAnnounced( service, "preSaveSampleProduct" );
				expect( getAnnouncedInterceptions( service ) ).toHaveLength( 1 );
			} );

			it( "should fail when the data does not match", function() {
				var service = prepareService( new fixtures.SampleService() );
				getMockPresideObject( service, "sample_product" ).$( "insertData", "new-id" );

				service.saveProduct( { label="Widget" } );

				expect( function() {
					expectAnnounced( service, "postSaveSampleProduct", { id="another-id" } );
				} ).toThrow();
			} );

			it( "should compare intercept data strictly", function() {
				var service = prepareService( new fixtures.SampleService() );
				getMockPresideObject( service, "sample_product" ).$( "insertData", "new-id" );

				service.saveProduct( { label="Widget", active=true } );

				expectAnnounced( service, "postSaveSampleProduct", { data={ label="Widget", active=true } } );
				expect( function() {
					expectAnnounced( service, "postSaveSampleProduct", { data={ label="widget" } } );
				} ).toThrow();
				expect( function() {
					expectAnnounced( service, "postSaveSampleProduct", { data={ active="yes" } } );
				} ).toThrow();
			} );

			it( "should fail expectNotAnnounced when the point was announced", function() {
				var service = prepareService( new fixtures.SampleService() );
				getMockPresideObject( service, "sample_product" ).$( "insertData", "new-id" );

				service.saveProduct( { label="Widget" } );

				expect( function() {
					expectNotAnnounced( service, "postSaveSampleProduct" );
				} ).toThrow();
			} );

			it( "should leave intercept data untouched when no listener is registered", function() {
				var service = prepareService( new fixtures.SampleService() );

				expect( service.isProductInUse( "p1" ) ).toBeFalse();
				expectAnnounced( service, "onIsSampleProductUsed", { productId="p1" } );
			} );

			it( "should run registered listeners so they can change the intercept data", function() {
				var service = prepareService( new fixtures.SampleService() );

				onAnnounce( service, "onIsSampleProductUsed", function( interceptData ) {
					interceptData.isUsed = interceptData.productId == "p2";
				} );

				expect( service.isProductInUse( "p1" ) ).toBeFalse();
				expect( service.isProductInUse( "p2" ) ).toBeTrue();
				expect( service.isProductInUseNamed( "p2" ) ).toBeTrue();
				expect( getAnnouncedInterceptions( service, "onIsSampleProductUsed" ) ).toHaveLength( 3 );
			} );

			it( "should run every listener for a point in order and ignore other points", function() {
				var service = prepareService( new fixtures.SampleService() );
				var calls   = [];

				onAnnounce( service, "onIsSampleProductUsed", function( interceptData ) {
					ArrayAppend( calls, "first" );
				} );
				onAnnounce( service, "onIsSampleProductUsed", function( interceptData ) {
					ArrayAppend( calls, "second" );
					interceptData.isUsed = true;
				} );
				onAnnounce( service, "postSaveSampleProduct", function( interceptData ) {
					ArrayAppend( calls, "other" );
				} );

				expect( service.isProductInUse( "p1" ) ).toBeTrue();
				expect( calls ).toBe( [ "first", "second" ] );
			} );

			it( "should record raised errors", function() {
				var service = prepareService( new fixtures.SampleService() );

				service.logFailure( "boom" );

				expect( getRaisedErrors( service ) ).toHaveLength( 1 );
				expect( getRaisedErrors( service )[ 1 ].message ).toBe( "boom" );
			} );
		} );

		describe( "queryFromRows()", function() {

			it( "should build a query from an array of structs", function() {
				var qry = queryFromRows( rows=[ { id="1", amount=10 }, { id="2", amount=20 } ], columns="id,amount", columnTypes={ amount="integer" } );

				expect( qry.recordCount ).toBe( 2 );
				expect( qry.amount[ 2 ] ).toBe( 20 );
				expect( qry.columnList ).toInclude( "ID" );
			} );

			it( "should return an empty query with the given columns", function() {
				var qry = queryFromRows( rows=[], columns="id,label" );

				expect( qry.recordCount ).toBe( 0 );
				expect( ListLen( qry.columnList ) ).toBe( 2 );
			} );
		} );

		describe( "framework base class stubs", function() {

			it( "should let a handler extending EnhancedDataManagerBase compile and run", function() {
				var handler = new fixtures.SampleAdminHandler();

				expect( handler.getObjectName() ).toBe( "sample_product" );
				expect( IsInstanceOf( handler, "preside.system.base.AdminHandler" ) ).toBeTrue();
			} );

			it( "should let an interceptor extending coldbox Interceptor compile and run", function() {
				var interceptor = new fixtures.SampleInterceptor();

				interceptor.postSaveSampleProduct( event=newMockRequestContext(), interceptData={} );

				expect( request.sampleInterceptorCalled ?: false ).toBeTrue();
				expect( IsInstanceOf( interceptor, "coldbox.system.FrameworkSupertype" ) ).toBeTrue();
			} );

			it( "should let classes extending preside handlers and services compile", function() {
				expect( IsInstanceOf( new fixtures.SampleBooleanRenderer(), "preside.system.handlers.renderers.content.Boolean" ) ).toBeTrue();
				expect( IsInstanceOf( new fixtures.SampleHeartBeat(), "preside.system.services.concurrency.AbstractHeartBeat" ) ).toBeTrue();
				expect( IsInstanceOf( new fixtures.SamplePresideObject(), "preside.system.base.SystemPresideObject" ) ).toBeTrue();
			} );
		} );
	}

}
