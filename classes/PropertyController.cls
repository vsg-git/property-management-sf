public with sharing class PropertyController {
    private static final Set<String> SORTABLE_FIELDS = new Set<String>{
        'Name', 'Street__c', 'City__c', 'Status__c', 'Furnishing_Status__c', 'Rent__c'
    };
    private static final Set<String> SORT_DIRECTIONS = new Set<String>{ 'asc', 'desc' };
    private static final Integer MAX_OFFSET = 2000;

    public class PropertyPage {
        @AuraEnabled public List<Property__c> records;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Id lastRecordId;
    }

    public class FileWrapper {
        @AuraEnabled public String fileName;
        @AuraEnabled public String base64Data;
    }

    @AuraEnabled(cacheable=true)
    public static PropertyPage getProperties(
        String filtersJson,
        String sortBy,
        String sortDirection,
        Id lastRecordId,
        Integer pageNumber,
        Integer pageSize
    ) {
        Integer limitSize = pageSize == null || pageSize <= 0 ? 25 : pageSize;

        Map<String, Object> filters = new Map<String, Object>();
        if (String.isNotBlank(filtersJson)) {
            filters = (Map<String, Object>) JSON.deserializeUntyped(filtersJson);
        }

        Map<String, Object> binds = new Map<String, Object>();
        List<String> conditions = buildConditions(filters, binds);

        String selectClause = 'SELECT Id, Name, Street__c, City__c, State__c, Postal_Code__c, Country__c, '
            + 'Type__c, Furnishing_Status__c, Status__c, Rent__c, Description__c, '
            + 'Location__Latitude__s, Location__Longitude__s '
            + 'FROM Property__c';

        Boolean useSort = String.isNotBlank(sortBy) && SORTABLE_FIELDS.contains(sortBy);

        binds.put('limitSize', limitSize);

        String query;
        List<Property__c> records;

        if (useSort) {
            String dir = String.isNotBlank(sortDirection) && SORT_DIRECTIONS.contains(sortDirection.toLowerCase())
                ? sortDirection.toLowerCase()
                : 'asc';
            Integer page = pageNumber == null || pageNumber < 0 ? 0 : pageNumber;
            Integer offset = page * limitSize;
            if (offset > MAX_OFFSET) {
                offset = MAX_OFFSET;
            }
            binds.put('offsetSize', offset);

            String whereClause = conditions.isEmpty() ? '' : ' WHERE ' + String.join(conditions, ' AND ');
            query = selectClause + whereClause + ' ORDER BY ' + sortBy + ' ' + dir
                + ', Id ASC LIMIT :limitSize OFFSET :offsetSize';
            records = Database.queryWithBinds(query, binds, AccessLevel.USER_MODE);
        } else {
            List<String> pageConditions = new List<String>(conditions);
            if (lastRecordId != null) {
                pageConditions.add('Id > :lastRecordId');
                binds.put('lastRecordId', lastRecordId);
            }
            String whereClause = pageConditions.isEmpty() ? '' : ' WHERE ' + String.join(pageConditions, ' AND ');
            query = selectClause + whereClause + ' ORDER BY Id ASC LIMIT :limitSize';
            records = Database.queryWithBinds(query, binds, AccessLevel.USER_MODE);
        }

        String countWhere = conditions.isEmpty() ? '' : ' WHERE ' + String.join(conditions, ' AND ');
        String countQuery = 'SELECT COUNT() FROM Property__c' + countWhere;
        Integer total = Database.countQueryWithBinds(countQuery, binds, AccessLevel.USER_MODE);

        PropertyPage page = new PropertyPage();
        page.records = records;
        page.totalCount = total;
        page.lastRecordId = records.isEmpty() ? lastRecordId : records[records.size() - 1].Id;
        return page;
    }

    @AuraEnabled
    public static Id createProperty(String propertyJson, List<FileWrapper> files) {
        Property__c prop = (Property__c) JSON.deserialize(propertyJson, Property__c.class);
        insert as user prop;

        if (files != null && !files.isEmpty()) {
            List<ContentVersion> versions = new List<ContentVersion>();
            for (FileWrapper file : files) {
                if (file == null || String.isBlank(file.base64Data)) {
                    continue;
                }
                versions.add(new ContentVersion(
                    Title = file.fileName,
                    PathOnClient = file.fileName,
                    VersionData = EncodingUtil.base64Decode(file.base64Data),
                    FirstPublishLocationId = prop.Id
                ));
            }
            if (!versions.isEmpty()) {
                insert as user versions;
            }
        }
        return prop.Id;
    }

    @AuraEnabled(cacheable=true)
    public static Property__c getProperty(Id recordId) {
        List<Property__c> records = [
            SELECT Id, Name, Street__c, City__c, State__c, Postal_Code__c, Country__c,
                Type__c, Furnishing_Status__c, Status__c, Rent__c, Description__c,
                Location__Latitude__s, Location__Longitude__s
            FROM Property__c
            WHERE Id = :recordId
            WITH USER_MODE
            LIMIT 1
        ];
        return records.isEmpty() ? null : records[0];
    }

    private static List<String> buildConditions(Map<String, Object> filters, Map<String, Object> binds) {
        List<String> conditions = new List<String>();

        if (filters.get('minPrice') != null) {
            binds.put('minPrice', toDecimal(filters.get('minPrice')));
            conditions.add('Rent__c >= :minPrice');
        }
        if (filters.get('maxPrice') != null) {
            binds.put('maxPrice', toDecimal(filters.get('maxPrice')));
            conditions.add('Rent__c <= :maxPrice');
        }
        if (String.isNotBlank((String) filters.get('status'))) {
            binds.put('status', (String) filters.get('status'));
            conditions.add('Status__c = :status');
        }
        if (String.isNotBlank((String) filters.get('furnishingStatus'))) {
            binds.put('furnishingStatus', (String) filters.get('furnishingStatus'));
            conditions.add('Furnishing_Status__c = :furnishingStatus');
        }
        if (filters.get('latitude') != null && filters.get('longitude') != null && filters.get('radiusKm') != null) {
            binds.put('latitude', toDecimal(filters.get('latitude')));
            binds.put('longitude', toDecimal(filters.get('longitude')));
            binds.put('radiusKm', toDecimal(filters.get('radiusKm')));
            conditions.add('DISTANCE(Location__c, GEOLOCATION(:latitude, :longitude), \'km\') < :radiusKm');
        }
        return conditions;
    }

    private static Decimal toDecimal(Object value) {
        if (value == null) {
            return null;
        }
        return Decimal.valueOf(String.valueOf(value));
    }
}