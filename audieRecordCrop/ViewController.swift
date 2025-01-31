//
//  ViewController.swift
//  audieRecordCrop
//
//  Created by Nikhil Gangurde on 30/01/25.
//

import UIKit
import IQAudioRecorderController
import MediaPlayer
import AVFoundation
import AVKit

class ViewController: UITableViewController, IQAudioRecorderViewControllerDelegate, IQAudioCropperViewControllerDelegate, UITextFieldDelegate {
    
    @IBOutlet weak var buttonPlayAudio: UIBarButtonItem!
    @IBOutlet weak var barButtonCrop: UIBarButtonItem!
    @IBOutlet weak var textFieldTitle: UITextField!
    @IBOutlet weak var switchDarkUserInterface: UISwitch!
    @IBOutlet weak var switchAllowsCropping: UISwitch!
    @IBOutlet weak var switchBlurEnabled: UISwitch!
    @IBOutlet weak var labelMaxDuration: UILabel!
    @IBOutlet weak var stepperMaxDuration: UIStepper!
    
    @IBOutlet weak var normalTintColorTextField: UITextField!
    @IBOutlet weak var highlightedTintColorTextField: UITextField!
    
    private var audioFilePath: String?
    private var normalTintColor: UIColor?
    private var highlightedTintColor: UIColor?
    private var audioFilePaths: [URL] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        buttonPlayAudio.isEnabled = false
        barButtonCrop.isEnabled = false
        
        // Toolbar for color picker text fields
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneAction))
        toolbar.items = [flexItem, doneItem]
        
        normalTintColorTextField.inputAccessoryView = toolbar
        highlightedTintColorTextField.inputAccessoryView = toolbar
    }
    
    @IBAction func switchThemeAction(_ sender: UISwitch) {
        let style: UIBarStyle = sender.isOn ? .black : .default
        navigationController?.navigationBar.barStyle = style
        navigationController?.toolbar.barStyle = style
    }
    
    @IBAction func stepperDurationChanged(_ sender: UIStepper) {
        labelMaxDuration.text = "\(Int(sender.value))"
    }
    
    // MARK: - Record Audio
    @IBAction func recordAction(_ sender: UIBarButtonItem) {
        let controller = IQAudioRecorderViewController()
        controller.delegate = self
        controller.title = textFieldTitle.text
        controller.maximumRecordDuration = stepperMaxDuration.value
        controller.allowCropping = switchAllowsCropping.isOn
        controller.normalTintColor = normalTintColor
        controller.highlightedTintColor = highlightedTintColor
        controller.barStyle = switchDarkUserInterface.isOn ? .black : .default
        
        if switchBlurEnabled.isOn {
            presentBlurredAudioRecorderViewControllerAnimated(controller)
        } else {
            present(controller, animated: true, completion: nil)
        }
    }
    
    func mergeAudioFiles() {
        guard audioFilePaths.count > 1 else {
            audioFilePath = audioFilePaths.first?.path // If only one file, use it directly
            return
        }

        let composition = AVMutableComposition()
        
        for audioURL in audioFilePaths {
            let asset = AVURLAsset(url: audioURL)
            guard let track = asset.tracks(withMediaType: .audio).first else { continue }
            
            let trackComposition = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            do {
                try trackComposition?.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration),
                                                      of: track,
                                                      at: composition.duration)
            } catch {
                print("Error merging audio: \(error.localizedDescription)")
            }
        }

        // Export the merged audio
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("mergedAudio.m4a")
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A)
        exporter?.outputURL = outputURL
        exporter?.outputFileType = .m4a
        exporter?.exportAsynchronously {
            DispatchQueue.main.async {
                if exporter?.status == .completed {
                    self.audioFilePath = outputURL.path
                    self.audioFilePaths = [outputURL] // Keep only the merged file
                    print("Merged audio saved at: \(outputURL.path)")
                } else {
                    print("Failed to merge audio: \(exporter?.error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    func audioRecorderController(_ controller: IQAudioRecorderViewController, didFinishWithAudioAtPath filePath: String) {
        let recordedURL = URL(fileURLWithPath: filePath)
        audioFilePaths.append(recordedURL) // Append instead of replacing
        mergeAudioFiles() // Merge all files into a single audio file
        buttonPlayAudio.isEnabled = true
        barButtonCrop.isEnabled = true
        controller.dismiss(animated: true, completion: nil)
    }
    
//    func audioRecorderController(_ controller: IQAudioRecorderViewController, didFinishWithAudioAtPath filePath: String) {
//        audioFilePath = filePath
//        buttonPlayAudio.isEnabled = true
//        barButtonCrop.isEnabled = true
//        controller.dismiss(animated: true, completion: nil)
//    }
    
    func audioRecorderControllerDidCancel(_ controller: IQAudioRecorderViewController) {
        buttonPlayAudio.isEnabled = false
        barButtonCrop.isEnabled = false
        controller.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Play Audio
//    @IBAction func playAction(_ sender: UIBarButtonItem) {
//        guard let audioFilePath = audioFilePath else { return }
//
//        // Create a URL from the file path
//        let audioURL = URL(fileURLWithPath: audioFilePath)
//
//        // Initialize the AVPlayer with the audio URL
//        let player = AVPlayer(url: audioURL)
//
//        // Create an AVPlayerViewController instance to display the player
//        let playerViewController = AVPlayerViewController()
//        playerViewController.player = player
//
//        // Ensure the audio session is active for playback
//        do {
//            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
//            try AVAudioSession.sharedInstance().setActive(true)
//        } catch {
//            print("Audio session setup failed: \(error.localizedDescription)")
//        }
//
//        // Present the AVPlayerViewController
//        present(playerViewController, animated: true) {
//            // Start playing the audio when the view is presented
//            player.play()
//        }
//
//    }
    
    @IBAction func playAction(_ sender: UIBarButtonItem) {
        guard let finalAudioPath = audioFilePath else { return }
        let audioURL = URL(fileURLWithPath: finalAudioPath)

        let player = AVPlayer(url: audioURL)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error.localizedDescription)")
        }
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("Audio file not found at: \(audioURL.path)")
            return
        }
        present(playerViewController, animated: true) {
            player.play()
        }
    }
    
    // MARK: - Crop Audio
//    @IBAction func cropAction(_ sender: UIBarButtonItem) {
//        guard let audioFilePath = audioFilePath else { return }
//        
//        let controller = IQAudioCropperViewController(filePath: audioFilePath)
//        controller.delegate = self
//        controller.title = "Crop"
//        controller.normalTintColor = normalTintColor
//        controller.highlightedTintColor = highlightedTintColor
//        controller.barStyle = switchDarkUserInterface.isOn ? .black : .default
//        
//        if switchBlurEnabled.isOn {
//            presentBlurredAudioCropperViewControllerAnimated(controller)
//        } else {
//            present(controller, animated: true, completion: nil)
//        }
//    }
    
    @IBAction func cropAction(_ sender: UIBarButtonItem) {
        guard let finalAudioPath = audioFilePath else { return }
        
        let controller = IQAudioCropperViewController(filePath: finalAudioPath)
        controller.delegate = self
        present(controller, animated: true, completion: nil)
    }
    
    func audioCropperController(_ controller: IQAudioCropperViewController, didFinishWithAudioAtPath filePath: String) {
        let croppedURL = URL(fileURLWithPath: filePath)
        audioFilePaths = [croppedURL] // Replace with cropped audio (reset)
        controller.dismiss(animated: true, completion: nil)
    }
    
    // Uncomment Because working example
//    func audioCropperController(_ controller: IQAudioCropperViewController, didFinishWithAudioAtPath filePath: String) {
//        audioFilePath = filePath
//        controller.dismiss(animated: true, completion: nil)
//    }
    
    func audioCropperControllerDidCancel(_ controller: IQAudioCropperViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - TextField Handling
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @objc func doneAction() {
        view.endEditing(true)
    }
}
