import ballerina/http;
import ballerina/io;
import ballerina/system;

endpoint http:Listener listener {
    port:9090
    
};

endpoint http:Client soapService {
    url: system:getEnv("SOAP_ENDPOINT")
};

@http:ServiceConfig {
    basePath: "/"
}
service<http:Service> soaprest bind listener {
    @http:ResourceConfig {
        path: "/",
        consumes: ["application/json"],
        produces: ["application/json"],
        body: "authoriseRequest"
    }
    newResource (endpoint caller, 
            http:Request request, 
            Authorise authoriseRequest) {

        http:Request req;
        req.setPayload(getXML(authoriseRequest));
        req.setHeader("soapAction", "http://freo.me/payment/authorise");
        http:Response soapRes =  check soapService->post("/pay/services/paymentSOAP",  request = req);
        xml result = check soapRes.getXmlPayload();
        AuthoriseResponse ar = getAuthoriseResponse(result);
        json j = check <json>ar;
        http:Response response;
        response.setPayload(j);
        _ = caller -> respond(response);
    }
}

type Authorise {
    int cardNumber;
    string postcode;
    string name;
    int month;
    int year;
    int cvc;
    string merchant;
    string reference;
    float amount;
};

type AuthoriseResponse {
    boolean success;
    string authCode;
    string reference;
    string refusalReason;
};

function getXML(Authorise a) returns xml {
    xmlns "http://schemas.xmlsoap.org/soap/envelope/" as soap;
    xmlns "http://freo.me/payment/" as pay;
    
    var body = 
        xml `<pay:authorise>
                <pay:card>
                    <pay:cardnumber>{{a.cardNumber}}</pay:cardnumber>
                    <pay:postcode>{{a.postcode}}</pay:postcode>
                    <pay:name>{{a.name}}</pay:name>
                    <pay:expiryMonth>{{a.month}}</pay:expiryMonth>
                    <pay:expiryYear>{{a.year}}</pay:expiryYear>
                    <pay:cvc>{{a.cvc}}</pay:cvc>
                </pay:card>
                <pay:merchant>{{a.merchant}}</pay:merchant>
                <pay:reference>{{a.reference}}</pay:reference>
                <pay:amount>{{a.amount}}</pay:amount>
            </pay:authorise>`;
    var soapBody =  xml `<soap:Envelope><soap:Body>{{body}}</soap:Body></soap:Envelope>`;
    return soapBody;
}

function getAuthoriseResponse(xml x) returns AuthoriseResponse {
    json j = x.toJSON({preserveNamespaces:false}).
        Envelope.Body.authoriseResponse;
    AuthoriseResponse ar;
    if ((check <string>j.resultcode) != "0") {
        ar.success = false;
        ar.refusalReason = check <string>j.refusalreason;
    }
    else {
        ar.success = true;
        ar.refusalReason = "";
    }
    
    ar.authCode = check <string>j.authcode;
    ar.reference = check <string>j.reference;
    
    return ar;
}