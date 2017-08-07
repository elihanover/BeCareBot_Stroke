//
//  ApiAIService.swift
//  BeCareBot
//
//  Created by Eli Hanover on 6/29/17.
//  Copyright © 2017 BeCare. All rights reserved.
//


import UIKit
import ApiAI

public typealias SuccesfullApiAIResponseBlock = (ApiAIResponse?) -> Swift.Void
public typealias FailureApiAIResponseBlock = (Error?) -> Swift.Void

class ApiAIService: NSObject {
    
    // Change to my api.ai information
    static let errorCode = 777 // ?
    static let errorDomain = "?"
    static let clientAccessToken = "45418f830b9d443f84df2aebb766f58e"
    
    private var apiAI = ApiAI()
    static let sharedInstance = ApiAIService()
    
    override init() {
        super.init()
        setupApiAI()
    }
    
    
    
    // it looks like this calls the real extractProducts method once
    // it checks for
    func extractProducts(fromText text: String,
                         success: SuccesfullApiAIResponseBlock!,
                         failure: FailureApiAIResponseBlock!) {
        let request = self.apiAI.textRequest()
        request?.query = text
        request?.setCompletionBlockSuccess({ [unowned self] (request, response) in
            if let response = response as? Dictionary<String, Any> { // if valid response from api.ai, set response to the response struct, mine should just be a string since I just want pure text, I don't need the extra struct as well
                success(self.extractMessageFromJSON(fromResponse: response))
            } else {
                let error = NSError(domain:ApiAIService.errorDomain,
                                    code:ApiAIService.errorCode,
                                    userInfo:nil)
                failure(error)
            }
            }, failure: { (request, error) in
                failure(error)
        })
        self.apiAI.enqueue(request)
    }
    
    
    
    // set up api.ai connection using accesstoken
    private func setupApiAI() {
        let configuration = AIDefaultConfiguration()
        configuration.clientAccessToken = ApiAIService.clientAccessToken
        self.apiAI.configuration = configuration
    }
    
    
    private func extractMessageFromJSON(fromResponse response: Dictionary<String, Any>) -> ApiAIResponse? {
        guard let fulfillment = response["fulfillment"] as? Dictionary<String, Any> else {
            return nil
        }
        
        guard let message = fulfillment["speech"] as? String else {
            return nil
        }
        
        return ApiAIResponse(message: message)
    }
    
    /*
    func sendText(text: String) -> String
    {
        let request = ApiAI.shared().textRequest()
        request?.query = [text]
        var messages: [[AnyHashable : Any]]
        
        request?.setMappedCompletionBlockSuccess({ (request, response) in
            let response = response as! AIResponse
            guard let messages = response.result.fulfillment.messages else {
                print("\n\n\n\nSomething wrong getting messages\n\n\n\n")
            }
        }, failure: { (request, error) in
            // TODO: handle error
            print("\n\n\n\n\nWell shit\n\n\n\n\n")
        })
        
        request?.setCompletionBlockSuccess({[unowned self] (request, response) -> Void in
                print("\n\n\n\n\nI guess this worked or something?...\n\n\n\n\n")
            
            }, failure: { (request, error) -> Void in
                print("\n\n\n\n\nuhhhhh\n\n\n\n\n")
        });
        
        ApiAI.shared().enqueue(request)
    }
     */

}
