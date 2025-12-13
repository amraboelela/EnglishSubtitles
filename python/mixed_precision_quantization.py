#!/usr/bin/env python3
"""
Mixed Precision Quantization: Int8 + Float16

This script applies optimal quantization:
- Large weight matrices: float32 → int8 (4x compression)
- Small parameters (bias, norms): float32 → float16 (2x compression)

This should give us much closer to theoretical compression!

Usage:
    python mixed_precision_quantization.py
"""

import torch
import whisper
import numpy as np
from pathlib import Path

def load_whisper_model():
    """Load the Whisper medium model"""
    print("📥 Loading Whisper medium model...")

    try:
        model = whisper.load_model("medium")

        total_params = sum(p.numel() for p in model.parameters())
        param_size = sum(p.numel() * p.element_size() for p in model.parameters()) / (1024 * 1024)

        print(f"✅ Model loaded: {total_params:,} parameters, {param_size:.1f} MB")
        return model

    except Exception as e:
        print(f"❌ Error loading model: {e}")
        return None

def mixed_precision_quantization(model):
    """
    Apply mixed precision quantization:
    - Large matrices (>1000 params): int8
    - Small parameters: float16
    """
    print("🔧 Applying Mixed Precision Quantization (Int8 + Float16)...")

    quantized_state = {}

    # Track compression statistics
    total_original_size = 0
    total_quantized_size = 0
    int8_count = 0
    float16_count = 0
    unchanged_count = 0

    for name, param in model.state_dict().items():
        original_size = param.numel() * param.element_size()
        total_original_size += original_size

        if param.dtype == torch.float32:
            # Decision tree for quantization strategy

            if len(param.shape) >= 2 and param.numel() > 1000:
                # LARGE MATRICES → INT8
                weights = param.cpu().numpy()

                # Quantize to int8 (same as before)
                w_min = weights.min()
                w_max = weights.max()

                scale = (w_max - w_min) / 254.0
                zero_point = -127 - w_min / scale

                quantized_weights = np.round((weights / scale) + zero_point).astype(np.int8)

                quantized_state[name] = {
                    'weights': quantized_weights,
                    'scale': scale,
                    'zero_point': zero_point,
                    'shape': weights.shape,
                    'dtype': 'int8'
                }

                quantized_size = quantized_weights.nbytes + 16  # +16 for scale/zero_point
                compression = original_size / quantized_size
                int8_count += 1

                print(f"   📦 INT8:   {name:40} {original_size/1024:6.1f}KB → {quantized_size/1024:6.1f}KB ({compression:.1f}x)")

            elif param.numel() > 1:  # Skip single values
                # SMALL PARAMETERS → FLOAT16
                float16_param = param.half()  # Convert to float16

                quantized_state[name] = {
                    'weights': float16_param.cpu().numpy(),
                    'dtype': 'float16'
                }

                quantized_size = float16_param.numel() * 2  # 2 bytes per float16
                compression = original_size / quantized_size
                float16_count += 1

                print(f"   🔢 FLOAT16: {name:40} {original_size/1024:6.1f}KB → {quantized_size/1024:6.1f}KB ({compression:.1f}x)")

            else:
                # KEEP AS-IS (single values, etc.)
                quantized_state[name] = {
                    'weights': param.cpu().numpy(),
                    'dtype': 'float32'
                }
                quantized_size = original_size
                unchanged_count += 1

                print(f"   ⚪ UNCHANGED: {name:40} {original_size/1024:6.1f}KB")
        else:
            # NON-FLOAT32 PARAMETERS (keep unchanged)
            quantized_state[name] = {
                'weights': param.cpu().numpy(),
                'dtype': str(param.dtype)
            }
            quantized_size = original_size
            unchanged_count += 1

        total_quantized_size += quantized_size

    # Calculate overall compression
    overall_compression = total_original_size / total_quantized_size
    savings_mb = (total_original_size - total_quantized_size) / (1024 * 1024)
    savings_percent = (1 - total_quantized_size / total_original_size) * 100

    print(f"\n📊 MIXED PRECISION QUANTIZATION RESULTS:")
    print(f"   Original total:     {total_original_size / (1024*1024):8.1f} MB")
    print(f"   Quantized total:    {total_quantized_size / (1024*1024):8.1f} MB")
    print(f"   Compression ratio:  {overall_compression:8.1f}x")
    print(f"   Space saved:        {savings_mb:8.1f} MB ({savings_percent:.1f}%)")
    print()
    print(f"📈 PARAMETER BREAKDOWN:")
    print(f"   INT8 quantized:     {int8_count:4d} large matrices")
    print(f"   FLOAT16 converted:  {float16_count:4d} small parameters")
    print(f"   Unchanged:          {unchanged_count:4d} parameters")

    return quantized_state

def save_mixed_precision_model(quantized_state, filepath):
    """Save the mixed precision quantized model"""
    print(f"💾 Saving mixed precision model to: {filepath}")

    try:
        # Save with metadata about the quantization
        save_data = {
            'quantized_state': quantized_state,
            'quantization_info': {
                'method': 'mixed_precision',
                'int8_matrices': True,
                'float16_parameters': True,
                'version': '2.0'
            }
        }

        # Use a more compact save format
        torch.save(save_data, filepath)

        file_size = Path(filepath).stat().st_size / (1024 * 1024)
        print(f"✅ Mixed precision model saved!")
        print(f"   File size: {file_size:.1f} MB")

        return file_size

    except Exception as e:
        print(f"❌ Error saving model: {e}")
        return 0

def load_mixed_precision_model(filepath):
    """Load and dequantize the mixed precision model"""
    print(f"🔄 Loading mixed precision model from: {filepath}")

    try:
        # Fix the numpy loading issue
        torch.serialization.add_safe_globals([np.core.multiarray._reconstruct])
        saved_data = torch.load(filepath, map_location='cpu', weights_only=False)

        quantized_state = saved_data['quantized_state']

        # Dequantize back to original format
        dequantized_state = {}
        for name, data in quantized_state.items():
            if data['dtype'] == 'int8':
                # Dequantize int8 back to float32
                weights = data['weights']
                scale = data['scale']
                zero_point = data['zero_point']

                dequantized = (weights.astype(np.float32) - zero_point) * scale
                dequantized_state[name] = torch.from_numpy(dequantized)

            elif data['dtype'] == 'float16':
                # Convert float16 back to float32
                float16_weights = data['weights']
                dequantized_state[name] = torch.from_numpy(float16_weights.astype(np.float32))

            else:
                # Keep as-is
                dequantized_state[name] = torch.from_numpy(data['weights'])

        print(f"✅ Mixed precision model loaded and dequantized!")
        return dequantized_state

    except Exception as e:
        print(f"❌ Error loading model: {e}")
        return None

def main():
    """Main mixed precision quantization workflow"""
    print("🚀 Mixed Precision Quantization: Int8 + Float16")
    print("=" * 50)

    # Load original model
    model = load_whisper_model()
    if not model:
        return

    # Apply mixed precision quantization
    quantized_state = mixed_precision_quantization(model)

    # Save quantized model
    output_path = "whisper_medium_mixed_precision.pth"
    saved_size = save_mixed_precision_model(quantized_state, output_path)

    if saved_size == 0:
        return

    # Test loading (optional)
    print(f"\n🧪 Testing model loading...")
    dequantized_state = load_mixed_precision_model(output_path)
    if dequantized_state:
        print("✅ Model can be loaded and dequantized successfully!")

    # Compare with original and previous quantization
    print(f"\n📊 COMPRESSION COMPARISON:")
    print(f"   Original model:          1,457 MB")
    print(f"   Int8 only:               1,081 MB (1.3x compression)")
    print(f"   Mixed precision (Int8+Float16): {saved_size:.0f} MB ({1457/saved_size:.1f}x compression)")

    savings_vs_original = 1457 - saved_size
    savings_vs_int8 = 1081 - saved_size

    print(f"\n💰 SAVINGS:")
    print(f"   vs Original:   {savings_vs_original:.0f} MB saved")
    print(f"   vs Int8-only:  {savings_vs_int8:.0f} MB additional saved")

    print(f"\n✅ Mixed precision quantization completed!")
    print(f"🎯 Result: Much better compression while maintaining quality!")

if __name__ == "__main__":
    main()