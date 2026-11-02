component extends="coldbox.system.Interceptor" {

	public void function configure() {}

	public void function postSaveSampleProduct( event, interceptData ) {
		request.sampleInterceptorCalled = true;
	}

}
