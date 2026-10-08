//
//  QRScannerView.swift
//  Authenticator
//
//  Created by Rendi  on 06/10/26.
//

import SwiftUI
@preconcurrency import AVFoundation

struct QRScannerView: UIViewRepresentable {
    let isScanning: Bool
    @Binding var message: String?
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> CameraPreview {
        let view = CameraPreview()
        view.previewLayer.session = context.coordinator.session
        view.previewLayer.videoGravity = .resizeAspectFill
        context.coordinator.prepare()
        return view
    }

    func updateUIView(_ uiView: CameraPreview, context: Context) {
        context.coordinator.parent = self
        context.coordinator.setRunning(isScanning)
    }

    static func dismantleUIView(_ uiView: CameraPreview, coordinator: Coordinator) {
        coordinator.setRunning(false)
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: QRScannerView
        let session = AVCaptureSession()
        private var ready = false
        private var desiredRunning = true
        private var lastScan = Date.distantPast
        private let sessionQueue = DispatchQueue(label: "Authenticator.camera")

        init(parent: QRScannerView) { self.parent = parent }

        func prepare() {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: configure()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    guard let self else { return }
                    Task { @MainActor in
                        if granted { self.configure() }
                        else { self.parent.message = "Camera access is off.\nEnable it in Settings or enter manually." }
                    }
                }
            default: parent.message = "Camera access is off.\nEnable it in Settings or enter manually."
            }
        }

        private func configure() {
            guard !ready else { return }
            guard let camera = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: camera) else {
                parent.message = "Camera unavailable.\nEnter an account manually or import a QR photo."
                return
            }
            session.beginConfiguration()
            session.sessionPreset = .high
            let output = AVCaptureMetadataOutput()
            guard session.canAddInput(input), session.canAddOutput(output) else {
                session.commitConfiguration()
                parent.message = "Camera unavailable.\nEnter an account manually or import a QR photo."
                return
            }
            session.addInput(input)
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
            session.commitConfiguration()
            ready = true
            setRunning(desiredRunning)
        }

        func setRunning(_ running: Bool) {
            desiredRunning = running
            guard ready else { return }
            let captureSession = session
            sessionQueue.async {
                if running && !captureSession.isRunning { captureSession.startRunning() }
                else if !running && captureSession.isRunning { captureSession.stopRunning() }
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard parent.isScanning, Date.now.timeIntervalSince(lastScan) > 2,
                  let qr = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = qr.stringValue else { return }
            lastScan = .now
            parent.onScan(value)
        }
    }
}

final class CameraPreview: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
