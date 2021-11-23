//
//  ViewController.swift
//  One-Healthy-Leap
//
//  Created by Doyoon Kim on 11/3/21.
//

import UIKit
import CoreBluetooth
import Foundation
import Charts

struct CBUUIDs{

    static let kBLEService_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
    static let kBLE_Characteristic_uuid_Tx = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
    static let kBLE_Characteristic_uuid_Rx = "6e400003-b5a3-f393-e0a9-e50e24dcca9e" // Identify bluetooth connection (device)

    static let BLEService_UUID = CBUUID(string: kBLEService_UUID)
    static let BLE_Characteristic_uuid_Tx = CBUUID(string: kBLE_Characteristic_uuid_Tx)//(Property = Write without response)
    static let BLE_Characteristic_uuid_Rx = CBUUID(string: kBLE_Characteristic_uuid_Rx)// (Property = Read/Notify)

}

class ViewController: UIViewController {

    @IBOutlet weak var stepsAchievementLabel: UILabel!
    @IBOutlet weak var achievementPercentageLabel: UILabel!
    
    @IBOutlet weak var goalSettingField: UITextField!
    @IBOutlet weak var dailyGoalLabel: UILabel!
    
    
    // Charts
    @IBOutlet weak var maineLineChartView: LineChartView!
    @IBOutlet weak var mainPieChartView: PieChartView!
    
    
    // Add CBCentralManager instance.
    var centralManager: CBCentralManager!
    
    private var bluefruitPeripheral: CBPeripheral!
    
    private var txCharacteristic: CBCharacteristic!
    private var rxCharacteristic: CBCharacteristic!
    
    private var dailyGoal: Int = 500 // test value.
    private var walked = 0
    private var dataSet: Array<Int> = [0]
    
    //private var receivedData
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        dailyGoalLabel.text = String(dailyGoal)
        achievementPercentageLabel.text = "0 %"
        stepsAchievementLabel.text = "0 / \(dailyGoal)"
        // initialize graph
        graphLineChart(dataArr: dataSet)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.goalSettingField.resignFirstResponder()
    }
    
    // Example function that reads data over Bluetooth connection.
    
    func startScanning() -> Void {
      // Start Scanning (Scanning Bluetooth Peripherals
      centralManager?.scanForPeripherals(withServices: [CBUUIDs.BLEService_UUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,advertisementData: [String : Any], rssi RSSI: NSNumber) {

        bluefruitPeripheral = peripheral
        bluefruitPeripheral.delegate = self

        print("Peripheral Discovered: \(peripheral)")
        print("Peripheral name: \(peripheral.name)")
        print ("Advertisement Data : \(advertisementData)")
        
        centralManager?.connect(bluefruitPeripheral!, options: nil)

    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
       bluefruitPeripheral.discoverServices([CBUUIDs.BLEService_UUID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            print("*******************************************************")

            if ((error) != nil) {
                print("Error discovering services: \(error!.localizedDescription)")
                return
            }
            guard let services = peripheral.services else {
                return
            }
            //We need to discover the all characteristic
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
            print("Discovered Services: \(services)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
           
               guard let characteristics = service.characteristics else {
              return
          }

          print("Found \(characteristics.count) characteristics.")

          for characteristic in characteristics {

            if characteristic.uuid.isEqual(CBUUIDs.BLE_Characteristic_uuid_Rx)  {

              rxCharacteristic = characteristic

              peripheral.setNotifyValue(true, for: rxCharacteristic!)
              peripheral.readValue(for: characteristic)

              print("RX Characteristic: \(rxCharacteristic.uuid)")
            }

            if characteristic.uuid.isEqual(CBUUIDs.BLE_Characteristic_uuid_Tx){
              
              txCharacteristic = characteristic
              
              print("TX Characteristic: \(txCharacteristic.uuid)")
            }
          }
    }
    
    func disconnectFromDevice () {
        if bluefruitPeripheral != nil {
        centralManager?.cancelPeripheralConnection(bluefruitPeripheral!)
        }
     }
    
    // READ DATA OVER THE BLUETOOTH.
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        var testString: String = "0%"
        
          var characteristicASCIIValue = NSString()

          guard characteristic == rxCharacteristic,

          let characteristicValue = characteristic.value,
          let ASCIIstring = NSString(data: characteristicValue, encoding: String.Encoding.utf8.rawValue) else { return }
          // Line above is for reading the data over bluetooth and saving it as a string.
        
          characteristicASCIIValue = ASCIIstring
        
         testString = characteristicASCIIValue as String
        //receivedData.append(recievedValues)
        //stepsAchievementLabel.text = "\(testString) / \((String(dailyGoal)))"
        let receivedValue = testString.filter {!$0.isWhitespace}
        let temp: Int = Int(receivedValue) ?? 0
        dataSet.append(temp)
        
        walked = walked + Int(temp)
        
        print(dataSet)
        
        graphLineChart(dataArr: dataSet)
        
        print(String(walked))
          print("Value Recieved: \((characteristicASCIIValue as String))")
        updateGUI()
    }
    
    // Write value to Peripheral
    func writeOutgoingValue(data: String){
          
        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue)
        
        if let bluefruitPeripheral = bluefruitPeripheral {
              
          if let txCharacteristic = txCharacteristic {
                  
            bluefruitPeripheral.writeValue(valueString!, for: txCharacteristic, type: CBCharacteristicWriteType.withResponse)
              }
          }
      }
    
    func graphLineChart(dataArr: [Int]) {
        
            // View size configuration: Make View have width and height both equal to width of screen
            maineLineChartView.frame = CGRect(x:0, y: 0, width: self.view.frame.width, height: self.view.frame.height / 2)
            
            // Make View center to be horizontally centered, but offset towards the top of the screen.
            maineLineChartView.center.x = self.view.center.x
            maineLineChartView.center.y = self.view.center.y - 240       // 240?
            
            // Initialize graph with empty dataset.
            var entries = [ChartDataEntry]()
            
            // For each element, set x and y coordinates in a data chart entry, and add to the entries arr
            // <Collection>.enumerated():
            //  Returns a sequence of pairs (n, x), where n represents a consecutive integer starting at zero and x represents an element of the sequence.
            for (index, element) in dataArr.enumerated() {
                let value = ChartDataEntry(x: Double(index), y: Double(element))
                entries.append(value)
            }
            
            // Use the entries object and a label string to make a LineChartDataSet Obj.
            let dataSet = LineChartDataSet(entries: entries, label: "Line Chart Example")
            
            // Customize graph setting.
            dataSet.colors = ChartColorTemplates.joyful()
            
            // Make Obj that will be added to the chart and set it to the variable in the Storyboard
            let lineChartData = LineChartData(dataSet: dataSet)
            maineLineChartView.data = lineChartData
            
            // Add setting for the chartView
            maineLineChartView.chartDescription?.text = "Pi Values"
            
            /*
             Animations will be removed to enhance visability
             // Animations
             maineLineChartView.animate(xAxisDuration: 2.0, yAxisDuration: 2.0, easingOption: .linear)
             */
                                        
        }
    
    func graphPiChart(cumulativeSteps: Int, goal: Int) {
            
        var dataArr: Array<Int> = []
        dataArr.append(cumulativeSteps)
        dataArr.append(goal - cumulativeSteps)
        
            // View size configuration: Make View have width and height both equal to width of screen
            mainPieChartView.frame = CGRect(x:0, y: 0, width: self.view.frame.width, height: self.view.frame.height / 2)
            
            // Make View center to be horizontally centered, but offset towards the top of the screen.
            mainPieChartView.center.x = self.view.center.x
            mainPieChartView.center.y = self.view.center.y - 240       // 240?
            
            // Initialize graph with empty dataset.
            var entries = [ChartDataEntry]()
            
            // For each element, set x and y coordinates in a data chart entry, and add to the entries arr
            // <Collection>.enumerated():
            //  Returns a sequence of pairs (n, x), where n represents a consecutive integer starting at zero and x represents an element of the sequence.
            for (index, element) in dataArr.enumerated() {
                let value = ChartDataEntry(x: Double(index), y: Double(element))
                entries.append(value)
            }
            
            // Use the entries object and a label string to make a LineChartDataSet Obj.
            let dataSet = PieChartDataSet(entries: entries, label: "Line Chart Example")
            
            // Customize graph setting.
            dataSet.colors = ChartColorTemplates.joyful()
            
            // Make Obj that will be added to the chart and set it to the variable in the Storyboard
            let PieChartData = PieChartData(dataSet: dataSet)
            mainPieChartView.data = PieChartData
            
            // Add setting for the chartView
            mainPieChartView.chartDescription?.text = "Pi Values"
            
            
        }
    
    func updateGUI() {
        var cumulativeSteps: Int = 0
        var achievementPercentage: Double = 0
        for element in dataSet {
            cumulativeSteps = cumulativeSteps + element
        }
        achievementPercentage = (Double(cumulativeSteps) / Double(dailyGoal)) * 100
        stepsAchievementLabel.text = "\(String(cumulativeSteps)) / \(String(dailyGoal))"
        achievementPercentageLabel.text = "\(String(achievementPercentage)) %"
        graphPiChart(cumulativeSteps: cumulativeSteps, goal: dailyGoal)
    }
    
    @IBAction func newGoalSet(_ sender: Any) {
        var stringValue: String = goalSettingField.text ?? "0"
        var newGoalInserted: Int = Int(stringValue)!
        
        if (newGoalInserted != 0) {
            dailyGoal = newGoalInserted
        }
        dailyGoalLabel.text = String(newGoalInserted)
        updateGUI()
        
    }
    

}

extension ViewController: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
         switch central.state {
              case .poweredOff:
                  print("Is Powered Off.")
              case .poweredOn:
                  print("Is Powered On.")
                  startScanning()
              case .unsupported:
                  print("Is Unsupported.")
              case .unauthorized:
              print("Is Unauthorized.")
              case .unknown:
                  print("Unknown")
              case .resetting:
                  print("Resetting")
              @unknown default:
                print("Error")
              }
      }
    
}

extension ViewController: CBPeripheralDelegate {

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    switch peripheral.state {
    case .poweredOn:
        print("Peripheral Is Powered On.")
    case .unsupported:
        print("Peripheral Is Unsupported.")
    case .unauthorized:
    print("Peripheral Is Unauthorized.")
    case .unknown:
        print("Peripheral Unknown")
    case .resetting:
        print("Peripheral Resetting")
    case .poweredOff:
      print("Peripheral Is Powered Off.")
    @unknown default:
      print("Error")
    }
  }
}


