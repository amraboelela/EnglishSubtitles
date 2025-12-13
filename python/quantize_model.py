#!/usr/bin/env python3
"""
Quantize WhisperKit CoreML models to reduce size.
Requires: pip install coremltools
"""

import coremltools as ct
import os
from pathlib import Path

def quantize_mlmodelc(input_path, output_path, bits=8):
    """
    Quantize a .mlmodelc CoreML model.

    Args:
        input_path: Path to input .mlmodelc directory
        output_path: Path to output quantized .mlmodelc directory
        bits: Quantization bits (8 for INT8, 4 for INT4)
    """
    print(f"Loading model from {input_path}...")
    model = ct.models.MLModel(input_path)

    print(f"Quantizing to {bits}-bit...")
    if bits == 8:
        quantized_model = ct.models.neural_network.quantization_utils.quantize_weights(
            model, nbits=8
        )
    elif bits == 4:
        quantized_model = ct.models.neural_network.quantization_utils.quantize_weights(
            model, nbits=4
        )
    else:
        raise ValueError("bits must be 4 or 8")

    print(f"Saving quantized model to {output_path}...")
    quantized_model.save(output_path)
    print("Done!")

def quantize_whisper_medium(base_path, output_base_path, bits=8):
    """
    Quantize all components of WhisperKit medium model.
    """
    components = [
        "AudioEncoder.mlmodelc",
        "TextDecoder.mlmodelc",
        "MelSpectrogram.mlmodelc"
    ]

    for component in components:
        input_path = os.path.join(base_path, component)
        output_path = os.path.join(output_base_path, component)

        if os.path.exists(input_path):
            print(f"\n{'='*60}")
            print(f"Quantizing {component}...")
            print(f"{'='*60}")
            quantize_mlmodelc(input_path, output_path, bits=bits)
        else:
            print(f"Warning: {component} not found at {input_path}")

    # Copy non-model files
    import shutil
    for file in ["config.json", "generation_config.json", "tokenizer.json", "tokenizer_config.json"]:
        src = os.path.join(base_path, file)
        dst = os.path.join(output_base_path, file)
        if os.path.exists(src):
            shutil.copy2(src, dst)
            print(f"Copied {file}")

if __name__ == "__main__":
    # Paths
    medium_path = "/Users/amraboelela/develop/swift/EnglishSubtitles/EnglishSubtitles/Models/openai_whisper-medium"
    quantized_path = "/Users/amraboelela/develop/swift/EnglishSubtitles/EnglishSubtitles/Models/openai_whisper-medium_quantized"

    # Create output directory
    os.makedirs(quantized_path, exist_ok=True)

    # Quantize to 8-bit (change to bits=4 for more compression)
    quantize_whisper_medium(medium_path, quantized_path, bits=8)

    print(f"\n{'='*60}")
    print("Quantization complete!")
    print(f"Original model: {medium_path}")
    print(f"Quantized model: {quantized_path}")
    print(f"{'='*60}")
