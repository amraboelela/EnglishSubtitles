#!/usr/bin/env python3
"""
Test CoreML Quantization APIs

Check what quantization methods are actually available in this version of coremltools.
"""

import coremltools as ct
import numpy as np

def check_quantization_apis():
    """Check what quantization methods are available"""
    print("🔍 Checking available CoreML quantization APIs...")
    print(f"CoreMLTools version: {ct.__version__}")

    # Check optimize module
    if hasattr(ct, 'optimize'):
        print("✅ ct.optimize module available")

        if hasattr(ct.optimize, 'coreml'):
            print("✅ ct.optimize.coreml available")

            # Check what methods are available
            coreml_optimize = ct.optimize.coreml
            methods = [method for method in dir(coreml_optimize) if not method.startswith('_')]
            print(f"📋 Available methods: {methods}")

            # Check for quantization methods
            quantization_methods = [method for method in methods if 'quantiz' in method.lower()]
            print(f"🎯 Quantization methods: {quantization_methods}")

        else:
            print("❌ ct.optimize.coreml not available")
    else:
        print("❌ ct.optimize module not available")

    # Check old API
    if hasattr(ct.models, 'neural_network'):
        if hasattr(ct.models.neural_network, 'quantization_utils'):
            print("✅ Old quantization API available")
        else:
            print("❌ Old quantization API not available")

    # Check compression module
    if hasattr(ct, 'compression'):
        print("✅ ct.compression module available")
        compression_methods = [method for method in dir(ct.compression) if not method.startswith('_')]
        print(f"📋 Compression methods: {compression_methods}")
    else:
        print("❌ ct.compression not available")

def check_precision_options():
    """Check available precision options"""
    print("\n🎯 Checking precision options...")

    if hasattr(ct, 'precision'):
        precision_options = [attr for attr in dir(ct.precision) if not attr.startswith('_')]
        print(f"📋 Available precisions: {precision_options}")

        # Check specific ones
        for precision in ['FLOAT16', 'FLOAT32', 'INT8', 'INT16']:
            if hasattr(ct.precision, precision):
                print(f"✅ {precision} available")
            else:
                print(f"❌ {precision} not available")

def main():
    check_quantization_apis()
    check_precision_options()

if __name__ == "__main__":
    main()