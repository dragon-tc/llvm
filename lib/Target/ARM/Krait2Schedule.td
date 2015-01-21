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
// This following definitions describe the simple machine model which
// will replace itineraries.

// Krait2 machine model for scheduling and other instruction cost heuristics.
def Krait2Model : SchedMachineModel {
  let IssueWidth = 3; // 3 micro-ops are dispatched per cycle.
  let MicroOpBufferSize = 45; // Based on NEON renamed registers.
  let LoadLatency = 3;
  let MispredictPenalty = 14; // A branch direction mispredict.

  let Itineraries = Krait2Itineraries;
}

// Krait2 resource mapping.
let SchedModel = Krait2Model in {
  // Processor resources.
  def KRT2UnitP01 : ProcResource<2>; // ALU unit.
  def KRT2UnitP0 : ProcResource<1> { let Super = KRT2UnitP01; } // Mul unit.
  def KRT2UnitP1 : ProcResource<1> { let Super = KRT2UnitP01; } // Br unit.
  def KRT2UnitP2 : ProcResource<1>; // LS unit.
  def KRT2UnitDiv : ProcResource<1>;

  // Generic resource requirements.
  def KRT2WriteP0OneCycle : SchedWriteRes<[KRT2UnitP0]>;
  def KRT2WriteP0TwoCycle : SchedWriteRes<[KRT2UnitP0]> { let Latency = 2; }
  def KRT2WriteP0FourCycle : SchedWriteRes<[KRT2UnitP0]> { let Latency = 4; }
  def KRT2WriteP0SixCycle : SchedWriteRes<[KRT2UnitP0]> { let Latency = 6; }
  def KRT2WriteP0P1FourCycle : SchedWriteRes<[KRT2UnitP0, KRT2UnitP1]> {
    let Latency = 4;
  }
  def KRT2WriteP0P1SixCycle : SchedWriteRes<[KRT2UnitP0, KRT2UnitP1]> {
    let Latency = 6;
  }
  def KRT2WriteP01OneCycle : SchedWriteRes<[KRT2UnitP01]>;
  def KRT2WriteP1TwoCycle : SchedWriteRes<[KRT2UnitP1]> { let Latency = 2; }
  def KRT2WriteP1FourCycle : SchedWriteRes<[KRT2UnitP1]> { let Latency = 4; }
  def KRT2WriteP1SixCycle : SchedWriteRes<[KRT2UnitP1]> { let Latency = 6; }
  def KRT2WriteP1EightCycle : SchedWriteRes<[KRT2UnitP1]> { let Latency = 8; }
  def KRT2WriteP1TwelveCyc : SchedWriteRes<[KRT2UnitP1]> { let Latency = 12; }
  def KRT2WriteP01OneCycle2x : WriteSequence<[KRT2WriteP01OneCycle], 2>;
  def KRT2WriteP01OneCycle3x : WriteSequence<[KRT2WriteP01OneCycle], 3>;
  def KRT2WriteP01TwoCycle : SchedWriteRes<[KRT2UnitP01]> { let Latency = 2; }
  def KRT2WriteP01ThreeCycleTwoUops : SchedWriteRes<[KRT2UnitP01,
                                                      KRT2UnitP01]> {
    let Latency = 3;
    let NumMicroOps = 2;
  }
  def KRT2WriteP0ThreeCycleThreeUops : SchedWriteRes<[KRT2UnitP0]> {
    let Latency = 3;
    let NumMicroOps = 3;
    let ResourceCycles = [3];
  }
  // Plain load without writeback.
  def KRT2WriteP2ThreeCycle : SchedWriteRes<[KRT2UnitP2]> {
    let Latency = 3;
  }
  def KRT2WriteP2FourCycle : SchedWriteRes<[KRT2UnitP2]> {
    let Latency = 4;
  }
  // A store does not write to a register.
  def KRT2WriteP2 : SchedWriteRes<[KRT2UnitP2]> {
    let Latency = 0;
  }
  foreach Num = 1-4 in {
    def KRT2Write#Num#xP2 : WriteSequence<[KRT2WriteP2], Num>;
  }
  def KRT2WriteP01OneCycle2x_load : WriteSequence<[KRT2WriteP01OneCycle,
                                                    KRT2WriteP01OneCycle,
                                                    KRT2WriteP2ThreeCycle]>;
  // 4.2.4 Arithmetic and Logical.
  // ALU operation register shifted by immediate variant.
  def KRT2WriteALUsi : SchedWriteVariant<[
    // lsl #2, lsl #1, or lsr #1.
    SchedVar<IsFastImmShiftSwiftPred, [KRT2WriteP01TwoCycle]>,
    SchedVar<NoSchedPred,             [WriteALU]>
  ]>;
  def KRT2WriteALUsr : SchedWriteVariant<[
    SchedVar<IsPredicatedPred, [KRT2WriteP01ThreeCycleTwoUops]>,
    SchedVar<NoSchedPred,      [KRT2WriteP01TwoCycle]>
  ]>;
  def KRT2WriteALUSsr : SchedWriteVariant<[
    SchedVar<IsPredicatedPred, [KRT2WriteP0ThreeCycleThreeUops]>,
    SchedVar<NoSchedPred,      [KRT2WriteP01TwoCycle]>
  ]>;
  def KRT2ReadAdvanceALUsr : SchedReadVariant<[
    SchedVar<IsPredicatedPred, [SchedReadAdvance<2>]>,
    SchedVar<NoSchedPred,      [NoReadAdvance]>
  ]>;
  // ADC,ADD,NEG,RSB,RSC,SBC,SUB,ADR
  // AND,BIC,EOR,ORN,ORR
  // CLZ,RBIT,REV,REV16,REVSH,PKH
  def : WriteRes<WriteALU, [KRT2UnitP01]>;
  def : SchedAlias<WriteALUsi, KRT2WriteALUsi>;
  def : SchedAlias<WriteALUsr, KRT2WriteALUsr>;
  def : SchedAlias<WriteALUSsr, KRT2WriteALUSsr>;
  def : ReadAdvance<ReadALU, 0>;
  def : SchedAlias<ReadALUsr, KRT2ReadAdvanceALUsr>;


  def KRT2ChooseShiftKindP01OneOrTwoCycle : SchedWriteVariant<[
    SchedVar<IsFastImmShiftSwiftPred, [KRT2WriteP01OneCycle]>,
    SchedVar<NoSchedPred,             [KRT2WriteP01TwoCycle]>
  ]>;

  // 4.2.5 Integer comparison
  def : WriteRes<WriteCMP, [KRT2UnitP01]>;
  def : SchedAlias<WriteCMPsi, KRT2ChooseShiftKindP01OneOrTwoCycle>;
  def : SchedAlias<WriteCMPsr, KRT2WriteP01TwoCycle>;

  // 4.2.6 Shift, Move
  // Shift
  //  ASR,LSL,ROR,RRX
  //  MOV(register-shiftedregister)  MVN(register-shiftedregister)
  // Move
  //  MOV,MVN
  //  MOVT
  // Sign/Zero extension
  def : InstRW<[KRT2WriteP01OneCycle],
               (instregex "SXTB", "SXTH", "SXTB16", "UXTB", "UXTH", "UXTB16",
                          "t2SXTB", "t2SXTH", "t2SXTB16", "t2UXTB", "t2UXTH",
                          "t2UXTB16")>;
  // Pseudo instructions.
  def : InstRW<[KRT2WriteP01OneCycle2x],
        (instregex "MOVCCi32imm", "MOVi32imm", "MOV_ga_dyn", "t2MOVCCi32imm",
                   "t2MOVi32imm", "t2MOV_ga_dyn")>;
  def : InstRW<[KRT2WriteP01OneCycle3x],
        (instregex "MOV_ga_pcrel", "t2MOV_ga_pcrel", "t2MOVi16_ga_pcrel")>;
  def : InstRW<[KRT2WriteP01OneCycle2x_load],
        (instregex "MOV_ga_pcrel_ldr", "t2MOV_ga_pcrel_ldr")>;

  def KRT2WriteP0TwoCyleTwoUops : WriteSequence<[KRT2WriteP0OneCycle], 2>;

  def KRT2PredP0OneOrTwoCycle : SchedWriteVariant<[
    SchedVar<IsPredicatedPred, [ KRT2WriteP0TwoCyleTwoUops ]>,
    SchedVar<NoSchedPred,     [ KRT2WriteP0OneCycle ]>
  ]>;

  // 4.2.7 Select
  // SEL
  def : InstRW<[KRT2PredP0OneOrTwoCycle], (instregex "SEL", "t2SEL")>;

  // 4.2.8 Bitfield
  // BFI,BFC, SBFX,UBFX
  def : InstRW< [KRT2WriteP01TwoCycle],
        (instregex "BFC", "BFI", "UBFX", "SBFX", "(t|t2)BFC", "(t|t2)BFI",
        "(t|t2)UBFX", "(t|t2)SBFX")>;

  // 4.2.9 Saturating arithmetic
  def : InstRW< [KRT2WriteP01TwoCycle],
        (instregex "QADD", "QSUB", "QDADD", "QDSUB", "SSAT", "SSAT16", "USAT",
        "USAT16", "QADD8", "QADD16", "QSUB8", "QSUB16", "QASX", "QSAX",
        "UQADD8", "UQADD16","UQSUB8","UQSUB16","UQASX","UQSAX", "t2QADD",
        "t2QSUB", "t2QDADD", "t2QDSUB", "t2SSAT", "t2SSAT16", "t2USAT",
        "t2QADD8", "t2QADD16", "t2QSUB8", "t2QSUB16", "t2QASX", "t2QSAX",
        "t2UQADD8", "t2UQADD16","t2UQSUB8","t2UQSUB16","t2UQASX","t2UQSAX")>;

  // 4.2.10 Parallel Arithmetic
  // Not flag setting.
  def : InstRW< [KRT2WriteALUsr],
        (instregex "SADD8", "SADD16", "SSUB8", "SSUB16", "SASX", "SSAX",
        "UADD8", "UADD16", "USUB8", "USUB16", "UASX", "USAX", "t2SADD8",
        "t2SADD16", "t2SSUB8", "t2SSUB16", "t2SASX", "t2SSAX", "t2UADD8",
        "t2UADD16", "t2USUB8", "t2USUB16", "t2UASX", "t2USAX")>;
  // Flag setting.
  def : InstRW< [KRT2WriteP01TwoCycle],
       (instregex "SHADD8", "SHADD16", "SHSUB8", "SHSUB16", "SHASX", "SHSAX",
       "SXTAB", "SXTAB16", "SXTAH", "UHADD8", "UHADD16", "UHSUB8", "UHSUB16",
       "UHASX", "UHSAX", "UXTAB", "UXTAB16", "UXTAH", "t2SHADD8", "t2SHADD16",
       "t2SHSUB8", "t2SHSUB16", "t2SHASX", "t2SHSAX", "t2SXTAB", "t2SXTAB16",
       "t2SXTAH", "t2UHADD8", "t2UHADD16", "t2UHSUB8", "t2UHSUB16", "t2UHASX",
       "t2UHSAX", "t2UXTAB", "t2UXTAB16", "t2UXTAH")>;

  // 4.2.11 Sum of Absolute Difference
  def : InstRW< [KRT2WriteP0P1FourCycle], (instregex "USAD8") >;
  def : InstRW<[KRT2WriteP0P1FourCycle, ReadALU, ReadALU, SchedReadAdvance<2>],
        (instregex "USADA8")>;

  // 4.2.12 Integer Multiply (32-bit result)
  // Two sources.
  def : InstRW< [KRT2WriteP0FourCycle],
        (instregex "MULS", "MUL", "SMMUL", "SMMULR", "SMULBB", "SMULBT",
        "SMULTB", "SMULTT", "SMULWB", "SMULWT", "SMUSD", "SMUSDXi", "t2MUL",
        "t2SMMUL", "t2SMMULR", "t2SMULBB", "t2SMULBT", "t2SMULTB", "t2SMULTT",
        "t2SMULWB", "t2SMULWT", "t2SMUSD")>;

  def KRT2WriteP0P01FiveCycleTwoUops :
      SchedWriteRes<[KRT2UnitP0, KRT2UnitP01]>  {
    let Latency = 5;
  }

  def KRT2PredP0P01FourFiveCycle : SchedWriteVariant<[
    SchedVar<IsPredicatedPred, [ KRT2WriteP0P01FiveCycleTwoUops ]>,
    SchedVar<NoSchedPred,      [ KRT2WriteP0FourCycle ]>
  ]>;

  def KRT2ReadAdvanceFourCyclesPred : SchedReadVariant<[
     SchedVar<IsPredicatedPred, [SchedReadAdvance<4>]>,
     SchedVar<NoSchedPred,      [ReadALU]>
  ]>;

  // Multiply accumulate, three sources
  def : InstRW< [KRT2PredP0P01FourFiveCycle, ReadALU, ReadALU,
                 KRT2ReadAdvanceFourCyclesPred],
        (instregex "MLAS", "MLA", "MLS", "SMMLA", "SMMLAR", "SMMLS", "SMMLSR",
        "t2MLA", "t2MLS", "t2MLAS", "t2SMMLA", "t2SMMLAR", "t2SMMLS",
        "t2SMMLSR")>;

  // 4.2.13 Integer Multiply (32-bit result, Q flag)
  def : InstRW< [KRT2WriteP0FourCycle],
        (instregex "SMUAD", "SMUADX", "t2SMUAD", "t2SMUADX")>;
  def : InstRW< [KRT2PredP0P01FourFiveCycle, ReadALU, ReadALU,
                 KRT2ReadAdvanceFourCyclesPred],
        (instregex "SMLABB", "SMLABT", "SMLATB", "SMLATT", "SMLSD", "SMLSDX",
        "SMLAWB", "SMLAWT", "t2SMLABB", "t2SMLABT", "t2SMLATB", "t2SMLATT",
        "t2SMLSD", "t2SMLSDX", "t2SMLAWB", "t2SMLAWT")>;
  def : InstRW< [KRT2PredP0P01FourFiveCycle],
        (instregex "SMLAD", "SMLADX", "t2SMLAD", "t2SMLADX")>;

  def KRT2P0P0P01FiveCycle : SchedWriteRes<[KRT2UnitP0, KRT2UnitP01]> {
    let Latency = 5;
    let NumMicroOps = 3;
    let ResourceCycles = [2, 1];
  }
  def KRT2Write1Cycle : SchedWriteRes<[]> {
    let Latency = 1;
    let NumMicroOps = 0;
  }
  def KRT2Write5Cycle : SchedWriteRes<[]> {
    let Latency = 5;
    let NumMicroOps = 0;
  }
  def KRT2Write6Cycle : SchedWriteRes<[]> {
    let Latency = 6;
    let NumMicroOps = 0;
  }

  // 4.2.14 Integer Multiply, Long
  def : InstRW< [KRT2P0P0P01FiveCycle, KRT2Write5Cycle],
        (instregex "SMULL$", "UMULL$", "t2SMULL$", "t2UMULL$")>;

  def KRT22P03P01FiveCycle : SchedWriteRes<[KRT2UnitP0, KRT2UnitP01]> {
    let Latency = 7;
    let NumMicroOps = 5;
    let ResourceCycles = [2, 3];
  }

  // 4.2.15 Integer Multiply Accumulate, Long
  // 4.2.16 Integer Multiply Accumulate, Dual
  // 4.2.17 Integer Multiply Accumulate Accumulate, Long
  // We are being a bit inaccurate here.
  def : InstRW< [KRT2Write5Cycle, KRT22P03P01FiveCycle, ReadALU, ReadALU,
                 SchedReadAdvance<4>, SchedReadAdvance<3>],
        (instregex "SMLALS", "UMLALS", "SMLAL", "UMLAL", "MLALBB", "SMLALBT",
        "SMLALTB", "SMLALTT", "SMLALD", "SMLALDX", "SMLSLD", "SMLSLDX",
        "UMAAL", "t2SMLALS", "t2UMLALS", "t2SMLAL", "t2UMLAL", "t2MLALBB", "t2SMLALBT",
        "t2SMLALTB", "t2SMLALTT", "t2SMLALD", "t2SMLALDX", "t2SMLSLD", "t2SMLSLDX",
        "t2UMAAL")>;

  def KRT2Div : SchedWriteRes<[KRT2UnitP0, KRT2UnitDiv]> {
    let NumMicroOps = 1;
    let Latency = 14;
    let ResourceCycles = [1, 14];
  }
  // 4.2.18 Integer Divide
  def : WriteRes<WriteDiv, [KRT2UnitDiv]>; // Workaround.
  def : InstRW <[KRT2Div],
        (instregex "SDIV", "UDIV", "t2SDIV", "t2UDIV")>;

  // 4.2.19 Integer Load Single Element
  // 4.2.20 Integer Load Signextended
  def KRT2WriteP2P01ThreeCycle : SchedWriteRes<[KRT2UnitP2, KRT2UnitP01]> {
    let Latency = 3;
    let NumMicroOps = 2;
  }
  def KRT2WriteP2P01FourCyle : SchedWriteRes<[KRT2UnitP2, KRT2UnitP01]> {
    let Latency = 4;
    let NumMicroOps = 2;
  }
  def KRT2WriteP2P01P01FourCycle : SchedWriteRes<[KRT2UnitP2, KRT2UnitP01,
                                                   KRT2UnitP01]> {
    let Latency = 4;
    let NumMicroOps = 3;
  }
  def KRT2WriteP2P2ThreeCycle : SchedWriteRes<[KRT2UnitP2, KRT2UnitP2]> {
    let Latency = 3;
    let NumMicroOps = 2;
  }
  def KRT2WriteP2P2P01ThreeCycle : SchedWriteRes<[KRT2UnitP2, KRT2UnitP2,
                                                   KRT2UnitP01]> {
    let Latency = 3;
    let NumMicroOps = 3;
  }
  def KRT2WrBackOne : SchedWriteRes<[]> {
    let Latency = 1;
    let NumMicroOps = 0;
  }
  def KRT2WriteLdFour : SchedWriteRes<[]> {
    let Latency = 4;
    let NumMicroOps = 0;
  }
   // Not accurate.
  def : InstRW<[KRT2WriteP2ThreeCycle],
        (instregex "LDR(i12|rs)$", "LDRB(i12|rs)$", "t2LDR(i8|i12|s|pci)",
        "t2LDR(H|B)(i8|i12|s|pci)", "LDREX", "tLDR[BH](r|i|spi|pci|pciASM)",
        "tLDR(r|i|spi|pci|pciASM)")>;
  def : InstRW<[KRT2WriteP2ThreeCycle],
        (instregex "LDRH$",  "PICLDR$", "PICLDR(H|B)$", "LDRcp$")>;
  def : InstRW<[KRT2WriteP2P01FourCyle],
        (instregex "PICLDRS(H|B)$", "t2LDRS(H|B)(i|r|p|s)", "LDRS(H|B)$",
        "t2LDRpci_pic", "tLDRS(B|H)")>;
  def : InstRW<[KRT2WriteP2P01ThreeCycle,  KRT2WrBackOne],
        (instregex "LD(RB|R)(_|T_)(POST|PRE)_(IMM|REG)", "LDRH(_PRE|_POST)",
        "LDR(T|BT)_POST_(REG|IMM)", "LDRHT(i|r)",
        "t2LD(R|RB|RH)_(PRE|POST)", "t2LD(R|RB|RH)T")>;
  def : InstRW<[KRT2WriteP2P01P01FourCycle, KRT2WrBackOne],
        (instregex "LDR(SH|SB)(_POST|_PRE)", "t2LDR(SH|SB)(_POST|_PRE)",
        "LDRS(B|H)T(i|r)", "t2LDRS(B|H)T(i|r)", "t2LDRS(B|H)T")>;

  // 4.2.21 Integer Dual Load
  // Not accurate.
  def : InstRW<[KRT2WriteP2P2ThreeCycle, KRT2WriteLdFour],
        (instregex "t2LDRDi8", "LDRD$")>;
  def : InstRW<[KRT2WriteP2P2P01ThreeCycle, KRT2WriteLdFour, KRT2WrBackOne],
        (instregex "LDRD_(POST|PRE)", "t2LDRD_(POST|PRE)")>;

  // 4.2.22 Integer Load, Multiple
  // NumReg = 1 .. 16
  foreach Lat = 3-25 in {
    def KRT2WriteLM#Lat#Cy : SchedWriteRes<[KRT2UnitP2]> {
      let Latency = Lat;
    }
    def KRT2WriteLM#Lat#CyNo : SchedWriteRes<[]> {
      let Latency = Lat;
      let NumMicroOps = 0;
    }
  }
  // Predicate.
  foreach NumAddr = 1-16 in {
    def KRT2LMAddr#NumAddr#Pred : SchedPredicate<"TII->getNumLDMAddresses(MI) == "#NumAddr>;
  }
  def KRT2WriteLDMAddrNoWB : SchedWriteRes<[KRT2UnitP01]> { let Latency = 0; }
  def KRT2WriteLDMAddrWB : SchedWriteRes<[KRT2UnitP01, KRT2UnitP01]>;
  def KRT2WriteLM : SchedWriteVariant<[
    SchedVar<KRT2LMAddr2Pred, [KRT2WriteLM3Cy, KRT2WriteLM4Cy]>,
    SchedVar<KRT2LMAddr3Pred, [KRT2WriteLM3Cy, KRT2WriteLM4Cy,
                                KRT2WriteLM5Cy]>,
    SchedVar<KRT2LMAddr4Pred, [KRT2WriteLM3Cy, KRT2WriteLM4Cy,
                                KRT2WriteLM5Cy, KRT2WriteLM6Cy]>,
    SchedVar<KRT2LMAddr5Pred, [KRT2WriteLM3Cy, KRT2WriteLM4Cy,
                                KRT2WriteLM5Cy, KRT2WriteLM6Cy,
                                KRT2WriteLM7Cy]>,
    SchedVar<KRT2LMAddr6Pred, [KRT2WriteLM3Cy, KRT2WriteLM4Cy,
                                KRT2WriteLM5Cy, KRT2WriteLM6Cy,
                                KRT2WriteLM7Cy, KRT2WriteLM8Cy]>,
    SchedVar<KRT2LMAddr7Pred, [KRT2WriteLM3Cy, KRT2WriteLM4Cy,
                                KRT2WriteLM5Cy, KRT2WriteLM6Cy,
                                KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM9Cy]>,
    SchedVar<KRT2LMAddr8Pred, [KRT2WriteLM3Cy, KRT2WriteLM4Cy,
                                KRT2WriteLM5Cy, KRT2WriteLM6Cy,
                                KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM9Cy, KRT2WriteLM10Cy]>,
    SchedVar<KRT2LMAddr9Pred, [KRT2WriteLM3Cy, KRT2WriteLM4Cy,
                                KRT2WriteLM5Cy, KRT2WriteLM6Cy,
                                KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM9Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM11Cy]>,
    SchedVar<KRT2LMAddr10Pred,[KRT2WriteLM3Cy, KRT2WriteLM4Cy,
                                KRT2WriteLM5Cy, KRT2WriteLM6Cy,
                                KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM9Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM11Cy, KRT2WriteLM12Cy]>,
    SchedVar<KRT2LMAddr11Pred,[KRT2WriteLM3Cy, KRT2WriteLM4Cy,
                                KRT2WriteLM5Cy, KRT2WriteLM6Cy,
                                KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM9Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM11Cy, KRT2WriteLM12Cy,
                                KRT2WriteLM13Cy]>,
    SchedVar<KRT2LMAddr12Pred,[KRT2WriteLM3Cy, KRT2WriteLM4Cy,
                                KRT2WriteLM5Cy, KRT2WriteLM6Cy,
                                KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM9Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM11Cy, KRT2WriteLM12Cy,
                                KRT2WriteLM13Cy, KRT2WriteLM14Cy]>,
    SchedVar<KRT2LMAddr13Pred,[KRT2WriteLM3Cy, KRT2WriteLM4Cy,
                                KRT2WriteLM5Cy, KRT2WriteLM6Cy,
                                KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM9Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM11Cy, KRT2WriteLM12Cy,
                                KRT2WriteLM13Cy, KRT2WriteLM14Cy,
                                KRT2WriteLM15Cy]>,
    SchedVar<KRT2LMAddr14Pred,[KRT2WriteLM3Cy, KRT2WriteLM4Cy,
                                KRT2WriteLM5Cy, KRT2WriteLM6Cy,
                                KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM9Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM11Cy, KRT2WriteLM12Cy,
                                KRT2WriteLM13Cy, KRT2WriteLM14Cy,
                                KRT2WriteLM15Cy, KRT2WriteLM16Cy]>,
    SchedVar<KRT2LMAddr15Pred,[KRT2WriteLM3Cy, KRT2WriteLM4Cy,
                                KRT2WriteLM5Cy, KRT2WriteLM6Cy,
                                KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM9Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM11Cy, KRT2WriteLM12Cy,
                                KRT2WriteLM13Cy, KRT2WriteLM14Cy,
                                KRT2WriteLM15Cy, KRT2WriteLM16Cy,
                                KRT2WriteLM17Cy]>,
    SchedVar<KRT2LMAddr16Pred,[KRT2WriteLM3Cy, KRT2WriteLM4Cy,
                                KRT2WriteLM5Cy, KRT2WriteLM6Cy,
                                KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM9Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM11Cy, KRT2WriteLM12Cy,
                                KRT2WriteLM13Cy, KRT2WriteLM14Cy,
                                KRT2WriteLM15Cy, KRT2WriteLM16Cy,
                                KRT2WriteLM17Cy, KRT2WriteLM18Cy]>,
    // Unknow number of registers, just use resources for two registers.
    SchedVar<NoSchedPred,      [KRT2WriteLM3Cy, KRT2WriteLM4Cy,
                                KRT2WriteLM5CyNo, KRT2WriteLM6CyNo,
                                KRT2WriteLM7CyNo, KRT2WriteLM8CyNo,
                                KRT2WriteLM9CyNo, KRT2WriteLM10CyNo,
                                KRT2WriteLM11CyNo, KRT2WriteLM12CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM14CyNo,
                                KRT2WriteLM15CyNo, KRT2WriteLM16CyNo,
                                KRT2WriteLM17CyNo, KRT2WriteLM18CyNo]>

  ]> { let Variadic=1; }

  def : InstRW<[KRT2WriteLM, KRT2WriteLDMAddrNoWB],
        (instregex "LDM(IA|DA|DB|IB)$", "t2LDM(IA|DA|DB|IB)$",
        "(t|sys)LDM(IA|DA|DB|IB)$")>;
  def : InstRW<[KRT2WriteLDMAddrWB, KRT2WriteLM],
        (instregex /*"t2LDMIA_RET", "tLDMIA_RET", "LDMIA_RET",*/
        "LDM(IA|DA|DB|IB)_UPD", "(t2|sys|t)LDM(IA|DA|DB|IB)_UPD")>;
  def : InstRW<[KRT2WriteLDMAddrWB, KRT2WriteLM, KRT2WriteP1TwoCycle],
        (instregex "LDMIA_RET", "(t|t2)LDMIA_RET", "POP", "tPOP")>;
  // 4.2.23 Integer Store, Single Element
  def : InstRW<[KRT2WriteP2],
        (instregex "PICSTR", "STR(i12|rs)", "STRB(i12|rs)", "STRH$", "STREX",
        "t2STR(i12|i8|s)$", "t2STR[BH](i12|i8|s)$", "tSTR[BH](i|r)", "tSTR(i|r)", "tSTRspi")>;

  def : InstRW<[KRT2WriteP01OneCycle, KRT2WriteP2],
        (instregex "STR(B_|_|BT_|T_)(PRE_IMM|PRE_REG|POST_REG|POST_IMM)",
        "STR(i|r)_preidx", "STRB(i|r)_preidx", "STRH_preidx", "STR(H_|HT_)(PRE|POST)",
        "STR(BT|HT|T)", "t2STR_(PRE|POST)", "t2STR[BH]_(PRE|POST)",
        "t2STR_preidx", "t2STR[BH]_preidx", "t2ST(RB|RH|R)T")>;

  // 4.2.24 Integer Store, Dual
  def : InstRW<[KRT2WriteP2, KRT2WriteP2, KRT2WriteP01OneCycle],
        (instregex "STRD$", "t2STRDi8")>;
  def : InstRW<[KRT2WriteP01OneCycle, KRT2WriteP2, KRT2WriteP2,
                KRT2WriteP01OneCycle],
        (instregex "(t2|t)STRD_(POST|PRE)", "STRD_(POST|PRE)")>;

  // 4.2.25 Integer Store, Multiple
  def KRT2WriteStIncAddr : SchedWriteRes<[KRT2UnitP2, KRT2UnitP01]> {
    let Latency = 0;
    let NumMicroOps = 2;
  }
  foreach NumAddr = 1-16 in {
     def KRT2WriteSTM#NumAddr : WriteSequence<[KRT2WriteStIncAddr], NumAddr>;
  }
  def KRT2WriteSTM : SchedWriteVariant<[
    SchedVar<KRT2LMAddr2Pred, [KRT2WriteSTM2]>,
    SchedVar<KRT2LMAddr3Pred, [KRT2WriteSTM3]>,
    SchedVar<KRT2LMAddr4Pred, [KRT2WriteSTM4]>,
    SchedVar<KRT2LMAddr5Pred, [KRT2WriteSTM5]>,
    SchedVar<KRT2LMAddr6Pred, [KRT2WriteSTM6]>,
    SchedVar<KRT2LMAddr7Pred, [KRT2WriteSTM7]>,
    SchedVar<KRT2LMAddr8Pred, [KRT2WriteSTM8]>,
    SchedVar<KRT2LMAddr9Pred, [KRT2WriteSTM9]>,
    SchedVar<KRT2LMAddr10Pred,[KRT2WriteSTM10]>,
    SchedVar<KRT2LMAddr11Pred,[KRT2WriteSTM11]>,
    SchedVar<KRT2LMAddr12Pred,[KRT2WriteSTM12]>,
    SchedVar<KRT2LMAddr13Pred,[KRT2WriteSTM13]>,
    SchedVar<KRT2LMAddr14Pred,[KRT2WriteSTM14]>,
    SchedVar<KRT2LMAddr15Pred,[KRT2WriteSTM15]>,
    SchedVar<KRT2LMAddr16Pred,[KRT2WriteSTM16]>,
    // Unknow number of registers, just use resources for two registers.
    SchedVar<NoSchedPred,      [KRT2WriteSTM2]>
  ]>;
  def : InstRW<[KRT2WriteSTM],
        (instregex "STM(IB|IA|DB|DA)$", "(t2|sys|t)STM(IB|IA|DB|DA)$")>;
  def : InstRW<[KRT2WriteP01OneCycle, KRT2WriteSTM],
        (instregex "STM(IB|IA|DB|DA)_UPD", "(t2|sys|t)STM(IB|IA|DB|DA)_UPD",
        "PUSH", "tPUSH")>;

  // 4.2.26 Branch
  def : WriteRes<WriteBr, [KRT2UnitP1]> { let Latency = 0; }
  def : WriteRes<WriteBrL, [KRT2UnitP1]> { let Latency = 2; }
  def : WriteRes<WriteBrTbl, [KRT2UnitP1, KRT2UnitP2]> { let Latency = 0; }

  // 4.2.27 Not issued
  def : WriteRes<WriteNoop, []> { let Latency = 0; let NumMicroOps = 0; }
  def : InstRW<[WriteNoop], (instregex "t2IT", "IT", "NOP")>;

  // 4.2.28 Advanced SIMD, Integer, 2 cycle
  def : InstRW<[KRT2WriteP0TwoCycle],
        (instregex "VADDv", "VSUBv", "VNEG(s|f|v)", "VADDL", "VSUBL",
                   "VADDW", "VSUBW", "VHADD", "VHSUB", "VRHADD", "VPADDi",
                   "VPADDL", "VAND", "VBIC", "VEOR", "VORN", "VORR", "VTST",
                   "VSHL", "VSHR(s|u)", "VSHLL", "VQSHL", "VQSHLU", "VBIF",
                   "VBIT", "VBSL", "VSLI", "VSRI", "VCLS", "VCLZ", "VCNT")>;

  def : InstRW<[KRT2WriteP1TwoCycle],
        (instregex "VEXT", "VREV16", "VREV32", "VREV64")>;

  // 4.2.29 Advanced SIMD, Integer, 4 cycle
  // 4.2.30 Advanced SIMD, Integer with Accumulate
  def : InstRW<[KRT2WriteP0FourCycle],
        (instregex "VABA", "VABAL", "VPADAL", "VRSRA", "VSRA", "VACGE", "VACGT",
        "VACLE", "VACLT", "VCEQ", "VCGE", "VCGT", "VCLE", "VCLT", "VRSHL",
        "VQRSHL", "VRSHR(u|s)", "VABS(f|v)", "VQABS", "VQNEG", "VQADD",
        "VQSUB")>;
  def : InstRW<[KRT2WriteP1FourCycle],
        (instregex "VRECPE", "VRSQRTE")>;

  // 4.2.31 Advanced SIMD, Add and Shift with Narrow
  def : InstRW<[KRT2WriteP0P1FourCycle],
        (instregex "VADDHN", "VSUBHN", "VSHRN")>;
  def : InstRW<[KRT2WriteP0P1SixCycle],
        (instregex "VRADDHN", "VRSUBHN", "VRSHRN", "VQSHRN", "VQSHRUN",
                   "VQRSHRN", "VQRSHRUN")>;

  // 4.2.32 Advanced SIMD, Vector Table Lookup
  foreach Num = 1-4 in {
    def KRT2Write#Num#xP1TwoCycle : WriteSequence<[KRT2WriteP1TwoCycle], Num>;
  }
  def : InstRW<[KRT2Write1xP1TwoCycle],
        (instregex "VTB(L|X)1")>;
  def : InstRW<[KRT2Write2xP1TwoCycle],
        (instregex "VTB(L|X)2")>;
  def : InstRW<[KRT2Write3xP1TwoCycle],
        (instregex "VTB(L|X)3")>;
  def : InstRW<[KRT2Write4xP1TwoCycle],
        (instregex "VTB(L|X)4")>;

  // 4.2.33 Advanced SIMD, Transpose
  def : InstRW<[KRT2WriteP1FourCycle, KRT2WriteP1FourCycle,
                KRT2WriteP1TwoCycle/*RsrcOnly*/, SchedReadAdvance<2>],
        (instregex "VSWP", "VTRN", "VUZP", "VZIP")>;

  // 4.2.34 Advanced SIMD and VFP, Floating Point
  def : InstRW<[KRT2WriteP0TwoCycle], (instregex "VABS(S|D)$", "VNEG(S|D)$")>;
  def : InstRW<[KRT2WriteP0FourCycle],
        (instregex "VCMP(D|S|ZD|ZS)$", "VCMPE(D|S|ZD|ZS)")>;
  def : InstRW<[KRT2WriteP0FourCycle],
        (instregex "VADD(S|f)", "VSUB(S|f)", "VABD", "VPADDf", "VMAX", "VMIN", "VPMAX",
                   "VPMIN")>;
  def : InstRW<[KRT2WriteP0SixCycle], (instregex "VADDD$", "VSUBD$")>;
  def : InstRW<[KRT2WriteP1EightCycle], (instregex "VRECPS", "VRSQRTS")>;

  // 4.2.35 Advanced SIMD and VFP, Multiply
  def : InstRW<[KRT2WriteP1FourCycle],
        (instregex "VMUL(S|v|p|f|s)", "VNMULS", "VQDMULH", "VQRDMULH",
                   "VMULL", "VQDMULL")>;
  def : InstRW<[KRT2WriteP1SixCycle],
        (instregex "VMULD", "VNMULD")>;
  def : InstRW<[KRT2WriteP1FourCycle],
        (instregex "VMLA", "VMLS", "VNMLA", "VNMLS", "VFMA(S|D)", "VFMS(S|D)",
        "VFNMA", "VFNMS", "VMLAL", "VMLSL","VQDMLAL", "VQDMLSL")>;
  def : InstRW<[KRT2WriteP1EightCycle], (instregex "VFMAfd", "VFMSfd")>;
  def : InstRW<[KRT2WriteP1TwelveCyc], (instregex "VFMAfq", "VFMSfq")>;

  // 4.2.36 Advanced SIMD and VFP, Convert
  def : InstRW<[KRT2WriteP1FourCycle], (instregex "VCVT", "V(S|U)IT", "VTO(S|U)")>;
  // Fixpoint conversions.
  def : WriteRes<WriteCvtFP, [KRT2UnitP1]> { let Latency = 4; }

  // 4.2.37 Advanced SIMD and VFP, Move
  def : InstRW<[KRT2WriteP0TwoCycle],
        (instregex "VMOVv", "VMOV(S|D)$", "VMOV(S|D)cc",
                   "VMVNv", "VMVN(d|q)", "VMVN(S|D)cc",
                   "FCONST(D|S)")>;
  def : InstRW<[KRT2WriteP1TwoCycle], (instregex "VMOVN", "VMOVL")>;
  def : InstRW<[WriteSequence<[KRT2WriteP0FourCycle, KRT2WriteP1TwoCycle]>],
        (instregex "VQMOVN")>;
  def : InstRW<[KRT2WriteP1TwoCycle], (instregex "VDUPLN", "VDUPf")>;
  def : InstRW<[WriteSequence<[KRT2WriteP2FourCycle, KRT2WriteP1TwoCycle]>],
        (instregex "VDUP(8|16|32)")>;
  def : InstRW<[KRT2WriteP2ThreeCycle], (instregex "VMOVRS$")>;
  def : InstRW<[WriteSequence<[KRT2WriteP2FourCycle, KRT2WriteP0TwoCycle]>],
        (instregex "VMOVSR$", "VSETLN")>;
  def : InstRW<[KRT2WriteP2ThreeCycle, KRT2WriteP2FourCycle],
        (instregex "VMOVRR(D|S)$")>;
  def : InstRW<[KRT2WriteP2FourCycle], (instregex "VMOVDRR$")>;
  def : InstRW<[WriteSequence<[KRT2WriteP2FourCycle, KRT2WriteP1TwoCycle]>,
                WriteSequence<[KRT2Write1Cycle, KRT2WriteP2FourCycle,
                               KRT2WriteP1TwoCycle]>],
                (instregex "VMOVSRR$")>;
  def : InstRW<[WriteSequence<[KRT2WriteP1TwoCycle, KRT2WriteP2ThreeCycle]>],
        (instregex "VGETLN(u|i)")>;
  def : InstRW<[WriteSequence<[KRT2WriteP1TwoCycle, KRT2WriteP2ThreeCycle,
                               KRT2WriteP01OneCycle]>],
        (instregex "VGETLNs")>;

  // 4.2.38 Advanced SIMD and VFP, Move FPSCR
  // Serializing instructions.
  def KRT2WaitP0For15Cy : SchedWriteRes<[KRT2UnitP0]> {
    let Latency = 15;
    let ResourceCycles = [15];
  }
  def KRT2WaitP1For15Cy : SchedWriteRes<[KRT2UnitP1]> {
    let Latency = 15;
    let ResourceCycles = [15];
  }
  def KRT2WaitP2For15Cy : SchedWriteRes<[KRT2UnitP2]> {
    let Latency = 15;
    let ResourceCycles = [15];
  }
  def : InstRW<[KRT2WaitP0For15Cy, KRT2WaitP1For15Cy, KRT2WaitP2For15Cy],
        (instregex "VMRS")>;
  def : InstRW<[KRT2WaitP0For15Cy, KRT2WaitP1For15Cy, KRT2WaitP2For15Cy],
        (instregex "VMSR")>;
  // Not serializing.
  def : InstRW<[KRT2WriteP0TwoCycle], (instregex "FMSTAT")>;

  // 4.2.39 Advanced SIMD and VFP, Load Single Element
  def : InstRW<[KRT2WriteLM4Cy], (instregex "VLDRD$", "VLDRS$")>;

  // 4.2.40 Advanced SIMD and VFP, Store Single Element
  def : InstRW<[KRT2WriteLM4Cy], (instregex "VSTRD$", "VSTRS$")>;

  // 4.2.41 Advanced SIMD and VFP, Load Multiple
  // 4.2.42 Advanced SIMD and VFP, Store Multiple

  // Resource requirement for permuting, just reserves the resources.
  foreach Num = 1-28 in {
    def KRT2VLDMPerm#Num : SchedWriteRes<[KRT2UnitP1]> {
      let Latency = 0;
      let NumMicroOps = Num;
      let ResourceCycles = [Num];
    }
  }

  // Pre RA pseudos - load/store to a Q register as a D register pair.
  def : InstRW<[KRT2WriteLM4Cy], (instregex "VLDMQIA$", "VSTMQIA$")>;

  // Post RA not modelled accurately. We assume that register use of width 64
  // bit maps to a D register, 128 maps to a Q register. Not all different kinds
  // are accurately represented.
  def KRT2WriteVLDM : SchedWriteVariant<[
    // Load of one S register.
    SchedVar<KRT2LMAddr1Pred, [KRT2WriteLM4Cy]>,
    // Load of one D register.
    SchedVar<KRT2LMAddr2Pred, [KRT2WriteLM4Cy, KRT2WriteLM4CyNo]>,
    // Load of 3 S register.
    SchedVar<KRT2LMAddr3Pred, [KRT2WriteLM9Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM13CyNo, KRT2WriteP01OneCycle,
                                KRT2VLDMPerm3]>,
    // Load of a Q register (not necessarily true). We should not be mapping to
    // 4 S registers, either.
    SchedVar<KRT2LMAddr4Pred, [KRT2WriteLM4Cy, KRT2WriteLM4CyNo,
                                KRT2WriteLM4CyNo, KRT2WriteLM4CyNo]>,
    // Load of 5 S registers.
    SchedVar<KRT2LMAddr5Pred, [KRT2WriteLM9Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM13CyNo, KRT2WriteLM14CyNo,
                                KRT2WriteLM17CyNo,  KRT2WriteP01OneCycle,
                                KRT2VLDMPerm5]>,
    // Load of 3 D registers. (Must also be able to handle s register list -
    // though, not accurate)
    SchedVar<KRT2LMAddr6Pred, [KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM10Cy, KRT2WriteLM14CyNo,
                                KRT2WriteLM14CyNo, KRT2WriteLM14CyNo,
                                KRT2WriteP01OneCycle, KRT2VLDMPerm5]>,
    // Load of 7 S registers.
    SchedVar<KRT2LMAddr7Pred, [KRT2WriteLM9Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM13Cy, KRT2WriteLM14CyNo,
                                KRT2WriteLM17CyNo, KRT2WriteLM18CyNo,
                                KRT2WriteLM21CyNo, KRT2WriteP01OneCycle,
                                KRT2VLDMPerm7]>,
    // Load of two Q registers.
    SchedVar<KRT2LMAddr8Pred, [KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM13Cy, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteP01OneCycle,  KRT2VLDMPerm2]>,
    // Load of 9 S registers.
    SchedVar<KRT2LMAddr9Pred, [KRT2WriteLM9Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM13Cy, KRT2WriteLM14CyNo,
                                KRT2WriteLM17CyNo, KRT2WriteLM18CyNo,
                                KRT2WriteLM21CyNo, KRT2WriteLM22CyNo,
                                KRT2WriteLM25CyNo, KRT2WriteP01OneCycle,
                                KRT2VLDMPerm9]>,
    // Load of 5 D registers.
    SchedVar<KRT2LMAddr10Pred,[KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM10Cy, KRT2WriteLM14Cy,
                                KRT2WriteLM14CyNo, KRT2WriteLM14CyNo,
                                KRT2WriteLM14CyNo, KRT2WriteLM14CyNo,
                                KRT2WriteLM14CyNo,  KRT2WriteLM14CyNo,
                                KRT2WriteP01OneCycle, KRT2VLDMPerm5]>,
    // Inaccurate: reuse describtion from 9 S registers.
    SchedVar<KRT2LMAddr11Pred,[KRT2WriteLM9Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM13Cy, KRT2WriteLM14CyNo,
                                KRT2WriteLM17CyNo, KRT2WriteLM18CyNo,
                                KRT2WriteLM21CyNo, KRT2WriteLM22CyNo,
                                KRT2WriteLM21CyNo, KRT2WriteLM22CyNo,
                                KRT2WriteLM25CyNo, KRT2WriteP01OneCycle,
                                KRT2VLDMPerm9]>,
    // Load of three Q registers.
    SchedVar<KRT2LMAddr12Pred,[KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM11Cy, KRT2WriteLM11Cy,
                                KRT2WriteLM11CyNo, KRT2WriteLM11CyNo,
                                KRT2WriteLM11CyNo, KRT2WriteLM11CyNo,
                                KRT2WriteLM11CyNo, KRT2WriteLM11CyNo,
                                KRT2WriteLM11CyNo, KRT2WriteLM11CyNo,
                                KRT2WriteP01OneCycle, KRT2VLDMPerm3]>,
    // Inaccurate: reuse describtion from 9 S registers.
    SchedVar<KRT2LMAddr13Pred, [KRT2WriteLM9Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM13Cy, KRT2WriteLM14CyNo,
                                KRT2WriteLM17CyNo, KRT2WriteLM18CyNo,
                                KRT2WriteLM21CyNo, KRT2WriteLM22CyNo,
                                KRT2WriteLM21CyNo, KRT2WriteLM22CyNo,
                                KRT2WriteLM21CyNo, KRT2WriteLM22CyNo,
                                KRT2WriteLM25CyNo, KRT2WriteP01OneCycle,
                                KRT2VLDMPerm9]>,
    // Load of 7 D registers inaccurate.
    SchedVar<KRT2LMAddr14Pred,[KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM10Cy, KRT2WriteLM14Cy,
                                KRT2WriteLM14Cy, KRT2WriteLM14CyNo,
                                KRT2WriteLM14CyNo, KRT2WriteLM14CyNo,
                                KRT2WriteLM14CyNo,  KRT2WriteLM14CyNo,
                                KRT2WriteLM14CyNo,  KRT2WriteLM14CyNo,
                                KRT2WriteP01OneCycle, KRT2VLDMPerm7]>,
    SchedVar<KRT2LMAddr15Pred,[KRT2WriteLM9Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM13Cy, KRT2WriteLM14Cy,
                                KRT2WriteLM17Cy, KRT2WriteLM18CyNo,
                                KRT2WriteLM21CyNo, KRT2WriteLM22CyNo,
                                KRT2WriteLM21CyNo, KRT2WriteLM22CyNo,
                                KRT2WriteLM21CyNo, KRT2WriteLM22CyNo,
                                KRT2WriteLM21CyNo, KRT2WriteLM22CyNo,
                                KRT2WriteLM25CyNo, KRT2WriteP01OneCycle,
                                KRT2VLDMPerm9]>,
    // Load of 4 Q registers.
    SchedVar<KRT2LMAddr16Pred,[KRT2WriteLM7Cy, KRT2WriteLM10Cy,
                                KRT2WriteLM11Cy, KRT2WriteLM14Cy,
                                KRT2WriteLM15Cy, KRT2WriteLM18CyNo,
                                KRT2WriteLM19CyNo, KRT2WriteLM22CyNo,
                                KRT2WriteLM19CyNo, KRT2WriteLM22CyNo,
                                KRT2WriteLM19CyNo, KRT2WriteLM22CyNo,
                                KRT2WriteLM19CyNo, KRT2WriteLM22CyNo,
                                KRT2WriteLM19CyNo, KRT2WriteLM22CyNo,
                                KRT2WriteP01OneCycle, KRT2VLDMPerm4]>,
    // Unknow number of registers, just use resources for two registers.
    SchedVar<NoSchedPred,      [KRT2WriteLM7Cy, KRT2WriteLM8Cy,
                                KRT2WriteLM13Cy, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteLM13CyNo, KRT2WriteLM13CyNo,
                                KRT2WriteP01OneCycle,  KRT2VLDMPerm2]>
  ]> { let Variadic = 1; }

  def : InstRW<[KRT2WriteVLDM], (instregex "VLDM[SD](IA|DB)$")>;

  def : InstRW<[KRT2WriteP01OneCycle2x, KRT2WriteVLDM],
        (instregex "VLDM[SD](IA|DB)_UPD$")>;

  def KRT2WriteVSTM : SchedWriteVariant<[
    // One S register.
    SchedVar<KRT2LMAddr1Pred, [KRT2WriteSTM1]>,
    // One D register.
    SchedVar<KRT2LMAddr2Pred, [KRT2WriteSTM1]>,
    // Three S registers.
    SchedVar<KRT2LMAddr3Pred, [KRT2WriteSTM4]>,
    // Assume one Q register.
    SchedVar<KRT2LMAddr4Pred, [KRT2WriteSTM1]>,
    SchedVar<KRT2LMAddr5Pred, [KRT2WriteSTM6]>,
    // Assume three D registers.
    SchedVar<KRT2LMAddr6Pred, [KRT2WriteSTM4]>,
    SchedVar<KRT2LMAddr7Pred, [KRT2WriteSTM8]>,
    // Assume two Q registers.
    SchedVar<KRT2LMAddr8Pred, [KRT2WriteSTM3]>,
    SchedVar<KRT2LMAddr9Pred, [KRT2WriteSTM10]>,
    // Assume 5 D registers.
    SchedVar<KRT2LMAddr10Pred, [KRT2WriteSTM6]>,
    SchedVar<KRT2LMAddr11Pred, [KRT2WriteSTM12]>,
    // Assume three Q registers.
    SchedVar<KRT2LMAddr12Pred, [KRT2WriteSTM4]>,
    SchedVar<KRT2LMAddr13Pred, [KRT2WriteSTM14]>,
    // Assume 7 D registers.
    SchedVar<KRT2LMAddr14Pred, [KRT2WriteSTM8]>,
    SchedVar<KRT2LMAddr15Pred, [KRT2WriteSTM16]>,
    // Assume four Q registers.
    SchedVar<KRT2LMAddr16Pred, [KRT2WriteSTM5]>,
    // Asumme two Q registers.
    SchedVar<NoSchedPred, [KRT2WriteSTM3]>
  ]> { let Variadic = 1; }

  def : InstRW<[KRT2WriteVSTM], (instregex "VSTM[SD](IA|DB)$")>;

  def : InstRW<[KRT2WriteP01OneCycle2x, KRT2WriteVSTM],
        (instregex "VSTM[SD](IA|DB)_UPD")>;

  // 4.2.43 Advanced SIMD, Element or Structure Load and Store
  def KRT2Write2xP2FourCy : SchedWriteRes<[KRT2UnitP2]> {
      let Latency = 4;
      let ResourceCycles = [2];
  }
  def KRT2Write3xP2FourCy : SchedWriteRes<[KRT2UnitP2]> {
      let Latency = 4;
      let ResourceCycles = [3];
  }
  foreach Num = 1-2 in {
    def KRT2Ext#Num#xP0 : SchedWriteRes<[KRT2UnitP0]> {
      let Latency = 0;
      let NumMicroOps = Num;
      let ResourceCycles = [Num];
    }
  }
  // VLDx
  // Multiple structures.
  // Single element structure loads.
  // We assume aligned.
  // Single/two register.
  def : InstRW<[KRT2WriteLM4Cy], (instregex "VLD1(d|q)(8|16|32|64)$")>;
  def : InstRW<[KRT2WriteLM4Cy, KRT2WriteP01OneCycle],
        (instregex "VLD1(d|q)(8|16|32|64)wb")>;
  // Three register.
  def : InstRW<[KRT2Write3xP2FourCy],
        (instregex "VLD1(d|q)(8|16|32|64)T$", "VLD1d64TPseudo")>;
  def : InstRW<[KRT2Write3xP2FourCy, KRT2WriteP01OneCycle],
        (instregex "VLD1(d|q)(8|16|32|64)Twb")>;
  /// Four Register.
  def : InstRW<[KRT2Write2xP2FourCy],
        (instregex "VLD1(d|q)(8|16|32|64)Q$", "VLD1d64QPseudo")>;
  def : InstRW<[KRT2Write2xP2FourCy, KRT2WriteP01OneCycle],
        (instregex "VLD1(d|q)(8|16|32|64)Qwb")>;
  // Two element structure loads.
  // Two/four register.
  def : InstRW<[KRT2WriteLM9Cy, KRT2Ext2xP0, KRT2VLDMPerm2],
        (instregex "VLD2(d|q|b)(8|16|32)$", "VLD2q(8|16|32)Pseudo$")>;
  def : InstRW<[KRT2WriteLM9Cy, KRT2WriteP01OneCycle, KRT2Ext2xP0,
                KRT2VLDMPerm2],
        (instregex "VLD2(d|q|b)(8|16|32)wb", "VLD2q(8|16|32)PseudoWB")>;
  // Three element structure.
  def : InstRW<[KRT2WriteLM9Cy, KRT2WriteLM9CyNo, KRT2WriteLM9CyNo,
                KRT2VLDMPerm3, KRT2Write3xP2FourCy],
        (instregex "VLD3(d|q)(8|16|32)$")>;
  def : InstRW<[KRT2WriteLM9Cy, KRT2VLDMPerm3, KRT2Write3xP2FourCy],
        (instregex "VLD3(d|q)(8|16|32)(oddP|P)seudo$")>;

  def : InstRW<[KRT2WriteLM9Cy, KRT2WriteLM9CyNo, KRT2WriteLM9CyNo,
                KRT2WriteP01OneCycle, KRT2VLDMPerm3, KRT2Write3xP2FourCy],
        (instregex "VLD3(d|q)(8|16|32)_UPD$")>;
  def : InstRW<[KRT2WriteLM9Cy, KRT2WriteP01OneCycle, KRT2VLDMPerm3,
                KRT2Write3xP2FourCy],
        (instregex "VLD3(d|q)(8|16|32)(oddP|P)seudo_UPD")>;
  // Four element structure loads.
  def : InstRW<[KRT2WriteLM11Cy, KRT2WriteLM11Cy, KRT2WriteLM11Cy,
                KRT2WriteLM11Cy, KRT2Ext2xP0, KRT2VLDMPerm4,
                KRT2Write3xP2FourCy],
        (instregex "VLD4(d|q)(8|16|32)$")>;
  def : InstRW<[KRT2WriteLM11Cy,  KRT2Ext2xP0, KRT2VLDMPerm4,
                KRT2Write3xP2FourCy],
        (instregex "VLD4(d|q)(8|16|32)(oddP|P)seudo$")>;
  def : InstRW<[KRT2WriteLM11Cy, KRT2WriteLM11Cy, KRT2WriteLM11Cy,
                KRT2WriteLM11Cy, KRT2WriteP01OneCycle, KRT2Ext2xP0,
                KRT2VLDMPerm4, KRT2Write3xP2FourCy],
        (instregex "VLD4(d|q)(8|16|32)_UPD")>;
  def : InstRW<[KRT2WriteLM11Cy, KRT2WriteP01OneCycle, KRT2Ext2xP0,
                KRT2VLDMPerm4, KRT2Write3xP2FourCy],
        (instregex  "VLD4(d|q)(8|16|32)(oddP|P)seudo_UPD")>;

  // Single all/lane loads.
  // One element structure.
  def : InstRW<[KRT2WriteLM6Cy, KRT2VLDMPerm2],
        (instregex "VLD1(LN|DUP)(d|q)(8|16|32)$", "VLD1(LN|DUP)(d|q)(8|16|32)Pseudo$")>;
  def : InstRW<[KRT2WriteLM6Cy, KRT2WriteP01OneCycle, KRT2VLDMPerm2],
        (instregex "VLD1(LN|DUP)(d|q)(8|16|32)(wb|_UPD)",
                  "VLD1LNq(8|16|32)Pseudo_UPD")>;
  // Two element structure.
  def : InstRW<[KRT2WriteLM6Cy, KRT2WriteLM6Cy, KRT2Ext1xP0, KRT2VLDMPerm2],
        (instregex "VLD2(DUP|LN)(d|q)(8|16|32|8x2|16x2|32x2)$",
                   "VLD2LN(d|q)(8|16|32)Pseudo$")>;
  def : InstRW<[KRT2WriteLM6Cy, KRT2WriteLM6Cy, KRT2WriteP01OneCycle,
                KRT2Ext1xP0, KRT2VLDMPerm2],
        (instregex "VLD2LN(d|q)(8|16|32)_UPD$")>;
  def : InstRW<[KRT2WriteLM6Cy, KRT2WriteP01OneCycle, KRT2WriteLM6Cy,
                KRT2Ext1xP0, KRT2VLDMPerm2],
        (instregex "VLD2DUPd(8|16|32|8x2|16x2|32x2)wb")>;
  def : InstRW<[KRT2WriteLM6Cy, KRT2WriteP01OneCycle, KRT2WriteLM6Cy,
                KRT2Ext1xP0, KRT2VLDMPerm2],
        (instregex "VLD2LN(d|q)(8|16|32)Pseudo_UPD")>;
  // Three element structure.
  def : InstRW<[KRT2WriteLM7Cy, KRT2WriteLM8Cy, KRT2WriteLM8Cy, KRT2Ext1xP0,
                KRT2VLDMPerm3],
        (instregex "VLD3(DUP|LN)(d|q)(8|16|32)$",
                   "VLD3(LN|DUP)(d|q)(8|16|32)Pseudo$")>;
  def : InstRW<[KRT2WriteLM7Cy, KRT2WriteLM8Cy, KRT2WriteLM8Cy,
                KRT2WriteP01OneCycle, KRT2Ext1xP0, KRT2VLDMPerm3],
        (instregex "VLD3(LN|DUP)(d|q)(8|16|32)_UPD")>;
  def : InstRW<[KRT2WriteLM7Cy, KRT2WriteP01OneCycle, KRT2WriteLM8Cy,
                KRT2WriteLM8Cy, KRT2Ext1xP0, KRT2VLDMPerm3],
        (instregex "VLD3(LN|DUP)(d|q)(8|16|32)Pseudo_UPD")>;
  // Four element struture.
  def : InstRW<[KRT2WriteLM8Cy, KRT2WriteLM9Cy, KRT2WriteLM10CyNo,
                KRT2WriteLM10CyNo, KRT2Ext1xP0, KRT2VLDMPerm5],
        (instregex "VLD4(LN|DUP)(d|q)(8|16|32)$",
                   "VLD4(LN|DUP)(d|q)(8|16|32)Pseudo$")>;
  def : InstRW<[KRT2WriteLM8Cy, KRT2WriteLM9Cy, KRT2WriteLM10CyNo,
                KRT2WriteLM10CyNo, KRT2WriteP01OneCycle, KRT2Ext1xP0,
                KRT2VLDMPerm5],
        (instregex "VLD4(DUP|LN)(d|q)(8|16|32)_UPD")>;
  def : InstRW<[KRT2WriteLM8Cy, KRT2WriteP01OneCycle, KRT2WriteLM9Cy,
                KRT2WriteLM10CyNo, KRT2WriteLM10CyNo, KRT2Ext1xP0,
                KRT2VLDMPerm5],
        (instregex "VLD4(DUP|LN)(d|q)(8|16|32)Pseudo_UPD")>;
  // VSTx
  // Multiple structures.
  // Single element structure store.
  def : InstRW<[KRT2Write1xP2], (instregex "VST1d(8|16|32|64)$")>;
  def : InstRW<[KRT2Write2xP2], (instregex "VST1q(8|16|32|64)$")>;
  def : InstRW<[KRT2WriteP01OneCycle, KRT2Write1xP2],
        (instregex "VST1d(8|16|32|64)wb")>;
  def : InstRW<[KRT2WriteP01OneCycle, KRT2Write2xP2],
        (instregex "VST1q(8|16|32|64)wb")>;
  def : InstRW<[KRT2Write3xP2],
        (instregex "VST1d(8|16|32|64)T$", "VST1d64TPseudo$")>;
  def : InstRW<[KRT2WriteP01OneCycle, KRT2Write3xP2],
        (instregex "VST1d(8|16|32|64)Twb", "VST1d64TPseudoWB")>;
  def : InstRW<[KRT2Write4xP2],
        (instregex "VST1d(8|16|32|64)(Q|QPseudo)$")>;
  def : InstRW<[KRT2WriteP01OneCycle, KRT2Write4xP2],
        (instregex "VST1d(8|16|32|64)(Qwb|QPseudoWB)")>;
  // Two element structure store.
  def : InstRW<[KRT2Write1xP2, KRT2VLDMPerm1],
        (instregex "VST2(d|b)(8|16|32)$")>;
  def : InstRW<[KRT2WriteP01OneCycle, KRT2Write1xP2, KRT2VLDMPerm1],
        (instregex "VST2(b|d)(8|16|32)wb")>;
  def : InstRW<[KRT2Write2xP2, KRT2VLDMPerm2],
        (instregex "VST2q(8|16|32)$", "VST2q(8|16|32)Pseudo$")>;
  def : InstRW<[KRT2Write2xP2, KRT2VLDMPerm2],
        (instregex "VST2q(8|16|32)wb", "VST2q(8|16|32)PseudoWB")>;
  // Three element structure store.
  def : InstRW<[KRT2Write4xP2, KRT2VLDMPerm2],
        (instregex "VST3(d|q)(8|16|32)$", "VST3(d|q)(8|16|32)(oddP|P)seudo$")>;
  def : InstRW<[KRT2WriteP01OneCycle, KRT2Write4xP2, KRT2VLDMPerm2],
        (instregex "VST3(d|q)(8|16|32)_UPD",
                   "VST3(d|q)(8|16|32)(oddP|P)seudo_UPD$")>;
  // Four element structure store.
  def : InstRW<[KRT2Write4xP2, KRT2VLDMPerm2],
        (instregex "VST4(d|q)(8|16|32)$", "VST4(d|q)(8|16|32)(oddP|P)seudo$")>;
  def : InstRW<[KRT2WriteP01OneCycle, KRT2Write4xP2, KRT2VLDMPerm4],
        (instregex "VST4(d|q)(8|16|32)_UPD",
                   "VST4(d|q)(8|16|32)(oddP|P)seudo_UPD$")>;
  // Single/all lane store.
  // One element structure.
  def : InstRW<[KRT2Write1xP2, KRT2VLDMPerm1],
        (instregex "VST1LNd(8|16|32)$", "VST1LNq(8|16|32)Pseudo$")>;
  def : InstRW<[KRT2WriteP01OneCycle, KRT2Write1xP2, KRT2VLDMPerm1],
        (instregex "VST1LNd(8|16|32)_UPD", "VST1LNq(8|16|32)Pseudo_UPD")>;
  // Two element structure.
  def : InstRW<[KRT2Write1xP2, KRT2VLDMPerm2],
        (instregex "VST2LN(d|q)(8|16|32)$", "VST2LN(d|q)(8|16|32)Pseudo$")>;
  def : InstRW<[KRT2WriteP01OneCycle, KRT2Write1xP2, KRT2VLDMPerm2],
        (instregex "VST2LN(d|q)(8|16|32)_UPD",
                   "VST2LN(d|q)(8|16|32)Pseudo_UPD")>;
  // Three element structure.
  def : InstRW<[KRT2Write4xP2, KRT2VLDMPerm2],
        (instregex "VST3LN(d|q)(8|16|32)$", "VST3LN(d|q)(8|16|32)Pseudo$")>;
  def : InstRW<[KRT2WriteP01OneCycle, KRT2Write4xP2, KRT2VLDMPerm2],
        (instregex "VST3LN(d|q)(8|16|32)_UPD",
                   "VST3LN(d|q)(8|16|32)Pseudo_UPD")>;
  // Four element structure.
  def : InstRW<[KRT2Write2xP2, KRT2VLDMPerm2],
        (instregex "VST4LN(d|q)(8|16|32)$", "VST4LN(d|q)(8|16|32)Pseudo$")>;
  def : InstRW<[KRT2WriteP01OneCycle, KRT2Write2xP2, KRT2VLDMPerm2],
        (instregex "VST4LN(d|q)(8|16|32)_UPD",
                   "VST4LN(d|q)(8|16|32)Pseudo_UPD")>;

  // 4.2.44 VFP, Divide and Square Root
  def KRT2Div17 : SchedWriteRes<[KRT2UnitP0, KRT2UnitDiv]> {
    let NumMicroOps = 1;
    let Latency = 17;
    let ResourceCycles = [1, 15];
  }
  def KRT2Div32 : SchedWriteRes<[KRT2UnitP0, KRT2UnitDiv]> {
    let NumMicroOps = 1;
    let Latency = 32;
    let ResourceCycles = [1, 30];
  }
  def : InstRW<[KRT2Div17], (instregex "VDIVS", "VSQRTS")>;
  def : InstRW<[KRT2Div32], (instregex "VDIVD", "VSQRTD")>;

  // Not specified.
  def : InstRW<[KRT2WriteP01OneCycle2x], (instregex "ABS")>;
  // Preload.
  def : WriteRes<WritePreLd, [KRT2UnitP2]> { let Latency = 0;
    let ResourceCycles = [0];
  }

}
