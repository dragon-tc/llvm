// Copyright (c) 2012 Qualcomm Technologies, Inc.  All Rights Reserved.
// Qualcomm Technologies Proprietary and Confidential
//
//===-- ARMProfitRecognizer.cpp - ARM postra profit recognizer ------------===//
//
//                     The LLVM Compiler Infrastructure
//===----------------------------------------------------------------------===//

#include "ARMProfitRecognizer.h"
#include "ARMBaseInstrInfo.h"
#include "ARMSubtarget.h"
#include "MCTargetDesc/ARMMCTargetDesc.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/ScheduleDAG.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;


static unsigned int getKraitPipeCount(const ARMSubtarget &STI,
  unsigned Units)
{
    return ARM_MC::getKrait2PipeCount(Units);

  return 1;
}

static bool useKraitIntPipe(const ARMSubtarget &STI,
  unsigned Units)
{
  ARM_MC::PipeType PipeT;

    PipeT = ARM_MC::getKrait2PipeType(Units);

  switch (PipeT) {
    case ARM_MC::PipeType_Krait_X_Y_M_B_Z:
    case ARM_MC::PipeType_Krait_L:
    case ARM_MC::PipeType_Krait_S:
      return true;
  default:
    return false;
  }
}

// checks whether the instruction itineraries represented by left
// and right units result in an efficient pipeline mix
// according to Krait instruction mixing rules.
bool isEfficientKraitPipeMix(const ARMSubtarget &STI,
  unsigned LeftUnits, unsigned RightUnits)
{
  // Enforcing mixing rules for integer pipelines but not
  // for vector pipelines.
  // Krait efficient (balanced) integer pipeline mixing rules:
  // Left       Right
  // L         favor: X_Y_M_Z_B       avoid: L, S
  // S         favor: X_Y_M_Z_B       avoid: L, S
  // X_Y_M_Z_B any pipe is ok (most instructions execute
  // in more than one pipe so should be ok to allow back to back)

  // todo: enforce Krait instruction pairing rules.

  ARM_MC::PipeType LeftPT;
  ARM_MC::PipeType RightPT;

    LeftPT = ARM_MC::getKrait2PipeType(LeftUnits);
    RightPT = ARM_MC::getKrait2PipeType(RightUnits);

  // Determine the integer pipeline mixing to avoid
  if (LeftPT == ARM_MC::PipeType_Krait_L &&
    (RightPT == ARM_MC::PipeType_Krait_L ||
    RightPT == ARM_MC::PipeType_Krait_S))
    return false;

  if (LeftPT == ARM_MC::PipeType_Krait_S &&
    (RightPT == ARM_MC::PipeType_Krait_S ||
    RightPT == ARM_MC::PipeType_Krait_L))
    return false;

  // all other pipeline mixing is ok
  return true;
}

static unsigned getUnits(const InstrItineraryData *ItinData,
  unsigned ItinClassIndx) {

  // target doesn't provide itinerary information or
  // a dummy (Generic) itinerary which should be handled as if its
  // itinerary is empty
  if (ItinData->isEmpty() ||
    ItinData->Itineraries[ItinClassIndx].FirstStage == 0)
    return 0;

  // Get all FUs used by instruction class
  unsigned Units = 0;
  for (const InstrStage *IS = ItinData->beginStage(ItinClassIndx),
    *E = ItinData->endStage(ItinClassIndx); IS != E; ++IS) {
    Units |= IS->getUnits();
  }

  return Units;
}

void ARMProfitRecognizer::reset() {
  LastMIIntPipe = 0;
}

void ARMProfitRecognizer::addInstruction(SUnit *SU) {
  MachineInstr *MI = SU->getInstr();

  if (MI->isDebugValue())
    return;

  const MCInstrDesc &MCID = MI->getDesc();
  unsigned Idx = MCID.getSchedClass();
  unsigned Units = getUnits(ItinData, Idx);

    // just keep track of emitted integer pipe instructions
    if (useKraitIntPipe(STI, Units))
      LastMIIntPipe = MI;
}

bool ARMProfitRecognizer::isEfficientInstrMix(const SUnit * SU) {


  // no previous instr in the integer pipe to check for mixing rules
  if (!LastMIIntPipe)
    return true;

  MachineInstr *MI = SU->getInstr();
  const MCInstrDesc &LastMCID = LastMIIntPipe->getDesc();
  const MCInstrDesc &CurrMCID = MI->getDesc();
  unsigned LastIdx = LastMCID.getSchedClass();
  unsigned CurrIdx = CurrMCID.getSchedClass();

  bool PipeMix;
    PipeMix = isEfficientKraitPipeMix(STI, getUnits(ItinData, LastIdx),
      getUnits(ItinData, CurrIdx));

   DEBUG(errs() << "LastMIIntPipe=" << *LastMIIntPipe
   << " CurrMI=" << *MI
   << " PipeMix=" << PipeMix <<"\n");

  return PipeMix;
}

unsigned int ARMProfitRecognizer::getPipeCount(const SUnit * SU) {

  MachineInstr *MI = SU->getInstr();
  const MCInstrDesc &CurrMCID = MI->getDesc();
  unsigned CurrIdx = CurrMCID.getSchedClass();

  unsigned int PipeCount;
    PipeCount = getKraitPipeCount(STI, getUnits(ItinData, CurrIdx));

   DEBUG(errs() << " CurrMI=" << *MI
   << " PipeCount=" << PipeCount <<"\n");

  return PipeCount;
}


