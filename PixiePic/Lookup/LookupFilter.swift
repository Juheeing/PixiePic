//
//  LookupFilter.swift
//  PixiePic
//
//  Created by 김주희 on 2024/06/07.
//

import UIKit
import Foundation
import AVFoundation
import CoreImage
import CoreGraphics

class LookupFilter  {
    
    let inputImage: UIImage?
    let player: AVPlayer?
    let playerLayer: AVPlayerLayer?
    var videoURL: URL?
    
    init(inputImage: UIImage? = nil, player: AVPlayer? = nil, playerLayer: AVPlayerLayer? = nil, videoURL: URL? = nil) {
        self.inputImage = inputImage
        self.player = player
        self.playerLayer = playerLayer
        self.videoURL = videoURL
    }
    
    func applyCubeFilter() -> UIImage? {
        guard let lutURL = Bundle.main.url(forResource: "sample1_s-sRGB Profile-16", withExtension: "cube") else {
            return nil
        }
        guard let data = getCubeData(cubeFilePath: lutURL, dimension: 16, colorSpace: CGColorSpaceCreateDeviceRGB()) else { return nil }
        
        guard let inputCGImage = inputImage?.cgImage else { return nil }
        let inputCIImage = CIImage(cgImage: inputCGImage)
        
        let filter = CIFilter(name: "CIColorCube", parameters: [
            "inputCubeDimension": 16,
            "inputCubeData": data,
            "inputImage": inputCIImage,
          ])
        
        if let outputImage = filter?.outputImage {
            return UIImage(ciImage: outputImage)
        } else {
            return nil
        }
    }

    func applyFilter(with lookup: Lookup) -> UIImage? {
        guard let lutImage = UIImage(named: lookup.rawValue) else { return nil }
        guard let data = getCubeData(lutImage: lutImage, dimension: 64, colorSpace: CGColorSpaceCreateDeviceRGB()) else { return nil }
        
        guard let inputCGImage = inputImage?.cgImage else { return nil }
        let inputCIImage = CIImage(cgImage: inputCGImage)
        
        let filter = CIFilter(name: "CIColorCube", parameters: [
            "inputCubeDimension": 64,
            "inputCubeData": data,
            "inputImage": inputCIImage,
          ])
        
        if let outputImage = filter?.outputImage {
            return UIImage(ciImage: outputImage)
        } else {
            return nil
        }
    }
    
    
    func applyAvFilter(with lookup: Lookup) {
        guard let lutImage = UIImage(named: lookup.rawValue) else { return }
        guard let data = getCubeData(lutImage: lutImage, dimension: 64, colorSpace: CGColorSpaceCreateDeviceRGB()) else { return }

        let avPlayerItem = player?.currentItem
        let avAsset = avPlayerItem?.asset

        let composition = AVMutableVideoComposition(asset: avAsset!) { (request) in
            let source = request.sourceImage

            let filter = CIFilter(name: "CIColorCube", parameters: [
                "inputCubeDimension": 64,
                "inputCubeData": data,
                "inputImage": source,
            ])

            guard let filteredImage = filter?.outputImage else {
                request.finish(with: NSError())
                return
            }

            request.finish(with: filteredImage, context: nil)
        }

        avPlayerItem?.videoComposition = composition
    }
    
    func applyVideoFilter(remoteVideoURL: URL, outputVideoURL: URL, with lookup: Lookup, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.main.async {
            let avAsset = AVAsset(url: remoteVideoURL)
            let composition = AVMutableComposition()
            let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)

            do {
                try videoTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: avAsset.duration),
                                               of: avAsset.tracks(withMediaType: .video)[0],
                                               at: .zero)
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            if let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                do {
                    try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: avAsset.duration),
                                                   of: avAsset.tracks(withMediaType: .audio)[0],
                                                   at: .zero)
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
            } else {
                print("No audio track found in the video.")
            }

            let compositionFilter = AVMutableVideoComposition(asset: avAsset) { request in
                let source = request.sourceImage

                let filter = CIFilter(name: "CIColorCube", parameters: [
                    "inputCubeDimension": 64,
                    "inputCubeData": self.getCubeData(lookup: lookup),
                    "inputImage": source,
                ])

                guard let filteredImage = filter?.outputImage else {
                    request.finish(with: NSError())
                    return
                }

                request.finish(with: filteredImage, context: nil)
            }

            compositionFilter.renderSize = CGSize(width: avAsset.tracks(withMediaType: .video)[0].naturalSize.width,
                                                  height: avAsset.tracks(withMediaType: .video)[0].naturalSize.height)

            guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: NSCocoaErrorDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Error creating export session"])))
                }
                return
            }

            exportSession.outputURL = outputVideoURL
            exportSession.outputFileType = .mp4
            exportSession.videoComposition = compositionFilter
            exportSession.timeRange = CMTimeRange(start: .zero, duration: avAsset.duration)

            exportSession.exportAsynchronously {
                if exportSession.status == .completed {
                    DispatchQueue.main.async {
                        completion(.success(outputVideoURL))
                    }
                } else if let error = exportSession.error {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    private func getCubeData(cubeFilePath: URL, dimension: Int, colorSpace: CGColorSpace) -> Data? {
            
        guard let fileData = try? Data(contentsOf: cubeFilePath) else {
            return nil
        }

        let dataSize = dimension * dimension * dimension * MemoryLayout<Float>.size * 4
        var array = Array<Float>(repeating: 0, count: dataSize)

        var fileOffset: Int = 0
        var z: Int = 0

        for _ in stride(from: 0, to: dimension, by: 1) {
            for y in stride(from: 0, to: dimension, by: 1) {
                let tmp = z
                for _ in stride(from: 0, to: dimension, by: 1) {
                    for x in stride(from: 0, to: dimension, by: 1) {

                        let dataOffset = (z * dimension * dimension + y * dimension + x) * 4

                        array[dataOffset + 0] = Float(fileData[fileOffset]) / 255
                        array[dataOffset + 1] = Float(fileData[fileOffset + 1]) / 255
                        array[dataOffset + 2] = Float(fileData[fileOffset + 2]) / 255
                        array[dataOffset + 3] = Float(fileData[fileOffset + 3]) / 255

                        fileOffset += 4
                    }
                    z += 1
                }
                z = tmp
            }
            z += dimension
        }

        let data = Data(bytes: array, count: dataSize)
        return data
    }

    private func getCubeData(lutImage: UIImage, dimension: Int, colorSpace: CGColorSpace) -> Data? {
        
      guard let cgImage = lutImage.cgImage else {
        return nil
      }

      guard let bitmap = createBitmap(image: cgImage, colorSpace: colorSpace) else {
        return nil
      }

      let width = cgImage.width
      let height = cgImage.height
      let rowNum = width / dimension
      let columnNum = height / dimension
      print("width: \(width), height: \(height), rowNum: \(rowNum), columnNum: \(columnNum)")
        
      let dataSize = dimension * dimension * dimension * MemoryLayout<Float>.size * 4
      print("dataSize: \(dataSize)")
        
      var array = Array<Float>(repeating: 0, count: dataSize)

      var bitmapOffest: Int = 0
      var z: Int = 0

      for _ in stride(from: 0, to: rowNum, by: 1) {
        for y in stride(from: 0, to: dimension, by: 1) {
          let tmp = z
          for _ in stride(from: 0, to: columnNum, by: 1) {
            for x in stride(from: 0, to: dimension, by: 1) {

              let dataOffset = (z * dimension * dimension + y * dimension + x) * 4

              let position = bitmap
                .advanced(by: bitmapOffest)

                array[dataOffset + 0] = Float(position.advanced(by: 0).pointee) / 255
                array[dataOffset + 1] = Float(position.advanced(by: 1).pointee) / 255
                array[dataOffset + 2] = Float(position.advanced(by: 2).pointee) / 255
                array[dataOffset + 3] = Float(position.advanced(by: 3).pointee) / 255
              
              bitmapOffest += 4
              
            }
            z += 1
          }
          z = tmp
        }
        z += columnNum
      }

      free(bitmap)
      
      let data = Data.init(bytes: array, count: dataSize)
      return data
    }
    
    private func getCubeData(lookup: Lookup) -> Data {
        guard let lutImage = UIImage(named: lookup.rawValue) else {
            fatalError("Lookup image not found")
        }

        guard let cgImage = lutImage.cgImage else {
            fatalError("Failed to get CGImage from lookup image")
        }

        guard let bitmap = createBitmap(image: cgImage, colorSpace: CGColorSpaceCreateDeviceRGB()) else {
            fatalError("Failed to create bitmap from CGImage")
        }

        let dimension = 64
        let dataSize = dimension * dimension * dimension * MemoryLayout<Float>.size * 4
        var array = Array<Float>(repeating: 0, count: dataSize)

        for z in 0..<dimension {
            for y in 0..<dimension {
                for x in 0..<dimension {
                    let dataOffset = (z * dimension * dimension + y * dimension + x) * 4
                    let position = bitmap.advanced(by: dataOffset)

                    array[dataOffset + 0] = Float(position.advanced(by: 0).pointee) / 255
                    array[dataOffset + 1] = Float(position.advanced(by: 1).pointee) / 255
                    array[dataOffset + 2] = Float(position.advanced(by: 2).pointee) / 255
                    array[dataOffset + 3] = Float(position.advanced(by: 3).pointee) / 255
                }
            }
        }

        free(bitmap)

        return Data(bytes: array, count: dataSize)
    }
    
    private func createBitmap(image: CGImage, colorSpace: CGColorSpace) -> UnsafeMutablePointer<UInt8>? {
      let width = image.width
      let height = image.height

      let bitsPerComponent = 8
      let bytesPerRow = width * 4

      let bitmapSize = bytesPerRow * height

      guard let data = malloc(bitmapSize) else {
        return nil
      }

      guard let context = CGContext(
        data: data,
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        releaseCallback: nil,
        releaseInfo: nil) else {
          return nil
      }

      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

      return data.bindMemory(to: UInt8.self, capacity: bitmapSize)
    }
}
