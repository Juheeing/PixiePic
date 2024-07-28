//
//  ViewController.swift
//  PixiePic
//
//  Created by 김주희 on 7/20/24.
//

import UIKit
import MetalKit
import AVFoundation
import CoreImage
import SnapKit
import PhotosUI

class ViewController: UIViewController, PHPickerViewControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource {

    private var mtkView: MTKView = MTKView()
    private var imageView: UIImageView = UIImageView()
    private var isImageMode: Bool = false
    private var albumImage: UIImage?
    private var lookupFilter: LookupFilter?
    private var collectionView: UICollectionView!
    private var filterNames: [String] = LookupModel.allCases.map { $0.rawValue }
    private var selectedFilterName: String = ""
    private var selectedFilterIndex: IndexPath?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configureUI()
        configureCollectionView()
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
    private var filterChangeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "camera.filters"), for: .normal)
        button.backgroundColor = .darkGray
        button.tintColor = .white
        button.layer.cornerRadius = 20
        return button
    }()
    
    private var captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "camera.circle"), for: .normal)
        button.backgroundColor = .darkGray
        button.tintColor = .white
        button.layer.cornerRadius = 40
        return button
    }()

    private var switchCameraButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera"), for: .normal)
        button.backgroundColor = .darkGray
        button.tintColor = .white
        button.layer.cornerRadius = 20
        return button
    }()
    
    private var galleryAccessButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
        button.backgroundColor = .darkGray
        button.tintColor = .white
        button.layer.cornerRadius = 20
        return button
    }()
    
    private var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle"), for: .normal)
        button.backgroundColor = .darkGray
        button.tintColor = .white
        button.layer.cornerRadius = 20
        return button
    }()
    
    private func configureUI() {
        self.view.backgroundColor = .black
        self.view.addSubview(self.mtkView)
        self.view.addSubview(self.imageView)
        self.view.addSubview(self.filterChangeButton)
        self.view.addSubview(self.captureButton)
        self.view.addSubview(self.switchCameraButton)
        self.view.addSubview(self.galleryAccessButton)
        
        self.filterChangeButton.addTarget(self, action: #selector(filterChangeButtonTapped), for: .touchUpInside)
        self.captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        self.switchCameraButton.addTarget(self, action: #selector(switchCameraButtonTapped), for: .touchUpInside)
        self.galleryAccessButton.addTarget(self, action: #selector(galleryAccessButtonTapped), for: .touchUpInside)
        
        self.mtkView.snp.makeConstraints { make in
            make.width.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(mtkView.snp.width).multipliedBy(4.0/3.0)
            make.center.equalTo(view.safeAreaLayoutGuide)
        }

        self.imageView.snp.makeConstraints { make in
            make.width.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(imageView.snp.width).multipliedBy(4.0/3.0)
            make.center.equalTo(view.safeAreaLayoutGuide)
        }
        
        self.imageView.contentMode = .scaleAspectFit
        self.imageView.isHidden = true
        
        self.captureButton.snp.makeConstraints { make in
            make.centerX.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-15)
            make.width.height.equalTo(80)
        }

        self.filterChangeButton.snp.makeConstraints { make in
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-15)
            make.centerY.equalTo(captureButton.snp.centerY)
            make.width.height.equalTo(50)
        }
        
        self.galleryAccessButton.snp.makeConstraints { make in
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(15)
            make.centerY.equalTo(captureButton.snp.centerY)
            make.width.height.equalTo(50)
        }
        
        self.switchCameraButton.snp.makeConstraints { make in
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-15)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(15)
            make.width.height.equalTo(40)
        }
    }
    
    private func configureCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 10
        layout.itemSize = CGSize(width: 80, height: 80)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(FilterCell.self, forCellWithReuseIdentifier: FilterCell.identifier)
        collectionView.isHidden = true
        collectionView.backgroundColor = .black
        
        self.view.addSubview(collectionView)
        self.view.addSubview(closeButton)
        
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)

        closeButton.isHidden = true
        
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(100)
        }
        
        closeButton.snp.makeConstraints { make in
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-15)
            make.bottom.equalTo(collectionView.snp.top).offset(-10)
            make.width.equalTo(40)
            make.height.equalTo(40)
        }
    }
    
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
        session.beginConfiguration()
        session.sessionPreset = .photo
        
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
        
        session.commitConfiguration()
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

    @objc private func filterChangeButtonTapped(_ button: UIButton) {
        collectionView.isHidden.toggle()
        closeButton.isHidden.toggle()
    }
    
    @objc private func captureButtonTapped(_ button: UIButton) {
        if isImageMode {
            guard let image = albumImage else { return }
            
            var finalImage: UIImage = image
            if let cgInputImage = image.cgImage,
               let filteredImage = applyFilter(inputImage: CIImage(cgImage: cgInputImage)),
               let filteredUIImage = ciImageToUIImage(ciImage: filteredImage) {
                finalImage = filteredUIImage
            }
            UIImageWriteToSavedPhotosAlbum(finalImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        } else {
            imageView.isHidden = false
            mtkView.isHidden = true
            galleryAccessButton.setImage(UIImage(systemName: "arrow.backward"), for: .normal)
            captureButton.setImage(UIImage(systemName: "square.and.arrow.down"), for: .normal)
            changeImageMode(true)
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("save error: \(error)")
            let alert = UIAlertController(title: "저장실패", message: "사진을 저장하는데 실패했습니다.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
        } else {
            let alert = UIAlertController(title: "저장완료", message: "사진을 갤러리에 저장했습니다.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
        }
    }
    
    @objc private func switchCameraButtonTapped(_ button: UIButton) {
        guard let currentInput = self.deviceInput else { return }

        session.beginConfiguration()
        session.removeInput(currentInput)

        let newCameraPosition: AVCaptureDevice.Position = (currentInput.device.position == .back) ? .front : .back
        let newCamera = self.cameraWithPosition(position: newCameraPosition)

        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera!)
            session.addInput(newInput)
            self.deviceInput = newInput

            if let connection = self.videoOutput.connection(with: .video) {
                connection.videoOrientation = .portrait
                if newCamera?.position == .front {
                    connection.isVideoMirrored = true
                } else {
                    connection.isVideoMirrored = false
                }
            }
        } catch {
            print("Error switching camera: \(error.localizedDescription)")
        }

        session.commitConfiguration()
    }
    
    @objc private func galleryAccessButtonTapped(_ button: UIButton) {
        if isImageMode {
            removeFilter()
            changeImageMode(false)
            self.galleryAccessButton.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
            self.captureButton.setImage(UIImage(systemName: "camera.circle"), for: .normal)
            self.imageView.isHidden = true
            self.mtkView.isHidden = false
        } else {
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            present(picker, animated: true)
        }
    }

    @objc private func closeButtonTapped(_ button: UIButton) {
        collectionView.isHidden = true
        closeButton.isHidden = true
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        changeImageMode(false)
        
        guard let itemProvider = results.first?.itemProvider else { return }

        if itemProvider.canLoadObject(ofClass: UIImage.self) {
            itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if let image = image as? UIImage {
                        self.removeFilter()
                        self.albumImage = image.fixedOrientation()
                        self.imageView.image = self.albumImage
                        self.imageView.isHidden = false
                        self.mtkView.isHidden = true
                        self.galleryAccessButton.setImage(UIImage(systemName: "arrow.backward"), for: .normal)
                        self.captureButton.setImage(UIImage(systemName: "square.and.arrow.down"), for: .normal)
                        self.changeImageMode(true)
                    }
                }
            }
        }
    }
    
    // 지정된 위치의 카메라를 찾는 메서드
    private func cameraWithPosition(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera], mediaType: .video, position: .unspecified)

        for device in discoverySession.devices {
            if device.position == position {
                return device
            }
        }

        return nil
    }

    // MARK: - UICollectionViewDelegate, UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filterNames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FilterCell.identifier, for: indexPath) as! FilterCell
        let filterName = filterNames[indexPath.item]
        let isSelected = indexPath == selectedFilterIndex
        cell.configure(with: filterName, isSelected: isSelected)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if selectedFilterIndex == indexPath {
            selectedFilterIndex = nil
            selectedFilterName = ""
            removeFilter()
        } else {
            let previousSelectedIndex = selectedFilterIndex
            selectedFilterIndex = indexPath
            selectedFilterName = filterNames[indexPath.item]
            applySelectedFilter()
            
            if let previousSelectedIndex = previousSelectedIndex {
                collectionView.reloadItems(at: [previousSelectedIndex])
            }
        }
        collectionView.reloadItems(at: [indexPath])
    }
    
    private func applySelectedFilter() {
        if isImageMode {
            if let inputImage = self.albumImage,
               let cgInputImage = inputImage.cgImage,
               let filteredImage = applyFilter(inputImage: CIImage(cgImage: cgInputImage)) {
                self.imageView.image = UIImage(ciImage: filteredImage)
            } else {
                print("Failed to apply filter")
            }
        } else {
            self.filterApplied = true
        }
    }
    
    private func removeFilter() {
        selectedFilterIndex = nil
        selectedFilterName = ""
        collectionView.reloadData()
        if isImageMode {
            self.imageView.image = self.albumImage
        } else {
            self.filterApplied = false
        }
    }
    
    private func ciImageToUIImage(ciImage: CIImage) -> UIImage? {
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
    
    private func changeImageMode(_ mode: Bool) {
        isImageMode = mode
        switchCameraButton.isHidden = mode
    }
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        guard var image = UIImage(data: imageData) else { return }

        image = image.fixedOrientation()

        var finalImage: UIImage = image
        if let cgInputImage = image.cgImage,
           let filteredImage = applyFilter(inputImage: CIImage(cgImage: cgInputImage)),
           let filteredUIImage = ciImageToUIImage(ciImage: filteredImage) {
            finalImage = filteredUIImage
        }
        albumImage = finalImage
        imageView.image = finalImage
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        AudioServicesDisposeSystemSoundID(1108)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        AudioServicesDisposeSystemSoundID(1108)
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
        if selectedFilterName == "" {
            return image
        }
        guard let lookup = LookupModel(filterName: selectedFilterName) else {
            print("Invalid filter name: \(selectedFilterName)")
            return nil
        }
        lookupFilter = LookupFilter(inputImage: image)
        let filteredImage = lookupFilter!.applyFilter(with: lookup)
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

extension UIImage {
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
}
