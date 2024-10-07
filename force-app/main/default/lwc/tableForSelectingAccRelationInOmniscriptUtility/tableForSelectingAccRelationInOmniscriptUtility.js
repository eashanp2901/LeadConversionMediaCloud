import { LightningElement, api } from 'lwc';
import { OmniscriptBaseMixin } from 'vlocity_cmt/omniscriptBaseMixin';

export default class TableForSelectingAccRelationInOmniscriptUtility extends OmniscriptBaseMixin(LightningElement) {

    @api existingAccRecords;
    @api newAccRecords;
    @api accRelationMapping;
    @api newAccountIdNode;
    @api newAccountNameNode;
    @api resultNodeName;

    isLoading = true;
    records = [];
    options = [];
    defaultAccRelation;

    connectedCallback(){

        if(this.existingAccRecords || this.newAccRecords)
        {
            this.accRelationMapping.forEach(element => {
                this.options.push({label : element.relationshipName, value : element.relationshipName})
                if(element.isDefault) this.defaultAccRelation = element.relationshipName;
            });

            if(!this.defaultAccRelation) this.defaultAccRelation = this.options[0];
            this.initializeRecords();
        }
        else {
            this.updateOmniScript();
            this.isLoading = false;
        }
    }

    initializeRecords(){

        if(this.existingAccRecords && this.existingAccRecords.length > 0){
            this.existingAccRecords.forEach(element => {
                this.records.push({"id" : element.Id,"name" : element.Name,"relation" : this.defaultAccRelation});
            });
        }

        if(this.newAccRecords){
            if(Array.isArray(this.newAccRecords)){
                this.newAccRecords.forEach(element => {
                    this.records.push({"id" : element[this.newAccountIdNode],"name" : element[this.newAccountNameNode],"relation" : this.defaultAccRelation});
                });
            }
            else{
                this.records.push({"id" : this.newAccRecords[this.newAccountIdNode],"name" : this.newAccRecords[this.newAccountNameNode],"relation" : this.defaultAccRelation});
            }
        }
        this.updateOmniScript();
        this.isLoading = false;
    }

    handleChange(event) {    
        this.isLoading = true;
        var updatedRecords = this.records;
        updatedRecords.forEach(element => {
            if(element.id == event.currentTarget.dataset.id){
                element.relation = event.detail.value;
            }                
        });
        this.records = updatedRecords;
        this.updateOmniScript();
        this.isLoading = false;
    }

    updateOmniScript() {
        var resultJSON = {};
        resultJSON[this.resultNodeName] = this.records;
        this.omniApplyCallResp(resultJSON);
    }
}