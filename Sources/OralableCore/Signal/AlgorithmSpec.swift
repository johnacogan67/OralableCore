//
//  AlgorithmSpec.swift
//  OralableCore
//
//  Created by John A Cogan on 16/02/2026.
//


//
//  AlgorithmSpec.swift
//  OralableCore
//
//  Created: January 29, 2026
//  Purpose: Algorithm constants matching Python reference
//  Reference: cursor_oralable/src/analysis/features.py
//
//  Location: Sources/OralableCore/Signal/AlgorithmSpec.swift
//

import Foundation

/// Algorithm specification constants for signal processing
/// Matches Python reference implementation (features.py)
public enum AlgorithmSpec {
    
    // MARK: - Sample Rates
    
    /// PPG sample rate in Hz
    public static let ppgSampleRate: Double = 50.0
    
    /// Accelerometer sample rate in Hz
    public static let accelSampleRate: Double = 100.0
    
    /// Sample interval for PPG in seconds (20ms)
    public static let ppgSampleInterval: Double = 1.0 / ppgSampleRate
    
    /// Sample interval for accelerometer in seconds (10ms)
    public static let accelSampleInterval: Double = 1.0 / accelSampleRate
    
    // MARK: - Packet Sizes (from oralable_nrf tgm_service.h)
    
    /// Frame counter size in bytes
    public static let frameCounterBytes: Int = 4
    
    /// Bytes per PPG sample (Red + IR + Green, each UInt32)
    public static let bytesPerPPGSample: Int = 12
    
    /// Bytes per accelerometer sample (X + Y + Z, each Int16)
    public static let bytesPerAccelSample: Int = 6
    
    /// Default PPG samples per packet (firmware CONFIG_PPG_SAMPLES_PER_FRAME)
    public static let ppgSamplesPerPacket: Int = 20
    
    /// Default accelerometer samples per packet
    public static let accelSamplesPerPacket: Int = 25
    
    /// Full PPG packet size: 4 + (20 × 12) = 244 bytes
    public static let ppgPacketSize: Int = frameCounterBytes + (ppgSamplesPerPacket * bytesPerPPGSample)
    
    /// Full accelerometer packet size: 4 + (25 × 6) = 154 bytes
    public static let accelPacketSize: Int = frameCounterBytes + (accelSamplesPerPacket * bytesPerAccelSample)
    
    // MARK: - Filter Parameters (from features.py)
    
    /// Heart rate bandpass filter low cutoff (Hz)
    /// Python: _butter_bandpass(0.5, 8.0, fs=50)
    public static let hrBandpassLow: Double = 0.5
    
    /// Heart rate bandpass filter high cutoff (Hz)
    public static let hrBandpassHigh: Double = 8.0
    
    /// IR DC baseline lowpass cutoff (Hz)
    /// Python: _butter_lowpass(cutoff_hz=0.8, fs=50)
    public static let irDCLowpassCutoff: Double = 0.8
    
    /// Filter order for Butterworth filters
    /// Python: order=4
    public static let filterOrder: Int = 4
    
    // MARK: - Heart Rate Detection (from features.py detect_beats_from_green_bp)
    
    /// Minimum valid heart rate (BPM)
    public static let minHeartRate: Double = 40.0
    
    /// Maximum valid heart rate (BPM)
    public static let maxHeartRate: Double = 180.0
    
    /// Minimum peak distance in seconds (based on maxHeartRate)
    /// Python: min_distance_samples = int(0.4 * FS) → 0.4s = 150 BPM max
    public static let minPeakDistanceSeconds: Double = 0.4
    
    /// Peak prominence multiplier (relative to signal std dev)
    /// Python: prom = np.nanstd(sig) * 0.5
    public static let peakProminenceMultiplier: Double = 0.5
    
    // MARK: - IR DC Analysis (from features.py)
    
    /// Rolling window for IR DC mean (seconds)
    /// Python: df["ir_dc_mean_5s"] = df["ir_dc"].rolling("5s"...)
    public static let irDCRollingWindowSeconds: Double = 5.0
    
    /// Reference window for IR DC shift baseline (seconds)
    /// Python: ref_samples = min(int(1.0 * FS), ir_dc.size)
    public static let irDCReferenceWindowSeconds: Double = 1.0
    
    /// IR DC shift threshold for muscle activity detection (ADC units)
    public static let irDCShiftThreshold: Double = 1000.0
    
    // MARK: - Validation Windows
    
    /// Validation window for event positioning (seconds)
    public static let validationWindowSeconds: Double = 180.0  // 3 minutes
    
    // MARK: - Calibration (from existing iOS implementation)
    
    /// Calibration duration in seconds
    public static let calibrationDurationSeconds: Double = 15.0
    
    /// Minimum calibration samples at 50Hz
    public static let calibrationMinSamples: Int = 500
    
    /// Maximum coefficient of variation for stable calibration
    public static let calibrationMaxCV: Double = 1.5  // 150%
    
    /// Activity detection threshold (normalized IR percentage above baseline)
    public static let activityThresholdPercent: Double = 40.0
    
    // MARK: - Channel Order
    
    /// PPG channel order in firmware packet
    /// Each sample: [Red, IR, Green] at byte offsets [0, 4, 8]
    public enum PPGChannelOrder {
        case redFirst  // Red at offset 0, IR at 4, Green at 8 (current firmware)
        
        /// Byte offset for Red channel within a sample
        public var redOffset: Int { 0 }
        
        /// Byte offset for IR channel within a sample
        public var irOffset: Int { 4 }
        
        /// Byte offset for Green channel within a sample
        public var greenOffset: Int { 8 }
    }
    
    /// Default channel order (matches oralable_nrf firmware)
    public static let defaultChannelOrder: PPGChannelOrder = .redFirst
    
    // MARK: - Buffer Sizes
    
    /// Circular buffer size for real-time processing (samples)
    public static let circularBufferSize: Int = 100
    
    /// Maximum signal buffer size for HR calculation (seconds worth of samples)
    public static let maxSignalBufferSeconds: Double = 10.0
    
    /// Minimum signal buffer for HR calculation (seconds)
    public static let minSignalBufferSeconds: Double = 3.0
}
