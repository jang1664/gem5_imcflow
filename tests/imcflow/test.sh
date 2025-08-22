#!/bin/bash

export PYTHONPATH=$PYTHONPATH:/root/project/tvm/tvm_practice/tvm_env/lib/python3.10/site-packages
$GEM5_HOME/build/X86/gem5.opt /root/project/imcflow/pmap/ISA_sim/gem5/configs/imcflow/run_imcflow.py --binary test_imcflow
