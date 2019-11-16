import Flutter
import UIKit
import ReplayKit
import Photos

public class SwiftFlutterScreenRecordingPlugin: NSObject, FlutterPlugin {
    
let recorder = RPScreenRecorder.shared()

var fileURL : URL?
var assetWriter : AVAssetWriter!
var videoInput : AVAssetWriterInput!
var audioInput:AVAssetWriterInput!
    
let screenSize = UIScreen.main.bounds
       var startSesstion = false
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_screen_recording", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterScreenRecordingPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

    print(call.method)
    
    if(call.method == "getPlatformVersion"){
        result("iOS " + UIDevice.current.systemVersion)

    }else if(call.method == "startRecordScreen"){
         startRecording()

    }else if(call.method == "stopRecordScreen"){
         stopRecording()

    }
  }


    @objc func startRecording() {
        //Use ReplayKit to record the screen
            RPScreenRecorder.shared().isMicrophoneEnabled = true;
        let videoName = String(Date().timeIntervalSince1970) + ".mp4"
        
        //Create the file path to write to
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        self.fileURL = URL(fileURLWithPath: documentsPath.appendingPathComponent(videoName))

        //Check the file does not already exist by deleting it if it does
        do {
            try FileManager.default.removeItem(at:  self.fileURL!)
        } catch {}


        do {
            assetWriter = try! AVAssetWriter(outputURL: self.fileURL!, fileType:
            AVFileType.mp4)
        } catch let writerError as NSError {
            print("Error opening video file", writerError);
            assetWriter = nil;
            return;
        }

        
        
        
        //Create the video settings
        if #available(iOS 11.0, *) {
            
              let videoOutputSettings: Dictionary<String, Any> = [
                            AVVideoCodecKey : AVVideoCodecType.h264,
                            AVVideoWidthKey : UIScreen.main.bounds.size.width,
                            AVVideoHeightKey : UIScreen.main.bounds.size.height,
                        ];

            var channelLayout = AudioChannelLayout()
            channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono

              let audioOutputSettings: [String : Any] = [
                                          AVFormatIDKey : kAudioFormatMPEG4AAC,
                                          AVSampleRateKey : 44100,
                                          AVEncoderBitRateKey : 64000,
                                          AVNumberOfChannelsKey: 1]

            videoInput  = AVAssetWriterInput(mediaType: AVMediaType.video,outputSettings: videoOutputSettings)
            audioInput  = AVAssetWriterInput(mediaType: AVMediaType.audio,outputSettings: audioOutputSettings)
            
            videoInput?.expectsMediaDataInRealTime = true;
              audioInput?.expectsMediaDataInRealTime = true;
            
            assetWriter!.add(videoInput)
            assetWriter!.add(audioInput)

        }
        
        
        //Tell the screen recorder to start capturing and to call the handler when it has a
        //sample 
        if #available(iOS 11.0, *) {

                        RPScreenRecorder.shared().startCapture(handler: { (sample, bufferType, error) in


                            if CMSampleBufferDataIsReady(sample)
                            {

                                DispatchQueue.main.async { [weak self] in
                                    if self?.assetWriter.status == AVAssetWriterStatus.unknown {
                                        print("AVAssetWriterStatus.unknown")
                                        if !(self?.assetWriter.startWriting())! {
                                            return
                                        }
                                        
                                        self?.assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sample))
                                        self?.startSesstion = true
                                    }

                                }
                                if self.assetWriter.status == AVAssetWriterStatus.failed {

                                    print("Error occured, status = \(String(describing: self.assetWriter.status.rawValue)), \(String(describing: self.assetWriter.error!.localizedDescription)) \(String(describing: self.assetWriter.error))")

                                    return
                                }
                                if (bufferType == .video)
                                {
                                    if(self.videoInput.isReadyForMoreMediaData) {
                                        self.videoInput.append(sample)
                                         print("vid Buffer Came")
                                    }
                                }
                                if (bufferType == .audioMic)
                                {
                                    if self.audioInput.isReadyForMoreMediaData
                                    {
                                        print("Audio Buffer Came")
                                        self.audioInput.append(sample)
                                    }
                                }
                            }
                        }) { (error) in
                            
            //                debugPrint(error)
                        }
                    
        } else {
            //Fallback on earlier versions
        }
    }

    
    
    
    
    
    
    
    
    
    

    
        @objc func stopRecording() {
            //Stop Recording the screen
            if #available(iOS 11.0, *) {
                RPScreenRecorder.shared().stopCapture( handler: { (error) in
                    print("stopping recording");
                })
            } else {
              //  Fallback on earlier versions
            }
    
            self.videoInput.markAsFinished()
            self.audioInput.markAsFinished()
            self.assetWriter?.finishWriting {
                print("finished writing video");
    
                //Now save the video
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.fileURL!)
                }) { saved, error in
                    if saved {
                        let alertController = UIAlertController(title: "Your video was successfully saved", message: nil, preferredStyle: .alert)
                        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alertController.addAction(defaultAction)
                        //self.present(alertController, animated: true, completion: nil)
                    }
                    if error != nil {
                        print("Video did not save for some reason", error.debugDescription);
                        debugPrint(error?.localizedDescription ?? "error is nil");
                    }
                }
            }
    }
    
    
  
