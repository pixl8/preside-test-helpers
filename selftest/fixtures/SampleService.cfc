component {

	public any function init( string defaultCurrency="GBP" ) {
		variables.defaultCurrency = arguments.defaultCurrency;

		return this;
	}

	public numeric function countActiveProducts() {
		return $getPresideObject( "sample_product" ).selectData( filter={ active=true }, recordCountOnly=true );
	}

	public string function saveProduct( required struct data ) {
		var newId = $getPresideObject( "sample_product" ).insertData( data=arguments.data );

		$announceInterception( "postSaveSampleProduct", { id=newId, data=arguments.data } );

		return newId;
	}

	public boolean function isProductInUse( required string productId ) {
		var interceptData = { productId=arguments.productId, isUsed=false };

		$announceInterception( "onIsSampleProductUsed", interceptData );

		return interceptData.isUsed;
	}

	public boolean function isProductInUseNamed( required string productId ) {
		var interceptData = { productId=arguments.productId, isUsed=false };

		$announceInterception( state="onIsSampleProductUsed", interceptData=interceptData );

		return interceptData.isUsed;
	}

	public string function getLabel() {
		return $translateResource( uri="sample:label", defaultValue="" );
	}

	public string function getTitle() {
		return $translateResource( uri="sample:title", defaultValue="Sample title" );
	}

	public boolean function isShopEnabled() {
		return $isFeatureEnabled( "sampleShop" );
	}

	public boolean function isFeatureExpressionEnabled( required string expression ) {
		return $isFeatureEnabled( arguments.expression );
	}

	public string function slugify( required string str, numeric maxLength=0 ) {
		return $slugify( str=arguments.str, maxLength=arguments.maxLength );
	}

	public string function formatFileSize( required numeric bytes ) {
		return $helpers.fileSizeFormat( arguments.bytes );
	}

	public string function getCurrency() {
		return $getPresideSetting( "sample", "currency", variables.defaultCurrency );
	}

	public struct function getSampleSettings() {
		return $getPresideCategorySettings( "sample" );
	}

	public boolean function isPaymentsInstalled() {
		return $isExtensionInstalled( "preside-ext-payments" );
	}

	public string function getProductLink( required string productId ) {
		return $getRequestContext().buildLink( page="product", id=arguments.productId );
	}

	public boolean function isTruthy( any value ) {
		return $helpers.isTrue( arguments.value ?: "" );
	}

	public string function getRcValue( required string name ) {
		return $getRequestContext().getValue( name=arguments.name, defaultValue="none" );
	}

	public string function getColdboxSetting( required string name ) {
		return $getColdbox().getSetting( name=arguments.name, defaultValue="" );
	}

	public void function logFailure( required string message ) {
		$raiseError( { message=arguments.message } );
	}

	public any function sendWelcome() {
		return $sendEmail( template="welcome" );
	}

	public string function getOrderLabel( required string orderId ) {
		return $getPresideObjectService().selectData( objectName="sample_order", id=arguments.orderId ).label;
	}

	public boolean function validateName( required string name ) {
		var result = $newValidationResult();

		if ( !Len( Trim( arguments.name ) ) ) {
			result.addError( fieldName="name", message="required" );
		}

		return result.validated();
	}

}
