// packages
${IMCFLOW_DIR}/pmap/packages/imcflow_pkg.sv
${IMCFLOW_DIR}/pmap/packages/imcu_pkg.sv
${IMCFLOW_DIR}/pmap/packages/imce_pkg.sv
${IMCFLOW_DIR}/pmap/packages/intf_node_pkg.sv
${IMCFLOW_DIR}/pmap/packages/router_pkg.sv
${IMCFLOW_DIR}/pmap/packages/axi_pkg.sv
${IMCFLOW_DIR}/pmap/packages/tcdm_pkg.sv
${IMCFLOW_DIR}/pmap/packages/utils_pkg.sv
${IMCFLOW_DIR}/pmap/packages/uuid_generator_pkg.sv

// interfaces
${IMCFLOW_DIR}/pmap/interfaces/debug_if.sv
${IMCFLOW_DIR}/pmap/interfaces/flow_if.sv
${IMCFLOW_DIR}/pmap/interfaces/imce_if.sv
${IMCFLOW_DIR}/pmap/interfaces/intf_node_pipe_if.sv
${IMCFLOW_DIR}/pmap/interfaces/rv_transfer_if.sv
${IMCFLOW_DIR}/pmap/interfaces/tcdm_intf.sv

// imce.common_cells
${IMCFLOW_DIR}/pmap/modules/common_cells/source/prioenc.sv
${IMCFLOW_DIR}/pmap/modules/common_cells/source/ones_comparator.sv
${IMCFLOW_DIR}/pmap/modules/common_cells/source/ones_counter.sv
${IMCFLOW_DIR}/pmap/modules/common_cells/source/modN_counter.sv
${IMCFLOW_DIR}/pmap/modules/common_cells/source/tc_sram.sv
${IMCFLOW_DIR}/pmap/modules/common_cells/source/fifo_imce_t.sv
// imce.imcu_core
${IMCFLOW_DIR}/pmap/modules/imce/imcu/source/imcu.sv
${IMCFLOW_DIR}/pmap/modules/imce/imcu_core/source/imcu_ctrl.sv
${IMCFLOW_DIR}/pmap/modules/imce/imcu_core/source/imcu_core.sv
${IMCFLOW_DIR}/pmap/modules/imce/post_imcu/source/post_imcu.sv
${IMCFLOW_DIR}/pmap/modules/imce/post_imcu/source/serializer.sv
// imce.linebuffer
${IMCFLOW_DIR}/pmap/modules/imce/linebuffer/source/addr_shfl_gen.sv
${IMCFLOW_DIR}/pmap/modules/imce/linebuffer/source/bitshiftreg.sv
${IMCFLOW_DIR}/pmap/modules/imce/linebuffer/source/linebuffer_datapath.sv
${IMCFLOW_DIR}/pmap/modules/imce/linebuffer/source/lineshuffle.sv
${IMCFLOW_DIR}/pmap/modules/imce/linebuffer/source/wmask_gen.sv
${IMCFLOW_DIR}/pmap/modules/imce/linebuffer/source/linebuffer.sv
// imce.decoder
${IMCFLOW_DIR}/pmap/modules/imce/decoder/source/decoder.sv
${IMCFLOW_DIR}/pmap/modules/imce/decoder/source/type_decoder.sv
// imce.vpu
${IMCFLOW_DIR}/pmap/modules/imce/vpu/source/vpu.sv
// imce.regfile
${IMCFLOW_DIR}/pmap/modules/imce/regfile/source/extended_regfile.sv
${IMCFLOW_DIR}/pmap/modules/imce/regfile/source/regfile.sv
// imce
${IMCFLOW_DIR}/pmap/modules/imce/source/imce_fsm.sv
${IMCFLOW_DIR}/pmap/modules/imce/source/pc_gen.sv
${IMCFLOW_DIR}/pmap/modules/imce/source/imce.sv
${IMCFLOW_DIR}/pmap/modules/imce/source/imem.sv
${IMCFLOW_DIR}/pmap/modules/imce/source/imce_datapath.sv
${IMCFLOW_DIR}/pmap/modules/imce/source/imce_ctrl.sv
${IMCFLOW_DIR}/pmap/modules/imce/source/hw_loop.sv
${IMCFLOW_DIR}/pmap/modules/imce/source/hazard_detector.sv
${IMCFLOW_DIR}/pmap/modules/imce/source/fifo_block.sv
${IMCFLOW_DIR}/pmap/modules/imce/source/ctrl_pipeline.sv
${IMCFLOW_DIR}/pmap/modules/imce/source/scan_control.sv

// router
${IMCFLOW_DIR}/pmap/modules/router/source/input_block.sv
${IMCFLOW_DIR}/pmap/modules/router/source/arbiter.sv
${IMCFLOW_DIR}/pmap/modules/router/source/crossbar.sv
${IMCFLOW_DIR}/pmap/modules/router/source/chunk_selector.sv
${IMCFLOW_DIR}/pmap/modules/router/source/policy_table.sv
${IMCFLOW_DIR}/pmap/modules/router/source/policy_table_decoder.sv
${IMCFLOW_DIR}/pmap/modules/router/source/rx_policy_decoder.sv
${IMCFLOW_DIR}/pmap/modules/router/source/tx_selector.sv
${IMCFLOW_DIR}/pmap/modules/router/source/router.sv

// interface node
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/type_decoder_intf_node.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/decoder_intf_node.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/reg_file_intf_node.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/ctrl_generator.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/recv_fifo_block.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/send_fifo_block.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/send_fifo.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/packet_packer.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/imem_intf_node.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/pc_gen_intf_node.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/intf_node_fsm.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/intf_node.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/IF_stage.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/IF_ID_pipe.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/ID_stage.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/ID_EX_pipe.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/EX_stage.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/EX_MEM_pipe.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/MEM_stage.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/MEM_WB_pipe.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/WB_stage.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/forward_control.sv
${IMCFLOW_DIR}/pmap/modules/interface_node_pipe/source/hazard_control.sv

${IMCFLOW_DIR}/pmap/modules/top/source/axi/fifo_v1.sv
${IMCFLOW_DIR}/pmap/modules/top/source/axi/fifo_v2.sv
${IMCFLOW_DIR}/pmap/modules/top/source/tcdm/addr_decode.sv
${IMCFLOW_DIR}/pmap/modules/top/source/tcdm/tcdm_demux.sv
${IMCFLOW_DIR}/pmap/modules/top/source/tcdm/slave_bridge.sv
${IMCFLOW_DIR}/pmap/modules/top/source/tcdm/aggregator.sv
${IMCFLOW_DIR}/pmap/modules/top/source/tcdm/tcdm_pipe_req.sv
${IMCFLOW_DIR}/pmap/modules/top/source/tcdm/tcdm_pipe_req_v2.sv
${IMCFLOW_DIR}/pmap/modules/top/source/tcdm/tcdm_pipe_rsp.sv
${IMCFLOW_DIR}/pmap/modules/top/source/controller.sv
${IMCFLOW_DIR}/pmap/modules/top/source/imcflow_impl.sv


${IMCFLOW_DIR}/pmap/interfaces/axi_intf.sv
${IMCFLOW_DIR}/pmap/modules/top/source/bridge/axi_2_tcdm.sv
${IMCFLOW_DIR}/pmap/modules/top/source/bridge/axi_2_tcdm_wrap.sv
${IMCFLOW_DIR}/pmap/modules/top/source/bridge/axi_read_write_ctrl.sv
${IMCFLOW_DIR}/pmap/modules/top/source/axi/axi_ar_buffer.sv
${IMCFLOW_DIR}/pmap/modules/top/source/axi/axi_aw_buffer.sv
${IMCFLOW_DIR}/pmap/modules/top/source/axi/axi_b_buffer.sv
${IMCFLOW_DIR}/pmap/modules/top/source/axi/axi_r_buffer.sv
${IMCFLOW_DIR}/pmap/modules/top/source/axi/axi_w_buffer.sv
${IMCFLOW_DIR}/pmap/modules/top/source/axi/axi_single_slice.sv
${IMCFLOW_DIR}/pmap/modules/top/source/imcflow_axi_wrapper.sv
${IMCFLOW_DIR}/pmap/modules/top/source/imcflow_with_axi.sv
