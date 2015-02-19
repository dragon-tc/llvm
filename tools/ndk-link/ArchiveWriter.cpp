//===-- ArchiveWriter.cpp - Write LLVM archive files ----------------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// Builds up an LLVM archive file (.a) containing LLVM bitcode.
//
//===----------------------------------------------------------------------===//

#include "Archive.h"
#include "ArchiveInternals.h"
#include "llvm/Bitcode/ReaderWriter.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/Process.h"
#include "llvm/Support/Signals.h"
#include <fstream>
#include <iomanip>
#include <ostream>
#include <system_error>
using namespace llvm;

// Create an empty archive.
Archive* Archive::CreateEmpty(StringRef FilePath, LLVMContext& C) {
  Archive* result = new Archive(FilePath, C);
  return result;
}

// Fill the ArchiveMemberHeader with the information from a member. If
// TruncateNames is true, names are flattened to 15 chars or less. The sz field
// is provided here instead of coming from the mbr because the member might be
// stored compressed and the compressed size is not the ArchiveMember's size.
// Furthermore compressed files have negative size fields to identify them as
// compressed.
bool
Archive::fillHeader(const ArchiveMember &mbr, ArchiveMemberHeader& hdr,
                    int sz) const {

  // Set the permissions mode, uid and gid
  hdr.init();
  char buffer[32];
  sprintf(buffer, "%-8o", mbr.getMode());
  memcpy(hdr.mode,buffer,8);
  sprintf(buffer,  "%-6u", mbr.getUser());
  memcpy(hdr.uid,buffer,6);
  sprintf(buffer,  "%-6u", mbr.getGroup());
  memcpy(hdr.gid,buffer,6);

  // Set the last modification date
  uint64_t secondsSinceEpoch = mbr.getModTime().toEpochTime();
  sprintf(buffer,"%-12u", unsigned(secondsSinceEpoch));
  memcpy(hdr.date,buffer,12);

  std::string mbrPath = sys::path::filename(mbr.getPath());

  // Set the name field in one of its various flavors.
  bool writeLongName = false;
  if (mbr.isStringTable()) {
    memcpy(hdr.name,ARFILE_STRTAB_NAME,16);
  } else if (mbr.isSVR4SymbolTable()) {
    memcpy(hdr.name,ARFILE_SVR4_SYMTAB_NAME,16);
  } else if (mbr.isBSD4SymbolTable()) {
    memcpy(hdr.name,ARFILE_BSD4_SYMTAB_NAME,16);
  } else if (mbrPath.length() < 16 && mbrPath.find('/') == std::string::npos) {
    memcpy(hdr.name,mbrPath.c_str(),mbrPath.length());
    hdr.name[mbrPath.length()] = '/';
  } else {
    std::string nm = "#1/";
    nm += utostr(mbrPath.length());
    memcpy(hdr.name,nm.data(),nm.length());
    if (sz < 0)
      sz -= mbrPath.length();
    else
      sz += mbrPath.length();
    writeLongName = true;
  }

  // Set the size field
  if (sz < 0) {
    buffer[0] = '-';
    sprintf(&buffer[1],"%-9u",(unsigned)-sz);
  } else {
    sprintf(buffer, "%-10u", (unsigned)sz);
  }
  memcpy(hdr.size,buffer,10);

  return writeLongName;
}

// Insert a file into the archive before some other member. This also takes care
// of extracting the necessary flags and information from the file.
bool Archive::addFileBefore(StringRef filePath, iterator where,
                            std::string *ErrMsg) {
  if (!sys::fs::exists(filePath)) {
    if (ErrMsg)
      *ErrMsg = "Can not add a non-existent file to archive";
    return true;
  }

  ArchiveMember* mbr = new ArchiveMember(this);

  mbr->data = 0;
  mbr->path = filePath;
  sys::fs::file_status Status;
  std::error_code EC = sys::fs::status(filePath, Status);
  if (EC) {
    delete mbr;
    return true;
  }
  mbr->User = Status.getUser();
  mbr->Group = Status.getGroup();
  mbr->Mode = Status.permissions();
  mbr->ModTime = Status.getLastModificationTime();
  // FIXME: On posix this is a second stat.
  EC =  sys::fs::file_size(filePath, mbr->Size);
  if (EC) {
    delete mbr;
    return true;
  }

  unsigned flags = 0;
  if (sys::path::filename(filePath).size() > 15)
    flags |= ArchiveMember::HasLongFilenameFlag;

  sys::fs::file_magic type;
  if (sys::fs::identify_magic(mbr->path, type))
    type = sys::fs::file_magic::unknown;
  mbr->flags = flags;
  members.insert(where,mbr);
  return false;
}

// Write one member out to the file.
bool
Archive::writeMember(
  const ArchiveMember& member,
  raw_fd_ostream& ARFile,
  std::string* ErrMsg
) {

  uint64_t filepos = ARFile.tell();
  filepos -= 8;

  // Get the data and its size either from the
  // member's in-memory data or directly from the file.
  size_t fSize = member.getSize();
  const char *data = (const char*)member.getData();
  MemoryBuffer *mFile = 0;
  if (!data) {
    ErrorOr<std::unique_ptr<MemoryBuffer> > File =
      MemoryBuffer::getFile(member.getPath());
    if (!File) {
      if (ErrMsg)
        *ErrMsg = File.getError().message();
      return true;
    }
    mFile = File.get().release();
    data = mFile->getBufferStart();
    fSize = mFile->getBufferSize();
  }

  int hdrSize = fSize;

  // Compute the fields of the header
  ArchiveMemberHeader Hdr;
  bool writeLongName = fillHeader(member,Hdr,hdrSize);

  // Write header to archive file
  ARFile.write((char*)&Hdr, sizeof(Hdr));

  // Write the long filename if its long
  if (writeLongName) {
    StringRef Name = sys::path::filename(member.getPath());
    ARFile.write(Name.data(), Name.size());
  }

  // Write the (possibly compressed) member's content to the file.
  ARFile.write(data,fSize);

  // Make sure the member is an even length
  if ((ARFile.tell() & 1) == 1)
    ARFile << ARFILE_PAD;

  // Close the mapped file if it was opened
  delete mFile;
  return false;
}

// Write the entire archive to the file specified when the archive was created.
// This writes to a temporary file first. Options are for creating a symbol
// table, flattening the file names (no directories, 15 chars max) and
// compressing each archive member.
bool Archive::writeToDisk(std::string *ErrMsg) {
  // Make sure they haven't opened up the file, not loaded it,
  // but are now trying to write it which would wipe out the file.
  if (members.empty() && mapfile && mapfile->getBufferSize() > 8) {
    if (ErrMsg)
      *ErrMsg = "Can't write an archive not opened for writing";
    return true;
  }

  // Create a temporary file to store the archive in
  int TmpArchiveFD;
  SmallString<128> TmpArchive;
  std::error_code EC = sys::fs::createUniqueFile(
      archPath + ".temp-archive-%%%%%%%.a", TmpArchiveFD, TmpArchive);
  if (EC)
    return true;

  // Make sure the temporary gets removed if we crash
  sys::RemoveFileOnSignal(TmpArchive);

  // Create archive file for output.
  raw_fd_ostream ArchiveFile(TmpArchiveFD, true);

  // Write magic string to archive.
  ArchiveFile << ARFILE_MAGIC;

  // Loop over all member files, and write them out. Note that this also
  // builds the symbol table, symTab.
  for (MembersList::iterator I = begin(), E = end(); I != E; ++I) {
    if (writeMember(*I, ArchiveFile, ErrMsg)) {
      sys::fs::remove(Twine(TmpArchive));
      ArchiveFile.close();
      return true;
    }
  }

  // Close archive file.
  ArchiveFile.close();

  // Before we replace the actual archive, we need to forget all the
  // members, since they point to data in that old archive. We need to do
  // this because we cannot replace an open file on Windows.
  cleanUpMemory();

  if (sys::fs::rename(Twine(TmpArchive), archPath)) {
    *ErrMsg = EC.message();
    return true;
  }

  return false;
}
