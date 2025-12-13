#!/usr/bin/env python3
"""
Simple Quantized Model - No Stupid Archives

Just quantize and save in a simple format you can actually use.
"""

import torch
import whisper
import numpy as np
from pathlib import Path

def simple_quantization():
    """Simple quantization that just works"""
    print("🔧 Simple Quantization (No Archives!)")

    model = whisper.load_model("medium")

    quantized_dict = {}
    total_original = 0
    total_quantized = 0

    for name, param in model.state_dict().items():
        original_size = param.numel() * param.element_size()
        total_original += original_size

        if param.dtype == torch.float32 and len(param.shape) >= 2 and param.numel() > 1000:
            # Large matrices → int8
            weights = param.cpu().numpy()
            w_min = weights.min()
            w_max = weights.max()

            scale = (w_max - w_min) / 254.0
            zero_point = -127 - w_min / scale
            quantized = np.round((weights / scale) + zero_point).astype(np.int8)

            # Store as torch tensor (PyTorch will handle it properly)
            quantized_dict[name] = torch.from_numpy(quantized)
            quantized_dict[name + '_scale'] = torch.tensor(scale, dtype=torch.float32)
            quantized_dict[name + '_zero_point'] = torch.tensor(zero_point, dtype=torch.float32)
            quantized_dict[name + '_is_quantized'] = torch.tensor(True)

            quant_size = quantized.nbytes + 8  # +8 for scale/zero_point
            total_quantized += quant_size

            print(f"INT8:   {name:40} {original_size/1024:6.0f}KB → {quant_size/1024:6.0f}KB")

        elif param.dtype == torch.float32:
            # Small params → float16
            quantized_dict[name] = param.half()  # Convert to float16
            quantized_dict[name + '_is_quantized'] = torch.tensor(False)

            quant_size = param.numel() * 2  # 2 bytes per float16
            total_quantized += quant_size

            print(f"FLOAT16: {name:40} {original_size/1024:6.0f}KB → {quant_size/1024:6.0f}KB")

        else:
            # Keep as-is
            quantized_dict[name] = param
            quantized_dict[name + '_is_quantized'] = torch.tensor(False)
            total_quantized += original_size

    # Save normally (no stupid archives!)
    output_path = "whisper_quantized_simple.pth"
    torch.save(quantized_dict, output_path)

    actual_size = Path(output_path).stat().st_size
    compression = total_original / actual_size

    print(f"\nOriginal:  {total_original/(1024*1024):6.1f} MB")
    print(f"Quantized: {actual_size/(1024*1024):6.1f} MB")
    print(f"Compression: {compression:.1f}x")
    print(f"File: {output_path}")

if __name__ == "__main__":
    simple_quantization()