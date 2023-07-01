//
//  CYPlayerMetalShaders.h
//  CYPlayer
//
//  Created by yellowei on 2020/1/14.
//  Copyright © 2020 Sutan. All rights reserved.
//

#ifndef CYPlayerMetalShaders_h
#define CYPlayerMetalShaders_h

#include <simd/simd.h>

# pragma mark - ShaderTypes

typedef struct
{
    vector_float4 position;
    vector_float2 textureCoordinate;
} CYVertex;


typedef struct {
    matrix_float3x3 matrix;
    vector_float3 offset;
} CYConvertMatrix;



typedef enum CYVertexInputIndex
{
    CYVertexInputIndexVertices     = 0,
} CYVertexInputIndex;


typedef enum CYFragmentBufferIndex
{
    CYFragmentInputIndexMatrix     = 0,
} CYFragmentBufferIndex;


typedef enum CYFragmentTextureIndex
{
    CYFragmentTextureIndexTextureY     = 0,
    CYFragmentTextureIndexTextureUV     = 1,
} CYFragmentTextureIndex;


#endif /* CYPlayerMetalShaders_h */
