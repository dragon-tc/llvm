// Copyright (c) 2012 Qualcomm Technologies, Inc.  All Rights Reserved.
// Qualcomm Technologies Proprietary and Confidential
//
//=- Krait2Schedule.td - Krait pass2 Scheduling Definitions -*- tablegen -*-=//
//
//                     The LLVM Compiler Infrastructure
//
//===----------------------------------------------------------------------===//
//
// This file defines the itinerary class data for the Krait processors.
// ===---------------------------------------------------------------------===//
// This section contains legacy support for itineraries. This is
// required until SD and PostRA schedulers are replaced by MachineScheduler.
//
//===----------------------------------------------------------------------===//
//
// Scheduling information derived from Krait Code Generation Guidelines
// 80-VE670-6 Rev. A.
//
// Assumptions:
// - In krait all functional units are fully pipelined.
// - Instructions can use B, L, Y, S, M, X, and Z integer pipelines and
//   VX, VS, VL NEON/VFP pipelines.
// - B pipeline:
//   unconditional PC relative branch
//   conditional non-linking PC relative branch
//   mov immediate
//   paired movw/movt
// - L pipeline:
//   load
// - Y pipeline:
//   simple and complex integer instructions
//   branches
// - S pipeline:
//   store
// - M pipeline:
//   integer MULT/MAC/DIV
// - X pipeline:
//   simple and complex integer instructions
//   branches
// - Z pipeline:
//   simple integer instructions (but with no CPSR update)
//   integer divide
//   unconditional pc-relative branches
// - VX pipeline:
//   P and SIMD arithmetic and logical instructions
// - VS pipeline:
//   VFP store
// - VL pipeline:
//   VFP load and permute
// - Multiplexor to allow VFP and NEON share the VFP register file and
//   to allow integer and VFP/NEON access shared LSUnit.
// - Fetch width: 4 instructions per clock cycle
// - Issue width: (into Instruction Queue) is 4 instructions per clock cycle
// - Dispatch witdth:  10 instructions per clock cycle (7 integer + 3 NEON/VFP)
//   to keep the 3 pipelines (S/Y, X, VS/VX) full.
// - Instruction Queue size is 10 instructions.
// - Modeling the issue width as 2 instructions per clock cycle,
//   and assuming this is the look-ahead capability of the processor.
//
// Note:
//- We do not have complete information on instructions throughput,
// input operands read cycles and wbck cycles.
// So we reuse values from the A9 scheduler.

// Functional units
def KRT2_Issue0  : FuncUnit; // Issue 0
def KRT2_Issue1  : FuncUnit; // Issue 1
def KRT2_Y       : FuncUnit;
def KRT2_X       : FuncUnit;
def KRT2_M       : FuncUnit;
def KRT2_B       : FuncUnit;
def KRT2_Z       : FuncUnit;
def KRT2_L       : FuncUnit;
def KRT2_S       : FuncUnit;
def KRT2_VX      : FuncUnit;
def KRT2_VL      : FuncUnit;
def KRT2_VS      : FuncUnit;
def KRT2_MUX0    : FuncUnit; // Integer + NEON/FPU multiplexer
def KRT2_LSUnit  : FuncUnit; // L/S Unit
def KRT2_DRegsVFP: FuncUnit; // FP register set, VFP side
def KRT2_DRegsN  : FuncUnit; // FP register set, NEON side

// Bypasses
def KRT2_LdBypass : Bypass;

def Krait2Itineraries : ProcessorItineraries<
  [KRT2_Issue0, KRT2_Issue1,
   KRT2_X, KRT2_Y, KRT2_M, KRT2_B, KRT2_Z, KRT2_L, KRT2_S,
   KRT2_VX, KRT2_VL, KRT2_VS,
   KRT2_MUX0, KRT2_LSUnit,
   KRT2_DRegsVFP, KRT2_DRegsN],
  [KRT2_LdBypass], [
  // Two fully-pipelined integer ALU pipelines

  //
  // Move instructions, unconditional
  InstrItinData<IIC_iMOVi   , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B, KRT2_Z]>], [1]>,
  InstrItinData<IIC_iMOVr   , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y, KRT2_Z]>], [1, 1]>,

  // shift by immediate has latency= 2 Throughput= 1
  // Note: LSL 2 has latency= 1 Throughput= 1
  InstrItinData<IIC_iMOVsi  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B, KRT2_Z]>], [2, 1]>,

  // shift by register has latency= 3 Throughput= 2
  InstrItinData<IIC_iMOVsr  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<2, [KRT2_X, KRT2_Y]>], [3, 1, 1]>,

  InstrItinData<IIC_iMOVix2 , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B, KRT2_Z]>,
                               InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B, KRT2_Z]>], [2]>,
  InstrItinData<IIC_iMOVix2addpc,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                  InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B, KRT2_Z]>,
                                  InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B, KRT2_Z]>,
                                  InstrStage<1, [KRT2_X, KRT2_Y, KRT2_Z]>], [3]>,
  InstrItinData<IIC_iMOVix2ld,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B, KRT2_Z]>,
                               InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B, KRT2_Z]>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_L], 0>,
                               InstrStage<1, [KRT2_LSUnit]>], [5]>,
  //
  // MVN instructions
  InstrItinData<IIC_iMVNi   , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B, KRT2_Z]>],
                              [1]>,
  InstrItinData<IIC_iMVNr   , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y, KRT2_Z]>],
                              [1, 1], [NoBypass, KRT2_LdBypass]>,

  // shift by immediate has latency= 2 Throughput= 1
  // Note: LSL 2 has latency= 1 Throughput= 1
  InstrItinData<IIC_iMVNsi  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B, KRT2_Z]>],
                              [2, 1]>,

  // shift by register has latency= 3 Throughput= 2
  InstrItinData<IIC_iMVNsr  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<2, [KRT2_X, KRT2_Y]>],
                              [3, 1, 1]>,
  //
  // No operand cycles
  // Note: itinerary used by Thumb2 IT
  InstrItinData<IIC_iALUx   , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_Y]>]>,
  //
  // Binary Instructions that produce a result
  InstrItinData<IIC_iALUi , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<1, [KRT2_X, KRT2_Y, KRT2_Z]>],
                            [1, 1], [NoBypass, KRT2_LdBypass]>,
  InstrItinData<IIC_iALUr , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<1, [KRT2_X, KRT2_Y, KRT2_Z]>],
                            [1, 1, 1], [NoBypass, KRT2_LdBypass, KRT2_LdBypass]>,

  // shift by immediate has latency= 2 Throughput= 1
  // (includes parallel add/sub
  // Note: LSL 2 has latency= 1 Throughput= 1
  InstrItinData<IIC_iALUsi, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<1, [KRT2_X, KRT2_Y, KRT2_Z]>],
                            [2, 1, 1], [NoBypass, KRT2_LdBypass, NoBypass]>,

  // shift by register has latency= 3 Throughput= 2
  InstrItinData<IIC_iALUsir,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<2, [KRT2_X, KRT2_Y]>],
                            [3, 1, 1], [NoBypass, NoBypass, KRT2_LdBypass]>,

  // shift by register has latency= 3 Throughput= 2
  InstrItinData<IIC_iALUsr, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<2, [KRT2_X, KRT2_Y]>],
                            [3, 1, 1, 1],
                            [NoBypass, KRT2_LdBypass, NoBypass, NoBypass]>,

  //Integer parallel add and sub  has latency= 2 Throughput= 1
  InstrItinData<IIC_iALUpr , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<1, [KRT2_X, KRT2_Y, KRT2_Z]>],
                            [2, 1, 1], [NoBypass, KRT2_LdBypass, KRT2_LdBypass]>,
  //
  // Bitwise Instructions that produce a result
  InstrItinData<IIC_iBITi , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<1, [KRT2_X, KRT2_Y, KRT2_Z]>], [1, 1]>,
  InstrItinData<IIC_iBITr , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<1, [KRT2_X, KRT2_Y, KRT2_Z]>], [1, 1, 1]>,

  // shift by immediate has latency= 2 Throughput= 1
  // Note: LSL 2 has latency= 1 Throughput= 1
  InstrItinData<IIC_iBITsi, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<1, [KRT2_X, KRT2_Y, KRT2_Z]>], [2, 1, 1]>,

  // shift by register has latency= 3 Throughput= 2
  InstrItinData<IIC_iBITsr, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<2, [KRT2_X, KRT2_Y]>], [3, 1, 1, 1]>,
  //
  // Unary Instructions that produce a result

  // CLZ, RBIT, etc.
  InstrItinData<IIC_iUNAr , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<1, [KRT2_X]>], [1, 1]>,

  // BFC, BFI, UBFX, SBFX
  // shift by immediate has latency= 2 Throughput= 1
  // Note: LSL 2 has latency= 1 Throughput= 1
  InstrItinData<IIC_iUNAsi, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<1, [KRT2_X, KRT2_Y, KRT2_Z]>], [2, 1]>,

  //
  // Zero and sign extension instructions
  InstrItinData<IIC_iEXTr , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<1, [KRT2_X, KRT2_Y, KRT2_Z]>], [2, 1]>,
  InstrItinData<IIC_iEXTAr, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<2, [KRT2_X, KRT2_Y, KRT2_Z]>], [3, 1, 1]>,

  // shift by register has latency= 3 Throughput= 2
  InstrItinData<IIC_iEXTAsr,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<2, [KRT2_X, KRT2_Y, KRT2_Z]>], [3, 1, 1, 1]>,
  //
  // Compare instructions
  InstrItinData<IIC_iCMPi   , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y]>],
                               [1], [KRT2_LdBypass]>,
  InstrItinData<IIC_iCMPr   , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y]>],
                               [1, 1], [KRT2_LdBypass, KRT2_LdBypass]>,

  // shift by immediate has latency= 2 Throughput= 1
  // Note: LSL 2 has latency= 1 Throughput= 1
  InstrItinData<IIC_iCMPsi  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y]>],
                                [2, 1], [KRT2_LdBypass, NoBypass]>,

  // shift by register has latency= 3 Throughput= 2
  InstrItinData<IIC_iCMPsr  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<2, [KRT2_X, KRT2_Y]>],
                              [3, 1, 1], [KRT2_LdBypass, NoBypass, NoBypass]>,
  //
  // Test instructions
  InstrItinData<IIC_iTSTi   , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y]>], [1]>,
  InstrItinData<IIC_iTSTr   , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y]>], [1, 1]>,

  // shift by immediate has latency= 2 Throughput= 1
  // Note: LSL 2 has latency= 1 Throughput= 1
  InstrItinData<IIC_iTSTsi  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y]>], [2, 1]>,

  // shift by register has latency= 3 Throughput= 2
  InstrItinData<IIC_iTSTsr  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<2, [KRT2_X, KRT2_Y]>], [3, 1, 1]>,
  //
  // Move instructions, conditional
  // FIXME: Correctly model the extra input dep on the destination.
  InstrItinData<IIC_iCMOVi  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B]>], [1]>,
  InstrItinData<IIC_iCMOVr  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y]>], [1, 1]>,

  // shift by immediate has latency= 2 Throughput= 1
  // Note: LSL 2 has latency= 1 Throughput= 1
  InstrItinData<IIC_iCMOVsi , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B]>], [2, 1]>,

  // shift by register has latency= 3 Throughput= 2
  InstrItinData<IIC_iCMOVsr , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<2, [KRT2_X, KRT2_Y]>], [3, 1, 1]>,
  InstrItinData<IIC_iCMOVix2, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B]>,
                               InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B]>], [2]>,

  // Integer multiply pipeline
  // The latency and throughput of integer multiply and multiply accumulate
  // vary a lot. See Krait Code Generation Guidelines.
  // - Assigning IIC_iMAC32, IIC_iMUL32, IIC_iMAC64, IIC_iMUL64, IIC_iMAC16, IIC_iMUL16
  //   the max latency and throughput  among all the instructions that use these itineraries
  // - New itineraries were created for the dual and dual long forms which
  //   had been originally defined with NoItinerary.

  // IIC_iMUL16:
  // SMULxy latency = 4, Throughput= 1; SMULWy  latency= 5, Throughput = 2
  InstrItinData<IIC_iMUL16  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<2, [KRT2_M]>], [5, 1, 1]>,

  // IIC_iMAC16:
  // SMLAxy latency = 4, Throughput = 1; SMLAWy latency = 5, Throughput = 2
  InstrItinData<IIC_iMAC16  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<2, [KRT2_M]>],
                              [5, 1, 1, 1]>,

  // IIC_iMUL32:
  // MUL latency = 5 Throughput = 2; SMMUL latency = 6 Throughput = 3
  InstrItinData<IIC_iMUL32  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<3, [KRT2_M]>], [6, 1, 1]>,

  // IIC_iMAC32:
  // MLA, MLS latency = 5 Throughput = 2;
  // SMMLA, SMMLS latency = 6 Throughput = 3;
  InstrItinData<IIC_iMAC32  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<3, [KRT2_M]>],
                              [6, 1, 1, 1]>,

  // IIC_iMUL64:
  // SMULL latency = 5,6 Throughput = 3; UMULL latency = 5,6, Throughput = 3
  InstrItinData<IIC_iMUL64  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<3, [KRT2_M]>], [5, 6, 1, 1]>,

  // IIC_iMAC64:
  // SMLAL latency = 5,6 Throughput = 3; SMLALxy latency = 4,5 Throughput = 2;
  // UMAAL latency = 6,7 Throughput = 4; UMLAL latency = 5,6 Throughput = 3
  InstrItinData<IIC_iMAC64  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<4, [KRT2_M]>],
                              [6, 7, 1, 1]>,

  // IIC_iDML32: MAC dual
  // SMLAD,DX latency = 5, Throughput = 2; SMLSD,DX latency = 5 Throughput = 2;
  InstrItinData<IIC_iDML32  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                            InstrStage<2, [KRT2_M]>],
                            [5, 1, 1, 1]>,

  // IIC_iDML64: MAC long dual
  // SMLALD,LDX latency = 5,6 Throughput = 3;
  // SMLSLD,LDX latency = 5,6 Throughput = 3
  InstrItinData<IIC_iDML64 , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                             InstrStage<3, [KRT2_M]>],
                             [5, 6, 1, 1]>,

  // IIC_iMUAD32: Dual multiply add
  // SMUAD,DX latency = 5, Throughput = 2; SMUSD,DX latency = 5, Throughput = 2
  InstrItinData<IIC_iMUAD32  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<2, [KRT2_M]>], [5, 1, 1]>,

  // IIC_iDIV32: integer division
  // min latency=3 min Throughput=2; max latency=36 Throughput=34
  // SDIV, UDIV
  InstrItinData<IIC_iDIV32  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                              InstrStage<34, [KRT2_M]>],
                              [36, 1, 1]>,

  // Integer load pipeline
  // FIXME: The timings are some rough approximations
  //
  // Immediate offset
  InstrItinData<IIC_iLoad_i   , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<1, [KRT2_L], 0>,
                                 InstrStage<1, [KRT2_LSUnit]>],
                                [3, 1], [KRT2_LdBypass]>,
  InstrItinData<IIC_iLoad_bh_i, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<2, [KRT2_L], 0>,
                                 InstrStage<1, [KRT2_LSUnit]>],
                                [4, 1], [KRT2_LdBypass]>,
  // FIXME: If address is 64-bit aligned, AGU cycles is 1.
  InstrItinData<IIC_iLoad_d_i , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<2, [KRT2_L], 0>,
                                 InstrStage<1, [KRT2_LSUnit]>],
                                [3, 3, 1], [KRT2_LdBypass]>,
  //
  // Register offset
  InstrItinData<IIC_iLoad_r   , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<1, [KRT2_L], 0>,
                                 InstrStage<1, [KRT2_LSUnit]>],
                                [3, 1, 1], [KRT2_LdBypass]>,
  InstrItinData<IIC_iLoad_bh_r, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<2, [KRT2_L], 0>,
                                 InstrStage<1, [KRT2_LSUnit]>],
                                [4, 1, 1], [KRT2_LdBypass]>,
  InstrItinData<IIC_iLoad_d_r , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<2, [KRT2_L], 0>,
                                 InstrStage<1, [KRT2_LSUnit]>],
                                [3, 3, 1, 1], [KRT2_LdBypass]>,
  //
  // Scaled register offset
  InstrItinData<IIC_iLoad_si  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<1, [KRT2_L], 0>,
                                 InstrStage<1, [KRT2_LSUnit], 0>],
                                [4, 1, 1], [KRT2_LdBypass]>,
  InstrItinData<IIC_iLoad_bh_si,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<2, [KRT2_L], 0>,
                                 InstrStage<1, [KRT2_LSUnit]>],
                                [5, 1, 1], [KRT2_LdBypass]>,
  //
  // Immediate offset with update
  // Note (todo): Load with base update use ALU but not modeling
  // this detail since the hardware supports single issue from RSV
  InstrItinData<IIC_iLoad_iu  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<1, [KRT2_L], 0>,
                                 InstrStage<1, [KRT2_LSUnit]>],
                                [3, 2, 1], [KRT2_LdBypass]>,
  InstrItinData<IIC_iLoad_bh_iu,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<2, [KRT2_L], 0>,
                                 InstrStage<1, [KRT2_LSUnit]>],
                                [4, 3, 1], [KRT2_LdBypass]>,
  //
  // Register offset with update
  InstrItinData<IIC_iLoad_ru  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<1, [KRT2_L], 0>,
                                 InstrStage<1, [KRT2_LSUnit]>],
                                [3, 2, 1, 1], [KRT2_LdBypass]>,
  InstrItinData<IIC_iLoad_bh_ru,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<2, [KRT2_L], 0>,
                                 InstrStage<1, [KRT2_LSUnit]>],
                                [4, 3, 1, 1], [KRT2_LdBypass]>,
  InstrItinData<IIC_iLoad_d_ru, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<2, [KRT2_L], 0>,
                                 InstrStage<1, [KRT2_LSUnit]>],
                                [3, 3, 1, 1], [KRT2_LdBypass]>,
  //
  // Scaled register offset with update
  InstrItinData<IIC_iLoad_siu , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<1, [KRT2_L], 0>,
                                 InstrStage<1, [KRT2_LSUnit]>],
                                [4, 3, 1, 1], [KRT2_LdBypass]>,
  InstrItinData<IIC_iLoad_bh_siu,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                  InstrStage<1, [KRT2_MUX0], 0>,
                                  InstrStage<2, [KRT2_L], 0>,
                                  InstrStage<1, [KRT2_LSUnit]>],
                                 [5, 4, 1, 1], [KRT2_LdBypass]>,
  //
  // Load multiple, def is the 5th operand.
  // FIXME: This assumes 3 to 4 registers.
  InstrItinData<IIC_iLoad_m  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                InstrStage<1, [KRT2_MUX0], 0>,
                                InstrStage<2, [KRT2_L], 1>,
                                InstrStage<2, [KRT2_LSUnit]>],
                               [1, 1, 1, 1, 3],
                         [NoBypass, NoBypass, NoBypass, NoBypass, KRT2_LdBypass],
                         -1>, // dynamic uops
  //
  // Load multiple + update, defs are the 1st and 5th operands.
  InstrItinData<IIC_iLoad_mu , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                InstrStage<1, [KRT2_MUX0], 0>,
                                InstrStage<2, [KRT2_L], 1>,
                                InstrStage<2, [KRT2_LSUnit]>],
                               [2, 1, 1, 1, 3],
                         [NoBypass, NoBypass, NoBypass, NoBypass, KRT2_LdBypass],
                         -1>, // dynamic uops
  //
  // Load multiple plus branch
  InstrItinData<IIC_iLoad_mBr, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                InstrStage<1, [KRT2_MUX0], 0>,
                                InstrStage<1, [KRT2_L], 1>,
                                InstrStage<2, [KRT2_LSUnit]>,
                                InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B, KRT2_Z]>],
                               [1, 2, 1, 1, 3],
                         [NoBypass, NoBypass, NoBypass, NoBypass, KRT2_LdBypass],
                         -1>, // dynamic uops
  //
  // Pop, def is the 3rd operand.
  InstrItinData<IIC_iPop  ,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                InstrStage<1, [KRT2_MUX0], 0>,
                                InstrStage<2, [KRT2_L], 1>,
                                InstrStage<2, [KRT2_LSUnit]>],
                               [1, 1, 3],
                               [NoBypass, NoBypass, KRT2_LdBypass],
                               -1>, // dynamic uops
  //
  // Pop + branch, def is the 3rd operand.
  InstrItinData<IIC_iPop_Br,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                InstrStage<1, [KRT2_MUX0], 0>,
                                InstrStage<2, [KRT2_L], 1>,
                                InstrStage<2, [KRT2_LSUnit]>,
                                InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B, KRT2_Z]>],
                               [1, 1, 3],
                               [NoBypass, NoBypass, KRT2_LdBypass],
                               -1>, // dynamic uops
  //
  // iLoadi + iALUr for t2LDRpci_pic.
  InstrItinData<IIC_iLoadiALU, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                InstrStage<1, [KRT2_MUX0], 0>,
                                InstrStage<1, [KRT2_L], 0>,
                                InstrStage<1, [KRT2_LSUnit]>,
                                InstrStage<1, [KRT2_X, KRT2_Y, KRT2_Z]>],
                               [2, 1]>,

  // Integer store pipeline
  ///
  // Immediate offset
  InstrItinData<IIC_iStore_i  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<1, [KRT2_S], 0>,
                                 InstrStage<1, [KRT2_LSUnit]>], [1, 1]>,
  InstrItinData<IIC_iStore_bh_i,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<2, [KRT2_S], 1>,
                                 InstrStage<1, [KRT2_LSUnit]>], [1, 1]>,
  // FIXME: If address is 64-bit aligned, AGU cycles is 1.
  InstrItinData<IIC_iStore_d_i, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<2, [KRT2_S], 1>,
                                 InstrStage<1, [KRT2_LSUnit]>], [1, 1]>,
  //
  // Register offset
  InstrItinData<IIC_iStore_r  , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<1, [KRT2_S], 0>,
                                 InstrStage<1, [KRT2_LSUnit]>], [1, 1, 1]>,
  InstrItinData<IIC_iStore_bh_r,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<2, [KRT2_S], 1>,
                                 InstrStage<1, [KRT2_LSUnit]>], [1, 1, 1]>,
  InstrItinData<IIC_iStore_d_r, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                 InstrStage<1, [KRT2_MUX0], 0>,
                                 InstrStage<2, [KRT2_S], 1>,
                                 InstrStage<1, [KRT2_LSUnit]>], [1, 1, 1]>,
  //
  // Scaled register offset
  InstrItinData<IIC_iStore_si ,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                  InstrStage<1, [KRT2_MUX0], 0>,
                                  InstrStage<1, [KRT2_S], 0>,
                                  InstrStage<1, [KRT2_LSUnit]>], [1, 1, 1]>,
  InstrItinData<IIC_iStore_bh_si,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                  InstrStage<1, [KRT2_MUX0], 0>,
                                  InstrStage<2, [KRT2_S], 1>,
                                  InstrStage<1, [KRT2_LSUnit]>], [1, 1, 1]>,
  //
  // Immediate offset with update
  // Note (todo): Store with base update use ALU but not modeling
  // this detail since the hardware supports single issue from RSV
  InstrItinData<IIC_iStore_iu ,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                  InstrStage<1, [KRT2_MUX0], 0>,
                                  InstrStage<1, [KRT2_S], 0>,
                                  InstrStage<1, [KRT2_LSUnit]>], [2, 1, 1]>,
  InstrItinData<IIC_iStore_bh_iu,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                  InstrStage<1, [KRT2_MUX0], 0>,
                                  InstrStage<2, [KRT2_S], 1>,
                                  InstrStage<1, [KRT2_LSUnit]>], [3, 1, 1]>,
  //
  // Register offset with update
  InstrItinData<IIC_iStore_ru ,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                  InstrStage<1, [KRT2_MUX0], 0>,
                                  InstrStage<1, [KRT2_S], 0>,
                                  InstrStage<1, [KRT2_LSUnit]>],
                                 [2, 1, 1, 1]>,
  InstrItinData<IIC_iStore_bh_ru,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                  InstrStage<1, [KRT2_MUX0], 0>,
                                  InstrStage<2, [KRT2_S], 1>,
                                  InstrStage<1, [KRT2_LSUnit]>],
                                 [3, 1, 1, 1]>,
  InstrItinData<IIC_iStore_d_ru, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                  InstrStage<1, [KRT2_MUX0], 0>,
                                  InstrStage<2, [KRT2_S], 1>,
                                  InstrStage<1, [KRT2_LSUnit]>],
                                 [3, 1, 1, 1]>,
  //
  // Scaled register offset with update
  InstrItinData<IIC_iStore_siu,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                    InstrStage<1, [KRT2_MUX0], 0>,
                                    InstrStage<1, [KRT2_S], 0>,
                                    InstrStage<1, [KRT2_LSUnit]>],
                                   [2, 1, 1, 1]>,
  InstrItinData<IIC_iStore_bh_siu, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                    InstrStage<1, [KRT2_MUX0], 0>,
                                    InstrStage<2, [KRT2_S], 1>,
                                    InstrStage<1, [KRT2_LSUnit]>],
                                   [3, 1, 1, 1]>,
  //
  // Store multiple
  InstrItinData<IIC_iStore_m , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                InstrStage<1, [KRT2_MUX0], 0>,
                                InstrStage<1, [KRT2_S], 0>,
                                InstrStage<2, [KRT2_LSUnit]>],
                [], [], -1>, // dynamic uops
  //
  // Store multiple + update
  InstrItinData<IIC_iStore_mu, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                InstrStage<1, [KRT2_MUX0], 0>,
                                InstrStage<1, [KRT2_S], 0>,
                                InstrStage<2, [KRT2_LSUnit]>],
                [2], [], -1>, // dynamic uops
  //
  // Preload
  InstrItinData<IIC_Preload,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1]>], [1, 1]>,

  // Branch
  //
  // no delay slots, so the latency of a branch is unimportant
  InstrItinData<IIC_Br       , [InstrStage<1, [KRT2_Issue0], 0>,
                                InstrStage<1, [KRT2_Issue1], 0>,
                                InstrStage<1, [KRT2_X, KRT2_Y, KRT2_B, KRT2_Z]>]>,

  // VFP and NEON shares the same register file. This means that every VFP
  // instruction should wait for full completion of the consecutive NEON
  // instruction and vice-versa. We model this behavior with two artificial FUs:
  // DRegsVFP and DRegsVFP.
  //
  // Every VFP instruction:
  //  - Acquires DRegsVFP resource for 1 cycle
  //  - Reserves DRegsN resource for the whole duration (including time to
  //    register file writeback!).
  // Every NEON instruction does the same but with FUs swapped.
  //
  // Since the reserved FU cannot be acquired, this models precisely
  // "cross-domain" stalls.

  // VFP
  // Issue through integer pipeline, and execute in NEON unit.
  // Note: fpSTAT is a VS Pipe instruction.
  // It requires synchronizing integer and VFP/NEON pipelines.
  // FP Special Register to Integer Register File Move
  // VMRS, VMSR with system registers latency = 2 Throughput = 1?
  // (in email notes krait2 from GPR latency = 9, throughput = 1?)
  // (in email notes krait2 to GPR latency = 14, throughput = 1?)
  InstrItinData<IIC_fpSTAT , [InstrStage<1, [KRT2_Issue0],0>,
                              InstrStage<1, [KRT2_Issue1], 0>,
                              InstrStage<1, [KRT2_MUX0], 0>,
                              InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                              InstrStage<15, [KRT2_DRegsN],   0, Reserved>,
                              InstrStage<1, [KRT2_VS]>],
                             [14]>,
  //
  // Single-precision FP Unary
  // Note (todo): Assuming fpUNA class is a VX Pipe instruction
  // Note (todo): Krait wbck cycles not known
  // VABSS, VNEGS latency = 2 Throughput = 1?
  // VMOVS latency= 1 Throughput = 1?
  // (in email notes latency = 1, latency krait2 = 2)
  // Note: Picking the max latency
  InstrItinData<IIC_fpUNA32 , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               // Extra latency cycles since wbck is 2 cycles
                               InstrStage<3, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [2, 1]>,
  //
  // Double-precision FP Unary
  // Note (todo): Assuming fpUNA class is a VX Pipe instruction
  // Note (todo): Krait wbck cycles not known
  // VABSD, VNEGD latency = 2 Throughput = 1?
  // VMOVD latency= 1 Throughput = 1?
  // Note: Picking the max latency
  InstrItinData<IIC_fpUNA64 , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               // Extra latency cycles since wbck is 2 cycles
                               InstrStage<3, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [2, 1]>,

  //
  // Single-precision FP Compare
  // Note (todo): Assuming fpCMP class is a VX Pipe instruction
  // Note (todo): Krait wbck cycles not known
  // latency = 2 Throughput = 1?
  InstrItinData<IIC_fpCMP32 , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               // Extra latency cycles since wbck is extra cycle
                               InstrStage<3, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [2, 1]>,
  //
  // Double-precision FP Compare
  // Note (todo): Assuming fpCMP class is a VX Pipe instruction
  // Note (todo): Krait wbck cycles not known
  // latency = 2 Throughput = 1?
  InstrItinData<IIC_fpCMP64 , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               // Extra latency cycles since wbck is 4 cycles
                               InstrStage<3, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [2, 1]>,
  //
  // Single to Double FP Convert
  // Note (todo): Assuming fpCVT class is a VX Pipe instruction
  // latency = 4 Throughput = 1?
  InstrItinData<IIC_fpCVTSD , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<5, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 1]>,
  //
  // Double to Single FP Convert
  // Note (todo): Assuming fpCVT class is a VX Pipe instruction
  // latency = 4 Throughput = 1?
  InstrItinData<IIC_fpCVTDS , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<5, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 1]>,

  //
  // Single to Half FP Convert
  // Note (todo): Assuming fpCVTSH class is a VX Pipe instruction
  // latency = 4 Throughput = 1?
  InstrItinData<IIC_fpCVTSH , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<5, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 1]>,
  //
  // Half to Single FP Convert
  // Note (todo): Assuming fpCVTHS class is a VX Pipe instruction
  // latency = 4 Throughput = 1?
  InstrItinData<IIC_fpCVTHS , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<5, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 1]>,

  //
  // Single-Precision FP to Integer Convert
  // Note (todo): Assuming fpCVTSI class is a VX Pipe instruction
  // latency = 4 Throughput = 1?
  InstrItinData<IIC_fpCVTSI , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<5, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 1]>,
  //
  // Double-Precision FP to Integer Convert
  // Note (todo): Assuming fpCVTDI class is a VX Pipe instruction
  // latency = 4 Throughput = 1?
  InstrItinData<IIC_fpCVTDI , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<5, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 1]>,
  //
  // Integer to Single-Precision FP Convert
  // Note (todo): Assuming fpCVTIS class is a VX Pipe instruction
  // latency = 4 Throughput = 1?
  InstrItinData<IIC_fpCVTIS , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<5, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 1]>,
  //
  // Integer to Double-Precision FP Convert
  // Note (todo): Assuming fpCVTID class is a VX Pipe instruction
  // latency = 4 Throughput = 1?
  InstrItinData<IIC_fpCVTID , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<5, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 1]>,
  //
  // Single-precision FP ALU
  // Note (todo): Assuming fpALU class is a VX Pipe instruction
  // latency krait3 = 4 Throughput = 1?
  // (in email notes latency krait2 VADD,VSUB = 5)
  InstrItinData<IIC_fpALU32 , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<6, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [5, 1, 1]>,
  //
  // Double-precision FP ALU
  // Note:  Assuming fpALU class is a VX Pipe instruction
  // latency krait3 = 4 Throughput = 1? 
  // (in email notes latency krait2 VADD, VSUB = 7)
  InstrItinData<IIC_fpALU64 , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<8, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [7, 1, 1]>,
  //
  // Single-precision FP Multiply
  // Note: fpALU class is a VX Pipe instruction
  // VMULS latency = 5 Throughput = 1?; VNMULS latency = 5
  InstrItinData<IIC_fpMUL32 , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<6, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [5, 1, 1]>,
  //
  // Double-precision FP Multiply
  // Note: fpMUL class is a VX Pipe instruction
  // VMULS latency = 6 Throughput = 1?; VNMULS latency = 7
  // Note: Picking the max latency
  InstrItinData<IIC_fpMUL64 , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<8, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [7, 1, 1]>,
  //
  // Single-precision FP MAC
  // Note (todo): Assuming execute 32-bit MAC each cycle
  // latency krait3 = 8 Throughput = 2? (in email notes latency krait2 = 9)
  InstrItinData<IIC_fpMAC32 , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<10, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [9, 1, 1, 1]>,
  //
  // Double-precision FP MAC
  // Note: fpMAC class is a VX Pipe instruction
  // latency krait3 = 10 Throughput = 2? (in email notes latency krait2 = 13)
  InstrItinData<IIC_fpMAC64 , [InstrStage<1,  [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1,  [KRT2_MUX0], 0>,
                               InstrStage<1,  [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<14, [KRT2_DRegsN],  0, Reserved>,
                               InstrStage<2,  [KRT2_VX]>],
                              [13, 1, 1, 1]>,
  //
  // Single-precision Fused FP MAC
  // Note (todo): Assuming execute 32-bit fused MAC each cycle
  // latency = 5 Throughput = 1?
  InstrItinData<IIC_fpFMAC32 , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<6, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [5, 1, 1, 1]>,
  //
  // Double-precision Fused FP MAC
  // latency = 6 (NeonOpt) Throughput = 1?, (in email notes latency = 7)
  InstrItinData<IIC_fpFMAC64 , [InstrStage<1,  [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1,  [KRT2_MUX0], 0>,
                               InstrStage<1,  [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<7, [KRT2_DRegsN],  0, Reserved>,
                               InstrStage<1,  [KRT2_VX]>],
                              [6, 1, 1, 1]>,
  //
  // Single-precision FP DIV
  // Note: fpDIV class is a VX Pipe instruction
  // latency krait3 = 18 (NeonOpt) Throughput = 2?
  // (in email notes latency = 17, latency krait2 = 19)
  InstrItinData<IIC_fpDIV32 , [InstrStage<1,  [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1,  [KRT2_MUX0], 0>,
                               InstrStage<1,  [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<20, [KRT2_DRegsN],  0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [19, 1, 1]>,
  //
  // Double-precision FP DIV
  // Note: fpDIV class is a VX Pipe instruction
  // latency krait3 = 31 Throughput = 2?, (in email notes latency krait2 = 32)
  InstrItinData<IIC_fpDIV64 , [InstrStage<1,  [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1,  [KRT2_MUX0], 0>,
                               InstrStage<1,  [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<33, [KRT2_DRegsN],  0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [32, 1, 1]>,
  //
  // Single-precision FP SQRT
  // Note: fpSQRT class is a VX Pipe instruction
  // latency = 18 (NeonOpt) Throughput = 2?
  // (in email notes latency = 17, latency krait2 = 19)
  InstrItinData<IIC_fpSQRT32, [InstrStage<1,  [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1,  [KRT2_MUX0], 0>,
                               InstrStage<1,  [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<20, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [19, 1]>,
  //
  // Double-precision FP SQRT
  // Note: fpSQRT class is a VX Pipe instruction
  // latency krait3 = 31, Throughput = 2? (in email notes latency krait2 = 32)
  InstrItinData<IIC_fpSQRT64, [InstrStage<1,  [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1,  [KRT2_MUX0], 0>,
                               InstrStage<1,  [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<33, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [32, 1]>,

  //
  // Integer to Single-precision Move
  // Note: fpMOV class is a VL Pipe instruction
  // Note (todo): Krait wbck cycles not known
  // VMOV (from GPR) SP latency krait3 = 4 Throughput = 1?
  // (in email latency krait2 = 14)
  InstrItinData<IIC_fpMOVIS,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               // Extra 1 latency cycle since wbck is 2 cycles
                               InstrStage<15, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VL]>],
                              [14, 1]>,
  //
  // Integer to Double-precision Move
  // Note: fpMOVID class is a VL Pipe instruction
  // Note (todo): Krait wbck cycles not known
  // VMOV (from GPR) DP latency krait3 = 4 Throughput = 1?
  // (in email latency krait2 = 14)
  InstrItinData<IIC_fpMOVID,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               // Extra 1 latency cycle since wbck is 2 cycles
                               InstrStage<15, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VL]>],
                              [14, 1, 1]>,
  //
  // Single-precision to Integer Move
  //
  // Note (todo): Assuming On A9/Krait move-from-VFP is free to issue with
  // no stall if other VFP operations are in flight.
  // Note: fpMOVSI class is a VS Pipe instruction
  // VMOV (to GPR) SP latency krait3 = 3 Throughput = 1?
  // (in email latency krait2 = 9)
  InstrItinData<IIC_fpMOVSI,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>],
                              [9, 1]>,

  //
  // Double-precision to Integer Move
  //
  // Note (todo): Assuming On A9/Krait move-from-VFP is free to issue with
  // no stall if other VFP operations are in flight.
  // Note: fpMOVDI class is a VS Pipe instruction
  // VMOV (to GPR) DP latency krait3 = 4 Throughput = 1?
  // (in email latency krait2 = 9)
  InstrItinData<IIC_fpMOVDI,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>],
                              [9, 9, 1]>,
  //
  // Single-precision FP Load
  // Note (todo): fpLoad class also uses uses ALU and LSUnit
  InstrItinData<IIC_fpLoad32, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<2, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VL], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [1, 1]>,
  //
  // Double-precision FP Load
  InstrItinData<IIC_fpLoad64, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<2, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VL], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [2, 1]>,
  //
  // FP Load Multiple
  // FIXME: assumes 2 doubles which requires 2 LS cycles.
  InstrItinData<IIC_fpLoad_m, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<2, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VL], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                [1, 1, 1, 1], [], -1>, // dynamic uops
  //
  // FP Load Multiple + update
  // FIXME: assumes 2 doubles which requires 2 LS cycles.
  InstrItinData<IIC_fpLoad_mu,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<2, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VL], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                [2, 1, 1, 1], [], -1>, // dynamic uops
  //
  // Single-precision FP Store
  InstrItinData<IIC_fpStore32,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<2, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VS], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [1, 1]>,
  //
  // Double-precision FP Store
  InstrItinData<IIC_fpStore64,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<2, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VS], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [1, 1]>,
  //
  // FP Store Multiple
  // FIXME: assumes 2 doubles which requires 2 LS cycles.
  InstrItinData<IIC_fpStore_m,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                               InstrStage<2, [KRT2_DRegsN],   0, Reserved>,
                               InstrStage<1, [KRT2_VS], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                [1, 1, 1, 1], [], -1>, // dynamic uops
  //
  // FP Store Multiple + update
  // FIXME: assumes 2 doubles which requires 2 LS cycles.
  InstrItinData<IIC_fpStore_mu,[InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                                InstrStage<1, [KRT2_MUX0], 0>,
                                InstrStage<1, [KRT2_DRegsVFP], 0, Required>,
                                InstrStage<2, [KRT2_DRegsN],   0, Reserved>,
                                InstrStage<1, [KRT2_VS], 0>,
                                InstrStage<2, [KRT2_LSUnit]>],
                [2, 1, 1, 1], [], -1>, // dynamic uops
  // NEON
  // VLD1
  InstrItinData<IIC_VLD1,     [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [1, 1]>,
  // VLD1x2
  InstrItinData<IIC_VLD1x2,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [1, 1, 1]>,
  // VLD1x3
  InstrItinData<IIC_VLD1x3,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [1, 1, 2, 1]>,
  // VLD1x4
  InstrItinData<IIC_VLD1x4,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [1, 1, 2, 2, 1]>,
  // VLD1u
  InstrItinData<IIC_VLD1u,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [1, 2, 1]>,
  // VLD1x2u
  InstrItinData<IIC_VLD1x2u,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [1, 1, 2, 1]>,
  // VLD1x3u
  InstrItinData<IIC_VLD1x3u,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [1, 1, 2, 2, 1]>,
  // VLD1x4u
  InstrItinData<IIC_VLD1x4u,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [1, 1, 2, 2, 2, 1]>,
  //
  // VLD1ln
  InstrItinData<IIC_VLD1ln,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [3, 1, 1, 1]>,
  //
  // VLD1lnu
  InstrItinData<IIC_VLD1lnu,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [3, 2, 1, 1, 1, 1]>,
  //
  // VLD1dup
  InstrItinData<IIC_VLD1dup,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [2, 1]>,
  //
  // VLD1dupu
  InstrItinData<IIC_VLD1dupu, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [2, 2, 1, 1]>,
  //
  // VLD2
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VLD2,     [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [2, 2, 1]>,
  //
  // VLD2x2
  InstrItinData<IIC_VLD2x2,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [2, 3, 2, 3, 1]>,
  //
  // VLD2ln
  InstrItinData<IIC_VLD2ln,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [3, 3, 1, 1, 1, 1]>,
  //
  // VLD2u
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VLD2u,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [2, 2, 2, 1, 1, 1]>,
  //
  // VLD2x2u
  InstrItinData<IIC_VLD2x2u,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [2, 3, 2, 3, 2, 1]>,
  //
  // VLD2lnu
  InstrItinData<IIC_VLD2lnu,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [3, 3, 2, 1, 1, 1, 1, 1]>,
  //
  // VLD2dup
  InstrItinData<IIC_VLD2dup,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [2, 2, 1]>,
  //
  // VLD2dupu
  InstrItinData<IIC_VLD2dupu, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [2, 2, 2, 1, 1]>,
  //
  // VLD3
  InstrItinData<IIC_VLD3,     [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<9,[KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<3, [KRT2_VL], 0>,
                               InstrStage<3, [KRT2_LSUnit]>],
                              [3, 3, 4, 1]>,
  //
  // VLD3ln
  InstrItinData<IIC_VLD3ln,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<11,[KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<5, [KRT2_VL], 0>,
                               InstrStage<5, [KRT2_LSUnit]>],
                              [5, 5, 6, 1, 1, 1, 1, 2]>,
  //
  // VLD3u
  InstrItinData<IIC_VLD3u,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<9,[KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<3, [KRT2_VL], 0>,
                               InstrStage<3, [KRT2_LSUnit]>],
                              [3, 3, 4, 2, 1]>,
  //
  // VLD3lnu
  InstrItinData<IIC_VLD3lnu,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<11,[KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<5, [KRT2_VL], 0>,
                               InstrStage<5, [KRT2_LSUnit]>],
                              [5, 5, 6, 2, 1, 1, 1, 1, 1, 2]>,
  //
  // VLD3dup
  InstrItinData<IIC_VLD3dup,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<9, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<3, [KRT2_VL], 0>,
                               InstrStage<3, [KRT2_LSUnit]>],
                              [3, 3, 4, 1]>,
  //
  // VLD3dupu
  InstrItinData<IIC_VLD3dupu, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<9, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<3, [KRT2_VL], 0>,
                               InstrStage<3, [KRT2_LSUnit]>],
                              [3, 3, 4, 2, 1, 1]>,
  //
  // VLD4
  InstrItinData<IIC_VLD4,     [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<9,[KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<3, [KRT2_VL], 0>,
                               InstrStage<3, [KRT2_LSUnit]>],
                              [3, 3, 4, 4, 1]>,
  //
  // VLD4ln
  InstrItinData<IIC_VLD4ln,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<10,[KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<4, [KRT2_VL], 0>,
                               InstrStage<4, [KRT2_LSUnit]>],
                              [4, 4, 5, 5, 1, 1, 1, 1, 2, 2]>,
  //
  // VLD4u
  InstrItinData<IIC_VLD4u,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<9,[KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<3, [KRT2_VL], 0>,
                               InstrStage<3, [KRT2_LSUnit]>],
                              [3, 3, 4, 4, 2, 1]>,
  //
  // VLD4lnu
  InstrItinData<IIC_VLD4lnu,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<10,[KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<4, [KRT2_VL], 0>,
                               InstrStage<4, [KRT2_LSUnit]>],
                              [4, 4, 5, 5, 2, 1, 1, 1, 1, 1, 2, 2]>,
  //
  // VLD4dup
  InstrItinData<IIC_VLD4dup,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [2, 2, 3, 3, 1]>,
  //
  // VLD4dupu
  InstrItinData<IIC_VLD4dupu, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [2, 2, 3, 3, 2, 1, 1]>,
  //
  // VST1
  // Note: fpStore class uses ALU and LSUnit
  InstrItinData<IIC_VST1,     [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VS], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [1, 1, 1]>,
  //
  // VST1x2
  InstrItinData<IIC_VST1x2,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VS], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [1, 1, 1, 1]>,
  //
  // VST1x3
  InstrItinData<IIC_VST1x3,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<2, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VS], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [1, 1, 1, 1, 2]>,
  //
  // VST1x4
  InstrItinData<IIC_VST1x4,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<2, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VS], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [1, 1, 1, 1, 2, 2]>,
  //
  // VST1u
  InstrItinData<IIC_VST1u,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VS], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [2, 1, 1, 1, 1]>,
  //
  // VST1x2u
  InstrItinData<IIC_VST1x2u,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VS], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [2, 1, 1, 1, 1, 1]>,
  //
  // VST1x3u
  InstrItinData<IIC_VST1x3u,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<2, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VS], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [2, 1, 1, 1, 1, 1, 2]>,
  //
  // VST1x4u
  InstrItinData<IIC_VST1x4u,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<2, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VS], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [2, 1, 1, 1, 1, 1, 2, 2]>,
  //
  // VST1ln
  InstrItinData<IIC_VST1ln,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VS], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [1, 1, 1]>,
  //
  // VST1lnu
  InstrItinData<IIC_VST1lnu,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VS], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [2, 1, 1, 1, 1]>,
  //
  // VST2
  InstrItinData<IIC_VST2,     [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VS], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [1, 1, 1, 1]>,
  //
  // VST2x2
  InstrItinData<IIC_VST2x2,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<3, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<3, [KRT2_VS], 0>,
                               InstrStage<3, [KRT2_LSUnit]>],
                              [1, 1, 1, 1, 2, 2]>,
  //
  // VST2u
  InstrItinData<IIC_VST2u,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VS], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [2, 1, 1, 1, 1, 1]>,
  //
  // VST2x2u
  InstrItinData<IIC_VST2x2u,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<3, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<3, [KRT2_VS], 0>,
                               InstrStage<3, [KRT2_LSUnit]>],
                              [2, 1, 1, 1, 1, 1, 2, 2]>,
  //
  // VST2ln
  InstrItinData<IIC_VST2ln,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VS], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [1, 1, 1, 1]>,
  //
  // VST2lnu
  InstrItinData<IIC_VST2lnu,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VS], 0>,
                               InstrStage<1, [KRT2_LSUnit]>],
                              [2, 1, 1, 1, 1, 1]>,
  //
  // VST3
  InstrItinData<IIC_VST3,     [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<2, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VS], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [1, 1, 1, 1, 2]>,
  //
  // VST3u
  InstrItinData<IIC_VST3u,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<2, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VS], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [2, 1, 1, 1, 1, 1, 2]>,
  //
  // VST3ln
  InstrItinData<IIC_VST3ln,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<3, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<3, [KRT2_VS], 0>,
                               InstrStage<3, [KRT2_LSUnit]>],
                              [1, 1, 1, 1, 2]>,
  //
  // VST3lnu
  InstrItinData<IIC_VST3lnu,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<3, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<3, [KRT2_VS], 0>,
                               InstrStage<3, [KRT2_LSUnit]>],
                              [2, 1, 1, 1, 1, 1, 2]>,
  //
  // VST4
  InstrItinData<IIC_VST4,     [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<2, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VS], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [1, 1, 1, 1, 2, 2]>,
  //
  // VST4u
  InstrItinData<IIC_VST4u,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<2, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VS], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [2, 1, 1, 1, 1, 1, 2, 2]>,
  //
  // VST4ln
  InstrItinData<IIC_VST4ln,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<2, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VS], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [1, 1, 1, 1, 2, 2]>,
  //
  // VST4lnu
  InstrItinData<IIC_VST4lnu,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<2, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VS], 0>,
                               InstrStage<2, [KRT2_LSUnit]>],
                              [2, 1, 1, 1, 1, 1, 2, 2]>,

  //
  // Double-register Integer Unary
  // Note (todo): Assuming VUNAiD class is a VX pipe instruction
  // VABS latency = 3 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VUNAiD,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [3, 1]>,
  //
  // Quad-register Integer Unary
  // Note (todo): Assuming VUNAiQ class is a VX pipe instruction
  // VABS latency = 3 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VUNAiQ,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [3, 1]>,
  //
  // Double-register Integer Q-Unary
  // Note (todo): Assuming VQUNAiD class is a VX pipe instruction
  // VABS latency = 3 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VQUNAiD,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [3, 1]>,
  //
  // Quad-register Integer CountQ-Unary
  // Note (todo): Assuming VQUNAiQ class is a VX pipe instruction
  // VABS latency = 3 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VQUNAiQ,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [3, 1]>,
  //
  // Double-register Integer Binary
  // Note (todo): Assuming VBINiD class is a VX pipe instruction
  // VEOR, VAND, etc. latency =2 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VBINiD,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [2, 1, 1]>,
  //
  // Quad-register Integer Binary
  // Note (todo): Assuming VBINiQ class is a VX pipe instruction
  // VEOR, VAND, etc. latency =2 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VBINiQ,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [2, 1, 1]>,
  //
  // Double-register Integer Add
  // Note: VADDiD class is a VX pipe instruction
  // VADD latency =3 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VADDiD,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [3, 2, 2]>,
  //
  // Quad-register Integer Add
  // Note: VADDiQ class is a VX pipe instruction
  // VADD latency =3 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VADDiQ,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [3, 2, 2]>,
  //
  // Double-register Integer Subtract
  // Note: VSUBiD class is a VX pipe instruction
  // VSUB latency =3 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VSUBiD,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [3, 2, 1]>,
  //
  // Quad-register Integer Subtract
  // Note: VSUBiQ class is a VX pipe instruction
  // VSUB latency =3 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VSUBiQ,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [3, 2, 1]>,
  //
  // Double-register Integer Shift
  // Note: VSHLiD class is a VX pipe instruction
  // VSHL latency =2 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VSHLiD,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [2, 1, 1]>,
  //
  // Quad-register Integer Shift
  // Note: VSHLiQ class is a VX pipe instruction
  // VSHL latency =2 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VSHLiQ,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [2, 1, 1]>,
  //
  // Double-register Integer Shift (3 cycles)
  // Note: VSHLi4D class is a VX pipe instruction
  // VPADD, VSHL round/saturate/narrow latency =3 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VSHLi4D,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [3, 1, 1]>,
  //
  // Quad-register Integer Shift (3 cycles)
  // Note: VSHLi4Q class is a VX pipe instruction
  // VPADD, VSHL round/saturate/narrow latency =3 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VSHLi4Q,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [3, 1, 1]>,
  //
  // Double-register Integer Binary (4 cycles)
  // Note (todo): Assuming VBINi4D class is a VX pipe instruction
  // VHADD, VRHADD  halve/round/staturate/narrow latency = 4 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VBINi4D,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 2, 2]>,
  //
  // Quad-register Integer Binary (4 cycles)
  // Note (todo): Assuming VBINi4Q class is a VX pipe instruction
  // VHADD, VQADD halve/saturate/round latency =4 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VBINi4Q,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 2, 2]>,
  //
  // Double-register Integer Subtract (4 cycles)
  // Note: VSUBi4D class is a VX pipe instruction
  // VHSUB, VQSUB halve/saturate/round latency =4 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VSUBi4D,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 2, 1]>,
  //
  // Quad-register Integer Subtract (4 cycles)
  // Note: VSUBi4Q class is a VX pipe instruction
  // VHSUB, VQSUB halve/saturate latency =4 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VSUBi4Q,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 2, 1]>,

  //
  // Double-register Integer Binary (2 cycles)
  // Note (todo): Assuming VBINi2D class is a VX pipe instruction
  // VCEQ, VCGE, VCGT, VMAX, VMin, VPMAX, VPMin latency =2 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VBINi2D,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [2, 1, 1]>,
  //
  // Quad-register Integer Binary (2 cycles)
  // Note (todo): Assuming VBINi2Q class is a VX pipe instruction
  // VCEQ, VCGE, VCGT, VMAX, VMin, VPMAX, VPMin latency =2 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VBINi2Q,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [2, 1, 1]>,
  //
  // Double-register Integer Count (4 cycles)
  // Note: VCNTiD class is a VX pipe instruction
  // VCLS, VCLZ, VCNT latency = 4 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VCNTiD,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 2, 2]>,
  //
  // Quad-register Integer Count (4 cycles)
  // Result written in N3, but that is relative to the last cycle of multicycle,
  // so we use 4 for those cases
  // Note: VCNTiQ class is a VX pipe instruction
  // VCLS, VCLZ, VCNT latency = 4 Throughput = 2?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VCNTiQ,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [4, 2, 2]>,
  //
  // Double-register Integer Count (2 cycles)
  // Note: VCNTi2D class is a VX pipe instruction
  // VBSL latency = 2 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VCNTi2D,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [2, 1, 1]>,
  //
  // Quad-register Integer Count (2 cycles)
  // Result written in N3, but that is relative to the last cycle of multicycle,
  // so we use 4 for those cases
  // Note: VCNTi2Q class is a VX pipe instruction
  // VBSL latency = 2 Throughput = 2?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VCNTi2Q,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [2, 1, 1]>,
  //
  // Double-register Absolute Difference and Accumulate
  // Note: VABAD class is a VX pipe instruction
  // VABA latency =4 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VABAD,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 3, 2, 1]>,
  //
  // Quad-register Absolute Difference and Accumulate
  // Note: VABAQ class is a VX pipe instruction
  // VABA latency =4 Throughput = 2?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VABAQ,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [4, 3, 2, 1]>,
  //
  // Double-register Integer Pair Add Accumulate Long
  // Note: VPALiD class is a VX pipe instruction
  // VSRA latency = 3 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VPALiD,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [3, 1, 1]>,
  //
  // Quad-register Integer Pair Add Accumulate Long
  // Note: VPALiQ class is a VX pipe instruction
  // VPADL latency = 4 Throughput = 2?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VPALiQ,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [4, 1, 1]>,

  //
  // Double-register Integer Multiply (.8, .16)
  // Note: VMULi16D class is a VX pipe instruction
  // VMUL, VQRDMULH round/saturate/double latency = 4 Throughput = 1?
  // VMULL polynomial latency = 2
  // Note: Picking max laltency
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VMULi16D, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 2, 2]>,
  //
  // Quad-register Integer Multiply (.8, .16)
  // Note: VMULi16Q class is a VX pipe instruction
  // VMUL, VQRDMULH round/saturate/double latency = 4 Throughput = 2?
  // VMULL polynomial latency = 2
  // Note: Picking max laltency
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VMULi16Q, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [4, 2, 2]>,

  //
  // Double-register Integer Multiply (.32)
  // Note: VMULi32D class is a VX pipe instruction
  // VMUL, VQRDMULH round/saturate/double latency =4 Throughput = 2?
  // VMULL polynomial latency = 2
  // Note: Picking max laltency
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VMULi32D, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [4, 2, 1]>,
  //
  // Quad-register Integer Multiply (.32)
  // Note: VMULi32Q class is a VX pipe instruction
  // VMUL, VQRDMULH round/saturate/double latency = 4 Throughput = 4?
  // VMULL polynomial latency = 2
  // Note: Picking max laltency
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VMULi32Q, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 9 cycles
                               InstrStage<10, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<4, [KRT2_VX]>],
                              [4, 2, 1]>,
  //
  // Double-register Integer Multiply-Accumulate (.8, .16) (by scalar)
  // Note: VMACi16D class is a VX pipe instruction
  // VMLA, VMLAL, VQMLAL latency = 4 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VMACi16D, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 3, 2, 2]>,
  //
  // Double-register Integer Multiply-Accumulate (.32) (by scalar)
  // Note: VMACi32D class is a VX pipe instruction
  // VMLA, VMLAL, VQMLAL latency = 4 Throughput = 2?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VMACi32D, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [4, 3, 2, 1]>,
  //
  // Quad-register Integer Multiply-Accumulate (.8, .16) (by scalar)
  // Note: VMACi16Q class is a VX pipe instruction
  // VMLA, VMLAL, VQMLAL latency = 4 Throughput = 2?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VMACi16Q, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [4, 3, 2, 2]>,
  //
  // Quad-register Integer Multiply-Accumulate (.32) (by scalar)
  // Note: VMACi32Q class is a VX pipe instruction
  // VMLA, VMLAL, VQMLAL latency = 4 Throughput = 4?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VMACi32Q, [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 9 cycles
                               InstrStage<10, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<4, [KRT2_VX]>],
                              [4, 3, 2, 1]>,

  //
  // Move register
  // Note: VMOV class is a VL pipe instruction
  // VMOV, VORR, VBIC, VMVN, latency = 2 (NeonOpt) Throughput = 1?
  // (in email notes VMOV latency Krait3 = 1)
  InstrItinData<IIC_VMOV,     [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<1, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL]>],
                              [1,1]>,
  //
  // Move Immediate
  // Note: VMOVImm class is a VX pipe instruction
  // VMOV immediate, latency = 1 Throughput = 1?
  // VMOV latency = 1  Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VMOVImm,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [1]>,
  //
  // Double-register Move (Integer to scalar)
  // Note: VMOVD class is a VL pipe instruction
  // VDUP latency = 4, Throughput = 1?
  // VMOV (from GPR) SP latency krait3 = 4 Throughput = 1?
  // (in email latency krait2 = 14)
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VMOVD,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<15, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL]>],
                              [14, 1]>,
  //
  // Quad-register Move (Integer to scalar)
  // Note: VMOVQ class is a VL pipe instruction
  // VDUP latency = 4, Throughput = 1?
  // VMOV (from GPR) SP latency krait3 = 4 Throughput = 1?
  // (in email latency krait2 = 14)
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VMOVQ,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<15, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL]>],
                              [14, 1]>,
  //
  // Double-register Reverse
  // Note: VREVD class is a VL pipe instruction
  // VREV latency = 2, Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VREVD,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL]>],
                              [2, 1]>,
  //
  // Quad-register Reverse
  // Note: VREVQ class is a VL pipe instruction
  // VREV latency = 2, Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VREVQ,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL]>],
                              [2, 1]>,
  //
  // Integer to Single-precision Move
  // Note: VMOVIS class is a VL pipe instruction
  // VMOV (from GPR) SP latency krait3 = 4 Throughput = 1?
  InstrItinData<IIC_VMOVIS ,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<3, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL]>],
                              [4, 1]>,
  //
  // Integer to Double-precision Move
  // Note: VMOVID class is a VL pipe instruction
  // VMOV (from GPR) DP latency krait3 = 4 Throughput = 1?
  InstrItinData<IIC_VMOVID ,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<3, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL]>],
                              [4, 1, 1]>,
  //
  // Single-precision to Integer Move
  // Note: VMOVSI class is a VS pipe instruction
  // VMOV (to GPR) SP latency krait3 = 3 Throughput = 1?
  InstrItinData<IIC_VMOVSI ,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<3, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VS]>],
                              [3, 1]>,
  //
  // Double-precision to Integer Move
  // Note: VMOVSI class is a VS pipe instruction
  // VMOV (to GPR) DP latency krait3 = 4 Throughput = 1?
  InstrItinData<IIC_VMOVDI ,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<3, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VS]>],
                              [4, 4, 1]>,
  //
  // Integer to Lane Move
  // Note (todo): Assuming VMOVISL class is a VL pipe instruction
  // Modeled VMOV (from GPR) DP latency krait3 = 4 Throughput = 2?
  InstrItinData<IIC_VMOVISL , [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               InstrStage<4, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL]>],
                              [4, 1, 1]>,

  //
  // Vector narrow move
  // Note (todo): Assuming VMOVN class is a VX pipe instruction
  // VMOVN latency = 3, Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VMOVN,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [3, 1]>,
  //
  // Double-register FP Unary (4 cycles)
  // Note (todo): Assuming VUNAD class is a VX pipe instruction
  // VRECPE, VRSQRTE, VCVT latency = 4 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VUNAD,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 2]>,
  //
  // Quad-register FP Unary (4 cycles)
  // Result written in N5, but that is relative to the last cycle of multicycle,
  // so we use 6 for those cases
  // Note (todo): Assuming VUNAQ class is a VX pipe instruction
  // VRECPE, VRSQRTE, VCVT latency = 4 Throughput = 2?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VUNAQ,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [4, 2]>,
  //
  // Double-register FP Unary (1 cycle)
  // Note (todo): Assuming VUNA1D class is a VX pipe instruction
  // VNEG, VABS latency = 1 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VUNA1D,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [1, 1]>,
  //
  // Quad-register FP Unary (1 cycle)
  // Result written in N5, but that is relative to the last cycle of multicycle,
  // so we use 6 for those cases
  // Note (todo): Assuming VUNA1Q class is a VX pipe instruction
  // VNEG, VABS latency = 1 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VUNA1Q,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [1, 1]>,

  //
  // Double-register FP Binary (4 cycles)
  // Note:  VBIND class is a VX pipe instruction
  // VADD, VQADD, VMul with scalar latency krait3 =4 Throughput = 1?
  // (in email notes latency VADD, VQADD krait2 = 7)
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VBIND,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [7, 2, 2]>,

  //
  // Double-register FP Add (4 cycles) (in SP)
  // Note:  VBIND class is a VX pipe instruction
  // VADD, VQADD, VMul with scalar latency krait3 =4 Throughput = 1?
  // (in email notes latency VADD, VQADD krait2 = 5)
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VADDD,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [5, 2, 2]>,

  //
  // Double-register FP Binary (2 cycles)
  // Note:  VBIN2D class is a VX pipe instruction
  // VCEQ, VCGE, VCGT, VACGE, VACGT, VABD, VMax,VMin latency =2 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VBIN2D,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [2, 1, 1]>,

  //
  // Integer Pairwise (4 cycles)
  // Note:  VPBIND class is a VX pipe instruction
  // VPADD, VPADAL latency = 4 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VPBIND,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [4, 1, 1]>,
  //
  // Integer Pairwise (2 cycles)
  // Note:  VPBIN2D class is a VX pipe instruction
  // VPMAX latency = 2 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VPBIN2D,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [2, 1, 1]>,
  //
  // Double-register FP VMUL
  // Note:  VFMULD class is a VX pipe instruction
  // VMUL latency = 5 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VFMULD,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [5, 2, 1]>,
  //
  // Quad-register FP Binary (4 cycles)
  // Note:  VBINQ class is a VX pipe instruction
  // VADD, VQADD, VMul with scalar latency =4 Throughput = 2?
  // (in email notes latency VADD, VQADD krait2 = 7)
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VBINQ,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [7, 2, 2]>,
  //
  // Quad-register FP Add (4 cycles) (in SP)
  // Note:  VBINQ class is a VX pipe instruction
  // VADD, VQADD, VMul with scalar latency =4 Throughput = 2?
  // (in email notes latency VADD, VQADD krait2 = 5)
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VADDQ,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [5, 2, 2]>,
  //
  // Quad-register FP Binary (2 cycles)
  // Result written in N5, but that is relative to the last cycle of multicycle,
  // so we use 6 for those cases
  // Note:  VBIN2Q class is a VX pipe instruction
  // VCEQ, VCGE, VCGT, VACGE, VACGT, VABD, Max,VMin latency =2 Throughput = 2?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VBIN2Q,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [2, 1, 1]>,
  //
  // Quad-register FP VMUL
  // Note:  VFMULQ class is a VX pipe instruction
  // VMUL latency = 5 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VFMULQ,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [5, 2, 1]>,
  //
  // Double-register FP Multiple-Accumulate (it is SP)
  // Note:  VMACD class is a VX pipe instruction
  // VMLA, VMLS, VMLA scalar latency = 8 (NeonOpt) Throughput = 2?
  // (in email notes latency krait2 = 9)
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VMACD,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [9, 3, 2, 1]>,
  //
  // Quad-register FP Multiple-Accumulate (it is SP)
  // Result written in N9, but that is relative to the last cycle of multicycle,
  // so we use 10 for those cases
  // Note:  VMACQ class is a VX pipe instruction
  // VMLA, VMLS, VMLA scalar latency = 8 (NeonOpt) Throughput = 4?
  // (in email notes latency krait2 = 9)
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VMACQ,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 9 cycles
                               InstrStage<10, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<4, [KRT2_VX]>],
                              [9, 4, 2, 1]>,
  //
  // Double-register Fused FP Multiple-Accumulate
  // Note:  VFMACD class is a VX pipe instruction
  // VFMA, VFMS latency = 5 (NeonOpt) Throughput = 2?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VFMACD,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [5, 3, 2, 1]>,
  //
  // Quad-register Fused FP Multiple-Accumulate
  // Result written in N9, but that is relative to the last cycle of multicycle,
  // so we use 10 for those cases
  // Note:  VFMACQ class is a VX pipe instruction
  // VFMA, VFMS latency = 5 Throughput = 4?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VFMACQ,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 9 cycles
                               InstrStage<10, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<4, [KRT2_VX]>],
                              [5, 4, 2, 1]>,
  //
  // Double-register Reciprical Step
  // Note:  VRECSD class is a VX pipe instruction
  // VRECPS, VRSQRTS, VCVT latency = 8 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VRECSD,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 10 cycles
                               InstrStage<11, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VX]>],
                              [8, 2, 2]>,
  //
  // Quad-register Reciprical Step
  // Note:  VRECSQ class is a VX pipe instruction
  // VRECPS, VRSQRTS, VCVT latency = 8 Throughput = 2?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VRECSQ,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 11 cycles
                               InstrStage<12, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VX]>],
                              [8, 2, 2]>,
  //
  // Double-register Permute
  // Note:  VPERMD class is a VL pipe instruction
  // VTRN, VZIP, VUZP latency =2 Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VPERMD,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL]>],
                              [2, 2, 1, 1]>,
  //
  // Quad-register Permute
  // Note:  VPERMQ class is a VL pipe instruction
  // VTRN, VZIP, VUZP latency =2 Throughput = 2?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VPERMQ,   [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL]>],
                              [2, 2, 1, 1]>,
  //
  // Quad-register Permute (3 cycle issue)
  // Note:  VPERMQ3 class is a VL pipe instruction
  // VTRN, VZIP, VUZP latency =2 Throughput = 2?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VPERMQ3,  [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 8 cycles
                               InstrStage<9, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL]>],
                              [2, 2, 1, 1]>,

  //
  // Double-register VEXT
  // Note:  VEXTD class is a VL pipe instruction
  // VEXT latency =2  Throughput = 1?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VEXTD,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 6 cycles
                               InstrStage<7, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<1, [KRT2_VL]>],
                              [2, 1, 1]>,
  //
  // Quad-register VEXT
  // Note:  VEXTQ class is a VL pipe instruction
  // VEXT latency =2  Throughput = 2?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VEXTQ,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL]>],
                              [2, 1, 1]>,
  //
  // VTB
  // Note:  VTB class is a VL pipe instruction
  // VTBL latency =2  Throughput = 2?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VTB1,     [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL]>],
                              [2, 1, 1]>,
  InstrItinData<IIC_VTB2,     [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL]>],
                              [2, 1, 1, 1]>,
  InstrItinData<IIC_VTB3,     [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 8 cycles
                               InstrStage<9, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL]>],
                              [2, 1, 1, 1, 1]>,
  InstrItinData<IIC_VTB4,     [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 8 cycles
                               InstrStage<9, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL]>],
                              [2, 1, 1, 1, 1, 1]>,
  //
  // VTBX
  // Note:  VTBX class is a VL pipe instruction
  // VTBX latency =2  Throughput = 2?
  // Note (todo): Krait wbck cycles not known
  InstrItinData<IIC_VTBX1,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL]>],
                              [2, 1, 1, 1]>,
  InstrItinData<IIC_VTBX2,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 7 cycles
                               InstrStage<8, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL]>],
                              [2, 1, 1, 1, 1]>,
  InstrItinData<IIC_VTBX3,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 8 cycles
                               InstrStage<9, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL]>],
                              [2, 1, 1, 1, 1, 1]>,
  InstrItinData<IIC_VTBX4,    [InstrStage<1, [KRT2_Issue0, KRT2_Issue1], 0>,
                               InstrStage<1, [KRT2_MUX0], 0>,
                               InstrStage<1, [KRT2_DRegsN],   0, Required>,
                               // Extra latency cycles since wbck is 8 cycles
                               InstrStage<9, [KRT2_DRegsVFP], 0, Reserved>,
                               InstrStage<2, [KRT2_VL]>],
                              [2, 1, 1, 1, 1, 1, 1]>
]>;

// ===---------------------------------------------------------------------===//
// The following definitions describe the simpler per-operand machine model.
// This works with MachineScheduler and will eventually replace itineraries.

class KRT2WriteLMOpsListType<list<WriteSequence> writes> {
  list <WriteSequence> Writes = writes;
  SchedMachineModel SchedModel = ?;
}

// Krait2 machine model for scheduling and other instruction cost heuristics.
def Krait2Model : SchedMachineModel {
  let IssueWidth = 3; // 2 micro-ops are dispatched per cycle.
  let MicroOpBufferSize = 45; // Based on NEON renamed registers.
  let LoadLatency = 3; // Optimistic load latency assuming bypass.
                       // This is overriden by OperandCycles if the
                       // Itineraries are queried instead.
  let MispredictPenalty = 14; // Based on estimate of pipeline depth.

  let Itineraries = Krait2Itineraries;

  // FIXME: Many vector operations were never given an itinerary. We
  // haven't mapped these to the new model either.
  let CompleteModel = 0;
}

//===----------------------------------------------------------------------===//
// Define each kind of processor resource and number available.
//
// The AGU unit has BufferSize=1 so that the latency between operations
// that use it are considered to stall other operations.
//
// The FP unit has BufferSize=0 so that it is a hard dispatch
// hazard. No instruction may be dispatched while the unit is reserved.

let SchedModel = Krait2Model in {

def KRT2UnitALU : ProcResource<2>;
def KRT2UnitMul : ProcResource<1> { let Super = KRT2UnitALU; }
def KRT2UnitAGU : ProcResource<1> { let BufferSize = 1; }
def KRT2UnitLS  : ProcResource<1>;
def KRT2UnitFP  : ProcResource<1> { let BufferSize = 0; }
def KRT2UnitB   : ProcResource<1>;

//===----------------------------------------------------------------------===//
// Define scheduler read/write types with their resources and latency on KRT2.

// Consume an issue slot, but no processor resources. This is useful when all
// other writes associated with the operand have NumMicroOps = 0.
def KRT2WriteIssue : SchedWriteRes<[]> { let Latency = 0; }

// Write an integer register.
def KRT2WriteI : SchedWriteRes<[KRT2UnitALU]>;
// Write an integer shifted-by register
def KRT2WriteIsr : SchedWriteRes<[KRT2UnitALU]> { let Latency = 2; }

// Basic ALU.
def KRT2WriteALU : SchedWriteRes<[KRT2UnitALU]>;
// ALU with operand shifted by immediate.
def : WriteRes<WriteALUsi, [KRT2UnitALU]> { let Latency = 2; }
// ALU with operand shifted by register.
def KRT2WriteALUsr : SchedWriteRes<[KRT2UnitALU]> { let Latency = 3; }

// Multiplication
def KRT2WriteM   : SchedWriteRes<[KRT2UnitMul, KRT2UnitMul]> { let Latency = 4; }
def KRT2WriteMHi : SchedWriteRes<[KRT2UnitMul]> { let Latency = 5;
                                              let NumMicroOps = 0; }
def KRT2WriteM16   : SchedWriteRes<[KRT2UnitMul]> { let Latency = 3; }
def KRT2WriteM16Hi : SchedWriteRes<[KRT2UnitMul]> { let Latency = 4;
                                                let NumMicroOps = 0; }

// Floating-point
// Only one FP or AGU instruction may issue per cycle. We model this
// by having FP instructions consume the AGU resource.
def KRT2WriteF      : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 4; }
def KRT2WriteFMov   : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 1; }
def KRT2WriteFMulS  : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 5; }
def KRT2WriteFMulD  : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 6; }
def KRT2WriteFMAS   : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 8; }
def KRT2WriteFMAD   : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 9; }
def KRT2WriteFDivS  : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 15; }
def KRT2WriteFDivD  : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 25; }
def KRT2WriteFSqrtS : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 17; }
def KRT2WriteFSqrtD : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 32; }

// NEON has an odd mix of latencies. Simply name the write types by latency.
def KRT2WriteV1 : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 1; }
def KRT2WriteV2 : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 2; }
def KRT2WriteV3 : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 3; }
def KRT2WriteV4 : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 4; }
def KRT2WriteV5 : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 5; }
def KRT2WriteV6 : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 6; }
def KRT2WriteV7 : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 7; }
def KRT2WriteV9 : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 9; }
def KRT2WriteV10 : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> { let Latency = 10; }

// Reserve KRT2UnitFP for 2 consecutive cycles.
def KRT2Write2V4 : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> {
  let Latency = 4;
  let ResourceCycles = [2];
}
def KRT2Write2V7 : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> {
  let Latency = 7;
  let ResourceCycles = [2];
}
def KRT2Write2V9 : SchedWriteRes<[KRT2UnitFP, KRT2UnitAGU]> {
  let Latency = 9;
  let ResourceCycles = [2];
}

// Branches don't have a def operand but still consume resources.
def KRT2WriteB : SchedWriteRes<[KRT2UnitB]>;

// Address generation.
def KRT2WriteAdr : SchedWriteRes<[KRT2UnitAGU]> { let NumMicroOps = 0; }

// Load Integer.
def KRT2WriteL : SchedWriteRes<[KRT2UnitLS]> { let Latency = 3; }
// Load the upper 32-bits using the same micro-op.
def KRT2WriteLHi : SchedWriteRes<[]> { let Latency = 3;
                                     let NumMicroOps = 0; }
// Offset shifted by register.
def KRT2WriteLsi : SchedWriteRes<[KRT2UnitLS]> { let Latency = 4; }
// Load (and zero extend) a byte.
def KRT2WriteLb : SchedWriteRes<[KRT2UnitLS]> { let Latency = 4; }
def KRT2WriteLbsi : SchedWriteRes<[KRT2UnitLS]> { let Latency = 5; }

// Load or Store Float, aligned.
def KRT2WriteLSfp : SchedWriteRes<[KRT2UnitLS, KRT2UnitFP]> { let Latency = 1; }

// Store Integer.
def KRT2WriteS : SchedWriteRes<[KRT2UnitLS]>;

//===----------------------------------------------------------------------===//
// Define resources dynamically for load multiple variants.

// Define helpers for extra latency without consuming resources.
def KRT2WriteCycle1 : SchedWriteRes<[]> { let Latency = 1; let NumMicroOps = 0; }
foreach NumCycles = 2-8 in {
def KRT2WriteCycle#NumCycles : WriteSequence<[KRT2WriteCycle1], NumCycles>;
} // foreach NumCycles

// Define address generation sequences and predicates for 8 flavors of LDMs.
foreach NumAddr = 1-8 in {

// Define KRT2WriteAdr1-8 as a sequence of KRT2WriteAdr with additive
// latency for instructions that generate multiple loads or stores.
def KRT2WriteAdr#NumAddr : WriteSequence<[KRT2WriteAdr], NumAddr>;

// Define a predicate to select the LDM based on number of memory addresses.
def KRT2LMAdr#NumAddr#Pred :
  SchedPredicate<"(TII->getNumLDMAddresses(MI)+1)/2 == "#NumAddr>;

} // foreach NumAddr

// Fall-back for unknown LDMs.
def KRT2LMUnknownPred : SchedPredicate<"TII->getNumLDMAddresses(MI) == 0">;

// LDM/VLDM/VLDn address generation latency & resources.
// Dynamically select the KRT2WriteAdrN sequence using a predicate.
def KRT2WriteLMAdr : SchedWriteVariant<[
  SchedVar<KRT2LMAdr1Pred, [KRT2WriteAdr1]>,
  SchedVar<KRT2LMAdr2Pred, [KRT2WriteAdr2]>,
  SchedVar<KRT2LMAdr3Pred, [KRT2WriteAdr3]>,
  SchedVar<KRT2LMAdr4Pred, [KRT2WriteAdr4]>,
  SchedVar<KRT2LMAdr5Pred, [KRT2WriteAdr5]>,
  SchedVar<KRT2LMAdr6Pred, [KRT2WriteAdr6]>,
  SchedVar<KRT2LMAdr7Pred, [KRT2WriteAdr7]>,
  SchedVar<KRT2LMAdr8Pred, [KRT2WriteAdr8]>,
  // For unknown LDM/VLDM/VSTM, assume 2 32-bit registers.
  SchedVar<KRT2LMUnknownPred, [KRT2WriteAdr2]>]>;

// Define LDM Resources.
// These take no issue resource, so they can be combined with other
// writes like WriteB.
// KRT2WriteLMLo takes a single LS resource and 2 cycles.
def KRT2WriteLMLo : SchedWriteRes<[KRT2UnitLS]> { let Latency = 2;
                                              let NumMicroOps = 0; }
// Assuming aligned access, the upper half of each pair is free with
// the same latency.
def KRT2WriteLMHi : SchedWriteRes<[]> { let Latency = 2;
                                      let NumMicroOps = 0; }
// Each KRT2WriteL#N variant adds N cycles of latency without consuming
// additional resources.
foreach NumAddr = 1-8 in {
def KRT2WriteL#NumAddr : WriteSequence<
  [KRT2WriteLMLo, !cast<SchedWrite>("KRT2WriteCycle"#NumAddr)]>;
def KRT2WriteL#NumAddr#Hi : WriteSequence<
  [KRT2WriteLMHi, !cast<SchedWrite>("KRT2WriteCycle"#NumAddr)]>;
}

//===----------------------------------------------------------------------===//
// LDM: Load multiple into 32-bit integer registers.

def KRT2WriteLMOpsList : KRT2WriteLMOpsListType<
                 [KRT2WriteL1, KRT2WriteL1Hi,
                  KRT2WriteL2, KRT2WriteL2Hi,
                  KRT2WriteL3, KRT2WriteL3Hi,
                  KRT2WriteL4, KRT2WriteL4Hi,
                  KRT2WriteL5, KRT2WriteL5Hi,
                  KRT2WriteL6, KRT2WriteL6Hi,
                  KRT2WriteL7, KRT2WriteL7Hi,
                  KRT2WriteL8, KRT2WriteL8Hi]>;

// KRT2WriteLM variants expand into a pair of writes for each 64-bit
// value loaded. When the number of registers is odd, the last
// KRT2WriteLnHi is naturally ignored because the instruction has no
// following def operands.  These variants take no issue resource, so
// they may need to be part of a WriteSequence that includes KRT2WriteIssue.
def KRT2WriteLM : SchedWriteVariant<[
  SchedVar<KRT2LMAdr1Pred, KRT2WriteLMOpsList.Writes[0-1]>,
  SchedVar<KRT2LMAdr2Pred, KRT2WriteLMOpsList.Writes[0-3]>,
  SchedVar<KRT2LMAdr3Pred, KRT2WriteLMOpsList.Writes[0-5]>,
  SchedVar<KRT2LMAdr4Pred, KRT2WriteLMOpsList.Writes[0-7]>,
  SchedVar<KRT2LMAdr5Pred, KRT2WriteLMOpsList.Writes[0-9]>,
  SchedVar<KRT2LMAdr6Pred, KRT2WriteLMOpsList.Writes[0-11]>,
  SchedVar<KRT2LMAdr7Pred, KRT2WriteLMOpsList.Writes[0-13]>,
  SchedVar<KRT2LMAdr8Pred, KRT2WriteLMOpsList.Writes[0-15]>,
  // For unknown LDMs, define the maximum number of writes, but only
  // make the first two consume resources.
  SchedVar<KRT2LMUnknownPred, [KRT2WriteL1, KRT2WriteL1Hi,
                             KRT2WriteL2, KRT2WriteL2Hi,
                             KRT2WriteL3Hi, KRT2WriteL3Hi,
                             KRT2WriteL4Hi, KRT2WriteL4Hi,
                             KRT2WriteL5Hi, KRT2WriteL5Hi,
                             KRT2WriteL6Hi, KRT2WriteL6Hi,
                             KRT2WriteL7Hi, KRT2WriteL7Hi,
                             KRT2WriteL8Hi, KRT2WriteL8Hi]>]> {
  let Variadic = 1;
}

//===----------------------------------------------------------------------===//
// VFP Load/Store Multiple Variants, and NEON VLDn/VSTn support.

// KRT2WriteLfpOp is the same as KRT2WriteLSfp but takes no issue resources
// so can be used in WriteSequences for in single-issue instructions that
// encapsulate multiple loads.
def KRT2WriteLfpOp : SchedWriteRes<[KRT2UnitLS, KRT2UnitFP]> {
  let Latency = 1;
  let NumMicroOps = 0;
}

foreach NumAddr = 1-8 in {

// Helper for KRT2WriteLfp1-8: A sequence of fp loads with no micro-ops.
def KRT2WriteLfp#NumAddr#Seq : WriteSequence<[KRT2WriteLfpOp], NumAddr>;

// KRT2WriteLfp1-8 definitions are statically expanded into a sequence of
// KRT2WriteLfpOps with additive latency that takes a single issue slot.
// Used directly to describe NEON VLDn.
def KRT2WriteLfp#NumAddr : WriteSequence<
  [KRT2WriteIssue, !cast<SchedWrite>("KRT2WriteLfp"#NumAddr#Seq)]>;

// KRT2WriteLfp1-8Mov adds a cycle of latency and FP resource for
// permuting loaded values.
def KRT2WriteLfp#NumAddr#Mov : WriteSequence<
  [KRT2WriteF, !cast<SchedWrite>("KRT2WriteLfp"#NumAddr#Seq)]>;

} // foreach NumAddr

// Define VLDM/VSTM PreRA resources.
// KRT2WriteLMfpPreRA are dynamically expanded into the correct
// KRT2WriteLfp1-8 sequence based on a predicate. This supports the
// preRA VLDM variants in which all 64-bit loads are written to the
// same tuple of either single or double precision registers.
def KRT2WriteLMfpPreRA : SchedWriteVariant<[
  SchedVar<KRT2LMAdr1Pred, [KRT2WriteLfp1]>,
  SchedVar<KRT2LMAdr2Pred, [KRT2WriteLfp2]>,
  SchedVar<KRT2LMAdr3Pred, [KRT2WriteLfp3]>,
  SchedVar<KRT2LMAdr4Pred, [KRT2WriteLfp4]>,
  SchedVar<KRT2LMAdr5Pred, [KRT2WriteLfp5]>,
  SchedVar<KRT2LMAdr6Pred, [KRT2WriteLfp6]>,
  SchedVar<KRT2LMAdr7Pred, [KRT2WriteLfp7]>,
  SchedVar<KRT2LMAdr8Pred, [KRT2WriteLfp8]>,
  // For unknown VLDM/VSTM PreRA, assume 2xS registers.
  SchedVar<KRT2LMUnknownPred, [KRT2WriteLfp2]>]>;

// Define VLDM/VSTM PostRA Resources.
// KRT2WriteLMfpLo takes a LS and FP resource and one issue slot but no latency.
def KRT2WriteLMfpLo : SchedWriteRes<[KRT2UnitLS, KRT2UnitFP]> { let Latency = 0; }

foreach NumAddr = 1-8 in {

// Each KRT2WriteL#N variant adds N cycles of latency without consuming
// additional resources.
def KRT2WriteLMfp#NumAddr : WriteSequence<
  [KRT2WriteLMfpLo, !cast<SchedWrite>("KRT2WriteCycle"#NumAddr)]>;

// Assuming aligned access, the upper half of each pair is free with
// the same latency.
def KRT2WriteLMfp#NumAddr#Hi : WriteSequence<
  [KRT2WriteLMHi, !cast<SchedWrite>("KRT2WriteCycle"#NumAddr)]>;

} // foreach NumAddr

// VLDM PostRA Variants. These variants expand KRT2WriteLMfpPostRA into a
// pair of writes for each 64-bit data loaded. When the number of
// registers is odd, the last WriteLMfpnHi is naturally ignored because
// the instruction has no following def operands.

def KRT2WriteLMfpPostRAOpsList : KRT2WriteLMOpsListType<
                 [KRT2WriteLMfp1, KRT2WriteLMfp2,       // 0-1
                  KRT2WriteLMfp3, KRT2WriteLMfp4,       // 2-3
                  KRT2WriteLMfp5, KRT2WriteLMfp6,       // 4-5
                  KRT2WriteLMfp7, KRT2WriteLMfp8,       // 6-7
                  KRT2WriteLMfp1Hi,                   // 8-8
                  KRT2WriteLMfp2Hi, KRT2WriteLMfp2Hi,   // 9-10
                  KRT2WriteLMfp3Hi, KRT2WriteLMfp3Hi,   // 11-12
                  KRT2WriteLMfp4Hi, KRT2WriteLMfp4Hi,   // 13-14
                  KRT2WriteLMfp5Hi, KRT2WriteLMfp5Hi,   // 15-16
                  KRT2WriteLMfp6Hi, KRT2WriteLMfp6Hi,   // 17-18
                  KRT2WriteLMfp7Hi, KRT2WriteLMfp7Hi,   // 19-20
                  KRT2WriteLMfp8Hi, KRT2WriteLMfp8Hi]>; // 21-22

def KRT2WriteLMfpPostRA : SchedWriteVariant<[
  SchedVar<KRT2LMAdr1Pred, KRT2WriteLMfpPostRAOpsList.Writes[0-0, 8-8]>,
  SchedVar<KRT2LMAdr2Pred, KRT2WriteLMfpPostRAOpsList.Writes[0-1, 9-10]>,
  SchedVar<KRT2LMAdr3Pred, KRT2WriteLMfpPostRAOpsList.Writes[0-2, 10-12]>,
  SchedVar<KRT2LMAdr4Pred, KRT2WriteLMfpPostRAOpsList.Writes[0-3, 11-14]>,
  SchedVar<KRT2LMAdr5Pred, KRT2WriteLMfpPostRAOpsList.Writes[0-4, 12-16]>,
  SchedVar<KRT2LMAdr6Pred, KRT2WriteLMfpPostRAOpsList.Writes[0-5, 13-18]>,
  SchedVar<KRT2LMAdr7Pred, KRT2WriteLMfpPostRAOpsList.Writes[0-6, 14-20]>,
  SchedVar<KRT2LMAdr8Pred, KRT2WriteLMfpPostRAOpsList.Writes[0-7, 15-22]>,
  // For unknown LDMs, define the maximum number of writes, but only
  // make the first two consume resources. We are optimizing for the case
  // where the operands are DPRs, and this determines the first eight
  // types. The remaining eight types are filled to cover the case
  // where the operands are SPRs.
  SchedVar<KRT2LMUnknownPred, [KRT2WriteLMfp1, KRT2WriteLMfp2,
                             KRT2WriteLMfp3Hi, KRT2WriteLMfp4Hi,
                             KRT2WriteLMfp5Hi, KRT2WriteLMfp6Hi,
                             KRT2WriteLMfp7Hi, KRT2WriteLMfp8Hi,
                             KRT2WriteLMfp5Hi, KRT2WriteLMfp5Hi,
                             KRT2WriteLMfp6Hi, KRT2WriteLMfp6Hi,
                             KRT2WriteLMfp7Hi, KRT2WriteLMfp7Hi,
                             KRT2WriteLMfp8Hi, KRT2WriteLMfp8Hi]>]> {
  let Variadic = 1;
}

// Distinguish between our multiple MI-level forms of the same
// VLDM/VSTM instructions.
def KRT2PreRA : SchedPredicate<
  "TargetRegisterInfo::isVirtualRegister(MI->getOperand(0).getReg())">;
def KRT2PostRA : SchedPredicate<
  "TargetRegisterInfo::isPhysicalRegister(MI->getOperand(0).getReg())">;

// VLDM represents all destination registers as a single register
// tuple, unlike LDM. So the number of write operands is not variadic.
def KRT2WriteLMfp : SchedWriteVariant<[
  SchedVar<KRT2PreRA, [KRT2WriteLMfpPreRA]>,
  SchedVar<KRT2PostRA, [KRT2WriteLMfpPostRA]>]>;

//===----------------------------------------------------------------------===//
// Resources for other (non-LDM/VLDM) Variants.

// These mov immediate writers are unconditionally expanded with
// additive latency.
def KRT2WriteI2 : WriteSequence<[KRT2WriteI, KRT2WriteI]>;
def KRT2WriteI2pc : WriteSequence<[KRT2WriteI, KRT2WriteI, WriteALU]>;
def KRT2WriteI2ld  : WriteSequence<[KRT2WriteI, KRT2WriteI, KRT2WriteL]>;

// Some ALU operations can read loaded integer values one cycle early.
def KRT2ReadALU : SchedReadAdvance<1,
  [KRT2WriteL, KRT2WriteLHi, KRT2WriteLsi, KRT2WriteLb, KRT2WriteLbsi,
   KRT2WriteL1, KRT2WriteL2, KRT2WriteL3, KRT2WriteL4,
   KRT2WriteL5, KRT2WriteL6, KRT2WriteL7, KRT2WriteL8,
   KRT2WriteL1Hi, KRT2WriteL2Hi, KRT2WriteL3Hi, KRT2WriteL4Hi,
   KRT2WriteL5Hi, KRT2WriteL6Hi, KRT2WriteL7Hi, KRT2WriteL8Hi]>;

// Read types for operands that are unconditionally read in cycle N
// after the instruction issues, decreases producer latency by N-1.
def KRT2Read2 : SchedReadAdvance<1>;
def KRT2Read3 : SchedReadAdvance<2>;
def KRT2Read4 : SchedReadAdvance<3>;

//===----------------------------------------------------------------------===//
// Map itinerary classes to scheduler read/write resources per operand.
//
// For ARM, we piggyback scheduler resources on the Itinerary classes
// to avoid perturbing the existing instruction definitions.

// This table follows the ARM Cortex-KRT2 Technical Reference Manuals,
// mostly in order.

def :ItinRW<[WriteALU], [IIC_iMOVi,IIC_iMOVr,IIC_iMOVsi,
                         IIC_iMVNi,IIC_iMVNsi,
                         IIC_iCMOVi,IIC_iCMOVr,IIC_iCMOVsi]>;
def :ItinRW<[WriteALU, KRT2ReadALU],[IIC_iMVNr]>;
def :ItinRW<[KRT2WriteIsr], [IIC_iMOVsr,IIC_iMVNsr,IIC_iCMOVsr]>;

def :ItinRW<[KRT2WriteI2],   [IIC_iMOVix2,IIC_iCMOVix2]>;
def :ItinRW<[KRT2WriteI2pc], [IIC_iMOVix2addpc]>;
def :ItinRW<[KRT2WriteI2ld], [IIC_iMOVix2ld]>;

def :ItinRW<[WriteALU], [IIC_iBITi,IIC_iBITr,IIC_iUNAr,IIC_iTSTi,IIC_iTSTr]>;
def :ItinRW<[WriteALU, KRT2ReadALU], [IIC_iALUi, IIC_iCMPi, IIC_iCMPsi]>;
def :ItinRW<[WriteALU, KRT2ReadALU, KRT2ReadALU],[IIC_iALUr,IIC_iCMPr]>;
def :ItinRW<[WriteALUsi], [IIC_iBITsi,IIC_iUNAsi,IIC_iEXTr,IIC_iTSTsi]>;
def :ItinRW<[WriteALUsi, KRT2ReadALU], [IIC_iALUsi]>;
def :ItinRW<[WriteALUsi, ReadDefault, KRT2ReadALU], [IIC_iALUsir]>; // RSB
def :ItinRW<[KRT2WriteALUsr], [IIC_iBITsr,IIC_iTSTsr,IIC_iEXTAr,IIC_iEXTAsr]>;
def :ItinRW<[KRT2WriteALUsr, KRT2ReadALU], [IIC_iALUsr,IIC_iCMPsr]>;

// KRT2WriteHi ignored for MUL32.
def :ItinRW<[KRT2WriteM, KRT2WriteMHi], [IIC_iMUL32,IIC_iMAC32,
                                     IIC_iMUL64,IIC_iMAC64]>;
// FIXME: SMLALxx needs itin classes
def :ItinRW<[KRT2WriteM16, KRT2WriteM16Hi], [IIC_iMUL16,IIC_iMAC16]>;

// TODO: For floating-point ops, we model the pipeline forwarding
// latencies here. WAW latencies are sometimes longer.

def :ItinRW<[KRT2WriteFMov], [IIC_fpSTAT, IIC_fpMOVIS, IIC_fpMOVID, IIC_fpMOVSI,
                            IIC_fpUNA32, IIC_fpUNA64,
                            IIC_fpCMP32, IIC_fpCMP64]>;
def :ItinRW<[KRT2WriteFMov, KRT2WriteFMov], [IIC_fpMOVDI]>;
def :ItinRW<[KRT2WriteF], [IIC_fpCVTSD, IIC_fpCVTDS, IIC_fpCVTSH, IIC_fpCVTHS,
                         IIC_fpCVTIS, IIC_fpCVTID, IIC_fpCVTSI, IIC_fpCVTDI,
                         IIC_fpALU32, IIC_fpALU64]>;
def :ItinRW<[KRT2WriteFMulS], [IIC_fpMUL32]>;
def :ItinRW<[KRT2WriteFMulD], [IIC_fpMUL64]>;
def :ItinRW<[KRT2WriteFMAS], [IIC_fpMAC32]>;
def :ItinRW<[KRT2WriteFMAD], [IIC_fpMAC64]>;
def :ItinRW<[KRT2WriteFDivS], [IIC_fpDIV32]>;
def :ItinRW<[KRT2WriteFDivD], [IIC_fpDIV64]>;
def :ItinRW<[KRT2WriteFSqrtS], [IIC_fpSQRT32]>;
def :ItinRW<[KRT2WriteFSqrtD], [IIC_fpSQRT64]>;

def :ItinRW<[KRT2WriteB], [IIC_Br]>;

// KRT2 PLD is processed in a dedicated unit.
def :ItinRW<[], [IIC_Preload]>;

// Note: We must assume that loads are aligned, since the machine
// model cannot know this statically and KRT2 ignores alignment hints.

// KRT2WriteAdr consumes AGU regardless address writeback. But it's
// latency is only relevant for users of an updated address.
def :ItinRW<[KRT2WriteL, KRT2WriteAdr], [IIC_iLoad_i,IIC_iLoad_r,
                                     IIC_iLoad_iu,IIC_iLoad_ru]>;
def :ItinRW<[KRT2WriteLsi, KRT2WriteAdr], [IIC_iLoad_si,IIC_iLoad_siu]>;
def :ItinRW<[KRT2WriteLb, KRT2WriteAdr2], [IIC_iLoad_bh_i,IIC_iLoad_bh_r,
                                       IIC_iLoad_bh_iu,IIC_iLoad_bh_ru]>;
def :ItinRW<[KRT2WriteLbsi, KRT2WriteAdr2], [IIC_iLoad_bh_si,IIC_iLoad_bh_siu]>;
def :ItinRW<[KRT2WriteL, KRT2WriteLHi, KRT2WriteAdr], [IIC_iLoad_d_i,IIC_iLoad_d_r,
                                            IIC_iLoad_d_ru]>;
// Store either has no def operands, or the one def for address writeback.
def :ItinRW<[KRT2WriteAdr, KRT2WriteS], [IIC_iStore_i, IIC_iStore_r,
                                     IIC_iStore_iu, IIC_iStore_ru,
                                     IIC_iStore_d_i, IIC_iStore_d_r,
                                     IIC_iStore_d_ru]>;
def :ItinRW<[KRT2WriteAdr2, KRT2WriteS], [IIC_iStore_si, IIC_iStore_siu,
                                      IIC_iStore_bh_i, IIC_iStore_bh_r,
                                      IIC_iStore_bh_iu, IIC_iStore_bh_ru]>;
def :ItinRW<[KRT2WriteAdr3, KRT2WriteS], [IIC_iStore_bh_si, IIC_iStore_bh_siu]>;

// KRT2WriteML will be expanded into a separate write for each def
// operand. Address generation consumes resources, but KRT2WriteLMAdr
// is listed after all def operands, so has no effective latency.
//
// Note: KRT2WriteLM expands into an even number of def operands. The
// actual number of def operands may be less by one.
def :ItinRW<[KRT2WriteLM, KRT2WriteLMAdr, KRT2WriteIssue], [IIC_iLoad_m, IIC_iPop]>;

// Load multiple with address writeback has an extra def operand in
// front of the loaded registers.
//
// Reuse the load-multiple variants for store-multiple because the
// resources are identical, For stores only the address writeback
// has a def operand so the WriteL latencies are unused.
def :ItinRW<[KRT2WriteLMAdr, KRT2WriteLM, KRT2WriteIssue], [IIC_iLoad_mu,
                                                      IIC_iStore_m,
                                                      IIC_iStore_mu]>;
def :ItinRW<[KRT2WriteLM, KRT2WriteLMAdr, KRT2WriteB], [IIC_iLoad_mBr, IIC_iPop_Br]>;
def :ItinRW<[KRT2WriteL, KRT2WriteAdr, WriteALU], [IIC_iLoadiALU]>;

def :ItinRW<[KRT2WriteLSfp, KRT2WriteAdr], [IIC_fpLoad32, IIC_fpLoad64]>;

def :ItinRW<[KRT2WriteLMfp, KRT2WriteLMAdr], [IIC_fpLoad_m]>;
def :ItinRW<[KRT2WriteLMAdr, KRT2WriteLMfp], [IIC_fpLoad_mu]>;
def :ItinRW<[KRT2WriteAdr, KRT2WriteLSfp], [IIC_fpStore32, IIC_fpStore64,
                                        IIC_fpStore_m, IIC_fpStore_mu]>;

// Note: Unlike VLDM, VLD1 expects the writeback operand after the
// normal writes.
def :ItinRW<[KRT2WriteLfp1, KRT2WriteAdr1], [IIC_VLD1, IIC_VLD1u,
                                         IIC_VLD1x2, IIC_VLD1x2u]>;
def :ItinRW<[KRT2WriteLfp2, KRT2WriteAdr2], [IIC_VLD1x3, IIC_VLD1x3u,
                                         IIC_VLD1x4, IIC_VLD1x4u,
                                         IIC_VLD4dup, IIC_VLD4dupu]>;
def :ItinRW<[KRT2WriteLfp1Mov, KRT2WriteAdr1], [IIC_VLD1dup, IIC_VLD1dupu,
                                            IIC_VLD2, IIC_VLD2u,
                                            IIC_VLD2dup, IIC_VLD2dupu]>;
def :ItinRW<[KRT2WriteLfp2Mov, KRT2WriteAdr1], [IIC_VLD1ln, IIC_VLD1lnu,
                                            IIC_VLD2x2, IIC_VLD2x2u,
                                            IIC_VLD2ln, IIC_VLD2lnu]>;
def :ItinRW<[KRT2WriteLfp3Mov, KRT2WriteAdr3], [IIC_VLD3, IIC_VLD3u,
                                            IIC_VLD3dup, IIC_VLD3dupu]>;
def :ItinRW<[KRT2WriteLfp4Mov, KRT2WriteAdr4], [IIC_VLD4, IIC_VLD4u,
                                            IIC_VLD4ln, IIC_VLD4lnu]>;
def :ItinRW<[KRT2WriteLfp5Mov, KRT2WriteAdr5], [IIC_VLD3ln, IIC_VLD3lnu]>;

// Vector stores use similar resources to vector loads, so use the
// same write types. The address write must be first for stores with
// address writeback.
def :ItinRW<[KRT2WriteAdr1, KRT2WriteLfp1], [IIC_VST1, IIC_VST1u,
                                         IIC_VST1x2, IIC_VST1x2u,
                                         IIC_VST1ln, IIC_VST1lnu,
                                         IIC_VST2, IIC_VST2u,
                                         IIC_VST2x2, IIC_VST2x2u,
                                         IIC_VST2ln, IIC_VST2lnu]>;
def :ItinRW<[KRT2WriteAdr2, KRT2WriteLfp2], [IIC_VST1x3, IIC_VST1x3u,
                                         IIC_VST1x4, IIC_VST1x4u,
                                         IIC_VST3, IIC_VST3u,
                                         IIC_VST3ln, IIC_VST3lnu,
                                         IIC_VST4, IIC_VST4u,
                                         IIC_VST4ln, IIC_VST4lnu]>;

// NEON moves.
def :ItinRW<[KRT2WriteV2], [IIC_VMOVSI, IIC_VMOVDI, IIC_VMOVD, IIC_VMOVQ]>;
def :ItinRW<[KRT2WriteV1], [IIC_VMOV, IIC_VMOVIS, IIC_VMOVID]>;
def :ItinRW<[KRT2WriteV3], [IIC_VMOVISL, IIC_VMOVN]>;

// NEON integer arithmetic
//
// VADD/VAND/VORR/VEOR/VBIC/VORN/VBIT/VBIF/VBSL
def :ItinRW<[KRT2WriteV3, KRT2Read2, KRT2Read2], [IIC_VBINiD, IIC_VBINiQ]>;
// VSUB/VMVN/VCLSD/VCLZD/VCNTD
def :ItinRW<[KRT2WriteV3, KRT2Read2], [IIC_VSUBiD, IIC_VSUBiQ, IIC_VCNTiD]>;
// VADDL/VSUBL/VNEG are mapped later under IIC_SHLi.
// ...
// VHADD/VRHADD/VQADD/VTST/VADH/VRADH
def :ItinRW<[KRT2WriteV4, KRT2Read2, KRT2Read2], [IIC_VBINi4D, IIC_VBINi4Q]>;

// VSBH/VRSBH/VHSUB/VQSUB/VABD/VCEQ/VCGE/VCGT/VMAX/VMIN/VPMAX/VPMIN/VABDL
def :ItinRW<[KRT2WriteV4, KRT2Read2], [IIC_VSUBi4D, IIC_VSUBi4Q]>;
// VQNEG/VQABS
def :ItinRW<[KRT2WriteV4], [IIC_VQUNAiD, IIC_VQUNAiQ]>;
// VABS
def :ItinRW<[KRT2WriteV4, KRT2Read2], [IIC_VUNAiD, IIC_VUNAiQ]>;
// VPADD/VPADDL are mapped later under IIC_SHLi.
// ...
// VCLSQ/VCLZQ/VCNTQ, takes two cycles.
def :ItinRW<[KRT2Write2V4, KRT2Read3], [IIC_VCNTiQ]>;
// VMOVimm/VMVNimm/VORRimm/VBICimm
def :ItinRW<[KRT2WriteV3], [IIC_VMOVImm]>;
def :ItinRW<[KRT2WriteV6, KRT2Read3, KRT2Read2], [IIC_VABAD, IIC_VABAQ]>;
def :ItinRW<[KRT2WriteV6, KRT2Read3], [IIC_VPALiD, IIC_VPALiQ]>;

// NEON integer multiply
//
// Note: these don't quite match the timing docs, but they do match
// the original KRT2 itinerary.
def :ItinRW<[KRT2WriteV6, KRT2Read2, KRT2Read2], [IIC_VMULi16D]>;
def :ItinRW<[KRT2WriteV7, KRT2Read2, KRT2Read2], [IIC_VMULi16Q]>;
def :ItinRW<[KRT2Write2V7, KRT2Read2], [IIC_VMULi32D]>;
def :ItinRW<[KRT2Write2V9, KRT2Read2], [IIC_VMULi32Q]>;
def :ItinRW<[KRT2WriteV6, KRT2Read3, KRT2Read2, KRT2Read2], [IIC_VMACi16D]>;
def :ItinRW<[KRT2WriteV7, KRT2Read3, KRT2Read2, KRT2Read2], [IIC_VMACi16Q]>;
def :ItinRW<[KRT2Write2V7, KRT2Read3, KRT2Read2], [IIC_VMACi32D]>;
def :ItinRW<[KRT2Write2V9, KRT2Read3, KRT2Read2], [IIC_VMACi32Q]>;

// NEON integer shift
// TODO: Q,Q,Q shifts should actually reserve FP for 2 cycles.
def :ItinRW<[KRT2WriteV3], [IIC_VSHLiD, IIC_VSHLiQ]>;
def :ItinRW<[KRT2WriteV4], [IIC_VSHLi4D, IIC_VSHLi4Q]>;

// NEON permute
def :ItinRW<[KRT2WriteV2, KRT2WriteV2], [IIC_VPERMD, IIC_VPERMQ, IIC_VEXTD]>;
def :ItinRW<[KRT2WriteV3, KRT2WriteV4, ReadDefault, KRT2Read2],
            [IIC_VPERMQ3, IIC_VEXTQ]>;
def :ItinRW<[KRT2WriteV3, KRT2Read2], [IIC_VTB1]>;
def :ItinRW<[KRT2WriteV3, KRT2Read2, KRT2Read2], [IIC_VTB2]>;
def :ItinRW<[KRT2WriteV4, KRT2Read2, KRT2Read2, KRT2Read3], [IIC_VTB3]>;
def :ItinRW<[KRT2WriteV4, KRT2Read2, KRT2Read2, KRT2Read3, KRT2Read3], [IIC_VTB4]>;
def :ItinRW<[KRT2WriteV3, ReadDefault, KRT2Read2], [IIC_VTBX1]>;
def :ItinRW<[KRT2WriteV3, ReadDefault, KRT2Read2, KRT2Read2], [IIC_VTBX2]>;
def :ItinRW<[KRT2WriteV4, ReadDefault, KRT2Read2, KRT2Read2, KRT2Read3], [IIC_VTBX3]>;
def :ItinRW<[KRT2WriteV4, ReadDefault, KRT2Read2, KRT2Read2, KRT2Read3, KRT2Read3],
            [IIC_VTBX4]>;

// NEON floating-point
def :ItinRW<[KRT2WriteV5, KRT2Read2, KRT2Read2], [IIC_VBIND]>;
def :ItinRW<[KRT2WriteV6, KRT2Read2, KRT2Read2], [IIC_VBINQ]>;
def :ItinRW<[KRT2WriteV5, KRT2Read2], [IIC_VUNAD, IIC_VFMULD]>;
def :ItinRW<[KRT2WriteV6, KRT2Read2], [IIC_VUNAQ, IIC_VFMULQ]>;
def :ItinRW<[KRT2WriteV9, KRT2Read3, KRT2Read2], [IIC_VMACD, IIC_VFMACD]>;
def :ItinRW<[KRT2WriteV10, KRT2Read3, KRT2Read2], [IIC_VMACQ, IIC_VFMACQ]>;
def :ItinRW<[KRT2WriteV9, KRT2Read2, KRT2Read2], [IIC_VRECSD]>;
def :ItinRW<[KRT2WriteV10, KRT2Read2, KRT2Read2], [IIC_VRECSQ]>;

// Map SchedRWs that are identical for cortexa9 to existing resources.
def : SchedAlias<WriteALU, KRT2WriteALU>;
def : SchedAlias<WriteALUsr, KRT2WriteALUsr>;
def : SchedAlias<WriteALUSsr, KRT2WriteALUsr>;
def : SchedAlias<ReadALU, KRT2ReadALU>;
def : SchedAlias<ReadALUsr, KRT2ReadALU>;
def : InstRW< [WriteALU],
      (instregex "ANDri", "ORRri", "EORri", "BICri", "ANDrr", "ORRrr", "EORrr",
                 "BICrr")>;
def : InstRW< [WriteALUsi], (instregex "ANDrsi", "ORRrsi", "EORrsi", "BICrsi")>;
def : InstRW< [WriteALUsr], (instregex "ANDrsr", "ORRrsr", "EORrsr", "BICrsr")>;


def : SchedAlias<WriteCMP, KRT2WriteALU>;
def : SchedAlias<WriteCMPsi, KRT2WriteALU>;
def : SchedAlias<WriteCMPsr, KRT2WriteALU>;

def : InstRW< [KRT2WriteIsr], (instregex "MOVsr", "MOVsi", "MVNsr", "MOVCCsi",
                                       "MOVCCsr")>;
def : InstRW< [WriteALU, KRT2ReadALU], (instregex "MVNr")>;
def : InstRW< [KRT2WriteI2], (instregex "MOVCCi32imm", "MOVi32imm",
                                      "MOV_ga_dyn")>;
def : InstRW< [KRT2WriteI2pc], (instregex "MOV_ga_pcrel")>;
def : InstRW< [KRT2WriteI2ld], (instregex "MOV_ga_pcrel_ldr")>;

def : InstRW< [WriteALU], (instregex "SEL")>;

def : InstRW< [WriteALUsi], (instregex "BFC", "BFI", "UBFX", "SBFX")>;

def : InstRW< [KRT2WriteM],
      (instregex "MUL", "MULv5", "SMMUL", "SMMULR", "MLA", "MLAv5", "MLS",
      "SMMLA", "SMMLAR", "SMMLS", "SMMLSR")>;
def : InstRW< [KRT2WriteM, KRT2WriteMHi],
      (instregex "SMULL", "SMULLv5", "UMULL", "UMULLv5", "SMLAL$", "UMLAL",
      "UMAAL", "SMLALv5", "UMLALv5", "UMAALv5", "SMLALBB", "SMLALBT", "SMLALTB",
      "SMLALTT")>;
// FIXME: These instructions used to have NoItinerary. Just copied the one from above.
def : InstRW< [KRT2WriteM, KRT2WriteMHi],
      (instregex "SMLAD", "SMLADX", "SMLALD", "SMLALDX", "SMLSD", "SMLSDX",
      "SMLSLD", "SMLLDX", "SMUAD", "SMUADX", "SMUSD", "SMUSDX")>;

def : InstRW<[KRT2WriteM16, KRT2WriteM16Hi],
      (instregex "SMULBB", "SMULBT", "SMULTB", "SMULTT", "SMULWB", "SMULWT")>;
def : InstRW<[KRT2WriteM16, KRT2WriteM16Hi],
      (instregex "SMLABB", "SMLABT", "SMLATB", "SMLATT", "SMLAWB", "SMLAWT")>;

def : InstRW<[KRT2WriteL], (instregex "LDRi12", "PICLDR$")>;
def : InstRW<[KRT2WriteLsi], (instregex "LDRrs")>;
def : InstRW<[KRT2WriteLb],
      (instregex "LDRBi12", "PICLDRH", "PICLDRB", "PICLDRSH", "PICLDRSB",
      "LDRH", "LDRSH", "LDRSB")>;
def : InstRW<[KRT2WriteLbsi], (instregex "LDRrs")>;

def : WriteRes<WriteDiv, []> { let Latency = 0; }

def : WriteRes<WriteBr, [KRT2UnitB]>;
def : WriteRes<WriteBrL, [KRT2UnitB]>;
def : WriteRes<WriteBrTbl, [KRT2UnitB]>;
def : WriteRes<WritePreLd, []>;
def : SchedAlias<WriteCvtFP, KRT2WriteF>;
def : WriteRes<WriteNoop, []> { let Latency = 0; let NumMicroOps = 0; }
} // SchedModel = Krait2Model

