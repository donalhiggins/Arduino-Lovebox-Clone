//
//  ContentView.swift
//  messageBox
//
//  Created by Donal Higgins on 12/24/21.
//
import SwiftUI
import CocoaMQTT
import Foundation
import Alamofire



public enum DispatchLevel {
    case main, userInteractive, userInitiated, utility, background
    var dispatchQueue: DispatchQueue {
        switch self {
        case .main:                 return DispatchQueue.main
        case .userInteractive:      return DispatchQueue.global(qos: .userInteractive)
        case .userInitiated:        return DispatchQueue.global(qos: .userInitiated)
        case .utility:              return DispatchQueue.global(qos: .utility)
        case .background:           return DispatchQueue.global(qos: .background)
        }
    }
}


struct ContentView: View {
    @State private var encoded = ""
    @State private var pictureMode = false
    @State public var Connection:Bool = false
    @State private var message = ""
    @State private var imageData = ""
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage?
    @State private var image: Image?
    @State public var bytes: Array<UInt8>?
    @State private var len = 0
    let data = [
        "To" : "",
        "From" : "",
        "Body" : "Test"
    ]
    let accountSID = ""
    let authToken = ""
    let url = "https://api.twilio.com/"
    
    let mqttClient = CocoaMQTT(clientID: "swift", host: "broker.emqx.io", port: 1883)
    
    var body: some View {


        
        VStack {
            Button(action: {
                self.mqttClient.username="user"
                self.mqttClient.password="password"
                self.mqttClient.keepAlive=60
                self.mqttClient.connect()
                self.Connection.toggle()
            }, label: {
                Text(Connection ? "Disconnect":"Connect").foregroundColor(Connection ? Color.red:Color.green)
            })
            
            Group {
                TextField("Enter your message ❤️", text: $message)
                    .multilineTextAlignment(.center)
                    .frame(width: 300)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(hue: 0.924, saturation: 1.0, brightness: 1.0, opacity: 0.1)))
                Button("Send") {
                    
                    AF.request(url, method: .post, parameters: data)
                        .authenticate(username: accountSID, password: authToken)
                        .responseJSON { response in
                            debugPrint(response)
                        }
                    
                    if(pictureMode){
                        
                        inputImage = resizeImage(image: inputImage!, newWidth: 128)
                        message = imgToBinaryArray(image: inputImage!)
                        message = runLengthEncoding(str: message)
                        let half = Int(message.count / 2)
                        let message1 = String(message[0..<half]) + "$"
                        let message2 = String(message[half..<message.count])

                        
                        self.mqttClient.publish("", withString: String(message1))
                        self.mqttClient.publish("", withString: String(message2))
                        
                    }
                    else{
                        message += "$&#"
                        self.mqttClient.publish("", withString: message)
                    }
                    message = ""
                    imageData = ""
                    
                }
                Button("Add Image"){
                    showingImagePicker = true
                }
                VStack{
                    Text(pictureMode ? "Picture Mode" : "Text Mode")
                    Toggle("Picture Mode", isOn: $pictureMode)
                        .labelsHidden()
                        }
                }
        }
        .onChange(of: inputImage) { _ in loadImage()}
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $inputImage)
        }
            


        
    }
    func loadImage() {
        guard var inputImage = inputImage else { return }
        image = Image(uiImage: inputImage)
    }
}
    


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPhone 13 Pro")
    }
}

extension String {
    subscript (index: Int) -> Character {
        let charIndex = self.index(self.startIndex, offsetBy: index)
        return self[charIndex]
    }

    subscript (range: Range<Int>) -> Substring {
        let startIndex = self.index(self.startIndex, offsetBy: range.startIndex)
        let stopIndex = self.index(self.startIndex, offsetBy: range.startIndex + range.count)
        return self[startIndex..<stopIndex]
    }

}
