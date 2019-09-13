//
//  ViewController.swift
//  BLE_Peripheral
//
//  Created by Lo Fang Chou on 2019/8/20.
//  Copyright © 2019 JStudio. All rights reserved.
//

import Cocoa
import CoreBluetooth

class ViewController: NSViewController, CBPeripheralManagerDelegate {

    @IBOutlet weak var textField: NSTextField!
    
    @IBOutlet var textView: NSTextView!
    
    var timer = Timer()

    //@IBOutlet weak var textView: NSTextView!
    
    @IBAction func sendClick(_ sender: Any) {
        let string = textField.stringValue
        if textView.string.isEmpty {
            textView.string = string
        } else {
            textView.string = textView.string + "\n" + string
        }
        
        do {
            let data = string.data(using: .utf8)
            try sendData(data!, uuidString: C001_CHARACTERISTIC)
        } catch {
            print(error)
        }
    }
    
    enum SendDataError: Error {
        case CharacteristicNotFound
    }
    
    //GATT
    let A001_SERVICE = "A001"
    let C001_CHARACTERISTIC = "C001"  //Notify Item Data (JSON-Formatted) Service
    let B001_CHARACTERISTIC = "B001"  //Data Sampling Rate Write Service
    
    var samplingRate = "100"
    
    var peripheralManager : CBPeripheralManager?
    var charDictionary = [String: CBMutableCharacteristic]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let queue = DispatchQueue.global()
        peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else {
            print(peripheral.state.rawValue)
            return
        }
        
        var service: CBMutableService
        var characteristic: CBMutableCharacteristic
        var charArray = [CBCharacteristic]()
        
        // Start to setup service and characteristic
        service = CBMutableService(type: CBUUID(string: A001_SERVICE), primary: true)

        // Register the data item characteristic server
        characteristic = CBMutableCharacteristic(
            type: CBUUID(string: C001_CHARACTERISTIC),
            properties: [.notifyEncryptionRequired, .write, .read],
            value: nil,
            permissions: [.writeEncryptionRequired, .readEncryptionRequired]
        )
        charDictionary[C001_CHARACTERISTIC] = characteristic
        charArray.append(characteristic)

        // Register the data sampling rate characteristic server
        characteristic = CBMutableCharacteristic(
            type: CBUUID(string: B001_CHARACTERISTIC),
            properties: [.write, .read],
            value: nil,
            permissions: [.writeEncryptionRequired, .readEncryptionRequired]
        )
        charDictionary[B001_CHARACTERISTIC] = characteristic
        charArray.append(characteristic)

        service.characteristics = charArray
        peripheralManager?.add(service)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else {
            //print("ERROR:{\(#file, #function)}\n")
            print(error!.localizedDescription)
            return
        }
        
        let deviceName = "BLE001"
        peripheral.startAdvertising(
            [CBAdvertisementDataServiceUUIDsKey: [service.uuid],
             CBAdvertisementDataLocalNameKey: deviceName]
        )
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("Start Advertising...")
    }
    
    // Send data to Central
    func sendData(_ data: Data, uuidString: String) throws {
        guard let characteristic = charDictionary[uuidString] else {
            // No such the uuid
            throw SendDataError.CharacteristicNotFound
        }
        
        peripheralManager?.updateValue(
            data,
            for: characteristic,
            onSubscribedCentrals: nil
        )
    }
    
    func sendDataByTimer() {
        self.timer.invalidate()
        let sampling_rate = Double(self.samplingRate)
        //self.timer = Timer.scheduledTimer(timeInterval: sampling_rate!, target: self, selector: #selector(self.continueSendData), userInfo: nil, repeats: true)
        self.timer = Timer.scheduledTimer(withTimeInterval: sampling_rate!, repeats: true) { (timer) in
            self.continueSendData()
        }
    }
    
    func continueSendData() {
        do {
            var tmp = [BLEReceivedDataValue]()
            var item = BLEReceivedDataValue()
            item.DataName = "Data001"
            item.DataValue = String(Int.random(in: 5...50))
            tmp.append(item)
            
            item.DataName = "Data002"
            item.DataValue = String(Int.random(in: 60...100))
            tmp.append(item)

            item.DataName = "Data003"
            item.DataValue = String(Int.random(in: 100...180))
            tmp.append(item)
            
            let jsonEncoder = JSONEncoder()
            let data = try jsonEncoder.encode(tmp)
            let json_string = String(data: data, encoding: .utf8)!

            //let data = "Test123".data(using: .utf8)
            //try sendData(data!, uuidString: C001_CHARACTERISTIC)
            try sendData(json_string.data(using: .utf8)!, uuidString: C001_CHARACTERISTIC)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    @IBAction func stopSendData(_ sender: Any) {
        self.timer.invalidate()
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        if peripheral.isAdvertising {
            peripheral.stopAdvertising()
            print("Stop Advertising")
        }
        
        if characteristic.uuid.uuidString == C001_CHARACTERISTIC {
            print("Subscride C001")
            /*
            do {
                let data = "Hello Central".data(using: .utf8)
                try sendData(data!, uuidString: C001_CHARACTERISTIC)
            } catch {
                print(error)
            }*/
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        if characteristic.uuid.uuidString == C001_CHARACTERISTIC {
            print("Unsubscribe C001")
        }
    }

    // Central write data to Peripheral
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let at = requests.first else {
            return
        }
        
        guard let data = at.value else {
            return
        }
        
        if at.characteristic.uuid.uuidString == C001_CHARACTERISTIC {
            peripheral.respond(to: at, withResult: .success)
            let string = "> " + String(data: data, encoding: .utf8)!
            print(string)
            
            DispatchQueue.main.async {
                if self.textView.string.isEmpty {
                    self.textView.string = string
                } else {
                    self.textView.string = self.textView.string + "\n" + string
                }
            }
        }
 
        if at.characteristic.uuid.uuidString == B001_CHARACTERISTIC {
            peripheral.respond(to: at, withResult: .success)
            self.samplingRate = String(data: data, encoding: .utf8)!
            print("Received Sampling Rate data: \(self.samplingRate)")
            //sendDataByTimer()

            DispatchQueue.main.async {
                if self.textView.string.isEmpty {
                    self.textView.string = "Received Sampling Rate data: \(self.samplingRate)"
                } else {
                    self.textView.string = self.textView.string + "\n" + "Received Sampling Rate data: \(self.samplingRate)"
                }
                
                self.sendDataByTimer()
            }
        }
    }
    
    // Central read data from Peripheral
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        request.value = nil
        
        if request.characteristic.uuid.uuidString == C001_CHARACTERISTIC {
            let data = "What do you want?".data(using: .utf8)
            request.value = data
        }
        
        peripheral.respond(to: request, withResult: .success)
    }

}

