//
//  filters.metal
//  PixiePic
//
//  Created by 김주희 on 2024/06/07.
//

#include <metal_stdlib>
using namespace metal;

struct RasterizerData {
    float4 position [[ position ]];
    float2 textureCoord [[ user(texturecoord) ]];
};

vertex RasterizerData vertexPassThroughShader(const device packed_float2* vertices [[ buffer(0) ]],
                                              unsigned int vertexId [[ vertex_id ]])
{
    RasterizerData outData;
    outData.position = float4(vertices[vertexId], 0.0, 1.0);
    outData.textureCoord = vertices[vertexId];
    return outData;
}

// 출처: github.com/alexiscn/MetalFilters
METAL_FUNC float4 metalColorLookUp(texture3d<float, access::sample> lutTexture,
                                   sampler lutSampler,
                                   float3 texCoord,
                                   int size) {
    float sliceSize = 1.0 / float(size);
    float slicePixelSize = sliceSize / float(size);
    float sliceInnerSize = slicePixelSize * (float(size) - 1.0);
    float xOffset = 0.5 * sliceSize + texCoord.x * (1.0 - sliceSize);
    
    float yOffset = 0.5 * slicePixelSize + texCoord.y * sliceInnerSize;
    float zOffset = texCoord.z * (float(size) - 1.0);
    float zSlice0 = floor(zOffset);
    float zSlice1 = zSlice0 + 1.0;
    float s0 = yOffset + (zSlice0 * sliceSize);
    float s1 = yOffset + (zSlice1 * sliceSize);
    float4 slice0Color = lutTexture.sample(lutSampler, float3(xOffset, s0, zSlice0));
    float4 slice1Color = lutTexture.sample(lutSampler, float3(xOffset, s1, zSlice1));
    return mix(slice0Color, slice1Color, zOffset - zSlice0);
}

fragment float4 fragmentLookupShader(RasterizerData data [[stage_in]],
                                     texture2d<float, access::sample> inputTexture [[ texture(0) ]],
                                     texture3d<float, access::sample> lutTexture [[ texture(1) ]],
                                     sampler sampler [[sampler(0)]]) {
    
    float4 inputSampledColor = inputTexture.sample(sampler, data.textureCoord);
    
    float3 lutColor = metalColorLookUp(lutTexture,
                                       sampler,
                                       inputSampledColor.rgb,
                                       32).rgb; // Adjust 32 based on your LUT size
    
    // This value should be dynamic based on your application's requirement
    float strength = 0.5;
    
    float3 finalRGB = mix(inputSampledColor.rgb, lutColor.rgb, strength);
    float4 finalColor = float4(finalRGB, 1);
    
    return finalColor;
}
