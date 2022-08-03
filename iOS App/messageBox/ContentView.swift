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

public extension UIImage {

    var pixelWidth: Int {
        return cgImage?.width ?? 0
    }

    var pixelHeight: Int {
        return cgImage?.height ?? 0
    }

    func pixelColor(x: Int, y: Int) -> UIColor {
        assert(
            0..<pixelWidth ~= x && 0..<pixelHeight ~= y,
            "Pixel coordinates are out of bounds")

        guard
            let cgImage = cgImage,
            let data = cgImage.dataProvider?.data,
            let dataPtr = CFDataGetBytePtr(data),
            let colorSpaceModel = cgImage.colorSpace?.model,
            let componentLayout = cgImage.bitmapInfo.componentLayout
        else {
            assertionFailure("Could not get a pixel of an image")
            return .clear
        }

        assert(
            colorSpaceModel == .rgb,
            "The only supported color space model is RGB")
        assert(
            cgImage.bitsPerPixel == 32 || cgImage.bitsPerPixel == 24,
            "A pixel is expected to be either 4 or 3 bytes in size")

        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel/8
        let pixelOffset = y*bytesPerRow + x*bytesPerPixel

        if componentLayout.count == 4 {
            let components = (
                dataPtr[pixelOffset + 0],
                dataPtr[pixelOffset + 1],
                dataPtr[pixelOffset + 2],
                dataPtr[pixelOffset + 3]
            )

            var alpha: UInt8 = 0
            var red: UInt8 = 0
            var green: UInt8 = 0
            var blue: UInt8 = 0

            switch componentLayout {
            case .bgra:
                alpha = components.3
                red = components.2
                green = components.1
                blue = components.0
            case .abgr:
                alpha = components.0
                red = components.3
                green = components.2
                blue = components.1
            case .argb:
                alpha = components.0
                red = components.1
                green = components.2
                blue = components.3
            case .rgba:
                alpha = components.3
                red = components.0
                green = components.1
                blue = components.2
            default:
                return .clear
            }

            // If chroma components are premultiplied by alpha and the alpha is `0`,
            // keep the chroma components to their current values.
            if cgImage.bitmapInfo.chromaIsPremultipliedByAlpha && alpha != 0 {
                let invUnitAlpha = 255/CGFloat(alpha)
                red = UInt8((CGFloat(red)*invUnitAlpha).rounded())
                green = UInt8((CGFloat(green)*invUnitAlpha).rounded())
                blue = UInt8((CGFloat(blue)*invUnitAlpha).rounded())
            }

            return .init(red: red, green: green, blue: blue, alpha: alpha)

        } else if componentLayout.count == 3 {
            let components = (
                dataPtr[pixelOffset + 0],
                dataPtr[pixelOffset + 1],
                dataPtr[pixelOffset + 2]
            )

            var red: UInt8 = 0
            var green: UInt8 = 0
            var blue: UInt8 = 0

            switch componentLayout {
            case .bgr:
                red = components.2
                green = components.1
                blue = components.0
            case .rgb:
                red = components.0
                green = components.1
                blue = components.2
            default:
                return .clear
            }

            return .init(red: red, green: green, blue: blue, alpha: UInt8(255))

        } else {
            assertionFailure("Unsupported number of pixel components")
            return .clear
        }
    }

}

public extension UIColor {

    convenience init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        self.init(
            red: CGFloat(red)/255,
            green: CGFloat(green)/255,
            blue: CGFloat(blue)/255,
            alpha: CGFloat(alpha)/255)
    }

}

public extension CGBitmapInfo {

    enum ComponentLayout {

        case bgra
        case abgr
        case argb
        case rgba
        case bgr
        case rgb

        var count: Int {
            switch self {
            case .bgr, .rgb: return 3
            default: return 4
            }
        }

    }

    var componentLayout: ComponentLayout? {
        guard let alphaInfo = CGImageAlphaInfo(rawValue: rawValue & Self.alphaInfoMask.rawValue) else { return nil }
        let isLittleEndian = contains(.byteOrder32Little)

        if alphaInfo == .none {
            return isLittleEndian ? .bgr : .rgb
        }
        let alphaIsFirst = alphaInfo == .premultipliedFirst || alphaInfo == .first || alphaInfo == .noneSkipFirst

        if isLittleEndian {
            return alphaIsFirst ? .bgra : .abgr
        } else {
            return alphaIsFirst ? .argb : .rgba
        }
    }

    var chromaIsPremultipliedByAlpha: Bool {
        let alphaInfo = CGImageAlphaInfo(rawValue: rawValue & Self.alphaInfoMask.rawValue)
        return alphaInfo == .premultipliedFirst || alphaInfo == .premultipliedLast
    }

}

func resizeImage(image: UIImage, newWidth: CGFloat) -> UIImage {
    let newHeight = newWidth
    UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
    image.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return newImage!     }

func getArrayOfBytesFromImage(imageData:NSData) -> Array<UInt8>
{
  // the number of elements:
  let count = imageData.length / MemoryLayout<Int8>.size

  // create array of appropriate length:
  var bytes = [UInt8](repeating: 0, count: count)

  // copy bytes into array
  imageData.getBytes(&bytes, length:count * MemoryLayout<Int8>.size)

  var byteArray:Array = Array<UInt8>()

  for i in 0 ..< count {
    byteArray.append(bytes[i])
  }

  return byteArray
}


func runLengthEncoding(str: String) -> String {
    var out = ""
    let len = str.count
    var cnt = 0
    var i = 0
    while(i < len) {
        cnt = 1
        while(i < len - 1 && str[i] == str[i + 1]) {
            cnt += 1
            i += 1
        }
        
        out += String(str[i]) + ":" + String(cnt) + ","
        
        i += 1
    }
    return out
}


extension UIColor {
    var rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return (red, green, blue, alpha)
    }
}

func imgToBinaryArray(image: UIImage) -> String {
    var binArray = ""
    var color: UIColor
    var grayScale: Float
    var red = image.pixelColor(x: 0, y: 0).rgba
    for y in 0...127 {
        for x in 0...127 {
            color = image.pixelColor(x: x, y: y)
            red = color.rgba

            grayScale = Float(0.299 * red.red + 0.587 * red.green + 0.144 * red.blue)
            if(grayScale >= 0.5){
                binArray += "1"
            }
            else{
                binArray += "0"
            }
        }
    }
    return binArray
}


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
                    /*
                    AF.request(url, method: .post, parameters: data)
                        .authenticate(username: accountSID, password: authToken)
                        .responseJSON { response in
                            debugPrint(response)
                        }
                    */
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
