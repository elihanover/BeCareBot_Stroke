//
//  ChatViewController.swift
//  BeCareBot
//
//  Created by Eli Hanover on 6/29/17.
//  Copyright © 2017 BeCare. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import ApiAI
import Speech
import SystemConfiguration
import SwiftyJSON
import Firebase
import FirebaseDatabase


// View Controller for Messaging Screen
class ChatViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UITextFieldDelegate, UICollectionViewDelegateFlowLayout, SFSpeechRecognizerDelegate {
    
    
    @IBOutlet weak var MyCollectionView: UICollectionView!
    @IBOutlet weak var textToSend: UITextField!
    @IBOutlet weak var sendButton: UIBarButtonItem!
    @IBOutlet weak var toolBar: UIToolbar! // bottom bar
    @IBOutlet weak var volume: UIBarButtonItem!
    @IBOutlet weak var back: UIBarButtonItem!
    @IBOutlet weak var navBar: UINavigationBar! // top bar
    
    // Set up JSON objects
    private var convMap : JSON = [] // actual conversation map to be loaded
    private var ref : String = ""
    private var synonyms : JSON = [] // JSON object of keyword synonyms
    
    // create Firebase instance
    // will send error cases to Firebase
    var firebase_object: DatabaseReference!
    

    // For speech to text and vice versa
    @IBOutlet weak var microphoneButton: UIBarButtonItem!
    private let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synth = AVSpeechSynthesizer() // text to speak engine
    

    // Messages an array that stores every message of the conversation.
    // The collectionview uses this each time it is updated.
    private var messages = ["Hi, I'm BeCare Bot, a chat bot designed to help answer any stroke-related questions.  Ask me something or type 'help' at any point to find out what you can ask me about.", "How can I help you?"]
    // Array that tells the collection view whether to format the bubble as a user or bot
    private var user = [true, true]
    
    // Array that stores the heights of the messages of the chats
    private var bubbleHeights = [CGFloat]()
    private var fontsize = CGFloat(20)
    
    // Width of the message bubbles to vary for device
    private var bubbleWidth: CGFloat = 0.0
    
    // BeCare Blue Color
    private var beCareBlue = UIColor(hex: "1F2C34")
    private var beCarePurp = UIColor(hex: "86134F")
    
    // Keyboard height to adjust text
    private var keyboardHeight: CGFloat = 0.0
    
    // Helper variable(s)
    private var stopped = false // tells speech to text to not write to textview
    private var tabBarUp = false // tells whether the tab bar is up or not
    private var speak = true // whether to speak output or not
    
    // This constraint ties an element at zero points from the bottom layout guide
    @IBOutlet var keyboardHeightLayoutConstraint: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load JSON objects
        self.convMap = loadJSON(filename: "convMapTest0")
        self.ref = "home"
        self.synonyms = loadJSON(filename: "synonyms")
        
        // Collection View delegate methods
        self.MyCollectionView.delegate = self
        self.MyCollectionView.dataSource = self
        self.MyCollectionView.alwaysBounceVertical = true
        
        // Set width of collection view bubbles to a proportion of the whole screen
        self.bubbleWidth = self.MyCollectionView.frame.width * 0.95
        
        // Sync keyboard with input text box
        self.textToSend.becomeFirstResponder()
        
        // init firebase ref
        self.firebase_object = Database.database().reference()
        
        // button colors
        sendButton.tintColor = UIColor.white
        microphoneButton.tintColor = UIColor.white
        
        // set background color
        self.view.backgroundColor = self.beCareBlue
        self.toolBar.barTintColor = self.beCareBlue
        self.MyCollectionView.backgroundColor = self.beCareBlue
        self.navBar.barTintColor = self.beCareBlue
        
        // Watch for keyboard moving
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardShown), name:NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        
        // Speech to text
        microphoneButton.isEnabled = false
        speechRecognizer?.delegate = self
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            
            var isButtonEnabled = false
            
            switch authStatus {
            case .authorized:
                isButtonEnabled = true
                
            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")
                
            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")
                
            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            }
            
            OperationQueue.main.addOperation() {
                self.microphoneButton.isEnabled = isButtonEnabled
            }
        }
        
        
        // if no internet connection
        // pop up message saying there is no internet connection and that you won't be able to receive responses
        // Uncomment if demanding internet connection for general use.
        /*
        if !self.isConnectedToNetwork() {
            self.connectionErrorPopUp()
        }*/
        
        
        
    }
    
    
    // get keyboard height
    func keyboardShown(notification: NSNotification) {
        
        print("Set keyboard height")
        let info = notification.userInfo!
        self.keyboardHeight = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue.maxY - (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue.minY
        print(self.keyboardHeight)
        
        if !tabBarUp {
            moveTextField(-self.keyboardHeight)
            scrollToBottom()
            self.tabBarUp = true
            print("Up to \(self.toolBar.frame.midY)")
        }
    }
    
    
    
    
// text view delegate methods

    // Start Editing The Text Field
    func textFieldDidBeginEditing(_ textField: UITextField) {
        print("Start editing")
        
        if !tabBarUp && self.keyboardHeight != CGFloat(0.0) {
            print("Moving up successfully")
            self.moveTextField(-self.keyboardHeight)
            self.scrollToBottom()
            self.tabBarUp = true
            print("Up to \(self.toolBar.frame.midY)")
        }
    }
    
    // Finish Editing The Text Field
    func textFieldDidEndEditing(_ textField: UITextField) {
        if tabBarUp {
            print("End editing")
            moveTextField(self.keyboardHeight)
            self.tabBarUp = false
            print("Down to \(self.toolBar.frame.midY)")
        }
    }
    
    // Hide the keyboard when the return key pressed
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        //view.endEditing(true)
        //textField.resignFirstResponder()
        
        return true
    }
    
    // Move the text field
    func moveTextField(_ moveDistance: CGFloat) {
        print("MOVING")
        print(moveDistance)
        let movement: CGFloat = CGFloat(moveDistance)
        
        //UIView.beginAnimations("animateTextField", context: nil)
        //UIView.setAnimationBeginsFromCurrentState(true)
        //UIView.setAnimationDuration(moveDuration)
        //self.view.frame = self.view.frame.offsetBy(dx: 0, dy: movement) // don't want to offset, just change bottom

        
        // move text field
        //self.textToSend.frame = self.textToSend.frame.offsetBy(dx: 0, dy: movement)
        //self.sendButton.frame = self.sendButton.frame.offsetBy(dx: 0, dy: movement)
        
        UIView.animate(withDuration: 0.25, animations: {
            self.toolBar.frame = self.toolBar.frame.offsetBy(dx: 0, dy: movement)
            
            // change bounds of the collection view to adjust for keyboard
            self.MyCollectionView.frame = CGRect(x: self.MyCollectionView.frame.minX, y: self.MyCollectionView.frame.minY, width: self.MyCollectionView.frame.width, height: self.MyCollectionView.frame.height + movement)
        })
    }

    
    @IBAction func hideFromSwipe(_ sender: Any) {
        view.endEditing(true)
    }
    
    @IBAction func hideKeyboard(_ sender: Any) {
        view.endEditing(true)
    }
// end textview delegate methods
    
    
    
    
    // "Choose_subpath"
    // Called after a message is sent to the bot
    func getResponse(query: String) {

        print("test")
        print(ref)
        print(self.convMap[ref]["outlets"].arrayValue.count)
        if query.lowercased() == "help" {
            
            var response = (ref == "home" || ref == "whatelse" ? "Here are some things you can ask me about:" : "Here are some keywords I might understand:")
            
            // Message back the available keywords
            for i in 0..<self.convMap[ref]["keywords"].count {
                let keyword = self.convMap[ref]["keywords"][i].string!
                print(keyword)
                response += "\n - "
                response += keyword
            }
            
            self.addTextToCollection(text: response, agent: true)
            self.scrollToBottom()
            self.speakOutput(text: response)
            return
            
        } else {
            
            for i in 0..<self.convMap[ref]["keywords"].count {
                
                // if query contains this keyword, set ref to the correct outlet and return that response
                let keyword = self.convMap[ref]["keywords"][i].string!
                if self.keyword_or_synonyms_found(keyword: keyword, query: query) {
                    ref = self.convMap[ref]["outlets"][i].string! // update ref
                    
                    // if info not "", add to collection
                    if self.convMap[ref]["info"] != "" {
                        let info = self.convMap[ref]["info"].string!.unescaped
                        self.addTextToCollection(text: info, agent: true)
                        self.scrollToBottom()
                        self.speakOutput(text: info)
                    }
                    // if prompt not "", add to collection
                    if self.convMap[ref]["prompt"] != "" {
                        let prompt = self.convMap[ref]["prompt"].string!.unescaped
                        self.addTextToCollection(text: prompt, agent: true)
                        self.scrollToBottom()
                        self.speakOutput(text: prompt)
                    }
                    
                    // If only one future state, automatically go to it
                    if self.convMap[ref]["outlets"].arrayValue.count == 1 {
                        
                        print("\n\n\n\nTRUE\n\n\n\n")
                        
                        // If only one subpath, set ref to that outlet
                        ref = self.convMap[ref]["outlets"][0].string!
                        // if info not "", add to collection
                        if self.convMap[ref]["info"] != "" {
                            let info = self.convMap[ref]["info"].string!.unescaped
                            self.addTextToCollection(text: info, agent: true)
                            self.scrollToBottom()
                            self.speakOutput(text: info)
                        }
                        // if prompt not "", add to collection
                        if self.convMap[ref]["prompt"] != "" {
                            let prompt = self.convMap[ref]["prompt"].string!.unescaped
                            self.addTextToCollection(text: prompt, agent: true)
                            self.scrollToBottom()
                            self.speakOutput(text: prompt)
                        }
                    }
                    
                    return
                }
            }
        }
        
        
        
        // else if no matches, add error to Firebase
        self.addRefAndKeyword(ref: ref, query: query)
        
        
        if ref == "home" || ref == "whatelse" {
            // Have API.ai give a response instead
            let request = ApiAI.shared().textRequest()
            request?.query = query
        
        
            request?.setMappedCompletionBlockSuccess({ (request, response) in
                guard let response = response as? AIResponse else {
                    print("Err1")
                    return
                }
           
                // if we get the message with no problems
                if let textResponse = response.result.fulfillment.speech {
                    print(textResponse)
                    self.addTextToCollection(text: textResponse, agent: true) // add the api.ai response back into the collection view
               
                    // scroll to bottom
                    self.scrollToBottom()
               
                    // speak the result
                    self.speakOutput(text: textResponse)
                }
           
            }, failure: { (request, error) in
                // TODO: handle error
                print("\n\n\n\nsomething went wrong here\n\n\n\n\n")
            })
       
            ApiAI.shared().enqueue(request)
            print("Done")
            
        } else {
            
            
            let response = "I didn't quite get that. Try again or enter 'help'."
            self.addTextToCollection(text: response, agent: true)
            self.scrollToBottom()
            self.speakOutput(text: response)
        }
    }
 
    

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let width = self.bubbleWidth
        
        // check if item at index path has already been calculated
        // assume if array value exists at this index that this is right
        if indexPath.row < bubbleHeights.count {
            // NEED TO FIND WIDTH THAT VARIES
            return CGSize(width: width, height: bubbleHeights[indexPath.row])
        }
        
        // else, calculate the height based on the label
        //let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell_id", for: indexPath) as! MyCollectionViewCell
        
        let message = messages[indexPath.row] // get message corresponding to this label
        
        print("Cell message:")
        print(message)
        
        let size = CGSize(width: width, height: 1000)
        
        let nsstring = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
        
        let rectangle = NSString(string: message).boundingRect(with: size, options: nsstring, attributes: [NSFontAttributeName : UIFont.systemFont(ofSize: 18)], context: nil)
        
        let bias = CGFloat(18)
        bubbleHeights.append(rectangle.height+bias) // add so we can reference later
        return CGSize(width: width, height: rectangle.height+bias)
        
    }
    
 
    
    
    // Formats each message bubble
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell_id", for: indexPath) as! MyCollectionViewCell
        
        cell.myLabel.text = messages[indexPath.row] // set each message text
        cell.layer.cornerRadius = 10.0
        
        
        if user[indexPath.row] { // if comp
            cell.myLabel.textColor = UIColor.white
            cell.backgroundColor = beCarePurp
            cell.layer.borderColor = UIColor.white.cgColor
            cell.layer.borderWidth = CGFloat(1.5)
            cell.myLabel.textAlignment = NSTextAlignment.left
        } else { // if user
            cell.myLabel.textColor = beCareBlue
            cell.backgroundColor = UIColor.white
            cell.layer.borderColor = beCarePurp.cgColor
            cell.layer.borderWidth = CGFloat(1.5)
            cell.myLabel.textAlignment = NSTextAlignment.right
        }
        
        return cell
    }
    

    
    // method to add text from some textfield to messages array and then reload the collectionview
    // Agent 0/false = user
    // Agent 1/true = bot
    func addTextToCollection(text: String, agent: Bool) {
        
        // or any combination of spaces
        if text == "" {
            return
        }
        
        messages.append(text)
        user.append(agent)
        MyCollectionView.reloadData()
    }

    
    
    // Called when button is pressed.
    // Makes a call to api.ai and updates the label with the response
    @IBAction func sendText(sender: UIBarButtonItem) {
        stopRecording() // make sure to stop recording
        
        // Add user text to the collection view
        let query = self.textToSend.text
        if query == "" { return }
        self.addTextToCollection(text: query!, agent: false)
        self.textToSend.text = "" // reset text field
        
        
        // Call get response to return the relevant messages and update the ref state
        self.getResponse(query: query!)
        
        
        
        
        
    }
    
    func scrollToBottom() {
        let section = 0
        let item = self.MyCollectionView.numberOfItems(inSection: section) - 1
        let lastIndexPath = IndexPath(item: item, section: section)
        self.MyCollectionView.scrollToItem(at: lastIndexPath, at: .bottom, animated: true)
    }
    
    
    
    //
    //
    // SPEECH
    //
    //
    // Speaks the last message in the collection view
    // Called after the api.ai result is added to the collectionview
    func speakOutput(text: String) {
        // don't speak if self.speak is false
        if self.speak == false { return }
        
        // make sure we set the audioSession back into play mode
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayback)
            try audioSession.setMode(AVAudioSessionModeDefault)
            print("WE OUT HERE")
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        
        
        self.synth.speak(utterance)
    }
    
    //
    // Start recording
    //
    @IBAction func microphoneTapped(_ sender: Any) {
        if audioEngine.isRunning {
            self.textToSend.text = ""
            microphoneButton.tintColor = UIColor.white
            audioEngine.stop()
            recognitionRequest?.endAudio()
            microphoneButton.isEnabled = false
        } else { // only go here if it wasn't called by send
            microphoneButton.tintColor = UIColor.red
            startRecording()
        }
    }
    
    func stopRecording() {
        if audioEngine.isRunning {
            microphoneButton.tintColor = UIColor.white
            audioEngine.stop()
            recognitionRequest?.endAudio()
            microphoneButton.isEnabled = false
            self.stopped = true
        }
    }
    
    
    func startRecording() {
        
        self.stopped = false // allow text to be written out
        
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else {
            fatalError("Audio engine has no input node")
        }
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            var isFinal = false
            
            if result != nil {
                if !self.stopped {
                    self.textToSend.text = result?.bestTranscription.formattedString
                }
                isFinal = (result?.isFinal)!
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.microphoneButton.isEnabled = true
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
        
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            microphoneButton.isEnabled = true
        } else {
            microphoneButton.isEnabled = false
        }
    }

    
    //
    // Returns whether there is connection to some network or not
    //
    func isConnectedToNetwork() -> Bool {
        
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        
        return (isReachable && !needsConnection)
        
    }
    
    //
    // Pop up notification that internet connection faulty
    // Called when isConnectedToNetwork returns false
    //
    func connectionErrorPopUp () {
        
        // if no internet connection
        if !self.isConnectedToNetwork() {
            // pop up message saying there is no internet connection and that you won't be able to receive responses
            let alertController = UIAlertController(title: "No Internet Connection", message:
                "Connect to the Internet in order to receive responses from MSBot.", preferredStyle: UIAlertControllerStyle.alert)
            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default,handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
        self.moveTextField(-self.keyboardHeight)
        
    }
    
    
    @IBAction func changeVolume(_ sender: UIBarButtonItem) {
        if synth.isSpeaking { synth.stopSpeaking(at: AVSpeechBoundary.immediate) }
        print(self.speak)
        print("hello")
        self.speak = !self.speak
        self.volume.tintColor = self.speak ? UIColor.white : UIColor.red
        self.volume.title = self.speak ? "Mute" : "Unmute"

    }
    
    
    override func viewWillDisappear(_ animated : Bool) {
        super.viewWillDisappear(animated)
        // stop speech
        if self.synth.isSpeaking {
            self.synth.stopSpeaking(at: AVSpeechBoundary.immediate)
        }
    }
    
    func loadJSON(filename: String) -> JSON {
        if let filepath = Bundle.main.path(forResource: filename, ofType: "json") {
            let data = NSData(contentsOfFile: filepath) // need whole pathfile which is annoying...
            if let jsonData = data {
                return JSON(data: jsonData as Data)
            }
            self.speakOutput(text: "Hmmm")
        }
            
        self.speakOutput(text: "Null")
        return JSON.null
    }
    
    // Add error case to Firebase to check later
    // Called when no keyword/outlet is detected in a query
    func addRefAndKeyword(ref: String, query: String) {
        
        let entry = ["ref": ref,
                     "query": query]
        
        let error_id = firebase_object.child("errors").childByAutoId().key
        self.firebase_object.child(error_id).setValue(entry)
    }
    
    
    // Returns whether a keyword or any of its synonyms are in a query
    func keyword_or_synonyms_found(keyword: String, query: String) -> Bool {
        
        // Check if the keyword is found
        if query.lowercased().range(of: keyword.lowercased()) != nil {
            return true
        }
        
        // Check if a synonym detected
        for synonym in self.synonyms[keyword].arrayValue {
            if query.lowercased().range(of: (synonym.string?.lowercased())!) != nil {
                return true
            }
        }
        
        //self.speakOutput(text: "Nothing found")
        return false
    }
    
    
}


/* To deal with unescaped characters from JSON */
extension String {
    var unescaped: String {
        let entities = ["\0", "\t", "\n", "\r", "\"", "\'", "\\"]
        var current = self
        for entity in entities {
            let descriptionCharacters = entity.debugDescription.characters.dropFirst().dropLast()
            let description = String(descriptionCharacters)
            current = current.replacingOccurrences(of: description, with: entity)
        }
        return current
    }
}

// Convert hex string to a UIColor
extension UIColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex)
        scanner.scanLocation = 0
        
        var rgbValue: UInt64 = 0
        
        scanner.scanHexInt64(&rgbValue)
        
        let r = (rgbValue & 0xff0000) >> 16
        let g = (rgbValue & 0xff00) >> 8
        let b = rgbValue & 0xff
        
        self.init(
            red: CGFloat(r) / 0xff,
            green: CGFloat(g) / 0xff,
            blue: CGFloat(b) / 0xff, alpha: 1
        )
    }
}
