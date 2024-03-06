import AVFoundation
import Speech
import UIKit
import WebKit

class ViewController: UIViewController {
    var webView: WKWebView!
    let e = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()

    let request = SFSpeechAudioBufferRecognitionRequest()
    var recognitionTask: SFSpeechRecognitionTask?
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let path = Bundle.main.path(forResource: "ttt", ofType: "mp3") else {
            fatalError()
        }
        let speechURL = URL(filePath: path)
        var file: AVAudioFile!

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)

            let input = e.inputNode
            let mainMixer = e.mainMixerNode
            let output = e.outputNode
            
            e.attach(playerNode)
            
            request.requiresOnDeviceRecognition = true
            recognitionTask = speechRecognizer?.recognitionTask(with: request, resultHandler: { [weak self] result, error in
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    print("识别结果：\(transcription)")
                   
                } else if let error = error as? NSError {
                    print("识别错误：\(error)")
//                    if error.code == 301 {
//                        print("Recognition request was canceled")
//                    } else {
//
//                    }
                }
            })

            try input.setVoiceProcessingEnabled(true)
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { [weak self] buffer, _ in
//                self.request.append(buffer)
                print("dddd")
                
                self?.processAudioBuffer(buffer)
            }
            try file = AVAudioFile(forReading: speechURL)
            
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
            
            guard let speechBuffer = buffer else {
                fatalError()
            }
            file.framePosition = 0
            try file.read(into: speechBuffer)
            file.framePosition = 0
            
            // 建立音频处理链
//            e.connect(input, to: mainMixer, format: input.outputFormat(forBus: 1))
            e.connect(playerNode, to: mainMixer, format: speechBuffer.format)
//            e.connect(mainMixer, to: output, format: mainMixer.outputFormat(forBus: 0))
            
            e.prepare()
            
            try e.start()

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.playerNode.scheduleBuffer(speechBuffer, at: nil, options: .loops)
                self.playerNode.play()
            }
            
        } catch {
            fatalError("load file error\(error)")
        }
    }
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // 获取第一个声道的数据
        guard let floatData = buffer.floatChannelData?.pointee else {
            return
        }
        
        // 计算所有样本的平方和
        var sumOfSquares: Float = 0.0
        for i in 0 ..< Int(buffer.frameLength) {
            let sample = floatData[i]
            sumOfSquares += sample * sample
        }
        
        // 计算均值
        let mean = sumOfSquares / Float(buffer.frameLength)
        
        // 声压计算方式
        let referenceValue: Float = 20e-6 // 20微帕,转换为浮点数
        let volume = 20.0 * log10(mean / referenceValue)

        // 判断是否有人声
        if volume >= 45.0 && volume <= 100.0 {
            print("检测到人声")
        } else if volume > 100.0 {
            print("检测到较大的人声或噪音")
        } else {
            print("无人声")
        }
    }

    func playTest() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            // 设置音频会话类别为播放和录制，并且默认使用喇叭进行播放
            try audioSession.setCategory(.playAndRecord, options: .defaultToSpeaker)
            
            // 激活音频会话
            try audioSession.setActive(true)
        } catch {
            fatalError("Failed to initialize audio session: \(error.localizedDescription)")
        }

        // 创建 AVAudioEngine 实例

        // 将 AVAudioPlayerNode 添加到 AVAudioEngine 中
        e.attach(playerNode)

        // 连接 AVAudioPlayerNode 到 AVAudioEngine 的输出节点
        let mainMixerNode = e.mainMixerNode
        e.connect(playerNode, to: mainMixerNode, format: nil)

        // 准备音频文件
        guard let audioFileURL = Bundle.main.url(forResource: "ttt", withExtension: "mp3") else {
            fatalError("Audio file not found")
        }

        // 创建 AVAudioFile 实例
        do {
            let audioFile = try AVAudioFile(forReading: audioFileURL)
            
            // 安排播放
            playerNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
        } catch {
            fatalError("Failed to create audio file: \(error.localizedDescription)")
        }

        // 启动 AVAudioEngine
        do {
            try e.start()
        } catch {
            fatalError("Failed to start audio engine: \(error.localizedDescription)")
        }

        // 开始播放
        playerNode.play()
    }
}
