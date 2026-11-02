# Preside Extension Testing

Unit testing kit for Preside extensions. It gives you:

- **TestBox** as a dependency, so extensions no longer vendor their own copy
- **`PresideMockSpec`**, a base spec whose `prepareService()` stubs every `$` helper a Preside service inherits, with sensible defaults
- **Real Preside helpers** on `$helpers` (`isTrue`, `isFalse`, `isEmptyString`, `queryRowToStruct`, `fileSizeFormat`...)
- **Empty stubs of framework classes**: everything in Preside's `system/base` and `system/handlers`, their ColdBox parents, plus `Interceptor`, `EventHandler`, `FrameworkSupertype`, `AbstractAppender` and `AbstractHeartBeat`. Handlers, interceptors, renderers and preside objects compile without Preside or ColdBox installed
- **A shared test harness** (`TestApplication.cfc` and `runner.cfm`)

The package version matches the Preside version it was built from. Pin the exact version that matches your extension's `preside.minVersion`. Don't use a range such as `^10.30.0`: it installs the newest 10.x, so your tests would run against helper signatures from a newer Preside than the one you support.

## Installing

In your extension's `box.json`:

```json
"devDependencies":{
    "preside-test-helpers":"10.30.0"
},
"installPaths":{
    "preside-test-helpers":"tests/preside-test-helpers/"
}
```

Then run `box install`. Add `/tests/preside-test-helpers` to `.gitignore`.

## Test harness

`tests/Application.cfc`:

```cfc
component extends="preside-test-helpers.TestApplication" {
	this.name = "My Extension Test Suite";

	this.mappings[ "/myextension" ] = ExpandPath( "../" );
}
```

`tests/runTests.cfm`:

```cfm
<cfinclude template="/preside-test-helpers/runner.cfm">
```

`TestApplication` maps `/tests`, `/testbox`, `/preside-test-helpers`, and points `/preside` and `/coldbox` at the bundled base-class stubs. Copies of both files are in `templates/`.

The stubs are empty: they only let your CFCs compile. Specs that need the real Preside or ColdBox (integration tests against a running application) can't use this harness, because `/preside` and `/coldbox` no longer point at the framework.

## Running

Start a CommandBox server with `tests/` as the webroot, then:

| URL | Runs |
|---|---|
| `/runTests.cfm` | every spec under `tests.unit`, simple reporter |
| `/runTests.cfm?reporter=json` | the same, as JSON |
| `/runTests.cfm?bundles=tests.unit.MyServiceTest` | one spec |
| `/runTests.cfm?directory=tests.integration` | another directory |
| `/runTests.cfm?labels=slow` | specs with a label |

## Writing a spec

```cfc
component extends="preside-test-helpers.PresideMockSpec" {

	function run() {
		describe( "getDefaultTemplate()", function() {

			var service     = "";
			var mockShopObj = "";

			beforeEach( function() {
				service     = prepareService( new myextension.services.ShopService() );
				mockShopObj = getMockPresideObject( service, "my_shop" );
			} );

			it( "should return the shop's template", function() {
				mockShopObj.$( "selectData", QueryNew( "template", "varchar", [ [ "t1" ] ] ) );

				expect( service.getDefaultTemplate( "shop-1" ) ).toBe( "t1" );
			} );

			it( "should return nothing when shops are disabled", function() {
				setFeature( service, "myShops", false );

				expect( service.getDefaultTemplate( "shop-1" ) ).toBe( "" );
				expect( mockShopObj.$count( "selectData" ) ).toBe( 0 );
			} );

		} );
	}

}
```

### prepareService()

```cfc
service = prepareService(
	  service             = new myextension.services.MyService( dependency=mockDependency )
	, features            = { myFeature=false }
	, defaultFeatureState = true
	, settings            = { mycategory={ mysetting="value" } }
	, coldboxSettings     = { siteName="Test" }
	, objects             = { my_object=myObjectMock }
	, extensions          = { "preside-ext-payments"=true }
	, helpers             = myHelpersMock
);
```

`helpers` replaces the default `$helpers` mock. Leave it out unless you need a completely custom one; to stub a single helper, use `getMockHelpers( service ).$( ... )`.

Every argument except `service` is optional. If you pass any of the others, **name every argument**, including `service`. Lucee won't let you mix positional and named arguments: `prepareService( new X(), features={} )` fails with "Missing argument name".

It returns the service as a MockBox mock, so `service.$( "method", value )` and `service.$callLog()` work as usual.

`prepareService()` copies the `features`, `settings`, `extensions` and `coldboxSettings` structs, so `setFeature()` and `setPresideSetting()` never change a struct you share between specs.

### Defaults

| Helper | Default |
|---|---|
| `$getPresideObject( name )` | one cached stub per object name. Get it with `getMockPresideObject( service, name )` |
| `$getPresideObjectService()` | a stub that routes `selectData`, `insertData`, `updateData`, `deleteData`, `dataExists` and `getObject` to the same per-object stubs |
| `$isFeatureEnabled( feature )` | `features[ feature ]`, otherwise `defaultFeatureState` (true). Expressions such as `!myFeature` or `a && b` are evaluated the same way as Preside's feature service |
| `$getPresideSetting( category, setting, default )` | `settings[ category ][ setting ]`, otherwise `default` |
| `$getPresideCategorySettings( category )` | `settings[ category ]` |
| `$isExtensionInstalled( ext )` | `extensions[ ext ]`, otherwise false |
| `$translateResource( uri, defaultValue )` | `defaultValue` if not empty, otherwise `uri` |
| `$translateObjectName`, `$translatePropertyName` | the object or property name |
| `$getI18nLocale()` | `"en"` |
| `$announceInterception()` | runs any listeners registered with `onAnnounce()`, records the call and returns true |
| `$raiseError()`, `$audit()`, `$systemOutput()` | recorded, otherwise do nothing |
| `$isInterrupted()` | false |
| `$getColdbox()` | a mock controller: `getSetting()` reads `coldboxSettings`, and `getWireBox().getInstance()` returns one cached stub per name |
| `$getRequestContext()` | a mock request context backed by a real collection (`getValue`, `setValue`, `paramValue`, `getCollection`, `buildLink`...) |
| `$getValidationEngine()`, `$newValidationResult()` | mocks whose validation results keep track of their errors |
| `$isWebsiteUserLoggedIn()` and the other logged-in helpers | false, `""` or `{}` |
| `$slugify()` | Preside's real implementation |
| `$helpers` | Preside's real helpers from `system/helpers`, except `presideProxies`, `datamanagerAuditHelpers`, `datamanagerWorkflowHelpers` and `webflowHelpers`. Helpers that need ColdBox use the mock controller, whose `i18n` instance returns `en_GB` from `getFwLocale()` |

**Any other `$` helper** (`$sendEmail`, `$renderViewlet`, `$renderView`...) throws `PresideTestHelpers.helperNotStubbed` until you stub it. A test can't silently pass on a helper nobody thought about.

**Your own stubs always win.** `service.$( "$translateResource", "x" )` or `service.$( "$isFeatureEnabled" ).$args( "f" ).$results( false )` fully replaces the default.

### Accessors and setters

| Function | Use |
|---|---|
| `getMockPresideObject( service, objectName )` | the stub returned by `$getPresideObject( objectName )` |
| `getMockPresideObjectService( service )` | the object service stub |
| `getMockHelpers( service )` | the `$helpers` mock. Stub extension-specific helpers with `getMockHelpers( service ).$( "myHelper", value )` |
| `getMockColdbox( service )` | the controller mock |
| `getMockRequestContext( service )` | the request context mock |
| `getMockValidationEngine( service )` | the validation engine mock |
| `getMockSystemConfigurationService( service )` | the system configuration service mock |
| `setFeature( service, feature, enabled )` | turn a feature on or off |
| `setPresideSetting( service, category, setting, value )` | set a system setting |

### Assertions

```cfc
expectAnnounced( service, "postSaveOrder" );
expectAnnounced( service, "postSaveOrder", { id="order-1" } );
expectNotAnnounced( service, "preSaveOrder" );

var calls  = getAnnouncedInterceptions( service, "postSaveOrder" );
var errors = getRaisedErrors( service );
```

`expectAnnounced` with data passes when the announced `interceptData` contains every key you give, with equal values. Extra keys are ignored. Simple values are compared as case-sensitive strings, so `"ABC"` doesn't match `"abc"` and `true` doesn't match `"yes"` or `1`.

The recorded `interceptData` is the struct the service passed, not a copy, so assertions see any changes that listeners or the service made to it after the announcement.

### Faking listeners

Some services announce an interception point and then read back what a listener put in `interceptData`. Another extension usually supplies that listener. For example:

```cfc
public boolean function isTemplateUsed( required string templateId ) {
	var interceptArgs = { templateId=arguments.templateId, isUsed=false };

	$announceInterception( "onIsPaymentScheduleTemplateUsed", interceptArgs );

	return $helpers.isTrue( interceptArgs.isUsed ?: "" );
}
```

Register a listener for that point with `onAnnounce( service, interceptionPoint, listener )`:

```cfc
onAnnounce( service, "onIsPaymentScheduleTemplateUsed", function( interceptData ) {
	interceptData.isUsed = interceptData.templateId == "template-2";
} );
```

- The listener receives the same `interceptData` struct the service passed, so any changes it makes are visible to the service.
- Listeners only run for the point they are registered for. A service that announces the wrong point name fails the test, which a catch-all `$callback` on `$announceInterception` would miss.
- You can register several listeners for one point. They run in the order they were registered.
- The call is still recorded, so `expectAnnounced()` works alongside `onAnnounce()`.
- Stubbing `$announceInterception` yourself replaces the default, and registered listeners no longer run.

### Building your own mocks

For dependencies that aren't the service under test:

| Function | Returns |
|---|---|
| `newMockRequestContext( collection, privateCollection )` | a request context mock |
| `newMockColdbox( requestContext, settings )` | a controller mock |
| `newMockPresideObjectService( objects )` | an object service mock |
| `newMockSystemConfigurationService( settings )` | a system configuration service mock |
| `newMockValidationEngine()` | a validation engine mock |
| `newMockValidationResult( errors, generalMessage )` | a validation result mock |
| `newMockPresideHelpers( coldbox )` | a `$helpers` mock with the real Preside helpers. Pass a controller from `newMockColdbox()` if the helpers you call need one |
| `queryFromRows( rows, columns, columnTypes )` | a query from an array of structs |

```cfc
var qry = queryFromRows(
	  rows        = [ { id="1", amount=10 }, { id="2", amount=20 } ]
	, columns     = "id,amount"
	, columnTypes = { amount="integer" }
);
```

**Naming:** don't name spec variables after base spec functions (`getMockHelpers`, `newMockColdbox`, `prepareService`...). A variable with the same name replaces the function.

## Handlers, interceptors and preside object CFCs

These call framework methods without the `$` prefix (`getPresideObject`, `translateResource`, `renderViewlet`...). `prepareService()` doesn't cover them yet. Extend `PresideMockSpec` anyway, so you get TestBox and the base-class stubs, and build them with `prepareMock()` and your own stubs as before.

## Migrating an existing spec

1. Set up the harness above. Remove the extension's own `testbox` dev dependency and install path from `box.json`, delete its vendored `tests/testbox` folder, and drop any `/testbox`, `/preside` or `/coldbox` mappings from `tests/Application.cfc`. `TestApplication` provides them.
2. Change `extends="testbox.system.BaseSpec"` to `extends="preside-test-helpers.PresideMockSpec"`.
3. Replace `createMock( object=new X() )` or `prepareMock( new X() )` with `prepareService( new X() )`.
4. Delete the stubs the defaults now cover:
   - `$isFeatureEnabled` returning true. Use `setFeature()` for the disabled cases.
   - `$getPresideObject` with `$args( "x" ).$results( mockX )` and its `createStub()`. Use `mockX = getMockPresideObject( service, "x" )`.
   - Hand-written `isTrue`, `isFalse` and `isEmptyString` stubs on `$helpers`.
   - No-op stubs of `$announceInterception`, `$raiseError`, `$audit` and `$isInterrupted`.
   - `$callback` stubs on `$announceInterception` that set values on `interceptData`. Use `onAnnounce()`.
   - Positional checks such as `service.$callLog().$announceInterception[ 1 ][ 1 ]`. Use `expectAnnounced()`.
5. Don't change any assertions. If a test relies on different behaviour from a default, keep its explicit stub.
6. Run the spec. It should have the same spec count as before, and every spec should pass.

## Building the package

The build reads Preside's source, so it needs a Preside checkout or installed package of the version you are building:

```
box install presidecms@10.31.0 --noSave
box task run taskFile=Build.cfc :version=10.31.0 :presideRoot=./preside
```

Both values are required. Pass `:version` and `:presideRoot`, or set the `RELEASE_VERSION` and `PRESIDE_ROOT` environment variables as CI does. The build writes `dist/preside-test-helpers/` and `dist/preside-test-helpers-<version>.zip`. It reads the `$` helper signatures from `PresideSuperClass`, copies the helper files from `system/helpers/`, and generates the framework stubs. If any stub can't be generated, the build fails. To check the build, run the self-tests in `selftest/`:

```
cd selftest
box install --force --noSave
box server start serverConfigFile=server.json --noSaveSettings
box testbox run
```

`box install` installs the package from `../dist/preside-test-helpers`, so rebuild and rerun it after changing `src/`. Keep `--noSave`: without it CommandBox rewrites the relative `folder:` path in `selftest/box.json` as an absolute path to your machine.

### CI and releasing

`.github/workflows/ci.yml` follows the same twgit flow as Preside and the Pixl8 extensions. Every push and pull request builds the package and runs the self-tests on Lucee 5.4 (Lucee 7.0 is experimental, as in Preside). Release branches and version tags are also published:

| Ref | Built from | Published as |
|---|---|---|
| `release-10.32.0` branch | `presidecms@10.32.0-snapshot` | `10.32.0-snapshot` (pre-release, replaced on every push) |
| `v10.32.0` tag | `presidecms@10.32.0` | `10.32.0+<build>` |
| anything else | `presidecms@DEFAULT_PRESIDE_VERSION` (set in the workflow) | not published |

So the version number always matches the Preside release it was built from, and snapshots follow Preside's own `x.y.z-snapshot` scheme. To test an extension against an unreleased Preside, pin `"preside-test-helpers":"10.32.0-snapshot"`.

The publish job doesn't rebuild. It publishes the package that the Lucee 5.4 self-test job built and tested. To release for a new Preside version, run `twgit release start 10.32.0` while Preside 10.32.0 is in snapshot, and `twgit release finish` once Preside 10.32.0 is on ForgeBox. Bump `DEFAULT_PRESIDE_VERSION` at the same time.

Publishing creates a GitHub release with the zip (tagged `v10.32.0-snapshot` for snapshots, or the pushed `v10.32.0` tag), sets it as the `location` in `box.json`, and publishes to ForgeBox with `pixl8/github-action-box-publish`. It uses the `FORGEBOX_USER` and `FORGEBOX_PASS` secrets, like the extensions.

To try an unpublished build in an extension:

```
cd tests && box install id=file:/path/to/dist/preside-test-helpers-10.31.0.zip save=false
```
