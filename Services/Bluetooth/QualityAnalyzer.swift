import Foundation
import Accelerate
import Combine

class QualityAnalyzer: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var ch1ConnectionStatus: (connected: Bool, quality: Double) = (false, 0.0)
    @Published var ch2ConnectionStatus: (connected: Bool, quality: Double) = (false, 0.0)
    
    // MARK: - Private Properties
    private var leadOffAnalysisTimer: Timer?
    private var qualityAnalysisTimer: Timer?
    
    // MARK: - Initialization
    override init() {
        super.init()
    }
    
    // MARK: - Public Quality Analysis Methods
    func analyzeSignalQuality(channel1: [Int32], channel2: [Int32]) -> (ch1: SignalQualityMetrics?, ch2: SignalQualityMetrics?) {
        guard channel1.count >= Int(BtConst.SAMPLE_RATE * 2) else { return (nil, nil) }
        
        let ch1Data = channel1.suffix(Int(BtConst.SAMPLE_RATE * 5)).map { Double($0) }
        let ch2Data = channel2.suffix(Int(BtConst.SAMPLE_RATE * 5)).map { Double($0) }
        
        let ch1Metrics = SignalProcessing.calculateQualityMetrics(for: ch1Data)
        let ch2Metrics = SignalProcessing.calculateQualityMetrics(for: ch2Data)
        
        return (ch1Metrics, ch2Metrics)
    }
    
    func startLeadOffAnalysis(channel1: [Int32], channel2: [Int32]) {
        leadOffAnalysisTimer?.invalidate()
        leadOffAnalysisTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.performLeadOffAnalysis(ch1Data: channel1, ch2Data: channel2)
        }
    }
    
    func stopLeadOffAnalysis() {
        leadOffAnalysisTimer?.invalidate()
        leadOffAnalysisTimer = nil
    }
    
    func startQualityAnalysis(channel1: [Int32], channel2: [Int32]) {
        qualityAnalysisTimer?.invalidate()
        qualityAnalysisTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            let (ch1Metrics, ch2Metrics) = self?.analyzeSignalQuality(channel1: channel1, channel2: channel2) ?? (nil, nil)
            
            if let ch1 = ch1Metrics {
                print("CH1 Quality - DR: \(ch1.dynamicRange.db)dB, SNR: \(ch1.snr.totalSNRdB)dB")
            }
            if let ch2 = ch2Metrics {
                print("CH2 Quality - DR: \(ch2.dynamicRange.db)dB, SNR: \(ch2.snr.totalSNRdB)dB")
            }
        }
    }
    
    func stopQualityAnalysis() {
        qualityAnalysisTimer?.invalidate()
        qualityAnalysisTimer = nil
    }
    
    // MARK: - Lead-Off Detection (from SignalProcessing)
    private func performLeadOffAnalysis(ch1Data: [Int32], ch2Data: [Int32]) {
        let (ch1Connected, ch2Connected, ch1Quality, ch2Quality) = SignalProcessing.processLeadoffDetection(
            ch1Data: ch1Data,
            ch2Data: ch2Data
        )
        
        DispatchQueue.main.async {
            self.ch1ConnectionStatus = (ch1Connected, ch1Quality)
            self.ch2ConnectionStatus = (ch2Connected, ch2Quality)
        }
    }
    
    // MARK: - Cleanup
    func stopAllAnalysis() {
        stopLeadOffAnalysis()
        stopQualityAnalysis()
    }
    
    func resetConnectionStatus() {
        DispatchQueue.main.async {
            self.ch1ConnectionStatus = (false, 0.0)
            self.ch2ConnectionStatus = (false, 0.0)
        }
    }
}
