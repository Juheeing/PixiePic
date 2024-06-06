//
//  ViewController.swift
//  PixiePic
//
//  Created by 김주희 on 6/6/24.
//

import UIKit
import MetalKit
import AVFoundation
import CoreImage
import SnapKit

class ViewController: UIViewController {

    private var mtkView: MTKView = MTKView()

    override func viewDidLoad() {
        super.viewDidLoad()

        configureUI()
        configureMetal()
        configureCoreImage()
        requestCameraPermissionAndConfigureSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        cameraQueue.async {
            self.session.startRunning()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        cameraQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    // MARK: - UI
    private func configureUI() {
        self.view.addSubview(self.mtkView)
        self.view.addSubview(self.filterChangeButton)
        self.view.addSubview(self.captureButton)

        self.filterChangeButton.addTarget(self, action: #selector(filterChangeButtonTapped), for: .touchUpInside)
        self.captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)

        self.mtkView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        self.filterChangeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(15)
            make.bottom.equalToSuperview().offset(-15)
            make.width.height.equalTo(40)
        }

        self.captureButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-15)
            make.width.height.equalTo(80)
        }
    }
    
    private var filterChangeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "camera.filters"), for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        return button
    }()
    
    private var captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "camera.circle"), for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 40
        button.clipsToBounds = true
        return button
    }()

    // MARK: - configure Metal

    private var metalDevice: MTLDevice!
    private var metalCommandQueue: MTLCommandQueue!

    private func configureMetal() {
        self.metalDevice = MTLCreateSystemDefaultDevice()
        
        self.mtkView.device = self.metalDevice

        self.mtkView.isPaused = true
        self.mtkView.enableSetNeedsDisplay = false

        self.metalCommandQueue = metalDevice.makeCommandQueue()

        self.mtkView.delegate = self

        self.mtkView.framebufferOnly = false
    }

    // MARK: - camera control
    private let cameraQueue = DispatchQueue(label: "cameraQueue")
    private let videoQueue = DispatchQueue(label: "videoQueue")

    private let session = AVCaptureSession()
    private var photoOutput: AVCapturePhotoOutput!
    private var deviceInput: AVCaptureDeviceInput!
    private var videoOutput: AVCaptureVideoDataOutput!

    private func requestCameraPermissionAndConfigureSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.configureCaptureSession()
                }
            }
        default:
            return
        }
    }

    private func configureCaptureSession() {
        let cameraDevice: AVCaptureDevice = configureCamera()
        do {
            self.deviceInput = try AVCaptureDeviceInput(device: cameraDevice)

            self.videoOutput = AVCaptureVideoDataOutput()
            self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)

            self.photoOutput = AVCapturePhotoOutput()
            
            self.session.addInput(self.deviceInput)
            self.session.addOutput(self.videoOutput)
            self.session.addOutput(self.photoOutput)

            self.videoOutput.connections.first?.videoOrientation = .portrait
            
        } catch {
            print("error = \(error.localizedDescription)")
        }
    }

    private func configureCamera() -> AVCaptureDevice {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera], mediaType: .video, position: .back)

        guard let cameraDevice = discoverySession.devices.first else {
            fatalError("no camera device is available")
        }

        return cameraDevice
    }

    // MARK: - configure core image
    private var ciContext: CIContext!
    private var currentCIImage: CIImage?

    private func configureCoreImage() {
        self.ciContext = CIContext(mtlDevice: self.metalDevice)
    }

    // MARK: - private methods
    private var filterApplied: Bool = false

    private let sepiaFilter: CIFilter = {
        let filter = CIFilter(name: "CISepiaTone")!
        filter.setValue(NSNumber(value: 1), forKeyPath: "inputIntensity")
        return filter
    }()

    @objc private func filterChangeButtonTapped(_ button: UIButton) {
        self.filterApplied.toggle()
    }
    
    @objc private func captureButtonTapped(_ button: UIButton) {
        let settings = AVCapturePhotoSettings()
        self.photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        guard let image = UIImage(data: imageData) else { return }

        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let ciImage = CIImage(cvImageBuffer: cvBuffer)

        if self.filterApplied {
            guard let filteredImage = applyFilter(inputImage: ciImage) else {
                return
            }

            self.currentCIImage = filteredImage

        } else {
            self.currentCIImage = ciImage
        }

        let imageSize = CIImage(cvImageBuffer: cvBuffer).extent.size
        DispatchQueue.main.async {
            self.mtkView.drawableSize = CGSize(width: imageSize.width, height: imageSize.height)
        }
        self.mtkView.draw()
    }

    func applyFilter(inputImage image: CIImage) -> CIImage? {
        var filteredImage: CIImage?

        self.sepiaFilter.setValue(image, forKey: kCIInputImageKey)
        filteredImage = self.sepiaFilter.outputImage

        return filteredImage
    }
}

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    
    }

    func draw(in view: MTKView) {
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else {
            return
        }

        guard let ciImage = self.currentCIImage else {
            return
        }

        guard let currentDrawable = view.currentDrawable else {
            return
        }

        self.ciContext.render(ciImage,
                              to: currentDrawable.texture,
                              commandBuffer: commandBuffer,
                              bounds: CGRect(origin: .zero, size: view.drawableSize),
                              colorSpace: CGColorSpaceCreateDeviceRGB())

        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}

