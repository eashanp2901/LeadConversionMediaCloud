global with sharing class MediaPOCLeadConversionHelper implements vlocity_cmt.VlocityOpenInterface2 {
        
    @JsonAccess(serializable='always' deserializable='always')
    public class AccountRelationInputWrapper {
        public String id;
        public String name;
        public String relation;
    }    
    
    @JsonAccess(serializable='always' deserializable='always')
    public class ResultWrapper {
        public String leadId;
        public String convertedAccountId;
        public String convertedAccountName;
        public String convertedContactId;
        public String convertedContactName;
        public String convertedOpportunityId;
        public String convertedOpportunityName;
        
        ResultWrapper(String leadId,String convertedAccountId,String convertedAccountName,String convertedContactId,String convertedContactName,String convertedOpportunityId,String convertedOpportunityName){
            this.leadId = leadId;
            this.convertedAccountId = convertedAccountId;
            this.convertedAccountName = convertedAccountName;
            this.convertedContactId = convertedContactId;
            this.convertedContactName = convertedContactName;
            this.convertedOpportunityId = convertedOpportunityId;
            this.convertedOpportunityName = convertedOpportunityName;
        }
    }    
    
    global Boolean invokeMethod(String methodName, Map < String, Object > inputMap, Map < String, Object > outMap, Map < String, Object > options) {
        Boolean result = true;
        try {
            if ('convertLead'.equalsIgnoreCase(methodName)) {
                convertLead(inputMap, outMap, options);
            } else {
                outMap.put('result',null);
            }
        } catch (Exception e) {
            result = false;
        }
        return result;
    }    
    
    private static void convertLead(Map < String, Object > inputMap, Map < String, Object > outMap, Map < String, Object > options)
    {
        try 
        {
            
            if(!inputMap.containsKey('leadId'))
            {
                outMap.put('result',null);
                outMap.put('errorMessage','Couldn\'t find the lead record id for conversion.');
                return;
            }            
            
            String leadId = (String)inputMap.get('leadId');
            List<Lead> leadRecord = [SELECT Id,Company,Company_Email__c,Lead_Type__c 
                                     FROM Lead 
                                     WHERE Id = :leadId];
            
            if(leadRecord.isEmpty())
            {
                outMap.put('result',null);
                outMap.put('errorMessage','Couldn\'t find the lead record for conversion.');
                return;
            }
            
            String leadType = leadRecord[0].Lead_Type__c;
            Lead_Conversion_Omniscript_Setting__mdt leadConvStatusConfig = Lead_Conversion_Omniscript_Setting__mdt.getInstance('LEAD_CONVERTED_STATUS');
            Lead_Conversion_Omniscript_Setting__mdt leadOwnerUsernameConfig = Lead_Conversion_Omniscript_Setting__mdt.getInstance('LEAD_OWNER_USERNAME');
            Lead_Conversion_Omniscript_Setting__mdt accountRecordTypeNameConfig = Lead_Conversion_Omniscript_Setting__mdt.getInstance(leadType.toUpperCase() + '_RECORD_TYPE_DEVNAME');
            
            if( leadConvStatusConfig == null || leadOwnerUsernameConfig == null || accountRecordTypeNameConfig == null )
            {
                outMap.put('result',null);
                outMap.put('errorMessage','Couldn\'t find the lead conversion configurations.');
                return;
            }              
            
            List<User> leadOwner = [Select Id from User where username = :leadOwnerUsernameConfig.Value__c];
            
            if(leadOwner.isEmpty())
            {
                outMap.put('result',null);
                outMap.put('errorMessage','Couldn\'t find the lead owner user.');
                return;
            }                   
            
            List<Account> duplicateAccount = [Select Id 
                                              from Account 
                                              where vlocity_cmt__BillingEmailAddress__c = :leadRecord[0].Company_Email__c 
                                              and RecordType.DeveloperName = :accountRecordTypeNameConfig.Value__c];
                
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(leadId);
            lc.setConvertedStatus(leadConvStatusConfig.Value__c);
            lc.setOpportunityName(leadRecord[0].Company + ' Opp - ' + String.valueOf(Date.today()).removeEnd(' 00:00:00'));
            if(!duplicateAccount.isEmpty()) lc.setAccountId(duplicateAccount[0].Id);
            lc.setOwnerId(leadOwner[0].Id);
            
            Database.LeadConvertResult lcr;
            lcr = Database.convertLead(lc);
            
            if ( lcr.isSuccess() ) 
            {
                Account convertedAcc = [Select Id,Name, RecordTypeId, vlocity_cmt__BillingEmailAddress__c from Account where Id = :lcr.getAccountId()];
                Contact convertedContact = [Select Id,Name from Contact where Id = :lcr.getContactId()];
                Opportunity convertedOpp = [Select Id,Name from Opportunity where Id = :lcr.getOpportunityId()];
                
                //Get account record type id using Lead_Conversion_Omniscript_Setting__mdt which is mapped to the Lead_Type__c
                List<RecordType> recordTypeId = [Select Id 
                                                 from RecordType 
                                                 where SobjectType = 'Account' 
                                                 and DeveloperName = :accountRecordTypeNameConfig.Value__c];
                
                if(recordTypeId.isEmpty())
                {
                    outMap.put('partialError','Account record type not found.');
                }
                else
                {
                    if(duplicateAccount.isEmpty())
                    {
                        convertedAcc.RecordTypeId = recordTypeId[0].Id;
                        convertedAcc.vlocity_cmt__BillingEmailAddress__c = leadRecord[0].Company_Email__c;
                        update convertedAcc;    
                    }
                    
                }
                
                List<AccountRelationInputWrapper> accountsToLinkInputList = (List<AccountRelationInputWrapper>) JSON.deserialize(JSON.serialize(inputMap.get('accountsToLink')), List<AccountRelationInputWrapper>.class);
                
                if(!accountsToLinkInputList.isEmpty())
                {
                    linkAccountsVlocity(convertedAcc.Id,accountsToLinkInputList,leadType,outMap);
                }
                
                ResultWrapper result = new ResultWrapper(leadId,convertedAcc.Id,convertedAcc.Name,convertedContact.Id,convertedContact.Name,convertedOpp.Id,convertedOpp.Name);
                outMap.put('result',result);
            }
            else
            {
                outMap.put('result',null);
                outMap.put('errorMessage',String.valueOf(lcr.getErrors()));
            }
        } catch (Exception e) {
            outMap.put('result',null);
            outMap.put('errorMessage',e.getMessage());
            outMap.put('errorStacktrace',e.getStacktraceString());
            system.debug('ErrorMsg: '+e.getMessage());
            system.debug('ErrorStacktrace: '+e.getStacktraceString());
            throw e;
        }

    }    
    
    private static void linkAccountsVlocity(String convertedAccountId,List<AccountRelationInputWrapper> accountsToLinkInputList,String leadType,Map < String, Object > outMap)
    {
        try{
            Set<String> accountIds = new Set<String>{convertedAccountId};
            Set<String> relationTypes = new Set<String>();
            Map<String,String> relationNameToIdMap = new Map<String,String>();
            Map<String,AccountRelationInputWrapper> accountRelationMap = new Map<String,AccountRelationInputWrapper>();
            Map<String,vlocity_cmt__Party__c> accountIdToPartyMap = new Map<String,vlocity_cmt__Party__c>();
            List<vlocity_cmt__Party__c> partiesToCreate = new List<vlocity_cmt__Party__c>();
            List<vlocity_cmt__PartyRelationship__c> partyRelationsToCreate = new List<vlocity_cmt__PartyRelationship__c>();
            String targetRole = leadType.equalsIgnoreCase('Advertiser') ? 'Agency' : 'Advertiser';
            
            for(AccountRelationInputWrapper record : accountsToLinkInputList)
            {
                accountIds.add(record.id);
                relationTypes.add(record.relation);
				accountRelationMap.put(record.id,record);                
            }
            
            for(vlocity_cmt__PartyRelationshipType__c record : [Select Id,vlocity_cmt__SourceString__c 
                                                                from vlocity_cmt__PartyRelationshipType__c 
                                                                where vlocity_cmt__SourceString__c in :relationTypes])
                relationNameToIdMap.put(record.vlocity_cmt__SourceString__c,record.Id);
                        
            for(vlocity_cmt__Party__c record : [Select Id,vlocity_cmt__AccountId__c 
                                                from vlocity_cmt__Party__c 
                                                where vlocity_cmt__AccountId__c in :accountIds])
            {
				accountIdToPartyMap.put(record.vlocity_cmt__AccountId__c,record);	                
            }
                        
            for(String accountId : accountIds)
            {
                if(!accountIdToPartyMap.containsKey(accountId))
                {
                    vlocity_cmt__Party__c newParty = new vlocity_cmt__Party__c();
                    newParty.Name = accountRelationMap.get(accountId).name;
                    newParty.vlocity_cmt__AccountId__c = accountId;
                    newParty.vlocity_cmt__PartyEntityId__c = accountId;
                    newParty.vlocity_cmt__PartyEntityType__c = 'Account';
                    
                    accountIdToPartyMap.put(accountId,newParty);
                    partiesToCreate.add(newParty);
                }
            }
                        
            if(!partiesToCreate.isEmpty()) insert partiesToCreate;
            
            for(AccountRelationInputWrapper record : accountsToLinkInputList)
            {
                vlocity_cmt__PartyRelationship__c partyRelation = new vlocity_cmt__PartyRelationship__c();
                partyRelation.Name = 'LEAD_CONV_ACCOUNT_RELATION';
                partyRelation.vlocity_cmt__SourcePartyId__c = accountIdToPartyMap.get(convertedAccountId).Id;
                partyRelation.vlocity_cmt__TargetPartyId__c = accountIdToPartyMap.get(record.id).Id;
                partyRelation.vlocity_cmt__PrimaryRole__c = leadType;
                partyRelation.vlocity_cmt__TargetRole__c = targetRole;
                partyRelation.vlocity_cmt__RelationshipTypeId__c = relationNameToIdMap.get(record.relation);
                partyRelation.vlocity_cmt__RelationshipStartDate__c = System.TODAY();
                partyRelation.vlocity_cmt__IsActive__c = true;
                partyRelationsToCreate.add(partyRelation);
            }
            
            insert partyRelationsToCreate;            
            
            //Update Party Relation names to it's record id
            for(vlocity_cmt__PartyRelationship__c record : partyRelationsToCreate)
                record.Name = record.Id;
            
            update partyRelationsToCreate;    
                            
        } catch (Exception e) {
            outMap.put('result',null);
            outMap.put('errorMessage',e.getMessage());
            outMap.put('errorStacktrace',e.getStacktraceString());
            system.debug('ErrorMsg: '+e.getMessage());
            system.debug('ErrorStacktrace: '+e.getStacktraceString());
            throw e;
        }
    }

}