@IsTest
private class PropertyControllerTest {
    private class GeoMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('[{"lat":"12.9716","lon":"77.5946"}]');
            return response;
        }
    }

    @TestSetup
    static void setup() {
        Test.setMock(HttpCalloutMock.class, new GeoMock());
        Test.startTest();
        TestDataFactory.createProperties(60, null, true);
        Test.stopTest();
    }

    @IsTest
    static void testKeysetPaginationMultiplePages() {
        Test.startTest();
        PropertyController.PropertyPage page1 = PropertyController.getProperties(null, null, null, null, 0, 25);
        PropertyController.PropertyPage page2 = PropertyController.getProperties(null, null, null, page1.lastRecordId, 0, 25);
        PropertyController.PropertyPage page3 = PropertyController.getProperties(null, null, null, page2.lastRecordId, 0, 25);
        Test.stopTest();

        Assert.areEqual(60, page1.totalCount, 'Total count should reflect all records');
        Assert.areEqual(25, page1.records.size(), 'First page should be full');
        Assert.areEqual(25, page2.records.size(), 'Second page should be full');
        Assert.areEqual(10, page3.records.size(), 'Third page should hold remainder');
        Assert.isTrue(page1.lastRecordId < page2.lastRecordId, 'Keyset should advance');
        Assert.isTrue(page2.records[0].Id > page1.lastRecordId, 'Page 2 starts after page 1');
    }

    @IsTest
    static void testSortAscending() {
        Test.startTest();
        PropertyController.PropertyPage page = PropertyController.getProperties(
            null, 'Rent__c', 'asc', null, 0, 100
        );
        Test.stopTest();

        Assert.areEqual(60, page.totalCount, 'Total count reflects all records');
        Decimal previous = null;
        for (Property__c prop : page.records) {
            if (previous != null) {
                Assert.isTrue(prop.Rent__c >= previous, 'Rent ascending');
            }
            previous = prop.Rent__c;
        }
    }

    @IsTest
    static void testSortDescending() {
        Test.startTest();
        PropertyController.PropertyPage page = PropertyController.getProperties(
            null, 'Rent__c', 'desc', null, 0, 100
        );
        Test.stopTest();

        Decimal previous = null;
        for (Property__c prop : page.records) {
            if (previous != null) {
                Assert.isTrue(prop.Rent__c <= previous, 'Rent descending');
            }
            previous = prop.Rent__c;
        }
    }

    @IsTest
    static void testSortOffsetPaging() {
        Test.startTest();
        PropertyController.PropertyPage page1 = PropertyController.getProperties(
            null, 'Rent__c', 'asc', null, 0, 25
        );
        PropertyController.PropertyPage page2 = PropertyController.getProperties(
            null, 'Rent__c', 'asc', null, 1, 25
        );
        Test.stopTest();

        Assert.areEqual(25, page1.records.size(), 'First offset page is full');
        Assert.areEqual(25, page2.records.size(), 'Second offset page is full');
        Assert.areNotEqual(page1.records[0].Id, page2.records[0].Id, 'Offset pages differ');
        Assert.isTrue(
            page2.records[0].Rent__c >= page1.records[page1.records.size() - 1].Rent__c,
            'Second page continues the ascending order'
        );
    }

    @IsTest
    static void testSortInvalidFieldFallsBackToKeyset() {
        Test.startTest();
        PropertyController.PropertyPage page = PropertyController.getProperties(
            null, 'Description__c; DROP', 'asc', null, 0, 25
        );
        Test.stopTest();

        Assert.areEqual(25, page.records.size(), 'Invalid sort field falls back to keyset paging');
        Assert.isNotNull(page.lastRecordId, 'Keyset cursor returned');
    }

    @IsTest
    static void testEmptyResult() {
        PropertyController.PropertyPage page = PropertyController.getProperties(
            '{"minPrice":99999999}', null, null, null, 0, 25
        );
        Assert.areEqual(0, page.totalCount, 'No records match');
        Assert.areEqual(0, page.records.size(), 'No records returned');
    }

    @IsTest
    static void testPriceFilters() {
        PropertyController.PropertyPage page = PropertyController.getProperties(
            '{"minPrice":60000,"maxPrice":100000}', null, null, null, 0, 100
        );
        for (Property__c prop : page.records) {
            Assert.isTrue(prop.Rent__c >= 60000 && prop.Rent__c <= 100000, 'Rent within range');
        }
        Assert.isTrue(page.totalCount > 0, 'Some records match price filter');
    }

    @IsTest
    static void testStatusFilter() {
        PropertyController.PropertyPage page = PropertyController.getProperties(
            '{"status":"Occupied"}', null, null, null, 0, 100
        );
        for (Property__c prop : page.records) {
            Assert.areEqual('Occupied', prop.Status__c, 'Only Occupied returned');
        }
    }

    @IsTest
    static void testFurnishingFilter() {
        PropertyController.PropertyPage page = PropertyController.getProperties(
            '{"furnishingStatus":"Furnished"}', null, null, null, 0, 100
        );
        for (Property__c prop : page.records) {
            Assert.areEqual('Furnished', prop.Furnishing_Status__c, 'Only Furnished returned');
        }
    }

    @IsTest
    static void testSortWithFilter() {
        Test.startTest();
        PropertyController.PropertyPage page = PropertyController.getProperties(
            '{"status":"Available"}', 'Rent__c', 'desc', null, 0, 100
        );
        Test.stopTest();

        Decimal previous = null;
        for (Property__c prop : page.records) {
            Assert.areEqual('Available', prop.Status__c, 'Filter respected while sorting');
            if (previous != null) {
                Assert.isTrue(prop.Rent__c <= previous, 'Rent descending with filter');
            }
            previous = prop.Rent__c;
        }
    }

    @IsTest
    static void testNearbyFilter() {
        List<Property__c> near = TestDataFactory.createProperties(1, new Map<String, Object>{
            'Location__Latitude__s' => 12.9716,
            'Location__Longitude__s' => 77.5946
        }, false);
        List<Property__c> far = TestDataFactory.createProperties(1, new Map<String, Object>{
            'Name' => 'Far Property',
            'Location__Latitude__s' => 19.0760,
            'Location__Longitude__s' => 72.8777
        }, false);
        PropertyTriggerHandler.bypassGeocoding = true;
        insert new List<Property__c>{ near[0], far[0] };
        PropertyTriggerHandler.bypassGeocoding = false;

        Test.startTest();
        PropertyController.PropertyPage page = PropertyController.getProperties(
            '{"latitude":12.9716,"longitude":77.5946,"radiusKm":50}', null, null, null, 0, 100
        );
        Test.stopTest();

        Boolean foundNear = false;
        for (Property__c prop : page.records) {
            if (prop.Id == near[0].Id) {
                foundNear = true;
            }
            Assert.areNotEqual(far[0].Id, prop.Id, 'Far property must be excluded');
        }
        Assert.isTrue(foundNear, 'Nearby property should be included');
    }

    @IsTest
    static void testCreateProperty() {
        Property__c prop = new Property__c(
            Name = 'New Property',
            Street__c = '10 Church Street',
            City__c = 'Bengaluru',
            State__c = 'Karnataka',
            Postal_Code__c = '560001',
            Country__c = 'India',
            Type__c = 'Residential',
            Furnishing_Status__c = 'Furnished',
            Status__c = 'Available',
            Rent__c = 45000,
            Description__c = 'A brand new listing'
        );

        Test.setMock(HttpCalloutMock.class, new GeoMock());
        Test.startTest();
        Id newId = PropertyController.createProperty(JSON.serialize(prop), null);
        Test.stopTest();

        Assert.isNotNull(newId, 'New Id returned');
        Property__c inserted = [SELECT Id, Name FROM Property__c WHERE Id = :newId];
        Assert.areEqual('New Property', inserted.Name, 'Property inserted');
    }

    @IsTest
    static void testCreatePropertyWithFiles() {
        Property__c prop = new Property__c(
            Name = 'Filed Property',
            Street__c = '1 MG Road',
            City__c = 'Bengaluru',
            State__c = 'Karnataka',
            Postal_Code__c = '560001',
            Country__c = 'India',
            Type__c = 'Commercial',
            Furnishing_Status__c = 'Unfurnished',
            Status__c = 'Available',
            Rent__c = 90000,
            Description__c = 'Has a picture'
        );

        PropertyController.FileWrapper file1 = new PropertyController.FileWrapper();
        file1.fileName = 'image1.png';
        file1.base64Data = EncodingUtil.base64Encode(Blob.valueOf('fake-image-one'));
        PropertyController.FileWrapper file2 = new PropertyController.FileWrapper();
        file2.fileName = 'image2.png';
        file2.base64Data = EncodingUtil.base64Encode(Blob.valueOf('fake-image-two'));

        Test.setMock(HttpCalloutMock.class, new GeoMock());
        Test.startTest();
        Id newId = PropertyController.createProperty(
            JSON.serialize(prop), new List<PropertyController.FileWrapper>{ file1, file2 }
        );
        Test.stopTest();

        Assert.isNotNull(newId, 'New Id returned');

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :newId
        ];
        Assert.areEqual(2, links.size(), 'Both files linked to property');

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            docIds.add(link.ContentDocumentId);
        }
        List<ContentVersion> versions = [
            SELECT Id, Title, PathOnClient FROM ContentVersion WHERE ContentDocumentId IN :docIds
        ];
        Assert.areEqual(2, versions.size(), 'ContentVersions created for each file');
    }

    @IsTest
    static void testCreatePropertyWithEmptyFile() {
        Property__c prop = new Property__c(
            Name = 'Skip Empty File',
            Street__c = '2 MG Road',
            City__c = 'Bengaluru',
            State__c = 'Karnataka',
            Postal_Code__c = '560001',
            Country__c = 'India',
            Type__c = 'Commercial',
            Furnishing_Status__c = 'Unfurnished',
            Status__c = 'Available',
            Rent__c = 70000,
            Description__c = 'No valid file'
        );

        PropertyController.FileWrapper empty = new PropertyController.FileWrapper();
        empty.fileName = 'empty.png';
        empty.base64Data = null;

        Test.setMock(HttpCalloutMock.class, new GeoMock());
        Test.startTest();
        Id newId = PropertyController.createProperty(
            JSON.serialize(prop), new List<PropertyController.FileWrapper>{ empty }
        );
        Test.stopTest();

        Integer linkCount = [
            SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :newId
        ];
        Assert.areEqual(0, linkCount, 'No file linked when base64 is blank');
    }

    @IsTest
    static void testGetProperty() {
        Property__c existing = [SELECT Id FROM Property__c LIMIT 1];
        Test.startTest();
        Property__c fetched = PropertyController.getProperty(existing.Id);
        Test.stopTest();
        Assert.areEqual(existing.Id, fetched.Id, 'Correct property returned');
    }
}