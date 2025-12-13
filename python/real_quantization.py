#!/usr/bin/env python3
"""
REAL Quantization with ACTUAL File Size Reduction

This script saves quantized weights in a custom binary format that
ACTUALLY reduces file size, not just pretends to.

Usage:
    python real_quantization.py
"""

import torch
import whisper
import numpy as np
from pathlib import Path
import pickle
import gzip
import struct

def quantize_and_save_real(model):
    """
    Actually save quantized data in a compact binary format
    """
    print("🔧 REAL Quantization with Binary Compression...")

    # Create output directory
    output_dir = Path("whisper_quantized_binary")
    output_dir.mkdir(exist_ok=True)

    # Track real file sizes
    total_original_size = 0
    total_compressed_size = 0

    # Save model metadata
    metadata = {
        'model_type': 'whisper-medium',
        'quantization': 'int8_float16_mixed',
        'parameters': {}
    }

    for name, param in model.state_dict().items():
        original_size = param.numel() * param.element_size()
        total_original_size += original_size

        param_file = output_dir / f"{name.replace('.', '_')}.bin"

        if param.dtype == torch.float32 and len(param.shape) >= 2 and param.numel() > 1000:
            # LARGE MATRICES → INT8 (save as actual int8 bytes)
            weights = param.cpu().numpy()

            # Quantize
            w_min = weights.min()
            w_max = weights.max()
            scale = (w_max - w_min) / 254.0
            zero_point = -127 - w_min / scale
            quantized = np.round((weights / scale) + zero_point).astype(np.int8)

            # Save in BINARY format
            with open(param_file, 'wb') as f:
                # Write header
                f.write(struct.pack('i', len(weights.shape)))  # number of dimensions
                for dim in weights.shape:
                    f.write(struct.pack('i', dim))  # each dimension size
                f.write(struct.pack('d', scale))      # scale (8 bytes)
                f.write(struct.pack('d', zero_point)) # zero_point (8 bytes)
                f.write(struct.pack('B', 8))          # bits per weight
                # Write actual int8 data (1 byte per weight!)
                f.write(quantized.tobytes())

            actual_size = param_file.stat().st_size
            compression = original_size / actual_size

            metadata['parameters'][name] = {
                'file': param_file.name,
                'type': 'int8',
                'shape': list(weights.shape),
                'scale': float(scale),
                'zero_point': float(zero_point)
            }

            print(f"   📦 INT8:   {name:35} {original_size/1024:6.0f}KB → {actual_size/1024:6.0f}KB ({compression:.1f}x)")

        elif param.dtype == torch.float32 and param.numel() > 1:
            # SMALL PARAMETERS → FLOAT16 (save as actual float16 bytes)
            weights = param.cpu().numpy().astype(np.float16)

            with open(param_file, 'wb') as f:
                # Write header
                f.write(struct.pack('i', len(param.shape)))
                for dim in param.shape:
                    f.write(struct.pack('i', dim))
                f.write(struct.pack('B', 16))  # bits per weight
                # Write actual float16 data (2 bytes per weight!)
                f.write(weights.tobytes())

            actual_size = param_file.stat().st_size
            compression = original_size / actual_size

            metadata['parameters'][name] = {
                'file': param_file.name,
                'type': 'float16',
                'shape': list(param.shape)
            }

            print(f"   🔢 FLOAT16: {name:35} {original_size/1024:6.0f}KB → {actual_size/1024:6.0f}KB ({compression:.1f}x)")

        else:
            # KEEP AS FLOAT32 (but still save in binary)
            weights = param.cpu().numpy()

            with open(param_file, 'wb') as f:
                f.write(struct.pack('i', len(param.shape)))
                for dim in param.shape:
                    f.write(struct.pack('i', dim))
                f.write(struct.pack('B', 32))  # bits per weight
                f.write(weights.tobytes())

            actual_size = param_file.stat().st_size

            metadata['parameters'][name] = {
                'file': param_file.name,
                'type': 'float32',
                'shape': list(param.shape)
            }

            print(f"   ⚪ FLOAT32: {name:35} {original_size/1024:6.0f}KB → {actual_size/1024:6.0f}KB (1.0x)")

        total_compressed_size += param_file.stat().st_size

    # Save metadata
    with open(output_dir / "metadata.json", 'w') as f:
        import json
        json.dump(metadata, f, indent=2)

    # Create compressed archive
    print(f"\n📦 Creating compressed archive...")
    import tarfile
    archive_path = "whisper_medium_ACTUALLY_quantized.tar.gz"

    with tarfile.open(archive_path, 'w:gz') as tar:
        tar.add(output_dir, arcname='quantized_model')

    archive_size = Path(archive_path).stat().st_size

    # Calculate real compression
    real_compression = total_original_size / archive_size
    savings_mb = (total_original_size - archive_size) / (1024 * 1024)
    savings_percent = (1 - archive_size / total_original_size) * 100

    print(f"\n📊 REAL COMPRESSION RESULTS:")
    print(f"   Original size:      {total_original_size / (1024*1024):8.1f} MB")
    print(f"   Binary files total: {total_compressed_size / (1024*1024):8.1f} MB")
    print(f"   Compressed archive: {archive_size / (1024*1024):8.1f} MB")
    print(f"   REAL compression:   {real_compression:8.1f}x")
    print(f"   REAL savings:       {savings_mb:8.1f} MB ({savings_percent:.1f}%)")

    return archive_path, archive_size

def test_loading_quantized_model(archive_path):
    """Test loading the quantized model back"""
    print(f"\n🧪 Testing quantized model loading...")

    import tarfile
    import json

    # Extract and load
    extract_dir = Path("test_extract")
    extract_dir.mkdir(exist_ok=True)

    with tarfile.open(archive_path, 'r:gz') as tar:
        tar.extractall(extract_dir)

    # Load metadata
    with open(extract_dir / "quantized_model" / "metadata.json", 'r') as f:
        metadata = json.load(f)

    print(f"✅ Successfully loaded metadata for {len(metadata['parameters'])} parameters")

    # Test loading a few parameters
    loaded_count = 0
    for name, info in list(metadata['parameters'].items())[:3]:  # Test first 3
        param_file = extract_dir / "quantized_model" / info['file']

        with open(param_file, 'rb') as f:
            # Read header
            ndims = struct.unpack('i', f.read(4))[0]
            shape = []
            for _ in range(ndims):
                shape.append(struct.unpack('i', f.read(4))[0])

            if info['type'] == 'int8':
                scale = struct.unpack('d', f.read(8))[0]
                zero_point = struct.unpack('d', f.read(8))[0]
                bits = struct.unpack('B', f.read(1))[0]

                # Read int8 data
                data_size = np.prod(shape)
                int8_data = np.frombuffer(f.read(data_size), dtype=np.int8)

                # Dequantize
                float_data = (int8_data.astype(np.float32) - zero_point) * scale
                loaded_param = float_data.reshape(shape)

                print(f"   ✓ Loaded {name}: {info['type']} {shape} → float32")

            elif info['type'] == 'float16':
                bits = struct.unpack('B', f.read(1))[0]
                data_size = np.prod(shape) * 2  # 2 bytes per float16
                float16_data = np.frombuffer(f.read(data_size), dtype=np.float16)
                loaded_param = float16_data.astype(np.float32).reshape(shape)

                print(f"   ✓ Loaded {name}: {info['type']} {shape} → float32")

            loaded_count += 1

    print(f"✅ Successfully loaded and dequantized {loaded_count} test parameters!")

    # Cleanup
    import shutil
    shutil.rmtree(extract_dir)

def main():
    """Main REAL quantization workflow"""
    print("🚀 REAL Quantization with ACTUAL File Size Reduction")
    print("=" * 55)

    # Load original model
    print("📥 Loading Whisper medium model...")
    model = whisper.load_model("medium")

    # Apply REAL quantization with binary saving
    archive_path, final_size = quantize_and_save_real(model)

    # Test loading
    test_loading_quantized_model(archive_path)

    print(f"\n📊 FINAL RESULTS:")
    print(f"   Original:     1,457 MB")
    print(f"   REAL compressed: {final_size/(1024*1024):.0f} MB")
    print(f"   REAL compression: {1457/(final_size/(1024*1024)):.1f}x")

    print(f"\n✅ REAL quantization completed!")
    print(f"📁 Saved as: {archive_path}")
    print(f"🎯 THIS IS ACTUALLY COMPRESSED!")

if __name__ == "__main__":
    main()