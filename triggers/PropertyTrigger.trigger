trigger PropertyTrigger on Property__c (after insert, after update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        PropertyTriggerHandler.afterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        PropertyTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}