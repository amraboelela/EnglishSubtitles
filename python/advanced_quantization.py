#!/usr/bin/env python3
"""
Advanced Whisper Model Quantization

This script implements multiple quantization techniques:
- Int8 (current)
- Int4 (4x more compression)
- Mixed precision quantization
- Block-wise quantization

Usage:
    python advanced_quantization.py
"""

import torch
import whisper
import numpy as np
from pathlib import Path
import struct

def load_whisper_model():
    """Load the Whisper medium model"""
    print("📥 Loading Whisper medium model...")

    try:
        import whisper
        model = whisper.load_model("medium")

        total_params = sum(p.numel() for p in model.parameters())
        param_size = sum(p.numel() * p.element_size() for p in model.parameters()) / (1024 * 1024)

        print(f"✅ Model loaded: {total_params:,} parameters, {param_size:.1f} MB")
        return model

    except Exception as e:
        print(f"❌ Error loading model: {e}")
        return None

def quantize_int4(weights):
    """
    Quantize weights to 4-bit integers (Int4)
    Achieves 8x compression but with more quality loss
    """
    w_min = weights.min()
    w_max = weights.max()

    # Quantize to 4-bit range [0, 15]
    scale = (w_max - w_min) / 15.0
    zero_point = w_min

    # Quantize and pack two 4-bit values into one byte
    quantized = np.round((weights - zero_point) / scale).astype(np.uint8)
    quantized = np.clip(quantized, 0, 15)

    # Pack two 4-bit values into one byte
    packed = np.zeros((quantized.size + 1) // 2, dtype=np.uint8)
    for i in range(0, quantized.size, 2):
        low = quantized.flat[i]
        high = quantized.flat[i + 1] if i + 1 < quantized.size else 0
        packed[i // 2] = (high << 4) | low

    return {
        'packed_weights': packed,
        'scale': scale,
        'zero_point': zero_point,
        'shape': weights.shape,
        'original_size': quantized.size
    }

def quantize_mixed_precision(weights, layer_name):
    """
    Mixed precision quantization - use different precision for different layers
    Critical layers get Int8, less critical get Int4
    """
    # Critical layers that need higher precision
    critical_layers = [
        'encoder.conv1', 'encoder.conv2',  # Audio processing
        'decoder.token_embedding',         # Token embeddings
        'decoder.ln',                     # Layer norms
    ]

    is_critical = any(critical in layer_name for critical in critical_layers)

    if is_critical:
        # Use Int8 for critical layers
        return quantize_int8(weights), 8
    else:
        # Use Int4 for non-critical layers
        return quantize_int4(weights), 4

def quantize_int8(weights):
    """
    Standard Int8 quantization (our current method)
    """
    w_min = weights.min()
    w_max = weights.max()

    scale = (w_max - w_min) / 254.0
    zero_point = -127 - w_min / scale

    quantized_weights = np.round((weights / scale) + zero_point).astype(np.int8)

    return {
        'weights': quantized_weights,
        'scale': scale,
        'zero_point': zero_point,
        'shape': weights.shape
    }

def quantize_block_wise(weights, block_size=128):
    """
    Block-wise quantization - quantize weights in blocks for better accuracy
    """
    if weights.size < block_size:
        return quantize_int8(weights), 8

    flat_weights = weights.flatten()
    num_blocks = (flat_weights.size + block_size - 1) // block_size

    quantized_blocks = []
    scales = []
    zero_points = []

    for i in range(num_blocks):
        start_idx = i * block_size
        end_idx = min((i + 1) * block_size, flat_weights.size)
        block = flat_weights[start_idx:end_idx]

        # Quantize this block
        w_min = block.min()
        w_max = block.max()

        if w_max == w_min:
            scale = 1.0
            zero_point = w_min
        else:
            scale = (w_max - w_min) / 254.0
            zero_point = -127 - w_min / scale

        quantized_block = np.round((block / scale) + zero_point).astype(np.int8)

        quantized_blocks.append(quantized_block)
        scales.append(scale)
        zero_points.append(zero_point)

    return {
        'blocks': quantized_blocks,
        'scales': np.array(scales),
        'zero_points': np.array(zero_points),
        'shape': weights.shape,
        'block_size': block_size
    }

def advanced_quantization(model, method="int4"):
    """
    Apply advanced quantization techniques
    """
    print(f"🔧 Applying {method.upper()} quantization...")

    quantized_state = {}
    total_original_size = 0
    total_quantized_size = 0

    for name, param in model.state_dict().items():
        if param.dtype == torch.float32 and len(param.shape) >= 2:
            weights = param.cpu().numpy()
            original_size = weights.nbytes

            if method == "int4":
                quantized_data = quantize_int4(weights)
                quantized_size = quantized_data['packed_weights'].nbytes + 16
                compression = original_size / quantized_size

            elif method == "int8":
                quantized_data = quantize_int8(weights)
                quantized_size = quantized_data['weights'].nbytes + 16
                compression = original_size / quantized_size

            elif method == "mixed":
                quantized_data, bits = quantize_mixed_precision(weights, name)
                if bits == 8:
                    quantized_size = quantized_data['weights'].nbytes + 16
                else:
                    quantized_size = quantized_data['packed_weights'].nbytes + 16
                compression = original_size / quantized_size

            elif method == "block":
                quantized_data = quantize_block_wise(weights)
                # Estimate size for blocks
                total_block_size = sum(len(block) for block in quantized_data['blocks'])
                scales_size = quantized_data['scales'].nbytes
                zero_points_size = quantized_data['zero_points'].nbytes
                quantized_size = total_block_size + scales_size + zero_points_size + 32
                compression = original_size / quantized_size

            quantized_state[name] = {
                'data': quantized_data,
                'method': method,
                'original_shape': weights.shape
            }

            total_original_size += original_size
            total_quantized_size += quantized_size

            print(f"   ✓ {name}: {original_size/1024:.1f}KB -> {quantized_size/1024:.1f}KB ({compression:.1f}x)")

        else:
            # Keep non-quantizable tensors as-is
            quantized_state[name] = {
                'data': {'weights': param.cpu().numpy(), 'original': True},
                'method': 'none'
            }
            size = param.cpu().numpy().nbytes
            total_original_size += size
            total_quantized_size += size

    overall_compression = total_original_size / total_quantized_size
    print(f"\n📊 {method.upper()} quantization results:")
    print(f"   Original total: {total_original_size / (1024*1024):.1f} MB")
    print(f"   Quantized total: {total_quantized_size / (1024*1024):.1f} MB")
    print(f"   Compression ratio: {overall_compression:.1f}x")
    print(f"   Space saved: {(total_original_size - total_quantized_size) / (1024*1024):.1f} MB")

    return quantized_state

def save_advanced_quantized_model(quantized_state, filepath, method):
    """Save the advanced quantized model"""
    print(f"💾 Saving {method.upper()} quantized model to: {filepath}")

    try:
        # Add method info to the saved state
        save_data = {
            'quantized_state': quantized_state,
            'quantization_method': method,
            'metadata': {
                'version': '1.0',
                'model': 'whisper-medium',
                'quantization': method
            }
        }

        torch.save(save_data, filepath)

        file_size = Path(filepath).stat().st_size / (1024 * 1024)
        print(f"✅ {method.upper()} quantized model saved!")
        print(f"   File size: {file_size:.1f} MB")

        return file_size

    except Exception as e:
        print(f"❌ Error saving model: {e}")
        return 0

def compare_quantization_methods(model):
    """Compare different quantization methods"""
    print("🔍 Comparing Quantization Methods")
    print("=" * 45)

    methods = ["int8", "int4", "mixed", "block"]
    results = {}

    for method in methods:
        print(f"\n📊 Testing {method.upper()} quantization:")
        print("-" * 30)

        quantized_state = advanced_quantization(model, method)
        output_path = f"whisper_medium_{method}_quantized.pth"
        file_size = save_advanced_quantized_model(quantized_state, output_path, method)

        results[method] = {
            'file_size_mb': file_size,
            'quantized_state': quantized_state
        }

    # Summary comparison
    print(f"\n📈 QUANTIZATION COMPARISON SUMMARY")
    print("=" * 45)

    # Original size
    original_size = 1457  # MB (from cache)
    print(f"Original model:     {original_size} MB")

    for method, data in results.items():
        size = data['file_size_mb']
        compression = original_size / size if size > 0 else 0
        savings = original_size - size

        print(f"{method.upper():12} quantized: {size:6.1f} MB ({compression:4.1f}x compression, {savings:6.1f} MB saved)")

    # Recommendations
    print(f"\n💡 RECOMMENDATIONS:")
    print("-" * 20)
    print("• INT8:   Best quality, moderate compression (current)")
    print("• INT4:   Aggressive compression, some quality loss")
    print("• MIXED:  Balanced - quality for critical layers")
    print("• BLOCK:  Best quality for high compression")

def main():
    """Main advanced quantization workflow"""
    print("🚀 Advanced Whisper Model Quantization")
    print("=" * 45)

    # Load original model
    model = load_whisper_model()
    if not model:
        return

    # Compare all quantization methods
    compare_quantization_methods(model)

    print(f"\n✅ Advanced quantization analysis completed!")
    print(f"🎯 Choose the quantization method that best fits your needs:")
    print(f"   • For iOS: INT4 or MIXED for smallest size")
    print(f"   • For quality: BLOCK or INT8")

if __name__ == "__main__":
    main()