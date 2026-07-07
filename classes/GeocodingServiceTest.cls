@IsTest
private class GeocodingServiceTest {
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            Assert.areEqual('PropertyMgmt/1.0', request.getHeader('User-Agent'), 'User-Agent header sent');
            Assert.isTrue(request.getEndpoint().startsWith('https://nominatim.openstreetmap.org/search'), 'Correct endpoint');
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('[{"lat":"12.9716","lon":"77.5946"}]');
            return response;
        }
    }

    private class EmptyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('[]');
            return response;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(500);
            response.setBody('error');
            return response;
        }
    }

    @IsTest
    static void testGeocodeSuccess() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        List<Property__c> props = TestDataFactory.createProperties(2, null, true);
        Test.stopTest();

        List<Property__c> updated = [
            SELECT Location__Latitude__s, Location__Longitude__s
            FROM Property__c
            WHERE Id IN :props
        ];
        for (Property__c prop : updated) {
            Assert.areEqual(12.9716, prop.Location__Latitude__s, 'Latitude set');
            Assert.areEqual(77.5946, prop.Location__Longitude__s, 'Longitude set');
        }
    }

    @IsTest
    static void testGeocodeNoResults() {
        Test.setMock(HttpCalloutMock.class, new EmptyMock());
        Test.startTest();
        List<Property__c> props = TestDataFactory.createProperties(1, null, true);
        Test.stopTest();

        Property__c prop = [
            SELECT Location__Latitude__s, Location__Longitude__s
            FROM Property__c
            WHERE Id = :props[0].Id
        ];
        Assert.isNull(prop.Location__Latitude__s, 'Latitude not set when no results');
        Assert.isNull(prop.Location__Longitude__s, 'Longitude not set when no results');
    }

    @IsTest
    static void testGeocodeErrorResponse() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        Test.startTest();
        List<Property__c> props = TestDataFactory.createProperties(1, null, true);
        Test.stopTest();

        Property__c prop = [
            SELECT Location__Latitude__s FROM Property__c WHERE Id = :props[0].Id
        ];
        Assert.isNull(prop.Location__Latitude__s, 'Latitude not set on error response');
    }

    @IsTest
    static void testDirectEnqueue() {
        List<Property__c> props = TestDataFactory.createProperties(1, null, false);
        PropertyTriggerHandler.bypassGeocoding = true;
        insert props;
        PropertyTriggerHandler.bypassGeocoding = false;

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        System.enqueueJob(new GeocodingService(new Set<Id>{ props[0].Id }));
        Test.stopTest();

        Property__c prop = [
            SELECT Location__Latitude__s FROM Property__c WHERE Id = :props[0].Id
        ];
        Assert.areEqual(12.9716, prop.Location__Latitude__s, 'Latitude set via direct enqueue');
    }
}