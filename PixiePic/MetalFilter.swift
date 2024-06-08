//
//  MetalFilter.swift
//  PixiePic
//
//  Created by 김주희 on 2024/06/07.
//

import Metal
import MetalKit
import UIKit

class MetalFilter {
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let inputImage: CIImage
    
    var commandBuffer: MTLCommandBuffer?
    var commandEncoder: MTLRenderCommandEncoder?
    var pipelineState: MTLRenderPipelineState?
   
    var inputTexture: MTLTexture?
    var outputTexture: MTLTexture?
    var lutTexture: MTLTexture?
    var samplerState: MTLSamplerState?
    
    // 삼각형을 두개 그려서 네모를 그린다
    let vertexData: [Float] =
    [
        -1.0, -1.0,
        -1.0,  1.0,
        1.0, -1.0,
        
        1.0, -1.0,
        -1.0,  1.0,
        1.0,  1.0,
    ]
    
    init(inputImage: CIImage) {
        self.device = MTLCreateSystemDefaultDevice()!
        self.commandQueue = self.device.makeCommandQueue()!
        self.inputImage = inputImage
    }
    
    func applyFilter(with lookUp: Lookup) -> CIImage? {
        prepare(with: lookUp)
        
        encodeCommand()
        
        commandBuffer?.commit()

        commandBuffer?.waitUntilCompleted()

        if let outputTexture = outputTexture {
            return CIImage(mtlTexture: outputTexture, options: nil)
        } else {
            return nil
        }
    }
    
    private func prepare(with lookUp: Lookup) {
        self.inputTexture = makeInputTexture()
        self.outputTexture = makeOutputTexture()
        self.lutTexture = makeLUTTexture(lookUp: lookUp)
        self.samplerState = makeSamplerState()
        
        self.pipelineState = makePipeLineState()
        self.commandBuffer = self.commandQueue.makeCommandBuffer()
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = .init(red: 0, green: 0.5, blue: 0.5, alpha: 1)
        self.commandEncoder = self.commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    }
    
    private func makePipeLineState() -> MTLRenderPipelineState? {
        let defaultLibrary = self.device.makeDefaultLibrary()
        
        let vertexFunction = defaultLibrary?.makeFunction(name: "vertexPassThroughShader")
        let fragmentFunction = defaultLibrary?.makeFunction(name: "fragmentLookupShader")
        
        if let vertexFunction = vertexFunction, let fragmentFunction = fragmentFunction {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
            
            let pipeLineState = try? device.makeRenderPipelineState(descriptor: descriptor)
            return pipeLineState
        } else {
            return nil
        }
    }
    
    private func encodeCommand() {
        guard let commandEncoder = commandEncoder, let pipelineState = pipelineState else { return }
            
        commandEncoder.setRenderPipelineState(pipelineState)
        
        let vertexDataSize = vertexData.count * MemoryLayout<Float>.size
        let vertexBuffer = device.makeBuffer(bytes: vertexData,
                                             length: vertexDataSize,
                                             options: [])
        
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder.setFragmentTexture(inputTexture, index: 0)
        commandEncoder.setFragmentTexture(lutTexture, index: 1)
        commandEncoder.setFragmentSamplerState(samplerState, index: 0)
        
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexData.count / 2)
        
        commandEncoder.endEncoding()

    }
    
    private func makeSamplerState() -> MTLSamplerState {
        let descriptor = MTLSamplerDescriptor()
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        
        descriptor.magFilter = .nearest
        descriptor.minFilter = .nearest

        return device.makeSamplerState(descriptor: descriptor)!
    }
    
    private func makeInputTexture() -> MTLTexture? {
        let ciContext = CIContext(mtlDevice: device)
        guard let cgImage = ciContext.createCGImage(inputImage, from: inputImage.extent) else {
            return nil
        }
        
        let textureLoader = MTKTextureLoader(device: self.device)
        let texture = try? textureLoader.newTexture(cgImage: cgImage, options: [.SRGB: false])
        return texture
    }
    
    private func makeLUTTexture(lookUp: Lookup) -> MTLTexture? {
        let lutImage = UIImage(named: lookUp.rawValue)
        guard let cgImage = lutImage?.cgImage else {
            return nil
        }
            
        let textureLoader = MTKTextureLoader(device: self.device)
        let texture = try? textureLoader.newTexture(cgImage: cgImage, options: nil)
        
        return texture
    }
    
    private func makeOutputTexture() -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                         width: Int(inputImage.extent.width),
                                                                         height: Int(inputImage.extent.height),
                                                                         mipmapped: false)
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        let texture = device.makeTexture(descriptor: textureDescriptor)
        return texture
    }
}
