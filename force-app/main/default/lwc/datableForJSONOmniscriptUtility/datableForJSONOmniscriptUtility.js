import { LightningElement, api } from 'lwc';
import { OmniscriptBaseMixin } from 'vlocity_cmt/omniscriptBaseMixin';
import pubsub from 'vlocity_cmt/pubsub';


export default class DatableForJSONOmniscriptUtility extends OmniscriptBaseMixin(LightningElement) {

    columns = [        
        { label: 'Name', fieldName: 'Name', wrapText: true},
        { label: 'Billing Street', fieldName: 'BillingStreet', wrapText: true},
        { label: 'Billing City', fieldName: 'BillingCity', wrapText: true},
        { label: 'Billing State', fieldName: 'BillingState', wrapText: true},
        { label: 'Billing Postal Code', fieldName: 'BillingPostalCode', wrapText: true},
        { label: 'Billing Country', fieldName: 'BillingCountry', wrapText: true}
    ]; 

    tableRecords = [];
    recordsInTableIds = [];
    selectedRecordIds=[];
    isLoading = false;

    @api records;
    @api resultNodeName;

    get disableRemoveButton(){
        return this.selectedRecordIds.length === 0;
    }

    renderedCallback(){
        pubsub.register('omniscript_action', {
            data: this.handleOmniAction.bind(this),
        });
    }

    connectedCallback(){            
        if(this.records) this.addToTableRecords(this.records);
        this.updateOmniScript();
    }

    addToTableRecords(value) {
        var tableRecordIds = this.tableRecords.map((obj) => obj.AccountId);
        if(value.isArray) {
            var recordList = this.tableRecords;
            value.forEach((element) => {
                if(element.AccountId && !tableRecordIds.includes(element.AccountId)) {
                    recordList.push(element);
                }                
            });
            this.tableRecords = recordList; 
        }
        else {
            var recordList = this.tableRecords;
            if(value.AccountId && !tableRecordIds.includes(value.AccountId)) {
                recordList.push(value);
            }
            this.tableRecords = recordList;
        }
        this.updateOmniScript();
        this.refreshTable();
    }

    refreshTable(){
        this.isLoading = true;
        setTimeout(() => {
            this.isLoading = false;
        }, 1000);
    }

    handleOmniAction(data){
        this.addToTableRecords(data.recordToAdd);
    }

    handleRowSelection(event) {

        const selectedRows = event.detail.selectedRows;
        this.selectedRecordIds=selectedRows.map((obj) => obj.AccountId);
        this.updateOmniScript();
    }

    handleRemoveRecords(event) {
        this.tableRecords = this.tableRecords.filter(obj => !this.selectedRecordIds.includes(obj.AccountId));
        this.selectedRecordIds = [];
        this.updateOmniScript();
        this.refreshTable();

    }

    updateOmniScript() {
        var resultJSON = {};
        resultJSON[this.resultNodeName] = {
            "selectedRowIds": this.selectedRecordIds,
            "tableRecords": this.tableRecords.map((obj) => {
                return {"Id" : obj.AccountId, "Name" : obj.Name}
            })
        }
        this.omniApplyCallResp(resultJSON);
    }

}