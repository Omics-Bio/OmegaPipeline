#!/usr/bin/python

# -*- coding: utf-8 -*-
"""
split big fasta/q into small files to process

Created on Wed Nov 13 14:51:36 EST 2015
@author: Naux
"""
import sys, os
import argparse
import math

IdOfFirstSingleRead = 0
sFirstSingleReadFilename = ""

## =================================================================
# # Function: getRead
## =================================================================
def getReadFromFasta(fin):
    output = ""
    name = ""
    for line in fin:
        if line.strip("\n").strip() != "":
            if line[0] != ">":
                output += line.strip('\n')
            else:
                if output != "":
                    yield output, name
                output = ""
                name = line.strip('\n')[1:]
    yield output, name

def getReadFromFastq(fin):
    output = ""
    count = 1
    name = ""
    for line in fin:
        if count != 2:
            count = count + 1
        else:
            yield line.strip('\n')
            count = -1
    yield output

## =================================================================
# # Function: count the bases
## =================================================================
def getTotalBases(inputFile):
    fileExt = inputFile.split(".")[-1]  # file type, fasta or fastq, autodetect
    if fileExt in ["fa", "Fa", "faa", "Faa", "fna", "Fna", "fasta", "Fasta"]:  # either fa or fq
        fileType = "fasta"
    elif fileExt in ["fq", "Fq", "fastq", "Fastq"]:  # either fa or fq
        fileType = "fastq"
    else:
        sys.stderr.write("File type is not correct...\n")
        return 0

    count = 0
    with open(inputFile, 'r') as fin:
        if fileType == "fastq":
            for readLines in getReadFromFastq(fin):
                count += len(readLines)
        elif fileType == "fasta":
            for readLines in getReadFromFasta(fin):
                count += len(readLines)

    return count


## =================================================================
# # Function: count the lines
## =================================================================
def getTotalLines(inputFile):
    fileExt = inputFile.split(".")[-1]  # file type, fasta or fastq, autodetect
    if fileExt in ["fa", "Fa", "faa", "Faa", "fna", "Fna", "fasta", "Fasta"]:  # either fa or fq
        fileType = "fasta"
    elif fileExt in ["fq", "Fq", "fastq", "Fastq"]:  # either fa or fq
        fileType = "fastq"
    else:
        sys.stderr.write("File type is not correct...\n")
        return 0

    count = 0
    thefile = open(inputFile, 'rb')

    if fileType == "fastq":
        while 1:
            xBuffer = thefile.read(8192 * 1024)
            if not xBuffer: break
            count += xBuffer.count('\n')
        count /= 4
    elif fileType == "fasta":
        while 1:
            xBuffer = thefile.read(8192 * 1024)
            if not xBuffer: break
            count += xBuffer.count('>')
    thefile.close()
    return count

## =================================================================
# # Function: splitReads
## =================================================================
def shuffleReads(_sFilename, _vOutputFiles, _iReadUniqueId):
    fileExt = _sFilename.split(".")[-1]  # file type, fasta or fastq, autodetect
    if fileExt in ["fa", "Fa", "faa", "Faa", "fna", "Fna", "fasta", "Fasta"]:  # either fa or fq
        fileType = "fasta"
    elif fileExt in ["fq", "Fq", "fastq", "Fastq"]:  # either fa or fq
        fileType = "fastq"
    else:
        sys.stderr.write("File type is not correct...\n")
        return (_iReadUniqueId)

    global IdOfFirstSingleRead
    global sFirstSingleReadFilename
    if IdOfFirstSingleRead == -1 and _sFilename == sFirstSingleReadFilename:
        IdOfFirstSingleRead = _iReadUniqueId

    numOutputFiles = len(_vOutputFiles)
    #fOutFileIdMap = open("IdMap", 'a')
    with open(_sFilename, 'r') as fin:
        if fileType == "fastq":
            for readLines in getReadFromFastq(fin):
                if len(readLines) == 0:
                    break
                iPairId = int(_iReadUniqueId / 2)
                fout = _vOutputFiles[(iPairId % numOutputFiles)]
                fout.write(">{0}\n".format(_iReadUniqueId))
                _iReadUniqueId = 1 + _iReadUniqueId
                fout.write(readLines)
                fout.write('\n')
        elif fileType == "fasta":
            for readLines, name in getReadFromFasta(fin):
                if len(readLines) == 0:
                    break
                iPairId = int(_iReadUniqueId / 2)
                fout = _vOutputFiles[(iPairId % numOutputFiles)]
                fout.write(">{0}\n".format(_iReadUniqueId))
                #fOutFileIdMap.write("{0}\t{1}\n".format(_iReadUniqueId, name))
                _iReadUniqueId = 1 + _iReadUniqueId
                fout.write(readLines)
                fout.write('\n')

    for fout in _vOutputFiles:
        fout.flush()
    return (_iReadUniqueId)


## =================================================================
# # argument parser
## =================================================================
parser = argparse.ArgumentParser(description="Split big sequence file in fasta/fastq format into small ones",
                                 prog='splitReads',  # program name
                                 prefix_chars='-',  # prefix for options
                                 fromfile_prefix_chars='@',  # if options are read from file, '@args.txt'
                                 conflict_handler='resolve',  # for handling conflict options
                                 add_help=True,  # include help in the options
                                 formatter_class=argparse.ArgumentDefaultsHelpFormatter  # print default values for options in help message
                                 )

# # input files and directories
parser.add_argument("-i", "--in", help="input sequence file(s)/folder", dest='seqFile', required=False)
# # input files and directories
parser.add_argument("-ip", "--inputPair", help="input sequence paired read file(s)/folder", dest='pairedSeqFile', required=False)
# # input files and directories
parser.add_argument("-is", "--inputSingle", help="input sequence single end read file(s)/folder", dest='singleSeqFile', required=False)
# # output directory
parser.add_argument("-o", "--out", help="output prefix", dest='outputPrefix', required=False)
# # options
parser.add_argument("-n", "--numOutput", help="number of split files", dest='seqCount', required=False, default=4, type=float)
#
parser.add_argument("-d", "--distribute", help="distribute reads to each file", dest='distribute', action='store_true', default=True)
#
parser.add_argument("-f", "--firstUniqueId", help="first Unique Id", dest='first', required=False, type=int, default=0)

## =================================================================
# # main function
## =================================================================
def main(argv=None):

    if argv is None:
        args = parser.parse_args()

    if args.outputPrefix is None:
        args.outputPrefix = "split"

    # add the input read file to the list
    lInputReadFiles = []
    if args.seqFile is not None:
        sFilename = args.seqFile
        if "," in sFilename:
            lInputReadFiles = sFilename.split(",")
        elif os.path.isdir(sFilename):
            for tElement in os.walk(sFilename):
                for name in tElement[2]:
                    lInputReadFiles.append(os.path.join(tElement[0], name))
        else:
            lInputReadFiles.append(sFilename)


    # add the input paired read file to the list
    if args.pairedSeqFile is not None:
        sFilename = args.pairedSeqFile
        if "," in sFilename:
            lInputReadFiles = sFilename.split(",")
        elif os.path.isdir(sFilename):
            for tElement in os.walk(sFilename):
                for name in tElement[2]:
                    lInputReadFiles.append(os.path.join(tElement[0], name))
        else:
            lInputReadFiles.append(sFilename)

    # add the input single read file to the list
    if args.singleSeqFile is not None:
        lSingleReadFiles = []
        sFilename = args.singleSeqFile
        if "," in sFilename:
            lSingleReadFiles = sFilename.split(",")
        elif os.path.isdir(sFilename):
            for tElement in os.walk(sFilename):
                for name in tElement[2]:
                    lSingleReadFiles.append(os.path.join(tElement[0], name))
        else:
            lSingleReadFiles.append(sFilename)
        global sFirstSingleReadFilename
        sFirstSingleReadFilename = lSingleReadFiles[0]
        lInputReadFiles.extend(lSingleReadFiles)

    global IdOfFirstSingleRead
    # shuffle the reads
    if args.distribute:
        iReadUniqueId = args.first;
        vOutput = []
        numParts = int(args.seqCount)
        for i in range(0, numParts):
            sOutputFilename = "{0}.{1:0>2}.{2}".format(args.outputPrefix, i, "fasta")
            fout = open(sOutputFilename, 'a')
            vOutput.append(fout)
        for sEachFile in lInputReadFiles:
            iReadUniqueId = shuffleReads(sEachFile, vOutput, iReadUniqueId)
        for fout in vOutput:
            fout.flush()
            fout.close()
        print "\nThe last available unique even Id is:"
        if iReadUniqueId%2 !=0:
            iReadUniqueId += 1
        print iReadUniqueId
        return

##==============================================================
# # call from command line (instead of interactively)
##==============================================================

if __name__ == '__main__':
    sys.exit(main())
