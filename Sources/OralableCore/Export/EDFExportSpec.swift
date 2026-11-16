//
//  EDFExportSpec.swift
//  OralableCore
//
//  Shared Dual A / research EDF channel + annotation labels
//  (parity with cursor_oralable src/export/edf_spec.py).
//

import Foundation

/// Research Dual A / Oralable EDF+ schema. Not PSG; not AHI/ODI.
/// `SASHB_cum` is engineering SpO2<90 AUC, not Azarbarzin HB.
public enum EDFExportSpec: Sendable {
    public static let sampleRateHz: Double = 50.0

    public static let channelIRDC = "IR_DC"
    public static let channelEMG = "EMG"
    public static let channelSpO2 = "SpO2"
    public static let channelSASHB = "SASHB_cum"
    public static let channelRed = "Red"
    public static let channelGreen = "Green"
    public static let channelIR = "IR"
    public static let channelAccX = "AccX"
    public static let channelAccY = "AccY"
    public static let channelAccZ = "AccZ"

    public static let annotationEMGBout = "EMG_bout"
    public static let annotationSpO2Desat = "SpO2_desat"
    public static let annotationLabelPrefix = "label:"

    public static let claimNote =
        "Research Dual A / Oralable EDF+ — not PSG; not AHI/ODI; SASHB_cum is engineering SpO2<90 AUC, not Azarbarzin HB. Default: IR_DC viewer a.u. (occlusion↑), SpO2 %dev from 100, EMG, SASHB_cum; absolute in CSV; raw PPG omitted."
}
