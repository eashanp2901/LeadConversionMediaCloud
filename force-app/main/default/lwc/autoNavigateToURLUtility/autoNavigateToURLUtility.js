import { LightningElement, api } from 'lwc';
import { OmniscriptBaseMixin } from 'vlocity_cmt/omniscriptBaseMixin';

export default class AutoNavigateToURLUtility extends OmniscriptBaseMixin(LightningElement) {

    @api urlToNavigate;

    connectedCallback(){
        window.open(url, '_blank').focus();
    }

}